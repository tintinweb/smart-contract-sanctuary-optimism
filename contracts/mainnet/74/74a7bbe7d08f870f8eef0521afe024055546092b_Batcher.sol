/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-17
*/

pragma solidity ^0.8.19;

interface WORLDinter {
  function balanceOf(address who) external view returns (uint256);
  function mint(address to, uint256 numberOfTokens) external;
}

contract Batcher {
    WORLDinter private constant WORLD = WORLDinter(0x6a886C76693Ed6f4319a289e3FE2e670b803a2Da);
    address private owner; 

    constructor() {
        owner = msg.sender; 
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function.");
        _;
    }

    function batchMint(address[] calldata minter) external onlyOwner {
        uint balance;
        for (uint8 i = 0; i < minter.length; i++) {
            balance = WORLD.balanceOf(minter[i]);
            if (balance == 0) {
                WORLD.mint(minter[i], 1);
            }
        }
    }
}