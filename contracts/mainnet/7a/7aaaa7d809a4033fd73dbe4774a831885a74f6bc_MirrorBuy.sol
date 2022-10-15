/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-14
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface BuyNFT {
    function purchase(address tokenRecipient,string memory message) external payable returns (uint256 tokenId);
    function transferFrom(address from,address to,uint256 tokenId) external;
}

contract MirrorBuy {
    function buy_multiple(address target_entry, uint256 times, address receiver) public {
        for(uint i=0;i<times;++i){
            BuyNFT(target_entry).purchase(receiver, "");
        }
    }

    function buy_multiple2(address target_entry, uint256 times) public {
        for(uint i=0;i<times;++i){
            new buyer(target_entry);
        }
    }
}

contract buyer{
    constructor(address contra){
        uint256 id = BuyNFT(contra).purchase(address(this), "");
        BuyNFT(contra).transferFrom(address(this),msg.sender,id);
        selfdestruct(payable(address(msg.sender)));
    }
}