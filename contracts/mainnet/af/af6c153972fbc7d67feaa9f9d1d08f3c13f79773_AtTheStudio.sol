/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-08-17
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.16;

contract AtTheStudio {
    bool public presence;
    string public statement;
    address public owner;
    event Update(bool status, string message, uint256 time);

    // owner can toggle presence
    function togglePresence() public {
        require(msg.sender == owner);
        if (presence == true) {
        presence = false;
        statement = "I am not at the studio";
        } else {
        presence = true;
        statement = "I am at the studio";
        }
        emit Update(presence, statement, block.timestamp);
    }
    
    // owner can withdraw
    function withdraw() public {
      require(msg.sender == owner);
      payable(msg.sender).transfer(address(this).balance);
    }
    
    // sets owner to my vncnt.eth address
    constructor() payable {
        owner = 0x06f4DB783097c632B888669032B2905F70e08105;
    }

    // to support receiving ETH by default
    receive() external payable {}
    fallback() external payable {}

    // owner can set new owner if needed
    function setOwner(address newOwner) external {
        require(msg.sender == owner);
        owner = newOwner;
    }
}