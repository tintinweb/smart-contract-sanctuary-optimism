// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "./MsgBoard.sol";

contract MsgBoardFactory {
  MsgBoard[] public boards;

  event NewBoard(address indexed addr, string name, string symbol, address indexed creator);

  function deployNew(string memory name, string memory symbol, uint initialMint, address postCallback, IDirectory directory) external {
    MsgBoard newBoard = new MsgBoard(msg.sender, name, symbol, initialMint, postCallback);
    emit NewBoard(address(newBoard), name, symbol, msg.sender);
    boards.push(newBoard);
    if(address(directory) != address(0)) directory.newBoard(address(newBoard));
  }
}

interface IDirectory {
  function newBoard(address board) external;
}