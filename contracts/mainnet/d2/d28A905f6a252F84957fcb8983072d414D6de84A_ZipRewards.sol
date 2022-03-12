// SPDX-License-Identifier: MIT
// based on MiniChefV2 from Sushiswap, fixed some bugs and added possibility of zapping out

pragma solidity ^0.8.11;

import { Ownable } from "Ownable.sol";
import { BoringBatchableWithPermit } from "BoringBatchable.sol";
import "Math.sol";
import "Pausable.sol";
import "BoringERC20.sol";
import "IERC20.sol";

interface IRewarder {
    function notify_onDeposit(uint pid, uint depositedAmount, uint finalBalance, address sender, address to) external;
    //to may be a zapper contract
    function notify_onWithdrawal(uint pid, uint withdrawnAmount, uint remainingAmount, address user, address to) external;
    function notify_onHarvest(uint pid, uint zipAmount, address user, address recipient) external;
    function pendingTokens(uint256 pid, address user, uint256 rewardAmount) external view returns (IERC20[] memory, uint256[] memory);
}

interface IWithdrawalNotifiable {
    function notify_onWithdrawal(uint amount, bytes calldata data) external;
}

interface IDepositNotifiable {
    function notify_onDeposit(uint amount, bytes calldata data) external;
}

// note: withdrawals can't be paused
contract BaseZipRewards is Ownable, BoringBatchableWithPermit, Pausable  {
    using BoringERC20 for IERC20;

    /// @notice Info of each user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of zipToken entitled to the user.
    struct UserInfo {
        uint128 amount;
        int128 rewardDebt;
    }

    /// @notice Info of each pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of zipToken to distribute per block.
    struct PoolInfo {
        uint accZipPerShare;
        uint40 lastRewardTime;
        uint216 allocPoint;
    }

    /// @notice Address of zipToken contract.
    IERC20 public immutable zipToken;

    /// @notice Info of each pool.
    PoolInfo[] public poolInfo;
    /// @notice Address of the LP token for each pool.
    IERC20[] public lpToken;
    /// @notice Address of each `IRewarder` contract.
    IRewarder[] public rewarder;

    /// @notice Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    /// @dev Tokens added
    mapping (address => bool) public addedTokens;

    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint public totalAllocPoint;

    uint public zipPerSecond;
    //note: maximum theoretically possible balance of Uni2 LP is 2**112-1
    //accZipPerShare is 256 bit. therefore, the maximum supported reward balance is ~10^25 units (*18 decimals)
    uint private constant ACC_ZIP_PRECISION = 2**112-1;
    uint public totalPaidRewards;
    //timestamp when zip rewards run out given current balance
    uint64 public zipRewardsSpentTime;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event LogPoolAddition(uint256 indexed pid, uint256 allocPoint, IERC20 indexed lpToken, IRewarder indexed rewarder);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint, IRewarder indexed rewarder, bool overwrite);
    event LogUpdatePool(uint256 indexed pid, uint64 lastRewardTime, uint256 lpSupply, uint256 accZipPerShare);
    event LogZipPerSecond(uint256 zipPerSecond);

    /// @param _zipToken The zipToken token contract address.
    constructor(IERC20 _zipToken) {
        zipToken = _zipToken;
        assert(ACC_ZIP_PRECISION != 0);
    }

    /// @notice Returns the number of pools.
    function poolLength() public view returns (uint256 pools) {
        pools = poolInfo.length;
    }

    /// @notice View function to see pending zipToken on frontend.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending zipToken reward for a given user.
    function pendingReward(uint _pid, address _user) external view returns (uint pending) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint accZipPerShare = pool.accZipPerShare;
        uint lpSupply = lpToken[_pid].balanceOf(address(this));

        if (lpSupply > 0 && totalAllocPoint > 0) {
            uint time;
            if(block.timestamp > zipRewardsSpentTime) {
                if(pool.lastRewardTime < zipRewardsSpentTime) {
                    time = zipRewardsSpentTime - pool.lastRewardTime;
                }
                else {
                    time = 0;
                }
            }
            else {
                    time = block.timestamp - pool.lastRewardTime;
            }
            uint tokenReward = time*zipPerSecond*pool.allocPoint/totalAllocPoint;
            accZipPerShare += tokenReward*ACC_ZIP_PRECISION / lpSupply;
        }
        pending = uint(int(uint(user.amount)*accZipPerShare/ACC_ZIP_PRECISION) - user.rewardDebt);
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if (block.timestamp > pool.lastRewardTime) {
            uint lpSupply = lpToken[pid].balanceOf(address(this));
            if (lpSupply > 0 && totalAllocPoint > 0) {
                uint time;
                if(block.timestamp > zipRewardsSpentTime) {
                    if(pool.lastRewardTime < zipRewardsSpentTime) {
                        time = zipRewardsSpentTime - pool.lastRewardTime;
                    }
                    else {
                        time = 0;
                    }
                }
                else {
                    time = block.timestamp - pool.lastRewardTime;
                }
                uint tokenReward = time*zipPerSecond*pool.allocPoint/totalAllocPoint;
                pool.accZipPerShare += tokenReward*ACC_ZIP_PRECISION / lpSupply;
            }
            pool.lastRewardTime = uint40(block.timestamp);
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardTime, lpSupply, pool.accZipPerShare);
        }
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    /// @param pids Pool IDs of all to be updated. Make sure to update all active pools.
    function massUpdatePools(uint[] calldata pids) external {
        uint len = pids.length;
        for (uint i = 0; i < len; ++i) {
            PoolInfo memory pool = updatePool(pids[i]);
        }
    }

    /// @notice Deposit LP tokens for zipToken allocation.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to deposit.
    /// @param to The receiver of `amount` deposit benefit.
    function deposit(uint pid, uint128 amount, address to) public whenNotPaused {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][to];

        user.amount += amount;
        uint rewardDebtChange = uint(amount)*pool.accZipPerShare / ACC_ZIP_PRECISION;
        user.rewardDebt += int128(uint128(rewardDebtChange));

        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.notify_onDeposit(pid, amount, user.amount, msg.sender, to);
        }

        lpToken[pid].safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, pid, amount, to);
    }

    /// @notice Withdraw LP tokens.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens.
    /// @param ignoreNotifyThrow if error in secondary rewarder should be ignored
    function withdrawLong(uint pid, uint128 amount, address to, bool ignoreNotifyThrow) public {
        (PoolInfo memory pool, UserInfo storage user, uint accumulatedZip, uint pendingZip) = getUserDataUpdatePool(pid, msg.sender);

        user.rewardDebt -= int128(uint128(uint(amount)*pool.accZipPerShare / ACC_ZIP_PRECISION));
        user.amount -= amount;
        
        
        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            try _rewarder.notify_onWithdrawal(pid, amount, user.amount, msg.sender, to) {}
            catch (bytes memory reason) {
                if(!ignoreNotifyThrow) {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }

        lpToken[pid].safeTransfer(to, amount);

        emit Withdraw(msg.sender, pid, amount, to);
    }

    function harvestLong(uint pid, address to, bool ignoreNotifyThrow) public whenNotPaused returns (uint) {
        (PoolInfo memory pool, UserInfo storage user, uint accumulatedZip, uint pendingZip) = getUserDataUpdatePool(pid, msg.sender);

        user.rewardDebt = int128(uint128(accumulatedZip));
        transferReward(pid, to, pendingZip, ignoreNotifyThrow);

        emit Harvest(msg.sender, pid, pendingZip);
        return pendingZip;
    }

    /// @notice Withdraw LP tokens and harvest proceeds for transaction sender.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param stakedTo Receiver of the LP tokens
    /// @param rewardsTo Receiver of the zipToken rewards.
    function withdrawAndHarvestLong(uint pid, uint128 amount, address stakedTo, address rewardsTo) public whenNotPaused returns (uint) {
        (PoolInfo memory pool, UserInfo storage user, uint accumulatedZip, uint pendingZip) = getUserDataUpdatePool(pid, msg.sender);

        user.rewardDebt = int128(int(accumulatedZip)-int(uint(amount)*pool.accZipPerShare / ACC_ZIP_PRECISION));
        user.amount -= amount;

        transferReward(pid, rewardsTo, pendingZip, false);

        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.notify_onWithdrawal(pid, amount, user.amount, msg.sender, stakedTo);
        }

        lpToken[pid].safeTransfer(stakedTo, amount);

        emit Withdraw(msg.sender, pid, amount, stakedTo);
        emit Harvest(msg.sender, pid, pendingZip);
        return pendingZip;
    }

    function transferReward(uint pid, address rewardsTo, uint rewardAmount, bool ignoreNotifyThrow) internal {
        if(rewardAmount != 0) {
            totalPaidRewards += rewardAmount;
            zipToken.safeTransfer(rewardsTo, rewardAmount);
        }

        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            try _rewarder.notify_onHarvest(pid, rewardAmount, msg.sender, rewardsTo) {}
            catch (bytes memory reason) {
                if(!ignoreNotifyThrow) {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    function getUserDataUpdatePool(uint pid, address who) internal returns (PoolInfo memory pool, UserInfo storage user, uint accumulatedZip, uint pendingZip) {
        pool = updatePool(pid);
        user = userInfo[pid][who];
        accumulatedZip = uint(user.amount)*pool.accZipPerShare / ACC_ZIP_PRECISION;
        pendingZip = uint(int(accumulatedZip)-int(user.rewardDebt));
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of the LP tokens.
    function emergencyWithdraw(uint pid, address to) external returns (uint amount) {
        UserInfo storage user = userInfo[pid][msg.sender];
        amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            try _rewarder.notify_onWithdrawal(pid, amount, 0, msg.sender, to) {}
            catch {}
        }

        // Note: transfer can fail or succeed if `amount` is zero.
        lpToken[pid].safeTransfer(to, amount);
        emit EmergencyWithdraw(msg.sender, pid, amount, to);
    }
}

contract BaseZipRewardsWithOwnerFunctions is BaseZipRewards {
    constructor(IERC20 _zipToken) BaseZipRewards(_zipToken) {}

    //////////////////////////////////////////////////////////////////////////////////////////////////////
    // OWNER FUNCTIONS                                                                                  //
    //////////////////////////////////////////////////////////////////////////////////////////////////////
    // note: owner can't transfer users' deposits or block withdrawals

    //before calling set, add, setZipPerSecond all non-zero alloc pools MUST be updated in the same second

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// @param allocPoint AP of the new pool.
    /// @param _lpToken Address of the LP ERC-20 token.
    /// @param _rewarder Address of the rewarder delegate.
    function add(uint allocPoint, IERC20 _lpToken, IRewarder _rewarder) external onlyOwner {
        require(addedTokens[address(_lpToken)] == false, "Token already added");
        totalAllocPoint += allocPoint;
        lpToken.push(_lpToken);
        rewarder.push(_rewarder);

        poolInfo.push(PoolInfo({
            allocPoint: uint216(allocPoint),
            lastRewardTime: uint40(block.timestamp),
            accZipPerShare: 0
        }));
        addedTokens[address(_lpToken)] = true;
        emit LogPoolAddition(lpToken.length-1, allocPoint, _lpToken, _rewarder);
    }

    /// @notice Update the given pool's zipToken allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    /// @param _rewarder Address of the rewarder delegate.
    /// @param overwrite True if _rewarder should be `set`. Otherwise `_rewarder` is ignored.
    function set(uint _pid, uint _allocPoint, IRewarder _rewarder, bool overwrite) external onlyOwner {
        totalAllocPoint = totalAllocPoint-poolInfo[_pid].allocPoint+_allocPoint;
        poolInfo[_pid].allocPoint = uint216(_allocPoint);
        if (overwrite) { rewarder[_pid] = _rewarder; }
        emit LogSetPool(_pid, _allocPoint, overwrite ? _rewarder : rewarder[_pid], overwrite);
    }

    uint64 public totalAccumulatedRewardsLastSetTimestamp;
    uint public totalAccumulatedZipRewards;
    
    /// @notice Sets the zipToken per second to be distributed. Can only be called by the owner.
    /// @param newZipPerSecond The amount of zipToken to be distributed per second.
    function setZipPerSecond(uint newZipPerSecond) external onlyOwner {
        if(block.timestamp <= zipRewardsSpentTime) {
            //contract didn't run out of rewards
            totalAccumulatedZipRewards += zipPerSecond*(block.timestamp-uint(totalAccumulatedRewardsLastSetTimestamp));
        }
        else {
            //contract has run out of rewards
            if(totalAccumulatedRewardsLastSetTimestamp < zipRewardsSpentTime) {
                totalAccumulatedZipRewards += zipPerSecond*uint(zipRewardsSpentTime-totalAccumulatedRewardsLastSetTimestamp);
            }
        }
        uint unclaimedZip = totalAccumulatedZipRewards-totalPaidRewards;
        uint zipForNewRewards = zipToken.balanceOf(address(this))-unclaimedZip;
        uint secondsRewardsCanLast = zipForNewRewards/newZipPerSecond;
        zipRewardsSpentTime = uint64(block.timestamp+zipForNewRewards/newZipPerSecond);
        zipPerSecond = newZipPerSecond;
        totalAccumulatedRewardsLastSetTimestamp = uint64(block.timestamp);
        emit LogZipPerSecond(newZipPerSecond);
    }

    /*
    failsafe functions can be used to fix an incorrect state that may arise from calling set/add/setZipPerSecond by the owner
    without calling updatePool() on pools with non-zero alloc first.
    Unfortunately, gas limit considerations make it impossible to enforce directly.
    */

    function failsafe_setRewardParams
    (uint newZipPerSecond, bool setNewZipPerSecond,
    uint64 newZipRewardsSpentTime, bool setZipRewardsSpentTime,
    uint64 newTotalAccumulatedRewardsLastSetTimestamp, bool setTotalAccumulatedRewardsLastSetTimestamp,
    uint newTotalAccumulatedZipRewards, bool setTotalAccumulatedZipRewards,
    uint newTotalPaidRewards, bool setNewTotalPaidRewards,
    uint newTotalAllocPoint, bool setTotalAllocPoint)
    external onlyOwner {
        if(setNewZipPerSecond) {
            zipPerSecond = newZipPerSecond;
        }
        if(setZipRewardsSpentTime) {
            zipRewardsSpentTime = newZipRewardsSpentTime;
        }
        if(setTotalAccumulatedRewardsLastSetTimestamp) {
            totalAccumulatedRewardsLastSetTimestamp = newTotalAccumulatedRewardsLastSetTimestamp;
        }
        if(setTotalAccumulatedZipRewards) {
            totalAccumulatedZipRewards = newTotalAccumulatedZipRewards;
        }
        if(setNewTotalPaidRewards) {
            totalPaidRewards = newTotalPaidRewards;
        }
        if(setTotalAllocPoint) {
            totalAllocPoint = newTotalAllocPoint;
        }
    }

    function failsafe_setPoolParams(uint pid, PoolInfo calldata newPoolInfo) external onlyOwner {
        poolInfo[pid] = newPoolInfo;
    }

    function failsafe_setUserRewardDebt(uint pid, address who, int128 rewardDebt) external onlyOwner {
        UserInfo storage user = userInfo[pid][who];
        user.rewardDebt = rewardDebt;
    }

    function ownerWithdrawRewardToken(address recipient, uint amount) external onlyOwner returns (uint) {
        if(amount == 0) {
            amount = zipToken.balanceOf(address(this));
        }
        require(zipToken.transfer(recipient, amount));
        return amount;
    }

    function ownerPauseDepositsAndHarvests() external onlyOwner {
        _pause();
    }

    function ownerUnpauseDepositsAndHarvests() external onlyOwner {
        _unpause();
    }
}

contract ZipRewards is BaseZipRewardsWithOwnerFunctions {
    constructor(IERC20 _zipToken) BaseZipRewardsWithOwnerFunctions(_zipToken) {}

    function depositNotify(uint pid, uint128 amount, address to, IDepositNotifiable notifyAddress, bytes calldata data) external {
        deposit(pid, amount, to);
        notifyAddress.notify_onDeposit(amount, data);
    }

    function depositShort(uint pid, uint128 amount) external {
        deposit(pid, amount, msg.sender);
    }

    function depositWithPermit(uint pid, uint128 amount, address to, uint deadline, uint8 v, bytes32 r, bytes32 s) public {
        lpToken[pid].permit(msg.sender, address(this), amount, deadline, v, r, s);
        deposit(pid, amount, to);
    }

    function depositWithPermitShort(uint pid, uint128 amount, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        depositWithPermit(pid, amount, msg.sender, deadline, v, r, s);
    }

    //can be used to zap out of LP tokens with a helper contract
    function withdrawNotify(uint pid, uint128 amount, address to, bytes calldata data) external {
        withdrawLong(pid, amount, to, false);
        IWithdrawalNotifiable(to).notify_onWithdrawal(amount, data);
    }

    function withdraw(uint pid, uint128 amount, address to) external {
        withdrawLong(pid, amount, to, false);
    }

    function withdrawShort(uint pid, uint128 amount) external {
        withdrawLong(pid, amount, msg.sender, false);
    }

    function withdrawAll(uint pid) external {
        UserInfo storage user = userInfo[pid][msg.sender];
        withdrawLong(pid, user.amount, msg.sender, false);
    }

    /// @notice Harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of zipToken rewards.
    function harvest(uint pid, address to) external returns (uint) {
        return harvestLong(pid, to, false);
    }

    function harvestShort(uint pid) external returns (uint) {
        return harvestLong(pid, msg.sender, false);
    }

    function withdrawAndHarvestShort(uint pid, uint128 amount) external returns (uint) {
        return withdrawAndHarvestLong(pid, amount, msg.sender, msg.sender);
    }

    function withdrawAllAndHarvest(uint pid) external returns (uint) {
        UserInfo storage user = userInfo[pid][msg.sender];
        return withdrawAndHarvestLong(pid, user.amount, msg.sender, msg.sender);
    }

    //can be used to zap out of LP tokens with a helper contract
    function withdrawAndHarvestNotifyLong(uint pid, uint128 amount, address stakedTo, address rewardsTo, bytes calldata data) external returns (uint rewardAmount) {
        rewardAmount = withdrawAndHarvestLong(pid, amount, stakedTo, rewardsTo);
        IWithdrawalNotifiable(stakedTo).notify_onWithdrawal(amount, data);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

abstract contract Ownable {
    address private _owner;
    address private newOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(msg.sender);
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
        require(owner() == msg.sender, "Ownable: caller is not the owner");
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
    function transferOwnership(address _newOwner) public virtual onlyOwner {
        require(_newOwner != address(0), "Ownable: new owner is the zero address");
        newOwner = _newOwner;
    }

    function acceptOwnership() public virtual {
        require(msg.sender == newOwner, "Ownable: sender != newOwner");
        _transferOwnership(msg.sender);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address _newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = _newOwner;
        emit OwnershipTransferred(oldOwner, _newOwner);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "IERC20.sol";

//from BoringSolidity - original forced solidity version 0.6.12

contract BoringBatchable {
    /// @dev Helper function to extract a useful revert message from a failed call.
    /// If the returned data is malformed or not correctly abi encoded then this call can fail itself.
    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    /// @notice Allows batched call to self (this contract).
    /// @param calls An array of inputs for each call.
    /// @param revertOnFail If True then reverts after a failed call and stops doing further calls.
    // F1: External is ok here because this is the batch function, adding it to a batch makes no sense
    // F2: Calls in the batch may be payable, delegatecall operates in the same context, so each call in the batch has access to msg.value
    // C3: The length of the loop is fully under user control, so can't be exploited
    // C7: Delegatecall is only used on the same contract, so it's safe
    function batch(bytes[] calldata calls, bool revertOnFail) external payable {
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            if (!success && revertOnFail) {
                revert(_getRevertMsg(result));
            }
        }
    }

    function batchRevertOnFailure(bytes[] calldata calls) external payable {
        //copy-pasted to save on copying arguments from calldata to memory (in a public function)
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            if (!success) {
                revert(_getRevertMsg(result));
            }
        }
    }
}

contract BoringBatchableWithPermit is BoringBatchable {
    /// @notice Call wrapper that performs `ERC20.permit` on `token`.
    /// Lookup `IERC20.permit`.
    // F6: Parameters can be used front-run the permit and the user's permit will fail (due to nonce or other revert)
    //     if part of a batch this could be used to grief once as the second call would not need the permit
    function batchPermitToken(
        IERC20 token,
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        token.permit(from, to, amount, deadline, v, r, s);
    }
}

pragma solidity >=0.5.0;

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a / b + (a % b == 0 ? 0 : 1);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
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
pragma solidity ^0.8.11;
import "IERC20.sol";

// solhint-disable avoid-low-level-calls

library BoringERC20 {
    bytes4 private constant SIG_SYMBOL = 0x95d89b41; // symbol()
    bytes4 private constant SIG_NAME = 0x06fdde03; // name()
    bytes4 private constant SIG_DECIMALS = 0x313ce567; // decimals()
    bytes4 private constant SIG_BALANCE_OF = 0x70a08231; // balanceOf(address)
    bytes4 private constant SIG_TRANSFER = 0xa9059cbb; // transfer(address,uint256)
    bytes4 private constant SIG_TRANSFER_FROM = 0x23b872dd; // transferFrom(address,address,uint256)

    function returnDataToString(bytes memory data) internal pure returns (string memory) {
        unchecked {
            if (data.length >= 64) {
                return abi.decode(data, (string));
            } else if (data.length == 32) {
                uint8 i = 0;
                while (i < 32 && data[i] != 0) {
                    i++;
                }
                bytes memory bytesArray = new bytes(i);
                for (i = 0; i < 32 && data[i] != 0; i++) {
                    bytesArray[i] = data[i];
                }
                return string(bytesArray);
            } else {
                return "???";
            }
        }
    }

    /// @notice Provides a safe ERC20.symbol version which returns '???' as fallback string.
    /// @param token The address of the ERC-20 token contract.
    /// @return (string) Token symbol.
    function safeSymbol(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_SYMBOL));
        return success ? returnDataToString(data) : "???";
    }

    /// @notice Provides a safe ERC20.name version which returns '???' as fallback string.
    /// @param token The address of the ERC-20 token contract.
    /// @return (string) Token name.
    function safeName(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_NAME));
        return success ? returnDataToString(data) : "???";
    }

    /// @notice Provides a safe ERC20.decimals version which returns '18' as fallback value.
    /// @param token The address of the ERC-20 token contract.
    /// @return (uint8) Token decimals.
    function safeDecimals(IERC20 token) internal view returns (uint8) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_DECIMALS));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    /// @notice Provides a gas-optimized balance check to avoid a redundant extcodesize check in addition to the returndatasize check.
    /// @param token The address of the ERC-20 token.
    /// @param to The address of the user to check.
    /// @return amount The token amount.
    function safeBalanceOf(IERC20 token, address to) internal view returns (uint256 amount) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_BALANCE_OF, to));
        require(success && data.length >= 32, "BoringERC20: BalanceOf failed");
        amount = abi.decode(data, (uint256));
    }

    /// @notice Provides a safe ERC20.transfer version for different ERC-20 implementations.
    /// Reverts on a failed transfer.
    /// @param token The address of the ERC-20 token.
    /// @param to Transfer tokens to.
    /// @param amount The token amount.
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(SIG_TRANSFER, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: Transfer failed");
    }

    /// @notice Provides a safe ERC20.transferFrom version for different ERC-20 implementations.
    /// Reverts on a failed transfer.
    /// @param token The address of the ERC-20 token.
    /// @param from Transfer tokens from.
    /// @param to Transfer tokens to.
    /// @param amount The token amount.
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(SIG_TRANSFER_FROM, from, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: TransferFrom failed");
    }
}