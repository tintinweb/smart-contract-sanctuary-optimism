// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// ══════════════════════════════ LIBRARY IMPORTS ══════════════════════════════
import {AttestationLib} from "./libs/memory/Attestation.sol";
import {ByteString} from "./libs/memory/ByteString.sol";
import {BONDING_OPTIMISTIC_PERIOD, SYNAPSE_DOMAIN} from "./libs/Constants.sol";
import {MustBeSynapseDomain, NotaryInDispute, TipsClaimMoreThanEarned, TipsClaimZero} from "./libs/Errors.sol";
import {Receipt, ReceiptLib} from "./libs/memory/Receipt.sol";
import {Snapshot, SnapshotLib} from "./libs/memory/Snapshot.sol";
import {AgentFlag, AgentStatus, DisputeFlag, MessageStatus} from "./libs/Structures.sol";
import {Tips, TipsLib} from "./libs/stack/Tips.sol";
// ═════════════════════════════ INTERNAL IMPORTS ══════════════════════════════
import {AgentSecured} from "./base/AgentSecured.sol";
import {SummitEvents} from "./events/SummitEvents.sol";
import {IAgentManager} from "./interfaces/IAgentManager.sol";
import {InterfaceBondingManager} from "./interfaces/InterfaceBondingManager.sol";
import {InterfaceSummit} from "./interfaces/InterfaceSummit.sol";
import {SnapshotHub} from "./hubs/SnapshotHub.sol";
// ═════════════════════════════ EXTERNAL IMPORTS ══════════════════════════════
import {DoubleEndedQueue} from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";

/// @notice `Summit` contract is the cornerstone of the Synapse messaging protocol. This is where the
/// states of all the remote chains (provided collectively by the Guards and Notaries) are stored. This is
/// also the place where the tips are distributed among the off-chain actors.
/// `Summit` is responsible for the following:
/// - Accepting Guard and Notary snapshots from the local `Inbox` contract, and storing the states from these
///   snapshots (see parent contract `SnapshotHub`).
/// - Accepting Notary Receipts from the local `Inbox` contract, and using them to distribute tips among the
///   off-chain actors that participated in the message lifecycle.
contract Summit is SnapshotHub, SummitEvents, InterfaceSummit {
    using AttestationLib for bytes;
    using ByteString for bytes;
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;
    using ReceiptLib for bytes;
    using SnapshotLib for bytes;

    // TODO: write docs, pack values
    struct SummitReceipt {
        uint32 origin;
        uint32 destination;
        uint32 attNonce;
        uint8 stateIndex;
        uint32 attNotaryIndex;
        address firstExecutor;
        address finalExecutor;
    }

    struct ReceiptStatus {
        MessageStatus status;
        bool pending;
        bool tipsAwarded;
        uint32 receiptNotaryIndex;
        uint40 submittedAt;
    }

    struct ReceiptTips {
        uint64 summitTip;
        uint64 attestationTip;
        uint64 executionTip;
        uint64 deliveryTip;
    }

    struct ActorTips {
        uint128 earned;
        uint128 claimed;
    }

    // ══════════════════════════════════════════════════ STORAGE ══════════════════════════════════════════════════════

    // (message hash => receipt data)
    mapping(bytes32 => SummitReceipt) private _receipts;

    // (message hash => receipt status)
    mapping(bytes32 => ReceiptStatus) private _receiptStatus;

    // (message hash => receipt tips)
    mapping(bytes32 => ReceiptTips) private _receiptTips;

    // Quarantine queue for message hashes
    DoubleEndedQueue.Bytes32Deque private _receiptQueue;

    /// @inheritdoc InterfaceSummit
    mapping(address => mapping(uint32 => ActorTips)) public actorTips;

    // ═════════════════════════════════════════ CONSTRUCTOR & INITIALIZER ═════════════════════════════════════════════

    constructor(uint32 domain, address agentManager_, address inbox_)
        AgentSecured("0.0.3", domain, agentManager_, inbox_)
    {
        if (domain != SYNAPSE_DOMAIN) revert MustBeSynapseDomain();
    }

    function initialize() external initializer {
        // Initialize Ownable: msg.sender is set as "owner"
        __Ownable_init();
        _initializeAttestations();
    }

    // ═════════════════════════════════════════════ ACCEPT STATEMENTS ═════════════════════════════════════════════════

    /// @inheritdoc InterfaceSummit
    function acceptReceipt(
        uint32 rcptNotaryIndex,
        uint32 attNotaryIndex,
        uint256 sigIndex,
        uint32 attNonce,
        uint256 paddedTips,
        bytes memory rcptPayload
    ) external onlyInbox returns (bool wasAccepted) {
        if (_isInDispute(rcptNotaryIndex)) revert NotaryInDispute();
        // This will revert if payload is not a receipt body
        return _saveReceipt({
            rcpt: rcptPayload.castToReceipt(),
            tips: TipsLib.wrapPadded(paddedTips),
            rcptNotaryIndex: rcptNotaryIndex,
            attNotaryIndex: attNotaryIndex,
            sigIndex: sigIndex,
            attNonce: attNonce
        });
    }

    /// @inheritdoc InterfaceSummit
    function acceptGuardSnapshot(uint32 guardIndex, uint256 sigIndex, bytes memory snapPayload) external onlyInbox {
        // Note: we don't check if Guard is in Dispute,
        // as the Guards could continue to submit snapshots after submitting a report.
        // This will revert if payload is not a snapshot
        _acceptGuardSnapshot(snapPayload.castToSnapshot(), guardIndex, sigIndex);
    }

    /// @inheritdoc InterfaceSummit
    function acceptNotarySnapshot(uint32 notaryIndex, uint256 sigIndex, bytes32 agentRoot, bytes memory snapPayload)
        external
        onlyInbox
        returns (bytes memory attPayload)
    {
        if (_isInDispute(notaryIndex)) revert NotaryInDispute();
        // This will revert if payload is not a snapshot
        return _acceptNotarySnapshot(snapPayload.castToSnapshot(), agentRoot, notaryIndex, sigIndex);
    }

    // ════════════════════════════════════════════════ TIPS LOGIC ═════════════════════════════════════════════════════

    /// @inheritdoc InterfaceSummit
    function distributeTips() public returns (bool queuePopped) {
        // Check message that is first in the "quarantine queue"
        if (_receiptQueue.empty()) return false;
        bytes32 messageHash = _receiptQueue.front();
        ReceiptStatus memory rcptStatus = _receiptStatus[messageHash];
        // Check if optimistic period for the receipt is over
        if (block.timestamp < uint256(rcptStatus.submittedAt) + BONDING_OPTIMISTIC_PERIOD) return false;
        // Fetch Notary who signed the receipt. If they are Slashed or in Dispute, exit early.
        if (_checkNotaryDisputed(messageHash, rcptStatus.receiptNotaryIndex)) return true;
        SummitReceipt memory summitRcpt = _receipts[messageHash];
        // Fetch Notary who signed the statement with snapshot root. If they are Slashed or in Dispute, exit early.
        if (_checkNotaryDisputed(messageHash, summitRcpt.attNotaryIndex)) return true;
        // At this point Receipt is optimistically verified to be correct, as well as the receipt's attestation
        // Meaning we can go ahead and distribute the tip values among the tipped actors.
        _awardTips(rcptStatus.receiptNotaryIndex, summitRcpt.attNotaryIndex, messageHash, summitRcpt, rcptStatus);
        // Save new receipt status
        rcptStatus.pending = false;
        rcptStatus.tipsAwarded = true;
        _receiptStatus[messageHash] = rcptStatus;
        // Remove the receipt from the queue
        _receiptQueue.popFront();
        return true;
    }

    /// @inheritdoc InterfaceSummit
    // solhint-disable-next-line ordering
    function withdrawTips(uint32 origin, uint256 amount) external {
        if (amount == 0) revert TipsClaimZero();
        ActorTips memory tips = actorTips[msg.sender][origin];
        if (tips.earned < amount + tips.claimed) revert TipsClaimMoreThanEarned();
        // Guaranteed to fit into uint128, as the sum is lower than `earned`
        actorTips[msg.sender][origin].claimed = uint128(tips.claimed + amount);
        InterfaceBondingManager(address(agentManager)).withdrawTips(msg.sender, origin, amount);
    }

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @inheritdoc InterfaceSummit
    // solhint-disable-next-line ordering
    function receiptQueueLength() external view returns (uint256) {
        return _receiptQueue.length();
    }

    /// @inheritdoc InterfaceSummit
    function getLatestState(uint32 origin) external view returns (bytes memory statePayload) {
        // Get a list of currently active guards
        address[] memory guards = InterfaceBondingManager(address(agentManager)).getActiveAgents(0);
        SummitState memory latestState;
        for (uint256 i = 0; i < guards.length; ++i) {
            SummitState memory state = _latestState(origin, _agentStatus(guards[i]).index);
            if (state.nonce > latestState.nonce) latestState = state;
        }
        // Check if we found anything
        if (latestState.nonce != 0) {
            statePayload = _formatSummitState(latestState);
        }
    }

    // ═══════════════════════════════════════════ INTERNAL LOGIC: QUEUE ═══════════════════════════════════════════════

    /// @dev Checks if the given Notary has been disputed.
    /// - Notary was slashed => receipt is invalided and deleted
    /// - Notary is in Dispute => receipt handling is postponed
    function _checkNotaryDisputed(bytes32 messageHash, uint32 notaryIndex) internal returns (bool queuePopped) {
        DisputeFlag flag = _disputes[notaryIndex];
        if (flag == DisputeFlag.Slashed) {
            // Notary has been slashed, so we can't trust their statement.
            // Honest Notaries are incentivized to resubmit the Receipt or Attestation if it was in fact valid.
            _deleteFromQueue(messageHash);
            queuePopped = true;
        } else if (flag == DisputeFlag.Pending) {
            // Notary is not slashed, but is in Dispute. To keep the tips flow going we add the receipt to the back of
            // the queue, hoping that by the next interaction the dispute will have been resolved.
            _moveToBack();
            queuePopped = true;
        }
    }

    /// @dev Deletes all stored receipt data and removes it from the queue.
    function _deleteFromQueue(bytes32 messageHash) internal {
        delete _receipts[messageHash];
        delete _receiptStatus[messageHash];
        delete _receiptTips[messageHash];
        _receiptQueue.popFront();
    }

    /// @dev Moves the front element of the queue to its back.
    function _moveToBack() internal {
        bytes32 popped = _receiptQueue.popFront();
        _receiptQueue.pushBack(popped);
    }

    /// @dev Saves the message from the receipt into the "quarantine queue". Once message leaves the queue,
    /// tips associated with the message are distributed across off-chain actors.
    function _saveReceipt(
        Receipt rcpt,
        Tips tips,
        uint32 rcptNotaryIndex,
        uint32 attNotaryIndex,
        uint256 sigIndex,
        uint32 attNonce
    ) internal returns (bool) {
        // TODO: save signature index
        // Check if tip values are non-zero
        if (tips.value() == 0) return false;
        // Check if there already exists receipt for the message
        bytes32 messageHash = rcpt.messageHash();
        ReceiptStatus memory savedRcpt = _receiptStatus[messageHash];
        // Don't save if receipt is already in the queue
        if (savedRcpt.pending) return false;
        // Get the status from the provided receipt
        MessageStatus msgStatus = rcpt.finalExecutor() == address(0) ? MessageStatus.Failed : MessageStatus.Success;
        // Don't save if we already have the receipt with at least this status
        if (savedRcpt.status >= msgStatus) return false;
        // Save information from the receipt
        _receipts[messageHash] = SummitReceipt({
            origin: rcpt.origin(),
            destination: rcpt.destination(),
            attNonce: attNonce,
            stateIndex: rcpt.stateIndex(),
            attNotaryIndex: attNotaryIndex,
            firstExecutor: rcpt.firstExecutor(),
            finalExecutor: rcpt.finalExecutor()
        });
        // Save receipt status: transfer tipsAwarded field (whether we paid tips for Failed Receipt before)
        _receiptStatus[messageHash] = ReceiptStatus({
            status: msgStatus,
            pending: true,
            tipsAwarded: savedRcpt.tipsAwarded,
            receiptNotaryIndex: rcptNotaryIndex,
            submittedAt: uint40(block.timestamp)
        });
        // Save receipt tips
        _receiptTips[messageHash] = ReceiptTips({
            summitTip: tips.summitTip(),
            attestationTip: tips.attestationTip(),
            executionTip: tips.executionTip(),
            deliveryTip: tips.deliveryTip()
        });
        // Add message hash to the quarantine queue
        _receiptQueue.pushBack(messageHash);
        return true;
    }

    // ══════════════════════════════════════ INTERNAL LOGIC: TIPS ACCOUNTING ══════════════════════════════════════════

    /// @dev Awards tips to the agent/actors that participated in message lifecycle
    function _awardTips(
        uint32 rcptNotaryIndex,
        uint32 attNotaryIndex,
        bytes32 messageHash,
        SummitReceipt memory summitRcpt,
        ReceiptStatus memory rcptStatus
    ) internal {
        ReceiptTips memory tips = _receiptTips[messageHash];
        // Check if we awarded tips for this message earlier
        bool awardFirst = !rcptStatus.tipsAwarded;
        // Check if this is the final tips distribution
        bool awardFinal = rcptStatus.status == MessageStatus.Success;
        if (awardFirst) {
            // There has been a valid attempt to execute the message
            _awardSnapshotTip(summitRcpt.attNonce, summitRcpt.stateIndex, summitRcpt.origin, tips.summitTip);
            _awardAgentTip(attNotaryIndex, summitRcpt.origin, tips.attestationTip);
            _awardActorTip(summitRcpt.firstExecutor, summitRcpt.origin, tips.executionTip);
        }
        _awardReceiptTip(rcptNotaryIndex, awardFirst, awardFinal, summitRcpt.origin, tips.summitTip);
        if (awardFinal) {
            // Message has been executed successfully
            _awardActorTip(summitRcpt.finalExecutor, summitRcpt.origin, tips.deliveryTip);
        }
    }

    /// @dev Award tip to the bonded agent
    function _awardAgentTip(uint32 agentIndex, uint32 origin, uint64 tip) internal {
        (address agent, AgentStatus memory status) = _getAgent(agentIndex);
        // If agent has been slashed, their earned tips go to treasury
        if (status.flag == AgentFlag.Fraudulent || status.flag == AgentFlag.Slashed) {
            agent = address(0);
        }
        _awardActorTip(agent, origin, tip);
    }

    /// @dev Award tip to any actor whether bonded or unbonded
    function _awardActorTip(address actor, uint32 origin, uint64 tip) internal {
        actorTips[actor][origin].earned += tip;
        emit TipAwarded(actor, origin, tip);
    }

    /// @dev Award tip for posting Receipt to Summit contract.
    function _awardReceiptTip(uint32 rcptNotaryIndex, bool awardFirst, bool awardFinal, uint32 origin, uint64 summitTip)
        internal
    {
        uint64 receiptTip = _receiptTip(summitTip);
        uint64 receiptTipAwarded;
        if (awardFirst && awardFinal) {
            receiptTipAwarded = receiptTip;
        } else if (awardFirst) {
            // Tip for posting Receipt with status >= MessageStatus.Failed
            receiptTipAwarded = receiptTip / 2;
        } else if (awardFinal) {
            // Tip for posting Receipt with status == MessageStatus.Success
            receiptTipAwarded = receiptTip - receiptTip / 2;
        }
        _awardAgentTip(rcptNotaryIndex, origin, receiptTipAwarded);
    }

    /// @dev Award tip for posting Snapshot to Summit contract.
    function _awardSnapshotTip(uint32 attNonce, uint8 stateIndex, uint32 origin, uint64 summitTip) internal {
        uint64 snapshotTip = _snapshotTip(summitTip);
        // Get the agents who submitted the given state for the attestation's snapshot
        (uint32 guardIndex, uint32 notaryIndex) = _stateAgents(attNonce, stateIndex);
        _awardAgentTip(guardIndex, origin, snapshotTip);
        _awardAgentTip(notaryIndex, origin, snapshotTip);
    }

    // ══════════════════════════════════════════════ INTERNAL VIEWS ═══════════════════════════════════════════════════

    /// @dev Returns "snapshot part" of the summit tip.
    function _snapshotTip(uint64 summitTip) internal pure returns (uint64) {
        return summitTip / 3;
    }

    /// @dev Returns "receipt part" of the summit tip.
    function _receiptTip(uint64 summitTip) internal pure returns (uint64) {
        return summitTip - 2 * _snapshotTip(summitTip);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MemView, MemViewLib} from "./MemView.sol";
import {ATTESTATION_LENGTH, ATTESTATION_VALID_SALT, ATTESTATION_INVALID_SALT} from "../Constants.sol";
import {UnformattedAttestation} from "../Errors.sol";

/// Attestation is a memory view over a formatted attestation payload.
type Attestation is uint256;

using AttestationLib for Attestation global;

/// # Attestation
/// Attestation structure represents the "Snapshot Merkle Tree" created from
/// every Notary snapshot accepted by the Summit contract. Attestation includes"
/// the root of the "Snapshot Merkle Tree", as well as additional metadata.
///
/// ## Steps for creation of "Snapshot Merkle Tree":
/// 1. The list of hashes is composed for states in the Notary snapshot.
/// 2. The list is padded with zero values until its length is 2**SNAPSHOT_TREE_HEIGHT.
/// 3. Values from the list are used as leafs and the merkle tree is constructed.
///
/// ## Differences between a State and Attestation
/// Similar to Origin, every derived Notary's "Snapshot Merkle Root" is saved in Summit contract.
/// The main difference is that Origin contract itself is keeping track of an incremental merkle tree,
/// by inserting the hash of the sent message and calculating the new "Origin Merkle Root".
/// While Summit relies on Guards and Notaries to provide snapshot data, which is used to calculate the
/// "Snapshot Merkle Root".
///
/// - Origin's State is "state of Origin Merkle Tree after N-th message was sent".
/// - Summit's Attestation is "data for the N-th accepted Notary Snapshot" + "agent merkle root at the
/// time snapshot was submitted" + "attestation metadata".
///
/// ## Attestation validity
/// - Attestation is considered "valid" in Summit contract, if it matches the N-th (nonce)
/// snapshot submitted by Notaries, as well as the historical agent merkle root.
/// - Attestation is considered "valid" in Origin contract, if its underlying Snapshot is "valid".
///
/// - This means that a snapshot could be "valid" in Summit contract and "invalid" in Origin, if the underlying
/// snapshot is invalid (i.e. one of the states in the list is invalid).
/// - The opposite could also be true. If a perfectly valid snapshot was never submitted to Summit, its attestation
/// would be valid in Origin, but invalid in Summit (it was never accepted, so the metadata would be incorrect).
///
/// - Attestation is considered "globally valid", if it is valid in the Summit and all the Origin contracts.
/// # Memory layout of Attestation fields
///
/// | Position   | Field       | Type    | Bytes | Description                                                    |
/// | ---------- | ----------- | ------- | ----- | -------------------------------------------------------------- |
/// | [000..032) | snapRoot    | bytes32 | 32    | Root for "Snapshot Merkle Tree" created from a Notary snapshot |
/// | [032..064) | dataHash    | bytes32 | 32    | Agent Root and SnapGasHash combined into a single hash         |
/// | [064..068) | nonce       | uint32  | 4     | Total amount of all accepted Notary snapshots                  |
/// | [068..073) | blockNumber | uint40  | 5     | Block when this Notary snapshot was accepted in Summit         |
/// | [073..078) | timestamp   | uint40  | 5     | Time when this Notary snapshot was accepted in Summit          |
///
/// @dev Attestation could be signed by a Notary and submitted to `Destination` in order to use if for proving
/// messages coming from origin chains that the initial snapshot refers to.
library AttestationLib {
    using MemViewLib for bytes;

    // TODO: compress three hashes into one?

    /// @dev The variables below are not supposed to be used outside of the library directly.
    uint256 private constant OFFSET_SNAP_ROOT = 0;
    uint256 private constant OFFSET_DATA_HASH = 32;
    uint256 private constant OFFSET_NONCE = 64;
    uint256 private constant OFFSET_BLOCK_NUMBER = 68;
    uint256 private constant OFFSET_TIMESTAMP = 73;

    // ════════════════════════════════════════════════ ATTESTATION ════════════════════════════════════════════════════

    /**
     * @notice Returns a formatted Attestation payload with provided fields.
     * @param snapRoot_     Snapshot merkle tree's root
     * @param dataHash_     Agent Root and SnapGasHash combined into a single hash
     * @param nonce_        Attestation Nonce
     * @param blockNumber_  Block number when attestation was created in Summit
     * @param timestamp_    Block timestamp when attestation was created in Summit
     * @return Formatted attestation
     */
    function formatAttestation(
        bytes32 snapRoot_,
        bytes32 dataHash_,
        uint32 nonce_,
        uint40 blockNumber_,
        uint40 timestamp_
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(snapRoot_, dataHash_, nonce_, blockNumber_, timestamp_);
    }

    /**
     * @notice Returns an Attestation view over the given payload.
     * @dev Will revert if the payload is not an attestation.
     */
    function castToAttestation(bytes memory payload) internal pure returns (Attestation) {
        return castToAttestation(payload.ref());
    }

    /**
     * @notice Casts a memory view to an Attestation view.
     * @dev Will revert if the memory view is not over an attestation.
     */
    function castToAttestation(MemView memView) internal pure returns (Attestation) {
        if (!isAttestation(memView)) revert UnformattedAttestation();
        return Attestation.wrap(MemView.unwrap(memView));
    }

    /// @notice Checks that a payload is a formatted Attestation.
    function isAttestation(MemView memView) internal pure returns (bool) {
        return memView.len() == ATTESTATION_LENGTH;
    }

    /// @notice Returns the hash of an Attestation, that could be later signed by a Notary to signal
    /// that the attestation is valid.
    function hashValid(Attestation att) internal pure returns (bytes32) {
        // The final hash to sign is keccak(attestationSalt, keccak(attestation))
        return att.unwrap().keccakSalted(ATTESTATION_VALID_SALT);
    }

    /// @notice Returns the hash of an Attestation, that could be later signed by a Guard to signal
    /// that the attestation is invalid.
    function hashInvalid(Attestation att) internal pure returns (bytes32) {
        // The final hash to sign is keccak(attestationInvalidSalt, keccak(attestation))
        return att.unwrap().keccakSalted(ATTESTATION_INVALID_SALT);
    }

    /// @notice Convenience shortcut for unwrapping a view.
    function unwrap(Attestation att) internal pure returns (MemView) {
        return MemView.wrap(Attestation.unwrap(att));
    }

    // ════════════════════════════════════════════ ATTESTATION SLICING ════════════════════════════════════════════════

    /// @notice Returns root of the Snapshot merkle tree created in the Summit contract.
    function snapRoot(Attestation att) internal pure returns (bytes32) {
        return att.unwrap().index({index_: OFFSET_SNAP_ROOT, bytes_: 32});
    }

    /// @notice Returns hash of the Agent Root and SnapGasHash combined into a single hash.
    function dataHash(Attestation att) internal pure returns (bytes32) {
        return att.unwrap().index({index_: OFFSET_DATA_HASH, bytes_: 32});
    }

    /// @notice Returns hash of the Agent Root and SnapGasHash combined into a single hash.
    function dataHash(bytes32 agentRoot_, bytes32 snapGasHash_) internal pure returns (bytes32) {
        return keccak256(bytes.concat(agentRoot_, snapGasHash_));
    }

    /// @notice Returns nonce of Summit contract at the time, when attestation was created.
    function nonce(Attestation att) internal pure returns (uint32) {
        return uint32(att.unwrap().indexUint({index_: OFFSET_NONCE, bytes_: 4}));
    }

    /// @notice Returns a block number when attestation was created in Summit.
    function blockNumber(Attestation att) internal pure returns (uint40) {
        return uint40(att.unwrap().indexUint({index_: OFFSET_BLOCK_NUMBER, bytes_: 5}));
    }

    /// @notice Returns a block timestamp when attestation was created in Summit.
    /// @dev This is the timestamp according to the Synapse Chain.
    function timestamp(Attestation att) internal pure returns (uint40) {
        return uint40(att.unwrap().indexUint({index_: OFFSET_TIMESTAMP, bytes_: 5}));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MemView, MemViewLib} from "./MemView.sol";
import {UnformattedCallData, UnformattedCallDataPrefix, UnformattedSignature} from "../Errors.sol";

/// @dev CallData is a memory view over the payload to be used for an external call, i.e.
/// recipient.call(callData). Its length is always (4 + 32 * N) bytes:
/// - First 4 bytes represent the function selector.
/// - 32 * N bytes represent N words that function arguments occupy.
type CallData is uint256;

/// @dev Attach library functions to CallData
using ByteString for CallData global;

/// @dev Signature is a memory view over a "65 bytes" array representing a ECDSA signature.
type Signature is uint256;

/// @dev Attach library functions to Signature
using ByteString for Signature global;

library ByteString {
    using MemViewLib for bytes;

    /**
     * @dev non-compact ECDSA signatures are enforced as of OZ 4.7.3
     *
     *      Signature payload memory layout
     * [000 .. 032) r   bytes32 32 bytes
     * [032 .. 064) s   bytes32 32 bytes
     * [064 .. 065) v   uint8    1 byte
     */
    uint256 internal constant SIGNATURE_LENGTH = 65;
    uint256 private constant OFFSET_R = 0;
    uint256 private constant OFFSET_S = 32;
    uint256 private constant OFFSET_V = 64;

    /**
     * @dev Calldata memory layout
     * [000 .. 004) selector    bytes4  4 bytes
     *      Optional: N function arguments
     * [004 .. 036) arg1        bytes32 32 bytes
     *      ..
     * [AAA .. END) argN        bytes32 32 bytes
     */
    uint256 internal constant SELECTOR_LENGTH = 4;
    uint256 private constant OFFSET_SELECTOR = 0;
    uint256 private constant OFFSET_ARGUMENTS = SELECTOR_LENGTH;

    // ═════════════════════════════════════════════════ SIGNATURE ═════════════════════════════════════════════════════

    /**
     * @notice Constructs the signature payload from the given values.
     * @dev Using ByteString.formatSignature({r: r, s: s, v: v}) will make sure
     * that params are given in the right order.
     */
    function formatSignature(bytes32 r, bytes32 s, uint8 v) internal pure returns (bytes memory) {
        return abi.encodePacked(r, s, v);
    }

    /**
     * @notice Returns a Signature view over for the given payload.
     * @dev Will revert if the payload is not a signature.
     */
    function castToSignature(bytes memory payload) internal pure returns (Signature) {
        return castToSignature(payload.ref());
    }

    /**
     * @notice Casts a memory view to a Signature view.
     * @dev Will revert if the memory view is not over a signature.
     */
    function castToSignature(MemView memView) internal pure returns (Signature) {
        if (!isSignature(memView)) revert UnformattedSignature();
        return Signature.wrap(MemView.unwrap(memView));
    }

    /**
     * @notice Checks that a byte string is a signature
     */
    function isSignature(MemView memView) internal pure returns (bool) {
        return memView.len() == SIGNATURE_LENGTH;
    }

    /// @notice Convenience shortcut for unwrapping a view.
    function unwrap(Signature signature) internal pure returns (MemView) {
        return MemView.wrap(Signature.unwrap(signature));
    }

    // ═════════════════════════════════════════════ SIGNATURE SLICING ═════════════════════════════════════════════════

    /// @notice Unpacks signature payload into (r, s, v) parameters.
    /// @dev Make sure to verify signature length with isSignature() beforehand.
    function toRSV(Signature signature) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        // Get the underlying memory view
        MemView memView = unwrap(signature);
        r = memView.index({index_: OFFSET_R, bytes_: 32});
        s = memView.index({index_: OFFSET_S, bytes_: 32});
        v = uint8(memView.indexUint({index_: OFFSET_V, bytes_: 1}));
    }

    // ═════════════════════════════════════════════════ CALLDATA ══════════════════════════════════════════════════════

    /**
     * @notice Constructs the calldata with the modified arguments:
     * the existing arguments are prepended with the arguments from the prefix.
     * @dev Given:
     *  - `calldata = abi.encodeWithSelector(foo.selector, d, e);`
     *  - `prefix = abi.encode(a, b, c);`
     *  - `a`, `b`, `c` are arguments of static type (i.e. not dynamically sized ones)
     *      Then:
     *  - Function will return abi.encodeWithSelector(foo.selector, a, c, c, d, e)
     *  - Returned calldata will trigger `foo(a, b, c, d, e)` when used for a contract call.
     * Note: for clarification as to what types are considered static, see
     * https://docs.soliditylang.org/en/latest/abi-spec.html#formal-specification-of-the-encoding
     * @param callData  Calldata that needs to be modified
     * @param prefix    ABI-encoded arguments to use as the first arguments in the new calldata
     * @return Modified calldata having prefix as the first arguments.
     */
    function addPrefix(CallData callData, bytes memory prefix) internal view returns (bytes memory) {
        // Prefix should occupy a whole amount of words in memory
        if (!_fullWords(prefix.length)) revert UnformattedCallDataPrefix();
        MemView[] memory views = new MemView[](3);
        // Use payload's function selector
        views[0] = abi.encodePacked(callData.callSelector()).ref();
        // Use prefix as the first arguments
        views[1] = prefix.ref();
        // Use payload's remaining arguments
        views[2] = callData.arguments();
        return MemViewLib.join(views);
    }

    /**
     * @notice Returns a CallData view over for the given payload.
     * @dev Will revert if the memory view is not over a calldata.
     */
    function castToCallData(bytes memory payload) internal pure returns (CallData) {
        return castToCallData(payload.ref());
    }

    /**
     * @notice Casts a memory view to a CallData view.
     * @dev Will revert if the memory view is not over a calldata.
     */
    function castToCallData(MemView memView) internal pure returns (CallData) {
        if (!isCallData(memView)) revert UnformattedCallData();
        return CallData.wrap(MemView.unwrap(memView));
    }

    /**
     * @notice Checks that a byte string is a valid calldata, i.e.
     * a function selector, followed by arbitrary amount of arguments.
     */
    function isCallData(MemView memView) internal pure returns (bool) {
        uint256 length = memView.len();
        // Calldata should at least have a function selector
        if (length < SELECTOR_LENGTH) return false;
        // The remainder of the calldata should be exactly N memory words (N >= 0)
        return _fullWords(length - SELECTOR_LENGTH);
    }

    /// @notice Convenience shortcut for unwrapping a view.
    function unwrap(CallData callData) internal pure returns (MemView) {
        return MemView.wrap(CallData.unwrap(callData));
    }

    /// @notice Returns callData's hash: a leaf to be inserted in the "Message mini-Merkle tree".
    function leaf(CallData callData) internal pure returns (bytes32) {
        return callData.unwrap().keccak();
    }

    // ═════════════════════════════════════════════ CALLDATA SLICING ══════════════════════════════════════════════════

    /**
     * @notice Returns amount of memory words (32 byte chunks) the function arguments
     * occupy in the calldata.
     * @dev This might differ from amount of arguments supplied, if any of the arguments
     * occupies more than one memory slot. It is true, however, that argument part of the payload
     * occupies exactly N words, even for dynamic types like `bytes`
     */
    function argumentWords(CallData callData) internal pure returns (uint256) {
        // Get the underlying memory view
        MemView memView = unwrap(callData);
        // Equivalent of (length - SELECTOR_LENGTH) / 32
        return (memView.len() - SELECTOR_LENGTH) >> 5;
    }

    /// @notice Returns selector for the provided calldata.
    function callSelector(CallData callData) internal pure returns (bytes4) {
        // Get the underlying memory view
        MemView memView = unwrap(callData);
        return bytes4(memView.index({index_: OFFSET_SELECTOR, bytes_: SELECTOR_LENGTH}));
    }

    /// @notice Returns abi encoded arguments for the provided calldata.
    function arguments(CallData callData) internal pure returns (MemView) {
        // Get the underlying memory view
        MemView memView = unwrap(callData);
        return memView.sliceFrom({index_: OFFSET_ARGUMENTS});
    }

    // ══════════════════════════════════════════════ PRIVATE HELPERS ══════════════════════════════════════════════════

    /// @dev Checks if length is full amount of memory words (32 bytes).
    function _fullWords(uint256 length) internal pure returns (bool) {
        // The equivalent of length % 32 == 0
        return length & 31 == 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Here we define common constants to enable their easier reusing later.

// ══════════════════════════════════ MERKLE ═══════════════════════════════════
/// @dev Height of the Agent Merkle Tree
uint256 constant AGENT_TREE_HEIGHT = 32;
/// @dev Height of the Origin Merkle Tree
uint256 constant ORIGIN_TREE_HEIGHT = 32;
/// @dev Height of the Snapshot Merkle Tree. Allows up to 64 leafs, e.g. up to 32 states
uint256 constant SNAPSHOT_TREE_HEIGHT = 6;
// ══════════════════════════════════ STRUCTS ══════════════════════════════════
/// @dev See Attestation.sol: (bytes32,bytes32,uint32,uint40,uint40): 32+32+4+5+5
uint256 constant ATTESTATION_LENGTH = 78;
/// @dev See GasData.sol: (uint16,uint16,uint16,uint16,uint16,uint16): 2+2+2+2+2+2
uint256 constant GAS_DATA_LENGTH = 12;
/// @dev See Receipt.sol: (uint32,uint32,bytes32,bytes32,uint8,address,address,address): 4+4+32+32+1+20+20+20
uint256 constant RECEIPT_LENGTH = 133;
/// @dev See State.sol: (bytes32,uint32,uint32,uint40,uint40,GasData): 32+4+4+5+5+len(GasData)
uint256 constant STATE_LENGTH = 50 + GAS_DATA_LENGTH;
/// @dev Maximum amount of states in a single snapshot. Each state produces two leafs in the tree
uint256 constant SNAPSHOT_MAX_STATES = 1 << (SNAPSHOT_TREE_HEIGHT - 1);
// ══════════════════════════════════ MESSAGE ══════════════════════════════════
/// @dev See Header.sol: (uint8,uint32,uint32,uint32,uint32): 1+4+4+4+4
uint256 constant HEADER_LENGTH = 17;
/// @dev See Request.sol: (uint96,uint64,uint32): 12+8+4
uint256 constant REQUEST_LENGTH = 24;
/// @dev See Tips.sol: (uint64,uint64,uint64,uint64): 8+8+8+8
uint256 constant TIPS_LENGTH = 32;
/// @dev The amount of discarded last bits when encoding tip values
uint256 constant TIPS_GRANULARITY = 32;
/// @dev Tip values could be only the multiples of TIPS_MULTIPLIER
uint256 constant TIPS_MULTIPLIER = 1 << TIPS_GRANULARITY;
// ══════════════════════════════ STATEMENT SALTS ══════════════════════════════
/// @dev Salts for signing various statements
bytes32 constant ATTESTATION_VALID_SALT = keccak256("ATTESTATION_VALID_SALT");
bytes32 constant ATTESTATION_INVALID_SALT = keccak256("ATTESTATION_INVALID_SALT");
bytes32 constant RECEIPT_VALID_SALT = keccak256("RECEIPT_VALID_SALT");
bytes32 constant RECEIPT_INVALID_SALT = keccak256("RECEIPT_INVALID_SALT");
bytes32 constant SNAPSHOT_VALID_SALT = keccak256("SNAPSHOT_VALID_SALT");
bytes32 constant STATE_INVALID_SALT = keccak256("STATE_INVALID_SALT");
// ═════════════════════════════════ PROTOCOL ══════════════════════════════════
/// @dev Optimistic period for new agent roots in LightManager
uint32 constant AGENT_ROOT_OPTIMISTIC_PERIOD = 1 days;
uint32 constant BONDING_OPTIMISTIC_PERIOD = 1 days;
/// @dev Amount of time without fresh data from Notaries before contract owner can resolve stuck disputes manually
uint256 constant FRESH_DATA_TIMEOUT = 4 hours;
/// @dev Maximum bytes per message = 2 KiB (somewhat arbitrarily set to begin)
uint256 constant MAX_CONTENT_BYTES = 2 * 2 ** 10;
/// @dev Domain of the Synapse Chain
// TODO: replace the placeholder with actual value (for MVP this is Optimism chainId)
uint32 constant SYNAPSE_DOMAIN = 10;

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// ══════════════════════════════ INVALID CALLER ═══════════════════════════════

error CallerNotAgentManager();
error CallerNotDestination();
error CallerNotInbox();
error CallerNotSummit();

// ══════════════════════════════ INCORRECT DATA ═══════════════════════════════

error IncorrectAttestation();
error IncorrectAgentDomain();
error IncorrectAgentIndex();
error IncorrectAgentProof();
error IncorrectDataHash();
error IncorrectDestinationDomain();
error IncorrectOriginDomain();
error IncorrectSnapshotProof();
error IncorrectSnapshotRoot();
error IncorrectState();
error IncorrectStatesAmount();
error IncorrectTipsProof();
error IncorrectVersionLength();

error IncorrectNonce();
error IncorrectSender();
error IncorrectRecipient();

error FlagOutOfRange();
error IndexOutOfRange();
error NonceOutOfRange();

error OutdatedNonce();

error UnformattedAttestation();
error UnformattedAttestationReport();
error UnformattedBaseMessage();
error UnformattedCallData();
error UnformattedCallDataPrefix();
error UnformattedMessage();
error UnformattedReceipt();
error UnformattedReceiptReport();
error UnformattedSignature();
error UnformattedSnapshot();
error UnformattedState();
error UnformattedStateReport();

// ═══════════════════════════════ MERKLE TREES ════════════════════════════════

error LeafNotProven();
error MerkleTreeFull();
error NotEnoughLeafs();
error TreeHeightTooLow();

// ═════════════════════════════ OPTIMISTIC PERIOD ═════════════════════════════

error BaseClientOptimisticPeriod();
error MessageOptimisticPeriod();
error SlashAgentOptimisticPeriod();
error WithdrawTipsOptimisticPeriod();
error ZeroProofMaturity();

// ═══════════════════════════════ AGENT MANAGER ═══════════════════════════════

error AgentNotGuard();
error AgentNotNotary();

error AgentCantBeAdded();
error AgentNotActive();
error AgentNotActiveNorUnstaking();
error AgentNotFraudulent();
error AgentNotUnstaking();
error AgentUnknown();

error DisputeAlreadyResolved();
error DisputeNotOpened();
error DisputeNotStuck();
error GuardInDispute();
error NotaryInDispute();

error MustBeSynapseDomain();
error SynapseDomainForbidden();

// ════════════════════════════════ DESTINATION ════════════════════════════════

error AlreadyExecuted();
error AlreadyFailed();
error DuplicatedSnapshotRoot();
error IncorrectMagicValue();
error GasLimitTooLow();
error GasSuppliedTooLow();

// ══════════════════════════════════ ORIGIN ═══════════════════════════════════

error ContentLengthTooBig();
error EthTransferFailed();
error InsufficientEthBalance();

// ════════════════════════════════ GAS ORACLE ═════════════════════════════════

error LocalGasDataNotSet();
error RemoteGasDataNotSet();

// ═══════════════════════════════════ TIPS ════════════════════════════════════

error TipsClaimMoreThanEarned();
error TipsClaimZero();
error TipsOverflow();
error TipsValueTooLow();

// ════════════════════════════════ MEMORY VIEW ════════════════════════════════

error IndexedTooMuch();
error ViewOverrun();
error OccupiedMemory();
error UnallocatedMemory();
error PrecompileOutOfGas();

// ═════════════════════════════════ MULTICALL ═════════════════════════════════

error MulticallFailed();

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MemView, MemViewLib} from "./MemView.sol";
import {RECEIPT_LENGTH, RECEIPT_VALID_SALT, RECEIPT_INVALID_SALT} from "../Constants.sol";
import {UnformattedReceipt} from "../Errors.sol";

/// Receipt is a memory view over a formatted "full receipt" payload.
type Receipt is uint256;

using ReceiptLib for Receipt global;

/// Receipt structure represents a Notary statement that a certain message has been executed in `ExecutionHub`.
/// - It is possible to prove the correctness of the tips payload using the message hash, therefore tips are not
///   included in the receipt.
/// - Receipt is signed by a Notary and submitted to `Summit` in order to initiate the tips distribution for an
///   executed message.
/// - If a message execution fails the first time, the `finalExecutor` field will be set to zero address. In this
///   case, when the message is finally executed successfully, the `finalExecutor` field will be updated. Both
///   receipts will be considered valid.
/// # Memory layout of Receipt fields
///
/// | Position   | Field         | Type    | Bytes | Description                                      |
/// | ---------- | ------------- | ------- | ----- | ------------------------------------------------ |
/// | [000..004) | origin        | uint32  | 4     | Domain where message originated                  |
/// | [004..008) | destination   | uint32  | 4     | Domain where message was executed                |
/// | [008..040) | messageHash   | bytes32 | 32    | Hash of the message                              |
/// | [040..072) | snapshotRoot  | bytes32 | 32    | Snapshot root used for proving the message       |
/// | [072..073) | stateIndex    | uint8   | 1     | Index of state used for the snapshot proof       |
/// | [073..093) | attNotary     | address | 20    | Notary who posted attestation with snapshot root |
/// | [093..113) | firstExecutor | address | 20    | Executor who performed first valid execution     |
/// | [113..133) | finalExecutor | address | 20    | Executor who successfully executed the message   |
library ReceiptLib {
    using MemViewLib for bytes;

    /// @dev The variables below are not supposed to be used outside of the library directly.
    uint256 private constant OFFSET_ORIGIN = 0;
    uint256 private constant OFFSET_DESTINATION = 4;
    uint256 private constant OFFSET_MESSAGE_HASH = 8;
    uint256 private constant OFFSET_SNAPSHOT_ROOT = 40;
    uint256 private constant OFFSET_STATE_INDEX = 72;
    uint256 private constant OFFSET_ATT_NOTARY = 73;
    uint256 private constant OFFSET_FIRST_EXECUTOR = 93;
    uint256 private constant OFFSET_FINAL_EXECUTOR = 113;

    // ═════════════════════════════════════════════════ RECEIPT ═════════════════════════════════════════════════════

    /**
     * @notice Returns a formatted Receipt payload with provided fields.
     * @param origin_           Domain where message originated
     * @param destination_      Domain where message was executed
     * @param messageHash_      Hash of the message
     * @param snapshotRoot_     Snapshot root used for proving the message
     * @param stateIndex_       Index of state used for the snapshot proof
     * @param attNotary_        Notary who posted attestation with snapshot root
     * @param firstExecutor_    Executor who performed first valid execution attempt
     * @param finalExecutor_    Executor who successfully executed the message
     * @return Formatted receipt
     */
    function formatReceipt(
        uint32 origin_,
        uint32 destination_,
        bytes32 messageHash_,
        bytes32 snapshotRoot_,
        uint8 stateIndex_,
        address attNotary_,
        address firstExecutor_,
        address finalExecutor_
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            origin_, destination_, messageHash_, snapshotRoot_, stateIndex_, attNotary_, firstExecutor_, finalExecutor_
        );
    }

    /**
     * @notice Returns a Receipt view over the given payload.
     * @dev Will revert if the payload is not a receipt.
     */
    function castToReceipt(bytes memory payload) internal pure returns (Receipt) {
        return castToReceipt(payload.ref());
    }

    /**
     * @notice Casts a memory view to a Receipt view.
     * @dev Will revert if the memory view is not over a receipt.
     */
    function castToReceipt(MemView memView) internal pure returns (Receipt) {
        if (!isReceipt(memView)) revert UnformattedReceipt();
        return Receipt.wrap(MemView.unwrap(memView));
    }

    /// @notice Checks that a payload is a formatted Receipt.
    function isReceipt(MemView memView) internal pure returns (bool) {
        // Check payload length
        return memView.len() == RECEIPT_LENGTH;
    }

    /// @notice Returns the hash of an Receipt, that could be later signed by a Notary to signal
    /// that the receipt is valid.
    function hashValid(Receipt receipt) internal pure returns (bytes32) {
        // The final hash to sign is keccak(receiptSalt, keccak(receipt))
        return receipt.unwrap().keccakSalted(RECEIPT_VALID_SALT);
    }

    /// @notice Returns the hash of a Receipt, that could be later signed by a Guard to signal
    /// that the receipt is invalid.
    function hashInvalid(Receipt receipt) internal pure returns (bytes32) {
        // The final hash to sign is keccak(receiptBodyInvalidSalt, keccak(receipt))
        return receipt.unwrap().keccakSalted(RECEIPT_INVALID_SALT);
    }

    /// @notice Convenience shortcut for unwrapping a view.
    function unwrap(Receipt receipt) internal pure returns (MemView) {
        return MemView.wrap(Receipt.unwrap(receipt));
    }

    /// @notice Compares two Receipt structures.
    function equals(Receipt a, Receipt b) internal pure returns (bool) {
        // Length of a Receipt payload is fixed, so we just need to compare the hashes
        return a.unwrap().keccak() == b.unwrap().keccak();
    }

    // ═════════════════════════════════════════════ RECEIPT SLICING ═════════════════════════════════════════════════

    /// @notice Returns receipt's origin field
    function origin(Receipt receipt) internal pure returns (uint32) {
        return uint32(receipt.unwrap().indexUint({index_: OFFSET_ORIGIN, bytes_: 4}));
    }

    /// @notice Returns receipt's destination field
    function destination(Receipt receipt) internal pure returns (uint32) {
        return uint32(receipt.unwrap().indexUint({index_: OFFSET_DESTINATION, bytes_: 4}));
    }

    /// @notice Returns receipt's "message hash" field
    function messageHash(Receipt receipt) internal pure returns (bytes32) {
        return receipt.unwrap().index({index_: OFFSET_MESSAGE_HASH, bytes_: 32});
    }

    /// @notice Returns receipt's "snapshot root" field
    function snapshotRoot(Receipt receipt) internal pure returns (bytes32) {
        return receipt.unwrap().index({index_: OFFSET_SNAPSHOT_ROOT, bytes_: 32});
    }

    /// @notice Returns receipt's "state index" field
    function stateIndex(Receipt receipt) internal pure returns (uint8) {
        return uint8(receipt.unwrap().indexUint({index_: OFFSET_STATE_INDEX, bytes_: 1}));
    }

    /// @notice Returns receipt's "attestation notary" field
    function attNotary(Receipt receipt) internal pure returns (address) {
        return receipt.unwrap().indexAddress({index_: OFFSET_ATT_NOTARY});
    }

    /// @notice Returns receipt's "first executor" field
    function firstExecutor(Receipt receipt) internal pure returns (address) {
        return receipt.unwrap().indexAddress({index_: OFFSET_FIRST_EXECUTOR});
    }

    /// @notice Returns receipt's "final executor" field
    function finalExecutor(Receipt receipt) internal pure returns (address) {
        return receipt.unwrap().indexAddress({index_: OFFSET_FINAL_EXECUTOR});
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {State, StateLib} from "./State.sol";
import {MemView, MemViewLib} from "./MemView.sol";
import {SNAPSHOT_MAX_STATES, SNAPSHOT_VALID_SALT, SNAPSHOT_TREE_HEIGHT, STATE_LENGTH} from "../Constants.sol";
import {IncorrectStatesAmount, IndexOutOfRange, UnformattedSnapshot} from "../Errors.sol";
import {MerkleMath} from "../merkle/MerkleMath.sol";
import {GasDataLib, ChainGas} from "../stack/GasData.sol";

/// Snapshot is a memory view over a formatted snapshot payload: a list of states.
type Snapshot is uint256;

using SnapshotLib for Snapshot global;

/// # Snapshot
/// Snapshot structure represents the state of multiple Origin contracts deployed on multiple chains.
/// In short, snapshot is a list of "State" structs. See State.sol for details about the "State" structs.
///
/// ## Snapshot usage
/// - Both Guards and Notaries are supposed to form snapshots and sign `snapshot.hash()` to verify its validity.
/// - Each Guard should be monitoring a set of Origin contracts chosen as they see fit.
///   - They are expected to form snapshots with Origin states for this set of chains,
///   sign and submit them to Summit contract.
/// - Notaries are expected to monitor the Summit contract for new snapshots submitted by the Guards.
///   - They should be forming their own snapshots using states from snapshots of any of the Guards.
///   - The states for the Notary snapshots don't have to come from the same Guard snapshot,
///   or don't even have to be submitted by the same Guard.
/// - With their signature, Notary effectively "notarizes" the work that some Guards have done in Summit contract.
///   - Notary signature on a snapshot doesn't only verify the validity of the Origins, but also serves as
///   a proof of liveliness for Guards monitoring these Origins.
///
/// ## Snapshot validity
/// - Snapshot is considered "valid" in Origin, if every state referring to that Origin is valid there.
/// - Snapshot is considered "globally valid", if it is "valid" in every Origin contract.
///
/// # Snapshot memory layout
///
/// | Position   | Field       | Type  | Bytes | Description                  |
/// | ---------- | ----------- | ----- | ----- | ---------------------------- |
/// | [000..050) | states[0]   | bytes | 50    | Origin State with index==0   |
/// | [050..100) | states[1]   | bytes | 50    | Origin State with index==1   |
/// | ...        | ...         | ...   | 50    | ...                          |
/// | [AAA..BBB) | states[N-1] | bytes | 50    | Origin State with index==N-1 |
///
/// @dev Snapshot could be signed by both Guards and Notaries and submitted to `Summit` in order to produce Attestations
/// that could be used in ExecutionHub for proving the messages coming from origin chains that the snapshot refers to.
library SnapshotLib {
    using MemViewLib for bytes;
    using StateLib for MemView;

    // ═════════════════════════════════════════════════ SNAPSHOT ══════════════════════════════════════════════════════

    /**
     * @notice Returns a formatted Snapshot payload using a list of States.
     * @param states    Arrays of State-typed memory views over Origin states
     * @return Formatted snapshot
     */
    function formatSnapshot(State[] memory states) internal view returns (bytes memory) {
        if (!_isValidAmount(states.length)) revert IncorrectStatesAmount();
        // First we unwrap State-typed views into untyped memory views
        uint256 length = states.length;
        MemView[] memory views = new MemView[](length);
        for (uint256 i = 0; i < length; ++i) {
            views[i] = states[i].unwrap();
        }
        // Finally, we join them in a single payload. This avoids doing unnecessary copies in the process.
        return MemViewLib.join(views);
    }

    /**
     * @notice Returns a Snapshot view over for the given payload.
     * @dev Will revert if the payload is not a snapshot payload.
     */
    function castToSnapshot(bytes memory payload) internal pure returns (Snapshot) {
        return castToSnapshot(payload.ref());
    }

    /**
     * @notice Casts a memory view to a Snapshot view.
     * @dev Will revert if the memory view is not over a snapshot payload.
     */
    function castToSnapshot(MemView memView) internal pure returns (Snapshot) {
        if (!isSnapshot(memView)) revert UnformattedSnapshot();
        return Snapshot.wrap(MemView.unwrap(memView));
    }

    /**
     * @notice Checks that a payload is a formatted Snapshot.
     */
    function isSnapshot(MemView memView) internal pure returns (bool) {
        // Snapshot needs to have exactly N * STATE_LENGTH bytes length
        // N needs to be in [1 .. SNAPSHOT_MAX_STATES] range
        uint256 length = memView.len();
        uint256 statesAmount_ = length / STATE_LENGTH;
        return statesAmount_ * STATE_LENGTH == length && _isValidAmount(statesAmount_);
    }

    /// @notice Returns the hash of a Snapshot, that could be later signed by an Agent  to signal
    /// that the snapshot is valid.
    function hashValid(Snapshot snapshot) internal pure returns (bytes32 hashedSnapshot) {
        // The final hash to sign is keccak(snapshotSalt, keccak(snapshot))
        return snapshot.unwrap().keccakSalted(SNAPSHOT_VALID_SALT);
    }

    /// @notice Convenience shortcut for unwrapping a view.
    function unwrap(Snapshot snapshot) internal pure returns (MemView) {
        return MemView.wrap(Snapshot.unwrap(snapshot));
    }

    // ═════════════════════════════════════════════ SNAPSHOT SLICING ══════════════════════════════════════════════════

    /// @notice Returns a state with a given index from the snapshot.
    function state(Snapshot snapshot, uint256 stateIndex) internal pure returns (State) {
        MemView memView = snapshot.unwrap();
        uint256 indexFrom = stateIndex * STATE_LENGTH;
        if (indexFrom >= memView.len()) revert IndexOutOfRange();
        return memView.slice({index_: indexFrom, len_: STATE_LENGTH}).castToState();
    }

    /// @notice Returns the amount of states in the snapshot.
    function statesAmount(Snapshot snapshot) internal pure returns (uint256) {
        // Each state occupies exactly `STATE_LENGTH` bytes
        return snapshot.unwrap().len() / STATE_LENGTH;
    }

    /// @notice Extracts the list of ChainGas structs from the snapshot.
    function snapGas(Snapshot snapshot) internal pure returns (ChainGas[] memory snapGas_) {
        uint256 statesAmount_ = snapshot.statesAmount();
        snapGas_ = new ChainGas[](statesAmount_);
        for (uint256 i = 0; i < statesAmount_; ++i) {
            State state_ = snapshot.state(i);
            snapGas_[i] = GasDataLib.encodeChainGas(state_.gasData(), state_.origin());
        }
    }

    // ═════════════════════════════════════════ SNAPSHOT ROOT CALCULATION ═════════════════════════════════════════════

    /// @notice Returns the root for the "Snapshot Merkle Tree" composed of state leafs from the snapshot.
    function calculateRoot(Snapshot snapshot) internal pure returns (bytes32) {
        uint256 statesAmount_ = snapshot.statesAmount();
        bytes32[] memory hashes = new bytes32[](statesAmount_);
        for (uint256 i = 0; i < statesAmount_; ++i) {
            // Each State has two sub-leafs, which are used as the "leafs" in "Snapshot Merkle Tree"
            // We save their parent in order to calculate the root for the whole tree later
            hashes[i] = snapshot.state(i).leaf();
        }
        // We are subtracting one here, as we already calculated the hashes
        // for the tree level above the "leaf level".
        MerkleMath.calculateRoot(hashes, SNAPSHOT_TREE_HEIGHT - 1);
        // hashes[0] now stores the value for the Merkle Root of the list
        return hashes[0];
    }

    /// @notice Reconstructs Snapshot merkle Root from State Merkle Data (root + origin domain)
    /// and proof of inclusion of State Merkle Data (aka State "left sub-leaf") in Snapshot Merkle Tree.
    /// > Reverts if any of these is true:
    /// > - State index is out of range.
    /// > - Snapshot Proof length exceeds Snapshot tree Height.
    /// @param originRoot    Root of Origin Merkle Tree
    /// @param domain        Domain of Origin chain
    /// @param snapProof     Proof of inclusion of State Merkle Data into Snapshot Merkle Tree
    /// @param stateIndex    Index of Origin State in the Snapshot
    function proofSnapRoot(bytes32 originRoot, uint32 domain, bytes32[] memory snapProof, uint256 stateIndex)
        internal
        pure
        returns (bytes32)
    {
        // Index of "leftLeaf" is twice the state position in the snapshot
        uint256 leftLeafIndex = stateIndex << 1;
        // Check that "leftLeaf" index fits into Snapshot Merkle Tree
        if (leftLeafIndex >= (1 << SNAPSHOT_TREE_HEIGHT)) revert IndexOutOfRange();
        // Reconstruct left sub-leaf of the Origin State: (originRoot, originDomain)
        bytes32 leftLeaf = StateLib.leftLeaf(originRoot, domain);
        // Reconstruct snapshot root using proof of inclusion
        // This will revert if snapshot proof length exceeds Snapshot Tree Height
        return MerkleMath.proofRoot(leftLeafIndex, leftLeaf, snapProof, SNAPSHOT_TREE_HEIGHT);
    }

    // ══════════════════════════════════════════════ PRIVATE HELPERS ══════════════════════════════════════════════════

    /// @dev Checks if snapshot's states amount is valid.
    function _isValidAmount(uint256 statesAmount_) internal pure returns (bool) {
        // Need to have at least one state in a snapshot.
        // Also need to have no more than `SNAPSHOT_MAX_STATES` states in a snapshot.
        return statesAmount_ != 0 && statesAmount_ <= SNAPSHOT_MAX_STATES;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    AgentNotActive,
    AgentNotFraudulent,
    AgentNotUnstaking,
    AgentNotActiveNorUnstaking,
    AgentUnknown
} from "../libs/Errors.sol";

// Here we define common enums and structures to enable their easier reusing later.

// ═══════════════════════════════ AGENT STATUS ════════════════════════════════

/// @dev Potential statuses for the off-chain bonded agent:
/// - Unknown: never provided a bond => signature not valid
/// - Active: has a bond in BondingManager => signature valid
/// - Unstaking: has a bond in BondingManager, initiated the unstaking => signature not valid
/// - Resting: used to have a bond in BondingManager, successfully unstaked => signature not valid
/// - Fraudulent: proven to commit fraud, value in Merkle Tree not updated => signature not valid
/// - Slashed: proven to commit fraud, value in Merkle Tree was updated => signature not valid
/// Unstaked agent could later be added back to THE SAME domain by staking a bond again.
/// Honest agent: Unknown -> Active -> unstaking -> Resting -> Active ...
/// Malicious agent: Unknown -> Active -> Fraudulent -> Slashed
/// Malicious agent: Unknown -> Active -> Unstaking -> Fraudulent -> Slashed
enum AgentFlag {
    Unknown,
    Active,
    Unstaking,
    Resting,
    Fraudulent,
    Slashed
}

/// @notice Struct for storing an agent in the BondingManager contract.
struct AgentStatus {
    AgentFlag flag;
    uint32 domain;
    uint32 index;
}
// 184 bits available for tight packing

using StructureUtils for AgentStatus global;

/// @notice Potential statuses of an agent in terms of being in dispute
/// - None: agent is not in dispute
/// - Pending: agent is in unresolved dispute
/// - Slashed: agent was in dispute that lead to agent being slashed
/// Note: agent who won the dispute has their status reset to None
enum DisputeFlag {
    None,
    Pending,
    Slashed
}

// ════════════════════════════════ DESTINATION ════════════════════════════════

/// @notice Struct representing the status of Destination contract.
/// @param snapRootTime     Timestamp when latest snapshot root was accepted
/// @param agentRootTime    Timestamp when latest agent root was accepted
/// @param notaryIndex      Index of Notary who signed the latest agent root
struct DestinationStatus {
    uint40 snapRootTime;
    uint40 agentRootTime;
    uint32 notaryIndex;
}

// ═══════════════════════════════ EXECUTION HUB ═══════════════════════════════

/// @notice Potential statuses of the message in Execution Hub.
/// - None: there hasn't been a valid attempt to execute the message yet
/// - Failed: there was a valid attempt to execute the message, but recipient reverted
/// - Success: there was a valid attempt to execute the message, and recipient did not revert
/// Note: message can be executed until its status is Success
enum MessageStatus {
    None,
    Failed,
    Success
}

library StructureUtils {
    /// @notice Checks that Agent is Active
    function verifyActive(AgentStatus memory status) internal pure {
        if (status.flag != AgentFlag.Active) {
            revert AgentNotActive();
        }
    }

    /// @notice Checks that Agent is Unstaking
    function verifyUnstaking(AgentStatus memory status) internal pure {
        if (status.flag != AgentFlag.Unstaking) {
            revert AgentNotUnstaking();
        }
    }

    /// @notice Checks that Agent is Active or Unstaking
    function verifyActiveUnstaking(AgentStatus memory status) internal pure {
        if (status.flag != AgentFlag.Active && status.flag != AgentFlag.Unstaking) {
            revert AgentNotActiveNorUnstaking();
        }
    }

    /// @notice Checks that Agent is Fraudulent
    function verifyFraudulent(AgentStatus memory status) internal pure {
        if (status.flag != AgentFlag.Fraudulent) {
            revert AgentNotFraudulent();
        }
    }

    /// @notice Checks that Agent is not Unknown
    function verifyKnown(AgentStatus memory status) internal pure {
        if (status.flag == AgentFlag.Unknown) {
            revert AgentUnknown();
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {TIPS_GRANULARITY} from "../Constants.sol";
import {TipsOverflow, TipsValueTooLow} from "../Errors.sol";

/// Tips is encoded data with "tips paid for sending a base message".
/// Note: even though uint256 is also an underlying type for MemView, Tips is stored ON STACK.
type Tips is uint256;

using TipsLib for Tips global;

/// # Tips
/// Library for formatting _the tips part_ of _the base messages_.
///
/// ## How the tips are awarded
/// Tips are paid for sending a base message, and are split across all the agents that
/// made the message execution on destination chain possible.
/// ### Summit tips
/// Split between:
///     - Guard posting a snapshot with state ST_G for the origin chain.
///     - Notary posting a snapshot SN_N using ST_G. This creates attestation A.
///     - Notary posting a message receipt after it is executed on destination chain.
/// ### Attestation tips
/// Paid to:
///     - Notary posting attestation A to destination chain.
/// ### Execution tips
/// Paid to:
///     - First executor performing a valid execution attempt (correct proofs, optimistic period over),
///      using attestation A to prove message inclusion on origin chain, whether the recipient reverted or not.
/// ### Delivery tips.
/// Paid to:
///     - Executor who successfully executed the message on destination chain.
///
/// ## Tips encoding
/// - Tips occupy a single storage word, and thus are stored on stack instead of being stored in memory.
/// - The actual tip values should be determined by multiplying stored values by divided by TIPS_MULTIPLIER=2**32.
/// - Tips are packed into a single word of storage, while allowing real values up to ~8*10**28 for every tip category.
/// > The only downside is that the "real tip values" are now multiplies of ~4*10**9, which should be fine even for
/// the chains with the most expensive gas currency.
/// # Tips stack layout (from highest bits to lowest)
///
/// | Position   | Field          | Type   | Bytes | Description                                                |
/// | ---------- | -------------- | ------ | ----- | ---------------------------------------------------------- |
/// | (032..024] | summitTip      | uint64 | 8     | Tip for agents interacting with Summit contract            |
/// | (024..016] | attestationTip | uint64 | 8     | Tip for Notary posting attestation to Destination contract |
/// | (016..008] | executionTip   | uint64 | 8     | Tip for valid execution attempt on destination chain       |
/// | (008..000] | deliveryTip    | uint64 | 8     | Tip for successful message delivery on destination chain   |

library TipsLib {
    /// @dev Amount of bits to shift to summitTip field
    uint256 private constant SHIFT_SUMMIT_TIP = 24 * 8;
    /// @dev Amount of bits to shift to attestationTip field
    uint256 private constant SHIFT_ATTESTATION_TIP = 16 * 8;
    /// @dev Amount of bits to shift to executionTip field
    uint256 private constant SHIFT_EXECUTION_TIP = 8 * 8;

    // ═══════════════════════════════════════════════════ TIPS ════════════════════════════════════════════════════════

    /// @notice Returns encoded tips with the given fields
    /// @param summitTip_        Tip for agents interacting with Summit contract, divided by TIPS_MULTIPLIER
    /// @param attestationTip_   Tip for Notary posting attestation to Destination contract, divided by TIPS_MULTIPLIER
    /// @param executionTip_     Tip for valid execution attempt on destination chain, divided by TIPS_MULTIPLIER
    /// @param deliveryTip_      Tip for successful message delivery on destination chain, divided by TIPS_MULTIPLIER
    function encodeTips(uint64 summitTip_, uint64 attestationTip_, uint64 executionTip_, uint64 deliveryTip_)
        internal
        pure
        returns (Tips)
    {
        return Tips.wrap(
            uint256(summitTip_) << SHIFT_SUMMIT_TIP | uint256(attestationTip_) << SHIFT_ATTESTATION_TIP
                | uint256(executionTip_) << SHIFT_EXECUTION_TIP | uint256(deliveryTip_)
        );
    }

    /// @notice Convenience function to encode tips with uint256 values.
    function encodeTips256(uint256 summitTip_, uint256 attestationTip_, uint256 executionTip_, uint256 deliveryTip_)
        internal
        pure
        returns (Tips)
    {
        return encodeTips({
            summitTip_: uint64(summitTip_ >> TIPS_GRANULARITY),
            attestationTip_: uint64(attestationTip_ >> TIPS_GRANULARITY),
            executionTip_: uint64(executionTip_ >> TIPS_GRANULARITY),
            deliveryTip_: uint64(deliveryTip_ >> TIPS_GRANULARITY)
        });
    }

    /// @notice Wraps the padded encoded tips into a Tips-typed value.
    /// @dev There is no actual padding here, as the underlying type is already uint256,
    /// but we include this function for consistency and to be future-proof, if tips will eventually use anything
    /// smaller than uint256.
    function wrapPadded(uint256 paddedTips) internal pure returns (Tips) {
        return Tips.wrap(paddedTips);
    }

    /**
     * @notice Returns a formatted Tips payload specifying empty tips.
     * @return Formatted tips
     */
    function emptyTips() internal pure returns (Tips) {
        return Tips.wrap(0);
    }

    /// @notice Returns tips's hash: a leaf to be inserted in the "Message mini-Merkle tree".
    function leaf(Tips tips) internal pure returns (bytes32 hashedTips) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Store tips in scratch space
            mstore(0, tips)
            // Compute hash of tips padded to 32 bytes
            hashedTips := keccak256(0, 32)
        }
    }

    // ═══════════════════════════════════════════════ TIPS SLICING ════════════════════════════════════════════════════

    /// @notice Returns summitTip field
    function summitTip(Tips tips) internal pure returns (uint64) {
        // Casting to uint64 will truncate the highest bits, which is the behavior we want
        return uint64(Tips.unwrap(tips) >> SHIFT_SUMMIT_TIP);
    }

    /// @notice Returns attestationTip field
    function attestationTip(Tips tips) internal pure returns (uint64) {
        // Casting to uint64 will truncate the highest bits, which is the behavior we want
        return uint64(Tips.unwrap(tips) >> SHIFT_ATTESTATION_TIP);
    }

    /// @notice Returns executionTip field
    function executionTip(Tips tips) internal pure returns (uint64) {
        // Casting to uint64 will truncate the highest bits, which is the behavior we want
        return uint64(Tips.unwrap(tips) >> SHIFT_EXECUTION_TIP);
    }

    /// @notice Returns deliveryTip field
    function deliveryTip(Tips tips) internal pure returns (uint64) {
        // Casting to uint64 will truncate the highest bits, which is the behavior we want
        return uint64(Tips.unwrap(tips));
    }

    // ════════════════════════════════════════════════ TIPS VALUE ═════════════════════════════════════════════════════

    /// @notice Returns total value of the tips payload.
    /// This is the sum of the encoded values, scaled up by TIPS_MULTIPLIER
    function value(Tips tips) internal pure returns (uint256 value_) {
        value_ = uint256(tips.summitTip()) + tips.attestationTip() + tips.executionTip() + tips.deliveryTip();
        value_ <<= TIPS_GRANULARITY;
    }

    /// @notice Increases the delivery tip to match the new value.
    function matchValue(Tips tips, uint256 newValue) internal pure returns (Tips newTips) {
        uint256 oldValue = tips.value();
        if (newValue < oldValue) revert TipsValueTooLow();
        // We want to increase the delivery tip, while keeping the other tips the same
        unchecked {
            uint256 delta = (newValue - oldValue) >> TIPS_GRANULARITY;
            // `delta` fits into uint224, as TIPS_GRANULARITY is 32, so this never overflows uint256.
            // In practice, this will never overflow uint64 as well, but we still check it just in case.
            if (delta + tips.deliveryTip() > type(uint64).max) revert TipsOverflow();
            // Delivery tips occupy lowest 8 bytes, so we can just add delta to the tips value
            // to effectively increase the delivery tip (knowing that delta fits into uint64).
            newTips = Tips.wrap(Tips.unwrap(tips) + delta);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// ══════════════════════════════ LIBRARY IMPORTS ══════════════════════════════
import {CallerNotAgentManager, CallerNotInbox} from "../libs/Errors.sol";
import {AgentStatus, DisputeFlag} from "../libs/Structures.sol";
// ═════════════════════════════ INTERNAL IMPORTS ══════════════════════════════
import {IAgentManager} from "../interfaces/IAgentManager.sol";
import {IAgentSecured} from "../interfaces/IAgentSecured.sol";
import {MessagingBase} from "./MessagingBase.sol";

/**
 * @notice Base contract for messaging contracts that are secured by the agent manager.
 * `AgentSecured` relies on `AgentManager` to provide the following functionality:
 * - Keep track of agents and their statuses.
 * - Pass agent-signed statements that were verified by the agent manager.
 * - These statements are considered valid indefinitely, unless the agent is disputed.
 * - Disputes are opened and resolved by the agent manager.
 * > `AgentSecured` implementation should never use statements signed by agents that are disputed.
 */
abstract contract AgentSecured is MessagingBase, IAgentSecured {
    // ════════════════════════════════════════════════ IMMUTABLES ═════════════════════════════════════════════════════

    /// @inheritdoc IAgentSecured
    address public immutable agentManager;

    /// @inheritdoc IAgentSecured
    address public immutable inbox;

    // ══════════════════════════════════════════════════ STORAGE ══════════════════════════════════════════════════════

    // (agent index => their dispute flag: None/Pending/Slashed)
    mapping(uint32 => DisputeFlag) internal _disputes;

    /// @dev gap for upgrade safety
    uint256[49] private __GAP; // solhint-disable-line var-name-mixedcase

    modifier onlyAgentManager() {
        if (msg.sender != agentManager) revert CallerNotAgentManager();
        _;
    }

    modifier onlyInbox() {
        if (msg.sender != inbox) revert CallerNotInbox();
        _;
    }

    constructor(string memory version_, uint32 localDomain_, address agentManager_, address inbox_)
        MessagingBase(version_, localDomain_)
    {
        agentManager = agentManager_;
        inbox = inbox_;
    }

    // ════════════════════════════════════════════ ONLY AGENT MANAGER ═════════════════════════════════════════════════

    /// @inheritdoc IAgentSecured
    function openDispute(uint32 guardIndex, uint32 notaryIndex) external onlyAgentManager {
        _disputes[guardIndex] = DisputeFlag.Pending;
        _disputes[notaryIndex] = DisputeFlag.Pending;
    }

    /// @inheritdoc IAgentSecured
    function resolveDispute(uint32 slashedIndex, uint32 honestIndex) external onlyAgentManager {
        _disputes[slashedIndex] = DisputeFlag.Slashed;
        if (honestIndex != 0) delete _disputes[honestIndex];
    }

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @inheritdoc IAgentSecured
    function agentStatus(address agent) external view returns (AgentStatus memory) {
        return _agentStatus(agent);
    }

    /// @inheritdoc IAgentSecured
    function getAgent(uint256 index) external view returns (address agent, AgentStatus memory status) {
        return _getAgent(index);
    }

    // ══════════════════════════════════════════════ INTERNAL VIEWS ═══════════════════════════════════════════════════

    /// @dev Returns status of the given agent: (flag, domain, index).
    function _agentStatus(address agent) internal view returns (AgentStatus memory) {
        return IAgentManager(agentManager).agentStatus(agent);
    }

    /// @dev Returns agent and their status for a given agent index. Returns zero values for non existing indexes.
    function _getAgent(uint256 index) internal view returns (address agent, AgentStatus memory status) {
        return IAgentManager(agentManager).getAgent(index);
    }

    /// @dev Checks if the agent with the given index is in a dispute.
    function _isInDispute(uint32 agentIndex) internal view returns (bool) {
        return _disputes[agentIndex] != DisputeFlag.None;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @notice A collection of events emitted by the Summit contract
abstract contract SummitEvents {
    /**
     * @notice Emitted when a tip is awarded to the actor, whether they are bonded or unbonded actor.
     * @param actor     Actor address
     * @param origin    Domain where tips were originally paid
     * @param tip       Tip value, scaled down by TIPS_MULTIPLIER
     */
    event TipAwarded(address actor, uint32 origin, uint256 tip);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {AgentStatus, DisputeFlag} from "../libs/Structures.sol";

interface IAgentManager {
    /**
     * @notice Allows Inbox to open a Dispute between a Guard and a Notary, if they are both not in Dispute already.
     * > Will revert if any of these is true:
     * > - Caller is not Inbox.
     * > - Guard or Notary is already in Dispute.
     * @param guardIndex    Index of the Guard in the Agent Merkle Tree
     * @param notaryIndex   Index of the Notary in the Agent Merkle Tree
     */
    function openDispute(uint32 guardIndex, uint32 notaryIndex) external;

    /**
     * @notice Allows contract owner to resolve a stuck Dispute.
     * This could only be called if no fresh data has been submitted by the Notaries to the Inbox,
     * which is required for the Dispute to be resolved naturally.
     * > Will revert if any of these is true:
     * > - Caller is not contract owner.
     * > - Domain doesn't match the saved agent domain.
     * > - `slashedAgent` is not in Dispute.
     * > - Less than `FRESH_DATA_TIMEOUT` has passed since the last Notary submission to the Inbox.
     * @param slashedAgent  Agent that is being slashed
     */
    function resolveStuckDispute(uint32 domain, address slashedAgent) external;

    /**
     * @notice Allows Inbox to slash an agent, if their fraud was proven.
     * > Will revert if any of these is true:
     * > - Caller is not Inbox.
     * > - Domain doesn't match the saved agent domain.
     * @param domain    Domain where the Agent is active
     * @param agent     Address of the Agent
     * @param prover    Address that initially provided fraud proof
     */
    function slashAgent(uint32 domain, address agent, address prover) external;

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /**
     * @notice Returns the latest known root of the Agent Merkle Tree.
     */
    function agentRoot() external view returns (bytes32);

    /**
     * @notice Returns (flag, domain, index) for a given agent. See Structures.sol for details.
     * @dev Will return AgentFlag.Fraudulent for agents that have been proven to commit fraud,
     * but their status is not updated to Slashed yet.
     * @param agent     Agent address
     * @return          Status for the given agent: (flag, domain, index).
     */
    function agentStatus(address agent) external view returns (AgentStatus memory);

    /**
     * @notice Returns agent address and their current status for a given agent index.
     * @dev Will return empty values if agent with given index doesn't exist.
     * @param index     Agent index in the Agent Merkle Tree
     * @return agent    Agent address
     * @return status   Status for the given agent: (flag, domain, index)
     */
    function getAgent(uint256 index) external view returns (address agent, AgentStatus memory status);

    /**
     * @notice Returns the number of opened Disputes.
     * @dev This includes the Disputes that have been resolved already.
     */
    function getDisputesAmount() external view returns (uint256);

    /**
     * @notice Returns information about the dispute with the given index.
     * @dev Will revert if dispute with given index hasn't been opened yet.
     * @param index             Dispute index
     * @return guard            Address of the Guard in the Dispute
     * @return notary           Address of the Notary in the Dispute
     * @return slashedAgent     Address of the Agent who was slashed when Dispute was resolved
     * @return fraudProver      Address who provided fraud proof to resolve the Dispute
     * @return reportPayload    Raw payload with report data that led to the Dispute
     * @return reportSignature  Guard signature for the report payload
     */
    function getDispute(uint256 index)
        external
        view
        returns (
            address guard,
            address notary,
            address slashedAgent,
            address fraudProver,
            bytes memory reportPayload,
            bytes memory reportSignature
        );

    /**
     * @notice Returns the current Dispute status of a given agent. See Structures.sol for details.
     * @dev Every returned value will be set to zero if agent was not slashed and is not in Dispute.
     * `rival` and `disputePtr` will be set to zero if the agent was slashed without being in Dispute.
     * @param agent         Agent address
     * @return flag         Flag describing the current Dispute status for the agent: None/Pending/Slashed
     * @return rival        Address of the rival agent in the Dispute
     * @return fraudProver  Address who provided fraud proof to resolve the Dispute
     * @return disputePtr   Index of the opened Dispute PLUS ONE. Zero if agent is not in Dispute.
     */
    function disputeStatus(address agent)
        external
        view
        returns (DisputeFlag flag, address rival, address fraudProver, uint256 disputePtr);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface InterfaceBondingManager {
    // ═══════════════════════════════════════════════ AGENTS LOGIC ════════════════════════════════════════════════════

    /**
     * @notice Adds a new agent for the domain. This is either a fresh address (Inactive),
     * or an agent who used to be active on the same domain before (Resting).
     * @dev Inactive: `proof` should be the proof of inclusion of an empty leaf
     * having index following the last added agent in the tree.
     * @dev Resting: `proof` should be the proof of inclusion of the agent leaf
     * with Resting flag having index previously assigned to the agent.
     * @param domain    Domain where the Agent will be active
     * @param agent     Address of the Agent
     * @param proof     Merkle proof of the Inactive/Resting status for the agent
     */
    function addAgent(uint32 domain, address agent, bytes32[] memory proof) external;

    /**
     * @notice Initiates the unstaking of the agent bond. Agent signature is immediately no longer
     * considered valid on Synapse Chain, and will be invalid on other chains once the Light Manager
     * updates their agent merkle root on these chains.
     * @dev `proof` should be the proof of inclusion of the agent leaf
     * with Active flag having index previously assigned to the agent.
     * @param domain    Domain where the Agent is active
     * @param agent     Address of the Agent
     * @param proof     Merkle proof of the Active status for the agent
     */
    function initiateUnstaking(uint32 domain, address agent, bytes32[] memory proof) external;

    /**
     * @notice Completes the unstaking of the agent bond. Agent signature is no longer considered
     * valid on any of the chains.
     * @dev `proof` should be the proof of inclusion of the agent leaf
     * with Unstaking flag having index previously assigned to the agent.
     * @param domain    Domain where the Agent was active
     * @param agent     Address of the Agent
     * @param proof     Merkle proof of the unstaking status for the agent
     */
    function completeUnstaking(uint32 domain, address agent, bytes32[] memory proof) external;

    /**
     * @notice Completes the slashing of the agent bond. Agent signature is no longer considered
     * valid under the updated Agent Merkle Root.
     * @dev `proof` should be the proof of inclusion of the agent leaf
     * with Active/Unstaking flag having index previously assigned to the agent.
     * @param domain    Domain where the Agent was active
     * @param agent     Address of the Agent
     * @param proof     Merkle proof of the active/unstaking status for the agent
     */
    function completeSlashing(uint32 domain, address agent, bytes32[] memory proof) external;

    /**
     * @notice Remote AgentManager should call this function to indicate that the agent
     * has been proven to commit fraud on the origin chain.
     * @dev This initiates the process of agent slashing. It could be immediately
     * completed by anyone calling completeSlashing() providing a correct merkle proof
     * for the OLD agent status.
     * Note: as an extra security check this function returns its own selector, so that
     * Destination could verify that a "remote" function was called when executing a manager message.
     * @param domain        Domain where the slashed agent was active
     * @param agent         Address of the slashed Agent
     * @param prover        Address that initially provided fraud proof to remote AgentManager
     * @return magicValue   Selector of this function
     */
    function remoteSlashAgent(uint32 msgOrigin, uint256 proofMaturity, uint32 domain, address agent, address prover)
        external
        returns (bytes4 magicValue);

    /**
     * @notice Withdraws locked base message tips from requested domain Origin to the recipient.
     * Issues a call to a local Origin contract, or sends a manager message to the remote chain.
     * @dev Could only be called by the Summit contract.
     * @param recipient     Address to withdraw tips to
     * @param origin        Domain where tips need to be withdrawn
     * @param amount        Tips value to withdraw
     */
    function withdrawTips(address recipient, uint32 origin, uint256 amount) external;

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /**
     * @notice Returns all active agents for a given domain.
     * @param domain    Domain to get agents from (ZERO for Guards)
     * @param agents    List of active agents for the domain
     */
    function getActiveAgents(uint32 domain) external view returns (address[] memory agents);

    /**
     * @notice Returns a leaf representing the current status of agent in the Agent Merkle Tree.
     * @dev Will return an empty leaf, if agent is not added to the tree yet.
     * @param agent     Agent address
     * @return leaf     Agent leaf in the Agent Merkle Tree
     */
    function agentLeaf(address agent) external view returns (bytes32 leaf);

    /**
     * @notice Returns a total amount of leafs representing known agents.
     * @dev This includes active, unstaking, resting and slashed agents.
     * This also includes an empty leaf as the very first entry.
     */
    function leafsAmount() external view returns (uint256 amount);

    /**
     * @notice Returns a full list of leafs from the Agent Merkle Tree.
     * @dev This might consume a lot of gas, do not use this on-chain.
     */
    function allLeafs() external view returns (bytes32[] memory leafs);

    /**
     * @notice Returns a list of leafs from the Agent Merkle Tree
     * with indexes [indexFrom .. indexFrom + amount).
     * @dev This might consume a lot of gas, do not use this on-chain.
     * @dev Will return less than `amount` entries, if indexFrom + amount > leafsAmount
     */
    function getLeafs(uint256 indexFrom, uint256 amount) external view returns (bytes32[] memory leafs);

    /**
     * @notice Returns a proof of inclusion of the agent in the Agent Merkle Tree.
     * @dev Will return a proof for an empty leaf, if agent is not added to the tree yet.
     * This proof could be used by ANY next new agent that calls {addAgent}.
     * @dev This WILL consume a lot of gas, do not use this on-chain.
     * @dev The alternative way to create a proof is to fetch the full list of leafs using
     * either {allLeafs} or {getLeafs}, and create a merkle proof from that.
     * @param agent     Agent address
     * @return proof    Merkle proof for the agent
     */
    function getProof(address agent) external view returns (bytes32[] memory proof);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {AgentStatus} from "../libs/Structures.sol";

interface InterfaceSummit {
    // ══════════════════════════════════════════ ACCEPT AGENT STATEMENTS ══════════════════════════════════════════════

    /**
     * @notice Accepts a receipt, which local `AgentManager` verified to have been signed by an active Notary.
     * > Receipt is a statement about message execution status on the remote chain.
     * - This will distribute the message tips across the off-chain actors once the receipt optimistic period is over.
     * - Notary who signed the receipt is referenced as the "Receipt Notary".
     * - Notary who signed the attestation on destination chain is referenced as the "Attestation Notary".
     * > Will revert if any of these is true:
     * > - Called by anyone other than local `AgentManager`.
     * > - Receipt body payload is not properly formatted.
     * > - Receipt signer is in Dispute.
     * > - Receipt's snapshot root is unknown.
     * @param rcptNotaryIndex   Index of Receipt Notary in Agent Merkle Tree
     * @param attNotaryIndex    Index of Attestation Notary in Agent Merkle Tree
     * @param sigIndex          Index of stored Notary signature
     * @param attNonce          Nonce of the attestation used for proving the executed message
     * @param paddedTips        Padded encoded paid tips information
     * @param rcptPayload       Raw payload with message execution receipt
     * @return wasAccepted      Whether the receipt was accepted
     */
    function acceptReceipt(
        uint32 rcptNotaryIndex,
        uint32 attNotaryIndex,
        uint256 sigIndex,
        uint32 attNonce,
        uint256 paddedTips,
        bytes memory rcptPayload
    ) external returns (bool wasAccepted);

    /**
     * @notice Accepts a snapshot, which local `AgentManager` verified to have been signed by an active Guard.
     * > Snapshot is a list of states for a set of Origin contracts residing on any of the chains.
     * All the states in the Guard-signed snapshot become available for Notary signing.
     * > Will revert if any of these is true:
     * > - Called by anyone other than local `AgentManager`.
     * > - Snapshot payload is not properly formatted.
     * > - Snapshot contains a state older then the Guard has previously submitted.
     * @param guardIndex        Index of Guard in Agent Merkle Tree
     * @param sigIndex          Index of stored Agent signature
     * @param snapPayload       Raw payload with snapshot data
     */
    function acceptGuardSnapshot(uint32 guardIndex, uint256 sigIndex, bytes memory snapPayload) external;

    /**
     * @notice Accepts a snapshot, which local `AgentManager` verified to have been signed by an active Notary.
     * > Snapshot is a list of states for a set of Origin contracts residing on any of the chains.
     * Snapshot Merkle Root is calculated and saved for valid snapshots, i.e.
     * snapshots which are only using states previously submitted by any of the Guards.
     * - Notary could use states singed by the same of different Guards in their snapshot.
     * - Notary could then proceed to sign the attestation for their submitted snapshot.
     * > Will revert if any of these is true:
     * > - Called by anyone other than local `AgentManager`.
     * > - Snapshot payload is not properly formatted.
     * > - Snapshot contains a state older then the Notary has previously submitted.
     * > - Snapshot contains a state that no Guard has previously submitted.
     * @param notaryIndex       Index of Notary in Agent Merkle Tree
     * @param sigIndex          Index of stored Agent signature
     * @param agentRoot         Current root of the Agent Merkle Tree
     * @param snapPayload       Raw payload with snapshot data
     * @return attPayload       Raw payload with data for attestation derived from Notary snapshot.
     */
    function acceptNotarySnapshot(uint32 notaryIndex, uint256 sigIndex, bytes32 agentRoot, bytes memory snapPayload)
        external
        returns (bytes memory attPayload);

    // ════════════════════════════════════════════════ TIPS LOGIC ═════════════════════════════════════════════════════

    /**
     * @notice Distributes tips using the first Receipt from the "receipt quarantine queue".
     * Possible scenarios:
     *  - Receipt queue is empty => does nothing
     *  - Receipt optimistic period is not over => does nothing
     *  - Either of Notaries present in Receipt was slashed => receipt is deleted from the queue
     *  - Either of Notaries present in Receipt in Dispute => receipt is moved to the end of queue
     *  - None of the above => receipt tips are distributed
     * @dev Returned value makes it possible to do the following: `while (distributeTips()) {}`
     * @return queuePopped      Whether the first element was popped from the queue
     */
    function distributeTips() external returns (bool queuePopped);

    /**
     * @notice Withdraws locked base message tips from requested domain Origin to the recipient.
     * This is done by a call to a local Origin contract, or by a manager message to the remote chain.
     * @dev This will revert, if the pending balance of origin tips (earned-claimed) is lower than requested.
     * @param origin    Domain of chain to withdraw tips on
     * @param amount    Amount of tips to withdraw
     */
    function withdrawTips(uint32 origin, uint256 amount) external;

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /**
     * @notice Returns earned and claimed tips for the actor.
     * Note: Tips for address(0) belong to the Treasury.
     * @param actor     Address of the actor
     * @param origin    Domain where the tips were initially paid
     * @return earned   Total amount of origin tips the actor has earned so far
     * @return claimed  Total amount of origin tips the actor has claimed so far
     */
    function actorTips(address actor, uint32 origin) external view returns (uint128 earned, uint128 claimed);

    /**
     * @notice Returns the amount of receipts in the "Receipt Quarantine Queue".
     */
    function receiptQueueLength() external view returns (uint256);

    /**
     * @notice Returns the state with the highest known nonce
     * submitted by any of the currently active Guards.
     * @param origin        Domain of origin chain
     * @return statePayload Raw payload with latest active Guard state for origin
     */
    function getLatestState(uint32 origin) external view returns (bytes memory statePayload);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// ══════════════════════════════ LIBRARY IMPORTS ══════════════════════════════
import {Attestation, AttestationLib} from "../libs/memory/Attestation.sol";
import {
    IncorrectAttestation, IncorrectState, IndexOutOfRange, NonceOutOfRange, OutdatedNonce
} from "../libs/Errors.sol";
import {ChainGas, GasData, GasDataLib} from "../libs/stack/GasData.sol";
import {MerkleMath} from "../libs/merkle/MerkleMath.sol";
import {Snapshot, SnapshotLib} from "../libs/memory/Snapshot.sol";
import {State, StateLib} from "../libs/memory/State.sol";
// ═════════════════════════════ INTERNAL IMPORTS ══════════════════════════════
import {AgentSecured} from "../base/AgentSecured.sol";
import {SnapshotHubEvents} from "../events/SnapshotHubEvents.sol";
import {ISnapshotHub} from "../interfaces/ISnapshotHub.sol";
import {IStatementInbox} from "../interfaces/IStatementInbox.sol";

/// @notice `SnapshotHub` is a parent contract for `Summit`. It is responsible for the following:
/// - Accepting and storing Guard and Notary snapshots to keep track of all the remote `Origin` states.
/// - Generating and storing Attestations derived from Notary snapshots, as well as verifying their validity.
abstract contract SnapshotHub is AgentSecured, SnapshotHubEvents, ISnapshotHub {
    using AttestationLib for bytes;
    using StateLib for bytes;

    /// @notice Struct that represents stored State of Origin contract
    /// @param guardIndex   Index of Guard who submitted this State to Summit
    /// @param notaryIndex  Index of Notary who submitted this State to Summit
    struct SummitState {
        bytes32 root;
        uint32 origin;
        uint32 nonce;
        uint40 blockNumber;
        uint40 timestamp;
        GasData gasData;
        uint32 guardIndex;
        uint32 notaryIndex;
    }
    // TODO: revisit packing

    struct SummitSnapshot {
        // TODO: compress this - indexes might as well be uint32/uint64
        uint256[] statePtrs;
        uint256 sigIndex;
    }

    struct SummitAttestation {
        bytes32 snapRoot;
        bytes32 agentRoot;
        bytes32 snapGasHash;
        uint40 blockNumber;
        uint40 timestamp;
    }

    // ══════════════════════════════════════════════════ STORAGE ══════════════════════════════════════════════════════

    /// @dev All States submitted by any of the Guards
    SummitState[] private _states;

    /// @dev All Snapshots submitted by any of the Guards
    SummitSnapshot[] private _guardSnapshots;

    /// @dev All Snapshots submitted by any of the Notaries
    SummitSnapshot[] private _notarySnapshots;

    /// @dev All Attestations created from Notary-submitted Snapshots
    /// Invariant: _attestations.length == _notarySnapshots.length
    SummitAttestation[] private _attestations;

    /// @dev Pointer for the given State Leaf of the origin
    /// with ZERO as a sentinel value for "state not submitted yet".
    // (origin => (stateLeaf => {state index in _states PLUS 1}))
    mapping(uint32 => mapping(bytes32 => uint256)) private _leafPtr;

    /// @dev Pointer for the latest Agent State of a given origin
    /// with ZERO as a sentinel value for "no states submitted yet".
    // (origin => (agent index => {latest state index in _states PLUS 1}))
    mapping(uint32 => mapping(uint32 => uint256)) private _latestStatePtr;

    /// @dev Latest nonce that a Notary created
    // (notary index => latest nonce)
    mapping(uint32 => uint32) private _latestAttNonce;

    /// @dev gap for upgrade safety
    uint256[43] private __GAP; // solhint-disable-line var-name-mixedcase

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @inheritdoc ISnapshotHub
    function isValidAttestation(bytes memory attPayload) external view returns (bool isValid) {
        // This will revert if payload is not a formatted attestation
        Attestation attestation = attPayload.castToAttestation();
        return _isValidAttestation(attestation);
    }

    /// @inheritdoc ISnapshotHub
    function getAttestation(uint32 attNonce)
        external
        view
        returns (bytes memory attPayload, bytes32 agentRoot, uint256[] memory snapGas)
    {
        if (attNonce >= _attestations.length) revert NonceOutOfRange();
        SummitAttestation memory summitAtt = _attestations[attNonce];
        attPayload = _formatSummitAttestation(summitAtt, attNonce);
        agentRoot = summitAtt.agentRoot;
        snapGas = _restoreSnapGas(_notarySnapshots[attNonce]);
    }

    /// @inheritdoc ISnapshotHub
    function getLatestAgentState(uint32 origin, address agent) external view returns (bytes memory stateData) {
        SummitState memory latestState = _latestState(origin, _agentStatus(agent).index);
        if (latestState.nonce == 0) return bytes("");
        return _formatSummitState(latestState);
    }

    /// @inheritdoc ISnapshotHub
    function getLatestNotaryAttestation(address notary)
        external
        view
        returns (bytes memory attPayload, bytes32 agentRoot, uint256[] memory snapGas)
    {
        uint32 latestAttNonce = _latestAttNonce[_agentStatus(notary).index];
        if (latestAttNonce != 0) {
            SummitAttestation memory summitAtt = _attestations[latestAttNonce];
            attPayload = _formatSummitAttestation(summitAtt, latestAttNonce);
            agentRoot = summitAtt.agentRoot;
            snapGas = _restoreSnapGas(_notarySnapshots[latestAttNonce]);
        }
    }

    /// @inheritdoc ISnapshotHub
    function getGuardSnapshot(uint256 index)
        external
        view
        returns (bytes memory snapPayload, bytes memory snapSignature)
    {
        if (index >= _guardSnapshots.length) revert IndexOutOfRange();
        return _restoreSnapshot(_guardSnapshots[index]);
    }

    /// @inheritdoc ISnapshotHub
    function getNotarySnapshot(uint256 index)
        public
        view
        returns (bytes memory snapPayload, bytes memory snapSignature)
    {
        uint256 nonce = index + 1;
        if (nonce >= _notarySnapshots.length) revert IndexOutOfRange();
        return _restoreSnapshot(_notarySnapshots[nonce]);
    }

    /// @inheritdoc ISnapshotHub
    // solhint-disable-next-line ordering
    function getNotarySnapshot(bytes memory attPayload)
        external
        view
        returns (bytes memory snapPayload, bytes memory snapSignature)
    {
        // This will revert if payload is not a formatted attestation
        Attestation attestation = attPayload.castToAttestation();
        if (!_isValidAttestation(attestation)) revert IncorrectAttestation();
        // Attestation is valid => _attestations[nonce] exists
        // _notarySnapshots.length == _attestations.length => _notarySnapshots[nonce] exists
        return _restoreSnapshot(_notarySnapshots[attestation.nonce()]);
    }

    /// @inheritdoc ISnapshotHub
    function getSnapshotProof(uint32 attNonce, uint256 stateIndex) external view returns (bytes32[] memory snapProof) {
        if (attNonce == 0 || attNonce >= _notarySnapshots.length) revert NonceOutOfRange();
        SummitSnapshot memory snap = _notarySnapshots[attNonce];
        uint256 statesAmount = snap.statePtrs.length;
        if (stateIndex >= statesAmount) revert IndexOutOfRange();
        // Reconstruct the leafs of Snapshot Merkle Tree: two for each state
        bytes32[] memory hashes = new bytes32[](2 * statesAmount);
        for (uint256 i = 0; i < statesAmount; ++i) {
            // Get value for "index in _states PLUS 1"
            uint256 statePtr = snap.statePtrs[i];
            // We are never saving zero values when accepting Guard/Notary snapshots, so this holds
            assert(statePtr != 0);
            State state = _formatSummitState(_states[statePtr - 1]).castToState();
            (hashes[2 * i], hashes[2 * i + 1]) = state.subLeafs();
        }
        // Index of State's left leaf is twice the state index
        return MerkleMath.calculateProof(hashes, 2 * stateIndex);
    }

    // ════════════════════════════════════════ INTERNAL LOGIC: ACCEPT DATA ════════════════════════════════════════════

    /// @dev Accepts a Snapshot signed by a Guard.
    /// It is assumed that the Guard signature has been checked outside of this contract.
    function _acceptGuardSnapshot(Snapshot snapshot, uint32 guardIndex, uint256 sigIndex) internal {
        // Snapshot Signer is a Guard: save the states for later use.
        uint256 statesAmount = snapshot.statesAmount();
        uint256[] memory statePtrs = new uint256[](statesAmount);
        for (uint256 i = 0; i < statesAmount; ++i) {
            statePtrs[i] = _saveState(snapshot.state(i), guardIndex);
            // Guard either submitted a fresh state, or reused state submitted by another Guard
            // In any case, the "state pointer" would never be zero
            assert(statePtrs[i] != 0);
        }
        // Save Guard snapshot for later retrieval
        _saveGuardSnapshot(statePtrs, sigIndex);
    }

    /// @dev Accepts a Snapshot signed by a Notary.
    /// It is assumed that the Notary signature has been checked outside of this contract.
    /// Returns the attestation created from the Notary snapshot.
    function _acceptNotarySnapshot(Snapshot snapshot, bytes32 agentRoot, uint32 notaryIndex, uint256 sigIndex)
        internal
        returns (bytes memory attPayload)
    {
        // Snapshot Signer is a Notary: construct a Snapshot Merkle Tree,
        // while checking that the states were previously saved.
        uint256 statesAmount = snapshot.statesAmount();
        uint256[] memory statePtrs = new uint256[](statesAmount);
        for (uint256 i = 0; i < statesAmount; ++i) {
            State state = snapshot.state(i);
            uint256 statePtr = _statePtr(state);
            // Notary can only used states previously submitted by any fo the Guards
            if (statePtr == 0) revert IncorrectState();
            statePtrs[i] = statePtr;
            // Check that Notary hasn't used a fresher state for this origin before
            uint32 origin = state.origin();
            if (state.nonce() <= _latestState(origin, notaryIndex).nonce) revert OutdatedNonce();
            // Save Notary if they are the first to use this state
            if (_states[statePtr - 1].notaryIndex == 0) _states[statePtr - 1].notaryIndex = notaryIndex;
            // Update Notary latest state for origin
            _latestStatePtr[origin][notaryIndex] = statePtrs[i];
        }
        // Derive the snapshot merkle root and save it for a Notary attestation.
        // Save Notary snapshot for later retrieval
        return _saveNotarySnapshot(snapshot, statePtrs, agentRoot, notaryIndex, sigIndex);
    }

    // ════════════════════════════════════ INTERNAL LOGIC: SAVE STATEMENT DATA ════════════════════════════════════════

    /// @dev Initializes the saved _attestations list by inserting empty values.
    function _initializeAttestations() internal {
        // This should only be called once, when the contract is initialized
        assert(_attestations.length == 0);
        // Insert empty non-meaningful values, that can't be used to prove anything
        _attestations.push(_toSummitAttestation(0, 0, 0));
        _notarySnapshots.push(SummitSnapshot(new uint256[](0), 0));
    }

    /// @dev Saves the Guard snapshot.
    function _saveGuardSnapshot(uint256[] memory statePtrs, uint256 sigIndex) internal {
        _guardSnapshots.push(SummitSnapshot(statePtrs, sigIndex));
    }

    /// @dev Saves the Notary snapshot and the attestation created from it.
    /// Returns the created attestation.
    function _saveNotarySnapshot(
        Snapshot snapshot,
        uint256[] memory statePtrs,
        bytes32 agentRoot,
        uint32 notaryIndex,
        uint256 sigIndex
    ) internal returns (bytes memory attPayload) {
        // Attestation nonce is its index in `_attestations` array
        uint32 attNonce = uint32(_attestations.length);
        bytes32 snapGasHash = GasDataLib.snapGasHash(snapshot.snapGas());
        SummitAttestation memory summitAtt = _toSummitAttestation(snapshot.calculateRoot(), agentRoot, snapGasHash);
        attPayload = _formatSummitAttestation(summitAtt, attNonce);
        _latestAttNonce[notaryIndex] = attNonce;
        /// @dev Add a single element to both `_attestations` and `_notarySnapshots`,
        /// enforcing the (_attestations.length == _notarySnapshots.length) invariant.
        _attestations.push(summitAtt);
        _notarySnapshots.push(SummitSnapshot(statePtrs, sigIndex));
        // Emit event with raw attestation data
        emit AttestationSaved(attPayload);
    }

    /// @dev Saves the state signed by a Guard.
    function _saveState(State state, uint32 guardIndex) internal returns (uint256 statePtr) {
        uint32 origin = state.origin();
        // Check that Guard hasn't submitted a fresher State before
        if (state.nonce() <= _latestState(origin, guardIndex).nonce) revert OutdatedNonce();
        bytes32 stateHash = state.leaf();
        statePtr = _leafPtr[origin][stateHash];
        // Save state only if it wasn't previously submitted
        if (statePtr == 0) {
            // Extract data that needs to be saved
            SummitState memory summitState = _toSummitState(state, guardIndex);
            _states.push(summitState);
            // State is stored at (length - 1), but we are tracking "index PLUS 1" as "pointer"
            statePtr = _states.length;
            _leafPtr[origin][stateHash] = statePtr;
            // Emit event with raw state data
            emit StateSaved(state.unwrap().clone());
        }
        // Update latest guard state for origin
        _latestStatePtr[origin][guardIndex] = statePtr;
    }

    // ══════════════════════════════════════════════ INTERNAL VIEWS ═══════════════════════════════════════════════════

    /// @dev Returns the amount of saved _attestations (created from Notary snapshots) so far.
    function _attestationsAmount() internal view returns (uint256) {
        return _attestations.length;
    }

    /// @dev Checks if attestation was previously submitted by a Notary (as a signed snapshot).
    function _isValidAttestation(Attestation att) internal view returns (bool) {
        // Check if nonce exists
        uint32 nonce = att.nonce();
        if (nonce >= _attestations.length) return false;
        // Check if Attestation matches the historical one
        return _areEqual(att, _attestations[nonce]);
    }

    /// @dev Restores Snapshot payload from a list of state pointers used for the snapshot.
    function _restoreSnapshot(SummitSnapshot memory snapshot)
        internal
        view
        returns (bytes memory snapPayload, bytes memory snapSignature)
    {
        uint256 statesAmount = snapshot.statePtrs.length;
        State[] memory states = new State[](statesAmount);
        for (uint256 i = 0; i < statesAmount; ++i) {
            // Get value for "index in _states PLUS 1"
            uint256 statePtr = snapshot.statePtrs[i];
            // We are never saving zero values when accepting Guard/Notary snapshots, so this holds
            assert(statePtr != 0);
            // Get the state that Agent used for the snapshot
            states[i] = _formatSummitState(_states[statePtr - 1]).castToState();
        }
        snapPayload = SnapshotLib.formatSnapshot(states);
        snapSignature = IStatementInbox(inbox).getStoredSignature(snapshot.sigIndex);
    }

    /// @dev Restores the gas data from the snapshot.
    function _restoreSnapGas(SummitSnapshot memory snapshot) internal view returns (uint256[] memory snapGas) {
        uint256 statesAmount = snapshot.statePtrs.length;
        snapGas = new uint256[](statesAmount);
        for (uint256 i = 0; i < statesAmount; ++i) {
            // Get value for "index in _states PLUS 1"
            uint256 statePtr = snapshot.statePtrs[i];
            // We are never saving zero values when accepting Guard/Notary snapshots, so this holds
            assert(statePtr != 0);
            // Get the state that Agent used for the snapshot
            snapGas[i] = ChainGas.unwrap(
                GasDataLib.encodeChainGas({
                    gasData_: _states[statePtr - 1].gasData,
                    domain_: _states[statePtr - 1].origin
                })
            );
        }
    }

    /// @dev Returns indexes of agents who provided state data for the Notary snapshot with the given nonce.
    function _stateAgents(uint32 nonce, uint256 stateIndex)
        internal
        view
        returns (uint32 guardIndex, uint32 notaryIndex)
    {
        uint256 statePtr = _notarySnapshots[nonce].statePtrs[stateIndex];
        return (_states[statePtr - 1].guardIndex, _states[statePtr - 1].notaryIndex);
    }

    /// @dev Returns the pointer for a matching Guard State, if it exists.
    function _statePtr(State state) internal view returns (uint256) {
        return _leafPtr[state.origin()][state.leaf()];
    }

    /// @dev Returns the latest state submitted by the Agent for the origin.
    /// Will return an empty struct, if the Agent hasn't submitted a single origin State yet.
    function _latestState(uint32 origin, uint32 agentIndex) internal view returns (SummitState memory state) {
        // Get value for "index in _states PLUS 1"
        uint256 latestPtr = _latestStatePtr[origin][agentIndex];
        // Check if the Agent has submitted at least one State for origin
        if (latestPtr != 0) {
            state = _states[latestPtr - 1];
        }
        // An empty struct is returned if the Agent hasn't submitted a single State for origin yet.
    }

    // ═════════════════════════════════════════════ STRUCT FORMATTING ═════════════════════════════════════════════════

    /// @dev Returns a formatted payload for a stored SummitState.
    function _formatSummitState(SummitState memory summitState) internal pure returns (bytes memory) {
        return StateLib.formatState({
            root_: summitState.root,
            origin_: summitState.origin,
            nonce_: summitState.nonce,
            blockNumber_: summitState.blockNumber,
            timestamp_: summitState.timestamp,
            gasData_: summitState.gasData
        });
    }

    /// @dev Returns a SummitState struct to save in the contract.
    function _toSummitState(State state, uint32 guardIndex) internal pure returns (SummitState memory summitState) {
        summitState.root = state.root();
        summitState.origin = state.origin();
        summitState.nonce = state.nonce();
        summitState.blockNumber = state.blockNumber();
        summitState.timestamp = state.timestamp();
        summitState.gasData = state.gasData();
        summitState.guardIndex = guardIndex;
        // summitState.notaryIndex is left as ZERO
    }

    /// @dev Returns a formatted payload for a stored SummitAttestation.
    function _formatSummitAttestation(SummitAttestation memory summitAtt, uint32 nonce)
        internal
        pure
        returns (bytes memory)
    {
        return AttestationLib.formatAttestation({
            snapRoot_: summitAtt.snapRoot,
            dataHash_: AttestationLib.dataHash(summitAtt.agentRoot, summitAtt.snapGasHash),
            nonce_: nonce,
            blockNumber_: summitAtt.blockNumber,
            timestamp_: summitAtt.timestamp
        });
    }

    /// @dev Returns an Attestation struct to save in the Summit contract.
    /// Current block number and timestamp are used.
    // solhint-disable-next-line ordering
    function _toSummitAttestation(bytes32 snapRoot, bytes32 agentRoot, bytes32 snapGasHash)
        internal
        view
        returns (SummitAttestation memory summitAtt)
    {
        summitAtt.snapRoot = snapRoot;
        summitAtt.agentRoot = agentRoot;
        summitAtt.snapGasHash = snapGasHash;
        summitAtt.blockNumber = uint40(block.number);
        summitAtt.timestamp = uint40(block.timestamp);
    }

    /// @dev Checks that an Attestation and its Summit representation are equal.
    function _areEqual(Attestation att, SummitAttestation memory summitAtt) internal pure returns (bool) {
        // forgefmt: disable-next-item
        return 
            att.snapRoot() == summitAtt.snapRoot &&
            att.dataHash() == AttestationLib.dataHash(summitAtt.agentRoot, summitAtt.snapGasHash) &&
            att.blockNumber() == summitAtt.blockNumber &&
            att.timestamp() == summitAtt.timestamp;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/structs/DoubleEndedQueue.sol)
pragma solidity ^0.8.4;

import "../math/SafeCast.sol";

/**
 * @dev A sequence of items with the ability to efficiently push and pop items (i.e. insert and remove) on both ends of
 * the sequence (called front and back). Among other access patterns, it can be used to implement efficient LIFO and
 * FIFO queues. Storage use is optimized, and all operations are O(1) constant time. This includes {clear}, given that
 * the existing queue contents are left in storage.
 *
 * The struct is called `Bytes32Deque`. Other types can be cast to and from `bytes32`. This data structure can only be
 * used in storage, and not in memory.
 * ```
 * DoubleEndedQueue.Bytes32Deque queue;
 * ```
 *
 * _Available since v4.6._
 */
library DoubleEndedQueue {
    /**
     * @dev An operation (e.g. {front}) couldn't be completed due to the queue being empty.
     */
    error Empty();

    /**
     * @dev An operation (e.g. {at}) couldn't be completed due to an index being out of bounds.
     */
    error OutOfBounds();

    /**
     * @dev Indices are signed integers because the queue can grow in any direction. They are 128 bits so begin and end
     * are packed in a single storage slot for efficient access. Since the items are added one at a time we can safely
     * assume that these 128-bit indices will not overflow, and use unchecked arithmetic.
     *
     * Struct members have an underscore prefix indicating that they are "private" and should not be read or written to
     * directly. Use the functions provided below instead. Modifying the struct manually may violate assumptions and
     * lead to unexpected behavior.
     *
     * Indices are in the range [begin, end) which means the first item is at data[begin] and the last item is at
     * data[end - 1].
     */
    struct Bytes32Deque {
        int128 _begin;
        int128 _end;
        mapping(int128 => bytes32) _data;
    }

    /**
     * @dev Inserts an item at the end of the queue.
     */
    function pushBack(Bytes32Deque storage deque, bytes32 value) internal {
        int128 backIndex = deque._end;
        deque._data[backIndex] = value;
        unchecked {
            deque._end = backIndex + 1;
        }
    }

    /**
     * @dev Removes the item at the end of the queue and returns it.
     *
     * Reverts with `Empty` if the queue is empty.
     */
    function popBack(Bytes32Deque storage deque) internal returns (bytes32 value) {
        if (empty(deque)) revert Empty();
        int128 backIndex;
        unchecked {
            backIndex = deque._end - 1;
        }
        value = deque._data[backIndex];
        delete deque._data[backIndex];
        deque._end = backIndex;
    }

    /**
     * @dev Inserts an item at the beginning of the queue.
     */
    function pushFront(Bytes32Deque storage deque, bytes32 value) internal {
        int128 frontIndex;
        unchecked {
            frontIndex = deque._begin - 1;
        }
        deque._data[frontIndex] = value;
        deque._begin = frontIndex;
    }

    /**
     * @dev Removes the item at the beginning of the queue and returns it.
     *
     * Reverts with `Empty` if the queue is empty.
     */
    function popFront(Bytes32Deque storage deque) internal returns (bytes32 value) {
        if (empty(deque)) revert Empty();
        int128 frontIndex = deque._begin;
        value = deque._data[frontIndex];
        delete deque._data[frontIndex];
        unchecked {
            deque._begin = frontIndex + 1;
        }
    }

    /**
     * @dev Returns the item at the beginning of the queue.
     *
     * Reverts with `Empty` if the queue is empty.
     */
    function front(Bytes32Deque storage deque) internal view returns (bytes32 value) {
        if (empty(deque)) revert Empty();
        int128 frontIndex = deque._begin;
        return deque._data[frontIndex];
    }

    /**
     * @dev Returns the item at the end of the queue.
     *
     * Reverts with `Empty` if the queue is empty.
     */
    function back(Bytes32Deque storage deque) internal view returns (bytes32 value) {
        if (empty(deque)) revert Empty();
        int128 backIndex;
        unchecked {
            backIndex = deque._end - 1;
        }
        return deque._data[backIndex];
    }

    /**
     * @dev Return the item at a position in the queue given by `index`, with the first item at 0 and last item at
     * `length(deque) - 1`.
     *
     * Reverts with `OutOfBounds` if the index is out of bounds.
     */
    function at(Bytes32Deque storage deque, uint256 index) internal view returns (bytes32 value) {
        // int256(deque._begin) is a safe upcast
        int128 idx = SafeCast.toInt128(int256(deque._begin) + SafeCast.toInt256(index));
        if (idx >= deque._end) revert OutOfBounds();
        return deque._data[idx];
    }

    /**
     * @dev Resets the queue back to being empty.
     *
     * NOTE: The current items are left behind in storage. This does not affect the functioning of the queue, but misses
     * out on potential gas refunds.
     */
    function clear(Bytes32Deque storage deque) internal {
        deque._begin = 0;
        deque._end = 0;
    }

    /**
     * @dev Returns the number of items in the queue.
     */
    function length(Bytes32Deque storage deque) internal view returns (uint256) {
        // The interface preserves the invariant that begin <= end so we assume this will not overflow.
        // We also assume there are at most int256.max items in the queue.
        unchecked {
            return uint256(int256(deque._end) - int256(deque._begin));
        }
    }

    /**
     * @dev Returns true if the queue is empty.
     */
    function empty(Bytes32Deque storage deque) internal view returns (bool) {
        return deque._end <= deque._begin;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IndexedTooMuch, OccupiedMemory, PrecompileOutOfGas, UnallocatedMemory, ViewOverrun} from "../Errors.sol";

/// @dev MemView is an untyped view over a portion of memory to be used instead of `bytes memory`
type MemView is uint256;

/// @dev Attach library functions to MemView
using MemViewLib for MemView global;

/// @notice Library for operations with the memory views.
/// Forked from https://github.com/summa-tx/memview-sol with several breaking changes:
/// - The codebase is ported to Solidity 0.8
/// - Custom errors are added
/// - The runtime type checking is replaced with compile-time check provided by User-Defined Value Types
///   https://docs.soliditylang.org/en/latest/types.html#user-defined-value-types
/// - uint256 is used as the underlying type for the "memory view" instead of bytes29.
///   It is wrapped into MemView custom type in order not to be confused with actual integers.
/// - Therefore the "type" field is discarded, allowing to allocate 16 bytes for both view location and length
/// - The documentation is expanded
/// - Library functions unused by the rest of the codebase are removed
//  - Very pretty code separators are added :)
library MemViewLib {
    /// @notice Stack layout for uint256 (from highest bits to lowest)
    /// (32 .. 16]      loc     16 bytes    Memory address of underlying bytes
    /// (16 .. 00]      len     16 bytes    Length of underlying bytes

    // ═══════════════════════════════════════════ BUILDING MEMORY VIEW ════════════════════════════════════════════════

    /**
     * @notice Instantiate a new untyped memory view. This should generally not be called directly.
     * Prefer `ref` wherever possible.
     * @param loc_          The memory address
     * @param len_          The length
     * @return The new view with the specified location and length
     */
    function build(uint256 loc_, uint256 len_) internal pure returns (MemView) {
        uint256 end_ = loc_ + len_;
        // Make sure that a view is not constructed that points to unallocated memory
        // as this could be indicative of a buffer overflow attack
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            if gt(end_, mload(0x40)) { end_ := 0 }
        }
        if (end_ == 0) {
            revert UnallocatedMemory();
        }
        return _unsafeBuildUnchecked(loc_, len_);
    }

    /**
     * @notice Instantiate a memory view from a byte array.
     * @dev Note that due to Solidity memory representation, it is not possible to
     * implement a deref, as the `bytes` type stores its len in memory.
     * @param arr           The byte array
     * @return The memory view over the provided byte array
     */
    function ref(bytes memory arr) internal pure returns (MemView) {
        uint256 len_ = arr.length;
        // `bytes arr` is stored in memory in the following way
        // 1. First, uint256 arr.length is stored. That requires 32 bytes (0x20).
        // 2. Then, the array data is stored.
        uint256 loc_;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // We add 0x20, so that the view starts exactly where the array data starts
            loc_ := add(arr, 0x20)
        }
        return build(loc_, len_);
    }

    // ════════════════════════════════════════════ CLONING MEMORY VIEW ════════════════════════════════════════════════

    /**
     * @notice Copies the referenced memory to a new loc in memory, returning a `bytes` pointing to the new memory.
     * @param memView       The memory view
     * @return arr          The cloned byte array
     */
    function clone(MemView memView) internal view returns (bytes memory arr) {
        uint256 ptr;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // Load unused memory pointer
            ptr := mload(0x40)
            // This is where the byte array will be stored
            arr := ptr
        }
        unchecked {
            _unsafeCopyTo(memView, ptr + 0x20);
        }
        // `bytes arr` is stored in memory in the following way
        // 1. First, uint256 arr.length is stored. That requires 32 bytes (0x20).
        // 2. Then, the array data is stored.
        uint256 len_ = memView.len();
        uint256 footprint_ = memView.footprint();
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // Write new unused pointer: the old value + array footprint + 32 bytes to store the length
            mstore(0x40, add(add(ptr, footprint_), 0x20))
            // Write len of new array (in bytes)
            mstore(ptr, len_)
        }
    }

    /**
     * @notice Copies all views, joins them into a new bytearray.
     * @param memViews      The memory views
     * @return arr          The new byte array with joined data behind the given views
     */
    function join(MemView[] memory memViews) internal view returns (bytes memory arr) {
        uint256 ptr;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // Load unused memory pointer
            ptr := mload(0x40)
            // This is where the byte array will be stored
            arr := ptr
        }
        MemView newView;
        unchecked {
            newView = _unsafeJoin(memViews, ptr + 0x20);
        }
        uint256 len_ = newView.len();
        uint256 footprint_ = newView.footprint();
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // Write new unused pointer: the old value + array footprint + 32 bytes to store the length
            mstore(0x40, add(add(ptr, footprint_), 0x20))
            // Write len of new array (in bytes)
            mstore(ptr, len_)
        }
    }

    // ══════════════════════════════════════════ INSPECTING MEMORY VIEW ═══════════════════════════════════════════════

    /**
     * @notice Returns the memory address of the underlying bytes.
     * @param memView       The memory view
     * @return loc_         The memory address
     */
    function loc(MemView memView) internal pure returns (uint256 loc_) {
        // loc is stored in the highest 16 bytes of the underlying uint256
        return MemView.unwrap(memView) >> 128;
    }

    /**
     * @notice Returns the number of bytes of the view.
     * @param memView       The memory view
     * @return len_         The length of the view
     */
    function len(MemView memView) internal pure returns (uint256 len_) {
        // len is stored in the lowest 16 bytes of the underlying uint256
        return MemView.unwrap(memView) & type(uint128).max;
    }

    /**
     * @notice Returns the endpoint of `memView`.
     * @param memView       The memory view
     * @return end_         The endpoint of `memView`
     */
    function end(MemView memView) internal pure returns (uint256 end_) {
        // The endpoint never overflows uint128, let alone uint256, so we could use unchecked math here
        unchecked {
            return memView.loc() + memView.len();
        }
    }

    /**
     * @notice Returns the number of memory words this memory view occupies, rounded up.
     * @param memView       The memory view
     * @return words_       The number of memory words
     */
    function words(MemView memView) internal pure returns (uint256 words_) {
        // returning ceil(length / 32.0)
        unchecked {
            return (memView.len() + 31) >> 5;
        }
    }

    /**
     * @notice Returns the in-memory footprint of a fresh copy of the view.
     * @param memView       The memory view
     * @return footprint_   The in-memory footprint of a fresh copy of the view.
     */
    function footprint(MemView memView) internal pure returns (uint256 footprint_) {
        // words() * 32
        return memView.words() << 5;
    }

    // ════════════════════════════════════════════ HASHING MEMORY VIEW ════════════════════════════════════════════════

    /**
     * @notice Returns the keccak256 hash of the underlying memory
     * @param memView       The memory view
     * @return digest       The keccak256 hash of the underlying memory
     */
    function keccak(MemView memView) internal pure returns (bytes32 digest) {
        uint256 loc_ = memView.loc();
        uint256 len_ = memView.len();
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            digest := keccak256(loc_, len_)
        }
    }

    /**
     * @notice Adds a salt to the keccak256 hash of the underlying data and returns the keccak256 hash of the
     * resulting data.
     * @param memView       The memory view
     * @return digestSalted keccak256(salt, keccak256(memView))
     */
    function keccakSalted(MemView memView, bytes32 salt) internal pure returns (bytes32 digestSalted) {
        return keccak256(bytes.concat(salt, memView.keccak()));
    }

    // ════════════════════════════════════════════ SLICING MEMORY VIEW ════════════════════════════════════════════════

    /**
     * @notice Safe slicing without memory modification.
     * @param memView       The memory view
     * @param index_        The start index
     * @param len_          The length
     * @return The new view for the slice of the given length starting from the given index
     */
    function slice(MemView memView, uint256 index_, uint256 len_) internal pure returns (MemView) {
        uint256 loc_ = memView.loc();
        // Ensure it doesn't overrun the view
        if (loc_ + index_ + len_ > memView.end()) {
            revert ViewOverrun();
        }
        // Build a view starting from index with the given length
        unchecked {
            // loc_ + index_ <= memView.end()
            return build({loc_: loc_ + index_, len_: len_});
        }
    }

    /**
     * @notice Shortcut to `slice`. Gets a view representing bytes from `index` to end(memView).
     * @param memView       The memory view
     * @param index_        The start index
     * @return The new view for the slice starting from the given index until the initial view endpoint
     */
    function sliceFrom(MemView memView, uint256 index_) internal pure returns (MemView) {
        uint256 len_ = memView.len();
        // Ensure it doesn't overrun the view
        if (index_ > len_) {
            revert ViewOverrun();
        }
        // Build a view starting from index with the given length
        unchecked {
            // index_ <= len_ => memView.loc() + index_ <= memView.loc() + memView.len() == memView.end()
            return build({loc_: memView.loc() + index_, len_: len_ - index_});
        }
    }

    /**
     * @notice Shortcut to `slice`. Gets a view representing the first `len` bytes.
     * @param memView       The memory view
     * @param len_          The length
     * @return The new view for the slice of the given length starting from the initial view beginning
     */
    function prefix(MemView memView, uint256 len_) internal pure returns (MemView) {
        return memView.slice({index_: 0, len_: len_});
    }

    /**
     * @notice Shortcut to `slice`. Gets a view representing the last `len` byte.
     * @param memView       The memory view
     * @param len_          The length
     * @return The new view for the slice of the given length until the initial view endpoint
     */
    function postfix(MemView memView, uint256 len_) internal pure returns (MemView) {
        uint256 viewLen = memView.len();
        // Ensure it doesn't overrun the view
        if (len_ > viewLen) {
            revert ViewOverrun();
        }
        // Could do the unchecked math due to the check above
        uint256 index_;
        unchecked {
            index_ = viewLen - len_;
        }
        // Build a view starting from index with the given length
        unchecked {
            // len_ <= memView.len() => memView.loc() <= loc_ <= memView.end()
            return build({loc_: memView.loc() + viewLen - len_, len_: len_});
        }
    }

    // ═══════════════════════════════════════════ INDEXING MEMORY VIEW ════════════════════════════════════════════════

    /**
     * @notice Load up to 32 bytes from the view onto the stack.
     * @dev Returns a bytes32 with only the `bytes_` HIGHEST bytes set.
     * This can be immediately cast to a smaller fixed-length byte array.
     * To automatically cast to an integer, use `indexUint`.
     * @param memView       The memory view
     * @param index_        The index
     * @param bytes_        The amount of bytes to load onto the stack
     * @return result       The 32 byte result having only `bytes_` highest bytes set
     */
    function index(MemView memView, uint256 index_, uint256 bytes_) internal pure returns (bytes32 result) {
        if (bytes_ == 0) {
            return bytes32(0);
        }
        // Can't load more than 32 bytes to the stack in one go
        if (bytes_ > 32) {
            revert IndexedTooMuch();
        }
        // The last indexed byte should be within view boundaries
        if (index_ + bytes_ > memView.len()) {
            revert ViewOverrun();
        }
        uint256 bitLength = bytes_ << 3; // bytes_ * 8
        uint256 loc_ = memView.loc();
        // Get a mask with `bitLength` highest bits set
        uint256 mask;
        // 0x800...00 binary representation is 100...00
        // sar stands for "signed arithmetic shift": https://en.wikipedia.org/wiki/Arithmetic_shift
        // sar(N-1, 100...00) = 11...100..00, with exactly N highest bits set to 1
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            mask := sar(sub(bitLength, 1), 0x8000000000000000000000000000000000000000000000000000000000000000)
        }
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // Load a full word using index offset, and apply mask to ignore non-relevant bytes
            result := and(mload(add(loc_, index_)), mask)
        }
    }

    /**
     * @notice Parse an unsigned integer from the view at `index`.
     * @dev Requires that the view have >= `bytes_` bytes following that index.
     * @param memView       The memory view
     * @param index_        The index
     * @param bytes_        The amount of bytes to load onto the stack
     * @return The unsigned integer
     */
    function indexUint(MemView memView, uint256 index_, uint256 bytes_) internal pure returns (uint256) {
        bytes32 indexedBytes = memView.index(index_, bytes_);
        // `index()` returns left-aligned `bytes_`, while integers are right-aligned
        // Shifting here to right-align with the full 32 bytes word: need to shift right `(32 - bytes_)` bytes
        unchecked {
            // memView.index() reverts when bytes_ > 32, thus unchecked math
            return uint256(indexedBytes) >> ((32 - bytes_) << 3);
        }
    }

    /**
     * @notice Parse an address from the view at `index`.
     * @dev Requires that the view have >= 20 bytes following that index.
     * @param memView       The memory view
     * @param index_        The index
     * @return The address
     */
    function indexAddress(MemView memView, uint256 index_) internal pure returns (address) {
        // index 20 bytes as `uint160`, and then cast to `address`
        return address(uint160(memView.indexUint(index_, 20)));
    }

    // ══════════════════════════════════════════════ PRIVATE HELPERS ══════════════════════════════════════════════════

    /// @dev Returns a memory view over the specified memory location
    /// without checking if it points to unallocated memory.
    function _unsafeBuildUnchecked(uint256 loc_, uint256 len_) private pure returns (MemView) {
        // There is no scenario where loc or len would overflow uint128, so we omit this check.
        // We use the highest 128 bits to encode the location and the lowest 128 bits to encode the length.
        return MemView.wrap((loc_ << 128) | len_);
    }

    /**
     * @notice Copy the view to a location, return an unsafe memory reference
     * @dev Super Dangerous direct memory access.
     * This reference can be overwritten if anything else modifies memory (!!!).
     * As such it MUST be consumed IMMEDIATELY. Update the free memory pointer to ensure the copied data
     * is not overwritten. This function is private to prevent unsafe usage by callers.
     * @param memView       The memory view
     * @param newLoc        The new location to copy the underlying view data
     * @return The memory view over the unsafe memory with the copied underlying data
     */
    function _unsafeCopyTo(MemView memView, uint256 newLoc) private view returns (MemView) {
        uint256 len_ = memView.len();
        uint256 oldLoc = memView.loc();

        uint256 ptr;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // Load unused memory pointer
            ptr := mload(0x40)
        }
        // Revert if we're writing in occupied memory
        if (newLoc < ptr) {
            revert OccupiedMemory();
        }
        bool res;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // use the identity precompile (0x04) to copy
            res := staticcall(gas(), 0x04, oldLoc, len_, newLoc, len_)
        }
        if (!res) revert PrecompileOutOfGas();
        return _unsafeBuildUnchecked({loc_: newLoc, len_: len_});
    }

    /**
     * @notice Join the views in memory, return an unsafe reference to the memory.
     * @dev Super Dangerous direct memory access.
     * This reference can be overwritten if anything else modifies memory (!!!).
     * As such it MUST be consumed IMMEDIATELY. Update the free memory pointer to ensure the copied data
     * is not overwritten. This function is private to prevent unsafe usage by callers.
     * @param memViews      The memory views
     * @return The conjoined view pointing to the new memory
     */
    function _unsafeJoin(MemView[] memory memViews, uint256 location) private view returns (MemView) {
        uint256 ptr;
        assembly {
            // solhint-disable-previous-line no-inline-assembly
            // Load unused memory pointer
            ptr := mload(0x40)
        }
        // Revert if we're writing in occupied memory
        if (location < ptr) {
            revert OccupiedMemory();
        }
        // Copy the views to the specified location one by one, by tracking the amount of copied bytes so far
        uint256 offset = 0;
        for (uint256 i = 0; i < memViews.length;) {
            MemView memView = memViews[i];
            // We can use the unchecked math here as location + sum(view.length) will never overflow uint256
            unchecked {
                _unsafeCopyTo(memView, location + offset);
                offset += memView.len();
                ++i;
            }
        }
        return _unsafeBuildUnchecked({loc_: location, len_: offset});
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MemView, MemViewLib} from "./MemView.sol";
import {GAS_DATA_LENGTH, STATE_LENGTH, STATE_INVALID_SALT} from "../Constants.sol";
import {UnformattedState} from "../Errors.sol";
import {GasData, GasDataLib} from "../stack/GasData.sol";

/// State is a memory view over a formatted state payload.
type State is uint256;

using StateLib for State global;

/// # State
/// State structure represents the state of Origin contract at some point of time.
/// - State is structured in a way to track the updates of the Origin Merkle Tree.
/// - State includes root of the Origin Merkle Tree, origin domain and some additional metadata.
/// ## Origin Merkle Tree
/// Hash of every sent message is inserted in the Origin Merkle Tree, which changes
/// the value of Origin Merkle Root (which is the root for the mentioned tree).
/// - Origin has a single Merkle Tree for all messages, regardless of their destination domain.
/// - This leads to Origin state being updated if and only if a message was sent in a block.
/// - Origin contract is a "source of truth" for states: a state is considered "valid" in its Origin,
/// if it matches the state of the Origin contract after the N-th (nonce) message was sent.
///
/// # Memory layout of State fields
///
/// | Position   | Field       | Type    | Bytes | Description                    |
/// | ---------- | ----------- | ------- | ----- | ------------------------------ |
/// | [000..032) | root        | bytes32 | 32    | Root of the Origin Merkle Tree |
/// | [032..036) | origin      | uint32  | 4     | Domain where Origin is located |
/// | [036..040) | nonce       | uint32  | 4     | Amount of sent messages        |
/// | [040..045) | blockNumber | uint40  | 5     | Block of last sent message     |
/// | [045..050) | timestamp   | uint40  | 5     | Time of last sent message      |
/// | [050..062) | gasData     | uint96  | 12    | Gas data for the chain         |
///
/// @dev State could be used to form a Snapshot to be signed by a Guard or a Notary.
library StateLib {
    using MemViewLib for bytes;

    /// @dev The variables below are not supposed to be used outside of the library directly.
    uint256 private constant OFFSET_ROOT = 0;
    uint256 private constant OFFSET_ORIGIN = 32;
    uint256 private constant OFFSET_NONCE = 36;
    uint256 private constant OFFSET_BLOCK_NUMBER = 40;
    uint256 private constant OFFSET_TIMESTAMP = 45;
    uint256 private constant OFFSET_GAS_DATA = 50;

    // ═══════════════════════════════════════════════════ STATE ═══════════════════════════════════════════════════════

    /**
     * @notice Returns a formatted State payload with provided fields
     * @param root_         New merkle root
     * @param origin_       Domain of Origin's chain
     * @param nonce_        Nonce of the merkle root
     * @param blockNumber_  Block number when root was saved in Origin
     * @param timestamp_    Block timestamp when root was saved in Origin
     * @param gasData_      Gas data for the chain
     * @return Formatted state
     */
    function formatState(
        bytes32 root_,
        uint32 origin_,
        uint32 nonce_,
        uint40 blockNumber_,
        uint40 timestamp_,
        GasData gasData_
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(root_, origin_, nonce_, blockNumber_, timestamp_, gasData_);
    }

    /**
     * @notice Returns a State view over the given payload.
     * @dev Will revert if the payload is not a state.
     */
    function castToState(bytes memory payload) internal pure returns (State) {
        return castToState(payload.ref());
    }

    /**
     * @notice Casts a memory view to a State view.
     * @dev Will revert if the memory view is not over a state.
     */
    function castToState(MemView memView) internal pure returns (State) {
        if (!isState(memView)) revert UnformattedState();
        return State.wrap(MemView.unwrap(memView));
    }

    /// @notice Checks that a payload is a formatted State.
    function isState(MemView memView) internal pure returns (bool) {
        return memView.len() == STATE_LENGTH;
    }

    /// @notice Returns the hash of a State, that could be later signed by a Guard to signal
    /// that the state is invalid.
    function hashInvalid(State state) internal pure returns (bytes32) {
        // The final hash to sign is keccak(stateInvalidSalt, keccak(state))
        return state.unwrap().keccakSalted(STATE_INVALID_SALT);
    }

    /// @notice Convenience shortcut for unwrapping a view.
    function unwrap(State state) internal pure returns (MemView) {
        return MemView.wrap(State.unwrap(state));
    }

    /// @notice Compares two State structures.
    function equals(State a, State b) internal pure returns (bool) {
        // Length of a State payload is fixed, so we just need to compare the hashes
        return a.unwrap().keccak() == b.unwrap().keccak();
    }

    // ═══════════════════════════════════════════════ STATE HASHING ═══════════════════════════════════════════════════

    /// @notice Returns the hash of the State.
    /// @dev We are using the Merkle Root of a tree with two leafs (see below) as state hash.
    function leaf(State state) internal pure returns (bytes32) {
        (bytes32 leftLeaf_, bytes32 rightLeaf_) = state.subLeafs();
        // Final hash is the parent of these leafs
        return keccak256(bytes.concat(leftLeaf_, rightLeaf_));
    }

    /// @notice Returns "sub-leafs" of the State. Hash of these "sub leafs" is going to be used
    /// as a "state leaf" in the "Snapshot Merkle Tree".
    /// This enables proving that leftLeaf = (root, origin) was a part of the "Snapshot Merkle Tree",
    /// by combining `rightLeaf` with the remainder of the "Snapshot Merkle Proof".
    function subLeafs(State state) internal pure returns (bytes32 leftLeaf_, bytes32 rightLeaf_) {
        MemView memView = state.unwrap();
        // Left leaf is (root, origin)
        leftLeaf_ = memView.prefix({len_: OFFSET_NONCE}).keccak();
        // Right leaf is (metadata), or (nonce, blockNumber, timestamp)
        rightLeaf_ = memView.sliceFrom({index_: OFFSET_NONCE}).keccak();
    }

    /// @notice Returns the left "sub-leaf" of the State.
    function leftLeaf(bytes32 root_, uint32 origin_) internal pure returns (bytes32) {
        // We use encodePacked here to simulate the State memory layout
        return keccak256(abi.encodePacked(root_, origin_));
    }

    /// @notice Returns the right "sub-leaf" of the State.
    function rightLeaf(uint32 nonce_, uint40 blockNumber_, uint40 timestamp_, GasData gasData_)
        internal
        pure
        returns (bytes32)
    {
        // We use encodePacked here to simulate the State memory layout
        return keccak256(abi.encodePacked(nonce_, blockNumber_, timestamp_, gasData_));
    }

    // ═══════════════════════════════════════════════ STATE SLICING ═══════════════════════════════════════════════════

    /// @notice Returns a historical Merkle root from the Origin contract.
    function root(State state) internal pure returns (bytes32) {
        return state.unwrap().index({index_: OFFSET_ROOT, bytes_: 32});
    }

    /// @notice Returns domain of chain where the Origin contract is deployed.
    function origin(State state) internal pure returns (uint32) {
        return uint32(state.unwrap().indexUint({index_: OFFSET_ORIGIN, bytes_: 4}));
    }

    /// @notice Returns nonce of Origin contract at the time, when `root` was the Merkle root.
    function nonce(State state) internal pure returns (uint32) {
        return uint32(state.unwrap().indexUint({index_: OFFSET_NONCE, bytes_: 4}));
    }

    /// @notice Returns a block number when `root` was saved in Origin.
    function blockNumber(State state) internal pure returns (uint40) {
        return uint40(state.unwrap().indexUint({index_: OFFSET_BLOCK_NUMBER, bytes_: 5}));
    }

    /// @notice Returns a block timestamp when `root` was saved in Origin.
    /// @dev This is the timestamp according to the origin chain.
    function timestamp(State state) internal pure returns (uint40) {
        return uint40(state.unwrap().indexUint({index_: OFFSET_TIMESTAMP, bytes_: 5}));
    }

    /// @notice Returns gas data for the chain.
    function gasData(State state) internal pure returns (GasData) {
        return GasDataLib.wrapGasData(state.unwrap().indexUint({index_: OFFSET_GAS_DATA, bytes_: GAS_DATA_LENGTH}));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {TreeHeightTooLow} from "../Errors.sol";

library MerkleMath {
    // ═════════════════════════════════════════ BASIC MERKLE CALCULATIONS ═════════════════════════════════════════════

    /**
     * @notice Calculates the merkle root for the given leaf and merkle proof.
     * @dev Will revert if proof length exceeds the tree height.
     * @param index     Index of `leaf` in tree
     * @param leaf      Leaf of the merkle tree
     * @param proof     Proof of inclusion of `leaf` in the tree
     * @param height    Height of the merkle tree
     * @return root_    Calculated Merkle Root
     */
    function proofRoot(uint256 index, bytes32 leaf, bytes32[] memory proof, uint256 height)
        internal
        pure
        returns (bytes32 root_)
    {
        // Proof length could not exceed the tree height
        uint256 proofLen = proof.length;
        if (proofLen > height) revert TreeHeightTooLow();
        root_ = leaf;
        /// @dev Apply unchecked to all ++h operations
        unchecked {
            // Go up the tree levels from the leaf following the proof
            for (uint256 h = 0; h < proofLen; ++h) {
                // Get a sibling node on current level: this is proof[h]
                root_ = getParent(root_, proof[h], index, h);
            }
            // Go up to the root: the remaining siblings are EMPTY
            for (uint256 h = proofLen; h < height; ++h) {
                root_ = getParent(root_, bytes32(0), index, h);
            }
        }
    }

    /**
     * @notice Calculates the parent of a node on the path from one of the leafs to root.
     * @param node          Node on a path from tree leaf to root
     * @param sibling       Sibling for a given node
     * @param leafIndex     Index of the tree leaf
     * @param nodeHeight    "Level height" for `node` (ZERO for leafs, ORIGIN_TREE_HEIGHT for root)
     */
    function getParent(bytes32 node, bytes32 sibling, uint256 leafIndex, uint256 nodeHeight)
        internal
        pure
        returns (bytes32 parent)
    {
        // Index for `node` on its "tree level" is (leafIndex / 2**height)
        // "Left child" has even index, "right child" has odd index
        if ((leafIndex >> nodeHeight) & 1 == 0) {
            // Left child
            return getParent(node, sibling);
        } else {
            // Right child
            return getParent(sibling, node);
        }
    }

    /// @notice Calculates the parent of tow nodes in the merkle tree.
    /// @dev We use implementation with H(0,0) = 0
    /// This makes EVERY empty node in the tree equal to ZERO,
    /// saving us from storing H(0,0), H(H(0,0), H(0, 0)), and so on
    /// @param leftChild    Left child of the calculated node
    /// @param rightChild   Right child of the calculated node
    /// @return parent      Value for the node having above mentioned children
    function getParent(bytes32 leftChild, bytes32 rightChild) internal pure returns (bytes32 parent) {
        if (leftChild == bytes32(0) && rightChild == bytes32(0)) {
            return 0;
        } else {
            return keccak256(bytes.concat(leftChild, rightChild));
        }
    }

    // ════════════════════════════════ ROOT/PROOF CALCULATION FOR A LIST OF LEAFS ═════════════════════════════════════

    /**
     * @notice Calculates merkle root for a list of given leafs.
     * Merkle Tree is constructed by padding the list with ZERO values for leafs until list length is `2**height`.
     * Merkle Root is calculated for the constructed tree, and then saved in `leafs[0]`.
     * > Note:
     * > - `leafs` values are overwritten in the process to avoid excessive memory allocations.
     * > - Caller is expected not to reuse `hashes` list after the call, and only use `leafs[0]` value,
     * which is guaranteed to contain the calculated merkle root.
     * > - root is calculated using the `H(0,0) = 0` Merkle Tree implementation. See MerkleTree.sol for details.
     * @dev Amount of leaves should be at most `2**height`
     * @param hashes    List of leafs for the merkle tree (to be overwritten)
     * @param height    Height of the Merkle Tree to construct
     */
    function calculateRoot(bytes32[] memory hashes, uint256 height) internal pure {
        uint256 levelLength = hashes.length;
        // Amount of hashes could not exceed amount of leafs in tree with the given height
        if (levelLength > (1 << height)) revert TreeHeightTooLow();
        /// @dev h, leftIndex, rightIndex and levelLength never overflow
        unchecked {
            // Iterate `height` levels up from the leaf level
            // For every level we will only record "significant values", i.e. not equal to ZERO
            for (uint256 h = 0; h < height; ++h) {
                // Let H be the height of the "current level". H = 0 for the "leafs level".
                // Invariant: a total of 2**(HEIGHT-H) nodes are on the current level
                // Invariant: hashes[0 .. length) are "significant values" for the "current level" nodes
                // Invariant: bytes32(0) is the value for nodes with indexes [length .. 2**(HEIGHT-H))

                // Iterate over every pair of (leftChild, rightChild) on the current level
                for (uint256 leftIndex = 0; leftIndex < levelLength; leftIndex += 2) {
                    uint256 rightIndex = leftIndex + 1;
                    bytes32 leftChild = hashes[leftIndex];
                    // Note: rightChild might be ZERO
                    bytes32 rightChild = rightIndex < levelLength ? hashes[rightIndex] : bytes32(0);
                    // Record the parent hash in the same array. This will not affect
                    // further calculations for the same level: (leftIndex >> 1) <= leftIndex.
                    hashes[leftIndex >> 1] = getParent(leftChild, rightChild);
                }
                // Set length for the "parent level": the amount of iterations for the for loop above.
                levelLength = (levelLength + 1) >> 1;
            }
        }
    }

    /**
     * @notice Generates a proof of inclusion of a leaf in the list. If the requested index is outside
     * of the list range, generates a proof of inclusion for an empty leaf (proof of non-inclusion).
     * The Merkle Tree is constructed by padding the list with ZERO values until list length is a power of two
     * __AND__ index is in the extended list range. For example:
     *  - `hashes.length == 6` and `0 <= index <= 7` will "extend" the list to 8 entries.
     *  - `hashes.length == 6` and `7 < index <= 15` will "extend" the list to 16 entries.
     * > Note: `leafs` values are overwritten in the process to avoid excessive memory allocations.
     * Caller is expected not to reuse `hashes` list after the call.
     * @param hashes    List of leafs for the merkle tree (to be overwritten)
     * @param index     Leaf index to generate the proof for
     * @return proof    Generated merkle proof
     */
    function calculateProof(bytes32[] memory hashes, uint256 index) internal pure returns (bytes32[] memory proof) {
        // Use only meaningful values for the shortened proof
        // Check if index is within the list range (we want to generates proofs for outside leafs as well)
        uint256 height = getHeight(index < hashes.length ? hashes.length : (index + 1));
        proof = new bytes32[](height);
        uint256 levelLength = hashes.length;
        /// @dev h, leftIndex, rightIndex and levelLength never overflow
        unchecked {
            // Iterate `height` levels up from the leaf level
            // For every level we will only record "significant values", i.e. not equal to ZERO
            for (uint256 h = 0; h < height; ++h) {
                // Use sibling for the merkle proof; `index^1` is index of our sibling
                proof[h] = (index ^ 1 < levelLength) ? hashes[index ^ 1] : bytes32(0);

                // Let H be the height of the "current level". H = 0 for the "leafs level".
                // Invariant: a total of 2**(HEIGHT-H) nodes are on the current level
                // Invariant: hashes[0 .. length) are "significant values" for the "current level" nodes
                // Invariant: bytes32(0) is the value for nodes with indexes [length .. 2**(HEIGHT-H))

                // Iterate over every pair of (leftChild, rightChild) on the current level
                for (uint256 leftIndex = 0; leftIndex < levelLength; leftIndex += 2) {
                    uint256 rightIndex = leftIndex + 1;
                    bytes32 leftChild = hashes[leftIndex];
                    // Note: rightChild might be ZERO
                    bytes32 rightChild = rightIndex < levelLength ? hashes[rightIndex] : bytes32(0);
                    // Record the parent hash in the same array. This will not affect
                    // further calculations for the same level: (leftIndex >> 1) <= leftIndex.
                    hashes[leftIndex >> 1] = getParent(leftChild, rightChild);
                }
                // Set length for the "parent level"
                levelLength = (levelLength + 1) >> 1;
                // Traverse to parent node
                index >>= 1;
            }
        }
    }

    /// @notice Returns the height of the tree having a given amount of leafs.
    function getHeight(uint256 leafs) internal pure returns (uint256 height) {
        uint256 amount = 1;
        while (amount < leafs) {
            unchecked {
                ++height;
            }
            amount <<= 1;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Number} from "./Number.sol";

/// GasData in encoded data with "basic information about gas prices" for some chain.
type GasData is uint96;

using GasDataLib for GasData global;

/// ChainGas is encoded data with given chain's "basic information about gas prices".
type ChainGas is uint128;

using GasDataLib for ChainGas global;

/// Library for encoding and decoding GasData and ChainGas structs.
/// # GasData
/// `GasData` is a struct to store the "basic information about gas prices", that could
/// be later used to approximate the cost of a message execution, and thus derive the
/// minimal tip values for sending a message to the chain.
/// > - `GasData` is supposed to be cached by `GasOracle` contract, allowing to store the
/// > approximates instead of the exact values, and thus save on storage costs.
/// > - For instance, if `GasOracle` only updates the values on +- 10% change, having an
/// > 0.4% error on the approximates would be acceptable.
/// `GasData` is supposed to be included in the Origin's state, which are synced across
/// chains using Agent-signed snapshots and attestations.
/// ## GasData stack layout (from highest bits to lowest)
///
/// | Position   | Field        | Type   | Bytes | Description                                         |
/// | ---------- | ------------ | ------ | ----- | --------------------------------------------------- |
/// | (012..010] | gasPrice     | uint16 | 2     | Gas price for the chain (in Wei per gas unit)       |
/// | (010..008] | dataPrice    | uint16 | 2     | Calldata price (in Wei per byte of content)         |
/// | (008..006] | execBuffer   | uint16 | 2     | Tx fee safety buffer for message execution (in Wei) |
/// | (006..004] | amortAttCost | uint16 | 2     | Amortized cost for attestation submission (in Wei)  |
/// | (004..002] | etherPrice   | uint16 | 2     | Chain's Ether Price / Mainnet Ether Price (in BWAD) |
/// | (002..000] | markup       | uint16 | 2     | Markup for the message execution (in BWAD)          |
/// > See Number.sol for more details on `Number` type and BWAD (binary WAD) math.
///
/// ## ChainGas stack layout (from highest bits to lowest)
///
/// | Position   | Field   | Type   | Bytes | Description      |
/// | ---------- | ------- | ------ | ----- | ---------------- |
/// | (016..004] | gasData | uint96 | 12    | Chain's gas data |
/// | (004..000] | domain  | uint32 | 4     | Chain's domain   |
library GasDataLib {
    /// @dev Amount of bits to shift to gasPrice field
    uint96 private constant SHIFT_GAS_PRICE = 10 * 8;
    /// @dev Amount of bits to shift to dataPrice field
    uint96 private constant SHIFT_DATA_PRICE = 8 * 8;
    /// @dev Amount of bits to shift to execBuffer field
    uint96 private constant SHIFT_EXEC_BUFFER = 6 * 8;
    /// @dev Amount of bits to shift to amortAttCost field
    uint96 private constant SHIFT_AMORT_ATT_COST = 4 * 8;
    /// @dev Amount of bits to shift to etherPrice field
    uint96 private constant SHIFT_ETHER_PRICE = 2 * 8;

    /// @dev Amount of bits to shift to gasData field
    uint128 private constant SHIFT_GAS_DATA = 4 * 8;

    // ═════════════════════════════════════════════════ GAS DATA ══════════════════════════════════════════════════════

    /// @notice Returns an encoded GasData struct with the given fields.
    /// @param gasPrice_        Gas price for the chain (in Wei per gas unit)
    /// @param dataPrice_       Calldata price (in Wei per byte of content)
    /// @param execBuffer_      Tx fee safety buffer for message execution (in Wei)
    /// @param amortAttCost_    Amortized cost for attestation submission (in Wei)
    /// @param etherPrice_      Ratio of Chain's Ether Price / Mainnet Ether Price (in BWAD)
    /// @param markup_          Markup for the message execution (in BWAD)
    function encodeGasData(
        Number gasPrice_,
        Number dataPrice_,
        Number execBuffer_,
        Number amortAttCost_,
        Number etherPrice_,
        Number markup_
    ) internal pure returns (GasData) {
        // forgefmt: disable-next-item
        return GasData.wrap(
            uint96(Number.unwrap(gasPrice_)) << SHIFT_GAS_PRICE |
            uint96(Number.unwrap(dataPrice_)) << SHIFT_DATA_PRICE |
            uint96(Number.unwrap(execBuffer_)) << SHIFT_EXEC_BUFFER |
            uint96(Number.unwrap(amortAttCost_)) << SHIFT_AMORT_ATT_COST |
            uint96(Number.unwrap(etherPrice_)) << SHIFT_ETHER_PRICE |
            uint96(Number.unwrap(markup_))
        );
    }

    /// @notice Wraps padded uint256 value into GasData struct.
    function wrapGasData(uint256 paddedGasData) internal pure returns (GasData) {
        return GasData.wrap(uint96(paddedGasData));
    }

    /// @notice Returns the gas price, in Wei per gas unit.
    function gasPrice(GasData data) internal pure returns (Number) {
        // Casting to uint16 will truncate the highest bits, which is the behavior we want
        return Number.wrap(uint16(GasData.unwrap(data) >> SHIFT_GAS_PRICE));
    }

    /// @notice Returns the calldata price, in Wei per byte of content.
    function dataPrice(GasData data) internal pure returns (Number) {
        // Casting to uint16 will truncate the highest bits, which is the behavior we want
        return Number.wrap(uint16(GasData.unwrap(data) >> SHIFT_DATA_PRICE));
    }

    /// @notice Returns the tx fee safety buffer for message execution, in Wei.
    function execBuffer(GasData data) internal pure returns (Number) {
        // Casting to uint16 will truncate the highest bits, which is the behavior we want
        return Number.wrap(uint16(GasData.unwrap(data) >> SHIFT_EXEC_BUFFER));
    }

    /// @notice Returns the amortized cost for attestation submission, in Wei.
    function amortAttCost(GasData data) internal pure returns (Number) {
        // Casting to uint16 will truncate the highest bits, which is the behavior we want
        return Number.wrap(uint16(GasData.unwrap(data) >> SHIFT_AMORT_ATT_COST));
    }

    /// @notice Returns the ratio of Chain's Ether Price / Mainnet Ether Price, in BWAD math.
    function etherPrice(GasData data) internal pure returns (Number) {
        // Casting to uint16 will truncate the highest bits, which is the behavior we want
        return Number.wrap(uint16(GasData.unwrap(data) >> SHIFT_ETHER_PRICE));
    }

    /// @notice Returns the markup for the message execution, in BWAD math.
    function markup(GasData data) internal pure returns (Number) {
        // Casting to uint16 will truncate the highest bits, which is the behavior we want
        return Number.wrap(uint16(GasData.unwrap(data)));
    }

    // ════════════════════════════════════════════════ CHAIN DATA ═════════════════════════════════════════════════════

    /// @notice Returns an encoded ChainGas struct with the given fields.
    /// @param gasData_ Chain's gas data
    /// @param domain_  Chain's domain
    function encodeChainGas(GasData gasData_, uint32 domain_) internal pure returns (ChainGas) {
        return ChainGas.wrap(uint128(GasData.unwrap(gasData_)) << SHIFT_GAS_DATA | uint128(domain_));
    }

    /// @notice Wraps padded uint256 value into ChainGas struct.
    function wrapChainGas(uint256 paddedChainGas) internal pure returns (ChainGas) {
        return ChainGas.wrap(uint128(paddedChainGas));
    }

    /// @notice Returns the chain's gas data.
    function gasData(ChainGas data) internal pure returns (GasData) {
        // Casting to uint96 will truncate the highest bits, which is the behavior we want
        return GasData.wrap(uint96(ChainGas.unwrap(data) >> SHIFT_GAS_DATA));
    }

    /// @notice Returns the chain's domain.
    function domain(ChainGas data) internal pure returns (uint32) {
        // Casting to uint32 will truncate the highest bits, which is the behavior we want
        return uint32(ChainGas.unwrap(data));
    }

    /// @notice Returns the hash for the list of ChainGas structs.
    function snapGasHash(ChainGas[] memory snapGas) internal pure returns (bytes32 snapGasHash_) {
        // Use assembly to calculate the hash of the array without copying it
        // ChainGas takes a single word of storage, thus ChainGas[] is stored in the following way:
        // 0x00: length of the array, in words
        // 0x20: first ChainGas struct
        // 0x40: second ChainGas struct
        // And so on...
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Find the location where the array data starts, we add 0x20 to skip the length field
            let loc := add(snapGas, 0x20)
            // Load the length of the array (in words).
            // Shifting left 5 bits is equivalent to multiplying by 32: this converts from words to bytes.
            let len := shl(5, mload(snapGas))
            // Calculate the hash of the array
            snapGasHash_ := keccak256(loc, len)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {AgentStatus} from "../libs/Structures.sol";

interface IAgentSecured {
    /**
     * @notice Local AgentManager should call this function to indicate that a dispute
     * between a Guard and a Notary has been opened.
     * @param guardIndex    Index of the Guard in the Agent Merkle Tree
     * @param notaryIndex   Index of the Notary in the Agent Merkle Tree
     */
    function openDispute(uint32 guardIndex, uint32 notaryIndex) external;

    /**
     * @notice Local AgentManager should call this function to indicate that a dispute
     * has been resolved due to one of the agents being slashed.
     * > `rivalIndex` will be ZERO, if the slashed agent was not in the Dispute.
     * @param slashedIndex  Index of the slashed agent in the Agent Merkle Tree
     * @param rivalIndex    Index of the their Dispute Rival in the Agent Merkle Tree
     */
    function resolveDispute(uint32 slashedIndex, uint32 rivalIndex) external;

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /**
     * @notice Returns the address of the local AgentManager contract, which is treated as
     * the "source of truth" for agent statuses.
     */
    function agentManager() external view returns (address);

    /**
     * @notice Returns the address of the local Inbox contract, which is treated as
     * the "source of truth" for agent-signed statements.
     * @dev Inbox passes verified agent statements to `IAgentSecured` contract.
     */
    function inbox() external view returns (address);

    /**
     * @notice Returns (flag, domain, index) for a given agent. See Structures.sol for details.
     * @dev Will return AgentFlag.Fraudulent for agents that have been proven to commit fraud,
     * but their status is not updated to Slashed yet.
     * @param agent     Agent address
     * @return          Status for the given agent: (flag, domain, index).
     */
    function agentStatus(address agent) external view returns (AgentStatus memory);

    /**
     * @notice Returns agent address and their current status for a given agent index.
     * @dev Will return empty values if agent with given index doesn't exist.
     * @param index     Agent index in the Agent Merkle Tree
     * @return agent    Agent address
     * @return status   Status for the given agent: (flag, domain, index)
     */
    function getAgent(uint256 index) external view returns (address agent, AgentStatus memory status);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// ═════════════════════════════ INTERNAL IMPORTS ══════════════════════════════
import {MultiCallable} from "./MultiCallable.sol";
import {Versioned} from "./Version.sol";
// ═════════════════════════════ EXTERNAL IMPORTS ══════════════════════════════
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @notice Base contract for all messaging contracts.
 * - Provides context on the local chain's domain.
 * - Provides ownership functionality.
 * - Will be providing pausing functionality when it is implemented.
 */
abstract contract MessagingBase is MultiCallable, Versioned, OwnableUpgradeable {
    // ════════════════════════════════════════════════ IMMUTABLES ═════════════════════════════════════════════════════

    /// @notice Domain of the local chain, set once upon contract creation
    uint32 public immutable localDomain;

    // ══════════════════════════════════════════════════ STORAGE ══════════════════════════════════════════════════════

    /// @dev gap for upgrade safety
    uint256[50] private __GAP; // solhint-disable-line var-name-mixedcase

    constructor(string memory version_, uint32 localDomain_) Versioned(version_) {
        localDomain = localDomain_;
    }

    // TODO: Implement pausing

    /**
     * @dev Should be impossible to renounce ownership;
     * we override OpenZeppelin OwnableUpgradeable's
     * implementation of renounceOwnership to make it a no-op
     */
    function renounceOwnership() public override onlyOwner {} //solhint-disable-line no-empty-blocks
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
     * @param attPayload    Raw payload with attestation data
     * @return isValid      Whether the provided attestation is valid
     */
    function isValidAttestation(bytes memory attPayload) external view returns (bool isValid);

    /**
     * @notice Returns saved attestation with the given nonce.
     * @dev Reverts if attestation with given nonce hasn't been created yet.
     * @param attNonce      Nonce for the attestation
     * @return attPayload   Raw payload with formatted Attestation data
     * @return agentRoot    Agent root hash used for the attestation
     * @return snapGas      Snapshot gas data used for the attestation
     */
    function getAttestation(uint32 attNonce)
        external
        view
        returns (bytes memory attPayload, bytes32 agentRoot, uint256[] memory snapGas);

    /**
     * @notice Returns the state with the highest known nonce submitted by a given Agent.
     * @param origin        Domain of origin chain
     * @param agent         Agent address
     * @return statePayload Raw payload with agent's latest state for origin
     */
    function getLatestAgentState(uint32 origin, address agent) external view returns (bytes memory statePayload);

    /**
     * @notice Returns latest saved attestation for a Notary.
     * @param notary        Notary address
     * @return attPayload   Raw payload with formatted Attestation data
     * @return agentRoot    Agent root hash used for the attestation
     * @return snapGas      Snapshot gas data used for the attestation
     */
    function getLatestNotaryAttestation(address notary)
        external
        view
        returns (bytes memory attPayload, bytes32 agentRoot, uint256[] memory snapGas);

    /**
     * @notice Returns Guard snapshot from the list of all accepted Guard snapshots.
     * @dev Reverts if snapshot with given index hasn't been accepted yet.
     * @param index             Snapshot index in the list of all Guard snapshots
     * @return snapPayload      Raw payload with Guard snapshot
     * @return snapSignature    Raw payload with Guard signature for snapshot
     */
    function getGuardSnapshot(uint256 index)
        external
        view
        returns (bytes memory snapPayload, bytes memory snapSignature);

    /**
     * @notice Returns Notary snapshot from the list of all accepted Guard snapshots.
     * @dev Reverts if snapshot with given index hasn't been accepted yet.
     * @param index             Snapshot index in the list of all Notary snapshots
     * @return snapPayload      Raw payload with Notary snapshot
     * @return snapSignature    Raw payload with Notary signature for snapshot
     */
    function getNotarySnapshot(uint256 index)
        external
        view
        returns (bytes memory snapPayload, bytes memory snapSignature);

    /**
     * @notice Returns Notary snapshot that was used for creating a given attestation.
     * @dev Reverts if any of these is true:
     *  - Attestation payload is not properly formatted.
     *  - Attestation is invalid (doesn't have a matching Notary snapshot).
     * @param attPayload        Raw payload with attestation data
     * @return snapPayload      Raw payload with Notary snapshot
     * @return snapSignature    Raw payload with Notary signature for snapshot
     */
    function getNotarySnapshot(bytes memory attPayload)
        external
        view
        returns (bytes memory snapPayload, bytes memory snapSignature);

    /**
     * @notice Returns proof of inclusion of (root, origin) fields of a given snapshot's state
     * into the Snapshot Merkle Tree for a given attestation.
     * @dev Reverts if any of these is true:
     *  - Attestation with given nonce hasn't been created yet.
     *  - State index is out of range of snapshot list.
     * @param attNonce      Nonce for the attestation
     * @param stateIndex    Index of state in the attestation's snapshot
     * @return snapProof    The snapshot proof
     */
    function getSnapshotProof(uint32 attNonce, uint256 stateIndex) external view returns (bytes32[] memory snapProof);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IStatementInbox {
    // ══════════════════════════════════════════ SUBMIT AGENT STATEMENTS ══════════════════════════════════════════════

    /**
     * @notice Accepts a Guard's state report signature, a Snapshot containing the reported State,
     * as well as Notary signature for the Snapshot.
     * > StateReport is a Guard statement saying "Reported state is invalid".
     * - This results in an opened Dispute between the Guard and the Notary.
     * - Note: Guard could (but doesn't have to) form a StateReport and use other values from
     * `verifyStateWithSnapshot()` successful call that led to Notary being slashed in remote Origin.
     * > Will revert if any of these is true:
     * > - State Report signer is not an active Guard.
     * > - Snapshot payload is not properly formatted.
     * > - Snapshot signer is not an active Notary.
     * > - State index is out of range.
     * > - The Guard or the Notary are already in a Dispute
     * @param stateIndex        Index of the reported State in the Snapshot
     * @param srSignature       Guard signature for the report
     * @param snapPayload       Raw payload with Snapshot data
     * @param snapSignature     Notary signature for the Snapshot
     * @return wasAccepted      Whether the Report was accepted (resulting in Dispute between the agents)
     */
    function submitStateReportWithSnapshot(
        uint256 stateIndex,
        bytes memory srSignature,
        bytes memory snapPayload,
        bytes memory snapSignature
    ) external returns (bool wasAccepted);

    /**
     * @notice Accepts a Guard's state report signature, a Snapshot containing the reported State,
     * as well as Notary signature for the Attestation created from this Snapshot.
     * > StateReport is a Guard statement saying "Reported state is invalid".
     * - This results in an opened Dispute between the Guard and the Notary.
     * - Note: Guard could (but doesn't have to) form a StateReport and use other values from
     * `verifyStateWithAttestation()` successful call that led to Notary being slashed in remote Origin.
     * > Will revert if any of these is true:
     * > - State Report signer is not an active Guard.
     * > - Snapshot payload is not properly formatted.
     * > - State index is out of range.
     * > - Attestation payload is not properly formatted.
     * > - Attestation signer is not an active Notary.
     * > - Attestation's snapshot root is not equal to Merkle Root derived from the Snapshot.
     * > - The Guard or the Notary are already in a Dispute
     * @param stateIndex        Index of the reported State in the Snapshot
     * @param srSignature       Guard signature for the report
     * @param snapPayload       Raw payload with Snapshot data
     * @param attPayload        Raw payload with Attestation data
     * @param attSignature      Notary signature for the Attestation
     * @return wasAccepted      Whether the Report was accepted (resulting in Dispute between the agents)
     */
    function submitStateReportWithAttestation(
        uint256 stateIndex,
        bytes memory srSignature,
        bytes memory snapPayload,
        bytes memory attPayload,
        bytes memory attSignature
    ) external returns (bool wasAccepted);

    /**
     * @notice Accepts a Guard's state report signature, a proof of inclusion of the reported State in an Attestation,
     * as well as Notary signature for the Attestation.
     * > StateReport is a Guard statement saying "Reported state is invalid".
     * - This results in an opened Dispute between the Guard and the Notary.
     * - Note: Guard could (but doesn't have to) form a StateReport and use other values from
     * `verifyStateWithSnapshotProof()` successful call that led to Notary being slashed in remote Origin.
     * > Will revert if any of these is true:
     * > - State payload is not properly formatted.
     * > - State Report signer is not an active Guard.
     * > - Attestation payload is not properly formatted.
     * > - Attestation signer is not an active Notary.
     * > - Attestation's snapshot root is not equal to Merkle Root derived from State and Snapshot Proof.
     * > - Snapshot Proof's first element does not match the State metadata.
     * > - Snapshot Proof length exceeds Snapshot Tree Height.
     * > - State index is out of range.
     * > - The Guard or the Notary are already in a Dispute
     * @param stateIndex        Index of the reported State in the Snapshot
     * @param statePayload      Raw payload with State data that Guard reports as invalid
     * @param srSignature       Guard signature for the report
     * @param snapProof         Proof of inclusion of reported State's Left Leaf into Snapshot Merkle Tree
     * @param attPayload        Raw payload with Attestation data
     * @param attSignature      Notary signature for the Attestation
     * @return wasAccepted      Whether the Report was accepted (resulting in Dispute between the agents)
     */
    function submitStateReportWithSnapshotProof(
        uint256 stateIndex,
        bytes memory statePayload,
        bytes memory srSignature,
        bytes32[] memory snapProof,
        bytes memory attPayload,
        bytes memory attSignature
    ) external returns (bool wasAccepted);

    // ══════════════════════════════════════════ VERIFY AGENT STATEMENTS ══════════════════════════════════════════════

    /**
     * @notice Verifies a message receipt signed by the Notary.
     * - Does nothing, if the receipt is valid (matches the saved receipt data for the referenced message).
     * - Slashes the Notary, if the receipt is invalid.
     * > Will revert if any of these is true:
     * > - Receipt payload is not properly formatted.
     * > - Receipt signer is not an active Notary.
     * > - Receipt's destination chain does not refer to this chain.
     * @param rcptPayload       Raw payload with Receipt data
     * @param rcptSignature     Notary signature for the receipt
     * @return isValidReceipt   Whether the provided receipt is valid.
     *                          Notary is slashed, if return value is FALSE.
     */
    function verifyReceipt(bytes memory rcptPayload, bytes memory rcptSignature)
        external
        returns (bool isValidReceipt);

    /**
     * @notice Verifies a Guard's receipt report signature.
     * - Does nothing, if the report is valid (if the reported receipt is invalid).
     * - Slashes the Guard, if the report is invalid (if the reported receipt is valid).
     * > Will revert if any of these is true:
     * > - Receipt payload is not properly formatted.
     * > - Receipt Report signer is not an active Guard.
     * > - Receipt does not refer to this chain.
     * @param rcptPayload       Raw payload with Receipt data that Guard reports as invalid
     * @param rrSignature       Guard signature for the report
     * @return isValidReport    Whether the provided report is valid.
     *                          Guard is slashed, if return value is FALSE.
     */
    function verifyReceiptReport(bytes memory rcptPayload, bytes memory rrSignature)
        external
        returns (bool isValidReport);

    /**
     * @notice Verifies a state from the snapshot, that was used for the Notary-signed attestation.
     * - Does nothing, if the state is valid (matches the historical state of this contract).
     * - Slashes the Notary, if the state is invalid.
     * > Will revert if any of these is true:
     * > - Attestation payload is not properly formatted.
     * > - Attestation signer is not an active Notary.
     * > - Attestation's snapshot root is not equal to Merkle Root derived from the Snapshot.
     * > - Snapshot payload is not properly formatted.
     * > - State index is out of range.
     * > - State does not refer to this chain.
     * @param stateIndex        State index to check
     * @param snapPayload       Raw payload with snapshot data
     * @param attPayload        Raw payload with Attestation data
     * @param attSignature      Notary signature for the attestation
     * @return isValidState     Whether the provided state is valid.
     *                          Notary is slashed, if return value is FALSE.
     */
    function verifyStateWithAttestation(
        uint256 stateIndex,
        bytes memory snapPayload,
        bytes memory attPayload,
        bytes memory attSignature
    ) external returns (bool isValidState);

    /**
     * @notice Verifies a state from the snapshot, that was used for the Notary-signed attestation.
     * - Does nothing, if the state is valid (matches the historical state of this contract).
     * - Slashes the Notary, if the state is invalid.
     * > Will revert if any of these is true:
     * > - Attestation payload is not properly formatted.
     * > - Attestation signer is not an active Notary.
     * > - Attestation's snapshot root is not equal to Merkle Root derived from State and Snapshot Proof.
     * > - Snapshot Proof's first element does not match the State metadata.
     * > - Snapshot Proof length exceeds Snapshot Tree Height.
     * > - State payload is not properly formatted.
     * > - State index is out of range.
     * > - State does not refer to this chain.
     * @param stateIndex        Index of state in the snapshot
     * @param statePayload      Raw payload with State data to check
     * @param snapProof         Proof of inclusion of provided State's Left Leaf into Snapshot Merkle Tree
     * @param attPayload        Raw payload with Attestation data
     * @param attSignature      Notary signature for the attestation
     * @return isValidState     Whether the provided state is valid.
     *                          Notary is slashed, if return value is FALSE.
     */
    function verifyStateWithSnapshotProof(
        uint256 stateIndex,
        bytes memory statePayload,
        bytes32[] memory snapProof,
        bytes memory attPayload,
        bytes memory attSignature
    ) external returns (bool isValidState);

    /**
     * @notice Verifies a state from the snapshot (a list of states) signed by a Guard or a Notary.
     * - Does nothing, if the state is valid (matches the historical state of this contract).
     * - Slashes the Agent, if the state is invalid.
     * > Will revert if any of these is true:
     * > - Snapshot payload is not properly formatted.
     * > - Snapshot signer is not an active Agent.
     * > - State index is out of range.
     * > - State does not refer to this chain.
     * @param stateIndex        State index to check
     * @param snapPayload       Raw payload with snapshot data
     * @param snapSignature     Agent signature for the snapshot
     * @return isValidState     Whether the provided state is valid.
     *                          Agent is slashed, if return value is FALSE.
     */
    function verifyStateWithSnapshot(uint256 stateIndex, bytes memory snapPayload, bytes memory snapSignature)
        external
        returns (bool isValidState);

    /**
     * @notice Verifies a Guard's state report signature.
     *  - Does nothing, if the report is valid (if the reported state is invalid).
     *  - Slashes the Guard, if the report is invalid (if the reported state is valid).
     * > Will revert if any of these is true:
     * > - State payload is not properly formatted.
     * > - State Report signer is not an active Guard.
     * > - Reported State does not refer to this chain.
     * @param statePayload      Raw payload with State data that Guard reports as invalid
     * @param srSignature       Guard signature for the report
     * @return isValidReport    Whether the provided report is valid.
     *                          Guard is slashed, if return value is FALSE.
     */
    function verifyStateReport(bytes memory statePayload, bytes memory srSignature)
        external
        returns (bool isValidReport);

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /**
     * @notice Returns the amount of Guard Reports stored in StatementInbox.
     * > Only reports that led to opening a Dispute are stored.
     */
    function getReportsAmount() external view returns (uint256);

    /**
     * @notice Returns the Guard report with the given index stored in StatementInbox.
     * > Only reports that led to opening a Dispute are stored.
     * @dev Will revert if report with given index doesn't exist.
     * @param index             Report index
     * @return statementPayload Raw payload with statement that Guard reported as invalid
     * @return reportSignature  Guard signature for the report
     */
    function getGuardReport(uint256 index)
        external
        view
        returns (bytes memory statementPayload, bytes memory reportSignature);

    /**
     * @notice Returns the signature with the given index stored in StatementInbox.
     * @dev Will revert if signature with given index doesn't exist.
     * @param index     Signature index
     * @return          Raw payload with signature
     */
    function getStoredSignature(uint256 index) external view returns (bytes memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/math/SafeCast.sol)

pragma solidity ^0.8.0;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCast {
    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        require(value <= type(uint248).max, "SafeCast: value doesn't fit in 248 bits");
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        require(value <= type(uint240).max, "SafeCast: value doesn't fit in 240 bits");
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        require(value <= type(uint232).max, "SafeCast: value doesn't fit in 232 bits");
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.2._
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        require(value <= type(uint216).max, "SafeCast: value doesn't fit in 216 bits");
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        require(value <= type(uint208).max, "SafeCast: value doesn't fit in 208 bits");
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        require(value <= type(uint200).max, "SafeCast: value doesn't fit in 200 bits");
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        require(value <= type(uint192).max, "SafeCast: value doesn't fit in 192 bits");
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        require(value <= type(uint184).max, "SafeCast: value doesn't fit in 184 bits");
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        require(value <= type(uint176).max, "SafeCast: value doesn't fit in 176 bits");
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        require(value <= type(uint168).max, "SafeCast: value doesn't fit in 168 bits");
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        require(value <= type(uint160).max, "SafeCast: value doesn't fit in 160 bits");
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        require(value <= type(uint152).max, "SafeCast: value doesn't fit in 152 bits");
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        require(value <= type(uint144).max, "SafeCast: value doesn't fit in 144 bits");
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        require(value <= type(uint136).max, "SafeCast: value doesn't fit in 136 bits");
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v2.5._
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        require(value <= type(uint120).max, "SafeCast: value doesn't fit in 120 bits");
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        require(value <= type(uint112).max, "SafeCast: value doesn't fit in 112 bits");
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        require(value <= type(uint104).max, "SafeCast: value doesn't fit in 104 bits");
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.2._
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        require(value <= type(uint80).max, "SafeCast: value doesn't fit in 80 bits");
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        require(value <= type(uint72).max, "SafeCast: value doesn't fit in 72 bits");
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v2.5._
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        require(value <= type(uint56).max, "SafeCast: value doesn't fit in 56 bits");
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        require(value <= type(uint48).max, "SafeCast: value doesn't fit in 48 bits");
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        require(value <= type(uint40).max, "SafeCast: value doesn't fit in 40 bits");
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v2.5._
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        require(value <= type(uint24).max, "SafeCast: value doesn't fit in 24 bits");
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v2.5._
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v2.5._
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     *
     * _Available since v3.0._
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toInt248(int256 value) internal pure returns (int248) {
        require(value >= type(int248).min && value <= type(int248).max, "SafeCast: value doesn't fit in 248 bits");
        return int248(value);
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toInt240(int256 value) internal pure returns (int240) {
        require(value >= type(int240).min && value <= type(int240).max, "SafeCast: value doesn't fit in 240 bits");
        return int240(value);
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toInt232(int256 value) internal pure returns (int232) {
        require(value >= type(int232).min && value <= type(int232).max, "SafeCast: value doesn't fit in 232 bits");
        return int232(value);
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.7._
     */
    function toInt224(int256 value) internal pure returns (int224) {
        require(value >= type(int224).min && value <= type(int224).max, "SafeCast: value doesn't fit in 224 bits");
        return int224(value);
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toInt216(int256 value) internal pure returns (int216) {
        require(value >= type(int216).min && value <= type(int216).max, "SafeCast: value doesn't fit in 216 bits");
        return int216(value);
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toInt208(int256 value) internal pure returns (int208) {
        require(value >= type(int208).min && value <= type(int208).max, "SafeCast: value doesn't fit in 208 bits");
        return int208(value);
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toInt200(int256 value) internal pure returns (int200) {
        require(value >= type(int200).min && value <= type(int200).max, "SafeCast: value doesn't fit in 200 bits");
        return int200(value);
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toInt192(int256 value) internal pure returns (int192) {
        require(value >= type(int192).min && value <= type(int192).max, "SafeCast: value doesn't fit in 192 bits");
        return int192(value);
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toInt184(int256 value) internal pure returns (int184) {
        require(value >= type(int184).min && value <= type(int184).max, "SafeCast: value doesn't fit in 184 bits");
        return int184(value);
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toInt176(int256 value) internal pure returns (int176) {
        require(value >= type(int176).min && value <= type(int176).max, "SafeCast: value doesn't fit in 176 bits");
        return int176(value);
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toInt168(int256 value) internal pure returns (int168) {
        require(value >= type(int168).min && value <= type(int168).max, "SafeCast: value doesn't fit in 168 bits");
        return int168(value);
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toInt160(int256 value) internal pure returns (int160) {
        require(value >= type(int160).min && value <= type(int160).max, "SafeCast: value doesn't fit in 160 bits");
        return int160(value);
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toInt152(int256 value) internal pure returns (int152) {
        require(value >= type(int152).min && value <= type(int152).max, "SafeCast: value doesn't fit in 152 bits");
        return int152(value);
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toInt144(int256 value) internal pure returns (int144) {
        require(value >= type(int144).min && value <= type(int144).max, "SafeCast: value doesn't fit in 144 bits");
        return int144(value);
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toInt136(int256 value) internal pure returns (int136) {
        require(value >= type(int136).min && value <= type(int136).max, "SafeCast: value doesn't fit in 136 bits");
        return int136(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128) {
        require(value >= type(int128).min && value <= type(int128).max, "SafeCast: value doesn't fit in 128 bits");
        return int128(value);
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toInt120(int256 value) internal pure returns (int120) {
        require(value >= type(int120).min && value <= type(int120).max, "SafeCast: value doesn't fit in 120 bits");
        return int120(value);
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toInt112(int256 value) internal pure returns (int112) {
        require(value >= type(int112).min && value <= type(int112).max, "SafeCast: value doesn't fit in 112 bits");
        return int112(value);
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toInt104(int256 value) internal pure returns (int104) {
        require(value >= type(int104).min && value <= type(int104).max, "SafeCast: value doesn't fit in 104 bits");
        return int104(value);
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.7._
     */
    function toInt96(int256 value) internal pure returns (int96) {
        require(value >= type(int96).min && value <= type(int96).max, "SafeCast: value doesn't fit in 96 bits");
        return int96(value);
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toInt88(int256 value) internal pure returns (int88) {
        require(value >= type(int88).min && value <= type(int88).max, "SafeCast: value doesn't fit in 88 bits");
        return int88(value);
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toInt80(int256 value) internal pure returns (int80) {
        require(value >= type(int80).min && value <= type(int80).max, "SafeCast: value doesn't fit in 80 bits");
        return int80(value);
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toInt72(int256 value) internal pure returns (int72) {
        require(value >= type(int72).min && value <= type(int72).max, "SafeCast: value doesn't fit in 72 bits");
        return int72(value);
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64) {
        require(value >= type(int64).min && value <= type(int64).max, "SafeCast: value doesn't fit in 64 bits");
        return int64(value);
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toInt56(int256 value) internal pure returns (int56) {
        require(value >= type(int56).min && value <= type(int56).max, "SafeCast: value doesn't fit in 56 bits");
        return int56(value);
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toInt48(int256 value) internal pure returns (int48) {
        require(value >= type(int48).min && value <= type(int48).max, "SafeCast: value doesn't fit in 48 bits");
        return int48(value);
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toInt40(int256 value) internal pure returns (int40) {
        require(value >= type(int40).min && value <= type(int40).max, "SafeCast: value doesn't fit in 40 bits");
        return int40(value);
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32) {
        require(value >= type(int32).min && value <= type(int32).max, "SafeCast: value doesn't fit in 32 bits");
        return int32(value);
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toInt24(int256 value) internal pure returns (int24) {
        require(value >= type(int24).min && value <= type(int24).max, "SafeCast: value doesn't fit in 24 bits");
        return int24(value);
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16) {
        require(value >= type(int16).min && value <= type(int16).max, "SafeCast: value doesn't fit in 16 bits");
        return int16(value);
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= type(int8).min && value <= type(int8).max, "SafeCast: value doesn't fit in 8 bits");
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     *
     * _Available since v3.0._
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// Number is a compact representation of uint256, that is fit into 16 bits
/// with the maximum relative error under 0.4%.
type Number is uint16;

using NumberLib for Number global;

/// # Number
/// Library for compact representation of uint256 numbers.
/// - Number is stored using mantissa and exponent, each occupying 8 bits.
/// - Numbers under 2**8 are stored as `mantissa` with `exponent = 0xFF`.
/// - Numbers at least 2**8 are approximated as `(256 + mantissa) << exponent`
/// > - `0 <= mantissa < 256`
/// > - `0 <= exponent <= 247` (`256 * 2**248` doesn't fit into uint256)
/// # Number stack layout (from highest bits to lowest)
///
/// | Position   | Field    | Type  | Bytes |
/// | ---------- | -------- | ----- | ----- |
/// | (002..001] | mantissa | uint8 | 1     |
/// | (001..000] | exponent | uint8 | 1     |

library NumberLib {
    /// @dev Amount of bits to shift to mantissa field
    uint16 private constant SHIFT_MANTISSA = 8;

    /// @notice For bwad math (binary wad) we use 2**64 as "wad" unit.
    /// @dev We are using not using 10**18 as wad, because it is not stored precisely in NumberLib.
    uint256 internal constant BWAD_SHIFT = 64;
    uint256 internal constant BWAD = 1 << BWAD_SHIFT;
    /// @notice ~0.1% in bwad units.
    uint256 internal constant PER_MILLE_SHIFT = BWAD_SHIFT - 10;
    uint256 internal constant PER_MILLE = 1 << PER_MILLE_SHIFT;

    /// @notice Compresses uint256 number into 16 bits.
    function compress(uint256 value) internal pure returns (Number) {
        // Find `msb` such as `2**msb <= value < 2**(msb + 1)`
        uint256 msb = mostSignificantBit(value);
        // We want to preserve 9 bits of precision.
        // The highest bit is always 1, so we can skip it.
        // The remaining 8 highest bits are stored as mantissa.
        if (msb < 8) {
            // Value is less than 2**8, so we can use value as mantissa with "-1" exponent.
            return _encode(uint8(value), 0xFF);
        } else {
            // We use `msb - 8` as exponent otherwise. Note that `exponent >= 0`.
            unchecked {
                uint256 exponent = msb - 8;
                // Shifting right by `msb-8` bits will shift the "remaining 8 highest bits" into the 8 lowest bits.
                // uint8() will truncate the highest bit.
                return _encode(uint8(value >> exponent), uint8(exponent));
            }
        }
    }

    /// @notice Decompresses 16 bits number into uint256.
    /// @dev The outcome is an approximation of the original number: `(value - value / 256) < number <= value`.
    function decompress(Number number) internal pure returns (uint256 value) {
        // Isolate 8 highest bits as the mantissa.
        uint256 mantissa = Number.unwrap(number) >> SHIFT_MANTISSA;
        // This will truncate the highest bits, leaving only the exponent.
        uint256 exponent = uint8(Number.unwrap(number));
        if (exponent == 0xFF) {
            return mantissa;
        } else {
            unchecked {
                return (256 + mantissa) << (exponent);
            }
        }
    }

    /// @dev Returns the most significant bit of `x`
    /// https://solidity-by-example.org/bitwise/
    function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
        // To find `msb` we determine it bit by bit, starting from the highest one.
        // `0 <= msb <= 255`, so we start from the highest bit, 1<<7 == 128.
        // If `x` is at least 2**128, then the highest bit of `x` is at least 128.
        // solhint-disable no-inline-assembly
        assembly {
            // `f` is set to 1<<7 if `x >= 2**128` and to 0 otherwise.
            let f := shl(7, gt(x, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
            // If `x >= 2**128` then set `msb` highest bit to 1 and shift `x` right by 128.
            // Otherwise, `msb` remains 0 and `x` remains unchanged.
            x := shr(f, x)
            msb := or(msb, f)
        }
        // `x` is now at most 2**128 - 1. Continue the same way, the next highest bit is 1<<6 == 64.
        assembly {
            // `f` is set to 1<<6 if `x >= 2**64` and to 0 otherwise.
            let f := shl(6, gt(x, 0xFFFFFFFFFFFFFFFF))
            x := shr(f, x)
            msb := or(msb, f)
        }
        assembly {
            // `f` is set to 1<<5 if `x >= 2**32` and to 0 otherwise.
            let f := shl(5, gt(x, 0xFFFFFFFF))
            x := shr(f, x)
            msb := or(msb, f)
        }
        assembly {
            // `f` is set to 1<<4 if `x >= 2**16` and to 0 otherwise.
            let f := shl(4, gt(x, 0xFFFF))
            x := shr(f, x)
            msb := or(msb, f)
        }
        assembly {
            // `f` is set to 1<<3 if `x >= 2**8` and to 0 otherwise.
            let f := shl(3, gt(x, 0xFF))
            x := shr(f, x)
            msb := or(msb, f)
        }
        assembly {
            // `f` is set to 1<<2 if `x >= 2**4` and to 0 otherwise.
            let f := shl(2, gt(x, 0xF))
            x := shr(f, x)
            msb := or(msb, f)
        }
        assembly {
            // `f` is set to 1<<1 if `x >= 2**2` and to 0 otherwise.
            let f := shl(1, gt(x, 0x3))
            x := shr(f, x)
            msb := or(msb, f)
        }
        assembly {
            // `f` is set to 1 if `x >= 2**1` and to 0 otherwise.
            let f := gt(x, 0x1)
            msb := or(msb, f)
        }
    }

    /// @dev Wraps (mantissa, exponent) pair into Number.
    function _encode(uint8 mantissa, uint8 exponent) private pure returns (Number) {
        return Number.wrap(uint16(mantissa) << SHIFT_MANTISSA | uint16(exponent));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MulticallFailed} from "../libs/Errors.sol";

/// @notice Collection of Multicall utilities. Fork of Multicall3:
/// https://github.com/mds1/multicall/blob/master/src/Multicall3.sol
abstract contract MultiCallable {
    struct Call {
        bool allowFailure;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    /// @notice Aggregates a few calls to this contract into one multicall without modifying `msg.sender`.
    function multicall(Call[] calldata calls) external returns (Result[] memory callResults) {
        uint256 amount = calls.length;
        callResults = new Result[](amount);
        Call calldata call_;
        for (uint256 i = 0; i < amount;) {
            call_ = calls[i];
            Result memory result = callResults[i];
            // We perform a delegate call to ourselves here. Delegate call does not modify `msg.sender`, so
            // this will have the same effect as if `msg.sender` performed all the calls themselves one by one.
            // solhint-disable-next-line avoid-low-level-calls
            (result.success, result.returnData) = address(this).delegatecall(call_.callData);
            // solhint-disable-next-line no-inline-assembly
            assembly {
                // Revert if the call fails and failure is not allowed
                // `allowFailure := calldataload(call_)` and `success := mload(result)`
                if iszero(or(calldataload(call_), mload(result))) {
                    // Revert with `0x4d6a2328` (function selector for `MulticallFailed()`)
                    mstore(0x00, 0x4d6a232800000000000000000000000000000000000000000000000000000000)
                    revert(0x00, 0x04)
                }
            }
            unchecked {
                ++i;
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IncorrectVersionLength} from "../libs/Errors.sol";

/**
 * @title Versioned
 * @notice Version getter for contracts. Doesn't use any storage slots, meaning
 * it will never cause any troubles with the upgradeable contracts. For instance, this contract
 * can be added or removed from the inheritance chain without shifting the storage layout.
 */
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

    constructor(string memory version_) {
        _length = bytes(version_).length;
        if (_length > 32) revert IncorrectVersionLength();
        // bytes32 is left-aligned => this will store the byte representation of the string
        // with the trailing zeroes to complete the 32-byte word
        _data = bytes32(bytes(version_));
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