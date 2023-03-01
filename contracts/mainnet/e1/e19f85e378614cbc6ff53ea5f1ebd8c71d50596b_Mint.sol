/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-19
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

interface Minter {
  function purchase ( address tokenRecipient, string memory message ) external returns ( uint256 tokenId );
}
    contract Mint{
    function multiMint(address contractAddress, address tokenRecipient) public {
            Minter(contractAddress).purchase(tokenRecipient,"");
    }
}