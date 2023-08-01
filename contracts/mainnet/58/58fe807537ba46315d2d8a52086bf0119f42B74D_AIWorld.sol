/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-24
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AIWorld{
    string constant public name = "AIWORLD";
    string constant public symbol = "AIWORLD";
    uint8 constant public decimals = 6;
    uint constant public totalSupply = 35391174008457991712737;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed from, address indexed spender, uint256 amount);

    constructor(address vault){
        balanceOf[vault] = totalSupply;
        emit Transfer(address(0), vault, totalSupply);
    }

    function _transfer(address from, address to, uint amount) internal{
        require(to != address(0), "zero address");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
    
    function transfer(address to, uint256 amount) public returns (bool success){
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool success){
        address spender = msg.sender;
        uint _allowance = allowance[from][spender];
        if(_allowance != type(uint).max){
            _allowance -= amount;
            allowance[from][spender] = _allowance;
            emit Approval(from, spender, _allowance);
        }
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool success){
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}