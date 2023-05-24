/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-24
*/

// SPDX-License-Identifier: gpl-3.0

// Sources flattened with hardhat v2.13.0 https://hardhat.org

// File contracts/external/openzeppelin/contracts/utils/Context.sol

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


// File contracts/external/openzeppelin/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

// pragma solidity ^0.8.0;

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


// File contracts/external/openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol

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


// File contracts/external/openzeppelin/contracts/token/ERC20/IERC20.sol

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


// File contracts/external/openzeppelin/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

// pragma solidity ^0.8.1;

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


// File contracts/external/openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

// pragma solidity ^0.8.0;



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


// File contracts/external/openzeppelin/contracts/security/ReentrancyGuard.sol

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


// File contracts/interfaces/IveToken.sol

// pragma solidity ^0.8.0;

interface IveToken {
    function checkpoint() external;

    function depositFor(address addr, uint128 value) external;

    function createLock(uint128 value, uint256 unlockTime) external;

    function increaseAmount(uint128 value) external;

    function increaseUnlockTime(uint256 unlockTime) external;

    function withdraw() external;

    function userPointEpoch(address addr) external view returns (uint256);

    function lockedEnd(address addr) external view returns (uint256);

    function getLastUserSlope(address addr) external view returns (int128);

    function getUserPointHistoryTS(
        address addr,
        uint256 idx
    ) external view returns (uint256);

    function balanceOf(
        address addr,
        uint256 ts
    ) external view returns (uint256);

    function balanceOf(address addr) external view returns (uint256);

    function balanceOfAt(
        address,
        uint256 blockNumber
    ) external view returns (uint256);

    function totalSupply(uint256 ts) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function totalSupplyAt(uint256 blockNumber) external view returns (uint256);
}


// File contracts/VeToken.sol

// pragma solidity ^0.8.0;



contract VeToken is IveToken, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum ActionType {
        DEPOSIT_FOR,
        CREATE_LOCK,
        INCREASE_AMOUNT,
        INCREASE_LOCK_TIME
    }

    struct Point {
        int128 bias; // veToken value at this point
        int128 slope; // slope at this point
        uint256 ts; // timestamp of this point
        uint256 blk; // block number of this point
    }
    /* We cannot really do block numbers per se b/c slope is per time, not per block
     * and per block could be fairly bad b/c Ethereum changes blocktimes.
     * What we can do is to extrapolate ***At functions */

    struct LockedBalance {
        uint128 amount; // amount of Token locked for a user.
        uint256 end; // the expiry time of the deposit.
    }

    // veToken token related
    string public version;
    string public constant name = "Vote-escrow EXTRA";
    string public constant symbol = "veEXTRA";
    uint8 public constant decimals = 18;

    uint256 public totalTokenLocked;
    uint256 public constant WEEK = 1 weeks;
    uint256 public constant MAX_TIME = 1 * 365 days;
    uint256 public constant MIN_TIME = 1 * WEEK;
    uint256 public constant MULTIPLIER = 10 ** 18;
    int128 public constant I_SLOPE_DENOMINATOR = int128(uint128(MAX_TIME));
    int128 public constant I_MIN_TIME = int128(uint128(WEEK));

    /// Base Token related information
    address public immutable Token;

    /// @dev Mappings to store global point information
    uint256 public epoch;
    mapping(uint256 => Point) public pointHistory; // epoch -> unsigned point
    mapping(uint256 => int128) public slopeChanges; // time -> signed slope change

    /// @dev Mappings to store user deposit information
    mapping(address => LockedBalance) public lockedBalances; // user Deposits
    mapping(address => mapping(uint256 => Point)) public userPointHistory; // user -> point[userEpoch]
    mapping(address => uint256) public userPointEpoch;

    event UserCheckpoint(
        ActionType indexed actionType,
        address indexed provider,
        uint256 value,
        uint256 indexed locktime
    );
    event GlobalCheckpoint(address caller, uint256 epoch);
    event Withdraw(address indexed provider, uint256 value, uint256 ts);
    event Supply(uint256 prevSupply, uint256 supply);

    /// @dev Constructor
    constructor(address _token, string memory _version) {
        require(_token != address(0), "_token is zero address");
        Token = _token;
        version = _version;
        pointHistory[0].blk = block.number;
        pointHistory[0].ts = block.timestamp;
    }

    /// @notice Record global data to checkpoint
    function checkpoint() external {
        _updateGlobalPoint();
        emit GlobalCheckpoint(_msgSender(), epoch);
    }

    /// @notice Deposit and lock tokens for a user
    /// @dev Anyone (even a smart contract) can deposit tokens for someone else, but
    ///      cannot extend their locktime and deposit for a user that is not locked
    /// @param addr Address of the user
    /// @param value Amount of tokens to deposit
    function depositFor(address addr, uint128 value) external nonReentrant {
        LockedBalance memory existingDeposit = lockedBalances[addr];
        require(value > 0, "Cannot deposit 0 tokens");
        require(existingDeposit.amount > 0, "No existing lock");

        require(
            existingDeposit.end > block.timestamp,
            "Lock expired. Withdraw"
        );
        _depositFor(addr, value, 0, existingDeposit, ActionType.DEPOSIT_FOR);
    }

    /// @notice Deposit `value` for `msg.sender` and lock untill `unlockTime`
    /// @param value Amount of tokens to deposit
    /// @param unlockTime Time when the tokens will be unlocked
    /// @dev the user's veToken balance will decay to 0 after `unlockTime`
    /// @dev unlockTime is rownded down to whole weeks
    function createLock(
        uint128 value,
        uint256 unlockTime
    ) external nonReentrant {
        address account = _msgSender();
        uint256 roundedUnlockTime = (unlockTime / WEEK) * WEEK;
        LockedBalance memory existingDeposit = lockedBalances[account];

        require(value > 0, "Cannot lock 0 tokens");
        require(existingDeposit.amount == 0, "Withdraw old tokens first");
        require(roundedUnlockTime > block.timestamp, "Cannot lock in the past");
        require(
            roundedUnlockTime <= block.timestamp + MAX_TIME,
            "Voting lock can not longer than MAX_TIME"
        );
        _depositFor(
            account,
            value,
            roundedUnlockTime,
            existingDeposit,
            ActionType.CREATE_LOCK
        );
    }

    /// @notice Deposit `value` additional tokens for `msg.sender` without
    ///         modifying the locktime
    /// @param value Amount of tokens to deposit
    function increaseAmount(uint128 value) external nonReentrant {
        address account = _msgSender();
        LockedBalance memory existingDeposit = lockedBalances[account];

        require(value > 0, "Cannot deposit 0 tokens");
        require(existingDeposit.amount > 0, "No existing lock found");

        require(
            existingDeposit.end > block.timestamp,
            "Lock expired. Withdraw"
        );
        _depositFor(
            account,
            value,
            0,
            existingDeposit,
            ActionType.INCREASE_AMOUNT
        );
    }

    /// @notice Extend the locktime of `msg.sender`'s tokens to `unlockTime`
    /// @param unlockTime New locktime
    function increaseUnlockTime(uint256 unlockTime) external {
        address account = _msgSender();
        LockedBalance memory existingDeposit = lockedBalances[account];
        uint256 roundedUnlockTime = (unlockTime / WEEK) * WEEK; // Locktime is rounded down to weeks

        require(existingDeposit.amount > 0, "No existing lock found");
        require(
            existingDeposit.end > block.timestamp,
            "Lock expired. Withdraw"
        );
        require(
            roundedUnlockTime > existingDeposit.end,
            "Can only increase lock duration"
        );
        require(
            roundedUnlockTime <= block.timestamp + MAX_TIME,
            "Voting lock can not longer than MAX_TIME"
        );

        _depositFor(
            account,
            0,
            roundedUnlockTime,
            existingDeposit,
            ActionType.INCREASE_LOCK_TIME
        );
    }

    /// @notice Withdraw tokens for `msg.sender`
    /// @dev Only possible if the locktime has expired
    function withdraw() external nonReentrant {
        address account = _msgSender();
        LockedBalance memory existingDeposit = lockedBalances[account];
        require(existingDeposit.amount > 0, "No existing lock found");
        require(block.timestamp >= existingDeposit.end, "Lock not expired.");
        uint128 value = existingDeposit.amount;

        LockedBalance memory oldDeposit = lockedBalances[account];
        lockedBalances[account] = LockedBalance(0, 0);
        uint256 prevSupply = totalTokenLocked;
        totalTokenLocked -= value;

        // oldDeposit can have either expired <= timestamp or 0 end
        // existingDeposit has 0 end
        // Both can have >= 0 amount
        _checkpoint(account, oldDeposit, LockedBalance(0, 0));

        IERC20(Token).safeTransfer(account, value);
        emit Withdraw(account, value, block.timestamp);
        emit Supply(prevSupply, totalTokenLocked);
    }

    /// @notice Calculate total voting power at a given block number in past
    /// @param blockNumber Block number to calculate total voting power at
    /// @return Total voting power at block number
    function totalSupplyAt(
        uint256 blockNumber
    ) external view returns (uint256) {
        require(blockNumber <= block.number);
        uint256 _epoch = epoch;
        uint256 targetEpoch = _findBlockEpoch(blockNumber, _epoch);

        Point memory point0 = pointHistory[targetEpoch];
        uint256 dt = 0;

        if (targetEpoch < _epoch) {
            Point memory point1 = pointHistory[targetEpoch + 1];
            dt =
                ((blockNumber - point0.blk) * (point1.ts - point0.ts)) /
                (point1.blk - point0.blk);
        } else {
            if (point0.blk != block.number) {
                dt =
                    ((blockNumber - point0.blk) *
                        (block.timestamp - point0.ts)) /
                    (block.number - point0.blk);
            }
        }
        // Now dt contains info on how far we are beyond point0
        return supplyAt(point0, point0.ts + dt);
    }

    /// @notice Get the most recently recorded rate of voting power decrease for `addr`
    /// @param addr The address to get the rate for
    /// @return value of the slope
    function getLastUserSlope(address addr) external view returns (int128) {
        uint256 uEpoch = userPointEpoch[addr];
        if (uEpoch == 0) {
            return 0;
        }
        return userPointHistory[addr][uEpoch].slope;
    }

    /// @notice Get the timestamp for checkpoint `idx` for `addr`
    /// @param addr User wallet address
    /// @param idx User epoch number
    /// @return Epoch time of the checkpoint
    function getUserPointHistoryTS(
        address addr,
        uint256 idx
    ) external view returns (uint256) {
        return userPointHistory[addr][idx].ts;
    }

    /// @notice Get timestamp when `addr`'s lock finishes
    /// @param addr User wallet address
    /// @return Timestamp when lock finishes
    function lockedEnd(address addr) external view returns (uint256) {
        return lockedBalances[addr].end;
    }

    /// @notice Function to estimate the user deposit
    /// @param value Amount of Token to deposit
    /// @param expectedUnlockTime The expected unlock time
    /// @dev if autoCooldown is true, the user's veToken balance will
    ///      decay to 0 after `unlockTime` else the user's veToken balance
    ///      will remain = residual balance till user initiates cooldown
    function estimateDeposit(
        uint128 value,
        uint256 expectedUnlockTime
    )
        public
        view
        returns (
            int128 initialVeTokenBalance, // initial veToken balance
            int128 slope, // slope of the user's graph
            int128 bias, // bias of the user's graph
            uint256 actualUnlockTime, // actual rounded unlock time
            uint256 providedUnlockTime // expected unlock time
        )
    {
        actualUnlockTime = (expectedUnlockTime / WEEK) * WEEK;

        require(actualUnlockTime > block.timestamp, "Cannot lock in the past");
        require(
            actualUnlockTime <= block.timestamp + MAX_TIME,
            "Voting lock can not longer than MAX_TIME"
        );

        int128 amt = int128(value);
        slope = amt / I_SLOPE_DENOMINATOR;

        bias =
            slope *
            int128(int256(actualUnlockTime) - int256(block.timestamp));

        if (bias <= 0) {
            bias = 0;
        }
        initialVeTokenBalance = bias;

        return (
            initialVeTokenBalance,
            slope,
            bias,
            actualUnlockTime,
            expectedUnlockTime
        );
    }

    /// @notice Get the voting power for a user at the specified timestamp
    /// @dev Adheres to ERC20 `balanceOf` interface for Aragon compatibility
    /// @param addr User wallet address
    /// @param ts Timestamp to get voting power at
    /// @return Voting power of user at timestamp
    function balanceOf(address addr, uint256 ts) public view returns (uint256) {
        uint256 _epoch = _findUserTimestampEpoch(addr, ts);
        if (_epoch == 0) {
            return 0;
        } else {
            Point memory lastPoint = userPointHistory[addr][_epoch];
            lastPoint.bias -=
                lastPoint.slope *
                int128(int256(ts) - int256(lastPoint.ts));
            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }
            return uint256(int256(lastPoint.bias));
        }
    }

    /// @notice Get the current voting power for a user
    /// @param addr User wallet address
    /// @return Voting power of user at current timestamp
    function balanceOf(address addr) public view returns (uint256) {
        return balanceOf(addr, block.timestamp);
    }

    /// @notice Get the voting power of `addr` at block `blockNumber`
    /// @param addr User wallet address
    /// @param blockNumber Block number to get voting power at
    /// @return Voting power of user at block number
    function balanceOfAt(
        address addr,
        uint256 blockNumber
    ) public view returns (uint256) {
        uint256 min = 0;
        uint256 max = userPointEpoch[addr];

        // Find the approximate timestamp for the block number
        for (uint256 i = 0; i < 128; i++) {
            if (min >= max) {
                break;
            }
            uint256 mid = (min + max + 1) / 2;
            if (userPointHistory[addr][mid].blk <= blockNumber) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }

        // min is the userEpoch nearest to the block number
        Point memory uPoint = userPointHistory[addr][min];
        uint256 maxEpoch = epoch;

        // blocktime using the global point history
        uint256 _epoch = _findBlockEpoch(blockNumber, maxEpoch);
        Point memory point0 = pointHistory[_epoch];
        uint256 dBlock = 0;
        uint256 dt = 0;

        if (_epoch < maxEpoch) {
            Point memory point1 = pointHistory[_epoch + 1];
            dBlock = point1.blk - point0.blk;
            dt = point1.ts - point0.ts;
        } else {
            dBlock = block.number - point0.blk;
            dt = block.timestamp - point0.ts;
        }

        uint256 blockTime = point0.ts;
        if (dBlock != 0) {
            blockTime += (dt * (blockNumber - point0.blk)) / dBlock;
        }

        uPoint.bias -=
            uPoint.slope *
            int128(int256(blockTime) - int256(uPoint.ts));
        if (uPoint.bias < 0) {
            uPoint.bias = 0;
        }
        return uint256(int256(uPoint.bias));
    }

    /// @notice Calculate total voting power at current timestamp
    /// @return Total voting power at current timestamp
    function totalSupply() public view returns (uint256) {
        return totalSupply(block.timestamp);
    }

    /// @notice Calculate total voting power at a given timestamp
    /// @return Total voting power at timestamp
    function totalSupply(uint256 ts) public view returns (uint256) {
        uint256 _epoch = _findGlobalTimestampEpoch(ts);
        Point memory lastPoint = pointHistory[_epoch];
        return supplyAt(lastPoint, ts);
    }

    /// @notice Record global and per-user data to checkpoint
    /// @param addr User wallet address. No user checkpoint if 0x0
    /// @param oldDeposit Previous locked balance / end lock time for the user
    /// @param newDeposit New locked balance / end lock time for the user
    function _checkpoint(
        address addr,
        LockedBalance memory oldDeposit,
        LockedBalance memory newDeposit
    ) internal {
        Point memory uOld = Point(0, 0, 0, 0);
        Point memory uNew = Point(0, 0, 0, 0);
        int128 dSlopeOld = 0;
        int128 dSlopeNew = 0;

        // Calculate slopes and biases for oldDeposit
        // Skipped in case of createLock
        if (oldDeposit.amount > 0) {
            int128 amt = int128(oldDeposit.amount);

            if (oldDeposit.end > block.timestamp) {
                uOld.slope = amt / I_SLOPE_DENOMINATOR;

                uOld.bias =
                    uOld.slope *
                    int128(int256(oldDeposit.end) - int256(block.timestamp));
            }
        }
        // Calculate slopes and biases for newDeposit
        // Skipped in case of withdraw
        if ((newDeposit.end > block.timestamp) && (newDeposit.amount > 0)) {
            int128 amt = int128(newDeposit.amount);

            if (newDeposit.end > block.timestamp) {
                uNew.slope = amt / I_SLOPE_DENOMINATOR;
                uNew.bias =
                    uNew.slope *
                    int128(int256(newDeposit.end) - int256(block.timestamp));
            }
        }

        // Read values of scheduled changes in the slope
        // oldDeposit.end can be in the past and in the future
        // newDeposit.end can ONLY be in the future, unless everything expired: than zeros
        dSlopeOld = slopeChanges[oldDeposit.end];
        if (newDeposit.end != 0) {
            // if not "withdraw"
            dSlopeNew = slopeChanges[newDeposit.end];
        }

        // add all global checkpoints from last added global check point until now
        Point memory lastPoint = _updateGlobalPoint();
        // If last point was in this block, the slope change has been applied already
        // But in such case we have 0 slope(s)

        // update the last global checkpoint (now) with user action's consequences
        lastPoint.slope += (uNew.slope - uOld.slope);
        lastPoint.bias += (uNew.bias - uOld.bias);
        if (lastPoint.slope < 0) {
            lastPoint.slope = 0;
        }
        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
        }
        pointHistory[epoch] = lastPoint; // Record the changed point into the global history by replacement

        // Schedule the slope changes (slope is going down)
        // We subtract new_user_slope from [new_locked.end]
        // and add old_user_slope to [old_locked.end]
        if (oldDeposit.end > block.timestamp) {
            // old_dslope was <something> - u_old.slope, so we cancel that
            dSlopeOld += uOld.slope;
            if (newDeposit.end == oldDeposit.end) {
                // It was a new deposit, not extension
                dSlopeOld -= uNew.slope;
            }
            slopeChanges[oldDeposit.end] = dSlopeOld;
        }

        if (newDeposit.end > block.timestamp) {
            if (newDeposit.end > oldDeposit.end) {
                dSlopeNew -= uNew.slope;
                // old slope disappeared at this point
                slopeChanges[newDeposit.end] = dSlopeNew;
            }
            // else: we recorded it already in old_dslopes̄
        }
        // Now handle user history
        uint256 userEpc = userPointEpoch[addr] + 1;
        userPointEpoch[addr] = userEpc;
        uNew.ts = block.timestamp;
        uNew.blk = block.number;
        userPointHistory[addr][userEpc] = uNew;
    }

    /// @notice Deposit and lock tokens for a user
    /// @param addr Address of the user
    /// @param value Amount of tokens to deposit
    /// @param unlockTime Time when the tokens will be unlocked
    /// @param oldDeposit Previous locked balance of the user / timestamp
    function _depositFor(
        address addr,
        // bool autoCooldown,
        // bool enableCooldown,
        uint128 value,
        uint256 unlockTime,
        LockedBalance memory oldDeposit,
        ActionType _type
    ) internal {
        LockedBalance memory newDeposit = lockedBalances[addr];
        uint256 prevSupply = totalTokenLocked;

        totalTokenLocked += value;
        // Adding to existing lock, or if a lock is expired - creating a new one
        newDeposit.amount += value;
        // newDeposit.autoCooldown = autoCooldown;
        // newDeposit.cooldownInitiated = enableCooldown;
        if (unlockTime != 0) {
            newDeposit.end = unlockTime;
        }
        lockedBalances[addr] = newDeposit;

        /// Possibilities:
        // Both oldDeposit.end could be current or expired (>/<block.timestamp)
        // value == 0 (extend lock) or value > 0 (add to lock or extend lock)
        // newDeposit.end > block.timestamp (always)
        _checkpoint(addr, oldDeposit, newDeposit);

        if (value != 0) {
            IERC20(Token).safeTransferFrom(_msgSender(), address(this), value);
        }

        emit UserCheckpoint(_type, addr, value, newDeposit.end);
        emit Supply(prevSupply, totalTokenLocked);
    }

    /// @notice Calculate total voting power at some point in the past
    /// @param point The point (bias/slope) to start search from
    /// @param ts Timestamp to calculate total voting power at
    /// @return Total voting power at timestamp
    function supplyAt(
        Point memory point,
        uint256 ts
    ) internal view returns (uint256) {
        Point memory lastPoint = point;
        uint256 ti = (lastPoint.ts / WEEK) * WEEK;

        // Calculate the missing checkpoints
        for (uint256 i = 0; i < 255; i++) {
            ti += WEEK;
            int128 dSlope = 0;
            if (ti > ts) {
                ti = ts;
            } else {
                dSlope = slopeChanges[ti];
            }
            lastPoint.bias -=
                lastPoint.slope *
                int128(int256(ti) - int256(lastPoint.ts));
            if (ti == ts) {
                break;
            }
            lastPoint.slope += dSlope;
            lastPoint.ts = ti;
        }

        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
        }
        return uint256(int256(lastPoint.bias));
    }

    // ----------------------VIEW functions----------------------
    /// NOTE:The following ERC20/minime-compatible methods are not real balanceOf and supply!!
    /// They measure the weights for the purpose of voting, so they don't represent real coins.

    /// @notice Binary search to find the latest epoch before specifc blockNumber
    /// Therefore, we can use the checkpoint of the epoch
    /// to estimate the timestamp at the blockNumber
    /// @param blockNumber Block number to estimate timestamp for
    /// @param maxEpoch Don't go beyond this epoch
    /// @return LatestEpcoh before the blockNumber
    function _findBlockEpoch(
        uint256 blockNumber,
        uint256 maxEpoch
    ) internal view returns (uint256) {
        uint256 min = 0;
        uint256 max = maxEpoch;

        for (uint256 i = 0; i < 128; i++) {
            if (min >= max) {
                break;
            }
            uint256 mid = (min + max + 1) / 2;
            if (pointHistory[mid].blk <= blockNumber) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    function _findUserTimestampEpoch(
        address addr,
        uint256 ts
    ) internal view returns (uint256) {
        uint256 min = 0;
        uint256 max = userPointEpoch[addr];

        for (uint256 i = 0; i < 128; i++) {
            if (min >= max) {
                break;
            }
            uint256 mid = (min + max + 1) / 2;
            if (userPointHistory[addr][mid].ts <= ts) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    function _findGlobalTimestampEpoch(
        uint256 ts
    ) internal view returns (uint256) {
        uint256 min = 0;
        uint256 max = epoch;

        for (uint256 i = 0; i < 128; i++) {
            if (min >= max) {
                break;
            }
            uint256 mid = (min + max + 1) / 2;
            if (pointHistory[mid].ts <= ts) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    /// @notice add checkpoints to pointHistory for every week from last added checkpoint until now
    /// @dev block number for each added checkpoint is estimated by their respective timestamp and the blockslope
    ///         where the blockslope is estimated by the last added time/block point and the current time/block point
    /// @dev pointHistory include all weekly global checkpoints and some additional in-week global checkpoints
    /// @return lastPoint by calling this function
    function _updateGlobalPoint() private returns (Point memory lastPoint) {
        uint256 _epoch = epoch;
        lastPoint = Point({
            bias: 0,
            slope: 0,
            ts: block.timestamp,
            blk: block.number
        });
        Point memory initialLastPoint = Point({
            bias: 0,
            slope: 0,
            ts: block.timestamp,
            blk: block.number
        });
        if (_epoch > 0) {
            lastPoint = pointHistory[_epoch];
            initialLastPoint = pointHistory[_epoch];
        }
        uint256 lastCheckpoint = lastPoint.ts;

        // initialLastPoint is used for extrapolation to calculate block number
        // (approximately, for *At functions) and save them
        // as we cannot figure that out exactly from inside the contract
        uint256 blockSlope = 0; // dblock/dt, how much blocks mined per seconds
        if (block.timestamp > lastPoint.ts) {
            blockSlope =
                (MULTIPLIER * (block.number - lastPoint.blk)) /
                (block.timestamp - lastPoint.ts);
        }
        // If last point is already recorded in this block, blockSlope is zero
        // But that's ok b/c we know the block in such case.

        // Go over weeks to fill history from lastCheckpoint by creating checkpoints for each epoch(week)
        // and calculate what the current point is
        {
            uint256 ti = (lastCheckpoint / WEEK) * WEEK;
            for (uint256 i = 0; i < 255; i++) {
                // Hopefully it won't happen that this won't get used in 4 years!
                // If it does, users will be able to withdraw but vote weight will be broken

                ti += WEEK;
                int128 dslope = 0;
                if (ti > block.timestamp) {
                    ti = block.timestamp;
                } else {
                    dslope = slopeChanges[ti];
                    // If dslope is 0, it means that the slope does not change at time ti.
                    // Each time a user locks new tokens, there will be a slope change at the unlock time recorded in slopeChanges[].
                }

                // calculate the slope and bia of the new last point
                lastPoint.bias -=
                    lastPoint.slope *
                    int128(int256(ti) - int256(lastCheckpoint));
                lastPoint.slope += dslope;
                // check sanity
                if (lastPoint.bias < 0) {
                    lastPoint.bias = 0;
                }
                if (lastPoint.slope < 0) {
                    lastPoint.slope = 0;
                }

                lastCheckpoint = ti;
                lastPoint.ts = ti;
                lastPoint.blk =
                    initialLastPoint.blk +
                    (blockSlope * (ti - initialLastPoint.ts)) /
                    MULTIPLIER;
                _epoch += 1;
                if (ti == block.timestamp) {
                    lastPoint.blk = block.number;
                    pointHistory[_epoch] = lastPoint;
                    break;
                }
                pointHistory[_epoch] = lastPoint;
            }
        }

        epoch = _epoch;
        return lastPoint;
    }
}