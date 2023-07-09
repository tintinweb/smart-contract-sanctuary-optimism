// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;
pragma abicoder v2;

import "./external/openzeppelin/contracts/access/Ownable.sol";
import "./external/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IAirdrop.sol";

/// @title  Airdrop Token Distributor
/// @notice Holds tokens for users to claim.
/// @dev    Unlike a merkle distributor this contract uses storage to record claims rather than a
///         merkle root.
///         After construction do the following
///         1. transfer tokens to this contract
///         2. setRecipients - called as many times as required to set all the recipients
///         3. transferOwnership - the ownership of the contract should be transferred to a new owner (eg DAO) after all recipients have been set
contract Airdrop is Ownable, IAirdrop {
    IERC20 public immutable override airdropToken;
    mapping(address => uint256) public override balanceOf;
    mapping(address => uint) public claimed;

    /// @notice Total amount of tokens claimable by recipients of this contract
    uint256 public totalClaimable;

    /// @notice Total amount of tokens claimed by recipients of this contract
    uint256 public totalClaimed;

    /// @notice Block number at which claiming starts
    uint256 public immutable claimPeriodStart;
    /// @notice Block number at which claiming ends
    uint256 public immutable claimPeriodEnd;

    /// @notice Address to receive tokens that were not claimed after claimPeriodEnd
    address payable public sweepReceiver;

    modifier InClaimablePeriod() {
        require(claimPeriodStart <= block.timestamp, "claim not started");
        require(claimPeriodEnd >= block.timestamp, "claim already ended");

        _;
    }

    constructor(
        address _airdropToken,
        uint256 _claimPeriodStart,
        uint256 _claimPeriodEnd
    ) {
        airdropToken = IERC20(_airdropToken);
        claimPeriodStart = _claimPeriodStart;
        claimPeriodEnd = _claimPeriodEnd;
    }

    function setAirdropList(
        address[] calldata _userAddresses,
        uint256[] calldata _userBalance
    ) public onlyOwner {
        require(
            _userAddresses.length == _userBalance.length,
            "length is not equal"
        );
        uint256 sum = 0;
        for (uint i; i < _userAddresses.length; i++) {
            require(
                balanceOf[_userAddresses[i]] == 0,
                "already set airdrop balance"
            );
            balanceOf[_userAddresses[i]] = _userBalance[i];
            sum += _userBalance[i];

            emit AirdropClaimable(_userAddresses[i], _userBalance[i]);
        }

        totalClaimable += sum;

        require(
            airdropToken.balanceOf(address(this)) >= totalClaimable,
            "token not enough"
        );

        emit AirdropSet(_userAddresses.length, sum);
    }

    /// @notice Claim tokens
    function claim() public InClaimablePeriod {
        uint256 amount = balanceOf[msg.sender];

        require(amount > 0, "no airdrop");
        require(claimed[msg.sender] != 1, "claimed");

        totalClaimed += amount;
        claimed[msg.sender] = 1;

        require(airdropToken.transfer(msg.sender, amount), "claim failed");

        emit AirdropClaimed(msg.sender, amount);
    }

    /// @notice Allows owner to update address of sweep receiver
    function setSweepReciever(
        address payable _sweepReceiver
    ) external onlyOwner {
        _setSweepReciever(_sweepReceiver);
    }

    function _setSweepReciever(address payable _sweepReceiver) internal {
        require(_sweepReceiver != address(0), "zero sweep receiver address");
        sweepReceiver = _sweepReceiver;
        emit SweepReceiverSet(_sweepReceiver);
    }

    /// @notice Allows owner of the contract to withdraw tokens
    /// @dev A safety measure in case something goes wrong with the distribution
    function withdraw(uint256 amount) external onlyOwner {
        require(
            airdropToken.transfer(msg.sender, amount),
            "fail transfer token"
        );
        emit Withdrawal(msg.sender, amount);
    }

    /// @notice Sends any unclaimed funds to the sweep reciever once the claiming period is over
    function sweep() external {
        require(block.timestamp > claimPeriodEnd, "not ended");
        uint256 leftovers = airdropToken.balanceOf(address(this));
        require(leftovers != 0, "no leftovers");
        require(sweepReceiver != address(0), "zero sweep receiver address");

        require(
            airdropToken.transfer(sweepReceiver, leftovers),
            "fail token transfer"
        );

        emit Swept(leftovers);
    }
}

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

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
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

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

// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "../external/openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAirdrop {
    event AirdropSet(uint256 accountCount, uint256 totalAmount);

    event AirdropClaimable(address indexed user, uint256 amount);

    event AirdropClaimed(address indexed user, uint256 amount);

    /// @notice leftover tokens after claiming period have been swept
    event Swept(uint256 amount);
    /// @notice new address set to receive unclaimed tokens
    event SweepReceiverSet(address indexed newSweepReceiver);
    /// @notice Tokens withdrawn
    event Withdrawal(address indexed recipient, uint256 amount);

    function airdropToken() external view returns (IERC20);

    function balanceOf(address) external view returns (uint256);

    function claim() external;
}