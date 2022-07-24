/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-07-24
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

contract TetrisLeaderboardV1 {
    // The address that can call admin functions
    address internal admin = 0xE3ff24a97BFB65CAdEF30F6Ad19a6EA7E6F6149d;

    // How many highscores should be recorded
    uint8 constant LEADERBOARD_LENGTH = 10;

    // Defines a score on the leaderboard
    struct Score {
        address player;
        uint256 score;
        uint256 timestamp;
    }

    // Stores the top [LEADERBOARD_LENGTH] highest scores where index 0 is the highest score
    mapping(uint256 => Score) public leaderboard;

    // Retrieves and returns a tuple of the current leaderboard players, scores and timestamps
    function getLeaderboard() public view returns(address[LEADERBOARD_LENGTH] memory, uint256[LEADERBOARD_LENGTH] memory, uint256[LEADERBOARD_LENGTH] memory) {
        address[LEADERBOARD_LENGTH] memory players;
        uint256[LEADERBOARD_LENGTH] memory scores;
        uint256[LEADERBOARD_LENGTH] memory timestamps;

        for (uint8 i = 0; i < LEADERBOARD_LENGTH; i++) {
            players[i] = leaderboard[i].player;
            scores[i] = leaderboard[i].score;
            timestamps[i] = leaderboard[i].timestamp;
        }

        return (players, scores, timestamps);
    }

    // Adds a new highscore to the leaderboard 
    function setHighscore(uint256 _score) public returns(address[LEADERBOARD_LENGTH] memory, uint256[LEADERBOARD_LENGTH] memory, uint256[LEADERBOARD_LENGTH] memory) {
        // Determines the index (0-9) that the new score deserves
        for (uint8 i = 0; i < LEADERBOARD_LENGTH; i++) {
            if (_score > leaderboard[i].score) {
                rebaseLeaderboard(i, _score);
                break;
            }
        }
        // Returns the new leaderboard
        return getLeaderboard();
    }

    // Rebases the leaderboard starting at the index that the new score should be in
    function rebaseLeaderboard(uint8 _index, uint256 _score) internal {
        // Shift every previous score lower than the new score to the right 1 index
        for (uint8 i = LEADERBOARD_LENGTH - 1; i > _index; i--) {
           leaderboard[i] = leaderboard[i-1];  
        }
        // Add the new score at its rightful place
        leaderboard[_index] = Score(msg.sender, _score, block.timestamp);
    }

    // Wipes the leaderboard
    function wipeLeaderboard() public {
        require(msg.sender == admin, "Access Denied...");
        for (uint8 i = 0; i < LEADERBOARD_LENGTH; i++) {
            leaderboard[i] = Score(0x0000000000000000000000000000000000000000, 0, 0);
        }
    }

    // Removes a single score from the leaderboard
    function removeHighscore(uint8 _index) public {
        require(msg.sender == admin, "Access Denied...");
        leaderboard[_index] = Score(0x0000000000000000000000000000000000000000, 0, 0);
    }

    // Edit a single score on the leaderboard
    function editHighscore(uint8 _index, address _address, uint256 _score, uint256 _timestamp) public {
        require(msg.sender == admin, "Access Denied...");
        leaderboard[_index] = Score(_address, _score, _timestamp);
    } 

    // Changes the admin to a new address
    function changeAdmin(address _address) public {
        require(msg.sender == admin, "Access Denied...");
        admin = _address;
    }
}