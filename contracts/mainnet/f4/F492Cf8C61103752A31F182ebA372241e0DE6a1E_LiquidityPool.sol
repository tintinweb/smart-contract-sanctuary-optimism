//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

// Libraries
import "./synthetix/SafeDecimalMath.sol";

// Interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IOptionMarket.sol";
import "./interfaces/ILiquidityCertificate.sol";
import "./interfaces/IPoolHedger.sol";
import "./interfaces/IShortCollateral.sol";

/**
 * @title LiquidityPool
 * @author Lyra
 * @dev Holds funds from LPs, which are used for the following purposes:
 * 1. Collateralizing options sold by the OptionMarket.
 * 2. Buying options from users.
 * 3. Delta hedging the LPs.
 * 4. Storing funds for expired in the money options.
 */
contract LiquidityPool is ILiquidityPool {
  using SafeMath for uint;
  using SafeDecimalMath for uint;

  ////
  // Constants
  ////
  ILyraGlobals internal globals;
  IOptionMarket internal optionMarket;
  ILiquidityCertificate internal liquidityCertificate;
  IShortCollateral internal shortCollateral;
  IPoolHedger internal poolHedger;
  IERC20 internal quoteAsset;
  IERC20 internal baseAsset;
  uint internal constant INITIAL_RATE = 1e18;

  ////
  // Variables
  ////
  mapping(uint => string) internal errorMessages;

  bool internal initialized = false;

  /// @dev Amount of collateral locked for outstanding calls and puts sold to users
  Collateral public override lockedCollateral;
  /**
   * @dev Total amount of quoteAsset held to pay out users who have locked/waited for their tokens to be burnable. As
   * well as keeping track of all settled option's usd value.
   */
  uint internal totalQuoteAmountReserved;
  /// @dev Total number of tokens that will be removed from the totalTokenSupply at the end of the round.
  uint internal tokensBurnableForRound;
  /// @dev Funds entering the pool in the next round.
  uint public override queuedQuoteFunds;
  /// @dev Total amount of tokens that represents the total amount of pool shares
  uint internal totalTokenSupply;
  /// @dev Counter for reentrancy guard.
  uint internal counter = 1;

  /**
   * @dev Mapping of timestamps to conversion rates of liquidity to tokens. To get the token value of a certificate;
   * `certificate.liquidity / expiryToTokenValue[certificate.enteredAt]`
   */
  mapping(uint => uint) public override expiryToTokenValue;

  constructor() {}

  /**
   * @dev Initialize the contract.
   *
   * @param _optionMarket OptionMarket address
   * @param _liquidityCertificate LiquidityCertificate address
   * @param _quoteAsset Quote Asset address
   * @param _poolHedger PoolHedger address
   */
  function init(
    ILyraGlobals _globals,
    IOptionMarket _optionMarket,
    ILiquidityCertificate _liquidityCertificate,
    IPoolHedger _poolHedger,
    IShortCollateral _shortCollateral,
    IERC20 _quoteAsset,
    IERC20 _baseAsset,
    string[] memory _errorMessages
  ) external {
    require(!initialized, "already initialized");
    globals = _globals;
    optionMarket = _optionMarket;
    liquidityCertificate = _liquidityCertificate;
    shortCollateral = _shortCollateral;
    poolHedger = _poolHedger;
    quoteAsset = _quoteAsset;
    baseAsset = _baseAsset;
    require(_errorMessages.length == uint(Error.Last), "error msg count");
    for (uint i = 0; i < _errorMessages.length; i++) {
      errorMessages[i] = _errorMessages[i];
    }
    initialized = true;
  }

  ////////////////////////////////////////////////////////////////
  // Dealing with providing liquidity and withdrawing liquidity //
  ////////////////////////////////////////////////////////////////

  /**
   * @dev Deposits liquidity to the pool. This assumes users have authorised access to the quote ERC20 token. Will add
   * any deposited amount to the queuedQuoteFunds until the next round begins.
   *
   * @param beneficiary The account that will receive the liquidity certificate.
   * @param amount The amount of quoteAsset to deposit.
   */
  function deposit(address beneficiary, uint amount) external override returns (uint) {
    // Assume we have the allowance to take the amount they are depositing
    queuedQuoteFunds = queuedQuoteFunds.add(amount);
    uint certificateId = liquidityCertificate.mint(beneficiary, amount, optionMarket.maxExpiryTimestamp());
    emit Deposit(beneficiary, certificateId, amount);
    _require(quoteAsset.transferFrom(msg.sender, address(this), amount), Error.QuoteTransferFailed);
    return certificateId;
  }

  /**
   * @notice Signals withdraw of liquidity from the pool.
   * @dev It is not possible to withdraw during a round, thus a user can signal to withdraw at the time the round ends.
   *
   * @param certificateId The id of the LiquidityCertificate.
   */
  function signalWithdrawal(uint certificateId) external override {
    ILiquidityCertificate.CertificateData memory certificateData = liquidityCertificate.certificateData(certificateId);
    uint maxExpiryTimestamp = optionMarket.maxExpiryTimestamp();

    _require(certificateData.burnableAt == 0, Error.AlreadySignalledWithdrawal);
    _require(
      certificateData.enteredAt != maxExpiryTimestamp && expiryToTokenValue[maxExpiryTimestamp] == 0,
      Error.SignallingBetweenRounds
    );

    if (certificateData.enteredAt == 0) {
      // Dividing by INITIAL_RATE is redundant as initial rate is 1 unit
      tokensBurnableForRound = tokensBurnableForRound.add(certificateData.liquidity);
    } else {
      tokensBurnableForRound = tokensBurnableForRound.add(
        certificateData.liquidity.divideDecimal(expiryToTokenValue[certificateData.enteredAt])
      );
    }

    liquidityCertificate.setBurnableAt(msg.sender, certificateId, maxExpiryTimestamp);

    emit WithdrawSignaled(certificateId, tokensBurnableForRound);
  }

  /**
   * @dev Undo a previously signalled withdraw. Certificate owner must have signalled withdraw to call this function,
   * and cannot unsignal if the token is already burnable or burnt.
   *
   * @param certificateId The id of the LiquidityCertificate.
   */
  function unSignalWithdrawal(uint certificateId) external override {
    ILiquidityCertificate.CertificateData memory certificateData = liquidityCertificate.certificateData(certificateId);

    // Cannot unsignal withdrawal if the token is burnable/hasn't signalled exit
    _require(certificateData.burnableAt != 0, Error.UnSignalMustSignalFirst);
    _require(expiryToTokenValue[certificateData.burnableAt] == 0, Error.UnSignalAlreadyBurnable);

    liquidityCertificate.setBurnableAt(msg.sender, certificateId, 0);

    if (certificateData.enteredAt == 0) {
      // Dividing by INITIAL_RATE is redundant as initial rate is 1 unit
      tokensBurnableForRound = tokensBurnableForRound.sub(certificateData.liquidity);
    } else {
      tokensBurnableForRound = tokensBurnableForRound.sub(
        certificateData.liquidity.divideDecimal(expiryToTokenValue[certificateData.enteredAt])
      );
    }

    emit WithdrawUnSignaled(certificateId, tokensBurnableForRound);
  }

  /**
   * @dev Withdraws liquidity from the pool.
   *
   * This requires tokens to have been locked until the round ending at the burnableAt timestamp has been ended.
   * This will burn the liquidityCertificates and have the quote asset equivalent at the time be reserved for the users.
   *
   * @param beneficiary The account that will receive the withdrawn funds.
   * @param certificateId The id of the LiquidityCertificate.
   */
  function withdraw(address beneficiary, uint certificateId) external override returns (uint value) {
    ILiquidityCertificate.CertificateData memory certificateData = liquidityCertificate.certificateData(certificateId);
    uint maxExpiryTimestamp = optionMarket.maxExpiryTimestamp();

    // We allow people to withdraw if their funds haven't entered the system
    if (certificateData.enteredAt == maxExpiryTimestamp) {
      queuedQuoteFunds = queuedQuoteFunds.sub(certificateData.liquidity);
      liquidityCertificate.burn(msg.sender, certificateId);
      emit Withdraw(beneficiary, certificateId, certificateData.liquidity, totalQuoteAmountReserved);
      _require(quoteAsset.transfer(beneficiary, certificateData.liquidity), Error.QuoteTransferFailed);
      return certificateData.liquidity;
    }

    uint enterValue = certificateData.enteredAt == 0 ? INITIAL_RATE : expiryToTokenValue[certificateData.enteredAt];

    // expiryToTokenValue will only be set if the previous round has ended, and the next has not started
    uint currentRoundValue = expiryToTokenValue[maxExpiryTimestamp];

    // If they haven't signaled withdrawal, and it is between rounds
    if (certificateData.burnableAt == 0 && currentRoundValue != 0) {
      uint tokenAmt = certificateData.liquidity.divideDecimal(enterValue);
      totalTokenSupply = totalTokenSupply.sub(tokenAmt);
      value = tokenAmt.multiplyDecimal(currentRoundValue);
      liquidityCertificate.burn(msg.sender, certificateId);
      emit Withdraw(beneficiary, certificateId, value, totalQuoteAmountReserved);
      _require(quoteAsset.transfer(beneficiary, value), Error.QuoteTransferFailed);
      return value;
    }

    uint exitValue = expiryToTokenValue[certificateData.burnableAt];

    _require(certificateData.burnableAt != 0 && exitValue != 0, Error.WithdrawNotBurnable);

    value = certificateData.liquidity.multiplyDecimal(exitValue).divideDecimal(enterValue);

    // We can allow a 0 expiry for options created before any boards exist
    liquidityCertificate.burn(msg.sender, certificateId);

    totalQuoteAmountReserved = totalQuoteAmountReserved.sub(value);
    emit Withdraw(beneficiary, certificateId, value, totalQuoteAmountReserved);
    _require(quoteAsset.transfer(beneficiary, value), Error.QuoteTransferFailed);
    return value;
  }

  //////////////////////////////////////////////
  // Dealing with locking and expiry rollover //
  //////////////////////////////////////////////

  /**
   * @dev Return Token value.
   *
   * This token price is only accurate within the period between rounds.
   */
  function tokenPriceQuote() public view override returns (uint) {
    ILyraGlobals.ExchangeGlobals memory exchangeGlobals =
      globals.getExchangeGlobals(address(optionMarket), ILyraGlobals.ExchangeType.ALL);

    if (totalTokenSupply == 0) {
      return INITIAL_RATE;
    }

    uint poolValue =
      getTotalPoolValueQuote(
        exchangeGlobals.spotPrice,
        poolHedger.getValueQuote(exchangeGlobals.short, exchangeGlobals.spotPrice)
      );
    return poolValue.divideDecimal(totalTokenSupply);
  }

  /**
   * @notice Ends a round.
   * @dev Should only be called after all boards have been liquidated.
   */
  function endRound() external override {
    // Round can only be ended if all boards have been liquidated, and can only be called once.
    uint maxExpiryTimestamp = optionMarket.maxExpiryTimestamp();
    // We must ensure all boards have been expired
    _require(optionMarket.getLiveBoards().length == 0, Error.EndRoundWithLiveBoards);
    // We can only end the round once
    _require(expiryToTokenValue[maxExpiryTimestamp] == 0, Error.EndRoundAlreadyEnded);
    // We want to make sure all base collateral has been exchanged
    _require(baseAsset.balanceOf(address(this)) == 0, Error.EndRoundMustExchangeBase);
    // We want to make sure there is no outstanding poolHedger balance. If there is collateral left in the poolHedger
    // it will not affect calculations.
    _require(poolHedger.getCurrentHedgedNetDelta() == 0, Error.EndRoundMustHedgeDelta);

    uint pricePerToken = tokenPriceQuote();

    // Store the value for the tokens that are burnable for this round
    expiryToTokenValue[maxExpiryTimestamp] = pricePerToken;

    // Reserve the amount of quote we need for the tokens that are burnable
    totalQuoteAmountReserved = totalQuoteAmountReserved.add(tokensBurnableForRound.multiplyDecimal(pricePerToken));
    emit QuoteReserved(tokensBurnableForRound.multiplyDecimal(pricePerToken), totalQuoteAmountReserved);

    totalTokenSupply = totalTokenSupply.sub(tokensBurnableForRound);
    emit RoundEnded(maxExpiryTimestamp, pricePerToken, totalQuoteAmountReserved, tokensBurnableForRound);
    tokensBurnableForRound = 0;
  }

  /**
   * @dev Starts a round. Can only be called by optionMarket contract when adding a board.
   *
   * @param lastMaxExpiryTimestamp The time at which the previous round ended.
   * @param newMaxExpiryTimestamp The time which funds will be locked until.
   */
  function startRound(uint lastMaxExpiryTimestamp, uint newMaxExpiryTimestamp) external override onlyOptionMarket {
    // As the value is never reset, this is when the first board is added
    if (lastMaxExpiryTimestamp == 0) {
      totalTokenSupply = queuedQuoteFunds;
    } else {
      _require(expiryToTokenValue[lastMaxExpiryTimestamp] != 0, Error.StartRoundMustEndRound);
      totalTokenSupply = totalTokenSupply.add(
        queuedQuoteFunds.divideDecimal(expiryToTokenValue[lastMaxExpiryTimestamp])
      );
    }
    queuedQuoteFunds = 0;

    emit RoundStarted(
      lastMaxExpiryTimestamp,
      newMaxExpiryTimestamp,
      totalTokenSupply,
      lastMaxExpiryTimestamp == 0 ? SafeDecimalMath.UNIT : expiryToTokenValue[lastMaxExpiryTimestamp]
    );
  }

  /////////////////////////////////////////
  // Dealing with collateral for options //
  /////////////////////////////////////////

  /**
   * @dev external override function that will bring the base balance of this contract to match locked.base. This cannot be done
   * in the same transaction as locking the base, as exchanging on synthetix is too costly gas-wise.
   */
  function exchangeBase() external override reentrancyGuard {
    uint currentBaseBalance = baseAsset.balanceOf(address(this));

    // Add this additional check to prevent any soft locks at round end, as the base balance must be 0 to end the round.
    if (optionMarket.getLiveBoards().length == 0) {
      lockedCollateral.base = 0;
    }

    if (currentBaseBalance > lockedCollateral.base) {
      // Sell excess baseAsset
      ILyraGlobals.ExchangeGlobals memory exchangeGlobals =
        globals.getExchangeGlobals(address(optionMarket), ILyraGlobals.ExchangeType.BASE_QUOTE);
      uint amount = currentBaseBalance - lockedCollateral.base;
      uint quoteReceived =
        exchangeGlobals.synthetix.exchange(exchangeGlobals.baseKey, amount, exchangeGlobals.quoteKey);
      _require(quoteReceived > 0, Error.ReceivedZeroFromBaseQuoteExchange);
      emit BaseSold(msg.sender, amount, quoteReceived);
    } else if (lockedCollateral.base > currentBaseBalance) {
      // Buy required amount of baseAsset
      ILyraGlobals.ExchangeGlobals memory exchangeGlobals =
        globals.getExchangeGlobals(address(optionMarket), ILyraGlobals.ExchangeType.QUOTE_BASE);
      uint quoteToSpend =
        (lockedCollateral.base - currentBaseBalance)
          .divideDecimalRound(SafeDecimalMath.UNIT.sub(exchangeGlobals.quoteBaseFeeRate))
          .multiplyDecimalRound(exchangeGlobals.spotPrice);
      uint totalQuoteAvailable =
        quoteAsset.balanceOf(address(this)).sub(totalQuoteAmountReserved).sub(lockedCollateral.quote).sub(
          queuedQuoteFunds
        );
      // We want to always buy as much collateral as we can, even if it dips into the delta hedging portion.
      // But we cannot compromise funds that aren't useable by the pool.
      quoteToSpend = quoteToSpend > totalQuoteAvailable ? totalQuoteAvailable : quoteToSpend;
      uint amtReceived =
        exchangeGlobals.synthetix.exchange(exchangeGlobals.quoteKey, quoteToSpend, exchangeGlobals.baseKey);
      _require(amtReceived > 0, Error.ReceivedZeroFromQuoteBaseExchange);
      emit BasePurchased(msg.sender, quoteToSpend, amtReceived);
    }
  }

  /**
   * @notice Locks quote when the system sells a put option.
   *
   * @param amount The amount of quote to lock.
   * @param freeCollatLiq The amount of free collateral that can be locked.
   */
  function lockQuote(uint amount, uint freeCollatLiq) external override onlyOptionMarket {
    _require(amount <= freeCollatLiq, Error.LockingMoreQuoteThanIsFree);
    lockedCollateral.quote = lockedCollateral.quote.add(amount);
    emit QuoteLocked(amount, lockedCollateral.quote);
  }

  /**
   * @notice Purchases and locks base when the system sells a call option.
   *
   * @param amount The amount of baseAsset to purchase and lock.
   * @param exchangeGlobals The exchangeGlobals.
   * @param liquidity Free and used liquidity amounts.
   */
  function lockBase(
    uint amount,
    ILyraGlobals.ExchangeGlobals memory exchangeGlobals,
    Liquidity memory liquidity
  ) external override onlyOptionMarket {
    uint currentBaseBal = baseAsset.balanceOf(address(this));

    uint desiredBase;
    uint availableQuote = liquidity.freeCollatLiquidity;

    if (lockedCollateral.base >= currentBaseBal) {
      uint outstanding = lockedCollateral.base - currentBaseBal;
      // We need to ignore any base we haven't purchased yet from our availableQuote
      availableQuote = availableQuote.add(outstanding.multiplyDecimal(exchangeGlobals.spotPrice));
      // But we want to make sure we will have enough quote to cover the debt owed on top of new base we want to lock
      desiredBase = amount.add(outstanding);
    } else {
      // We actually need to buy less, or none, if we already have excess balance
      uint excess = currentBaseBal - lockedCollateral.base;
      if (excess >= amount) {
        desiredBase = 0;
      } else {
        desiredBase = amount.sub(excess);
      }
    }
    uint quoteToSpend =
      desiredBase.divideDecimalRound(SafeDecimalMath.UNIT.sub(exchangeGlobals.quoteBaseFeeRate)).multiplyDecimalRound(
        exchangeGlobals.spotPrice
      );

    _require(availableQuote >= quoteToSpend, Error.LockingMoreBaseThanCanBeExchanged);

    lockedCollateral.base = lockedCollateral.base.add(amount);
    emit BaseLocked(amount, lockedCollateral.base);
  }

  /**
   * @notice Frees quote when the system buys back a put from the user.
   *
   * @param amount The amount of quote to free.
   */
  function freeQuoteCollateral(uint amount) external override onlyOptionMarket {
    _freeQuoteCollateral(amount);
  }

  /**
   * @notice Frees quote when the system buys back a put from the user.
   *
   * @param amount The amount of quote to free.
   */
  function _freeQuoteCollateral(uint amount) internal {
    // Handle rounding errors by returning the full amount when the requested amount is greater
    if (amount > lockedCollateral.quote) {
      amount = lockedCollateral.quote;
    }
    lockedCollateral.quote = lockedCollateral.quote.sub(amount);
    emit QuoteFreed(amount, lockedCollateral.quote);
  }

  /**
   * @notice Sells base and frees the proceeds of the sale.
   *
   * @param amountBase The amount of base to sell.
   */
  function freeBase(uint amountBase) external override onlyOptionMarket {
    _require(amountBase <= lockedCollateral.base, Error.FreeingMoreBaseThanLocked);
    lockedCollateral.base = lockedCollateral.base.sub(amountBase);
    emit BaseFreed(amountBase, lockedCollateral.base);
  }

  /**
   * @notice Sends the premium to a user who is selling an option to the pool.
   * @dev The caller must be the OptionMarket.
   *
   * @param recipient The address of the recipient.
   * @param amount The amount to transfer.
   * @param freeCollatLiq The amount of free collateral liquidity.
   */
  function sendPremium(
    address recipient,
    uint amount,
    uint freeCollatLiq
  ) external override onlyOptionMarket reentrancyGuard {
    _require(freeCollatLiq >= amount, Error.SendPremiumNotEnoughCollateral);
    _require(quoteAsset.transfer(recipient, amount), Error.QuoteTransferFailed);

    emit CollateralQuoteTransferred(recipient, amount);
  }

  //////////////////////////////////////////
  // Dealing with expired option premiums //
  //////////////////////////////////////////

  /**
   * @notice Manages collateral at the time of board liquidation, also converting base sent here from the OptionMarket.
   *
   * @param amountQuoteFreed Total amount of base to convert to quote, including profits from short calls.
   * @param amountQuoteReserved Total amount of base to convert to quote, including profits from short calls.
   * @param amountBaseFreed Total amount of collateral to liquidate.
   */
  function boardLiquidation(
    uint amountQuoteFreed,
    uint amountQuoteReserved,
    uint amountBaseFreed
  ) external override onlyOptionMarket {
    _freeQuoteCollateral(amountQuoteFreed);

    totalQuoteAmountReserved = totalQuoteAmountReserved.add(amountQuoteReserved);
    emit QuoteReserved(amountQuoteReserved, totalQuoteAmountReserved);

    lockedCollateral.base = lockedCollateral.base.sub(amountBaseFreed);
    emit BaseFreed(amountBaseFreed, lockedCollateral.base);
  }

  /**
   * @dev Transfers reserved quote. Sends `amount` of reserved quoteAsset to `user`.
   *
   * Requirements:
   *
   * - the caller must be `OptionMarket`.
   *
   * @param user The address of the user to send the quote.
   * @param amount The amount of quote to send.
   */
  function sendReservedQuote(address user, uint amount) external override onlyShortCollateral reentrancyGuard {
    // Should never happen, but added to prevent any potential rounding errors
    if (amount > totalQuoteAmountReserved) {
      amount = totalQuoteAmountReserved;
    }
    totalQuoteAmountReserved = totalQuoteAmountReserved.sub(amount);
    _require(quoteAsset.transfer(user, amount), Error.QuoteTransferFailed);

    emit ReservedQuoteSent(user, amount, totalQuoteAmountReserved);
  }

  ////////////////////////////
  // Getting Pool Liquidity //
  ////////////////////////////

  /**
   * @notice Returns the total pool value in quoteAsset.
   *
   * @param basePrice The price of the baseAsset.
   * @param usedDeltaLiquidity The amout of delta liquidity that has been used for hedging.
   */
  function getTotalPoolValueQuote(uint basePrice, uint usedDeltaLiquidity) public view override returns (uint) {
    return
      quoteAsset
        .balanceOf(address(this))
        .add(baseAsset.balanceOf(address(this)).multiplyDecimal(basePrice))
        .add(usedDeltaLiquidity)
        .sub(totalQuoteAmountReserved)
        .sub(queuedQuoteFunds);
  }

  /**
   * @notice Returns the used and free amounts for collateral and delta liquidity.
   *
   * @param basePrice The price of the base asset.
   * @param short The address of the short contract.
   */
  function getLiquidity(uint basePrice, ICollateralShort short) public view override returns (Liquidity memory) {
    Liquidity memory liquidity;

    liquidity.usedDeltaLiquidity = poolHedger.getValueQuote(short, basePrice);
    liquidity.usedCollatLiquidity = lockedCollateral.quote.add(lockedCollateral.base.multiplyDecimal(basePrice));

    uint totalLiquidity = getTotalPoolValueQuote(basePrice, liquidity.usedDeltaLiquidity);

    uint collatPortion = (totalLiquidity * 2) / 3;
    uint deltaPortion = totalLiquidity.sub(collatPortion);

    if (liquidity.usedCollatLiquidity > collatPortion) {
      collatPortion = liquidity.usedCollatLiquidity;
      deltaPortion = totalLiquidity.sub(collatPortion);
    } else if (liquidity.usedDeltaLiquidity > deltaPortion) {
      deltaPortion = liquidity.usedDeltaLiquidity;
      collatPortion = totalLiquidity.sub(deltaPortion);
    }

    liquidity.freeDeltaLiquidity = deltaPortion.sub(liquidity.usedDeltaLiquidity);
    liquidity.freeCollatLiquidity = collatPortion.sub(liquidity.usedCollatLiquidity);

    return liquidity;
  }

  //////////
  // Misc //
  //////////

  /**
   * @notice Sends quoteAsset to the PoolHedger.
   * @dev This function will transfer whatever free delta liquidity is available.
   * The hedger must determine what to do with the amount received.
   *
   * @param exchangeGlobals The exchangeGlobals.
   * @param amount The amount requested by the PoolHedger.
   */
  function transferQuoteToHedge(ILyraGlobals.ExchangeGlobals memory exchangeGlobals, uint amount)
    external
    override
    onlyPoolHedger
    reentrancyGuard
    returns (uint)
  {
    Liquidity memory liquidity = getLiquidity(exchangeGlobals.spotPrice, exchangeGlobals.short);

    uint available = liquidity.freeDeltaLiquidity;
    if (available < amount) {
      amount = available;
    }
    _require(quoteAsset.transfer(address(poolHedger), amount), Error.QuoteTransferFailed);

    emit DeltaQuoteTransferredToPoolHedger(amount);

    return amount;
  }

  function _require(bool pass, Error error) internal view {
    require(pass, errorMessages[uint(error)]);
  }

  ///////////////
  // Modifiers //
  ///////////////

  modifier onlyPoolHedger virtual {
    _require(msg.sender == address(poolHedger), Error.OnlyPoolHedger);
    _;
  }

  modifier onlyOptionMarket virtual {
    _require(msg.sender == address(optionMarket), Error.OnlyOptionMarket);
    _;
  }

  modifier onlyShortCollateral virtual {
    _require(msg.sender == address(shortCollateral), Error.OnlyShortCollateral);
    _;
  }

  modifier reentrancyGuard virtual {
    counter = counter.add(1); // counter adds 1 to the existing 1 so becomes 2
    uint guard = counter; // assigns 2 to the "guard" variable
    _;
    _require(guard == counter, Error.ReentrancyDetected);
  }

  /**
   * @dev Emitted when liquidity is deposited.
   */
  event Deposit(address indexed beneficiary, uint indexed certificateId, uint amount);
  /**
   * @dev Emitted when withdrawal is signaled.
   */
  event WithdrawSignaled(uint indexed certificateId, uint tokensBurnableForRound);
  /**
   * @dev Emitted when a withdrawal is unsignaled.
   */
  event WithdrawUnSignaled(uint indexed certificateId, uint tokensBurnableForRound);
  /**
   * @dev Emitted when liquidity is withdrawn.
   */
  event Withdraw(address indexed beneficiary, uint indexed certificateId, uint value, uint totalQuoteAmountReserved);
  /**
   * @dev Emitted when a round ends.
   */
  event RoundEnded(
    uint indexed maxExpiryTimestamp,
    uint pricePerToken,
    uint totalQuoteAmountReserved,
    uint tokensBurnableForRound
  );
  /**
   * @dev Emitted when a round starts.
   */
  event RoundStarted(
    uint indexed lastMaxExpiryTimestamp,
    uint indexed newMaxExpiryTimestamp,
    uint totalTokenSupply,
    uint tokenValue
  );
  /**
   * @dev Emitted when quote is locked.
   */
  event QuoteLocked(uint quoteLocked, uint lockedCollateralQuote);
  /**
   * @dev Emitted when base is locked.
   */
  event BaseLocked(uint baseLocked, uint lockedCollateralBase);
  /**
   * @dev Emitted when quote is freed.
   */
  event QuoteFreed(uint quoteFreed, uint lockedCollateralQuote);
  /**
   * @dev Emitted when base is freed.
   */
  event BaseFreed(uint baseFreed, uint lockedCollateralBase);
  /**
   * @dev Emitted when base is purchased.
   */
  event BasePurchased(address indexed caller, uint quoteSpent, uint amountPurchased);
  /**
   * @dev Emitted when base is sold.
   */
  event BaseSold(address indexed caller, uint amountSold, uint quoteReceived);
  /**
   * @dev Emitted when collateral is liquidated. This combines LP profit from short calls and freeing base collateral
   */
  event CollateralLiquidated(
    uint totalAmountToLiquidate,
    uint baseFreed,
    uint quoteReceived,
    uint lockedCollateralBase
  );
  /**
   * @dev Emitted when quote is reserved.
   */
  event QuoteReserved(uint amountQuoteReserved, uint totalQuoteAmountReserved);
  /**
   * @dev Emitted when reserved quote is sent.
   */
  event ReservedQuoteSent(address indexed user, uint amount, uint totalQuoteAmountReserved);
  /**
   * @dev Emitted when collatQuote is transferred.
   */
  event CollateralQuoteTransferred(address indexed recipient, uint amount);
  /**
   * @dev Emitted when quote is transferred to hedge.
   */
  event DeltaQuoteTransferredToPoolHedger(uint amount);
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

interface ILiquidityCertificate {
  struct CertificateData {
    uint liquidity;
    uint enteredAt;
    uint burnableAt;
  }

  function MIN_LIQUIDITY() external view returns (uint);

  function liquidityPool() external view returns (address);

  function certificates(address owner) external view returns (uint[] memory);

  function liquidity(uint certificateId) external view returns (uint);

  function enteredAt(uint certificateId) external view returns (uint);

  function burnableAt(uint certificateId) external view returns (uint);

  function certificateData(uint certificateId) external view returns (CertificateData memory);

  function mint(
    address owner,
    uint liquidityAmount,
    uint expiryAtCreation
  ) external returns (uint);

  function setBurnableAt(
    address spender,
    uint certificateId,
    uint timestamp
  ) external;

  function burn(address spender, uint certificateId) external;

  function split(uint certificateId, uint percentageSplit) external returns (uint);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./ICollateralShort.sol";

interface IPoolHedger {
  function shortingInitialized() external view returns (bool);

  function shortId() external view returns (uint);

  function shortBuffer() external view returns (uint);

  function lastInteraction() external view returns (uint);

  function interactionDelay() external view returns (uint);

  function setShortBuffer(uint newShortBuffer) external;

  function setInteractionDelay(uint newInteractionDelay) external;

  function initShort() external;

  function reopenShort() external;

  function hedgeDelta() external;

  function getShortPosition(ICollateralShort short) external view returns (uint shortBalance, uint collateral);

  function getCurrentHedgedNetDelta() external view returns (int);

  function getValueQuote(ICollateralShort short, uint spotPrice) external view returns (uint value);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./IOptionMarket.sol";

interface IShortCollateral {
  function sendQuoteCollateral(address recipient, uint amount) external;

  function sendBaseCollateral(address recipient, uint amount) external;

  function sendToLP(uint amountBase, uint amountQuote) external;

  function processSettle(
    uint listingId,
    address receiver,
    IOptionMarket.TradeType tradeType,
    uint amount,
    uint strike,
    uint priceAtExpiry,
    uint listingToShortCallEthReturned
  ) external;
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