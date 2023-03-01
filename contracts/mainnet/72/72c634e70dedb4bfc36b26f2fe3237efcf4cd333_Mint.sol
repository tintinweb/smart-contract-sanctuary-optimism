/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-21
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface Minter {
  function mint(address mintTo) external returns ( bool );
}
    contract Mint{
    function MintOne(address contractAddress, address tokenRecipient) public {
            Minter(contractAddress).mint(tokenRecipient);
    }
}