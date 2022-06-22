// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./ElectionsSimpleQuadratic.sol";
import "./ChildFactory.sol";

/*{
  "name": "Simple Elections with Quadratic Voting Factory",
  "methods": {
    "deployNew": {
      "onlyAllowed": true,
      "fields": [
        {"hidden":"parent"},
        {"input":"invokeFilter"},
        {"preview":"seconds"},
        {"input":"percentage"},
        {"input":"percentage"},
        {"select":["Children"], "preview":"token"},
        {"hint":"Number of tokens per vote (square root)",
         "decimals": 5}
      ]
    }
  }
}*/
contract ElectionsSimpleQuadraticFactory is ChildFactory {
  constructor(address factoryMeta, address _childMeta, IVerifiedGroupFactory _parentFactory)
    ChildFactory(factoryMeta, _childMeta, _parentFactory) {}

  function deployNew(
    address group,
    bytes[] memory allowedInvokePrefixes,
    uint durationSeconds,
    uint16 threshold,
    uint16 minParticipation,
    address quadraticToken,
    uint quadraticMultiplier,
    string memory name
  ) external {
    require(IVerifiedGroup(group).contractAllowed(msg.sender));
    ElectionsSimpleQuadratic newContract = new ElectionsSimpleQuadratic(
      childMeta, group, allowedInvokePrefixes, durationSeconds, threshold, minParticipation, quadraticToken, quadraticMultiplier, name);
    parentFactory.registerChild(group, childMeta, address(newContract));
  }
}