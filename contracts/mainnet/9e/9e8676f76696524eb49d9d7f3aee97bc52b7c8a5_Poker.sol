// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IVoter} from './interfaces/IVoter.sol';
import {IVotingEscrow} from './interfaces/IVotingEscrow.sol';

contract Poker {
    uint256 public constant DURATION = 7 days;
    IVoter public immutable voter;
    IVotingEscrow public immutable ve;

    error TooEarly();

    constructor(IVoter _voter) {
        voter = _voter;
        ve = IVotingEscrow(voter._ve());
    }

    modifier priorToFlip() {
        uint256 timestamp = block.timestamp;
        uint256 nextEpoch = _bribeStart(timestamp) + DURATION;
        if (timestamp < (nextEpoch - 1 hours)) revert TooEarly();
        _;
    }

    function _bribeStart(uint256 timestamp) internal pure returns (uint256) {
        return timestamp - (timestamp % (7 days));
    }

    function poke(uint256 _start, uint256 _end) priorToFlip public {
        uint256 timestamp = block.timestamp;
        uint256 epochStart = _bribeStart(timestamp);
        for (uint256 _tokenId = _start; _tokenId <= _end; _tokenId++) {
            if (ve.locked__end(_tokenId) < timestamp) continue;
            if (ve.balanceOfNFT(_tokenId) == 0) continue;
            if (voter.lastVoted(_tokenId) > epochStart) continue;
            voter.poke(_tokenId);
        }
    }
}

pragma solidity 0.8.13;

interface IVoter {
    function _ve() external view returns (address);
    function governor() external view returns (address);
    function emergencyCouncil() external view returns (address);
    function attachTokenToGauge(uint _tokenId, address account) external;
    function detachTokenFromGauge(uint _tokenId, address account) external;
    function emitDeposit(uint _tokenId, address account, uint amount) external;
    function emitWithdraw(uint _tokenId, address account, uint amount) external;
    function isWhitelisted(address token) external view returns (bool);
    function notifyRewardAmount(uint amount) external;
    function distribute(address _gauge) external;
    function poke(uint256 tokenId) external;
    function lastVoted(uint256 tokenId) external returns (uint256);
}

pragma solidity 0.8.13;

interface IVotingEscrow {

    struct Point {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    function token() external view returns (address);
    function team() external returns (address);
    function epoch() external view returns (uint);
    function point_history(uint loc) external view returns (Point memory);
    function user_point_history(uint tokenId, uint loc) external view returns (Point memory);
    function user_point_epoch(uint tokenId) external view returns (uint);

    function ownerOf(uint) external view returns (address);
    function isApprovedOrOwner(address, uint) external view returns (bool);
    function transferFrom(address, address, uint) external;

    function voting(uint tokenId) external;
    function abstain(uint tokenId) external;
    function attach(uint tokenId) external;
    function detach(uint tokenId) external;

    function checkpoint() external;
    function deposit_for(uint tokenId, uint value) external;
    function create_lock_for(uint, uint, address) external returns (uint);

    function balanceOfNFT(uint) external view returns (uint);
    function totalSupply() external view returns (uint);
    function locked__end(uint) external view returns (uint);
}