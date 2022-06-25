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

interface IERC20 {
    function approve(address addr, uint256 amount) external;

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);
}

address constant L2_AMM_WRAPPER_ADDRESS = 0x2ad09850b0CA4c7c1B33f5AcD6cBAbCaB5d6e796;
address constant OPTIMISM_USDC_ADDRESS = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
uint256 constant ARBITRUM_CHAIN_ID = 42161;

contract L2Sender {
    address arbitrum_2inch_address;

    constructor(address _arbitrum_2inch_address) {
        arbitrum_2inch_address = _arbitrum_2inch_address;
    }

    function swap(uint256 amount) external {
        uint256 deadline = block.timestamp + 86400;

        IERC20(OPTIMISM_USDC_ADDRESS).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        IERC20(OPTIMISM_USDC_ADDRESS).approve(L2_AMM_WRAPPER_ADDRESS, amount);
        IL2_AmmWrapper(L2_AMM_WRAPPER_ADDRESS).swapAndSend(
            ARBITRUM_CHAIN_ID,
            arbitrum_2inch_address,
            amount,
            (amount * 25) / 10000,
            0,
            deadline,
            0,
            deadline
        );
    }
}