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

import {IAccountProxy} from "./interfaces/IAccountProxy.sol";

/// @title Kwenta Account Proxy
/// @author OpenZeppelin, JaredBorders ([email protected])
/// @dev This contract implements a proxy that gets the
/// implementation address for each call from the {Beacon}
/// (which in this system is the contract: {Factory.sol}).
/// The beacon address is stored in the storage slot
/// `uint256(keccak256('eip1967.proxy.beacon')) - 1`, so that it doesn't
/// conflict with the storage layout of the implementation behind this proxy.
contract AccountProxy is IAccountProxy {
    /*//////////////////////////////////////////////////////////////
                           STORAGE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant _BEACON_STORAGE_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);

    /// @dev struct to store beacon address
    struct AddressSlot {
        address value;
    }

    /// @dev returns the storage slot where the beacon address is stored
    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r.slot := slot
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice constructor for proxy
    /// @param _beaconAddress: address of beacon (i.e. factory address)
    /// @dev {Factory.sol} will store the implementation address,
    /// thus acting as the beacon
    constructor(address _beaconAddress) {
        _getAddressSlot(_BEACON_STORAGE_SLOT).value = _beaconAddress;
    }

    /*//////////////////////////////////////////////////////////////
                              BEACON LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @return beacon address (i.e. the factory address)
    function _beacon() internal view returns (address beacon) {
        beacon = _getAddressSlot(_BEACON_STORAGE_SLOT).value;
        if (beacon == address(0)) revert BeaconNotSet();
    }

    /*//////////////////////////////////////////////////////////////
                          IMPLEMENTATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @return implementation address (i.e. the account logic address)
    function _implementation() internal returns (address implementation) {
        (bool success, bytes memory data) =
            _beacon().call(abi.encodeWithSignature("implementation()"));
        if (!success) revert BeaconCallFailed();
        implementation = abi.decode(data, (address));
        if (implementation == address(0)) revert ImplementationNotSet();
    }

    /*//////////////////////////////////////////////////////////////
                            FORWARDING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Fallback function that delegates calls to the address returned by `_implementation()`.
    /// Will run if no other function in the contract matches the call data.
    fallback() external payable {
        _fallback();
    }

    /// @dev Fallback function that delegates calls to the address returned by `_implementation()`.
    /// Will run if call data is empty.
    receive() external payable {
        _fallback();
    }

    /// @notice Delegates the current call to the address returned by `_implementation()`.
    /// @dev This function does not return to its internal call site,
    /// it will return directly to the external caller.
    function _fallback() internal {
        _delegate(_implementation());
    }

    /// @notice delegates the current call to `implementation`.
    /// @dev This function does not return to its internal call site,
    /// it will return directly to the external caller.
    function _delegate(address implementation) internal virtual {
        // solhint-disable-next-line no-inline-assembly
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
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import {AccountProxy} from "./AccountProxy.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {Owned} from "@solmate/auth/Owned.sol";

/// @title Kwenta Account Factory
/// @author JaredBorders ([email protected])
/// @notice Mutable factory for creating smart margin accounts
/// @dev This contract acts as a Beacon for the {AccountProxy.sol} contract
contract Factory is IFactory, Owned {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFactory
    bool public canUpgrade = true;

    /// @inheritdoc IFactory
    address public implementation;

    /// @inheritdoc IFactory
    address public settings;

    /// @inheritdoc IFactory
    address public events;

    /// @inheritdoc IFactory
    mapping(address accountOwner => address account) public ownerToAccount;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice constructor for factory
    /// @param _owner: owner of factory
    /// @param _settings: address of settings contract for accounts
    /// @param _events: address of events contract for accounts
    /// @param _implementation: address of account implementation
    constructor(address _owner, address _settings, address _events, address _implementation)
        Owned(_owner)
    {
        settings = _settings;
        events = _events;
        implementation = _implementation;
    }

    /*//////////////////////////////////////////////////////////////
                           ACCOUNT DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFactory
    function newAccount() external override returns (address payable accountAddress) {
        /// @dev ensure one account per address
        if (ownerToAccount[msg.sender] != address(0)) {
            revert OnlyOneAccountPerAddress(ownerToAccount[msg.sender]);
        }

        // create account and set beacon to this address (i.e. factory address)
        accountAddress = payable(address(new AccountProxy(address(this))));

        // update owner to account mapping
        ownerToAccount[msg.sender] = accountAddress;

        // initialize new account
        (bool success, bytes memory data) = accountAddress.call(
            abi.encodeWithSignature(
                "initialize(address,address,address,address)",
                msg.sender, // caller will be set as owner
                settings,
                events,
                address(this)
            )
        );
        if (!success) revert AccountFailedToInitialize(data);

        // determine version for the following event
        (success, data) = accountAddress.call(abi.encodeWithSignature("VERSION()"));
        if (!success) revert AccountFailedToFetchVersion(data);

        emit NewAccount({
            creator: msg.sender,
            account: accountAddress,
            version: abi.decode(data, (bytes32))
        });
    }

    /*//////////////////////////////////////////////////////////////
                           ACCOUNT OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFactory
    function updateAccountOwner(address _oldOwner, address _newOwner) external override {
        /// @dev ensure _newOwner does not already have an account
        if (ownerToAccount[_newOwner] != address(0)) {
            revert OnlyOneAccountPerAddress(ownerToAccount[_newOwner]);
        }

        // get account address
        address account = ownerToAccount[_oldOwner];

        // ensure account exists
        if (account == address(0)) revert AccountDoesNotExist();

        // ensure account owned by _oldOwner is the caller
        if (msg.sender != account) revert CallerMustBeAccount();

        delete ownerToAccount[_oldOwner];
        ownerToAccount[_newOwner] = account;
    }

    /*//////////////////////////////////////////////////////////////
                             UPGRADABILITY
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFactory
    function upgradeAccountImplementation(address _implementation) external override onlyOwner {
        if (!canUpgrade) revert CannotUpgrade();
        implementation = _implementation;
        emit AccountImplementationUpgraded({implementation: _implementation});
    }

    /// @inheritdoc IFactory
    function upgradeSettings(address _settings) external override onlyOwner {
        if (!canUpgrade) revert CannotUpgrade();
        settings = _settings;
        emit SettingsUpgraded({settings: _settings});
    }

    /// @inheritdoc IFactory
    function upgradeEvents(address _events) external override onlyOwner {
        if (!canUpgrade) revert CannotUpgrade();
        events = _events;
        emit EventsUpgraded({events: _events});
    }

    /// @inheritdoc IFactory
    function removeUpgradability() external override onlyOwner {
        canUpgrade = false;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

/// @title Kwenta Account Proxy Interface
/// @author JaredBorders ([email protected])
interface IAccountProxy {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev thrown if beacon is not set to a valid address
    error BeaconNotSet();

    /// @dev thrown if implementation is not set to a valid address
    error ImplementationNotSet();

    /// @dev thrown if beacon call fails
    error BeaconCallFailed();
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