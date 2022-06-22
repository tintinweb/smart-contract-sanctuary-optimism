// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./VerifiedGroup.sol";
import "./ChildFactory.sol";

/*{
  "name": "Groups",
  "methods": {
    "deployNew": {
      "fields": [
        { "hidden": "Verification" },
        { "hint": "Can be changed later" }
      ]
    }
  },
  "display": {
    "FactoryBrowser": { "root": true }
  }
}*/
contract VerifiedGroupFactory is ChildFactory {
  struct GroupChild {
    address meta;
    address item;
    uint created;
  }
  address public rewriter;
  mapping(address => GroupChild[]) public groupChildren;
  event NewChild(address indexed group, address indexed meta, address indexed deployed);

  constructor(address factoryMeta, address _childMeta, address _rewriter)
    ChildFactory(factoryMeta, _childMeta, IVerifiedGroupFactory(address(0))) {
    rewriter = _rewriter;
  }

  function deployNew(
    address verifications,
    string memory name
  ) external {
    VerifiedGroup newContract = new VerifiedGroup(childMeta, verifications, msg.sender, address(this), name);
    groupChildren[address(0)].push(GroupChild(childMeta, address(newContract), block.timestamp));
    emit NewChild(address(0), childMeta, address(newContract));
  }

  function registerChild(address group, address childMeta, address item) public {
    VerifiedGroup groupInstance = VerifiedGroup(group);
    require(groupInstance.contractAllowed(msg.sender), 'Invalid Caller');
    groupChildren[group].push(GroupChild(childMeta, item, block.timestamp));
    emit NewChild(group, childMeta, item);
  }

  function childCount(address group) external view returns(uint) {
    return groupChildren[group].length;
  }
}