/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-26
*/

pragma solidity ^0.8.0;

contract BalanceFetcher {

    function fetch (address _address) external view returns (uint) {
        return _address.balance;
    }

}