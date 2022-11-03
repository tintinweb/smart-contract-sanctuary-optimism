/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-11-03
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

interface IAccounts {
    function withdraw() external;
    function repay(address initiator, uint256 amount) external;
}

interface IBullsAndBears {
    function accounts(address owner) external view returns (uint8, address);
}

interface IView {
    function getBalance(address positionOwner, address asset) external view returns (int256 amount);
}

contract Rescue {
    IBullsAndBears[] public parents;
    IView public aaveView;


    constructor(
        address[] memory _parents,
        address _view
    ) {
        aaveView = IView(_view);
        for (uint256 i = 0; i < _parents.length; i++) {
            parents.push(IBullsAndBears(_parents[i]));
        }

    }

    function allAccounts(address owner) public view returns (address[] memory) {
        address[] memory accounts = new address[](parents.length);
        for (uint256 i = 0; i < parents.length; i++) {
            (, accounts[i]) = parents[i].accounts(owner);
        }
        return accounts;
    }

    function getAccountInfo(address account) public view returns (int256 usdc, int256 weth) {
        usdc = aaveView.getBalance(account, 0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
        weth = aaveView.getBalance(account, 0x4200000000000000000000000000000000000006);
    }

    function repay(address account, uint256 amount) public {
        IAccounts(account).repay(address(0), amount);
    }

}