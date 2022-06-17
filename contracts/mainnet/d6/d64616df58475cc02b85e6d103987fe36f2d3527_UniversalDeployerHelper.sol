/**
 *Submitted for verification at optimistic.etherscan.io on 2022-06-17
*/

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


interface Factory {
  /**
   * @notice Will deploy a new wallet instance
   * @param _mainModule Address of the main module to be used by the wallet
   * @param _salt Salt used to generate the wallet, which is the imageHash
   *       of the wallet's configuration.
   * @dev It is recommended to not have more than 200 signers as opcode repricing
   *      could make transactions impossible to execute as all the signers must be
   *      passed for each transaction.
   */
  function deploy(address _mainModule, bytes32 _salt) external payable returns (address _contract);
}

contract UniversalDeployerHelper {
  Factory private immutable factory;

  constructor(address _factory) {
    factory = Factory(_factory);
  }

  function deploy(address _mainModule, bytes32 _salt) external payable {
      require(factory.deploy(_mainModule, _salt) != address(0));
  }  
}