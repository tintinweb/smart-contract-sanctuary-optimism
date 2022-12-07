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
pragma solidity 0.8.15;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract OPTokenClaim is Ownable {
    // EXP and OP token
    IERC20 public immutable EXP;
    IERC20 public immutable OP;

    // EthernautDAO treasury (multisig)
    address public immutable treasury;

    // constants
    uint256 public constant MAX_REWARD = 10000 ether;
    uint256 public constant MAX_EXP = 99 ether;

    struct Config {
        // start date of first epoch
        uint128 start;
        // duration of claims
        uint128 maxEpoch;
    }

    Config public config;

    mapping(uint256 => uint256) public totalEXPAtEpoch;

    mapping(uint256 => mapping(address => uint256)) public epochToSubscribedEXP;

    event ClaimExtended(uint256 indexed months);
    event Subscribed(address indexed account, uint256 epoch, uint256 amount);
    event OPClaimed(address indexed to, uint256 epoch, uint256 reward);

    constructor(address _EXP, address _OP, address _treasury) {
        EXP = IERC20(_EXP);
        OP = IERC20(_OP);

        // multisig address: 0x2431BFA47bB3d494Bd720FaC71960F27a54b6FE7
        treasury = _treasury;

        config = Config({
            start: 1669852800, // Thu Dec 01 2022 00:00:00 UTC
            maxEpoch: 6 // first claim duration runs for 6 months
        });

        // transfer ownership to multisig
        _transferOwnership(_treasury);
    }

    /* ========== ADMIN CONFIGURATION ========== */

    /// extend duration of claim period
    /// @param months number of months to extend claim period
    function extendClaim(uint256 months) external onlyOwner {
        unchecked {
            config.maxEpoch += uint128(months);
        }
        emit ClaimExtended(months);
    }

    /* ========== VIEWS ========== */

    /// @return epochNumber the current epoch number
    function currentEpoch() external view returns (uint256 epochNumber) {
        return _currentEpoch(config);
    }

    /// returns last epoch where claims are open
    function maxEpoch() external view returns (uint256) {
        return config.maxEpoch;
    }

    /// @return reward the amount of OP tokens to be claimed
    function calcReward(address account, uint256 epochNum) public view returns (uint256 reward) {
        unchecked {
            // calculate the total reward of given epoch
            uint256 totalReward = totalEXPAtEpoch[epochNum] * 5;

            // calculate individual reward
            uint256 subscribedEXP = epochToSubscribedEXP[epochNum][account];
            if (totalReward > MAX_REWARD) {
                reward = 5 * subscribedEXP * MAX_REWARD / totalReward;
            } else {
                reward = 5 * subscribedEXP;
            }
        }
    }

    /* ========== USER FUNCTIONS ========== */

    /// subscribe to reward distribution for current epoch
    function subscribe(address account) public {
        Config memory _config = config;

        // epoch 0 is the first
        uint256 epochNum = _currentEpoch(_config);
        require(epochNum < _config.maxEpoch, "claims ended");

        uint256 expBalance = EXP.balanceOf(account);
        require(expBalance > 0, "address has no exp");

        // cap at MAX_EXP = 99 EXP
        if (expBalance > MAX_EXP) {
            expBalance = MAX_EXP;
        }

        uint256 subscribedEXP = epochToSubscribedEXP[epochNum][account];
        if (subscribedEXP == expBalance) {
            emit Subscribed(account, epochNum, expBalance);
            return;
        }

        // update total EXP at epoch
        unchecked {
            totalEXPAtEpoch[epochNum] += expBalance - subscribedEXP;
        }

        // update subscribed EXP for this account
        epochToSubscribedEXP[epochNum][account] = expBalance;

        emit Subscribed(account, epochNum, expBalance);
    }

    /// claim subscribed OP reward
    function claimOP(address account) external {
        Config memory _config = config;

        // users claim reward for last epoch, so claims start at epoch 1
        uint256 epochNum = _currentEpoch(_config);
        require(epochNum > 0, "claims have not started yet");

        uint256 lastEpochNum;
        unchecked {
            lastEpochNum = epochNum - 1;
        }
        require(lastEpochNum < _config.maxEpoch, "claims ended");

        // check if subscribed and if already claimed
        require(epochToSubscribedEXP[lastEpochNum][account] > 0, "didn't subscribe or already claimed");

        uint256 OPReward = calcReward(account, lastEpochNum);

        // mark as claimed
        epochToSubscribedEXP[lastEpochNum][account] = 0;

        // subscribe for next epoch
        if (epochNum < _config.maxEpoch) {
            subscribe(account);
        }

        // transfer OP to account
        require(OP.transferFrom(treasury, account, OPReward), "Transfer failed");

        emit OPClaimed(account, lastEpochNum, OPReward);
    }

    /// @dev reverts if claims have not started yet
    function _currentEpoch(Config memory _config) internal view returns (uint256 epochNumber) {
        require(block.timestamp >= _config.start, "reward dist not started yet");
        unchecked {
            epochNumber = (block.timestamp - _config.start) / 30 days;
        }
    }
}