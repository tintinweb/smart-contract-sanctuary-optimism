//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ElectionInspectorModule as BaseElectionInspectorModule} from "@synthetixio/core-modules/contracts/modules/ElectionInspectorModule.sol";

// solhint-disable-next-line no-empty-blocks
contract ElectionInspectorModule is BaseElectionInspectorModule {

}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IElectionInspectorModule.sol";
import "../submodules/election/ElectionBase.sol";

contract ElectionInspectorModule is IElectionInspectorModule, ElectionBase {
    using SetUtil for SetUtil.AddressSet;

    function getEpochStartDateForIndex(uint epochIndex) external view override returns (uint64) {
        return _getEpochAtIndex(epochIndex).startDate;
    }

    function getEpochEndDateForIndex(uint epochIndex) external view override returns (uint64) {
        return _getEpochAtIndex(epochIndex).endDate;
    }

    function getNominationPeriodStartDateForIndex(uint epochIndex) external view override returns (uint64) {
        return _getEpochAtIndex(epochIndex).nominationPeriodStartDate;
    }

    function getVotingPeriodStartDateForIndex(uint epochIndex) external view override returns (uint64) {
        return _getEpochAtIndex(epochIndex).votingPeriodStartDate;
    }

    function wasNominated(address candidate, uint epochIndex) external view override returns (bool) {
        return _getElectionAtIndex(epochIndex).nominees.contains(candidate);
    }

    function getNomineesAtEpoch(uint epochIndex) external view override returns (address[] memory) {
        return _getElectionAtIndex(epochIndex).nominees.values();
    }

    function getBallotVotedAtEpoch(address user, uint epochIndex) public view override returns (bytes32) {
        return _getElectionAtIndex(epochIndex).ballotIdsByAddress[user];
    }

    function hasVotedInEpoch(address user, uint epochIndex) external view override returns (bool) {
        return getBallotVotedAtEpoch(user, epochIndex) != bytes32(0);
    }

    function getBallotVotesInEpoch(bytes32 ballotId, uint epochIndex) external view override returns (uint) {
        return _getBallotInEpoch(ballotId, epochIndex).votes;
    }

    function getBallotCandidatesInEpoch(bytes32 ballotId, uint epochIndex)
        external
        view
        override
        returns (address[] memory)
    {
        return _getBallotInEpoch(ballotId, epochIndex).candidates;
    }

    function getCandidateVotesInEpoch(address candidate, uint epochIndex) external view override returns (uint) {
        return _getElectionAtIndex(epochIndex).candidateVotes[candidate];
    }

    function getElectionWinnersInEpoch(uint epochIndex) external view override returns (address[] memory) {
        return _getElectionAtIndex(epochIndex).winners.values();
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Module that simply adds view functions to retrieve additional info from the election module, such as historical election info
/// @dev View functions add to contract size, since they bloat the Solidity function dispatcher
interface IElectionInspectorModule {
    // ---------------------------------------
    // View functions
    // ---------------------------------------

    /// @notice Returns the date in which the given epoch started
    function getEpochStartDateForIndex(uint epochIndex) external view returns (uint64);

    /// @notice Returns the date in which the given epoch ended
    function getEpochEndDateForIndex(uint epochIndex) external view returns (uint64);

    /// @notice Returns the date in which the Nomination period in the given epoch started
    function getNominationPeriodStartDateForIndex(uint epochIndex) external view returns (uint64);

    /// @notice Returns the date in which the Voting period in the given epoch started
    function getVotingPeriodStartDateForIndex(uint epochIndex) external view returns (uint64);

    /// @notice Shows if a candidate was nominated in the given epoch
    function wasNominated(address candidate, uint epochIndex) external view returns (bool);

    /// @notice Returns a list of all nominated candidates in the given epoch
    function getNomineesAtEpoch(uint epochIndex) external view returns (address[] memory);

    /// @notice Returns the ballot id that user voted on in the given election
    function getBallotVotedAtEpoch(address user, uint epochIndex) external view returns (bytes32);

    /// @notice Returns if user has voted in the given election
    function hasVotedInEpoch(address user, uint epochIndex) external view returns (bool);

    /// @notice Returns the number of votes given to a particular ballot in a given epoch
    function getBallotVotesInEpoch(bytes32 ballotId, uint epochIndex) external view returns (uint);

    /// @notice Returns the list of candidates that a particular ballot has in a given epoch
    function getBallotCandidatesInEpoch(bytes32 ballotId, uint epochIndex) external view returns (address[] memory);

    /// @notice Returns the number of votes a candidate received in a given epoch
    function getCandidateVotesInEpoch(address candidate, uint epochIndex) external view returns (uint);

    /// @notice Returns the winners of the given election
    function getElectionWinnersInEpoch(uint epochIndex) external view returns (address[] memory);
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

    function _getEpochAtIndex(uint epochIndex) internal view returns (EpochData storage) {
        return _electionStore().epochs[epochIndex];
    }

    function _getCurrentElection() internal view returns (ElectionData storage) {
        return _getElectionAtIndex(_getCurrentEpochIndex());
    }

    function _getElectionAtIndex(uint epochIndex) internal view returns (ElectionData storage) {
        return _electionStore().elections[epochIndex];
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