/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-15
*/

pragma solidity ^0.7.6;

interface IUniswapV3Pool {
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}

contract MyContract {
    IUniswapV3Pool private uniswapV3Pool;

    constructor(address _uniswapV3PoolAddress) {
        uniswapV3Pool = IUniswapV3Pool(_uniswapV3PoolAddress);
    }

    function increaseObservation(uint16 _observationCardinalityNext) external {
        uniswapV3Pool.increaseObservationCardinalityNext(_observationCardinalityNext);
    }
}