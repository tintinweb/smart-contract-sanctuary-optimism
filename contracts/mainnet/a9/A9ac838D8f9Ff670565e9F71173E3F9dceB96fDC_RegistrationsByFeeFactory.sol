// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./RegistrationsByFee.sol";
import "./ChildFactory.sol";

/*{
  "name": "Registrations By Fee Factory",
  "methods": {
    "deployNew": {
      "onlyAllowed": true,
      "fields": [
        {"hidden":"parent"},
        {"select":["Children"], "preview":"token"},
        {"decimals":1}
      ]
    }
  }
}*/
contract RegistrationsByFeeFactory is ChildFactory {
  constructor(address factoryMeta, address _childMeta, IVerifiedGroupFactory _parentFactory)
    ChildFactory(factoryMeta, _childMeta, _parentFactory) {}

  function deployNew(
    address group,
    address tokenAddress,
    uint amount,
    string memory name
  ) external {
    require(IVerifiedGroup(group).contractAllowed(msg.sender));
    RegistrationsByFee newContract = new RegistrationsByFee(
      childMeta, group, tokenAddress, amount, name);
    parentFactory.registerChild(group, childMeta, address(newContract));
  }
}