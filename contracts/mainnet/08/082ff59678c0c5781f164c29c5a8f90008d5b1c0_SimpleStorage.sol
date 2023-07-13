/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-13
*/

// SPDX-License-Identifier: GPL-3.0
// https://docs.soliditylang.org/en/v0.8.20/introduction-to-smart-contracts.html

pragma solidity >=0.8.18 <0.9.0;

contract SimpleStorage {
    address public owner;
    mapping(string => string) private store;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can add to the store");
        _;
    }

    function addToStore(
        string memory key,
        string memory value
    ) public onlyOwner {
        require(bytes(store[key]).length == 0, "Key already has a value");
        store[key] = value;
    }

    function getValue(string memory key) public view returns (string memory) {
        return store[key];
    }
}