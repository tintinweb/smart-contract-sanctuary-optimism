// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

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

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

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
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
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

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

interface IStrategyMasterchefFarmV2 {
    /// @dev Universal instalation params.
    struct InstallParams {
        address controller;
        address router; 
        address treasury;
        uint16 protocolFee;
        uint16 slippage;
    }

    /// @dev Emitted when reards get autocompounded.
    event Compounded(uint256 rewardAmount, uint256 fee, uint256 time);

    /// @dev Caller unauthorized.
    error Unauthorized();

    /// @dev Unexpected token address.
    error BadToken();

    /// @dev Strategy disabled.
    error NotActive();

    /// @dev Amount is zero.
    error ZeroAmount();

    /// @dev Address is zero.
    error ZeroAddress();

    /// @dev Protocol paused.
    error OnPause();

    /// @dev Slippage too big.
    error SlippageProtection();

    /// @dev Slippage percentage too big.
    error SlippageTooHigh();

    /// @dev Wrong amount.
    error BadAmount();

    /// @dev Deposits disabled (strategy deprecated).
    error WithdrawOnly();

    /// @dev Strategy disabled.
    error StrategyDisabled();

    /// @dev Different size of arrays.
    error ArrayDifferentLength();

    /// @dev No rewards to claim.
    error NoRewardsAvailable();

    /// @dev Reentrancy detected.
    error Reentrancy();
    
    function balance() external view returns (uint256);

    function claimable()
        external
        view
        returns (address[] memory tokens, uint256[] memory amounts);

    function deposit(
        address user,
        address[] memory path,
        bytes memory data
    ) external returns (uint256);

    function withdraw(
        address user,
        uint256 shares,
        address[] memory path1,
        address[] memory path2,
        bytes memory data
    ) external returns (uint256);

    function migrate(uint16 slippage) external returns (uint256 amountOut);

    function autocompound(uint16 slippage) external;

    function quotePotentialWithdraw(
        uint256 shares,
        address[] calldata path1,
        address[] calldata path2,
        bytes calldata data,
        uint256 price1,
        uint256 price2
    ) external view returns (uint256 amountOut);

    function allocationOf(address user) external view returns (uint256);

    function totalAllocation() external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library Helpers {
    using SafeERC20 for IERC20;

    uint16 public constant DENOMINATOR = 10000;

    error PercentExeedsMaximalValue();

    /**
     * @notice Calc minAmount with slippage tollerance.
     * @param amount Full amount.
     * @param fees Slippage percent.
     * @return Fee amount.
     */
    function calcFee(
        uint256 amount,
        uint16 fees
    ) external pure returns (uint256) {
        if (fees == 0) return amount;
        if (fees > DENOMINATOR) revert PercentExeedsMaximalValue();

        return (amount * fees) / DENOMINATOR;
    }

    /**
     * @notice Calc fee.
     * @param amount Full amount.
     * @param slippage Fee percent.
     */
    function withSlippage(
        uint256 amount,
        uint16 slippage
    ) external pure returns (uint256) {
        if (slippage == 0) return amount;
        if (slippage > DENOMINATOR) revert PercentExeedsMaximalValue();

        return amount - ((amount * slippage) / DENOMINATOR);
    }

    /**
     * @notice Converts "abi.encode(address)" string back to address.
     * @param b Bytes with address.
     * @return decoded Recovered address.
     */
    function toAddress(bytes calldata b) external pure returns (address decoded) {
        decoded = abi.decode(b, (address));
    }

    /**
     * @notice Approve tokens for external contract.
     * @param token token instance.
     * @param to address to be approved.
     */
    function approveAll(IERC20 token, address to) external {
        if (token.allowance(address(this), to) != type(uint256).max) {
            token.safeApprove(address(to), type(uint256).max);
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IStrategyMasterchefFarmV2.sol";
import "./ILeechRouter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 *        __                   __
 *       / /   ___  ___  _____/ /_
 *      / /   / _ \/ _ \/ ___/ __ \
 *     / /___/  __/  __/ /__/ / / / v.0.2-beta
 *    /_____/\___/\___/\___/_/ /_/           __
 *    / __ \_________  / /_____  _________  / /
 *   / /_/ / ___/ __ \/ __/ __ \/ ___/ __ \/ /
 *  / ____/ /  / /_/ / /_/ /_/ / /__/ /_/ / /
 * /_/   /_/   \____/\__/\____/\___/\____/_/
 *
 * @title Base farming strategy.
 * @author Leech Protocol (https://app.leechprotocol.com/).
 * @custom:version 0.2-beta.
 * @custom:security Found vulnerability? Get reward ([email protected]).
 */
abstract contract BaseFarmStrategy is Ownable, IStrategyMasterchefFarmV2 {
    /// @dev SafeERC20 library from OpenZeppelin.
    using SafeERC20 for IERC20;

    /// @notice The protocol fee limit is 12%.
    uint16 public constant MAX_FEE = 1200;

    /// @notice Used for fractional part (1 = 0.01)
    uint16 public constant DENOMINATOR = 10000;

    /// @notice Address of Leech's backend.
    address public controller;

    /// @notice Address of LeechRouter.
    address public router;

    /// @notice Treasury address.
    address public treasury;

    /// @notice Leech's comission.
    uint16 public protocolFee;

    /// @notice Sum of all users shares.
    uint256 public totalAllocation;

    /// @notice Swap slippage.
    uint16 public slippage = 50; // 0.5% by default

    /// @notice For migration process.
    bool public isActive = true;

    /// @notice For migration process.
    bool public isWithdrawOnly;

    /// @dev Re-entrancy lock.
    bool private locked;

    /// @notice Share of user
    mapping(address => uint256) public allocationOf;

    /// @dev Limit access for the LeechRouter only.
    modifier onlyRouter() {
        if (msg.sender != router) revert Unauthorized();
        _;
    }

    /// @dev Unsigned integer should be great than zero.
    modifier notZeroAmount(uint256 amountToCheck) {
        if (amountToCheck == 0) revert ZeroAmount();
        _;
    }

    /// @dev Address shouldn't be empty.
    modifier notZeroAddress(address addressToCheck) {
        if (addressToCheck == address(0)) revert ZeroAddress();
        _;
    }

    /// @dev Strategy should be active.
    modifier enabled() {
        if (!isActive) revert StrategyDisabled();
        _;
    }

    /// @dev Re-entrancy lock
    modifier lock() {
        if (locked) revert Reentrancy();
        locked = true;
        _;
        locked = false;
    }

    /**
     * @notice Executes on contract deployment.
     * @param params General strategy parameters.
     */
    constructor(InstallParams memory params) {
        // Set params on deploy
        (controller, router, treasury, protocolFee, slippage) = (
            params.controller,
            params.router,
            params.treasury,
            params.protocolFee,
            params.slippage
        );
    }

    /**
     * @notice Take fees and re-invests rewards.
     */
    function autocompound(uint16) public virtual enabled {
        // Revert if protocol paused
        if (ILeechRouter(router).paused()) revert OnPause();
    }

    /**
     * @notice Depositing into the farm pool.
     * @dev Only LeechRouter can call this function.
     * @dev Re-entrancy lock on the LeechRouter side.
     * @param user User address
     * @param path Path to swap the deposited token into the token0.
     * @param data Additional data.
     * @return share Deposit allocation.
     */
    function deposit(
        address user,
        address[] memory path,
        bytes memory data
    ) public virtual onlyRouter enabled returns (uint256 share) {
        if (isWithdrawOnly) revert WithdrawOnly();
        // Get external LP amount
        share = _deposit(path, data);
        // Balance of SSLP before deposit
        uint256 _initialBalance = balance() - share;
        // Second+ deposit
        if (totalAllocation != 0 && _initialBalance != 0) {
            // Calc deposit share
            share = (share * totalAllocation) / _initialBalance;
        }
        // Update user allocation
        allocationOf[user] += share;
        // Update total allcation
        totalAllocation += share;
        // Revert is nothing to deposit
        if (share == 0) revert ZeroAmount();
    }

    /**
     * @notice Withdrawing staking token (LP) from the strategy.
     * @dev Can only be called by LeechRouter.
     * @dev Re-entrancy lock on the LeechRouter side.
     * @param user User address.
     * @param shares Amount of the strategy shares to be withdrawn.
     * @param data Output token encoded to bytes string.
     * @return tokenOutAmount Amount of the token returned to LeechRouter.
     */
    function withdraw(
        address user,
        uint256 shares,
        address[] memory path1,
        address[] memory path2,
        bytes memory data
    )
        public
        virtual
        onlyRouter
        enabled
        notZeroAmount(shares)
        returns (uint256 tokenOutAmount)
    {
        // Is amount more than user have?
        if (shares > allocationOf[user]) revert BadAmount();
        // Calc amount in LP tokens
        uint256 _lpAmount = (balance() * shares) / totalAllocation;
        // Reduce shares if not migration
        if (user != address(this)) {
            allocationOf[user] -= shares;
            totalAllocation -= shares;
        }
        // Withdraw to, amount, path1...
        tokenOutAmount = _withdraw(
            router,
            _lpAmount,
            path1,
            path2,
            data,
            slippage
        );
    }

    function migrate(
        uint16 slippage_
    ) external virtual enabled onlyRouter returns (uint256) {
        address[] memory _blank;
        isActive = false;
        return
            _withdraw(
                router,
                balance(),
                _blank,
                _blank,
                abi.encode(address(base())),
                slippage_
            );
    }

    function panic(uint16 slippage_) external virtual enabled onlyOwner {
        address[] memory _blank;
        isActive = false;
        _withdraw(
            owner(),
            balance(),
            _blank,
            _blank,
            abi.encode(address(base())),
            slippage_
        );
    }

    /**
     * @notice Sets fee taken by the Leech protocol.
     * @dev Only owner can set the protocol fee.
     * @param _fee Fee value.
     */
    function setFee(uint16 _fee) external virtual onlyOwner {
        if (_fee > MAX_FEE) revert BadAmount();
        protocolFee = _fee;
    }

    /**
     * @notice Sets the tresury address.
     * @dev Only owner can set the treasury address.
     * @param _treasury The address to be set.
     */
    function setTreasury(address _treasury) external virtual onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
    }

    /**
     * @notice Sets the controller address.
     * @dev Only owner can set the controller address.
     * @param _controller The address to be set.
     */
    function setController(address _controller) external virtual onlyOwner {
        if (_controller == address(0)) revert ZeroAddress();
        controller = _controller;
    }

    /**
     * @notice Sets slippage tolerance.
     * @dev Only owner can set the slippage tolerance.
     * @param _slippage Slippage percent (1 == 0.01%).
     */
    function setSlippage(uint16 _slippage) external virtual onlyOwner {
        if (_slippage > DENOMINATOR) revert SlippageTooHigh();
        if (_slippage == 0) revert ZeroAmount();
        slippage = _slippage;
    }

    /**
     * @notice Allows the owner to withdraw stuck tokens from the contract's balance.
     * @dev Only owner can withdraw tokens.
     * @param _token Address of the token to be withdrawn.
     * @param _amount Amount to be withdrawn.
     */
    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount
    ) external virtual onlyOwner {
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    /**
     * @dev Depositing into the farm pool.
     * @return share External pool deposit LP amount.
     */
    function _deposit(
        address[] memory,
        bytes memory
    ) internal virtual returns (uint256 share) {}

    /**
     * @dev Withdrawing staking token (LP) from the strategy.
     * @return tokenOutAmount Amount of the token returned to LeechRouter.
     */
    function _withdraw(
        address,
        uint256,
        address[] memory,
        address[] memory,
        bytes memory,
        uint16
    ) internal virtual returns (uint256 tokenOutAmount) {}

    /**
     * @notice Function returns estimated amount of token out from the LP withdrawn LP amount.
     * @param shares Amount of shares.
     * @param token0toTokenOut Path to output token.
     * @param token1toTokenOut Path to output token.
     * @param data Additional params.
     * @param price0 Price of token0.
     * @param price1 Price of token1.
     */
    function quotePotentialWithdraw(
        uint256 shares,
        address[] calldata token0toTokenOut,
        address[] calldata token1toTokenOut,
        bytes calldata data,
        uint256 price0,
        uint256 price1
    ) public view virtual returns (uint256 amountOut) {}

    /**
     * @notice Address of base token.
     * @return Base token address.
     */
    function base() public view virtual returns (address) {
        return ILeechRouter(router).base();
    }

    /**
     * @notice Amount of LPs staked into Masterchef.
     * @return amount LP amount.
     */
    function balance() public view virtual returns (uint256 amount) {}

    /**
     * @notice Amounts of pending rewards.
     * @return tokens Array of reward tokens.
     * @return amounts Array of reward amounts.
     */
    function claimable()
        public
        view
        virtual
        returns (address[] memory tokens, uint256[] memory amounts)
    {}
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

interface ILeechRouter {
    function base() external view returns (address);
    function paused() external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

interface IBentoBox {
    event LogDeploy(
        address indexed masterContract,
        bytes data,
        address indexed cloneAddress
    );
    event LogDeposit(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 share
    );
    event LogFlashLoan(
        address indexed borrower,
        address indexed token,
        uint256 amount,
        uint256 feeAmount,
        address indexed receiver
    );
    event LogRegisterProtocol(address indexed protocol);
    event LogSetMasterContractApproval(
        address indexed masterContract,
        address indexed user,
        bool approved
    );
    event LogStrategyDivest(address indexed token, uint256 amount);
    event LogStrategyInvest(address indexed token, uint256 amount);
    event LogStrategyLoss(address indexed token, uint256 amount);
    event LogStrategyProfit(address indexed token, uint256 amount);
    event LogStrategyQueued(address indexed token, address indexed strategy);
    event LogStrategySet(address indexed token, address indexed strategy);
    event LogStrategyTargetPercentage(
        address indexed token,
        uint256 targetPercentage
    );
    event LogTransfer(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 share
    );
    event LogWhiteListMasterContract(
        address indexed masterContract,
        bool approved
    );
    event LogWithdraw(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 share
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function balanceOf(address, address) external view returns (uint256);

    function batch(bytes[] memory calls, bool revertOnFail)
        external
        payable
        returns (bool[] memory successes, bytes[] memory results);

    function batchFlashLoan(
        address borrower,
        address[] memory receivers,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function deploy(
        address masterContract,
        bytes memory data,
        bool useCreate2
    ) external payable returns (address cloneAddress);

    function deposit(
        address token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external payable returns (uint256 amountOut, uint256 shareOut);

    function flashLoan(
        address borrower,
        address receiver,
        address token,
        uint256 amount,
        bytes memory data
    ) external;

    function harvest(
        address token,
        bool balance,
        uint256 maxChangeAmount
    ) external;

    function masterContractApproved(address, address)
        external
        view
        returns (bool);

    function masterContractOf(address) external view returns (address);

    function nonces(address) external view returns (uint256);

    function pendingStrategy(address) external view returns (address);

    function permitToken(
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function registerProtocol() external;

    function setMasterContractApproval(
        address user,
        address masterContract,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function setStrategy(address token, address newStrategy) external;

    function setStrategyTargetPercentage(
        address token,
        uint64 targetPercentage_
    ) external;

    function strategy(address) external view returns (address);

    function strategyData(address)
        external
        view
        returns (
            uint64 strategyStartDate,
            uint64 targetPercentage,
            uint128 balance
        );

    function toAmount(
        address token,
        uint256 share,
        bool roundUp
    ) external view returns (uint256 amount);

    function toShare(
        address token,
        uint256 amount,
        bool roundUp
    ) external view returns (uint256 share);

    function totals(address)
        external
        view
        returns (uint128 elastic, uint128 base);

    function transfer(
        address token,
        address from,
        address to,
        uint256 share
    ) external;

    function transferMultiple(
        address token,
        address from,
        address[] memory tos,
        uint256[] memory shares
    ) external;

    function transferOwnership(
        address newOwner,
        bool direct,
        bool renounce
    ) external;

    function whitelistMasterContract(address masterContract, bool approved)
        external;

    function whitelistedMasterContracts(address) external view returns (bool);

    function withdraw(
        address token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256 amountOut, uint256 shareOut);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

interface IComplexRewarderTime {
    struct PoolInfo {
        uint128 accSushiPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    event LogInit();
    event LogOnReward(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        address indexed to
    );
    event LogPoolAddition(uint256 indexed pid, uint256 allocPoint);
    event LogRewardPerSecond(uint256 rewardPerSecond);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint);
    event LogUpdatePool(
        uint256 indexed pid,
        uint64 lastRewardTime,
        uint256 lpSupply,
        uint256 accSushiPerShare
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    function add(uint256 allocPoint, uint256 _pid) external;

    function claimOwnership() external;

    function massUpdatePools(uint256[] memory pids) external;

    function onSushiReward(
        uint256 pid,
        address _user,
        address to,
        uint256,
        uint256 lpToken
    ) external;

    function owner() external view returns (address);

    function pendingOwner() external view returns (address);

    function pendingToken(uint256 _pid, address _user)
        external
        view
        returns (uint256 pending);

    function pendingTokens(
        uint256 pid,
        address user,
        uint256
    )
        external
        view
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts);

    function poolIds(uint256) external view returns (uint256);

    function poolInfo(uint256)
        external
        view
        returns (
            uint128 accSushiPerShare,
            uint64 lastRewardTime,
            uint64 allocPoint
        );

    function poolLength() external view returns (uint256 pools);

    function reclaimTokens(
        address token,
        uint256 amount,
        address to
    ) external;

    function rewardPerSecond() external view returns (uint256);

    function set(uint256 _pid, uint256 _allocPoint) external;

    function setRewardPerSecond(uint256 _rewardPerSecond) external;

    function transferOwnership(
        address newOwner,
        bool direct,
        bool renounce
    ) external;

    function updatePool(uint256 pid)
        external
        returns (PoolInfo memory pool);

    function userInfo(uint256, address)
        external
        view
        returns (
            uint256 amount,
            uint256 rewardDebt,
            uint256 unpaidRewards
        );
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

interface IMiniChefV2 {
    struct PoolInfo {
        uint128 accSushiPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    function add(
        uint256 allocPoint,
        address _lpToken,
        address _rewarder
    ) external;

    function addedTokens(address) external view returns (bool);

    function batch(
        bytes[] memory calls,
        bool revertOnFail
    )
        external
        payable
        returns (bool[] memory successes, bytes[] memory results);

    function deposit(uint256 pid, uint256 amount, address to) external;

    function emergencyWithdraw(uint256 pid, address to) external;

    function harvest(uint256 pid, address to) external;

    function lpToken(uint256) external view returns (address);

    function updatePool(uint256 pid) external returns (PoolInfo memory pool);

    function pendingSushi(
        uint256 _pid,
        address _user
    ) external view returns (uint256 pending);

    function permitToken(
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function poolInfo(
        uint256
    )
        external
        view
        returns (
            uint128 accSushiPerShare,
            uint64 lastRewardTime,
            uint64 allocPoint
        );

    function poolLength() external view returns (uint256 pools);

    function rewarder(uint256) external view returns (address);

    function sushiPerSecond() external view returns (uint256);

    function totalAllocPoint() external view returns (uint256);

    function userInfo(
        uint256,
        address
    ) external view returns (uint256 amount, int256 rewardDebt);

    function withdraw(uint256 pid, uint256 amount, address to) external;

    function withdrawAndHarvest(
        uint256 pid,
        uint256 amount,
        address to
    ) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

/// @notice Trident pool interface.
interface IPool {
    function allowance(address, address) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    /// @notice Executes a swap from one token to another.
    /// @dev The input tokens must've already been sent to the pool.
    /// @param data ABI-encoded params that the pool requires.
    /// @return finalAmountOut The amount of output tokens that were sent to the user.
    function swap(bytes calldata data) external returns (uint256 finalAmountOut);

    /// @notice Executes a swap from one token to another with a callback.
    /// @dev This function allows borrowing the output tokens and sending the input tokens in the callback.
    /// @param data ABI-encoded params that the pool requires.
    /// @return finalAmountOut The amount of output tokens that were sent to the user.
    function flashSwap(bytes calldata data) external returns (uint256 finalAmountOut);

    /// @notice Mints liquidity tokens.
    /// @param data ABI-encoded params that the pool requires.
    /// @return liquidity The amount of liquidity tokens that were minted for the user.
    function mint(bytes calldata data) external returns (uint256 liquidity);

    /// @notice Burns liquidity tokens.
    /// @dev The input LP tokens must've already been sent to the pool.
    /// @param data ABI-encoded params that the pool requires.
    /// @return withdrawnAmounts The amount of various output tokens that were sent to the user.
    function burn(bytes calldata data) external returns (TokenAmount[] memory withdrawnAmounts);

    /// @notice Burns liquidity tokens for a single output token.
    /// @dev The input LP tokens must've already been sent to the pool.
    /// @param data ABI-encoded params that the pool requires.
    /// @return amountOut The amount of output tokens that were sent to the user.
    function burnSingle(bytes calldata data) external returns (uint256 amountOut);

    /// @return A unique identifier for the pool type.
    function poolIdentifier() external pure returns (bytes32);

    /// @return An array of tokens supported by the pool.
    function getAssets() external view returns (address[] memory);

    /// @notice Simulates a trade and returns the expected output.
    /// @dev The pool does not need to include a trade simulator directly in itself - it can use a library.
    /// @param data ABI-encoded params that the pool requires.
    /// @return finalAmountOut The amount of output tokens that will be sent to the user if the trade is executed.
    function getAmountOut(bytes calldata data) external view returns (uint256 finalAmountOut);

    /// @notice Simulates a trade and returns the expected output.
    /// @dev The pool does not need to include a trade simulator directly in itself - it can use a library.
    /// @param data ABI-encoded params that the pool requires.
    /// @return finalAmountIn The amount of input tokens that are required from the user if the trade is executed.
    function getAmountIn(bytes calldata data) external view returns (uint256 finalAmountIn);

    function getReserves() external view returns (uint256 _token0, uint256 _token1);

    function totalSupply() external view returns (uint256);

    /// @dev This event must be emitted on all swaps.
    event Swap(address indexed recipient, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    /// @dev This struct frames output tokens for burns.
    struct TokenAmount {
        address token;
        uint256 amount;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "./IPool.sol";
import "./IBentoBox.sol";
import "./IMiniChefV2.sol";
import "./IComplexRewarderTime.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../libraries/Helpers.sol";
import "../BaseFarmStrategy.sol";

/**
 *        __                   __
 *       / /   ___  ___  _____/ /_
 *      / /   / _ \/ _ \/ ___/ __ \
 *     / /___/  __/  __/ /__/ / / / v.0.2-beta
 *    /_____/\___/\___/\___/_/ /_/           __
 *    / __ \_________  / /_____  _________  / /
 *   / /_/ / ___/ __ \/ __/ __ \/ ___/ __ \/ /
 *  / ____/ /  / /_/ / /_/ /_/ / /__/ /_/ / /
 * /_/   /_/   \____/\__/\____/\___/\____/_/
 *
 * @title Leech Protocol farming strategy for Sushi Swap stable pair.
 * @author Leech Protocol (https://app.leechprotocol.com/).
 * @notice Only for the stable pairs on Sushi Swap.
 * @custom:version 0.2-beta.
 * @custom:network Optimism (chainId 10).
 * @custom:provider Sushi Swap (https://sushi.com/).
 * @custom:security Found vulnerability? Get reward ([email protected]).
 */
contract StrategySushiStableFarm is BaseFarmStrategy {
    /// @dev OpenZeppelin's library for ERC20 tokens.
    using SafeERC20 for IERC20;

    /// @dev To extract address from bytes.
    using Helpers for bytes;

    /// @dev To calc slippage.
    using Helpers for uint256;

    /// @dev For max approve.
    using Helpers for IERC20;

    /**
     * @notice For rewards array.
     * @param token Reward token address.
     * @param lp Pool to swap reward token to one of the pair tokens.
     */
    struct SushiRewards {
        IERC20 token;
        SushiRewardsPath[] path;
    }

    /**
     * @notice Rewards pathes.
     * @param token Path token address.
     * @param lp Pool to swap tokens.
     */
    struct SushiRewardsPath {
        IERC20 token;
        IPool lp;
    }

    /// @notice Sushi Swap Bento Box contract.
    IBentoBox public constant BENTO_BOX =
        IBentoBox(0xc35DADB65012eC5796536bD9864eD8773aBc74C4);

    /// @notice Sushi's Optimism masterchef.
    IMiniChefV2 public constant MINI_CHEF =
        IMiniChefV2(0xB25157bF349295a7Cd31D1751973f426182070D6);

    /// @notice For additional rewards.
    IComplexRewarderTime public constant REWARDER =
        IComplexRewarderTime(0x320a04B981c092884a9783cdE907578F613EF773);

    /// @notice First token of the pair.
    IERC20 public immutable token0;

    /// @notice Second token of the pair.
    IERC20 public immutable token1;

    /// @notice Liquidity provider.
    IPool public immutable lp;

    /// @notice Sushi's pool id.
    uint16 public immutable poolId;

    /// @notice Autocompound in this token.
    IERC20 public reinvestToken;

    /// @notice Reward tokens.
    SushiRewards[] public rewards;

    /**
     * @notice Executes on contract deployment.
     * @param params General strategy parameters.
     * @param _token0 First token of the pair.
     * @param _token1 Second token of the pair.
     * @param _lp LP token.
     * @param _poolId Sushi's pool id.
     * @param _rewards Array with reward tokens.
     */
    constructor(
        InstallParams memory params,
        IERC20 _token0,
        IERC20 _token1,
        IPool _lp,
        uint16 _poolId,
        SushiRewards[] memory _rewards
    ) BaseFarmStrategy(params) {
        // Set params on deploy
        (token0, token1, lp, poolId, rewards) = (
            _token0,
            _token1,
            _lp,
            _poolId,
            _rewards
        );
        // Set reinvest token
        reinvestToken = _token0;
        // Approve token transfers
        IERC20(address(lp)).approveAll(address(MINI_CHEF));
    }

    /**
     * @notice Re-invests rewards.
     * @dev There is no restrictions for anybody to call this function.
     * @dev Have re-entrancy lock.
     */
    function autocompound(uint16) public override lock {
        // Execute parent
        super.autocompound(0);
        // Get claimable amounts
        (address[] memory tokens, uint256[] memory amounts) = claimable();
        // Arrays isn't equal
        if (tokens.length != amounts.length) revert ArrayDifferentLength();
        // Is any rewards available?
        bool _hasRewards;
        // Check amounts
        for (uint256 i = 0; i < tokens.length; i++) {
            if (amounts[i] != 0) {
                // Reward founded
                _hasRewards = true;
                break;
            }
        }
        // If not - revert tx
        if (!_hasRewards) revert NoRewardsAvailable();
        // Claim rewards
        MINI_CHEF.harvest(poolId, address(this));
        // Exchange rewards to one of the pool token
        for (uint256 i = 0; i < rewards.length; i++) {
            // Find reward amount
            for (uint256 j = 0; j < tokens.length; j++) {
                // Reward token founded
                if (address(rewards[i].token) == address(tokens[j])) {
                    // Skip if no rewards available
                    if (amounts[j] == 0) break;
                    // Swap rewards
                    for (uint256 k = 0; k < (rewards[i].path.length); k++) {
                        // Transfer token amount to the BentoBox for swap
                        rewards[i].path[k].token.safeTransfer(
                            address(BENTO_BOX),
                            amounts[j]
                        );
                        // Deposit the specified amount of depositToken into BentoBox
                        BENTO_BOX.deposit(
                            address(rewards[i].path[k].token),
                            address(BENTO_BOX),
                            address(rewards[i].path[k].lp),
                            amounts[j],
                            0
                        );
                        // Make the swap
                        amounts[j] = rewards[i].path[k].lp.swap(
                            // Encode request params to bytes
                            abi.encode(
                                address(rewards[i].path[k].token),
                                address(this),
                                true
                            )
                        );
                    }
                }
            }
        }
        // Reward balance
        uint256 _rewardBalance = token0.balanceOf(address(this));
        // In case if reinvest token != token0
        if (reinvestToken != token0) {
            // Send to BentoBox
            token0.safeTransfer(address(BENTO_BOX), _rewardBalance);
            // Deposit to pool
            BENTO_BOX.deposit(
                address(token0),
                address(BENTO_BOX),
                address(lp),
                _rewardBalance,
                0
            );
            // Make the swap and update reward balance
            _rewardBalance = lp.swap(
                // Encode request params to bytes
                abi.encode(address(token0), address(this), true)
            );
        }
        // Protocol fees
        uint256 _fee = _rewardBalance.calcFee(protocolFee);
        // Sent fees to treasury
        reinvestToken.safeTransfer(treasury, _fee);
        // Blank address
        address[] memory _blank;
        // Deposit reward to liquidity provider
        _deposit(_blank, abi.encode(reinvestToken));
        // Notify services
        emit Compounded(_rewardBalance, _fee, block.timestamp);
    }

    /**
     * @notice Update rewards.
     * @param newRewards Array with rewards data.
     */
    function setRewards(SushiRewards[] calldata newRewards) external onlyOwner {
        rewards = newRewards;
    }

    /**
     * @notice Update rewards.
     * @dev New reinvest token should be the one of the pair tokens.
     * @param newReinvestToken Autocompound in this token.
     */
    function setReinvestToken(IERC20 newReinvestToken) external onlyOwner {
        if (newReinvestToken != token0 && newReinvestToken != token1)
            revert BadToken();
        reinvestToken = newReinvestToken;
    }

    /**
     * @notice Function returns estimated amount of token out from the LP withdrawn LP amount.
     * @param shares Amount of shares.
     * @param data Additional params.
     * @return amountOut Shares amount in USD.
     */
    function quotePotentialWithdraw(
        uint256 shares,
        address[] calldata,
        address[] calldata,
        bytes calldata data,
        uint256,
        uint256
    ) public view override notZeroAmount(shares) returns (uint256 amountOut) {
        // Convert shares to LP amount
        uint256 lpAmount = (balance() * shares) / totalAllocation;
        // Get liquidity provider token reserves
        (uint256 reserve0, uint256 reserve1) = lp.getReserves();
        // Get total supply
        uint256 totalSupply = lp.totalSupply();
        // Wanted token0 amount
        uint256 token0Amount = (lpAmount * reserve0) / totalSupply;
        // Wanted token1 amount
        uint256 token1Amount = (lpAmount * reserve1) / totalSupply;
        // Check token0 amount
        if (data.toAddress() == address(token0)) {
            amountOut += token0Amount;
        } else {
            amountOut += lp.getAmountOut(
                abi.encode(address(token0), token0Amount)
            );
        }
        // Check token1 amount
        if (data.toAddress() == address(token1)) {
            amountOut += token1Amount;
        } else {
            amountOut += lp.getAmountOut(
                abi.encode(address(token1), token1Amount)
            );
        }
    }

    /**
     * @notice Amount of LPs staked into Masterchef.
     * @return amount LP amount.
     */
    function balance() public view override returns (uint256 amount) {
        // Get strategy balance.
        (amount, ) = MINI_CHEF.userInfo(poolId, address(this));
    }

    /**
     * @notice Amounts of pending rewards.
     * @return tokens Array of reward tokens.
     * @return amounts Array of reward amounts.
     */
    function claimable()
        public
        view
        override
        returns (address[] memory, uint256[] memory)
    {
        // Reward token addresses
        address[] memory tokens = new address[](rewards.length);
        // Reward token amounts
        uint256[] memory amounts = new uint256[](rewards.length);
        // First reward should be always sushi
        tokens[0] = address(rewards[0].token);
        // Reward in SUSHI tokens
        amounts[0] = MINI_CHEF.pendingSushi(poolId, address(this));
        // Amount of additional rewards (non-SUSHI)
        (
            address[] memory rewardTokens,
            uint256[] memory rewardAmounts
        ) = REWARDER.pendingTokens(poolId, address(this), 0);
        // Collect reward data
        for (uint256 i = 1; i <= rewardTokens.length; i++) {
            tokens[i] = rewardTokens[i - 1];
            amounts[i] = rewardAmounts[i - 1];
        }
        // Return claimable amounts.
        return (tokens, amounts);
    }

    /**
     * @notice Depositing into the farm pool.
     * @dev Only LeechRouter can call this function.
     * @dev Re-entrancy lock on the LeechRouter side.
     * @param data Deposit token
     */
    function _deposit(
        address[] memory,
        bytes memory data
    ) internal override returns (uint256 share) {
        // Get deposit token
        IERC20 depositToken = IERC20(data.toAddress());
        // Get paired token (by default token1)
        IERC20 oppositToken = token1;
        // Check deposit token
        if (address(depositToken) != address(token0)) {
            // If depositToken token1, make opposit token0
            oppositToken = token0;
            // Revert if not token1 or token0
            if (address(depositToken) != address(token1)) revert BadToken();
        }
        // Get deposit amount
        uint256 amountIn = depositToken.balanceOf(address(this));
        // Check deposit amount
        if (amountIn == 0) revert ZeroAmount();
        // Transfer the specified amount of depositToken to BentoBox
        depositToken.safeTransfer(address(BENTO_BOX), amountIn);
        // Deposit the specified amount of depositToken into BentoBox
        BENTO_BOX.deposit(
            address(depositToken),
            address(BENTO_BOX),
            address(lp),
            amountIn / 2,
            0
        );
        // Make the swap
        uint256 amountOut = lp.swap(
            // Encode request params to bytes
            abi.encode(address(depositToken), address(this), true)
        );
        // Check amountOut to prevent slippage
        if (amountOut < (amountIn / 2).withSlippage(slippage))
            revert SlippageProtection();
        // Transfer the specified amount of oppositToken to BentoBox
        oppositToken.safeTransfer(address(BENTO_BOX), amountOut);
        // Deposit the rest of amount of depositToken into BentoBox
        BENTO_BOX.deposit(
            address(depositToken),
            address(BENTO_BOX),
            address(lp),
            amountIn / 2,
            0
        );
        // Deposit the swapped amount of oppositToken into BentoBox
        BENTO_BOX.deposit(
            address(oppositToken),
            address(BENTO_BOX),
            address(lp),
            amountOut,
            0
        );
        // Mint SSLP
        share = lp.mint(abi.encode(address(this)));
        // Deposit LP
        MINI_CHEF.deposit(poolId, share, address(this));
    }

    /**
     * @notice Withdrawing staking token (LP) from the strategy.
     * @dev Can only be called by LeechRouter.
     * @dev Re-entrancy lock on the LeechRouter side.
     * @param user User address.
     * @param lpAmount Amount of the strategy shares to be withdrawn.
     * @param data Output token encoded to bytes string.
     * @param withdrawSlippage Slippage tolerance.
     * @return tokenOutAmount Amount of the token returned to LeechRouter.
     */
    function _withdraw(
        address user,
        uint256 lpAmount,
        address[] memory,
        address[] memory,
        bytes memory data,
        uint16 withdrawSlippage
    ) internal override returns (uint256 tokenOutAmount) {
        // Withdraw LP to the Sushi pool
        MINI_CHEF.withdraw(poolId, lpAmount, address(lp));
        // Remove liquidity
        IPool.TokenAmount[] memory _amountsOut = lp.burn(
            abi.encode(address(this), true)
        );
        // Get withdraw token
        IERC20 withdrawToken = IERC20(data.toAddress());
        // Get paired token (by default token1)
        IERC20 oppositToken = token1;
        // Check withdraw token
        if (address(withdrawToken) != address(token0)) {
            // If withdrawToken token1, make opposit token0
            oppositToken = token0;
            // Revert if not token1 or token0
            if (address(withdrawToken) != address(token1)) revert BadToken();
        }
        // Swap second token
        uint256 _oppositAmount = address(oppositToken) == _amountsOut[0].token
            ? _amountsOut[0].amount
            : _amountsOut[1].amount;
        // Transfer the specified amount of oppositToken to BentoBox
        oppositToken.safeTransfer(address(BENTO_BOX), _oppositAmount);
        // Deposit the oppositToken into BentoBox
        BENTO_BOX.deposit(
            address(oppositToken),
            address(BENTO_BOX),
            address(lp),
            _oppositAmount,
            0
        );
        // Make the swap
        uint256 _amountOut = lp.swap(
            // Encode request params to bytes
            abi.encode(address(oppositToken), address(this), true)
        );
        // Check amountOut to prevent slippage
        if (_amountOut < _oppositAmount.withSlippage(withdrawSlippage))
            revert SlippageProtection();
        // Get final amount in withdraw token
        tokenOutAmount = withdrawToken.balanceOf(address(this));
        // Send to LeechRouter
        withdrawToken.safeTransfer(user, tokenOutAmount);
    }
}