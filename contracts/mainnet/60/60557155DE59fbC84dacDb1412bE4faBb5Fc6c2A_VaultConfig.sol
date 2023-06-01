// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity >=0.4.24 <0.8.0;

import "../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || _isConstructor() || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

abstract contract SafeOwnable is ContextUpgradeable {
    address private _owner;
    address private _candidate;

    // __gap is reserved storage
    uint256[50] private __gap;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        // caller not owner
        require(owner() == _msgSender(), "SO_CNO");
        _;
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */

    function __SafeOwnable_init() internal initializer {
        __Context_init();
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() external virtual onlyOwner {
        // emitting event first to avoid caching values
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
        _candidate = address(0);
    }

    /**
     * @dev Set ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function setOwner(address newOwner) external onlyOwner {
        // newOwner is 0
        require(newOwner != address(0), "SO_NW0");
        // same as original
        require(newOwner != _owner, "SO_SAO");
        // same as candidate
        require(newOwner != _candidate, "SO_SAC");

        _candidate = newOwner;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`_candidate`).
     * Can only be called by the new owner.
     */
    function updateOwner() external {
        // candidate is zero
        require(_candidate != address(0), "SO_C0");
        // caller is not candidate
        require(_candidate == _msgSender(), "SO_CNC");

        // emitting event first to avoid caching values
        emit OwnershipTransferred(_owner, _candidate);
        _owner = _candidate;
        _candidate = address(0);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Returns the candidate that can become the owner.
     */
    function candidate() external view returns (address) {
        return _candidate;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { SafeOwnable } from "@perp/curie-contract/contracts/base/SafeOwnable.sol";
import { IVaultConfig } from "./interface/IVaultConfig.sol";
import { VaultConfigStorageV2 } from "./storage/VaultConfigStorage.sol";
import { IVaultConfigEvent } from "./interface/IVaultConfigEvent.sol";

contract VaultConfig is IVaultConfig, IVaultConfigEvent, SafeOwnable, VaultConfigStorageV2 {
    // TODO: fetch from ClearingHouseConfig
    uint24 internal constant _LIQUIDATION_MARGIN_RATIO = 62500;
    uint24 internal constant _ONE_HUNDRED_PERCENT_RATIO = 1e6;

    //
    // EXTERNAL NON-VIEW
    //

    function initialize() external initializer {
        __SafeOwnable_init();
    }

    function setWhitelistedLiquidityProviderAdder(address account) external onlyOwner {
        _requireNonZeroAddress(account);
        address oldWhiteListedLiquidProviderAdder = _whitelistedLiquidityProviderAdder;
        _whitelistedLiquidityProviderAdder = account;
        emit UpdateWhitelistedLiquidityProviderAdder(oldWhiteListedLiquidProviderAdder, account);
    }

    function setWhitelistForLiquidityProvider(address account, bool enable) external {
        // VC_IC: invalid caller
        require(owner() == _msgSender() || _whitelistedLiquidityProviderAdder == _msgSender(), "VC_IC");
        _requireNonZeroAddress(account);
        _whitelistedLiquidityProviderMap[account] = enable;
        emit UpdateLiquidityProviderWhitelist(account, enable);
    }

    function setWhitelistForArbitrageur(address account, bool enable) external onlyOwner {
        _requireNonZeroAddress(account);
        // VC_SV: same value
        require(_whitelistedArbitrageurMap[account] != enable, "VC_SV");
        _whitelistedArbitrageurMap[account] = enable;
        emit UpdateArbitragerWhitelist(account, enable);
    }

    function setDeleverageMarginRatio(uint24 deleverageMarginRatioArg) external onlyOwner {
        // VC_IDMR: invalid deleverage margin ratio
        require(
            deleverageMarginRatioArg > _LIQUIDATION_MARGIN_RATIO &&
                deleverageMarginRatioArg <= _ONE_HUNDRED_PERCENT_RATIO,
            "VC_IDMR"
        );
        uint24 oldDeleverageMarginRatio = _deleverageMarginRatio;
        _deleverageMarginRatio = deleverageMarginRatioArg;
        emit UpdateDeleverageMarginRatio(oldDeleverageMarginRatio, deleverageMarginRatioArg);
    }

    function setSwapRestrictionMarginRatio(uint24 swapRestrictionMarginRatioArg) external onlyOwner {
        // VC_ISRMR: invalid swap restriction margin ratio
        require(
            swapRestrictionMarginRatioArg > _LIQUIDATION_MARGIN_RATIO &&
                swapRestrictionMarginRatioArg <= _ONE_HUNDRED_PERCENT_RATIO,
            "VC_ISRMR"
        );
        uint24 oldSwapRestrictionMarginRatio = _swapRestrictionMarginRatio;
        _swapRestrictionMarginRatio = swapRestrictionMarginRatioArg;
        emit UpdateSwapRestrictionMarginRatio(oldSwapRestrictionMarginRatio, swapRestrictionMarginRatioArg);
    }

    //
    // EXTERNAL VIEW
    //

    function isWhitelistedLiquidityProvider(address account) external view override returns (bool) {
        return _whitelistedLiquidityProviderMap[account];
    }

    function isWhitelistedArbitrageur(address account) external view override returns (bool) {
        return _whitelistedArbitrageurMap[account];
    }

    function getWhitelistedLiquidityProviderAdder() external view override returns (address) {
        return _whitelistedLiquidityProviderAdder;
    }

    function getDeleverageMarginRatio() external view override returns (uint24) {
        return _deleverageMarginRatio;
    }

    function getSwapRestrictionMarginRatio() external view override returns (uint24) {
        return _swapRestrictionMarginRatio;
    }

    //
    // PUBLIC NON-VIEW
    //

    //
    // PUBLIC VIEW
    //

    //
    // INTERNAL NON-VIEW
    //

    //
    // INTERNAL VIEW
    //

    function _requireNonZeroAddress(address account) internal pure {
        // VC_ZA: Zero Address
        require(account != address(0), "VC_ZA");
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

interface IVaultConfig {
    /**
     * @notice Returns true if the provided address is a whitelisted liquidity provider
     */
    function isWhitelistedLiquidityProvider(address account) external view returns (bool);

    /**
     * @notice Returns true if the provided address is a whitelisted arbitrageur
     */
    function isWhitelistedArbitrageur(address account) external view returns (bool);

    /**
     * @notice Returns the address of whitelistedLiquidityProviderAdder
     */
    function getWhitelistedLiquidityProviderAdder() external view returns (address);

    /**
     * @notice Returns the margin ratio when Vault should be deleveraged
     */
    function getDeleverageMarginRatio() external view returns (uint24);

    /**
     * @notice Returns the margin ratio when swap is restricted/stopped
     */
    function getSwapRestrictionMarginRatio() external view returns (uint24);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

interface IVaultConfigEvent {
    event UpdateLiquidityProviderWhitelist(address account, bool enabled);

    event UpdateArbitragerWhitelist(address account, bool enabled);

    event UpdateWhitelistedLiquidityProviderAdder(address oldAccount, address newAccount);

    event UpdateDeleverageMarginRatio(uint24 oldMarginRatio, uint24 newMarginRatio);

    event UpdateSwapRestrictionMarginRatio(uint24 oldMarginRatio, uint24 newMarginRatio);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

/// @notice For future upgrades, do not change VaultConfigStorageV1. Create a new
/// contract which implements VaultConfigStorageV1 and following the naming convention
/// VaultConfigStorageVX.
abstract contract VaultConfigStorageV1 {
    uint24 internal _deleverageMarginRatio;
    uint24 internal _swapRestrictionMarginRatio;

    mapping(address => bool) internal _whitelistedLiquidityProviderMap;
    mapping(address => bool) internal _whitelistedArbitrageurMap;
}

abstract contract VaultConfigStorageV2 is VaultConfigStorageV1 {
    address internal _whitelistedLiquidityProviderAdder;
}