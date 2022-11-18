pragma solidity 0.8.14;
pragma experimental ABIEncoderV2;

struct BeaconBlockHeader {
    uint64 slot;
    uint64 proposerIndex;
    bytes32 parentRoot;
    bytes32 stateRoot;
    bytes32 bodyRoot;
}

library SSZ {
    function toLittleEndian(uint256 x) internal pure returns (bytes32) {
        bytes32 res;
        for (uint256 i = 0; i < 32; i++) {
            res = (res << 8) | bytes32(x & 0xff);
            x >>= 8;
        }
        return res;
    }

    function restoreMerkleRoot(bytes32 leaf, uint256 index, bytes32[] memory branch)
        internal
        pure
        returns (bytes32)
    {
        bytes32 value = leaf;
        for (uint256 i = 0; i < branch.length; i++) {
            if ((index / (2 ** i)) % 2 == 1) {
                value = sha256(bytes.concat(branch[i], value));
            } else {
                value = sha256(bytes.concat(value, branch[i]));
            }
        }
        return value;
    }

    function isValidMerkleBranch(bytes32 leaf, uint256 index, bytes32[] memory branch, bytes32 root)
        internal
        pure
        returns (bool)
    {
        bytes32 restoredMerkleRoot = restoreMerkleRoot(leaf, index, branch);
        return root == restoredMerkleRoot;
    }

    function sszBeaconBlockHeader(BeaconBlockHeader memory header)
        internal
        pure
        returns (bytes32)
    {
        bytes32 left = sha256(
            bytes.concat(
                sha256(
                    bytes.concat(toLittleEndian(header.slot), toLittleEndian(header.proposerIndex))
                ),
                sha256(bytes.concat(header.parentRoot, header.stateRoot))
            )
        );
        bytes32 right = sha256(
            bytes.concat(
                sha256(bytes.concat(header.bodyRoot, bytes32(0))),
                sha256(bytes.concat(bytes32(0), bytes32(0)))
            )
        );

        return sha256(bytes.concat(left, right));
    }

    function computeDomain(bytes4 forkVersion, bytes32 genesisValidatorsRoot)
        internal
        pure
        returns (bytes32)
    {
        return bytes32(uint256(0x07 << 248))
            | (sha256(abi.encode(forkVersion, genesisValidatorsRoot)) >> 32);
    }
}

pragma solidity 0.8.14;
pragma experimental ABIEncoderV2;

import "../../src/lightclient/libraries/SimpleSerialize.sol";

contract LightClientMock {
    uint256 public head;
    mapping(uint256 => BeaconBlockHeader) public headers;
    mapping(uint64 => bytes32) public executionStateRoots;
    mapping(uint64 => bytes32) public stateRoots;
    event HeadUpdate(uint256 indexed slot, bytes32 indexed root);

    function setHead(uint256 slot, BeaconBlockHeader memory header) external {
        head = slot;
        headers[slot] = header;
    }

    function setStateRoot(uint64 slot, bytes32 stateRoot) external {
        stateRoots[slot] = stateRoot;
        // NOTE that the stateRoot emitted here is not the same as the header root
        // in the real LightClient
        emit HeadUpdate(slot, stateRoot);
    }

    function stateRoot(uint64 slot) external view returns (bytes32) {
        return stateRoots[slot];
    }

    function setExecutionRoot(uint64 slot, bytes32 executionRoot) external {
        // NOTE that the root emitted here is not the same as the header root
        // in the real LightClient
        executionStateRoots[slot] = executionRoot;
        emit HeadUpdate(slot, executionRoot);
    }

    function executionStateRoot(uint64 slot) external view returns (bytes32) {
        return executionStateRoots[slot];
    }
}