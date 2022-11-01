/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-11-01
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
//import "hardhat/console.sol";

contract Wallet {
    mapping(address => uint256) public balance;

    function deposit() external payable {
        require(msg.value != 0, "must send some eth");
        balance[msg.sender] += msg.value;
    }

    function depositFor(address _to) external payable {
        require(msg.value != 0, "must send some eth");
        balance[_to] += msg.value;
    }

    function withdraw() external {
        uint256 _balance = balance[msg.sender];
        require(_balance != 0, "No balance.");
        balance[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value:_balance}("");
        require(success, "Transfer failed.");
    }

}