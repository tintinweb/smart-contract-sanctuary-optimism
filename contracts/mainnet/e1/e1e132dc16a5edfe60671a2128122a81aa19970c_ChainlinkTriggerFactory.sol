/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-09-09
*/

// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

/**
 * @dev Interface that all cost models must conform to.
 */
interface ICostModel {
  /// @notice Returns the cost of purchasing protection as a percentage of the amount being purchased, as a wad.
  /// For example, if you are purchasing $200 of protection and this method returns 1e17, then the cost of
  /// the purchase is 200 * 1e17 / 1e18 = $20.
  /// @param utilization Current utilization of the market.
  /// @param newUtilization Utilization ratio of the market after purchasing protection.
  function costFactor(uint256 utilization, uint256 newUtilization) external view returns (uint256);

  /// @notice Gives the return value in assets of returning protection, as a percentage of
  /// the supplier fee pool, as a wad. For example, if the supplier fee pool currently has $100
  /// and this method returns 1e17, then you will get $100 * 1e17 / 1e18 = $10 in assets back.
  /// @param utilization Current utilization of the market.
  /// @param newUtilization Utilization ratio of the market after cancelling protection.
  function refundFactor(uint256 utilization, uint256 newUtilization) external view returns (uint256);
}

/**
 * @dev Interface that all decay models must conform to.
 */
interface IDecayModel {
  /// @notice Returns current decay rate of PToken value, as percent per second, where the percent is a wad.
  /// @param utilization Current utilization of the market.
  function decayRate(uint256 utilization) external view returns (uint256);
}

/**
 * @dev Interface that all drip models must conform to.
 */
interface IDripModel {
  /// @notice Returns the percentage of the fee pool that should be dripped to suppliers, per second, as a wad.
  /// @dev The returned value is not equivalent to the annual yield earned by suppliers. Annual yield can be
  /// computed as supplierFeePool * dripRate * secondsPerYear / totalAssets.
  /// @param utilization Current utilization of the set.
  function dripRate(uint256 utilization) external view returns (uint256);
}

/**
 * @dev Structs used to define parameters in sets and markets.
 * @dev A "zoc" is a unit with 4 decimal places. All numbers in these config structs are in zocs, i.e. a
 * value of 900 translates to 900/10,000 = 0.09, or 9%.
 */
interface IConfig {
  /// @notice  Set-level configuration.
  struct SetConfig {
    uint256 leverageFactor; // The set's leverage factor.
    uint256 depositFee; // Fee applied on each deposit and mint.
    IDecayModel decayModel; // Contract defining the decay rate for PTokens in this set.
    IDripModel dripModel; // Contract defining the rate at which funds are dripped to suppliers for their yield.
  }

  /// @notice Market-level configuration.
  struct MarketInfo {
    address trigger; // Address of the trigger contract for this market.
    address costModel; // Contract defining the cost model for this market.
    uint16 weight; // Weight of this market. Sum of weights across all markets must sum to 100% (1e4, 1 zoc).
    uint16 purchaseFee; // Fee applied on each purchase.
  }

  /// @notice PTokens and are not eligible to claim protection until maturity. It takes `purchaseDelay` seconds for a PToken
  /// to mature, but time during an InactivePeriod is not counted towards maturity. Similarly, there is a delay
  /// between requesting a withdrawal and completing that withdrawal, and inactive periods do not count towards that
  /// withdrawal delay.
  struct InactivePeriod {
    uint64 startTime; // Timestamp that this inactive period began.
    uint64 cumulativeDuration; // Cumulative inactive duration of all prior inactive periods and this inactive period at the point when this inactive period ended.
  }
}

/**
 * @dev Contains the enum used to define valid Cozy states.
 * @dev All states except TRIGGERED are valid for sets, and all states except PAUSED are valid for markets/triggers.
 */
interface ICState {
  /// @notice The set of all Cozy states.
  enum CState {
    ACTIVE,
    FROZEN,
    PAUSED,
    TRIGGERED
  }
}

/**
 * @dev Interface for ERC20 tokens.
 */
interface IERC20 {
  /// @dev Emitted when the allowance of a `spender` for an `owner` is updated, where `amount` is the new allowance.
  event Approval(address indexed owner, address indexed spender, uint256 value);
  /// @dev Emitted when `amount` tokens are moved from `from` to `to`.
  event Transfer(address indexed from, address indexed to, uint256 value);

  /// @notice Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `holder`.
  function allowance(address owner, address spender) external view returns (uint256);
  /// @notice Sets `_amount` as the allowance of `_spender` over the caller's tokens.
  function approve(address spender, uint256 amount) external returns (bool);
  /// @notice Returns the amount of tokens owned by `account`.
  function balanceOf(address account) external view returns (uint256);
  /// @notice Returns the decimal places of the token.
  function decimals() external view returns (uint8);
  /// @notice Sets `_value` as the allowance of `_spender` over `_owner`s tokens, given a signed approval from the owner.
  function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
  /// @notice Returns the name of the token.
  function name() external view returns (string memory);
  /// @notice Returns the symbol of the token.
  function symbol() external view returns (string memory);
  /// @notice Returns the amount of tokens in existence.
  function totalSupply() external view returns (uint256);
  /// @notice Moves `_amount` tokens from the caller's account to `_to`.
  function transfer(address to, uint256 amount) external returns (bool);
  /// @notice Moves `_amount` tokens from `_from` to `_to` using the allowance mechanism. `_amount` is then deducted from the caller's allowance.
  function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @dev Interface for LFT tokens.
 */
interface ILFT is IERC20 {
  /// @notice Data saved off on each mint.
  struct MintMetadata {
    uint128 amount; // Amount of tokens minted.
    uint64 time; // Timestamp of the mint.
    uint64 delay; // Delay until these tokens mature and become fungible.
  }

  /// @notice Mapping from user address to all of their mints.
  function mints(address, uint256) view external returns (uint128 amount, uint64 time, uint64 delay);

  /// @notice Returns the array of metadata for all tokens minted to `_user`.
  function getMints(address _user) view external returns (MintMetadata[] memory);

  /// @notice Returns the quantity of matured tokens held by the given `_user`.
  /// @dev A user's `balanceOfMatured` is computed by starting with `balanceOf[_user]` then subtracting the sum of
  /// all `amounts` from the  user's `mints` array that are not yet matured. How to determine when a given mint
  /// is matured is left to the implementer. It can be simple such as maturing when `block.timestamp >= time + delay`,
  /// or something more complex.
  function balanceOfMatured(address _user) view external returns (uint256);

  /// @notice Moves `_amount` tokens from the caller's account to `_to`. Tokens must be matured to transfer them.
  function transfer(address _to, uint256 _amount) external returns (bool);

  /// @notice Moves `_amount` tokens from `_from` to `_to`. Tokens must be matured to transfer them.
  function transferFrom(address _from, address _to, uint256 _amount) external returns (bool);
}

/**
 * @notice All protection markets live within a set.
 */
interface ISet is ILFT {
  /// @dev Emitted when a user cancels protection. This is a market-level event.
  event Cancellation(
    address caller,
    address indexed receiver,
    address indexed owner,
    uint256 protection,
    uint256 ptokens,
    address indexed trigger,
    uint256 refund
  );

  /// @dev Emitted when a user claims their protection payout when a market is
  /// triggered. This is a market-level event
  event Claim(
    address caller,
    address indexed receiver,
    address indexed owner,
    uint256 protection,
    uint256 ptokens,
    address indexed trigger
  );

  /// @dev Emitted when a user deposits assets or mints shares. This is a
  /// set-level event.
  event Deposit(
    address indexed caller,
    address indexed owner,
    uint256 assets,
    uint256 shares
  );

  /// @dev Emitted when a user purchases protection from a market. This is a
  /// market-level event.
  event Purchase(
    address indexed caller,
    address indexed owner,
    uint256 protection,
    uint256 ptokens,
    address indexed trigger,
    uint256 cost
  );

  /// @dev Emitted when a user withdraws assets or redeems shares. This is a
  /// set-level event.
  event Withdraw(
    address caller,
    address indexed receiver,
    address indexed owner,
    uint256 assets,
    uint256 shares,
    uint256 indexed withdrawalId
  );

  /// @dev Emitted when a user queues a withdrawal or redeem to be completed
  /// later. This is a set-level event.
  event WithdrawalPending(
    address caller,
    address indexed receiver,
    address indexed owner,
    uint256 assets,
    uint256 shares,
    uint256 indexed withdrawalId
  );

  struct PendingWithdrawal {
    uint128 shares; // Shares burned to queue the withdrawal.
    uint128 assets; // Amount of assets that will be paid out upon completion of the withdrawal.
    address owner; // Owner of the shares.
    uint64 queueTime; // Timestamp at which the withdrawal was requested.
    address receiver; // Address the assets will be sent to.
    uint64 delay; // Protocol withdrawal delay at the time of request.
  }

  /// @notice Devalues all outstanding protection by applying unaccrued decay to the specified market.
  function accrueDecay(address _trigger) external;

  /// @notice Returns the amount of assets for the Cozy backstop.
  function accruedCozyBackstopFees() view external returns (uint128);

  /// @notice Returns the amount of assets for generic Cozy reserves.
  function accruedCozyReserveFees() view external returns (uint128);

  /// @notice Returns the amount of assets accrued to the set owner.
  function accruedSetOwnerFees() view external returns (uint128);

  /// @notice Returns the amount of outstanding protection that is currently active for the specified market.
  function activeProtection(address _trigger) view external returns (uint256);

  /// @notice Returns the underlying asset used by this set.
  function asset() view external returns (address);

  /// @notice Returns the internal asset balance - equivalent to `asset.balanceOf(address(set))` if no one transfers tokens directly to the contract.
  function assetBalance() view external returns (uint128);

  /// @notice Returns the amount of assets pending withdrawal. These assets are unavailable for new protection purchases but
  /// are available to payout protection in the event of a market becoming triggered.
  function assetsPendingWithdrawal() view external returns (uint128);

  /// @notice Returns the balance of matured tokens held by `_user`.
  function balanceOfMatured(address _user) view external returns (uint256 _balance);

  /// @notice Cancel `_protection` amount of protection for the specified market, and send the refund amount to `_receiver`.
  function cancel(address _trigger, uint256 _protection, address _receiver, address _owner) external returns (uint256 _refund, uint256 _ptokens);

  /// @notice Claims protection payout after the market for `_trigger` is triggered. Pays out the specified amount of
  /// `_protection` held by `_owner` by sending it to `_receiver`.
  function claim(address _trigger, uint256 _protection, address _receiver, address _owner) external returns (uint256 _ptokens);

  /// @notice Transfers accrued reserve and backstop fees to the `_owner` address and `_backstop` address, respectively.
  function claimCozyFees(address _owner, address _backstop) external;

  /// @notice Transfers accrued set owner fees to `_receiver`.
  function claimSetFees(address _receiver) external;

  /// @notice Completes the withdraw request for the specified ID, sending the assets to the stored `_receiver` address.
  function completeRedeem(uint256 _redemptionId) external;

  /// @notice Completes the withdraw request for the specified ID, and sends assets to the new `_receiver` instead of
  /// the stored receiver.
  function completeRedeem(uint256 _redemptionId, address _receiver) external;

  /// @notice Completes the withdraw request for the specified ID, sending the assets to the stored `_receiver` address.
  function completeWithdraw(uint256 _withdrawalId) external;

  /// @notice Completes the withdraw request for the specified ID, and sends assets to the new `_receiver` instead of
  /// the stored receiver.
  function completeWithdraw(uint256 _withdrawalId, address _receiver) external;

  /// @notice The amount of `_assets` that the Set would exchange for the amount of `_shares` provided, in an ideal
  /// scenario where all the conditions are met.
  function convertToAssets(uint256 shares) view external returns (uint256);

  /// @notice The amount of PTokens that the Vault would exchange for the amount of protection, in an ideal scenario
  /// where all the conditions are met.
  function convertToPTokens(address _trigger, uint256 _protection) view external returns (uint256);

  /// @notice The amount of protection that the Vault would exchange for the amount of PTokens, in an ideal scenario
  /// where all the conditions are met.
  function convertToProtection(address _trigger, uint256 _ptokens) view external returns (uint256);

  /// @notice The amount of `_shares` that the Set would exchange for the amount of `_assets` provided, in an ideal
  /// scenario where all the conditions are met.
  function convertToShares(uint256 assets) view external returns (uint256);

  /// @notice Returns the cost factor when purchasing the specified amount of `_protection` in the given market.
  function costFactor(address _trigger, uint256 _protection) view external returns (uint256 _costFactor);

  /// @notice Returns the current drip rate for the set.
  function currentDripRate() view external returns (uint256);

  /// @notice Returns the active protection, decay rate, and last decay time. The response is encoded into a word.
  function dataApd(address) view external returns (bytes32);

  /// @notice Returns the state and PToken address for a market, and the state for the set. The response is encoded into a word.
  function dataSp(address) view external returns (bytes32);

  /// @notice Returns the address of the set's decay model. The decay model governs how fast outstanding protection loses it's value.
  function decayModel() view external returns (address);

  /// @notice Supply protection by minting `_shares` shares to `_receiver` by depositing exactly `_assets` amount of
  /// underlying tokens.
  function deposit(uint256 _assets, address _receiver) external returns (uint256 _shares);

  /// @notice Returns the fee charged by the Set owner on deposits.
  function depositFee() view external returns (uint256);

  /// @notice Returns the market's reserve fee, backstop fee, and set owner fee applied on deposit.
  function depositFees() view external returns (uint256 _reserveFee, uint256 _backstopFee, uint256 _setOwnerFee);

  /// @notice Drip accrued fees to suppliers.
  function drip() external;

  /// @notice Returns the address of the set's drip model. The drip model governs the interest rate earned by depositors.
  function dripModel() view external returns (address);

  /// @notice Returns the array of metadata for all tokens minted to `_user`.
  function getMints(address _user) view external returns (MintMetadata[] memory);

  /// @notice Returns true if `_who` is a valid market in the `_set`, false otherwise.
  function isMarket(address _who) view external returns (bool);

  /// @notice Returns the drip rate used during the most recent `drip()`.
  function lastDripRate() view external returns (uint96);

  /// @notice Returns the timestamp of the most recent `drip()`.
  function lastDripTime() view external returns (uint32);

  /// @notice Returns the exchange rate of shares:assets when the most recent trigger occurred, or 0 if no market is triggered.
  /// This exchange rate is used for any pending withdrawals that were queued before the trigger occurred to calculate
  /// the new amount of assets to be received when the withdrawal is completed.
  function lastTriggeredExchangeRate() view external returns (uint192);

  /// @notice Returns the pending withdrawal count when the most recently triggered market became triggered, or 0 if none.
  /// Any pending withdrawals with IDs less than this need to have their amount of assets updated to reflect the exchange
  /// rate at the time when the most recently triggered market became triggered.
  function lastTriggeredPendingWithdrawalCount() view external returns (uint64);

  /// @notice Returns the leverage factor of the set, as a zoc.
  function leverageFactor() view external returns (uint256);

  /// @notice Returns the address of the Cozy protocol Manager.
  function manager() view external returns (address);

  /// @notice Returns the encoded market configuration, i.e. it's cost model, weight, and purchase fee for a market.
  function marketConfig(address) view external returns (bytes32);

  /// @notice Returns the maximum amount of the underlying asset that can be deposited to supply protection.
  function maxDeposit(address) view external returns (uint256);

  /// @notice Maximum amount of shares that can be minted to supply protection.
  function maxMint(address) view external returns (uint256);

  /// @notice Returns the maximum amount of protection that can be sold for the specified market.
  function maxProtection(address _trigger) view external returns (uint256);

  /// @notice Maximum amount of protection that can be purchased from the specified market.
  function maxPurchaseAmount(address _trigger) view external returns (uint256 _protection);

  /// @notice Maximum amount of Set shares that can be redeemed from the `_owner` balance in the Set,
  /// through a redeem call.
  function maxRedemptionRequest(address _owner) view external returns (uint256);

  /// @notice Maximum amount of the underlying asset that can be withdrawn from the `_owner` balance in the Set,
  /// through a withdraw call.
  function maxWithdrawalRequest(address _owner) view external returns (uint256);

  /// @notice Supply protection by minting exactly `_shares` shares to `_receiver` by depositing `_assets` amount
  /// of underlying tokens.
  function mint(uint256 _shares, address _receiver) external returns (uint256 _assets);

  /// @notice Mapping from user address to all of their mints.
  function mints(address, uint256) view external returns (uint128 amount, uint64 time, uint64 delay);

  /// @notice Returns the amount of decay that will accrue next time `accrueDecay()` is called for the market.
  function nextDecayAmount(address _trigger) view external returns (uint256 _accruedDecay);

  /// @notice Returns the amount to be dripped on the next `drip()` call.
  function nextDripAmount() view external returns (uint256);

  /// @notice Returns the number of frozen markets in the set.
  function numFrozenMarkets() view external returns (uint256);

  /// @notice Returns the number of markets in this Set, including triggered markets.
  function numMarkets() view external returns (uint256);

  /// @notice Returns the number of triggered markets in the set.
  function numTriggeredMarkets() view external returns (uint256);

  /// @notice Pauses the set.
  function pause() external;

  /// @notice Claims protection payout after the market for `_trigger` is triggered. Burns the specified number of
  /// `ptokens` held by `_owner` and sends the payout to `_receiver`.
  function payout(address _trigger, uint256 _ptokens, address _receiver, address _owner) external returns (uint256 _protection);

  /// @notice Returns the total number of withdrawals that have been queued, including pending withdrawals that have been completed.
  function pendingWithdrawalCount() view external returns (uint64);

  /// @notice Returns all withdrawal data for the specified withdrawal ID.
  function pendingWithdrawalData(uint256 _withdrawalId) view external returns (uint256 _remainingWithdrawalDelay, PendingWithdrawal memory _pendingWithdrawal);

  /// @notice Maps a withdrawal ID to information about the pending withdrawal.
  function pendingWithdrawals(uint256) view external returns (uint128 shares, uint128 assets, address owner, uint64 queueTime, address receiver, uint64 delay);

  /// @notice Allows an on-chain or off-chain user to simulate the effects of their cancellation (i.e. view the refund
  /// amount, number of PTokens burned, and associated fees collected by the protocol) at the current block, given
  /// current on-chain conditions.
  function previewCancellation(address _trigger, uint256 _protection) view external returns (uint256 _refund, uint256 _ptokens, uint256 _reserveFeeAssets, uint256 _backstopFeeAssets);

  /// @notice Returns the utilization ratio of the specified market after canceling `_assets` of protection.
  function previewCancellationUtilization(address _trigger, uint256 _assets) view external returns (uint256);

  /// @notice Allows an on-chain or off-chain user to simulate the effects of their claim (i.e. view the quantity of
  /// PTokens burned) at the current block, given current on-chain conditions.
  function previewClaim(address _trigger, uint256 _protection) view external returns (uint256 _ptokens);

  /// @notice Allows an on-chain or off-chain user to simulate the effects of their deposit (i.e. view the number of
  /// shares received) at the current block, given current on-chain conditions.
  function previewDeposit(uint256 _assets) view external returns (uint256 _shares);

  /// @notice Allows an on-chain or off-chain user to simulate the effects of their deposit (i.e. view the number of
  /// shares received along with associated fees) at the current block, given current on-chain conditions.
  function previewDepositData(uint256 _assets) view external returns (uint256 _userShares, uint256 _reserveFeeAssets, uint256 _backstopFeeAssets, uint256 _setOwnerFeeAssets);

  /// @notice Allows an on-chain or off-chain user to simulate the effects of their mint (i.e. view the number of
  /// assets transferred) at the current block, given current on-chain conditions.
  function previewMint(uint256 _shares) view external returns (uint256 _assets);

  /// @notice Allows an on-chain or off-chain user to simulate the effects of their mint (i.e. view the number of
  /// assets transferred along with associated fees) at the current block, given current on-chain conditions.
  function previewMintData(uint256 _shares) view external returns (uint256 _assets, uint256 _reserveFeeAssets, uint256 _backstopFeeAssets, uint256 _setOwnerFeeAssets);

  /// @notice Allows an on-chain or off-chain user to simulate the effects of their payout (i.e. view the amount of
  /// assets that would be received for an amount of PTokens) at the current block, given current on-chain conditions.
  function previewPayout(address _trigger, uint256 _ptokens) view external returns (uint256 _protection);

  /// @notice Allows an on-chain or off-chain user to simulate the effects of their purchase (i.e. view the total cost,
  /// inclusive of fees, and the number of PTokens received) at the current block, given current on-chain conditions.
  function previewPurchase(address _trigger, uint256 _protection) view external returns (uint256 _totalCost, uint256 _ptokens);

  /// @notice Allows an on-chain or off-chain user to comprehensively simulate the effects of their purchase at the
  /// current block, given current on-chain conditions. This is similar to `previewPurchase` but additionally returns
  /// the cost before fees, as well as the fee breakdown.
  function previewPurchaseData(address _trigger, uint256 _protection) view external returns (uint256 _totalCost, uint256 _ptokens, uint256 _cost, uint256 _reserveFeeAssets, uint256 _backstopFeeAssets, uint256 _setOwnerFeeAssets);

  /// @notice Returns the utilization ratio of the specified market after purchasing `_assets` of protection.
  function previewPurchaseUtilization(address _trigger, uint256 _assets) view external returns (uint256);

  /// @notice Allows an on-chain or off-chain user to simulate the effects of their redemption (i.e. view the number
  /// of assets received) at the current block, given current on-chain conditions.
  function previewRedeem(uint256 shares) view external returns (uint256);

  /// @notice Allows an on-chain or off-chain user to simulate the effects of their sale (i.e. view the refund amount,
  /// protection sold, and fees accrued by the protocol) at the current block, given current on-chain conditions.
  function previewSale(address _trigger, uint256 _ptokens) view external returns (uint256 _refund, uint256 _protection, uint256 _reserveFeeAssets, uint256 _backstopFeeAssets);

  /// @notice Allows an on-chain or off-chain user to simulate the effects of their withdrawal (i.e. view the number of
  /// shares burned) at the current block, given current on-chain conditions.
  function previewWithdraw(uint256 assets) view external returns (uint256);

  /// @notice Return the PToken address for the given market.
  function ptoken(address _who) view external returns (address _ptoken);

  /// @notice Returns the address of the Cozy protocol PTokenFactory.
  function ptokenFactory() view external returns (address);

  /// @notice Purchase `_protection` amount of protection for the specified market, and send the PTokens to `_receiver`.
  function purchase(address _trigger, uint256 _protection, address _receiver) external returns (uint256 _totalCost, uint256 _ptokens);

  /// @notice Returns the market's reserve fee, backstop fee, and set owner fee applied on purchase.
  function purchaseFees(address _trigger) view external returns (uint256 _reserveFee, uint256 _backstopFee, uint256 _setOwnerFee);

  /// @notice Burns exactly `_shares` from owner and queues `_assets` amount of underlying tokens to be sent to
  /// `_receiver` after the `manager.withdrawDelay()` has elapsed.
  function redeem(uint256 _shares, address _receiver, address _owner) external returns (uint256 _assets);

  /// @notice Returns the refund factor when canceling the specified amount of `_protection` in the given market.
  function refundFactor(address _trigger, uint256 _protection) view external returns (uint256 _refundFactor);

  /// @notice Returns the amount of protection currently available to purchase for the specified market.
  function remainingProtection(address _trigger) view external returns (uint256);

  /// @notice Sell `_ptokens` amount of ptokens for the specified market, and send the refund amount to `_receiver`.
  function sell(address _trigger, uint256 _ptokens, address _receiver, address _owner) external returns (uint256 _refund, uint256 _protection);

  /// @notice Returns the shortfall (i.e. the amount of unbacked active protection) in a market, or zero if the market
  /// is fully backed.
  function shortfall(address _trigger) view external returns (uint256);

  /// @notice Returns the state of the market or set. Pass a market address to read that market's state, or the set's
  /// address to read the set's state.
  function state(address _who) view external returns (uint8 _state);

  /// @notice Returns the set's total amount of fees available to drip to suppliers, and each market's contribution to that total amount.
  /// When protection is purchased, the supplier fee pools for the set and the market that protection is purchased from
  /// gets incremented by the protection cost (after fees). They get decremented when fees are dripped to suppliers.
  function supplierFeePool(address) view external returns (uint256);

  /// @notice Syncs the internal accounting balance with the true balance.
  function sync() external;

  /// @notice Returns the total amount of assets that is available to back protection.
  function totalAssets() view external returns (uint256 _protectableAssets);

  /// @notice Array of trigger addresses used for markets in the set.
  function triggers(uint256) view external returns (address);

  /// @notice Unpauses the set and transitions to the provided `_state`.
  function unpause(uint8 _state) external;

  /// @notice Execute queued updates to setConfig and marketConfig. This should only be called by the Manager.
  function updateConfigs(uint256 _leverageFactor, uint256 _depositFee, address _decayModel, address _dripModel, IConfig.MarketInfo[] memory _marketInfos) external;

  /// @notice Updates the state of the a market in the set.
  function updateMarketState(address _trigger, uint8 _newState) external;

  /// @notice Updates the set's state to `_state.
  function updateSetState(uint8 _state) external;

  /// @notice Returns the current utilization ratio of the specified market, as a wad.
  function utilization(address _trigger) view external returns (uint256);

  /// @notice Returns the current utilization ratio of the set, as a wad.
  function utilization() view external returns (uint256);

  /// @notice Burns `_shares` from owner and queues exactly `_assets` amount of underlying tokens to be sent to
  /// `_receiver` after the `manager.withdrawDelay()` has elapsed.
  function withdraw(uint256 _assets, address _receiver, address _owner) external returns (uint256 _shares);

  /// Additional functions from the ABI.
  function DOMAIN_SEPARATOR() view external returns (bytes32);
  function VERSION() view external returns (uint256);
  function allowance(address, address) view external returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function balanceOf(address) view external returns (uint256);
  function decimals() view external returns (uint8);
  function name() view external returns (string memory);
  function nonces(address) view external returns (uint256);
  function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
  function symbol() view external returns (string memory);
  function totalSupply() view external returns (uint256);
  function transfer(address _to, uint256 _amount) external returns (bool);
  function transferFrom(address _from, address _to, uint256 _amount) external returns (bool);
}

/**
 * @notice The Manager is in charge of the full Cozy protocol. Configuration parameters are defined here, it serves
 * as the entry point for all privileged operations, and exposes the `createSet` method used to create new sets.
 */
interface IManager is ICState, IConfig {
  /// @dev Emitted when a new set is given permission to pull funds from the backstop if it has a shortfall after a trigger.
  event BackstopApprovalStatusUpdated(address indexed set, bool status);

  /// @dev Emitted when the Cozy configuration delays are updated, and when a set is created.
  event ConfigParamsUpdated(uint256 configUpdateDelay, uint256 configUpdateGracePeriod);

  /// @dev Emitted when a Set owner's queued set and market configuration updates are applied, and when a set is created.
  event ConfigUpdatesFinalized(address indexed set, SetConfig setConfig, MarketInfo[] marketInfos);

  /// @dev Emitted when a Set owner queues new set and/or market configurations.
  event ConfigUpdatesQueued(address indexed set, SetConfig setConfig, MarketInfo[] marketInfos, uint256 updateTime, uint256 updateDeadline);

  /// @dev Emitted when accrued Cozy reserve fees and backstop fees are swept from a Set to the Cozy owner (for reserves) and backstop.
  event CozyFeesClaimed(address indexed set);

  /// @dev Emitted when the delays affecting user actions are initialized or updated by the Cozy owner.
  event DelaysUpdated(uint256 minDepositDuration, uint256 withdrawDelay, uint256 purchaseDelay);

  /// @dev Emitted when the deposit cap for an asset is updated by the Cozy owner.
  event DepositCapUpdated(IERC20 indexed asset, uint256 depositCap);

  /// @dev Emitted when the Cozy protocol fees are updated by the Cozy owner.
  /// Changes to fees for the Set owner are emitted in ConfigUpdatesQueued and ConfigUpdatesFinalized.
  event FeesUpdated(Fees fees);

  /// @dev Emitted when a market, defined by it's trigger address, changes state.
  event MarketStateUpdated(address indexed set, address indexed trigger, CState indexed state);

  /// @dev Emitted when the owner address is updated.
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /// @dev Emitted when the pauser address is updated.
  event PauserUpdated(address indexed newPauser);

  /// @dev Emitted when the owner of a set is updated.
  event SetOwnerUpdated(address indexed set, address indexed owner);

  /// @dev Emitted when the Set owner claims their portion of fees.
  event SetFeesClaimed(address indexed set, address _receiver);

  /// @dev Emitted when the Set's pauser is updated.
  event SetPauserUpdated(address indexed set, address indexed pauser);

  /// @dev Emitted when the Set's state is updated.
  event SetStateUpdated(address indexed set, CState indexed state);

  /// @notice Used to update backstop approvals.
  struct BackstopApproval {
    ISet set;
    bool status;
  }

  /// @notice All delays that can be set by the Cozy owner.
  struct Delays {
    uint256 configUpdateDelay; // Duration between when a set/market configuration updates are queued and when they can be executed.
    uint256 configUpdateGracePeriod; // Defines how long the owner has to execute a configuration change, once it can be executed.
    uint256 minDepositDuration; // The minimum duration before a withdrawal can be initiated after a deposit.
    uint256 withdrawDelay; // If not paused, suppliers must queue a withdrawal and wait this long before completing the withdrawal.
    uint256 purchaseDelay; // Protection does not mature (i.e. it cannot claim funds from a trigger) until this delay elapses after purchase.
  }

  /// @notice All fees that can be set by the Cozy owner.
  struct Fees {
    uint16 depositFeeReserves;  // Fee charged on deposit and min, allocated to the protocol reserves, denoted in zoc.
    uint16 depositFeeBackstop; // Fee charged on deposit and min, allocated to the protocol backstop, denoted in zoc.
    uint16 purchaseFeeReserves; // Fee charged on purchase, allocated to the protocol reserves, denoted in zoc.
    uint16 purchaseFeeBackstop; // Fee charged on purchase, allocated to the protocol backstop, denoted in zoc.
    uint16 cancellationFeeReserves; // Fee charged on cancellation, allocated to the protocol reserves, denoted in zoc.
    uint16 cancellationFeeBackstop; // Fee charged on cancellation, allocated to the protocol backstop, denoted in zoc.
  }

  /// @notice A market or set is considered inactive when it's FROZEN or PAUSED.
  struct InactivityData {
    uint64 inactiveTransitionTime; // The timestamp the set/market transitioned from active to inactive, if currently inactive. 0 otherwise.
    InactivePeriod[] periods; // Array of all inactive periods for a set or market.
  }

  /// @notice Set related data.
  struct SetData {
    // When a set is created, this is updated to true.
    bool exists;
     // If true, this set can use funds from the backstop.
    bool approved;
    // Earliest timestamp at which finalizeUpdateConfigs can be called to apply config updates queued by updateConfigs.
    uint64 configUpdateTime;
    // Maps from set address to the latest timestamp after configUpdateTime at which finalizeUpdateConfigs can be
    // called to apply config updates queued by updateConfigs. After this timestamp, the queued config updates
    // expire and can no longer be applied.
    uint64 configUpdateDeadline;
  }

  /// @notice Max fee for deposit and purchase.
  function MAX_FEE() view external returns (uint256);

  /// @notice Returns the address of the Cozy protocol Backstop.
  function backstop() view external returns (address);

  /// @notice Returns the fees applied on cancellations that go to Cozy protocol reserves and backstop.
  function cancellationFees() view external returns (uint256 _reserveFee, uint256 _backstopFee);

  /// @notice For all specified `_sets`, transfers accrued reserve and backstop fees to the owner address and
  /// backstop address, respectively.
  function claimCozyFees(ISet[] memory _sets) external;

  /// @notice Callable by the owner of `_set` and sends accrued fees to `_receiver`.
  function claimSetFees(ISet _set, address _receiver) external;

  /// @notice Configuration updates are queued, then can be applied after this delay elapses.
  function configUpdateDelay() view external returns (uint32);

  /// @notice Once `configUpdateDelay` elapses, configuration updates must be applied before the grace period elapses.
  function configUpdateGracePeriod() view external returns (uint32);

  /// @notice Deploys a new set with the provided parameters.
  function createSet(address _owner, address _pauser, address _asset, SetConfig memory _setConfig, MarketInfo[] memory _marketInfos, bytes32 _salt) external returns (ISet _set);

  /// @notice Returns the fees applied on deposits that go to Cozy protocol reserves and backstop.
  function depositFees() view external returns (uint256 _reserveFee, uint256 _backstopFee);

  /// @notice Returns protocol fees that can be applied on deposit/mint, purchase, and cancellation.
  function fees() view external returns (uint16 depositFeeReserves, uint16 depositFeeBackstop, uint16 purchaseFeeReserves, uint16 purchaseFeeBackstop, uint16 cancellationFeeReserves, uint16 cancellationFeeBackstop);

  /// @notice Execute queued updates to set config and market configs.
  function finalizeUpdateConfigs(ISet _set, SetConfig memory _setConfig, MarketInfo[] memory _marketInfos) external;

  /// @notice Returns the amount of delay time that has accrued since a timestamp.
  function getDelayTimeAccrued(uint256 _startTime, uint256 _currentInactiveDuration, InactivePeriod[] memory _inactivePeriods) view external returns (uint256);

  /// @notice Returns the maximum amount of assets that can be deposited into a set that uses `_asset`.
  function getDepositCap(address _asset) view external returns (uint256);

  /// @notice Returns the stored inactivity data for the specified `_set` and `_trigger`.
  function getMarketInactivityData(ISet _set, address _trigger) view external returns (InactivityData memory);

  /// @notice Returns the amount of time that accrued towards the withdrawal delay for the `_set`, given the
  /// `_startTime` and the `_setState`.
  function getWithdrawDelayTimeAccrued(ISet _set, uint256 _startTime, uint8 _setState) view external returns (uint256 _activeTimeElapsed);

  /// @notice Performs a binary search to return the cumulative inactive duration before a `_timestamp` based on
  /// the given `_inactivePeriods` that occurred.
  function inactiveDurationBeforeTimestampLookup(uint256 _timestamp, InactivePeriod[] memory _inactivePeriods) pure external returns (uint256);

  /// @notice Returns true if there is at least one FROZEN market in the `_set`, false otherwise.
  function isAnyMarketFrozen(ISet _set) view external returns (bool);

  /// @notice Returns true if the specified `_set` is approved for the backstop, false otherwise.
  function isApprovedForBackstop(ISet _set) view external returns (bool);

  /// @notice Returns true if `_who` is the local owner for the specified `_set`, false otherwise.
  function isLocalSetOwner(ISet _set, address _who) view external returns (bool);

  /// @notice Returns true if `_who` is a valid market in the `_set`, false otherwise.
  function isMarket(ISet _set, address _who) view external returns (bool);

  /// @notice Returns true if `_who` is the Cozy owner or the local owner for the specified `_set`, false otherwise.
  function isOwner(ISet _set, address _who) view external returns (bool);

  /// @notice Returns true if `_who` is the Cozy owner/pauser or the local owner/pauser for the specified `_set`,
  /// false otherwise.
  function isOwnerOrPauser(ISet _set, address _who) view external returns (bool);

  /// @notice Returns true if `_who` is the Cozy pauser or the local pauser for the specified `_set`, false otherwise.
  function isPauser(ISet _set, address _who) view external returns (bool);

  /// @notice Returns true if the provided `_setConfig` and `_marketInfos` pairing is generically valid, false otherwise.
  function isValidConfiguration(SetConfig memory _setConfig, MarketInfo[] memory _marketInfos) pure external returns (bool);

  /// @notice Check if a state transition is valid for a market in a set.
  function isValidMarketStateTransition(ISet _set, address _who, uint8 _from, uint8 _to) view external returns (bool);

  /// @notice Returns true if the state transition from `_from` to `_to` is valid for the given `_set` when called
  /// by `_who`, false otherwise.
  function isValidSetStateTransition(ISet _set, address _who, uint8 _from, uint8 _to) view external returns (bool);

  /// @notice Returns true if the provided `_setConfig` and `_marketInfos` pairing is valid for the `_set`,
  /// false otherwise.
  function isValidUpdate(ISet _set, SetConfig memory _setConfig, MarketInfo[] memory _marketInfos) view external returns (bool);

  /// @notice Maps from set address to trigger address to metadata about previous inactive periods for markets.
  function marketInactivityData(address, address) view external returns (uint64 inactiveTransitionTime);

  /// @notice Minimum duration that funds must be supplied for before initiating a withdraw.
  function minDepositDuration() view external returns (uint32);

  /// @notice Returns the Manager contract owner address.
  function owner() view external returns (address);

  /// @notice Pauses the set.
  function pause(ISet _set) external;

  /// @notice Returns the manager Contract pauser address.
  function pauser() view external returns (address);

  /// @notice Returns the address of the Cozy protocol PTokenFactory.
  function ptokenFactory() view external returns (address);

  /// @notice Duration that must elapse before purchased protection becomes active.
  function purchaseDelay() view external returns (uint32);

  /// @notice Returns the fees applied on purchases that go to Cozy protocol reserves and backstop.
  function purchaseFees() view external returns (uint256 _reserveFee, uint256 _backstopFee);

  /// @notice Maps from set address to a hash representing queued `SetConfig` and `MarketInfo[]` updates. This hash
  /// is used to prove that the `SetConfig` and `MarketInfo[]` params used when applying config updates are identical
  /// to the queued updates.
  function queuedConfigUpdateHash(address) view external returns (bytes32);

  /// @notice Returns the Cozy protocol SetFactory.
  function setFactory() view external returns (address);

  /// @notice Returns metadata about previous inactive periods for sets.
  function setInactivityData(address) view external returns (uint64 inactiveTransitionTime);

  /// @notice Returns the owner address for the given set.
  function setOwner(address) view external returns (address);

  /// @notice Returns the pauser address for the given set.
  function setPauser(address) view external returns (address);

  /// @notice For the specified set, returns whether it's a valid Cozy set, if it's approve to use the backstop,
  /// as well as timestamps for any configuration updates that are queued.
  function sets(ISet) view external returns (bool exists, bool approved, uint64 configUpdateTime, uint64 configUpdateDeadline);

  /// @notice Unpauses the set.
  function unpause(ISet _set) external;

  /// @notice Update params related to config updates.
  function updateConfigParams(uint256 _configUpdateDelay, uint256 _configUpdateGracePeriod) external;

  /// @notice Signal an update to the set config and market configs. Existing queued updates are overwritten.
  function updateConfigs(ISet _set, SetConfig memory _setConfig, MarketInfo[] memory _marketInfos) external;

  /// @notice Called by a trigger when it's state changes to `_newMarketState` to execute the corresponding state
  /// change in the market for the given `_set`.
  function updateMarketState(ISet _set, CState _newMarketState) external;

  /// @notice Updates the owner of `_set` to `_owner`.
  function updateSetOwner(ISet _set, address _owner) external;

  /// @notice Updates the pauser of `_set` to `_pauser`.
  function updateSetPauser(ISet _set, address _pauser) external;

  /// @notice Returns true if the provided `_fees` are valid, false otherwise.
  function validateFees(Fees memory _fees) pure external returns (bool);

  /// @notice Duration that must elapse before completing a withdrawal after initiating it.
  function withdrawDelay() view external returns (uint32);

  function VERSION() view external returns (uint256);
  function updateDepositCap(address _asset, uint256 _newDepositCap) external;
  function updateFees(Fees memory _fees) external;
  function updateOwner(address _newOwner) external;
  function updatePauser(address _newPauser) external;
  function updateUserDelays(uint256 _minDepositDuration, uint256 _withdrawDelay, uint256 _purchaseDelay) external;
}

/**
 * @notice A trigger contract that takes two addresses: a truth oracle and a tracking oracle.
 * This trigger ensures the two oracles always stay within the given price tolerance; the delta
 * in prices can be equal to but not greater than the price tolerance.
 */
interface IChainlinkTrigger is ICState {
  /// @dev Emitted when a new set is added to the trigger's list of sets.
  event SetAdded(ISet set);

  /// @dev Emitted when a trigger's state is updated.
  event TriggerStateUpdated(CState indexed state);

  /// @notice The canonical oracle, assumed to be correct.
  function truthOracle() view external returns (AggregatorV3Interface);

  /// @notice The oracle we expect to diverge.
  function trackingOracle() view external returns (AggregatorV3Interface);

  /// @notice The current trigger state. This should never return PAUSED.
  function state() external returns(CState);

  /// @notice Called by the Manager to add a newly created set to the trigger's list of sets.
  function addSet(ISet set) external;

  /// @notice Returns the set address at the specified index in the trigger's list of sets.
  function sets(uint256) view external returns (address);

  /// @notice Returns all sets in the trigger's list of sets.
  function getSets() view external returns (address[] memory);

  /// @notice Returns the number of Sets that use this trigger in a market.
  function getSetsLength() view external returns (uint256);

  /// @notice Returns the trigger's manager contract.
  function manager() view external returns (IManager);

  /// @notice The maximum amount of sets that can be added to this trigger.
  function MAX_SET_LENGTH() view external returns (uint256);

  /// @notice The maximum percent delta between oracle prices that is allowed, expressed as a zoc.
  /// For example, a 0.2e4 priceTolerance would mean the trackingOracle price is
  /// allowed to deviate from the truthOracle price by up to +/- 20%, but no more.
  /// Note that if the truthOracle returns a price of 0, we treat the priceTolerance
  /// as having been exceeded, no matter what price the trackingOracle returns.
  function priceTolerance() view external returns (uint256);

  /// @notice The maximum amount of time we allow to elapse before the truth oracle's price is deemed stale.
  function truthFrequencyTolerance() view external returns (uint256);

  /// @notice The maximum amount of time we allow to elapse before the tracking oracle's price is deemed stale.
  function trackingFrequencyTolerance() view external returns (uint256);

  /// @notice Compares the oracle's price to the reference oracle and toggles the trigger if required.
  /// @dev This method executes the `programmaticCheck()` and makes the
  /// required state changes both in the trigger and the sets.
  function runProgrammaticCheck() external returns (CState);

  /// @notice Returns true if the trigger has been acknowledged by the entity responsible for transitioning trigger state.
  /// @notice Chainlink triggers are programmatic, so this always returns true.
  function acknowledged() external pure returns (bool);
}

/**
 * @notice Deploys Chainlink triggers that ensure two oracles stay within the given price
 * tolerance. It also supports creating a fixed price oracle to use as the truth oracle, useful
 * for e.g. ensuring stablecoins maintain their peg.
 */
interface IChainlinkTriggerFactory {
  struct TriggerMetadata {
    // The name that should be used for markets that use the trigger.
    string name;
    // A human-readable description of the trigger.
    string description;
    // The URI of a logo image to represent the trigger.
    string logoURI;
  }

  /// @dev Emitted when the factory deploys a trigger.
  /// @param trigger Address at which the trigger was deployed.
  /// @param triggerConfigId Unique identifier of the trigger based on its configuration.
  /// @param truthOracle The address of the desired truthOracle for the trigger.
  /// @param trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param priceTolerance The priceTolerance that the deployed trigger will have. See
  /// `ChainlinkTrigger.priceTolerance()` for more information.
  /// @param truthFrequencyTolerance The frequencyTolerance that the deployed trigger will have for the truth oracle. See
  /// `ChainlinkTrigger.truthFrequencyTolerance()` for more information.
  /// @param trackingFrequencyTolerance The frequencyTolerance that the deployed trigger will have for the tracking oracle. See
  /// `ChainlinkTrigger.trackingFrequencyTolerance()` for more information.
  /// @param name The name that should be used for markets that use the trigger.
  /// @param description A human-readable description of the trigger.
  /// @param logoURI The URI of a logo image to represent the trigger.
  /// For other attributes, see the docs for the params of `deployTrigger` in
  /// this contract.
  event TriggerDeployed(
    address trigger,
    bytes32 indexed triggerConfigId,
    address indexed truthOracle,
    address indexed trackingOracle,
    uint256 priceTolerance,
    uint256 truthFrequencyTolerance,
    uint256 trackingFrequencyTolerance,
    string name,
    string description,
    string logoURI
  );

  /// @notice The manager of the Cozy protocol.
  function manager() view external returns (IManager);

  /// @notice Maps the triggerConfigId to the number of triggers created with those configs.
  function triggerCount(bytes32) view external returns (uint256);

  /// @notice Call this function to deploy a ChainlinkTrigger.
  /// @param _truthOracle The address of the desired truthOracle for the trigger.
  /// @param _trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param _priceTolerance The priceTolerance that the deployed trigger will
  /// have. See ChainlinkTrigger.priceTolerance() for more information.
  /// @param _truthFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the truth oracle. See ChainlinkTrigger.truthFrequencyTolerance() for more information.
  /// @param _trackingFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the tracking oracle. See ChainlinkTrigger.trackingFrequencyTolerance() for more information.
  function deployTrigger(
    AggregatorV3Interface _truthOracle,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance,
    TriggerMetadata memory _metadata
  ) external returns (IChainlinkTrigger _trigger);

  /// @notice Call this function to deploy a ChainlinkTrigger with a
  /// FixedPriceAggregator as its truthOracle. This is useful if you were
  /// building a market in which you wanted to track whether or not a stablecoin
  /// asset had become depegged.
  /// @param _price The fixed price, or peg, with which to compare the trackingOracle price.
  /// @param _decimals The number of decimals of the fixed price. This should
  /// match the number of decimals used by the desired _trackingOracle.
  /// @param _trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param _priceTolerance The priceTolerance that the deployed trigger will
  /// have. See ChainlinkTrigger.priceTolerance() for more information.
  /// @param _frequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the tracking oracle. See ChainlinkTrigger.trackingFrequencyTolerance() for more information.
  function deployTrigger(
    int256 _price,
    uint8 _decimals,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _frequencyTolerance,
    TriggerMetadata memory _metadata
  ) external returns (IChainlinkTrigger _trigger);

  /// @notice Call this function to determine the address at which a trigger
  /// with the supplied configuration would be deployed.
  /// @param _truthOracle The address of the desired truthOracle for the trigger.
  /// @param _trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param _priceTolerance The priceTolerance that the deployed trigger would
  /// have. See ChainlinkTrigger.priceTolerance() for more information.
  /// @param _truthFrequencyTolerance The frequency tolerance that the deployed trigger would
  /// have for the truth oracle. See ChainlinkTrigger.truthFrequencyTolerance() for more information.
  /// @param _trackingFrequencyTolerance The frequency tolerance that the deployed trigger would
  /// have for the tracking oracle. See ChainlinkTrigger.trackingFrequencyTolerance() for more information.
  /// @param _triggerCount The zero-indexed ordinal of the trigger with respect to its
  /// configuration, e.g. if this were to be the fifth trigger deployed with
  /// these configs, then _triggerCount should be 4.
  function computeTriggerAddress(
    AggregatorV3Interface _truthOracle,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance,
    uint256 _triggerCount
  ) view external returns (address _address);

  /// @notice Call this function to find triggers with the specified
  /// configurations that can be used for new markets in Sets.
  /// @dev If this function returns the zero address, that means that an
  /// available trigger was not found with the supplied configuration. Use
  /// `deployTrigger` to deploy a new one.
  /// @param _truthOracle The address of the desired truthOracle for the trigger.
  /// @param _trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param _priceTolerance The priceTolerance that the deployed trigger will
  /// have. See ChainlinkTrigger.priceTolerance() for more information.
  /// @param _truthFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the truth oracle. See ChainlinkTrigger.truthFrequencyTolerance() for more information.
  /// @param _trackingFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the tracking oracle. See ChainlinkTrigger.trackingFrequencyTolerance() for more information.
  function findAvailableTrigger(
    AggregatorV3Interface _truthOracle,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) view external returns (address);

  /// @notice Call this function to determine the identifier of the supplied trigger
  /// configuration. This identifier is used both to track the number of
  /// triggers deployed with this configuration (see `triggerCount`) and is
  /// emitted at the time triggers with that configuration are deployed.
  /// @param _truthOracle The address of the desired truthOracle for the trigger.
  /// @param _trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param _priceTolerance The priceTolerance that the deployed trigger will
  /// have. See ChainlinkTrigger.priceTolerance() for more information.
  /// @param _truthFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the truth oracle. See ChainlinkTrigger.truthFrequencyTolerance() for more information.
  /// @param _trackingFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the tracking oracle. See ChainlinkTrigger.trackingFrequencyTolerance() for more information.
  function triggerConfigId(
    AggregatorV3Interface _truthOracle,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) view external returns (bytes32);

  /// @notice Call this function to deploy a FixedPriceAggregator contract,
  /// which behaves like a Chainlink oracle except that it always returns the
  /// same price.
  /// @dev If the specified contract is already deployed, we return it's address
  /// instead of reverting to avoid duplicate aggregators
  /// @param _price The fixed price, in the decimals indicated, returned by the deployed oracle.
  /// @param _decimals The number of decimals of the fixed price.
  function deployFixedPriceAggregator(int256 _price, uint8 _decimals) external returns (AggregatorV3Interface);

  /// @notice Call this function to compute the address that a
  /// FixedPriceAggregator contract would be deployed to with the provided args.
  /// @param _price The fixed price, in the decimals indicated, returned by the deployed oracle.
  /// @param _decimals The number of decimals of the fixed price.
  function computeFixedPriceAggregatorAddress(int256 _price, uint8 _decimals) view external returns (address);
}

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
    }

    /*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

            // Divide z by the denominator.
            z := div(z, denominator)
        }
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

            // First, divide z - 1 by the denominator and add 1.
            // We allow z - 1 to underflow if z is 0, because we multiply the
            // end result by 0 if z is zero, ensuring we return 0 if z is zero.
            z := mul(iszero(iszero(z)), add(div(sub(z, 1), denominator), 1))
        }
    }

    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := scalar
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store scalar in z for now.
                    z := scalar
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, scalar)

                for {
                    // Shift n right by 1 before looping to halve it.
                    n := shr(1, n)
                } n {
                    // Shift n right by 1 each iteration to halve it.
                    n := shr(1, n)
                } {
                    // Revert immediately if x ** 2 would overflow.
                    // Equivalent to iszero(eq(div(xx, x), x)) here.
                    if shr(128, x) {
                        revert(0, 0)
                    }

                    // Store x squared.
                    let xx := mul(x, x)

                    // Round to the nearest number.
                    let xxRound := add(xx, half)

                    // Revert if xx + half overflowed.
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }

                    // Set x to scaled xxRound.
                    x := div(xxRound, scalar)

                    // If n is even:
                    if mod(n, 2) {
                        // Compute z * x.
                        let zx := mul(z, x)

                        // If z * x overflowed:
                        if iszero(eq(div(zx, x), z)) {
                            // Revert if x is non-zero.
                            if iszero(iszero(x)) {
                                revert(0, 0)
                            }
                        }

                        // Round to the nearest number.
                        let zxRound := add(zx, half)

                        // Revert if zx + half overflowed.
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }

                        // Return properly scaled zxRound.
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            // Start off with z at 1.
            z := 1

            // Used below to help find a nearby power of 2.
            let y := x

            // Find the lowest power of 2 that is at least sqrt(x).
            if iszero(lt(y, 0x100000000000000000000000000000000)) {
                y := shr(128, y) // Like dividing by 2 ** 128.
                z := shl(64, z) // Like multiplying by 2 ** 64.
            }
            if iszero(lt(y, 0x10000000000000000)) {
                y := shr(64, y) // Like dividing by 2 ** 64.
                z := shl(32, z) // Like multiplying by 2 ** 32.
            }
            if iszero(lt(y, 0x100000000)) {
                y := shr(32, y) // Like dividing by 2 ** 32.
                z := shl(16, z) // Like multiplying by 2 ** 16.
            }
            if iszero(lt(y, 0x10000)) {
                y := shr(16, y) // Like dividing by 2 ** 16.
                z := shl(8, z) // Like multiplying by 2 ** 8.
            }
            if iszero(lt(y, 0x100)) {
                y := shr(8, y) // Like dividing by 2 ** 8.
                z := shl(4, z) // Like multiplying by 2 ** 4.
            }
            if iszero(lt(y, 0x10)) {
                y := shr(4, y) // Like dividing by 2 ** 4.
                z := shl(2, z) // Like multiplying by 2 ** 2.
            }
            if iszero(lt(y, 0x8)) {
                // Equivalent to 2 ** z.
                z := shl(1, z)
            }

            // Shifting right by 1 is like dividing by 2.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // Compute a rounded down version of z.
            let zRoundDown := div(x, z)

            // If zRoundDown is smaller, use it.
            if lt(zRoundDown, z) {
                z := zRoundDown
            }
        }
    }
}

/**
 * @dev The minimal functions a trigger must implement to work with the Cozy protocol.
 */
interface ITrigger is ICState {
  /// @dev Emitted when a new set is added to the trigger's list of sets.
  event SetAdded(ISet set);

  /// @dev Emitted when a trigger's state is updated.
  event TriggerStateUpdated(CState indexed state);

  /// @notice The current trigger state. This should never return PAUSED.
  function state() external returns(CState);

  /// @notice Called by the Manager to add a newly created set to the trigger's list of sets.
  function addSet(ISet set) external returns (bool);

  /// @notice Returns true if the trigger has been acknowledged by the entity responsible for transitioning trigger state.
  function acknowledged() external returns (bool);
}

/**
 * @dev Additional functions that are recommended to have in a trigger, but are not required.
 */
interface IBaseTrigger is ITrigger {
  /// @notice Returns the set address at the specified index in the trigger's list of sets.
  function sets(uint256 index) external returns(ISet set);

  /// @notice Returns all sets in the trigger's list of sets.
  function getSets() external returns(ISet[] memory);

  /// @notice Returns the number of Sets that use this trigger in a market.
  function getSetsLength() external returns(uint256 setsLength);

  /// @notice Returns the address of the trigger's manager.
  function manager() external returns(IManager managerAddress);

  /// @notice The maximum amount of sets that can be added to this trigger.
  function MAX_SET_LENGTH() external returns(uint256 maxSetLength);
}

/**
 * @dev Core trigger interface and implementation. All triggers should inherit from this to ensure they conform
 * to the required trigger interface.
 */
abstract contract BaseTrigger is ICState, IBaseTrigger {
  /// @notice Current trigger state.
  CState public state;

  /// @notice The Sets that use this trigger in a market.
  /// @dev Use this function to retrieve a specific Set.
  ISet[] public sets;

  /// @notice Prevent DOS attacks by limiting the number of sets.
  uint256 public constant MAX_SET_LENGTH = 25;

  /// @notice The manager of the Cozy protocol.
  IManager public immutable manager;

  /// @dev Thrown when a state update results in an invalid state transition.
  error InvalidStateTransition();

  /// @dev Thrown when trying to add a set to the `sets` array when it's length is already at `MAX_SET_LENGTH`.
  error SetLimitReached();

  /// @dev Thrown when trying to add a set to the `sets` array when the trigger has not been acknowledged.
  error Unacknowledged();

  /// @dev Thrown when the caller is not authorized to perform the action.
  error Unauthorized();

  /// @param _manager The manager of the Cozy protocol.
  constructor(IManager _manager) {
    manager = _manager;
  }

  /// @notice Returns true if the trigger has been acknowledged by the entity responsible for transitioning trigger state.
  /// @dev This must be implemented by contracts that inherit this contract. For manual triggers, after the trigger is deployed
  /// this should initially return false, and instead return true once the entity responsible for transitioning trigger state
  /// acknowledges the trigger. For programmatic triggers, this should always return true.
  function acknowledged() public virtual returns (bool);

  /// @notice The Sets that use this trigger in a market.
  /// @dev Use this function to retrieve all Sets.
  function getSets() public view returns(ISet[] memory) {
    return sets;
  }

  /// @notice The number of Sets that use this trigger in a market.
  function getSetsLength() public view returns(uint256) {
    return sets.length;
  }

  /// @dev Call this method to update Set addresses after deploy. Returns false if the trigger has not been acknowledged.
  function addSet(ISet _set) external returns (bool) {
    if (msg.sender != address(manager)) revert Unauthorized();
    if (!acknowledged()) revert Unacknowledged();
    (bool _exists,,,) = manager.sets(_set);
    if (!_exists) revert Unauthorized();

    uint256 setLength = sets.length;
    if (setLength >= MAX_SET_LENGTH) revert SetLimitReached();
    for (uint256 i = 0; i < setLength; i = uncheckedIncrement(i)) {
      if (sets[i] == _set) return true;
    }
    sets.push(_set);
    emit SetAdded(_set);
    return true;
  }

  /// @dev Child contracts should use this function to handle Trigger state transitions.
  function _updateTriggerState(CState _newState) internal returns (CState) {
    if (!_isValidTriggerStateTransition(state, _newState)) revert InvalidStateTransition();
    state = _newState;
    uint256 setLength = sets.length;
    for (uint256 i = 0; i < setLength; i = uncheckedIncrement(i)) {
      manager.updateMarketState(sets[i], _newState);
    }
    emit TriggerStateUpdated(_newState);
    return _newState;
  }

  /// @dev Reimplement this function if different state transitions are needed.
  function _isValidTriggerStateTransition(CState _oldState, CState _newState) internal virtual returns(bool) {
    // | From / To | ACTIVE      | FROZEN      | PAUSED   | TRIGGERED |
    // | --------- | ----------- | ----------- | -------- | --------- |
    // | ACTIVE    | -           | true        | false    | true      |
    // | FROZEN    | true        | -           | false    | true      |
    // | PAUSED    | false       | false       | -        | false     | <-- PAUSED is a set-level state, triggers cannot be paused
    // | TRIGGERED | false       | false       | false    | -         | <-- TRIGGERED is a terminal state

    if (_oldState == CState.TRIGGERED) return false;
    if (_oldState == _newState) return true; // If oldState == newState, return true since the Manager will convert that into a no-op.
    if (_oldState == CState.ACTIVE && _newState == CState.FROZEN) return true;
    if (_oldState == CState.FROZEN && _newState == CState.ACTIVE) return true;
    if (_oldState == CState.ACTIVE && _newState == CState.TRIGGERED) return true;
    if (_oldState == CState.FROZEN && _newState == CState.TRIGGERED) return true;
    return false;
  }

  /// @dev Unchecked increment of the provided value. Realistically it's impossible to overflow a
  /// uint256 so this is always safe.
  function uncheckedIncrement(uint256 i) internal pure returns (uint256) {
    unchecked { return i + 1; }
  }
}

/**
 * @notice A trigger contract that takes two addresses: a truth oracle and a tracking oracle.
 * This trigger ensures the two oracles always stay within the given price tolerance; the delta
 * in prices can be equal to but not greater than the price tolerance.
 */
contract ChainlinkTrigger is BaseTrigger {
  using FixedPointMathLib for uint256;

  uint256 internal constant ZOC = 1e4;

  /// @notice The canonical oracle, assumed to be correct.
  AggregatorV3Interface public immutable truthOracle;

  /// @notice The oracle we expect to diverge.
  AggregatorV3Interface public immutable trackingOracle;

  /// @notice The maximum percent delta between oracle prices that is allowed, expressed as a zoc.
  /// For example, a 0.2e4 priceTolerance would mean the trackingOracle price is
  /// allowed to deviate from the truthOracle price by up to +/- 20%, but no more.
  /// Note that if the truthOracle returns a price of 0, we treat the priceTolerance
  /// as having been exceeded, no matter what price the trackingOracle returns.
  uint256 public immutable priceTolerance;

  /// @notice The maximum amount of time we allow to elapse before the truth oracle's price is deemed stale.
  uint256 public immutable truthFrequencyTolerance;

  /// @notice The maximum amount of time we allow to elapse before the tracking oracle's price is deemed stale.
  uint256 public immutable trackingFrequencyTolerance;

  /// @dev Thrown when the `oracle`s price is negative.
  error InvalidPrice();

  /// @dev Thrown when the `oracle`s price timestamp is greater than the block's timestamp.
  error InvalidTimestamp();

  /// @dev Thrown when the `oracle`s last update is more than `frequencyTolerance` seconds ago.
  error StaleOraclePrice();

  /// @param _manager Address of the Cozy protocol manager.
  /// @param _truthOracle The canonical oracle, assumed to be correct.
  /// @param _trackingOracle The oracle we expect to diverge.
  /// @param _priceTolerance The maximum percent delta between oracle prices that is allowed, as a wad.
  /// @param _truthFrequencyTolerance The maximum amount of time we allow to elapse before the truth oracle's price is deemed stale.
  /// @param _trackingFrequencyTolerance The maximum amount of time we allow to elapse before the tracking oracle's price is deemed stale.
  constructor(
    IManager _manager,
    AggregatorV3Interface _truthOracle,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) BaseTrigger(_manager) {
    truthOracle = _truthOracle;
    trackingOracle = _trackingOracle;
    priceTolerance = _priceTolerance;
    truthFrequencyTolerance = _truthFrequencyTolerance;
    trackingFrequencyTolerance = _trackingFrequencyTolerance;
    runProgrammaticCheck();
  }

  /// @notice Compares the oracle's price to the reference oracle and toggles the trigger if required.
  /// @dev This method executes the `programmaticCheck()` and makes the
  /// required state changes both in the trigger and the sets.
  function runProgrammaticCheck() public returns (CState) {
    // Rather than revert if not active, we simply return the state and exit.
    // Both behaviors are acceptable, but returning is friendlier to the caller
    // as they don't need to handle a revert and can simply parse the
    // transaction's logs to know if the call resulted in a state change.
    if (state != CState.ACTIVE) return state;
    if (programmaticCheck()) return _updateTriggerState(CState.TRIGGERED);
    return state;
  }

  /// @notice Returns true if the trigger has been acknowledged by the entity responsible for transitioning trigger state.
  /// @notice Chainlink triggers are programmatic, so this always returns true.
  function acknowledged() public pure override returns (bool) {
    return true;
  }

  /// @dev Executes logic to programmatically determine if the trigger should be toggled.
  function programmaticCheck() internal view returns (bool) {
    uint256 _truePrice = _oraclePrice(truthOracle, truthFrequencyTolerance);
    uint256 _trackingPrice = _oraclePrice(trackingOracle, trackingFrequencyTolerance);

    uint256 _priceDelta = _truePrice > _trackingPrice ? _truePrice - _trackingPrice : _trackingPrice - _truePrice;

    // We round up when calculating the delta percentage to accommodate for precision loss to
    // ensure that the state becomes triggered when the delta is greater than the price tolerance.
    // When the delta is less than or exactly equal to the price tolerance, the resulting rounded
    // up value will not be greater than the price tolerance, as expected.
    return _truePrice > 0 ? _priceDelta.mulDivUp(ZOC, _truePrice) > priceTolerance : true;
  }

  /// @dev Returns the current price of the specified `_oracle`.
  function _oraclePrice(AggregatorV3Interface _oracle, uint256 _frequencyTolerance) internal view returns (uint256 _price) {
    (,int256 _priceInt,, uint256 _updatedAt,) = _oracle.latestRoundData();
    if (_updatedAt > block.timestamp) revert InvalidTimestamp();
    if (block.timestamp - _updatedAt > _frequencyTolerance) revert StaleOraclePrice();
    if (_priceInt < 0) revert InvalidPrice();
    _price = uint256(_priceInt);
  }
}

/**
 * @notice An aggregator that does one thing: return a fixed price, in fixed decimals, as set
 * in the constructor.
 */
contract FixedPriceAggregator is AggregatorV3Interface {
  /// @notice The number of decimals the fixed price is represented in.
  uint8 public immutable decimals;

  /// @notice The fixed price, in the decimals indicated, returned by this oracle.
  int256 private immutable price;

  /// @param _decimals The number of decimals the fixed price is represented in.
  /// @param _price The fixed price, in the decimals indicated, to be returned by this oracle.
  constructor(uint8 _decimals, int256 _price) {
    price = _price;
    decimals = _decimals;
  }

  /// @notice A description indicating this is a fixed price oracle.
  function description() external pure returns (string memory) {
    return "Fixed price oracle";
  }

   /// @notice A version number of 0.
  function version() external pure returns (uint256) {
    return 0;
  }

  /// @notice Returns data for the specified round.
  /// @param _roundId This parameter is ignored.
  /// @return roundId 0
  /// @return answer The fixed price returned by this oracle, represented in appropriate decimals.
  /// @return startedAt 0
  /// @return updatedAt Since price is fixed, we always return the current block timestamp.
  /// @return answeredInRound 0
  function getRoundData(uint80 _roundId)
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    _roundId; // Silence unused variable compiler warning.
    return (uint80(0), price, uint256(0), block.timestamp, uint80(0));
  }

  /// @notice Returns data for the latest round.
  /// @return roundId 0
  /// @return answer The fixed price returned by this oracle, represented in appropriate decimals.
  /// @return startedAt 0
  /// @return updatedAt Since price is fixed, we always return the current block timestamp.
  /// @return answeredInRound 0
  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    return (uint80(0), price, uint256(0), block.timestamp, uint80(0));
  }
}

/**
 * @notice Deploys Chainlink triggers that ensure two oracles stay within the given price
 * tolerance. It also supports creating a fixed price oracle to use as the truth oracle, useful
 * for e.g. ensuring stablecoins maintain their peg.
 */
contract ChainlinkTriggerFactory is IChainlinkTriggerFactory {
  /// @notice The manager of the Cozy protocol.
  IManager public immutable manager;

  /// @notice Maps the triggerConfigId to the number of triggers created with those configs.
  mapping(bytes32 => uint256) public triggerCount;

  // We use a fixed salt because:
  //   (a) FixedPriceAggregators are just static, owner-less contracts,
  //   (b) there are no risks of bad actors taking them over on other chains,
  //   (c) it would be nice to have these aggregators deployed to the same
  //       address on each chain, and
  //   (d) it saves gas.
  // This is just the 32 bytes you get when you keccak256(abi.encode(42)).
  bytes32 internal constant FIXED_PRICE_ORACLE_SALT = 0xbeced09521047d05b8960b7e7bcc1d1292cf3e4b2a6b63f48335cbde5f7545d2;

  /// @param _manager Address of the Cozy protocol manager.
  constructor(IManager _manager) {
    manager = _manager;
  }

  /// @dev Thrown when the truthOracle and trackingOracle prices cannot be directly compared.
  error InvalidOraclePair();

  /// @notice Call this function to deploy a ChainlinkTrigger.
  /// @param _truthOracle The address of the desired truthOracle for the trigger.
  /// @param _trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param _priceTolerance The priceTolerance that the deployed trigger will
  /// have. See ChainlinkTrigger.priceTolerance() for more information.
  /// @param _truthFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the truth oracle. See ChainlinkTrigger.truthFrequencyTolerance() for more information.
  /// @param _trackingFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the tracking oracle. See ChainlinkTrigger.trackingFrequencyTolerance() for more information.
  /// @param _metadata See TriggerMetadata for more info.
  function deployTrigger(
    AggregatorV3Interface _truthOracle,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance,
    TriggerMetadata memory _metadata
  ) public returns (IChainlinkTrigger _trigger) {
    if (_truthOracle.decimals() != _trackingOracle.decimals()) revert InvalidOraclePair();

    bytes32 _configId = triggerConfigId(
      _truthOracle,
      _trackingOracle,
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );

    uint256 _triggerCount = triggerCount[_configId]++;
    bytes32 _salt = keccak256(abi.encode(_triggerCount, block.chainid));

    _trigger = IChainlinkTrigger(address(new ChainlinkTrigger{salt: _salt}(
      manager,
      _truthOracle,
      _trackingOracle,
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    )));

    emit TriggerDeployed(
      address(_trigger),
      _configId,
      address(_truthOracle),
      address(_trackingOracle),
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance,
      _metadata.name,
      _metadata.description,
      _metadata.logoURI
    );
  }

  /// @notice Call this function to deploy a ChainlinkTrigger with a
  /// FixedPriceAggregator as its truthOracle. This is useful if you were
  /// building a market in which you wanted to track whether or not a stablecoin
  /// asset had become depegged.
  /// @param _price The fixed price, or peg, with which to compare the trackingOracle price.
  /// @param _decimals The number of decimals of the fixed price. This should
  /// match the number of decimals used by the desired _trackingOracle.
  /// @param _trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param _priceTolerance The priceTolerance that the deployed trigger will
  /// have. See ChainlinkTrigger.priceTolerance() for more information.
  /// @param _frequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the tracking oracle. See ChainlinkTrigger.trackingFrequencyTolerance() for more information.
  /// @param _metadata See TriggerMetadata for more info.
  function deployTrigger(
    int256 _price,
    uint8 _decimals,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _frequencyTolerance,
    TriggerMetadata memory _metadata
  ) public returns (IChainlinkTrigger _trigger) {
    AggregatorV3Interface _truthOracle = deployFixedPriceAggregator(_price, _decimals);

    return deployTrigger(
      _truthOracle,
      _trackingOracle,
      _priceTolerance,
      // For the truth FixedPriceAggregator peg oracle, we use a frequency
      // tolerance of 0 since it should always return block.timestamp as the
      // updatedAt timestamp.
      0,
      _frequencyTolerance,
      _metadata
    );
  }

  /// @notice Call this function to determine the address at which a trigger
  /// with the supplied configuration would be deployed.
  /// @param _truthOracle The address of the desired truthOracle for the trigger.
  /// @param _trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param _priceTolerance The priceTolerance that the deployed trigger would
  /// have. See ChainlinkTrigger.priceTolerance() for more information.
  /// @param _truthFrequencyTolerance The frequency tolerance that the deployed trigger would
  /// have for the truth oracle. See ChainlinkTrigger.truthFrequencyTolerance() for more information.
  /// @param _trackingFrequencyTolerance The frequency tolerance that the deployed trigger would
  /// have for the tracking oracle. See ChainlinkTrigger.trackingFrequencyTolerance() for more information.
  /// @param _triggerCount The zero-indexed ordinal of the trigger with respect to its
  /// configuration, e.g. if this were to be the fifth trigger deployed with
  /// these configs, then _triggerCount should be 4.
  function computeTriggerAddress(
    AggregatorV3Interface _truthOracle,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance,
    uint256 _triggerCount
  ) public view returns(address _address) {
    bytes memory _triggerConstructorArgs = abi.encode(
      manager,
      _truthOracle,
      _trackingOracle,
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );

    // https://eips.ethereum.org/EIPS/eip-1014
    bytes32 _bytecodeHash = keccak256(
      bytes.concat(
        type(ChainlinkTrigger).creationCode,
        _triggerConstructorArgs
      )
    );
    bytes32 _salt = keccak256(abi.encode(_triggerCount, block.chainid));
    bytes32 _data = keccak256(bytes.concat(bytes1(0xff), bytes20(address(this)), _salt, _bytecodeHash));
    _address = address(uint160(uint256(_data)));
  }

  /// @notice Call this function to find triggers with the specified
  /// configurations that can be used for new markets in Sets.
  /// @dev If this function returns the zero address, that means that an
  /// available trigger was not found with the supplied configuration. Use
  /// `deployTrigger` to deploy a new one.
  /// @param _truthOracle The address of the desired truthOracle for the trigger.
  /// @param _trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param _priceTolerance The priceTolerance that the deployed trigger will
  /// have. See ChainlinkTrigger.priceTolerance() for more information.
  /// @param _truthFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the truth oracle. See ChainlinkTrigger.truthFrequencyTolerance() for more information.
  /// @param _trackingFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the tracking oracle. See ChainlinkTrigger.trackingFrequencyTolerance() for more information.
  function findAvailableTrigger(
    AggregatorV3Interface _truthOracle,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) public view returns(address) {

    bytes32 _counterId = triggerConfigId(
      _truthOracle,
      _trackingOracle,
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );
    uint256 _triggerCount = triggerCount[_counterId];

    for (uint256 i = 0; i < _triggerCount; i++) {
      address _computedAddr = computeTriggerAddress(
        _truthOracle,
        _trackingOracle,
        _priceTolerance,
        _truthFrequencyTolerance,
        _trackingFrequencyTolerance,
        i
      );

      ChainlinkTrigger _trigger = ChainlinkTrigger(_computedAddr);
      if (_trigger.getSetsLength() < _trigger.MAX_SET_LENGTH()) {
        return _computedAddr;
      }
    }

    return address(0); // If none is found, return zero address.
  }

  /// @notice Call this function to determine the identifier of the supplied trigger
  /// configuration. This identifier is used both to track the number of
  /// triggers deployed with this configuration (see `triggerCount`) and is
  /// emitted at the time triggers with that configuration are deployed.
  /// @param _truthOracle The address of the desired truthOracle for the trigger.
  /// @param _trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param _priceTolerance The priceTolerance that the deployed trigger will
  /// have. See ChainlinkTrigger.priceTolerance() for more information.
  /// @param _truthFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the truth oracle. See ChainlinkTrigger.truthFrequencyTolerance() for more information.
  /// @param _trackingFrequencyTolerance The frequency tolerance that the deployed trigger will
  /// have for the tracking oracle. See ChainlinkTrigger.trackingFrequencyTolerance() for more information.
  function triggerConfigId(
    AggregatorV3Interface _truthOracle,
    AggregatorV3Interface _trackingOracle,
    uint256 _priceTolerance,
    uint256 _truthFrequencyTolerance,
    uint256 _trackingFrequencyTolerance
  ) public view returns (bytes32) {
    bytes memory _triggerConstructorArgs = abi.encode(
      manager,
      _truthOracle,
      _trackingOracle,
      _priceTolerance,
      _truthFrequencyTolerance,
      _trackingFrequencyTolerance
    );
    return keccak256(_triggerConstructorArgs);
  }

  /// @notice Call this function to deploy a FixedPriceAggregator contract,
  /// which behaves like a Chainlink oracle except that it always returns the
  /// same price.
  /// @dev If the specified contract is already deployed, we return it's address
  /// instead of reverting to avoid duplicate aggregators
  /// @param _price The fixed price, in the decimals indicated, returned by the deployed oracle.
  /// @param _decimals The number of decimals of the fixed price.
  function deployFixedPriceAggregator(
    int256 _price, // An int (instead of uint256) because that's what's used by Chainlink.
    uint8 _decimals
  ) public returns (AggregatorV3Interface) {
    address _oracleAddress = computeFixedPriceAggregatorAddress(_price, _decimals);
    if (_oracleAddress.code.length > 0) return AggregatorV3Interface(_oracleAddress);
    return new FixedPriceAggregator{salt: FIXED_PRICE_ORACLE_SALT}(_decimals, _price);
  }

  /// @notice Call this function to compute the address that a
  /// FixedPriceAggregator contract would be deployed to with the provided args.
  /// @param _price The fixed price, in the decimals indicated, returned by the deployed oracle.
  /// @param _decimals The number of decimals of the fixed price.
  function computeFixedPriceAggregatorAddress(
    int256 _price, // An int (instead of uint256) because that's what's used by Chainlink.
    uint8 _decimals
  ) public view returns (address) {
    bytes memory _aggregatorConstructorArgs = abi.encode(_decimals, _price);
    bytes32 _bytecodeHash = keccak256(
      bytes.concat(
        type(FixedPriceAggregator).creationCode,
        _aggregatorConstructorArgs
      )
    );
    bytes32 _data = keccak256(
      bytes.concat(
        bytes1(0xff),
        bytes20(address(this)),
        FIXED_PRICE_ORACLE_SALT,
        _bytecodeHash
      )
    );
    return address(uint160(uint256(_data)));
  }
}