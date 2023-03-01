// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "./AddressSet.sol";
using AddressSet for AddressSet.Set;

import "./IMsgBoard.sol";
import "./Ownable.sol";

contract MsgBoardDirectory is Ownable {
  address public factory;

  struct Tree {
    mapping(uint8 => uint) x;
    AddressSet.Set items;
  }

  Tree[] points;
  Tree root;

  event FactoryChanged(address indexed oldFactory, address indexed newFactory);
  event BoardAdded(address indexed board);
  event BoardRemoved(address indexed board);

  constructor(address _factory) {
    _transferOwnership(msg.sender);
    factory = _factory;
  }

  function transferOwnership(address newOwner) external onlyOwner {
    _transferOwnership(newOwner);
  }

  function setFactory(address newFactory) external onlyOwner {
    emit FactoryChanged(factory, newFactory);
    factory = newFactory;
  }

  function totalCount() external view returns(uint) {
    return root.items.count();
  }

  function newBoard(IMsgBoard board) external {
    require(msg.sender == factory);

    insertString(board.name(), address(board));
    insertString(board.symbol(), address(board));

    emit BoardAdded(address(board));
  }

  function removeBoard(IMsgBoard board) external onlyOwner {
    removeString(board.name(), address(board));
    removeString(board.symbol(), address(board));
    emit BoardRemoved(address(board));
  }

  function lowerCase(bytes1 input) internal pure returns(uint8 char) {
    char = uint8(input);
    if(char > 64 && char < 91) char += 32;
  }

  function removeString(string memory inputStr, address board) internal {
    if(root.items.exists(board)) root.items.remove(board);
    bytes memory input = bytes(inputStr);
    Tree storage pos = root;
    for(uint i; i<input.length; i++) {
      uint8 char = lowerCase(input[i]);
      uint pointer = pos.x[char];
      if(pointer == 0) {
        points.push();
        pos.x[char] = points.length;
        pos = points[points.length - 1];
      } else {
        pos = points[pointer - 1];
      }
      if(pos.items.exists(board)) pos.items.remove(board);
    }
  }

  function insertString(string memory inputStr, address board) internal {
    if(!root.items.exists(board)) root.items.insert(board);
    bytes memory input = bytes(inputStr);
    Tree storage pos = root;
    for(uint i; i<input.length; i++) {
      uint8 char = lowerCase(input[i]);
      uint pointer = pos.x[char];
      if(pointer == 0) {
        points.push();
        pos.x[char] = points.length;
        pos = points[points.length - 1];
      } else {
        pos = points[pointer - 1];
      }
      if(!pos.items.exists(board)) pos.items.insert(board);
    }
  }

  // TODO this function must be in its own contract so it can be upgraded
  function query(string memory qStr) external view returns(address[] memory out) {
    bytes memory q = bytes(qStr);
    Tree storage pos = root;
    for(uint i; i<q.length; i++) {
      uint pointer = pos.x[lowerCase(q[i])];
      if(pointer == 0) {
        return (new address[](0));
      } else {
        pos = points[pointer - 1];
      }
    }
    out = pos.items.keyList;
  }
}