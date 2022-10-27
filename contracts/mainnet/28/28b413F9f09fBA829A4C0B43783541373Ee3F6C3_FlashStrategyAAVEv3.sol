// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/AAVE/IL2Pool.sol";
import "./interfaces/AAVE/IL2Encoder.sol";
import "./interfaces/AAVE/IRewardsController.sol";
import "./interfaces/FlashstakeProtocol/IFlashStrategy.sol";
import "./interfaces/FlashstakeProtocol/IUserIncentive.sol";
import "./interfaces/FlashstakeProtocol/IFlashFToken.sol";

contract FlashStrategyAAVEv3 is IFlashStrategy, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address immutable flashProtocolAddress; // The Flash Protocol address this strat belongs to
    address immutable lendingPoolAddress; // The AAVEv3 lending pool contract address
    address immutable principalTokenAddress; // The principal token accepted by this strategy
    address immutable interestBearingTokenAddress; // The AAVEv3 aToken contract address
    uint8 immutable principalDecimals; // Number of decimals, used when minting fTokens

    address immutable aaveIncentivesAddress; // AAVEv3 Incentives contract address
    address immutable aaveL2Encoder; // The AAVEv3 L2Encoder contract address

    address public aaveIncentiveRedirectAddress = address(this); // Determines where AAVE rewards should go
    address[] aaveRewardsArray = new address[](1);

    address fTokenAddress; // The Flash fERC20 token address
    uint16 referralCode = 0; // The AAVE V2 referral code
    uint256 principalBalance; // The amount of principal in this strategy

    address public userIncentiveAddress; // The UserIncentive contract address
    bool public userIncentiveAddressLocked; // Determine whether the above is locked (stop future updates)

    uint256 maxStakeDuration = 63072000; // Maximum stake duration for this strategy
    bool public maxStakeDurationLocked = false; // Determines if the above variable is locked (stop future updates)

    constructor(
        address _lendingPoolAddress,
        address _aaveIncentivesAddress,
        address _aaveL2Encoder,
        address _principalTokenAddress,
        address _interestBearingTokenAddress,
        address _flashProtocolAddress
    ) public {
        lendingPoolAddress = _lendingPoolAddress;
        aaveIncentivesAddress = _aaveIncentivesAddress;
        aaveL2Encoder = _aaveL2Encoder;
        principalTokenAddress = _principalTokenAddress;
        interestBearingTokenAddress = _interestBearingTokenAddress;
        flashProtocolAddress = _flashProtocolAddress;

        // Read the number of decimals from the principal token
        principalDecimals = IFlashFToken(principalTokenAddress).decimals();

        aaveRewardsArray[0] = interestBearingTokenAddress;

        increaseAllowance();
    }

    // Implemented as a separate function just in case the strategy ever runs out of allowance
    function increaseAllowance() public {
        IERC20(principalTokenAddress).safeApprove(lendingPoolAddress, 0);
        IERC20(principalTokenAddress).safeApprove(lendingPoolAddress, type(uint256).max);
    }

    function depositPrincipal(uint256 _tokenAmount) external override onlyAuthorised returns (uint256) {
        // Register how much we are depositing
        principalBalance = principalBalance + _tokenAmount;

        // Deposit into AAVE
        IL2Pool(lendingPoolAddress).supply(
            IL2Encoder(aaveL2Encoder).encodeSupplyParams(principalTokenAddress, _tokenAmount, referralCode)
        );
        IRewardsController(aaveIncentivesAddress).claimAllRewards(aaveRewardsArray, aaveIncentiveRedirectAddress);

        return _tokenAmount;
    }

    function withdrawYield(uint256 _tokenAmount) private {
        // Withdraw from AAVE
        IL2Pool(lendingPoolAddress).withdraw(
            IL2Encoder(aaveL2Encoder).encodeWithdrawParams(principalTokenAddress, _tokenAmount)
        );

        uint256 aTokenBalance = IERC20(interestBearingTokenAddress).balanceOf(address(this));
        require(aTokenBalance >= getPrincipalBalance(), "PRINCIPAL BALANCE INVALID");
    }

    function withdrawPrincipal(uint256 _tokenAmount) external override onlyAuthorised {
        // Withdraw from AAVE
        IL2Pool(lendingPoolAddress).withdraw(
            IL2Encoder(aaveL2Encoder).encodeWithdrawParams(principalTokenAddress, _tokenAmount)
        );

        IERC20(principalTokenAddress).safeTransfer(msg.sender, _tokenAmount);

        principalBalance = principalBalance - _tokenAmount;
    }

    function withdrawERC20(address[] calldata _tokenAddresses, uint256[] calldata _tokenAmounts) external onlyOwner {
        require(_tokenAddresses.length == _tokenAmounts.length, "ARRAY SIZE MISMATCH");

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            // Ensure the token being withdrawn is not the interest bearing token
            require(_tokenAddresses[i] != interestBearingTokenAddress, "TOKEN ADDRESS PROHIBITED");

            // Transfer the token to the caller
            IERC20(_tokenAddresses[i]).safeTransfer(msg.sender, _tokenAmounts[i]);
        }
    }

    function getPrincipalBalance() public view override returns (uint256) {
        return principalBalance;
    }

    function getYieldBalance() public view override returns (uint256) {
        uint256 interestBearingTokenBalance = IERC20(interestBearingTokenAddress).balanceOf(address(this));

        return (interestBearingTokenBalance - getPrincipalBalance());
    }

    function getPrincipalAddress() external view override returns (address) {
        return principalTokenAddress;
    }

    function getFTokenAddress() external view returns (address) {
        return fTokenAddress;
    }

    function setFTokenAddress(address _fTokenAddress) external override onlyAuthorised {
        require(fTokenAddress == address(0), "FTOKEN ADDRESS ALREADY SET");
        fTokenAddress = _fTokenAddress;
    }

    function quoteMintFToken(uint256 _tokenAmount, uint256 _duration) external view override returns (uint256) {
        // Enforce minimum _duration
        require(_duration >= 60, "DURATION TOO LOW");

        // 1 ERC20 for 365 DAYS = 1 fERC20
        // 1 second = 0.000000031709792000
        // eg (100000000000000000 * (1 second * 31709792000)) / 10**18
        // eg (1000000 * (1 second * 31709792000)) / 10**6
        uint256 amountToMint = (_tokenAmount * (_duration * 31709792000)) / (10**principalDecimals);

        require(amountToMint > 0, "INSUFFICIENT OUTPUT");

        return amountToMint;
    }

    function quoteBurnFToken(uint256 _tokenAmount) public view override returns (uint256) {
        uint256 totalSupply = IERC20(fTokenAddress).totalSupply();
        require(totalSupply > 0, "INSUFFICIENT fERC20 TOKEN SUPPLY");

        if (_tokenAmount > totalSupply) {
            _tokenAmount = totalSupply;
        }

        // Calculate the percentage of _tokenAmount vs totalSupply provided
        // and multiply by total yield
        return (getYieldBalance() * _tokenAmount) / totalSupply;
    }

    function burnFToken(
        uint256 _tokenAmount,
        uint256 _minimumReturned,
        address _yieldTo
    ) external override nonReentrant returns (uint256) {
        // Calculate how much yield to give back
        uint256 tokensOwed = quoteBurnFToken(_tokenAmount);
        require(tokensOwed >= _minimumReturned && tokensOwed > 0, "INSUFFICIENT OUTPUT");

        // Transfer fERC20 (from caller) tokens to contract so we can burn them
        IFlashFToken(fTokenAddress).burnFrom(msg.sender, _tokenAmount);

        withdrawYield(tokensOwed);
        IERC20(principalTokenAddress).safeTransfer(_yieldTo, tokensOwed);

        // Distribute rewards if there is a reward balance within contract
        if (userIncentiveAddress != address(0)) {
            IUserIncentive(userIncentiveAddress).claimReward(_tokenAmount, _yieldTo);
        }

        emit BurnedFToken(msg.sender, _tokenAmount, tokensOwed);

        return tokensOwed;
    }

    modifier onlyAuthorised() {
        require(msg.sender == flashProtocolAddress || msg.sender == address(this), "NOT FLASH PROTOCOL");
        _;
    }

    function getMaxStakeDuration() public view override returns (uint256) {
        return maxStakeDuration;
    }

    // @notice claims aave rewards from aave reward contract, redirects rewards to aaveIncentiveRedirectAddress
    // @dev this can only be called by the strategy owner
    function claimAAVERewards(address[] calldata _assets) external onlyOwner {
        IRewardsController(aaveIncentivesAddress).claimAllRewards(_assets, aaveIncentiveRedirectAddress);
    }

    // @notice sets the new maximum stake duration
    // @dev this can only be called by the strategy owner
    function setMaxStakeDuration(uint256 _newMaxStakeDuration) external onlyOwner {
        require(maxStakeDurationLocked == false);
        maxStakeDuration = _newMaxStakeDuration;
    }

    // @notice permanently locks the max stake duration
    // @dev this can only be called by the strategy owner
    function lockMaxStakeDuration() external onlyOwner {
        maxStakeDurationLocked = true;
    }

    // @notice set the new user incentive address
    // @dev this can only be called by the strategy owner
    function setUserIncentiveAddress(address _userIncentiveAddress) external onlyOwner {
        require(userIncentiveAddressLocked == false);
        userIncentiveAddress = _userIncentiveAddress;
    }

    // @notice permanently locks the user incentive address
    // @dev this can only be called by the strategy owner
    function lockSetUserIncentiveAddress() external onlyOwner {
        userIncentiveAddressLocked = true;
    }

    // @notice configure aave related settings
    // @dev this can only be called by the strategy owner
    function setAaveOptions(address _aaveIncentiveRedirectAddress, uint16 _refCode) external onlyOwner {
        aaveIncentiveRedirectAddress = _aaveIncentiveRedirectAddress;
        referralCode = _refCode;
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

/**
 * @title IL2Pool
 * @author Aave
 * @notice Defines the basic extension interface for an L2 Aave Pool.
 **/
interface IL2Pool {
    /**
     * @notice Calldata efficient wrapper of the supply function on behalf of the caller
     * @param args Arguments for the supply function packed in one bytes32
     *    96 bits       16 bits         128 bits      16 bits
     * | 0-padding | referralCode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     */
    function supply(bytes32 args) external;

    /**
     * @notice Calldata efficient wrapper of the supplyWithPermit function on behalf of the caller
     * @param args Arguments for the supply function packed in one bytes32
     *    56 bits    8 bits         32 bits           16 bits         128 bits      16 bits
     * | 0-padding | permitV | shortenedDeadline | referralCode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     * @param r The R parameter of ERC712 permit sig
     * @param s The S parameter of ERC712 permit sig
     */
    function supplyWithPermit(
        bytes32 args,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @notice Calldata efficient wrapper of the withdraw function, withdrawing to the caller
     * @param args Arguments for the withdraw function packed in one bytes32
     *    112 bits       128 bits      16 bits
     * | 0-padding | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     */
    function withdraw(bytes32 args) external;

    /**
     * @notice Calldata efficient wrapper of the borrow function, borrowing on behalf of the caller
     * @param args Arguments for the borrow function packed in one bytes32
     *    88 bits       16 bits             8 bits                 128 bits       16 bits
     * | 0-padding | referralCode | shortenedInterestRateMode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     */
    function borrow(bytes32 args) external;

    /**
     * @notice Calldata efficient wrapper of the repay function, repaying on behalf of the caller
     * @param args Arguments for the repay function packed in one bytes32
     *    104 bits             8 bits               128 bits       16 bits
     * | 0-padding | shortenedInterestRateMode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     * @return The final amount repaid
     */
    function repay(bytes32 args) external returns (uint256);

    /**
     * @notice Calldata efficient wrapper of the repayWithPermit function, repaying on behalf of the caller
     * @param args Arguments for the repayWithPermit function packed in one bytes32
     *    64 bits    8 bits        32 bits                   8 bits               128 bits       16 bits
     * | 0-padding | permitV | shortenedDeadline | shortenedInterestRateMode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     * @param r The R parameter of ERC712 permit sig
     * @param s The S parameter of ERC712 permit sig
     * @return The final amount repaid
     */
    function repayWithPermit(
        bytes32 args,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /**
     * @notice Calldata efficient wrapper of the repayWithATokens function
     * @param args Arguments for the repayWithATokens function packed in one bytes32
     *    104 bits             8 bits               128 bits       16 bits
     * | 0-padding | shortenedInterestRateMode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     * @return The final amount repaid
     */
    function repayWithATokens(bytes32 args) external returns (uint256);

    /**
     * @notice Calldata efficient wrapper of the swapBorrowRateMode function
     * @param args Arguments for the swapBorrowRateMode function packed in one bytes32
     *    232 bits            8 bits             16 bits
     * | 0-padding | shortenedInterestRateMode | assetId |
     * @dev assetId is the index of the asset in the reservesList.
     */
    function swapBorrowRateMode(bytes32 args) external;

    /**
     * @notice Calldata efficient wrapper of the rebalanceStableBorrowRate function
     * @param args Arguments for the rebalanceStableBorrowRate function packed in one bytes32
     *    80 bits      160 bits     16 bits
     * | 0-padding | user address | assetId |
     * @dev assetId is the index of the asset in the reservesList.
     */
    function rebalanceStableBorrowRate(bytes32 args) external;

    /**
     * @notice Calldata efficient wrapper of the setUserUseReserveAsCollateral function
     * @param args Arguments for the setUserUseReserveAsCollateral function packed in one bytes32
     *    239 bits         1 bit       16 bits
     * | 0-padding | useAsCollateral | assetId |
     * @dev assetId is the index of the asset in the reservesList.
     */
    function setUserUseReserveAsCollateral(bytes32 args) external;

    /**
     * @notice Calldata efficient wrapper of the liquidationCall function
     * @param args1 part of the arguments for the liquidationCall function packed in one bytes32
     *    64 bits      160 bits       16 bits         16 bits
     * | 0-padding | user address | debtAssetId | collateralAssetId |
     * @param args2 part of the arguments for the liquidationCall function packed in one bytes32
     *    127 bits       1 bit             128 bits
     * | 0-padding | receiveAToken | shortenedDebtToCover |
     * @dev the shortenedDebtToCover is cast to 256 bits at decode time,
     * if type(uint128).max the value will be expanded to type(uint256).max
     */
    function liquidationCall(bytes32 args1, bytes32 args2) external;
}

// SPDX-License-Identifier: UNLICENSED
// !! THIS FILE WAS AUTOGENERATED BY abi-to-sol v0.6.6. SEE SOURCE BELOW. !!
pragma solidity ^0.8.4;

interface IL2Encoder {
    function POOL() external view returns (address);

    function encodeBorrowParams(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode
    ) external view returns (bytes32);

    function encodeLiquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external view returns (bytes32, bytes32);

    function encodeRebalanceStableBorrowRate(address asset, address user) external view returns (bytes32);

    function encodeRepayParams(
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external view returns (bytes32);

    function encodeRepayWithATokensParams(
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external view returns (bytes32);

    function encodeRepayWithPermitParams(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    )
        external
        view
        returns (
            bytes32,
            bytes32,
            bytes32
        );

    function encodeSetUserUseReserveAsCollateral(address asset, bool useAsCollateral) external view returns (bytes32);

    function encodeSupplyParams(
        address asset,
        uint256 amount,
        uint16 referralCode
    ) external view returns (bytes32);

    function encodeSupplyWithPermitParams(
        address asset,
        uint256 amount,
        uint16 referralCode,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    )
        external
        view
        returns (
            bytes32,
            bytes32,
            bytes32
        );

    function encodeSwapBorrowRateMode(address asset, uint256 interestRateMode) external view returns (bytes32);

    function encodeWithdrawParams(address asset, uint256 amount) external view returns (bytes32);
}

// THIS FILE WAS AUTOGENERATED FROM THE FOLLOWING ABI JSON:
/*
[{"inputs":[{"internalType":"contract IPool","name":"pool","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[],"name":"POOL","outputs":[{"internalType":"contract IPool","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"uint256","name":"interestRateMode","type":"uint256"},{"internalType":"uint16","name":"referralCode","type":"uint16"}],"name":"encodeBorrowParams","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"collateralAsset","type":"address"},{"internalType":"address","name":"debtAsset","type":"address"},{"internalType":"address","name":"user","type":"address"},{"internalType":"uint256","name":"debtToCover","type":"uint256"},{"internalType":"bool","name":"receiveAToken","type":"bool"}],"name":"encodeLiquidationCall","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"},{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"address","name":"user","type":"address"}],"name":"encodeRebalanceStableBorrowRate","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"uint256","name":"interestRateMode","type":"uint256"}],"name":"encodeRepayParams","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"uint256","name":"interestRateMode","type":"uint256"}],"name":"encodeRepayWithATokensParams","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"uint256","name":"interestRateMode","type":"uint256"},{"internalType":"uint256","name":"deadline","type":"uint256"},{"internalType":"uint8","name":"permitV","type":"uint8"},{"internalType":"bytes32","name":"permitR","type":"bytes32"},{"internalType":"bytes32","name":"permitS","type":"bytes32"}],"name":"encodeRepayWithPermitParams","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"},{"internalType":"bytes32","name":"","type":"bytes32"},{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"bool","name":"useAsCollateral","type":"bool"}],"name":"encodeSetUserUseReserveAsCollateral","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"uint16","name":"referralCode","type":"uint16"}],"name":"encodeSupplyParams","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"uint16","name":"referralCode","type":"uint16"},{"internalType":"uint256","name":"deadline","type":"uint256"},{"internalType":"uint8","name":"permitV","type":"uint8"},{"internalType":"bytes32","name":"permitR","type":"bytes32"},{"internalType":"bytes32","name":"permitS","type":"bytes32"}],"name":"encodeSupplyWithPermitParams","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"},{"internalType":"bytes32","name":"","type":"bytes32"},{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"uint256","name":"interestRateMode","type":"uint256"}],"name":"encodeSwapBorrowRateMode","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"encodeWithdrawParams","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"}]
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IFlashStrategy {
    event BurnedFToken(address indexed _address, uint256 _tokenAmount, uint256 _yieldReturned);

    // This is how principal will be deposited into the contract
    // The Flash protocol allows the strategy to specify how much
    // should be registered. This allows the strategy to manipulate (eg take fee)
    // on the principal if the strategy requires
    function depositPrincipal(uint256 _tokenAmount) external returns (uint256);

    // This is how principal will be returned from the contract
    function withdrawPrincipal(uint256 _tokenAmount) external;

    // Responsible for instant upfront yield. Takes fERC20 tokens specific to this
    // strategy. The strategy is responsible for returning some amount of principal tokens
    function burnFToken(
        uint256 _tokenAmount,
        uint256 _minimumReturned,
        address _yieldTo
    ) external returns (uint256);

    // This should return the current total of all principal within the contract
    function getPrincipalBalance() external view returns (uint256);

    // This should return the current total of all yield generated to date (including bootstrapped tokens)
    function getYieldBalance() external view returns (uint256);

    // This should return the principal token address (eg DAI)
    function getPrincipalAddress() external view returns (address);

    // View function which quotes how many principal tokens would be returned if x
    // fERC20 tokens are burned
    function quoteMintFToken(uint256 _tokenAmount, uint256 duration) external view returns (uint256);

    // View function which quotes how many principal tokens would be returned if x
    // fERC20 tokens are burned
    // IMPORTANT NOTE: This should utilise bootstrap tokens if they exist
    // bootstrapped tokens are any principal tokens that exist within the smart contract
    function quoteBurnFToken(uint256 _tokenAmount) external view returns (uint256);

    // The function to set the fERC20 address within the strategy
    function setFTokenAddress(address _fTokenAddress) external;

    // This should return what the maximum stake duration is
    function getMaxStakeDuration() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IUserIncentive {
    event RewardClaimed(address _rewardToken, address indexed _address);

    // This will be called by the Strategy to claim rewards for the user
    // This should be permissioned such that only the Strategy address can call
    function claimReward(uint256 _fERC20Burned, address _yieldTo) external;

    // This is a view function to determine how many reward tokens will be paid out
    // providing ??? fERC20 tokens are burned
    function quoteReward(uint256 _fERC20Burned) external view returns (uint256);

    // Administrator: setting the reward ratio
    function setRewardRatio(uint256 _ratio) external;

    // Administrator: adding the reward tokens
    function addRewardTokens(uint256 _tokenAmount) external;

    // Administrator: depositing the reward tokens
    function depositReward(
        address _rewardTokenAddress,
        uint256 _tokenAmount,
        uint256 _ratio
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IFlashFToken {
    function mint(address account, uint256 amount) external;

    function burnFrom(address from, uint256 amount) external;

    function decimals() external returns (uint8);
}

// SPDX-License-Identifier: UNLICENSED
// !! THIS FILE WAS AUTOGENERATED BY abi-to-sol v0.6.6. SEE SOURCE BELOW. !!
pragma solidity ^0.8.4;

interface IRewardsController {
    event Accrued(
        address indexed asset,
        address indexed reward,
        address indexed user,
        uint256 assetIndex,
        uint256 userIndex,
        uint256 rewardsAccrued
    );
    event AssetConfigUpdated(
        address indexed asset,
        address indexed reward,
        uint256 oldEmission,
        uint256 newEmission,
        uint256 oldDistributionEnd,
        uint256 newDistributionEnd,
        uint256 assetIndex
    );
    event ClaimerSet(address indexed user, address indexed claimer);
    event EmissionManagerUpdated(address indexed oldEmissionManager, address indexed newEmissionManager);
    event RewardOracleUpdated(address indexed reward, address indexed rewardOracle);
    event RewardsClaimed(
        address indexed user,
        address indexed reward,
        address indexed to,
        address claimer,
        uint256 amount
    );
    event TransferStrategyInstalled(address indexed reward, address indexed transferStrategy);

    function REVISION() external view returns (uint256);

    function claimAllRewards(address[] memory assets, address to)
        external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts);

    function claimAllRewardsOnBehalf(
        address[] memory assets,
        address user,
        address to
    ) external returns (address[] memory rewardsList, uint256[] memory claimedAmounts);

    function claimAllRewardsToSelf(address[] memory assets)
        external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts);

    function claimRewards(
        address[] memory assets,
        uint256 amount,
        address to,
        address reward
    ) external returns (uint256);

    function claimRewardsOnBehalf(
        address[] memory assets,
        uint256 amount,
        address user,
        address to,
        address reward
    ) external returns (uint256);

    function claimRewardsToSelf(
        address[] memory assets,
        uint256 amount,
        address reward
    ) external returns (uint256);

    function configureAssets(RewardsDataTypes.RewardsConfigInput[] memory config) external;

    function getAllUserRewards(address[] memory assets, address user)
        external
        view
        returns (address[] memory rewardsList, uint256[] memory unclaimedAmounts);

    function getAssetDecimals(address asset) external view returns (uint8);

    function getClaimer(address user) external view returns (address);

    function getDistributionEnd(address asset, address reward) external view returns (uint256);

    function getEmissionManager() external view returns (address);

    function getRewardOracle(address reward) external view returns (address);

    function getRewardsByAsset(address asset) external view returns (address[] memory);

    function getRewardsData(address asset, address reward)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    function getRewardsList() external view returns (address[] memory);

    function getTransferStrategy(address reward) external view returns (address);

    function getUserAccruedRewards(address user, address reward) external view returns (uint256);

    function getUserAssetIndex(
        address user,
        address asset,
        address reward
    ) external view returns (uint256);

    function getUserRewards(
        address[] memory assets,
        address user,
        address reward
    ) external view returns (uint256);

    function handleAction(
        address user,
        uint256 totalSupply,
        uint256 userBalance
    ) external;

    function initialize(address emissionManager) external;

    function setClaimer(address user, address caller) external;

    function setDistributionEnd(
        address asset,
        address reward,
        uint32 newDistributionEnd
    ) external;

    function setEmissionManager(address emissionManager) external;

    function setEmissionPerSecond(
        address asset,
        address[] memory rewards,
        uint88[] memory newEmissionsPerSecond
    ) external;

    function setRewardOracle(address reward, address rewardOracle) external;

    function setTransferStrategy(address reward, address transferStrategy) external;
}

interface RewardsDataTypes {
    struct RewardsConfigInput {
        uint88 emissionPerSecond;
        uint256 totalSupply;
        uint32 distributionEnd;
        address asset;
        address reward;
        address transferStrategy;
        address rewardOracle;
    }
}

// THIS FILE WAS AUTOGENERATED FROM THE FOLLOWING ABI JSON:
/*
[{"inputs":[{"internalType":"address","name":"emissionManager","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"asset","type":"address"},{"indexed":true,"internalType":"address","name":"reward","type":"address"},{"indexed":true,"internalType":"address","name":"user","type":"address"},{"indexed":false,"internalType":"uint256","name":"assetIndex","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"userIndex","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"rewardsAccrued","type":"uint256"}],"name":"Accrued","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"asset","type":"address"},{"indexed":true,"internalType":"address","name":"reward","type":"address"},{"indexed":false,"internalType":"uint256","name":"oldEmission","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"newEmission","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"oldDistributionEnd","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"newDistributionEnd","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"assetIndex","type":"uint256"}],"name":"AssetConfigUpdated","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"user","type":"address"},{"indexed":true,"internalType":"address","name":"claimer","type":"address"}],"name":"ClaimerSet","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"oldEmissionManager","type":"address"},{"indexed":true,"internalType":"address","name":"newEmissionManager","type":"address"}],"name":"EmissionManagerUpdated","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"reward","type":"address"},{"indexed":true,"internalType":"address","name":"rewardOracle","type":"address"}],"name":"RewardOracleUpdated","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"user","type":"address"},{"indexed":true,"internalType":"address","name":"reward","type":"address"},{"indexed":true,"internalType":"address","name":"to","type":"address"},{"indexed":false,"internalType":"address","name":"claimer","type":"address"},{"indexed":false,"internalType":"uint256","name":"amount","type":"uint256"}],"name":"RewardsClaimed","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"reward","type":"address"},{"indexed":true,"internalType":"address","name":"transferStrategy","type":"address"}],"name":"TransferStrategyInstalled","type":"event"},{"inputs":[],"name":"REVISION","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address[]","name":"assets","type":"address[]"},{"internalType":"address","name":"to","type":"address"}],"name":"claimAllRewards","outputs":[{"internalType":"address[]","name":"rewardsList","type":"address[]"},{"internalType":"uint256[]","name":"claimedAmounts","type":"uint256[]"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address[]","name":"assets","type":"address[]"},{"internalType":"address","name":"user","type":"address"},{"internalType":"address","name":"to","type":"address"}],"name":"claimAllRewardsOnBehalf","outputs":[{"internalType":"address[]","name":"rewardsList","type":"address[]"},{"internalType":"uint256[]","name":"claimedAmounts","type":"uint256[]"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address[]","name":"assets","type":"address[]"}],"name":"claimAllRewardsToSelf","outputs":[{"internalType":"address[]","name":"rewardsList","type":"address[]"},{"internalType":"uint256[]","name":"claimedAmounts","type":"uint256[]"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address[]","name":"assets","type":"address[]"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"address","name":"reward","type":"address"}],"name":"claimRewards","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address[]","name":"assets","type":"address[]"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"address","name":"user","type":"address"},{"internalType":"address","name":"to","type":"address"},{"internalType":"address","name":"reward","type":"address"}],"name":"claimRewardsOnBehalf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address[]","name":"assets","type":"address[]"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"address","name":"reward","type":"address"}],"name":"claimRewardsToSelf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"components":[{"internalType":"uint88","name":"emissionPerSecond","type":"uint88"},{"internalType":"uint256","name":"totalSupply","type":"uint256"},{"internalType":"uint32","name":"distributionEnd","type":"uint32"},{"internalType":"address","name":"asset","type":"address"},{"internalType":"address","name":"reward","type":"address"},{"internalType":"contract ITransferStrategyBase","name":"transferStrategy","type":"address"},{"internalType":"contract IEACAggregatorProxy","name":"rewardOracle","type":"address"}],"internalType":"struct RewardsDataTypes.RewardsConfigInput[]","name":"config","type":"tuple[]"}],"name":"configureAssets","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address[]","name":"assets","type":"address[]"},{"internalType":"address","name":"user","type":"address"}],"name":"getAllUserRewards","outputs":[{"internalType":"address[]","name":"rewardsList","type":"address[]"},{"internalType":"uint256[]","name":"unclaimedAmounts","type":"uint256[]"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"}],"name":"getAssetDecimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"user","type":"address"}],"name":"getClaimer","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"address","name":"reward","type":"address"}],"name":"getDistributionEnd","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getEmissionManager","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"reward","type":"address"}],"name":"getRewardOracle","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"}],"name":"getRewardsByAsset","outputs":[{"internalType":"address[]","name":"","type":"address[]"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"address","name":"reward","type":"address"}],"name":"getRewardsData","outputs":[{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getRewardsList","outputs":[{"internalType":"address[]","name":"","type":"address[]"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"reward","type":"address"}],"name":"getTransferStrategy","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"user","type":"address"},{"internalType":"address","name":"reward","type":"address"}],"name":"getUserAccruedRewards","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"user","type":"address"},{"internalType":"address","name":"asset","type":"address"},{"internalType":"address","name":"reward","type":"address"}],"name":"getUserAssetIndex","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address[]","name":"assets","type":"address[]"},{"internalType":"address","name":"user","type":"address"},{"internalType":"address","name":"reward","type":"address"}],"name":"getUserRewards","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"user","type":"address"},{"internalType":"uint256","name":"totalSupply","type":"uint256"},{"internalType":"uint256","name":"userBalance","type":"uint256"}],"name":"handleAction","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"emissionManager","type":"address"}],"name":"initialize","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"user","type":"address"},{"internalType":"address","name":"caller","type":"address"}],"name":"setClaimer","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"address","name":"reward","type":"address"},{"internalType":"uint32","name":"newDistributionEnd","type":"uint32"}],"name":"setDistributionEnd","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"emissionManager","type":"address"}],"name":"setEmissionManager","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"asset","type":"address"},{"internalType":"address[]","name":"rewards","type":"address[]"},{"internalType":"uint88[]","name":"newEmissionsPerSecond","type":"uint88[]"}],"name":"setEmissionPerSecond","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"reward","type":"address"},{"internalType":"contract IEACAggregatorProxy","name":"rewardOracle","type":"address"}],"name":"setRewardOracle","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"reward","type":"address"},{"internalType":"contract ITransferStrategyBase","name":"transferStrategy","type":"address"}],"name":"setTransferStrategy","outputs":[],"stateMutability":"nonpayable","type":"function"}]
*/

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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}