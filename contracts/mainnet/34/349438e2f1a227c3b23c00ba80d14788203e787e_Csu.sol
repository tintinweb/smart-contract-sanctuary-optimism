/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-16
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

contract Cu {
    uint256 public v = 0;

    function f(uint256 newU) external {
        v = newU;
    }
}

contract Csu {
    struct su256 {
        uint256 u256;
    }

    su256 public v;

    function f(uint256 newU) external {
        v.u256 = newU;
    }
}

contract Csbu {
    struct sbu256 {
        uint64 u64;
        uint256 u256;
    }

    sbu256 public v;

    function f(uint256 newU) external {
        v.u256 = newU;
    }
}