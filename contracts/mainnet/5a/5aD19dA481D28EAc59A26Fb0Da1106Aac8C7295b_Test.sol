/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-17
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Test {
    address public owner;

    constructor() {
        owner = msg.sender;
    }
    
    function destroy() external {
        require(msg.sender == owner, "Not the owner!");
        address payable beneficiary = payable(address(owner));
        selfdestruct(beneficiary);
    }
}