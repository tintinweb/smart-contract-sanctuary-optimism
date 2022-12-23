/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-12-23
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

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
/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
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
        return a / b + (a % b == 0 ? 0 : 1);
    }
}
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
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
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

library BeamerUtils {
    struct FillInfo {
        address filler;
        bytes32 fillId;
    }

    function createRequestHash(
        uint256 requestId,
        uint256 sourceChainId,
        uint256 targetChainId,
        address targetTokenAddress,
        address targetReceiverAddress,
        uint256 amount
    ) internal pure returns (bytes32) {
        return
        keccak256(
            abi.encodePacked(
                requestId,
                sourceChainId,
                targetChainId,
                targetTokenAddress,
                targetReceiverAddress,
                amount
            )
        );
    }

    function createFillHash(bytes32 requestHash, bytes32 fillId)
    internal
    pure
    returns (bytes32)
    {
        return keccak256(abi.encodePacked(requestHash, fillId));
    }

    function createFillHash(
        uint256 requestId,
        uint256 sourceChainId,
        uint256 targetChainId,
        address targetTokenAddress,
        address targetReceiverAddress,
        uint256 amount,
        bytes32 fillId
    ) internal pure returns (bytes32) {
        return
        createFillHash(
            createRequestHash(
                requestId,
                sourceChainId,
                targetChainId,
                targetTokenAddress,
                targetReceiverAddress,
                amount
            ),
            fillId
        );
    }
}

/// The messenger interface.
///
/// Implementations of this interface are expected to transport
/// messages across the L1 <-> L2 boundary. For instance,
/// if an implementation is deployed on L1, the :sol:func:`sendMessage`
/// would send a message to a L2 chain, as determined by the implementation.
/// In order to do this, a messenger implementation may use a native
/// messenger contract. In such cases, :sol:func:`nativeMessenger` must
/// return the address of the native messenger contract.
interface IMessenger {
    /// Send a message across the L1 <-> L2 boundary.
    ///
    /// @param target The message recipient.
    /// @param message The message.
    /// @param gasLimit The transaction's gas limit.
    function sendMessage(
        address target,
        bytes calldata message,
        uint32 gasLimit
    ) external;

    /// Get the original sender of the last message.
    function originalSender() external view returns (address);

    /// Get the native messenger contract.
    ///
    /// In case a native messenger is not used, zero must be returned.
    function nativeMessenger() external view returns (address);
}


/// A helper contract that provides a way to restrict cross-domain callers of
/// restricted functions to a single address. This allows for a trusted call chain,
/// as described in :ref:`contracts' architecture <contracts-architecture>`.
///
/// Unlike :sol:contract:`RestrictedCalls`, which is used for calls on the same chain,
/// this contract is used to restrict calls that come from a chain different from the
/// one this contract is deployed on.
///
/// .. seealso:: :sol:contract:`RestrictedCalls` :sol:interface:`IMessenger`
contract CrossDomainRestrictedCalls is Ownable {
    struct MessengerSource {
        IMessenger messenger;
        address sender;
    }

    /// Maps chain IDs to messenger and callers.
    mapping(uint256 => MessengerSource) public messengers;

    /// Add a caller for the given chain ID.
    ///
    /// .. note:: There can only be one caller per chain.
    ///
    /// @param chainId The chain ID.
    /// @param messenger The messenger, an instance of :sol:interface:`IMessenger`.
    /// @param caller The caller.
    function addCaller(
        uint256 chainId,
        address messenger,
        address caller
    ) external onlyOwner {
        require(messenger != address(0), "XRestrictedCalls: invalid messenger");
        messengers[chainId] = MessengerSource(IMessenger(messenger), caller);
    }

    /// Mark the function as restricted.
    ///
    /// Calls to the restricted function can only come from one address, that
    /// was previously added by a call to :sol:func:`addCaller`.
    ///
    /// Example usage::
    ///
    ///     restricted(foreignChainId, msg.sender)
    ///
    modifier restricted(uint256 chainId, address caller) {
        MessengerSource storage s = messengers[chainId];
        require(
            address(s.messenger) != address(0),
            "XRestrictedCalls: unknown caller"
        );
        require(
            caller == s.messenger.nativeMessenger(),
            "XRestrictedCalls: unknown caller"
        );
        require(
            s.messenger.originalSender() == s.sender,
            "XRestrictedCalls: unknown caller"
        );
        _;
    }
}


/// The resolution registry.
///
/// This contract resides on the source L2 chain and is tasked with keeping track of results
/// of L1 resolution. In particular, it stores the information about known fills and fillers,
/// as well as fills that were marked invalid. This information is used by the :sol:contract:`RequestManager`
/// to resolve claims.
///
/// .. note::
///
///   This contract can only be called by the :sol:contract:`Resolver` contract, via a
///   chain-dependent messenger contract.
contract ResolutionRegistry is CrossDomainRestrictedCalls {
    /// Emitted when a request has been resolved via L1 resolution.
    ///
    /// .. seealso:: :sol:func:`resolveRequest`
    event RequestResolved(bytes32 requestHash, address filler, bytes32 fillId);

    /// Emitted when a fill hash has been invalidated.
    ///
    /// .. seealso:: :sol:func:`invalidateFill`
    event FillHashInvalidated(bytes32 fillHash);

    /// Maps request hashes to fill infos.
    mapping(bytes32 => BeamerUtils.FillInfo) public fillers;

    /// The set of invalid fill hashes.
    mapping(bytes32 => bool) public invalidFillHashes;

    /// Mark the request identified by ``requestHash`` as filled by ``filler``.
    ///
    /// .. note::
    ///
    ///     This function is callable only by the native L2 messenger contract,
    ///     which simply delivers the message sent from L1 by the
    ///     Beamer's L2 :sol:interface:`messenger <IMessenger>` contract.
    ///
    /// @param requestHash The request hash.
    /// @param fillId The fill ID.
    /// @param resolutionChainId The resolution (L1) chain ID.
    /// @param filler The address that filled the request.
    function resolveRequest(
        bytes32 requestHash,
        bytes32 fillId,
        uint256 resolutionChainId,
        address filler
    ) external restricted(resolutionChainId, msg.sender) {
        require(
            fillers[requestHash].filler == address(0),
            "Resolution already recorded"
        );
        fillers[requestHash] = BeamerUtils.FillInfo(filler, fillId);
        // Revert fill hash invalidation, fill proofs outweigh an invalidation
        bytes32 fillHash = BeamerUtils.createFillHash(requestHash, fillId);
        invalidFillHashes[fillHash] = false;

        emit RequestResolved(requestHash, filler, fillId);
    }

    /// Mark the fill identified by ``fillId`` as invalid.
    ///
    /// .. note::
    ///
    ///     This function is callable only by the native L2 messenger contract,
    ///     which simply delivers the message sent from L1 by the
    ///     Beamer's L2 :sol:interface:`messenger <IMessenger>` contract.
    ///
    /// @param requestHash The request hash.
    /// @param fillId The fill ID.
    /// @param resolutionChainId The resolution (L1) chain ID.
    function invalidateFill(
        bytes32 requestHash,
        bytes32 fillId,
        uint256 resolutionChainId
    ) external restricted(resolutionChainId, msg.sender) {
        require(
            fillers[requestHash].filler == address(0),
            "Cannot invalidate resolved fillHashes"
        );
        bytes32 fillHash = BeamerUtils.createFillHash(requestHash, fillId);
        require(
            invalidFillHashes[fillHash] == false,
            "FillHash already invalidated"
        );

        invalidFillHashes[fillHash] = true;

        emit FillHashInvalidated(fillHash);
    }
}


/// The request manager.
///
/// This contract is responsible for keeping track of transfer requests,
/// implementing the rules of the challenge game and holding deposited
/// tokens until they are withdrawn.
///
/// It is the only contract that agents need to interact with on the source chain.
contract RequestManager is Ownable {
    using Math for uint256;
    using SafeERC20 for IERC20;

    // Structs
    // TODO: check if we can use a smaller type for `targetChainId`, so that the
    // fields can be packed into one storage slot
    struct Request {
        address sender;
        address sourceTokenAddress;
        uint256 targetChainId;
        address targetTokenAddress;
        address targetAddress;
        uint256 amount;
        BeamerUtils.FillInfo withdrawInfo;
        uint192 activeClaims;
        uint256 validUntil;
        uint256 lpFee;
        uint256 protocolFee;
    }

    struct Claim {
        uint256 requestId;
        address claimer;
        uint256 claimerStake;
        mapping(address => uint256) challengersStakes;
        address lastChallenger;
        uint256 challengerStakeTotal;
        uint256 withdrawnAmount;
        uint256 termination;
        bytes32 fillId;
    }

    // Events

    /// Emitted when a new request has been created.
    ///
    /// .. seealso:: :sol:func:`createRequest`
    event RequestCreated(
        uint256 requestId,
        uint256 targetChainId,
        address sourceTokenAddress,
        address targetTokenAddress,
        address targetAddress,
        uint256 amount,
        uint256 validUntil
    );

    /// Emitted when the token deposit for request ``requestId`` has been
    /// transferred to the ``receiver``.
    ///
    /// This can happen in two cases:
    ///
    ///  * the request expired and the request submitter called :sol:func:`withdrawExpiredRequest`
    ///  * a claim related to the request has been resolved successfully in favor of the claimer
    ///
    /// .. seealso:: :sol:func:`withdraw` :sol:func:`withdrawExpiredRequest`
    event DepositWithdrawn(uint256 requestId, address receiver);

    /// Emitted when a claim or a counter-claim (challenge) has been made.
    ///
    /// .. seealso:: :sol:func:`claimRequest` :sol:func:`challengeClaim`
    event ClaimMade(
        uint256 indexed requestId,
        uint256 claimId,
        address claimer,
        uint256 claimerStake,
        address lastChallenger,
        uint256 challengerStakeTotal,
        uint256 termination,
        bytes32 fillId
    );

    /// Emitted when staked native tokens tied to a claim have been withdrawn.
    ///
    /// This can only happen when the claim has been resolved and the caller
    /// of :sol:func:`withdraw` is allowed to withdraw their stake.
    ///
    /// .. seealso:: :sol:func:`withdraw`
    event ClaimStakeWithdrawn(
        uint256 claimId,
        uint256 indexed requestId,
        address claimReceiver
    );

    event FinalityPeriodUpdated(uint256 targetChainId, uint256 finalityPeriod);

    // Constants

    /// The minimum amount of source chain's native token that the claimer needs to
    /// provide when making a claim, as well in each round of the challenge game.
    uint256 public claimStake;

    /// The period for which the claim is valid.
    uint256 public claimPeriod;

    /// The period by which the termination time of a claim is extended after each
    /// round of the challenge game. This period should allow enough time for the
    /// other parties to counter-challenge.
    ///
    /// .. note::
    ///
    ///    The claim's termination time is extended only if it is less than the
    ///    extension time.
    ///
    /// Note that in the first challenge round, i.e. the round initiated by the first
    /// challenger, the termination time is extended additionally by the finality
    /// period of the target chain. This is done to allow for L1 resolution.
    uint256 public challengePeriodExtension;

    /// The minimum validity period of a request.
    uint256 public constant MIN_VALIDITY_PERIOD = 5 minutes;

    /// The maximum validity period of a request.
    uint256 public constant MAX_VALIDITY_PERIOD = 30 minutes;

    // Variables

    /// Indicates whether the contract is deprecated. A deprecated contract
    /// cannot be used to create new requests.
    bool public deprecated;

    /// The request counter, used to generate request IDs.
    uint256 public requestCounter;

    /// The claim counter, used to generate claim IDs.
    uint256 public claimCounter;

    /// The resolution registry that is used to query for results of L1 resolution.
    ResolutionRegistry public resolutionRegistry;

    /// Maps target rollup chain IDs to finality periods.
    /// Finality periods are in seconds.
    mapping(uint256 => uint256) public finalityPeriods;

    /// Maps request IDs to requests.
    mapping(uint256 => Request) public requests;

    /// Maps claim IDs to claims.
    mapping(uint256 => Claim) public claims;

    /// The minimum fee, denominated in transfer token, paid to the liquidity provider.
    uint256 public minLpFee = 5 ether; // 5e18

    /// Liquidity provider fee percentage, expressed in ppm (parts per million).
    uint256 public lpFeePPM = 1_000; // 0.1% of the token amount being transferred

    /// Protocol fee percentage, expressed in ppm (parts per million).
    uint256 public protocolFeePPM = 0; // 0% of the token amount being transferred

    /// The maximum amount of tokens that can be transferred in a single request.
    uint256 public transferLimit = 10000 ether; // 10000e18

    /// Maps ERC20 token addresses to related token amounts that belong to the protocol.
    mapping(address => uint256) public collectedProtocolFees;

    /// Compute the liquidy provider fee that needs to be paid for a given transfer amount.
    function lpFee(uint256 amount) public view returns (uint256) {
        return Math.max(minLpFee, (amount * lpFeePPM) / 1_000_000);
    }

    /// Compute the protocol fee that needs to be paid for a given transfer amount.
    function protocolFee(uint256 amount) public view returns (uint256) {
        return (amount * protocolFeePPM) / 1_000_000;
    }

    /// Compute the total fee that needs to be paid for a given transfer amount.
    /// The total fee is the sum of the liquidity provider fee and the protocol fee.
    function totalFee(uint256 amount) public view returns (uint256) {
        return lpFee(amount) + protocolFee(amount);
    }

    // Modifiers

    /// Check whether a given request ID is valid.
    modifier validRequestId(uint256 requestId) {
        require(
            requestId <= requestCounter && requestId > 0,
            "requestId not valid"
        );
        _;
    }

    /// Check whether a given claim ID is valid.
    modifier validClaimId(uint256 claimId) {
        require(claimId <= claimCounter && claimId > 0, "claimId not valid");
        _;
    }

    /// Constructor.
    ///
    /// @param _claimStake Claim stake amount.
    /// @param _claimPeriod Claim period, in seconds.
    /// @param _challengePeriodExtension Challenge period extension, in seconds.
    /// @param _resolutionRegistry Address of the resolution registry.
    constructor(
        uint256 _claimStake,
        uint256 _claimPeriod,
        uint256 _challengePeriodExtension,
        address _resolutionRegistry
    ) {
        claimStake = _claimStake;
        claimPeriod = _claimPeriod;
        challengePeriodExtension = _challengePeriodExtension;
        resolutionRegistry = ResolutionRegistry(_resolutionRegistry);
    }

    /// Create a new transfer request.
    ///
    /// @param targetChainId ID of the target chain.
    /// @param sourceTokenAddress Address of the token contract on the source chain.
    /// @param targetTokenAddress Address of the token contract on the target chain.
    /// @param targetAddress Recipient address on the target chain.
    /// @param amount Amount of tokens to transfer. Does not include fees.
    /// @param validityPeriod The number of seconds the request is to be considered valid.
    ///                       Once its validity period has elapsed, the request cannot be claimed
    ///                       anymore and will eventually expire, allowing the request submitter
    ///                       to withdraw the deposited tokens if there are no active claims.
    /// @return ID of the newly created request.
    function createRequest(
        uint256 targetChainId,
        address sourceTokenAddress,
        address targetTokenAddress,
        address targetAddress,
        uint256 amount,
        uint256 validityPeriod
    ) external returns (uint256) {
        require(deprecated == false, "Contract is deprecated");
        require(
            finalityPeriods[targetChainId] != 0,
            "Target rollup not supported"
        );
        require(
            validityPeriod >= MIN_VALIDITY_PERIOD,
            "Validity period too short"
        );
        require(
            validityPeriod <= MAX_VALIDITY_PERIOD,
            "Validity period too long"
        );
        require(amount <= transferLimit, "Amount exceeds transfer limit");

        IERC20 token = IERC20(sourceTokenAddress);

        uint256 lpFee = lpFee(amount);
        uint256 protocolFee = protocolFee(amount);
        uint256 totalTokenAmount = amount + lpFee + protocolFee;

        require(
            token.allowance(msg.sender, address(this)) >= totalTokenAmount,
            "Insufficient allowance"
        );

        requestCounter += 1;
        Request storage newRequest = requests[requestCounter];
        newRequest.sender = msg.sender;
        newRequest.sourceTokenAddress = sourceTokenAddress;
        newRequest.targetChainId = targetChainId;
        newRequest.targetTokenAddress = targetTokenAddress;
        newRequest.targetAddress = targetAddress;
        newRequest.amount = amount;
        newRequest.withdrawInfo = BeamerUtils.FillInfo(address(0), bytes32(0));
        newRequest.validUntil = block.timestamp + validityPeriod;
        newRequest.lpFee = lpFee;
        newRequest.protocolFee = protocolFee;

        emit RequestCreated(
            requestCounter,
            targetChainId,
            sourceTokenAddress,
            targetTokenAddress,
            targetAddress,
            amount,
            newRequest.validUntil
        );

        token.safeTransferFrom(msg.sender, address(this), totalTokenAmount);

        return requestCounter;
    }

    /// Withdraw funds deposited with an expired request.
    ///
    /// No claims must be active for the request.
    ///
    /// @param requestId ID of the expired request.
    function withdrawExpiredRequest(uint256 requestId)
        external
        validRequestId(requestId)
    {
        Request storage request = requests[requestId];

        require(
            request.withdrawInfo.filler == address(0),
            "Deposit already withdrawn"
        );
        require(
            block.timestamp >= request.validUntil,
            "Request not expired yet"
        );
        require(request.activeClaims == 0, "Active claims running");

        request.withdrawInfo.filler = request.sender;

        emit DepositWithdrawn(requestId, request.sender);

        IERC20 token = IERC20(request.sourceTokenAddress);
        token.safeTransfer(
            request.sender,
            request.amount + request.lpFee + request.protocolFee
        );
    }

    /// Claim that a request was filled by the caller.
    ///
    /// The request must still be valid at call time.
    /// The caller must provide the ``claimStake`` amount of source rollup's native
    /// token.
    ///
    /// @param requestId ID of the request.
    /// @param fillId The fill ID.
    /// @return The claim ID.
    function claimRequest(uint256 requestId, bytes32 fillId)
        external
        payable
        validRequestId(requestId)
        returns (uint256)
    {
        Request storage request = requests[requestId];

        require(block.timestamp < request.validUntil, "Request expired");
        require(
            request.withdrawInfo.filler == address(0),
            "Deposit already withdrawn"
        );
        require(msg.value == claimStake, "Invalid stake amount");
        require(fillId != bytes32(0), "FillId must not be 0x0");

        request.activeClaims += 1;
        claimCounter += 1;

        Claim storage claim = claims[claimCounter];
        claim.requestId = requestId;
        claim.claimer = msg.sender;
        claim.claimerStake = claimStake;
        claim.lastChallenger = address(0);
        claim.challengerStakeTotal = 0;
        claim.withdrawnAmount = 0;
        claim.termination = block.timestamp + claimPeriod;
        claim.fillId = fillId;

        emit ClaimMade(
            requestId,
            claimCounter,
            claim.claimer,
            claim.claimerStake,
            claim.lastChallenger,
            claim.challengerStakeTotal,
            claim.termination,
            fillId
        );

        return claimCounter;
    }

    /// Challenge an existing claim.
    ///
    /// The claim must still be valid at call time.
    /// This function implements one round of the challenge game.
    /// The original claimer is allowed to call this function only
    /// after someone else made a challenge, i.e. every second round.
    /// However, once the original claimer counter-challenges, anyone
    /// can join the game and make another challenge.
    ///
    /// The caller must provide enough native tokens as their stake.
    /// For the original claimer, the minimum stake is
    /// ``challengerStakeTotal - claimerStake + claimStake``.
    ///
    /// For challengers, the minimum stake is
    /// ``claimerStake - challengerStakeTotal + 1``.
    ///
    /// An example (time flows downwards, claimStake = 10)::
    ///
    ///   claimRequest() by Max [stakes 10]
    ///   challengeClaim() by Alice [stakes 11]
    ///   challengeClaim() by Max [stakes 11]
    ///   challengeClaim() by Bob [stakes 16]
    ///
    /// In this example, if Max didn't want to lose the challenge game to
    /// Alice and Bob, he would have to challenge with a stake of at least 16.
    ///
    /// @param claimId The claim ID.
    function challengeClaim(uint256 claimId)
        external
        payable
        validClaimId(claimId)
    {
        Claim storage claim = claims[claimId];
        Request storage request = requests[claim.requestId];
        require(block.timestamp < claim.termination, "Claim expired");

        address nextActor;
        uint256 minValue;
        uint256 periodExtension = challengePeriodExtension;
        uint256 claimerStake = claim.claimerStake;
        uint256 challengerStakeTotal = claim.challengerStakeTotal;

        if (claimerStake > challengerStakeTotal) {
            if (challengerStakeTotal == 0) {
                periodExtension += finalityPeriods[request.targetChainId];
            }
            require(claim.claimer != msg.sender, "Cannot challenge own claim");
            nextActor = msg.sender;
            minValue = claimerStake - challengerStakeTotal + 1;
        } else {
            nextActor = claim.claimer;
            minValue = challengerStakeTotal - claimerStake + claimStake;
        }

        require(msg.sender == nextActor, "Not eligible to outbid");
        require(msg.value >= minValue, "Not enough stake provided");

        if (nextActor == claim.claimer) {
            claim.claimerStake += msg.value;
        } else {
            claim.lastChallenger = msg.sender;
            claim.challengersStakes[msg.sender] += msg.value;
            claim.challengerStakeTotal += msg.value;
        }

        claim.termination = Math.max(
            claim.termination,
            block.timestamp + periodExtension
        );
        uint256 minimumTermination = block.timestamp + challengePeriodExtension;
        require(
            claim.termination >= minimumTermination,
            "Claim termination did not increase enough"
        );

        emit ClaimMade(
            claim.requestId,
            claimId,
            claim.claimer,
            claim.claimerStake,
            claim.lastChallenger,
            claim.challengerStakeTotal,
            claim.termination,
            claim.fillId
        );
    }

    /// Withdraw the deposit that the request submitter left with the contract,
    /// as well as the staked native tokens associated with the claim.
    ///
    /// In case the caller of this function is a challenger that won the game,
    /// they will only get their staked native tokens plus the reward in the form
    /// of full (sole challenger) or partial (multiple challengers) amount
    /// of native tokens staked by the dishonest claimer.
    ///
    /// @param claimId The claim ID.
    /// @return The address of the deposit receiver.
    function withdraw(uint256 claimId)
        external
        validClaimId(claimId)
        returns (address)
    {
        Claim storage claim = claims[claimId];
        Request storage request = requests[claim.requestId];

        (address claimReceiver, uint256 ethToTransfer) = resolveClaim(claimId);

        if (claim.challengersStakes[claimReceiver] > 0) {
            //Re-entrancy protection
            claim.challengersStakes[claimReceiver] = 0;
        }

        // First time withdraw is called, remove it from active claims
        if (claim.withdrawnAmount == 0) {
            request.activeClaims -= 1;
        }
        claim.withdrawnAmount += ethToTransfer;
        require(
            claim.withdrawnAmount <=
                claim.claimerStake + claim.challengerStakeTotal,
            "Amount to withdraw too large"
        );

        (bool sent, ) = claimReceiver.call{value: ethToTransfer}("");
        require(sent, "Failed to send Ether");

        emit ClaimStakeWithdrawn(claimId, claim.requestId, claimReceiver);

        if (
            request.withdrawInfo.filler == address(0) &&
            claimReceiver == claim.claimer
        ) {
            withdrawDeposit(request, claim);
        }

        return claimReceiver;
    }

    function resolveClaim(uint256 claimId)
        private
        view
        returns (address, uint256)
    {
        Claim storage claim = claims[claimId];
        Request storage request = requests[claim.requestId];
        uint256 claimerStake = claim.claimerStake;
        uint256 challengerStakeTotal = claim.challengerStakeTotal;
        require(
            claim.withdrawnAmount < claimerStake + challengerStakeTotal,
            "Claim already withdrawn"
        );

        bytes32 requestHash = BeamerUtils.createRequestHash(
            claim.requestId,
            block.chainid,
            request.targetChainId,
            request.targetTokenAddress,
            request.targetAddress,
            request.amount
        );

        bytes32 fillHash = BeamerUtils.createFillHash(
            requestHash,
            claim.fillId
        );

        bool claimValid = false;
        BeamerUtils.FillInfo memory withdrawInfo = request.withdrawInfo;

        // Priority list for validity check of claim
        // Claim is valid if either
        // 1) ResolutionRegistry entry in fillers, claimer is the filler
        // 2) ResolutionRegistry entry in invalidFillHashes, claim is invalid
        // 3) Request.withdrawInfo, the claimer withdrew with an identical claim (same fill id)
        // 4) Claim properties, claim terminated and claimer has the highest stake
        (address filler, bytes32 fillId) = resolutionRegistry.fillers(
            requestHash
        );

        if (filler == address(0)) {
            (filler, fillId) = (withdrawInfo.filler, withdrawInfo.fillId);
        }

        if (resolutionRegistry.invalidFillHashes(fillHash)) {
            // Claim resolution via 2)
            claimValid = false;
        } else if (filler != address(0)) {
            // Claim resolution via 1) or 3)
            claimValid = filler == claim.claimer && fillId == claim.fillId;
        } else {
            // Claim resolution via 4)
            require(
                block.timestamp >= claim.termination,
                "Claim period not finished"
            );
            claimValid = claimerStake > challengerStakeTotal;
        }

        // Calculate withdraw scheme for claim stakes
        uint256 ethToTransfer;
        address claimReceiver;

        if (claimValid) {
            // If claim is valid, all stakes go to the claimer
            ethToTransfer = claimerStake + challengerStakeTotal;
            claimReceiver = claim.claimer;
        } else if (challengerStakeTotal > 0) {
            // If claim is invalid, partial withdrawal by the sender
            ethToTransfer = 2 * claim.challengersStakes[msg.sender];
            claimReceiver = msg.sender;

            require(ethToTransfer > 0, "Challenger has nothing to withdraw");
        } else {
            // The unlikely event is possible that a false claim has no challenger
            // If it is known that the claim is false then the claim stake goes to the platform
            ethToTransfer = claimerStake;
            claimReceiver = owner();
        }

        // If the challenger wins and is the last challenger, he gets either
        // twice his stake plus the excess stake (if the claimer was winning), or
        // twice his stake minus the difference between the claimer and challenger stakes (if the claimer was losing)
        if (msg.sender == claim.lastChallenger) {
            if (claimerStake > challengerStakeTotal) {
                ethToTransfer += (claimerStake - challengerStakeTotal);
            } else {
                ethToTransfer -= (challengerStakeTotal - claimerStake);
            }
        }

        return (claimReceiver, ethToTransfer);
    }

    function withdrawDeposit(Request storage request, Claim storage claim)
        private
    {
        address claimer = claim.claimer;
        emit DepositWithdrawn(claim.requestId, claimer);

        request.withdrawInfo = BeamerUtils.FillInfo(claimer, claim.fillId);

        collectedProtocolFees[request.sourceTokenAddress] += request
            .protocolFee;

        IERC20 token = IERC20(request.sourceTokenAddress);
        token.safeTransfer(claimer, request.amount + request.lpFee);
    }

    /// Withdraw protocol fees collected by the contract.
    ///
    /// Protocol fees are paid in token transferred.
    ///
    /// .. note:: This function can only be called by the contract owner.
    ///
    /// @param tokenAddress The address of the token contract.
    /// @param recipient The address the fees should be sent to.
    function withdrawProtocolFees(address tokenAddress, address recipient)
        external
        onlyOwner
    {
        uint256 amount = collectedProtocolFees[tokenAddress];
        require(amount > 0, "Protocol fee is zero");
        collectedProtocolFees[tokenAddress] = 0;

        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(recipient, amount);
    }

    /// Update fee parameters.
    ///
    /// .. note:: This function can only be called by the contract owner.
    ///
    /// @param newProtocolFeePPM The new value for ``protocolFeePPM``.
    /// @param newLpFeePPM The new value for ``lpFeePPM``.
    /// @param newMinLpFee The new value for ``minLpFee``.
    function updateFeeData(
        uint256 newProtocolFeePPM,
        uint256 newLpFeePPM,
        uint256 newMinLpFee
    ) external onlyOwner {
        protocolFeePPM = newProtocolFeePPM;
        lpFeePPM = newLpFeePPM;
        minLpFee = newMinLpFee;
    }

    /// Update the transfer amount limit.
    ///
    /// .. note:: This function can only be called by the contract owner.
    ///
    /// @param newTransferLimit The new value for ``transferLimit``.
    function updateTransferLimit(uint256 newTransferLimit) external onlyOwner {
        transferLimit = newTransferLimit;
    }

    /// Set the finality period for the given target chain.
    ///
    /// .. note:: This function can only be called by the contract owner.
    ///
    /// @param targetChainId The target chain ID.
    /// @param finalityPeriod Finality period in seconds.
    function setFinalityPeriod(uint256 targetChainId, uint256 finalityPeriod)
        external
        onlyOwner
    {
        require(finalityPeriod > 0, "Finality period must be greater than 0");
        finalityPeriods[targetChainId] = finalityPeriod;

        emit FinalityPeriodUpdated(targetChainId, finalityPeriod);
    }

    /// Mark the contract as deprecated.
    ///
    /// Once the contract is deprecated, it cannot be used to create new
    /// requests anymore. Withdrawing deposited funds and claim stakes
    /// still works, though.
    ///
    /// .. note:: This function can only be called by the contract owner.
    function deprecateContract() external onlyOwner {
        require(deprecated == false, "Contract already deprecated");
        deprecated = true;
    }
}