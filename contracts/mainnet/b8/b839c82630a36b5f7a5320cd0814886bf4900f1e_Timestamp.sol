/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-09-08
*/

pragma solidity 0.6.12;

contract Timestamp {
  function getBlockTimestamp() external view returns (uint) {
    return block.timestamp;
  }
}