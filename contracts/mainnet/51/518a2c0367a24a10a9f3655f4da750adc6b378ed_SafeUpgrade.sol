/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-14
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

contract SafeUpgrade {
    address private masterCopy;

    function changeMasterCopy(address _masterCopy) external {
        masterCopy = _masterCopy;
    }
}