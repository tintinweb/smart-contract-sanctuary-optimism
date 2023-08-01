// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

pragma solidity >=0.6.0 <0.8.0;

/**
 * @title SignedSafeMath
 * @dev Signed math operations with safety checks that revert on error.
 */
library SignedSafeMathUpgradeable {
    int256 constant private _INT256_MIN = -2**255;

    /**
     * @dev Returns the multiplication of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == _INT256_MIN), "SignedSafeMath: multiplication overflow");

        int256 c = a * b;
        require(c / a == b, "SignedSafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two signed integers. Reverts on
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
    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != 0, "SignedSafeMath: division by zero");
        require(!(b == -1 && a == _INT256_MIN), "SignedSafeMath: division overflow");

        int256 c = a / b;

        return c;
    }

    /**
     * @dev Returns the subtraction of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), "SignedSafeMath: subtraction overflow");

        return c;
    }

    /**
     * @dev Returns the addition of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), "SignedSafeMath: addition overflow");

        return c;
    }
}

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity >=0.4.24 <0.8.0;

import "../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || _isConstructor() || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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

pragma solidity >=0.6.0 <0.8.0;

import "./IERC20Upgradeable.sol";
import "../../math/SafeMathUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    function safeTransfer(IERC20Upgradeable token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20Upgradeable token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./ContextUpgradeable.sol";
import "../proxy/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal initializer {
        __Context_init_unchained();
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal initializer {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal initializer {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal initializer {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { SafeOwnable } from "./SafeOwnable.sol";

abstract contract OwnerPausable is SafeOwnable, PausableUpgradeable {
    // __gap is reserved storage
    uint256[50] private __gap;

    // solhint-disable-next-line func-order
    function __OwnerPausable_init() internal initializer {
        __SafeOwnable_init();
        __Pausable_init();
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _msgSender() internal view virtual override returns (address payable) {
        return super._msgSender();
    }

    function _msgData() internal view virtual override returns (bytes memory) {
        return super._msgData();
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

abstract contract SafeOwnable is ContextUpgradeable {
    address private _owner;
    address private _candidate;

    // __gap is reserved storage
    uint256[50] private __gap;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        // caller not owner
        require(owner() == _msgSender(), "SO_CNO");
        _;
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */

    function __SafeOwnable_init() internal initializer {
        __Context_init();
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() external virtual onlyOwner {
        // emitting event first to avoid caching values
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
        _candidate = address(0);
    }

    /**
     * @dev Set ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function setOwner(address newOwner) external onlyOwner {
        // newOwner is 0
        require(newOwner != address(0), "SO_NW0");
        // same as original
        require(newOwner != _owner, "SO_SAO");
        // same as candidate
        require(newOwner != _candidate, "SO_SAC");

        _candidate = newOwner;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`_candidate`).
     * Can only be called by the new owner.
     */
    function updateOwner() external {
        // candidate is zero
        require(_candidate != address(0), "SO_C0");
        // caller is not candidate
        require(_candidate == _msgSender(), "SO_CNC");

        // emitting event first to avoid caching values
        emit OwnershipTransferred(_owner, _candidate);
        _owner = _candidate;
        _candidate = address(0);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Returns the candidate that can become the owner.
     */
    function candidate() external view returns (address) {
        return _candidate;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.7.6;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20Upgradeable {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";
import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import { SafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import { SignedSafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

library PerpMath {
    using PerpSafeCast for int256;
    using SignedSafeMathUpgradeable for int256;
    using SafeMathUpgradeable for uint256;

    function formatSqrtPriceX96ToPriceX96(uint160 sqrtPriceX96) internal pure returns (uint256) {
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
    }

    function formatX10_18ToX96(uint256 valueX10_18) internal pure returns (uint256) {
        return FullMath.mulDiv(valueX10_18, FixedPoint96.Q96, 1 ether);
    }

    function formatX96ToX10_18(uint256 valueX96) internal pure returns (uint256) {
        return FullMath.mulDiv(valueX96, 1 ether, FixedPoint96.Q96);
    }

    function max(int256 a, int256 b) internal pure returns (int256) {
        return a >= b ? a : b;
    }

    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    function abs(int256 value) internal pure returns (uint256) {
        return value >= 0 ? value.toUint256() : neg256(value).toUint256();
    }

    function neg256(int256 a) internal pure returns (int256) {
        require(a > -2**255, "PerpMath: inversion overflow");
        return -a;
    }

    function neg256(uint256 a) internal pure returns (int256) {
        return -PerpSafeCast.toInt256(a);
    }

    function neg128(int128 a) internal pure returns (int128) {
        require(a > -2**127, "PerpMath: inversion overflow");
        return -a;
    }

    function neg128(uint128 a) internal pure returns (int128) {
        return -PerpSafeCast.toInt128(a);
    }

    function divBy10_18(int256 value) internal pure returns (int256) {
        // no overflow here
        return value / (1 ether);
    }

    function divBy10_18(uint256 value) internal pure returns (uint256) {
        // no overflow here
        return value / (1 ether);
    }

    function subRatio(uint24 a, uint24 b) internal pure returns (uint24) {
        require(b <= a, "PerpMath: subtraction overflow");
        return a - b;
    }

    function mulRatio(uint256 value, uint24 ratio) internal pure returns (uint256) {
        return FullMath.mulDiv(value, ratio, 1e6);
    }

    function mulRatio(int256 value, uint24 ratio) internal pure returns (int256) {
        return mulDiv(value, int256(ratio), 1e6);
    }

    function divRatio(uint256 value, uint24 ratio) internal pure returns (uint256) {
        return FullMath.mulDiv(value, 1e6, ratio);
    }

    /// @param denominator cannot be 0 and is checked in FullMath.mulDiv()
    function mulDiv(
        int256 a,
        int256 b,
        uint256 denominator
    ) internal pure returns (int256 result) {
        uint256 unsignedA = a < 0 ? uint256(neg256(a)) : uint256(a);
        uint256 unsignedB = b < 0 ? uint256(neg256(b)) : uint256(b);
        bool negative = ((a < 0 && b > 0) || (a > 0 && b < 0)) ? true : false;

        uint256 unsignedResult = FullMath.mulDiv(unsignedA, unsignedB, denominator);

        result = negative ? neg256(unsignedResult) : PerpSafeCast.toInt256(unsignedResult);

        return result;
    }

    function findMedianOfThree(
        uint256 v1,
        uint256 v2,
        uint256 v3
    ) internal pure returns (uint256) {
        return MathUpgradeable.max(MathUpgradeable.min(v1, v2), MathUpgradeable.min(MathUpgradeable.max(v1, v2), v3));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

/**
 * @dev copy from "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol"
 * and rename to avoid naming conflict with uniswap
 */
library PerpSafeCast {
    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128 returnValue) {
        require(((returnValue = uint128(value)) == value), "SafeCast: value doesn't fit in 128 bits");
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64 returnValue) {
        require(((returnValue = uint64(value)) == value), "SafeCast: value doesn't fit in 64 bits");
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32 returnValue) {
        require(((returnValue = uint32(value)) == value), "SafeCast: value doesn't fit in 32 bits");
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toUint24(uint256 value) internal pure returns (uint24 returnValue) {
        require(((returnValue = uint24(value)) == value), "SafeCast: value doesn't fit in 24 bits");
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16 returnValue) {
        require(((returnValue = uint16(value)) == value), "SafeCast: value doesn't fit in 16 bits");
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     */
    function toUint8(uint256 value) internal pure returns (uint8 returnValue) {
        require(((returnValue = uint8(value)) == value), "SafeCast: value doesn't fit in 8 bits");
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128 returnValue) {
        require(((returnValue = int128(value)) == value), "SafeCast: value doesn't fit in 128 bits");
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64 returnValue) {
        require(((returnValue = int64(value)) == value), "SafeCast: value doesn't fit in 64 bits");
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32 returnValue) {
        require(((returnValue = int32(value)) == value), "SafeCast: value doesn't fit in 32 bits");
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16 returnValue) {
        require(((returnValue = int16(value)) == value), "SafeCast: value doesn't fit in 16 bits");
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8 returnValue) {
        require(((returnValue = int8(value)) == value), "SafeCast: value doesn't fit in 8 bits");
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }

    /**
     * @dev Returns the downcasted uint24 from int256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0 and into 24 bit.
     */
    function toUint24(int256 value) internal pure returns (uint24 returnValue) {
        require(
            ((returnValue = uint24(value)) == value),
            "SafeCast: value must be positive or value doesn't fit in an 24 bits"
        );
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toInt24(int256 value) internal pure returns (int24 returnValue) {
        require(((returnValue = int24(value)) == value), "SafeCast: value doesn't fit in an 24 bits");
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

interface IPriceFeed {
    function decimals() external view returns (uint8);

    /// @dev Returns the index price of the token.
    /// @param interval The interval represents twap interval.
    function getPrice(uint256 interval) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Callback for IUniswapV3PoolActions#swap
/// @notice Any contract that calls IUniswapV3PoolActions#swap must implement this interface
interface IUniswapV3SwapCallback {
    /// @notice Called to `msg.sender` after executing a swap via IUniswapV3Pool#swap.
    /// @dev In the implementation you must pay the pool tokens owed for the swap.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// amount0Delta and amount1Delta can both be 0 if no tokens were swapped.
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token0 to the pool.
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token1 to the pool.
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.4.0;

/// @title FixedPoint96
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)
/// @dev Used in SqrtPriceMath.sol
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.0;

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 512-bit multiply [prod1 prod0] = a * b
        // Compute the product mod 2**256 and mod 2**256 - 1
        // then use the Chinese Remainder Theorem to reconstruct
        // the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2**256 + prod0
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // Handle non-overflow cases, 256 by 256 division
        if (prod1 == 0) {
            require(denominator > 0);
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        // Make sure the result is less than 2**256.
        // Also prevents denominator == 0
        require(denominator > prod1);

        ///////////////////////////////////////////////
        // 512 by 256 division.
        ///////////////////////////////////////////////

        // Make division exact by subtracting the remainder from [prod1 prod0]
        // Compute remainder using mulmod
        uint256 remainder;
        assembly {
            remainder := mulmod(a, b, denominator)
        }
        // Subtract 256 bit number from 512 bit number
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        // Factor powers of two out of denominator
        // Compute largest power of two divisor of denominator.
        // Always >= 1.
        uint256 twos = -denominator & denominator;
        // Divide denominator by power of two
        assembly {
            denominator := div(denominator, twos)
        }

        // Divide [prod1 prod0] by the factors of two
        assembly {
            prod0 := div(prod0, twos)
        }
        // Shift in bits from prod1 into prod0. For this we need
        // to flip `twos` such that it is 2**256 / twos.
        // If twos is zero, then it becomes one
        assembly {
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        // Invert denominator mod 2**256
        // Now that denominator is an odd number, it has an inverse
        // modulo 2**256 such that denominator * inv = 1 mod 2**256.
        // Compute the inverse by starting with a seed that is correct
        // correct for four bits. That is, denominator * inv = 1 mod 2**4
        uint256 inv = (3 * denominator) ^ 2;
        // Now use Newton-Raphson iteration to improve the precision.
        // Thanks to Hensel's lifting lemma, this also works in modular
        // arithmetic, doubling the correct bits in each step.
        inv *= 2 - denominator * inv; // inverse mod 2**8
        inv *= 2 - denominator * inv; // inverse mod 2**16
        inv *= 2 - denominator * inv; // inverse mod 2**32
        inv *= 2 - denominator * inv; // inverse mod 2**64
        inv *= 2 - denominator * inv; // inverse mod 2**128
        inv *= 2 - denominator * inv; // inverse mod 2**256

        // Because the division is now exact we can divide by multiplying
        // with the modular inverse of denominator. This will give us the
        // correct result modulo 2**256. Since the precoditions guarantee
        // that the outcome is less than 2**256, this is the final result.
        // We don't need to compute the high bits of the result and prod1
        // is no longer required.
        result = prod0 * inv;
        return result;
    }

    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol';

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface ISwapRouter is IUniswapV3SwapCallback {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { IERC20Metadata } from "@perp/curie-contract/contracts/interface/IERC20Metadata.sol";
import { PerpSafeCast } from "@perp/curie-contract/contracts/lib/PerpSafeCast.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import { SafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import { SignedSafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import { CommonVault } from "./CommonVault.sol";
import { IVaultConfig } from "./interface/IVaultConfig.sol";
import { IPerpPositionManager } from "./interface/IPerpPositionManager.sol";

contract BaseVault is CommonVault {
    using SafeMathUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;
    using FullMath for uint256;
    using PerpSafeCast for uint256;
    using PerpSafeCast for int256;

    //
    // EXTERNAL NON-VIEW
    //

    function deposit(uint256 assets) external override whenNotPaused nonReentrant returns (uint256) {
        return _deposit(_msgSender(), assets);
    }

    function depositFor(address to, uint256 assets) external override whenNotPaused nonReentrant returns (uint256) {
        return _deposit(to, assets);
    }

    function swapExactOutput(SwapExactOutputParams calldata params)
        external
        override
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        revert("Not Implemented");
    }

    function deleverage(uint256 reducedPositionSizeAbs)
        external
        override
        whenNotPaused
        nonReentrant
        returns (int256 pnl)
    {
        _requireIsWhitelistedArbitrageur(_msgSender());

        uint24 deleverageRatio = IVaultConfig(_vaultConfig).getDeleverageMarginRatio(address(this));
        // BV_MSCD : margin sufficient; cannot deleverage
        require(!IPerpPositionManager(_perpPositionManager).isMarginSufficientByRatio(deleverageRatio), "BV_MSCD");

        uint256 maxDeleveragePositionSize = IPerpPositionManager(_perpPositionManager).getDeleveragedPositionSize(
            deleverageRatio
        );

        // BV_RPSTM: Reduced Position Size Too Much
        require(reducedPositionSizeAbs <= maxDeleveragePositionSize, "BV_RPSTM");

        return _deleverage(reducedPositionSizeAbs == 0 ? maxDeleveragePositionSize : reducedPositionSizeAbs);
    }

    //
    // PUBLIC VIEW
    //

    /// @dev denominated in baseToken, hence the return values are rounded to _bd, baseToken's decimals
    function totalAssets() public view override returns (uint256) {
        IERC20Metadata baseToken = IERC20Metadata(_baseToken);
        uint256 base_bd = baseToken.balanceOf(address(this));
        uint256 quote_qd = IERC20Metadata(_quoteToken).balanceOf(address(this));

        // we require quoteToken decimals == perp settlementToken decimals in initialize()
        // getAccountValueSafe_6() reverts if bankrupt
        uint256 perpAccountValue_qd = IPerpPositionManager(_perpPositionManager).getAccountValueSafe_6().toUint256();

        // NOTE: ChainlinkPriceFeedV1R1 decimals is 8,
        // however, baseToken decimals could be 18 (ETH and DAI), 6 (USDT), or 8 (WBTC)
        // scale up quoteToken's decimals _qd to baseToken's decimals _bd
        uint256 totalQuote_qd = quote_qd.add(perpAccountValue_qd);
        uint256 totalQuoteInBase_qd = totalQuote_qd.mulDiv(10**_CHAINLINK_AGGREGATOR_DECIMALS_8, getIndexPrice());
        uint256 totalQuoteInBase_bd = _formatDecimals(totalQuoteInBase_qd, _quoteTokenDecimals, _baseTokenDecimals);

        return totalQuoteInBase_bd.add(base_bd);
    }

    //
    // INTERNAL NON-VIEW
    //

    function _deposit(address to, uint256 assets) internal returns (uint256) {
        return _depositFor(to, assets);
    }

    function _redeemByShares(uint256 shares, uint256 totalSupply) internal override returns (uint256) {
        (uint256 usdcForBuyingBase_6, uint256 redeemedBase) = _getBalancesByShares(shares, totalSupply);

        uint256 usdcWithdrawnFromPerp_6 = _redeemPerpPositionByShares(shares, totalSupply);
        usdcForBuyingBase_6 = usdcForBuyingBase_6.add(usdcWithdrawnFromPerp_6);

        // if usdcForBuyingBase_6 == 0, will encounter error 'AS' in UniswapV3Pool
        if (usdcForBuyingBase_6 > 0) {
            // reduce spot on uniswap
            uint256 baseBoughtFromUni = _swapExactInputOnUni(_quoteToken, _baseToken, usdcForBuyingBase_6);

            // usdcForBuyingBase_6 = quoteToken here +
            //                       reduce position and withdraw from perp
            // redeemedBase = baseToken here (include arb profit) +
            //                buy eth with usdcForBuyingBase_6 on uniswap
            redeemedBase = redeemedBase.add(baseBoughtFromUni);
        }

        SafeERC20Upgradeable.safeTransfer(IERC20Metadata(_baseToken), _msgSender(), redeemedBase);

        return redeemedBase;
    }

    function _reducePerpPosition(uint256 reducedPositionSizeAbs)
        internal
        override
        returns (uint256 perpBase, uint256 perpQuote)
    {
        return
            IPerpPositionManager(_perpPositionManager).openPosition(
                IPerpPositionManager.OpenPositionParams({
                    isBaseToQuote: true,
                    isExactInput: true,
                    amount: reducedPositionSizeAbs
                })
            );
    }

    function _deleverage(uint256 reducedPositionSizeAbs) internal returns (int256 pnl) {
        // reduce position on perp: baseVault only has long position, reduce position means short
        // TODO: add slippage protection
        uint256 totalAssetsBefore = totalAssets();

        // ensure baseVault only has long position
        (uint256 perpBase, uint256 perpQuote) = _reducePerpPosition(reducedPositionSizeAbs);

        uint256 totalAssetsAfter = totalAssets();

        int256 pnl = totalAssetsAfter.toInt256().sub(totalAssetsBefore.toInt256());

        emit Deleverage(
            _msgSender(),
            IPerpPositionManager(_perpPositionManager).getBaseToken(),
            reducedPositionSizeAbs,
            perpBase,
            perpQuote,
            0,
            pnl
        );

        return pnl;
    }

    //
    // INTERNAL VIEW
    //

    function _getAssetDecimals() internal view override returns (uint8) {
        return _baseTokenDecimals;
    }

    function _getAsset() internal view override returns (address) {
        return _baseToken;
    }

    /// @dev baseVault should only have long position
    function _getPerpPositionSizeSafe() internal view override returns (int256) {
        int256 positionSize = IPerpPositionManager(_perpPositionManager).getTakerPositionSize();
        // BV_PSS: Position Size is Short
        require(positionSize >= 0, "BV_PSS");
        return positionSize;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IPriceFeed } from "@perp/perp-oracle-contract/contracts/interface/IPriceFeed.sol";
import { IERC20Metadata } from "@perp/curie-contract/contracts/interface/IERC20Metadata.sol";
import { OwnerPausable } from "@perp/curie-contract/contracts/base/OwnerPausable.sol";
import { PerpSafeCast } from "@perp/curie-contract/contracts/lib/PerpSafeCast.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { SafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import { SignedSafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import { PerpMath } from "@perp/curie-contract/contracts/lib/PerpMath.sol";
import { AddressUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import { IVaultConfig } from "./interface/IVaultConfig.sol";
import { IVaultToken } from "./interface/IVaultToken.sol";
import { ICommonVault } from "./interface/ICommonVault.sol";
import { IPerpPositionManager } from "./interface/IPerpPositionManager.sol";
import { CommonVaultStorageV3 } from "./storage/CommonVaultStorage.sol";
import { IRouter } from "./interface/IRouter.sol";
import { IRouterStruct } from "./interface/IRouterStruct.sol";
import { IShowerRoom } from "./interface/IShowerRoom.sol";

abstract contract CommonVault is ICommonVault, OwnerPausable, ReentrancyGuardUpgradeable, CommonVaultStorageV3 {
    using AddressUpgradeable for address;
    using FullMath for uint256;
    using SafeMathUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;
    using PerpMath for int256;
    using PerpMath for uint256;
    using PerpSafeCast for uint256;
    using PerpSafeCast for int256;

    struct InternalOpenPerpPositionParams {
        bool isBaseToQuote;
        uint256 spotIn;
        uint256 spotOutMinimum;
        uint256 deadline;
        uint160 sqrtPriceLimitX96;
    }

    uint8 internal constant _CHAINLINK_AGGREGATOR_DECIMALS_8 = 8;
    uint8 internal constant _PERP_DECIMALS_18 = 18;

    //
    // EXTERNAL NON-VIEW
    //

    function initialize(
        address vaultTokenArg,
        address quoteTokenArg,
        address baseTokenArg,
        address vaultConfigArg,
        address perpPositionManagerArg
    ) external initializer {
        __OwnerPausable_init();
        __ReentrancyGuard_init();

        _vaultToken = vaultTokenArg;
        _perpPositionManager = perpPositionManagerArg;
        _vaultConfig = vaultConfigArg;

        // CV_QTMBST: QuoteToken must be SettlementToken
        require(quoteTokenArg == IPerpPositionManager(perpPositionManagerArg).getSettlementToken(), "CV_QTMBST");
        _quoteToken = quoteTokenArg;
        _quoteTokenDecimals = _getDecimalsSafe(quoteTokenArg);

        // ex: WETH decimals is 18, WBTC decimals is 8
        _baseToken = baseTokenArg;
        _baseTokenDecimals = _getDecimalsSafe(baseTokenArg);

        IERC20Metadata(quoteTokenArg).approve(perpPositionManagerArg, type(uint256).max);
    }

    function setRouter(address routerArg) external onlyOwner {
        address oldRouter = _router;

        // revoke approvals for old router
        if (oldRouter != address(0)) {
            IERC20Metadata(_quoteToken).approve(oldRouter, 0);
            IERC20Metadata(_baseToken).approve(oldRouter, 0);
        }

        // CV_RNC: router is not a contract
        require(routerArg.isContract(), "CV_RNC");
        _router = routerArg;

        IERC20Metadata(_quoteToken).approve(routerArg, type(uint256).max);
        IERC20Metadata(_baseToken).approve(routerArg, type(uint256).max);

        emit UpdateRouterAddress(oldRouter, routerArg);
    }

    function setQuoteUsdPriceFeed(address quoteUsdPriceFeedArg) external onlyOwner {
        require(quoteUsdPriceFeedArg.isContract(), "CV_QUPNC");

        address oldQuoteUsdPriceFeed = _quoteUsdPriceFeed;
        _quoteUsdPriceFeed = quoteUsdPriceFeedArg;

        emit UpdateQuoteUsdPriceFeed(oldQuoteUsdPriceFeed, quoteUsdPriceFeedArg);
    }

    function setBaseUsdPriceFeed(address baseUsdPriceFeedArg) external onlyOwner {
        require(baseUsdPriceFeedArg.isContract(), "CV_BUPNC");

        address oldBaseUsdPriceFeed = _baseUsdPriceFeed;
        _baseUsdPriceFeed = baseUsdPriceFeedArg;

        emit UpdateBaseUsdPriceFeed(oldBaseUsdPriceFeed, baseUsdPriceFeedArg);
    }

    function setShowerRoom(address showerRoomArg) external onlyOwner {
        _showerRoom = showerRoomArg;
        emit UpdateShowerRoom(showerRoomArg);
    }

    function redeem(uint256 shares, uint256 minRedeemedAmount)
        external
        override
        whenNotPaused
        nonReentrant
        returns (uint256 redeemed)
    {
        _requireUint256GreaterThanZero(shares);

        address msgSender = _msgSender();
        uint256 totalSupplyBeforeBurn = _getTotalSupply();
        IVaultToken(_vaultToken).burn(msgSender, shares);

        redeemed = _redeemByShares(shares, totalSupplyBeforeBurn);
        // CV_RALTMRA: RedeemedAmount is Less Than MinRedeemedAmount
        require(redeemed >= minRedeemedAmount, "CV_RALTMRA");

        emit Redeem(msgSender, redeemed, shares);

        return redeemed;
    }

    function swapExactInput(SwapExactInputParams calldata params)
        external
        override
        whenNotPaused
        nonReentrant
        returns (uint256 amountOut)
    {
        address msgSender = _msgSender();
        _requireIsWhitelistedArbitrageur(msgSender);
        _requireTokens(params.tokenIn, params.tokenOut);

        int256 perpPositionSizeBeforeSwap = _getPerpPositionSizeSafe();
        bool isBaseToQuote = params.tokenIn == _baseToken;

        // quoteVault positionSize <= 0, short on perp => quoteVault increase position
        // baseVault positionSize >= 0, long on perp => baseVault increase position
        // copied from Exchange
        bool isReducingPosition = perpPositionSizeBeforeSwap == 0
            ? false
            : perpPositionSizeBeforeSwap < 0 != isBaseToQuote;

        // we should check margin ratio if
        // 1. withdraw
        // 2. increase position
        // which will both lower the margin ratio
        if (!isReducingPosition) {
            _requireMarginRatioGreaterThanSwapRestriction();
        }

        SafeERC20Upgradeable.safeTransferFrom(
            IERC20Metadata(params.tokenIn),
            msgSender,
            address(this),
            params.amountIn
        );

        uint256 fee = params.amountIn.mulRatio(
            IVaultConfig(_vaultConfig).getExchangeFeeRatioByTrader(msgSender, address(this))
        );

        (uint256 perpBase, uint256 perpQuote) = _openPerpPosition(
            InternalOpenPerpPositionParams({
                isBaseToQuote: isBaseToQuote,
                spotIn: params.amountIn.sub(fee),
                spotOutMinimum: params.amountOutMinimum,
                deadline: params.deadline,
                sqrtPriceLimitX96: params.sqrtPriceLimitX96OnPerp
            })
        );

        if (isBaseToQuote) {
            // quoteToken == perp.settlementToken is asserted during initialization
            amountOut = _formatPerpToQuoteDecimals(perpQuote);

            // if Vault has no enough freeCollateral for the specified amountOut of usdc for withdraw(),
            // tx will be reverted with "V_NEFC"
            IPerpPositionManager(_perpPositionManager).withdraw(_quoteToken, amountOut);

            // if withdraw() is successful, there will be enough quoteToken to be sent out to users
            // and thus we don't need another check for the balance of quoteToken
        } else {
            // quote to base

            amountOut = _formatPerpToBaseDecimals(perpBase);
            // require there is enough amountOut as Vault can run out of BaseToken
            // CV_ILB: insufficient liquidity: baseToken
            require(amountOut <= IERC20Metadata(_baseToken).balanceOf(address(this)), "CV_ILB");
        }

        if (!isReducingPosition) {
            _requireMarginRatioGreaterThanDeleverage();
        }

        SafeERC20Upgradeable.safeTransfer(IERC20Metadata(params.tokenOut), params.recipient, amountOut);
        emit Swap(msgSender, params.tokenIn, params.tokenOut, params.amountIn, amountOut, params.recipient, fee);

        return amountOut;
    }

    //
    // EXTERNAL VIEW
    //

    function getQuoteToken() external view returns (address) {
        return _quoteToken;
    }

    function getBaseToken() external view returns (address) {
        return _baseToken;
    }

    function getVaultConfig() external view returns (address) {
        return _vaultConfig;
    }

    function getRouter() external view override returns (address) {
        return _router;
    }

    function getQuoteUsdPriceFeed() external view override returns (address) {
        return _quoteUsdPriceFeed;
    }

    function getBaseUsdPriceFeed() external view override returns (address) {
        return _baseUsdPriceFeed;
    }

    //
    // PUBLIC VIEW
    //

    function totalAssets() public view virtual override returns (uint256);

    /// @dev convert Base/USD and Quote/USD to Base/Quote
    function getIndexPrice() public view override returns (uint256) {
        // NOTE: we're using ChainlinkPriceFeedV1R1 for price feeds instead of PriceFeedDispatcher,
        // and ChainlinkPriceFeedV1R1 is using Chainlink aggregator's decimals which is 8
        IPriceFeed quoteUsdPriceFeed = IPriceFeed(_quoteUsdPriceFeed);
        IPriceFeed baseUsdPriceFeed = IPriceFeed(_baseUsdPriceFeed);
        uint8 quoteUsdPriceFeedDecimals = quoteUsdPriceFeed.decimals();
        uint8 baseUsdPriceFeedDecimals = baseUsdPriceFeed.decimals();

        // CV_PFDNE: PriceFeed Decimals Not Equal
        require(
            quoteUsdPriceFeedDecimals == _CHAINLINK_AGGREGATOR_DECIMALS_8 &&
                quoteUsdPriceFeedDecimals == baseUsdPriceFeedDecimals,
            "CV_PFDNE"
        );

        uint256 quoteUsdIndexPrice = quoteUsdPriceFeed.getPrice(0);
        uint256 baseUsdIndexPrice = baseUsdPriceFeed.getPrice(0);
        uint256 chainedIndexPrice = baseUsdIndexPrice.mulDiv(10**_CHAINLINK_AGGREGATOR_DECIMALS_8, quoteUsdIndexPrice);

        return chainedIndexPrice;
    }

    //
    // INTERNAL NON-VIEW
    //

    /// @param totalSupply is cached before the redeemer's shares are burnt
    function _redeemByShares(uint256 shares, uint256 totalSupply) internal virtual returns (uint256 redeemed);

    /// @dev reduce position on perp, which settles funding & unrealizedPnl to owedRealizedPnl
    function _reducePerpPosition(uint256 reducePositionSizeAbs)
        internal
        virtual
        returns (uint256 perpBase, uint256 perpQuote);

    function _depositFor(address to, uint256 assets) internal returns (uint256 shares) {
        _requireUint256GreaterThanZero(assets);

        address msgSender = _msgSender();

        // CV_SRNE: shower room not empty
        if (_showerRoom.isContract() && !IShowerRoom(_showerRoom).isNextDepositIndexEndOfWaitList()) {
            require(msgSender == _showerRoom, "CV_SRNE");
        }

        // calculate shares first as the below transferFrom() changes totalAssets()
        shares = _convertToShares(assets);

        SafeERC20Upgradeable.safeTransferFrom(IERC20Metadata(_getAsset()), msgSender, address(this), assets);

        IVaultToken(_vaultToken).mint(to, shares);
        emit Deposit(to, assets, shares);

        return shares;
    }

    function _openPerpPosition(InternalOpenPerpPositionParams memory params)
        internal
        returns (uint256 perpBase, uint256 perpQuote)
    {
        (uint256 amountIn, uint256 amountOutMinimum) = _formatSwapExactInputFromSpotToPerp(
            params.spotIn,
            params.spotOutMinimum,
            params.isBaseToQuote
        );

        IPerpPositionManager perp = IPerpPositionManager(_perpPositionManager);
        if (!params.isBaseToQuote) {
            // if tokenIn is quoteToken, deposit it anyway as it's perp's settlement token
            perp.deposit(_quoteToken, params.spotIn);
        }

        // tx can be reverted with "CH_NEFCI" if there's no enough freeCollateral, i.e.
        // no enough quoteToken, since quoteToken will always be deposited in the above step
        (perpBase, perpQuote) = perp.openPosition(
            IPerpPositionManager.OpenPositionFullParams({
                isBaseToQuote: params.isBaseToQuote,
                isExactInput: true,
                amount: amountIn,
                oppositeAmountBound: amountOutMinimum,
                deadline: params.deadline,
                sqrtPriceLimitX96: params.sqrtPriceLimitX96
            })
        );

        // ensure vault only has the right side of the position
        _getPerpPositionSizeSafe();
        return (perpBase, perpQuote);
    }

    function _redeemPerpPositionByShares(uint256 shares, uint256 totalSupply)
        internal
        returns (uint256 usdcWithdrawnFromPerp_6)
    {
        int256 perpPositionSize = _getPerpPositionSizeSafe();
        uint256 reducedPositionSizeAbs = perpPositionSize.abs().mulDiv(shares, totalSupply);

        IPerpPositionManager perp = IPerpPositionManager(_perpPositionManager);

        int256 accountValueBefore_6 = perp.getAccountValueSafe_6();
        // accountValueDiff is the diff between realizedPnl & unrealizedPnl after reducing position
        int256 accountValueDiff_6;

        // if reducedPositionSizeAbs == 0, will encounter error 'AS' in UniswapV3Pool
        if (reducedPositionSizeAbs > 0) {
            _reducePerpPosition(reducedPositionSizeAbs);
            // 1. funding isn't included as it's already in accountValueBefore
            // 2. diff between accountValue before & now is the extra pnl caused by mark & market price inconsistency
            accountValueDiff_6 = perp.getAccountValueSafe_6().sub(accountValueBefore_6);
        }

        // the extra pnl (accountValueDiff) belongs to the redeemer only and thus the redeemer gets shares + extra pnl
        usdcWithdrawnFromPerp_6 = accountValueBefore_6
            .mulDiv(shares.toInt256(), totalSupply)
            .add(accountValueDiff_6)
            .toUint256();

        // withdraw from perp; tx can fail if margin ratio is too low
        perp.withdraw(_quoteToken, usdcWithdrawnFromPerp_6);

        return usdcWithdrawnFromPerp_6;
    }

    // TODO: add slippage protection, just in case we set a low liquidity pool unintentionally
    function _swapExactInputOnUni(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        return
            IRouter(_router).uniswapV3ExactInput(
                IRouterStruct.UniswapV3ExactInputParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: 0
                })
            );
    }

    //
    // INTERNAL VIEW
    //

    function _getAsset() internal view virtual returns (address);

    function _getAssetDecimals() internal view virtual returns (uint8);

    function _getPerpPositionSizeSafe() internal view virtual returns (int256);

    /// @dev get quote & base token balance * share ratio
    function _getBalancesByShares(uint256 shares, uint256 totalSupply)
        internal
        view
        returns (uint256 quoteByShares_6, uint256 baseByShares)
    {
        return (
            IERC20Metadata(_quoteToken).balanceOf(address(this)).mulDiv(shares, totalSupply),
            IERC20Metadata(_baseToken).balanceOf(address(this)).mulDiv(shares, totalSupply)
        );
    }

    function _requireTokens(address tokenIn, address tokenOut) internal view {
        // CV_ITI: invalid tokenIn
        require(tokenIn == _quoteToken || tokenIn == _baseToken, "CV_ITI");
        // CV_ITO: invalid tokenOut
        require(tokenOut == _quoteToken || tokenOut == _baseToken, "CV_ITO");
        // CV_ITP: invalid token pair
        require(tokenIn != tokenOut, "CV_ITP");
    }

    function _requireIsWhitelistedArbitrageur(address account) internal view {
        // CV_IARB: invalid arbitrageur
        require(IVaultConfig(_vaultConfig).isWhitelistedArbitrageur(account), "CV_IARB");
    }

    function _requireMarginRatioGreaterThanSwapRestriction() internal view {
        // CV_MIBS: margin insufficient before swap
        require(
            IPerpPositionManager(_perpPositionManager).isMarginSufficientByRatio(
                IVaultConfig(_vaultConfig).getSwapRestrictionMarginRatio(address(this))
            ),
            "CV_MIBS"
        );
    }

    function _requireMarginRatioGreaterThanDeleverage() internal view {
        // CV_MIAS: margin insufficient after swap
        require(
            IPerpPositionManager(_perpPositionManager).isMarginSufficientByRatio(
                IVaultConfig(_vaultConfig).getDeleverageMarginRatio(address(this))
            ),
            "CV_MIAS"
        );
    }

    function _getDecimalsSafe(address token) internal view returns (uint8) {
        uint8 decimals = IERC20Metadata(token).decimals();

        // CV_ID: invalid decimals
        require(decimals > 0 && decimals <= 18, "CV_ID");
        return decimals;
    }

    function _getTotalSupply() internal view returns (uint256) {
        return IERC20Metadata(_vaultToken).totalSupply();
    }

    /// @dev must calculate before updating totalSupply and totalAssets
    function _convertToShares(uint256 assets) internal view returns (uint256) {
        // vaultTokenDecimals = 36 or 24 (or others, we didn't restrict it inside the contract),
        // assetsDecimals = underlying asset = USDC(6) or wETH(18) or wBTC(8)
        // if vaultTokenDecimals ~= assetsDecimals, hacker can do inflation attack easily
        uint256 totalSupply = _getTotalSupply();
        return
            totalSupply == 0
                ? assets.mul(10**(IERC20Metadata(_vaultToken).decimals() - _getAssetDecimals()))
                : assets.mulDiv(totalSupply, totalAssets());
    }

    function _formatBaseToPerpDecimals(uint256 base) internal view returns (uint256) {
        return _formatDecimals(base, _baseTokenDecimals, _PERP_DECIMALS_18);
    }

    function _formatQuoteToPerpDecimals(uint256 quote) internal view returns (uint256) {
        return _formatDecimals(quote, _quoteTokenDecimals, _PERP_DECIMALS_18);
    }

    function _formatPerpToBaseDecimals(uint256 perp) internal view returns (uint256) {
        return _formatDecimals(perp, _PERP_DECIMALS_18, _baseTokenDecimals);
    }

    function _formatPerpToQuoteDecimals(uint256 perp) internal view returns (uint256) {
        return _formatDecimals(perp, _PERP_DECIMALS_18, _quoteTokenDecimals);
    }

    function _formatSwapExactInputFromSpotToPerp(
        uint256 spotAmountIn,
        uint256 spotAmountOutMinimum,
        bool isBaseToQuote
    ) internal view returns (uint256 perpAmountIn, uint256 perpAmountOutMinimum) {
        if (isBaseToQuote) {
            // amountIn = base
            perpAmountIn = _formatBaseToPerpDecimals(spotAmountIn);

            // amountOut = quote
            perpAmountOutMinimum = _formatQuoteToPerpDecimals(spotAmountOutMinimum);
        } else {
            // amountIn = quote
            perpAmountIn = _formatQuoteToPerpDecimals(spotAmountIn);

            // amountOut = base
            perpAmountOutMinimum = _formatBaseToPerpDecimals(spotAmountOutMinimum);
        }
        return (perpAmountIn, perpAmountOutMinimum);
    }

    //
    // INTERNAL PURE
    //

    function _requireUint256GreaterThanZero(uint256 uintArg) internal pure {
        // CV_ZU: zero uint
        require(uintArg > 0, "CV_ZU");
    }

    function _requireNonZeroAddress(address addressArg) internal pure {
        // CV_ZA: Zero Address
        require(addressArg != address(0), "CV_ZA");
    }

    function _formatDecimals(
        uint256 num,
        uint8 fromDecimals,
        uint8 toDecimals
    ) internal pure returns (uint256) {
        if (fromDecimals == toDecimals) {
            return num;
        }
        return
            fromDecimals >= toDecimals ? num / 10**(fromDecimals - toDecimals) : num * 10**(toDecimals - fromDecimals);
    }

    // copied from SettlementTokenMath.convertTokenDecimals()
    function _formatDecimals(
        int256 num,
        uint8 fromDecimals,
        uint8 toDecimals
    ) internal pure returns (int256) {
        if (fromDecimals == toDecimals) {
            return num;
        }

        if (fromDecimals < toDecimals) {
            return num.mul(int256(10**(toDecimals - fromDecimals)));
        }

        uint256 denominator = 10**(fromDecimals - toDecimals);
        int256 rounding = 0;
        if (num < 0 && uint256(-num) % denominator != 0) {
            rounding = -1;
        }
        return num.div(int256(denominator)).add(rounding);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { ICommonVaultEvent } from "./ICommonVaultEvent.sol";
import { ICommonVaultStruct } from "./ICommonVaultStruct.sol";

interface ICommonVault is ICommonVaultStruct, ICommonVaultEvent {
    /**
     * @notice Deposits an amount of assets into the vault and mints the according amount of shares
     * @param amount The amount of assets to deposit
     * @return shares The amount of shares minted in VaultToken's decimals
     */
    function deposit(uint256 amount) external returns (uint256 shares);

    /**
     * @param to the receiver of shares
     */
    function depositFor(address to, uint256 amount) external returns (uint256 shares);

    /**
     * @notice Redeems an amount of shares from the vault and returns the according amount of assets
     * @dev if redeemed shares are too small compared to VaultToken's totalSupply, there's a chance
     *       that the proportion of the user is also too small s.t. 0 asset is returned to the user
     * @param shares The amount of shares to redeem in VaultToken's decimals
     * @return The amount of assets redeemed
     */
    function redeem(uint256 shares, uint256 minRedeemedAmount) external returns (uint256);

    /**
     * @notice Swaps an exact amount of input asset for as much output asset as possible
     * @param params The parameters for the swap
     * @return The amount of output asset received
     */
    function swapExactInput(SwapExactInputParams calldata params) external returns (uint256);

    /**
     * @notice Swaps an exact amount of output asset for as little input asset as possible
     * @param params The parameters for the swap
     * @return The amount of input asset spent
     */
    function swapExactOutput(SwapExactOutputParams calldata params) external returns (uint256);

    /**
     * @notice Reduces the size of the position held in the vault
     * @param reducedPositionSizeAbs The absolute amount of position size to be reduced
     * @return pnl The realized profit and loss denominated in the vault's _getAsset() token
     */
    function deleverage(uint256 reducedPositionSizeAbs) external returns (int256 pnl);

    /**
     * @notice Returns the total assets held in the vault
     * @dev denominated in the vault's _getAsset() token
     */
    function totalAssets() external view returns (uint256);

    /**
     * @notice Returns the address of router
     */
    function getRouter() external view returns (address);

    /**
     * @notice Returns the address of QUOTE/USD priceFeed (QUOTE: USDC)
     */
    function getQuoteUsdPriceFeed() external view returns (address);

    /**
     * @notice Returns the address of BASE/USD priceFeed (BASE: ETH, OP, etc.)
     */
    function getBaseUsdPriceFeed() external view returns (address);

    /**
     * @notice Returns the index price in QuoteToken
     */
    function getIndexPrice() external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

interface ICommonVaultEvent {
    /**
     * @dev Emitted when a deposit is made to the Common Vault
     * @param sender The address of the depositor
     * @param assets The amount of assets deposited
     * @param shares The amount of shares minted in VaultToken's decimals
     */
    event Deposit(address indexed sender, uint256 assets, uint256 shares);

    /**
     * @dev Emitted when a redemption is made from the Common Vault
     * @param sender The address of the redeemer
     * @param assets The amount of assets redeemed
     * @param shares The amount of shares burned  in VaultToken's decimals
     */
    event Redeem(address indexed sender, uint256 assets, uint256 shares);

    /**
     * @dev Emitted when a token swap is made by the Common Vault
     * @param sender The address of the sender
     * @param tokenIn The address of the input token
     * @param tokenOut The address of the output token
     * @param amountIn The amount of input token
     * @param amountOut The amount of output token
     * @param to The address receiving the swapped tokens
     * @param fee The fee of this swap
     */
    event Swap(
        address indexed sender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to,
        uint256 fee
    );

    /**
     * @dev Emitted when Common Vault is deleveraged
     * @param keeper The address of the keeper initiating the deleverage
     * @param baseToken The address of the base token
     * @param reducedPositionSizeAbs Absolute value of the reduced position size
     * @param base The amount of the base token
     * @param quote The amount of the quote token
     * @param soldSpotNotional Notional value of the spot sold
     * @param pnl Realized profit and loss denominated in the vault's _getAsset() token
     */
    event Deleverage(
        address indexed keeper,
        address indexed baseToken,
        uint256 reducedPositionSizeAbs,
        uint256 base,
        uint256 quote,
        uint256 soldSpotNotional,
        int256 pnl
    );

    event UpdateRouterAddress(address oldRouter, address newRouter);

    event UpdateQuoteUsdPriceFeed(address oldQuoteUsdPriceFeed, address newQuoteUsdPriceFeed);

    event UpdateBaseUsdPriceFeed(address oldBaseUsdPriceFeed, address newBaseUsdPriceFeed);

    event UpdateShowerRoom(address showerRoom);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.6;

interface ICommonVaultStruct {
    /// @param sqrtPriceLimitX96OnPerp square root price limit scaled by 2^96 of Perp, not Uni spot
    struct SwapExactInputParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96OnPerp;
    }

    /// @param sqrtPriceLimitX96OnPerp square root price limit scaled by 2^96 of Perp, not Uni spot
    struct SwapExactOutputParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96OnPerp;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { IPerpPositionManagerEvent } from "./IPerpPositionManagerEvent.sol";

interface IPerpPositionManager is IPerpPositionManagerEvent {
    struct OpenPositionParams {
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
    }

    /// @param sqrtPriceLimitX96 square root price limit scaled by 2^96 of Perp, not Uni spot
    struct OpenPositionFullParams {
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
        uint160 sqrtPriceLimitX96;
    }

    function deposit(address token, uint256 amount) external;

    function withdraw(address token, uint256 amount) external;

    function openPosition(OpenPositionParams memory) external returns (uint256 base, uint256 quote);

    function openPosition(OpenPositionFullParams memory) external returns (uint256 base, uint256 quote);

    function getCaller() external view returns (address);

    function getBaseToken() external view returns (address);

    function getSettlementToken() external view returns (address);

    function getTakerPositionSize() external view returns (int256 takerPositionSize);

    /// @dev there's a `Safe` suffix means the value is required to be >= 0
    function getAccountValueSafe_6() external view returns (int256);

    function getMarkPrice() external view returns (uint256);

    function isMarginSufficientByRatio(uint24 ratio) external view returns (bool);

    function getDeleveragedPositionSize(uint24 targetMarginRatio) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

interface IPerpPositionManagerEvent {
    event UpdateCaller(address oldCaller, address newCaller);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { IRouterEvent } from "./IRouterEvent.sol";
import { IRouterStruct } from "./IRouterStruct.sol";

interface IRouter is IRouterEvent, IRouterStruct {
    function uniswapV3ExactInput(IRouterStruct.UniswapV3ExactInputParams memory params)
        external
        returns (uint256 amountOut);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

interface IRouterEvent {
    /**
     * @dev Emitted when UniswapV3 multihop path of tokenIn/tokenOut pair is changed
     * @param tokenIn The address of tokenIn
     * @param tokenOut The address of tokenOut
     * @param oldPath The old UniswapV3 multihop path
     * @param newPath The new UniswapV3 multihop path
     */
    event UpdateUniswapV3Path(address tokenIn, address tokenOut, bytes oldPath, bytes newPath);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

interface IRouterStruct {
    struct UniswapV3ExactInputParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { IShowerRoomEvent } from "./IShowerRoomEvent.sol";
import { IShowerRoomStruct } from "./IShowerRoomStruct.sol";

interface IShowerRoom is IShowerRoomStruct, IShowerRoomEvent {
    function deposit(uint256) external;

    /**
     * @param maxSkipped # of for loop runs limit
     * @return shares in Kantaban vault
     */
    function pushToKantaban(uint256 maxSkipped) external returns (uint256 shares);

    function withdrawAll() external returns (uint256 totalAssetsWithdrawn);

    function getAsset() external view returns (address);

    function getKantabanVault() external view returns (address);

    /**
     * @dev yearnVault can be zero address, meaning that there's no Yearn Vault available
     */
    function getYearnVault() external view returns (address);

    /**
     * @dev yearnStakingRewards can be zero address, meaning that there's no Yearn StakingRewards available
     */
    function getYearnStakingRewards() external view returns (address);

    /**
     * @dev yearnStakingRewardsVault can be zero address, meaning that there's no Yearn StakingRewards available
     */
    function getYearnStakingRewardsVault() external view returns (address);

    /**
     * @dev router can be zero address, meaning that there's no Yearn StakingRewards available and thus
     *      don't need to swap staking rewards to asset
     * @dev this is not Uniswap's official router, but a router written by us
     */
    function getRouter() external view returns (address);

    function getPusher() external view returns (address);

    /**
     * @dev maxDepositPerUser can be zero, meaning that deposit to Kantaban is forbidden
     */
    function getMaxDepositPerUser() external view returns (uint256);

    function getUser(address) external view returns (User calldata);

    function getNextDepositIndex() external view returns (uint256);

    /**
     * @dev this does not necessarily mean wait list is empty if all user in the wait list withdraw
     *      (without BE calling pushToKantaban)
     *      1. default: _nextDepositIndex == 0, _waitListArray.length == 0
     *      2. if Shower Room is pushed to the latest: _nextDepositIndex == _waitListArray.length
     */
    function isNextDepositIndexEndOfWaitList() external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

interface IShowerRoomEvent {
    event AddToWaitList(
        address indexed sender,
        uint256 waitListIndex,
        uint256 amountIn,
        uint256 yvTokenAmountIn,
        uint256 stakingRewardPerToken,
        uint256 pendingStakingRewards
    );

    /**
     * @param yvStakingRewards not the same asset as yvTokenWithdrawn,
     *                         e.g. yvTokenWithdrawn = yvUSDC, yvStakingRewards = yvOP
     * @param stakingRewards withdrawn from yvStakingRewards
     */
    event PushToKantaban(
        address indexed account,
        uint256 waitListIndex,
        uint256 depositedToKantaban,
        uint256 shares,
        uint256 yvTokenWithdrawn,
        uint256 assetsWithdrawnFromYearnVault,
        uint256 yvStakingRewards,
        uint256 stakingRewards,
        uint256 assetsSwappedFromRewards
    );

    /**
     * @param assetsSwappedFromRewards identical to stakingRewards if stakingRewards token == _asset
     */
    event Withdraw(
        address indexed account,
        uint256 totalAssetsWithdrawn,
        uint256 yvTokenWithdrawn,
        uint256 assetsWithdrawnFromYearnVault,
        uint256 yvStakingRewards,
        uint256 stakingRewards,
        uint256 assetsSwappedFromRewards
    );

    event UpdateYearnVault(address);

    event UpdateYearnStakingRewards(address);

    event UpdateYearnStakingRewardsVault(address);

    event UpdateRouter(address);

    event UpdatePusher(address);

    event UpdateMaxDepositPerUser(uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

interface IShowerRoomStruct {
    struct User {
        uint256 waitListIndex;
        uint256 amountIn;
        uint256 yvTokenAmountIn;
        uint256 stakingRewardPerToken;
        uint256 pendingStakingRewards;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

interface IVaultConfig {
    /**
     * @notice Returns true if the provided address is a whitelisted liquidity provider
     */
    function isWhitelistedLiquidityProvider(address account) external view returns (bool);

    /**
     * @notice Returns true if the provided address is a whitelisted arbitrageur
     */
    function isWhitelistedArbitrageur(address account) external view returns (bool);

    /**
     * @notice Returns the address of whitelistedLiquidityProviderAdder
     */
    function getWhitelistedLiquidityProviderAdder() external view returns (address);

    /**
     * @notice Returns the margin ratio when Vault should be deleveraged
     */
    function getDeleverageMarginRatio() external view returns (uint24);

    /**
     * @notice Returns the margin ratio when Vault should be deleveraged
     */
    function getDeleverageMarginRatio(address vault) external view returns (uint24);

    /**
     * @notice Returns the margin ratio when swap is restricted/stopped
     */
    function getSwapRestrictionMarginRatio() external view returns (uint24);

    /**
     * @notice Returns the margin ratio when swap is restricted/stopped
     */
    function getSwapRestrictionMarginRatio(address vault) external view returns (uint24);

    /**
     * @notice Returns the exchange fee of a vault
     */
    function getExchangeFeeRatio(address vault) external view returns (uint24 feeRatio);

    /**
     * @notice Returns the discount ratio of a trader
     */
    function getFeeDiscountRatio(address trader) external view returns (uint24 discountRatio);

    /**
     * @notice Returns the exchange fee ratio when given a vault and a trader
     */
    function getExchangeFeeRatioByTrader(address trader, address vault) external view returns (uint24);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IVaultToken is IERC20Upgradeable {
    function mint(address account, uint256 amount) external;

    function burn(address account, uint256 amount) external;

    /**
     * @notice Returns the cooldown time for asset transfers in seconds
     */
    function getTransferCooldown() external view returns (uint24);

    function getTotalSupplyCap() external view returns (uint256);

    function getMinter() external view returns (address);

    function getLastMintedAt(address account) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

/// @notice For future upgrades, do not change CommonVaultStorageV1. Create a new
/// contract which implements CommonVaultStorageV1 and following the naming convention
/// CommonVaultStorageVX.
abstract contract CommonVaultStorageV1 {
    address internal _vaultToken;
    address internal _quoteToken;
    address internal _baseToken;
    address internal _vaultConfig;
    address internal _perpPositionManager;

    // NOTE: UniswapV3 related storage are deprecated (moved to Router)
    address internal _uniswapV3Router;
    address internal _uniswapV3Factory;
    uint24 internal _uniswapV3DefaultFeeTier;

    uint8 internal _quoteTokenDecimals;
    uint8 internal _baseTokenDecimals;
}

abstract contract CommonVaultStorageV2 is CommonVaultStorageV1 {
    address internal _router;
    address internal _quoteUsdPriceFeed;
    address internal _baseUsdPriceFeed;
}

abstract contract CommonVaultStorageV3 is CommonVaultStorageV2 {
    address internal _showerRoom;
}