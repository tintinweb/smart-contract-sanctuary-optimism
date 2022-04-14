/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-14
*/

pragma solidity ^0.4.24;
contract Hello{
    string public name;

    constructor() public {
        name = "test";
    }
    function setName(string _name) public{
        name = _name;
    }
}