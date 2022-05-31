/**
 *Submitted for verification at optimistic.etherscan.io on 2022-05-31
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

interface OPClaimContract {
    function claim(uint256 index, address account, uint256 amount, bytes32[] memory merkleProof) external;
}

contract ClaimOP {
    constructor() {}

    function claim(uint256 index, address account, uint256 amount, bytes32[] memory merkleProof) external {
        address OPClaimContractAddress = 0xFeDFAF1A10335448b7FA0268F56D2B44DBD357de;
        OPClaimContract airdropContract = OPClaimContract(OPClaimContractAddress);
        airdropContract.claim(index, account, amount, merkleProof);
    }
}