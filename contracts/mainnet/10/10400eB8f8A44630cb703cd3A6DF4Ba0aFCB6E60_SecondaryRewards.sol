// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import { Ownable } from "Ownable.sol";
import "BoringERC20.sol";
import "IERC20.sol";

interface IZipRewards {
    struct UserInfo {
        uint128 amount;
        int128 rewardDebt;
    }
    function userInfo(uint pid, address user) external view returns (UserInfo memory);
}

abstract contract SecondaryRewarder {
    function notify_onDeposit(uint pid, uint depositedAmount, uint finalBalance, address sender, address to) virtual external;
    //to may be a zapper contract
    function notify_onWithdrawal(uint pid, uint withdrawnAmount, uint remainingAmount, address user, address to) virtual external;
    function notify_onHarvest(uint pid, uint zipAmount, address user, address recipient) virtual external;
    //view functions for the gui
    function pendingTokens(address user) virtual external view returns (IERC20[] memory, uint256[] memory);
    function rewardRates() virtual external view returns (IERC20[] memory, uint256[] memory);
}

// note: withdrawals can't be paused
contract SecondaryRewards is SecondaryRewarder, Ownable  {
    using BoringERC20 for IERC20;

    /// @notice Info of each user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of zipToken entitled to the user.
    struct UserInfo {
        uint128 amount;
        int128 rewardDebt;
    }

    /// @notice Address of zipToken contract.
    IERC20 public immutable zipToken;
    /// @notice Address of the master farm contract.
    IZipRewards public immutable zipRewards;

    uint public accZipPerShare;
    uint public lastRewardTime;
    uint public zipPerSecond;
    //total sum of all current deposits
    uint public lpSupply;
    //only needed for forceSyncDeposits
    uint public masterFarmPid;

    /// @notice Info of each user that stakes LP tokens.
    mapping (address => UserInfo) public userInfo;

    //note: maximum theoretically possible balance of Uni2 LP is 2**112-1
    //accZipPerShare is 256 bit. therefore, the maximum supported reward balance is ~10^25 units (*18 decimals)
    uint private constant ACC_ZIP_PRECISION = 2**112-1;

    event SecondaryDeposit(address indexed user, uint256 amount, address indexed to);
    event SecondaryWithdraw(address indexed user, uint256 amount);
    event SecondaryHarvest(address indexed user, address recipient, uint256 amount);
    event SecondaryLogZipPerSecond(uint256 zipPerSecond);
    event SecondaryLogUpdatePool(uint256 lastRewardTime, uint256 lpSupply, uint256 accZipPerShare);

    modifier onlyFromZipRewards() {
        require(msg.sender == address(zipRewards), "must be called by ZipRewards");
        _;
    }

    /// @param _rewardToken The rewardToken token contract address.
    constructor(IERC20 _rewardToken, IZipRewards _zipRewards) {
        zipToken = _rewardToken;
        assert(ACC_ZIP_PRECISION != 0);
        lastRewardTime = block.timestamp;
        zipRewards = _zipRewards;
        masterFarmPid = type(uint).max;
    }

    // GUI VIEW FUNCTIONS START
    function pendingTokens(address user) external view override returns (IERC20[] memory rewardTokens, uint256[] memory rewardAmounts) {
        IERC20[] memory _rewardTokens = new IERC20[](1);
        _rewardTokens[0] = (zipToken);
        uint256[] memory _rewardAmounts = new uint256[](1);
        _rewardAmounts[0] = pendingReward(user);
        return (_rewardTokens, _rewardAmounts);
    }
    
    function rewardRates() external view override returns (IERC20[] memory, uint256[] memory) {
        IERC20[] memory _rewardTokens = new IERC20[](1);
        _rewardTokens[0] = (zipToken);
        uint256[] memory _rewardRates = new uint256[](1);
        _rewardRates[0] = zipPerSecond;
        return (_rewardTokens, _rewardRates);
    }

    /// @notice View function to see pending zipToken on frontend.
    /// @param _user Address of user.
    /// @return pending zipToken reward for a given user.
    function pendingReward(address _user) internal view returns (uint pending) {
        UserInfo storage user = userInfo[_user];
        uint _accZipPerShare = accZipPerShare;

        if (lpSupply > 0) {
            uint time;
            if(block.timestamp > zipRewardsSpentTime) {
                if(lastRewardTime < zipRewardsSpentTime) {
                    time = zipRewardsSpentTime - lastRewardTime;
                }
                else {
                    time = 0;
                }
            }
            else {
                    time = block.timestamp - lastRewardTime;
            }
            uint tokenReward = time*zipPerSecond;
            _accZipPerShare += tokenReward*ACC_ZIP_PRECISION / lpSupply;
        }
        pending = uint(int(uint(user.amount)*_accZipPerShare/ACC_ZIP_PRECISION) - user.rewardDebt);
    }

    // GUI VIEW FUNCTIONS END

    function notify_onDeposit(uint pid, uint depositedAmount, uint _finalBalance, address sender, address to) external override onlyFromZipRewards {
        require(depositedAmount == uint(uint128(depositedAmount)));
        deposit(sender, uint128(depositedAmount), to);
    }

    function notify_onWithdrawal(uint pid, uint withdrawnAmount, uint remainingAmount, address user, address to) external override onlyFromZipRewards {
        require(withdrawnAmount == uint(uint128(withdrawnAmount)));
        withdraw(user, uint128(withdrawnAmount));
    }

    function notify_onHarvest(uint pid, uint zipAmount, address user, address recipient) external override onlyFromZipRewards {
        harvest(user, recipient);
    }

    /*
      in case some deposits happen before rewarder is set on the master farm contract
      or rewarder is removed on the main contract and then reenabled
    */
    function forceSyncDeposit(address who) external {
        require(masterFarmPid < type(uint).max);
        uint128 externalAmount = zipRewards.userInfo(masterFarmPid, who).amount;
        UserInfo storage user = userInfo[who];
        uint128 localAmount = user.amount;
        require(externalAmount != localAmount, 'balance correct');
        if(localAmount < externalAmount) {
            deposit(who, externalAmount-localAmount, who);
        }
        else {
            withdraw(who, localAmount-externalAmount);
        }
    }

    /// @notice Update reward variables of the pool.
    function updatePool() public {
        if (block.timestamp > lastRewardTime) {
            if (lpSupply > 0) {
                uint time;
                if(block.timestamp > zipRewardsSpentTime) {
                    if(lastRewardTime < zipRewardsSpentTime) {
                        time = zipRewardsSpentTime - lastRewardTime;
                    }
                    else {
                        time = 0;
                    }
                }
                else {
                    time = block.timestamp - lastRewardTime;
                }
                uint tokenReward = time*zipPerSecond;
                accZipPerShare += tokenReward*ACC_ZIP_PRECISION / lpSupply;
            }
            lastRewardTime = block.timestamp;
            emit SecondaryLogUpdatePool(lastRewardTime, lpSupply, accZipPerShare);
        }
    }

    /// @notice Deposit LP tokens for zipToken allocation.
    /// @param amount LP token amount to deposit.
    /// @param to The receiver of `amount` deposit benefit.
    function deposit(address who, uint128 amount, address to) internal {
        updatePool();
        UserInfo storage user = userInfo[to];

        user.amount += amount;
        lpSupply += amount;
        uint rewardDebtChange = uint(amount)*accZipPerShare / ACC_ZIP_PRECISION;
        user.rewardDebt += int128(uint128(rewardDebtChange));
        emit SecondaryDeposit(who, amount, to);
    }

    /// @notice Withdraw LP tokens.
    /// @param amount LP token amount to withdraw.
    function withdraw(address who, uint128 amount) internal {
        (UserInfo storage user, uint accumulatedZip, uint pendingZip) = getUserDataUpdatePool(who);

        user.rewardDebt -= int128(uint128(uint(amount)*accZipPerShare / ACC_ZIP_PRECISION));
        user.amount -= amount;
        lpSupply -= amount;

        emit SecondaryWithdraw(who, amount);
    }

    function harvest(address who, address to) internal {
        (UserInfo storage user, uint accumulatedZip, uint pendingZip) = getUserDataUpdatePool(who);
        user.rewardDebt = int128(uint128(accumulatedZip));
        if(pendingZip != 0) {
            totalPaidRewards += pendingZip;
            zipToken.safeTransfer(to, pendingZip);
        }

        emit SecondaryHarvest(who, to, pendingZip);
    }

    function getUserDataUpdatePool(address who) internal returns (UserInfo storage user, uint accumulatedZip, uint pendingZip) {
        updatePool();
        user = userInfo[who];
        accumulatedZip = uint(user.amount)*accZipPerShare / ACC_ZIP_PRECISION;
        pendingZip = uint(int(accumulatedZip)-int(user.rewardDebt));
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////////
    // OWNER FUNCTIONS                                                                                  //
    //////////////////////////////////////////////////////////////////////////////////////////////////////
    // note: owner can't transfer users' deposits or block withdrawals

    uint public totalPaidRewards;
    //timestamp when zip rewards run out given current balance
    uint64 public zipRewardsSpentTime;
    uint64 public totalAccumulatedRewardsLastSetTimestamp;
    uint public totalAccumulatedZipRewards;
    
    /// @notice Sets the zipToken per second to be distributed. Can only be called by the owner.
    /// @param newZipPerSecond The amount of zipToken to be distributed per second.
    /// uint128 because that makes overflow while multiplying zipPerSecond (as uint256) impossible.
    function setRewardTokenPerSecond(uint128 newZipPerSecond) external onlyOwner {
        updatePool();
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
        zipRewardsSpentTime = uint64(block.timestamp+secondsRewardsCanLast);
        zipPerSecond = uint(newZipPerSecond);
        totalAccumulatedRewardsLastSetTimestamp = uint64(block.timestamp);

        lastRewardTime = block.timestamp;
        emit SecondaryLogZipPerSecond(newZipPerSecond);
    }

    function ownerWithdrawToken(IERC20 _token, address recipient, uint amount) external onlyOwner returns (uint) {
        if(amount == 0) {
            amount = _token.balanceOf(address(this));
        }
        BoringERC20.safeTransfer(_token, recipient, amount);
        return amount;
    }

    function ownerSetMasterFarmPid(uint _masterFarmPid) external onlyOwner {
        masterFarmPid = _masterFarmPid;
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