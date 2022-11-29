/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-11-29
*/

pragma solidity ^0.8.0;

contract returnMeSomething {

    uint256 public SomeVariable = 256;

    function checkSomething(uint _a) public view returns (bool) {
        if (_a == 10) {
            return true;
        } else {
            return false;
        }
    }
}