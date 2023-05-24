/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-18
*/

/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-13
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IBase {
    function mint(address to,uint256 numberOfTokens) external ;

}

contract BatchMaster {
    IBase private constant base =
        IBase(0x6a886C76693Ed6f4319a289e3FE2e670b803a2Da);

    function mint(address[] memory  _address) external  {
         for (uint256 i; i < _address.length; ++i) {
            base.mint(_address[i],1);
        }
    }
}