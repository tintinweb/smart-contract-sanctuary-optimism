// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMathUpgradeable {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * @title Solidity Bytes Arrays Utils
 * @author Gonçalo Sá <[email protected]>
 *
 * @dev Bytes tightly packed arrays utility library for ethereum contracts written in Solidity.
 *      The library lets you concatenate, slice and type cast bytes arrays both in memory and storage.
 */
pragma solidity >=0.5.0 <0.8.0;

library BytesLib {
    function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    ) internal pure returns (bytes memory) {
        require(_length + 31 >= _length, 'slice_overflow');
        require(_start + _length >= _start, 'slice_overflow');
        require(_bytes.length >= _start + _length, 'slice_outOfBounds');

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
                case 0 {
                    // Get a location of some free memory and store it in tempBytes as
                    // Solidity does for memory variables.
                    tempBytes := mload(0x40)

                    // The first word of the slice result is potentially a partial
                    // word read from the original array. To read it, we calculate
                    // the length of that partial word and start copying that many
                    // bytes into the array. The first word we copy will start with
                    // data we don't care about, but the last `lengthmod` bytes will
                    // land at the beginning of the contents of the new array. When
                    // we're done copying, we overwrite the full first word with
                    // the actual length of the slice.
                    let lengthmod := and(_length, 31)

                    // The multiplication in the next line is necessary
                    // because when slicing multiples of 32 bytes (lengthmod == 0)
                    // the following copy loop was copying the origin's length
                    // and then ending prematurely not copying everything it should.
                    let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                    let end := add(mc, _length)

                    for {
                        // The multiplication in the next line has the same exact purpose
                        // as the one above.
                        let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                    } lt(mc, end) {
                        mc := add(mc, 0x20)
                        cc := add(cc, 0x20)
                    } {
                        mstore(mc, mload(cc))
                    }

                    mstore(tempBytes, _length)

                    //update free-memory pointer
                    //allocating the array padded to 32 bytes like the compiler does now
                    mstore(0x40, and(add(mc, 31), not(31)))
                }
                //if we want a zero-length slice let's just return a zero-length array
                default {
                    tempBytes := mload(0x40)
                    //zero out the 32 bytes slice we are about to return
                    //we need to do it because Solidity does not garbage collect
                    mstore(tempBytes, 0)

                    mstore(0x40, add(tempBytes, 0x20))
                }
        }

        return tempBytes;
    }

    function toAddress(bytes memory _bytes, uint256 _start) internal pure returns (address) {
        require(_start + 20 >= _start, 'toAddress_overflow');
        require(_bytes.length >= _start + 20, 'toAddress_outOfBounds');
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }

    function toUint24(bytes memory _bytes, uint256 _start) internal pure returns (uint24) {
        require(_start + 3 >= _start, 'toUint24_overflow');
        require(_bytes.length >= _start + 3, 'toUint24_outOfBounds');
        uint24 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x3), _start))
        }

        return tempUint;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../../../utils/TxDataUtils.sol";
import "../../../interfaces/guards/IGuard.sol";
import "../../../interfaces/velodrome/IVelodromeV2Router.sol";
import "../../../interfaces/IPoolManagerLogic.sol";
import "../../../interfaces/IHasSupportedAsset.sol";
import "../../../interfaces/ITransactionTypes.sol";

contract VelodromeV2RouterGuard is TxDataUtils, IGuard, ITransactionTypes {
  event AddLiquidity(address fundAddress, address pair, bytes params, uint256 time);

  event RemoveLiquidity(address fundAddress, address pair, bytes params, uint256 time);

  /// @notice Transaction guard for Velodrome V2 Router
  /// @dev It supports addLiquidity and removeLiquidity functionalities
  /// @param _poolManagerLogic the pool manager logic
  /// @param _to the router address
  /// @param _data the transaction data
  /// @return txType the transaction type of a given transaction data
  /// @return isPublic if the transaction is public or private
  function txGuard(
    address _poolManagerLogic,
    address _to,
    bytes calldata _data
  ) external override returns (uint16 txType, bool) {
    IPoolManagerLogic poolManagerLogic = IPoolManagerLogic(_poolManagerLogic);
    IHasSupportedAsset poolManagerLogicAssets = IHasSupportedAsset(_poolManagerLogic);

    bytes4 method = getMethod(_data);
    bytes memory params = getParams(_data);
    address defaultFactory = IVelodromeV2Router(_to).defaultFactory();

    if (method == IVelodromeV2Router.addLiquidity.selector) {
      (address tokenA, address tokenB, bool stable, , , , , address recipient, ) = abi.decode(
        params,
        (address, address, bool, uint256, uint256, uint256, uint256, address, uint256)
      );

      require(poolManagerLogicAssets.isSupportedAsset(tokenA), "unsupported asset: tokenA");
      require(poolManagerLogicAssets.isSupportedAsset(tokenB), "unsupported asset: tokenB");

      address pair = IVelodromeV2Router(_to).poolFor(tokenA, tokenB, stable, defaultFactory);

      require(poolManagerLogicAssets.isSupportedAsset(pair), "unsupported lp asset");
      require(poolManagerLogic.poolLogic() == recipient, "recipient is not pool");

      emit AddLiquidity(poolManagerLogic.poolLogic(), pair, params, block.timestamp);

      txType = uint16(TransactionType.AddLiquidity);
    } else if (method == IVelodromeV2Router.removeLiquidity.selector) {
      (address tokenA, address tokenB, bool stable, , , , address recipient, ) = abi.decode(
        params,
        (address, address, bool, uint256, uint256, uint256, address, uint256)
      );

      require(poolManagerLogicAssets.isSupportedAsset(tokenA), "unsupported asset: tokenA");
      require(poolManagerLogicAssets.isSupportedAsset(tokenB), "unsupported asset: tokenB");

      address pair = IVelodromeV2Router(_to).poolFor(tokenA, tokenB, stable, defaultFactory);

      require(poolManagerLogicAssets.isSupportedAsset(pair), "unsupported lp asset");
      require(poolManagerLogic.poolLogic() == recipient, "recipient is not pool");

      emit RemoveLiquidity(poolManagerLogic.poolLogic(), pair, params, block.timestamp);

      txType = uint16(TransactionType.RemoveLiquidity);
    }

    return (txType, false);
  }
}

//
//        __  __    __  ________  _______    ______   ________
//       /  |/  |  /  |/        |/       \  /      \ /        |
//   ____$$ |$$ |  $$ |$$$$$$$$/ $$$$$$$  |/$$$$$$  |$$$$$$$$/
//  /    $$ |$$ |__$$ |$$ |__    $$ |  $$ |$$ | _$$/ $$ |__
// /$$$$$$$ |$$    $$ |$$    |   $$ |  $$ |$$ |/    |$$    |
// $$ |  $$ |$$$$$$$$ |$$$$$/    $$ |  $$ |$$ |$$$$ |$$$$$/
// $$ \__$$ |$$ |  $$ |$$ |_____ $$ |__$$ |$$ \__$$ |$$ |_____
// $$    $$ |$$ |  $$ |$$       |$$    $$/ $$    $$/ $$       |
//  $$$$$$$/ $$/   $$/ $$$$$$$$/ $$$$$$$/   $$$$$$/  $$$$$$$$/
//
// dHEDGE DAO - https://dhedge.org
//
// Copyright (c) 2021 dHEDGE DAO
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//
// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

interface IGuard {
  event ExchangeFrom(address fundAddress, address sourceAsset, uint256 sourceAmount, address dstAsset, uint256 time);
  event ExchangeTo(address fundAddress, address sourceAsset, address dstAsset, uint256 dstAmount, uint256 time);

  function txGuard(
    address poolManagerLogic,
    address to,
    bytes calldata data
  ) external returns (uint16 txType, bool isPublic); // TODO: eventually update `txType` to be of enum type as per ITransactionTypes
}

//
//        __  __    __  ________  _______    ______   ________
//       /  |/  |  /  |/        |/       \  /      \ /        |
//   ____$$ |$$ |  $$ |$$$$$$$$/ $$$$$$$  |/$$$$$$  |$$$$$$$$/
//  /    $$ |$$ |__$$ |$$ |__    $$ |  $$ |$$ | _$$/ $$ |__
// /$$$$$$$ |$$    $$ |$$    |   $$ |  $$ |$$ |/    |$$    |
// $$ |  $$ |$$$$$$$$ |$$$$$/    $$ |  $$ |$$ |$$$$ |$$$$$/
// $$ \__$$ |$$ |  $$ |$$ |_____ $$ |__$$ |$$ \__$$ |$$ |_____
// $$    $$ |$$ |  $$ |$$       |$$    $$/ $$    $$/ $$       |
//  $$$$$$$/ $$/   $$/ $$$$$$$$/ $$$$$$$/   $$$$$$/  $$$$$$$$/
//
// dHEDGE DAO - https://dhedge.org
//
// Copyright (c) 2021 dHEDGE DAO
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//
// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

pragma experimental ABIEncoderV2;

interface IHasSupportedAsset {
  struct Asset {
    address asset;
    bool isDeposit;
  }

  function getSupportedAssets() external view returns (Asset[] memory);

  function isSupportedAsset(address asset) external view returns (bool);
}

//
//        __  __    __  ________  _______    ______   ________
//       /  |/  |  /  |/        |/       \  /      \ /        |
//   ____$$ |$$ |  $$ |$$$$$$$$/ $$$$$$$  |/$$$$$$  |$$$$$$$$/
//  /    $$ |$$ |__$$ |$$ |__    $$ |  $$ |$$ | _$$/ $$ |__
// /$$$$$$$ |$$    $$ |$$    |   $$ |  $$ |$$ |/    |$$    |
// $$ |  $$ |$$$$$$$$ |$$$$$/    $$ |  $$ |$$ |$$$$ |$$$$$/
// $$ \__$$ |$$ |  $$ |$$ |_____ $$ |__$$ |$$ \__$$ |$$ |_____
// $$    $$ |$$ |  $$ |$$       |$$    $$/ $$    $$/ $$       |
//  $$$$$$$/ $$/   $$/ $$$$$$$$/ $$$$$$$/   $$$$$$/  $$$$$$$$/
//
// dHEDGE DAO - https://dhedge.org
//
// Copyright (c) 2021 dHEDGE DAO
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//
// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

interface IPoolManagerLogic {
  function poolLogic() external view returns (address);

  function isDepositAsset(address asset) external view returns (bool);

  function validateAsset(address asset) external view returns (bool);

  function assetValue(address asset) external view returns (uint256);

  function assetValue(address asset, uint256 amount) external view returns (uint256);

  function assetBalance(address asset) external view returns (uint256 balance);

  function factory() external view returns (address);

  function setPoolLogic(address fundAddress) external returns (bool);

  function totalFundValue() external view returns (uint256);

  function isMemberAllowed(address member) external view returns (bool);

  function getFee()
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    );

  function minDepositUSD() external view returns (uint256);
}

//        __  __    __  ________  _______    ______   ________
//       /  |/  |  /  |/        |/       \  /      \ /        |
//   ____$$ |$$ |  $$ |$$$$$$$$/ $$$$$$$  |/$$$$$$  |$$$$$$$$/
//  /    $$ |$$ |__$$ |$$ |__    $$ |  $$ |$$ | _$$/ $$ |__
// /$$$$$$$ |$$    $$ |$$    |   $$ |  $$ |$$ |/    |$$    |
// $$ |  $$ |$$$$$$$$ |$$$$$/    $$ |  $$ |$$ |$$$$ |$$$$$/
// $$ \__$$ |$$ |  $$ |$$ |_____ $$ |__$$ |$$ \__$$ |$$ |_____
// $$    $$ |$$ |  $$ |$$       |$$    $$/ $$    $$/ $$       |
//  $$$$$$$/ $$/   $$/ $$$$$$$$/ $$$$$$$/   $$$$$$/  $$$$$$$$/
//
// dHEDGE DAO - https://dhedge.org
//
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Transaction type events used in pool execTransaction() contract guards
/// @dev Gradually migrate to these events as we update / add new contract guards
interface ITransactionTypes {
  // Transaction Types in execTransaction()
  // 1. Approve: Approving a token for spending by different address/contract
  // 2. Exchange: Exchange/trade of tokens eg. Uniswap, Synthetix
  // 3. AddLiquidity: Add liquidity of Uniswap, Sushiswap
  // 4. RemoveLiquidity: Remove liquidity of Uniswap, Sushiswap
  // 5. Stake: Stake tokens into a third party contract (eg. Sushi yield farming)
  event Stake(address poolLogic, address stakingToken, address to, uint256 amount, uint256 time);
  // 6. Unstake: Unstake tokens from a third party contract (eg. Sushi yield farming)
  event Unstake(address poolLogic, address stakingToken, address to, uint256 amount, uint256 time);
  // 7. Claim: Claim rewards tokens from a third party contract (eg. SUSHI & MATIC rewards)
  // 8. UnstakeAndClaim: Unstake tokens and claim rewards from a third party contract
  // 9. Deposit: Aave deposit tokens -> get Aave Interest Bearing Token
  // 10. Withdraw: Withdraw tokens from Aave Interest Bearing Token
  // 11. SetUserUseReserveAsCollateral: Aave set reserve asset to be used as collateral
  // 12. Borrow: Aave borrow tokens
  // 13. Repay: Aave repay tokens
  // 14. SwapBorrowRateMode: Aave change borrow rate mode (stable/variable)
  // 15. RebalanceStableBorrowRate: Aave rebalance stable borrow rate
  // 16. JoinPool: Balancer join pool
  // 17. ExitPool: Balancer exit pool
  // 18. Deposit: EasySwapper Deposit
  // 19. Withdraw: EasySwapper Withdraw
  // 20. Mint: Uniswap V3 Mint position
  // 21. IncreaseLiquidity: Uniswap V3 increase liquidity position
  // 22. DecreaseLiquidity: Uniswap V3 decrease liquidity position
  // 23. Burn: Uniswap V3 Burn position
  // 24. Collect: Uniswap V3 collect fees
  // 25. Multicall: Uniswap V3 Multicall
  // 26. Lyra: open position
  // 27. Lyra: close position
  // 28. Lyra: force close position
  // 29. Futures: Market
  // 30. AddLiquidity: Single asset add liquidity (eg. Stargate)
  event AddLiquiditySingle(address fundAddress, address asset, address liquidityPool, uint256 amount, uint256 time);
  // 31. RemoveLiquidity: Single asset remove liquidity (eg. Stargate)
  event RemoveLiquiditySingle(address fundAddress, address asset, address liquidityPool, uint256 amount, uint256 time);
  // 36. Redeem Deprecated Synths into sUSD
  event SynthRedeem(address poolAddress, IERC20[] synthProxies);

  // Enum representing Transaction Types
  enum TransactionType {
    NotUsed, // 0
    Approve, // 1
    Exchange, // 2
    AddLiquidity, // 3
    RemoveLiquidity, // 4
    Stake, // 5
    Unstake, // 6
    Claim, // 7
    UnstakeAndClaim, // 8
    AaveDeposit, // 9
    AaveWithdraw, // 10
    AaveSetUserUseReserveAsCollateral, // 11
    AaveBorrow, // 12
    AaveRepay, // 13
    AaveSwapBorrowRateMode, // 14
    AaveRebalanceStableBorrowRate, // 15
    BalancerJoinPool, // 16
    BalancerExitPool, // 17
    EasySwapperDeposit, // 18
    EasySwapperWithdraw, // 19
    UniswapV3Mint, // 20
    UniswapV3IncreaseLiquidity, // 21
    UniswapV3DecreaseLiquidity, // 22
    UniswapV3Burn, // 23
    UniswapV3Collect, // 24
    UniswapV3Multicall, // 25
    LyraOpenPosition, // 26
    LyraClosePosition, // 27
    LyraForceClosePosition, // 28
    KwentaFuturesMarket, // 29
    AddLiquiditySingle, // 30
    RemoveLiquiditySingle, // 31
    MaiTx, // 32
    LyraAddCollateral, // 33
    LyraLiquidatePosition, // 34
    KwentaPerpsV2Market, // 35
    RedeemSynth // 36
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

interface IVelodromeV2Router {
  struct Route {
    address from;
    address to;
    bool stable;
    address factory;
  }

  /// @dev Struct containing information necessary to zap in and out of pools
  /// @param tokenA           .
  /// @param tokenB           .
  /// @param stable           Stable or volatile pool
  /// @param factory          factory of pool
  /// @param amountOutMinA    Minimum amount expected from swap leg of zap via routesA
  /// @param amountOutMinB    Minimum amount expected from swap leg of zap via routesB
  /// @param amountAMin       Minimum amount of tokenA expected from liquidity leg of zap
  /// @param amountBMin       Minimum amount of tokenB expected from liquidity leg of zap
  struct Zap {
    address tokenA;
    address tokenB;
    bool stable;
    address factory;
    uint256 amountOutMinA;
    uint256 amountOutMinB;
    uint256 amountAMin;
    uint256 amountBMin;
  }

  function defaultFactory() external view returns (address);

  /// @notice Sort two tokens by which address value is less than the other
  /// @param tokenA   Address of token to sort
  /// @param tokenB   Address of token to sort
  /// @return token0  Lower address value between tokenA and tokenB
  /// @return token1  Higher address value between tokenA and tokenB
  function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);

  /// @notice Calculate the address of a pool by its' factory.
  ///         Used by all Router functions containing a `Route[]` or `_factory` argument.
  ///         Reverts if _factory is not approved by the FactoryRegistry
  /// @dev Returns a randomly generated address for a nonexistent pool
  /// @param tokenA   Address of token to query
  /// @param tokenB   Address of token to query
  /// @param stable   True if pool is stable, false if volatile
  /// @param _factory Address of factory which created the pool
  function poolFor(
    address tokenA,
    address tokenB,
    bool stable,
    address _factory
  ) external view returns (address pool);

  /// @notice Wraps around poolFor(tokenA,tokenB,stable,_factory) for backwards compatibility to Velodrome v1
  function pairFor(
    address tokenA,
    address tokenB,
    bool stable,
    address _factory
  ) external view returns (address pool);

  /// @notice Fetch and sort the reserves for a pool
  /// @param tokenA       .
  /// @param tokenB       .
  /// @param stable       True if pool is stable, false if volatile
  /// @param _factory     Address of PoolFactory for tokenA and tokenB
  /// @return reserveA    Amount of reserves of the sorted token A
  /// @return reserveB    Amount of reserves of the sorted token B
  function getReserves(
    address tokenA,
    address tokenB,
    bool stable,
    address _factory
  ) external view returns (uint256 reserveA, uint256 reserveB);

  /// @notice Perform chained getAmountOut calculations on any number of pools
  function getAmountsOut(uint256 amountIn, Route[] memory routes) external view returns (uint256[] memory amounts);

  // **** ADD LIQUIDITY ****

  /// @notice Quote the amount deposited into a Pool
  /// @param tokenA           .
  /// @param tokenB           .
  /// @param stable           True if pool is stable, false if volatile
  /// @param _factory         Address of PoolFactory for tokenA and tokenB
  /// @param amountADesired   Amount of tokenA desired to deposit
  /// @param amountBDesired   Amount of tokenB desired to deposit
  /// @return amountA         Amount of tokenA to actually deposit
  /// @return amountB         Amount of tokenB to actually deposit
  /// @return liquidity       Amount of liquidity token returned from deposit
  function quoteAddLiquidity(
    address tokenA,
    address tokenB,
    bool stable,
    address _factory,
    uint256 amountADesired,
    uint256 amountBDesired
  )
    external
    view
    returns (
      uint256 amountA,
      uint256 amountB,
      uint256 liquidity
    );

  /// @notice Quote the amount of liquidity removed from a Pool
  /// @param tokenA       .
  /// @param tokenB       .
  /// @param stable       True if pool is stable, false if volatile
  /// @param _factory     Address of PoolFactory for tokenA and tokenB
  /// @param liquidity    Amount of liquidity to remove
  /// @return amountA     Amount of tokenA received
  /// @return amountB     Amount of tokenB received
  function quoteRemoveLiquidity(
    address tokenA,
    address tokenB,
    bool stable,
    address _factory,
    uint256 liquidity
  ) external view returns (uint256 amountA, uint256 amountB);

  /// @notice Add liquidity of two tokens to a Pool
  /// @param tokenA           .
  /// @param tokenB           .
  /// @param stable           True if pool is stable, false if volatile
  /// @param amountADesired   Amount of tokenA desired to deposit
  /// @param amountBDesired   Amount of tokenB desired to deposit
  /// @param amountAMin       Minimum amount of tokenA to deposit
  /// @param amountBMin       Minimum amount of tokenB to deposit
  /// @param to               Recipient of liquidity token
  /// @param deadline         Deadline to receive liquidity
  /// @return amountA         Amount of tokenA to actually deposit
  /// @return amountB         Amount of tokenB to actually deposit
  /// @return liquidity       Amount of liquidity token returned from deposit
  function addLiquidity(
    address tokenA,
    address tokenB,
    bool stable,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
  )
    external
    returns (
      uint256 amountA,
      uint256 amountB,
      uint256 liquidity
    );

  /// @notice Add liquidity of a token and WETH (transferred as ETH) to a Pool
  /// @param token                .
  /// @param stable               True if pool is stable, false if volatile
  /// @param amountTokenDesired   Amount of token desired to deposit
  /// @param amountTokenMin       Minimum amount of token to deposit
  /// @param amountETHMin         Minimum amount of ETH to deposit
  /// @param to                   Recipient of liquidity token
  /// @param deadline             Deadline to add liquidity
  /// @return amountToken         Amount of token to actually deposit
  /// @return amountETH           Amount of tokenETH to actually deposit
  /// @return liquidity           Amount of liquidity token returned from deposit
  function addLiquidityETH(
    address token,
    bool stable,
    uint256 amountTokenDesired,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline
  )
    external
    payable
    returns (
      uint256 amountToken,
      uint256 amountETH,
      uint256 liquidity
    );

  // **** REMOVE LIQUIDITY ****

  /// @notice Remove liquidity of two tokens from a Pool
  /// @param tokenA       .
  /// @param tokenB       .
  /// @param stable       True if pool is stable, false if volatile
  /// @param liquidity    Amount of liquidity to remove
  /// @param amountAMin   Minimum amount of tokenA to receive
  /// @param amountBMin   Minimum amount of tokenB to receive
  /// @param to           Recipient of tokens received
  /// @param deadline     Deadline to remove liquidity
  /// @return amountA     Amount of tokenA received
  /// @return amountB     Amount of tokenB received
  function removeLiquidity(
    address tokenA,
    address tokenB,
    bool stable,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
  ) external returns (uint256 amountA, uint256 amountB);

  /// @notice Remove liquidity of a token and WETH (returned as ETH) from a Pool
  /// @param token            .
  /// @param stable           True if pool is stable, false if volatile
  /// @param liquidity        Amount of liquidity to remove
  /// @param amountTokenMin   Minimum amount of token to receive
  /// @param amountETHMin     Minimum amount of ETH to receive
  /// @param to               Recipient of liquidity token
  /// @param deadline         Deadline to receive liquidity
  /// @return amountToken     Amount of token received
  /// @return amountETH       Amount of ETH received
  function removeLiquidityETH(
    address token,
    bool stable,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline
  ) external returns (uint256 amountToken, uint256 amountETH);

  /// @notice Remove liquidity of a fee-on-transfer token and WETH (returned as ETH) from a Pool
  /// @param token            .
  /// @param stable           True if pool is stable, false if volatile
  /// @param liquidity        Amount of liquidity to remove
  /// @param amountTokenMin   Minimum amount of token to receive
  /// @param amountETHMin     Minimum amount of ETH to receive
  /// @param to               Recipient of liquidity token
  /// @param deadline         Deadline to receive liquidity
  /// @return amountETH       Amount of ETH received
  function removeLiquidityETHSupportingFeeOnTransferTokens(
    address token,
    bool stable,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline
  ) external returns (uint256 amountETH);

  // **** SWAP ****

  /// @notice Swap one token for another
  /// @param amountIn     Amount of token in
  /// @param amountOutMin Minimum amount of desired token received
  /// @param routes       Array of trade routes used in the swap
  /// @param to           Recipient of the tokens received
  /// @param deadline     Deadline to receive tokens
  /// @return amounts     Array of amounts returned per route
  function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    Route[] calldata routes,
    address to,
    uint256 deadline
  ) external returns (uint256[] memory amounts);

  /// @notice Swap ETH for a token
  /// @param amountOutMin Minimum amount of desired token received
  /// @param routes       Array of trade routes used in the swap
  /// @param to           Recipient of the tokens received
  /// @param deadline     Deadline to receive tokens
  /// @return amounts     Array of amounts returned per route
  function swapExactETHForTokens(
    uint256 amountOutMin,
    Route[] calldata routes,
    address to,
    uint256 deadline
  ) external payable returns (uint256[] memory amounts);

  /// @notice Swap a token for WETH (returned as ETH)
  /// @param amountIn     Amount of token in
  /// @param amountOutMin Minimum amount of desired ETH
  /// @param routes       Array of trade routes used in the swap
  /// @param to           Recipient of the tokens received
  /// @param deadline     Deadline to receive tokens
  /// @return amounts     Array of amounts returned per route
  function swapExactTokensForETH(
    uint256 amountIn,
    uint256 amountOutMin,
    Route[] calldata routes,
    address to,
    uint256 deadline
  ) external returns (uint256[] memory amounts);

  // **** SWAP (supporting fee-on-transfer tokens) ****

  /// @notice Swap one token for another supporting fee-on-transfer tokens
  /// @param amountIn     Amount of token in
  /// @param amountOutMin Minimum amount of desired token received
  /// @param routes       Array of trade routes used in the swap
  /// @param to           Recipient of the tokens received
  /// @param deadline     Deadline to receive tokens
  function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    Route[] calldata routes,
    address to,
    uint256 deadline
  ) external;

  /// @notice Swap ETH for a token supporting fee-on-transfer tokens
  /// @param amountOutMin Minimum amount of desired token received
  /// @param routes       Array of trade routes used in the swap
  /// @param to           Recipient of the tokens received
  /// @param deadline     Deadline to receive tokens
  function swapExactETHForTokensSupportingFeeOnTransferTokens(
    uint256 amountOutMin,
    Route[] calldata routes,
    address to,
    uint256 deadline
  ) external payable;

  /// @notice Swap a token for WETH (returned as ETH) supporting fee-on-transfer tokens
  /// @param amountIn     Amount of token in
  /// @param amountOutMin Minimum amount of desired ETH
  /// @param routes       Array of trade routes used in the swap
  /// @param to           Recipient of the tokens received
  /// @param deadline     Deadline to receive tokens
  function swapExactTokensForETHSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    Route[] calldata routes,
    address to,
    uint256 deadline
  ) external;

  /// @notice Zap a token A into a pool (B, C). (A can be equal to B or C).
  ///         Supports standard ERC20 tokens only (i.e. not fee-on-transfer tokens etc).
  ///         Slippage is required for the initial swap.
  ///         Additional slippage may be required when adding liquidity as the
  ///         price of the token may have changed.
  /// @param tokenIn      Token you are zapping in from (i.e. input token).
  /// @param amountInA    Amount of input token you wish to send down routesA
  /// @param amountInB    Amount of input token you wish to send down routesB
  /// @param zapInPool    Contains zap struct information. See Zap struct.
  /// @param routesA      Route used to convert input token to tokenA
  /// @param routesB      Route used to convert input token to tokenB
  /// @param to           Address you wish to mint liquidity to.
  /// @param stake        Auto-stake liquidity in corresponding gauge.
  /// @return liquidity   Amount of LP tokens created from zapping in.
  function zapIn(
    address tokenIn,
    uint256 amountInA,
    uint256 amountInB,
    Zap calldata zapInPool,
    Route[] calldata routesA,
    Route[] calldata routesB,
    address to,
    bool stake
  ) external payable returns (uint256 liquidity);

  /// @notice Zap out a pool (B, C) into A.
  ///         Supports standard ERC20 tokens only (i.e. not fee-on-transfer tokens etc).
  ///         Slippage is required for the removal of liquidity.
  ///         Additional slippage may be required on the swap as the
  ///         price of the token may have changed.
  /// @param tokenOut     Token you are zapping out to (i.e. output token).
  /// @param liquidity    Amount of liquidity you wish to remove.
  /// @param zapOutPool   Contains zap struct information. See Zap struct.
  /// @param routesA      Route used to convert tokenA into output token.
  /// @param routesB      Route used to convert tokenB into output token.
  function zapOut(
    address tokenOut,
    uint256 liquidity,
    Zap calldata zapOutPool,
    Route[] calldata routesA,
    Route[] calldata routesB
  ) external;

  /// @notice Used to generate params required for zapping in.
  ///         Zap in => remove liquidity then swap.
  ///         Apply slippage to expected swap values to account for changes in reserves in between.
  /// @dev Output token refers to the token you want to zap in from.
  /// @param tokenA           .
  /// @param tokenB           .
  /// @param stable           .
  /// @param _factory         .
  /// @param amountInA        Amount of input token you wish to send down routesA
  /// @param amountInB        Amount of input token you wish to send down routesB
  /// @param routesA          Route used to convert input token to tokenA
  /// @param routesB          Route used to convert input token to tokenB
  /// @return amountOutMinA   Minimum output expected from swapping input token to tokenA.
  /// @return amountOutMinB   Minimum output expected from swapping input token to tokenB.
  /// @return amountAMin      Minimum amount of tokenA expected from depositing liquidity.
  /// @return amountBMin      Minimum amount of tokenB expected from depositing liquidity.
  function generateZapInParams(
    address tokenA,
    address tokenB,
    bool stable,
    address _factory,
    uint256 amountInA,
    uint256 amountInB,
    Route[] calldata routesA,
    Route[] calldata routesB
  )
    external
    view
    returns (
      uint256 amountOutMinA,
      uint256 amountOutMinB,
      uint256 amountAMin,
      uint256 amountBMin
    );

  /// @notice Used to generate params required for zapping out.
  ///         Zap out => swap then add liquidity.
  ///         Apply slippage to expected liquidity values to account for changes in reserves in between.
  /// @dev Output token refers to the token you want to zap out of.
  /// @param tokenA           .
  /// @param tokenB           .
  /// @param stable           .
  /// @param _factory         .
  /// @param liquidity        Amount of liquidity being zapped out of into a given output token.
  /// @param routesA          Route used to convert tokenA into output token.
  /// @param routesB          Route used to convert tokenB into output token.
  /// @return amountOutMinA   Minimum output expected from swapping tokenA into output token.
  /// @return amountOutMinB   Minimum output expected from swapping tokenB into output token.
  /// @return amountAMin      Minimum amount of tokenA expected from withdrawing liquidity.
  /// @return amountBMin      Minimum amount of tokenB expected from withdrawing liquidity.
  function generateZapOutParams(
    address tokenA,
    address tokenB,
    bool stable,
    address _factory,
    uint256 liquidity,
    Route[] calldata routesA,
    Route[] calldata routesB
  )
    external
    view
    returns (
      uint256 amountOutMinA,
      uint256 amountOutMinB,
      uint256 amountAMin,
      uint256 amountBMin
    );

  /// @notice Used by zapper to determine appropriate ratio of A to B to deposit liquidity. Assumes stable pool.
  /// @dev Returns stable liquidity ratio of B to (A + B).
  ///      E.g. if ratio is 0.4, it means there is more of A than there is of B.
  ///      Therefore you should deposit more of token A than B.
  /// @param tokenA   tokenA of stable pool you are zapping into.
  /// @param tokenB   tokenB of stable pool you are zapping into.
  /// @param factory  Factory that created stable pool.
  /// @return ratio   Ratio of token0 to token1 required to deposit into zap.
  function quoteStableLiquidityRatio(
    address tokenA,
    address tokenB,
    address factory
  ) external view returns (uint256 ratio);
}

//        __  __    __  ________  _______    ______   ________
//       /  |/  |  /  |/        |/       \  /      \ /        |
//   ____$$ |$$ |  $$ |$$$$$$$$/ $$$$$$$  |/$$$$$$  |$$$$$$$$/
//  /    $$ |$$ |__$$ |$$ |__    $$ |  $$ |$$ | _$$/ $$ |__
// /$$$$$$$ |$$    $$ |$$    |   $$ |  $$ |$$ |/    |$$    |
// $$ |  $$ |$$$$$$$$ |$$$$$/    $$ |  $$ |$$ |$$$$ |$$$$$/
// $$ \__$$ |$$ |  $$ |$$ |_____ $$ |__$$ |$$ \__$$ |$$ |_____
// $$    $$ |$$ |  $$ |$$       |$$    $$/ $$    $$/ $$       |
//  $$$$$$$/ $$/   $$/ $$$$$$$$/ $$$$$$$/   $$$$$$/  $$$$$$$$/
//
// dHEDGE DAO - https://dhedge.org
//
// Copyright (c) 2021 dHEDGE DAO
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//
// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@uniswap/v3-periphery/contracts/libraries/BytesLib.sol";

contract TxDataUtils {
  using BytesLib for bytes;
  using SafeMathUpgradeable for uint256;

  function getMethod(bytes memory data) public pure returns (bytes4) {
    return read4left(data, 0);
  }

  function getParams(bytes memory data) public pure returns (bytes memory) {
    return data.slice(4, data.length - 4);
  }

  function getInput(bytes memory data, uint8 inputNum) public pure returns (bytes32) {
    return read32(data, 32 * inputNum + 4, 32);
  }

  function getBytes(
    bytes memory data,
    uint8 inputNum,
    uint256 offset
  ) public pure returns (bytes memory) {
    require(offset < 20, "invalid offset"); // offset is in byte32 slots, not bytes
    offset = offset * 32; // convert offset to bytes
    uint256 bytesLenPos = uint256(read32(data, 32 * inputNum + 4 + offset, 32));
    uint256 bytesLen = uint256(read32(data, bytesLenPos + 4 + offset, 32));
    return data.slice(bytesLenPos + 4 + offset + 32, bytesLen);
  }

  function getArrayLast(bytes memory data, uint8 inputNum) public pure returns (bytes32) {
    bytes32 arrayPos = read32(data, 32 * inputNum + 4, 32);
    bytes32 arrayLen = read32(data, uint256(arrayPos) + 4, 32);
    require(arrayLen > 0, "input is not array");
    return read32(data, uint256(arrayPos) + 4 + (uint256(arrayLen) * 32), 32);
  }

  function getArrayLength(bytes memory data, uint8 inputNum) public pure returns (uint256) {
    bytes32 arrayPos = read32(data, 32 * inputNum + 4, 32);
    return uint256(read32(data, uint256(arrayPos) + 4, 32));
  }

  function getArrayIndex(
    bytes memory data,
    uint8 inputNum,
    uint8 arrayIndex
  ) public pure returns (bytes32) {
    bytes32 arrayPos = read32(data, 32 * inputNum + 4, 32);
    bytes32 arrayLen = read32(data, uint256(arrayPos) + 4, 32);
    require(arrayLen > 0, "input is not array");
    require(uint256(arrayLen) > arrayIndex, "invalid array position");
    return read32(data, uint256(arrayPos) + 4 + ((1 + uint256(arrayIndex)) * 32), 32);
  }

  function read4left(bytes memory data, uint256 offset) public pure returns (bytes4 o) {
    require(data.length >= offset + 4, "Reading bytes out of bounds");
    assembly {
      o := mload(add(data, add(32, offset)))
    }
  }

  function read32(
    bytes memory data,
    uint256 offset,
    uint256 length
  ) public pure returns (bytes32 o) {
    require(data.length >= offset + length, "Reading bytes out of bounds");
    assembly {
      o := mload(add(data, add(32, offset)))
      let lb := sub(32, length)
      if lb {
        o := div(o, exp(2, mul(lb, 8)))
      }
    }
  }

  function convert32toAddress(bytes32 data) public pure returns (address o) {
    return address(uint160(uint256(data)));
  }

  function sliceUint(bytes memory data, uint256 start) internal pure returns (uint256) {
    require(data.length >= start + 32, "slicing out of range");
    uint256 x;
    assembly {
      x := mload(add(data, add(0x20, start)))
    }
    return x;
  }
}