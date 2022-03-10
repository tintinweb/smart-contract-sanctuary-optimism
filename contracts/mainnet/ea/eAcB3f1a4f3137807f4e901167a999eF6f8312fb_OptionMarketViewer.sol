//SPDX-License-Identifier:ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../interfaces/IOptionMarket.sol";
import "../interfaces/IBlackScholes.sol";
import "../synthetix/SafeDecimalMath.sol";
import "../interfaces/IOptionToken.sol";
import "../interfaces/IOptionGreekCache.sol";

/**
 * @title OptionMarketViewer
 * @author Lyra
 * @dev Provides helpful functions to allow the dapp to operate more smoothly; logic in getPremiumForTrade is vital to
 * ensuring accurate prices are provided to the user.
 */
contract OptionMarketViewer {
  using SafeDecimalMath for uint;

  struct BoardView {
    uint boardId;
    uint expiry;
  }

  // Detailed view of an OptionListing - only for output
  struct ListingView {
    uint listingId;
    uint boardId;
    uint strike;
    uint expiry;
    uint iv;
    uint skew;
    uint callPrice;
    uint putPrice;
    int callDelta;
    int putDelta;
    uint longCall;
    uint shortCall;
    uint longPut;
    uint shortPut;
  }

  // Detailed view of a user's holdings - only for output
  struct OwnedOptionView {
    uint listingId;
    address owner;
    uint strike;
    uint expiry;
    int callAmount;
    int putAmount;
    uint callPrice;
    uint putPrice;
  }

  struct TradePremiumView {
    uint listingId;
    uint premium;
    uint basePrice;
    uint vegaUtilFee;
    uint optionPriceFee;
    uint spotPriceFee;
    uint newIv;
  }

  ILyraGlobals public globals;
  IOptionMarket public optionMarket;
  IOptionMarketPricer public optionMarketPricer;
  IOptionGreekCache public greekCache;
  IOptionToken public optionToken;
  ILiquidityPool public liquidityPool;
  IBlackScholes public blackScholes;

  bool initialized = false;

  constructor() {}

  /**
   * @dev Initializes the contract
   * @param _globals LyraGlobals contract address
   * @param _optionMarket OptionMarket contract address
   * @param _optionMarketPricer OptionMarketPricer contract address
   * @param _greekCache OptionGreekCache contract address
   * @param _optionToken OptionToken contract address
   * @param _liquidityPool LiquidityPool contract address
   * @param _blackScholes BlackScholes contract address
   */
  function init(
    ILyraGlobals _globals,
    IOptionMarket _optionMarket,
    IOptionMarketPricer _optionMarketPricer,
    IOptionGreekCache _greekCache,
    IOptionToken _optionToken,
    ILiquidityPool _liquidityPool,
    IBlackScholes _blackScholes
  ) external {
    require(!initialized, "Contract already initialized");

    globals = _globals;
    optionMarket = _optionMarket;
    optionMarketPricer = _optionMarketPricer;
    greekCache = _greekCache;
    optionToken = _optionToken;
    liquidityPool = _liquidityPool;
    blackScholes = _blackScholes;

    initialized = true;
  }

  /**
   * @dev Gets the OptionBoard struct from the OptionMarket
   */
  function getBoard(uint boardId) public view returns (IOptionMarket.OptionBoard memory) {
    (uint id, uint expiry, uint iv, ) = optionMarket.optionBoards(boardId);
    uint[] memory listings = optionMarket.getBoardListings(boardId);
    return IOptionMarket.OptionBoard(id, expiry, iv, false, listings);
  }

  /**
   * @dev Gets the OptionListing struct from the OptionMarket
   */
  function getListing(uint listingId) public view returns (IOptionMarket.OptionListing memory) {
    (uint id, uint strike, uint skew, uint longCall, uint shortCall, uint longPut, uint shortPut, uint boardId) =
      optionMarket.optionListings(listingId);
    return IOptionMarket.OptionListing(id, strike, skew, longCall, shortCall, longPut, shortPut, boardId);
  }

  /**
   * @dev Gets the OptionListingCache struct from the OptionGreekCache
   */
  function getListingCache(uint listingId) internal view returns (IOptionGreekCache.OptionListingCache memory) {
    (
      uint id,
      uint strike,
      uint skew,
      uint boardId,
      int callDelta,
      int putDelta,
      uint vega,
      int callExposure,
      int putExposure,
      uint updatedAt,
      uint updatedAtPrice
    ) = greekCache.listingCaches(listingId);
    return
      IOptionGreekCache.OptionListingCache(
        id,
        strike,
        skew,
        boardId,
        callDelta,
        putDelta,
        vega,
        callExposure,
        putExposure,
        updatedAt,
        updatedAtPrice
      );
  }

  /**
   * @dev Gets the GlobalCache struct from the OptionGreekCache
   */
  function getGlobalCache() internal view returns (IOptionGreekCache.GlobalCache memory) {
    (
      int netDelta,
      int netStdVega,
      uint minUpdatedAt,
      uint minUpdatedAtPrice,
      uint maxUpdatedAtPrice,
      uint minExpiryTimestamp
    ) = greekCache.globalCache();
    return
      IOptionGreekCache.GlobalCache(
        netDelta,
        netStdVega,
        minUpdatedAt,
        minUpdatedAtPrice,
        maxUpdatedAtPrice,
        minExpiryTimestamp
      );
  }

  /**
   * @dev Gets the array of liveBoards with details from the OptionMarket
   */
  function getLiveBoards() external view returns (BoardView[] memory boards) {
    uint[] memory liveBoards = optionMarket.getLiveBoards();
    boards = new BoardView[](liveBoards.length);
    for (uint i = 0; i < liveBoards.length; i++) {
      IOptionMarket.OptionBoard memory board = getBoard(liveBoards[i]);
      boards[i] = BoardView(board.id, board.expiry);
    }
  }

  /**
   * @dev Gets detailed ListingViews for all listings on a board
   */
  function getListingsForBoard(uint boardId) external view returns (ListingView[] memory boardListings) {
    IOptionMarket.OptionBoard memory board = getBoard(boardId);
    ILyraGlobals.GreekCacheGlobals memory greekCacheGlobals = globals.getGreekCacheGlobals(address(optionMarket));

    boardListings = new ListingView[](board.listingIds.length);

    for (uint i = 0; i < board.listingIds.length; i++) {
      IOptionMarket.OptionListing memory listing = getListing(board.listingIds[i]);

      uint vol = board.iv.multiplyDecimal(listing.skew);

      IBlackScholes.PricesDeltaStdVega memory pricesDeltaStdVega =
        blackScholes.pricesDeltaStdVega(
          timeToMaturitySeconds(board.expiry),
          vol,
          greekCacheGlobals.spotPrice,
          listing.strike,
          greekCacheGlobals.rateAndCarry
        );

      boardListings[i] = ListingView(
        listing.id,
        boardId,
        listing.strike,
        board.expiry,
        board.iv,
        listing.skew,
        pricesDeltaStdVega.callPrice,
        pricesDeltaStdVega.putPrice,
        pricesDeltaStdVega.callDelta,
        pricesDeltaStdVega.putDelta,
        listing.longCall,
        listing.shortCall,
        listing.longPut,
        listing.shortPut
      );
    }
  }

  /**
   * @dev Gets detailed ListingView along with all of a user's balances for a given listing
   */
  function getListingViewAndBalance(uint listingId, address user)
    external
    view
    returns (
      ListingView memory listingView,
      uint longCallAmt,
      uint longPutAmt,
      uint shortCallAmt,
      uint shortPutAmt
    )
  {
    listingView = getListingView(listingId);
    longCallAmt = optionToken.balanceOf(user, listingId + uint(IOptionMarket.TradeType.LONG_CALL));
    longPutAmt = optionToken.balanceOf(user, listingId + uint(IOptionMarket.TradeType.LONG_PUT));
    shortCallAmt = optionToken.balanceOf(user, listingId + uint(IOptionMarket.TradeType.SHORT_CALL));
    shortPutAmt = optionToken.balanceOf(user, listingId + uint(IOptionMarket.TradeType.SHORT_PUT));
  }

  /**
   * @dev Gets a detailed ListingView for a given listing
   */
  function getListingView(uint listingId) public view returns (ListingView memory listingView) {
    IOptionMarket.OptionListing memory listing = getListing(listingId);
    IOptionMarket.OptionBoard memory board = getBoard(listing.boardId);
    ILyraGlobals.GreekCacheGlobals memory greekCacheGlobals = globals.getGreekCacheGlobals(address(optionMarket));

    uint vol = board.iv.multiplyDecimal(listing.skew);

    IBlackScholes.PricesDeltaStdVega memory pricesDeltaStdVega =
      blackScholes.pricesDeltaStdVega(
        timeToMaturitySeconds(board.expiry),
        vol,
        greekCacheGlobals.spotPrice,
        listing.strike,
        greekCacheGlobals.rateAndCarry
      );

    return
      ListingView(
        listing.id,
        listing.boardId,
        listing.strike,
        board.expiry,
        board.iv,
        listing.skew,
        pricesDeltaStdVega.callPrice,
        pricesDeltaStdVega.putPrice,
        pricesDeltaStdVega.callDelta,
        pricesDeltaStdVega.putDelta,
        listing.longCall,
        listing.shortCall,
        listing.longPut,
        listing.shortPut
      );
  }

  /**
   * @dev Gets the premium and new iv value after opening
   */
  function getPremiumForOpen(
    uint _listingId,
    IOptionMarket.TradeType tradeType,
    uint amount
  ) external view returns (TradePremiumView memory) {
    bool isBuy = tradeType == IOptionMarket.TradeType.LONG_CALL || tradeType == IOptionMarket.TradeType.LONG_PUT;
    return getPremiumForTrade(_listingId, tradeType, isBuy, amount);
  }

  /**
   * @dev Gets the premium and new iv value after closing
   */
  function getPremiumForClose(
    uint _listingId,
    IOptionMarket.TradeType tradeType,
    uint amount
  ) external view returns (TradePremiumView memory) {
    bool isBuy = !(tradeType == IOptionMarket.TradeType.LONG_CALL || tradeType == IOptionMarket.TradeType.LONG_PUT);
    return getPremiumForTrade(_listingId, tradeType, isBuy, amount);
  }

  /**
   * @dev Gets the premium with fee breakdown and new iv value for a given trade
   */
  function getPremiumForTrade(
    uint _listingId,
    IOptionMarket.TradeType tradeType,
    bool isBuy,
    uint amount
  ) public view returns (TradePremiumView memory) {
    ILyraGlobals.PricingGlobals memory pricingGlobals = globals.getPricingGlobals(address(optionMarket));
    ILyraGlobals.ExchangeGlobals memory exchangeGlobals =
      globals.getExchangeGlobals(address(optionMarket), ILyraGlobals.ExchangeType.ALL);

    IOptionMarket.OptionListing memory listing = getListing(_listingId);
    IOptionMarket.OptionBoard memory board = getBoard(listing.boardId);
    IOptionMarket.Trade memory trade =
      IOptionMarket.Trade({
        isBuy: isBuy,
        amount: amount,
        vol: board.iv.multiplyDecimal(listing.skew),
        expiry: board.expiry,
        liquidity: liquidityPool.getLiquidity(pricingGlobals.spotPrice, exchangeGlobals.short)
      });
    bool isCall = tradeType == IOptionMarket.TradeType.LONG_CALL || tradeType == IOptionMarket.TradeType.SHORT_CALL;
    return _getPremiumForTrade(listing, board, trade, pricingGlobals, isCall);
  }

  /**
   * @dev Gets the premium with fee breakdown and new iv value after opening for all listings in a board
   */
  function getOpenPremiumsForBoard(
    uint _boardId,
    IOptionMarket.TradeType tradeType,
    uint amount
  ) external view returns (TradePremiumView[] memory) {
    bool isBuy = tradeType == IOptionMarket.TradeType.LONG_CALL || tradeType == IOptionMarket.TradeType.LONG_PUT;
    return getPremiumsForBoard(_boardId, tradeType, isBuy, amount);
  }

  /**
   * @dev Gets the premium with fee breakdown and new iv value after closing for all listings in a board
   */
  function getClosePremiumsForBoard(
    uint _boardId,
    IOptionMarket.TradeType tradeType,
    uint amount
  ) external view returns (TradePremiumView[] memory) {
    bool isBuy = !(tradeType == IOptionMarket.TradeType.LONG_CALL || tradeType == IOptionMarket.TradeType.LONG_PUT);
    return getPremiumsForBoard(_boardId, tradeType, isBuy, amount);
  }

  /**
   * @dev Gets the premium with fee breakdown and new iv value for all listings in a board
   */
  function getPremiumsForBoard(
    uint _boardId,
    IOptionMarket.TradeType tradeType,
    bool isBuy,
    uint amount
  ) public view returns (TradePremiumView[] memory tradePremiums) {
    IOptionMarket.OptionBoard memory board = getBoard(_boardId);
    ILyraGlobals.PricingGlobals memory pricingGlobals = globals.getPricingGlobals(address(optionMarket));
    ILyraGlobals.ExchangeGlobals memory exchangeGlobals =
      globals.getExchangeGlobals(address(optionMarket), ILyraGlobals.ExchangeType.ALL);

    tradePremiums = new TradePremiumView[](board.listingIds.length);
    for (uint i = 0; i < board.listingIds.length; i++) {
      IOptionMarket.OptionListing memory listing = getListing(board.listingIds[i]);
      IOptionMarket.Trade memory trade =
        IOptionMarket.Trade({
          isBuy: isBuy,
          amount: amount,
          vol: board.iv.multiplyDecimal(listing.skew),
          expiry: board.expiry,
          liquidity: liquidityPool.getLiquidity(pricingGlobals.spotPrice, exchangeGlobals.short)
        });
      bool isCall = tradeType == IOptionMarket.TradeType.LONG_CALL || tradeType == IOptionMarket.TradeType.SHORT_CALL;
      tradePremiums[i] = _getPremiumForTrade(listing, board, trade, pricingGlobals, isCall);
    }
  }

  /**
   * @dev Gets the premium and new iv value for a given trade
   */
  function _getPremiumForTrade(
    IOptionMarket.OptionListing memory listing,
    IOptionMarket.OptionBoard memory board,
    IOptionMarket.Trade memory trade,
    ILyraGlobals.PricingGlobals memory pricingGlobals,
    bool isCall
  ) public view returns (TradePremiumView memory premium) {
    // Apply the skew as implemented in OptionMarket

    (uint newIv, uint newSkew) = optionMarketPricer.ivImpactForTrade(listing, trade, pricingGlobals, board.iv);
    trade.vol = newIv.multiplyDecimal(newSkew);

    int newCallExposure =
      int(listing.longCall) -
        int(listing.shortCall) +
        (isCall ? (trade.isBuy ? int(trade.amount) : -int(trade.amount)) : 0);
    int newPutExposure =
      int(listing.longPut) -
        int(listing.shortPut) +
        (isCall ? 0 : (trade.isBuy ? int(trade.amount) : -int(trade.amount)));

    IOptionMarketPricer.Pricing memory pricing =
      _getPricingForTrade(pricingGlobals, trade, listing.id, newCallExposure, newPutExposure, isCall);

    uint vegaUtil = optionMarketPricer.getVegaUtil(trade, pricing, pricingGlobals);

    premium.listingId = listing.id;
    premium.premium = optionMarketPricer.getPremium(trade, pricing, pricingGlobals);
    premium.newIv = trade.vol;
    premium.optionPriceFee = pricingGlobals
      .optionPriceFeeCoefficient
      .multiplyDecimal(pricing.optionPrice)
      .multiplyDecimal(trade.amount);
    premium.spotPriceFee = pricingGlobals
      .spotPriceFeeCoefficient
      .multiplyDecimal(pricingGlobals.spotPrice)
      .multiplyDecimal(trade.amount);
    premium.vegaUtilFee = pricingGlobals.vegaFeeCoefficient.multiplyDecimal(vegaUtil).multiplyDecimal(trade.amount);
    premium.basePrice = pricing.optionPrice.multiplyDecimal(trade.amount);
  }

  function _getPricingForTrade(
    ILyraGlobals.PricingGlobals memory pricingGlobals,
    IOptionMarket.Trade memory trade,
    uint _listingId,
    int newCallExposure,
    int newPutExposure,
    bool isCall
  ) internal view returns (IOptionMarketPricer.Pricing memory pricing) {
    IOptionGreekCache.OptionListingCache memory listingCache = getListingCache(_listingId);
    IOptionGreekCache.GlobalCache memory globalCache = getGlobalCache();

    IBlackScholes.PricesDeltaStdVega memory pricesDeltaStdVega =
      blackScholes.pricesDeltaStdVega(
        timeToMaturitySeconds(trade.expiry),
        trade.vol,
        pricingGlobals.spotPrice,
        listingCache.strike,
        pricingGlobals.rateAndCarry
      );

    int preTradeAmmNetStdVega = -globalCache.netStdVega;

    globalCache.netStdVega +=
      (int(listingCache.stdVega) *
        ((newCallExposure - listingCache.callExposure) + (newPutExposure - listingCache.putExposure))) /
      1e18;

    listingCache.callExposure = newCallExposure;
    listingCache.putExposure = newPutExposure;

    int netStdVegaDiff =
      (((listingCache.callExposure + listingCache.putExposure) *
        (int(pricesDeltaStdVega.stdVega) - int(listingCache.stdVega))) / 1e18);

    pricing.optionPrice = isCall ? pricesDeltaStdVega.callPrice : pricesDeltaStdVega.putPrice;
    pricing.postTradeAmmNetStdVega = -(globalCache.netStdVega + netStdVegaDiff);
    pricing.preTradeAmmNetStdVega = preTradeAmmNetStdVega;
    return pricing;
  }

  /**
   * @dev Gets seconds to expiry.
   */
  function timeToMaturitySeconds(uint expiry) internal view returns (uint timeToMaturity) {
    if (expiry > block.timestamp) {
      timeToMaturity = expiry - block.timestamp;
    } else {
      timeToMaturity = 0;
    }
  }
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./ILyraGlobals.sol";
import "./ILiquidityPool.sol";

interface IOptionMarket {
  struct OptionListing {
    uint id;
    uint strike;
    uint skew;
    uint longCall;
    uint shortCall;
    uint longPut;
    uint shortPut;
    uint boardId;
  }

  struct OptionBoard {
    uint id;
    uint expiry;
    uint iv;
    bool frozen;
    uint[] listingIds;
  }

  struct Trade {
    bool isBuy;
    uint amount;
    uint vol;
    uint expiry;
    ILiquidityPool.Liquidity liquidity;
  }

  enum TradeType {LONG_CALL, SHORT_CALL, LONG_PUT, SHORT_PUT}

  enum Error {
    TransferOwnerToZero,
    InvalidBoardId,
    InvalidBoardIdOrNotFrozen,
    InvalidListingIdOrNotFrozen,
    StrikeSkewLengthMismatch,
    BoardMaxExpiryReached,
    CannotStartNewRoundWhenBoardsExist,
    ZeroAmountOrInvalidTradeType,
    BoardFrozenOrTradingCutoffReached,
    QuoteTransferFailed,
    BaseTransferFailed,
    BoardNotExpired,
    BoardAlreadyLiquidated,
    OnlyOwner,
    Last
  }

  function maxExpiryTimestamp() external view returns (uint);

  function optionBoards(uint)
    external
    view
    returns (
      uint id,
      uint expiry,
      uint iv,
      bool frozen
    );

  function optionListings(uint)
    external
    view
    returns (
      uint id,
      uint strike,
      uint skew,
      uint longCall,
      uint shortCall,
      uint longPut,
      uint shortPut,
      uint boardId
    );

  function boardToPriceAtExpiry(uint) external view returns (uint);

  function listingToBaseReturnedRatio(uint) external view returns (uint);

  function transferOwnership(address newOwner) external;

  function setBoardFrozen(uint boardId, bool frozen) external;

  function setBoardBaseIv(uint boardId, uint baseIv) external;

  function setListingSkew(uint listingId, uint skew) external;

  function createOptionBoard(
    uint expiry,
    uint baseIV,
    uint[] memory strikes,
    uint[] memory skews
  ) external returns (uint);

  function addListingToBoard(
    uint boardId,
    uint strike,
    uint skew
  ) external;

  function getLiveBoards() external view returns (uint[] memory _liveBoards);

  function getBoardListings(uint boardId) external view returns (uint[] memory);

  function openPosition(
    uint _listingId,
    TradeType tradeType,
    uint amount
  ) external returns (uint totalCost);

  function closePosition(
    uint _listingId,
    TradeType tradeType,
    uint amount
  ) external returns (uint totalCost);

  function liquidateExpiredBoard(uint boardId) external;

  function settleOptions(uint listingId, TradeType tradeType) external;
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

interface IBlackScholes {
  struct PricesDeltaStdVega {
    uint callPrice;
    uint putPrice;
    int callDelta;
    int putDelta;
    uint stdVega;
  }

  function abs(int x) external pure returns (uint);

  function exp(uint x) external pure returns (uint);

  function exp(int x) external pure returns (uint);

  function sqrt(uint x) external pure returns (uint y);

  function optionPrices(
    uint timeToExpirySec,
    uint volatilityDecimal,
    uint spotDecimal,
    uint strikeDecimal,
    int rateDecimal
  ) external pure returns (uint call, uint put);

  function pricesDeltaStdVega(
    uint timeToExpirySec,
    uint volatilityDecimal,
    uint spotDecimal,
    uint strikeDecimal,
    int rateDecimal
  ) external pure returns (PricesDeltaStdVega memory);
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

pragma solidity ^0.7.6;

// Libraries
import "@openzeppelin/contracts/math/SafeMath.sol";

// https://docs.synthetix.io/contracts/source/libraries/SafeDecimalMath/
library SafeDecimalMath {
  using SafeMath for uint;

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
    return x.mul(y) / UNIT;
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
    uint quotientTimesTen = x.mul(y) / (precisionUnit / 10);

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
    return x.mul(UNIT).div(y);
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
    uint resultTimesTen = x.mul(precisionUnit * 10).div(y);

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
    return i.mul(UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR);
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

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155MetadataURI.sol";

interface IOptionToken is IERC1155, IERC1155MetadataURI {
  function setURI(string memory newURI) external;

  function mint(
    address account,
    uint id,
    uint amount
  ) external;

  function burn(
    address account,
    uint id,
    uint amount
  ) external;
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./ILyraGlobals.sol";
import "./IOptionMarketPricer.sol";

interface IOptionGreekCache {
  struct OptionListingCache {
    uint id;
    uint strike;
    uint skew;
    uint boardId;
    int callDelta;
    int putDelta;
    uint stdVega;
    int callExposure; // long - short
    int putExposure; // long - short
    uint updatedAt;
    uint updatedAtPrice;
  }

  struct OptionBoardCache {
    uint id;
    uint expiry;
    uint iv;
    uint[] listings;
    uint minUpdatedAt; // This should be the minimum value of all the listings
    uint minUpdatedAtPrice;
    uint maxUpdatedAtPrice;
    int netDelta;
    int netStdVega;
  }

  struct GlobalCache {
    int netDelta;
    int netStdVega;
    uint minUpdatedAt; // This should be the minimum value of all the listings
    uint minUpdatedAtPrice;
    uint maxUpdatedAtPrice;
    uint minExpiryTimestamp;
  }

  function MAX_LISTINGS_PER_BOARD() external view returns (uint);

  function staleUpdateDuration() external view returns (uint);

  function priceScalingPeriod() external view returns (uint);

  function maxAcceptablePercent() external view returns (uint);

  function minAcceptablePercent() external view returns (uint);

  function liveBoards(uint) external view returns (uint);

  function listingCaches(uint)
    external
    view
    returns (
      uint id,
      uint strike,
      uint skew,
      uint boardId,
      int callDelta,
      int putDelta,
      uint stdVega,
      int callExposure,
      int putExposure,
      uint updatedAt,
      uint updatedAtPrice
    );

  function boardCaches(uint)
    external
    view
    returns (
      uint id,
      uint expiry,
      uint iv,
      uint minUpdatedAt,
      uint minUpdatedAtPrice,
      uint maxUpdatedAtPrice,
      int netDelta,
      int netStdVega
    );

  function globalCache()
    external
    view
    returns (
      int netDelta,
      int netStdVega,
      uint minUpdatedAt,
      uint minUpdatedAtPrice,
      uint maxUpdatedAtPrice,
      uint minExpiryTimestamp
    );

  function setStaleCacheParameters(
    uint _staleUpdateDuration,
    uint _priceScalingPeriod,
    uint _maxAcceptablePercent,
    uint _minAcceptablePercent
  ) external;

  function addBoard(uint boardId) external;

  function removeBoard(uint boardId) external;

  function setBoardIv(uint boardId, uint newIv) external;

  function setListingSkew(uint listingId, uint newSkew) external;

  function addListingToBoard(uint boardId, uint listingId) external;

  function updateAllStaleBoards() external returns (int);

  function updateBoardCachedGreeks(uint boardCacheId) external;

  function updateListingCacheAndGetPrice(
    ILyraGlobals.GreekCacheGlobals memory greekCacheGlobals,
    uint listingCacheId,
    int newCallExposure,
    int newPutExposure,
    uint iv,
    uint skew
  ) external returns (IOptionMarketPricer.Pricing memory);

  function isGlobalCacheStale() external view returns (bool);

  function isBoardCacheStale(uint boardCacheId) external view returns (bool);

  function getGlobalNetDelta() external view returns (int);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./ICollateralShort.sol";
import "./IExchangeRates.sol";
import "./IExchanger.sol";
import "./ISynthetix.sol";

interface ILyraGlobals {
  enum ExchangeType {BASE_QUOTE, QUOTE_BASE, ALL}

  /**
   * @dev Structs to help reduce the number of calls between other contracts and this one
   * Grouped in usage for a particular contract/use case
   */
  struct ExchangeGlobals {
    uint spotPrice;
    bytes32 quoteKey;
    bytes32 baseKey;
    ISynthetix synthetix;
    ICollateralShort short;
    uint quoteBaseFeeRate;
    uint baseQuoteFeeRate;
  }

  struct GreekCacheGlobals {
    int rateAndCarry;
    uint spotPrice;
  }

  struct PricingGlobals {
    uint optionPriceFeeCoefficient;
    uint spotPriceFeeCoefficient;
    uint vegaFeeCoefficient;
    uint vegaNormFactor;
    uint standardSize;
    uint skewAdjustmentFactor;
    int rateAndCarry;
    int minDelta;
    uint volatilityCutoff;
    uint spotPrice;
  }

  function synthetix() external view returns (ISynthetix);

  function exchanger() external view returns (IExchanger);

  function exchangeRates() external view returns (IExchangeRates);

  function collateralShort() external view returns (ICollateralShort);

  function isPaused() external view returns (bool);

  function tradingCutoff(address) external view returns (uint);

  function optionPriceFeeCoefficient(address) external view returns (uint);

  function spotPriceFeeCoefficient(address) external view returns (uint);

  function vegaFeeCoefficient(address) external view returns (uint);

  function vegaNormFactor(address) external view returns (uint);

  function standardSize(address) external view returns (uint);

  function skewAdjustmentFactor(address) external view returns (uint);

  function rateAndCarry(address) external view returns (int);

  function minDelta(address) external view returns (int);

  function volatilityCutoff(address) external view returns (uint);

  function quoteKey(address) external view returns (bytes32);

  function baseKey(address) external view returns (bytes32);

  function setGlobals(
    ISynthetix _synthetix,
    IExchanger _exchanger,
    IExchangeRates _exchangeRates,
    ICollateralShort _collateralShort
  ) external;

  function setGlobalsForContract(
    address _contractAddress,
    uint _tradingCutoff,
    PricingGlobals memory pricingGlobals,
    bytes32 _quoteKey,
    bytes32 _baseKey
  ) external;

  function setPaused(bool _isPaused) external;

  function setTradingCutoff(address _contractAddress, uint _tradingCutoff) external;

  function setOptionPriceFeeCoefficient(address _contractAddress, uint _optionPriceFeeCoefficient) external;

  function setSpotPriceFeeCoefficient(address _contractAddress, uint _spotPriceFeeCoefficient) external;

  function setVegaFeeCoefficient(address _contractAddress, uint _vegaFeeCoefficient) external;

  function setVegaNormFactor(address _contractAddress, uint _vegaNormFactor) external;

  function setStandardSize(address _contractAddress, uint _standardSize) external;

  function setSkewAdjustmentFactor(address _contractAddress, uint _skewAdjustmentFactor) external;

  function setRateAndCarry(address _contractAddress, int _rateAndCarry) external;

  function setMinDelta(address _contractAddress, int _minDelta) external;

  function setVolatilityCutoff(address _contractAddress, uint _volatilityCutoff) external;

  function setQuoteKey(address _contractAddress, bytes32 _quoteKey) external;

  function setBaseKey(address _contractAddress, bytes32 _baseKey) external;

  function getSpotPriceForMarket(address _contractAddress) external view returns (uint);

  function getSpotPrice(bytes32 to) external view returns (uint);

  function getPricingGlobals(address _contractAddress) external view returns (PricingGlobals memory);

  function getGreekCacheGlobals(address _contractAddress) external view returns (GreekCacheGlobals memory);

  function getExchangeGlobals(address _contractAddress, ExchangeType exchangeType)
    external
    view
    returns (ExchangeGlobals memory exchangeGlobals);

  function getGlobalsForOptionTrade(address _contractAddress, bool isBuy)
    external
    view
    returns (
      PricingGlobals memory pricingGlobals,
      ExchangeGlobals memory exchangeGlobals,
      uint tradeCutoff
    );
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./ILyraGlobals.sol";

interface ILiquidityPool {
  struct Collateral {
    uint quote;
    uint base;
  }

  /// @dev These are all in quoteAsset amounts.
  struct Liquidity {
    uint freeCollatLiquidity;
    uint usedCollatLiquidity;
    uint freeDeltaLiquidity;
    uint usedDeltaLiquidity;
  }

  enum Error {
    QuoteTransferFailed,
    AlreadySignalledWithdrawal,
    SignallingBetweenRounds,
    UnSignalMustSignalFirst,
    UnSignalAlreadyBurnable,
    WithdrawNotBurnable,
    EndRoundWithLiveBoards,
    EndRoundAlreadyEnded,
    EndRoundMustExchangeBase,
    EndRoundMustHedgeDelta,
    StartRoundMustEndRound,
    ReceivedZeroFromBaseQuoteExchange,
    ReceivedZeroFromQuoteBaseExchange,
    LockingMoreQuoteThanIsFree,
    LockingMoreBaseThanCanBeExchanged,
    FreeingMoreBaseThanLocked,
    SendPremiumNotEnoughCollateral,
    OnlyPoolHedger,
    OnlyOptionMarket,
    OnlyShortCollateral,
    ReentrancyDetected,
    Last
  }

  function lockedCollateral() external view returns (uint, uint);

  function queuedQuoteFunds() external view returns (uint);

  function expiryToTokenValue(uint) external view returns (uint);

  function deposit(address beneficiary, uint amount) external returns (uint);

  function signalWithdrawal(uint certificateId) external;

  function unSignalWithdrawal(uint certificateId) external;

  function withdraw(address beneficiary, uint certificateId) external returns (uint value);

  function tokenPriceQuote() external view returns (uint);

  function endRound() external;

  function startRound(uint lastMaxExpiryTimestamp, uint newMaxExpiryTimestamp) external;

  function exchangeBase() external;

  function lockQuote(uint amount, uint freeCollatLiq) external;

  function lockBase(
    uint amount,
    ILyraGlobals.ExchangeGlobals memory exchangeGlobals,
    Liquidity memory liquidity
  ) external;

  function freeQuoteCollateral(uint amount) external;

  function freeBase(uint amountBase) external;

  function sendPremium(
    address recipient,
    uint amount,
    uint freeCollatLiq
  ) external;

  function boardLiquidation(
    uint amountQuoteFreed,
    uint amountQuoteReserved,
    uint amountBaseFreed
  ) external;

  function sendReservedQuote(address user, uint amount) external;

  function getTotalPoolValueQuote(uint basePrice, uint usedDeltaLiquidity) external view returns (uint);

  function getLiquidity(uint basePrice, ICollateralShort short) external view returns (Liquidity memory);

  function transferQuoteToHedge(ILyraGlobals.ExchangeGlobals memory exchangeGlobals, uint amount)
    external
    returns (uint);
}

//SPDX-License-Identifier: ISC
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

interface ICollateralShort {
  struct Loan {
    // ID for the loan
    uint id;
    //  Account that created the loan
    address account;
    //  Amount of collateral deposited
    uint collateral;
    // The synth that was borrowed
    bytes32 currency;
    //  Amount of synths borrowed
    uint amount;
    // Indicates if the position was short sold
    bool short;
    // interest amounts accrued
    uint accruedInterest;
    // last interest index
    uint interestIndex;
    // time of last interaction.
    uint lastInteraction;
  }

  function loans(uint id)
    external
    returns (
      uint,
      address,
      uint,
      bytes32,
      uint,
      bool,
      uint,
      uint,
      uint
    );

  function minCratio() external returns (uint);

  function minCollateral() external returns (uint);

  function issueFeeRate() external returns (uint);

  function open(
    uint collateral,
    uint amount,
    bytes32 currency
  ) external returns (uint id);

  function repay(
    address borrower,
    uint id,
    uint amount
  ) external returns (uint short, uint collateral);

  function repayWithCollateral(uint id, uint repayAmount) external returns (uint short, uint collateral);

  function draw(uint id, uint amount) external returns (uint short, uint collateral);

  // Same as before
  function deposit(
    address borrower,
    uint id,
    uint amount
  ) external returns (uint short, uint collateral);

  // Same as before
  function withdraw(uint id, uint amount) external returns (uint short, uint collateral);

  // function to return the loan details in one call, without needing to know about the collateralstate
  function getShortAndCollateral(address account, uint id) external view returns (uint short, uint collateral);
}

//SPDX-License-Identifier:MIT
pragma solidity ^0.7.6;

// https://docs.synthetix.io/contracts/source/interfaces/iexchangerates
interface IExchangeRates {
  function rateAndInvalid(bytes32 currencyKey) external view returns (uint rate, bool isInvalid);
}

//SPDX-License-Identifier:MIT
pragma solidity ^0.7.6;

// https://docs.synthetix.io/contracts/source/interfaces/iexchanger
interface IExchanger {
  function feeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey)
    external
    view
    returns (uint exchangeFeeRate);
}

//SPDX-License-Identifier: ISC
pragma solidity >=0.7.6;

interface ISynthetix {
  function exchange(
    bytes32 sourceCurrencyKey,
    uint sourceAmount,
    bytes32 destinationCurrencyKey
  ) external returns (uint amountReceived);

  function exchangeOnBehalf(
    address exchangeForAddress,
    bytes32 sourceCurrencyKey,
    uint sourceAmount,
    bytes32 destinationCurrencyKey
  ) external returns (uint amountReceived);
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
library SafeMath {
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

import "../../introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

import "./IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURI is IERC1155 {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./ILyraGlobals.sol";
import "./IOptionMarket.sol";

interface IOptionMarketPricer {
  struct Pricing {
    uint optionPrice;
    int preTradeAmmNetStdVega;
    int postTradeAmmNetStdVega;
    int callDelta;
  }

  function ivImpactForTrade(
    IOptionMarket.OptionListing memory listing,
    IOptionMarket.Trade memory trade,
    ILyraGlobals.PricingGlobals memory pricingGlobals,
    uint boardBaseIv
  ) external pure returns (uint, uint);

  function updateCacheAndGetTotalCost(
    IOptionMarket.OptionListing memory listing,
    IOptionMarket.Trade memory trade,
    ILyraGlobals.PricingGlobals memory pricingGlobals,
    uint boardBaseIv
  )
    external
    returns (
      uint totalCost,
      uint newBaseIv,
      uint newSkew
    );

  function getPremium(
    IOptionMarket.Trade memory trade,
    Pricing memory pricing,
    ILyraGlobals.PricingGlobals memory pricingGlobals
  ) external pure returns (uint premium);

  function getVegaUtil(
    IOptionMarket.Trade memory trade,
    Pricing memory pricing,
    ILyraGlobals.PricingGlobals memory pricingGlobals
  ) external pure returns (uint vegaUtil);

  function getFee(
    ILyraGlobals.PricingGlobals memory pricingGlobals,
    uint amount,
    uint optionPrice,
    uint vegaUtil
  ) external pure returns (uint fee);
}