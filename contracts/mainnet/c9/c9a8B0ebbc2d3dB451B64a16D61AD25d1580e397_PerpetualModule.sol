// SPDX-License-Identifier: BUSL-1.1
// Refer to https://docs.pegasusfinance.xyz/protocol-overview/protocol-mechanism/code-use-notes
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../interface/IOracle.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";
import "../Type.sol";
import "./MarginAccountModule.sol";

import "hardhat/console.sol";

library PerpetualModule {
    using SafeMathUpgradeable for uint256;
    using SafeMathExt for int256;
    using SafeCastUpgradeable for int256;
    using SafeCastUpgradeable for uint256;
    using AddressUpgradeable for address;
    using SignedSafeMathUpgradeable for int256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using MarginAccountModule for PerpetualStorage;

    int256 constant FUNDING_INTERVAL = 3600 * 8;

    uint256 internal constant INDEX_INITIAL_MARGIN_RATE = 0;
    uint256 internal constant INDEX_MAINTENANCE_MARGIN_RATE = 1;
    uint256 internal constant INDEX_OPERATOR_FEE_RATE = 2;
    uint256 internal constant INDEX_LP_FEE_RATE = 3;
    uint256 internal constant INDEX_REFERRAL_REBATE_RATE = 4;
    uint256 internal constant INDEX_LIQUIDATION_PENALTY_RATE = 5;
    uint256 internal constant INDEX_KEEPER_GAS_REWARD = 6;
    uint256 internal constant INDEX_INSURANCE_FUND_RATE = 7;
    uint256 internal constant INDEX_MAX_OPEN_INTEREST_RATE = 8;

    uint256 internal constant INDEX_HALF_SPREAD = 0;
    uint256 internal constant INDEX_OPEN_SLIPPAGE_FACTOR = 1;
    uint256 internal constant INDEX_CLOSE_SLIPPAGE_FACTOR = 2;
    uint256 internal constant INDEX_FUNDING_RATE_LIMIT = 3;
    uint256 internal constant INDEX_AMM_MAX_LEVERAGE = 4;
    uint256 internal constant INDEX_AMM_CLOSE_PRICE_DISCOUNT = 5;
    uint256 internal constant INDEX_FUNDING_RATE_FACTOR = 6;
    uint256 internal constant INDEX_DEFAULT_TARGET_LEVERAGE = 7;
    uint256 internal constant INDEX_BASE_FUNDING_RATE = 8;
    uint256 internal constant INDEX_SLIP_LONG_PEN = 9;
    uint256 internal constant INDEX_SLIP_SHORT_PEN = 10;
    uint256 internal constant INDEX_MEAN_RATE = 11;
    uint256 internal constant INDEX_MAX_RATE = 12;
    uint256 internal constant INDEX_LONG_MEAN_FACTOR = 13;
    uint256 internal constant INDEX_SHORT_MEAN_FACTOR = 14;

    event Deposit(uint256 perpetualIndex, address indexed trader, int256 amount);
    event Withdraw(uint256 perpetualIndex, address indexed trader, int256 amount);
    event Clear(uint256 perpetualIndex, address indexed trader);
    event Settle(uint256 perpetualIndex, address indexed trader, int256 amount);
    event SetNormalState(uint256 perpetualIndex);
    event SetEmergencyState(uint256 perpetualIndex, int256 settlementPrice, uint256 settlementTime);
    event SetClearedState(uint256 perpetualIndex);
    event UpdateUnitAccumulativeFunding(
        uint256 perpetualIndex,
        int256 unitAccumulativeFunding,
        int256 unitAccumulativeLongFunding,
        int256 unitAccumulativeShortFunding
    );
    event SetPerpetualBaseParameter(uint256 perpetualIndex, int256[9] baseParams);
    event SetPerpetualRiskParameter(
        uint256 perpetualIndex,
        int256[15] riskParams,
        int256[15] minRiskParamValues,
        int256[15] maxRiskParamValues
    );
    event UpdatePerpetualRiskParameter(uint256 perpetualIndex, int256[15] riskParams);
    event SetOracle(uint256 perpetualIndex, address indexed oldOracle, address indexed newOracle);
    event UpdatePrice(
        uint256 perpetualIndex,
        address indexed oracle,
        int256 markPrice,
        uint256 markPriceUpdateTime,
        int256 indexPrice,
        uint256 indexPriceUpdateTime
    );
    event UpdateFundingRate(uint256 perpetualIndex, int256 fundingRate);

    /**
     * @dev     Get the mark price of the perpetual. If the state of the perpetual is not "NORMAL",
     *          return the settlement price
     * @param   perpetual   The reference of perpetual storage.
     * @return  markPrice   The mark price of current perpetual.
     */
    function getMarkPrice(PerpetualStorage storage perpetual)
        internal
        view
        returns (int256 markPrice)
    {
        markPrice = perpetual.state == PerpetualState.NORMAL
            ? perpetual.markPriceData.price
            : perpetual.settlementPriceData.price;
    }

    /**
     * @dev     Get the index price of the perpetual. If the state of the perpetual is not "NORMAL",
     *          return the settlement price
     * @param   perpetual   The reference of perpetual storage.
     * @return  indexPrice  The index price of current perpetual.
     */
    function getIndexPrice(PerpetualStorage storage perpetual)
        internal
        view
        returns (int256 indexPrice)
    {
        indexPrice = perpetual.state == PerpetualState.NORMAL
            ? perpetual.indexPriceData.price
            : perpetual.settlementPriceData.price;
    }

    /**
     * @dev     Get the margin to rebalance in the perpetual.
     *          Margin to rebalance = margin - initial margin
     * @param   perpetual The perpetual object
     * @return  marginToRebalance The margin to rebalance in the perpetual
     */
    function getRebalanceMargin(PerpetualStorage storage perpetual)
        public
        view
        returns (int256 marginToRebalance)
    {
        int256 price = getMarkPrice(perpetual);
        marginToRebalance = perpetual.getMargin(address(this), price).sub(
            perpetual.getInitialMargin(address(this), price)
        );
    }

    /**
     * @dev     Initialize the perpetual. Set up its configuration and validate parameters.
     *          If the validation passed, set the state of perpetual to "INITIALIZING"
     *          [minRiskParamValues, maxRiskParamValues] represents the range that the operator could
     *          update directly without proposal.
     *
     * @param   perpetual           The reference of perpetual storage.
     * @param   id                  The id of the perpetual (currently the index of perpetual)
     * @param   oracle              The address of oracle contract.
     * @param   baseParams          An int array of base parameter values.
     * @param   riskParams          An int array of risk parameter values.
     * @param   minRiskParamValues  An int array of minimal risk parameter values.
     * @param   maxRiskParamValues  An int array of maximum risk parameter values.
     */
    function initialize(
        PerpetualStorage storage perpetual,
        uint256 id,
        address oracle,
        int256[9] calldata baseParams,
        int256[15] calldata riskParams,
        int256[15] calldata minRiskParamValues,
        int256[15] calldata maxRiskParamValues
    ) public {
        perpetual.id = id;
        setOracle(perpetual, oracle);
        setBaseParameter(perpetual, baseParams);
        setRiskParameter(perpetual, riskParams, minRiskParamValues, maxRiskParamValues);
        perpetual.state = PerpetualState.INITIALIZING;
    }

    /**
     * @dev     Set oracle address of perpetual. New oracle must be different from the old one.
     *
     * @param   perpetual   The reference of perpetual storage.
     * @param   newOracle   The address of new oracle contract.
     */
    function setOracle(PerpetualStorage storage perpetual, address newOracle) public {
        require(newOracle != perpetual.oracle, "oracle not changed");
        validateOracle(newOracle);
        emit SetOracle(perpetual.id, perpetual.oracle, newOracle);
        perpetual.oracle = newOracle;
    }

    /**
     * @dev     Set the base parameter of the perpetual. Can only called by the governor
     * @param   perpetual   The perpetual object
     * @param   baseParams  The new value of the base parameter
     */
    function setBaseParameter(PerpetualStorage storage perpetual, int256[9] memory baseParams)
        public
    {
        validateBaseParameters(perpetual, baseParams);
        perpetual.initialMarginRate = baseParams[INDEX_INITIAL_MARGIN_RATE];
        perpetual.maintenanceMarginRate = baseParams[INDEX_MAINTENANCE_MARGIN_RATE];
        perpetual.operatorFeeRate = baseParams[INDEX_OPERATOR_FEE_RATE];
        perpetual.lpFeeRate = baseParams[INDEX_LP_FEE_RATE];
        perpetual.referralRebateRate = baseParams[INDEX_REFERRAL_REBATE_RATE];
        perpetual.liquidationPenaltyRate = baseParams[INDEX_LIQUIDATION_PENALTY_RATE];
        perpetual.keeperGasReward = baseParams[INDEX_KEEPER_GAS_REWARD];
        perpetual.insuranceFundRate = baseParams[INDEX_INSURANCE_FUND_RATE];
        perpetual.maxOpenInterestRate = baseParams[INDEX_MAX_OPEN_INTEREST_RATE];
        emit SetPerpetualBaseParameter(perpetual.id, baseParams);
    }

    /**
     * @dev     Set the risk parameter of the perpetual. New parameters will be validate first to apply.
     *          Using group set instead of one-by-one set to avoid revert due to constrains between values.
     *
     * @param   perpetual           The reference of perpetual storage.
     * @param   riskParams          An int array of risk parameter values.
     * @param   minRiskParamValues  An int array of minimal risk parameter values.
     * @param   maxRiskParamValues  An int array of maximum risk parameter values.
     */
    function setRiskParameter(
        PerpetualStorage storage perpetual,
        int256[15] memory riskParams,
        int256[15] memory minRiskParamValues,
        int256[15] memory maxRiskParamValues
    ) public {
        validateRiskParameters(perpetual, riskParams);
        setOption(
            perpetual.halfSpread,
            riskParams[INDEX_HALF_SPREAD],
            minRiskParamValues[INDEX_HALF_SPREAD],
            maxRiskParamValues[INDEX_HALF_SPREAD]
        );
        setOption(
            perpetual.openSlippageFactor,
            riskParams[INDEX_OPEN_SLIPPAGE_FACTOR],
            minRiskParamValues[INDEX_OPEN_SLIPPAGE_FACTOR],
            maxRiskParamValues[INDEX_OPEN_SLIPPAGE_FACTOR]
        );
        setOption(
            perpetual.closeSlippageFactor,
            riskParams[INDEX_CLOSE_SLIPPAGE_FACTOR],
            minRiskParamValues[INDEX_CLOSE_SLIPPAGE_FACTOR],
            maxRiskParamValues[INDEX_CLOSE_SLIPPAGE_FACTOR]
        );
        setOption(
            perpetual.fundingRateLimit,
            riskParams[INDEX_FUNDING_RATE_LIMIT],
            minRiskParamValues[INDEX_FUNDING_RATE_LIMIT],
            maxRiskParamValues[INDEX_FUNDING_RATE_LIMIT]
        );
        setOption(
            perpetual.ammMaxLeverage,
            riskParams[INDEX_AMM_MAX_LEVERAGE],
            minRiskParamValues[INDEX_AMM_MAX_LEVERAGE],
            maxRiskParamValues[INDEX_AMM_MAX_LEVERAGE]
        );
        setOption(
            perpetual.maxClosePriceDiscount,
            riskParams[INDEX_AMM_CLOSE_PRICE_DISCOUNT],
            minRiskParamValues[INDEX_AMM_CLOSE_PRICE_DISCOUNT],
            maxRiskParamValues[INDEX_AMM_CLOSE_PRICE_DISCOUNT]
        );
        setOption(
            perpetual.fundingRateFactor,
            riskParams[INDEX_FUNDING_RATE_FACTOR],
            minRiskParamValues[INDEX_FUNDING_RATE_FACTOR],
            maxRiskParamValues[INDEX_FUNDING_RATE_FACTOR]
        );
        setOption(
            perpetual.defaultTargetLeverage,
            riskParams[INDEX_DEFAULT_TARGET_LEVERAGE],
            minRiskParamValues[INDEX_DEFAULT_TARGET_LEVERAGE],
            maxRiskParamValues[INDEX_DEFAULT_TARGET_LEVERAGE]
        );
        setOption(
            perpetual.baseFundingRate,
            riskParams[INDEX_BASE_FUNDING_RATE],
            minRiskParamValues[INDEX_BASE_FUNDING_RATE],
            maxRiskParamValues[INDEX_BASE_FUNDING_RATE]
        );
        setOption(
            perpetual.openSlippageLongPenaltyFactor,
            riskParams[INDEX_SLIP_LONG_PEN],
            minRiskParamValues[INDEX_SLIP_LONG_PEN],
            maxRiskParamValues[INDEX_SLIP_LONG_PEN]
        );
        setOption(
            perpetual.openSlippageShortPenaltyFactor,
            riskParams[INDEX_SLIP_SHORT_PEN],
            minRiskParamValues[INDEX_SLIP_SHORT_PEN],
            maxRiskParamValues[INDEX_SLIP_SHORT_PEN]
        );
        setOption(
            perpetual.meanRate,
            riskParams[INDEX_MEAN_RATE],
            minRiskParamValues[INDEX_MEAN_RATE],
            maxRiskParamValues[INDEX_MEAN_RATE]
        );
        setOption(
            perpetual.maxRate,
            riskParams[INDEX_MAX_RATE],
            minRiskParamValues[INDEX_MAX_RATE],
            maxRiskParamValues[INDEX_MAX_RATE]
        );
        setOption(
            perpetual.longMeanRevertFactor,
            riskParams[INDEX_LONG_MEAN_FACTOR],
            minRiskParamValues[INDEX_LONG_MEAN_FACTOR],
            maxRiskParamValues[INDEX_LONG_MEAN_FACTOR]
        );
        setOption(
            perpetual.shortMeanRevertFactor,
            riskParams[INDEX_SHORT_MEAN_FACTOR],
            minRiskParamValues[INDEX_SHORT_MEAN_FACTOR],
            maxRiskParamValues[INDEX_SHORT_MEAN_FACTOR]
        );
        emit SetPerpetualRiskParameter(
            perpetual.id,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
    }

    /**
     * @dev     Adjust the risk parameter. New values should always satisfied the constrains and min/max limit.
     *
     * @param   perpetual   The reference of perpetual storage.
     * @param   riskParams  An int array of risk parameter values.
     */
    function updateRiskParameter(PerpetualStorage storage perpetual, int256[15] memory riskParams)
        public
    {
        validateRiskParameters(perpetual, riskParams);
        updateOption(perpetual.halfSpread, riskParams[INDEX_HALF_SPREAD]);
        updateOption(perpetual.openSlippageFactor, riskParams[INDEX_OPEN_SLIPPAGE_FACTOR]);
        updateOption(perpetual.closeSlippageFactor, riskParams[INDEX_CLOSE_SLIPPAGE_FACTOR]);
        updateOption(perpetual.fundingRateLimit, riskParams[INDEX_FUNDING_RATE_LIMIT]);
        updateOption(perpetual.ammMaxLeverage, riskParams[INDEX_AMM_MAX_LEVERAGE]);
        updateOption(perpetual.maxClosePriceDiscount, riskParams[INDEX_AMM_CLOSE_PRICE_DISCOUNT]);
        updateOption(perpetual.fundingRateFactor, riskParams[INDEX_FUNDING_RATE_FACTOR]);
        updateOption(perpetual.defaultTargetLeverage, riskParams[INDEX_DEFAULT_TARGET_LEVERAGE]);
        updateOption(perpetual.baseFundingRate, riskParams[INDEX_BASE_FUNDING_RATE]);
        emit UpdatePerpetualRiskParameter(perpetual.id, riskParams);
    }

    /**
     * @dev     Update the unitAccumulativeFunding variable in perpetual.
     *          After that, funding payment of every account in the perpetual is updated,
     *
     *          nextUnitAccumulativeFunding = unitAccumulativeFunding
     *                                       + index * fundingRate * elapsedTime / fundingInterval
     *
     * @param   perpetual   The reference of perpetual storage.
     * @param   timeElapsed The elapsed time since last update.
     */
    function updateFundingState(PerpetualStorage storage perpetual, int256 timeElapsed) public {
        int256 deltaUnitLoss = timeElapsed
            .mul(getIndexPrice(perpetual))
            .wmul(perpetual.fundingRate)
            .div(FUNDING_INTERVAL);
        perpetual.unitAccumulativeFunding = perpetual.unitAccumulativeFunding.add(deltaUnitLoss);
        if (deltaUnitLoss < 0) {
            perpetual.unitAccumulativeShortFunding = perpetual.unitAccumulativeShortFunding.add(
                deltaUnitLoss
            );
        } else {
            perpetual.unitAccumulativeLongFunding = perpetual.unitAccumulativeLongFunding.add(
                deltaUnitLoss
            );
        }
        emit UpdateUnitAccumulativeFunding(
            perpetual.id,
            perpetual.unitAccumulativeFunding,
            perpetual.unitAccumulativeLongFunding,
            perpetual.unitAccumulativeShortFunding
        );
    }

    /**
     * @dev     Update the funding rate of the perpetual.
     *
     *            - funding rate = - index * position * factor / pool margin
     *            - funding rate += base funding rate when
     *                - open interest != 0 and position >= 0 and base funding rate < 0
     *                - open interest != 0 and position <= 0 and base funding rate > 0
     *            - funding rate = (+/-)limit when
     *                - pool margin = 0 and position != 0
     *                - abs(funding rate) > limit
     *
     * @param   perpetual   The reference of perpetual storage.
     * @param   poolMargin  The pool margin of liquidity pool.
     */
    function updateFundingRate(PerpetualStorage storage perpetual, int256 poolMargin) public {
        int256 position = perpetual.getPosition(address(this));
        int256 newFundingRate;

        if (perpetual.openInterest == 0) {
            newFundingRate = 0;
        } else if (position <= 0) {
            newFundingRate = perpetual.baseFundingRate.value;
        } else if (position >= 0) {
            newFundingRate = perpetual.baseFundingRate.value.neg();
        }

        if (position != 0) {
            int256 fundingRateLimit = perpetual.fundingRateLimit.value;
            if (poolMargin != 0) {
                newFundingRate = newFundingRate.add(
                    getIndexPrice(perpetual).wfrac(position, poolMargin)
                    .neg()
                    .wmul(perpetual.fundingRateFactor.value)
                );
                newFundingRate = newFundingRate.min(fundingRateLimit).max(fundingRateLimit.neg());
            } else if (position > 0) {
                newFundingRate = fundingRateLimit.neg();
            } else {
                newFundingRate = fundingRateLimit;
            }
        }
        perpetual.fundingRate = newFundingRate;
        emit UpdateFundingRate(perpetual.id, newFundingRate);
    }

    /**
     * @dev     Update the oracle price of the perpetual, including the index price and the mark price
     * @param   perpetual   The reference of perpetual storage.
     */
    function updatePrice(PerpetualStorage storage perpetual) internal {
        IOracle oracle = IOracle(perpetual.oracle);
        updatePriceData(perpetual.markPriceData, oracle.priceTWAPLong);
        updatePriceData(perpetual.indexPriceData, oracle.priceTWAPShort);
        emit UpdatePrice(
            perpetual.id,
            address(oracle),
            perpetual.markPriceData.price,
            perpetual.markPriceData.time,
            perpetual.indexPriceData.price,
            perpetual.indexPriceData.time
        );
    }

    /**
     * @dev     Set the state of the perpetual to "NORMAL". The state must be "INITIALIZING" before
     * @param   perpetual   The reference of perpetual storage.
     */
    function setNormalState(PerpetualStorage storage perpetual) public {
        require(
            perpetual.state == PerpetualState.INITIALIZING,
            "perpetual should be in initializing state"
        );
        perpetual.state = PerpetualState.NORMAL;
        emit SetNormalState(perpetual.id);
    }

    /**
     * @dev     Set the state of the perpetual to "EMERGENCY". The state must be "NORMAL" before.
     *          The settlement price is the mark price at this time
     * @param   perpetual   The reference of perpetual storage.
     */
    function setEmergencyState(PerpetualStorage storage perpetual) public {
        require(perpetual.state == PerpetualState.NORMAL, "perpetual should be in NORMAL state");
        // use mark price as final price when emergency
        perpetual.settlementPriceData = perpetual.markPriceData;
        perpetual.totalAccount = perpetual.activeAccounts.length();
        perpetual.state = PerpetualState.EMERGENCY;
        emit SetEmergencyState(
            perpetual.id,
            perpetual.settlementPriceData.price,
            perpetual.settlementPriceData.time
        );
    }

    /**
     * @dev     Set the state of the perpetual to "CLEARED". The state must be "EMERGENCY" before.
     *          And settle the collateral of the perpetual, which means
     *          determining how much collateral should returned to every account.
     * @param   perpetual   The reference of perpetual storage.
     */
    function setClearedState(PerpetualStorage storage perpetual) public {
        require(
            perpetual.state == PerpetualState.EMERGENCY,
            "perpetual should be in emergency state"
        );
        settleCollateral(perpetual);
        perpetual.state = PerpetualState.CLEARED;
        emit SetClearedState(perpetual.id);
    }

    /**
     * @dev     Deposit collateral to the trader's account of the perpetual, that will increase the cash amount in
     *          trader's margin account.
     *
     *          If this is the first time the trader deposits in current perpetual, the address of trader will be
     *          push to a list, then the trader is defined as an 'Active' trader for this perpetual.
     *          List of active traders will be used during clearing.
     *
     * @param   perpetual           The reference of perpetual storage.
     * @param   trader              The address of the trader.
     * @param   amount              The amount of collateral to deposit.
     * @return  isInitialDeposit    True if the trader's account is empty before depositing.
     */
    function deposit(
        PerpetualStorage storage perpetual,
        address trader,
        int256 amount
    ) public returns (bool isInitialDeposit) {
        require(amount > 0, "amount should greater than 0");
        perpetual.updateCash(trader, amount);
        isInitialDeposit = registerActiveAccount(perpetual, trader);
        emit Deposit(perpetual.id, trader, amount);
    }

    /**
     * @dev     Withdraw collateral from the trader's account of the perpetual, that will increase the cash amount in
     *          trader's margin account.
     *
     *          Trader must be initial margin safe in the perpetual after withdrawing.
     *          Making the margin account 'Empty' will mark this account as a 'Deactive' trader then be removed from
     *          list of active traders.
     *
     * @param   perpetual           The reference of perpetual storage.
     * @param   trader              The address of the trader.
     * @param   amount              The amount of collateral to withdraw.
     * @return  isLastWithdrawal    True if the trader's account is empty after withdrawing.
     */
    function withdraw(
        PerpetualStorage storage perpetual,
        address trader,
        int256 amount
    ) public returns (bool isLastWithdrawal) {
        require(
            perpetual.getPosition(trader) == 0 || !IOracle(perpetual.oracle).isMarketClosed(),
            "market is closed"
        );
        require(amount > 0, "amount should greater than 0");
        perpetual.updateCash(trader, amount.neg());
        int256 markPrice = getMarkPrice(perpetual);
        require(
            perpetual.isInitialMarginSafe(trader, markPrice),
            "margin is unsafe after withdrawal"
        );
        isLastWithdrawal = perpetual.isEmptyAccount(trader);
        if (isLastWithdrawal) {
            deregisterActiveAccount(perpetual, trader);
        }
        emit Withdraw(perpetual.id, trader, amount);
    }

    /**
     * @dev     Clear the active account of the perpetual which state is "EMERGENCY" and send gas reward of collateral
     *          to sender.
     *          If all active accounts are cleared, the clear progress is done and the perpetual's state will
     *          change to "CLEARED".
     *
     * @param   perpetual       The reference of perpetual storage.
     * @param   trader          The address of the trader to clear.
     * @return  isAllCleared    True if all the active accounts are cleared.
     */
    function clear(PerpetualStorage storage perpetual, address trader)
        public
        returns (bool isAllCleared)
    {
        require(perpetual.activeAccounts.length() > 0, "no account to clear");
        require(
            perpetual.activeAccounts.contains(trader),
            "account cannot be cleared or already cleared"
        );
        countMargin(perpetual, trader);
        perpetual.activeAccounts.remove(trader);
        isAllCleared = (perpetual.activeAccounts.length() == 0);
        emit Clear(perpetual.id, trader);
    }

    /**
     * @dev     Check the margin balance of trader's account, update total margin.
     *          If the margin of the trader's account is not positive, it will be counted as 0.
     *
     * @param   perpetual   The reference of perpetual storage.
     * @param   trader      The address of the trader to be counted.
     */
    function countMargin(PerpetualStorage storage perpetual, address trader) public {
        int256 margin = perpetual.getMargin(trader, getMarkPrice(perpetual));
        if (margin <= 0) {
            return;
        }
        if (perpetual.getPosition(trader) != 0) {
            perpetual.totalMarginWithPosition = perpetual.totalMarginWithPosition.add(margin);
        } else {
            perpetual.totalMarginWithoutPosition = perpetual.totalMarginWithoutPosition.add(margin);
        }
    }

    /**
     * @dev     Get the address of the next active account in the perpetual.
     *
     * @param   perpetual   The reference of perpetual storage.
     * @return  account     The address of the next active account.
     */
    function getNextActiveAccount(PerpetualStorage storage perpetual)
        public
        view
        returns (address account)
    {
        require(perpetual.activeAccounts.length() > 0, "no active account");
        account = perpetual.activeAccounts.at(0);
    }

    /**
     * @dev     If the state of the perpetual is "CLEARED".
     *          The traders is able to settle all margin balance left in account.
     *          How much collateral can be returned is determined by the ratio of margin balance left in account to the
     *          total amount of collateral in perpetual.
     *          The priority is:
     *              - accounts withou position;
     *              - accounts with positions;
     *              - accounts with negative margin balance will get nothing back.
     *
     * @param   perpetual       The reference of perpetual storage.
     * @param   trader          The address of the trader to settle.
     * @param   marginToReturn  The actual collateral will be returned to the trader.
     */
    function settle(PerpetualStorage storage perpetual, address trader)
        public
        returns (int256 marginToReturn)
    {
        int256 price = getMarkPrice(perpetual);
        marginToReturn = perpetual.getSettleableMargin(trader, price);
        perpetual.resetAccount(trader);
        emit Settle(perpetual.id, trader, marginToReturn);
    }

    /**
     * @dev     Settle the total collateral of the perpetual, which means update redemptionRateWithPosition
     *          and redemptionRateWithoutPosition variables.
     *          If the total collateral is not enough for the accounts without position,
     *          all the total collateral is given to them proportionally.
     *          If the total collateral is more than the accounts without position needs,
     *          the extra part of collateral is given to the accounts with position proportionally.
     *
     * @param   perpetual   The reference of perpetual storage.
     */
    function settleCollateral(PerpetualStorage storage perpetual) public {
        int256 totalCollateral = perpetual.totalCollateral;
        // 2. cover margin without position
        if (totalCollateral < perpetual.totalMarginWithoutPosition) {
            // margin without positions get balance / total margin
            // smaller rate to make sure total redemption margin < total collateral of perpetual
            perpetual.redemptionRateWithoutPosition = perpetual.totalMarginWithoutPosition > 0
                ? totalCollateral.wdiv(perpetual.totalMarginWithoutPosition, Round.FLOOR)
                : 0;
            // margin with positions will get nothing
            perpetual.redemptionRateWithPosition = 0;
        } else {
            // 3. covere margin with position
            perpetual.redemptionRateWithoutPosition = Constant.SIGNED_ONE;
            // smaller rate to make sure total redemption margin < total collateral of perpetual
            perpetual.redemptionRateWithPosition = perpetual.totalMarginWithPosition > 0
                ? totalCollateral.sub(perpetual.totalMarginWithoutPosition).wdiv(
                    perpetual.totalMarginWithPosition,
                    Round.FLOOR
                )
                : 0;
        }
    }

    /**
     * @dev     Register the trader's account to the active accounts in the perpetual
     * @param   perpetual   The reference of perpetual storage.
     * @param   trader      The address of the trader.
     * @return  True if the trader is added to account for the first time.
     */
    function registerActiveAccount(PerpetualStorage storage perpetual, address trader)
        internal
        returns (bool)
    {
        return perpetual.activeAccounts.add(trader);
    }

    /**
     * @dev     Deregister the trader's account from the active accounts in the perpetual
     * @param   perpetual   The reference of perpetual storage.
     * @param   trader      The address of the trader.
     * @return  True if the trader is removed to account for the first time.
     */
    function deregisterActiveAccount(PerpetualStorage storage perpetual, address trader)
        internal
        returns (bool)
    {
        return perpetual.activeAccounts.remove(trader);
    }

    /**
     * @dev     Update the price data, which means the price and the update time
     * @param   priceData   The price data to update.
     * @param   priceGetter The function pointer to retrieve current price data.
     */
    function updatePriceData(
        OraclePriceData storage priceData,
        function() external returns (int256, uint256) priceGetter
    ) internal {
        (int256 price, uint256 time) = priceGetter();
        require(price > 0 && time != 0, "invalid price data");
        if (time >= priceData.time) {
            priceData.price = price;
            priceData.time = time;
        }
    }

    /**
     * @dev     Increase the total collateral of the perpetual
     * @param   perpetual   The reference of perpetual storage.
     * @param   amount      The amount of collateral to increase
     */
    function increaseTotalCollateral(PerpetualStorage storage perpetual, int256 amount) internal {
        require(amount >= 0, "amount is negative");
        perpetual.totalCollateral = perpetual.totalCollateral.add(amount);
    }

    /**
     * @dev     Decrease the total collateral of the perpetual
     * @param   perpetual   The reference of perpetual storage.
     * @param   amount      The amount of collateral to decrease
     */
    function decreaseTotalCollateral(PerpetualStorage storage perpetual, int256 amount) internal {
        require(amount >= 0, "amount is negative");
        console.log("decreaseTotalCollateral");
        console.logInt(perpetual.totalCollateral);
        console.logInt(amount);
        perpetual.totalCollateral = perpetual.totalCollateral.sub(amount);
        require(perpetual.totalCollateral >= 0, "collateral is negative");
    }

    /**
     * @dev     Update the option
     * @param   option      The option to update
     * @param   newValue    The new value of the option, must between the minimum value and the maximum value
     */
    function updateOption(Option storage option, int256 newValue) internal {
        require(newValue >= option.minValue && newValue <= option.maxValue, "value out of range");
        option.value = newValue;
    }

    /**
     * @dev     Set the option value, with constraints that newMinValue <= newValue <= newMaxValue.
     *
     * @param   option      The reference of option storage.
     * @param   newValue    The new value of the option, must be within range of [newMinValue, newMaxValue].
     * @param   newMinValue The minimum value of the option.
     * @param   newMaxValue The maximum value of the option.
     */
    function setOption(
        Option storage option,
        int256 newValue,
        int256 newMinValue,
        int256 newMaxValue
    ) internal {
        require(newValue >= newMinValue && newValue <= newMaxValue, "value out of range");
        option.value = newValue;
        option.minValue = newMinValue;
        option.maxValue = newMaxValue;
    }

    /**
     * @dev     Validate oracle contract, including each method of oracle
     *
     * @param   oracle   The address of oracle contract.
     */
    function validateOracle(address oracle) public {
        require(oracle != address(0), "invalid oracle address");
        require(oracle.isContract(), "oracle must be contract");
        bool success;
        bytes memory data;
        (success, data) = oracle.call(abi.encodeWithSignature("isMarketClosed()"));
        require(success && data.length == 32, "invalid function: isMarketClosed");
        (success, data) = oracle.call(abi.encodeWithSignature("isTerminated()"));
        require(success && data.length == 32, "invalid function: isTerminated");
        require(!abi.decode(data, (bool)), "oracle is terminated");
        (success, data) = oracle.call(abi.encodeWithSignature("collateral()"));
        require(success && data.length > 0, "invalid function: collateral");
        string memory result;
        result = abi.decode(data, (string));
        require(keccak256(bytes(result)) != keccak256(bytes("")), "oracle's collateral is empty");
        (success, data) = oracle.call(abi.encodeWithSignature("underlyingAsset()"));
        require(success && data.length > 0, "invalid function: underlyingAsset");
        result = abi.decode(data, (string));
        require(
            keccak256(bytes(result)) != keccak256(bytes("")),
            "oracle's underlyingAsset is empty"
        );
        (success, data) = oracle.call(abi.encodeWithSignature("priceTWAPLong()"));
        require(success && data.length > 0, "invalid function: priceTWAPLong");
        (int256 price, uint256 timestamp) = abi.decode(data, (int256, uint256));
        require(price > 0 && timestamp > 0, "oracle's twap long price is not updated");
        (success, data) = oracle.call(abi.encodeWithSignature("priceTWAPShort()"));
        require(success && data.length > 0, "invalid function: priceTWAPShort");
        (price, timestamp) = abi.decode(data, (int256, uint256));
        require(price > 0 && timestamp > 0, "oracle's twap short price is not updated");
    }

    /**
     * @dev     Validate the base parameters of the perpetual:
     *            1. initial margin rate > 0
     *            2. 0 < maintenance margin rate <= initial margin rate
     *            3. 0 <= operator fee rate <= 0.01
     *            4. 0 <= lp fee rate <= 0.01
     *            5. 0 <= liquidation penalty rate < maintenance margin rate
     *            6. keeper gas reward >= 0
     *
     * @param   perpetual   The reference of perpetual storage.
     * @param   baseParams  The base parameters of the perpetual.
     */
    function validateBaseParameters(PerpetualStorage storage perpetual, int256[9] memory baseParams)
        public
        view
    {
        require(baseParams[INDEX_INITIAL_MARGIN_RATE] > 0, "initialMarginRate <= 0");
        require(
            perpetual.initialMarginRate == 0 ||
                baseParams[INDEX_INITIAL_MARGIN_RATE] <= perpetual.initialMarginRate,
            "cannot increase initialMarginRate"
        );
        int256 maxLeverage = Constant.SIGNED_ONE.wdiv(baseParams[INDEX_INITIAL_MARGIN_RATE]);
        require(
            perpetual.defaultTargetLeverage.value <= maxLeverage,
            "default target leverage exceeds max leverage"
        );
        require(
            perpetual.maintenanceMarginRate == 0 ||
                baseParams[INDEX_MAINTENANCE_MARGIN_RATE] <= perpetual.maintenanceMarginRate,
            "cannot increase maintenanceMarginRate"
        );
        require(baseParams[INDEX_MAINTENANCE_MARGIN_RATE] > 0, "maintenanceMarginRate <= 0");
        require(
            baseParams[INDEX_MAINTENANCE_MARGIN_RATE] <= baseParams[INDEX_INITIAL_MARGIN_RATE],
            "maintenanceMarginRate > initialMarginRate"
        );
        require(baseParams[INDEX_OPERATOR_FEE_RATE] >= 0, "operatorFeeRate < 0");
        require(
            baseParams[INDEX_OPERATOR_FEE_RATE] <= (Constant.SIGNED_ONE / 100),
            "operatorFeeRate > 1%"
        );
        require(baseParams[INDEX_LP_FEE_RATE] >= 0, "lpFeeRate < 0");
        require(baseParams[INDEX_LP_FEE_RATE] <= (Constant.SIGNED_ONE / 100), "lpFeeRate > 1%");

        require(baseParams[INDEX_REFERRAL_REBATE_RATE] >= 0, "referralRebateRate < 0");
        require(
            baseParams[INDEX_REFERRAL_REBATE_RATE] <= Constant.SIGNED_ONE,
            "referralRebateRate > 100%"
        );

        require(baseParams[INDEX_LIQUIDATION_PENALTY_RATE] >= 0, "liquidationPenaltyRate < 0");
        require(
            baseParams[INDEX_LIQUIDATION_PENALTY_RATE] <= baseParams[INDEX_MAINTENANCE_MARGIN_RATE],
            "liquidationPenaltyRate > maintenanceMarginRate"
        );
        require(baseParams[INDEX_KEEPER_GAS_REWARD] >= 0, "keeperGasReward < 0");
        require(baseParams[INDEX_INSURANCE_FUND_RATE] >= 0, "insuranceFundRate < 0");
        require(baseParams[INDEX_MAX_OPEN_INTEREST_RATE] > 0, "maxOpenInterestRate <= 0");
    }

    /**
     * @dev     alidate the risk parameters of the perpetual
     *            1. 0 <= half spread < 1
     *            2. open slippage factor > 0
     *            3. 0 < close slippage factor <= open slippage factor
     *            4. funding rate limit >= 0
     *            5. AMM max leverage > 0
     *            6. 0 <= max close price discount < 1
     *
     * @param   perpetual   The reference of perpetual storage.
     */
    function validateRiskParameters(PerpetualStorage storage perpetual, int256[15] memory riskParams)
        public
        view
    {
        // must set risk parameters after setting base parameters
        require(perpetual.initialMarginRate > 0, "need to set base parameters first");
        require(riskParams[INDEX_HALF_SPREAD] >= 0, "halfSpread < 0");
        require(riskParams[INDEX_HALF_SPREAD] < Constant.SIGNED_ONE, "halfSpread >= 100%");
        require(riskParams[INDEX_OPEN_SLIPPAGE_FACTOR] > 0, "openSlippageFactor < 0");
        require(riskParams[INDEX_CLOSE_SLIPPAGE_FACTOR] > 0, "closeSlippageFactor < 0");
        require(
            riskParams[INDEX_CLOSE_SLIPPAGE_FACTOR] <= riskParams[INDEX_OPEN_SLIPPAGE_FACTOR],
            "closeSlippageFactor > openSlippageFactor"
        );
        require(riskParams[INDEX_FUNDING_RATE_FACTOR] >= 0, "fundingRateFactor < 0");
        require(riskParams[INDEX_FUNDING_RATE_LIMIT] >= 0, "fundingRateLimit < 0");
        require(riskParams[INDEX_AMM_MAX_LEVERAGE] >= 0, "ammMaxLeverage < 0");
        require(
            riskParams[INDEX_AMM_MAX_LEVERAGE] <=
                Constant.SIGNED_ONE.wdiv(perpetual.initialMarginRate, Round.FLOOR),
            "ammMaxLeverage > 1 / initialMarginRate"
        );
        require(riskParams[INDEX_AMM_CLOSE_PRICE_DISCOUNT] >= 0, "maxClosePriceDiscount < 0");
        require(
            riskParams[INDEX_AMM_CLOSE_PRICE_DISCOUNT] < Constant.SIGNED_ONE,
            "maxClosePriceDiscount >= 100%"
        );
        require(perpetual.initialMarginRate != 0, "initialMarginRate is not set");
        int256 maxLeverage = Constant.SIGNED_ONE.wdiv(perpetual.initialMarginRate);
        require(
            riskParams[INDEX_DEFAULT_TARGET_LEVERAGE] <= maxLeverage,
            "default target leverage exceeds max leverage"
        );
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @title SignedSafeMath
 * @dev Signed math operations with safety checks that revert on error.
 */
library SignedSafeMathUpgradeable {
    int256 constant private _INT256_MIN = -2**255;

    /**
     * @dev Returns the multiplication of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == _INT256_MIN), "SignedSafeMath: multiplication overflow");

        int256 c = a * b;
        require(c / a == b, "SignedSafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two signed integers. Reverts on
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
    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != 0, "SignedSafeMath: division by zero");
        require(!(b == -1 && a == _INT256_MIN), "SignedSafeMath: division overflow");

        int256 c = a / b;

        return c;
    }

    /**
     * @dev Returns the subtraction of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), "SignedSafeMath: subtraction overflow");

        return c;
    }

    /**
     * @dev Returns the addition of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), "SignedSafeMath: addition overflow");

        return c;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
library SafeMathUpgradeable {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
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
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
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
        require(b > 0, "SafeMath: modulo by zero");
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSetUpgradeable {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;

        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) { // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            bytes32 lastvalue = set._values[lastIndex];

            // Move the last value to the index where the value to delete is
            set._values[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            set._indexes[lastvalue] = toDeleteIndex + 1; // All indexes are 1-based

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }


    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;


/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCastUpgradeable {

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value < 2**128, "SafeCast: value doesn\'t fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value < 2**64, "SafeCast: value doesn\'t fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value < 2**32, "SafeCast: value doesn\'t fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value < 2**16, "SafeCast: value doesn\'t fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value < 2**8, "SafeCast: value doesn\'t fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128) {
        require(value >= -2**127 && value < 2**127, "SafeCast: value doesn\'t fit in 128 bits");
        return int128(value);
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64) {
        require(value >= -2**63 && value < 2**63, "SafeCast: value doesn\'t fit in 64 bits");
        return int64(value);
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32) {
        require(value >= -2**31 && value < 2**31, "SafeCast: value doesn\'t fit in 32 bits");
        return int32(value);
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16) {
        require(value >= -2**15 && value < 2**15, "SafeCast: value doesn\'t fit in 16 bits");
        return int16(value);
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= -2**7 && value < 2**7, "SafeCast: value doesn\'t fit in 8 bits");
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        require(value < 2**255, "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.4;

interface IOracle {
    /**
     * @dev The market is closed if the market is not in its regular trading period.
     */
    function isMarketClosed() external returns (bool);

    /**
     * @dev The oracle service was shutdown and never online again.
     */
    function isTerminated() external returns (bool);

    /**
     * @dev Get collateral symbol. Also known as quote.
     */
    function collateral() external view returns (string memory);

    /**
     * @dev Get underlying asset symbol. Also known as base.
     */
    function underlyingAsset() external view returns (string memory);

    /**
     * @dev Mark price. Used to evaluate the account margin balance and liquidation.
     *
     *      It does not need to be a TWAP. This name is only for backward compatibility.
     */
    function priceTWAPLong() external returns (int256 newPrice, uint256 newTimestamp);

    /**
     * @dev Index price. It is AMM reference price.
     *
     *      It does not need to be a TWAP. This name is only for backward compatibility.
     */
    function priceTWAPShort() external returns (int256 newPrice, uint256 newTimestamp);
}

// SPDX-License-Identifier: BUSL-1.1
// Refer to https://docs.pegasusfinance.xyz/protocol-overview/protocol-mechanism/code-use-notes
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "./Constant.sol";
import "./Utils.sol";

enum Round {
    CEIL,
    FLOOR
}

library SafeMathExt {
    using SafeMathUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;

    /*
     * @dev Always half up for uint256
     */
    function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(y).add(Constant.UNSIGNED_ONE / 2) / Constant.UNSIGNED_ONE;
    }

    /*
     * @dev Always half up for uint256
     */
    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(Constant.UNSIGNED_ONE).add(y / 2).div(y);
    }

    /*
     * @dev Always half up for uint256
     */
    function wfrac(
        uint256 x,
        uint256 y,
        uint256 z
    ) internal pure returns (uint256 r) {
        r = x.mul(y).add(z / 2).div(z);
    }

    /*
     * @dev Always half up if no rounding parameter
     */
    function wmul(int256 x, int256 y) internal pure returns (int256 z) {
        z = roundHalfUp(x.mul(y), Constant.SIGNED_ONE) / Constant.SIGNED_ONE;
    }

    /*
     * @dev Always half up if no rounding parameter
     */
    function wdiv(int256 x, int256 y) internal pure returns (int256 z) {
        if (y < 0) {
            y = neg(y);
            x = neg(x);
        }
        z = roundHalfUp(x.mul(Constant.SIGNED_ONE), y).div(y);
    }

    /*
     * @dev Always half up if no rounding parameter
     */
    function wfrac(
        int256 x,
        int256 y,
        int256 z
    ) internal pure returns (int256 r) {
        int256 t = x.mul(y);
        if (z < 0) {
            z = neg(z);
            t = neg(t);
        }
        r = roundHalfUp(t, z).div(z);
    }

    function wmul(
        int256 x,
        int256 y,
        Round round
    ) internal pure returns (int256 z) {
        z = div(x.mul(y), Constant.SIGNED_ONE, round);
    }

    function wdiv(
        int256 x,
        int256 y,
        Round round
    ) internal pure returns (int256 z) {
        z = div(x.mul(Constant.SIGNED_ONE), y, round);
    }

    function wfrac(
        int256 x,
        int256 y,
        int256 z,
        Round round
    ) internal pure returns (int256 r) {
        int256 t = x.mul(y);
        r = div(t, z, round);
    }

    function abs(int256 x) internal pure returns (int256) {
        return x >= 0 ? x : neg(x);
    }

    function neg(int256 a) internal pure returns (int256) {
        return SignedSafeMathUpgradeable.sub(int256(0), a);
    }

    /*
     * @dev ROUND_HALF_UP rule helper.
     *      You have to call roundHalfUp(x, y) / y to finish the rounding operation.
     *      0.5 ≈ 1, 0.4 ≈ 0, -0.5 ≈ -1, -0.4 ≈ 0
     */
    function roundHalfUp(int256 x, int256 y) internal pure returns (int256) {
        require(y > 0, "roundHalfUp only supports y > 0");
        if (x >= 0) {
            return x.add(y / 2);
        }
        return x.sub(y / 2);
    }

    /*
     * @dev Division, rounding ceil or rounding floor
     */
    function div(
        int256 x,
        int256 y,
        Round round
    ) internal pure returns (int256 divResult) {
        require(y != 0, "division by zero");
        divResult = x.div(y);
        if (x % y == 0) {
            return divResult;
        }
        bool isSameSign = Utils.hasTheSameSign(x, y);
        if (round == Round.CEIL && isSameSign) {
            divResult = divResult.add(1);
        }
        if (round == Round.FLOOR && !isSameSign) {
            divResult = divResult.sub(1);
        }
    }

    function max(int256 a, int256 b) internal pure returns (int256) {
        return a >= b ? a : b;
    }

    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

// SPDX-License-Identifier: BUSL-1.1
// Refer to https://docs.pegasusfinance.xyz/protocol-overview/protocol-mechanism/code-use-notes
pragma solidity 0.7.4;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "./SafeMathExt.sol";

library Utils {
    using SafeMathExt for int256;
    using SafeMathExt for uint256;
    using SafeMathUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    /*
     * @dev Check if two numbers have the same sign. Zero has the same sign with any number
     */
    function hasTheSameSign(int256 x, int256 y) internal pure returns (bool) {
        if (x == 0 || y == 0) {
            return true;
        }
        return (x ^ y) >> 255 == 0;
    }

    /**
     * @dev     Check if the trader has opened position in the trade.
     *          Example: 2, 1 => true; 2, -1 => false; -2, -3 => true
     * @param   amount  The position of the trader after the trade
     * @param   delta   The update position amount of the trader after the trade
     * @return  True if the trader has opened position in the trade
     */
    function hasOpenedPosition(int256 amount, int256 delta) internal pure returns (bool) {
        if (amount == 0) {
            return false;
        }
        return Utils.hasTheSameSign(amount, delta);
    }

    /*
     * @dev Split the delta to two numbers.
     *      Use for splitting the trading amount to the amount to close position and the amount to open position.
     *      Examples: 2, 1 => 0, 1; 2, -1 => -1, 0; 2, -3 => -2, -1
     */
    function splitAmount(int256 amount, int256 delta) internal pure returns (int256, int256) {
        if (Utils.hasTheSameSign(amount, delta)) {
            return (0, delta);
        } else if (amount.abs() >= delta.abs()) {
            return (delta, 0);
        } else {
            return (amount.neg(), amount.add(delta));
        }
    }

    /*
     * @dev Check if amount will be away from zero or cross zero if added the delta.
     *      Use for checking if trading amount will make trader open position.
     *      Example: 2, 1 => true; 2, -1 => false; 2, -3 => true
     */
    function isOpen(int256 amount, int256 delta) internal pure returns (bool) {
        return Utils.hasTheSameSign(amount, delta) || amount.abs() < delta.abs();
    }

    /*
     * @dev Get the id of the current chain
     */
    function chainID() internal pure returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }

    // function toArray(
    //     EnumerableSet.AddressSet storage set,
    //     uint256 begin,
    //     uint256 end
    // ) internal view returns (address[] memory result) {
    //     require(end > begin, "begin should be lower than end");
    //     uint256 length = set.length();
    //     if (begin >= length) {
    //         return result;
    //     }
    //     uint256 safeEnd = end.min(length);
    //     result = new address[](safeEnd.sub(begin));
    //     for (uint256 i = begin; i < safeEnd; i++) {
    //         result[i.sub(begin)] = set.at(i);
    //     }
    //     return result;
    // }

    function toArray(
        EnumerableSetUpgradeable.AddressSet storage set,
        uint256 begin,
        uint256 end
    ) internal view returns (address[] memory result) {
        require(end > begin, "begin should be lower than end");
        uint256 length = set.length();
        if (begin >= length) {
            return result;
        }
        uint256 safeEnd = end.min(length);
        result = new address[](safeEnd.sub(begin));
        for (uint256 i = begin; i < safeEnd; i++) {
            result[i.sub(begin)] = set.at(i);
        }
        return result;
    }

    function toArray(
        EnumerableSetUpgradeable.Bytes32Set storage set,
        uint256 begin,
        uint256 end
    ) internal view returns (bytes32[] memory result) {
        require(end > begin, "begin should be lower than end");
        uint256 length = set.length();
        if (begin >= length) {
            return result;
        }
        uint256 safeEnd = end.min(length);
        result = new bytes32[](safeEnd.sub(begin));
        for (uint256 i = begin; i < safeEnd; i++) {
            result[i.sub(begin)] = set.at(i);
        }
        return result;
    }
}

// SPDX-License-Identifier: BUSL-1.1
// Refer to https://docs.pegasusfinance.xyz/protocol-overview/protocol-mechanism/code-use-notes
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

/**
 * @notice  Perpetual state:
 *          - INVALID:      Uninitialized or not non-existent perpetual;
 *          - INITIALIZING: Only when LiquidityPoolStorage.isRunning == false. Traders cannot perform operations;
 *          - NORMAL:       Full functional state. Traders is able to perform all operations;
 *          - EMERGENCY:    Perpetual is unsafe and only clear is available;
 *          - CLEARED:      All margin account is cleared. Trade could withdraw remaining margin balance.
 */
enum PerpetualState {
    INVALID,
    INITIALIZING,
    NORMAL,
    EMERGENCY,
    CLEARED
}
enum OrderType {
    LIMIT,
    MARKET,
    STOP
}

/**
 * @notice  Data structure to store risk parameter value.
 */
struct Option {
    int256 value;
    int256 minValue;
    int256 maxValue;
}

/**
 * @notice  Data structure to store oracle price data.
 */
struct OraclePriceData {
    int256 price;
    uint256 time;
}

/**
 * @notice  Data structure to store user margin information. See MarginAccountModule.sol for details.
 */
struct MarginAccount {
    int256 cash;
    int256 position;
    int256 targetLeverage;
    int256 entryValue;
}

/**
 * @notice  Data structure of an order object.
 */
struct Order {
    address trader;
    address broker;
    address relayer;
    address referrer;
    address liquidityPool;
    int256 minTradeAmount;
    int256 amount;
    int256 limitPrice;
    int256 triggerPrice;
    uint256 chainID;
    uint64 expiredAt;
    uint32 perpetualIndex;
    uint32 brokerFeeLimit;
    uint32 flags;
    uint32 salt;
}

/**
 * @notice  Core data structure, a core .
 */
struct LiquidityPoolStorage {
    bool isRunning;
    bool isFastCreationEnabled;
    // addresses
    address creator;
    address operator;
    address transferringOperator;
    address governor;
    address shareToken;
    address accessController;
    bool reserved3; // isWrapped
    uint256 scaler;
    uint256 collateralDecimals;
    address collateralToken;
    // pool attributes
    int256 poolCash;
    uint256 fundingTime;
    uint256 reserved5;
    uint256 operatorExpiration;
    mapping(address => int256) reserved1;
    bytes32[] reserved2;
    // perpetuals
    uint256 perpetualCount;
    mapping(uint256 => PerpetualStorage) perpetuals;
    // insurance fund
    int256 insuranceFundCap;
    int256 insuranceFund;
    int256 donatedInsuranceFund;
    address reserved4;
    uint256 liquidityCap;
    uint256 shareTransferDelay;
    address lpAuth;
    // reserved slot for future upgrade
    bytes32[13] reserved;
}

/**
 * @notice  Core data structure, storing perpetual information.
 */
struct PerpetualStorage {
    uint256 id;
    PerpetualState state;
    address oracle;
    int256 totalCollateral;
    int256 openInterest;
    // prices
    OraclePriceData indexPriceData;
    OraclePriceData markPriceData;
    OraclePriceData settlementPriceData;
    // funding state
    int256 fundingRate;
    int256 unitAccumulativeFunding;
    int256 unitAccumulativeShortFunding;
    int256 unitAccumulativeLongFunding;
    // base parameters
    int256 initialMarginRate;
    int256 maintenanceMarginRate;
    int256 operatorFeeRate;
    int256 lpFeeRate;
    int256 referralRebateRate;
    int256 liquidationPenaltyRate;
    int256 keeperGasReward;
    int256 insuranceFundRate;
    int256 reserved1;
    int256 maxOpenInterestRate;
    // risk parameters
    Option halfSpread;
    Option openSlippageFactor;
    Option closeSlippageFactor;
    Option fundingRateLimit;
    Option fundingRateFactor;
    Option ammMaxLeverage;
    Option maxClosePriceDiscount;
    Option openSlippageLongPenaltyFactor;
    Option openSlippageShortPenaltyFactor;
    Option meanRate;
    Option maxRate;
    Option longMeanRevertFactor;
    Option shortMeanRevertFactor;
    // users
    uint256 totalAccount;
    int256 totalMarginWithoutPosition;
    int256 totalMarginWithPosition;
    int256 redemptionRateWithoutPosition;
    int256 redemptionRateWithPosition;
    EnumerableSetUpgradeable.AddressSet activeAccounts;
    // insurance fund
    int256 reserved2;
    int256 reserved3;
    // accounts
    mapping(address => MarginAccount) marginAccounts;
    Option defaultTargetLeverage;
    // keeper
    address reserved4;
    EnumerableSetUpgradeable.AddressSet ammKeepers;
    EnumerableSetUpgradeable.AddressSet reserved5;
    Option baseFundingRate;
    // reserved slot for future upgrade
    bytes32[9] reserved;
}

// SPDX-License-Identifier: BUSL-1.1
// Refer to https://docs.pegasusfinance.xyz/protocol-overview/protocol-mechanism/code-use-notes
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../libraries/Math.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Utils.sol";
import "../libraries/OrderData.sol";

import "../Type.sol";

import "hardhat/console.sol";

library MarginAccountModule {
    using Math for int256;
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;
    using SafeCastUpgradeable for uint256;
    using OrderData for uint32;

    /**
     * @dev Get the initial margin of the trader in the perpetual.
     *      Initial margin = price * abs(position) * initial margin rate
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @param price The price to calculate the initial margin
     * @return initialMargin The initial margin of the trader in the perpetual
     */
    function getInitialMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (int256 initialMargin) {
        initialMargin = perpetual
            .marginAccounts[trader]
            .position
            .wmul(price)
            .wmul(perpetual.initialMarginRate)
            .abs();
    }


    /**
     * @dev Get the maintenance margin of the trader in the perpetual.
     *      Maintenance margin = price * abs(position) * maintenance margin rate
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @param price The price to calculate the  maintenance margin
     * @return maintenanceMargin The maintenance margin of the trader in the perpetual
     */
    function getMaintenanceMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (int256 maintenanceMargin) {
        maintenanceMargin = perpetual
            .marginAccounts[trader]
            .position
            .wmul(price)
            .wmul(perpetual.maintenanceMarginRate)
            .abs();
    }

    function getFundingWithMeanPenalty(
        PerpetualStorage storage perpetual,
        MarginAccount storage account,
        int256 position,
        int256 entryValue
    ) internal view returns (int256) {
        int256 funding = position.wmul(perpetual.unitAccumulativeFunding);
        console.log("funding");
        console.logInt(funding);
        int256 entryValAdj;
        if (entryValue != 0) {
            entryValAdj = entryValue.abs();
        } else if (account.position != 0){
            entryValAdj = account.entryValue.wmul(position).wdiv(account.position).abs();
        } else {
            return funding;
        }
        console.log("position");
        console.logInt(position);
        console.log("entryValAdj");
        console.logInt(entryValAdj);
        int256 meanAdj = perpetual.meanRate.value.wmul(position).abs();
        console.log("meanAdj");
        console.logInt(meanAdj);
        int256 penalty = 0;
        if (entryValAdj < meanAdj) {
            int256 meanRevertPenalty = perpetual.longMeanRevertFactor.value.wmul(
                meanAdj.sub(entryValAdj)
            );
            penalty = meanRevertPenalty.wmul(perpetual.unitAccumulativeLongFunding);
            if (position < 0) {
                penalty = penalty.neg();
            }
        } else if (entryValAdj > meanAdj){
            int256 meanRevertPenalty = perpetual.shortMeanRevertFactor.value.wmul(
                entryValAdj.sub(meanAdj)
            );
            penalty = meanRevertPenalty.wmul(perpetual.unitAccumulativeShortFunding);
            if (position < 0) {
                penalty = penalty.neg();
            }
        }
        console.log("penalty");
        console.logInt(penalty);
        funding = funding.add(penalty);
        return funding;
    }

    /**
     * @dev Get the available cash of the trader in the perpetual.
     *      Available cash = cash - position * unit accumulative funding
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @return availableCash The available cash of the trader in the perpetual
     */
    function getAvailableCash(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (int256 availableCash)
    {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        console.log("accountCash");
        console.logInt(account.cash);
        console.log("fundingWMeanPen");
        console.log("params");
        console.logInt(account.position);
        console.logInt(getFundingWithMeanPenalty(perpetual, account, account.position, 0));
        availableCash = account.cash.sub(
            getFundingWithMeanPenalty(perpetual, account, account.position, 0)
        );
    }

    /**
     * @dev Get the position of the trader in the perpetual
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @return position The position of the trader in the perpetual
     */
    function getPosition(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (int256 position)
    {
        position = perpetual.marginAccounts[trader].position;
    }

    /**
     * @dev Get the margin of the trader in the perpetual.
     *      Margin = available cash + position * price
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @param price The price to calculate the margin
     * @return margin The margin of the trader in the perpetual
     */
    function getMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (int256 margin) {
        margin = perpetual.marginAccounts[trader].position.wmul(price).add(
            getAvailableCash(perpetual, trader)
        );
    }

    /**
     * @dev Get the settleable margin of the trader in the perpetual.
     *      This is the margin trader can withdraw when the state of the perpetual is "CLEARED".
     *      If the state of the perpetual is not "CLEARED", the settleable margin is always zero
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @param price The price to calculate the settleable margin
     * @return margin The settleable margin of the trader in the perpetual
     */
    function getSettleableMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (int256 margin) {
        margin = getMargin(perpetual, trader, price);
        if (margin > 0) {
            int256 rate = (getPosition(perpetual, trader) == 0)
                ? perpetual.redemptionRateWithoutPosition
                : perpetual.redemptionRateWithPosition;
            // make sure total redemption margin < total collateral of perpetual
            margin = margin.wmul(rate, Round.FLOOR);
        } else {
            margin = 0;
        }
    }

    /**
     * @dev     Get the available margin of the trader in the perpetual.
     *          Available margin = margin - (initial margin + keeper gas reward), keeper gas reward = 0 if position = 0
     * @param   perpetual   The perpetual object
     * @param   trader      The address of the trader
     * @param   price       The price to calculate available margin
     * @return  availableMargin The available margin of the trader in the perpetual
     */
    function getAvailableMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (int256 availableMargin) {
        int256 threshold = getPosition(perpetual, trader) == 0
            ? 0
            : getInitialMargin(perpetual, trader, price).add(perpetual.keeperGasReward);
        availableMargin = getMargin(perpetual, trader, price).sub(threshold);
    }

    /**
     * @dev     Check if the trader is initial margin safe in the perpetual, which means available margin >= 0
     * @param   perpetual   The perpetual object
     * @param   trader      The address of the trader
     * @param   price       The price to calculate the available margin
     * @return  isSafe      True if the trader is initial margin safe in the perpetual
     */
    function isInitialMarginSafe(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (bool isSafe) {
        isSafe = (getAvailableMargin(perpetual, trader, price) >= 0);
    }

    /**
     * @dev Check if the trader is maintenance margin safe in the perpetual, which means
     *      margin >= maintenance margin + keeper gas reward. Keeper gas reward = 0 if position = 0
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @param price The price to calculate the maintenance margin
     * @return isSafe True if the trader is maintenance margin safe in the perpetual
     */
    function isMaintenanceMarginSafe(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (bool isSafe) {
        int256 threshold = getPosition(perpetual, trader) == 0
            ? 0
            : getMaintenanceMargin(perpetual, trader, price).add(perpetual.keeperGasReward);
        isSafe = getMargin(perpetual, trader, price) >= threshold;
    }

    /**
     * @dev Check if the trader is margin safe in the perpetual, which means margin >= keeper gas reward.
     *      Keeper gas reward = 0 if position = 0
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @param price The price to calculate the margin
     * @return isSafe True if the trader is margin safe in the perpetual
     */
    function isMarginSafe(
        PerpetualStorage storage perpetual,
        address trader,
        int256 price
    ) internal view returns (bool isSafe) {
        int256 threshold = getPosition(perpetual, trader) == 0 ? 0 : perpetual.keeperGasReward;
        isSafe = getMargin(perpetual, trader, price) >= threshold;
    }

    /**
     * @dev Check if the account of the trader is empty in the perpetual, which means cash = 0 and position = 0
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @return isEmpty True if the account of the trader is empty in the perpetual
     */
    function isEmptyAccount(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (bool isEmpty)
    {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        isEmpty = (account.cash == 0 && account.position == 0);
    }

    /**
     * @dev Update the trader's cash in the perpetual
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @param deltaCash The update cash(collateral) of the trader's account in the perpetual
     */
    function updateCash(
        PerpetualStorage storage perpetual,
        address trader,
        int256 deltaCash
    ) internal {
        if (deltaCash == 0) {
            return;
        }
        MarginAccount storage account = perpetual.marginAccounts[trader];
        account.cash = account.cash.add(deltaCash);
    }

    function getNewEntryValue(
        PerpetualStorage storage perpetual,
        MarginAccount storage account,
        int256 deltaPosition,
        int256 deltaCash
    ) view internal returns (int256 newEntryValue, int256 fundingToAdd) {
        int256 oldPosition = account.position;
        int256 oldEntryValue = account.entryValue;
        newEntryValue = oldEntryValue;
        fundingToAdd = 0;
        (int256 closePosition, int256 openPosition) = Utils.splitAmount(
            oldPosition, deltaPosition);
        if (closePosition != 0) {
            newEntryValue = oldEntryValue.wmul(
                oldPosition.add(closePosition)
            ).wdiv(oldPosition);
            fundingToAdd = fundingToAdd.add(
                getFundingWithMeanPenalty(perpetual, account, closePosition, 0)
            );
        }
        if (openPosition != 0) {
            fundingToAdd = fundingToAdd.add(
                getFundingWithMeanPenalty(
                    perpetual, account, openPosition, deltaCash.wmul(openPosition).wdiv(deltaPosition)
                )
            );
            newEntryValue = newEntryValue.add(
                deltaCash.wmul(openPosition).wdiv(deltaPosition)
            );
        }
    }

    function getNewEntryValuePerp(
        PerpetualStorage storage perpetual,
        MarginAccount storage account,
        int256 deltaPosition,
        int256 deltaCash,
        address counterTrader
    ) view internal returns (int256 newEntryValue, int256 fundingToAdd) {
        newEntryValue = account.entryValue;
        MarginAccount storage counter = perpetual.marginAccounts[counterTrader];
        fundingToAdd = 0;

        (int256 closePosition, int256 openPosition) = Utils.splitAmount(
            counter.position, deltaPosition.neg());

        if (closePosition != 0) {
            int256 closedValue = (
                counter.entryValue
                .wmul(closePosition)
                .wdiv(counter.position)
            );
            newEntryValue = newEntryValue.sub(closedValue);
            fundingToAdd = fundingToAdd.add(
                getFundingWithMeanPenalty(
                    perpetual, account, closePosition.neg(), closedValue
                )
            );
        }

        if (openPosition != 0) {
            fundingToAdd = fundingToAdd.add(
                getFundingWithMeanPenalty(
                    perpetual, account, openPosition.neg(), deltaCash.wmul(openPosition).wdiv(deltaPosition)
                )
            );
            newEntryValue = newEntryValue.add(
                deltaCash.wmul(openPosition).wdiv(deltaPosition).neg()
            );
        }
    }

    /**
     * @dev Update the trader's account in the perpetual
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     * @param deltaPosition The update position of the trader's account in the perpetual
     * @param deltaCash The update cash(collateral) of the trader's account in the perpetual
     */
    function updateMargin(
        PerpetualStorage storage perpetual,
        address trader,
        int256 deltaPosition,
        int256 deltaCash,
        bool isPerp,
        address counterTrader
    ) internal returns (int256 deltaOpenInterest) {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        int256 oldPosition = account.position;
        int256 entryValue;
        int256 fundingToAdd;
        if (isPerp) {
            (entryValue, fundingToAdd) = getNewEntryValuePerp(
                perpetual, account, deltaPosition, deltaCash,
                counterTrader
            );
        } else {
            (entryValue, fundingToAdd) = getNewEntryValue(
                perpetual, account, deltaPosition, deltaCash
            );
        }
        console.log("updateMargin");
        console.log("deltaPosition");
        console.logInt(deltaPosition);
        console.log("entryValue");
        console.logInt(entryValue);
        console.log("fundingToAdd");
        console.logInt(fundingToAdd);
        account.entryValue = entryValue;
        account.position = account.position.add(deltaPosition);
        account.cash = account.cash.add(deltaCash).add(fundingToAdd);
        if (oldPosition > 0) {
            deltaOpenInterest = oldPosition.neg();
        }
        if (account.position > 0) {
            deltaOpenInterest = deltaOpenInterest.add(account.position);
        }
        perpetual.openInterest = perpetual.openInterest.add(deltaOpenInterest);
    }

    /**
     * @dev Reset the trader's account in the perpetual to empty, which means position = 0 and cash = 0
     * @param perpetual The perpetual object
     * @param trader The address of the trader
     */
    function resetAccount(PerpetualStorage storage perpetual, address trader) internal {
        MarginAccount storage account = perpetual.marginAccounts[trader];
        account.cash = 0;
        account.position = 0;
    }

    // deprecated
    function setTargetLeverage(
        PerpetualStorage storage perpetual,
        address trader,
        int256 targetLeverage
    ) internal {
        perpetual.marginAccounts[trader].targetLeverage = targetLeverage;
    }

    function getTargetLeverage(PerpetualStorage storage perpetual, address trader)
        internal
        view
        returns (int256)
    {
        require(perpetual.initialMarginRate != 0, "initialMarginRate is not set");
        int256 maxLeverage = Constant.SIGNED_ONE.wdiv(perpetual.initialMarginRate);
        int256 targetLeverage = perpetual.marginAccounts[trader].targetLeverage;
        targetLeverage = targetLeverage == 0
            ? perpetual.defaultTargetLeverage.value
            : targetLeverage;
        return targetLeverage.min(maxLeverage);
    }

    function getTargetLeverageWithFlags(
        PerpetualStorage storage perpetual,
        address trader,
        uint32 flags
    ) internal view returns (int256 targetLeverage) {
        require(perpetual.initialMarginRate != 0, "initialMarginRate is not set");
        int256 maxLeverage = Constant.SIGNED_ONE.wdiv(perpetual.initialMarginRate);
        bool _oldUseTargetLeverage = flags.oldUseTargetLeverage();
        bool _newUseTargetLeverage = flags.newUseTargetLeverage();
        require(!(_oldUseTargetLeverage && _newUseTargetLeverage), "invalid flags");
        if (_oldUseTargetLeverage) {
            targetLeverage = perpetual.marginAccounts[trader].targetLeverage;
        } else {
            targetLeverage = flags.getTargetLeverageByFlags();
        }
        targetLeverage = targetLeverage == 0
            ? perpetual.defaultTargetLeverage.value
            : targetLeverage;
        targetLeverage = targetLeverage.min(maxLeverage);
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

// SPDX-License-Identifier: BUSL-1.1
// Refer to https://docs.pegasusfinance.xyz/protocol-overview/protocol-mechanism/code-use-notes
pragma solidity 0.7.4;

library Constant {
    address internal constant INVALID_ADDRESS = address(0);

    int256 internal constant SIGNED_ONE = 10**18;
    uint256 internal constant UNSIGNED_ONE = 10**18;

    uint256 internal constant PRIVILEGE_DEPOSIT = 0x1;
    uint256 internal constant PRIVILEGE_WITHDRAW = 0x2;
    uint256 internal constant PRIVILEGE_TRADE = 0x4;
    uint256 internal constant PRIVILEGE_LIQUIDATE = 0x8;
    uint256 internal constant PRIVILEGE_GUARD =
        PRIVILEGE_DEPOSIT | PRIVILEGE_WITHDRAW | PRIVILEGE_TRADE | PRIVILEGE_LIQUIDATE;
    // max number of uint256
    uint256 internal constant SET_ALL_PERPETUALS_TO_EMERGENCY_STATE =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;

        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) { // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            bytes32 lastvalue = set._values[lastIndex];

            // Move the last value to the index where the value to delete is
            set._values[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            set._indexes[lastvalue] = toDeleteIndex + 1; // All indexes are 1-based

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }


    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}

// SPDX-License-Identifier: BUSL-1.1
// Refer to https://docs.pegasusfinance.xyz/protocol-overview/protocol-mechanism/code-use-notes
pragma solidity >=0.7.4;

library Math {
    /**
     * @dev Get the most significant bit of the number,
            example: 0 ~ 1 => 0, 2 ~ 3 => 1, 4 ~ 7 => 2, 8 ~ 15 => 3,
            about use 606 ~ 672 gas
     * @param x The number
     * @return uint8 The significant bit of the number
     */
    function mostSignificantBit(uint256 x) internal pure returns (uint8) {
        uint256 t;
        uint8 r;
        if ((t = (x >> 128)) > 0) {
            x = t;
            r += 128;
        }
        if ((t = (x >> 64)) > 0) {
            x = t;
            r += 64;
        }
        if ((t = (x >> 32)) > 0) {
            x = t;
            r += 32;
        }
        if ((t = (x >> 16)) > 0) {
            x = t;
            r += 16;
        }
        if ((t = (x >> 8)) > 0) {
            x = t;
            r += 8;
        }
        if ((t = (x >> 4)) > 0) {
            x = t;
            r += 4;
        }
        if ((t = (x >> 2)) > 0) {
            x = t;
            r += 2;
        }
        if ((t = (x >> 1)) > 0) {
            x = t;
            r += 1;
        }
        return r;
    }

    // https://en.wikipedia.org/wiki/Integer_square_root
    /**
     * @dev Get the square root of the number
     * @param x The number, usually 10^36
     * @return int256 The square root of the number, usually 10^18
     */
    function sqrt(int256 x) internal pure returns (int256) {
        require(x >= 0, "negative sqrt");
        if (x < 3) {
            return (x + 1) / 2;
        }

        // binary estimate
        // inspired by https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Binary_estimates
        uint8 n = mostSignificantBit(uint256(x));
        // make sure initial estimate > sqrt(x)
        // 2^ceil((n + 1) / 2) as initial estimate
        // 2^(n + 1) > x
        // => 2^ceil((n + 1) / 2) > 2^((n + 1) / 2) > sqrt(x)
        n = (n + 1) / 2 + 1;

        // modified babylonian method
        int256 next = int256(1 << n);
        int256 y;
        do {
            y = next;
            next = (next + x / next) >> 1;
        } while (next < y);
        return y;
    }
}

// SPDX-License-Identifier: BUSL-1.1
// Refer to https://docs.pegasusfinance.xyz/protocol-overview/protocol-mechanism/code-use-notes
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../libraries/Utils.sol";
import "../Type.sol";

library OrderData {
    uint32 internal constant MASK_CLOSE_ONLY = 0x80000000;
    uint32 internal constant MASK_MARKET_ORDER = 0x40000000;
    uint32 internal constant MASK_STOP_LOSS_ORDER = 0x20000000;
    uint32 internal constant MASK_TAKE_PROFIT_ORDER = 0x10000000;
    uint32 internal constant MASK_USE_TARGET_LEVERAGE = 0x08000000;

    // old domain, will be removed in future
    string internal constant DOMAIN_NAME = "Mai Protocol v3";
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(abi.encodePacked("EIP712Domain(string name)"));
    bytes32 internal constant DOMAIN_SEPARATOR =
        keccak256(abi.encodePacked(EIP712_DOMAIN_TYPEHASH, keccak256(bytes(DOMAIN_NAME))));
    bytes32 internal constant EIP712_ORDER_TYPE =
        keccak256(
            abi.encodePacked(
                "Order(address trader,address broker,address relayer,address referrer,address liquidityPool,",
                "int256 minTradeAmount,int256 amount,int256 limitPrice,int256 triggerPrice,uint256 chainID,",
                "uint64 expiredAt,uint32 perpetualIndex,uint32 brokerFeeLimit,uint32 flags,uint32 salt)"
            )
        );

    /*
     * @dev Check if the order is close-only order. Close-only order means the order can only close position
     *      of the trader
     * @param order The order object
     * @return bool True if the order is close-only order
     */
    function isCloseOnly(Order memory order) internal pure returns (bool) {
        return (order.flags & MASK_CLOSE_ONLY) > 0;
    }

    /*
     * @dev Check if the order is market order. Market order means the order which has no limit price, should be
     *      executed immediately
     * @param order The order object
     * @return bool True if the order is market order
     */
    function isMarketOrder(Order memory order) internal pure returns (bool) {
        return (order.flags & MASK_MARKET_ORDER) > 0;
    }

    /*
     * @dev Check if the order is stop-loss order. Stop-loss order means the order will trigger when the
     *      price is worst than the trigger price
     * @param order The order object
     * @return bool True if the order is stop-loss order
     */
    function isStopLossOrder(Order memory order) internal pure returns (bool) {
        return (order.flags & MASK_STOP_LOSS_ORDER) > 0;
    }

    /*
     * @dev Check if the order is take-profit order. Take-profit order means the order will trigger when
     *      the price is better than the trigger price
     * @param order The order object
     * @return bool True if the order is take-profit order
     */
    function isTakeProfitOrder(Order memory order) internal pure returns (bool) {
        return (order.flags & MASK_TAKE_PROFIT_ORDER) > 0;
    }

    /*
     * @dev Check if the flags contain close-only flag
     * @param flags The flags
     * @return bool True if the flags contain close-only flag
     */
    function isCloseOnly(uint32 flags) internal pure returns (bool) {
        return (flags & MASK_CLOSE_ONLY) > 0;
    }

    /*
     * @dev Check if the flags contain market flag
     * @param flags The flags
     * @return bool True if the flags contain market flag
     */
    function isMarketOrder(uint32 flags) internal pure returns (bool) {
        return (flags & MASK_MARKET_ORDER) > 0;
    }

    /*
     * @dev Check if the flags contain stop-loss flag
     * @param flags The flags
     * @return bool True if the flags contain stop-loss flag
     */
    function isStopLossOrder(uint32 flags) internal pure returns (bool) {
        return (flags & MASK_STOP_LOSS_ORDER) > 0;
    }

    /*
     * @dev Check if the flags contain take-profit flag
     * @param flags The flags
     * @return bool True if the flags contain take-profit flag
     */
    function isTakeProfitOrder(uint32 flags) internal pure returns (bool) {
        return (flags & MASK_TAKE_PROFIT_ORDER) > 0;
    }

    function oldUseTargetLeverage(uint32 flags) internal pure returns (bool) {
        return (flags & MASK_USE_TARGET_LEVERAGE) > 0;
    }

    function newUseTargetLeverage(uint32 flags) internal pure returns (bool) {
        return getTargetLeverageByFlags(flags) > 0;
    }

    function getTargetLeverageByFlags(uint32 flags) internal pure returns (int256) {
        return int256((flags >> 7) & 0xfffff) * 10**16;
    }

    function useTargetLeverage(uint32 flags) internal pure returns (bool) {
        bool _oldUseTargetLeverage = oldUseTargetLeverage(flags);
        bool _newUseTargetLeverage = newUseTargetLeverage(flags);
        require(!(_oldUseTargetLeverage && _newUseTargetLeverage), "invalid flags");
        return _oldUseTargetLeverage || _newUseTargetLeverage;
    }

    /*
     * @dev Get the hash of the order
     * @param order The order object
     * @return bytes32 The hash of the order
     */
    function getOrderHash(Order memory order) internal pure returns (bytes32) {
        bytes32 result = keccak256(abi.encode(EIP712_ORDER_TYPE, order));
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, result));
    }

    /*
     * @dev Decode the signature from the data
     * @param data The data object to decode
     * @return signature The signature
     */
    function decodeSignature(bytes memory data) internal pure returns (bytes memory signature) {
        require(data.length >= 350, "broken data");
        bytes32 r;
        bytes32 s;
        uint8 v;
        uint8 signType;
        assembly {
            r := mload(add(data, 318))
            s := mload(add(data, 350))
            v := byte(24, mload(add(data, 292)))
            signType := byte(25, mload(add(data, 292)))
        }
        signature = abi.encodePacked(r, s, v, signType);
    }

    /*
     * @dev Decode the order from the data
     * @param data The data object to decode
     * @return order The order
     */
    function decodeOrderData(bytes memory data) internal pure returns (Order memory order) {
        require(data.length >= 256, "broken data");
        bytes32 tmp;
        assembly {
            // trader / 20
            mstore(add(order, 0), mload(add(data, 20)))
            // broker / 20
            mstore(add(order, 32), mload(add(data, 40)))
            // relayer / 20
            mstore(add(order, 64), mload(add(data, 60)))
            // referrer / 20
            mstore(add(order, 96), mload(add(data, 80)))
            // liquidityPool / 20
            mstore(add(order, 128), mload(add(data, 100)))
            // minTradeAmount / 32
            mstore(add(order, 160), mload(add(data, 132)))
            // amount / 32
            mstore(add(order, 192), mload(add(data, 164)))
            // limitPrice / 32
            mstore(add(order, 224), mload(add(data, 196)))
            // triggerPrice / 32
            mstore(add(order, 256), mload(add(data, 228)))
            // chainID / 32
            mstore(add(order, 288), mload(add(data, 260)))
            // expiredAt + perpetualIndex + brokerFeeLimit + flags + salt + v + signType / 26
            tmp := mload(add(data, 292))
        }
        order.expiredAt = uint64(bytes8(tmp));
        order.perpetualIndex = uint32(bytes4(tmp << 64));
        order.brokerFeeLimit = uint32(bytes4(tmp << 96));
        order.flags = uint32(bytes4(tmp << 128));
        order.salt = uint32(bytes4(tmp << 160));
    }
}