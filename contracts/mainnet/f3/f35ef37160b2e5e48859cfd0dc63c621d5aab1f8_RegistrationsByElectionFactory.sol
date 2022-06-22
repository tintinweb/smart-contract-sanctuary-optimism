// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./RegistrationsByElection.sol";
import "./ChildFactory.sol";

/*{
  "name": "Registrations By Election Factory",
  "methods": {
    "deployNew": {
      "onlyAllowed": true,
      "fields": [
        {"hidden":"parent"},
        {"select":["Children"]}
      ]
    }
  }
}*/
contract RegistrationsByElectionFactory is ChildFactory {
  constructor(address factoryMeta, address _childMeta, IVerifiedGroupFactory _parentFactory)
    ChildFactory(factoryMeta, _childMeta, _parentFactory) {}

  function deployNew(
    address group,
    address elections,
    string memory name
  ) external {
    require(IVerifiedGroup(group).contractAllowed(msg.sender));
    RegistrationsByElection newContract = new RegistrationsByElection(
      childMeta, group, elections, name);
    parentFactory.registerChild(group, childMeta, address(newContract));
  }
}