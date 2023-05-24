/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-18
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BatchTransfer {

    function batchTransfer(address[] calldata recipients, uint[] calldata amounts) external payable {
        require(recipients.length == amounts.length, "Length mismatch");
        for (uint i = 0; i < recipients.length; i++) {
            uint amount = amounts[i] * 1 ether / 1000;     
            recipients[i].call{value: amount}("");
        }
    }  
}

// luoye