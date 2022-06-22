// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./ElectionsByMedian.sol";
import "./ChildFactory.sol";

/*{
  "name": "Elections by Median Factory",
  "methods": {
    "deployNew": {
      "onlyAllowed": true,
      "fields": [
        {"hidden":"parent"},
        {"input":"invokeFilter"}
      ]
    }
  }
}*/
contract ElectionsByMedianFactory is ChildFactory {
  constructor(address factoryMeta, address _childMeta, IVerifiedGroupFactory _parentFactory)
    ChildFactory(factoryMeta, _childMeta, _parentFactory) {}

  function deployNew(address group, bytes[] memory allowedInvokePrefixes, string memory name) external {
    require(IVerifiedGroup(group).contractAllowed(msg.sender));
    ElectionsByMedian newContract = new ElectionsByMedian(childMeta, group, allowedInvokePrefixes, name);
    parentFactory.registerChild(group, childMeta, address(newContract));
  }
}