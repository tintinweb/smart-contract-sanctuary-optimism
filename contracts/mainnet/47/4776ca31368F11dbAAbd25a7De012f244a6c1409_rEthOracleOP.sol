// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";

/*****************************************
 * This gets USD price on Optimism based on the exchange rate
 * found on the RocketOvmPriceOracle @ 0x1a8F81c256aee9C640e14bB0453ce247ea0DFE6F
 * This is a price ported from mainnet and should not be used as a primary oracle on Optimism
 */
interface IRocketOvmPriceOracle {
  function rate() external view returns (uint256);
}

contract rEthOracleOP is IOracleRelay {
  IRocketOvmPriceOracle public immutable _priceFeed;
  IOracleRelay public immutable _ethOracle;

  constructor(IRocketOvmPriceOracle priceFeed, IOracleRelay ethOracle) {
    _priceFeed = priceFeed;
    _ethOracle = ethOracle;
  }

  function currentValue() external view override returns (uint256) {
    uint256 priceInEth = _priceFeed.rate();
    uint256 ethPrice = _ethOracle.currentValue();

    return (ethPrice * priceInEth) / 1e18;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/// @title OracleRelay Interface
/// @notice Interface for interacting with OracleRelay
interface IOracleRelay {
  // returns  price with 18 decimals
  function currentValue() external view returns (uint256);
}