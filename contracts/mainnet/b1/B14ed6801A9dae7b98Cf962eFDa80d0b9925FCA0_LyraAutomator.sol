// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../interfaces/AutomationCompatibleInterface.sol";
import "../ConfirmedOwner.sol";
import "./OptionMarketInterface.sol";

contract LyraAutomator is AutomationCompatibleInterface, ConfirmedOwner {
  OptionMarketInterface public s_optionMarket;

  event BoardExpired(uint256 indexed boardId, uint256 blocknumber);
  event SettlementFailed(uint256 indexed boardId, bytes lowLevelData);

  constructor(OptionMarketInterface optionMarket) ConfirmedOwner(msg.sender) {
    s_optionMarket = optionMarket;
  }

  function setOptionMarket(OptionMarketInterface optionMarket) external onlyOwner {
    s_optionMarket = optionMarket;
  }

  function checkUpkeep(bytes calldata checkData)
    external
    override
    returns (bool upkeepNeeded, bytes memory performData)
  {
    uint256[] memory liveBoards = s_optionMarket.getLiveBoards();
    uint256 index = 0;

    for (uint256 i = 0; i < liveBoards.length; i++) {
      uint256 boardId = liveBoards[i];
      OptionBoard memory board = s_optionMarket.getOptionBoard(boardId);
      if (board.expiry < block.timestamp) {
        liveBoards[index++] = boardId;
      }
    }

    if (index > 0) {
      return (true, abi.encode(index, liveBoards));
    }

    return (false, "");
  }

  function performUpkeep(bytes calldata performData) external override {
    (uint256 index, uint256[] memory boardIds) = abi.decode(performData, (uint256, uint256[]));
    if (index == 0) {
      return;
    }

    for (uint256 i = 0; i < index; i++) {
      uint256 boardId = boardIds[i];

      try s_optionMarket.settleExpiredBoard(boardId) {
        emit BoardExpired(boardId, block.number);
      } catch (bytes memory lowLevelData) {
        emit SettlementFailed(boardId, lowLevelData);
      }
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AutomationCompatibleInterface {
  /**
   * @notice method that is simulated by the keepers to see if any work actually
   * needs to be performed. This method does does not actually need to be
   * executable, and since it is only ever simulated it can consume lots of gas.
   * @dev To ensure that it is never called, you may want to add the
   * cannotExecute modifier from KeeperBase to your implementation of this
   * method.
   * @param checkData specified in the upkeep registration so it is always the
   * same for a registered upkeep. This can easily be broken down into specific
   * arguments using `abi.decode`, so multiple upkeeps can be registered on the
   * same contract and easily differentiated by the contract.
   * @return upkeepNeeded boolean to indicate whether the keeper should call
   * performUpkeep or not.
   * @return performData bytes that the keeper should call performUpkeep with, if
   * upkeep is needed. If you would like to encode data to decode later, try
   * `abi.encode`.
   */
  function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);

  /**
   * @notice method that is actually executed by the keepers, via the registry.
   * The data returned by the checkUpkeep simulation will be passed into
   * this method to actually be executed.
   * @dev The input to this method should not be trusted, and the caller of the
   * method should not even be restricted to any single registry. Anyone should
   * be able call it, and the input should be validated, there is no guarantee
   * that the data passed in is the performData returned from checkUpkeep. This
   * could happen due to malicious keepers, racing keepers, or simply a state
   * change while the performUpkeep transaction is waiting for confirmation.
   * Always validate the data passed in.
   * @param performData is the data which was passed back from the checkData
   * simulation. If it is encoded, it can easily be decoded into other types by
   * calling `abi.decode`. This data should not be trusted, and should be
   * validated against the contract's current state.
   */
  function performUpkeep(bytes calldata performData) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ConfirmedOwnerWithProposal.sol";

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwner is ConfirmedOwnerWithProposal {
  constructor(address newOwner) ConfirmedOwnerWithProposal(newOwner, address(0)) {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

struct OptionBoard {
  // board identifier
  uint256 id;
  // expiry of all strikes belonging to board
  uint256 expiry;
  // volatility component specific to board (boardIv * skew = vol of strike)
  uint256 iv;
  // admin settable flag blocking all trading on this board
  bool frozen;
  // list of all strikes belonging to this board
  uint256[] strikeIds;
}

interface OptionMarketInterface {
  function getLiveBoards() external view returns (uint256[] memory _liveBoards);

  function getOptionBoard(uint256 boardId) external view returns (OptionBoard memory);

  function settleExpiredBoard(uint256 boardId) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/OwnableInterface.sol";

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwnerWithProposal is OwnableInterface {
  address private s_owner;
  address private s_pendingOwner;

  event OwnershipTransferRequested(address indexed from, address indexed to);
  event OwnershipTransferred(address indexed from, address indexed to);

  constructor(address newOwner, address pendingOwner) {
    require(newOwner != address(0), "Cannot set owner to zero");

    s_owner = newOwner;
    if (pendingOwner != address(0)) {
      _transferOwnership(pendingOwner);
    }
  }

  /**
   * @notice Allows an owner to begin transferring ownership to a new address,
   * pending.
   */
  function transferOwnership(address to) public override onlyOwner {
    _transferOwnership(to);
  }

  /**
   * @notice Allows an ownership transfer to be completed by the recipient.
   */
  function acceptOwnership() external override {
    require(msg.sender == s_pendingOwner, "Must be proposed owner");

    address oldOwner = s_owner;
    s_owner = msg.sender;
    s_pendingOwner = address(0);

    emit OwnershipTransferred(oldOwner, msg.sender);
  }

  /**
   * @notice Get the current owner
   */
  function owner() public view override returns (address) {
    return s_owner;
  }

  /**
   * @notice validate, transfer ownership, and emit relevant events
   */
  function _transferOwnership(address to) private {
    require(to != msg.sender, "Cannot transfer to self");

    s_pendingOwner = to;

    emit OwnershipTransferRequested(s_owner, to);
  }

  /**
   * @notice validate access
   */
  function _validateOwnership() internal view {
    require(msg.sender == s_owner, "Only callable by owner");
  }

  /**
   * @notice Reverts if called by anyone other than the contract owner.
   */
  modifier onlyOwner() {
    _validateOwnership();
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface OwnableInterface {
  function owner() external returns (address);

  function transferOwnership(address recipient) external;

  function acceptOwnership() external;
}