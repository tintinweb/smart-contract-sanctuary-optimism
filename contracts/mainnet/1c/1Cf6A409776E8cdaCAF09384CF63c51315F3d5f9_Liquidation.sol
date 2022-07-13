// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import {IBaseToken} from "./interface/IBaseToken.sol";
import {IClearingHouse} from "./interface/IClearingHouse.sol";
import {IClearingHouseConfig} from "./interface/IClearingHouseConfig.sol";
import {IAccountBalance} from "./interface/IAccountBalance.sol";

contract Liquidation {
    address owner;
    address liquidator;
    address accountBalance;
    address clearingHouse;
    address clearingHouseConfig;

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    modifier onlyLiquidator() {
        require(msg.sender == liquidator, "only liquidator");
        _;
    }

    constructor(
        address _accountBalance,
        address _clearingHouse,
        address _clearingHouseConfig
    ) {
        owner = msg.sender;
        liquidator = msg.sender;
        accountBalance = _accountBalance;
        clearingHouse = _clearingHouse;
        clearingHouseConfig = _clearingHouseConfig;
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
    }

    function setLiquidator(address _liquidator) external onlyOwner {
        liquidator = _liquidator;
    }

    function setAccountBalance(address _accountBalance) external onlyOwner {
        accountBalance = _accountBalance;
    }

    function setClearinghouse(address _clearingHouse) external onlyOwner {
        clearingHouse = _clearingHouse;
    }

    function setClearinghouseConfig(address _clearingHouseConfig)
        external
        onlyOwner
    {
        clearingHouseConfig = _clearingHouseConfig;
    }

    function checkLiquidatable(
        address[] memory traders,
        address[] memory baseTokens
    ) external view onlyLiquidator returns (bool[] memory) {
        require(traders.length == baseTokens.length, "invalid params");

        bool[] memory results = new bool[](traders.length);
        for (uint256 i = 0; i < traders.length; i++) {
            address trader = traders[i];
            address baseToken = baseTokens[i];

            bool liquidatable = _checkLiquidatable(trader, baseToken);
            results[i] = liquidatable;
        }

        return results;
    }

    function _checkLiquidatable(address trader, address baseToken)
        internal
        view
        returns (bool liquidatable)
    {
        bool isOpen = IBaseToken(baseToken).isOpen();
        bool hasOrder = IAccountBalance(accountBalance).hasOrder(trader);
        int256 accountValue = IClearingHouse(clearingHouse).getAccountValue(
            trader
        );
        int256 marginRequirementForLiquidation = IAccountBalance(accountBalance)
            .getMarginRequirementForLiquidation(trader);

        bool isBackstopLiquidityProvider = IClearingHouseConfig(
            clearingHouseConfig
        ).isBackstopLiquidityProvider(msg.sender);
        bool isValidLiquidator = isBackstopLiquidityProvider ||
            accountValue >= 0;

        return
            isOpen &&
            !hasOrder &&
            (accountValue < marginRequirementForLiquidation) &&
            isValidLiquidator;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

interface IBaseToken {
    // Do NOT change the order of enum values because it will break backwards compatibility
    enum Status { Open, Paused, Closed }

    event PriceFeedChanged(address indexed priceFeed);
    event StatusUpdated(Status indexed status);

    function close() external;

    /// @notice Get the price feed address
    /// @return priceFeed the current price feed
    function getPriceFeed() external view returns (address priceFeed);

    function getPausedTimestamp() external view returns (uint256);

    function getPausedIndexPrice() external view returns (uint256);

    function getClosedPrice() external view returns (uint256);

    function isOpen() external view returns (bool);

    function isPaused() external view returns (bool);

    function isClosed() external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

interface IClearingHouse {
    /// @param useTakerBalance only accept false now
    struct AddLiquidityParams {
        address baseToken;
        uint256 base;
        uint256 quote;
        int24 lowerTick;
        int24 upperTick;
        uint256 minBase;
        uint256 minQuote;
        bool useTakerBalance;
        uint256 deadline;
    }

    /// @param liquidity collect fee when 0
    struct RemoveLiquidityParams {
        address baseToken;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint256 minBase;
        uint256 minQuote;
        uint256 deadline;
    }

    struct AddLiquidityResponse {
        uint256 base;
        uint256 quote;
        uint256 fee;
        uint256 liquidity;
    }

    struct RemoveLiquidityResponse {
        uint256 base;
        uint256 quote;
        uint256 fee;
    }

    /// @param oppositeAmountBound
    // B2Q + exact input, want more output quote as possible, so we set a lower bound of output quote
    // B2Q + exact output, want less input base as possible, so we set a upper bound of input base
    // Q2B + exact input, want more output base as possible, so we set a lower bound of output base
    // Q2B + exact output, want less input quote as possible, so we set a upper bound of input quote
    // when it's set to 0, it will disable slippage protection entirely regardless of exact input or output
    // when it's over or under the bound, it will be reverted
    /// @param sqrtPriceLimitX96
    // B2Q: the price cannot be less than this value after the swap
    // Q2B: the price cannot be greater than this value after the swap
    // it will fill the trade until it reaches the price limit but WON'T REVERT
    // when it's set to 0, it will disable price limit;
    // when it's 0 and exact output, the output amount is required to be identical to the param amount
    struct OpenPositionParams {
        address baseToken;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
        uint160 sqrtPriceLimitX96;
        bytes32 referralCode;
    }

    struct ClosePositionParams {
        address baseToken;
        uint160 sqrtPriceLimitX96;
        uint256 oppositeAmountBound;
        uint256 deadline;
        bytes32 referralCode;
    }

    struct CollectPendingFeeParams {
        address trader;
        address baseToken;
        int24 lowerTick;
        int24 upperTick;
    }

    /// @notice Emitted when open position with non-zero referral code
    /// @param referralCode The referral code by partners
    event ReferredPositionChanged(bytes32 indexed referralCode);

    /// @notice Emitted when taker position is being liquidated
    /// @param trader The trader who has been liquidated
    /// @param baseToken Virtual base token(ETH, BTC, etc...) address
    /// @param positionNotional The cost of position
    /// @param positionSize The size of position
    /// @param liquidationFee The fee of liquidate
    /// @param liquidator The address of liquidator
    event PositionLiquidated(
        address indexed trader,
        address indexed baseToken,
        uint256 positionNotional,
        uint256 positionSize,
        uint256 liquidationFee,
        address liquidator
    );

    /// @notice Emitted when maker's liquidity of a order changed
    /// @param maker The one who provide liquidity
    /// @param baseToken The address of virtual base token(ETH, BTC, etc...)
    /// @param quoteToken The address of virtual USD token
    /// @param lowerTick The lower tick of the position in which to add liquidity
    /// @param upperTick The upper tick of the position in which to add liquidity
    /// @param base The amount of base token added (> 0) / removed (< 0) as liquidity; fees not included
    /// @param quote The amount of quote token added ... (same as the above)
    /// @param liquidity The amount of liquidity unit added (> 0) / removed (< 0)
    /// @param quoteFee The amount of quote token the maker received as fees
    event LiquidityChanged(
        address indexed maker,
        address indexed baseToken,
        address indexed quoteToken,
        int24 lowerTick,
        int24 upperTick,
        int256 base,
        int256 quote,
        int128 liquidity,
        uint256 quoteFee
    );

    /// @notice Emitted when taker's position is being changed
    /// @param trader Trader address
    /// @param baseToken The address of virtual base token(ETH, BTC, etc...)
    /// @param exchangedPositionSize The actual amount swap to uniswapV3 pool
    /// @param exchangedPositionNotional The cost of position, include fee
    /// @param fee The fee of open/close position
    /// @param openNotional The cost of open/close position, < 0: long, > 0: short
    /// @param realizedPnl The realized Pnl after open/close position
    /// @param sqrtPriceAfterX96 The sqrt price after swap, in X96
    event PositionChanged(
        address indexed trader,
        address indexed baseToken,
        int256 exchangedPositionSize,
        int256 exchangedPositionNotional,
        uint256 fee,
        int256 openNotional,
        int256 realizedPnl,
        uint256 sqrtPriceAfterX96
    );

    /// @notice Emitted when taker close her position in closed market
    /// @param trader Trader address
    /// @param baseToken The address of virtual base token(ETH, BTC, etc...)
    /// @param closedPositionSize Trader's position size in closed market
    /// @param closedPositionNotional Trader's position notional in closed market, based on closed price
    /// @param openNotional The cost of open/close position, < 0: long, > 0: short
    /// @param realizedPnl The realized Pnl after close position
    /// @param closedPrice The close price of position
    event PositionClosed(
        address indexed trader,
        address indexed baseToken,
        int256 closedPositionSize,
        int256 closedPositionNotional,
        int256 openNotional,
        int256 realizedPnl,
        uint256 closedPrice
    );

    /// @notice Emitted when settling a trader's funding payment
    /// @param trader The address of trader
    /// @param baseToken The address of virtual base token(ETH, BTC, etc...)
    /// @param fundingPayment The fundingPayment of trader on baseToken market, > 0: payment, < 0 : receipt
    event FundingPaymentSettled(address indexed trader, address indexed baseToken, int256 fundingPayment);

    /// @notice Emitted when trusted forwarder address changed
    /// @dev TrustedForward is only used for metaTx
    /// @param forwarder The trusted forwarder address
    event TrustedForwarderChanged(address indexed forwarder);

    /// @notice Maker can call `addLiquidity` to provide liquidity on Uniswap V3 pool
    /// @dev Tx will fail if adding `base == 0 && quote == 0` / `liquidity == 0`
    /// @dev - `AddLiquidityParams.useTakerBalance` is only accept `false` now
    /// @param params AddLiquidityParams struct
    /// @return response AddLiquidityResponse struct
    function addLiquidity(AddLiquidityParams calldata params) external returns (AddLiquidityResponse memory response);

    /// @notice Maker can call `removeLiquidity` to remove liquidity
    /// @dev remove liquidity will transfer maker impermanent position to taker position,
    /// if `liquidity` of RemoveLiquidityParams struct is zero, the action will collect fee from
    /// pool to maker
    /// @param params RemoveLiquidityParams struct
    /// @return response RemoveLiquidityResponse struct
    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        returns (RemoveLiquidityResponse memory response);

    /// @notice Settle all markets fundingPayment to owedRealized Pnl
    /// @param trader The address of trader
    function settleAllFunding(address trader) external;

    /// @notice Trader can call `openPosition` to long/short on baseToken market
    /// @dev - `OpenPositionParams.oppositeAmountBound`
    ///     - B2Q + exact input, want more output quote as possible, so we set a lower bound of output quote
    ///     - B2Q + exact output, want less input base as possible, so we set a upper bound of input base
    ///     - Q2B + exact input, want more output base as possible, so we set a lower bound of output base
    ///     - Q2B + exact output, want less input quote as possible, so we set a upper bound of input quote
    ///     > when it's set to 0, it will disable slippage protection entirely regardless of exact input or output
    ///     > when it's over or under the bound, it will be reverted
    /// @dev - `OpenPositionParams.sqrtPriceLimitX96`
    ///     - B2Q: the price cannot be less than this value after the swap
    ///     - Q2B: the price cannot be greater than this value after the swap
    ///     > it will fill the trade until it reaches the price limit but WON'T REVERT
    ///     > when it's set to 0, it will disable price limit;
    ///     > when it's 0 and exact output, the output amount is required to be identical to the param amount
    /// @param params OpenPositionParams struct
    /// @return base The amount of baseToken the taker got or spent
    /// @return quote The amount of quoteToken the taker got or spent
    function openPosition(OpenPositionParams memory params) external returns (uint256 base, uint256 quote);

    /// @notice Close trader's position
    /// @param params ClosePositionParams struct
    /// @return base The amount of baseToken the taker got or spent
    /// @return quote The amount of quoteToken the taker got or spent
    function closePosition(ClosePositionParams calldata params) external returns (uint256 base, uint256 quote);

    /// @notice If trader is underwater, any one can call `liquidate` to liquidate this trader
    /// @dev If trader has open orders, need to call `cancelAllExcessOrders` first
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @param oppositeAmountBound please check OpenPositionParams
    /// @return base The amount of baseToken the taker got or spent
    /// @return quote The amount of quoteToken the taker got or spent
    /// @return isPartialClose when it's over price limit return true and only liquidate 25% of the position
    function liquidate(
        address trader,
        address baseToken,
        uint256 oppositeAmountBound
    )
        external
        returns (
            uint256 base,
            uint256 quote,
            bool isPartialClose
        );

    /// @notice If trader is underwater, any one can call `liquidate` to liquidate this trader
    /// @dev This function will be deprecated in the future, recommend to use the function `liquidate()` above
    /// @dev If trader has open orders, need to call `cancelAllExcessOrders` first
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    function liquidate(address trader, address baseToken) external;

    /// @notice Cancel excess order of a maker
    /// @dev Order id can get from `OrderBook.getOpenOrderIds`
    /// @param maker The address of Maker
    /// @param baseToken The address of baseToken
    /// @param orderIds The id of the order
    function cancelExcessOrders(
        address maker,
        address baseToken,
        bytes32[] calldata orderIds
    ) external;

    /// @notice Cancel all excess orders of a maker if the maker is underwater
    /// @dev This function won't fail if the maker has no order but fails when maker is not underwater
    /// @param maker The address of maker
    /// @param baseToken The address of baseToken
    function cancelAllExcessOrders(address maker, address baseToken) external;

    /// @notice Close all positions of a trader in the closed market
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return base The amount of base token that is closed
    /// @return quote The amount of quote token that is closed
    function quitMarket(address trader, address baseToken) external returns (uint256 base, uint256 quote);

    /// @notice Get account value of trader
    /// @dev accountValue = totalCollateralValue + totalUnrealizedPnl, in 18 decimals
    /// @param trader The address of trader
    /// @return accountValue The account value of trader
    function getAccountValue(address trader) external view returns (int256 accountValue);

    /// @notice Get QuoteToken address
    /// @return quoteToken The quote token address
    function getQuoteToken() external view returns (address quoteToken);

    /// @notice Get UniswapV3Factory address
    /// @return factory UniswapV3Factory address
    function getUniswapV3Factory() external view returns (address factory);

    /// @notice Get ClearingHouseConfig address
    /// @return clearingHouseConfig ClearingHouseConfig address
    function getClearingHouseConfig() external view returns (address clearingHouseConfig);

    /// @notice Get `Vault` address
    /// @return vault `Vault` address
    function getVault() external view returns (address vault);

    /// @notice Get `Exchange` address
    /// @return exchange `Exchange` address
    function getExchange() external view returns (address exchange);

    /// @notice Get `OrderBook` address
    /// @return orderBook `OrderBook` address
    function getOrderBook() external view returns (address orderBook);

    /// @notice Get AccountBalance address
    /// @return accountBalance `AccountBalance` address
    function getAccountBalance() external view returns (address accountBalance);

    /// @notice Get `InsuranceFund` address
    /// @return insuranceFund `InsuranceFund` address
    function getInsuranceFund() external view returns (address insuranceFund);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

interface IClearingHouseConfig {
    /// @return maxMarketsPerAccount Max value of total markets per account
    function getMaxMarketsPerAccount() external view returns (uint8 maxMarketsPerAccount);

    /// @return imRatio Initial margin ratio
    function getImRatio() external view returns (uint24 imRatio);

    /// @return mmRatio Maintenance margin requirement ratio
    function getMmRatio() external view returns (uint24 mmRatio);

    /// @return liquidationPenaltyRatio Liquidation penalty ratio
    function getLiquidationPenaltyRatio() external view returns (uint24 liquidationPenaltyRatio);

    /// @return partialCloseRatio Partial close ratio
    function getPartialCloseRatio() external view returns (uint24 partialCloseRatio);

    /// @return twapInterval TwapInterval for funding and prices (mark & index) calculations
    function getTwapInterval() external view returns (uint32 twapInterval);

    /// @return settlementTokenBalanceCap Max value of settlement token balance
    function getSettlementTokenBalanceCap() external view returns (uint256 settlementTokenBalanceCap);

    /// @return maxFundingRate Max value of funding rate
    function getMaxFundingRate() external view returns (uint24 maxFundingRate);

    /// @return isBackstopLiquidityProvider is backstop liquidity provider
    function isBackstopLiquidityProvider(address account) external view returns (bool isBackstopLiquidityProvider);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

struct AccountMarketInfo {
    int256 takerPositionSize;
    int256 takerOpenNotional;
    int256 lastTwPremiumGrowthGlobalX96;
}

interface IAccountBalance {
    /// @param vault The address of the vault contract
    event VaultChanged(address indexed vault);

    /// @dev Emit whenever a trader's `owedRealizedPnl` is updated
    /// @param trader The address of the trader
    /// @param amount The amount changed
    event PnlRealized(address indexed trader, int256 amount);

    /// @notice Modify trader account balance
    /// @dev Only used by `ClearingHouse` contract
    /// @param trader The address of the trader
    /// @param baseToken The address of the baseToken
    /// @param base Modified amount of base
    /// @param quote Modified amount of quote
    /// @return takerPositionSize Taker position size after modified
    /// @return takerOpenNotional Taker open notional after modified
    function modifyTakerBalance(
        address trader,
        address baseToken,
        int256 base,
        int256 quote
    ) external returns (int256 takerPositionSize, int256 takerOpenNotional);

    /// @notice Modify trader owedRealizedPnl
    /// @dev Only used by `ClearingHouse` contract
    /// @param trader The address of the trader
    /// @param amount Modified amount of owedRealizedPnl
    function modifyOwedRealizedPnl(address trader, int256 amount) external;

    /// @notice Settle owedRealizedPnl
    /// @dev Only used by `Vault.withdraw()`
    /// @param trader The address of the trader
    /// @return pnl Settled owedRealizedPnl
    function settleOwedRealizedPnl(address trader)
        external
        returns (int256 pnl);

    /// @notice Modify trader owedRealizedPnl
    /// @dev Only used by `ClearingHouse` contract
    /// @param trader The address of the trader
    /// @param baseToken The address of the baseToken
    /// @param amount Settled quote amount
    function settleQuoteToOwedRealizedPnl(
        address trader,
        address baseToken,
        int256 amount
    ) external;

    /// @notice Settle account balance and deregister base token
    /// @dev Only used by `ClearingHouse` contract
    /// @param maker The address of the maker
    /// @param baseToken The address of the baseToken
    /// @param realizedPnl Amount of pnl realized
    /// @param fee Amount of fee collected from pool
    function settleBalanceAndDeregister(
        address maker,
        address baseToken,
        int256 takerBase,
        int256 takerQuote,
        int256 realizedPnl,
        int256 fee
    ) external;

    /// @notice Every time a trader's position value is checked, the base token list of this trader will be traversed;
    /// thus, this list should be kept as short as possible
    /// @dev Only used by `ClearingHouse` contract
    /// @param trader The address of the trader
    /// @param baseToken The address of the trader's base token
    function registerBaseToken(address trader, address baseToken) external;

    /// @notice Deregister baseToken from trader accountInfo
    /// @dev Only used by `ClearingHouse` contract, this function is expensive, due to for loop
    /// @param trader The address of the trader
    /// @param baseToken The address of the trader's base token
    function deregisterBaseToken(address trader, address baseToken) external;

    /// @notice Update trader Twap premium info
    /// @dev Only used by `ClearingHouse` contract
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @param lastTwPremiumGrowthGlobalX96 The last Twap Premium
    function updateTwPremiumGrowthGlobal(
        address trader,
        address baseToken,
        int256 lastTwPremiumGrowthGlobalX96
    ) external;

    /// @notice Settle trader's PnL in closed market
    /// @dev Only used by `ClearingHouse`
    /// @param trader The address of the trader
    /// @param baseToken The address of the trader's base token
    /// @return positionNotional Taker's position notional settled with closed price
    /// @return openNotional Taker's open notional
    /// @return realizedPnl Settled realized pnl
    /// @return closedPrice The closed price of the closed market
    function settlePositionInClosedMarket(address trader, address baseToken)
        external
        returns (
            int256 positionNotional,
            int256 openNotional,
            int256 realizedPnl,
            uint256 closedPrice
        );

    /// @notice Get `ClearingHouseConfig` address
    /// @return clearingHouseConfig The address of ClearingHouseConfig
    function getClearingHouseConfig()
        external
        view
        returns (address clearingHouseConfig);

    /// @notice Get `OrderBook` address
    /// @return orderBook The address of OrderBook
    function getOrderBook() external view returns (address orderBook);

    /// @notice Get `Vault` address
    /// @return vault The address of Vault
    function getVault() external view returns (address vault);

    /// @notice Get trader registered baseTokens
    /// @param trader The address of trader
    /// @return baseTokens The array of baseToken address
    function getBaseTokens(address trader)
        external
        view
        returns (address[] memory baseTokens);

    /// @notice Get trader account info
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return traderAccountInfo The baseToken account info of trader
    function getAccountInfo(address trader, address baseToken)
        external
        view
        returns (AccountMarketInfo memory traderAccountInfo);

    /// @notice Get taker cost of trader's baseToken
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return openNotional The taker cost of trader's baseToken
    function getTakerOpenNotional(address trader, address baseToken)
        external
        view
        returns (int256 openNotional);

    /// @notice Get total cost of trader's baseToken
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return totalOpenNotional the amount of quote token paid for a position when opening
    function getTotalOpenNotional(address trader, address baseToken)
        external
        view
        returns (int256 totalOpenNotional);

    /// @notice Get total debt value of trader
    /// @param trader The address of trader
    /// @dev Total debt value will relate to `Vault.getFreeCollateral()`
    /// @return totalDebtValue The debt value of trader
    function getTotalDebtValue(address trader)
        external
        view
        returns (uint256 totalDebtValue);

    /// @notice Get margin requirement to check whether trader will be able to liquidate
    /// @dev This is different from `Vault._getTotalMarginRequirement()`, which is for freeCollateral calculation
    /// @param trader The address of trader
    /// @return marginRequirementForLiquidation It is compared with `ClearingHouse.getAccountValue` which is also an int
    function getMarginRequirementForLiquidation(address trader)
        external
        view
        returns (int256 marginRequirementForLiquidation);

    /// @notice Get owedRealizedPnl, unrealizedPnl and pending fee
    /// @param trader The address of trader
    /// @return owedRealizedPnl the pnl realized already but stored temporarily in AccountBalance
    /// @return unrealizedPnl the pnl not yet realized
    /// @return pendingFee the pending fee of maker earned
    function getPnlAndPendingFee(address trader)
        external
        view
        returns (
            int256 owedRealizedPnl,
            int256 unrealizedPnl,
            uint256 pendingFee
        );

    /// @notice Check trader has open order in open/closed market.
    /// @param trader The address of trader
    /// @return hasOrder True of false
    function hasOrder(address trader) external view returns (bool hasOrder);

    /// @notice Get trader base amount
    /// @dev `base amount = takerPositionSize - orderBaseDebt`
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return baseAmount The base amount of trader's baseToken market
    function getBase(address trader, address baseToken)
        external
        view
        returns (int256 baseAmount);

    /// @notice Get trader quote amount
    /// @dev `quote amount = takerOpenNotional - orderQuoteDebt`
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return quoteAmount The quote amount of trader's baseToken market
    function getQuote(address trader, address baseToken)
        external
        view
        returns (int256 quoteAmount);

    /// @notice Get taker position size of trader's baseToken market
    /// @dev This will only has taker position, can get maker impermanent position through `getTotalPositionSize`
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return takerPositionSize The taker position size of trader's baseToken market
    function getTakerPositionSize(address trader, address baseToken)
        external
        view
        returns (int256 takerPositionSize);

    /// @notice Get total position size of trader's baseToken market
    /// @dev `total position size = taker position size + maker impermanent position size`
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return totalPositionSize The total position size of trader's baseToken market
    function getTotalPositionSize(address trader, address baseToken)
        external
        view
        returns (int256 totalPositionSize);

    /// @notice Get total position value of trader's baseToken market
    /// @dev A negative returned value is only be used when calculating pnl,
    /// @dev we use `15 mins` twap to calc position value
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return totalPositionValue Total position value of trader's baseToken market
    function getTotalPositionValue(address trader, address baseToken)
        external
        view
        returns (int256 totalPositionValue);

    /// @notice Get all market position abs value of trader
    /// @param trader The address of trader
    /// @return totalAbsPositionValue Sum up positions value of every market
    function getTotalAbsPositionValue(address trader)
        external
        view
        returns (uint256 totalAbsPositionValue);
}