/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-01-16
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

 /**
   * @title ContractName
   * @dev ContractDescription
   * @custom:dev-run-script file_path
   */
  contract ContractName {}

contract GalaxyCoder {

address public owner;
mapping (address => uint) public payments;

constructor() {
owner = msg.sender;
}

function payForNFT() public payable {
payments[msg.sender] = msg.value;
}

function withdrawAll() public {
address payable _to = payable(owner);
address _thisContract = address(this);
_to.transfer(_thisContract.balance);
}
}