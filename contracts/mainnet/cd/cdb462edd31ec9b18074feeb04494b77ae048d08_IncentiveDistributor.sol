/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-26
*/

// Sources flattened with hardhat v2.10.2 https://hardhat.org

// File @openzeppelin/contracts/security/[email protected]

// -License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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
abstract contract ReentrancyGuard {
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

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
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
}


// File @openzeppelin/contracts/token/ERC20/[email protected]

// -License-Identifier: MIT
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


// File @openzeppelin/contracts/token/ERC20/extensions/[email protected]

// -License-Identifier: MIT
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


// File @openzeppelin/contracts/utils/[email protected]

// -License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

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
        return functionCall(target, data, "Address: low-level call failed");
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
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
}


// File @openzeppelin/contracts/token/ERC20/utils/[email protected]

// -License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;



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
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


// File contracts/libraries/FullMath.sol

// -License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @notice Source - https://github.com/sushiswap/StakingContract/blob/master/src/libraries/FullMath.sol
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
/// @dev Adapted to pragma solidity 0.8 from https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/FullMath.sol
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
        unchecked {
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
            uint256 twos = (0 - denominator) & denominator;
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


// File contracts/libraries/PackedUint144.sol

// -License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

/// @notice Source - https://github.com/sushiswap/StakingContract/blob/master/src/libraries/PackedUint144.sol
library PackedUint144 {
    uint256 private constant MAX_UINT24 = type(uint24).max;
    uint256 private constant MAX_UINT48 = type(uint48).max;
    uint256 private constant MAX_UINT72 = type(uint72).max;
    uint256 private constant MAX_UINT96 = type(uint96).max;
    uint256 private constant MAX_UINT120 = type(uint120).max;
    uint256 private constant MAX_UINT144 = type(uint144).max;

    error NonZero();
    error FullyPacked();

    function pushUint24Value(uint144 packedUint144, uint24 value)
        internal
        pure
        returns (uint144)
    {
        if (value == 0) revert NonZero(); // Not strictly necessairy for our use-case since value (incentiveId) can't be 0.
        if (packedUint144 > MAX_UINT120) revert FullyPacked();
        return (packedUint144 << 24) + value;
    }

    function countStoredUint24Values(uint144 packedUint144)
        internal
        pure
        returns (uint256)
    {
        if (packedUint144 == 0) return 0;
        if (packedUint144 <= MAX_UINT24) return 1;
        if (packedUint144 <= MAX_UINT48) return 2;
        if (packedUint144 <= MAX_UINT72) return 3;
        if (packedUint144 <= MAX_UINT96) return 4;
        if (packedUint144 <= MAX_UINT120) return 5;
        return 6;
    }

    function getUint24ValueAt(uint144 packedUint144, uint256 i)
        internal
        pure
        returns (uint24)
    {
        return uint24(packedUint144 >> (i * 24));
    }

    function removeUint24ValueAt(uint144 packedUint144, uint256 i)
        internal
        pure
        returns (uint144)
    {
        if (i > 5) return packedUint144;
        uint256 rightMask = MAX_UINT144 >> (24 * (6 - i));
        uint256 leftMask = (~rightMask) << 24;
        uint256 left = packedUint144 & leftMask;
        uint256 right = packedUint144 & rightMask;
        return uint144((left >> 24) | right);
    }
}


// File contracts/IncentiveDistributor.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;




contract IncentiveDistributor is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using PackedUint144 for uint144;

    struct Incentive {
        address creator;            // 1st slot
        address token;              // 2nd slot
        address rewardToken;        // 3rd slot
        uint32 endTime;             // 3rd slot
        uint256 rewardPerLiquidity; // 4th slot
        uint32 lastRewardTime;      // 5th slot
        uint112 rewardRemaining;    // 5th slot
        uint112 liquidityStaked;    // 5th slot
    }

    uint256 public incentiveCount;

    // Starts with 1. Zero is an invalid incentive.
    mapping(uint256 => Incentive) public incentives;

    /// @dev rewardPerLiquidityLast[user][incentiveId]
    /// @dev Semantic overload: if value is zero user isn't subscribed to the incentive.
    mapping(address => mapping(uint256 => uint256)) public rewardPerLiquidityLast;

    /// @dev userStakes[user][stakedToken]
    mapping(address => mapping(address => UserStake)) public userStakes;

    // Incentive count won't be greater than type(uint24).max on mainnet.
    // This means we can use uint24 values to identify incentives.
    struct UserStake {
        uint112 liquidity;
        uint144 subscribedIncentiveIds; // Six packed uint24 values.
    }

    error InvalidTimeFrame();
    error IncentiveOverflow();
    error AlreadySubscribed();
    error AlreadyUnsubscribed();
    error NotSubscribed();
    error OnlyCreator();
    error NoToken();
    error InvalidInput();
    error BatchError(bytes innerErorr);
    error InsufficientStakedAmount();
    error NotStaked();
    error InvalidIndex();

    event IncentiveCreated(address indexed token, address indexed rewardToken, address indexed creator, uint256 id, uint256 amount, uint256 startTime, uint256 endTime);
    event IncentiveUpdated(uint256 indexed id, int256 changeAmount, uint256 newStartTime, uint256 newEndTime);
    event Stake(address indexed token, address indexed user, uint256 amount);
    event Unstake(address indexed token, address indexed user, uint256 amount);
    event Subscribe(uint256 indexed id, address indexed user);
    event Unsubscribe(uint256 indexed id, address indexed user);
    event Claim(uint256 indexed id, address indexed user, uint256 amount);

    function createIncentive(
        address token,
        address rewardToken,
        uint112 rewardAmount,
        uint32 startTime,
        uint32 endTime
    ) external nonReentrant returns (uint256 incentiveId) {
        if (rewardAmount <= 0) revert InvalidInput();

        if (startTime < block.timestamp) startTime = uint32(block.timestamp);

        if (startTime >= endTime) revert InvalidTimeFrame();

        unchecked { incentiveId = ++incentiveCount; }

        if (incentiveId > type(uint24).max) revert IncentiveOverflow();

        _saferTransferFrom(rewardToken, rewardAmount);

        incentives[incentiveId] = Incentive({
            creator: msg.sender,
            token: token,
            rewardToken: rewardToken,
            lastRewardTime: startTime,
            endTime: endTime,
            rewardRemaining: rewardAmount,
            liquidityStaked: 0,
            // Initial value of rewardPerLiquidity can be arbitrarily set to a non-zero value.
            rewardPerLiquidity: type(uint256).max / 2
        });

        emit IncentiveCreated(token, rewardToken, msg.sender, incentiveId, rewardAmount, startTime, endTime);
    }

    function updateIncentive(
        uint256 incentiveId,
        int112 changeAmount,
        uint32 newStartTime,
        uint32 newEndTime
    ) external nonReentrant {
        Incentive storage incentive = incentives[incentiveId];

        if (msg.sender != incentive.creator) revert OnlyCreator();

        _accrueRewards(incentive);

        if (newStartTime != 0) {
            if (newStartTime < block.timestamp) newStartTime = uint32(block.timestamp);
            incentive.lastRewardTime = newStartTime;
        }

        if (newEndTime != 0) {
            if (newEndTime < block.timestamp) newEndTime = uint32(block.timestamp);
            incentive.endTime = newEndTime;
        }

        if (incentive.lastRewardTime >= incentive.endTime) revert InvalidTimeFrame();

        if (changeAmount > 0) {
            incentive.rewardRemaining += uint112(changeAmount);
            IERC20(incentive.rewardToken).safeTransferFrom(msg.sender, address(this), uint112(changeAmount));
        } else if (changeAmount < 0) {
            uint112 transferOut = uint112(-changeAmount);
            if (transferOut > incentive.rewardRemaining) transferOut = incentive.rewardRemaining;
            unchecked { incentive.rewardRemaining -= transferOut; }
            IERC20(incentive.rewardToken).safeTransfer(msg.sender, transferOut);
        }

        emit IncentiveUpdated(incentiveId, changeAmount, incentive.lastRewardTime, incentive.endTime);
    }

    function stakeAndSubscribeToIncentives(
        address token,
        uint112 amount,
        uint256[] memory incentiveIds,
        bool transferExistingRewards
    ) external {
        stakeToken(token, amount, transferExistingRewards);

        uint256 n = incentiveIds.length;
        for (uint256 i = 0; i < n; i = _increment(i)) {
            subscribeToIncentive(incentiveIds[i]);
        }
    }

    function stakeToken(address token, uint112 amount, bool transferExistingRewards) public nonReentrant {
        _saferTransferFrom(token, amount);

        UserStake storage userStake = userStakes[msg.sender][token];

        uint112 previousLiquidity = userStake.liquidity;
        userStake.liquidity += amount;
        uint256 n = userStake.subscribedIncentiveIds.countStoredUint24Values();

        for (uint256 i = 0; i < n; i = _increment(i)) { // Loop through already subscribed incentives.
            uint256 incentiveId = userStake.subscribedIncentiveIds.getUint24ValueAt(i);

            Incentive storage incentive = incentives[incentiveId];

            _accrueRewards(incentive);

            if (transferExistingRewards) {
                _claimReward(incentive, incentiveId, previousLiquidity);
            } else {
                _saveReward(incentive, incentiveId, previousLiquidity, userStake.liquidity);
            }
            incentive.liquidityStaked += amount;
        }

        emit Stake(token, msg.sender, amount);
    }

    function unstakeToken(address token, uint112 amount, bool transferExistingRewards) external nonReentrant {
        UserStake storage userStake = userStakes[msg.sender][token];

        uint112 previousLiquidity = userStake.liquidity;
        if (amount > previousLiquidity) revert InsufficientStakedAmount();

        userStake.liquidity -= amount;

        uint256 n = userStake.subscribedIncentiveIds.countStoredUint24Values();
        for (uint256 i = 0; i < n; i = _increment(i)) {
            uint256 incentiveId = userStake.subscribedIncentiveIds.getUint24ValueAt(i);
            Incentive storage incentive = incentives[incentiveId];

            _accrueRewards(incentive);

            if (transferExistingRewards || userStake.liquidity == 0) {
                _claimReward(incentive, incentiveId, previousLiquidity);
            } else {
                _saveReward(incentive, incentiveId, previousLiquidity, userStake.liquidity);
            }

            incentive.liquidityStaked -= amount;
        }

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Unstake(token, msg.sender, amount);
    }

    function subscribeToIncentive(uint256 incentiveId) public nonReentrant {
        if (incentiveId > incentiveCount || incentiveId <= 0) revert InvalidInput();

        if (rewardPerLiquidityLast[msg.sender][incentiveId] != 0) revert AlreadySubscribed();

        Incentive storage incentive = incentives[incentiveId];

        if (userStakes[msg.sender][incentive.token].liquidity <= 0) revert NotStaked();

        _accrueRewards(incentive);

        rewardPerLiquidityLast[msg.sender][incentiveId] = incentive.rewardPerLiquidity;
        UserStake storage userStake = userStakes[msg.sender][incentive.token];
        userStake.subscribedIncentiveIds = userStake.subscribedIncentiveIds.pushUint24Value(uint24(incentiveId));
        incentive.liquidityStaked += userStake.liquidity;

        emit Subscribe(incentiveId, msg.sender);
    }

    /// @param incentiveIndex ∈ [0,5]
    function unsubscribeFromIncentive(address token, uint256 incentiveIndex, bool ignoreRewards) external nonReentrant {
        UserStake storage userStake = userStakes[msg.sender][token];

        if (incentiveIndex >= userStake.subscribedIncentiveIds.countStoredUint24Values()) revert InvalidIndex();

        uint256 incentiveId = userStake.subscribedIncentiveIds.getUint24ValueAt(incentiveIndex);
        if (rewardPerLiquidityLast[msg.sender][incentiveId] == 0) revert AlreadyUnsubscribed();

        Incentive storage incentive = incentives[incentiveId];

        _accrueRewards(incentive);

        /// In case there is a token specific issue we can ignore rewards.
        if (!ignoreRewards) _claimReward(incentive, incentiveId, userStake.liquidity);

        rewardPerLiquidityLast[msg.sender][incentiveId] = 0;
        incentive.liquidityStaked -= userStake.liquidity;
        userStake.subscribedIncentiveIds = userStake.subscribedIncentiveIds.removeUint24ValueAt(incentiveIndex);

        emit Unsubscribe(incentiveId, msg.sender);
    }

    function accrueRewards(uint256 incentiveId) external nonReentrant {
        if (incentiveId > incentiveCount || incentiveId <= 0) revert InvalidInput();

        _accrueRewards(incentives[incentiveId]);
    }

    function claimRewards(uint256[] calldata incentiveIds) external nonReentrant returns (uint256[] memory rewards) {
        uint256 n = incentiveIds.length;
        rewards = new uint256[](n);

        for(uint256 i = 0; i < n; i = _increment(i)) {
            if (incentiveIds[i] > incentiveCount || incentiveIds[i] <= 0) revert InvalidInput();
            
            Incentive storage incentive = incentives[incentiveIds[i]];

            _accrueRewards(incentive);

            rewards[i] = _claimReward(incentive, incentiveIds[i], userStakes[msg.sender][incentive.token].liquidity);
        }
    }

    function _accrueRewards(Incentive storage incentive) internal {
        uint256 lastRewardTime = incentive.lastRewardTime;

        uint256 endTime = incentive.endTime;

        unchecked {
            uint256 maxTime = block.timestamp < endTime ? block.timestamp : endTime;

            if (incentive.liquidityStaked > 0 && lastRewardTime < maxTime) {
                uint256 totalTime = endTime - lastRewardTime;
                uint256 passedTime = maxTime - lastRewardTime;
                uint256 reward = uint256(incentive.rewardRemaining) * passedTime / totalTime;

                // Increments of less than type(uint224).max - overflow is unrealistic.
                incentive.rewardPerLiquidity += reward * type(uint112).max / incentive.liquidityStaked;
                incentive.rewardRemaining -= uint112(reward);
                incentive.lastRewardTime = uint32(maxTime);
            } else if (incentive.liquidityStaked == 0 && lastRewardTime < block.timestamp) {
                incentive.lastRewardTime = uint32(maxTime);
            }
        }
    }

    function _claimReward(Incentive storage incentive, uint256 incentiveId, uint112 usersLiquidity) internal returns (uint256 reward) {
        reward = _calculateReward(incentive, incentiveId, usersLiquidity);
        rewardPerLiquidityLast[msg.sender][incentiveId] = incentive.rewardPerLiquidity;
        IERC20(incentive.rewardToken).safeTransfer(msg.sender, reward);

        emit Claim(incentiveId, msg.sender, reward);
    }

    // We offset the rewardPerLiquidityLast snapshot so that the current reward is included next time we call _claimReward.
    function _saveReward(Incentive storage incentive, uint256 incentiveId, uint112 usersLiquidity, uint112 newLiquidity) internal returns (uint256 reward) {
        reward = _calculateReward(incentive, incentiveId, usersLiquidity);
        uint256 rewardPerLiquidityDelta = reward * type(uint112).max / newLiquidity;
        rewardPerLiquidityLast[msg.sender][incentiveId] = incentive.rewardPerLiquidity - rewardPerLiquidityDelta;
    }

    function _calculateReward(Incentive storage incentive, uint256 incentiveId, uint112 usersLiquidity) internal view returns (uint256 reward) {
        uint256 userRewardPerLiquidtyLast = rewardPerLiquidityLast[msg.sender][incentiveId];

        if (userRewardPerLiquidtyLast == 0) revert NotSubscribed();

        uint256 rewardPerLiquidityDelta;
        unchecked { rewardPerLiquidityDelta = incentive.rewardPerLiquidity - userRewardPerLiquidtyLast; }
        reward = FullMath.mulDiv(rewardPerLiquidityDelta, usersLiquidity, type(uint112).max);
    }

    function _saferTransferFrom(address token, uint256 amount) internal {
        if (token.code.length == 0) revert NoToken();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    function _increment(uint256 i) internal pure returns (uint256) {
        unchecked { return i + 1; }
    }
}