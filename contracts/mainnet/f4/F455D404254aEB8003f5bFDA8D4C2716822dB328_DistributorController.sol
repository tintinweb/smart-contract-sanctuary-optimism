pragma solidity 0.8.6;

import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface ICumulativeMerkleDistributor {
    function updateRoot(bytes32 _newRoot) external;

    function withdrawTokens(address _to, uint256 _amount) external;

    function withdrawNative(address _to, uint256 _amount) external;

    function transferOwnership(address newOwner) external;

    function TOKEN() external returns (address);
}

contract DistributorController is Ownable {
    ICumulativeMerkleDistributor public immutable distributor;
    IERC20 public immutable rewardToken;
    address public rewardsSupplier;
    address public distributorAdmin;

    event RewardsSupplierUpdated(address newRewardsSupplier);

    error OnlyDistributorAdmin();
    event DistributorAdminUpdated(address newDistributorAdmin);

    error ForbiddenZeroAddress();
    error RewardTokenMismatch();

    event DistributionHalted();
    event EmergencyWithdrawal();

    modifier onlyDistributorAdmin() {
        if (msg.sender != distributorAdmin && msg.sender != owner()) revert OnlyDistributorAdmin();
        _;
    }

    constructor(
        address owner,
        ICumulativeMerkleDistributor _distributor,
        IERC20 _rewardToken
    ) {
        _transferOwnership(owner);
        rewardsSupplier = owner;
        distributorAdmin = owner;

        if (address(_distributor) == address(0)) revert ForbiddenZeroAddress();
        if (address(_rewardToken) != _distributor.TOKEN()) revert RewardTokenMismatch();

        distributor = _distributor;
        rewardToken = _rewardToken;
    }

    function updateMerkleRootAndTransferRewards(
        bytes32 merkleRoot,
        uint256 totalRewards,
        bool resetRoot
    ) external onlyDistributorAdmin {
        if (totalRewards > 0) rewardToken.transferFrom(rewardsSupplier, address(distributor), totalRewards);
        if (resetRoot) distributor.updateRoot(bytes32(0));
        distributor.updateRoot(merkleRoot);
    }

    function transferRewardsOnly(uint256 totalRewards) external onlyDistributorAdmin {
        rewardToken.transferFrom(rewardsSupplier, address(distributor), totalRewards);
    }

    // utility functions to collect non claimed rewards
    function withdrawTokensFromDistributor(uint256 amount) external onlyOwner {
        distributor.withdrawTokens(msg.sender, amount);
    }

    function withdrawNativeTokensFromDistributor(uint256 amount) external onlyOwner {
        distributor.withdrawNative(msg.sender, amount);
    }

    // utility functions to manage roles
    function setRewardsSupplier(address _newRewardsSupplier) external onlyOwner {
        rewardsSupplier = _newRewardsSupplier;
        emit RewardsSupplierUpdated(_newRewardsSupplier);
    }

    function setDistributorAdmin(address _newDistributorAdmin) external onlyOwner {
        distributorAdmin = _newDistributorAdmin;
        emit DistributorAdminUpdated(_newDistributorAdmin);
    }

    function transferDistributorOwnership(address newDistributorOwner) external onlyOwner {
        if (newDistributorOwner == address(0)) revert ForbiddenZeroAddress();
        distributor.transferOwnership(newDistributorOwner);
    }

    // functions for emergency usage only, the features are already possible by combining the rest of the functions
    function haltDistribution() external onlyOwner {
        distributor.updateRoot(bytes32(0));
        distributor.updateRoot(bytes32(0));
        rewardsSupplier = address(0);
        distributorAdmin = address(0);

        emit DistributionHalted();
    }

    function emergencyWithdraw() external onlyOwner {
        distributor.withdrawTokens(msg.sender, type(uint256).max);
        distributor.withdrawNative(msg.sender, type(uint256).max);

        emit EmergencyWithdrawal();
    }
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