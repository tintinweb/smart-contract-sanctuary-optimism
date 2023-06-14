// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

//https://etherscan.io/address/0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1#code
interface IMessenger {
  function sendMessage(address _target, bytes memory _message, uint32 _gasLimit) external;

  function relayMessage(address _target, address _sender, bytes memory _message, uint256 _messageNonce) external;

  function xDomainMessageSender() external view returns (address);
}

// L2 Contract which receives messages from a specific L1 address and transparently
// forwards them to the destination.
//
// Any other L2 contract which uses this contract's address as a privileged position,
// can be considered to be owned by the `l1Owner`
contract CrossChainAccount {
  IMessenger public immutable messenger;
  address public immutable l1Owner;

  constructor(IMessenger _messenger, address _l1Owner) {
    messenger = _messenger;
    l1Owner = _l1Owner;
  }

  // `forward` `calls` the `target` with `data`,
  // can only be called by the `messenger`
  // can only be called if `tx.l1MessageSender == l1Owner`
  function forward(address target, bytes memory data) external {
    // 1. The call MUST come from the L1 Messenger
    require(msg.sender == address(messenger), "Sender is not the messenger");
    // 2. The L1 Messenger's caller MUST be the L1 Owner
    require(messenger.xDomainMessageSender() == l1Owner, "L1Sender is not the L1Owner");
    // 3. Make the external call
    (bool success, bytes memory res) = target.call(data);
    require(success, string(abi.encode("XChain call failed:", res)));
  }
}