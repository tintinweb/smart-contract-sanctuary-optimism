/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-06-06
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
/*                 _______            _                     __   ___  
       /\         |__   __|          | |                   /_ | |__ \ 
      /  \   _ __ ___| |_ __ __ _  __| | ___ _ __  __   __  | |    ) |
     / /\ \ | '__/ __| | '__/ _` |/ _` |/ _ \ '__| \ \ / /  | |   / / 
    / ____ \| | | (__| | | | (_| | (_| |  __/ |     \ V /   | |_ / /_ 
   /_/    \_\_|  \___|_|_|  \__,_|\__,_|\___|_|      \_/    |_(_)____|

  Changes from v 1.1:

  * Pools where we would sell/buy less than 0.1% of the total will be skipped (protects us from wasting
    gas when some pools are tiny)
  * Some variable renaming and minor formatting changes to make the code clearer
  * Set Solidity version to exactly 0.8.19
*/

// Interfaces of external contracts we need to interact with (only the functions we use)
interface IERC20 {
  function allowance(address owner, address spender) external view returns (uint256);
  function balanceOf(address account) external view returns (uint256);
  function symbol() external pure returns (string memory);
  function transferFrom(address sender, address recipient, uint256 amount)
    external returns (bool);
}

interface IFactory {
  function getPair(address tokenA, address tokenB, bool stable) external view returns (address);
}

interface IPair {
  // The amounts of the two tokens (sorted by address) in the pair
  function getReserves() external view
    returns (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast);

  function swap(
    uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

// Conctract to buy and sell Arc from/to multiple pools in the same transaction
contract ArcTrader {
  // The Arc token address
  address immutable public Arc;

  // Address of the Archly pair factory
  address immutable public PairFactory;

  // The number of tokens that Arc may have pools with
  uint256 immutable public Count;

  // The tokens that Arc may have pools with (pools with other tokens will be ignored),
  // set once and for all in the constructor. Tokens with transfer tax are not supported.
  address[] public Tokens;

  // The Arc/Token (or Token/Arc) liquidity pools. This is set in the constructor but may
  // be updated to include newly added pools (with token from the Tokens array) by calling
  // the public function updatePools().
  address[] public Pools;

  // The following functions with names beginning with underscores are helper functions to make
  // the contract smaller and more readable.
  function _isStringEqualToArc(string memory symbol) private pure returns (bool) {
    bytes memory b = bytes(symbol);
    if (b.length != 3) {
      return false;
    }

    return b[0] == 'A' && b[1] == 'r' && b[2] == 'c';
  }

  function _callerAllowance(address token, address spender) private view returns (uint256) {
    return IERC20(token).allowance(msg.sender, spender);
  }

  function _callerBalanceOf(address token) private view returns (uint256) {
    return IERC20(token).balanceOf(msg.sender);
  }

  function _transferFromCaller(address token, address to, uint256 amount) private {
    bool success = IERC20(token).transferFrom(msg.sender, to, amount);

    // Failure here is unexpected because we should have already checked the allowance and balance
    require(success, "ArcTrader: unexpected token transfer failure");
  }

  // Returns a (volatile) pair that token has with Arc, or the zero address if the pool does not exist.
  function _getPairWith(address token) private view returns (address) {
    return IFactory(PairFactory).getPair(Arc, token, false);
  }

  function _getReserves(address lpToken) private view returns (
    uint256 token0Reserve, uint256 token1Reserve) {
      (token0Reserve, token1Reserve, ) = IPair(lpToken).getReserves();
  }

  // Returns the Arc reserves for each potential pool (zero for non-existing pools) and the sum of them
  function _getArcReserves() private view returns (uint256[] memory arcReserves, uint256 total) {
    uint256 count = Count;
    arcReserves = new uint256[](count);
    unchecked {
      for (uint256 i = 0; i < count; ++i) {
        if (Pools[i] != address(0)) {
          (uint256 token0Reserve, uint256 token1Reserve) = _getReserves(Pools[i]);
          uint256 arcReserve = (Arc < Tokens[i]) ? token0Reserve : token1Reserve;
          arcReserves[i] = arcReserve;
          total += arcReserve;
        }
      }
    }
  }

  function _pairSwapToCaller(address pair, uint256 outAmount0, uint256 outAmount1) private {
    IPair(pair).swap(outAmount0, outAmount1, msg.sender, new bytes(0));
  }

  function _getToAmount(uint256 fromAmount, uint256 fromReserve, uint256 toReserve)
    private pure returns (uint256) {

    unchecked {
      // Note that these calculations (originally from UniSwapV2) only work for volatile pairs.
      uint256 fromAmountAfterFee = fromAmount * 9995;  // 0.05% fee
      uint256 numerator = fromAmountAfterFee * toReserve;
      uint256 denominator = (fromReserve * 10000) + fromAmountAfterFee;
      return numerator / denominator;
    }
  }

  function _getFromAmount(uint256 toAmount, uint256 fromReserve, uint256 toReserve)
    private pure returns (uint256) {

    unchecked {
      uint256 numerator = fromReserve * toAmount * 10000;
      uint256 denominator = (toReserve - toAmount) * 9995;  // 0.05% fee
      return (numerator / denominator) + 1;
    }
  }

  // Swaps a specific amount from one token to the other.
  // fromToken and toToken must be the tokens in the pair (not checked here).
  function _swapFromExact(address pair, address fromToken, address toToken, uint256 fromAmount) private {
    (uint256 fromReserve, uint256 toReserve) = _getReserves(pair);

    bool sorted = fromToken < toToken;
    if (!sorted) {
      (fromReserve, toReserve) = (toReserve, fromReserve);
    }

    _transferFromCaller(fromToken, pair, fromAmount);
    uint256 toAmount = _getToAmount(fromAmount, fromReserve, toReserve);

    if (sorted) {
      _pairSwapToCaller(pair, 0, toAmount);
    } else {
      _pairSwapToCaller(pair, toAmount, 0);
    }
  }

  // Swaps from one token to a specific amount of the other.
  // fromToken and toToken must be the tokens in the pair (not checked here).
  function _swapToExact(address pair, address fromToken, address toToken, uint256 toAmount) private {
    (uint256 fromReserve, uint256 toReserve) = _getReserves(pair);

    bool sorted = fromToken < toToken;
    if (!sorted) {
      (fromReserve, toReserve) = (toReserve, fromReserve);
    }

    uint256 fromAmount = _getFromAmount(toAmount, fromReserve, toReserve);

    // Verify the caller's allowance and balance so we can provide descriptive error messages.
    require(_callerAllowance(fromToken, address(this)) >= fromAmount,
      string.concat(string.concat(
        "ArcTrader: insufficient ", IERC20(fromToken).symbol()), " allowance"));

    require(_callerBalanceOf(fromToken) >= fromAmount, string.concat(string.concat(
        "ArcTrader: insufficient ", IERC20(fromToken).symbol()), " balance"));

    _transferFromCaller(fromToken, pair, fromAmount);
    if (sorted) {
      _pairSwapToCaller(pair, 0, toAmount);
    } else {
      _pairSwapToCaller(pair, toAmount, 0);
    }
  }

  // The constructor sets the Arc token address, the Archly pair factory and all the tokens
  // with which Arc will (potentially) have pools (only volatile pools are considered).
  constructor(address arc, address[] memory tokens, address pairFactory) {
    // Gas optimization is less important here but errors could cause headaches (and be
    // costly) so we include some extra checks with descriptive error messages.
    try IERC20(arc).symbol() returns (string memory symbol) {
      require(_isStringEqualToArc(symbol), string.concat(string.concat(
          "ArcTrader: Arc token address is the ", symbol), " token"));
    } catch {
      revert("ArcTrader: invalid Arc token address");
    }

    Arc = arc;

    Count = tokens.length;
    require(Count >= 1, "ArcTrader: Arc must have a pool with at least one token");

    for (uint256 i = 0; i < Count; ++i) {
      require(tokens[i] != arc, "ArcTrader: Arc cannot have a pair with itself");

      try IERC20(tokens[i]).balanceOf(address(this)) { }
      catch {
        revert("ArcTrader: one or more token addresses are not valid tokens");
      }

      for (uint256 j = 0; j < i; ++j) {
        require(tokens[i] != tokens[j], "ArcTrader: duplicate token");
      }

      Tokens.push(tokens[i]);
      Pools.push(address(0));
    }

    // Verify that the factory is correct and that the pair for the first token exists.
    PairFactory = pairFactory;
    try IFactory(pairFactory).getPair(Arc, tokens[0], false) returns (address pairAddress) {
      require(pairAddress != address(0), "ArcTrader: a pool with the first token must exist");
      Pools[0] = pairAddress;
    } catch {
      revert("ArcTrader: invalid pairFactory address");
    }

    // Find and save the pool addresses.
    updatePools();
  }

  // This function is called by the constructor and should also be called externally when
  // needsPoolUpdate() returns true.
  // (This is not done on every call to buy() and sell() because that would waste gas.)
  function updatePools() public {
    uint256 count = Count;
    unchecked {
      // The first pool has been set in the constructor so we start from index 1
      for (uint256 i = 1; i < count; ++i) {
        if (Pools[i] == address(0)) {
          Pools[i] = _getPairWith(Tokens[i]);
        }
      }
    }
  }

  // View function that will return true if we should call updatePools() because one or more new pools
  // (with tokens set in the constructor) have been created.
  function needsPoolUpdate() external view returns (bool) {
    uint256 count = Count;
    unchecked {
      for (uint256 i = 1; i < count; ++i) {
        if (Pools[i] == address(0)) {
          if (_getPairWith(Tokens[i]) != address(0)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  // View function to get all the pool reserves.
  function getAllReserves() external view returns (
    uint256[] memory tokenReserves, uint256[] memory arcReserves) {

    uint256 count = Count;
    tokenReserves = new uint256[](count);
    arcReserves = new uint256[](count);

    unchecked {
      for (uint256 i = 0; i < count; ++i) {
        if (Pools[i] != address(0)) {
          (uint256 arcReserve, uint256 tokenReserve) = _getReserves(Pools[i]);
          if (Arc > Tokens[i]) {
            (arcReserve, tokenReserve) = (tokenReserve, arcReserve);
          }

          tokenReserves[i] = tokenReserve;
          arcReserves[i] = arcReserve;
        }
      }
    }
  }

  // Sells Arc for the other tokens in the right proportions.
  function sell(uint256 arcSellAmount) public {
    require(arcSellAmount >= 1e15, "ArcTrader: cannot sell less than 1 milliArc");
    require(_callerAllowance(Arc, address(this)) >= arcSellAmount,
      "ArcTrader: insufficient Arc allowance");

    // By checking that the caller balance is sufficient we not only can provide a descriptive
    // error message but also safely use unchecked math on arcSellAmount.
    require(_callerBalanceOf(Arc) >= arcSellAmount, "ArcTrader: insufficient Arc balance");

    // Get all the pool Arc reserves and the sum of them.
    (uint256[] memory arcReserves, uint256 totalArcReserve) = _getArcReserves();

    // Compute how many Arc to sell into each pool and perform the swaps.
    uint256 arcSold = 0;
    uint256 count = Count;

    unchecked {
      // Initially skip the first (always existing) pool; it will be used last.
      for (uint256 i = 1; i < count; ++i) {
        if (arcReserves[i] > 0) {
          uint256 poolSellAmount = arcSellAmount * arcReserves[i] / totalArcReserve;
          if (poolSellAmount >= arcSellAmount / 1000) {
            // Use this pool if the swap amount is at least 0.1% of the total
            _swapFromExact(Pools[i], Arc, Tokens[i], poolSellAmount);
            arcSold += poolSellAmount;
          }
        }
      }

      // The amount to sell into the first pool is simply what's left (this makes sure the total
      // number of Arc sold is exactly right).
      if (arcSellAmount > arcSold) {
        _swapFromExact(Pools[0], Arc, Tokens[0], arcSellAmount - arcSold);
      }
    }
  }

  // Sells ALL the caller's Arc tokens (for convenience and gas savings on chains with expensive input).
  function sellAll() external {
    sell(_callerBalanceOf(Arc));
  }

  // Buys a specific amount of Arc (up to half of the existing reserves) using the right amount of all
  // the other tokens.
  // Note that spend approvals must have been given to all tokens (that have pools) and the
  // caller must have enough balance of them.
  function buy(uint256 arcBuyAmount) external {
    require(arcBuyAmount >= 1e15, "ArcTrader: cannot buy less than 1 milliArc");

    // Get all the pool reserves and the total amount of Arc reserves.
    (uint256[] memory arcReserves, uint256 totalArcReserve) = _getArcReserves();

    unchecked {
      // By limiting the max amount to half of the total reserves (enough to quadruple the price)
      // we guard against mistakenly buying too much and can use unchecked math.
      require(arcBuyAmount <= totalArcReserve / 2,
        "ArcTrader: cannot buy more than half the pool reserves");

      // Compute how many Arc we want to get from each pool and perform the swaps.
      uint256 arcBought = 0;
      uint256 count = Count;

      // Initially skip the first (always existing) pool; it will be used last.
      for (uint256 i = 1; i < count; ++i) {
        if (arcReserves[i] > 0) {
          uint256 poolBuyAmount = arcBuyAmount * arcReserves[i] / totalArcReserve;
          if (poolBuyAmount >= arcBuyAmount / 1000) {
            // Use this pool if the swap amount is at least 0.1% of the total
            _swapToExact(Pools[i], Tokens[i], Arc, poolBuyAmount);
            arcBought += poolBuyAmount;
          }
        }
      }

      // The amount to buy from the first pool is simply what's left (this makes sure the total
      // number of Arc bought is exactly right).
      if (arcBuyAmount > arcBought) {
        _swapToExact(Pools[0], Tokens[0], Arc, arcBuyAmount - arcBought);
      }
    }
  }
}