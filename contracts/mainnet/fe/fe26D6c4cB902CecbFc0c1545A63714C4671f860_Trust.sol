//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract Trust {
    address public beneficiary;
    uint256 public unlockDate;

    event Deposited(
        address indexed from,
        address indexed beneficiary,
        uint256 amount,
        uint256 balance
    );
    event Withdrawn(address indexed beneficiary, uint256 balance);
    event NewBeneficiary(address indexed from, address indexed to);

    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "Sender is not the beneficiary.");
        _;
    }

    constructor(address _beneficiary, uint256 _unlockDate) payable {
        require(
            _beneficiary != address(0),
            "Beneficiary cannot be the zero address."
        );
        require(
            _unlockDate > block.timestamp,
            "Unlock date must be in the future."
        );
        require(msg.value == 0, "Initial deposit must be zero.");

        beneficiary = _beneficiary;
        unlockDate = _unlockDate;
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        require(
            unlockDate > block.timestamp,
            "Wallet is unlocked, can't deposit."
        );
        require(msg.value > 0, "Deposit must be greater than zero.");

        emit Deposited(
            msg.sender,
            beneficiary,
            msg.value,
            address(this).balance
        );
    }

    function withdraw() external onlyBeneficiary {
        require(block.timestamp >= unlockDate, "Wallet is locked.");

        emit Withdrawn(beneficiary, address(this).balance);
        payable(beneficiary).transfer(address(this).balance);
    }

    function transferBeneficiary(address _beneficiary)
        external
        onlyBeneficiary
    {
        require(
            _beneficiary != address(0),
            "Beneficiary cannot be the zero address."
        );

        beneficiary = _beneficiary;
        emit NewBeneficiary(msg.sender, beneficiary);
    }
}