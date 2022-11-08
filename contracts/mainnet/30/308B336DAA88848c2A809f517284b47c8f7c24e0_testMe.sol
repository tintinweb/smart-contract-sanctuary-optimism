/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-11-08
*/

pragma solidity ^0.8.4;

error Unauthorized();

contract testMe {
    address payable owner = payable(msg.sender);
    uint256 public increment;
    
    function add() public {
        if (msg.sender != owner)
            revert Unauthorized();

        increment = increment + 1;
    }
}