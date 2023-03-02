// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.12;

contract SaleParams {
    function getSalesPrice(uint256 supply) external pure returns (uint256) {
        if (supply < 1000) return 0 ether;
        return ((supply - 500) / 1000) * .01 ether;
    }

    function airdropCutoff() external pure returns (uint256) {
        return 4000;
    }

    function freeMintsPerAddress() external pure returns (uint256) {
        return 5;
    }

    function sprinklerPrice() external pure returns (uint256) {
        return 0.01 ether;
    }
}