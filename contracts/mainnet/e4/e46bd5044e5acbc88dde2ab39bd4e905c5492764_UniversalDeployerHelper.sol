/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-29
*/

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


contract UniversalDeployer2 {
  event Deploy(address _addr);

  function deploy(bytes memory _creationCode, uint256 _instance) public payable {
    address addr;
    assembly { addr := create2(callvalue(), add(_creationCode, 32), mload(_creationCode), _instance) }
    emit Deploy(addr);
  }
}

contract UniversalDeployerHelper {
  UniversalDeployer2 private immutable ud2;

  constructor(address _ud2) {
    ud2 = UniversalDeployer2(_ud2);
  }

  function deploy(bytes memory _creationCode, uint256 _instance) external payable {
    address addr = address(
      uint160(
        uint256(
          keccak256(
            abi.encodePacked(
              hex'ff',
              address(ud2),
              _instance,
              keccak256(_creationCode)
            )
          )
        )
      )
    );
  
    ud2.deploy(_creationCode, _instance);

    uint256 size; assembly { size := extcodesize(addr) }
    require(size != 0);
  }  
}