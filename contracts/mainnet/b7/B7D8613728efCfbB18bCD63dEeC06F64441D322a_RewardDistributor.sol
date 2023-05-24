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

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;

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

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;

import "./external/openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./external/openzeppelin/contracts/access/Ownable.sol";
import "./external/openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IveToken.sol";

/// @notice This contract is used to distribute rewards to veToken holders
/// @dev This contract Distributes rewards based on user's checkpointed veEXTRA balance.
contract RewardDistributor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // @todo Update the below addresses
    address public immutable EMERGENCY_RETURN; // Emergency return address
    address public immutable veToken; // veToken contract address
    address public immutable rewardToken; // Reward Token
    uint256 public constant WEEK = 7 days;
    uint256 public constant REWARD_CHECKPOINT_DEADLINE = 1 days;

    uint256 public startTime; // Start time for reward distribution
    uint256 public lastRewardCheckpointTime; // Last time when reward was checkpointed
    uint256 public lastRewardBalance = 0; // Last reward balance of the contract
    uint256 public maxIterations = 50; // Max number of weeks a user can claim rewards in a transaction

    mapping(uint256 => uint256) public rewardsPerWeek; // Reward distributed per week
    mapping(address => uint256) public timeCursorOf; // Timestamp of last user checkpoint
    mapping(uint256 => uint256) public veTokenSupply; // Store the veToken supply per week

    bool public canCheckpointReward; // Checkpoint reward flag
    bool public isKilled = false;

    event Claimed(
        address indexed _recipient,
        bool _staked,
        uint256 _amount,
        uint256 _lastRewardClaimTime,
        uint256 _rewardClaimedTill
    );
    event RewardsCheckpointed(uint256 _amount);
    event CheckpointAllowed(bool _allowed);
    event Killed();
    event RecoveredERC20(address _token, uint256 _amount);
    event MaxIterationsUpdated(uint256 _oldNo, uint256 _newNo);

    constructor(
        address emergencyReturnAddress,
        address veTokenAddress,
        address rewardTokenAddress,
        uint256 _startTime
    ) {
        EMERGENCY_RETURN = emergencyReturnAddress;
        veToken = veTokenAddress;
        rewardToken = rewardTokenAddress;

        uint256 t = (_startTime / WEEK) * WEEK;
        // All time initialization is rounded to the week
        startTime = t; // Decides the start time for reward distibution
        lastRewardCheckpointTime = t; //reward checkpoint timestamp
    }

    /// @notice Function to add rewards in the contract for distribution
    /// @param value The amount of Token to add
    /// @dev This function is only for sending in Token.
    function addRewards(uint256 value) external nonReentrant {
        require(!isKilled);
        require(value > 0, "Reward amount must be > 0");
        IERC20(rewardToken).safeTransferFrom(
            _msgSender(),
            address(this),
            value
        );
        if (
            canCheckpointReward &&
            (block.timestamp >
                lastRewardCheckpointTime + REWARD_CHECKPOINT_DEADLINE)
        ) {
            _checkpointReward();
        }
    }

    /// @notice Update the reward checkpoint
    /// @dev Calculates the total number of tokens to be distributed in a given week.
    ///     During setup for the initial distribution this function is only callable
    ///     by the contract owner. Beyond initial distro, it can be enabled for anyone
    ///     to call.
    function checkpointReward() external nonReentrant {
        require(
            _msgSender() == owner() ||
                (canCheckpointReward &&
                    block.timestamp >
                    (lastRewardCheckpointTime + REWARD_CHECKPOINT_DEADLINE)),
            "Checkpointing not allowed"
        );
        _checkpointReward();
    }

    function claim(bool restake) external returns (uint256) {
        return claim(_msgSender(), restake);
    }

    /// @notice Function to enable / disable checkpointing of tokens
    /// @dev To be called by the owner only
    function toggleAllowCheckpointReward() external onlyOwner {
        canCheckpointReward = !canCheckpointReward;
        emit CheckpointAllowed(canCheckpointReward);
    }

    /*****************************
     *  Emergency Control
     ******************************/

    /// @notice Function to update the maximum iterations for the claim function.
    /// @param newIterationNum  The new maximum iterations for the claim function.
    /// @dev To be called by the owner only.
    function updateMaxIterations(uint256 newIterationNum) external onlyOwner {
        require(newIterationNum > 0, "Max iterations must be > 0");
        uint256 oldIterationNum = maxIterations;
        maxIterations = newIterationNum;
        emit MaxIterationsUpdated(oldIterationNum, newIterationNum);
    }

    /// @notice Function to kill the contract.
    /// @dev Killing transfers the entire Token balance to the emergency return address
    ///      and blocks the ability to claim or addRewards.
    /// @dev The contract can't be unkilled.
    function killMe() external onlyOwner {
        require(!isKilled);
        isKilled = true;
        IERC20(rewardToken).safeTransfer(
            EMERGENCY_RETURN,
            IERC20(rewardToken).balanceOf(address(this))
        );
        emit Killed();
    }

    /// @notice Recover ERC20 tokens from this contract
    /// @dev Tokens are sent to the emergency return address
    /// @param _coin token address
    function recoverERC20(address _coin) external onlyOwner {
        // Only the owner address can ever receive the recovery withdrawal
        require(_coin != rewardToken, "Can't recover Token tokens");
        uint256 amount = IERC20(_coin).balanceOf(address(this));
        IERC20(_coin).safeTransfer(EMERGENCY_RETURN, amount);
        emit RecoveredERC20(_coin, amount);
    }

    /// @notice Function to get the user earnings at a given timestamp.
    /// @param addr The address of the user
    /// @dev This function gets only for 50 days worth of rewards.
    /// @return total rewards earned by user, lastRewardCollectionTime, rewardsTill
    /// @dev lastRewardCollectionTime, rewardsTill are in terms of WEEK Cursor.
    function computeRewards(
        address addr
    )
        external
        view
        returns (
            uint256, // total rewards earned by user
            uint256, // lastRewardCollectionTime
            uint256 // rewardsTill
        )
    {
        uint256 _lastRewardCheckpointTime = lastRewardCheckpointTime;
        // Compute the rounded last token time
        _lastRewardCheckpointTime = (_lastRewardCheckpointTime / WEEK) * WEEK;
        (uint256 rewardsTill, uint256 totalRewards) = _computeRewards(
            addr,
            _lastRewardCheckpointTime
        );
        uint256 lastRewardCollectionTime = timeCursorOf[addr];
        if (lastRewardCollectionTime == 0) {
            lastRewardCollectionTime = startTime;
        }
        return (totalRewards, lastRewardCollectionTime, rewardsTill);
    }

    /// @notice Claim fees for the address
    /// @param addr The address of the user
    /// @return The amount of tokens claimed
    function claim(
        address addr,
        bool restake
    ) public nonReentrant returns (uint256) {
        require(!isKilled);
        // Get the last token time
        uint256 _lastRewardCheckpointTime = lastRewardCheckpointTime;
        if (
            canCheckpointReward &&
            (block.timestamp >
                _lastRewardCheckpointTime + REWARD_CHECKPOINT_DEADLINE)
        ) {
            // Checkpoint the rewards till the current week
            _checkpointReward();
            _lastRewardCheckpointTime = block.timestamp;
        }

        // Compute the rounded last token time
        _lastRewardCheckpointTime = (_lastRewardCheckpointTime / WEEK) * WEEK;

        // Calculate the entitled reward amount for the user
        (uint256 weekCursor, uint256 amount) = _computeRewards(
            addr,
            _lastRewardCheckpointTime
        );

        uint256 lastRewardCollectionTime = timeCursorOf[addr];
        if (lastRewardCollectionTime == 0) {
            lastRewardCollectionTime = startTime;
        }
        // update time cursor for the user
        timeCursorOf[addr] = weekCursor;

        if (amount > 0) {
            lastRewardBalance -= amount;
            if (restake) {
                // If restake == True, add the rewards to user's deposit
                IERC20(rewardToken).safeApprove(veToken, amount);
                IveToken(veToken).depositFor(addr, uint128(amount));
            } else {
                IERC20(rewardToken).safeTransfer(addr, amount);
            }
        }

        emit Claimed(
            addr,
            restake,
            amount,
            lastRewardCollectionTime,
            weekCursor
        );

        return amount;
    }

    /// @notice Checkpoint reward
    /// @dev Checkpoint rewards for at most 20 weeks at a time
    function _checkpointReward() internal {
        // Calculate the amount to distribute
        uint256 tokenBalance = IERC20(rewardToken).balanceOf(address(this));
        uint256 toDistribute = tokenBalance - lastRewardBalance;
        lastRewardBalance = tokenBalance;

        uint256 t = lastRewardCheckpointTime;
        // Store the period of the last checkpoint
        uint256 sinceLast = block.timestamp - t;
        lastRewardCheckpointTime = block.timestamp;
        uint256 thisWeek = (t / WEEK) * WEEK;
        uint256 nextWeek = 0;

        for (uint256 i = 0; i < 20; i++) {
            nextWeek = thisWeek + WEEK;
            veTokenSupply[thisWeek] = IveToken(veToken).totalSupply(thisWeek);
            // Calculate share for the ongoing week
            if (block.timestamp < nextWeek) {
                if (sinceLast == 0) {
                    rewardsPerWeek[thisWeek] += toDistribute;
                } else {
                    // In case of a gap in time of the distribution
                    // Reward is divided across the remainder of the week
                    rewardsPerWeek[thisWeek] +=
                        (toDistribute * (block.timestamp - t)) /
                        sinceLast;
                }
                break;
                // Calculate share for all the past weeks
            } else {
                rewardsPerWeek[thisWeek] +=
                    (toDistribute * (nextWeek - t)) /
                    sinceLast;
            }
            t = nextWeek;
            thisWeek = nextWeek;
        }

        emit RewardsCheckpointed(toDistribute);
    }

    /// @notice Get the nearest user epoch for a given timestamp
    /// @param addr The address of the user
    /// @param ts The timestamp
    /// @param maxEpoch The maximum possible epoch for the user.
    function _findUserTimestampEpoch(
        address addr,
        uint256 ts,
        uint256 maxEpoch
    ) internal view returns (uint256) {
        uint256 min = 0;
        uint256 max = maxEpoch;

        // Binary search
        for (uint256 i = 0; i < 128; i++) {
            if (min >= max) {
                break;
            }
            uint256 mid = (min + max + 1) / 2;
            if (IveToken(veToken).getUserPointHistoryTS(addr, mid) <= ts) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    /// @notice Function to initialize user's reward weekCursor
    /// @param addr The address of the user
    /// @return weekCursor The weekCursor of the user
    function _initializeUser(
        address addr
    ) internal view returns (uint256 weekCursor) {
        uint256 userEpoch = 0;
        // Get the user's max epoch
        uint256 maxUserEpoch = IveToken(veToken).userPointEpoch(addr);

        require(maxUserEpoch > 0, "User has no deposit");

        // Find the Timestamp curresponding to reward distribution start time
        userEpoch = _findUserTimestampEpoch(addr, startTime, maxUserEpoch);

        // In case the User deposits after the startTime
        // binary search returns userEpoch as 0
        if (userEpoch == 0) {
            userEpoch = 1;
        }
        // Get the user deposit timestamp
        uint256 userPointTs = IveToken(veToken).getUserPointHistoryTS(
            addr,
            userEpoch
        );
        // Compute the initial week cursor for the user for claiming the reward.
        weekCursor = ((userPointTs + WEEK - 1) / WEEK) * WEEK;
        // If the week cursor is less than the reward start time
        // Update it to the reward start time.
        if (weekCursor < startTime) {
            weekCursor = startTime;
        }
        return weekCursor;
    }

    /// @notice Function to get the total rewards for the user.
    /// @param addr The address of the user
    /// @param _lastRewardCheckpointTime The last reward checkpoint
    /// @return WeekCursor of User, TotalRewards
    function _computeRewards(
        address addr,
        uint256 _lastRewardCheckpointTime
    )
        internal
        view
        returns (
            uint256, // WeekCursor
            uint256 // TotalRewards
        )
    {
        uint256 toDistrbute = 0;
        // Get the user's reward time cursor.
        uint256 weekCursor = timeCursorOf[addr];

        if (weekCursor == 0) {
            weekCursor = _initializeUser(addr);
        }

        // Iterate over the weeks
        for (uint256 i = 0; i < maxIterations; i++) {
            // Users can't claim the reward for the ongoing week.
            if (weekCursor >= _lastRewardCheckpointTime) {
                break;
            }

            // Get the week's balance for the user
            uint256 balance = IveToken(veToken).balanceOf(addr, weekCursor);
            if (balance > 0 && veTokenSupply[weekCursor] > 0) {
                // Compute the user's share for the week.
                toDistrbute +=
                    (balance * rewardsPerWeek[weekCursor]) /
                    veTokenSupply[weekCursor];
            }

            weekCursor += WEEK;
        }

        return (weekCursor, toDistrbute);
    }
}