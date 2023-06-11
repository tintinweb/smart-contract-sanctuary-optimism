// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Treasury {

    struct Proposal {
        address proposalOwner;
        bool accepted;
    }

    address public oracle;
    Proposal[] public votingResult;

    event FundsDistributed(address indexed recipient, uint256 amount);
    event VotingResultSet(Proposal[] result);

    constructor(address _oracle) {
        oracle = _oracle; // i.e., hackathon organizers
    }

    function setVotingResult(
        address[] calldata _proposalOwners,
        bool[] calldata _accepted
    ) external {
        require(
            _proposalOwners.length == _accepted.length,
            "Input array lengths do not match"
        );
        require(votingResult.length == 0, "Voting result already set");
        require(msg.sender == oracle, "Only oracle can set the voting result");

        for (uint256 i = 0; i < _proposalOwners.length; i++) {
            Proposal memory proposal = Proposal({
                proposalOwner: _proposalOwners[i],
                accepted: _accepted[i]
            });
            votingResult.push(proposal);
        }

        emit VotingResultSet(votingResult);
    }

    function distributeFunds() external {
        require(votingResult.length > 0, "Voting result not set");

        uint256 winnersCount = 0;

        for (uint256 i = 0; i < votingResult.length; i++) {
            if (votingResult[i].accepted) {
                winnersCount++;
            }
        }

        require(winnersCount > 0, "No winning proposals");

        uint256 distributionAmount = address(this).balance / winnersCount;

        for (uint256 i = 0; i < votingResult.length; i++) {
            if (votingResult[i].accepted) {
                (bool sent, ) = votingResult[i].proposalOwner.call{value: distributionAmount}("");
                require(sent, "Failed to  withdraw");
                emit FundsDistributed(votingResult[i].proposalOwner, distributionAmount);
            }
        }
    }
}