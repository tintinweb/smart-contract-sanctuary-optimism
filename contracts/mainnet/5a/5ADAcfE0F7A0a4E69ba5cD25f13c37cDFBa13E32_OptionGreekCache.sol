//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

// Libraries
import "./synthetix/SafeDecimalMath.sol";
import "./synthetix/SignedSafeDecimalMath.sol";

// Inherited
import "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IBlackScholes.sol";
import "./interfaces/ILyraGlobals.sol";
import "./interfaces/IOptionMarket.sol";
import "./interfaces/IOptionMarketPricer.sol";
import "./interfaces/IOptionGreekCache.sol";

/**
 * @title OptionGreekCache
 * @author Lyra
 * @dev Aggregates the netDelta and netStdVega of the OptionMarket by iterating over current listings.
 * Needs to be called by an external override actor as it's not feasible to do all the computation during the trade flow and
 * because delta/vega change over time and with movements in asset price and volatility.
 */
contract OptionGreekCache is IOptionGreekCache, Ownable {
  using SafeMath for uint;
  using SafeDecimalMath for uint;
  using SignedSafeMath for int;
  using SignedSafeDecimalMath for int;

  ILyraGlobals internal globals;
  IOptionMarket internal optionMarket;
  IOptionMarketPricer internal optionPricer;
  IBlackScholes internal blackScholes;

  // Limit due to gas constraints when updating
  uint public constant override MAX_LISTINGS_PER_BOARD = 10;

  // For calculating if the cache is stale based on spot price
  // These values can be quite wide as per listing updates occur whenever a trade does.
  uint public override staleUpdateDuration = 2 days;
  uint public override priceScalingPeriod = 7 days;
  uint public override maxAcceptablePercent = (1e18 / 100) * 20; // 20%
  uint public override minAcceptablePercent = (1e18 / 100) * 10; // 10%

  bool internal initialized;

  uint[] public override liveBoards; // Should be a clone of OptionMarket.liveBoards
  mapping(uint => OptionListingCache) public override listingCaches;
  mapping(uint => OptionBoardCache) public override boardCaches;
  GlobalCache public override globalCache;

  constructor() Ownable() {}

  /**
   * @dev Initialize the contract.
   *
   * @param _globals LyraGlobals address
   * @param _optionMarket OptionMarket address
   * @param _optionPricer OptionMarketPricer address
   */
  function init(
    ILyraGlobals _globals,
    IOptionMarket _optionMarket,
    IOptionMarketPricer _optionPricer,
    IBlackScholes _blackScholes
  ) external {
    require(!initialized, "Contract already initialized");
    globals = _globals;
    optionMarket = _optionMarket;
    optionPricer = _optionPricer;
    blackScholes = _blackScholes;
    initialized = true;
  }

  function setStaleCacheParameters(
    uint _staleUpdateDuration,
    uint _priceScalingPeriod,
    uint _maxAcceptablePercent,
    uint _minAcceptablePercent
  ) external override onlyOwner {
    require(_staleUpdateDuration >= 2 hours, "staleUpdateDuration too low");
    require(_maxAcceptablePercent >= _minAcceptablePercent, "maxAcceptablePercent must be >= min");
    require(_minAcceptablePercent >= (1e18 / 100) * 1, "minAcceptablePercent too low");
    // Note: this value can be zero even though it is in the divisor as timeToExpiry must be < priceScalingPeriod for it
    // to be used.
    priceScalingPeriod = _priceScalingPeriod;
    minAcceptablePercent = _minAcceptablePercent;
    maxAcceptablePercent = _maxAcceptablePercent;
    staleUpdateDuration = _staleUpdateDuration;

    emit StaleCacheParametersUpdated(
      priceScalingPeriod,
      minAcceptablePercent,
      maxAcceptablePercent,
      staleUpdateDuration
    );
  }

  ////
  // Add/Remove boards
  ////

  /**
   * @notice Adds a new OptionBoardCache.
   * @dev Called by the OptionMarket when an OptionBoard is added.
   *
   * @param boardId The id of the OptionBoard.
   */
  function addBoard(uint boardId) external override onlyOptionMarket {
    // Load in board from OptionMarket, adding net positions to global count
    (, uint expiry, uint iv, ) = optionMarket.optionBoards(boardId);
    uint[] memory listings = optionMarket.getBoardListings(boardId);

    require(listings.length <= MAX_LISTINGS_PER_BOARD, "too many listings for board");

    OptionBoardCache storage boardCache = boardCaches[boardId];
    boardCache.id = boardId;
    boardCache.expiry = expiry;
    boardCache.iv = iv;
    liveBoards.push(boardId);

    for (uint i = 0; i < listings.length; i++) {
      _addNewListingToListingCache(boardCache, listings[i]);
    }

    _updateBoardLastUpdatedAt(boardCache);
  }

  /**
   * @notice Removes an OptionBoardCache.
   * @dev Called by the OptionMarket when an OptionBoard is liquidated.
   *
   * @param boardId The id of the OptionBoard.
   */
  function removeBoard(uint boardId) external override onlyOptionMarket {
    // Remove board from cache, removing net positions from global count
    OptionBoardCache memory boardCache = boardCaches[boardId];
    globalCache.netDelta = globalCache.netDelta.sub(boardCache.netDelta);
    globalCache.netStdVega = globalCache.netStdVega.sub(boardCache.netStdVega);
    // Clean up, cache isn't necessary for settle logic
    for (uint i = 0; i < boardCache.listings.length; i++) {
      delete listingCaches[boardCache.listings[i]];
    }
    for (uint i = 0; i < liveBoards.length; i++) {
      if (liveBoards[i] == boardId) {
        liveBoards[i] = liveBoards[liveBoards.length - 1];
        liveBoards.pop();
        break;
      }
    }
    delete boardCaches[boardId];
    emit GlobalCacheUpdated(globalCache.netDelta, globalCache.netStdVega);
  }

  /**
   * @dev modifies an OptionBoard's baseIv
   *
   * @param boardId The id of the OptionBoard.
   * @param newIv The baseIv of the OptionBoard.
   */
  function setBoardIv(uint boardId, uint newIv) external override onlyOptionMarket {
    // Remove board from cache, removing net positions from global count
    OptionBoardCache storage boardCache = boardCaches[boardId];
    boardCache.iv = newIv;
  }

  /**
   * @dev modifies an OptionListing's skew
   *
   * @param listingId The id of the OptionListing.
   * @param newSkew The skew of the OptionListing.
   */
  function setListingSkew(uint listingId, uint newSkew) external override onlyOptionMarket {
    // Remove board from cache, removing net positions from global count
    OptionListingCache storage listingCache = listingCaches[listingId];
    listingCache.skew = newSkew;
  }

  /**
   * @notice Add a new listing to the listingCaches and the listingId to the boardCache
   *
   * @param boardId The id of the Board
   * @param listingId The id of the OptionListing.
   */
  function addListingToBoard(uint boardId, uint listingId) external override onlyOptionMarket {
    OptionBoardCache storage boardCache = boardCaches[boardId];
    require(boardCache.listings.length + 1 <= MAX_LISTINGS_PER_BOARD, "too many listings for board");
    _addNewListingToListingCache(boardCache, listingId);
  }

  /**
   * @notice Add a new listing to the listingCaches
   *
   * @param boardCache The OptionBoardCache object the listing is being added to
   * @param listingId The id of the OptionListing.
   */
  function _addNewListingToListingCache(OptionBoardCache storage boardCache, uint listingId) internal {
    IOptionMarket.OptionListing memory listing = getOptionMarketListing(listingId);

    // This is only called when a new board or a new listing is added, so exposure values will be 0
    OptionListingCache storage listingCache = listingCaches[listing.id];
    listingCache.id = listing.id;
    listingCache.strike = listing.strike;
    listingCache.boardId = listing.boardId;
    listingCache.skew = listing.skew;

    boardCache.listings.push(listingId);
  }

  /**
   * @notice Retrieves an OptionListing from the OptionMarket.
   *
   * @param listingId The id of the OptionListing.
   */
  function getOptionMarketListing(uint listingId) internal view returns (IOptionMarket.OptionListing memory) {
    (uint id, uint strike, uint skew, uint longCall, uint shortCall, uint longPut, uint shortPut, uint boardId) =
      optionMarket.optionListings(listingId);
    return IOptionMarket.OptionListing(id, strike, skew, longCall, shortCall, longPut, shortPut, boardId);
  }

  ////
  // Updating greeks/caches
  ////

  /**
   * @notice Updates all stale boards.
   */
  function updateAllStaleBoards() external override returns (int) {
    // Check all boards to see if they are stale
    ILyraGlobals.GreekCacheGlobals memory greekCacheGlobals = globals.getGreekCacheGlobals(address(optionMarket));
    _updateAllStaleBoards(greekCacheGlobals);
    return globalCache.netDelta;
  }

  /**
   * @dev Updates all stale boards.
   *
   * @param greekCacheGlobals The GreekCacheGlobals.
   */
  function _updateAllStaleBoards(ILyraGlobals.GreekCacheGlobals memory greekCacheGlobals) internal {
    for (uint i = 0; i < liveBoards.length; i++) {
      uint boardId = liveBoards[i];
      if (_isBoardCacheStale(boardId, greekCacheGlobals.spotPrice)) {
        // This updates all listings in the board, even though it is not strictly necessary
        _updateBoardCachedGreeks(greekCacheGlobals, boardId);
      }
    }
  }

  /**
   * @notice Updates the cached greeks for an OptionBoardCache.
   *
   * @param boardCacheId The id of the OptionBoardCache.
   */
  function updateBoardCachedGreeks(uint boardCacheId) external override {
    _updateBoardCachedGreeks(globals.getGreekCacheGlobals(address(optionMarket)), boardCacheId);
  }

  /**
   * @dev Updates the cached greeks for an OptionBoardCache.
   *
   * @param greekCacheGlobals The GreekCacheGlobals.
   * @param boardCacheId The id of the OptionBoardCache.
   */
  function _updateBoardCachedGreeks(ILyraGlobals.GreekCacheGlobals memory greekCacheGlobals, uint boardCacheId)
    internal
  {
    OptionBoardCache storage boardCache = boardCaches[boardCacheId];
    // In the case the board doesnt exist, listings.length is 0, so nothing happens
    for (uint i = 0; i < boardCache.listings.length; i++) {
      OptionListingCache storage listingCache = listingCaches[boardCache.listings[i]];
      _updateListingCachedGreeks(
        greekCacheGlobals,
        listingCache,
        boardCache,
        true,
        listingCache.callExposure,
        listingCache.putExposure
      );
    }

    boardCache.minUpdatedAt = block.timestamp;
    boardCache.minUpdatedAtPrice = greekCacheGlobals.spotPrice;
    boardCache.maxUpdatedAtPrice = greekCacheGlobals.spotPrice;
    _updateGlobalLastUpdatedAt();
  }

  /**
   * @notice Updates the OptionListingCache to reflect the new exposure.
   *
   * @param greekCacheGlobals The GreekCacheGlobals.
   * @param listingCacheId The id of the OptionListingCache.
   * @param newCallExposure The new call exposure of the OptionListing.
   * @param newPutExposure The new put exposure of the OptionListing.
   * @param iv The new iv of the OptionBoardCache.
   * @param skew The new skew of the OptionListingCache.
   */
  function updateListingCacheAndGetPrice(
    ILyraGlobals.GreekCacheGlobals memory greekCacheGlobals,
    uint listingCacheId,
    int newCallExposure,
    int newPutExposure,
    uint iv,
    uint skew
  ) external override onlyOptionMarketPricer returns (IOptionMarketPricer.Pricing memory) {
    require(!_isGlobalCacheStale(greekCacheGlobals.spotPrice), "Global cache is stale");
    OptionListingCache storage listingCache = listingCaches[listingCacheId];
    OptionBoardCache storage boardCache = boardCaches[listingCache.boardId];

    int callExposureDiff = newCallExposure.sub(listingCache.callExposure);
    int putExposureDiff = newPutExposure.sub(listingCache.putExposure);

    require(callExposureDiff == 0 || putExposureDiff == 0, "both call and put exposure updated");

    boardCache.iv = iv;
    listingCache.skew = skew;

    // The AMM's net std vega is opposite to the global sum of user's std vega
    int preTradeAmmNetStdVega = -globalCache.netStdVega;

    IOptionMarketPricer.Pricing memory pricing =
      _updateListingCachedGreeks(
        greekCacheGlobals,
        listingCache,
        boardCache,
        callExposureDiff != 0,
        newCallExposure,
        newPutExposure
      );
    pricing.preTradeAmmNetStdVega = preTradeAmmNetStdVega;

    _updateBoardLastUpdatedAt(boardCache);

    return pricing;
  }

  /**
   * @dev Updates an OptionListingCache.
   *
   * @param greekCacheGlobals The GreekCacheGlobals.
   * @param listingCache The OptionListingCache.
   * @param boardCache The OptionBoardCache.
   * @param returnCallPrice If true, return the call price, otherwise return the put price.
   */
  function _updateListingCachedGreeks(
    ILyraGlobals.GreekCacheGlobals memory greekCacheGlobals,
    OptionListingCache storage listingCache,
    OptionBoardCache storage boardCache,
    bool returnCallPrice,
    int newCallExposure,
    int newPutExposure
  ) internal returns (IOptionMarketPricer.Pricing memory pricing) {
    IBlackScholes.PricesDeltaStdVega memory pricesDeltaStdVega =
      blackScholes.pricesDeltaStdVega(
        timeToMaturitySeconds(boardCache.expiry),
        boardCache.iv.multiplyDecimal(listingCache.skew),
        greekCacheGlobals.spotPrice,
        listingCache.strike,
        greekCacheGlobals.rateAndCarry
      );

    // (newCallExposure * newCallDelta - oldCallExposure * oldCallDelta)
    // + (newPutExposure * newPutDelta - oldPutExposure * oldPutDelta)
    int netDeltaDiff =
      (
        (newCallExposure.multiplyDecimal(pricesDeltaStdVega.callDelta)) // newCall
          .sub(listingCache.callExposure.multiplyDecimal(listingCache.callDelta))
          .add(
          (newPutExposure.multiplyDecimal(pricesDeltaStdVega.putDelta)).sub(
            listingCache.putExposure.multiplyDecimal(listingCache.putDelta)
          )
        )
      );

    int netStdVegaDiff =
      newCallExposure.add(newPutExposure).multiplyDecimal(int(pricesDeltaStdVega.stdVega)).sub(
        listingCache.callExposure.add(listingCache.putExposure).multiplyDecimal(int(listingCache.stdVega))
      );

    if (listingCache.callExposure != newCallExposure || listingCache.putExposure != newPutExposure) {
      emit ListingExposureUpdated(listingCache.id, newCallExposure, newPutExposure);
    }

    listingCache.callExposure = newCallExposure;
    listingCache.putExposure = newPutExposure;
    listingCache.callDelta = pricesDeltaStdVega.callDelta;
    listingCache.putDelta = pricesDeltaStdVega.putDelta;
    listingCache.stdVega = pricesDeltaStdVega.stdVega;

    listingCache.updatedAt = block.timestamp;
    listingCache.updatedAtPrice = greekCacheGlobals.spotPrice;

    boardCache.netDelta = boardCache.netDelta.add(netDeltaDiff);
    boardCache.netStdVega = boardCache.netStdVega.add(netStdVegaDiff);

    globalCache.netDelta = globalCache.netDelta.add(netDeltaDiff);
    globalCache.netStdVega = globalCache.netStdVega.add(netStdVegaDiff);

    pricing.optionPrice = returnCallPrice ? pricesDeltaStdVega.callPrice : pricesDeltaStdVega.putPrice;
    // AMM's net positions are the inverse of the user's net position
    pricing.postTradeAmmNetStdVega = -globalCache.netStdVega;
    pricing.callDelta = pricesDeltaStdVega.callDelta;

    emit ListingGreeksUpdated(
      listingCache.id,
      pricesDeltaStdVega.callDelta,
      pricesDeltaStdVega.putDelta,
      pricesDeltaStdVega.stdVega,
      greekCacheGlobals.spotPrice,
      boardCache.iv,
      listingCache.skew
    );
    emit GlobalCacheUpdated(globalCache.netDelta, globalCache.netStdVega);

    return pricing;
  }

  /**
   * @notice Checks if the GlobalCache is stale.
   */
  function isGlobalCacheStale() external view override returns (bool) {
    // Check all boards to see if they are stale
    uint currentPrice = getCurrentPrice();
    return _isGlobalCacheStale(currentPrice);
  }

  /**
   * @dev Checks if the GlobalCache is stale.
   *
   * @param spotPrice The price of the baseAsset.
   */
  function _isGlobalCacheStale(uint spotPrice) internal view returns (bool) {
    // Check all boards to see if they are stale
    return (isUpdatedAtTimeStale(globalCache.minUpdatedAt) ||
      !isPriceMoveAcceptable(
        globalCache.minUpdatedAtPrice,
        spotPrice,
        timeToMaturitySeconds(globalCache.minExpiryTimestamp)
      ) ||
      !isPriceMoveAcceptable(
        globalCache.maxUpdatedAtPrice,
        spotPrice,
        timeToMaturitySeconds(globalCache.minExpiryTimestamp)
      ));
  }

  /**
   * @notice Checks if the OptionBoardCache is stale.
   *
   * @param boardCacheId The OptionBoardCache id.
   */
  function isBoardCacheStale(uint boardCacheId) external view override returns (bool) {
    uint spotPrice = getCurrentPrice();
    return _isBoardCacheStale(boardCacheId, spotPrice);
  }

  /**
   * @dev Checks if the OptionBoardCache is stale.
   *
   * @param boardCacheId The OptionBoardCache id.
   * @param spotPrice The price of the baseAsset.
   */
  function _isBoardCacheStale(uint boardCacheId, uint spotPrice) internal view returns (bool) {
    // We do not have to check every individual listing, as the OptionBoardCache
    // should always keep the minimum values.
    OptionBoardCache memory boardCache = boardCaches[boardCacheId];
    require(boardCache.id != 0, "Board does not exist");

    return
      isUpdatedAtTimeStale(boardCache.minUpdatedAt) ||
      !isPriceMoveAcceptable(boardCache.minUpdatedAtPrice, spotPrice, timeToMaturitySeconds(boardCache.expiry)) ||
      !isPriceMoveAcceptable(boardCache.maxUpdatedAtPrice, spotPrice, timeToMaturitySeconds(boardCache.expiry));
  }

  /**
   * @dev Checks if `updatedAt` is stale.
   *
   * @param updatedAt The time of the last update.
   */
  function isUpdatedAtTimeStale(uint updatedAt) internal view returns (bool) {
    // This can be more complex than just checking the item wasn't updated in the last two hours
    return getSecondsTo(updatedAt, block.timestamp) > staleUpdateDuration;
  }

  /**
   * @dev Check if the price move of an asset is acceptable given the time to expiry.
   *
   * @param pastPrice The previous price.
   * @param currentPrice The current price.
   * @param timeToExpirySec The time to expiry in seconds.
   */
  function isPriceMoveAcceptable(
    uint pastPrice,
    uint currentPrice,
    uint timeToExpirySec
  ) internal view returns (bool) {
    uint acceptablePriceMovementPercent = maxAcceptablePercent;

    if (timeToExpirySec < priceScalingPeriod) {
      acceptablePriceMovementPercent = ((maxAcceptablePercent.sub(minAcceptablePercent)).mul(timeToExpirySec))
        .div(priceScalingPeriod)
        .add(minAcceptablePercent);
    }

    uint acceptablePriceMovement = pastPrice.multiplyDecimal(acceptablePriceMovementPercent);

    if (currentPrice > pastPrice) {
      return currentPrice.sub(pastPrice) < acceptablePriceMovement;
    } else {
      return pastPrice.sub(currentPrice) < acceptablePriceMovement;
    }
  }

  /**
   * @dev Updates `lastUpdatedAt` for an OptionBoardCache.
   *
   * @param boardCache The OptionBoardCache.
   */
  function _updateBoardLastUpdatedAt(OptionBoardCache storage boardCache) internal {
    OptionListingCache memory listingCache = listingCaches[boardCache.listings[0]];
    uint minUpdate = listingCache.updatedAt;
    uint minPrice = listingCache.updatedAtPrice;
    uint maxPrice = listingCache.updatedAtPrice;

    for (uint i = 1; i < boardCache.listings.length; i++) {
      listingCache = listingCaches[boardCache.listings[i]];
      if (listingCache.updatedAt < minUpdate) {
        minUpdate = listingCache.updatedAt;
      }
      if (listingCache.updatedAtPrice < minPrice) {
        minPrice = listingCache.updatedAtPrice;
      } else if (listingCache.updatedAtPrice > maxPrice) {
        maxPrice = listingCache.updatedAtPrice;
      }
    }
    boardCache.minUpdatedAt = minUpdate;
    boardCache.minUpdatedAtPrice = minPrice;
    boardCache.maxUpdatedAtPrice = maxPrice;

    _updateGlobalLastUpdatedAt();
  }

  /**
   * @dev Updates global `lastUpdatedAt`.
   */
  function _updateGlobalLastUpdatedAt() internal {
    OptionBoardCache memory boardCache = boardCaches[liveBoards[0]];
    uint minUpdate = boardCache.minUpdatedAt;
    uint minPrice = boardCache.minUpdatedAtPrice;
    uint minExpiry = boardCache.expiry;
    uint maxPrice = boardCache.maxUpdatedAtPrice;

    for (uint i = 1; i < liveBoards.length; i++) {
      boardCache = boardCaches[liveBoards[i]];
      if (boardCache.minUpdatedAt < minUpdate) {
        minUpdate = boardCache.minUpdatedAt;
      }
      if (boardCache.minUpdatedAtPrice < minPrice) {
        minPrice = boardCache.minUpdatedAtPrice;
      }
      if (boardCache.maxUpdatedAtPrice > maxPrice) {
        maxPrice = boardCache.maxUpdatedAtPrice;
      }
      if (boardCache.expiry < minExpiry) {
        minExpiry = boardCache.expiry;
      }
    }

    globalCache.minUpdatedAt = minUpdate;
    globalCache.minUpdatedAtPrice = minPrice;
    globalCache.maxUpdatedAtPrice = maxPrice;
    globalCache.minExpiryTimestamp = minExpiry;
  }

  /**
   * @dev Returns time to maturity for a given expiry.
   */
  function timeToMaturitySeconds(uint expiry) internal view returns (uint) {
    return getSecondsTo(block.timestamp, expiry);
  }

  /**
   * @dev Returns the difference in seconds between two dates.
   */
  function getSecondsTo(uint fromTime, uint toTime) internal pure returns (uint) {
    if (toTime > fromTime) {
      return toTime - fromTime;
    }
    return 0;
  }

  /**
   * @dev Get the price of the baseAsset for the OptionMarket.
   */
  function getCurrentPrice() internal view returns (uint) {
    return globals.getSpotPriceForMarket(address(optionMarket));
  }

  /**
   * @dev Get the current cached global netDelta value.
   */
  function getGlobalNetDelta() external view override returns (int) {
    return globalCache.netDelta;
  }

  modifier onlyOptionMarket virtual {
    require(msg.sender == address(optionMarket), "Only optionMarket permitted");
    _;
  }

  modifier onlyOptionMarketPricer virtual {
    require(msg.sender == address(optionPricer), "Only optionPricer permitted");
    _;
  }

  /**
   * @dev Emitted when stale cache parameters are updated.
   */
  event StaleCacheParametersUpdated(
    uint priceScalingPeriod,
    uint minAcceptablePercent,
    uint maxAcceptablePercent,
    uint staleUpdateDuration
  );

  /**
   * @dev Emitted when the cache of an OptionListing is updated.
   */
  event ListingGreeksUpdated(
    uint indexed listingId,
    int callDelta,
    int putDelta,
    uint vega,
    uint price,
    uint baseIv,
    uint skew
  );

  /**
   * @dev Emitted when the exposure of an OptionListing is updated.
   */
  event ListingExposureUpdated(uint indexed listingId, int newCallExposure, int newPutExposure);

  /**
   * @dev Emitted when the GlobalCache is updated.
   */
  event GlobalCacheUpdated(int netDelta, int netStdVega);
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

//SPDX-License-Identifier: MIT
//MIT License
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
import "@openzeppelin/contracts/math/SignedSafeMath.sol";

// https://docs.synthetix.io/contracts/source/libraries/safedecimalmath
library SignedSafeDecimalMath {
  using SignedSafeMath for int;

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
    int x,
    int y,
    int precisionUnit
  ) private pure returns (int) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    int quotientTimesTen = x.mul(y) / (precisionUnit / 10);

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
    int x,
    int y,
    int precisionUnit
  ) private pure returns (int) {
    int resultTimesTen = x.mul(precisionUnit * 10).div(y);

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
    return i.mul(UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR);
  }

  /**
   * @dev Convert a high precision decimal to a standard decimal representation.
   */
  function preciseDecimalToDecimal(int i) internal pure returns (int) {
    int quotientTimesTen = i / (UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR / 10);

    if (quotientTimesTen % 10 >= 5) {
      quotientTimesTen += 10;
    }

    return quotientTimesTen / 10;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
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

pragma solidity >=0.6.0 <0.8.0;

/**
 * @title SignedSafeMath
 * @dev Signed math operations with safety checks that revert on error.
 */
library SignedSafeMath {
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

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
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