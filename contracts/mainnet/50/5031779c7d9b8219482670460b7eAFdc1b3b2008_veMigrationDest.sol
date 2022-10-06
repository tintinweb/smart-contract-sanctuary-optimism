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
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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
abstract contract ReentrancyGuard {
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

    constructor() {
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
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
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

pragma solidity ^0.8.0;

interface IAnyCall {
    function anyCall(
        address _to,
        bytes calldata _data,
        address _fallback,
        uint256 _toChainID,
        uint256 _flags
    ) external;

    function executor() external view returns (address executor);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC20 {
    function mint(address to, uint256 amount) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IExecutor {
    function context()
        external
        returns (
            address from,
            uint256 fromChainID,
            uint256 nonce
        );
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IVotingEscrow {
    struct LockedBalance {
        int128 amount;
        uint256 end;
    }

    function create_lock_for(
        uint256 _value,
        uint256 _lock_duration,
        address _to
    ) external returns (uint256);

    function locked(uint256 tokenId) external view returns (LockedBalance memory lock);

    function ownerOf(uint256 _tokenId) external view returns (address);

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IAnyCall.sol";
import "./interfaces/IExecutor.sol";
import "./interfaces/IERC20.sol";

struct MigrationLock {
    uint256 amount;
    uint256 duration;
}

contract veMigrationDest is Ownable, ReentrancyGuard {
    address public immutable ibToken;
    address public immutable anycallExecutor;
    address public immutable anyCall;
    address public immutable veIB;
    uint256 public immutable srcChainId;
    address public sender;

    /// @notice emitted when migration is successful on destination chain
    /// @param user user address
    /// @param oldTokenIds old tokenIds of the user
    /// @param newTokenIds new tokenIds of the user after migration
    event MigrationCompleted(address user, uint256[] oldTokenIds, uint256[] newTokenIds);

    modifier onlyExecutor() {
        require(msg.sender == anycallExecutor, "Only executor can call this function");
        _;
    }

    /// @notice Contract constructor, can be deployed on both the source chain and the destination chainz
    /// @param _ibToken ibToken address
    /// @param _anyCall anyCall address
    /// @param _veIB veIB address
    constructor(
        address _ibToken,
        address _anyCall,
        address _veIB,
        uint256 _srcChainId
    ) {
        require(_ibToken != address(0), "ibToken address cannot be 0");
        require(_anyCall != address(0), "anyCall address cannot be 0");
        require(_veIB != address(0), "veIB address cannot be 0");

        ibToken = _ibToken;
        anyCall = _anyCall;
        anycallExecutor = IAnyCall(_anyCall).executor();
        veIB = _veIB;
        srcChainId = _srcChainId;
    }

    function setup(address _sender) external onlyOwner {
        require(_sender != address(0), "_sender address cannot be 0");
        sender = _sender;
    }

    /// @notice function only callable by anyCall executor, it will be called on destination chain and the source chain
    ///         upon a successful call on the dest chain, it will execute the normal migration flow
    ///         if such call fails, it will in turn call the anyCall executor to initiate a call on the source chain
    ///         with the function selector as anyFallback, which will then log the failure on the source chain
    /// @param data abi encoded data of the anyCall
    /// @return success true if migration is successful
    /// @return result return message
    function anyExecute(bytes calldata data) external onlyExecutor nonReentrant returns (bool success, bytes memory result) {
        (address callFrom, uint256 fromChainID, ) = IExecutor(anycallExecutor).context();
        bool isValidSource = callFrom == sender && fromChainID == srcChainId;
        if (!isValidSource) {
            return (false, "invalid source");
        }
        executeMigration(data);
        return (true, "");
    }

    /// @notice function to execute migration on destination chain
    /// @param data encoded data of tokenIds, lockBalances and user address
    function executeMigration(bytes calldata data) internal {
        (address user, uint256[] memory oldTokenIds, MigrationLock[] memory migrationLocks) = abi.decode(data, (address, uint256[], MigrationLock[]));
        uint256[] memory newTokenIds = new uint256[](oldTokenIds.length);
        for (uint256 i = 0; i < migrationLocks.length; i++) {
            uint256 amount = migrationLocks[i].amount;
            IERC20(ibToken).approve(veIB, amount);
            uint256 tokenId = IVotingEscrow(veIB).create_lock_for(amount, migrationLocks[i].duration, user);
            newTokenIds[i] = tokenId;
        }
        emit MigrationCompleted(user, oldTokenIds, newTokenIds);
    }
}