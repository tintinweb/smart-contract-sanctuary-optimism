// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ISolidlyLpWrapper {
    function harvest(uint256 minAmountOut) external returns (uint256 amountOut);
}

contract SolidlyStrategyLens {
    error ReturnPreviewWrapperHarvestLpMintAmount(uint256 amount);

    function previewWrapperHarvestLpMintAmount(ISolidlyLpWrapper wrapper) external {
        uint256 amountOut = wrapper.harvest(0);
        revert ReturnPreviewWrapperHarvestLpMintAmount(amountOut);
    }
}