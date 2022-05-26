/**
 *Submitted for verification at optimistic.etherscan.io on 2022-05-26
*/

contract PollingEvents {
    event Votes(
        address indexed voter,
        uint256[] pollId,
        uint256[] optionId,
        uint256 indexed signature
    );
}

contract Polling is PollingEvents {
    function vote(uint256[] calldata pollIds, uint256[] calldata optionIds, uint256 signature)
        external
    {
        require(pollIds.length == optionIds.length, "non-matching-length");
        emit Votes(msg.sender, pollIds, optionIds, signature);
    }
}