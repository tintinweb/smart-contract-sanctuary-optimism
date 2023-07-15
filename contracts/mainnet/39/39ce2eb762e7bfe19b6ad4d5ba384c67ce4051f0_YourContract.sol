/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-15
*/

pragma solidity ^0.7.6;


// Manually define the IUniswapV3Pool interface
interface IUniswapV3Pool {
    function observe(uint32[] calldata secondsAgos) external view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}

contract YourContract {

    function observePool(address poolAddress, uint32[] memory secondsAgos)
        public
        view
        returns (int56[] memory tickCumulatives, uint160[] memory liquidityCumulatives)
    {
        // create an instance of the Uniswap V3 Pool contract
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        // Call observe method on pool
        (tickCumulatives, liquidityCumulatives) = pool.observe(secondsAgos);
    }

    function increaseObservationCardinalityNext(address poolAddress, uint16 observationCardinalityNext) public {
        // create an instance of the Uniswap V3 Pool contract
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        // Call increaseObservationCardinalityNext method on pool
        pool.increaseObservationCardinalityNext(observationCardinalityNext);
    }
}