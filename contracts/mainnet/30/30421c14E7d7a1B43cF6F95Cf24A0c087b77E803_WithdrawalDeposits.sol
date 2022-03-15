/**
 *Submitted for verification at optimistic.etherscan.io on 2022-03-15
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Ownable {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender == owner)
            _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) owner = newOwner;
    }
}

contract WithdrawalDeposits is Ownable {
    //DentacoinToken instance
    DentacoinToken public dcn;
    uint256 public eth_deposit_value = 10000000000000;
    uint256 public dcn_deposit_max_value = 10000000;
    address public deposits_receiver;
    bool public depositsStopped = false;

    constructor(address _dcn_address, address _deposits_receiver) {
        dcn = DentacoinToken(_dcn_address);
        deposits_receiver = _deposits_receiver;
    }

    // ==================================== EVENTS ====================================
    event deposited(address indexed depositor, uint256 tokens, uint256 eth);
    // ==================================== /EVENTS ====================================

    // ==================================== MODIFIERS ====================================
    modifier checkIfDepositsStopped() {
        require(!depositsStopped, "Deposits are stopped.");
        _;
    }
    // ==================================== /MODIFIERS ====================================

    // ==================================== CONTRACT ADMIN ====================================
    function setDepositValues(uint256 _eth_deposit_value, uint256 _dcn_deposit_max_value, address _deposits_receiver) external onlyOwner {
        eth_deposit_value = _eth_deposit_value;
        dcn_deposit_max_value = _dcn_deposit_max_value;
        deposits_receiver = _deposits_receiver;
    }

    function stopUnstopDeposits() external onlyOwner {
        if (!depositsStopped) {
            depositsStopped = true;
        } else {
            depositsStopped = false;
        }
    }
    // ==================================== /CONTRACT ADMIN ====================================

    function deposit(uint256 _tokens_amount) external payable checkIfDepositsStopped {
        require(_tokens_amount <= dcn_deposit_max_value, "Reached maximum DCN deposit.");
        require(dcn.allowance(msg.sender, address(this)) != 0 && dcn.allowance(msg.sender, address(this)) > _tokens_amount, "Reached maximum approved DCN.");
        require(msg.value == eth_deposit_value, "Wrong ETH deposit value.");

        // transfer DCN to deposits receiver
        require(dcn.transferFrom(msg.sender, deposits_receiver, _tokens_amount), "Tokens cannot be transferred from sender.");
        // transfer ETH to deposits receiver
        payable(deposits_receiver).transfer(msg.value);

        emit deposited(msg.sender, _tokens_amount, msg.value);
    }
}

interface DentacoinToken {
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);

    function allowance(address _owner, address _spender) external view returns (uint256);
}