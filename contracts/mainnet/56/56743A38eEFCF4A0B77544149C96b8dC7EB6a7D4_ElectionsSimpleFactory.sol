// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./ElectionsSimple.sol";
import "./ChildFactory.sol";

/*{
  "name": "Simple Elections Factory",
  "methods": {
    "deployNew": {
      "onlyAllowed": true,
      "fields": [
        {"hidden":"parent"},
        {"input":"invokeFilter"},
        {"preview":"seconds"},
        {"input":"percentage"},
        {"input":"percentage"}
      ]
    }
  }
}*/
contract ElectionsSimpleFactory is ChildFactory {
  constructor(address factoryMeta, address _childMeta, IVerifiedGroupFactory _parentFactory)
    ChildFactory(factoryMeta, _childMeta, _parentFactory) {}

  function deployNew(
    address group,
    bytes[] memory allowedInvokePrefixes,
    uint durationSeconds,
    uint16 threshold,
    uint16 minParticipation,
    string memory name
  ) external {
    require(IVerifiedGroup(group).contractAllowed(msg.sender));
    ElectionsSimple newContract = new ElectionsSimple(
      childMeta, group, allowedInvokePrefixes, durationSeconds, threshold, minParticipation, name);
    parentFactory.registerChild(group, childMeta, address(newContract));
  }
}