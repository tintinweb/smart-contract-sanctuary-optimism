// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { IExchangeV4 } from "./IExchangeV4.sol";

contract BatchExchangeV1 {

    // We add a version number to make it easy to find the implementation version on the front-end.
    uint8 public constant VERSION = 1;

    // Optimistic mainnet ExchangeV4
    address public constant EXCHANGE = 0x065e8A87b8F11aED6fAcf9447aBe5E8C5D7502b6;

    /**
     * @param caller Address of the caller (msg.sender)
     * @param numOrders Number of orders in the transaction
     */
    event BatchSellOrderFilled(
        address indexed caller,
        uint256 numOrders
    );

    /**
     * @param seller Seller of the NFT
     * @param contractAddress Contract address of NFT
     * @param tokenId Token id of NFT to sell
     * @param startTime Start time in unix timestamp
     * @param expiration Expiration in unix timestamp
     * @param price Price in wei
     * @param quantity Number of tokens to transfer; should be 1 for ERC721
     * @param createdAtBlockNumber Block number that this order was created at
     * @param paymentERC20 Address of the ERC20 token for the payment. Address(0) for payments in native ETH.
     * @param signature Seller's EIP-712 signature
     * @param buyer Buyer's address
     */
    struct SellOrderInfoV1 {
        address payable seller;
        address contractAddress;
        uint256 tokenId;
        uint256 startTime;
        uint256 expiration;
        uint256 price;
        uint256 quantity;
        uint256 createdAtBlockNumber;
        address paymentERC20;
        bytes signature;
        address payable buyer;
    }

    function fillBatchSellOrder(SellOrderInfoV1[] calldata orders) external payable {
        require(orders.length > 1, "BatchExchangeV1: Order size must be greater than one.");

        uint256 remainingMsgValue = msg.value;
        for (uint i = 0; i < orders.length; i++) {
            SellOrderInfoV1 memory sellOrder = orders[i];
            if (sellOrder.paymentERC20 == address(0)) {
                remainingMsgValue -= sellOrder.price;
                IExchangeV4(EXCHANGE).fillSellOrder{value: sellOrder.price}(
                    sellOrder.seller,
                    sellOrder.contractAddress,
                    sellOrder.tokenId,
                    sellOrder.startTime,
                    sellOrder.expiration,
                    sellOrder.price,
                    sellOrder.quantity,
                    sellOrder.createdAtBlockNumber,
                    sellOrder.paymentERC20,
                    sellOrder.signature,
                    sellOrder.buyer
                );
            } else {
                IExchangeV4(EXCHANGE).fillSellOrder(
                    sellOrder.seller,
                    sellOrder.contractAddress,
                    sellOrder.tokenId,
                    sellOrder.startTime,
                    sellOrder.expiration,
                    sellOrder.price,
                    sellOrder.quantity,
                    sellOrder.createdAtBlockNumber,
                    sellOrder.paymentERC20,
                    sellOrder.signature,
                    sellOrder.buyer
                );
            }
        }
        if (remainingMsgValue > 0) {
            (bool success, ) = payable(msg.sender).call{value: remainingMsgValue}("");
            require(success, "BatchExchangeV1: Failed to refund buyer extra ETH.");
        }
        emit BatchSellOrderFilled(msg.sender, orders.length);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IExchangeV4 {
    struct DutchAuctionOrder {
        /* Seller of the NFT */
        address payable seller;
        /* Contract address of NFT */
        address contractAddress;
        /* Token id of NFT to sell */
        uint256 tokenId;
        /* Start time in unix timestamp */
        uint256 startTime;
        /* End time in unix timestamp */
        uint256 endTime;
        /* Price in wei */
        uint256 startPrice;
        /* Price in wei */
        uint256 endPrice;
        /* Number of tokens to transfer; should be 1 for ERC721 */
        uint256 quantity;
        /* Block number that this order was created at */
        uint256 createdAtBlockNumber;
        /* Address of the ERC20 token for the payment. */
        address paymentERC20;
    }

    function fillSellOrder(
        address payable seller,
        address contractAddress,
        uint256 tokenId,
        uint256 startTime,
        uint256 expiration,
        uint256 price,
        uint256 quantity,
        uint256 createdAtBlockNumber,
        address paymentERC20,
        bytes memory signature,
        address payable buyer
    ) external payable;

    function fillBuyOrder(
        address payable buyer,
        address contractAddress,
        uint256 tokenId,
        uint256 startTime,
        uint256 expiration,
        uint256 price,
        uint256 quantity,
        address paymentERC20,
        bytes memory signature,
        address payable seller
    ) external payable;

    function fillDutchAuctionOrder(
        DutchAuctionOrder memory dutchAuctionOrder,
        bytes memory signature,
        address payable buyer
    ) external payable;
}