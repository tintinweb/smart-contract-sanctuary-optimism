/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-08-23
*/

// SPDX-License-Identifier: LGPL-3.0-or-later
pragma abicoder v2;
pragma solidity ^0.8.9;

contract BulkReserves {
  struct Pool {
    address pool_address;
    uint112 reserve0;
    uint112 reserve1;
  }
  
  struct Token01 {
    address pool_address;
    address token0;
    address token1;
  }

  function getReservesBulk(address[] calldata pools) external view returns (Pool[] memory reserves) {
    reserves = new Pool[](pools.length);
    
    for(uint i = 0; i < pools.length; i++) {
      if(isAContract(pools[i])) { 
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(pools[i]); 
        reserves[i] = Pool(pools[i], _reserve0, _reserve1); 
      } else {
        reserves[i] = Pool(pools[i], 0, 0);   
      }
    }
    return reserves;
  }

  function getToken01Bulk(address[] calldata pools) external view returns (Token01[] memory tokens) {
    tokens = new Token01[](pools.length);
    
    for(uint i = 0; i < pools.length; i++) {
      if(isAContract(pools[i])) { 
        address _token0 = getToken0(pools[i]); 
        address _token1 = getToken1(pools[i]);
        tokens[i] = Token01(pools[i], _token0, _token1); 
      } else {
        tokens[i] = Token01(pools[i], address(0), address(0));   
      }
    }
    return tokens;
  }
  
  function getReserves(address pair) internal view returns (uint112, uint112, uint32) {
    try IUniswapV2Pair(pair).getReserves() returns (uint112 _reserve0, uint112 _reserve1, uint32 blockTimestampLast) {
        return (_reserve0, _reserve1, blockTimestampLast);
    } catch Error(string memory /*reason*/) {
        return (0, 0, 0);
    } catch (bytes memory /*lowLevelData*/) {
        return (0, 0, 0);
    }
  }
    
  function getToken0(address pair) internal view returns (address) {
    try IUniswapV2Pair(pair).token0() returns (address token) {
        return (token);
    } catch Error(string memory /*reason*/) {
        return (address(0));
    } catch (bytes memory /*lowLevelData*/) {
        return (address(0));
    }
  }

  function getToken1(address pair) internal view returns (address) {
    try IUniswapV2Pair(pair).token1() returns (address token) {
        return (token);
    } catch Error(string memory /*reason*/) {
        return (address(0));
    } catch (bytes memory /*lowLevelData*/) {
        return (address(0));
    }
  }

  // check if contract (token, exchange) is actually a smart contract and not a 'regular' address
  function isAContract(address contractAddr) internal view returns (bool) {
    uint256 codeSize;
    assembly { codeSize := extcodesize(contractAddr) } // contract code size
    return codeSize > 0; 
    // Might not be 100% foolproof, but reliable enough for an early return in 'view' functions 
  }
}

interface IUniswapV2Pair {
  function token0() external view returns (address);
  function token1() external view returns (address);
  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}