/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-13
*/

// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

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
  ICostModel costModel; // Contract defining the cost model for this market.
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
  function state(address _who) view external returns (ICState.CState _state);

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
  function unpause(ICState.CState _state) external;

  /// @notice Execute queued updates to setConfig and marketConfig. This should only be called by the Manager.
  function updateConfigs(uint256 _leverageFactor, uint256 _depositFee, address _decayModel, address _dripModel, MarketInfo[] memory _marketInfos) external;

  /// @notice Updates the state of the a market in the set.
  function updateMarketState(address _trigger, uint8 _newState) external;

  /// @notice Updates the set's state to `_state.
  function updateSetState(ICState.CState _state) external;

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
interface IManager is ICState {
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
  function queuedConfigUpdateHash(ISet _set) view external returns (bytes32);

  /// @notice Returns the Cozy protocol SetFactory.
  function setFactory() view external returns (address);

  /// @notice Returns metadata about previous inactive periods for sets.
  function setInactivityData(ISet _set) view external returns (uint64 inactiveTransitionTime);

  /// @notice Returns the owner address for the given set.
  function setOwner(ISet _set) view external returns (address);

  /// @notice Returns the pauser address for the given set.
  function setPauser(ISet _set) view external returns (address);

  /// @notice For the specified set, returns whether it's a valid Cozy set, if it's approve to use the backstop,
  /// as well as timestamps for any configuration updates that are queued.
  function sets(ISet _set) view external returns (bool exists, bool approved, uint64 configUpdateTime, uint64 configUpdateDeadline);

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
  uint256 public constant MAX_SET_LENGTH = 50;

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

// A named import is used to avoid identifier naming conflicts between IERC20 imports. solc throws a DeclarationError
// if an interface with the same name is imported twice in a file using different paths, even if they have the
// same implementation. For example, if a file in the cozy-v2-interfaces submodule that is imported in this project
// imports an IERC20 interface with "import src/interfaces/IERC20.sol;", but in this project we import the same
// interface with "import cozy-v2-interfaces/interfaces/IERC20.sol;", a DeclarationError will be thrown.

/**
 * @title Provides addresses of the live contracts implementing certain interfaces.
 * @dev Examples are the Oracle or Store interfaces.
 */
interface FinderInterface {
    /**
     * @notice Updates the address of the contract that implements `interfaceName`.
     * @param interfaceName bytes32 encoding of the interface name that is either changed or registered.
     * @param implementationAddress address of the deployed contract that implements the interface.
     */
    function changeImplementationAddress(bytes32 interfaceName, address implementationAddress) external;

    /**
     * @notice Gets the address of the contract that implements the given `interfaceName`.
     * @param interfaceName queried interface.
     * @return implementationAddress address of the deployed contract that implements the interface.
     */
    function getImplementationAddress(bytes32 interfaceName) external view returns (address);
}

/**
 * @title Financial contract facing Oracle interface.
 * @dev Interface used by financial contracts to interact with the Oracle. Voters will use a different interface.
 * @dev Modified from uma-protocol to use Cozy's implementation of IERC20 instead of OpenZeppelin's. Cozy's IERC20
 * conforms to Cozy's implementation of ERC20, which was modified from Solmate to use an initializer to support
 * usage as a minimal proxy.
 */
abstract contract OptimisticOracleV2Interface {
    event RequestPrice(
        address indexed requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes ancillaryData,
        address currency,
        uint256 reward,
        uint256 finalFee
    );
    event ProposePrice(
        address indexed requester,
        address indexed proposer,
        bytes32 identifier,
        uint256 timestamp,
        bytes ancillaryData,
        int256 proposedPrice,
        uint256 expirationTimestamp,
        address currency
    );
    event DisputePrice(
        address indexed requester,
        address indexed proposer,
        address indexed disputer,
        bytes32 identifier,
        uint256 timestamp,
        bytes ancillaryData,
        int256 proposedPrice
    );
    event Settle(
        address indexed requester,
        address indexed proposer,
        address indexed disputer,
        bytes32 identifier,
        uint256 timestamp,
        bytes ancillaryData,
        int256 price,
        uint256 payout
    );
    // Struct representing the state of a price request.
    enum State {
        Invalid, // Never requested.
        Requested, // Requested, no other actions taken.
        Proposed, // Proposed, but not expired or disputed yet.
        Expired, // Proposed, not disputed, past liveness.
        Disputed, // Disputed, but no DVM price returned yet.
        Resolved, // Disputed and DVM price is available.
        Settled // Final price has been set in the contract (can get here from Expired or Resolved).
    }

    struct RequestSettings {
        bool eventBased; // True if the request is set to be event-based.
        bool refundOnDispute; // True if the requester should be refunded their reward on dispute.
        bool callbackOnPriceProposed; // True if callbackOnPriceProposed callback is required.
        bool callbackOnPriceDisputed; // True if callbackOnPriceDisputed callback is required.
        bool callbackOnPriceSettled; // True if callbackOnPriceSettled callback is required.
        uint256 bond; // Bond that the proposer and disputer must pay on top of the final fee.
        uint256 customLiveness; // Custom liveness value set by the requester.
    }

    // Struct representing a price request.
    struct Request {
        address proposer; // Address of the proposer.
        address disputer; // Address of the disputer.
        IERC20 currency; // ERC20 token used to pay rewards and fees.
        bool settled; // True if the request is settled.
        RequestSettings requestSettings; // Custom settings associated with a request.
        int256 proposedPrice; // Price that the proposer submitted.
        int256 resolvedPrice; // Price resolved once the request is settled.
        uint256 expirationTime; // Time at which the request auto-settles without a dispute.
        uint256 reward; // Amount of the currency to pay to the proposer on settlement.
        uint256 finalFee; // Final fee to pay to the Store upon request to the DVM.
    }

    // This value must be <= the Voting contract's `ancillaryBytesLimit` value otherwise it is possible
    // that a price can be requested to this contract successfully, but cannot be disputed because the DVM refuses
    // to accept a price request made with ancillary data length over a certain size.
    uint256 public constant ancillaryBytesLimit = 8192;

    function defaultLiveness() external view virtual returns (uint256);

    function finder() external view virtual returns (FinderInterface);

    function getCurrentTime() external view virtual returns (uint256);

    // Note: this is required so that typechain generates a return value with named fields.
    mapping(bytes32 => Request) public requests;

    /**
     * @notice Requests a new price.
     * @param identifier price identifier being requested.
     * @param timestamp timestamp of the price being requested.
     * @param ancillaryData ancillary data representing additional args being passed with the price request.
     * @param currency ERC20 token used for payment of rewards and fees. Must be approved for use with the DVM.
     * @param reward reward offered to a successful proposer. Will be pulled from the caller. Note: this can be 0,
     *               which could make sense if the contract requests and proposes the value in the same call or
     *               provides its own reward system.
     * @return totalBond default bond (final fee) + final fee that the proposer and disputer will be required to pay.
     * This can be changed with a subsequent call to setBond().
     */
    function requestPrice(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        IERC20 currency,
        uint256 reward
    ) external virtual returns (uint256 totalBond);

    /**
     * @notice Set the proposal bond associated with a price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @param bond custom bond amount to set.
     * @return totalBond new bond + final fee that the proposer and disputer will be required to pay. This can be
     * changed again with a subsequent call to setBond().
     */
    function setBond(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        uint256 bond
    ) external virtual returns (uint256 totalBond);

    /**
     * @notice Sets the request to refund the reward if the proposal is disputed. This can help to "hedge" the caller
     * in the event of a dispute-caused delay. Note: in the event of a dispute, the winner still receives the other's
     * bond, so there is still profit to be made even if the reward is refunded.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     */
    function setRefundOnDispute(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external virtual;

    /**
     * @notice Sets a custom liveness value for the request. Liveness is the amount of time a proposal must wait before
     * being auto-resolved.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @param customLiveness new custom liveness.
     */
    function setCustomLiveness(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        uint256 customLiveness
    ) external virtual;

    /**
     * @notice Sets the request to be an "event-based" request.
     * @dev Calling this method has a few impacts on the request:
     *
     * 1. The timestamp at which the request is evaluated is the time of the proposal, not the timestamp associated
     *    with the request.
     *
     * 2. The proposer cannot propose the "too early" value (TOO_EARLY_RESPONSE). This is to ensure that a proposer who
     *    prematurely proposes a response loses their bond.
     *
     * 3. RefundoOnDispute is automatically set, meaning disputes trigger the reward to be automatically refunded to
     *    the requesting contract.
     *
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     */
    function setEventBased(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external virtual;

    /**
     * @notice Sets which callbacks should be enabled for the request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @param callbackOnPriceProposed whether to enable the callback onPriceProposed.
     * @param callbackOnPriceDisputed whether to enable the callback onPriceDisputed.
     * @param callbackOnPriceSettled whether to enable the callback onPriceSettled.
     */
    function setCallbacks(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        bool callbackOnPriceProposed,
        bool callbackOnPriceDisputed,
        bool callbackOnPriceSettled
    ) external virtual;

    /**
     * @notice Proposes a price value on another address' behalf. Note: this address will receive any rewards that come
     * from this proposal. However, any bonds are pulled from the caller.
     * @param proposer address to set as the proposer.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @param proposedPrice price being proposed.
     * @return totalBond the amount that's pulled from the caller's wallet as a bond. The bond will be returned to
     * the proposer once settled if the proposal is correct.
     */
    function proposePriceFor(
        address proposer,
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        int256 proposedPrice
    ) public virtual returns (uint256 totalBond);

    /**
     * @notice Proposes a price value for an existing price request.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @param proposedPrice price being proposed.
     * @return totalBond the amount that's pulled from the proposer's wallet as a bond. The bond will be returned to
     * the proposer once settled if the proposal is correct.
     */
    function proposePrice(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        int256 proposedPrice
    ) external virtual returns (uint256 totalBond);

    /**
     * @notice Disputes a price request with an active proposal on another address' behalf. Note: this address will
     * receive any rewards that come from this dispute. However, any bonds are pulled from the caller.
     * @param disputer address to set as the disputer.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return totalBond the amount that's pulled from the caller's wallet as a bond. The bond will be returned to
     * the disputer once settled if the dispute was value (the proposal was incorrect).
     */
    function disputePriceFor(
        address disputer,
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) public virtual returns (uint256 totalBond);

    /**
     * @notice Disputes a price value for an existing price request with an active proposal.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return totalBond the amount that's pulled from the disputer's wallet as a bond. The bond will be returned to
     * the disputer once settled if the dispute was valid (the proposal was incorrect).
     */
    function disputePrice(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external virtual returns (uint256 totalBond);

    /**
     * @notice Retrieves a price that was previously requested by a caller. Reverts if the request is not settled
     * or settleable. Note: this method is not view so that this call may actually settle the price request if it
     * hasn't been settled.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return resolved price.
     */
    function settleAndGetPrice(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external virtual returns (int256);

    /**
     * @notice Attempts to settle an outstanding price request. Will revert if it isn't settleable.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return payout the amount that the "winner" (proposer or disputer) receives on settlement. This amount includes
     * the returned bonds as well as additional rewards.
     */
    function settle(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) external virtual returns (uint256 payout);

    /**
     * @notice Gets the current data structure containing all information about a price request.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return the Request data structure.
     */
    function getRequest(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) public view virtual returns (Request memory);

    /**
     * @notice Returns the state of a price request.
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return the State enum value.
     */
    function getState(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) public view virtual returns (State);

    /**
     * @notice Checks if a given request has resolved or been settled (i.e the optimistic oracle has a price).
     * @param requester sender of the initial price request.
     * @param identifier price identifier to identify the existing request.
     * @param timestamp timestamp to identify the existing request.
     * @param ancillaryData ancillary data of the price being requested.
     * @return true if price has resolved or settled, false otherwise.
     */
    function hasPrice(
        address requester,
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData
    ) public view virtual returns (bool);

    function stampAncillaryData(bytes memory ancillaryData, address requester)
        public
        view
        virtual
        returns (bytes memory);
}

// A named import is used to avoid identifier naming conflicts between IERC20 imports. solc throws a DeclarationError
// if an interface with the same name is imported twice in a file using different paths, even if they have the
// same implementation. For example, if a file in the cozy-v2-interfaces submodule that is imported in this project
// imports an IERC20 interface with "import src/interfaces/IERC20.sol;", but in this project we import the same
// interface with "import cozy-v2-interfaces/interfaces/IERC20.sol;", a DeclarationError will be thrown.

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/d155ee8d58f96426f57c015b34dee8a410c1eacc/src/utils/SafeTransferLib.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
/// @dev Note that none of the functions in this library check that a token has code at all! That responsibility is delegated to the caller.
/// @dev Note that this version of solmate's SafeTransferLib uses our own IERC20 interface instead of solmate's ERC20. Cozy's ERC20 was modified
/// from solmate to use an initializer to support usage as a minimal proxy.
library SafeTransferLib {
  // --------------------------------
  // -------- ETH OPERATIONS --------
  // --------------------------------

  function safeTransferETH(address to, uint256 amount) internal {
    bool success;

    assembly {
      // Transfer the ETH and store if it succeeded or not.
      success := call(gas(), to, amount, 0, 0, 0, 0)
    }

    require(success, "ETH_TRANSFER_FAILED");
  }

  // ----------------------------------
  // -------- ERC20 OPERATIONS --------
  // ----------------------------------

  function safeTransferFrom(
    IERC20 token,
    address from,
    address to,
    uint256 amount
  ) internal {
    bool success;

    assembly {
      // Get a pointer to some free memory.
      let freeMemoryPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the function selector.
      mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
      mstore(add(freeMemoryPointer, 4), from) // Append the "from" argument.
      mstore(add(freeMemoryPointer, 36), to) // Append the "to" argument.
      mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument.

      success := and(
        // Set success to whether the call reverted, if not we check it either
        // returned exactly 1 (can't just be non-zero data), or had no return data.
        or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
        // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
        // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
        // Counterintuitively, this call must be positioned second to the or() call in the
        // surrounding and() call or else returndatasize() will be zero during the computation.
        call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
      )
    }

    require(success, "TRANSFER_FROM_FAILED");
  }

  function safeTransfer(
    IERC20 token,
    address to,
    uint256 amount
  ) internal {
    bool success;

    assembly {
      // Get a pointer to some free memory.
      let freeMemoryPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the function selector.
      mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
      mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
      mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

      success := and(
        // Set success to whether the call reverted, if not we check it either
        // returned exactly 1 (can't just be non-zero data), or had no return data.
        or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
        // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
        // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
        // Counterintuitively, this call must be positioned second to the or() call in the
        // surrounding and() call or else returndatasize() will be zero during the computation.
        call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
      )
    }

    require(success, "TRANSFER_FAILED");
  }

  function safeApprove(
    IERC20 token,
    address to,
    uint256 amount
  ) internal {
    bool success;

    assembly {
      // Get a pointer to some free memory.
      let freeMemoryPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the function selector.
      mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
      mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
      mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

      success := and(
        // Set success to whether the call reverted, if not we check it either
        // returned exactly 1 (can't just be non-zero data), or had no return data.
        or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
        // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
        // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
        // Counterintuitively, this call must be positioned second to the or() call in the
        // surrounding and() call or else returndatasize() will be zero during the computation.
        call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
      )
    }

    require(success, "APPROVE_FAILED");
  }
}

/**
 * @notice This is an automated trigger contract which will move markets into a
 * TRIGGERED state in the event that the UMA Optimistic Oracle answers "YES" to
 * a provided query, e.g. "Was protocol ABCD hacked on or after block 42". More
 * information about UMA oracles and the lifecycle of queries can be found here:
 * https://docs.umaproject.org/.
 * @dev The high-level lifecycle of a UMA request is as follows:
 *   - someone asks a question of the oracle and provides a reward for someone
 *     to answer it
 *   - users of the UMA oracle system view the question (usually here:
 *     https://oracle.umaproject.org/)
 *   - someone proposes an answer to the question in hopes of claiming the
 *     reward`
 *   - users of UMA see the proposed answer and have a chance to dispute it
 *   - there is a finite period of time within which to dispute the answer
 *   - if the answer is not disputed during this period, the oracle can finalize
 *     the answer and the proposer gets the reward
 *   - if the answer is disputed, the question is sent to the DVM (Data
 *     Verification Mechanism) in which UMA token holders vote on who is right
 * There are four essential players in the above process:
 *   1. Requester: the account that is asking the oracle a question.
 *   2. Proposer: the account that submits an answer to the question.
 *   3. Disputer: the account (if any) that disagrees with the proposed answer.
 *   4. The DVM: a DAO that is the final arbiter of disputed proposals.
 * This trigger plays the first role in this lifecycle. It submits a request for
 * an answer to a yes-or-no question (the query) to the Optimistic Oracle.
 * Questions need to be phrased in such a way that if a "Yes" answer is given
 * to them, then this contract will go into a TRIGGERED state and p-token
 * holders will be able to claim the protection that they purchased. For
 * example, if you wanted to create a market selling protection for Compound
 * yield, you might deploy a UMATrigger with a query like "Was Compound hacked
 * after block X?" If the oracle responds with a "Yes" answer, this contract
 * would move the associated market into the TRIGGERED state and people who had
 * purchased protection from that market would get paid out.
 *   But what if Compound hasn't been hacked? Can't someone just respond "No" to
 * the trigger's query? Wouldn't that be the right answer and wouldn't it mean
 * the end of the query lifecycle? Yes. For this exact reason, we have enabled
 * callbacks (see the `priceProposed` function) which will revert in the event
 * that someone attempts to propose a negative answer to the question. We want
 * the queries to remain open indefinitely until there is a positive answer,
 * i.e. "Yes, there was a hack". **This should be communicated in the query text.**
 *   In the event that a YES answer to a query is disputed and the DVM sides
 * with the disputer (i.e. a NO answer), we immediately re-submit the query to
 * the DVM through another callback (see `priceSettled`). In this way, our query
 * will always be open with the oracle. If/when the event that we are concerned
 * with happens the trigger will immediately be notified.
 */
contract UMATrigger is BaseTrigger {
  using SafeTransferLib for IERC20;

  /// @notice The type of query that will be submitted to the oracle.
  bytes32 public constant queryIdentifier = bytes32("YES_OR_NO_QUERY");

  /// @notice The UMA Optimistic Oracle.
  OptimisticOracleV2Interface public immutable oracle;

  /// @notice The identifier used to lookup the UMA Optimistic Oracle with the finder.
  bytes32 internal constant ORACLE_LOOKUP_IDENTIFIER = bytes32("OptimisticOracleV2");

  /// @notice The query that is sent to the UMA Optimistic Oracle for evaluation.
  /// It should be phrased so that only a positive answer is appropriate, e.g.
  /// "Was protocol ABCD hacked on or after block number 42". Negative answers
  /// are disallowed so that queries can remain open in UMA until the events we
  /// care about happen, if ever.
  string public query;

  /// @notice The token used to pay the reward to users that propose answers to the query.
  IERC20 public immutable rewardToken;

  /// @notice The amount of `rewardToken` that must be staked by a user wanting
  /// to propose or dispute an answer to the query. See UMA's price dispute
  /// workflow for more information. It's recommended that the bond amount be a
  /// significant value to deter addresses from proposing malicious, false, or
  /// otherwise self-interested answers to the query.
  uint256 public immutable bondAmount;

  /// @notice The window of time in seconds within which a proposed answer may
  /// be disputed. See UMA's "customLiveness" setting for more information. It's
  /// recommended that the dispute window be fairly long (12-24 hours), given
  /// the difficulty of assessing expected queries (e.g. "Was protocol ABCD
  /// hacked") and the amount of funds potentially at stake.
  uint256 public immutable proposalDisputeWindow;

  /// @notice The most recent timestamp that the query was submitted to the UMA oracle.
  uint256 public requestTimestamp;

  /// @notice Default address that will receive any leftover rewards.
  address public refundRecipient;

  /// @dev Thrown when a negative answer is proposed to the submitted query.
  error InvalidProposal();

  /// @dev Thrown when the trigger attempts to settle an unsettleable UMA request.
  error Unsettleable();

  /// @dev UMA expects answers to be denominated as wads. So, e.g., a p3 answer
  /// of 0.5 would be represented as 0.5e18.
  int256 internal constant AFFIRMATIVE_ANSWER = 1e18;

  /// @param _manager The Cozy protocol Manager.
  /// @param _oracle The UMA Optimistic Oracle.
  /// @param _query The query that the trigger will send to the UMA Optimistic
  /// Oracle for evaluation.
  /// @param _rewardToken The token used to pay the reward to users that propose
  /// answers to the query. The reward token must be approved by UMA governance.
  /// Approved tokens can be found with the UMA AddressWhitelist contract on each
  /// chain supported by UMA.
  /// @param _refundRecipient Default address that will recieve any leftover
  /// rewards at UMA query settlement time.
  /// @param _bondAmount The amount of `rewardToken` that must be staked by a
  /// user wanting to propose or dispute an answer to the query. See UMA's price
  /// dispute workflow for more information. It's recommended that the bond
  /// amount be a significant value to deter addresses from proposing malicious,
  /// false, or otherwise self-interested answers to the query.
  /// @param _proposalDisputeWindow The window of time in seconds within which a
  /// proposed answer may be disputed. See UMA's "customLiveness" setting for
  /// more information. It's recommended that the dispute window be fairly long
  /// (12-24 hours), given the difficulty of assessing expected queries (e.g.
  /// "Was protocol ABCD hacked") and the amount of funds potentially at stake.
  constructor(
    IManager _manager,
    OptimisticOracleV2Interface _oracle,
    string memory _query,
    IERC20 _rewardToken,
    address _refundRecipient,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow
  ) BaseTrigger(_manager) {
    oracle = _oracle;
    query = _query;
    rewardToken = _rewardToken;
    refundRecipient = _refundRecipient;
    bondAmount = _bondAmount;
    proposalDisputeWindow = _proposalDisputeWindow;

    _submitRequestToOracle();
  }

  /// @notice Returns true if the trigger has been acknowledged by the entity responsible for transitioning trigger state.
  /// @notice UMA triggers are managed by the UMA decentralized voting system, so this always returns true.
  function acknowledged() public pure override returns (bool) {
    return true;
  }

  /// @notice Submits the trigger query to the UMA Optimistic Oracle for evaluation.
  function _submitRequestToOracle() internal {
    uint256 _rewardAmount = rewardToken.balanceOf(address(this));
    rewardToken.approve(address(oracle), _rewardAmount);
    requestTimestamp = block.timestamp;

    // The UMA function for submitting a query to the oracle is `requestPrice`
    // even though not all queries are price queries. Another name for this
    // function might have been `requestAnswer`.
    oracle.requestPrice(
      queryIdentifier,
      requestTimestamp,
      bytes(query),
      rewardToken,
      _rewardAmount
    );

    // Set this as an event-based query so that no one can propose the "too
    // soon" answer and so that we automatically get the reward back if there
    // is a dispute. This allows us to re-query the oracle for ~free.
    oracle.setEventBased(queryIdentifier, requestTimestamp, bytes(query));

    // Set the amount of rewardTokens that have to be staked in order to answer
    // the query or dispute an answer to the query.
    oracle.setBond(queryIdentifier, requestTimestamp, bytes(query), bondAmount);

    // Set the proposal dispute window -- i.e. how long people have to challenge
    // and answer to the query.
    oracle.setCustomLiveness(queryIdentifier, requestTimestamp, bytes(query), proposalDisputeWindow);

    // We want to be notified by the UMA oracle when answers and proposed and
    // when answers are confirmed/settled.
    oracle.setCallbacks(
      queryIdentifier,
      requestTimestamp,
      bytes(query),
      true,  // Enable the answer-proposed callback.
      false, // Don't enable the answer-disputed callback.
      true   // Enable the answer-settled callback.
    );
  }

  /// @notice UMA callback for proposals. This function is called by the UMA
  /// oracle when a new answer is proposed for the query. Its only purpose is to
  /// prevent people from proposing negative answers and prematurely closing our
  /// queries. For example, if our query were something like "Has Compound been
  /// hacked since block X?" the correct answer could easily be "No" right now.
  /// But we we don't care if the answer is "No". The trigger only cares when
  /// hacks *actually happen*. So we revert when people try to submit negative
  /// answers, as negative answers that are undisputed would resolve our query
  /// and we'd have to pay a new reward to resubmit.
  /// @param _identifier price identifier being requested.
  /// @param _timestamp timestamp of the original query request.
  /// @param _ancillaryData ancillary data of the original query request.
  function priceProposed(
    bytes32 _identifier,
    uint256 _timestamp,
    bytes memory _ancillaryData
  ) external {
    // Besides confirming that the caller is the UMA oracle, we also confirm
    // that the args passed in match the args used to submit our latest query to
    // UMA. This is done as an extra safeguard that we are responding to an
    // event related to the specific query we care about. It is possible, for
    // example, for multiple queries to be submitted to the oracle that differ
    // only with respect to timestamp. So we want to make sure we know which
    // query the answer is for.
    if (
      msg.sender != address(oracle) ||
      _timestamp != requestTimestamp ||
      keccak256(_ancillaryData) != keccak256(bytes(query)) ||
      _identifier != queryIdentifier
    ) revert Unauthorized();

    OptimisticOracleV2Interface.Request memory _umaRequest;
    _umaRequest = oracle.getRequest(address(this), _identifier, _timestamp, _ancillaryData);

    // Revert if the answer was anything other than "YES". We don't want to be told
    // that a hack/exploit has *not* happened yet, or it cannot be determined, etc.
    if (_umaRequest.proposedPrice != AFFIRMATIVE_ANSWER) revert InvalidProposal();

    // Freeze the market and set so that funds cannot be withdrawn, since
    // there's now a real possibility that we are going to trigger.
    _updateTriggerState(CState.FROZEN);
  }

  /// @notice UMA callback for settlement. This code is run when the protocol
  /// has confirmed an answer to the query.
  /// @dev This callback is kept intentionally lean, as we don't want to risk
  /// reverting and blocking settlement.
  /// @param _identifier price identifier being requested.
  /// @param _timestamp timestamp of the original query request.
  /// @param _ancillaryData ancillary data of the original query request.
  /// @param _answer the oracle's answer to the query.
  function priceSettled(
    bytes32 _identifier,
    uint256 _timestamp,
    bytes memory _ancillaryData,
    int256 _answer
  ) external {

    // See `priceProposed` for why we authorize callers in this way.
    if (
      msg.sender != address(oracle) ||
      _timestamp != requestTimestamp ||
      keccak256(_ancillaryData) != keccak256(bytes(query)) ||
      _identifier != queryIdentifier
    ) revert Unauthorized();

    if (_answer == AFFIRMATIVE_ANSWER) {
      uint256 _rewardBalance = rewardToken.balanceOf(address(this));
      if (_rewardBalance > 0) rewardToken.safeTransfer(refundRecipient, _rewardBalance);
      _updateTriggerState(CState.TRIGGERED);
    } else {
      // If the answer was not affirmative, i.e. "Yes, the protocol was hacked",
      // the trigger should return to the ACTIVE state. And we need to resubmit
      // our query so that we are informed if the event we care about happens in
      // the future.
      _updateTriggerState(CState.ACTIVE);
      _submitRequestToOracle();
    }
  }

  /// @notice This function attempts to confirm and finalize (i.e. "settle") the
  /// answer to the query with the UMA oracle. It reverts with Unsettleable if
  /// it cannot settle the query, but does NOT revert if the oracle has already
  /// settled the query on its own. If the oracle's answer is an
  /// AFFIRMATIVE_ANSWER, this function will toggle the trigger and update
  /// associated markets.
  function runProgrammaticCheck() external returns (CState) {
    // Rather than revert when triggered, we simply return the state and exit.
    // Both behaviors are acceptable, but returning is friendlier to the caller
    // as they don't need to handle a revert and can simply parse the
    // transaction's logs to know if the call resulted in a state change.
    if (state == CState.TRIGGERED) return state;

    bool _oracleHasPrice = oracle.hasPrice(
      address(this),
      queryIdentifier,
      requestTimestamp,
      bytes(query)
    );

    if (!_oracleHasPrice) revert Unsettleable();

    OptimisticOracleV2Interface.Request memory _umaRequest = oracle.getRequest(
      address(this),
      queryIdentifier,
      requestTimestamp,
      bytes(query)
    );
    if (!_umaRequest.settled) {
      // Give the reward balance to the caller to make up for gas costs and
      // incentivize keeping markets in line with trigger state.
      refundRecipient = msg.sender;

      // `settle` will cause the oracle to call the trigger's `priceSettled` function.
      oracle.settle(
        address(this),
        queryIdentifier,
        requestTimestamp,
        bytes(query)
      );
    }

    // If the request settled as a result of this call, trigger.state will have
    // been updated in the priceSettled callback.
    return state;
  }
}