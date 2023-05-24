/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-13
*/

/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-13
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Free mint
// No fee

interface DCNTinter {
  function balanceOf(address _addr) external view returns (uint256);
  function mint(address to, uint256 numberOfTokens) external;
}

contract Batcher {
    DCNTinter private constant DCNT = DCNTinter(0x6a886C76693Ed6f4319a289e3FE2e670b803a2Da);

    function Mint(address[] calldata minters) external{
        uint balance;
		for(uint i= 0; i < minters.length; i++) {
            balance = DCNT.balanceOf(minters[i]);
            if(balance==0){
	            DCNT.mint(minters[i], 1);
            }
		}
    }

}