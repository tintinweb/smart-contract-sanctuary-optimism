/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-06-09
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

struct Randomness
{
    bytes32 randomBytes;
    uint commitmentDeadline;
    uint revealDeadline;
    bool rewardIsClaimed;
    uint stakeAmount;
    address creator;
}

contract RandomnessCeremony {
    using Counters for Counters.Counter;
    enum CommitmentState {NotCommitted, Committed, Revealed, Slashed}

    function sendETH(address payable _to, uint amount) internal {
        (bool sent, bytes memory data) = _to.call{value: amount}("");
        data;
        require(sent, "Failed to send Ether");
    }

    struct Commitment
    {
        address committer;
        CommitmentState state;
    }

    Counters.Counter public randomnessIds;
    mapping(uint randomnessId => Randomness) public randomness;
    mapping(uint randomnessId => mapping(bytes32 hashedValue => Commitment commitment)) public commitments;

    constructor() {
    }

    // Public Functions

    function commit(address committer, uint randomnessId, bytes32 hashedValue) public payable {
        require(msg.value == randomness[randomnessId].stakeAmount, "Invalid stake amount");
        require(block.timestamp <= randomness[randomnessId].commitmentDeadline, "Can't commit at this moment.");
        commitments[randomnessId][hashedValue] = Commitment(committer, CommitmentState.Committed);
    }

    function reveal(uint randomnessId, bytes32 hashedValue, bytes32 secretValue) public {
        require(block.timestamp > randomness[randomnessId].commitmentDeadline &&
            block.timestamp <= randomness[randomnessId].revealDeadline, "Can't reveal at this moment.");
        require(commitments[randomnessId][hashedValue].state == CommitmentState.Committed, "Hash is not commited");
        require(hashedValue == keccak256(abi.encodePacked(secretValue)), "Invalid secret value");

        commitments[randomnessId][hashedValue].state = CommitmentState.Revealed;

        randomness[randomnessId].randomBytes = randomness[randomnessId].randomBytes ^ secretValue;

        sendETH(
            payable(commitments[randomnessId][hashedValue].committer),
            randomness[randomnessId].stakeAmount
        );
    }

    function getRandomness(uint randomnessId) public view returns(bytes32) {
        require(block.timestamp > randomness[randomnessId].revealDeadline,
            "Randomness not ready yet.");
        return randomness[randomnessId].randomBytes;
    }

    function generateRandomness(uint commitmentDeadline, uint revealDeadline, uint stakeAmount) public returns(uint){
        uint randomnessId = randomnessIds.current();
        randomness[randomnessId] = Randomness(
            bytes32(0),
            commitmentDeadline,
            revealDeadline,
            false,
            stakeAmount,
            msg.sender
        );
        randomnessIds.increment();
        return randomnessId;
    }

    function claimSlashedETH(uint randomnessId, bytes32 hashedValue) public {
        require(randomness[randomnessId].creator == msg.sender, "Only creator can claim slashed");
        require(block.timestamp > randomness[randomnessId].revealDeadline, "Slashing period has not happened yet");
        require(commitments[randomnessId][hashedValue].state == CommitmentState.Committed, "This commitment was not slashed");
        commitments[randomnessId][hashedValue].state = CommitmentState.Slashed;
        sendETH(
            payable(msg.sender),
            randomness[randomnessId].stakeAmount
        );
    }
}