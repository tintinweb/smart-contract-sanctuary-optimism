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
    )
        external
        onlyOwner
    {
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
    )
        external
        onlyWhitelistOperator(_safe)
    {
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
    )
        external
        onlyWhitelistOperator(_safe)
    {
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
    )
        external
        onlyWhitelistOperator(_safe)
    {
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