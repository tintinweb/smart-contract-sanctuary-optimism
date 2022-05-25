/**
 *Submitted for verification at optimistic.etherscan.io on 2022-05-25
*/

// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

contract HelloWorld {
    uint256 public age;

    function setAge() external {
        age = block.number;
    }
}