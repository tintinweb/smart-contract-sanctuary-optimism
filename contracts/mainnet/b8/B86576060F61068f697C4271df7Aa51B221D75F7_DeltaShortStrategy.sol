// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// standard strategy interface
import "../interfaces/IStrategy.sol";

// Libraries
import {Vault} from "../libraries/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StrandsLyraVault} from "../core/StrandsLyraVault.sol";
import {DecimalMath} from "@lyrafinance/protocol/contracts/synthetix/DecimalMath.sol";
import {SignedDecimalMath} from "@lyrafinance/protocol/contracts/synthetix/SignedDecimalMath.sol";
import {OwnableAdmins} from "../core/OwnableAdmins.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "hardhat/console.sol";

// StrategyBase to inherit
import {StrategyBase} from "./StrategyBase.sol";

contract DeltaShortStrategy is StrategyBase, IStrategy {
  using DecimalMath for uint;
  using SignedDecimalMath for int;

  // Example parameters for a delta short strategy
  struct DeltaShortStrategyDetail {
    uint minTimeToExpiry; // minimum board expiry
    uint maxTimeToExpiry; // maximum board expiry
    int targetDelta; // ideal option delta to trade
    uint maxDeltaGap; // max diff between targetDelta and option delta
    uint minVol; // min option volatility required
    uint maxVol; // max option volatility required
    uint size; // amount of options to sell per StrandsLyraVault.trade()
    uint minTradeInterval; // min seconds between StrandsLyraVault.trade() calls
    uint maxVolVariance; // max deviation from GWAV vol and option volatility
    uint gwavPeriod; // gwav period used when calculating GWAV vol
    uint collatBuffer; // multiple of vaultAdapter.minCollateral(): 1.1 -> 110% * minCollat
    uint collatPercent; // partial collateral: 0.9 -> 90% * fullCollat
  }

  DeltaShortStrategyDetail public strategyDetail;
  uint public activeExpiry;

  ///////////
  // ADMIN //
  ///////////

  constructor(StrandsLyraVault _vault, OptionType _optionType) StrategyBase(_vault, _optionType) {}

  /**
   * @dev update the strategy detail for the new round.
   */
  function setStrategyDetail(DeltaShortStrategyDetail memory _deltaStrategy) external onlyOwner {
    (, , , , , , , bool roundInProgress) = vault.vaultState();
    require(!roundInProgress, "cannot change strategy if round is active");
    strategyDetail = _deltaStrategy;
  }

  /**
   * @dev set the board id that will be traded for the next round
   * @param boardId lyra board Id.
   */
  function setBoard(uint boardId) external onlyVault {
    Board memory board = _getBoard(boardId);
    require(_isValidExpiry(board.expiry), "invalid board");
    activeExpiry = board.expiry;
  }

  ///////////////////
  // VAULT ACTIONS //
  ///////////////////

  /**
   * @dev convert premium in quote asset into collateral asset and send it back to the vault.
   */
  function returnFundsAndClearStrikes() external onlyVault {
    // exchange asset back to collateral asset and send it back to the vault
    _returnFundsToVault();

    // keep internal storage data on old strikes and positions ids
    _clearAllActiveStrikes();
  }

  /**
   * @notice Sell a fixed amount of options and collect premium
   * @dev the vault should pass in a strike id, and the strategy would verify if the strike is valid on-chain.
   * @param strikeId lyra strikeId to trade
   * @param lyraRewardRecipient address to receive trading reward. This need to be whitelisted
   * @return positionId
   * @return premiumReceived
   */
  function doTrade(uint strikeId, address lyraRewardRecipient)
    external
    onlyVault
    returns (
      uint positionId,
      uint premiumReceived,
      uint collateralToAdd
    )
  {
    // validate trade
    require(
      lastTradeTimestamp[strikeId] + strategyDetail.minTradeInterval <= block.timestamp,
      "min time interval not passed"
    );
    require(_isValidVolVariance(strikeId), "vol variance exceeded");

    Strike memory strike = _getStrikes(_toDynamic(strikeId))[0];
    require(isValidStrike(strike), "invalid strike");

    uint setCollateralTo;
    (collateralToAdd, setCollateralTo) = getRequiredCollateral(strike);

    require(
      collateralAsset.transferFrom(address(vault), address(this), collateralToAdd),
      "collateral transfer from vault failed");

    (positionId, premiumReceived) = _sellStrike(strike, setCollateralTo, lyraRewardRecipient);
  }

  /**
   * @dev calculate required collateral to add in the next trade.
   * sell size is fixed as strategyDetail.size
   * only add collateral if the additional sell will make the position out of buffer range
   * never remove collateral from an existing position
   */
  function getRequiredCollateral(Strike memory strike)
    public
    view
    returns (uint collateralToAdd, uint setCollateralTo)
  {
    uint sellAmount = strategyDetail.size;
    ExchangeRateParams memory exchangeParams = _getExchangeParams();

    // get existing position info if active
    uint existingAmount = 0;
    uint existingCollateral = 0;
    if (_isActiveStrike(strike.id)) {
      OptionPosition memory position = _getPositions(_toDynamic(strikeToPositionId[strike.id]))[0];
      existingCollateral = position.collateral;
      existingAmount = position.amount;
    }

    // gets minBufferCollat for the whole position
    uint minBufferCollateral = _getBufferCollateral(
      strike.strikePrice,
      strike.expiry,
      exchangeParams.spotPrice,
      existingAmount + sellAmount
    );

    // get targetCollat for this trade instance
    // prevents vault from adding excess collat just to meet targetCollat
    uint targetCollat = existingCollateral +
      _getFullCollateral(strike.strikePrice, sellAmount).multiplyDecimal(strategyDetail.collatPercent);

    // if excess collateral, keep in position to encourage more option selling
    setCollateralTo = _max(_max(minBufferCollateral, targetCollat), existingCollateral);

    // existingCollateral is never > setCollateralTo
    collateralToAdd = setCollateralTo - existingCollateral;
  }

  /**
   * @dev perform the trade
   * @param strike strike detail
   * @param setCollateralTo target collateral amount
   * @param lyraRewardRecipient address to receive lyra trading reward
   * @return positionId
   * @return premiumReceived
   */
  function _sellStrike(
    Strike memory strike,
    uint setCollateralTo, 
    address lyraRewardRecipient
  ) internal returns (uint, uint) {
    // get minimum expected premium based on minIv
    uint minExpectedPremium = _getPremiumLimit(strike, strategyDetail.minVol, strategyDetail.size);
    // perform trade
    TradeResult memory result = _openPosition(
      TradeInputParameters({
        strikeId: strike.id,
        positionId: strikeToPositionId[strike.id],
        iterations: 3,
        optionType: optionType,
        amount: strategyDetail.size,
        setCollateralTo: setCollateralTo,
        minTotalCost: minExpectedPremium,
        maxTotalCost: type(uint).max,
        rewardRecipient: lyraRewardRecipient // set to zero address if don't want to wait for whitelist
      })
    );
    lastTradeTimestamp[strike.id] = block.timestamp;

    // update active strikes
    _addActiveStrike(strike.id, result.positionId);

    require(result.totalCost >= minExpectedPremium, "premium received is below min expected premium");

    return (result.positionId, result.totalCost);
  }

  /**
   * @dev use premium in strategy to reduce position size if collateral ratio is out of range
   */
  function reducePosition(
    uint positionId,
    uint closeAmount,
    address lyraRewardRecipient
  ) external onlyVault {
    OptionPosition memory position = _getPositions(_toDynamic(positionId))[0];
    Strike memory strike = _getStrikes(_toDynamic(position.strikeId))[0];

    require(strikeToPositionId[position.strikeId] == positionId, "invalid positionId");

    // only allows closing if collat < minBuffer
    require(
      closeAmount <= getAllowedCloseAmount(position, strike.strikePrice, strike.expiry),
      "amount exceeds allowed close amount"
    );

    // closes excess position with premium balance
    uint maxExpectedPremium = _getPremiumLimit(strike, strategyDetail.maxVol, strategyDetail.size);
    _formatedCloseOrForceClosePosition(position, closeAmount, 0, maxExpectedPremium, lyraRewardRecipient);

    // return closed collateral amount
    if (_isBaseCollat()) {
      uint currentBal = baseAsset.balanceOf(address(this));
      baseAsset.transfer(address(vault), currentBal);
    } else {
      // quote collateral
      quoteAsset.transfer(address(vault), closeAmount);
    }
  }

  /**
   * @dev close all outstanding positions regardless of collat and send funds back to vault
   */
  function emergencyCloseAll(address lyraRewardRecipient) external onlyVault {
    // the vault might not hold enough sUSD to close all positions, will need someone to tapup before doing so.
    console.log("emergencyCloseAll activeStrikeIds.length",activeStrikeIds.length);
    for (uint i = 0; i < activeStrikeIds.length; i++) {
      uint strikeId = activeStrikeIds[i];
      console.log("strikeId=",strikeId);

      OptionPosition memory position = _getPositions(_toDynamic(strikeToPositionId[strikeId]))[0];
      console.log("positionId=",position.positionId);
      console.log("positionAmount=",position.amount);
      // revert if position state is not settled
      _formatedCloseOrForceClosePosition(position, position.amount, 0, type(uint).max, lyraRewardRecipient);

      delete strikeToPositionId[strikeId];
      delete lastTradeTimestamp[strikeId];
    }
    _clearAllActiveStrikes();
    _returnFundsToVault();
  }

  /**
   * @dev calculates the position amount required to stay above the buffer collateral
   */
  function getAllowedCloseAmount(
    OptionPosition memory position,
    uint strikePrice,
    uint strikeExpiry
  ) public view returns (uint closeAmount) {
    ExchangeRateParams memory exchangeParams = _getExchangeParams();
    uint minCollatPerAmount = _getBufferCollateral(strikePrice, strikeExpiry, exchangeParams.spotPrice, 1e18);

    closeAmount = position.collateral < minCollatPerAmount.multiplyDecimal(position.amount)
      ? position.amount - position.collateral.divideDecimal(minCollatPerAmount)
      : 0;
  }

  /////////////////////////////
  // Trade Parameter Helpers //
  /////////////////////////////

  function _getFullCollateral(uint strikePrice, uint amount) internal view returns (uint fullCollat) {
    // calculate required collat based on collatBuffer and collatPercent
    fullCollat = _isBaseCollat() ? amount : amount.multiplyDecimal(strikePrice);
  }

  /**
   * @dev get amount of collateral needed for shorting {amount} of strike, according to the strategy
   */
  function _getBufferCollateral(
    uint strikePrice,
    uint expiry,
    uint spotPrice,
    uint amount
  ) internal view returns (uint) {
    uint minCollat = _getMinCollateral(optionType, strikePrice, expiry, spotPrice, amount);
    uint minCollatWithBuffer = minCollat.multiplyDecimal(strategyDetail.collatBuffer);

    uint fullCollat = _getFullCollateral(strikePrice, amount);

    return _min(minCollatWithBuffer, fullCollat);
  }

  /////////////////
  // Validation ///
  /////////////////

  /**
   * @dev verify if the strike is valid for the strategy
   * @return isValid true if vol is withint [minVol, maxVol] and delta is within targetDelta +- maxDeltaGap
   */
  function isValidStrike(Strike memory strike) public view returns (bool isValid) {
    if (activeExpiry != strike.expiry) {
      return false;
    }

    uint[] memory strikeId = _toDynamic(strike.id);
    uint vol = _getVols(strikeId)[0];
    int callDelta = _getDeltas(strikeId)[0];
    int delta = _isCall() ? callDelta : callDelta - SignedDecimalMath.UNIT;
    uint deltaGap = _abs(strategyDetail.targetDelta - delta);
    console.log("vol=%s/100",vol/10**16);
    console.log("deltaGap=%s/10000",deltaGap/10**14);
    return vol >= strategyDetail.minVol && vol <= strategyDetail.maxVol && deltaGap < strategyDetail.maxDeltaGap;
  }

  /**
   * @dev Check if the vol variance for the given strike is within certain range
   */
  function _isValidVolVariance(uint strikeId) internal view returns (bool isValid) {
    uint volGWAV = _volGWAV(strikeId, strategyDetail.gwavPeriod);
    uint volSpot = _getVols(_toDynamic(strikeId))[0];

    uint volDiff = (volGWAV >= volSpot) ? volGWAV - volSpot : volSpot - volGWAV;

    return isValid = volDiff < strategyDetail.maxVolVariance;
  }

  /**
   * @dev check if the expiry of the board is valid according to the strategy
   */
  function _isValidExpiry(uint expiry) public view returns (bool isValid) {
    uint secondsToExpiry = _getSecondsToExpiry(expiry);
    // todo: `minTimeToExpiry` and `maxTimeToExpiry` must be changed prior to
    //       the start of a new round
    isValid = (secondsToExpiry >= strategyDetail.minTimeToExpiry && secondsToExpiry <= strategyDetail.maxTimeToExpiry);
  }

}

//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

interface IStrategy {
  function activeExpiry() external returns (uint);

  function setBoard(uint boardId) external;

  function doTrade(uint strikeId, address rewardRecipient)
    external
    returns (
      uint positionId,
      uint premium,
      uint collateralAdded
    );

  function reducePosition(
    uint positionId,
    uint closeAmount,
    address rewardRecipient
  ) external;

  function emergencyCloseAll(address lyraRewardRecipient) external;

  function returnFundsAndClearStrikes() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library Vault {
  /************************************************
   *  IMMUTABLES & CONSTANTS
   ***********************************************/

  // Fees are 6-decimal places. For example: 20 * 10**6 = 20%
  uint internal constant FEE_MULTIPLIER = 10**6;

  uint internal constant ROUND_DELAY = 1 minutes;

  struct VaultParams {
    // Token decimals for vault shares
    uint8 decimals;
    // Vault cap
    uint104 cap;
    // Asset used in Theta / Delta Vault
    address asset;
  }

  struct VaultState {
    // 32 byte slot 1
    //  Current round number. `round` represents the number of `period`s elapsed.
    uint16 round;
    // Amount that is currently locked for the strategy
    uint104 lockedAmount;
    // Amount that was locked for strategy in the previous round
    // used for calculating performance fee deduction
    uint104 lastLockedAmount;
    // locked amount left to be used for collateral;
    uint lockedAmountLeft;
    // 32 byte slot 2
    // Stores the total tally of how much of `asset` there is
    // to be used to mint Vault tokens
    uint128 totalPending;
    // Amount locked for scheduled withdrawals;
    uint128 queuedWithdrawShares;
    // The timestamp next round will be ready to start
    uint nextRoundReadyTimestamp;
    // true if the current round is in progress, false if the round is idle
    bool roundInProgress;
  }

  struct DepositReceipt {
    // Maximum of 65535 rounds. Assuming 1 round is 7 days, maximum is 1256 years.
    uint16 round;
    // Deposit amount, max 20,282,409,603,651 or 20 trillion ETH deposit
    uint104 amount;
    // Unredeemed shares balance
    uint128 unredeemedShares;
  }

  struct Withdrawal {
    // Maximum of 65535 rounds. Assuming 1 round is 7 days, maximum is 1256 years.
    uint16 round;
    // Number of shares withdrawn
    uint128 shares;
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
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
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseVault} from "./BaseVault.sol";
import {OwnableAdmins} from "./OwnableAdmins.sol";
import {Vault} from "../libraries/Vault.sol";

import {IStrategy} from "../interfaces/IStrategy.sol";
import "hardhat/console.sol";

/// @notice StrandsLyraVault help users run option-selling strategies on Lyra AMM.
contract StrandsLyraVault is OwnableAdmins, Ownable, BaseVault {
  IERC20 public immutable premiumAsset;
  IERC20 public immutable collateralAsset;

  IStrategy public strategy;
  address public lyraRewardRecipient;

  // Amount locked for scheduled withdrawals last week;
  uint public lastQueuedWithdrawAmount;
  // % of funds to be used for weekly option purchase
  uint public optionAllocation;

  event StrategyUpdated(address strategy);

  event Trade(address user, uint positionId, uint premium, uint capitalUsed);

  event RoundStarted(uint16 roundId, uint104 lockAmount);

  event RoundClosed(uint16 roundId, uint104 lockAmount);

  constructor(
    address _susd,
    address _feeRecipient,
    uint _roundDuration,
    string memory _tokenName,
    string memory _tokenSymbol,
    Vault.VaultParams memory _vaultParams
  ) BaseVault(_feeRecipient, _roundDuration, _tokenName, _tokenSymbol, _vaultParams) {
    premiumAsset = IERC20(_susd);
    collateralAsset = IERC20(_vaultParams.asset);
  }

  /// @dev set strategy contract. This function can only be called by owner.
  /// @param _strategy new strategy contract address
  function setStrategy(address _strategy) external onlyAdmins {
    if (address(strategy) != address(0)) {
      collateralAsset.approve(address(strategy), 0);
    }

    strategy = IStrategy(_strategy);
    collateralAsset.approve(_strategy, type(uint).max);
    emit StrategyUpdated(_strategy);
  }

  /// @dev anyone can trigger a trade
  /// @param strikeId the strike id to sell
  function trade(uint strikeId) external {
    require(vaultState.roundInProgress, "round closed");
    // perform trade through strategy
    (uint positionId, uint premiumReceived, uint capitalUsed) = strategy.doTrade(strikeId, lyraRewardRecipient);

    // update the remaining locked amount
    vaultState.lockedAmountLeft = vaultState.lockedAmountLeft - capitalUsed;
    
    // todo: udpate events
    emit Trade(msg.sender, positionId, premiumReceived, capitalUsed);
  }

  /// @dev anyone close part of the position with premium made by the strategy if a position is dangerous
  /// @param positionId the positiion to close
  function reducePosition(uint positionId, uint closeAmount) external {
    strategy.reducePosition(positionId, closeAmount, lyraRewardRecipient);
  }

  /// @dev close the current round, enable user to deposit for the next round
  function closeRound() external {
    require(strategy.activeExpiry() < block.timestamp, "cannot close round if board not expired");
    require(vaultState.roundInProgress, "round closed");

    uint104 lockAmount = vaultState.lockedAmount;
    vaultState.lastLockedAmount = lockAmount;
    vaultState.lockedAmountLeft = 0;
    vaultState.lockedAmount = 0;
    vaultState.nextRoundReadyTimestamp = block.timestamp + Vault.ROUND_DELAY;
    vaultState.roundInProgress = false;

    // won't be able to close if positions are not settled
    strategy.returnFundsAndClearStrikes();

    emit RoundClosed(vaultState.round, lockAmount);
  }

  /// @dev Close the current round, enable user to deposit for the next round
  //       Can call multiple times before round starts to close all positions
  function emergencyCloseRound() external onlyAdmins {
    require(vaultState.roundInProgress, "round closed");

    uint104 lockAmount = vaultState.lockedAmount;
    vaultState.lastLockedAmount = lockAmount;
    vaultState.lockedAmountLeft = 0;
    vaultState.lockedAmount = 0;
    vaultState.nextRoundReadyTimestamp = block.timestamp + Vault.ROUND_DELAY;
    vaultState.roundInProgress = false;

    strategy.emergencyCloseAll(lyraRewardRecipient);
    emit RoundClosed(vaultState.round, lockAmount);
  }

  /// @notice start the next round
  /// @param boardId board id (asset + expiry) for next round.
  function startNextRound(uint boardId) external onlyAdmins {
    require(!vaultState.roundInProgress, "round in progress");
    require(block.timestamp > vaultState.nextRoundReadyTimestamp, "Delay between rounds not elapsed");

    strategy.setBoard(boardId);

    (uint lockedBalance, uint queuedWithdrawAmount) = _rollToNextRound(lastQueuedWithdrawAmount);

    vaultState.lockedAmount = uint104(lockedBalance);
    vaultState.lockedAmountLeft = lockedBalance;
    vaultState.roundInProgress = true;
    lastQueuedWithdrawAmount = queuedWithdrawAmount;

    emit RoundStarted(vaultState.round, uint104(lockedBalance));
  }

  /// @notice set set new address to receive Lyra trading reward on behalf of the vault
  /// @param recipient recipient address
  function setLyraRewardRecipient(address recipient) external onlyAdmins {
    lyraRewardRecipient = recipient;
  }
}

//SPDX-License-Identifier: MIT
//
//Copyright (c) 2019 Synthetix
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

pragma solidity ^0.8.9;

/**
 * @title DecimalMath
 * @author Lyra
 * @dev Modified synthetix SafeDecimalMath to include internal arithmetic underflow/overflow.
 * @dev https://docs.synthetix.io/contracts/source/libraries/SafeDecimalMath/
 */

library DecimalMath {
  /* Number of decimal places in the representations. */
  uint8 public constant decimals = 18;
  uint8 public constant highPrecisionDecimals = 27;

  /* The number representing 1.0. */
  uint public constant UNIT = 10**uint(decimals);

  /* The number representing 1.0 for higher fidelity numbers. */
  uint public constant PRECISE_UNIT = 10**uint(highPrecisionDecimals);
  uint private constant UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR = 10**uint(highPrecisionDecimals - decimals);

  /**
   * @return Provides an interface to UNIT.
   */
  function unit() external pure returns (uint) {
    return UNIT;
  }

  /**
   * @return Provides an interface to PRECISE_UNIT.
   */
  function preciseUnit() external pure returns (uint) {
    return PRECISE_UNIT;
  }

  /**
   * @return The result of multiplying x and y, interpreting the operands as fixed-point
   * decimals.
   *
   * @dev A unit factor is divided out after the product of x and y is evaluated,
   * so that product must be less than 2**256. As this is an integer division,
   * the internal division always rounds down. This helps save on gas. Rounding
   * is more expensive on gas.
   */
  function multiplyDecimal(uint x, uint y) internal pure returns (uint) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    return (x * y) / UNIT;
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of the specified precision unit.
   *
   * @dev The operands should be in the form of a the specified unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function _multiplyDecimalRound(
    uint x,
    uint y,
    uint precisionUnit
  ) private pure returns (uint) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    uint quotientTimesTen = (x * y) / (precisionUnit / 10);

    if (quotientTimesTen % 10 >= 5) {
      quotientTimesTen += 10;
    }

    return quotientTimesTen / 10;
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a precise unit.
   *
   * @dev The operands should be in the precise unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRoundPrecise(uint x, uint y) internal pure returns (uint) {
    return _multiplyDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a standard unit.
   *
   * @dev The operands should be in the standard unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRound(uint x, uint y) internal pure returns (uint) {
    return _multiplyDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is a high
   * precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and UNIT must be less than 2**256. As
   * this is an integer division, the result is always rounded down.
   * This helps save on gas. Rounding is more expensive on gas.
   */
  function divideDecimal(uint x, uint y) internal pure returns (uint) {
    /* Reintroduce the UNIT factor that will be divided out by y. */
    return (x * UNIT) / y;
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * decimal in the precision unit specified in the parameter.
   *
   * @dev y is divided after the product of x and the specified precision unit
   * is evaluated, so the product of x and the specified precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function _divideDecimalRound(
    uint x,
    uint y,
    uint precisionUnit
  ) private pure returns (uint) {
    uint resultTimesTen = (x * (precisionUnit * 10)) / y;

    if (resultTimesTen % 10 >= 5) {
      resultTimesTen += 10;
    }

    return resultTimesTen / 10;
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * standard precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and the standard precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRound(uint x, uint y) internal pure returns (uint) {
    return _divideDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * high precision decimal.
   *
   * @dev y is divided after the product of x and the high precision unit
   * is evaluated, so the product of x and the high precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRoundPrecise(uint x, uint y) internal pure returns (uint) {
    return _divideDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @dev Convert a standard decimal representation to a high precision one.
   */
  function decimalToPreciseDecimal(uint i) internal pure returns (uint) {
    return i * UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR;
  }

  /**
   * @dev Convert a high precision decimal to a standard decimal representation.
   */
  function preciseDecimalToDecimal(uint i) internal pure returns (uint) {
    uint quotientTimesTen = i / (UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR / 10);

    if (quotientTimesTen % 10 >= 5) {
      quotientTimesTen += 10;
    }

    return quotientTimesTen / 10;
  }
}

//SPDX-License-Identifier: MIT
//
//Copyright (c) 2019 Synthetix
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

pragma solidity ^0.8.9;

/**
 * @title SignedDecimalMath
 * @author Lyra
 * @dev Modified synthetix SafeSignedDecimalMath to include internal arithmetic underflow/overflow.
 * @dev https://docs.synthetix.io/contracts/source/libraries/safedecimalmath
 */
library SignedDecimalMath {
  /* Number of decimal places in the representations. */
  uint8 public constant decimals = 18;
  uint8 public constant highPrecisionDecimals = 27;

  /* The number representing 1.0. */
  int public constant UNIT = int(10**uint(decimals));

  /* The number representing 1.0 for higher fidelity numbers. */
  int public constant PRECISE_UNIT = int(10**uint(highPrecisionDecimals));
  int private constant UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR = int(10**uint(highPrecisionDecimals - decimals));

  /**
   * @return Provides an interface to UNIT.
   */
  function unit() external pure returns (int) {
    return UNIT;
  }

  /**
   * @return Provides an interface to PRECISE_UNIT.
   */
  function preciseUnit() external pure returns (int) {
    return PRECISE_UNIT;
  }

  /**
   * @dev Rounds an input with an extra zero of precision, returning the result without the extra zero.
   * Half increments round away from zero; positive numbers at a half increment are rounded up,
   * while negative such numbers are rounded down. This behaviour is designed to be consistent with the
   * unsigned version of this library (SafeDecimalMath).
   */
  function _roundDividingByTen(int valueTimesTen) private pure returns (int) {
    int increment;
    if (valueTimesTen % 10 >= 5) {
      increment = 10;
    } else if (valueTimesTen % 10 <= -5) {
      increment = -10;
    }
    return (valueTimesTen + increment) / 10;
  }

  /**
   * @return The result of multiplying x and y, interpreting the operands as fixed-point
   * decimals.
   *
   * @dev A unit factor is divided out after the product of x and y is evaluated,
   * so that product must be less than 2**256. As this is an integer division,
   * the internal division always rounds down. This helps save on gas. Rounding
   * is more expensive on gas.
   */
  function multiplyDecimal(int x, int y) internal pure returns (int) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    return (x * y) / UNIT;
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of the specified precision unit.
   *
   * @dev The operands should be in the form of a the specified unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function _multiplyDecimalRound(
    int x,
    int y,
    int precisionUnit
  ) private pure returns (int) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    int quotientTimesTen = (x * y) / (precisionUnit / 10);
    return _roundDividingByTen(quotientTimesTen);
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a precise unit.
   *
   * @dev The operands should be in the precise unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRoundPrecise(int x, int y) internal pure returns (int) {
    return _multiplyDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a standard unit.
   *
   * @dev The operands should be in the standard unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRound(int x, int y) internal pure returns (int) {
    return _multiplyDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is a high
   * precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and UNIT must be less than 2**256. As
   * this is an integer division, the result is always rounded down.
   * This helps save on gas. Rounding is more expensive on gas.
   */
  function divideDecimal(int x, int y) internal pure returns (int) {
    /* Reintroduce the UNIT factor that will be divided out by y. */
    return (x * UNIT) / y;
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * decimal in the precision unit specified in the parameter.
   *
   * @dev y is divided after the product of x and the specified precision unit
   * is evaluated, so the product of x and the specified precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function _divideDecimalRound(
    int x,
    int y,
    int precisionUnit
  ) private pure returns (int) {
    int resultTimesTen = (x * (precisionUnit * 10)) / y;
    return _roundDividingByTen(resultTimesTen);
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * standard precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and the standard precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRound(int x, int y) internal pure returns (int) {
    return _divideDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * high precision decimal.
   *
   * @dev y is divided after the product of x and the high precision unit
   * is evaluated, so the product of x and the high precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRoundPrecise(int x, int y) internal pure returns (int) {
    return _divideDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @dev Convert a standard decimal representation to a high precision one.
   */
  function decimalToPreciseDecimal(int i) internal pure returns (int) {
    return i * UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR;
  }

  /**
   * @dev Convert a high precision decimal to a standard decimal representation.
   */
  function preciseDecimalToDecimal(int i) internal pure returns (int) {
    int quotientTimesTen = i / (UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR / 10);
    return _roundDividingByTen(quotientTimesTen);
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";

error AdminNotFound(address oldAdmin);
//error CallerIsNotAdmin(address caller);
error IsZeroAddress(address zeroAddress);
error AddressAlreadyAdded(address newAdmin);
error IsLastRemainingAdmin(address finalAdmin);

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
abstract contract OwnableAdmins is Context {
  address[] private _admins;

  event AdminAdded(address indexed newAdmin);
  event AdminRemoved(address indexed oldAdmin);

  /**
   * @dev Initializes the contract setting the deployer as the initial owner.
   */
  constructor() {
    _addAdmin(_msgSender());
  }

  function isAdmin(address _isAdmin) public view virtual returns (bool, int) {
    address admin;
    uint index;
    int arrayLength = int(_admins.length);

    for (int i = 0; i < arrayLength; i++) {
      index = uint(i);
      admin = _admins[index];
      if (admin == _isAdmin) return (true, i);
    }

    return (false, -1);
  }

  modifier onlyAdmins() {
    (bool isAdmin_, int adminIndex) = isAdmin(_msgSender());
    require(isAdmin_ == true, "Caller is not Admin");
    _;
  }

  function removeAdmin(address oldAdmin) public virtual onlyAdmins {
    if (_admins.length == 1) revert IsLastRemainingAdmin(oldAdmin);
    (bool isAdmin_, int index) = isAdmin(oldAdmin);
    if (isAdmin_ == false) revert AdminNotFound(oldAdmin);
    if (isAdmin_ == true) {
      delete _admins[uint(index)];
      emit AdminRemoved(oldAdmin);
    }
  }

  function addAdmin(address newAdmin) public virtual onlyAdmins {
    if (newAdmin == address(0)) revert IsZeroAddress(newAdmin);
    (bool isAdmin_, ) = isAdmin(newAdmin);
    if (isAdmin_ == true) revert AddressAlreadyAdded(newAdmin);
    _addAdmin(newAdmin);
  }

  function _addAdmin(address newAdmin) internal virtual {
    _admins.push(newAdmin);
    emit AdminAdded(newAdmin);
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/math/Math.sol)

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
pragma solidity >= 0.4.22 <0.9.0;

library console {
	address constant CONSOLE_ADDRESS = address(0x000000000000000000636F6e736F6c652e6c6f67);

	function _sendLogPayload(bytes memory payload) private view {
		uint256 payloadLength = payload.length;
		address consoleAddress = CONSOLE_ADDRESS;
		assembly {
			let payloadStart := add(payload, 32)
			let r := staticcall(gas(), consoleAddress, payloadStart, payloadLength, 0, 0)
		}
	}

	function log() internal view {
		_sendLogPayload(abi.encodeWithSignature("log()"));
	}

	function logInt(int p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(int)", p0));
	}

	function logUint(uint p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
	}

	function logString(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function logBool(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function logAddress(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function logBytes(bytes memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
	}

	function logBytes1(bytes1 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
	}

	function logBytes2(bytes2 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
	}

	function logBytes3(bytes3 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
	}

	function logBytes4(bytes4 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
	}

	function logBytes5(bytes5 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
	}

	function logBytes6(bytes6 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
	}

	function logBytes7(bytes7 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
	}

	function logBytes8(bytes8 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
	}

	function logBytes9(bytes9 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
	}

	function logBytes10(bytes10 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
	}

	function logBytes11(bytes11 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
	}

	function logBytes12(bytes12 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
	}

	function logBytes13(bytes13 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
	}

	function logBytes14(bytes14 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
	}

	function logBytes15(bytes15 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
	}

	function logBytes16(bytes16 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
	}

	function logBytes17(bytes17 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
	}

	function logBytes18(bytes18 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
	}

	function logBytes19(bytes19 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
	}

	function logBytes20(bytes20 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
	}

	function logBytes21(bytes21 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
	}

	function logBytes22(bytes22 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
	}

	function logBytes23(bytes23 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
	}

	function logBytes24(bytes24 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
	}

	function logBytes25(bytes25 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
	}

	function logBytes26(bytes26 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
	}

	function logBytes27(bytes27 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
	}

	function logBytes28(bytes28 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
	}

	function logBytes29(bytes29 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
	}

	function logBytes30(bytes30 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
	}

	function logBytes31(bytes31 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
	}

	function logBytes32(bytes32 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
	}

	function log(uint p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
	}

	function log(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function log(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function log(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function log(uint p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint)", p0, p1));
	}

	function log(uint p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string)", p0, p1));
	}

	function log(uint p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool)", p0, p1));
	}

	function log(uint p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address)", p0, p1));
	}

	function log(string memory p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint)", p0, p1));
	}

	function log(string memory p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
	}

	function log(string memory p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
	}

	function log(string memory p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
	}

	function log(bool p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint)", p0, p1));
	}

	function log(bool p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
	}

	function log(bool p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
	}

	function log(bool p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
	}

	function log(address p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint)", p0, p1));
	}

	function log(address p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
	}

	function log(address p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
	}

	function log(address p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address)", p0, p1));
	}

	function log(uint p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint)", p0, p1, p2));
	}

	function log(uint p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string)", p0, p1, p2));
	}

	function log(uint p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool)", p0, p1, p2));
	}

	function log(uint p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address)", p0, p1, p2));
	}

	function log(uint p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint)", p0, p1, p2));
	}

	function log(uint p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string)", p0, p1, p2));
	}

	function log(uint p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool)", p0, p1, p2));
	}

	function log(uint p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address)", p0, p1, p2));
	}

	function log(uint p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint)", p0, p1, p2));
	}

	function log(uint p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string)", p0, p1, p2));
	}

	function log(uint p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool)", p0, p1, p2));
	}

	function log(uint p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
	}

	function log(string memory p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint)", p0, p1, p2));
	}

	function log(string memory p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
	}

	function log(string memory p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
	}

	function log(string memory p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
	}

	function log(bool p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint)", p0, p1, p2));
	}

	function log(bool p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string)", p0, p1, p2));
	}

	function log(bool p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool)", p0, p1, p2));
	}

	function log(bool p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
	}

	function log(bool p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint)", p0, p1, p2));
	}

	function log(bool p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
	}

	function log(bool p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
	}

	function log(bool p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
	}

	function log(bool p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint)", p0, p1, p2));
	}

	function log(bool p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
	}

	function log(bool p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
	}

	function log(bool p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
	}

	function log(address p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint)", p0, p1, p2));
	}

	function log(address p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string)", p0, p1, p2));
	}

	function log(address p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool)", p0, p1, p2));
	}

	function log(address p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address)", p0, p1, p2));
	}

	function log(address p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint)", p0, p1, p2));
	}

	function log(address p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
	}

	function log(address p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
	}

	function log(address p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
	}

	function log(address p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint)", p0, p1, p2));
	}

	function log(address p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
	}

	function log(address p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
	}

	function log(address p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
	}

	function log(address p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint)", p0, p1, p2));
	}

	function log(address p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
	}

	function log(address p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
	}

	function log(address p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
	}

	function log(uint p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3));
	}

}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Lyra
import {LyraAdapter} from "@lyrafinance/protocol/contracts/periphery/LyraAdapter.sol";

// Libraries
import {Vault} from "../libraries/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StrandsLyraVault} from "../core/StrandsLyraVault.sol";
import {DecimalMath} from "@lyrafinance/protocol/contracts/synthetix/DecimalMath.sol";
import {SignedDecimalMath} from "@lyrafinance/protocol/contracts/synthetix/SignedDecimalMath.sol";
import "hardhat/console.sol";

contract StrategyBase is LyraAdapter {
  using DecimalMath for uint;
  using SignedDecimalMath for int;

  StrandsLyraVault public immutable vault;
  OptionType public immutable optionType;

  /// @dev asset used as collateral in AMM to sell. Should be the same as vault asset
  IERC20 public collateralAsset;

  mapping(uint => uint) public lastTradeTimestamp;

  uint[] public activeStrikeIds;
  mapping(uint => uint) public strikeToPositionId;

  ///////////
  // ADMIN //
  ///////////

  modifier onlyVault() virtual {
    require(msg.sender == address(vault), "only Vault");
    _;
  }

  constructor(StrandsLyraVault _vault, OptionType _optionType) LyraAdapter() {
    vault = _vault;
    optionType = _optionType;
  }

  function initAdapter(
    address _lyraRegistry,
    address _optionMarket,
    address _curveSwap,
    address _feeCounter
  ) external onlyOwner {
    // set addresses for LyraAdapter
    setLyraAddresses(_lyraRegistry, _optionMarket, _curveSwap, _feeCounter);

    quoteAsset.approve(address(vault), type(uint).max);
    baseAsset.approve(address(vault), type(uint).max);
    collateralAsset = _isBaseCollat() ? IERC20(address(baseAsset)) : IERC20(address(quoteAsset));
  }

  ///////////////////
  // VAULT ACTIONS //
  ///////////////////

  /**
   * @dev exchange asset back to collateral asset and send it back to the vault
   * @dev override this function if you want to customize asset management flow
   */
  function _returnFundsToVault() internal virtual {
    ExchangeRateParams memory exchangeParams = _getExchangeParams();
    uint quoteBal = quoteAsset.balanceOf(address(this));

    if (_isBaseCollat()) {
      // exchange quote asset to base asset, and send base asset back to vault
      uint baseBal = baseAsset.balanceOf(address(this));
      uint minQuoteExpected = quoteBal.divideDecimal(exchangeParams.spotPrice).multiplyDecimal(
        DecimalMath.UNIT - exchangeParams.baseQuoteFeeRate
      );
      uint baseReceived = _exchangeFromExactQuote(quoteBal, minQuoteExpected);
      require(baseAsset.transfer(address(vault), baseBal + baseReceived), "failed to return funds from strategy");
    } else {
      // send quote balance directly
      require(quoteAsset.transfer(address(vault), quoteBal), "failed to return funds from strategy");
    }
  }

  /////////////////////////////
  // Trade Parameter Helpers //
  /////////////////////////////

  /**
   * @dev Automatically decide between close and forceClose
   * depending on whether deltaCutoff or tradingCutoff are crossed
   */

  function _formatedCloseOrForceClosePosition(
    OptionPosition memory position,
    uint closeAmount,
    uint minTotalCost,
    uint maxTotalCost,
    address lyraRewardRecipient
  ) internal {
    // closes excess position with premium balance

    // if it's a full close, take out our collateral as well.
    uint setCollateralTo = position.amount == closeAmount ? 0 : position.collateral;
    console.log("minTotalCost=",minTotalCost);
    console.log("maxTotalCost=",maxTotalCost);
    console.log("closeAmount=",closeAmount);
    TradeInputParameters memory tradeParams = TradeInputParameters({
      strikeId: position.strikeId,
      positionId: position.positionId,
      iterations: 3,
      optionType: optionType,
      amount: closeAmount,
      setCollateralTo: setCollateralTo,
      minTotalCost: minTotalCost,
      maxTotalCost: maxTotalCost,
      rewardRecipient: lyraRewardRecipient // set to zero address if don't want to wait for whitelist
    });

    // if forceClosed, will pay less competitive price to close position but bypasses Lyra delta/trading cutoffs
    TradeResult memory result = _closeOrForceClosePosition(tradeParams);
    require(result.totalCost <= maxTotalCost, "premium paid is above max expected premium");
  }

  /**
   * @dev get minimum premium that the vault should receive.
   * param listingId lyra option listing id
   * param size size of trade in Lyra standard sizes
   */
  function _getPremiumLimit(
    Strike memory strike,
    uint vol,
    uint size
  ) internal view returns (uint limitPremium) {
    ExchangeRateParams memory exchangeParams = _getExchangeParams();
    (uint callPremium, uint putPremium) = _getPurePremium(
      _getSecondsToExpiry(strike.expiry),
      vol,
      exchangeParams.spotPrice,
      strike.strikePrice
    );

    limitPremium = _isCall() ? callPremium.multiplyDecimal(size) : putPremium.multiplyDecimal(size);
  }

  //////////////////////////////
  // Active Strike Management //
  //////////////////////////////

  /**
   * @dev add strike id to activeStrikeIds array
   */
  function _addActiveStrike(uint strikeId, uint tradedPositionId) internal {
    if (!_isActiveStrike(strikeId)) {
      strikeToPositionId[strikeId] = tradedPositionId;
      activeStrikeIds.push(strikeId);
    }
  }

  /**
   * @dev add the last traded timestamp for a specific strike.
   */
  function _setLastTradedAt(uint strikeId, uint timestamp) internal {
    lastTradeTimestamp[strikeId] = timestamp;
  }

  /**
   * @dev remove position data opened in the current round.
   * this can only be called after the position is settled by lyra
   **/
  function _clearAllActiveStrikes() internal {
    if (activeStrikeIds.length != 0) {
      for (uint i = 0; i < activeStrikeIds.length; i++) {
        uint strikeId = activeStrikeIds[i];
        OptionPosition memory position = _getPositions(_toDynamic(strikeToPositionId[strikeId]))[0];
        // revert if position state is not settled
        require(position.state != PositionState.ACTIVE, "cannot clear active position");
        delete strikeToPositionId[strikeId];
        delete lastTradeTimestamp[strikeId];
      }
      delete activeStrikeIds;
    }
  }

  function _isActiveStrike(uint strikeId) internal view returns (bool isActive) {
    isActive = strikeToPositionId[strikeId] != 0;
  }

  //////////
  // Misc //
  //////////

  function getDeltas(uint[] memory strikeIds) external view returns (int[] memory callDeltas) {
    return _getDeltas(strikeIds);
  }

  function _isBaseCollat() internal view returns (bool isBase) {
    isBase = (optionType == OptionType.SHORT_CALL_BASE) ? true : false;
  }

  function _isCall() internal view returns (bool isCall) {
    isCall = (optionType == OptionType.SHORT_PUT_QUOTE || optionType == OptionType.LONG_PUT) ? false : true;
  }

  function _getSecondsToExpiry(uint expiry) internal view returns (uint) {
    require(block.timestamp <= expiry, "timestamp expired");
    return expiry - block.timestamp;
  }

  function _abs(int val) internal pure returns (uint) {
    return val >= 0 ? uint(val) : uint(-val);
  }

  function _min(uint x, uint y) internal pure returns (uint) {
    return (x < y) ? x : y;
  }

  function _max(uint x, uint y) internal pure returns (uint) {
    return (x > y) ? x : y;
  }

  // temporary fix - eth core devs promised Q2 2022 fix
  function _toDynamic(uint val) internal pure returns (uint[] memory dynamicArray) {
    dynamicArray = new uint[](1);
    dynamicArray[0] = val;
  }
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
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {Vault} from "../libraries/Vault.sol";
import {VaultLifecycle} from "../libraries/VaultLifecycle.sol";
import {ShareMath} from "../libraries/ShareMath.sol";

contract BaseVault is ReentrancyGuard, Ownable, ERC20, Initializable {
  using SafeERC20 for IERC20;
  using ShareMath for Vault.DepositReceipt;

  /************************************************
   *  NON UPGRADEABLE STORAGE
   ***********************************************/

  /// @notice Stores the user's pending deposit for the round
  mapping(address => Vault.DepositReceipt) public depositReceipts;

  /// @notice On every round's close, the pricePerShare value of the Vault's
  //          token is stored
  /// This is used to determine the number of shares to be returned
  /// to a user with their DepositReceipt.depositAmount
  mapping(uint => uint) public roundPricePerShare;

  /// @notice Stores pending user withdrawals
  mapping(address => Vault.Withdrawal) public withdrawals;

  /// @notice Vault's parameters like cap, decimals
  Vault.VaultParams public vaultParams;

  /// @notice Vault's lifecycle state like round and locked amounts
  Vault.VaultState public vaultState;

  /// @notice Fee recipient for the performance and management fees
  address public feeRecipient;

  /// @notice Performance fee charged on premiums earned in rollToNextOption. Only charged when there is no loss.
  uint public performanceFee;

  /// @notice Management fee charged on entire AUM in rollToNextOption. Only charged when there is no loss.
  uint public managementFee;

  // Gap is left to avoid storage collisions. Though RibbonVault is not upgradeable, we add this as a safety measure.
  uint[30] private ____gap;

  // *IMPORTANT* NO NEW STORAGE VARIABLES SHOULD BE ADDED HERE
  // This is to prevent storage collisions. All storage variables should be appended to RibbonThetaVaultStorage
  // or RibbonDeltaVaultStorage instead. Read this documentation to learn more:
  // https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#modifying-your-contracts

  /************************************************
   *  IMMUTABLES & CONSTANTS
   ***********************************************/

  // Round per year scaled up FEE_MULTIPLIER
  uint private immutable roundPerYear;

  /************************************************
   *  EVENTS
   ***********************************************/

  event Deposit(address indexed account, uint amount, uint round);

  event InitiateWithdraw(address indexed account, uint shares, uint round);

  event Redeem(address indexed account, uint share, uint round);

  event ManagementFeeSet(uint managementFee, uint newManagementFee);

  event PerformanceFeeSet(uint performanceFee, uint newPerformanceFee);

  event CapSet(uint oldCap, uint newCap, address manager);

  event Withdraw(address indexed account, uint amount, uint shares);

  event CollectVaultFees(uint performanceFee, uint vaultFee, uint round, address indexed feeRecipient);

  /************************************************
   *  CONSTRUCTOR & INITIALIZATION
   ***********************************************/

  /**
   * @notice Initializes the contract with immutable variables
   */
  constructor(
    address _feeRecipient,
    uint _roundDuration,
    string memory _tokenName,
    string memory _tokenSymbol,
    Vault.VaultParams memory _vaultParams
  ) ERC20(_tokenName, _tokenSymbol) {
    feeRecipient = _feeRecipient;
    uint _roundPerYear = (uint(365 days) * Vault.FEE_MULTIPLIER) / _roundDuration;
    roundPerYear = _roundPerYear;
    vaultParams = _vaultParams;

    uint assetBalance = IERC20(vaultParams.asset).balanceOf(address(this));
    ShareMath.assertUint104(assetBalance);
    vaultState.lastLockedAmount = uint104(assetBalance);
    vaultState.round = 1;
  }

  /************************************************
   *  SETTERS
   ***********************************************/

  /**
   * @notice Sets the new fee recipient
   * @param newFeeRecipient is the address of the new fee recipient
   */
  function setFeeRecipient(address newFeeRecipient) external onlyOwner {
    require(newFeeRecipient != address(0), "!newFeeRecipient");
    require(newFeeRecipient != feeRecipient, "Must be new feeRecipient");
    feeRecipient = newFeeRecipient;
  }

  /**
   * @notice Sets the management fee for the vault
   * @param newManagementFee is the management fee (6 decimals). ex: 2 * 10 ** 6 = 2%
   */
  function setManagementFee(uint newManagementFee) external onlyOwner {
    require(newManagementFee < 100 * Vault.FEE_MULTIPLIER, "Invalid management fee");

    emit ManagementFeeSet(managementFee, newManagementFee);

    // We are dividing annualized management fee by number of rounds in a year
    managementFee = (newManagementFee * Vault.FEE_MULTIPLIER) / roundPerYear;
  }

  /**
   * @notice Sets the performance fee for the vault
   * @param newPerformanceFee is the performance fee (6 decimals). ex: 20 * 10 ** 6 = 20%
   */
  function setPerformanceFee(uint newPerformanceFee) external onlyOwner {
    require(newPerformanceFee < 100 * Vault.FEE_MULTIPLIER, "Invalid performance fee");

    emit PerformanceFeeSet(performanceFee, newPerformanceFee);

    performanceFee = newPerformanceFee;
  }

  /**
   * @notice Sets a new cap for deposits
   * @param newCap is the new cap for deposits
   */
  function setCap(uint newCap) external onlyOwner {
    require(newCap > 0, "!newCap");

    emit CapSet(vaultParams.cap, newCap, msg.sender);

    ShareMath.assertUint104(newCap);
    vaultParams.cap = uint104(newCap);
  }

  /************************************************
   *  DEPOSIT & WITHDRAWALS
   ***********************************************/

  /**
   * @notice Deposits the `asset` from msg.sender.
   * @param amount is the amount of `asset` to deposit
   */
  function deposit(uint amount) external nonReentrant {
    require(amount > 0, "!amount");

    _depositFor(amount, msg.sender);

    // An approve() by the msg.sender is required beforehand
    IERC20(vaultParams.asset).safeTransferFrom(msg.sender, address(this), amount);
  }

  /**
   * @notice Deposits the `asset` from msg.sender added to `creditor`'s deposit.
   * @notice Used for vault -> vault deposits on the user's behalf
   * @param amount is the amount of `asset` to deposit
   * @param creditor is the address that can claim/withdraw deposited amount
   */
  function depositFor(uint amount, address creditor) external nonReentrant {
    require(amount > 0, "!amount");
    require(creditor != address(0), "!creditor");

    _depositFor(amount, creditor);

    // An approve() by the msg.sender is required beforehand
    IERC20(vaultParams.asset).safeTransferFrom(msg.sender, address(this), amount);
  }

  /**
   * @notice Mints the vault shares to the creditor
   * @param amount is the amount of `asset` deposited
   * @param creditor is the address to receieve the deposit
   */
  function _depositFor(uint amount, address creditor) private {
    uint currentRound = vaultState.round;
    uint totalWithDepositedAmount = totalBalance() + amount;

    require(totalWithDepositedAmount <= vaultParams.cap, "Exceed cap");

    emit Deposit(creditor, amount, currentRound);

    Vault.DepositReceipt memory depositReceipt = depositReceipts[creditor];

    // process unprocessed pending deposit from the previous rounds
    uint unredeemedShares = depositReceipt.getSharesFromReceipt(
      currentRound,
      roundPricePerShare[depositReceipt.round],
      vaultParams.decimals
    );

    uint depositAmount = amount;

    // If we have a pending deposit in the current round, we add on to the pending deposit
    if (currentRound == depositReceipt.round) {
      uint newAmount = uint(depositReceipt.amount) + amount;
      depositAmount = newAmount;
    }

    ShareMath.assertUint104(depositAmount);

    depositReceipts[creditor] = Vault.DepositReceipt({
      round: uint16(currentRound),
      amount: uint104(depositAmount),
      unredeemedShares: uint128(unredeemedShares)
    });

    uint newTotalPending = uint(vaultState.totalPending) + amount;
    ShareMath.assertUint128(newTotalPending);

    vaultState.totalPending = uint128(newTotalPending);
  }

  /**
   * @notice Initiates a withdrawal that can be processed once the round completes
   * @param numShares is the number of shares to withdraw
   */
  function initiateWithdraw(uint numShares) external nonReentrant {
    require(numShares > 0, "!numShares");

    // We do a max redeem before initiating a withdrawal
    // But we check if they must first have unredeemed shares
    if (depositReceipts[msg.sender].amount > 0 || depositReceipts[msg.sender].unredeemedShares > 0) {
      _redeem(0, true);
    }

    // This caches the `round` variable used in shareBalances
    uint currentRound = vaultState.round;
    Vault.Withdrawal storage withdrawal = withdrawals[msg.sender];

    bool withdrawalIsSameRound = withdrawal.round == currentRound;

    emit InitiateWithdraw(msg.sender, numShares, currentRound);

    uint existingShares = uint(withdrawal.shares);

    uint withdrawalShares;
    if (withdrawalIsSameRound) {
      withdrawalShares = existingShares + numShares;
    } else {
      require(existingShares == 0, "Existing withdraw");
      withdrawalShares = numShares;
      withdrawals[msg.sender].round = uint16(currentRound);
    }

    ShareMath.assertUint128(withdrawalShares);
    withdrawals[msg.sender].shares = uint128(withdrawalShares);

    uint newQueuedWithdrawShares = uint(vaultState.queuedWithdrawShares) + numShares;
    ShareMath.assertUint128(newQueuedWithdrawShares);
    vaultState.queuedWithdrawShares = uint128(newQueuedWithdrawShares);

    _transfer(msg.sender, address(this), numShares);
  }

  /**
   * @notice Completes a scheduled withdrawal from a past round. Uses finalized pps for the round
   */
  function completeWithdraw() external nonReentrant {
    Vault.Withdrawal storage withdrawal = withdrawals[msg.sender];

    uint withdrawalShares = withdrawal.shares;
    uint withdrawalRound = withdrawal.round;

    // This checks if there is a withdrawal
    require(withdrawalShares > 0, "Not initiated");

    require(withdrawalRound < vaultState.round, "Round in progress");

    // We leave the round number as non-zero to save on gas for subsequent writes
    withdrawals[msg.sender].shares = 0;
    vaultState.queuedWithdrawShares = uint128(uint(vaultState.queuedWithdrawShares) - withdrawalShares);

    uint withdrawAmount = ShareMath.sharesToAsset(
      withdrawalShares,
      roundPricePerShare[withdrawalRound],
      vaultParams.decimals
    );

    emit Withdraw(msg.sender, withdrawAmount, withdrawalShares);

    _burn(address(this), withdrawalShares);

    require(withdrawAmount > 0, "!withdrawAmount");

    _transferAsset(msg.sender, withdrawAmount);
  }

  /**
   * @notice Redeems shares that are owed to the account
   * @param numShares is the number of shares to redeem
   */
  function redeem(uint numShares) external nonReentrant {
    require(numShares > 0, "!numShares");
    _redeem(numShares, false);
  }

  /**
   * @notice Redeems the entire unredeemedShares balance that is owed to the account
   */
  function maxRedeem() external nonReentrant {
    _redeem(0, true);
  }

  /**
   * @notice Redeems shares that are owed to the account
   * @param numShares is the number of shares to redeem, could be 0 when isMax=true
   * @param isMax is flag for when callers do a max redemption
   */
  function _redeem(uint numShares, bool isMax) internal {
    Vault.DepositReceipt memory depositReceipt = depositReceipts[msg.sender];

    // This handles the null case when depositReceipt.round = 0
    // Because we start with round = 1 at `initialize`
    uint currentRound = vaultState.round;

    uint unredeemedShares = depositReceipt.getSharesFromReceipt(
      currentRound,
      roundPricePerShare[depositReceipt.round],
      vaultParams.decimals
    );

    numShares = isMax ? unredeemedShares : numShares;
    if (numShares == 0) {
      return;
    }
    require(numShares <= unredeemedShares, "Exceeds available");

    // If we have a depositReceipt on the same round, BUT we have some unredeemed shares
    // we debit from the unredeemedShares, but leave the amount field intact
    // If the round has past, with no new deposits, we just zero it out for new deposits.
    depositReceipts[msg.sender].amount = depositReceipt.round < currentRound ? 0 : depositReceipt.amount;

    ShareMath.assertUint128(numShares);
    depositReceipts[msg.sender].unredeemedShares = uint128(unredeemedShares - numShares);

    emit Redeem(msg.sender, numShares, depositReceipt.round);

    _transfer(address(this), msg.sender, numShares);
  }

  /************************************************
   *  VAULT OPERATIONS
   ***********************************************/

  /*
   * @notice Helper function that performs most administrative tasks
   * such as setting next option, minting new shares, getting vault fees, etc.
   * @param lastQueuedWithdrawAmount is old queued withdraw amount
   * @return lockedBalance is the new balance used to calculate next option purchase size or collateral size
   * @return queuedWithdrawAmount is the new queued withdraw amount for this round
   */
  function _rollToNextRound(uint lastQueuedWithdrawAmount) internal returns (uint, uint) {
    (uint lockedBalance, uint queuedWithdrawAmount, uint newPricePerShare, uint mintShares) = VaultLifecycle.rollover(
      totalSupply(),
      vaultParams.asset,
      vaultParams.decimals,
      uint(vaultState.totalPending),
      vaultState.queuedWithdrawShares
    );

    // Finalize the pricePerShare at the end of the round
    uint currentRound = vaultState.round;
    roundPricePerShare[currentRound] = newPricePerShare;

    uint withdrawAmountDiff = queuedWithdrawAmount > lastQueuedWithdrawAmount
      ? queuedWithdrawAmount - lastQueuedWithdrawAmount
      : 0;

    // Take management / performance fee from previous round and deduct
    lockedBalance = lockedBalance - _collectVaultFees(lockedBalance + withdrawAmountDiff);

    // update round info
    vaultState.totalPending = 0;
    vaultState.round = uint16(currentRound + 1);

    _mint(address(this), mintShares);

    return (lockedBalance, queuedWithdrawAmount);
  }

  /*
   * @notice Helper function that transfers management fees and performance fees from previous round.
   * @param pastWeekBalance is the balance we are about to lock for next round
   * @return vaultFee is the fee deducted
   */
  function _collectVaultFees(uint pastWeekBalance) internal returns (uint) {
    (uint performanceFeeInAsset, , uint vaultFee) = VaultLifecycle.getVaultFees(
      vaultState,
      pastWeekBalance,
      performanceFee,
      managementFee
    );

    if (vaultFee > 0) {
      _transferAsset(payable(feeRecipient), vaultFee);
      emit CollectVaultFees(performanceFeeInAsset, vaultFee, vaultState.round, feeRecipient);
    }

    return vaultFee;
  }

  /**
   * @notice Helper function to make either an ETH transfer or ERC20 transfer
   * @param recipient is the receiving address
   * @param amount is the transfer amount
   */
  function _transferAsset(address recipient, uint amount) internal {
    address asset = vaultParams.asset;
    IERC20(asset).safeTransfer(recipient, amount);
  }

  /************************************************
   *  GETTERS
   ***********************************************/

  /**
   * @notice Returns the asset balance held on the vault for the account
   * @param account is the address to lookup balance for
   * @return the amount of `asset` custodied by the vault for the user
   */
  function accountVaultBalance(address account) external view returns (uint) {
    uint _decimals = vaultParams.decimals;
    uint assetPerShare = ShareMath.pricePerShare(totalSupply(), totalBalance(), vaultState.totalPending, _decimals);
    return ShareMath.sharesToAsset(shares(account), assetPerShare, _decimals);
  }

  /**
   * @notice Getter for returning the account's share balance including unredeemed shares
   * @param account is the account to lookup share balance for
   * @return the share balance
   */
  function shares(address account) public view returns (uint) {
    (uint heldByAccount, uint heldByVault) = shareBalances(account);
    return heldByAccount + heldByVault;
  }

  /**
   * @notice Getter for returning the account's share balance split between account and vault holdings
   * @param account is the account to lookup share balance for
   * @return heldByAccount is the shares held by account
   * @return heldByVault is the shares held on the vault (unredeemedShares)
   */
  function shareBalances(address account) public view returns (uint heldByAccount, uint heldByVault) {
    Vault.DepositReceipt memory depositReceipt = depositReceipts[account];

    if (depositReceipt.round == 0) {
      return (balanceOf(account), 0);
    }

    uint unredeemedShares = depositReceipt.getSharesFromReceipt(
      vaultState.round,
      roundPricePerShare[depositReceipt.round],
      vaultParams.decimals
    );

    return (balanceOf(account), unredeemedShares);
  }

  /**
   * @notice The price of a unit of share denominated in the `asset`
   */
  function pricePerShare() external view returns (uint) {
    return ShareMath.pricePerShare(totalSupply(), totalBalance(), vaultState.totalPending, vaultParams.decimals);
  }

  /**
   * @notice Returns the vault's total balance, including the amounts locked into a short position
   * @return total balance of the vault, including the amounts locked in third party protocols
   */
  function totalBalance() public view returns (uint) {
    return
      uint(vaultState.lockedAmount - vaultState.lockedAmountLeft) + IERC20(vaultParams.asset).balanceOf(address(this));
  }

  /**
   * @notice Returns the token decimals
   */
  function decimals() public view override returns (uint8) {
    return vaultParams.decimals;
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
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
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, _allowances[owner][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = _allowances[owner][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Spend `amount` form the allowance of `owner` toward `spender`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

import "../../utils/Address.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To initialize the implementation contract, you can either invoke the
 * initializer manually, or you can include a constructor to automatically mark it as initialized when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() initializer {}
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(_initializing ? _isConstructor() : !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _isConstructor() private view returns (bool) {
        return !Address.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Vault} from "./Vault.sol";
import {ShareMath} from "./ShareMath.sol";

import {IERC20Detailed} from "../interfaces/IERC20Detailed.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev copied from Ribbon's VaultLifeCycle, changed to internal library for gas optimization
 */
library VaultLifecycle {
  using SafeMath for uint;
  using SafeERC20 for IERC20;

  /**
   * @notice Calculate the shares to mint, new price per share,
   *         and amount of funds to re-allocate as collateral for the new round
   * @param currentShareSupply is the total supply of shares
   * @param asset is the address of the vault's asset
   * @param decimals is the decimals of the asset
   * @param pendingAmount is the amount of funds pending from recent deposits
   * @return newLockedAmount is the amount of funds to allocate for the new round
   * @return queuedWithdrawAmount is the amount of funds set aside for withdrawal
   * @return newPricePerShare is the price per share of the new round
   * @return mintShares is the amount of shares to mint from deposits
   */
  function rollover(
    uint currentShareSupply,
    address asset,
    uint decimals,
    uint pendingAmount,
    uint queuedWithdrawShares
  )
    internal
    view
    returns (
      uint newLockedAmount,
      uint queuedWithdrawAmount,
      uint newPricePerShare,
      uint mintShares
    )
  {
    uint currentBalance = IERC20(asset).balanceOf(address(this));

    newPricePerShare = ShareMath.pricePerShare(currentShareSupply, currentBalance, pendingAmount, decimals);

    // After closing the short, if the options expire in-the-money
    // vault pricePerShare would go down because vault's asset balance decreased.
    // This ensures that the newly-minted shares do not take on the loss.
    uint _mintShares = ShareMath.assetToShares(pendingAmount, newPricePerShare, decimals);

    uint newSupply = currentShareSupply.add(_mintShares);

    uint queuedWithdraw = newSupply > 0 ? ShareMath.sharesToAsset(queuedWithdrawShares, newPricePerShare, decimals) : 0;

    return (currentBalance.sub(queuedWithdraw), queuedWithdraw, newPricePerShare, _mintShares);
  }

  /**
   * @notice Calculates the performance and management fee for this week's round
   * @param vaultState is the struct with vault accounting state
   * @param currentLockedBalance is the amount of funds currently locked in opyn
   * @param performanceFeePercent is the performance fee pct.
   * @param managementFeePercent is the management fee pct.
   * @return performanceFeeInAsset is the performance fee
   * @return managementFeeInAsset is the management fee
   * @return vaultFee is the total fees
   */
  function getVaultFees(
    Vault.VaultState storage vaultState,
    uint currentLockedBalance,
    uint performanceFeePercent,
    uint managementFeePercent
  )
    internal
    view
    returns (
      uint performanceFeeInAsset,
      uint managementFeeInAsset,
      uint vaultFee
    )
  {
    uint prevLockedAmount = vaultState.lastLockedAmount;

    uint lockedBalanceSansPending = currentLockedBalance.sub(vaultState.totalPending);

    uint _performanceFeeInAsset;
    uint _managementFeeInAsset;
    uint _vaultFee;

    // Take performance fee and management fee ONLY if difference between
    // last week and this week's vault deposits, taking into account pending
    // deposits and withdrawals, is positive. If it is negative, last week's
    // option expired ITM past breakeven, and the vault took a loss so we
    // do not collect performance fee for last week

    // todo: update management fee to exclude profit?
    if (lockedBalanceSansPending > prevLockedAmount) {
      _performanceFeeInAsset = performanceFeePercent > 0
        ? lockedBalanceSansPending.sub(prevLockedAmount).mul(performanceFeePercent).div(100 * Vault.FEE_MULTIPLIER)
        : 0;
      _managementFeeInAsset = managementFeePercent > 0
        ? lockedBalanceSansPending.mul(managementFeePercent).div(100 * Vault.FEE_MULTIPLIER)
        : 0;

      _vaultFee = _performanceFeeInAsset.add(_managementFeeInAsset);
    }

    return (_performanceFeeInAsset, _managementFeeInAsset, _vaultFee);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Vault} from "./Vault.sol";

library ShareMath {
  function assetToShares(
    uint assetAmount,
    uint assetPerShare,
    uint decimals
  ) internal pure returns (uint) {
    // If this throws, it means that vault's roundPricePerShare[currentRound] has not been set yet
    // which should never happen.
    require(assetPerShare > 0, "Invalid assetPerShare");

    return (assetAmount * (10**decimals)) / (assetPerShare);
  }

  function sharesToAsset(
    uint shares,
    uint assetPerShare,
    uint decimals
  ) internal pure returns (uint) {
    // If this throws, it means that vault's roundPricePerShare[currentRound] has not been set yet
    // which should never happen.
    require(assetPerShare > 0, "Invalid assetPerShare");

    return (shares * assetPerShare) / (10**decimals);
  }

  /**
   * @notice Returns the shares unredeemed by the user given their DepositReceipt
   * @param depositReceipt is the user's deposit receipt
   * @param currentRound is the `round` stored on the vault
   * @param assetPerShare is the price in asset per share
   * @param decimals is the number of decimals the asset/shares use
   * @return unredeemedShares is the user's virtual balance of shares that are owed
   */
  function getSharesFromReceipt(
    Vault.DepositReceipt memory depositReceipt,
    uint currentRound,
    uint assetPerShare,
    uint decimals
  ) internal pure returns (uint unredeemedShares) {
    if (depositReceipt.round > 0 && depositReceipt.round < currentRound) {
      uint sharesFromRound = assetToShares(depositReceipt.amount, assetPerShare, decimals);

      return uint(depositReceipt.unredeemedShares) + sharesFromRound;
    }
    return depositReceipt.unredeemedShares;
  }

  function pricePerShare(
    uint totalSupply,
    uint totalBalance,
    uint pendingAmount,
    uint decimals
  ) internal pure returns (uint) {
    uint singleShare = 10**decimals;
    return totalSupply > 0 ? (singleShare * (totalBalance - pendingAmount)) / (totalSupply) : singleShare;
  }

  /************************************************
   *  HELPERS
   ***********************************************/

  function assertUint104(uint num) internal pure {
    require(num <= type(uint104).max, "Overflow uint104");
  }

  function assertUint128(uint num) internal pure {
    require(num <= type(uint128).max, "Overflow uint128");
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Detailed is IERC20 {
  function decimals() external view returns (uint8);

  function symbol() external view returns (string calldata);

  function name() external view returns (string calldata);
}

//SPDX-License-Identifier:ISC
pragma solidity 0.8.9;

// Libraries
import "../libraries/GWAV.sol";
import "../libraries/BlackScholes.sol";
import "../synthetix/DecimalMath.sol";

// Inherited
import "openzeppelin-contracts-4.4.1/access/Ownable.sol";
import "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";

// Interfaces
import "../interfaces/IOptionToken.sol";
import "../interfaces/IOptionMarket.sol";
import "../interfaces/ILiquidityPool.sol";
import "../interfaces/IShortCollateral.sol";
import "../interfaces/IOptionGreekCache.sol";
import "../interfaces/ISynthetixAdapter.sol";
import "../interfaces/IDelegateApprovals.sol";
import "../interfaces/ICurve.sol";
import "../interfaces/IGWAVOracle.sol";
import "../interfaces/ILyraRegistry.sol";
import "./BasicFeeCounter.sol";

/**
 * @title LyraAdapter
 * @author Lyra
 * @dev Provides helpful functions for any Lyra trading/market data/vault related actions in one contract
 *      To earn trading rewards, integrators must request to be whitelisted by Lyra
 */

contract LyraAdapter is Ownable {
  using DecimalMath for uint;

  ///////////////////////
  // Abstract Contract //
  ///////////////////////

  struct Strike {
    // strike listing identifier
    uint id;
    // expiry of strike
    uint expiry;
    // strike price
    uint strikePrice;
    // volatility component specific to the strike listing (boardIv * skew = vol of strike)
    uint skew;
    // volatility component specific to the board (boardIv * skew = vol of strike)
    uint boardIv;
  }

  struct Board {
    // board identifier
    uint id;
    // expiry of all strikes belong to
    uint expiry;
    // volatility component specific to the board (boardIv * skew = vol of strike)
    uint boardIv;
    // all strikes belonging to board
    uint[] strikeIds;
  }

  struct OptionPosition {
    // OptionToken ERC721 identifier for position
    uint positionId;
    // strike identifier
    uint strikeId;
    // LONG_CALL | LONG_PUT | SHORT_CALL_BASE | SHORT_CALL_QUOTE | SHORT_PUT_QUOTE
    OptionType optionType;
    // number of options contract owned by position
    uint amount;
    // collateral held in position (only applies to shorts)
    uint collateral;
    // EMPTY | ACTIVE | CLOSED | LIQUIDATED | SETTLED | MERGED
    PositionState state;
  }

  enum OptionType {
    LONG_CALL,
    LONG_PUT,
    SHORT_CALL_BASE,
    SHORT_CALL_QUOTE,
    SHORT_PUT_QUOTE
  }

  enum PositionState {
    EMPTY,
    ACTIVE,
    CLOSED,
    LIQUIDATED,
    SETTLED,
    MERGED
  }

  struct TradeInputParameters {
    // id of strike
    uint strikeId;
    // OptionToken ERC721 id for position (set to 0 for new positions)
    uint positionId;
    // number of sub-orders to break order into (reduces slippage)
    uint iterations;
    // type of option to trade
    OptionType optionType;
    // number of contracts to trade
    uint amount;
    // final amount of collateral to leave in OptionToken position
    uint setCollateralTo;
    // revert trade if totalCost is below this value
    uint minTotalCost;
    // revert trade if totalCost is above this value
    uint maxTotalCost;
    // address of recipient for Lyra trading rewards (must request Lyra to be whitelisted for rewards)
    address rewardRecipient;
  }

  struct TradeResult {
    // OptionToken ERC721 id for position
    uint positionId;
    // total option cost paid/received during trade including premium and totalFee
    uint totalCost;
    // trading fees as determined in OptionMarketPricer.sol
    uint totalFee;
  }

  struct Liquidity {
    // Amount of liquidity available for option collateral and premiums
    uint freeLiquidity;
    // Amount of liquidity available for withdrawals - different to freeLiquidity
    uint burnableLiquidity;
    // Amount of liquidity reserved for long options sold to traders
    uint usedCollatLiquidity;
    // Portion of liquidity reserved for delta hedging (quote outstanding)
    uint pendingDeltaLiquidity;
    // Current value of delta hedge
    uint usedDeltaLiquidity;
    // Net asset value, including everything and netOptionValue
    uint NAV;
  }

  struct MarketParams {
    // The amount of options traded to move baseIv for the board up or down 1 point (depending on trade direction)
    uint standardSize;
    // Determines relative move of skew for a given strike compared to shift in baseIv
    uint skewAdjustmentParam;
    // Interest/risk free rate used in BlackScholes
    int rateAndCarry;
    // Delta cutoff past which options can be traded (optionD > minD && optionD < 1 - minD) - can use forceClose to bypass
    int deltaCutOff;
    // Time when trading closes - can use forceClose to bypass
    uint tradingCutoff;
    // Delta cutoff at which forceClose can be called (optionD < minD || optionD > 1 - minD) - using call delta
    int minForceCloseDelta;
  }

  struct ExchangeRateParams {
    // current snx oracle base price
    uint spotPrice;
    // snx spot exchange rate from quote to base
    uint quoteBaseFeeRate;
    // snx spot exchange rate from base to quote
    uint baseQuoteFeeRate;
  }

  ///////////////
  // Variables //
  ///////////////

  ILyraRegistry public lyraRegistry;
  ISynthetixAdapter internal synthetixAdapter;
  IOptionMarket public optionMarket;
  IOptionToken public optionToken;
  ILiquidityPool public liquidityPool;
  IShortCollateral public shortCollateral;
  IGWAVOracle public gwavOracle;
  IOptionMarketPricer public optionPricer;
  IOptionGreekCache public greekCache;
  IERC20 public quoteAsset;
  IERC20 public baseAsset;

  ICurve public curveSwap;
  BasicFeeCounter public feeCounter;
  bytes32 private constant SNX_ADAPTER = "SYNTHETIX_ADAPTER";

  ///////////
  // Admin //
  ///////////

  constructor() Ownable() {}

  /**
   * @dev Assigns all lyra contracts

   * @param _lyraRegistry LyraRegistry address which holds latest market and global addressess
   * @param _optionMarket OptionMarket address
   * @param _curveSwap Curve pool address for swapping sUSD and other stables via `exchange_with_best_rate`
   * @param _feeCounter Fee counter addressu used to determine Lyra trading rewards
   */

  function setLyraAddresses(
    address _lyraRegistry,
    address _optionMarket,
    address _curveSwap,
    address _feeCounter
  ) public onlyOwner {
    // remove allowance from old assets
    if (address(quoteAsset) != address(0)) {
      quoteAsset.approve(address(optionMarket), 0);
    }
    if (address(baseAsset) != address(0)) {
      baseAsset.approve(address(optionMarket), 0);
    }

    optionMarket = IOptionMarket(_optionMarket);

    // Get market & global addresses via LyraRegistry
    lyraRegistry = ILyraRegistry(_lyraRegistry);
    synthetixAdapter = ISynthetixAdapter(lyraRegistry.getGlobalAddress(SNX_ADAPTER));
    _assignLyraRegistryMarketAddresses();

    // assign curve and Lyra reward counter
    curveSwap = ICurve(_curveSwap);
    feeCounter = BasicFeeCounter(_feeCounter);

    // Do approvals
    IDelegateApprovals(synthetixAdapter.delegateApprovals()).approveExchangeOnBehalf(address(synthetixAdapter));
    quoteAsset.approve(address(optionMarket), type(uint).max);
    baseAsset.approve(address(optionMarket), type(uint).max);
  }

  /// @notice In case of an update to the synthetix contract that revokes the approval
  function updateDelegateApproval() external onlyOwner {
    IDelegateApprovals(synthetixAdapter.delegateApprovals()).approveExchangeOnBehalf(address(synthetixAdapter));
  }

  ////////////////////
  // Market Actions //
  ////////////////////

  /**
   * @notice Attempts to open positions within cost bounds.
   * @dev If a positionId is specified params.amount will be added to the position
   * @dev params.amount can be zero when adjusting an existing position
   *
   * @param params The parameters for the requested trade
   */
  function _openPosition(TradeInputParameters memory params) internal returns (TradeResult memory tradeResult) {
    IOptionMarket.Result memory result = optionMarket.openPosition(_convertParams(params));
    if (params.rewardRecipient != address(0)) {
      feeCounter.trackFee(
        address(optionMarket),
        params.rewardRecipient,
        _convertParams(params).amount,
        result.totalCost,
        result.totalFee
      );
    }
    return TradeResult({positionId: result.positionId, totalCost: result.totalCost, totalFee: result.totalFee});
  }

  /**
   * @notice Attempt close under normal condition or forceClose
   *          if position is outside of delta or too close to expiry.
   *
   * @param params The parameters for the requested trade
   */
  function _closeOrForceClosePosition(TradeInputParameters memory params)
    internal
    returns (TradeResult memory tradeResult)
  {
    if (!_isOutsideDeltaCutoff(params.strikeId) && !_isWithinTradingCutoff(params.strikeId)) {
      return _closePosition(params);
    } else {
      // will pay less competitive price to close position but bypasses Lyra delta/trading cutoffs
      return _forceClosePosition(params);
    }
  }

  /**
   * @notice Attempts to close an existing position within cost bounds.
   * @dev If a positionId is specified params.amount will be subtracted from the position
   * @dev params.amount can be zero when adjusting an existing position
   *
   * @param params The parameters for the requested trade
   */
  function _closePosition(TradeInputParameters memory params) internal returns (TradeResult memory tradeResult) {
    IOptionMarket.Result memory result = optionMarket.closePosition(_convertParams(params));
    if (params.rewardRecipient != address(0)) {
      feeCounter.trackFee(
        address(optionMarket),
        params.rewardRecipient,
        _convertParams(params).amount,
        result.totalCost,
        result.totalFee
      );
    }
    return TradeResult({positionId: result.positionId, totalCost: result.totalCost, totalFee: result.totalFee});
  }

  /**
   * @notice Attempts to close an existing position outside of the delta or trading cutoffs (as specified in MarketParams).
   * @dev This market action will charge higher fees than the standard `closePosition()`
   *
   * @param params The parameters for the requested trade
   */
  function _forceClosePosition(TradeInputParameters memory params) internal returns (TradeResult memory tradeResult) {
    IOptionMarket.Result memory result = optionMarket.forceClosePosition(_convertParams(params));
    if (params.rewardRecipient != address(0)) {
      feeCounter.trackFee(
        address(optionMarket),
        params.rewardRecipient,
        _convertParams(params).amount,
        result.totalCost,
        result.totalFee
      );
    }
    return TradeResult({positionId: result.positionId, totalCost: result.totalCost, totalFee: result.totalFee});
  }

  //////////////
  // Exchange //
  //////////////

  /// @notice Exchange an exact amount of quote for a minimum amount of base (revert otherwise)
  function _exchangeFromExactQuote(uint amountQuote, uint minBaseReceived) internal returns (uint baseReceived) {
    baseReceived = synthetixAdapter.exchangeFromExactQuote(address(optionMarket), amountQuote);
    if (baseReceived < minBaseReceived) {
      revert ExchangerBaseReceivedTooLow(address(this), minBaseReceived, baseReceived);
    }
  }

  /// @notice Exchange to an exact amount of quote for a maximum amount of base (revert otherwise)
  function _exchangeToExactQuote(uint amountQuote, uint maxBaseUsed) internal returns (uint quoteReceived) {
    ISynthetixAdapter.ExchangeParams memory exchangeParams = synthetixAdapter.getExchangeParams(address(optionMarket));
    (, quoteReceived) = synthetixAdapter.exchangeToExactQuoteWithLimit(
      exchangeParams,
      address(optionMarket),
      amountQuote,
      maxBaseUsed
    );
  }

  /// @notice Exchange an exact amount of base for a minimum amount of quote (revert otherwise)
  function _exchangeFromExactBase(uint amountBase, uint minQuoteReceived) internal returns (uint quoteReceived) {
    quoteReceived = synthetixAdapter.exchangeFromExactBase(address(optionMarket), amountBase);
    if (quoteReceived < minQuoteReceived) {
      revert ExchangerQuoteReceivedTooLow(address(this), minQuoteReceived, quoteReceived);
    }
  }

  /// @notice Exchange to an exact amount of base for a maximum amount of quote (revert otherwise)
  function _exchangeToExactBase(uint amountBase, uint maxQuoteUsed) internal returns (uint baseReceived) {
    ISynthetixAdapter.ExchangeParams memory exchangeParams = synthetixAdapter.getExchangeParams(address(optionMarket));
    (, baseReceived) = synthetixAdapter.exchangeToExactBaseWithLimit(
      exchangeParams,
      address(optionMarket),
      amountBase,
      maxQuoteUsed
    );
  }

  /// @notice Returns the ExchangeParams for current market.
  function _getExchangeParams() internal view returns (ExchangeRateParams memory) {
    ISynthetixAdapter.ExchangeParams memory params = synthetixAdapter.getExchangeParams(address(optionMarket));
    return
      ExchangeRateParams({
        spotPrice: params.spotPrice,
        quoteBaseFeeRate: params.quoteBaseFeeRate,
        baseQuoteFeeRate: params.baseQuoteFeeRate
      });
  }

  /**
   * @notice WARNING: ENSURE CURVE HAS SUFFICIENT sUSD LIQUIDITY
   *         Exchange between stables within the curveSwap sUSD pool.
   *
   * @param from start ERC20
   * @param to destination ERC20
   * @param amount amount of "from" currency to exchange
   * @param expected minimum expected amount of "to" currency
   * @param receiver address of recipient of "to" currency
   *
   * @return amountOut received amount
   */
  function _swapStables(
    address from,
    address to,
    uint amount,
    uint expected,
    address receiver
  ) internal returns (uint amountOut) {
    amountOut = curveSwap.exchange_with_best_rate(from, to, amount, expected, receiver);
  }

  //////////////////////////
  // Option Token Actions //
  //////////////////////////

  /// @notice Get position info for given positionIds
  function _getPositions(uint[] memory positionIds) internal view returns (OptionPosition[] memory) {
    IOptionToken.OptionPosition[] memory positions = optionToken.getOptionPositions(positionIds);

    uint positionsLen = positions.length;
    OptionPosition[] memory convertedPositions = new OptionPosition[](positionsLen);
    for (uint i = 0; i < positionsLen; ++i) {
      convertedPositions[i] = OptionPosition({
        positionId: positions[i].positionId,
        strikeId: positions[i].strikeId,
        optionType: OptionType(uint(positions[i].optionType)),
        amount: positions[i].amount,
        collateral: positions[i].collateral,
        state: PositionState(uint(positions[i].state))
      });
    }

    return convertedPositions;
  }

  /**
   * @notice Allows a user to split a curent position into two. The amount of the original position will
   *         be subtracted from and a new position will be minted with the desired amount and collateral.
   * @dev Only ACTIVE positions can be owned by users, so status does not need to be checked
   * @dev Both resulting positions must not be liquidatable
   *
   * @param positionId the positionId of the original position to be split
   * @param newAmount the amount in the new position
   * @param newCollateral the amount of collateral for the new position
   * @param recipient recipient of new position
   */
  function _splitPosition(
    uint positionId,
    uint newAmount,
    uint newCollateral,
    address recipient
  ) internal returns (uint newPositionId) {
    newPositionId = optionToken.split(positionId, newAmount, newCollateral, recipient);
  }

  /**
   * @notice User can merge many positions with matching strike and optionType into a single position
   * @dev Only ACTIVE positions can be owned by users, so status does not need to be checked.
   * @dev Merged position must not be liquidatable.
   *
   * @param positionIds the positionIds to be merged together
   */
  function _mergePositions(uint[] memory positionIds) internal {
    optionToken.merge(positionIds);
  }

  ////////////////////
  // Market Getters //
  ////////////////////

  /// @notice Returns the list of live board ids.
  function _getLiveBoards() internal view returns (uint[] memory liveBoards) {
    liveBoards = optionMarket.getLiveBoards();
  }

  /// @notice Returns Board struct for a given boardId
  function _getBoard(uint boardId) internal view returns (Board memory) {
    IOptionMarket.OptionBoard memory board = optionMarket.getOptionBoard(boardId);
    return Board({id: board.id, expiry: board.expiry, boardIv: board.iv, strikeIds: board.strikeIds});
  }

  /// @notice Returns all Strike structs for a list of strikeIds
  function _getStrikes(uint[] memory strikeIds) internal view returns (Strike[] memory allStrikes) {
    uint strikesLen = strikeIds.length;

    allStrikes = new Strike[](strikesLen);
    for (uint i = 0; i < strikesLen; ++i) {
      (IOptionMarket.Strike memory strike, IOptionMarket.OptionBoard memory board) = optionMarket.getStrikeAndBoard(
        strikeIds[i]
      );

      allStrikes[i] = Strike({
        id: strike.id,
        expiry: board.expiry,
        strikePrice: strike.strikePrice,
        skew: strike.skew,
        boardIv: board.iv
      });
    }
    return allStrikes;
  }

  /// @notice Returns current spot volatilities for given strikeIds (boardIv * skew)
  function _getVols(uint[] memory strikeIds) internal view returns (uint[] memory vols) {
    uint strikesLen = strikeIds.length;

    vols = new uint[](strikesLen);
    for (uint i = 0; i < strikesLen; ++i) {
      (IOptionMarket.Strike memory strike, IOptionMarket.OptionBoard memory board) = optionMarket.getStrikeAndBoard(
        strikeIds[i]
      );

      vols[i] = board.iv.multiplyDecimal(strike.skew);
    }
    return vols;
  }

  /// @notice Returns current spot deltas for given strikeIds (using BlackScholes and spot volatilities)
  function _getDeltas(uint[] memory strikeIds) internal view returns (int[] memory callDeltas) {
    uint strikesLen = strikeIds.length;

    callDeltas = new int[](strikesLen);
    for (uint i = 0; i < strikesLen; ++i) {
      BlackScholes.BlackScholesInputs memory bsInput = _getBsInput(strikeIds[i]);
      (callDeltas[i], ) = BlackScholes.delta(bsInput);
    }
  }

  /// @notice Returns current spot vegas for given strikeIds (using BlackScholes and spot volatilities)
  function _getVegas(uint[] memory strikeIds) internal view returns (uint[] memory vegas) {
    uint strikesLen = strikeIds.length;

    vegas = new uint[](strikesLen);
    for (uint i = 0; i < strikesLen; ++i) {
      BlackScholes.BlackScholesInputs memory bsInput = _getBsInput(strikeIds[i]);
      vegas[i] = BlackScholes.vega(bsInput);
    }
  }

  /// @notice Calculate the pure black-scholes premium for given params
  function _getPurePremium(
    uint secondsToExpiry,
    uint vol,
    uint spotPrice,
    uint strikePrice
  ) internal view returns (uint call, uint put) {
    BlackScholes.BlackScholesInputs memory bsInput = BlackScholes.BlackScholesInputs({
      timeToExpirySec: secondsToExpiry,
      volatilityDecimal: vol,
      spotDecimal: spotPrice,
      strikePriceDecimal: strikePrice,
      rateDecimal: greekCache.getGreekCacheParams().rateAndCarry
    });
    (call, put) = BlackScholes.optionPrices(bsInput);
  }

  /// @notice Calculate the spot black-scholes premium for a given strike
  /// @dev Does not include slippage or trading fees
  function _getPurePremiumForStrike(uint strikeId) internal view returns (uint call, uint put) {
    BlackScholes.BlackScholesInputs memory bsInput = _getBsInput(strikeId);
    (call, put) = BlackScholes.optionPrices(bsInput);
  }

  /// @notice Returns the breakdown of current liquidity usage (see Liquidity struct)
  function _getLiquidity() internal view returns (Liquidity memory) {
    ILiquidityPool.Liquidity memory liquidity = liquidityPool.getCurrentLiquidity();
    return
      Liquidity({
        freeLiquidity: liquidity.freeLiquidity,
        burnableLiquidity: liquidity.burnableLiquidity,
        usedCollatLiquidity: liquidity.usedCollatLiquidity,
        pendingDeltaLiquidity: liquidity.pendingDeltaLiquidity,
        usedDeltaLiquidity: liquidity.usedDeltaLiquidity,
        NAV: liquidity.NAV
      });
  }

  /// @notice Returns the amount of liquidity available for trading
  function _getFreeLiquidity() internal view returns (uint freeLiquidity) {
    freeLiquidity = liquidityPool.getCurrentLiquidity().freeLiquidity;
  }

  /// @notice Returns the most critical Lyra market trading parameters that determine pricing/slippage/trading restrictions
  function _getMarketParams() internal view returns (MarketParams memory) {
    IOptionMarketPricer.PricingParameters memory pricingParams = optionPricer.getPricingParams();
    IOptionMarketPricer.TradeLimitParameters memory tradeLimitParams = optionPricer.getTradeLimitParams();
    return
      MarketParams({
        standardSize: pricingParams.standardSize,
        skewAdjustmentParam: pricingParams.skewAdjustmentFactor,
        rateAndCarry: greekCache.getGreekCacheParams().rateAndCarry,
        deltaCutOff: tradeLimitParams.minDelta,
        tradingCutoff: tradeLimitParams.tradingCutoff,
        minForceCloseDelta: tradeLimitParams.minForceCloseDelta
      });
  }

  /// @notice use latest optionMarket delta cutoff to determine whether trade delta is out of bounds
  function _isOutsideDeltaCutoff(uint strikeId) internal view returns (bool) {
    MarketParams memory marketParams = _getMarketParams();
    uint[] memory dynamicArray = new uint[](1);
    dynamicArray[0] = strikeId;

    int callDelta = _getDeltas(dynamicArray)[0];
    return callDelta > (int(DecimalMath.UNIT) - marketParams.deltaCutOff) || callDelta < marketParams.deltaCutOff;
  }

  /// @notice use latest optionMarket trading cutoff to determine whether trade is too close to expiry
  function _isWithinTradingCutoff(uint strikeId) internal view returns (bool) {
    MarketParams memory marketParams = _getMarketParams();
    uint[] memory dynamicArray = new uint[](1);
    dynamicArray[0] = strikeId;

    Strike memory strike = _getStrikes(dynamicArray)[0];
    return strike.expiry - block.timestamp <= marketParams.tradingCutoff;
  }

  ////////////////////////
  // Minimum Collateral //
  ////////////////////////

  /// @notice Estimate minimum collateral required for given parameters
  /// @dev Position is liquidatable when position.collateral < minCollateral
  function _getMinCollateral(
    OptionType optionType,
    uint strikePrice,
    uint expiry,
    uint spotPrice,
    uint amount
  ) internal view returns (uint) {
    return
      greekCache.getMinCollateral(IOptionMarket.OptionType(uint(optionType)), strikePrice, expiry, spotPrice, amount);
  }

  /// @notice Estimate minimum collateral required for an existing position
  function _getMinCollateralForPosition(uint positionId) internal view returns (uint) {
    IOptionToken.PositionWithOwner memory position = optionToken.getPositionWithOwner(positionId);
    if (_isLong(OptionType(uint(position.optionType)))) return 0;

    uint strikePrice;
    uint expiry;
    (strikePrice, expiry) = optionMarket.getStrikeAndExpiry(position.strikeId);

    return
      _getMinCollateral(
        OptionType(uint(position.optionType)),
        strikePrice,
        expiry,
        synthetixAdapter.getSpotPriceForMarket(address(optionMarket)),
        position.amount
      );
  }

  /// @notice Estimate minimum collateral required for a given strike with manual amount
  function _getMinCollateralForStrike(
    OptionType optionType,
    uint strikeId,
    uint amount
  ) internal view returns (uint) {
    if (_isLong(optionType)) return 0;

    uint strikePrice;
    uint expiry;
    (strikePrice, expiry) = optionMarket.getStrikeAndExpiry(strikeId);

    return
      _getMinCollateral(
        optionType,
        strikePrice,
        expiry,
        synthetixAdapter.getSpotPriceForMarket(address(optionMarket)),
        amount
      );
  }

  /////////////////
  // GWAV Oracle //
  /////////////////

  /// @notice the `baseIv` GWAV for a given `boardId` with GWAV interval `secondsAgo`
  function _ivGWAV(uint boardId, uint secondsAgo) internal view returns (uint) {
    return gwavOracle.ivGWAV(boardId, secondsAgo);
  }

  /// @notice the volatility `skew` GWAV for a given `strikeId` with GWAV interval `secondsAgo`
  function _skewGWAV(uint strikeId, uint secondsAgo) internal view returns (uint) {
    return gwavOracle.skewGWAV(strikeId, secondsAgo);
  }

  /// @notice the resultant volatility =`skew` * 'baseIv' for a given `strikeId` with GWAV interval `secondsAgo`
  function _volGWAV(uint strikeId, uint secondsAgo) internal view returns (uint) {
    return gwavOracle.volGWAV(strikeId, secondsAgo);
  }

  /// @notice the delta GWAV for a given `strikeId` with GWAV interval `secondsAgo`
  function _deltaGWAV(uint strikeId, uint secondsAgo) internal view returns (int callDelta) {
    return gwavOracle.deltaGWAV(strikeId, secondsAgo);
  }

  /// @notice the non-normalized vega GWAV for a given `strikeId` with GWAV interval `secondsAgo`
  function _vegaGWAV(uint strikeId, uint secondsAgo) internal view returns (uint) {
    return gwavOracle.vegaGWAV(strikeId, secondsAgo);
  }

  /// @notice the option price GWAV for a given `strikeId` with GWAV interval `secondsAgo`
  function _optionPriceGWAV(uint strikeId, uint secondsAgo) internal view returns (uint callPrice, uint putPrice) {
    return gwavOracle.optionPriceGWAV(strikeId, secondsAgo);
  }

  //////////
  // Misc //
  //////////

  /// @dev format all strike related params before input into BlackScholes
  function _getBsInput(uint strikeId) internal view returns (BlackScholes.BlackScholesInputs memory bsInput) {
    (IOptionMarket.Strike memory strike, IOptionMarket.OptionBoard memory board) = optionMarket.getStrikeAndBoard(
      strikeId
    );
    bsInput = BlackScholes.BlackScholesInputs({
      timeToExpirySec: board.expiry - block.timestamp,
      volatilityDecimal: board.iv.multiplyDecimal(strike.skew),
      spotDecimal: synthetixAdapter.getSpotPriceForMarket(address(optionMarket)),
      strikePriceDecimal: strike.strikePrice,
      rateDecimal: greekCache.getGreekCacheParams().rateAndCarry
    });
  }

  /// @dev Check if position is long
  function _isLong(OptionType optionType) internal pure returns (bool) {
    return (optionType < OptionType.SHORT_CALL_BASE);
  }

  /// @dev Convert LyraAdapter.TradeInputParameters into OptionMarket.TradeInputParameters
  function _convertParams(TradeInputParameters memory _params)
    internal
    pure
    returns (IOptionMarket.TradeInputParameters memory)
  {
    return
      IOptionMarket.TradeInputParameters({
        strikeId: _params.strikeId,
        positionId: _params.positionId,
        iterations: _params.iterations,
        optionType: IOptionMarket.OptionType(uint(_params.optionType)),
        amount: _params.amount,
        setCollateralTo: _params.setCollateralTo,
        minTotalCost: _params.minTotalCost,
        maxTotalCost: _params.maxTotalCost
      });
  }

  /// @dev get lyra market addresses from LyraRegistry
  function _assignLyraRegistryMarketAddresses() internal {
    ILyraRegistry.OptionMarketAddresses memory addresses = lyraRegistry.getMarketAddresses(address(optionMarket));

    liquidityPool = ILiquidityPool(addresses.liquidityPool);
    greekCache = IOptionGreekCache(addresses.greekCache);
    optionPricer = IOptionMarketPricer(addresses.optionMarketPricer);
    optionToken = IOptionToken(addresses.optionToken);
    shortCollateral = IShortCollateral(addresses.shortCollateral);
    gwavOracle = IGWAVOracle(addresses.gwavOracle);
    quoteAsset = addresses.quoteAsset;
    baseAsset = addresses.baseAsset;
  }

  ////////////
  // Errors //
  ////////////

  error ExchangerBaseReceivedTooLow(address thrower, uint baseExpected, uint baseReceived);
  error ExchangerQuoteReceivedTooLow(address thrower, uint quoteExpected, uint quoteReceived);
}

// SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

import "../synthetix/SignedDecimalMath.sol";
import "../synthetix/DecimalMath.sol";
import "./FixedPointMathLib.sol";

/**
 * @title Geometric Moving Average Oracle
 * @author Lyra
 * @dev Instances of stored oracle data, "observations", are collected in the oracle array
 *
 * The GWAV values are calculated from the blockTimestamps and "q" accumulator values of two Observations. When
 * requested the closest observations are scaled to the requested timestamp.
 */
library GWAV {
  using DecimalMath for uint;
  using SignedDecimalMath for int;

  /// @dev Stores all past Observations and the current index
  struct Params {
    Observation[] observations;
    uint index;
  }

  /// @dev An observation holds the cumulative log value of all historic observations (accumulator)
  /// and other relevant fields for computing the next accumulator value.
  /// @dev A pair of oracle Observations is used to deduce the GWAV TWAP
  struct Observation {
    int q; // accumulator value used to compute GWAV
    uint nextVal; // value at the time the observation was made, used to calculate the next q value
    uint blockTimestamp;
  }

  /////////////
  // Setters //
  /////////////

  /**
   * @notice Initialize the oracle array by writing the first Observation.
   * @dev Called once for the lifecycle of the observations array
   * @dev First Observation uses blockTimestamp as the time interval to prevent manipulation of the GWAV immediately
   * after initialization
   * @param self Stores past Observations and the index of the latest Observation
   * @param newVal First observed value for blockTimestamp
   * @param blockTimestamp Timestamp of first Observation
   */
  function _initialize(
    Params storage self,
    uint newVal,
    uint blockTimestamp
  ) internal {
    // if Observation older than blockTimestamp is used for GWAV,
    // _getFirstBefore() will scale the first Observation "q" accordingly
    _initializeWithManualQ(self, FixedPointMathLib.ln((int(newVal))) * int(blockTimestamp), newVal, blockTimestamp);
  }

  /**
   * @notice Writes an oracle Observation to the GWAV array
   * @dev Writable at most once per block. BlockTimestamp must be > last.blockTimestamp
   * @param self Stores past Observations and the index of the latest Observation
   * @param nextVal Value at given blockTimestamp
   * @param blockTimestamp Current blockTimestamp
   */
  function _write(
    Params storage self,
    uint nextVal,
    uint blockTimestamp
  ) internal {
    Observation memory last = self.observations[self.index];

    // Ensure entries are sequential
    if (blockTimestamp < last.blockTimestamp) {
      revert InvalidBlockTimestamp(address(this), blockTimestamp, last.blockTimestamp);
    }

    // early return if we've already written an observation this block
    if (last.blockTimestamp == blockTimestamp) {
      self.observations[self.index].nextVal = nextVal;
      return;
    }
    // No reason to record an entry if it's the same as the last one
    if (last.nextVal == nextVal) return;

    // update accumulator value
    // assumes the market value between the previous and current blockTimstamps was "last.nextVal"
    uint timestampDelta = blockTimestamp - last.blockTimestamp;
    int newQ = last.q + FixedPointMathLib.ln((int(last.nextVal))) * int(timestampDelta);

    // update latest index and store Observation
    uint indexUpdated = (self.index + 1);
    self.observations.push(_transform(newQ, nextVal, blockTimestamp));
    self.index = indexUpdated;
  }

  /////////////
  // Getters //
  /////////////

  /**
   * @notice Calculates the geometric moving average between two Observations A & B. These observations are scaled to
   * the requested timestamps
   * @dev For the current GWAV value, "0" may be passed in for secondsAgo
   * @dev If timestamps A==B, returns the value at A/B.
   * @param self Stores past Observations and the index of the latest Observation
   * @param secondsAgoA Seconds from blockTimestamp to Observation A
   * @param secondsAgoB Seconds from blockTimestamp to Observation B
   */
  function getGWAVForPeriod(
    Params storage self,
    uint secondsAgoA,
    uint secondsAgoB
  ) public view returns (uint) {
    (int q0, uint t0) = queryFirstBeforeAndScale(self, block.timestamp, secondsAgoA);
    (int q1, uint t1) = queryFirstBeforeAndScale(self, block.timestamp, secondsAgoB);

    if (t0 == t1) {
      return uint(FixedPointMathLib.exp(q1 / int(t1)));
    }

    return uint(FixedPointMathLib.exp((q1 - q0) / int(t1 - t0)));
  }

  /**
   * @notice Returns the GWAV accumulator/timestamps values for each "secondsAgo" in the array `secondsAgos[]`
   * @param currentBlockTimestamp Timestamp of current block
   * @param secondsAgos Array of all timestamps for which to export accumulator/timestamp values
   */
  function observe(
    Params storage self,
    uint currentBlockTimestamp,
    uint[] memory secondsAgos
  ) public view returns (int[] memory qCumulatives, uint[] memory timestamps) {
    uint secondsAgosLength = secondsAgos.length;
    qCumulatives = new int[](secondsAgosLength);
    timestamps = new uint[](secondsAgosLength);
    for (uint i = 0; i < secondsAgosLength; ++i) {
      (qCumulatives[i], timestamps[i]) = queryFirstBefore(self, currentBlockTimestamp, secondsAgos[i]);
    }
  }

  //////////////////////////////////////////////////////
  // Querying observation closest to target timestamp //
  //////////////////////////////////////////////////////

  /**
   * @notice Finds the first observation before a timestamp "secondsAgo" from the "currentBlockTimestamp"
   * @dev If target falls between two Observations, the older one is returned
   * @dev See _queryFirstBefore() for edge cases where target lands
   * after the newest Observation or before the oldest Observation
   * @dev Reverts if secondsAgo exceeds the currentBlockTimestamp
   * @param self Stores past Observations and the index of the latest Observation
   * @param currentBlockTimestamp Timestamp of current block
   * @param secondsAgo Seconds from currentBlockTimestamp to target Observation
   */
  function queryFirstBefore(
    Params storage self,
    uint currentBlockTimestamp,
    uint secondsAgo
  ) internal view returns (int qCumulative, uint timestamp) {
    uint target = currentBlockTimestamp - secondsAgo;
    Observation memory beforeOrAt = _queryFirstBefore(self, target);

    return (beforeOrAt.q, beforeOrAt.blockTimestamp);
  }

  function queryFirstBeforeAndScale(
    Params storage self,
    uint currentBlockTimestamp,
    uint secondsAgo
  ) internal view returns (int qCumulative, uint timestamp) {
    uint target = currentBlockTimestamp - secondsAgo;
    Observation memory beforeOrAt = _queryFirstBefore(self, target);

    int timestampDelta = int(target - beforeOrAt.blockTimestamp);

    return (beforeOrAt.q + (FixedPointMathLib.ln(int(beforeOrAt.nextVal)) * timestampDelta), target);
  }

  /**
   * @notice Finds the first observation before the "target" timestamp
   * @dev Checks for trivial scenarios before entering _binarySearch()
   * @dev Assumes _initialize() has been called
   * @param self Stores past Observations and the index of the latest Observation
   * @param target BlockTimestamp of target Observation
   */
  function _queryFirstBefore(Params storage self, uint target) private view returns (Observation memory beforeOrAt) {
    // Case 1: target blockTimestamp is at or after the most recent Observation
    beforeOrAt = self.observations[self.index];
    if (beforeOrAt.blockTimestamp <= target) {
      return (beforeOrAt);
    }

    // Now, set to the oldest observation
    beforeOrAt = self.observations[0];

    // Case 2: target blockTimestamp is older than the oldest Observation
    // The observation is scaled to the target using the nextVal
    if (beforeOrAt.blockTimestamp > target) {
      return _transform((beforeOrAt.q * int(target)) / int(beforeOrAt.blockTimestamp), beforeOrAt.nextVal, target);
    }

    // Case 3: target is within the recorded Observations.
    return self.observations[_binarySearch(self, target)];
  }

  /**
   * @notice Finds closest Observation before target using binary search and returns its index
   * @dev Used when the target is located within the stored observation boundaries
   * e.g. Older than the most recent observation and younger, or the same age as, the oldest observation
   * @return foundIndex Returns the Observation which is older than target (instead of newer)
   * @param self Stores past Observations and the index of the latest Observation
   * @param target BlockTimestamp of target Observation
   */
  function _binarySearch(Params storage self, uint target) internal view returns (uint) {
    uint oldest = 0; // oldest observation
    uint newest = self.index; // newest observation
    uint i;
    while (true) {
      i = (oldest + newest) / 2;
      uint beforeOrAtTimestamp = self.observations[i].blockTimestamp;

      uint atOrAfterTimestamp = self.observations[i + 1].blockTimestamp;
      bool targetAtOrAfter = beforeOrAtTimestamp <= target;

      // check if we've found the answer!
      if (targetAtOrAfter && target <= atOrAfterTimestamp) break;

      if (!targetAtOrAfter) {
        newest = i - 1;
      } else {
        oldest = i + 1;
      }
    }

    return i;
  }

  /////////////
  // Utility //
  /////////////

  /**
   * @notice Creates the first Observation with manual Q accumulator value.
   * @param qVal Initial GWAV accumulator value
   * @param nextVal First observed value for blockTimestamp
   * @param blockTimestamp Timestamp of Observation
   */
  function _initializeWithManualQ(
    Params storage self,
    int qVal,
    uint nextVal,
    uint blockTimestamp
  ) internal {
    self.observations.push(Observation({q: qVal, nextVal: nextVal, blockTimestamp: blockTimestamp}));
  }

  /**
   * @dev Creates an Observation given a GWAV accumulator, latest value, and a blockTimestamp
   */
  function _transform(
    int newQ,
    uint nextVal,
    uint blockTimestamp
  ) private pure returns (Observation memory) {
    return Observation({q: newQ, nextVal: nextVal, blockTimestamp: blockTimestamp});
  }

  ////////////
  // Errors //
  ////////////
  error InvalidBlockTimestamp(address thrower, uint timestamp, uint lastObservedTimestamp);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

// Libraries
import "../synthetix/SignedDecimalMath.sol";
import "../synthetix/DecimalMath.sol";
import "./FixedPointMathLib.sol";

/**
 * @title BlackScholes
 * @author Lyra
 * @dev Contract to compute the black scholes price of options. Where the unit is unspecified, it should be treated as a
 * PRECISE_DECIMAL, which has 1e27 units of precision. The default decimal matches the ethereum standard of 1e18 units
 * of precision.
 */
library BlackScholes {
  using DecimalMath for uint;
  using SignedDecimalMath for int;

  struct PricesDeltaStdVega {
    uint callPrice;
    uint putPrice;
    int callDelta;
    int putDelta;
    uint vega;
    uint stdVega;
  }

  /**
   * @param timeToExpirySec Number of seconds to the expiry of the option
   * @param volatilityDecimal Implied volatility over the period til expiry as a percentage
   * @param spotDecimal The current price of the base asset
   * @param strikePriceDecimal The strikePrice price of the option
   * @param rateDecimal The percentage risk free rate + carry cost
   */
  struct BlackScholesInputs {
    uint timeToExpirySec;
    uint volatilityDecimal;
    uint spotDecimal;
    uint strikePriceDecimal;
    int rateDecimal;
  }

  uint private constant SECONDS_PER_YEAR = 31536000;
  /// @dev Internally this library uses 27 decimals of precision
  uint private constant PRECISE_UNIT = 1e27;
  uint private constant SQRT_TWOPI = 2506628274631000502415765285;
  /// @dev Below this value, return 0
  int private constant MIN_CDF_STD_DIST_INPUT = (int(PRECISE_UNIT) * -45) / 10; // -4.5
  /// @dev Above this value, return 1
  int private constant MAX_CDF_STD_DIST_INPUT = int(PRECISE_UNIT) * 10;
  /// @dev Value to use to avoid any division by 0 or values near 0
  uint private constant MIN_T_ANNUALISED = PRECISE_UNIT / SECONDS_PER_YEAR; // 1 second
  uint private constant MIN_VOLATILITY = PRECISE_UNIT / 10000; // 0.001%
  uint private constant VEGA_STANDARDISATION_MIN_DAYS = 7 days;
  /// @dev Magic numbers for normal CDF
  uint private constant SPLIT = 7071067811865470000000000000;
  uint private constant N0 = 220206867912376000000000000000;
  uint private constant N1 = 221213596169931000000000000000;
  uint private constant N2 = 112079291497871000000000000000;
  uint private constant N3 = 33912866078383000000000000000;
  uint private constant N4 = 6373962203531650000000000000;
  uint private constant N5 = 700383064443688000000000000;
  uint private constant N6 = 35262496599891100000000000;
  uint private constant M0 = 440413735824752000000000000000;
  uint private constant M1 = 793826512519948000000000000000;
  uint private constant M2 = 637333633378831000000000000000;
  uint private constant M3 = 296564248779674000000000000000;
  uint private constant M4 = 86780732202946100000000000000;
  uint private constant M5 = 16064177579207000000000000000;
  uint private constant M6 = 1755667163182640000000000000;
  uint private constant M7 = 88388347648318400000000000;

  /////////////////////////////////////
  // Option Pricing public functions //
  /////////////////////////////////////

  /**
   * @dev Returns call and put prices for options with given parameters.
   */
  function optionPrices(BlackScholesInputs memory bsInput) public pure returns (uint call, uint put) {
    uint tAnnualised = _annualise(bsInput.timeToExpirySec);
    uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();
    uint strikePricePrecise = bsInput.strikePriceDecimal.decimalToPreciseDecimal();
    int ratePrecise = bsInput.rateDecimal.decimalToPreciseDecimal();
    (int d1, int d2) = _d1d2(
      tAnnualised,
      bsInput.volatilityDecimal.decimalToPreciseDecimal(),
      spotPrecise,
      strikePricePrecise,
      ratePrecise
    );
    (call, put) = _optionPrices(tAnnualised, spotPrecise, strikePricePrecise, ratePrecise, d1, d2);
    return (call.preciseDecimalToDecimal(), put.preciseDecimalToDecimal());
  }

  /**
   * @dev Returns call/put prices and delta/stdVega for options with given parameters.
   */
  function pricesDeltaStdVega(BlackScholesInputs memory bsInput) public pure returns (PricesDeltaStdVega memory) {
    uint tAnnualised = _annualise(bsInput.timeToExpirySec);
    uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();

    (int d1, int d2) = _d1d2(
      tAnnualised,
      bsInput.volatilityDecimal.decimalToPreciseDecimal(),
      spotPrecise,
      bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
      bsInput.rateDecimal.decimalToPreciseDecimal()
    );
    (uint callPrice, uint putPrice) = _optionPrices(
      tAnnualised,
      spotPrecise,
      bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
      bsInput.rateDecimal.decimalToPreciseDecimal(),
      d1,
      d2
    );
    (uint vegaPrecise, uint stdVegaPrecise) = _standardVega(d1, spotPrecise, bsInput.timeToExpirySec);
    (int callDelta, int putDelta) = _delta(d1);

    return
      PricesDeltaStdVega(
        callPrice.preciseDecimalToDecimal(),
        putPrice.preciseDecimalToDecimal(),
        callDelta.preciseDecimalToDecimal(),
        putDelta.preciseDecimalToDecimal(),
        vegaPrecise.preciseDecimalToDecimal(),
        stdVegaPrecise.preciseDecimalToDecimal()
      );
  }

  /**
   * @dev Returns call delta given parameters.
   */

  function delta(BlackScholesInputs memory bsInput) public pure returns (int callDeltaDecimal, int putDeltaDecimal) {
    uint tAnnualised = _annualise(bsInput.timeToExpirySec);
    uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();

    (int d1, ) = _d1d2(
      tAnnualised,
      bsInput.volatilityDecimal.decimalToPreciseDecimal(),
      spotPrecise,
      bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
      bsInput.rateDecimal.decimalToPreciseDecimal()
    );

    (int callDelta, int putDelta) = _delta(d1);
    return (callDelta.preciseDecimalToDecimal(), putDelta.preciseDecimalToDecimal());
  }

  /**
   * @dev Returns non-normalized vega given parameters. Quoted in cents.
   */
  function vega(BlackScholesInputs memory bsInput) public pure returns (uint vegaDecimal) {
    uint tAnnualised = _annualise(bsInput.timeToExpirySec);
    uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();

    (int d1, ) = _d1d2(
      tAnnualised,
      bsInput.volatilityDecimal.decimalToPreciseDecimal(),
      spotPrecise,
      bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
      bsInput.rateDecimal.decimalToPreciseDecimal()
    );
    return _vega(tAnnualised, spotPrecise, d1).preciseDecimalToDecimal();
  }

  //////////////////////
  // Computing Greeks //
  //////////////////////

  /**
   * @dev Returns internal coefficients of the Black-Scholes call price formula, d1 and d2.
   * @param tAnnualised Number of years to expiry
   * @param volatility Implied volatility over the period til expiry as a percentage
   * @param spot The current price of the base asset
   * @param strikePrice The strikePrice price of the option
   * @param rate The percentage risk free rate + carry cost
   */
  function _d1d2(
    uint tAnnualised,
    uint volatility,
    uint spot,
    uint strikePrice,
    int rate
  ) internal pure returns (int d1, int d2) {
    // Set minimum values for tAnnualised and volatility to not break computation in extreme scenarios
    // These values will result in option prices reflecting only the difference in stock/strikePrice, which is expected.
    // This should be caught before calling this function, however the function shouldn't break if the values are 0.
    tAnnualised = tAnnualised < MIN_T_ANNUALISED ? MIN_T_ANNUALISED : tAnnualised;
    volatility = volatility < MIN_VOLATILITY ? MIN_VOLATILITY : volatility;

    int vtSqrt = int(volatility.multiplyDecimalRoundPrecise(_sqrtPrecise(tAnnualised)));
    int log = FixedPointMathLib.lnPrecise(int(spot.divideDecimalRoundPrecise(strikePrice)));
    int v2t = (int(volatility.multiplyDecimalRoundPrecise(volatility) / 2) + rate).multiplyDecimalRoundPrecise(
      int(tAnnualised)
    );
    d1 = (log + v2t).divideDecimalRoundPrecise(vtSqrt);
    d2 = d1 - vtSqrt;
  }

  /**
   * @dev Internal coefficients of the Black-Scholes call price formula.
   * @param tAnnualised Number of years to expiry
   * @param spot The current price of the base asset
   * @param strikePrice The strikePrice price of the option
   * @param rate The percentage risk free rate + carry cost
   * @param d1 Internal coefficient of Black-Scholes
   * @param d2 Internal coefficient of Black-Scholes
   */
  function _optionPrices(
    uint tAnnualised,
    uint spot,
    uint strikePrice,
    int rate,
    int d1,
    int d2
  ) internal pure returns (uint call, uint put) {
    uint strikePricePV = strikePrice.multiplyDecimalRoundPrecise(
      FixedPointMathLib.expPrecise(int(-rate.multiplyDecimalRoundPrecise(int(tAnnualised))))
    );
    uint spotNd1 = spot.multiplyDecimalRoundPrecise(_stdNormalCDF(d1));
    uint strikePriceNd2 = strikePricePV.multiplyDecimalRoundPrecise(_stdNormalCDF(d2));

    // We clamp to zero if the minuend is less than the subtrahend
    // In some scenarios it may be better to compute put price instead and derive call from it depending on which way
    // around is more precise.
    call = strikePriceNd2 <= spotNd1 ? spotNd1 - strikePriceNd2 : 0;
    put = call + strikePricePV;
    put = spot <= put ? put - spot : 0;
  }

  /*
   * Greeks
   */

  /**
   * @dev Returns the option's delta value
   * @param d1 Internal coefficient of Black-Scholes
   */
  function _delta(int d1) internal pure returns (int callDelta, int putDelta) {
    callDelta = int(_stdNormalCDF(d1));
    putDelta = callDelta - int(PRECISE_UNIT);
  }

  /**
   * @dev Returns the option's vega value based on d1. Quoted in cents.
   *
   * @param d1 Internal coefficient of Black-Scholes
   * @param tAnnualised Number of years to expiry
   * @param spot The current price of the base asset
   */
  function _vega(
    uint tAnnualised,
    uint spot,
    int d1
  ) internal pure returns (uint) {
    return _sqrtPrecise(tAnnualised).multiplyDecimalRoundPrecise(_stdNormal(d1).multiplyDecimalRoundPrecise(spot));
  }

  /**
   * @dev Returns the option's vega value with expiry modified to be at least VEGA_STANDARDISATION_MIN_DAYS
   * @param d1 Internal coefficient of Black-Scholes
   * @param spot The current price of the base asset
   * @param timeToExpirySec Number of seconds to expiry
   */
  function _standardVega(
    int d1,
    uint spot,
    uint timeToExpirySec
  ) internal pure returns (uint, uint) {
    uint tAnnualised = _annualise(timeToExpirySec);
    uint normalisationFactor = _getVegaNormalisationFactorPrecise(timeToExpirySec);
    uint vegaPrecise = _vega(tAnnualised, spot, d1);
    return (vegaPrecise, vegaPrecise.multiplyDecimalRoundPrecise(normalisationFactor));
  }

  function _getVegaNormalisationFactorPrecise(uint timeToExpirySec) internal pure returns (uint) {
    timeToExpirySec = timeToExpirySec < VEGA_STANDARDISATION_MIN_DAYS ? VEGA_STANDARDISATION_MIN_DAYS : timeToExpirySec;
    uint daysToExpiry = timeToExpirySec / 1 days;
    uint thirty = 30 * PRECISE_UNIT;
    return _sqrtPrecise(thirty / daysToExpiry) / 100;
  }

  /////////////////////
  // Math Operations //
  /////////////////////

  /**
   * @dev Compute the absolute value of `val`.
   *
   * @param val The number to absolute value.
   */
  function _abs(int val) internal pure returns (uint) {
    return uint(val < 0 ? -val : val);
  }

  /// @notice Calculates the square root of x, rounding down (borrowed from https://github.com/paulrberg/prb-math)
  /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
  /// @param x The uint256 number for which to calculate the square root.
  /// @return result The result as an uint256.
  function _sqrt(uint x) internal pure returns (uint result) {
    if (x == 0) {
      return 0;
    }

    // Calculate the square root of the perfect square of a power of two that is the closest to x.
    uint xAux = uint(x);
    result = 1;
    if (xAux >= 0x100000000000000000000000000000000) {
      xAux >>= 128;
      result <<= 64;
    }
    if (xAux >= 0x10000000000000000) {
      xAux >>= 64;
      result <<= 32;
    }
    if (xAux >= 0x100000000) {
      xAux >>= 32;
      result <<= 16;
    }
    if (xAux >= 0x10000) {
      xAux >>= 16;
      result <<= 8;
    }
    if (xAux >= 0x100) {
      xAux >>= 8;
      result <<= 4;
    }
    if (xAux >= 0x10) {
      xAux >>= 4;
      result <<= 2;
    }
    if (xAux >= 0x8) {
      result <<= 1;
    }

    // The operations can never overflow because the result is max 2^127 when it enters this block.
    unchecked {
      result = (result + x / result) >> 1;
      result = (result + x / result) >> 1;
      result = (result + x / result) >> 1;
      result = (result + x / result) >> 1;
      result = (result + x / result) >> 1;
      result = (result + x / result) >> 1;
      result = (result + x / result) >> 1; // Seven iterations should be enough
      uint roundedDownResult = x / result;
      return result >= roundedDownResult ? roundedDownResult : result;
    }
  }

  /**
   * @dev Returns the square root of the value using Newton's method.
   */
  function _sqrtPrecise(uint x) internal pure returns (uint) {
    // Add in an extra unit factor for the square root to gobble;
    // otherwise, sqrt(x * UNIT) = sqrt(x) * sqrt(UNIT)
    return _sqrt(x * PRECISE_UNIT);
  }

  /**
   * @dev The standard normal distribution of the value.
   */
  function _stdNormal(int x) internal pure returns (uint) {
    return
      FixedPointMathLib.expPrecise(int(-x.multiplyDecimalRoundPrecise(x / 2))).divideDecimalRoundPrecise(SQRT_TWOPI);
  }

  /**
   * @dev The standard normal cumulative distribution of the value.
   * borrowed from a C++ implementation https://stackoverflow.com/a/23119456
   */
  function _stdNormalCDF(int x) public pure returns (uint) {
    uint z = _abs(x);
    int c;

    if (z <= 37 * PRECISE_UNIT) {
      uint e = FixedPointMathLib.expPrecise(-int(z.multiplyDecimalRoundPrecise(z / 2)));
      if (z < SPLIT) {
        c = int(
          (_stdNormalCDFNumerator(z).divideDecimalRoundPrecise(_stdNormalCDFDenom(z)).multiplyDecimalRoundPrecise(e))
        );
      } else {
        uint f = (z +
          PRECISE_UNIT.divideDecimalRoundPrecise(
            z +
              (2 * PRECISE_UNIT).divideDecimalRoundPrecise(
                z +
                  (3 * PRECISE_UNIT).divideDecimalRoundPrecise(
                    z + (4 * PRECISE_UNIT).divideDecimalRoundPrecise(z + ((PRECISE_UNIT * 13) / 20))
                  )
              )
          ));
        c = int(e.divideDecimalRoundPrecise(f.multiplyDecimalRoundPrecise(SQRT_TWOPI)));
      }
    }
    return uint((x <= 0 ? c : (int(PRECISE_UNIT) - c)));
  }

  /**
   * @dev Helper for _stdNormalCDF
   */
  function _stdNormalCDFNumerator(uint z) internal pure returns (uint) {
    uint numeratorInner = ((((((N6 * z) / PRECISE_UNIT + N5) * z) / PRECISE_UNIT + N4) * z) / PRECISE_UNIT + N3);
    return (((((numeratorInner * z) / PRECISE_UNIT + N2) * z) / PRECISE_UNIT + N1) * z) / PRECISE_UNIT + N0;
  }

  /**
   * @dev Helper for _stdNormalCDF
   */
  function _stdNormalCDFDenom(uint z) internal pure returns (uint) {
    uint denominatorInner = ((((((M7 * z) / PRECISE_UNIT + M6) * z) / PRECISE_UNIT + M5) * z) / PRECISE_UNIT + M4);
    return
      (((((((denominatorInner * z) / PRECISE_UNIT + M3) * z) / PRECISE_UNIT + M2) * z) / PRECISE_UNIT + M1) * z) /
      PRECISE_UNIT +
      M0;
  }

  /**
   * @dev Converts an integer number of seconds to a fractional number of years.
   */
  function _annualise(uint secs) internal pure returns (uint yearFraction) {
    return secs.divideDecimalRoundPrecise(SECONDS_PER_YEAR);
  }
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
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
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

// Interfaces
import "./IOptionMarket.sol";
import "./ISynthetixAdapter.sol";
import "./IOptionGreekCache.sol";
import "openzeppelin-contracts-4.4.1/token/ERC721/IERC721.sol";

// For full documentation refer to @lyrafinance/protocol/contracts/OptionToken.sol";
interface IOptionToken is IERC721 {
  enum PositionState {
    EMPTY,
    ACTIVE,
    CLOSED,
    LIQUIDATED,
    SETTLED,
    MERGED
  }

  enum PositionUpdatedType {
    OPENED,
    ADJUSTED,
    CLOSED,
    SPLIT_FROM,
    SPLIT_INTO,
    MERGED,
    MERGED_INTO,
    SETTLED,
    LIQUIDATED,
    TRANSFER
  }

  struct OptionPosition {
    uint positionId;
    uint strikeId;
    IOptionMarket.OptionType optionType;
    uint amount;
    uint collateral;
    PositionState state;
  }

  struct PartialCollateralParameters {
    // Percent of collateral used for penalty (amm + sm + liquidator fees)
    uint penaltyRatio;
    // Percent of penalty used for amm fees
    uint liquidatorFeeRatio;
    // Percent of penalty used for SM fees
    uint smFeeRatio;
    // Minimal value of quote that is used to charge a fee
    uint minLiquidationFee;
  }

  struct PositionWithOwner {
    uint positionId;
    uint strikeId;
    IOptionMarket.OptionType optionType;
    uint amount;
    uint collateral;
    PositionState state;
    address owner;
  }

  struct LiquidationFees {
    uint returnCollateral; // quote || base
    uint lpPremiums; // quote || base
    uint lpFee; // quote || base
    uint liquidatorFee; // quote || base
    uint smFee; // quote || base
    uint insolventAmount; // quote
  }

  function positions(uint positionId) external view returns (OptionPosition memory);

  function nextId() external view returns (uint);

  function partialCollatParams() external view returns (PartialCollateralParameters memory);

  function baseURI() external view returns (string memory);

  function canLiquidate(
    OptionPosition memory position,
    uint expiry,
    uint strikePrice,
    uint spotPrice
  ) external view returns (bool);

  function getLiquidationFees(
    uint gwavPremium, // quote || base
    uint userPositionCollateral, // quote || base
    uint convertedMinLiquidationFee, // quote || base
    uint insolvencyMultiplier // 1 for quote || spotPrice for base
  ) external view returns (LiquidationFees memory liquidationFees);

  ///////////////
  // Transfers //
  ///////////////

  function split(
    uint positionId,
    uint newAmount,
    uint newCollateral,
    address recipient
  ) external returns (uint newPositionId);

  function merge(uint[] memory positionIds) external;

  //////////
  // View //
  //////////

  /// @dev Returns the PositionState of a given positionId
  function getPositionState(uint positionId) external view returns (PositionState);

  /// @dev Returns an OptionPosition struct of a given positionId
  function getOptionPosition(uint positionId) external view returns (OptionPosition memory);

  /// @dev Returns an array of OptionPosition structs given an array of positionIds
  function getOptionPositions(uint[] memory positionIds) external view returns (OptionPosition[] memory);

  /// @dev Returns a PositionWithOwner struct of a given positionId (same as OptionPosition but with owner)
  function getPositionWithOwner(uint positionId) external view returns (PositionWithOwner memory);

  /// @dev Returns an array of PositionWithOwner structs given an array of positionIds
  function getPositionsWithOwner(uint[] memory positionIds) external view returns (PositionWithOwner[] memory);

  /// @notice Returns an array of OptionPosition structs owned by a given address
  /// @dev Meant to be used offchain as it can run out of gas
  function getOwnerPositions(address target) external view returns (OptionPosition[] memory);

  /// @dev returns PartialCollateralParameters struct
  function getPartialCollatParams() external view returns (PartialCollateralParameters memory);

  ////////////
  // Events //
  ///////////

  /**
   * @dev Emitted when the URI is modified
   */
  event URISet(string URI);

  /**
   * @dev Emitted when partial collateral parameters are modified
   */
  event PartialCollateralParamsSet(PartialCollateralParameters partialCollateralParams);

  /**
   * @dev Emitted when a position is minted, adjusted, burned, merged or split.
   */
  event PositionUpdated(
    uint indexed positionId,
    address indexed owner,
    PositionUpdatedType indexed updatedType,
    OptionPosition position,
    uint timestamp
  );

  ////////////
  // Errors //
  ////////////

  // Admin
  error InvalidPartialCollateralParameters(address thrower, PartialCollateralParameters partialCollatParams);

  // Adjusting
  error AdjustmentResultsInMinimumCollateralNotBeingMet(address thrower, OptionPosition position, uint spotPrice);
  error CannotClosePositionZero(address thrower);
  error CannotOpenZeroAmount(address thrower);
  error CannotAdjustInvalidPosition(
    address thrower,
    uint positionId,
    bool invalidPositionId,
    bool positionInactive,
    bool strikeMismatch,
    bool optionTypeMismatch
  );
  error OnlyOwnerCanAdjustPosition(address thrower, uint positionId, address trader, address owner);
  error FullyClosingWithNonZeroSetCollateral(address thrower, uint positionId, uint setCollateralTo);
  error AddingCollateralToInvalidPosition(
    address thrower,
    uint positionId,
    bool invalidPositionId,
    bool positionInactive,
    bool isShort
  );

  // Liquidation
  error PositionNotLiquidatable(address thrower, OptionPosition position, uint spotPrice);

  // Splitting
  error SplittingUnapprovedPosition(address thrower, address caller, uint positionId);
  error InvalidSplitAmount(address thrower, uint originalPositionAmount, uint splitAmount);
  error ResultingOriginalPositionLiquidatable(address thrower, OptionPosition position, uint spotPrice);
  error ResultingNewPositionLiquidatable(address thrower, OptionPosition position, uint spotPrice);

  // Merging
  error MustMergeTwoOrMorePositions(address thrower);
  error MergingUnapprovedPosition(address thrower, address caller, uint positionId);
  error PositionMismatchWhenMerging(
    address thrower,
    OptionPosition firstPosition,
    OptionPosition nextPosition,
    bool ownerMismatch,
    bool strikeMismatch,
    bool optionTypeMismatch,
    bool duplicatePositionId
  );

  // Access
  error StrikeIsSettled(address thrower, uint strikeId);
  error OnlyOptionMarket(address thrower, address caller, address optionMarket);
  error OnlyShortCollateral(address thrower, address caller, address shortCollateral);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

import "./ILiquidityPool.sol";
import "./ISynthetixAdapter.sol";
import "./IOptionMarketPricer.sol";

// For full documentation refer to @lyrafinance/protocol/contracts/OptionMarket.sol";
interface IOptionMarket {
  enum TradeDirection {
    OPEN,
    CLOSE,
    LIQUIDATE
  }

  enum OptionType {
    LONG_CALL,
    LONG_PUT,
    SHORT_CALL_BASE,
    SHORT_CALL_QUOTE,
    SHORT_PUT_QUOTE
  }

  /// @notice For returning more specific errors
  enum NonZeroValues {
    BASE_IV,
    SKEW,
    STRIKE_PRICE,
    ITERATIONS,
    STRIKE_ID
  }

  ///////////////////
  // Internal Data //
  ///////////////////

  struct Strike {
    // strike listing identifier
    uint id;
    // strike price
    uint strikePrice;
    // volatility component specific to the strike listing (boardIv * skew = vol of strike)
    uint skew;
    // total user long call exposure
    uint longCall;
    // total user short call (base collateral) exposure
    uint shortCallBase;
    // total user short call (quote collateral) exposure
    uint shortCallQuote;
    // total user long put exposure
    uint longPut;
    // total user short put (quote collateral) exposure
    uint shortPut;
    // id of board to which strike belongs
    uint boardId;
  }

  struct OptionBoard {
    // board identifier
    uint id;
    // expiry of all strikes belonging to board
    uint expiry;
    // volatility component specific to board (boardIv * skew = vol of strike)
    uint iv;
    // admin settable flag blocking all trading on this board
    bool frozen;
    // list of all strikes belonging to this board
    uint[] strikeIds;
  }

  ///////////////
  // In-memory //
  ///////////////

  struct OptionMarketParameters {
    // max allowable expiry of added boards
    uint maxBoardExpiry;
    // security module address
    address securityModule;
    // fee portion reserved for Lyra DAO
    uint feePortionReserved;
    // expected fee charged to LPs, used for pricing short_call_base settlement
    uint staticBaseSettlementFee;
  }

  struct TradeInputParameters {
    // id of strike
    uint strikeId;
    // OptionToken ERC721 id for position (set to 0 for new positions)
    uint positionId;
    // number of sub-orders to break order into (reduces slippage)
    uint iterations;
    // type of option to trade
    OptionType optionType;
    // number of contracts to trade
    uint amount;
    // final amount of collateral to leave in OptionToken position
    uint setCollateralTo;
    // revert trade if totalCost is below this value
    uint minTotalCost;
    // revert trade if totalCost is above this value
    uint maxTotalCost;
  }

  struct TradeParameters {
    bool isBuy;
    bool isForceClose;
    TradeDirection tradeDirection;
    OptionType optionType;
    uint amount;
    uint expiry;
    uint strikePrice;
    ILiquidityPool.Liquidity liquidity;
    ISynthetixAdapter.ExchangeParams exchangeParams;
  }

  struct TradeEventData {
    uint expiry;
    uint strikePrice;
    OptionType optionType;
    TradeDirection tradeDirection;
    uint amount;
    uint setCollateralTo;
    bool isForceClose;
    uint spotPrice;
    uint reservedFee;
    uint totalCost;
  }

  struct LiquidationEventData {
    address rewardBeneficiary;
    address caller;
    uint returnCollateral; // quote || base
    uint lpPremiums; // quote || base
    uint lpFee; // quote || base
    uint liquidatorFee; // quote || base
    uint smFee; // quote || base
    uint insolventAmount; // quote
  }

  struct Result {
    uint positionId;
    uint totalCost;
    uint totalFee;
  }

  ///////////////
  // Variables //
  ///////////////

  /// @notice claim all reserved option fees
  function smClaim() external;

  ///////////
  // Views //
  ///////////

  function getOptionMarketParams() external view returns (OptionMarketParameters memory);

  function getLiveBoards() external view returns (uint[] memory _liveBoards);

  function getNumLiveBoards() external view returns (uint numLiveBoards);

  function getStrikeAndExpiry(uint strikeId) external view returns (uint strikePrice, uint expiry);

  function getBoardStrikes(uint boardId) external view returns (uint[] memory strikeIds);

  function getStrike(uint strikeId) external view returns (Strike memory);

  function getOptionBoard(uint boardId) external view returns (OptionBoard memory);

  function getStrikeAndBoard(uint strikeId) external view returns (Strike memory, OptionBoard memory);

  function getBoardAndStrikeDetails(uint boardId)
    external
    view
    returns (
      OptionBoard memory,
      Strike[] memory,
      uint[] memory,
      uint
    );

  ////////////////////
  // User functions //
  ////////////////////

  function openPosition(TradeInputParameters memory params) external returns (Result memory result);

  function closePosition(TradeInputParameters memory params) external returns (Result memory result);

  /**
   * @notice Attempts to reduce or fully close position within cost bounds while ignoring delta trading cutoffs.
   *
   * @param params The parameters for the requested trade
   */
  function forceClosePosition(TradeInputParameters memory params) external returns (Result memory result);

  function addCollateral(uint positionId, uint amountCollateral) external;

  function liquidatePosition(uint positionId, address rewardBeneficiary) external;

  /////////////////////////////////
  // Board Expiry and settlement //
  /////////////////////////////////

  function settleExpiredBoard(uint boardId) external;

  function getSettlementParameters(uint strikeId)
    external
    view
    returns (
      uint strikePrice,
      uint priceAtExpiry,
      uint strikeToBaseReturned
    );

  ////////////
  // Events //
  ////////////

  /**
   * @dev Emitted when a Board is created.
   */
  event BoardCreated(uint indexed boardId, uint expiry, uint baseIv, bool frozen);

  /**
   * @dev Emitted when a Board frozen is updated.
   */
  event BoardFrozen(uint indexed boardId, bool frozen);

  /**
   * @dev Emitted when a Board new baseIv is set.
   */
  event BoardBaseIvSet(uint indexed boardId, uint baseIv);

  /**
   * @dev Emitted when a Strike new skew is set.
   */
  event StrikeSkewSet(uint indexed strikeId, uint skew);

  /**
   * @dev Emitted when a Strike is added to a board
   */
  event StrikeAdded(uint indexed boardId, uint indexed strikeId, uint strikePrice, uint skew);

  /**
   * @dev Emitted when parameters for the option market are adjusted
   */
  event OptionMarketParamsSet(OptionMarketParameters optionMarketParams);

  /**
   * @dev Emitted whenever the security module claims their portion of fees
   */
  event SMClaimed(address securityModule, uint quoteAmount, uint baseAmount);

  /**
   * @dev Emitted when a Position is opened, closed or liquidated.
   */
  event Trade(
    address indexed trader,
    uint indexed strikeId,
    uint indexed positionId,
    TradeEventData trade,
    IOptionMarketPricer.TradeResult[] tradeResults,
    LiquidationEventData liquidation,
    uint timestamp
  );

  /**
   * @dev Emitted when a Board is liquidated.
   */
  event BoardSettled(
    uint indexed boardId,
    uint spotPriceAtExpiry,
    uint totalUserLongProfitQuote,
    uint totalBoardLongCallCollateral,
    uint totalBoardLongPutCollateral,
    uint totalAMMShortCallProfitBase,
    uint totalAMMShortCallProfitQuote,
    uint totalAMMShortPutProfitQuote
  );

  ////////////
  // Errors //
  ////////////
  // General purpose
  error ExpectedNonZeroValue(address thrower, NonZeroValues valueType);

  // Admin
  error InvalidOptionMarketParams(address thrower, OptionMarketParameters optionMarketParams);

  // Board related
  error InvalidBoardId(address thrower, uint boardId);
  error InvalidExpiryTimestamp(address thrower, uint currentTime, uint expiry, uint maxBoardExpiry);
  error BoardNotFrozen(address thrower, uint boardId);
  error BoardAlreadySettled(address thrower, uint boardId);
  error BoardNotExpired(address thrower, uint boardId);

  // Strike related
  error InvalidStrikeId(address thrower, uint strikeId);
  error StrikeSkewLengthMismatch(address thrower, uint strikesLength, uint skewsLength);

  // Trade
  error TotalCostOutsideOfSpecifiedBounds(address thrower, uint totalCost, uint minCost, uint maxCost);
  error BoardIsFrozen(address thrower, uint boardId);
  error BoardExpired(address thrower, uint boardId, uint boardExpiry, uint currentTime);
  error TradeIterationsHasRemainder(
    address thrower,
    uint iterations,
    uint expectedAmount,
    uint tradeAmount,
    uint totalAmount
  );

  // Access
  error OnlySecurityModule(address thrower, address caller, address securityModule);

  // Token transfers
  error BaseTransferFailed(address thrower, address from, address to, uint amount);
  error QuoteTransferFailed(address thrower, address from, address to, uint amount);
}

//SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

// For full documentation refer to @lyrafinance/protocol/contracts/LiquidityPool.sol";
interface ILiquidityPool {
  struct Collateral {
    uint quote;
    uint base;
  }

  /// These values are all in quoteAsset amounts.
  struct Liquidity {
    // Amount of liquidity available for option collateral and premiums
    uint freeLiquidity;
    // Amount of liquidity available for withdrawals - different to freeLiquidity
    uint burnableLiquidity;
    // Amount of liquidity reserved for long options sold to traders
    uint usedCollatLiquidity;
    // Portion of liquidity reserved for delta hedging (quote outstanding)
    uint pendingDeltaLiquidity;
    // Current value of delta hedge
    uint usedDeltaLiquidity;
    // Net asset value, including everything and netOptionValue
    uint NAV;
  }

  struct QueuedDeposit {
    uint id;
    // Who will receive the LiquidityToken minted for this deposit after the wait time
    address beneficiary;
    // The amount of quoteAsset deposited to be converted to LiquidityToken after wait time
    uint amountLiquidity;
    // The amount of LiquidityToken minted. Will equal to 0 if not processed
    uint mintedTokens;
    uint depositInitiatedTime;
  }

  struct QueuedWithdrawal {
    uint id;
    // Who will receive the quoteAsset returned after burning the LiquidityToken
    address beneficiary;
    // The amount of LiquidityToken being burnt after the wait time
    uint amountTokens;
    // The amount of quote transferred. Will equal to 0 if process not started
    uint quoteSent;
    uint withdrawInitiatedTime;
  }

  struct LiquidityPoolParameters {
    // The minimum amount of quoteAsset for a deposit, or the amount of LiquidityToken for a withdrawal
    uint minDepositWithdraw;
    // Time between initiating a deposit and when it can be processed
    uint depositDelay;
    // Time between initiating a withdrawal and when it can be processed
    uint withdrawalDelay;
    // Fee charged on withdrawn funds
    uint withdrawalFee;
    // Percentage of NAV below which the liquidity CB fires
    uint liquidityCBThreshold;
    // Length of time after the liq. CB stops firing during which deposits/withdrawals are still blocked
    uint liquidityCBTimeout;
    // Difference between the spot and GWAV baseline IVs after which point the vol CB will fire
    uint ivVarianceCBThreshold;
    // Difference between the spot and GWAV skew ratios after which point the vol CB will fire
    uint skewVarianceCBThreshold;
    // Length of time after the (base) vol. CB stops firing during which deposits/withdrawals are still blocked
    uint ivVarianceCBTimeout;
    // Length of time after the (skew) vol. CB stops firing during which deposits/withdrawals are still blocked
    uint skewVarianceCBTimeout;
    // The address of the "guardian"
    address guardianMultisig;
    // Length of time a deposit/withdrawal since initiation for before a guardian can force process their transaction
    uint guardianDelay;
    // When a new board is listed, block deposits/withdrawals
    uint boardSettlementCBTimeout;
    // When exchanging, don't exchange if fee is above this value
    uint maxFeePaid;
  }

  function poolHedger() external view returns (address);

  function queuedDeposits(uint id) external view returns (QueuedDeposit memory);

  function totalQueuedDeposits() external view returns (uint);

  function queuedDepositHead() external view returns (uint);

  function nextQueuedDepositId() external view returns (uint);

  function queuedWithdrawals(uint id) external view returns (QueuedWithdrawal memory);

  function totalQueuedWithdrawals() external view returns (uint);

  function queuedWithdrawalHead() external view returns (uint);

  function nextQueuedWithdrawalId() external view returns (uint);

  function CBTimestamp() external view returns (uint);

  /// @dev Amount of collateral locked for outstanding calls and puts sold to users
  function lockedCollateral() external view returns (Collateral memory);

  /// @dev Total amount of quoteAsset reserved for all settled options that have yet to be paid out
  function totalOutstandingSettlements() external view returns (uint);

  /// @dev Total value not transferred to this contract for all shorts that didn't have enough collateral after expiry
  function insolventSettlementAmount() external view returns (uint);

  /// @dev Total value not transferred to this contract for all liquidations that didn't have enough collateral when liquidated
  function liquidationInsolventAmount() external view returns (uint);

  function initiateDeposit(address beneficiary, uint amountQuote) external;

  function initiateWithdraw(address beneficiary, uint amountLiquidityToken) external;

  function processDepositQueue(uint limit) external;

  function processWithdrawalQueue(uint limit) external;

  function updateCBs() external;

  function getTotalTokenSupply() external view returns (uint);

  function getTokenPriceWithCheck()
    external
    view
    returns (
      uint tokenPrice,
      bool isStale,
      uint circuitBreakerExpiry
    );

  function getTokenPrice() external view returns (uint);

  function getCurrentLiquidity() external view returns (Liquidity memory);

  function getLiquidity(uint spotPrice) external view returns (Liquidity memory);

  function getTotalPoolValueQuote() external view returns (uint);

  function exchangeBase() external;

  function getLpParams() external view returns (LiquidityPoolParameters memory);

  ////////////
  // Events //
  ////////////

  /// @dev Emitted whenever the pool paramters are updated
  event LiquidityPoolParametersUpdated(LiquidityPoolParameters lpParams);

  /// @dev Emitted whenever the poolHedger address is modified
  event PoolHedgerUpdated(address poolHedger);

  /// @dev Emitted when quote is locked.
  event QuoteLocked(uint quoteLocked, uint lockedCollateralQuote);

  /// @dev Emitted when quote is freed.
  event QuoteFreed(uint quoteFreed, uint lockedCollateralQuote);

  /// @dev Emitted when base is locked.
  event BaseLocked(uint baseLocked, uint lockedCollateralBase);

  /// @dev Emitted when base is freed.
  event BaseFreed(uint baseFreed, uint lockedCollateralBase);

  /// @dev Emitted when a board is settled.
  event BoardSettlement(uint insolventSettlementAmount, uint amountQuoteReserved, uint totalOutstandingSettlements);

  /// @dev Emitted when reserved quote is sent.
  event OutstandingSettlementSent(address indexed user, uint amount, uint totalOutstandingSettlements);

  /// @dev Emitted whenever quote is exchanged for base
  event BasePurchased(uint quoteSpent, uint baseReceived);

  /// @dev Emitted whenever base is exchanged for quote
  event BaseSold(uint amountBase, uint quoteReceived);

  /// @dev Emitted whenever premium is sent to a trader closing their position
  event PremiumTransferred(address indexed recipient, uint recipientPortion, uint optionMarketPortion);

  /// @dev Emitted whenever quote is sent to the PoolHedger
  event QuoteTransferredToPoolHedger(uint amountQuote);

  /// @dev Emitted whenever the insolvent settlement amount is updated (settlement and excess)
  event InsolventSettlementAmountUpdated(uint amountQuoteAdded, uint totalInsolventSettlementAmount);

  /// @dev Emitted whenever a user deposits and enters the queue.
  event DepositQueued(
    address indexed depositor,
    address indexed beneficiary,
    uint indexed depositQueueId,
    uint amountDeposited,
    uint totalQueuedDeposits,
    uint timestamp
  );

  /// @dev Emitted whenever a deposit gets processed. Note, can be processed without being queued.
  ///  QueueId of 0 indicates it was not queued.
  event DepositProcessed(
    address indexed caller,
    address indexed beneficiary,
    uint indexed depositQueueId,
    uint amountDeposited,
    uint tokenPrice,
    uint tokensReceived,
    uint timestamp
  );

  /// @dev Emitted whenever a deposit gets processed. Note, can be processed without being queued.
  ///  QueueId of 0 indicates it was not queued.
  event WithdrawProcessed(
    address indexed caller,
    address indexed beneficiary,
    uint indexed withdrawalQueueId,
    uint amountWithdrawn,
    uint tokenPrice,
    uint quoteReceived,
    uint totalQueuedWithdrawals,
    uint timestamp
  );
  event WithdrawPartiallyProcessed(
    address indexed caller,
    address indexed beneficiary,
    uint indexed withdrawalQueueId,
    uint amountWithdrawn,
    uint tokenPrice,
    uint quoteReceived,
    uint totalQueuedWithdrawals,
    uint timestamp
  );
  event WithdrawQueued(
    address indexed withdrawer,
    address indexed beneficiary,
    uint indexed withdrawalQueueId,
    uint amountWithdrawn,
    uint totalQueuedWithdrawals,
    uint timestamp
  );

  /// @dev Emitted whenever the CB timestamp is updated
  event CircuitBreakerUpdated(
    uint newTimestamp,
    bool ivVarianceThresholdCrossed,
    bool skewVarianceThresholdCrossed,
    bool liquidityThresholdCrossed
  );

  /// @dev Emitted whenever the CB timestamp is updated from a board settlement
  event BoardSettlementCircuitBreakerUpdated(uint newTimestamp);

  /// @dev Emitted whenever a queue item is checked for the ability to be processed
  event CheckingCanProcess(uint entryId, bool boardNotStale, bool validEntry, bool guardianBypass, bool delaysExpired);

  ////////////
  // Errors //
  ////////////

  // Admin
  error InvalidLiquidityPoolParameters(address thrower, LiquidityPoolParameters lpParams);

  // Deposits and withdrawals
  error InvalidBeneficiaryAddress(address thrower, address beneficiary);
  error MinimumDepositNotMet(address thrower, uint amountQuote, uint minDeposit);
  error MinimumWithdrawNotMet(address thrower, uint amountLiquidityToken, uint minWithdraw);

  // Liquidity and accounting
  error LockingMoreQuoteThanIsFree(address thrower, uint quoteToLock, uint freeLiquidity, Collateral lockedCollateral);
  error SendPremiumNotEnoughCollateral(address thrower, uint premium, uint reservedFee, uint freeLiquidity);
  error NotEnoughFreeToReclaimInsolvency(address thrower, uint amountQuote, Liquidity liquidity);
  error OptionValueDebtExceedsTotalAssets(address thrower, int totalAssetValue, int optionValueDebt);
  error InsufficientFreeLiquidityForBaseExchange(
    address thrower,
    uint pendingBase,
    uint estimatedExchangeCost,
    uint freeLiquidity
  );

  // Access
  error OnlyPoolHedger(address thrower, address caller, address poolHedger);
  error OnlyOptionMarket(address thrower, address caller, address optionMarket);
  error OnlyShortCollateral(address thrower, address caller, address poolHedger);

  // Token transfers
  error QuoteTransferFailed(address thrower, address from, address to, uint amount);
  error BaseTransferFailed(address thrower, address from, address to, uint amount);
}

//SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

// Interfaces
import "./IOptionMarket.sol";
import "./IOptionToken.sol";

// For full documentation refer to @lyrafinance/protocol/contracts/ShortCollateral.sol";

interface IShortCollateral {
  // The amount the SC underpaid the LP due to insolvency.
  // The SC will take this much less from the LP when settling insolvent positions.
  function LPBaseExcess() external view returns (uint);

  function LPQuoteExcess() external view returns (uint);

  /////////////////////////
  // Position Settlement //
  /////////////////////////

  function settleOptions(uint[] memory positionIds) external;

  ////////////
  // Events //
  ////////////

  /// @dev Emitted when a board is settled
  event BoardSettlementCollateralSent(
    uint amountBaseSent,
    uint amountQuoteSent,
    uint lpBaseInsolvency,
    uint lpQuoteInsolvency,
    uint LPBaseExcess,
    uint LPQuoteExcess
  );

  /**
   * @dev Emitted when an Option is settled.
   */
  event PositionSettled(
    uint indexed positionId,
    address indexed settler,
    address indexed optionOwner,
    uint strikePrice,
    uint priceAtExpiry,
    IOptionMarket.OptionType optionType,
    uint amount,
    uint settlementAmount,
    uint insolventAmount
  );

  /**
   * @dev Emitted when quote is sent to either a user or the LiquidityPool
   */
  event QuoteSent(address indexed receiver, uint amount);
  /**
   * @dev Emitted when base is sent to either a user or the LiquidityPool
   */
  event BaseSent(address indexed receiver, uint amount);

  event BaseExchangedAndQuoteSent(address indexed recipient, uint amountBase, uint quoteReceived);

  ////////////
  // Errors //
  ////////////

  // Collateral transfers
  error OutOfQuoteCollateralForTransfer(address thrower, uint balance, uint amount);
  error OutOfBaseCollateralForTransfer(address thrower, uint balance, uint amount);
  error OutOfBaseCollateralForExchangeAndTransfer(address thrower, uint balance, uint amount);

  // Token transfers
  error BaseTransferFailed(address thrower, address from, address to, uint amount);
  error QuoteTransferFailed(address thrower, address from, address to, uint amount);

  // Access
  error BoardMustBeSettled(address thrower, IOptionToken.PositionWithOwner position);
  error OnlyOptionMarket(address thrower, address caller, address optionMarket);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

import "./IOptionMarket.sol";

// For full documentation refer to @lyrafinance/protocol/contracts/interfaces/IOptionGreekCache.sol";
interface IOptionGreekCache {
  struct GreekCacheParameters {
    // Cap the number of strikes per board to avoid hitting gasLimit constraints
    uint maxStrikesPerBoard;
    // How much spot price can move since last update before deposits/withdrawals are blocked
    uint acceptableSpotPricePercentMove;
    // How much time has passed since last update before deposits/withdrawals are blocked
    uint staleUpdateDuration;
    // Length of the GWAV for the baseline volatility used to fire the vol circuit breaker
    uint varianceIvGWAVPeriod;
    // Length of the GWAV for the skew ratios used to fire the vol circuit breaker
    uint varianceSkewGWAVPeriod;
    // Length of the GWAV for the baseline used to determine the NAV of the pool
    uint optionValueIvGWAVPeriod;
    // Length of the GWAV for the skews used to determine the NAV of the pool
    uint optionValueSkewGWAVPeriod;
    // Minimum skew that will be fed into the GWAV calculation
    // Prevents near 0 values being used to heavily manipulate the GWAV
    uint gwavSkewFloor;
    // Maximum skew that will be fed into the GWAV calculation
    uint gwavSkewCap;
    // Interest/risk free rate
    int rateAndCarry;
  }

  struct ForceCloseParameters {
    // Length of the GWAV for the baseline vol used in ForceClose() and liquidations
    uint ivGWAVPeriod;
    // Length of the GWAV for the skew ratio used in ForceClose() and liquidations
    uint skewGWAVPeriod;
    // When a user buys back an option using ForceClose() we increase the GWAV vol to penalise the trader
    uint shortVolShock;
    // Increase the penalty when within the trading cutoff
    uint shortPostCutoffVolShock;
    // When a user sells back an option to the AMM using ForceClose(), we decrease the GWAV to penalise the seller
    uint longVolShock;
    // Increase the penalty when within the trading cutoff
    uint longPostCutoffVolShock;
    // Same justification as shortPostCutoffVolShock
    uint liquidateVolShock;
    // Increase the penalty when within the trading cutoff
    uint liquidatePostCutoffVolShock;
    // Minimum price the AMM will sell back an option at for force closes (as a % of current spot)
    uint shortSpotMin;
    // Minimum price the AMM will sell back an option at for liquidations (as a % of current spot)
    uint liquidateSpotMin;
  }

  struct MinCollateralParameters {
    // Minimum collateral that must be posted for a short to be opened (denominated in quote)
    uint minStaticQuoteCollateral;
    // Minimum collateral that must be posted for a short to be opened (denominated in base)
    uint minStaticBaseCollateral;
    /* Shock Vol:
     * Vol used to compute the minimum collateral requirements for short positions.
     * This value is derived from the following chart, created by using the 4 values listed below.
     *
     *     vol
     *      |
     * volA |____
     *      |    \
     * volB |     \___
     *      |___________ time to expiry
     *         A   B
     */
    uint shockVolA;
    uint shockVolPointA;
    uint shockVolB;
    uint shockVolPointB;
    // Static percentage shock to the current spot price for calls
    uint callSpotPriceShock;
    // Static percentage shock to the current spot price for puts
    uint putSpotPriceShock;
  }

  ///////////////////
  // Cache storage //
  ///////////////////
  struct GlobalCache {
    uint minUpdatedAt;
    uint minUpdatedAtPrice;
    uint maxUpdatedAtPrice;
    uint maxSkewVariance;
    uint maxIvVariance;
    NetGreeks netGreeks;
  }

  struct OptionBoardCache {
    uint id;
    uint[] strikes;
    uint expiry;
    uint iv;
    NetGreeks netGreeks;
    uint updatedAt;
    uint updatedAtPrice;
    uint maxSkewVariance;
    uint ivVariance;
  }

  struct StrikeCache {
    uint id;
    uint boardId;
    uint strikePrice;
    uint skew;
    StrikeGreeks greeks;
    int callExposure; // long - short
    int putExposure; // long - short
    uint skewVariance; // (GWAVSkew - skew)
  }

  // These are based on GWAVed iv
  struct StrikeGreeks {
    int callDelta;
    int putDelta;
    uint stdVega;
    uint callPrice;
    uint putPrice;
  }

  // These are based on GWAVed iv
  struct NetGreeks {
    int netDelta;
    int netStdVega;
    int netOptionValue;
  }

  ///////////////
  // In-memory //
  ///////////////
  struct TradePricing {
    uint optionPrice;
    int preTradeAmmNetStdVega;
    int postTradeAmmNetStdVega;
    int callDelta;
    uint volTraded;
    uint ivVariance;
    uint vega;
  }

  struct BoardGreeksView {
    NetGreeks boardGreeks;
    uint ivGWAV;
    StrikeGreeks[] strikeGreeks;
    uint[] skewGWAVs;
  }

  function getPriceForForceClose(
    IOptionMarket.TradeParameters memory trade,
    IOptionMarket.Strike memory strike,
    uint expiry,
    uint newVol,
    bool isPostCutoff
  ) external view returns (uint optionPrice, uint forceCloseVol);

  function getMinCollateral(
    IOptionMarket.OptionType optionType,
    uint strikePrice,
    uint expiry,
    uint spotPrice,
    uint amount
  ) external view returns (uint minCollateral);

  function getShockVol(uint timeToMaturity) external view returns (uint);

  function updateBoardCachedGreeks(uint boardId) external;

  function isGlobalCacheStale(uint spotPrice) external view returns (bool);

  function isBoardCacheStale(uint boardId) external view returns (bool);

  /////////////////////////////
  // External View functions //
  /////////////////////////////

  /// @notice Get the current cached global netDelta exposure.
  function getGlobalNetDelta() external view returns (int);

  /// @notice Get the current global net option value
  function getGlobalOptionValue() external view returns (int);

  /// @notice Returns the BoardGreeksView struct given a specific boardId
  function getBoardGreeksView(uint boardId) external view returns (BoardGreeksView memory);

  /// @notice Get StrikeCache given a specific strikeId
  function getStrikeCache(uint strikeId) external view returns (StrikeCache memory);

  /// @notice Get OptionBoardCache given a specific boardId
  function getOptionBoardCache(uint boardId) external view returns (OptionBoardCache memory);

  /// @notice Get the global cache
  function getGlobalCache() external view returns (GlobalCache memory);

  /// @notice Returns ivGWAV for a given boardId and GWAV time interval
  function getIvGWAV(uint boardId, uint secondsAgo) external view returns (uint ivGWAV);

  /// @notice Returns skewGWAV for a given strikeId and GWAV time interval
  function getSkewGWAV(uint strikeId, uint secondsAgo) external view returns (uint skewGWAV);

  /// @notice Get the GreekCacheParameters
  function getGreekCacheParams() external view returns (GreekCacheParameters memory);

  /// @notice Get the ForceCloseParamters
  function getForceCloseParams() external view returns (ForceCloseParameters memory);

  /// @notice Get the MinCollateralParamters
  function getMinCollatParams() external view returns (MinCollateralParameters memory);

  ////////////
  // Events //
  ////////////

  event GreekCacheParametersSet(GreekCacheParameters params);
  event ForceCloseParametersSet(ForceCloseParameters params);
  event MinCollateralParametersSet(MinCollateralParameters params);

  event StrikeCacheUpdated(StrikeCache strikeCache);
  event BoardCacheUpdated(OptionBoardCache boardCache);
  event GlobalCacheUpdated(GlobalCache globalCache);

  event BoardCacheRemoved(uint boardId);
  event StrikeCacheRemoved(uint strikeId);
  event BoardIvUpdated(uint boardId, uint newIv, uint globalMaxIvVariance);
  event StrikeSkewUpdated(uint strikeId, uint newSkew, uint globalMaxSkewVariance);

  ////////////
  // Errors //
  ////////////
  // Admin
  error InvalidGreekCacheParameters(address thrower, GreekCacheParameters greekCacheParams);
  error InvalidForceCloseParameters(address thrower, ForceCloseParameters forceCloseParams);
  error InvalidMinCollatParams(address thrower, MinCollateralParameters minCollatParams);

  // Board related
  error BoardStrikeLimitExceeded(address thrower, uint boardId, uint newStrikesLength, uint maxStrikesPerBoard);
  error InvalidBoardId(address thrower, uint boardId);
  error CannotUpdateExpiredBoard(address thrower, uint boardId, uint expiry, uint currentTimestamp);

  // Access
  error OnlyIOptionMarket(address thrower, address caller, address optionMarket);
  error OnlyIOptionMarketPricer(address thrower, address caller, address optionMarketPricer);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

import "./IAddressResolver.sol";
import "./ISynthetix.sol";
import "./IExchanger.sol";
import "./IExchangeRates.sol";
import "./IDelegateApprovals.sol";

// For full documentation refer to @lyrafinance/protocol/contracts/SynthetixAdapter.sol";
interface ISynthetixAdapter {
  struct ExchangeParams {
    // snx oracle exchange rate for base
    uint spotPrice;
    // snx quote asset identifier key
    bytes32 quoteKey;
    // snx base asset identifier key
    bytes32 baseKey;
    // snx spot exchange rate from quote to base
    uint quoteBaseFeeRate;
    // snx spot exchange rate from base to quote
    uint baseQuoteFeeRate;
  }

  /// @dev Pause the whole system. Note; this will not pause settling previously expired options.
  function isMarketPaused(address market) external view returns (bool);

  function isGlobalPaused() external view returns (bool);

  function addressResolver() external view returns (address);

  function synthetix() external view returns (address);

  function exchanger() external view returns (address);

  function exchangeRates() external view returns (address);

  function delegateApprovals() external view returns (address);

  // Variables related to calculating premium/fees
  function quoteKey(address market) external view returns (bytes32);

  function baseKey(address market) external view returns (bytes32);

  function rewardAddress(address market) external view returns (bytes32);

  function trackingCode(address market) external view returns (bytes32);

  function updateSynthetixAddresses() external;

  /////////////
  // Getters //
  /////////////

  function getSpotPriceForMarket(address _contractAddress) external view returns (uint spotPrice);

  function getSpotPrice(bytes32 to) external view returns (uint);

  function getExchangeParams(address optionMarket) external view returns (ExchangeParams memory exchangeParams);

  function requireNotGlobalPaused(address optionMarket) external view;

  /////////////////////////////////////////
  // Exchanging QuoteAsset for BaseAsset //
  /////////////////////////////////////////

  function exchangeFromExactQuote(address optionMarket, uint amountQuote) external returns (uint baseReceived);

  function exchangeToExactBase(
    ExchangeParams memory exchangeParams,
    address optionMarket,
    uint amountBase
  ) external returns (uint quoteSpent, uint baseReceived);

  function exchangeToExactBaseWithLimit(
    ExchangeParams memory exchangeParams,
    address optionMarket,
    uint amountBase,
    uint quoteLimit
  ) external returns (uint quoteSpent, uint baseReceived);

  function estimateExchangeToExactBase(ExchangeParams memory exchangeParams, uint amountBase)
    external
    pure
    returns (uint quoteNeeded);

  /////////////////////////////////////////
  // Exchanging BaseAsset for QuoteAsset //
  /////////////////////////////////////////

  function exchangeFromExactBase(address optionMarket, uint amountBase) external returns (uint quoteReceived);

  function exchangeToExactQuote(
    ExchangeParams memory exchangeParams,
    address optionMarket,
    uint amountQuote
  ) external returns (uint baseSpent, uint quoteReceived);

  function exchangeToExactQuoteWithLimit(
    ExchangeParams memory exchangeParams,
    address optionMarket,
    uint amountQuote,
    uint baseLimit
  ) external returns (uint baseSpent, uint quoteReceived);

  function estimateExchangeToExactQuote(ExchangeParams memory exchangeParams, uint amountQuote)
    external
    pure
    returns (uint baseNeeded);

  ////////////
  // Events //
  ////////////

  /**
   * @dev Emitted when the address resolver is set.
   */
  event AddressResolverSet(IAddressResolver addressResolver);
  /**
   * @dev Emitted when synthetix contracts are updated.
   */
  event SynthetixAddressesUpdated(
    ISynthetix synthetix,
    IExchanger exchanger,
    IExchangeRates exchangeRates,
    IDelegateApprovals delegateApprovals
  );
  /**
   * @dev Emitted when values for a given option market are set.
   */
  event GlobalsSetForContract(
    address indexed market,
    bytes32 quoteKey,
    bytes32 baseKey,
    address rewardAddress,
    bytes32 trackingCode
  );
  /**
   * @dev Emitted when GlobalPause.
   */
  event GlobalPausedSet(bool isPaused);
  /**
   * @dev Emitted when single market paused.
   */
  event MarketPausedSet(address contractAddress, bool isPaused);
  /**
   * @dev Emitted when an exchange for base to quote occurs.
   * Which base and quote were swapped can be determined by the given marketAddress.
   */
  event BaseSwappedForQuote(
    address indexed marketAddress,
    address indexed exchanger,
    uint baseSwapped,
    uint quoteReceived
  );
  /**
   * @dev Emitted when an exchange for quote to base occurs.
   * Which base and quote were swapped can be determined by the given marketAddress.
   */
  event QuoteSwappedForBase(
    address indexed marketAddress,
    address indexed exchanger,
    uint quoteSwapped,
    uint baseReceived
  );

  ////////////
  // Errors //
  ////////////
  // Admin
  error InvalidRewardAddress(address thrower, address rewardAddress);

  // Market Paused
  error AllMarketsPaused(address thrower, address marketAddress);
  error MarketIsPaused(address thrower, address marketAddress);

  // Exchanging
  error ReceivedZeroFromExchange(
    address thrower,
    bytes32 fromKey,
    bytes32 toKey,
    uint amountSwapped,
    uint amountReceived
  );
  error QuoteBaseExchangeExceedsLimit(
    address thrower,
    uint amountBaseRequested,
    uint quoteToSpend,
    uint quoteLimit,
    uint spotPrice,
    bytes32 quoteKey,
    bytes32 baseKey
  );
  error BaseQuoteExchangeExceedsLimit(
    address thrower,
    uint amountQuoteRequested,
    uint baseToSpend,
    uint baseLimit,
    uint spotPrice,
    bytes32 baseKey,
    bytes32 quoteKey
  );
  error RateIsInvalid(address thrower, uint spotPrice, bool invalid);
}

//SPDX-License-Identifier: ISC
pragma solidity ^0.8.9;

interface IDelegateApprovals {
  function approveExchangeOnBehalf(address delegate) external;

  function canExchangeOnBehalf(address exchanger, address beneficiary) external view returns (bool);
}

//SPDX-License-Identifier: ISC
pragma solidity ^0.8.9;

interface ICurve {
  function exchange_with_best_rate(
    address _from,
    address _to,
    uint _amount,
    uint _expected,
    address _receiver
  ) external payable returns (uint amountOut);

  function exchange_underlying(
    int128 _from,
    int128 _to,
    uint _amount,
    uint _expected
  ) external payable returns (uint amountOut);

  function get_best_rate(
    address _from,
    address _to,
    uint _amount
  ) external view returns (address pool, uint amountOut);
}

//SPDX-License-Identifier:ISC

pragma solidity 0.8.9;

// For full documentation refer to @lyrafinance/protocol/contracts/periphery/GWAVOracle.sol";

interface IGWAVOracle {
  function ivGWAV(uint boardId, uint secondsAgo) external view returns (uint);

  function skewGWAV(uint strikeId, uint secondsAgo) external view returns (uint);

  function volGWAV(uint strikeId, uint secondsAgo) external view returns (uint);

  function deltaGWAV(uint strikeId, uint secondsAgo) external view returns (int callDelta);

  function vegaGWAV(uint strikeId, uint secondsAgo) external view returns (uint vega);

  function optionPriceGWAV(uint strikeId, uint secondsAgo) external view returns (uint callPrice, uint putPrice);
}

//SPDX-License-Identifier:ISC

pragma solidity 0.8.9;

import "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";

// For full documentation refer to @lyrafinance/protocol/contracts/periphery/LyraRegistry.sol";
/// @dev inputs/returns that contain Lyra contracts replaced with addresses (as opposed to LyraRegistry.sol)
///      so that interacting contracts are not required to import Lyra contracts
interface ILyraRegistry {
  struct OptionMarketAddresses {
    address liquidityPool;
    address liquidityToken;
    address greekCache;
    address optionMarket;
    address optionMarketPricer;
    address optionToken;
    address poolHedger;
    address shortCollateral;
    address gwavOracle;
    IERC20 quoteAsset;
    IERC20 baseAsset;
  }

  function optionMarkets() external view returns (address[] memory);

  function marketAddress(address market) external view returns (OptionMarketAddresses memory);

  function globalAddresses(bytes32 name) external view returns (address);

  function getMarketAddresses(address optionMarket) external view returns (OptionMarketAddresses memory);

  function getGlobalAddress(bytes32 contractName) external view returns (address globalContract);

  event GlobalAddressUpdated(bytes32 indexed name, address addr);

  event MarketUpdated(address indexed optionMarket, OptionMarketAddresses market);

  event MarketRemoved(address indexed market);

  error RemovingInvalidMarket(address thrower, address market);

  error NonExistentMarket(address optionMarket);

  error NonExistentGlobalContract(bytes32 contractName);
}

//SPDX-License-Identifier:ISC
pragma solidity 0.8.9;

import "../synthetix/Owned.sol";
import "../interfaces/IFeeCounter.sol";

/**
 * @title BasicFeeCounter
 */
contract BasicFeeCounter is IFeeCounter, Owned {
  mapping(address => bool) public trustedCounter;
  mapping(address => mapping(address => uint)) public totalFeesPerMarket;

  constructor() Owned() {}

  function setTrustedCounter(address counter, bool isTrusted) external onlyOwner {
    trustedCounter[counter] = isTrusted;
  }

  function trackFee(
    address market,
    address trader,
    uint,
    uint,
    uint totalFee
  ) external onlyTrustedCounter {
    totalFeesPerMarket[market][trader] += totalFee;
  }

  modifier onlyTrustedCounter() {
    require(trustedCounter[msg.sender], "not trusted counter");
    _;
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

// Slightly modified version of:
// - https://github.com/recmo/experiment-solexp/blob/605738f3ed72d6c67a414e992be58262fbc9bb80/src/FixedPointMathLib.sol
library FixedPointMathLib {
  /// @dev Computes ln(x) for a 1e27 fixed point. Loses 9 last significant digits of precision.
  function lnPrecise(int x) internal pure returns (int r) {
    return ln(x / 1e9) * 1e9;
  }

  /// @dev Computes e ^ x for a 1e27 fixed point. Loses 9 last significant digits of precision.
  function expPrecise(int x) internal pure returns (uint r) {
    return exp(x / 1e9) * 1e9;
  }

  // Computes ln(x) in 1e18 fixed point.
  // Reverts if x is negative or zero.
  // Consumes 670 gas.
  function ln(int x) internal pure returns (int r) {
    unchecked {
      if (x < 1) {
        if (x < 0) revert LnNegativeUndefined();
        revert Overflow();
      }

      // We want to convert x from 10**18 fixed point to 2**96 fixed point.
      // We do this by multiplying by 2**96 / 10**18.
      // But since ln(x * C) = ln(x) + ln(C), we can simply do nothing here
      // and add ln(2**96 / 10**18) at the end.

      // Reduce range of x to (1, 2) * 2**96
      // ln(2^k * x) = k * ln(2) + ln(x)
      // Note: inlining ilog2 saves 8 gas.
      int k = int(ilog2(uint(x))) - 96;
      x <<= uint(159 - k);
      x = int(uint(x) >> 159);

      // Evaluate using a (8, 8)-term rational approximation
      // p is made monic, we will multiply by a scale factor later
      int p = x + 3273285459638523848632254066296;
      p = ((p * x) >> 96) + 24828157081833163892658089445524;
      p = ((p * x) >> 96) + 43456485725739037958740375743393;
      p = ((p * x) >> 96) - 11111509109440967052023855526967;
      p = ((p * x) >> 96) - 45023709667254063763336534515857;
      p = ((p * x) >> 96) - 14706773417378608786704636184526;
      p = p * x - (795164235651350426258249787498 << 96);
      //emit log_named_int("p", p);
      // We leave p in 2**192 basis so we don't need to scale it back up for the division.
      // q is monic by convention
      int q = x + 5573035233440673466300451813936;
      q = ((q * x) >> 96) + 71694874799317883764090561454958;
      q = ((q * x) >> 96) + 283447036172924575727196451306956;
      q = ((q * x) >> 96) + 401686690394027663651624208769553;
      q = ((q * x) >> 96) + 204048457590392012362485061816622;
      q = ((q * x) >> 96) + 31853899698501571402653359427138;
      q = ((q * x) >> 96) + 909429971244387300277376558375;
      assembly {
        // Div in assembly because solidity adds a zero check despite the `unchecked`.
        // The q polynomial is known not to have zeros in the domain. (All roots are complex)
        // No scaling required because p is already 2**96 too large.
        r := sdiv(p, q)
      }
      // r is in the range (0, 0.125) * 2**96

      // Finalization, we need to
      // * multiply by the scale factor s = 5.549…
      // * add ln(2**96 / 10**18)
      // * add k * ln(2)
      // * multiply by 10**18 / 2**96 = 5**18 >> 78
      // mul s * 5e18 * 2**96, base is now 5**18 * 2**192
      r *= 1677202110996718588342820967067443963516166;
      // add ln(2) * k * 5e18 * 2**192
      r += 16597577552685614221487285958193947469193820559219878177908093499208371 * k;
      // add ln(2**96 / 10**18) * 5e18 * 2**192
      r += 600920179829731861736702779321621459595472258049074101567377883020018308;
      // base conversion: mul 2**18 / 2**192
      r >>= 174;
    }
  }

  // Integer log2
  // @returns floor(log2(x)) if x is nonzero, otherwise 0. This is the same
  //          as the location of the highest set bit.
  // Consumes 232 gas. This could have been an 3 gas EVM opcode though.
  function ilog2(uint x) internal pure returns (uint r) {
    assembly {
      r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
      r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
      r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
      r := or(r, shl(4, lt(0xffff, shr(r, x))))
      r := or(r, shl(3, lt(0xff, shr(r, x))))
      r := or(r, shl(2, lt(0xf, shr(r, x))))
      r := or(r, shl(1, lt(0x3, shr(r, x))))
      r := or(r, lt(0x1, shr(r, x)))
    }
  }

  // Computes e^x in 1e18 fixed point.
  function exp(int x) internal pure returns (uint r) {
    unchecked {
      // Input x is in fixed point format, with scale factor 1/1e18.

      // When the result is < 0.5 we return zero. This happens when
      // x <= floor(log(0.5e18) * 1e18) ~ -42e18
      if (x <= -42139678854452767551) {
        return 0;
      }

      // When the result is > (2**255 - 1) / 1e18 we can not represent it
      // as an int256. This happens when x >= floor(log((2**255 -1) / 1e18) * 1e18) ~ 135.
      if (x >= 135305999368893231589) revert ExpOverflow();

      // x is now in the range (-42, 136) * 1e18. Convert to (-42, 136) * 2**96
      // for more intermediate precision and a binary basis. This base conversion
      // is a multiplication by 1e18 / 2**96 = 5**18 / 2**78.
      x = (x << 78) / 5**18;

      // Reduce range of x to (-½ ln 2, ½ ln 2) * 2**96 by factoring out powers of two
      // such that exp(x) = exp(x') * 2**k, where k is an integer.
      // Solving this gives k = round(x / log(2)) and x' = x - k * log(2).
      int k = ((x << 96) / 54916777467707473351141471128 + 2**95) >> 96;
      x = x - k * 54916777467707473351141471128;
      // k is in the range [-61, 195].

      // Evaluate using a (6, 7)-term rational approximation
      // p is made monic, we will multiply by a scale factor later
      int p = x + 2772001395605857295435445496992;
      p = ((p * x) >> 96) + 44335888930127919016834873520032;
      p = ((p * x) >> 96) + 398888492587501845352592340339721;
      p = ((p * x) >> 96) + 1993839819670624470859228494792842;
      p = p * x + (4385272521454847904632057985693276 << 96);
      // We leave p in 2**192 basis so we don't need to scale it back up for the division.
      // Evaluate using using Knuth's scheme from p. 491.
      int z = x + 750530180792738023273180420736;
      z = ((z * x) >> 96) + 32788456221302202726307501949080;
      int w = x - 2218138959503481824038194425854;
      w = ((w * z) >> 96) + 892943633302991980437332862907700;
      int q = z + w - 78174809823045304726920794422040;
      q = ((q * w) >> 96) + 4203224763890128580604056984195872;
      assembly {
        // Div in assembly because solidity adds a zero check despite the `unchecked`.
        // The q polynomial is known not to have zeros in the domain. (All roots are complex)
        // No scaling required because p is already 2**96 too large.
        r := sdiv(p, q)
      }
      // r should be in the range (0.09, 0.25) * 2**96.

      // We now need to multiply r by
      //  * the scale factor s = ~6.031367120...,
      //  * the 2**k factor from the range reduction, and
      //  * the 1e18 / 2**96 factor for base converison.
      // We do all of this at once, with an intermediate result in 2**213 basis
      // so the final right shift is always by a positive amount.
      r = (uint(r) * 3822833074963236453042738258902158003155416615667) >> uint(195 - k);
    }
  }

  error Overflow();
  error ExpOverflow();
  error LnNegativeUndefined();
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
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

import "./IOptionMarket.sol";
import "./IOptionGreekCache.sol";

// For full documentation refer to @lyrafinance/protocol/contracts/OptionMarketPricer.sol";
interface IOptionMarketPricer {
  struct PricingParameters {
    // Percentage of option price that is charged as a fee
    uint optionPriceFeeCoefficient;
    // Refer to: getTimeWeightedFee()
    uint optionPriceFee1xPoint;
    uint optionPriceFee2xPoint;
    // Percentage of spot price that is charged as a fee per option
    uint spotPriceFeeCoefficient;
    // Refer to: getTimeWeightedFee()
    uint spotPriceFee1xPoint;
    uint spotPriceFee2xPoint;
    // Refer to: getVegaUtilFee()
    uint vegaFeeCoefficient;
    // The amount of options traded to move baseIv for the board up or down 1 point (depending on trade direction)
    uint standardSize;
    // The relative move of skew for a given strike based on standard sizes traded
    uint skewAdjustmentFactor;
  }

  struct TradeLimitParameters {
    // Delta cutoff past which no options can be traded (optionD > minD && optionD < 1 - minD) - using call delta
    int minDelta;
    // Delta cutoff at which ForceClose can be called (optionD < minD || optionD > 1 - minD) - using call delta
    int minForceCloseDelta;
    // Time when trading closes. Only ForceClose can be called after this
    uint tradingCutoff;
    // Lowest baseIv for a board that can be traded for regular option opens/closes
    uint minBaseIV;
    // Maximal baseIv for a board that can be traded for regular option opens/closes
    uint maxBaseIV;
    // Lowest skew for a strike that can be traded for regular option opens/closes
    uint minSkew;
    // Maximal skew for a strike that can be traded for regular option opens/closes
    uint maxSkew;
    // Minimal vol traded for regular option opens/closes (baseIv * skew)
    uint minVol;
    // Maximal vol traded for regular option opens/closes (baseIv * skew)
    uint maxVol;
    // Absolute lowest skew that ForceClose can go to
    uint absMinSkew;
    // Absolute highest skew that ForceClose can go to
    uint absMaxSkew;
    // Cap the skew the abs max/min skews - only relevant to liquidations
    bool capSkewsToAbs;
  }

  struct VarianceFeeParameters {
    uint defaultVarianceFeeCoefficient;
    uint forceCloseVarianceFeeCoefficient;
    // coefficient that allows the skew component of the fee to be scaled up
    uint skewAdjustmentCoefficient;
    // measures the difference of the skew to a reference skew
    uint referenceSkew;
    // constant to ensure small vega terms have a fee
    uint minimumStaticSkewAdjustment;
    // coefficient that allows the vega component of the fee to be scaled up
    uint vegaCoefficient;
    // constant to ensure small vega terms have a fee
    uint minimumStaticVega;
    // coefficient that allows the ivVariance component of the fee to be scaled up
    uint ivVarianceCoefficient;
    // constant to ensure small variance terms have a fee
    uint minimumStaticIvVariance;
  }

  ///////////////
  // In-memory //
  ///////////////
  struct TradeResult {
    uint amount;
    uint premium;
    uint optionPriceFee;
    uint spotPriceFee;
    VegaUtilFeeComponents vegaUtilFee;
    VarianceFeeComponents varianceFee;
    uint totalFee;
    uint totalCost;
    uint volTraded;
    uint newBaseIv;
    uint newSkew;
  }

  struct VegaUtilFeeComponents {
    int preTradeAmmNetStdVega;
    int postTradeAmmNetStdVega;
    uint vegaUtil;
    uint volTraded;
    uint NAV;
    uint vegaUtilFee;
  }

  struct VarianceFeeComponents {
    uint varianceFeeCoefficient;
    uint vega;
    uint vegaCoefficient;
    uint skew;
    uint skewCoefficient;
    uint ivVariance;
    uint ivVarianceCoefficient;
    uint varianceFee;
  }

  struct VolComponents {
    uint vol;
    uint baseIv;
    uint skew;
  }

  ///////////////
  // Variables //
  ///////////////

  function pricingParams() external view returns (PricingParameters memory);

  function tradeLimitParams() external view returns (TradeLimitParameters memory);

  function varianceFeeParams() external view returns (VarianceFeeParameters memory);

  function ivImpactForTrade(
    IOptionMarket.TradeParameters memory trade,
    uint boardBaseIv,
    uint strikeSkew
  ) external view returns (uint newBaseIv, uint newSkew);

  function getTradeResult(
    IOptionMarket.TradeParameters memory trade,
    IOptionGreekCache.TradePricing memory pricing,
    uint newBaseIv,
    uint newSkew
  ) external view returns (TradeResult memory tradeResult);

  function getTimeWeightedFee(
    uint expiry,
    uint pointA,
    uint pointB,
    uint coefficient
  ) external view returns (uint timeWeightedFee);

  function getVegaUtilFee(IOptionMarket.TradeParameters memory trade, IOptionGreekCache.TradePricing memory pricing)
    external
    view
    returns (VegaUtilFeeComponents memory vegaUtilFeeComponents);

  function getVarianceFee(
    IOptionMarket.TradeParameters memory trade,
    IOptionGreekCache.TradePricing memory pricing,
    uint skew
  ) external view returns (VarianceFeeComponents memory varianceFeeComponents);

  /////////////////////////////
  // External View functions //
  /////////////////////////////

  function getPricingParams() external view returns (PricingParameters memory pricingParameters);

  function getTradeLimitParams() external view returns (TradeLimitParameters memory tradeLimitParameters);

  function getVarianceFeeParams() external view returns (VarianceFeeParameters memory varianceFeeParameters);

  ////////////
  // Events //
  ////////////

  event PricingParametersSet(PricingParameters pricingParams);
  event TradeLimitParametersSet(TradeLimitParameters tradeLimitParams);
  event VarianceFeeParametersSet(VarianceFeeParameters varianceFeeParams);

  ////////////
  // Errors //
  ////////////
  // Admin
  error InvalidTradeLimitParameters(address thrower, TradeLimitParameters tradeLimitParams);
  error InvalidPricingParameters(address thrower, PricingParameters pricingParams);

  // Trade limitations
  error TradingCutoffReached(address thrower, uint tradingCutoff, uint boardExpiry, uint currentTime);
  error ForceCloseSkewOutOfRange(address thrower, bool isBuy, uint newSkew, uint minSkew, uint maxSkew);
  error VolSkewOrBaseIvOutsideOfTradingBounds(
    address thrower,
    bool isBuy,
    VolComponents currentVol,
    VolComponents newVol,
    VolComponents tradeBounds
  );
  error TradeDeltaOutOfRange(address thrower, int strikeCallDelta, int minDelta, int maxDelta);
  error ForceCloseDeltaOutOfRange(address thrower, int strikeCallDelta, int minDelta, int maxDelta);

  // Access
  error OnlyOptionMarket(address thrower, address caller, address optionMarket);
}

//SPDX-License-Identifier: ISC
pragma solidity ^0.8.9;

// https://docs.synthetix.io/contracts/source/interfaces/iaddressresolver
interface IAddressResolver {
  function getAddress(bytes32 name) external view returns (address);
}

//SPDX-License-Identifier: ISC
pragma solidity ^0.8.9;

interface ISynthetix {
  function exchange(
    bytes32 sourceCurrencyKey,
    uint sourceAmount,
    bytes32 destinationCurrencyKey
  ) external returns (uint amountReceived);

  function exchangeOnBehalfWithTracking(
    address exchangeForAddress,
    bytes32 sourceCurrencyKey,
    uint sourceAmount,
    bytes32 destinationCurrencyKey,
    address rewardAddress,
    bytes32 trackingCode
  ) external returns (uint amountReceived);
}

//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

// https://docs.synthetix.io/contracts/source/interfaces/iexchanger
interface IExchanger {
  function feeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey)
    external
    view
    returns (uint exchangeFeeRate);
}

//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

// https://docs.synthetix.io/contracts/source/interfaces/iexchangerates
interface IExchangeRates {
  function rateAndInvalid(bytes32 currencyKey) external view returns (uint rate, bool isInvalid);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

//SPDX-License-Identifier: MIT
//
//Copyright (c) 2019 Synthetix
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

pragma solidity ^0.8.9;

import "./AbstractOwned.sol";

/**
 * @title Owned
 * @author Synthetix
 * @dev Slightly modified Synthetix owned contract, so that first owner is msg.sender
 * @dev https://docs.synthetix.io/contracts/source/contracts/owned
 */
contract Owned is AbstractOwned {
  constructor() {
    owner = msg.sender;
    emit OwnerChanged(address(0), msg.sender);
  }
}

//SPDX-License-Identifier: ISC
pragma solidity ^0.8.9;

interface IFeeCounter {
  function trackFee(
    address market,
    address trader,
    uint amount,
    uint totalCost,
    uint totalFee
  ) external;
}

//SPDX-License-Identifier: MIT
//
//Copyright (c) 2019 Synthetix
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

pragma solidity ^0.8.9;

/**
 * @title Owned
 * @author Synthetix
 * @dev Synthetix owned contract without constructor and custom errors
 * @dev https://docs.synthetix.io/contracts/source/contracts/owned
 */
abstract contract AbstractOwned {
  address public owner;
  address public nominatedOwner;

  function nominateNewOwner(address _owner) external onlyOwner {
    nominatedOwner = _owner;
    emit OwnerNominated(_owner);
  }

  function acceptOwnership() external {
    if (msg.sender != nominatedOwner) {
      revert OnlyNominatedOwner(address(this), msg.sender, nominatedOwner);
    }
    emit OwnerChanged(owner, nominatedOwner);
    owner = nominatedOwner;
    nominatedOwner = address(0);
  }

  modifier onlyOwner() {
    _onlyOwner();
    _;
  }

  function _onlyOwner() private view {
    if (msg.sender != owner) {
      revert OnlyOwner(address(this), msg.sender, owner);
    }
  }

  event OwnerNominated(address newOwner);
  event OwnerChanged(address oldOwner, address newOwner);

  ////////////
  // Errors //
  ////////////
  error OnlyOwner(address thrower, address caller, address owner);
  error OnlyNominatedOwner(address thrower, address caller, address nominatedOwner);
}