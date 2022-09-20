pragma solidity ^0.8.0;

import "./IFundingManager.sol";
contract FundingManagerReader {

    address public fundingManager;

    constructor(address _fundingManager) public {
        fundingManager = _fundingManager;
    }

    function getFundingData(
        uint256 productId
    ) external view returns(
        int256 fundingPayment,
        int256 fundingRate,
        uint256 lastUpdateTimestamp
    ) {
        fundingPayment = IFundingManager(fundingManager).getFunding(productId);
        fundingRate = IFundingManager(fundingManager).getFundingRate(productId);
        lastUpdateTimestamp = IFundingManager(fundingManager).getLastUpdateTime(productId);
    }
}

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IFundingManager {
    function updateFunding(uint256) external;
    function getFunding(uint256) external view returns(int256);
    function getFundingRate(uint256) external view returns(int256);
    function getLastUpdateTime(uint256) external view returns(uint256);
}