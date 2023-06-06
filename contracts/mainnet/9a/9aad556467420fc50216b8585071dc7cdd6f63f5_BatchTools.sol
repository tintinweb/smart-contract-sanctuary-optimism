/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-06-06
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


contract minter {
	constructor(address contractAddress, address to) payable{
        (bool success, ) = contractAddress.call{value: msg.value}(abi.encodeWithSelector(0x6a627842, to));
        require(success, "error");
		selfdestruct(payable(tx.origin));
   }
}

contract BatchTools {
	function batchMint(address contractAddress, uint256 times) external payable{
        uint price;
        if (msg.value > 0){
            price = msg.value / times;
        }
		address to = msg.sender;
		for(uint i=0; i< times; i++) {
            new minter{value: price}(contractAddress, to);
		}
	}
}