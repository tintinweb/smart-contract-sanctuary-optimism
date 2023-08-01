/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-23
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract SpeakOnMoonContract {

    event SpeakOnMoon(string memo);

    function speakOnMoon(string memory _memo) public {
        emit SpeakOnMoon(_memo);
    }

}