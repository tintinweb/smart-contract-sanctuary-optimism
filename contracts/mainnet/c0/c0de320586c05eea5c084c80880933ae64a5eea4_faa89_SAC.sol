/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-01-12
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


contract faa89_SAC {

    address public owner;
    mapping (address => uint) public payments;

    constructor() {
        owner = msg.sender;
    }

    function payforNFT() public payable {
        payments[msg.sender] = msg.value;
    }

    function withdrawALL() public {
        address payable _to = payable(owner);
        address _thisContract = address(this);
        _to.transfer(_thisContract.balance);
    }
}