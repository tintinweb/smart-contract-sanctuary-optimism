/**
 *Submitted for verification at optimistic.etherscan.io on 2022-06-21
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IVerifiedGroupFactory {
  struct GroupChild {
    address meta;
    address item;
    uint created;
  }
  function rewriter() external view returns(address);
  function childCount(address group) external view returns(uint);
  function groupChildren(address group, uint index) external view returns(GroupChild memory);
  function registerChild(address group, address childMeta, address item) external;
}

interface IVerifiedGroup {
  struct Comment {
    address author;
    uint timestamp;
    string text;
  }
  function name() external view returns(string memory);
  function setName(string memory _name) external;
  function joinedTimestamps(address account) external view returns(uint);
  function registeredCount() external view returns(uint);
  function isVerified(address account) external view returns(bool);
  function isRegistered(address account) external view returns(bool);
  function contractAllowed(address key) external view returns(bool);
  function allowedContractCount() external view returns(uint);
  function allowedContractIndex(uint index) external view returns(address);
  function commentCount(address item) external view returns(uint);
  function getComment(address item, uint index) external view returns(Comment memory);
  function postComment(address item, string memory text) external;
  function register(address account) external;
  function unregister(address account) external;
  function ban(address account, uint banExpirationTimestamp) external;
  function setVerifications(address _verifications) external;
  function allowContract(address contractToAllow) external;
  function hookRegister(bytes4 selector) external;
  function hookUnregister(bytes4 selector) external;
  function disallowContract(address contractToDisallow) external;
  function invoke(address to, bytes memory data) external;
  function invokeMany(bytes[] memory data) external;
}


contract FactoryBrowser {
  struct ItemDetails {
    address meta;
    address item;
    uint created;
    string metaname;
    string name;
  }
  struct AllowedDetails {
    address meta;
    address item;
    string metaname;
    string name;
  }
  address public meta;

  bytes4 private constant NAME_SELECTOR = bytes4(keccak256(bytes('name()')));
  bytes4 private constant META_SELECTOR = bytes4(keccak256(bytes('meta()')));

  constructor(address _meta) {
    meta = _meta;
  }

  function detailsMany(IVerifiedGroupFactory factory, address group, uint startIndex, uint fetchCount) external returns(ItemDetails[] memory) {
    uint itemCount = factory.childCount(group);
    require(startIndex < itemCount);
    if(startIndex + fetchCount >= itemCount) {
      fetchCount = itemCount - startIndex;
    }
    ItemDetails[] memory out = new ItemDetails[](fetchCount);
    for(uint i; i < fetchCount; i++) {
      IVerifiedGroupFactory.GroupChild memory raw = factory.groupChildren(group, startIndex + i);
      out[i] = ItemDetails(raw.meta, raw.item, raw.created, safeName(raw.meta), safeName(raw.item));
    }
    return out;
  }

  function allowedMany(IVerifiedGroup group, uint startIndex, uint fetchCount) external returns(AllowedDetails[] memory) {
    uint itemCount = group.allowedContractCount();
    require(startIndex < itemCount);
    if(startIndex + fetchCount >= itemCount) {
      fetchCount = itemCount - startIndex;
    }
    AllowedDetails[] memory out = new AllowedDetails[](fetchCount);
    for(uint i; i < fetchCount; i++) {
      address raw = group.allowedContractIndex(startIndex + i);
      address metaAddr = safeMeta(raw);
      string memory metaname;
      if(!isContract(raw)) {
        metaname = 'Not a Contract';
      } else {
        metaname = safeName(metaAddr);
      }
      out[i] = AllowedDetails(metaAddr, raw, metaname, safeName(raw));
    }
    return out;
  }

  function commentsMany(IVerifiedGroup group, address item, uint startIndex, uint fetchCount) external view returns(IVerifiedGroup.Comment[] memory) {
    uint itemCount = group.commentCount(item);
    require(startIndex < itemCount);
    if(startIndex + fetchCount >= itemCount) {
      fetchCount = itemCount - startIndex;
    }
    IVerifiedGroup.Comment[] memory out = new IVerifiedGroup.Comment[](fetchCount);
    for(uint i = 0; i < fetchCount; i++) {
      out[i] = group.getComment(item, startIndex + i);
    }
    return out;
  }

  function safeName(address raw) public returns(string memory) {
    if(!isContract(raw)) return "";
    (bool success, bytes memory data) = raw.call(abi.encodeWithSelector(NAME_SELECTOR));
    if(success) {
      return abi.decode(data, (string));
    }
    return "";
  }

  function safeMeta(address raw) public returns(address) {
    if(!isContract(raw)) return address(0);
    (bool success, bytes memory data) = raw.call(abi.encodeWithSelector(META_SELECTOR));
    if(success) {
      return abi.decode(data, (address));
    }
    return address(0);
  }
  function isContract(address _addr) private view returns (bool){
    uint32 size;
    assembly {
      size := extcodesize(_addr)
    }
    return (size > 0);
  }
}