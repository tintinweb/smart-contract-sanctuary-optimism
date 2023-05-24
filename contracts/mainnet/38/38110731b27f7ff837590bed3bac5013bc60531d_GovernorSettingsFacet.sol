// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IGovernorSettings} from "src/interfaces/IGovernorSettings.sol";
import {GovernorStorage} from "src/utils/GovernorStorage.sol";

/**
 * @title Origami Governor Settings Facet
 * @author Origami
 * @notice Logic for interacting with the Origami Governor configuration settings.
 * @dev This facet is not intended to be used directly, but rather through the OrigamiGovernorDiamond interface.
 * @custom:security-contact [email protected]
 */
contract GovernorSettingsFacet is IGovernorSettings {
    /**
     * @dev Returns the default counting strategy.
     * @return the default counting strategy.
     */
    function defaultCountingStrategy() external view returns (bytes4) {
        return config().defaultCountingStrategy;
    }

    /**
     * @dev Returns the default proposal token address.
     * @return the default proposal token address.
     */
    function defaultProposalToken() public view override returns (address) {
        return config().defaultProposalToken;
    }

    /**
     * @notice public interface to retrieve the configured governance token.
     * @return the governance token address.
     */
    function governanceToken() public view override returns (address) {
        return config().governanceToken;
    }

    /**
     * @notice public interface to retrieve the configured membership token.
     * @return the membership token address.
     */
    function membershipToken() public view override returns (address) {
        return config().membershipToken;
    }

    /**
     * @notice public interface to retrieve the configured proposal threshold.
     * @return the threshold for the proposal. Should always be 1.
     */
    function proposalThreshold() public view returns (uint256) {
        return config().proposalThreshold;
    }

    /**
     * @notice public interface to retrieve the configured proposal threshold token.
     * @return the token address for the proposal threshold.
     */
    function proposalThresholdToken() public view returns (address) {
        return config().proposalThresholdToken;
    }

    /**
     * @notice public interface to retrieve the configured quorum numerator.
     * @return the quorum numerator for the proposal.
     */
    function quorumNumerator() public view returns (uint128) {
        return config().quorumNumerator;
    }

    /**
     * @notice public interface to retrieve the configured quorum denominator.
     * @return the quorum denominator for the proposal.
     */
    function quorumDenominator() public view returns (uint128) {
        return config().quorumDenominator;
    }

    /**
     * @notice Enumerates the delay in blocks between proposal creation and voting start.
     * @return delay the delay between proposal creation and voting start.
     */
    function votingDelay() public view returns (uint64) {
        return config().votingDelay;
    }

    /**
     * @notice Enumerates the duration in blocks of the voting period.
     * @return period the duration of the voting period.
     */
    function votingPeriod() public view returns (uint64) {
        return config().votingPeriod;
    }

    /**
     * @notice sets the default counting strategy.
     * @param newDefaultCountingStrategy a bytes4 selector for the new default counting strategy.
     * emits DefaultCountingStrategySet event.
     */
    function setDefaultCountingStrategy(bytes4 newDefaultCountingStrategy) public onlyGovernance {
        GovernorStorage.setDefaultCountingStrategy(newDefaultCountingStrategy);
    }

    /**
     * @notice sets the default proposal token.
     * @param newDefaultProposalToken the new default proposal token address.
     * emits DefaultProposalTokenSet event.
     */
    function setDefaultProposalToken(address newDefaultProposalToken) public onlyGovernance {
        GovernorStorage.setDefaultProposalToken(newDefaultProposalToken);
    }

    /**
     * @notice sets the Governance token.
     * @param newGovernanceToken the new governance token address.
     * emits GovernanceTokenSet event.
     */
    function setGovernanceToken(address newGovernanceToken) public onlyGovernance {
        GovernorStorage.setGovernanceToken(newGovernanceToken);
    }

    /**
     * @notice sets the Membership token.
     * @param newMembershipToken the new membership token address.
     * emits MembershipTokenSet event.
     */
    function setMembershipToken(address newMembershipToken) public onlyGovernance {
        GovernorStorage.setMembershipToken(newMembershipToken);
    }

    /**
     * @notice Sets the voting delay.
     * @param newVotingDelay the new voting delay.
     * emits VotingDelaySet event.
     */
    function setVotingDelay(uint64 newVotingDelay) public onlyGovernance {
        GovernorStorage.setVotingDelay(newVotingDelay);
    }

    /**
     * @notice Sets the proposal threshold.
     * @param newProposalThreshold the new proposal threshold.
     * emits ProposalThresholdSet event.
     */
    function setProposalThreshold(uint64 newProposalThreshold) public onlyGovernance {
        GovernorStorage.setProposalThreshold(newProposalThreshold);
    }

    /**
     * @notice Sets the proposal threshold token.
     * @param newProposalThresholdToken the new proposal threshold token.
     * emits ProposalThresholdTokenSet event.
     */
    function setProposalThresholdToken(address newProposalThresholdToken) public onlyGovernance {
        GovernorStorage.setProposalThresholdToken(newProposalThresholdToken);
    }

    /**
     * @notice Sets the quorum numerator.
     * @param newQuorumNumerator the new quorum numerator.
     * emits QuorumNumeratorSet event.
     */
    function setQuorumNumerator(uint128 newQuorumNumerator) public onlyGovernance {
        GovernorStorage.setQuorumNumerator(newQuorumNumerator);
    }

    /**
     * @notice Sets the quorum denominator.
     * @param newQuorumDenominator the new quorum denominator.
     * emits QuorumDenominatorSet event.
     */
    function setQuorumDenominator(uint128 newQuorumDenominator) public onlyGovernance {
        GovernorStorage.setQuorumDenominator(newQuorumDenominator);
    }

    /**
     * @notice Sets the voting period.
     * @param newVotingPeriod the new voting period.
     * emits VotingPeriodSet event.
     */
    function setVotingPeriod(uint64 newVotingPeriod) public onlyGovernance {
        GovernorStorage.setVotingPeriod(newVotingPeriod);
    }

    /**
     * @notice update proposal token validity.
     * @param proposalToken the proposal token address.
     * @param valid whether the proposal token is valid.
     * emits ProposalTokenValidSet event.
     */
    function enableProposalToken(address proposalToken, bool valid) public onlyGovernance {
        GovernorStorage.enableProposalToken(proposalToken, valid);
    }

    /**
     * @notice update counting strategy validity.
     * @param countingStrategy the counting strategy bytes4 selector.
     * @param valid whether the counting strategy is valid.
     * emits CountingStrategyValidSet event.
     */
    function enableCountingStrategy(bytes4 countingStrategy, bool valid) public onlyGovernance {
        GovernorStorage.enableCountingStrategy(countingStrategy, valid);
    }

    /**
     * @dev returns the GovernorConfig storage pointer.
     */
    function config() internal pure returns (GovernorStorage.GovernorConfig storage) {
        return GovernorStorage.configStorage();
    }

    /**
     * @dev restricts interaction to the timelock contract.
     */
    modifier onlyGovernance() {
        require(msg.sender == GovernorStorage.configStorage().timelock, "Governor: onlyGovernance");
        _;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {GovernorStorage} from "src/utils/GovernorStorage.sol";

/**
 * @title Simple Counting strategy
 * @author Origami
 * @notice Implements swappable counting strategies at the proposal level.
 * @custom:security-contact [email protected]
 */
library TokenWeightStrategy {
    bytes4 internal constant simpleWeightSelector = bytes4(keccak256("simpleWeight(uint256)"));
    bytes4 internal constant quadraticWeightSelector = bytes4(keccak256("quadraticWeight(uint256)"));

    /**
     * @notice Checks if the provided selector is a known strategy.
     * @param weightingSelector the selector to check.
     * @return true if the selector is a known strategy.
     */
    function knownStrategy(bytes4 weightingSelector) internal pure returns (bool) {
        return weightingSelector == simpleWeightSelector || weightingSelector == quadraticWeightSelector;
    }

    /**
     * @notice Applies the indicated weighting strategy to the amount `weight` that is supplied.
     * @dev the staticcall is only executed against this contract and is checked for success before failing to a revert if the selector isn't found on this contract.
     * @param weight the token weight to apply the weighting strategy to.
     * @param weightingSelector an encoded selector to use as a weighting strategy implementation.
     * @return the weight with the weighting strategy applied to it.
     */
    function applyStrategy(uint256 weight, bytes4 weightingSelector) internal pure returns (uint256) {
        if (weightingSelector == simpleWeightSelector) {
            return simpleWeight(weight);
        } else if (weightingSelector == quadraticWeightSelector) {
            return quadraticWeight(weight);
        } else {
            revert("Governor: weighting strategy not found");
        }
    }

    /**
     * @notice simple weight calculation does not apply any weighting strategy. It is an integer identity function.
     * @param weight the weight to apply the weighting strategy to.
     * @return the weight with the weighting strategy applied to it.
     */
    function simpleWeight(uint256 weight) internal pure returns (uint256) {
        return weight;
    }

    /**
     * @notice quadratic weight calculation returns square root of the weight.
     * @param weight the weight to apply the weighting strategy to.
     * @return the weight with the weighting strategy applied to it.
     */
    function quadraticWeight(uint256 weight) internal pure returns (uint256) {
        return squareRoot(weight);
    }

    /**
     * @dev square root algorithm from https://github.com/ethereum/dapp-bin/pull/50#issuecomment-1075267374
     * @param x the number to derive the square root of.
     * @return y - the square root of x.
     */
    function squareRoot(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IGovernorSettings {
    /**
     * @dev Returns the default counting strategy.
     */
    function defaultCountingStrategy() external view returns (bytes4);

    /**
     * @dev Returns the default proposal token address.
     */
    function defaultProposalToken() external view returns (address);

    /**
     * @dev Returns the governance token address.
     */
    function governanceToken() external view returns (address);

    /**
     * @dev Returns the membership token address.
     */
    function membershipToken() external view returns (address);

    /**
     * @dev Returns the number of votes required in order for a voter to become a proposer.
     */
    function proposalThreshold() external view returns (uint256);

    /**
     * @dev Returns the token to use for proposal threshold.
     */
    function proposalThresholdToken() external view returns (address);

    /**
     * @dev Returns the quorum numerator for the proposal.
     */
    function quorumNumerator() external view returns (uint128);

    /**
     * @dev Returns the quorum denominator for the proposal.
     */
    function quorumDenominator() external view returns (uint128);

    /**
     * @dev Returns the delay before voting on a proposal may take place, once proposed.
     */
    function votingDelay() external view returns (uint64);

    /**
     * @dev Returns the duration of voting on a proposal, in blocks.
     */
    function votingPeriod() external view returns (uint64);

    /**
     * @dev sets the default counting strategy.
     * @param newDefaultCountingStrategy a bytes4 selector for the new default counting strategy.
     * Emits a {DefaultCountingStrategySet} event.
     */
    function setDefaultCountingStrategy(bytes4 newDefaultCountingStrategy) external;

    /**
     * @dev Sets the default proposal token.
     * @param newDefaultProposalToken The new default proposal token.
     * Emits a {DefaultProposalTokenSet} event.
     */
    function setDefaultProposalToken(address newDefaultProposalToken) external;

    /**
     * @dev Sets the governance token.
     * @param newGovernanceToken The new governance token.
     * Emits a {GovernanceTokenSet} event.
     */
    function setGovernanceToken(address newGovernanceToken) external;

    /**
     * @dev Sets the membership token.
     * @param newMembershipToken The new membership token.
     * Emits a {MembershipTokenSet} event.
     */
    function setMembershipToken(address newMembershipToken) external;

    /**
     * @dev Sets the proposal threshold.
     * @param newProposalThreshold The new proposal threshold.
     * Emits a {ProposalThresholdSet} event.
     */
    function setProposalThreshold(uint64 newProposalThreshold) external;

    /**
     * @dev Returns the token to use for proposal threshold.
     * Emits a {ProposalThresholdTokenSet} event.
     */
    function setProposalThresholdToken(address newProposalThresholdToken) external;

    /**
     * @dev Sets the quorum numerator.
     * @param newQuorumNumerator The new quorum numerator.
     * Emits a {QuorumNumeratorSet} event.
     */
    function setQuorumNumerator(uint128 newQuorumNumerator) external;

    /**
     * @dev Sets the quorum denominator.
     * @param newQuorumDenominator The new quorum denominator.
     * Emits a {QuorumDenominatorSet} event.
     */
    function setQuorumDenominator(uint128 newQuorumDenominator) external;

    /**
     * @dev Sets the voting delay.
     * @param newVotingDelay The new voting delay.
     * Emits a {VotingDelaySet} event.
     */
    function setVotingDelay(uint64 newVotingDelay) external;

    /**
     * @dev Sets the voting period.
     * @param newVotingPeriod The new voting period.
     * Emits a {VotingPeriodSet} event.
     */
    function setVotingPeriod(uint64 newVotingPeriod) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {TokenWeightStrategy} from "src/governor/lib/TokenWeightStrategy.sol";

library GovernorStorage {
    bytes32 public constant CONFIG_STORAGE_POSITION = keccak256("com.origami.governor.configStorage");
    bytes32 public constant PROPOSAL_STORAGE_POSITION = keccak256("com.origami.governor.proposalStorage");

    /**
     * @dev Emitted when a counting strategy's validity is enabled.
     * @param countingStrategy The counting strategy's bytes4 signature.
     * @param enabled Whether the counting strategy is enabled.
     */
    event CountingStrategyEnabled(bytes4 countingStrategy, bool enabled);

    /**
     * @dev Emitted when the default counting strategy is set.
     * @param oldDefaultCountingStrategy The previous default counting strategy.
     * @param newDefaultCountingStrategy The new default counting strategy.
     */
    event DefaultCountingStrategySet(bytes4 oldDefaultCountingStrategy, bytes4 newDefaultCountingStrategy);

    /**
     * @dev Emitted when the default proposal token is set.
     * @param oldDefaultProposalToken The previous default proposal token.
     * @param newDefaultProposalToken The new default proposal token.
     */
    event DefaultProposalTokenSet(address oldDefaultProposalToken, address newDefaultProposalToken);

    /**
     * @dev Emitted when the proposal token is enabled or disabled.
     * @param proposalToken The proposal token's address.
     * @param enabled Whether the proposal token is enabled.
     */
    event ProposalTokenEnabled(address proposalToken, bool enabled);

    /**
     * @dev Emitted when the voting delay is set.
     * @param oldVotingDelay The previous voting delay.
     * @param newVotingDelay The new voting delay.
     */
    event VotingDelaySet(uint64 oldVotingDelay, uint64 newVotingDelay);

    /**
     * @dev Emitted when the voting period is set.
     * @param oldVotingPeriod The previous voting period.
     * @param newVotingPeriod The new voting period.
     */
    event VotingPeriodSet(uint64 oldVotingPeriod, uint64 newVotingPeriod);

    /**
     * @dev Emitted when the proposal threshold is set.
     * @param oldProposalThreshold The previous proposal threshold.
     * @param newProposalThreshold The new proposal threshold.
     */
    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);

    /**
     * @dev Emitted when the proposal threshold token is set.
     * @param oldProposalThresholdToken The previous proposal threshold.
     * @param newProposalThresholdToken The new proposal threshold.
     */
    event ProposalThresholdTokenSet(address oldProposalThresholdToken, address newProposalThresholdToken);

    /**
     * @dev Emitted when the quorum numerator is set.
     * @param oldQuorumNumerator The previous quorum numerator.
     * @param newQuorumNumerator The new quorum numerator.
     */
    event QuorumNumeratorSet(uint128 oldQuorumNumerator, uint128 newQuorumNumerator);

    /**
     * @dev Emitted when the quorum denominator is set.
     * @param oldQuorumDenominator The previous quorum denominator.
     * @param newQuorumDenominator The new quorum denominator.
     */
    event QuorumDenominatorSet(uint128 oldQuorumDenominator, uint128 newQuorumDenominator);

    /**
     * @dev Emitted when the membership token is set.
     * @param oldMembershipToken The previous membership token.
     * @param newMembershipToken The new membership token.
     */
    event MembershipTokenSet(address oldMembershipToken, address newMembershipToken);

    /**
     * @dev Emitted when the governance token is set.
     * @param oldGovernanceToken The previous governance token.
     * @param newGovernanceToken The new governance token.
     */
    event GovernanceTokenSet(address oldGovernanceToken, address newGovernanceToken);

    struct ProposalCore {
        address proposalToken;
        bytes4 countingStrategy;
        uint128 quorumNumerator;
        uint128 quorumDenominator;
        uint256 snapshot;
        uint256 deadline;
        bytes params;
        bool canceled;
        bool executed;
    }

    struct GovernorConfig {
        string name;
        address admin;
        address payable timelock;
        address defaultProposalToken;
        bytes4 defaultCountingStrategy;
        address membershipToken;
        address governanceToken;
        address proposalThresholdToken;
        uint64 votingDelay; // 2^64 seconds is 585 years
        uint64 votingPeriod;
        uint128 quorumNumerator;
        uint128 quorumDenominator;
        uint256 proposalThreshold;
        mapping(address => bool) proposalTokens;
        mapping(bytes4 => bool) countingStrategies;
    }

    struct TimelockQueue {
        uint256 timestamp;
    }

    struct ProposalStorage {
        // proposalId => ProposalCore
        mapping(uint256 => ProposalCore) proposals;
        // proposalId => voter address => voteBytes
        mapping(uint256 => mapping(address => bytes)) proposalVote;
        // proposalId => voter addresses (provides index)
        mapping(uint256 => address[]) proposalVoters;
        // proposalId => voter address => true if voted
        mapping(uint256 => mapping(address => bool)) proposalHasVoted;
        // proposalId => TimelockQueue
        mapping(uint256 => TimelockQueue) timelockQueue;
        // voter address => nonce
        mapping(address => uint256) nonces;
    }

    /**
     * @dev returns the ConfigStorage location.
     */
    function configStorage() internal pure returns (GovernorConfig storage gs) {
        bytes32 position = CONFIG_STORAGE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            gs.slot := position
        }
    }

    /**
     * @dev determines if the provided token is the membership token or
     *  governance token. This is useful to ensure that functions that allow
     *  specifying a token address can't use unexpected tokens.
     * @param token the token address to check.
     * @return true if the token is the membership token or governance token.
     */
    function isConfiguredToken(address token) internal view returns (bool) {
        GovernorConfig storage cs = configStorage();
        return token == cs.membershipToken || token == cs.governanceToken;
    }

    /**
     * @notice determine if a counting strategy is enabled.
     * @param countingStrategy the counting strategy to check.
     * @return true if the counting strategy is enabled.
     */
    function isCountingStrategyEnabled(bytes4 countingStrategy) internal view returns (bool) {
        return configStorage().countingStrategies[countingStrategy];
    }

    /**
     * @notice determine if a token is enabled for proposal creation.
     * @param token the token address to check.
     * @return true if the token is enabled for proposal creation.
     */
    function isProposalTokenEnabled(address token) internal view returns (bool) {
        return configStorage().proposalTokens[token];
    }

    /**
     * @notice sets the default counting strategy.
     * @param newDefaultCountingStrategy the new default counting strategy address.
     * emits DefaultCountingStrategySet event.
     */
    function setDefaultCountingStrategy(bytes4 newDefaultCountingStrategy) internal {
        bytes4 oldDefaultCountingStrategy = configStorage().defaultCountingStrategy;
        configStorage().defaultCountingStrategy = newDefaultCountingStrategy;

        emit DefaultCountingStrategySet(oldDefaultCountingStrategy, newDefaultCountingStrategy);
    }

    /**
     * @notice sets the default proposal token.
     * @param newDefaultProposalToken the new default proposal token address.
     * emits DefaultProposalTokenSet event.
     */
    function setDefaultProposalToken(address newDefaultProposalToken) internal {
        address oldDefaultProposalToken = configStorage().defaultProposalToken;
        configStorage().defaultProposalToken = newDefaultProposalToken;

        emit DefaultProposalTokenSet(oldDefaultProposalToken, newDefaultProposalToken);
    }

    /**
     * @notice set proposal token validity
     * @param proposalToken the proposal token address.
     * @param enabled true if the proposal token is valid.
     * emits ProposalTokenEnabled event.
     */
    function enableProposalToken(address proposalToken, bool enabled) internal {
        require(isConfiguredToken(proposalToken), "Governor: proposal token must be a configured token");
        configStorage().proposalTokens[proposalToken] = enabled;

        emit ProposalTokenEnabled(proposalToken, enabled);
    }

    /**
     * @notice set counting strategy validity
     * @param countingStrategy the counting strategy selector.
     * @param enabled true if the counting strategy is valid.
     * emits CountingStrategyEnabled event.
     */
    function enableCountingStrategy(bytes4 countingStrategy, bool enabled) internal {
        // ensure it's a valid counting strategy selector
        require(TokenWeightStrategy.knownStrategy(countingStrategy), "Governor: counting strategy must be known");
        configStorage().countingStrategies[countingStrategy] = enabled;

        emit CountingStrategyEnabled(countingStrategy, enabled);
    }

    /**
     * @notice sets the Governance token.
     * @param newGovernanceToken the new governance token address.
     * emits GovernanceTokenSet event.
     */
    function setGovernanceToken(address newGovernanceToken) internal {
        address oldGovernanceToken = configStorage().governanceToken;
        configStorage().governanceToken = newGovernanceToken;

        emit GovernanceTokenSet(oldGovernanceToken, newGovernanceToken);
    }

    /**
     * @notice sets the Membership token.
     * @param newMembershipToken the new membership token address.
     * emits MembershipTokenSet event.
     */
    function setMembershipToken(address newMembershipToken) internal {
        address oldMembershipToken = configStorage().membershipToken;
        configStorage().membershipToken = newMembershipToken;

        emit MembershipTokenSet(oldMembershipToken, newMembershipToken);
    }

    /**
     * @notice Sets the proposal threshold.
     * @param newProposalThreshold the new proposal threshold.
     * emits ProposalThresholdSet event.
     */
    function setProposalThreshold(uint64 newProposalThreshold) internal {
        uint256 oldProposalThreshold = configStorage().proposalThreshold;
        configStorage().proposalThreshold = newProposalThreshold;

        emit ProposalThresholdSet(oldProposalThreshold, newProposalThreshold);
    }

    /**
     * @notice Sets the proposal threshold token.
     * @param newProposalThresholdToken the new proposal threshold token.
     * emits ProposalThresholdTokenSet event.
     */
    function setProposalThresholdToken(address newProposalThresholdToken) internal {
        address oldProposalThresholdToken = configStorage().proposalThresholdToken;
        configStorage().proposalThresholdToken = newProposalThresholdToken;

        emit ProposalThresholdTokenSet(oldProposalThresholdToken, newProposalThresholdToken);
    }

    /**
     * @notice Sets the quorum numerator.
     * @param newQuorumNumerator the new quorum numerator.
     * emits QuorumNumeratorSet event.
     */
    function setQuorumNumerator(uint128 newQuorumNumerator) internal {
        uint128 oldQuorumNumerator = configStorage().quorumNumerator;
        configStorage().quorumNumerator = newQuorumNumerator;

        emit QuorumNumeratorSet(oldQuorumNumerator, newQuorumNumerator);
    }

    /**
     * @notice Sets the quorum denominator.
     * @param newQuorumDenominator the new quorum denominator.
     * emits QuorumDenominatorSet event.
     */
    function setQuorumDenominator(uint128 newQuorumDenominator) internal {
        uint128 oldQuorumDenominator = configStorage().quorumDenominator;
        configStorage().quorumDenominator = newQuorumDenominator;

        emit QuorumDenominatorSet(oldQuorumDenominator, newQuorumDenominator);
    }

    /**
     * @notice Sets the voting delay.
     * @param newVotingDelay the new voting delay.
     * emits VotingDelaySet event.
     */
    function setVotingDelay(uint64 newVotingDelay) internal {
        uint64 oldVotingDelay = configStorage().votingDelay;
        configStorage().votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay, newVotingDelay);
    }

    /**
     * @notice Sets the voting period.
     * @param newVotingPeriod the new voting period.
     * emits VotingPeriodSet event.
     */
    function setVotingPeriod(uint64 newVotingPeriod) internal {
        uint64 oldVotingPeriod = configStorage().votingPeriod;
        configStorage().votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, newVotingPeriod);
    }

    /**
     * @dev returns the ProposalStorage location.
     */
    function proposalStorage() internal pure returns (ProposalStorage storage ps) {
        bytes32 position = PROPOSAL_STORAGE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            ps.slot := position
        }
    }

    /**
     * @notice creates a new proposal.
     * @param proposalId the proposal id.
     * @param proposalToken the proposal token.
     * @param countingStrategy the counting strategy.
     * @return ps the proposal core storage.
     */
    function createProposal(uint256 proposalId, address proposalToken, bytes4 countingStrategy)
        internal
        returns (ProposalCore storage ps)
    {
        // start populating the new ProposalCore struct
        ps = proposal(proposalId);
        GovernorConfig storage cs = configStorage();

        require(ps.snapshot == 0, "Governor: proposal already exists");

        ps.proposalToken = proposalToken;
        ps.countingStrategy = countingStrategy;
        ps.quorumNumerator = cs.quorumNumerator;
        ps.quorumDenominator = cs.quorumDenominator;
        // An epoch exceeding max UINT64 is 584,942,417,355 years from now.
        ps.snapshot = uint64(block.timestamp + cs.votingDelay);
        ps.deadline = ps.snapshot + cs.votingPeriod;

        return ps;
    }

    /**
     * @notice returns the proposal core storage.
     * @param proposalId the proposal id.
     * @return ps the proposal core storage.
     */
    function proposal(uint256 proposalId) internal view returns (ProposalCore storage) {
        return proposalStorage().proposals[proposalId];
    }

    /**
     * @notice returns the vote for an account on a particular proposal.
     * @param proposalId the proposal id.
     * @param account the account.
     * @return the bytes representation of the vote
     */
    function proposalVote(uint256 proposalId, address account) internal view returns (bytes memory) {
        return proposalStorage().proposalVote[proposalId][account];
    }

    /**
     * @notice sets the vote for an account on a particular proposal.
     * @param proposalId the proposal id.
     * @param account the account.
     * @param vote the bytes representation of the vote
     */
    function setProposalVote(uint256 proposalId, address account, bytes memory vote) internal {
        proposalStorage().proposalVote[proposalId][account] = vote;
    }

    /**
     * @notice returns the list of voters for a particular proposal.
     * @param proposalId the proposal id.
     * @return the list of voters.
     */
    function proposalVoters(uint256 proposalId) internal view returns (address[] storage) {
        return proposalStorage().proposalVoters[proposalId];
    }

    /**
     * @notice returns whether an account has voted on a particular proposal.
     * @param proposalId the proposal id.
     * @param account the account.
     * @return true if the account has voted on the proposal.
     */
    function proposalHasVoted(uint256 proposalId, address account) internal view returns (bool) {
        return proposalStorage().proposalHasVoted[proposalId][account];
    }

    /**
     * @notice call to indicate that an account has voted on a particular proposal.
     * @param proposalId the proposal id.
     * @param account the account.
     */
    function setProposalHasVoted(uint256 proposalId, address account) internal {
        proposalStorage().proposalHasVoted[proposalId][account] = true;
    }

    /**
     * @notice returns the account's current nonce.
     * @param account the account.
     * @return the account's nonce.
     */
    function getAccountNonce(address account) internal view returns (uint256) {
        return proposalStorage().nonces[account];
    }

    /**
     * @notice increments the account's nonce.
     * @param account the account.
     */
    function incrementAccountNonce(address account) internal {
        // This function is unchecked because it is virtually impossible to
        // overflow the nonce.  If a given account submitted one proposal per
        // second forever, it would take 5.44 septillion years to overflow.
        // ChatGPT agrees that's a long time.
        unchecked {
            GovernorStorage.proposalStorage().nonces[account]++;
        }
    }
}