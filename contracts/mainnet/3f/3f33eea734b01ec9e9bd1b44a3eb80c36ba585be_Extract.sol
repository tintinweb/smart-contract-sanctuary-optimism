/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-24
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Extract {
    function withdraw() external {
        (bool success,) = payable(msg.sender).call{value : address(this).balance}("");
        require(success, "PrivateSales: unsuccessful withdraw");
    }
}