/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-23
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract oppe {
    string constant public name = "oppe";
    string constant public symbol = "oppe";
    uint256 constant public decimals = 18;
    uint256 immutable public totalSupply;

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(uint256 _totalSupply) {
        totalSupply = _totalSupply;
        balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function balanceOf(address _owner) external view returns (uint256) {
        return balances[_owner];
    }

    function allowance(
        address _owner,
        address _spender
    )
        external
        view
        returns (uint256)
    {
        return allowed[_owner][_spender];
    }

    function approve(address _spender, uint256 _value) external returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function _transfer(address _from, address _to, uint256 _value) internal {
        require(balances[_from] >= _value, "Insufficient balance");
        unchecked {
            balances[_from] -= _value; 
            balances[_to] = balances[_to] + _value;
        }
        emit Transfer(_from, _to, _value);
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )
        external
        returns (bool)
    {
        require(allowed[_from][msg.sender] >= _value, "Insufficient allowance");
        unchecked{ allowed[_from][msg.sender] = allowed[_from][msg.sender] - _value; }
        _transfer(_from, _to, _value);
        return true;
    }
}