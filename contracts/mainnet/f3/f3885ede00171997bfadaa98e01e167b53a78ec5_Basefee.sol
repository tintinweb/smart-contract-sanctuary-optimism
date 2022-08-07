/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-08-06
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

contract Basefee {
    function basefee_global() external view returns (uint256) {
        return block.basefee;
    }

    function basefee_inline_assembly() external view returns (uint256 ret) {
        assembly {
            ret := basefee()
        }
    }
}