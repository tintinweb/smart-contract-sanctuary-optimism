// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IAccessControl} from "src/interfaces/IAccessControl.sol";
import {IGovernor} from "src/interfaces/IGovernor.sol";
import {IGovernorProposalQuorum} from "src/interfaces/IGovernorProposalQuorum.sol";
import {IGovernorSettings} from "src/interfaces/IGovernorSettings.sol";
import {IGovernorTimelockControl} from "src/interfaces/IGovernorTimelockControl.sol";
import {AccessControlStorage} from "src/utils/AccessControlStorage.sol";
import {GovernorStorage} from "src/utils/GovernorStorage.sol";

import {LibDiamond} from "@diamond/libraries/LibDiamond.sol";
import {IDiamondLoupe} from "@diamond/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {IERC173} from "@diamond/interfaces/IERC173.sol";
import {IERC165} from "@diamond/interfaces/IERC165.sol";

// EIP-2535 specifies that the `diamondCut` function takes two optional
// arguments: address _init and bytes calldata _calldata
// These arguments are used to execute an arbitrary function using delegatecall
// in order to set state variables in the diamond during deployment or an upgrade
// More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface

struct GovernorSettings {
    string name;
    address diamondLoupeFacet;
    address ownershipFacet;
    address governorCoreFacet;
    address governorSettingsFacet;
    address governorTimelockControlFacet;
    address membershipToken;
    address governanceToken;
    address defaultProposalToken;
    address proposalThresholdToken;
    uint256 proposalThreshold;
    uint64 votingPeriod;
    uint64 votingDelay;
    uint128 quorumNumerator;
    uint128 quorumDenominator;
    bool enableGovernanceToken;
    bool enableMembershipToken;
}

/**
 * @title Governor Diamond Initializer
 * @author Origami
 * @notice this contract is used to initialize the Governor Diamond.
 * @dev all state that's required at initialization must be set here.
 * @custom:security-contact [email protected]
 */
contract GovernorDiamondInit {
    function specifySupportedInterfaces() internal {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        // adding ERC165 data
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        // governor diamond specific
        ds.supportedInterfaces[type(IAccessControl).interfaceId] = true;
        ds.supportedInterfaces[type(IGovernor).interfaceId] = true;
        ds.supportedInterfaces[type(IGovernorProposalQuorum).interfaceId] = true;
        ds.supportedInterfaces[type(IGovernorSettings).interfaceId] = true;
        ds.supportedInterfaces[type(IGovernorTimelockControl).interfaceId] = true;
    }

    function initializeRoles(address admin) internal {
        AccessControlStorage.RoleStorage storage rs = AccessControlStorage.roleStorage();
        // 0x0 is the DEFAULT_ADMIN_ROLE
        rs.roles[0x0].members[admin] = true;
    }

    function setProposalTokens(GovernorSettings memory settings) internal {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        config.membershipToken = settings.membershipToken;
        config.governanceToken = settings.governanceToken;
        config.defaultProposalToken = settings.defaultProposalToken;
        config.proposalTokens[settings.membershipToken] = settings.enableMembershipToken;
        config.proposalTokens[settings.governanceToken] = settings.enableGovernanceToken;
    }

    function setDefaultCountingStrategy() internal {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        // // by default, we only configure and enable the simple counting strategy
        config.defaultCountingStrategy = 0x6c4b0e9f;
        config.countingStrategies[0x6c4b0e9f] = true;
    }

    function setConfigurationValues(address admin, address payable timelock, GovernorSettings memory settings)
        internal
    {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        config.name = settings.name;
        config.admin = admin;
        config.timelock = timelock;
        config.votingDelay = settings.votingDelay;
        config.votingPeriod = settings.votingPeriod;
        config.proposalThreshold = settings.proposalThreshold;
        config.proposalThresholdToken = settings.proposalThresholdToken;
        config.quorumNumerator = settings.quorumNumerator;
        config.quorumDenominator = settings.quorumDenominator;
    }

    function init(address admin, address payable timelock, bytes memory configuration) external {
        GovernorSettings memory settings = abi.decode(configuration, (GovernorSettings));
        specifySupportedInterfaces();
        initializeRoles(admin);
        setDefaultCountingStrategy();
        setProposalTokens(settings);
        setConfigurationValues(admin, timelock, settings);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 * @author Origami
 * @author Modified from OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @dev Interface of the {Governor} core.
 */
interface IGovernor {
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /**
     * @dev Emitted when a proposal is created.
     */
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startTimestamp,
        uint256 endTimestamp,
        string description
    );

    /**
     * @dev Emitted when a proposal is canceled.
     */
    event ProposalCanceled(uint256 proposalId);

    /**
     * @dev Emitted when a proposal is executed.
     */
    event ProposalExecuted(uint256 proposalId);

    /**
     * @dev Emitted when a vote is cast without params.
     *
     * Note: `support` values should be seen as buckets. Their interpretation depends on the voting module used.
     */
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);

    /**
     * @notice hashes proposal params to create a proposalId.
     * @param targets the targets of the proposal.
     * @param values the values of the proposal.
     * @param calldatas the calldatas of the proposal.
     * @param descriptionHash the hash of the description of the proposal.
     * @return the proposalId.
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256);

    /**
     * @notice returns the current ProposalState for a proposal.
     * @param proposalId the id of the proposal.
     * @return the ProposalState.
     */
    function state(uint256 proposalId) external view returns (ProposalState);

    /**
     * @notice returns the snapshot timestamp for a proposal.
     * @dev snapshot is performed at the end of this block, hence voting for the
     * proposal starts at any timestamp greater than this, but may also be less
     * than the timestamp of the next block. Block issuance times vary per
     * chain.
     * @param proposalId the id of the proposal.
     * @return the snapshot timestamp.
     */
    function proposalSnapshot(uint256 proposalId) external view returns (uint256);

    /**
     * @notice returns the deadline timestamp for a proposal.
     * @dev Votes close after this block's timestamp, so it is possible to cast a vote during this block.
     * @param proposalId the id of the proposal.
     * @return the deadline block.
     */
    function proposalDeadline(uint256 proposalId) external view returns (uint256);

    /**
     * @notice Get the configured quorum for a proposal.
     * @param proposalId The id of the proposal to get the quorum for.
     * @return The quorum for the given proposal.
     */
    function quorum(uint256 proposalId) external view returns (uint256);

    /**
     * @notice Get votes for the given account at the given timestamp using proposal token.
     * @dev delegates the implementation to the token used for the given proposal.
     * @param account the account to get the vote weight for.
     * @param timestamp the block timestamp the snapshot is needed for.
     * @param proposalToken the token to use for counting votes.
     */
    function getVotes(address account, uint256 timestamp, address proposalToken) external view returns (uint256);

    /**
     * @notice Indicates whether or not an account has voted on a proposal.
     * @dev Unlike Bravo, we don't want to prevent multiple votes, we instead update their previous vote.
     * @return true if the account has voted on the proposal, false otherwise.
     */
    function hasVoted(uint256 proposalId, address account) external view returns (bool);

    /**
     * @notice The current nonce for a given account.
     * @dev we use these nonces to prevent replay attacks.
     */
    function getAccountNonce(address account) external view returns (uint256);

    /**
     * @notice Propose a new action to be performed by the governor, specifying the proposal's counting strategy and voting token.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of calldata to be passed to each call.
     * @param description The description of the proposal.
     * @param proposalToken The token to use for counting votes.
     * @param countingStrategy The strategy to use for counting votes.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithTokenAndCountingStrategy(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposalToken,
        bytes4 countingStrategy
    ) external returns (uint256);

    /**
     * @notice Propose a new action to be performed by the governor, specifying the proposal's counting strategy and voting token. This method supports EIP-712 signed data structures, enabling gasless proposals.
     * @param targets The ordered list of target addresses for calls to be made on the proposal.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made on the proposal.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made on the proposal.
     * @param description The description of the proposal.
     * @param proposalToken The token to use for counting votes.
     * @param countingStrategy The bytes4 function selector for the strategy to use for counting votes.
     * @param nonce The nonce of the proposer.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithTokenAndCountingStrategyBySig(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposalToken,
        bytes4 countingStrategy,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 proposalId);

    /**
     * @notice Propose a new action to be performed by the governor, with params specifying proposal token and counting strategy. This method supports EIP-712 signed data structures, enabling gasless proposals.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of calldata to be passed to each call.
     * @param description The description of the proposal.
     * @param params The parameters of the proposal, encoded as a tuple of (proposalToken, countingStrategy).
     * @param nonce The nonce of the proposer.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithParamsBySig(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes memory params,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /**
     * @notice Propose a new action to be performed by the governor, specifying the proposal's counting strategy.
     * @dev See {GovernorUpgradeable-_propose}.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made.
     * @param params the encoded bytes that specify the proposal's counting strategy and the token to use for counting.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithParams(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes memory params
    ) external returns (uint256);

    /**
     * @notice Propose a new action to be performed by the governor. This method supports EIP-712 signed data structures, enabling gasless proposals.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made.
     * @param description The description of the proposal.
     * @param nonce The nonce of the proposer.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeBySig(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /**
     * @notice propose a new action to be performed by the governor.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made.
     * @param description The description of the proposal.
     * @return proposalId The id of the newly created proposal.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256 proposalId);

    /**
     * @notice Cast a vote on a proposal.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @return weight The weight of the vote.
     */
    function castVote(uint256 proposalId, uint8 support) external returns (uint256 weight);

    /**
     * @notice Cast a vote on a proposal with a reason.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @param reason The reason for the vote.
     * @return weight The weight of the vote.
     */
    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason)
        external
        returns (uint256 weight);

    /**
     * @notice Cast a vote on a proposal by signature. This is useful in allowing another address to pay for gas.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @param nonce The nonce to use for this vote.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return weight The weight of the vote.
     */
    function castVoteBySig(uint256 proposalId, uint8 support, uint256 nonce, uint8 v, bytes32 r, bytes32 s)
        external
        returns (uint256 weight);

    /**
     * @notice Cast a vote on a proposal with a reason by signature. This is useful in allowing another address to pay for gas.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @param reason The reason for the vote.
     * @param nonce The nonce to use for this vote.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return weight The weight of the vote.
     */
    function castVoteWithReasonBySig(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 weight);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IGovernorProposalQuorum {
    /**
     * @dev Returns the quorum numerator for a specific proposalId.
     */
    function quorumNumerator(uint256 proposalId) external view returns (uint128);

    /**
     * @dev Returns the quorum denominator for a specific proposalId.
     */
    function quorumDenominator(uint256 proposalId) external view returns (uint128);

    /**
     * @dev Returns the quorum for a specific proposal's counting token, in terms of number of votes: `supply * numerator / denominator`.
     */
    function quorum(uint256 proposalId) external view returns (uint256);
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

import {ITimelockController} from "src/interfaces/ITimelockController.sol";

interface IGovernorTimelockControl {
    event TimelockChange(address oldTimelock, address newTimelock);
    event ProposalQueued(uint256 proposalId, uint256 eta);
    event ProposalCanceled(uint256 proposalId);
    event ProposalExecuted(uint256 proposalId);

    /**
     * @dev Public accessor to check the eta of a queued proposal
     */
    function proposalEta(uint256 proposalId) external view returns (uint256);

    /**
     * @dev Public accessor to return the address of the timelock
     */
    function timelock() external returns (ITimelockController);

    /**
     * @dev Queue a proposal to be executed after a delay.
     *
     * Emits a {ProposalQueued} event.
     */
    function queue(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);

    /**
     * @dev Execute a successful proposal. This requires the quorum to be reached, the vote to be successful, and the
     * deadline to be reached.
     *
     * Emits a {ProposalExecuted} event.
     *
     * Note: some module can modify the requirements for execution, for example by adding an additional timelock.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256);

    /**
     * @dev Cancel a proposal. This can only be done if the proposal is still pending or queued, or if the module that
     * implements the {IGovernor} interface has a different implementation for this function.
     *
     * Emits a {ProposalCanceled} event.
     */
    function cancel(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);

    /**
     * @dev Update the timelock.
     *
     * Emits a {TimelockChange} event.
     */
    function updateTimelock(address payable newTimelock) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

library AccessControlStorage {
    bytes32 public constant ROLE_STORAGE_POSITION = keccak256("com.origami.accesscontrol.role");

    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    struct RoleStorage {
        mapping(bytes32 => RoleData) roles;
    }

    // Regarding: slither uses assembly: This is how DiamondStorage writes to a specific slot
    // slither-disable-start assembly
    function roleStorage() internal pure returns (RoleStorage storage rs) {
        bytes32 position = ROLE_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            rs.slot := position
        }
    }
    // slither-disable-end assembly

    function roleData(bytes32 role) internal view returns (RoleData storage rd) {
        RoleStorage storage rs = roleStorage();
        rd = rs.roles[role];
    }
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
     * Regarding: slither uses assembly: This is how DiamondStorage writes to a specific slot
     */
    // slither-disable-start assembly
    function configStorage() internal pure returns (GovernorConfig storage gs) {
        bytes32 position = CONFIG_STORAGE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            gs.slot := position
        }
    }
    // slither-disable-end assembly

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
     * Regarding: slither uses assembly: This is how DiamondStorage writes to a specific slot
     */
    // slither-disable-start assembly
    function proposalStorage() internal pure returns (ProposalStorage storage ps) {
        bytes32 position = PROPOSAL_STORAGE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            ps.slot := position
        }
    }
    // slither-disable-end assembly

    /**
     * @notice creates a new proposal.
     * @param proposalId the proposal id.
     * @param proposalToken the proposal token.
     * @param countingStrategy the counting strategy.
     * @return ps the proposal core storage.
     * Regarding slither disable timestamp: Block manipulation generally occurs over
     * a very short period of time (seconds/minutes). The snapshot and deadline properties are
     * only used to set the start and end times of the voting period for the proposal. Any
     * manipulation of the block-timestamp would only result in a small difference in the
     * voting period, and does not have a significant impact on the overall governance process.
     */
    //slither-disable-start timestamp
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
    //slither-disable-end timestamp

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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <[email protected]> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";

// Remember to add the loupe functions from DiamondLoupeFacet to the diamond.
// The loupe functions are required by the EIP2535 Diamonds standard

error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);

library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    struct DiamondStorage {
        // maps function selectors to the facets that execute the functions.
        // and maps the selectors to their position in the selectorSlots array.
        // func selector => address facet, selector position
        mapping(bytes4 => bytes32) facets;
        // array of slots of function selectors.
        // each slot holds 8 function selectors.
        mapping(uint256 => bytes32) selectorSlots;
        // The number of function selectors in selectorSlots
        uint16 selectorCount;
        // Used to query if a contract implements an interface.
        // Used to implement ERC-165.
        mapping(bytes4 => bool) supportedInterfaces;
        // owner of the contract
        address contractOwner;
    }

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        require(msg.sender == diamondStorage().contractOwner, "LibDiamond: Must be contract owner");
    }

    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    bytes32 constant CLEAR_ADDRESS_MASK = bytes32(uint256(0xffffffffffffffffffffffff));
    bytes32 constant CLEAR_SELECTOR_MASK = bytes32(uint256(0xffffffff << 224));

    // Internal function version of diamondCut
    // This code is almost the same as the external diamondCut,
    // except it is using 'Facet[] memory _diamondCut' instead of
    // 'Facet[] calldata _diamondCut'.
    // The code is duplicated to prevent copying calldata to memory which
    // causes an error for a two dimensional array.
    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        DiamondStorage storage ds = diamondStorage();
        uint256 originalSelectorCount = ds.selectorCount;
        uint256 selectorCount = originalSelectorCount;
        bytes32 selectorSlot;
        // Check if last selector slot is not full
        // "selectorCount & 7" is a gas efficient modulo by eight "selectorCount % 8" 
        if (selectorCount & 7 > 0) {
            // get last selectorSlot
            // "selectorSlot >> 3" is a gas efficient division by 8 "selectorSlot / 8"
            selectorSlot = ds.selectorSlots[selectorCount >> 3];
        }
        // loop through diamond cut
        for (uint256 facetIndex; facetIndex < _diamondCut.length; ) {
            (selectorCount, selectorSlot) = addReplaceRemoveFacetSelectors(
                selectorCount,
                selectorSlot,
                _diamondCut[facetIndex].facetAddress,
                _diamondCut[facetIndex].action,
                _diamondCut[facetIndex].functionSelectors
            );

            unchecked {
                facetIndex++;
            }
        }
        if (selectorCount != originalSelectorCount) {
            ds.selectorCount = uint16(selectorCount);
        }
        // If last selector slot is not full
        // "selectorCount & 7" is a gas efficient modulo by eight "selectorCount % 8" 
        if (selectorCount & 7 > 0) {
            // "selectorSlot >> 3" is a gas efficient division by 8 "selectorSlot / 8"
            ds.selectorSlots[selectorCount >> 3] = selectorSlot;
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addReplaceRemoveFacetSelectors(
        uint256 _selectorCount,
        bytes32 _selectorSlot,
        address _newFacetAddress,
        IDiamondCut.FacetCutAction _action,
        bytes4[] memory _selectors
    ) internal returns (uint256, bytes32) {
        DiamondStorage storage ds = diamondStorage();
        require(_selectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        if (_action == IDiamondCut.FacetCutAction.Add) {
            enforceHasContractCode(_newFacetAddress, "LibDiamondCut: Add facet has no code");
            for (uint256 selectorIndex; selectorIndex < _selectors.length; ) {
                bytes4 selector = _selectors[selectorIndex];
                bytes32 oldFacet = ds.facets[selector];
                require(address(bytes20(oldFacet)) == address(0), "LibDiamondCut: Can't add function that already exists");
                // add facet for selector
                ds.facets[selector] = bytes20(_newFacetAddress) | bytes32(_selectorCount);
                // "_selectorCount & 7" is a gas efficient modulo by eight "_selectorCount % 8" 
                // " << 5 is the same as multiplying by 32 ( * 32)
                uint256 selectorInSlotPosition = (_selectorCount & 7) << 5;
                // clear selector position in slot and add selector
                _selectorSlot = (_selectorSlot & ~(CLEAR_SELECTOR_MASK >> selectorInSlotPosition)) | (bytes32(selector) >> selectorInSlotPosition);
                // if slot is full then write it to storage
                if (selectorInSlotPosition == 224) {
                    // "_selectorSlot >> 3" is a gas efficient division by 8 "_selectorSlot / 8"
                    ds.selectorSlots[_selectorCount >> 3] = _selectorSlot;
                    _selectorSlot = 0;
                }
                _selectorCount++;

                unchecked {
                    selectorIndex++;
                }
            }
        } else if (_action == IDiamondCut.FacetCutAction.Replace) {
            enforceHasContractCode(_newFacetAddress, "LibDiamondCut: Replace facet has no code");
            for (uint256 selectorIndex; selectorIndex < _selectors.length; ) {
                bytes4 selector = _selectors[selectorIndex];
                bytes32 oldFacet = ds.facets[selector];
                address oldFacetAddress = address(bytes20(oldFacet));
                // only useful if immutable functions exist
                require(oldFacetAddress != address(this), "LibDiamondCut: Can't replace immutable function");
                require(oldFacetAddress != _newFacetAddress, "LibDiamondCut: Can't replace function with same function");
                require(oldFacetAddress != address(0), "LibDiamondCut: Can't replace function that doesn't exist");
                // replace old facet address
                ds.facets[selector] = (oldFacet & CLEAR_ADDRESS_MASK) | bytes20(_newFacetAddress);

                unchecked {
                    selectorIndex++;
                }
            }
        } else if (_action == IDiamondCut.FacetCutAction.Remove) {
            require(_newFacetAddress == address(0), "LibDiamondCut: Remove facet address must be address(0)");
            // "_selectorCount >> 3" is a gas efficient division by 8 "_selectorCount / 8"
            uint256 selectorSlotCount = _selectorCount >> 3;
            // "_selectorCount & 7" is a gas efficient modulo by eight "_selectorCount % 8" 
            uint256 selectorInSlotIndex = _selectorCount & 7;
            for (uint256 selectorIndex; selectorIndex < _selectors.length; ) {
                if (_selectorSlot == 0) {
                    // get last selectorSlot
                    selectorSlotCount--;
                    _selectorSlot = ds.selectorSlots[selectorSlotCount];
                    selectorInSlotIndex = 7;
                } else {
                    selectorInSlotIndex--;
                }
                bytes4 lastSelector;
                uint256 oldSelectorsSlotCount;
                uint256 oldSelectorInSlotPosition;
                // adding a block here prevents stack too deep error
                {
                    bytes4 selector = _selectors[selectorIndex];
                    bytes32 oldFacet = ds.facets[selector];
                    require(address(bytes20(oldFacet)) != address(0), "LibDiamondCut: Can't remove function that doesn't exist");
                    // only useful if immutable functions exist
                    require(address(bytes20(oldFacet)) != address(this), "LibDiamondCut: Can't remove immutable function");
                    // replace selector with last selector in ds.facets
                    // gets the last selector
                    // " << 5 is the same as multiplying by 32 ( * 32)
                    lastSelector = bytes4(_selectorSlot << (selectorInSlotIndex << 5));
                    if (lastSelector != selector) {
                        // update last selector slot position info
                        ds.facets[lastSelector] = (oldFacet & CLEAR_ADDRESS_MASK) | bytes20(ds.facets[lastSelector]);
                    }
                    delete ds.facets[selector];
                    uint256 oldSelectorCount = uint16(uint256(oldFacet));
                    // "oldSelectorCount >> 3" is a gas efficient division by 8 "oldSelectorCount / 8"
                    oldSelectorsSlotCount = oldSelectorCount >> 3;
                    // "oldSelectorCount & 7" is a gas efficient modulo by eight "oldSelectorCount % 8" 
                    // " << 5 is the same as multiplying by 32 ( * 32)
                    oldSelectorInSlotPosition = (oldSelectorCount & 7) << 5;
                }
                if (oldSelectorsSlotCount != selectorSlotCount) {
                    bytes32 oldSelectorSlot = ds.selectorSlots[oldSelectorsSlotCount];
                    // clears the selector we are deleting and puts the last selector in its place.
                    oldSelectorSlot =
                        (oldSelectorSlot & ~(CLEAR_SELECTOR_MASK >> oldSelectorInSlotPosition)) |
                        (bytes32(lastSelector) >> oldSelectorInSlotPosition);
                    // update storage with the modified slot
                    ds.selectorSlots[oldSelectorsSlotCount] = oldSelectorSlot;
                } else {
                    // clears the selector we are deleting and puts the last selector in its place.
                    _selectorSlot =
                        (_selectorSlot & ~(CLEAR_SELECTOR_MASK >> oldSelectorInSlotPosition)) |
                        (bytes32(lastSelector) >> oldSelectorInSlotPosition);
                }
                if (selectorInSlotIndex == 0) {
                    delete ds.selectorSlots[selectorSlotCount];
                    _selectorSlot = 0;
                }

                unchecked {
                    selectorIndex++;
                }
            }
            _selectorCount = selectorSlotCount * 8 + selectorInSlotIndex;
        } else {
            revert("LibDiamondCut: Incorrect FacetCutAction");
        }
        return (_selectorCount, _selectorSlot);
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            return;
        }
        enforceHasContractCode(_init, "LibDiamondCut: _init address has no code");        
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                // bubble up error
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert InitializationFunctionReverted(_init, _calldata);
            }
        }
    }

    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <[email protected]> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

// A loupe is a small magnifying glass used to look at diamonds.
// These functions look at diamonds
interface IDiamondLoupe {
    /// These functions are expected to be called frequently
    /// by tools.

    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Gets all facet addresses and their four byte function selectors.
    /// @return facets_ Facet
    function facets() external view returns (Facet[] memory facets_);

    /// @notice Gets all the function selectors supported by a specific facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_);

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses() external view returns (address[] memory facetAddresses_);

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <[email protected]> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

interface IDiamondCut {
    enum FacetCutAction {Add, Replace, Remove}
    // Add=0, Replace=1, Remove=2

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ERC-173 Contract Ownership Standard
///  Note: the ERC-165 identifier for this interface is 0x7f5828d0
/* is ERC165 */
interface IERC173 {
    /// @dev This emits when ownership of a contract changes.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Get the address of the owner
    /// @return owner_ The address of the owner.
    function owner() external view returns (address owner_);

    /// @notice Set the address of the new owner of the contract
    /// @dev Set _newOwner to address(0) to renounce any ownership.
    /// @param _newOwner The address of the new owner of the contract
    function transferOwnership(address _newOwner) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceId The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///  uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface ITimelockController {
    function getMinDelay() external view returns (uint256);

    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external payable;

    function hashOperationBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external returns (bytes32 hash);

    function cancel(bytes32 id) external;
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