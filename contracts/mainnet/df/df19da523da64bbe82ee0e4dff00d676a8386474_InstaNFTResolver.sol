/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-03-01
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract InstaNFTResolver {
    function getNFTHolders(address nftAddress, uint256 start, uint256 end) public view returns(address[] memory nftHolders) {
        uint256 length = end - start + 1;
        nftHolders = new address[](length);

        for (uint256 i = start; i <= end; i++) {
            nftHolders[i] = IERC721(nftAddress).ownerOf(i);
        }
    }
}