// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Ownable.sol";
import "./AddressSet.sol";

interface ICollection {
  function name() external view returns(string memory);
  function symbol() external view returns(string memory);
  function tokenClaimCount(uint256 tokenId) external view returns(uint);
  function ownerOf(uint256 tokenId) external view returns (address owner);
  function tokenURI(uint256 tokenId) external view returns (string memory);
}

contract PublicRegistry is Ownable {
  using AddressSet for AddressSet.Set;

  AddressSet.Set collections;
  mapping(address => uint[]) tokensByCollection;

  struct Collection {
    address addr;
    string name;
    string symbol;
    uint count;
    address owner;
  }

  struct Token {
    uint tokenId;
    address owner;
    uint claimCount;
    string tokenURI;
  }

  constructor() {
    _transferOwnership(msg.sender);
  }

  function transferOwnership(address newOwner) external onlyOwner {
    _transferOwnership(newOwner);
  }

  // TODO: somebody could keep spamming collections even after removal
  function register(address collection) external {
    collections.insert(collection);
  }

  // Invoked by the collection itself
  function registerToken(uint tokenId) external {
    require(collections.exists(msg.sender));
    tokensByCollection[msg.sender].push(tokenId);
  }

  function unregister(address collection) external {
    require(msg.sender == owner || msg.sender == Ownable(collection).owner());
    collections.remove(collection);
  }

  function isRegistered(address collection) external view returns(bool) {
    return collections.exists(collection);
  }

  function fetchCollections(
    uint startIndex,
    uint fetchCount
  ) external view returns (Collection[] memory) {
    uint itemCount = collections.keyList.length;
    if(itemCount == 0) {
      return new Collection[](0);
    }
    require(startIndex < itemCount);
    if(startIndex + fetchCount >= itemCount) {
      fetchCount = itemCount - startIndex;
    }
    Collection[] memory out = new Collection[](fetchCount);
    for(uint i; i < fetchCount; i++) {
      address addr = collections.keyList[startIndex + i];
      ICollection collection = ICollection(addr);
      out[i] = Collection(
        addr,
        collection.name(),
        collection.symbol(),
        tokenCount(addr),
        Ownable(addr).owner()
      );
    }
    return out;
  }

  function fetchTokens(
    ICollection collection,
    uint startIndex,
    uint fetchCount
  ) external view returns (Token[] memory) {
    uint itemCount = tokenCount(address(collection));
    if(itemCount == 0) {
      return new Token[](0);
    }
    require(startIndex < itemCount);
    if(startIndex + fetchCount >= itemCount) {
      fetchCount = itemCount - startIndex;
    }
    Token[] memory out = new Token[](fetchCount);
    for(uint i; i < fetchCount; i++) {
      uint tokenId = tokensByCollection[address(collection)][startIndex + i];
      out[i] = Token(
        tokenId,
        collection.ownerOf(tokenId),
        collection.tokenClaimCount(tokenId),
        collection.tokenURI(tokenId)
      );
    }
    return out;
  }

  function collectionCount() external view returns(uint) {
    return collections.keyList.length;
  }

  function tokenCount(address collection) public view returns(uint) {
    return tokensByCollection[collection].length;
  }
}