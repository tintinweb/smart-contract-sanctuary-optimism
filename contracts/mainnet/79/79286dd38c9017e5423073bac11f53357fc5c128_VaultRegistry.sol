/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-09-09
*/

// File: github/pandadefi/registry/contracts/IVault.sol


pragma solidity ^0.8.15;

interface IVault {
    function token() external view returns (address);

    function apiVersion() external view returns (string memory);

    function governance() external view returns (address);

    function initialize(
        address _token,
        address _governance,
        address _rewards,
        string calldata _name,
        string calldata _symbol,
        address _guardian
    ) external;
}

// File: @openzeppelin/contracts/utils/Context.sol


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

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;


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

// File: github/pandadefi/registry/contracts/VaultRegistry.sol


pragma solidity ^0.8.15;



interface IReleaseRegistry {
    function numReleases() external view returns (uint256);

    function releases(uint256 _version) external view returns (address);

    function newVault(
        address _token,
        address _governance,
        address _guardian,
        address _rewards,
        string calldata _name,
        string calldata _symbol,
        uint256 _releaseDelta
    ) external returns (address);
}

contract VaultRegistry is Ownable {
    uint256 constant DEFAULT_TYPE = 1;
    address immutable LEGACY_REGISTRY;

    address public releaseRegistry;
    // token => vaults
    mapping(address => address[]) public vaults;
    address[] public tokens;
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public vaultType;
    mapping(address => bool) public approvedVaultsOwner;
    mapping(address => bool) public isVaultEndorsed;
    mapping(address => bool) public vaultEndorsers;

    event NewVault(
        address indexed token,
        uint256 indexed vaultId,
        uint256 vaultType,
        address vault,
        string apiVersion
    );

    event ApprovedVaultOwnerUpdated(address governance, bool approved);

    event ApprovedVaultEndorser(address account, bool canEndorse);
    event ReleaseRegistryUpdated(address newRegistry);

    error GovernanceMismatch(address vault);
    error NotAllowedToEndorse();
    error VersionMissmatch(string v1, string v2);
    error EndorseVaultWithSameVersion(address existingVault, address newVault);
    error VaultAlreadyEndorsed(address vault, uint256 vaultType);
    error InvalidVaultType();

    constructor(address _releaseRegistry, address _legacyRegistry) {
        releaseRegistry = _releaseRegistry;
        LEGACY_REGISTRY = _legacyRegistry;
        emit ReleaseRegistryUpdated(_releaseRegistry);
    }

    function numTokens() external view returns (uint256) {
        return tokens.length;
    }

    function numVaults(address _token) external view returns (uint256) {
        return _numVaults(_token);
    }

    function _numVaults(address _token) internal view returns (uint256) {
        return vaults[_token].length;
    }

    function _latestVault(address _token) internal view returns (address) {
        uint256 length = _numVaults(_token);
        if (length == 0) {
            return _fetchFromLegacy(_token);
        }
        return vaults[_token][length - 1];
    }

    function _latestVaultOfType(address _token, uint256 _type)
        internal
        view
        returns (address)
    {
        uint256 length = _numVaults(_token);
        if (length == 0) {
            return address(0);
        }
        uint256 i = length - 1;
        while (true) {
            address vault = vaults[_token][i];
            if (vaultType[vault] == _type) {
                return vault;
            }
            if (i == 0) {
                break;
            }
            unchecked {
                i--;
            }
        }
        return address(0);
    }

    function _fetchFromLegacy(address _token) internal view returns (address) {
        bytes memory data = abi.encodeWithSignature(
            "latestVault(address)",
            _token
        );
        (bool success, bytes memory returnBytes) = address(LEGACY_REGISTRY)
            .staticcall(data);
        if (success) {
            return abi.decode(returnBytes, (address));
        }
        return address(0);
    }

    /**
     @notice Returns the latest deployed vault for the given token.
     @dev Return zero if no vault is associated with the token
     @param _token The token address to find the latest vault for.
     @return The address of the latest vault for the given token.
     */
    function latestVault(address _token) external view returns (address) {
        return _latestVault(_token);
    }

    /**
     @notice Returns the latest deployed vault for the given token and type.
     @dev Return zero if no vault exists for both token and type.
     @param _token The token address to find the latest vault for.
     @param _type The vault type to find the latest vault for.
     @return The address of the latest vault found matching both token and type.
     */
    function latestVaultOfType(address _token, uint256 _type)
        external
        view
        returns (address)
    {
        return _latestVaultOfType(_token, _type);
    }

    function _registerVault(
        address _token,
        address _vault,
        uint256 _type
    ) internal {
        // Check if there is an existing deployment for this token + type combination at the particular api version
        // NOTE: This doesn't check for strict semver-style linearly increasing release versions
        if (vaultType[_vault] != 0) {
            revert VaultAlreadyEndorsed(_vault, vaultType[_vault]);
        }

        if (_type == 0) {
            revert InvalidVaultType();
        }

        address latest = _latestVaultOfType(_token, _type);
        if (latest != address(0)) {
            if (
                keccak256(bytes(IVault(latest).apiVersion())) ==
                keccak256(bytes(IVault(_vault).apiVersion()))
            ) {
                revert EndorseVaultWithSameVersion(latest, _vault);
            }
        }
        uint256 id = _numVaults(_token);
        // Update the latest deployment
        vaults[_token].push(_vault);
        vaultType[_vault] = _type;

        // Register tokens for endorsed vaults
        if (isRegistered[_token] == false) {
            isRegistered[_token] = true;
            tokens.push(_token);
        }
        isVaultEndorsed[_vault] = true;
        emit NewVault(_token, id, _type, _vault, IVault(_vault).apiVersion());
    }

    /**
     @notice
         Adds an existing vault to the list of "endorsed" vaults for that token.
     @dev
         `governance` is set in the new vault as `governance`, with no ability to override.
         Throws if caller isn't `governance`.
         Throws if `vault`'s governance isn't `governance`.
         Throws if no releases are registered yet.
         Throws if `vault`'s api version does not match latest release.
         Throws if there already is a deployment for the vault's token with the latest api version.
         Emits a `NewVault` event.
     @param _vault The vault that will be endorsed by the Registry.
     @param _releaseDelta Specify the number of releases prior to the latest to use as a target. DEFAULT_TYPE is latest.
     @param _type Vault type
    */
    function endorseVault(
        address _vault,
        uint256 _releaseDelta,
        uint256 _type
    ) public {
        if (vaultEndorsers[msg.sender] == false) {
            revert NotAllowedToEndorse();
        }

        if (approvedVaultsOwner[IVault(_vault).governance()] == false) {
            revert GovernanceMismatch(_vault);
        }

        // NOTE: Underflow if no releases created yet, or targeting prior to release history
        uint256 releaseTarget = IReleaseRegistry(releaseRegistry)
            .numReleases() -
            1 -
            _releaseDelta; // dev: no releases
        string memory apiVersion = IVault(
            IReleaseRegistry(releaseRegistry).releases(releaseTarget)
        ).apiVersion();
        if (
            keccak256(bytes((IVault(_vault).apiVersion()))) !=
            keccak256(bytes((apiVersion)))
        ) {
            revert VersionMissmatch(IVault(_vault).apiVersion(), apiVersion);
        }
        // Add to the end of the list of vaults for token
        _registerVault(IVault(_vault).token(), _vault, _type);
    }

    function endorseVault(address _vault, uint256 _releaseDelta) external {
        endorseVault(_vault, _releaseDelta, DEFAULT_TYPE);
    }

    function endorseVault(address _vault) external {
        endorseVault(_vault, 0, DEFAULT_TYPE);
    }

    function newVault(
        address _token,
        address _guardian,
        address _rewards,
        string calldata _name,
        string calldata _symbol,
        uint256 _releaseDelta
    ) external returns (address) {
        return
            newVault(
                _token,
                msg.sender,
                _guardian,
                _rewards,
                _name,
                _symbol,
                _releaseDelta,
                DEFAULT_TYPE
            );
    }

    /**
    @notice
        Create a new vault for the given token using the latest release in the registry,
        as a simple "forwarder-style" delegatecall proxy to the latest release.
    @dev
        `governance` is set in the new vault as `governance`, with no ability to override.
        Throws if caller isn't `governance`.
        Throws if no releases are registered yet.
        Throws if there already is a registered vault for the given token with the latest api version.
        Emits a `NewVault` event.
    @param _token The token that may be deposited into the new Vault.
    @param _guardian The address authorized for guardian interactions in the new Vault.
    @param _rewards The address to use for collecting rewards in the new Vault
    @param _name Specify a custom Vault name. Set to empty string for DEFAULT_TYPE choice.
    @param _symbol Specify a custom Vault symbol name. Set to empty string for DEFAULT_TYPE choice.
    @param _releaseDelta Specify the number of releases prior to the latest to use as a target. DEFAULT_TYPE is latest.
    @param _type Vault type
    @return The address of the newly-deployed vault
     */
    function newVault(
        address _token,
        address _governance,
        address _guardian,
        address _rewards,
        string calldata _name,
        string calldata _symbol,
        uint256 _releaseDelta,
        uint256 _type
    ) public returns (address) {
        require(vaultEndorsers[msg.sender], "unauthorized");
        require(approvedVaultsOwner[_governance], "not allowed vault owner");
        address vault = IReleaseRegistry(releaseRegistry).newVault(
            _token,
            _governance,
            _guardian,
            _rewards,
            _name,
            _symbol,
            _releaseDelta
        );
        _registerVault(_token, vault, _type);
        return vault;
    }

    /**
    @notice Set the ability of a particular tagger to tag current vaults.
    @dev Throws if caller is not `governance`.
    @param _addr The address to approve or deny access.
    @param _approved Allowed to endorse
     */
    function setVaultEndorsers(address _addr, bool _approved)
        external
        onlyOwner
    {
        vaultEndorsers[_addr] = _approved;
        emit ApprovedVaultEndorser(_addr, _approved);
    }

    /**
    @notice Set the vaults owners
    @dev Throws if caller is not `governance`.
    @param _addr The address to approve or deny access.
    @param _approved Allowed to own vault
     */
    function setApprovedVaultsOwner(address _addr, bool _approved)
        external
        onlyOwner
    {
        approvedVaultsOwner[_addr] = _approved;
        emit ApprovedVaultOwnerUpdated(_addr, _approved);
    }

    function updateReleaseRegistry(address _newRegistry) external onlyOwner {
        releaseRegistry = _newRegistry;
        emit ReleaseRegistryUpdated(_newRegistry);
    }
}