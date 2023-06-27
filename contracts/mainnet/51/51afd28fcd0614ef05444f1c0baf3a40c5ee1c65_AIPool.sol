/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-06-27
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AIPool{
    string constant public name = "AIPOOL";
    string constant public symbol = "AIPOOL";
    uint8 constant public decimals = 6;
    uint public totalSupply;
    address public owner;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed from, address indexed spender, uint256 amount);
    mapping(address => bool) public isMinter;

    constructor(){
        owner = msg.sender;
    }

    modifier onlyOwner(){
        require(msg.sender == owner, "onlyOwner");
        _;
    }

    function setOwner(address _owner) external onlyOwner{
        owner = _owner;
    }

    function setMinter(address account, bool enable) external onlyOwner{
        isMinter[account] = enable;
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
            allowance[from][spender] = _allowance - amount;
            emit Approval(from, spender, amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool success){
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function mint(address to, uint256 amount) external{
        require(isMinter[msg.sender], "only minter");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}