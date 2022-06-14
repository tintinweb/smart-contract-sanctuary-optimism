//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ElectionModule as SynthetixElectionModule} from "@synthetixio/synthetix-governance/contracts/modules/ElectionModule.sol";

contract ElectionModule is SynthetixElectionModule {
    // ---------------------------------------
    // Internal
    // ---------------------------------------

    /// @dev Overrides the user's voting power by combining local chain debt share with debt shares in other chains
    /// @dev Note that this removes the use of Math.sqrt defined in synthetix-governance
    function _getVotePower(address user) internal view override returns (uint) {
        return _getDebtShare(user) + _getDeclaredCrossChainDebtShare(user);
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ElectionModule as BaseElectionModule} from "@synthetixio/core-modules/contracts/modules/ElectionModule.sol";
import "@synthetixio/core-contracts/contracts/utils/MathUtil.sol";
import "@synthetixio/core-modules/contracts/interfaces/IElectionModule.sol";
import "../interfaces/ISynthetixElectionModule.sol";
import "../submodules/election/DebtShareManager.sol";
import "../submodules/election/CrossChainDebtShareManager.sol";

/// @title Module for electing a council, represented by a set of NFT holders
/// @notice This extends the base ElectionModule by determining voting power by Synthetix v2 debt share
contract ElectionModule is ISynthetixElectionModule, BaseElectionModule, DebtShareManager, CrossChainDebtShareManager {
    error TooManyCandidates();
    error WrongInitializer();

    /// @dev The BaseElectionModule initializer should not be called, and this one must be called instead
    function initializeElectionModule(
        string memory,
        string memory,
        address[] memory,
        uint8,
        uint64,
        uint64,
        uint64
    ) external view override(BaseElectionModule, IElectionModule) onlyOwner onlyIfNotInitialized {
        revert WrongInitializer();
    }

    /// @dev Overloads the BaseElectionModule initializer with an additional parameter for the debt share contract
    function initializeElectionModule(
        string memory councilTokenName,
        string memory councilTokenSymbol,
        address[] memory firstCouncil,
        uint8 minimumActiveMembers,
        uint64 nominationPeriodStartDate,
        uint64 votingPeriodStartDate,
        uint64 epochEndDate,
        address debtShareContract
    ) external override onlyOwner onlyIfNotInitialized {
        _setDebtShareContract(debtShareContract);

        _initializeElectionModule(
            councilTokenName,
            councilTokenSymbol,
            firstCouncil,
            minimumActiveMembers,
            nominationPeriodStartDate,
            votingPeriodStartDate,
            epochEndDate
        );
    }

    /// @dev Overrides the BaseElectionModule nominate function to only allow 1 candidate to be nominated
    function cast(address[] calldata candidates)
        public
        override(BaseElectionModule, IElectionModule)
        onlyInPeriod(ElectionPeriod.Vote)
    {
        if (candidates.length > 1) {
            revert TooManyCandidates();
        }

        super.cast(candidates);
    }

    // ---------------------------------------
    // Debt shares
    // ---------------------------------------

    function setDebtShareContract(address debtShareContract)
        external
        override
        onlyOwner
        onlyInPeriod(ElectionPeriod.Administration)
    {
        _setDebtShareContract(debtShareContract);

        emit DebtShareContractSet(debtShareContract);
    }

    function getDebtShareContract() external view override returns (address) {
        return address(_debtShareStore().debtShareContract);
    }

    function setDebtShareSnapshotId(uint snapshotId) external override onlyOwner onlyInPeriod(ElectionPeriod.Nomination) {
        _setDebtShareSnapshotId(snapshotId);
    }

    function getDebtShareSnapshotId() external view override returns (uint) {
        return _getDebtShareSnapshotId();
    }

    function getDebtShare(address user) external view override returns (uint) {
        return _getDebtShare(user);
    }

    // ---------------------------------------
    // Cross chain debt shares
    // ---------------------------------------

    function setCrossChainDebtShareMerkleRoot(bytes32 merkleRoot, uint blocknumber)
        external
        override
        onlyOwner
        onlyInPeriod(ElectionPeriod.Nomination)
    {
        _setCrossChainDebtShareMerkleRoot(merkleRoot, blocknumber);

        emit CrossChainDebtShareMerkleRootSet(merkleRoot, blocknumber, _getCurrentEpochIndex());
    }

    function getCrossChainDebtShareMerkleRoot() external view override returns (bytes32) {
        return _getCrossChainDebtShareMerkleRoot();
    }

    function getCrossChainDebtShareMerkleRootBlockNumber() external view override returns (uint) {
        return _getCrossChainDebtShareMerkleRootBlockNumber();
    }

    function declareCrossChainDebtShare(
        address user,
        uint256 debtShare,
        bytes32[] calldata merkleProof
    ) public override onlyInPeriod(ElectionPeriod.Vote) {
        _declareCrossChainDebtShare(user, debtShare, merkleProof);

        emit CrossChainDebtShareDeclared(user, debtShare);
    }

    function getDeclaredCrossChainDebtShare(address user) external view override returns (uint) {
        return _getDeclaredCrossChainDebtShare(user);
    }

    function declareAndCast(
        uint256 debtShare,
        bytes32[] calldata merkleProof,
        address[] calldata candidates
    ) public override onlyInPeriod(ElectionPeriod.Vote) {
        declareCrossChainDebtShare(msg.sender, debtShare, merkleProof);

        cast(candidates);
    }

    // ---------------------------------------
    // Internal
    // ---------------------------------------

    /// @dev Overrides the user's voting power by combining local chain debt share with debt shares in other chains, quadratically filtered
    function _getVotePower(address user) internal view virtual override returns (uint) {
        uint votePower = _getDebtShare(user) + _getDeclaredCrossChainDebtShare(user);

        return MathUtil.sqrt(votePower);
    }

    function _createNewEpoch() internal virtual override {
        super._createNewEpoch();

        DebtShareStore storage store = _debtShareStore();

        store.debtShareIds.push();
        store.crossChainDebtShareData.push();
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@synthetixio/core-contracts/contracts/errors/InitError.sol";
import "@synthetixio/core-contracts/contracts/ownership/OwnableMixin.sol";
import "@synthetixio/core-contracts/contracts/initializable/InitializableMixin.sol";
import "../interfaces/IElectionModule.sol";
import "../submodules/election/ElectionSchedule.sol";
import "../submodules/election/ElectionCredentials.sol";
import "../submodules/election/ElectionVotes.sol";
import "../submodules/election/ElectionTally.sol";

contract ElectionModule is
    IElectionModule,
    ElectionSchedule,
    ElectionCredentials,
    ElectionVotes,
    ElectionTally,
    OwnableMixin,
    InitializableMixin
{
    using SetUtil for SetUtil.AddressSet;

    function initializeElectionModule(
        string memory councilTokenName,
        string memory councilTokenSymbol,
        address[] memory firstCouncil,
        uint8 minimumActiveMembers,
        uint64 nominationPeriodStartDate,
        uint64 votingPeriodStartDate,
        uint64 epochEndDate
    ) external virtual override onlyOwner onlyIfNotInitialized {
        _initializeElectionModule(
            councilTokenName,
            councilTokenSymbol,
            firstCouncil,
            minimumActiveMembers,
            nominationPeriodStartDate,
            votingPeriodStartDate,
            epochEndDate
        );
    }

    function _initializeElectionModule(
        string memory councilTokenName,
        string memory councilTokenSymbol,
        address[] memory firstCouncil,
        uint8 minimumActiveMembers,
        uint64 nominationPeriodStartDate,
        uint64 votingPeriodStartDate,
        uint64 epochEndDate
    ) internal {
        ElectionStore storage store = _electionStore();

        uint8 seatCount = uint8(firstCouncil.length);
        if (minimumActiveMembers == 0 || minimumActiveMembers > seatCount) {
            revert InvalidMinimumActiveMembers();
        }

        ElectionSettings storage settings = _electionSettings();
        settings.minNominationPeriodDuration = 2 days;
        settings.minVotingPeriodDuration = 2 days;
        settings.minEpochDuration = 7 days;
        settings.maxDateAdjustmentTolerance = 7 days;
        settings.nextEpochSeatCount = uint8(firstCouncil.length);
        settings.minimumActiveMembers = minimumActiveMembers;
        settings.defaultBallotEvaluationBatchSize = 500;

        _createNewEpoch();

        EpochData storage firstEpoch = _getEpochAtIndex(0);
        uint64 epochStartDate = uint64(block.timestamp);
        _configureEpochSchedule(firstEpoch, epochStartDate, nominationPeriodStartDate, votingPeriodStartDate, epochEndDate);

        _createCouncilToken(councilTokenName, councilTokenSymbol);
        _addCouncilMembers(firstCouncil, 0);

        store.initialized = true;

        emit ElectionModuleInitialized();
        emit EpochStarted(1);
    }

    function isElectionModuleInitialized() public view override returns (bool) {
        return _isInitialized();
    }

    function _isInitialized() internal view override returns (bool) {
        return _electionStore().initialized;
    }

    function upgradeCouncilToken(address newCouncilTokenImplementation) external override onlyOwner onlyIfInitialized {
        CouncilToken(_electionStore().councilToken).upgradeTo(newCouncilTokenImplementation);

        emit CouncilTokenUpgraded(newCouncilTokenImplementation);
    }

    function tweakEpochSchedule(
        uint64 newNominationPeriodStartDate,
        uint64 newVotingPeriodStartDate,
        uint64 newEpochEndDate
    ) external override onlyOwner onlyInPeriod(ElectionPeriod.Administration) {
        _adjustEpochSchedule(
            _getCurrentEpoch(),
            newNominationPeriodStartDate,
            newVotingPeriodStartDate,
            newEpochEndDate,
            true /*ensureChangesAreSmall = true*/
        );

        emit EpochScheduleUpdated(newNominationPeriodStartDate, newVotingPeriodStartDate, newEpochEndDate);
    }

    function modifyEpochSchedule(
        uint64 newNominationPeriodStartDate,
        uint64 newVotingPeriodStartDate,
        uint64 newEpochEndDate
    ) external override onlyOwner onlyInPeriod(ElectionPeriod.Administration) {
        _adjustEpochSchedule(
            _getCurrentEpoch(),
            newNominationPeriodStartDate,
            newVotingPeriodStartDate,
            newEpochEndDate,
            false /*!ensureChangesAreSmall = false*/
        );

        emit EpochScheduleUpdated(newNominationPeriodStartDate, newVotingPeriodStartDate, newEpochEndDate);
    }

    function setMinEpochDurations(
        uint64 newMinNominationPeriodDuration,
        uint64 newMinVotingPeriodDuration,
        uint64 newMinEpochDuration
    ) external override onlyOwner {
        _setMinEpochDurations(newMinNominationPeriodDuration, newMinVotingPeriodDuration, newMinEpochDuration);

        emit MinimumEpochDurationsChanged(newMinNominationPeriodDuration, newMinVotingPeriodDuration, newMinEpochDuration);
    }

    function setMaxDateAdjustmentTolerance(uint64 newMaxDateAdjustmentTolerance) external override onlyOwner {
        if (newMaxDateAdjustmentTolerance == 0) revert InvalidElectionSettings();

        _electionSettings().maxDateAdjustmentTolerance = newMaxDateAdjustmentTolerance;

        emit MaxDateAdjustmentToleranceChanged(newMaxDateAdjustmentTolerance);
    }

    function setDefaultBallotEvaluationBatchSize(uint newDefaultBallotEvaluationBatchSize) external override onlyOwner {
        if (newDefaultBallotEvaluationBatchSize == 0) revert InvalidElectionSettings();

        _electionSettings().defaultBallotEvaluationBatchSize = newDefaultBallotEvaluationBatchSize;

        emit DefaultBallotEvaluationBatchSizeChanged(newDefaultBallotEvaluationBatchSize);
    }

    function setNextEpochSeatCount(uint8 newSeatCount)
        external
        override
        onlyOwner
        onlyInPeriod(ElectionPeriod.Administration)
    {
        if (newSeatCount == 0) revert InvalidElectionSettings();

        _electionSettings().nextEpochSeatCount = newSeatCount;

        emit NextEpochSeatCountChanged(newSeatCount);
    }

    function setMinimumActiveMembers(uint8 newMinimumActiveMembers) external override onlyOwner {
        if (newMinimumActiveMembers == 0) revert InvalidMinimumActiveMembers();

        _electionSettings().minimumActiveMembers = newMinimumActiveMembers;

        emit MinimumActiveMembersChanged(newMinimumActiveMembers);
    }

    function dismissMembers(address[] calldata membersToDismiss) external override onlyOwner {
        uint epochIndex = _getCurrentEpochIndex();

        _removeCouncilMembers(membersToDismiss, epochIndex);

        emit CouncilMembersDismissed(membersToDismiss, epochIndex);

        // Don't immediately jump to an election if the council still has enough members
        if (_getCurrentPeriod() != ElectionPeriod.Administration) return;
        if (_electionStore().councilMembers.length() >= _electionSettings().minimumActiveMembers) return;

        _jumpToNominationPeriod();

        emit EmergencyElectionStarted(epochIndex);
    }

    function nominate() public virtual override onlyInPeriod(ElectionPeriod.Nomination) {
        SetUtil.AddressSet storage nominees = _getCurrentElection().nominees;

        if (nominees.contains(msg.sender)) revert AlreadyNominated();

        nominees.add(msg.sender);

        emit CandidateNominated(msg.sender, _getCurrentEpochIndex());
    }

    function withdrawNomination() external override onlyInPeriod(ElectionPeriod.Nomination) {
        SetUtil.AddressSet storage nominees = _getCurrentElection().nominees;

        if (!nominees.contains(msg.sender)) revert NotNominated();

        nominees.remove(msg.sender);

        emit NominationWithdrawn(msg.sender, _getCurrentEpochIndex());
    }

    /// @dev ElectionVotes needs to be extended to specify what determines voting power
    function cast(address[] calldata candidates) public virtual override onlyInPeriod(ElectionPeriod.Vote) {
        uint votePower = _getVotePower(msg.sender);

        if (votePower == 0) revert NoVotePower();

        _validateCandidates(candidates);

        bytes32 ballotId;

        uint epochIndex = _getCurrentEpochIndex();

        if (hasVoted(msg.sender)) {
            _withdrawCastedVote(msg.sender, epochIndex);
        }

        ballotId = _recordVote(msg.sender, votePower, candidates);

        emit VoteRecorded(msg.sender, ballotId, epochIndex, votePower);
    }

    function withdrawVote() external override onlyInPeriod(ElectionPeriod.Vote) {
        if (!hasVoted(msg.sender)) {
            revert VoteNotCasted();
        }

        _withdrawCastedVote(msg.sender, _getCurrentEpochIndex());
    }

    /// @dev ElectionTally needs to be extended to specify how votes are counted
    function evaluate(uint numBallots) external override onlyInPeriod(ElectionPeriod.Evaluation) {
        ElectionData storage election = _getCurrentElection();

        if (election.evaluated) revert ElectionAlreadyEvaluated();

        _evaluateNextBallotBatch(numBallots);

        uint currentEpochIndex = _getCurrentEpochIndex();

        uint totalBallots = election.ballotIds.length;
        if (election.numEvaluatedBallots < totalBallots) {
            emit ElectionBatchEvaluated(currentEpochIndex, election.numEvaluatedBallots, totalBallots);
        } else {
            election.evaluated = true;

            emit ElectionEvaluated(currentEpochIndex, totalBallots);
        }
    }

    /// @dev Burns previous NFTs and mints new ones
    function resolve() external override onlyInPeriod(ElectionPeriod.Evaluation) {
        ElectionData storage election = _getCurrentElection();

        if (!election.evaluated) revert ElectionNotEvaluated();

        uint newEpochIndex = _getCurrentEpochIndex() + 1;

        _removeAllCouncilMembers(newEpochIndex);
        _addCouncilMembers(election.winners.values(), newEpochIndex);

        election.resolved = true;

        _createNewEpoch();
        _copyScheduleFromPreviousEpoch();

        emit EpochStarted(newEpochIndex);
    }

    function getMinEpochDurations()
        external
        view
        override
        returns (
            uint64 minNominationPeriodDuration,
            uint64 minVotingPeriodDuration,
            uint64 minEpochDuration
        )
    {
        ElectionSettings storage settings = _electionSettings();

        return (settings.minNominationPeriodDuration, settings.minVotingPeriodDuration, settings.minEpochDuration);
    }

    function getMaxDateAdjustmenTolerance() external view override returns (uint64) {
        return _electionSettings().maxDateAdjustmentTolerance;
    }

    function getDefaultBallotEvaluationBatchSize() external view override returns (uint) {
        return _electionSettings().defaultBallotEvaluationBatchSize;
    }

    function getNextEpochSeatCount() external view override returns (uint8) {
        return _electionSettings().nextEpochSeatCount;
    }

    function getMinimumActiveMembers() external view override returns (uint8) {
        return _electionSettings().minimumActiveMembers;
    }

    function getEpochIndex() external view override returns (uint) {
        return _getCurrentEpochIndex();
    }

    function getEpochStartDate() external view override returns (uint64) {
        return _getCurrentEpoch().startDate;
    }

    function getEpochEndDate() external view override returns (uint64) {
        return _getCurrentEpoch().endDate;
    }

    function getNominationPeriodStartDate() external view override returns (uint64) {
        return _getCurrentEpoch().nominationPeriodStartDate;
    }

    function getVotingPeriodStartDate() external view override returns (uint64) {
        return _getCurrentEpoch().votingPeriodStartDate;
    }

    function getCurrentPeriod() external view override returns (uint) {
        return uint(_getCurrentPeriod());
    }

    function isNominated(address candidate) external view override returns (bool) {
        return _getCurrentElection().nominees.contains(candidate);
    }

    function getNominees() external view override returns (address[] memory) {
        return _getCurrentElection().nominees.values();
    }

    function calculateBallotId(address[] calldata candidates) external pure override returns (bytes32) {
        return _calculateBallotId(candidates);
    }

    function getBallotVoted(address user) public view override returns (bytes32) {
        return _getBallotVoted(user);
    }

    function hasVoted(address user) public view override returns (bool) {
        return _getBallotVoted(user) != bytes32(0);
    }

    function getVotePower(address user) external view override returns (uint) {
        return _getVotePower(user);
    }

    function getBallotVotes(bytes32 ballotId) external view override returns (uint) {
        return _getBallot(ballotId).votes;
    }

    function getBallotCandidates(bytes32 ballotId) external view override returns (address[] memory) {
        return _getBallot(ballotId).candidates;
    }

    function isElectionEvaluated() public view override returns (bool) {
        return _getCurrentElection().evaluated;
    }

    function getCandidateVotes(address candidate) external view override returns (uint) {
        return _getCurrentElection().candidateVotes[candidate];
    }

    function getElectionWinners() external view override returns (address[] memory) {
        return _getCurrentElection().winners.values();
    }

    function getCouncilToken() public view override returns (address) {
        return _electionStore().councilToken;
    }

    function getCouncilMembers() external view override returns (address[] memory) {
        return _electionStore().councilMembers.values();
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
    Reference implementations:
    * Solmate - https://github.com/Rari-Capital/solmate/blob/main/src/utils/FixedPointMathLib.sol
*/

library MathUtil {
    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            // Start off with z at 1.
            z := 1

            // Used below to help find a nearby power of 2.
            let y := x

            // Find the lowest power of 2 that is at least sqrt(x).
            if iszero(lt(y, 0x100000000000000000000000000000000)) {
                y := shr(128, y) // Like dividing by 2 ** 128.
                z := shl(64, z) // Like multiplying by 2 ** 64.
            }
            if iszero(lt(y, 0x10000000000000000)) {
                y := shr(64, y) // Like dividing by 2 ** 64.
                z := shl(32, z) // Like multiplying by 2 ** 32.
            }
            if iszero(lt(y, 0x100000000)) {
                y := shr(32, y) // Like dividing by 2 ** 32.
                z := shl(16, z) // Like multiplying by 2 ** 16.
            }
            if iszero(lt(y, 0x10000)) {
                y := shr(16, y) // Like dividing by 2 ** 16.
                z := shl(8, z) // Like multiplying by 2 ** 8.
            }
            if iszero(lt(y, 0x100)) {
                y := shr(8, y) // Like dividing by 2 ** 8.
                z := shl(4, z) // Like multiplying by 2 ** 4.
            }
            if iszero(lt(y, 0x10)) {
                y := shr(4, y) // Like dividing by 2 ** 4.
                z := shl(2, z) // Like multiplying by 2 ** 2.
            }
            if iszero(lt(y, 0x8)) {
                // Equivalent to 2 ** z.
                z := shl(1, z)
            }

            // Shifting right by 1 is like dividing by 2.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // Compute a rounded down version of z.
            let zRoundDown := div(x, z)

            // If zRoundDown is smaller, use it.
            if lt(zRoundDown, z) {
                z := zRoundDown
            }
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Module for electing a council, represented by a set of NFT holders
interface IElectionModule {
    // ---------------------------------------
    // Initialization
    // ---------------------------------------

    /// @notice Initializes the module and immediately starts the first epoch
    function initializeElectionModule(
        string memory councilTokenName,
        string memory councilTokenSymbol,
        address[] memory firstCouncil,
        uint8 minimumActiveMembers,
        uint64 nominationPeriodStartDate,
        uint64 votingPeriodStartDate,
        uint64 epochEndDate
    ) external;

    /// @notice Shows whether the module has been initialized
    function isElectionModuleInitialized() external view returns (bool);

    // ---------------------------------------
    // Owner write functions
    // ---------------------------------------

    /// @notice Upgrades the implementation of the existing council NFT token
    function upgradeCouncilToken(address newCouncilTokenImplementation) external;

    /// @notice Adjusts the current epoch schedule requiring that the current period remains Administration, and that changes are small (see setMaxDateAdjustmentTolerance)
    function tweakEpochSchedule(
        uint64 newNominationPeriodStartDate,
        uint64 newVotingPeriodStartDate,
        uint64 newEpochEndDate
    ) external;

    /// @notice Adjusts the current epoch schedule requiring that the current period remains Administration
    function modifyEpochSchedule(
        uint64 newNominationPeriodStartDate,
        uint64 newVotingPeriodStartDate,
        uint64 newEpochEndDate
    ) external;

    /// @notice Determines minimum values for epoch schedule adjustments
    function setMinEpochDurations(
        uint64 newMinNominationPeriodDuration,
        uint64 newMinVotingPeriodDuration,
        uint64 newMinEpochDuration
    ) external;

    /// @notice Determines adjustment size for tweakEpochSchedule
    function setMaxDateAdjustmentTolerance(uint64 newMaxDateAdjustmentTolerance) external;

    /// @notice Determines batch size when evaluate() is called with numBallots = 0
    function setDefaultBallotEvaluationBatchSize(uint newDefaultBallotEvaluationBatchSize) external;

    /// @notice Determines the number of council members in the next epoch
    function setNextEpochSeatCount(uint8 newSeatCount) external;

    /// @notice Determines the minimum number of council members before triggering an emergency election
    function setMinimumActiveMembers(uint8 newMinimumActiveMembers) external;

    /// @notice Allows the owner to remove one or more council members, triggering an election if a threshold is met
    function dismissMembers(address[] calldata members) external;

    // ---------------------------------------
    // User write functions
    // ---------------------------------------

    /// @notice Allows anyone to self-nominate during the Nomination period
    function nominate() external;

    /// @notice Self-withdrawal of nominations during the Nomination period
    function withdrawNomination() external;

    /// @notice Allows anyone with vote power to vote on nominated candidates during the Voting period
    function cast(address[] calldata candidates) external;

    /// @notice Allows votes to be withdraw
    function withdrawVote() external;

    /// @notice Processes ballots in batches during the Evaluation period (after epochEndDate)
    function evaluate(uint numBallots) external;

    /// @notice Shuffles NFTs and resolves an election after it has been evaluated
    function resolve() external;

    // ---------------------------------------
    // View functions
    // ---------------------------------------

    /// @notice Exposes minimum durations required when adjusting epoch schedules
    function getMinEpochDurations()
        external
        view
        returns (
            uint64 minNominationPeriodDuration,
            uint64 minVotingPeriodDuration,
            uint64 minEpochDuration
        );

    /// @notice Exposes maximum size of adjustments when calling tweakEpochSchedule
    function getMaxDateAdjustmenTolerance() external view returns (uint64);

    /// @notice Shows the default batch size when calling evaluate() with numBallots = 0
    function getDefaultBallotEvaluationBatchSize() external view returns (uint);

    /// @notice Shows the number of council members that the next epoch will have
    function getNextEpochSeatCount() external view returns (uint8);

    /// @notice Returns the minimum active members that the council needs to avoid an emergency election
    function getMinimumActiveMembers() external view returns (uint8);

    /// @notice Returns the index of the current epoch. The first epoch's index is 1
    function getEpochIndex() external view returns (uint);

    /// @notice Returns the date in which the current epoch started
    function getEpochStartDate() external view returns (uint64);

    /// @notice Returns the date in which the current epoch will end
    function getEpochEndDate() external view returns (uint64);

    /// @notice Returns the date in which the Nomination period in the current epoch will start
    function getNominationPeriodStartDate() external view returns (uint64);

    /// @notice Returns the date in which the Voting period in the current epoch will start
    function getVotingPeriodStartDate() external view returns (uint64);

    /// @notice Returns the current period type: Administration, Nomination, Voting, Evaluation
    function getCurrentPeriod() external view returns (uint);

    /// @notice Shows if a candidate has been nominated in the current epoch
    function isNominated(address candidate) external view returns (bool);

    /// @notice Returns a list of all nominated candidates in the current epoch
    function getNominees() external view returns (address[] memory);

    /// @notice Hashes a list of candidates (used for identifying and storing ballots)
    function calculateBallotId(address[] calldata candidates) external pure returns (bytes32);

    /// @notice Returns the ballot id that user voted on in the current election
    function getBallotVoted(address user) external view returns (bytes32);

    /// @notice Returns if user has voted in the current election
    function hasVoted(address user) external view returns (bool);

    /// @notice Returns the vote power of user in the current election
    function getVotePower(address user) external view returns (uint);

    /// @notice Returns the number of votes given to a particular ballot
    function getBallotVotes(bytes32 ballotId) external view returns (uint);

    /// @notice Returns the list of candidates that a particular ballot has
    function getBallotCandidates(bytes32 ballotId) external view returns (address[] memory);

    /// @notice Returns whether all ballots in the current election have been counted
    function isElectionEvaluated() external view returns (bool);

    /// @notice Returns the number of votes a candidate received. Requires the election to be partially or totally evaluated
    function getCandidateVotes(address candidate) external view returns (uint);

    /// @notice Returns the winners of the current election. Requires the election to be partially or totally evaluated
    function getElectionWinners() external view returns (address[] memory);

    /// @notice Returns the address of the council NFT token
    function getCouncilToken() external view returns (address);

    /// @notice Returns the current NFT token holders
    function getCouncilMembers() external view returns (address[] memory);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IElectionModule as IBaseElectionModule} from "@synthetixio/core-modules/contracts/interfaces/IElectionModule.sol";

interface ISynthetixElectionModule is IBaseElectionModule {
    /// @notice Initializes the module and immediately starts the first epoch
    function initializeElectionModule(
        string memory councilTokenName,
        string memory councilTokenSymbol,
        address[] memory firstCouncil,
        uint8 minimumActiveMembers,
        uint64 nominationPeriodStartDate,
        uint64 votingPeriodStartDate,
        uint64 epochEndDate,
        address debtShareContract
    ) external;

    // ---------------------------------------
    // Debt shares
    // ---------------------------------------

    /// @notice Sets the Synthetix v2 DebtShare contract that determines vote power
    function setDebtShareContract(address newDebtShareContractAddress) external;

    /// @notice Returns the Synthetix v2 DebtShare contract that determines vote power
    function getDebtShareContract() external view returns (address);

    /// @notice Sets the Synthetix v2 DebtShare snapshot that determines vote power for this epoch
    function setDebtShareSnapshotId(uint snapshotId) external;

    /// @notice Returns the Synthetix v2 DebtShare snapshot id set for this epoch
    function getDebtShareSnapshotId() external view returns (uint);

    /// @notice Returns the Synthetix v2 debt share for the provided address, at this epoch's snapshot
    function getDebtShare(address user) external view returns (uint);

    // ---------------------------------------
    // Cross chain debt shares
    // ---------------------------------------

    /// @notice Allows the system owner to declare a merkle root for user debt shares on other chains for this epoch
    function setCrossChainDebtShareMerkleRoot(bytes32 merkleRoot, uint blocknumber) external;

    /// @notice Returns the current epoch's merkle root for user debt shares on other chains
    function getCrossChainDebtShareMerkleRoot() external view returns (bytes32);

    /// @notice Returns the current epoch's merkle root block number
    function getCrossChainDebtShareMerkleRootBlockNumber() external view returns (uint);

    /// @notice Allows users to declare their Synthetix v2 debt shares on other chains
    function declareCrossChainDebtShare(
        address account,
        uint256 debtShare,
        bytes32[] calldata merkleProof
    ) external;

    /// @notice Returns the Synthetix v2 debt shares for the provided address, at this epoch's snapshot, in other chains
    function getDeclaredCrossChainDebtShare(address account) external view returns (uint);

    /// @notice Declares cross chain debt shares and casts a vote
    function declareAndCast(
        uint256 debtShare,
        bytes32[] calldata merkleProof,
        address[] calldata candidates
    ) external;
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../storage/DebtShareStorage.sol";
import "@synthetixio/core-contracts/contracts/utils/AddressUtil.sol";
import "@synthetixio/core-contracts/contracts/errors/ChangeError.sol";
import "@synthetixio/core-contracts/contracts/errors/AddressError.sol";
import "@synthetixio/core-modules/contracts/submodules/election/ElectionBase.sol";

/// @dev Tracks user Synthetix v2 debt chains on the local chain at a particular block number
contract DebtShareManager is ElectionBase, DebtShareStorage {
    error DebtShareContractNotSet();
    error DebtShareSnapshotIdNotSet();

    event DebtShareContractSet(address contractAddress);
    event DebtShareSnapshotIdSet(uint snapshotId);

    function _setDebtShareSnapshotId(uint snapshotId) internal {
        DebtShareStore storage store = _debtShareStore();

        uint currentEpochIndex = _getCurrentEpochIndex();
        store.debtShareIds[currentEpochIndex] = uint128(snapshotId);

        emit DebtShareSnapshotIdSet(snapshotId);
    }

    function _getDebtShareSnapshotId() internal view returns (uint) {
        DebtShareStore storage store = _debtShareStore();

        uint128 debtShareId = store.debtShareIds[_getCurrentEpochIndex()];
        if (debtShareId == 0) {
            revert DebtShareSnapshotIdNotSet();
        }

        return debtShareId;
    }

    function _setDebtShareContract(address newDebtShareContractAddress) internal {
        DebtShareStore storage store = _debtShareStore();

        if (newDebtShareContractAddress == address(0)) {
            revert AddressError.ZeroAddress();
        }

        if (newDebtShareContractAddress == address(store.debtShareContract)) {
            revert ChangeError.NoChange();
        }

        if (!AddressUtil.isContract(newDebtShareContractAddress)) {
            revert AddressError.NotAContract(newDebtShareContractAddress);
        }

        store.debtShareContract = IDebtShare(newDebtShareContractAddress);
    }

    function _getDebtShare(address user) internal view returns (uint) {
        DebtShareStore storage store = _debtShareStore();

        uint128 debtShareId = store.debtShareIds[_getCurrentEpochIndex()];

        return store.debtShareContract.balanceOfOnPeriod(user, uint(debtShareId));
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@synthetixio/core-contracts/contracts/utils/MerkleProof.sol";
import "@synthetixio/core-modules/contracts/submodules/election/ElectionBase.sol";
import "../../storage/DebtShareStorage.sol";

/// @dev Uses a merkle tree to track user Synthetix v2 debt shares on other chains at a particular block number
contract CrossChainDebtShareManager is ElectionBase, DebtShareStorage {
    error MerkleRootNotSet();
    error InvalidMerkleProof();
    error CrossChainDebtShareAlreadyDeclared();

    event CrossChainDebtShareMerkleRootSet(bytes32 merkleRoot, uint blocknumber, uint epoch);
    event CrossChainDebtShareDeclared(address user, uint debtShare);

    function _setCrossChainDebtShareMerkleRoot(bytes32 merkleRoot, uint blocknumber) internal {
        CrossChainDebtShareData storage debtShareData = _debtShareStore().crossChainDebtShareData[_getCurrentEpochIndex()];

        debtShareData.merkleRoot = merkleRoot;
        debtShareData.merkleRootBlockNumber = blocknumber;
    }

    function _declareCrossChainDebtShare(
        address user,
        uint256 debtShare,
        bytes32[] calldata merkleProof
    ) internal {
        CrossChainDebtShareData storage debtShareData = _debtShareStore().crossChainDebtShareData[_getCurrentEpochIndex()];

        if (debtShareData.debtShares[user] != 0) {
            revert CrossChainDebtShareAlreadyDeclared();
        }

        if (debtShareData.merkleRoot == 0) {
            revert MerkleRootNotSet();
        }

        bytes32 leaf = keccak256(abi.encodePacked(user, debtShare));

        if (!MerkleProof.verify(merkleProof, debtShareData.merkleRoot, leaf)) {
            revert InvalidMerkleProof();
        }

        debtShareData.debtShares[user] = debtShare;
    }

    function _getCrossChainDebtShareMerkleRoot() internal view returns (bytes32) {
        CrossChainDebtShareData storage debtShareData = _debtShareStore().crossChainDebtShareData[_getCurrentEpochIndex()];

        if (debtShareData.merkleRoot == 0) {
            revert MerkleRootNotSet();
        }

        return debtShareData.merkleRoot;
    }

    function _getCrossChainDebtShareMerkleRootBlockNumber() internal view returns (uint) {
        CrossChainDebtShareData storage debtShareData = _debtShareStore().crossChainDebtShareData[_getCurrentEpochIndex()];

        if (debtShareData.merkleRoot == 0) {
            revert MerkleRootNotSet();
        }

        return debtShareData.merkleRootBlockNumber;
    }

    function _getDeclaredCrossChainDebtShare(address user) internal view returns (uint) {
        CrossChainDebtShareData storage debtShareData = _debtShareStore().crossChainDebtShareData[_getCurrentEpochIndex()];

        return debtShareData.debtShares[user];
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library InitError {
    error AlreadyInitialized();
    error NotInitialized();
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OwnableStorage.sol";
import "../errors/AccessError.sol";

contract OwnableMixin is OwnableStorage {
    modifier onlyOwner() {
        _onlyOwner();

        _;
    }

    modifier onlyOwnerIfSet() {
        address owner = _getOwner();

        // if owner is set then check if msg.sender is the owner
        if (owner != address(0)) {
            _onlyOwner();
        }

        _;
    }

    function _onlyOwner() internal view {
        if (msg.sender != _getOwner()) {
            revert AccessError.Unauthorized(msg.sender);
        }
    }

    function _getOwner() internal view returns (address) {
        return _ownableStore().owner;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../errors/InitError.sol";

abstract contract InitializableMixin {
    modifier onlyIfInitialized() {
        if (!_isInitialized()) {
            revert InitError.NotInitialized();
        }

        _;
    }

    modifier onlyIfNotInitialized() {
        if (_isInitialized()) {
            revert InitError.AlreadyInitialized();
        }

        _;
    }

    function _isInitialized() internal view virtual returns (bool);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ElectionBase.sol";
import "@synthetixio/core-contracts/contracts/errors/InitError.sol";

/// @dev Provides core schedule functionality. I.e. dates, periods, etc
contract ElectionSchedule is ElectionBase {
    /// @dev Used to allow certain functions to only operate within a given period
    modifier onlyInPeriod(ElectionPeriod period) {
        if (_getCurrentPeriod() != period) {
            revert NotCallableInCurrentPeriod();
        }

        _;
    }

    /// @dev Determines the current period type according to the current time and the epoch's dates
    function _getCurrentPeriod() internal view returns (ElectionPeriod) {
        if (!_electionStore().initialized) {
            revert InitError.NotInitialized();
        }

        EpochData storage epoch = _getCurrentEpoch();

        uint64 currentTime = uint64(block.timestamp);

        if (currentTime >= epoch.endDate) {
            return ElectionPeriod.Evaluation;
        }

        if (currentTime >= epoch.votingPeriodStartDate) {
            return ElectionPeriod.Vote;
        }

        if (currentTime >= epoch.nominationPeriodStartDate) {
            return ElectionPeriod.Nomination;
        }

        return ElectionPeriod.Administration;
    }

    /// @dev Sets dates within an epoch, with validations
    function _configureEpochSchedule(
        EpochData storage epoch,
        uint64 epochStartDate,
        uint64 nominationPeriodStartDate,
        uint64 votingPeriodStartDate,
        uint64 epochEndDate
    ) internal {
        _validateEpochSchedule(epochStartDate, nominationPeriodStartDate, votingPeriodStartDate, epochEndDate);

        epoch.startDate = epochStartDate;
        epoch.nominationPeriodStartDate = nominationPeriodStartDate;
        epoch.votingPeriodStartDate = votingPeriodStartDate;
        epoch.endDate = epochEndDate;
    }

    /// @dev Ensures epoch dates are in the correct order, durations are above minimums, etc
    function _validateEpochSchedule(
        uint64 epochStartDate,
        uint64 nominationPeriodStartDate,
        uint64 votingPeriodStartDate,
        uint64 epochEndDate
    ) private view {
        if (
            epochEndDate <= votingPeriodStartDate ||
            votingPeriodStartDate <= nominationPeriodStartDate ||
            nominationPeriodStartDate <= epochStartDate
        ) {
            revert InvalidEpochConfiguration();
        }

        uint64 epochDuration = epochEndDate - epochStartDate;
        uint64 votingPeriodDuration = epochEndDate - votingPeriodStartDate;
        uint64 nominationPeriodDuration = votingPeriodStartDate - nominationPeriodStartDate;

        ElectionSettings storage settings = _electionSettings();

        if (
            epochDuration < settings.minEpochDuration ||
            nominationPeriodDuration < settings.minNominationPeriodDuration ||
            votingPeriodDuration < settings.minVotingPeriodDuration
        ) {
            revert InvalidEpochConfiguration();
        }
    }

    /// @dev Changes epoch dates, with validations
    function _adjustEpochSchedule(
        EpochData storage epoch,
        uint64 newNominationPeriodStartDate,
        uint64 newVotingPeriodStartDate,
        uint64 newEpochEndDate,
        bool ensureChangesAreSmall
    ) internal {
        uint64 maxDateAdjustmentTolerance = _electionSettings().maxDateAdjustmentTolerance;

        if (ensureChangesAreSmall) {
            if (
                _uint64AbsDifference(newEpochEndDate, epoch.endDate) > maxDateAdjustmentTolerance ||
                _uint64AbsDifference(newNominationPeriodStartDate, epoch.nominationPeriodStartDate) >
                maxDateAdjustmentTolerance ||
                _uint64AbsDifference(newVotingPeriodStartDate, epoch.votingPeriodStartDate) > maxDateAdjustmentTolerance
            ) {
                revert InvalidEpochConfiguration();
            }
        }

        _configureEpochSchedule(
            epoch,
            epoch.startDate,
            newNominationPeriodStartDate,
            newVotingPeriodStartDate,
            newEpochEndDate
        );

        if (_getCurrentPeriod() != ElectionPeriod.Administration) {
            revert ChangesCurrentPeriod();
        }
    }

    /// @dev Moves schedule forward to immediately jump to the nomination period
    function _jumpToNominationPeriod() internal {
        EpochData storage currentEpoch = _getCurrentEpoch();

        uint64 nominationPeriodDuration = _getNominationPeriodDuration(currentEpoch);
        uint64 votingPeriodDuration = _getVotingPeriodDuration(currentEpoch);

        // Keep the previous durations, but shift everything back
        // so that nominations start now
        uint64 newNominationPeriodStartDate = uint64(block.timestamp);
        uint64 newVotingPeriodStartDate = newNominationPeriodStartDate + nominationPeriodDuration;
        uint64 newEpochEndDate = newVotingPeriodStartDate + votingPeriodDuration;

        _configureEpochSchedule(
            currentEpoch,
            currentEpoch.startDate,
            newNominationPeriodStartDate,
            newVotingPeriodStartDate,
            newEpochEndDate
        );
    }

    /// @dev Copies the current epoch schedule to the next epoch, maintaining durations
    function _copyScheduleFromPreviousEpoch() internal {
        EpochData storage previousEpoch = _getPreviousEpoch();
        EpochData storage currentEpoch = _getCurrentEpoch();

        uint64 currentEpochStartDate = uint64(block.timestamp);
        uint64 currentEpochEndDate = currentEpochStartDate + _getEpochDuration(previousEpoch);
        uint64 currentVotingPeriodStartDate = currentEpochEndDate - _getVotingPeriodDuration(previousEpoch);
        uint64 currentNominationPeriodStartDate = currentVotingPeriodStartDate - _getNominationPeriodDuration(previousEpoch);

        _configureEpochSchedule(
            currentEpoch,
            currentEpochStartDate,
            currentNominationPeriodStartDate,
            currentVotingPeriodStartDate,
            currentEpochEndDate
        );
    }

    /// @dev Sets the minimum epoch durations, with validations
    function _setMinEpochDurations(
        uint64 newMinNominationPeriodDuration,
        uint64 newMinVotingPeriodDuration,
        uint64 newMinEpochDuration
    ) internal {
        ElectionSettings storage settings = _electionSettings();

        if (newMinNominationPeriodDuration == 0 || newMinVotingPeriodDuration == 0 || newMinEpochDuration == 0) {
            revert InvalidElectionSettings();
        }

        settings.minNominationPeriodDuration = newMinNominationPeriodDuration;
        settings.minVotingPeriodDuration = newMinVotingPeriodDuration;
        settings.minEpochDuration = newMinEpochDuration;
    }

    function _uint64AbsDifference(uint64 valueA, uint64 valueB) private pure returns (uint64) {
        return valueA > valueB ? valueA - valueB : valueB - valueA;
    }

    function _getEpochDuration(EpochData storage epoch) private view returns (uint64) {
        return epoch.endDate - epoch.startDate;
    }

    function _getVotingPeriodDuration(EpochData storage epoch) private view returns (uint64) {
        return epoch.endDate - epoch.votingPeriodStartDate;
    }

    function _getNominationPeriodDuration(EpochData storage epoch) private view returns (uint64) {
        return epoch.votingPeriodStartDate - epoch.nominationPeriodStartDate;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@synthetixio/core-contracts/contracts/proxy/UUPSProxy.sol";
import "@synthetixio/core-contracts/contracts/errors/ArrayError.sol";
import "../../tokens/CouncilToken.sol";
import "./ElectionBase.sol";

/// @dev Core functionality for keeping track of council members with an NFT token
contract ElectionCredentials is ElectionBase {
    using SetUtil for SetUtil.AddressSet;

    function _createCouncilToken(string memory tokenName, string memory tokenSymbol) internal {
        CouncilToken implementation = new CouncilToken();

        UUPSProxy proxy = new UUPSProxy(address(implementation));

        CouncilToken token = CouncilToken(address(proxy));

        token.nominateNewOwner(address(this));
        token.acceptOwnership();

        token.initialize(tokenName, tokenSymbol);

        _electionStore().councilToken = address(token);

        emit CouncilTokenCreated(address(proxy), address(implementation));
    }

    function _removeAllCouncilMembers(uint epochIndex) internal {
        SetUtil.AddressSet storage members = _electionStore().councilMembers;

        uint numMembers = members.length();

        for (uint memberIndex = 0; memberIndex < numMembers; memberIndex++) {
            // Always removes the first element in the array
            // until none are left.
            _removeCouncilMember(members.valueAt(1), epochIndex);
        }
    }

    function _addCouncilMembers(address[] memory membersToAdd, uint epochIndex) internal {
        uint numMembers = membersToAdd.length;
        if (numMembers == 0) revert ArrayError.EmptyArray();

        for (uint memberIndex = 0; memberIndex < numMembers; memberIndex++) {
            _addCouncilMember(membersToAdd[memberIndex], epochIndex);
        }
    }

    function _removeCouncilMembers(address[] memory membersToRemove, uint epochIndex) internal {
        uint numMembers = membersToRemove.length;
        if (numMembers == 0) revert ArrayError.EmptyArray();

        for (uint memberIndex = 0; memberIndex < numMembers; memberIndex++) {
            _removeCouncilMember(membersToRemove[memberIndex], epochIndex);
        }
    }

    function _addCouncilMember(address newMember, uint epochIndex) internal {
        ElectionStore storage store = _electionStore();
        SetUtil.AddressSet storage members = store.councilMembers;

        if (members.contains(newMember)) {
            revert AlreadyACouncilMember();
        }

        members.add(newMember);

        // Note that tokenId = 0 will not be used.
        uint tokenId = members.length();
        _getCouncilToken().mint(newMember, tokenId);

        store.councilTokenIds[newMember] = tokenId;

        emit CouncilMemberAdded(newMember, epochIndex);
    }

    function _removeCouncilMember(address member, uint epochIndex) internal {
        ElectionStore storage store = _electionStore();
        SetUtil.AddressSet storage members = store.councilMembers;

        if (!members.contains(member)) {
            revert NotACouncilMember();
        }

        members.remove(member);

        uint tokenId = _getCouncilMemberTokenId(member);
        _getCouncilToken().burn(tokenId);

        // tokenId = 0 means no associated token.
        store.councilTokenIds[member] = 0;

        emit CouncilMemberRemoved(member, epochIndex);
    }

    function _getCouncilToken() private view returns (CouncilToken) {
        return CouncilToken(_electionStore().councilToken);
    }

    function _getCouncilMemberTokenId(address member) private view returns (uint) {
        uint tokenId = _electionStore().councilTokenIds[member];

        if (tokenId == 0) revert NotACouncilMember();

        return tokenId;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ElectionBase.sol";
import "@synthetixio/core-contracts/contracts/utils/AddressUtil.sol";
import "@synthetixio/core-contracts/contracts/utils/MathUtil.sol";
import "@synthetixio/core-contracts/contracts/errors/ChangeError.sol";
import "@synthetixio/core-contracts/contracts/errors/AddressError.sol";

/// @dev Defines core functionality for recording votes in ElectionModule.cast()
contract ElectionVotes is ElectionBase {
    using SetUtil for SetUtil.AddressSet;

    function _validateCandidates(address[] calldata candidates) internal virtual {
        uint length = candidates.length;

        if (length == 0) {
            revert NoCandidates();
        }

        SetUtil.AddressSet storage nominees = _getCurrentElection().nominees;

        for (uint i = 0; i < length; i++) {
            address candidate = candidates[i];

            // Reject candidates that are not nominated.
            if (!nominees.contains(candidate)) {
                revert NotNominated();
            }

            // Reject duplicate candidates.
            if (i < length - 1) {
                for (uint j = i + 1; j < length; j++) {
                    address otherCandidate = candidates[j];

                    if (candidate == otherCandidate) {
                        revert DuplicateCandidates();
                    }
                }
            }
        }
    }

    function _recordVote(
        address user,
        uint votePower,
        address[] calldata candidates
    ) internal virtual returns (bytes32 ballotId) {
        ElectionData storage election = _getCurrentElection();

        ballotId = _calculateBallotId(candidates);
        BallotData storage ballot = _getBallot(ballotId);

        // Initialize ballot if new.
        if (!_ballotExists(ballot)) {
            address[] memory newCandidates = candidates;

            ballot.candidates = newCandidates;

            election.ballotIds.push(ballotId);
        }

        ballot.votes += votePower;
        ballot.votesByUser[user] = votePower;
        election.ballotIdsByAddress[user] = ballotId;

        return ballotId;
    }

    function _withdrawVote(address user, uint votePower) internal virtual returns (bytes32 ballotId) {
        ElectionData storage election = _getCurrentElection();

        ballotId = election.ballotIdsByAddress[user];
        BallotData storage ballot = _getBallot(ballotId);

        ballot.votes -= votePower;
        ballot.votesByUser[user] = 0;
        election.ballotIdsByAddress[user] = bytes32(0);

        return ballotId;
    }

    function _withdrawCastedVote(address user, uint epochIndex) internal virtual {
        uint castedVotePower = _getCastedVotePower(user);

        bytes32 ballotId = _withdrawVote(user, castedVotePower);

        emit VoteWithdrawn(user, ballotId, epochIndex, castedVotePower);
    }

    function _getCastedVotePower(address user) internal virtual returns (uint votePower) {
        ElectionData storage election = _getCurrentElection();

        bytes32 ballotId = election.ballotIdsByAddress[user];
        BallotData storage ballot = _getBallot(ballotId);

        return ballot.votesByUser[user];
    }

    function _getVotePower(address) internal view virtual returns (uint) {
        return 1;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ElectionBase.sol";

/// @dev Defines core vote-counting / ballot-processing functionality in ElectionModule.evaluate()
contract ElectionTally is ElectionBase {
    using SetUtil for SetUtil.AddressSet;

    function _evaluateNextBallotBatch(uint numBallots) internal {
        if (numBallots == 0) {
            numBallots = _electionSettings().defaultBallotEvaluationBatchSize;
        }

        ElectionData storage election = _getCurrentElection();
        uint totalBallots = election.ballotIds.length;

        uint firstBallotIndex = election.numEvaluatedBallots;

        uint lastBallotIndex = firstBallotIndex + numBallots;
        if (lastBallotIndex > totalBallots) {
            lastBallotIndex = totalBallots;
        }

        _evaluateBallotRange(election, firstBallotIndex, lastBallotIndex);
    }

    function _evaluateBallotRange(
        ElectionData storage election,
        uint fromIndex,
        uint toIndex
    ) private {
        ElectionSettings storage settings = _electionSettings();
        uint numSeats = settings.nextEpochSeatCount;

        for (uint ballotIndex = fromIndex; ballotIndex < toIndex; ballotIndex++) {
            bytes32 ballotId = election.ballotIds[ballotIndex];
            BallotData storage ballot = election.ballotsById[ballotId];

            _evaluateBallot(election, ballot, numSeats);
        }
    }

    function _evaluateBallot(
        ElectionData storage election,
        BallotData storage ballot,
        uint numSeats
    ) internal {
        uint ballotVotes = ballot.votes;

        uint numCandidates = ballot.candidates.length;
        for (uint candidateIndex = 0; candidateIndex < numCandidates; candidateIndex++) {
            address candidate = ballot.candidates[candidateIndex];

            uint currentCandidateVotes = election.candidateVotes[candidate];
            uint newCandidateVotes = currentCandidateVotes + ballotVotes;
            election.candidateVotes[candidate] = newCandidateVotes;

            _updateWinnerSet(election, candidate, newCandidateVotes, numSeats);
        }

        election.numEvaluatedBallots += 1;
    }

    function _updateWinnerSet(
        ElectionData storage election,
        address candidate,
        uint candidateVotes,
        uint numSeats
    ) private {
        SetUtil.AddressSet storage winners = election.winners;

        // Already a winner?
        if (winners.contains(candidate)) {
            return;
        }

        // Just take first empty seat if
        // the set is not complete yet.
        if (winners.length() < numSeats) {
            winners.add(candidate);

            return;
        }

        // Otherwise, replace the winner with the least votes
        // in the set.
        (address leastVotedWinner, uint leastVotes) = _findWinnerWithLeastVotes(election, winners);

        if (candidateVotes > leastVotes) {
            winners.replace(leastVotedWinner, candidate);
        }
    }

    function _findWinnerWithLeastVotes(ElectionData storage election, SetUtil.AddressSet storage winners)
        private
        view
        returns (address leastVotedWinner, uint leastVotes)
    {
        leastVotes = type(uint).max;

        uint numWinners = winners.length();

        for (uint8 winnerPosition = 1; winnerPosition <= numWinners; winnerPosition++) {
            address winner = winners.valueAt(winnerPosition);
            uint winnerVotes = election.candidateVotes[winner];

            if (winnerVotes < leastVotes) {
                leastVotes = winnerVotes;

                leastVotedWinner = winner;
            }
        }

        return (leastVotedWinner, leastVotes);
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract OwnableStorage {
    struct OwnableStore {
        bool initialized;
        address owner;
        address nominatedOwner;
    }

    function _ownableStore() internal pure returns (OwnableStore storage store) {
        assembly {
            // bytes32(uint(keccak256("io.synthetix.ownable")) - 1)
            store.slot := 0x66d20a9eef910d2df763b9de0d390f3cc67f7d52c6475118cd57fa98be8cf6cb
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AccessError {
    error Unauthorized(address addr);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../storage/ElectionStorage.sol";

/// @dev Common utils, errors, and events to be used by any contracts that conform the ElectionModule
contract ElectionBase is ElectionStorage {
    // ---------------------------------------
    // Enums
    // ---------------------------------------

    enum ElectionPeriod {
        // Council elected and active
        Administration,
        // Accepting nominations for next election
        Nomination,
        // Accepting votes for ongoing election
        Vote,
        // Votes being counted
        Evaluation
    }

    // ---------------------------------------
    // Errors
    // ---------------------------------------

    error ElectionNotEvaluated();
    error ElectionAlreadyEvaluated();
    error AlreadyNominated();
    error NotNominated();
    error NoCandidates();
    error NoVotePower();
    error VoteNotCasted();
    error DuplicateCandidates();
    error InvalidEpochConfiguration();
    error InvalidElectionSettings();
    error NotCallableInCurrentPeriod();
    error ChangesCurrentPeriod();
    error AlreadyACouncilMember();
    error NotACouncilMember();
    error InvalidMinimumActiveMembers();

    // ---------------------------------------
    // Events
    // ---------------------------------------

    event ElectionModuleInitialized();
    event EpochStarted(uint epochIndex);
    event CouncilTokenCreated(address proxy, address implementation);
    event CouncilTokenUpgraded(address newImplementation);
    event CouncilMemberAdded(address indexed member, uint indexed epochIndex);
    event CouncilMemberRemoved(address indexed member, uint indexed epochIndex);
    event CouncilMembersDismissed(address[] members, uint indexed epochIndex);
    event EpochScheduleUpdated(uint64 nominationPeriodStartDate, uint64 votingPeriodStartDate, uint64 epochEndDate);
    event MinimumEpochDurationsChanged(
        uint64 minNominationPeriodDuration,
        uint64 minVotingPeriodDuration,
        uint64 minEpochDuration
    );
    event MaxDateAdjustmentToleranceChanged(uint64 tolerance);
    event DefaultBallotEvaluationBatchSizeChanged(uint size);
    event NextEpochSeatCountChanged(uint8 seatCount);
    event MinimumActiveMembersChanged(uint8 minimumActiveMembers);
    event CandidateNominated(address indexed candidate, uint indexed epochIndex);
    event NominationWithdrawn(address indexed candidate, uint indexed epochIndex);
    event VoteRecorded(address indexed voter, bytes32 indexed ballotId, uint indexed epochIndex, uint votePower);
    event VoteWithdrawn(address indexed voter, bytes32 indexed ballotId, uint indexed epochIndex, uint votePower);
    event ElectionEvaluated(uint indexed epochIndex, uint totalBallots);
    event ElectionBatchEvaluated(uint indexed epochIndex, uint evaluatedBallots, uint totalBallots);
    event EmergencyElectionStarted(uint indexed epochIndex);

    // ---------------------------------------
    // Helpers
    // ---------------------------------------

    function _createNewEpoch() internal virtual {
        ElectionStore storage store = _electionStore();

        store.epochs.push();
        store.elections.push();
    }

    function _getCurrentEpochIndex() internal view returns (uint) {
        return _electionStore().epochs.length - 1;
    }

    function _getCurrentEpoch() internal view returns (EpochData storage) {
        return _getEpochAtIndex(_getCurrentEpochIndex());
    }

    function _getPreviousEpoch() internal view returns (EpochData storage) {
        return _getEpochAtIndex(_getCurrentEpochIndex() - 1);
    }

    function _getEpochAtIndex(uint position) internal view returns (EpochData storage) {
        return _electionStore().epochs[position];
    }

    function _getCurrentElection() internal view returns (ElectionData storage) {
        return _getElectionAtIndex(_getCurrentEpochIndex());
    }

    function _getElectionAtIndex(uint position) internal view returns (ElectionData storage) {
        return _electionStore().elections[position];
    }

    function _getBallot(bytes32 ballotId) internal view returns (BallotData storage) {
        return _getCurrentElection().ballotsById[ballotId];
    }

    function _getBallotInEpoch(bytes32 ballotId, uint epochIndex) internal view returns (BallotData storage) {
        return _getElectionAtIndex(epochIndex).ballotsById[ballotId];
    }

    function _calculateBallotId(address[] memory candidates) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(candidates));
    }

    function _ballotExists(BallotData storage ballot) internal view returns (bool) {
        return ballot.candidates.length != 0;
    }

    function _getBallotVoted(address user) internal view returns (bytes32) {
        return _getCurrentElection().ballotIdsByAddress[user];
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@synthetixio/core-contracts/contracts/utils/SetUtil.sol";

contract ElectionStorage {
    struct ElectionStore {
        // True if initializeElectionModule was called
        bool initialized;
        // The address of the council NFT
        address councilToken;
        // Council member addresses
        SetUtil.AddressSet councilMembers;
        // Council token id's by council member address
        mapping(address => uint) councilTokenIds;
        // Array of EpochData's for each epoch
        EpochData[] epochs;
        // Array of ElectionData's for each election
        ElectionData[] elections;
        // Pointer to ElectionSettings
        // To be always used via store.settings[0] to avoid storage collisions
        mapping(uint => ElectionSettings) settings;
    }

    struct ElectionSettings {
        // Number of council members in the next epoch
        uint8 nextEpochSeatCount;
        // Minimum active council members. If too many are dismissed an emergency election is triggered
        uint8 minimumActiveMembers;
        // Minimum epoch duration when adjusting schedules
        uint64 minEpochDuration;
        // Minimum nomination period duration when adjusting schedules
        uint64 minNominationPeriodDuration;
        // Minimum voting period duration when adjusting schedules
        uint64 minVotingPeriodDuration;
        // Maximum size for tweaking epoch schedules (see tweakEpochSchedule)
        uint64 maxDateAdjustmentTolerance;
        // Default batch size when calling evaluate() with numBallots = 0
        uint defaultBallotEvaluationBatchSize;
    }

    struct EpochData {
        // Date at which the epoch started
        uint64 startDate;
        // Date at which the epoch's voting period will end
        uint64 endDate;
        // Date at which the epoch's nomination period will start
        uint64 nominationPeriodStartDate;
        // Date at which the epoch's voting period will start
        uint64 votingPeriodStartDate;
    }

    struct ElectionData {
        // True if ballots have been counted in this election
        bool evaluated;
        // True if NFTs have been re-shuffled in this election
        bool resolved;
        // Number of counted ballots in this election
        uint numEvaluatedBallots;
        // List of nominated candidates in this election
        SetUtil.AddressSet nominees;
        // List of winners of this election (requires evaluation)
        SetUtil.AddressSet winners;
        // List of all ballot ids in this election
        bytes32[] ballotIds;
        // BallotData by ballot id
        mapping(bytes32 => BallotData) ballotsById;
        // Ballot id that each user voted on
        mapping(address => bytes32) ballotIdsByAddress;
        // Number of votes for each candidate
        mapping(address => uint) candidateVotes;
    }

    struct BallotData {
        // Total accumulated votes in this ballot (needs evaluation)
        uint votes;
        // List of candidates in this ballot
        address[] candidates;
        // Vote power added per voter
        mapping(address => uint) votesByUser;
    }

    function _electionSettings() internal view returns (ElectionSettings storage) {
        return _electionStore().settings[0];
    }

    function _electionStore() internal pure returns (ElectionStore storage store) {
        assembly {
            // bytes32(uint(keccak256("io.synthetix.election")) - 1)
            store.slot := 0x4a7bae7406c7467d50a80c6842d6ba8287c729469098e48fc594351749ba4b22
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SetUtil {
    // ----------------------------------------
    // Address support
    // ----------------------------------------

    struct AddressSet {
        Bytes32Set raw;
    }

    function add(AddressSet storage set, address value) internal {
        add(set.raw, bytes32(uint256(uint160(value))));
    }

    function remove(AddressSet storage set, address value) internal {
        remove(set.raw, bytes32(uint256(uint160(value))));
    }

    function replace(
        AddressSet storage set,
        address value,
        address newValue
    ) internal {
        replace(set.raw, bytes32(uint256(uint160(value))), bytes32(uint256(uint160(newValue))));
    }

    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return contains(set.raw, bytes32(uint256(uint160(value))));
    }

    function length(AddressSet storage set) internal view returns (uint) {
        return length(set.raw);
    }

    function valueAt(AddressSet storage set, uint position) internal view returns (address) {
        return address(uint160(uint256(valueAt(set.raw, position))));
    }

    function positionOf(AddressSet storage set, address value) internal view returns (uint) {
        return positionOf(set.raw, bytes32(uint256(uint160(value))));
    }

    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = values(set.raw);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
    }

    // ----------------------------------------
    // Core bytes32 support
    // ----------------------------------------

    error PositionOutOfBounds();
    error ValueNotInSet();
    error ValueAlreadyInSet();

    struct Bytes32Set {
        /* solhint-disable private-vars-leading-underscore */
        bytes32[] _values;
        mapping(bytes32 => uint) _positions; // Position zero is never used.
        /* solhint-enable private-vars-leading-underscore */
    }

    function add(Bytes32Set storage set, bytes32 value) internal {
        if (contains(set, value)) {
            revert ValueAlreadyInSet();
        }

        set._values.push(value);
        set._positions[value] = set._values.length;
    }

    function remove(Bytes32Set storage set, bytes32 value) internal {
        uint position = set._positions[value];
        if (position == 0) {
            revert ValueNotInSet();
        }

        uint index = position - 1;
        uint lastIndex = set._values.length - 1;

        // If the element being deleted is not the last in the values,
        // move the last element to its position.
        if (index != lastIndex) {
            bytes32 lastValue = set._values[lastIndex];

            set._values[index] = lastValue;
            set._positions[lastValue] = position;
        }

        // Remove the last element in the values.
        set._values.pop();
        delete set._positions[value];
    }

    function replace(
        Bytes32Set storage set,
        bytes32 value,
        bytes32 newValue
    ) internal {
        if (!contains(set, value)) {
            revert ValueNotInSet();
        }

        if (contains(set, newValue)) {
            revert ValueAlreadyInSet();
        }

        uint position = set._positions[value];
        uint index = position - 1;

        set._values[index] = newValue;
        set._positions[newValue] = position;
    }

    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return set._positions[value] != 0;
    }

    function length(Bytes32Set storage set) internal view returns (uint) {
        return set._values.length;
    }

    function valueAt(Bytes32Set storage set, uint position) internal view returns (bytes32) {
        if (position == 0 || position > set._values.length) {
            revert PositionOutOfBounds();
        }

        uint index = position - 1;

        return set._values[index];
    }

    function positionOf(Bytes32Set storage set, bytes32 value) internal view returns (uint) {
        if (!contains(set, value)) {
            revert ValueNotInSet();
        }

        return set._positions[value];
    }

    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return set._values;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AbstractProxy.sol";
import "./ProxyStorage.sol";
import "../errors/AddressError.sol";
import "../utils/AddressUtil.sol";

contract UUPSProxy is AbstractProxy, ProxyStorage {
    constructor(address firstImplementation) {
        if (firstImplementation == address(0)) {
            revert AddressError.ZeroAddress();
        }

        if (!AddressUtil.isContract(firstImplementation)) {
            revert AddressError.NotAContract(firstImplementation);
        }

        _proxyStore().implementation = firstImplementation;
    }

    function _getImplementation() internal view virtual override returns (address) {
        return _proxyStore().implementation;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ArrayError {
    error EmptyArray();
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@synthetixio/core-contracts/contracts/proxy/UUPSImplementation.sol";
import "@synthetixio/core-contracts/contracts/ownership/Ownable.sol";
import "@synthetixio/core-contracts/contracts/token/ERC721.sol";

contract CouncilToken is Ownable, UUPSImplementation, ERC721 {
    error TokenIsNotTransferable();

    function initialize(string memory tokenName, string memory tokenSymbol) public onlyOwner {
        _initialize(tokenName, tokenSymbol, "");
    }

    function upgradeTo(address newImplementation) public override onlyOwner {
        _upgradeTo(newImplementation);
    }

    function mint(address to, uint256 tokenId) public virtual onlyOwner {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) public virtual onlyOwner {
        _burn(tokenId);
    }

    function transferFrom(
        address,
        address,
        uint256
    ) public virtual override {
        revert TokenIsNotTransferable();
    }

    function safeTransferFrom(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override {
        revert TokenIsNotTransferable();
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract AbstractProxy {
    fallback() external payable {
        _forward();
    }

    receive() external payable {
        _forward();
    }

    function _forward() internal {
        address implementation = _getImplementation();

        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldatacopy(0, 0, calldatasize())

            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function _getImplementation() internal view virtual returns (address);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ProxyStorage {
    struct ProxyStore {
        address implementation;
        bool simulatingUpgrade;
    }

    function _proxyStore() internal pure returns (ProxyStore storage store) {
        assembly {
            // bytes32(uint(keccak256("io.synthetix.v3.proxy")) - 1)
            store.slot := 0x32402780481dd8149e50baad867f01da72e2f7d02639a6fe378dbd80b6bb446e
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AddressError {
    error ZeroAddress();
    error NotAContract(address contr);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AddressUtil {
    function isContract(address account) internal view returns (bool) {
        uint256 size;

        assembly {
            size := extcodesize(account)
        }

        return size > 0;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IUUPSImplementation.sol";
import "../errors/AddressError.sol";
import "../errors/ChangeError.sol";
import "../utils/AddressUtil.sol";
import "./ProxyStorage.sol";

abstract contract UUPSImplementation is IUUPSImplementation, ProxyStorage {
    event Upgraded(address implementation);

    error ImplementationIsSterile(address implementation);
    error UpgradeSimulationFailed();

    function _upgradeTo(address newImplementation) internal virtual {
        if (newImplementation == address(0)) {
            revert AddressError.ZeroAddress();
        }

        if (!AddressUtil.isContract(newImplementation)) {
            revert AddressError.NotAContract(newImplementation);
        }

        ProxyStore storage store = _proxyStore();

        if (newImplementation == store.implementation) {
            revert ChangeError.NoChange();
        }

        if (!store.simulatingUpgrade && _implementationIsSterile(newImplementation)) {
            revert ImplementationIsSterile(newImplementation);
        }

        store.implementation = newImplementation;

        emit Upgraded(newImplementation);
    }

    function _implementationIsSterile(address candidateImplementation) internal virtual returns (bool) {
        (bool simulationReverted, bytes memory simulationResponse) = address(this).delegatecall(
            abi.encodeCall(this.simulateUpgradeTo, (candidateImplementation))
        );

        return
            !simulationReverted &&
            keccak256(abi.encodePacked(simulationResponse)) == keccak256(abi.encodePacked(UpgradeSimulationFailed.selector));
    }

    function simulateUpgradeTo(address newImplementation) public override {
        ProxyStore storage store = _proxyStore();

        store.simulatingUpgrade = true;

        address currentImplementation = store.implementation;
        store.implementation = newImplementation;

        (bool rollbackSuccessful, ) = newImplementation.delegatecall(
            abi.encodeCall(this.upgradeTo, (currentImplementation))
        );

        if (!rollbackSuccessful || _proxyStore().implementation != currentImplementation) {
            revert UpgradeSimulationFailed();
        }

        store.simulatingUpgrade = false;

        // solhint-disable-next-line reason-string
        revert();
    }

    function getImplementation() external view override returns (address) {
        return _proxyStore().implementation;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OwnableMixin.sol";
import "../interfaces/IOwnable.sol";
import "../errors/AddressError.sol";
import "../errors/ChangeError.sol";

contract Ownable is IOwnable, OwnableMixin {
    event OwnerNominated(address newOwner);
    event OwnerChanged(address oldOwner, address newOwner);

    error NotNominated(address addr);

    function acceptOwnership() public override {
        OwnableStore storage store = _ownableStore();

        address currentNominatedOwner = store.nominatedOwner;
        if (msg.sender != currentNominatedOwner) {
            revert NotNominated(msg.sender);
        }

        emit OwnerChanged(store.owner, currentNominatedOwner);
        store.owner = currentNominatedOwner;

        store.nominatedOwner = address(0);
    }

    function nominateNewOwner(address newNominatedOwner) public override onlyOwnerIfSet {
        OwnableStore storage store = _ownableStore();

        if (newNominatedOwner == address(0)) {
            revert AddressError.ZeroAddress();
        }

        if (newNominatedOwner == store.nominatedOwner) {
            revert ChangeError.NoChange();
        }

        store.nominatedOwner = newNominatedOwner;
        emit OwnerNominated(newNominatedOwner);
    }

    function renounceNomination() external override {
        OwnableStore storage store = _ownableStore();

        if (store.nominatedOwner != msg.sender) {
            revert NotNominated(msg.sender);
        }

        store.nominatedOwner = address(0);
    }

    function owner() external view override returns (address) {
        return _ownableStore().owner;
    }

    function nominatedOwner() external view override returns (address) {
        return _ownableStore().nominatedOwner;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC721.sol";
import "../interfaces/IERC721Metadata.sol";
import "../interfaces/IERC721Receiver.sol";
import "../errors/AddressError.sol";
import "../errors/AccessError.sol";
import "../errors/InitError.sol";
import "./ERC721Storage.sol";
import "../utils/AddressUtil.sol";
import "../utils/StringUtil.sol";

/*
    Reference implementations:
    * OpenZeppelin - https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol
*/

contract ERC721 is IERC721, IERC721Metadata, ERC721Storage {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    error CannotSelfApprove(address);
    error InvalidTransferRecipient(address);
    error TokenDoesNotExist(uint256);
    error TokenAlreadyMinted(uint256);

    function _initialize(
        string memory tokenName,
        string memory tokenSymbol,
        string memory baseTokenURI
    ) internal virtual {
        ERC721Store storage store = _erc721Store();
        if (bytes(store.name).length > 0 || bytes(store.symbol).length > 0 || bytes(store.baseTokenURI).length > 0) {
            revert InitError.AlreadyInitialized();
        }

        store.name = tokenName;
        store.symbol = tokenSymbol;
        store.baseTokenURI = baseTokenURI;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == this.supportsInterface.selector || // ERC165
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId;
    }

    function balanceOf(address holder) public view virtual override returns (uint) {
        if (holder == address(0)) {
            revert AddressError.ZeroAddress();
        }

        return _erc721Store().balanceOf[holder];
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) {
            revert TokenDoesNotExist(tokenId);
        }

        return _erc721Store().ownerOf[tokenId];
    }

    function name() external view virtual override returns (string memory) {
        return _erc721Store().name;
    }

    function symbol() external view virtual override returns (string memory) {
        return _erc721Store().symbol;
    }

    function tokenURI(uint256 tokenId) external view virtual override returns (string memory) {
        if (!_exists(tokenId)) {
            revert TokenDoesNotExist(tokenId);
        }

        string memory baseURI = _erc721Store().baseTokenURI;

        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, StringUtil.uintToString(tokenId))) : "";
    }

    function approve(address to, uint256 tokenId) public virtual override {
        ERC721Store storage store = _erc721Store();
        address holder = store.ownerOf[tokenId];

        if (to == holder) {
            revert CannotSelfApprove(to);
        }

        if (msg.sender != holder && !isApprovedForAll(holder, msg.sender)) {
            revert AccessError.Unauthorized(msg.sender);
        }

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) {
            revert TokenDoesNotExist(tokenId);
        }

        return _erc721Store().tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        if (msg.sender == operator) {
            revert CannotSelfApprove(operator);
        }

        _erc721Store().operatorApprovals[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address holder, address operator) public view virtual override returns (bool) {
        return _erc721Store().operatorApprovals[holder][operator];
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert AccessError.Unauthorized(msg.sender);
        }

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert AccessError.Unauthorized(msg.sender);
        }

        _transfer(from, to, tokenId);
        if (!_checkOnERC721Received(from, to, tokenId, data)) {
            revert InvalidTransferRecipient(to);
        }
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _erc721Store().ownerOf[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address holder = ownerOf(tokenId);

        // Not checking tokenId existence since it is checked in ownerOf() and getApproved()

        return (spender == holder || getApproved(tokenId) == spender || isApprovedForAll(holder, spender));
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        ERC721Store storage store = _erc721Store();
        if (to == address(0)) {
            revert AddressError.ZeroAddress();
        }

        if (_exists(tokenId)) {
            revert TokenAlreadyMinted(tokenId);
        }

        store.balanceOf[to] += 1;
        store.ownerOf[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual {
        ERC721Store storage store = _erc721Store();
        address holder = store.ownerOf[tokenId];

        _approve(address(0), tokenId);

        store.balanceOf[holder] -= 1;
        delete store.ownerOf[tokenId];

        emit Transfer(holder, address(0), tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        ERC721Store storage store = _erc721Store();

        if (ownerOf(tokenId) != from) {
            revert AccessError.Unauthorized(from);
        }

        if (to == address(0)) {
            revert AddressError.ZeroAddress();
        }

        // Clear approvals from the previous holder
        _approve(address(0), tokenId);

        store.balanceOf[from] -= 1;
        store.balanceOf[to] += 1;
        store.ownerOf[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal virtual {
        _erc721Store().tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (AddressUtil.isContract(to)) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch {
                return false;
            }
        } else {
            return true;
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUUPSImplementation {
    function upgradeTo(address newImplementation) external;

    function simulateUpgradeTo(address newImplementation) external;

    function getImplementation() external view returns (address);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ChangeError {
    error NoChange();
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOwnable {
    function acceptOwnership() external;

    function nominateNewOwner(address newNominatedOwner) external;

    function renounceNomination() external;

    function owner() external view returns (address);

    function nominatedOwner() external view returns (address);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC165.sol";

interface IERC721 is IERC165 {
    function balanceOf(address owner) external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function approve(address approved, uint256 tokenId) external;

    function setApprovalForAll(address operator, bool approved) external;

    function getApproved(uint256 tokenId) external view returns (address);

    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC165.sol";

interface IERC721Metadata is IERC165 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function tokenURI(uint256 tokenId) external view returns (string memory);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
    ) external returns (bytes4);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ERC721Storage {
    struct ERC721Store {
        string name;
        string symbol;
        string baseTokenURI;
        mapping(uint256 => address) ownerOf;
        mapping(address => uint256) balanceOf;
        mapping(uint256 => address) tokenApprovals;
        mapping(address => mapping(address => bool)) operatorApprovals;
    }

    function _erc721Store() internal pure returns (ERC721Store storage store) {
        assembly {
            // bytes32(uint(keccak256("io.synthetix.ERC721")) - 1)
            store.slot := 0xcff586616dbfd8fcbd4d6ec876c80f6e96179ad989cea8424b590d1e270e5bcf
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
    Reference implementations:
    * OpenZeppelin - https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol
*/

library StringUtil {
    function uintToString(uint value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IDebtShare.sol";
import "@synthetixio/core-contracts/contracts/utils/SetUtil.sol";

contract DebtShareStorage {
    struct DebtShareStore {
        // Synthetix c2 DebtShare contract used to determine vote power in the local chain
        IDebtShare debtShareContract;
        // Array of debt share snapshot id's for each epoch
        uint128[] debtShareIds;
        // Array of CrossChainDebtShareData's for each epoch
        CrossChainDebtShareData[] crossChainDebtShareData;
    }

    struct CrossChainDebtShareData {
        // Synthetix v2 cross chain debt share merkle root
        bytes32 merkleRoot;
        // Cross chain debt share merkle root snapshot blocknumber
        uint merkleRootBlockNumber;
        // Cross chain debt shares declared on this chain
        mapping(address => uint) debtShares;
    }

    function _debtShareStore() internal pure returns (DebtShareStore storage store) {
        assembly {
            // bytes32(uint(keccak256("io.synthetix.debtshare")) - 1)
            store.slot := 0x24dbf425c80a2b812a860ebf3bf1d082b94299e66be3feb971f862ad0811d2b8
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDebtShare {
    function balanceOfOnPeriod(address account, uint periodId) external view returns (uint);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Based on OpenZeppelin https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MerkleProof.sol
library MerkleProof {
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = _efficientHash(computedHash, proofElement);
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = _efficientHash(proofElement, computedHash);
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}