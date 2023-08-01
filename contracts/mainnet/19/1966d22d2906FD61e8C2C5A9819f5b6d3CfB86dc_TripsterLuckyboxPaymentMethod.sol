/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-24
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
struct luckyboxItem {
    string Id;
    string Name;
    uint8 Quantity;
    uint256 PriceUnit; // in ether
    uint256 PaidAmount;
    uint256 Time;
}

contract TripsterLuckyboxPaymentMethod {
    /// Insufficient ethers for payment
    /// @param requiredEthers required amount to payment
    /// @param receivedEthers received amount of ethers
    error InsufficientEthers(uint256 requiredEthers, uint256 receivedEthers);

    address seller; // address of the owner
    mapping(address => luckyboxItem[]) buyerTransactions;

    constructor() {
        seller = msg.sender;
    }

    modifier onlyonwner() {
        require(seller == msg.sender, "You are not allowed to do this ");
        _;
    }

    function buy(
        string memory luckyboxItemId,
        string memory luckyboxItemName,
        uint8 Quantity,
        uint256 PricePerUnit
    ) public payable {
        uint256 requiredEthers = Quantity * PricePerUnit;
        if (msg.value != requiredEthers)
            revert InsufficientEthers(requiredEthers, msg.value);
        buyerTransactions[msg.sender].push(
            luckyboxItem(
                luckyboxItemId,
                luckyboxItemName,
                Quantity,
                PricePerUnit,
                msg.value,
                block.timestamp
            )
        );
    }

    function view_buyer_transactions(address buyer)
        public
        view
        returns (luckyboxItem[] memory)
    {
        return buyerTransactions[buyer];
    }
}