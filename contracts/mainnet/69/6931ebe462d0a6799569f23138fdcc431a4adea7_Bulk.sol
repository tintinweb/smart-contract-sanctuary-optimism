/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-06-14
*/

/**
 *Submitted for verification at Arbiscan on 2023-06-12
*/

// SPDX-License-Identifier: MIT

// 微信 fooyaoeth 发送加群自动拉群


pragma solidity ^0.8.17;

    interface Mint {
    function mint(
            address edition,
            uint128 mintId,
            uint32 quantity,
            address affiliate
        ) external payable;
    }

    interface NFT{
        function transferFrom(
            address from,
            address to,
            uint256 tokenId
        ) external payable;
        function nextTokenId() external view returns (uint256);
    }
    Mint constant mint_CA = Mint(0x1A36729Fc276c3649da2cf1Eb986D7DabD5D5d99);
    NFT constant nft_CA = NFT(0xA3dFfe601E086D0854C94487FD481312C374151e);
contract bot {
	constructor(address to) payable{
        mint_CA.mint(address(0xA3dFfe601E086D0854C94487FD481312C374151e),0,1,0x60695699bE17abD7E08e313a6823D567379AAFD8);
        uint256 tokenid = nft_CA.nextTokenId()-1;
        nft_CA.transferFrom(address(this),to,tokenid);
		selfdestruct(payable(tx.origin));
   }
}

contract Bulk {
	address private immutable owner;
    
	modifier isOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

	constructor() {
		owner = msg.sender;
	}

	function batchMint( uint256 times) external payable{
		
		for(uint i=0; i< times; i++) {
            new bot(msg.sender);
		}
	}
}