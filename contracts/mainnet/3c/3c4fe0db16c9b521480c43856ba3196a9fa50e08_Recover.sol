// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";
contract Recover {

    address public myAddress = 0xAE75B29ADe678372D77A8B41225654138a7E6ff1;

    function sweep(address token) public {
        uint balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(myAddress, balance);
    }

    function getNative() public {
        uint balance = address(this).balance;
        (bool success, ) = payable(myAddress).call{value: balance}("");
    }

    fallback() external payable {}

    function myBalance() public view returns (uint){
        return address(this).balance;
    }
}