// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPriceFeed {
    function getToken() external view returns (address);

    function getPrice() external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../interfaces/IPriceFeed.sol";

contract ChainlinkPriceFeedAggregator is IPriceFeed {
    address public immutable aggregator;
    address public immutable token;

    /**
     * @dev Sets the values for {aggregator}, and {token}.
     *
     * We retrieve price from ChainLink aggregator.
     */
    constructor(address _aggregator, address _token) {
        aggregator = _aggregator;
        token = _token;
    }

    /**
     * @notice Return the token. It should be the collateral token address from IB agreement.
     * @return the token address
     */
    function getToken() external view override returns (address) {
        return token;
    }

    /**
     * @notice Return the token latest price in USD.
     * @return the price, scaled by 1e18
     */
    function getPrice() external view override returns (uint256) {
        (, int256 price, , , ) = AggregatorV3Interface(aggregator)
            .latestRoundData();
        require(price > 0, "invalid price");

        // Extend the decimals to 1e18.
        return
            uint256(price) *
            10**(18 - uint256(AggregatorV3Interface(aggregator).decimals()));
    }
}