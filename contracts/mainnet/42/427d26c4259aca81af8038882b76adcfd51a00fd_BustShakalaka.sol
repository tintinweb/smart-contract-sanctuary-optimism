/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-08-30
*/

pragma solidity ^0.8.16;

contract BustShakalaka {

    struct Game {
        address player;
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

    // key is block number, value is array of games
    mapping(uint => Game[]) games;

    // key is player address, value is block nums player is playing in
    // value is array in ascending block order
    mapping(address => uint[]) blocksPlayed;

    // key is block number, value is the random busted number for the block
    mapping(uint => uint) public bustedAt;

    constructor() {
        owner = msg.sender;
        maxWager = 100000000000000000;
        blocksToFinality = 6;
        houseWinnings = payable(0x2ac1131f34D59Ca814225C6EBcAafB408764a16D);
        // bust can be between 1 and 100
        // bust num has two extra 00s at the end because Solidity doesn't have floating point values
        bustUpperLimit = 1000;
        bustLowerLimit = 100;

        randomSeed = uint(keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            block.coinbase,
            block.difficulty)));
    }


    function play(uint guess) payable public {
        uint wager = msg.value;
        require(wager > 0, "Wager must be greater than 0");
        require(wager <= maxWager, "wager must be less than or equal to 0.1 ether");
        require(guess >= bustLowerLimit, "guess must be greater than or equal to 1");
        require(guess <= bustUpperLimit, "guess must be less than or equal to 10");

        Game memory game = Game({player: msg.sender, wager: wager, guess: guess, blockNum: block.number});
        games[block.number].push(game);

        // update player mapping with this block number
        blocksPlayed[msg.sender].push(block.number);
    }

    function getResult() public returns(string memory) {
        uint[] memory playersBlocks = blocksPlayed[msg.sender];
        if (playersBlocks.length == 0) {
            // then no games have been played by this player
            return "No games found";
        }

        uint blockNum = playersBlocks[0];
        if (block.number - 6 < blockNum) {
            // then user needs to wait more blocks to get a result
            return "Please wait longer";
        }

        Game[] storage curGames = games[blockNum];
        uint j;
        string memory result;
        for (j = 0; j < curGames.length; j++) {
            Game memory game = curGames[j];
            if (game.player == msg.sender) {
                result = processGame(game);
                break;
            }
        }

        delete playersBlocks[0];
        delete curGames[j];
        return string.concat("You ", result);
    }

    function processGame(Game memory game) internal returns(string memory) {
        uint busted = bustedAt[game.blockNum];
        if (busted == 0) {
            // then new random needs generating
            busted = getRandomLimit(bustUpperLimit - 100) + 100;
            bustedAt[game.blockNum] = busted;
        }

        if (game.guess > busted) {
            // then player lost
            houseWinnings.transfer(game.wager);
            return "lost";
        }

        // then player won
        uint winAmount = bustaMultiply(game.wager, game.guess, 2);
        uint payoutAmount = winAmount < address(this).balance ? winAmount : address(this).balance;
        payable(msg.sender).transfer(payoutAmount);
        return "won";
    }

    // Multiplication of a number x by y, where y has simulated decimal places
    // x should have no decimals simulated
    // y should have yNumDecimals decimals simulated
    // y is in form of -> (yOriginalWithDecimals*(10**yNumDecimals))
    function bustaMultiply(uint x, uint y, uint yNumDecimals) public pure returns(uint){
        return (x*y)/(10**yNumDecimals);
    }

    function setBlocksToFinality(uint _blocksToFinality) public {
        require(msg.sender == owner);
        require(_blocksToFinality > 0);
        blocksToFinality = _blocksToFinality;
    }

    function setMaxWager(uint _maxWager) public {
        require(msg.sender == owner);
        require(maxWager >= 0);
        maxWager = _maxWager;
    }

    function setMaxGuess(uint _maxGuess) public {
        require(msg.sender == owner);
        require(bustUpperLimit >= 0);
        bustUpperLimit = _maxGuess;
    }

    //Return a decent random uint
    function getRandom() internal returns (uint decentRandom){
        randomSeed = uint(keccak256(abi.encodePacked(
                randomSeed,
                blockhash(block.number - ((randomSeed % 63) + 1)), // must choose at least 1 block before this one.
                block.coinbase,
                block.difficulty)));
        return randomSeed;
    }

    //get a random number within an upper limit
    function getRandomLimit(uint limit) internal returns (uint decentRandom){
        return getRandom() % limit;
    }

    // So we can cashout
    function cashout(address payable _payto) public {
        require(msg.sender == owner);
        _payto.transfer(address(this).balance);
    }

    function topUpHouse() payable public {
        require(msg.value > 0);
    }

    function transferOwnership(address newOwner) public {
        require(msg.sender == owner);
        owner = newOwner;
    }

    function changeHouseWinnings(address payable _houseWinnings) public {
        require(msg.sender == owner);
        houseWinnings = _houseWinnings;
    }

    // for testing
    function getGame(uint blockNumber) public returns(Game memory) {
        return games[blockNumber][0];
    }

    function getBlocksPlayed(address player) public returns(uint[] memory) {
        return blocksPlayed[player];
    }

    function getSeed() public returns(uint) {
        return randomSeed;
    }
}