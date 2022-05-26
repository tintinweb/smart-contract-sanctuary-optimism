/**
 *Submitted for verification at optimistic.etherscan.io on 2022-05-26
*/

// Sources flattened with hardhat v2.6.0 https://hardhat.org

// File @openzeppelin/contracts/utils/[email protected]

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


// File @openzeppelin/contracts/access/[email protected]

// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// File contracts/Game.sol

pragma solidity ^0.8.0;

enum MoveDirection {
    Up,
    Down,
    Left,
    Right
}

abstract contract LoogieCoinContract {
  function mint(address to, uint256 amount) virtual public;
}

abstract contract LoogiesContract {
  function tokenURI(uint256 id) external virtual view returns (string memory);
  function ownerOf(uint256 id) external virtual view returns (address);
}

contract Game is Ownable  {
    event Restart(uint8 width, uint8 height);
    event Register(address indexed txOrigin, address indexed msgSender, uint8 x, uint8 y, uint256 loogieId);
    event Move(address indexed txOrigin, uint8 x, uint8 y, uint256 health);
    event GameOver(address indexed player);
    event CollectedTokens(address indexed player, uint256 amount);
    event CollectedHealth(address indexed player, uint256 amount);
    event NewDrop(bool indexed isHealth, uint256 amount, uint8 x, uint8 y);

    struct Field {
        address player;
        uint256 tokenAmountToCollect;
        uint256 healthAmountToCollect;
    }

    struct Position {
        uint8 x;
        uint8 y;
    }

    LoogiesContract public loogiesContract;
    LoogieCoinContract public loogieCoin;

    bool public gameOn;
    uint public collectInterval;

    uint8 public constant width = 24;
    uint8 public constant height = 24;
    Field[width][height] public worldMatrix;

    mapping(address => address) public yourContract;
    mapping(address => Position) public yourPosition;
    mapping(address => uint256) public health;
    mapping(address => uint256) public lastCollectAttempt;
    mapping(address => uint256) public loogies;
    address[] public players;

    uint256 public restartBlockNumber;
    bool public dropOnCollect;
    uint8 public attritionDivider = 50;

    constructor(uint256 _collectInterval, address _loogiesContractAddress, address _loogieCoinContractAddress) {
        collectInterval = _collectInterval;
        loogiesContract = LoogiesContract(_loogiesContractAddress);
        loogieCoin = LoogieCoinContract(_loogieCoinContractAddress);
        restartBlockNumber = block.number;

        emit Restart(width, height);
    }

    function setCollectInterval(uint256 _collectInterval) public onlyOwner {
        collectInterval = _collectInterval;
    }

    function setDropOnCollect(bool _dropOnCollect) public onlyOwner {
        dropOnCollect = _dropOnCollect;
    }

    function start() public onlyOwner {
        gameOn = true;
    }

    function end() public onlyOwner {
        gameOn = false;
    }

    function restart() public onlyOwner {
        for (uint i=0; i<players.length; i++) {
            yourContract[players[i]] = address(0);
            Position memory playerPosition = yourPosition[players[i]];
            worldMatrix[playerPosition.x][playerPosition.y] = Field(address(0),0,0);
            yourPosition[players[i]] = Position(0,0);
            health[players[i]] = 0;
            lastCollectAttempt[players[i]] = 0;
            loogies[players[i]] = 0;
        }

        delete players;

        restartBlockNumber = block.number;

        emit Restart(width, height);
    }

    function getPlayers() public view returns(address[] memory){
        return players;
    }

    function update(address newContract) public {
      require(gameOn, "TOO LATE");
      health[tx.origin] = (health[tx.origin]*80)/100; //20% loss of health on contract update?!!? lol
      require(tx.origin == msg.sender, "MUST BE AN EOA");
      require(yourContract[tx.origin] != address(0), "MUST HAVE A CONTRACT");
      yourContract[tx.origin] = newContract;
    }

    bool public requireContract = false;

    function setRequireContract(bool newValue) public onlyOwner {
        requireContract = newValue;
    }

    function register(uint256 loogieId) public {
        require(gameOn, "TOO LATE");
        if(requireContract) require(tx.origin != msg.sender, "NOT A CONTRACT");
        require(yourContract[tx.origin] == address(0), "NO MORE PLZ");
        require(loogiesContract.ownerOf(loogieId) == tx.origin, "ONLY LOOGIES THAT YOU OWN");
        require(players.length <= 50, "MAX 50 LOOGIES REACHED");

        players.push(tx.origin);
        yourContract[tx.origin] = msg.sender;
        health[tx.origin] = 500;
        loogies[tx.origin] = loogieId;

        randomlyPlace();

        emit Register(tx.origin, msg.sender, yourPosition[tx.origin].x, yourPosition[tx.origin].y, loogieId);
    }

    function randomlyPlace() internal {
        bytes32 predictableRandom = keccak256(abi.encodePacked( blockhash(block.number-1), msg.sender, tx.origin, address(this) ));

        uint8 index = 0;
        uint8 x  = uint8(predictableRandom[index++])%width;
        uint8 y  = uint8(predictableRandom[index++])%height;

        Field memory field = worldMatrix[x][y];

        while(field.player != address(0)){
            x  = uint8(predictableRandom[index++])%width;
            y  = uint8(predictableRandom[index++])%height;
            field = worldMatrix[x][y];
        }

        worldMatrix[x][y].player = tx.origin;
        worldMatrix[yourPosition[tx.origin].x][yourPosition[tx.origin].y].player = address(0);
        yourPosition[tx.origin] = Position(x, y);
        //emit Move(tx.origin, x, y);
    }

    function currentPosition() public view returns(Position memory) {
        return yourPosition[tx.origin];
    }

    function positionOf(address player) public view returns(Position memory) {
        return yourPosition[player];
    }

    function tokenURIOf(address player) public view returns(string memory) {
        return loogiesContract.tokenURI(loogies[player]);
    }

    function collectTokens() public {
        require(health[tx.origin] > 0, "YOU DED");
        require(block.timestamp - lastCollectAttempt[tx.origin] >= collectInterval, "TOO EARLY");
        lastCollectAttempt[tx.origin] = block.timestamp;

        Position memory position = yourPosition[tx.origin];
        Field memory field = worldMatrix[position.x][position.y];
        require(field.tokenAmountToCollect > 0, "NOTHING TO COLLECT");

        if(field.tokenAmountToCollect > 0) {
            uint256 amount = field.tokenAmountToCollect;
            // mint tokens to tx.origin
            loogieCoin.mint(tx.origin, amount);
            worldMatrix[position.x][position.y].tokenAmountToCollect = 0;
            emit CollectedTokens(tx.origin, amount);
            if (dropOnCollect) {
                dropToken(amount);
            }
        }

    }

    function collectHealth() public {
        require(health[tx.origin] > 0, "YOU DED");
        require(block.timestamp - lastCollectAttempt[tx.origin] >= collectInterval, "TOO EARLY");
        lastCollectAttempt[tx.origin] = block.timestamp;

        Position memory position = yourPosition[tx.origin];
        Field memory field = worldMatrix[position.x][position.y];
        require(field.healthAmountToCollect > 0, "NOTHING TO COLLECT");

        if(field.healthAmountToCollect > 0) {
            uint256 amount = field.healthAmountToCollect;
            // increase health
            health[tx.origin] += amount;
            worldMatrix[position.x][position.y].healthAmountToCollect = 0;
            emit CollectedHealth(tx.origin, amount);
            if (dropOnCollect) {
                dropHealth(amount);
            }
        }
    }

    function setAttritionDivider(uint8 newDivider) public onlyOwner {
        attritionDivider = newDivider;
    }

    function move(MoveDirection direction) public {
        require(health[tx.origin] > 0, "YOU DED");
        if(requireContract) require(tx.origin != msg.sender, "NOT A CONTRACT");
        (uint8 x, uint8 y) = getCoordinates(direction, tx.origin);
        require(x < width && y < height, "OUT OF BOUNDS");

        Field memory field = worldMatrix[x][y];

        require(field.player == address(0), "ANOTHER LOOGIE ON THIS POSITION");

        bytes32 predictableRandom = keccak256(abi.encodePacked( blockhash(block.number-1), msg.sender, address(this)));

        health[tx.origin] -= uint8(predictableRandom[0])/attritionDivider;

        worldMatrix[x][y].player = tx.origin;
        worldMatrix[yourPosition[tx.origin].x][yourPosition[tx.origin].y].player = address(0);
        yourPosition[tx.origin] = Position(x, y);
        emit Move(tx.origin, x, y, health[tx.origin]);

        if(health[tx.origin] <= 0) {
            worldMatrix[yourPosition[tx.origin].x][yourPosition[tx.origin].y].player = address(0);
            emit GameOver(tx.origin);
        }
    }

    function getCoordinates(MoveDirection direction, address txOrigin) internal view returns(uint8 x, uint8 y) {
        //       x ----->
        //      _______________
        //  y  |____|____|_____
        //     |____|____|_____
        //     |____|____|_____
        //     |____|____|_____

        if (direction == MoveDirection.Up) {
            x = yourPosition[txOrigin].x;
            y = yourPosition[txOrigin].y - 1;
        }

        if (direction == MoveDirection.Down) {
            x = yourPosition[txOrigin].x;
            y = yourPosition[txOrigin].y + 1;
        }

        if (direction == MoveDirection.Left) {
            x = yourPosition[txOrigin].x - 1;
            y = yourPosition[txOrigin].y;
        }

        if (direction == MoveDirection.Right) {
            x = yourPosition[txOrigin].x + 1;
            y = yourPosition[txOrigin].y;
        }
    }

    function dropToken(uint256 amount) internal {
        bytes32 predictableRandom = keccak256(abi.encodePacked( blockhash(block.number-1), msg.sender, address(this) ));

        uint8 x = uint8(predictableRandom[0]) % width;
        uint8 y = uint8(predictableRandom[1]) % height;

        worldMatrix[x][y].tokenAmountToCollect += amount;
        emit NewDrop(false, amount, x, y);
    }

    function dropHealth(uint256 amount) internal {
        bytes32 predictableRandom = keccak256(abi.encodePacked( blockhash(block.number-1), msg.sender, address(this) ));

        uint8 x = uint8(predictableRandom[0]) % width;
        uint8 y = uint8(predictableRandom[1]) % height;

        worldMatrix[x][y].healthAmountToCollect += amount;
        emit NewDrop(true, amount, x, y);
    }

    function shufflePrizes(uint256 firstRandomNumber, uint256 secondRandomNumber) public onlyOwner {
        uint8 x;
        uint8 y;

        x = uint8(uint256(keccak256(abi.encode(firstRandomNumber, 1))) % width);
        y = uint8(uint256(keccak256(abi.encode(secondRandomNumber, 1))) % height);
        worldMatrix[x][y].tokenAmountToCollect += 1000;
        emit NewDrop(false, 1000, x, y);

        x = uint8(uint256(keccak256(abi.encode(firstRandomNumber, 2))) % width);
        y = uint8(uint256(keccak256(abi.encode(secondRandomNumber, 2))) % height);
        worldMatrix[x][y].tokenAmountToCollect += 500;
        emit NewDrop(false, 500, x, y);

        x = uint8(uint256(keccak256(abi.encode(firstRandomNumber, 3))) % width);
        y = uint8(uint256(keccak256(abi.encode(secondRandomNumber, 3))) % height);
        worldMatrix[x][y].healthAmountToCollect += 100;
        emit NewDrop(true, 100, x, y);

        x = uint8(uint256(keccak256(abi.encode(firstRandomNumber, 4))) % width);
        y = uint8(uint256(keccak256(abi.encode(secondRandomNumber, 4))) % height);
        worldMatrix[x][y].healthAmountToCollect += 50;
        emit NewDrop(true, 50, x, y);
    }
}