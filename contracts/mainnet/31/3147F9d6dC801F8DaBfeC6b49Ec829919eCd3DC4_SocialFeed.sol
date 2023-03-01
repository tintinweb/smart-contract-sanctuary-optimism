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
pragma solidity ^0.8.9;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Social Feed Contract
/// @author trmid.eth
/// @notice Allows the owner to manage a social feed that can be queried by clients
contract SocialFeed is Ownable {

    // Variables:
    uint64 _nextId;
    uint64 _numDeleted;
    mapping(uint64 => string) _postUri;
    mapping(uint64 => string) _postMetadata;
    mapping(address => bool) _isEditor;

    // Events:
    event Post(uint64 indexed id, string uri);
    event PostWithMetadata(uint64 indexed id, string uri, string metadata);
    event RemovePost(uint64 indexed id);
    event AddEditor(address indexed editor);
    event RemoveEditor(address indexed editor, address remover);

    /// @param editors The initial editors of the contract
    constructor(address[] memory editors) Ownable() {
        for(uint8 i = 0; i < editors.length; i++) {
            addEditor(editors[i]);
        }
    }

    /// @return uint64 current number of posts
    function numPosts() external view  returns(uint64) {
        return _nextId - _numDeleted;
    }

    /// @dev Not gas optimized! Designed for read-only use!
    /// @notice Fetches a list of recent posts (posts that have been removed will be empty strings)
    /// @param offset The amount of posts to skip (starting at the most recent)
    /// @param depth How many posts to return in the results. Use '0' to return all posts
    /// @return (string[] uri, string[] metadata, uint64[] postId)  
    function feed(uint64 offset, uint64 depth) external view returns(string[] memory, string[] memory, uint64[] memory) {
        require(_nextId >= offset, "offset too big");
        if(depth == 0 || depth > _nextId - offset) depth = _nextId - offset;
        string[] memory uri = new string[](depth);
        string[] memory metadata = new string[](depth);
        uint64[] memory postId = new uint64[](depth);
        if(depth == 0) return(uri, metadata, postId);
        for(uint64 index; index < depth; index++) {
            uint64 id = _nextId - index - offset - 1;
            uri[index] = _postUri[id];
            metadata[index] = _postMetadata[id];
            postId[index] = id;
        }
        return(uri, metadata, postId);
    }

    /// @notice Checks if an address is an editor
    /// @param editor The address to check
    /// @return bool
    function isEditor(address editor) public view returns(bool) {
        return _isEditor[editor];
    }

    /// @notice (Only Owner) Adds a new address as an editor
    /// @param editor The address to add
    function addEditor(address editor) public onlyOwner {
        require(!_isEditor[editor], "already editor");
        _isEditor[editor] = true;
        emit AddEditor(editor);
    }

    /// @notice (Only Owner or Self) Removes editor permissions from an address
    /// @param editor The address to remove permissions from
    /// @dev Rejects if address is not editor
    function removeEditor(address editor) public {
        require(_msgSender() == owner() || _msgSender() == editor, "not owner or self");
        require(_isEditor[editor], "not editor");
        delete _isEditor[editor];
        emit RemoveEditor(editor, _msgSender());
    }

    /// @notice (Only Editor) Pushes a post to the feed with only a URI
    function post(string calldata uri) external {
        post(uri, "");
    }

    /// @notice (Only Editor) Pushes a post to the feed with a URI and Metadata
    function post(string calldata uri, string memory metadata) public {
        require(_isEditor[_msgSender()], "not editor");
        _postUri[_nextId] = uri;
        if(bytes(metadata).length > 0) {
            _postMetadata[_nextId] = metadata;
            emit PostWithMetadata(_nextId, uri, metadata);
        } else {
            emit Post(_nextId, uri);
        }
        ++_nextId;
    }

    /// @notice (Only Editor) Removes the post with the given ID
    function removePost(uint64 id) external {
        require(_isEditor[_msgSender()], "not editor");
        require(bytes(_postUri[id]).length > 0, "post dne");
        delete _postUri[id];
        delete _postMetadata[id];
        ++_numDeleted;
        emit RemovePost(id);
    }
}