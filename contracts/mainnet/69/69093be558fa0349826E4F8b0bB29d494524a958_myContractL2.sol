/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-01-15
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

contract myContractL2{
    address public owner;
    
    
    constructor(){
        owner = msg.sender;
    }
    modifier onlyOwner{
        require(owner == msg.sender, "not owner!");
        _;
    }
    mapping (address => uint) payments;

    function callMe()external pure returns(string memory){
        return "Welcome to L2";
    }
    function onlyOwnerCan()public view onlyOwner returns(string memory){
        return "Hello owner of L2 contract";
    }

    function inputFunds()public payable{
        payments[msg.sender] = msg.value;
    }
    
}