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

pragma solidity ^0.8.15;

// Package imports
import { IDistributor } from "../interfaces/IDistributor.sol";
import { Events } from "../libraries/Events.sol";
import { Errors } from "../libraries/Errors.sol";
// Third-party imports
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title Distributor
 * @author API3 Latam.
 *
 * @notice Implementation for the Distributor interface.
 */
contract Distributor is
    ReentrancyGuard,
    IDistributor
{
    // ========== Libraries ==========
    using SafeERC20 for IERC20;
    using Address for address payable;

    // ========== Constructor ==========
    constructor() {}

    // ========== Core Functions ==========
    /**
     * @dev See { IDistributor-distributeNative }.
     * We do not check balance because it could become more
     * expensive to call the function. We rely that the user
     * would attach enough ETH to cover the distribution.
     */
    function distributeNative (
        address payable _sender,
        address payable[] memory _addresses,
        uint256[] memory _amounts
    ) external payable nonReentrant {
        // Check the correctness of the data types
        if (
            _addresses.length != _amounts.length
        ) revert Errors.InvalidArrayLength();
        if (
            _addresses.length == 0
        ) revert Errors.InvalidArrayLength();
        if (
            _sender == address(0)
        ) revert Errors.ZeroAddress();

        uint256 len = _addresses.length;
        uint256 total = 0;

        for(uint256 i = 0; i < len; i++) {
            total += _amounts[i];
            _addresses[i].sendValue(_amounts[i]);
        }

        if (address(this).balance > 0) {
            _sender.sendValue(address(this).balance);
        }

        emit Events.NativeDistributed(
            _sender,
            total,
            block.timestamp
        );
    }

    /**
     * @dev See { IDistributor-distributeTokens }.
     * We do not check balance because it could become very expensive.
     * So we leave the handling of any error to the sender, in
     * addition to the assurance from the SafeERC20 library.
     */
    function distributeTokens (
        IERC20 _token,
        address _sender,
        address[] memory _addresses,
        uint256[] memory _amounts
    ) external nonReentrant {
        // Check the correctness of the data types
        if (
            _addresses.length != _amounts.length
        ) revert Errors.InvalidArrayLength();
        if (
            _addresses.length == 0
        ) revert Errors.InvalidArrayLength();
        if (
            _sender == address(0)
        ) revert Errors.ZeroAddress();

        uint256 len = _addresses.length;
        uint256 total = 0;

        for (uint256 i = 0; i < len; i++) {
            total += _amounts[i];
        }

        // Can revert with: "SafeERC20: ERC20 operation did not succeed"
        _token.safeTransferFrom(_sender, address(this), total);

        for(uint256 i = 0; i < len; i++) {
            _token.safeTransfer(_addresses[i], _amounts[i]);
        }

        emit Events.TokensDistributed(
            _sender,
            address(_token),
            total,
            block.timestamp
        );
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

// Third-party imports
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IDistributor.
 * @author API3 Latam.
 *
 * @notice Provides batch transfer of cypto.
 * This contract is inspired by 'Disperse' which can be found at:
 * `0xD152f549545093347A162Dce210e7293f1452150`
 * @dev Interface for the Distributor contract.
 */
interface IDistributor {
    // ========== Core Functions ==========
    /**
     * @notice Distributes native tokens to a list of addresses.
     *
     * @param _sender The sender of the transaction.
     * @param _addresses The list of addresses to distribute to.
     * @param _amounts The amount of tokens to distribute to each address.
     */
    function distributeNative (
        address payable _sender,
        address payable[] memory _addresses,
        uint256[] memory _amounts
    ) external payable;

    /**
     * @notice Distributes tokens to a list of addresses.
     *
     * @param _token The token to distribute.
     * @param _sender The sender of the transaction.
     * @param _addresses The list of addresses to distribute to.
     * @param _amounts The amount of tokens to distribute to each address.
     */
    function distributeTokens (
        IERC20 _token,
        address _sender,
        address[] memory _addresses,
        uint256[] memory _amounts
    ) external;

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/**
 * @title DataTypes
 * @author API3 Latam
 * 
 * @notice A standard library of data types used across the API3 LATAM
 * Quantum Fair Platform.
 */
library DataTypes {
    
    // ========== Enums ==========
    /**
     * @notice An enum containing the different states a raffle can use.
     *
     * @param Unintialized - A raffle is created but yet to be open.
     * @param Canceled - A raffle that is invalidated.
     * @param Open - A raffle where participants can enter.
     * @param Close - A raffle which cannot recieve more participants.
     * @param Finish - A raffle that has been wrapped up.
     */
    enum RaffleStatus {
        Unintialized,
        Canceled,
        Open,
        Close,
        Finish
    }

    /**
     * @notice An enum containing the different tokens that a Vault can hold.
     *
     * @param Native - The native token of the network, eg. ETH or MATIC.
     * @param ERC20 - An ERC20 token.
     * @param ERC721 - An NFT.
     * @param ERC1155 - An ERC1155 token.
     */
    enum TokenType {
        Native,
        ERC20,
        ERC721,
        ERC1155
    }

    // ========== Structs ==========
    /**
     * @notice Structure to efficiently save IPFS hashes.
     * @dev To reconstruct full hash insert `hash_function` and `size` before the
     * the `hash` value. So you have `hash_function` + `size` + `hash`.
     * This gives you a hexadecimal representation of the CIDs. You need to parse
     * it to base58 from hex if you want to use it on a traditional IPFS gateway.
     *
     * @param hash - The hexadecimal representation of the CID payload from the hash.
     * @param hash_function - The hexadecimal representation of multihash identifier.
     * IPFS currently defaults to use `sha2` which equals to `0x12`.
     * @param size - The hexadecimal representation of `hash` bytes size.
     * Expecting value of `32` as default which equals to `0x20`. 
     */
    struct Multihash {
        bytes32 hash;
        uint8 hash_function;
        uint8 size;
    }

    /**
     * @notice Information for Airnode endpoints.
     *
     * @param endpointId - The unique identifier for the endpoint this
     * callbacks points to.
     * @param functionSelector - The function selector for this endpoint
     * callback.
     */
    struct Endpoint {
        bytes32 endpointId;
        bytes4 functionSelector;
    }

    /**
     * @notice Metadata information for WinnerAirnode request flow.
     * @dev This should be consume by used in addition to IndividualRaffle struct
     * to return actual winner addresses.
     *
     * @param totalEntries - The number of participants for this raffle.
     * @param totalWinners - The number of winners finally set for this raffle.
     * @param winnerIndexes - The indexes for the winners from raffle entries.
     * @param isFinished - Indicates wether the result has been retrieved or not.
     */
    struct WinnerReponse {
        uint256 totalEntries;
        uint256 totalWinners;
        uint256[] winnerIndexes;
        bool isFinished;
    }

    /**
     * @notice Structure to keep track of tokens kept in vaults.
     * @dev Some fields could be ignored depending on the type of token.
     * Eg. tokenId is of no use for ERC20 tokens.
     */
    struct TokenInventory {
        address tokenAddress;
        uint256 tokenId;
        uint256 tokenAmount;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/**
 * @title Errors
 * @author API3 Latam
 * 
 * @notice A standard library of error types used across the API3 LATAM
 * Quantum Fair Platform.
 */
library Errors {

    // ========== Core Errors ==========
    error SameValueProvided ();
    error AlreadyInitialized ();
    error InvalidProxyAddress (
        address _proxy
    );
    error ZeroAddress ();
    error WrongInitializationParams (
        string errorMessage
    );
    error InvalidParameter ();
    error InvalidAddress ();
    error InvalidAmount ();
    error ParameterNotSet ();
    error InvalidArrayLength ();
    error InsufficientBalance();
    error ParameterAlreadySet ();
    error RaffleDue ();                 // Raffle
    error RaffleNotOpen ();             // Raffle
    error RaffleNotAvailable ();        // Raffle
    error RaffleNotClose ();            // Raffle
    error RaffleAlreadyOpen ();         // Raffle
    error TicketPaymentFailed ();       // Raffle
    error EarlyClosing ();              // Raffle

    // ========== Base Errors ==========
    error CallerNotOwner (               // Ownable ERC721
        address caller
    );
    error RequestIdNotKnown ();          // AirnodeLogic
    error NoEndpointAdded ();            // AirnodeLogic
    error InvalidEndpointId ();          // AirnodeLogic
    error IncorrectCallback ();          // AirnodeLogic
    error RequestNotFulfilled ();        // AirnodeLogic
    error EndpointAlreadyExists ();    // AirnodeLogic
    error InvalidInterface ();           // ERC1820Registry
    error InvalidKey ();                 // EternalStorage
    error ValueAlreadyExists ();         // EternalStorage

    // ========== Airnode Module Errors ==========
    error InvalidWinnerNumber ();        // WinnerAirnode
    error ResultRetrieved ();            // WinnerAirnode

    // ========== Vault Module Errors ==========
    error VaultWithdrawsDisabled ();     // AssetVault
    error VaultWithdrawsEnabled ();      // AssetVault
    error TokenIdOutOfBounds (           // VaultFactory
        uint256 tokenId
    );
    error NoTransferWithdrawEnabled (    // VaultFactory
        uint256 tokenId
    );
    error BatchLengthMismatch();         // VaultDepositRouter
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

// Package imports
import { DataTypes } from "./DataTypes.sol";

/**
 * @title Events
 * @author API3 Latam
 * 
 * @notice A standard library of Events used across the API3 LATAM
 * Quantum Fair Platform.
 */
library Events {
    // ========== Core Events ==========
    /**
     * @dev Emitted when a beneficiaries are added to a Raffle.
     *
     * @param beneficiaries_ The addresses of the beneficiaries.
     * @param shares_ The shares of the beneficiaries.
     * @param raffleId_ The identifier for this specific raffle.
     * @param timestamp_ The timestamp when the beneficiaries were set.
     */
    event SetRaffleBeneficiaries (
        address[] beneficiaries_,
        uint256[] shares_,
        uint256 indexed raffleId_,
        uint256 indexed timestamp_
    );

    /**
     * @dev Emitted when a beneficiary is updated.
     *
     * @param beneficiary_ The address of the beneficiary.
     * @param oldShare_ The old share of the beneficiary.
     * @param newShare_ The new share of the beneficiary.
     * @param raffleId_ The identifier for this specific raffle.
     * @param timestamp_ The timestamp when the beneficiary was updated.
     */
    event UpdateRaffleBeneficiary (
        address indexed beneficiary_,
        uint256 oldShare_,
        uint256 newShare_,
        uint256 indexed raffleId_,
        uint256 timestamp_
    );

    /**
     * @dev Emitted when a Raffle is created.
     * 
     * @param _raffleId - The identifier for this specific raffle.
     */
    event RaffleCreated (
        uint256 indexed _raffleId
    );

    /**
     * @dev Emitted when a Raffle is opened.
     *
     * @param raffleId_ - The identifier for this specific raffle.
     * @param prizeVaultId_ - The id of the prize vault associated with this raffle.
     * @param ticketVaultId_ - The id of the ticket vault associated with this raffle.
     * @param nftAmount_ - The amount of NFTs to be raffled.
     * @param timestamp_ - The timestamp when the raffle was opened.
     */
    event RaffleOpened (
        uint256 indexed raffleId_,
        uint256 prizeVaultId_,
        uint256 ticketVaultId_,
        uint256 nftAmount_,
        uint256 indexed timestamp_
    );

    /**
     * @dev Emitted when someone buys a ticket for a raffle.
     * 
     * @param raffleId_ - The identifier for this specific raffle.
     * @param participant_ - The address of the participant.
     * @param amount_ - The amount of tickets bought.
     * @param timestamp_ - The timestamp when the participant entered the raffle.
     */
    event RaffleEntered (
        uint256 indexed raffleId_,
        address indexed participant_,
        uint256 indexed amount_,
        uint256 timestamp_
    );

    /**
     * @dev Emitted when a Raffle is closed.
     *
     * @param raffleId_ - The identifier for this specific raffle.
     * @param requestId_ - The id for this raffle airnode request.
     * @param timestamp_ - The timestamp when the raffle was closed.
     */
    event RaffleClosed (
        uint256 indexed raffleId_,
        bytes32 requestId_,
        uint256 indexed timestamp_
    );

    /**
     * @dev Emitted when the winners are set from the QRNG provided data.
     *
     * @param raffleId_ - The identifier for this specific raffle.
     * @param raffleWinners_ - The winner address list for this raffle.
     * @param ownerCut_ - The amount of tokens to be sent to the owner.
     * @param treasuryCut_ - The amount of tokens to be sent to the treasury.
     * @param timestamp_ - The timestamp when the raffle was finished.
     */
    event RaffleFinished (
        uint256 indexed raffleId_,
        address[] raffleWinners_,
        uint256 ownerCut_,
        uint256 treasuryCut_,
        uint256 indexed timestamp_
    );

    /**
     * @dev Emitted when Distributor send native tokens.
     *
     * @param sender_ - The address of the sender.
     * @param total_ - The total amount of tokens sent.
     * @param timestamp_ - The timestamp when the distribution was done.
     */
    event NativeDistributed (
        address indexed sender_,
        uint256 indexed total_,
        uint256 timestamp_
    );

    /**
     * @dev Emitted when Distributor send ERC20 tokens.
     *
     * @param sender_ - The address of the sender.
     * @param token_ - The address of the token being distributed.
     * @param total_ - The total amount of tokens sent.
     * @param timestamp_ - The timestamp when the distribution was done.
     */
    event TokensDistributed (
        address indexed sender_,
        address indexed token_,
        uint256 indexed total_,
        uint256 timestamp_
    );

        // ========== Base Events ==========
    /**
     * @dev Emitted when we set the parameters for the airnode.
     *
     * @param airnodeAddress - The Airnode address being use.
     * @param derivedAddress - The derived address for the airnode-sponsor.
     * @param sponsorAddress - The actual sponsor wallet address.
     * @param timestamp - The timestamp when the parameters were set.
     */
    event SetRequestParameters (
        address airnodeAddress,
        address derivedAddress,
        address sponsorAddress,
        uint256 indexed timestamp
    );

    /**
     * @dev Emitted when a new Endpoint is added to an AirnodeLogic instance.
     *
     * @param _index - The current index for the recently added endpoint in the array.
     * @param _newEndpointId - The given endpointId for the addition.
     * @param _newEndpointSelector - The selector for the given endpoint of this addition.
     */
    event SetAirnodeEndpoint (
        uint256 indexed _index,
        bytes32 indexed _newEndpointId,
        string _endpointFunction,
        bytes4 _newEndpointSelector
    );

    /**
     * @dev Emitted when balance is withdraw from requester.
     *
     * @param _requester - The address of the requester contract.
     * @param _recipient - The address of the recipient.
     * @param _amount - The amount of tokens being transfered.
     */
    event Withdraw (
        address indexed _requester,
        address indexed _recipient,
        uint256 indexed _amount
    );

    // ========== Airnode Module Events ==========
    /**
     * @dev Should be emitted when a request to WinnerAirnode is done.
     *
     * @param requestId - The request id which this event is related to.
     * @param airnodeAddress - The airnode address from which this request was originated.
     */
    event NewWinnerRequest (
        bytes32 indexed requestId,
        address indexed airnodeAddress
    );

    /**
     * @dev Same as `NewRequest` but, emitted at the callback time when
     * a request is successful for flow control.
     *
     * @param requestId - The request id from which this event was emitted.
     * @param airnodeAddress - The airnode address from which this request was originated.
     */
    event SuccessfulRequest (
        bytes32 indexed requestId,
        address indexed airnodeAddress
    );

    // ========== Vault Module Events ==========
    /**
     * @dev Should be emitted when withdrawals are enabled on a vault.
     *
     * @param emitter The address of the vault owner.
     */
    event WithdrawEnabled (
        address emitter
    );
    
    /**
     * @dev Should be emitted when the balance of ERC721s is withdraw
     * from a vault.
     *
     * @param emitter The address of the vault owner.
     * @param recipient The end user to recieve the assets.
     * @param tokenContract The addresses of the assets being transfered.
     * @param tokenId The id of the token being transfered.
     */
    event WithdrawERC721 (
        address indexed emitter,
        address indexed recipient,
        address indexed tokenContract,
        uint256 tokenId
    );

    /**
     * @dev Should be emitted when the balance of ERC20s is withdraw.
     *
     * @param emitter The address of the vault.
     * @param recipient The end user to recieve the assets.
     * @param amount The amount of the token being transfered.
     */
    event WithdrawNative (
        address indexed emitter,
        address indexed recipient,
        uint256 amount
    );

    /**
     * @dev Should be emitted when router deposits native tokens to a vault.
     *
     * @param emitter The address of the sender.
     * @param recipient The address of the vault to recieve the funds.
     * @param amount The amount of the token being transfered.
     */
    event DepositNative (
        address indexed emitter,
        address indexed recipient,
        uint256 amount
    );

    /**
     * @dev Should be emitted when router deposits NFTs to a vault.
     *
     * @param emitter The address of the sender.
     * @param recipient The address of the vault to recieve the funds.
     * @param tokenAddresses The addresses of the ERC721 token(s).
     * @param tokenIds The id of the token(s) being transfered.
     */
    event DepositERC721 (
        address indexed emitter,
        address indexed recipient,
        address[] tokenAddresses,
        uint256[] tokenIds
    );

    /**
     * @dev Should be emitted when factory creates a new vault clone.
     *
     * @param vault The address of the new vault.
     * @param to The new owner of the vault.
     */
    event VaultCreated (
        address vault,
        address to
    );
}