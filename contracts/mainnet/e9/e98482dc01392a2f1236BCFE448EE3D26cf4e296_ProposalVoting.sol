// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error not_in_proposalPeriod();
error not_in_votingPeriod();

contract ProposalVoting {

    struct Proposal {
        string description;
        address proposalOwner;
        uint256 votes;
        bool accepted;
    }

    struct Vote {
        uint256 proposalIndex;
        uint8 decision; // 0 for decline, 1 for accept
    }


    IERC20 public votingToken;

    Proposal[] public proposals;
    uint256 public hackathonEndTime; // Hackathon end timestamp
    uint256 public constant TRANSITION_PERIOD = 90 days; // Transition period after hackathon ends
    uint256 public constant SUBMISSION_PERIOD = TRANSITION_PERIOD + 30 days; // Submission duration
    uint256 public constant VOTING_PERIOD = SUBMISSION_PERIOD + 10 days; // VOTING duration
    uint256 public castedVotes;

    event ProposalSubmitted(address indexed recipient, string message);
    event VoteCasted(address indexed sender, address indexed proposalOwner, uint8 accept);

    constructor(uint256 _hackathonEndTime, address _votingTokenAddress) {
        hackathonEndTime = _hackathonEndTime;
        votingToken = IERC20(_votingTokenAddress);
    }

    function submitProposal(string calldata _description) external {
        if (hackathonEndTime + SUBMISSION_PERIOD < block.timestamp || block.timestamp < hackathonEndTime + TRANSITION_PERIOD) {
            revert not_in_proposalPeriod();
        }

        Proposal memory newProposal = Proposal({
            description: _description,
            proposalOwner: msg.sender,
            votes: 0,
            accepted: false
        });

        proposals.push(newProposal);

        emit ProposalSubmitted(msg.sender, _description);
    }

    function castVote(Vote[] calldata _votes) external {
        if (hackathonEndTime + SUBMISSION_PERIOD > block.timestamp || block.timestamp > hackathonEndTime + VOTING_PERIOD) {
            revert not_in_votingPeriod();
        }

        require(_votes.length == proposals.length, "Invalid number of votes");

        require(votingToken.transferFrom(msg.sender, address(this), 10**18), "No votes available");
        castedVotes += 1;

        for (uint256 i = 0; i < _votes.length; i++) {
            Vote calldata vote = _votes[i];
            require(vote.decision == 0 || vote.decision == 1, "Invalid vote decision");

            proposals[i].votes += vote.decision;

            emit VoteCasted(msg.sender, proposals[i].proposalOwner, vote.decision);
        }
    }

    function proposalsCount() public view returns (uint256) {
        // You need to implement this function to return the total number of proposals submitted
        return proposals.length;
    }

}