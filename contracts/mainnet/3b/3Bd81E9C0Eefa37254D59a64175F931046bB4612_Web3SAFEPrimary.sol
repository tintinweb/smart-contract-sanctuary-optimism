// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeacon.sol";
import "../../interfaces/draft-IERC1822.sol";
import "../../utils/Address.sol";
import "../../utils/StorageSlot.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967Upgrade {
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlot.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(Address.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            Address.isContract(IBeacon(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlot.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (proxy/Proxy.sol)

pragma solidity ^0.8.0;

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _beforeFallback();
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _fallback();
    }

    /**
     * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
     * call, or as part of the Solidity `fallback` or `receive` functions.
     *
     * If overridden should call `super._beforeFallback()`.
     */
    function _beforeFallback() internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/beacon/BeaconProxy.sol)

pragma solidity ^0.8.0;

import "./IBeacon.sol";
import "../Proxy.sol";
import "../ERC1967/ERC1967Upgrade.sol";

/**
 * @dev This contract implements a proxy that gets the implementation address for each call from an {UpgradeableBeacon}.
 *
 * The beacon address is stored in storage slot `uint256(keccak256('eip1967.proxy.beacon')) - 1`, so that it doesn't
 * conflict with the storage layout of the implementation behind the proxy.
 *
 * _Available since v3.4._
 */
contract BeaconProxy is Proxy, ERC1967Upgrade {
    /**
     * @dev Initializes the proxy with `beacon`.
     *
     * If `data` is nonempty, it's used as data in a delegate call to the implementation returned by the beacon. This
     * will typically be an encoded function call, and allows initializing the storage of the proxy like a Solidity
     * constructor.
     *
     * Requirements:
     *
     * - `beacon` must be a contract with the interface {IBeacon}.
     */
    constructor(address beacon, bytes memory data) payable {
        _upgradeBeaconToAndCall(beacon, data, false);
    }

    /**
     * @dev Returns the current beacon address.
     */
    function _beacon() internal view virtual returns (address) {
        return _getBeacon();
    }

    /**
     * @dev Returns the current implementation address of the associated beacon.
     */
    function _implementation() internal view virtual override returns (address) {
        return IBeacon(_getBeacon()).implementation();
    }

    /**
     * @dev Changes the proxy to use a new beacon. Deprecated: see {_upgradeBeaconToAndCall}.
     *
     * If `data` is nonempty, it's used as data in a delegate call to the implementation returned by the beacon.
     *
     * Requirements:
     *
     * - `beacon` must be a contract.
     * - The implementation returned by `beacon` must be a contract.
     */
    function _setBeacon(address beacon, bytes memory data) internal virtual {
        _upgradeBeaconToAndCall(beacon, data, false);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/UpgradeableBeacon.sol)

pragma solidity ^0.8.0;

import "./IBeacon.sol";
import "../../access/Ownable.sol";
import "../../utils/Address.sol";

/**
 * @dev This contract is used in conjunction with one or more instances of {BeaconProxy} to determine their
 * implementation contract, which is where they will delegate all function calls.
 *
 * An owner is able to change the implementation the beacon points to, thus upgrading the proxies that use this beacon.
 */
contract UpgradeableBeacon is IBeacon, Ownable {
    address private _implementation;

    /**
     * @dev Emitted when the implementation returned by the beacon is changed.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Sets the address of the initial implementation, and the deployer account as the owner who can upgrade the
     * beacon.
     */
    constructor(address implementation_) {
        _setImplementation(implementation_);
    }

    /**
     * @dev Returns the current implementation address.
     */
    function implementation() public view virtual override returns (address) {
        return _implementation;
    }

    /**
     * @dev Upgrades the beacon to a new implementation.
     *
     * Emits an {Upgraded} event.
     *
     * Requirements:
     *
     * - msg.sender must be the owner of the contract.
     * - `newImplementation` must be a contract.
     */
    function upgradeTo(address newImplementation) public virtual onlyOwner {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Sets the implementation contract address for this beacon
     *
     * Requirements:
     *
     * - `newImplementation` must be a contract.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "UpgradeableBeacon: implementation is not a contract");
        _implementation = newImplementation;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Create2.sol)

pragma solidity ^0.8.0;

/**
 * @dev Helper to make usage of the `CREATE2` EVM opcode easier and safer.
 * `CREATE2` can be used to compute in advance the address where a smart
 * contract will be deployed, which allows for interesting new mechanisms known
 * as 'counterfactual interactions'.
 *
 * See the https://eips.ethereum.org/EIPS/eip-1014#motivation[EIP] for more
 * information.
 */
library Create2 {
    /**
     * @dev Deploys a contract using `CREATE2`. The address where the contract
     * will be deployed can be known in advance via {computeAddress}.
     *
     * The bytecode for a contract can be obtained from Solidity with
     * `type(contractName).creationCode`.
     *
     * Requirements:
     *
     * - `bytecode` must not be empty.
     * - `salt` must have not been used for `bytecode` already.
     * - the factory must have a balance of at least `amount`.
     * - if `amount` is non-zero, `bytecode` must have a `payable` constructor.
     */
    function deploy(
        uint256 amount,
        bytes32 salt,
        bytes memory bytecode
    ) internal returns (address) {
        address addr;
        require(address(this).balance >= amount, "Create2: insufficient balance");
        require(bytecode.length != 0, "Create2: bytecode length is zero");
        /// @solidity memory-safe-assembly
        assembly {
            addr := create2(amount, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(addr != address(0), "Create2: Failed on deploy");
        return addr;
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy}. Any change in the
     * `bytecodeHash` or `salt` will result in a new destination address.
     */
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) internal view returns (address) {
        return computeAddress(salt, bytecodeHash, address(this));
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy} from a contract located at
     * `deployer`. If `deployer` is this contract's address, returns the same value as {computeAddress}.
     */
    function computeAddress(
        bytes32 salt,
        bytes32 bytecodeHash,
        address deployer
    ) internal pure returns (address) {
        bytes32 _data = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, bytecodeHash));
        return address(uint160(uint256(_data)));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "../tokens/ERC20.sol";

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
/// @dev Note that none of the functions in this library check that a token has code at all! That responsibility is delegated to the caller.
library SafeTransferLib {
    /*//////////////////////////////////////////////////////////////
                             ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), from) // Append the "from" argument.
            mstore(add(freeMemoryPointer, 36), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
            )
        }

        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "TRANSFER_FAILED");
    }

    function safeApprove(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "APPROVE_FAILED");
    }
}

// SPDX-License-Identifier: None

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

contract BeaconFactory {
    address public immutable deployer;
    UpgradeableBeacon public beacon;

    mapping(bytes32 => address) public proxies;

    constructor() {
        deployer = msg.sender;
    }

    function initialize(address _implementation) external {
        require(msg.sender == deployer, "!deployer");
        beacon = new UpgradeableBeacon(_implementation);
        Ownable(address(beacon)).transferOwnership(msg.sender);
    }

    function deploy(string memory _salt) external returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(_salt));
        address proxy = address(new BeaconProxy{salt : salt}(address(beacon),hex''));
        proxies[salt] = proxy;
        return proxy;
    }

    function getProxyAddress(string memory _salt) external view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(_salt));
        return proxies[salt];
    }
}

// SPDX-License-Identifier: None

pragma solidity ^0.8.0;

import "./interfaces/ICompliance.sol";
import "./library/WhitelistOperatorRole.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice whitelist which manages KYC approvals, token lockup, and transfer
 * restrictions for a DAT token.
 */
contract Compliance is OwnableUpgradeable, WhitelistOperatorRole {
    event UpdateJurisdictionFlow(
        uint256 indexed _jurisdictionIndex,
        uint256 indexed _fromJurisdictionId,
        uint256 indexed _toJurisdictionId,
        uint256 _lockupLength,
        address _operator
    );
    event ApproveNewUser(
        address indexed _safe, address indexed _trader, uint256 indexed _jurisdictionId, address _operator
    );
    event AddApprovedUserWallet(
        address indexed _safe, address indexed _userId, address indexed _newWallet, address _operator
    );
    event RevokeUserWallet(address indexed _safe, address indexed _wallet, address indexed _operator);
    event UpdateJurisdictionForUserId(
        address indexed _safe, address indexed _userId, uint256 indexed _jurisdictionId, address _operator
    );
    event AddLockup(
        address indexed _safe,
        address indexed _userId,
        uint256 _lockupExpirationDate,
        uint256 _numberOfTokensLocked,
        address _operator
    );
    event UnlockTokens(address indexed _safe, address indexed _userId, uint256 _tokensUnlocked, address _operator);
    event Halt(address indexed _safe, uint256 indexed _jurisdictionId);
    event Resume(address indexed _safe, uint256 indexed _jurisdictionId);
    event MaxInvestorsChanged(address indexed _safe, uint256 _limit);
    event MaxInvestorsByJurisdictionChanged(address indexed _safe, uint256 indexed _jurisdictionId, uint256 _limit);

    uint256 public lockupGranularity;

    struct InvestorLimit {
        uint128 max;
        uint128 current;
    }

    mapping(address => InvestorLimit) public globalInvestorLimit;

    mapping(address => mapping(uint256 => InvestorLimit)) public jurisdictionInvestorLimit;

    /**
     * @notice Maps Jurisdiction Id to it's halted status
     */
    mapping(address => mapping(uint256 => bool)) public jurisdictionHalted;

    mapping(address => uint256) public jurisdictionIndex;

    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint64))) internal jurisdictionFlows;

    enum Status {
        Unknown, // User is unknown. Needs approval from whitelistOperator
        Activated, // User is known and activated
        Revoked // User is known but revoked from whitelist
    }

    struct UserInfo {
        Status status;
        uint8 jurisdictionId;
        uint64 walletCount;
    }

    struct UserLockupInfo {
        // The first applicable entry in userIdLockups
        uint32 startIndex;
        // The last applicable entry in userIdLockups + 1
        uint32 endIndex;
        // The number of tokens locked, with details tracked in userIdLockups
        uint192 totalTokensLocked;
    }

    mapping(address => mapping(address => UserInfo)) internal userInfo;

    mapping(address => mapping(address => UserLockupInfo)) internal userLockupInfo;

    struct WalletInfo {
        Status status;
        address userId;
    }

    mapping(address => mapping(address => WalletInfo)) public walletInfo;

    /**
     * info stored for each token lockup.
     */
    struct Lockup {
        // The date/time that this lockup entry has expired and the tokens may be transferred
        uint64 lockupExpirationDate;
        // How many tokens locked until the given expiration date.
        uint128 numberOfTokensLocked;
    }

    mapping(address => mapping(address => mapping(uint256 => Lockup))) internal userIdLockups;

    mapping(address => string) public legal;

    /**
     * @notice checks for transfer restrictions between jurisdictions.
     * @return lockupLength if transfers between these jurisdictions are allowed and if a
     * token lockup should apply:
     * - 0 means transfers between these jurisdictions is blocked (the default)
     * - 1 is supported with no token lockup required
     * - >1 is supported and this value defines the lockup length in seconds
     */
    function getJurisdictionFlow(uint256 _index, uint256 _fromJurisdictionId, uint256 _toJurisdictionId)
        external
        view
        returns (uint256 lockupLength)
    {
        return jurisdictionFlows[_index][_fromJurisdictionId][_toJurisdictionId];
    }

    /**
     * @notice checks details for a given userId.
     */
    function getAuthorizedUserIdInfo(address _safe, address _userId)
        external
        view
        returns (uint256 jurisdictionId, uint256 totalTokensLocked, uint256 startIndex, uint256 endIndex)
    {
        UserInfo memory info = userInfo[_safe][_userId];
        UserLockupInfo memory lockupInfo = userLockupInfo[_safe][_userId];
        return (info.jurisdictionId, lockupInfo.totalTokensLocked, lockupInfo.startIndex, lockupInfo.endIndex);
    }

    function getInvestorInfo(address _safe) external view returns (uint256 maxInvestor, uint256 currentInvestor) {
        return (globalInvestorLimit[_safe].max, globalInvestorLimit[_safe].current);
    }

    function getJurisdictionInfo(address _safe, uint256 _jurisdictionId)
        external
        view
        returns (bool halted, uint256 maxInvestor, uint256 currentInvestor)
    {
        InvestorLimit memory limit = jurisdictionInvestorLimit[_safe][_jurisdictionId];
        return (jurisdictionHalted[_safe][_jurisdictionId], limit.max, limit.current);
    }

    /**
     * @notice gets a specific lockup entry for a userId.
     * @dev use `getAuthorizedUserIdInfo` to determine the range of applicable lockupIndex.
     */
    function getUserIdLockup(address _safe, address _userId, uint256 _lockupIndex)
        external
        view
        returns (uint256 lockupExpirationDate, uint256 numberOfTokensLocked)
    {
        Lockup memory lockup = userIdLockups[_safe][_userId][_lockupIndex];
        return (lockup.lockupExpirationDate, lockup.numberOfTokensLocked);
    }

    /**
     * @notice Returns the number of unlocked tokens a given userId has available.
     * @dev this is a `view`-only way to determine how many tokens are still locked
     * (info.totalTokensLocked is only accurate after processing lockups which changes state)
     */
    function getLockedTokenCount(address _safe, address _userId) external view returns (uint256 lockedTokens) {
        UserLockupInfo memory info = userLockupInfo[_safe][_userId];
        lockedTokens = info.totalTokensLocked;
        uint256 endIndex = info.endIndex;
        for (uint256 i = info.startIndex; i < endIndex; i++) {
            Lockup memory lockup = userIdLockups[_safe][_userId][i];
            if (lockup.lockupExpirationDate > block.timestamp) {
                // no more eligible entries
                break;
            }
            // this lockup entry has expired and would be processed on the next tx
            lockedTokens -= lockup.numberOfTokensLocked;
        }
    }

    /**
     * @notice Called once to complete configuration for this contract.
     * @dev Done with `initialize` instead of a constructor in order to support
     * using this contract via an Upgradable Proxy.
     */
    function initialize() public initializer {
        _initializeWhitelistOperatorRole();
        lockupGranularity = 172800;
    }

    function authorizedWalletToUserId(address safe, address wallet) external view returns (address userId) {
        return walletInfo[safe][wallet].userId;
    }

    /**
     * @notice Called by the owner to define or update jurisdiction flows.
     * @param _lockupLengths defines transfer restrictions where:
     * - 0 is not supported (the default)
     * - 1 is supported with no token lockup required
     * - >1 is supported and this value defines the lockup length in seconds.
     * @dev note that this can be called with a partial list, only including entries
     * to be added or which have changed.
     */
    function updateJurisdictionFlows(
        uint256 _index,
        uint256[] calldata _fromJurisdictionIds,
        uint256[] calldata _toJurisdictionIds,
        uint256[] calldata _lockupLengths
    ) external onlyOwner {
        uint256 count = _fromJurisdictionIds.length;
        for (uint256 i = 0; i < count; i++) {
            uint256 fromJurisdictionId = _fromJurisdictionIds[i];
            uint256 toJurisdictionId = _toJurisdictionIds[i];
            require(fromJurisdictionId > 0 && toJurisdictionId > 0, "INVALID_JURISDICTION_ID");
            jurisdictionFlows[_index][fromJurisdictionId][toJurisdictionId] = uint64(_lockupLengths[i]);
            emit UpdateJurisdictionFlow(_index, fromJurisdictionId, toJurisdictionId, _lockupLengths[i], msg.sender);
        }
    }

    function setLegalUri(address _safe, string memory _uri) external onlyWhitelistOperator(_safe) {
        legal[_safe] = _uri;
    }

    /**
     * @notice Called by an operator to add new traders.
     * @dev The trader will be assigned a userId equal to their wallet address.
     */
    function approveNewUsers(address _safe, address[] calldata _traders, uint256[] calldata _jurisdictionIds)
        external
        onlyWhitelistOperator(_safe)
    {
        uint256 length = _traders.length;
        for (uint256 i = 0; i < length; i++) {
            address trader = _traders[i];
            require(walletInfo[_safe][trader].userId == address(0), "USER_WALLET_ALREADY_ADDED");

            uint256 jurisdictionId = _jurisdictionIds[i];
            require(jurisdictionId != 0, "INVALID_JURISDICTION_ID");

            walletInfo[_safe][trader] = WalletInfo({status: Status.Activated, userId: trader});
            userInfo[_safe][trader] =
                UserInfo({status: Status.Activated, jurisdictionId: uint8(jurisdictionId), walletCount: 1});

            InvestorLimit memory global = globalInvestorLimit[_safe];
            require(global.max == 0 || global.max > global.current, "exceeds investor limit");
            globalInvestorLimit[_safe].current++;

            InvestorLimit memory jurisdiction = jurisdictionInvestorLimit[_safe][jurisdictionId];
            require(jurisdiction.max == 0 || jurisdiction.max > jurisdiction.current, "exceeds investor limit");
            jurisdictionInvestorLimit[_safe][jurisdictionId].current++;

            emit ApproveNewUser(_safe, trader, jurisdictionId, msg.sender);
        }
    }

    /**
     * @notice Called by an operator to add wallets to known userIds.
     */
    function addApprovedUserWallets(address _safe, address[] calldata _userIds, address[] calldata _newWallets)
        external
        onlyWhitelistOperator(_safe)
    {
        uint256 length = _userIds.length;
        for (uint256 i = 0; i < length; i++) {
            address userId = _userIds[i];
            require(userInfo[_safe][userId].status != Status.Unknown, "USER_ID_UNKNOWN");
            address newWallet = _newWallets[i];
            WalletInfo storage info = walletInfo[_safe][newWallet];
            require(
                info.status == Status.Unknown || (info.status == Status.Revoked && info.userId == userId),
                "WALLET_ALREADY_ADDED"
            );
            walletInfo[_safe][newWallet] = WalletInfo({status: Status.Activated, userId: userId});
            if (userInfo[_safe][userId].walletCount == 0) {
                userInfo[_safe][userId].status = Status.Activated;
                jurisdictionInvestorLimit[_safe][userInfo[_safe][userId].jurisdictionId].current++;
                globalInvestorLimit[_safe].current++;
            }

            userInfo[_safe][userId].walletCount++;
            emit AddApprovedUserWallet(_safe, userId, newWallet, msg.sender);
        }
    }

    /**
     * @notice Called by an operator to revoke approval for the given wallets.
     * @dev If this is called in error, you can restore access with `addApprovedUserWallets`.
     */
    function revokeUserWallets(address _safe, address[] calldata _wallets) external onlyWhitelistOperator(_safe) {
        uint256 length = _wallets.length;
        for (uint256 i = 0; i < length; i++) {
            WalletInfo memory wallet = walletInfo[_safe][_wallets[i]];
            require(wallet.status != Status.Unknown, "WALLET_NOT_FOUND");
            userInfo[_safe][wallet.userId].walletCount--;
            if (userInfo[_safe][wallet.userId].walletCount == 0) {
                userInfo[_safe][wallet.userId].status = Status.Revoked;
                jurisdictionInvestorLimit[_safe][userInfo[_safe][wallet.userId].jurisdictionId].current--;
                globalInvestorLimit[_safe].current--;
            }

            walletInfo[_safe][_wallets[i]].status = Status.Revoked;
            emit RevokeUserWallet(_safe, _wallets[i], msg.sender);
        }
    }

    /**
     * @notice Called by an operator to change the jurisdiction
     * for the given userIds.
     */
    function updateJurisdictionsForUserIds(
        address _safe,
        address[] calldata _userIds,
        uint256[] calldata _jurisdictionIds
    ) external onlyWhitelistOperator(_safe) {
        uint256 length = _userIds.length;
        for (uint256 i = 0; i < length; i++) {
            address userId = _userIds[i];
            require(userInfo[_safe][userId].status != Status.Unknown, "USER_ID_UNKNOWN");
            uint256 jurisdictionId = _jurisdictionIds[i];
            require(jurisdictionId != 0, "INVALID_JURISDICTION_ID");
            jurisdictionInvestorLimit[_safe][userInfo[_safe][userId].jurisdictionId].current--;
            userInfo[_safe][userId].jurisdictionId = uint8(jurisdictionId);
            jurisdictionInvestorLimit[_safe][jurisdictionId].current++;

            emit UpdateJurisdictionForUserId(_safe, userId, jurisdictionId, msg.sender);
        }
    }

    /**
     * @notice Adds a tokenLockup for the userId.
     * @dev A no-op if lockup is not required for this transfer.
     * The lockup entry is merged with the most recent lockup for that user
     * if the expiration date is <= `lockupGranularity` from the previous entry.
     */
    function _addLockup(address _safe, address _userId, uint256 _lockupExpirationDate, uint256 _numberOfTokensLocked)
        internal
    {
        if (_numberOfTokensLocked == 0 || _lockupExpirationDate <= block.timestamp) {
            // This is a no-op
            return;
        }
        emit AddLockup(_safe, _userId, _lockupExpirationDate, _numberOfTokensLocked, msg.sender);
        UserLockupInfo storage info = userLockupInfo[_safe][_userId];
        require(userInfo[_safe][_userId].status != Status.Unknown, "USER_ID_UNKNOWN");
        require(info.totalTokensLocked + _numberOfTokensLocked >= _numberOfTokensLocked, "OVERFLOW");
        info.totalTokensLocked = info.totalTokensLocked + uint128(_numberOfTokensLocked);
        if (info.endIndex > 0) {
            Lockup storage lockup = userIdLockups[_safe][_userId][info.endIndex - 1];
            if (lockup.lockupExpirationDate + lockupGranularity >= _lockupExpirationDate) {
                // Merge with the previous entry
                // if totalTokensLocked can't overflow then this value will not either
                lockup.numberOfTokensLocked += uint128(_numberOfTokensLocked);
                return;
            }
        }
        // Add a new lockup entry
        userIdLockups[_safe][_userId][info.endIndex] =
            Lockup(uint64(_lockupExpirationDate), uint128(_numberOfTokensLocked));
        info.endIndex++;
    }

    /**
     * @notice Operators can manually add lockups for userIds.
     * This may be used by the organization before transfering tokens
     * from the initial supply.
     */
    function addLockups(
        address _safe,
        address[] calldata _userIds,
        uint256[] calldata _lockupExpirationDates,
        uint256[] calldata _numberOfTokensLocked
    ) external onlyWhitelistOperator(_safe) {
        uint256 length = _userIds.length;
        for (uint256 i = 0; i < length; i++) {
            _addLockup(_safe, _userIds[i], _lockupExpirationDates[i], _numberOfTokensLocked[i]);
        }
    }

    /**
     * @notice Checks the next lockup entry for a given user and unlocks
     * those tokens if applicable.
     * @param _ignoreExpiration bypasses the recorded expiration date and
     * removes the lockup entry if there are any remaining for this user.
     */
    function _processLockup(address _safe, UserLockupInfo storage info, address _userId, bool _ignoreExpiration)
        internal
        returns (bool isDone)
    {
        if (info.startIndex >= info.endIndex) {
            // no lockups for this user
            return true;
        }
        Lockup storage lockup = userIdLockups[_safe][_userId][info.startIndex];
        if (lockup.lockupExpirationDate > block.timestamp && !_ignoreExpiration) {
            // no more eligable entries
            return true;
        }
        emit UnlockTokens(_safe, _userId, lockup.numberOfTokensLocked, msg.sender);
        info.totalTokensLocked -= lockup.numberOfTokensLocked;
        info.startIndex++;
        // Free up space we don't need anymore
        lockup.lockupExpirationDate = 0;
        lockup.numberOfTokensLocked = 0;
        // There may be another entry
        return false;
    }

    /**
     * @notice Anyone can process lockups for a userId.
     * This is generally unused but may be required if a given userId
     * has a lot of individual lockup entries which are expired.
     */
    function processLockups(address _safe, address _userId, uint256 _maxCount) external {
        UserLockupInfo storage info = userLockupInfo[_safe][_userId];
        require(userInfo[_safe][_userId].status != Status.Unknown, "USER_ID_UNKNOWN");
        for (uint256 i = 0; i < _maxCount; i++) {
            if (_processLockup(_safe, info, _userId, false)) {
                break;
            }
        }
    }

    /**
     * @notice Allows operators to remove lockup entries, bypassing the
     * recorded expiration date.
     * @dev This should generally remain unused. It could be used in combination with
     * `addLockups` to fix an incorrect lockup expiration date or quantity.
     */
    function forceUnlockUpTo(address _safe, address _userId, uint256 _maxLockupIndex)
        external
        onlyWhitelistOperator(_safe)
    {
        UserLockupInfo storage info = userLockupInfo[_safe][_userId];
        require(userInfo[_safe][_userId].status != Status.Unknown, "USER_ID_UNKNOWN");
        require(_maxLockupIndex > info.startIndex, "ALREADY_UNLOCKED");
        uint256 maxCount = _maxLockupIndex - info.startIndex;
        for (uint256 i = 0; i < maxCount; i++) {
            if (_processLockup(_safe, info, _userId, true)) {
                break;
            }
        }
    }

    function _isJurisdictionHalted(address _safe, uint256 _jurisdictionId) internal view returns (bool) {
        return jurisdictionHalted[_safe][_jurisdictionId];
    }

    /**
     * @notice halts jurisdictions of id `_jurisdictionIds` for `_duration` seconds
     * @dev only owner can call this function
     * @param _jurisdictionIds ids of the jurisdictions to halt
     * @param _expirationTimestamps due when halt ends
     *
     */
    function halt(address _safe, uint256[] calldata _jurisdictionIds, uint256[] calldata _expirationTimestamps)
        external
        onlyWhitelistOperator(_safe)
    {
        uint256 length = _jurisdictionIds.length;
        for (uint256 i = 0; i < length; i++) {
            _halt(_safe, _jurisdictionIds[i], _expirationTimestamps[i]);
        }
    }

    function _halt(address _safe, uint256 _jurisdictionId, uint256 _until) internal {
        require(_until > block.timestamp, "HALT_DUE_SHOULD_BE_FUTURE");
        jurisdictionHalted[_safe][_jurisdictionId] = true;
        emit Halt(_safe, _jurisdictionId);
    }

    /**
     * @notice resume halted jurisdiction
     * @dev only owner can call this function
     * @param _jurisdictionIds list of jurisdiction ids to resume
     *
     */
    function resume(address _safe, uint256[] calldata _jurisdictionIds) external onlyWhitelistOperator(_safe) {
        uint256 length = _jurisdictionIds.length;
        for (uint256 i = 0; i < length; i++) {
            _resume(_safe, _jurisdictionIds[i]);
        }
    }

    function _resume(address _safe, uint256 _jurisdictionId) internal {
        require(jurisdictionHalted[_safe][_jurisdictionId], "ATTEMPT_TO_RESUME_NONE_HALTED_JURISDICATION");
        jurisdictionHalted[_safe][_jurisdictionId] = false;
        emit Resume(_safe, _jurisdictionId);
    }

    function setJurisdictionIndex(address _safe, uint256 _jurisdictionIndex) external onlyWhitelistOperator(_safe) {
        jurisdictionIndex[_safe] = _jurisdictionIndex;
    }

    /**
     * @notice changes max investors limit of the contract to `_limit`
     * @dev only owner can call this function
     * @param _limit new investor limit for contract
     */
    function setInvestorLimit(address _safe, uint256 _limit) external onlyWhitelistOperator(_safe) {
        require(_limit >= globalInvestorLimit[_safe].current, "LIMIT_SHOULD_BE_LARGER_THAN_CURRENT_INVESTORS");
        globalInvestorLimit[_safe].max = uint128(_limit);
        emit MaxInvestorsChanged(_safe, _limit);
    }

    /**
     * @notice changes max investors limit of the `_jurisdcitionId` to `_limit`
     * @dev only owner can call this function
     * @param _jurisdictionIds jurisdiction id to update
     * @param _limits new investor limit for jurisdiction
     */
    function setInvestorLimitForJurisdiction(
        address _safe,
        uint256[] calldata _jurisdictionIds,
        uint256[] calldata _limits
    ) external onlyWhitelistOperator(_safe) {
        for (uint256 i = 0; i < _jurisdictionIds.length; i++) {
            uint256 jurisdictionId = _jurisdictionIds[i];
            uint256 limit = _limits[i];
            require(
                limit >= jurisdictionInvestorLimit[_safe][jurisdictionId].current,
                "LIMIT_SHOULD_BE_LARGER_THAN_CURRENT_INVESTORS"
            );
            jurisdictionInvestorLimit[_safe][jurisdictionId].max = uint128(limit);
            emit MaxInvestorsByJurisdictionChanged(_safe, jurisdictionId, limit);
        }
    }

    /**
     * @notice Called by RSafe before a transfer occurs.
     * @dev This call will revert when the transfer is not authorized.
     * This is a mutable call to allow additional data to be recorded,
     * such as when the user aquired their tokens.
     *
     */
    function authorizeTransfer(address _from, address _to, uint256 _value) external {
        if (_to == address(0)) {
            // This is a burn, no authorization required
            // You can burn locked tokens. Burning will effectively burn unlocked tokens,
            // and then burn locked tokens starting with those that will be unlocked first.
            return;
        }
        WalletInfo memory from = walletInfo[msg.sender][_from];
        require(
            (from.status != Status.Unknown && from.status != Status.Revoked) || _from == address(0), "FROM_USER_UNKNOWN"
        );
        WalletInfo memory to = walletInfo[msg.sender][_to];
        require((to.status != Status.Unknown && to.status != Status.Revoked) || _to == address(0), "TO_USER_UNKNOWN");

        // A single user can move funds between wallets they control without restriction
        if (from.userId != to.userId) {
            uint256 fromJurisdictionId = userInfo[msg.sender][from.userId].jurisdictionId;
            uint256 toJurisdictionId = userInfo[msg.sender][to.userId].jurisdictionId;

            uint256 index = jurisdictionIndex[msg.sender];

            require(!_isJurisdictionHalted(msg.sender, fromJurisdictionId), "FROM_JURISDICTION_HALTED");
            require(!_isJurisdictionHalted(msg.sender, toJurisdictionId), "TO_JURISDICTION_HALTED");

            uint256 lockupLength = jurisdictionFlows[index][fromJurisdictionId][toJurisdictionId];
            require(lockupLength > 0, "DENIED: JURISDICTION_FLOW");

            // If the lockupLength is 1 then we interpret this as approved without any lockup
            // This means any token lockup period must be at least 2 seconds long in order to apply.
            if (lockupLength > 1 && _to != address(0)) {
                // Lockup may apply for any action other than burn/sell (e.g. buy/pay/transfer)
                uint256 lockupExpirationDate = block.timestamp + lockupLength;
                _addLockup(msg.sender, to.userId, lockupExpirationDate, _value);
            }

            // This is a transfer (or sell)
            UserLockupInfo storage info = userLockupInfo[msg.sender][from.userId];
            while (true) {
                if (_processLockup(msg.sender, info, from.userId, false)) {
                    break;
                }
            }
            if (_from != address(0)) {
                uint256 balance = IERC20(msg.sender).balanceOf(_from);
                // This first require is redundant, but allows us to provide
                // a more clear error message.
                require(balance >= _value, "INSUFFICIENT_BALANCE");
                require(balance >= info.totalTokensLocked + _value, "INSUFFICIENT_TRANSFERABLE_BALANCE");
            }
        }
    }
}

// SPDX-License-Identifier: None

pragma solidity ^0.8.15;

import "@rari-capital/solmate/src/tokens/ERC20.sol";
import "./interfaces/ICompliance.sol";

contract ComplianceERC20 is ERC20 {
    ICompliance public immutable compliance;
    address public immutable safe;
    address public beneficiary;

    constructor(ICompliance _compliance, address _safe) ERC20("", "", 18) {
        compliance = _compliance;
        safe = _safe;
    }

    function initialize(string memory _name, string memory _symbol, address _beneficiary) external {
        require(beneficiary == address(0), "initialized");
        name = _name;
        symbol = _symbol;
        beneficiary = _beneficiary;
    }

    function reinitialize(string memory _name, string memory _symbol, address _beneficiary) external {
        require(msg.sender == beneficiary || msg.sender == safe, "!beneficiary");
        name = _name;
        symbol = _symbol;
        beneficiary = _beneficiary;
    }

    function changeBeneficiary(address _newBeneficiary) external {
        require(msg.sender == beneficiary, "!beneficiary");
        beneficiary = _newBeneficiary;
        transfer(_newBeneficiary, balanceOf[msg.sender]);
    }

    function mint(address _to, uint256 _amount) external {
        require(msg.sender == safe, "!safe");
        _mint(_to, _amount);
    }

    function _mint(address to, uint256 amount) internal override {
        compliance.authorizeTransfer(address(0), to, amount);
        super._mint(to, amount);
    }

    function _burn(address from, uint256 amount) internal override {
        compliance.authorizeTransfer(from, address(0), amount);
        super._burn(from, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        compliance.authorizeTransfer(msg.sender, to, amount);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        compliance.authorizeTransfer(from, to, amount);
        return super.transferFrom(from, to, amount);
    }

    function batchTransfer(address[] calldata tos, uint256[] calldata amounts) public {
        require(tos.length == amounts.length, "length diff");
        for (uint256 i = 0; i < tos.length; i++) {
            compliance.authorizeTransfer(msg.sender, tos[i], amounts[i]);
            super.transfer(tos[i], amounts[i]);
        }
    }

    function legal() external view returns (string memory) {
        return compliance.legal(address(this));
    }
}

// SPDX-License-Identifier: None

pragma solidity ^0.8.15;

import "./ComplianceERC20.sol";
import "./abstract/Web3SAFE.sol";
import "./BeaconFactory.sol";
import {Compliance} from "./Compliance.sol";

contract Web3SAFEPrimary is Web3SAFE {
    //PermitConfigure(uint256 safeId,address control,address recipient,uint256 minInvestment,uint256 nonce,uint256 deadline)
    bytes32 public constant PERMIT_CONFIGURE_TYPEHASH =
        0xa5cad0a92f52b75065ebbdb0f179dfd4cd52d3394cdba395c77a49a0d00d773b;
    BeaconFactory public immutable beaconfactory;

    Compliance public immutable compliance;

    struct InstantiateParams {
        string salt;
        string name;
        string symbol;
        address beneficiary;
        address control;
        address payable recipient;
        address admin;
        uint256 minInvestment;
        address currency;
        SafeType safeType;
    }

    struct NewAllocationParams {
        uint256 startPrice;
        uint256 endPrice;
        uint256 tokenAmount;
        uint256 newCommitment;
    }

    constructor(BeaconFactory _beaconFactory, Compliance _compliance) {
        beaconfactory = _beaconFactory;
        compliance = _compliance;
    }

    function initialize(
        InstantiateParams calldata iparam,
        uint256 jurisdictionIndex,
        string calldata legal,
        uint256 beneficiaryJurisdictionId,
        NewAllocationParams calldata nparam
    ) external returns (address token) {
        token = this.instantiate(
            iparam.salt,
            iparam.name,
            iparam.symbol,
            address(this),
            iparam.control,
            iparam.recipient,
            iparam.minInvestment,
            iparam.currency,
            iparam.safeType
        );
        compliance.addWhitelistOperator(token, address(this));
        compliance.setJurisdictionIndex(token, jurisdictionIndex);
        compliance.setLegalUri(token, legal);
        this.newAllocation(
            uint256(uint160(token)), nparam.startPrice, nparam.endPrice, nparam.tokenAmount, nparam.newCommitment
        );
        address[] memory traders = new address[](3);
        traders[0] = address(this);
        traders[1] = iparam.beneficiary;
        traders[2] = address(0);
        uint256[] memory jurisdictions = new uint256[](3);
        jurisdictions[0] = 1;
        jurisdictions[1] = beneficiaryJurisdictionId;
        jurisdictions[2] = 1;
        compliance.approveNewUsers(token, traders, jurisdictions);
        this.addAdmin(uint256(uint160(token)), iparam.admin);
        ComplianceERC20(token).changeBeneficiary(iparam.beneficiary);
        compliance.renounceWhitelistOperator(token);
    }

    function instantiate(
        string memory _salt,
        string memory _name,
        string memory _symbol,
        address _beneficiary,
        address _control,
        address payable _recipient,
        uint256 _minInvestment,
        address _currency,
        SafeType _safeType
    ) external returns (address) {
        address token = beaconfactory.deploy(_salt);
        ComplianceERC20(token).initialize(_name, _symbol, _beneficiary);
        _instantiate(uint256(uint160(token)), _control, _recipient, _minInvestment, token, _currency, _safeType);
        return token;
    }

    function reinstantiate(
        uint256 _safeId,
        string memory _name,
        string memory _symbol,
        address _beneficiary,
        address _control,
        address payable _recipient,
        uint256 _minInvestment,
        address _currency,
        SafeType _safeType
    ) external onlyBeneficiary(_safeId) {
        require(state(_safeId) == State.Run && params[_safeId].totalInvested == 0, "cannot reinstantiate");
        ComplianceERC20(address(uint160(_safeId))).reinitialize(_name, _symbol, _beneficiary);
        _instantiate(_safeId, _control, _recipient, _minInvestment, address(uint160(_safeId)), _currency, _safeType);
    }

    function configure(uint256 _safeId, address _control, address payable _recipient, uint256 _minInvestment)
        external
        onRun(_safeId)
    {
        _configure(msg.sender, _safeId, _control, _recipient, _minInvestment);
    }

    function permitConfigure(
        uint256 _safeId,
        address _control,
        address payable _recipient,
        uint256 _minInvestment,
        uint256 _nonce,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external onRun(_safeId) {
        bytes32 digest = keccak256(
            abi.encode(PERMIT_CONFIGURE_TYPEHASH, _safeId, _control, _recipient, _minInvestment, _nonce, _deadline)
        );
        digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), digest));
        address signer = ecrecover(digest, _v, _r, _s);
        require(_nonce == nonces[signer]++, "INVALID_NONCE");
        require(block.timestamp <= _deadline, "INVALID_EXPIRATION");
        _configure(signer, _safeId, _control, _recipient, _minInvestment);
    }

    function _payout(ERC20 _token, address _to, uint256 _amount) internal override {
        ComplianceERC20(address(_token)).mint(_to, _amount);
    }

    function _receiveToken(ERC20 _token, uint256) internal view override {
        // no-op
    }

    function _flushToken(ERC20 _token, address _to, uint256 _amount) internal override {
        // no-op
    }

    function beneficiary(uint256 _safeId) public view override returns (address) {
        SafeInfo memory i = info[_safeId];
        return ComplianceERC20(i.token).beneficiary();
    }

    function name() public pure override returns (string memory) {
        return "Web3SAFEPrimary";
    }
}

// SPDX-License-Identifier: None

pragma solidity ^0.8.15;

import "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "../utils/MathUtils.sol";

abstract contract Web3SAFE is Initializable {
    enum State {
        Invalid,
        Run,
        Close
    }

    enum SafeType {
        Invalid,
        Safe,
        Share
    }

    struct SafeInfo {
        bool closed;
        SafeType safeType;
        address token;
        address currency;
    }

    struct SafeConfig {
        address control;
        address payable recipient;
        uint256 minInvestment;
    }

    struct SafeParams {
        uint256 commitment;
        uint256 committed;
        uint256 shareholders;
        uint256 stakeholders;
        uint256 issued;
        uint256 fundraisingGoal;
        uint256 totalInvested;
        uint256 lastPrice;
        uint256 nextPrice;
        uint256 buySlope;
        int256 yIntercept;
    }

    uint256 public constant M = 1e18;

    address public constant ETH = address(0);

    string public constant version = "1.0";

    //PermitNewAllocation(uint256 safeId,uint256 startPrice,uint256 endPrice,uint256 tokenAmount,uint256 newCommitment,uint256 nonce,uint256 deadline)
    bytes32 public constant PERMIT_NEW_ALLOCATION_TYPEHASH =
        0x92e9c7780c37c6c93752ef6c68ad3040c058ba77173b0ed956a3a1618f819712;

    //PermitBuy(uint256 safeId,uint256 amount,uint256 minimum,address to,uint256 nonce,uint256 deadline)
    bytes32 public constant PERMIT_BUY_TYPEHASH = 0x84421f8678db780b2c10d4077410bc91e97706d609e94afb205351d47cc8fadb;

    //PermitManualBuy(uint256 safeId,address[] wallets,uint256[] amounts,uint256 minimum,bool reward,uint256 nonce,uint256 deadline)
    bytes32 public constant PERMIT_MANUAL_BUY_TYPEHASH =
        0xd9203d3b21155762ffd37e68dfbb693f2f6961f3595cb66c184efb594955a38a;

    //PermitClose(uint256 safeId,uint256 newCommitment,uint8 safeType,uint256 nonce,uint256 deadline)
    bytes32 public constant PERMIT_CLOSE_TYPEHASH = 0x64b9a498601d1d198aa08f46fa2a6bacc0aed5f464b2788fbe877e489108b11b;

    //PermitConvertToSafe(uint256 safeId,uint256 newCommitment,uint256 amountInvested,address[] wallets,uint256[] amounts,uint256 nonce,uint256 deadline)
    bytes32 public constant PERMIT_CONVERT_TO_SAFE_TYPEHASH =
        0xcd8ac4b623810d8eeec7a60ee5b5dc5fd914ff5211ae448c9a49d86d92db842c;

    //PermitUpdatePrice(uint256 safeId,uint256 newPrice,uint256 nonce,uint256 deadline)
    bytes32 public constant PERMIT_UPDATE_PRICE_TYPEHASH =
        0xc732558e9f6c2037535578adcbf1ab78b7f25bd8a97bfb133dee71ab12f3c418;

    mapping(uint256 => SafeInfo) public info;

    mapping(uint256 => SafeConfig) public config;

    mapping(uint256 => SafeParams) public params;

    mapping(uint256 => mapping(address => bool)) public isAdmin;

    mapping(address => uint256) public nonces;

    modifier onlyBeneficiary(uint256 _safeId) {
        require(msg.sender == beneficiary(_safeId), "!beneficiary");
        _;
    }

    modifier onRun(uint256 _safeId) {
        require(state(_safeId) == State.Run, "!Run");
        _;
    }

    modifier onlyAdmin(uint256 _safeId) {
        require(msg.sender == beneficiary(_safeId) || isAdmin[_safeId][msg.sender], "!admin");
        _;
    }

    event Buy(uint256 indexed safe, address indexed investor, uint256 paid, uint256 received);

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name())),
                keccak256(bytes(version)),
                block.chainid,
                address(this)
            )
        );
    }

    function addAdmin(uint256 _safeId, address _admin) public onlyBeneficiary(_safeId) {
        isAdmin[_safeId][_admin] = true;
    }

    function removeAdmin(uint256 _safeId, address _admin) public onlyBeneficiary(_safeId) {
        isAdmin[_safeId][_admin] = false;
    }

    function revokeAdmin(uint256 _safeId) public onlyAdmin(_safeId) {
        isAdmin[_safeId][msg.sender] = false;
    }

    function _instantiate(
        uint256 _safeId,
        address _control,
        address payable _recipient,
        uint256 _minInvestment,
        address _token,
        address _currency,
        SafeType _safeType
    ) internal {
        info[_safeId] = SafeInfo({closed: false, safeType: _safeType, currency: _currency, token: _token});

        config[_safeId] = SafeConfig({control: _control, recipient: _recipient, minInvestment: _minInvestment});
    }

    function _configure(
        address _caller,
        uint256 _safeId,
        address _control,
        address payable _recipient,
        uint256 _minInvestment
    ) internal onRun(_safeId) {
        require(
            _caller == config[_safeId].control || _caller == beneficiary(_safeId) || isAdmin[_safeId][_caller],
            "!(beneficiary||control||admin)"
        );
        config[_safeId] = SafeConfig({recipient: _recipient, control: _control, minInvestment: _minInvestment});
    }

    function newAllocation(
        uint256 _safeId,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _tokenAmount,
        uint256 _newCommitment
    ) external onlyAdmin(_safeId) onRun(_safeId) {
        _newAllocation(_safeId, _startPrice, _endPrice, _tokenAmount, _newCommitment);
    }

    function _newAllocation(
        uint256 _safeId,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _tokenAmount,
        uint256 _newCommitment
    ) internal {
        require(_startPrice <= _endPrice, "ENDPRICE < STARTPRICE");
        SafeParams memory param = params[_safeId];
        if (param.issued == 0) {
            require(_tokenAmount != 0, "_tokenAmount 0");
            param.commitment = _newCommitment;
        }
        param.nextPrice = _startPrice;
        param.buySlope = (_endPrice - _startPrice) * 1e18 / _tokenAmount;
        param.yIntercept = int256(_startPrice) - int256(param.buySlope * param.issued / 1e18);
        param.fundraisingGoal = _tokenAmount;
        if (param.issued != 0) {
            param.commitment = (param.issued + _tokenAmount) * param.committed / param.issued;
        }
        params[_safeId] = param;
        _receiveToken(ERC20(info[_safeId].token), _tokenAmount);
    }

    function permitNewAllocation(
        uint256 _safeId,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _tokenAmount,
        uint256 _newCommitment,
        uint256 _nonce,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external onRun(_safeId) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_NEW_ALLOCATION_TYPEHASH,
                        _safeId,
                        _startPrice,
                        _endPrice,
                        _tokenAmount,
                        _newCommitment,
                        _nonce,
                        _deadline
                    )
                )
            )
        );
        address signer = ecrecover(digest, _v, _r, _s);
        require(signer == beneficiary(_safeId), "INVALID_SIGNATURE");
        require(_nonce == nonces[signer]++, "INVALID_NONCE");
        require(block.timestamp <= _deadline, "INVALID_EXPIRATION");
        _newAllocation(_safeId, _startPrice, _endPrice, _tokenAmount, _newCommitment);
    }

    function state(uint256 _safeId) public view returns (State) {
        if (info[_safeId].safeType == SafeType.Invalid) {
            return State.Invalid;
        } else if (info[_safeId].closed) {
            return State.Close;
        } else {
            return State.Run;
        }
    }

    function buy(uint256 _safeId, uint256 _amount, uint256 _minimum, address _to) external payable onRun(_safeId) {
        ERC20 token = ERC20(info[_safeId].token);
        _collectInvestment(msg.sender, _safeId, _amount);
        (uint256 bought,) = _buy(_safeId, _amount, _minimum, false);
        _payout(token, _to, bought);
        emit Buy(_safeId, msg.sender, _amount, bought);
    }

    function permitBuy(
        address _signer,
        uint256 _safeId,
        uint256 _amount,
        uint256 _minimum,
        address _to,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external payable onRun(_safeId) {
        require(_deadline >= block.timestamp, "EXPIRED");
        bytes32 digest =
            keccak256(abi.encode(PERMIT_BUY_TYPEHASH, _safeId, _amount, _minimum, _to, nonces[_signer]++, _deadline));
        digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), digest));
        address recoveredAddress = ecrecover(digest, _v, _r, _s);
        require(recoveredAddress == _signer, "INVALID_SIGNATURE");

        ERC20 token = ERC20(info[_safeId].token);
        _collectInvestment(_signer, _safeId, _amount);
        (uint256 bought,) = _buy(_safeId, _amount, _minimum, false);
        _payout(token, _to, bought);
        emit Buy(_safeId, _signer, _amount, bought);
    }

    function manualBuy(
        uint256 _safeId,
        address[] calldata _wallets,
        uint256[] calldata _amounts,
        uint256 _minimum,
        bool _reward
    ) external onlyAdmin(_safeId) onRun(_safeId) {
        require(_wallets.length == _amounts.length, "length diff");
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }
        (uint256 bought,) = _buy(_safeId, totalAmount, _minimum, _reward);
        _split(_safeId, bought, totalAmount, _amounts, _wallets, true);
    }

    function permitManualBuy(
        uint256 _safeId,
        address[] calldata _wallets,
        uint256[] calldata _amounts,
        uint256 _minimum,
        bool _reward,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external onRun(_safeId) {
        require(_deadline >= block.timestamp, "EXPIRED");
        {
            bytes32 digest = keccak256(
                abi.encode(
                    PERMIT_MANUAL_BUY_TYPEHASH,
                    _safeId,
                    keccak256(abi.encodePacked(_wallets)),
                    keccak256(abi.encodePacked(_amounts)),
                    _minimum,
                    _reward,
                    nonces[beneficiary(_safeId)]++,
                    _deadline
                )
            );
            digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), digest));
            address recoveredAddress = ecrecover(digest, _v, _r, _s);
            require(recoveredAddress == beneficiary(_safeId), "INVALID_SIGNATURE");
        }
        require(_wallets.length == _amounts.length, "length diff");
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }
        (uint256 bought,) = _buy(_safeId, totalAmount, _minimum, _reward);
        _split(_safeId, bought, totalAmount, _amounts, _wallets, true);
    }

    function close(uint256 _safeId, uint256 _newCommitment, SafeType _newType)
        external
        onlyAdmin(_safeId)
        onRun(_safeId)
    {
        info[_safeId].closed = true;
        info[_safeId].safeType = _newType;
        params[_safeId].committed = _newCommitment;
        _flushToken(ERC20(info[_safeId].token), beneficiary(_safeId), params[_safeId].fundraisingGoal);
    }

    function permitClose(
        uint256 _safeId,
        uint256 _newCommitment,
        SafeType _newType,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external onRun(_safeId) {
        require(_deadline >= block.timestamp, "EXPIRED");
        {
            bytes32 digest = keccak256(
                abi.encode(
                    PERMIT_CLOSE_TYPEHASH, _safeId, _newCommitment, _newType, nonces[beneficiary(_safeId)]++, _deadline
                )
            );
            digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), digest));
            address recoveredAddress = ecrecover(digest, _v, _r, _s);
            require(recoveredAddress == beneficiary(_safeId), "INVALID_SIGNATURE");
        }
        info[_safeId].closed = true;
        info[_safeId].safeType = _newType;
        params[_safeId].committed = _newCommitment;
        _flushToken(ERC20(info[_safeId].token), beneficiary(_safeId), params[_safeId].fundraisingGoal);
    }

    function convertToSafe(
        uint256 _safeId,
        uint256 _newCommitment,
        uint256 _amountInvested,
        address[] calldata _wallets,
        uint256[] calldata _amounts
    ) external onlyAdmin(_safeId) onRun(_safeId) {
        require(_wallets.length == _amounts.length, "length diff");
        uint256 amount = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            amount += _amounts[i];
        }
        SafeParams memory param = params[_safeId];
        if (_newCommitment == 0) {
            _newCommitment = amount * param.commitment / (param.issued + param.fundraisingGoal);
        }
        param.shareholders += amount;
        if (param.commitment == 0) {
            param.totalInvested += _amountInvested;
            param.lastPrice = _amountInvested * 1e18 / amount;
            param.yIntercept = int256(param.lastPrice);
        } else {
            param.totalInvested += _amountInvested;
            param.lastPrice = param.nextPrice;
            param.yIntercept = int256(param.nextPrice) - int256((param.buySlope) * (param.issued + amount)) / int256(M);
        }
        param.commitment += _newCommitment;
        param.committed += _newCommitment;
        param.issued += amount;
        params[_safeId] = param;
        _split(_safeId, amount, amount, _amounts, _wallets, false);
    }

    function permitConvertToSafe(
        uint256 _safeId,
        uint256 _newCommitment,
        uint256 _amountInvested,
        address[] calldata _wallets,
        uint256[] calldata _amounts,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external onRun(_safeId) {
        require(_deadline >= block.timestamp, "EXPIRED");
        {
            bytes32 digest = keccak256(
                abi.encode(
                    PERMIT_CONVERT_TO_SAFE_TYPEHASH,
                    _safeId,
                    _newCommitment,
                    _amountInvested,
                    keccak256(abi.encodePacked(_wallets)),
                    keccak256(abi.encodePacked(_amounts)),
                    nonces[beneficiary(_safeId)]++,
                    _deadline
                )
            );
            digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), digest));
            address recoveredAddress = ecrecover(digest, _v, _r, _s);
            require(recoveredAddress == beneficiary(_safeId), "INVALID_SIGNATURE");
        }
        require(_wallets.length == _amounts.length, "length diff");
        uint256 amount = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            amount += _amounts[i];
        }
        SafeParams memory param = params[_safeId];
        if (_newCommitment == 0) {
            _newCommitment = amount * param.commitment / (param.issued + param.fundraisingGoal);
        }
        param.shareholders += amount;
        if (param.commitment == 0) {
            param.totalInvested += _amountInvested;
            param.lastPrice = _amountInvested * 1e18 / amount;
            param.yIntercept = int256(param.lastPrice);
        } else {
            param.totalInvested += param.nextPrice * amount / 1e18;
            param.lastPrice = param.nextPrice;
            param.yIntercept = int256(param.nextPrice) - int256((param.buySlope) * (param.issued + amount)) / int256(M);
        }
        param.commitment += _newCommitment;
        param.committed += _newCommitment;
        param.issued += amount;
        params[_safeId] = param;
        _split(_safeId, amount, amount, _amounts, _wallets, false);
    }

    function updatePrice(uint256 _safeId, uint256 _newPrice) external onlyAdmin(_safeId) onRun(_safeId) {
        params[_safeId].yIntercept += int256(_newPrice) - int256(params[_safeId].nextPrice);
        params[_safeId].nextPrice = _newPrice;
    }

    function permitUpdatePrice(uint256 _safeId, uint256 _newPrice, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s)
        external
        onRun(_safeId)
    {
        require(_deadline >= block.timestamp, "EXPIRED");
        {
            bytes32 digest = keccak256(
                abi.encode(PERMIT_UPDATE_PRICE_TYPEHASH, _safeId, _newPrice, nonces[beneficiary(_safeId)]++, _deadline)
            );
            digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), digest));
            address recoveredAddress = ecrecover(digest, _v, _r, _s);
            require(recoveredAddress == beneficiary(_safeId), "INVALID_SIGNATURE");
        }
        params[_safeId].yIntercept += int256(_newPrice) - int256(params[_safeId].nextPrice);
        params[_safeId].nextPrice = _newPrice;
    }

    function _collectInvestment(address _from, uint256 _safeId, uint256 _amount) internal {
        if (info[_safeId].currency == ETH) {
            require(msg.value == _amount, "msg.value != _amount");
            require(_from == msg.sender, "msg.sender != _from");
            config[_safeId].recipient.transfer(_amount);
        } else {
            SafeTransferLib.safeTransferFrom(ERC20(info[_safeId].currency), _from, config[_safeId].recipient, _amount);
        }
    }

    function changeCommitment(uint256 _safeId, uint256 _commitement, uint256 _committed) external onlyAdmin(_safeId) {
        SafeParams memory param = params[_safeId];
        param.committed = _committed;
        param.commitment = _commitement;
        params[_safeId] = param;
    }

    function estimateBuyValue(uint256 _safeId, uint256 _amount) public view returns (uint256 payout) {
        SafeParams memory param = params[_safeId];
        (payout,,) = _estimateBuyValue(param, _amount);
    }

    function _estimateBuyValue(SafeParams memory _param, uint256 _amount)
        internal
        pure
        returns (uint256 payout, uint256 refund, bool overflow)
    {
        if (_param.buySlope == 0) {
            uint256 maxReceive = _param.nextPrice * _param.fundraisingGoal / M;
            if (_amount > maxReceive) {
                refund = _amount - maxReceive;
                _amount = maxReceive;
            }
            payout = _amount * M / _param.nextPrice;
        } else {
            uint256 maxReceive = MathUtils.area(
                _param.fundraisingGoal,
                _param.nextPrice,
                uint256(
                    int256(_param.buySlope * uint256(int256(_param.issued + _param.fundraisingGoal) / 1e18))
                        + _param.yIntercept
                )
            ) / (M);
            if (_amount > maxReceive) {
                refund = _amount - maxReceive;
                _amount = maxReceive;
            }
            (uint256 dx, bool o) = MathUtils.dx(
                _amount * 1e18 * M,
                uint256(int256(_param.buySlope * uint256(int256(_param.issued) / 1e18)) + _param.yIntercept),
                _param.issued,
                _param.buySlope,
                _param.yIntercept
            );
            overflow = o;
            if (overflow) {
                payout = _param.fundraisingGoal;
            } else {
                payout = dx;
            }
        }
        return (payout, refund, overflow);
    }

    function _buy(uint256 _safeId, uint256 _amount, uint256 _minimum, bool _isReward)
        internal
        returns (uint256 payout, uint256 refund)
    {
        require(_amount >= config[_safeId].minInvestment, "MIN_INVESTMENT");
        bool overflow;
        SafeParams memory param = params[_safeId];
        (payout, refund, overflow) = _estimateBuyValue(param, _amount);
        _amount = _amount - refund;
        require(payout >= _minimum, "SLIPPAGE");
        if (payout == 0) {
            return (payout, refund);
        }
        if (overflow) {
            param.fundraisingGoal = 0;
            return (payout, refund);
        }
        param.committed += param.commitment * payout / (param.issued + param.fundraisingGoal);
        param.fundraisingGoal -= payout;
        param.totalInvested += _amount;
        param.lastPrice = _amount * M / payout;
        if (param.buySlope > 0) {
            param.nextPrice = uint256(int256(param.buySlope * (param.issued + payout)) + param.yIntercept * 1e18) / 1e18;
        }
        if (_isReward) {
            param.stakeholders += payout;
        }
        param.issued += payout;
        params[_safeId] = param;
    }

    function _split(
        uint256 _safeId,
        uint256 _amount,
        uint256 _totalShare,
        uint256[] memory _shares,
        address[] memory _recipients,
        bool _isBuy
    ) internal {
        ERC20 token = ERC20(info[_safeId].token);
        for (uint256 i = 0; i < _shares.length; i++) {
            _payout(token, _recipients[i], _amount * _shares[i] / _totalShare);
            if (_isBuy) {
                emit Buy(_safeId, _recipients[i], _shares[i], _amount * _shares[i] / _totalShare);
            }
        }
    }

    function _payout(ERC20 _token, address _to, uint256 _amount) internal virtual;

    function _receiveToken(ERC20 _token, uint256 _amount) internal virtual;

    function _flushToken(ERC20 _token, address _to, uint256 _amount) internal virtual;

    function beneficiary(uint256 _safeId) public view virtual returns (address);

    function name() public view virtual returns (string memory);

    //-- helper functions --//
    function totalSupply(uint256 _safeId) external view returns (uint256 supply) {
        supply = ERC20(info[_safeId].token).totalSupply();
    }

    function changeTotalInvested(uint256 _safeId, uint256 _invested) external onlyAdmin(_safeId) {
        params[_safeId].totalInvested = _invested;
    }
}

// SPDX-License-Identifier: None

pragma solidity ^0.8.12;

/**
 * Source: https://raw.githubusercontent.com/simple-restricted-token/reference-implementation/master/contracts/token/ERC1404/ERC1404.sol
 * With ERC-20 APIs removed (will be implemented as a separate contract).
 * And adding authorizeTransfer.
 */
interface ICompliance {
    /**
     * @notice Detects if a transfer will be reverted and if so returns an appropriate reference code
     * @param from Sending address
     * @param to Receiving address
     * @param value Amount of tokens being transferred
     * @return Code by which to reference message for rejection reasoning
     * @dev Overwrite with your custom transfer restriction logic
     */
    function detectTransferRestriction(address from, address to, uint256 value) external view returns (uint8);

    /**
     * @notice Returns a human-readable message for a given restriction code
     * @param restrictionCode Identifier for looking up a message
     * @return Text showing the restriction's reasoning
     * @dev Overwrite with your custom message and restrictionCode handling
     */
    function messageForTransferRestriction(uint8 restrictionCode) external pure returns (string memory);

    /**
     * @notice Called by the DAT contract before a transfer occurs.
     * @dev This call will revert when the transfer is not authorized.
     * This is a mutable call to allow additional data to be recorded,
     * such as when the user aquired their tokens.
     */
    function authorizeTransfer(address _from, address _to, uint256 _value) external;

    function legal(address _safe) external view returns (string memory);
}

// SPDX-License-Identifier: None

pragma solidity ^0.8.0;

// Original source: openzeppelin's SignerRole
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @notice allows a single owner to manage a group of operators which may
 * have some special permissions in the contract.
 */
contract AdminOperatorRole is OwnableUpgradeable {
    mapping(address => bool) internal _admins;

    event AdminOperatorAdded(address indexed account);
    event AdminOperatorRemoved(address indexed account);

    function _initializeAdminOperatorRole() internal {
        __Ownable_init();
        _addAdminOperator(msg.sender);
    }

    modifier onlyAdminOperator() {
        require(isAdminOperator(msg.sender), "AdminOperatorRole: caller does not have the AdminOperator role");
        _;
    }

    function isAdminOperator(address account) public view returns (bool) {
        return _admins[account];
    }

    function addAdminOperator(address account) public onlyOwner {
        _addAdminOperator(account);
    }

    function addAdminOperators(address[] calldata accounts) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _addAdminOperator(accounts[i]);
        }
    }

    function removeAdminOperator(address account) public onlyOwner {
        _removeAdminOperator(account);
    }

    function removeAdminOperators(address[] calldata accounts) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _removeAdminOperator(accounts[i]);
        }
    }

    function renounceAdminOperator() public {
        _removeAdminOperator(msg.sender);
    }

    function _addAdminOperator(address account) internal {
        _admins[account] = true;
        emit AdminOperatorAdded(account);
    }

    function _removeAdminOperator(address account) internal {
        _admins[account] = false;
        emit AdminOperatorRemoved(account);
    }

    uint256[50] private ______gap;
}

// SPDX-License-Identifier: None

pragma solidity ^0.8.0;

// Original source: openzeppelin's SignerRole
import "./AdminOperator.sol";

/**
 * @notice allows a single owner to manage a group of operators which may
 * have some special permissions in the contract.
 */
contract WhitelistOperatorRole is AdminOperatorRole {
    mapping(address => mapping(address => bool)) internal _operators;

    event WhitelistOperatorAdded(address indexed safe, address indexed account);
    event WhitelistOperatorRemoved(address indexed safe, address indexed account);

    function _initializeWhitelistOperatorRole() internal {
        _initializeAdminOperatorRole();
    }

    modifier onlyWhitelistOperator(address _safe) {
        require(
            isWhitelistOperator(_safe, msg.sender) || isAdminOperator(msg.sender),
            "WhitelistOperatorRole: caller does not have the WhitelistOperator role"
        );
        _;
    }

    function isWhitelistOperator(address _safe, address account) public view returns (bool) {
        return _operators[_safe][account];
    }

    function addWhitelistOperator(address _safe, address account) public onlyAdminOperator {
        _addWhitelistOperator(_safe, account);
    }

    function addWhitelistOperators(address _safe, address[] calldata accounts) public onlyAdminOperator {
        for (uint256 i = 0; i < accounts.length; i++) {
            _addWhitelistOperator(_safe, accounts[i]);
        }
    }

    function removeWhitelistOperator(address _safe, address account) public onlyAdminOperator {
        _removeWhitelistOperator(_safe, account);
    }

    function removeWhitelistOperators(address _safe, address[] calldata accounts) public onlyAdminOperator {
        for (uint256 i = 0; i < accounts.length; i++) {
            _removeWhitelistOperator(_safe, accounts[i]);
        }
    }

    function renounceWhitelistOperator(address _safe) public {
        _removeWhitelistOperator(_safe, msg.sender);
    }

    function _addWhitelistOperator(address _safe, address account) internal {
        _operators[_safe][account] = true;
        emit WhitelistOperatorAdded(_safe, account);
    }

    function _removeWhitelistOperator(address _safe, address account) internal {
        _operators[_safe][account] = false;
        emit WhitelistOperatorRemoved(_safe, account);
    }

    uint256[50] private ______gap;
}

// SPDX-License-Identifier: None

pragma solidity ^0.8.15;

library MathUtils {
    function square(uint256 x) internal pure returns (uint256 y) {
        y = x * x;
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        unchecked {
            if (x == 0) {
                return 0;
            } else if (x <= 3) {
                return 1;
            } else if (x == type(uint256).max) {
                // Without this we fail on x + 1 below
                return 2 ** 128 - 1;
            }

            uint256 z = (x + 1) / 2;
            y = x;
            while (z < y) {
                y = z;
                z = (x / z + z) / 2;
            }
        }
    }

    function area(uint256 _dx, uint256 y1, uint256 y2) internal pure returns (uint256 z) {
        z = _dx * (y1 + y2) / 2;
    }

    function gety(uint256 x, uint256 slope, int256 intercept) internal pure returns (int256 y) {
        y = int256(x * slope) + intercept;
    }

    function dx(uint256 _area, uint256 y, uint256 x, uint256 slope, int256 intercept)
        internal
        pure
        returns (uint256 d, bool overflow)
    {
        d = uint256(int256(sqrt(square(y * 1e18) + 2 * slope * _area)) - intercept * 1e18);
        if (d / slope < x) {
            d = 0;
            overflow = true;
        } else {
            d = d / slope - x;
            overflow = false;
        }
    }
}