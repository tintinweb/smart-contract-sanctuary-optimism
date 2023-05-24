// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

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
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

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
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

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

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
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
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(
                oldAllowance >= value,
                "SafeERC20: decreased allowance below zero"
            );
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(
                token,
                abi.encodeWithSelector(
                    token.approve.selector,
                    spender,
                    newAllowance
                )
            );
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
        require(
            nonceAfter == nonceBefore + 1,
            "SafeERC20: permit did not succeed"
        );
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

        bytes memory returndata = address(token).functionCall(
            data,
            "SafeERC20: low-level call failed"
        );
        if (returndata.length > 0) {
            // Return data is optional
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
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
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
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
    function functionCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        return
            functionCallWithValue(
                target,
                data,
                0,
                "Address: low-level call failed"
            );
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
        return
            functionCallWithValue(
                target,
                data,
                value,
                "Address: low-level call with value failed"
            );
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
        require(
            address(this).balance >= value,
            "Address: insufficient balance for call"
        );
        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        return
            verifyCallResultFromTarget(
                target,
                success,
                returndata,
                errorMessage
            );
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data
    ) internal view returns (bytes memory) {
        return
            functionStaticCall(
                target,
                data,
                "Address: low-level static call failed"
            );
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
        return
            verifyCallResultFromTarget(
                target,
                success,
                returndata,
                errorMessage
            );
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        return
            functionDelegateCall(
                target,
                data,
                "Address: low-level delegate call failed"
            );
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
        return
            verifyCallResultFromTarget(
                target,
                success,
                returndata,
                errorMessage
            );
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

    function _revert(
        bytes memory returndata,
        string memory errorMessage
    ) private pure {
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
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

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
    function tryAdd(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
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
    function trySub(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
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
    function tryMul(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
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
    function tryDiv(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
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
    function tryMod(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
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
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;
pragma abicoder v2;

interface IRouter {
    function pairFor(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (address pair);

    function getReserves(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (uint reserveA, uint reserveB);

    function getAmountOut(
        uint amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint amount, bool stable);

    struct route {
        address from;
        address to;
        bool stable;
    }

    function getAmountsOut(
        uint amountIn,
        route[] memory routes
    ) external view returns (uint[] memory amounts);

    function isPair(address pair) external view returns (bool);

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired
    ) external view returns (uint amountA, uint amountB, uint liquidity);

    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity
    ) external view returns (uint amountA, uint amountB);

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function swapExactTokensForTokensSimple(
        uint amountIn,
        uint amountOutMin,
        address tokenFrom,
        address tokenTo,
        bool stable,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        route[] calldata routes,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        uint amountOutMin,
        route[] calldata routes,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
}

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;

import "../libraries/helpers/AddressId.sol";

interface IAddressRegistry {
    event SetAddress(
        address indexed setter,
        uint256 indexed id,
        address newAddress
    );

    function getAddress(uint256 id) external view returns (address);
}

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;
pragma abicoder v2;

interface IVaultFactory {
    event NewVault(
        address indexed token0,
        address indexed token1,
        bool stable,
        address vaultAddress,
        uint256 indexed vaultId
    );

    function vaults(uint256 vaultId) external view returns (address);
}

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;
pragma abicoder v2;

import "./IVeloVaultPositionManager.sol";
import "../libraries/types/VaultTypes.sol";

interface IVeloVault {
    /// @notice token0 address of the related velo pair
    function token0() external view returns (address);

    /// @notice token1 address of the related velo pair
    function token1() external view returns (address);

    /// @notice stable of the related velo pair
    function stable() external view returns (bool);

    function getVaultState()
        external
        view
        returns (VaultTypes.VeloVaultState memory vault);

    function adminSetVault(bytes calldata params) external;

    function transferManagerTo(
        address caller,
        uint256 positionId,
        address newManager
    ) external;

    function setRangeStop(
        address caller,
        uint256 positionId,
        bool enable,
        uint256 minPrice,
        uint256 maxPrice
    ) external;

    function getPositionValue(
        uint256 vaultPositionId
    ) external view returns (VaultTypes.VeloPositionValue memory positionValue);

    function getPosition(
        uint256 vaultPositionId
    ) external view returns (VaultTypes.VeloPosition memory position);

    function newOrInvestToVaultPosition(
        IVeloVaultPositionManager.NewOrInvestToVaultPositionParams
            calldata params,
        address caller
    ) external returns (uint256 positionId, uint256 liquidity);

    function closeAndRepayPartially(
        IVeloVaultPositionManager.CloseVaultPositionPartiallyParams
            calldata params,
        address caller
    ) external returns (uint256, uint256, uint256, uint256);

    function closeAndRepayOutOfRangePosition(
        IVeloVaultPositionManager.CloseVaultPositionPartiallyParams
            calldata params
    )
        external
        returns (
            address manager,
            uint256 price,
            uint256 amount0Left,
            uint256 amount1Left,
            uint256 fee0,
            uint256 fee1
        );

    struct LiquidateState {
        address manager;
        uint256 price;
        uint256 amount0Left;
        uint256 amount1Left;
        uint256 amount0Repaid;
        uint256 amount1Repaid;
        uint256 repaidValue;
        uint256 removedLiquidityValue;
        uint256 liquidateFeeValue;
        uint256 equivalentRepaid0;
        uint256 equivalentRepaid1;
        uint256 liquidatorReceive0;
        uint256 liquidatorReceive1;
        uint256 liquidateFee0;
        uint256 liquidateFee1;
    }

    function repayAndLiquidatePositionPartially(
        IVeloVaultPositionManager.LiquidateVaultPositionPartiallyParams
            calldata params,
        address caller
    ) external returns (LiquidateState memory);

    function exactRepay(
        IVeloVaultPositionManager.ExactRepayParam calldata params,
        address caller
    )
        external
        returns (
            address positionMananger,
            uint256 amount0Repaid,
            uint256 amount1Repaid
        );

    function claimRewardsAndReInvestToLiquidity(
        IVeloVaultPositionManager.InvestEarnedFeeToLiquidityParam
            calldata params
    )
        external
        returns (
            uint256 liquidity,
            uint256 fee0,
            uint256 fee1,
            uint256[] memory rewards
        );
}

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;

import "../external/velodrome/contracts/interfaces/IRouter.sol";
import "../libraries/types/VaultTypes.sol";

interface IVeloVaultPositionManager {
    /// @notice New a vaultPosition
    /// @param vaultId The id of the vault
    /// @param manager The manager of the position, usually the caller
    /// @param vaultPositionId The id of the newed position
    event NewVaultPosition(
        uint256 indexed vaultId,
        uint256 indexed vaultPositionId,
        address indexed manager
    );

    /// @notice Invest to a position
    /// @param vaultId The id of the vault
    /// @param vaultPositionId The id of the new vaultPosition
    /// @param manager The manager of the vaultPosition, usually the caller
    /// @param amount0Invest The amount of token0 user wants to transfer
    /// @param amount1Invest The amount of token1 user wants to transfer
    /// @param amount0Borrow The amount of token0 user wants to borrow
    /// @param amount1Borrow The amount of token1 user wants to borrow
    /// @param liquidity The amount of lp tokens added to the pool
    event InvestToVaultPosition(
        uint256 indexed vaultId,
        uint256 indexed vaultPositionId,
        address indexed manager,
        uint256 amount0Invest,
        uint256 amount1Invest,
        uint256 amount0Borrow,
        uint256 amount1Borrow,
        uint256 liquidity
    );

    /// @notice Close a position partially
    /// @param vaultId The id of the vault
    /// @param vaultPositionId The id of the vaultPosition
    /// @param manager The manager of the vaultPosition
    /// @param percent The percentage of the vault user want to close
    /// @param amount0Received The amount of token0 user received after close
    /// @param amount1Received The amount of token1 user received after close
    /// @param amount0Repaid The amount of token0 user repaid when close
    /// @param amount1Repaid The amount of token1 user repaid when close
    event CloseVaultPositionPartially(
        uint256 indexed vaultId,
        uint256 indexed vaultPositionId,
        address indexed manager,
        uint16 percent,
        uint256 amount0Received,
        uint256 amount1Received,
        uint256 amount0Repaid,
        uint256 amount1Repaid
    );

    /// @notice Close a position which is outof price range
    /// @param vaultId The id of the vault
    /// @param vaultPositionId The id of the vaultPosition
    /// @param manager The manager of the vaultPosition
    /// @param caller The caller initiate range stop
    /// @param percent The percentage of the vault user want to close
    /// @param amount0Received The amount of token0 user received after close
    /// @param amount1Received The amount of token1 user received after close
    /// @param fee0 The caller received
    /// @param fee1 The caller received
    event CloseOutOfRangePosition(
        uint256 indexed vaultId,
        uint256 indexed vaultPositionId,
        address indexed manager,
        address caller,
        uint16 percent,
        uint64 timestamp,
        uint256 price,
        uint256 amount0Received,
        uint256 amount1Received,
        uint256 fee0,
        uint256 fee1
    );

    /// @notice Liquidate a position partially
    /// @param vaultId The id of the vault
    /// @param vaultPositionId The id of the vaultPosition
    /// @param manager The manager of the vaultPosition
    /// @param liquidator The caller of the function
    /// @param percent The percentage of the vault user want to liquidate
    /// @param amount0Left The amount of token0 transferred to the position's manager after close
    /// @param amount1Left The amount of token1 transferred to the position's manager after close
    /// @param liquidateFee0 The amount of token0 for liquidation bonus
    /// @param liquidateFee1 The amount of token1 for liquidation bonus
    event LiquidateVaultPositionPartially(
        uint256 indexed vaultId,
        uint256 indexed vaultPositionId,
        address indexed manager,
        address liquidator,
        uint16 percent,
        uint64 timestamp,
        uint256 price,
        uint256 debtValueOfPosition,
        uint256 liquidityValueOfPosition,
        uint256 amount0Left,
        uint256 amount1Left,
        uint256 liquidateFee0,
        uint256 liquidateFee1
    );

    /// @notice Liquidate a position partially
    /// @param vaultId The id of the vault
    /// @param vaultPositionId The id of the vaultPosition
    /// @param manager The manager of the vaultPosition
    /// @param caller The initiator of the repay action
    /// @param amount0Repaid The amount of token0 repaid
    /// @param amount1Repaid The amount of token1 repaid
    event ExactRepay(
        uint256 indexed vaultId,
        uint256 indexed vaultPositionId,
        address indexed manager,
        address caller,
        uint256 amount0Repaid,
        uint256 amount1Repaid
    );

    /// @notice InvestEarnedFeeToLiquidity
    /// @param vaultId The id of the vault
    /// @param caller The initiator of the repay action
    /// @param liquidityAdded The liquidity amount added by adding rewards to the pool
    /// @param fee0 The fee in token0
    /// @param fee1 The fee in token1
    /// @param rewards The rewards claimed
    event InvestEarnedFeeToLiquidity(
        uint256 indexed vaultId,
        address indexed caller,
        uint256 liquidityAdded,
        uint256 fee0,
        uint256 fee1,
        uint256[] rewards
    );

    event FeePaid(
        uint256 indexed vaultId,
        address indexed asset,
        uint256 indexed feeType,
        uint256 amount
    );

    function getVaultPosition(
        uint256 vaultId,
        uint256 vaultPositionId
    ) external view returns (VaultTypes.VeloPositionValue memory state);

    function getVault(
        uint256 vaultId
    ) external view returns (VaultTypes.VeloVaultState memory);

    struct PayToVaultCallbackParams {
        uint256 vaultId;
        uint256 amount0;
        uint256 amount1;
        address payer;
    }

    /// @notice Callback functions called by the vault to pay tokens to the vault contract.
    /// The caller to this function must be the vault contract
    function payToVaultCallback(
        PayToVaultCallbackParams calldata params
    ) external;

    /// @notice Callback functions called by the vault to pay fees to treasury.
    /// The caller to this function must be the vault contract
    function payFeeToTreasuryCallback(
        uint256 vaultId,
        address asset,
        uint256 amount,
        uint256 feeType
    ) external;

    /// @notice The param struct used in function newOrInvestToVaultPosition(param)
    struct NewOrInvestToVaultPositionParams {
        // vaultId
        uint256 vaultId;
        // The vaultPositionId of the vaultPosition to invest
        // 0  if open a new vaultPosition
        uint256 vaultPositionId;
        // The amount of token0 user want to invest
        uint256 amount0Invest;
        // The amount of token0 user want to borrow
        uint256 amount0Borrow;
        // The amount of token1 user want to invest
        uint256 amount1Invest;
        // The amount of token1 user want to borrow
        uint256 amount1Borrow;
        // The minimal amount of token0 should be added to the liquidity
        // This value will be used when call mint() or addLiquidity() of uniswap V3 pool
        uint256 amount0Min;
        // The minimal amount of token1 should be added to the liquidity
        // This value will be used when call mint() or addLiquidity() of uniswap V3 pool
        uint256 amount1Min;
        // The deadline of the tx
        uint256 deadline;
        // The swapExecutor to swap tokens
        uint256 swapExecutorId;
        // The swap path to swap tokens
        bytes swapPath;
    }

    /// @notice Open a new vaultPosition or invest to a existed vault position
    /// @param params The parameters necessary, encoded as `NewOrInvestToVaultPositionParams` in calldata
    function newOrInvestToVaultPosition(
        NewOrInvestToVaultPositionParams calldata params
    ) external payable;

    /// @notice The param struct used in function closeVaultPositionPartially(param)
    struct CloseVaultPositionPartiallyParams {
        // vaultId
        uint256 vaultId;
        // The Id of vaultPosition to be closed
        uint256 vaultPositionId;
        // The percentage of the entire position to close
        uint16 percent;
        // The receiver of the left tokens when close then position
        // Or the fee receiver when used in `closeOutOfRangePosition`
        address receiver;
        bool receiveNativeETH;
        // The receiveType of the left tokens
        // 0: only receive token0, swap all left token1 to token0
        // 1: only receive token1, swap all left token0 to token1
        // 2: receive tokens according to minimal swap rule
        uint8 receiveType;
        // The minimal token0 receive after remove the liquidity, will be used when call removeLiquidity() of uniswap
        uint256 minAmount0WhenRemoveLiquidity;
        // The minimal token1 receive after remove the liquidity, will be used when call removeLiquidity() of uniswap
        uint256 minAmount1WhenRemoveLiquidity;
        // The deadline of the tx, the tx will be reverted if the _blockTimestamp() > deadline
        uint256 deadline;
        // The swapExecutor to swap tokens
        uint256 swapExecutorId;
        // The swap path to swap tokens
        bytes swapPath;
    }

    /// @notice Close a vaultPosition partially
    /// @param params The parameters necessary, encoded as `CloseVaultPositionPartiallyParams` in calldata
    function closeVaultPositionPartially(
        CloseVaultPositionPartiallyParams calldata params
    ) external payable;

    /// @notice The param struct used in function closeVaultPositionPartially(param)
    struct LiquidateVaultPositionPartiallyParams {
        // vaultId
        uint256 vaultId;
        // The Id of vaultPosition to be closed
        uint256 vaultPositionId;
        // The percentage of the entire position to close
        uint16 percent;
        // The liquidator's fee receiver
        address receiver;
        bool receiveNativeETH;
        // The receiveType of the left tokens
        // 0: only receive token0, swap all left token1 to token0
        // 1: only receive token1, swap all left token0 to token1
        // 2: receive tokens according to minimal swap rule
        uint8 receiveType;
        // The minimal token0 receive after remove the liquidity, will be used when call removeLiquidity() of uniswap
        uint256 minAmount0WhenRemoveLiquidity;
        // The minimal token1 receive after remove the liquidity, will be used when call removeLiquidity() of uniswap
        uint256 minAmount1WhenRemoveLiquidity;
        // The deadline of the tx, the tx will be reverted if the _blockTimestamp() > deadline
        uint256 deadline;
        // The maximum amount of token0 to repay debts
        uint256 maxRepay0;
        // The maximum amount of token1 to repay debts
        uint256 maxRepay1;
        // The swapExecutor to swap tokens
        uint256 swapExecutorId;
        // The swap path to swap tokens
        bytes swapPath;
    }

    /// @notice Liquidate a vaultPosition partially
    /// @param params The parameters necessary, encoded as `CloseVaultPositionPartiallyParam` in calldata
    function liquidateVaultPositionPartially(
        LiquidateVaultPositionPartiallyParams calldata params
    ) external payable;

    struct InvestEarnedFeeToLiquidityParam {
        // vaultId
        uint256 vaultId;
        // The compound fee receive
        address compoundFeeReceiver;
        IRouter.route[][] routes;
        bool receiveNativeETH;
        // The deadline of the tx, the tx will be reverted if the _blockTimestamp() > deadline
        uint256 deadline;
    }

    /// @notice Invest the earned fee by the position to liquidity
    /// The manager of the position can call this function with no compound fee charged
    /// If the manager allow others to compound the fee, there will be a small fee charged  as bonus for the caller
    function investEarnedFeeToLiquidity(
        InvestEarnedFeeToLiquidityParam calldata params
    ) external payable;

    struct ExactRepayParam {
        // vaultId
        uint256 vaultId;
        // The Id of vaultPosition to be closed
        uint256 vaultPositionId;
        // The max amount of token0 to repay
        uint256 amount0ToRepay;
        // The max amount of token1 to repay
        uint256 amount1ToRepay;
        // whether receive nativeETH or WETH when there are un-repaid ETH
        bool receiveNativeETH;
        // The deadline of the tx, the tx will be reverted if the _blockTimestamp() > deadline
        uint256 deadline;
    }

    /// @notice Repay exact value of debts
    function exactRepay(
        ExactRepayParam calldata params
    ) external payable returns (uint256, uint256);

    /// @notice Transfer the position's manager to another wallet
    /// Must be called by the current manager of the posistion
    /// @param vaultId The Id of the vault
    /// @param vaultPositionId The Id of the position
    /// @param newManager The new address of the manager
    function transferManagerOfVaultPosition(
        uint256 vaultId,
        uint256 vaultPositionId,
        address newManager
    ) external;

    /// @notice Set stop-loss price range of the position
    /// Users can set a stop-loss price range for a position only if the position is enabled `RangeStop` feature.
    /// If current price goes out of the stop-loss price range, extraFi's bots will close the position
    /// @param vaultId The Id of the vault
    /// @param vaultPositionId The Id of the position
    /// @param enable The enable status to set
    /// @param minPrice The lower price of the stop-loss price range
    /// @param maxPrice The upper price of the stop-loss price range
    function setRangeStop(
        uint256 vaultId,
        uint256 vaultPositionId,
        bool enable,
        uint256 minPrice,
        uint256 maxPrice
    ) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../external/openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Interface for WETH9
interface IWETH9 is IERC20 {
    /// @notice Deposit ether to get wrapped ether
    function deposit() external payable;

    /// @notice Withdraw wrapped ether to get ether
    function withdraw(uint256) external;
}

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;
pragma abicoder v2;

library AddressId {
    uint256 constant ADDRESS_ID_WETH9 = 1;
    uint256 constant ADDRESS_ID_UNI_V3_FACTORY = 2;
    uint256 constant ADDRESS_ID_UNI_V3_NONFUNGIBLE_POSITION_MANAGER = 3;
    uint256 constant ADDRESS_ID_UNI_V3_SWAP_ROUTER = 4;
    uint256 constant ADDRESS_ID_VELO_ROUTER = 5;
    uint256 constant ADDRESS_ID_VELO_FACTORY = 6;
    uint256 constant ADDRESS_ID_VAULT_POSITION_MANAGER = 7;
    uint256 constant ADDRESS_ID_SWAP_EXECUTOR_MANAGER = 8;
    uint256 constant ADDRESS_ID_LENDING_POOL = 9;
    uint256 constant ADDRESS_ID_VAULT_FACTORY = 10;
    uint256 constant ADDRESS_ID_TREASURY = 11;
    uint256 constant ADDRESS_ID_VE_TOKEN = 12;

    uint256 constant ADDRESS_ID_VELO_VAULT_DEPLOYER = 101;
    uint256 constant ADDRESS_ID_VELO_VAULT_INITIALIZER = 102;
    uint256 constant ADDRESS_ID_VELO_VAULT_POSITION_LOGIC = 103;
    uint256 constant ADDRESS_ID_VELO_VAULT_REWARDS_LOGIC = 104;
    uint256 constant ADDRESS_ID_VELO_VAULT_OWNER_ACTIONS = 105;
    uint256 constant ADDRESS_ID_VELO_SWAP_PATH_MANAGER = 106;
}

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;

/**
 * @title Errors library
 * @notice Defines the error messages emitted by the different contracts
 * @dev Error messages prefix glossary:
 *  - VL = ValidationLogic
 *  - VT = Vault
 *  - LP = LendingPool
 *  - P = Pausable
 */
library Errors {
    //contract specific errors
    string internal constant VL_TRANSACTION_TOO_OLD = "0"; // 'Transaction too old'
    string internal constant VL_NO_ACTIVE_RESERVE = "1"; // 'Action requires an active reserve'
    string internal constant VL_RESERVE_FROZEN = "2"; // 'Action cannot be performed because the reserve is frozen'
    string internal constant VL_CURRENT_AVAILABLE_LIQUIDITY_NOT_ENOUGH = "3"; // 'The current liquidity is not enough'
    string internal constant VL_NOT_ENOUGH_AVAILABLE_USER_BALANCE = "4"; // 'User cannot withdraw more than the available balance'
    string internal constant VL_TRANSFER_NOT_ALLOWED = "5"; // 'Transfer cannot be allowed.'
    string internal constant VL_BORROWING_NOT_ENABLED = "6"; // 'Borrowing is not enabled'
    string internal constant VL_INVALID_DEBT_OWNER = "7"; // 'Invalid interest rate mode selected'
    string internal constant VL_BORROWING_CALLER_NOT_IN_WHITELIST = "8"; // 'The collateral balance is 0'
    string internal constant VL_DEPOSIT_TOO_MUCH = "9"; // 'Deposit too much'
    string internal constant VL_OUT_OF_CAPACITY = "10"; // 'There is not enough collateral to cover a new borrow'
    string internal constant VL_OUT_OF_CREDITS = "11"; // 'Out of credits, there is not enough credits to borrow'
    string internal constant VL_PERCENT_TOO_LARGE = "12"; // 'Percentage too large'
    string internal constant VL_ADDRESS_CANNOT_ZERO = "13"; // vault address cannot be zero
    string internal constant VL_VAULT_UN_ACTIVE = "14";
    string internal constant VL_VAULT_FROZEN = "15";
    string internal constant VL_VAULT_BORROWING_DISABLED = "16";
    string internal constant VL_NOT_WETH9 = "17";
    string internal constant VL_INSUFFICIENT_WETH9 = "18";
    string internal constant VL_INSUFFICIENT_TOKEN = "19";
    string internal constant VL_LIQUIDATOR_NOT_IN_WHITELIST = "20";
    string internal constant VL_COMPOUNDER_NOT_IN_WHITELIST = "21";
    string internal constant VL_VAULT_ALREADY_INITIALIZED = "22";
    string internal constant VL_TREASURY_ADDRESS_NOT_SET = "23";

    string internal constant VT_INVALID_RESERVE_ID = "40"; // invalid reserve id
    string internal constant VT_INVALID_POOL = "41"; // invalid uniswap v3 pool
    string internal constant VT_INVALID_VAULT_POSITION_MANAGER = "42"; // invalid vault position manager
    string internal constant VT_VAULT_POSITION_NOT_ACTIVE = "43"; // vault position is not active
    string internal constant VT_VAULT_POSITION_AUTO_COMPOUND_NOT_ENABLED = "44"; // 'auto compound not enabled'
    string internal constant VT_VAULT_POSITION_ID_INVALID = "45"; // 'VaultPositionId invalid'
    string internal constant VT_VAULT_PAUSED = "46"; // 'vault is paused'
    string internal constant VT_VAULT_FROZEN = "47"; // 'vault is frozen'
    string internal constant VT_VAULT_CALLBACK_INVALID_SENDER = "48"; // 'callback must be initiate by the vault self
    string internal constant VT_VAULT_DEBT_RATIO_TOO_LOW_TO_LIQUIDATE = "49"; // 'debt ratio haven't reach liquidate ratio'
    string internal constant VT_VAULT_POSITION_MANAGER_INVALID = "50"; // 'invalid vault manager'
    string internal constant VT_VAULT_POSITION_RANGE_STOP_DISABLED = "60"; // 'vault positions' range stop is disabled'
    string internal constant VT_VAULT_POSITION_RANGE_STOP_PRICE_INVALID = "61"; // 'invalid range stop price'
    string internal constant VT_VAULT_POSITION_OUT_OF_MAX_LEVERAGE = "62";
    string internal constant VT_VAULT_POSITION_SHARES_INVALID = "63";

    string internal constant LP_NOT_ENOUGH_LIQUIDITY_TO_BORROW = "80"; // 'There is not enough liquidity available to borrow'
    string internal constant LP_CALLER_MUST_BE_LENDING_POOL = "81"; // 'Caller must be lending pool contract'
    string internal constant LP_BORROW_INDEX_OVERFLOW = "82"; // 'The borrow index overflow'
    string internal constant LP_IS_PAUSED = "83"; // lending pool is paused
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.0;

import "../external/openzeppelin/contracts/token/ERC20/IERC20.sol";

library TransferHelper {
    /// @notice Transfers tokens from the targeted address to the given destination
    /// @notice Errors with 'STF' if transfer fails
    /// @param token The contract address of the token to be transferred
    /// @param from The originating address from which the tokens will be transferred
    /// @param to The destination address of the transfer
    /// @param value The amount to be transferred
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                from,
                to,
                value
            )
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "STF"
        );
    }

    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Errors with ST if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "ST"
        );
    }

    /// @notice Approves the stipulated contract to spend the given allowance in the given token
    /// @dev Errors with 'SA' if transfer fails
    /// @param token The contract address of the token to be approved
    /// @param to The target of the approval
    /// @param value The amount of the given token the target will be allowed to spend
    function safeApprove(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SA"
        );
    }

    /// @notice Transfers ETH to the recipient address
    /// @dev Fails with `STE`
    /// @param to The destination of the transfer
    /// @param value The value to be transferred
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "STE");
    }
}

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;
pragma abicoder v2;

library VaultTypes {
    struct VeloVaultStorage {
        VeloVaultState state;
        mapping(uint256 => VeloPosition) positions;
        uint256 nextPositionId;
        address[] rewardTokens;
        address addressProvider;
        address veloFactory;
        address veloRouter;
        address swapPathManager;
        address lendingPool;
        address vaultPositionManager;
        address WETH9;
        address veToken;
    }

    struct VeloPositionValue {
        // manager of the position, who can adjust the position
        address manager;
        bool isActive;
        bool enableRangeStop;
        // timestamp when open
        uint64 openedAt;
        // timestamp now
        uint64 current;
        // token0Principal is the original invested token0
        uint256 token0Principal;
        // token1Principal is the original invested token1
        uint256 token1Principal;
        // liquidityPrincipal is the original liquidity user added to the pool
        uint256 liquidityPrincipal;
        // left token0 not added to the liquidity
        uint256 token0Left;
        // left Token1 not added to the liquidity
        uint256 token1Left;
        // left token0 in liquidity
        uint256 token0InLiquidity;
        // left Token1 not added to the liquidity
        uint256 token1InLiquidity;
        // The lp amount
        uint256 liquidity;
        // The debt share of debtPosition0 in the vault
        uint256 debt0;
        // The debt share for debtPosition1 in the vault
        uint256 debt1;
        // The borrowingIndex of debt0 in lendingPool
        uint256 borrowingIndex0;
        // The borrowingIndex of debt1 in lendingPool
        uint256 borrowingIndex1;
        // range stop config
        uint256 minPriceOfRangeStop;
        uint256 maxPriceOfRangeStop;
    }

    struct VeloPosition {
        // manager of the position, who can adjust the position
        address manager;
        bool isActive;
        bool enableRangeStop;
        // timestamp when open
        uint64 openedAt;
        // token0Principal is the original invested token0
        uint256 token0Principal;
        // token1Principal is the original invested token1
        uint256 token1Principal;
        // liquidityPrincipal is the original liquidity user added to the pool
        uint256 liquidityPrincipal;
        // left token0 not added to the liquidity
        uint256 token0Left;
        // left Token1 not added to the liquidity
        uint256 token1Left;
        // The lp shares in the vault
        uint256 lpShares;
        // The debt share of debtPosition0 in the vault
        uint256 debtShare0;
        // The debt share for debtPosition1 in the vault
        uint256 debtShare1;
        // range stop config
        uint256 minPriceOfRangeStop;
        uint256 maxPriceOfRangeStop;
    }

    struct VeloVaultState {
        address gauge;
        address pair;
        address token0;
        address token1;
        bool stable;
        // If the vault is paused, new or close positions would be rejected by the contract.
        bool paused;
        // If the vault is frozen, only new position action is rejected, the close is normal.
        bool frozen;
        // Only if this feature is true, users of the vault can borrow tokens from lending pool.
        bool borrowingEnabled;
        // liquidate with TWAP
        bool liquidateWithTWAP;
        // max leverage when open a position
        // the value has with a multiplier of 100
        // 1x -> 1 * 100
        // 2x -> 2 * 100
        uint16 maxLeverage;
        // premium leverage for a position of users who have specific veToken's voting power
        uint16 premiumMaxLeverage;
        uint16 maxPriceDiff;
        // The debt ratio trigger liquidation
        // When a position's debt ratio goes out of liquidateDebtRatio
        // the position can be liquidated
        uint16 liquidateDebtRatio;
        uint16 withdrawFeeRate;
        uint16 compoundFeeRate;
        uint16 liquidateFeeRate;
        uint16 rangeStopFeeRate;
        uint16 protocolFeeRate;
        // the minimal voting power reqruired to use premium functions
        uint256 premiumRequirement;
        // Protocol Fee
        uint256 protocolFee0Accumulated;
        uint256 protocolFee1Accumulated;
        // minimal invest value
        uint256 minInvestValue;
        uint256 minSwapAmount0;
        uint256 minSwapAmount1;
        // total lp
        uint256 totalLp;
        uint256 totalLpShares;
        // the utilization of the lending reserve pool trigger premium check
        uint256 premiumUtilizationOfReserve0;
        // debt limit of token0
        uint256 debtLimit0;
        // debt positionId of token0
        uint256 debtPositionId0;
        // debt total_shares
        uint256 debtTotalShares0;
        // the utilization of the lending reserve pool trigger premium check
        uint256 premiumUtilizationOfReserve1;
        // debt limit of token1
        uint256 debtLimit1;
        // debt positionId of token1
        uint256 debtPositionId1;
        // debt total_shares
        uint256 debtTotalShares1;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma abicoder v2;

import "./interfaces/IWETH9.sol";
import "./libraries/TransferHelper.sol";

import "./libraries/helpers/Errors.sol";

abstract contract Payments {
    address public immutable WETH9;

    modifier avoidUsingNativeEther() {
        require(msg.value == 0, "avoid using native ether");
        _;
    }

    constructor(address _WETH9) {
        WETH9 = _WETH9;
    }

    receive() external payable {
        require(msg.sender == WETH9, Errors.VL_NOT_WETH9);
    }

    function unwrapWETH9(uint256 amountMinimum, address recipient) internal {
        uint256 balanceWETH9 = IWETH9(WETH9).balanceOf(address(this));
        require(balanceWETH9 >= amountMinimum, Errors.VL_INSUFFICIENT_WETH9);

        if (balanceWETH9 > 0) {
            IWETH9(WETH9).withdraw(balanceWETH9);
            TransferHelper.safeTransferETH(recipient, balanceWETH9);
        }
    }

    function refundETH() internal {
        if (address(this).balance > 0)
            TransferHelper.safeTransferETH(msg.sender, address(this).balance);
    }

    /// @param token The token to pay
    /// @param payer The entity that must pay
    /// @param recipient The entity that will receive payment
    /// @param value The amount to pay
    function pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        if (token == WETH9 && address(this).balance >= value) {
            // pay with WETH9
            IWETH9(WETH9).deposit{value: value}(); // wrap only what is needed to pay
            require(
                IWETH9(WETH9).transfer(recipient, value),
                "transfer failed"
            );
        } else if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            TransferHelper.safeTransfer(token, recipient, value);
        } else {
            // pull payment
            TransferHelper.safeTransferFrom(token, payer, recipient, value);
        }
    }
}

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;
pragma abicoder v2;

import "./external/openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./external/openzeppelin/contracts/access/Ownable.sol";
import "./external/openzeppelin/contracts/utils/math/SafeMath.sol";
import "./external/openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IVeloVaultPositionManager.sol";
import "./interfaces/IVaultFactory.sol";
import "./interfaces/IVeloVault.sol";

import "./libraries/helpers/Errors.sol";
import "./Payments.sol";

import "./interfaces/IAddressRegistry.sol";
import "./libraries/helpers/AddressId.sol";

import "./libraries/types/VaultTypes.sol";

contract VeloPositionManager is
    ReentrancyGuard,
    IVeloVaultPositionManager,
    Ownable,
    Payments
{
    using SafeMath for uint256;

    /// @notice Contract address of the AddressProvider
    address public immutable addressProvider;
    /// @notice Contract address of the VaultFactory
    address public immutable vaultFactory;

    /// @notice permissionLessLiquidation feature
    /// Only if this feature is true, users can liquidate positions without permissions.
    /// Otherwise only liquidators in the whitelist can liquidate positions.
    bool public permissionLessLiquidationEnabled;
    /// @notice liquidatorWhitelist
    mapping(address => bool) public liquidatorWhitelist;

    /// @notice permissionLessCompoundEnabled feature
    /// Only if this feature is true, users can claim the vaults' rewards and reinvest to liquidity  without permissions.
    /// Otherwise only users in the whitelist can call the reinvest function
    bool public permissionLessCompoundEnabled;
    /// @notice CompounderWhitelist
    mapping(address => bool) public compounderWhitelist;

    /// @notice permissionLessRangeStopEnabled feature
    /// Only if this feature is true, users can close outof-range positions
    bool public permissionLessRangeStopEnabled;
    /// @notice rangeStopCallerWhitelist
    mapping(address => bool) public rangeStopCallerWhitelist;

    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, Errors.VL_TRANSACTION_TOO_OLD);
        _;
    }

    modifier liquidatorInWhitelist() {
        require(
            permissionLessLiquidationEnabled || liquidatorWhitelist[msg.sender],
            Errors.VL_LIQUIDATOR_NOT_IN_WHITELIST
        );
        _;
    }

    modifier compounderInWhitelist() {
        require(
            permissionLessCompoundEnabled || compounderWhitelist[msg.sender],
            Errors.VL_LIQUIDATOR_NOT_IN_WHITELIST
        );
        _;
    }

    modifier rangeStopCallerInWhitelist() {
        require(
            permissionLessRangeStopEnabled ||
                rangeStopCallerWhitelist[msg.sender],
            Errors.VL_LIQUIDATOR_NOT_IN_WHITELIST
        );
        _;
    }

    constructor(
        address _addressProvider
    )
        Payments(
            IAddressRegistry(_addressProvider).getAddress(
                AddressId.ADDRESS_ID_WETH9
            )
        )
    {
        require(_addressProvider != address(0), Errors.VL_ADDRESS_CANNOT_ZERO);
        addressProvider = _addressProvider;
        vaultFactory = IAddressRegistry(addressProvider).getAddress(
            AddressId.ADDRESS_ID_VAULT_FACTORY
        );

        disablePermissionLessLiquidation();
        addPermissionedLiquidator(msg.sender);
        disablePermissionLessCompound();
        addPermissionedCompounder(msg.sender);
        disablePermissonLessRangeStop();
        addPermissionedRangeStopCaller(msg.sender);
    }

    /// @notice Callback functions called by the vault to pay tokens to the vault contract.
    /// The caller to this function must be the vault contract
    function payToVaultCallback(
        PayToVaultCallbackParams calldata params
    ) external {
        address vaultAddress = IVaultFactory(vaultFactory).vaults(
            params.vaultId
        );
        require(vaultAddress != address(0), Errors.VL_ADDRESS_CANNOT_ZERO);
        require(
            vaultAddress == _msgSender(),
            Errors.VT_VAULT_CALLBACK_INVALID_SENDER
        );

        // transfer token0 and token1 from user's wallet to vault
        if (params.amount0 > 0) {
            pay(
                IVeloVault(vaultAddress).token0(),
                params.payer,
                vaultAddress,
                params.amount0
            );
        }
        if (params.amount1 > 0) {
            pay(
                IVeloVault(vaultAddress).token1(),
                params.payer,
                vaultAddress,
                params.amount1
            );
        }
    }

    /// @notice Callback functions called by the vault to pay protocol fee.
    /// The caller to this function must be the vault contract
    function payFeeToTreasuryCallback(
        uint256 vaultId,
        address asset,
        uint256 amount,
        uint256 feeType
    ) external {
        address vaultAddress = IVaultFactory(vaultFactory).vaults(vaultId);
        require(vaultAddress != address(0), Errors.VL_ADDRESS_CANNOT_ZERO);
        require(
            vaultAddress == _msgSender(),
            Errors.VT_VAULT_CALLBACK_INVALID_SENDER
        );

        address treasury = IAddressRegistry(addressProvider).getAddress(
            AddressId.ADDRESS_ID_TREASURY
        );
        require(treasury != address(0), "zero-address treasury");

        SafeERC20.safeTransferFrom(
            IERC20(asset),
            vaultAddress,
            treasury,
            amount
        );

        emit FeePaid(vaultId, asset, feeType, amount);
    }

    /// @notice Open a new vaultPosition or invest to a existing vault position
    /// @param params The parameters necessary, encoded as `NewOrInvestToVaultPositionParams` in calldata
    function newOrInvestToVaultPosition(
        NewOrInvestToVaultPositionParams calldata params
    ) external payable nonReentrant checkDeadline(params.deadline) {
        address vaultAddress = IVaultFactory(vaultFactory).vaults(
            params.vaultId
        );
        require(vaultAddress != address(0), Errors.VL_ADDRESS_CANNOT_ZERO);

        (uint256 positionId, uint256 liquidity) = IVeloVault(vaultAddress)
            .newOrInvestToVaultPosition(params, _msgSender());

        if (params.vaultPositionId == 0) {
            emit NewVaultPosition(params.vaultId, positionId, _msgSender());
        }

        // if user use ether, refund unused ether to msg.sender
        if (msg.value > 0) {
            refundETH();
        }

        emit InvestToVaultPosition(
            params.vaultId,
            positionId,
            _msgSender(),
            params.amount0Invest,
            params.amount1Invest,
            params.amount0Borrow,
            params.amount1Borrow,
            liquidity
        );
    }

    /// @notice Close a vaultPosition partially
    /// @param params The parameters necessary, encoded as `CloseVaultPositionPartiallyParams` in calldata
    function closeVaultPositionPartially(
        CloseVaultPositionPartiallyParams calldata params
    )
        external
        payable
        override
        nonReentrant
        checkDeadline(params.deadline)
        avoidUsingNativeEther
    {
        address vaultAddress = IVaultFactory(vaultFactory).vaults(
            params.vaultId
        );
        require(vaultAddress != address(0), Errors.VL_ADDRESS_CANNOT_ZERO);

        (
            uint256 amount0,
            uint256 amount1,
            uint256 repay0,
            uint256 repay1
        ) = IVeloVault(vaultAddress).closeAndRepayPartially(
                params,
                _msgSender()
            );

        if (
            amount0 > 0 &&
            IVeloVault(vaultAddress).token0() == WETH9 &&
            params.receiveNativeETH
        ) {
            unwrapWETH9(amount0, params.receiver);
        }

        if (
            amount1 > 0 &&
            IVeloVault(vaultAddress).token1() == WETH9 &&
            params.receiveNativeETH
        ) {
            unwrapWETH9(amount1, params.receiver);
        }

        emit CloseVaultPositionPartially(
            params.vaultId,
            params.vaultPositionId,
            _msgSender(),
            params.percent,
            amount0,
            amount1,
            repay0,
            repay1
        );
    }

    /// @notice Close the position which is outof price range.
    /// This function can be called only if the `rangeStop` feature is enabled.
    /// Any permissioned user can call this function, regardless of whether they are the position owner.
    /// @param params The parameters necessary, encoded as `CloseVaultPositionPartiallyParams` in calldata
    function closeOutOfRangePosition(
        CloseVaultPositionPartiallyParams calldata params
    )
        external
        payable
        nonReentrant
        rangeStopCallerInWhitelist
        avoidUsingNativeEther
    {
        address vaultAddress = IVaultFactory(vaultFactory).vaults(
            params.vaultId
        );
        require(vaultAddress != address(0), Errors.VL_ADDRESS_CANNOT_ZERO);

        (
            address positionManager,
            uint256 price,
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        ) = IVeloVault(vaultAddress).closeAndRepayOutOfRangePosition(params);

        if (
            fee0 > 0 &&
            IVeloVault(vaultAddress).token0() == WETH9 &&
            params.receiveNativeETH
        ) {
            unwrapWETH9(fee0, params.receiver);
        }

        if (
            fee1 > 0 &&
            IVeloVault(vaultAddress).token1() == WETH9 &&
            params.receiveNativeETH
        ) {
            unwrapWETH9(fee1, params.receiver);
        }

        emit CloseOutOfRangePosition(
            params.vaultId,
            params.vaultPositionId,
            positionManager,
            _msgSender(),
            params.percent,
            uint64(block.timestamp),
            price,
            amount0,
            amount1,
            fee0,
            fee1
        );
    }

    /// @notice Liquidate a vaultPosition partially
    /// @param params The parameters necessary, encoded as `LiquidateVaultPositionPartiallyParams` in calldata
    function liquidateVaultPositionPartially(
        LiquidateVaultPositionPartiallyParams calldata params
    ) external payable nonReentrant liquidatorInWhitelist {
        address vaultAddress = IVaultFactory(vaultFactory).vaults(
            params.vaultId
        );
        require(vaultAddress != address(0), Errors.VL_ADDRESS_CANNOT_ZERO);

        IVeloVault.LiquidateState memory result = IVeloVault(vaultAddress)
            .repayAndLiquidatePositionPartially(params, _msgSender());

        if (
            result.liquidatorReceive0 > 0 &&
            IVeloVault(vaultAddress).token0() == WETH9 &&
            params.receiveNativeETH
        ) {
            unwrapWETH9(result.liquidatorReceive0, params.receiver);
        }

        if (
            result.liquidatorReceive1 > 0 &&
            IVeloVault(vaultAddress).token1() == WETH9 &&
            params.receiveNativeETH
        ) {
            unwrapWETH9(result.liquidatorReceive1, params.receiver);
        }

        // if user use ether, refund unused ether to msg.sender
        if (msg.value > 0) {
            refundETH();
        }

        emit LiquidateVaultPositionPartially(
            params.vaultId,
            params.vaultPositionId,
            result.manager,
            _msgSender(),
            params.percent,
            uint64(block.timestamp),
            result.price,
            result.repaidValue,
            result.removedLiquidityValue,
            result.amount0Left,
            result.amount1Left,
            result.liquidateFee0,
            result.liquidateFee1
        );
    }

    /// @notice Invest the earned fee by the position to liquidity
    function investEarnedFeeToLiquidity(
        InvestEarnedFeeToLiquidityParam calldata params
    )
        external
        payable
        nonReentrant
        compounderInWhitelist
        avoidUsingNativeEther
    {
        address vaultAddress = IVaultFactory(vaultFactory).vaults(
            params.vaultId
        );
        require(vaultAddress != address(0), Errors.VL_ADDRESS_CANNOT_ZERO);

        (
            uint256 liquidity,
            uint256 fee0,
            uint256 fee1,
            uint256[] memory rewards
        ) = IVeloVault(vaultAddress).claimRewardsAndReInvestToLiquidity(params);

        if (
            fee0 > 0 &&
            IVeloVault(vaultAddress).token0() == WETH9 &&
            params.receiveNativeETH
        ) {
            unwrapWETH9(fee0, params.compoundFeeReceiver);
        }

        if (
            fee1 > 0 &&
            IVeloVault(vaultAddress).token1() == WETH9 &&
            params.receiveNativeETH
        ) {
            unwrapWETH9(fee1, params.compoundFeeReceiver);
        }

        emit InvestEarnedFeeToLiquidity(
            params.vaultId,
            _msgSender(),
            liquidity,
            fee0,
            fee1,
            rewards
        );
    }

    /// @notice Repay exact value of debts
    function exactRepay(
        ExactRepayParam calldata params
    )
        external
        payable
        nonReentrant
        returns (uint256 amount0Repaid, uint256 amount1Repaid)
    {
        address vaultAddress = IVaultFactory(vaultFactory).vaults(
            params.vaultId
        );
        require(vaultAddress != address(0), Errors.VL_ADDRESS_CANNOT_ZERO);

        address positionMananegr;

        (positionMananegr, amount0Repaid, amount1Repaid) = IVeloVault(
            vaultAddress
        ).exactRepay(params, _msgSender());

        if (
            params.amount0ToRepay > amount0Repaid &&
            IVeloVault(vaultAddress).token0() == WETH9 &&
            params.receiveNativeETH
        ) {
            unwrapWETH9(params.amount0ToRepay.sub(amount0Repaid), _msgSender());
        }

        if (
            params.amount1ToRepay > amount1Repaid &&
            IVeloVault(vaultAddress).token1() == WETH9 &&
            params.receiveNativeETH
        ) {
            unwrapWETH9(params.amount1ToRepay.sub(amount1Repaid), _msgSender());
        }

        // if there is unused ETH, refund it to msg.sender
        if (msg.value > 0) {
            refundETH();
        }

        emit ExactRepay(
            params.vaultId,
            params.vaultPositionId,
            positionMananegr,
            _msgSender(),
            amount0Repaid,
            amount1Repaid
        );
    }

    function adminSetVault(
        uint256 vaultId,
        bytes calldata params
    ) external nonReentrant onlyOwner {
        address vaultAddress = IVaultFactory(vaultFactory).vaults(vaultId);
        require(vaultAddress != address(0), Errors.VL_ADDRESS_CANNOT_ZERO);
        IVeloVault(vaultAddress).adminSetVault(params);
    }

    /// @notice Transfer the position's manager to another wallet
    /// Must be called by the current manager of the posistion
    /// @param vaultId The Id of the vault
    /// @param vaultPositionId The Id of the position
    /// @param newManager The new address of the manager
    function transferManagerOfVaultPosition(
        uint256 vaultId,
        uint256 vaultPositionId,
        address newManager
    ) external override nonReentrant {
        address vaultAddress = IVaultFactory(vaultFactory).vaults(vaultId);
        require(vaultAddress != address(0), Errors.VL_ADDRESS_CANNOT_ZERO);
        IVeloVault(vaultAddress).transferManagerTo(
            _msgSender(),
            vaultPositionId,
            newManager
        );
    }

    /// @notice Set stop-loss price range of the position
    /// Users can set a stop-loss price range for a position only if the position is enabled `RangeStop` feature.
    /// If current price goes out of the stop-loss price range, extraFi's bots will close the position
    /// @param vaultId The Id of the vault
    /// @param vaultPositionId The Id of the position
    /// @param enable Enable or Disable the rangeStop feature
    /// @param minPrice The lower price of the stop-loss price range
    /// @param maxPrice The upper price of the stop-loss price range
    function setRangeStop(
        uint256 vaultId,
        uint256 vaultPositionId,
        bool enable,
        uint256 minPrice,
        uint256 maxPrice
    ) external override nonReentrant {
        address vaultAddress = IVaultFactory(vaultFactory).vaults(vaultId);
        require(vaultAddress != address(0), Errors.VL_ADDRESS_CANNOT_ZERO);
        IVeloVault(vaultAddress).setRangeStop(
            _msgSender(),
            vaultPositionId,
            enable,
            minPrice,
            maxPrice
        );
    }

    function enablePermissionLessLiquidation() public nonReentrant onlyOwner {
        permissionLessLiquidationEnabled = true;
    }

    function disablePermissionLessLiquidation() public nonReentrant onlyOwner {
        permissionLessLiquidationEnabled = false;
    }

    function addPermissionedLiquidator(
        address addr
    ) public nonReentrant onlyOwner {
        liquidatorWhitelist[addr] = true;
    }

    function removePermissionedLiquidator(
        address addr
    ) public nonReentrant onlyOwner {
        liquidatorWhitelist[addr] = false;
    }

    function enablePermissionLessCompound() public nonReentrant onlyOwner {
        permissionLessCompoundEnabled = true;
    }

    function disablePermissionLessCompound() public nonReentrant onlyOwner {
        permissionLessCompoundEnabled = false;
    }

    function addPermissionedCompounder(
        address addr
    ) public nonReentrant onlyOwner {
        compounderWhitelist[addr] = true;
    }

    function removePermissionedCompounder(
        address addr
    ) public nonReentrant onlyOwner {
        compounderWhitelist[addr] = false;
    }

    function enablePermissonLessRangeStop() public nonReentrant onlyOwner {
        permissionLessRangeStopEnabled = true;
    }

    function disablePermissonLessRangeStop() public nonReentrant onlyOwner {
        permissionLessRangeStopEnabled = false;
    }

    function addPermissionedRangeStopCaller(
        address addr
    ) public nonReentrant onlyOwner {
        rangeStopCallerWhitelist[addr] = true;
    }

    function removePermissionedRangeStopCaller(
        address addr
    ) public nonReentrant onlyOwner {
        rangeStopCallerWhitelist[addr] = false;
    }

    //----------------->>>>>  getters <<<<<-----------------
    function getVault(
        uint256 vaultId
    ) external view override returns (VaultTypes.VeloVaultState memory) {
        address vaultAddress = IVaultFactory(vaultFactory).vaults(vaultId);
        return IVeloVault(vaultAddress).getVaultState();
    }

    function getVaultPosition(
        uint256 vaultId,
        uint256 vaultPositionId
    )
        external
        view
        override
        returns (VaultTypes.VeloPositionValue memory state)
    {
        address vaultAddress = IVaultFactory(vaultFactory).vaults(vaultId);
        return IVeloVault(vaultAddress).getPositionValue(vaultPositionId);
    }
}