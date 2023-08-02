// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

/**
 * Dummy Voting strategy used for creating Rounds without voting process
 */
contract DummyVotingStrategy {
  function create() external returns (address) {
    return address(this);
  }
  function init() external {}
  function vote(bytes[] calldata _encodedVotes, address _voterAddress) external payable {}
}