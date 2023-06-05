/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-06-05
*/

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.2 <0.9.0;

contract Upload {
    bytes data1;
    bytes data2;

    function upload(bytes memory _data) public {
        data1 = _data;
    }

    function copy() public {
        data2 = data1;
    }
}