/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-12-17
*/

pragma solidity ^0.6.0;

contract KAZERRZZZRAG {
// Define a mapping from player addresses to their scores
mapping (address => uint) public playerScores;

// Define a struct to store the score of a player for a round
struct RoundScore {
    uint score;
    address payable player;
}

// Define an array to store the scores for each round
RoundScore[] public roundScores;

// Define a mapping from player addresses to the address of the last player they tagged
mapping (address => address) public lastTagged;

// Define a contract-wide variable to store the prize pool balance
uint public prizePool;

// Define an event to be emitted whenever a player scores a point
event ScorePoint(uint score, address payable player);

// Define a function to tag a player, which increments their score and updates the lastTagged mapping
function tagPlayer(address payable player) public {
    // Check if the player is able to score a point (i.e., they are not tagging the same player in a row)
    if (lastTagged[msg.sender] != player) {
        // Increment the player's score by 1
        playerScores[player] += 1;
        // Update the lastTagged mapping for the player who scored the point
        lastTagged[msg.sender] = player;
        // Emit the ScorePoint event to record the point
        emit ScorePoint(playerScores[player], player);
    }
}

// Define a function to end a round and distribute the prize pool
function endRound() public payable{
    // Iterate over each player and calculate their share of the prize pool
    for (uint i = 0; i < roundScores.length; i++) {
        RoundScore memory score = roundScores[i];
        // Calculate the player's share of the prize pool
        uint share = prizePool * score.score / totalScore();
        // Transfer the player's share to their address
        score.player.transfer(share);
    }
    // Clear the roundScores array and reset the prize pool to 0
    delete roundScores;
    prizePool = 0;
}

// Define a function to calculate the total score for all players in the current round
function totalScore() public view returns (uint) {
    uint total = 0;
    // Iterate over each player and add their score to the total
    for (uint i = 0; i < roundScores.length; i++) {
        RoundScore memory score = roundScores[i];
        total += score.score;
    }
    return total;
}

// Define a function to allow players to enter the game and contribute to the prize pool
function enterGame() public payable {
    // Add the player's contribution to the prize pool
    prizePool += msg.value;
    // Add the player to the list of round scores
    roundScores.push(RoundScore({
        score: 0,
        player: msg.sender
    }));
}
}