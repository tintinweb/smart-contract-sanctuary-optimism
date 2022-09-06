/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-09-06
*/

// Sources flattened with hardhat v2.9.6 https://hardhat.org

// File contracts/interfaces/ChainlinkPrice.sol

pragma solidity 0.8.11;
interface PriceSource {
    function latestRoundData() external view returns (uint256);
    function latestAnswer() external view returns (int256);
    function decimals() external view returns (uint8);
}


// File contracts/oracles/mooRacleV6.sol

// contracts/mooRacleSingle.sol

pragma solidity 0.8.11;

interface IBeefyV6 {
    function getPricePerFullShare() external view returns (uint256 price);
	function decimals() external view returns (uint8);
	function want() external view returns (address);
}

interface Decimals {
	function decimals() external view returns (uint8);
}

contract mooRacleV6 {

    PriceSource public priceSource;
    Decimals public underlying;
    IBeefyV6 public vault; 

    uint256 public fallbackPrice;
    uint8 public vaultDecimals;
    uint8 public underlyingDecimals;

    event FallbackPrice(
         int256 price
	);

	// price Source gives underlying price per token

    constructor(address _priceSource, address _vault) public {

    	priceSource = PriceSource(_priceSource);
    	vault 	= IBeefyV6(_vault);
    	underlying  = Decimals(vault.want()); // gets the address of DAI and sets it.

    	vaultDecimals = vault.decimals();
    	underlyingDecimals = underlying.decimals();
    }

    // to integrate we just need to inherit that same interface the other vaults use.
	function latestAnswer() public view
		returns 
			( uint256 answer ){

        int256 price = priceSource.latestAnswer();

        uint256 _price;

        if(price>0){
        	_price=uint256(price);
        } else {
	    	_price=fallbackPrice;
        }

		uint256 newPrice 
			= _price * vault.getPricePerFullShare()
				/ (10 ** uint256(vaultDecimals))
				* (10 ** uint256(vaultDecimals - underlyingDecimals));
		
		return newPrice;
	}

	function updateFallbackPrice() public {
        int256 price = priceSource.latestAnswer();

		if (price > 0) {
			fallbackPrice = uint256(price);
	        emit FallbackPrice(price);
        }
 	}
}