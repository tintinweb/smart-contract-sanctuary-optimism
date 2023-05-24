/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-15
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IBase {
    function mint(address to,uint256 numberOfTokens) external ;

}

contract BatchNft {
    IBase private constant base =
        IBase(0x6a886C76693Ed6f4319a289e3FE2e670b803a2Da);

    function mint(uint256 quantity ) external  {
         for (uint256 i; i < quantity; ++i) {
            base.mint(tx.origin,1);
        }
    }
}