// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "./AddressSet.sol";
using AddressSet for AddressSet.Set;

import "./KarmaERC20.sol";
import "./Ownable.sol";

contract MsgBoard is KarmaERC20, Ownable {
  AddressSet.Set moderators;

  string public name;
  string public symbol;
  address public postCallback;
  uint public msgCount;
  uint public created;

  struct Msg {
    address author;
    address parent;
    address key;
    uint timestamp;
    uint childIndex;
    uint childCount; // Filled when viewing from msgChildren[].length
    uint versionCount; // Filled when viewing from msgChildren[].length
    uint upvotes;
    uint downvotes;
    uint8 status; // 0 = active, greater number = more suppression
    bytes data;
  }
  mapping(address => Msg[]) public msgs;
  mapping(address => address[]) public msgChildren;
  mapping(address => address[]) public msgsByAuthor;
  mapping(address => mapping(address => uint8)) public votes;

  // TODO why doesn't msgs work in browser??
  function getMsg(address key, uint index) external view returns(Msg memory) {
    return msgs[key][index];
  }

  event NewMsg(address indexed key);
  event MsgEdited(address indexed key);
  event Vote(address indexed key, uint upvotes, uint downvotes);
  event ModeratorAdded(address indexed moderator);
  event ModeratorRemoved(address indexed moderator);
  event PostCallbackChanged(address indexed oldCallback, address indexed newCallback);

  constructor(address owner, string memory _name, string memory _symbol, uint initialMint, address _postCallback) {
    name = _name;
    symbol = _symbol;
    created = block.timestamp;
    require(_postCallback == address(0) || isContract(_postCallback));
    postCallback = _postCallback;
    moderators.insert(owner);
    _transferOwnership(owner);
    _mint(owner, initialMint);
  }

  modifier onlyModerator() {
    require(moderators.exists(msg.sender));
    _;
  }

  function listModerators() external view returns(address[] memory) {
    address[] memory out = new address[](moderators.count());
    for(uint i; i<out.length; i++) {
      out[i] = moderators.keyList[i];
    }
    return out;
  }

  function changePostCallback(address newPostCallback) external onlyOwner {
    require(newPostCallback == address(0) || isContract(newPostCallback));
    emit PostCallbackChanged(postCallback, newPostCallback);
    postCallback = newPostCallback;
  }

  function transferOwnership(address newOwner) external onlyOwner {
    _transferOwnership(newOwner);
  }

  function arbitraryTransfer(address origin, address recipient, uint amount) external onlyOwner {
    _transferAllowNegative(origin, recipient, amount);
  }

  function addModerator(address newModerator) external onlyOwner {
    moderators.insert(newModerator);
    emit ModeratorAdded(newModerator);
  }

  function removeModerator(address moderator) external onlyOwner {
    moderators.remove(moderator);
    emit ModeratorRemoved(moderator);
  }

  function post(address parent, bytes memory data) external {
    if(postCallback != address(0)) {
      IPostCallback(postCallback).onPost(msg.sender, parent, block.timestamp, data);
    }
    address key = address(uint160(uint256(keccak256(abi.encode(msg.sender, childCount(parent), parent)))));

    msgs[key].push(Msg(msg.sender, parent, key, block.timestamp, msgChildren[parent].length, 0, 0, 0, 0, 0, data));
    msgChildren[parent].push(key);
    msgsByAuthor[msg.sender].push(key);
    // Author self-upvotes
    msgs[key][0].upvotes++;
    votes[msg.sender][key] = 1;

    msgCount++;
    emit NewMsg(key);
  }

  function edit(address key, bytes memory data) external {
    require(msg.sender == msgs[key][0].author);
    if(postCallback != address(0)) {
      IPostCallback(postCallback).onEdit(msg.sender, msgs[key][0].parent, block.timestamp, data);
    }
    msgs[key].push(Msg(msg.sender, msgs[key][0].parent, key, block.timestamp, 0, 0, 0, 0, 0, 0, data));
    emit MsgEdited(key);
  }

  function vote(address key, uint8 newVote) external {
    require(msgs[key][0].timestamp > 0);
    uint curVote = votes[msg.sender][key];
    require(curVote != newVote && newVote < 3);
    if(curVote == 1) {
      msgs[key][0].upvotes--;
      // User had upvoted the post, but are now not upvoting
      // so burn a token from the author.
      // The voter does not recieve a refund when changing an upvote
      //  because then users could maintain and move tokens continuously
      // XXX: Token is burnt but totalSupply is unchanged?
      _transferAllowNegative(msgs[key][0].author, address(0), 1);
    } else if(curVote == 2) {
      msgs[key][0].downvotes--;
      // User had downvoted the post, but now are not downvoting
      // so mint a token back to the author
      // XXX: totalSupply is not changed?
      _transfer(address(0), msgs[key][0].author, 1);
    }
    if(newVote == 1) {
      msgs[key][0].upvotes++;
      votes[msg.sender][key] = 1;
      // On an upvote, the voter gives the author one of their tokens
      // _transfer() is used here because a user cannot vote themselves into debt
      _transfer(msg.sender, msgs[key][0].author, 1);
    } else if(newVote == 2) {
      msgs[key][0].downvotes++;
      votes[msg.sender][key] = 2;
      // On a downvote, the voter is burning one of the author's tokens
      _transferAllowNegative(msgs[key][0].author, address(0), 1);
      // And burning one for the vote too
      _burn(msg.sender, 1);
    } else if(newVote == 0) {
      votes[msg.sender][key] = 0;
    }
    emit Vote(key, msgs[key][0].upvotes, msgs[key][0].downvotes);
  }

  function versionCount(address key) external view returns(uint) {
    return msgs[key].length;
  }

  function childCount(address key) public view returns(uint) {
    return msgChildren[key].length;
  }

  function authorCount(address author) public view returns(uint) {
    return msgsByAuthor[author].length;
  }

  // Moderators can set a non-zero status value in order to set the level of
  //  suppression a post deserves
  function setMsgStatus(address[] memory key, uint8[] memory status) external onlyModerator {
    require(key.length == status.length);
    for(uint i=0; i<key.length; i++) {
      msgs[key[i]][0].status = status[i];
    }
  }

  // Moderators can mint tokens
  //  a) to themselves in order to provide upvotes to content and fund the economy
  //  b) to individual users in order to reward good behavior
  //  c) to outsiders to invite their participation
  function mint(address[] memory account, uint[] memory amount) external onlyModerator {
    require(account.length == amount.length);
    for(uint i=0; i<account.length; i++) {
      _mint(account[i], amount[i]);
    }
  }

  function isContract(address _addr) private view returns (bool){
    uint32 size;
    assembly {
      size := extcodesize(_addr)
    }
    return (size > 0);
  }

}

interface IPostCallback {
  function onPost(address author, address parent, uint timestamp, bytes memory data) external;
  function onEdit(address author, address parent, uint timestamp, bytes memory data) external;
}