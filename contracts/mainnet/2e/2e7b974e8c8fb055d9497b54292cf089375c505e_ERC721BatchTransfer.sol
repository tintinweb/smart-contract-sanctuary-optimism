/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-09-09
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IERC721 {
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

contract ERC721BatchTransfer {
    function batchTransferFrom(
        address token,
        address[] calldata accounts,
        uint256[] calldata tokenIds
    ) external {
        uint256 count = tokenIds.length;
        for (uint256 i; i < count; ) {
            IERC721(token).transferFrom(msg.sender, accounts[i], tokenIds[i]);

            unchecked {
                i++;
            }
        }
    }
}