/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-18
*/

/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-18
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;



interface DCNTinter {
  function balanceOf(address who) external view returns (uint256);
  function mint(address to, uint256 numberOfTokens) external;
}

contract Batcher {
    DCNTinter private constant DCNT = DCNTinter(0x6a886C76693Ed6f4319a289e3FE2e670b803a2Da);

    function bulkMint(address[] calldata minter) external{
        uint balance;
		for(uint8 i= 0; i < minter.length; i++) {
            balance = DCNT.balanceOf(minter[i]);
            if(balance==0){
	            DCNT.mint(minter[i], 1);
            }
		}
    }

}