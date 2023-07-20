/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-20
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract ShoutOutTheNumberYouLikeContract {

    event ShoutOutTheNumberYouLike(uint256 num);

    function shoutOutTheNumberYouLike(uint256 _num) public {
        emit ShoutOutTheNumberYouLike(_num);
    }

}