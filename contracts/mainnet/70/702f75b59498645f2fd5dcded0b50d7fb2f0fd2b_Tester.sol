/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-13
*/

pragma solidity 0.8.6;


contract Tester {
    uint public myVar = 0;

    constructor(uint value) {
        myVar = value;
    }

    function initialize(uint _value) external {
        require(_value > 1);
        myVar = _value;
    }
}