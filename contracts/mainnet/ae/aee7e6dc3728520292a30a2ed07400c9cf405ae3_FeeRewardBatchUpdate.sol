/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-22
*/

pragma solidity ^0.8.0;


contract FeeRewardBatchUpdate {

    address public pikaFeeReward;

    constructor(address _pikaFeeReward) public {
        pikaFeeReward = _pikaFeeReward;
    }

    function update(address[] memory _addresses) external {
        uint256 length = _addresses.length;
        for (uint256 i = 0; i < length; i++) {
            IPikaFeeReward(pikaFeeReward).updateReward(_addresses[i]);
        }
    }
}

interface IPikaFeeReward {
    function updateReward(address user) external;
}