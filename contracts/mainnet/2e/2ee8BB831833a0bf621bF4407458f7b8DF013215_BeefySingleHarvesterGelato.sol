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
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
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
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
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
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
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
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
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
 *  Trying to delete such a structure from storage will likely result in data corruption, rendering the structure unusable.
 *  See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 *  In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an array of EnumerableSet.
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
        return _values(set._inner);
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
     * @dev Returns the number of values on the set. O(1).
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
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
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
            require(denominator > prod1, "Math: mulDiv overflow");

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
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
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
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
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
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
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
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";
import "./math/SignedMath.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toString(int256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(SignedMath.abs(value))));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

pragma solidity >=0.4.0 < 0.9.0;


/**
 * @title RLPEncode
 * @dev A simple RLP encoding library.
 * @author Bakaoh
 */
library RLPEncode {
    /*
     * Internal functions
     */

    /**
     * @dev RLP encodes a byte string.
     * @param self The byte string to encode.
     * @return The RLP encoded string in bytes.
     */
    function encodeBytes(bytes memory self) internal pure returns (bytes memory) {
        bytes memory encoded;
        if (self.length == 1 && uint8(self[0]) < 128) {
            encoded = self;
        } else {
            encoded = concat(encodeLength(self.length, 128), self);
        }
        return encoded;
    }

    /**
     * @dev RLP encodes a list of RLP encoded byte byte strings.
     * @param self The list of RLP encoded byte strings.
     * @return The RLP encoded list of items in bytes.
     */
    function encodeList(bytes[] memory self) internal pure returns (bytes memory) {
        bytes memory list = flatten(self);
        return concat(encodeLength(list.length, 192), list);
    }

    /**
     * @dev RLP encodes a string.
     * @param self The string to encode.
     * @return The RLP encoded string in bytes.
     */
    function encodeString(string memory self) internal pure returns (bytes memory) {
        return encodeBytes(bytes(self));
    }

    /** 
     * @dev RLP encodes an address.
     * @param self The address to encode.
     * @return The RLP encoded address in bytes.
     */
    function encodeAddress(address self) internal pure returns (bytes memory) {
        bytes memory inputBytes;
        assembly {
            let m := mload(0x40)
            mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, self))
            mstore(0x40, add(m, 52))
            inputBytes := m
        }
        return encodeBytes(inputBytes);
    }

    /** 
     * @dev RLP encodes a uint.
     * @param self The uint to encode.
     * @return The RLP encoded uint in bytes.
     */
    function encodeUint(uint self) internal pure returns (bytes memory) {
        return encodeBytes(toBinary(self));
    }

    /** 
     * @dev RLP encodes an int.
     * @param self The int to encode.
     * @return The RLP encoded int in bytes.
     */
    function encodeInt(int self) internal pure returns (bytes memory) {
        return encodeUint(uint(self));
    }

    /** 
     * @dev RLP encodes a bool.
     * @param self The bool to encode.
     * @return The RLP encoded bool in bytes.
     */
    function encodeBool(bool self) internal pure returns (bytes memory) {
        bytes memory encoded = new bytes(1);
        encoded[0] = (self ? bytes1(0x01) : bytes1(0x80));
        return encoded;
    }


    /*
     * Private functions
     */

    /**
     * @dev Encode the first byte, followed by the `len` in binary form if `length` is more than 55.
     * @param len The length of the string or the payload.
     * @param offset 128 if item is string, 192 if item is list.
     * @return RLP encoded bytes.
     */
    function encodeLength(uint len, uint offset) private pure returns (bytes memory) {
        bytes memory encoded;
        if (len < 56) {
            encoded = new bytes(1);
            encoded[0] = bytes32(len + offset)[31];
        } else {
            uint lenLen;
            uint i = 1;
            while (len / i != 0) {
                lenLen++;
                i *= 256;
            }

            encoded = new bytes(lenLen + 1);
            encoded[0] = bytes32(lenLen + offset + 55)[31];
            for(i = 1; i <= lenLen; i++) {
                encoded[i] = bytes32((len / (256**(lenLen-i))) % 256)[31];
            }
        }
        return encoded;
    }

    /**
     * @dev Encode integer in big endian binary form with no leading zeroes.
     * @notice TODO: This should be optimized with assembly to save gas costs.
     * @param _x The integer to encode.
     * @return RLP encoded bytes.
     */
    function toBinary(uint _x) private pure returns (bytes memory) {
        bytes memory b = new bytes(32);
        assembly { 
            mstore(add(b, 32), _x) 
        }
        uint i;
        for (i = 0; i < 32; i++) {
            if (b[i] != 0) {
                break;
            }
        }
        bytes memory res = new bytes(32 - i);
        for (uint j = 0; j < res.length; j++) {
            res[j] = b[i++];
        }
        return res;
    }

    /**
     * @dev Copies a piece of memory to another location.
     * @notice From: https://github.com/Arachnid/solidity-stringutils/blob/master/src/strings.sol.
     * @param _dest Destination location.
     * @param _src Source location.
     * @param _len Length of memory to copy.
     */
    function memcpy(uint _dest, uint _src, uint _len) private pure {
        uint dest = _dest;
        uint src = _src;
        uint len = _len;

        for(; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        uint mask = 256 ** (32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    /**
     * @dev Flattens a list of byte strings into one byte string.
     * @notice From: https://github.com/sammayo/solidity-rlp-encoder/blob/master/RLPEncode.sol.
     * @param _list List of byte strings to flatten.
     * @return The flattened byte string.
     */
    function flatten(bytes[] memory _list) private pure returns (bytes memory) {
        if (_list.length == 0) {
            return new bytes(0);
        }

        uint len;
        uint i;
        for (i = 0; i < _list.length; i++) {
						require(_list[i].length > 0, "An item in the list to be RLP encoded is null.");
            len += _list[i].length;
        }

        bytes memory flattened = new bytes(len);
        uint flattenedPtr;
        assembly { flattenedPtr := add(flattened, 0x20) }

        for(i = 0; i < _list.length; i++) {
            bytes memory item = _list[i];
            
            uint listPtr;
            assembly { listPtr := add(item, 0x20)}

            memcpy(flattenedPtr, listPtr, item.length);
            flattenedPtr += _list[i].length;
        }

        return flattened;
    }

    /**
     * @dev Concatenates two bytes.
     * @notice From: https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol.
     * @param _preBytes First byte string.
     * @param _postBytes Second byte string.
     * @return Both byte string combined.
     */
    function concat(bytes memory _preBytes, bytes memory _postBytes) private pure returns (bytes memory) {
        bytes memory tempBytes;

        assembly {
            tempBytes := mload(0x40)

            let length := mload(_preBytes)
            mstore(tempBytes, length)

            let mc := add(tempBytes, 0x20)
            let end := add(mc, length)

            for {
                let cc := add(_preBytes, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

            length := mload(_postBytes)
            mstore(tempBytes, add(length, mload(tempBytes)))

            mc := end
            end := add(mc, length)

            for {
                let cc := add(_postBytes, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

            mstore(0x40, and(
              add(add(end, iszero(add(length, mload(_preBytes)))), 31),
              not(31)
            ))
        }

        return tempBytes;
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

interface IGelatoExec {
  function exec(
    address _service,
    bytes calldata _data,
    address _creditToken
  )
    external
    returns (
      uint256 credit,
      uint256 gasDebitInNativeToken,
      uint256 gasDebitInCreditToken,
      uint256 estimatedGasUsed
    );
} //interface IGelatoExec

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

enum Module {
  RESOLVER,
  TIME,
  PROXY,
  SINGLE_EXEC
}
struct ModuleData {
  Module[] modules;
  bytes[] args;
}

interface IGelatoOps {
  function cancelTask(bytes32 _taskId) external;

  function createTask(
    address _execAddress,
    bytes memory _execDataOrSelector,
    ModuleData calldata _moduleData,
    address _feeToken
  ) external returns (bytes32 taskId);

  function exec(
    address _taskCreator,
    address _execAddress,
    bytes memory _execData,
    ModuleData calldata _moduleData,
    uint256 _txFee,
    address _feeToken,
    bool _useTaskTreasuryFunds,
    bool _revertOnFailure
  ) external;

  function execAddresses(bytes32) external view returns (address);

  function fee() external view returns (uint256);

  function feeToken() external view returns (address);

  function gelato() external view returns (address);

  function getFeeDetails() external view returns (uint256, address);

  function getTaskId(
    address taskCreator,
    address execAddress,
    bytes4 execSelector,
    ModuleData memory moduleData,
    address feeToken
  ) external pure returns (bytes32 taskId);

  function getTaskId(
    address taskCreator,
    address execAddress,
    bytes4 execSelector,
    bool useTaskTreasuryFunds,
    address feeToken,
    bytes32 resolverHash
  ) external pure returns (bytes32 taskId);

  function getTaskIdsByUser(address _taskCreator) external view returns (bytes32[] memory);

  function setModule(Module[] calldata _modules, address[] calldata _moduleAddresses) external;

  function taskCreator(bytes32) external view returns (address);

  function taskModuleAddresses(uint8) external view returns (address);

  function taskTreasury() external view returns (address);

  function timedTask(bytes32) external view returns (uint128 nextExec, uint128 interval);

  function version() external view returns (string memory);

  //legacy...

  function createTask(
    address _execAddress,
    bytes4 _execSelector,
    address _resolverAddress,
    bytes memory _resolverData
  ) external returns (bytes32 task);

  function createTaskNoPrepayment(
    address _execAddress,
    bytes4 _execSelector,
    address _resolverAddress,
    bytes memory _resolverData,
    address _feeToken
  ) external returns (bytes32 task);

  function createTimedTask(
    uint128 _startTime,
    uint128 _interval,
    address _execAddress,
    bytes4 _execSelector,
    address _resolverAddress,
    bytes memory _resolverData,
    address _feeToken,
    bool _useTreasury
  ) external returns (bytes32 task);

  /*  function exec(									//remmed for expediency
        uint256 _txFee,
        address _feeToken,
        address _taskCreator,
        bool _useTaskTreasuryFunds,
        bool _revertOnFailure,
        bytes32 _resolverHash,
        address _execAddress,
        bytes memory _execData
    ) external;
*/
  function getResolverHash(address _resolverAddress, bytes memory _resolverData)
    external
    pure
    returns (bytes32);

  function getSelector(string memory _func) external pure returns (bytes4);
} //interface IGelatoOps

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IResolver {
  function depositFundsThreshold()
    external
    view
    returns (
      //move this one to an IBeefyResolver
      uint256
    );

  function checker(address vault_) external returns (bool canExec, bytes memory execPayload);

  function performUpkeep(
    address vault_,
    uint256 checkerGasprice_,
    uint256 estimatedTxCost_,
    uint256 estimatedCallRewards_,
    uint256 estimatedProfit_,
    bool isDailyHarvest_
  ) external;
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

library UpkeepLibrary {
  uint256 public constant UPKEEPTX_PREMIUM_SCALE = 1 gwei;

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
      (gasprice_ * gasOverhead_ * (UPKEEPTX_PREMIUM_SCALE + upkeepTxPremiumFactor_)) /
      UPKEEPTX_PREMIUM_SCALE;
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
} //library UpkeepLibrary

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {IERC20Upgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/interfaces/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {PausableUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
import {Strings} from "../../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {RLPEncode} from "../../lib/solidity-rlp-encode/contracts/RLPEncode.sol";
//			import {console} from "../libraries/hardhat/console.sol";

import {ManageableUpgradeable} from "../access/ManageableUpgradeable.sol";
import {UpkeepLibrary} from "../libraries/UpkeepLibrary.sol";

import {IBeefyVault} from "../interfaces/IBeefyVault.sol";
import {IBeefyStrategy} from "../interfaces/IBeefyStrategy.sol";
import {ITaskTreasury} from "../interfaces/external/ITaskTreasury.sol";

import {IWrappedNative} from "../interfaces/external/IWrappedNative.sol";
import {IGelatoExec} from "../interfaces/external/IGelatoExec.sol";
import {IGelatoOps, ModuleData, Module} from "../interfaces/external/IGelatoOps.sol";
import {IResolver} from "../interfaces/external/IResolver.sol";

interface OVM_GasPriceOracle {
  function getL1Fee(bytes memory _data) external view returns (uint256);
}

abstract contract BeefySingleHarvesterBase is ManageableUpgradeable, PausableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  uint256 internal constant HARVEST_GAS_PROFITABILITY_BUFFER = 10_000;
  uint256 internal constant GELATO_REGISTRY_GAS_OVERHEAD = 0; //irrelevant on
  //	Optimism where *calldata* rules cost
  uint256 internal constant BEEFY_HARVESTER_OVERHEAD = 5_500; //observed
  //	estimate
  address internal constant RECEIVER = 0x96e9886A56726873CDC6Fc20FCDf806722F408d2; //Beefy
  //	EOA that funds Gelato Automate
  address internal constant GAS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; //address
  //	Gelato uses for native
  ITaskTreasury internal constant TASK_TREASURY =
    ITaskTreasury(0xB3f5503f93d5Ef84b06993a1975B9D21B962892F); //Proxy
  //	of Gelato's "TaskTreasury" contract,
  //	where Beefy's account is funded
  address internal constant GELATO_OPERATIONS = 0x340759c8346A1E6Ed92035FB8B6ec57cE1D82c2c; //Proxy of
  //	Gelato's "Ops" contract
  IWrappedNative internal constant WNATIVE =
    IWrappedNative(0x4200000000000000000000000000000000000006);
  OVM_GasPriceOracle internal constant OPTIMISM_GAS_ORACLE =
    OVM_GasPriceOracle(0x420000000000000000000000000000000000000F);

  bool public revertWhenUnprofitable;
  uint256 public premium; //gwei (e9), for future flexibility if fee
  //	structure changes
  uint256 public maxGasPrice; //gwei (e9), chain-specific
  uint256 public depositFundsThreshold; //eth (e18), chain-specific
  /// @custom:oz-renamed-from gelatoRefunder
  address private slot_blankAddress; //preserves slot layout in upgraded logic
  //	(implementation) contract

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

  struct CheckerContext {
    bool harvest;
    bool daily;
    address vault;
    uint256 overhead; //estimates from here down
    uint256 reward;
    uint256 cost;
    uint256 costL1;
  }

  function checkUpkeep(uint256 gasPrice, IBeefyVault vault)
    public
    returns (CheckerContext memory context_)
  {
    //					console.log( "tx.origin %s with %s wei in tank", tx.origin,
    //									~uint( 0) != tx.origin.balance ? tx.origin.balance : 0);

    context_ = _willHarvestVault(gasPrice, vault);
    //						console.log( "willHarvest", context_.harvest);
    //						console.log( "upkeepOverhead", context_.overhead);
    //						console.log( "txCostWithPremium", context_.cost);
    //						console.log( "callReward", context_.reward);
    //						console.log( "isDailyHarvest", context_.daily);
    //						console.log( "estimatedProfit", context_.reward > context_.cost ?
    //																				context_.reward - context_.cost : 0);

    require(!(context_.daily && gasPrice > maxGasPrice), "tx.gasprice too high.");
  } //function checkUpkeep(

  function _willHarvestVault(uint256 gasPrice, IBeefyVault vault)
    internal
    returns (CheckerContext memory context_)
  {
    uint256 lastHarvest;
    (lastHarvest, context_) = _canHarvestVault(vault);
    //						console.log( "lastHarvest:", lastHarvest);

    if (context_.harvest) {
      context_.overhead = _estimateSingleVaultHarvestGasOverhead(context_.overhead);
      bool shouldHarvest = _shouldHarvestVault(gasPrice, lastHarvest, context_);

      context_.harvest = context_.harvest && shouldHarvest;
    }
  } //function _willHarvestVault(

  //virtual for etch in testing
  function _canHarvestVault(IBeefyVault vault)
    internal
    virtual
    returns (uint256 lastHarvest_, CheckerContext memory context_)
  {
    IBeefyStrategy strategy = vault.strategy();
    bool isPaused = strategy.paused();

    //get lastHarvest now before the harvest simulation, as the harvest
    //	simulation will overwrite it
    lastHarvest_ = strategy.lastHarvest();

    context_ = _harvestVault(vault);

    context_.harvest = context_.harvest && !isPaused;
  } //function _canHarvestVault(

  function _shouldHarvestVault(
    uint256 gasPrice,
    uint256 lastHarvest,
    CheckerContext memory context
  ) internal view returns (bool shouldHarvest_) {
    /* solhint-disable not-rely-on-time */
    bool hasBeenHarvestedToday = lastHarvest > block.timestamp - 1 days;
    /* solhint-enable not-rely-on-time */

    _costTransaction(gasPrice, context);
    bool isProfitableHarvest = context.reward >= context.cost + HARVEST_GAS_PROFITABILITY_BUFFER;
    context.daily = !hasBeenHarvestedToday && context.reward > 0 && !isProfitableHarvest;

    shouldHarvest_ = isProfitableHarvest || context.daily;
  } //function _shouldHarvestVault(

  /*               */
  /* performUpkeep */
  /*               */
  function _performUpkeep(
    IBeefyVault vault,
    uint256 checkUpkeepGasPrice,
    uint256 estimatedTxCost,
    uint256 reward,
    uint256, /* estimatedProfit */
    bool isDailyHarvest
  ) internal whenNotPaused {
    require(!(isDailyHarvest && tx.gasprice > maxGasPrice), "tx.gasprice too high");

    uint32 lastHarvest;
    /* solhint-disable not-rely-on-time */
    require(
      !isDailyHarvest ||
        (lastHarvest = uint32(vault.strategy().lastHarvest())) < block.timestamp - 1 days,
      string(
        abi.encodePacked(
          "Racing keepers detected. ",
          Strings.toString(block.timestamp),
          " vs lastHarvest ",
          Strings.toString(lastHarvest),
          "."
        )
      )
    );
    /* solhint-enable not-rely-on-time */

    uint256 gasBefore = gasleft();

    CheckerContext memory context = _harvestVault(vault);
    require(context.harvest, "Vault failed to actually harvest");

    uint256 gasAfter = gasleft();
    context.cost = estimatedTxCost;
    uint256 temp = context.reward;
    context.reward = reward;
    reward = temp;
    context.daily = isDailyHarvest;

    uint256 balance = WNATIVE.balanceOf(address(this));
    if (balance > depositFundsThreshold) {
      WNATIVE.withdraw(balance);
      uint256 amount = address(this).balance;
      TASK_TREASURY.depositFunds{value: amount}(RECEIVER, GAS, amount);
    }

    _reportHarvestSummary(vault, checkUpkeepGasPrice, gasBefore - gasAfter, reward, context);
  } //function _performUpkeep(

  function _reportHarvestSummary(
    IBeefyVault vault,
    uint256 checkUpkeepGasPrice,
    uint256 overheadActual,
    uint256 rewardActual,
    CheckerContext memory context
  ) internal {
    //Calculate onchain profit
    uint256 costCalculatedActual = _txCostWithOverheadWithPremium(
      overheadActual,
      tx.gasprice,
      context
    );
    uint256 profitActual = UpkeepLibrary._calculateProfit(rewardActual, costCalculatedActual);

    //revert if not profitable and not a daily harvest
    require(
      !revertWhenUnprofitable || context.daily || profitActual > 0,
      "Actual harvest Not profitable"
    );

    emit HarvestSummary(
      block.number,
      address(vault),
      // gas metrics
      checkUpkeepGasPrice,
      costCalculatedActual / overheadActual,
      overheadActual,
      // harvest metrics
      context.cost,
      context.reward,
      context.reward > context.cost ? context.reward - context.cost : 0,
      context.daily,
      costCalculatedActual,
      rewardActual,
      profitActual
    );
  } //function _reportHarvestSummary(

  function _harvestVault(IBeefyVault vault) internal returns (CheckerContext memory context_) {
    context_.vault = address(vault);

    IBeefyStrategy strategy = vault.strategy();
    address callFeeRecipient = address(this);
    uint256 beforeBalance = WNATIVE.balanceOf(address(this));
    uint256 gasBefore = gasleft();

    try strategy.harvest(callFeeRecipient) {
      context_.overhead = gasBefore - gasleft();
      context_.harvest = true;
    } catch Error(
      string memory /* reason */
    ) {
      //						console.log( "Harvest Error", reason);
    } catch Panic(
      uint256 /* errorCode */
    ) {
      //						console.log( "Harvest Panicked", errorCode);
    } catch (bytes memory) {
      //						console.log( "Harvest last catch");
    }

    //if default harvest failed, try the old-style call
    if (!context_.harvest) {
      gasBefore = gasleft();
      try strategy.harvestWithCallFeeRecipient(callFeeRecipient) {
        context_.overhead = gasBefore - gasleft();
        context_.harvest = true;
      } catch Error(
        string memory /* reason */
      ) {
        //							console.log( "Harvest old Error", reason);
      } catch Panic(
        uint256 /* errorCode */
      ) {
        //							console.log( "Harvest old Panicked", errorCode);
      } catch (bytes memory) {
        //							console.log( "Harvest old last catch");
      }
    } //if (!didHarvest_)

    if (context_.harvest) {
      uint256 afterBalance = WNATIVE.balanceOf(address(this));
      context_.reward = afterBalance - beforeBalance;
    }
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

  /*      */
  /* View */
  /*      */
  function getUpkeepTxPremiumFactor() public view virtual returns (uint256) {
    return premium;
  }

  function _costTransaction(uint256 gasPrice, CheckerContext memory context) internal view {
    context.cost = UpkeepLibrary._calculateUpkeepTxCost(
      gasPrice,
      context.overhead,
      getUpkeepTxPremiumFactor()
    );
    if (0 == context.costL1) _calculateL1cost(gasPrice, context);
    context.cost += context.costL1;
  }

  function _calculateL1cost(uint256 gasPrice, CheckerContext memory context)
    internal
    view
    returns (uint256)
  {
    bytes[] memory rlpTransaction = new bytes[](9);
    rlpTransaction[0] = RLPEncode.encodeBytes(hex"9999"); //dummy nonce
    rlpTransaction[1] = RLPEncode.encodeUint(gasPrice);
    rlpTransaction[2] = RLPEncode.encodeUint(
      (context.overhead * 6) / 5 //gas limit
    );
    rlpTransaction[3] = RLPEncode.encodeAddress(GELATO_OPERATIONS); //destination
    rlpTransaction[4] = rlpTransaction[7] = RLPEncode.encodeUint(0); //value & v
    rlpTransaction[6] = RLPEncode.encodeUint(10); //chain id
    rlpTransaction[8] = RLPEncode.encodeUint(~uint256(0)); //r; Optimism "docs"
    //	suggest this field should be null, but the oracle
    //	seems to undervalue the transaction a bit without

    ModuleData memory module = ModuleData({modules: new Module[](1), args: new bytes[](1)});
    module.modules[0] = Module.RESOLVER;
    module.args[0] = abi.encode(
      this,
      abi.encodeWithSelector(IResolver.checker.selector, context.vault)
    );
    rlpTransaction[5] = RLPEncode.encodeBytes(
      abi.encodeWithSelector(
        IGelatoExec.exec.selector,
        GELATO_OPERATIONS,
        abi.encodeWithSelector(
          IGelatoOps.exec.selector,
          RECEIVER,
          this,
          abi.encodeWithSelector(
            IResolver.performUpkeep.selector,
            context.vault,
            context.cost / context.overhead,
            context.cost,
            context.reward,
            context.reward > context.cost ? context.reward - context.cost : 0,
            context.daily
          ),
          module,
          context.cost,
          GAS,
          true,
          false
        ),
        GAS
      )
    );

    context.costL1 = OPTIMISM_GAS_ORACLE.getL1Fee(RLPEncode.encodeList(rlpTransaction));
    //				console.log( "current L1 fee for harvest: %s, with txdata",
    //																															context.costL1);
    //				console.logBytes( RLPEncode.encodeList( rlpTransaction));
    return context.costL1;
  }

  function _txCostWithOverheadWithPremium(
    uint256 overheadActual,
    uint256 gasPrice,
    CheckerContext memory context
  ) internal view returns (uint256) {
    uint256 l2Cost = UpkeepLibrary._calculateUpkeepTxCostFromTotalVaultHarvestOverhead(
      gasPrice,
      overheadActual,
      _getThirdPartyUpstreamContractGasOverhead(),
      getUpkeepTxPremiumFactor()
    );
    if (0 == context.costL1) _calculateL1cost(gasPrice, context);
    return l2Cost + context.costL1;
  }

  function _getThirdPartyUpstreamContractGasOverhead() internal pure returns (uint256) {
    return GELATO_REGISTRY_GAS_OVERHEAD;
  }

  function _estimateSingleVaultHarvestGasOverhead(uint256 vaultHarvestGasOverhead_)
    internal
    pure
    returns (uint256)
  {
    return
      vaultHarvestGasOverhead_ +
      BEEFY_HARVESTER_OVERHEAD +
      _getThirdPartyUpstreamContractGasOverhead();
  }

  /*      */
  /* Misc */
  /*      */
  //can receive ether from unwrapping native, like prior to relaying excess
  //	funds to the task-treasury contrct
  receive() external payable {
    //			console.log( "--> resolver just got paid");
  }

  //utility and safety mechanism
  function withdrawToken(address token_) external onlyManager {
    IERC20Upgradeable token = IERC20Upgradeable(token_);
    uint256 amount = token.balanceOf(address(this));
    token.safeTransfer(msg.sender, amount);
  }
} //abstract contract BeefySingleHarvesterBase is

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {IBeefyVault} from "../interfaces/IBeefyVault.sol";
import {BeefySingleHarvesterBase} from "./BeefySingleHarvesterBase.sol";

contract BeefySingleHarvesterGelato is BeefySingleHarvesterBase {
  //protect logic (implementation) contract
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /*             */
  /* Initializer */
  /*             */
  function initialize() external initializer {
    __Manageable_init();

    maxGasPrice = 2_000_000; //0.002 gwei
    depositFundsThreshold = 20_000_000_000_000_000; //0.02 ether
  }

  function checker(address vault_) external returns (bool canExec_, bytes memory execPayload_) {
    CheckerContext memory context = checkUpkeep(tx.gasprice, IBeefyVault(vault_));

    if (!context.harvest) {
      execPayload_ = bytes(context.cost > 0 ? "Won't harvest now" : "harvest() errored!");
    } else {
      canExec_ = true;
      execPayload_ = abi.encodeWithSelector(
        this.performUpkeep.selector,
        vault_,
        (tx.gasprice * context.overhead + context.costL1) / context.overhead,
        context.cost,
        context.reward,
        context.reward > context.cost ? context.reward - context.cost : 0,
        context.daily
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