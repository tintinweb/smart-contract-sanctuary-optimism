// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

import "./interfaces/IAddressStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IBaseURI {
    function setBaseURI(string memory _baseUri) external;
}

contract AddressStorage is IAddressStorage, Ownable {
    address public override cellar;
    address public override vinegar;
    address public override vineyard;
    address public override bottle;
    address public override giveawayToken;
    address public override royaltyManager;
    address public override alchemy;
    address public override grape;
    address public override spellParams;

    address public override wineUri;
    address public override vineUri;

    bool private addressesSet = false;

    // EVENTS
    event AddressesSet();

    // CONSTRUCTOR
    constructor() Ownable() {}

    // PUBLIC FUNCTIONS
    /// @notice sets addresses for ecosystem
    function setAddresses(
        address _cellar,
        address _vinegar,
        address _vineyard,
        address _bottle,
        address _giveawayToken,
        address _royaltyManager,
        address _alchemy,
        address _grape,
        address _spellParams,
        address _wineUri,
        address _vineUri
    ) public onlyOwner {
        require(addressesSet == false, "already set");
        cellar = _cellar;
        vinegar = _vinegar;
        vineyard = _vineyard;
        bottle = _bottle;
        giveawayToken = _giveawayToken;
        royaltyManager = _royaltyManager;
        alchemy = _alchemy;
        grape = _grape;
        spellParams = _spellParams;
        wineUri = _wineUri;
        vineUri = _vineUri;
        addressesSet = true;
        emit AddressesSet();
    }

    function newRoyaltyManager(address _royaltyManager) external onlyOwner {
        royaltyManager = _royaltyManager;
        emit AddressesSet();
    }

    function newVineUri(address _newVineUri) external onlyOwner {
        vineUri = _newVineUri;
        emit AddressesSet();
    }

    function newWineUri(address _newWineUri) external onlyOwner {
        wineUri = _newWineUri;
        emit AddressesSet();
    }

    function newSpellParams(address _newParams) external onlyOwner {
        spellParams = _newParams;
        emit AddressesSet();
    }

    function setVineBaseUri(string memory _baseUri) external onlyOwner {
        IBaseURI(vineyard).setBaseURI(_baseUri);
    }

    function setWineBaseUri(string memory _baseUri) external onlyOwner {
        IBaseURI(bottle).setBaseURI(_baseUri);
    }
}

// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IAddressStorage {
    function cellar() external view returns (address);

    function vinegar() external view returns (address);

    function vineyard() external view returns (address);

    function bottle() external view returns (address);

    function giveawayToken() external view returns (address);

    function royaltyManager() external view returns (address);

    function alchemy() external view returns (address);

    function grape() external view returns (address);

    function spellParams() external view returns (address);

    function wineUri() external view returns (address);

    function vineUri() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
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