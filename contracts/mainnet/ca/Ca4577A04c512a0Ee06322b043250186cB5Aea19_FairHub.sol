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
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822ProxiableUpgradeable {
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
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeaconUpgradeable {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeaconUpgradeable.sol";
import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/StorageSlotUpgradeable.sol";
import "../utils/Initializable.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967UpgradeUpgradeable is Initializable {
    function __ERC1967Upgrade_init() internal onlyInitializing {
    }

    function __ERC1967Upgrade_init_unchained() internal onlyInitializing {
    }
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
        return StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(AddressUpgradeable.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
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
            _functionDelegateCall(newImplementation, data);
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
        if (StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822ProxiableUpgradeable(newImplementation).proxiableUUID() returns (bytes32 slot) {
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
        return StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
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
        return StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(AddressUpgradeable.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            AddressUpgradeable.isContract(IBeaconUpgradeable(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value = newBeacon;
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
            _functionDelegateCall(IBeaconUpgradeable(newBeacon).implementation(), data);
        }
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/Initializable.sol)

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
        if (_initialized < type(uint8).max) {
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
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../ERC1967/ERC1967UpgradeUpgradeable.sol";
import "./Initializable.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822ProxiableUpgradeable, ERC1967UpgradeUpgradeable {
    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }

    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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

// SPDX-License-Identifier: MIT
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
library StorageSlotUpgradeable {
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
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

// Package imports
import { FairHubStorage } from "./storage/FairHubStorage.sol";
import { IFairHub } from "../interfaces/IFairHub.sol";
import { Raffle } from "./Raffle.sol";
import { DataTypes } from '../libraries/DataTypes.sol';
import { Events } from "../libraries/Events.sol";
import { Errors } from "../libraries/Errors.sol";
// Third party imports
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title FairHub
 * @author API3 Latam
 *
 * @notice Entrypoint to the Fair Platform made by API3 Latam Team.
 * Currently it only provides the creation interface for raffles,
 * but more products will be added soon!
 * @dev Contracts are expected to provide a proxy for each user journey.
 * So it will differ per product and time, so make sure to know which
 * proxy you're using in each interaction.
 */
contract FairHub is
    UUPSUpgradeable,
    OwnableUpgradeable,
    FairHubStorage,
    IFairHub
{
    using Counters for Counters.Counter;

    // ========== Initializer/Constructor ==========
    /**
     * @dev Run the initializer instead of constructor in an upgradeable contract.
     */
    constructor () {
        _disableInitializers();
    }
    
    /**
     * @dev See { IFairHub-initialize }.
     */
    function initialize (
        address _raffleBeacon
    ) external override initializer {
        if (_raffleBeacon == address(0)) {
            revert Errors.InvalidProxyAddress(_raffleBeacon);
        }

        raffleBeacon = _raffleBeacon;

        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    // ========== Upgrade Functions ==========
    /**
     * @dev See { UUPSUpgradeable-_authorizeUpgrade }.
     */
    function _authorizeUpgrade (
        address
    ) internal override onlyOwner {}

    /**
     * @dev See { IFairHub-getVersion }.
     */
    function getVersion ()
     external pure returns (
        uint256 version
    ) {
        return 1;
    }

        // ========== Get/Set Functions ==========
    /**
     * @dev See { IFairHub-getRaffleCount }.
     */
    function getRaffleCount()
     external view returns (
        uint256 _counter
     ) {
        return _raffleCounter.current();
     }

    /**
     * @dev See { IFairHub-getRaffleAddress }.
     */
    function getRaffleAddress (
        uint256 _raffleId
    ) external view override returns (
        address _proxyAddress
    ) {
        return raffles[_raffleId];
    }

    /**
     * @dev See { IFairHub-getOwnedRaffles }.
     */
    function getOwnedRaffles ()
     external view override returns (
        uint256[] memory _raffleIds
    ) {
        return ownedRaffles[msg.sender];
    }

    /**
     * @dev See { IFairHub-setVaultFactoryAddress }.
     */
    function setVaultFactoryAddress (
        address _vaultFactoryAddress
    ) external onlyOwner {
        vaultFactoryAdress = _vaultFactoryAddress;
    }

    /**
     * @dev See { IFairHub-setDepositRouterAddress }.
     */
    function setDepositRouterAddress (
        address _depositRouterAddress
    ) external onlyOwner {
        depositRouterAddress = _depositRouterAddress;
    }

    /**
     * @dev See { IFairHub-setTreasuryAddress }
     */
    function setTreasuryAddress (
        address _treasuryAddress
    ) external onlyOwner {
        // Parameters validation.
        if (
            _treasuryAddress == address(0)
        ) {
            revert Errors.InvalidParameter();
        }
        if (
            _treasuryAddress == treasuryAddress
        ) {
            revert Errors.SameValueProvided();
        }

        // Set new treasury address.
        treasuryAddress = _treasuryAddress;
    }   

    /**
     * @dev See { IFairHub-setRaffleCut }
     */ 
    function setRaffleCut (
        uint256 _raffleCut
    ) external onlyOwner {
        // Parameters validation.
        if (
            _raffleCut > 100
        ) {
            revert Errors.InvalidParameter();
        }
        if (
            _raffleCut == raffleCut
        ) {
            revert Errors.SameValueProvided();
        }

        // Set new raffle cut.
        raffleCut = _raffleCut;
    }

    // ========== Core Functions ==========
    /**
     * @dev See { IFairHub-createRaffle }.
     */
    function createRaffle (
        uint256 startTime,
        uint256 expectedEndTime,
        uint256 winnerNumber,
        uint256 ticketPrice,
        uint256 requiredBalance,
        DataTypes.Multihash memory metadata
    ) external {
        _raffleCounter.increment();
        uint256 _id = _raffleCounter.current();

        bytes memory _data = abi.encodeWithSelector(
            Raffle.initialize.selector,
            msg.sender,
            _id,
            startTime,
            expectedEndTime,
            winnerNumber,
            ticketPrice,
            requiredBalance,
            raffleCut,
            metadata,
            vaultFactoryAdress,
            depositRouterAddress,
            treasuryAddress
        );

        BeaconProxy _raffle = new BeaconProxy (
            address(raffleBeacon),
            _data
        );

        raffles[_id] = address(_raffle);
        ownedRaffles[msg.sender].push(_id);

        emit Events.RaffleCreated(_id);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

// Package imports
import { RaffleStorage } from "./storage/RaffleStorage.sol";
import { IRaffle } from "../interfaces/IRaffle.sol";
import { IWinnerAirnode } from "../interfaces/IWinnerAirnode.sol";
import { IAssetVault } from "../interfaces/IAssetVault.sol";
import { IVaultFactory } from "../interfaces/IVaultFactory.sol";
import { IVaultDepositRouter } from "../interfaces/IVaultDepositRouter.sol";
import { DataTypes } from "../libraries/DataTypes.sol";
import { Events } from "../libraries/Events.sol";
import { Errors } from "../libraries/Errors.sol";
// Third party imports
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol"; 

/**
 * @title Raffle
 * @author API3 Latam
 *
 * @notice This is the implementation of the Raffle contract.
 * Including all the logic to operate an individual Raffle.
 */
contract Raffle is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    RaffleStorage,
    IRaffle
{
    // ========== Libraries ==========
    using Address for address;
    using Address for address payable;

    // ========== Modifiers ==========
    /**
     * @notice Verifies whether the status is equal to 'Open' or not.
     * @dev Reverts with 'RaffleNotOpen' error.
     */
    modifier isOpen() {
        if (status != DataTypes.RaffleStatus.Open) {
            revert Errors.RaffleNotOpen();
        }
        _;
    }

    /**
     * @notice Verifies wether the status is equal to 'Open' or Unintialized.
     * @dev Reverts with 'RaffleNotAvailable' error.
     */
    modifier isAvailable() {
        if (!(status == DataTypes.RaffleStatus.Unintialized ||
                status == DataTypes.RaffleStatus.Open)) {
            revert Errors.RaffleNotAvailable();
        }
        _;
    }

    /**
     * @notice Verifies wether the time for the raffle is still valid.
     * @dev Reverts with 'RaffleDue' error.
     */
    modifier notDue() {
        if ( block.timestamp > expectedEndTime ) {
            revert Errors.RaffleDue();
        }
        _;
    }

    // ========== Constructor/Initializer ==========
    /**
     * @dev Disables initializers, so contract can only be used trough proxies.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev See { IRaffle-initialize }.
     */
    function initialize (
        address _creatorAddress,
        uint256 _raffleId,
        uint256 _startTime,
        uint256 _expectedEndTime,
        uint256 _winnerNumber,
        uint256 _ticketPrice,
        uint256 _requiredBalance,
        uint256 _poolCut,
        DataTypes.Multihash memory _metadata,
        address _vaultFactory,
        address _vaultRouter,
        address _treasury
    ) external initializer nonReentrant {
        // Parameters' validations.
        if (
            _startTime < block.timestamp
        ) revert Errors.WrongInitializationParams(
            "Raffle: Invalid `startTime` parameter."
        );
        if (
            _expectedEndTime < _startTime
        ) revert Errors.WrongInitializationParams(
            "Raffle: Invalid `endTime` parameter."
        );
        if (
            _winnerNumber <= 0
        ) revert Errors.WrongInitializationParams(
            "Raffle: Invalid `winnerNumber` parameter."
        );
        if (
            _poolCut > 100
        ) revert Errors.WrongInitializationParams(
            "Raffle: Invalid `poolCut` parameter."
        );
        if (
            _vaultFactory == address(0)
        ) revert Errors.WrongInitializationParams(
            "Raffle: Invalid `vaultFactory` parameter."
        );
        if (
            _vaultRouter == address(0)
        ) revert Errors.WrongInitializationParams(
            "Raffle: Invalid `vaultRouter` parameter."
        );
        if (
            _treasury == address(0)
        ) revert Errors.WrongInitializationParams(
            "Raffle: Invalid `treasury` parameter."
        );

        // Set the parameters in storage.
        creatorAddress = _creatorAddress;
        status = DataTypes.RaffleStatus.Unintialized;
        raffleId = _raffleId;
        startTime = _startTime;
        expectedEndTime = _expectedEndTime;
        winnerNumber = _winnerNumber;
        ticketPrice = _ticketPrice;
        requiredBalance = _requiredBalance;
        poolCut = _poolCut;
        metadata = _metadata;
        vaultFactory = _vaultFactory;
        vaultRouter = _vaultRouter;
        treasury = _treasury;

        // Initialize the inheritance chain.
        __Ownable_init();
        __ReentrancyGuard_init();

        // Execute setup functions.
        _transferOwnership(
            _creatorAddress
        );
    }

    // ========== Upgradability ==========
    /**
     * @dev See { IRaffle-getVersion }.
     */
    function getVersion ()
     external pure returns (
        uint256 version
    ) {
        return 1;
    }

    // ========== Get/Set Functions ==========
    /**
     * @dev See { IRaffle-setRequester }.
     */
    function setRequester (
        address _requester
    ) external onlyOwner isAvailable {
        if (winnerRequester == _requester) revert Errors.SameValueProvided();
        if (_requester == address(0)) revert Errors.ZeroAddress();

        winnerRequester = _requester;
    }

    /**
     * @dev See { IRaffle-updateWinners }.
     */
    function updateWinners (
        uint256 _winnerNumbers
    ) external override onlyOwner {
        if (
            status != DataTypes.RaffleStatus.Unintialized
        ) revert Errors.RaffleAlreadyOpen();
        if (
            _winnerNumbers <= 0
        ) revert Errors.InvalidWinnerNumber();

        winnerNumber = _winnerNumbers;
    }

    /**
     * @dev See { IRaffle-updateMetadata }
     */
    function updateMetadata (
        DataTypes.Multihash memory _metadata
    ) external override onlyOwner {
        metadata = _metadata;
    }

    /**
     * @dev See { IRaffle-setBeneficiaries }
     */
    function setBeneficiaries (
        address[] memory _beneficiaries,
        uint256[] memory _shares
    ) external override onlyOwner isAvailable {
        // Initial validation.
        if (
            _beneficiaries.length != _shares.length
        ) revert Errors.BatchLengthMismatch();

        for (uint256 i; i < _beneficiaries.length; i++) {
            // Additional validations.
            if (
                _beneficiaries[i] == address(0)
            ) revert Errors.ZeroAddress();
            if (
                _beneficiaries[i].isContract()
            ) revert Errors.InvalidAddress();
            if (
                _shares[i] == 0
            ) revert Errors.InvalidParameter();
            if (
                shares[_beneficiaries[i]] > 0
            ) revert Errors.ParameterAlreadySet();

            // Save the parameters in storage.
            beneficiaries.push(_beneficiaries[i]);
            shares[_beneficiaries[i]] = _shares[i];
            totalShare += _shares[i];
        }

        if (
            totalShare > 100
        ) revert Errors.InvalidParameter();

        // Emit function event.
        emit Events.SetRaffleBeneficiaries (
            _beneficiaries,
            _shares,
            raffleId,
            block.timestamp
        );
    }

    /**
     * @dev See { IRaffle-updateBeneficiary }
     */
    function updateBeneficiary (
        address _beneficiary,
        uint256 _share
    ) external override onlyOwner isAvailable {
        // Initial validation.
        if (
            _beneficiary == address(0)
        ) revert Errors.ZeroAddress();
        if (
            _beneficiary.isContract()
        ) revert Errors.InvalidAddress();
        if (
            _share == 0
        ) revert Errors.InvalidParameter();
        if (
            shares[_beneficiary] == 0
        ) revert Errors.ParameterNotSet();

        uint256 oldShare = shares[_beneficiary];
        // Save the parameters in storage.
        totalShare -= shares[_beneficiary];
        shares[_beneficiary] = _share;
        totalShare += _share;

        if (
            totalShare > 100
        ) revert Errors.InvalidParameter();

        emit Events.UpdateRaffleBeneficiary (
            _beneficiary,
            oldShare,
            _share,
            raffleId,
            block.timestamp
        );
    }

    // ========== Core Functions ==========
    /**
     * @dev See { IRaffle-open }.
     */
    function open (
        address[] memory _tokens,
        uint256[] memory _ids
    ) external onlyOwner nonReentrant notDue {
        // Parameters' Validations.
        if (
            status != DataTypes.RaffleStatus.Unintialized
        ) revert Errors.RaffleAlreadyOpen();
        if (
            _tokens.length != winnerNumber
        ) revert Errors.InvalidWinnerNumber();
        if (
            _tokens.length != _ids.length
        ) revert Errors.BatchLengthMismatch();

        // Create the vaults for the raffle.
        IVaultFactory vFactory = IVaultFactory(vaultFactory);
        IVaultDepositRouter vRouter = IVaultDepositRouter(vaultRouter);

        (prizesVaultId, prizesVaultAddress) = vFactory.create(address(this));
        (ticketsVaultId, ticketsVaultAddress) = vFactory.create(address(this));

        // Deposit the prizes in the vaults.
        vRouter.depositERC721(
            owner(),
            prizesVaultId,
            _tokens,
            _ids
        );
        
        // Save the parameters in storage.
        status = DataTypes.RaffleStatus.Open;
        tokens = _tokens;
        ids = _ids;

        // Emit function event.
        emit Events.RaffleOpened(
            raffleId,
            prizesVaultId,
            ticketsVaultId,
            _tokens.length,
            block.timestamp
        );
    }

    /**
     * @dev See { IRaffle-enter }.
     */
    function enter (
        address _participantAddress,
        uint256 _amount
    ) external override payable isOpen {
        // Validates the raffle status.
        if (
            (
                requiredBalance == 0 ||
                ticketsVaultAddress.balance > requiredBalance
            ) &&
            block.timestamp > expectedEndTime
        ) revert Errors.RaffleDue();

        // Additional parameters' validations.
        if (
            _amount == 0
        ) revert Errors.InvalidAmount();
        if (
            _participantAddress == address(0)
        ) revert Errors.ZeroAddress();
        if (
            _participantAddress.isContract()
        ) revert Errors.InvalidAddress();

        // Save the participant in the raffle storage.
        for (uint256 i = 0; i < _amount; i++) {
            participants.push(_participantAddress);

            if (
                entries[_participantAddress] == 0
            ) entries[_participantAddress] = 1;
            else entries[_participantAddress]++;
        }
        
        if (ticketPrice > 0) {
            uint256 totalAmount = _amount * ticketPrice;

            // Check whether the user sent the correct amount.
            if (
                msg.value != totalAmount
            ) revert Errors.InvalidAmount();

            // Send the actual funds to the vault.
            payable(ticketsVaultAddress).sendValue(totalAmount);

            // Register the transaction in the router.
            IVaultDepositRouter vRouter = IVaultDepositRouter(vaultRouter);
            vRouter.depositNative(
                _participantAddress,
                ticketsVaultAddress,
                totalAmount
            );
        }

        // Emit function event.
        emit Events.RaffleEntered(
            raffleId,
            _participantAddress,
            _amount,
            block.timestamp
        );
    }

    /**
     * @dev See { IRaffle-close }.
     * TODO: Add handling of endless raffles
     */
    function close ()
     external override nonReentrant isOpen {
        // Validates the raffle status.
        if (
            requiredBalance == 0
        ) {
            if (
                block.timestamp < expectedEndTime
            ) revert Errors.EarlyClosing();
        } else {
            if (
                msg.sender != owner() &&
                msg.sender != IVaultFactory(vaultFactory).owner()
            ) revert Errors.CallerNotOwner(msg.sender);

            if (
                ticketsVaultAddress.balance < requiredBalance
            ) revert Errors.EarlyClosing();
        }
        
        // Additional parameters' validations.
        if (
            winnerRequester == address(0)
        ) revert Errors.ParameterNotSet();

        status = DataTypes.RaffleStatus.Close;

        IWinnerAirnode airnode = IWinnerAirnode(winnerRequester);
        IAssetVault prizeVault = IAssetVault(prizesVaultAddress);
        IAssetVault ticketVault = IAssetVault(ticketsVaultAddress);
        
        if (winnerNumber == 1) {
            requestId = airnode.requestWinners (
                airnode.getIndividualWinner.selector, 
                winnerNumber, 
                participants.length
            );
        } else {
            requestId = airnode.requestWinners (
                airnode.getMultipleWinners.selector, 
                winnerNumber, 
                participants.length
            );
        }

        prizeVault.enableWithdraw();
        ticketVault.enableWithdraw();

        // Emit function event.
        emit Events.RaffleClosed(
            raffleId,
            requestId,
            block.timestamp
        );
    }

    /**
     * @dev See { IRaffle-finish }.
     */
    function finish () 
     external override nonReentrant {
        // Parameters' validations.
        if (
            status != DataTypes.RaffleStatus.Close
        ) revert Errors.RaffleNotClose();

        status = DataTypes.RaffleStatus.Finish;
        uint256 pvBalance = ticketsVaultAddress.balance;
        uint256 treasuryCut = (pvBalance * poolCut) / 100;
        uint256 availableVault = pvBalance - treasuryCut;

        IWinnerAirnode airnode = IWinnerAirnode(winnerRequester);
        IAssetVault prizeVault = IAssetVault(prizesVaultAddress);
        IAssetVault ticketVault = IAssetVault(ticketsVaultAddress);

        // Request results and update winners.
        DataTypes.WinnerReponse memory winnerResults =  airnode.requestResults(
            requestId
        );

        for (uint256 i; i < winnerNumber; i++) {
            winners.push(
                participants[winnerResults.winnerIndexes[i]]
            );
        }

        // Withdraw assets from vaults.
        for (uint256 i; i < winners.length; i++) {
            prizeVault.withdrawERC721(
                tokens[i],
                ids[i],
                winners[i]
            );
        }

        if (treasuryCut > 0) {
            ticketVault.withdrawNative(
                treasury,
                treasuryCut
            );
        }
        
        if (
            beneficiaries.length > 0
        ) {
            uint256[] memory _percentages;
            address payable[] memory _payableReceivers;
        
            if (
                totalShare < 100
            ) {
                _percentages = new uint256[](beneficiaries.length + 1);
                _payableReceivers = new address payable[](beneficiaries.length + 1);
                
                for (uint256 i; i < beneficiaries.length; i++) {
                    _percentages[i] = shares[beneficiaries[i]];
                    _payableReceivers[i] = payable(beneficiaries[i]);
                }
                
                _percentages[beneficiaries.length] = 100 - totalShare;
                _payableReceivers[beneficiaries.length] = payable(creatorAddress);
            } else {
                _percentages = new uint256[](beneficiaries.length);
                _payableReceivers = new address payable[](beneficiaries.length);
                
                for (uint256 i; i < beneficiaries.length; i++) {
                    _percentages[i] = shares[beneficiaries[i]];
                    _payableReceivers[i] = payable(beneficiaries[i]);
                }
            }
        
            ticketVault.batchWithdrawNative(
                _payableReceivers,
                _percentages
            );
        } else {
            ticketVault.withdrawNative(
                creatorAddress,
                availableVault
            );
        }

        // Emit function event.
        emit Events.RaffleFinished(
            raffleId,
            winners,
            availableVault,
            treasuryCut,
            block.timestamp
        );
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title FairHubStorage
 * @author API3 Latam
 *
 * @notice This is an abstract contract that *only* contains storage for the FairHub contract.
 * This *must* be inherited last in order to preserve the storage layout.
 * Adding storage variables should be done solely at the bottom of this contract.
 */
abstract contract FairHubStorage {
    // ========== Address ==========
    address public raffleBeacon;            // Raffle beacon address.
    address public vaultFactoryAdress;      // Current Vault Factory address.
    address public depositRouterAddress;    // Current Vault Deposit Router address.
    address internal treasuryAddress;       // Treasury address of the platform.

    // ========== Uint256 ==========
    uint256 public raffleCut;                   // Percentage of the raffle cut.
    Counters.Counter internal _raffleCounter;   // Individual Raffle identifier.

    // Mapping of raffle id with its contract
    mapping(uint256 => address) public raffles;
    // Mapping of owner addresses with its owned raffle ids.
    mapping(address => uint256[]) public ownedRaffles;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

// Package imports
import { DataTypes } from "../../libraries/DataTypes.sol";

/**
 * @title RaffleStorage
 * @author API3 Latam
 *
 * @notice This is an abstract contract that contains the storage layout
 * for the `Raffle` contract.
 * This must be inherited last in order to preserve the storage layout.
 * Adding storage variables should be done solely at the bottom of this contract.
 */
abstract contract RaffleStorage {
    // ========== Raffle State ==========
    uint256 public raffleId;                    // The id of this raffle contract.
    address public creatorAddress;              // The address from the creator of the raffle.
    uint256 public winnerNumber;                // The number of winners for this raffle.
    uint256 public startTime;                   // The starting time for the raffle.
    uint256 public expectedEndTime;             // The expected end time for the raffle.
    uint256 public ticketPrice;                 // The price of each ticket.
    uint256 public requiredBalance;             // The required balance for not canceling the raffle.
    uint256 public poolCut;                     // The percentage of the pool to be shared with QF.
    DataTypes.RaffleStatus public status;       // The status of the raffle.
    DataTypes.Multihash public metadata;        // The metadata information for this raffle.
    address[] public participants;              // The addresses of the participants.
    
    // ========== Requester Related ==========
    address public winnerRequester;             // The address of the requester being use.
    bytes32 public requestId;                   // The id for this raffle airnode request.

    // ========== Prizes ==========
    address[] public winners;                   // Winner addresses for this raffle.
    address[] public tokens;                    // Tokens to be set as prize.
    uint256[] public ids;                       // TokenIds to be set as prize.

    // ========== Beneficiaries ==========
    address[] public beneficiaries;             // Beneficiaries addresses for this raffle.
    uint256 internal totalShare;                // Total share of the pool to be shared with the beneficiaries.

    // ========== Vault Related ==========
    address public vaultFactory;                // VaultFactory Proxy address to interact with.
    address public vaultRouter;                 // VaultDepositRouter Proxy.
    uint256 public prizesVaultId;               // Prizes Vault Token Id for ownership validation.
    address public prizesVaultAddress;          // Prizes Vault Token Address.
    uint256 public ticketsVaultId;              // Tickets Vault Token Id for ownership validation.
    address public ticketsVaultAddress;         // Tickets Vault Token Address.
    address internal treasury;                  // The treasury address to deposit the cut to.

    // ========== Mappings ==========
    mapping(address => uint256) public entries; // Amount of entries for a given user.
    mapping(address => uint256) public shares; // Amount of shares for a given beneficiary.
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/**
 * @title IAssetVault
 * @author API3 Latam
 *
 * @notice This is the interface for the AssetVault contract,
 * which is utilized for safekeeping of assets during Hub
 * user flows, like 'Raffles'.
 *
 * This contract is based from the arcadexyz repository `v2-contracts`.
 * You can found it at this URL:
 * https://github.com/arcadexyz/v2-contracts/blob/main/contracts/interfaces/IAssetVault.sol
 */
interface IAssetVault {
    // ================ Initialize ================
    /**
     * @notice Initializer for the logic contract trough the minimal clone proxy.
     * @dev In practice, always called by the VaultFactory contract.
     *
     * @param _distributorAddress The address of the distributor contract.
     */
    function initialize (
        address _distributorAddress
    ) external;

    // ========== Core Functions ==========
    /**
     * @notice Enables withdrawals on the vault.
     * @dev Any integration should be aware that a withdraw-enabled vault cannot
     * be transferred (will revert).
     */
    function enableWithdraw () 
     external;

    /**
     * @notice Withdraw entire balance of a given ERC721 token from the vault.
     * The vault must be in a "withdrawEnabled" state (non-transferrable).
     * The specified token must exist and be owned by this contract.
     *
     * @param token The token to withdraw.
     * @param tokenId The ID of the NFT to withdraw.
     * @param to The recipient of the withdrawn token.
     */
    function withdrawERC721 (
        address token,
        uint256 tokenId,
        address to
    ) external;

    /**
     * @notice Withdraw entire balance of native tokens from the vault.
     *
     * @param to The recipient of the withdrawn funds.
     * @param amount The amount of native tokens to withdraw.
     */
    function withdrawNative (
        address to,
        uint256 amount
    ) external;

    /**
     * @notice Withdraw entire balance of native tokens from the vault.
     *
     * @param _recipients The recipients of the withdrawn funds.
     * @param _percentages The percentages of the vault per each recipient.
     */
    function batchWithdrawNative (
        address payable[] memory _recipients,
        uint256[] memory _percentages
    ) external;

    // ========== Get/Set Functions ==========
    /**
     * @notice Default view function for public value `withdrawEnabled`.
     *
     * @return withdrawEnabled Either true or false depending on the state. 
     */
    function withdrawEnabled ()
     external view returns (
        bool withdrawEnabled
    );
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import { DataTypes } from '../libraries/DataTypes.sol';

/**
 * @title IRaffleHub
 * @author API3 Latam
 *
 * @notice This is the interface for the Raffle Manager,
 * The contract from which users will be able to create raffles.
 */
interface IFairHub {
    // ================ Initialize ================
    /**
     * @notice Initializer for the logic contract trough the UUPS Proxy.
     *
     * @param _raffleBeacon The beacon to use for raffle proxies.
     */
    function initialize (
        address _raffleBeacon
    ) external;

    // ================ Upgrade Functions ================
    /**
     * @notice Returns the current implementation version for this contract.
     * @dev This version will be manually updated on each new contract version deployed.
     *
     * @return version The current version of the implementation.
     */
    function getVersion ()
     external pure returns (
        uint256 version
    );

    // ========== Get/Set Functions ==========
    /**
     * @notice Gets the current counter for the raffle ids.
     *
     * @return _counter The current counter value.
     */
    function getRaffleCount()
        external view returns (
            uint256 _counter
        );

    /**
     * @notice Gets the address from the raffle proxy of a given id.
     *
     * @return _proxyAddress The address of the proxy.
     */
    function getRaffleAddress (
        uint256 _raffleId
    ) external view returns (
        address _proxyAddress
    );

    /**
     * @notice Gets the function caller owned raffle ids.
     *
     * @return _raffleIds An array of raffle ids.
     */
    function getOwnedRaffles () 
     external view returns (
        uint256[] memory _raffleIds
     );

    /**
     * @notice Sets the current vault factory address.
     * @dev This function is only callable by the owner.
     *
     * @param _vaultFactoryAddress The new vault factory address.
     */
    function setVaultFactoryAddress (
        address _vaultFactoryAddress
    ) external;

    /**
     * @notice Sets the current deposit router address.
     * @dev This function is only callable by the owner.
     *
     * @param _depositRouterAddress The new deposit router address.
     */
    function setDepositRouterAddress (
        address _depositRouterAddress
    ) external;

    /**
     * @notice Sets the current treasury address.
     * @dev This function is only callable by the owner.
     *
     * @param _treasuryAddress The new treasury address.
     */
    function setTreasuryAddress (
        address _treasuryAddress
    ) external;

    // ========== Core Functions ==========
    /**
     * @notice Creates a new Raffle Proxy from a given implementation.
     * @dev Uses the beacon to get the current implementation contract.
     *
     * @param startTime The starting time for the raffle.
     * @param endTime The end time for the raffle.
     * @param winnerNumber The initial number to set as total winners.
     * @param ticketPrice The price for each ticket.
     * @param requiredBalance The minimum amount of tokens required to close the raffle.
     * @param metadata The `Multihash` information for this raffle metadata.
     */
    function createRaffle (
        uint256 startTime,
        uint256 endTime,
        uint256 winnerNumber,
        uint256 ticketPrice,
        uint256 requiredBalance,
        DataTypes.Multihash memory metadata
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

// Package imports
import { DataTypes } from '../libraries/DataTypes.sol';

/**
 * @title IRaffle
 * @author API3 Latam
 *
 * @notice This is the interface for the Raffle contract,
 * which is initialized everytime a new raffle is requested.
 */
interface IRaffle {
  // ================ Initialize ================
  /**
   * @notice Initializer function for proxy pattern.
   * @dev This replaces the constructor so we can utilize it on every new proxy.
   * NOTE: This is set to be initialized/parametrized trough the FairHub.
   *
   * @param _creatorAddress The raffle creator.
   * @param _raffleId The id for this raffle.
   * @param _startTime The starting time for the raffle.
   * @param _expectedEndTime The expected end time for the raffle.
   * @param _winnerNumber The initial number to set as total winners.
   * @param _ticketPrice The ticket price to charge on native tokens for each unique entry per participant.
   * @param _requiredBalance The required balance for not canceling the raffle.
   * @param _poolCut The percentage of the pool to be shared with QF.
   * @param _metadata The `Multihash` struct information for this raffle metadata.
   * @param _vaultFactory The VaultFactory proxy address to use.
   * @param _vaultRouter The VauldDepositRouter Proxy to use.
   * @param _treasury The treasury address to deposit the cut to.
   */
  function initialize (
    address _creatorAddress,
    uint256 _raffleId,
    uint256 _startTime,
    uint256 _expectedEndTime,
    uint256 _winnerNumber,
    uint256 _ticketPrice,
    uint256 _requiredBalance,
    uint256 _poolCut,
    DataTypes.Multihash memory _metadata,
    address _vaultFactory,
    address _vaultRouter,
    address _treasury
  ) external;

  // ========== Core Functions ==========
  /**
   * @notice Opens a raffle to the public,
   * and safekeeps the assets in the corresponding vaults.
   * @dev `_tokens`, `_ids` and `winnerNumber` should match.
   *
   * @param _tokens The tokens addresses to use for prizes.
   * @param _ids The id for the respective address in the array of `_tokens`.
   */
  function open (
    address[] memory _tokens,
    uint256[] memory _ids
  ) external;

  /**
    * @notice Enter the raffle.
    * @dev Verified wether raffle is Open and on time.
    *
    * @param _participantAddress The participant address.
    * @param _amount The amount of tickets to buy.
    */
  function enter (
      address _participantAddress,
      uint256 _amount
  ) external payable;

  /**
    * @notice Closes the ongoing raffle.
    * @dev Called by the owner when the raffle is over.
    * This function stops new entries from registering and will
    * call a QRNG requester.
    */
  function close () external;

  /**
    * @notice Wrap ups a closed raffle.
    * @dev This function updates the winners as result from calling the airnode,
    * and distribute the prizes.
    */
  function finish () external;

  // ========== Get/Set Functions ==========
  /**
    * @notice Set address for winnerRequester.
    *
    * @param _requester The address of the requester contract.
    */
  function setRequester (
        address _requester
    ) external;

  /**
    * @notice Update the set number of winners.
    *
    * @param _winnerNumbers The new number of winners for this raffle.
    */
  function updateWinners(
    uint256 _winnerNumbers
  ) external;

  /**
    * @notice Update the metadata for the raffle.
    *
    * @param _metadata The new metadata struct.
    */
  function updateMetadata(
    DataTypes.Multihash memory _metadata
  ) external;

  /**
   * @notice Set the beneficiaries for this raffle.
   * 
   * @param _beneficiaries The addresses of the beneficiaries.
   * @param _shares The shares for each beneficiary.
   */
  function setBeneficiaries (
    address[] memory _beneficiaries,
    uint256[] memory _shares
  ) external;

  /**
   * @notice Update a given beneficiary share.
   *
   * @param _beneficiary The address of the beneficiary.
   * @param _share The new share for the beneficiary.
   */
  function updateBeneficiary (
    address _beneficiary,
    uint256 _share
  ) external;

  // ========== Upgradability ==========
  /**
    * @notice Returns the current implementation version for this contract.
    * @dev This version will be manually updated on each new contract version deployed.
    *
    * @return version The current version of the implementation.
    */
  function getVersion ()
    external pure returns (
      uint256 version
  );
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/**
 * @title IVaultDepositRouter.
 * @author API3 Latam.
 *
 * @notice Interface for VaultDepositRouter.
 */
interface IVaultDepositRouter {
    // ================ Initialize ================
    /**
     * @notice Initializer for the logic contract trough the UUPS Proxy.
     *
     * @param _factoryAddress The address to use for the factory interface.
     */
    function initialize (
        address _factoryAddress
    ) external;

    // ========== Upgrade Functions ==========
    /**
     * @notice Updates the VaultFactory implementation address.
     *
     * @param newImplementation The address of the upgraded version of the contract.
     */
    function upgradeFactory (
        address newImplementation
    ) external;

    /**
     * @notice Returns the current implementation version for this contract.
     * @dev This version will be manually updated on each new contract version deployed.
     *
     * @return version The current version of the implementation.
     */
    function getVersion ()
     external pure returns (
        uint256 version
    );

    // ========== Core Functions ==========
    /**
     * @notice Deposit ERC721 tokens to the vault.
     *
     * @param owner The address of the current owner of the token.
     * @param vault The vault to deposit to.
     * @param tokens The token to deposit.
     * @param ids The ID of the token to deposit, for each token.
     */
    function depositERC721 (
        address owner,
        uint256 vault,
        address[] calldata tokens,
        uint256[] calldata ids
    ) external;

    /**
     * @notice Transfer native tokens to the vault.
     *
     * @param sender The address sending the tokens.
     * @param vault The vault to deposit to.
     * @param amount The expected amount of tokens to be deposit.
     */
    function depositNative (
        address sender,
        address vault,
        uint256 amount
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IVaultFactory {
    // ================ Initialize ================
    /**
     * @notice Initializer for the logic contract trough the UUPS Proxy.
     *
     * @param _vaultAddress The template to use for the factory cloning of vaults.
     */
    function initialize (
        address _vaultAddress
    ) external;

    // ================ Upgrade Functions ================
    /**
     * @notice Updates the AssetVault logic contract address.
     *
     * @param newImplementation The address of the upgraded version of the contract.
     */
    function upgradeVault (
        address newImplementation
    ) external;

    /**
     * @notice Returns the current implementation version for this contract.
     * @dev This version will be manually updated on each new contract version deployed.
     *
     * @return version The current version of the implementation.
     */
    function getVersion ()
     external pure returns (
        uint256 version
    );

    // ================ Core Functions ================
    /**
     * @notice Creates a new vault contract.
     *
     * @param to The address that will own the new vault.
     *
     * @return vaultId The id of the vault token, derived from the initialized clone address.
     * @return vaultAddress The address of the proxy vault created.
     */
    function create (
        address to
    ) external returns (
        uint256 vaultId,
        address vaultAddress
    );

    // ================ Get/Set Functions ================
    /**
     * @notice Check if the given address is a vault instance created by this factory.
     *
     * @param instance The address to check.
     *
     * @return validity Whether the address is a valid vault instance.
     */
    function isInstance (
        address instance
    ) external view returns (
        bool validity
    );

    /**
     * @notice Return the address of the instance for the given token ID.
     *
     * @param tokenId The token ID for which to find the instance.
     *
     * @return instance The address of the derived instance.
     */
    function instanceAt (
        uint256 tokenId
    ) external view returns (
        address instance
    );

    /**
     * @notice Return the address of the instance for the given index.
     * Allows for enumeration over all instances.
     *
     * @param index The index for which to find the instance.
     *
     * @return instance The address of the instance, derived from the corresponding
     * token ID at the specified index.
     */
    function instanceAtIndex (
        uint256 index
    ) external view returns (
        address instance
    );

    /**
     * @notice Set the distributor address to be used by the vaults.
     * @dev This function is only callable by the owner of the factory.
     *
     * @param _distributorAddress The address of the distributor contract.
     */
    function setDistributor (
        address _distributorAddress
    ) external;

    // ================ Overrides ================
    /**
     * @notice Visibility for owner function from Ownable contract.
     */
    function owner ()
     external view returns (
        address
    );
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import { DataTypes } from "../libraries/DataTypes.sol";

/**
 * @title IWinnerAirnode
 * @author API3 Latam
 *
 * @notice This is the interface for the Winner Airnode,
 * which is initialized utilized when closing up a raffle.
 */
interface IWinnerAirnode {
    // ========== Get/Set Functions ==========
    /**
     * @notice Function to get the output of a raffle request.
     *
     * @param requestId The request ID of the raffle request.
     *
     * @return _winnerReponse The metadata for the request result.
     */
    function getRequestToRaffle (
        bytes32 requestId
    ) external view returns (
        DataTypes.WinnerReponse memory _winnerReponse
    );

    // ========== Callback Functions ==========
    /**
     * @notice - Callback function when requesting one winner only.
     * @dev - We suggest to set this as endpointId index `1`.
     *
     * @param requestId - The id for this request.
     * @param data - The response from the API send by the airnode.
     */
    function getIndividualWinner (
        bytes32 requestId,
        bytes calldata data
    ) external;

    /**
     * @notice - Callback function when requesting multiple winners.
     * @dev - We suggest to set this as endpointId index `2`.
     *
     * @param requestId - The id for this request.
     * @param data - The response from the API send by the airnode. 
     */
    function getMultipleWinners (
        bytes32 requestId,
        bytes calldata data
    ) external;

    // ========== Core Functions ==========
    /**
     * @notice - The function to call this airnode implementation.
     *
     * @param callbackSelector - The target endpoint to use as callback.
     * @param winnerNumbers - The number of winners to return.
     * @param participantNumbers - The number of participants from the raffle.
     */
    function requestWinners (
        bytes4 callbackSelector,
        uint256 winnerNumbers,
        uint256 participantNumbers
    ) external returns (
        bytes32
    );

    /**
     * @notice Return the results from a given request.
     *
     * @param requestId The request to get results from.
     */
    function requestResults (
        bytes32 requestId
    ) external returns (
        DataTypes.WinnerReponse memory
    );
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