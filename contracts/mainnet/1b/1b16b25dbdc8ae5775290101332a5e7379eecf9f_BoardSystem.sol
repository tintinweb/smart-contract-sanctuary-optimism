// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;
import "solecs/System.sol";
import {IWorld} from "solecs/interfaces/IWorld.sol";
import {getAddressById} from "solecs/utils.sol";
import {TileComponent, ID as TileComponentID} from "../components/TileComponent.sol";
import {ScoreComponent, ID as ScoreComponentID} from "../components/ScoreComponent.sol";
import {LetterCountComponent, ID as LetterCountComponentID} from "../components/LetterCountComponent.sol";
import {Letter} from "../common/Letter.sol";
import {Tile} from "../common/Tile.sol";
import {Score} from "../common/Score.sol";
import {Direction, Bounds, Position} from "../common/Play.sol";
import {LinearVRGDA} from "../vrgda/LinearVRGDA.sol";
import {toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";
import {LibBoard} from "../libraries/LibBoard.sol";
import "../common/Errors.sol";

uint256 constant ID = uint256(keccak256("system.Board"));

/// @title Game Board System for Words3
/// @author Small Brain Games
/// @notice Logic for placing words, scoring points, and claiming winnings
contract BoardSystem is System, LinearVRGDA {
    /// ============ Immutable Storage ============

    /// @notice Target price for a token, to be scaled according to sales pace.
    int256 public immutable vrgdaTargetPrice = 5e14;
    /// @notice The percent price decays per unit of time with no sales, scaled by 1e18.
    int256 public immutable vrgdaPriceDecayPercent = 0.77e18;
    /// @notice The number of tokens to target selling in 1 full unit of time, scaled by 1e18.
    int256 public immutable vrgdaPerTimeUnit = 20e18;
    /// @notice Start time for vrgda calculations
    uint256 public immutable startTime = block.timestamp;

    /// @notice End time for game end
    uint256 public immutable endTime = block.timestamp + 86400 * 6;
    /// @notice Amount of sales that go to rewards (1/4)
    uint256 public immutable rewardFraction = 4;

    /// @notice Merkle root for dictionary of words
    bytes32 private merkleRoot =
        0xd848d23e6ac07f7c22c9cb0e121f568619a636d37fab669e76595adfda216273;

    /// @notice Mapping for point values of letters, set up in setupLetterPoints()
    mapping(Letter => uint8) private letterValue;

    /// ============ Mutable Storage (ECS Sin, but gas savings) ============

    /// @notice Mapping to store if a player has claimed their end of game payout
    mapping(address => bool) private claimedPayout;
    /// @notice Store of treasury to be paid out to game winners
    uint256 private treasury;

    constructor(IWorld _world, address _components)
        LinearVRGDA(vrgdaTargetPrice, vrgdaPriceDecayPercent, vrgdaPerTimeUnit)
        System(_world, _components)
    {
        setupLetterPoints();
    }

    /// ============ Public functions ============

    function execute(bytes memory arguments) public returns (bytes memory) {
        (
            Letter[] memory word,
            bytes32[] memory proof,
            Position memory position,
            Direction direction,
            Bounds memory bounds
        ) = abi.decode(
                arguments,
                (Letter[], bytes32[], Position, Direction, Bounds)
            );
        executeInternal(word, proof, position, direction, bounds);
    }

    /// @notice Checks if a move is valid and if so, plays a word on the board.
    /// @param word The letters of the word being played, empty letters mean using existing letters on board.
    /// @param proof The Merkle proof that the word is in the dictionary.
    /// @param position The starting position that the word is being played from.
    /// @param direction The direction the word is being played (top-down, or left-to-right).
    /// @param bounds The bounds of all other words on the cross axis this word makes.
    function executeTyped(
        Letter[] memory word,
        bytes32[] memory proof,
        Position memory position,
        Direction direction,
        Bounds memory bounds
    ) public payable returns (bytes memory) {
        return execute(abi.encode(word, proof, position, direction, bounds));
    }

    /// @notice Claims winnings for a player at game end, can only be called once.
    function claimPayout() public {
        if (!isGameOver()) revert GameNotOver();
        if (claimedPayout[msg.sender]) revert AlreadyClaimedPayout();
        claimedPayout[msg.sender] = true;
        ScoreComponent scores = ScoreComponent(
            getAddressById(components, ScoreComponentID)
        );
        Score memory playerScore = scores.getValueAtAddress(msg.sender);
        uint256 winnings = (treasury * playerScore.score) /
            uint256(scores.getTotalScore());
        uint256 rewards = playerScore.rewards;
        payable(msg.sender).transfer(winnings + rewards);
    }

    /// @notice Allows anyone to seed the treasury for this game with extra funds.
    function fundTreasury() public payable {
        if (msg.value > 0) {
            treasury += msg.value;
        }
    }

    /// @notice Gets funds in treasury (only treasury, not player rewards).
    function getTreasury() public view returns (uint256) {
        return treasury;
    }

    /// @notice Plays the first word "infinite" on the board.
    function setupInitialGrid() public {
        TileComponent tiles = TileComponent(
            getAddressById(components, TileComponentID)
        );
        if (tiles.hasTileAtPosition(Position({x: 0, y: 0})))
            revert AlreadySetupGrid();
        tiles.set(Tile(address(0), Position({x: 0, y: 0}), Letter.I));
        tiles.set(Tile(address(0), Position({x: 1, y: 0}), Letter.N));
        tiles.set(Tile(address(0), Position({x: 2, y: 0}), Letter.F));
        tiles.set(Tile(address(0), Position({x: 3, y: 0}), Letter.I));
        tiles.set(Tile(address(0), Position({x: 4, y: 0}), Letter.N));
        tiles.set(Tile(address(0), Position({x: 5, y: 0}), Letter.I));
        tiles.set(Tile(address(0), Position({x: 6, y: 0}), Letter.T));
        tiles.set(Tile(address(0), Position({x: 7, y: 0}), Letter.E));
    }

    /// ============ Private functions ============

    /// @notice Internal function to check if a move is valid and if so, play it on the board.
    /// @dev Making execute payable breaks the System interface, so executeInternal is needed.
    function executeInternal(
        Letter[] memory word,
        bytes32[] memory proof,
        Position memory position,
        Direction direction,
        Bounds memory bounds
    ) private {
        // Ensure game is not ever
        if (isGameOver()) revert GameOver();

        // Ensure payment is sufficient
        uint256 price = getPriceForWord(word);
        if (msg.value < price) revert PaymentTooLow();

        // Increment letter counts
        LetterCountComponent letterCount = LetterCountComponent(
            getAddressById(components, LetterCountComponentID)
        );
        for (uint32 i = 0; i < word.length; i++) {
            if (word[i] != Letter.EMPTY) {
                letterCount.incrementValueAtLetter(word[i]);
            }
        }

        // Increment treasury
        treasury += (msg.value * (rewardFraction - 1)) / rewardFraction;

        // Check if move is valid, and if so, make it
        makeMoveChecked(word, proof, position, direction, bounds);
    }

    /// @notice Checks if a move is valid, and if so, update TileComponent and ScoreComponent.
    function makeMoveChecked(
        Letter[] memory word,
        bytes32[] memory proof,
        Position memory position,
        Direction direction,
        Bounds memory bounds
    ) private {
        TileComponent tiles = TileComponent(
            getAddressById(components, TileComponentID)
        );
        checkWord(word, proof, position, direction, tiles);
        checkBounds(word, position, direction, bounds, tiles);
        Letter[] memory filledWord = processWord(
            word,
            position,
            direction,
            tiles
        );
        countPointsChecked(filledWord, position, direction, bounds, tiles);
    }

    /// @notice Checks if a word is 1) played on another word, 2) has at least one letter, 3) is a valid word, 4) has valid bounds, and 5) has not been played yet
    function checkWord(
        Letter[] memory word,
        bytes32[] memory proof,
        Position memory position,
        Direction direction,
        TileComponent tiles
    ) public view {
        // Ensure word is less than 200 letters
        if (word.length > 200) revert WordTooLong();
        // Ensure word isn't missing letters at edges
        if (
            tiles.hasTileAtPosition(
                LibBoard.getLetterPosition(-1, position, direction)
            )
        ) revert InvalidWordStart();
        if (
            tiles.hasTileAtPosition(
                LibBoard.getLetterPosition(
                    int32(uint32(word.length)),
                    position,
                    direction
                )
            )
        ) revert InvalidWordEnd();

        bool emptyTile = false;
        bool nonEmptyTile = false;

        Letter[] memory filledWord = new Letter[](word.length);

        for (uint32 i = 0; i < word.length; i++) {
            Position memory letterPosition = LibBoard.getLetterPosition(
                int32(i),
                position,
                direction
            );
            if (word[i] == Letter.EMPTY) {
                emptyTile = true;

                // Ensure empty letter is played on existing letter
                if (!tiles.hasTileAtPosition(letterPosition))
                    revert EmptyLetterNotOnExisting();

                filledWord[i] = tiles.getValueAtPosition(letterPosition).letter;
            } else {
                nonEmptyTile = true;

                // Ensure non-empty letter is played on empty tile
                if (tiles.hasTileAtPosition(letterPosition))
                    revert LetterOnExistingTile();

                filledWord[i] = word[i];
            }
        }

        // Ensure word is played on another word
        if (!emptyTile) revert LonelyWord();
        // Ensure word has at least one letter
        if (!nonEmptyTile) revert NoLettersPlayed();
        // Ensure word is a valid word
        LibBoard.verifyWordProof(filledWord, proof, merkleRoot);
    }

    /// @notice Checks if the given bounds for other words on the cross axis are well formed.
    function checkBounds(
        Letter[] memory word,
        Position memory position,
        Direction direction,
        Bounds memory bounds,
        TileComponent tiles
    ) private view {
        // Ensure bounds of equal length
        if (bounds.positive.length != bounds.negative.length)
            revert BoundsDoNotMatch();
        // Ensure bounds of correct length
        if (bounds.positive.length != word.length) revert InvalidBoundLength();
        // Ensure proof of correct length
        if (bounds.positive.length != bounds.proofs.length)
            revert InvalidCrossProofs();

        // Ensure positive and negative bounds are valid
        for (uint32 i; i < word.length; i++) {
            if (word[i] == Letter.EMPTY) {
                // Ensure bounds are 0 if letter is empty
                // since you cannot get points for words formed by letters you did not play
                if (bounds.positive[i] != 0 || bounds.negative[i] != 0)
                    revert InvalidEmptyLetterBound();
            } else {
                // Ensure bounds are valid (empty at edges) for nonempty letters
                // Bounds that are too large will be caught while verifying formed words
                (Position memory start, Position memory end) = LibBoard
                    .getOutsideBoundPositions(
                        LibBoard.getLetterPosition(
                            int32(i),
                            position,
                            direction
                        ),
                        direction,
                        bounds.positive[i],
                        bounds.negative[i]
                    );
                if (
                    tiles.hasTileAtPosition(start) ||
                    tiles.hasTileAtPosition(end)
                ) revert InvalidBoundEdges();
            }
        }
    }

    /// @notice 1) Places the word on the board, 2) adds word rewards to other players, and 3) returns a filled in word.
    /// @return filledWord A word that has empty letters replaced with the underlying letters from the board.
    function processWord(
        Letter[] memory word,
        Position memory position,
        Direction direction,
        TileComponent tiles
    ) private returns (Letter[] memory) {
        Letter[] memory filledWord = new Letter[](word.length);

        // Rewards are tracked in the score component
        ScoreComponent scores = ScoreComponent(
            getAddressById(components, ScoreComponentID)
        );

        // Evenly split the reward fraction of among tiles the player used to create their word
        // Rewards are only awarded to players who are used in the "primary" word
        uint256 rewardPerEmptyTile = LibBoard.getRewardPerEmptyTile(
            word,
            rewardFraction,
            msg.value
        );

        // Place tiles and fill filledWord
        for (uint32 i = 0; i < word.length; i++) {
            Position memory letterPosition = LibBoard.getLetterPosition(
                int32(i),
                position,
                direction
            );
            if (word[i] == Letter.EMPTY) {
                Tile memory tile = tiles.getValueAtPosition(letterPosition);
                scores.incrementValueAtAddress(
                    tile.player,
                    0,
                    rewardPerEmptyTile,
                    0
                );
                filledWord[i] = tile.letter;
            } else {
                tiles.set(
                    Tile(
                        msg.sender,
                        Position({x: letterPosition.x, y: letterPosition.y}),
                        word[i]
                    )
                );
                filledWord[i] = word[i];
            }
        }
        return filledWord;
    }

    /// @notice Updates the score for a player for the main word and cross words and checks every cross word.
    /// @dev Expects a word input with empty letters filled in
    function countPointsChecked(
        Letter[] memory filledWord,
        Position memory position,
        Direction direction,
        Bounds memory bounds,
        TileComponent tiles
    ) private {
        uint32 points = countPointsForWord(filledWord);
        // Count points for perpendicular word
        // This double counts points on purpose (points are recounted for every valid word)
        for (uint32 i; i < filledWord.length; i++) {
            if (bounds.positive[i] != 0 || bounds.negative[i] != 0) {
                Letter[] memory perpendicularWord = LibBoard
                    .getWordInBoundsChecked(
                        LibBoard.getLetterPosition(
                            int32(i),
                            position,
                            direction
                        ),
                        direction,
                        bounds.positive[i],
                        bounds.negative[i],
                        tiles
                    );
                LibBoard.verifyWordProof(
                    perpendicularWord,
                    bounds.proofs[i],
                    merkleRoot
                );
                points += countPointsForWord(perpendicularWord);
            }
        }
        ScoreComponent scores = ScoreComponent(
            getAddressById(components, ScoreComponentID)
        );
        scores.incrementValueAtAddress(msg.sender, msg.value, 0, points);
    }

    /// @notice Ge the points for a given word. The points are simply a sum of the letter point values.
    function countPointsForWord(Letter[] memory word)
        private
        view
        returns (uint32)
    {
        uint32 points;
        for (uint32 i; i < word.length; i++) {
            points += letterValue[word[i]];
        }
        return points;
    }

    /// @notice Get price for a letter using a linear VRGDA.
    function getPriceForLetter(Letter letter) public view returns (uint256) {
        LetterCountComponent letterCount = LetterCountComponent(
            getAddressById(components, LetterCountComponentID)
        );
        return
            getVRGDAPrice(
                toDaysWadUnsafe(block.timestamp - startTime),
                ((letterValue[letter] + 1) / 2) *
                    letterCount.getValueAtLetter(letter)
            );
    }

    /// @notice Get price for a word using a linear VRGDA.
    function getPriceForWord(Letter[] memory word)
        public
        view
        returns (uint256)
    {
        uint256 price;
        for (uint32 i = 0; i < word.length; i++) {
            if (word[i] != Letter.EMPTY) {
                price += getPriceForLetter(word[i]);
            }
        }
        return price;
    }

    /// @notice Get if game is over.
    function isGameOver() private view returns (bool) {
        return block.timestamp >= endTime;
    }

    /// ============ Setup functions ============

    function setupLetterPoints() private {
        letterValue[Letter.A] = 1;
        letterValue[Letter.B] = 3;
        letterValue[Letter.C] = 3;
        letterValue[Letter.D] = 2;
        letterValue[Letter.E] = 1;
        letterValue[Letter.F] = 4;
        letterValue[Letter.G] = 2;
        letterValue[Letter.H] = 4;
        letterValue[Letter.I] = 1;
        letterValue[Letter.J] = 8;
        letterValue[Letter.K] = 5;
        letterValue[Letter.L] = 1;
        letterValue[Letter.M] = 3;
        letterValue[Letter.N] = 1;
        letterValue[Letter.O] = 1;
        letterValue[Letter.P] = 3;
        letterValue[Letter.Q] = 10;
        letterValue[Letter.R] = 1;
        letterValue[Letter.S] = 1;
        letterValue[Letter.T] = 1;
        letterValue[Letter.U] = 1;
        letterValue[Letter.V] = 4;
        letterValue[Letter.W] = 4;
        letterValue[Letter.X] = 8;
        letterValue[Letter.Y] = 4;
        letterValue[Letter.Z] = 10;
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import { ISystem } from "./interfaces/ISystem.sol";
import { IUint256Component } from "./interfaces/IUint256Component.sol";
import { IWorld } from "./interfaces/IWorld.sol";

/**
 * System base contract
 */
abstract contract System is ISystem {
  IUint256Component components;
  IWorld world;
  address _owner;

  modifier onlyOwner() {
    require(msg.sender == _owner, "ONLY_OWNER");
    _;
  }

  constructor(IWorld _world, address _components) {
    _owner = msg.sender;
    components = _components == address(0) ? _world.components() : IUint256Component(_components);
    world = _world;
  }

  function owner() public view returns (address) {
    return _owner;
  }
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;
import { QueryType } from "./Query.sol";
import { IUint256Component } from "./IUint256Component.sol";

// For ProxyRead and ProxyExpand QueryFragments:
// - component must be a component whose raw value decodes to a single uint256
// - value must decode to a single uint256 represents the proxy depth
struct WorldQueryFragment {
  QueryType queryType;
  uint256 componentId;
  bytes value;
}

interface IWorld {
  function components() external view returns (IUint256Component);

  function systems() external view returns (IUint256Component);

  function registerComponent(address componentAddr, uint256 id) external;

  function getComponent(uint256 id) external view returns (address);

  function getComponentIdFromAddress(address componentAddr) external view returns (uint256);

  function registerSystem(address systemAddr, uint256 id) external;

  function registerComponentValueSet(
    address component,
    uint256 entity,
    bytes calldata data
  ) external;

  function registerComponentValueSet(uint256 entity, bytes calldata data) external;

  function registerComponentValueRemoved(address component, uint256 entity) external;

  function registerComponentValueRemoved(uint256 entity) external;

  function getNumEntities() external view returns (uint256);

  function hasEntity(uint256 entity) external view returns (bool);

  function getUniqueEntityId() external view returns (uint256);

  function query(WorldQueryFragment[] calldata worldQueryFragments) external view returns (uint256[] memory);
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import { IUint256Component } from "./interfaces/IUint256Component.sol";
import { IComponent } from "./interfaces/IComponent.sol";
import { ISystem } from "./interfaces/ISystem.sol";
import { systemsComponentId } from "./constants.sol";

/** Turn an entity ID into its corresponding Ethereum address. */
function entityToAddress(uint256 entity) pure returns (address) {
  return address(uint160(entity));
}

/** Turn an Ethereum address into its corresponding entity ID. */
function addressToEntity(address addr) pure returns (uint256) {
  return uint256(uint160(addr));
}

/** Get an Ethereum address from an address/id registry component (like _components/_systems in World.sol) */
function getAddressById(IUint256Component registry, uint256 id) view returns (address) {
  uint256[] memory entities = registry.getEntitiesWithValue(id);
  require(entities.length != 0, "id not registered");
  return entityToAddress(entities[0]);
}

/** Get an entity id from an address/id registry component (like _components/_systems in World.sol) */
function getIdByAddress(IUint256Component registry, address addr) view returns (uint256) {
  require(registry.has(addressToEntity(addr)), "address not registered");
  return registry.getValue(addressToEntity(addr));
}

/** Get a Component from an address/id registry component (like _components in World.sol) */
function getComponentById(IUint256Component components, uint256 id) view returns (IComponent) {
  return IComponent(getAddressById(components, id));
}

/**
 * Get the Ethereum address of a System from an address/id component registry component in which the
 * System registry component is registered (like _components in World.sol)
 */
function getSystemAddressById(IUint256Component components, uint256 id) view returns (address) {
  IUint256Component systems = IUint256Component(getAddressById(components, systemsComponentId));
  return getAddressById(systems, id);
}

/**
 * Get a System from an address/id component registry component in which the
 * System registry component is registered (like _components in World.sol)
 */
function getSystemById(IUint256Component components, uint256 id) view returns (ISystem) {
  return ISystem(getSystemAddressById(components, id));
}

// SPDX-License-Identifier: Unlicensed
// Adapted from Mud's CoordComponent (https://github.com/latticexyz/mud/blob/main/packages/std-contracts/src/components/CoordComponent.sol)
pragma solidity >=0.8.0;
import "solecs/BareComponent.sol";
import { Letter } from "../common/Letter.sol";
import { Tile } from "../common/Tile.sol";
import { Position } from "../common/Play.sol";

uint256 constant ID = uint256(keccak256("component.Tile"));

contract TileComponent is BareComponent {
  constructor(address world) BareComponent(world, ID) {}

  function getSchema() public pure override returns (string[] memory keys, LibTypes.SchemaValue[] memory values) {
    keys = new string[](1);
    values = new LibTypes.SchemaValue[](1);

    keys[0] = "value";
    values[0] = LibTypes.SchemaValue.UINT256;
  }

  function set(Tile calldata tile) public {
    set(
      getEntityAtPosition(tile.position),
      abi.encode(
        bytes32(
          bytes.concat(
            bytes20(tile.player),
            bytes4(uint32(tile.position.x)),
            bytes4(uint32(tile.position.y)),
            bytes1(uint8(tile.letter))
          )
        )
      )
    );
  }

  function getValue(uint256 entity) public view returns (Tile memory) {
    uint256 rawData = abi.decode(getRawValue(entity), (uint256));
    address player = address(uint160(rawData >> ((32 - 20) * 8)));
    int32 x = int32(uint32(((rawData << (20 * 8)) >> ((32 - 4) * 8))));
    int32 y = int32(uint32((rawData << (24 * 8)) >> ((32 - 4) * 8)));
    Letter letter = Letter(uint8((uint256(rawData) << (28 * 8)) >> ((32 - 1) * 8)));

    return Tile(player, Position({ x: x, y: y }), letter);
  }

  function hasTileAtPosition(Position memory position) public view returns (bool) {
    return has(getEntityAtPosition(position));
  }

  function getEntityAtPosition(Position memory position) public pure returns (uint256) {
    return uint256(keccak256(abi.encode(ID, position.x, position.y)));
  }

  function getValueAtPosition(Position memory position) public view returns (Tile memory) {
    return getValue(getEntityAtPosition(position));
  }
}

// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.8.0;
import "solecs/BareComponent.sol";
import { addressToEntity } from "solecs/utils.sol";
import { Score } from "../common/Score.sol";

uint256 constant ID = uint256(keccak256("component.Score"));

contract ScoreComponent is BareComponent {
  uint32 private totalScore;

  constructor(address world) BareComponent(world, ID) {}

  function getSchema() public pure override returns (string[] memory keys, LibTypes.SchemaValue[] memory values) {
    keys = new string[](3);
    values = new LibTypes.SchemaValue[](3);

    keys[0] = "spent";
    values[0] = LibTypes.SchemaValue.UINT256;

    keys[1] = "rewards";
    values[1] = LibTypes.SchemaValue.UINT256;

    keys[2] = "score";
    values[2] = LibTypes.SchemaValue.UINT32;
  }

  function set(
    address player,
    uint256 spent,
    uint256 rewards,
    uint32 score
  ) public {
    set(getEntityAtAddress(player), abi.encode(Score({ spent: spent, rewards: rewards, score: score })));
  }

  function getValue(uint256 entity) public view returns (Score memory) {
    Score memory score = abi.decode(getRawValue(entity), (Score));
    return score;
  }

  function getEntityAtAddress(address player) public pure returns (uint256) {
    return addressToEntity(player);
  }

  function getValueAtAddress(address player) public view returns (Score memory) {
    uint256 entity = getEntityAtAddress(player);
    return getValue(entity);
  }

  function hasValueAtAddress(address player) public view returns (bool) {
    return has(getEntityAtAddress(player));
  }

  function incrementValueAtAddress(
    address player,
    uint256 spent,
    uint256 rewards,
    uint32 score
  ) public {
    if (hasValueAtAddress(player)) {
      Score memory previous = getValueAtAddress(player);
      set(player, previous.spent + spent, previous.rewards + rewards, previous.score + score);
    } else {
      set(player, spent, rewards, score);
    }
    totalScore += score;
  }

  function getTotalScore() public view returns (uint32) {
    return totalScore;
  }
}

// SPDX-License-Identifier: Unlicense
// Adapted from UInt256 Component (cannot use default UInt256 Component since this must be bare)
pragma solidity >=0.8.0;
import { Letter } from "../common/Letter.sol";
import "std-contracts/components/UInt32BareComponent.sol";
import { console } from "forge-std/console.sol";


uint256 constant ID = uint256(keccak256("component.LetterCount"));

contract LetterCountComponent is Uint32BareComponent {
  constructor(address world) Uint32BareComponent(world, ID) {}

  function getEntityAtLetter(Letter letter) private pure returns (uint256) {
    return uint256(keccak256(abi.encode(ID, uint8(letter))));
  }

  function getValueAtLetter(Letter letter) public view returns (uint32) {
    uint256 entity = getEntityAtLetter(letter);
    if (!has(entity)) return 0;
    return getValue(entity);
  }

  function incrementValueAtLetter(Letter letter) public {
    uint256 entity = getEntityAtLetter(letter);
    uint256 letterCount = getValueAtLetter(letter);
    set(entity, abi.encode(letterCount + 1));
  }
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

// Letters
enum Letter {
  EMPTY,
  A,
  B,
  C,
  D,
  E,
  F,
  G,
  H,
  I,
  J,
  K,
  L,
  M,
  N,
  O,
  P,
  Q,
  R,
  S,
  T,
  U,
  V,
  W,
  X,
  Y,
  Z
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import { Letter } from "./Letter.sol";
import { Position } from "./Play.sol";

struct Tile {
  address player;
  Position position;
  Letter letter;
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

struct Score {
  uint256 spent;
  uint256 rewards;
  uint32 score;
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import { Letter } from "./Letter.sol";

struct Position {
  int32 x;
  int32 y;
}

// Boundaries for a played word
struct Bounds {
  uint32[] positive; // Distance in the positive direction
  uint32[] negative; // Distance in the negative direction
  bytes32[][] proofs;
}

enum Direction {
  LEFT_TO_RIGHT,
  TOP_TO_BOTTOM
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { unsafeWadDiv } from "solmate/utils/SignedWadMath.sol";
import { VRGDA } from "./VRGDA.sol";

/// @title Linear Variable Rate Gradual Dutch Auction
/// @author transmissions11 <[email protected]>
/// @author FrankieIsLost <[email protected]>
/// @notice VRGDA with a linear issuance curve.
abstract contract LinearVRGDA is VRGDA {
  /*//////////////////////////////////////////////////////////////
                           PRICING PARAMETERS
    //////////////////////////////////////////////////////////////*/

  /// @dev The total number of tokens to target selling every full unit of time.
  /// @dev Represented as an 18 decimal fixed point number.
  int256 internal immutable perTimeUnit;

  /// @notice Sets pricing parameters for the VRGDA.
  /// @param _targetPrice The target price for a token if sold on pace, scaled by 1e18.
  /// @param _priceDecayPercent The percent price decays per unit of time with no sales, scaled by 1e18.
  /// @param _perTimeUnit The number of tokens to target selling in 1 full unit of time, scaled by 1e18.
  constructor(
    int256 _targetPrice,
    int256 _priceDecayPercent,
    int256 _perTimeUnit
  ) VRGDA(_targetPrice, _priceDecayPercent) {
    perTimeUnit = _perTimeUnit;
  }

  /*//////////////////////////////////////////////////////////////
                              PRICING LOGIC
    //////////////////////////////////////////////////////////////*/

  /// @dev Given a number of tokens sold, return the target time that number of tokens should be sold by.
  /// @param sold A number of tokens sold, scaled by 1e18, to get the corresponding target sale time for.
  /// @return The target time the tokens should be sold by, scaled by 1e18, where the time is
  /// relative, such that 0 means the tokens should be sold immediately when the VRGDA begins.
  function getTargetSaleTime(int256 sold) public view virtual override returns (int256) {
    return unsafeWadDiv(sold, perTimeUnit);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @notice Signed 18 decimal fixed point (wad) arithmetic library.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SignedWadMath.sol)

/// @dev Will not revert on overflow, only use where overflow is not possible.
function toWadUnsafe(uint256 x) pure returns (int256 r) {
    assembly {
        // Multiply x by 1e18.
        r := mul(x, 1000000000000000000)
    }
}

/// @dev Takes an integer amount of seconds and converts it to a wad amount of days.
/// @dev Will not revert on overflow, only use where overflow is not possible.
/// @dev Not meant for negative second amounts, it assumes x is positive.
function toDaysWadUnsafe(uint256 x) pure returns (int256 r) {
    assembly {
        // Multiply x by 1e18 and then divide it by 86400.
        r := div(mul(x, 1000000000000000000), 86400)
    }
}

/// @dev Takes a wad amount of days and converts it to an integer amount of seconds.
/// @dev Will not revert on overflow, only use where overflow is not possible.
/// @dev Not meant for negative day amounts, it assumes x is positive.
function fromDaysWadUnsafe(int256 x) pure returns (uint256 r) {
    assembly {
        // Multiply x by 86400 and then divide it by 1e18.
        r := div(mul(x, 86400), 1000000000000000000)
    }
}

/// @dev Will not revert on overflow, only use where overflow is not possible.
function unsafeWadMul(int256 x, int256 y) pure returns (int256 r) {
    assembly {
        // Multiply x by y and divide by 1e18.
        r := sdiv(mul(x, y), 1000000000000000000)
    }
}

/// @dev Will return 0 instead of reverting if y is zero and will
/// not revert on overflow, only use where overflow is not possible.
function unsafeWadDiv(int256 x, int256 y) pure returns (int256 r) {
    assembly {
        // Multiply x by 1e18 and divide it by y.
        r := sdiv(mul(x, 1000000000000000000), y)
    }
}

function wadMul(int256 x, int256 y) pure returns (int256 r) {
    assembly {
        // Store x * y in r for now.
        r := mul(x, y)

        // Equivalent to require(x == 0 || (x * y) / x == y)
        if iszero(or(iszero(x), eq(sdiv(r, x), y))) {
            revert(0, 0)
        }

        // Scale the result down by 1e18.
        r := sdiv(r, 1000000000000000000)
    }
}

function wadDiv(int256 x, int256 y) pure returns (int256 r) {
    assembly {
        // Store x * 1e18 in r for now.
        r := mul(x, 1000000000000000000)

        // Equivalent to require(y != 0 && ((x * 1e18) / 1e18 == x))
        if iszero(and(iszero(iszero(y)), eq(sdiv(r, 1000000000000000000), x))) {
            revert(0, 0)
        }

        // Divide r by y.
        r := sdiv(r, y)
    }
}

function wadExp(int256 x) pure returns (int256 r) {
    unchecked {
        // When the result is < 0.5 we return zero. This happens when
        // x <= floor(log(0.5e18) * 1e18) ~ -42e18
        if (x <= -42139678854452767551) return 0;

        // When the result is > (2**255 - 1) / 1e18 we can not represent it as an
        // int. This happens when x >= floor(log((2**255 - 1) / 1e18) * 1e18) ~ 135.
        if (x >= 135305999368893231589) revert("EXP_OVERFLOW");

        // x is now in the range (-42, 136) * 1e18. Convert to (-42, 136) * 2**96
        // for more intermediate precision and a binary basis. This base conversion
        // is a multiplication by 1e18 / 2**96 = 5**18 / 2**78.
        x = (x << 78) / 5**18;

        // Reduce range of x to (-½ ln 2, ½ ln 2) * 2**96 by factoring out powers
        // of two such that exp(x) = exp(x') * 2**k, where k is an integer.
        // Solving this gives k = round(x / log(2)) and x' = x - k * log(2).
        int256 k = ((x << 96) / 54916777467707473351141471128 + 2**95) >> 96;
        x = x - k * 54916777467707473351141471128;

        // k is in the range [-61, 195].

        // Evaluate using a (6, 7)-term rational approximation.
        // p is made monic, we'll multiply by a scale factor later.
        int256 y = x + 1346386616545796478920950773328;
        y = ((y * x) >> 96) + 57155421227552351082224309758442;
        int256 p = y + x - 94201549194550492254356042504812;
        p = ((p * y) >> 96) + 28719021644029726153956944680412240;
        p = p * x + (4385272521454847904659076985693276 << 96);

        // We leave p in 2**192 basis so we don't need to scale it back up for the division.
        int256 q = x - 2855989394907223263936484059900;
        q = ((q * x) >> 96) + 50020603652535783019961831881945;
        q = ((q * x) >> 96) - 533845033583426703283633433725380;
        q = ((q * x) >> 96) + 3604857256930695427073651918091429;
        q = ((q * x) >> 96) - 14423608567350463180887372962807573;
        q = ((q * x) >> 96) + 26449188498355588339934803723976023;

        assembly {
            // Div in assembly because solidity adds a zero check despite the unchecked.
            // The q polynomial won't have zeros in the domain as all its roots are complex.
            // No scaling is necessary because p is already 2**96 too large.
            r := sdiv(p, q)
        }

        // r should be in the range (0.09, 0.25) * 2**96.

        // We now need to multiply r by:
        // * the scale factor s = ~6.031367120.
        // * the 2**k factor from the range reduction.
        // * the 1e18 / 2**96 factor for base conversion.
        // We do this all at once, with an intermediate result in 2**213
        // basis, so the final right shift is always by a positive amount.
        r = int256((uint256(r) * 3822833074963236453042738258902158003155416615667) >> uint256(195 - k));
    }
}

function wadLn(int256 x) pure returns (int256 r) {
    unchecked {
        require(x > 0, "UNDEFINED");

        // We want to convert x from 10**18 fixed point to 2**96 fixed point.
        // We do this by multiplying by 2**96 / 10**18. But since
        // ln(x * C) = ln(x) + ln(C), we can simply do nothing here
        // and add ln(2**96 / 10**18) at the end.

        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            r := or(r, shl(2, lt(0xf, shr(r, x))))
            r := or(r, shl(1, lt(0x3, shr(r, x))))
            r := or(r, lt(0x1, shr(r, x)))
        }

        // Reduce range of x to (1, 2) * 2**96
        // ln(2^k * x) = k * ln(2) + ln(x)
        int256 k = r - 96;
        x <<= uint256(159 - k);
        x = int256(uint256(x) >> 159);

        // Evaluate using a (8, 8)-term rational approximation.
        // p is made monic, we will multiply by a scale factor later.
        int256 p = x + 3273285459638523848632254066296;
        p = ((p * x) >> 96) + 24828157081833163892658089445524;
        p = ((p * x) >> 96) + 43456485725739037958740375743393;
        p = ((p * x) >> 96) - 11111509109440967052023855526967;
        p = ((p * x) >> 96) - 45023709667254063763336534515857;
        p = ((p * x) >> 96) - 14706773417378608786704636184526;
        p = p * x - (795164235651350426258249787498 << 96);

        // We leave p in 2**192 basis so we don't need to scale it back up for the division.
        // q is monic by convention.
        int256 q = x + 5573035233440673466300451813936;
        q = ((q * x) >> 96) + 71694874799317883764090561454958;
        q = ((q * x) >> 96) + 283447036172924575727196451306956;
        q = ((q * x) >> 96) + 401686690394027663651624208769553;
        q = ((q * x) >> 96) + 204048457590392012362485061816622;
        q = ((q * x) >> 96) + 31853899698501571402653359427138;
        q = ((q * x) >> 96) + 909429971244387300277376558375;
        assembly {
            // Div in assembly because solidity adds a zero check despite the unchecked.
            // The q polynomial is known not to have zeros in the domain.
            // No scaling required because p is already 2**96 too large.
            r := sdiv(p, q)
        }

        // r is in the range (0, 0.125) * 2**96

        // Finalization, we need to:
        // * multiply by the scale factor s = 5.549…
        // * add ln(2**96 / 10**18)
        // * add k * ln(2)
        // * multiply by 10**18 / 2**96 = 5**18 >> 78

        // mul s * 5e18 * 2**96, base is now 5**18 * 2**192
        r *= 1677202110996718588342820967067443963516166;
        // add ln(2) * k * 5e18 * 2**192
        r += 16597577552685614221487285958193947469193820559219878177908093499208371 * k;
        // add ln(2**96 / 10**18) * 5e18 * 2**192
        r += 600920179829731861736702779321621459595472258049074101567377883020018308;
        // base conversion: mul 2**18 / 2**192
        r >>= 174;
    }
}

/// @dev Will return 0 instead of reverting if y is zero.
function unsafeDiv(int256 x, int256 y) pure returns (int256 r) {
    assembly {
        // Divide x by y.
        r := sdiv(x, y)
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {Letter} from "../common/Letter.sol";
import {Position, Direction} from "../common/Play.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {TileComponent, ID as TileComponentID} from "../components/TileComponent.sol";
import "../common/Errors.sol";

library LibBoard {
    /// @notice Verifies a Merkle proof to check if a given word is in the dictionary.
    function verifyWordProof(
        Letter[] memory word,
        bytes32[] memory proof,
        bytes32 merkleRoot
    ) internal pure {
        bytes32 leaf = keccak256(abi.encodePacked(word));
        bool isValidLeaf = MerkleProof.verify(proof, merkleRoot, leaf);
        if (!isValidLeaf) revert InvalidWord();
    }

    /// @notice Get the amount of rewards paid to every empty tile in the word.
    function getRewardPerEmptyTile(
        Letter[] memory word,
        uint256 rewardFraction,
        uint256 value
    ) internal pure returns (uint256) {
        uint256 numEmptyTiles;
        for (uint32 i = 0; i < word.length; i++) {
            if (word[i] == Letter.EMPTY) numEmptyTiles++;
        }
        // msg.value / rewardFraction is total to be paid out in rewards, split across numEmptyTiles
        return (value / rewardFraction) / numEmptyTiles;
    }

    /// @notice Gets the position of a letter in a word given an offset and a direction.
    /// @dev Useful for looping through words.
    /// @param letterOffset The offset of the position from the start position.
    /// @param position The start position of the word.
    /// @param direction The direction the word is being played in.
    function getLetterPosition(
        int32 letterOffset,
        Position memory position,
        Direction direction
    ) internal pure returns (Position memory) {
        if (direction == Direction.LEFT_TO_RIGHT) {
            return Position(position.x + letterOffset, position.y);
        } else {
            return Position(position.x, position.y + letterOffset);
        }
    }

    /// @notice Gets the positions OUTSIDE a boundary on the boundary axis.
    /// @dev Useful for checking if a boundary is valid.
    /// @param letterPosition The start position of the letter for which the boundary is for.
    /// @param direction The direction the original word (not the boundary) is being played in.
    /// @param positive The distance the bound spans in the positive direction.
    /// @param negative The distance the bound spans in the negative direction.
    function getOutsideBoundPositions(
        Position memory letterPosition,
        Direction direction,
        uint32 positive,
        uint32 negative
    ) internal pure returns (Position memory, Position memory) {
        if (positive > 200 || negative > 200) revert BoundTooLong();
        Position memory start = Position(letterPosition.x, letterPosition.y);
        Position memory end = Position(letterPosition.x, letterPosition.y);
        if (direction == Direction.LEFT_TO_RIGHT) {
            start.y -= (int32(negative) + 1);
            end.y += (int32(positive) + 1);
        } else {
            start.x -= (int32(negative) + 1);
            end.x += (int32(positive) + 1);
        }
        return (start, end);
    }

    /// @notice Gets the word inside a given boundary and checks to make sure there are no empty letters in the bound.
    /// @dev Assumes that the word being made this round has already been played on board
    function getWordInBoundsChecked(
        Position memory letterPosition,
        Direction direction,
        uint32 positive,
        uint32 negative,
        TileComponent tiles
    ) internal view returns (Letter[] memory) {
        uint32 wordLength = positive + negative + 1;
        Letter[] memory word = new Letter[](wordLength);
        Position memory position;
        // Start at edge of negative bound
        if (direction == Direction.LEFT_TO_RIGHT) {
            position = LibBoard.getLetterPosition(
                -1 * int32(negative),
                letterPosition,
                Direction.TOP_TO_BOTTOM
            );
        } else {
            position = LibBoard.getLetterPosition(
                -1 * int32(negative),
                letterPosition,
                Direction.LEFT_TO_RIGHT
            );
        }
        for (uint32 i = 0; i < wordLength; i++) {
            word[i] = tiles.getValueAtPosition(position).letter;
            if (word[i] == Letter.EMPTY) revert EmptyLetterInBounds();
            if (direction == Direction.LEFT_TO_RIGHT) {
                position.y += 1;
            } else {
                position.x += 1;
            }
        }
        return word;
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

error BoundsDoNotMatch();
error InvalidBoundLength();
error InvalidWordStart();
error InvalidWordEnd();
error GameOver();
error GameNotOver();
error AlreadyClaimedPayout();
error PaymentTooLow();
error InvalidEmptyLetterBound();
error InvalidBoundEdges();
error InvalidWord();
error EmptyLetterInBounds();
error EmptyLetterNotOnExisting();
error LetterOnExistingTile();
error LonelyWord();
error NoLettersPlayed();
error AlreadySetupGrid();
error InvalidCrossProofs();
error BoundTooLong();
error WordTooLong();

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "./IOwned.sol";

// The minimum requirement for a system is to have an `execute` function.
// For convenience having an `executeTyped` function with typed arguments is recommended.
interface ISystem is IOwned {
  function execute(bytes memory arguments) external returns (bytes memory);
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import { IComponent } from "./IComponent.sol";

interface IUint256Component is IComponent {
  function set(uint256 entity, uint256 value) external;

  function getValue(uint256 entity) external view returns (uint256);

  function getEntitiesWithValue(uint256 value) external view returns (uint256[] memory);
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.13;
import { IComponent } from "./IComponent.sol";
import { LinkedList } from "memmove/LinkedList.sol";

enum QueryType {
  Has,
  Not,
  HasValue,
  NotValue,
  ProxyRead,
  ProxyExpand
}

// For ProxyRead and ProxyExpand QueryFragments:
// - component must be a component whose raw value decodes to a single uint256
// - value must decode to a single uint256 represents the proxy depth
struct QueryFragment {
  QueryType queryType;
  IComponent component;
  bytes value;
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "./IOwned.sol";

interface IComponent is IOwned {
  function transferOwnership(address newOwner) external;

  function set(uint256 entity, bytes memory value) external;

  function remove(uint256 entity) external;

  function has(uint256 entity) external view returns (bool);

  function getRawValue(uint256 entity) external view returns (bytes memory);

  function getEntities() external view returns (uint256[] memory);

  function getEntitiesWithValue(bytes memory value) external view returns (uint256[] memory);

  function authorizeWriter(address writer) external;

  function unauthorizeWriter(address writer) external;
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

uint256 constant componentsComponentId = uint256(keccak256("world.component.components"));
uint256 constant systemsComponentId = uint256(keccak256("world.component.systems"));

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import { IWorld } from "./interfaces/IWorld.sol";
import { IComponent } from "./interfaces/IComponent.sol";

import { Set } from "./Set.sol";
import { MapSet } from "./MapSet.sol";
import { LibTypes } from "./LibTypes.sol";

/**
 * Components are a key-value store from entity id to component value.
 * They are registered in the World and register updates to their state in the World.
 * They have an owner, who can grant write access to more addresses.
 * (Systems that want to write to a component need to be given write access first.)
 * Everyone has read access.
 */
abstract contract BareComponent is IComponent {
  error BareComponent__NotImplemented();

  /** Reference to the World contract this component is registered in */
  address public world;

  /** Owner of the component has write access and can given write access to other addresses */
  address internal _owner;

  /** Addresses with write access to this component */
  mapping(address => bool) public writeAccess;

  /** Mapping from entity id to value in this component */
  mapping(uint256 => bytes) internal entityToValue;

  /** Public identifier of this component */
  uint256 public id;

  constructor(address _world, uint256 _id) {
    _owner = msg.sender;
    writeAccess[msg.sender] = true;
    id = _id;
    if (_world != address(0)) registerWorld(_world);
  }

  /** Revert if caller is not the owner of this component */
  modifier onlyOwner() {
    require(msg.sender == _owner, "ONLY_OWNER");
    _;
  }

  /** Revert if caller does not have write access to this component */
  modifier onlyWriter() {
    require(writeAccess[msg.sender], "ONLY_WRITER");
    _;
  }

  /** Get the owner of this component */
  function owner() public view override returns (address) {
    return _owner;
  }

  /**
   * Transfer ownership of this component to a new owner.
   * Can only be called by the current owner.
   * @param newOwner Address of the new owner.
   */
  function transferOwnership(address newOwner) public override onlyOwner {
    writeAccess[msg.sender] = false;
    _owner = newOwner;
    writeAccess[newOwner] = true;
  }

  /**
   * Register this component in the given world.
   * @param _world Address of the World contract.
   */
  function registerWorld(address _world) public onlyOwner {
    world = _world;
    IWorld(world).registerComponent(address(this), id);
  }

  /**
   * Grant write access to this component to the given address.
   * Can only be called by the owner of this component.
   * @param writer Address to grant write access to.
   */
  function authorizeWriter(address writer) public override onlyOwner {
    writeAccess[writer] = true;
  }

  /**
   * Revoke write access to this component to the given address.
   * Can only be called by the owner of this component.
   * @param writer Address to revoke write access .
   */
  function unauthorizeWriter(address writer) public override onlyOwner {
    delete writeAccess[writer];
  }

  /**
   * Return the keys and value types of the schema of this component.
   */
  function getSchema() public pure virtual returns (string[] memory keys, LibTypes.SchemaValue[] memory values);

  /**
   * Set the given component value for the given entity.
   * Registers the update in the World contract.
   * Can only be called by addresses with write access to this component.
   * @param entity Entity to set the value for.
   * @param value Value to set for the given entity.
   */
  function set(uint256 entity, bytes memory value) public override onlyWriter {
    _set(entity, value);
  }

  /**
   * Remove the given entity from this component.
   * Registers the update in the World contract.
   * Can only be called by addresses with write access to this component.
   * @param entity Entity to remove from this component.
   */
  function remove(uint256 entity) public override onlyWriter {
    _remove(entity);
  }

  /**
   * Check whether the given entity has a value in this component.
   * @param entity Entity to check whether it has a value in this component for.
   */
  function has(uint256 entity) public view virtual override returns (bool) {
    return entityToValue[entity].length != 0;
  }

  /**
   * Get the raw (abi-encoded) value of the given entity in this component.
   * @param entity Entity to get the raw value in this component for.
   */
  function getRawValue(uint256 entity) public view virtual override returns (bytes memory) {
    // Return the entity's component value
    return entityToValue[entity];
  }

  function getEntities() public view virtual override returns (uint256[] memory) {
    revert BareComponent__NotImplemented();
  }

  function getEntitiesWithValue(bytes memory) public view virtual override returns (uint256[] memory) {
    revert BareComponent__NotImplemented();
  }

  function registerIndexer(address) external virtual {
    revert BareComponent__NotImplemented();
  }

  /**
   * Set the given component value for the given entity.
   * Registers the update in the World contract.
   * Can only be called internally (by the component or contracts deriving from it),
   * without requiring explicit write access.
   * @param entity Entity to set the value for.
   * @param value Value to set for the given entity.
   */
  function _set(uint256 entity, bytes memory value) internal virtual {
    // Store the entity's value;
    entityToValue[entity] = value;

    // Emit global event
    IWorld(world).registerComponentValueSet(entity, value);
  }

  /**
   * Remove the given entity from this component.
   * Registers the update in the World contract.
   * Can only be called internally (by the component or contracts deriving from it),
   * without requiring explicit write access.
   * @param entity Entity to remove from this component.
   */
  function _remove(uint256 entity) internal virtual {
    // Remove the entity from the mapping
    delete entityToValue[entity];

    // Emit global event
    IWorld(world).registerComponentValueRemoved(entity);
  }
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;
import "solecs/BareComponent.sol";

contract Uint32BareComponent is BareComponent {
  constructor(address world, uint256 id) BareComponent(world, id) {}

  function getSchema() public pure override returns (string[] memory keys, LibTypes.SchemaValue[] memory values) {
    keys = new string[](1);
    values = new LibTypes.SchemaValue[](1);

    keys[0] = "value";
    values[0] = LibTypes.SchemaValue.UINT32;
  }

  function set(uint256 entity, uint32 value) public {
    set(entity, abi.encode(value));
  }

  function getValue(uint256 entity) public view returns (uint32) {
    uint32 value = abi.decode(getRawValue(entity), (uint32));
    return value;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

library console {
    address constant CONSOLE_ADDRESS = address(0x000000000000000000636F6e736F6c652e6c6f67);

    function _sendLogPayload(bytes memory payload) private view {
        uint256 payloadLength = payload.length;
        address consoleAddress = CONSOLE_ADDRESS;
        /// @solidity memory-safe-assembly
        assembly {
            let payloadStart := add(payload, 32)
            let r := staticcall(gas(), consoleAddress, payloadStart, payloadLength, 0, 0)
        }
    }

    function log() internal view {
        _sendLogPayload(abi.encodeWithSignature("log()"));
    }

    function logInt(int p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(int)", p0));
    }

    function logUint(uint p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
    }

    function logString(string memory p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string)", p0));
    }

    function logBool(bool p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
    }

    function logAddress(address p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address)", p0));
    }

    function logBytes(bytes memory p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
    }

    function logBytes1(bytes1 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
    }

    function logBytes2(bytes2 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
    }

    function logBytes3(bytes3 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
    }

    function logBytes4(bytes4 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
    }

    function logBytes5(bytes5 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
    }

    function logBytes6(bytes6 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
    }

    function logBytes7(bytes7 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
    }

    function logBytes8(bytes8 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
    }

    function logBytes9(bytes9 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
    }

    function logBytes10(bytes10 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
    }

    function logBytes11(bytes11 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
    }

    function logBytes12(bytes12 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
    }

    function logBytes13(bytes13 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
    }

    function logBytes14(bytes14 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
    }

    function logBytes15(bytes15 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
    }

    function logBytes16(bytes16 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
    }

    function logBytes17(bytes17 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
    }

    function logBytes18(bytes18 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
    }

    function logBytes19(bytes19 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
    }

    function logBytes20(bytes20 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
    }

    function logBytes21(bytes21 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
    }

    function logBytes22(bytes22 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
    }

    function logBytes23(bytes23 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
    }

    function logBytes24(bytes24 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
    }

    function logBytes25(bytes25 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
    }

    function logBytes26(bytes26 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
    }

    function logBytes27(bytes27 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
    }

    function logBytes28(bytes28 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
    }

    function logBytes29(bytes29 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
    }

    function logBytes30(bytes30 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
    }

    function logBytes31(bytes31 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
    }

    function logBytes32(bytes32 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
    }

    function log(uint p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
    }

    function log(string memory p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string)", p0));
    }

    function log(bool p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
    }

    function log(address p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address)", p0));
    }

    function log(uint p0, uint p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint)", p0, p1));
    }

    function log(uint p0, string memory p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string)", p0, p1));
    }

    function log(uint p0, bool p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool)", p0, p1));
    }

    function log(uint p0, address p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address)", p0, p1));
    }

    function log(string memory p0, uint p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint)", p0, p1));
    }

    function log(string memory p0, string memory p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
    }

    function log(string memory p0, bool p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
    }

    function log(string memory p0, address p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
    }

    function log(bool p0, uint p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint)", p0, p1));
    }

    function log(bool p0, string memory p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
    }

    function log(bool p0, bool p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
    }

    function log(bool p0, address p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
    }

    function log(address p0, uint p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint)", p0, p1));
    }

    function log(address p0, string memory p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
    }

    function log(address p0, bool p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
    }

    function log(address p0, address p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address)", p0, p1));
    }

    function log(uint p0, uint p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint)", p0, p1, p2));
    }

    function log(uint p0, uint p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,string)", p0, p1, p2));
    }

    function log(uint p0, uint p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool)", p0, p1, p2));
    }

    function log(uint p0, uint p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,address)", p0, p1, p2));
    }

    function log(uint p0, string memory p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,uint)", p0, p1, p2));
    }

    function log(uint p0, string memory p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,string)", p0, p1, p2));
    }

    function log(uint p0, string memory p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,bool)", p0, p1, p2));
    }

    function log(uint p0, string memory p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,address)", p0, p1, p2));
    }

    function log(uint p0, bool p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint)", p0, p1, p2));
    }

    function log(uint p0, bool p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,string)", p0, p1, p2));
    }

    function log(uint p0, bool p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool)", p0, p1, p2));
    }

    function log(uint p0, bool p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,address)", p0, p1, p2));
    }

    function log(uint p0, address p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,uint)", p0, p1, p2));
    }

    function log(uint p0, address p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,string)", p0, p1, p2));
    }

    function log(uint p0, address p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,bool)", p0, p1, p2));
    }

    function log(uint p0, address p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,address)", p0, p1, p2));
    }

    function log(string memory p0, uint p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,uint)", p0, p1, p2));
    }

    function log(string memory p0, uint p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,string)", p0, p1, p2));
    }

    function log(string memory p0, uint p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,bool)", p0, p1, p2));
    }

    function log(string memory p0, uint p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,address)", p0, p1, p2));
    }

    function log(string memory p0, string memory p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,uint)", p0, p1, p2));
    }

    function log(string memory p0, string memory p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
    }

    function log(string memory p0, string memory p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
    }

    function log(string memory p0, string memory p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
    }

    function log(string memory p0, bool p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint)", p0, p1, p2));
    }

    function log(string memory p0, bool p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
    }

    function log(string memory p0, bool p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
    }

    function log(string memory p0, bool p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
    }

    function log(string memory p0, address p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,uint)", p0, p1, p2));
    }

    function log(string memory p0, address p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
    }

    function log(string memory p0, address p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
    }

    function log(string memory p0, address p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
    }

    function log(bool p0, uint p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint)", p0, p1, p2));
    }

    function log(bool p0, uint p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,string)", p0, p1, p2));
    }

    function log(bool p0, uint p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool)", p0, p1, p2));
    }

    function log(bool p0, uint p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,address)", p0, p1, p2));
    }

    function log(bool p0, string memory p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint)", p0, p1, p2));
    }

    function log(bool p0, string memory p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
    }

    function log(bool p0, string memory p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
    }

    function log(bool p0, string memory p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
    }

    function log(bool p0, bool p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint)", p0, p1, p2));
    }

    function log(bool p0, bool p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
    }

    function log(bool p0, bool p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
    }

    function log(bool p0, bool p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
    }

    function log(bool p0, address p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint)", p0, p1, p2));
    }

    function log(bool p0, address p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
    }

    function log(bool p0, address p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
    }

    function log(bool p0, address p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
    }

    function log(address p0, uint p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,uint)", p0, p1, p2));
    }

    function log(address p0, uint p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,string)", p0, p1, p2));
    }

    function log(address p0, uint p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,bool)", p0, p1, p2));
    }

    function log(address p0, uint p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,address)", p0, p1, p2));
    }

    function log(address p0, string memory p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,uint)", p0, p1, p2));
    }

    function log(address p0, string memory p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
    }

    function log(address p0, string memory p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
    }

    function log(address p0, string memory p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
    }

    function log(address p0, bool p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint)", p0, p1, p2));
    }

    function log(address p0, bool p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
    }

    function log(address p0, bool p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
    }

    function log(address p0, bool p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
    }

    function log(address p0, address p1, uint p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,uint)", p0, p1, p2));
    }

    function log(address p0, address p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
    }

    function log(address p0, address p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
    }

    function log(address p0, address p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
    }

    function log(uint p0, uint p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, uint p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,string)", p0, p1, p2, p3));
    }

    function log(uint p0, uint p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, uint p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,address)", p0, p1, p2, p3));
    }

    function log(uint p0, uint p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, uint p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,string)", p0, p1, p2, p3));
    }

    function log(uint p0, uint p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, uint p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,address)", p0, p1, p2, p3));
    }

    function log(uint p0, uint p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, uint p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,string)", p0, p1, p2, p3));
    }

    function log(uint p0, uint p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, uint p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,address)", p0, p1, p2, p3));
    }

    function log(uint p0, uint p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, uint p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,string)", p0, p1, p2, p3));
    }

    function log(uint p0, uint p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, uint p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,address)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,string)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,address)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,string,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,string,string)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,string,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,string,address)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,string)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,address)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,address,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,address,string)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,address,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, string memory p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,address,address)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,string)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,address)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,string)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,address)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,string)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,address)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,string)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, bool p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,address)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,string)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,address)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,string,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,string,string)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,string,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,string,address)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,string)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,address)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,address,uint)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,address,string)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,address,bool)", p0, p1, p2, p3));
    }

    function log(uint p0, address p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,address,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,string,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,string,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,string,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,string,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,address,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,address,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,address,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,address,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,uint,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,uint,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,uint,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,uint,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,string,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,address,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,uint,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,uint,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,uint,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,uint,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,string,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,address,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,string)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,address)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,string)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,address)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,string)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,address)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,string)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, uint p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,address)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,string)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,address)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,string)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,address)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,string)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,address)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,uint)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,string)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,bool)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,address)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,string,uint)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,string,string)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,string,bool)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,string,address)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,uint)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,string)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,bool)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,address)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,address,uint)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,address,string)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,address,bool)", p0, p1, p2, p3));
    }

    function log(address p0, uint p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,address,address)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,uint,uint)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,uint,string)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,uint,bool)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,uint,address)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,string,uint)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,uint)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,address,uint)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,uint)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,string)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,bool)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,address)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,uint)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,uint)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,uint)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, uint p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,uint,uint)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, uint p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,uint,string)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, uint p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,uint,bool)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, uint p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,uint,address)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, string memory p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,string,uint)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, bool p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,uint)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, address p2, uint p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,address,uint)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3));
    }

}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { wadExp, wadLn, wadMul, unsafeWadMul, toWadUnsafe } from "solmate/utils/SignedWadMath.sol";

/// @title Variable Rate Gradual Dutch Auction
/// @author transmissions11 <[email protected]>
/// @author FrankieIsLost <[email protected]>
/// @notice Sell tokens roughly according to an issuance schedule.
abstract contract VRGDA {
  /*//////////////////////////////////////////////////////////////
                            VRGDA PARAMETERS
    //////////////////////////////////////////////////////////////*/

  /// @notice Target price for a token, to be scaled according to sales pace.
  /// @dev Represented as an 18 decimal fixed point number.
  int256 public immutable targetPrice;

  /// @dev Precomputed constant that allows us to rewrite a pow() as an exp().
  /// @dev Represented as an 18 decimal fixed point number.
  int256 internal immutable decayConstant;

  /// @notice Sets target price and per time unit price decay for the VRGDA.
  /// @param _targetPrice The target price for a token if sold on pace, scaled by 1e18.
  /// @param _priceDecayPercent The percent price decays per unit of time with no sales, scaled by 1e18.
  constructor(int256 _targetPrice, int256 _priceDecayPercent) {
    targetPrice = _targetPrice;

    decayConstant = wadLn(1e18 - _priceDecayPercent);

    // The decay constant must be negative for VRGDAs to work.
    require(decayConstant < 0, "NON_NEGATIVE_DECAY_CONSTANT");
  }

  /*//////////////////////////////////////////////////////////////
                              PRICING LOGIC
    //////////////////////////////////////////////////////////////*/

  /// @notice Calculate the price of a token according to the VRGDA formula.
  /// @param timeSinceStart Time passed since the VRGDA began, scaled by 1e18.
  /// @param sold The total number of tokens that have been sold so far.
  /// @return The price of a token according to VRGDA, scaled by 1e18.
  function getVRGDAPrice(int256 timeSinceStart, uint256 sold) public view virtual returns (uint256) {
    unchecked {
      // prettier-ignore
      return uint256(wadMul(targetPrice, wadExp(unsafeWadMul(decayConstant,
                // Theoretically calling toWadUnsafe with sold can silently overflow but under
                // any reasonable circumstance it will never be large enough. We use sold + 1 as
                // the VRGDA formula's n param represents the nth token and sold is the n-1th token.
                timeSinceStart - getTargetSaleTime(toWadUnsafe(sold + 1))
            ))));
    }
  }

  /// @dev Given a number of tokens sold, return the target time that number of tokens should be sold by.
  /// @param sold A number of tokens sold, scaled by 1e18, to get the corresponding target sale time for.
  /// @return The target time the tokens should be sold by, scaled by 1e18, where the time is
  /// relative, such that 0 means the tokens should be sold immediately when the VRGDA begins.
  function getTargetSaleTime(int256 sold) public view virtual returns (int256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Tree proofs.
 *
 * The tree and the proofs can be generated using our
 * https://github.com/OpenZeppelin/merkle-tree[JavaScript library].
 * You will find a quickstart guide in the readme.
 *
 * WARNING: You should avoid using leaf values that are 64 bytes long prior to
 * hashing, or use a hash function other than keccak256 for hashing leaves.
 * This is because the concatenation of a sorted pair of internal nodes in
 * the merkle tree could be reinterpreted as a leaf value.
 * OpenZeppelin's JavaScript library generates merkle trees that are safe
 * against this attack out of the box.
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Calldata version of {verify}
     *
     * _Available since v4.7._
     */
    function verifyCalldata(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProofCalldata(proof, leaf) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. When processing the proof, the pairs
     * of leafs & pre-images are assumed to be sorted.
     *
     * _Available since v4.4._
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Calldata version of {processProof}
     *
     * _Available since v4.7._
     */
    function processProofCalldata(bytes32[] calldata proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Returns true if the `leaves` can be simultaneously proven to be a part of a merkle tree defined by
     * `root`, according to `proof` and `proofFlags` as described in {processMultiProof}.
     *
     * CAUTION: Not all merkle trees admit multiproofs. See {processMultiProof} for details.
     *
     * _Available since v4.7._
     */
    function multiProofVerify(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProof(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Calldata version of {multiProofVerify}
     *
     * CAUTION: Not all merkle trees admit multiproofs. See {processMultiProof} for details.
     *
     * _Available since v4.7._
     */
    function multiProofVerifyCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProofCalldata(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Returns the root of a tree reconstructed from `leaves` and sibling nodes in `proof`. The reconstruction
     * proceeds by incrementally reconstructing all inner nodes by combining a leaf/inner node with either another
     * leaf/inner node or a proof sibling node, depending on whether each `proofFlags` item is true or false
     * respectively.
     *
     * CAUTION: Not all merkle trees admit multiproofs. To use multiproofs, it is sufficient to ensure that: 1) the tree
     * is complete (but not necessarily perfect), 2) the leaves to be proven are in the opposite order they are in the
     * tree (i.e., as seen from right to left starting at the deepest layer and continuing at the next layer).
     *
     * _Available since v4.7._
     */
    function processMultiProof(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuild the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        require(leavesLen + proof.length - 1 == totalHashes, "MerkleProof: invalid multiproof");

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value for the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i] ? leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++] : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            return hashes[totalHashes - 1];
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    /**
     * @dev Calldata version of {processMultiProof}.
     *
     * CAUTION: Not all merkle trees admit multiproofs. See {processMultiProof} for details.
     *
     * _Available since v4.7._
     */
    function processMultiProofCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuild the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        require(leavesLen + proof.length - 1 == totalHashes, "MerkleProof: invalid multiproof");

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value for the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i] ? leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++] : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            return hashes[totalHashes - 1];
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

interface IOwned {
  function owner() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import "./Array.sol";

type LinkedList is bytes32;

// A basic wrapper around an array that returns a pointer to an element in
// the array. Unfortunately without generics, the user has to cast from a pointer to a type
// held in memory manually
//
// is indexable
//
// data structure:
//   |-----------------------------|                      |-------|
//   |                             v                      |       v  
// [ptr, ptr2, ptr3, ptr4]         {value, other value, next}     {value, other value, next}
//        |                                                       ^
//        |-------------------------------------------------------|
//
// where `mload(add(ptr, linkingOffset))` (aka `next`) == ptr2

library IndexableLinkedListLib {
    using ArrayLib for Array;

    function newIndexableLinkedList(uint16 capacityHint) internal pure returns (LinkedList s) {
        s = LinkedList.wrap(Array.unwrap(ArrayLib.newArray(capacityHint)));
    }

    function capacity(LinkedList self) internal pure returns (uint256 cap) {
        cap = Array.wrap(LinkedList.unwrap(self)).capacity();
    }

    function length(LinkedList self) internal pure returns (uint256 len) {
        len = Array.wrap(LinkedList.unwrap(self)).length();
    }

    function push_no_link(LinkedList self, bytes32 element) internal view returns (LinkedList s) {
        s = LinkedList.wrap(
            Array.unwrap(
                Array.wrap(LinkedList.unwrap(self)).push(uint256(element))
            )
        );
    }

    // linkingOffset is the offset from the element ptr that is written to 
    function push_and_link(LinkedList self, bytes32 element, uint256 linkingOffset) internal view returns (LinkedList s) {
        Array asArray = Array.wrap(LinkedList.unwrap(self));

        uint256 len = asArray.length();
        if (len == 0) {
            // nothing to link to
            Array arrayS = asArray.push(uint256(element), 3);
            s = LinkedList.wrap(Array.unwrap(arrayS));
        } else {
            // over alloc by 3
            Array arrayS = asArray.push(uint256(element), 3);
            uint256 newPtr = arrayS.unsafe_get(len);
            uint256 lastPtr = arrayS.unsafe_get(len - 1);
            
            // link the previous element with the new element
            assembly ("memory-safe") {
                mstore(add(lastPtr, linkingOffset), newPtr)
            }

            s = LinkedList.wrap(Array.unwrap(arrayS));
        }
    }

    function next(LinkedList /*self*/, bytes32 element, uint256 linkingOffset) internal pure returns (bool exists, bytes32 elem) {
        assembly ("memory-safe") {
            elem := mload(add(element, linkingOffset))
            exists := gt(elem, 0x00)
        }
    }

    function get(LinkedList self, uint256 index) internal pure returns (bytes32 elementPointer) {
        elementPointer = bytes32(Array.wrap(LinkedList.unwrap(self)).get(index));
    }

    function unsafe_get(LinkedList self, uint256 index) internal pure returns (bytes32 elementPointer) {
        elementPointer = bytes32(Array.wrap(LinkedList.unwrap(self)).unsafe_get(index));
    }
}

// the only way to traverse is to start at head and iterate via `next`. More memory efficient, better for maps
//
// data structure:
//   |-------------------------tail----------------------------|
//   |head|                                           |--------|
//   |    v                                           |        v
//  head, dataStruct{.., next} }     dataStruct{.., next}     dataStruct{.., next}
//                          |          ^
//                          |----------|
//
// `head` is a packed word split as 80, 80, 80 of linking offset, ptr to first element, ptr to last element
// `head` *isn't* stored in memory because it fits in a word 

library LinkedListLib {
    uint256 constant HEAD_MASK = 0xFFFFFFFFFFFFFFFFFFFF00000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    uint256 constant TAIL_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000000;

    function newLinkedList(uint80 _linkingOffset) internal pure returns (LinkedList s) {
        assembly ("memory-safe") {
            s := shl(176, _linkingOffset)
        }
    }

    function tail(LinkedList s) internal pure returns (bytes32 elemPtr) {
        assembly ("memory-safe") {
            elemPtr := shr(176, shl(160, s))
        }
    }

    function head(LinkedList s) internal pure returns (bytes32 elemPtr) {
        assembly ("memory-safe") {
            elemPtr := shr(176, shl(80, s))
        }
    }

    function linkingOffset(LinkedList s) internal pure returns (uint80 offset) {
        assembly ("memory-safe") {
            offset := shr(176, s)
        }
    }

    function set_head(LinkedList self, bytes32 element) internal pure returns (LinkedList s) {
        assembly ("memory-safe") {
            s := or(and(self, HEAD_MASK), shl(96, element))
        }
    }

    // manually links one element to another
    function set_link(LinkedList self, bytes32 prevElem, bytes32 nextElem) internal pure {
        assembly ("memory-safe") {
            // store the new element as the `next` ptr for the tail
            mstore(
                add(
                    prevElem, // get the tail ptr
                    shr(176, self) // add the offset size to get `next`
                ),
                nextElem
            )
        }
    }

    function push_and_link(LinkedList self, bytes32 element) internal pure returns (LinkedList s) {
        assembly ("memory-safe") {
            switch gt(shr(176, shl(80, self)), 0) 
            case 1 {
                // store the new element as the `next` ptr for the tail
                mstore(
                    add(
                        shr(176, shl(160, self)), // get the tail ptr
                        shr(176, self) // add the offset size to get `next`
                    ),
                    element
                )

                // update the tail ptr
                s := or(and(self, TAIL_MASK), shl(16, element))
            }
            default {
                // no head, set element as head and tail
                s := or(or(self, shl(96, element)), shl(16, element))
            }
        }
    }

    function next(LinkedList self, bytes32 element) internal pure returns (bool exists, bytes32 elem) {
        assembly ("memory-safe") {
            elem := mload(add(element, shr(176, self)))
            exists := gt(elem, 0x00)
        }
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

/**
 * Set of unique uint256
 */
contract Set {
  address private owner;
  uint256[] private items;
  mapping(uint256 => uint256) private itemToIndex;

  constructor() {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "ONLY_OWNER");
    _;
  }

  function add(uint256 item) public onlyOwner {
    if (has(item)) return;

    itemToIndex[item] = items.length;
    items.push(item);
  }

  function remove(uint256 item) public onlyOwner {
    if (!has(item)) return;

    // Copy the last item to the given item's index
    items[itemToIndex[item]] = items[items.length - 1];

    // Update the moved item's stored index to the new index
    itemToIndex[items[itemToIndex[item]]] = itemToIndex[item];

    // Remove the given item's stored index
    delete itemToIndex[item];

    // Remove the last item
    items.pop();
  }

  function getIndex(uint256 item) public view returns (bool, uint256) {
    if (!has(item)) return (false, 0);

    return (true, itemToIndex[item]);
  }

  function has(uint256 item) public view returns (bool) {
    if (items.length == 0) return false;
    if (itemToIndex[item] == 0) return items[0] == item;
    return itemToIndex[item] != 0;
  }

  function getItems() public view returns (uint256[] memory) {
    return items;
  }

  function size() public view returns (uint256) {
    return items.length;
  }
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

/**
 * Key value store with uint256 key and uint256 Set value
 */
contract MapSet {
  address private owner;
  mapping(uint256 => uint256[]) private items;
  mapping(uint256 => mapping(uint256 => uint256)) private itemToIndex;

  constructor() {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "ONLY_OWNER");
    _;
  }

  function add(uint256 setKey, uint256 item) public onlyOwner {
    if (has(setKey, item)) return;

    itemToIndex[setKey][item] = items[setKey].length;
    items[setKey].push(item);
  }

  function remove(uint256 setKey, uint256 item) public onlyOwner {
    if (!has(setKey, item)) return;

    // Copy the last item to the given item's index
    items[setKey][itemToIndex[setKey][item]] = items[setKey][items[setKey].length - 1];

    // Update the moved item's stored index to the new index
    itemToIndex[setKey][items[setKey][itemToIndex[setKey][item]]] = itemToIndex[setKey][item];

    // Remove the given item's stored index
    delete itemToIndex[setKey][item];

    // Remove the last item
    items[setKey].pop();
  }

  function has(uint256 setKey, uint256 item) public view returns (bool) {
    if (items[setKey].length == 0) return false;
    if (itemToIndex[setKey][item] == 0) return items[setKey][0] == item;
    return itemToIndex[setKey][item] != 0;
  }

  function getItems(uint256 setKey) public view returns (uint256[] memory) {
    return items[setKey];
  }

  function size(uint256 setKey) public view returns (uint256) {
    return items[setKey].length;
  }
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.13;

/**
 * Enum of supported schema types
 */
library LibTypes {
  enum SchemaValue {
    BOOL,
    INT8,
    INT16,
    INT32,
    INT64,
    INT128,
    INT256,
    INT,
    UINT8,
    UINT16,
    UINT32,
    UINT64,
    UINT128,
    UINT256,
    BYTES,
    STRING,
    ADDRESS,
    BYTES4,
    BOOL_ARRAY,
    INT8_ARRAY,
    INT16_ARRAY,
    INT32_ARRAY,
    INT64_ARRAY,
    INT128_ARRAY,
    INT256_ARRAY,
    INT_ARRAY,
    UINT8_ARRAY,
    UINT16_ARRAY,
    UINT32_ARRAY,
    UINT64_ARRAY,
    UINT128_ARRAY,
    UINT256_ARRAY,
    BYTES_ARRAY,
    STRING_ARRAY
  }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

// create a user defined type that is a pointer to memory
type Array is bytes32;

/* 
Memory layout:
offset..offset+32: current first unset element (cheaper to have it first most of the time), aka "length"
offset+32..offset+64: capacity of elements in array
offset+64..offset+64+(capacity*32): elements

nominclature:
 - capacity: total number of elements able to be stored prior to having to perform a move
 - length/current unset index: the number of defined items in the array

a dynamic array is such a primitive data structure that it should be extremely optimized. so everything is in assembly
*/
library ArrayLib {
    function newArray(uint16 capacityHint) internal pure returns (Array s) {
        assembly ("memory-safe") {
            // grab free mem ptr
            s := mload(0x40)
            
            // update free memory pointer based on array's layout:
            //  + 32 bytes for capacity
            //  + 32 bytes for current unset pointer/length
            //  + 32*capacity
            //  + current free memory pointer (s is equal to mload(0x40)) 
            mstore(0x40, add(s, mul(add(0x02, capacityHint), 0x20)))

            // store the capacity in the second word (see memory layout above)
            mstore(add(0x20, s), capacityHint)

            // store length as 0 because otherwise the compiler may have rugged us
            mstore(s, 0x00)
        }
    }

    // capacity of elements before a move would occur
    function capacity(Array self) internal pure returns (uint256 cap) {
        assembly ("memory-safe") {
            cap := mload(add(0x20, self))
        }
    }

    // number of set elements in the array
    function length(Array self) internal pure returns (uint256 len) {
        assembly ("memory-safe") {
            len := mload(self)
        }
    }

    // gets a ptr to an element
    function unsafe_ptrToElement(Array self, uint256 index) internal pure returns (bytes32 ptr) {
        assembly ("memory-safe") {
            ptr := add(self, mul(0x20, add(0x02, index)))
        }
    }

    // overloaded to default push function with 0 overallocation
    function push(Array self, uint256 elem) internal view returns (Array ret) {
        ret = push(self, elem, 0);
    }

    // push an element safely into the array - will perform a move if needed as well as updating the free memory pointer
    // returns the new pointer.
    //
    // WARNING: if a move occurs, the user *must* update their pointer, thus the returned updated pointer. safest
    // method is *always* updating the pointer
    function push(Array self, uint256 elem, uint256 overalloc) internal view returns (Array) {
        Array ret;
        assembly ("memory-safe") {
            // set the return ptr
            ret := self
            // check if length == capacity (meaning no more preallocated space)
            switch eq(mload(self), mload(add(0x20, self))) 
            case 1 {
                // optimization: check if the free memory pointer is equal to the end of the preallocated space
                // if it is, we can just natively extend the array because nothing has been allocated *after*
                // us. i.e.:
                // evm_memory = [00...free_mem_ptr...Array.length...Array.lastElement]
                // this check compares free_mem_ptr to Array.lastElement, if they are equal, we know there is nothing after
                //
                // optimization 2: length == capacity in this case (per above) so we can avoid an add to look at capacity
                // to calculate where the last element it
                switch eq(mload(0x40), add(self, mul(add(0x02, mload(self)), 0x20))) 
                case 1 {
                    // the free memory pointer hasn't moved, i.e. free_mem_ptr == Array.lastElement, just extend

                    // Add 1 to the Array.capacity
                    mstore(add(0x20, self), add(0x01, mload(add(0x20, self))))

                    // the free mem ptr is where we want to place the next element
                    mstore(mload(0x40), elem)

                    // move the free_mem_ptr by a word (32 bytes. 0x20 in hex)
                    mstore(0x40, add(0x20, mload(0x40)))

                    // update the length
                    mstore(self, add(0x01, mload(self)))
                }
                default {
                    // we couldn't do the above optimization, use the `identity` precompile to perform a memory move
                    
                    // move the array to the free mem ptr by using the identity precompile which just returns the values
                    let array_size := mul(add(0x02, mload(self)), 0x20)
                    pop(
                        staticcall(
                            gas(), // pass gas
                            0x04,  // call identity precompile address 
                            self,  // arg offset == pointer to self
                            array_size,  // arg size: capacity + 2 * word_size (we add 2 to capacity to account for capacity and length words)
                            mload(0x40), // set return buffer to free mem ptr
                            array_size   // identity just returns the bytes of the input so equal to argsize 
                        )
                    )
                    
                    // add the element to the end of the array
                    mstore(add(mload(0x40), array_size), elem)

                    // add to the capacity
                    mstore(
                        add(0x20, mload(0x40)), // free_mem_ptr + word == new capacity word
                        add(add(0x01, overalloc), mload(add(0x20, mload(0x40)))) // add one + overalloc to capacity
                    )

                    // add to length
                    mstore(mload(0x40), add(0x01, mload(mload(0x40))))

                    // set the return ptr to the new array
                    ret := mload(0x40)

                    // update free memory pointer
                    // we also over allocate if requested
                    mstore(0x40, add(add(array_size, add(0x20, mul(overalloc, 0x20))), mload(0x40)))
                }
            }
            default {
                // we have capacity for the new element, store it
                mstore(
                    // mem_loc := capacity_ptr + (capacity + 2) * 32
                    // we add 2 to capacity to acct for capacity and length words, then multiply by element size
                    add(self, mul(add(0x02, mload(self)), 0x20)), 
                    elem
                )

                // update length
                mstore(self, add(0x01, mload(self)))
            }
        }
        return ret;
    }

    // used when you *guarantee* that the array has the capacity available to be pushed to.
    // no need to update return pointer in this case
    //
    // NOTE: marked as memory safe, but potentially not memory safe if the safety contract is broken by the caller
    function unsafe_push(Array self, uint256 elem) internal pure {
        assembly ("memory-safe") {
            mstore(
                // mem_loc := capacity_ptr + (capacity + 2) * 32
                // we add 2 to capacity to acct for capacity and length words, then multiply by element size
                add(self, mul(add(0x02, mload(self)), 0x20)),
                elem
            )

            // update length
            mstore(self, add(0x01, mload(self)))
        }
    }

    // used when you *guarantee* that the index, i, is within the bounds of length
    // NOTE: marked as memory safe, but potentially not memory safe if the safety contract is broken by the caller
    function unsafe_set(Array self, uint256 i, uint256 value) internal pure {
        assembly ("memory-safe") {
            mstore(add(self, mul(0x20, add(0x02, i))), value)
        }
    }

    function set(Array self, uint256 i, uint256 value) internal pure {
        // if the index is greater than or equal to the capacity, revert
        assembly ("memory-safe") {
            if lt(mload(add(0x20, self)), i) {
                // emit compiler native Panic(uint256) style error
                mstore(0x00, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x32)
                revert(0, 0x24)
            }
            mstore(add(self, mul(0x20, add(0x02, i))), value)
        }
    }

    // used when you *guarantee* that the index, i, is within the bounds of length
    // NOTE: marked as memory safe, but potentially not memory safe if the safety contract is broken by the caller
    function unsafe_get(Array self, uint256 i) internal pure returns (uint256 s) {
        assembly ("memory-safe") {
            s := mload(add(self, mul(0x20, add(0x02, i))))
        }
    }

    // a safe `get` that checks capacity
    function get(Array self, uint256 i) internal pure returns (uint256 s) {
        // if the index is greater than or equal to the capacity, revert
        assembly ("memory-safe") {
            if lt(mload(add(0x20, self)), i) {
                // emit compiler native Panic(uint256) style error
                mstore(0x00, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x32)
                revert(0, 0x24)
            }
            s := mload(add(self, mul(0x20, add(0x02, i))))
        }
    } 
}

// A wrapper around the lower level array that does one layer of indirection so that the pointer
// the user has to hold never moves. Effectively a reference to the array. i.e. push doesn't return anything
// because it doesnt need to. Slightly less efficient, generally adds 1-3 memops per func
library RefArrayLib {
    using ArrayLib for Array;

    function newArray(uint16 capacityHint) internal pure returns (Array s) {
        Array referenced = ArrayLib.newArray(capacityHint);
        assembly ("memory-safe") {
            // grab free memory pointer for return value
            s := mload(0x40)
            // store referenced array in s
            mstore(mload(0x40), referenced)
            // update free mem ptr
            mstore(0x40, add(mload(0x40), 0x20))
        }
    }

    // capacity of elements before a move would occur
    function capacity(Array self) internal pure returns (uint256 cap) {
        assembly ("memory-safe") {
            cap := mload(add(0x20, mload(self)))
        }
    }

    // number of set elements in the array
    function length(Array self) internal pure returns (uint256 len) {
        assembly ("memory-safe") {
            len := mload(mload(self))
        }
    }

    // gets a ptr to an element
    function unsafe_ptrToElement(Array self, uint256 index) internal pure returns (bytes32 ptr) {
        assembly ("memory-safe") {
            ptr := add(mload(self), mul(0x20, add(0x02, index)))
        }
    }

    // overloaded to default push function with 0 overallocation
    function push(Array self, uint256 elem) internal view {
        push(self, elem, 0);
    }

    // dereferences the array
    function deref(Array self) internal pure returns (Array s) {
        assembly ("memory-safe") {
            s := mload(self)
        }
    }

    // push an element safely into the array - will perform a move if needed as well as updating the free memory pointer
    function push(Array self, uint256 elem, uint256 overalloc) internal view {
        Array newArr = deref(self).push(elem, overalloc);
        assembly ("memory-safe") {
            // we always just update the pointer because it is cheaper to do so than check whether
            // the array moved
            mstore(self, newArr)
        }
    }

    // used when you *guarantee* that the array has the capacity available to be pushed to.
    // no need to update return pointer in this case
    function unsafe_push(Array self, uint256 elem) internal pure {
        // no need to update pointer
        deref(self).unsafe_push(elem);
    }

    // used when you *guarantee* that the index, i, is within the bounds of length
    // NOTE: marked as memory safe, but potentially not memory safe if the safety contract is broken by the caller
    function unsafe_set(Array self, uint256 i, uint256 value) internal pure {
        deref(self).unsafe_set(i, value);
    }

    function set(Array self, uint256 i, uint256 value) internal pure {
        deref(self).set(i, value);
    }

    // used when you *guarantee* that the index, i, is within the bounds of length
    // NOTE: marked as memory safe, but potentially not memory safe if the safety contract is broken by the caller
    function unsafe_get(Array self, uint256 i) internal pure returns (uint256 s) {
        s = deref(self).unsafe_get(i);
    }

    // a safe `get` that checks capacity
    function get(Array self, uint256 i) internal pure returns (uint256 s) {
        s = deref(self).get(i);
    }
}