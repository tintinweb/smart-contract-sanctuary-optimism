pragma solidity 0.8.15;

import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @notice An aggregator that does one thing: return a fixed price, in fixed decimals, as set
 * in the constructor.
 */
contract FixedPriceAggregator is AggregatorV3Interface {
  /// @notice The number of decimals the fixed price is represented in.
  uint8 public immutable decimals;

  /// @notice The fixed price, in the decimals indicated, returned by this oracle.
  int256 private immutable price;

  /// @param _decimals The number of decimals the fixed price is represented in.
  /// @param _price The fixed price, in the decimals indicated, to be returned by this oracle.
  constructor(uint8 _decimals, int256 _price) {
    price = _price;
    decimals = _decimals;
  }


  /// @notice A description indicating this is a fixed price oracle.
  function description() external pure returns (string memory) {
    return "Fixed price oracle";
  }

   /// @notice A version number of 0.
  function version() external pure returns (uint256) {
    return 0;
  }

  /// @notice Returns data for the specified round.
  /// @param _roundId This parameter is ignored.
  /// @return roundId 0
  /// @return answer The fixed price returned by this oracle, represented in appropriate decimals.
  /// @return startedAt 0
  /// @return updatedAt Since price is fixed, we always return the current block timestamp.
  /// @return answeredInRound 0
  function getRoundData(uint80 _roundId)
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    _roundId; // Silence unused variable compiler warning.
    return (uint80(0), price, uint256(0), block.timestamp, uint80(0));
  }

  /// @notice Returns data for the latest round.
  /// @return roundId 0
  /// @return answer The fixed price returned by this oracle, represented in appropriate decimals.
  /// @return startedAt 0
  /// @return updatedAt Since price is fixed, we always return the current block timestamp.
  /// @return answeredInRound 0
  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    return (uint80(0), price, uint256(0), block.timestamp, uint80(0));
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}