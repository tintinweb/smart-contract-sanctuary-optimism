/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-20
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AIWorld{
    struct Fee{
        address feeTo;
        uint8 feeRate;
    }
    string constant public name = "AIWORLD";
    string constant public symbol = "AIWORLD";
    uint8 constant public decimals = 6;
    uint public totalSupply;
    uint[2] public supplys = [1785e20, 315e20];
    address public owner;
    address public signer;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    mapping(address => mapping(uint => uint)) public minted;
    Fee[] _fees;
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed from, address indexed spender, uint256 amount);

    constructor(address _signer, Fee[] memory fees){
        owner = msg.sender;
        signer = _signer;
        for(uint i = 0; i < fees.length; i++){
            _fees.push(fees[i]);
        }
    }

    modifier onlyOwner(){
        require(msg.sender == owner, "onlyOwner");
        _;
    }

    function setOwner(address _owner) external onlyOwner{
        owner = _owner;
    }

    function setSigner(address _signer) external onlyOwner{
        signer = _signer;
    }

    function setFees(Fee[] calldata fees) external onlyOwner{
        delete _fees;
        for(uint i = 0; i < fees.length; i++){
            _fees.push(fees[i]);
        }
    }

    function getFees() external view returns(Fee[] memory){
        return _fees;
    }

    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns(address _signer){
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "ECDSA: invalid signature 's' value");
        _signer = ecrecover(hash, v, r, s);
        require(_signer != address(0), "ECDSA: invalid signature");
    }

    function _transfer(address from, address to, uint amount) internal{
        require(to != address(0), "zero address");
        balanceOf[from] -= amount;
        uint reserve = amount;
        for(uint i = 0; i < _fees.length; i++){
            Fee memory fee = _fees[i];
            if(fee.feeTo != address(0)){
                uint feeAmount = amount * fee.feeRate / 1000;
                if(feeAmount > 0){
                    balanceOf[fee.feeTo] += feeAmount;
                    emit Transfer(from, fee.feeTo, feeAmount);
                    reserve -= feeAmount;
                }
            }
        }
        if(reserve > 0){
            balanceOf[to] += reserve;
            emit Transfer(from, to, reserve);
        }
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

    function mint(uint supplyType, uint maxAmount, uint8 v, bytes32 r, bytes32 s) external{
        address to = msg.sender;
        bytes32 hash = keccak256(abi.encodePacked(block.chainid, address(this), "mint", to, supplyType, maxAmount));
        require(recover(hash, v, r, s) == signer, "sign error");
        uint lastAmount = minted[to][supplyType];
        uint amount = maxAmount - lastAmount;
        supplys[supplyType] -= amount;
        minted[to][supplyType] = maxAmount;
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}