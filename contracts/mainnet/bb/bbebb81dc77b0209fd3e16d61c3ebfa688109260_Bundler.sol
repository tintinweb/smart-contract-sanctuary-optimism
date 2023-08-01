// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IdRegistry} from "./IdRegistry.sol";
import {StorageRent} from "./StorageRent.sol";
import {KeyRegistry} from "./KeyRegistry.sol";
import {TrustedCaller} from "./lib/TrustedCaller.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";

contract Bundler is TrustedCaller {
    using TransferHelper for address;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Revert if the caller does not have the authority to perform the action.
    error Unauthorized();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Data needed to trusted register a user with the fid and storage contracts.
    struct UserData {
        address to;
        address recovery;
        uint32 scheme;
        bytes key;
        bytes metadata;
        uint256 units;
    }

    /// @notice Data needed to register an fid with signature.
    struct RegistrationParams {
        address to;
        address recovery;
        uint256 deadline;
        bytes sig;
    }

    /// @notice Data needed to add a signer with signature.
    struct SignerParams {
        uint32 scheme;
        bytes key;
        bytes metadata;
        uint256 deadline;
        bytes sig;
    }

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Address of the IdRegistry contract
     */
    IdRegistry public immutable idRegistry;

    /**
     * @dev Address of the StorageRent contract
     */
    StorageRent public immutable storageRent;

    /**
     * @dev Address of the StorageRent contract
     */
    KeyRegistry public immutable keyRegistry;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Configure the addresses of the Registry contracts and the trusted caller, which is
     *        allowed to register during the bootstrap phase.
     *
     * @param _idRegistry    Address of the IdRegistry contract
     * @param _storageRent   Address of the StorageRent contract
     * @param _trustedCaller Address that can call trustedRegister and trustedBatchRegister
     * @param _owner         Address that can set the trusted caller
     */
    constructor(
        address _idRegistry,
        address _storageRent,
        address _keyRegistry,
        address _trustedCaller,
        address _owner
    ) TrustedCaller(_owner) {
        idRegistry = IdRegistry(_idRegistry);
        storageRent = StorageRent(_storageRent);
        keyRegistry = KeyRegistry(_keyRegistry);
        _setTrustedCaller(_trustedCaller);
    }

    /**
     * @notice Register an fid, multiple signers, and rent storage to an address in a single transaction.
     *
     * @param registration Struct containing registration parameters: to, from, deadline, and signature.
     * @param signers      Array of structs containing signer parameters: scheme, key, metadata, deadline, and signature.
     * @param storageUnits Number of storage units to rent
     *
     */
    function register(
        RegistrationParams calldata registration,
        SignerParams[] calldata signers,
        uint256 storageUnits
    ) external payable {
        uint256 fid =
            idRegistry.registerFor(registration.to, registration.recovery, registration.deadline, registration.sig);

        for (uint256 i; i < signers.length; i++) {
            SignerParams calldata signer = signers[i];
            keyRegistry.addFor(registration.to, signer.scheme, signer.key, signer.metadata, signer.deadline, signer.sig);
        }

        uint256 overpayment = storageRent.rent{value: msg.value}(fid, storageUnits);

        if (overpayment > 0) {
            msg.sender.sendNative(overpayment);
        }
    }

    /**
     * @notice Register an fid, add a signer, and credit storage to an address in a single transaction. Can only
     *         be called by the trustedCaller during the Seedable phase.
     *
     * @param to           Address of the fid to register
     * @param recovery     Address that is allowed to perform a recovery
     * @param storageUnits Number of storage units to rent
     */
    function trustedRegister(
        address to,
        address recovery,
        uint32 scheme,
        bytes calldata key,
        bytes calldata metadata,
        uint256 storageUnits
    ) external onlyTrustedCaller {
        // Will revert unless IdRegistry is in the Seedable phase
        uint256 fid = idRegistry.trustedRegister(to, recovery);
        keyRegistry.trustedAdd(to, scheme, key, metadata);
        storageRent.credit(fid, storageUnits);
    }

    /**
     * @notice Register fids, keys, and credit storage for multiple users in a single transaction. Can
     *         only be called by the trustedCaller during the Seedable phase. Will be used when
     *         migrating across Ethereum networks to bootstrap a new contract with existing data.
     *
     * @param users  Array of UserData structs to register
     */
    function trustedBatchRegister(UserData[] calldata users) external onlyTrustedCaller {
        // Safety: calls inside a loop are safe since caller is trusted
        for (uint256 i = 0; i < users.length; i++) {
            uint256 fid = idRegistry.trustedRegister(users[i].to, users[i].recovery);
            keyRegistry.trustedAdd(users[i].to, users[i].scheme, users[i].key, users[i].metadata);
            storageRent.credit(fid, users[i].units);
        }
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ECDSA} from "openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Nonces} from "openzeppelin-latest/contracts/utils/Nonces.sol";
import {Pausable} from "openzeppelin/contracts/security/Pausable.sol";

import {Signatures} from "./lib/Signatures.sol";
import {TrustedCaller} from "./lib/TrustedCaller.sol";

/**
 * @title IdRegistry
 *
 * @notice See ../docs/docs.md for an overview.
 */

contract IdRegistry is TrustedCaller, Signatures, Pausable, EIP712, Nonces {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Revert when the caller does not have the authority to perform the action.
    error Unauthorized();

    /// @dev Revert when the caller must have an fid but does not have one.
    error HasNoId();

    /// @dev Revert when the destination must be empty but has an fid.
    error HasId();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when a new Farcaster ID is registered.
     *
     *      Hubs listen for this and update their address-to-fid mapping by adding `to` as the
     *      current owner of `id`. Hubs assume the invariants:
     *
     *      1. Two Register events can never emit with the same `id`
     *
     *      2. Two Register(alice, ..., ...) cannot emit unless a Transfer(..., alice, bob) emits
     *          in between, where bob != alice.
     *
     *      3. A Register(alice, id, recovery) can only occur if alice approves both the request
     *         and the recovery parameter, otherwise it could be used to impersonate/grief alice
     *
     * @param to       The custody address that owns the fid
     * @param id       The fid that was registered.
     * @param recovery The address that can initiate a recovery request for the fid.
     */
    event Register(address indexed to, uint256 indexed id, address recovery);

    /**
     * @dev Emit an event when an fid is transferred to a new custody address.
     *
     *      Hubs listen to this event and atomically change the current owner of `id`
     *      from `from` to `to` in their address-to-fid mapping. Hubs assume the invariants:
     *
     *      1. A Transfer(..., alice, ...) cannot emit if the most recent event for alice is
     *         Register (alice, ..., ...)
     *
     *      2. A Transfer(alice, ..., id) cannot emit unless the most recent event with that id is
     *         Transfer(..., alice, id) or Register(alice, id, ...)
     *
     * @param from The custody address that previously owned the fid.
     * @param to   The custody address that now owns the fid.
     * @param id   The fid that was transferred.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    /**
     * @dev Emit an event when a Farcaster ID's recovery address changes.
     *
     * @param id       The fid whose recovery address was changed.
     * @param recovery The new recovery address.
     */
    event ChangeRecoveryAddress(uint256 indexed id, address indexed recovery);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant _REGISTER_TYPEHASH =
        keccak256("Register(address to,address recovery,uint256 nonce,uint256 deadline)");

    bytes32 internal constant _TRANSFER_TYPEHASH =
        keccak256("Transfer(address from,address to,uint256 nonce,uint256 deadline)");

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev The last Farcaster id that was issued.
     */
    uint256 internal idCounter;

    /**
     * @dev Maps each address to a fid, or zero if it does not own a fid.
     */
    mapping(address owner => uint256 fid) public idOf;

    /**
     * @dev Maps each fid to an address that can initiate a recovery.
     */
    mapping(uint256 fid => address recovery) internal recoveryOf;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the owner of the contract to the provided _owner.
     */
    // solhint-disable-next-line no-empty-blocks
    constructor(address _owner) TrustedCaller(_owner) EIP712("Farcaster IdRegistry", "1") {}

    /*//////////////////////////////////////////////////////////////
                             REGISTRATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register a new Farcaster ID (fid) to the caller. The caller must not have an fid.
     *         The contract must not be in the Registrable (trustedOnly = 0) state.
     *
     * @param recovery Address which can recover the fid. Set to zero to disable recovery.
     */
    function register(address recovery) external returns (uint256 fid) {
        return _register(msg.sender, recovery);
    }

    /**
     * @notice Register a new Farcaster ID (fid) to any address. A signed message from the address
     *         must be provided. The address must not have an fid. The contract must be in the
     *         Registrable (trustedOnly = 0) state.
     *
     * @param to       Address which will own the fid.
     * @param recovery Address which can recover the fid. Set to zero to disable recovery.
     * @param deadline Expiration timestamp of the signature.
     * @param sig      EIP-712 signature signed by the to address.
     */
    function registerFor(
        address to,
        address recovery,
        uint256 deadline,
        bytes calldata sig
    ) external returns (uint256 fid) {
        _verifyRegisterSig(to, recovery, deadline, sig);
        return _register(to, recovery);
    }

    /**
     * @notice Register a new Farcaster ID (fid) to any address. The address must not have an fid.
     *         The contract must be in the Seedable (trustedOnly = 1) state.
     *
     * @param to       The address which will own the fid.
     * @param recovery The address which can recover the fid.
     */
    function trustedRegister(address to, address recovery) external onlyTrustedCaller returns (uint256 fid) {
        fid = _unsafeRegister(to, recovery);
        emit Register(to, idCounter, recovery);
    }

    /**
     * @dev Registers an fid and sets up a recovery address for a target. The contract must not be
     *      in the Seedable (trustedOnly = 1) state and target must not have an fid.
     */
    function _register(address to, address recovery) internal whenNotTrusted returns (uint256 fid) {
        fid = _unsafeRegister(to, recovery);

        emit Register(to, idCounter, recovery);
    }

    /**
     * @dev Registers an fid and sets up a recovery address for a target. Does not check all
     *      invariants or emit events. The contract must not be in the Seedable (trustedOnly = 1)
     *      state and target must not have an fid.
     */
    function _unsafeRegister(address to, address recovery) internal whenNotPaused returns (uint256 fid) {
        /* Revert if the target(to) has an fid */
        if (idOf[to] != 0) revert HasId();

        /* Safety: idCounter won't realistically overflow. */
        unchecked {
            /* Incrementing before assignment ensures that no one gets the 0 fid. */
            fid = ++idCounter;
        }

        /* Perf: Save 29 gas by avoiding to == address(0) check since 0x0 can only register 1 fid */
        idOf[to] = fid;
        recoveryOf[fid] = recovery;
    }

    /*//////////////////////////////////////////////////////////////
                             TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfer the fid owned by this address to another address that does not have an fid.
     *         Supports ERC 2771 meta-transactions and can be called via a relayer. A signed message
     *         from the destination address must be provided.
     *
     * @param to The address to transfer the fid to.
     * @param deadline Expiration timestamp of the signature.
     * @param sig      EIP-712 signature signed by the to address.
     */
    function transfer(address to, uint256 deadline, bytes calldata sig) external {
        address from = msg.sender;
        uint256 fromId = idOf[from];

        /* Revert if the sender has no id or recipient has an id */
        if (fromId == 0) revert HasNoId();
        if (idOf[to] != 0) revert HasId();

        _verifyTransferSig(fromId, to, deadline, sig);

        _unsafeTransfer(fromId, from, to);
    }

    /**
     * @dev Transfer the fid to another address without checking invariants.
     */
    function _unsafeTransfer(uint256 id, address from, address to) internal {
        idOf[to] = id;
        delete idOf[from];

        emit Transfer(from, to, id);
    }

    /*//////////////////////////////////////////////////////////////
                             RECOVERY LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Change the recovery address of the fid owned by the caller. Supports ERC 2771
     *         meta-transactions and can be called by a relayer.
     *
     * @param recovery The address which can recover the fid. Set to 0x0 to disable recovery.
     */
    function changeRecoveryAddress(address recovery) external {
        /* Revert if the caller does not own an fid */
        uint256 ownerId = idOf[msg.sender];
        if (ownerId == 0) revert HasNoId();

        /* Change the recovery address */
        recoveryOf[ownerId] = recovery;

        emit ChangeRecoveryAddress(ownerId, recovery);
    }

    /**
     * @notice Transfer the fid from the from address to the to address. Must be called by the
     *         recovery address. Supports ERC 2771 meta-transactions and can be called via a
     *         relayer. A signed message from the to address must be provided.
     *
     * @param from     The address that currently owns the fid.
     * @param to       The address to transfer the fid to.
     * @param deadline Expiration timestamp of the signature.
     * @param sig      EIP-712 signature signed by the to address.
     */
    function recover(address from, address to, uint256 deadline, bytes calldata sig) external {
        /* Revert if from does not own an fid */
        uint256 fromId = idOf[from];
        if (fromId == 0) revert HasNoId();

        /* Revert if the caller is not the recovery address */
        address caller = msg.sender;
        address recoveryAddress = recoveryOf[fromId];
        if (recoveryAddress != caller) revert Unauthorized();

        /* Revert if destination(to) already has an fid */
        if (idOf[to] != 0) revert HasId();

        _verifyTransferSig(fromId, to, deadline, sig);

        _unsafeTransfer(fromId, from, to);
    }

    /*//////////////////////////////////////////////////////////////
                         PERMISSIONED ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pause all registrations. Must be called by the owner.
     */
    function pauseRegistration() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause all registrations. Must be called by the owner.
     */
    function unpauseRegistration() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                     SIGNATURE VERIFICATION HELPERS
    //////////////////////////////////////////////////////////////*/

    function _verifyRegisterSig(address to, address recovery, uint256 deadline, bytes memory sig) internal {
        _verifySig(
            _hashTypedDataV4(keccak256(abi.encode(_REGISTER_TYPEHASH, to, recovery, _useNonce(to), deadline))),
            to,
            deadline,
            sig
        );
    }

    function _verifyTransferSig(uint256 fid, address to, uint256 deadline, bytes memory sig) internal {
        _verifySig(
            _hashTypedDataV4(keccak256(abi.encode(_TRANSFER_TYPEHASH, fid, to, _useNonce(to), deadline))),
            to,
            deadline,
            sig
        );
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {AccessControlEnumerable} from "openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

import {TransferHelper} from "./lib/TransferHelper.sol";

/**
 * @title StorageRent
 *
 * @notice See ../docs/docs.md for an overview.
 */
contract StorageRent is AccessControlEnumerable {
    using FixedPointMathLib for uint256;
    using TransferHelper for address;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Revert if the caller attempts to rent storage after deprecating this contract.
    error ContractDeprecated();

    /// @dev Revert if the caller attempts to rent more storage than is available.
    error ExceedsCapacity();

    /// @dev Revert if the caller attempts to rent zero units.
    error InvalidAmount();

    /// @dev Revert if the caller attempts a batch rent with mismatched input array lengths or an empty array.
    error InvalidBatchInput();

    /// @dev Revert if the caller provides the wrong payment amount.
    error InvalidPayment();

    /// @dev Revert if a data feed returns a stale answer.
    error StaleAnswer();

    /// @dev Revert if the data feed round is incomplete and has not yet generated an answer.
    error IncompleteRound();

    /// @dev Revert if the price feed returns a zero or negative price.
    error InvalidPrice();

    /// @dev Revert if the sequencer uptime feed detects that the L2 sequencer is unavailable.
    error SequencerDown();

    /// @dev Revert if the L2 sequencer restarted less than L2_DOWNTIME_GRACE_PERIOD seconds ago.
    error GracePeriodNotOver();

    /// @dev Revert if the deprecation timestamp parameter is in the past.
    error InvalidDeprecationTimestamp();

    /// @dev Revert if the max units parameter is above 1.6e7 (64TB @ 4MB/unit).
    error InvalidMaxUnits();

    /// @dev Revert if the caller is not an admin.
    error NotAdmin();

    /// @dev Revert if the caller is not an operator.
    error NotOperator();

    /// @dev Revert if the caller is not a treasurer.
    error NotTreasurer();

    /// @dev Revert if the caller does not have an authorized role.
    error Unauthorized();

    /// @dev Revert if transferred to the zero address.
    error InvalidAddress();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when caller pays rent for an fid's storage.
     *
     *      Hubs listen for this event and increment the units assigned to the fid by 1 for exactly
     *      395 days from the timestamp of this event (1 year + 30 day grace period). Hubs respect
     *      this even if the fid is not yet issued.
     *
     * @param payer     Address of the account paying the storage rent.
     * @param fid       The fid that will receive the storage allocation.
     * @param units     The number of storage units being rented.
     */
    event Rent(address indexed payer, uint256 indexed fid, uint256 units);

    /**
     * @dev Emit an event when an admin changes the price of storage units.
     *
     * @param oldPrice The previous unit price in USD. Fixed point value with 8 decimals.
     * @param newPrice The new unit price in USD. Fixed point value with 8 decimals.
     */
    event SetPrice(uint256 oldPrice, uint256 newPrice);

    /**
     * @dev Emit an event when an admin changes the fixed ETH/USD price.
     *      Setting this value to zero means the fixed price is disabled.
     *
     * @param oldPrice The previous ETH price in USD. Fixed point value with 8 decimals.
     * @param newPrice The new ETH price in USD. Fixed point value with 8 decimals.
     */
    event SetFixedEthUsdPrice(uint256 oldPrice, uint256 newPrice);

    /**
     * @dev Emit an event when an admin changes the maximum supply of storage units.
     *
     *      Hubs do not actively listen for this event, though the owner of the contract is
     *      responsible for ensuring that Hub operators are aware of the new storage requirements,
     *      since that may cause Hubs to fail if they do not allocate sufficient storage.
     *
     * @param oldMax The previous maximum amount.
     * @param newMax The new maximum amount.
     */
    event SetMaxUnits(uint256 oldMax, uint256 newMax);

    /**
     * @dev Emit an event when an admin changes the deprecationTimestamp.
     *
     * @param oldTimestamp The previous deprecationTimestamp.
     * @param newTimestamp The new deprecationTimestamp.
     */
    event SetDeprecationTimestamp(uint256 oldTimestamp, uint256 newTimestamp);

    /**
     * @dev Emit an event when an admin changes the priceFeedCacheDuration.
     *
     * @param oldDuration The previous priceFeedCacheDuration.
     * @param newDuration The new priceFeedCacheDuration.
     */
    event SetCacheDuration(uint256 oldDuration, uint256 newDuration);

    /**
     * @dev Emit an event when an admin changes the priceFeedMaxAge.
     *
     * @param oldAge The previous priceFeedMaxAge.
     * @param newAge The new priceFeedMaxAge.
     */
    event SetMaxAge(uint256 oldAge, uint256 newAge);

    /**
     * @dev Emit an event when an admin changes the uptimeFeedGracePeriod.
     *
     * @param oldPeriod The previous uptimeFeedGracePeriod.
     * @param newPeriod The new uptimeFeedGracePeriod.
     */
    event SetGracePeriod(uint256 oldPeriod, uint256 newPeriod);

    /**
     * @dev Emit an event when an admin changes the vault.
     *
     * @param oldVault The previous vault.
     * @param newVault The new vault.
     */
    event SetVault(address oldVault, address newVault);

    /**
     * @dev Emit an event when a treasurer makes a withdrawal from the contract balance.
     *
     * @param to     Address of recipient.
     * @param amount The amount of ether withdrawn.
     */
    event Withdraw(address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Contract version specified in the Farcaster protocol version scheme.
     */
    string public constant VERSION = "2023.07.12";

    /**
     * @dev Total possible storage unit capacity. 1.6e7 = 64TB @ 4MB/unit .
     */
    uint256 public constant TOTAL_STORAGE_UNIT_CAPACITY = 1.6e7;

    bytes32 internal constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 internal constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 internal constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Chainlink ETH/USD price feed.
     */
    AggregatorV3Interface public immutable priceFeed;

    /**
     * @dev Chainlink L2 sequencer uptime feed.
     */
    AggregatorV3Interface public immutable uptimeFeed;

    /*//////////////////////////////////////////////////////////////
                              PARAMETERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Block timestamp at which this contract will no longer accept storage rent payments. Changeable by admin.
     */
    uint256 public deprecationTimestamp;

    /**
     * @dev Price per storage unit in USD. Fixed point value with 8 decimals, e.g. 5e8 = $5 USD. Changeable by admin.
     */
    uint256 public usdUnitPrice;

    /**
     * @dev A fixed ETH/USD price to be used in the event of a price feed failure. If this value
     *      is nonzero, we disable external calls to the price feed and use this price. Changeable by admin.
     */
    uint256 public fixedEthUsdPrice;

    /**
     * @dev Total capacity of storage units. Changeable by admin.
     */
    uint256 public maxUnits;

    /**
     * @dev Duration to cache ethUsdPrice before updating from the price feed. Changeable by admin.
     */
    uint256 public priceFeedCacheDuration;

    /**
     * @dev Max age of a price feed answer before it is considered stale. Changeable by admin.
     */
    uint256 public priceFeedMaxAge;

    /**
     * @dev Period in seconds to wait after the L2 sequencer restarts before resuming rentals.
     *      See: https://docs.chain.link/data-feeds/l2-sequencer-feeds. Changeable by admin.
     */
    uint256 public uptimeFeedGracePeriod;

    /**
     * @dev Address to which the treasurer role can withdraw funds. Changeable by admin.
     */
    address public vault;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Total number of storage units that have been rented.
     */
    uint256 public rentedUnits;

    /**
     * @dev Cached Chainlink ETH/USD price.
     */
    uint256 public ethUsdPrice;

    /**
     * @dev Previous Chainlink ETH/USD price.
     */
    uint256 public prevEthUsdPrice;

    /**
     * @dev Timestamp of the last update to ethUsdPrice.
     */
    uint256 public lastPriceFeedUpdateTime;

    /**
     * @dev Block number of the last update to ethUsdPrice.
     */
    uint256 public lastPriceFeedUpdateBlock;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the price feed, uptime feed, and initial parameters.
     *
     * @param _priceFeed                     Chainlink ETH/USD price feed.
     * @param _uptimeFeed                    Chainlink L2 sequencer uptime feed.
     * @param _initialDeprecationPeriod      Initial deprecation period in seconds.
     * @param _initialUsdUnitPrice           Initial unit price in USD. Fixed point value with 8 decimals.
     * @param _initialMaxUnits               Initial maximum capacity in storage units.
     * @param _initialVault                  Initial vault address.
     * @param _initialRoleAdmin              Initial role admin address.
     * @param _initialAdmin                  Initial admin address.
     * @param _initialOperator               Initial operator address.
     * @param _initialTreasurer              Initial treasurer address.
     */
    constructor(
        AggregatorV3Interface _priceFeed,
        AggregatorV3Interface _uptimeFeed,
        uint256 _initialDeprecationPeriod,
        uint256 _initialUsdUnitPrice,
        uint256 _initialMaxUnits,
        address _initialVault,
        address _initialRoleAdmin,
        address _initialAdmin,
        address _initialOperator,
        address _initialTreasurer
    ) {
        priceFeed = _priceFeed;
        uptimeFeed = _uptimeFeed;

        deprecationTimestamp = block.timestamp + _initialDeprecationPeriod;
        emit SetDeprecationTimestamp(0, deprecationTimestamp);

        usdUnitPrice = _initialUsdUnitPrice;
        emit SetPrice(0, _initialUsdUnitPrice);

        maxUnits = _initialMaxUnits;
        emit SetMaxUnits(0, _initialMaxUnits);

        priceFeedCacheDuration = 1 days;
        emit SetCacheDuration(0, 1 days);

        priceFeedMaxAge = 2 hours;
        emit SetMaxAge(0, 2 hours);

        uptimeFeedGracePeriod = 1 hours;
        emit SetGracePeriod(0, 1 hours);

        vault = _initialVault;
        emit SetVault(address(0), _initialVault);

        _grantRole(DEFAULT_ADMIN_ROLE, _initialRoleAdmin);
        _grantRole(ADMIN_ROLE, _initialAdmin);
        _grantRole(OPERATOR_ROLE, _initialOperator);
        _grantRole(TREASURER_ROLE, _initialTreasurer);

        _refreshPrice();
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier whenNotDeprecated() {
        if (block.timestamp >= deprecationTimestamp) revert ContractDeprecated();
        _;
    }

    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert NotAdmin();
        _;
    }

    modifier onlyOperator() {
        if (!hasRole(OPERATOR_ROLE, msg.sender)) revert NotOperator();
        _;
    }

    modifier onlyTreasurer() {
        if (!hasRole(TREASURER_ROLE, msg.sender)) revert NotTreasurer();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        STORAGE RENTAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rent storage for a given fid for a year. The caller must provide at least
     *         price(units) wei of payment. Any excess payment will be refunded to the caller. Hubs
     *         will issue storage for 365 days + 30 day grace period after which it expires.
     *
     *         RentedUnits is never decremented on the contract even as the assigned storage expires
     *         on the hubs. This is done to keep the contract simple since we expect to launch a new
     *         storage contract within the year and deprecate this one. Even if that does not occur,
     *         the existing maxUnits parameter can be tweaked to account for expired units.
     *
     * @param fid   The fid that will receive the storage allocation.
     * @param units Number of storage units to rent.
     */
    function rent(uint256 fid, uint256 units) external payable whenNotDeprecated returns (uint256 overpayment) {
        // Checks
        if (units == 0) revert InvalidAmount();
        if (rentedUnits + units > maxUnits) revert ExceedsCapacity();
        uint256 totalPrice = _price(units);
        if (msg.value < totalPrice) revert InvalidPayment();

        // Effects
        rentedUnits += units;
        emit Rent(msg.sender, fid, units);

        // Interactions
        // Safety: overpayment is guaranteed to be >=0 because of checks
        overpayment = msg.value - totalPrice;
        if (overpayment > 0) {
            msg.sender.sendNative(overpayment);
        }
    }

    /**
     * @notice Rent storage for multiple fids. The caller must provide an exact payment amount equal to
     *         the sum of the prices for each fid's storage allocation.
     *
     * @param fids  An array of fids.
     * @param units An array of storage unit quantities. Must be the same length as the fids array.
     */
    function batchRent(uint256[] calldata fids, uint256[] calldata units) external payable whenNotDeprecated {
        // Pre-checks
        if (fids.length == 0 || units.length == 0) revert InvalidBatchInput();
        if (fids.length != units.length) revert InvalidBatchInput();

        // Effects
        uint256 _usdPrice = usdUnitPrice;
        uint256 _ethPrice = _ethUsdPrice();

        uint256 totalQty;
        for (uint256 i; i < fids.length; ++i) {
            uint256 qty = units[i];
            if (qty == 0) continue;
            totalQty += qty;
            emit Rent(msg.sender, fids[i], qty);
        }
        uint256 totalPrice = _price(totalQty, _usdPrice, _ethPrice);

        // Post-checks
        if (msg.value < totalPrice) revert InvalidPayment();
        if (rentedUnits + totalQty > maxUnits) revert ExceedsCapacity();

        // Effects
        rentedUnits += totalQty;

        // Interactions
        if (msg.value > totalPrice) {
            msg.sender.sendNative(msg.value - totalPrice);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              PRICE VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Cost in wei to rent one storage unit.
     * @return uint256 cost in wei.
     */
    function unitPrice() external view returns (uint256) {
        return price(1);
    }

    /**
     * @notice Calculate the cost in wei to rent the given number of storage units.
     *
     * @param units Number of storage units.
     * @return uint256 cost in wei.
     */
    function price(uint256 units) public view returns (uint256) {
        uint256 ethPrice;
        if (fixedEthUsdPrice != 0) {
            ethPrice = fixedEthUsdPrice;

            /**
             *  Slither flags the following line as a dangerous strict equality, but we want to
             *  make an exact comparison here and are not using this value in the context
             *  this detector rule describes.
             */

            // slither-disable-next-line incorrect-equality
        } else if (lastPriceFeedUpdateBlock == block.number) {
            ethPrice = prevEthUsdPrice;
        } else {
            ethPrice = ethUsdPrice;
        }
        return _price(units, usdUnitPrice, ethPrice);
    }

    /**
     * @dev Return the cached ethUsdPrice if it's still valid, otherwise get the
     *      latest ETH/USD price from the price feed and update the cache.
     */
    function _ethUsdPrice() internal returns (uint256) {
        /**
         *  If a fixed ETH/USD price is set, use it. This disables external calls
         *  to the price feed in case of emergency.
         */
        if (fixedEthUsdPrice != 0) return fixedEthUsdPrice;

        /**
         *  If cache duration has expired, get the latest price from the price feed.
         *  This updates prevEthUsdPrice, ethUsdPrice, lastPriceFeedUpdateTime, and
         *  lastPriceFeedUpdateBlock.
         */
        if (block.timestamp - lastPriceFeedUpdateTime > priceFeedCacheDuration) {
            _refreshPrice();
        }

        /**
         *  We want price changes to take effect in the first block after the price
         *  refresh, rather than immediately, to keep the price from changing intra
         *  block. If we update the price in this block, use the previous price
         *  until the next block. Otherwise, use the latest price.
         *
         *  Slither flags this line as a dangerous strict equality, but we want to
         *  make an exact comparison here and are not using this value in the context
         *  this detector rule describes.
         *
         */

        // slither-disable-next-line incorrect-equality
        return (lastPriceFeedUpdateBlock == block.number) ? prevEthUsdPrice : ethUsdPrice;
    }

    /**
     * @dev Get the latest ETH/USD price from the price feed and update the cached price.
     */
    function _refreshPrice() internal {
        /* Get and validate the L2 sequencer status. */
        (
            uint80 uptimeRoundId,
            int256 sequencerUp,
            uint256 uptimeStartedAt,
            uint256 uptimeUpdatedAt,
            uint80 uptimeAnsweredInRound
        ) = uptimeFeed.latestRoundData();
        if (sequencerUp != 0) revert SequencerDown();
        if (uptimeUpdatedAt == 0) revert IncompleteRound();
        if (uptimeAnsweredInRound < uptimeRoundId) revert StaleAnswer();

        /* If the L2 sequencer recently restarted, ensure the grace period has elapsed. */
        uint256 timeSinceUp = block.timestamp - uptimeStartedAt;
        if (timeSinceUp < uptimeFeedGracePeriod) revert GracePeriodNotOver();

        /**
         *  Get and validate the Chainlink ETH/USD price. We validate that the answer is
         *  a positive value, the round is complete, and the answer is not stale by round.
         *
         *  We ignore the price feed startedAt value, which we don't use in validations,
         *  since the priceUpdatedAt timestamp is more meaningful.
         *
         *  Slither flags this as an unused return value error, but this is safe since
         *  we use priceUpdatedAt and are interested in the latest value.
         */

        // slither-disable-next-line unused-return
        (uint80 priceRoundId, int256 answer,, uint256 priceUpdatedAt, uint80 priceAnsweredInRound) =
            priceFeed.latestRoundData();
        if (answer <= 0) revert InvalidPrice();
        if (priceUpdatedAt == 0) revert IncompleteRound();
        if (priceAnsweredInRound < priceRoundId) revert StaleAnswer();
        if (block.timestamp - priceUpdatedAt > priceFeedMaxAge) revert StaleAnswer();

        /* Set the last update timestamp and block. */
        lastPriceFeedUpdateTime = block.timestamp;
        lastPriceFeedUpdateBlock = block.number;

        if (prevEthUsdPrice == 0 && ethUsdPrice == 0) {
            /* If this is the very first price update, set previous equal to latest. */
            prevEthUsdPrice = ethUsdPrice = uint256(answer);
        } else {
            prevEthUsdPrice = ethUsdPrice;
            ethUsdPrice = uint256(answer);
        }
    }

    function _price(uint256 units) internal returns (uint256) {
        return _price(units, usdUnitPrice, _ethUsdPrice());
    }

    /**
     * @param units      Number of storage units. Integer, no decimals.
     * @param usdPerUnit Unit price in USD. Fixed point with 8 decimals.
     * @param usdPerEth  ETH/USD price. Fixed point with 8 decimals.
     *
     * @return uint256 price in wei, i.e. 18 decimals.
     */
    function _price(uint256 units, uint256 usdPerUnit, uint256 usdPerEth) internal pure returns (uint256) {
        return (units * usdPerUnit).divWadUp(usdPerEth);
    }

    /*//////////////////////////////////////////////////////////////
                         PERMISSIONED ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Credit a single fid with free storage units. Only callable by operator.
     *
     * @param fid   The fid that will receive the credit.
     * @param units Number of storage units to credit.
     */
    function credit(uint256 fid, uint256 units) external onlyOperator whenNotDeprecated {
        if (units == 0) revert InvalidAmount();
        if (rentedUnits + units > maxUnits) revert ExceedsCapacity();

        rentedUnits += units;
        emit Rent(msg.sender, fid, units);
    }

    /**
     * @notice Credit multiple fids with free storage units. Only callable by operator.
     *
     * @param fids  An array of fids.
     * @param units Number of storage units per fid.
     */
    function batchCredit(uint256[] calldata fids, uint256 units) external onlyOperator whenNotDeprecated {
        if (units == 0) revert InvalidAmount();
        uint256 totalUnits = fids.length * units;
        if (rentedUnits + totalUnits > maxUnits) revert ExceedsCapacity();
        rentedUnits += totalUnits;
        for (uint256 i; i < fids.length; ++i) {
            emit Rent(msg.sender, fids[i], units);
        }
    }

    /**
     * @notice Credit a continuous sequence of fids with free storage units. Only callable by operator.
     *
     * @param start Lowest fid in sequence (inclusive).
     * @param end   Highest fid in sequence (inclusive).
     * @param units Number of storage units per fid.
     */
    function continuousCredit(uint256 start, uint256 end, uint256 units) external onlyOperator whenNotDeprecated {
        if (units == 0) revert InvalidAmount();
        uint256 len = end - start;
        uint256 totalUnits = len * units;
        if (rentedUnits + totalUnits > maxUnits) revert ExceedsCapacity();
        rentedUnits += totalUnits;
        for (uint256 i; i < len; ++i) {
            emit Rent(msg.sender, start + i, units);
        }
    }

    /**
     * @notice Force refresh the cached Chainlink ETH/USD price. Callable by admin and treasurer.
     */
    function refreshPrice() external {
        if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(TREASURER_ROLE, msg.sender)) revert Unauthorized();
        _refreshPrice();
    }

    /**
     * @notice Change the USD price per storage unit. Callable by admin and treasurer.
     *
     * @param usdPrice The new unit price in USD. Fixed point value with 8 decimals.
     */
    function setPrice(uint256 usdPrice) external {
        if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(TREASURER_ROLE, msg.sender)) revert Unauthorized();
        emit SetPrice(usdUnitPrice, usdPrice);
        usdUnitPrice = usdPrice;
    }

    /**
     * @notice Set the fixed ETH/USD price, disabling the price feed if the value is
     *         nonzero. This is an emergency fallback in case of a price feed failure.
     *         Only callable by admin.
     *
     * @param fixedPrice The new fixed ETH/USD price. Fixed point value with 8 decimals.
     *                   Setting this value back to zero from a nonzero value will
     *                   re-enable the price feed.
     */
    function setFixedEthUsdPrice(uint256 fixedPrice) external onlyAdmin {
        emit SetFixedEthUsdPrice(fixedEthUsdPrice, fixedPrice);
        fixedEthUsdPrice = fixedPrice;
    }

    /**
     * @notice Change the maximum supply of storage units. Only callable by admin.
     *
     * @param max The new maximum supply of storage units.
     */
    function setMaxUnits(uint256 max) external onlyAdmin {
        if (max > TOTAL_STORAGE_UNIT_CAPACITY) revert InvalidMaxUnits();
        emit SetMaxUnits(maxUnits, max);
        maxUnits = max;
    }

    /**
     * @notice Change the deprecationTimestamp. Only callable by admin.
     *
     * @param timestamp The new deprecationTimestamp.
     */
    function setDeprecationTimestamp(uint256 timestamp) external onlyAdmin {
        if (timestamp < block.timestamp) revert InvalidDeprecationTimestamp();
        emit SetDeprecationTimestamp(deprecationTimestamp, timestamp);
        deprecationTimestamp = timestamp;
    }

    /**
     * @notice Change the priceFeedCacheDuration. Only callable by admin.
     *
     * @param duration The new priceFeedCacheDuration.
     */
    function setCacheDuration(uint256 duration) external onlyAdmin {
        emit SetCacheDuration(priceFeedCacheDuration, duration);
        priceFeedCacheDuration = duration;
    }

    /**
     * @notice Change the priceFeedMaxAge. Only callable by admin.
     *
     * @param age The new priceFeedMaxAge.
     */
    function setMaxAge(uint256 age) external onlyAdmin {
        emit SetMaxAge(priceFeedMaxAge, age);
        priceFeedMaxAge = age;
    }

    /**
     * @notice Change the uptimeFeedGracePeriod. Only callable by admin.
     *
     * @param period The new uptimeFeedGracePeriod.
     */
    function setGracePeriod(uint256 period) external onlyAdmin {
        emit SetGracePeriod(uptimeFeedGracePeriod, period);
        uptimeFeedGracePeriod = period;
    }

    /**
     * @notice Set the vault address that can receive funds from this contract.
     *         Only callable by admin.
     *
     * @param vaultAddr The new vault address.
     */
    function setVault(address vaultAddr) external onlyAdmin {
        if (vaultAddr == address(0)) revert InvalidAddress();
        emit SetVault(vault, vaultAddr);
        vault = vaultAddr;
    }

    /**
     * @notice Withdraw a specified amount of ether from the contract balance to the vault.
     *         Only callable by treasurer.
     *
     * @param amount The amount of ether to withdraw.
     */
    function withdraw(uint256 amount) external onlyTreasurer {
        emit Withdraw(vault, amount);
        vault.sendNative(amount);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ECDSA} from "openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Nonces} from "openzeppelin-latest/contracts/utils/Nonces.sol";

import {IdRegistry} from "./IdRegistry.sol";
import {Signatures} from "./lib/Signatures.sol";
import {TrustedCaller} from "./lib/TrustedCaller.sol";

interface IdRegistryLike {
    function idOf(address owner) external view returns (uint256);
}

/**
 * @title KeyRegistry
 *
 * @notice KeyRegistry allows addresses with an fid to add and remove public keys.
 *
 *         Keys have schemes which indicate how they should be interpreted and used. The only
 *         scheme today is SCHEME_1 which indicates that a key is an EdDSA key and should be
 *         allowed to sign messages on behalf of this fid on Farcaster Hubs.
 *
 *         The invariants of this contract are:
 *
 *         1. A key can only move to the added state if it was previously in the null state.
 *         2. A key can only move to the removed state if it was previously in the added state.
 *         3. A key can only move to the null state if it was previously in the added state, the
 * .         contract hasn't been migrated, and the action was performed by the owner.
 *         4. Event invariants are specified in comments above each event.
 */

contract KeyRegistry is TrustedCaller, Signatures, EIP712, Nonces {
    /**
     *  @notice State enumeration for a key in the registry. During migration, an admin can change
     *          the state of any fids key from NULL to ADDED or ADDED to NULL. After migration, an
     *          fid can change the state of a key from NULL to ADDED or ADDED to REMOVED only.
     *
     *          - NULL: The key is not in the registry.
     *          - ADDED: The key has been added to the registry.
     *          - REMOVED: The key was added to the registry but is now removed.
     */
    enum KeyState {
        NULL,
        ADDED,
        REMOVED
    }

    /**
     *  @notice Data about a key.
     *
     *  @param state   The current state of the key.
     *  @param scheme  The manner in which the key should be used.
     */
    struct KeyData {
        KeyState state;
        uint32 scheme;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Revert if a key violates KeyState transition rules.
    error InvalidState();

    /// @dev Revert if the caller does not have the authority to perform the action.
    error Unauthorized();

    /// @dev Revert if the owner calls migrateKeys more than once.
    error AlreadyMigrated();

    /// @dev Revert if migration batch input arrays are not the same length.
    error InvalidBatchInput();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when an admin or fid adds a new key.
     *
     *      Hubs listen for this, validate that keyBytes is an EdDSA pub key and scheme == 1 and
     *      add keyBytes to its SignerStore. Messages signed by keyBytes with `fid` are now valid
     *      and accepted over gossip, sync and client apis. Hubs assume the invariants:
     *
     *      1. Add(fid, ..., key, keyBytes, ...) cannot emit if there is an earlier emit with
     *         Add(fid, ..., key, keyBytes, ...)
     *
     *      2. Add(fid, ..., key, keyBytes, ...) cannot emit if there is an earlier emit with
     *         Remove(fid, key, keyBytes)
     *
     *      3. For all Add(..., ..., key, keyBytes, ...) key = keccack(keyBytes)
     *
     * @param fid       The fid associated with the key.
     * @param scheme    The type of the key.
     * @param key       The key being registered. (indexed as hash)
     * @param keyBytes  The bytes of the key being registered.
     * @param metadata  Metadata about the key.
     */
    event Add(uint256 indexed fid, uint32 indexed scheme, bytes indexed key, bytes keyBytes, bytes metadata);

    /**
     * @dev Emit an event when an fid removes an added key.
     *
     *      Hubs listen for this, validate that keyBytes is an EdDSA pub key, that scheme == 1 and
     *      that keyBytes exists in its SignerStore.  keyBytes is marked as removed, messages signed
     *      by keyBytes with `fid` areinvalid, dropped immediately and no longer accepted. Hubs
     *      assume the invariants:
     *
     *      1. Remove(fid, key, keyBytes cannot emit if there is no earlier emit with
     *         Add(fid, ..., key, keyBytes, ...)
     *
     *      2. Remove(fid, key, keyBytes, ...) cannot emit if there is an earlier emit with
     *         Remove(fid, key, keyBytes)
     *
     *      3. For all Remove(..., key, keyBytes), key = keccack(keyBytes)
     *
     * @param fid       The fid associated with the key.
     * @param key       The key being registered. (indexed as hash)
     * @param keyBytes  The bytes of the key being registered.
     */
    event Remove(uint256 indexed fid, bytes indexed key, bytes keyBytes);

    /**
     * @dev Emit an event when an admin resets an added key.
     *
     *      Hubs listen for this, validate that keyBytes is an EdDSA pub key, that scheme == 1 and
     *      that keyBytes exists in its SignerStore. keyBytes is no longer tracked, messages signed
     *      by keyBytes with `fid` are invalid, dropped immediately and not accepted. Unlike Remove
     *      keyBytes can be added to the SignerStore if an Add() event is observed.
     *
     * @param fid       The fid associated with the key.
     * @param key       The key being reset. (indexed as hash)
     * @param keyBytes  The bytes of the key being registered.
     */
    event AdminReset(uint256 indexed fid, bytes indexed key, bytes keyBytes);

    /**
     * @dev Emit an event when the admin calls migrateKeys. Used to migrate Hubs from using
     *      off-chain signers to on-chain signers.
     *
     *      Hubs listen for this and:
     *      1. Stop accepting Farcaster Signer messages with a timestamp >= keysMigratedAt.
     *      2. After the grace period (24 hours), stop accepting all Farcaster Signer messages.
     *      3. Drop any messages created by off-chain Farcaster Signers whose pub key was
     *         not emitted as an Add event.
     *
     *      If SignerMessages are not correctly migrated by an admin during the migration,
     *      there is a chance that there is some data loss, which is considered an acceptable
     *      risk for this migration.
     *
     *      If this event is emitted incorrectly ahead of schedule, new users cannot not post
     *      and existing users cannot add new apps. A protocol upgrade will be necessary
     *      which could take up to 6 weeks to roll out correctly.
     *
     * @param keysMigratedAt  The timestamp at which the migration occurred.
     */
    event Migrated(uint256 indexed keysMigratedAt);

    /**
     * @dev Emit an event when the admin sets a new IdRegistry contract address.
     *
     * @param oldIdRegistry The previous IdRegistry address.
     * @param newIdRegistry The ne IdRegistry address.
     */
    event SetIdRegistry(address oldIdRegistry, address newIdRegistry);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant _ADD_TYPEHASH =
        keccak256("Add(address owner,uint32 scheme,bytes key,bytes metadata,uint256 nonce,uint256 deadline)");

    bytes32 internal constant _REMOVE_TYPEHASH =
        keccak256("Remove(address owner,bytes key,uint256 nonce,uint256 deadline)");

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Period in seconds after migration during which admin can bulk add/reset keys.
     *      Admins can make corrections to the migrated data during the grace period if necessary,
     *      but cannot make changes after it expires.
     */
    uint24 public immutable gracePeriod;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev The IdRegistry contract.
     */
    IdRegistryLike public idRegistry;

    /**
     * @dev Timestamp at which keys migrated. Hubs will cut over to use this KeyRegistry as their
     *      source of truth after this timestamp.
     */
    uint40 public keysMigratedAt;

    /**
     * @dev Mapping of fid to a key to the key's metadata.
     *
     * @custom:param fid       The fid associated with the key.
     * @custom:param key       Bytes of the key.
     * @custom:param data      Struct with the state and key type. In the initial migration
     *                         all keys will have data.scheme == 1.
     */
    mapping(uint256 fid => mapping(bytes key => KeyData data)) public keys;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the IdRegistry, migration grace period, and owner.
     *
     * @param _idRegistry  IdRegistry contract address.
     * @param _gracePeriod Migration grace period in seconds. Immutable.
     * @param _owner       Contract owner address.
     */
    constructor(
        address _idRegistry,
        uint24 _gracePeriod,
        address _owner
    ) TrustedCaller(_owner) EIP712("Farcaster KeyRegistry", "1") {
        gracePeriod = _gracePeriod;
        idRegistry = IdRegistryLike(_idRegistry);
    }

    /*//////////////////////////////////////////////////////////////
                                  VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Retrieve state and type data for a given key.
     *
     * @param fid   The fid associated with the key.
     * @param key   Bytes of the key.
     *
     * @return KeyData struct that contains the state and scheme.
     */
    function keyDataOf(uint256 fid, bytes calldata key) external view returns (KeyData memory) {
        return keys[fid][key];
    }

    /**
     * @notice Check if the contract has been migrated.
     *
     * @return true if the contract has been migrated, false otherwise.
     */
    function isMigrated() public view returns (bool) {
        return keysMigratedAt != 0;
    }

    /*//////////////////////////////////////////////////////////////
                              REGISTRATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add a key to the caller's fid, setting the key state to ADDED.
     *
     * @param scheme   The key's numeric scheme.
     * @param key      Bytes of the key to add.
     * @param metadata Metadata about the key, which is not stored and only emitted in an event.
     */
    function add(uint32 scheme, bytes calldata key, bytes calldata metadata) external {
        uint256 fid = idRegistry.idOf(msg.sender);
        if (fid == 0) revert Unauthorized();

        _add(fid, scheme, key, metadata);
    }

    function addFor(
        address owner,
        uint32 scheme,
        bytes calldata key,
        bytes calldata metadata,
        uint256 deadline,
        bytes calldata sig
    ) external {
        uint256 fid = idRegistry.idOf(owner);
        if (fid == 0) revert Unauthorized();

        _verifyAddSig(owner, scheme, key, metadata, deadline, sig);
        _add(fid, scheme, key, metadata);
    }

    function trustedAdd(
        address owner,
        uint32 scheme,
        bytes calldata key,
        bytes calldata metadata
    ) external onlyTrustedCaller {
        uint256 fid = idRegistry.idOf(owner);
        if (fid == 0) revert Unauthorized();

        _add(fid, scheme, key, metadata);
    }

    /**
     * @notice Remove a key associated with the caller's fid, setting the key state to REMOVED.
     *         The key must be in the ADDED state.
     *
     * @param key   Bytes of the key to remove.
     */
    function remove(bytes calldata key) external {
        uint256 fid = idRegistry.idOf(msg.sender);
        if (fid == 0) revert Unauthorized();

        _remove(fid, key);
    }

    function removeFor(address owner, bytes calldata key, uint256 deadline, bytes calldata sig) external {
        uint256 fid = idRegistry.idOf(owner);
        if (fid == 0) revert Unauthorized();

        _verifyRemoveSig(owner, key, deadline, sig);
        _remove(fid, key);
    }

    /*//////////////////////////////////////////////////////////////
                                MIGRATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the time of the key migration and emit an event. Hubs will watch this event and
     *         cut over to use the onchain registry as their source of truth after this timestamp.
     *         Only callable by the contract owner.
     */
    function migrateKeys() external onlyOwner {
        if (isMigrated()) revert AlreadyMigrated();
        keysMigratedAt = uint40(block.timestamp);
        emit Migrated(keysMigratedAt);
    }

    /**
     * @notice Add multiple keys as part of the initial migration. Only callable by the contract owner.
     *
     * @param fids    A list of fids to associate with keys.
     * @param fidKeys A list of public keys to register for each fid, in the same order as the fids array.
     */
    function bulkAddKeysForMigration(
        uint256[] calldata fids,
        bytes[][] calldata fidKeys,
        bytes calldata metadata
    ) external onlyOwner {
        if (isMigrated() && block.timestamp > keysMigratedAt + gracePeriod) revert Unauthorized();
        if (fids.length != fidKeys.length) revert InvalidBatchInput();

        // Safety: i and j can be incremented unchecked since they are bound by fids.length and
        // fidKeys[i].length respectively.
        unchecked {
            for (uint256 i = 0; i < fids.length; i++) {
                uint256 fid = fids[i];
                for (uint256 j = 0; j < fidKeys[i].length; j++) {
                    // TODO: add note about griefing during migration
                    _add(fid, 1, fidKeys[i][j], metadata);
                }
            }
        }
    }

    /**
     * @notice Reset multiple keys as part of the initial migration. Only callable by the contract owner.
     *         Reset is not the same as removal: this function sets the key state back to NULL,
     *         rather than REMOVED. This allows the owner to correct any errors in the initial migration until
     *         the grace period expires.
     *
     * @param fids    A list of fids whose added keys should be removed.
     * @param fidKeys A list of keys to remove for each fid, in the same order as the fids array.
     */
    function bulkResetKeysForMigration(uint256[] calldata fids, bytes[][] calldata fidKeys) external onlyOwner {
        if (isMigrated() && block.timestamp > keysMigratedAt + gracePeriod) revert Unauthorized();
        if (fids.length != fidKeys.length) revert InvalidBatchInput();

        // Safety: i and j can be incremented unchecked since they are bound by fids.length and
        // fidKeys[i].length respectively.
        unchecked {
            for (uint256 i = 0; i < fids.length; i++) {
                uint256 fid = fids[i];
                for (uint256 j = 0; j < fidKeys[i].length; j++) {
                    // TODO: add note about griefing during migration
                    _reset(fid, fidKeys[i][j]);
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 ADMIN
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the IdRegistry contract address. Only callable by owner.
     *
     * @param _idRegistry The new IdRegistry address.
     */
    function setIdRegistry(address _idRegistry) external onlyOwner {
        emit SetIdRegistry(address(idRegistry), _idRegistry);
        idRegistry = IdRegistryLike(_idRegistry);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _add(uint256 fid, uint32 scheme, bytes calldata key, bytes calldata metadata) internal {
        KeyData storage keyData = keys[fid][key];
        if (keyData.state != KeyState.NULL) revert InvalidState();

        keyData.state = KeyState.ADDED;
        keyData.scheme = scheme;
        emit Add(fid, scheme, key, key, metadata);
    }

    function _remove(uint256 fid, bytes calldata key) internal {
        KeyData storage keyData = keys[fid][key];
        if (keyData.state != KeyState.ADDED) revert InvalidState();

        keyData.state = KeyState.REMOVED;
        emit Remove(fid, key, key);
    }

    function _reset(uint256 fid, bytes calldata key) internal {
        KeyData storage keyData = keys[fid][key];
        if (keyData.state != KeyState.ADDED) revert InvalidState();

        keyData.state = KeyState.NULL;
        delete keyData.scheme;
        emit AdminReset(fid, key, key);
    }

    /*//////////////////////////////////////////////////////////////
                     SIGNATURE VERIFICATION HELPERS
    //////////////////////////////////////////////////////////////*/

    function _verifyAddSig(
        address owner,
        uint32 scheme,
        bytes memory key,
        bytes memory metadata,
        uint256 deadline,
        bytes memory sig
    ) internal {
        _verifySig(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        _ADD_TYPEHASH, owner, scheme, keccak256(key), keccak256(metadata), _useNonce(owner), deadline
                    )
                )
            ),
            owner,
            deadline,
            sig
        );
    }

    function _verifyRemoveSig(address owner, bytes memory key, uint256 deadline, bytes memory sig) internal {
        _verifySig(
            _hashTypedDataV4(keccak256(abi.encode(_REMOVE_TYPEHASH, owner, keccak256(key), _useNonce(owner), deadline))),
            owner,
            deadline,
            sig
        );
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ECDSA} from "openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Nonces} from "openzeppelin-latest/contracts/utils/Nonces.sol";
import {Ownable2Step} from "openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "openzeppelin/contracts/security/Pausable.sol";

abstract contract TrustedCaller is Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Revert when an unauthorized caller calls a trusted function.
    error OnlyTrustedCaller();

    /// @dev Revert if trustedRegister is invoked after trustedCallerOnly is disabled.
    error Registrable();

    /// @dev Revert if register is invoked before trustedCallerOnly is disabled.
    error Seedable();

    /// @dev Revert when an invalid address is provided as input.
    error InvalidAddress();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when the trusted caller is modified.
     *
     * @param oldCaller The address of the old trusted caller.
     * @param newCaller The address of the new trusted caller.
     * @param owner     The address of the owner setting the new caller.
     */
    event SetTrustedCaller(address indexed oldCaller, address indexed newCaller, address owner);

    /**
     * @dev Emit an event when the trustedOnly state is disabled.
     */
    event DisableTrustedOnly();

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev The privileged address that is allowed to call trusted functions.
     */
    address public trustedCaller;

    /**
     * @dev Allows calling trusted functions when set 1, and disables trusted
     *      functions when set to 0. The value is set to 1 and can be changed to 0,
     *      but never back to 1.
     */
    uint256 internal trustedOnly = 1;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Allow only the trusted caller to call the modified function.
     */
    modifier onlyTrustedCaller() {
        if (trustedOnly == 0) revert Registrable();
        if (msg.sender != trustedCaller) revert OnlyTrustedCaller();
        _;
    }

    /**
     * @dev Prevent calling the modified function in trustedOnly mode.
     */
    modifier whenNotTrusted() {
        if (trustedOnly == 1) revert Seedable();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _owner Initial contract owner address.
     */
    constructor(address _owner) {
        _transferOwnership(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                         PERMISSIONED ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Change the trusted caller by calling this from the contract's owner.
     *
     * @param _trustedCaller The address of the new trusted caller
     */
    function setTrustedCaller(address _trustedCaller) public onlyOwner {
        _setTrustedCaller(_trustedCaller);
    }

    /**
     * @notice Disable trustedOnly mode. Must be called by the contract's owner.
     */
    function disableTrustedOnly() external onlyOwner {
        delete trustedOnly;
        emit DisableTrustedOnly();
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal helper to set trusted caller. Can be used internally
     *      to set the trusted caller at construction time.
     */
    function _setTrustedCaller(address _trustedCaller) internal {
        if (_trustedCaller == address(0)) revert InvalidAddress();

        emit SetTrustedCaller(trustedCaller, _trustedCaller, msg.sender);
        trustedCaller = _trustedCaller;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

library TransferHelper {
    /// @dev Revert when a native token transfer fails.
    error CallFailed();

    /// @dev Revert when there are not enough funds for a native token transfer.
    error InsufficientFunds();

    /**
     * @dev Native token transfer helper.
     */
    function sendNative(address to, uint256 amount) internal {
        if (address(this).balance < amount) revert InsufficientFunds();

        /**
         *  This Slither detector requires all return values to be
         *  used, but we are intentionally ignoring returndata here.
         *  This is safe since we still check success and revert if
         *  the call failed. We're not using the returndata.
         */

        // slither-disable-next-line unchecked-lowlevel, unused-return
        (bool success,) = payable(to).call{value: amount}("");
        if (!success) revert CallFailed();
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../Strings.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV // Deprecated in v4.8
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 message) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32")
            mstore(0x1c, hash)
            message := keccak256(0x00, 0x3c)
        }
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 data) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, "\x19\x01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            data := keccak256(ptr, 0x42)
        }
    }

    /**
     * @dev Returns an Ethereum Signed Data with intended validator, created from a
     * `validator` and `data` according to the version 0 of EIP-191.
     *
     * See {recover}.
     */
    function toDataWithIntendedValidatorHash(address validator, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x00", validator, data));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/cryptography/EIP712.sol)

pragma solidity ^0.8.8;

import "./ECDSA.sol";
import "../ShortStrings.sol";
import "../../interfaces/IERC5267.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding specified in the EIP is very generic, and such a generic implementation in Solidity is not feasible,
 * thus this contract does not implement the encoding itself. Protocols need to implement the type-specific encoding
 * they need in their contracts using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * NOTE: In the upgradeable version of this contract, the cached values will correspond to the address, and the domain
 * separator of the implementation contract. This will cause the `_domainSeparatorV4` function to always rebuild the
 * separator from the immutable values, which is cheaper than accessing a cached version in cold storage.
 *
 * _Available since v3.4._
 *
 * @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
 */
abstract contract EIP712 is IERC5267 {
    using ShortStrings for *;

    bytes32 private constant _TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    // Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
    // invalidate the cached domain separator if the chain id changes.
    bytes32 private immutable _cachedDomainSeparator;
    uint256 private immutable _cachedChainId;
    address private immutable _cachedThis;

    bytes32 private immutable _hashedName;
    bytes32 private immutable _hashedVersion;

    ShortString private immutable _name;
    ShortString private immutable _version;
    string private _nameFallback;
    string private _versionFallback;

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     *
     * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
     * contract upgrade].
     */
    constructor(string memory name, string memory version) {
        _name = name.toShortStringWithFallback(_nameFallback);
        _version = version.toShortStringWithFallback(_versionFallback);
        _hashedName = keccak256(bytes(name));
        _hashedVersion = keccak256(bytes(version));

        _cachedChainId = block.chainid;
        _cachedDomainSeparator = _buildDomainSeparator();
        _cachedThis = address(this);
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        if (address(this) == _cachedThis && block.chainid == _cachedChainId) {
            return _cachedDomainSeparator;
        } else {
            return _buildDomainSeparator();
        }
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(_TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(this)));
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return ECDSA.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    /**
     * @dev See {EIP-5267}.
     *
     * _Available since v4.9._
     */
    function eip712Domain()
        public
        view
        virtual
        override
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (
            hex"0f", // 01111
            _name.toStringWithFallback(_nameFallback),
            _version.toStringWithFallback(_versionFallback),
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @dev Provides tracking nonces for addresses. Nonces will only increment.
 */
abstract contract Nonces {
    /**
     * @dev The nonce used for an `account` is not the expected current nonce.
     */
    error InvalidAccountNonce(address account, uint256 currentNonce);

    mapping(address => uint256) private _nonces;

    /**
     * @dev Returns an the next unused nonce for an address.
     */
    function nonces(address owner) public view virtual returns (uint256) {
        return _nonces[owner];
    }

    /**
     * @dev Consumes a nonce.
     *
     * Returns the current value and increments nonce.
     */
    function _useNonce(address owner) internal virtual returns (uint256) {
        // For each account, the nonce has an initial value of 0, can only be incremented by one, and cannot be
        // decremented or reset. This guarantees that the nonce never overflows.
        unchecked {
            // It is important to do x++ and not ++x here.
            return _nonces[owner]++;
        }
    }

    /**
     * @dev Same as {_useNonce} but checking that `nonce` is the next valid for `owner`.
     */
    function _useCheckedNonce(address owner, uint256 nonce) internal virtual returns (uint256) {
        uint256 current = _useNonce(owner);
        if (nonce != current) {
            revert InvalidAccountNonce(owner, current);
        }
        return current;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
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
    constructor() {
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
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {SignatureChecker} from "openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

abstract contract Signatures {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Revert when the signature provided is invalid.
    error InvalidSignature();

    /// @dev Revert when the block.timestamp is ahead of the signature deadline.
    error SignatureExpired();

    /*//////////////////////////////////////////////////////////////
                     SIGNATURE VERIFICATION HELPERS
    //////////////////////////////////////////////////////////////*/

    function _verifySig(bytes32 digest, address signer, uint256 deadline, bytes memory sig) internal view {
        if (block.timestamp >= deadline) revert SignatureExpired();
        if (!SignatureChecker.isValidSignatureNow(signer, digest, sig)) revert InvalidSignature();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {

  function decimals()
    external
    view
    returns (
      uint8
    );

  function description()
    external
    view
    returns (
      string memory
    );

  function version()
    external
    view
    returns (
      uint256
    );

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(
    uint80 _roundId
  )
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (access/AccessControlEnumerable.sol)

pragma solidity ^0.8.0;

import "./IAccessControlEnumerable.sol";
import "./AccessControl.sol";
import "../utils/structs/EnumerableSet.sol";

/**
 * @dev Extension of {AccessControl} that allows enumerating the members of each role.
 */
abstract contract AccessControlEnumerable is IAccessControlEnumerable, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(bytes32 => EnumerableSet.AddressSet) private _roleMembers;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlEnumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) public view virtual override returns (address) {
        return _roleMembers[role].at(index);
    }

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) public view virtual override returns (uint256) {
        return _roleMembers[role].length();
    }

    /**
     * @dev Overload {_grantRole} to track enumerable memberships
     */
    function _grantRole(bytes32 role, address account) internal virtual override {
        super._grantRole(role, account);
        _roleMembers[role].add(account);
    }

    /**
     * @dev Overload {_revokeRole} to track enumerable memberships
     */
    function _revokeRole(bytes32 role, address account) internal virtual override {
        super._revokeRole(role, account);
        _roleMembers[role].remove(account);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/FixedPointMathLib.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
    }

    function powWad(int256 x, int256 y) internal pure returns (int256) {
        // Equivalent to x to the power of y because x ** y = (e ** ln(x)) ** y = e ** (ln(x) * y)
        return expWad((lnWad(x) * y) / int256(WAD)); // Using ln(x) means x must be greater than 0.
    }

    function expWad(int256 x) internal pure returns (int256 r) {
        unchecked {
            // When the result is < 0.5 we return zero. This happens when
            // x <= floor(log(0.5e18) * 1e18) ~ -42e18
            if (x <= -42139678854452767551) return 0;

            // When the result is > (2**255 - 1) / 1e18 we can not represent it as an
            // int. This happens when x >= floor(log((2**255 - 1) / 1e18) * 1e18) ~ 135.
            if (x >= 135305999368893231589) revert("EXP_OVERFLOW");

            // x is now in the range (-42, 136) * 1e18. Convert to (-42, 136) * 2**96
            // for more intermediate precision and a binary basis. This base conversion
            // is a multiplication by 1e18 / 2**96 = 5**18 / 2**78.
            x = (x << 78) / 5**18;

            // Reduce range of x to (-½ ln 2, ½ ln 2) * 2**96 by factoring out powers
            // of two such that exp(x) = exp(x') * 2**k, where k is an integer.
            // Solving this gives k = round(x / log(2)) and x' = x - k * log(2).
            int256 k = ((x << 96) / 54916777467707473351141471128 + 2**95) >> 96;
            x = x - k * 54916777467707473351141471128;

            // k is in the range [-61, 195].

            // Evaluate using a (6, 7)-term rational approximation.
            // p is made monic, we'll multiply by a scale factor later.
            int256 y = x + 1346386616545796478920950773328;
            y = ((y * x) >> 96) + 57155421227552351082224309758442;
            int256 p = y + x - 94201549194550492254356042504812;
            p = ((p * y) >> 96) + 28719021644029726153956944680412240;
            p = p * x + (4385272521454847904659076985693276 << 96);

            // We leave p in 2**192 basis so we don't need to scale it back up for the division.
            int256 q = x - 2855989394907223263936484059900;
            q = ((q * x) >> 96) + 50020603652535783019961831881945;
            q = ((q * x) >> 96) - 533845033583426703283633433725380;
            q = ((q * x) >> 96) + 3604857256930695427073651918091429;
            q = ((q * x) >> 96) - 14423608567350463180887372962807573;
            q = ((q * x) >> 96) + 26449188498355588339934803723976023;

            assembly {
                // Div in assembly because solidity adds a zero check despite the unchecked.
                // The q polynomial won't have zeros in the domain as all its roots are complex.
                // No scaling is necessary because p is already 2**96 too large.
                r := sdiv(p, q)
            }

            // r should be in the range (0.09, 0.25) * 2**96.

            // We now need to multiply r by:
            // * the scale factor s = ~6.031367120.
            // * the 2**k factor from the range reduction.
            // * the 1e18 / 2**96 factor for base conversion.
            // We do this all at once, with an intermediate result in 2**213
            // basis, so the final right shift is always by a positive amount.
            r = int256((uint256(r) * 3822833074963236453042738258902158003155416615667) >> uint256(195 - k));
        }
    }

    function lnWad(int256 x) internal pure returns (int256 r) {
        unchecked {
            require(x > 0, "UNDEFINED");

            // We want to convert x from 10**18 fixed point to 2**96 fixed point.
            // We do this by multiplying by 2**96 / 10**18. But since
            // ln(x * C) = ln(x) + ln(C), we can simply do nothing here
            // and add ln(2**96 / 10**18) at the end.

            // Reduce range of x to (1, 2) * 2**96
            // ln(2^k * x) = k * ln(2) + ln(x)
            int256 k = int256(log2(uint256(x))) - 96;
            x <<= uint256(159 - k);
            x = int256(uint256(x) >> 159);

            // Evaluate using a (8, 8)-term rational approximation.
            // p is made monic, we will multiply by a scale factor later.
            int256 p = x + 3273285459638523848632254066296;
            p = ((p * x) >> 96) + 24828157081833163892658089445524;
            p = ((p * x) >> 96) + 43456485725739037958740375743393;
            p = ((p * x) >> 96) - 11111509109440967052023855526967;
            p = ((p * x) >> 96) - 45023709667254063763336534515857;
            p = ((p * x) >> 96) - 14706773417378608786704636184526;
            p = p * x - (795164235651350426258249787498 << 96);

            // We leave p in 2**192 basis so we don't need to scale it back up for the division.
            // q is monic by convention.
            int256 q = x + 5573035233440673466300451813936;
            q = ((q * x) >> 96) + 71694874799317883764090561454958;
            q = ((q * x) >> 96) + 283447036172924575727196451306956;
            q = ((q * x) >> 96) + 401686690394027663651624208769553;
            q = ((q * x) >> 96) + 204048457590392012362485061816622;
            q = ((q * x) >> 96) + 31853899698501571402653359427138;
            q = ((q * x) >> 96) + 909429971244387300277376558375;
            assembly {
                // Div in assembly because solidity adds a zero check despite the unchecked.
                // The q polynomial is known not to have zeros in the domain.
                // No scaling required because p is already 2**96 too large.
                r := sdiv(p, q)
            }

            // r is in the range (0, 0.125) * 2**96

            // Finalization, we need to:
            // * multiply by the scale factor s = 5.549…
            // * add ln(2**96 / 10**18)
            // * add k * ln(2)
            // * multiply by 10**18 / 2**96 = 5**18 >> 78

            // mul s * 5e18 * 2**96, base is now 5**18 * 2**192
            r *= 1677202110996718588342820967067443963516166;
            // add ln(2) * k * 5e18 * 2**192
            r += 16597577552685614221487285958193947469193820559219878177908093499208371 * k;
            // add ln(2**96 / 10**18) * 5e18 * 2**192
            r += 600920179829731861736702779321621459595472258049074101567377883020018308;
            // base conversion: mul 2**18 / 2**192
            r >>= 174;
        }
    }

    /*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

            // Divide z by the denominator.
            z := div(z, denominator)
        }
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

            // First, divide z - 1 by the denominator and add 1.
            // We allow z - 1 to underflow if z is 0, because we multiply the
            // end result by 0 if z is zero, ensuring we return 0 if z is zero.
            z := mul(iszero(iszero(z)), add(div(sub(z, 1), denominator), 1))
        }
    }

    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := scalar
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store scalar in z for now.
                    z := scalar
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, scalar)

                for {
                    // Shift n right by 1 before looping to halve it.
                    n := shr(1, n)
                } n {
                    // Shift n right by 1 each iteration to halve it.
                    n := shr(1, n)
                } {
                    // Revert immediately if x ** 2 would overflow.
                    // Equivalent to iszero(eq(div(xx, x), x)) here.
                    if shr(128, x) {
                        revert(0, 0)
                    }

                    // Store x squared.
                    let xx := mul(x, x)

                    // Round to the nearest number.
                    let xxRound := add(xx, half)

                    // Revert if xx + half overflowed.
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }

                    // Set x to scaled xxRound.
                    x := div(xxRound, scalar)

                    // If n is even:
                    if mod(n, 2) {
                        // Compute z * x.
                        let zx := mul(z, x)

                        // If z * x overflowed:
                        if iszero(eq(div(zx, x), z)) {
                            // Revert if x is non-zero.
                            if iszero(iszero(x)) {
                                revert(0, 0)
                            }
                        }

                        // Round to the nearest number.
                        let zxRound := add(zx, half)

                        // Revert if zx + half overflowed.
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }

                        // Return properly scaled zxRound.
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            let y := x // We start y at x, which will help us make our initial estimate.

            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // We check y >= 2^(k + 8) but shift right by k bits
            // each branch to ensure that if x >= 256, then y >= 256.
            if iszero(lt(y, 0x10000000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x1000000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x10000000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x1000000)) {
                y := shr(16, y)
                z := shl(8, z)
            }

            // Goal was to get z*z*y within a small factor of x. More iterations could
            // get y in a tighter range. Currently, we will have y in [256, 256*2^16).
            // We ensured y >= 256 so that the relative difference between y and y+1 is small.
            // That's not possible if x < 256 but we can just verify those cases exhaustively.

            // Now, z*z*y <= x < z*z*(y+1), and y <= 2^(16+8), and either y >= 256, or x < 256.
            // Correctness can be checked exhaustively for x < 256, so we assume y >= 256.
            // Then z*sqrt(y) is within sqrt(257)/sqrt(256) of sqrt(x), or about 20bps.

            // For s in the range [1/256, 256], the estimate f(s) = (181/1024) * (s+1) is in the range
            // (1/2.84 * sqrt(s), 2.84 * sqrt(s)), with largest error when s = 1 and when s = 256 or 1/256.

            // Since y is in [256, 256*2^16), let a = y/65536, so that a is in [1/256, 256). Then we can estimate
            // sqrt(y) using sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2^18.

            // There is no overflow risk here since y < 2^136 after the first branch above.
            z := shr(18, mul(z, add(y, 65536))) // A mul() is saved from starting z at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If x+1 is a perfect square, the Babylonian method cycles between
            // floor(sqrt(x)) and ceil(sqrt(x)). This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            // Since the ceil is rare, we save gas on the assignment and repeat division in the rare case.
            // If you don't care whether the floor or ceil square root is returned, you can remove this statement.
            z := sub(z, lt(div(x, z), z))
        }
    }

    function log2(uint256 x) internal pure returns (uint256 r) {
        require(x > 0, "UNDEFINED");

        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            r := or(r, shl(2, lt(0xf, shr(r, x))))
            r := or(r, shl(1, lt(0x3, shr(r, x))))
            r := or(r, lt(0x1, shr(r, x)))
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable2Step.sol)

pragma solidity ^0.8.0;

import "./Ownable.sol";

/**
 * @dev Contract module which provides access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership} and {acceptOwnership}.
 *
 * This module is used through inheritance. It will make available all functions
 * from parent (Ownable).
 */
abstract contract Ownable2Step is Ownable {
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public virtual {
        address sender = _msgSender();
        require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
        _transferOwnership(sender);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Strings.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/ShortStrings.sol)

pragma solidity ^0.8.8;

import "./StorageSlot.sol";

// | string  | 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA   |
// | length  | 0x                                                              BB |
type ShortString is bytes32;

/**
 * @dev This library provides functions to convert short memory strings
 * into a `ShortString` type that can be used as an immutable variable.
 *
 * Strings of arbitrary length can be optimized using this library if
 * they are short enough (up to 31 bytes) by packing them with their
 * length (1 byte) in a single EVM word (32 bytes). Additionally, a
 * fallback mechanism can be used for every other case.
 *
 * Usage example:
 *
 * ```solidity
 * contract Named {
 *     using ShortStrings for *;
 *
 *     ShortString private immutable _name;
 *     string private _nameFallback;
 *
 *     constructor(string memory contractName) {
 *         _name = contractName.toShortStringWithFallback(_nameFallback);
 *     }
 *
 *     function name() external view returns (string memory) {
 *         return _name.toStringWithFallback(_nameFallback);
 *     }
 * }
 * ```
 */
library ShortStrings {
    // Used as an identifier for strings longer than 31 bytes.
    bytes32 private constant _FALLBACK_SENTINEL = 0x00000000000000000000000000000000000000000000000000000000000000FF;

    error StringTooLong(string str);
    error InvalidShortString();

    /**
     * @dev Encode a string of at most 31 chars into a `ShortString`.
     *
     * This will trigger a `StringTooLong` error is the input string is too long.
     */
    function toShortString(string memory str) internal pure returns (ShortString) {
        bytes memory bstr = bytes(str);
        if (bstr.length > 31) {
            revert StringTooLong(str);
        }
        return ShortString.wrap(bytes32(uint256(bytes32(bstr)) | bstr.length));
    }

    /**
     * @dev Decode a `ShortString` back to a "normal" string.
     */
    function toString(ShortString sstr) internal pure returns (string memory) {
        uint256 len = byteLength(sstr);
        // using `new string(len)` would work locally but is not memory safe.
        string memory str = new string(32);
        /// @solidity memory-safe-assembly
        assembly {
            mstore(str, len)
            mstore(add(str, 0x20), sstr)
        }
        return str;
    }

    /**
     * @dev Return the length of a `ShortString`.
     */
    function byteLength(ShortString sstr) internal pure returns (uint256) {
        uint256 result = uint256(ShortString.unwrap(sstr)) & 0xFF;
        if (result > 31) {
            revert InvalidShortString();
        }
        return result;
    }

    /**
     * @dev Encode a string into a `ShortString`, or write it to storage if it is too long.
     */
    function toShortStringWithFallback(string memory value, string storage store) internal returns (ShortString) {
        if (bytes(value).length < 32) {
            return toShortString(value);
        } else {
            StorageSlot.getStringSlot(store).value = value;
            return ShortString.wrap(_FALLBACK_SENTINEL);
        }
    }

    /**
     * @dev Decode a string that was encoded to `ShortString` or written to storage using {setWithFallback}.
     */
    function toStringWithFallback(ShortString value, string storage store) internal pure returns (string memory) {
        if (ShortString.unwrap(value) != _FALLBACK_SENTINEL) {
            return toString(value);
        } else {
            return store;
        }
    }

    /**
     * @dev Return the length of a string that was encoded to `ShortString` or written to storage using {setWithFallback}.
     *
     * WARNING: This will return the "byte length" of the string. This may not reflect the actual length in terms of
     * actual characters as the UTF-8 encoding of a single character can span over multiple bytes.
     */
    function byteLengthWithFallback(ShortString value, string storage store) internal view returns (uint256) {
        if (ShortString.unwrap(value) != _FALLBACK_SENTINEL) {
            return byteLength(value);
        } else {
            return bytes(store).length;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (interfaces/IERC5267.sol)

pragma solidity ^0.8.0;

interface IERC5267 {
    /**
     * @dev MAY be emitted to signal that the domain could have changed.
     */
    event EIP712DomainChanged();

    /**
     * @dev returns the fields and values that describe the domain separator used by this contract for EIP-712
     * signature.
     */
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
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
// OpenZeppelin Contracts (last updated v4.9.0) (utils/cryptography/SignatureChecker.sol)

pragma solidity ^0.8.0;

import "./ECDSA.sol";
import "../../interfaces/IERC1271.sol";

/**
 * @dev Signature verification helper that can be used instead of `ECDSA.recover` to seamlessly support both ECDSA
 * signatures from externally owned accounts (EOAs) as well as ERC1271 signatures from smart contract wallets like
 * Argent and Gnosis Safe.
 *
 * _Available since v4.1._
 */
library SignatureChecker {
    /**
     * @dev Checks if a signature is valid for a given signer and data hash. If the signer is a smart contract, the
     * signature is validated against that smart contract using ERC1271, otherwise it's validated using `ECDSA.recover`.
     *
     * NOTE: Unlike ECDSA signatures, contract signatures are revocable, and the outcome of this function can thus
     * change through time. It could return true at block N and false at block N+1 (or the opposite).
     */
    function isValidSignatureNow(address signer, bytes32 hash, bytes memory signature) internal view returns (bool) {
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(hash, signature);
        return
            (error == ECDSA.RecoverError.NoError && recovered == signer) ||
            isValidERC1271SignatureNow(signer, hash, signature);
    }

    /**
     * @dev Checks if a signature is valid for a given signer and data hash. The signature is validated
     * against the signer smart contract using ERC1271.
     *
     * NOTE: Unlike ECDSA signatures, contract signatures are revocable, and the outcome of this function can thus
     * change through time. It could return true at block N and false at block N+1 (or the opposite).
     */
    function isValidERC1271SignatureNow(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) internal view returns (bool) {
        (bool success, bytes memory result) = signer.staticcall(
            abi.encodeWithSelector(IERC1271.isValidSignature.selector, hash, signature)
        );
        return (success &&
            result.length >= 32 &&
            abi.decode(result, (bytes32)) == bytes32(IERC1271.isValidSignature.selector));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControlEnumerable.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";

/**
 * @dev External interface of AccessControlEnumerable declared to support ERC165 detection.
 */
interface IAccessControlEnumerable is IAccessControl {
    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(account),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/structs/EnumerableSet.sol)
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
 * ```solidity
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
library EnumerableSet {
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
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

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
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
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
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

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
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
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
// OpenZeppelin Contracts (last updated v4.9.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

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
 * ```solidity
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
 * _Available since v4.1 for `address`, `bool`, `bytes32`, `uint256`._
 * _Available since v4.9 for `string`, `bytes`._
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

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
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

    /**
     * @dev Returns an `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC1271.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC1271 standard signature validation method for
 * contracts as defined in https://eips.ethereum.org/EIPS/eip-1271[ERC-1271].
 *
 * _Available since v4.1._
 */
interface IERC1271 {
    /**
     * @dev Should return whether the signature provided is valid for the provided data
     * @param hash      Hash of the data to be signed
     * @param signature Signature byte array associated with _data
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
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