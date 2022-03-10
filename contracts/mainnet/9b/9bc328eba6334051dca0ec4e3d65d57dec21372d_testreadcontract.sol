/**
 *Submitted for verification at optimistic.etherscan.io on 2022-02-21
*/

pragma solidity ^0.8.0;

    contract testreadcontract {

        function gimmeastring(uint256 a) public pure returns (string memory) {
            if(a == 1) {
                return "Result 1";
            } else {
                return "Result 2";
            }
        }

    }