/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-12-07
*/

// Sources flattened with hardhat v2.12.2 https://hardhat.org

// File contracts/interfaces/external/ChainlinkPrice.sol

pragma solidity 0.8.11;
interface PriceSource {
    function latestRoundData() external view returns (uint256);
    function latestAnswer() external view returns (int256);
    function decimals() external view returns (uint8);
}


// File contracts/oracles/yvOraclePerfFee.sol

// contracts/shareOracle.sol

pragma solidity 0.8.11;

interface IYearnVault {
	function balance() external view returns (uint256);
    function pricePerShare() external view returns (uint256 price);
	function decimals() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface ERC20 {
    function balanceOf(address account) external view returns (uint256);
	function decimals() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract yvPerformanceFeeOracle {

	// this should just be vieweing a chainlink oracle's price
	// then it would check the balances of that contract in the token that its checking.
	// it should return the price per token based on the camToken's balance

    PriceSource public priceSource;
    ERC20 public underlying;

    address public yVault; 

    uint256 public fallbackPrice;

    uint256 public vaultDecimals;

    event FallbackPrice(
         int256 price
	);

	// price Source gives underlying price per token

    constructor(address _priceSource, address _yVault, address underlying_) public {
    	priceSource = PriceSource(_priceSource);
    	yVault 		= _yVault;
    	vaultDecimals = IYearnVault(yVault).decimals();
    	underlying = ERC20(underlying_);
    }

    // to integrate we just need to inherit that same interface the other page uses.

	function latestAnswer() public view
		returns 
			(uint256 answer){
        (
         int256 price
		 ) = priceSource.latestAnswer();

        uint256 _price;

        if(price>0){
        	_price=uint256(price);
        } else {
	    	_price=fallbackPrice;
        }

		IYearnVault vault = IYearnVault(yVault);

		uint256 price_ = (_price * vault.pricePerShare()) / (10**vaultDecimals);
		uint256 newPrice = ( IYearnVault(yVault).balanceOf(address(underlying))* price_ ) / underlying.totalSupply();

		return (newPrice);
	}

	function updateFallbackPrice() public {
        (
         int256 price
		 ) = priceSource.latestAnswer();

		if (price > 0) {
			fallbackPrice = uint256(price);
	        emit FallbackPrice(price);
        }
 	}
}