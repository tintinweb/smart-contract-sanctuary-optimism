// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library Fee {
    function getFees(uint256 amount) public pure returns (uint256) {
        return ((amount * 2) / 1000);
    }
}