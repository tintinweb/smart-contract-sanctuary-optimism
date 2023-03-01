/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-28
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract CustomError {
    error MyCustomError(uint256 _m, string _msg);

    function test(string memory _msg) public view {
        revert MyCustomError(1, _msg);
    }
}