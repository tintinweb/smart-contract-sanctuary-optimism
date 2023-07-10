/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-07-10
*/

// File @openzeppelin/contracts-upgradeable/utils/[email protected]

// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

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

// File @openzeppelin/contracts-upgradeable/proxy/utils/[email protected]

// OpenZeppelin Contracts (last updated v4.8.1) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

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
            (isTopLevelCall && _initialized < 1) ||
                (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
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
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// File @openzeppelin/contracts-upgradeable/utils/[email protected]

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {}

    function __Context_init_unchained() internal onlyInitializing {}

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

// File @openzeppelin/contracts-upgradeable/security/PausableUpgradeable.s[email protected]

// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

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

// File @openzeppelin/contracts-upgradeable/security/[email protected]

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// File @openzeppelin/contracts-upgradeable/token/ERC20/extensions/[email protected]

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

// File @openzeppelin/contracts-upgradeable/token/ERC20/[email protected]

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
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// File @openzeppelin/contracts-upgradeable/token/ERC20/utils/[email protected]

// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

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
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(IERC20Upgradeable token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20Upgradeable token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
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

// File @openzeppelin/contracts/utils/introspection/[email protected]

// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File @openzeppelin/contracts/interfaces/[email protected]

// OpenZeppelin Contracts (last updated v4.6.0) (interfaces/IERC2981.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface for the NFT Royalty Standard.
 *
 * A standardized way to retrieve royalty payment information for non-fungible tokens (NFTs) to enable universal
 * support for royalty payments across all NFT marketplaces and ecosystem participants.
 *
 * _Available since v4.5._
 */
interface IERC2981 is IERC165 {
    /**
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be paid in that same unit of exchange.
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount);
}

// File @openzeppelin/contracts/token/ERC721/[email protected]

// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// File contracts/interfaces/IGovernable.sol

pragma solidity 0.8.15;

/**
 * @notice Governable interface
 */
interface IGovernable {
    function governor() external view returns (address _governor);

    function transferGovernorship(address _proposedGovernor) external;
}

// File contracts/access/Governable.sol

pragma solidity 0.8.15;

error CallerIsNotGovernor();
error ProposedGovernorIsNull();
error CallerIsNotTheProposedGovernor();

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (governor) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the governor account will be the one that deploys the contract. This
 * can later be changed with {transferGovernorship}.
 *
 */
abstract contract Governable is IGovernable, ContextUpgradeable {
    address public governor;
    address private proposedGovernor;

    event UpdatedGovernor(address indexed previousGovernor, address indexed proposedGovernor);

    /**
     * @dev Initializes the contract setting the deployer as the initial governor.
     */
    constructor() {
        address msgSender = _msgSender();
        governor = msgSender;
        emit UpdatedGovernor(address(0), msgSender);
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial governor.
     */
    // solhint-disable-next-line func-name-mixedcase
    function __Governable_init() internal onlyInitializing {
        address msgSender = _msgSender();
        governor = msgSender;
        emit UpdatedGovernor(address(0), msgSender);
    }

    /**
     * @dev Throws if called by any account other than the governor.
     */
    modifier onlyGovernor() {
        if (governor != msg.sender) revert CallerIsNotGovernor();
        _;
    }

    /**
     * @dev Transfers governorship of the contract to a new account (`proposedGovernor`).
     * Can only be called by the current governor.
     */
    function transferGovernorship(address proposedGovernor_) external onlyGovernor {
        if (proposedGovernor_ == address(0)) revert ProposedGovernorIsNull();
        proposedGovernor = proposedGovernor_;
    }

    /**
     * @dev Allows new governor to accept governorship of the contract.
     */
    function acceptGovernorship() external {
        address _proposedGovernor = proposedGovernor;
        if (msg.sender != _proposedGovernor) revert CallerIsNotTheProposedGovernor();
        emit UpdatedGovernor(governor, _proposedGovernor);
        governor = _proposedGovernor;
        proposedGovernor = address(0);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// File contracts/interfaces/ICapsule.sol

pragma solidity 0.8.15;

interface ICapsule is IERC721, IERC2981 {
    function mint(address account, string memory _uri) external;

    function burn(address owner, uint256 tokenId) external;

    function setMetadataProvider(address _metadataAddress) external;

    // Read functions
    function baseURI() external view returns (string memory);

    function counter() external view returns (uint256);

    function exists(uint256 tokenId) external view returns (bool);

    function isCollectionMinter(address _account) external view returns (bool);

    function isCollectionPrivate() external view returns (bool);

    function maxId() external view returns (uint256);

    function royaltyRate() external view returns (uint256);

    function royaltyReceiver() external view returns (address);

    function tokenURIOwner() external view returns (address);

    ////////////////////////////////////////////////////////////////////////////
    //     Extra functions compare to original ICapsule interface    ///////////
    ////////////////////////////////////////////////////////////////////////////
    // Read functions
    function owner() external view returns (address);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    // Admin functions
    function lockCollectionCount(uint256 _nftCount) external;

    function setBaseURI(string calldata baseURI_) external;

    function setTokenURI(uint256 _tokenId, string memory _newTokenURI) external;

    function transferOwnership(address _newOwner) external;

    function updateTokenURIOwner(address _newTokenURIOwner) external;

    function updateRoyaltyConfig(address _royaltyReceiver, uint256 _royaltyRate) external;
}

// File contracts/interfaces/ICapsuleFactory.sol

pragma solidity 0.8.15;

interface ICapsuleFactory is IGovernable {
    function capsuleCollectionTax() external view returns (uint256);

    function capsuleMinter() external view returns (address);

    function createCapsuleCollection(
        string memory _name,
        string memory _symbol,
        address _tokenURIOwner,
        bool _isCollectionPrivate
    ) external payable returns (address);

    function collectionBurner(address _capsule) external view returns (address);

    function getAllCapsuleCollections() external view returns (address[] memory);

    function getCapsuleCollectionsOf(address _owner) external view returns (address[] memory);

    function getBlacklist() external view returns (address[] memory);

    function getWhitelist() external view returns (address[] memory);

    function isBlacklisted(address _user) external view returns (bool);

    function isCapsule(address _capsule) external view returns (bool);

    function isCollectionBurner(address _capsuleCollection, address _account) external view returns (bool);

    function isWhitelisted(address _user) external view returns (bool);

    function taxCollector() external view returns (address);

    //solhint-disable-next-line func-name-mixedcase
    function VERSION() external view returns (string memory);

    // Special permission functions
    function addToWhitelist(address _user) external;

    function removeFromWhitelist(address _user) external;

    function addToBlacklist(address _user) external;

    function removeFromBlacklist(address _user) external;

    function flushTaxAmount() external;

    function setCapsuleMinter(address _newCapsuleMinter) external;

    function updateCapsuleCollectionBurner(address _capsuleCollection, address _newBurner) external;

    function updateCapsuleCollectionOwner(address _previousOwner, address _newOwner) external;

    function updateCapsuleCollectionTax(uint256 _newTax) external;

    function updateTaxCollector(address _newTaxCollector) external;
}

// File contracts/interfaces/ICapsuleMinter.sol

pragma solidity 0.8.15;

interface ICapsuleMinter is IGovernable {
    struct SingleERC20Capsule {
        address tokenAddress;
        uint256 tokenAmount;
    }

    struct MultiERC20Capsule {
        address[] tokenAddresses;
        uint256[] tokenAmounts;
    }

    struct SingleERC721Capsule {
        address tokenAddress;
        uint256 id;
    }

    struct MultiERC721Capsule {
        address[] tokenAddresses;
        uint256[] ids;
    }

    struct MultiERC1155Capsule {
        address[] tokenAddresses;
        uint256[] ids;
        uint256[] tokenAmounts;
    }

    function capsuleMintTax() external view returns (uint256);

    function factory() external view returns (ICapsuleFactory);

    function getMintWhitelist() external view returns (address[] memory);

    function getCapsuleOwner(address _capsule, uint256 _id) external view returns (address);

    function getWhitelistedCallers() external view returns (address[] memory);

    function isMintWhitelisted(address _user) external view returns (bool);

    function isWhitelistedCaller(address _caller) external view returns (bool);

    function multiERC20Capsule(address _capsule, uint256 _id) external view returns (MultiERC20Capsule memory _data);

    function multiERC721Capsule(address _capsule, uint256 _id) external view returns (MultiERC721Capsule memory _data);

    function multiERC1155Capsule(
        address _capsule,
        uint256 _id
    ) external view returns (MultiERC1155Capsule memory _data);

    function singleERC20Capsule(address _capsule, uint256 _id) external view returns (SingleERC20Capsule memory);

    function singleERC721Capsule(address _capsule, uint256 _id) external view returns (SingleERC721Capsule memory);

    function mintSimpleCapsule(address _capsule, string memory _uri, address _receiver) external payable;

    function burnSimpleCapsule(address _capsule, uint256 _id, address _burnFrom) external;

    function mintSingleERC20Capsule(
        address _capsule,
        address _token,
        uint256 _amount,
        string memory _uri,
        address _receiver
    ) external payable;

    function burnSingleERC20Capsule(address _capsule, uint256 _id, address _burnFrom, address _receiver) external;

    function mintSingleERC721Capsule(
        address _capsule,
        address _token,
        uint256 _id,
        string memory _uri,
        address _receiver
    ) external payable;

    function burnSingleERC721Capsule(address _capsule, uint256 _id, address _burnFrom, address _receiver) external;

    function mintMultiERC20Capsule(
        address _capsule,
        address[] memory _tokens,
        uint256[] memory _amounts,
        string memory _uri,
        address _receiver
    ) external payable;

    function burnMultiERC20Capsule(address _capsule, uint256 _id, address _burnFrom, address _receiver) external;

    function mintMultiERC721Capsule(
        address _capsule,
        address[] memory _tokens,
        uint256[] memory _ids,
        string memory _uri,
        address _receiver
    ) external payable;

    function burnMultiERC721Capsule(address _capsule, uint256 _id, address _burnFrom, address _receiver) external;

    function mintMultiERC1155Capsule(
        address _capsule,
        address[] memory _tokens,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        string memory _uri,
        address _receiver
    ) external payable;

    function burnMultiERC1155Capsule(address _capsule, uint256 _id, address _burnFrom, address _receiver) external;

    // Special permission functions
    function addToWhitelist(address _user) external;

    function removeFromWhitelist(address _user) external;

    function flushTaxAmount() external;

    function updateCapsuleMintTax(uint256 _newTax) external;

    function updateWhitelistedCallers(address _caller) external;
}

// File contracts/interfaces/ICapsuleProxy.sol

pragma solidity 0.8.15;

interface CapsuleData {
    enum CapsuleType {
        SIMPLE,
        ERC20,
        ERC721,
        ERC1155
    }

    struct CapsuleContent {
        CapsuleType capsuleType;
        address[] tokenAddresses;
        uint256[] tokenIds;
        uint256[] amounts;
        string tokenURI;
    }
}

interface ICapsuleProxy {
    /**
     *  Burn given id from given Capsule collection
     * @param collection_ Capsule collection address
     * @param capsuleType_ Capsule type
     * @param capsuleId_ CapsuleId to burn
     * @param burnFrom_ Capsule will be burnt from this address
     * @param receiver_ Receiver of Capsule contents
     */
    function burnCapsule(
        address collection_,
        CapsuleData.CapsuleType capsuleType_,
        uint256 capsuleId_,
        address burnFrom_,
        address receiver_
    ) external;

    /**
     * Mint a Capsule with given contents in given Capsule collection
     * @param collection_ Capsule collection address
     * @param capsuleContent_ Capsule contents
     * @param receiver_ Receiver of capsule
     * @param mintFee_ Capsule mint fee. It can be different than msg.value
     * @return _capsuleId Id of newly minted capsule
     */
    function mintCapsule(
        address collection_,
        CapsuleData.CapsuleContent calldata capsuleContent_,
        address receiver_,
        uint256 mintFee_
    ) external payable returns (uint256 _capsuleId);
}

// File contracts/PostOffice.sol

// SPDX-License-Identifier: GPLv3

pragma solidity 0.8.15;

error AddressIsNull();
error ArrayLengthMismatch();
error CallerIsNotAssetKeyHolder();
error CallerIsNotAssetKeyOwner();
error NotAuthorized();
error NotReceiver();
error NotRelayer();
error ReceiverIsMissing();
error RedeemNotEnabled();
error ShippingNotEnabled();
error PackageHasBeenDelivered();
error PackageIsStillLocked();
error PasswordIsMissing();
error PasswordMismatched();
error UnsupportedCapsuleType();

abstract contract PostOfficeStorage is Governable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    enum PackageStatus {
        NO_STATUS,
        SHIPPED,
        CANCELLED,
        DELIVERED,
        REDEEMED
    }

    /// @notice This struct holds info related to package security.
    struct SecurityInfo {
        bytes32 passwordHash; // Encoded hash of password and salt. keccak(encode(password, salt)).
        uint64 unlockTimestamp; // Unix timestamp when package will be unlocked and ready to accept.
        address keyAddress; // NFT collection address. If set receiver must hold at least 1 NFT in this collection.
        uint256 keyId; // If keyAddress is set and keyId is set then receiver must hold keyId in order to accept package.
    }

    /// @notice This struct holds all info related to a package.
    struct PackageInfo {
        PackageStatus packageStatus; // Package Status
        CapsuleData.CapsuleType capsuleType; // Type of Capsule
        address manager; // Package Manager
        address receiver; // Package receiver
        SecurityInfo securityInfo; // Package security details
    }
    /// @notice Capsule Minter
    ICapsuleMinter public capsuleMinter;

    /// @notice Capsule Packaging collection
    ICapsule public packagingCollection;

    /// @notice CapsuleProxy. It does all the heavy lifting of minting/burning of Capsule.
    address public capsuleProxy;

    /// @notice Holds info of package. packageId => PackageInfo.
    mapping(uint256 => PackageInfo) public packageInfo;

    address public relayer;
}

/**
 * @title Capsule Post Office
 * @author Capsule team
 * @notice Capsule Post Office allows to ship packages, cancel packages, deliver packages and accept package.
 * We have added security measures in place so that as a shipper you do not have to worry about what happen
 * if you ship to wrong address? You can always update shipment or even cancel it altogether.
 *
 * You can ship package containing ERC20/ERC721/ERC1155 tokens to any recipient you provide.
 * You are the shipper and you control how shipping will work.
 * You get to choose
 * - What to ship? An Empty Capsule, Capsule containing ERC20 or ERC721 or ERC1155 tokens.
 * - Who to ship? Designated recipient or up for anyone to claim if recipient is address(0)
 * - How to secure package? See security info of shipPackage().
 * - How to make sure right recipient gets package?  See security info of shipPackage().
 * - Cancel the package. Yep you can do that anytime unless it is delivered.
 * - Deliver the package yourself to recipient. :)
 */
contract PostOffice is PostOfficeStorage {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    error WrongPackageStatus(PackageStatus);

    /// @notice Current version of PostOffice
    string public constant VERSION = "1.0.0";

    event PackageShipped(uint256 indexed packageId, address indexed sender, address indexed receiver);
    event PackageCancelled(uint256 indexed packageId, address indexed receiver);
    event PackageDelivered(uint256 indexed packageId, address indexed receiver);
    event PackageRedeemed(uint256 indexed packageId, address indexed burnFrom, address indexed receiver);
    event PackageManagerUpdated(
        uint256 indexed packageId,
        address indexed oldPackageManager,
        address indexed newPackageManager
    );
    event PackageReceiverUpdated(uint256 indexed packageId, address indexed oldReceiver, address indexed newReceiver);
    event PackagePasswordHashUpdated(uint256 indexed packageId, bytes32 passwordHash);
    event PackageAssetKeyUpdated(uint256 indexed packageId, address indexed keyAddress, uint256 keyId);
    event PackageUnlockTimestampUpdated(uint256 indexed packageId, uint256 unlockTimestamp);

    modifier onlyRelayer() {
        if (msg.sender != relayer) revert NotRelayer();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        ICapsuleMinter capsuleMinter_,
        ICapsule capsuleCollection_,
        address capsuleProxy_
    ) external initializer {
        if (address(capsuleMinter_) == address(0)) revert AddressIsNull();
        if (address(capsuleCollection_) == address(0)) revert AddressIsNull();
        if (capsuleProxy_ == address(0)) revert AddressIsNull();
        capsuleMinter = capsuleMinter_;
        packagingCollection = capsuleCollection_;
        capsuleProxy = capsuleProxy_;
        relayer = msg.sender;

        __Governable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        // Deploy PostOffice in paused state
        _pause();
    }

    /**
     * @notice Ship package containing ERC20/ERC721/ERC1155 tokens to any recipient you provide.
     * @param packageContent_ Contents of package to ship. A Capsule will be created using these contents.
     * This param is struct of `CapsuleData.CapsuleContent` type.
     * enum CapsuleType { SIMPLE, ERC20, ERC721, ERC1155 }
     * struct CapsuleContent {
     *   CapsuleType capsuleType; // Capsule Type from above enum
     *   address[] tokenAddresses; // Tokens to send in packages
     *   uint256[] tokenIds; // TokenIds in case of ERC721 and ERC1155. Send 0 for ERC20.
     *   uint256[] amounts; // Token amounts in case of ERC20 and ERC1155. Send 0 for ERC721.
     *   string tokenURI;  // TokenURI for Capsule NFT
     *   }
     *
     * @param securityInfo_ It is important to deliver package to right receiver and hence package security
     * comes into picture. It is possible to secure your package and there are 3 independent security measures are supported.
     * For any given package you can provide none, all or any combination of these 3.
     * 1. Password lock. `receiver_` will have to provide a password to accept package.
     * 2. Time lock, `receiver_` can not accept before time lock is unlocked.
     * 3. AssetKey lock. `receiver_` must be hold at least 1 NFT in NFT collection at `keyAddress`.
     *    `receiver_` must hold NFT with specific id from NFT collection if `keyId` is set.
     *     If do not want to enforce `keyId` then provider type(uint256).max as `keyId`.
     *
     * struct SecurityInfo {
     *   bytes32 passwordHash; // Encoded hash of password and salt. keccak(encode(password, salt))
     *                          // `receiver` will need password and salt both to accept package.
     *   uint64 unlockTimestamp; // Unix timestamp when package will be unlocked and ready to accept
     *   address keyAddress;    // NFT collection address. If set receiver must hold at least 1 NFT in this collection.
     *   uint256 keyId;         // If keyAddress is set and keyId is set then receiver must hold keyId in order to accept package.
     *   }
     *
     * @param receiver_ Package receiver. `receiver_` can be zero if you want address to accept/claim this package.
     */
    function shipPackage(
        CapsuleData.CapsuleContent calldata packageContent_,
        SecurityInfo calldata securityInfo_,
        address receiver_
    ) public payable returns (uint256) {
        return _shipPackage(packageContent_, securityInfo_, receiver_, msg.value);
    }

    function shipPackages(
        CapsuleData.CapsuleContent[] calldata packageContent_,
        SecurityInfo[] calldata securityInfo_,
        address[] calldata receiver_
    ) external payable returns (uint256[] memory _packageIds) {
        uint256 _len = receiver_.length;
        if (packageContent_.length != _len || securityInfo_.length != _len) revert ArrayLengthMismatch();
        _packageIds = new uint256[](_len);
        uint256 _mintFee = msg.value / _len;
        for (uint16 i; i < _len; i++) {
            _packageIds[i] = _shipPackage(packageContent_[i], securityInfo_[i], receiver_[i], _mintFee);
        }
    }

    /**
     * @notice Package receiver will call this function to pickup package.
     * This function will make sure caller and package state pass all the security measure before it get delivered.
     * @param packageId_ Package id of Capsule package.
     * @param rawPassword_  Plain text password. You get it from shipper. Send empty('') if no password lock.
     * @param salt_ Plain text salt. You get it from shipper(unless you shipped via Capsule UI). Send empty('') if no password lock.
     * @param shouldRedeem_ Boolean flag indicating you want to unwrap package or want it as is.
     * True == You want to unwrap package aka burn Capsule NFT and get contents transferred to you.
     * False == You want to receive Capsule NFT. You can always redeem/burn this NFT later and receive contents.
     */
    function pickup(
        uint256 packageId_,
        string calldata rawPassword_,
        string calldata salt_,
        bool shouldRedeem_
    ) external payable whenNotPaused nonReentrant {
        address _receiver = packageInfo[packageId_].receiver;
        if (_receiver == address(0)) revert ReceiverIsMissing();
        if (_receiver != msg.sender) revert NotReceiver();

        _pickup(packageId_, rawPassword_, salt_, shouldRedeem_, _receiver);
    }

    /**
     * @notice Redeem package by unwrapping package(burning Capsule). Package contents will be transferred to `receiver_`.
     * There are 2 cases when you have wrapped package,
     * 1. Package got delivered to you.
     * 2. You(recipient) accepted package at PostOffice without redeeming it.
     * In above cases you have a Capsule NFT, you can redeem this NFT for it's content using this function.
     * @param packageId_ Package id
     * @param receiver_ receive of package/Capsule contents.
     */
    function redeemPackage(uint256 packageId_, address receiver_) external whenNotPaused nonReentrant {
        if (receiver_ == address(0)) revert AddressIsNull();

        PackageStatus _status = packageInfo[packageId_].packageStatus;
        if (_status != PackageStatus.DELIVERED) revert WrongPackageStatus(_status);
        // It is quite possible that after delivery of package, original receiver transfer package to someone else.
        // Hence we will redeem package to provided receiver_ address and not on receiver stored in packageInfo
        _redeemPackage(packageId_, msg.sender, receiver_);
    }

    /**
     * @notice Get security info of package
     * @param packageId_ Package Id
     */
    function securityInfo(uint256 packageId_) external view returns (SecurityInfo memory) {
        return packageInfo[packageId_].securityInfo;
    }

    function _burnCapsule(
        CapsuleData.CapsuleType capsuleType_,
        uint256 packageId_,
        address burnFrom_,
        address receiver_
    ) internal {
        _executeViaProxy(
            abi.encodeWithSelector(
                ICapsuleProxy.burnCapsule.selector,
                address(packagingCollection),
                capsuleType_,
                packageId_,
                burnFrom_,
                receiver_
            )
        );
    }

    function _checkPackageInfo(uint256 packageId_) private view {
        if (msg.sender != packageInfo[packageId_].manager && msg.sender != governor) revert NotAuthorized();
        _validateShippedStatus(packageInfo[packageId_].packageStatus);
    }

    function _deliverPackage(uint256 packageId_, address receiver_) internal {
        packageInfo[packageId_].packageStatus = PackageStatus.DELIVERED;
        packagingCollection.safeTransferFrom(address(this), receiver_, packageId_);
        emit PackageDelivered(packageId_, receiver_);
    }

    function _executeViaProxy(bytes memory _data) private returns (uint256) {
        // solhint-disable-next-line avoid-low-level-calls
        (bool _success, bytes memory _returnData) = capsuleProxy.delegatecall(_data);
        if (_success) {
            return _returnData.length > 0 ? abi.decode(_returnData, (uint256)) : 0;
        } else {
            // Below code is taken from https://ethereum.stackexchange.com/a/114140
            // solhint-disable-next-line no-inline-assembly
            assembly {
                revert(add(_returnData, 32), _returnData)
            }
        }
    }

    function _getPasswordHash(string calldata inputPassword_, string calldata salt_) internal pure returns (bytes32) {
        return keccak256(abi.encode(inputPassword_, salt_));
    }

    function _pickup(
        uint256 packageId_,
        string calldata rawPassword_,
        string calldata salt_,
        bool shouldRedeem_,
        address receiver_
    ) internal {
        _validateShippedStatus(packageInfo[packageId_].packageStatus);
        SecurityInfo memory _sInfo = packageInfo[packageId_].securityInfo;
        // Security Mode:: TIME_LOCKED
        if (_sInfo.unlockTimestamp > block.timestamp) revert PackageIsStillLocked();

        // Security Mode:: ASSET_KEY
        if (_sInfo.keyAddress != address(0)) {
            // If no specific id is provided then check if caller is holder
            if (_sInfo.keyId == type(uint256).max) {
                if (IERC721(_sInfo.keyAddress).balanceOf(msg.sender) == 0) revert CallerIsNotAssetKeyHolder();
            } else {
                // If specific id is provided then caller must be owner of keyId  NFT collection
                if (IERC721(_sInfo.keyAddress).ownerOf(_sInfo.keyId) != msg.sender) revert CallerIsNotAssetKeyOwner();
            }
        }

        // Security Mode:: PASSWORD_PROTECTED
        if (_sInfo.passwordHash != bytes32(0)) {
            if (_getPasswordHash(rawPassword_, salt_) != _sInfo.passwordHash) revert PasswordMismatched();
        }

        if (shouldRedeem_) {
            emit PackageDelivered(packageId_, receiver_);
            _redeemPackage(packageId_, address(this), receiver_);
        } else {
            _deliverPackage(packageId_, receiver_);
        }
    }

    function _redeemPackage(uint256 packageId_, address burnFrom_, address receiver_) internal {
        packageInfo[packageId_].packageStatus = PackageStatus.REDEEMED;
        _burnCapsule(packageInfo[packageId_].capsuleType, packageId_, burnFrom_, receiver_);
        emit PackageRedeemed(packageId_, burnFrom_, receiver_);
    }

    function _shipPackage(
        CapsuleData.CapsuleContent calldata packageContent_,
        SecurityInfo calldata securityInfo_,
        address receiver_,
        uint256 mintFee_
    ) private whenNotPaused nonReentrant returns (uint256 _packageId) {
        //  Mint capsule based on contains of package
        _packageId = _executeViaProxy(
            abi.encodeWithSelector(
                ICapsuleProxy.mintCapsule.selector,
                address(packagingCollection),
                packageContent_,
                address(this),
                mintFee_
            )
        );

        // Prepare package info for shipping
        PackageInfo memory _pInfo = PackageInfo({
            capsuleType: packageContent_.capsuleType,
            packageStatus: PackageStatus.SHIPPED,
            manager: msg.sender,
            receiver: receiver_,
            securityInfo: securityInfo_
        });

        // Store package info
        packageInfo[_packageId] = _pInfo;

        emit PackageShipped(_packageId, msg.sender, receiver_);
    }

    function _validateShippedStatus(PackageStatus _status) internal pure {
        if (_status != PackageStatus.SHIPPED) revert WrongPackageStatus(_status);
    }

    /******************************************************************************
     *                              Relayer functions                             *
     *****************************************************************************/

    function privatePickup(
        uint256 packageId_,
        string calldata rawPassword_,
        string calldata salt_,
        bool shouldRedeem_,
        address receiver_
    ) external payable onlyRelayer {
        if (receiver_ == address(0)) revert AddressIsNull();
        _pickup(packageId_, rawPassword_, salt_, shouldRedeem_, receiver_);

        // Forward gas to recipient.
        if (msg.value > 0) {
            payable(receiver_).transfer(msg.value);
        }
    }

    /******************************************************************************
     *                    Package Manager & Governor functions                    *
     *****************************************************************************/

    /**
     * @notice onlyPackageManager:: Cancel package aka cancel package/shipment
     * @param packageId_ id of package to cancel
     * @param contentReceiver_ Address which will receive contents of package
     */
    function cancelPackage(uint256 packageId_, address contentReceiver_) external whenNotPaused nonReentrant {
        if (contentReceiver_ == address(0)) revert AddressIsNull();
        _checkPackageInfo(packageId_);

        packageInfo[packageId_].packageStatus = PackageStatus.CANCELLED;
        _burnCapsule(packageInfo[packageId_].capsuleType, packageId_, address(this), contentReceiver_);
        emit PackageCancelled(packageId_, contentReceiver_);
    }

    /**
     * @notice onlyPackageManager:: Deliver package to receiver
     * @param packageId_ id of package to deliver
     */
    function deliverPackage(uint packageId_) external whenNotPaused nonReentrant {
        address _receiver = packageInfo[packageId_].receiver;
        if (_receiver == address(0)) revert ReceiverIsMissing();
        _checkPackageInfo(packageId_);
        // All security measures are bypassed. It is better to set unlockTimestamp for consistency.
        if (packageInfo[packageId_].securityInfo.unlockTimestamp > uint64(block.timestamp)) {
            packageInfo[packageId_].securityInfo.unlockTimestamp = uint64(block.timestamp);
        }
        _deliverPackage(packageId_, _receiver);
    }

    /**
     * @notice onlyPackageManager:: Update AssetKey of package
     * @param packageId_ PackageId
     * @param newKeyAddress_ AssetKey address aka ERC721 collection address
     * @param newKeyId_ AssetKey id aka NFT id
     */
    function updatePackageAssetKey(
        uint256 packageId_,
        address newKeyAddress_,
        uint256 newKeyId_
    ) external whenNotPaused {
        _checkPackageInfo(packageId_);
        emit PackageAssetKeyUpdated(packageId_, newKeyAddress_, newKeyId_);
        packageInfo[packageId_].securityInfo.keyAddress = newKeyAddress_;
        packageInfo[packageId_].securityInfo.keyId = newKeyId_;
    }

    /**
     * @notice onlyPackageManager:: Update PackageManger of package
     * @param packageId_ PackageId
     * @param newPackageManager_ New PackageManager address
     */
    function updatePackageManager(uint256 packageId_, address newPackageManager_) external whenNotPaused {
        if (newPackageManager_ == address(0)) revert AddressIsNull();
        _checkPackageInfo(packageId_);
        emit PackageManagerUpdated(packageId_, packageInfo[packageId_].manager, newPackageManager_);
        packageInfo[packageId_].manager = newPackageManager_;
    }

    /**
     * @notice onlyPackageManager:: Update PasswordHash of package
     * @param packageId_ PackageId
     * @param newPasswordHash_ New password hash
     */
    function updatePackagePasswordHash(uint256 packageId_, bytes32 newPasswordHash_) external whenNotPaused {
        _checkPackageInfo(packageId_);
        emit PackagePasswordHashUpdated(packageId_, newPasswordHash_);
        packageInfo[packageId_].securityInfo.passwordHash = newPasswordHash_;
    }

    /**
     * @notice onlyPackageManager:: Update package receiver
     * @param packageId_ PackageId
     * @param newReceiver_ New receiver address
     */
    function updatePackageReceiver(uint256 packageId_, address newReceiver_) external whenNotPaused {
        _checkPackageInfo(packageId_);
        emit PackageReceiverUpdated(packageId_, packageInfo[packageId_].receiver, newReceiver_);
        packageInfo[packageId_].receiver = newReceiver_;
    }

    /**
     * @notice onlyPackageManager:: Update package unlock timestamp
     * @param packageId_ PackageId
     * @param newUnlockTimestamp_ New unlock timestamp
     */
    function updatePackageUnlockTimestamp(uint256 packageId_, uint64 newUnlockTimestamp_) external whenNotPaused {
        _checkPackageInfo(packageId_);
        emit PackageUnlockTimestampUpdated(packageId_, newUnlockTimestamp_);
        packageInfo[packageId_].securityInfo.unlockTimestamp = newUnlockTimestamp_;
    }

    /******************************************************************************
     *                            Governor functions                              *
     *****************************************************************************/

    /**
     * @notice onlyGovernor:: Triggers stopped state.
     *
     * Requirements:
     * - The contract must not be paused.
     */
    function pause() external onlyGovernor {
        _pause();
    }

    /// @notice onlyGovernor:: Sweep given token to governor address
    function sweep(address _token) external onlyGovernor {
        if (_token == address(0)) {
            AddressUpgradeable.sendValue(payable(governor), address(this).balance);
        } else {
            uint256 _amount = IERC20Upgradeable(_token).balanceOf(address(this));
            IERC20Upgradeable(_token).safeTransfer(governor, _amount);
        }
    }

    /**
     * @notice onlyGovernor:: Transfer ownership of the packaging collection
     * @param newOwner_ Address of new owner
     */
    function transferCollectionOwnership(address newOwner_) external onlyGovernor {
        packagingCollection.transferOwnership(newOwner_);
    }

    /**
     * @notice onlyGovernor:: Returns to normal state.
     *
     * Requirements:
     * - The contract must be paused.
     */
    function unpause() external onlyGovernor {
        _unpause();
    }

    /**
     * @notice onlyGovernor:: Set the collection baseURI
     * @param baseURI_ New baseURI string
     */
    function updateBaseURI(string memory baseURI_) public onlyGovernor {
        packagingCollection.setBaseURI(baseURI_);
    }

    /**
     * @notice onlyGovernor:: Set collection burner address
     * @param _newBurner Address of collection burner
     */
    function updateCollectionBurner(address _newBurner) external onlyGovernor {
        capsuleMinter.factory().updateCapsuleCollectionBurner(address(packagingCollection), _newBurner);
    }

    /**
     * @notice onlyGovernor:: Transfer metamaster of the packaging collection
     * @param metamaster_ Address of new metamaster
     */
    function updateMetamaster(address metamaster_) external onlyGovernor {
        packagingCollection.updateTokenURIOwner(metamaster_);
    }

    /**
     * @notice onlyGovernor:: Set new relayer
     * @param newRelayer_ Address of new relayer
     */
    function updateRelayer(address newRelayer_) external onlyGovernor {
        if (newRelayer_ == address(0)) revert AddressIsNull();
        relayer = newRelayer_;
    }

    /**
     * @notice onlyGovernor:: Update royalty receiver and rate in packaging collection
     * @param royaltyReceiver_ Address of royalty receiver
     * @param royaltyRate_ Royalty rate in Basis Points. ie. 100 = 1%, 10_000 = 100%
     */
    function updateRoyaltyConfig(address royaltyReceiver_, uint256 royaltyRate_) external onlyGovernor {
        packagingCollection.updateRoyaltyConfig(royaltyReceiver_, royaltyRate_);
    }
}