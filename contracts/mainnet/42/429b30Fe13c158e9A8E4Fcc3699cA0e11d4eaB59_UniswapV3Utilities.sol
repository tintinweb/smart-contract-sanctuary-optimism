/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-09-05
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

contract UniswapV3Utilities {
    bytes32 public constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
    address public constant FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    address private owner;

    constructor() {
        owner = msg.sender;
    }

    function getPool(address token0, address token1, uint24 fee) public pure returns (address) {
        return address(uint160(uint256(
                keccak256(
                    abi.encodePacked(
                        hex'ff',
                        FACTORY,
                        keccak256(abi.encode(token0, token1, fee)),
                        POOL_INIT_CODE_HASH
                    )
                )
            )));
    }
}