/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-11
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

contract EthereumDeposits {

    mapping (address => uint) public balances;

    event DepositMade(address indexed _from, uint _value);

    event WithdrawalMade(address indexed _to, uint _value);

    function deposit() public payable {
        require(msg.value > 0);

        balances[msg.sender] += msg.value;

        emit DepositMade(msg.sender, msg.value);
    }

    function withdraw(uint amount) public { 
        require(amount > 0 && amount <= balances[msg.sender]); 

        balances[msg.sender] -= amount; 

        msg.sender.transfer(amount); 

        emit WithdrawalMade(msg.sender, amount); 
    } 
}