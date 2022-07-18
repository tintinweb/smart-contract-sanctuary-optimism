/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-07-18
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

contract Documents {
  mapping(address => mapping(address => bytes[])) public docs;
  event NewDoc(address indexed author, address indexed id);
  function post(address id, bytes memory input) external {
    emit NewDoc(msg.sender, id);
    docs[msg.sender][id].push(input);
  }
  function latest(address account, address id) external view returns(bytes memory) {
    return docs[account][id][docs[account][id].length - 1];
  }
  function count(address account, address id) external view returns(uint) {
    return docs[account][id].length;
  }
}