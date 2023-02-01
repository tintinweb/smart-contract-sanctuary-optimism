/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-01-30
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

contract Test {

    address public owner;
    mapping (address => uint) public payments;

    constructor() {
        owner = msg.sender;
    }

    function Send() public payable {
        payments[msg.sender] = msg.value;
    }

    function Return() public {
        address payable _to = payable(owner);
        address _thisContract = address(this);
        _to.transfer(_thisContract.balance);
    }
}