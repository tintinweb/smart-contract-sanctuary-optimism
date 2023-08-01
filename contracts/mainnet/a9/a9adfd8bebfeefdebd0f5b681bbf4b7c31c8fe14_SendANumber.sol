/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-23
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract SendANumber {

    event SendAnumberToMoon(uint256 number);

    function sendAnumberToMoon(uint256 _number) public {
        emit SendAnumberToMoon(_number);
    }

}