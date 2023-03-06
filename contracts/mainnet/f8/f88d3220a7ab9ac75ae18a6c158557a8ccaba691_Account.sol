// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/Address.sol";

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
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
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
            (isTopLevelCall && _initialized < 1) || (!Address.isContract(address(this)) && _initialized == 1),
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
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Permit.sol)

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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

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

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

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

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
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

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import {
    IAccount,
    IAddressResolver,
    IExchanger,
    IFactory,
    IFuturesMarketManager,
    IPerpsV2MarketConsolidated,
    ISettings,
    IEvents
} from "./interfaces/IAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {OpsReady, IOps} from "./utils/OpsReady.sol";
import {Owned} from "@solmate/auth/Owned.sol";

/// @title Kwenta Smart Margin Account Implementation
/// @author JaredBorders ([email protected]), JChiaramonte7 ([email protected])
/// @notice flexible smart margin account enabling users to trade on-chain derivatives
contract Account is IAccount, OpsReady, Owned, Initializable {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAccount
    bytes32 public constant VERSION = "2.0.0";

    /// @notice tracking code used when modifying positions
    bytes32 private constant TRACKING_CODE = "KWENTA";

    /// @notice name for futures market manager
    bytes32 private constant FUTURES_MARKET_MANAGER = "FuturesMarketManager";

    /// @notice constant for sUSD currency key
    bytes32 private constant SUSD = "sUSD";

    /// @notice minimum ETH balance required to place a conditional order
    uint256 private constant MIN_ETH = 1 ether / 100;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice address of the Synthetix ReadProxyAddressResolver
    IAddressResolver private immutable ADDRESS_RESOLVER;

    /// @notice address of the Synthetix ProxyERC20sUSD
    /// address used as the margin asset
    IERC20 private immutable MARGIN_ASSET;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAccount
    IFactory public factory;

    //// @inheritdoc IAccount
    IFuturesMarketManager public futuresMarketManager;

    /// @inheritdoc IAccount
    ISettings public settings;

    /// @inheritdoc IAccount
    IEvents public events;

    /// @inheritdoc IAccount
    uint256 public committedMargin;

    /// @inheritdoc IAccount
    uint256 public conditionalOrderId;

    /// @notice track conditional orders by id
    mapping(uint256 id => ConditionalOrder order) private conditionalOrders;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice helpful modifier to check non-zero values
    /// @param value: value to check if zero
    modifier notZero(uint256 value, bytes32 valueName) {
        if (value == 0) revert ValueCannotBeZero(valueName);

        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice disable initializers on initial contract deployment
    /// @dev set owner of implementation to zero address
    constructor(address addressResolver, address marginAsset) Owned(address(0)) {
        // recommended to use this to lock implementation contracts
        // that are designed to be called through proxies
        _disableInitializers();

        ADDRESS_RESOLVER = IAddressResolver(addressResolver);
        MARGIN_ASSET = IERC20(marginAsset);
    }

    /// @notice initialize contract (only once) and transfer ownership to specified address
    /// @dev ensure resolver and sUSD addresses are set to their proxies and not implementations
    /// @param _owner: account owner
    /// @param _settings: contract address for account settings
    /// @param _events: address of events contract for accounts
    /// @param _factory: contract address for account factory
    function initialize(address _owner, address _settings, address _events, address _factory)
        external
        initializer
    {
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);

        settings = ISettings(_settings);
        events = IEvents(_events);
        factory = IFactory(_factory);

        // get address for futures market manager
        futuresMarketManager = IFuturesMarketManager(
            ADDRESS_RESOLVER.requireAndGetAddress(
                FUTURES_MARKET_MANAGER, "Account: Could not get Futures Market Manager"
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAccount
    function getDelayedOrder(bytes32 _marketKey)
        external
        view
        override
        returns (IPerpsV2MarketConsolidated.DelayedOrder memory order)
    {
        // fetch delayed order data from Synthetix
        order = _getPerpsV2Market(_marketKey).delayedOrders(address(this));
    }

    /// @inheritdoc IAccount
    function checker(uint256 _conditionalOrderId)
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        (canExec,) = _validConditionalOrder(_conditionalOrderId);

        // calldata for execute func
        execPayload = abi.encodeCall(this.executeConditionalOrder, _conditionalOrderId);
    }

    /// @inheritdoc IAccount
    function freeMargin() public view override returns (uint256) {
        return MARGIN_ASSET.balanceOf(address(this)) - committedMargin;
    }

    /// @inheritdoc IAccount
    function getPosition(bytes32 _marketKey)
        public
        view
        override
        returns (IPerpsV2MarketConsolidated.Position memory position)
    {
        // fetch position data from Synthetix
        position = _getPerpsV2Market(_marketKey).positions(address(this));
    }

    /// @inheritdoc IAccount
    function getConditionalOrder(uint256 _conditionalOrderId)
        public
        view
        override
        returns (ConditionalOrder memory)
    {
        return conditionalOrders[_conditionalOrderId];
    }

    /*//////////////////////////////////////////////////////////////
                           ACCOUNT OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    /// @notice transfer ownership of this account to a new address
    /// @dev will update factory's mapping record of owner to account
    /// @param _newOwner: address to transfer ownership to
    function transferOwnership(address _newOwner) public override onlyOwner {
        factory.updateAccountOwner({_oldOwner: owner, _newOwner: _newOwner});
        super.transferOwnership(_newOwner);
    }

    /*//////////////////////////////////////////////////////////////
                               EXECUTION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAccount
    function execute(Command[] memory _commands, bytes[] memory _inputs)
        external
        payable
        override
        onlyOwner
    {
        uint256 numCommands = _commands.length;
        if (_inputs.length != numCommands) {
            revert LengthMismatch();
        }

        // loop through all given commands and execute them
        for (uint256 commandIndex = 0; commandIndex < numCommands;) {
            Command command = _commands[commandIndex];

            bytes memory input = _inputs[commandIndex];

            _dispatch(command, input);

            unchecked {
                commandIndex++;
            }
        }
    }

    function _dispatch(Command _command, bytes memory _inputs) internal {
        // @TODO optimize via grouping commands: i.e. if uint(command) > 5, etc.

        if (_command == Command.ACCOUNT_MODIFY_MARGIN) {
            (int256 amount) = abi.decode(_inputs, (int256));
            _modifyAccountMargin({_amount: amount});
        } else if (_command == Command.ACCOUNT_WITHDRAW_ETH) {
            (uint256 amount) = abi.decode(_inputs, (uint256));
            _withdrawEth({_amount: amount});
        } else if (_command == Command.PERPS_V2_MODIFY_MARGIN) {
            (address market, int256 amount) = abi.decode(_inputs, (address, int256));
            _perpsV2ModifyMargin({_market: market, _amount: amount});
        } else if (_command == Command.PERPS_V2_WITHDRAW_ALL_MARGIN) {
            address market = abi.decode(_inputs, (address));
            _perpsV2WithdrawAllMargin({_market: market});
        } else if (_command == Command.PERPS_V2_SUBMIT_ATOMIC_ORDER) {
            (address market, int256 sizeDelta, uint256 priceImpactDelta) =
                abi.decode(_inputs, (address, int256, uint256));
            _perpsV2SubmitAtomicOrder({
                _market: market,
                _sizeDelta: sizeDelta,
                _priceImpactDelta: priceImpactDelta
            });
        } else if (_command == Command.PERPS_V2_SUBMIT_DELAYED_ORDER) {
            (address market, int256 sizeDelta, uint256 priceImpactDelta, uint256 desiredTimeDelta) =
                abi.decode(_inputs, (address, int256, uint256, uint256));
            _perpsV2SubmitDelayedOrder({
                _market: market,
                _sizeDelta: sizeDelta,
                _priceImpactDelta: priceImpactDelta,
                _desiredTimeDelta: desiredTimeDelta
            });
        } else if (_command == Command.PERPS_V2_SUBMIT_OFFCHAIN_DELAYED_ORDER) {
            (address market, int256 sizeDelta, uint256 priceImpactDelta) =
                abi.decode(_inputs, (address, int256, uint256));
            _perpsV2SubmitOffchainDelayedOrder({
                _market: market,
                _sizeDelta: sizeDelta,
                _priceImpactDelta: priceImpactDelta
            });
        } else if (_command == Command.PERPS_V2_CANCEL_DELAYED_ORDER) {
            address market = abi.decode(_inputs, (address));
            _perpsV2CancelDelayedOrder({_market: market});
        } else if (_command == Command.PERPS_V2_CANCEL_OFFCHAIN_DELAYED_ORDER) {
            address market = abi.decode(_inputs, (address));
            _perpsV2CancelOffchainDelayedOrder({_market: market});
        } else if (_command == Command.PERPS_V2_CLOSE_POSITION) {
            (address market, uint256 priceImpactDelta) = abi.decode(_inputs, (address, uint256));
            _perpsV2ClosePosition({_market: market, _priceImpactDelta: priceImpactDelta});
        } else if (_command == Command.GELATO_PLACE_CONDITIONAL_ORDER) {
            (
                bytes32 marketKey,
                int256 marginDelta,
                int256 sizeDelta,
                uint256 targetPrice,
                ConditionalOrderTypes conditionalOrderType,
                uint128 priceImpactDelta,
                bool reduceOnly
            ) = abi.decode(
                _inputs, (bytes32, int256, int256, uint256, ConditionalOrderTypes, uint128, bool)
            );
            _placeConditionalOrder({
                _marketKey: marketKey,
                _marginDelta: marginDelta,
                _sizeDelta: sizeDelta,
                _targetPrice: targetPrice,
                _conditionalOrderType: conditionalOrderType,
                _priceImpactDelta: priceImpactDelta,
                _reduceOnly: reduceOnly
            });
        } else if (_command == Command.GELATO_CANCEL_CONDITIONAL_ORDER) {
            uint256 orderId = abi.decode(_inputs, (uint256));
            _cancelConditionalOrder({_conditionalOrderId: orderId});
        } else {
            // placeholder area for further commands
            revert InvalidCommandType(uint256(_command));
        }
    }

    /*//////////////////////////////////////////////////////////////
                        ACCOUNT DEPOSIT/WITHDRAW
    //////////////////////////////////////////////////////////////*/

    /// @notice allows ETH to be deposited directly into a margin account
    /// @notice ETH can be withdrawn
    receive() external payable onlyOwner {}

    /// @notice allow users to withdraw ETH deposited for keeper fees
    /// @param _amount: amount to withdraw
    function _withdrawEth(uint256 _amount) internal {
        if (_amount > 0) {
            (bool success,) = payable(owner).call{value: _amount}("");
            if (!success) revert EthWithdrawalFailed();

            events.emitEthWithdraw({user: msg.sender, account: address(this), amount: _amount});
        }
    }

    /// @notice deposit/withdraw margin to/from this smart margin account
    /// @param _amount: amount of margin to deposit/withdraw
    function _modifyAccountMargin(int256 _amount) internal {
        // if amount is positive, deposit
        if (_amount > 0) {
            bool success = MARGIN_ASSET.transferFrom(owner, address(this), _abs(_amount));
            if (!success) revert FailedMarginTransfer();

            events.emitDeposit({user: msg.sender, account: address(this), amount: _abs(_amount)});
        } else if (_amount < 0) {
            // if amount is negative, withdraw
            if (_abs(_amount) > freeMargin()) {
                /// @dev make sure committed margin isn't withdrawn
                revert InsufficientFreeMargin(freeMargin(), _abs(_amount));
            } else {
                bool success = MARGIN_ASSET.transfer(owner, _abs(_amount));
                if (!success) revert FailedMarginTransfer();

                events.emitWithdraw({
                    user: msg.sender,
                    account: address(this),
                    amount: _abs(_amount)
                });
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                          MODIFY MARKET MARGIN
    //////////////////////////////////////////////////////////////*/

    /// @notice deposit/withdraw margin to/from a Synthetix PerpsV2 Market
    /// @param _market: address of market
    /// @param _amount: amount of margin to deposit/withdraw
    function _perpsV2ModifyMargin(address _market, int256 _amount) internal {
        if (_amount > 0) {
            if (uint256(_amount) > freeMargin()) {
                revert InsufficientFreeMargin(freeMargin(), uint256(_amount));
            } else {
                IPerpsV2MarketConsolidated(_market).transferMargin(_amount);
            }
        } else {
            IPerpsV2MarketConsolidated(_market).transferMargin(_amount);
        }
    }

    /// @notice withdraw margin from market back to this account
    /// @dev this will *not* fail if market has zero margin
    function _perpsV2WithdrawAllMargin(address _market) internal {
        IPerpsV2MarketConsolidated(_market).withdrawAllMargin();
    }

    /*//////////////////////////////////////////////////////////////
                             ATOMIC ORDERS
    //////////////////////////////////////////////////////////////*/

    /// @notice submit an atomic order to a Synthetix PerpsV2 Market
    /// @dev trade fee may be imposed on smart margin account
    /// @param _market: address of market
    /// @param _sizeDelta: size delta of order
    /// @param _priceImpactDelta: price impact delta of order
    function _perpsV2SubmitAtomicOrder(
        address _market,
        int256 _sizeDelta,
        uint256 _priceImpactDelta
    ) internal {
        _imposeFee(
            _calculateTradeFee({
                _sizeDelta: _sizeDelta,
                _market: IPerpsV2MarketConsolidated(_market),
                _conditionalOrderFee: 0
            })
        );

        IPerpsV2MarketConsolidated(_market).modifyPositionWithTracking({
            sizeDelta: _sizeDelta,
            priceImpactDelta: _priceImpactDelta,
            trackingCode: TRACKING_CODE
        });
    }

    /// @notice close Synthetix PerpsV2 Market position via an atomic order
    /// @dev trade fee may be imposed on smart margin account
    /// @param _market: address of market
    /// @param _priceImpactDelta: price impact delta of order
    function _perpsV2ClosePosition(address _market, uint256 _priceImpactDelta) internal {
        // establish Synthetix PerpsV2 Market position
        bytes32 marketKey = IPerpsV2MarketConsolidated(_market).marketKey();

        // close position (i.e. reduce size to zero)
        /// @dev this does not remove margin from market
        IPerpsV2MarketConsolidated(_market).closePositionWithTracking(
            _priceImpactDelta, TRACKING_CODE
        );

        _imposeFee(
            _calculateTradeFee({
                _sizeDelta: getPosition(marketKey).size,
                _market: IPerpsV2MarketConsolidated(_market),
                _conditionalOrderFee: 0
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                             DELAYED ORDERS
    //////////////////////////////////////////////////////////////*/

    /// @notice submit a delayed order to a Synthetix PerpsV2 Market
    /// @dev trade fee may be imposed on smart margin account
    /// @param _market: address of market
    /// @param _sizeDelta: size delta of order
    /// @param _priceImpactDelta: price impact delta of order
    /// @param _desiredTimeDelta: desired time delta of order
    function _perpsV2SubmitDelayedOrder(
        address _market,
        int256 _sizeDelta,
        uint256 _priceImpactDelta,
        uint256 _desiredTimeDelta
    ) internal {
        _imposeFee(
            _calculateTradeFee({
                _sizeDelta: _sizeDelta,
                _market: IPerpsV2MarketConsolidated(_market),
                _conditionalOrderFee: 0
            })
        );

        IPerpsV2MarketConsolidated(_market).submitDelayedOrderWithTracking({
            sizeDelta: _sizeDelta,
            priceImpactDelta: _priceImpactDelta,
            desiredTimeDelta: _desiredTimeDelta,
            trackingCode: TRACKING_CODE
        });
    }

    /// @notice cancel a *pending* delayed order from a Synthetix PerpsV2 Market
    /// @dev will revert if no previous delayed order
    function _perpsV2CancelDelayedOrder(address _market) internal {
        IPerpsV2MarketConsolidated(_market).cancelDelayedOrder(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                        DELAYED OFF-CHAIN ORDERS
    //////////////////////////////////////////////////////////////*/

    /// @notice submit an off-chain delayed order to a Synthetix PerpsV2 Market
    /// @dev trade fee may be imposed on smart margin account
    /// @param _market: address of market
    /// @param _sizeDelta: size delta of order
    /// @param _priceImpactDelta: price impact delta of order
    function _perpsV2SubmitOffchainDelayedOrder(
        address _market,
        int256 _sizeDelta,
        uint256 _priceImpactDelta
    ) internal {
        _imposeFee(
            _calculateTradeFee({
                _sizeDelta: _sizeDelta,
                _market: IPerpsV2MarketConsolidated(_market),
                _conditionalOrderFee: 0
            })
        );

        IPerpsV2MarketConsolidated(_market).submitOffchainDelayedOrderWithTracking({
            sizeDelta: _sizeDelta,
            priceImpactDelta: _priceImpactDelta,
            trackingCode: TRACKING_CODE
        });
    }

    /// @notice cancel a *pending* off-chain delayed order from a Synthetix PerpsV2 Market
    /// @dev will revert if no previous offchain delayed order
    function _perpsV2CancelOffchainDelayedOrder(address _market) internal {
        IPerpsV2MarketConsolidated(_market).cancelOffchainDelayedOrder(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                           CONDITIONAL ORDERS
    //////////////////////////////////////////////////////////////*/

    /// @notice register a conditional order internally and with gelato
    /// @dev restricts _sizeDelta to be non-zero otherwise no need for conditional order
    /// @param _marketKey: Synthetix futures market id/key
    /// @param _marginDelta: amount of margin (in sUSD) to deposit or withdraw
    /// @param _sizeDelta: denominated in market currency (i.e. ETH, BTC, etc), size of position
    /// @param _targetPrice: expected conditional order price
    /// @param _conditionalOrderType: expected conditional order type enum where 0 = LIMIT, 1 = STOP, etc..
    /// @param _priceImpactDelta: price impact tolerance as a percentage
    /// @param _reduceOnly: if true, only allows position's absolute size to decrease
    function _placeConditionalOrder(
        bytes32 _marketKey,
        int256 _marginDelta,
        int256 _sizeDelta,
        uint256 _targetPrice,
        ConditionalOrderTypes _conditionalOrderType,
        uint128 _priceImpactDelta,
        bool _reduceOnly
    ) internal notZero(_abs(_sizeDelta), "_sizeDelta") {
        // if more margin is desired on the position we must commit the margin
        if (_marginDelta > 0) {
            // ensure margin doesn't exceed max
            if (uint256(_marginDelta) > freeMargin()) {
                revert InsufficientFreeMargin(freeMargin(), uint256(_marginDelta));
            }
            committedMargin += _abs(_marginDelta);
        }

        // create and submit Gelato task for this conditional order
        bytes32 taskId = _createGelatoTask();

        // internally store the conditional order
        conditionalOrders[conditionalOrderId] = ConditionalOrder({
            marketKey: _marketKey,
            marginDelta: _marginDelta,
            sizeDelta: _sizeDelta,
            targetPrice: _targetPrice,
            gelatoTaskId: taskId,
            conditionalOrderType: _conditionalOrderType,
            priceImpactDelta: _priceImpactDelta,
            reduceOnly: _reduceOnly
        });

        events.emitConditionalOrderPlaced({
            account: address(this),
            conditionalOrderId: conditionalOrderId,
            marketKey: _marketKey,
            marginDelta: _marginDelta,
            sizeDelta: _sizeDelta,
            targetPrice: _targetPrice,
            conditionalOrderType: _conditionalOrderType,
            priceImpactDelta: _priceImpactDelta,
            reduceOnly: _reduceOnly
        });

        conditionalOrderId++;
    }

    /// @notice create a new Gelato task for a conditional order
    /// @return taskId of the new Gelato task
    function _createGelatoTask() internal returns (bytes32 taskId) {
        IOps.ModuleData memory moduleData = _createGelatoModuleData();

        taskId = IOps(OPS).createTask({
            execAddress: address(this),
            execData: abi.encodeCall(this.executeConditionalOrder, conditionalOrderId),
            moduleData: moduleData,
            feeToken: ETH
        });
    }

    /// @notice create the Gelato ModuleData for a conditional order
    /// @dev see IOps for details on the task creation and the ModuleData struct
    function _createGelatoModuleData() internal view returns (IOps.ModuleData memory moduleData) {
        moduleData = IOps.ModuleData({
            modules: new IOps.Module[](2),
            args: new bytes[](2)
        });

        moduleData.modules[0] = IOps.Module.RESOLVER;
        moduleData.modules[1] = IOps.Module.SINGLE_EXEC;

        moduleData.args[0] = abi.encode(
            address(this),
            abi.encodeCall(this.checker, conditionalOrderId)
        );
        // moduleData.args[1] is empty for single exec thus no need to encode
    }

    /// @notice cancel a gelato queued conditional order
    /// @param _conditionalOrderId: key for an active conditional order
    function _cancelConditionalOrder(uint256 _conditionalOrderId) internal {
        ConditionalOrder memory conditionalOrder = getConditionalOrder(_conditionalOrderId);

        // if margin was committed, free it
        if (conditionalOrder.marginDelta > 0) {
            committedMargin -= _abs(conditionalOrder.marginDelta);
        }

        // cancel gelato task
        /// @dev will revert if task id does not exist {Ops.cancelTask: Task not found}
        IOps(OPS).cancelTask({taskId: conditionalOrder.gelatoTaskId});

        // delete order from conditional orders
        delete conditionalOrders[_conditionalOrderId];

        events.emitConditionalOrderCancelled({
            account: address(this),
            conditionalOrderId: _conditionalOrderId,
            reason: ConditionalOrderCancelledReason.CONDITIONAL_ORDER_CANCELLED_BY_USER
        });
    }

    /*//////////////////////////////////////////////////////////////
                   GELATO CONDITIONAL ORDER HANDLING
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAccount
    function executeConditionalOrder(uint256 _conditionalOrderId) external override onlyOps {
        (bool isValidConditionalOrder, uint256 fillPrice) =
            _validConditionalOrder(_conditionalOrderId);

        // Account.checker() will prevent this from being called if the conditional order is not valid
        /// @dev this is a safety check; never intended to fail
        assert(isValidConditionalOrder);

        ConditionalOrder memory conditionalOrder = getConditionalOrder(_conditionalOrderId);
        address market = address(_getPerpsV2Market(conditionalOrder.marketKey));

        // if conditional order is reduce only, ensure position size is only reduced
        if (conditionalOrder.reduceOnly) {
            int256 currentSize = _getPerpsV2Market(conditionalOrder.marketKey).positions({
                account: address(this)
            }).size;

            // ensure position exists and incoming size delta is NOT the same sign
            /// @dev if incoming size delta is the same sign, then the conditional order is not reduce only
            if (currentSize == 0 || _isSameSign(currentSize, conditionalOrder.sizeDelta)) {
                // delete conditional order from conditional orders
                delete conditionalOrders[_conditionalOrderId];

                events.emitConditionalOrderCancelled({
                    account: address(this),
                    conditionalOrderId: _conditionalOrderId,
                    reason: ConditionalOrderCancelledReason.CONDITIONAL_ORDER_CANCELLED_NOT_REDUCE_ONLY
                });

                return;
            }

            // ensure incoming size delta is not larger than current position size
            /// @dev reduce only conditional orders can only reduce position size (i.e. approach size of zero) and
            /// cannot cross that boundary (i.e. short -> long or long -> short)
            if (_abs(conditionalOrder.sizeDelta) > _abs(currentSize)) {
                // bound conditional order size delta to current position size
                conditionalOrder.sizeDelta = -currentSize;
            }
        }

        // if margin was committed, free it
        if (conditionalOrder.marginDelta > 0) {
            committedMargin -= _abs(conditionalOrder.marginDelta);
        }

        // delete conditional order from conditional orders
        delete conditionalOrders[_conditionalOrderId];

        // calculate conditional order fee imposed by Kwenta
        uint256 conditionalOrderFee = conditionalOrder.conditionalOrderType
            == ConditionalOrderTypes.LIMIT ? settings.limitOrderFee() : settings.stopOrderFee();

        // execute trade
        _perpsV2ModifyMargin({_market: market, _amount: conditionalOrder.marginDelta});
        _perpsV2SubmitOffchainDelayedOrder({
            _market: market,
            _sizeDelta: conditionalOrder.sizeDelta,
            _priceImpactDelta: conditionalOrder.priceImpactDelta
        });

        // pay Gelato imposed fee for conditional order execution
        (uint256 fee, address feeToken) = IOps(OPS).getFeeDetails();
        _transfer({_amount: fee, _paymentToken: feeToken});

        // pay Kwenta imposed fee for conditional order execution
        _imposeFee(
            _calculateTradeFee({
                _sizeDelta: conditionalOrder.sizeDelta,
                _market: IPerpsV2MarketConsolidated(market),
                _conditionalOrderFee: conditionalOrderFee
            })
        );

        events.emitConditionalOrderFilled({
            account: address(this),
            conditionalOrderId: _conditionalOrderId,
            fillPrice: fillPrice,
            keeperFee: fee
        });
    }

    /// @notice order logic condition checker
    /// @dev this is where order type logic checks are handled
    /// @param _conditionalOrderId: key for an active order
    /// @return true if conditional order is valid by execution rules
    /// @return price that the order will be filled at (only valid if prev is true)
    function _validConditionalOrder(uint256 _conditionalOrderId)
        internal
        view
        returns (bool, uint256)
    {
        ConditionalOrder memory conditionalOrder = getConditionalOrder(_conditionalOrderId);

        // check if markets satisfy specific order type
        if (conditionalOrder.conditionalOrderType == ConditionalOrderTypes.LIMIT) {
            return _validLimitOrder(conditionalOrder);
        } else if (conditionalOrder.conditionalOrderType == ConditionalOrderTypes.STOP) {
            return _validStopOrder(conditionalOrder);
        } else {
            // unknown order type
            return (false, 0);
        }
    }

    /// @notice limit order logic condition checker
    /// @dev sizeDelta will never be zero due to check when submitting conditional order
    /// @param _conditionalOrder: struct for an active conditional order
    /// @return true if conditional order is valid by execution rules
    /// @return price that the conditional order will be submitted
    function _validLimitOrder(ConditionalOrder memory _conditionalOrder)
        internal
        view
        returns (bool, uint256)
    {
        /// @dev is marketKey is invalid, this will revert
        uint256 price = _sUSDRate(_getPerpsV2Market(_conditionalOrder.marketKey));

        if (_conditionalOrder.sizeDelta > 0) {
            // Long: increase position size (buy) once *below* target price
            // ex: open long position once price is below target
            return (price <= _conditionalOrder.targetPrice, price);
        } else {
            // Short: decrease position size (sell) once *above* target price
            // ex: open short position once price is above target
            return (price >= _conditionalOrder.targetPrice, price);
        }
    }

    /// @notice stop order logic condition checker
    /// @dev sizeDelta will never be zero due to check when submitting order
    /// @param _conditionalOrder: struct for an active conditional order
    /// @return true if conditional order is valid by execution rules
    /// @return price that the conditional order will be submitted
    function _validStopOrder(ConditionalOrder memory _conditionalOrder)
        internal
        view
        returns (bool, uint256)
    {
        /// @dev is marketKey is invalid, this will revert
        uint256 price = _sUSDRate(_getPerpsV2Market(_conditionalOrder.marketKey));

        if (_conditionalOrder.sizeDelta > 0) {
            // Long: increase position size (buy) once *above* target price
            // ex: unwind short position once price is above target (prevent further loss)
            return (price >= _conditionalOrder.targetPrice, price);
        } else {
            // Short: decrease position size (sell) once *below* target price
            // ex: unwind long position once price is below target (prevent further loss)
            return (price <= _conditionalOrder.targetPrice, price);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             FEE UTILITIES
    //////////////////////////////////////////////////////////////*/

    /// @notice calculate fee based on both size and given market
    /// @param _sizeDelta: size delta of given trade
    /// @param _market: Synthetix PerpsV2 Market
    /// @param _conditionalOrderFee: additional fee charged for conditional orders
    /// @return fee to be imposed based on size delta
    function _calculateTradeFee(
        int256 _sizeDelta,
        IPerpsV2MarketConsolidated _market,
        uint256 _conditionalOrderFee
    ) internal view returns (uint256 fee) {
        fee = (_abs(_sizeDelta) * (settings.tradeFee() + _conditionalOrderFee)) / settings.MAX_BPS();

        /// @notice fee is currently measured in the underlying base asset of the market
        /// @dev fee will be measured in sUSD, thus exchange rate is needed
        fee = (_sUSDRate(_market) * fee) / 1e18;
    }

    /// @notice impose fee on account
    /// @param _fee: fee to impose
    function _imposeFee(uint256 _fee) internal {
        /// @dev send fee to Kwenta's treasury
        if (_fee > freeMargin()) {
            // fee canot be greater than available margin
            revert CannotPayFee();
        } else {
            // attempt to transfer margin asset from user to Kwenta's treasury
            bool success = MARGIN_ASSET.transfer(settings.treasury(), _fee);
            if (!success) revert FailedMarginTransfer();

            events.emitFeeImposed({account: address(this), amount: _fee});
        }
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER UTILITIES
    //////////////////////////////////////////////////////////////*/

    /// @notice fetch PerpsV2Market market defined by market key
    /// @param _marketKey: key for Synthetix PerpsV2 market
    /// @return IPerpsV2Market contract interface
    function _getPerpsV2Market(bytes32 _marketKey)
        internal
        view
        returns (IPerpsV2MarketConsolidated)
    {
        return IPerpsV2MarketConsolidated(futuresMarketManager.marketForKey(_marketKey));
    }

    /// @notice get exchange rate of underlying market asset in terms of sUSD
    /// @param _market: Synthetix PerpsV2 Market
    /// @return price in sUSD
    function _sUSDRate(IPerpsV2MarketConsolidated _market) internal view returns (uint256) {
        (uint256 price, bool invalid) = _market.assetPrice();
        if (invalid) {
            revert InvalidPrice();
        }
        return price;
    }

    /*//////////////////////////////////////////////////////////////
                             MATH UTILITIES
    //////////////////////////////////////////////////////////////*/

    /// @notice get absolute value of the input, returned as an unsigned number.
    /// @param x: signed number
    /// @return z uint256 absolute value of x
    function _abs(int256 x) internal pure returns (uint256 z) {
        assembly {
            let mask := sub(0, shr(255, x))
            z := xor(mask, add(mask, x))
        }
    }

    /// @notice determines if input numbers have the same sign
    /// @dev asserts that both numbers are not zero
    /// @param x: signed number
    /// @param y: signed number
    /// @return true if same sign, false otherwise
    function _isSameSign(int256 x, int256 y) internal pure returns (bool) {
        assert(x != 0 && y != 0);
        return (x ^ y) >= 0;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import {IAddressResolver} from "@synthetix/IAddressResolver.sol";
import {IEvents} from "./IEvents.sol";
import {IExchanger} from "@synthetix/IExchanger.sol";
import {IFactory} from "./IFactory.sol";
import {IFuturesMarketManager} from "@synthetix/IFuturesMarketManager.sol";
import {IPerpsV2MarketConsolidated} from "@synthetix/IPerpsV2MarketConsolidated.sol";
import {ISettings} from "./ISettings.sol";

/// @title Kwenta Smart Margin Account Implementation Interface
/// @author JaredBorders ([email protected]), JChiaramonte7 ([email protected])
interface IAccount {
    /*///////////////////////////////////////////////////////////////
                                Types
    ///////////////////////////////////////////////////////////////*/

    /// @notice Command Flags used to decode commands to execute
    /// @dev under the hood PERPS_V2_MODIFY_MARGIN = 0, PERPS_V2_WITHDRAW_ALL_MARGIN = 1
    enum Command {
        ACCOUNT_MODIFY_MARGIN,
        ACCOUNT_WITHDRAW_ETH,
        PERPS_V2_MODIFY_MARGIN,
        PERPS_V2_WITHDRAW_ALL_MARGIN,
        PERPS_V2_SUBMIT_ATOMIC_ORDER,
        PERPS_V2_SUBMIT_DELAYED_ORDER,
        PERPS_V2_SUBMIT_OFFCHAIN_DELAYED_ORDER,
        PERPS_V2_CANCEL_DELAYED_ORDER,
        PERPS_V2_CANCEL_OFFCHAIN_DELAYED_ORDER,
        PERPS_V2_CLOSE_POSITION,
        GELATO_PLACE_CONDITIONAL_ORDER,
        GELATO_CANCEL_CONDITIONAL_ORDER
    }

    /// @notice denotes conditional order types for code clarity
    /// @dev under the hood LIMIT = 0, STOP = 1
    enum ConditionalOrderTypes {
        LIMIT,
        STOP
    }

    /// @notice denotes conditional order cancelled reasons for code clarity
    /// @dev under the hood CONDITIONAL_ORDER_CANCELLED_BY_USER = 0, CONDITIONAL_ORDER_CANCELLED_NOT_REDUCE_ONLY = 1
    enum ConditionalOrderCancelledReason {
        CONDITIONAL_ORDER_CANCELLED_BY_USER,
        CONDITIONAL_ORDER_CANCELLED_NOT_REDUCE_ONLY
    }

    /// marketKey: Synthetix PerpsV2 Market id/key
    /// marginDelta: amount of margin to deposit or withdraw; positive indicates deposit, negative withdraw
    /// sizeDelta: denoted in market currency (i.e. ETH, BTC, etc), size of Synthetix PerpsV2 position
    /// targetPrice: limit or stop price to fill at
    /// gelatoTaskId: unqiue taskId from gelato necessary for cancelling conditional orders
    /// conditionalOrderType: conditional order type to determine conditional order fill logic
    /// priceImpactDelta: price impact tolerance as a percentage used on fillPrice at execution
    /// reduceOnly: if true, only allows position's absolute size to decrease
    struct ConditionalOrder {
        bytes32 marketKey;
        int256 marginDelta;
        int256 sizeDelta;
        uint256 targetPrice;
        bytes32 gelatoTaskId;
        ConditionalOrderTypes conditionalOrderType;
        uint128 priceImpactDelta;
        bool reduceOnly;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice thrown when commands length does not equal inputs length
    error LengthMismatch();

    /// @notice thrown when Command given is not valid
    error InvalidCommandType(uint256 commandType);

    /// @notice thrown when margin asset transfer fails
    error FailedMarginTransfer();

    /// @notice given value cannot be zero
    /// @param valueName: name of the variable that cannot be zero
    error ValueCannotBeZero(bytes32 valueName);

    /// @notice exceeds useable margin
    /// @param available: amount of useable margin asset
    /// @param required: amount of margin asset required
    error InsufficientFreeMargin(uint256 available, uint256 required);

    /// @notice call to transfer ETH on withdrawal fails
    error EthWithdrawalFailed();

    /// @notice base price from the oracle was invalid
    /// @dev Rate can be invalid either due to:
    ///     1. Returned as invalid from ExchangeRates - due to being stale or flagged by oracle
    ///     2. Out of deviation bounds w.r.t. to previously stored rate
    ///     3. if there is no valid stored rate, w.r.t. to previous 3 oracle rates
    ///     4. Price is zero
    error InvalidPrice();

    /// @notice Insufficient margin to pay fee
    error CannotPayFee();

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice returns the version of the Account
    function VERSION() external view returns (bytes32);

    /// @return returns the address of the factory
    function factory() external view returns (IFactory);

    /// @return returns the address of the futures market manager
    function futuresMarketManager() external view returns (IFuturesMarketManager);

    /// @return returns the address of the native settings for account
    function settings() external view returns (ISettings);

    /// @return returns the address of events contract for accounts
    function events() external view returns (IEvents);

    /// @return returns the amount of margin locked for future events (i.e. conditional orders)
    function committedMargin() external view returns (uint256);

    /// @return returns current conditional order id
    function conditionalOrderId() external view returns (uint256);

    /// @notice get delayed order data from Synthetix PerpsV2
    /// @dev call reverts if _marketKey is invalid
    /// @param _marketKey: key for Synthetix PerpsV2 Market
    /// @return delayed order struct defining delayed order (will return empty struct if no delayed order exists)
    function getDelayedOrder(bytes32 _marketKey)
        external
        returns (IPerpsV2MarketConsolidated.DelayedOrder memory);

    /// @notice checker() is the Resolver for Gelato
    /// (see https://docs.gelato.network/developer-services/automate/guides/custom-logic-triggers/smart-contract-resolvers)
    /// @notice signal to a keeper that a conditional order is valid/invalid for execution
    /// @dev call reverts if conditional order Id does not map to a valid conditional order;
    /// ConditionalOrder.marketKey would be invalid
    /// @param _conditionalOrderId: key for an active conditional order
    /// @return canExec boolean that signals to keeper a conditional order can be executed by Gelato
    /// @return execPayload calldata for executing a conditional order
    function checker(uint256 _conditionalOrderId)
        external
        view
        returns (bool canExec, bytes memory execPayload);

    /// @notice the current withdrawable or usable balance
    /// @return free margin amount
    function freeMargin() external view returns (uint256);

    /// @notice get up-to-date position data from Synthetix PerpsV2
    /// @param _marketKey: key for Synthetix PerpsV2 Market
    /// @return position struct defining current position
    function getPosition(bytes32 _marketKey)
        external
        returns (IPerpsV2MarketConsolidated.Position memory);

    /// @notice conditional order id mapped to conditional order
    /// @param _conditionalOrderId: id of conditional order
    /// @return conditional order
    function getConditionalOrder(uint256 _conditionalOrderId)
        external
        view
        returns (ConditionalOrder memory);

    /*//////////////////////////////////////////////////////////////
                                MUTATIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice executes commands along with provided inputs
    /// @param _commands: array of commands, each represented as an enum
    /// @param _inputs: array of byte strings containing abi encoded inputs for each command
    function execute(Command[] calldata _commands, bytes[] calldata _inputs) external payable;

    /// @notice execute a gelato queued conditional order
    /// @notice only keepers can trigger this function
    /// @dev currently only supports conditional order submission via PERPS_V2_SUBMIT_OFFCHAIN_DELAYED_ORDER COMMAND
    /// @param _conditionalOrderId: key for an active conditional order
    function executeConditionalOrder(uint256 _conditionalOrderId) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import {IAccount} from "./IAccount.sol";

/// @title Interface for contract that emits all events emitted by the Smart Margin Accounts
/// @author JaredBorders ([email protected])
interface IEvents {
    /// @notice emitted after a successful withdrawal
    /// @param user: the address that withdrew from account
    /// @param account: the account that was withdrawn from
    /// @param amount: amount of marginAsset to withdraw from account
    function emitDeposit(address user, address account, uint256 amount) external;

    // @inheritdoc IAccount
    event Deposit(address indexed user, address indexed account, uint256 amount);

    /// @notice emitted after a successful withdrawal
    /// @param user: the address that withdrew from account
    /// @param account: the account that was withdrawn from
    /// @param amount: amount of marginAsset to withdraw from account
    function emitWithdraw(address user, address account, uint256 amount) external;

    // @inheritdoc IAccount
    event Withdraw(address indexed user, address indexed account, uint256 amount);

    /// @notice emitted after a successful ETH withdrawal
    /// @param user: the address that withdrew from account
    /// @param amount: the account that was withdrawn from
    /// @param amount: amount of ETH to withdraw from account
    function emitEthWithdraw(address user, address account, uint256 amount) external;

    // @inheritdoc IAccount
    event EthWithdraw(address indexed user, address indexed account, uint256 amount);

    /// @notice emitted when a conditional order is placed
    /// @param account: account placing the conditional order
    /// @param conditionalOrderId: id of conditional order
    /// @param marketKey: Synthetix PerpsV2 market key
    /// @param marginDelta: margin change
    /// @param sizeDelta: size change
    /// @param targetPrice: targeted fill price
    /// @param conditionalOrderType: expected conditional order type enum where 0 = LIMIT, 1 = STOP, etc..
    /// @param priceImpactDelta: price impact tolerance as a percentage
    /// @param reduceOnly: if true, only allows position's absolute size to decrease
    function emitConditionalOrderPlaced(
        address account,
        uint256 conditionalOrderId,
        bytes32 marketKey,
        int256 marginDelta,
        int256 sizeDelta,
        uint256 targetPrice,
        IAccount.ConditionalOrderTypes conditionalOrderType,
        uint128 priceImpactDelta,
        bool reduceOnly
    ) external;

    // @inheritdoc IAccount
    event ConditionalOrderPlaced(
        address indexed account,
        uint256 conditionalOrderId,
        bytes32 marketKey,
        int256 marginDelta,
        int256 sizeDelta,
        uint256 targetPrice,
        IAccount.ConditionalOrderTypes conditionalOrderType,
        uint128 priceImpactDelta,
        bool reduceOnly
    );

    /// @notice emitted when a conditional order is cancelled
    /// @param account: account cancelling the conditional order
    /// @param conditionalOrderId: id of conditional order
    /// @param reason: reason for cancellation
    function emitConditionalOrderCancelled(
        address account,
        uint256 conditionalOrderId,
        IAccount.ConditionalOrderCancelledReason reason
    ) external;

    // @inheritdoc IAccount
    event ConditionalOrderCancelled(
        address indexed account,
        uint256 conditionalOrderId,
        IAccount.ConditionalOrderCancelledReason reason
    );

    /// @notice emitted when a conditional order is filled
    /// @param account: account that placed the conditional order
    /// @param conditionalOrderId: id of conditional order
    /// @param fillPrice: price the conditional order was executed at
    /// @param keeperFee: fees paid to the executor
    function emitConditionalOrderFilled(
        address account,
        uint256 conditionalOrderId,
        uint256 fillPrice,
        uint256 keeperFee
    ) external;

    // @inheritdoc IAccount
    event ConditionalOrderFilled(
        address indexed account, uint256 conditionalOrderId, uint256 fillPrice, uint256 keeperFee
    );

    /// @notice emitted after a fee has been transferred to Treasury
    /// @param account: the address of the account the fee was imposed on
    /// @param amount: fee amount sent to Treasury
    function emitFeeImposed(address account, uint256 amount) external;

    // @inheritdoc IAccount
    event FeeImposed(address indexed account, uint256 amount);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

/// @title Kwenta Factory Interface
/// @author JaredBorders ([email protected])
interface IFactory {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted when new account is created
    /// @param creator: account creator (address that called newAccount())
    /// @param account: address of account that was created (will be address of proxy)
    event NewAccount(address indexed creator, address indexed account, bytes32 version);

    /// @notice emitted when implementation is upgraded
    /// @param implementation: address of new implementation
    event AccountImplementationUpgraded(address implementation);

    /// @notice emitted when settings contract is upgraded
    /// @param settings: address of new settings contract
    event SettingsUpgraded(address settings);

    /// @notice emitted when events contract is upgraded
    /// @param events: address of new events contract
    event EventsUpgraded(address events);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice thrown when newAccount() is called
    /// by an address which has already made an account
    /// @param account: address of account previously created
    error OnlyOneAccountPerAddress(address account);

    /// @notice thrown when Account creation fails at initialization step
    /// @param data: data returned from failed low-level call
    error AccountFailedToInitialize(bytes data);

    /// @notice thrown when Account creation fails due to no version being set
    /// @param data: data returned from failed low-level call
    error AccountFailedToFetchVersion(bytes data);

    /// @notice thrown when factory is not upgradable
    error CannotUpgrade();

    /// @notice thrown account owner is unrecognized via ownerToAccount mapping
    error AccountDoesNotExist();

    /// @notice thrown when caller is not an account
    error CallerMustBeAccount();

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @return canUpgrade: bool to determine if factory can be upgraded
    function canUpgrade() external view returns (bool);

    /// @return logic: account logic address
    function implementation() external view returns (address);

    /// @return settings: address of settings contract for accounts
    function settings() external view returns (address);

    /// @return events: address of events contract for accounts
    function events() external view returns (address);

    /// @return address of account owned by _owner
    /// @param _owner: owner of account
    function ownerToAccount(address _owner) external view returns (address);

    /*//////////////////////////////////////////////////////////////
                                MUTATIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice create unique account proxy for function caller
    /// @return accountAddress address of account created
    function newAccount() external returns (address payable accountAddress);

    /// @notice update account owner
    /// @param _oldOwner: old owner of account
    /// @param _newOwner: new owner of account
    function updateAccountOwner(address _oldOwner, address _newOwner) external;

    /*//////////////////////////////////////////////////////////////
                             UPGRADABILITY
    //////////////////////////////////////////////////////////////*/

    /// @notice upgrade implementation of account which all account proxies currently point to
    /// @dev this *will* impact all existing accounts
    /// @dev future accounts will also point to this new implementation (until
    /// upgradeAccountImplementation() is called again with a newer implementation)
    /// @dev *DANGER* this function does not check the new implementation for validity,
    /// thus, a bad upgrade could result in severe consequences.
    /// @param _implementation: address of new implementation
    function upgradeAccountImplementation(address _implementation) external;

    /// @dev upgrade settings contract for all future accounts; existing accounts will not be affected
    /// and will point to settings address they were initially deployed with
    /// @param _settings: address of new settings contract
    function upgradeSettings(address _settings) external;

    /// @dev upgrade events contract for all future accounts; existing accounts will not be affected
    /// and will point to events address they were initially deployed with
    /// @param _events: address of new events contract
    function upgradeEvents(address _events) external;

    /// @notice remove upgradability from factory
    /// @dev cannot be undone
    function removeUpgradability() external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

interface IOps {
    /**
     * @notice Whitelisted modules that are available for users to customise conditions and specifications of their tasks.
     *
     * @param RESOLVER Use dynamic condition & input data for execution. {See ResolverModule.sol}
     * @param TIME Repeated execution of task at a specified timing and interval. {See TimeModule.sol}
     * @param PROXY Creates a dedicated caller (msg.sender) to be used when executing the task. {See ProxyModule.sol}
     * @param SINGLE_EXEC Task is cancelled after one execution. {See SingleExecModule.sol}
     */
    enum Module {
        RESOLVER,
        TIME,
        PROXY,
        SINGLE_EXEC
    }

    /**
     * @notice Struct to contain modules and their relative arguments that are used for task creation.
     *
     * @param modules List of selected modules.
     * @param args Arguments of modules if any. Pass "0x" for modules which does not require args {See encodeModuleArg}
     */
    struct ModuleData {
        Module[] modules;
        bytes[] args;
    }

    /**
     * @notice Struct for time module.
     *
     * @param nextExec Time when the next execution should occur.
     * @param interval Time interval between each execution.
     */
    struct Time {
        uint128 nextExec;
        uint128 interval;
    }

    /**
     * @notice Initiates a task with conditions which Gelato will monitor and execute when conditions are met.
     *
     * @param execAddress Address of contract that should be called by Gelato.
     * @param execData Execution data to be called with / function selector if execution data is yet to be determined.
     * @param moduleData Conditional modules that will be used.
     * @param feeToken Address of token to be used as payment. Use address(0) if TaskTreasury is being used, 0xeeeeee... for ETH or native tokens.
     *
     * @return taskId Unique hash of the task created.
     */
    function createTask(
        address execAddress,
        bytes calldata execData,
        ModuleData calldata moduleData,
        address feeToken
    ) external returns (bytes32 taskId);

    /**
     * @notice Terminates a task that was created and Gelato can no longer execute it.
     *
     * @param taskId Unique hash of the task that is being cancelled. {See LibTaskId-getTaskId}
     */
    function cancelTask(bytes32 taskId) external;

    /**
     * @notice Execution API called by Gelato.
     *
     * @param taskCreator The address which created the task.
     * @param execAddress Address of contract that should be called by Gelato.
     * @param execData Execution data to be called with / function selector if execution data is yet to be determined.
     * @param moduleData Conditional modules that will be used.
     * @param txFee Fee paid to Gelato for execution, deducted on the TaskTreasury or transfered to Gelato.
     * @param feeToken Token used to pay for the execution. ETH = 0xeeeeee...
     * @param useTaskTreasuryFunds If taskCreator's balance on TaskTreasury should pay for the tx.
     * @param revertOnFailure To revert or not if call to execAddress fails. (Used for off-chain simulations)
     */
    function exec(
        address taskCreator,
        address execAddress,
        bytes memory execData,
        ModuleData calldata moduleData,
        uint256 txFee,
        address feeToken,
        bool useTaskTreasuryFunds,
        bool revertOnFailure
    ) external;

    /**
     * @notice Sets the address of task modules. Only callable by proxy admin.
     *
     * @param modules List of modules to be set
     * @param moduleAddresses List of addresses for respective modules.
     */
    function setModule(Module[] calldata modules, address[] calldata moduleAddresses) external;

    /**
     * @notice Helper function to query fee and feeToken to be used for payment. (For executions which pays itself)
     *
     * @return uint256 Fee amount to be paid.
     * @return address Token to be paid. (Determined and passed by taskCreator during createTask)
     */
    function getFeeDetails() external view returns (uint256, address);

    /**
     * @notice Helper func to query all open tasks by a task creator.
     *
     * @param taskCreator Address of task creator to query.
     *
     * @return bytes32[] List of taskIds created.
     */
    function getTaskIdsByUser(address taskCreator) external view returns (bytes32[] memory);

    /**
     * @notice Helper function to compute task id with module arguments
     *
     * @param taskCreator The address which created the task.
     * @param execAddress Address of contract that will be called by Gelato.
     * @param execSelector Signature of the function which will be called by Gelato.
     * @param moduleData  Conditional modules that will be used. {See LibDataTypes-ModuleData}
     * @param feeToken Address of token to be used as payment. Use address(0) if TaskTreasury is being used, 0xeeeeee... for ETH or native tokens.
     */
    function getTaskId(
        address taskCreator,
        address execAddress,
        bytes4 execSelector,
        ModuleData memory moduleData,
        address feeToken
    ) external pure returns (bytes32 taskId);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

/// @title Kwenta Settings Interface
/// @author JaredBorders ([email protected])
/// @dev all fees are denoted in Basis points (BPS)
interface ISettings {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted after changing treasury address
    /// @param treasury: new treasury address
    event TreasuryAddressChanged(address treasury);

    /// @notice emitted after a successful trade fee change
    /// @param fee: fee denoted in BPS
    event TradeFeeChanged(uint256 fee);

    /// @notice emitted after a successful limit order fee change
    /// @param fee: fee denoted in BPS
    event LimitOrderFeeChanged(uint256 fee);

    /// @notice emitted after a successful stop loss fee change
    /// @param fee: fee denoted in BPS
    event StopOrderFeeChanged(uint256 fee);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice zero address cannot be used
    error ZeroAddress();

    /// @notice new treasury address cannot be the same as the old treasury address
    error DuplicateAddress();

    /// @notice invalid fee (fee > MAX_BPS)
    /// @param fee: fee denoted in BPS
    error InvalidFee(uint256 fee);

    /// @notice new fee cannot be the same as the old fee
    error DuplicateFee();

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @return max BPS; used for decimals calculations
    // solhint-disable-next-line func-name-mixedcase
    function MAX_BPS() external view returns (uint256);

    // @return Kwenta's Treasury Address
    function treasury() external view returns (address);

    /// @return fee imposed on all trades
    function tradeFee() external view returns (uint256);

    /// @return fee imposed on limit orders
    function limitOrderFee() external view returns (uint256);

    /// @return fee imposed on stop losses
    function stopOrderFee() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                                MUTATIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice set new treasury address
    /// @param _treasury: new treasury address
    function setTreasury(address _treasury) external;

    /// @notice set new trade fee
    /// @param _fee: fee imposed on all trades
    function setTradeFee(uint256 _fee) external;

    /// @notice set new limit order fee
    /// @param _fee: fee imposed on limit orders
    function setLimitOrderFee(uint256 _fee) external;

    /// @notice set new stop loss fee
    /// @param _fee: fee imposed on stop losses
    function setStopOrderFee(uint256 _fee) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

// https://docs.synthetix.io/contracts/source/interfaces/iaddressresolver
interface IAddressResolver {
    function getAddress(bytes32 name) external view returns (address);

    function getSynth(bytes32 key) external view returns (address);

    function requireAndGetAddress(bytes32 name, string calldata reason)
        external
        view
        returns (address);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

pragma experimental ABIEncoderV2;

import "./IVirtualSynth.sol";

// https://docs.synthetix.io/contracts/source/interfaces/iexchanger
interface IExchanger {
    struct ExchangeEntrySettlement {
        bytes32 src;
        uint256 amount;
        bytes32 dest;
        uint256 reclaim;
        uint256 rebate;
        uint256 srcRoundIdAtPeriodEnd;
        uint256 destRoundIdAtPeriodEnd;
        uint256 timestamp;
    }

    struct ExchangeEntry {
        uint256 sourceRate;
        uint256 destinationRate;
        uint256 destinationAmount;
        uint256 exchangeFeeRate;
        uint256 exchangeDynamicFeeRate;
        uint256 roundIdForSrc;
        uint256 roundIdForDest;
        uint256 sourceAmountAfterSettlement;
    }

    // Views
    function calculateAmountAfterSettlement(
        address from,
        bytes32 currencyKey,
        uint256 amount,
        uint256 refunded
    ) external view returns (uint256 amountAfterSettlement);

    function isSynthRateInvalid(bytes32 currencyKey) external view returns (bool);

    function maxSecsLeftInWaitingPeriod(address account, bytes32 currencyKey)
        external
        view
        returns (uint256);

    function settlementOwing(address account, bytes32 currencyKey)
        external
        view
        returns (uint256 reclaimAmount, uint256 rebateAmount, uint256 numEntries);

    function hasWaitingPeriodOrSettlementOwing(address account, bytes32 currencyKey)
        external
        view
        returns (bool);

    function feeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey)
        external
        view
        returns (uint256);

    function dynamicFeeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey)
        external
        view
        returns (uint256 feeRate, bool tooVolatile);

    function getAmountsForExchange(
        uint256 sourceAmount,
        bytes32 sourceCurrencyKey,
        bytes32 destinationCurrencyKey
    ) external view returns (uint256 amountReceived, uint256 fee, uint256 exchangeFeeRate);

    function priceDeviationThresholdFactor() external view returns (uint256);

    function waitingPeriodSecs() external view returns (uint256);

    function lastExchangeRate(bytes32 currencyKey) external view returns (uint256);

    // Mutative functions
    function exchange(
        address exchangeForAddress,
        address from,
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey,
        address destinationAddress,
        bool virtualSynth,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint256 amountReceived, IVirtualSynth vSynth);

    function exchangeAtomically(
        address from,
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey,
        address destinationAddress,
        bytes32 trackingCode,
        uint256 minAmount
    ) external returns (uint256 amountReceived);

    function settle(address from, bytes32 currencyKey)
        external
        returns (uint256 reclaimed, uint256 refunded, uint256 numEntries);
}

// Used to have strongly-typed access to internal mutative functions in Synthetix
interface ISynthetixInternal {
    function emitExchangeTracking(
        bytes32 trackingCode,
        bytes32 toCurrencyKey,
        uint256 toAmount,
        uint256 fee
    ) external;

    function emitSynthExchange(
        address account,
        bytes32 fromCurrencyKey,
        uint256 fromAmount,
        bytes32 toCurrencyKey,
        uint256 toAmount,
        address toAddress
    ) external;

    function emitAtomicSynthExchange(
        address account,
        bytes32 fromCurrencyKey,
        uint256 fromAmount,
        bytes32 toCurrencyKey,
        uint256 toAmount,
        address toAddress
    ) external;

    function emitExchangeReclaim(address account, bytes32 currencyKey, uint256 amount) external;

    function emitExchangeRebate(address account, bytes32 currencyKey, uint256 amount) external;
}

interface IExchangerInternalDebtCache {
    function updateCachedSynthDebtsWithRates(
        bytes32[] calldata currencyKeys,
        uint256[] calldata currencyRates
    ) external;

    function updateCachedSynthDebts(bytes32[] calldata currencyKeys) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

interface IFuturesMarketManager {
    function markets(uint256 index, uint256 pageSize) external view returns (address[] memory);

    function markets(uint256 index, uint256 pageSize, bool proxiedMarkets)
        external
        view
        returns (address[] memory);

    function numMarkets() external view returns (uint256);

    function numMarkets(bool proxiedMarkets) external view returns (uint256);

    function allMarkets() external view returns (address[] memory);

    function allMarkets(bool proxiedMarkets) external view returns (address[] memory);

    function marketForKey(bytes32 marketKey) external view returns (address);

    function marketsForKeys(bytes32[] calldata marketKeys)
        external
        view
        returns (address[] memory);

    function totalDebt() external view returns (uint256 debt, bool isInvalid);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

interface IPerpsV2MarketBaseTypes {
    /* ========== TYPES ========== */

    enum OrderType {
        Atomic,
        Delayed,
        Offchain
    }

    enum Status {
        Ok,
        InvalidPrice,
        InvalidOrderType,
        PriceOutOfBounds,
        CanLiquidate,
        CannotLiquidate,
        MaxMarketSizeExceeded,
        MaxLeverageExceeded,
        InsufficientMargin,
        NotPermitted,
        NilOrder,
        NoPositionOpen,
        PriceTooVolatile,
        PriceImpactToleranceExceeded
    }

    // If margin/size are positive, the position is long; if negative then it is short.
    struct Position {
        uint64 id;
        uint64 lastFundingIndex;
        uint128 margin;
        uint128 lastPrice;
        int128 size;
    }

    // Delayed order storage
    struct DelayedOrder {
        bool isOffchain; // flag indicating the delayed order is offchain
        int128 sizeDelta; // difference in position to pass to modifyPosition
        uint128 priceImpactDelta; // price impact tolerance as a percentage used on fillPrice at execution
        uint128 targetRoundId; // price oracle roundId using which price this order needs to executed
        uint128 commitDeposit; // the commitDeposit paid upon submitting that needs to be refunded if order succeeds
        uint128 keeperDeposit; // the keeperDeposit paid upon submitting that needs to be paid / refunded on tx confirmation
        uint256 executableAtTime; // The timestamp at which this order is executable at
        uint256 intentionTime; // The block timestamp of submission
        bytes32 trackingCode; // tracking code to emit on execution for volume source fee sharing
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import "./IPerpsV2MarketBaseTypes.sol";

pragma experimental ABIEncoderV2;

// Helper Interface, only used in tests and to provide a consolidated interface to PerpsV2 users/integrators

interface IPerpsV2MarketConsolidated {
    /* ========== TYPES ========== */
    enum OrderType {
        Atomic,
        Delayed,
        Offchain
    }

    enum Status {
        Ok,
        InvalidPrice,
        InvalidOrderPrice,
        PriceOutOfBounds,
        CanLiquidate,
        CannotLiquidate,
        MaxMarketSizeExceeded,
        MaxLeverageExceeded,
        InsufficientMargin,
        NotPermitted,
        NilOrder,
        NoPositionOpen,
        PriceTooVolatile,
        PriceImpactToleranceExceeded
    }

    // If margin/size are positive, the position is long; if negative then it is short.
    struct Position {
        uint64 id;
        uint64 lastFundingIndex;
        uint128 margin;
        uint128 lastPrice;
        int128 size;
    }

    // Delayed order storage
    struct DelayedOrder {
        bool isOffchain; // flag indicating the delayed order is offchain
        int128 sizeDelta; // difference in position to pass to modifyPosition
        uint128 priceImpactDelta; // price impact tolerance as a percentage used on fillPrice at execution
        uint128 targetRoundId; // price oracle roundId using which price this order needs to executed
        uint128 commitDeposit; // the commitDeposit paid upon submitting that needs to be refunded if order succeeds
        uint128 keeperDeposit; // the keeperDeposit paid upon submitting that needs to be paid / refunded on tx confirmation
        uint256 executableAtTime; // The timestamp at which this order is executable at
        uint256 intentionTime; // The block timestamp of submission
        bytes32 trackingCode; // tracking code to emit on execution for volume source fee sharing
    }

    /* ========== Views ========== */
    /* ---------- Market Details ---------- */

    function marketKey() external view returns (bytes32 key);

    function baseAsset() external view returns (bytes32 key);

    function marketSize() external view returns (uint128 size);

    function marketSkew() external view returns (int128 skew);

    function fundingLastRecomputed() external view returns (uint32 timestamp);

    function fundingSequence(uint256 index) external view returns (int128 netFunding);

    function positions(address account) external view returns (Position memory);

    function delayedOrders(address account) external view returns (DelayedOrder memory);

    function assetPrice() external view returns (uint256 price, bool invalid);

    function marketSizes() external view returns (uint256 long, uint256 short);

    function marketDebt() external view returns (uint256 debt, bool isInvalid);

    function currentFundingRate() external view returns (int256 fundingRate);

    function currentFundingVelocity() external view returns (int256 fundingVelocity);

    function unrecordedFunding() external view returns (int256 funding, bool invalid);

    function fundingSequenceLength() external view returns (uint256 length);

    /* ---------- Position Details ---------- */

    function notionalValue(address account) external view returns (int256 value, bool invalid);

    function profitLoss(address account) external view returns (int256 pnl, bool invalid);

    function accruedFunding(address account) external view returns (int256 funding, bool invalid);

    function remainingMargin(address account)
        external
        view
        returns (uint256 marginRemaining, bool invalid);

    function accessibleMargin(address account)
        external
        view
        returns (uint256 marginAccessible, bool invalid);

    function liquidationPrice(address account)
        external
        view
        returns (uint256 price, bool invalid);

    function liquidationFee(address account) external view returns (uint256);

    function canLiquidate(address account) external view returns (bool);

    function orderFee(int256 sizeDelta, IPerpsV2MarketBaseTypes.OrderType orderType)
        external
        view
        returns (uint256 fee, bool invalid);

    function postTradeDetails(
        int256 sizeDelta,
        uint256 tradePrice,
        IPerpsV2MarketBaseTypes.OrderType orderType,
        address sender
    )
        external
        view
        returns (
            uint256 margin,
            int256 size,
            uint256 price,
            uint256 liqPrice,
            uint256 fee,
            Status status
        );

    /* ========== Market ========== */
    function recomputeFunding() external returns (uint256 lastIndex);

    function transferMargin(int256 marginDelta) external;

    function withdrawAllMargin() external;

    function modifyPosition(int256 sizeDelta, uint256 priceImpactDelta) external;

    function modifyPositionWithTracking(
        int256 sizeDelta,
        uint256 priceImpactDelta,
        bytes32 trackingCode
    ) external;

    function closePosition(uint256 priceImpactDelta) external;

    function closePositionWithTracking(uint256 priceImpactDelta, bytes32 trackingCode) external;

    function liquidatePosition(address account) external;

    /* ========== DelayedOrder ========== */
    function submitDelayedOrder(
        int256 sizeDelta,
        uint256 priceImpactDelta,
        uint256 desiredTimeDelta
    ) external;

    function submitDelayedOrderWithTracking(
        int256 sizeDelta,
        uint256 priceImpactDelta,
        uint256 desiredTimeDelta,
        bytes32 trackingCode
    ) external;

    function cancelDelayedOrder(address account) external;

    function executeDelayedOrder(address account) external;

    /* ========== OffchainDelayedOrder ========== */
    function submitOffchainDelayedOrder(int256 sizeDelta, uint256 priceImpactDelta) external;

    function submitOffchainDelayedOrderWithTracking(
        int256 sizeDelta,
        uint256 priceImpactDelta,
        bytes32 trackingCode
    ) external;

    function cancelOffchainDelayedOrder(address account) external;

    function executeOffchainDelayedOrder(address account, bytes[] calldata priceUpdateData)
        external
        payable;

    /* ========== Events ========== */

    event PositionModified(
        uint256 indexed id,
        address indexed account,
        uint256 margin,
        int256 size,
        int256 tradeSize,
        uint256 lastPrice,
        uint256 fundingIndex,
        uint256 fee
    );

    event MarginTransferred(address indexed account, int256 marginDelta);

    event PositionLiquidated(
        uint256 id, address account, address liquidator, int256 size, uint256 price, uint256 fee
    );

    event FundingRecomputed(int256 funding, int256 fundingRate, uint256 index, uint256 timestamp);

    event PerpsTracking(
        bytes32 indexed trackingCode,
        bytes32 baseAsset,
        bytes32 marketKey,
        int256 sizeDelta,
        uint256 fee
    );

    event DelayedOrderRemoved(
        address indexed account,
        bool isOffchain,
        uint256 currentRoundId,
        int256 sizeDelta,
        uint256 targetRoundId,
        uint256 commitDeposit,
        uint256 keeperDeposit,
        bytes32 trackingCode
    );

    event DelayedOrderSubmitted(
        address indexed account,
        bool isOffchain,
        int256 sizeDelta,
        uint256 targetRoundId,
        uint256 intentionTime,
        uint256 executableAtTime,
        uint256 commitDeposit,
        uint256 keeperDeposit,
        bytes32 trackingCode
    );
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

// https://docs.synthetix.io/contracts/source/interfaces/isynth
interface ISynth {
    // Views
    function currencyKey() external view returns (bytes32);

    function transferableSynths(address account) external view returns (uint256);

    // Mutative functions
    function transferAndSettle(address to, uint256 value) external returns (bool);

    function transferFromAndSettle(address from, address to, uint256 value)
        external
        returns (bool);

    // Restricted: used internally to Synthetix
    function burn(address account, uint256 amount) external;

    function issue(address account, uint256 amount) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import "./ISynth.sol";

interface IVirtualSynth {
    // Views
    function balanceOfUnderlying(address account) external view returns (uint256);

    function rate() external view returns (uint256);

    function readyToSettle() external view returns (bool);

    function secsLeftInWaitingPeriod() external view returns (uint256);

    function settled() external view returns (bool);

    function synth() external view returns (ISynth);

    // Mutative functions
    function settle(address account) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOps} from "../interfaces/IOps.sol";

/// @dev Inherit this contract to allow your smart
/// contract to make synchronous fee payments and have
/// call restrictions for functions to be automated.
abstract contract OpsReady {
    error OnlyOps();
    error EthTransferFailed();

    /// @notice address of Gelato Network contract
    address public constant GELATO = 0x01051113D81D7d6DA508462F2ad6d7fD96cF42Ef; // Optimism
    // address public constant GELATO = 0xF82D64357D9120a760e1E4C75f646C0618eFc2F3; // Optimism Goerli

    /// @notice address of Gelato `Automate` contract
    address public constant OPS = 0x340759c8346A1E6Ed92035FB8B6ec57cE1D82c2c; // Optimism
    // address public constant OPS = 0x255F82563b5973264e89526345EcEa766DB3baB2; // Optimism Goerli

    /// @notice address of Gelato `OpsProxyFactory` contract
    address private constant OPS_PROXY_FACTORY = 0xB3f5503f93d5Ef84b06993a1975B9D21B962892F; // Optimism
    // address private constant OPS_PROXY_FACTORY = 0x644CB00854EDC55FE8CCC9c1967BABb22F08Ad2f; // Optimism Goerli

    /// @notice internal address representation of ETH (used by Gelato)
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice modifier to restrict access to the `Automate` contract
    modifier onlyOps() {
        if (msg.sender != OPS) revert OnlyOps();
        _;
    }

    /// @notice transfers fee to gelato for synchronous fee payments
    /// @param _amount: amount of asset to transfer
    /// @param _paymentToken: address of the token to transfer
    function _transfer(uint256 _amount, address _paymentToken) internal {
        if (_paymentToken == ETH) {
            (bool success,) = GELATO.call{value: _amount}("");
            if (!success) revert EthTransferFailed();
        } else {
            SafeERC20.safeTransfer(IERC20(_paymentToken), GELATO, _amount);
        }
    }

    /// @notice get fee details from `Automate` contract
    /// @return fee amount
    /// @return feeToken address of fee token (or ETH)
    function _getFeeDetails() internal view returns (uint256 fee, address feeToken) {
        (fee, feeToken) = IOps(OPS).getFeeDetails();
    }
}