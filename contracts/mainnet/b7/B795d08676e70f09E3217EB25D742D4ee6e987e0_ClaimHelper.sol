// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

interface fee_dist {
    function claim(uint _tokenId) external returns (uint);
}


contract ClaimHelper {

    function claim(address[] calldata fee_dists, uint[] calldata tokenIds) external {
        for (uint i = 0; i < fee_dists.length; i++) {
          fee_dist(fee_dists[i]).claim(tokenIds[i]);
        }
    }

}