// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/extensions/IERC20Metadata.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
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
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
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
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
import "../../../utils/Address.sol";

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
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
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
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

error InvalidInterval();
error InvalidMask();

error UnauthorizedCaller();
error ZeroAddress();

error HighPlatformFeeRatio();
error HighFee();
error InvalidToken();
error InvalidNoOfSwaps();

error InvalidPermitSender();
error InvalidPermitData();
error InvalidPermit();
error InvalidAmountTransferred();

error InvalidLength();
error NoAvailableSwap();
error InvalidSwapAmount();
error InvalidReturnAmount();
error SwapCallFailed();
error InvalidBlankSwap();

error InvalidPosition();
error InvalidNativeAmount();
error NotWNative();
error NativeTransferFailed();
error UnauthorizedTokens();
error InvalidTokens();
error InvalidAmount();
error UnauthorizedInterval();
error InvalidRate();
error NoChanges();
error ZeroSwappedTokens();

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @notice User position info
 * swapWhereLastUpdated: swaps at which position was last updated (create, modify, withdraw)
 * startingSwap: swap at position will start (1st swap = 0)
 * finalSwap: swap at the all the swaps for position will be finished
 * swapIntervalMask: How frequently the position's swaps should be executed
 * rate: How many "from" tokens need to be traded in each swap
 * from: The token that the user deposited and will be swapped in exchange for "to"
 * to: The token that the user will get in exchange for their "from" tokens in each swap
 * owner: address of position owner
 */
struct UserPosition {
    address owner;
    address from;
    address to;
    bytes1 swapIntervalMask;
    uint256 rate;
    uint256 swapWhereLastUpdated;
    uint256 startingSwap;
    uint256 finalSwap;
}

/**
 * @notice User position info
 * @dev to get more readable information
 * owner: address of position owner
 * from: The token that the user deposited and will be swapped in exchange for "to"
 * to: The token that the user will get in exchange for their "from" tokens in each swap
 * swapInterval: How frequently the position's swaps should be executed
 * rate: How many "from" tokens need to be traded in each swap
 * swapsExecuted: How many swaps were executed since creation, last modification, or last withdraw
 * swapsLeft: How many swaps left the position has to execute
 * swapped: How many to swaps are available to withdraw
 * unswapped:How many "from" tokens there are left to swap
 */
struct PositionInfo {
    address owner;
    address from;
    address to;
    uint32 swapInterval;
    uint256 rate;
    uint256 swapsExecuted;
    uint256 swapsLeft;
    uint256 swapped;
    uint256 unswapped;
}

/**
 * @notice Create Position Details
 * @dev Will be use in createPosition and createBatchPositions as input arg
 * @dev For Native token user NATIVE_TOKEN as address
 * from: The address of the "from" token
 * to: The address of the "to" token
 * swapInterval: How frequently the position's swaps should be executed
 * amount: How many "from" tokens will be swapped in total
 * noOfSwaps: How many swaps to execute for this position
 * permit: Permit callData, erc20Permit, daiPermit and permit2 are supported
 */
struct CreatePositionDetails {
    address from;
    address to;
    uint32 swapInterval;
    uint256 amount;
    uint256 noOfSwaps;
    bytes permit;
}

/**
 * @notice Swap information about a specific pair
 * performedSwaps: How many swaps have been executed
 * nextAmountToSwap: How much of "from" token will be swapped on the next swap
 * nextToNextAmountToSwap: How much of "from" token will be swapped on the nextToNext swap
 * lastSwappedAt: Timestamp of the last swap
 */
struct SwapData {
    uint256 performedSwaps;
    uint256 nextAmountToSwap;
    uint256 nextToNextAmountToSwap;
    uint256 lastSwappedAt;
}

/**
 * @notice Information about a swap
 * @dev totalAmount of "from" tokens used is equal swappedAmount + reward + fee
 * from: The address of the "from" token
 * to: The address of the "to" token
 * swappedAmount: The actual amount of "from" tokens that were swapped
 * receivedAmount:The actual amount of "tp" tokens that were received
 * reward: The amount of "from" token that were given as rewards
 * fee: The amount of "from" token that were given as fee
 * intervalsInSwap: The different interval for which swap has taken place
 */
struct SwapInfo {
    address from;
    address to;
    uint256 swappedAmount;
    uint256 receivedAmount;
    uint256 reward;
    uint256 fee;
    bytes1 intervalsInSwap;
}

/**
 * @notice Swap Details
 * @dev Will be use in swap as input arg
 * executor: DEX's or aggregator address
 * tokenProxy: Who should we approve the tokens to (as an example: Paraswap makes you approve one address and send data to other)
 * from: The address of the "from" token
 * to: The address of the "to" token
 * amount: The amount of "from" token which will be swapped (totalSwappedAmount - feeAmount)
 * minReturnAmount: Minimum amount of "to" token which will be received from swap
 * swapCallData: call to make to the dex
 */
struct SwapDetails {
    address executor;
    address tokenProxy;
    address from;
    address to;
    uint256 amount;
    uint256 minReturnAmount;
    bytes swapCallData;
}

/**
 * @notice A pair of tokens
 * from: The address of the "from" token
 * to: The address of the "to" token
 */
struct Pair {
    address from;
    address to;
}

enum PermitType {
    PERMIT2_APPROVE,
    PERMIT2_TRANSFER_FROM,
    PERMIT
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import "./DCAParameters.sol";
import "./../utils/Governable.sol";
import "./../libraries/Intervals.sol";
import "../interfaces/IDCAConfigHandler.sol";
import "./../interfaces/IWNative.sol";

import { ZeroAddress, InvalidInterval, HighFee, HighPlatformFeeRatio, InvalidToken, InvalidNoOfSwaps, InvalidLength } from "./../common/Error.sol";

abstract contract DCAConfigHandler is DCAParameters, Governable, Pausable, IDCAConfigHandler {
    bytes1 public allowedSwapIntervals;

    mapping(address => bool) public allowedTokens;
    mapping(address => uint256) public tokenMagnitude;
    mapping(address => bool) public admins;
    mapping(address => bool) public swapExecutors;
    mapping(bytes1 => uint256) internal _swapFeeMap;

    IWNative public immutable wNative;
    address public feeVault;

    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 public maxNoOfSwap;
    uint256 public nextToNextTimeThreshold = 10 minutes;
    uint256 public platformFeeRatio;
    uint256 public constant MAX_FEE = 1000; // 10%
    uint256 public constant MAX_PLATFORM_FEE_RATIO = 10000; // 100%
    uint256 public constant BPS_DENOMINATOR = 10000; // 2 point precision

    /* ========= CONSTRUCTOR ========= */

    constructor(address governor_, address wNative_, address feeVault_, uint256 maxNoOfSwap_) Governable(governor_) {
        if (feeVault_ == address(0) || wNative_ == address(0)) revert ZeroAddress();
        if (maxNoOfSwap_ < 2) revert InvalidNoOfSwaps(); 

        wNative = IWNative(wNative_);
        feeVault = feeVault_;
        maxNoOfSwap = maxNoOfSwap_;
    }

    /* ========== MODIFIERS ==========  */

    modifier onlyAdminOrGovernor() {
        if (!admins[_msgSender()] && _msgSender() != governance()) revert UnauthorizedCaller();
        _;
    }

    modifier onlySwapper() {
        if (!swapExecutors[_msgSender()]) revert UnauthorizedCaller();
        _;
    }

    /* ========= VIEWS ========= */

    function getSwapFee(uint32 interval_) external view returns (uint256) {
        return _swapFeeMap[Intervals.intervalToMask(interval_)];
    }

    /* ========= RESTRICTED FUNCTIONS ========= */

    function pause() external onlyGovernance {
        _pause();
    }

    function unpause() external onlyGovernance {
        _unpause();
    }

    function addAdmins(address[] calldata accounts_) external onlyGovernance {
        _setAdmin(accounts_, true);
        emit AdminAdded(accounts_);
    }

    function removeAdmins(address[] calldata accounts_) external onlyGovernance {
        _setAdmin(accounts_, false);
        emit AdminRemoved(accounts_);
    }

    function addSwapExecutors(address[] calldata executor_) external onlyGovernance {
        _setSwapExecutor(executor_, true);
        emit SwapExecutorAdded(executor_);
    }

    function removeSwapExecutors(address[] calldata executor_) external onlyGovernance {
        _setSwapExecutor(executor_, false);
        emit SwapExecutorRemoved(executor_);
    }

    function addAllowedTokens(address[] calldata tokens_) external onlyAdminOrGovernor {
        _setAllowedTokens(tokens_, true);
        emit TokensAdded(tokens_);
    }

    function removeAllowedTokens(address[] calldata tokens_) external onlyAdminOrGovernor {
        _setAllowedTokens(tokens_, false);
        emit TokensRemoved(tokens_);
    }

    function addSwapIntervalsToAllowedList(uint32[] calldata swapIntervals_) external onlyAdminOrGovernor {
        for (uint256 i; i < swapIntervals_.length; ++i) {
            allowedSwapIntervals |= Intervals.intervalToMask(swapIntervals_[i]);
        }
        emit SwapIntervalsAdded(swapIntervals_);
    }

    function removeSwapIntervalsFromAllowedList(uint32[] calldata swapIntervals_) external onlyAdminOrGovernor {
        for (uint256 i; i < swapIntervals_.length; ++i) {
            allowedSwapIntervals &= ~Intervals.intervalToMask(swapIntervals_[i]);
        }
        emit SwapIntervalsRemoved(swapIntervals_);
    }

    function updateMaxSwapLimit(uint256 maxNoOfSwap_) external onlyAdminOrGovernor {
        if (maxNoOfSwap_ < 2) revert InvalidNoOfSwaps();
        maxNoOfSwap = maxNoOfSwap_;
        emit SwapLimitUpdated(maxNoOfSwap_);
    }

    function updateSwapTimeThreshold(uint256 nextToNextTimeThreshold_) external onlyAdminOrGovernor {
        nextToNextTimeThreshold = nextToNextTimeThreshold_;
        emit SwapThresholdUpdated(nextToNextTimeThreshold_);
    }

    function setFeeVault(address newVault_) external onlyGovernance {
        if (newVault_ == address(0)) revert ZeroAddress();
        feeVault = newVault_;
        emit FeeVaultUpdated(newVault_);
    }

    function setSwapFee(uint32[] calldata intervals_, uint256[] calldata swapFee_) external onlyGovernance {
        if (intervals_.length != swapFee_.length) revert InvalidLength();
        for (uint256 i; i < intervals_.length; i++) {
            if (swapFee_[i] > MAX_FEE) revert HighFee();

            _swapFeeMap[Intervals.intervalToMask(intervals_[i])] = swapFee_[i];
        }

        emit SwapFeeUpdated(intervals_, swapFee_);
    }

    function setPlatformFeeRatio(uint256 platformFeeRatio_) external onlyGovernance {
        if (platformFeeRatio_ > MAX_PLATFORM_FEE_RATIO) revert HighPlatformFeeRatio();
        platformFeeRatio = platformFeeRatio_;
        emit PlatformFeeRatioUpdated(platformFeeRatio_);
    }

    /* ========= INTERNAL/PRIVATE FUNCTIONS ========= */

    function _setAllowedTokens(address[] calldata tokens_, bool allowed_) private {
        for (uint256 i; i < tokens_.length; ++i) {
            address token = tokens_[i];
            if (token == address(0) || token == NATIVE_TOKEN) revert InvalidToken();
            allowedTokens[token] = allowed_;
            if (tokenMagnitude[token] == 0) {
                tokenMagnitude[token] = 10**IERC20Metadata(token).decimals();
            }
        }
    }

    function _setAdmin(address[] calldata accounts_, bool state_) private {
        for (uint256 i; i < accounts_.length; i++) {
            if (accounts_[i] == address(0)) revert ZeroAddress();
            admins[accounts_[i]] = state_;
        }
    }

    function _setSwapExecutor(address[] calldata accounts_, bool state_) private {
        for (uint256 i; i < accounts_.length; i++) {
            if (accounts_[i] == address(0)) revert ZeroAddress();
            swapExecutors[accounts_[i]] = state_;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./../interfaces/IDCAParameters.sol";

import { SwapData } from "./../common/Types.sol";

abstract contract DCAParameters is IDCAParameters {
    /* ========= VIEWS ========= */

    mapping(address => mapping(address => bytes1)) public activeSwapIntervals;

    mapping(address => mapping(address => mapping(bytes1 => SwapData))) public swapData;

    mapping(address => mapping(address => mapping(bytes1 => mapping(uint256 => uint256)))) public swapAmountDelta;

    mapping(address => mapping(address => mapping(bytes1 => mapping(uint256 => uint256)))) public accumRatio;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./../interfaces/IDCAPositionHandler.sol";
import "./../utils/Permitable.sol";
import "./DCAConfigHandler.sol";

import { UserPosition, PositionInfo, CreatePositionDetails, PermitType } from "./../common/Types.sol";
import { ZeroAddress, NotWNative, NativeTransferFailed, UnauthorizedTokens, InvalidAmount, InvalidNoOfSwaps, UnauthorizedInterval, InvalidRate, NoChanges, ZeroSwappedTokens, InvalidAmountTransferred, InvalidNativeAmount, InvalidPosition } from "./../common/Error.sol";

abstract contract DCAPositionHandler is Permitable, DCAConfigHandler, IDCAPositionHandler {
    using SafeERC20 for IERC20;

    mapping(uint256 => UserPosition) public userPositions;
    mapping(uint256 => uint256) internal _swappedBeforeModified; // positionId -> swappedAmount

    uint256 public totalCreatedPositions;

    /* ========= CONSTRUCTOR ========= */

    // solhint-disable-next-line no-empty-blocks
    constructor(address permit2_) Permitable(permit2_) {}

    /* ========= VIEWS ========= */

    function getPositionDetails(uint256 positionId_) external view returns (PositionInfo memory positionInfo) {
        UserPosition memory userPosition = userPositions[positionId_];

        uint256 performedSwaps = swapData[userPosition.from][userPosition.to][userPosition.swapIntervalMask].performedSwaps;

        positionInfo.owner = userPosition.owner;
        positionInfo.from = userPosition.from;
        positionInfo.to = userPosition.to;
        positionInfo.rate = userPosition.rate;


        positionInfo.swapsLeft = _remainingNoOfSwaps(userPosition.startingSwap, userPosition.finalSwap, performedSwaps);
        positionInfo.swapsExecuted = userPosition.finalSwap - userPosition.startingSwap - positionInfo.swapsLeft;
        positionInfo.unswapped = _calculateUnswapped(userPosition, performedSwaps);

        if (userPosition.swapIntervalMask > 0) {
            positionInfo.swapInterval = Intervals.maskToInterval(userPosition.swapIntervalMask);
            positionInfo.swapped = _calculateSwapped(positionId_, userPosition, performedSwaps);
        }
    }

    /* ========= FUNCTIONS ========= */

    function createPosition(CreatePositionDetails calldata details_) external payable whenNotPaused {
        if (details_.from == NATIVE_TOKEN && msg.value != details_.amount) revert InvalidNativeAmount();

        (uint256 positionId, bool isNative) = _create(details_);

        emit Created(_msgSender(), positionId, isNative);
    }

    function createBatchPositions(CreatePositionDetails[] calldata details_) external payable whenNotPaused {
        uint256 value = msg.value;
        bool[] memory isNative = new bool[](details_.length);

        for (uint256 i; i < details_.length; ++i) {
            if (details_[i].from == NATIVE_TOKEN) {
                if (details_[i].amount > value) revert InvalidNativeAmount();
                value -= details_[i].amount;
            }

            (, isNative[i]) = _create(details_[i]);
        }

        if (value != 0) revert InvalidNativeAmount();

        emit CreatedBatched(_msgSender(), totalCreatedPositions, details_.length, isNative);
    }

    function modifyPosition(uint256 positionId_, uint256 amount_, uint256 noOfSwaps_, bool isIncrease_, bool isNative_, bytes calldata permit_) external payable whenNotPaused {
        UserPosition memory userPosition = userPositions[positionId_];
        _assertPositionExistsAndCallerIsOwner(userPosition);

        if (amount_ == 0) {
            // only noOfSwaps is updated
            _assertTokensAreAllowed(userPosition.from, userPosition.to);
            if (msg.value != 0) revert InvalidNativeAmount();
        } else if (isIncrease_) {
            // increase
            _assertTokensAreAllowed(userPosition.from, userPosition.to);

            _deposit(isNative_, userPosition.from, amount_, permit_);
        }

        (uint256 rate, uint256 startingSwap, uint256 finalSwap) = _modify(userPosition, positionId_, amount_, noOfSwaps_, isIncrease_);

        // reduce
        if (!isIncrease_ && amount_ > 0) _pay(isNative_, userPosition.from, _msgSender(), amount_);

        emit Modified(_msgSender(), positionId_, rate, startingSwap, finalSwap, isNative_);
    }

    function terminatePosition(uint256 positionId_, address recipient_, bool isNative_) external {
        if (recipient_ == address(0)) revert ZeroAddress();

        UserPosition memory userPosition = userPositions[positionId_];
        _assertPositionExistsAndCallerIsOwner(userPosition);

        (uint256 unswapped, uint256 swapped) = _terminate(userPosition, positionId_);

        if (isNative_) {
            if (userPosition.from == address(wNative)) {
                _unwrapAndTransfer(recipient_, unswapped);
                IERC20(userPosition.to).safeTransfer(recipient_, swapped);
            } else if ((userPosition.to == address(wNative))) {
                IERC20(userPosition.from).safeTransfer(recipient_, unswapped);
                _unwrapAndTransfer(recipient_, swapped);
            } else revert NotWNative();
        } else {
            IERC20(userPosition.from).safeTransfer(recipient_, unswapped);
            IERC20(userPosition.to).safeTransfer(recipient_, swapped);
        }

        emit Terminated(_msgSender(), recipient_, positionId_, swapped, unswapped, isNative_);
    }

    function withdrawPosition(uint256 positionId_, address recipient_, bool isNative_) external {
        if (recipient_ == address(0)) revert ZeroAddress();

        UserPosition memory userPosition = userPositions[positionId_];
        _assertPositionExistsAndCallerIsOwner(userPosition);

        uint256 swapped = _withdraw(userPosition, positionId_);
        if (swapped == 0) revert ZeroSwappedTokens();

        _pay(isNative_, userPosition.to, recipient_, swapped);

        emit Withdrawn(_msgSender(), recipient_, positionId_, swapped, isNative_);
    }

    function transferPositionOwnership(uint256 positionId_, address newOwner_) external whenNotPaused {
        if (newOwner_ == address(0)) revert ZeroAddress();

        UserPosition memory userPosition = userPositions[positionId_];
        _assertPositionExistsAndCallerIsOwner(userPosition);

        userPositions[positionId_].owner = newOwner_;

        emit PositionOwnerUpdated(userPosition.owner, newOwner_, positionId_);
    }

    /* ========= INTERNAL ========= */

    function _deposit(bool isNative_, address token_, uint256 amount_, bytes calldata permit_) private {
        if (isNative_) {
            if (msg.value != amount_) revert InvalidNativeAmount();
            if (token_ != address(wNative)) revert NotWNative();
            _wrap(amount_);
        } else {
            _permitAndTransferFrom(token_, permit_, amount_);
        }
    }

    function _pay(bool isNative_, address token_, address recipient_, uint256 amount_) private {
        if (isNative_) {
            if (token_ != address(wNative)) revert NotWNative();
            _unwrapAndTransfer(recipient_, amount_);
        } else {
            IERC20(token_).safeTransfer(recipient_, amount_);
        }
    }

    function _safeNativeTransfer(address recipient_, uint256 amount_) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool sent, ) = recipient_.call{ value: amount_ }(new bytes(0));
        if (!sent) revert NativeTransferFailed();
    }
 
    function _permitAndTransferFrom(address token_, bytes calldata permit_, uint256 amount_) internal {
        (PermitType permitType, bytes memory data) = abi.decode(permit_, (PermitType, bytes)); 

        if(permitType == PermitType.PERMIT2_APPROVE)  {
            _permit2Approve(token_, data);
            IPermit2(PERMIT2).transferFrom(
                _msgSender(),
                address(this),
                uint160(amount_),
                token_
            );
        } else if (permitType == PermitType.PERMIT2_TRANSFER_FROM) {
            _permit2TransferFrom(token_, data, amount_);
        } else {
            _permit(token_, data);
            IERC20(token_).safeTransferFrom(_msgSender(), address(this), amount_);
        }
    }

    function _wrap(uint256 amount_) internal {
        if (amount_ > 0) wNative.deposit{ value: amount_ }();
    }

    function _unwrapAndTransfer(address recipient_, uint256 amount_) internal {
        if (amount_ > 0) {
            wNative.withdraw(amount_);
            _safeNativeTransfer(recipient_, amount_);
        }
    }

    // solhint-disable-next-line code-complexity
    function _create(CreatePositionDetails calldata details_) private returns (uint256 positionId, bool isNative) {
        if (details_.from == address(0) || details_.to == address(0)) revert ZeroAddress();
        if (details_.amount == 0) revert InvalidAmount();
        if (details_.noOfSwaps == 0 || details_.noOfSwaps > maxNoOfSwap) revert InvalidNoOfSwaps();

        bool isFromNative = details_.from == NATIVE_TOKEN;
        bool isToNative = details_.to == NATIVE_TOKEN;
        isNative = isFromNative || isToNative;

        address from = isFromNative ? address(wNative) : details_.from;
        address to = isToNative ? address(wNative) : details_.to;

        if (from == to) revert InvalidToken();
        _assertTokensAreAllowed(from, to);

        bytes1 swapIntervalMask = Intervals.intervalToMask(details_.swapInterval);
        if (allowedSwapIntervals & swapIntervalMask == 0) revert InvalidInterval();

        uint256 rate = _calculateRate(details_.amount, details_.noOfSwaps);
        if (rate == 0) revert InvalidRate();

        // transfer tokens
        if (isFromNative) _wrap(details_.amount);
        else _permitAndTransferFrom(from, details_.permit, details_.amount);

        positionId = ++totalCreatedPositions;
        uint256 performedSwaps = swapData[from][to][swapIntervalMask].performedSwaps;

        // updateActiveIntervals
        if (activeSwapIntervals[from][to] & swapIntervalMask == 0) activeSwapIntervals[from][to] |= swapIntervalMask;

        (uint256 startingSwap, uint256 finalSwap) = _addToDelta(from, to, swapIntervalMask, rate, performedSwaps, performedSwaps + details_.noOfSwaps
        );

        userPositions[positionId] = UserPosition({
            owner: _msgSender(), from: from, to: to, swapIntervalMask: swapIntervalMask, rate: rate, 
            swapWhereLastUpdated: performedSwaps, startingSwap: startingSwap, finalSwap: finalSwap
        });
    }

    function _modify(UserPosition memory userPosition_, uint256 positionId_, uint256 amount_, uint256 noOfSwaps_, bool isIncrease_) 
        internal returns (uint256 newRate,uint256 newStartingSwap,uint256 newFinalSwap) 
    {
        uint256 performedSwaps = swapData[userPosition_.from][userPosition_.to][userPosition_.swapIntervalMask].performedSwaps;
        uint256 remainingNoOfSwaps = _remainingNoOfSwaps(userPosition_.startingSwap, userPosition_.finalSwap, performedSwaps);
        uint256 unswapped = remainingNoOfSwaps * userPosition_.rate;
        uint256 tempUnswapped = unswapped;

        if (isIncrease_) tempUnswapped += amount_;
        else {
            if (amount_ > unswapped) revert InvalidAmount();
            tempUnswapped -= amount_;
        }

        if (tempUnswapped == unswapped && noOfSwaps_ == remainingNoOfSwaps) revert NoChanges();
        if (
            (tempUnswapped > 0 && (noOfSwaps_ == 0 || noOfSwaps_ > maxNoOfSwap)) ||
            (tempUnswapped == 0 && noOfSwaps_ > 0)
        ) revert InvalidNoOfSwaps();

        if (noOfSwaps_ > 0) newRate = _calculateRate(tempUnswapped, noOfSwaps_);
        if (newRate > 0) {
            newStartingSwap = performedSwaps;
            newFinalSwap = performedSwaps + noOfSwaps_;
        }

        // store current claimable swap tokens.
        _swappedBeforeModified[positionId_] = _calculateSwapped(positionId_, userPosition_, performedSwaps);

        // remove the prev position
        _removeFromDelta(userPosition_, performedSwaps);

        if(newRate > 0) {
            // add updated position
            (newStartingSwap, newFinalSwap) = _addToDelta(userPosition_.from, userPosition_.to, userPosition_.swapIntervalMask, newRate, newStartingSwap, newFinalSwap);

            if((activeSwapIntervals[userPosition_.from][userPosition_.to] & userPosition_.swapIntervalMask == 0)) {
                // add in activeSwapIntervals
                activeSwapIntervals[userPosition_.from][userPosition_.to] |= userPosition_.swapIntervalMask;
            }
        } else {
             // remove from activeSwapIntervals (if no other positions exist)
             SwapData memory data = swapData[userPosition_.from][userPosition_.to][userPosition_.swapIntervalMask];
             
             if (data.nextAmountToSwap == 0 && data.nextToNextAmountToSwap == 0)
                activeSwapIntervals[userPosition_.from][userPosition_.to] &= ~userPosition_.swapIntervalMask;
        }

        userPositions[positionId_].rate = newRate;
        userPositions[positionId_].swapWhereLastUpdated = performedSwaps;
        userPositions[positionId_].startingSwap = newStartingSwap;
        userPositions[positionId_].finalSwap = newFinalSwap;
    }

    function _terminate(UserPosition memory userPosition_, uint256 positionId_) private returns (uint256 unswapped, uint256 swapped){
        uint256 performedSwaps = swapData[userPosition_.from][userPosition_.to][userPosition_.swapIntervalMask].performedSwaps;

        swapped = _calculateSwapped(positionId_, userPosition_, performedSwaps);
        unswapped = _calculateUnswapped(userPosition_, performedSwaps);

        // removeFromDelta
        _removeFromDelta(userPosition_, performedSwaps);

        SwapData memory data = swapData[userPosition_.from][userPosition_.to][userPosition_.swapIntervalMask];
             
        if (data.nextAmountToSwap == 0 && data.nextToNextAmountToSwap == 0)
            activeSwapIntervals[userPosition_.from][userPosition_.to] &= ~userPosition_.swapIntervalMask;

        delete userPositions[positionId_];
        _swappedBeforeModified[positionId_] = 0;
    }

    function _withdraw(UserPosition memory userPosition_, uint256 positionId_) internal returns (uint256 swapped) {
        uint256 performedSwaps = swapData[userPosition_.from][userPosition_.to][userPosition_.swapIntervalMask].performedSwaps;

        swapped = _calculateSwapped(positionId_, userPosition_, performedSwaps);

        userPositions[positionId_].swapWhereLastUpdated = performedSwaps;
        _swappedBeforeModified[positionId_] = 0;
    }

    function _addToDelta(address from_, address to_, bytes1 swapIntervalMask_, uint256 rate_, uint256 startingSwap_, uint256 finalSwap_) internal returns (uint256, uint256) {
        (bool isPartOfNextSwap, uint256 timeUntilThreshold) = _getTimeUntilThreshold(from_, to_, swapIntervalMask_);
        SwapData storage data = swapData[from_][to_][swapIntervalMask_];

        if (isPartOfNextSwap && block.timestamp > timeUntilThreshold) {
            startingSwap_ += 1;
            finalSwap_ += 1;
            data.nextToNextAmountToSwap += rate_;
        } else {
            data.nextAmountToSwap += rate_;
        }

        swapAmountDelta[from_][to_][swapIntervalMask_][finalSwap_ + 1] += rate_;
        return (startingSwap_, finalSwap_);
    }

    function _removeFromDelta(UserPosition memory userPosition_, uint256 performedSwaps_) internal {
        if (userPosition_.finalSwap > performedSwaps_) {
            SwapData storage data = swapData[userPosition_.from][userPosition_.to][userPosition_.swapIntervalMask];

            if (userPosition_.startingSwap > performedSwaps_) {
                data.nextToNextAmountToSwap -= userPosition_.rate;
            } else {
                data.nextAmountToSwap -= userPosition_.rate;
            }
            swapAmountDelta[userPosition_.from][userPosition_.to][userPosition_.swapIntervalMask][
                userPosition_.finalSwap + 1
            ] -= userPosition_.rate;
        }
    }

    function _calculateSwapped( uint256 positionId_, UserPosition memory userPosition_, uint256 performedSwaps_) internal view returns (uint256) {
        uint256 finalNo = Math.min(performedSwaps_, userPosition_.finalSwap);

        // If last update happened after the position's final swap, then a withdraw was executed, and we just return 0
        if (userPosition_.swapWhereLastUpdated > finalNo) return 0;
        // If the last update matches the positions's final swap, then we can avoid all calculation below
        else if (userPosition_.swapWhereLastUpdated == finalNo) return _swappedBeforeModified[positionId_];

        uint256 startingNo= Math.max(userPosition_.swapWhereLastUpdated, userPosition_.startingSwap);
        uint256 avgAccumulationPrice = accumRatio[userPosition_.from][userPosition_.to][userPosition_.swapIntervalMask][finalNo] -
            accumRatio[userPosition_.from][userPosition_.to][userPosition_.swapIntervalMask][startingNo];

        return ((avgAccumulationPrice * userPosition_.rate) / tokenMagnitude[userPosition_.from]) + _swappedBeforeModified[positionId_];
    }

    function _remainingNoOfSwaps(uint256 startingSwap_, uint256 finalSwap_, uint256 performedSwaps_) private pure returns (uint256 remainingNoOfSwap) {
        uint256 noOfSwaps = finalSwap_ - startingSwap_;
        uint256 totalSwapExecutedFromStart = _subtractIfPossible(performedSwaps_, startingSwap_);
        remainingNoOfSwap = totalSwapExecutedFromStart > noOfSwaps ? 0 : noOfSwaps - totalSwapExecutedFromStart;
    }

    function _calculateUnswapped(UserPosition memory userPosition_, uint256 performedSwaps_) internal pure returns (uint256){
        return _remainingNoOfSwaps(userPosition_.startingSwap, userPosition_.finalSwap, performedSwaps_) * userPosition_.rate;
    }

    function _calculateRate(uint256 amount_, uint256 noOfSwaps_) internal pure returns (uint256) {
        return amount_ / noOfSwaps_;
    }

    function _assertTokensAreAllowed(address tokenA_, address tokenB_) internal view {
        if (!allowedTokens[tokenA_] || !allowedTokens[tokenB_]) revert UnauthorizedTokens();
    }

    function _assertPositionExistsAndCallerIsOwner(UserPosition memory userPosition_) internal view {
        if (userPosition_.swapIntervalMask == 0) revert InvalidPosition();
        if (_msgSender() != userPosition_.owner) revert UnauthorizedCaller();
    }

    function _subtractIfPossible(uint256 a_, uint256 b_) internal pure returns (uint256) {
        return a_ > b_ ? a_ - b_ : 0;
    }

    function _getTimeUntilThreshold(address from_, address to_, bytes1 interval_) private view returns (bool, uint256) {
        bytes1 activeIntervals = activeSwapIntervals[from_][to_];
        bytes1 mask = 0x01;
        bytes1 intervalsInSwap;
        uint256 nextSwapTimeEnd = type(uint256).max;

        while (activeIntervals >= mask && mask > 0) {
            if (activeIntervals & mask == mask || interval_ == mask) {
                SwapData memory swapDataMem = swapData[from_][to_][mask];
                uint32 swapInterval = Intervals.maskToInterval(mask);
                uint256 currSwapTime = (block.timestamp / swapInterval) * swapInterval; 
                uint256 nextSwapTime = swapDataMem.lastSwappedAt == 0
                    ? currSwapTime
                    : ((swapDataMem.lastSwappedAt / swapInterval) + 1) * swapInterval;
                
                // as swaps will only be done in current window
                // so if next window is smaller than current window then update the next window
                if(currSwapTime > nextSwapTime) nextSwapTime = currSwapTime;
                uint256 tempNextSwapTimeEnd = nextSwapTime + swapInterval;

                if (
                    (block.timestamp > nextSwapTime && block.timestamp < tempNextSwapTimeEnd) &&
                    (swapDataMem.nextAmountToSwap > 0 || mask == interval_)
                ) {
                    intervalsInSwap |= mask;
                    if (tempNextSwapTimeEnd < nextSwapTimeEnd) {
                        nextSwapTimeEnd = tempNextSwapTimeEnd;
                    }
                }
            }
            mask <<= 1;
        }
        return (intervalsInSwap & interval_ == interval_, nextSwapTimeEnd - nextToNextTimeThreshold);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./../interfaces/IDCASwapHandler.sol";
import "./DCAConfigHandler.sol";

import { SwapInfo, Pair, SwapDetails } from "./../common/Types.sol";
import { InvalidLength, NoAvailableSwap, InvalidSwapAmount, InvalidReturnAmount, SwapCallFailed, InvalidBlankSwap } from "./../common/Error.sol";

abstract contract DCASwapHandler is DCAConfigHandler, IDCASwapHandler {
    using SafeERC20 for IERC20;

    /* ========= VIEWS ========= */

    function secondsUntilNextSwap(Pair[] calldata pairs_) external view returns (uint256[] memory) {
        uint256[] memory secondsArr = new uint256[](pairs_.length);
        for (uint256 i; i < pairs_.length; i++) secondsArr[i] = _secondsUntilNextSwap(pairs_[i].from, pairs_[i].to);
        return secondsArr;
    }

    function getNextSwapInfo(Pair[] calldata pairs_) external view returns (SwapInfo[] memory) {
        SwapInfo[] memory swapInformation = new SwapInfo[](pairs_.length);

        for (uint256 i; i < pairs_.length; ++i) {
            Pair memory pair = pairs_[i];

            (uint256 amountToSwap, bytes1 intervalsInSwap, uint256 swapperReward, uint256 platformFee) = _getTotalAmountsToSwap(pair.from, pair.to);

            swapInformation[i] = SwapInfo(pair.from, pair.to, amountToSwap, 0, swapperReward, platformFee, intervalsInSwap);
        }

        return swapInformation;
    }

    /* ========= PUBLIC ========= */

    function swap(SwapDetails[] calldata data_, address rewardRecipient_) external onlySwapper whenNotPaused {
        if (data_.length == 0) revert InvalidLength();
        SwapInfo[] memory swapInfo = new SwapInfo[](data_.length);

        for (uint256 i; i < data_.length; ++i) {
            SwapDetails memory data = data_[i];
            (uint256 amountToSwap, bytes1 intervalsInSwap, uint256 swapperReward, uint256 platformFee) = _getTotalAmountsToSwap(data.from, data.to);

            if (amountToSwap == 0 || intervalsInSwap == 0) revert NoAvailableSwap();
            if (data.amount != amountToSwap) revert InvalidSwapAmount();

            // execute Swap
            uint256 returnAmount = _executeSwap(data);

            if (returnAmount < data.minReturnAmount) revert InvalidReturnAmount();

            // register swap
            _registerSwap(data.from, data.to, amountToSwap, returnAmount, intervalsInSwap);

            swapInfo[i] = SwapInfo(data.from, data.to, amountToSwap, returnAmount, swapperReward, platformFee, intervalsInSwap);

            // transfer reward and fee
            if (platformFee > 0) IERC20(data.from).safeTransfer(feeVault, platformFee);
            if (swapperReward > 0) IERC20(data.from).safeTransfer(rewardRecipient_, swapperReward);
        }
        emit Swapped(_msgSender(), rewardRecipient_, swapInfo);
    }

    /**
        wont come under this until it all positions have a blank swap active
        dont update lastSwappedAt;
         swapAmountDelta:
            in create in will be grater than swapDataMem.performSwap + 1
            in modify if will have been updated
    */
    function blankSwap(address from_, address to_, bytes1 maskedInterval_) external onlySwapper whenNotPaused {
        SwapData storage data = swapData[from_][to_][maskedInterval_];
        
        if (data.nextAmountToSwap > 0 || data.nextToNextAmountToSwap == 0) revert InvalidBlankSwap();
        // require(data.nextAmountToSwap == 0 && data.nextToNextAmountToSwap > 0, "InvalidBlankSwap");

        accumRatio[from_][to_][maskedInterval_][data.performedSwaps + 1] = accumRatio[from_][to_][maskedInterval_][data.performedSwaps];

        data.nextAmountToSwap += data.nextToNextAmountToSwap;
        data.nextToNextAmountToSwap = 0;
        data.performedSwaps += 1;

        emit BlankSwapped(_msgSender(), from_, to_, maskedInterval_);
    }

    /* ========= INTERNAL ========= */

    function _executeSwap(SwapDetails memory data_) private returns (uint256 returnAmount) {
        uint256 balanceBefore = IERC20(data_.to).balanceOf(address(this));
        IERC20(data_.from).approve(data_.tokenProxy, data_.amount);

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = data_.executor.call(data_.swapCallData);
        if (!success) revert SwapCallFailed();

        returnAmount = IERC20(data_.to).balanceOf(address(this)) - balanceBefore;
    }

    function _getSwapAmountAndFee(uint256 amount_, uint256 fee_) private pure returns (uint256, uint256) {
        uint256 feeAmount = (amount_ * fee_) / BPS_DENOMINATOR;
        return (amount_ - feeAmount, feeAmount);
    }

    function _getTotalAmountsToSwap(address from_, address to_) private view 
        returns (uint256 amountToSwap, bytes1 intervalsInSwap, uint256 swapperReward, uint256 platformFee) 
    {
        bytes1 activeIntervalsMem = activeSwapIntervals[from_][to_];
        bytes1 mask = 0x01;

        while (activeIntervalsMem >= mask && mask > 0) {
            if (activeIntervalsMem & mask != 0) {
                SwapData memory swapDataMem = swapData[from_][to_][mask];
                uint32 swapInterval = Intervals.maskToInterval(mask);

                // Note: this 'break' is both an optimization and a search for more CoW. Since this loop starts with the smaller intervals, it is
                // highly unlikely that if a small interval can't be swapped, a bigger interval can. It could only happen when a position was just
                // created for a new swap interval. At the same time, by adding this check, we force intervals to be swapped together.
                if (((swapDataMem.lastSwappedAt / swapInterval) + 1) * swapInterval > block.timestamp) break;

                if (swapDataMem.nextAmountToSwap > 0) {
                    intervalsInSwap |= mask;
                    (uint256 amountToSwapForInterval, uint256 feeAmount) = _getSwapAmountAndFee(swapDataMem.nextAmountToSwap, _swapFeeMap[mask]);
                    (uint256 reward, uint256 fee) = _getSwapAmountAndFee(feeAmount, platformFeeRatio);

                    amountToSwap += amountToSwapForInterval;
                    swapperReward += reward;
                    platformFee += fee;
                }
            }

            mask <<= 1;
        }

        if (amountToSwap == 0) intervalsInSwap = 0;
    }

    function _registerSwap(address tokenA_, address tokenB_,uint256 amountToSwap_, uint256 totalReturnAmount_, bytes1 intervalsInSwap_) private {
        bytes1 mask = 0x01;
        bytes1 activeIntervals = activeSwapIntervals[tokenA_][tokenB_];

        while (activeIntervals >= mask && mask != 0) {
            // nextAmountToSwap > 0. 
            // nextAmountToSwap > 0. nextToNext > 0
            SwapData memory swapDataMem = swapData[tokenA_][tokenB_][mask];

            if (intervalsInSwap_ & mask != 0 && swapDataMem.nextAmountToSwap > 0) {
                (uint256 amountToSwapForIntervalWithoutFee, ) = _getSwapAmountAndFee(swapDataMem.nextAmountToSwap, _swapFeeMap[mask]);
                uint256 returnAmountForInterval = totalReturnAmount_ * amountToSwapForIntervalWithoutFee * tokenMagnitude[tokenA_] / amountToSwap_;
                uint256 swapPrice = returnAmountForInterval / swapDataMem.nextAmountToSwap;

                // accumRatio[currSwapNo] = accumRatio[prevSwapNo] + swapPriceForInterval
                accumRatio[tokenA_][tokenB_][mask][swapDataMem.performedSwaps + 1] = accumRatio[tokenA_][tokenB_][mask][swapDataMem.performedSwaps] + swapPrice;

                // nextAmountToSwap = nextAmountToSwap - amounts for position which have to finished
                swapData[tokenA_][tokenB_][mask] = SwapData(
                    swapDataMem.performedSwaps + 1,
                    swapDataMem.nextAmountToSwap +
                        swapDataMem.nextToNextAmountToSwap -
                        swapAmountDelta[tokenA_][tokenB_][mask][swapDataMem.performedSwaps + 2],
                    0,
                    block.timestamp
                );

                // remove swapInterval from  activeSwapIntervals if all swaps for it are been executed
                if (swapData[tokenA_][tokenB_][mask].nextAmountToSwap == 0) activeSwapIntervals[tokenA_][tokenB_] &= ~mask;

                delete swapAmountDelta[tokenA_][tokenB_][mask][swapDataMem.performedSwaps + 2];
            } else if (swapDataMem.nextAmountToSwap == 0 && swapDataMem.nextToNextAmountToSwap > 0) {
                // nextAmountToSwap = 0. nextToNext > 0
                SwapData storage data = swapData[tokenA_][tokenB_][mask];

                accumRatio[tokenA_][tokenB_][mask][swapDataMem.performedSwaps + 1] = accumRatio[tokenA_][tokenB_][mask][swapDataMem.performedSwaps];

                data.nextAmountToSwap = swapDataMem.nextAmountToSwap + swapDataMem.nextToNextAmountToSwap;
                data.nextToNextAmountToSwap = 0;
                data.performedSwaps += 1;

                // emit BlankSwapped(_msgSender(), tokenA_, tokenB_, mask);
            }
            mask <<= 1;
        }
    }

    function _secondsUntilNextSwap(address from_, address to_) private view returns (uint256) {
        bytes1 activeIntervals = activeSwapIntervals[from_][to_];
        bytes1 mask = 0x01;
        uint256 smallerIntervalBlocking;

        while (activeIntervals >= mask && mask > 0) {
            if (activeIntervals & mask == mask) {
                SwapData memory swapDataMem = swapData[from_][to_][mask];
                uint32 swapInterval = Intervals.maskToInterval(mask);
                uint256 nextAvailable = ((swapDataMem.lastSwappedAt / swapInterval) + 1) * swapInterval;

                if (swapDataMem.nextAmountToSwap > 0) {
                    if (nextAvailable <= block.timestamp) return smallerIntervalBlocking;
                    else return nextAvailable - block.timestamp;
                } else if (nextAvailable > block.timestamp) {
                    smallerIntervalBlocking = smallerIntervalBlocking == 0 ? nextAvailable - block.timestamp : smallerIntervalBlocking;
                }
            }
            mask <<= 1;
        }
        return type(uint256).max;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./../interfaces/IDZapDCA.sol";

import "./DCAParameters.sol";
import "./DCAConfigHandler.sol";
import "./DCAPositionHandler.sol"; 
import "./DCASwapHandler.sol";

import { ZeroAddress } from "./../common/Error.sol";

contract DZapDCA is DCAParameters, DCAConfigHandler, DCASwapHandler, DCAPositionHandler, IDZapDCA {
    using SafeERC20 for IERC20;

    constructor(address governor_, address wNative_, address feeVault_, address permit2_, uint256 maxNoOfSwap_) DCAConfigHandler(governor_, wNative_, feeVault_, maxNoOfSwap_) DCAPositionHandler(permit2_) {} // solhint-disable-line no-empty-blocks

    /* ========= USER FUNCTIONS ========= */

    function batchCall(bytes[] calldata data_) external returns (bytes[] memory results) {
        results = new bytes[](data_.length);
        for (uint256 i; i < data_.length; i++) {
            results[i] = Address.functionDelegateCall(address(this), data_[i]);
        }
        return results;
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IDAIPermit {
    /**
     * @dev Sets the allowance of `spender` over ``holder``'s tokens,
     * given ``holder``'s signed approval.
     */
    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./IWNative.sol";

interface IDCAConfigHandler {
    /* ========= EVENTS ========= */

    event AdminAdded(address[] accounts);

    event AdminRemoved(address[] accounts);

    event SwapExecutorAdded(address[] accounts);

    event SwapExecutorRemoved(address[] accounts);

    event SwapLimitUpdated(uint256 noOfSwaps);

    event SwapThresholdUpdated(uint256 threshold);

    event TokensAdded(address[] tokens);

    event TokensRemoved(address[] tokens);

    event SwapIntervalsAdded(uint32[] swapIntervals);

    event SwapIntervalsRemoved(uint32[] swapIntervals);

    event FeeVaultUpdated(address feeVault);

    event SwapFeeUpdated(uint32[] intervals, uint256[] swapFee);

    event PlatformFeeRatioUpdated(uint256 platformFeeRatio);

    /* ========= VIEWS ========= */

    /// @notice Returns a byte that represents allowed swap intervals
    function allowedSwapIntervals() external view returns (bytes1);

    /// @notice Returns if a token is currently allowed or not
    function allowedTokens(address token_) external view returns (bool);

    /// @notice Returns token's magnitude (10**decimals)
    function tokenMagnitude(address token_) external view returns (uint256);

    /**
     * @notice Returns whether account is admin or not
     * @param account_ account to check
     */
    function admins(address account_) external view returns (bool);

    /**
     * @notice Returns whether account is a swap executors or not
     * @param account_ account to check
     */
    function swapExecutors(address account_) external view returns (bool);

    /// @notice Returns address of wNative token
    function wNative() external view returns (IWNative);

    /// @notice Returns the address of vault where platform fee will be deposited
    function feeVault() external view returns (address);

    /**
     * @notice Returns the address which will be used for Native tokens
     * @dev Cannot be modified
     * @return Native token
     */
    // solhint-disable-next-line func-name-mixedcase
    function NATIVE_TOKEN() external view returns (address);

    /// @notice Returns the percent of fee that will be charged on swaps
    function getSwapFee(uint32 interval_) external view returns (uint256);

    /// @notice Returns the percent of swapFee that platform will take
    function platformFeeRatio() external view returns (uint256);

    /**
     * @notice Returns the max fee that can be set for swaps
     * @dev Cannot be modified
     * @return The maximum possible fee
     */
    // solhint-disable-next-line func-name-mixedcase
    function MAX_FEE() external view returns (uint256);

    /**
     * @notice Returns the max fee ratio that can be set
     * @dev Cannot be modified
     * @return The maximum possible value
     */
    // solhint-disable-next-line func-name-mixedcase
    function MAX_PLATFORM_FEE_RATIO() external view returns (uint256);

    /**
     * @notice Returns the BPS denominator to be used
     * @dev Cannot be modified
     * @dev swapFee and platformFeeRatio need to use the precision used by BPS_DENOMINATOR
     */
    // solhint-disable-next-line func-name-mixedcase
    function BPS_DENOMINATOR() external view returns (uint256);

    /* ========= RESTRICTED FUNCTIONS ========= */

    /// @notice Pauses all swaps and deposits
    function pause() external;

    /// @notice UnPauses if contract is paused
    function unpause() external;

    /**
     * @notice @notice Add admins which can set allowed tokens and intervals
     * @dev Can be called by governance
     * @param accounts_ array of accounts
     */
    function addAdmins(address[] calldata accounts_) external;

    /**
     * @notice @notice Remove admins
     * @dev Can be called by governance
     * @param accounts_ array of accounts
     */
    function removeAdmins(address[] calldata accounts_) external;

    /**
     * @notice @notice Add executors which can do swaps
     * @dev Can be called by governance
     * @param executor_ array of accounts
     */
    function addSwapExecutors(address[] calldata executor_) external;

    /**
     * @notice @notice Remove executors
     * @dev Can be called by governance
     * @param executor_ array of accounts
     */
    function removeSwapExecutors(address[] calldata executor_) external;

    /**
     * @notice Adds new tokens to the allowed list
     * @dev Can be called by governance or admins
     * @param tokens_ array of tokens
     */
    function addAllowedTokens(address[] calldata tokens_) external;

    /**
     * @notice Removes tokens from the allowed list
     * @dev Can be called by governance or admins
     * @param tokens_ array of tokens
     */
    function removeAllowedTokens(address[] calldata tokens_) external;

    /**
     * @notice Adds new swap intervals to the allowed list
     * @dev Can be called by governance or admins
     * @param swapIntervals_ The new swap intervals
     */
    function addSwapIntervalsToAllowedList(uint32[] calldata swapIntervals_) external;

    /**
     * @notice Removes some swap intervals from the allowed list
     * @dev Can be called by governance or admins
     * @param swapIntervals_ The swap intervals to remove
     */
    function removeSwapIntervalsFromAllowedList(uint32[] calldata swapIntervals_) external;

    /**
     * @notice Sets a the fee vault address
     * @dev Can be called by governance
     * @param newVault_ New vault address
     */
    function setFeeVault(address newVault_) external;

    /**
     * @notice Sets a swap fee for different interval
     * @dev Can be called by governance
     * @dev Will revert with HighFee if the fee is higher than the maximum
     * @dev set it in multiple of 100 (1.5% = 150)
     * @param intervals_ Array of intervals
     * @param swapFee_ Array of fees in respect to intervals
     */
    function setSwapFee(uint32[] calldata intervals_, uint256[] calldata swapFee_) external;

    /**
     * @notice Sets a new platform fee ratio
     * @dev Can be called by governance
     * @dev Will revert with HighPlatformFeeRatio if given ratio is too high
     * @dev set it in multiple of 100 (1.5% = 150)
     * @param platformFeeRatio_ The new ratio
     */
    function setPlatformFeeRatio(uint256 platformFeeRatio_) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IDCAParameters {
    /* ========= VIEWS ========= */

    /// @notice Returns the byte representation of the set of active swap intervals for the given pair
    function activeSwapIntervals(address from_, address to_) external view returns (bytes1);

    /**
     * @notice Returns swapping information about a specific pair
     * @param swapInterval_ The byte representation of the swap interval to check
     */
    function swapData(address from_, address to_, bytes1 swapInterval_) external view 
        returns (uint256 performedSwaps, uint256 nextAmountToSwap, uint256 nextToNextSwap, uint256 lastSwappedAt);

    /// @notice Returns The difference of tokens to swap between a swap, and the previous one
    function swapAmountDelta(address from_, address to_, bytes1 swapInterval_, uint256 swapNo_) external view returns (uint256);

    /// @notice Returns the sum of the ratios reported in all swaps executed until the given swap number
    function accumRatio(address from_, address to_, bytes1 swapInterval_, uint256 swapNo_) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { PositionInfo, CreatePositionDetails } from "./../common/Types.sol";

interface IDCAPositionHandler {
    /* ========= EVENTS ========= */

    event Created(address indexed user, uint256 positionId, bool isNative);

    event CreatedBatched(address indexed user, uint256 finalIndex, uint256 noOfPositions, bool[] isNative);

    event Modified(address indexed user, uint256 positionId, uint256 rate, uint256 startingSwap, uint256 finalSwap, bool isNative);
    event Terminated(address indexed user, address indexed recipient, uint256 positionId, uint256 unswapped, uint256 swapped, bool isNative);
    event Withdrawn(address indexed user, address indexed recipient, uint256 positionId, uint256 swapped, bool isNative);
    event PositionOwnerUpdated(address indexed oldOwner, address indexed newOwner, uint256 positionId);

    /* ========= VIEWS ========= */

    /*
     * @notice Returns user position info
     * @param positionId_ The information about the user position
     */
    function userPositions(uint256 positionId_) external view returns (address owner, address from, address to, bytes1 swapIntervalMask, uint256 rate, uint256 swapWhereLastUpdated, uint256 startingSwap, uint256 finalSwap);

    /// @notice Returns total positions that have been created
    function totalCreatedPositions() external view returns (uint256);

    /*
     * @notice Returns position info
     * @dev swapsExecuted, swapsLeft, swapped, unswapped are also returned here
     * @param positionId_ The information about the position
     */
    function getPositionDetails(uint256 positionId_) external view returns (PositionInfo memory positionInfo);

    /* ========= USER FUNCTIONS ========= */

    /*
     * @notice Creates a new position
     * @dev can only be call if contract is not pause
     * @dev to use positions with native tokens use NATIVE_TOKEN as address
     * @dev native token will be internally wrapped to wNative tokens
     * @param details_ details for position creation
     */
    function createPosition(CreatePositionDetails calldata details_) external payable;

    /*
     * @notice Creates multiple new positions
     * @dev can only be call if contract is not pause
     * @dev to use positions with native tokens use NATIVE_TOKEN as address
     * @dev native token will be internally wrapped to wNative tokens
     * @param details_ array of details for position creation
     */
    function createBatchPositions(CreatePositionDetails[] calldata details_) external payable;

    /*
     * @notice Modify(increase/reduce/changeOnlyNoOfSwaps) position
     * @dev can only be call if contract is not pause
     * @param positionId_ The position's id
     * @param amount_ Amount of funds to add or remove to the position
     * @param noOfSwaps_ The new no of swaps
     * @param isIncrease_ Set it as true for increasing
     * @param isNative_ Set it as true for increasing/reducing using native token
     * @param permit_ permit calldata, erc20Permit, daiPermit, and permit2 both can be used here
     */
    function modifyPosition(uint256 positionId_, uint256 amount_, uint256 noOfSwaps_, bool isIncrease_, bool isNative_, bytes calldata permit_) external payable;

    /*
     * @notice Terminate a position and withdraw swapped and unswapped tokens
     * @param positionId_ The position's id
     * @param recipient_ account where tokens will be transferred
     * @param isNative_ Set it as true unwrap wNative to native token
     */
    function terminatePosition(uint256 positionId_, address recipient_, bool isNative_) external;

    /*
     * @notice Withdraw swapped tokens
     * @param positionId_ The position's id
     * @param recipient_ account where tokens will be transferred
     * @param isNative_ Set it as true unwrap wNative to native token
     */
    function withdrawPosition(uint256 positionId_, address recipient_, bool isNative_) external;

    /*
     * @notice Transfer position ownership to other account
     * @dev can only be call if contract is not pause
     * @param positionId_ The position's id
     * @param newOwner_ New owner to set
     */
    function transferPositionOwnership(uint256 positionId_, address newOwner_) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { SwapInfo, SwapDetails, Pair } from "./../common/Types.sol";

interface IDCASwapHandler {
    /* ========= EVENTS ========= */

    event Swapped(address indexed sender, address indexed rewardRecipient, SwapInfo[] swapInformation);
   
    event BlankSwapped(address indexed sender, address from, address to, bytes1 interval);

    /* ========= VIEWS ========= */

    /// @notice Returns the time after which next swap chan be done
    /// @param pairs_ The pairs that you want to swap.
    /// @return time after which swap can can be done
    function secondsUntilNextSwap(Pair[] calldata pairs_) external view returns (uint256[] memory);

    /// @notice Returns all information related to the next swap
    /// @dev Zero will returned for SwapInfo.receivedAmount
    /// @param pairs_ The pairs that you want to swap.
    /// @return The information about the next swap
    function getNextSwapInfo(Pair[] calldata pairs_) external view returns (SwapInfo[] memory);

    /* ========= RESTRICTED ========= */

    /// @notice Executes a swap
    /// @dev Can only be call by swapExecutors
    /// @param data_ Array of swap details
    /// @param rewardRecipient_ The address to send the reward to
    function swap(SwapDetails[] calldata data_, address rewardRecipient_) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./IDCAConfigHandler.sol";
import "./IDCAPositionHandler.sol";
import "./IDCASwapHandler.sol";
import "./IDCAParameters.sol";

interface IDZapDCA is IDCAParameters, IDCAConfigHandler, IDCAPositionHandler, IDCASwapHandler {
    /* ========= EVENTS ========= */

    event TokensRescued(address indexed to, address indexed token, uint256 amount);

    /* ========= OPEN ========= */

    /// @notice Receives and executes a batch of function calls on this contract.
    function batchCall(bytes[] calldata data_) external returns (bytes[] memory results);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IPermit2 {
 struct PermitDetails {
        address token;
        uint160 amount;
        uint48 expiration;
        uint48 nonce;
    }

    struct PermitSingle {
        PermitDetails details;
        address spender;
        uint256 sigDeadline;
    }

    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    function permit(
        address owner,
        PermitSingle memory permitSingle,
        bytes calldata signature
    ) external;

    function transferFrom(
        address from,
        address to,
        uint160 amount,
        address token
    ) external;

    function permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IWNative is IERC20 {
    function deposit() external payable;

    function withdraw(uint256) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { InvalidInterval, InvalidMask } from "./../common/Error.sol";

/// @title Intervals library
/// @notice Provides functions to easily convert from swap intervals to their byte representation and viceversa
library Intervals {
    /// @notice Takes a swap interval and returns its byte representation
    /// @dev Will revert with InvalidInterval if the swap interval is not valid
    /// @param swapInterval_ The swap interval
    /// @return The interval's byte representation
    // solhint-disable-next-line code-complexity
    function intervalToMask(uint32 swapInterval_) internal pure returns (bytes1) {
        if (swapInterval_ == 1 hours) return 0x01;
        if (swapInterval_ == 4 hours) return 0x02;
        if (swapInterval_ == 12 hours) return 0x04;
        if (swapInterval_ == 1 days) return 0x08;
        if (swapInterval_ == 3 days) return 0x10;
        if (swapInterval_ == 1 weeks) return 0x20;
        if (swapInterval_ == 2 weeks) return 0x40;
        if (swapInterval_ == 30 days) return 0x80;
        revert InvalidInterval();
    }

    /// @notice Takes a byte representation of a swap interval and returns the swap interval
    /// @dev Will revert with InvalidMask if the byte representation is not valid
    /// @param mask_ The byte representation
    /// @return The swap interval
    // solhint-disable-next-line code-complexity
    function maskToInterval(bytes1 mask_) internal pure returns (uint32) {
        if (mask_ == 0x01) return 1 hours;
        if (mask_ == 0x02) return 4 hours;
        if (mask_ == 0x04) return 12 hours;
        if (mask_ == 0x08) return 1 days;
        if (mask_ == 0x10) return 3 days;
        if (mask_ == 0x20) return 1 weeks;
        if (mask_ == 0x40) return 2 weeks;
        if (mask_ == 0x80) return 30 days;
        revert InvalidMask();
    }

    /// @notice Takes a byte representation of a set of swap intervals and returns which ones are in the set
    /// @dev Will always return an array of length 8, with zeros at the end if there are less than 8 intervals
    /// @param byte_ The byte representation
    /// @return intervals The swap intervals in the set
    function intervalsInByte(bytes1 byte_) internal pure returns (uint32[] memory intervals) {
        intervals = new uint32[](8);
        uint8 _index;
        bytes1 mask_ = 0x01;
        while (byte_ >= mask_ && mask_ > 0) {
            if (byte_ & mask_ != 0) intervals[_index++] = maskToInterval(mask_);
            mask_ <<= 1;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/Context.sol";

import { UnauthorizedCaller, ZeroAddress } from "../common/Error.sol";

abstract contract Governable is Context {
    address private _governance;

    event GovernanceChanged(address indexed formerGov, address indexed newGov);

    /**
     * @dev Throws if called by any account other than the governance.
     */
    modifier onlyGovernance() {
        if (governance() != _msgSender()) revert UnauthorizedCaller();
        _;
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial governance.
     */
    constructor(address governance_) {
        if (governance_ == address(0)) revert ZeroAddress();
        _governance = governance_;
        emit GovernanceChanged(address(0), governance_);
    }

    /**
     * @dev Returns the address of the current governance.
     */
    function governance() public view virtual returns (address) {
        return _governance;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newGov`).
     * Can only be called by the current governance.
     */
    function changeGovernance(address newGov) external virtual onlyGovernance {
        if (newGov == address(0)) revert ZeroAddress();
        emit GovernanceChanged(_governance, newGov);
        _governance = newGov;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { ZeroAddress, InvalidPermit, InvalidPermitData, InvalidPermitSender } from "./../common/Error.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import "./../interfaces/IDAIPermit.sol";

import "./../interfaces/IPermit2.sol";

abstract contract Permitable {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable PERMIT2;

    constructor(address permit2_) {
        if (permit2_ == address(0)) revert ZeroAddress();
        PERMIT2 = permit2_;
    }

    function _permit2Approve(address token_, bytes memory data_) internal {
        if(data_.length > 0) {
            (uint160 allowanceAmount, uint48 nonce, uint48 expiration, uint256 sigDeadline, bytes memory signature) = abi.decode(data_, (uint160, uint48, uint48, uint256, bytes));
            IPermit2(PERMIT2).permit(
                msg.sender, 
                IPermit2.PermitSingle(
                    IPermit2.PermitDetails(
                        token_,
                        allowanceAmount, 
                        expiration, 
                        nonce
                    ),
                    address(this),
                    sigDeadline
                ),
                signature
            );
        }
    }

    function _permit2TransferFrom(address token_, bytes memory data_, uint256 amount_) internal {
        (uint256 nonce, uint256 deadline, bytes memory signature) = abi.decode(data_, (uint256, uint256, bytes));
        IPermit2(PERMIT2).permitTransferFrom(
            IPermit2.PermitTransferFrom(
                IPermit2.TokenPermissions(token_, amount_),
                nonce,
                deadline
            ),
            IPermit2.SignatureTransferDetails(address(this), amount_),
            msg.sender,
            signature
        );
    }

    function _permit(address token_, bytes memory data_) internal {
        if (data_.length > 0) {
            bool success;
            
            if (data_.length == 32 * 7) {
                (success, ) = token_.call(abi.encodePacked(IERC20Permit.permit.selector, data_));
            } else if (data_.length == 32 * 8) {
                (success, ) = token_.call(abi.encodePacked(IDAIPermit.permit.selector, data_));
            } else {
                revert InvalidPermitData();
            }
            if (!success) revert InvalidPermit();
        }
    }
}