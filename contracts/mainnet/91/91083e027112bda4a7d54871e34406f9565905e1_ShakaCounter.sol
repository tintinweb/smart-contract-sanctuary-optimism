/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-12-29
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.4.0;
contract ShakaCounter {
    int private count = 0;
    function incrementShaka() public {
        count += 1;
    }
    function decrementShaka() public {
        count -= 1;
    }
    function getShakaCount() public constant returns (int) {
        return count;
    }
}