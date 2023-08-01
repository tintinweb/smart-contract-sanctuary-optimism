/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-31
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PikaStakingReader {

    address public pikaStaking;

    constructor(address _pikaStaking) public {
        pikaStaking = _pikaStaking;
    }

    function getBalances(address[] memory _addresses) external view returns(uint256[] memory) {
        uint256 length = _addresses.length;
        uint256[] memory balances = new uint256[](length); 
        for (uint256 i = 0; i < length; i++) {
            address userAddress = _addresses[i];
            uint256 balance = IPikaStaking(pikaStaking).balanceOf(userAddress);
            balances[i] = balance;
        }
        return balances;
    }


}


interface IPikaStaking {
    function balanceOf(address user) external view returns(uint256);
}