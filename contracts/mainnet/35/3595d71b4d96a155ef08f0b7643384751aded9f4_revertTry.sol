/**
 *Submitted for verification at optimistic.etherscan.io on 2022-06-20
*/

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

contract revertTry {
    function revertNow() public pure {
        bytes memory revertData = abi.encode(1, 2);
        assembly {
            let revertData_size := mload(revertData)
            revert(add(32, revertData), revertData_size)
        }
    }
}