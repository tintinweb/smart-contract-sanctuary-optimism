/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-22
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract ReentrancyGuard {

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

pragma solidity ^0.8.7;


contract BankOfEthereum is ReentrancyGuard {
    mapping (address => uint) public balances;

    event DepositMade(address indexed _from, uint _value);
    event WithdrawalMade(address indexed _to, uint _value);

    function deposit() public payable {
        require(msg.value > 0, "Deposit must be greater than 0");
        balances[msg.sender] += msg.value;
        emit DepositMade(msg.sender, msg.value);
    }

    function withdraw(uint amount) public nonReentrant { 
        require(amount > 0, "Withdrawal amount must be greater than 0");
        require(amount <= balances[msg.sender], "Not enough balance");
        balances[msg.sender] -= amount; 
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        emit WithdrawalMade(msg.sender, amount); 
    } 
}