/**
 *Submitted for verification at optimistic.etherscan.io on 2022-06-25
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IL2_AmmWrapper {
    function swapAndSend(
        uint256 chainId,
        address recipient,
        uint256 amount,
        uint256 bonderFee,
        uint256 amountOutMin,
        uint256 deadline,
        uint256 destinationAmountOutMin,
        uint256 destinationDeadline
    ) external payable;
}

address constant L2_AMM_WRAPPER_ADDRESS = 0x86cA30bEF97fB651b8d866D45503684b90cb3312;
uint256 constant ARBITRUM_CHAIN_ID = 42161;

contract L2Sender {
    address arbitrum_2inch_address;

    constructor(address _arbitrum_2inch_address) {
        arbitrum_2inch_address = _arbitrum_2inch_address;
    }

    function swapETH(address token2) external payable {
        // for now, we only support ETH to USDC swaps (Hop testnet only supports these)
        require(
            msg.value > 0 &&
                token2 == 0x7F5c764cBc14f9669B88837ca1490cCa17c31607
        );

        uint256 deadline = block.timestamp + 86400;

        IL2_AmmWrapper(L2_AMM_WRAPPER_ADDRESS).swapAndSend(
            ARBITRUM_CHAIN_ID,
            arbitrum_2inch_address,
            msg.value,
            0,
            0,
            deadline,
            0,
            deadline
        );
    }
}