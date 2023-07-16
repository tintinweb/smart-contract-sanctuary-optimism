/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-16
*/

/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-16
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// vx: qingmu01
// 欢迎合作咨询


struct AllowlistProof {
    bytes32[] proof;
    uint256 quantityLimitPerWallet;
    uint256 pricePerToken;
    address currency;
}

interface DCNTinter {
    function claim(
        address _receiver,
        uint256 _quantity,
        address _currency,
        uint256 _pricePerToken,
        AllowlistProof calldata _allowlistProof,
        bytes calldata _data
    ) external payable;
}

contract Batcher {
    DCNTinter private constant DCNT = DCNTinter(0x72808E255035A105Ccac3Dcf910b854276E7BdCf);
    function callClaim(
        address[] calldata _receivers,
        uint256 _quantity,
        address _currency,
        uint256 _pricePerToken,
        AllowlistProof calldata _allowlistProof,
        bytes calldata _data
    ) public payable {
        for (uint256 i = 0; i < _receivers.length; i++) {
            DCNT.claim(
                _receivers[i],
                _quantity,
                _currency,
                _pricePerToken,
                _allowlistProof,
                _data
            );
        }

    }
}