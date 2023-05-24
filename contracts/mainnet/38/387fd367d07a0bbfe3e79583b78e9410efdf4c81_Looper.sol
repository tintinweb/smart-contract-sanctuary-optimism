/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-19
*/

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.2 <0.9.0;

contract Looper {
    function loop0() public {}

    function loop1() public {
        for (uint256 i; i < 1; i++) {}
    }

    function loop10() public {
        for (uint256 i; i < 10; i++) {}
    }

    function loop100() public {
        for (uint256 i; i < 100; i++) {}
    }

    function loop1000() public {
        for (uint256 i; i < 1000; i++) {}
    }
}