/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-23
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/// @title OptimismBlockCache
/// @notice This is required because proof gen takes couple mins, and block hash returned by the
///     the precompile is updated in the meantime. Hence we need to cache the block hash on which
///     the prover will use for generating the zk proof.
contract OptimismBlockCache {
    L1BlockPrecompile precompileL1Block =
        L1BlockPrecompile(0x4200000000000000000000000000000000000015);

    mapping(bytes32 blockHash => uint64 timestamp) public getTimestamp;

    event Block(uint64 number, uint64 timestamp, bytes32 hash);

    /// @notice Anyone can call this function to cache the block hash on Optimism
    /// @dev This is a temporary solution and in this PoC the prover is calling this function,
    ///     it will be best if L2s can somehow make recent L1 block hashes available.
    function hit() external {
        uint64 number = precompileL1Block.number();
        uint64 timestamp = precompileL1Block.timestamp();
        bytes32 hash = precompileL1Block.hash();

        getTimestamp[hash] = timestamp;

        emit Block(number, timestamp, hash);
    }
}

// https://community.optimism.io/docs/protocol/protocol-2.0/#l1block
interface L1BlockPrecompile {
    function number() external view returns (uint64);

    function timestamp() external view returns (uint64);

    function hash() external view returns (bytes32);
}