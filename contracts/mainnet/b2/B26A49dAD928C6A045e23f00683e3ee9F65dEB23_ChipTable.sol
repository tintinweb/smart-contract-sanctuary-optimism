/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-08-23
*/

pragma solidity ^0.8.5;

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


// File contracts/intf/IChipTable.sol

/***
 * == Developer History (NAME, ORG, DATE, DESCR) ==
 * Isaac Dubuque, Verilink, 7/24/22, Initial Commit
 * ================================================
 * 
 * File: IChipTable.sol
 * Description: Chip Table Interface
 */



/***
 * IChipTable
 * Provides the interface for the ERS interim on-chain chip resolution
 * The Chip Table allows the owner to register Trusted Service Managers (TSM)
 * TSMs can add chips allowing for a decentralized chip resolution
 * Chips can be look up their TSM for device information and redirect resolution
 */
interface IChipTable is IERC165
{
  /**
   * Registered TSM
   */
  event TSMRegistered(address tsmAddress, string tsmUri);
  
  /**
   * TSM approved operator
   */
  event TSMApproved(address tsmAddress, address operator);

  /**
   * Chip Registered with ERS
   */
  event ChipRegistered(bytes32 chipId, address tsmAddress);

  /**
   * TSM updated
   */
  event TSMUpdate(address tsmAddress, string tsmUri);

  /**
    Registry Version
   */
  function registryVersion() external returns (string memory);

  /**
   * Registers a TSM 
   * Permissions: Owner
   */
  function registerTSM(
    address tsmAddress, 
    string calldata uri) external;
  
  /**
   * Registers Chip Ids without signatures
   * Permissions: Owner
   */
  function registerChipIds(
    address tsmAddress,
    bytes32[] calldata chipIds
  ) external;

  /**
   * Registers Chip Ids with Signatures
   * Permissions: Owner
   */
  function safeRegisterChipIds(
    address tsmAddress,
    bytes32[] calldata chipIds,
    bytes[] calldata signatures
  ) external;

  /**
   * Returns the number of registered TSMs
   */
  function totalTSMs() 
    external view returns (uint256);

  /**
   * Returns the TSM Id by Index
   */
  function tsmByIndex(uint256 index) 
    external view returns (address);

  /**
   * Returns the TSM uri
   */
  function tsmUri(address tsmAddress) 
    external view returns (string memory);

  /**
   * Sets the TSM uri
   */
  function tsmSetUri(string calldata uri) external;

  /**
   * Returns the TSM operator
   */
  function tsmOperator(address tsmAddress) 
    external view returns (address);

  /**
   * Approves an operator for a TSM
   */
  function approve(address operator) external;

  /**
   * Adds a ChipId
   * requires a signature
   * Permissions: TSM
   */
  function addChipId(
    address tsmAddress, 
    bytes32 chipId, 
    bytes calldata signature) external;

  /**
   * Adds ChipIds
   * requires a signature
   * Permissions: TSM
   */
  function addChipIds(
    address tsmAddress,
    bytes32[] calldata chipIds,
    bytes[] calldata signatures
  ) external;

  /**
   * gets a Chip's TSM Id
   */
  function chipTSM(bytes32 chipId) 
    external view returns (address);

  /**
   * Gets the Chip Redirect Uri
   */
  function chipUri(bytes32 chipId) 
    external view returns (string memory);
  
  /**
   * Get whether chip exists
   */
  function chipExists(bytes32 chipId)
    external view returns (bool);
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


// File @openzeppelin/contracts/access/[email protected]


// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)



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


// File contracts/src/chipTable.sol

/***
 * == Developer History (NAME, ORG, DATE, DESCR) ==
 * Isaac Dubuque, Verilink, 7/24/22, Initial Commit
 * ================================================
 * 
 * File: ChipTable.sol
 * Description: Chip Table Implementation
 */




/***
 * ChipTable
 * Provides the implementation for the ERS interim on-chain chip resolution
 * The Chip Table allows the owner to register Trusted Service Managers (TSM)
 * TSMs can add chips allowing for a decentralized chip resolution
 * Chips can be look up their TSM for device information and redirect resolution
 */
contract ChipTable is IChipTable, Context, Ownable
{
  struct TSM 
  {
    bool _isRegistered;
    address _operator;
    string _uri;
  }

  struct ChipInfo
  {
    address _tsmAddress;
  }

  mapping(address => TSM) private _tsms; /* mapping tsmAddress => TSM */
  mapping(bytes32 => ChipInfo) private _chipIds; /* mapping from chipId => ChipInfo */
  mapping(uint256 => address) private _tsmIndex; /* mapping from TSM index => tsmAddress */
  uint256 private _tsmCount;

  string private VERSION;

  constructor(address _contractOwner, string memory _registryVersion)
  {
    transferOwnership(_contractOwner);
    _tsmCount = 0;
    VERSION = _registryVersion;
  }

  function supportsInterface(bytes4 interfaceId)
    external pure override returns (bool)
  {
    return interfaceId == type(IChipTable).interfaceId;
  }

  function registryVersion() external view override returns (string memory)
  {
    return VERSION;
  }

  /*=== OWNER ===*/
  function registerTSM(
    address tsmAddress, 
    string calldata uri) external override onlyOwner 
  {
    _registerTSM(tsmAddress, uri);

    /* update indexing */
    _tsmIndex[_tsmCount] = tsmAddress;
    _tsmCount = _tsmCount + 1;
  }

  function registerChipIds(
    address tsmAddress,
    bytes32[] calldata chipIds
  ) external override onlyOwner
  { 
    require(_tsmExists(tsmAddress), "Owner: TSM does not exist");
    for(uint256 i = 0; i < chipIds.length; i++)
    {
      _addChip(tsmAddress, chipIds[i]);
    }
  }

  function safeRegisterChipIds(
    address tsmAddress,
    bytes32[] calldata chipIds,
    bytes[] calldata signatures
  ) external override onlyOwner
  { 
    require(_tsmExists(tsmAddress), "Owner: TSM does not exist");
    require(chipIds.length == signatures.length, "Owner: chipIds and signatures length mismatch");
    for(uint256 i = 0; i < chipIds.length; i++)
    {
      _addChipSafe(tsmAddress, chipIds[i], signatures[i]);
    }
  }


  /*=== END OWNER ===*/

  /*=== TSM ===*/
  modifier onlyTSM(address tsmAddress) 
  {
    _checkTSM(tsmAddress);
    _;
  }

  function _checkTSM(address tsmAddress) internal view
  {
    require(_tsmExists(tsmAddress), "TSM: tsm does not exist");
  }

  modifier onlyTSMOrApproved(address tsmAddress)
  {
    _checkTSMOrApproved(tsmAddress);
    _;
  }

  function _checkTSMOrApproved(address tsmAddress) internal view
  {
    require(_tsmExists(tsmAddress) && (
      (_msgSender() == tsmOperator(tsmAddress)) ||
      (_msgSender() == tsmAddress)),
      "TSM: caller is not TSM or approved");
  }

  function _registerTSM(
    address tsmAddress, 
    string calldata uri) internal
  {
    require(!_tsmExists(tsmAddress), "Owner: TSM already registered");
    _tsms[tsmAddress]._isRegistered = true;
    _tsms[tsmAddress]._operator = address(0);
    _tsms[tsmAddress]._uri = uri;
    emit TSMRegistered(tsmAddress, uri);
  }

  function _tsmExists(address tsmAddress) internal view returns (bool)
  {
    return _tsms[tsmAddress]._isRegistered != false;
  }


  function totalTSMs() external override view returns (uint256)
  {
    return _tsmCount;
  }

  function tsmByIndex(uint256 index) external override view returns (address)
  {
    require(index < _tsmCount, "TSM: index out of bounds");
    return _tsmIndex[index];
  }

  function tsmUri(address tsmAddress) 
    public override view onlyTSM(tsmAddress) returns (string memory) 
  {
    return _tsms[tsmAddress]._uri;
  }

  function tsmSetUri(string calldata uri) 
    public override onlyTSM(_msgSender())
  {
    _tsms[_msgSender()]._uri = uri;
    emit TSMUpdate(_msgSender(), uri);
  }
  
  function tsmOperator(address tsmAddress) 
    public override view onlyTSM(tsmAddress) returns (address)
  {
    return _tsms[tsmAddress]._operator;
  }

  function approve(address operator) external override onlyTSM(_msgSender())
  {
    _tsms[_msgSender()]._operator = operator;
    emit TSMApproved(_msgSender(), operator);
  }

  function addChipId(
    address tsmAddress, 
    bytes32 chipId, 
    bytes calldata signature) external override onlyTSMOrApproved(tsmAddress)
  {
    _addChipSafe(tsmAddress, chipId, signature);
  }

  function addChipIds(
    address tsmAddress,
    bytes32[] calldata chipIds,
    bytes[] calldata signatures
  ) external override onlyTSMOrApproved(tsmAddress)
  { 
    require(chipIds.length == signatures.length, "TSM: chipIds and signatures length mismatch");
    for(uint256 i = 0; i < chipIds.length; i++)
    {
      _addChipSafe(tsmAddress, chipIds[i], signatures[i]);
    }
  }

  /*=== END TSM ===*/

  /*=== CHIP ===*/
  function _chipExists(bytes32 chipId) internal view returns (bool)
  {
    return _chipIds[chipId]._tsmAddress != address(0);
  }

  function _isValidChipSignature(address tsmAddress, bytes32 chipId, bytes calldata signature) internal pure returns (bool)
  {
    address _signer;
    bytes32 msgHash;
    bytes32 _r;
    bytes32 _s;
    uint8 _v;

    /* Implementation for Kong Halo Chip 2021 Edition */
    require(signature.length == 65, "Chip: invalid sig length");

      /* unpack v, s, r */
    _r = bytes32(signature[0:32]);
    _s = bytes32(signature[32:64]);
    _v = uint8(signature[64]);

    if(uint256(_s) > 
      0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0)
    {
      revert("Chip: invalid sig `s`");
    }

    if(_v != 27 && _v != 28)
    {
      revert("Chip: invalid sig `v`");
    }

    msgHash = keccak256(
      abi.encodePacked(
        "\x19Ethereum Signed Message:\n32",
        keccak256(abi.encodePacked(tsmAddress))
      )
    );

    _signer = ecrecover(msgHash, _v, _r, _s);
    
    require(_signer != address(0x0), "Chip: invalid signer");

    return _signer == address(uint160(uint256(chipId)));
  }

  function _addChipSafe(address tsmAddress, bytes32 chipId, bytes calldata signature) internal
  {
    require(_isValidChipSignature(tsmAddress, chipId, signature), "Chip: chip signature invalid");
    _addChip(tsmAddress, chipId);
  }

  function _addChip(address tsmAddress, bytes32 chipId) internal
  {
    require(!_chipExists(chipId), "Chip: chip already exists");
    _chipIds[chipId]._tsmAddress = tsmAddress;
    emit ChipRegistered(chipId, tsmAddress);
  }

  function chipTSM(bytes32 chipId) public override view returns (address)
  {
    require(_chipExists(chipId), "Chip: chip doesn't exist");
    return _chipIds[chipId]._tsmAddress;
  }
  
  function chipUri(bytes32 chipId) external override view returns (string memory)
  {
    return tsmUri(chipTSM(chipId));
  }

  function chipExists(bytes32 chipId) public override view returns (bool)
  {
    return _chipExists(chipId);
  }

  /*=== END CHIP ===*/
}