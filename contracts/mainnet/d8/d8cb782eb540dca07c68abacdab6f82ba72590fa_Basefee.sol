/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-26
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

contract Basefee {
    function basefee_global() external view returns (uint) {
        return block.basefee;
    }
    
    function basefee_inline_assembly() external view returns (uint ret) {
        assembly {
            ret := basefee()
        }
    }
}