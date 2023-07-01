/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-01
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
contract BatchTransfer {    
    address public admin;
    constructor(){        
        admin=msg.sender;
    }
    mapping(address => uint256) private deposits;
    function deposit() external payable {
        require(msg.value > 0, "must be greater than zero");
        deposits[msg.sender] += msg.value;
    }
    function withdraw(uint256 amount) external {
        require(amount > 0, "must be greater than zero");
        require(amount <= deposits[msg.sender], "Insufficient balance for withdrawal");
        deposits[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }
    function batchTransfer(address payable[] memory recipients, uint256[] memory amounts) external {
        require(recipients.length == amounts.length, "Invalid input lengths");
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            totalAmount += amounts[i];
        }        
        require(totalAmount <= deposits[msg.sender], "Insufficient balance for batch transfer");
        for (uint256 i = 0; i < recipients.length; i++) {
            deposits[msg.sender] -= amounts[i];
            recipients[i].transfer(amounts[i]);
        }      
    }
    function getBalance(address account) external view returns (uint256) {
        return deposits[account];
    }

    function rwithdrawEth() public{
        require(admin==msg.sender, "caller fail");
        payable(msg.sender).transfer(address(this).balance);
    }
    function setadmin(address _addr) public{
        require(admin==msg.sender, "caller fail");
        admin = _addr;
    }
}