/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-08-28
*/

// SPDX-License-Identifier: Unlicense

// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

library Counters {
    struct Counter {
        uint256 _value;
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

contract Forum {
  using Counters for Counters.Counter;
  
  enum ItemKind {
    POST,
    COMMENT
  }

  struct Item {

    ItemKind kind;

    uint256 id;

    uint256 parentId;

    address author;

    uint256 categoryId;    

    uint256 createdAtBlock;

    uint256[] childIds;

    string contentCID;
  }

  struct VoteCount {
    mapping(bytes32 => int8) votes;
    int256 total;
  }

  Counters.Counter private itemIdCounter;
  
  mapping(uint256 => VoteCount) private itemVotes;

  mapping(address => int256) private authorKarma;

  mapping(uint256 => Item) private items;

  event NewItem(
    uint256 indexed id,
    uint256 indexed parentId,
    address indexed author
  );

  function addPost(string memory contentCID) public {
    itemIdCounter.increment();
    uint256 id = itemIdCounter.current();
    address author = msg.sender;

    uint256[] memory childIds;
    items[id] = Item(ItemKind.POST, id, 0, author, 0, block.number, childIds, contentCID);
    emit NewItem(id, 0, author);
  }

  function addPost1(string memory contentCID) public {
    itemIdCounter.increment();
    uint256 id = itemIdCounter.current();
    address author = msg.sender;

    uint256[] memory childIds;
    items[id] = Item(ItemKind.POST, id, 0, author, 1, block.number, childIds, contentCID);
    emit NewItem(id, 0, author);
  }  

  function addPost2(string memory contentCID) public {
    itemIdCounter.increment();
    uint256 id = itemIdCounter.current();
    address author = msg.sender;

    uint256[] memory childIds;
    items[id] = Item(ItemKind.POST, id, 0, author, 2, block.number, childIds, contentCID);
    emit NewItem(id, 0, author);
  }  

  function addPost3(string memory contentCID) public {
    itemIdCounter.increment();
    uint256 id = itemIdCounter.current();
    address author = msg.sender;

    uint256[] memory childIds;
    items[id] = Item(ItemKind.POST, id, 0, author, 3, block.number, childIds, contentCID);
    emit NewItem(id, 0, author);
  }  

  function addPost4(string memory contentCID) public {
    itemIdCounter.increment();
    uint256 id = itemIdCounter.current();
    address author = msg.sender;

    uint256[] memory childIds;
    items[id] = Item(ItemKind.POST, id, 0, author, 4, block.number, childIds, contentCID);
    emit NewItem(id, 0, author);
  } 

  function addPost5(string memory contentCID) public {
    itemIdCounter.increment();
    uint256 id = itemIdCounter.current();
    address author = msg.sender;

    uint256[] memory childIds;
    items[id] = Item(ItemKind.POST, id, 0, author, 5, block.number, childIds, contentCID);
    emit NewItem(id, 0, author);
  }

  function addPost6(string memory contentCID) public {
    itemIdCounter.increment();
    uint256 id = itemIdCounter.current();
    address author = msg.sender;

    uint256[] memory childIds;
    items[id] = Item(ItemKind.POST, id, 0, author, 6, block.number, childIds, contentCID);
    emit NewItem(id, 0, author);
  }

  function addPost7(string memory contentCID) public {
    itemIdCounter.increment();
    uint256 id = itemIdCounter.current();
    address author = msg.sender;

    uint256[] memory childIds;
    items[id] = Item(ItemKind.POST, id, 0, author, 7, block.number, childIds, contentCID);
    emit NewItem(id, 0, author);
  }

  function addPost8(string memory contentCID) public {
    itemIdCounter.increment();
    uint256 id = itemIdCounter.current();
    address author = msg.sender;

    uint256[] memory childIds;
    items[id] = Item(ItemKind.POST, id, 0, author, 8, block.number, childIds, contentCID);
    emit NewItem(id, 0, author);
  }

  function addPost9(string memory contentCID) public {
    itemIdCounter.increment();
    uint256 id = itemIdCounter.current();
    address author = msg.sender;

    uint256[] memory childIds;
    items[id] = Item(ItemKind.POST, id, 0, author, 9, block.number, childIds, contentCID);
    emit NewItem(id, 0, author);
  }

  function getItem(uint256 itemId) public view returns (Item memory) {
    require(items[itemId].id == itemId, "No item found");
    return items[itemId];
  }

  function addComment(uint256 parentId, string memory contentCID) public {
    require(items[parentId].id == parentId, "Parent item does not exist");

    itemIdCounter.increment();
    uint256 id = itemIdCounter.current();
    address author = msg.sender;

    items[parentId].childIds.push(id);

    uint256[] memory childIds;
    items[id] = Item(ItemKind.COMMENT, id, parentId, author, 0, block.number, childIds, contentCID);
    emit NewItem(id, parentId, author);
  }

  function voteForItem(uint256 itemId, int8 voteValue) public {
    require(items[itemId].id == itemId, "Item does not exist");
    require(voteValue >= -1 && voteValue <= 1, "Invalid vote value. Must be -1, 0, or 1");

    bytes32 voterId = _voterId(msg.sender);
    int8 oldVote = itemVotes[itemId].votes[voterId];
    if (oldVote != voteValue) {
      itemVotes[itemId].votes[voterId] = voteValue;
      itemVotes[itemId].total = itemVotes[itemId].total - oldVote + voteValue;

      address author = items[itemId].author;
      if (author != msg.sender) {
        authorKarma[author] = authorKarma[author] - oldVote + voteValue;
      }
    }
  }

  function getItemScore(uint256 itemId) public view returns (int256) {
    return itemVotes[itemId].total;
  }

  function getAuthorKarma(address author) public view returns (int256) {
    return authorKarma[author];
  }

  function _voterId(address voter) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(voter));
  }

}