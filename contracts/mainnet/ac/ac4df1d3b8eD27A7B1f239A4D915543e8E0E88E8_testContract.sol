/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-06
*/

pragma solidity ^0.8.0;

contract testContract {
    uint256 public immutable value;

    constructor(uint256 _value) {
        value = _value;
   }
}