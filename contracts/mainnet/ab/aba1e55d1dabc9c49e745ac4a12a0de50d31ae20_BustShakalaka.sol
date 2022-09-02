/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-09-02
*/

pragma solidity ^0.8.16;

contract BustShakalaka {

    struct Game {
        uint wager;
        uint guess;
        uint blockNum;
    }

    address owner;
    uint randomSeed;
    uint maxWager;

    uint bustUpperLimit;
    uint bustLowerLimit;

    address payable public houseWinnings;

    // num blocks before a chain reorg attack is infeasible for placing bets
    uint blocksToFinality;

    // maps an player to their current game
    mapping(address => Game) gameByPlayer;

    // key is block number, value is the random busted number for the block
    mapping(uint => uint) public bustedAt;

    constructor() {
        owner = msg.sender;
        maxWager = 100000000000000000; // in wei
        blocksToFinality = 6;
        houseWinnings = payable(0x84FD0F906A3D49D9770aeAdDEe09C36a5b3fC913);
        // bust can be between 1 and 10
        // bust num has two extra 00s at the end because Solidity doesn't have floating point values
        bustUpperLimit = 1000;
        bustLowerLimit = 100;

        randomSeed = uint(keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            block.coinbase,
            block.difficulty))
        );
    }


    function play(uint guess) payable public {
        uint wager = msg.value;
        require(wager > 0, "Wager must be greater than 0");
        require(wager <= maxWager, "wager must be less than or equal to 0.1 ether");
        require(guess >= bustLowerLimit, "Guess must be greater than or equal to 1");
        require(guess <= bustUpperLimit, "Guess must be less than or equal to 10");

        Game memory potentialGame = gameByPlayer[msg.sender];
        if (potentialGame.blockNum > 0) {
            // then game in progress so prevent overwriting the current one
            revert("Game in progress. Please call getResult() to finish current game.");
        }

        Game memory game = Game({wager: wager, guess: guess, blockNum: block.number});
        gameByPlayer[msg.sender] = game;
    }

    function getResult() public {
        Game memory game = gameByPlayer[msg.sender];
        if (game.blockNum == 0) {
            // then no game was played by this player
            revert("No game found");
        }

        if (block.number - blocksToFinality < game.blockNum) {
            // then user needs to wait more blocks to get a result
            revert("Please wait longer");
        }

        uint busted = bustedAt[game.blockNum];
        if (busted == 0) {
            // then new random needs generating
            busted = getRandomLimit(bustUpperLimit - 100) + 100;
            bustedAt[game.blockNum] = busted;
        }

        delete gameByPlayer[msg.sender];
        if (game.guess > busted) {
            // then player lost
            (bool txSuccess, ) = houseWinnings.call{value: game.wager}("");
            require(txSuccess, "Unable to send winnings to house address.");
        } else {
            // then player won
            uint winAmount = bustaMultiply(game.wager, game.guess, 2);
            uint payoutAmount = winAmount < address(this).balance ? winAmount : address(this).balance;
            (bool userPaid, ) = payable(msg.sender).call{value: payoutAmount}("");
            require(userPaid, "User was not paid.");
        }
    }

    // Multiplication of a number x by y, where y has simulated decimal places
    // x should have no decimals simulated
    // y should have yNumDecimals decimals simulated
    // y is in form of -> (yOriginalWithDecimals*(10**yNumDecimals))
    function bustaMultiply(uint x, uint y, uint yNumDecimals) public pure returns(uint){
        return (x*y)/(10**yNumDecimals);
    }

    function setBlocksToFinality(uint _blocksToFinality) public {
        require(msg.sender == owner, "Must be called by contract owner");
        require(_blocksToFinality > 0, "Number of blocks to finality must be greater than 0");
        blocksToFinality = _blocksToFinality;
    }

    function setMaxWager(uint _maxWager) public {
        require(msg.sender == owner, "Must be called by contract owner");
        require(maxWager >= 0, "Max wager must be greater than or equal to 0");
        maxWager = _maxWager;
    }

    function setMaxGuess(uint _maxGuess) public {
        require(msg.sender == owner, "Must be called by contract owner");
        require(bustUpperLimit >= 0, "Max guess must be greater than or equal to 0");
        bustUpperLimit = _maxGuess;
    }

    //Return a decent random uint
    function getRandom() internal returns (uint decentRandom){
        randomSeed = uint(keccak256(abi.encodePacked(
            randomSeed,
            blockhash(block.number - ((randomSeed % 63) + 1)), // must choose at least 1 block before this one.
            block.coinbase,
            block.difficulty))
        );

        return randomSeed;
    }

    //get a random number within an upper limit
    function getRandomLimit(uint limit) internal returns (uint decentRandom){
        return getRandom() % limit;
    }

    // So we can cashout
    function cashout(address payable _payto) public {
        require(msg.sender == owner, "Must be called by contract owner");
        _payto.transfer(address(this).balance);
    }

    // only allow owner to send ETH to contract to avoid user mistakes
    receive() external payable  {
        require(msg.sender == owner, "Only contract owner can top up contract ETH");
    }

    function transferOwnership(address newOwner) public {
        require(msg.sender == owner, "Must be called by contract owner");
        owner = newOwner;
    }

    function changeHouseWinnings(address payable _houseWinnings) public {
        require(msg.sender == owner, "Must be called by contract owner");
        houseWinnings = _houseWinnings;
    }

    // for testing
    function getGame(address player) public view returns(Game memory) {
        return gameByPlayer[player];
    }
}