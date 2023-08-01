// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { Semver } from "../universal/Semver.sol";
import { Predeploys } from "../libraries/Predeploys.sol";

import { EIP712Verifier } from "./eip712/EIP712Verifier.sol";

import { ISchemaResolver } from "./resolver/ISchemaResolver.sol";

// prettier-ignore
import {
    AccessDenied,
    EMPTY_UID,
    EIP712Signature,
    InvalidLength,
    MAX_GAP,
    NotFound,
    NO_EXPIRATION_TIME,
    uncheckedInc
} from "./Common.sol";

// prettier-ignore
import {
    Attestation,
    AttestationRequest,
    AttestationRequestData,
    DelegatedAttestationRequest,
    DelegatedRevocationRequest,
    IEAS,
    MultiAttestationRequest,
    MultiDelegatedAttestationRequest,
    MultiDelegatedRevocationRequest,
    MultiRevocationRequest,
    RevocationRequest,
    RevocationRequestData
} from "./IEAS.sol";

import { ISchemaRegistry, SchemaRecord } from "./ISchemaRegistry.sol";

struct AttestationsResult {
    uint256 usedValue; // Total ETH amount that was sent to resolvers.
    bytes32[] uids; // UIDs of the new attestations.
}

/// @custom:proxied
/// @custom:predeploy 0x4200000000000000000000000000000000000021
/// @title EAS
/// @notice The Ethereum Attestation Service protocol.
contract EAS is IEAS, Semver, EIP712Verifier {
    using Address for address payable;

    error AlreadyRevoked();
    error AlreadyRevokedOffchain();
    error AlreadyTimestamped();
    error InsufficientValue();
    error InvalidAttestation();
    error InvalidAttestations();
    error InvalidExpirationTime();
    error InvalidOffset();
    error InvalidRegistry();
    error InvalidRevocation();
    error InvalidRevocations();
    error InvalidSchema();
    error InvalidVerifier();
    error Irrevocable();
    error NotPayable();
    error WrongSchema();

    // The global schema registry.
    ISchemaRegistry private constant _schemaRegistry = ISchemaRegistry(Predeploys.SCHEMA_REGISTRY);

    // The global mapping between attestations and their UIDs.
    mapping(bytes32 uid => Attestation attestation) private _db;

    // The global mapping between data and their timestamps.
    mapping(bytes32 data => uint64 timestamp) private _timestamps;

    // The global mapping between data and their revocation timestamps.
    mapping(address revoker => mapping(bytes32 data => uint64 timestamp)) private _revocationsOffchain;

    // Upgrade forward-compatibility storage gap
    uint256[MAX_GAP - 3] private __gap;

    /// @dev Creates a new EAS instance.
    constructor() Semver(1, 0, 1) EIP712Verifier("EAS", "1.0.1") {
    }

    /// @inheritdoc IEAS
    function getSchemaRegistry() external pure returns (ISchemaRegistry) {
        return _schemaRegistry;
    }

    /// @inheritdoc IEAS
    function attest(AttestationRequest calldata request) external payable returns (bytes32) {
        AttestationRequestData[] memory requests = new AttestationRequestData[](1);
        requests[0] = request.data;
        return _attest(request.schema, requests, msg.sender, msg.value, true).uids[0];
    }

    /// @inheritdoc IEAS
    function attestByDelegation(
        DelegatedAttestationRequest calldata delegatedRequest
    ) external payable returns (bytes32) {
        _verifyAttest(delegatedRequest);

        AttestationRequestData[] memory data = new AttestationRequestData[](1);
        data[0] = delegatedRequest.data;
        return _attest(delegatedRequest.schema, data, delegatedRequest.attester, msg.value, true).uids[0];
    }

    /// @inheritdoc IEAS
    function multiAttest(MultiAttestationRequest[] calldata multiRequests) external payable returns (bytes32[] memory) {
        // Since a multi-attest call is going to make multiple attestations for multiple schemas, we'd need to collect
        // all the returned UIDs into a single list.
        bytes32[][] memory totalUids = new bytes32[][](multiRequests.length);
        uint256 totalUidsCount = 0;

        // We are keeping track of the total available ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint availableValue = msg.value;

        for (uint256 i = 0; i < multiRequests.length; i = uncheckedInc(i)) {
            // The last batch is handled slightly differently: if the total available ETH wasn't spent in full and there
            // is a remainder - it will be refunded back to the attester (something that we can only verify during the
            // last and final batch).
            bool last;
            unchecked {
                last = i == multiRequests.length - 1;
            }

            // Process the current batch of attestations.
            MultiAttestationRequest calldata multiRequest = multiRequests[i];
            AttestationsResult memory res = _attest(
                multiRequest.schema,
                multiRequest.data,
                msg.sender,
                availableValue,
                last
            );

            // Ensure to deduct the ETH that was forwarded to the resolver during the processing of this batch.
            availableValue -= res.usedValue;

            // Collect UIDs (and merge them later).
            totalUids[i] = res.uids;
            unchecked {
                totalUidsCount += res.uids.length;
            }
        }

        // Merge all the collected UIDs and return them as a flatten array.
        return _mergeUIDs(totalUids, totalUidsCount);
    }

    /// @inheritdoc IEAS
    function multiAttestByDelegation(
        MultiDelegatedAttestationRequest[] calldata multiDelegatedRequests
    ) external payable returns (bytes32[] memory) {
        // Since a multi-attest call is going to make multiple attestations for multiple schemas, we'd need to collect
        // all the returned UIDs into a single list.
        bytes32[][] memory totalUids = new bytes32[][](multiDelegatedRequests.length);
        uint256 totalUidsCount = 0;

        // We are keeping track of the total available ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint availableValue = msg.value;

        for (uint256 i = 0; i < multiDelegatedRequests.length; i = uncheckedInc(i)) {
            // The last batch is handled slightly differently: if the total available ETH wasn't spent in full and there
            // is a remainder - it will be refunded back to the attester (something that we can only verify during the
            // last and final batch).
            bool last;
            unchecked {
                last = i == multiDelegatedRequests.length - 1;
            }

            MultiDelegatedAttestationRequest calldata multiDelegatedRequest = multiDelegatedRequests[i];
            AttestationRequestData[] calldata data = multiDelegatedRequest.data;

            // Ensure that no inputs are missing.
            if (data.length == 0 || data.length != multiDelegatedRequest.signatures.length) {
                revert InvalidLength();
            }

            // Verify EIP712 signatures. Please note that the signatures are assumed to be signed with increasing nonces.
            for (uint256 j = 0; j < data.length; j = uncheckedInc(j)) {
                _verifyAttest(
                    DelegatedAttestationRequest({
                        schema: multiDelegatedRequest.schema,
                        data: data[j],
                        signature: multiDelegatedRequest.signatures[j],
                        attester: multiDelegatedRequest.attester
                    })
                );
            }

            // Process the current batch of attestations.
            AttestationsResult memory res = _attest(
                multiDelegatedRequest.schema,
                data,
                multiDelegatedRequest.attester,
                availableValue,
                last
            );

            // Ensure to deduct the ETH that was forwarded to the resolver during the processing of this batch.
            availableValue -= res.usedValue;

            // Collect UIDs (and merge them later).
            totalUids[i] = res.uids;
            unchecked {
                totalUidsCount += res.uids.length;
            }
        }

        // Merge all the collected UIDs and return them as a flatten array.
        return _mergeUIDs(totalUids, totalUidsCount);
    }

    /// @inheritdoc IEAS
    function revoke(RevocationRequest calldata request) external payable {
        RevocationRequestData[] memory requests = new RevocationRequestData[](1);
        requests[0] = request.data;

        _revoke(request.schema, requests, msg.sender, msg.value, true);
    }

    /// @inheritdoc IEAS
    function revokeByDelegation(DelegatedRevocationRequest calldata delegatedRequest) external payable {
        _verifyRevoke(delegatedRequest);

        RevocationRequestData[] memory data = new RevocationRequestData[](1);
        data[0] = delegatedRequest.data;

        _revoke(delegatedRequest.schema, data, delegatedRequest.revoker, msg.value, true);
    }

    /// @inheritdoc IEAS
    function multiRevoke(MultiRevocationRequest[] calldata multiRequests) external payable {
        // We are keeping track of the total available ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint availableValue = msg.value;

        for (uint256 i = 0; i < multiRequests.length; i = uncheckedInc(i)) {
            // The last batch is handled slightly differently: if the total available ETH wasn't spent in full and there
            // is a remainder - it will be refunded back to the attester (something that we can only verify during the
            // last and final batch).
            bool last;
            unchecked {
                last = i == multiRequests.length - 1;
            }

            MultiRevocationRequest calldata multiRequest = multiRequests[i];

            // Ensure to deduct the ETH that was forwarded to the resolver during the processing of this batch.
            availableValue -= _revoke(multiRequest.schema, multiRequest.data, msg.sender, availableValue, last);
        }
    }

    /// @inheritdoc IEAS
    function multiRevokeByDelegation(
        MultiDelegatedRevocationRequest[] calldata multiDelegatedRequests
    ) external payable {
        // We are keeping track of the total available ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint availableValue = msg.value;

        for (uint256 i = 0; i < multiDelegatedRequests.length; i = uncheckedInc(i)) {
            // The last batch is handled slightly differently: if the total available ETH wasn't spent in full and there
            // is a remainder - it will be refunded back to the attester (something that we can only verify during the
            // last and final batch).
            bool last;
            unchecked {
                last = i == multiDelegatedRequests.length - 1;
            }

            MultiDelegatedRevocationRequest memory multiDelegatedRequest = multiDelegatedRequests[i];
            RevocationRequestData[] memory data = multiDelegatedRequest.data;

            // Ensure that no inputs are missing.
            if (data.length == 0 || data.length != multiDelegatedRequest.signatures.length) {
                revert InvalidLength();
            }

            // Verify EIP712 signatures. Please note that the signatures are assumed to be signed with increasing nonces.
            for (uint256 j = 0; j < data.length; j = uncheckedInc(j)) {
                _verifyRevoke(
                    DelegatedRevocationRequest({
                        schema: multiDelegatedRequest.schema,
                        data: data[j],
                        signature: multiDelegatedRequest.signatures[j],
                        revoker: multiDelegatedRequest.revoker
                    })
                );
            }

            // Ensure to deduct the ETH that was forwarded to the resolver during the processing of this batch.
            availableValue -= _revoke(
                multiDelegatedRequest.schema,
                data,
                multiDelegatedRequest.revoker,
                availableValue,
                last
            );
        }
    }

    /// @inheritdoc IEAS
    function timestamp(bytes32 data) external returns (uint64) {
        uint64 time = _time();
        _timestamp(data, time);
        return time;
    }

    /// @inheritdoc IEAS
    function revokeOffchain(bytes32 data) external returns (uint64) {
        uint64 time = _time();
        _revokeOffchain(msg.sender, data, time);
        return time;
    }

    /// @inheritdoc IEAS
    function multiRevokeOffchain(bytes32[] calldata data) external returns (uint64) {
        uint64 time = _time();

        uint256 length = data.length;
        for (uint256 i = 0; i < length; i = uncheckedInc(i)) {
            _revokeOffchain(msg.sender, data[i], time);
        }

        return time;
    }

    /// @inheritdoc IEAS
    function multiTimestamp(bytes32[] calldata data) external returns (uint64) {
        uint64 time = _time();

        uint256 length = data.length;
        for (uint256 i = 0; i < length; i = uncheckedInc(i)) {
            _timestamp(data[i], time);
        }

        return time;
    }

    /// @inheritdoc IEAS
    function getAttestation(bytes32 uid) external view returns (Attestation memory) {
        return _db[uid];
    }

    /// @inheritdoc IEAS
    function isAttestationValid(bytes32 uid) public view returns (bool) {
        return _db[uid].uid != 0;
    }

    /// @inheritdoc IEAS
    function getTimestamp(bytes32 data) external view returns (uint64) {
        return _timestamps[data];
    }

    /// @inheritdoc IEAS
    function getRevokeOffchain(address revoker, bytes32 data) external view returns (uint64) {
        return _revocationsOffchain[revoker][data];
    }

    /// @dev Attests to a specific schema.
    /// @param schema // the unique identifier of the schema to attest to.
    /// @param data The arguments of the attestation requests.
    /// @param attester The attesting account.
    /// @param availableValue The total available ETH amount that can be sent to the resolver.
    /// @param last Whether this is the last attestations/revocations set.
    /// @return The UID of the new attestations and the total sent ETH amount.
    function _attest(
        bytes32 schema,
        AttestationRequestData[] memory data,
        address attester,
        uint256 availableValue,
        bool last
    ) private returns (AttestationsResult memory) {
        uint256 length = data.length;

        AttestationsResult memory res;
        res.uids = new bytes32[](length);

        // Ensure that we aren't attempting to attest to a non-existing schema.
        SchemaRecord memory schemaRecord = _schemaRegistry.getSchema(schema);
        if (schemaRecord.uid == EMPTY_UID) {
            revert InvalidSchema();
        }

        Attestation[] memory attestations = new Attestation[](length);
        uint256[] memory values = new uint256[](length);

        for (uint256 i = 0; i < length; i = uncheckedInc(i)) {
            AttestationRequestData memory request = data[i];

            // Ensure that either no expiration time was set or that it was set in the future.
            if (request.expirationTime != NO_EXPIRATION_TIME && request.expirationTime <= _time()) {
                revert InvalidExpirationTime();
            }

            // Ensure that we aren't trying to make a revocable attestation for a non-revocable schema.
            if (!schemaRecord.revocable && request.revocable) {
                revert Irrevocable();
            }

            Attestation memory attestation = Attestation({
                uid: EMPTY_UID,
                schema: schema,
                refUID: request.refUID,
                time: _time(),
                expirationTime: request.expirationTime,
                revocationTime: 0,
                recipient: request.recipient,
                attester: attester,
                revocable: request.revocable,
                data: request.data
            });

            // Look for the first non-existing UID (and use a bump seed/nonce in the rare case of a conflict).
            bytes32 uid;
            uint32 bump = 0;
            while (true) {
                uid = _getUID(attestation, bump);
                if (_db[uid].uid == EMPTY_UID) {
                    break;
                }

                unchecked {
                    ++bump;
                }
            }
            attestation.uid = uid;

            _db[uid] = attestation;

            if (request.refUID != 0) {
                // Ensure that we aren't trying to attest to a non-existing referenced UID.
                if (!isAttestationValid(request.refUID)) {
                    revert NotFound();
                }
            }

            attestations[i] = attestation;
            values[i] = request.value;

            res.uids[i] = uid;

            emit Attested(request.recipient, attester, uid, schema);
        }

        res.usedValue = _resolveAttestations(schemaRecord, attestations, values, false, availableValue, last);

        return res;
    }

    /// @dev Revokes an existing attestation to a specific schema.
    /// @param schema The unique identifier of the schema to attest to.
    /// @param data The arguments of the revocation requests.
    /// @param revoker The revoking account.
    /// @param availableValue The total available ETH amount that can be sent to the resolver.
    /// @param last Whether this is the last attestations/revocations set.
    /// @return Returns the total sent ETH amount.
    function _revoke(
        bytes32 schema,
        RevocationRequestData[] memory data,
        address revoker,
        uint256 availableValue,
        bool last
    ) private returns (uint256) {
        // Ensure that a non-existing schema ID wasn't passed by accident.
        SchemaRecord memory schemaRecord = _schemaRegistry.getSchema(schema);
        if (schemaRecord.uid == EMPTY_UID) {
            revert InvalidSchema();
        }

        uint256 length = data.length;
        Attestation[] memory attestations = new Attestation[](length);
        uint256[] memory values = new uint256[](length);

        for (uint256 i = 0; i < length; i = uncheckedInc(i)) {
            RevocationRequestData memory request = data[i];

            Attestation storage attestation = _db[request.uid];

            // Ensure that we aren't attempting to revoke a non-existing attestation.
            if (attestation.uid == EMPTY_UID) {
                revert NotFound();
            }

            // Ensure that a wrong schema ID wasn't passed by accident.
            if (attestation.schema != schema) {
                revert InvalidSchema();
            }

            // Allow only original attesters to revoke their attestations.
            if (attestation.attester != revoker) {
                revert AccessDenied();
            }

            // Please note that also checking of the schema itself is revocable is unnecessary, since it's not possible to
            // make revocable attestations to an irrevocable schema.
            if (!attestation.revocable) {
                revert Irrevocable();
            }

            // Ensure that we aren't trying to revoke the same attestation twice.
            if (attestation.revocationTime != 0) {
                revert AlreadyRevoked();
            }
            attestation.revocationTime = _time();

            attestations[i] = attestation;
            values[i] = request.value;

            emit Revoked(attestation.recipient, revoker, request.uid, attestation.schema);
        }

        return _resolveAttestations(schemaRecord, attestations, values, true, availableValue, last);
    }

    /// @dev Resolves a new attestation or a revocation of an existing attestation.
    /// @param schemaRecord The schema of the attestation.
    /// @param attestation The data of the attestation to make/revoke.
    /// @param value An explicit ETH amount to send to the resolver.
    /// @param isRevocation Whether to resolve an attestation or its revocation.
    /// @param availableValue The total available ETH amount that can be sent to the resolver.
    /// @param last Whether this is the last attestations/revocations set.
    /// @return Returns the total sent ETH amount.
    function _resolveAttestation(
        SchemaRecord memory schemaRecord,
        Attestation memory attestation,
        uint256 value,
        bool isRevocation,
        uint256 availableValue,
        bool last
    ) private returns (uint256) {
        ISchemaResolver resolver = schemaRecord.resolver;
        if (address(resolver) == address(0)) {
            // Ensure that we don't accept payments if there is no resolver.
            if (value != 0) {
                revert NotPayable();
            }

            return 0;
        }

        // Ensure that we don't accept payments which can't be forwarded to the resolver.
        if (value != 0 && !resolver.isPayable()) {
            revert NotPayable();
        }

        // Ensure that the attester/revoker doesn't try to spend more than available.
        if (value > availableValue) {
            revert InsufficientValue();
        }

        // Ensure to deduct the sent value explicitly.
        unchecked {
            availableValue -= value;
        }

        if (isRevocation) {
            if (!resolver.revoke{ value: value }(attestation)) {
                revert InvalidRevocation();
            }
        } else if (!resolver.attest{ value: value }(attestation)) {
            revert InvalidAttestation();
        }

        if (last) {
            _refund(availableValue);
        }

        return value;
    }

    /// @dev Resolves multiple attestations or revocations of existing attestations.
    /// @param schemaRecord The schema of the attestation.
    /// @param attestations The data of the attestations to make/revoke.
    /// @param values Explicit ETH amounts to send to the resolver.
    /// @param isRevocation Whether to resolve an attestation or its revocation.
    /// @param availableValue The total available ETH amount that can be sent to the resolver.
    /// @param last Whether this is the last attestations/revocations set.
    /// @return Returns the total sent ETH amount.
    function _resolveAttestations(
        SchemaRecord memory schemaRecord,
        Attestation[] memory attestations,
        uint256[] memory values,
        bool isRevocation,
        uint256 availableValue,
        bool last
    ) private returns (uint256) {
        uint256 length = attestations.length;
        if (length == 1) {
            return _resolveAttestation(schemaRecord, attestations[0], values[0], isRevocation, availableValue, last);
        }

        ISchemaResolver resolver = schemaRecord.resolver;
        if (address(resolver) == address(0)) {
            // Ensure that we don't accept payments if there is no resolver.
            for (uint256 i = 0; i < length; i = uncheckedInc(i)) {
                if (values[i] != 0) {
                    revert NotPayable();
                }
            }

            return 0;
        }

        uint256 totalUsedValue = 0;

        for (uint256 i = 0; i < length; i = uncheckedInc(i)) {
            uint256 value = values[i];

            // Ensure that we don't accept payments which can't be forwarded to the resolver.
            if (value != 0 && !resolver.isPayable()) {
                revert NotPayable();
            }

            // Ensure that the attester/revoker doesn't try to spend more than available.
            if (value > availableValue) {
                revert InsufficientValue();
            }

            // Ensure to deduct the sent value explicitly and add it to the total used value by the batch.
            unchecked {
                availableValue -= value;
                totalUsedValue += value;
            }
        }

        if (isRevocation) {
            if (!resolver.multiRevoke{ value: totalUsedValue }(attestations, values)) {
                revert InvalidRevocations();
            }
        } else if (!resolver.multiAttest{ value: totalUsedValue }(attestations, values)) {
            revert InvalidAttestations();
        }

        if (last) {
            _refund(availableValue);
        }

        return totalUsedValue;
    }

    /// @dev Calculates a UID for a given attestation.
    /// @param attestation The input attestation.
    /// @param bump A bump value to use in case of a UID conflict.
    /// @return Attestation UID.
    function _getUID(Attestation memory attestation, uint32 bump) private pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    attestation.schema,
                    attestation.recipient,
                    attestation.attester,
                    attestation.time,
                    attestation.expirationTime,
                    attestation.revocable,
                    attestation.refUID,
                    attestation.data,
                    bump
                )
            );
    }

    /// @dev Refunds remaining ETH amount to the attester.
    /// @param remainingValue The remaining ETH amount that was not sent to the resolver.
    function _refund(uint256 remainingValue) private {
        if (remainingValue > 0) {
            // Using a regular transfer here might revert, for some non-EOA attesters, due to exceeding of the 2300
            // gas limit which is why we're using call instead (via sendValue), which the 2300 gas limit does not
            // apply for.
            payable(msg.sender).sendValue(remainingValue);
        }
    }

    /// @dev Timestamps the specified bytes32 data.
    /// @param data The data to timestamp.
    /// @param time The timestamp.
    function _timestamp(bytes32 data, uint64 time) private {
        if (_timestamps[data] != 0) {
            revert AlreadyTimestamped();
        }

        _timestamps[data] = time;

        emit Timestamped(data, time);
    }

    /// @dev Timestamps the specified bytes32 data.
    /// @param data The data to timestamp.
    /// @param time The timestamp.
    function _revokeOffchain(address revoker, bytes32 data, uint64 time) private {
        mapping(bytes32 => uint64) storage revocations = _revocationsOffchain[revoker];

        if (revocations[data] != 0) {
            revert AlreadyRevokedOffchain();
        }

        revocations[data] = time;

        emit RevokedOffchain(revoker, data, time);
    }

    /// @dev Returns the current's block timestamp.
    ///      This method is overridden during tests and
    ///      used to simulate the current block time.
    function _time() internal view virtual returns (uint64) {
        return uint64(block.timestamp);
    }

    /// @dev Merges lists of UIDs.
    /// @param uidLists The provided lists of UIDs.
    /// @param uidsCount Total UIDs count.
    /// @return A merged and flatten list of all the UIDs.
    function _mergeUIDs(bytes32[][] memory uidLists, uint256 uidsCount) private pure returns (bytes32[] memory) {
        bytes32[] memory uids = new bytes32[](uidsCount);

        uint256 currentIndex = 0;
        for (uint256 i = 0; i < uidLists.length; i = uncheckedInc(i)) {
            bytes32[] memory currentUids = uidLists[i];
            for (uint256 j = 0; j < currentUids.length; j = uncheckedInc(j)) {
                uids[currentIndex] = currentUids[j];

                unchecked {
                    ++currentIndex;
                }
            }
        }

        return uids;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
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
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
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
                /// @solidity memory-safe-assembly
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @title Semver
/// @notice Semver is a simple contract for managing contract versions.
contract Semver {
    /// @notice Contract version number (major).
    uint256 private immutable MAJOR_VERSION;

    /// @notice Contract version number (minor).
    uint256 private immutable MINOR_VERSION;

    /// @notice Contract version number (patch).
    uint256 private immutable PATCH_VERSION;

    /// @param _major Version number (major).
    /// @param _minor Version number (minor).
    /// @param _patch Version number (patch).
    constructor(
        uint256 _major,
        uint256 _minor,
        uint256 _patch
    ) {
        MAJOR_VERSION = _major;
        MINOR_VERSION = _minor;
        PATCH_VERSION = _patch;
    }

    /// @notice Returns the full semver contract version.
    /// @return Semver contract version as a string.
    function version() public view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    Strings.toString(MAJOR_VERSION),
                    ".",
                    Strings.toString(MINOR_VERSION),
                    ".",
                    Strings.toString(PATCH_VERSION)
                )
            );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Predeploys
/// @notice Contains constant addresses for contracts that are pre-deployed to the L2 system.
library Predeploys {
    /// @notice Address of the L2ToL1MessagePasser predeploy.
    address internal constant L2_TO_L1_MESSAGE_PASSER = 0x4200000000000000000000000000000000000016;

    /// @notice Address of the L2CrossDomainMessenger predeploy.
    address internal constant L2_CROSS_DOMAIN_MESSENGER =
        0x4200000000000000000000000000000000000007;

    /// @notice Address of the L2StandardBridge predeploy.
    address internal constant L2_STANDARD_BRIDGE = 0x4200000000000000000000000000000000000010;

    /// @notice Address of the L2ERC721Bridge predeploy.
    address internal constant L2_ERC721_BRIDGE = 0x4200000000000000000000000000000000000014;

    //// @notice Address of the SequencerFeeWallet predeploy.
    address internal constant SEQUENCER_FEE_WALLET = 0x4200000000000000000000000000000000000011;

    /// @notice Address of the OptimismMintableERC20Factory predeploy.
    address internal constant OPTIMISM_MINTABLE_ERC20_FACTORY =
        0x4200000000000000000000000000000000000012;

    /// @notice Address of the OptimismMintableERC721Factory predeploy.
    address internal constant OPTIMISM_MINTABLE_ERC721_FACTORY =
        0x4200000000000000000000000000000000000017;

    /// @notice Address of the L1Block predeploy.
    address internal constant L1_BLOCK_ATTRIBUTES = 0x4200000000000000000000000000000000000015;

    /// @notice Address of the GasPriceOracle predeploy. Includes fee information
    ///         and helpers for computing the L1 portion of the transaction fee.
    address internal constant GAS_PRICE_ORACLE = 0x420000000000000000000000000000000000000F;

    /// @custom:legacy
    /// @notice Address of the L1MessageSender predeploy. Deprecated. Use L2CrossDomainMessenger
    ///         or access tx.origin (or msg.sender) in a L1 to L2 transaction instead.
    address internal constant L1_MESSAGE_SENDER = 0x4200000000000000000000000000000000000001;

    /// @custom:legacy
    /// @notice Address of the DeployerWhitelist predeploy. No longer active.
    address internal constant DEPLOYER_WHITELIST = 0x4200000000000000000000000000000000000002;

    /// @custom:legacy
    /// @notice Address of the LegacyERC20ETH predeploy. Deprecated. Balances are migrated to the
    ///         state trie as of the Bedrock upgrade. Contract has been locked and write functions
    ///         can no longer be accessed.
    address internal constant LEGACY_ERC20_ETH = 0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000;

    /// @custom:legacy
    /// @notice Address of the L1BlockNumber predeploy. Deprecated. Use the L1Block predeploy
    ///         instead, which exposes more information about the L1 state.
    address internal constant L1_BLOCK_NUMBER = 0x4200000000000000000000000000000000000013;

    /// @custom:legacy
    /// @notice Address of the LegacyMessagePasser predeploy. Deprecate. Use the updated
    ///         L2ToL1MessagePasser contract instead.
    address internal constant LEGACY_MESSAGE_PASSER = 0x4200000000000000000000000000000000000000;

    /// @notice Address of the ProxyAdmin predeploy.
    address internal constant PROXY_ADMIN = 0x4200000000000000000000000000000000000018;

    /// @notice Address of the BaseFeeVault predeploy.
    address internal constant BASE_FEE_VAULT = 0x4200000000000000000000000000000000000019;

    /// @notice Address of the L1FeeVault predeploy.
    address internal constant L1_FEE_VAULT = 0x420000000000000000000000000000000000001A;

    /// @notice Address of the GovernanceToken predeploy.
    address internal constant GOVERNANCE_TOKEN = 0x4200000000000000000000000000000000000042;

    /// @notice Address of the SchemaRegistry predeploy.
    address internal constant SCHEMA_REGISTRY = 0x4200000000000000000000000000000000000020;

    /// @notice Address of the EAS predeploy.
    address internal constant EAS = 0x4200000000000000000000000000000000000021;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// prettier-ignore
import {
    AttestationRequest,
    AttestationRequestData,
    DelegatedAttestationRequest,
    DelegatedRevocationRequest,
    RevocationRequest,
    RevocationRequestData
} from "../IEAS.sol";

import { EIP712Signature, InvalidSignature, MAX_GAP, stringToBytes32, bytes32ToString } from "../Common.sol";

/// @title EIP712
/// @notice The EIP712 typed signatures verifier for EAS delegated attestations.
abstract contract EIP712Verifier is EIP712 {
    // The hash of the data type used to relay calls to the attest function. It's the value of
    // keccak256("Attest(bytes32 schema,address recipient,uint64 expirationTime,bool revocable,bytes32 refUID,bytes data,uint256 nonce)").
    bytes32 private constant ATTEST_TYPEHASH = 0xdbfdf8dc2b135c26253e00d5b6cbe6f20457e003fd526d97cea183883570de61;

    // The hash of the data type used to relay calls to the revoke function. It's the value of
    // keccak256("Revoke(bytes32 schema,bytes32 uid,uint256 nonce)").
    bytes32 private constant REVOKE_TYPEHASH = 0xa98d02348410c9c76735e0d0bb1396f4015ac2bb9615f9c2611d19d7a8a99650;

    // The user readable name of the signing domain.
    bytes32 private immutable _name;

    // Replay protection nonces.
    mapping(address => uint256) private _nonces;

    // Upgrade forward-compatibility storage gap
    uint256[MAX_GAP - 1] private __gap;

    /// @dev Creates a new EIP712Verifier instance.
    /// @param version The current major version of the signing domain
    constructor(string memory name, string memory version) EIP712(name, version) {
        _name = stringToBytes32(name);
    }

    /// @notice Returns the domain separator used in the encoding of the signatures for attest, and revoke.
    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @notice Returns the current nonce per-account.
    /// @param account The requested account.
    /// @return The current nonce.
    function getNonce(address account) external view returns (uint256) {
        return _nonces[account];
    }

    /// @notice Returns the EIP712 type hash for the attest function.
    /// @return The EIP712 attest function type hash.
    function getAttestTypeHash() external pure returns (bytes32) {
        return ATTEST_TYPEHASH;
    }

    /// @notice Returns the EIP712 type hash for the revoke function.
    /// @return hash_ The EIP712 revoke function type hash.
    function getRevokeTypeHash() external pure returns (bytes32) {
        return REVOKE_TYPEHASH;
    }

    /// @notice Returns the EIP712 name.
    /// @return The EIP712 name.
    function getName() external view returns (string memory) {
        return bytes32ToString(_name);
    }

    /// @notice Verifies delegated attestation request.
    /// @param request The arguments of the delegated attestation request.
    function _verifyAttest(DelegatedAttestationRequest memory request) internal {
        AttestationRequestData memory data = request.data;
        EIP712Signature memory signature = request.signature;

        uint256 nonce;
        unchecked {
            nonce = _nonces[request.attester]++;
        }

        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    ATTEST_TYPEHASH,
                    request.schema,
                    data.recipient,
                    data.expirationTime,
                    data.revocable,
                    data.refUID,
                    keccak256(data.data),
                    nonce
                )
            )
        );

        if (ECDSA.recover(digest, signature.v, signature.r, signature.s) != request.attester) {
            revert InvalidSignature();
        }
    }

    /// @notice Verifies delegated revocation request.
    /// @param request The arguments of the delegated revocation request.
    function _verifyRevoke(DelegatedRevocationRequest memory request) internal {
        RevocationRequestData memory data = request.data;
        EIP712Signature memory signature = request.signature;

        uint256 nonce;
        unchecked {
            nonce = _nonces[request.revoker]++;
        }

        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(REVOKE_TYPEHASH, request.schema, data.uid, nonce)));

        if (ECDSA.recover(digest, signature.v, signature.r, signature.s) != request.revoker) {
            revert InvalidSignature();
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Attestation } from "../Common.sol";

/// @title ISchemaResolver
/// @notice The interface of an optional schema resolver.
interface ISchemaResolver {
    /// @notice Checks if the resolve can be sent ETH.
    /// @return Whether the resolver supports ETH transfers.
    function isPayable() external pure returns (bool);

    /// @notice Processes an attestation and verifies whether it's valid.
    /// @param attestation The new attestation.
    /// @return Whether the attestation is valid.
    function attest(Attestation calldata attestation) external payable returns (bool);

    /// @notice Processes multiple attestations and verifies whether they are valid.
    /// @param attestations The new attestations.
    /// @param values Explicit ETH amounts which were sent with each attestation.
    /// @return Whether all the attestations are valid.
    function multiAttest(
        Attestation[] calldata attestations,
        uint256[] calldata values
    ) external payable returns (bool);

    /// @notice Processes an attestation revocation and verifies if it can be revoked.
    /// @param attestation The existing attestation to be revoked.
    /// @return Whether the attestation can be revoked.
    function revoke(Attestation calldata attestation) external payable returns (bool);

    /// @notice Processes revocation of multiple attestation and verifies they can be revoked.
    /// @param attestations The existing attestations to be revoked.
    /// @param values Explicit ETH amounts which were sent with each revocation.
    /// @return Whether the attestations can be revoked.
    function multiRevoke(
        Attestation[] calldata attestations,
        uint256[] calldata values
    ) external payable returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// A representation of an empty/uninitialized UID.
bytes32 constant EMPTY_UID = 0;

// A zero expiration represents an non-expiring attestation.
uint64 constant NO_EXPIRATION_TIME = 0;

error AccessDenied();
error InvalidEAS();
error InvalidLength();
error InvalidSignature();
error NotFound();

/// @dev A struct representing EIP712 signature data.
struct EIP712Signature {
    uint8 v; // The recovery ID.
    bytes32 r; // The x-coordinate of the nonce R.
    bytes32 s; // The signature data.
}

/// @dev A struct representing a single attestation.
struct Attestation {
    bytes32 uid; // A unique identifier of the attestation.
    bytes32 schema; // The unique identifier of the schema.
    uint64 time; // The time when the attestation was created (Unix timestamp).
    uint64 expirationTime; // The time when the attestation expires (Unix timestamp).
    uint64 revocationTime; // The time when the attestation was revoked (Unix timestamp).
    bytes32 refUID; // The UID of the related attestation.
    address recipient; // The recipient of the attestation.
    address attester; // The attester/sender of the attestation.
    bool revocable; // Whether the attestation is revocable.
    bytes data; // Custom attestation data.
}

// Maximum upgrade forward-compatibility storage gap.
uint32 constant MAX_GAP = 50;

/// @dev A helper function to work with unchecked iterators in loops.
/// @param i The index to increment.
/// @return j The incremented index.
function uncheckedInc(uint256 i) pure returns (uint256 j) {
    unchecked {
        j = i + 1;
    }
}

/// @dev A helper function that converts a string to a bytes32.
/// @param str The string to convert.
/// @return The converted bytes32.
function stringToBytes32(string memory str) pure returns (bytes32) {
    bytes32 result;

    assembly {
        result := mload(add(str, 32))
    }

    return result;
}

/// @dev A helper function that converts a bytes32 to a string.
/// @param data The bytes32 data to convert.
/// @return The converted string.
function bytes32ToString(bytes32 data) pure returns (string memory) {
    bytes memory byteArray = new bytes(32);

    uint256 length = 0;
    for (uint256 i = 0; i < 32; i = uncheckedInc(i)) {
        bytes1 char = data[i];
        if (char == 0x00) {
            break;
        }

        byteArray[length] = char;
        length = uncheckedInc(length);
    }

    bytes memory terminatedBytes = new bytes(length);
    for (uint256 j = 0; j < length; j = uncheckedInc(j)) {
        terminatedBytes[j] = byteArray[j];
    }

    return string(terminatedBytes);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ISchemaRegistry } from "./ISchemaRegistry.sol";
import { Attestation, EIP712Signature } from "./Common.sol";

/// @dev A struct representing the arguments of the attestation request.
struct AttestationRequestData {
    address recipient; // The recipient of the attestation.
    uint64 expirationTime; // The time when the attestation expires (Unix timestamp).
    bool revocable; // Whether the attestation is revocable.
    bytes32 refUID; // The UID of the related attestation.
    bytes data; // Custom attestation data.
    uint256 value; // An explicit ETH amount to send to the resolver. This is important to prevent accidental user errors.
}

/// @dev A struct representing the full arguments of the attestation request.
struct AttestationRequest {
    bytes32 schema; // The unique identifier of the schema.
    AttestationRequestData data; // The arguments of the attestation request.
}

/// @dev A struct representing the full arguments of the full delegated attestation request.
struct DelegatedAttestationRequest {
    bytes32 schema; // The unique identifier of the schema.
    AttestationRequestData data; // The arguments of the attestation request.
    EIP712Signature signature; // The EIP712 signature data.
    address attester; // The attesting account.
}

/// @dev A struct representing the full arguments of the multi attestation request.
struct MultiAttestationRequest {
    bytes32 schema; // The unique identifier of the schema.
    AttestationRequestData[] data; // The arguments of the attestation request.
}

/// @dev A struct representing the full arguments of the delegated multi attestation request.
struct MultiDelegatedAttestationRequest {
    bytes32 schema; // The unique identifier of the schema.
    AttestationRequestData[] data; // The arguments of the attestation requests.
    EIP712Signature[] signatures; // The EIP712 signatures data. Please note that the signatures are assumed to be signed with increasing nonces.
    address attester; // The attesting account.
}

/// @dev A struct representing the arguments of the revocation request.
struct RevocationRequestData {
    bytes32 uid; // The UID of the attestation to revoke.
    uint256 value; // An explicit ETH amount to send to the resolver. This is important to prevent accidental user errors.
}

/// @dev A struct representing the full arguments of the revocation request.
struct RevocationRequest {
    bytes32 schema; // The unique identifier of the schema.
    RevocationRequestData data; // The arguments of the revocation request.
}

/// @dev A struct representing the arguments of the full delegated revocation request.
struct DelegatedRevocationRequest {
    bytes32 schema; // The unique identifier of the schema.
    RevocationRequestData data; // The arguments of the revocation request.
    EIP712Signature signature; // The EIP712 signature data.
    address revoker; // The revoking account.
}

/// @dev A struct representing the full arguments of the multi revocation request.
struct MultiRevocationRequest {
    bytes32 schema; // The unique identifier of the schema.
    RevocationRequestData[] data; // The arguments of the revocation request.
}

/// @dev A struct representing the full arguments of the delegated multi revocation request.
struct MultiDelegatedRevocationRequest {
    bytes32 schema; // The unique identifier of the schema.
    RevocationRequestData[] data; // The arguments of the revocation requests.
    EIP712Signature[] signatures; // The EIP712 signatures data. Please note that the signatures are assumed to be signed with increasing nonces.
    address revoker; // The revoking account.
}

/// @title IEAS
/// @notice The Ethereum Attestation Service interface.
interface IEAS {
    /// @dev Emitted when an attestation has been made.
    /// @param recipient The recipient of the attestation.
    /// @param attester The attesting account.
    /// @param uid The UID the revoked attestation.
    /// @param schema The UID of the schema.
    event Attested(address indexed recipient, address indexed attester, bytes32 uid, bytes32 indexed schema);

    /// @dev Emitted when an attestation has been revoked.
    /// @param recipient The recipient of the attestation.
    /// @param attester The attesting account.
    /// @param schema The UID of the schema.
    /// @param uid The UID the revoked attestation.
    event Revoked(address indexed recipient, address indexed attester, bytes32 uid, bytes32 indexed schema);

    /// @dev Emitted when a data has been timestamped.
    /// @param data The data.
    /// @param timestamp The timestamp.
    event Timestamped(bytes32 indexed data, uint64 indexed timestamp);

    /// @dev Emitted when a data has been revoked.
    /// @param revoker The address of the revoker.
    /// @param data The data.
    /// @param timestamp The timestamp.
    event RevokedOffchain(address indexed revoker, bytes32 indexed data, uint64 indexed timestamp);

    /// @notice Returns the address of the global schema registry.
    /// @return The address of the global schema registry.
    function getSchemaRegistry() external view returns (ISchemaRegistry);

    /// @notice Attests to a specific schema.
    ///
    ///      Example:
    ///
    ///      attest({
    ///         schema: "0facc36681cbe2456019c1b0d1e7bedd6d1d40f6f324bf3dd3a4cef2999200a0",
    ///         data: {
    ///             recipient: "0xdEADBeAFdeAdbEafdeadbeafDeAdbEAFdeadbeaf",
    ///             expirationTime: 0,
    ///             revocable: true,
    ///             refUID: "0x0000000000000000000000000000000000000000000000000000000000000000",
    ///             data: "0xF00D",
    ///             value: 0
    ///         }
    ///      })
    ///
    /// @param request The arguments of the attestation request.
    /// @return The UID of the new attestation.
    function attest(AttestationRequest calldata request) external payable returns (bytes32);

    /// @notice Attests to a specific schema via the provided EIP712 signature.
    ///
    ///         Example:
    ///
    ///         attestByDelegation({
    ///             schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///             data: {
    ///                 recipient: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    ///                 expirationTime: 1673891048,
    ///                 revocable: true,
    ///                 refUID: '0x0000000000000000000000000000000000000000000000000000000000000000',
    ///                 data: '0x1234',
    ///                 value: 0
    ///             },
    ///             signature: {
    ///                 v: 28,
    ///                 r: '0x148c...b25b',
    ///                 s: '0x5a72...be22'
    ///             },
    ///             attester: '0xc5E8740aD971409492b1A63Db8d83025e0Fc427e'
    ///         })
    ///
    /// @param delegatedRequest The arguments of the delegated attestation request.
    /// @return The UID of the new attestation.
    function attestByDelegation(
        DelegatedAttestationRequest calldata delegatedRequest
    ) external payable returns (bytes32);

    /// @notice Attests to multiple schemas.
    ///
    ///         Example:
    ///
    ///         multiAttest([{
    ///             schema: '0x33e9094830a5cba5554d1954310e4fbed2ef5f859ec1404619adea4207f391fd',
    ///             data: [{
    ///                 recipient: '0xdEADBeAFdeAdbEafdeadbeafDeAdbEAFdeadbeaf',
    ///                 expirationTime: 1673891048,
    ///                 revocable: true,
    ///                 refUID: '0x0000000000000000000000000000000000000000000000000000000000000000',
    ///                 data: '0x1234',
    ///                 value: 1000
    ///             },
    ///             {
    ///                 recipient: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    ///                 expirationTime: 0,
    ///                 revocable: false,
    ///                 refUID: '0x480df4a039efc31b11bfdf491b383ca138b6bde160988222a2a3509c02cee174',
    ///                 data: '0x00',
    ///                 value: 0
    ///             }],
    ///         },
    ///         {
    ///             schema: '0x5ac273ce41e3c8bfa383efe7c03e54c5f0bff29c9f11ef6ffa930fc84ca32425',
    ///             data: [{
    ///                 recipient: '0xdEADBeAFdeAdbEafdeadbeafDeAdbEAFdeadbeaf',
    ///                 expirationTime: 0,
    ///                 revocable: true,
    ///                 refUID: '0x75bf2ed8dca25a8190c50c52db136664de25b2449535839008ccfdab469b214f',
    ///                 data: '0x12345678',
    ///                 value: 0
    ///             },
    ///         }])
    ///
    /// @param multiRequests The arguments of the multi attestation requests. The requests should be grouped by distinct
    ///        schema ids to benefit from the best batching optimization.
    /// @return The UIDs of the new attestations.
    function multiAttest(MultiAttestationRequest[] calldata multiRequests) external payable returns (bytes32[] memory);

    /// @notice Attests to multiple schemas using via provided EIP712 signatures.
    ///
    ///         Example:
    ///
    ///         multiAttestByDelegation([{
    ///             schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///             data: [{
    ///                 recipient: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    ///                 expirationTime: 1673891048,
    ///                 revocable: true,
    ///                 refUID: '0x0000000000000000000000000000000000000000000000000000000000000000',
    ///                 data: '0x1234',
    ///                 value: 0
    ///             },
    ///             {
    ///                 recipient: '0xdEADBeAFdeAdbEafdeadbeafDeAdbEAFdeadbeaf',
    ///                 expirationTime: 0,
    ///                 revocable: false,
    ///                 refUID: '0x0000000000000000000000000000000000000000000000000000000000000000',
    ///                 data: '0x00',
    ///                 value: 0
    ///             }],
    ///             signatures: [{
    ///                 v: 28,
    ///                 r: '0x148c...b25b',
    ///                 s: '0x5a72...be22'
    ///             },
    ///             {
    ///                 v: 28,
    ///                 r: '0x487s...67bb',
    ///                 s: '0x12ad...2366'
    ///             }],
    ///             attester: '0x1D86495b2A7B524D747d2839b3C645Bed32e8CF4'
    ///         }])
    ///
    /// @param multiDelegatedRequests The arguments of the delegated multi attestation requests. The requests should be
    ///        grouped by distinct schema ids to benefit from the best batching optimization.
    /// @return The UIDs of the new attestations.
    function multiAttestByDelegation(
        MultiDelegatedAttestationRequest[] calldata multiDelegatedRequests
    ) external payable returns (bytes32[] memory);

    /// @notice Revokes an existing attestation to a specific schema.
    ///
    ///         Example:
    ///
    ///         revoke({
    ///             schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///             data: {
    ///                 uid: '0x101032e487642ee04ee17049f99a70590c735b8614079fc9275f9dd57c00966d',
    ///                 value: 0
    ///             }
    ///         })
    ///
    /// @param request The arguments of the revocation request.
    function revoke(RevocationRequest calldata request) external payable;

    /// @notice Revokes an existing attestation to a specific schema via the provided EIP712 signature.
    ///
    ///         Example:
    ///
    ///         revokeByDelegation({
    ///             schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///             data: {
    ///                 uid: '0xcbbc12102578c642a0f7b34fe7111e41afa25683b6cd7b5a14caf90fa14d24ba',
    ///                 value: 0
    ///             },
    ///             signature: {
    ///                 v: 27,
    ///                 r: '0xb593...7142',
    ///                 s: '0x0f5b...2cce'
    ///             },
    ///             revoker: '0x244934dd3e31bE2c81f84ECf0b3E6329F5381992'
    ///         })
    ///
    /// @param delegatedRequest The arguments of the delegated revocation request.
    function revokeByDelegation(DelegatedRevocationRequest calldata delegatedRequest) external payable;

    /// @notice Revokes existing attestations to multiple schemas.
    ///
    ///         Example:
    ///
    ///         multiRevoke([{
    ///             schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///             data: [{
    ///                 uid: '0x211296a1ca0d7f9f2cfebf0daaa575bea9b20e968d81aef4e743d699c6ac4b25',
    ///                 value: 1000
    ///             },
    ///             {
    ///                 uid: '0xe160ac1bd3606a287b4d53d5d1d6da5895f65b4b4bab6d93aaf5046e48167ade',
    ///                 value: 0
    ///             }],
    ///         },
    ///         {
    ///             schema: '0x5ac273ce41e3c8bfa383efe7c03e54c5f0bff29c9f11ef6ffa930fc84ca32425',
    ///             data: [{
    ///                 uid: '0x053d42abce1fd7c8fcddfae21845ad34dae287b2c326220b03ba241bc5a8f019',
    ///                 value: 0
    ///             },
    ///         }])
    ///
    /// @param multiRequests The arguments of the multi revocation requests. The requests should be grouped by distinct
    ///        schema ids to benefit from the best batching optimization.
    function multiRevoke(MultiRevocationRequest[] calldata multiRequests) external payable;

    /// @notice Revokes existing attestations to multiple schemas via provided EIP712 signatures.
    ///
    ///         Example:
    ///
    ///         multiRevokeByDelegation([{
    ///             schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///             data: [{
    ///                 uid: '0x211296a1ca0d7f9f2cfebf0daaa575bea9b20e968d81aef4e743d699c6ac4b25',
    ///                 value: 1000
    ///             },
    ///             {
    ///                 uid: '0xe160ac1bd3606a287b4d53d5d1d6da5895f65b4b4bab6d93aaf5046e48167ade',
    ///                 value: 0
    ///             }],
    ///             signatures: [{
    ///                 v: 28,
    ///                 r: '0x148c...b25b',
    ///                 s: '0x5a72...be22'
    ///             },
    ///             {
    ///                 v: 28,
    ///                 r: '0x487s...67bb',
    ///                 s: '0x12ad...2366'
    ///             }],
    ///             revoker: '0x244934dd3e31bE2c81f84ECf0b3E6329F5381992'
    ///         }])
    ///
    /// @param multiDelegatedRequests The arguments of the delegated multi revocation attestation requests. The requests should be
    ///        grouped by distinct schema ids to benefit from the best batching optimization.
    function multiRevokeByDelegation(
        MultiDelegatedRevocationRequest[] calldata multiDelegatedRequests
    ) external payable;

    /// @notice Timestamps the specified bytes32 data.
    /// @param data The data to timestamp.
    /// @return The timestamp the data was timestamped with.
    function timestamp(bytes32 data) external returns (uint64);

    /// @notice Timestamps the specified multiple bytes32 data.
    /// @param data The data to timestamp.
    /// @return The timestamp the data was timestamped with.
    function multiTimestamp(bytes32[] calldata data) external returns (uint64);

    /// @notice Revokes the specified bytes32 data.
    /// @param data The data to timestamp.
    /// @return The timestamp the data was revoked with.
    function revokeOffchain(bytes32 data) external returns (uint64);

    /// @notice Revokes the specified multiple bytes32 data.
    /// @param data The data to timestamp.
    /// @return The timestamp the data was revoked with.
    function multiRevokeOffchain(bytes32[] calldata data) external returns (uint64);

    /// @notice Returns an existing attestation by UID.
    /// @param uid The UID of the attestation to retrieve.
    /// @return The attestation data members.
    function getAttestation(bytes32 uid) external view returns (Attestation memory);

    /// @notice Checks whether an attestation exists.
    /// @param uid The UID of the attestation to retrieve.
    /// @return Whether an attestation exists.
    function isAttestationValid(bytes32 uid) external view returns (bool);

    /// @notice Returns the timestamp that the specified data was timestamped with.
    /// @param data The data to query.
    /// @return The timestamp the data was timestamped with.
    function getTimestamp(bytes32 data) external view returns (uint64);

    /// @notice Returns the timestamp that the specified data was timestamped with.
    /// @param data The data to query.
    /// @return The timestamp the data was timestamped with.
    function getRevokeOffchain(address revoker, bytes32 data) external view returns (uint64);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ISchemaResolver } from "./resolver/ISchemaResolver.sol";

/// @title A struct representing a record for a submitted schema.
struct SchemaRecord {
    bytes32 uid; // The unique identifier of the schema.
    ISchemaResolver resolver; // Optional schema resolver.
    bool revocable; // Whether the schema allows revocations explicitly.
    string schema; // Custom specification of the schema (e.g., an ABI).
}

/// @title ISchemaRegistry
/// @notice The interface of global attestation schemas for the Ethereum Attestation Service protocol.
interface ISchemaRegistry {
    /// @dev Emitted when a new schema has been registered
    /// @param uid The schema UID.
    /// @param registerer The address of the account used to register the schema.
    event Registered(bytes32 indexed uid, address registerer);

    /// @dev Submits and reserves a new schema
    /// @param schema The schema data schema.
    /// @param resolver An optional schema resolver.
    /// @param revocable Whether the schema allows revocations explicitly.
    /// @return The UID of the new schema.
    function register(string calldata schema, ISchemaResolver resolver, bool revocable) external returns (bytes32);

    /// @dev Returns an existing schema by UID
    /// @param uid The UID of the schema to retrieve.
    /// @return The schema data members.
    function getSchema(bytes32 uid) external view returns (SchemaRecord memory);
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
// OpenZeppelin Contracts v4.4.1 (utils/cryptography/draft-EIP712.sol)

pragma solidity ^0.8.0;

import "./ECDSA.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding specified in the EIP is very generic, and such a generic implementation in Solidity is not feasible,
 * thus this contract does not implement the encoding itself. Protocols need to implement the type-specific encoding
 * they need in their contracts using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * _Available since v3.4._
 */
abstract contract EIP712 {
    /* solhint-disable var-name-mixedcase */
    // Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
    // invalidate the cached domain separator if the chain id changes.
    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;
    address private immutable _CACHED_THIS;

    bytes32 private immutable _HASHED_NAME;
    bytes32 private immutable _HASHED_VERSION;
    bytes32 private immutable _TYPE_HASH;

    /* solhint-enable var-name-mixedcase */

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     *
     * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
     * contract upgrade].
     */
    constructor(string memory name, string memory version) {
        bytes32 hashedName = keccak256(bytes(name));
        bytes32 hashedVersion = keccak256(bytes(version));
        bytes32 typeHash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(typeHash, hashedName, hashedVersion);
        _CACHED_THIS = address(this);
        _TYPE_HASH = typeHash;
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        if (address(this) == _CACHED_THIS && block.chainid == _CACHED_CHAIN_ID) {
            return _CACHED_DOMAIN_SEPARATOR;
        } else {
            return _buildDomainSeparator(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION);
        }
    }

    function _buildDomainSeparator(
        bytes32 typeHash,
        bytes32 nameHash,
        bytes32 versionHash
    ) private view returns (bytes32) {
        return keccak256(abi.encode(typeHash, nameHash, versionHash, block.chainid, address(this)));
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return ECDSA.toTypedDataHash(_domainSeparatorV4(), structHash);
    }
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