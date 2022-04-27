/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-27
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

interface passNFT {
    function purchase(address tokenRecipient, string memory message) external;
}
contract multiClam {
    address constant contra = address(0xA95579592078783B409803Ddc75Bb402C217A924);
    function call(uint256 times) public {
        for(uint i=0;i<times;++i){
            new claimer(contra);
        }
    }
}
contract claimer{
    constructor(address contra){
        passNFT(contra).purchase(address(tx.origin),"0x00");
        selfdestruct(payable(address(msg.sender)));
    }
}