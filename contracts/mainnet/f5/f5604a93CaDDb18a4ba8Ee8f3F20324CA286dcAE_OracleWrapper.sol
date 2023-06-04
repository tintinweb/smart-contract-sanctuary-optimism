// SPDX-License-Identifier: MIT

pragma solidity 0.6.6;

interface IAggregator {
  function latestAnswer() external view returns (int256);
  function latestTimestamp() external view returns (uint256);
  function latestRound() external view returns (uint256);
  function getAnswer(uint256 roundId) external view returns (int256);
  function getTimestamp(uint256 roundId) external view returns (uint256);
  function decimals() external view returns (uint8);
  function description() external view returns (string memory);

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);
  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.6;

import "./interfaces/IAggregator.sol";

contract OracleWrapper {
	uint8 private constant DECIMALS = 8; 
	IAggregator public immutable ethOracle;
	IAggregator public immutable underlyingOracle;

	constructor(address _ethOracle, address _underlyingOracle) public {
		ethOracle = IAggregator(_ethOracle);
		underlyingOracle = IAggregator(_underlyingOracle);
	}

	function latestAnswer() external view returns (int256) {
		int256 ethPricInUSD = ethOracle.latestAnswer();
		int256 underlyingPriceInETH = underlyingOracle.latestAnswer();
		return underlyingPriceInETH * ethPricInUSD / 10 ** 18;
	}

	function latestTimestamp() external view returns (uint256) {
		return underlyingOracle.latestTimestamp();
	}

	function decimals() external view returns (uint8) {
		return DECIMALS;
	}
}