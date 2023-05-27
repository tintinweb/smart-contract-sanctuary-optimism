// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
// ══════════════════════════════ LIBRARY IMPORTS ══════════════════════════════
import { SummitState } from "./libs/State.sol";
import { AgentInfo } from "./libs/Structures.sol";
// ═════════════════════════════ INTERNAL IMPORTS ══════════════════════════════
import { BondingManager } from "./bonding/BondingManager.sol";
import { DomainContext } from "./context/DomainContext.sol";
import { SummitEvents } from "./events/SummitEvents.sol";
import { InterfaceSummit } from "./interfaces/InterfaceSummit.sol";
import { SnapshotHub } from "./hubs/SnapshotHub.sol";
import { Attestation, Snapshot, StatementHub } from "./hubs/StatementHub.sol";

/**
 * @notice Accepts snapshots signed by Guards and Notaries. Verifies Notaries attestations.
 */
contract Summit is StatementHub, SnapshotHub, BondingManager, SummitEvents, InterfaceSummit {
    constructor(uint32 _domain) DomainContext(_domain) {
        require(_onSynapseChain(), "Only deployed on SynChain");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             INITIALIZER                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function initialize() external initializer {
        __SystemContract_initialize();
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            ADDING AGENTS                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function addAgent(uint32 _domain, address _account) external onlyOwner returns (bool isAdded) {
        isAdded = _addAgent(_domain, _account);
        if (isAdded) {
            _syncAgentLocalRegistries(AgentInfo(_domain, _account, true));
        }
    }

    function removeAgent(uint32 _domain, address _account)
        external
        onlyOwner
        returns (bool isRemoved)
    {
        isRemoved = _removeAgent(_domain, _account);
        if (isRemoved) {
            _syncAgentLocalRegistries(AgentInfo(_domain, _account, false));
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          ACCEPT STATEMENTS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @inheritdoc InterfaceSummit
    function submitSnapshot(bytes memory _snapPayload, bytes memory _snapSignature)
        external
        returns (bool wasAccepted)
    {
        // This will revert if payload is not a snapshot, or signer is not an active Agent
        (Snapshot snapshot, uint32 domain, address agent) = _verifySnapshot(
            _snapPayload,
            _snapSignature
        );
        if (domain == 0) {
            // This will revert if Guard has previously submitted
            // a fresher state than one in the snapshot.
            _acceptGuardSnapshot(snapshot, agent);
        } else {
            // This will revert if any of the states from the Notary snapshot
            // haven't been submitted by any of the Guards before.
            _acceptNotarySnapshot(snapshot, agent);
        }
        emit SnapshotAccepted(domain, agent, _snapPayload, _snapSignature);
        return true;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          VERIFY STATEMENTS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @inheritdoc InterfaceSummit
    function verifyAttestation(bytes memory _attPayload, bytes memory _attSignature)
        external
        returns (bool isValid)
    {
        // This will revert if payload is not an attestation, or signer is not an active Notary
        (Attestation att, uint32 domain, address notary) = _verifyAttestation(
            _attPayload,
            _attSignature
        );
        isValid = _isValidAttestation(att);
        if (!isValid) {
            emit InvalidAttestation(_attPayload, _attSignature);
            // Slash Notary and trigger a hook to send a slashAgent system call
            _slashAgent(domain, notary, true);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                VIEWS                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @inheritdoc InterfaceSummit
    function getLatestState(uint32 _origin) external view returns (bytes memory statePayload) {
        uint256 guardsAmount = amountAgents(0);
        SummitState memory latestState;
        for (uint256 i = 0; i < guardsAmount; ++i) {
            address guard = getAgent(0, i);
            SummitState memory state = _latestState(_origin, guard);
            if (state.nonce > latestState.nonce) {
                latestState = state;
            }
        }
        // Check if we found anything
        if (latestState.nonce != 0) {
            statePayload = latestState.formatSummitState();
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            INTERNAL LOGIC                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Hook that is called after an existing agent was slashed,
    /// when verification of an invalid agent statement was done in this contract.
    function _afterAgentSlashed(uint32 _domain, address _agent) internal virtual override {
        /// @dev Summit is BondingPrimary, so we need to slash Agent on local Registries,
        /// as well as relay this information to all other chains.
        /// There was no system call that triggered slashing, so callOrigin is set to ZERO.
        _updateLocalRegistries({
            _data: _dataSlashAgent(_domain, _agent),
            _forwardUpdate: true,
            _callOrigin: 0
        });
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ByteString } from "./ByteString.sol";
import { STATE_LENGTH } from "./Constants.sol";
import { TypedMemView } from "./TypedMemView.sol";

/// @dev State is a memory view over a formatted state payload.
type State is bytes29;
/// @dev Attach library functions to State
using {
    StateLib.unwrap,
    StateLib.equalToOrigin,
    StateLib.hash,
    StateLib.subLeafs,
    StateLib.toSummitState,
    StateLib.root,
    StateLib.origin,
    StateLib.nonce,
    StateLib.blockNumber,
    StateLib.timestamp
} for State global;

/// @dev Struct representing State, as it is stored in the Origin contract.
struct OriginState {
    bytes32 root;
    uint40 blockNumber;
    uint40 timestamp;
    // 176 bits left for tight packing
}
/// @dev Attach library functions to OriginState
using { StateLib.formatOriginState } for OriginState global;

/// @dev Struct representing State, as it is stored in the Summit contract.
struct SummitState {
    bytes32 root;
    uint32 origin;
    uint32 nonce;
    uint40 blockNumber;
    uint40 timestamp;
    // 112 bits left for tight packing
}
/// @dev Attach library functions to SummitState
using { StateLib.formatSummitState } for SummitState global;

library StateLib {
    using ByteString for bytes;
    using TypedMemView for bytes29;

    /**
     * @dev State structure represents the state of Origin contract at some point of time.
     * State is structured in a way to track the updates of the Origin Merkle Tree. State includes
     * root of the Origin Merkle Tree, origin domain and some additional metadata.
     *
     * Hash of every dispatched message is inserted in the Origin Merkle Tree, which changes the
     * value of Origin Merkle Root (which is the root for the mentioned tree).
     * Origin has a single Merkle Tree for all messages, regardless of their destination domain.
     * This leads to Origin state being updated if and only if a message was dispatched in a block.
     *
     * Origin contract is a "source of truth" for states: a state is considered "valid" in its Origin,
     * if it matches the state of the Origin contract after the N-th (nonce) message was dispatched.
     *
     * @dev Memory layout of State fields
     * [000 .. 032): root           bytes32 32 bytes    Root of the Origin Merkle Tree
     * [032 .. 036): origin         uint32   4 bytes    Domain where Origin is located
     * [036 .. 040): nonce          uint32   4 bytes    Amount of dispatched messages
     * [040 .. 045): blockNumber    uint40   5 bytes    Block of last dispatched message
     * [045 .. 050): timestamp      uint40   5 bytes    Time of last dispatched message
     *
     * The variables below are not supposed to be used outside of the library directly.
     */

    uint256 private constant OFFSET_ROOT = 0;
    uint256 private constant OFFSET_ORIGIN = 32;
    uint256 private constant OFFSET_NONCE = 36;
    uint256 private constant OFFSET_BLOCK_NUMBER = 40;
    uint256 private constant OFFSET_TIMESTAMP = 45;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                STATE                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Returns a formatted State payload with provided fields
     * @param _root         New merkle root
     * @param _origin       Domain of Origin's chain
     * @param _nonce        Nonce of the merkle root
     * @param _blockNumber  Block number when root was saved in Origin
     * @param _timestamp    Block timestamp when root was saved in Origin
     * @return Formatted state
     **/
    function formatState(
        bytes32 _root,
        uint32 _origin,
        uint32 _nonce,
        uint40 _blockNumber,
        uint40 _timestamp
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(_root, _origin, _nonce, _blockNumber, _timestamp);
    }

    /**
     * @notice Returns a State view over the given payload.
     * @dev Will revert if the payload is not a state.
     */
    function castToState(bytes memory _payload) internal pure returns (State) {
        return castToState(_payload.castToRawBytes());
    }

    /**
     * @notice Casts a memory view to a State view.
     * @dev Will revert if the memory view is not over a state.
     */
    function castToState(bytes29 _view) internal pure returns (State) {
        require(isState(_view), "Not a state");
        return State.wrap(_view);
    }

    /// @notice Checks that a payload is a formatted State.
    function isState(bytes29 _view) internal pure returns (bool) {
        return _view.len() == STATE_LENGTH;
    }

    /// @notice Convenience shortcut for unwrapping a view.
    function unwrap(State _state) internal pure returns (bytes29) {
        return State.unwrap(_state);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             ORIGIN STATE                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Returns a formatted State payload with provided fields.
     * @param _origin       Domain of Origin's chain
     * @param _nonce        Nonce of the merkle root
     * @param _originState  State struct as it is stored in Origin contract
     * @return Formatted state
     */
    function formatOriginState(
        OriginState memory _originState,
        uint32 _origin,
        uint32 _nonce
    ) internal pure returns (bytes memory) {
        return
            formatState({
                _root: _originState.root,
                _origin: _origin,
                _nonce: _nonce,
                _blockNumber: _originState.blockNumber,
                _timestamp: _originState.timestamp
            });
    }

    /// @notice Returns a struct to save in the Origin contract.
    /// Current block number and timestamp are used.
    function originState(bytes32 currentRoot) internal view returns (OriginState memory state) {
        state.root = currentRoot;
        state.blockNumber = uint40(block.number);
        state.timestamp = uint40(block.timestamp);
    }

    /// @notice Checks that a state and its Origin representation are equal.
    function equalToOrigin(State _state, OriginState memory _originState)
        internal
        pure
        returns (bool)
    {
        return
            _state.root() == _originState.root &&
            _state.blockNumber() == _originState.blockNumber &&
            _state.timestamp() == _originState.timestamp;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             SUMMIT STATE                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Returns a formatted State payload with provided fields.
     * @param _summitState  State struct as it is stored in Summit contract
     * @return Formatted state
     */
    function formatSummitState(SummitState memory _summitState)
        internal
        pure
        returns (bytes memory)
    {
        return
            formatState({
                _root: _summitState.root,
                _origin: _summitState.origin,
                _nonce: _summitState.nonce,
                _blockNumber: _summitState.blockNumber,
                _timestamp: _summitState.timestamp
            });
    }

    /// @notice Returns a struct to save in the Summit contract.
    function toSummitState(State _state) internal pure returns (SummitState memory state) {
        state.root = _state.root();
        state.origin = _state.origin();
        state.nonce = _state.nonce();
        state.blockNumber = _state.blockNumber();
        state.timestamp = _state.timestamp();
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            STATE HASHING                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Returns the hash of the State.
    /// @dev We are using the Merkle Root of a tree with two leafs (see below) as state hash.
    function hash(State _state) internal pure returns (bytes32) {
        (bytes32 _leftLeaf, bytes32 _rightLeaf) = _state.subLeafs();
        // Final hash is the parent of these leafs
        return keccak256(bytes.concat(_leftLeaf, _rightLeaf));
    }

    /// @notice Returns "sub-leafs" of the State. Hash of these "sub leafs" is going to be used
    /// as a "state leaf" in the "Snapshot Merkle Tree".
    /// This enables proving that leftLeaf = (root, origin) was a part of the "Snapshot Merkle Tree",
    /// by combining `rightLeaf` with the remainder of the "Snapshot Merkle Proof".
    function subLeafs(State _state) internal pure returns (bytes32 _leftLeaf, bytes32 _rightLeaf) {
        bytes29 _view = _state.unwrap();
        // Left leaf is (root, origin)
        _leftLeaf = _view.prefix({ _len: OFFSET_NONCE, newType: 0 }).keccak();
        // Right leaf is (metadata), or (nonce, blockNumber, timestamp)
        _rightLeaf = _view.sliceFrom({ _index: OFFSET_NONCE, newType: 0 }).keccak();
    }

    /// @notice Returns the left "sub-leaf" of the State.
    function leftLeaf(bytes32 _root, uint32 _origin) internal pure returns (bytes32) {
        // We use encodePacked here to simulate the State memory layout
        return keccak256(abi.encodePacked(_root, _origin));
    }

    /// @notice Returns the right "sub-leaf" of the State.
    function rightLeaf(
        uint32 _nonce,
        uint40 _blockNumber,
        uint40 _timestamp
    ) internal pure returns (bytes32) {
        // We use encodePacked here to simulate the State memory layout
        return keccak256(abi.encodePacked(_nonce, _blockNumber, _timestamp));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            STATE SLICING                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Returns a historical Merkle root from the Origin contract.
    function root(State _state) internal pure returns (bytes32) {
        bytes29 _view = _state.unwrap();
        return _view.index({ _index: OFFSET_ROOT, _bytes: 32 });
    }

    /// @notice Returns domain of chain where the Origin contract is deployed.
    function origin(State _state) internal pure returns (uint32) {
        bytes29 _view = _state.unwrap();
        return uint32(_view.indexUint({ _index: OFFSET_ORIGIN, _bytes: 4 }));
    }

    /// @notice Returns nonce of Origin contract at the time, when `root` was the Merkle root.
    function nonce(State _state) internal pure returns (uint32) {
        bytes29 _view = _state.unwrap();
        return uint32(_view.indexUint({ _index: OFFSET_NONCE, _bytes: 4 }));
    }

    /// @notice Returns a block number when `root` was saved in Origin.
    function blockNumber(State _state) internal pure returns (uint40) {
        bytes29 _view = _state.unwrap();
        return uint40(_view.indexUint({ _index: OFFSET_BLOCK_NUMBER, _bytes: 5 }));
    }

    /// @notice Returns a block timestamp when `root` was saved in Origin.
    /// @dev This is the timestamp according to the origin chain.
    function timestamp(State _state) internal pure returns (uint40) {
        bytes29 _view = _state.unwrap();
        return uint40(_view.indexUint({ _index: OFFSET_TIMESTAMP, _bytes: 5 }));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Here we define common enums and structures to enable their easier reusing later.

/// @dev Potential senders/recipients of a system message
enum SystemEntity {
    Origin,
    Destination,
    BondingManager
}

/**
 * @notice Unified struct for off-chain agent storing
 * @dev Both Guards and Notaries are stored this way.
 * `domain == 0` refers to Guards, who are active on every domain
 * `domain != 0` refers to Notaries, who are active on a single domain
 * @param bonded    Whether agent bonded or unbonded
 * @param domain    Domain, where agent is active
 * @param account   Off-chain agent address
 */
struct AgentInfo {
    // TODO: This won't be needed when Agents Merkle Tree is implemented
    uint32 domain;
    address account;
    bool bonded;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
// ══════════════════════════════ LIBRARY IMPORTS ══════════════════════════════
import { AgentInfo, SystemEntity } from "../libs/Structures.sol";
// ═════════════════════════════ INTERNAL IMPORTS ══════════════════════════════
import { AgentRegistry } from "../system/AgentRegistry.sol";
import { ISystemContract, SystemContract } from "../system/SystemContract.sol";

/// @notice BondingManager keeps track of all agents.
abstract contract BondingManager is AgentRegistry, SystemContract {
    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          SYSTEM ROUTER ONLY                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @inheritdoc ISystemContract
    function slashAgent(
        uint256 _rootSubmittedAt,
        uint32 _callOrigin,
        SystemEntity _caller,
        AgentInfo memory _info
    ) external onlySystemRouter {
        bool forwardUpdate;
        if (_callOrigin == localDomain) {
            // Forward information about slashed agent to remote chains
            forwardUpdate = true;
            // Only Origin can slash agents on local domain.
            // Summit is BondingManager on SynChain, so
            // Summit Notary slashing will not require a local slashAgent call.
            _assertEntityAllowed(ORIGIN, _caller);
        } else {
            // Forward information about slashed agent to remote chains
            // only if BondingManager is deployed on Synapse Chain
            forwardUpdate = _onSynapseChain();
            // Validate security params for cross-chain slashing
            _assertCrossChainSlashing(_rootSubmittedAt, _callOrigin, _caller);
        }
        // Forward information about the slashed agent to local Registries
        // Forward information about slashed agent to remote chains if needed
        _updateLocalRegistries(_dataSlashAgent(_info), forwardUpdate, _callOrigin);
    }

    /// @inheritdoc ISystemContract
    function syncAgent(
        uint256 _rootSubmittedAt,
        uint32 _callOrigin,
        SystemEntity _caller,
        AgentInfo memory _info
    ) external onlySystemRouter {
        // BondingPrimary doesn't receive any valid syncAgent calls
        if (_onSynapseChain()) revert("Disabled for BondingPrimary");
        // Validate security params for cross-chain synching
        _assertCrossChainSynching(_rootSubmittedAt, _callOrigin, _caller);
        // Forward information about the synced agent to local Registries
        // Don't forward any information back to Synapse Chain
        _syncAgentLocalRegistries(_info);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║          INTERNAL HELPERS: UPDATE AGENT (BOND/UNBOND/SLASH)          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    // TODO: generalize this further when Agent Merkle Tree is implemented

    /// @dev Passes an "update status" message to local Registries:
    /// that an Agent has been added / removed
    function _syncAgentLocalRegistries(AgentInfo memory _info) internal {
        // TODO: rework once Agent Merkle Tree is implemented
        // In the MVP version we don't do any forwarding for agents added/removed
        // Instead, BondingSecondary exposes owner-only addAgent() and removeAgent()
        _updateLocalRegistries(_dataSyncAgent(_info), false, 0);
    }

    /// @dev Passes an "update status" message to local Registries:
    /// that an Agent has been added / removed / slashed
    function _updateLocalRegistries(
        bytes memory _data,
        bool _forwardUpdate,
        uint32 _callOrigin
    ) internal {
        // Pass data to all System Registries. This could lead to duplicated data, meaning that
        // every Registry is responsible for ignoring the data it already has. This makes Registries
        // a bit more complex, but greatly reduces the complexity of BondingManager.
        systemRouter.systemMultiCall({
            _destination: localDomain,
            _optimisticSeconds: 0,
            _recipients: _localSystemRegistries(),
            _data: _data
        });
        // Forward data cross-chain, if requested
        if (_forwardUpdate) {
            _forwardUpdateData(_data, _callOrigin);
        }
    }

    /**
     * @notice Forward data with an agent status update (due to a system call from `_callOrigin`).
     * @dev If BondingManager is deployed on Synapse Chain, all chains should be notified,
     * excluding `_callOrigin` and Synapse Chain.
     * If BondingManager is not deployed on Synapse CHain, only Synapse Chain should be notified.
     */
    function _forwardUpdateData(bytes memory _data, uint32 _callOrigin) internal {
        if (_onSynapseChain()) {
            // SynapseChain: forward data to all OTHER chains except for callOrigin
            uint256 amount = amountDomains();
            for (uint256 i = 0; i < amount; ++i) {
                uint32 domain = getDomain(i);
                if (domain != _callOrigin && domain != SYNAPSE_DOMAIN) {
                    _callBondingManager(domain, BONDING_OPTIMISTIC_PERIOD, _data);
                }
            }
        } else {
            // Not Synapse Chain: forward data to Synapse Chain
            _callBondingManager(SYNAPSE_DOMAIN, BONDING_OPTIMISTIC_PERIOD, _data);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            INTERNAL VIEWS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Perform all required security checks for a cross-chain
     * system call for slashing an agent.
     */
    function _assertCrossChainSlashing(
        uint256 _rootSubmittedAt,
        uint32 _callOrigin,
        SystemEntity _caller
    ) internal view {
        // Optimistic period should be over
        _assertOptimisticPeriodOver(_rootSubmittedAt, BONDING_OPTIMISTIC_PERIOD);
        // Either BondingManager is deployed on Synapse Chain, or
        // slashing system call has to originate on Synapse Chain
        if (!_onSynapseChain()) {
            _assertSynapseChain(_callOrigin);
        }
        // Slashing system call has to be done by Bonding Manager
        _assertEntityAllowed(BONDING_MANAGER, _caller);
    }

    /**
     * @notice Perform all required security checks for a cross-chain
     * system call for synching an agent.
     */
    function _assertCrossChainSynching(
        uint256 _rootSubmittedAt,
        uint32 _callOrigin,
        SystemEntity _caller
    ) internal view {
        // Optimistic period should be over
        _assertOptimisticPeriodOver(_rootSubmittedAt, BONDING_OPTIMISTIC_PERIOD);
        // Synching system call has to originate on Synapse Chain
        _assertSynapseChain(_callOrigin);
        // Synching system call has to be done by Bonding Manager
        _assertEntityAllowed(BONDING_MANAGER, _caller);
    }

    /**
     * @notice Returns a list of local System Registries: system contracts, keeping track
     * of active Notaries and Guards.
     */
    function _localSystemRegistries() internal pure returns (SystemEntity[] memory recipients) {
        recipients = new SystemEntity[](2);
        recipients[0] = SystemEntity.Origin;
        recipients[1] = SystemEntity.Destination;
    }

    function _isIgnoredAgent(uint32, address) internal pure override returns (bool) {
        // Bonding keeps track of every agent
        return false;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract DomainContext {
    /// @notice Domain of the local chain, set once upon contract creation
    uint32 public immutable localDomain;

    /**
     * @notice Ensures that a domain matches the local domain.
     */
    modifier onlyLocalDomain(uint32 _domain) {
        _assertLocalDomain(_domain);
        _;
    }

    constructor(uint32 _domain) {
        localDomain = _domain;
    }

    function _assertLocalDomain(uint32 _domain) internal view {
        require(_domain == localDomain, "!localDomain");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @notice A collection of events emitted by the Summit contract
abstract contract SummitEvents {
    /**
     * @notice Emitted when a proof of invalid attestation is submitted.
     * @param attestation   Raw payload with attestation data
     * @param attSignature  Notary signature for the attestation
     */
    event InvalidAttestation(bytes attestation, bytes attSignature);

    /**
     * @notice Emitted when a snapshot is accepted by the Summit contract.
     * @param domain        Domain where the signed Agent is active (ZERO for Guards)
     * @param agent         Agent who signed the snapshot
     * @param snapshot      Raw payload with snapshot data
     * @param snapSignature Agent signature for the snapshot
     */
    event SnapshotAccepted(
        uint32 indexed domain,
        address indexed agent,
        bytes snapshot,
        bytes snapSignature
    );
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface InterfaceSummit {
    /**
     * @notice Submit a snapshot (list of states) signed by a Guard or a Notary.
     * Guard-signed snapshots: all the states in the snapshot become available for Notary signing.
     * Notary-signed snapshots: Attestation Merkle Root is saved for valid snapshots, i.e.
     * snapshots which are only using states previously submitted by any of the Guards.
     * Notary doesn't have to use states submitted by a single Guard in their snapshot.
     * Notary could then proceed to sign the attestation for their submitted snapshot.
     * @dev Will revert if any of these is true:
     *  - Snapshot payload is not properly formatted.
     *  - Snapshot signer is not an active Agent.
     *  - Guard snapshot contains a state older then they have previously submitted
     *  - Notary snapshot contains a state that hasn't been previously submitted by a Guard.
     * Note that Notary will NOT be slashed for submitting such a snapshot.
     * @param _snapPayload      Raw payload with snapshot data
     * @param _snapSignature    Agent signature for the snapshot
     * @return wasAccepted      Whether the snapshot was accepted by the Summit contract
     */
    function submitSnapshot(bytes memory _snapPayload, bytes memory _snapSignature)
        external
        returns (bool wasAccepted);

    /**
     * @notice Verifies an attestation signed by a Notary.
     *  - Does nothing, if the attestation is valid (was submitted by this Notary as a snapshot).
     *  - Slashes the Notary otherwise (meaning the attestation is invalid).
     * @dev Will revert if any of these is true:
     *  - Attestation payload is not properly formatted.
     *  - Attestation signer is not an active Notary.
     * @param _attPayload       Raw payload with Attestation data
     * @param _attSignature     Notary signature for the attestation
     * @return isValid          Whether the provided attestation is valid.
     *                          Notary is slashed, if return value is FALSE.
     */
    function verifyAttestation(bytes memory _attPayload, bytes memory _attSignature)
        external
        returns (bool isValid);

    /**
     * @notice Returns the state with the highest known nonce
     * submitted by any of the currently active Guards.
     * @param _origin       Domain of origin chain
     * @return statePayload Raw payload with latest active Guard state for origin
     */
    function getLatestState(uint32 _origin) external view returns (bytes memory statePayload);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
// ══════════════════════════════ LIBRARY IMPORTS ══════════════════════════════
import { Attestation, AttestationLib, SummitAttestation } from "../libs/Attestation.sol";
import { MerkleList } from "../libs/MerkleList.sol";
import { Snapshot, SnapshotLib, SummitSnapshot } from "../libs/Snapshot.sol";
import { State, StateLib, SummitState } from "../libs/State.sol";
import { TypedMemView } from "../libs/TypedMemView.sol";
// ═════════════════════════════ INTERNAL IMPORTS ══════════════════════════════
import { SnapshotHubEvents } from "../events/SnapshotHubEvents.sol";
import { ISnapshotHub } from "../interfaces/ISnapshotHub.sol";

/**
 * @notice Hub to accept and save snapshots, as well as verify attestations.
 */
abstract contract SnapshotHub is SnapshotHubEvents, ISnapshotHub {
    using AttestationLib for bytes;
    using SnapshotLib for uint256[];
    using StateLib for bytes;
    using TypedMemView for bytes29;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STORAGE                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev All States submitted by any of the Guards
    SummitState[] private guardStates;

    /// @dev All Snapshots submitted by any of the Guards
    SummitSnapshot[] private guardSnapshots;

    /// @dev All Snapshots submitted by any of the Notaries
    SummitSnapshot[] private notarySnapshots;

    /// @dev All Attestations created from Notary-submitted Snapshots
    /// Invariant: attestations.length == notarySnapshots.length
    SummitAttestation[] private attestations;

    /// @dev Pointer for the given State Leaf of the origin
    /// with ZERO as a sentinel value for "state not submitted yet".
    // (origin => (stateLeaf => {state index in guardStates PLUS 1}))
    mapping(uint32 => mapping(bytes32 => uint256)) private leafPtr;

    /// @dev Pointer for the latest Agent State of a given origin
    /// with ZERO as a sentinel value for "no states submitted yet".
    // (origin => (agent => {latest state index in guardStates PLUS 1}))
    mapping(uint32 => mapping(address => uint256)) private latestStatePtr;

    /// @dev gap for upgrade safety
    uint256[44] private __GAP; // solhint-disable-line var-name-mixedcase

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                VIEWS                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @inheritdoc ISnapshotHub
    function isValidAttestation(bytes memory _attPayload) external view returns (bool isValid) {
        // This will revert if payload is not a formatted attestation
        Attestation attestation = _attPayload.castToAttestation();
        return _isValidAttestation(attestation);
    }

    /// @inheritdoc ISnapshotHub
    function getLatestAgentState(uint32 _origin, address _agent)
        external
        view
        returns (bytes memory stateData)
    {
        SummitState memory latestState = _latestState(_origin, _agent);
        if (latestState.nonce == 0) return bytes("");
        return latestState.formatSummitState();
    }

    /// @inheritdoc ISnapshotHub
    function getGuardSnapshot(uint256 _index) external view returns (bytes memory snapshotPayload) {
        require(_index < guardSnapshots.length, "Index out of range");
        return _restoreSnapshot(guardSnapshots[_index]);
    }

    /// @inheritdoc ISnapshotHub
    function getNotarySnapshot(uint256 _nonce)
        external
        view
        returns (bytes memory snapshotPayload)
    {
        require(_nonce < notarySnapshots.length, "Nonce out of range");
        return _restoreSnapshot(notarySnapshots[_nonce]);
    }

    /// @inheritdoc ISnapshotHub
    function getNotarySnapshot(bytes memory _attPayload)
        external
        view
        returns (bytes memory snapshotPayload)
    {
        // This will revert if payload is not a formatted attestation
        Attestation attestation = _attPayload.castToAttestation();
        require(_isValidAttestation(attestation), "Invalid attestation");
        // Attestation is valid => attestations[nonce] exists
        // notarySnapshots.length == attestations.length => notarySnapshots[nonce] exists
        return _restoreSnapshot(notarySnapshots[attestation.nonce()]);
    }

    /// @inheritdoc ISnapshotHub
    function getSnapshotProof(uint256 _nonce, uint256 _stateIndex)
        external
        view
        returns (bytes32[] memory snapProof)
    {
        require(_nonce < notarySnapshots.length, "Nonce out of range");
        snapProof = new bytes32[](attestations[_nonce].height);
        SummitSnapshot memory snap = notarySnapshots[_nonce];
        uint256 statesAmount = snap.getStatesAmount();
        require(_stateIndex < statesAmount, "Index out of range");
        // Reconstruct the leafs of Snapshot Merkle Tree
        bytes32[] memory hashes = new bytes32[](statesAmount);
        for (uint256 i = 0; i < statesAmount; ++i) {
            // Get value for "index in guardStates PLUS 1"
            uint256 statePtr = snap.getStatePtr(i);
            // We are never saving zero values when accepting Guard/Notary snapshots, so this holds
            assert(statePtr != 0);
            SummitState memory guardState = guardStates[statePtr - 1];
            State state = guardState.formatSummitState().castToState();
            hashes[i] = state.hash();
            if (i == _stateIndex) {
                // First element of the proof is "right sub-leaf"
                (, snapProof[0]) = state.subLeafs();
            }
        }
        // This will fill the remaining values in the `snapProof` array
        MerkleList.calculateProof(hashes, _stateIndex, snapProof);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             ACCEPT DATA                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Accepts a Snapshot signed by a Guard.
    /// It is assumed that the Guard signature has been checked outside of this contract.
    function _acceptGuardSnapshot(Snapshot _snapshot, address _guard) internal {
        // Snapshot Signer is a Guard: save the states for later use.
        uint256 statesAmount = _snapshot.statesAmount();
        uint256[] memory statePtrs = new uint256[](statesAmount);
        for (uint256 i = 0; i < statesAmount; ++i) {
            statePtrs[i] = _saveState(_snapshot.state(i), _guard);
            // Guard either submitted a fresh state, or reused state submitted by another Guard
            // In any case, the "state pointer" would never be zero
            assert(statePtrs[i] != 0);
        }
        // Save Guard snapshot for later retrieval
        _saveGuardSnapshot(statePtrs);
    }

    /// @dev Accepts a Snapshot signed by a Notary.
    /// It is assumed that the Notary signature has been checked outside of this contract.
    function _acceptNotarySnapshot(Snapshot _snapshot, address _notary) internal {
        // Snapshot Signer is a Notary: construct an Attestation Merkle Tree,
        // while checking that the states were previously saved.
        uint256 statesAmount = _snapshot.statesAmount();
        uint256[] memory statePtrs = new uint256[](statesAmount);
        for (uint256 i = 0; i < statesAmount; ++i) {
            State state = _snapshot.state(i);
            uint256 statePtr = _statePtr(state);
            // Notary can only used states previously submitted by any fo the Guards
            require(statePtr != 0, "State doesn't exist");
            statePtrs[i] = statePtr;
            // Check that Notary hasn't used a fresher state for this origin before
            uint32 origin = state.origin();
            require(state.nonce() > _latestState(origin, _notary).nonce, "Outdated nonce");
            // Update Notary latest state for origin
            latestStatePtr[origin][_notary] = statePtrs[i];
        }
        // Derive attestation merkle root and save it for a Notary attestation.
        // Save Notary snapshot for later retrieval
        _saveNotarySnapshot(_snapshot, statePtrs);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         SAVE STATEMENT DATA                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Saves the Guard snapshot.
    function _saveGuardSnapshot(uint256[] memory statePtrs) internal {
        guardSnapshots.push(statePtrs.toSummitSnapshot());
    }

    /// @dev Saves the Notary snapshot and the attestation created from it.
    function _saveNotarySnapshot(Snapshot _snapshot, uint256[] memory statePtrs) internal {
        // Attestation nonce is its index in `attestations` array
        uint32 attNonce = uint32(attestations.length);
        SummitAttestation memory summitAtt = _snapshot.toSummitAttestation();
        /// @dev Add a single element to both `attestations` and `notarySnapshots`,
        /// enforcing the (attestations.length == notarySnapshots.length) invariant.
        attestations.push(summitAtt);
        notarySnapshots.push(statePtrs.toSummitSnapshot());
        // Emit event with raw attestation data
        emit AttestationSaved(summitAtt.formatSummitAttestation(attNonce));
    }

    /// @dev Saves the state signed by a Guard.
    function _saveState(State _state, address _guard) internal returns (uint256 statePtr) {
        uint32 origin = _state.origin();
        // Check that Guard hasn't submitted a fresher State before
        require(_state.nonce() > _latestState(origin, _guard).nonce, "Outdated nonce");
        bytes32 stateHash = _state.hash();
        statePtr = leafPtr[origin][stateHash];
        // Save state only if it wasn't previously submitted
        if (statePtr == 0) {
            // Extract data that needs to be saved
            SummitState memory state = _state.toSummitState();
            guardStates.push(state);
            // State is stored at (length - 1), but we are tracking "index PLUS 1" as "pointer"
            statePtr = guardStates.length;
            leafPtr[origin][stateHash] = statePtr;
            // Emit event with raw state data
            emit StateSaved(_state.unwrap().clone());
        }
        // Update latest guard state for origin
        latestStatePtr[origin][_guard] = statePtr;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         CHECK STATEMENT DATA                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Checks if attestation was previously submitted by a Notary (as a signed snapshot).
    function _isValidAttestation(Attestation _att) internal view returns (bool) {
        // Check if nonce exists
        uint32 nonce = _att.nonce();
        if (nonce >= attestations.length) return false;
        // Check if Attestation matches the historical one
        return _att.equalToSummit(attestations[nonce]);
    }

    /// @dev Restores Snapshot payload from a list of state pointers used for the snapshot.
    function _restoreSnapshot(SummitSnapshot memory _snapshot)
        internal
        view
        returns (bytes memory)
    {
        uint256 statesAmount = _snapshot.getStatesAmount();
        State[] memory states = new State[](statesAmount);
        for (uint256 i = 0; i < statesAmount; ++i) {
            // Get value for "index in guardStates PLUS 1"
            uint256 statePtr = _snapshot.getStatePtr(i);
            // We are never saving zero values when accepting Guard/Notary snapshots, so this holds
            assert(statePtr != 0);
            SummitState memory state = guardStates[statePtr - 1];
            // Get the state that Agent used for the snapshot
            states[i] = state.formatSummitState().castToState();
        }
        return SnapshotLib.formatSnapshot(states);
    }

    /// @dev Returns the pointer for a matching Guard State, if it exists.
    function _statePtr(State _state) internal view returns (uint256) {
        return leafPtr[_state.origin()][_state.hash()];
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          LATEST STATE VIEWS                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Returns the latest state submitted by the Agent for the origin.
    /// Will return an empty struct, if the Agent hasn't submitted a single origin State yet.
    function _latestState(uint32 _origin, address _agent)
        internal
        view
        returns (SummitState memory state)
    {
        // Get value for "index in guardStates PLUS 1"
        uint256 latestPtr = latestStatePtr[_origin][_agent];
        // Check if the Agent has submitted at least one State for origin
        if (latestPtr != 0) {
            state = guardStates[latestPtr - 1];
        }
        // An empty struct is returned if the Agent hasn't submitted a single State for origin yet.
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
// ══════════════════════════════ LIBRARY IMPORTS ══════════════════════════════
import { Attestation, AttestationLib } from "../libs/Attestation.sol";
import { Snapshot, SnapshotLib } from "../libs/Snapshot.sol";
// ═════════════════════════════ INTERNAL IMPORTS ══════════════════════════════
import { AgentRegistry } from "../system/AgentRegistry.sol";
import { Version0_0_2 } from "../Version.sol";
// ═════════════════════════════ EXTERNAL IMPORTS ══════════════════════════════
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @notice This abstract contract is used for verifying Guards and Notaries
 * signature over several type of statements such as:
 * - Attestations
 * - Snapshots
 * - Reports
 * Several checks are performed in StatementHub, abstracting it away from the child contracts:
 * - Statement being properly formatted
 * - Signer being an active agent
 * - Signer being allowed to sign the particular type of statement
 */
abstract contract StatementHub is AgentRegistry, Version0_0_2 {
    using AttestationLib for bytes;
    using SnapshotLib for bytes;

    /**
     * @dev Recovers a signer from a hashed message, and a EIP-191 signature for it.
     * Will revert, if the signer is not an active agent.
     * @param _hashedStatement  Hash of the statement that was signed by an Agent
     * @param _signature        Agent signature for the hashed statement
     * @return domain   Domain where the signed Agent is active
     * @return agent    Agent that signed the statement
     */
    function _recoverAgent(bytes32 _hashedStatement, bytes memory _signature)
        internal
        view
        returns (uint32 domain, address agent)
    {
        bytes32 ethSignedMsg = ECDSA.toEthSignedMessageHash(_hashedStatement);
        agent = ECDSA.recover(ethSignedMsg, _signature);
        bool isActive;
        (isActive, domain) = _isActiveAgent(agent);
        require(isActive, "Not an active agent");
    }

    /**
     * @dev Internal function to verify the signed attestation payload.
     * Reverts if either of this is true:
     *  - Attestation payload is not properly formatted.
     *  - Attestation signer is not an active Notary.
     * @param _attPayload       Raw payload with attestation data
     * @param _attSignature     Notary signature for the attestation
     * @return attestation      Typed memory view over attestation payload
     * @return domain           Domain where the signed Notary is active
     * @return notary           Notary that signed the snapshot
     */
    function _verifyAttestation(bytes memory _attPayload, bytes memory _attSignature)
        internal
        view
        returns (
            Attestation attestation,
            uint32 domain,
            address notary
        )
    {
        // This will revert if payload is not a formatted attestation
        attestation = _attPayload.castToAttestation();
        // This will revert if signer is not an active agent
        (domain, notary) = _recoverAgent(attestation.hash(), _attSignature);
        // Attestation signer needs to be a Notary, not a Guard
        require(domain != 0, "Signer is not a Notary");
    }

    /**
     * @dev Internal function to verify the signed snapshot payload.
     * Reverts if either of this is true:
     *  - Snapshot payload is not properly formatted.
     *  - Snapshot signer is not an active Agent.
     * @param _snapPayload      Raw payload with snapshot data
     * @param _snapSignature    Agent signature for the snapshot
     * @return snapshot         Typed memory view over snapshot payload
     * @return domain           Domain where the signed Agent is active
     * @return agent            Agent that signed the snapshot
     */
    function _verifySnapshot(bytes memory _snapPayload, bytes memory _snapSignature)
        internal
        view
        returns (
            Snapshot snapshot,
            uint32 domain,
            address agent
        )
    {
        // This will revert if payload is not a formatted snapshot
        snapshot = _snapPayload.castToSnapshot();
        // This will revert if signer is not an active agent
        (domain, agent) = _recoverAgent(snapshot.hash(), _snapSignature);
        // Guards and Notaries for all domains could sign Snapshots, no further checks are needed.
    }

    /**
     * @dev Internal function to verify that snapshot root matches the root from Attestation.
     * Reverts if either of this is true:
     *  - Snapshot payload is not properly formatted.
     *  - Attestation root is not equal to root derived from the snapshot.
     * @param _att          Typed memory view over Attestation
     * @param _snapPayload  Raw payload with snapshot data
     * @return snapshot     Typed memory view over snapshot payload
     */
    function _verifySnapshotRoot(Attestation _att, bytes memory _snapPayload)
        internal
        pure
        returns (Snapshot snapshot)
    {
        // This will revert if payload is not a formatted snapshot
        snapshot = _snapPayload.castToSnapshot();
        require(_att.root() == snapshot.root(), "Incorrect snapshot root");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { TypedMemView } from "./TypedMemView.sol";

/// @dev CallData is a memory view over the payload to be used for an external call, i.e.
/// recipient.call(callData). Its length is always (4 + 32 * N) bytes:
/// - First 4 bytes represent the function selector.
/// - 32 * N bytes represent N words that function arguments occupy.
type CallData is bytes29;
/// @dev Signature is a memory view over a "65 bytes" array representing a ECDSA signature.
type Signature is bytes29;

library ByteString {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;

    /**
     * @dev non-compact ECDSA signatures are enforced as of OZ 4.7.3
     *
     *      Signature payload memory layout
     * [000 .. 032) r   bytes32 32 bytes
     * [032 .. 064) s   bytes32 32 bytes
     * [064 .. 065) v   uint8    1 byte
     */
    uint256 internal constant SIGNATURE_LENGTH = 65;
    uint256 internal constant OFFSET_R = 0;
    uint256 internal constant OFFSET_S = 32;
    uint256 internal constant OFFSET_V = 64;

    /**
     * @dev Calldata memory layout
     * [000 .. 004) selector    bytes4  4 bytes
     *      Optional: N function arguments
     * [004 .. 036) arg1        bytes32 32 bytes
     *      ..
     * [AAA .. END) argN        bytes32 32 bytes
     */
    uint256 internal constant SELECTOR_LENGTH = 4;
    uint256 internal constant OFFSET_SELECTOR = 0;
    uint256 internal constant OFFSET_ARGUMENTS = SELECTOR_LENGTH;

    /**
     * @notice Returns a memory view over the given payload, treating it as raw bytes.
     * @dev Shortcut for .ref(0) - to be deprecated once "uint40 type" is removed from bytes29.
     */
    function castToRawBytes(bytes memory _payload) internal pure returns (bytes29) {
        return _payload.ref({ newType: 0 });
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              SIGNATURE                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Constructs the signature payload from the given values.
     * @dev Using ByteString.formatSignature({r: r, s: s, v: v}) will make sure
     * that params are given in the right order.
     */
    function formatSignature(
        bytes32 r,
        bytes32 s,
        uint8 v
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(r, s, v);
    }

    /**
     * @notice Returns a Signature view over for the given payload.
     * @dev Will revert if the payload is not a signature.
     */
    function castToSignature(bytes memory _payload) internal pure returns (Signature) {
        return castToSignature(castToRawBytes(_payload));
    }

    /**
     * @notice Casts a memory view to a Signature view.
     * @dev Will revert if the memory view is not over a signature.
     */
    function castToSignature(bytes29 _view) internal pure returns (Signature) {
        require(isSignature(_view), "Not a signature");
        return Signature.wrap(_view);
    }

    /**
     * @notice Checks that a byte string is a signature
     */
    function isSignature(bytes29 _view) internal pure returns (bool) {
        return _view.len() == SIGNATURE_LENGTH;
    }

    /// @notice Convenience shortcut for unwrapping a view.
    function unwrap(Signature _signature) internal pure returns (bytes29) {
        return Signature.unwrap(_signature);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          SIGNATURE SLICING                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Unpacks signature payload into (r, s, v) parameters.
    /// @dev Make sure to verify signature length with isSignature() beforehand.
    function toRSV(Signature _signature)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        // Get the underlying memory view
        bytes29 _view = unwrap(_signature);
        r = _view.index({ _index: OFFSET_R, _bytes: 32 });
        s = _view.index({ _index: OFFSET_S, _bytes: 32 });
        v = uint8(_view.indexUint({ _index: OFFSET_V, _bytes: 1 }));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               CALLDATA                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Returns a CallData view over for the given payload.
     * @dev Will revert if the memory view is not over a calldata.
     */
    function castToCallData(bytes memory _payload) internal pure returns (CallData) {
        return castToCallData(castToRawBytes(_payload));
    }

    /**
     * @notice Casts a memory view to a CallData view.
     * @dev Will revert if the memory view is not over a calldata.
     */
    function castToCallData(bytes29 _view) internal pure returns (CallData) {
        require(isCallData(_view), "Not a calldata");
        return CallData.wrap(_view);
    }

    /**
     * @notice Checks that a byte string is a valid calldata, i.e.
     * a function selector, followed by arbitrary amount of arguments.
     */
    function isCallData(bytes29 _view) internal pure returns (bool) {
        uint256 length = _view.len();
        // Calldata should at least have a function selector
        if (length < SELECTOR_LENGTH) return false;
        // The remainder of the calldata should be exactly N words (N >= 0), i.e.
        // (length - SELECTOR_LENGTH) % 32 == 0
        // We're using logical AND here to speed it up a bit
        return (length - SELECTOR_LENGTH) & 31 == 0;
    }

    /// @notice Convenience shortcut for unwrapping a view.
    function unwrap(CallData _callData) internal pure returns (bytes29) {
        return CallData.unwrap(_callData);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           CALLDATA SLICING                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Returns amount of memory words (32 byte chunks) the function arguments
     * occupy in the calldata.
     * @dev This might differ from amount of arguments supplied, if any of the arguments
     * occupies more than one memory slot. It is true, however, that argument part of the payload
     * occupies exactly N words, even for dynamic types like `bytes`
     */
    function argumentWords(CallData _callData) internal pure returns (uint256) {
        // Get the underlying memory view
        bytes29 _view = unwrap(_callData);
        // Equivalent of (length - SELECTOR_LENGTH) / 32
        return (_view.len() - SELECTOR_LENGTH) >> 5;
    }

    /// @notice Returns selector for the provided calldata.
    function callSelector(CallData _callData) internal pure returns (bytes29) {
        // Get the underlying memory view
        bytes29 _view = unwrap(_callData);
        return _view.slice({ _index: OFFSET_SELECTOR, _len: SELECTOR_LENGTH, newType: 0 });
    }

    /// @notice Returns abi encoded arguments for the provided calldata.
    function arguments(CallData _callData) internal pure returns (bytes29) {
        // Get the underlying memory view
        bytes29 _view = unwrap(_callData);
        return _view.sliceFrom({ _index: OFFSET_ARGUMENTS, newType: 0 });
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Here we define common constants to enable their easier reusing later.

/// @dev See Attestation.sol: (bytes32,uint8,uint32,uint40,uint40): 32+1+4+5+5
uint256 constant ATTESTATION_LENGTH = 47;

/// @dev See State.sol: (bytes32,uint32,uint32,uint40,uint40): 32+4+4+5+5
uint256 constant STATE_LENGTH = 50;

/// @dev Maximum amount of states in a single snapshot
uint256 constant SNAPSHOT_MAX_STATES = 32;

/// @dev Root for an empty Origin Merkle Tree.
bytes32 constant EMPTY_ROOT = hex"27ae5ba08d7291c96c8cbddcc148bf48a6d68c7974b94356f53754ef6171d757";

/// @dev Depth of the Origin Merkle Tree
uint256 constant ORIGIN_TREE_DEPTH = 32;

/// @dev Maximum bytes per message = 2 KiB (somewhat arbitrarily set to begin)
uint256 constant MAX_MESSAGE_BODY_BYTES = 2 * 2**10;

/**
 * @dev Custom address used for sending and receiving system messages.
 *  - Origin will dispatch messages from SystemRouter as if they were "sent by this sender".
 *  - Destination will reroute messages "sent to this recipient" to SystemRouter.
 *  - As a result: only SystemRouter messages will have this value as both sender and recipient.
 * Note: all bits except for lower 20 bytes are set to 1.
 * Note: TypeCasts.bytes32ToAddress(SYSTEM_ROUTER) == address(0)
 */
bytes32 constant SYSTEM_ROUTER = bytes32(type(uint256).max << 160);

// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.12;

library TypedMemView {
    // Why does this exist?
    // the solidity `bytes memory` type has a few weaknesses.
    // 1. You can't index ranges effectively
    // 2. You can't slice without copying
    // 3. The underlying data may represent any type
    // 4. Solidity never deallocates memory, and memory costs grow
    //    superlinearly

    // By using a memory view instead of a `bytes memory` we get the following
    // advantages:
    // 1. Slices are done on the stack, by manipulating the pointer
    // 2. We can index arbitrary ranges and quickly convert them to stack types
    // 3. We can insert type info into the pointer, and typecheck at runtime

    // This makes `TypedMemView` a useful tool for efficient zero-copy
    // algorithms.

    // Why bytes29?
    // We want to avoid confusion between views, digests, and other common
    // types so we chose a large and uncommonly used odd number of bytes
    //
    // Note that while bytes are left-aligned in a word, integers and addresses
    // are right-aligned. This means when working in assembly we have to
    // account for the 3 unused bytes on the righthand side
    //
    // First 5 bytes are a type flag.
    // - ff_ffff_fffe is reserved for unknown type.
    // - ff_ffff_ffff is reserved for invalid types/errors.
    // next 12 are memory address
    // next 12 are len
    // bottom 3 bytes are empty

    // Assumptions:
    // - non-modification of memory.
    // - No Solidity updates
    // - - wrt free mem point
    // - - wrt bytes representation in memory
    // - - wrt memory addressing in general

    // Usage:
    // - create type constants
    // - use `assertType` for runtime type assertions
    // - - unfortunately we can't do this at compile time yet :(
    // - recommended: implement modifiers that perform type checking
    // - - e.g.
    // - - `uint40 constant MY_TYPE = 3;`
    // - - ` modifier onlyMyType(bytes29 myView) { myView.assertType(MY_TYPE); }`
    // - instantiate a typed view from a bytearray using `ref`
    // - use `index` to inspect the contents of the view
    // - use `slice` to create smaller views into the same memory
    // - - `slice` can increase the offset
    // - - `slice can decrease the length`
    // - - must specify the output type of `slice`
    // - - `slice` will return a null view if you try to overrun
    // - - make sure to explicitly check for this with `notNull` or `assertType`
    // - use `equal` for typed comparisons.

    // The null view
    bytes29 public constant NULL = hex"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";

    /**
     * @dev Memory layout for bytes29
     * TODO (Chi): with the user defined types storing type is no longer necessary.
     * Update the library, transforming bytes29 to bytes24 in the process.
     * [000..005)   type     5 bytes    Type flag for the pointer
     * [005..017)   loc     12 bytes    Memory address of underlying bytes
     * [017..029)   len     12 bytes    Length of underlying bytes
     * [029..032)   empty    3 bytes    Not used
     */
    uint256 public constant BITS_TYPE = 40;
    uint256 public constant BITS_LOC = 96;
    uint256 public constant BITS_LEN = 96;
    uint256 public constant BITS_EMPTY = 24;

    // `SHIFT_X` is how much bits to shift for `X` to be in the very bottom bits
    uint256 public constant SHIFT_LEN = BITS_EMPTY; // 24
    uint256 public constant SHIFT_LOC = SHIFT_LEN + BITS_LEN; // 24 + 96 = 120
    uint256 public constant SHIFT_TYPE = SHIFT_LOC + BITS_LOC; // 24 + 96 + 96 = 216
    // Bitmask for the lowest 96 bits
    uint256 public constant LOW_96_BITS_MASK = type(uint96).max;

    // For nibble encoding
    bytes private constant NIBBLE_LOOKUP = "0123456789abcdef";

    /**
     * @notice Returns the encoded hex character that represents the lower 4 bits of the argument.
     * @param _byte     The byte
     * @return _char    The encoded hex character
     */
    function nibbleHex(uint8 _byte) internal pure returns (uint8 _char) {
        uint8 _nibble = _byte & 0x0f; // keep bottom 4 bits, zero out top 4 bits
        _char = uint8(NIBBLE_LOOKUP[_nibble]);
    }

    /**
     * @notice      Returns a uint16 containing the hex-encoded byte.
     * @param _b    The byte
     * @return      encoded - The hex-encoded byte
     */
    function byteHex(uint8 _b) internal pure returns (uint16 encoded) {
        encoded |= nibbleHex(_b >> 4); // top 4 bits
        encoded <<= 8;
        encoded |= nibbleHex(_b); // lower 4 bits
    }

    /**
     * @notice      Encodes the uint256 to hex. `first` contains the encoded top 16 bytes.
     *              `second` contains the encoded lower 16 bytes.
     *
     * @param _b    The 32 bytes as uint256
     * @return      first - The top 16 bytes
     * @return      second - The bottom 16 bytes
     */
    function encodeHex(uint256 _b) internal pure returns (uint256 first, uint256 second) {
        for (uint8 i = 31; i > 15; ) {
            uint8 _byte = uint8(_b >> (i * 8));
            first |= byteHex(_byte);
            if (i != 16) {
                first <<= 16;
            }
            unchecked {
                i -= 1;
            }
        }

        // abusing underflow here =_=
        for (uint8 i = 15; i < 255; ) {
            uint8 _byte = uint8(_b >> (i * 8));
            second |= byteHex(_byte);
            if (i != 0) {
                second <<= 16;
            }
            unchecked {
                i -= 1;
            }
        }
    }

    /**
     * @notice          Changes the endianness of a uint256.
     * @dev             https://graphics.stanford.edu/~seander/bithacks.html#ReverseParallel
     * @param _b        The unsigned integer to reverse
     * @return          v - The reversed value
     */
    function reverseUint256(uint256 _b) internal pure returns (uint256 v) {
        v = _b;

        // swap bytes
        v =
            ((v >> 8) & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) |
            ((v & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) << 8);
        // swap 2-byte long pairs
        v =
            ((v >> 16) & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) |
            ((v & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) << 16);
        // swap 4-byte long pairs
        v =
            ((v >> 32) & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) |
            ((v & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) << 32);
        // swap 8-byte long pairs
        v =
            ((v >> 64) & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) |
            ((v & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) << 64);
        // swap 16-byte long pairs
        v = (v >> 128) | (v << 128);
    }

    /**
     * @notice      Create a mask with the highest `_len` bits set.
     * @param _len  The length
     * @return      mask - The mask
     */
    function leftMask(uint8 _len) private pure returns (uint256 mask) {
        // 0x800...00 binary representation is 100...00
        // sar stands for "signed arithmetic shift": https://en.wikipedia.org/wiki/Arithmetic_shift
        // sar(N-1, 100...00) = 11...100..00, with exactly N highest bits set to 1
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            mask := sar(
                sub(_len, 1),
                0x8000000000000000000000000000000000000000000000000000000000000000
            )
        }
    }

    /**
     * @notice      Return the null view.
     * @return      bytes29 - The null view
     */
    // solhint-disable-next-line ordering
    function nullView() internal pure returns (bytes29) {
        return NULL;
    }

    /**
     * @notice      Check if the view is null.
     * @return      bool - True if the view is null
     */
    function isNull(bytes29 memView) internal pure returns (bool) {
        return memView == NULL;
    }

    /**
     * @notice      Check if the view is not null.
     * @return      bool - True if the view is not null
     */
    function notNull(bytes29 memView) internal pure returns (bool) {
        return !isNull(memView);
    }

    /**
     * @notice          Check if the view is of a valid type and points to a valid location
     *                  in memory.
     * @dev             We perform this check by examining solidity's unallocated memory
     *                  pointer and ensuring that the view's upper bound is less than that.
     * @param memView   The view
     * @return          ret - True if the view is valid
     */
    function isValid(bytes29 memView) internal pure returns (bool ret) {
        if (typeOf(memView) == 0xffffffffff) {
            return false;
        }
        uint256 _end = end(memView);
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // View is valid if ("upper bound" <= "unallocated memory pointer")
            // Upper bound is exclusive, hence "<="
            ret := not(gt(_end, mload(0x40)))
        }
    }

    /**
     * @notice          Require that a typed memory view be valid.
     * @dev             Returns the view for easy chaining.
     * @param memView   The view
     * @return          bytes29 - The validated view
     */
    function assertValid(bytes29 memView) internal pure returns (bytes29) {
        require(isValid(memView), "Validity assertion failed");
        return memView;
    }

    /**
     * @notice          Return true if the memview is of the expected type. Otherwise false.
     * @param memView   The view
     * @param _expected The expected type
     * @return          bool - True if the memview is of the expected type
     */
    function isType(bytes29 memView, uint40 _expected) internal pure returns (bool) {
        return typeOf(memView) == _expected;
    }

    /**
     * @notice          Require that a typed memory view has a specific type.
     * @dev             Returns the view for easy chaining.
     * @param memView   The view
     * @param _expected The expected type
     * @return          bytes29 - The view with validated type
     */
    function assertType(bytes29 memView, uint40 _expected) internal pure returns (bytes29) {
        if (!isType(memView, _expected)) {
            (, uint256 g) = encodeHex(uint256(typeOf(memView)));
            (, uint256 e) = encodeHex(uint256(_expected));
            string memory err = string(
                abi.encodePacked(
                    "Type assertion failed. Got 0x",
                    uint80(g),
                    ". Expected 0x",
                    uint80(e)
                )
            );
            revert(err);
        }
        return memView;
    }

    /**
     * @notice          Return an identical view with a different type.
     * @param memView   The view
     * @param _newType  The new type
     * @return          newView - The new view with the specified type
     */
    function castTo(bytes29 memView, uint40 _newType) internal pure returns (bytes29 newView) {
        // How many bits are the "type bits" occupying
        uint256 _bitsType = BITS_TYPE;
        // How many bits are the "type bits" shifted from the bottom
        uint256 _shiftType = SHIFT_TYPE;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // shift off the "type bits" (shift left, then sift right)
            newView := or(newView, shr(_bitsType, shl(_bitsType, memView)))
            // set the new "type bits" (shift left, then OR)
            newView := or(newView, shl(_shiftType, _newType))
        }
    }

    /**
     * @notice          Unsafe raw pointer construction. This should generally not be called
     *                  directly. Prefer `ref` wherever possible.
     * @dev             Unsafe raw pointer construction. This should generally not be called
     *                  directly. Prefer `ref` wherever possible.
     * @param _type     The type
     * @param _loc      The memory address
     * @param _len      The length
     * @return          newView - The new view with the specified type, location and length
     */
    function unsafeBuildUnchecked(
        uint256 _type,
        uint256 _loc,
        uint256 _len
    ) private pure returns (bytes29 newView) {
        uint256 _bitsLoc = BITS_LOC;
        uint256 _bitsLen = BITS_LEN;
        uint256 _bitsEmpty = BITS_EMPTY;
        // Ref memory layout
        // [000..005) 5 bytes of type
        // [005..017) 12 bytes of location
        // [017..029) 12 bytes of length
        // last 3 bits are blank and dropped in typecast
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // insert `type`, shift to prepare empty bits for `loc`
            newView := shl(_bitsLoc, or(newView, _type))
            // insert `loc`, shift to prepare empty bits for `len`
            newView := shl(_bitsLen, or(newView, _loc))
            // insert `len`, shift to insert 3 blank lowest bits
            newView := shl(_bitsEmpty, or(newView, _len))
        }
    }

    /**
     * @notice          Instantiate a new memory view. This should generally not be called
     *                  directly. Prefer `ref` wherever possible.
     * @dev             Instantiate a new memory view. This should generally not be called
     *                  directly. Prefer `ref` wherever possible.
     * @param _type     The type
     * @param _loc      The memory address
     * @param _len      The length
     * @return          newView - The new view with the specified type, location and length
     */
    function build(
        uint256 _type,
        uint256 _loc,
        uint256 _len
    ) internal pure returns (bytes29 newView) {
        uint256 _end = _loc + _len;
        // Make sure that a view is not constructed that points to unallocated memory
        // as this could be indicative of a buffer overflow attack
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            if gt(_end, mload(0x40)) {
                _end := 0
            }
        }
        if (_end == 0) {
            return NULL;
        }
        newView = unsafeBuildUnchecked(_type, _loc, _len);
    }

    /**
     * @notice          Instantiate a memory view from a byte array.
     * @dev             Note that due to Solidity memory representation, it is not possible to
     *                  implement a deref, as the `bytes` type stores its len in memory.
     * @param arr       The byte array
     * @param newType   The type
     * @return          bytes29 - The memory view
     */
    function ref(bytes memory arr, uint40 newType) internal pure returns (bytes29) {
        uint256 _len = arr.length;
        // `bytes arr` is stored in memory in the following way
        // 1. First, uint256 arr.length is stored. That requires 32 bytes (0x20).
        // 2. Then, the array data is stored.
        uint256 _loc;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // We add 0x20, so that the view starts exactly where the array data starts
            _loc := add(arr, 0x20)
        }

        return build(newType, _loc, _len);
    }

    /**
     * @notice          Return the associated type information.
     * @param memView   The memory view
     * @return          _type - The type associated with the view
     */
    function typeOf(bytes29 memView) internal pure returns (uint40 _type) {
        // How many bits are the "type bits" shifted from the bottom
        uint256 _shiftType = SHIFT_TYPE;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // Shift out the bottom bits preceding "type bits". "type bits" are occupying
            // the highest bits, so all that's left is "type bits", OR is not required.
            _type := shr(_shiftType, memView)
        }
    }

    /**
     * @notice          Optimized type comparison. Checks that the 5-byte type flag is equal.
     * @param left      The first view
     * @param right     The second view
     * @return          bool - True if the 5-byte type flag is equal
     */
    function sameType(bytes29 left, bytes29 right) internal pure returns (bool) {
        // Check that the highest 5 bytes are equal: xor and shift out lower 27 bytes
        return (left ^ right) >> SHIFT_TYPE == 0;
    }

    /**
     * @notice          Return the memory address of the underlying bytes.
     * @param memView   The view
     * @return          _loc - The memory address
     */
    function loc(bytes29 memView) internal pure returns (uint96 _loc) {
        // How many bits are the "loc bits" shifted from the bottom
        uint256 _shiftLoc = SHIFT_LOC;
        // Mask for the bottom 96 bits
        uint256 _uint96Mask = LOW_96_BITS_MASK;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // Shift out the bottom bits preceding "loc bits".
            // Then use the lowest 96 bits to determine `loc` by applying the bit-mask.
            _loc := and(shr(_shiftLoc, memView), _uint96Mask)
        }
    }

    /**
     * @notice          The number of memory words this memory view occupies, rounded up.
     * @param memView   The view
     * @return          uint256 - The number of memory words
     */
    function words(bytes29 memView) internal pure returns (uint256) {
        // returning ceil(length / 32.0)
        return (uint256(len(memView)) + 31) / 32;
    }

    /**
     * @notice          The in-memory footprint of a fresh copy of the view.
     * @param memView   The view
     * @return          uint256 - The in-memory footprint of a fresh copy of the view.
     */
    function footprint(bytes29 memView) internal pure returns (uint256) {
        return words(memView) * 32;
    }

    /**
     * @notice          The number of bytes of the view.
     * @param memView   The view
     * @return          _len - The length of the view
     */
    function len(bytes29 memView) internal pure returns (uint96 _len) {
        // How many bits are the "len bits" shifted from the bottom
        uint256 _shiftLen = SHIFT_LEN;
        // Mask for the bottom 96 bits
        uint256 _uint96Mask = LOW_96_BITS_MASK;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // Shift out the bottom bits preceding "len bits".
            // Then use the lowest 96 bits to determine `len` by applying the bit-mask.
            _len := and(shr(_shiftLen, memView), _uint96Mask)
        }
    }

    /**
     * @notice          Returns the endpoint of `memView`.
     * @param memView   The view
     * @return          uint256 - The endpoint of `memView`
     */
    function end(bytes29 memView) internal pure returns (uint256) {
        unchecked {
            return loc(memView) + len(memView);
        }
    }

    /**
     * @notice          Safe slicing without memory modification.
     * @param memView   The view
     * @param _index    The start index
     * @param _len      The length
     * @param newType   The new type
     * @return          bytes29 - The new view
     */
    function slice(
        bytes29 memView,
        uint256 _index,
        uint256 _len,
        uint40 newType
    ) internal pure returns (bytes29) {
        uint256 _loc = loc(memView);

        // Ensure it doesn't overrun the view
        if (_loc + _index + _len > end(memView)) {
            return NULL;
        }

        _loc = _loc + _index;
        return build(newType, _loc, _len);
    }

    /**
     * @notice          Shortcut to `slice`. Gets a view representing
     *                  bytes from `_index` to end(memView).
     * @param memView   The view
     * @param _index    The start index
     * @param newType   The new type
     * @return          bytes29 - The new view
     */
    function sliceFrom(
        bytes29 memView,
        uint256 _index,
        uint40 newType
    ) internal pure returns (bytes29) {
        return slice(memView, _index, len(memView) - _index, newType);
    }

    /**
     * @notice          Shortcut to `slice`. Gets a view representing the first `_len` bytes.
     * @param memView   The view
     * @param _len      The length
     * @param newType   The new type
     * @return          bytes29 - The new view
     */
    function prefix(
        bytes29 memView,
        uint256 _len,
        uint40 newType
    ) internal pure returns (bytes29) {
        return slice(memView, 0, _len, newType);
    }

    /**
     * @notice          Shortcut to `slice`. Gets a view representing the last `_len` byte.
     * @param memView   The view
     * @param _len      The length
     * @param newType   The new type
     * @return          bytes29 - The new view
     */
    function postfix(
        bytes29 memView,
        uint256 _len,
        uint40 newType
    ) internal pure returns (bytes29) {
        return slice(memView, uint256(len(memView)) - _len, _len, newType);
    }

    /**
     * @notice          Construct an error message for an indexing overrun.
     * @param _loc      The memory address
     * @param _len      The length
     * @param _index    The index
     * @param _slice    The slice where the overrun occurred
     * @return          err - The err
     */
    function indexErrOverrun(
        uint256 _loc,
        uint256 _len,
        uint256 _index,
        uint256 _slice
    ) internal pure returns (string memory err) {
        (, uint256 a) = encodeHex(_loc);
        (, uint256 b) = encodeHex(_len);
        (, uint256 c) = encodeHex(_index);
        (, uint256 d) = encodeHex(_slice);
        err = string(
            abi.encodePacked(
                "TypedMemView/index - Overran the view. Slice is at 0x",
                uint48(a),
                " with length 0x",
                uint48(b),
                ". Attempted to index at offset 0x",
                uint48(c),
                " with length 0x",
                uint48(d),
                "."
            )
        );
    }

    /**
     * @notice          Load up to 32 bytes from the view onto the stack.
     * @dev             Returns a bytes32 with only the `_bytes` highest bytes set.
     *                  This can be immediately cast to a smaller fixed-length byte array.
     *                  To automatically cast to an integer, use `indexUint`.
     * @param memView   The view
     * @param _index    The index
     * @param _bytes    The bytes
     * @return          result - The 32 byte result
     */
    function index(
        bytes29 memView,
        uint256 _index,
        uint8 _bytes
    ) internal pure returns (bytes32 result) {
        if (_bytes == 0) {
            return bytes32(0);
        }
        if (_index + _bytes > len(memView)) {
            revert(indexErrOverrun(loc(memView), len(memView), _index, uint256(_bytes)));
        }
        require(_bytes <= 32, "Index: more than 32 bytes");

        uint8 bitLength;
        unchecked {
            bitLength = _bytes * 8;
        }
        uint256 _loc = loc(memView);
        // Get a mask with `bitLength` highest bits set
        uint256 _mask = leftMask(bitLength);
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // Load a full word using index offset, and apply mask to ignore non-relevant bytes
            result := and(mload(add(_loc, _index)), _mask)
        }
    }

    /**
     * @notice          Parse an unsigned integer from the view at `_index`.
     * @dev             Requires that the view have >= `_bytes` bytes following that index.
     * @param memView   The view
     * @param _index    The index
     * @param _bytes    The bytes
     * @return          result - The unsigned integer
     */
    function indexUint(
        bytes29 memView,
        uint256 _index,
        uint8 _bytes
    ) internal pure returns (uint256 result) {
        // `index()` returns left-aligned `_bytes`, while integers are right-aligned
        // Shifting here to right-align with the full 32 bytes word
        return uint256(index(memView, _index, _bytes)) >> ((32 - _bytes) * 8);
    }

    /**
     * @notice          Parse an unsigned integer from LE bytes.
     * @param memView   The view
     * @param _index    The index
     * @param _bytes    The bytes
     * @return          result - The unsigned integer
     */
    function indexLEUint(
        bytes29 memView,
        uint256 _index,
        uint8 _bytes
    ) internal pure returns (uint256 result) {
        return reverseUint256(uint256(index(memView, _index, _bytes)));
    }

    /**
     * @notice          Parse an address from the view at `_index`.
     *                  Requires that the view have >= 20 bytes following that index.
     * @param memView   The view
     * @param _index    The index
     * @return          address - The address
     */
    function indexAddress(bytes29 memView, uint256 _index) internal pure returns (address) {
        // index 20 bytes as `uint160`, and then cast to `address`
        return address(uint160(indexUint(memView, _index, 20)));
    }

    /**
     * @notice          Return the keccak256 hash of the underlying memory
     * @param memView   The view
     * @return          digest - The keccak256 hash of the underlying memory
     */
    function keccak(bytes29 memView) internal pure returns (bytes32 digest) {
        uint256 _loc = loc(memView);
        uint256 _len = len(memView);
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            digest := keccak256(_loc, _len)
        }
    }

    /**
     * @notice          Return the sha2 digest of the underlying memory.
     * @dev             We explicitly deallocate memory afterwards.
     * @param memView   The view
     * @return          digest - The sha2 hash of the underlying memory
     */
    function sha2(bytes29 memView) internal view returns (bytes32 digest) {
        uint256 _loc = loc(memView);
        uint256 _len = len(memView);
        bool res;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            let ptr := mload(0x40)
            // sha2 precompile is 0x02
            res := staticcall(gas(), 0x02, _loc, _len, ptr, 0x20)
            digest := mload(ptr)
        }
        require(res, "sha2: out of gas");
    }

    /**
     * @notice          Implements bitcoin's hash160 (rmd160(sha2()))
     * @param memView   The pre-image
     * @return          digest - the Digest
     */
    function hash160(bytes29 memView) internal view returns (bytes20 digest) {
        uint256 _loc = loc(memView);
        uint256 _len = len(memView);
        bool res;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            let ptr := mload(0x40)
            // sha2 precompile is 0x02
            res := staticcall(gas(), 0x02, _loc, _len, ptr, 0x20)
            // rmd160 precompile is 0x03
            res := and(res, staticcall(gas(), 0x03, ptr, 0x20, ptr, 0x20))
            digest := mload(add(ptr, 0xc)) // return value is 0-prefixed.
        }
        require(res, "hash160: out of gas");
    }

    /**
     * @notice          Implements bitcoin's hash256 (double sha2)
     * @param memView   A view of the preimage
     * @return          digest - the Digest
     */
    function hash256(bytes29 memView) internal view returns (bytes32 digest) {
        uint256 _loc = loc(memView);
        uint256 _len = len(memView);
        bool res;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            let ptr := mload(0x40)
            // sha2 precompile is 0x02
            res := staticcall(gas(), 0x02, _loc, _len, ptr, 0x20)
            res := and(res, staticcall(gas(), 0x02, ptr, 0x20, ptr, 0x20))
            digest := mload(ptr)
        }
        require(res, "hash256: out of gas");
    }

    /**
     * @notice          Return true if the underlying memory is equal. Else false.
     * @param left      The first view
     * @param right     The second view
     * @return          bool - True if the underlying memory is equal
     */
    function untypedEqual(bytes29 left, bytes29 right) internal pure returns (bool) {
        return
            (loc(left) == loc(right) && len(left) == len(right)) || keccak(left) == keccak(right);
    }

    /**
     * @notice          Return false if the underlying memory is equal. Else true.
     * @param left      The first view
     * @param right     The second view
     * @return          bool - False if the underlying memory is equal
     */
    function untypedNotEqual(bytes29 left, bytes29 right) internal pure returns (bool) {
        return !untypedEqual(left, right);
    }

    /**
     * @notice          Compares type equality.
     * @dev             Shortcuts if the pointers are identical, otherwise compares type and digest.
     * @param left      The first view
     * @param right     The second view
     * @return          bool - True if the types are the same
     */
    function equal(bytes29 left, bytes29 right) internal pure returns (bool) {
        return left == right || (typeOf(left) == typeOf(right) && keccak(left) == keccak(right));
    }

    /**
     * @notice          Compares type inequality.
     * @dev             Shortcuts if the pointers are identical, otherwise compares type and digest.
     * @param left      The first view
     * @param right     The second view
     * @return          bool - True if the types are not the same
     */
    function notEqual(bytes29 left, bytes29 right) internal pure returns (bool) {
        return !equal(left, right);
    }

    /**
     * @notice          Copy the view to a location, return an unsafe memory reference
     * @dev             Super Dangerous direct memory access.
     *
     *                  This reference can be overwritten if anything else modifies memory (!!!).
     *                  As such it MUST be consumed IMMEDIATELY.
     *                  This function is private to prevent unsafe usage by callers.
     * @param memView   The view
     * @param _newLoc   The new location
     * @return          written - the unsafe memory reference
     */
    function unsafeCopyTo(bytes29 memView, uint256 _newLoc) private view returns (bytes29 written) {
        require(notNull(memView), "copyTo: Null pointer deref");
        require(isValid(memView), "copyTo: Invalid pointer deref");
        uint256 _len = len(memView);
        uint256 _oldLoc = loc(memView);

        uint256 ptr;
        bool res;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            ptr := mload(0x40)
            // revert if we're writing in occupied memory
            if gt(ptr, _newLoc) {
                revert(0x60, 0x20) // empty revert message
            }

            // use the identity precompile (0x04) to copy
            res := staticcall(gas(), 0x04, _oldLoc, _len, _newLoc, _len)
        }
        require(res, "identity: out of gas");

        written = unsafeBuildUnchecked(typeOf(memView), _newLoc, _len);
    }

    /**
     * @notice          Copies the referenced memory to a new loc in memory,
     *                  returning a `bytes` pointing to the new memory.
     * @dev             Shortcuts if the pointers are identical, otherwise compares type and digest.
     * @param memView   The view
     * @return          ret - The view pointing to the new memory
     */
    function clone(bytes29 memView) internal view returns (bytes memory ret) {
        uint256 ptr;
        uint256 _len = len(memView);
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            ptr := mload(0x40) // load unused memory pointer
            ret := ptr
        }
        unchecked {
            unsafeCopyTo(memView, ptr + 0x20);
        }
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            mstore(0x40, add(add(ptr, _len), 0x20)) // write new unused pointer
            mstore(ptr, _len) // write len of new array (in bytes)
        }
    }

    /**
     * @notice          Join the views in memory, return an unsafe reference to the memory.
     * @dev             Super Dangerous direct memory access.
     *
     *                  This reference can be overwritten if anything else modifies memory (!!!).
     *                  As such it MUST be consumed IMMEDIATELY.
     *                  This function is private to prevent unsafe usage by callers.
     * @param memViews  The views
     * @return          unsafeView - The conjoined view pointing to the new memory
     */
    function unsafeJoin(bytes29[] memory memViews, uint256 _location)
        private
        view
        returns (bytes29 unsafeView)
    {
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            let ptr := mload(0x40)
            // revert if we're writing in occupied memory
            if gt(ptr, _location) {
                revert(0x60, 0x20) // empty revert message
            }
        }

        uint256 _offset = 0;
        for (uint256 i = 0; i < memViews.length; i++) {
            bytes29 memView = memViews[i];
            unchecked {
                unsafeCopyTo(memView, _location + _offset);
                _offset += len(memView);
            }
        }
        unsafeView = unsafeBuildUnchecked(0, _location, _offset);
    }

    /**
     * @notice          Produce the keccak256 digest of the concatenated contents of multiple views.
     * @param memViews  The views
     * @return          bytes32 - The keccak256 digest
     */
    function joinKeccak(bytes29[] memory memViews) internal view returns (bytes32) {
        uint256 ptr;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            ptr := mload(0x40) // load unused memory pointer
        }
        return keccak(unsafeJoin(memViews, ptr));
    }

    /**
     * @notice          Produce the sha256 digest of the concatenated contents of multiple views.
     * @param memViews  The views
     * @return          bytes32 - The sha256 digest
     */
    function joinSha2(bytes29[] memory memViews) internal view returns (bytes32) {
        uint256 ptr;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            ptr := mload(0x40) // load unused memory pointer
        }
        return sha2(unsafeJoin(memViews, ptr));
    }

    /**
     * @notice          copies all views, joins them into a new bytearray.
     * @param memViews  The views
     * @return          ret - The new byte array
     */
    function join(bytes29[] memory memViews) internal view returns (bytes memory ret) {
        uint256 ptr;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            ptr := mload(0x40) // load unused memory pointer
        }

        bytes29 _newView;
        unchecked {
            _newView = unsafeJoin(memViews, ptr + 0x20);
        }
        uint256 _written = len(_newView);
        uint256 _footprint = footprint(_newView);

        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // store the length
            mstore(ptr, _written)
            // new pointer is old + 0x20 + the footprint of the body
            mstore(0x40, add(add(ptr, _footprint), 0x20))
            ret := ptr
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
// ══════════════════════════════ LIBRARY IMPORTS ══════════════════════════════
import { AgentSet } from "../libs/AgentSet.sol";
import { Auth } from "../libs/Auth.sol";
import { Signature } from "../libs/ByteString.sol";
// ═════════════════════════════ INTERNAL IMPORTS ══════════════════════════════
import { AgentRegistryEvents } from "../events/AgentRegistryEvents.sol";
import { IAgentRegistry } from "../interfaces/IAgentRegistry.sol";
// ═════════════════════════════ EXTERNAL IMPORTS ══════════════════════════════
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @notice Registry used for verifying signatures of any of the Agents.
 * Both Guards and Notaries could be stored in a single AgentRegistry.
 * An option to ignore certain agents is available, see {_isIgnoredAgent}.
 * @dev Following assumptions are implied:
 * 1. Guard is active on all domains at once.
 * 2. Notary is active on a single domain.
 * 3. Same account can't be both a Guard and a Notary.
 */
abstract contract AgentRegistry is AgentRegistryEvents, IAgentRegistry {
    using AgentSet for AgentSet.DomainAddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STORAGE                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Refers to the current epoch. Whenever a full agent reset is required
     * by BondingManager, a new epoch starts. This saves us from iterating over all
     * agents and deleting them, which could be gas consuming.
     * @dev Variable is private as the child contracts are not supposed to modify it.
     * Use _currentEpoch() getter if needed.
     */
    uint256 private epoch;

    /**
     * @notice All active domains, i.e. domains having at least one active Notary.
     * Note: guards are stored with domain = 0, but we don't want to mix
     * "domains with at least one active Notary" and "zero domain with at least one active Guard",
     * so we are NOT storing domain == 0 in this set.
     */
    // (epoch => [domains with at least one active Notary])
    mapping(uint256 => EnumerableSet.UintSet) internal domains;

    /**
     * @notice DomainAddressSet implies that every agent is stored as a (domain, account) tuple.
     * Guard is active on all domains => Guards are stored as (domain = 0, account).
     * Notary is active on one (non-zero) domain => Notaries are stored as (domain > 0, account).
     */
    // (epoch => [set of active agents for all domains])
    mapping(uint256 => AgentSet.DomainAddressSet) internal agents;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              MODIFIERS                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Ensures that there is at least one active Notary for the given domain.
     */
    modifier haveActiveNotary(uint32 _domain) {
        require(_isActiveDomain(_domain), "No active notaries");
        _;
    }

    /**
     * @notice Ensures that there is at least one active Guard.
     */
    modifier haveActiveGuard() {
        // Guards are stored with `_domain == 0`
        require(amountAgents({ _domain: 0 }) != 0, "No active guards");
        _;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            EXTERNAL VIEWS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @inheritdoc IAgentRegistry
    function allAgents(uint32 _domain) external view returns (address[] memory) {
        return agents[_currentEpoch()].values(_domain);
    }

    /// @inheritdoc IAgentRegistry
    function allDomains() external view returns (uint32[] memory domains_) {
        uint256[] memory values = domains[_currentEpoch()].values();
        // Use assembly to perform uint256 -> uint32 downcast
        // See OZ's EnumerableSet.values()
        // solhint-disable-next-line no-inline-assembly
        assembly {
            domains_ := values
        }
    }

    /// @inheritdoc IAgentRegistry
    function isActiveAgent(address _account) external view returns (bool isActive, uint32 domain) {
        return _isActiveAgent(_account);
    }

    /// @inheritdoc IAgentRegistry
    function isActiveAgent(uint32 _domain, address _account) external view returns (bool) {
        return _isActiveAgent(_domain, _account);
    }

    /// @inheritdoc IAgentRegistry
    function isActiveDomain(uint32 _domain) external view returns (bool) {
        return _isActiveDomain(_domain);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             PUBLIC VIEWS                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @inheritdoc IAgentRegistry
    function amountAgents(uint32 _domain) public view returns (uint256) {
        return agents[_currentEpoch()].length(_domain);
    }

    /// @inheritdoc IAgentRegistry
    function amountDomains() public view returns (uint256) {
        return domains[_currentEpoch()].length();
    }

    /// @inheritdoc IAgentRegistry
    function getAgent(uint32 _domain, uint256 _agentIndex) public view returns (address) {
        return agents[_currentEpoch()].at(_domain, _agentIndex);
    }

    /// @inheritdoc IAgentRegistry
    function getDomain(uint256 _domainIndex) public view returns (uint32) {
        return uint32(domains[_currentEpoch()].at(_domainIndex));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          INTERNAL FUNCTIONS                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @dev Tries to add an agent to the domain. If added, emits a corresponding event,
     * updates the list of active domains if necessary, and triggers a corresponding hook.
     * Note: use _domain == 0 to add a Guard, _domain > 0 to add a Notary.
     */
    function _addAgent(uint32 _domain, address _account) internal returns (bool wasAdded) {
        // Some Registries may want to ignore certain agents
        if (_isIgnoredAgent(_domain, _account)) return false;
        // Do the storage read just once
        uint256 _epoch = _currentEpoch();
        // Add to the list of agents for the domain in the current epoch
        wasAdded = agents[_epoch].add(_domain, _account);
        if (wasAdded) {
            emit AgentAdded(_domain, _account);
            // Consider adding domain to the list of "active domains" only if a Notary was added
            if (_domain != 0) {
                // We can skip the "already exists" check here, as EnumerableSet.add() does that
                if (domains[_epoch].add(_domain)) {
                    // Emit the event if domain was added to the list of active domains
                    emit DomainActivated(_domain);
                }
            }
            // Trigger the hook after the work is done
            _afterAgentAdded(_domain, _account);
        }
    }

    /**
     * @dev Tries to remove an agent from the domain. If removed, emits a corresponding event,
     * updates the list of active domains if necessary, and triggers a corresponding hook.
     * Note: use _domain == 0 to remove a Guard, _domain > 0 to remove a Notary.
     */
    function _removeAgent(uint32 _domain, address _account) internal returns (bool wasRemoved) {
        // Some Registries may want to ignore certain agents
        if (_isIgnoredAgent(_domain, _account)) return false;
        // Do the storage read just once
        uint256 _epoch = _currentEpoch();
        // Remove from the list of agents for the domain in the current epoch
        wasRemoved = agents[_epoch].remove(_domain, _account);
        if (wasRemoved) {
            emit AgentRemoved(_domain, _account);
            // Consider removing domain to the list of "active domains" only if a Notary was removed
            if (_domain != 0 && amountAgents(_domain) == 0) {
                // Remove domain for the "active list", if that was the last agent
                domains[_epoch].remove(_domain);
                emit DomainDeactivated(_domain);
            }
            // Trigger the hook after the work is done
            _afterAgentRemoved(_domain, _account);
        }
    }

    /**
     * @dev Tries to slash an agent active on the domain by removing it.
     * If slashed, emits a corresponding event, and triggers a corresponding hook if verified locally.
     * Hook will not be triggered, if agent was slashed elsewhere.
     * Note: use _domain == 0 to slash a Guard, _domain > 0 to slash a Notary.
     */
    function _slashAgent(
        uint32 _domain,
        address _account,
        bool _verified
    ) internal returns (bool wasSlashed) {
        wasSlashed = _removeAgent(_domain, _account);
        if (wasSlashed) {
            emit AgentSlashed(_domain, _account);
            if (_verified) _afterAgentSlashed(_domain, _account);
        }
    }

    /**
     * @dev Removes all active agents from all domains.
     * Note: iterating manually over all agents in order to delete them all is super inefficient.
     * Deleting sets (which contain mappings inside) is literally not possible.
     * So we're switching to fresh sets instead.
     */
    function _resetAgents() internal {
        ++epoch;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                HOOKS                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    // solhint-disable no-empty-blocks

    /// @dev Hook that is always called after a new agent was added for the domain.
    function _afterAgentAdded(uint32 _domain, address _account) internal virtual {}

    /// @dev Hook that is always called after an existing agent was removed from the domain.
    function _afterAgentRemoved(uint32 _domain, address _account) internal virtual {}

    /// @dev Hook that is called after an existing agent was slashed,
    /// when verification of an invalid agent statement was done in this contract.
    function _afterAgentSlashed(uint32 _domain, address _account) internal virtual {}

    // solhint-enable no-empty-blocks

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            INTERNAL VIEWS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @dev Returns current epoch, i.e. an index that is used to determine the currently
     * used sets for active agents and domains.
     */
    function _currentEpoch() internal view returns (uint256) {
        return epoch;
    }

    /**
     * @dev Recovers a signer from digest and signature, and checks if they are
     * active on the given domain.
     * Note: domain == 0 refers to a Guard, while _domain > 0 refers to a Notary.
     */
    function _checkAgentAuth(
        uint32 _domain,
        bytes32 _digest,
        Signature _signature
    ) internal view returns (address agent) {
        agent = Auth.recoverSigner(_digest, _signature);
        require(_isActiveAgent(_domain, agent), "Signer is not authorized");
    }

    /**
     * @dev Checks if agent is active on any of the domains.
     * Note: this returns if agent is active, and the domain where they're active.
     */
    function _isActiveAgent(address _account) internal view returns (bool, uint32) {
        // Check the list of global agents in the current epoch
        return agents[_currentEpoch()].contains(_account);
    }

    /**
     * @dev Checks if agent is active on the given domain.
     * Note: domain == 0 refers to a Guard, while _domain > 0 refers to a Notary.
     */
    function _isActiveAgent(uint32 _domain, address _account) internal view returns (bool) {
        // Check the list of the domain's agents in the current epoch
        return agents[_currentEpoch()].contains(_domain, _account);
    }

    /**
     * @dev Checks if there is at least one active Notary for the given domain.
     * Note: will return false for `_domain == 0`, even if there are active Guards.
     */
    function _isActiveDomain(uint32 _domain) internal view returns (bool) {
        return domains[_currentEpoch()].contains(_domain);
    }

    /**
     * @dev Child contracts should override this function to prevent
     * certain agents from being added and removed.
     * For instance, Origin might want to ignore all agents from the local domain.
     * Note: It is assumed that no agent can change its "ignored" status in any AgentRegistry.
     * In other words, do not use any values that might change over time, when implementing.
     * Otherwise, unexpected behavior might be expected. For instance, if an agent was added,
     * and then it became "ignored", it would be not possible to remove such agent.
     * Note: domain == 0 refers to a Guard, while _domain > 0 refers to a Notary.
     */
    function _isIgnoredAgent(uint32 _domain, address _account) internal view virtual returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
// ══════════════════════════════ LIBRARY IMPORTS ══════════════════════════════
import { AgentInfo, SystemEntity } from "../libs/Structures.sol";
// ═════════════════════════════ INTERNAL IMPORTS ══════════════════════════════
import { DomainContext } from "../context/DomainContext.sol";
import { ISystemContract } from "../interfaces/ISystemContract.sol";
import { InterfaceSystemRouter } from "../interfaces/InterfaceSystemRouter.sol";
// ═════════════════════════════ EXTERNAL IMPORTS ══════════════════════════════
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @notice Shared utilities between Synapse System Contracts: Origin, Destination, etc.
 */
abstract contract SystemContract is DomainContext, OwnableUpgradeable, ISystemContract {
    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              CONSTANTS                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    // domain of the Synapse Chain
    // For MVP this is Optimism chainId
    // TODO: replace the placeholder with actual value
    uint32 public constant SYNAPSE_DOMAIN = 10;

    uint256 internal constant ORIGIN = 1 << uint8(SystemEntity.Origin);
    uint256 internal constant DESTINATION = 1 << uint8(SystemEntity.Destination);
    uint256 internal constant BONDING_MANAGER = 1 << uint8(SystemEntity.BondingManager);

    // TODO: reevaluate optimistic period for staking/unstaking bonds
    uint32 internal constant BONDING_OPTIMISTIC_PERIOD = 1 days;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STORAGE                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    InterfaceSystemRouter public systemRouter;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              MODIFIERS                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @dev Modifier for functions that are supposed to be called only from
     * System Contracts on all chains (either local or remote).
     * Note: any function protected by this modifier should have last three params:
     * - uint32 _callOrigin
     * - SystemEntity _systemCaller
     * - uint256 _rootSubmittedAt
     * Make sure to check domain/caller, if a function should be only called
     * from a given domain / by a given caller.
     * Make sure to check that a needed amount of time has passed since
     * root submission for the cross-chain calls.
     */
    modifier onlySystemRouter() {
        _assertSystemRouter();
        _;
    }

    /**
     * @dev Modifier for functions that are supposed to be called only from
     * System Contracts on Synapse chain.
     * Note: has to be used alongside with `onlySystemRouter`
     * See `onlySystemRouter` for details about the functions protected by such modifiers.
     */
    modifier onlySynapseChain(uint32 _callOrigin) {
        _assertSynapseChain(_callOrigin);
        _;
    }

    /**
     * @dev Modifier for functions that are supposed to be called only from
     * a set of System Contracts on any chain.
     * Note: has to be used alongside with `onlySystemRouter`
     * See `onlySystemRouter` for details about the functions protected by such modifiers.
     * Note: check constants section for existing mask constants
     * E.g. to restrict the set of callers to three allowed system callers:
     *  onlyCallers(MASK_0 | MASK_1 | MASK_2, _systemCaller)
     */
    modifier onlyCallers(uint256 _allowedMask, SystemEntity _systemCaller) {
        _assertEntityAllowed(_allowedMask, _systemCaller);
        _;
    }

    /**
     * @dev Modifier for functions that are supposed to be called only from
     * BondingManager on their local chain.
     * Note: has to be used alongside with `onlySystemRouter`
     * See `onlySystemRouter` for details about the functions protected by such modifiers.
     */
    modifier onlyLocalBondingManager(uint32 _callOrigin, SystemEntity _caller) {
        _assertLocalDomain(_callOrigin);
        _assertEntityAllowed(BONDING_MANAGER, _caller);
        _;
    }

    /**
     * @dev Modifier for functions that are supposed to be called only from
     * BondingManager on Synapse Chain.
     * Note: has to be used alongside with `onlySystemRouter`
     * See `onlySystemRouter` for details about the functions protected by such modifiers.
     */
    modifier onlySynapseChainBondingManager(uint32 _callOrigin, SystemEntity _systemCaller) {
        _assertSynapseChain(_callOrigin);
        _assertEntityAllowed(BONDING_MANAGER, _systemCaller);
        _;
    }

    /**
     * @dev Modifier for functions that are supposed to be called only from
     * System Contracts on remote chain with a defined minimum optimistic period.
     * Note: has to be used alongside with `onlySystemRouter`
     * See `onlySystemRouter` for details about the functions protected by such modifiers.
     * Note: message could be sent with a period lower than that, but will be executed
     * only when `_optimisticSeconds` have passed.
     * Note: _optimisticSeconds=0 will allow calls from a local chain as well
     */
    modifier onlyOptimisticPeriodOver(uint256 _rootSubmittedAt, uint256 _optimisticSeconds) {
        _assertOptimisticPeriodOver(_rootSubmittedAt, _optimisticSeconds);
        _;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             INITIALIZER                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    // solhint-disable-next-line func-name-mixedcase
    function __SystemContract_initialize() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              OWNER ONLY                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    // solhint-disable-next-line ordering
    function setSystemRouter(InterfaceSystemRouter _systemRouter) external onlyOwner {
        systemRouter = _systemRouter;
    }

    /**
     * @dev Should be impossible to renounce ownership;
     * we override OpenZeppelin OwnableUpgradeable's
     * implementation of renounceOwnership to make it a no-op
     */
    function renounceOwnership() public override onlyOwner {} //solhint-disable-line no-empty-blocks

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        SYSTEM CALL SHORTCUTS                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Perform a System Call to a BondingManager on a given domain
    /// with the given optimistic period and data.
    function _callBondingManager(
        uint32 _domain,
        uint32 _optimisticSeconds,
        bytes memory _data
    ) internal {
        systemRouter.systemCall({
            _destination: _domain,
            _optimisticSeconds: _optimisticSeconds,
            _recipient: SystemEntity.BondingManager,
            _data: _data
        });
    }

    /// @dev Perform a System Call to a local BondingManager with the given `_data`.
    function _callLocalBondingManager(bytes memory _data) internal {
        _callBondingManager(localDomain, 0, _data);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                 INTERNAL VIEWS: SECURITY ASSERTIONS                  ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _onSynapseChain() internal view returns (bool) {
        return localDomain == SYNAPSE_DOMAIN;
    }

    function _assertSystemRouter() internal view {
        require(msg.sender == address(systemRouter), "!systemRouter");
    }

    function _assertOptimisticPeriodOver(uint256 _rootSubmittedAt, uint256 _optimisticSeconds)
        internal
        view
    {
        require(block.timestamp >= _rootSubmittedAt + _optimisticSeconds, "!optimisticPeriod");
    }

    function _assertEntityAllowed(uint256 _allowedMask, SystemEntity _caller) internal pure {
        require(_entityAllowed(_allowedMask, _caller), "!allowedCaller");
    }

    function _assertSynapseChain(uint32 _domain) internal pure {
        require(_domain == SYNAPSE_DOMAIN, "!synapseDomain");
    }

    /**
     * @notice Checks if a given entity is allowed to call a function using a _systemMask
     * @param _systemMask a mask of allowed entities
     * @param _entity a system entity to check
     * @return true if _entity is allowed to call a function
     *
     * @dev this function works by converting the enum value to a non-zero bit mask
     * we then use a bitwise AND operation to check if permission bits allow the entity
     * to perform this operation, more details can be found here:
     * https://en.wikipedia.org/wiki/Bitwise_operation#AND
     */
    function _entityAllowed(uint256 _systemMask, SystemEntity _entity)
        internal
        pure
        returns (bool)
    {
        return _systemMask & _getSystemMask(_entity) != 0;
    }

    /**
     * @notice Returns a mask for a given system entity
     * @param _entity System entity
     * @return a non-zero mask for a given system entity
     *
     * Converts an enum value into a non-zero bit mask used for a bitwise AND check
     * E.g. for Origin (0) returns 1, for Destination (1) returns 2
     */
    function _getSystemMask(SystemEntity _entity) internal pure returns (uint256) {
        return 1 << uint8(_entity);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      INTERNAL VIEWS: AGENT DATA                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Convenience shortcut for creating data for the slashAgent system call.
    function _dataSlashAgent(uint32 _domain, address _agent) internal pure returns (bytes memory) {
        return _dataSlashAgent(AgentInfo(_domain, _agent, false));
    }

    /**
     * @notice Constructs data for the system call to slash a given agent.
     */
    function _dataSlashAgent(AgentInfo memory _info) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                ISystemContract.slashAgent.selector,
                0, // rootSubmittedAt
                0, // callOrigin
                0, // systemCaller
                _info
            );
    }

    /// @dev Constructs data for the system call to sync the given agent.
    function _dataSyncAgent(AgentInfo memory _info) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                ISystemContract.syncAgent.selector,
                0, // rootSubmittedAt
                0, // callOrigin
                0, // systemCaller
                _info
            );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ByteString } from "./ByteString.sol";
import { ATTESTATION_LENGTH } from "./Constants.sol";
import { TypedMemView } from "./TypedMemView.sol";

/// @dev Attestation is a memory view over a formatted attestation payload.
type Attestation is bytes29;
/// @dev Attach library functions to Attestation
using {
    AttestationLib.unwrap,
    AttestationLib.equalToSummit,
    AttestationLib.toDestinationAttestation,
    AttestationLib.hash,
    AttestationLib.root,
    AttestationLib.height,
    AttestationLib.nonce,
    AttestationLib.blockNumber,
    AttestationLib.timestamp
} for Attestation global;

/// @dev Struct representing Attestation, as it is stored in the Summit contract.
struct SummitAttestation {
    bytes32 root;
    uint8 height;
    uint40 blockNumber;
    uint40 timestamp;
}
/// @dev Attach library functions to SummitAttestation
using { AttestationLib.formatSummitAttestation } for SummitAttestation global;

/// @dev Struct representing Attestation, as it is stored in the Destination contract.
/// mapping (bytes32 root => DestinationAttestation) is supposed to be used
struct DestinationAttestation {
    address notary;
    uint8 height;
    uint32 nonce;
    uint40 destTimestamp;
    // 16 bits left for tight packing
}
/// @dev Attach library functions to DestinationAttestation
using { AttestationLib.isEmpty } for DestinationAttestation global;

library AttestationLib {
    using ByteString for bytes;
    using TypedMemView for bytes29;

    /**
     * @dev Attestation structure represents the "Snapshot Merkle Tree" created from
     * every Notary snapshot accepted by the Summit contract. Attestation includes
     * the root and height of "Snapshot Merkle Tree", as well as additional metadata.
     *
     * Steps for creation of "Snapshot Merkle Tree":
     * 1. The list of hashes is composed for states in the Notary snapshot.
     * 2. The list is padded with zero values until its length is a power of two.
     * 3. Values from the lists are used as leafs and the merkle tree is constructed.
     *
     * Similar to Origin, every derived Notary's "Snapshot Merkle Root" is saved in Summit contract.
     * The main difference is that Origin contract itself is keeping track of an incremental merkle tree,
     * by inserting the hash of the dispatched message and calculating the new "Origin Merkle Root".
     * While Summit relies on Guards and Notaries to provide snapshot data, which is used to calculate the
     * "Snapshot Merkle Root".
     *
     * Origin's State is "state of Origin Merkle Tree after N-th message was dispatched".
     * Summit's Attestation is "data for the N-th accepted Notary Snapshot".
     *
     * Attestation is considered "valid" in Summit contract, if it matches the N-th (nonce)
     * snapshot submitted by Notaries.
     * Attestation is considered "valid" in Origin contract, if its underlying Snapshot is "valid".
     *
     * This means that a snapshot could be "valid" in Summit contract and "invalid" in Origin, if the underlying
     * snapshot is invalid (i.e. one of the states in the list is invalid).
     * The opposite could also be true. If a perfectly valid snapshot was never submitted to Summit, its attestation
     * would be valid in Origin, but invalid in Summit (it was never accepted, so the metadata would be incorrect).
     *
     * Attestation is considered "globally valid", if it is valid in the Summit and all the Origin contracts.
     *
     * @dev Memory layout of Attestation fields
     * [000 .. 032): root           bytes32 32 bytes    Root for "Snapshot Merkle Tree" created from a Notary snapshot
     * [032 .. 033): height         uint8    1 byte     Height of "Snapshot Merkle Tree" created from a Notary snapshot
     * [033 .. 037): nonce          uint32   4 bytes    Total amount of all accepted Notary snapshots
     * [037 .. 042): blockNumber    uint40   5 bytes    Block when this Notary snapshot was accepted in Summit
     * [042 .. 047): timestamp      uint40   5 bytes    Time when this Notary snapshot was accepted in Summit
     *
     * The variables below are not supposed to be used outside of the library directly.
     */

    uint256 private constant OFFSET_ROOT = 0;
    uint256 private constant OFFSET_DEPTH = 32;
    uint256 private constant OFFSET_NONCE = 33;
    uint256 private constant OFFSET_BLOCK_NUMBER = 37;
    uint256 private constant OFFSET_TIMESTAMP = 42;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             ATTESTATION                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Returns a formatted Attestation payload with provided fields.
     * @param _root         Snapshot merkle tree's root
     * @param _height       Snapshot merkle tree's height
     * @param _nonce        Attestation Nonce
     * @param _blockNumber  Block number when attestation was created in Summit
     * @param _timestamp    Block timestamp when attestation was created in Summit
     * @return Formatted attestation
     **/
    function formatAttestation(
        bytes32 _root,
        uint8 _height,
        uint32 _nonce,
        uint40 _blockNumber,
        uint40 _timestamp
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(_root, _height, _nonce, _blockNumber, _timestamp);
    }

    /**
     * @notice Returns an Attestation view over the given payload.
     * @dev Will revert if the payload is not an attestation.
     */
    function castToAttestation(bytes memory _payload) internal pure returns (Attestation) {
        return castToAttestation(_payload.castToRawBytes());
    }

    /**
     * @notice Casts a memory view to an Attestation view.
     * @dev Will revert if the memory view is not over an attestation.
     */
    function castToAttestation(bytes29 _view) internal pure returns (Attestation) {
        require(isAttestation(_view), "Not an attestation");
        return Attestation.wrap(_view);
    }

    /// @notice Checks that a payload is a formatted Attestation.
    function isAttestation(bytes29 _view) internal pure returns (bool) {
        return _view.len() == ATTESTATION_LENGTH;
    }

    /// @notice Convenience shortcut for unwrapping a view.
    function unwrap(Attestation _att) internal pure returns (bytes29) {
        return Attestation.unwrap(_att);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          SUMMIT ATTESTATION                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Returns a formatted Attestation payload with provided fields.
     * @param _summitAtt    Attestation struct as it stored in Summit contract
     * @param _nonce        Attestation nonce
     * @return Formatted attestation
     */
    function formatSummitAttestation(SummitAttestation memory _summitAtt, uint32 _nonce)
        internal
        pure
        returns (bytes memory)
    {
        return
            formatAttestation({
                _root: _summitAtt.root,
                _height: _summitAtt.height,
                _nonce: _nonce,
                _blockNumber: _summitAtt.blockNumber,
                _timestamp: _summitAtt.timestamp
            });
    }

    /// @notice Checks that an Attestation and its Summit representation are equal.
    function equalToSummit(Attestation _att, SummitAttestation memory _summitAtt)
        internal
        pure
        returns (bool)
    {
        return
            _att.root() == _summitAtt.root &&
            _att.height() == _summitAtt.height &&
            _att.blockNumber() == _summitAtt.blockNumber &&
            _att.timestamp() == _summitAtt.timestamp;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       DESTINATION ATTESTATION                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function toDestinationAttestation(Attestation _att, address _notary)
        internal
        view
        returns (DestinationAttestation memory attestation)
    {
        attestation.notary = _notary;
        attestation.height = _att.height();
        attestation.nonce = _att.nonce();
        // We need to store the timestamp when attestation was submitted to Destination
        attestation.destTimestamp = uint40(block.timestamp);
    }

    function isEmpty(DestinationAttestation memory _destAtt) internal pure returns (bool) {
        return _destAtt.notary == address(0);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         ATTESTATION HASHING                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Returns the hash of an Attestation, that could be later signed by a Notary.
    function hash(Attestation _att) internal pure returns (bytes32) {
        // Get the underlying memory view
        bytes29 _view = _att.unwrap();
        // TODO: include Attestation-unique salt in the hash
        return _view.keccak();
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         ATTESTATION SLICING                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Returns root of the Snapshot merkle tree created in the Summit contract.
    function root(Attestation _att) internal pure returns (bytes32) {
        bytes29 _view = _att.unwrap();
        return _view.index({ _index: OFFSET_ROOT, _bytes: 32 });
    }

    /// @notice Returns height of the Snapshot merkle tree created in the Summit contract.
    function height(Attestation _att) internal pure returns (uint8) {
        bytes29 _view = _att.unwrap();
        return uint8(_view.indexUint({ _index: OFFSET_DEPTH, _bytes: 1 }));
    }

    /// @notice Returns nonce of Summit contract at the time, when attestation was created.
    function nonce(Attestation _att) internal pure returns (uint32) {
        bytes29 _view = _att.unwrap();
        return uint32(_view.indexUint({ _index: OFFSET_NONCE, _bytes: 4 }));
    }

    /// @notice Returns a block number when attestation was created in Summit.
    function blockNumber(Attestation _att) internal pure returns (uint40) {
        bytes29 _view = _att.unwrap();
        return uint40(_view.indexUint({ _index: OFFSET_BLOCK_NUMBER, _bytes: 5 }));
    }

    /// @notice Returns a block timestamp when attestation was created in Summit.
    /// @dev This is the timestamp according to the Synapse Chain.
    function timestamp(Attestation _att) internal pure returns (uint40) {
        bytes29 _view = _att.unwrap();
        return uint40(_view.indexUint({ _index: OFFSET_TIMESTAMP, _bytes: 5 }));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library MerkleList {
    /**
     * @notice Calculates merkle root for a list of given leafs.
     * Merkle Tree is constructed by padding the list with ZERO values for leafs
     * until list length is a power of two.
     * Merkle Root is calculated for the constructed tree, and recorded in leafs[0].
     * Note: `leafs` values are overwritten in the process to avoid excessive memory allocations.
     * Caller is expected not to allocate memory for the leafs list, and only use leafs[0] value,
     * which is guaranteed to contain the calculated merkle root.
     * @param hashes    List of leafs for the merkle tree (to be overwritten)
     */
    function calculateRoot(bytes32[] memory hashes) internal pure {
        // Use ZERO as value for "extra leafs".
        // Later this will be tracking the value of a "zero node" on the current tree level.
        bytes32 zeroHash = bytes32(0);
        uint256 levelLength = hashes.length;
        // We will be iterating from the "leafs level" up to the "root level" of the Merkle Tree.
        // For every level we will only record "significant values", i.e. not equal to `zeroHash`
        // Repeat until we only have a single hash: this would be the root of the tree
        while (levelLength > 1) {
            // Let H be the height of the "current level". H = 0 for the "root level".
            // Invariant: hashes[0 .. length) are "current level" tree nodes
            // Invariant: zeroHash is the value for nodes with indexes [length .. 2**H)

            // Iterate over every pair of (leftChild, rightChild) on the current level
            for (uint256 leftIndex = 0; leftIndex < levelLength; leftIndex += 2) {
                uint256 rightIndex = leftIndex + 1;
                bytes32 leftChild = hashes[leftIndex];
                // Note: rightChild might be zeroHash
                bytes32 rightChild = rightIndex < levelLength ? hashes[rightIndex] : zeroHash;
                // Record the parent hash in the same array. This will not affect
                // further calculations for the same level: (leftIndex >> 1) <= leftIndex.
                hashes[leftIndex >> 1] = keccak256(bytes.concat(leftChild, rightChild));
            }
            // Update value for the "zero hash"
            zeroHash = keccak256(bytes.concat(zeroHash, zeroHash));
            // Set length for the "parent level"
            levelLength = (levelLength + 1) >> 1;
        }
    }

    function calculateProof(
        bytes32[] memory hashes,
        uint256 index,
        bytes32[] memory proof
    ) internal pure {
        // proof[0] is already set up
        uint256 height = 0;

        // Use ZERO as value for "extra leafs".
        // Later this will be tracking the value of a "zero node" on the current tree level.
        bytes32 zeroHash = bytes32(0);
        uint256 levelLength = hashes.length;

        // We will be iterating from the "leafs level" up to the "root level" of the Merkle Tree.
        // For every level we will only record "significant values", i.e. not equal to `zeroHash`
        // Repeat until we only have a single hash: this would be the root of the tree
        while (levelLength > 1) {
            // Use sibling for the merkle proof
            proof[++height] = (index ^ 1 < levelLength) ? hashes[index ^ 1] : zeroHash;

            // Let H be the height of the "current level". H = 0 for the "root level".
            // Invariant: hashes[0 .. length) are "current level" tree nodes
            // Invariant: zeroHash is the value for nodes with indexes [length .. 2**H)

            // Iterate over every pair of (leftChild, rightChild) on the current level
            for (uint256 leftIndex = 0; leftIndex < levelLength; leftIndex += 2) {
                uint256 rightIndex = leftIndex + 1;
                bytes32 leftChild = hashes[leftIndex];
                // Note: rightChild might be zeroHash
                bytes32 rightChild = rightIndex < levelLength ? hashes[rightIndex] : zeroHash;
                // Record the parent hash in the same array. This will not affect
                // further calculations for the same level: (leftIndex >> 1) <= leftIndex.
                hashes[leftIndex >> 1] = keccak256(bytes.concat(leftChild, rightChild));
            }
            // Update value for the "zero hash"
            zeroHash = keccak256(bytes.concat(zeroHash, zeroHash));
            // Set length for the "parent level"
            levelLength = (levelLength + 1) >> 1;
            // Traverse to parent node
            index >>= 1;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { SummitAttestation } from "./Attestation.sol";
import { ByteString } from "./ByteString.sol";
import { SNAPSHOT_MAX_STATES, STATE_LENGTH } from "./Constants.sol";
import { MerkleList } from "./MerkleList.sol";
import { State, StateLib } from "./State.sol";
import { TypedMemView } from "./TypedMemView.sol";

/// @dev Snapshot is a memory view over a formatted snapshot payload: a list of states.
type Snapshot is bytes29;
/// @dev Attach library functions to Snapshot
using {
    SnapshotLib.unwrap,
    SnapshotLib.hash,
    SnapshotLib.state,
    SnapshotLib.statesAmount,
    SnapshotLib.height,
    SnapshotLib.root,
    SnapshotLib.toSummitAttestation
} for Snapshot global;

/// @dev Struct representing Snapshot, as it is stored in the Summit contract.
/// Summit contract is supposed to store states. Snapshot is a list of states,
/// so we are storing a list of references to already stored states.
struct SummitSnapshot {
    // TODO: compress this - indexes might as well be uint32/uint64
    uint256[] statePtrs;
}
/// @dev Attach library functions to SummitSnapshot
using { SnapshotLib.getStatesAmount, SnapshotLib.getStatePtr } for SummitSnapshot global;

library SnapshotLib {
    using ByteString for bytes;
    using StateLib for bytes29;
    using TypedMemView for bytes29;

    /**
     * @dev Snapshot structure represents the state of multiple Origin contracts deployed on multiple chains.
     * In short, snapshot is a list of "State" structs. See State.sol for details about the "State" structs.
     *
     * Snapshot is considered "valid" in Origin, if every state referring to that Origin is valid there.
     * Snapshot is considered "globally valid", if it is "valid" in every Origin contract.
     *
     * Both Guards and Notaries are supposed to form snapshots and sign snapshot.hash() to verify its validity.
     * Each Guard should be monitoring a set of Origin contracts chosen as they see fit. They are expected
     * to form snapshots with Origin states for this set of chains, sign and submit them to Summit contract.
     *
     * Notaries are expected to monitor the Summit contract for new snapshots submitted by the Guards.
     * They should be forming their own snapshots using states from snapshots of any of the Guards.
     * The states for the Notary snapshots don't have to come from the same Guard snapshot,
     * or don't even have to be submitted by the same Guard.
     *
     * With their signature, Notary effectively "notarizes" the work that some Guards have done in Summit contract.
     * Notary signature on a snapshot doesn't only verify the validity of the Origins, but also serves as
     * a proof of liveliness for Guards monitoring these Origins.
     *
     * @dev Snapshot memory layout
     * [000 .. 050) states[0]   bytes   50 bytes
     * [050 .. 100) states[1]   bytes   50 bytes
     *      ..
     * [AAA .. BBB) states[N-1] bytes   50 bytes
     */

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               SNAPSHOT                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Returns a formatted Snapshot payload using a list of States.
     * @param _states   Arrays of State-typed memory views over Origin states
     * @return Formatted snapshot
     */
    function formatSnapshot(State[] memory _states) internal view returns (bytes memory) {
        require(_isValidAmount(_states.length), "Invalid states amount");
        // First we unwrap State-typed views into generic views
        uint256 length = _states.length;
        bytes29[] memory views = new bytes29[](length);
        for (uint256 i = 0; i < length; ++i) {
            views[i] = _states[i].unwrap();
        }
        // Finally, we join them in a single payload. This avoids doing unnecessary copies in the process.
        return TypedMemView.join(views);
    }

    /**
     * @notice Returns a Snapshot view over for the given payload.
     * @dev Will revert if the payload is not a snapshot payload.
     */
    function castToSnapshot(bytes memory _payload) internal pure returns (Snapshot) {
        return castToSnapshot(_payload.castToRawBytes());
    }

    /**
     * @notice Casts a memory view to a Snapshot view.
     * @dev Will revert if the memory view is not over a snapshot payload.
     */
    function castToSnapshot(bytes29 _view) internal pure returns (Snapshot) {
        require(isSnapshot(_view), "Not a snapshot");
        return Snapshot.wrap(_view);
    }

    /**
     * @notice Checks that a payload is a formatted Snapshot.
     */
    function isSnapshot(bytes29 _view) internal pure returns (bool) {
        // Snapshot needs to have exactly N * STATE_LENGTH bytes length
        // N needs to be in [1 .. SNAPSHOT_MAX_STATES] range
        uint256 length = _view.len();
        uint256 _statesAmount = length / STATE_LENGTH;
        return _statesAmount * STATE_LENGTH == length && _isValidAmount(_statesAmount);
    }

    /// @notice Convenience shortcut for unwrapping a view.
    function unwrap(Snapshot _snapshot) internal pure returns (bytes29) {
        return Snapshot.unwrap(_snapshot);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           SUMMIT SNAPSHOT                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function toSummitSnapshot(uint256[] memory _statePtrs)
        internal
        pure
        returns (SummitSnapshot memory snapshot)
    {
        snapshot.statePtrs = _statePtrs;
    }

    function getStatesAmount(SummitSnapshot memory _snapshot) internal pure returns (uint256) {
        return _snapshot.statePtrs.length;
    }

    function getStatePtr(SummitSnapshot memory _snapshot, uint256 _index)
        internal
        pure
        returns (uint256)
    {
        require(_index < getStatesAmount(_snapshot), "Out of range");
        return _snapshot.statePtrs[_index];
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           SNAPSHOT HASHING                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Returns the hash of a Snapshot, that could be later signed by an Agent.
    function hash(Snapshot _snapshot) internal pure returns (bytes32 hashedSnapshot) {
        // Get the underlying memory view
        bytes29 _view = _snapshot.unwrap();
        // TODO: include Snapshot-unique salt in the hash
        return _view.keccak();
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           SNAPSHOT SLICING                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Returns a state with a given index from the snapshot.
    function state(Snapshot _snapshot, uint256 _stateIndex) internal pure returns (State) {
        bytes29 _view = _snapshot.unwrap();
        uint256 indexFrom = _stateIndex * STATE_LENGTH;
        require(indexFrom < _view.len(), "Out of range");
        return _view.slice({ _index: indexFrom, _len: STATE_LENGTH, newType: 0 }).castToState();
    }

    /// @notice Returns the amount of states in the snapshot.
    function statesAmount(Snapshot _snapshot) internal pure returns (uint256) {
        bytes29 _view = _snapshot.unwrap();
        return _view.len() / STATE_LENGTH;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            SNAPSHOT ROOT                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Returns the height of the extended "Snapshot Merkle Tree":
    /// every "state leaf" is in fact a node with two sub-leafs.
    /// @dev snapshot.height() is the length of the "extended merkle proof" for (root, origin) leaf:
    /// keccak256(metadata) is the first item in the "extended proof" list,
    /// followed by the remainder of the "merkle proof" from the "Snapshot Merkle Tree"
    function height(Snapshot _snapshot) internal pure returns (uint8 treeHeight) {
        // Account for the fact that every "state leaf" is a node with two sub-leafs
        treeHeight = 1;
        uint256 _statesAmount = _snapshot.statesAmount();
        for (uint256 amount = 1; amount < _statesAmount; amount <<= 1) {
            ++treeHeight;
        }
    }

    /// @notice Returns the root for the "Snapshot Merkle Tree" composed of state leafs from the snapshot.
    function root(Snapshot _snapshot) internal pure returns (bytes32) {
        uint256 _statesAmount = _snapshot.statesAmount();
        bytes32[] memory hashes = new bytes32[](_statesAmount);
        for (uint256 i = 0; i < _statesAmount; ++i) {
            // Each State has two sub-leafs, their hash is used as "leaf" in "Snapshot Merkle Tree"
            hashes[i] = _snapshot.state(i).hash();
        }
        MerkleList.calculateRoot(hashes);
        // hashes[0] now stores the value for the Merkle Root of the list
        return hashes[0];
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          SUMMIT ATTESTATION                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Returns an Attestation struct to save in the Summit contract.
    /// Current block number and timestamp are used.
    function toSummitAttestation(Snapshot _snapshot)
        internal
        view
        returns (SummitAttestation memory attestation)
    {
        attestation.root = _snapshot.root();
        attestation.height = _snapshot.height();
        attestation.blockNumber = uint40(block.number);
        attestation.timestamp = uint40(block.timestamp);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          PRIVATE FUNCTIONS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Checks if snapshot's states amount is valid.
    function _isValidAmount(uint256 _statesAmount) internal pure returns (bool) {
        // Need to have at least one state in a snapshot.
        // Also need to have no more than `SNAPSHOT_MAX_STATES` states in a snapshot.
        return _statesAmount > 0 && _statesAmount <= SNAPSHOT_MAX_STATES;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @notice A collection of events emitted by the SnapshotHub contract
abstract contract SnapshotHubEvents {
    /**
     * @notice Emitted when a new Attestation is saved (derived from a Notary snapshot).
     * @param attestation   Raw payload with attestation data
     */
    event AttestationSaved(bytes attestation);

    /**
     * @notice Emitted when a new Origin State is saved from a Guard snapshot.
     * @param state     Raw payload with state data
     */
    event StateSaved(bytes state);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISnapshotHub {
    /**
     * @notice Check that a given attestation is valid: matches the historical attestation
     * derived from an accepted Notary snapshot.
     * @dev Will revert if any of these is true:
     *  - Attestation payload is not properly formatted.
     * @param _attPayload   Raw payload with attestation data
     * @return isValid      Whether the provided attestation is valid
     */
    function isValidAttestation(bytes memory _attPayload) external view returns (bool isValid);

    /**
     * @notice Returns the state with the highest known nonce submitted by a given Agent.
     * @param _origin       Domain of origin chain
     * @param _agent        Agent address
     * @return statePayload Raw payload with agent's latest state for origin
     */
    function getLatestAgentState(uint32 _origin, address _agent)
        external
        view
        returns (bytes memory statePayload);

    /**
     * @notice Returns Guard snapshot for the list of all accepted Guard snapshots.
     * @dev Reverts if snapshot with given index hasn't been accepted yet.
     * @param _index            Snapshot index in the list of all Guard snapshots
     * @return snapshotPayload  Raw payload with Guard snapshot
     */
    function getGuardSnapshot(uint256 _index) external view returns (bytes memory snapshotPayload);

    /**
     * @notice Returns Notary snapshot that was used for creating an attestation with a given nonce.
     * @dev Reverts if attestation with given nonce hasn't been created yet.
     * @param _nonce            Nonce for the attestation
     * @return snapshotPayload  Raw payload with Notary snapshot used for creating the attestation
     */
    function getNotarySnapshot(uint256 _nonce) external view returns (bytes memory snapshotPayload);

    /**
     * @notice Returns Notary snapshot that was used for creating a given attestation.
     * @dev Reverts if either of this is true:
     *  - Attestation payload is not properly formatted.
     *  - Attestation is invalid (doesn't have a matching Notary snapshot).
     * @param _attPayload       Raw payload with attestation data
     * @return snapshotPayload  Raw payload with Notary snapshot used for creating the attestation
     */
    function getNotarySnapshot(bytes memory _attPayload)
        external
        view
        returns (bytes memory snapshotPayload);

    /**
     * @notice Returns proof of inclusion of (root, origin) fields of a given snapshot's state
     * into the Snapshot Merkle Tree for a given attestation.
     * @dev Reverts if either of this is true:
     *  - Attestation with given nonce hasn't been created yet.
     *  - State index is out of range of snapshot list.
     * @param _nonce        Nonce for the attestation
     * @param _stateIndex   Index of state in the attestation's snapshot
     * @return snapProof    The snapshot proof
     */
    function getSnapshotProof(uint256 _nonce, uint256 _stateIndex)
        external
        view
        returns (bytes32[] memory snapProof);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title Versioned
 * @notice Version getter for contracts. Doesn't use any storage slots, meaning
 * it will never cause any troubles with the upgradeable contracts. For instance, this contract
 * can be added or removed from the inheritance chain without shifting the storage layout.
 **/
abstract contract Versioned {
    /**
     * @notice Struct that is mimicking the storage layout of a string with 32 bytes or less.
     * Length is limited by 32, so the whole string payload takes two memory words:
     * @param length    String length
     * @param data      String characters
     */
    struct _ShortString {
        uint256 length;
        bytes32 data;
    }

    /// @dev Length of the "version string"
    uint256 private immutable _length;
    /// @dev Bytes representation of the "version string".
    /// Strings with length over 32 are not supported!
    bytes32 private immutable _data;

    constructor(string memory _version) {
        _length = bytes(_version).length;
        require(_length <= 32, "String length over 32");
        // bytes32 is left-aligned => this will store the byte representation of the string
        // with the trailing zeroes to complete the 32-byte word
        _data = bytes32(bytes(_version));
    }

    function version() external view returns (string memory versionString) {
        // Load the immutable values to form the version string
        _ShortString memory str = _ShortString(_length, _data);
        // The only way to do this cast is doing some dirty assembly
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            versionString := str
        }
    }
}

abstract contract Version0_0_2 is Versioned {
    // solhint-disable-next-line no-empty-blocks
    constructor() Versioned("0.0.2") {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.3) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../Strings.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library AgentSet {
    /**
     * @notice Information about an active Agent, optimized to fit in one word of storage.
     * @dev We are storing both Notaries (domain > 0) and Guards (domain == 0) this way.
     * @param domain    Domain where Agent is active
     * @param index     Agent position in _agents[domain] array, plus 1 because index 0
     *                  means Agent is not active on any domain
     */
    struct AgentIndex {
        uint32 domain;
        uint224 index;
    }

    /**
     * @notice Information about all active agents for all domains.
     * @dev We are storing both Notaries (domain > 0) and Guards (domain == 0) this way.
     * @param _agents   List of active agents for each domain
     * @param _indexes  Information about every active agent
     */
    struct DomainAddressSet {
        // (domain => [list of agents for the domain])
        mapping(uint32 => address[]) _agents;
        // (agent => agentIndex)
        mapping(address => AgentIndex) _indexes;
    }

    /**
     * @notice Add an agent to a given domain's set of active agents. O(1)
     * @dev Will not add the agent, if it is already active on another domain.
     *
     * Returns true if the agent was added to the domain, that is
     * if it was not already active on any domain.
     */
    function add(
        DomainAddressSet storage set,
        uint32 domain,
        address account
    ) internal returns (bool) {
        (bool isActive, ) = contains(set, account);
        if (isActive) return false;
        set._agents[domain].push(account);
        // The agent is stored at length-1, but we add 1 to all indexes
        // and use 0 as a sentinel value
        set._indexes[account] = AgentIndex({
            domain: domain,
            index: uint224(set._agents[domain].length)
        });
        return true;
    }

    /**
     * @notice Remove an agent from a given domain's set of active agents. O(1)
     * @dev Will not remove the agent, if it is not active on the given domain.
     *
     * Returns true if the agent was removed from the domain, that is
     * if it was active on that domain.
     */
    function remove(
        DomainAddressSet storage set,
        uint32 domain,
        address account
    ) internal returns (bool) {
        AgentIndex memory agentIndex = set._indexes[account];
        // Do nothing if agent is not active, or is active but on another domain
        if (agentIndex.index == 0 || agentIndex.domain != domain) return false;
        uint256 toDeleteIndex = agentIndex.index - 1;
        // To delete an Agent from the array in O(1),
        // we swap the Agent to delete with the last one in the array,
        // and then remove the last Agent (sometimes called as 'swap and pop').
        address[] storage agents = set._agents[domain];
        uint256 lastIndex = agents.length - 1;
        if (lastIndex != toDeleteIndex) {
            address lastAgent = agents[lastIndex];
            // Move the last Agent to the index where the Agent to delete is
            agents[toDeleteIndex] = lastAgent;
            // Update the index for the moved Agent (use deleted agent's value)
            set._indexes[lastAgent].index = agentIndex.index;
        }
        // Delete the slot where the moved Agent was stored
        agents.pop();
        // Delete the index for the deleted slot
        delete set._indexes[account];
        return true;
    }

    /**
     * @notice Returns true if the agent is active on any domain,
     * and the domain where the agent is active. O(1)
     */
    function contains(DomainAddressSet storage set, address account)
        internal
        view
        returns (bool isActive, uint32 domain)
    {
        AgentIndex memory agentIndex = set._indexes[account];
        if (agentIndex.index != 0) {
            isActive = true;
            domain = agentIndex.domain;
        }
    }

    /**
     * @notice Returns true if the agent is active on the given domain. O(1)
     */
    function contains(
        DomainAddressSet storage set,
        uint32 domain,
        address account
    ) internal view returns (bool) {
        // Read from storage just once
        AgentIndex memory agentIndex = set._indexes[account];
        // Check that agent domain matches, and that agent is active
        return agentIndex.domain == domain && agentIndex.index != 0;
    }

    /**
     * @notice Returns a number of active agents for the given domain. O(1)
     */
    function length(DomainAddressSet storage set, uint32 domain) internal view returns (uint256) {
        return set._agents[domain].length;
    }

    /**
     * @notice Returns the agent stored at position `index` in the given domain's set. O(1).
     * @dev Note that there are no guarantees on the ordering of agents inside the
     * array, and it may change when more agents are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(
        DomainAddressSet storage set,
        uint32 domain,
        uint256 index
    ) internal view returns (address) {
        return set._agents[domain][index];
    }

    /**
     * @notice Return the entire set of domain's agents in an array.
     *
     * @dev This operation will copy the entire storage to memory, which can be quite expensive.
     * This is designed to mostly be used by view accessors that are queried without any gas fees.
     * Developers should keep in mind that this function has an unbounded cost, and using it as part
     * of a state-changing function may render the function uncallable if the set grows to a point
     * where copying to memory consumes too much gas to fit in a block.
     */
    function values(DomainAddressSet storage set, uint32 domain)
        internal
        view
        returns (address[] memory)
    {
        return set._agents[domain];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ByteString, Signature } from "./ByteString.sol";
import { TypedMemView } from "./TypedMemView.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

library Auth {
    using ByteString for Signature;
    using TypedMemView for bytes29;

    /**
     * @notice Returns an Ethereum Signed Message, created from a `_view`.
     * @dev This produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     * See {recoverSigner}.
     * @param _dataView Memory view over the data that needs to be signed
     * @return digest   An Ethereum Signed Message for the given data
     */
    function toEthSignedMessageHash(bytes29 _dataView) internal pure returns (bytes32 digest) {
        // Derive hash of the original data and use that for forming an Ethereum Signed Message
        digest = ECDSA.toEthSignedMessageHash(_dataView.keccak());
    }

    /**
     * @notice Recovers signer from digest and signature.
     * @dev IMPORTANT: `_digest` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     * @param _digest       Digest that was signed
     * @param _signature    Memory view over `signer` signature on `_digest`
     * @return signer       Address that signed the data
     */
    function recoverSigner(bytes32 _digest, Signature _signature)
        internal
        pure
        returns (address signer)
    {
        (bytes32 r, bytes32 s, uint8 v) = _signature.toRSV();
        signer = ECDSA.recover({ hash: _digest, r: r, s: s, v: v });
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract AgentRegistryEvents {
    /*
     * @notice Emitted when a new Agent is added.
     * @param domain    Domain where a Agent was added
     * @param account   Address of the added agent
     */
    event AgentAdded(uint32 indexed domain, address indexed account);

    /**
     * @notice Emitted when an Agent is removed.
     * @param domain    Domain where a removed Agent was active
     * @param account   Address of the removed agent
     */
    event AgentRemoved(uint32 indexed domain, address indexed account);

    /**
     * @notice Emitted when an Agent is slashed.
     * @param domain    Domain where a slashed Agent was active
     * @param account   Address of the slashed agent
     */
    event AgentSlashed(uint32 indexed domain, address indexed account);

    /**
     * @notice Emitted when the first agent is added for the domain
     * @param domain    Domain where the first Agent was added
     */
    event DomainActivated(uint32 indexed domain);

    /**
     * @notice Emitted when the last agent is removed from the domain
     * @param domain    Domain where the last Agent was removed
     */
    event DomainDeactivated(uint32 indexed domain);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IAgentRegistry {
    /**
     * @notice Returns the amount of active agents for the given domain.
     * Note: will return the amount of active Guards, if `_domain == 0`.
     */
    function amountAgents(uint32 _domain) external view returns (uint256);

    /**
     * @notice Returns the amount of active domains.
     * @dev This always excludes the zero domain, which is used for storing the guards.
     */
    function amountDomains() external view returns (uint256);

    /**
     * @notice Returns i-th agent for a given domain.
     * @dev Will revert if index is out of range.
     * Note: domain == 0 refers to a Guard, while _domain > 0 refers to a Notary.
     */
    function getAgent(uint32 _domain, uint256 _agentIndex) external view returns (address);

    /**
     * @notice Returns i-th domain from the list of active domains.
     * @dev Will revert if index is out of range.
     * Note: this never returns the zero domain, which is used for storing the guards.
     */
    function getDomain(uint256 _domainIndex) external view returns (uint32);

    /**
     * @notice Returns all active Agents for a given domain in an array.
     * Note: will return the list of active Guards, if `_domain == 0`.
     * @dev This copies storage into memory, so can consume a lof of gas, if
     * amount of agents is large (see EnumerableSet.values())
     */
    function allAgents(uint32 _domain) external view returns (address[] memory);

    /**
     * @notice Returns all domains having at least one active Notary in an array.
     * @dev This always excludes the zero domain, which is used for storing the guards.
     */
    function allDomains() external view returns (uint32[] memory domains_);

    /**
     * @notice Returns true if the agent is active on any domain.
     * Note: that includes both Guards and Notaries.
     * @return isActive Whether the account is an active agent on any of the domains
     * @return domain   Domain, where the account is an active agent
     */
    function isActiveAgent(address _account) external view returns (bool isActive, uint32 domain);

    /**
     * @notice Returns true if the agent is active on the given domain.
     * Note: domain == 0 refers to a Guard, while _domain > 0 refers to a Notary.
     */
    function isActiveAgent(uint32 _domain, address _account) external view returns (bool);

    /**
     * @notice Returns true if there is at least one active notary for the domain
     * Note: will return false for `_domain == 0`, even if there are active Guards.
     */
    function isActiveDomain(uint32 _domain) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/structs/EnumerableSet.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 *  Trying to delete such a structure from storage will likely result in data corruption, rendering the structure unusable.
 *  See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 *  In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { AgentInfo, SystemEntity } from "../libs/Structures.sol";
import { InterfaceSystemRouter } from "./InterfaceSystemRouter.sol";

interface ISystemContract {
    /**
     * @notice Receive a system call indicating the off-chain agent needs to be slashed.
     * @param _rootSubmittedAt  Time when merkle root (used for proving this message) was submitted
     * @param _callOrigin       Domain where the system call originated
     * @param _caller           Entity which performed the system call
     * @param _info             Information about agent to slash
     */
    function slashAgent(
        uint256 _rootSubmittedAt,
        uint32 _callOrigin,
        SystemEntity _caller,
        AgentInfo memory _info
    ) external;

    /**
     * @notice Receive a system call indicating the off-chain agent status needs to be updated.
     * @param _rootSubmittedAt  Time when merkle root (used for proving this message) was submitted
     * @param _callOrigin       Domain where the system call originated
     * @param _caller           Entity which performed the system call
     * @param _info             Information about agent to sync
     */
    function syncAgent(
        uint256 _rootSubmittedAt,
        uint32 _callOrigin,
        SystemEntity _caller,
        AgentInfo memory _info
    ) external;

    function setSystemRouter(InterfaceSystemRouter _systemRouter) external;

    function systemRouter() external view returns (InterfaceSystemRouter);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { SystemEntity } from "../libs/Structures.sol";

interface InterfaceSystemRouter {
    /**
     * @notice Call a System Contract on the destination chain with a given data payload.
     * Note: for system calls on the local chain
     * - use `destination = localDomain`
     * - `_optimisticSeconds` value will be ignored
     *
     * @dev Only System contracts are allowed to call this function.
     * Note: knowledge of recipient address is not required, routing will be done by SystemRouter
     * on the destination chain. Following call will be made on destination chain:
     * - recipient.call(_data, callOrigin, systemCaller, rootSubmittedAt)
     * This allows recipient to check:
     * - callOrigin: domain where a system call originated (local domain in this case)
     * - systemCaller: system entity who initiated the call (msg.sender on local chain)
     * - rootSubmittedAt:
     *   - For cross-chain calls: timestamp when merkle root (used for executing the system call)
     *     was submitted to destination and its optimistic timer started ticking
     *   - For on-chain calls: timestamp of the current block
     *
     * @param _destination          Domain of destination chain
     * @param _optimisticSeconds    Optimistic period for the message
     * @param _recipient            System entity to receive the call on destination chain
     * @param _data                 Data for calling recipient on destination chain
     */
    function systemCall(
        uint32 _destination,
        uint32 _optimisticSeconds,
        SystemEntity _recipient,
        bytes memory _data
    ) external;

    /**
     * @notice Calls a few system contracts using the given calldata for each call.
     * See `systemCall` for details on system calls.
     * Note: tx will revert if any of the calls revert, guaranteeing
     * that either all calls succeed or none.
     */
    function systemMultiCall(
        uint32 _destination,
        uint32 _optimisticSeconds,
        SystemEntity[] memory _recipients,
        bytes[] memory _dataArray
    ) external;

    /**
     * @notice Calls a few system contracts using the same calldata for each call.
     * See `systemCall` for details on system calls.
     * Note: tx will revert if any of the calls revert, guaranteeing
     * that either all calls succeed or none.
     */
    function systemMultiCall(
        uint32 _destination,
        uint32 _optimisticSeconds,
        SystemEntity[] memory _recipients,
        bytes memory _data
    ) external;

    /**
     * @notice Calls a single system contract a few times using the given calldata for each call.
     * See `systemCall` for details on system calls.
     * Note: tx will revert if any of the calls revert, guaranteeing
     * that either all calls succeed or none.
     */
    function systemMultiCall(
        uint32 _destination,
        uint32 _optimisticSeconds,
        SystemEntity _recipient,
        bytes[] memory _dataArray
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

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

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
     */
    modifier initializer() {
        bool isTopLevelCall = _setInitializedVersion(1);
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     */
    modifier reinitializer(uint8 version) {
        bool isTopLevelCall = _setInitializedVersion(version);
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(version);
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     */
    function _disableInitializers() internal virtual {
        _setInitializedVersion(type(uint8).max);
    }

    function _setInitializedVersion(uint8 version) private returns (bool) {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, and for the lowest level
        // of initializers, because in other contexts the contract may have been reentered.
        if (_initializing) {
            require(
                version == 1 && !AddressUpgradeable.isContract(address(this)),
                "Initializable: contract is already initialized"
            );
            return false;
        } else {
            require(_initialized < version, "Initializable: contract is already initialized");
            _initialized = version;
            return true;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}