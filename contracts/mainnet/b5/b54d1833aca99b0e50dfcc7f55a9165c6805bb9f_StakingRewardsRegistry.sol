/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-03-08
*/

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

// File: Context.sol

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

// File: Ownable.sol

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

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

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
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
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

// File: StakingRewardsRegistry.sol

interface IStakingRewards {
    function stakingToken() external view returns (address);

    function owner() external view returns (address);
}

contract StakingRewardsRegistry is Ownable {
    /* ========== STATE VARIABLES ========== */

    /// @notice If a stakingPool exists for a given token, it will be shown here.
    /// @dev Only stakingPools added to this registry will be shown.
    mapping(address => address) public stakingPool;

    /// @notice Tokens that this registry has added stakingPools for.
    address[] public tokens;

    /// @notice Check if an stakingPool exists for a given vault token.
    mapping(address => bool) public isRegistered;

    /// @notice Check if an address is allowed to own stakingPools from this registry.
    mapping(address => bool) public approvedPoolOwner;

    /// @notice Check if a given stakingPool is known to this registry.
    mapping(address => bool) public isStakingPoolEndorsed;

    /// @notice Check if an address can add pools to this registry.
    mapping(address => bool) public poolEndorsers;

    /* ========== EVENTS ========== */

    event StakingPoolAdded(address indexed token, address indexed stakingPool);
    event ApprovedPoolOwnerUpdated(address governance, bool approved);
    event ApprovedPoolEndorser(address account, bool canEndorse);

    /* ========== VIEWS ========== */

    /// @notice The number of tokens with staking pools added to this registry.
    function numTokens() external view returns (uint256) {
        return tokens.length;
    }

    /* ========== CORE FUNCTIONS ========== */

    /**
    @notice
        Add a new staking pool to our registry, for new or existing tokens.
    @dev
        Throws if governance isn't set properly.
        Throws if sender isn't allowed to endorse.
        Throws if replacement is handled improperly.
        Emits a StakingPoolAdded event.
    @param _stakingPool The address of the new staking pool.
    @param _token The token to be deposited into the new staking pool.
    @param _replaceExistingPool If we are replacing an existing staking pool, set this to true.
     */
    function addStakingPool(
        address _stakingPool,
        address _token,
        bool _replaceExistingPool
    ) public {
        // don't let just anyone add to our registry
        require(poolEndorsers[msg.sender], "unauthorized");

        // load up the staking pool contract
        IStakingRewards stakingRewards = IStakingRewards(_stakingPool);

        // check that gov is correct on the staking contract
        address poolGov = stakingRewards.owner();
        require(approvedPoolOwner[poolGov], "not allowed pool owner");

        // make sure we didn't mess up our token/staking pool match
        require(
            stakingRewards.stakingToken() == _token,
            "staking token doesn't match"
        );

        // Make sure we're only using the latest stakingPool in our registry
        if (_replaceExistingPool) {
            require(
                isRegistered[_token] == true,
                "token isn't registered, can't replace"
            );
            address oldPool = stakingPool[_token];
            isStakingPoolEndorsed[oldPool] = false;
            stakingPool[_token] = _stakingPool;
        } else {
            require(
                isRegistered[_token] == false,
                "replace instead, pool already exists"
            );
            stakingPool[_token] = _stakingPool;
            isRegistered[_token] = true;
            tokens.push(_token);
        }

        isStakingPoolEndorsed[_stakingPool] = true;
        emit StakingPoolAdded(_token, _stakingPool);
    }

    /* ========== SETTERS ========== */

    /**
    @notice Set the ability of an address to endorse staking pools.
    @dev Throws if caller is not owner.
    @param _addr The address to approve or deny access.
    @param _approved Allowed to endorse
     */
    function setPoolEndorsers(address _addr, bool _approved)
        external
        onlyOwner
    {
        poolEndorsers[_addr] = _approved;
        emit ApprovedPoolEndorser(_addr, _approved);
    }

    /**
    @notice Set the staking pool owners
    @dev Throws if caller is not owner.
    @param _addr The address to approve or deny access.
    @param _approved Allowed to own staking pools
     */
    function setApprovedPoolOwner(address _addr, bool _approved)
        external
        onlyOwner
    {
        approvedPoolOwner[_addr] = _approved;
        emit ApprovedPoolOwnerUpdated(_addr, _approved);
    }
}