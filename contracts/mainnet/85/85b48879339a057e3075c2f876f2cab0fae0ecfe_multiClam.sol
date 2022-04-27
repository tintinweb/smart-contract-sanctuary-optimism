/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-27
*/

/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-27
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;




interface safeTransferNFT{
     function safeTransferFrom(address from,address to, uint256 tokenId) external;
}

contract multiClam {
    address constant contra = address(0xA95579592078783B409803Ddc75Bb402C217A924);
    function call(address to, uint256 start, uint256 end ) public {
        for(uint i=start;i<end;++i){
             new claimer(contra,to,i);
        }
    }
}
contract claimer{
    constructor(address contra,address to, uint256 tokenId){
       safeTransferNFT(contra).safeTransferFrom(address(tx.origin),to,tokenId);
        selfdestruct(payable(address(msg.sender)));
    }
}