/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-13
*/

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.9;

interface IERC20
{
    function approve(address _spender, uint256 _amount) external returns (bool _success);
}

interface IAaveV3Pool
{
    function supply(address _asset, uint256 _amount, address _onBehalfOf, uint16 _referralCode) external;
    // leverageAmount = baseAmount * (maxLTV / (1 - maxLTV))
    // function flashLoan(address _receiverAddress, address[] calldata _assets, uint256[] calldata _amounts, uint256[] calldata _interestRateModes, address _onBehalfOf, bytes calldata _params, uint16 _referralCode) external;
}

interface IAaveV3FlashLoanReceiver
{
    function executeOperation(address[] calldata _assets, uint256[] calldata _amounts, uint256[] calldata _premiums, address _initiator, bytes calldata _params) external returns (bool _success);
}

contract AaveV3FlashLoanReceiver is IAaveV3FlashLoanReceiver
{
    function executeOperation(address[] calldata _assets, uint256[] calldata _amounts, uint256[] calldata, address _initiator, bytes calldata) external returns (bool _success)
    {
        for (uint256 _i = 0; _i < _amounts.length; _i++) {
            address _asset = _assets[_i];
            uint256 _amount = _amounts[_i];
            require(IERC20(_asset).approve(msg.sender, _amount), "approve failure");
            IAaveV3Pool(msg.sender).supply(_asset, _amount, _initiator, 0);
        }
        return true;
    }
}