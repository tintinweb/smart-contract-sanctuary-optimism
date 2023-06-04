// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/IERC20Permit.sol)

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
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

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
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/IERC20Permit.sol";
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

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
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
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Compatible with tokens that require the approval to be set to
     * 0 before setting it to a non-zero value.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
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
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && Address.isContract(address(token));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
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
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
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
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
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
        return a + b;
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
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
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
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
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
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
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
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/******************************************************************************\
* Author: Nick Mudge <[email protected]> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

interface IDiamondCut {
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }
    // Add=0, Replace=1, Remove=2

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/******************************************************************************\
* Author: Nick Mudge <[email protected]> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";

// Remember to add the loupe functions from DiamondLoupeFacet to the diamond.
// The loupe functions are required by the EIP2535 Diamonds standard

error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);

library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.app.storage");

    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition; // position of facetAddress in facetAddresses array
    }

    struct DiamondStorage {
        // maps function selector to the facet address and
        // the position of the selector in the facetFunctionSelectors.selectors array
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // maps facet addresses to function selectors
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // facet addresses
        address[] facetAddresses;

        // array of slots of function selectors.
        // each slot holds 8 function selectors.
        // may need to change bytes32 to address.
        mapping(uint256 => bytes32) selectorSlots;
        // The number of function selectors in selectorSlots
        uint16 selectorCount;
        
        // Used to query if a contract implements an interface.
        // Used to implement ERC-165.
        mapping(bytes4 => bool) supportedInterfaces;
        // owner of the contract
        address contractOwner;
    }

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        require(msg.sender == diamondStorage().contractOwner, "LibDiamond: Must be contract owner");
    }

    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    // Internal function version of diamondCut
    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else {
                revert("LibDiamondCut: Incorrect FacetCutAction");
            }
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();        
        require(_facetAddress != address(0), "LibDiamondCut: Add facet can't be address(0)");
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);            
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress == address(0), "LibDiamondCut: Can't add function that already exists");
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();
        require(_facetAddress != address(0), "LibDiamondCut: Add facet can't be address(0)");
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress != _facetAddress, "LibDiamondCut: Can't replace function with same function");
            removeFunction(ds, oldFacetAddress, selector);
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();
        // if function does not exist then do nothing and return
        require(_facetAddress == address(0), "LibDiamondCut: Remove facet address must be address(0)");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            removeFunction(ds, oldFacetAddress, selector);
        }
    }

    function addFacet(DiamondStorage storage ds, address _facetAddress) internal {
        enforceHasContractCode(_facetAddress, "LibDiamondCut: New facet has no code");
        ds.facetFunctionSelectors[_facetAddress].facetAddressPosition = ds.facetAddresses.length;
        ds.facetAddresses.push(_facetAddress);
    }    


    function addFunction(DiamondStorage storage ds, bytes4 _selector, uint96 _selectorPosition, address _facetAddress) internal {
        ds.selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        ds.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    function removeFunction(DiamondStorage storage ds, address _facetAddress, bytes4 _selector) internal {        
        require(_facetAddress != address(0), "LibDiamondCut: Can't remove function that doesn't exist");
        // an immutable function is a function defined directly in a diamond
        require(_facetAddress != address(this), "LibDiamondCut: Can't remove immutable function");
        // replace selector with last selector, then delete last selector
        uint256 selectorPosition = ds.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = ds.facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;
        // if not the same then replace _selector with lastSelector
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            ds.facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }
        // delete the last selector
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[_selector];

        // if no more selectors for facet address then delete the facet address
        if (lastSelectorPosition == 0) {
            // replace facet address with last facet address and delete last facet address
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition = ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            ds.facetAddresses.pop();
            delete ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            return;
        }
        enforceHasContractCode(_init, "LibDiamondCut: _init address has no code");        
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                // bubble up error
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert InitializationFunctionReverted(_init, _calldata);
            }
        }
    }

    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author The Stoa Corporation Ltd.
    @title  Yield Facet
    @notice Provides logic for distributing and managing yield.
 */

import { Modifiers } from '../libs/LibAppStorage.sol';
import { PercentageMath } from '../libs/external/PercentageMath.sol';
import { LibToken } from '../libs/LibToken.sol';
import { LibReward } from '../libs/LibReward.sol';
import { LibVault } from '../libs/LibVault.sol';
import { IERC4626 } from '../interfaces/IERC4626.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract YieldFacet is Modifiers {
    using PercentageMath for uint256;

    /// @notice Function for updating fiAssets originating from vaults.
    ///
    /// @param  fiAsset The fiAsset to distribute yield earnings for.
    function rebase(
        address fiAsset
    )   public
        returns (uint256 assets, uint256 yield, uint256 shareYield)
    {
        require(
            s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
            'RewardFacet: Caller not Upkeep or Admin'
        );
        uint256 currentSupply = IERC20(fiAsset).totalSupply();
        if (currentSupply == 0) {
            emit LibToken.TotalSupplyUpdated(fiAsset, 0, 0, 1e18, 0);
            return (0, 0, 0); 
        }

        if (s.harvestable[s.vault[fiAsset]] == 1) LibVault._harvest(fiAsset);

        assets = LibToken._toFiDecimals(fiAsset, LibVault._totalValue(s.vault[fiAsset]));

        if (assets > currentSupply) {

            yield = assets - currentSupply;

            shareYield = yield.percentMul(1e4 - s.serviceFee[fiAsset]);

            LibToken._changeSupply(
                fiAsset,
                currentSupply + shareYield,
                yield,
                yield - shareYield
            );

            if (yield - shareYield > 0)
                LibToken._mint(fiAsset, s.feeCollector, yield - shareYield);
        } else {
            emit LibToken.TotalSupplyUpdated(
                fiAsset,
                assets,
                0,
                LibToken._getRebasingCreditsPerToken(fiAsset),
                0
            );
            return (assets, 0, 0);
        }
    }

    /// @dev    Opt to trigger the relevant route rather than a single migrate function
    ///         that has to deduce said route.
    function migrateVault(
        address fiAsset,
        address newVault
    )   external
        returns (bool)
    {
        if (
            IERC4626(s.vault[fiAsset]).asset() == IERC4626(newVault).asset()
        ) return migrateMutual(fiAsset, newVault); // U => U; D => D.
        else if (
            s.underlying[fiAsset] == IERC4626(s.vault[fiAsset]).asset() &&
            s.underlying[fiAsset] != IERC4626(newVault).asset()
        ) return migrateToDeriv(fiAsset, newVault); // U => D.
        else if (
            s.underlying[fiAsset] != IERC4626(s.vault[fiAsset]).asset() &&
            s.underlying[fiAsset] == IERC4626(newVault).asset()
        ) return migrateToUnderlying(fiAsset, newVault); // D => U.
        else return migrateToUnlikeDeriv(fiAsset, newVault); // D => D'.
    }

    /// @notice Function for migrating to a new Vault. The new Vault must support the
    ///         same underlyingAsset (e.g., USDC).
    ///
    /// @dev    Ensure that a buffer of the underlyingAsset resides in the Diamond
    ///         beforehand to account for slippage.
    ///
    /// @param  fiAsset     The fiAsset to migrate vault backing for.
    /// @param  newVault    The vault to migrate to (must adhere to ERC4626).
    /// @dev    U => U; D => D.
    function migrateMutual(
        address fiAsset,
        address newVault
    )   public
        returns (bool)
    {
        require(
            s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
            'RewardFacet: Caller not Upkeep or Admin'
        );
        // Pull funds from old vault.
        uint256 assets = IERC4626(s.vault[fiAsset]).redeem(
            IERC20(s.vault[fiAsset]).balanceOf(address(this)),
            address(this),
            address(this)
        );

        // Approve newVault spend for Diamond.
        SafeERC20.safeApprove(
            IERC20(IERC4626(s.vault[fiAsset]).asset()),
            newVault,
            assets + s.buffer[fiAsset]
        );

        // Deploy funds to new vault.
        LibVault._wrap(
            assets + s.buffer[fiAsset],
            newVault,
            address(this)
        );

        require(
            // Vaults use same asset, therefore same decimals.
            assets <= LibVault._totalValue(newVault),
            'RewardFacet: Vault migration slippage exceeded'
        );
        emit LibVault.VaultMigration(
            fiAsset,
            s.vault[fiAsset],
            newVault,
            assets,
            LibVault._totalValue(newVault)
        );

        // Update vault for fiAsset.
        s.vault[fiAsset] = newVault;

        rebase(fiAsset);

        return true;
    }

    /// @dev    U => D.
    function migrateToDeriv(
        address fiAsset,
        address newVault
    )   public
        EXTGuardOn
        returns (bool)
    {
        require(
            s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
            'RewardFacet: Caller not Upkeep or Admin'
        );
        // Obtain U.
        uint256 assets = IERC4626(s.vault[fiAsset]).redeem(
            IERC20(s.vault[fiAsset]).balanceOf(address(this)),
            address(this),
            address(this)
        );

        // Get D from U.
        (bool success, ) = address(this).call(abi.encodeWithSelector(
            s.derivParams[s.vault[fiAsset]].toDeriv,
            assets + s.buffer[fiAsset]  // Convert U buffer to D here.
        )); // Will fail here if set vault is not using a derivative.
        require(success, 'RewardFacet: Underlying to derivative operation failed');
        require(s.RETURN_ASSETS > 0, 'RewardFacet: Zero return assets received');

        // Approve newVault spend for Diamond.
        SafeERC20.safeApprove(
            IERC20(IERC4626(newVault).asset()),
            newVault,
            s.RETURN_ASSETS
        );

        (success, ) = address(this).call(abi.encodeWithSelector(
            s.derivParams[s.vault[fiAsset]].convertToUnderlying,
            LibVault._getAssets(
                // Deploy D.
                LibVault._wrap(
                    s.RETURN_ASSETS,
                    s.vault[fiAsset],
                    address(this)
                ),
                s.vault[fiAsset]
            )
        ));
        require(success, 'SupplyFacet: Convert to underlying operation failed');
        require(s.RETURN_ASSETS > 0, 'RewardFacet: Zero return assets received');
        s.RETURN_ASSETS = 0; // Reset.

        require(
            // Ensure same decimals for accurate comparison.
            LibToken._toFiDecimals(fiAsset, assets) <=
                LibToken._toFiDecimals(fiAsset, LibVault._totalValue(newVault)),
            'AdminFacet: Vault migration slippage exceeded'
        );
        emit LibVault.VaultMigration(
            fiAsset,
            s.vault[fiAsset],
            newVault,
            assets,
            LibVault._totalValue(newVault)
        );

        // Update vault for fiAsset.
        s.vault[fiAsset] = newVault;

        rebase(fiAsset);

        return true;
    }

    /// @dev    D => U.
    function migrateToUnderlying(
        address fiAsset,
        address newVault
    )   public
        EXTGuardOn
        returns (bool)
    {
        require(
            s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
            'RewardFacet: Caller not Upkeep or Admin'
        );

        // Get U from D.
        (bool success, ) = address(this).call(abi.encodeWithSelector(
            s.derivParams[s.vault[fiAsset]].toUnderlying,
            // Obtain D.
            IERC4626(s.vault[fiAsset]).redeem( // E.g., 100 USDC-LP.
                IERC20(s.vault[fiAsset]).balanceOf(address(this)),
                address(this),
                address(this)
            )
        )); // Will fail here if set vault is not using a derivative.
        require(success, 'SupplyFacet: Underlying to derivative operation failed');
        require(s.RETURN_ASSETS > 0, 'SupplyFacet: Zero return assets received');

        // Approve newVault spend for Diamond.
        SafeERC20.safeApprove(
            IERC20(IERC4626(newVault).asset()),
            newVault,
            s.RETURN_ASSETS + s.buffer[fiAsset] // Include buffer here.
        );

        // Deploy U. Remaining logic same as 'migrateMutual()'.
        LibVault._wrap(
            s.RETURN_ASSETS + s.buffer[fiAsset],
            newVault,
            address(this)
        );

        require(
            // '_totalValue()' returns underlying equivalent, therefore same decimals.
            s.RETURN_ASSETS <= LibVault._totalValue(newVault),
            'AdminFacet: Vault migration slippage exceeded'
        );
        emit LibVault.VaultMigration(
            fiAsset,
            s.vault[fiAsset],
            newVault,
            s.RETURN_ASSETS,
            LibVault._totalValue(newVault)
        );
        s.RETURN_ASSETS = 0;

        // Update vault for fiAsset.
        s.vault[fiAsset] = newVault;

        rebase(fiAsset);

        return true;
    }

    /// @dev D => D' (= D => U => D').
    function migrateToUnlikeDeriv(
        address fiAsset,
        address newVault
    )   public
        EXTGuardOn
        returns (bool)
    {
        require(
            s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
            'RewardFacet: Caller not Upkeep or Admin'
        );
        // Obtain D.
        uint256 assets = IERC4626(s.vault[fiAsset]).redeem(
            IERC20(s.vault[fiAsset]).balanceOf(address(this)),
            address(this),
            address(this)
        );

        // Get U from D.
        (bool success, ) = address(this).call(abi.encodeWithSelector(
            s.derivParams[s.vault[fiAsset]].toUnderlying,
            assets  // Buffer already exists in underlying so no need to convert.
        )); // Will fail here if set vault is not using a derivative.
        require(success, 'SupplyFacet: Underlying to derivative operation failed');
        require(s.RETURN_ASSETS > 0, 'SupplyFacet: Zero return assets received');
        assets = s.RETURN_ASSETS;
        s.RETURN_ASSETS = 0; // Need to reset for next operation.

        // Get D' from U.
        (success, ) = address(this).call(abi.encodeWithSelector(
            s.derivParams[newVault].toDeriv,
            assets + s.buffer[fiAsset]  // Convert U buffer to D' here.
        )); // Will fail here if new vault is not using a derivative.
        require(success, 'SupplyFacet: Underlying to derivative operation failed');
        require(s.RETURN_ASSETS > 0, 'SupplyFacet: Zero return assets received');

        // Approve new vault spend for Diamond.
        SafeERC20.safeApprove(
            IERC20(IERC4626(newVault).asset()),
            newVault,
            s.RETURN_ASSETS
        );

        // Deploy D'.
        (success, ) = address(this).call(abi.encodeWithSelector(
            s.derivParams[newVault].convertToUnderlying,
            LibVault._getAssets(
                LibVault._wrap(
                    s.RETURN_ASSETS,
                    newVault,
                    address(this)
                ),
                s.vault[fiAsset]
            )
        ));
        require(success, 'SupplyFacet: Convert to underlying operation failed');
        require(s.RETURN_ASSETS > 0, 'SupplyFacet: Zero return assets received');
        s.RETURN_ASSETS = 0; // Reset.

        require(
            // Ensure same decimals for accurate comparison.
            LibToken._toFiDecimals(fiAsset, assets) <=
                LibToken._toFiDecimals(fiAsset, LibVault._totalValue(newVault)),
            'AdminFacet: Vault migration slippage exceeded'
        );
        emit LibVault.VaultMigration(
            fiAsset,
            s.vault[fiAsset],
            newVault,
            assets,
            LibVault._totalValue(newVault)
        );

        // Update vault for fiAsset.
        s.vault[fiAsset] = newVault;

        rebase(fiAsset);

        return true;
    }

    function setBuffer(
        address fiAsset,
        uint256 buffer
    )   external
        onlyAdmin
        returns (bool)
    {
        s.buffer[fiAsset] = buffer;
        return true;
    }

    /// @dev Only for setting up a new fiAsset. 'migrateVault()' must be used otherwise.
    function setVault(
        address fiAsset,
        address vault
    )   external
        onlyAdmin
        returns (bool)
    {
        require(
            s.vault[fiAsset] == address(0),
            'RewardFacet: fiAsset must not already link with a Vault'
        );
        s.vault[fiAsset] = vault;
        return true;
    }

    function rebaseOptIn(
        address fiAsset
    )   external
        onlyAdmin
        returns (bool)
    {
        LibToken._rebaseOptIn(fiAsset);
        return true;
    }

    function rebaseOptOut(
        address fiAsset
    )   external
        onlyAdmin
        returns (bool)
    {
        LibToken._rebaseOptOut(fiAsset);
        return true;
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ERC4626 Interface
 * @author yearn.finance
 */
interface IERC4626 is IERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(
        address indexed caller,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    function asset() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver)
        external
        returns (uint256 shares); /* {
        Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }*/

    /**
     * @dev Addition for executing harvest in the context of COFI.
     */
    function harvest() external returns (uint256, uint256);

    function mint(uint256 shares, address receiver)
        external
        returns (uint256 assets); /* {
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }*/

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares); /* {
        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }*/

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets); /* {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }*/

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function totalAssets() external view returns (uint256);

    function convertToShares(uint256 assets) external view returns (uint256); /* {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
    }*/

    function convertToAssets(uint256 shares) external view returns (uint256); /* {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
    }*/

    function previewDeposit(uint256 assets) external view returns (uint256); /* {
        return convertToShares(assets);
    }*/

    function previewMint(uint256 shares) external view returns (uint256); /* {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
    }*/

    function previewWithdraw(uint256 assets) external view returns (uint256); /* {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
    }*/

    function previewRedeem(uint256 shares) external view returns (uint256); /* {
        return convertToAssets(shares);
    }*/

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(address) external view returns (uint256); /* {
        return type(uint256).max;
    }*/

    function maxMint(address) external view returns (uint256); /* {
        return type(uint256).max;
    }*/

    function maxWithdraw(address owner) external view returns (uint256); /* {
        return convertToAssets(balanceOf[owner]);
    }*/

    function maxRedeem(address owner) external view returns (uint256); /* {
        return balanceOf[owner];
    }*/

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/
    /*
    function beforeWithdraw(uint256 assets, uint256 shares) internal {}

    function afterDeposit(uint256 assets, uint256 shares) internal {}
    */
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @author The Stoa Corporation Ltd.
/// @title  Fi Token Interface
/// @notice Interface for executing functions on Fi tokens.
interface IFiToken {

    function mint(address to, uint amount) external;

    function mintOptIn(address to, uint amount) external;

    function burn(address from, uint amount) external;

    function redeem(address from, address to, uint256 amount) external;

    function changeSupply(uint newTotalSupply) external;

    function getYieldEarned(address account) external view returns (uint256);

    function rebasingCreditsPerTokenHighres() external view returns (uint256);

    function creditsToBal(uint256 amount) external view returns (uint256);

    function rebaseOptIn() external;

    function rebaseOptOut() external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title PercentageMath library
 * @author Aave
 * @notice Provides functions to perform percentage calculations
 * @dev Percentages are defined by default with 2 decimals of precision (100.00). The precision is indicated by PERCENTAGE_FACTOR
 * @dev Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down.
 */
library PercentageMath {
  // Maximum percentage factor (100.00%)
  uint256 internal constant PERCENTAGE_FACTOR = 1e4;

  // Half percentage factor (50.00%)
  uint256 internal constant HALF_PERCENTAGE_FACTOR = 0.5e4;

  /**
   * @notice Executes a percentage multiplication
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated
   * @return result value percentmul percentage
   */
  function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
    // to avoid overflow, value <= (type(uint256).max - HALF_PERCENTAGE_FACTOR) / percentage
    assembly {
      if iszero(
        or(
          iszero(percentage),
          iszero(gt(value, div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage)))
        )
      ) {
        revert(0, 0)
      }

      result := div(add(mul(value, percentage), HALF_PERCENTAGE_FACTOR), PERCENTAGE_FACTOR)
    }
  }

  /**
   * @notice Executes a percentage division
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated
   * @return result value percentdiv percentage
   */
  function percentDiv(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
    // to avoid overflow, value <= (type(uint256).max - halfPercentage) / PERCENTAGE_FACTOR
    assembly {
      if or(
        iszero(percentage),
        iszero(iszero(gt(value, div(sub(not(0), div(percentage, 2)), PERCENTAGE_FACTOR))))
      ) {
        revert(0, 0)
      }

      result := div(add(mul(value, PERCENTAGE_FACTOR), div(percentage, 2)), percentage)
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { LibDiamond } from ".././core/libs/LibDiamond.sol";

struct YieldPointsCapture {
    uint256 yield;
    uint256 points;
}

struct RewardStatus {
    uint8   initClaimed;
    uint8   referClaimed;
    uint8   referDisabled;
}

/// @dev    'spender' address must be provided in LibVault.
struct DerivParams {
    address spender;                // Spender for the 'toDeriv()' method.
    bytes4  toDeriv;                // Method for winding to the derivative asset.
    bytes4  toUnderlying;           // Method for unwinding to the underlying asset.
    bytes4  convertToDeriv;         // Method for retrieving the equiv. number of derivative.
    bytes4  convertToUnderlying;    // Method for retrieving the equiv. number of underlying.
    address[] add;                  // Additional addresses that may be required.
    uint256[] num;                  // Additional integers that may be required.
}

struct AppStorage {

    /*//////////////////////////////////////////////////////////////
                        COFI STABLECOIN PARAMS
    //////////////////////////////////////////////////////////////*/

    // E.g., COFI => 20*10**18. Applies to underlyingAsset (e.g., DAI).
    mapping(address => uint256) minDeposit;

    // E.g., COFI => 20*10**18. Applies to underlyingAsset (e.g., DAI).
    mapping(address => uint256) minWithdraw;

    // E.g., COFI => 10bps. Applies to fiAsset only.
    mapping(address => uint256) mintFee;

    // E.g., COFI => 10bps. Applies to fiAsset only.
    mapping(address => uint256) redeemFee;

    // E.g., COFI => 1,000bps. Applies to fiAsset only.
    mapping(address => uint256) serviceFee;

    // E.g., COFI => 1,000,000bps (100x / 1*10**18 yield earned).
    mapping(address => uint256) pointsRate;

    // E.g., COFI => 100 USDC. Buffer for migrations. Applies to underlyingAsset.
    mapping(address => uint256) buffer;

    // E.g., COFI => yvDAI; fiETH => maETH; fiBTC => maBTC.
    mapping(address => address) vault;

    // E.g., COFI => USDC; ETHFI => wETH; BTCFI => wBTC.
    // Need to specify as vault may use different underlying (e.g., USDC-LP).
    mapping(address => address) underlying;

    // E.g., COFI => 1.
    mapping(address => uint8)   mintEnabled;

    // E.g., COFI => 1.
    mapping(address => uint8)   redeemEnabled;

    // Decimals of the underlying asset (e.g., USDC => 6).
    mapping(address => uint256) decimals;

    /*//////////////////////////////////////////////////////////////
                            OTHER STORAGE
    //////////////////////////////////////////////////////////////*/

    // E.g., wmooHopUSDC => DerivParams.
    mapping(address => DerivParams) derivParams;

    // If rebase operation should harvest vault beforehand.
    mapping(address => uint8) harvestable;

    // Reward for first-time depositors. Setting to 0 deactivates it.
    uint256 initReward;

    // Reward for referrals. Setting to 0 deactivates it.
    uint256 referReward;

    mapping(address => RewardStatus) rewardStatus;

    // Yield points capture (determined via yield earnings from fiAsset).
    // E.g., 0x1234... => COFI => YieldPointsCapture.
    mapping(address => mapping(address => YieldPointsCapture)) YPC;

    // External points capture (to yield earnings). Maps to account only (not fiAsset).
    mapping(address => uint256) XPC;

    mapping(address => uint8)   isWhitelisted;

    mapping(address => uint8)   isAdmin;

    mapping(address => uint8)   isUpkeep;

    // Gnosis Safe contract.
    address feeCollector;

    address owner;

    address backupOwner;

    uint8 EXT_GUARD;

    uint256 RETURN_ASSETS;
}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        // bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := 0
        }
    }

    function abs(int256 x) internal pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }
}

contract Modifiers {
    AppStorage internal s;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier isWhitelisted() {
        require(s.isWhitelisted[msg.sender] == 1, 'Caller not whitelisted');
        _;
    }

    modifier minDeposit(uint256 amount, address fiAsset) {
        require(amount >= s.minDeposit[fiAsset], 'Insufficient deposit amount');
        _;
    }

    modifier minWithdraw(uint256 amount, address fiAsset) {
        require(amount >= s.minWithdraw[fiAsset], 'Insufficient withdraw amount');
        _;
    }

    modifier mintEnabled(address fiAsset) {
        require(s.mintEnabled[fiAsset] == 1, 'Mint not enabled');
        _;
    }

    modifier redeemEnabled(address fiAsset) {
        require(s.redeemEnabled[fiAsset] == 1, 'Redeem not enabled');
        _;
    }
    
    modifier onlyAdmin() {
        require(s.isAdmin[msg.sender] == 1, 'Caller not Admin');
        _;
    }

    /// @dev Low-level call operation available only for public/external functions.
    modifier EXTGuard() {
        require(s.EXT_GUARD == 1, 'Not accessible to external accounts');
        _;
    }

    modifier EXTGuardOn() {
        s.EXT_GUARD = 1;
        _;
        s.EXT_GUARD = 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AppStorage, LibAppStorage } from "./LibAppStorage.sol";

library LibReward {

    /// @notice Emitted when external points are distributed (not tied to yield).
    ///
    /// @param  account The recipient of the points.
    /// @param  amount  The amount of points distributed.
    event RewardDistributed(address indexed account, uint256 amount);

    /// @notice Emitted when a referral is executed.
    ///
    /// @param  referral    The account receiving the referral reward.
    /// @param  account     The account using the referral.
    /// @param  amount      The amount of points distributed to the referral account.
    event Referral(address indexed referral, address indexed account, uint256 amount);

    /// @notice Distributes rewards not tied to yield.
    ///
    /// @param  account The recipient.
    /// @param  points  The amount of points distributed.
    function _reward(
        address account,
        uint256 points
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        s.XPC[account] += points;
        emit RewardDistributed(account, points);
    }

    /// @notice Reward distributed for each new first deposit.
    function _initReward(
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (
            // If there is a sign-up reward.
            s.initReward != 0 &&
            // If the user has not already claimed their sign-up reward.
            s.rewardStatus[msg.sender].initClaimed == 0
        ) {
            // Provide user with sign-up reward.
            s.XPC[msg.sender] += s.initReward;
            emit RewardDistributed(msg.sender, s.initReward);
            // Mark user as having claimed their sign-up reward.
            s.rewardStatus[msg.sender].initClaimed == 1;
        }
    }

    /// @notice Reward distributed for each referral.
    ///
    /// @param  referral    The referral account.
    function _referReward(
        address referral
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (
            // If there is a refer reward.
            s.referReward != 0 &&
            // If the user has not already claimed a refer reward.
            s.rewardStatus[msg.sender].referClaimed == 0 &&
            // If the referrer is a whitelisted account.
            s.isWhitelisted[referral] == 1 &&
            // If referrals are enabled.
            s.rewardStatus[referral].referDisabled != 1
        ) {
            // Apply referral to user.
            s.XPC[msg.sender] += s.referReward;
            emit RewardDistributed(msg.sender, s.referReward);
            // Provide referrer with reward.
            s.XPC[referral] += s.referReward;
            emit RewardDistributed(referral, s.referReward);
            // Mark user as having claimed their one-time referral.
            s.rewardStatus[msg.sender].referClaimed == 1;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AppStorage, LibAppStorage } from "./LibAppStorage.sol";
import { PercentageMath } from "./external/PercentageMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IFiToken } from ".././interfaces/IFiToken.sol";
import 'contracts/token/utils/StableMath.sol';

library LibToken {
    using PercentageMath for uint256;
    using StableMath for uint256;

    /// @notice Emitted when a transfer is executed.
    ///
    /// @param  asset           The asset transferred (underlyingAsset, yieldAsset, or fiAsset).
    /// @param  amount          The amount transferred.
    /// @param  transferFrom    The account the asset was transferred from.
    /// @param  recipient       The recipient of the transfer.
    event Transfer(address indexed asset, uint256 amount, address indexed transferFrom, address indexed recipient);

    /// @notice Emitted when a fiAsset is minted.
    ///
    /// @param  fiAsset The address of the minted fiAsset.
    /// @param  amount  The amount of fiAssets minted.
    /// @param  to      The recipient of the minted fiAssets.
    event Mint(address indexed fiAsset, uint256 amount, address indexed to);

    /// @notice Emitted when a fiAsset is burned.
    ///
    /// @param  fiAsset The address of the burned fiAsset.
    /// @param  amount  The amount of fiAssets burned.
    /// @param  from    The account burned from.
    event Burn(address indexed fiAsset, uint256 amount, address indexed from);

    /// @notice Emitted when a fiAsset supply update is executed.
    ///
    /// @param  fiAsset The fiAsset with updated supply.
    /// @param  assets  The new total supply.
    /// @param  yield   The amount of yield added.
    /// @param  rCPT    Rebasing credits per token of fiAsset contract (used to calc interest rate).
    /// @param  fee     The service fee captured, which is a share of the yield generated.
    event TotalSupplyUpdated(address indexed fiAsset, uint256 assets, uint256 yield, uint256 rCPT, uint256 fee);

    /// @notice Emitted when a deposit action is executed.
    ///
    /// @param  asset       The asset deposited (e.g., USDC).
    /// @param  amount      The amount deposited.
    /// @param  depositFrom The account assets were transferred from.
    /// @param  fee         The mint fee captured.
    event Deposit(address indexed asset, uint256 amount, address indexed depositFrom, uint256 fee);

    /// @notice Emitted when a withdrawal action is executed.
    ///
    /// @param  asset       The asset being withdrawn (e.g., USDC).
    /// @param  amount      The amount withdrawn.
    /// @param  depositFrom The account fiAssets were transferred from.
    /// @param  fee         The redeem fee captured.
    event Withdraw(address indexed asset, uint256 amount, address indexed depositFrom, uint256 fee);

    /// @notice Executes a transferFrom operation in the context of Stoa.
    ///
    /// @param  asset           The asset to transfer.
    /// @param  amount          The amount to transfer.
    /// @param  transferFrom    The account to transfer from, must have approved spender.
    /// @param  recipient       The recipient of the transfer.
    function _transferFrom(
        address asset,
        uint256 amount,
        address transferFrom,
        address recipient
    )   internal {

        SafeERC20.safeTransferFrom(
            IERC20(asset),
            transferFrom,
            recipient,
            amount
        );
        emit Transfer(asset, amount, transferFrom, recipient);
    }

    /// @notice Executes a transfer operation in the context of Stoa.
    ///
    /// @param  asset       The asset to transfer.
    /// @param  amount      The amount to transfer.
    /// @param  recipient   The recipient of the transfer.
    function _transfer(
        address asset,
        uint256 amount,
        address recipient
    ) internal {

        SafeERC20.safeTransfer(
            IERC20(asset),
            recipient,
            amount
        );
        emit Transfer(asset, amount, address(this), recipient);
    }

    /// @notice Executes a mint operation in the context of COFI.
    ///
    /// @param  fiAsset The fiAsset to mint.
    /// @param  to      The account to mint to.
    /// @param  amount  The amount of fiAssets to mint.
    function _mint(
        address fiAsset,
        address to,
        uint256 amount
    ) internal {

        IFiToken(fiAsset).mint(to, amount);
        emit Mint(fiAsset, amount, to);
    }


    /// @notice Opts in recipient being minted to.
    ///
    /// @param  fiAsset The fiAsset to mint.
    /// @param  to      The account to mint to.
    /// @param  amount  The amount of fiAssets to mint.
    function _mintOptIn(
        address fiAsset,
        address to,
        uint256 amount
    ) internal {

        IFiToken(fiAsset).mintOptIn(to, amount);
        emit Mint(fiAsset, amount, to);
    }

    /// @notice Executes a burn operation in the context of COFI.
    ///
    /// @param  fiAsset The fiAsset to burn.
    /// @param  from    The account to burn from.
    /// @param  amount  The amount of fiAssets to burn.
    function _burn(
        address fiAsset,
        address from,
        uint256 amount
    ) internal {

        IFiToken(fiAsset).burn(from, amount);
        emit Burn(fiAsset, amount, from);
    }

    /// @notice Calls redeem operation on FiToken contract.
    /// @dev    Skips approval check.
    function _redeem(
        address fiAsset,
        address from,
        uint256 amount
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        IFiToken(fiAsset).redeem(from, s.feeCollector, amount);
    }

    /// @notice Updates the total supply of the fiAsset.
    function _changeSupply(
        address fiAsset,
        uint256 amount,
        uint256 yield,
        uint256 fee
    ) internal {
        
        IFiToken(fiAsset).changeSupply(amount);
        emit TotalSupplyUpdated(
            fiAsset,
            amount,
            yield,
            IFiToken(fiAsset).rebasingCreditsPerTokenHighres(),
            fee
        );
    }

    function _getRebasingCreditsPerToken(
        address fiAsset
    ) internal view returns (uint256) {

        return IFiToken(fiAsset).rebasingCreditsPerTokenHighres();
    }

    /// @notice Returns the mint fee for a given fiAsset.
    ///
    /// @param  fiAsset The fiAsset to mint.
    /// @param  amount  The amount of fiAssets to mint.
    function _getMintFee(
        address fiAsset,
        uint256 amount
    ) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return amount.percentMul(s.mintFee[fiAsset]);
    }

    /// @notice Returns the redeem fee for a given fiAsset.
    ///
    /// @param  fiAsset The fiAsset to submit for redemption.
    /// @param  amount  The amount of fiAssets to submit for redemption.
    function _getRedeemFee(
        address fiAsset,
        uint256 amount
    ) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return amount.percentMul(s.redeemFee[fiAsset]);
    }

    /// @notice Opts contract into receiving rebases.
    ///
    /// @param  fiAsset The fiAsset to opt-in to rebases for.
    function _rebaseOptIn(
        address fiAsset
    ) internal {

        IFiToken(fiAsset).rebaseOptIn();
    }

    /// @notice Opts contract out of receiving rebases.
    ///
    /// @param  fiAsset The fiAsset to opt-out of rebases for.
    function _rebaseOptOut(
        address fiAsset
    ) internal {
        
        IFiToken(fiAsset).rebaseOptOut();
    }

    /// @notice Retrieves yield earned of fiAsset for account.
    ///
    /// @param  account The account to enquire for.
    /// @param  fiAsset The fiAsset to check account's yield for.
    function _getYieldEarned(
        address account,
        address fiAsset
    ) internal view returns (uint256) {
        
        return IFiToken(fiAsset).getYieldEarned(account);
    }

    function _toFiDecimals(
        address fiAsset,
        uint256 amount
    ) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return amount.scaleBy(18, s.decimals[s.underlying[fiAsset]]);
    }

    function _toUnderlyingDecimals(
        address fiAsset,
        uint256 amount
    ) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return amount.scaleBy(s.decimals[s.underlying[fiAsset]], 18);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AppStorage, LibAppStorage } from "./LibAppStorage.sol";
import { IERC4626 } from ".././interfaces/IERC4626.sol";

library LibVault {

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a wrap operation is executed.
    ///
    /// @param  amount      The amount of underlyingAssets wrapped.
    /// @param  depositFrom The account which supplied the underlyingAssets.
    /// @param  vault       The ERC4626 Vault.
    /// @param  shares      The amount of shares minted.
    event Wrap(uint256 amount, address indexed depositFrom, address indexed vault, uint256 shares);

    /// @notice Emitted when an unwrap operation is executed.
    ///
    /// @param  amount      The amount of fiAssets redeemed.
    /// @param  shares      The amount of shares burned.
    /// @param  vault       The ERC4626 Vault.
    /// @param  assets      The amount of underlyingAssets received from the Vault.
    /// @param  recipient   The recipient of the underlyingAssets.
    event Unwrap(uint256 amount, uint256 shares, address indexed vault, uint256 assets, address indexed recipient);

    /// @notice Emitted when a vault migration is executed.
    ///
    /// @param  fiAsset     The fiAsset to migrate underlyingAssets for.
    /// @param  oldVault    The vault migrated from.
    /// @param  newVault    The vault migrated to.
    /// @param  oldAssets   The amount of assets pre-migration.
    /// @param  newAssets   The amount of assets post-migration.
    event VaultMigration(address indexed fiAsset, address indexed oldVault, address indexed newVault, uint256 oldAssets, uint256 newAssets);

    /// @notice Emitted when a harvest operation is executed (usually immediately prior to a rebase).
    ///
    /// @param fiAsset  The fiAsset being harvested for.
    /// @param vault    The actual vault where the harvest operation resides.
    /// @param assets   The amount of assets deposited.
    /// @param shares   The amount of shares returned from the deposit operation.
    event Harvest(address indexed fiAsset, address indexed vault, uint256 assets, uint256 shares);

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    function _getAssets(
        uint256 shares,
        address vault
    ) internal view returns (uint256 assets) {

        assets = IERC4626(vault).previewRedeem(shares);
    }

    function _getShares(
        uint256 assets,
        address vault
    ) internal view returns (uint256 shares) {

        shares = IERC4626(vault).previewDeposit(assets);
    }

    /// @notice Gets total value of Diamond's holding of shares from the relevant Vault.
    function _totalValue(
        address vault
    ) internal returns (uint256 assets) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // I.e., if vault is using a derivative.
        if (s.derivParams[vault].toUnderlying != 0) {
            // Sets RETURN_ASSETS to equivalent number of underlying.
            (bool success, ) = address(this).call(abi.encodeWithSelector(
                s.derivParams[vault].convertToUnderlying,
                IERC4626(vault).maxWithdraw(address(this))
            ));
            require(success, 'LibVault: Convert to underlying operation failed');
            assets = s.RETURN_ASSETS;
            s.RETURN_ASSETS = 0;
        }
        else assets = IERC4626(vault).maxWithdraw(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                            STATE CHANGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Wraps an underlyingAsset into shares via a Vault.
    /// @dev    Shares reside at the Diamond at all times.
    ///
    /// @param  amount      The amount of underlyingAssets to wrap.
    /// @param  vault       The ERC4626 Vault.
    /// @param  depositFrom The account supplying underlyingAssets from.
    function _wrap(
        uint256 amount,
        address vault,
        address depositFrom
    ) internal returns (uint256 shares) {

        shares = IERC4626(vault).deposit(amount, address(this));
        emit Wrap(amount, depositFrom, vault, shares);
    }

    /// @notice Unwraps shares into underlyingAssets via the relevant Vault.
    ///
    /// @param  amount      The amount of fiAssets to redeem (target 1:1 correlation to underlyingAssets).
    /// @param  vault       The ERC4626 Vault.
    /// @param  recipient   The recipient of the underlyingAssets.
    function _unwrap(
        uint256 amount,
        address vault,
        address recipient
    ) internal returns (uint256 assets) {

        // Retrieve the corresponding number of shares for the amount of fiAssets provided.
        uint256 shares = IERC4626(vault).previewDeposit(amount);    // Need to convert from USDC to USDC-LP

        assets = IERC4626(vault).redeem(shares, recipient, address(this));
        emit Unwrap(amount, shares, vault, assets, recipient);
    }

    function _harvest(
        address fiAsset
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        (uint256 assets, uint256 shares) = IERC4626(s.vault[fiAsset]).harvest();
        if (assets == 0 || shares == 0) return;
        emit Harvest(fiAsset, s.vault[fiAsset], assets, shares);
    }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.17;

import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Based on StableMath from Stability Labs Pty. Ltd.
// https://github.com/mstable/mStable-contracts/blob/master/contracts/shared/StableMath.sol

library StableMath {
    using SafeMath for uint256;

    /**
     * @dev Scaling unit for use in specific calculations,
     * where 1 * 10**18, or 1e18 represents a unit '1'
     */
    uint256 private constant FULL_SCALE = 1e18;

    /***************************************
                    Helpers
    ****************************************/

    /**
     * @dev Adjust the scale of an integer
     * @param to Decimals to scale to
     * @param from Decimals to scale from
     */
    function scaleBy(
        uint256 x,
        uint256 to,
        uint256 from
    ) internal pure returns (uint256) {
        if (to > from) {
            x = x.mul(10**(to - from));
        } else if (to < from) {
            x = x.div(10**(from - to));
        }
        return x;
    }

    /***************************************
               Precise Arithmetic
    ****************************************/

    /**
     * @dev Multiplies two precise units, and then truncates by the full scale
     * @param x Left hand input to multiplication
     * @param y Right hand input to multiplication
     * @return Result after multiplying the two inputs and then dividing by the shared
     *         scale unit
     */
    function mulTruncate(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulTruncateScale(x, y, FULL_SCALE);
    }

    /**
     * @dev Multiplies two precise units, and then truncates by the given scale. For example,
     * when calculating 90% of 10e18, (10e18 * 9e17) / 1e18 = (9e36) / 1e18 = 9e18
     * @param x Left hand input to multiplication
     * @param y Right hand input to multiplication
     * @param scale Scale unit
     * @return Result after multiplying the two inputs and then dividing by the shared
     *         scale unit
     */
    function mulTruncateScale(
        uint256 x,
        uint256 y,
        uint256 scale
    ) internal pure returns (uint256) {
        // e.g. assume scale = fullScale
        // z = 10e18 * 9e17 = 9e36
        uint256 z = x.mul(y);
        // return 9e36 / 1e18 = 9e18
        return z.div(scale);
    }

    /**
     * @dev Multiplies two precise units, and then truncates by the full scale, rounding up the result
     * @param x Left hand input to multiplication
     * @param y Right hand input to multiplication
     * @return Result after multiplying the two inputs and then dividing by the shared
     *          scale unit, rounded up to the closest base unit.
     */
    function mulTruncateCeil(uint256 x, uint256 y)
        internal
        pure
        returns (uint256)
    {
        // e.g. 8e17 * 17268172638 = 138145381104e17
        uint256 scaled = x.mul(y);
        // e.g. 138145381104e17 + 9.99...e17 = 138145381113.99...e17
        uint256 ceil = scaled.add(FULL_SCALE.sub(1));
        // e.g. 13814538111.399...e18 / 1e18 = 13814538111
        return ceil.div(FULL_SCALE);
    }

    /**
     * @dev Precisely divides two units, by first scaling the left hand operand. Useful
     *      for finding percentage weightings, i.e. 8e18/10e18 = 80% (or 8e17)
     * @param x Left hand input to division
     * @param y Right hand input to division
     * @return Result after multiplying the left operand by the scale, and
     *         executing the division on the right hand input.
     */
    function divPrecisely(uint256 x, uint256 y)
        internal
        pure
        returns (uint256)
    {
        // e.g. 8e18 * 1e18 = 8e36
        uint256 z = x.mul(FULL_SCALE);
        // e.g. 8e36 / 10e18 = 8e17
        return z.div(y);
    }

    function abs(int256 x) internal pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }
}