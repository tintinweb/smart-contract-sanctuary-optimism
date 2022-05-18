// SPDX-License-Identifier: MIT

pragma solidity ^0.5.16;

import "openzeppelin-solidity-2.3.0/contracts/token/ERC20/SafeERC20.sol";
import "openzeppelin-solidity-2.3.0/contracts/math/SafeMath.sol";

import "../utils/proxy/ProxyReentrancyGuard.sol";
import "../utils/proxy/ProxyOwned.sol";
import "../utils/proxy/ProxyPausable.sol";
import "@openzeppelin/upgrades-core/contracts/Initializable.sol";

import "../interfaces/IEscrowThales.sol";
import "../interfaces/IStakingThales.sol";
import "../interfaces/ISNXRewards.sol";
import "../interfaces/IThalesRoyale.sol";
import "../interfaces/IPriceFeed.sol";
import "../interfaces/IThalesStakingRewardsPool.sol";
import "../interfaces/IAddressResolver.sol";

contract StakingThales is IStakingThales, Initializable, ProxyOwned, ProxyReentrancyGuard, ProxyPausable {
    /* ========== LIBRARIES ========== */

    using SafeMath for uint;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IEscrowThales public iEscrowThales;
    IERC20 public stakingToken;
    IERC20 public feeToken;
    ISNXRewards public SNXRewards;
    IThalesRoyale public thalesRoyale;
    IPriceFeed public priceFeed;

    uint public periodsOfStaking;
    uint public lastPeriodTimeStamp;
    uint public durationPeriod;
    uint public unstakeDurationPeriod;
    uint public startTimeStamp;
    uint public currentPeriodRewards;
    uint public currentPeriodFees;
    bool public distributeFeesEnabled;
    uint public fixedPeriodReward;
    uint public periodExtraReward;
    uint public totalSNXRewardsInPeriod;
    uint public totalSNXFeesInPeriod;
    bool public claimEnabled;

    mapping(address => uint) public stakerLifetimeRewardsClaimed;
    mapping(address => uint) public stakerFeesClaimed;

    uint private _totalStakedAmount;
    uint private _totalEscrowedAmount;
    uint private _totalPendingStakeAmount;
    uint private _totalUnclaimedRewards;
    uint private _totalRewardsClaimed;
    uint private _totalRewardFeesClaimed;

    mapping(address => uint) public lastUnstakeTime;
    mapping(address => bool) public unstaking;
    mapping(address => uint) public unstakingAmount;
    mapping(address => uint) private _stakedBalances;
    mapping(address => uint) private _lastRewardsClaimedPeriod;
    address public thalesAMM;

    uint constant HUNDRED = 1e18;
    uint constant AMM_EXTRA_REWARD_PERIODS = 4;

    struct AMMVolumeEntry {
        uint amount;
        uint period;
    }
    mapping(address => uint) private lastAMMUpdatePeriod;
    mapping(address => AMMVolumeEntry[AMM_EXTRA_REWARD_PERIODS]) private stakerAMMVolume;

    bool public extraRewardsActive;
    IThalesStakingRewardsPool public ThalesStakingRewardsPool;

    uint public maxSNXRewardsPercentage;
    uint public maxAMMVolumeRewardsPercentage;
    uint public AMMVolumeRewardsMultiplier;
    uint public maxThalesRoyaleRewardsPercentage;

    uint constant ONE = 1e18;
    uint constant ONE_PERCENT = 1e16;

    uint public SNXVolumeRewardsMultiplier;

    mapping(address => uint) private _lastStakingPeriod;

    uint public totalStakedLastPeriodEnd;
    uint public totalEscrowedLastPeriodEnd;
    address public exoticBonds;

    IAddressResolver public addressResolver;

    address public thalesRangedAMM;
    address public sportsAMM;

    /* ========== CONSTRUCTOR ========== */

    function initialize(
        address _owner,
        address _iEscrowThales, //THALES
        address _stakingToken, //THALES
        address _feeToken, //sUSD
        uint _durationPeriod,
        uint _unstakeDurationPeriod,
        address _ISNXRewards
    ) public initializer {
        setOwner(_owner);
        initNonReentrant();
        iEscrowThales = IEscrowThales(_iEscrowThales);
        stakingToken = IERC20(_stakingToken);
        feeToken = IERC20(_feeToken);
        stakingToken.approve(_iEscrowThales, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        durationPeriod = _durationPeriod;
        unstakeDurationPeriod = _unstakeDurationPeriod;
        fixedPeriodReward = 70000 * 1e18;
        periodExtraReward = 21000 * 1e18;
        SNXRewards = ISNXRewards(_ISNXRewards);
    }

    /* ========== VIEWS ========== */

    function totalStakedAmount() external view returns (uint) {
        return _totalStakedAmount;
    }

    function stakedBalanceOf(address account) external view returns (uint) {
        return _stakedBalances[account];
    }

    function getLastPeriodOfClaimedRewards(address account) external view returns (uint) {
        return _lastRewardsClaimedPeriod[account];
    }

    function getRewardsAvailable(address account) external view returns (uint) {
        return _calculateAvailableRewardsToClaim(account);
    }

    function getRewardFeesAvailable(address account) external view returns (uint) {
        return _calculateAvailableFeesToClaim(account);
    }

    function getAlreadyClaimedRewards(address account) external view returns (uint) {
        return stakerLifetimeRewardsClaimed[account];
    }

    function getAlreadyClaimedFees(address account) external view returns (uint) {
        return stakerFeesClaimed[account];
    }

    function getContractRewardFunds() external view returns (uint) {
        return stakingToken.balanceOf(address(ThalesStakingRewardsPool));
    }

    function getContractFeeFunds() external view returns (uint) {
        return feeToken.balanceOf(address(this));
    }

    function setDistributeFeesEnabled(bool _distributeFeesEnabled) external onlyOwner {
        distributeFeesEnabled = _distributeFeesEnabled;
        emit DistributeFeesEnabled(_distributeFeesEnabled);
    }

    function setFixedPeriodReward(uint _fixedReward) external onlyOwner {
        fixedPeriodReward = _fixedReward;
        emit FixedPeriodRewardChanged(_fixedReward);
    }

    function setPeriodExtraReward(uint _extraReward) external onlyOwner {
        periodExtraReward = _extraReward;
        emit PeriodExtraRewardChanged(_extraReward);
    }

    function setClaimEnabled(bool _claimEnabled) external onlyOwner {
        claimEnabled = _claimEnabled;
        emit ClaimEnabled(_claimEnabled);
    }

    function setDurationPeriod(uint _durationPeriod) external onlyOwner {
        durationPeriod = _durationPeriod;
        emit DurationPeriodChanged(_durationPeriod);
    }

    function setUnstakeDurationPeriod(uint _unstakeDurationPeriod) external onlyOwner {
        unstakeDurationPeriod = _unstakeDurationPeriod;
        emit UnstakeDurationPeriodChanged(_unstakeDurationPeriod);
    }

    function setSNXRewards(address _snxRewards) public onlyOwner {
        require(_snxRewards != address(0), "Invalid address");
        SNXRewards = ISNXRewards(_snxRewards);
        emit SNXRewardsAddressChanged(_snxRewards);
    }

    function setExtraRewards(bool _extraRewardsActive) public onlyOwner {
        extraRewardsActive = _extraRewardsActive;
        emit ExtraRewardsChanged(_extraRewardsActive);
    }

    function setMaxSNXRewardsPercentage(uint _maxSNXRewardsPercentage) public onlyOwner {
        maxSNXRewardsPercentage = _maxSNXRewardsPercentage;
        emit MaxSNXRewardsPercentageChanged(_maxSNXRewardsPercentage);
    }

    function setMaxAMMVolumeRewardsPercentage(uint _maxAMMVolumeRewardsPercentage) public onlyOwner {
        maxAMMVolumeRewardsPercentage = _maxAMMVolumeRewardsPercentage;
        emit MaxAMMVolumeRewardsPercentageChanged(_maxAMMVolumeRewardsPercentage);
    }

    function setAMMVolumeRewardsMultiplier(uint _AMMVolumeRewardsMultiplier) public onlyOwner {
        AMMVolumeRewardsMultiplier = _AMMVolumeRewardsMultiplier;
        emit AMMVolumeRewardsMultiplierChanged(_AMMVolumeRewardsMultiplier);
    }

    function setSNXVolumeRewardsMultiplier(uint _SNXVolumeRewardsMultiplier) public onlyOwner {
        SNXVolumeRewardsMultiplier = _SNXVolumeRewardsMultiplier;
        emit SNXVolumeRewardsMultiplierChanged(_SNXVolumeRewardsMultiplier);
    }

    function setMaxThalesRoyaleRewardsPercentage(uint _maxThalesRoyaleRewardsPercentage) public onlyOwner {
        maxThalesRoyaleRewardsPercentage = _maxThalesRoyaleRewardsPercentage;
        emit MaxThalesRoyaleRewardsPercentageChanged(_maxThalesRoyaleRewardsPercentage);
    }

    function setThalesRoyale(address _royale) public onlyOwner {
        require(_royale != address(0), "Invalid address");
        thalesRoyale = IThalesRoyale(_royale);
        emit ThalesRoyaleAddressChanged(_royale);
    }

    function setThalesAMM(address _thalesAMM) public onlyOwner {
        require(_thalesAMM != address(0), "Invalid address");
        thalesAMM = _thalesAMM;
        emit ThalesAMMAddressChanged(_thalesAMM);
    }

    function setThalesRangedAMM(address _thalesRangedAMM) public onlyOwner {
        require(_thalesRangedAMM != address(0), "Invalid address");
        thalesRangedAMM = _thalesRangedAMM;
        emit ThalesRangedAMMAddressChanged(_thalesRangedAMM);
    }

    function setThalesSportsAMM(address _sportsAMM) public onlyOwner {
        require(_sportsAMM != address(0), "Invalid address");
        sportsAMM = _sportsAMM;
        emit ThalesSportsAMMAddressChanged(_sportsAMM);
    }

    function setExoticBonds(address _exoticBonds) public onlyOwner {
        require(_exoticBonds != address(0), "Invalid address");
        exoticBonds = _exoticBonds;
        emit ExoticBondsAddressChanged(_exoticBonds);
    }

    function setPriceFeed(address _priceFeed) public onlyOwner {
        require(_priceFeed != address(0), "Invalid address");
        priceFeed = IPriceFeed(_priceFeed);
        emit PriceFeedAddressChanged(_priceFeed);
    }

    function setThalesStakingRewardsPool(address _thalesStakingRewardsPool) public onlyOwner {
        require(_thalesStakingRewardsPool != address(0), "Invalid address");
        ThalesStakingRewardsPool = IThalesStakingRewardsPool(_thalesStakingRewardsPool);
        emit ThalesStakingRewardsPoolChanged(_thalesStakingRewardsPool);
    }

    // Set EscrowThales contract address
    function setEscrow(address _escrowThalesContract) public onlyOwner {
        if (address(iEscrowThales) != address(0)) {
            stakingToken.approve(address(iEscrowThales), 0);
        }
        iEscrowThales = IEscrowThales(_escrowThalesContract);
        stakingToken.approve(_escrowThalesContract, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        emit EscrowChanged(_escrowThalesContract);
    }

    function setAddressResolver(address _addressResolver) external onlyOwner {
        require(_addressResolver != address(0), "Invalid address");
        addressResolver = IAddressResolver(_addressResolver);
        emit AddressResolverChanged(_addressResolver);
    }

    function getSNXRewardsAddress() public view returns (address) {
        if (address(addressResolver) == address(0)) {
            return address(0);
        } else {
            return addressResolver.getAddress("Issuer");
        }
    }

    function getSNXStaked(address account) external view returns (uint) {
        return _getSNXStakedForAccount(account);
    }

    function getBaseReward(address account) public view returns (uint) {
        if (
            (_lastStakingPeriod[account] == periodsOfStaking) ||
            (_stakedBalances[account] == 0) ||
            (_lastRewardsClaimedPeriod[account] == periodsOfStaking) ||
            (totalStakedLastPeriodEnd == 0)
        ) {
            return 0;
        }
        return
            _stakedBalances[account]
                .add(iEscrowThales.getStakedEscrowedBalanceForRewards(account))
                .mul(currentPeriodRewards)
                .div(totalStakedLastPeriodEnd.add(totalEscrowedLastPeriodEnd));
    }

    function getAMMVolume(address account) external view returns (uint) {
        return _getTotalAMMVolume(account);
    }

    function getSNXBonusPercentage(address account) public view returns (uint) {
        uint baseReward = getBaseReward(account);
        if (baseReward == 0) {
            return 0;
        }
        uint stakedSNX = _getSNXStakedForAccount(account);
        // SNX staked more than base reward
        return
            stakedSNX >= baseReward.mul(SNXVolumeRewardsMultiplier)
                ? maxSNXRewardsPercentage.mul(ONE_PERCENT)
                : stakedSNX.mul(maxSNXRewardsPercentage).mul(ONE_PERCENT).div(baseReward.mul(SNXVolumeRewardsMultiplier));
    }

    function getSNXBonus(address account) public view returns (uint) {
        uint baseReward = getBaseReward(account);
        uint SNXBonusPercentage = getSNXBonusPercentage(account);

        return baseReward.mul(SNXBonusPercentage).div(ONE);
    }

    function getAMMBonusPercentage(address account) public view returns (uint) {
        uint baseReward = getBaseReward(account);
        if (baseReward == 0) {
            return 0;
        }
        return
            _getTotalAMMVolume(account) >= baseReward.mul(AMMVolumeRewardsMultiplier)
                ? maxAMMVolumeRewardsPercentage.mul(ONE_PERCENT)
                : _getTotalAMMVolume(account).mul(ONE_PERCENT).mul(maxAMMVolumeRewardsPercentage).div(
                    baseReward.mul(AMMVolumeRewardsMultiplier)
                );
    }

    function getAMMBonus(address account) public view returns (uint) {
        uint baseReward = getBaseReward(account);
        uint AMMPercentage = getAMMBonusPercentage(account);
        return baseReward.mul(AMMPercentage).div(ONE);
    }

    function getThalesRoyaleBonusPercentage(address account) public view returns (uint) {
        uint baseReward = getBaseReward(account);
        if (baseReward == 0) {
            return 0;
        }
        return
            (address(thalesRoyale) != address(0) && thalesRoyale.hasParticipatedInCurrentOrLastRoyale(account))
                ? maxThalesRoyaleRewardsPercentage.mul(ONE_PERCENT)
                : 0;
    }

    function getThalesRoyaleBonus(address account) public view returns (uint) {
        uint baseReward = getBaseReward(account);
        uint RoyalePercentage = getThalesRoyaleBonusPercentage(account);
        return baseReward.mul(RoyalePercentage).div(ONE);
    }

    function getTotalBonusPercentage(address account) public view returns (uint) {
        uint snxPercentage = getSNXBonusPercentage(account);
        uint ammPercentage = getAMMBonusPercentage(account);
        uint royalePercentage = getThalesRoyaleBonusPercentage(account);
        return snxPercentage.add(ammPercentage).add(royalePercentage);
    }

    function getTotalBonus(address account) public view returns (uint) {
        uint baseReward = getBaseReward(account);
        uint totalBonusPercentage = getTotalBonusPercentage(account);
        // failsafe
        require(totalBonusPercentage < ONE, "Bonus Exceeds base rewards");
        return baseReward.mul(totalBonusPercentage).div(ONE);
    }

    function canClosePeriod() external view returns (bool) {
        return (startTimeStamp > 0 && (block.timestamp >= lastPeriodTimeStamp.add(durationPeriod)));
    }

    function getSNXTargetRatio() public view returns (uint) {
        uint hund = 100 * 100 * 1e18;
        return hund.div(ISNXRewards(getSNXRewardsAddress()).issuanceRatio());
    }

    function getCRatio(address account) public view returns (uint) {
        uint debt = ISNXRewards(getSNXRewardsAddress()).debtBalanceOf(account, "sUSD");
        if (debt == 0) {
            return 0;
        }
        uint hund = 100 * 100 * 1e18;
        (uint cRatio, ) = ISNXRewards(getSNXRewardsAddress()).collateralisationRatioAndAnyRatesInvalid(account);
        return hund.div(cRatio);
    }

    function getSNXRateForCurrency() public view returns (uint) {
        return priceFeed.rateForCurrency("SNX");
    }

    function getSNXDebt(address account) public view returns (uint) {
        return ISNXRewards(getSNXRewardsAddress()).debtBalanceOf(account, "sUSD");
    }

    /* ========== PUBLIC ========== */

    function startStakingPeriod() external onlyOwner {
        require(startTimeStamp == 0, "Staking has already started");
        startTimeStamp = block.timestamp;
        periodsOfStaking = 0;
        lastPeriodTimeStamp = startTimeStamp;
        _totalUnclaimedRewards = 0;
        _totalRewardsClaimed = 0;
        _totalRewardFeesClaimed = 0;
        _totalStakedAmount = 0;
        _totalEscrowedAmount = 0;
        _totalPendingStakeAmount = 0;
        emit StakingPeriodStarted();
    }

    function closePeriod() external nonReentrant notPaused {
        require(startTimeStamp > 0, "Staking period has not started");
        require(
            block.timestamp >= lastPeriodTimeStamp.add(durationPeriod),
            "A full period has not passed since the last closed period"
        );

        iEscrowThales.updateCurrentPeriod();
        lastPeriodTimeStamp = block.timestamp;
        periodsOfStaking = iEscrowThales.currentVestingPeriod();

        _totalEscrowedAmount = iEscrowThales.totalEscrowedRewards().sub(
            iEscrowThales.totalEscrowBalanceNotIncludedInStaking()
        );

        //Actions taken on every closed period
        currentPeriodRewards = fixedPeriodReward;
        _totalUnclaimedRewards = _totalUnclaimedRewards.add(currentPeriodRewards.add(periodExtraReward));

        currentPeriodFees = feeToken.balanceOf(address(this));

        totalStakedLastPeriodEnd = _totalStakedAmount;
        totalEscrowedLastPeriodEnd = _totalEscrowedAmount;

        emit ClosedPeriod(periodsOfStaking, lastPeriodTimeStamp);
    }

    function stake(uint amount) external nonReentrant notPaused {
        require(startTimeStamp > 0, "Staking period has not started");
        require(amount > 0, "Cannot stake 0");
        require(
            stakingToken.allowance(msg.sender, address(this)) >= amount,
            "No allowance. Please grant StakingThales allowance"
        );
        require(unstaking[msg.sender] == false, "Cannot stake, the staker is paused from staking due to unstaking");
        // Check if there are not claimable rewards from last period.
        // Claim them, and add new stake

        if (_calculateAvailableRewardsToClaim(msg.sender) > 0) {
            _claimReward(msg.sender);
        }
        _lastStakingPeriod[msg.sender] = periodsOfStaking;

        // if just started staking subtract his escrowed balance from totalEscrowBalanceNotIncludedInStaking
        if (_stakedBalances[msg.sender] == 0) {
            if (iEscrowThales.totalAccountEscrowedAmount(msg.sender) > 0) {
                iEscrowThales.subtractTotalEscrowBalanceNotIncludedInStaking(
                    iEscrowThales.totalAccountEscrowedAmount(msg.sender)
                );
            }
        }

        _totalStakedAmount = _totalStakedAmount.add(amount);
        _stakedBalances[msg.sender] = _stakedBalances[msg.sender].add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    function stakeOnBehalf(uint amount, address staker) external nonReentrant onlyOwner {
        require(startTimeStamp > 0, "Staking period has not started");
        require(amount > 0, "Cannot stake 0");
        require(
            stakingToken.allowance(msg.sender, address(this)) >= amount,
            "No allowance. Please grant StakingThales allowance"
        );
        require(unstaking[staker] == false, "Cannot stake, the staker is paused from staking due to unstaking");
        // Check if there are not claimable rewards from last period.
        // Claim them, and add new stake
        if (_calculateAvailableRewardsToClaim(staker) > 0) {
            _claimReward(staker);
        }

        // if just started staking subtract his escrowed balance from totalEscrowBalanceNotIncludedInStaking
        if (_stakedBalances[staker] == 0) {
            if (iEscrowThales.totalAccountEscrowedAmount(staker) > 0) {
                iEscrowThales.subtractTotalEscrowBalanceNotIncludedInStaking(
                    iEscrowThales.totalAccountEscrowedAmount(staker)
                );
            }
        }

        _totalStakedAmount = _totalStakedAmount.add(amount);
        _stakedBalances[staker] = _stakedBalances[staker].add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit StakedOnBehalf(msg.sender, staker, amount);
    }

    function startUnstake(uint amount) external notPaused {
        require(amount > 0, "Cannot unstake 0");
        require(_stakedBalances[msg.sender] >= amount, "Account doesnt have that much staked");
        require(unstaking[msg.sender] == false, "Account has already triggered unstake cooldown");

        if (_calculateAvailableRewardsToClaim(msg.sender) > 0) {
            _claimReward(msg.sender);
        }
        lastUnstakeTime[msg.sender] = block.timestamp;
        unstaking[msg.sender] = true;
        _totalStakedAmount = _totalStakedAmount.sub(amount);
        unstakingAmount[msg.sender] = amount;
        _stakedBalances[msg.sender] = _stakedBalances[msg.sender].sub(amount);

        // on full unstake add his escrowed balance to totalEscrowBalanceNotIncludedInStaking
        if (_stakedBalances[msg.sender] == 0) {
            if (iEscrowThales.totalAccountEscrowedAmount(msg.sender) > 0) {
                iEscrowThales.addTotalEscrowBalanceNotIncludedInStaking(
                    iEscrowThales.totalAccountEscrowedAmount(msg.sender)
                );
            }
        }

        emit UnstakeCooldown(msg.sender, lastUnstakeTime[msg.sender].add(unstakeDurationPeriod), amount);
    }

    function cancelUnstake() external notPaused {
        require(unstaking[msg.sender] == true, "Account is not unstaking");

        // on revert full unstake remove his escrowed balance from totalEscrowBalanceNotIncludedInStaking
        if (_stakedBalances[msg.sender] == 0) {
            if (iEscrowThales.totalAccountEscrowedAmount(msg.sender) > 0) {
                iEscrowThales.subtractTotalEscrowBalanceNotIncludedInStaking(
                    iEscrowThales.totalAccountEscrowedAmount(msg.sender)
                );
            }
        }

        if (_calculateAvailableRewardsToClaim(msg.sender) > 0) {
            _claimReward(msg.sender);
        }

        unstaking[msg.sender] = false;
        _totalStakedAmount = _totalStakedAmount.add(unstakingAmount[msg.sender]);
        _stakedBalances[msg.sender] = _stakedBalances[msg.sender].add(unstakingAmount[msg.sender]);
        unstakingAmount[msg.sender] = 0;

        emit CancelUnstake(msg.sender);
    }

    function unstake() external notPaused {
        require(unstaking[msg.sender] == true, "Account has not triggered unstake cooldown");
        require(
            lastUnstakeTime[msg.sender] < block.timestamp.sub(unstakeDurationPeriod),
            "Cannot unstake yet, cooldown not expired."
        );
        unstaking[msg.sender] = false;
        uint unstakeAmount = unstakingAmount[msg.sender];
        stakingToken.safeTransfer(msg.sender, unstakeAmount);
        unstakingAmount[msg.sender] = 0;
        emit Unstaked(msg.sender, unstakeAmount);
    }

    function claimReward() public nonReentrant notPaused {
        _claimReward(msg.sender);
    }

    function updateVolume(address account, uint amount) external {
        require(
            msg.sender == thalesAMM || msg.sender == exoticBonds || msg.sender == thalesRangedAMM || msg.sender == sportsAMM,
            "Invalid address"
        );
        require(msg.sender != address(0), "Invalid address");
        if (lastAMMUpdatePeriod[account] < periodsOfStaking) {
            stakerAMMVolume[account][periodsOfStaking.mod(AMM_EXTRA_REWARD_PERIODS)].amount = 0;
            stakerAMMVolume[account][periodsOfStaking.mod(AMM_EXTRA_REWARD_PERIODS)].period = periodsOfStaking;
            lastAMMUpdatePeriod[account] = periodsOfStaking;
        }
        stakerAMMVolume[account][periodsOfStaking.mod(AMM_EXTRA_REWARD_PERIODS)].amount = stakerAMMVolume[account][
            periodsOfStaking.mod(AMM_EXTRA_REWARD_PERIODS)
        ]
            .amount
            .add(amount);
        emit AMMVolumeUpdated(account, amount);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _claimReward(address account) internal notPaused {
        require(claimEnabled, "Claiming is not enabled.");
        require(startTimeStamp > 0, "Staking period has not started");

        //Calculate rewards
        if (distributeFeesEnabled) {
            uint availableFeesToClaim = _calculateAvailableFeesToClaim(account);
            if (availableFeesToClaim > 0) {
                feeToken.safeTransfer(account, availableFeesToClaim);
                stakerFeesClaimed[account] = stakerFeesClaimed[account].add(availableFeesToClaim);
                _totalRewardFeesClaimed = _totalRewardFeesClaimed.add(availableFeesToClaim);
                emit FeeRewardsClaimed(account, availableFeesToClaim);
            }
        }
        uint availableRewardsToClaim = _calculateAvailableRewardsToClaim(account);
        if (availableRewardsToClaim > 0) {
            // Transfer THALES to Escrow contract
            ThalesStakingRewardsPool.addToEscrow(account, availableRewardsToClaim);
            // Record the total claimed rewards
            stakerLifetimeRewardsClaimed[account] = stakerLifetimeRewardsClaimed[account].add(availableRewardsToClaim);
            _totalRewardsClaimed = _totalRewardsClaimed.add(availableRewardsToClaim);
            _totalUnclaimedRewards = _totalUnclaimedRewards.sub(availableRewardsToClaim);

            emit RewardsClaimed(account, availableRewardsToClaim);
        }
        // Update last claiming period
        _lastRewardsClaimedPeriod[account] = periodsOfStaking;
    }

    function _calculateAvailableRewardsToClaim(address account) internal view returns (uint) {
        uint baseReward = getBaseReward(account);
        if (baseReward == 0) {
            return 0;
        }
        if (!extraRewardsActive) {
            return baseReward;
        } else {
            return baseReward.add(getTotalBonus(account));
        }
    }

    function _calculateAvailableFeesToClaim(address account) internal view returns (uint) {
        uint baseReward = getBaseReward(account);
        if (baseReward == 0) {
            return 0;
        }

        return
            _stakedBalances[account]
                .add(iEscrowThales.getStakedEscrowedBalanceForRewards(account))
                .mul(currentPeriodFees)
                .div(totalStakedLastPeriodEnd.add(totalEscrowedLastPeriodEnd));
    }

    function _getSNXStakedForAccount(address account) internal view returns (uint) {
        uint cRatio = getCRatio(account);
        uint targetRatio = getSNXTargetRatio();
        uint snxPrice = priceFeed.rateForCurrency("SNX");
        uint debt = ISNXRewards(getSNXRewardsAddress()).debtBalanceOf(account, "sUSD");
        if (cRatio < targetRatio) {
            return (cRatio.mul(cRatio).mul(debt).mul(1e14)).div(targetRatio.mul(snxPrice));
        } else {
            return (targetRatio.mul(debt).mul(1e14)).div(snxPrice);
        }
    }

    function _getTotalAMMVolume(address account) internal view returns (uint) {
        uint totalAMMforAccount;
        if (periodsOfStaking >= lastAMMUpdatePeriod[account].add(AMM_EXTRA_REWARD_PERIODS)) {
            return 0;
        }
        for (uint i = 0; i < AMM_EXTRA_REWARD_PERIODS; i++) {
            if (periodsOfStaking < stakerAMMVolume[account][i].period.add(AMM_EXTRA_REWARD_PERIODS))
                totalAMMforAccount = totalAMMforAccount.add(stakerAMMVolume[account][i].amount);
        }
        return totalAMMforAccount;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint reward);
    event Staked(address user, uint amount);
    event StakedOnBehalf(address user, address staker, uint amount);
    event ClosedPeriod(uint PeriodOfStaking, uint lastPeriodTimeStamp);
    event RewardsClaimed(address account, uint unclaimedReward);
    event FeeRewardsClaimed(address account, uint unclaimedFees);
    event UnstakeCooldown(address account, uint cooldownTime, uint amount);
    event CancelUnstake(address account);
    event Unstaked(address account, uint unstakeAmount);
    event ClaimEnabled(bool enabled);
    event DistributeFeesEnabled(bool enabled);
    event FixedPeriodRewardChanged(uint value);
    event PeriodExtraRewardChanged(uint value);
    event DurationPeriodChanged(uint value);
    event UnstakeDurationPeriodChanged(uint value);
    event EscrowChanged(address newEscrow);
    event StakingPeriodStarted();
    event SNXRewardsAddressChanged(address snxRewards);
    event ThalesRoyaleAddressChanged(address royale);
    event ThalesAMMAddressChanged(address amm);
    event ThalesRangedAMMAddressChanged(address amm);
    event ThalesSportsAMMAddressChanged(address amm);
    event AMMVolumeUpdated(address account, uint amount);
    event ExtraRewardsChanged(bool extrarewardsactive);
    event PriceFeedAddressChanged(address pricefeed);
    event MaxSNXRewardsPercentageChanged(uint maxSnxRewardsPercentage);
    event AMMVolumeRewardsMultiplierChanged(uint ammVolumeRewardsMultiplier);
    event MaxAMMVolumeRewardsPercentageChanged(uint maxAmmVolumeRewardsPercentage);
    event MaxThalesRoyaleRewardsPercentageChanged(uint maxThalesRewardsPercentage);
    event ThalesStakingRewardsPoolChanged(address thalesStakingRewardsPool);
    event SNXVolumeRewardsMultiplierChanged(uint ammVolumeRewardsMultiplier);
    event AddressResolverChanged(address addressResolver);
    event ExoticBondsAddressChanged(address exoticBonds);
}

pragma solidity ^0.5.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves.

        // A Solidity high level call has three parts:
        //  1. The target address is checked to verify it contains contract code
        //  2. The call itself is made, and success asserted
        //  3. The return value is decoded, which in turn checks the size of the returned data.
        // solhint-disable-next-line max-line-length
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

pragma solidity ^0.5.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.5.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the `nonReentrant` modifier
 * available, which can be aplied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 */
contract ProxyReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;
    bool private _initialized;

    function initNonReentrant() public {
        require(!_initialized, "Already initialized");
        _initialized = true;
        _guardCounter = 1;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter, "ReentrancyGuard: reentrant call");
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.5.16;

// Clone of syntetix contract without constructor
contract ProxyOwned {
    address public owner;
    address public nominatedOwner;
    bool private _initialized;
    bool private _transferredAtInit;

    function setOwner(address _owner) public {
        require(_owner != address(0), "Owner address cannot be 0");
        require(!_initialized, "Already initialized, use nominateNewOwner");
        _initialized = true;
        owner = _owner;
        emit OwnerChanged(address(0), _owner);
    }

    function nominateNewOwner(address _owner) external onlyOwner {
        nominatedOwner = _owner;
        emit OwnerNominated(_owner);
    }

    function acceptOwnership() external {
        require(msg.sender == nominatedOwner, "You must be nominated before you can accept ownership");
        emit OwnerChanged(owner, nominatedOwner);
        owner = nominatedOwner;
        nominatedOwner = address(0);
    }

    function transferOwnershipAtInit(address proxyAddress) external onlyOwner {
        require(proxyAddress != address(0), "Invalid address");
        require(!_transferredAtInit, "Already transferred");
        owner = proxyAddress;
        _transferredAtInit = true;
        emit OwnerChanged(owner, proxyAddress);
    }

    modifier onlyOwner {
        _onlyOwner();
        _;
    }

    function _onlyOwner() private view {
        require(msg.sender == owner, "Only the contract owner may perform this action");
    }

    event OwnerNominated(address newOwner);
    event OwnerChanged(address oldOwner, address newOwner);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.5.16;

// Inheritance
import "./ProxyOwned.sol";

// Clone of syntetix contract without constructor

contract ProxyPausable is ProxyOwned {
    uint public lastPauseTime;
    bool public paused;

    

    /**
     * @notice Change the paused state of the contract
     * @dev Only the contract owner may call this.
     */
    function setPaused(bool _paused) external onlyOwner {
        // Ensure we're actually changing the state before we do anything
        if (_paused == paused) {
            return;
        }

        // Set our paused state.
        paused = _paused;

        // If applicable, set the last pause time.
        if (paused) {
            lastPauseTime = block.timestamp;
        }

        // Let everyone know that our pause state has changed.
        emit PauseChanged(paused);
    }

    event PauseChanged(bool isPaused);

    modifier notPaused {
        require(!paused, "This action cannot be performed while the contract is paused");
        _;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.4.24 <0.7.0;


/**
 * @title Initializable
 *
 * @dev Helper contract to support initializer functions. To use it, replace
 * the constructor with a function that has the `initializer` modifier.
 * WARNING: Unlike constructors, initializer functions must be manually
 * invoked. This applies both to deploying an Initializable contract, as well
 * as extending an Initializable contract via inheritance.
 * WARNING: When used with inheritance, manual care must be taken to not invoke
 * a parent initializer twice, or ensure that all initializers are idempotent,
 * because this is not dealt with automatically as with constructors.
 */
contract Initializable {

  /**
   * @dev Indicates that the contract has been initialized.
   */
  bool private initialized;

  /**
   * @dev Indicates that the contract is in the process of being initialized.
   */
  bool private initializing;

  /**
   * @dev Modifier to use in the initializer function of a contract.
   */
  modifier initializer() {
    require(initializing || isConstructor() || !initialized, "Contract instance has already been initialized");

    bool isTopLevelCall = !initializing;
    if (isTopLevelCall) {
      initializing = true;
      initialized = true;
    }

    _;

    if (isTopLevelCall) {
      initializing = false;
    }
  }

  /// @dev Returns true if and only if the function is running in the constructor
  function isConstructor() private view returns (bool) {
    // extcodesize checks the size of the code stored in an address, and
    // address returns the current address. Since the code is still not
    // deployed when running a constructor, any checks on its code size will
    // yield zero, making it an effective way to detect if a contract is
    // under construction or not.
    address self = address(this);
    uint256 cs;
    assembly { cs := extcodesize(self) }
    return cs == 0;
  }

  // Reserved storage space to allow for layout changes in the future.
  uint256[50] private ______gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

interface IEscrowThales {
    /* ========== VIEWS / VARIABLES ========== */
    function getStakerPeriod(address account, uint index) external view returns (uint);

    function getStakerAmounts(address account, uint index) external view returns (uint);

    function totalAccountEscrowedAmount(address account) external view returns (uint);

    function getStakedEscrowedBalanceForRewards(address account) external view returns (uint);

    function totalEscrowedRewards() external view returns (uint);

    function totalEscrowBalanceNotIncludedInStaking() external view returns (uint);

    function currentVestingPeriod() external view returns (uint);

    function updateCurrentPeriod() external returns (bool);

    function claimable(address account) external view returns (uint);

    function addToEscrow(address account, uint amount) external;

    function vest(uint amount) external returns (bool);

    function addTotalEscrowBalanceNotIncludedInStaking(uint amount) external;

    function subtractTotalEscrowBalanceNotIncludedInStaking(uint amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

interface IStakingThales {
    function updateVolume(address account, uint amount) external;
    
    /* ========== VIEWS / VARIABLES ========== */
    function totalStakedAmount() external view returns (uint);

    function stakedBalanceOf(address account) external view returns (uint); 

    function currentPeriodRewards() external view returns (uint);

    function currentPeriodFees() external view returns (uint);

    function getLastPeriodOfClaimedRewards(address account) external view returns (uint);

    function getRewardsAvailable(address account) external view returns (uint);

    function getRewardFeesAvailable(address account) external view returns (uint);

    function getAlreadyClaimedRewards(address account) external view returns (uint);

    function getAlreadyClaimedFees(address account) external view returns (uint);

    function getContractRewardFunds() external view returns (uint);

    function getContractFeeFunds() external view returns (uint);

    
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

interface ISNXRewards {
    /* ========== VIEWS / VARIABLES ========== */
    function collateralisationRatioAndAnyRatesInvalid(address account) external view returns (uint, bool);
    function debtBalanceOf(address _issuer, bytes32 currencyKey) external view returns (uint);
    function issuanceRatio() external view returns (uint);

    function setCRatio(address account, uint _c_ratio) external;
    function setIssuanceRatio(uint _issuanceRation) external;
    
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;
pragma experimental ABIEncoderV2;
import "../interfaces/IPassportPosition.sol";

interface IThalesRoyale {

    
    /* ========== VIEWS / VARIABLES ========== */
    function getBuyInAmount() external view returns (uint);
    function season() external view returns (uint);
    function tokenSeason(uint tokenId) external view returns (uint);
    function seasonFinished(uint _season) external view returns (bool);
    function roundInASeason(uint _round) external view returns (uint);
    function roundResultPerSeason(uint _season, uint round) external view returns (uint);
    function isTokenAliveInASpecificSeason(uint tokenId, uint _season) external view returns (bool);
    function hasParticipatedInCurrentOrLastRoyale(address _player) external view returns (bool);

    function getTokenPositions(uint tokenId) external view returns (IPassportPosition.Position[] memory);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

interface IPriceFeed {
     // Structs
    struct RateAndUpdatedTime {
        uint216 rate;
        uint40 time;
    }
    
    // Mutative functions
    function addAggregator(bytes32 currencyKey, address aggregatorAddress) external;

    function removeAggregator(bytes32 currencyKey) external;

    // Views

    function rateForCurrency(bytes32 currencyKey) external view returns (uint);

    function rateAndUpdatedTime(bytes32 currencyKey) external view returns (uint rate, uint time);

    function getRates() external view returns (uint[] memory);

    function getCurrencies() external view returns (bytes32[] memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.5.16;

interface IThalesStakingRewardsPool {
   
   function addToEscrow(address account, uint amount) external;

    
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.5.16;

interface IAddressResolver {
    /* ========== VIEWS / VARIABLES ========== */
    function getAddress(bytes32 name) external view returns (address);    
}

pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see `ERC20Detailed`.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through `transferFrom`. This is
     * zero by default.
     *
     * This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * > Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an `Approval` event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to `approve`. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.5.0;

/**
 * @dev Collection of functions related to the address type,
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * This test is non-exhaustive, and there may be false-negatives: during the
     * execution of a contract's constructor, its address will be reported as
     * not containing a contract.
     *
     * > It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

interface IPassportPosition {
   
    struct Position {
       uint round;
       uint position;
   }

}