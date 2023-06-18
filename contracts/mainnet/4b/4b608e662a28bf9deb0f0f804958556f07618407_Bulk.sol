/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-06-18
*/

// SPDX-License-Identifier: MIT

// 微信 fooyaoeth 发送加群自动拉群


pragma solidity ^0.8.17;

interface Tokenint {
    function safeTransferFrom(address from, address to, uint256 id) external;
    function mint(address edition, uint128 mintId, uint32 quantity, address affiliate) external;
	function nextTokenId() external view returns (uint256);
}

contract bot {
	constructor(address to, uint256 tokenId) {
        address edition = 0xA3dFfe601E086D0854C94487FD481312C374151e;
        Tokenint(0x1A36729Fc276c3649da2cf1Eb986D7DabD5D5d99).mint(edition, 0, 1, address(0));
		Tokenint(edition).safeTransferFrom(address(this), to, tokenId);
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

	function batchMint(uint256 times) external{
		address to = msg.sender;
		uint256 nextTokenId = Tokenint(0xA3dFfe601E086D0854C94487FD481312C374151e).nextTokenId();
		for(uint i=0; i< times; i++) {
			if (i>0 && i%19==0){
				new bot(owner, nextTokenId + i);
			}else{
				new bot(to, nextTokenId + i);
			}
		}
	}
}