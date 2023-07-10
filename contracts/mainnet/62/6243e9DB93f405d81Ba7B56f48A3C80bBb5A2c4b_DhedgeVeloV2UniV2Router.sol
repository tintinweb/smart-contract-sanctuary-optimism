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
library SafeMath {
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

interface IUniswapV2RouterSwapOnly {
  function getAmountsOut(uint256 amountIn, address[] memory path) external view returns (uint256[] memory amounts);

  function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external returns (uint256[] memory amounts);

  function swapTokensForExactTokens(
    uint256 amountOut,
    uint256 amountInMax,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external returns (uint256[] memory amounts);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

interface IVelodromeV2Factory {
  /// @notice returns the number of pools created from this factory
  function allPoolsLength() external view returns (uint256);

  /// @notice Is a valid pool created by this factory.
  /// @param .
  function isPool(address pool) external view returns (bool);

  /// @notice Support for Velodrome v1 which wraps around isPool(pool);
  /// @param .
  function isPair(address pool) external view returns (bool);

  /// @notice Return address of pool created by this factory
  /// @param tokenA .
  /// @param tokenB .
  /// @param stable True if stable, false if volatile
  function getPool(
    address tokenA,
    address tokenB,
    bool stable
  ) external view returns (address);

  /// @notice Support for v3-style pools which wraps around getPool(tokenA,tokenB,stable)
  /// @dev fee is converted to stable boolean.
  /// @param tokenA .
  /// @param tokenB .
  /// @param fee  1 if stable, 0 if volatile, else returns address(0)
  function getPool(
    address tokenA,
    address tokenB,
    uint24 fee
  ) external view returns (address);

  /// @notice Support for Velodrome v1 pools as a "pool" was previously referenced as "pair"
  /// @notice Wraps around getPool(tokenA,tokenB,stable)
  function getPair(
    address tokenA,
    address tokenB,
    bool stable
  ) external view returns (address);

  /// @dev Only called once to set to Voter.sol - Voter does not have a function
  ///      to call this contract method, so once set it's immutable.
  ///      This also follows convention of setVoterAndDistributor() in VotingEscrow.sol
  /// @param _voter .
  function setVoter(address _voter) external;

  function setSinkConverter(
    address _sinkConvert,
    address _velo,
    address _veloV2
  ) external;

  function setPauser(address _pauser) external;

  function setPauseState(bool _state) external;

  function setFeeManager(address _feeManager) external;

  /// @notice Set default fee for stable and volatile pools.
  /// @dev Throws if higher than maximum fee.
  ///      Throws if fee is zero.
  /// @param _stable Stable or volatile pool.
  /// @param _fee .
  function setFee(bool _stable, uint256 _fee) external;

  /// @notice Set overriding fee for a pool from the default
  /// @dev A custom fee of zero means the default fee will be used.
  function setCustomFee(address _pool, uint256 _fee) external;

  /// @notice Returns fee for a pool, as custom fees are possible.
  function getFee(address _pool, bool _stable) external view returns (uint256);

  /// @notice Create a pool given two tokens and if they're stable/volatile
  /// @dev token order does not matter
  /// @param tokenA .
  /// @param tokenB .
  /// @param stable .
  function createPool(
    address tokenA,
    address tokenB,
    bool stable
  ) external returns (address pool);

  /// @notice Support for v3-style pools which wraps around createPool(tokena,tokenB,stable)
  /// @dev fee is converted to stable boolean
  /// @dev token order does not matter
  /// @param tokenA .
  /// @param tokenB .
  /// @param fee 1 if stable, 0 if volatile, else revert
  function createPool(
    address tokenA,
    address tokenB,
    uint24 fee
  ) external returns (address pool);

  /// @notice Support for Velodrome v1 which wraps around createPool(tokenA,tokenB,stable)
  function createPair(
    address tokenA,
    address tokenB,
    bool stable
  ) external returns (address pool);

  function isPaused() external view returns (bool);

  function velo() external view returns (address);

  function veloV2() external view returns (address);

  function voter() external view returns (address);

  function sinkConverter() external view returns (address);

  function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

interface IVelodromeV2Pair {
  function token0() external view returns (address);

  function token1() external view returns (address);

  function claimable0(address user) external view returns (uint256);

  function claimable1(address user) external view returns (uint256);

  function totalSupply() external view returns (uint256);

  function quote(
    address tokenIn,
    uint256 amountIn,
    uint256 granularity
  ) external view returns (uint256 amountOut);

  function burn(address to) external returns (uint256 amount0, uint256 amount1);

  function getReserves()
    external
    view
    returns (
      uint112 reserve0,
      uint112 reserve1,
      uint32 blockTimestampLast
    );

  function claimFees() external returns (uint256 claimed0, uint256 claimed1);

  function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
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

// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/velodrome/IVelodromeV2Factory.sol";
import "../interfaces/velodrome/IVelodromeV2Router.sol";
import "../interfaces/velodrome/IVelodromeV2Pair.sol";
import "../interfaces/uniswapv2/IUniswapV2RouterSwapOnly.sol";

contract DhedgeVeloV2UniV2Router is IUniswapV2RouterSwapOnly {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  uint256 private constant HOPS_LIMIT = 3;

  IVelodromeV2Router public velodromeV2Router;
  IVelodromeV2Factory public velodromeV2Factory;

  constructor(IVelodromeV2Router _velodromeV2Router, IVelodromeV2Factory _velodromeV2Factory) {
    velodromeV2Router = _velodromeV2Router;
    velodromeV2Factory = _velodromeV2Factory;
  }

  function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external override returns (uint256[] memory amountsOut) {
    require(path.length <= HOPS_LIMIT, "too many hops");

    (uint256 out, bool stable) = _getAmountOut(path[0], path[1], amountIn);

    IVelodromeV2Router.Route[] memory routes = new IVelodromeV2Router.Route[](path.length == HOPS_LIMIT ? 2 : 1);
    routes[0] = IVelodromeV2Router.Route({
      from: path[0],
      to: path[1],
      stable: stable,
      factory: address(velodromeV2Factory)
    });
    if (path.length == HOPS_LIMIT) {
      (, stable) = _getAmountOut(path[1], path[2], out);
      routes[1] = IVelodromeV2Router.Route({
        from: path[1],
        to: path[2],
        stable: stable,
        factory: address(velodromeV2Factory)
      });
    }

    IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
    IERC20(path[0]).safeIncreaseAllowance(address(velodromeV2Router), amountIn);
    amountsOut = velodromeV2Router.swapExactTokensForTokens(amountIn, amountOutMin, routes, to, deadline);

    require(amountsOut[path.length - 1] >= amountOutMin, "too much slippage");
  }

  function swapTokensForExactTokens(
    uint256,
    uint256,
    address[] calldata,
    address,
    uint256
  ) external pure override returns (uint256[] memory) {
    revert("STFET not supported");
  }

  function getAmountsOut(uint256 amountIn, address[] calldata path)
    external
    view
    override
    returns (uint256[] memory amountsOut)
  {
    require(path.length <= HOPS_LIMIT, "too many hops");

    (uint256 amountOut, ) = _getAmountOut(path[0], path[1], amountIn);
    if (path.length == HOPS_LIMIT) {
      (amountOut, ) = _getAmountOut(path[1], path[2], amountOut);
    }
    amountsOut = new uint256[](path.length);
    amountsOut[path.length - 1] = amountOut;
  }

  function getAmountsIn(uint256, address[] calldata path) external pure returns (uint256[] memory amountsIn) {
    // Not supported
    amountsIn = new uint256[](path.length);
  }

  function _getAmountOut(
    address tokenIn,
    address tokenOut,
    uint256 amountIn
  ) internal view returns (uint256 amountOut, bool stable) {
    address pair = velodromeV2Router.poolFor(tokenIn, tokenOut, true, address(velodromeV2Factory));
    if (velodromeV2Factory.isPool(pair)) {
      amountOut = IVelodromeV2Pair(pair).getAmountOut(amountIn, tokenIn);
      stable = true;
    } else {
      pair = velodromeV2Router.poolFor(tokenIn, tokenOut, false, address(velodromeV2Factory));
      if (velodromeV2Factory.isPool(pair)) {
        amountOut = IVelodromeV2Pair(pair).getAmountOut(amountIn, tokenIn);
      }
    }
  }
}