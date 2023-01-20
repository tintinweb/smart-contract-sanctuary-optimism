/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-01-19
*/

// SPDX-License-Identifier: MIT
// File: Crypto.sol


pragma solidity ^0.8.2;

contract Token {
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowance;
    uint public totalSupply = 10000000000 * 10 ** decimals;
    string public name = "Birt";
    string public symbol = "Brt";
    uint public decimals = 18;
    
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
      }