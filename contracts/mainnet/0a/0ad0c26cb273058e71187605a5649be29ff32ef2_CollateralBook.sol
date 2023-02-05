/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-05
*/

// File contracts/CollateralBook.sol
// CollateralBook.sol for isomorph.loans
// Source code: https://github.com/kree-dotcom/isomorph

//SPDX-License-Identifier: MIT
pragma solidity =0.8.9;
pragma abicoder v2;

// File @openzeppelin/contracts/access/[email protected]
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

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


// File @openzeppelin/contracts/utils/[email protected]


// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
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
}


// File @openzeppelin/contracts/utils/[email protected]


// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

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


// File @openzeppelin/contracts/utils/introspection/[email protected]


// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

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


// File @openzeppelin/contracts/utils/introspection/[email protected]


// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

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


// File @openzeppelin/contracts/access/[email protected]


// OpenZeppelin Contracts (last updated v4.7.0) (access/AccessControl.sol)

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
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
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
 * accounts that have been granted it.
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
                        Strings.toHexString(uint160(account), 20),
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


// File contracts/RoleControl.sol

contract RoleControl is AccessControl{

    // admin address can add  after `TIME_DELAY` has passed.
    // admin address can also remove minters or pause minting, no time delay needed.
    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public previous_action_hash = 0x0;
    uint256 private immutable TIME_DELAY;
    mapping(bytes32 => uint256) public action_queued;
    uint256 public actionNonce = 0;
    

    event QueueAddRole(address indexed account, bytes32 indexed role, address indexed suggestedBy, uint256 suggestedTimestamp);
    event AddRole(address indexed account, bytes32 indexed role, address indexed addedBy);
    event RemoveRole(address indexed account, bytes32 indexed role, address indexed addedBy);

    //this is horrid I am sorry, code too big kept occuring for vaults.
    function onlyAdminInternal() internal view {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
    }
    modifier onlyAdmin{
        onlyAdminInternal();
        _;
    }

    constructor(uint256 _timeDelay){
        TIME_DELAY = _timeDelay;
    }
    // @dev adding a new role to an account is a two step process with a time delay
    // @dev first call this function then addRole
    // @param _account address you wish to be add the role to
    // @param _role the predefined role you wish the address to have, hashed by keccak256
    // @notice actionNonce increments on each call, therefore only one addRole can be queued at a time
    function proposeAddRole(address _account, bytes32 _role) external onlyAdmin{
        bytes32 action_hash = keccak256(abi.encode(_account, _role, actionNonce));
        previous_action_hash = action_hash;
        actionNonce += 1;
        action_queued[action_hash] = block.timestamp;
        emit QueueAddRole(_account, _role, msg.sender, block.timestamp);
    }

    // @param _account address that has been queued to become the role
    // @param _role the role the account should gain, note that all admins become pausers also.
    function addRole(address _account, bytes32 _role) external onlyAdmin{
        bytes32 action_hash = keccak256(abi.encode(_account, _role, actionNonce-1));
        require(previous_action_hash == action_hash, "Invalid Hash");
        require(block.timestamp > action_queued[action_hash] + TIME_DELAY,
            "Not enough time has passed");
        //overwrite old hash to prevent reuse.
        delete previous_action_hash;
        //use a hash to verify proposed account is the same as added account.
        _setupRole(_role, _account);
        emit AddRole(_account, _role,  msg.sender);
    }

    // @param _account address that is already a minter and you wish to remove from this role.
    // @notice reverts if address `_account` did not already have the specified role.
    function removeRole(address _account, bytes32 _role) external onlyAdmin{
        require(hasRole(_role, _account), "Address was not already specified role");
        _revokeRole(_role, _account);
        emit RemoveRole(_account, _role, msg.sender);
    }
}


// File contracts/interfaces/ICollateralBook.sol

interface ICollateralBook {
  
  
    struct Collateral {
        bytes32 currencyKey; //used by synthetix to identify synths
        uint256 minOpeningMargin; //minimum loan margin required on opening or adjusting a loan
        uint256 liquidatableMargin; //margin point below which a loan can be liquidated
        uint256 interestPer3Min; //what percentage the interest grows by every 3 minutes
        uint256 lastUpdateTime; //last blocktimestamp this collateral's virtual price was updated
        uint256 virtualPrice; //price accounting for growing interest accrued on any loans taken in this collateral
        uint256 assetType;
    }

  
   
  function CHANGE_COLLATERAL_DELAY (  ) external view returns ( uint256 );
  function DEFAULT_ADMIN_ROLE (  ) external view returns ( bytes32 );
  function DIVISION_BASE (  ) external view returns ( uint256 );
  function THREE_MIN (  ) external view returns ( uint256 );
  function VAULT_ROLE (  ) external view returns ( bytes32 );
  function actionNonce (  ) external view returns ( uint256 );
  function action_queued ( bytes32 ) external view returns ( uint256 );
  function addCollateralType ( address _collateralAddress, bytes32 _currencyKey, uint256 _minimumRatio, uint256 _liquidationRatio, uint256 _interestPer3Min, uint256 _assetType, address _liquidityPool ) external;
  function addRole ( address _account, bytes32 _role ) external;
  function addVaultAddress ( address _vault, uint256 _assetType ) external;
  function changeCollateralType (  ) external;
  function collateralPaused ( address ) external view returns ( bool );
  function collateralProps(address) external view returns(Collateral memory collateral);
  function collateralValid ( address ) external view returns ( bool );
  function getRoleAdmin ( bytes32 role ) external view returns ( bytes32 );
  function grantRole ( bytes32 role, address account ) external;
  function hasRole ( bytes32 role, address account ) external view returns ( bool );
  function liquidityPoolOf ( bytes32 ) external view returns ( address );
  function pauseCollateralType ( address _collateralAddress, bytes32 _currencyKey ) external;
  function previous_action_hash (  ) external view returns ( bytes32 );
  function proposeAddRole ( address _account, bytes32 _role ) external;
  function queueCollateralChange ( address _collateralAddress, bytes32 _currencyKey, uint256 _minimumRatio, uint256 _liquidationRatio, uint256 _interestPer3Min, uint256 _assetType, address _liquidityPool ) external;
  function removeRole ( address _account, bytes32 _role ) external;
  function renounceRole ( bytes32 role, address account ) external;
  function revokeRole ( bytes32 role, address account ) external;
  function supportsInterface ( bytes4 interfaceId ) external view returns ( bool );
  function unpauseCollateralType ( address _collateralAddress, bytes32 _currencyKey ) external;
  function updateVirtualPriceSlowly ( address _collateralAddress, uint256 _cycles ) external;
  function vaultUpdateVirtualPriceAndTime ( address _collateralAddress, uint256 _virtualPriceUpdate, uint256 _updateTime ) external;
  function vaults ( uint256 ) external view returns ( address );
  function viewLastUpdateTimeforAsset ( address _collateralAddress ) external view returns ( uint256 );
  function viewVirtualPriceforAsset ( address _collateralAddress ) external view returns ( uint256 );
}


// File contracts/interfaces/IVault.sol

interface IVault {
  function ADMIN_ROLE (  ) external view returns ( bytes32 );
  function DEFAULT_ADMIN_ROLE (  ) external view returns ( bytes32 );
  function EXCHANGE_RATES (  ) external view returns ( address );
  function LIQUIDATION_RETURN (  ) external view returns ( uint256 );
  function LOAN_SCALE (  ) external view returns ( uint256 );
  function LOWER_LIQUIDATION_BAND (  ) external view returns ( uint256 );
  function LYRA_LP (  ) external view returns ( uint256 );
  function PAUSER_ROLE (  ) external view returns ( bytes32 );
  function PROXY_ERC20 (  ) external view returns ( address );
  function SUSD_ADDR (  ) external view returns ( address );
  function SYNTHETIX_SYNTH (  ) external view returns ( uint256 );
  function SYSTEM_STATUS (  ) external view returns ( address );
  function TIME_DELAY (  ) external view returns ( uint256 );
  function actionNonce (  ) external view returns ( uint256 );
  function action_queued ( bytes32 ) external view returns ( uint256 );
  function addRole ( address _account, bytes32 _role ) external;
  function callLiquidation ( address _loanHolder, address _collateralAddress ) external;
  function closeLoan ( address _collateralAddress, uint256 _collateralToUser, uint256 _USDToVault ) external;
  function collateralPosted ( address, address ) external view returns ( uint256 );
  function dailyMax (  ) external view returns ( uint256 );
  function dailyTotal (  ) external view returns ( uint256 );
  function dayCounter (  ) external view returns ( uint256 );
  function feePaid (  ) external view returns ( uint256 );
  function getRoleAdmin ( bytes32 role ) external view returns ( bytes32 );
  function grantRole ( bytes32 role, address account ) external;
  function hasRole ( bytes32 role, address account ) external view returns ( bool );
  function increaseCollateralAmount ( address _collateralAddress, uint256 _colAmount ) external;
  function loanOpenFee (  ) external view returns ( uint256 );
  function moUSDLoaned ( address, address ) external view returns ( uint256 );
  function openLoan ( address _collateralAddress, uint256 _colAmount, uint256 _USDborrowed ) external;
  function pause (  ) external;
  function paused (  ) external view returns ( bool );
  function previous_action_hash (  ) external view returns ( bytes32 );
  function priceCollateralToUSD ( bytes32 _currencyKey, uint256 _amount, uint256 _assetType ) external view returns ( uint256 );
  function proposeAddRole ( address _account, bytes32 _role ) external;
  function removeRole ( address _account, bytes32 _role ) external;
  function renounceRole ( bytes32 role, address account ) external;
  function revokeRole ( bytes32 role, address account ) external;
  function setDailyMax ( uint256 _dailyMax ) external;
  function supportsInterface ( bytes4 interfaceId ) external view returns ( bool );
  function unpause (  ) external;
  function viewLiquidatableAmount ( uint256 _collateralAmount, uint256 _collateralPrice, uint256 _userDebt, uint256 _liquidatableMargin ) external pure returns ( uint256 );
}


// File contracts/CollateralBook.sol


uint256 constant COLLATERAL_BOOK_TIME_DELAY = 3 days;

contract CollateralBook is RoleControl(COLLATERAL_BOOK_TIME_DELAY){

    mapping(address => bool) public collateralValid;
    mapping(address => bool) public collateralPaused;
    mapping(address => Collateral) public collateralProps;
    mapping(bytes32 => address) public liquidityPoolOf;
    mapping(uint256 => address) public vaults;

    
    bytes32 public constant VAULT_ROLE = keccak256("MINTER_ROLE");

    uint256 public constant THREE_MIN = 180;
    uint256 public constant DIVISION_BASE = 1 ether;
    uint256 public constant CHANGE_COLLATERAL_DELAY = 2 days;

    //temporary data stores for changing Collateral variables
    address queuedCollateralAddress;
    bytes32 queuedCurrencyKey;
    uint256 queuedMinimumRatio;
    uint256 queuedLiquidationRatio;
    uint256 queuedInterestPer3Min;
    address queuedLiquidityPool;
    uint256 queuedTimestamp;

    // @notice minOpeningMargin MUST always be set high enough that 
    // a single update in the Chainlink pricefeed underlying Synthetix 
    // is significantly unlikely to produce an undercollateralized loan else the system is frontrunnable.
    struct Collateral {
        bytes32 currencyKey; //used by synthetix to identify synths
        uint256 minOpeningMargin; //minimum loan margin required on opening or adjusting a loan
        uint256 liquidatableMargin; //margin point below which a loan can be liquidated
        uint256 interestPer3Min; //what percentage the interest grows by every 3 minutes
        uint256 lastUpdateTime; //last blocktimestamp this collateral's virtual price was updated
        uint256 virtualPrice; //price accounting for growing interest accrued on any loans taken in this collateral
        uint256 assetType; //number to indicate what system this collateral token belongs to, 
                            // assetType is used to determine which Vault we are looking at
    }


    modifier collateralExists(address _collateralAddress){
        require(collateralValid[_collateralAddress], "Unsupported collateral!");
        _;
    }

    modifier onlyVault{
        require(hasRole(VAULT_ROLE, msg.sender), "Only updatable by vault");
        _;
    }

     constructor() {
        //we dont want the `DEFAULT_ADMIN_ROLE` to exist as this doesn't require a 
        // time delay to add/remove any role and so is dangerous. 
        //So we do not set it and set our weaker admin role.
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    /**
      * @notice Used for testing or when a bot wants to check virtualPrice of an asset
      * @param _collateralAddress address of collateral token being used.
       */
    function viewVirtualPriceforAsset(address _collateralAddress) external view returns(uint256){
        return (collateralProps[_collateralAddress].virtualPrice);
    }

    /**
      * @notice Used for testing or when a bot wants to check if a collateral token needs the virtualPrice 
            manually updated due to inactivity.
      * @param _collateralAddress address of collateral token being used.
       */
    function viewLastUpdateTimeforAsset(address _collateralAddress) external view returns(uint256){
        return (collateralProps[_collateralAddress].lastUpdateTime);
    }

     /**
      * @notice Only Admin can modify collateral tokens,
      * @notice two step process to enforce a timelock for changing collateral
      * @notice first you call queueCollateralChange() then changeCollateralType() after timelock period ends
      * @dev does not allow changing token address, if this changes add a new collateral.
      * @param _collateralAddress address of collateral token being used.
      * @param _currencyKey symbol() returned string, used for synthetix calls
      * @param _minimumRatio lowest margin ratio for opening debts with new collateral token
      * @param _liquidationRatio margin ratio at which a loan backed by said collateral can be liquidated.
      * @param _interestPer3Min interest charged per block to loan holders using this collateral.
      * @param _liquidityPool only set for Lyra LP tokens, this address is where price info of the LP token is stored. The Zero address is used for non-Lyra Collateral
     **/
    function queueCollateralChange(
        address _collateralAddress,
        bytes32 _currencyKey,
        uint256 _minimumRatio,
        uint256 _liquidationRatio,
        uint256 _interestPer3Min,
        address _liquidityPool

    ) external onlyAdmin collateralExists(_collateralAddress) {
        
        require(_collateralAddress != address(0));
        require(_minimumRatio > _liquidationRatio);
        require(_liquidationRatio != 0);
        require(_interestPer3Min >= DIVISION_BASE); //interest must always be >= 1e18 otherwise it could decrease
        uint256 assetType = collateralProps[_collateralAddress].assetType;
        IVault vault = IVault(vaults[assetType]);
        //prevent setting liquidationRatio too low such that it would cause an overflow in callLiquidation, see appendix on liquidation maths for details.
        require( vault.LIQUIDATION_RETURN() *_liquidationRatio > 10 ** 36, "Liquidation ratio too low");

        queuedCollateralAddress = _collateralAddress;
        queuedCurrencyKey = _currencyKey;
        queuedMinimumRatio = _minimumRatio;
        queuedLiquidationRatio = _liquidationRatio;
        queuedInterestPer3Min = _interestPer3Min;
        queuedLiquidityPool = _liquidityPool;
        queuedTimestamp = block.timestamp;
    }
    /**
    * @notice Only Admin can modify collateral tokens, 
    * @notice forces virtualPrice to be up-to-date when updating to prevent retroactive interest rate changes.
    * @dev if time since last virtual price update is too long, 
    * @dev you must cycle it via the vault.updateVirtualPriceSlowly function or this function will revert
     */
    function changeCollateralType() external onlyAdmin {
        uint256 submissionTimestamp = queuedTimestamp;
        require(submissionTimestamp != 0, "Uninitialized collateral change");
        require(submissionTimestamp + CHANGE_COLLATERAL_DELAY <= block.timestamp, "Not enough time passed");
        address collateralAddress = queuedCollateralAddress;
        bytes32 currencyKey = queuedCurrencyKey;
        uint256 minimumRatio = queuedMinimumRatio;
        uint256 liquidationRatio = queuedLiquidationRatio;
        uint256 interestPer3Min = queuedInterestPer3Min;
        address liquidityPool = queuedLiquidityPool;
        

        //Now we must ensure interestPer3Min changes aren't applied retroactively
        // by updating the assets virtualPrice to current block timestamp
        uint256 timeDelta = (block.timestamp - collateralProps[collateralAddress].lastUpdateTime) / THREE_MIN;
        if (timeDelta != 0){ 
           updateVirtualPriceSlowly(collateralAddress, timeDelta );
        }
        bytes32 oldCurrencyKey = collateralProps[collateralAddress].currencyKey;

        _changeCollateralParameters(
            collateralAddress,
            currencyKey,
            minimumRatio,
            liquidationRatio,
            interestPer3Min
        );
        //Then update LiqPool as this isn't stored in the struct and requires the currencyKey also.
        liquidityPoolOf[oldCurrencyKey]= address(0); 
        liquidityPoolOf[currencyKey]= liquidityPool;
        
    }

   /** 
      * @dev This function should only be used by trusted functions that have validated all inputs already
      * @param _collateralAddress address of collateral token being used.
      * @param _currencyKey symbol() returned string, used for synthetix calls
      * @param _minimumRatio lowest margin ratio for opening debts with new collateral token
      * @param _liquidationRatio margin ratio at which a loan backed by said collateral can be liquidated.
      * @param _interestPer3Min interest charged per block to loan holders using this collateral.
     **/ 
    function _changeCollateralParameters(
        address _collateralAddress,
        bytes32 _currencyKey,
        uint256 _minimumRatio,
        uint256 _liquidationRatio,
        uint256 _interestPer3Min
        ) internal {
        collateralProps[_collateralAddress].currencyKey = _currencyKey;
        collateralProps[_collateralAddress].minOpeningMargin = _minimumRatio;
        collateralProps[_collateralAddress].liquidatableMargin = _liquidationRatio;
        collateralProps[_collateralAddress].interestPer3Min = _interestPer3Min;
    }

  /// @notice  Allows governance to pause a collateral type if necessary
  /// @param _collateralAddress the token address of the collateral we wish to remove
  /// @param _currencyKey the related synthcode, here we use this to prevent accidentally pausing the wrong collateral token.
  /// @dev this should only be called on collateral no longer used by loans.
  /// @dev This function can only be called if the collateral has been updated within 3min by calling updateVirtualPriceSlowly()
    function pauseCollateralType(
        address _collateralAddress,
        bytes32 _currencyKey
        ) external collateralExists(_collateralAddress) onlyAdmin {
        //checks two inputs to help prevent input mistakes
        require( _currencyKey == collateralProps[_collateralAddress].currencyKey, "Mismatched data");
        collateralPaused[_collateralAddress] = true;
        

        
    }

  /// @notice  Allows governance to unpause a collateral type if necessary
  /// @param _collateralAddress the token address of the collateral we wish to remove
  /// @param _currencyKey the related synthcode, here we use this to prevent accidentally unpausing the wrong collateral token.
  /// @dev this should only be called on collateral that should be reenabled for taking loans against
  /// @dev while a collateral is paused we charge no interest on it, so we update the timestamp to the current time to enforce this.
    function unpauseCollateralType(
        address _collateralAddress,
        bytes32 _currencyKey
        ) external collateralExists(_collateralAddress) onlyAdmin {
        require(collateralPaused[_collateralAddress], "Unsupported collateral or not Paused");
        //checks two inputs to help prevent input mistakes
        require( _currencyKey == collateralProps[_collateralAddress].currencyKey, "Mismatched data");
        collateralPaused[_collateralAddress] = false;
        
    }
    /// @dev Governnance callable only, this should be set once atomically on construction 
    /// @notice once called it can no longer be called.
    /// @param _vault the address of the vault system
    function addVaultAddress(address _vault, uint256 _assetType) external onlyAdmin{
        require(_vault != address(0), "Zero address");
        require(vaults[_assetType] == address(0), "Asset type already has vault");
        _setupRole(VAULT_ROLE, _vault);
        vaults[_assetType]= _vault;
    }
    
    /// @notice this takes in the updated virtual price of a collateral and records it as well as the time it was updated.
    /// @dev this should only be called by vault functions which have updated the virtual price and need to log this.
    /// @dev it is only callable by vault functions as a result.
    /// @notice both virtualPrice and updateTime are strictly monotonically increasing so we verify this with require statements
    /// @param _collateralAddress the token address of the collateral we are updating
    /// @param _virtualPriceUpdate interest calculation update for it's virtual price
    /// @param _updateTime block timestamp to keep track of last updated time.
    
    function _updateVirtualPriceAndTime(
        address _collateralAddress,
        uint256 _virtualPriceUpdate,
        uint256 _updateTime
        ) internal  {

        require( collateralProps[_collateralAddress].virtualPrice <= _virtualPriceUpdate, "Incorrect virtual price" );
        require( collateralProps[_collateralAddress].lastUpdateTime <= _updateTime, "Incorrect timestamp" );
        collateralProps[_collateralAddress].virtualPrice = _virtualPriceUpdate;
        collateralProps[_collateralAddress].lastUpdateTime = _updateTime;
    }

    /// @dev external function to enable the Vault to update the collateral virtual price & update timestamp
    ///      while maintaining the same method as the slow update below for consistency.
    function vaultUpdateVirtualPriceAndTime(
        address _collateralAddress,
        uint256 _virtualPriceUpdate,
        uint256 _updateTime
    ) external onlyVault collateralExists(_collateralAddress){
        uint256 assetType = collateralProps[_collateralAddress].assetType;
        require(vaults[assetType] == msg.sender, "Vaults can only update their own asset type");
        _updateVirtualPriceAndTime(_collateralAddress, _virtualPriceUpdate, _updateTime);
    }


    /// @dev this function is intentionally callable by anyone
    /// @notice it is designed to prevent DOS situations occuring if there is a long period of inactivity for a collateral token
    /// @param _collateralAddress the collateral token you are updating the virtual price of
    /// @param _cycles how many updates (currently equal to seconds) to process the virtual price for.
    function updateVirtualPriceSlowly(
        address _collateralAddress,
        uint256 _cycles
        ) public collateralExists(_collateralAddress){ 
            Collateral memory collateral = collateralProps[_collateralAddress];
            uint256 timeDelta = block.timestamp - collateral.lastUpdateTime;
            uint256 threeMinDelta = timeDelta / THREE_MIN;
            require(_cycles <= threeMinDelta, 'Cycle count too high');
                for (uint256 i = 0; i < _cycles; i++ ){
                    collateral.virtualPrice = (collateral.virtualPrice * collateral.interestPer3Min) / DIVISION_BASE; 
                }
            _updateVirtualPriceAndTime(_collateralAddress, collateral.virtualPrice, collateral.lastUpdateTime + (_cycles*THREE_MIN));
        }
    
    
    

    /**
      * @notice Only governance can add new collateral tokens
      * @dev adds new synth token to approved list of collateral
      * @dev includes sanity checks 
      * @param _collateralAddress address of collateral token being used.
      * @param _currencyKey symbol() returned string, used for synthetix calls
      * @param _minimumRatio lowest margin ratio for opening debts with new collateral token
      * @param _liquidationRatio margin ratio at which a loan backed by said collateral can be liquidated.
      * @param _interestPer3Min interest charged per block to loan holders using this collateral.
      * @param _assetType number to indicate what system this collateral token belongs to, 
                          used to determine value function in vault.
     **/
    function addCollateralType(
        address _collateralAddress,
        bytes32 _currencyKey,
        uint256 _minimumRatio,
        uint256 _liquidationRatio,
        uint256 _interestPer3Min,
        uint256 _assetType,
        address _liquidityPool
        ) external onlyAdmin {

        require(!collateralValid[_collateralAddress], "Collateral already exists");
        require(_collateralAddress != address(0));
        require(_minimumRatio > _liquidationRatio);
        require(_liquidationRatio > 0);
        require(_interestPer3Min >= DIVISION_BASE); //interest must always be >= 1 otherwise it could decrease
        require(vaults[_assetType] != address(0), "Vault not deployed yet");
        require(liquidityPoolOf[_currencyKey] == address(0), "CurrencyKey already in use");
        IVault vault = IVault(vaults[_assetType]);

        //prevent setting liquidationRatio too low such that it would cause an overflow in callLiquidation, see appendix on liquidation maths for details.
        require( vault.LIQUIDATION_RETURN() *_liquidationRatio > 10 ** 36, "Liquidation ratio too low"); //i.e. 1 when multiplying two 1 ether scale numbers.
        collateralValid[_collateralAddress] = true;
        collateralProps[_collateralAddress] = Collateral(
            _currencyKey,
            _minimumRatio,
            _liquidationRatio,
            _interestPer3Min,
            block.timestamp,
            1 ether,
            _assetType
            );
        //Then update LiqPool as this isn't stored in the struct and requires the currencyKey also.
        liquidityPoolOf[_currencyKey]= _liquidityPool; 
    }

}