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
pragma abicoder v2;

import { PerpSafeCast } from "@perp/curie-contract/contracts/lib/PerpSafeCast.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import { IVaultConfig } from "./interface/IVaultConfig.sol";

import { OwnerPausable } from "@perp/curie-contract/contracts/base/OwnerPausable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { ShowerRoomStorageV1 } from "./storage/ShowerRoomStorage.sol";
import { AddressUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import { IERC20Metadata } from "@perp/curie-contract/contracts/interface/IERC20Metadata.sol";
import { IRouter } from "./interface/IRouter.sol";
import { IRouterStruct } from "./interface/IRouterStruct.sol";
import { ICommonVault } from "./interface/ICommonVault.sol";
import { IShowerRoom } from "./interface/IShowerRoom.sol";
import { IYearnVault } from "./interface/IYearnVault.sol";
import { IYearnStakingRewards } from "./interface/IYearnStakingRewards.sol";
import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import { SafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

contract ShowerRoom is IShowerRoom, OwnerPausable, ReentrancyGuardUpgradeable, ShowerRoomStorageV1 {
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    //
    // EXTERNAL NON-VIEW
    //

    function initialize(address kantabanVaultArg, address assetArg) external initializer {
        __OwnerPausable_init();
        __ReentrancyGuard_init();

        // SR_KVNC: kantabanVault is not a contract
        require(kantabanVaultArg.isContract(), "SR_KVNC");
        _kantabanVault = kantabanVaultArg;

        // SR_ANC: asset is not a contract
        require(assetArg.isContract(), "SR_ANC");
        _asset = assetArg;

        IERC20Metadata(assetArg).approve(kantabanVaultArg, type(uint256).max);
    }

    function setYearnVault(address yearnVaultArg) external onlyOwner {
        if (yearnVaultArg != address(0)) {
            // SR_AM: asset mismatched
            require(IYearnVault(yearnVaultArg).token() == _asset, "SR_AM");
        }

        _yearnVault = yearnVaultArg;
        emit UpdateYearnVault(yearnVaultArg);
    }

    function setYearnStakingRewards(address yearnStakingRewardsArg) external onlyOwner {
        _yearnStakingRewards = yearnStakingRewardsArg;
        emit UpdateYearnStakingRewards(yearnStakingRewardsArg);
    }

    function setYearnStakingRewardsVault(address yearnStakingRewardsVaultArg) external onlyOwner {
        _yearnStakingRewardsVault = yearnStakingRewardsVaultArg;
        emit UpdateYearnStakingRewardsVault(yearnStakingRewardsVaultArg);
    }

    function setRouter(address routerArg) external onlyOwner {
        _router = routerArg;
        emit UpdateRouter(routerArg);
    }

    function setPusher(address pusherArg) external onlyOwner {
        _pusher = pusherArg;
        emit UpdatePusher(pusherArg);
    }

    function setMaxDepositPerUser(uint256 maxDepositPerUserArg) external onlyOwner {
        _maxDepositPerUser = maxDepositPerUserArg;
        emit UpdateMaxDepositPerUser(maxDepositPerUserArg);
    }

    /// @inheritdoc IShowerRoom
    function deposit(uint256 amountIn) external override whenNotPaused nonReentrant {
        _requireUint256GreaterThanZero(amountIn);

        address msgSender = _msgSender();
        SafeERC20Upgradeable.safeTransferFrom(IERC20Metadata(_asset), msgSender, address(this), amountIn);

        _userMap[msgSender].amountIn = _userMap[msgSender].amountIn.add(amountIn);
        // active wait list is from _nextDepositIndex ~ _waitListArray.length
        // if user's waitListIndex is not in this range, we treat him as a new user
        if (_userMap[msgSender].waitListIndex >= _nextDepositIndex) {
            // user is in the wait list
            if (!_isZeroAddress(_yearnVault)) {
                (uint256 pendingStakingRewards, ) = _getStakingRewards(msgSender);
                // stakingRewardPerToken will be updated in _depositAndStakeToYearn()
                _userMap[msgSender].pendingStakingRewards = pendingStakingRewards;
                _depositAndStakeToYearn(msgSender, amountIn);
            }
        } else {
            // new user or all user's funds are in Kantaban already
            if (!_isZeroAddress(_yearnVault)) {
                _depositAndStakeToYearn(msgSender, amountIn);
            }
        }
        _addToWaitList(msgSender);
    }

    /// @inheritdoc IShowerRoom
    function pushToKantaban(uint256 maxSkipped) external override whenNotPaused nonReentrant returns (uint256) {
        // SR_CNP: caller not pusher
        require(_msgSender() == _pusher, "SR_CNP");

        address account;
        User memory user;
        uint256 i;
        // the last user's waitListIndex will always == _waitListArray.length - 1 and thus for loop won't overflow
        // because it will always break on line 110
        for (i = 0; i < maxSkipped; i++) {
            account = _waitListArray[_nextDepositIndex];
            user = _userMap[account];
            _nextDepositIndex++;
            if (user.waitListIndex == _nextDepositIndex - 1 && (user.amountIn > 0 || user.yvTokenAmountIn > 0)) {
                break;
            }
        }
        if (i == maxSkipped) {
            return 0;
        }

        uint256 depositedToKantaban;

        uint256 yvTokenWithdrawn;
        uint256 assetsWithdrawnFromYearnVault;

        uint256 yvStakingRewards;
        uint256 stakingRewards;
        uint256 assetsSwappedFromRewards;
        // 1. if NO Yearn, deposit _maxDepositPerUser in user.amountIn to Kantaban directly
        // 2. if Yearn but user has inactive funds in user.amountIn, prioritize using it to deposit
        //    a. user.amountIn >= _maxDepositPerUser: use _maxDepositPerUser in user.amountIn (same impl. as 1)
        //    b. user.amountIn < _maxDepositPerUser: withdraw from yearn (if user.yvTokenAmountIn > 0)
        // 3. if Yearn but all assets are in Yearn, then simply withdraw from yearn (same impl. as 2.b)
        if (_isZeroAddress(_yearnVault) || user.amountIn >= _maxDepositPerUser) {
            depositedToKantaban = MathUpgradeable.min(_maxDepositPerUser, user.amountIn);
            _userMap[account].amountIn = user.amountIn.sub(depositedToKantaban);
        } else {
            (user, yvStakingRewards, stakingRewards, assetsSwappedFromRewards) = _withdrawAndSwapStakingRewards(
                account
            );

            uint256 pricePerShare = IYearnVault(_yearnVault).pricePerShare();
            // pricePerShare already multiplied _yearVault.decimals so need to divide it
            uint256 maxYvTokenWithdrawn = _maxDepositPerUser
                .sub(user.amountIn)
                .mul(10**IYearnVault(_yearnVault).decimals())
                .div(pricePerShare);
            yvTokenWithdrawn = MathUpgradeable.min(maxYvTokenWithdrawn, user.yvTokenAmountIn);

            user.yvTokenAmountIn = user.yvTokenAmountIn.sub(yvTokenWithdrawn);
            assetsWithdrawnFromYearnVault = _unstakeAndWithdrawFromYearnVault(yvTokenWithdrawn);

            // min() again to assure the amount won't exceed _maxDepositPerUser and tx gets reverted
            depositedToKantaban = MathUpgradeable.min(
                user.amountIn.add(assetsWithdrawnFromYearnVault),
                _maxDepositPerUser
            );
            user.amountIn = user.amountIn.add(assetsWithdrawnFromYearnVault).sub(depositedToKantaban);

            _userMap[account] = user;
        }

        // depositFor user to Kantaban
        uint256 shares = ICommonVault(_kantabanVault).depositFor(account, depositedToKantaban);

        emit PushToKantaban(
            account,
            _userMap[account].waitListIndex,
            depositedToKantaban,
            shares,
            yvTokenWithdrawn,
            assetsWithdrawnFromYearnVault,
            yvStakingRewards,
            stakingRewards,
            assetsSwappedFromRewards
        );

        if (_userMap[account].amountIn > 0 || _userMap[account].yvTokenAmountIn > 0) {
            _addToWaitList(account);
        }

        return shares;
    }

    /// @inheritdoc IShowerRoom
    function withdrawAll() external override whenNotPaused nonReentrant returns (uint256) {
        address msgSender = _msgSender();

        uint256 yvTokenWithdrawn;
        uint256 assetsWithdrawnFromYearnVault;

        uint256 yvStakingRewards;
        uint256 stakingRewards;
        uint256 assetsSwappedFromRewards;
        if (!_isZeroAddress(_yearnVault)) {
            User memory user;
            (user, yvStakingRewards, stakingRewards, assetsSwappedFromRewards) = _withdrawAndSwapStakingRewards(
                msgSender
            );

            yvTokenWithdrawn = user.yvTokenAmountIn;
            user.yvTokenAmountIn = 0;
            assetsWithdrawnFromYearnVault = _unstakeAndWithdrawFromYearnVault(yvTokenWithdrawn);
            user.amountIn = user.amountIn.add(assetsWithdrawnFromYearnVault);

            _userMap[msgSender] = user;
        }

        uint256 totalAssetsWithdrawn = _userMap[msgSender].amountIn;
        _userMap[msgSender].amountIn = 0;

        SafeERC20Upgradeable.safeTransfer(IERC20Metadata(_asset), msgSender, totalAssetsWithdrawn);

        emit Withdraw(
            msgSender,
            totalAssetsWithdrawn,
            yvTokenWithdrawn,
            assetsWithdrawnFromYearnVault,
            yvStakingRewards,
            stakingRewards,
            assetsSwappedFromRewards
        );

        return totalAssetsWithdrawn;
    }

    //
    // EXTERNAL VIEW
    //

    /// @inheritdoc IShowerRoom
    function getAsset() external view override returns (address) {
        return _asset;
    }

    /// @inheritdoc IShowerRoom
    function getKantabanVault() external view override returns (address) {
        return _kantabanVault;
    }

    /// @inheritdoc IShowerRoom
    function getYearnVault() external view override returns (address) {
        return _yearnVault;
    }

    /// @inheritdoc IShowerRoom
    function getYearnStakingRewards() external view override returns (address) {
        return _yearnStakingRewards;
    }

    /// @inheritdoc IShowerRoom
    function getYearnStakingRewardsVault() external view override returns (address) {
        return _yearnStakingRewardsVault;
    }

    /// @inheritdoc IShowerRoom
    function getRouter() external view override returns (address) {
        return _router;
    }

    /// @inheritdoc IShowerRoom
    function getPusher() external view override returns (address) {
        return _pusher;
    }

    /// @inheritdoc IShowerRoom
    function getMaxDepositPerUser() external view override returns (uint256) {
        return _maxDepositPerUser;
    }

    /// @inheritdoc IShowerRoom
    function getUser(address user) external view override returns (User memory) {
        return _userMap[user];
    }

    /// @inheritdoc IShowerRoom
    function getNextDepositIndex() external view override returns (uint256) {
        return _nextDepositIndex;
    }

    /// @inheritdoc IShowerRoom
    function isNextDepositIndexEndOfWaitList() external view override returns (bool) {
        return _nextDepositIndex == _waitListArray.length;
    }

    //
    // INTERNAL NON-VIEW
    //

    /**
     * @dev 1. before calling this function, user's struct should be up-to-date/ready to be pushed to waitList
     * @dev 2. this is NOT a state changing function; Yearn-related storage states are NOT updated here
     */
    function _depositAndStakeToYearn(address account, uint256 amountIn) internal {
        User memory user = _userMap[account];
        user.amountIn = user.amountIn.sub(amountIn);

        // deposit to yearn
        IERC20Metadata(_asset).approve(_yearnVault, amountIn);
        uint256 yvTokenAmountIn = IYearnVault(_yearnVault).deposit(amountIn, address(this));
        user.yvTokenAmountIn = user.yvTokenAmountIn.add(yvTokenAmountIn);

        if (!_isZeroAddress(_yearnStakingRewards)) {
            // stake yvToken
            IERC20Metadata(_yearnVault).approve(_yearnStakingRewards, yvTokenAmountIn);
            IYearnStakingRewards(_yearnStakingRewards).stake(yvTokenAmountIn);
            user.stakingRewardPerToken = IYearnStakingRewards(_yearnStakingRewards).rewardPerToken();
        }
        _userMap[account] = user;
    }

    /**
     * @dev 1. before calling this function, user's struct should be up-to-date/ready to be pushed to waitList
     * @dev 2. this is NOT a state changing function; Yearn-related storage states are NOT updated here
     */
    function _withdrawAndSwapStakingRewards(address account)
        internal
        returns (
            User memory,
            uint256 yvStakingRewards,
            uint256 stakingRewards,
            uint256 assetsSwappedFromRewards
        )
    {
        User memory user = _userMap[account];
        if (!_isZeroAddress(_yearnStakingRewards)) {
            IYearnStakingRewards(_yearnStakingRewards).getReward();

            (yvStakingRewards, user.stakingRewardPerToken) = _getStakingRewards(account);
            user.pendingStakingRewards = 0;

            if (yvStakingRewards > 0) {
                // approve and withdraw from yvOP vault to get OP
                stakingRewards = _approveAndWithdrawFromYearnVault(_yearnStakingRewardsVault, yvStakingRewards);

                // swap OP to asset
                assetsSwappedFromRewards = _approveAndSwapOnUni(
                    IYearnVault(_yearnStakingRewardsVault).token(),
                    _asset,
                    stakingRewards
                );

                user.amountIn = user.amountIn.add(assetsSwappedFromRewards);
            }
        }
        return (user, yvStakingRewards, stakingRewards, assetsSwappedFromRewards);
    }

    function _unstakeAndWithdrawFromYearnVault(uint256 yvTokenWithdrawn) internal returns (uint256 assetsWithdrawn) {
        if (yvTokenWithdrawn > 0) {
            if (!_isZeroAddress(_yearnStakingRewards)) {
                // unstake
                IYearnStakingRewards(_yearnStakingRewards).withdraw(yvTokenWithdrawn);
            }
            assetsWithdrawn = _approveAndWithdrawFromYearnVault(_yearnVault, yvTokenWithdrawn);
        }
        return assetsWithdrawn;
    }

    function _approveAndWithdrawFromYearnVault(address yearnVault, uint256 yvTokenAmountIn) internal returns (uint256) {
        IERC20Metadata(yearnVault).approve(yearnVault, yvTokenAmountIn);
        // 1 for the last param means there can be max .01% loss when withdrawing from Yearn
        return IYearnVault(yearnVault).withdraw(yvTokenAmountIn, address(this), 1);
    }

    /**
     * @dev before calling this function, user's struct should be up-to-date/ready to be pushed to waitList
     */
    function _addToWaitList(address account) internal {
        uint256 waitListIndex = _waitListArray.length;
        _waitListArray.push(account);
        _userMap[account].waitListIndex = waitListIndex;
        emit AddToWaitList(
            account,
            waitListIndex,
            _userMap[account].amountIn,
            _userMap[account].yvTokenAmountIn,
            _userMap[account].stakingRewardPerToken,
            _userMap[account].pendingStakingRewards
        );
    }

    function _approveAndSwapOnUni(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256) {
        if (tokenIn == tokenOut) {
            return amountIn;
        }
        IERC20Metadata(tokenIn).approve(_router, amountIn);
        return
            IRouter(_router).uniswapV3ExactInput(
                IRouterStruct.UniswapV3ExactInputParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: 0 // we don't set slippage protection for now
                })
            );
    }

    //
    // INTERNAL VIEW
    //

    /**
     * @dev 1. before calling this function, user's struct should be up-to-date/ready to be pushed to waitList
     * @dev 2. this is NOT a state changing function; Yearn-related storage states are NOT updated here
     */
    function _getStakingRewards(address account)
        internal
        view
        returns (uint256 pendingStakingRewards, uint256 stakingRewardPerToken)
    {
        User memory user = _userMap[account];
        if (user.stakingRewardPerToken > 0 && !_isZeroAddress(_yearnStakingRewards)) {
            stakingRewardPerToken = IYearnStakingRewards(_yearnStakingRewards).rewardPerToken();
            pendingStakingRewards = user.pendingStakingRewards.add(
                user.yvTokenAmountIn.mul(stakingRewardPerToken.sub(user.stakingRewardPerToken)).div(1e18)
            );
        }
        return (pendingStakingRewards, stakingRewardPerToken);
    }

    function _isZeroAddress(address addr) internal pure returns (bool) {
        return addr == address(0);
    }

    function _requireUint256GreaterThanZero(uint256 uintArg) internal pure {
        // SR_ZU: zero uint
        require(uintArg > 0, "SR_ZU");
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
     */
    event Swap(
        address indexed sender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to
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
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

interface IYearnStakingRewards {
    /**
     * @notice Deposits an amount of yvToken into yearn staking rewards
     * @param amount The amount of yvToken to stake
     */
    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function getReward() external;

    function rewardPerToken() external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

interface IYearnVault {
    /**
     * @notice Deposits an amount of assets into the vault and mints the according amount of shares
     * @param amount The amount of assets to deposit
     * @return shares The amount of shares minted in YearnVault
     */
    function deposit(uint256 amount, address recipient) external returns (uint256 shares);

    function withdraw(
        uint256 maxShares,
        address recipient,
        uint256 maxLoss
    ) external returns (uint256 redeemedTokenAmount);

    function pricePerShare() external returns (uint256);

    /**
     * @notice the underlying token deposited to the vault
     */
    function token() external returns (address);

    function decimals() external returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { IShowerRoomStruct } from "../interface/IShowerRoomStruct.sol";

/// @notice For future upgrades, do not change ShowerRoomStorageV1. Create a new
/// contract which implements ShowerRoomStorageV1 and following the naming convention
/// ShowerRoomStorageVX.
abstract contract ShowerRoomStorageV1 {
    address internal _kantabanVault;
    address internal _yearnVault; // e.g. usdc yearn vault
    address internal _yearnStakingRewards; // e.g. yvUsdc staking rewards
    address internal _yearnStakingRewardsVault; // e.g. yvOP yearn vault
    address internal _router;
    address internal _asset;
    address internal _pusher;

    uint256 internal _maxDepositPerUser;

    mapping(address => IShowerRoomStruct.User) internal _userMap;
    address[] internal _waitListArray;
    uint256 internal _nextDepositIndex;
}