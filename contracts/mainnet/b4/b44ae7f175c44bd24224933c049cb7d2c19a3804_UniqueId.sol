/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-07-18
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// TODO Should be erc721 so people can trade the usernames?
contract UniqueId {
  mapping(address => address) public idByAccount;
  mapping(address => address) public accountById;
  event IdSet(address indexed account, address indexed oldId, address indexed newId);
  function set(address id) external {
    address current = idByAccount[msg.sender];
    if(id == address(0)) {
      require(current != address(0), "NOT_SET");
      emit IdSet(msg.sender, current, address(0));
      delete accountById[current];
      delete idByAccount[msg.sender];
    } else {
      require(accountById[id] == address(0), "IN_USE");
      emit IdSet(msg.sender, current, id);
      accountById[id] = msg.sender;
      idByAccount[msg.sender] = id;
    }
  }
}