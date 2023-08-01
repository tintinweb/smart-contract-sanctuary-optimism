/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-23
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract WriteANum {

    event WriteALuckNum(uint num);

    function writeALuckNum(uint _num) public {
        emit WriteALuckNum(_num);
    }

}