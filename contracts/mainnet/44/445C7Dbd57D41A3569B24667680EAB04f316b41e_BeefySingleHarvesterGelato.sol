// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20Upgradeable.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized != type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initialized`
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initializing`
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
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
interface IERC20PermitUpgradeable {
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
interface IERC20Upgradeable {
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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../extensions/draft-IERC20PermitUpgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

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
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
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
        IERC20PermitUpgradeable token,
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
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSetUpgradeable {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "../../lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol";
import "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "../../lib/openzeppelin-contracts-upgradeable/contracts/utils/structs/EnumerableSetUpgradeable.sol";

abstract contract ManageableUpgradeable is Initializable, ContextUpgradeable {
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

  EnumerableSetUpgradeable.AddressSet private _managers;

  event ManagersUpdated(address[] users_, address status_);

  /* solhint-disable func-name-mixedcase */
  /**
   * @dev Initializes the contract setting the deployer as the only manager.
   */
  function __Manageable_init() internal onlyInitializing {
    /* solhint-enable func-name-mixedcase */
    __Context_init_unchained();
    __Manageable_init_unchained();
  }

  /* solhint-disable func-name-mixedcase */
  function __Manageable_init_unchained() internal onlyInitializing {
    /* solhint-enable func-name-mixedcase */
    _setManager(_msgSender(), true);
  }

  /**
   * @dev Throws if called by any account other than the manager.
   */
  modifier onlyManager() {
    require(_managers.contains(msg.sender), "!manager");
    _;
  }

  function setManagers(address[] memory managers_, bool status_) external onlyManager {
    for (uint256 managerIndex = 0; managerIndex < managers_.length; managerIndex++) {
      _setManager(managers_[managerIndex], status_);
    }
  }

  function _setManager(address manager_, bool status_) internal {
    if (status_) {
      _managers.add(manager_);
    } else {
      // Must be at least 1 manager.
      require(_managers.length() > 1, "!(managers > 1)");
      _managers.remove(manager_);
    }
  }

  uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IResolver {
  function checker(address vault_) external returns (bool canExec, bytes memory execPayload);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface ITaskTreasury {
  function addWhitelistedService(address _service) external;

  function depositFunds(
    address _receiver,
    address _token,
    uint256 _amount
  ) external payable;

  function gelato() external view returns (address);

  function getCreditTokensByUser(address _user) external view returns (address[] memory);

  function getWhitelistedServices() external view returns (address[] memory);

  function maxFee() external view returns (uint256);

  function owner() external view returns (address);

  function removeWhitelistedService(address _service) external;

  function renounceOwnership() external;

  function setMaxFee(uint256 _newMaxFee) external;

  function transferOwnership(address newOwner) external;

  function useFunds(
    address _token,
    uint256 _amount,
    address _user
  ) external;

  function userTokenBalance(address, address) external view returns (uint256);

  function withdrawFunds(
    address _receiver,
    address _token,
    uint256 _amount
  ) external;
} //interface ITaskTreasury

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import {IERC20Upgradeable} from "../../../lib/openzeppelin-contracts-upgradeable/contracts/interfaces/IERC20Upgradeable.sol";

interface IWrappedNative is IERC20Upgradeable {
  function deposit() external payable;

  function withdraw(uint256 wad) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import "../../lib/openzeppelin-contracts-upgradeable/contracts/interfaces/IERC20Upgradeable.sol";

interface IBeefyStrategy {
  function vault() external view returns (address);

  function want() external view returns (IERC20Upgradeable);

  function beforeDeposit() external;

  function deposit() external;

  function withdraw(uint256) external;

  function balanceOf() external view returns (uint256);

  function balanceOfWant() external view returns (uint256);

  function balanceOfPool() external view returns (uint256);

  function harvest(address callFeeRecipient) external;

  function retireStrat() external;

  function panic() external;

  function pause() external;

  function unpause() external;

  function paused() external view returns (bool);

  function unirouter() external view returns (address);

  function lpToken0() external view returns (address);

  function lpToken1() external view returns (address);

  function lastHarvest() external view returns (uint256);

  function callReward() external view returns (uint256);

  function rewardPool() external view returns (address);

  function harvestWithCallFeeRecipient(address callFeeRecipient) external; // back compat call
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import "../../lib/openzeppelin-contracts-upgradeable/contracts/interfaces/IERC20Upgradeable.sol";
import "./IBeefyStrategy.sol";

interface IBeefyVault is IERC20Upgradeable {
  function name() external view returns (string memory);

  function deposit(uint256) external;

  function depositAll() external;

  function withdraw(uint256) external;

  function withdrawAll() external;

  function getPricePerFullShare() external view returns (uint256);

  function upgradeStrat() external;

  function balance() external view returns (uint256);

  function symbol() external view returns (string memory);

  function want() external view returns (IERC20Upgradeable);

  function strategy() external view returns (IBeefyStrategy);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IGelatoRefunder {
  function refund() external returns (uint256 nativeRefunded_);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

library console {
  address constant CONSOLE_ADDRESS = address(0x000000000000000000636F6e736F6c652e6c6f67);

  function _sendLogPayload(bytes memory payload) private view {
    uint256 payloadLength = payload.length;
    address consoleAddress = CONSOLE_ADDRESS;
    assembly {
      let payloadStart := add(payload, 32)
      let r := staticcall(gas(), consoleAddress, payloadStart, payloadLength, 0, 0)
    }
  }

  function log() internal view {
    _sendLogPayload(abi.encodeWithSignature("log()"));
  }

  function logInt(int256 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(int)", p0));
  }

  function logUint(uint256 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
  }

  function logString(string memory p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string)", p0));
  }

  function logBool(bool p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
  }

  function logAddress(address p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address)", p0));
  }

  function logBytes(bytes memory p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
  }

  function logBytes1(bytes1 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
  }

  function logBytes2(bytes2 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
  }

  function logBytes3(bytes3 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
  }

  function logBytes4(bytes4 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
  }

  function logBytes5(bytes5 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
  }

  function logBytes6(bytes6 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
  }

  function logBytes7(bytes7 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
  }

  function logBytes8(bytes8 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
  }

  function logBytes9(bytes9 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
  }

  function logBytes10(bytes10 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
  }

  function logBytes11(bytes11 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
  }

  function logBytes12(bytes12 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
  }

  function logBytes13(bytes13 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
  }

  function logBytes14(bytes14 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
  }

  function logBytes15(bytes15 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
  }

  function logBytes16(bytes16 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
  }

  function logBytes17(bytes17 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
  }

  function logBytes18(bytes18 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
  }

  function logBytes19(bytes19 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
  }

  function logBytes20(bytes20 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
  }

  function logBytes21(bytes21 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
  }

  function logBytes22(bytes22 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
  }

  function logBytes23(bytes23 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
  }

  function logBytes24(bytes24 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
  }

  function logBytes25(bytes25 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
  }

  function logBytes26(bytes26 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
  }

  function logBytes27(bytes27 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
  }

  function logBytes28(bytes28 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
  }

  function logBytes29(bytes29 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
  }

  function logBytes30(bytes30 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
  }

  function logBytes31(bytes31 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
  }

  function logBytes32(bytes32 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
  }

  function log(uint256 p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
  }

  function log(string memory p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string)", p0));
  }

  function log(bool p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
  }

  function log(address p0) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address)", p0));
  }

  function log(uint256 p0, uint256 p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint)", p0, p1));
  }

  function log(uint256 p0, string memory p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string)", p0, p1));
  }

  function log(uint256 p0, bool p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool)", p0, p1));
  }

  function log(uint256 p0, address p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address)", p0, p1));
  }

  function log(string memory p0, uint256 p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint)", p0, p1));
  }

  function log(string memory p0, string memory p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
  }

  function log(string memory p0, bool p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
  }

  function log(string memory p0, address p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
  }

  function log(bool p0, uint256 p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint)", p0, p1));
  }

  function log(bool p0, string memory p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
  }

  function log(bool p0, bool p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
  }

  function log(bool p0, address p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
  }

  function log(address p0, uint256 p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint)", p0, p1));
  }

  function log(address p0, string memory p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
  }

  function log(address p0, bool p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
  }

  function log(address p0, address p1) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address)", p0, p1));
  }

  function log(
    uint256 p0,
    uint256 p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    uint256 p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,string)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    uint256 p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    uint256 p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,address)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    string memory p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,uint)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    string memory p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,string)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    string memory p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,bool)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    string memory p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,address)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    bool p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    bool p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,string)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    bool p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    bool p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,address)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    address p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,uint)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    address p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,string)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    address p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,bool)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    address p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,address)", p0, p1, p2));
  }

  function log(
    string memory p0,
    uint256 p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,uint)", p0, p1, p2));
  }

  function log(
    string memory p0,
    uint256 p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,string)", p0, p1, p2));
  }

  function log(
    string memory p0,
    uint256 p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,bool)", p0, p1, p2));
  }

  function log(
    string memory p0,
    uint256 p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,address)", p0, p1, p2));
  }

  function log(
    string memory p0,
    string memory p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,uint)", p0, p1, p2));
  }

  function log(
    string memory p0,
    string memory p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
  }

  function log(
    string memory p0,
    string memory p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
  }

  function log(
    string memory p0,
    string memory p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
  }

  function log(
    string memory p0,
    bool p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint)", p0, p1, p2));
  }

  function log(
    string memory p0,
    bool p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
  }

  function log(
    string memory p0,
    bool p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
  }

  function log(
    string memory p0,
    bool p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
  }

  function log(
    string memory p0,
    address p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,uint)", p0, p1, p2));
  }

  function log(
    string memory p0,
    address p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
  }

  function log(
    string memory p0,
    address p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
  }

  function log(
    string memory p0,
    address p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
  }

  function log(
    bool p0,
    uint256 p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint)", p0, p1, p2));
  }

  function log(
    bool p0,
    uint256 p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,string)", p0, p1, p2));
  }

  function log(
    bool p0,
    uint256 p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool)", p0, p1, p2));
  }

  function log(
    bool p0,
    uint256 p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,address)", p0, p1, p2));
  }

  function log(
    bool p0,
    string memory p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint)", p0, p1, p2));
  }

  function log(
    bool p0,
    string memory p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
  }

  function log(
    bool p0,
    string memory p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
  }

  function log(
    bool p0,
    string memory p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
  }

  function log(
    bool p0,
    bool p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint)", p0, p1, p2));
  }

  function log(
    bool p0,
    bool p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
  }

  function log(
    bool p0,
    bool p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
  }

  function log(
    bool p0,
    bool p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
  }

  function log(
    bool p0,
    address p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint)", p0, p1, p2));
  }

  function log(
    bool p0,
    address p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
  }

  function log(
    bool p0,
    address p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
  }

  function log(
    bool p0,
    address p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
  }

  function log(
    address p0,
    uint256 p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,uint)", p0, p1, p2));
  }

  function log(
    address p0,
    uint256 p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,string)", p0, p1, p2));
  }

  function log(
    address p0,
    uint256 p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,bool)", p0, p1, p2));
  }

  function log(
    address p0,
    uint256 p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,address)", p0, p1, p2));
  }

  function log(
    address p0,
    string memory p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,uint)", p0, p1, p2));
  }

  function log(
    address p0,
    string memory p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
  }

  function log(
    address p0,
    string memory p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
  }

  function log(
    address p0,
    string memory p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
  }

  function log(
    address p0,
    bool p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint)", p0, p1, p2));
  }

  function log(
    address p0,
    bool p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
  }

  function log(
    address p0,
    bool p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
  }

  function log(
    address p0,
    bool p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
  }

  function log(
    address p0,
    address p1,
    uint256 p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,uint)", p0, p1, p2));
  }

  function log(
    address p0,
    address p1,
    string memory p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
  }

  function log(
    address p0,
    address p1,
    bool p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
  }

  function log(
    address p0,
    address p1,
    address p2
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
  }

  function log(
    uint256 p0,
    uint256 p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    uint256 p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    uint256 p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    uint256 p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,address)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    uint256 p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    uint256 p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    uint256 p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    uint256 p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,address)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    uint256 p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    uint256 p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    uint256 p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    uint256 p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,address)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    uint256 p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    uint256 p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    uint256 p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    uint256 p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,address)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,address)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,string,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,string,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,string,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,string,address)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,address)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,address,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,address,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,address,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    string memory p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,string,address,address)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,address)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,address)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,address)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    bool p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,address)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,address)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,string,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,string,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,string,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,string,address)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,address)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,address,uint)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,address,string)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,address,bool)", p0, p1, p2, p3));
  }

  function log(
    uint256 p0,
    address p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(uint,address,address,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,string,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,string,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,string,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,string,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,address,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,address,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,address,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    uint256 p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,uint,address,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,uint,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,uint,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,string,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,address,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    string memory p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    bool p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,uint,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,uint,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,string,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,address,uint)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
  }

  function log(
    string memory p0,
    address p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    uint256 p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    string memory p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    bool p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,uint)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
  }

  function log(
    bool p0,
    address p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,string,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,string,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,string,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,string,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,address,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,address,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,address,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    uint256 p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,uint,address,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,uint,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,uint,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,string,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,address,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    string memory p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    bool p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    uint256 p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,uint,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    uint256 p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,uint,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    uint256 p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,uint,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    uint256 p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,uint,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    string memory p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,string,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    string memory p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    string memory p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    string memory p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    bool p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    bool p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    bool p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    bool p2,
    address p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    address p2,
    uint256 p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,address,uint)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    address p2,
    string memory p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    address p2,
    bool p3
  ) internal view {
    _sendLogPayload(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
  }

  function log(
    address p0,
    address p1,
    address p2,
    address p3
  ) internal view {
    _sendLogPayload(
      abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3)
    );
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

library UpkeepLibrary {
  uint256 public constant UPKEEPTX_PREMIUM_SCALING_FACTOR = 1 gwei;

  function _getCircularIndex(uint256 index_, uint256 bufferLength_)
    internal
    pure
    returns (uint256 circularIndex_)
  {
    circularIndex_ = index_ % bufferLength_;
  }

  function _calculateUpkeepTxCost(
    uint256 gasprice_,
    uint256 gasOverhead_,
    uint256 upkeepTxPremiumFactor_
  ) internal pure returns (uint256 upkeepTxCost_) {
    upkeepTxCost_ =
      (gasprice_ * gasOverhead_ * (UPKEEPTX_PREMIUM_SCALING_FACTOR + upkeepTxPremiumFactor_)) /
      UPKEEPTX_PREMIUM_SCALING_FACTOR;
  }

  function _calculateUpkeepTxCostFromTotalVaultHarvestOverhead(
    uint256 gasprice_,
    uint256 totalVaultHarvestOverhead_,
    uint256 keeperRegistryOverhead_,
    uint256 upkeepTxPremiumFactor_
  ) internal pure returns (uint256 upkeepTxCost_) {
    uint256 totalOverhead = totalVaultHarvestOverhead_ + keeperRegistryOverhead_;

    upkeepTxCost_ = _calculateUpkeepTxCost(gasprice_, totalOverhead, upkeepTxPremiumFactor_);
  }

  function _calculateProfit(uint256 revenue, uint256 expenses)
    internal
    pure
    returns (uint256 profit_)
  {
    profit_ = revenue >= expenses ? revenue - expenses : 0;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {IERC20Upgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/interfaces/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {PausableUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";

import {ManageableUpgradeable} from "../access/ManageableUpgradeable.sol";

import {IBeefyVault} from "../interfaces/IBeefyVault.sol";
import {IBeefyStrategy} from "../interfaces/IBeefyStrategy.sol";
import {IGelatoRefunder} from "../interfaces/IGelatoRefunder.sol";

import {ITaskTreasury} from "../interfaces/external/ITaskTreasury.sol";
import {IWrappedNative} from "../interfaces/external/IWrappedNative.sol";

import {UpkeepLibrary} from "../libraries/UpkeepLibrary.sol";

import {console} from "../libraries/hardhat/console.sol";

abstract contract BeefySingleHarvesterBase is ManageableUpgradeable, PausableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  uint256 public constant HARVEST_GAS_PROFITABILITY_BUFFER = 10_000;
  uint256 public constant GELATO_REGISTRY_GAS_OVERHEAD = 100_000; //Compared
  //	normal harvest to a harvest via gelato and
  //	came up with this conservative estimate.
  uint256 public constant BEEFY_HARVESTER_OVERHEAD = 34_000; //estimated from
  //	GasExperiments tests

  address public constant RECEIVER = 0x340759c8346A1E6Ed92035FB8B6ec57cE1D82c2c; //address
  //	that registers the resolver (Ops/Automate)

  IWrappedNative public constant NATIVE =
    IWrappedNative(0x4200000000000000000000000000000000000006);
  ITaskTreasury public constant TASK_TREASURY =
    ITaskTreasury(0xB3f5503f93d5Ef84b06993a1975B9D21B962892F);

  bool public revertWhenUnprofitable;
  uint256 public premium; //AT: Spell out purpose. Is chain-specific?
  uint256 public maxGasPrice; //gwei (e9), chain-specific deployment default
  uint256 public depositFundsThreshold; //eth (e18), chain-specific deployment
  //	default
  IGelatoRefunder public gelatoRefunder;

  event HarvestSummary(
    uint256 indexed blockNumber,
    address indexed vault,
    uint256 checkUpkeepGasPrice,
    uint256 gasPrice,
    uint256 gasUsedByPerformUpkeep,
    uint256 estimatedTxCost,
    uint256 estimatedCallRewards,
    uint256 estimatedProfit,
    bool isDailyHarvest,
    uint256 calculatedTxCost,
    uint256 calculatedCallRewards,
    uint256 calculatedProfit
  );

  /*             */
  /* checkUpkeep */
  /*             */
  function checkUpkeep(uint256 gasPrice_, IBeefyVault vault_)
    public
    returns (
      bool willHarvestVault_,
      uint256 estimatedTxCost_,
      uint256 estimatedCallRewards_,
      uint256 estimatedProfit_,
      bool isDailyHarvest_
    )
  {
    //this should only be
    //	true when estimatedProfit_ is 0
    (
      willHarvestVault_,
      estimatedTxCost_,
      estimatedCallRewards_,
      isDailyHarvest_
    ) = _willHarvestVault(gasPrice_, vault_);
    estimatedProfit_ = UpkeepLibrary._calculateProfit(estimatedCallRewards_, estimatedTxCost_);

    require(!(isDailyHarvest_ && gasPrice_ > maxGasPrice), "tx.gasprice too high.");
  } //function checkUpkeep(

  function _willHarvestVault(uint256 gasPrice_, IBeefyVault vault_)
    internal
    returns (
      bool willHarvestVault_,
      uint256 estimatedTxCost_,
      uint256 callReward_,
      bool isDailyHarvest_
    )
  {
    (
      bool canHarvestVault,
      uint256 callReward,
      uint256 gasOverhead,
      uint256 lastHarvest
    ) = _canHarvestVault(vault_);
    console.log("canHarvestVault", canHarvestVault);

    (bool shouldHarvestVault, uint256 estimatedTxCost, bool isDailyHarvest) = _shouldHarvestVault(
      gasPrice_,
      callReward,
      gasOverhead,
      lastHarvest
    );

    willHarvestVault_ = canHarvestVault && shouldHarvestVault;
    estimatedTxCost_ = estimatedTxCost;
    callReward_ = callReward;
    isDailyHarvest_ = isDailyHarvest;
  } //function _willHarvestVault(

  //virtual for etch in testing
  function _canHarvestVault(IBeefyVault vault_)
    internal
    virtual
    returns (
      bool canHarvest_,
      uint256 callReward_,
      uint256 harvestGasOverhead_,
      uint256 lastHarvest_
    )
  {
    IBeefyStrategy strategy = vault_.strategy();

    //Make sure strategy isn't paused
    bool isPaused = strategy.paused();

    //Get lastHarvest before the harvest simulation, as the harvest simulation
    //	will overwrite lastHarvest
    lastHarvest_ = strategy.lastHarvest();

    (bool didHarvest, uint256 callReward, uint256 harvestGasOverhead) = _harvestVault(vault_);

    canHarvest_ = !isPaused && didHarvest;
    callReward_ = callReward;
    harvestGasOverhead_ = harvestGasOverhead;
  } //function _canHarvestVault(

  function _shouldHarvestVault(
    uint256 gasPrice_,
    uint256 callReward_,
    uint256 harvestGasOverhead_,
    uint256 lastHarvest_
  )
    internal
    view
    returns (
      bool shouldHarvestVault_,
      uint256 txCostWithPremium_,
      bool isDailyHarvest_
    )
  {
    /* solhint-disable not-rely-on-time */
    uint256 oneDayAgo = block.timestamp - 1 days;
    /* solhint-enable not-rely-on-time */
    bool hasBeenHarvestedToday = lastHarvest_ > oneDayAgo;

    console.log("oneDayAgo", oneDayAgo);
    /* solhint-disable not-rely-on-time */
    console.log("now", block.timestamp);
    /* solhint-enable not-rely-on-time */
    console.log("1day", 1 days);

    console.log("lastHarvest", lastHarvest_);
    console.log("hasBeenHarvestedToday", hasBeenHarvestedToday);

    uint256 vaultHarvestGasOverhead = _estimateSingleVaultHarvestGasOverhead(harvestGasOverhead_);
    txCostWithPremium_ = _calculateTxCostWithPremium(vaultHarvestGasOverhead, gasPrice_);
    uint256 harvestThreshold = txCostWithPremium_ + HARVEST_GAS_PROFITABILITY_BUFFER;
    bool isProfitableHarvest = callReward_ >= harvestThreshold;
    isDailyHarvest_ = !hasBeenHarvestedToday && callReward_ > 0 && !isProfitableHarvest;

    console.log("vaultHarvestGasOverhead", vaultHarvestGasOverhead);
    console.log("txCostWithPremium_", txCostWithPremium_);
    console.log("harvestThreshold", harvestThreshold);
    console.log("callReward_", callReward_);
    console.log("isProfitableHarvest", isProfitableHarvest);
    console.log("isDailyHarvest_", isDailyHarvest_);

    shouldHarvestVault_ = isProfitableHarvest || isDailyHarvest_;

    console.log("shouldHarvestVault_", shouldHarvestVault_);
  } //function _shouldHarvestVault(

  /*               */
  /* performUpkeep */
  /*               */
  function _performUpkeep(
    IBeefyVault vault_,
    uint256 checkUpkeepGasPrice_,
    uint256 estimatedTxCost_,
    uint256 estimatedCallRewards_,
    uint256 estimatedProfit_,
    bool isDailyHarvest_
  ) internal whenNotPaused {
    require(!(isDailyHarvest_ && tx.gasprice > maxGasPrice), "tx.gasprice too high");

    /* solhint-disable not-rely-on-time */
    require(
      !(vault_.strategy().lastHarvest() > block.timestamp - 1 days) == isDailyHarvest_,
      "Racing keepers detected"
    );
    /* solhint-enable not-rely-on-time */

    uint256 gasBefore = gasleft();

    (bool didHarvest, uint256 calculatedCallRewards, ) = _harvestVault(vault_);
    require(didHarvest, "Vault wasn't harvestable");

    uint256 gasAfter = gasleft();

    uint256 nativeBalance = NATIVE.balanceOf(address(this));
    if (nativeBalance > depositFundsThreshold) {
      NATIVE.transfer(address(gelatoRefunder), nativeBalance);
      uint256 refunded = gelatoRefunder.refund();
      console.log("Refunded", refunded);
    }

    uint256 gasUsedByPerformUpkeep = gasBefore - gasAfter;

    _reportHarvestSummary(
      vault_,
      checkUpkeepGasPrice_,
      gasUsedByPerformUpkeep,
      estimatedTxCost_,
      estimatedCallRewards_,
      estimatedProfit_,
      isDailyHarvest_,
      calculatedCallRewards
    );
  } //function _performUpkeep(

  function _reportHarvestSummary(
    IBeefyVault vault_,
    uint256 checkUpkeepGasPrice_,
    uint256 gasUsedByPerformUpkeep_,
    uint256 estimatedTxCost_,
    uint256 estimatedCallRewards_,
    uint256 estimatedProfit_,
    bool isDailyHarvest_,
    uint256 calculatedCallRewards_
  ) internal {
    //Calculate onchain profit
    uint256 calculatedTxCost = _calculateTxCostWithOverheadWithPremium(
      gasUsedByPerformUpkeep_,
      tx.gasprice
    );
    uint256 calculatedProfit = UpkeepLibrary._calculateProfit(
      calculatedCallRewards_,
      calculatedTxCost
    );

    //revert if not profitable and not a daily harvest
    require(!revertWhenUnprofitable || isDailyHarvest_ || calculatedProfit > 0, "Not profitable");

    emit HarvestSummary(
      block.number,
      address(vault_),
      // gas metrics
      checkUpkeepGasPrice_,
      tx.gasprice,
      gasUsedByPerformUpkeep_,
      // harvest metrics
      estimatedTxCost_,
      estimatedCallRewards_,
      estimatedProfit_,
      isDailyHarvest_,
      calculatedTxCost,
      calculatedCallRewards_,
      calculatedProfit
    );
  } //function _reportHarvestSummary(

  function _harvestVault(IBeefyVault vault_)
    internal
    returns (
      bool didHarvest_,
      uint256 callReward_,
      uint256 harvestGasOverhead_
    )
  {
    IBeefyStrategy strategy = vault_.strategy();
    address callFeeRecipient = address(this);
    uint256 gasBefore = gasleft();
    uint256 beforeBalance = NATIVE.balanceOf(address(this));
    try strategy.harvest(callFeeRecipient) {
      harvestGasOverhead_ = gasBefore - gasleft();
      didHarvest_ = true;
      /* solhint-disable no-empty-blocks */
    } catch Error(string memory reason) {
      console.log("Harvest Error", reason);
    } catch Panic(uint256 errorCode) {
      console.log("Harvest Panicked", errorCode);
    } catch (bytes memory) {
      console.log("Harvest last catch");
    }

    if (!didHarvest_) {
      // try old function signature
      gasBefore = gasleft();
      try strategy.harvestWithCallFeeRecipient(callFeeRecipient) {
        harvestGasOverhead_ = gasBefore - gasleft();
        didHarvest_ = true;
        /* solhint-disable no-empty-blocks */
      } catch Error(string memory reason) {
        console.log("Harvest old Error", reason);
      } catch Panic(uint256 errorCode) {
        console.log("Harvest old Panicked", errorCode);
      } catch (bytes memory) {
        console.log("Harvest old last catch");
      }
    } //if (!didHarvest_)
    uint256 afterBalance = NATIVE.balanceOf(address(this));
    callReward_ = afterBalance - beforeBalance;
  } //function _harvestVault(

  /*     */
  /* Set */
  /*     */
  function togglePaused() external onlyManager {
    paused() ? _unpause() : _pause();
  }

  function setRevertWhenUnprofitable(bool revertWhenUnprofitable_) external onlyManager {
    revertWhenUnprofitable = revertWhenUnprofitable_;
  }

  function setPremium(uint256 premium_) external onlyManager {
    premium = premium_;
  }

  function setMaxGasPrice(uint256 gasPrice_) external onlyManager {
    maxGasPrice = gasPrice_;
  }

  function setDepositFundsThreshold(uint256 depositFundsThreshold_) external onlyManager {
    depositFundsThreshold = depositFundsThreshold_;
  }

  function setGelatoRefunder(IGelatoRefunder refunder_) external onlyManager {
    gelatoRefunder = refunder_;
  }

  /*      */
  /* View */
  /*      */
  function getUpkeepTxPremiumFactor() public view virtual returns (uint256 upkeepTxPremiumFactor_) {
    return premium;
  }

  function _calculateTxCostWithPremium(uint256 gasOverhead_, uint256 gasPrice_)
    internal
    view
    returns (uint256 txCost_)
  {
    return
      UpkeepLibrary._calculateUpkeepTxCost(gasPrice_, gasOverhead_, getUpkeepTxPremiumFactor());
  }

  function _calculateTxCostWithOverheadWithPremium(
    uint256 totalVaultHarvestOverhead_,
    uint256 gasPrice_
  ) internal view returns (uint256 txCost_) {
    return
      UpkeepLibrary._calculateUpkeepTxCostFromTotalVaultHarvestOverhead(
        gasPrice_,
        totalVaultHarvestOverhead_,
        _getThirdPartyUpstreamContractGasOverhead(),
        getUpkeepTxPremiumFactor()
      );
  }

  function _getThirdPartyUpstreamContractGasOverhead()
    internal
    pure
    returns (uint256 gasOverhead_)
  {
    gasOverhead_ = GELATO_REGISTRY_GAS_OVERHEAD;
  }

  function _estimateSingleVaultHarvestGasOverhead(uint256 vaultHarvestFunctionGasOverhead_)
    internal
    pure
    returns (uint256 totalGasOverhead_)
  {
    totalGasOverhead_ =
      vaultHarvestFunctionGasOverhead_ +
      BEEFY_HARVESTER_OVERHEAD +
      _getThirdPartyUpstreamContractGasOverhead();
  }

  /*      */
  /* Misc */
  /*      */
  function withdrawToken(address token_) external onlyManager {
    IERC20Upgradeable token = IERC20Upgradeable(token_);

    uint256 amount = token.balanceOf(address(this));
    token.safeTransfer(msg.sender, amount);
  }
} //abstract contract BeefySingleHarvesterBase is

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {IBeefyVault} from "../interfaces/IBeefyVault.sol";
import {IResolver} from "../interfaces/external/IResolver.sol";

import {BeefySingleHarvesterBase} from "./BeefySingleHarvesterBase.sol";

contract BeefySingleHarvesterGelato is BeefySingleHarvesterBase, IResolver {
  /*             */
  /* Initializer */
  /*             */
  function initialize() external initializer {
    __Manageable_init();

    premium = 70_000;
    maxGasPrice = 2_000_000;
    depositFundsThreshold = 20_000_000_000_000_000;
  }

  function checker(address vault_)
    external
    override
    returns (bool canExec_, bytes memory execPayload_)
  {
    (
      bool willHarvestVault,
      uint256 estimatedTxCost,
      uint256 estimatedCallRewards,
      uint256 estimatedProfit,
      bool isDailyHarvest
    ) = checkUpkeep(tx.gasprice, IBeefyVault(vault_));

    if (!willHarvestVault) {
      execPayload_ = bytes("Vault not harvestable");
    } else {
      canExec_ = true;
      execPayload_ = abi.encodeWithSelector(
        this.performUpkeep.selector,
        vault_,
        tx.gasprice,
        estimatedTxCost,
        estimatedCallRewards,
        estimatedProfit,
        isDailyHarvest
      );
    }
  } //function checker( address vault_)

  function performUpkeep(
    address vault_,
    uint256 checkerGasprice_,
    uint256 estimatedTxCost_,
    uint256 estimatedCallRewards_,
    uint256 estimatedProfit_,
    bool isDailyHarvest_
  ) external {
    _performUpkeep(
      IBeefyVault(vault_),
      checkerGasprice_,
      estimatedTxCost_,
      estimatedCallRewards_,
      estimatedProfit_,
      isDailyHarvest_
    );
  }
} //contract BeefySingleHarvesterGelato is