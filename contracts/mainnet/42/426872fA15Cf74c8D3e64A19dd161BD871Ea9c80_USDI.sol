// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.9;

/**
 * @dev This is an empty interface used to represent either ERC20-conforming token contracts or ETH (using the zero
 * address sentinel value). We're just relying on the fact that `interface` can be used to declare new address-like
 * types.
 *
 * This concept is unrelated to a Pool's Asset Managers.
 */
interface IAsset {
  // solhint-disable-previous-line no-empty-blocks
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.9;

interface IAuthorizer {
  /**
   * @dev Returns true if `account` can perform the action described by `actionId` in the contract `where`.
   */
  function canPerform(bytes32 actionId, address account, address where) external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma experimental ABIEncoderV2;

import "../IERC20.sol";
import "../IWETH.sol";
import "./ISignaturesValidator.sol";
import "./ITemporarilyPausable.sol";

import "./IAsset.sol";
import "./IAuthorizer.sol";
import "./IFlashLoanRecipient.sol";
import "./IProtocolFeesCollector.sol";

pragma solidity ^0.8.9;

/**
 * @dev Full external interface for the Vault core contract - no external or public methods exist in the contract that
 * don't override one of these declarations.
 */
interface IBalancerVault is ISignaturesValidator, ITemporarilyPausable {
  // Generalities about the Vault:
  //
  // - Whenever documentation refers to 'tokens', it strictly refers to ERC20-compliant token contracts. Tokens are
  // transferred out of the Vault by calling the `IERC20.transfer` function, and transferred in by calling
  // `IERC20.transferFrom`. In these cases, the sender must have previously allowed the Vault to use their tokens by
  // calling `IERC20.approve`. The only deviation from the ERC20 standard that is supported is functions not returning
  // a boolean value: in these scenarios, a non-reverting call is assumed to be successful.
  //
  // - All non-view functions in the Vault are non-reentrant: calling them while another one is mid-execution (e.g.
  // while execution control is transferred to a token contract during a swap) will result in a revert. View
  // functions can be called in a re-reentrant way, but doing so might cause them to return inconsistent results.
  // Contracts calling view functions in the Vault must make sure the Vault has not already been entered.
  //
  // - View functions revert if referring to either unregistered Pools, or unregistered tokens for registered Pools.

  // Authorizer
  //
  // Some system actions are permissioned, like setting and collecting protocol fees. This permissioning system exists
  // outside of the Vault in the Authorizer contract: the Vault simply calls the Authorizer to check if the caller
  // can perform a given action.

  /**
   * @dev Returns the Vault's Authorizer.
   */
  function getAuthorizer() external view returns (IAuthorizer);

  /**
   * @dev Sets a new Authorizer for the Vault. The caller must be allowed by the current Authorizer to do this.
   *
   * Emits an `AuthorizerChanged` event.
   */
  function setAuthorizer(IAuthorizer newAuthorizer) external;

  /**
   * @dev Emitted when a new authorizer is set by `setAuthorizer`.
   */
  event AuthorizerChanged(IAuthorizer indexed newAuthorizer);

  // Relayers
  //
  // Additionally, it is possible for an account to perform certain actions on behalf of another one, using their
  // Vault ERC20 allowance and Internal Balance. These accounts are said to be 'relayers' for these Vault functions,
  // and are expected to be smart contracts with sound authentication mechanisms. For an account to be able to wield
  // this power, two things must occur:
  //  - The Authorizer must grant the account the permission to be a relayer for the relevant Vault function. This
  //    means that Balancer governance must approve each individual contract to act as a relayer for the intended
  //    functions.
  //  - Each user must approve the relayer to act on their behalf.
  // This double protection means users cannot be tricked into approving malicious relayers (because they will not
  // have been allowed by the Authorizer via governance), nor can malicious relayers approved by a compromised
  // Authorizer or governance drain user funds, since they would also need to be approved by each individual user.

  /**
   * @dev Returns true if `user` has approved `relayer` to act as a relayer for them.
   */
  function hasApprovedRelayer(address user, address relayer) external view returns (bool);

  /**
   * @dev Allows `relayer` to act as a relayer for `sender` if `approved` is true, and disallows it otherwise.
   *
   * Emits a `RelayerApprovalChanged` event.
   */
  function setRelayerApproval(address sender, address relayer, bool approved) external;

  /**
   * @dev Emitted every time a relayer is approved or disapproved by `setRelayerApproval`.
   */
  event RelayerApprovalChanged(address indexed relayer, address indexed sender, bool approved);

  // Internal Balance
  //
  // Users can deposit tokens into the Vault, where they are allocated to their Internal Balance, and later
  // transferred or withdrawn. It can also be used as a source of tokens when joining Pools, as a destination
  // when exiting them, and as either when performing swaps. This usage of Internal Balance results in greatly reduced
  // gas costs when compared to relying on plain ERC20 transfers, leading to large savings for frequent users.
  //
  // Internal Balance management features batching, which means a single contract call can be used to perform multiple
  // operations of different kinds, with different senders and recipients, at once.

  /**
   * @dev Returns `user`'s Internal Balance for a set of tokens.
   */
  function getInternalBalance(address user, IERC20[] memory tokens) external view returns (uint256[] memory);

  /**
   * @dev Performs a set of user balance operations, which involve Internal Balance (deposit, withdraw or transfer)
   * and plain ERC20 transfers using the Vault's allowance. This last feature is particularly useful for relayers, as
   * it lets integrators reuse a user's Vault allowance.
   *
   * For each operation, if the caller is not `sender`, it must be an authorized relayer for them.
   */
  function manageUserBalance(UserBalanceOp[] memory ops) external payable;

  /**
     * @dev Data for `manageUserBalance` operations, which include the possibility for ETH to be sent and received
     without manual WETH wrapping or unwrapping.
     */
  struct UserBalanceOp {
    UserBalanceOpKind kind;
    IAsset asset;
    uint256 amount;
    address sender;
    address payable recipient;
  }

  // There are four possible operations in `manageUserBalance`:
  //
  // - DEPOSIT_INTERNAL
  // Increases the Internal Balance of the `recipient` account by transferring tokens from the corresponding
  // `sender`. The sender must have allowed the Vault to use their tokens via `IERC20.approve()`.
  //
  // ETH can be used by passing the ETH sentinel value as the asset and forwarding ETH in the call: it will be wrapped
  // and deposited as WETH. Any ETH amount remaining will be sent back to the caller (not the sender, which is
  // relevant for relayers).
  //
  // Emits an `InternalBalanceChanged` event.
  //
  //
  // - WITHDRAW_INTERNAL
  // Decreases the Internal Balance of the `sender` account by transferring tokens to the `recipient`.
  //
  // ETH can be used by passing the ETH sentinel value as the asset. This will deduct WETH instead, unwrap it and send
  // it to the recipient as ETH.
  //
  // Emits an `InternalBalanceChanged` event.
  //
  //
  // - TRANSFER_INTERNAL
  // Transfers tokens from the Internal Balance of the `sender` account to the Internal Balance of `recipient`.
  //
  // Reverts if the ETH sentinel value is passed.
  //
  // Emits an `InternalBalanceChanged` event.
  //
  //
  // - TRANSFER_EXTERNAL
  // Transfers tokens from `sender` to `recipient`, using the Vault's ERC20 allowance. This is typically used by
  // relayers, as it lets them reuse a user's Vault allowance.
  //
  // Reverts if the ETH sentinel value is passed.
  //
  // Emits an `ExternalBalanceTransfer` event.

  enum UserBalanceOpKind {
    DEPOSIT_INTERNAL,
    WITHDRAW_INTERNAL,
    TRANSFER_INTERNAL,
    TRANSFER_EXTERNAL
  }

  /**
   * @dev Emitted when a user's Internal Balance changes, either from calls to `manageUserBalance`, or through
   * interacting with Pools using Internal Balance.
   *
   * Because Internal Balance works exclusively with ERC20 tokens, ETH deposits and withdrawals will use the WETH
   * address.
   */
  event InternalBalanceChanged(address indexed user, IERC20 indexed token, int256 delta);

  /**
   * @dev Emitted when a user's Vault ERC20 allowance is used by the Vault to transfer tokens to an external account.
   */
  event ExternalBalanceTransfer(IERC20 indexed token, address indexed sender, address recipient, uint256 amount);

  // Pools
  //
  // There are three specialization settings for Pools, which allow for cheaper swaps at the cost of reduced
  // functionality:
  //
  //  - General: no specialization, suited for all Pools. IGeneralPool is used for swap request callbacks, passing the
  // balance of all tokens in the Pool. These Pools have the largest swap costs (because of the extra storage reads),
  // which increase with the number of registered tokens.
  //
  //  - Minimal Swap Info: IMinimalSwapInfoPool is used instead of IGeneralPool, which saves gas by only passing the
  // balance of the two tokens involved in the swap. This is suitable for some pricing algorithms, like the weighted
  // constant product one popularized by Balancer V1. Swap costs are smaller compared to general Pools, and are
  // independent of the number of registered tokens.
  //
  //  - Two Token: only allows two tokens to be registered. This achieves the lowest possible swap gas cost. Like
  // minimal swap info Pools, these are called via IMinimalSwapInfoPool.

  enum PoolSpecialization {
    GENERAL,
    MINIMAL_SWAP_INFO,
    TWO_TOKEN
  }

  /**
   * @dev Registers the caller account as a Pool with a given specialization setting. Returns the Pool's ID, which
   * is used in all Pool-related functions. Pools cannot be deregistered, nor can the Pool's specialization be
   * changed.
   *
   * The caller is expected to be a smart contract that implements either `IGeneralPool` or `IMinimalSwapInfoPool`,
   * depending on the chosen specialization setting. This contract is known as the Pool's contract.
   *
   * Note that the same contract may register itself as multiple Pools with unique Pool IDs, or in other words,
   * multiple Pools may share the same contract.
   *
   * Emits a `PoolRegistered` event.
   */
  function registerPool(PoolSpecialization specialization) external returns (bytes32);

  /**
   * @dev Emitted when a Pool is registered by calling `registerPool`.
   */
  event PoolRegistered(bytes32 indexed poolId, address indexed poolAddress, PoolSpecialization specialization);

  /**
   * @dev Returns a Pool's contract address and specialization setting.
   */
  function getPool(bytes32 poolId) external view returns (address, PoolSpecialization);

  /**
   * @dev Registers `tokens` for the `poolId` Pool. Must be called by the Pool's contract.
   *
   * Pools can only interact with tokens they have registered. Users join a Pool by transferring registered tokens,
   * exit by receiving registered tokens, and can only swap registered tokens.
   *
   * Each token can only be registered once. For Pools with the Two Token specialization, `tokens` must have a length
   * of two, that is, both tokens must be registered in the same `registerTokens` call, and they must be sorted in
   * ascending order.
   *
   * The `tokens` and `assetManagers` arrays must have the same length, and each entry in these indicates the Asset
   * Manager for the corresponding token. Asset Managers can manage a Pool's tokens via `managePoolBalance`,
   * depositing and withdrawing them directly, and can even set their balance to arbitrary amounts. They are therefore
   * expected to be highly secured smart contracts with sound design principles, and the decision to register an
   * Asset Manager should not be made lightly.
   *
   * Pools can choose not to assign an Asset Manager to a given token by passing in the zero address. Once an Asset
   * Manager is set, it cannot be changed except by deregistering the associated token and registering again with a
   * different Asset Manager.
   *
   * Emits a `TokensRegistered` event.
   */
  function registerTokens(bytes32 poolId, IERC20[] memory tokens, address[] memory assetManagers) external;

  /**
   * @dev Emitted when a Pool registers tokens by calling `registerTokens`.
   */
  event TokensRegistered(bytes32 indexed poolId, IERC20[] tokens, address[] assetManagers);

  /**
   * @dev Deregisters `tokens` for the `poolId` Pool. Must be called by the Pool's contract.
   *
   * Only registered tokens (via `registerTokens`) can be deregistered. Additionally, they must have zero total
   * balance. For Pools with the Two Token specialization, `tokens` must have a length of two, that is, both tokens
   * must be deregistered in the same `deregisterTokens` call.
   *
   * A deregistered token can be re-registered later on, possibly with a different Asset Manager.
   *
   * Emits a `TokensDeregistered` event.
   */
  function deregisterTokens(bytes32 poolId, IERC20[] memory tokens) external;

  /**
   * @dev Emitted when a Pool deregisters tokens by calling `deregisterTokens`.
   */
  event TokensDeregistered(bytes32 indexed poolId, IERC20[] tokens);

  /**
   * @dev Returns detailed information for a Pool's registered token.
   *
   * `cash` is the number of tokens the Vault currently holds for the Pool. `managed` is the number of tokens
   * withdrawn and held outside the Vault by the Pool's token Asset Manager. The Pool's total balance for `token`
   * equals the sum of `cash` and `managed`.
   *
   * Internally, `cash` and `managed` are stored using 112 bits. No action can ever cause a Pool's token `cash`,
   * `managed` or `total` balance to be greater than 2^112 - 1.
   *
   * `lastChangeBlock` is the number of the block in which `token`'s total balance was last modified (via either a
   * join, exit, swap, or Asset Manager update). This value is useful to avoid so-called 'sandwich attacks', for
   * example when developing price oracles. A change of zero (e.g. caused by a swap with amount zero) is considered a
   * change for this purpose, and will update `lastChangeBlock`.
   *
   * `assetManager` is the Pool's token Asset Manager.
   */
  function getPoolTokenInfo(
    bytes32 poolId,
    IERC20 token
  ) external view returns (uint256 cash, uint256 managed, uint256 lastChangeBlock, address assetManager);

  /**
   * @dev Returns a Pool's registered tokens, the total balance for each, and the latest block when *any* of
   * the tokens' `balances` changed.
   *
   * The order of the `tokens` array is the same order that will be used in `joinPool`, `exitPool`, as well as in all
   * Pool hooks (where applicable). Calls to `registerTokens` and `deregisterTokens` may change this order.
   *
   * If a Pool only registers tokens once, and these are sorted in ascending order, they will be stored in the same
   * order as passed to `registerTokens`.
   *
   * Total balances include both tokens held by the Vault and those withdrawn by the Pool's Asset Managers. These are
   * the amounts used by joins, exits and swaps. For a detailed breakdown of token balances, use `getPoolTokenInfo`
   * instead.
   */
  function getPoolTokens(
    bytes32 poolId
  ) external view returns (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock);

  /**
   * @dev Called by users to join a Pool, which transfers tokens from `sender` into the Pool's balance. This will
   * trigger custom Pool behavior, which will typically grant something in return to `recipient` - often tokenized
   * Pool shares.
   *
   * If the caller is not `sender`, it must be an authorized relayer for them.
   *
   * The `assets` and `maxAmountsIn` arrays must have the same length, and each entry indicates the maximum amount
   * to send for each asset. The amounts to send are decided by the Pool and not the Vault: it just enforces
   * these maximums.
   *
   * If joining a Pool that holds WETH, it is possible to send ETH directly: the Vault will do the wrapping. To enable
   * this mechanism, the IAsset sentinel value (the zero address) must be passed in the `assets` array instead of the
   * WETH address. Note that it is not possible to combine ETH and WETH in the same join. Any excess ETH will be sent
   * back to the caller (not the sender, which is important for relayers).
   *
   * `assets` must have the same length and order as the array returned by `getPoolTokens`. This prevents issues when
   * interacting with Pools that register and deregister tokens frequently. If sending ETH however, the array must be
   * sorted *before* replacing the WETH address with the ETH sentinel value (the zero address), which means the final
   * `assets` array might not be sorted. Pools with no registered tokens cannot be joined.
   *
   * If `fromInternalBalance` is true, the caller's Internal Balance will be preferred: ERC20 transfers will only
   * be made for the difference between the requested amount and Internal Balance (if any). Note that ETH cannot be
   * withdrawn from Internal Balance: attempting to do so will trigger a revert.
   *
   * This causes the Vault to call the `IBasePool.onJoinPool` hook on the Pool's contract, where Pools implement
   * their own custom logic. This typically requires additional information from the user (such as the expected number
   * of Pool shares). This can be encoded in the `userData` argument, which is ignored by the Vault and passed
   * directly to the Pool's contract, as is `recipient`.
   *
   * Emits a `PoolBalanceChanged` event.
   */
  function joinPool(bytes32 poolId, address sender, address recipient, JoinPoolRequest memory request) external payable;

  struct JoinPoolRequest {
    IAsset[] assets;
    uint256[] maxAmountsIn;
    bytes userData;
    bool fromInternalBalance;
  }

  /**
   * @dev Called by users to exit a Pool, which transfers tokens from the Pool's balance to `recipient`. This will
   * trigger custom Pool behavior, which will typically ask for something in return from `sender` - often tokenized
   * Pool shares. The amount of tokens that can be withdrawn is limited by the Pool's `cash` balance (see
   * `getPoolTokenInfo`).
   *
   * If the caller is not `sender`, it must be an authorized relayer for them.
   *
   * The `tokens` and `minAmountsOut` arrays must have the same length, and each entry in these indicates the minimum
   * token amount to receive for each token contract. The amounts to send are decided by the Pool and not the Vault:
   * it just enforces these minimums.
   *
   * If exiting a Pool that holds WETH, it is possible to receive ETH directly: the Vault will do the unwrapping. To
   * enable this mechanism, the IAsset sentinel value (the zero address) must be passed in the `assets` array instead
   * of the WETH address. Note that it is not possible to combine ETH and WETH in the same exit.
   *
   * `assets` must have the same length and order as the array returned by `getPoolTokens`. This prevents issues when
   * interacting with Pools that register and deregister tokens frequently. If receiving ETH however, the array must
   * be sorted *before* replacing the WETH address with the ETH sentinel value (the zero address), which means the
   * final `assets` array might not be sorted. Pools with no registered tokens cannot be exited.
   *
   * If `toInternalBalance` is true, the tokens will be deposited to `recipient`'s Internal Balance. Otherwise,
   * an ERC20 transfer will be performed. Note that ETH cannot be deposited to Internal Balance: attempting to
   * do so will trigger a revert.
   *
   * `minAmountsOut` is the minimum amount of tokens the user expects to get out of the Pool, for each token in the
   * `tokens` array. This array must match the Pool's registered tokens.
   *
   * This causes the Vault to call the `IBasePool.onExitPool` hook on the Pool's contract, where Pools implement
   * their own custom logic. This typically requires additional information from the user (such as the expected number
   * of Pool shares to return). This can be encoded in the `userData` argument, which is ignored by the Vault and
   * passed directly to the Pool's contract.
   *
   * Emits a `PoolBalanceChanged` event.
   */
  function exitPool(bytes32 poolId, address sender, address payable recipient, ExitPoolRequest memory request) external;

  struct ExitPoolRequest {
    IAsset[] assets;
    uint256[] minAmountsOut;
    bytes userData;
    bool toInternalBalance;
  }

  /**
   * @dev Emitted when a user joins or exits a Pool by calling `joinPool` or `exitPool`, respectively.
   */
  event PoolBalanceChanged(
    bytes32 indexed poolId,
    address indexed liquidityProvider,
    IERC20[] tokens,
    int256[] deltas,
    uint256[] protocolFeeAmounts
  );

  enum PoolBalanceChangeKind {
    JOIN,
    EXIT
  }

  // Swaps
  //
  // Users can swap tokens with Pools by calling the `swap` and `batchSwap` functions. To do this,
  // they need not trust Pool contracts in any way: all security checks are made by the Vault. They must however be
  // aware of the Pools' pricing algorithms in order to estimate the prices Pools will quote.
  //
  // The `swap` function executes a single swap, while `batchSwap` can perform multiple swaps in sequence.
  // In each individual swap, tokens of one kind are sent from the sender to the Pool (this is the 'token in'),
  // and tokens of another kind are sent from the Pool to the recipient in exchange (this is the 'token out').
  // More complex swaps, such as one token in to multiple tokens out can be achieved by batching together
  // individual swaps.
  //
  // There are two swap kinds:
  //  - 'given in' swaps, where the amount of tokens in (sent to the Pool) is known, and the Pool determines (via the
  // `onSwap` hook) the amount of tokens out (to send to the recipient).
  //  - 'given out' swaps, where the amount of tokens out (received from the Pool) is known, and the Pool determines
  // (via the `onSwap` hook) the amount of tokens in (to receive from the sender).
  //
  // Additionally, it is possible to chain swaps using a placeholder input amount, which the Vault replaces with
  // the calculated output of the previous swap. If the previous swap was 'given in', this will be the calculated
  // tokenOut amount. If the previous swap was 'given out', it will use the calculated tokenIn amount. These extended
  // swaps are known as 'multihop' swaps, since they 'hop' through a number of intermediate tokens before arriving at
  // the final intended token.
  //
  // In all cases, tokens are only transferred in and out of the Vault (or withdrawn from and deposited into Internal
  // Balance) after all individual swaps have been completed, and the net token balance change computed. This makes
  // certain swap patterns, such as multihops, or swaps that interact with the same token pair in multiple Pools, cost
  // much less gas than they would otherwise.
  //
  // It also means that under certain conditions it is possible to perform arbitrage by swapping with multiple
  // Pools in a way that results in net token movement out of the Vault (profit), with no tokens being sent in (only
  // updating the Pool's internal accounting).
  //
  // To protect users from front-running or the market changing rapidly, they supply a list of 'limits' for each token
  // involved in the swap, where either the maximum number of tokens to send (by passing a positive value) or the
  // minimum amount of tokens to receive (by passing a negative value) is specified.
  //
  // Additionally, a 'deadline' timestamp can also be provided, forcing the swap to fail if it occurs after
  // this point in time (e.g. if the transaction failed to be included in a block promptly).
  //
  // If interacting with Pools that hold WETH, it is possible to both send and receive ETH directly: the Vault will do
  // the wrapping and unwrapping. To enable this mechanism, the IAsset sentinel value (the zero address) must be
  // passed in the `assets` array instead of the WETH address. Note that it is possible to combine ETH and WETH in the
  // same swap. Any excess ETH will be sent back to the caller (not the sender, which is relevant for relayers).
  //
  // Finally, Internal Balance can be used when either sending or receiving tokens.

  enum SwapKind {
    GIVEN_IN,
    GIVEN_OUT
  }

  /**
   * @dev Performs a swap with a single Pool.
   *
   * If the swap is 'given in' (the number of tokens to send to the Pool is known), it returns the amount of tokens
   * taken from the Pool, which must be greater than or equal to `limit`.
   *
   * If the swap is 'given out' (the number of tokens to take from the Pool is known), it returns the amount of tokens
   * sent to the Pool, which must be less than or equal to `limit`.
   *
   * Internal Balance usage and the recipient are determined by the `funds` struct.
   *
   * Emits a `Swap` event.
   */
  function swap(
    SingleSwap memory singleSwap,
    FundManagement memory funds,
    uint256 limit,
    uint256 deadline
  ) external payable returns (uint256);

  /**
   * @dev Data for a single swap executed by `swap`. `amount` is either `amountIn` or `amountOut` depending on
   * the `kind` value.
   *
   * `assetIn` and `assetOut` are either token addresses, or the IAsset sentinel value for ETH (the zero address).
   * Note that Pools never interact with ETH directly: it will be wrapped to or unwrapped from WETH by the Vault.
   *
   * The `userData` field is ignored by the Vault, but forwarded to the Pool in the `onSwap` hook, and may be
   * used to extend swap behavior.
   */
  struct SingleSwap {
    bytes32 poolId;
    SwapKind kind;
    IAsset assetIn;
    IAsset assetOut;
    uint256 amount;
    bytes userData;
  }

  /**
   * @dev Performs a series of swaps with one or multiple Pools. In each individual swap, the caller determines either
   * the amount of tokens sent to or received from the Pool, depending on the `kind` value.
   *
   * Returns an array with the net Vault asset balance deltas. Positive amounts represent tokens (or ETH) sent to the
   * Vault, and negative amounts represent tokens (or ETH) sent by the Vault. Each delta corresponds to the asset at
   * the same index in the `assets` array.
   *
   * Swaps are executed sequentially, in the order specified by the `swaps` array. Each array element describes a
   * Pool, the token to be sent to this Pool, the token to receive from it, and an amount that is either `amountIn` or
   * `amountOut` depending on the swap kind.
   *
   * Multihop swaps can be executed by passing an `amount` value of zero for a swap. This will cause the amount in/out
   * of the previous swap to be used as the amount in for the current one. In a 'given in' swap, 'tokenIn' must equal
   * the previous swap's `tokenOut`. For a 'given out' swap, `tokenOut` must equal the previous swap's `tokenIn`.
   *
   * The `assets` array contains the addresses of all assets involved in the swaps. These are either token addresses,
   * or the IAsset sentinel value for ETH (the zero address). Each entry in the `swaps` array specifies tokens in and
   * out by referencing an index in `assets`. Note that Pools never interact with ETH directly: it will be wrapped to
   * or unwrapped from WETH by the Vault.
   *
   * Internal Balance usage, sender, and recipient are determined by the `funds` struct. The `limits` array specifies
   * the minimum or maximum amount of each token the vault is allowed to transfer.
   *
   * `batchSwap` can be used to make a single swap, like `swap` does, but doing so requires more gas than the
   * equivalent `swap` call.
   *
   * Emits `Swap` events.
   */
  function batchSwap(
    SwapKind kind,
    BatchSwapStep[] memory swaps,
    IAsset[] memory assets,
    FundManagement memory funds,
    int256[] memory limits,
    uint256 deadline
  ) external payable returns (int256[] memory);

  /**
   * @dev Data for each individual swap executed by `batchSwap`. The asset in and out fields are indexes into the
   * `assets` array passed to that function, and ETH assets are converted to WETH.
   *
   * If `amount` is zero, the multihop mechanism is used to determine the actual amount based on the amount in/out
   * from the previous swap, depending on the swap kind.
   *
   * The `userData` field is ignored by the Vault, but forwarded to the Pool in the `onSwap` hook, and may be
   * used to extend swap behavior.
   */
  struct BatchSwapStep {
    bytes32 poolId;
    uint256 assetInIndex;
    uint256 assetOutIndex;
    uint256 amount;
    bytes userData;
  }

  /**
   * @dev Emitted for each individual swap performed by `swap` or `batchSwap`.
   */
  event Swap(
    bytes32 indexed poolId,
    IERC20 indexed tokenIn,
    IERC20 indexed tokenOut,
    uint256 amountIn,
    uint256 amountOut
  );

  /**
   * @dev All tokens in a swap are either sent from the `sender` account to the Vault, or from the Vault to the
   * `recipient` account.
   *
   * If the caller is not `sender`, it must be an authorized relayer for them.
   *
   * If `fromInternalBalance` is true, the `sender`'s Internal Balance will be preferred, performing an ERC20
   * transfer for the difference between the requested amount and the User's Internal Balance (if any). The `sender`
   * must have allowed the Vault to use their tokens via `IERC20.approve()`. This matches the behavior of
   * `joinPool`.
   *
   * If `toInternalBalance` is true, tokens will be deposited to `recipient`'s internal balance instead of
   * transferred. This matches the behavior of `exitPool`.
   *
   * Note that ETH cannot be deposited to or withdrawn from Internal Balance: attempting to do so will trigger a
   * revert.
   */
  struct FundManagement {
    address sender;
    bool fromInternalBalance;
    address payable recipient;
    bool toInternalBalance;
  }

  /**
   * @dev Simulates a call to `batchSwap`, returning an array of Vault asset deltas. Calls to `swap` cannot be
   * simulated directly, but an equivalent `batchSwap` call can and will yield the exact same result.
   *
   * Each element in the array corresponds to the asset at the same index, and indicates the number of tokens (or ETH)
   * the Vault would take from the sender (if positive) or send to the recipient (if negative). The arguments it
   * receives are the same that an equivalent `batchSwap` call would receive.
   *
   * Unlike `batchSwap`, this function performs no checks on the sender or recipient field in the `funds` struct.
   * This makes it suitable to be called by off-chain applications via eth_call without needing to hold tokens,
   * approve them for the Vault, or even know a user's address.
   *
   * Note that this function is not 'view' (due to implementation details): the client code must explicitly execute
   * eth_call instead of eth_sendTransaction.
   */
  function queryBatchSwap(
    SwapKind kind,
    BatchSwapStep[] memory swaps,
    IAsset[] memory assets,
    FundManagement memory funds
  ) external returns (int256[] memory assetDeltas);

  // Flash Loans

  /**
   * @dev Performs a 'flash loan', sending tokens to `recipient`, executing the `receiveFlashLoan` hook on it,
   * and then reverting unless the tokens plus a proportional protocol fee have been returned.
   *
   * The `tokens` and `amounts` arrays must have the same length, and each entry in these indicates the loan amount
   * for each token contract. `tokens` must be sorted in ascending order.
   *
   * The 'userData' field is ignored by the Vault, and forwarded as-is to `recipient` as part of the
   * `receiveFlashLoan` call.
   *
   * Emits `FlashLoan` events.
   */
  function flashLoan(
    IFlashLoanRecipient recipient,
    IERC20[] memory tokens,
    uint256[] memory amounts,
    bytes memory userData
  ) external;

  /**
   * @dev Emitted for each individual flash loan performed by `flashLoan`.
   */
  event FlashLoan(IFlashLoanRecipient indexed recipient, IERC20 indexed token, uint256 amount, uint256 feeAmount);

  // Asset Management
  //
  // Each token registered for a Pool can be assigned an Asset Manager, which is able to freely withdraw the Pool's
  // tokens from the Vault, deposit them, or assign arbitrary values to its `managed` balance (see
  // `getPoolTokenInfo`). This makes them extremely powerful and dangerous. Even if an Asset Manager only directly
  // controls one of the tokens in a Pool, a malicious manager could set that token's balance to manipulate the
  // prices of the other tokens, and then drain the Pool with swaps. The risk of using Asset Managers is therefore
  // not constrained to the tokens they are managing, but extends to the entire Pool's holdings.
  //
  // However, a properly designed Asset Manager smart contract can be safely used for the Pool's benefit,
  // for example by lending unused tokens out for interest, or using them to participate in voting protocols.
  //
  // This concept is unrelated to the IAsset interface.

  /**
   * @dev Performs a set of Pool balance operations, which may be either withdrawals, deposits or updates.
   *
   * Pool Balance management features batching, which means a single contract call can be used to perform multiple
   * operations of different kinds, with different Pools and tokens, at once.
   *
   * For each operation, the caller must be registered as the Asset Manager for `token` in `poolId`.
   */
  function managePoolBalance(PoolBalanceOp[] memory ops) external;

  struct PoolBalanceOp {
    PoolBalanceOpKind kind;
    bytes32 poolId;
    IERC20 token;
    uint256 amount;
  }

  /**
   * Withdrawals decrease the Pool's cash, but increase its managed balance, leaving the total balance unchanged.
   *
   * Deposits increase the Pool's cash, but decrease its managed balance, leaving the total balance unchanged.
   *
   * Updates don't affect the Pool's cash balance, but because the managed balance changes, it does alter the total.
   * The external amount can be either increased or decreased by this call (i.e., reporting a gain or a loss).
   */
  enum PoolBalanceOpKind {
    WITHDRAW,
    DEPOSIT,
    UPDATE
  }

  /**
   * @dev Emitted when a Pool's token Asset Manager alters its balance via `managePoolBalance`.
   */
  event PoolBalanceManaged(
    bytes32 indexed poolId,
    address indexed assetManager,
    IERC20 indexed token,
    int256 cashDelta,
    int256 managedDelta
  );

  // Protocol Fees
  //
  // Some operations cause the Vault to collect tokens in the form of protocol fees, which can then be withdrawn by
  // permissioned accounts.
  //
  // There are two kinds of protocol fees:
  //
  //  - flash loan fees: charged on all flash loans, as a percentage of the amounts lent.
  //
  //  - swap fees: a percentage of the fees charged by Pools when performing swaps. For a number of reasons, including
  // swap gas costs and interface simplicity, protocol swap fees are not charged on each individual swap. Rather,
  // Pools are expected to keep track of how much they have charged in swap fees, and pay any outstanding debts to the
  // Vault when they are joined or exited. This prevents users from joining a Pool with unpaid debt, as well as
  // exiting a Pool in debt without first paying their share.

  /**
   * @dev Returns the current protocol fee module.
   */
  function getProtocolFeesCollector() external view returns (IProtocolFeesCollector);

  /**
   * @dev Safety mechanism to pause most Vault operations in the event of an emergency - typically detection of an
   * error in some part of the system.
   *
   * The Vault can only be paused during an initial time period, after which pausing is forever disabled.
   *
   * While the contract is paused, the following features are disabled:
   * - depositing and transferring internal balance
   * - transferring external balance (using the Vault's allowance)
   * - swaps
   * - joining Pools
   * - Asset Manager interactions
   *
   * Internal Balance can still be withdrawn, and Pools exited.
   */
  function setPaused(bool paused) external;

  /**
   * @dev Returns the Vault's WETH instance.
   */
  function WETH() external view returns (IWETH);
  // solhint-disable-previous-line func-name-mixedcase
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.9;

// Inspired by Aave Protocol's IFlashLoanReceiver.

import "../IERC20.sol";

interface IFlashLoanRecipient {
  /**
   * @dev When `flashLoan` is called on the Vault, it invokes the `receiveFlashLoan` hook on the recipient.
   *
   * At the time of the call, the Vault will have transferred `amounts` for `tokens` to the recipient. Before this
   * call returns, the recipient must have transferred `amounts` plus `feeAmounts` for each token back to the
   * Vault, or else the entire flash loan will revert.
   *
   * `userData` is the same value passed in the `IVault.flashLoan` call.
   */
  function receiveFlashLoan(
    IERC20[] memory tokens,
    uint256[] memory amounts,
    uint256[] memory feeAmounts,
    bytes memory userData
  ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IERC20.sol";

interface IGauge is IERC20 {
  function deposit(uint256 _value) external;

  function withdraw(uint256 _value) external;

  function withdraw(uint256 _value, bool _claim_rewards) external;

  function claim_rewards() external;

  function claim_rewards(address _addr) external;

  function claim_rewards(address _addr, address _receiver) external;

  function claimable_reward(address _user, address _reward_token) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import "../IERC20.sol";

import "./IBalancerVault.sol";
import "./IAuthorizer.sol";

interface IProtocolFeesCollector {
  event SwapFeePercentageChanged(uint256 newSwapFeePercentage);
  event FlashLoanFeePercentageChanged(uint256 newFlashLoanFeePercentage);

  function withdrawCollectedFees(IERC20[] calldata tokens, uint256[] calldata amounts, address recipient) external;

  function setSwapFeePercentage(uint256 newSwapFeePercentage) external;

  function setFlashLoanFeePercentage(uint256 newFlashLoanFeePercentage) external;

  function getSwapFeePercentage() external view returns (uint256);

  function getFlashLoanFeePercentage() external view returns (uint256);

  function getCollectedFeeAmounts(IERC20[] memory tokens) external view returns (uint256[] memory feeAmounts);

  function getAuthorizer() external view returns (IAuthorizer);

  function vault() external view returns (IBalancerVault);
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.9;

/**
 * @dev Interface for the SignatureValidator helper, used to support meta-transactions.
 */
interface ISignaturesValidator {
  /**
   * @dev Returns the EIP712 domain separator.
   */
  function getDomainSeparator() external view returns (bytes32);

  /**
   * @dev Returns the next nonce used by an address to sign messages.
   */
  function getNextNonce(address user) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.9;

/**
 * @dev Interface for the TemporarilyPausable helper.
 */
interface ITemporarilyPausable {
  /**
   * @dev Emitted every time the pause state changes by `_setPaused`.
   */
  event PausedStateChanged(bool paused);

  /**
   * @dev Returns the current paused state.
   */
  function getPausedState()
    external
    view
    returns (bool paused, uint256 pauseWindowEndTime, uint256 bufferPeriodEndTime);
}

// SPDX-License-Identifier: MIT
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the “Software”), to deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.

// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

pragma solidity ^0.8.0;

/* solhint-disable */

/**
 * @dev Exponentiation and logarithm functions for 18 decimal fixed point numbers (both base and exponent/argument).
 *
 * Exponentiation and logarithm with arbitrary bases (x^y and log_x(y)) are implemented by conversion to natural
 * exponentiation and logarithm (where the base is Euler's number).
 *
 * @author Fernando Martinelli - @fernandomartinelli
 * @author Sergio Yuhjtman - @sergioyuhjtman
 * @author Daniel Fernandez - @dmf7z
 */
library LogExpMath {
  // All fixed point multiplications and divisions are inlined. This means we need to divide by ONE when multiplying
  // two numbers, and multiply by ONE when dividing them.

  // All arguments and return values are 18 decimal fixed point numbers.
  int256 constant ONE_18 = 1e18;

  // Internally, intermediate values are computed with higher precision as 20 decimal fixed point numbers, and in the
  // case of ln36, 36 decimals.
  int256 constant ONE_20 = 1e20;
  int256 constant ONE_36 = 1e36;

  // The domain of natural exponentiation is bound by the word size and number of decimals used.
  //
  // Because internally the result will be stored using 20 decimals, the largest possible result is
  // (2^255 - 1) / 10^20, which makes the largest exponent ln((2^255 - 1) / 10^20) = 130.700829182905140221.
  // The smallest possible result is 10^(-18), which makes largest negative argument
  // ln(10^(-18)) = -41.446531673892822312.
  // We use 130.0 and -41.0 to have some safety margin.
  int256 constant MAX_NATURAL_EXPONENT = 130e18;
  int256 constant MIN_NATURAL_EXPONENT = -41e18;

  // Bounds for ln_36's argument. Both ln(0.9) and ln(1.1) can be represented with 36 decimal places in a fixed point
  // 256 bit integer.
  int256 constant LN_36_LOWER_BOUND = ONE_18 - 1e17;
  int256 constant LN_36_UPPER_BOUND = ONE_18 + 1e17;

  uint256 constant MILD_EXPONENT_BOUND = 2 ** 254 / uint256(ONE_20);

  // 18 decimal constants
  int256 constant x0 = 128000000000000000000; // 2ˆ7
  int256 constant a0 = 38877084059945950922200000000000000000000000000000000000; // eˆ(x0) (no decimals)
  int256 constant x1 = 64000000000000000000; // 2ˆ6
  int256 constant a1 = 6235149080811616882910000000; // eˆ(x1) (no decimals)

  // 20 decimal constants
  int256 constant x2 = 3200000000000000000000; // 2ˆ5
  int256 constant a2 = 7896296018268069516100000000000000; // eˆ(x2)
  int256 constant x3 = 1600000000000000000000; // 2ˆ4
  int256 constant a3 = 888611052050787263676000000; // eˆ(x3)
  int256 constant x4 = 800000000000000000000; // 2ˆ3
  int256 constant a4 = 298095798704172827474000; // eˆ(x4)
  int256 constant x5 = 400000000000000000000; // 2ˆ2
  int256 constant a5 = 5459815003314423907810; // eˆ(x5)
  int256 constant x6 = 200000000000000000000; // 2ˆ1
  int256 constant a6 = 738905609893065022723; // eˆ(x6)
  int256 constant x7 = 100000000000000000000; // 2ˆ0
  int256 constant a7 = 271828182845904523536; // eˆ(x7)
  int256 constant x8 = 50000000000000000000; // 2ˆ-1
  int256 constant a8 = 164872127070012814685; // eˆ(x8)
  int256 constant x9 = 25000000000000000000; // 2ˆ-2
  int256 constant a9 = 128402541668774148407; // eˆ(x9)
  int256 constant x10 = 12500000000000000000; // 2ˆ-3
  int256 constant a10 = 113314845306682631683; // eˆ(x10)
  int256 constant x11 = 6250000000000000000; // 2ˆ-4
  int256 constant a11 = 106449445891785942956; // eˆ(x11)

  /**
   * @dev Exponentiation (x^y) with unsigned 18 decimal fixed point base and exponent.
   *
   * Reverts if ln(x) * y is smaller than `MIN_NATURAL_EXPONENT`, or larger than `MAX_NATURAL_EXPONENT`.
   */
  function pow(uint256 x, uint256 y) internal pure returns (uint256) {
    if (y == 0) {
      // We solve the 0^0 indetermination by making it equal one.
      return uint256(ONE_18);
    }

    if (x == 0) {
      return 0;
    }

    // Instead of computing x^y directly, we instead rely on the properties of logarithms and exponentiation to
    // arrive at that result. In particular, exp(ln(x)) = x, and ln(x^y) = y * ln(x). This means
    // x^y = exp(y * ln(x)).

    // The ln function takes a signed value, so we need to make sure x fits in the signed 256 bit range.
    require(x < 2 ** 255, "X_OUT_OF_BOUNDS");
    int256 x_int256 = int256(x);

    // We will compute y * ln(x) in a single step. Depending on the value of x, we can either use ln or ln_36. In
    // both cases, we leave the division by ONE_18 (due to fixed point multiplication) to the end.

    // This prevents y * ln(x) from overflowing, and at the same time guarantees y fits in the signed 256 bit range.
    require(y < MILD_EXPONENT_BOUND, "Y_OUT_OF_BOUNDS");
    int256 y_int256 = int256(y);

    int256 logx_times_y;
    if (LN_36_LOWER_BOUND < x_int256 && x_int256 < LN_36_UPPER_BOUND) {
      int256 ln_36_x = _ln_36(x_int256);

      // ln_36_x has 36 decimal places, so multiplying by y_int256 isn't as straightforward, since we can't just
      // bring y_int256 to 36 decimal places, as it might overflow. Instead, we perform two 18 decimal
      // multiplications and add the results: one with the first 18 decimals of ln_36_x, and one with the
      // (downscaled) last 18 decimals.
      logx_times_y = ((ln_36_x / ONE_18) * y_int256 + ((ln_36_x % ONE_18) * y_int256) / ONE_18);
    } else {
      logx_times_y = _ln(x_int256) * y_int256;
    }
    logx_times_y /= ONE_18;

    // Finally, we compute exp(y * ln(x)) to arrive at x^y
    require(MIN_NATURAL_EXPONENT <= logx_times_y && logx_times_y <= MAX_NATURAL_EXPONENT, "PRODUCT_OUT_OF_BOUNDS");

    return uint256(exp(logx_times_y));
  }

  /**
   * @dev Natural exponentiation (e^x) with signed 18 decimal fixed point exponent.
   *
   * Reverts if `x` is smaller than MIN_NATURAL_EXPONENT, or larger than `MAX_NATURAL_EXPONENT`.
   */
  function exp(int256 x) internal pure returns (int256) {
    require(x >= MIN_NATURAL_EXPONENT && x <= MAX_NATURAL_EXPONENT, "INVALID_EXPONENT");

    if (x < 0) {
      // We only handle positive exponents: e^(-x) is computed as 1 / e^x. We can safely make x positive since it
      // fits in the signed 256 bit range (as it is larger than MIN_NATURAL_EXPONENT).
      // Fixed point division requires multiplying by ONE_18.
      return ((ONE_18 * ONE_18) / exp(-x));
    }

    // First, we use the fact that e^(x+y) = e^x * e^y to decompose x into a sum of powers of two, which we call x_n,
    // where x_n == 2^(7 - n), and e^x_n = a_n has been precomputed. We choose the first x_n, x0, to equal 2^7
    // because all larger powers are larger than MAX_NATURAL_EXPONENT, and therefore not present in the
    // decomposition.
    // At the end of this process we will have the product of all e^x_n = a_n that apply, and the remainder of this
    // decomposition, which will be lower than the smallest x_n.
    // exp(x) = k_0 * a_0 * k_1 * a_1 * ... + k_n * a_n * exp(remainder), where each k_n equals either 0 or 1.
    // We mutate x by subtracting x_n, making it the remainder of the decomposition.

    // The first two a_n (e^(2^7) and e^(2^6)) are too large if stored as 18 decimal numbers, and could cause
    // intermediate overflows. Instead we store them as plain integers, with 0 decimals.
    // Additionally, x0 + x1 is larger than MAX_NATURAL_EXPONENT, which means they will not both be present in the
    // decomposition.

    // For each x_n, we test if that term is present in the decomposition (if x is larger than it), and if so deduct
    // it and compute the accumulated product.

    int256 firstAN;
    if (x >= x0) {
      x -= x0;
      firstAN = a0;
    } else if (x >= x1) {
      x -= x1;
      firstAN = a1;
    } else {
      firstAN = 1; // One with no decimal places
    }

    // We now transform x into a 20 decimal fixed point number, to have enhanced precision when computing the
    // smaller terms.
    x *= 100;

    // `product` is the accumulated product of all a_n (except a0 and a1), which starts at 20 decimal fixed point
    // one. Recall that fixed point multiplication requires dividing by ONE_20.
    int256 product = ONE_20;

    if (x >= x2) {
      x -= x2;
      product = (product * a2) / ONE_20;
    }
    if (x >= x3) {
      x -= x3;
      product = (product * a3) / ONE_20;
    }
    if (x >= x4) {
      x -= x4;
      product = (product * a4) / ONE_20;
    }
    if (x >= x5) {
      x -= x5;
      product = (product * a5) / ONE_20;
    }
    if (x >= x6) {
      x -= x6;
      product = (product * a6) / ONE_20;
    }
    if (x >= x7) {
      x -= x7;
      product = (product * a7) / ONE_20;
    }
    if (x >= x8) {
      x -= x8;
      product = (product * a8) / ONE_20;
    }
    if (x >= x9) {
      x -= x9;
      product = (product * a9) / ONE_20;
    }

    // x10 and x11 are unnecessary here since we have high enough precision already.

    // Now we need to compute e^x, where x is small (in particular, it is smaller than x9). We use the Taylor series
    // expansion for e^x: 1 + x + (x^2 / 2!) + (x^3 / 3!) + ... + (x^n / n!).

    int256 seriesSum = ONE_20; // The initial one in the sum, with 20 decimal places.
    int256 term; // Each term in the sum, where the nth term is (x^n / n!).

    // The first term is simply x.
    term = x;
    seriesSum += term;

    // Each term (x^n / n!) equals the previous one times x, divided by n. Since x is a fixed point number,
    // multiplying by it requires dividing by ONE_20, but dividing by the non-fixed point n values does not.

    term = ((term * x) / ONE_20) / 2;
    seriesSum += term;

    term = ((term * x) / ONE_20) / 3;
    seriesSum += term;

    term = ((term * x) / ONE_20) / 4;
    seriesSum += term;

    term = ((term * x) / ONE_20) / 5;
    seriesSum += term;

    term = ((term * x) / ONE_20) / 6;
    seriesSum += term;

    term = ((term * x) / ONE_20) / 7;
    seriesSum += term;

    term = ((term * x) / ONE_20) / 8;
    seriesSum += term;

    term = ((term * x) / ONE_20) / 9;
    seriesSum += term;

    term = ((term * x) / ONE_20) / 10;
    seriesSum += term;

    term = ((term * x) / ONE_20) / 11;
    seriesSum += term;

    term = ((term * x) / ONE_20) / 12;
    seriesSum += term;

    // 12 Taylor terms are sufficient for 18 decimal precision.

    // We now have the first a_n (with no decimals), and the product of all other a_n present, and the Taylor
    // approximation of the exponentiation of the remainder (both with 20 decimals). All that remains is to multiply
    // all three (one 20 decimal fixed point multiplication, dividing by ONE_20, and one integer multiplication),
    // and then drop two digits to return an 18 decimal value.

    return (((product * seriesSum) / ONE_20) * firstAN) / 100;
  }

  /**
   * @dev Logarithm (log(arg, base), with signed 18 decimal fixed point base and argument.
   */
  function log(int256 arg, int256 base) internal pure returns (int256) {
    // This performs a simple base change: log(arg, base) = ln(arg) / ln(base).

    // Both logBase and logArg are computed as 36 decimal fixed point numbers, either by using ln_36, or by
    // upscaling.

    int256 logBase;
    if (LN_36_LOWER_BOUND < base && base < LN_36_UPPER_BOUND) {
      logBase = _ln_36(base);
    } else {
      logBase = _ln(base) * ONE_18;
    }

    int256 logArg;
    if (LN_36_LOWER_BOUND < arg && arg < LN_36_UPPER_BOUND) {
      logArg = _ln_36(arg);
    } else {
      logArg = _ln(arg) * ONE_18;
    }

    // When dividing, we multiply by ONE_18 to arrive at a result with 18 decimal places
    return (logArg * ONE_18) / logBase;
  }

  /**
   * @dev Natural logarithm (ln(a)) with signed 18 decimal fixed point argument.
   */
  function ln(int256 a) internal pure returns (int256) {
    // The real natural logarithm is not defined for negative numbers or zero.
    require(a > 0, "OUT_OF_BOUNDS");
    if (LN_36_LOWER_BOUND < a && a < LN_36_UPPER_BOUND) {
      return _ln_36(a) / ONE_18;
    } else {
      return _ln(a);
    }
  }

  /**
   * @dev Internal natural logarithm (ln(a)) with signed 18 decimal fixed point argument.
   */
  function _ln(int256 a) private pure returns (int256) {
    if (a < ONE_18) {
      // Since ln(a^k) = k * ln(a), we can compute ln(a) as ln(a) = ln((1/a)^(-1)) = - ln((1/a)). If a is less
      // than one, 1/a will be greater than one, and this if statement will not be entered in the recursive call.
      // Fixed point division requires multiplying by ONE_18.
      return (-_ln((ONE_18 * ONE_18) / a));
    }

    // First, we use the fact that ln^(a * b) = ln(a) + ln(b) to decompose ln(a) into a sum of powers of two, which
    // we call x_n, where x_n == 2^(7 - n), which are the natural logarithm of precomputed quantities a_n (that is,
    // ln(a_n) = x_n). We choose the first x_n, x0, to equal 2^7 because the exponential of all larger powers cannot
    // be represented as 18 fixed point decimal numbers in 256 bits, and are therefore larger than a.
    // At the end of this process we will have the sum of all x_n = ln(a_n) that apply, and the remainder of this
    // decomposition, which will be lower than the smallest a_n.
    // ln(a) = k_0 * x_0 + k_1 * x_1 + ... + k_n * x_n + ln(remainder), where each k_n equals either 0 or 1.
    // We mutate a by subtracting a_n, making it the remainder of the decomposition.

    // For reasons related to how `exp` works, the first two a_n (e^(2^7) and e^(2^6)) are not stored as fixed point
    // numbers with 18 decimals, but instead as plain integers with 0 decimals, so we need to multiply them by
    // ONE_18 to convert them to fixed point.
    // For each a_n, we test if that term is present in the decomposition (if a is larger than it), and if so divide
    // by it and compute the accumulated sum.

    int256 sum = 0;
    if (a >= a0 * ONE_18) {
      a /= a0; // Integer, not fixed point division
      sum += x0;
    }

    if (a >= a1 * ONE_18) {
      a /= a1; // Integer, not fixed point division
      sum += x1;
    }

    // All other a_n and x_n are stored as 20 digit fixed point numbers, so we convert the sum and a to this format.
    sum *= 100;
    a *= 100;

    // Because further a_n are  20 digit fixed point numbers, we multiply by ONE_20 when dividing by them.

    if (a >= a2) {
      a = (a * ONE_20) / a2;
      sum += x2;
    }

    if (a >= a3) {
      a = (a * ONE_20) / a3;
      sum += x3;
    }

    if (a >= a4) {
      a = (a * ONE_20) / a4;
      sum += x4;
    }

    if (a >= a5) {
      a = (a * ONE_20) / a5;
      sum += x5;
    }

    if (a >= a6) {
      a = (a * ONE_20) / a6;
      sum += x6;
    }

    if (a >= a7) {
      a = (a * ONE_20) / a7;
      sum += x7;
    }

    if (a >= a8) {
      a = (a * ONE_20) / a8;
      sum += x8;
    }

    if (a >= a9) {
      a = (a * ONE_20) / a9;
      sum += x9;
    }

    if (a >= a10) {
      a = (a * ONE_20) / a10;
      sum += x10;
    }

    if (a >= a11) {
      a = (a * ONE_20) / a11;
      sum += x11;
    }

    // a is now a small number (smaller than a_11, which roughly equals 1.06). This means we can use a Taylor series
    // that converges rapidly for values of `a` close to one - the same one used in ln_36.
    // Let z = (a - 1) / (a + 1).
    // ln(a) = 2 * (z + z^3 / 3 + z^5 / 5 + z^7 / 7 + ... + z^(2 * n + 1) / (2 * n + 1))

    // Recall that 20 digit fixed point division requires multiplying by ONE_20, and multiplication requires
    // division by ONE_20.
    int256 z = ((a - ONE_20) * ONE_20) / (a + ONE_20);
    int256 z_squared = (z * z) / ONE_20;

    // num is the numerator of the series: the z^(2 * n + 1) term
    int256 num = z;

    // seriesSum holds the accumulated sum of each term in the series, starting with the initial z
    int256 seriesSum = num;

    // In each step, the numerator is multiplied by z^2
    num = (num * z_squared) / ONE_20;
    seriesSum += num / 3;

    num = (num * z_squared) / ONE_20;
    seriesSum += num / 5;

    num = (num * z_squared) / ONE_20;
    seriesSum += num / 7;

    num = (num * z_squared) / ONE_20;
    seriesSum += num / 9;

    num = (num * z_squared) / ONE_20;
    seriesSum += num / 11;

    // 6 Taylor terms are sufficient for 36 decimal precision.

    // Finally, we multiply by 2 (non fixed point) to compute ln(remainder)
    seriesSum *= 2;

    // We now have the sum of all x_n present, and the Taylor approximation of the logarithm of the remainder (both
    // with 20 decimals). All that remains is to sum these two, and then drop two digits to return a 18 decimal
    // value.

    return (sum + seriesSum) / 100;
  }

  /**
   * @dev Intrnal high precision (36 decimal places) natural logarithm (ln(x)) with signed 18 decimal fixed point argument,
   * for x close to one.
   *
   * Should only be used if x is between LN_36_LOWER_BOUND and LN_36_UPPER_BOUND.
   */
  function _ln_36(int256 x) private pure returns (int256) {
    // Since ln(1) = 0, a value of x close to one will yield a very small result, which makes using 36 digits
    // worthwhile.

    // First, we transform x to a 36 digit fixed point value.
    x *= ONE_18;

    // We will use the following Taylor expansion, which converges very rapidly. Let z = (x - 1) / (x + 1).
    // ln(x) = 2 * (z + z^3 / 3 + z^5 / 5 + z^7 / 7 + ... + z^(2 * n + 1) / (2 * n + 1))

    // Recall that 36 digit fixed point division requires multiplying by ONE_36, and multiplication requires
    // division by ONE_36.
    int256 z = ((x - ONE_36) * ONE_36) / (x + ONE_36);
    int256 z_squared = (z * z) / ONE_36;

    // num is the numerator of the series: the z^(2 * n + 1) term
    int256 num = z;

    // seriesSum holds the accumulated sum of each term in the series, starting with the initial z
    int256 seriesSum = num;

    // In each step, the numerator is multiplied by z^2
    num = (num * z_squared) / ONE_36;
    seriesSum += num / 3;

    num = (num * z_squared) / ONE_36;
    seriesSum += num / 5;

    num = (num * z_squared) / ONE_36;
    seriesSum += num / 7;

    num = (num * z_squared) / ONE_36;
    seriesSum += num / 9;

    num = (num * z_squared) / ONE_36;
    seriesSum += num / 11;

    num = (num * z_squared) / ONE_36;
    seriesSum += num / 13;

    num = (num * z_squared) / ONE_36;
    seriesSum += num / 15;

    // 8 Taylor terms are sufficient for 36 decimal precision.

    // All that remains is multiplying by 2 (non fixed point).
    return seriesSum * 2;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IAggregator {
  function latestAnswer() external view returns (int256);

  function latestTimestamp() external view returns (uint256);

  function latestRound() external view returns (uint256);

  function getAnswer(uint256 roundId) external view returns (int256);

  function getTimestamp(uint256 roundId) external view returns (uint256);

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface CompLike {
  function delegate(address delegatee) external;
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title Careful Math
 * @author Compound
 * @notice Derived from OpenZeppelin's SafeMath library
 *         https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/math/SafeMath.sol
 */
contract CarefulMath {
  /**
   * @dev Possible error codes that we can return
   */
  enum MathError {
    NO_ERROR,
    DIVISION_BY_ZERO,
    INTEGER_OVERFLOW,
    INTEGER_UNDERFLOW
  }

  /**
   * @dev Multiplies two numbers, returns an error on overflow.
   */
  function mulUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
    if (a == 0) {
      return (MathError.NO_ERROR, 0);
    }

    uint256 c = a * b;

    if (c / a != b) {
      return (MathError.INTEGER_OVERFLOW, 0);
    } else {
      return (MathError.NO_ERROR, c);
    }
  }

  /**
   * @dev Integer division of two numbers, truncating the quotient.
   */
  function divUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
    if (b == 0) {
      return (MathError.DIVISION_BY_ZERO, 0);
    }

    return (MathError.NO_ERROR, a / b);
  }

  /**
   * @dev Subtracts two numbers, returns an error on overflow (i.e. if subtrahend is greater than minuend).
   */
  function subUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
    if (b <= a) {
      return (MathError.NO_ERROR, a - b);
    } else {
      return (MathError.INTEGER_UNDERFLOW, 0);
    }
  }

  /**
   * @dev Adds two numbers, returns an error on overflow.
   */
  function addUInt(uint256 a, uint256 b) internal pure returns (MathError, uint256) {
    uint256 c = a + b;

    if (c >= a) {
      return (MathError.NO_ERROR, c);
    } else {
      return (MathError.INTEGER_OVERFLOW, 0);
    }
  }

  /**
   * @dev add a and b and then subtract c
   */
  function addThenSubUInt(uint256 a, uint256 b, uint256 c) internal pure returns (MathError, uint256) {
    (MathError err0, uint256 sum) = addUInt(a, b);

    if (err0 != MathError.NO_ERROR) {
      return (err0, 0);
    }

    return subUInt(sum, c);
  }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title Exponential module for storing fixed-precision decimals
 * @author Compound
 * @notice Exp is a struct which stores decimals with a fixed precision of 18 decimal places.
 *         Thus, if we wanted to store the 5.1, mantissa would store 5.1e18. That is:
 *         `Exp({mantissa: 5100000000000000000})`.
 */
contract ExponentialNoError {
  uint256 constant expScale = 1e18;
  uint256 constant doubleScale = 1e36;
  uint256 constant halfExpScale = expScale / 2;
  uint256 constant mantissaOne = expScale;
  uint256 constant uint192Max = 2 ** 192 - 1;
  uint256 constant uint128Max = 2 ** 128 - 1;

  struct Exp {
    uint256 mantissa;
  }

  struct Double {
    uint256 mantissa;
  }

  /**
   * @dev Truncates the given exp to a whole number value.
   *      For example, truncate(Exp{mantissa: 15 * expScale}) = 15
   */
  function truncate(Exp memory exp) internal pure returns (uint256) {
    return exp.mantissa / expScale;
  }

  function truncate(uint256 u) internal pure returns (uint256) {
    return u / expScale;
  }

  function safeu192(uint256 u) internal pure returns (uint192) {
    require(u < uint192Max, "overflow");
    return uint192(u);
  }

  function safeu128(uint256 u) internal pure returns (uint128) {
    require(u < uint128Max, "overflow");
    return uint128(u);
  }

  /**
   * @dev Multiply an Exp by a scalar, then truncate to return an unsigned integer.
   */
  function mul_ScalarTruncate(Exp memory a, uint256 scalar) internal pure returns (uint256) {
    Exp memory product = mul_(a, scalar);
    return truncate(product);
  }

  /**
   * @dev Multiply an Exp by a scalar, truncate, then add an to an unsigned integer, returning an unsigned integer.
   */
  function mul_ScalarTruncateAddUInt(Exp memory a, uint256 scalar, uint256 addend) internal pure returns (uint256) {
    Exp memory product = mul_(a, scalar);
    return add_(truncate(product), addend);
  }

  /**
   * @dev Checks if first Exp is less than second Exp.
   */
  function lessThanExp(Exp memory left, Exp memory right) internal pure returns (bool) {
    return left.mantissa < right.mantissa;
  }

  /**
   * @dev Checks if left Exp <= right Exp.
   */
  function lessThanOrEqualExp(Exp memory left, Exp memory right) internal pure returns (bool) {
    return left.mantissa <= right.mantissa;
  }

  /**
   * @dev Checks if left Exp > right Exp.
   */
  function greaterThanExp(Exp memory left, Exp memory right) internal pure returns (bool) {
    return left.mantissa > right.mantissa;
  }

  /**
   * @dev returns true if Exp is exactly zero
   */
  function isZeroExp(Exp memory value) internal pure returns (bool) {
    return value.mantissa == 0;
  }

  function safe224(uint256 n, string memory errorMessage) internal pure returns (uint224) {
    require(n < 2 ** 224, errorMessage);
    return uint224(n);
  }

  function safe32(uint256 n, string memory errorMessage) internal pure returns (uint32) {
    require(n < 2 ** 32, errorMessage);
    return uint32(n);
  }

  function add_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
    return Exp({mantissa: add_(a.mantissa, b.mantissa)});
  }

  function add_(Double memory a, Double memory b) internal pure returns (Double memory) {
    return Double({mantissa: add_(a.mantissa, b.mantissa)});
  }

  function add_(uint256 a, uint256 b) internal pure returns (uint256) {
    return add_(a, b, "addition overflow");
  }

  function add_(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, errorMessage);
    return c;
  }

  function sub_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
    return Exp({mantissa: sub_(a.mantissa, b.mantissa)});
  }

  function sub_(Double memory a, Double memory b) internal pure returns (Double memory) {
    return Double({mantissa: sub_(a.mantissa, b.mantissa)});
  }

  function sub_(uint256 a, uint256 b) internal pure returns (uint256) {
    return sub_(a, b, "subtraction underflow");
  }

  function sub_(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b <= a, errorMessage);
    return a - b;
  }

  function mul_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
    return Exp({mantissa: mul_(a.mantissa, b.mantissa) / expScale});
  }

  function mul_(Exp memory a, uint256 b) internal pure returns (Exp memory) {
    return Exp({mantissa: mul_(a.mantissa, b)});
  }

  function mul_(uint256 a, Exp memory b) internal pure returns (uint256) {
    return mul_(a, b.mantissa) / expScale;
  }

  function mul_(Double memory a, Double memory b) internal pure returns (Double memory) {
    return Double({mantissa: mul_(a.mantissa, b.mantissa) / doubleScale});
  }

  function mul_(Double memory a, uint256 b) internal pure returns (Double memory) {
    return Double({mantissa: mul_(a.mantissa, b)});
  }

  function mul_(uint256 a, Double memory b) internal pure returns (uint256) {
    return mul_(a, b.mantissa) / doubleScale;
  }

  function mul_(uint256 a, uint256 b) internal pure returns (uint256) {
    return mul_(a, b, "multiplication overflow");
  }

  function mul_(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    if (a == 0 || b == 0) {
      return 0;
    }
    uint256 c = a * b;
    require(c / a == b, errorMessage);
    return c;
  }

  function div_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
    return Exp({mantissa: div_(mul_(a.mantissa, expScale), b.mantissa)});
  }

  function div_(Exp memory a, uint256 b) internal pure returns (Exp memory) {
    return Exp({mantissa: div_(a.mantissa, b)});
  }

  function div_(uint256 a, Exp memory b) internal pure returns (uint256) {
    return div_(mul_(a, expScale), b.mantissa);
  }

  function div_(Double memory a, Double memory b) internal pure returns (Double memory) {
    return Double({mantissa: div_(mul_(a.mantissa, doubleScale), b.mantissa)});
  }

  function div_(Double memory a, uint256 b) internal pure returns (Double memory) {
    return Double({mantissa: div_(a.mantissa, b)});
  }

  function div_(uint256 a, Double memory b) internal pure returns (uint256) {
    return div_(mul_(a, doubleScale), b.mantissa);
  }

  function div_(uint256 a, uint256 b) internal pure returns (uint256) {
    return div_(a, b, "divide by zero");
  }

  function div_(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b > 0, errorMessage);
    return a / b;
  }

  function fraction(uint256 a, uint256 b) internal pure returns (Double memory) {
    return Double({mantissa: div_(mul_(a, doubleScale), b)});
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/*
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
    this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    return msg.data;
  }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "./IERC20.sol";
import "./openzeppelin/Initializable.sol";

/**
 * @title ERC20Detailed token
 * @dev The decimals are only for visualization purposes.
 * All the operations are done using the smallest and indivisible token unit,
 * just as on Ethereum all the operations are done in wei.
 */
abstract contract ERC20Detailed is Initializable, IERC20 {
  string private _name;
  string private _symbol;
  uint8 private _decimals;

  /**
    constructor(string memory name_, string memory symbol_, uint8 decimals_){
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }
     */

  function __ERC20Detailed_init(string memory name_, string memory symbol_, uint8 decimals_) public initializer {
    _name = name_;
    _symbol = symbol_;
    _decimals = decimals_;
  }

  /**
   * @return the name of the token.
   */
  function name() public view virtual returns (string memory) {
    return _name;
  }

  /**
   * @return the symbol of the token.
   */
  function symbol() public view virtual returns (string memory) {
    return _symbol;
  }

  /**
   * @return the number of decimals of the token.
   */
  function decimals() public view virtual returns (uint8) {
    return _decimals;
  }

  uint256[50] private ______gap;
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
  struct Counter {
    // This variable should never be directly accessed by users of the library: interactions must be restricted to
    // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
    // this feature: see https://github.com/ethereum/solidity/issues/4637
    uint256 _value; // default: 0
  }

  function current(Counter storage counter) internal view returns (uint256) {
    return counter._value;
  }

  function increment(Counter storage counter) internal {
    unchecked {
      counter._value += 1;
    }
  }

  function decrement(Counter storage counter) internal {
    uint256 value = counter._value;
    require(value > 0, "Counter: decrement overflow");
    unchecked {
      counter._value = value - 1;
    }
  }

  function reset(Counter storage counter) internal {
    counter._value = 0;
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "./Strings.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
  enum RecoverError {
    NoError,
    InvalidSignature,
    InvalidSignatureLength,
    InvalidSignatureS,
    InvalidSignatureV
  }

  function _throwError(RecoverError error) private pure {
    if (error == RecoverError.NoError) {
      return; // no error: do nothing
    } else if (error == RecoverError.InvalidSignature) {
      revert("ECDSA: invalid signature");
    } else if (error == RecoverError.InvalidSignatureLength) {
      revert("ECDSA: invalid signature length");
    } else if (error == RecoverError.InvalidSignatureS) {
      revert("ECDSA: invalid signature 's' value");
    } else if (error == RecoverError.InvalidSignatureV) {
      revert("ECDSA: invalid signature 'v' value");
    }
  }

  /**
   * @dev Returns the address that signed a hashed message (`hash`) with
   * `signature` or error string. This address can then be used for verification purposes.
   *
   * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
   * this function rejects them by requiring the `s` value to be in the lower
   * half order, and the `v` value to be either 27 or 28.
   *
   * IMPORTANT: `hash` _must_ be the result of a hash operation for the
   * verification to be secure: it is possible to craft signatures that
   * recover to arbitrary addresses for non-hashed data. A safe way to ensure
   * this is by receiving a hash of the original message (which may otherwise
   * be too long), and then calling {toEthSignedMessageHash} on it.
   *
   * Documentation for signature generation:
   * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
   * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
   *
   * _Available since v4.3._
   */
  function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
    // Check the signature length
    // - case 65: r,s,v signature (standard)
    // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098) _Available since v4.1._
    if (signature.length == 65) {
      bytes32 r;
      bytes32 s;
      uint8 v;
      // ecrecover takes the signature parameters, and the only way to get them
      // currently is to use assembly.
      /// @solidity memory-safe-assembly
      assembly {
        r := mload(add(signature, 0x20))
        s := mload(add(signature, 0x40))
        v := byte(0, mload(add(signature, 0x60)))
      }
      return tryRecover(hash, v, r, s);
    } else if (signature.length == 64) {
      bytes32 r;
      bytes32 vs;
      // ecrecover takes the signature parameters, and the only way to get them
      // currently is to use assembly.
      /// @solidity memory-safe-assembly
      assembly {
        r := mload(add(signature, 0x20))
        vs := mload(add(signature, 0x40))
      }
      return tryRecover(hash, r, vs);
    } else {
      return (address(0), RecoverError.InvalidSignatureLength);
    }
  }

  /**
   * @dev Returns the address that signed a hashed message (`hash`) with
   * `signature`. This address can then be used for verification purposes.
   *
   * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
   * this function rejects them by requiring the `s` value to be in the lower
   * half order, and the `v` value to be either 27 or 28.
   *
   * IMPORTANT: `hash` _must_ be the result of a hash operation for the
   * verification to be secure: it is possible to craft signatures that
   * recover to arbitrary addresses for non-hashed data. A safe way to ensure
   * this is by receiving a hash of the original message (which may otherwise
   * be too long), and then calling {toEthSignedMessageHash} on it.
   */
  function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
    (address recovered, RecoverError error) = tryRecover(hash, signature);
    _throwError(error);
    return recovered;
  }

  /**
   * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
   *
   * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
   *
   * _Available since v4.3._
   */
  function tryRecover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address, RecoverError) {
    bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    uint8 v = uint8((uint256(vs) >> 255) + 27);
    return tryRecover(hash, v, r, s);
  }

  /**
   * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
   *
   * _Available since v4.2._
   */
  function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
    (address recovered, RecoverError error) = tryRecover(hash, r, vs);
    _throwError(error);
    return recovered;
  }

  /**
   * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
   * `r` and `s` signature fields separately.
   *
   * _Available since v4.3._
   */
  function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address, RecoverError) {
    // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
    // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
    // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
    // signatures from current libraries generate a unique signature with an s-value in the lower half order.
    //
    // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
    // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
    // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
    // these malleable signatures as well.
    if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
      return (address(0), RecoverError.InvalidSignatureS);
    }
    if (v != 27 && v != 28) {
      return (address(0), RecoverError.InvalidSignatureV);
    }

    // If the signature is valid (and not malleable), return the signer address
    address signer = ecrecover(hash, v, r, s);
    if (signer == address(0)) {
      return (address(0), RecoverError.InvalidSignature);
    }

    return (signer, RecoverError.NoError);
  }

  /**
   * @dev Overload of {ECDSA-recover} that receives the `v`,
   * `r` and `s` signature fields separately.
   */
  function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
    (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
    _throwError(error);
    return recovered;
  }

  /**
   * @dev Returns an Ethereum Signed Message, created from a `hash`. This
   * produces hash corresponding to the one signed with the
   * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
   * JSON-RPC method as part of EIP-191.
   *
   * See {recover}.
   */
  function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
    // 32 is the length in bytes of hash,
    // enforced by the type signature above
    return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
  }

  /**
   * @dev Returns an Ethereum Signed Message, created from `s`. This
   * produces hash corresponding to the one signed with the
   * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
   * JSON-RPC method as part of EIP-191.
   *
   * See {recover}.
   */
  function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
  }

  /**
   * @dev Returns an Ethereum Signed Typed Data, created from a
   * `domainSeparator` and a `structHash`. This produces hash corresponding
   * to the one signed with the
   * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
   * JSON-RPC method as part of EIP-712.
   *
   * See {recover}.
   */
  function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/cryptography/draft-EIP712.sol)

pragma solidity ^0.8.0;

import "./ECDSA.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding specified in the EIP is very generic, and such a generic implementation in Solidity is not feasible,
 * thus this contract does not implement the encoding itself. Protocols need to implement the type-specific encoding
 * they need in their contracts using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * _Available since v3.4._
 */
abstract contract EIP712 {
  /* solhint-disable var-name-mixedcase */
  // Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
  // invalidate the cached domain separator if the chain id changes.
  bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
  uint256 private immutable _CACHED_CHAIN_ID;
  address private immutable _CACHED_THIS;

  bytes32 private immutable _HASHED_NAME;
  bytes32 private immutable _HASHED_VERSION;
  bytes32 private immutable _TYPE_HASH;

  /* solhint-enable var-name-mixedcase */

  /**
   * @dev Initializes the domain separator and parameter caches.
   *
   * The meaning of `name` and `version` is specified in
   * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
   *
   * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
   * - `version`: the current major version of the signing domain.
   *
   * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
   * contract upgrade].
   */
  constructor(string memory name, string memory version) {
    bytes32 hashedName = keccak256(bytes(name));
    bytes32 hashedVersion = keccak256(bytes(version));
    bytes32 typeHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    _HASHED_NAME = hashedName;
    _HASHED_VERSION = hashedVersion;
    _CACHED_CHAIN_ID = block.chainid;
    _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(typeHash, hashedName, hashedVersion);
    _CACHED_THIS = address(this);
    _TYPE_HASH = typeHash;
  }

  /**
   * @dev Returns the domain separator for the current chain.
   */
  function _domainSeparatorV4() internal view returns (bytes32) {
    if (address(this) == _CACHED_THIS && block.chainid == _CACHED_CHAIN_ID) {
      return _CACHED_DOMAIN_SEPARATOR;
    } else {
      return _buildDomainSeparator(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION);
    }
  }

  function _buildDomainSeparator(
    bytes32 typeHash,
    bytes32 nameHash,
    bytes32 versionHash
  ) private view returns (bytes32) {
    return keccak256(abi.encode(typeHash, nameHash, versionHash, block.chainid, address(this)));
  }

  /**
   * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
   * function returns the hash of the fully encoded EIP712 message for this domain.
   *
   * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
   *
   * ```solidity
   * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
   *     keccak256("Mail(address to,string contents)"),
   *     mailTo,
   *     keccak256(bytes(mailContents))
   * )));
   * address signer = ECDSA.recover(digest, signature);
   * ```
   */
  function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
    return ECDSA.toTypedDataHash(_domainSeparatorV4(), structHash);
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "./IERC20Metadata.sol";
import "../Context.sol";

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
  function decimals() public view virtual override(IERC20, IERC20Metadata) returns (uint8) {
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
  function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
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
    _approve(owner, spender, allowance(owner, spender) + addedValue);
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
    uint256 currentAllowance = allowance(owner, spender);
    require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
    unchecked {
      _approve(owner, spender, currentAllowance - subtractedValue);
    }

    return true;
  }

  /**
   * @dev Moves `amount` of tokens from `from` to `to`.
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
  function _transfer(address from, address to, uint256 amount) internal virtual {
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
  function _approve(address owner, address spender, uint256 amount) internal virtual {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  /**
   * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
   *
   * Does not update the allowance amount in case of infinite allowance.
   * Revert if not enough allowance is available.
   *
   * Might emit an {Approval} event.
   */
  function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
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
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

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
  function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/extensions/draft-ERC20Permit.sol)

pragma solidity ^0.8.0;

import "./IERC20Permit.sol";
import "./ERC20.sol";
import "./EIP712.sol";
import "./ECDSA.sol";
import "./Counters.sol";

/**
 * @dev Implementation of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * _Available since v3.4._
 */
abstract contract ERC20Permit is ERC20, IERC20Permit, EIP712 {
  using Counters for Counters.Counter;

  mapping(address => Counters.Counter) private _nonces;

  // solhint-disable-next-line var-name-mixedcase
  bytes32 private constant _PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
  /**
   * @dev In previous versions `_PERMIT_TYPEHASH` was declared as `immutable`.
   * However, to ensure consistency with the upgradeable transpiler, we will continue
   * to reserve a slot.
   * @custom:oz-renamed-from _PERMIT_TYPEHASH
   */
  // solhint-disable-next-line var-name-mixedcase
  bytes32 private _PERMIT_TYPEHASH_DEPRECATED_SLOT;

  /**
   * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
   *
   * It's a good idea to use the same `name` that is defined as the ERC20 token name.
   */
  constructor(string memory name) EIP712(name, "1") {}

  /**
   * @dev See {IERC20Permit-permit}.
   */
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public virtual override {
    require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

    bytes32 structHash = keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));

    bytes32 hash = _hashTypedDataV4(structHash);

    address signer = ECDSA.recover(hash, v, r, s);
    require(signer == owner, "ERC20Permit: invalid signature");

    _approve(owner, spender, value);
  }

  /**
   * @dev See {IERC20Permit-nonces}.
   */
  function nonces(address owner) public view virtual override returns (uint256) {
    return _nonces[owner].current();
  }

  /**
   * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
   */
  // solhint-disable-next-line func-name-mixedcase
  function DOMAIN_SEPARATOR() external view override returns (bytes32) {
    return _domainSeparatorV4();
  }

  /**
   * @dev "Consume a nonce": return the current value and increment.
   *
   * _Available since v4.1._
   */
  function _useNonce(address owner) internal virtual returns (uint256 current) {
    Counters.Counter storage nonce = _nonces[owner];
    current = nonce.current();
    nonce.increment();
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity 0.8.9;

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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "./IERC20Permit.sol";
import "./Address.sol";

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

  function safeTransfer(IERC20 token, address to, uint256 value) internal {
    _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
  }

  function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
    _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
  }

  /**
   * @dev Deprecated. This function has issues similar to the ones found in
   * {IERC20-approve}, and its usage is discouraged.
   *
   * Whenever possible, use {safeIncreaseAllowance} and
   * {safeDecreaseAllowance} instead.
   */
  function safeApprove(IERC20 token, address spender, uint256 value) internal {
    // safeApprove should only be called when setting an initial allowance,
    // or when resetting it to zero. To increase and decrease it, use
    // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
    require(
      (value == 0) || (token.allowance(address(this), spender) == 0),
      "SafeERC20: approve from non-zero to non-zero allowance"
    );
    _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
  }

  function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
    uint256 newAllowance = token.allowance(address(this), spender) + value;
    _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
  }

  function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
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
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
  bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
  uint8 private constant _ADDRESS_LENGTH = 20;

  /**
   * @dev Converts a `uint256` to its ASCII `string` decimal representation.
   */
  function toString(uint256 value) internal pure returns (string memory) {
    // Inspired by OraclizeAPI's implementation - MIT licence
    // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

    if (value == 0) {
      return "0";
    }
    uint256 temp = value;
    uint256 digits;
    while (temp != 0) {
      digits++;
      temp /= 10;
    }
    bytes memory buffer = new bytes(digits);
    while (value != 0) {
      digits -= 1;
      buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
      value /= 10;
    }
    return string(buffer);
  }

  /**
   * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
   */
  function toHexString(uint256 value) internal pure returns (string memory) {
    if (value == 0) {
      return "0x00";
    }
    uint256 temp = value;
    uint256 length = 0;
    while (temp != 0) {
      length++;
      temp >>= 8;
    }
    return toHexString(value, length);
  }

  /**
   * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
   */
  function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
    bytes memory buffer = new bytes(2 * length + 2);
    buffer[0] = "0";
    buffer[1] = "x";
    for (uint256 i = 2 * length + 1; i > 1; --i) {
      buffer[i] = _HEX_SYMBOLS[value & 0xf];
      value >>= 4;
    }
    require(value == 0, "Strings: hex length insufficient");
    return string(buffer);
  }

  /**
   * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
   */
  function toHexString(address addr) internal pure returns (string memory) {
    return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

library HomoraMath {
  function divCeil(uint256 lhs, uint256 rhs) internal pure returns (uint256) {
    return ((lhs + rhs) - 1) / rhs;
  }

  function fmul(uint256 lhs, uint256 rhs) internal pure returns (uint256) {
    return (lhs * rhs) / (2 ** 112);
  }

  function fdiv(uint256 lhs, uint256 rhs) internal pure returns (uint256) {
    return (lhs * (2 ** 112)) / rhs;
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

  // implementation from https://github.com/Uniswap/uniswap-lib/commit/99f3f28770640ba1bb1ff460ac7c5292fb8291a0
  // original implementation: https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.sol#L687
  function sqrt(uint256 x) internal pure returns (uint256) {
    if (x == 0) return 0;
    uint256 xx = x;
    uint256 r = 1;

    if (xx >= 0x100000000000000000000000000000000) {
      xx >>= 128;
      r <<= 64;
    }

    if (xx >= 0x10000000000000000) {
      xx >>= 64;
      r <<= 32;
    }
    if (xx >= 0x100000000) {
      xx >>= 32;
      r <<= 16;
    }
    if (xx >= 0x10000) {
      xx >>= 16;
      r <<= 8;
    }
    if (xx >= 0x100) {
      xx >>= 8;
      r <<= 4;
    }
    if (xx >= 0x10) {
      xx >>= 4;
      r <<= 2;
    }
    if (xx >= 0x8) {
      r <<= 1;
    }

    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1; // Seven iterations should be enough
    uint256 r1 = x / r;
    return (r < r1 ? r : r1);
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
  /**
   * @dev Returns the amount of tokens in existence.
   */
  function totalSupply() external view returns (uint256);

  /**
   * @dev Returns the token decimals.
   */
  function decimals() external view returns (uint8);

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

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./IERC20.sol";

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
// OpenZeppelin Contracts v4.4.0 (token/ERC721/IERC721.sol)

pragma solidity 0.8.9;

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 {
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
  function safeTransferFrom(address from, address to, uint256 tokenId) external;

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
  function transferFrom(address from, address to, uint256 tokenId) external;

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
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./IERC20.sol";

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IVOTE is IERC20 {
  enum DelegationType {
    VOTING_POWER,
    PROPOSITION_POWER
  }

  /**
   * @notice Gets the current votes balance for `account`
   * @param account The address to get votes balance
   * @return The number of current votes for `account`
   */
  function getCurrentVotes(address account) external view returns (uint96);

  /**
   * @dev returns the current delegated power of a user. The current power is the
   * power delegated at the time of the last snapshot
   * @param user the user
   **/
  function getPowerCurrent(address user, DelegationType delegationType) external view returns (uint256);

  function getVotes(address account) external view returns (uint256);

  //aave functions
  function getDelegateeByType(address delegator, DelegationType delegationType) external view returns (address);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.9;

interface IWETH {
  function deposit() external payable;

  function transfer(address to, uint256 value) external returns (bool);

  function withdraw(uint256) external;

  function approve(address spender, uint256 amount) external returns (bool);

  function balanceOf(address holder) external returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Address.sol)

pragma solidity 0.8.9;

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
    assembly {
      size := extcodesize(account)
    }
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
// OpenZeppelin Contracts v4.4.0 (utils/Context.sol)

pragma solidity 0.8.9;
import "./Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
  function __Context_init() internal initializer {
    __Context_init_unchained();
  }

  function __Context_init_unchained() internal initializer {}

  function _msgSender() internal view virtual returns (address) {
    return msg.sender;
  }

  function _msgData() internal view virtual returns (bytes calldata) {
    return msg.data;
  }

  uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/introspection/ERC165.sol)

pragma solidity 0.8.9;

import "./IERC165Upgradeable.sol";
import "./Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
  function __ERC165_init() internal initializer {
    __ERC165_init_unchained();
  }

  function __ERC165_init_unchained() internal initializer {}

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == type(IERC165Upgradeable).interfaceId;
  }

  uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC20/ERC20.sol)

pragma solidity 0.8.9;

import "./IERC20Upgradeable.sol";
import "./IERC20MetadataUpgradeable.sol";
import "./ContextUpgradeable.sol";
import "./Initializable.sol";

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
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable, IERC20MetadataUpgradeable {
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
  function __ERC20_init(string memory name_, string memory symbol_) internal initializer {
    __Context_init_unchained();
    __ERC20_init_unchained(name_, symbol_);
  }

  function __ERC20_init_unchained(string memory name_, string memory symbol_) internal initializer {
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
   * - `recipient` cannot be the zero address.
   * - the caller must have a balance of at least `amount`.
   */
  function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    _transfer(_msgSender(), recipient, amount);
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
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
  function approve(address spender, uint256 amount) public virtual override returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  /**
   * @dev See {IERC20-transferFrom}.
   *
   * Emits an {Approval} event indicating the updated allowance. This is not
   * required by the EIP. See the note at the beginning of {ERC20}.
   *
   * Requirements:
   *
   * - `sender` and `recipient` cannot be the zero address.
   * - `sender` must have a balance of at least `amount`.
   * - the caller must have allowance for ``sender``'s tokens of at least
   * `amount`.
   */
  function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
    _transfer(sender, recipient, amount);

    uint256 currentAllowance = _allowances[sender][_msgSender()];
    require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
    unchecked {
      _approve(sender, _msgSender(), currentAllowance - amount);
    }

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
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
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
    uint256 currentAllowance = _allowances[_msgSender()][spender];
    require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
    unchecked {
      _approve(_msgSender(), spender, currentAllowance - subtractedValue);
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
   * - `sender` cannot be the zero address.
   * - `recipient` cannot be the zero address.
   * - `sender` must have a balance of at least `amount`.
   */
  function _transfer(address sender, address recipient, uint256 amount) internal virtual {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");

    _beforeTokenTransfer(sender, recipient, amount);

    uint256 senderBalance = _balances[sender];
    require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
    unchecked {
      _balances[sender] = senderBalance - amount;
    }
    _balances[recipient] += amount;

    emit Transfer(sender, recipient, amount);

    _afterTokenTransfer(sender, recipient, amount);
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
  function _approve(address owner, address spender, uint256 amount) internal virtual {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
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
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

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
  function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}

  uint256[45] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC721/ERC721.sol)

pragma solidity 0.8.9;

import "./IERC721Upgradeable.sol";
import "./IERC721ReceiverUpgradeable.sol";
import "./IERC721MetadataUpgradeable.sol";
import "./AddressUpgradeable.sol";
import "./ContextUpgradeable.sol";
import "./StringsUpgradeable.sol";
import "./ERC165Upgradeable.sol";
import "./Initializable.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721Upgradeable is
  Initializable,
  ContextUpgradeable,
  ERC165Upgradeable,
  IERC721Upgradeable,
  IERC721MetadataUpgradeable
{
  using AddressUpgradeable for address;
  using StringsUpgradeable for uint256;

  // Token name
  string private _name;

  // Token symbol
  string private _symbol;

  // Mapping from token ID to owner address
  mapping(uint256 => address) private _owners;

  // Mapping owner address to token count
  mapping(address => uint256) private _balances;

  // Mapping from token ID to approved address
  mapping(uint256 => address) private _tokenApprovals;

  // Mapping from owner to operator approvals
  mapping(address => mapping(address => bool)) private _operatorApprovals;

  /**
   * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
   */
  function __ERC721_init(string memory name_, string memory symbol_) internal initializer {
    __Context_init_unchained();
    __ERC165_init_unchained();
    __ERC721_init_unchained(name_, symbol_);
  }

  function __ERC721_init_unchained(string memory name_, string memory symbol_) internal initializer {
    _name = name_;
    _symbol = symbol_;
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(
    bytes4 interfaceId
  ) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
    return
      interfaceId == type(IERC721Upgradeable).interfaceId ||
      interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  /**
   * @dev See {IERC721-balanceOf}.
   */
  function balanceOf(address owner) public view virtual override returns (uint256) {
    require(owner != address(0), "ERC721: balance query for the zero address");
    return _balances[owner];
  }

  /**
   * @dev See {IERC721-ownerOf}.
   */
  function ownerOf(uint256 tokenId) public view virtual override returns (address) {
    address owner = _owners[tokenId];
    require(owner != address(0), "ERC721: owner query for nonexistent token");
    return owner;
  }

  /**
   * @dev See {IERC721Metadata-name}.
   */
  function name() public view virtual override returns (string memory) {
    return _name;
  }

  /**
   * @dev See {IERC721Metadata-symbol}.
   */
  function symbol() public view virtual override returns (string memory) {
    return _symbol;
  }

  /**
   * @dev See {IERC721Metadata-tokenURI}.
   */
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

    string memory baseURI = _baseURI();
    return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
  }

  /**
   * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
   * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
   * by default, can be overriden in child contracts.
   */
  function _baseURI() internal view virtual returns (string memory) {
    return "";
  }

  /**
   * @dev See {IERC721-approve}.
   */
  function approve(address to, uint256 tokenId) public virtual override {
    address owner = ERC721Upgradeable.ownerOf(tokenId);
    require(to != owner, "ERC721: approval to current owner");

    require(
      _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
      "ERC721: approve caller is not owner nor approved for all"
    );

    _approve(to, tokenId);
  }

  /**
   * @dev See {IERC721-getApproved}.
   */
  function getApproved(uint256 tokenId) public view virtual override returns (address) {
    require(_exists(tokenId), "ERC721: approved query for nonexistent token");

    return _tokenApprovals[tokenId];
  }

  /**
   * @dev See {IERC721-setApprovalForAll}.
   */
  function setApprovalForAll(address operator, bool approved) public virtual override {
    _setApprovalForAll(_msgSender(), operator, approved);
  }

  /**
   * @dev See {IERC721-isApprovedForAll}.
   */
  function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
    return _operatorApprovals[owner][operator];
  }

  /**
   * @dev See {IERC721-transferFrom}.
   */
  function transferFrom(address from, address to, uint256 tokenId) public virtual override {
    //solhint-disable-next-line max-line-length
    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

    _transfer(from, to, tokenId);
  }

  /**
   * @dev See {IERC721-safeTransferFrom}.
   */
  function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
    safeTransferFrom(from, to, tokenId, "");
  }

  /**
   * @dev See {IERC721-safeTransferFrom}.
   */
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
    _safeTransfer(from, to, tokenId, _data);
  }

  /**
   * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
   * are aware of the ERC721 protocol to prevent tokens from being forever locked.
   *
   * `_data` is additional data, it has no specified format and it is sent in call to `to`.
   *
   * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
   * implement alternative mechanisms to perform token transfer, such as signature-based.
   *
   * Requirements:
   *
   * - `from` cannot be the zero address.
   * - `to` cannot be the zero address.
   * - `tokenId` token must exist and be owned by `from`.
   * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
   *
   * Emits a {Transfer} event.
   */
  function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal virtual {
    _transfer(from, to, tokenId);
    require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
  }

  /**
   * @dev Returns whether `tokenId` exists.
   *
   * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
   *
   * Tokens start existing when they are minted (`_mint`),
   * and stop existing when they are burned (`_burn`).
   */
  function _exists(uint256 tokenId) internal view virtual returns (bool) {
    return _owners[tokenId] != address(0);
  }

  /**
   * @dev Returns whether `spender` is allowed to manage `tokenId`.
   *
   * Requirements:
   *
   * - `tokenId` must exist.
   */
  function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
    require(_exists(tokenId), "ERC721: operator query for nonexistent token");
    address owner = ERC721Upgradeable.ownerOf(tokenId);
    return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
  }

  /**
   * @dev Safely mints `tokenId` and transfers it to `to`.
   *
   * Requirements:
   *
   * - `tokenId` must not exist.
   * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
   *
   * Emits a {Transfer} event.
   */
  function _safeMint(address to, uint256 tokenId) internal virtual {
    _safeMint(to, tokenId, "");
  }

  /**
   * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
   * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
   */
  function _safeMint(address to, uint256 tokenId, bytes memory _data) internal virtual {
    _mint(to, tokenId);
    require(
      _checkOnERC721Received(address(0), to, tokenId, _data),
      "ERC721: transfer to non ERC721Receiver implementer"
    );
  }

  /**
   * @dev Mints `tokenId` and transfers it to `to`.
   *
   * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
   *
   * Requirements:
   *
   * - `tokenId` must not exist.
   * - `to` cannot be the zero address.
   *
   * Emits a {Transfer} event.
   */
  function _mint(address to, uint256 tokenId) internal virtual {
    require(to != address(0), "ERC721: mint to the zero address");
    require(!_exists(tokenId), "ERC721: token already minted");

    _beforeTokenTransfer(address(0), to, tokenId);

    _balances[to] += 1;
    _owners[tokenId] = to;

    emit Transfer(address(0), to, tokenId);
  }

  /**
   * @dev Destroys `tokenId`.
   * The approval is cleared when the token is burned.
   *
   * Requirements:
   *
   * - `tokenId` must exist.
   *
   * Emits a {Transfer} event.
   */
  function _burn(uint256 tokenId) internal virtual {
    address owner = ERC721Upgradeable.ownerOf(tokenId);

    _beforeTokenTransfer(owner, address(0), tokenId);

    // Clear approvals
    _approve(address(0), tokenId);

    _balances[owner] -= 1;
    delete _owners[tokenId];

    emit Transfer(owner, address(0), tokenId);
  }

  /**
   * @dev Transfers `tokenId` from `from` to `to`.
   *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
   *
   * Requirements:
   *
   * - `to` cannot be the zero address.
   * - `tokenId` token must be owned by `from`.
   *
   * Emits a {Transfer} event.
   */
  function _transfer(address from, address to, uint256 tokenId) internal virtual {
    require(ERC721Upgradeable.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
    require(to != address(0), "ERC721: transfer to the zero address");

    _beforeTokenTransfer(from, to, tokenId);

    // Clear approvals from the previous owner
    _approve(address(0), tokenId);

    _balances[from] -= 1;
    _balances[to] += 1;
    _owners[tokenId] = to;

    emit Transfer(from, to, tokenId);
  }

  /**
   * @dev Approve `to` to operate on `tokenId`
   *
   * Emits a {Approval} event.
   */
  function _approve(address to, uint256 tokenId) internal virtual {
    _tokenApprovals[tokenId] = to;
    emit Approval(ERC721Upgradeable.ownerOf(tokenId), to, tokenId);
  }

  /**
   * @dev Approve `operator` to operate on all of `owner` tokens
   *
   * Emits a {ApprovalForAll} event.
   */
  function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
    require(owner != operator, "ERC721: approve to caller");
    _operatorApprovals[owner][operator] = approved;
    emit ApprovalForAll(owner, operator, approved);
  }

  /**
   * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
   * The call is not executed if the target address is not a contract.
   *
   * @param from address representing the previous owner of the given token ID
   * @param to target address that will receive the tokens
   * @param tokenId uint96 id of the token to be transferred
   * @param _data bytes optional data to send along with the call
   * @return bool whether the call correctly returned the expected magic value
   */
  function _checkOnERC721Received(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) private returns (bool) {
    if (to.isContract()) {
      try IERC721ReceiverUpgradeable(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
        return retval == IERC721ReceiverUpgradeable.onERC721Received.selector;
      } catch (bytes memory reason) {
        if (reason.length == 0) {
          revert("ERC721: transfer to non ERC721Receiver implementer");
        } else {
          assembly {
            revert(add(32, reason), mload(reason))
          }
        }
      }
    } else {
      return true;
    }
  }

  /**
   * @dev Hook that is called before any token transfer. This includes minting
   * and burning.
   *
   * Calling conditions:
   *
   * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
   * transferred to `to`.
   * - When `from` is zero, `tokenId` will be minted for `to`.
   * - When `to` is zero, ``from``'s `tokenId` will be burned.
   * - `from` and `to` are never both zero.
   *
   * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
   */
  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

  uint256[44] private __gap;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

contract GovernorBravoEvents {
  /// @notice An event emitted when a new proposal is created
  event ProposalCreated(
    uint96 id,
    address proposer,
    address[] targets,
    uint256[] values,
    string[] signatures,
    bytes[] calldatas,
    uint256 startBlock,
    uint256 endBlock,
    string description
  );

  /// @notice An event emitted when a vote has been cast on a proposal
  /// @param voter The address which casted a vote
  /// @param proposalId The proposal id which was voted on
  /// @param support Support value for the vote. 0=against, 1=for, 2=abstain
  /// @param votes Number of votes which were cast by the voter
  /// @param reason The reason given for the vote by the voter
  event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 votes, string reason);

  /// @notice An event emitted when a proposal has been canceled
  event ProposalCanceled(uint96 id);

  /// @notice An event emitted when a proposal has been queued in the Timelock
  event ProposalQueued(uint96 id, uint256 eta);

  /// @notice An event emitted when a proposal has been executed in the Timelock
  event ProposalExecuted(uint96 id);

  /// @notice An event emitted when the voting delay is set
  event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);

  /// @notice An event emitted when the voting period is set
  event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);

  /// @notice Emitted when implementation is changed
  event NewImplementation(address oldImplementation, address newImplementation);

  /// @notice Emitted when proposal threshold is set
  event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);

  /// @notice Emitted when pendingAdmin is changed
  event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

  /// @notice Emitted when pendingAdmin is accepted, which means admin is updated
  event NewAdmin(address oldAdmin, address newAdmin);

  /// @notice Emitted when whitelist account expiration is set
  event WhitelistAccountExpirationSet(address account, uint256 expiration);

  /// @notice Emitted when the whitelistGuardian is set
  event WhitelistGuardianSet(address oldGuardian, address newGuardian);
}

contract GovernorBravoDelegatorStorage {
  /// @notice Administrator for this contract
  address public admin;

  /// @notice Pending administrator for this contract
  address public pendingAdmin;

  /// @notice Active brains of Governor
  address public implementation;
}

/**
 * @title Storage for Governor Bravo Delegate
 * @notice For future upgrades, do not change GovernorBravoDelegateStorageV1. Create a new
 * contract which implements GovernorBravoDelegateStorageV1 and following the naming convention
 * GovernorBravoDelegateStorageVX.
 */
contract GovernorBravoDelegateStorageV1 is GovernorBravoDelegatorStorage {
  /// @notice The delay before voting on a proposal may take place, once proposed, in blocks
  uint256 public votingDelay;

  /// @notice The duration of voting on a proposal, in blocks
  uint256 public votingPeriod;

  /// @notice The number of votes required in order for a voter to become a proposer
  uint256 public proposalThreshold;

  /// @notice Initial proposal id set at become
  uint256 public initialProposalId;

  /// @notice The total number of proposals
  uint256 public proposalCount;

  /// @notice The address of the Compound Protocol Timelock
  TimelockInterface public timelock;

  /// @notice The address of the Compound governance token
  CompInterface public comp;

  /// @notice The official record of all proposals ever proposed
  mapping(uint256 => Proposal) public proposals;

  /// @notice The latest proposal for each proposer
  mapping(address => uint256) public latestProposalIds;

  struct Proposal {
    /// @notice Unique id for looking up a proposal
    uint96 id;
    /// @notice Creator of the proposal
    address proposer;
    /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
    uint256 eta;
    /// @notice the ordered list of target addresses for calls to be made
    address[] targets;
    /// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
    uint256[] values;
    /// @notice The ordered list of function signatures to be called
    string[] signatures;
    /// @notice The ordered list of calldata to be passed to each call
    bytes[] calldatas;
    /// @notice The block at which voting begins: holders must delegate their votes prior to this block
    uint256 startBlock;
    /// @notice The block at which voting ends: votes must be cast prior to this block
    uint256 endBlock;
    /// @notice Current number of votes in favor of this proposal
    uint256 forVotes;
    /// @notice Current number of votes in opposition to this proposal
    uint256 againstVotes;
    /// @notice Current number of votes for abstaining for this proposal
    uint256 abstainVotes;
    /// @notice Flag marking whether the proposal has been canceled
    bool canceled;
    /// @notice Flag marking whether the proposal has been executed
    bool executed;
    /// @notice Receipts of ballots for the entire set of voters
    mapping(address => Receipt) receipts;
  }

  /// @notice Ballot receipt record for a voter
  struct Receipt {
    /// @notice Whether or not a vote has been cast
    bool hasVoted;
    /// @notice Whether or not the voter supports the proposal or abstains
    uint8 support;
    /// @notice The number of votes the voter had, which were cast
    uint96 votes;
  }

  /// @notice Possible states that a proposal may be in
  enum ProposalState {
    Pending,
    Active,
    Canceled,
    Defeated,
    Succeeded,
    Queued,
    Expired,
    Executed
  }
}

contract GovernorBravoDelegateStorageV2 is GovernorBravoDelegateStorageV1 {
  /// @notice Stores the expiration of account whitelist status as a timestamp
  mapping(address => uint256) public whitelistAccountExpirations;

  /// @notice Address which manages whitelisted proposals and whitelist accounts
  address public whitelistGuardian;
}

interface TimelockInterface {
  function delay() external view returns (uint256);

  function GRACE_PERIOD() external view returns (uint256);

  function acceptAdmin() external;

  function queuedTransactions(bytes32 hash) external view returns (bool);

  function queueTransaction(
    address target,
    uint256 value,
    string calldata signature,
    bytes calldata data,
    uint256 eta
  ) external returns (bytes32);

  function cancelTransaction(
    address target,
    uint256 value,
    string calldata signature,
    bytes calldata data,
    uint256 eta
  ) external;

  function executeTransaction(
    address target,
    uint256 value,
    string calldata signature,
    bytes calldata data,
    uint256 eta
  ) external payable returns (bytes memory);
}

interface CompInterface {
  function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);
}

interface GovernorAlpha {
  /// @notice The total number of proposals
  function proposalCount() external returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/introspection/IERC165.sol)

pragma solidity 0.8.9;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity 0.8.9;

import "./IERC20Upgradeable.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
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
// OpenZeppelin Contracts v4.4.0 (token/ERC20/IERC20.sol)

pragma solidity 0.8.9;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity 0.8.9;

import "./IERC721Upgradeable.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721MetadataUpgradeable is IERC721Upgradeable {
  /**
   * @dev Returns the token collection name.
   */
  function name() external view returns (string memory);

  /**
   * @dev Returns the token collection symbol.
   */
  function symbol() external view returns (string memory);

  /**
   * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
   */
  function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC721/IERC721Receiver.sol)

pragma solidity 0.8.9;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721ReceiverUpgradeable {
  /**
   * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
   * by `operator` from `from`, this function is called.
   *
   * It must return its Solidity selector to confirm the token transfer.
   * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
   *
   * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
   */
  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC721/IERC721.sol)

pragma solidity 0.8.9;

import "./IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
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
  function safeTransferFrom(address from, address to, uint256 tokenId) external;

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
  function transferFrom(address from, address to, uint256 tokenId) external;

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
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (proxy/utils/Initializable.sol)

pragma solidity 0.8.9;

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
    require(_initializing || !_initialized, "Initializable: contract is already initialized");

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (access/Ownable.sol)

pragma solidity 0.8.9;

import "./ContextUpgradeable.sol";
import "./Initializable.sol";

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev Initializes the contract setting the deployer as the initial owner.
   */
  function __Ownable_init() internal initializer {
    __Context_init_unchained();
    __Ownable_init_unchained();
  }

  function __Ownable_init_unchained() internal initializer {
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

  uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity 0.8.9;

import "./ContextUpgradeable.sol";
import "./Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
  /**
   * @dev Emitted when the pause is triggered by `account`.
   */
  event Paused(address account);

  /**
   * @dev Emitted when the pause is lifted by `account`.
   */
  event Unpaused(address account);

  bool private _paused;

  /**
   * @dev Initializes the contract in unpaused state.
   */
  function __Pausable_init() internal onlyInitializing {
    __Pausable_init_unchained();
  }

  function __Pausable_init_unchained() internal onlyInitializing {
    _paused = false;
  }

  /**
   * @dev Returns true if the contract is paused, and false otherwise.
   */
  function paused() public view virtual returns (bool) {
    return _paused;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   *
   * Requirements:
   *
   * - The contract must not be paused.
   */
  modifier whenNotPaused() {
    require(!paused(), "Pausable: paused");
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   *
   * Requirements:
   *
   * - The contract must be paused.
   */
  modifier whenPaused() {
    require(paused(), "Pausable: not paused");
    _;
  }

  /**
   * @dev Triggers stopped state.
   *
   * Requirements:
   *
   * - The contract must not be paused.
   */
  function _pause() internal virtual whenNotPaused {
    _paused = true;
    emit Paused(_msgSender());
  }

  /**
   * @dev Returns to normal state.
   *
   * Requirements:
   *
   * - The contract must be paused.
   */
  function _unpause() internal virtual whenPaused {
    _paused = false;
    emit Unpaused(_msgSender());
  }

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity 0.8.9;
import "./Initializable.sol";

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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

  function __ReentrancyGuard_init() internal onlyInitializing {
    __ReentrancyGuard_init_unchained();
  }

  function __ReentrancyGuard_init_unchained() internal onlyInitializing {
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

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20Upgradeable.sol";
import "./AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
  using AddressUpgradeable for address;

  function safeTransfer(IERC20Upgradeable token, address to, uint256 value) internal {
    _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
  }

  function safeTransferFrom(IERC20Upgradeable token, address from, address to, uint256 value) internal {
    _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
  }

  /**
   * @dev Deprecated. This function has issues similar to the ones found in
   * {IERC20-approve}, and its usage is discouraged.
   *
   * Whenever possible, use {safeIncreaseAllowance} and
   * {safeDecreaseAllowance} instead.
   */
  function safeApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
    // safeApprove should only be called when setting an initial allowance,
    // or when resetting it to zero. To increase and decrease it, use
    // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
    require(
      (value == 0) || (token.allowance(address(this), spender) == 0),
      "SafeERC20: approve from non-zero to non-zero allowance"
    );
    _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
  }

  function safeIncreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
    uint256 newAllowance = token.allowance(address(this), spender) + value;
    _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
  }

  function safeDecreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
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
  function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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
// OpenZeppelin Contracts v4.4.0 (utils/Strings.sol)

pragma solidity 0.8.9;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
  bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

  /**
   * @dev Converts a `uint256` to its ASCII `string` decimal representation.
   */
  function toString(uint256 value) internal pure returns (string memory) {
    // Inspired by OraclizeAPI's implementation - MIT licence
    // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

    if (value == 0) {
      return "0";
    }
    uint256 temp = value;
    uint256 digits;
    while (temp != 0) {
      digits++;
      temp /= 10;
    }
    bytes memory buffer = new bytes(digits);
    while (value != 0) {
      digits -= 1;
      buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
      value /= 10;
    }
    return string(buffer);
  }

  /**
   * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
   */
  function toHexString(uint256 value) internal pure returns (string memory) {
    if (value == 0) {
      return "0x00";
    }
    uint256 temp = value;
    uint256 length = 0;
    while (temp != 0) {
      length++;
      temp >>= 8;
    }
    return toHexString(value, length);
  }

  /**
   * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
   */
  function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
    bytes memory buffer = new bytes(2 * length + 2);
    buffer[0] = "0";
    buffer[1] = "x";
    for (uint256 i = 2 * length + 1; i > 1; --i) {
      buffer[i] = _HEX_SYMBOLS[value & 0xf];
      value >>= 4;
    }
    require(value == 0, "Strings: hex length insufficient");
    return string(buffer);
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./Context.sol";

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
    require(newOwner != address(0), "Ownable: new owner is zero addr");
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/BeaconProxy.sol)

pragma solidity 0.8.9;

import "./IBeacon.sol";
import "../Proxy.sol";
import "../ERC1967/ERC1967Upgrade.sol";

/**
 * @dev This contract implements a proxy that gets the implementation address for each call from a {UpgradeableBeacon}.
 *
 * The beacon address is stored in storage slot `uint256(keccak256('eip1967.proxy.beacon')) - 1`, so that it doesn't
 * conflict with the storage layout of the implementation behind the proxy.
 *
 * _Available since v3.4._
 */
contract BeaconProxy is Proxy, ERC1967Upgrade {
  /**
   * @dev Initializes the proxy with `beacon`.
   *
   * If `data` is nonempty, it's used as data in a delegate call to the implementation returned by the beacon. This
   * will typically be an encoded function call, and allows initializating the storage of the proxy like a Solidity
   * constructor.
   *
   * Requirements:
   *
   * - `beacon` must be a contract with the interface {IBeacon}.
   */
  constructor(address beacon, bytes memory data) payable {
    assert(_BEACON_SLOT == bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1));
    _upgradeBeaconToAndCall(beacon, data, false);
  }

  /**
   * @dev Returns the current beacon address.
   */
  function _beacon() internal view virtual returns (address) {
    return _getBeacon();
  }

  /**
   * @dev Returns the current implementation address of the associated beacon.
   */
  function _implementation() internal view virtual override returns (address) {
    return IBeacon(_getBeacon()).implementation();
  }

  /**
   * @dev Changes the proxy to use a new beacon. Deprecated: see {_upgradeBeaconToAndCall}.
   *
   * If `data` is nonempty, it's used as data in a delegate call to the implementation returned by the beacon.
   *
   * Requirements:
   *
   * - `beacon` must be a contract.
   * - The implementation returned by `beacon` must be a contract.
   */
  function _setBeacon(address beacon, bytes memory data) internal virtual {
    _upgradeBeaconToAndCall(beacon, data, false);
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity 0.8.9;

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
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity 0.8.9;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
  /**
   * @dev Must return an address that can be used as a delegate call target.
   *
   * {BeaconProxy} will check that this address is a contract.
   */
  function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity 0.8.9;

import "./Context.sol";

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
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/UpgradeableBeacon.sol)

pragma solidity 0.8.9;

import "./IBeacon.sol";
import "./Ownable.sol";
import "../ERC1967/Address.sol";

/**
 * @dev This contract is used in conjunction with one or more instances of {BeaconProxy} to determine their
 * implementation contract, which is where they will delegate all function calls.
 *
 * An owner is able to change the implementation the beacon points to, thus upgrading the proxies that use this beacon.
 */
contract UpgradeableBeacon is IBeacon, Ownable {
  address private _implementation;

  /**
   * @dev Emitted when the implementation returned by the beacon is changed.
   */
  event Upgraded(address indexed implementation);

  /**
   * @dev Sets the address of the initial implementation, and the deployer account as the owner who can upgrade the
   * beacon.
   */
  constructor(address implementation_) {
    _setImplementation(implementation_);
  }

  /**
   * @dev Returns the current implementation address.
   */
  function implementation() public view virtual override returns (address) {
    return _implementation;
  }

  /**
   * @dev Upgrades the beacon to a new implementation.
   *
   * Emits an {Upgraded} event.
   *
   * Requirements:
   *
   * - msg.sender must be the owner of the contract.
   * - `newImplementation` must be a contract.
   */
  function upgradeTo(address newImplementation) public virtual onlyOwner {
    _setImplementation(newImplementation);
    emit Upgraded(newImplementation);
  }

  /**
   * @dev Sets the implementation contract address for this beacon
   *
   * Requirements:
   *
   * - `newImplementation` must be a contract.
   */
  function _setImplementation(address newImplementation) private {
    require(Address.isContract(newImplementation), "UpgradeableBeacon: implementation is not a contract");
    _implementation = newImplementation;
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/Clones.sol)

pragma solidity 0.8.9;

/**
 * @dev https://eips.ethereum.org/EIPS/eip-1167[EIP 1167] is a standard for
 * deploying minimal proxy contracts, also known as "clones".
 *
 * > To simply and cheaply clone contract functionality in an immutable way, this standard specifies
 * > a minimal bytecode implementation that delegates all calls to a known, fixed address.
 *
 * The library includes functions to deploy a proxy using either `create` (traditional deployment) or `create2`
 * (salted deterministic deployment). It also includes functions to predict the addresses of clones deployed using the
 * deterministic method.
 *
 * _Available since v3.4._
 */
library Clones {
  /**
   * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
   *
   * This function uses the create opcode, which should never revert.
   */
  function clone(address implementation) internal returns (address instance) {
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
      mstore(add(ptr, 0x14), shl(0x60, implementation))
      mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
      instance := create(0, ptr, 0x37)
    }
    require(instance != address(0), "ERC1167: create failed");
  }

  /**
   * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
   *
   * This function uses the create2 opcode and a `salt` to deterministically deploy
   * the clone. Using the same `implementation` and `salt` multiple time will revert, since
   * the clones cannot be deployed twice at the same address.
   */
  function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
      mstore(add(ptr, 0x14), shl(0x60, implementation))
      mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
      instance := create2(0, ptr, 0x37, salt)
    }
    require(instance != address(0), "ERC1167: create2 failed");
  }

  /**
   * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
   */
  function predictDeterministicAddress(
    address implementation,
    bytes32 salt,
    address deployer
  ) internal pure returns (address predicted) {
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
      mstore(add(ptr, 0x14), shl(0x60, implementation))
      mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf3ff00000000000000000000000000000000)
      mstore(add(ptr, 0x38), shl(0x60, deployer))
      mstore(add(ptr, 0x4c), salt)
      mstore(add(ptr, 0x6c), keccak256(ptr, 0x37))
      predicted := keccak256(add(ptr, 0x37), 0x55)
    }
  }

  /**
   * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
   */
  function predictDeterministicAddress(address implementation, bytes32 salt) internal view returns (address predicted) {
    return predictDeterministicAddress(implementation, salt, address(this));
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity 0.8.9;

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
// OpenZeppelin Contracts v4.4.1 (proxy/ERC1967/ERC1967Proxy.sol)

pragma solidity 0.8.9;

import "../Proxy.sol";
import "./ERC1967Upgrade.sol";

/**
 * @dev This contract implements an upgradeable proxy. It is upgradeable because calls are delegated to an
 * implementation address that can be changed. This address is stored in storage in the location specified by
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967], so that it doesn't conflict with the storage layout of the
 * implementation behind the proxy.
 */
contract ERC1967Proxy is Proxy, ERC1967Upgrade {
  /**
   * @dev Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
   *
   * If `_data` is nonempty, it's used as data in a delegate call to `_logic`. This will typically be an encoded
   * function call, and allows initializating the storage of the proxy like a Solidity constructor.
   */
  constructor(address _logic, bytes memory _data) payable {
    assert(_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));
    _upgradeToAndCall(_logic, _data, false);
  }

  /**
   * @dev Returns the current implementation address.
   */
  function _implementation() internal view virtual override returns (address impl) {
    return ERC1967Upgrade._getImplementation();
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity 0.8.9;

import "../beacon/IBeacon.sol";
import "./Address.sol";
import "./StorageSlot.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967Upgrade {
  // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
  bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

  /**
   * @dev Storage slot with the address of the current implementation.
   * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
   * validated in the constructor.
   */
  bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  /**
   * @dev Emitted when the implementation is upgraded.
   */
  event Upgraded(address indexed implementation);

  /**
   * @dev Returns the current implementation address.
   */
  function _getImplementation() internal view returns (address) {
    return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
  }

  /**
   * @dev Stores a new address in the EIP1967 implementation slot.
   */
  function _setImplementation(address newImplementation) private {
    require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
    StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
  }

  /**
   * @dev Perform implementation upgrade
   *
   * Emits an {Upgraded} event.
   */
  function _upgradeTo(address newImplementation) internal {
    _setImplementation(newImplementation);
    emit Upgraded(newImplementation);
  }

  /**
   * @dev Perform implementation upgrade with additional setup call.
   *
   * Emits an {Upgraded} event.
   */
  function _upgradeToAndCall(address newImplementation, bytes memory data, bool forceCall) internal {
    _upgradeTo(newImplementation);
    if (data.length > 0 || forceCall) {
      Address.functionDelegateCall(newImplementation, data);
    }
  }

  /**
   * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
   *
   * Emits an {Upgraded} event.
   */
  function _upgradeToAndCallSecure(address newImplementation, bytes memory data, bool forceCall) internal {
    address oldImplementation = _getImplementation();

    // Initial upgrade and setup call
    _setImplementation(newImplementation);
    if (data.length > 0 || forceCall) {
      Address.functionDelegateCall(newImplementation, data);
    }

    // Perform rollback test if not already in progress
    StorageSlot.BooleanSlot storage rollbackTesting = StorageSlot.getBooleanSlot(_ROLLBACK_SLOT);
    if (!rollbackTesting.value) {
      // Trigger rollback using upgradeTo from the new implementation
      rollbackTesting.value = true;
      Address.functionDelegateCall(newImplementation, abi.encodeWithSignature("upgradeTo(address)", oldImplementation));
      rollbackTesting.value = false;
      // Check rollback was effective
      require(oldImplementation == _getImplementation(), "ERC1967Upgrade: upgrade breaks further upgrades");
      // Finally reset to the new implementation and log the upgrade
      _upgradeTo(newImplementation);
    }
  }

  /**
   * @dev Storage slot with the admin of the contract.
   * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
   * validated in the constructor.
   */
  bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  /**
   * @dev Emitted when the admin account has changed.
   */
  event AdminChanged(address previousAdmin, address newAdmin);

  /**
   * @dev Returns the current admin.
   */
  function _getAdmin() internal view returns (address) {
    return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
  }

  /**
   * @dev Stores a new address in the EIP1967 admin slot.
   */
  function _setAdmin(address newAdmin) private {
    require(newAdmin != address(0), "ERC1967: new admin is the zero address");
    StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
  }

  /**
   * @dev Changes the admin of the proxy.
   *
   * Emits an {AdminChanged} event.
   */
  function _changeAdmin(address newAdmin) internal {
    emit AdminChanged(_getAdmin(), newAdmin);
    _setAdmin(newAdmin);
  }

  /**
   * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
   * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
   */
  bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

  /**
   * @dev Emitted when the beacon is upgraded.
   */
  event BeaconUpgraded(address indexed beacon);

  /**
   * @dev Returns the current beacon.
   */
  function _getBeacon() internal view returns (address) {
    return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
  }

  /**
   * @dev Stores a new beacon in the EIP1967 beacon slot.
   */
  function _setBeacon(address newBeacon) private {
    require(Address.isContract(newBeacon), "ERC1967: new beacon is not a contract");
    require(
      Address.isContract(IBeacon(newBeacon).implementation()),
      "ERC1967: beacon implementation is not a contract"
    );
    StorageSlot.getAddressSlot(_BEACON_SLOT).value = newBeacon;
  }

  /**
   * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
   * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
   *
   * Emits a {BeaconUpgraded} event.
   */
  function _upgradeBeaconToAndCall(address newBeacon, bytes memory data, bool forceCall) internal {
    _setBeacon(newBeacon);
    emit BeaconUpgraded(newBeacon);
    if (data.length > 0 || forceCall) {
      Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
    }
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/StorageSlot.sol)

pragma solidity 0.8.9;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlot {
  struct AddressSlot {
    address value;
  }

  struct BooleanSlot {
    bool value;
  }

  struct Bytes32Slot {
    bytes32 value;
  }

  struct Uint256Slot {
    uint256 value;
  }

  /**
   * @dev Returns an `AddressSlot` with member `value` located at `slot`.
   */
  function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
    assembly {
      r.slot := slot
    }
  }

  /**
   * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
   */
  function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
    assembly {
      r.slot := slot
    }
  }

  /**
   * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
   */
  function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
    assembly {
      r.slot := slot
    }
  }

  /**
   * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
   */
  function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
    assembly {
      r.slot := slot
    }
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/Proxy.sol)

pragma solidity 0.8.9;

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
  /**
   * @dev Delegates the current call to `implementation`.
   *
   * This function does not return to its internal call site, it will return directly to the external caller.
   */
  function _delegate(address implementation) internal virtual {
    assembly {
      // Copy msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      calldatacopy(0, 0, calldatasize())

      // Call the implementation.
      // out and outsize are 0 because we don't know the size yet.
      let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

      // Copy the returned data.
      returndatacopy(0, 0, returndatasize())

      switch result
      // delegatecall returns 0 on error.
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }

  /**
   * @dev This is a virtual function that should be overriden so it returns the address to which the fallback function
   * and {_fallback} should delegate.
   */
  function _implementation() internal view virtual returns (address);

  /**
   * @dev Delegates the current call to the address returned by `_implementation()`.
   *
   * This function does not return to its internall call site, it will return directly to the external caller.
   */
  function _fallback() internal virtual {
    _beforeFallback();
    _delegate(_implementation());
  }

  /**
   * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
   * function in the contract matches the call data.
   */
  fallback() external payable virtual {
    _fallback();
  }

  /**
   * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
   * is empty.
   */
  receive() external payable virtual {
    _fallback();
  }

  /**
   * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
   * call, or as part of the Solidity `fallback` or `receive` functions.
   *
   * If overriden should call `super._beforeFallback()`.
   */
  function _beforeFallback() internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/transparent/ProxyAdmin.sol)

pragma solidity 0.8.9;

import "./TransparentUpgradeableProxy.sol";
import "../beacon/Ownable.sol";

/**
 * @dev This is an auxiliary contract meant to be assigned as the admin of a {TransparentUpgradeableProxy}. For an
 * explanation of why you would want to use this see the documentation for {TransparentUpgradeableProxy}.
 */
contract ProxyAdmin is Ownable {
  /**
   * @dev Returns the current implementation of `proxy`.
   *
   * Requirements:
   *
   * - This contract must be the admin of `proxy`.
   */
  function getProxyImplementation(TransparentUpgradeableProxy proxy) public view virtual returns (address) {
    // We need to manually run the static call since the getter cannot be flagged as view
    // bytes4(keccak256("implementation()")) == 0x5c60da1b
    (bool success, bytes memory returndata) = address(proxy).staticcall(hex"5c60da1b");
    require(success);
    return abi.decode(returndata, (address));
  }

  /**
   * @dev Returns the current admin of `proxy`.
   *
   * Requirements:
   *
   * - This contract must be the admin of `proxy`.
   */
  function getProxyAdmin(TransparentUpgradeableProxy proxy) public view virtual returns (address) {
    // We need to manually run the static call since the getter cannot be flagged as view
    // bytes4(keccak256("admin()")) == 0xf851a440
    (bool success, bytes memory returndata) = address(proxy).staticcall(hex"f851a440");
    require(success);
    return abi.decode(returndata, (address));
  }

  /**
   * @dev Changes the admin of `proxy` to `newAdmin`.
   *
   * Requirements:
   *
   * - This contract must be the current admin of `proxy`.
   */
  function changeProxyAdmin(TransparentUpgradeableProxy proxy, address newAdmin) public virtual onlyOwner {
    proxy.changeAdmin(newAdmin);
  }

  /**
   * @dev Upgrades `proxy` to `implementation`. See {TransparentUpgradeableProxy-upgradeTo}.
   *
   * Requirements:
   *
   * - This contract must be the admin of `proxy`.
   */
  function upgrade(TransparentUpgradeableProxy proxy, address implementation) public virtual onlyOwner {
    proxy.upgradeTo(implementation);
  }

  /**
   * @dev Upgrades `proxy` to `implementation` and calls a function on the new implementation. See
   * {TransparentUpgradeableProxy-upgradeToAndCall}.
   *
   * Requirements:
   *
   * - This contract must be the admin of `proxy`.
   */
  function upgradeAndCall(
    TransparentUpgradeableProxy proxy,
    address implementation,
    bytes memory data
  ) public payable virtual onlyOwner {
    proxy.upgradeToAndCall{value: msg.value}(implementation, data);
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/transparent/TransparentUpgradeableProxy.sol)

pragma solidity 0.8.9;

import "../ERC1967/ERC1967Proxy.sol";

/**
 * @dev This contract implements a proxy that is upgradeable by an admin.
 *
 * To avoid https://medium.com/nomic-labs-blog/malicious-backdoors-in-ethereum-proxies-62629adf3357[proxy selector
 * clashing], which can potentially be used in an attack, this contract uses the
 * https://blog.openzeppelin.com/the-transparent-proxy-pattern/[transparent proxy pattern]. This pattern implies two
 * things that go hand in hand:
 *
 * 1. If any account other than the admin calls the proxy, the call will be forwarded to the implementation, even if
 * that call matches one of the admin functions exposed by the proxy itself.
 * 2. If the admin calls the proxy, it can access the admin functions, but its calls will never be forwarded to the
 * implementation. If the admin tries to call a function on the implementation it will fail with an error that says
 * "admin cannot fallback to proxy target".
 *
 * These properties mean that the admin account can only be used for admin actions like upgrading the proxy or changing
 * the admin, so it's best if it's a dedicated account that is not used for anything else. This will avoid headaches due
 * to sudden errors when trying to call a function from the proxy implementation.
 *
 * Our recommendation is for the dedicated account to be an instance of the {ProxyAdmin} contract. If set up this way,
 * you should think of the `ProxyAdmin` instance as the real administrative interface of your proxy.
 */
contract TransparentUpgradeableProxy is ERC1967Proxy {
  /**
   * @dev Initializes an upgradeable proxy managed by `_admin`, backed by the implementation at `_logic`, and
   * optionally initialized with `_data` as explained in {ERC1967Proxy-constructor}.
   */
  constructor(address _logic, address admin_, bytes memory _data) payable ERC1967Proxy(_logic, _data) {
    assert(_ADMIN_SLOT == bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1));
    _changeAdmin(admin_);
  }

  /**
   * @dev Modifier used internally that will delegate the call to the implementation unless the sender is the admin.
   */
  modifier ifAdmin() {
    if (msg.sender == _getAdmin()) {
      _;
    } else {
      _fallback();
    }
  }

  /**
   * @dev Returns the current admin.
   *
   * NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyAdmin}.
   *
   * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
   * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
   * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
   */
  function admin() external ifAdmin returns (address admin_) {
    admin_ = _getAdmin();
  }

  /**
   * @dev Returns the current implementation.
   *
   * NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyImplementation}.
   *
   * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
   * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
   * `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`
   */
  function implementation() external ifAdmin returns (address implementation_) {
    implementation_ = _implementation();
  }

  /**
   * @dev Changes the admin of the proxy.
   *
   * Emits an {AdminChanged} event.
   *
   * NOTE: Only the admin can call this function. See {ProxyAdmin-changeProxyAdmin}.
   */
  function changeAdmin(address newAdmin) external virtual ifAdmin {
    _changeAdmin(newAdmin);
  }

  /**
   * @dev Upgrade the implementation of the proxy.
   *
   * NOTE: Only the admin can call this function. See {ProxyAdmin-upgrade}.
   */
  function upgradeTo(address newImplementation) external ifAdmin {
    _upgradeToAndCall(newImplementation, bytes(""), false);
  }

  /**
   * @dev Upgrade the implementation of the proxy, and then call a function from the new implementation as specified
   * by `data`, which should be an encoded function call. This is useful to initialize new storage variables in the
   * proxied contract.
   *
   * NOTE: Only the admin can call this function. See {ProxyAdmin-upgradeAndCall}.
   */
  function upgradeToAndCall(address newImplementation, bytes calldata data) external payable ifAdmin {
    _upgradeToAndCall(newImplementation, data, true);
  }

  /**
   * @dev Returns the current admin.
   */
  function _admin() internal view virtual returns (address) {
    return _getAdmin();
  }

  /**
   * @dev Makes sure the admin cannot access the fallback function. See {Proxy-_beforeFallback}.
   */
  function _beforeFallback() internal virtual override {
    require(msg.sender != _getAdmin(), "TransparentUpgradeableProxy: admin cannot fallback to proxy target");
    super._beforeFallback();
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/utils/Initializable.sol)

pragma solidity 0.8.9;

import "../ERC1967/Address.sol";

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
// OpenZeppelin Contracts v4.4.1 (proxy/utils/UUPSUpgradeable.sol)

pragma solidity 0.8.9;

import "../ERC1967/ERC1967Upgrade.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is ERC1967Upgrade {
  /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
  address private immutable __self = address(this);

  /**
   * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
   * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
   * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
   * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
   * fail.
   */
  modifier onlyProxy() {
    require(address(this) != __self, "Function must be called through delegatecall");
    require(_getImplementation() == __self, "Function must be called through active proxy");
    _;
  }

  /**
   * @dev Upgrade the implementation of the proxy to `newImplementation`.
   *
   * Calls {_authorizeUpgrade}.
   *
   * Emits an {Upgraded} event.
   */
  function upgradeTo(address newImplementation) external virtual onlyProxy {
    _authorizeUpgrade(newImplementation);
    _upgradeToAndCallSecure(newImplementation, new bytes(0), false);
  }

  /**
   * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
   * encoded in `data`.
   *
   * Calls {_authorizeUpgrade}.
   *
   * Emits an {Upgraded} event.
   */
  function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
    _authorizeUpgrade(newImplementation);
    _upgradeToAndCallSecure(newImplementation, data, true);
  }

  /**
   * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
   * {upgradeTo} and {upgradeToAndCall}.
   *
   * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
   *
   * ```solidity
   * function _authorizeUpgrade(address) internal override onlyOwner {}
   * ```
   */
  function _authorizeUpgrade(address newImplementation) internal virtual;
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4;

/// @notice Emitted when the result overflows uint256.
error PRBMath__MulDivFixedPointOverflow(uint256 prod1);

/// @notice Emitted when the result overflows uint256.
error PRBMath__MulDivOverflow(uint256 prod1, uint256 denominator);

/// @notice Emitted when one of the inputs is type(int256).min.
error PRBMath__MulDivSignedInputTooSmall();

/// @notice Emitted when the intermediary absolute result overflows int256.
error PRBMath__MulDivSignedOverflow(uint256 rAbs);

/// @notice Emitted when the input is MIN_SD59x18.
error PRBMathSD59x18__AbsInputTooSmall();

/// @notice Emitted when ceiling a number overflows SD59x18.
error PRBMathSD59x18__CeilOverflow(int256 x);

/// @notice Emitted when one of the inputs is MIN_SD59x18.
error PRBMathSD59x18__DivInputTooSmall();

/// @notice Emitted when one of the intermediary unsigned results overflows SD59x18.
error PRBMathSD59x18__DivOverflow(uint256 rAbs);

/// @notice Emitted when the input is greater than 133.084258667509499441.
error PRBMathSD59x18__ExpInputTooBig(int256 x);

/// @notice Emitted when the input is greater than 192.
error PRBMathSD59x18__Exp2InputTooBig(int256 x);

/// @notice Emitted when flooring a number underflows SD59x18.
error PRBMathSD59x18__FloorUnderflow(int256 x);

/// @notice Emitted when converting a basic integer to the fixed-point format overflows SD59x18.
error PRBMathSD59x18__FromIntOverflow(int256 x);

/// @notice Emitted when converting a basic integer to the fixed-point format underflows SD59x18.
error PRBMathSD59x18__FromIntUnderflow(int256 x);

/// @notice Emitted when the product of the inputs is negative.
error PRBMathSD59x18__GmNegativeProduct(int256 x, int256 y);

/// @notice Emitted when multiplying the inputs overflows SD59x18.
error PRBMathSD59x18__GmOverflow(int256 x, int256 y);

/// @notice Emitted when the input is less than or equal to zero.
error PRBMathSD59x18__LogInputTooSmall(int256 x);

/// @notice Emitted when one of the inputs is MIN_SD59x18.
error PRBMathSD59x18__MulInputTooSmall();

/// @notice Emitted when the intermediary absolute result overflows SD59x18.
error PRBMathSD59x18__MulOverflow(uint256 rAbs);

/// @notice Emitted when the intermediary absolute result overflows SD59x18.
error PRBMathSD59x18__PowuOverflow(uint256 rAbs);

/// @notice Emitted when the input is negative.
error PRBMathSD59x18__SqrtNegativeInput(int256 x);

/// @notice Emitted when the calculating the square root overflows SD59x18.
error PRBMathSD59x18__SqrtOverflow(int256 x);

/// @notice Emitted when addition overflows UD60x18.
error PRBMathUD60x18__AddOverflow(uint256 x, uint256 y);

/// @notice Emitted when ceiling a number overflows UD60x18.
error PRBMathUD60x18__CeilOverflow(uint256 x);

/// @notice Emitted when the input is greater than 133.084258667509499441.
error PRBMathUD60x18__ExpInputTooBig(uint256 x);

/// @notice Emitted when the input is greater than 192.
error PRBMathUD60x18__Exp2InputTooBig(uint256 x);

/// @notice Emitted when converting a basic integer to the fixed-point format format overflows UD60x18.
error PRBMathUD60x18__FromUintOverflow(uint256 x);

/// @notice Emitted when multiplying the inputs overflows UD60x18.
error PRBMathUD60x18__GmOverflow(uint256 x, uint256 y);

/// @notice Emitted when the input is less than 1.
error PRBMathUD60x18__LogInputTooSmall(uint256 x);

/// @notice Emitted when the calculating the square root overflows UD60x18.
error PRBMathUD60x18__SqrtOverflow(uint256 x);

/// @notice Emitted when subtraction underflows UD60x18.
error PRBMathUD60x18__SubUnderflow(uint256 x, uint256 y);

/// @dev Common mathematical functions used in both PRBMathSD59x18 and PRBMathUD60x18. Note that this shared library
/// does not always assume the signed 59.18-decimal fixed-point or the unsigned 60.18-decimal fixed-point
/// representation. When it does not, it is explicitly mentioned in the NatSpec documentation.
library PRBMath {
  /// STRUCTS ///

  struct SD59x18 {
    int256 value;
  }

  struct UD60x18 {
    uint256 value;
  }

  /// STORAGE ///

  /// @dev How many trailing decimals can be represented.
  uint256 internal constant SCALE = 1e18;

  /// @dev Largest power of two divisor of SCALE.
  uint256 internal constant SCALE_LPOTD = 262144;

  /// @dev SCALE inverted mod 2^256.
  uint256 internal constant SCALE_INVERSE =
    78156646155174841979727994598816262306175212592076161876661_508869554232690281;

  /// FUNCTIONS ///

  /// @notice Calculates the binary exponent of x using the binary fraction method.
  /// @dev Has to use 192.64-bit fixed-point numbers.
  /// See https://ethereum.stackexchange.com/a/96594/24693.
  /// @param x The exponent as an unsigned 192.64-bit fixed-point number.
  /// @return result The result as an unsigned 60.18-decimal fixed-point number.
  function exp2(uint256 x) internal pure returns (uint256 result) {
    unchecked {
      // Start from 0.5 in the 192.64-bit fixed-point format.
      result = 0x800000000000000000000000000000000000000000000000;

      // Multiply the result by root(2, 2^-i) when the bit at position i is 1. None of the intermediary results overflows
      // because the initial result is 2^191 and all magic factors are less than 2^65.
      if (x & 0x8000000000000000 > 0) {
        result = (result * 0x16A09E667F3BCC909) >> 64;
      }
      if (x & 0x4000000000000000 > 0) {
        result = (result * 0x1306FE0A31B7152DF) >> 64;
      }
      if (x & 0x2000000000000000 > 0) {
        result = (result * 0x1172B83C7D517ADCE) >> 64;
      }
      if (x & 0x1000000000000000 > 0) {
        result = (result * 0x10B5586CF9890F62A) >> 64;
      }
      if (x & 0x800000000000000 > 0) {
        result = (result * 0x1059B0D31585743AE) >> 64;
      }
      if (x & 0x400000000000000 > 0) {
        result = (result * 0x102C9A3E778060EE7) >> 64;
      }
      if (x & 0x200000000000000 > 0) {
        result = (result * 0x10163DA9FB33356D8) >> 64;
      }
      if (x & 0x100000000000000 > 0) {
        result = (result * 0x100B1AFA5ABCBED61) >> 64;
      }
      if (x & 0x80000000000000 > 0) {
        result = (result * 0x10058C86DA1C09EA2) >> 64;
      }
      if (x & 0x40000000000000 > 0) {
        result = (result * 0x1002C605E2E8CEC50) >> 64;
      }
      if (x & 0x20000000000000 > 0) {
        result = (result * 0x100162F3904051FA1) >> 64;
      }
      if (x & 0x10000000000000 > 0) {
        result = (result * 0x1000B175EFFDC76BA) >> 64;
      }
      if (x & 0x8000000000000 > 0) {
        result = (result * 0x100058BA01FB9F96D) >> 64;
      }
      if (x & 0x4000000000000 > 0) {
        result = (result * 0x10002C5CC37DA9492) >> 64;
      }
      if (x & 0x2000000000000 > 0) {
        result = (result * 0x1000162E525EE0547) >> 64;
      }
      if (x & 0x1000000000000 > 0) {
        result = (result * 0x10000B17255775C04) >> 64;
      }
      if (x & 0x800000000000 > 0) {
        result = (result * 0x1000058B91B5BC9AE) >> 64;
      }
      if (x & 0x400000000000 > 0) {
        result = (result * 0x100002C5C89D5EC6D) >> 64;
      }
      if (x & 0x200000000000 > 0) {
        result = (result * 0x10000162E43F4F831) >> 64;
      }
      if (x & 0x100000000000 > 0) {
        result = (result * 0x100000B1721BCFC9A) >> 64;
      }
      if (x & 0x80000000000 > 0) {
        result = (result * 0x10000058B90CF1E6E) >> 64;
      }
      if (x & 0x40000000000 > 0) {
        result = (result * 0x1000002C5C863B73F) >> 64;
      }
      if (x & 0x20000000000 > 0) {
        result = (result * 0x100000162E430E5A2) >> 64;
      }
      if (x & 0x10000000000 > 0) {
        result = (result * 0x1000000B172183551) >> 64;
      }
      if (x & 0x8000000000 > 0) {
        result = (result * 0x100000058B90C0B49) >> 64;
      }
      if (x & 0x4000000000 > 0) {
        result = (result * 0x10000002C5C8601CC) >> 64;
      }
      if (x & 0x2000000000 > 0) {
        result = (result * 0x1000000162E42FFF0) >> 64;
      }
      if (x & 0x1000000000 > 0) {
        result = (result * 0x10000000B17217FBB) >> 64;
      }
      if (x & 0x800000000 > 0) {
        result = (result * 0x1000000058B90BFCE) >> 64;
      }
      if (x & 0x400000000 > 0) {
        result = (result * 0x100000002C5C85FE3) >> 64;
      }
      if (x & 0x200000000 > 0) {
        result = (result * 0x10000000162E42FF1) >> 64;
      }
      if (x & 0x100000000 > 0) {
        result = (result * 0x100000000B17217F8) >> 64;
      }
      if (x & 0x80000000 > 0) {
        result = (result * 0x10000000058B90BFC) >> 64;
      }
      if (x & 0x40000000 > 0) {
        result = (result * 0x1000000002C5C85FE) >> 64;
      }
      if (x & 0x20000000 > 0) {
        result = (result * 0x100000000162E42FF) >> 64;
      }
      if (x & 0x10000000 > 0) {
        result = (result * 0x1000000000B17217F) >> 64;
      }
      if (x & 0x8000000 > 0) {
        result = (result * 0x100000000058B90C0) >> 64;
      }
      if (x & 0x4000000 > 0) {
        result = (result * 0x10000000002C5C860) >> 64;
      }
      if (x & 0x2000000 > 0) {
        result = (result * 0x1000000000162E430) >> 64;
      }
      if (x & 0x1000000 > 0) {
        result = (result * 0x10000000000B17218) >> 64;
      }
      if (x & 0x800000 > 0) {
        result = (result * 0x1000000000058B90C) >> 64;
      }
      if (x & 0x400000 > 0) {
        result = (result * 0x100000000002C5C86) >> 64;
      }
      if (x & 0x200000 > 0) {
        result = (result * 0x10000000000162E43) >> 64;
      }
      if (x & 0x100000 > 0) {
        result = (result * 0x100000000000B1721) >> 64;
      }
      if (x & 0x80000 > 0) {
        result = (result * 0x10000000000058B91) >> 64;
      }
      if (x & 0x40000 > 0) {
        result = (result * 0x1000000000002C5C8) >> 64;
      }
      if (x & 0x20000 > 0) {
        result = (result * 0x100000000000162E4) >> 64;
      }
      if (x & 0x10000 > 0) {
        result = (result * 0x1000000000000B172) >> 64;
      }
      if (x & 0x8000 > 0) {
        result = (result * 0x100000000000058B9) >> 64;
      }
      if (x & 0x4000 > 0) {
        result = (result * 0x10000000000002C5D) >> 64;
      }
      if (x & 0x2000 > 0) {
        result = (result * 0x1000000000000162E) >> 64;
      }
      if (x & 0x1000 > 0) {
        result = (result * 0x10000000000000B17) >> 64;
      }
      if (x & 0x800 > 0) {
        result = (result * 0x1000000000000058C) >> 64;
      }
      if (x & 0x400 > 0) {
        result = (result * 0x100000000000002C6) >> 64;
      }
      if (x & 0x200 > 0) {
        result = (result * 0x10000000000000163) >> 64;
      }
      if (x & 0x100 > 0) {
        result = (result * 0x100000000000000B1) >> 64;
      }
      if (x & 0x80 > 0) {
        result = (result * 0x10000000000000059) >> 64;
      }
      if (x & 0x40 > 0) {
        result = (result * 0x1000000000000002C) >> 64;
      }
      if (x & 0x20 > 0) {
        result = (result * 0x10000000000000016) >> 64;
      }
      if (x & 0x10 > 0) {
        result = (result * 0x1000000000000000B) >> 64;
      }
      if (x & 0x8 > 0) {
        result = (result * 0x10000000000000006) >> 64;
      }
      if (x & 0x4 > 0) {
        result = (result * 0x10000000000000003) >> 64;
      }
      if (x & 0x2 > 0) {
        result = (result * 0x10000000000000001) >> 64;
      }
      if (x & 0x1 > 0) {
        result = (result * 0x10000000000000001) >> 64;
      }

      // We're doing two things at the same time:
      //
      //   1. Multiply the result by 2^n + 1, where "2^n" is the integer part and the one is added to account for
      //      the fact that we initially set the result to 0.5. This is accomplished by subtracting from 191
      //      rather than 192.
      //   2. Convert the result to the unsigned 60.18-decimal fixed-point format.
      //
      // This works because 2^(191-ip) = 2^ip / 2^191, where "ip" is the integer part "2^n".
      result *= SCALE;
      result >>= (191 - (x >> 64));
    }
  }

  /// @notice Finds the zero-based index of the first one in the binary representation of x.
  /// @dev See the note on msb in the "Find First Set" Wikipedia article https://en.wikipedia.org/wiki/Find_first_set
  /// @param x The uint256 number for which to find the index of the most significant bit.
  /// @return msb The index of the most significant bit as an uint256.
  function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
    if (x >= 2 ** 128) {
      x >>= 128;
      msb += 128;
    }
    if (x >= 2 ** 64) {
      x >>= 64;
      msb += 64;
    }
    if (x >= 2 ** 32) {
      x >>= 32;
      msb += 32;
    }
    if (x >= 2 ** 16) {
      x >>= 16;
      msb += 16;
    }
    if (x >= 2 ** 8) {
      x >>= 8;
      msb += 8;
    }
    if (x >= 2 ** 4) {
      x >>= 4;
      msb += 4;
    }
    if (x >= 2 ** 2) {
      x >>= 2;
      msb += 2;
    }
    if (x >= 2 ** 1) {
      // No need to shift x any more.
      msb += 1;
    }
  }

  /// @notice Calculates floor(x*y÷denominator) with full precision.
  ///
  /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv.
  ///
  /// Requirements:
  /// - The denominator cannot be zero.
  /// - The result must fit within uint256.
  ///
  /// Caveats:
  /// - This function does not work with fixed-point numbers.
  ///
  /// @param x The multiplicand as an uint256.
  /// @param y The multiplier as an uint256.
  /// @param denominator The divisor as an uint256.
  /// @return result The result as an uint256.
  function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
    // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
    // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
    // variables such that product = prod1 * 2^256 + prod0.
    uint256 prod0; // Least significant 256 bits of the product
    uint256 prod1; // Most significant 256 bits of the product
    assembly {
      let mm := mulmod(x, y, not(0))
      prod0 := mul(x, y)
      prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }

    // Handle non-overflow cases, 256 by 256 division.
    if (prod1 == 0) {
      unchecked {
        result = prod0 / denominator;
      }
      return result;
    }

    // Make sure the result is less than 2^256. Also prevents denominator == 0.
    if (prod1 >= denominator) {
      revert PRBMath__MulDivOverflow(prod1, denominator);
    }

    ///////////////////////////////////////////////
    // 512 by 256 division.
    ///////////////////////////////////////////////

    // Make division exact by subtracting the remainder from [prod1 prod0].
    uint256 remainder;
    assembly {
      // Compute remainder using mulmod.
      remainder := mulmod(x, y, denominator)

      // Subtract 256 bit number from 512 bit number.
      prod1 := sub(prod1, gt(remainder, prod0))
      prod0 := sub(prod0, remainder)
    }

    // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
    // See https://cs.stackexchange.com/q/138556/92363.
    unchecked {
      // Does not overflow because the denominator cannot be zero at this stage in the function.
      uint256 lpotdod = denominator & (~denominator + 1);
      assembly {
        // Divide denominator by lpotdod.
        denominator := div(denominator, lpotdod)

        // Divide [prod1 prod0] by lpotdod.
        prod0 := div(prod0, lpotdod)

        // Flip lpotdod such that it is 2^256 / lpotdod. If lpotdod is zero, then it becomes one.
        lpotdod := add(div(sub(0, lpotdod), lpotdod), 1)
      }

      // Shift in bits from prod1 into prod0.
      prod0 |= prod1 * lpotdod;

      // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
      // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
      // four bits. That is, denominator * inv = 1 mod 2^4.
      uint256 inverse = (3 * denominator) ^ 2;

      // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
      // in modular arithmetic, doubling the correct bits in each step.
      inverse *= 2 - denominator * inverse; // inverse mod 2^8
      inverse *= 2 - denominator * inverse; // inverse mod 2^16
      inverse *= 2 - denominator * inverse; // inverse mod 2^32
      inverse *= 2 - denominator * inverse; // inverse mod 2^64
      inverse *= 2 - denominator * inverse; // inverse mod 2^128
      inverse *= 2 - denominator * inverse; // inverse mod 2^256

      // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
      // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
      // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
      // is no longer required.
      result = prod0 * inverse;
      return result;
    }
  }

  /// @notice Calculates floor(x*y÷1e18) with full precision.
  ///
  /// @dev Variant of "mulDiv" with constant folding, i.e. in which the denominator is always 1e18. Before returning the
  /// final result, we add 1 if (x * y) % SCALE >= HALF_SCALE. Without this, 6.6e-19 would be truncated to 0 instead of
  /// being rounded to 1e-18.  See "Listing 6" and text above it at https://accu.org/index.php/journals/1717.
  ///
  /// Requirements:
  /// - The result must fit within uint256.
  ///
  /// Caveats:
  /// - The body is purposely left uncommented; see the NatSpec comments in "PRBMath.mulDiv" to understand how this works.
  /// - It is assumed that the result can never be type(uint256).max when x and y solve the following two equations:
  ///     1. x * y = type(uint256).max * SCALE
  ///     2. (x * y) % SCALE >= SCALE / 2
  ///
  /// @param x The multiplicand as an unsigned 60.18-decimal fixed-point number.
  /// @param y The multiplier as an unsigned 60.18-decimal fixed-point number.
  /// @return result The result as an unsigned 60.18-decimal fixed-point number.
  function mulDivFixedPoint(uint256 x, uint256 y) internal pure returns (uint256 result) {
    uint256 prod0;
    uint256 prod1;
    assembly {
      let mm := mulmod(x, y, not(0))
      prod0 := mul(x, y)
      prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }

    if (prod1 >= SCALE) {
      revert PRBMath__MulDivFixedPointOverflow(prod1);
    }

    uint256 remainder;
    uint256 roundUpUnit;
    assembly {
      remainder := mulmod(x, y, SCALE)
      roundUpUnit := gt(remainder, 499999999999999999)
    }

    if (prod1 == 0) {
      unchecked {
        result = (prod0 / SCALE) + roundUpUnit;
        return result;
      }
    }

    assembly {
      result := add(
        mul(
          or(
            div(sub(prod0, remainder), SCALE_LPOTD),
            mul(sub(prod1, gt(remainder, prod0)), add(div(sub(0, SCALE_LPOTD), SCALE_LPOTD), 1))
          ),
          SCALE_INVERSE
        ),
        roundUpUnit
      )
    }
  }

  /// @notice Calculates floor(x*y÷denominator) with full precision.
  ///
  /// @dev An extension of "mulDiv" for signed numbers. Works by computing the signs and the absolute values separately.
  ///
  /// Requirements:
  /// - None of the inputs can be type(int256).min.
  /// - The result must fit within int256.
  ///
  /// @param x The multiplicand as an int256.
  /// @param y The multiplier as an int256.
  /// @param denominator The divisor as an int256.
  /// @return result The result as an int256.
  function mulDivSigned(int256 x, int256 y, int256 denominator) internal pure returns (int256 result) {
    if (x == type(int256).min || y == type(int256).min || denominator == type(int256).min) {
      revert PRBMath__MulDivSignedInputTooSmall();
    }

    // Get hold of the absolute values of x, y and the denominator.
    uint256 ax;
    uint256 ay;
    uint256 ad;
    unchecked {
      ax = x < 0 ? uint256(-x) : uint256(x);
      ay = y < 0 ? uint256(-y) : uint256(y);
      ad = denominator < 0 ? uint256(-denominator) : uint256(denominator);
    }

    // Compute the absolute value of (x*y)÷denominator. The result must fit within int256.
    uint256 rAbs = mulDiv(ax, ay, ad);
    if (rAbs > uint256(type(int256).max)) {
      revert PRBMath__MulDivSignedOverflow(rAbs);
    }

    // Get the signs of x, y and the denominator.
    uint256 sx;
    uint256 sy;
    uint256 sd;
    assembly {
      sx := sgt(x, sub(0, 1))
      sy := sgt(y, sub(0, 1))
      sd := sgt(denominator, sub(0, 1))
    }

    // XOR over sx, sy and sd. This is checking whether there are one or three negative signs in the inputs.
    // If yes, the result should be negative.
    result = sx ^ sy ^ sd == 0 ? -int256(rAbs) : int256(rAbs);
  }

  /// @notice Calculates the square root of x, rounding down.
  /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
  ///
  /// Caveats:
  /// - This function does not work with fixed-point numbers.
  ///
  /// @param x The uint256 number for which to calculate the square root.
  /// @return result The result as an uint256.
  function sqrt(uint256 x) internal pure returns (uint256 result) {
    if (x == 0) {
      return 0;
    }

    // Set the initial guess to the least power of two that is greater than or equal to sqrt(x).
    uint256 xAux = uint256(x);
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
    if (xAux >= 0x4) {
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
      uint256 roundedDownResult = x / result;
      return result >= roundedDownResult ? roundedDownResult : result;
    }
  }
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4;

import "./PRBMath.sol";

/// @title PRBMathSD59x18
/// @author Paul Razvan Berg
/// @notice Smart contract library for advanced fixed-point math that works with int256 numbers considered to have 18
/// trailing decimals. We call this number representation signed 59.18-decimal fixed-point, since the numbers can have
/// a sign and there can be up to 59 digits in the integer part and up to 18 decimals in the fractional part. The numbers
/// are bound by the minimum and the maximum values permitted by the Solidity type int256.
library PRBMathSD59x18 {
  /// @dev log2(e) as a signed 59.18-decimal fixed-point number.
  int256 internal constant LOG2_E = 1_442695040888963407;

  /// @dev Half the SCALE number.
  int256 internal constant HALF_SCALE = 5e17;

  /// @dev The maximum value a signed 59.18-decimal fixed-point number can have.
  int256 internal constant MAX_SD59x18 = 57896044618658097711785492504343953926634992332820282019728_792003956564819967;

  /// @dev The maximum whole value a signed 59.18-decimal fixed-point number can have.
  int256 internal constant MAX_WHOLE_SD59x18 =
    57896044618658097711785492504343953926634992332820282019728_000000000000000000;

  /// @dev The minimum value a signed 59.18-decimal fixed-point number can have.
  int256 internal constant MIN_SD59x18 =
    -57896044618658097711785492504343953926634992332820282019728_792003956564819968;

  /// @dev The minimum whole value a signed 59.18-decimal fixed-point number can have.
  int256 internal constant MIN_WHOLE_SD59x18 =
    -57896044618658097711785492504343953926634992332820282019728_000000000000000000;

  /// @dev How many trailing decimals can be represented.
  int256 internal constant SCALE = 1e18;

  /// INTERNAL FUNCTIONS ///

  /// @notice Calculate the absolute value of x.
  ///
  /// @dev Requirements:
  /// - x must be greater than MIN_SD59x18.
  ///
  /// @param x The number to calculate the absolute value for.
  /// @param result The absolute value of x.
  function abs(int256 x) internal pure returns (int256 result) {
    unchecked {
      if (x == MIN_SD59x18) {
        revert PRBMathSD59x18__AbsInputTooSmall();
      }
      result = x < 0 ? -x : x;
    }
  }

  /// @notice Calculates the arithmetic average of x and y, rounding down.
  /// @param x The first operand as a signed 59.18-decimal fixed-point number.
  /// @param y The second operand as a signed 59.18-decimal fixed-point number.
  /// @return result The arithmetic average as a signed 59.18-decimal fixed-point number.
  function avg(int256 x, int256 y) internal pure returns (int256 result) {
    // The operations can never overflow.
    unchecked {
      int256 sum = (x >> 1) + (y >> 1);
      if (sum < 0) {
        // If at least one of x and y is odd, we add 1 to the result. This is because shifting negative numbers to the
        // right rounds down to infinity.
        assembly {
          result := add(sum, and(or(x, y), 1))
        }
      } else {
        // If both x and y are odd, we add 1 to the result. This is because if both numbers are odd, the 0.5
        // remainder gets truncated twice.
        result = sum + (x & y & 1);
      }
    }
  }

  /// @notice Yields the least greatest signed 59.18 decimal fixed-point number greater than or equal to x.
  ///
  /// @dev Optimized for fractional value inputs, because for every whole value there are (1e18 - 1) fractional counterparts.
  /// See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
  ///
  /// Requirements:
  /// - x must be less than or equal to MAX_WHOLE_SD59x18.
  ///
  /// @param x The signed 59.18-decimal fixed-point number to ceil.
  /// @param result The least integer greater than or equal to x, as a signed 58.18-decimal fixed-point number.
  function ceil(int256 x) internal pure returns (int256 result) {
    if (x > MAX_WHOLE_SD59x18) {
      revert PRBMathSD59x18__CeilOverflow(x);
    }
    unchecked {
      int256 remainder = x % SCALE;
      if (remainder == 0) {
        result = x;
      } else {
        // Solidity uses C fmod style, which returns a modulus with the same sign as x.
        result = x - remainder;
        if (x > 0) {
          result += SCALE;
        }
      }
    }
  }

  /// @notice Divides two signed 59.18-decimal fixed-point numbers, returning a new signed 59.18-decimal fixed-point number.
  ///
  /// @dev Variant of "mulDiv" that works with signed numbers. Works by computing the signs and the absolute values separately.
  ///
  /// Requirements:
  /// - All from "PRBMath.mulDiv".
  /// - None of the inputs can be MIN_SD59x18.
  /// - The denominator cannot be zero.
  /// - The result must fit within int256.
  ///
  /// Caveats:
  /// - All from "PRBMath.mulDiv".
  ///
  /// @param x The numerator as a signed 59.18-decimal fixed-point number.
  /// @param y The denominator as a signed 59.18-decimal fixed-point number.
  /// @param result The quotient as a signed 59.18-decimal fixed-point number.
  function div(int256 x, int256 y) internal pure returns (int256 result) {
    if (x == MIN_SD59x18 || y == MIN_SD59x18) {
      revert PRBMathSD59x18__DivInputTooSmall();
    }

    // Get hold of the absolute values of x and y.
    uint256 ax;
    uint256 ay;
    unchecked {
      ax = x < 0 ? uint256(-x) : uint256(x);
      ay = y < 0 ? uint256(-y) : uint256(y);
    }

    // Compute the absolute value of (x*SCALE)÷y. The result must fit within int256.
    uint256 rAbs = PRBMath.mulDiv(ax, uint256(SCALE), ay);
    if (rAbs > uint256(MAX_SD59x18)) {
      revert PRBMathSD59x18__DivOverflow(rAbs);
    }

    // Get the signs of x and y.
    uint256 sx;
    uint256 sy;
    assembly {
      sx := sgt(x, sub(0, 1))
      sy := sgt(y, sub(0, 1))
    }

    // XOR over sx and sy. This is basically checking whether the inputs have the same sign. If yes, the result
    // should be positive. Otherwise, it should be negative.
    result = sx ^ sy == 1 ? -int256(rAbs) : int256(rAbs);
  }

  /// @notice Returns Euler's number as a signed 59.18-decimal fixed-point number.
  /// @dev See https://en.wikipedia.org/wiki/E_(mathematical_constant).
  function e() internal pure returns (int256 result) {
    result = 2_718281828459045235;
  }

  /// @notice Calculates the natural exponent of x.
  ///
  /// @dev Based on the insight that e^x = 2^(x * log2(e)).
  ///
  /// Requirements:
  /// - All from "log2".
  /// - x must be less than 133.084258667509499441.
  ///
  /// Caveats:
  /// - All from "exp2".
  /// - For any x less than -41.446531673892822322, the result is zero.
  ///
  /// @param x The exponent as a signed 59.18-decimal fixed-point number.
  /// @return result The result as a signed 59.18-decimal fixed-point number.
  function exp(int256 x) internal pure returns (int256 result) {
    // Without this check, the value passed to "exp2" would be less than -59.794705707972522261.
    if (x < -41_446531673892822322) {
      return 0;
    }

    // Without this check, the value passed to "exp2" would be greater than 192.
    if (x >= 133_084258667509499441) {
      revert PRBMathSD59x18__ExpInputTooBig(x);
    }

    // Do the fixed-point multiplication inline to save gas.
    unchecked {
      int256 doubleScaleProduct = x * LOG2_E;
      result = exp2((doubleScaleProduct + HALF_SCALE) / SCALE);
    }
  }

  /// @notice Calculates the binary exponent of x using the binary fraction method.
  ///
  /// @dev See https://ethereum.stackexchange.com/q/79903/24693.
  ///
  /// Requirements:
  /// - x must be 192 or less.
  /// - The result must fit within MAX_SD59x18.
  ///
  /// Caveats:
  /// - For any x less than -59.794705707972522261, the result is zero.
  ///
  /// @param x The exponent as a signed 59.18-decimal fixed-point number.
  /// @return result The result as a signed 59.18-decimal fixed-point number.
  function exp2(int256 x) internal pure returns (int256 result) {
    // This works because 2^(-x) = 1/2^x.
    if (x < 0) {
      // 2^59.794705707972522262 is the maximum number whose inverse does not truncate down to zero.
      if (x < -59_794705707972522261) {
        return 0;
      }

      // Do the fixed-point inversion inline to save gas. The numerator is SCALE * SCALE.
      unchecked {
        result = 1e36 / exp2(-x);
      }
    } else {
      // 2^192 doesn't fit within the 192.64-bit format used internally in this function.
      if (x >= 192e18) {
        revert PRBMathSD59x18__Exp2InputTooBig(x);
      }

      unchecked {
        // Convert x to the 192.64-bit fixed-point format.
        uint256 x192x64 = (uint256(x) << 64) / uint256(SCALE);

        // Safe to convert the result to int256 directly because the maximum input allowed is 192.
        result = int256(PRBMath.exp2(x192x64));
      }
    }
  }

  /// @notice Yields the greatest signed 59.18 decimal fixed-point number less than or equal to x.
  ///
  /// @dev Optimized for fractional value inputs, because for every whole value there are (1e18 - 1) fractional counterparts.
  /// See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
  ///
  /// Requirements:
  /// - x must be greater than or equal to MIN_WHOLE_SD59x18.
  ///
  /// @param x The signed 59.18-decimal fixed-point number to floor.
  /// @param result The greatest integer less than or equal to x, as a signed 58.18-decimal fixed-point number.
  function floor(int256 x) internal pure returns (int256 result) {
    if (x < MIN_WHOLE_SD59x18) {
      revert PRBMathSD59x18__FloorUnderflow(x);
    }
    unchecked {
      int256 remainder = x % SCALE;
      if (remainder == 0) {
        result = x;
      } else {
        // Solidity uses C fmod style, which returns a modulus with the same sign as x.
        result = x - remainder;
        if (x < 0) {
          result -= SCALE;
        }
      }
    }
  }

  /// @notice Yields the excess beyond the floor of x for positive numbers and the part of the number to the right
  /// of the radix point for negative numbers.
  /// @dev Based on the odd function definition. https://en.wikipedia.org/wiki/Fractional_part
  /// @param x The signed 59.18-decimal fixed-point number to get the fractional part of.
  /// @param result The fractional part of x as a signed 59.18-decimal fixed-point number.
  function frac(int256 x) internal pure returns (int256 result) {
    unchecked {
      result = x % SCALE;
    }
  }

  /// @notice Converts a number from basic integer form to signed 59.18-decimal fixed-point representation.
  ///
  /// @dev Requirements:
  /// - x must be greater than or equal to MIN_SD59x18 divided by SCALE.
  /// - x must be less than or equal to MAX_SD59x18 divided by SCALE.
  ///
  /// @param x The basic integer to convert.
  /// @param result The same number in signed 59.18-decimal fixed-point representation.
  function fromInt(int256 x) internal pure returns (int256 result) {
    unchecked {
      if (x < MIN_SD59x18 / SCALE) {
        revert PRBMathSD59x18__FromIntUnderflow(x);
      }
      if (x > MAX_SD59x18 / SCALE) {
        revert PRBMathSD59x18__FromIntOverflow(x);
      }
      result = x * SCALE;
    }
  }

  /// @notice Calculates geometric mean of x and y, i.e. sqrt(x * y), rounding down.
  ///
  /// @dev Requirements:
  /// - x * y must fit within MAX_SD59x18, lest it overflows.
  /// - x * y cannot be negative.
  ///
  /// @param x The first operand as a signed 59.18-decimal fixed-point number.
  /// @param y The second operand as a signed 59.18-decimal fixed-point number.
  /// @return result The result as a signed 59.18-decimal fixed-point number.
  function gm(int256 x, int256 y) internal pure returns (int256 result) {
    if (x == 0) {
      return 0;
    }

    unchecked {
      // Checking for overflow this way is faster than letting Solidity do it.
      int256 xy = x * y;
      if (xy / x != y) {
        revert PRBMathSD59x18__GmOverflow(x, y);
      }

      // The product cannot be negative.
      if (xy < 0) {
        revert PRBMathSD59x18__GmNegativeProduct(x, y);
      }

      // We don't need to multiply by the SCALE here because the x*y product had already picked up a factor of SCALE
      // during multiplication. See the comments within the "sqrt" function.
      result = int256(PRBMath.sqrt(uint256(xy)));
    }
  }

  /// @notice Calculates 1 / x, rounding toward zero.
  ///
  /// @dev Requirements:
  /// - x cannot be zero.
  ///
  /// @param x The signed 59.18-decimal fixed-point number for which to calculate the inverse.
  /// @return result The inverse as a signed 59.18-decimal fixed-point number.
  function inv(int256 x) internal pure returns (int256 result) {
    unchecked {
      // 1e36 is SCALE * SCALE.
      result = 1e36 / x;
    }
  }

  /// @notice Calculates the natural logarithm of x.
  ///
  /// @dev Based on the insight that ln(x) = log2(x) / log2(e).
  ///
  /// Requirements:
  /// - All from "log2".
  ///
  /// Caveats:
  /// - All from "log2".
  /// - This doesn't return exactly 1 for 2718281828459045235, for that we would need more fine-grained precision.
  ///
  /// @param x The signed 59.18-decimal fixed-point number for which to calculate the natural logarithm.
  /// @return result The natural logarithm as a signed 59.18-decimal fixed-point number.
  function ln(int256 x) internal pure returns (int256 result) {
    // Do the fixed-point multiplication inline to save gas. This is overflow-safe because the maximum value that log2(x)
    // can return is 195205294292027477728.
    unchecked {
      result = (log2(x) * SCALE) / LOG2_E;
    }
  }

  /// @notice Calculates the common logarithm of x.
  ///
  /// @dev First checks if x is an exact power of ten and it stops if yes. If it's not, calculates the common
  /// logarithm based on the insight that log10(x) = log2(x) / log2(10).
  ///
  /// Requirements:
  /// - All from "log2".
  ///
  /// Caveats:
  /// - All from "log2".
  ///
  /// @param x The signed 59.18-decimal fixed-point number for which to calculate the common logarithm.
  /// @return result The common logarithm as a signed 59.18-decimal fixed-point number.
  function log10(int256 x) internal pure returns (int256 result) {
    if (x <= 0) {
      revert PRBMathSD59x18__LogInputTooSmall(x);
    }

    // Note that the "mul" in this block is the assembly mul operation, not the "mul" function defined in this contract.
    // prettier-ignore
    assembly {
            switch x
            case 1 { result := mul(SCALE, sub(0, 18)) }
            case 10 { result := mul(SCALE, sub(1, 18)) }
            case 100 { result := mul(SCALE, sub(2, 18)) }
            case 1000 { result := mul(SCALE, sub(3, 18)) }
            case 10000 { result := mul(SCALE, sub(4, 18)) }
            case 100000 { result := mul(SCALE, sub(5, 18)) }
            case 1000000 { result := mul(SCALE, sub(6, 18)) }
            case 10000000 { result := mul(SCALE, sub(7, 18)) }
            case 100000000 { result := mul(SCALE, sub(8, 18)) }
            case 1000000000 { result := mul(SCALE, sub(9, 18)) }
            case 10000000000 { result := mul(SCALE, sub(10, 18)) }
            case 100000000000 { result := mul(SCALE, sub(11, 18)) }
            case 1000000000000 { result := mul(SCALE, sub(12, 18)) }
            case 10000000000000 { result := mul(SCALE, sub(13, 18)) }
            case 100000000000000 { result := mul(SCALE, sub(14, 18)) }
            case 1000000000000000 { result := mul(SCALE, sub(15, 18)) }
            case 10000000000000000 { result := mul(SCALE, sub(16, 18)) }
            case 100000000000000000 { result := mul(SCALE, sub(17, 18)) }
            case 1000000000000000000 { result := 0 }
            case 10000000000000000000 { result := SCALE }
            case 100000000000000000000 { result := mul(SCALE, 2) }
            case 1000000000000000000000 { result := mul(SCALE, 3) }
            case 10000000000000000000000 { result := mul(SCALE, 4) }
            case 100000000000000000000000 { result := mul(SCALE, 5) }
            case 1000000000000000000000000 { result := mul(SCALE, 6) }
            case 10000000000000000000000000 { result := mul(SCALE, 7) }
            case 100000000000000000000000000 { result := mul(SCALE, 8) }
            case 1000000000000000000000000000 { result := mul(SCALE, 9) }
            case 10000000000000000000000000000 { result := mul(SCALE, 10) }
            case 100000000000000000000000000000 { result := mul(SCALE, 11) }
            case 1000000000000000000000000000000 { result := mul(SCALE, 12) }
            case 10000000000000000000000000000000 { result := mul(SCALE, 13) }
            case 100000000000000000000000000000000 { result := mul(SCALE, 14) }
            case 1000000000000000000000000000000000 { result := mul(SCALE, 15) }
            case 10000000000000000000000000000000000 { result := mul(SCALE, 16) }
            case 100000000000000000000000000000000000 { result := mul(SCALE, 17) }
            case 1000000000000000000000000000000000000 { result := mul(SCALE, 18) }
            case 10000000000000000000000000000000000000 { result := mul(SCALE, 19) }
            case 100000000000000000000000000000000000000 { result := mul(SCALE, 20) }
            case 1000000000000000000000000000000000000000 { result := mul(SCALE, 21) }
            case 10000000000000000000000000000000000000000 { result := mul(SCALE, 22) }
            case 100000000000000000000000000000000000000000 { result := mul(SCALE, 23) }
            case 1000000000000000000000000000000000000000000 { result := mul(SCALE, 24) }
            case 10000000000000000000000000000000000000000000 { result := mul(SCALE, 25) }
            case 100000000000000000000000000000000000000000000 { result := mul(SCALE, 26) }
            case 1000000000000000000000000000000000000000000000 { result := mul(SCALE, 27) }
            case 10000000000000000000000000000000000000000000000 { result := mul(SCALE, 28) }
            case 100000000000000000000000000000000000000000000000 { result := mul(SCALE, 29) }
            case 1000000000000000000000000000000000000000000000000 { result := mul(SCALE, 30) }
            case 10000000000000000000000000000000000000000000000000 { result := mul(SCALE, 31) }
            case 100000000000000000000000000000000000000000000000000 { result := mul(SCALE, 32) }
            case 1000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 33) }
            case 10000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 34) }
            case 100000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 35) }
            case 1000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 36) }
            case 10000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 37) }
            case 100000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 38) }
            case 1000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 39) }
            case 10000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 40) }
            case 100000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 41) }
            case 1000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 42) }
            case 10000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 43) }
            case 100000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 44) }
            case 1000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 45) }
            case 10000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 46) }
            case 100000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 47) }
            case 1000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 48) }
            case 10000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 49) }
            case 100000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 50) }
            case 1000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 51) }
            case 10000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 52) }
            case 100000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 53) }
            case 1000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 54) }
            case 10000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 55) }
            case 100000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 56) }
            case 1000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 57) }
            case 10000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 58) }
            default {
                result := MAX_SD59x18
            }
        }

    if (result == MAX_SD59x18) {
      // Do the fixed-point division inline to save gas. The denominator is log2(10).
      unchecked {
        result = (log2(x) * SCALE) / 3_321928094887362347;
      }
    }
  }

  /// @notice Calculates the binary logarithm of x.
  ///
  /// @dev Based on the iterative approximation algorithm.
  /// https://en.wikipedia.org/wiki/Binary_logarithm#Iterative_approximation
  ///
  /// Requirements:
  /// - x must be greater than zero.
  ///
  /// Caveats:
  /// - The results are not perfectly accurate to the last decimal, due to the lossy precision of the iterative approximation.
  ///
  /// @param x The signed 59.18-decimal fixed-point number for which to calculate the binary logarithm.
  /// @return result The binary logarithm as a signed 59.18-decimal fixed-point number.
  function log2(int256 x) internal pure returns (int256 result) {
    if (x <= 0) {
      revert PRBMathSD59x18__LogInputTooSmall(x);
    }
    unchecked {
      // This works because log2(x) = -log2(1/x).
      int256 sign;
      if (x >= SCALE) {
        sign = 1;
      } else {
        sign = -1;
        // Do the fixed-point inversion inline to save gas. The numerator is SCALE * SCALE.
        assembly {
          x := div(1000000000000000000000000000000000000, x)
        }
      }

      // Calculate the integer part of the logarithm and add it to the result and finally calculate y = x * 2^(-n).
      uint256 n = PRBMath.mostSignificantBit(uint256(x / SCALE));

      // The integer part of the logarithm as a signed 59.18-decimal fixed-point number. The operation can't overflow
      // because n is maximum 255, SCALE is 1e18 and sign is either 1 or -1.
      result = int256(n) * SCALE;

      // This is y = x * 2^(-n).
      int256 y = x >> n;

      // If y = 1, the fractional part is zero.
      if (y == SCALE) {
        return result * sign;
      }

      // Calculate the fractional part via the iterative approximation.
      // The "delta >>= 1" part is equivalent to "delta /= 2", but shifting bits is faster.
      for (int256 delta = int256(HALF_SCALE); delta > 0; delta >>= 1) {
        y = (y * y) / SCALE;

        // Is y^2 > 2 and so in the range [2,4)?
        if (y >= 2 * SCALE) {
          // Add the 2^(-m) factor to the logarithm.
          result += delta;

          // Corresponds to z/2 on Wikipedia.
          y >>= 1;
        }
      }
      result *= sign;
    }
  }

  /// @notice Multiplies two signed 59.18-decimal fixed-point numbers together, returning a new signed 59.18-decimal
  /// fixed-point number.
  ///
  /// @dev Variant of "mulDiv" that works with signed numbers and employs constant folding, i.e. the denominator is
  /// always 1e18.
  ///
  /// Requirements:
  /// - All from "PRBMath.mulDivFixedPoint".
  /// - None of the inputs can be MIN_SD59x18
  /// - The result must fit within MAX_SD59x18.
  ///
  /// Caveats:
  /// - The body is purposely left uncommented; see the NatSpec comments in "PRBMath.mulDiv" to understand how this works.
  ///
  /// @param x The multiplicand as a signed 59.18-decimal fixed-point number.
  /// @param y The multiplier as a signed 59.18-decimal fixed-point number.
  /// @return result The product as a signed 59.18-decimal fixed-point number.
  function mul(int256 x, int256 y) internal pure returns (int256 result) {
    if (x == MIN_SD59x18 || y == MIN_SD59x18) {
      revert PRBMathSD59x18__MulInputTooSmall();
    }

    unchecked {
      uint256 ax;
      uint256 ay;
      ax = x < 0 ? uint256(-x) : uint256(x);
      ay = y < 0 ? uint256(-y) : uint256(y);

      uint256 rAbs = PRBMath.mulDivFixedPoint(ax, ay);
      if (rAbs > uint256(MAX_SD59x18)) {
        revert PRBMathSD59x18__MulOverflow(rAbs);
      }

      uint256 sx;
      uint256 sy;
      assembly {
        sx := sgt(x, sub(0, 1))
        sy := sgt(y, sub(0, 1))
      }
      result = sx ^ sy == 1 ? -int256(rAbs) : int256(rAbs);
    }
  }

  /// @notice Returns PI as a signed 59.18-decimal fixed-point number.
  function pi() internal pure returns (int256 result) {
    result = 3_141592653589793238;
  }

  /// @notice Raises x to the power of y.
  ///
  /// @dev Based on the insight that x^y = 2^(log2(x) * y).
  ///
  /// Requirements:
  /// - All from "exp2", "log2" and "mul".
  /// - z cannot be zero.
  ///
  /// Caveats:
  /// - All from "exp2", "log2" and "mul".
  /// - Assumes 0^0 is 1.
  ///
  /// @param x Number to raise to given power y, as a signed 59.18-decimal fixed-point number.
  /// @param y Exponent to raise x to, as a signed 59.18-decimal fixed-point number.
  /// @return result x raised to power y, as a signed 59.18-decimal fixed-point number.
  function pow(int256 x, int256 y) internal pure returns (int256 result) {
    if (x == 0) {
      result = y == 0 ? SCALE : int256(0);
    } else {
      result = exp2(mul(log2(x), y));
    }
  }

  /// @notice Raises x (signed 59.18-decimal fixed-point number) to the power of y (basic unsigned integer) using the
  /// famous algorithm "exponentiation by squaring".
  ///
  /// @dev See https://en.wikipedia.org/wiki/Exponentiation_by_squaring
  ///
  /// Requirements:
  /// - All from "abs" and "PRBMath.mulDivFixedPoint".
  /// - The result must fit within MAX_SD59x18.
  ///
  /// Caveats:
  /// - All from "PRBMath.mulDivFixedPoint".
  /// - Assumes 0^0 is 1.
  ///
  /// @param x The base as a signed 59.18-decimal fixed-point number.
  /// @param y The exponent as an uint256.
  /// @return result The result as a signed 59.18-decimal fixed-point number.
  function powu(int256 x, uint256 y) internal pure returns (int256 result) {
    uint256 xAbs = uint256(abs(x));

    // Calculate the first iteration of the loop in advance.
    uint256 rAbs = y & 1 > 0 ? xAbs : uint256(SCALE);

    // Equivalent to "for(y /= 2; y > 0; y /= 2)" but faster.
    uint256 yAux = y;
    for (yAux >>= 1; yAux > 0; yAux >>= 1) {
      xAbs = PRBMath.mulDivFixedPoint(xAbs, xAbs);

      // Equivalent to "y % 2 == 1" but faster.
      if (yAux & 1 > 0) {
        rAbs = PRBMath.mulDivFixedPoint(rAbs, xAbs);
      }
    }

    // The result must fit within the 59.18-decimal fixed-point representation.
    if (rAbs > uint256(MAX_SD59x18)) {
      revert PRBMathSD59x18__PowuOverflow(rAbs);
    }

    // Is the base negative and the exponent an odd number?
    bool isNegative = x < 0 && y & 1 == 1;
    result = isNegative ? -int256(rAbs) : int256(rAbs);
  }

  /// @notice Returns 1 as a signed 59.18-decimal fixed-point number.
  function scale() internal pure returns (int256 result) {
    result = SCALE;
  }

  /// @notice Calculates the square root of x, rounding down.
  /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
  ///
  /// Requirements:
  /// - x cannot be negative.
  /// - x must be less than MAX_SD59x18 / SCALE.
  ///
  /// @param x The signed 59.18-decimal fixed-point number for which to calculate the square root.
  /// @return result The result as a signed 59.18-decimal fixed-point .
  function sqrt(int256 x) internal pure returns (int256 result) {
    unchecked {
      if (x < 0) {
        revert PRBMathSD59x18__SqrtNegativeInput(x);
      }
      if (x > MAX_SD59x18 / SCALE) {
        revert PRBMathSD59x18__SqrtOverflow(x);
      }
      // Multiply x by the SCALE to account for the factor of SCALE that is picked up when multiplying two signed
      // 59.18-decimal fixed-point numbers together (in this case, those two numbers are both the square root).
      result = int256(PRBMath.sqrt(uint256(x * SCALE)));
    }
  }

  /// @notice Converts a signed 59.18-decimal fixed-point number to basic integer form, rounding down in the process.
  /// @param x The signed 59.18-decimal fixed-point number to convert.
  /// @return result The same number in basic integer form.
  function toInt(int256 x) internal pure returns (int256 result) {
    unchecked {
      result = x / SCALE;
    }
  }
}

// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;

library BlockVerifier {
  function extractStateRootAndTimestamp(
    bytes memory rlpBytes
  ) internal view returns (bytes32 stateRoot, uint256 blockTimestamp, uint256 blockNumber) {
    assembly {
      function revertWithReason(message, length) {
        mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(4, 0x20)
        mstore(0x24, length)
        mstore(0x44, message)
        revert(0, add(0x44, length))
      }

      function readDynamic(prefixPointer) -> dataPointer, dataLength {
        let value := byte(0, mload(prefixPointer))
        switch lt(value, 0x80)
        case 1 {
          dataPointer := prefixPointer
          dataLength := 1
        }
        case 0 {
          dataPointer := add(prefixPointer, 1)
          dataLength := sub(value, 0x80)
        }
      }

      // get the length of the data
      let rlpLength := mload(rlpBytes)
      // move pointer forward, ahead of length
      rlpBytes := add(rlpBytes, 0x20)

      // we know the length of the block will be between 483 bytes and 709 bytes, which means it will have 2 length bytes after the prefix byte, so we can skip 3 bytes in
      // CONSIDER: we could save a trivial amount of gas by compressing most of this into a single add instruction
      let parentHashPrefixPointer := add(rlpBytes, 3)
      let parentHashPointer := add(parentHashPrefixPointer, 1)
      let uncleHashPrefixPointer := add(parentHashPointer, 32)
      let uncleHashPointer := add(uncleHashPrefixPointer, 1)
      let minerAddressPrefixPointer := add(uncleHashPointer, 32)
      let minerAddressPointer := add(minerAddressPrefixPointer, 1)
      let stateRootPrefixPointer := add(minerAddressPointer, 20)
      let stateRootPointer := add(stateRootPrefixPointer, 1)
      let transactionRootPrefixPointer := add(stateRootPointer, 32)
      let transactionRootPointer := add(transactionRootPrefixPointer, 1)
      let receiptsRootPrefixPointer := add(transactionRootPointer, 32)
      let receiptsRootPointer := add(receiptsRootPrefixPointer, 1)
      let logsBloomPrefixPointer := add(receiptsRootPointer, 32)
      let logsBloomPointer := add(logsBloomPrefixPointer, 3)
      let difficultyPrefixPointer := add(logsBloomPointer, 256)
      let difficultyPointer, difficultyLength := readDynamic(difficultyPrefixPointer)
      let blockNumberPrefixPointer := add(difficultyPointer, difficultyLength)
      let blockNumberPointer, blockNumberLength := readDynamic(blockNumberPrefixPointer)
      let gasLimitPrefixPointer := add(blockNumberPointer, blockNumberLength)
      let gasLimitPointer, gasLimitLength := readDynamic(gasLimitPrefixPointer)
      let gasUsedPrefixPointer := add(gasLimitPointer, gasLimitLength)
      let gasUsedPointer, gasUsedLength := readDynamic(gasUsedPrefixPointer)
      let timestampPrefixPointer := add(gasUsedPointer, gasUsedLength)
      let timestampPointer, timestampLength := readDynamic(timestampPrefixPointer)

      blockNumber := shr(sub(256, mul(blockNumberLength, 8)), mload(blockNumberPointer))
      let blockHash := blockhash(blockNumber)
      let rlpHash := keccak256(rlpBytes, rlpLength)
      if iszero(eq(blockHash, rlpHash)) {
        revertWithReason("blockHash != rlpHash", 20)
      }

      stateRoot := mload(stateRootPointer)
      blockTimestamp := shr(sub(256, mul(timestampLength, 8)), mload(timestampPointer))
    }
  }
}

// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))
library FixedPoint {
  // range: [0, 2**112 - 1]
  // resolution: 1 / 2**112
  struct uq112x112 {
    uint224 _x;
  }

  // range: [0, 2**144 - 1]
  // resolution: 1 / 2**112
  struct uq144x112 {
    uint256 _x;
  }

  uint8 public constant RESOLUTION = 112;
  uint256 public constant Q112 = 0x10000000000000000000000000000; // 2**112
  uint256 private constant Q224 = 0x100000000000000000000000000000000000000000000000000000000; // 2**224
  uint256 private constant LOWER_MASK = 0xffffffffffffffffffffffffffff; // decimal of UQ*x112 (lower 112 bits)

  // returns a UQ112x112 which represents the ratio of the numerator to the denominator
  // can be lossy
  function fraction(uint256 numerator, uint256 denominator) internal pure returns (uq112x112 memory) {
    require(denominator > 0, "FixedPoint::fraction: division by zero");
    if (numerator == 0) return FixedPoint.uq112x112(0);

    if (numerator <= uint144(2 ** 144 - 1)) {
      uint256 result = (numerator << RESOLUTION) / denominator;
      require(result <= uint224(2 ** 224 - 1), "FixedPoint::fraction: overflow");
      return uq112x112(uint224(result));
    } else {
      uint256 result = mulDiv(numerator, Q112, denominator);
      require(result <= uint224(2 ** 224 - 1), "FixedPoint::fraction: overflow");
      return uq112x112(uint224(result));
    }
  }

  // decode a UQ144x112 into a uint144 by truncating after the radix point
  function decode144(uq144x112 memory self) internal pure returns (uint144) {
    return uint144(self._x >> RESOLUTION);
  }

  function mulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
    (uint256 l, uint256 h) = fullMul(x, y);

    uint256 mm = mulmod(x, y, d);
    if (mm > l) h -= 1;
    l -= mm;

    if (h == 0) return l / d;

    require(h < d, "FullMath: FULLDIV_OVERFLOW");
    return fullDiv(l, h, d);
  }

  function fullDiv(uint256 l, uint256 h, uint256 d) private pure returns (uint256) {
    uint256 pow2 = d & uint256((int256(d) * -1));
    d /= pow2;
    l /= pow2;
    l += h * ((uint256(int256(pow2) * -1)) / pow2 + 1);
    uint256 r = 1;
    r *= 2 - d * r;
    r *= 2 - d * r;
    r *= 2 - d * r;
    r *= 2 - d * r;
    r *= 2 - d * r;
    r *= 2 - d * r;
    r *= 2 - d * r;
    r *= 2 - d * r;
    return l * r;
  }

  function fullMul(uint256 x, uint256 y) internal pure returns (uint256 l, uint256 h) {
    uint256 mm = mulmod(x, y, uint256(2 ** 256 - 1));
    l = x * y;
    h = mm - l;
    if (mm < l) h -= 1;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;


import "../IERC721.sol";

interface INonfungiblePositionManager is IERC721 {
    /// @notice Emitted when liquidity is increased for a position NFT
    /// @dev Also emitted when a token is minted
    /// @param tokenId The ID of the token for which liquidity was increased
    /// @param liquidity The amount by which liquidity for the NFT position was increased
    /// @param amount0 The amount of token0 that was paid for the increase in liquidity
    /// @param amount1 The amount of token1 that was paid for the increase in liquidity
    event IncreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    /// @notice Emitted when liquidity is decreased for a position NFT
    /// @param tokenId The ID of the token for which liquidity was decreased
    /// @param liquidity The amount by which liquidity for the NFT position was decreased
    /// @param amount0 The amount of token0 that was accounted for the decrease in liquidity
    /// @param amount1 The amount of token1 that was accounted for the decrease in liquidity
    event DecreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    /// @notice Emitted when tokens are collected for a position NFT
    /// @dev The amounts reported may not be exactly equivalent to the amounts transferred, due to rounding behavior
    /// @param tokenId The ID of the token for which underlying tokens were collected
    /// @param recipient The address of the account that received the collected tokens
    /// @param amount0 The amount of token0 owed to the position that was collected
    /// @param amount1 The amount of token1 owed to the position that was collected
    event Collect(uint256 indexed tokenId, address recipient, uint256 amount0, uint256 amount1);

    /// @notice Returns the position information associated with a given token ID.
    /// @dev Throws if the token ID is not valid.
    /// @param tokenId The ID of the token that represents the position
    /// @return nonce The nonce for permits
    /// @return operator The address that is approved for spending
    /// @return token0 The address of the token0 for a specific pool
    /// @return token1 The address of the token1 for a specific pool
    /// @return fee The fee associated with the pool
    /// @return tickLower The lower end of the tick range for the position
    /// @return tickUpper The higher end of the tick range for the position
    /// @return liquidity The liquidity of the position
    /// @return feeGrowthInside0LastX128 The fee growth of token0 as of the last action on the individual position
    /// @return feeGrowthInside1LastX128 The fee growth of token1 as of the last action on the individual position
    /// @return tokensOwed0 The uncollected amount of token0 owed to the position as of the last computation
    /// @return tokensOwed1 The uncollected amount of token1 owed to the position as of the last computation
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    /// @notice Creates a new position wrapped in a NFT
    /// @dev Call this when the pool does exist and is initialized. Note that if the pool is created but not initialized
    /// a method does not exist, i.e. the pool is assumed to be initialized.
    /// @param params The params necessary to mint a position, encoded as `MintParams` in calldata
    /// @return tokenId The ID of the token that represents the minted position
    /// @return liquidity The amount of liquidity for this position
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function mint(MintParams calldata params)
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /// @notice Increases the amount of liquidity in a position, with tokens paid by the `msg.sender`
    /// @param params tokenId The ID of the token for which liquidity is being increased,
    /// amount0Desired The desired amount of token0 to be spent,
    /// amount1Desired The desired amount of token1 to be spent,
    /// amount0Min The minimum amount of token0 to spend, which serves as a slippage check,
    /// amount1Min The minimum amount of token1 to spend, which serves as a slippage check,
    /// deadline The time by which the transaction must be included to effect the change
    /// @return liquidity The new liquidity amount as a result of the increase
    /// @return amount0 The amount of token0 to acheive resulting liquidity
    /// @return amount1 The amount of token1 to acheive resulting liquidity
    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /// @notice Decreases the amount of liquidity in a position and accounts it to the position
    /// @param params tokenId The ID of the token for which liquidity is being decreased,
    /// amount The amount by which liquidity will be decreased,
    /// amount0Min The minimum amount of token0 that should be accounted for the burned liquidity,
    /// amount1Min The minimum amount of token1 that should be accounted for the burned liquidity,
    /// deadline The time by which the transaction must be included to effect the change
    /// @return amount0 The amount of token0 accounted to the position's tokens owed
    /// @return amount1 The amount of token1 accounted to the position's tokens owed
    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    /// @notice Collects up to a maximum amount of fees owed to a specific position to the recipient
    /// @param params tokenId The ID of the NFT for which tokens are being collected,
    /// recipient The account that should receive the tokens,
    /// amount0Max The maximum amount of token0 to collect,
    /// amount1Max The maximum amount of token1 to collect
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);

    /// @notice Burns a token ID, which deletes it from the NFT contract. The token must have 0 liquidity and all tokens
    /// must be collected first.
    /// @param tokenId The ID of the token that is being burned
    function burn(uint256 tokenId) external payable;
}

// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;

interface IUniswapV2Factory {
  event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

  function feeTo() external view returns (address);

  function feeToSetter() external view returns (address);

  function getPair(address tokenA, address tokenB) external view returns (address pair);

  function allPairs(uint256) external view returns (address pair);

  function allPairsLength() external view returns (uint256);

  function createPair(address tokenA, address tokenB) external returns (address pair);

  function setFeeTo(address) external;

  function setFeeToSetter(address) external;
}

// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;

interface IUniswapV2Pair {
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Transfer(address indexed from, address indexed to, uint256 value);

  function name() external pure returns (string memory);

  function symbol() external pure returns (string memory);

  function decimals() external pure returns (uint8);

  function totalSupply() external view returns (uint256);

  function balanceOf(address owner) external view returns (uint256);

  function allowance(address owner, address spender) external view returns (uint256);

  function approve(address spender, uint256 value) external returns (bool);

  function transfer(address to, uint256 value) external returns (bool);

  function transferFrom(address from, address to, uint256 value) external returns (bool);

  function DOMAIN_SEPARATOR() external view returns (bytes32);

  function PERMIT_TYPEHASH() external pure returns (bytes32);

  function nonces(address owner) external view returns (uint256);

  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  event Mint(address indexed sender, uint256 amount0, uint256 amount1);
  event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
  event Swap(
    address indexed sender,
    uint256 amount0In,
    uint256 amount1In,
    uint256 amount0Out,
    uint256 amount1Out,
    address indexed to
  );
  event Sync(uint112 reserve0, uint112 reserve1);

  function MINIMUM_LIQUIDITY() external pure returns (uint256);

  function factory() external view returns (address);

  function token0() external view returns (address);

  function token1() external view returns (address);

  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

  function price0CumulativeLast() external view returns (uint256);

  function price1CumulativeLast() external view returns (uint256);

  function kLast() external view returns (uint256);

  function mint(address to) external returns (uint256 liquidity);

  function burn(address to) external returns (uint256 amount0, uint256 amount1);

  function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

  function skim(address to) external;

  function sync() external;

  function initialize(address, address) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.9;

/// @title Pool state that is not stored
/// @notice Contains view functions to provide information about the pool that is computed rather than stored on the
/// blockchain. The functions here may have variable gas costs.
interface IUniswapV3PoolDerivedState {
  /// @notice Returns the cumulative tick and liquidity as of each timestamp `secondsAgo` from the current block timestamp
  /// @dev To get a time weighted average tick or liquidity-in-range, you must call this with two values, one representing
  /// the beginning of the period and another for the end of the period. E.g., to get the last hour time-weighted average tick,
  /// you must call it with secondsAgos = [3600, 0].
  /// @dev The time weighted average tick represents the geometric time weighted average price of the pool, in
  /// log base sqrt(1.0001) of token1 / token0. The TickMath library can be used to go from a tick value to a ratio.
  /// @param secondsAgos From how long ago each cumulative tick and liquidity value should be returned
  /// @return tickCumulatives Cumulative tick values as of each `secondsAgos` from the current block timestamp
  /// @return secondsPerLiquidityCumulativeX128s Cumulative seconds per liquidity-in-range value as of each `secondsAgos` from the current block
  /// timestamp
  function observe(
    uint32[] calldata secondsAgos
  ) external view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);

  /// @notice Returns a snapshot of the tick cumulative, seconds per liquidity and seconds inside a tick range
  /// @dev Snapshots must only be compared to other snapshots, taken over a period for which a position existed.
  /// I.e., snapshots cannot be compared if a position is not held for the entire period between when the first
  /// snapshot is taken and the second snapshot is taken.
  /// @param tickLower The lower tick of the range
  /// @param tickUpper The upper tick of the range
  /// @return tickCumulativeInside The snapshot of the tick accumulator for the range
  /// @return secondsPerLiquidityInsideX128 The snapshot of seconds per liquidity for the range
  /// @return secondsInside The snapshot of seconds per liquidity for the range
  function snapshotCumulativesInside(
    int24 tickLower,
    int24 tickUpper
  ) external view returns (int56 tickCumulativeInside, uint160 secondsPerLiquidityInsideX128, uint32 secondsInside);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.9;

/// @title Optimized overflow and underflow safe math operations
/// @notice Contains methods for doing math operations that revert on overflow or underflow for minimal gas cost
library LowGasSafeMath {
  /// @notice Returns x + y, reverts if sum overflows uint256
  /// @param x The augend
  /// @param y The addend
  /// @return z The sum of x and y
  function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require((z = x + y) >= x);
  }

  /// @notice Returns x - y, reverts if underflows
  /// @param x The minuend
  /// @param y The subtrahend
  /// @return z The difference of x and y
  function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require((z = x - y) <= x);
  }

  /// @notice Returns x * y, reverts if overflows
  /// @param x The multiplicand
  /// @param y The multiplier
  /// @return z The product of x and y
  function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require(x == 0 || (z = x * y) / x == y);
  }

  /// @notice Returns x + y, reverts if overflows or underflows
  /// @param x The augend
  /// @param y The addend
  /// @return z The sum of x and y
  function add(int256 x, int256 y) internal pure returns (int256 z) {
    require((z = x + y) >= x == (y >= 0));
  }

  /// @notice Returns x - y, reverts if overflows or underflows
  /// @param x The minuend
  /// @param y The subtrahend
  /// @return z The difference of x and y
  function sub(int256 x, int256 y) internal pure returns (int256 z) {
    require((z = x - y) <= x == (y >= 0));
  }
}

// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;
import {Rlp} from "./Rlp.sol";

library MerklePatriciaVerifier {
  /*
   * @dev Extracts the value from a merkle proof
   * @param expectedRoot The expected hash of the root node of the trie.
   * @param path The path in the trie leading to value.
   * @param proofNodesRlp RLP encoded array of proof nodes.
   * @return The value proven to exist in the merkle patricia tree whose root is `expectedRoot` at the path `path`
   *
   * WARNING: Does not currently support validation of unset/0 values!
   */
  function getValueFromProof(
    bytes32 expectedRoot,
    bytes32 path,
    bytes memory proofNodesRlp
  ) internal pure returns (bytes memory data) {
    Rlp.Item memory rlpParentNodes = Rlp.toItem(proofNodesRlp);
    Rlp.Item[] memory parentNodes = Rlp.toList(rlpParentNodes);

    bytes memory currentNode;
    Rlp.Item[] memory currentNodeList;

    bytes32 nodeKey = expectedRoot;
    uint256 pathPtr = 0;

    // our input is a 32-byte path, but we have to prepend a single 0 byte to that and pass it along as a 33 byte memory array since that is what getNibbleArray wants
    bytes memory nibblePath = new bytes(33);
    assembly {
      mstore(add(nibblePath, 33), path)
    }
    nibblePath = _getNibbleArray(nibblePath);

    require(path.length != 0, "empty path provided");

    currentNode = Rlp.toBytes(parentNodes[0]);

    for (uint256 i = 0; i < parentNodes.length; i++) {
      require(pathPtr <= nibblePath.length, "Path overflow");

      currentNode = Rlp.toBytes(parentNodes[i]);
      require(nodeKey == keccak256(currentNode), "node doesn't match key");
      currentNodeList = Rlp.toList(parentNodes[i]);

      if (currentNodeList.length == 17) {
        if (pathPtr == nibblePath.length) {
          data = Rlp.toData(currentNodeList[16]);
        }

        uint8 nextPathNibble = uint8(nibblePath[pathPtr]);
        require(nextPathNibble <= 16, "nibble too long");
        nodeKey = Rlp.toBytes32(currentNodeList[nextPathNibble]);
        pathPtr += 1;
      } else if (currentNodeList.length == 2) {
        pathPtr += _nibblesToTraverse(Rlp.toData(currentNodeList[0]), nibblePath, pathPtr);
        // leaf node
        if (pathPtr == nibblePath.length) {
          data = Rlp.toData(currentNodeList[1]);
        }
        //extension node
        require(_nibblesToTraverse(Rlp.toData(currentNodeList[0]), nibblePath, pathPtr) != 0, "invalid extension node");

        nodeKey = Rlp.toBytes32(currentNodeList[1]);
      } else {
        require(false, "unexpected length array");
      }
    }
    require(false, "not enough proof nodes");
  }

  function _nibblesToTraverse(
    bytes memory encodedPartialPath,
    bytes memory path,
    uint256 pathPtr
  ) private pure returns (uint256) {
    uint256 len;
    // encodedPartialPath has elements that are each two hex characters (1 byte), but partialPath
    // and slicedPath have elements that are each one hex character (1 nibble)
    bytes memory partialPath = _getNibbleArray(encodedPartialPath);
    bytes memory slicedPath = new bytes(partialPath.length);

    // pathPtr counts nibbles in path
    // partialPath.length is a number of nibbles
    for (uint256 i = pathPtr; i < pathPtr + partialPath.length; i++) {
      bytes1 pathNibble = path[i];
      slicedPath[i - pathPtr] = pathNibble;
    }

    if (keccak256(partialPath) == keccak256(slicedPath)) {
      len = partialPath.length;
    } else {
      len = 0;
    }
    return len;
  }

  // bytes byteArray must be hp encoded
  function _getNibbleArray(bytes memory byteArray) private pure returns (bytes memory) {
    bytes memory nibbleArray;
    if (byteArray.length == 0) return nibbleArray;

    uint8 offset;
    uint8 hpNibble = uint8(_getNthNibbleOfBytes(0, byteArray));
    if (hpNibble == 1 || hpNibble == 3) {
      nibbleArray = new bytes(byteArray.length * 2 - 1);
      bytes1 oddNibble = _getNthNibbleOfBytes(1, byteArray);
      nibbleArray[0] = oddNibble;
      offset = 1;
    } else {
      nibbleArray = new bytes(byteArray.length * 2 - 2);
      offset = 0;
    }

    for (uint256 i = offset; i < nibbleArray.length; i++) {
      nibbleArray[i] = _getNthNibbleOfBytes(i - offset + 2, byteArray);
    }
    return nibbleArray;
  }

  function _getNthNibbleOfBytes(uint256 n, bytes memory str) private pure returns (bytes1) {
    return bytes1(n % 2 == 0 ? uint8(str[n / 2]) / 0x10 : uint8(str[n / 2]) % 0x10);
  }
}

// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;

library Rlp {
  uint256 constant DATA_SHORT_START = 0x80;
  uint256 constant DATA_LONG_START = 0xB8;
  uint256 constant LIST_SHORT_START = 0xC0;
  uint256 constant LIST_LONG_START = 0xF8;

  uint256 constant DATA_LONG_OFFSET = 0xB7;
  uint256 constant LIST_LONG_OFFSET = 0xF7;

  struct Item {
    uint256 _unsafe_memPtr; // Pointer to the RLP-encoded bytes.
    uint256 _unsafe_length; // Number of bytes. This is the full length of the string.
  }

  struct Iterator {
    Item _unsafe_item; // Item that's being iterated over.
    uint256 _unsafe_nextPtr; // Position of the next item in the list.
  }

  /* Iterator */

  function next(Iterator memory self) internal pure returns (Item memory subItem) {
    require(hasNext(self), "Rlp.sol:Rlp:next:1");
    uint256 ptr = self._unsafe_nextPtr;
    uint256 itemLength = _itemLength(ptr);
    subItem._unsafe_memPtr = ptr;
    subItem._unsafe_length = itemLength;
    self._unsafe_nextPtr = ptr + itemLength;
  }

  function next(Iterator memory self, bool strict) internal pure returns (Item memory subItem) {
    subItem = next(self);
    require(!strict || _validate(subItem), "Rlp.sol:Rlp:next:2");
  }

  function hasNext(Iterator memory self) internal pure returns (bool) {
    Rlp.Item memory item = self._unsafe_item;
    return self._unsafe_nextPtr < item._unsafe_memPtr + item._unsafe_length;
  }

  /* Item */

  /// @dev Creates an Item from an array of RLP encoded bytes.
  /// @param self The RLP encoded bytes.
  /// @return An Item
  function toItem(bytes memory self) internal pure returns (Item memory) {
    uint256 len = self.length;
    if (len == 0) {
      return Item(0, 0);
    }
    uint256 memPtr;
    assembly {
      memPtr := add(self, 0x20)
    }
    return Item(memPtr, len);
  }

  /// @dev Creates an Item from an array of RLP encoded bytes.
  /// @param self The RLP encoded bytes.
  /// @param strict Will throw if the data is not RLP encoded.
  /// @return An Item
  function toItem(bytes memory self, bool strict) internal pure returns (Item memory) {
    Rlp.Item memory item = toItem(self);
    if (strict) {
      uint256 len = self.length;
      require(_payloadOffset(item) <= len, "Rlp.sol:Rlp:toItem4");
      require(_itemLength(item._unsafe_memPtr) == len, "Rlp.sol:Rlp:toItem:5");
      require(_validate(item), "Rlp.sol:Rlp:toItem:6");
    }
    return item;
  }

  /// @dev Check if the Item is null.
  /// @param self The Item.
  /// @return 'true' if the item is null.
  function isNull(Item memory self) internal pure returns (bool) {
    return self._unsafe_length == 0;
  }

  /// @dev Check if the Item is a list.
  /// @param self The Item.
  /// @return 'true' if the item is a list.
  function isList(Item memory self) internal pure returns (bool) {
    if (self._unsafe_length == 0) return false;
    uint256 memPtr = self._unsafe_memPtr;
    bool result;
    assembly {
      result := iszero(lt(byte(0, mload(memPtr)), 0xC0))
    }
    return result;
  }

  /// @dev Check if the Item is data.
  /// @param self The Item.
  /// @return 'true' if the item is data.
  function isData(Item memory self) internal pure returns (bool) {
    if (self._unsafe_length == 0) return false;
    uint256 memPtr = self._unsafe_memPtr;
    bool result;
    assembly {
      result := lt(byte(0, mload(memPtr)), 0xC0)
    }
    return result;
  }

  /// @dev Check if the Item is empty (string or list).
  /// @param self The Item.
  /// @return result 'true' if the item is null.
  function isEmpty(Item memory self) internal pure returns (bool) {
    if (isNull(self)) return false;
    uint256 b0;
    uint256 memPtr = self._unsafe_memPtr;
    assembly {
      b0 := byte(0, mload(memPtr))
    }
    return (b0 == DATA_SHORT_START || b0 == LIST_SHORT_START);
  }

  /// @dev Get the number of items in an RLP encoded list.
  /// @param self The Item.
  /// @return The number of items.
  function items(Item memory self) internal pure returns (uint256) {
    if (!isList(self)) return 0;
    uint256 b0;
    uint256 memPtr = self._unsafe_memPtr;
    assembly {
      b0 := byte(0, mload(memPtr))
    }
    uint256 pos = memPtr + _payloadOffset(self);
    uint256 last = memPtr + self._unsafe_length - 1;
    uint256 itms;
    while (pos <= last) {
      pos += _itemLength(pos);
      itms++;
    }
    return itms;
  }

  /// @dev Create an iterator.
  /// @param self The Item.
  /// @return An 'Iterator' over the item.
  function iterator(Item memory self) internal pure returns (Iterator memory) {
    require(isList(self), "Rlp.sol:Rlp:iterator:1");
    uint256 ptr = self._unsafe_memPtr + _payloadOffset(self);
    Iterator memory it;
    it._unsafe_item = self;
    it._unsafe_nextPtr = ptr;
    return it;
  }

  /// @dev Return the RLP encoded bytes.
  /// @param self The Item.
  /// @return The bytes.
  function toBytes(Item memory self) internal pure returns (bytes memory) {
    uint256 len = self._unsafe_length;
    require(len != 0, "Rlp.sol:Rlp:toBytes:2");
    bytes memory bts;
    bts = new bytes(len);
    _copyToBytes(self._unsafe_memPtr, bts, len);
    return bts;
  }

  /// @dev Decode an Item into bytes. This will not work if the
  /// Item is a list.
  /// @param self The Item.
  /// @return The decoded string.
  function toData(Item memory self) internal pure returns (bytes memory) {
    require(isData(self));
    (uint256 rStartPos, uint256 len) = _decode(self);
    bytes memory bts;
    bts = new bytes(len);
    _copyToBytes(rStartPos, bts, len);
    return bts;
  }

  /// @dev Get the list of sub-items from an RLP encoded list.
  /// Warning: This is inefficient, as it requires that the list is read twice.
  /// @param self The Item.
  /// @return Array of Items.
  function toList(Item memory self) internal pure returns (Item[] memory) {
    require(isList(self), "Rlp.sol:Rlp:toList:1");
    uint256 numItems = items(self);
    Item[] memory list = new Item[](numItems);
    Rlp.Iterator memory it = iterator(self);
    uint256 idx;
    while (hasNext(it)) {
      list[idx] = next(it);
      idx++;
    }
    return list;
  }

  /// @dev Decode an Item into an ascii string. This will not work if the
  /// Item is a list.
  /// @param self The Item.
  /// @return The decoded string.
  function toAscii(Item memory self) internal pure returns (string memory) {
    require(isData(self), "Rlp.sol:Rlp:toAscii:1");
    (uint256 rStartPos, uint256 len) = _decode(self);
    bytes memory bts = new bytes(len);
    _copyToBytes(rStartPos, bts, len);
    string memory str = string(bts);
    return str;
  }

  /// @dev Decode an Item into a uint. This will not work if the
  /// Item is a list.
  /// @param self The Item.
  /// @return The decoded string.
  function toUint(Item memory self) internal pure returns (uint256) {
    require(isData(self), "Rlp.sol:Rlp:toUint:1");
    (uint256 rStartPos, uint256 len) = _decode(self);
    require(len <= 32, "Rlp.sol:Rlp:toUint:3");
    require(len != 0, "Rlp.sol:Rlp:toUint:4");
    uint256 data;
    assembly {
      data := div(mload(rStartPos), exp(256, sub(32, len)))
    }
    return data;
  }

  /// @dev Decode an Item into a boolean. This will not work if the
  /// Item is a list.
  /// @param self The Item.
  /// @return The decoded string.
  function toBool(Item memory self) internal pure returns (bool) {
    require(isData(self), "Rlp.sol:Rlp:toBool:1");
    (uint256 rStartPos, uint256 len) = _decode(self);
    require(len == 1, "Rlp.sol:Rlp:toBool:3");
    uint256 temp;
    assembly {
      temp := byte(0, mload(rStartPos))
    }
    require(temp <= 1, "Rlp.sol:Rlp:toBool:8");
    return temp == 1 ? true : false;
  }

  /// @dev Decode an Item into an int. This will not work if the
  /// Item is a list.
  /// @param self The Item.
  /// @return The decoded string.
  function toInt(Item memory self) internal pure returns (int256) {
    return int256(toUint(self));
  }

  /// @dev Decode an Item into a bytes32. This will not work if the
  /// Item is a list.
  /// @param self The Item.
  /// @return The decoded string.
  function toBytes32(Item memory self) internal pure returns (bytes32) {
    return bytes32(toUint(self));
  }

  /// @dev Decode an Item into an address. This will not work if the
  /// Item is a list.
  /// @param self The Item.
  /// @return The decoded string.
  function toAddress(Item memory self) internal pure returns (address) {
    require(isData(self), "Rlp.sol:Rlp:toAddress:1");
    (uint256 rStartPos, uint256 len) = _decode(self);
    require(len == 20, "Rlp.sol:Rlp:toAddress:3");
    address data;
    assembly {
      data := div(mload(rStartPos), exp(256, 12))
    }
    return data;
  }

  // Get the payload offset.
  function _payloadOffset(Item memory self) private pure returns (uint256) {
    if (self._unsafe_length == 0) return 0;
    uint256 b0;
    uint256 memPtr = self._unsafe_memPtr;
    assembly {
      b0 := byte(0, mload(memPtr))
    }
    if (b0 < DATA_SHORT_START) return 0;
    if (b0 < DATA_LONG_START || (b0 >= LIST_SHORT_START && b0 < LIST_LONG_START)) return 1;
    if (b0 < LIST_SHORT_START) return b0 - DATA_LONG_OFFSET + 1;
    return b0 - LIST_LONG_OFFSET + 1;
  }

  // Get the full length of an Item.
  function _itemLength(uint256 memPtr) private pure returns (uint256 len) {
    uint256 b0;
    assembly {
      b0 := byte(0, mload(memPtr))
    }
    if (b0 < DATA_SHORT_START) len = 1;
    else if (b0 < DATA_LONG_START) len = b0 - DATA_SHORT_START + 1;
    else if (b0 < LIST_SHORT_START) {
      assembly {
        let bLen := sub(b0, 0xB7) // bytes length (DATA_LONG_OFFSET)
        let dLen := div(mload(add(memPtr, 1)), exp(256, sub(32, bLen))) // data length
        len := add(1, add(bLen, dLen)) // total length
      }
    } else if (b0 < LIST_LONG_START) len = b0 - LIST_SHORT_START + 1;
    else {
      assembly {
        let bLen := sub(b0, 0xF7) // bytes length (LIST_LONG_OFFSET)
        let dLen := div(mload(add(memPtr, 1)), exp(256, sub(32, bLen))) // data length
        len := add(1, add(bLen, dLen)) // total length
      }
    }
  }

  // Get start position and length of the data.
  function _decode(Item memory self) private pure returns (uint256 memPtr, uint256 len) {
    require(isData(self), "Rlp.sol:Rlp:_decode:1");
    uint256 b0;
    uint256 start = self._unsafe_memPtr;
    assembly {
      b0 := byte(0, mload(start))
    }
    if (b0 < DATA_SHORT_START) {
      memPtr = start;
      len = 1;
      return (memPtr, len);
    }
    if (b0 < DATA_LONG_START) {
      len = self._unsafe_length - 1;
      memPtr = start + 1;
    } else {
      uint256 bLen;
      assembly {
        bLen := sub(b0, 0xB7) // DATA_LONG_OFFSET
      }
      len = self._unsafe_length - 1 - bLen;
      memPtr = start + bLen + 1;
    }
    return (memPtr, len);
  }

  // Assumes that enough memory has been allocated to store in target.
  function _copyToBytes(uint256 sourceBytes, bytes memory destinationBytes, uint256 btsLen) internal pure {
    // Exploiting the fact that 'tgt' was the last thing to be allocated,
    // we can write entire words, and just overwrite any excess.
    assembly {
      let words := div(add(btsLen, 31), 32)
      let sourcePointer := sourceBytes
      let destinationPointer := add(destinationBytes, 32)
      for {
        let i := 0
      } lt(i, words) {
        i := add(i, 1)
      } {
        let offset := mul(i, 32)
        mstore(add(destinationPointer, offset), mload(add(sourcePointer, offset)))
      }
      mstore(add(destinationBytes, add(32, mload(destinationBytes))), 0)
    }
  }

  // Check that an Item is valid.
  function _validate(Item memory self) private pure returns (bool ret) {
    // Check that RLP is well-formed.
    uint256 b0;
    uint256 b1;
    uint256 memPtr = self._unsafe_memPtr;
    assembly {
      b0 := byte(0, mload(memPtr))
      b1 := byte(1, mload(memPtr))
    }
    if (b0 == DATA_SHORT_START + 1 && b1 < DATA_SHORT_START) return false;
    return true;
  }

  function rlpBytesToUint256(bytes memory source) internal pure returns (uint256 result) {
    return Rlp.toUint(Rlp.toItem(source));
  }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.9;

/// @title Math library for computing sqrt prices from ticks and vice versa
/// @notice Computes sqrt price for ticks of size 1.0001, i.e. sqrt(1.0001^tick) as fixed point Q64.96 numbers. Supports
/// prices between 2**-128 and 2**128
library TickMath {
  /// @dev The minimum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**-128
  int24 internal constant MIN_TICK = -887272;
  /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
  int24 internal constant MAX_TICK = -MIN_TICK;

  /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
  uint160 internal constant MIN_SQRT_RATIO = 4295128739;
  /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
  uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

  /// @notice Calculates sqrt(1.0001^tick) * 2^96
  /// @dev Throws if |tick| > max tick
  /// @param tick The input tick for the above formula
  /// @return sqrtPriceX96 A Fixed point Q64.96 number representing the sqrt of the ratio of the two assets (token1/token0)
  /// at the given tick
  function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
    uint256 absTick = (tick < 0) ? uint256(-int256(tick)) : uint256(int256(tick));
    require(absTick <= uint256(int256(MAX_TICK)), "T");

    uint256 ratio = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
    if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
    if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
    if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
    if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
    if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
    if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
    if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
    if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
    if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
    if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
    if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
    if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
    if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
    if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
    if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
    if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
    if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
    if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
    if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

    if (tick > 0) ratio = type(uint256).max / ratio;

    // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
    // we then downcast because we know the result always fits within 160 bits due to our tick input constraint
    // we round up in the division so getTickAtSqrtRatio of the output price is always consistent
    sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
  }

  /// @notice Calculates the greatest tick value such that getRatioAtTick(tick) <= ratio
  /// @dev Throws in case sqrtPriceX96 < MIN_SQRT_RATIO, as MIN_SQRT_RATIO is the lowest value getRatioAtTick may
  /// ever return.
  /// @param sqrtPriceX96 The sqrt ratio for which to compute the tick as a Q64.96
  /// @return tick The greatest tick for which the ratio is less than or equal to the input ratio
  function getTickAtSqrtRatio(uint160 sqrtPriceX96) internal pure returns (int24 tick) {
    // second inequality must be < because the price can never reach the price at the max tick
    require(sqrtPriceX96 >= MIN_SQRT_RATIO && sqrtPriceX96 < MAX_SQRT_RATIO, "R");
    uint256 ratio = uint256(sqrtPriceX96) << 32;

    uint256 r = ratio;
    uint256 msb = 0;

    assembly {
      let f := shl(7, gt(r, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
      msb := or(msb, f)
      r := shr(f, r)
    }
    assembly {
      let f := shl(6, gt(r, 0xFFFFFFFFFFFFFFFF))
      msb := or(msb, f)
      r := shr(f, r)
    }
    assembly {
      let f := shl(5, gt(r, 0xFFFFFFFF))
      msb := or(msb, f)
      r := shr(f, r)
    }
    assembly {
      let f := shl(4, gt(r, 0xFFFF))
      msb := or(msb, f)
      r := shr(f, r)
    }
    assembly {
      let f := shl(3, gt(r, 0xFF))
      msb := or(msb, f)
      r := shr(f, r)
    }
    assembly {
      let f := shl(2, gt(r, 0xF))
      msb := or(msb, f)
      r := shr(f, r)
    }
    assembly {
      let f := shl(1, gt(r, 0x3))
      msb := or(msb, f)
      r := shr(f, r)
    }
    assembly {
      let f := gt(r, 0x1)
      msb := or(msb, f)
    }

    if (msb >= 128) r = ratio >> (msb - 127);
    else r = ratio << (127 - msb);

    int256 log_2 = (int256(msb) - 128) << 64;

    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(63, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(62, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(61, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(60, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(59, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(58, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(57, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(56, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(55, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(54, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(53, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(52, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(51, f))
      r := shr(f, r)
    }
    assembly {
      r := shr(127, mul(r, r))
      let f := shr(128, r)
      log_2 := or(log_2, shl(50, f))
    }

    int256 log_sqrt10001 = log_2 * 255738958999603826347141; // 128.128 number

    int24 tickLow = int24((log_sqrt10001 - 3402992956809132418596140100660247210) >> 128);
    int24 tickHi = int24((log_sqrt10001 + 291339464771989622907027621153398088495) >> 128);

    tick = tickLow == tickHi ? tickLow : getSqrtRatioAtTick(tickHi) <= sqrtPriceX96 ? tickHi : tickLow;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;
pragma experimental ABIEncoderV2;

import {BlockVerifier} from "./BlockVerifier.sol";
import {MerklePatriciaVerifier} from "./MerklePatriciaVerifier.sol";
import {Rlp} from "./Rlp.sol";
import {IUniswapV2Pair} from "./IUniswapV2Pair.sol";
import {UQ112x112} from "./UQ112x112.sol";

contract UniswapOracle {
  using UQ112x112 for uint224;

  bytes32 public constant reserveTimestampSlotHash = keccak256(abi.encodePacked(uint256(8)));
  bytes32 public constant token0Slot = keccak256(abi.encodePacked(uint256(9)));
  bytes32 public constant token1Slot = keccak256(abi.encodePacked(uint256(10)));

  struct ProofData {
    bytes block;
    bytes accountProofNodesRlp;
    bytes reserveAndTimestampProofNodesRlp;
    bytes priceAccumulatorProofNodesRlp;
  }

  function getAccountStorageRoot(
    address uniswapV2Pair,
    ProofData memory proofData
  ) public view returns (bytes32 storageRootHash, uint256 blockNumber, uint256 blockTimestamp) {
    bytes32 stateRoot;
    (stateRoot, blockTimestamp, blockNumber) = BlockVerifier.extractStateRootAndTimestamp(proofData.block);
    bytes memory accountDetailsBytes = MerklePatriciaVerifier.getValueFromProof(
      stateRoot,
      keccak256(abi.encodePacked(uniswapV2Pair)),
      proofData.accountProofNodesRlp
    );
    Rlp.Item[] memory accountDetails = Rlp.toList(Rlp.toItem(accountDetailsBytes));
    return (Rlp.toBytes32(accountDetails[2]), blockNumber, blockTimestamp);
  }

  // This function verifies the full block is old enough (MIN_BLOCK_COUNT), not too old (or blockhash will return 0x0) and return the proof values for the two storage slots we care about
  function verifyBlockAndExtractReserveData(
    IUniswapV2Pair uniswapV2Pair,
    uint8 minBlocksBack,
    uint8 maxBlocksBack,
    bytes32 slotHash,
    ProofData memory proofData
  )
    public
    view
    returns (
      uint256 blockTimestamp,
      uint256 blockNumber,
      uint256 priceCumulativeLast,
      uint112 reserve0,
      uint112 reserve1,
      uint256 reserveTimestamp
    )
  {
    bytes32 storageRootHash;
    (storageRootHash, blockNumber, blockTimestamp) = getAccountStorageRoot(address(uniswapV2Pair), proofData);
    require(blockNumber <= block.number - minBlocksBack, "Proof does not span enough blocks");
    require(blockNumber >= block.number - maxBlocksBack, "Proof spans too many blocks");

    priceCumulativeLast = Rlp.rlpBytesToUint256(
      MerklePatriciaVerifier.getValueFromProof(storageRootHash, slotHash, proofData.priceAccumulatorProofNodesRlp)
    );
    uint256 reserve0Reserve1TimestampPacked = Rlp.rlpBytesToUint256(
      MerklePatriciaVerifier.getValueFromProof(
        storageRootHash,
        reserveTimestampSlotHash,
        proofData.reserveAndTimestampProofNodesRlp
      )
    );
    reserveTimestamp = reserve0Reserve1TimestampPacked >> (112 + 112);
    reserve1 = uint112((reserve0Reserve1TimestampPacked >> 112) & (2 ** 112 - 1));
    reserve0 = uint112(reserve0Reserve1TimestampPacked & (2 ** 112 - 1));
  }

  function getPrice(
    IUniswapV2Pair uniswapV2Pair,
    address denominationToken,
    uint8 minBlocksBack,
    uint8 maxBlocksBack,
    ProofData memory proofData
  ) public view returns (uint256 price, uint256 blockNumber) {
    // exchange = the ExchangeV2Pair. check denomination token (USE create2 check?!) check gas cost
    bool denominationTokenIs0;
    if (uniswapV2Pair.token0() == denominationToken) {
      denominationTokenIs0 = true;
    } else if (uniswapV2Pair.token1() == denominationToken) {
      denominationTokenIs0 = false;
    } else {
      revert("denominationToken invalid");
    }
    return getPriceRaw(uniswapV2Pair, denominationTokenIs0, minBlocksBack, maxBlocksBack, proofData);
  }

  function getPriceRaw(
    IUniswapV2Pair uniswapV2Pair,
    bool denominationTokenIs0,
    uint8 minBlocksBack,
    uint8 maxBlocksBack,
    ProofData memory proofData
  ) public view returns (uint256 price, uint256 blockNumber) {
    uint256 historicBlockTimestamp;
    uint256 historicPriceCumulativeLast;
    {
      // Stack-too-deep workaround, manual scope
      // Side-note: wtf Solidity?
      uint112 reserve0;
      uint112 reserve1;
      uint256 reserveTimestamp;
      (
        historicBlockTimestamp,
        blockNumber,
        historicPriceCumulativeLast,
        reserve0,
        reserve1,
        reserveTimestamp
      ) = verifyBlockAndExtractReserveData(
        uniswapV2Pair,
        minBlocksBack,
        maxBlocksBack,
        denominationTokenIs0 ? token1Slot : token0Slot,
        proofData
      );
      uint256 secondsBetweenReserveUpdateAndHistoricBlock = historicBlockTimestamp - reserveTimestamp;
      // bring old record up-to-date, in case there was no cumulative update in provided historic block itself
      if (secondsBetweenReserveUpdateAndHistoricBlock > 0) {
        historicPriceCumulativeLast +=
          secondsBetweenReserveUpdateAndHistoricBlock *
          uint256(
            UQ112x112.encode(denominationTokenIs0 ? reserve0 : reserve1).uqdiv(
              denominationTokenIs0 ? reserve1 : reserve0
            )
          );
      }
    }
    uint256 secondsBetweenProvidedBlockAndNow = block.timestamp - historicBlockTimestamp;
    price =
      (getCurrentPriceCumulativeLast(uniswapV2Pair, denominationTokenIs0) - historicPriceCumulativeLast) /
      secondsBetweenProvidedBlockAndNow;
    return (price, blockNumber);
  }

  function getCurrentPriceCumulativeLast(
    IUniswapV2Pair uniswapV2Pair,
    bool denominationTokenIs0
  ) public view returns (uint256 priceCumulativeLast) {
    (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = uniswapV2Pair.getReserves();
    priceCumulativeLast = denominationTokenIs0
      ? uniswapV2Pair.price1CumulativeLast()
      : uniswapV2Pair.price0CumulativeLast();
    uint256 timeElapsed = block.timestamp - blockTimestampLast;
    priceCumulativeLast +=
      timeElapsed *
      uint256(
        UQ112x112.encode(denominationTokenIs0 ? reserve0 : reserve1).uqdiv(denominationTokenIs0 ? reserve1 : reserve0)
      );
  }
}

// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;

import "./IUniswapV2Pair.sol";
import "./FixedPoint.sol";

// library with helper methods for oracles that are concerned with computing average prices
library UniswapV2OracleLibrary {
  using FixedPoint for *;

  // helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
  function currentBlockTimestamp() internal view returns (uint32) {
    return uint32(block.timestamp % 2 ** 32);
  }

  // produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
  function currentCumulativePrices(
    address pair
  ) internal view returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) {
    blockTimestamp = currentBlockTimestamp();
    price0Cumulative = IUniswapV2Pair(pair).price0CumulativeLast();
    price1Cumulative = IUniswapV2Pair(pair).price1CumulativeLast();

    // if time has elapsed since the last update on the pair, mock the accumulated price values
    (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IUniswapV2Pair(pair).getReserves();
    if (blockTimestampLast != blockTimestamp) {
      // subtraction overflow is desired
      uint32 timeElapsed = blockTimestamp - blockTimestampLast;
      // addition overflow is desired
      // counterfactual
      price0Cumulative += uint256(FixedPoint.fraction(reserve1, reserve0)._x) * timeElapsed;
      // counterfactual
      price1Cumulative += uint256(FixedPoint.fraction(reserve0, reserve1)._x) * timeElapsed;
    }
  }
}

// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;

// https://raw.githubusercontent.com/Uniswap/uniswap-v2-core/master/contracts/libraries/UQ112x112.sol
// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))

// range: [0, 2**112 - 1]
// resolution: 1 / 2**112

library UQ112x112 {
  uint224 constant Q112 = 2 ** 112;

  // encode a uint112 as a UQ112x112
  function encode(uint112 y) internal pure returns (uint224 z) {
    z = uint224(y) * Q112; // never overflows
  }

  // divide a UQ112x112 by a uint112, returning a UQ112x112
  function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
    z = x / uint224(y);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../_external/Ownable.sol";
import "./ICurveMaster.sol";
import "./ICurveSlave.sol";
import "../lending/IVaultController.sol";

/// @title Curve Master
/// @notice Curve master keeps a record of CurveSlave contracts and links it with an address
/// @dev all numbers should be scaled to 1e18. for instance, number 5e17 represents 50%
contract CurveMaster is ICurveMaster, Ownable {
  // mapping of token to address
  mapping(address => address) public _curves;

  address public _vaultControllerAddress;
  IVaultController private _VaultController;

  /// @notice gets the return value of curve labled token_address at x_value
  /// @param token_address the key to lookup the curve with in the mapping
  /// @param x_value the x value to pass to the slave
  /// @return y value of the curve
  function getValueAt(address token_address, int256 x_value) external view override returns (int256) {
    require(_curves[token_address] != address(0x0), "token not enabled");
    ICurveSlave curve = ICurveSlave(_curves[token_address]);
    int256 value = curve.valueAt(x_value);
    require(value != 0, "result must be nonzero");
    return value;
  }

  /// @notice set the VaultController addr in order to pay interest on curve setting
  /// @param vault_master_address address of vault master
  function setVaultController(address vault_master_address) external override onlyOwner {
    _vaultControllerAddress = vault_master_address;
    _VaultController = IVaultController(vault_master_address);
  }

  function vaultControllerAddress() external view override returns (address) {
    return _vaultControllerAddress;
  }

  ///@notice setting a new curve should pay interest
  function setCurve(address token_address, address curve_address) external override onlyOwner {
    if (address(_VaultController) != address(0)) {
      _VaultController.calculateInterest();
    }
    _curves[token_address] = curve_address;
  }

  /// @notice special function that does not calculate interest, used for deployment et al
  function forceSetCurve(address token_address, address curve_address) external override onlyOwner {
    _curves[token_address] = curve_address;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/// @title CurveMaster Interface
/// @notice Interface for interacting with CurveMaster
interface ICurveMaster {
  function vaultControllerAddress() external view returns (address);

  function getValueAt(address token_address, int256 x_value) external view returns (int256);

  function _curves(address curve_address) external view returns (address);

  function setVaultController(address vault_master_address) external;

  function setCurve(address token_address, address curve_address) external;

  function forceSetCurve(address token_address, address curve_address) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/// @title CurveSlave Interface
/// @notice Interface for interacting with CurveSlaves
interface ICurveSlave {
  function valueAt(int256 x_value) external view returns (int256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../ICurveSlave.sol";

/// @title Piecewise linear curve f(x)
/// @notice returns values for input values 0 to 1e18,
/// described by variables _r0, _r1, and _r2, along with _s1 and _s2
/// graph of function appears below code
// solhint-disable-next-line contract-name-camelcase
contract ThreeLines0_100 is ICurveSlave {
  int256 public immutable _r0;
  int256 public immutable _r1;
  int256 public immutable _r2;
  int256 public immutable _s1;
  int256 public immutable _s2;

  /// @notice curve is constructed on deploy and may not be modified
  /// @param r0 y value at x=0
  /// @param r1 y value at the x=s1
  /// @param r2 y value at x >= s2 && x < 1e18
  /// @param s1 x value of first breakpoint
  /// @param s2 x value of second breakpoint
  constructor(int256 r0, int256 r1, int256 r2, int256 s1, int256 s2) {
    require((0 < r2) && (r2 < r1) && (r1 < r0), "Invalid curve");
    require((0 < s1) && (s1 < s2) && (s2 < 1e18), "Invalid breakpoint values");

    _r0 = r0;
    _r1 = r1;
    _r2 = r2;
    _s1 = s1;
    _s2 = s2;
  }

  /// @notice calculates f(x)
  /// @param x_value x value to evaluate
  /// @return value of f(x)
  function valueAt(int256 x_value) external view override returns (int256) {
    // the x value must be between 0 (0%) and 1e18 (100%)
    require(x_value >= 0, "too small");
    if (x_value > 1e18) {
      x_value = 1e18;
    }

    // first piece of the piece wise function
    if (x_value < _s1) {
      int256 rise = _r1 - _r0;
      int256 run = _s1;
      return linearInterpolation(rise, run, x_value, _r0);
    }
    // second piece of the piece wise function
    if (x_value < _s2) {
      int256 rise = _r2 - _r1;
      int256 run = _s2 - _s1;
      return linearInterpolation(rise, run, x_value - _s1, _r1);
    }
    // the third and final piece of piecewise function, simply a line
    // since we already know that x_value <= 1e18, this is safe
    return _r2;
  }

  /// @notice linear interpolation, calculates g(x) = (rise/run)x+b
  /// @param rise x delta, used to calculate, "rise" in our equation
  /// @param run y delta, used to calculate "run" in our equation
  /// @param distance distance to interpolate. "x" in our equation
  /// @param b y intercept, "b" in our equation
  /// @return value of g(x)
  function linearInterpolation(int256 rise, int256 run, int256 distance, int256 b) private pure returns (int256) {
    // 6 digits of precision should be more than enough
    int256 mE6 = (rise * 1e6) / run;
    // simply multiply the slope by the distance traveled and add the intercept
    // don't forget to unscale the 1e6 by dividing. b is never scaled, and so it is not unscaled
    int256 result = (mE6 * distance) / 1e6 + b;
    return result;
  }
}
/// (0, _r0)
///      |\
///      | -\
///      |   \
///      |    -\
///      |      -\
///      |        \
///      |         -\
///      |           \
///      |            -\
///      |              -\
///      |                \
///      |                 -\
///      |                   \
///      |                    -\
///      |                      -\
///      |                        \
///      |                         -\
///      |                          ***----\
///      |                     (_s1, _r1)   ----\
///      |                                       ----\
///      |                                            ----\
///      |                                                 ----\ (_s2, _r2)
///      |                                                             ***--------------------------------------------------------------\
///      |
///      |
///      |
///      |
///      +---------------------------------------------------------------------------------------------------------------------------------
/// (0,0)                                                                                                                            (100, _r2)

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "./IGovernor.sol";
import "./GovernorStorage.sol";

contract GovernorCharlieDelegate is GovernorCharlieDelegateStorage, GovernorCharlieEvents, IGovernorCharlieDelegate {
  /// @notice The name of this contract
  string public constant name = "Interest Protocol Governor";

  /// @notice The maximum number of actions that can be included in a proposal
  uint256 public constant proposalMaxOperations = 10;

  /// @notice The EIP-712 typehash for the contract's domain
  bytes32 public constant DOMAIN_TYPEHASH =
    keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

  /// @notice The EIP-712 typehash for the ballot struct used by the contract
  bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

  /// @notice The time for a proposal to be executed after passing
  uint256 public constant GRACE_PERIOD = 14 days;

  /**
   * @notice Used to initialize the contract during delegator contructor
   * @param ipt_ The address of the IPT token
   */
  function initialize(address ipt_) external override {
    require(!initialized, "already been initialized");
    ipt = IIpt(ipt_);
    votingPeriod = 40320;
    votingDelay = 13140;
    proposalThreshold = 1000000000000000000000000;
    proposalTimelockDelay = 172800;
    proposalCount = 0;
    quorumVotes = 10000000000000000000000000;
    emergencyQuorumVotes = 40000000000000000000000000;
    emergencyVotingPeriod = 6570;
    emergencyTimelockDelay = 43200;

    optimisticQuorumVotes = 2000000000000000000000000;
    optimisticVotingDelay = 25600;
    maxWhitelistPeriod = 31536000;

    initialized = true;
  }

  /// @notice any function with this modifier can only be called by governance
  modifier onlyGov() {
    require(_msgSender() == address(this), "must come from the gov.");
    _;
  }

  /**
   * @notice Function used to propose a new proposal. Sender must have delegates above the proposal threshold
   * @param targets Target addresses for proposal calls
   * @param values Eth values for proposal calls
   * @param signatures Function signatures for proposal calls
   * @param calldatas Calldatas for proposal calls
   * @param description String description of the proposal
   * @param emergency Bool to determine if proposal an emergency proposal
   * @return Proposal id of new proposal
   */
  function propose(
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory description,
    bool emergency
  ) public override returns (uint256) {
    // Reject proposals before initiating as Governor
    require(quorumVotes != 0, "Charlie not active");
    // Allow addresses above proposal threshold and whitelisted addresses to propose
    require(
      ipt.getPriorVotes(_msgSender(), (block.number - 1)) >= proposalThreshold || isWhitelisted(_msgSender()),
      "votes below proposal threshold"
    );
    require(
      targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length,
      "information arity mismatch"
    );
    require(targets.length != 0, "must provide actions");
    require(targets.length <= proposalMaxOperations, "too many actions");

    uint256 latestProposalId = latestProposalIds[_msgSender()];
    if (latestProposalId != 0) {
      ProposalState proposersLatestProposalState = state(latestProposalId);
      require(proposersLatestProposalState != ProposalState.Active, "one active proposal per proposer");
      require(proposersLatestProposalState != ProposalState.Pending, "one pending proposal per proposer");
    }

    proposalCount++;
    Proposal memory newProposal = Proposal({
      id: proposalCount,
      proposer: _msgSender(),
      eta: 0,
      targets: targets,
      values: values,
      signatures: signatures,
      calldatas: calldatas,
      startBlock: block.number + votingDelay,
      endBlock: block.number + votingDelay + votingPeriod,
      forVotes: 0,
      againstVotes: 0,
      abstainVotes: 0,
      canceled: false,
      executed: false,
      emergency: emergency,
      quorumVotes: quorumVotes,
      delay: proposalTimelockDelay
    });

    //whitelist can't make emergency
    if (emergency && !isWhitelisted(_msgSender())) {
      newProposal.startBlock = block.number;
      newProposal.endBlock = block.number + emergencyVotingPeriod;
      newProposal.quorumVotes = emergencyQuorumVotes;
      newProposal.delay = emergencyTimelockDelay;
    }

    //whitelist can only make optimistic proposals
    if (isWhitelisted(_msgSender())) {
      newProposal.quorumVotes = optimisticQuorumVotes;
      newProposal.startBlock = block.number + optimisticVotingDelay;
      newProposal.endBlock = block.number + optimisticVotingDelay + votingPeriod;
    }

    proposals[newProposal.id] = newProposal;
    latestProposalIds[newProposal.proposer] = newProposal.id;

    emit ProposalCreated(
      newProposal.id,
      _msgSender(),
      targets,
      values,
      signatures,
      calldatas,
      newProposal.startBlock,
      newProposal.endBlock,
      description
    );
    return newProposal.id;
  }

  /**
   * @notice Queues a proposal of state succeeded
   * @param proposalId The id of the proposal to queue
   */
  function queue(uint256 proposalId) external override {
    require(state(proposalId) == ProposalState.Succeeded, "can only be queued if succeeded");
    Proposal storage proposal = proposals[proposalId];
    uint256 eta = block.timestamp + proposal.delay;
    for (uint256 i = 0; i < proposal.targets.length; i++) {
      require(
        !queuedTransactions[
          keccak256(
            abi.encode(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], eta)
          )
        ],
        "proposal already queued"
      );
      queueTransaction(
        proposal.targets[i],
        proposal.values[i],
        proposal.signatures[i],
        proposal.calldatas[i],
        eta,
        proposal.delay
      );
    }
    proposal.eta = eta;
    emit ProposalQueued(proposalId, eta);
  }

  function queueTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta,
    uint256 delay
  ) internal returns (bytes32) {
    require(eta >= (getBlockTimestamp() + delay), "must satisfy delay.");

    bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
    queuedTransactions[txHash] = true;

    emit QueueTransaction(txHash, target, value, signature, data, eta);
    return txHash;
  }

  /**
   * @notice Executes a queued proposal if eta has passed
   * @param proposalId The id of the proposal to execute
   */
  function execute(uint256 proposalId) external payable override {
    require(state(proposalId) == ProposalState.Queued, "can only be exec'd if queued");
    Proposal storage proposal = proposals[proposalId];
    proposal.executed = true;
    for (uint256 i = 0; i < proposal.targets.length; i++) {
      this.executeTransaction{value: proposal.values[i]}(
        proposal.targets[i],
        proposal.values[i],
        proposal.signatures[i],
        proposal.calldatas[i],
        proposal.eta
      );
    }
    emit ProposalExecuted(proposalId);
  }

  function executeTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
  ) external payable override {
    require(msg.sender == address(this), "execute must come from this address");

    bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
    require(queuedTransactions[txHash], "tx hasn't been queued.");
    require(getBlockTimestamp() >= eta, "tx hasn't surpassed timelock.");
    require(getBlockTimestamp() <= eta + GRACE_PERIOD, "tx is stale.");

    queuedTransactions[txHash] = false;

    bytes memory callData;

    if (bytes(signature).length == 0) {
      callData = data;
    } else {
      callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
    }

    // solhint-disable-next-line avoid-low-level-calls
    (bool success /*bytes memory returnData*/, ) = target.call{value: value}(callData);
    require(success, "tx execution reverted.");

    emit ExecuteTransaction(txHash, target, value, signature, data, eta);
  }

  /**
   * @notice Cancels a proposal only if sender is the proposer, or proposer delegates dropped below proposal threshold
   * @notice whitelistGuardian can cancel proposals from whitelisted addresses
   * @param proposalId The id of the proposal to cancel
   */
  function cancel(uint256 proposalId) external override {
    require(state(proposalId) != ProposalState.Executed, "cant cancel executed proposal");

    Proposal storage proposal = proposals[proposalId];

    // Proposer can cancel
    if (_msgSender() != proposal.proposer) {
      // Whitelisted proposers can't be canceled for falling below proposal threshold
      if (isWhitelisted(proposal.proposer)) {
        require(
          (ipt.getPriorVotes(proposal.proposer, (block.number - 1)) < proposalThreshold) &&
            _msgSender() == whitelistGuardian,
          "cancel: whitelisted proposer"
        );
      } else {
        require(
          (ipt.getPriorVotes(proposal.proposer, (block.number - 1)) < proposalThreshold),
          "cancel: proposer above threshold"
        );
      }
    }

    proposal.canceled = true;
    for (uint256 i = 0; i < proposal.targets.length; i++) {
      cancelTransaction(
        proposal.targets[i],
        proposal.values[i],
        proposal.signatures[i],
        proposal.calldatas[i],
        proposal.eta
      );
    }

    emit ProposalCanceled(proposalId);
  }

  function cancelTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
  ) internal {
    bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
    queuedTransactions[txHash] = false;

    emit CancelTransaction(txHash, target, value, signature, data, eta);
  }

  /**
   * @notice Gets actions of a proposal
   * @param proposalId the id of the proposal
   * @return targets proposal targets
   * @return values proposal values
   * @return signatures proposal signatures
   * @return calldatas proposal calldatae
   */
  function getActions(
    uint256 proposalId
  )
    external
    view
    override
    returns (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas)
  {
    Proposal storage p = proposals[proposalId];
    return (p.targets, p.values, p.signatures, p.calldatas);
  }

  /**
   * @notice Gets the receipt for a voter on a given proposal
   * @param proposalId the id of proposal
   * @param voter The address of the voter
   * @return The voting receipt
   */
  function getReceipt(uint256 proposalId, address voter) external view override returns (Receipt memory) {
    return proposalReceipts[proposalId][voter];
  }

  /**
   * @notice Gets the state of a proposal
   * @param proposalId The id of the proposal
   * @return Proposal state
   */
  // solhint-disable-next-line code-complexity
  function state(uint256 proposalId) public view override returns (ProposalState) {
    require(proposalCount >= proposalId && proposalId > initialProposalId, "state: invalid proposal id");
    Proposal storage proposal = proposals[proposalId];
    bool whitelisted = isWhitelisted(proposal.proposer);
    if (proposal.canceled) {
      return ProposalState.Canceled;
    } else if (block.number <= proposal.startBlock) {
      return ProposalState.Pending;
    } else if (block.number <= proposal.endBlock) {
      return ProposalState.Active;
    } else if (
      (whitelisted && proposal.againstVotes > proposal.quorumVotes) ||
      (!whitelisted && proposal.forVotes <= proposal.againstVotes) ||
      (!whitelisted && proposal.forVotes < proposal.quorumVotes)
    ) {
      return ProposalState.Defeated;
    } else if (proposal.eta == 0) {
      return ProposalState.Succeeded;
    } else if (proposal.executed) {
      return ProposalState.Executed;
    } else if (block.timestamp >= (proposal.eta + GRACE_PERIOD)) {
      return ProposalState.Expired;
    }
    return ProposalState.Queued;
  }

  /**
   * @notice Cast a vote for a proposal
   * @param proposalId The id of the proposal to vote on
   * @param support The support value for the vote. 0=against, 1=for, 2=abstain
   */
  function castVote(uint256 proposalId, uint8 support) external override {
    emit VoteCast(_msgSender(), proposalId, support, castVoteInternal(_msgSender(), proposalId, support), "");
  }

  /**
   * @notice Cast a vote for a proposal with a reason
   * @param proposalId The id of the proposal to vote on
   * @param support The support value for the vote. 0=against, 1=for, 2=abstain
   * @param reason The reason given for the vote by the voter
   */
  function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external override {
    emit VoteCast(_msgSender(), proposalId, support, castVoteInternal(_msgSender(), proposalId, support), reason);
  }

  /**
   * @notice Cast a vote for a proposal by signature
   * @dev external override function that accepts EIP-712 signatures for voting on proposals.
   */
  function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external override {
    bytes32 domainSeparator = keccak256(
      abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainIdInternal(), address(this))
    );
    bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));

    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

    require(
      uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
      "castVoteBySig: invalid signature"
    );
    address signatory = ecrecover(digest, v, r, s);
    require(signatory != address(0x0), "castVoteBySig: invalid signature");
    emit VoteCast(signatory, proposalId, support, castVoteInternal(signatory, proposalId, support), "");
  }

  /**
   * @notice Internal function that caries out voting logic
   * @param voter The voter that is casting their vote
   * @param proposalId The id of the proposal to vote on
   * @param support The support value for the vote. 0=against, 1=for, 2=abstain
   * @return The number of votes cast
   */
  function castVoteInternal(address voter, uint256 proposalId, uint8 support) internal returns (uint96) {
    require(state(proposalId) == ProposalState.Active, "voting is closed");
    require(support <= 2, "invalid vote type");
    Proposal storage proposal = proposals[proposalId];
    Receipt storage receipt = proposalReceipts[proposalId][voter];
    require(receipt.hasVoted == false, "voter already voted");
    uint96 votes = ipt.getPriorVotes(voter, proposal.startBlock);

    if (support == 0) {
      proposal.againstVotes = proposal.againstVotes + votes;
    } else if (support == 1) {
      proposal.forVotes = proposal.forVotes + votes;
    } else if (support == 2) {
      proposal.abstainVotes = proposal.abstainVotes + votes;
    }

    receipt.hasVoted = true;
    receipt.support = support;
    receipt.votes = votes;

    return votes;
  }

  /**
   * @notice View function which returns if an account is whitelisted
   * @param account Account to check white list status of
   * @return If the account is whitelisted
   */
  function isWhitelisted(address account) public view override returns (bool) {
    return (whitelistAccountExpirations[account] > block.timestamp);
  }

  /**
   * @notice Governance function for setting the governance token
   * @param  token_ new token addr
   */
  function _setNewToken(address token_) external onlyGov {
    ipt = IIpt(token_);
  }

  /**
   * @notice Governance function for setting the max whitelist period
   * @param  second how many seconds to whitelist for
   */
  function setMaxWhitelistPeriod(uint256 second) external onlyGov {
    maxWhitelistPeriod = second;
  }

  /**
   * @notice Used to update the timelock period
   * @param proposalTimelockDelay_ The proposal holding period
   */
  function _setDelay(uint256 proposalTimelockDelay_) public override onlyGov {
    uint256 oldTimelockDelay = proposalTimelockDelay;
    proposalTimelockDelay = proposalTimelockDelay_;

    emit NewDelay(oldTimelockDelay, proposalTimelockDelay);
  }

  /**
   * @notice Used to update the emergency timelock period
   * @param emergencyTimelockDelay_ The proposal holding period
   */
  function _setEmergencyDelay(uint256 emergencyTimelockDelay_) public override onlyGov {
    uint256 oldEmergencyTimelockDelay = emergencyTimelockDelay;
    emergencyTimelockDelay = emergencyTimelockDelay_;

    emit NewEmergencyDelay(oldEmergencyTimelockDelay, emergencyTimelockDelay);
  }

  /**
   * @notice Governance function for setting the voting delay
   * @param newVotingDelay new voting delay, in blocks
   */
  function _setVotingDelay(uint256 newVotingDelay) external override onlyGov {
    uint256 oldVotingDelay = votingDelay;
    votingDelay = newVotingDelay;

    emit VotingDelaySet(oldVotingDelay, votingDelay);
  }

  /**
   * @notice Governance function for setting the voting period
   * @param newVotingPeriod new voting period, in blocks
   */
  function _setVotingPeriod(uint256 newVotingPeriod) external override onlyGov {
    uint256 oldVotingPeriod = votingPeriod;
    votingPeriod = newVotingPeriod;

    emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
  }

  /**
   * @notice Governance function for setting the emergency voting period
   * @param newEmergencyVotingPeriod new voting period, in blocks
   */
  function _setEmergencyVotingPeriod(uint256 newEmergencyVotingPeriod) external override onlyGov {
    uint256 oldEmergencyVotingPeriod = emergencyVotingPeriod;
    emergencyVotingPeriod = newEmergencyVotingPeriod;

    emit EmergencyVotingPeriodSet(oldEmergencyVotingPeriod, emergencyVotingPeriod);
  }

  /**
   * @notice Governance function for setting the proposal threshold
   * @param newProposalThreshold new proposal threshold
   */
  function _setProposalThreshold(uint256 newProposalThreshold) external override onlyGov {
    uint256 oldProposalThreshold = proposalThreshold;
    proposalThreshold = newProposalThreshold;

    emit ProposalThresholdSet(oldProposalThreshold, proposalThreshold);
  }

  /**
   * @notice Governance function for setting the quorum
   * @param newQuorumVotes new proposal quorum
   */
  function _setQuorumVotes(uint256 newQuorumVotes) external override onlyGov {
    uint256 oldQuorumVotes = quorumVotes;
    quorumVotes = newQuorumVotes;

    emit NewQuorum(oldQuorumVotes, quorumVotes);
  }

  /**
   * @notice Governance function for setting the emergency quorum
   * @param newEmergencyQuorumVotes new proposal quorum
   */
  function _setEmergencyQuorumVotes(uint256 newEmergencyQuorumVotes) external override onlyGov {
    uint256 oldEmergencyQuorumVotes = emergencyQuorumVotes;
    emergencyQuorumVotes = newEmergencyQuorumVotes;

    emit NewEmergencyQuorum(oldEmergencyQuorumVotes, emergencyQuorumVotes);
  }

  /**
   * @notice Governance function for setting the whitelist expiration as a timestamp
   * for an account. Whitelist status allows accounts to propose without meeting threshold
   * @param account Account address to set whitelist expiration for
   * @param expiration Expiration for account whitelist status as timestamp (if now < expiration, whitelisted)
   */
  function _setWhitelistAccountExpiration(address account, uint256 expiration) external override onlyGov {
    require(expiration < (maxWhitelistPeriod + block.timestamp), "expiration exceeds max");
    whitelistAccountExpirations[account] = expiration;

    emit WhitelistAccountExpirationSet(account, expiration);
  }

  /**
   * @notice Governance function for setting the whitelistGuardian. WhitelistGuardian can cancel proposals from whitelisted addresses
   * @param account Account to set whitelistGuardian to (0x0 to remove whitelistGuardian)
   */
  function _setWhitelistGuardian(address account) external override onlyGov {
    address oldGuardian = whitelistGuardian;
    whitelistGuardian = account;

    emit WhitelistGuardianSet(oldGuardian, whitelistGuardian);
  }

  /**
   * @notice Governance function for setting the optimistic voting delay
   * @param newOptimisticVotingDelay new optimistic voting delay, in blocks
   */
  function _setOptimisticDelay(uint256 newOptimisticVotingDelay) external override onlyGov {
    uint256 oldOptimisticVotingDelay = optimisticVotingDelay;
    optimisticVotingDelay = newOptimisticVotingDelay;

    emit OptimisticVotingDelaySet(oldOptimisticVotingDelay, optimisticVotingDelay);
  }

  /**
   * @notice Governance function for setting the optimistic quorum
   * @param newOptimisticQuorumVotes new optimistic quorum votes, in blocks
   */
  function _setOptimisticQuorumVotes(uint256 newOptimisticQuorumVotes) external override onlyGov {
    uint256 oldOptimisticQuorumVotes = optimisticQuorumVotes;
    optimisticQuorumVotes = newOptimisticQuorumVotes;

    emit OptimisticQuorumVotesSet(oldOptimisticQuorumVotes, optimisticQuorumVotes);
  }

  function getChainIdInternal() internal view returns (uint256) {
    return block.chainid;
  }

  function getBlockTimestamp() internal view returns (uint256) {
    // solium-disable-next-line security/no-block-members
    return block.timestamp;
  }

  function _msgSender() internal view virtual returns (address) {
    return msg.sender;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "./IGovernor.sol";
import "./GovernorStorage.sol";

contract GovernorCharlieDelegator is GovernorCharlieDelegatorStorage, GovernorCharlieEvents, IGovernorCharlieDelegator {
  constructor(address ipt_, address implementation_) {
    delegateTo(implementation_, abi.encodeWithSignature("initialize(address)", ipt_));
    address oldImplementation = implementation;
    implementation = implementation_;
    emit NewImplementation(oldImplementation, implementation);
  }

  /**
   * @notice Called by itself via governance to update the implementation of the delegator
   * @param implementation_ The address of the new implementation for delegation
   */
  function _setImplementation(address implementation_) public override {
    require(msg.sender == address(this), "governance proposal required");
    require(implementation_ != address(0), "invalid implementation address");

    address oldImplementation = implementation;
    implementation = implementation_;

    emit NewImplementation(oldImplementation, implementation);
  }

  /**
   * @notice Internal method to delegate execution to another contract
   * @dev It returns to the external caller whatever the implementation returns or forwards reverts
   * @param callee The contract to delegatecall
   * @param data The raw data to delegatecall
   */
  function delegateTo(address callee, bytes memory data) internal {
    //solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory returnData) = callee.delegatecall(data);
    //solhint-disable-next-line no-inline-assembly
    assembly {
      if eq(success, 0) {
        revert(add(returnData, 0x20), returndatasize())
      }
    }
  }

  /**
   * @dev Delegates execution to an implementation contract.
   * It returns to the external caller whatever the implementation returns
   * or forwards reverts.
   */
  // solhint-disable-next-line no-complex-fallback
  fallback() external payable override {
    // delegate all other functions to current implementation
    //solhint-disable-next-line avoid-low-level-calls
    (bool success, ) = implementation.delegatecall(msg.data);

    //solhint-disable-next-line no-inline-assembly
    assembly {
      let free_mem_ptr := mload(0x40)
      returndatacopy(free_mem_ptr, 0, returndatasize())

      switch success
      case 0 {
        revert(free_mem_ptr, returndatasize())
      }
      default {
        return(free_mem_ptr, returndatasize())
      }
    }
  }

  receive() external payable override {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./IIpt.sol";
import "./Structs.sol";

contract GovernorCharlieDelegatorStorage {
  /// @notice Active brains of Governor
  address public implementation;
}

/**
 * @title Storage for Governor Charlie Delegate
 * @notice For future upgrades, do not change GovernorCharlieDelegateStorage. Create a new
 * contract which implements GovernorCharlieDelegateStorage and following the naming convention
 * GovernorCharlieDelegateStorageVX.
 */
//solhint-disable-next-line max-states-count
contract GovernorCharlieDelegateStorage is GovernorCharlieDelegatorStorage {
  /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
  uint256 public quorumVotes;

  /// @notice The number of votes in support of a proposal required in order for an emergency quorum to be reached and for a vote to succeed
  uint256 public emergencyQuorumVotes;

  /// @notice The delay before voting on a proposal may take place, once proposed, in blocks
  uint256 public votingDelay;

  /// @notice The duration of voting on a proposal, in blocks
  uint256 public votingPeriod;

  /// @notice The number of votes required in order for a voter to become a proposer
  uint256 public proposalThreshold;

  /// @notice Initial proposal id set at become
  uint256 public initialProposalId;

  /// @notice The total number of proposals
  uint256 public proposalCount;

  /// @notice The address of the Interest Protocol governance token
  IIpt public ipt;

  /// @notice The official record of all proposals ever proposed
  mapping(uint256 => Proposal) public proposals;

  /// @notice The latest proposal for each proposer
  mapping(address => uint256) public latestProposalIds;

  /// @notice The latest proposal for each proposer
  mapping(bytes32 => bool) public queuedTransactions;

  /// @notice The proposal holding period
  uint256 public proposalTimelockDelay;

  /// @notice Stores the expiration of account whitelist status as a timestamp
  mapping(address => uint256) public whitelistAccountExpirations;

  /// @notice Address which manages whitelisted proposals and whitelist accounts
  address public whitelistGuardian;

  /// @notice The duration of the voting on a emergency proposal, in blocks
  uint256 public emergencyVotingPeriod;

  /// @notice The emergency proposal holding period
  uint256 public emergencyTimelockDelay;

  /// all receipts for proposal
  mapping(uint256 => mapping(address => Receipt)) public proposalReceipts;

  /// @notice The emergency proposal holding period
  bool public initialized;

  /// @notice The number of votes to reject an optimistic proposal
  uint256 public optimisticQuorumVotes;

  /// @notice The delay period before voting begins
  uint256 public optimisticVotingDelay;

  /// @notice The maximum number of seconds an address can be whitelisted for
  uint256 public maxWhitelistPeriod;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./Structs.sol";

/// @title interface to interact with TokenDelgator
interface IGovernorCharlieDelegator {
  function _setImplementation(address implementation_) external;

  fallback() external payable;

  receive() external payable;
}

/// @title interface to interact with TokenDelgate
interface IGovernorCharlieDelegate {
  function initialize(address ipt_) external;

  function propose(
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory description,
    bool emergency
  ) external returns (uint256);

  function queue(uint256 proposalId) external;

  function execute(uint256 proposalId) external payable;

  function executeTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
  ) external payable;

  function cancel(uint256 proposalId) external;

  function getActions(
    uint256 proposalId
  )
    external
    view
    returns (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas);

  function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory);

  function state(uint256 proposalId) external view returns (ProposalState);

  function castVote(uint256 proposalId, uint8 support) external;

  function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external;

  function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external;

  function isWhitelisted(address account) external view returns (bool);

  function _setDelay(uint256 proposalTimelockDelay_) external;

  function _setEmergencyDelay(uint256 emergencyTimelockDelay_) external;

  function _setVotingDelay(uint256 newVotingDelay) external;

  function _setVotingPeriod(uint256 newVotingPeriod) external;

  function _setEmergencyVotingPeriod(uint256 newEmergencyVotingPeriod) external;

  function _setProposalThreshold(uint256 newProposalThreshold) external;

  function _setQuorumVotes(uint256 newQuorumVotes) external;

  function _setEmergencyQuorumVotes(uint256 newEmergencyQuorumVotes) external;

  function _setWhitelistAccountExpiration(address account, uint256 expiration) external;

  function _setWhitelistGuardian(address account) external;

  function _setOptimisticDelay(uint256 newOptimisticVotingDelay) external;

  function _setOptimisticQuorumVotes(uint256 newOptimisticQuorumVotes) external;
}

/// @title interface which contains all events emitted by delegator & delegate
interface GovernorCharlieEvents {
  /// @notice An event emitted when a new proposal is created
  event ProposalCreated(
    uint256 indexed id,
    address indexed proposer,
    address[] targets,
    uint256[] values,
    string[] signatures,
    bytes[] calldatas,
    uint256 indexed startBlock,
    uint256 endBlock,
    string description
  );

  /// @notice An event emitted when a vote has been cast on a proposal
  /// @param voter The address which casted a vote
  /// @param proposalId The proposal id which was voted on
  /// @param support Support value for the vote. 0=against, 1=for, 2=abstain
  /// @param votes Number of votes which were cast by the voter
  /// @param reason The reason given for the vote by the voter
  event VoteCast(address indexed voter, uint256 indexed proposalId, uint8 support, uint256 votes, string reason);

  /// @notice An event emitted when a proposal has been canceled
  event ProposalCanceled(uint256 indexed id);

  /// @notice An event emitted when a proposal has been queued in the Timelock
  event ProposalQueued(uint256 indexed id, uint256 eta);

  /// @notice An event emitted when a proposal has been executed in the Timelock
  event ProposalExecuted(uint256 indexed id);

  /// @notice An event emitted when the voting delay is set
  event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);

  /// @notice An event emitted when the voting period is set
  event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);

  /// @notice An event emitted when the emergency voting period is set
  event EmergencyVotingPeriodSet(uint256 oldEmergencyVotingPeriod, uint256 emergencyVotingPeriod);

  /// @notice Emitted when implementation is changed
  event NewImplementation(address oldImplementation, address newImplementation);

  /// @notice Emitted when proposal threshold is set
  event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);

  /// @notice Emitted when pendingAdmin is changed
  event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

  /// @notice Emitted when pendingAdmin is accepted, which means admin is updated
  event NewAdmin(address oldAdmin, address newAdmin);

  /// @notice Emitted when whitelist account expiration is set
  event WhitelistAccountExpirationSet(address account, uint256 expiration);

  /// @notice Emitted when the whitelistGuardian is set
  event WhitelistGuardianSet(address oldGuardian, address newGuardian);

  /// @notice Emitted when the a new delay is set
  event NewDelay(uint256 oldTimelockDelay, uint256 proposalTimelockDelay);

  /// @notice Emitted when the a new emergency delay is set
  event NewEmergencyDelay(uint256 oldEmergencyTimelockDelay, uint256 emergencyTimelockDelay);

  /// @notice Emitted when the quorum is updated
  event NewQuorum(uint256 oldQuorumVotes, uint256 quorumVotes);

  /// @notice Emitted when the emergency quorum is updated
  event NewEmergencyQuorum(uint256 oldEmergencyQuorumVotes, uint256 emergencyQuorumVotes);

  /// @notice An event emitted when the optimistic voting delay is set
  event OptimisticVotingDelaySet(uint256 oldOptimisticVotingDelay, uint256 optimisticVotingDelay);

  /// @notice Emitted when the optimistic quorum is updated
  event OptimisticQuorumVotesSet(uint256 oldOptimisticQuorumVotes, uint256 optimisticQuorumVotes);

  /// @notice Emitted when a transaction is canceled
  event CancelTransaction(
    bytes32 indexed txHash,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 eta
  );

  /// @notice Emitted when a transaction is executed
  event ExecuteTransaction(
    bytes32 indexed txHash,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 eta
  );

  /// @notice Emitted when a transaction is queued
  event QueueTransaction(
    bytes32 indexed txHash,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 eta
  );
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IIpt {
  function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

struct Proposal {
  /// @notice Unique id for looking up a proposal
  uint256 id;
  /// @notice Creator of the proposal
  address proposer;
  /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
  uint256 eta;
  /// @notice the ordered list of target addresses for calls to be made
  address[] targets;
  /// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
  uint256[] values;
  /// @notice The ordered list of function signatures to be called
  string[] signatures;
  /// @notice The ordered list of calldata to be passed to each call
  bytes[] calldatas;
  /// @notice The block at which voting begins: holders must delegate their votes prior to this block
  uint256 startBlock;
  /// @notice The block at which voting ends: votes must be cast prior to this block
  uint256 endBlock;
  /// @notice Current number of votes in favor of this proposal
  uint256 forVotes;
  /// @notice Current number of votes in opposition to this proposal
  uint256 againstVotes;
  /// @notice Current number of votes for abstaining for this proposal
  uint256 abstainVotes;
  /// @notice Flag marking whether the proposal has been canceled
  bool canceled;
  /// @notice Flag marking whether the proposal has been executed
  bool executed;
  /// @notice Whether the proposal is an emergency proposal
  bool emergency;
  /// @notice quorum votes requires
  uint256 quorumVotes;
  /// @notice time delay
  uint256 delay;
}

/// @notice Ballot receipt record for a voter
struct Receipt {
  /// @notice Whether or not a vote has been cast
  bool hasVoted;
  /// @notice Whether or not the voter supports the proposal or abstains
  uint8 support;
  /// @notice The number of votes the voter had, which were cast
  uint96 votes;
}

/// @notice Possible states that a proposal may be in
enum ProposalState {
  Pending,
  Active,
  Canceled,
  Defeated,
  Succeeded,
  Queued,
  Expired,
  Executed
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

/// @title interface to interact with TokenDelgator
interface ITokenDelegator {
  function _setImplementation(address implementation_) external;

  function _setOwner(address owner_) external;

  fallback() external payable;

  receive() external payable;
}

/// @title interface to interact with TokenDelgate
interface ITokenDelegate {
  function initialize(address account_, uint256 initialSupply_) external;

  function changeName(string calldata name_) external;

  function changeSymbol(string calldata symbol_) external;

  function allowance(address account, address spender) external view returns (uint256);

  function approve(address spender, uint256 rawAmount) external returns (bool);

  function balanceOf(address account) external view returns (uint256);

  function transfer(address dst, uint256 rawAmount) external returns (bool);

  function transferFrom(address src, address dst, uint256 rawAmount) external returns (bool);

  //function mint(address dst, uint256 rawAmount) external;

  function permit(
    address owner,
    address spender,
    uint256 rawAmount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  function delegate(address delegatee) external;

  function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;

  function getCurrentVotes(address account) external view returns (uint96);

  function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);
}

/// @title interface which contains all events emitted by delegator & delegate
interface TokenEvents {
  /// @notice An event thats emitted when an account changes its delegate
  event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

  /// @notice An event thats emitted when a delegate account's vote balance changes
  event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

  /// @notice An event thats emitted when the minter changes
  event MinterChanged(address indexed oldMinter, address indexed newMinter);

  /// @notice The standard EIP-20 transfer event
  event Transfer(address indexed from, address indexed to, uint256 amount);

  /// @notice The standard EIP-20 approval event
  event Approval(address indexed owner, address indexed spender, uint256 amount);

  /// @notice Emitted when implementation is changed
  event NewImplementation(address oldImplementation, address newImplementation);

  /// @notice An event thats emitted when the token symbol is changed
  event ChangedSymbol(string oldSybmol, string newSybmol);

  /// @notice An event thats emitted when the token name is changed
  event ChangedName(string oldName, string newName);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "./IToken.sol";
import "./TokenStorage.sol";

contract InterestProtocolTokenDelegate is TokenDelegateStorageV1, TokenEvents, ITokenDelegate {
  /// @notice The EIP-712 typehash for the contract's domain
  bytes32 public constant DOMAIN_TYPEHASH =
    keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

  /// @notice The EIP-712 typehash for the delegation struct used by the contract
  bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

  /// @notice The EIP-712 typehash for the permit struct used by the contract
  bytes32 public constant PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

  uint96 public constant UINT96_MAX = 2 ** 96 - 1;

  uint256 public constant UINT256_MAX = 2 ** 256 - 1;

  /**
   * @notice Used to initialize the contract during delegator constructor
   * @param account_ The address to recieve initial suppply   * @param initialSupply_ set initial supply
   */
  function initialize(address account_, uint256 initialSupply_) public override {
    require(totalSupply == 0, "initialize: can only do once");
    require(account_ != address(0), "initialize: invalid address");
    require(initialSupply_ > 0, "invalid initial supply");

    totalSupply = initialSupply_;

    require(initialSupply_ < 2 ** 96, "initialSupply_ overflow uint96");

    balances[account_] = uint96(totalSupply);
    emit Transfer(address(0), account_, totalSupply);
  }

  /**
   * @notice Change token name
   * @param name_ New token name
   */
  function changeName(string calldata name_) external override onlyOwner {
    require(bytes(name_).length > 0, "changeName: length invaild");

    emit ChangedName(name, name_);

    name = name_;
  }

  /**
   * @notice Change token symbol
   * @param symbol_ New token symbol
   */
  function changeSymbol(string calldata symbol_) external override onlyOwner {
    require(bytes(symbol_).length > 0, "changeSymbol: length invaild");

    emit ChangedSymbol(symbol, symbol_);

    symbol = symbol_;
  }

  /**
   * @notice Get the number of tokens `spender` is approved to spend on behalf of `account`
   * @param account The address of the account holding the funds
   * @param spender The address of the account spending the funds
   * @return The number of tokens approved
   */
  function allowance(address account, address spender) external view override returns (uint256) {
    return allowances[account][spender];
  }

  /**
   * @notice Approve `spender` to transfer up to `amount` from `src`
   * @dev This will overwrite the approval amount for `spender`
   *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
   * @param spender The address of the account which may transfer tokens
   * @param rawAmount The number of tokens that are approved (2^256-1 means infinite)
   * @return Whether or not the approval succeeded
   */
  function approve(address spender, uint256 rawAmount) external override returns (bool) {
    uint96 amount;
    if (rawAmount == UINT256_MAX) {
      amount = UINT96_MAX;
    } else {
      amount = safe96(rawAmount, "approve: amount exceeds 96 bits");
    }

    allowances[msg.sender][spender] = amount;

    emit Approval(msg.sender, spender, amount);
    return true;
  }

  /**
   * @notice Triggers an approval from owner to spends
   * @param owner The address to approve from
   * @param spender The address to be approved
   * @param rawAmount The number of tokens that are approved (2^256-1 means infinite)
   * @param deadline The time at which to expire the signature
   * @param v The recovery byte of the signature
   * @param r Half of the ECDSA signature pair
   * @param s Half of the ECDSA signature pair
   */
  function permit(
    address owner,
    address spender,
    uint256 rawAmount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external override {
    uint96 amount;
    if (rawAmount == UINT256_MAX) {
      amount = UINT96_MAX;
    } else {
      amount = safe96(rawAmount, "permit: amount exceeds 96 bits");
    }

    bytes32 domainSeparator = keccak256(
      abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainid(), address(this))
    );
    bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, rawAmount, nonces[owner]++, deadline));
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    require(
      uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
      "permit: invalid signature"
    );
    address signatory = ecrecover(digest, v, r, s);
    require(signatory != address(0x0), "permit: invalid signature");

    require(block.timestamp <= deadline, "permit: signature expired");

    allowances[owner][spender] = amount;

    emit Approval(owner, spender, amount);
  }

  /**
   * @notice Get the number of tokens held by the `account`
   * @param account The address of the account to get the balance of
   * @return The number of tokens held
   */
  function balanceOf(address account) external view override returns (uint256) {
    return balances[account];
  }

  /**
   * @notice Transfer `amount` tokens from `msg.sender` to `dst`
   * @param dst The address of the destination account
   * @param rawAmount The number of tokens to transfer
   * @return Whether or not the transfer succeeded
   */
  function transfer(address dst, uint256 rawAmount) external override returns (bool) {
    uint96 amount = safe96(rawAmount, "transfer: amount exceeds 96 bits");
    _transferTokens(msg.sender, dst, amount);
    return true;
  }

  /**
   * @notice Transfer `amount` tokens from `src` to `dst`
   * @param src The address of the source account
   * @param dst The address of the destination account
   * @param rawAmount The number of tokens to transfer
   * @return Whether or not the transfer succeeded
   */
  function transferFrom(address src, address dst, uint256 rawAmount) external override returns (bool) {
    address spender = msg.sender;
    uint96 spenderAllowance = allowances[src][spender];
    uint96 amount = safe96(rawAmount, "transferFrom: amount exceeds 96 bits");

    if (spender != src && spenderAllowance != UINT96_MAX) {
      uint96 newAllowance = sub96(spenderAllowance, amount, "transferFrom: transfer amount exceeds spender allowance");
      allowances[src][spender] = newAllowance;

      emit Approval(src, spender, newAllowance);
    }

    _transferTokens(src, dst, amount);
    return true;
  }

  /**
   * @notice Mint new tokens
   * @param dst The address of the destination account
   * @param rawAmount The number of tokens to be minted
   */
  /**
   * Removed mint for compliance
   function mint(address dst, uint256 rawAmount) external override onlyOwner {
    require(dst != address(0), "mint: cant transfer to 0 address");
    uint96 amount = safe96(rawAmount, "mint: amount exceeds 96 bits");
    totalSupply = safe96(totalSupply + amount, "mint: totalSupply exceeds 96 bits");

    // transfer the amount to the recipient
    balances[dst] = add96(balances[dst], amount, "mint: transfer amount overflows");
    emit Transfer(address(0), dst, amount);

    // move delegates
    _moveDelegates(address(0), delegates[dst], amount);
  }
   */

  /**
   * @notice Delegate votes from `msg.sender` to `delegatee`
   * @param delegatee The address to delegate votes to
   */
  function delegate(address delegatee) public override {
    return _delegate(msg.sender, delegatee);
  }

  /**
   * @notice Delegates votes from signatory to `delegatee`
   * @param delegatee The address to delegate votes to
   * @param nonce The contract state required to match the signature
   * @param expiry The time at which to expire the signature
   * @param v The recovery byte of the signature
   * @param r Half of the ECDSA signature pair
   * @param s Half of the ECDSA signature pair
   */
  function delegateBySig(
    address delegatee,
    uint256 nonce,
    uint256 expiry,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public override {
    bytes32 domainSeparator = keccak256(
      abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainid(), address(this))
    );
    bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    require(
      uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
      "delegateBySig: invalid signature"
    );
    address signatory = ecrecover(digest, v, r, s);
    require(signatory != address(0x0), "delegateBySig: invalid signature");

    require(nonce == nonces[signatory]++, "delegateBySig: invalid nonce");
    require(block.timestamp <= expiry, "delegateBySig: signature expired");
    return _delegate(signatory, delegatee);
  }

  /**
   * @notice Gets the current votes balance for `account`
   * @param account The address to get votes balance
   * @return The number of current votes for `account`
   */
  function getCurrentVotes(address account) external view override returns (uint96) {
    uint32 nCheckpoints = numCheckpoints[account];
    return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
  }

  /**
   * @notice Determine the prior number of votes for an account as of a block number
   * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
   * @param account The address of the account to check
   * @param blockNumber The block number to get the vote balance at
   * @return The number of votes the account had as of the given block
   */
  function getPriorVotes(address account, uint256 blockNumber) public view override returns (uint96) {
    require(blockNumber < block.number, "getPriorVotes: not determined");
    bool ok = false;
    uint96 votes = 0;
    // check naive cases
    (ok, votes) = _naivePriorVotes(account, blockNumber);
    if (ok == true) {
      return votes;
    }
    uint32 lower = 0;
    uint32 upper = numCheckpoints[account] - 1;
    while (upper > lower) {
      uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
      Checkpoint memory cp = checkpoints[account][center];
      (ok, lower, upper) = _binarySearch(cp.fromBlock, blockNumber, lower, upper);
      if (ok == true) {
        return cp.votes;
      }
    }
    return checkpoints[account][lower].votes;
  }

  function _naivePriorVotes(address account, uint256 blockNumber) internal view returns (bool ok, uint96 ans) {
    uint32 nCheckpoints = numCheckpoints[account];
    // if no checkpoints, must be 0
    if (nCheckpoints == 0) {
      return (true, 0);
    }
    // First check most recent balance
    if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
      return (true, checkpoints[account][nCheckpoints - 1].votes);
    }
    // Next check implicit zero balance
    if (checkpoints[account][0].fromBlock > blockNumber) {
      return (true, 0);
    }
    return (false, 0);
  }

  function _binarySearch(
    uint32 from,
    uint256 blk,
    uint32 lower,
    uint32 upper
  ) internal pure returns (bool ok, uint32 newLower, uint32 newUpper) {
    uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
    if (from == blk) {
      return (true, 0, 0);
    }
    if (from < blk) {
      return (false, center, upper);
    }
    return (false, lower, center - 1);
  }

  function _delegate(address delegator, address delegatee) internal {
    address currentDelegate = delegates[delegator];
    uint96 delegatorBalance = balances[delegator];
    delegates[delegator] = delegatee;

    emit DelegateChanged(delegator, currentDelegate, delegatee);

    _moveDelegates(currentDelegate, delegatee, delegatorBalance);
  }

  function _transferTokens(address src, address dst, uint96 amount) internal {
    require(src != address(0), "_transferTokens: cant 0addr");
    require(dst != address(0), "_transferTokens: cant 0addr");

    balances[src] = sub96(balances[src], amount, "_transferTokens: transfer amount exceeds balance");
    balances[dst] = add96(balances[dst], amount, "_transferTokens: transfer amount overflows");
    emit Transfer(src, dst, amount);

    _moveDelegates(delegates[src], delegates[dst], amount);
  }

  function _moveDelegates(address srcRep, address dstRep, uint96 amount) internal {
    if (srcRep != dstRep && amount > 0) {
      if (srcRep != address(0)) {
        uint32 srcRepNum = numCheckpoints[srcRep];
        uint96 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
        uint96 srcRepNew = sub96(srcRepOld, amount, "_moveVotes: vote amt underflows");
        _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
      }

      if (dstRep != address(0)) {
        uint32 dstRepNum = numCheckpoints[dstRep];
        uint96 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
        uint96 dstRepNew = add96(dstRepOld, amount, "_moveVotes: vote amt overflows");
        _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
      }
    }
  }

  function _writeCheckpoint(address delegatee, uint32 nCheckpoints, uint96 oldVotes, uint96 newVotes) internal {
    uint32 blockNumber = safe32(block.number, "_writeCheckpoint: blocknum exceeds 32 bits");

    if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
      checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
    } else {
      checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
      numCheckpoints[delegatee] = nCheckpoints + 1;
    }

    emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
  }

  function safe32(uint256 n, string memory errorMessage) internal pure returns (uint32) {
    require(n < 2 ** 32, errorMessage);
    return uint32(n);
  }

  function safe96(uint256 n, string memory errorMessage) internal pure returns (uint96) {
    require(n < 2 ** 96, errorMessage);
    return uint96(n);
  }

  function add96(uint96 a, uint96 b, string memory errorMessage) internal pure returns (uint96) {
    uint96 c = a + b;
    require(c >= a, errorMessage);
    return c;
  }

  function sub96(uint96 a, uint96 b, string memory errorMessage) internal pure returns (uint96) {
    require(b <= a, errorMessage);
    return a - b;
  }

  function getChainid() internal view returns (uint256) {
    uint256 chainId;
    //solhint-disable-next-line no-inline-assembly
    assembly {
      chainId := chainid()
    }
    return chainId;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "./IToken.sol";
import "./TokenStorage.sol";

contract InterestProtocolToken is TokenDelegatorStorage, TokenEvents, ITokenDelegator {
  constructor(address account_, address owner_, address implementation_, uint256 initialSupply_) {
    require(implementation_ != address(0), "TokenDelegator: invalid address");
    owner = owner_;
    delegateTo(implementation_, abi.encodeWithSignature("initialize(address,uint256)", account_, initialSupply_));

    implementation = implementation_;

    emit NewImplementation(address(0), implementation);
  }

  /**
   * @notice Called by the admin to update the implementation of the delegator
   * @param implementation_ The address of the new implementation for delegation
   */
  function _setImplementation(address implementation_) external override onlyOwner {
    require(implementation_ != address(0), "_setImplementation: invalid addr");

    address oldImplementation = implementation;
    implementation = implementation_;

    emit NewImplementation(oldImplementation, implementation);
  }

  /**
   * @notice Called by the admin to update the owner of the delegator
   * @param owner_ The address of the new owner
   */
  function _setOwner(address owner_) external override onlyOwner {
    owner = owner_;
  }

  /**
   * @notice Internal method to delegate execution to another contract
   * @dev It returns to the external caller whatever the implementation returns or forwards reverts
   * @param callee The contract to delegatecall
   * @param data The raw data to delegatecall
   */
  function delegateTo(address callee, bytes memory data) internal {
    //solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory returnData) = callee.delegatecall(data);
    //solhint-disable-next-line no-inline-assembly
    assembly {
      if eq(success, 0) {
        revert(add(returnData, 0x20), returndatasize())
      }
    }
  }

  /**
   * @dev Delegates execution to an implementation contract.
   * It returns to the external caller whatever the implementation returns
   * or forwards reverts.
   */
  // solhint-disable-next-line no-complex-fallback
  fallback() external payable override {
    // delegate all other functions to current implementation
    //solhint-disable-next-line avoid-low-level-calls
    (bool success, ) = implementation.delegatecall(msg.data);
    //solhint-disable-next-line no-inline-assembly
    assembly {
      let free_mem_ptr := mload(0x40)
      returndatacopy(free_mem_ptr, 0, returndatasize())
      switch success
      case 0 {
        revert(free_mem_ptr, returndatasize())
      }
      default {
        return(free_mem_ptr, returndatasize())
      }
    }
  }

  receive() external payable override {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "../../_external/Context.sol";

contract TokenDelegatorStorage is Context {
  /// @notice Active brains of Token
  address public implementation;

  /// @notice EIP-20 token name for this token
  string public name = "Interest Protocol";

  /// @notice EIP-20 token symbol for this token
  string public symbol = "IPT";

  /// @notice Total number of tokens in circulation
  uint256 public totalSupply;

  /// @notice EIP-20 token decimals for this token
  uint8 public constant decimals = 18;

  address public owner;
  /// @notice onlyOwner modifier checks if sender is owner
  modifier onlyOwner() {
    require(owner == _msgSender(), "onlyOwner: sender not owner");
    _;
  }
}

/**
 * @title Storage for Token Delegate
 * @notice For future upgrades, do not change TokenDelegateStorageV1. Create a new
 * contract which implements TokenDelegateStorageV1 and following the naming convention
 * TokenDelegateStorageVX.
 */
contract TokenDelegateStorageV1 is TokenDelegatorStorage {
  // Allowance amounts on behalf of others
  mapping(address => mapping(address => uint96)) internal allowances;

  // Official record of token balances for each account
  mapping(address => uint96) internal balances;

  /// @notice A record of each accounts delegate
  mapping(address => address) public delegates;

  /// @notice A checkpoint for marking number of votes from a given block
  struct Checkpoint {
    uint32 fromBlock;
    uint96 votes;
  }
  /// @notice A record of votes checkpoints for each account, by index
  mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

  /// @notice The number of checkpoints for each account
  mapping(address => uint32) public numCheckpoints;

  /// @notice A record of states for signing / validating signatures
  mapping(address => uint256) public nonces;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Tree proofs.
 *
 * The proofs can be generated using the JavaScript library
 * https://github.com/miguelmota/merkletreejs[merkletreejs].
 * Note: the hashing algorithm should be keccak256 and pair sorting should be enabled.
 *
 * See `test/utils/cryptography/MerkleProof.test.js` for some examples.
 *
 * WARNING: You should avoid using leaf values that are 64 bytes long prior to
 * hashing, or use a hash function other than keccak256 for hashing leaves.
 * This is because the concatenation of a sorted pair of internal nodes in
 * the merkle tree could be reinterpreted as a leaf value.
 */
library MerkleProof {
  /**
   * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
   * defined by `root`. For this, a `proof` must be provided, containing
   * sibling hashes on the branch from the leaf to the root of the tree. Each
   * pair of leaves and each pair of pre-images are assumed to be sorted.
   */
  function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
    return processProof(proof, leaf) == root;
  }

  /**
   * @dev Calldata version of {verify}
   *
   * _Available since v4.7._
   */
  function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
    return processProofCalldata(proof, leaf) == root;
  }

  /**
   * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
   * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
   * hash matches the root of the tree. When processing the proof, the pairs
   * of leafs & pre-images are assumed to be sorted.
   *
   * _Available since v4.4._
   */
  function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
    bytes32 computedHash = leaf;
    for (uint256 i = 0; i < proof.length; i++) {
      computedHash = _hashPair(computedHash, proof[i]);
    }
    return computedHash;
  }

  /**
   * @dev Calldata version of {processProof}
   *
   * _Available since v4.7._
   */
  function processProofCalldata(bytes32[] calldata proof, bytes32 leaf) internal pure returns (bytes32) {
    bytes32 computedHash = leaf;
    for (uint256 i = 0; i < proof.length; i++) {
      computedHash = _hashPair(computedHash, proof[i]);
    }
    return computedHash;
  }

  /**
   * @dev Returns true if the `leaves` can be proved to be a part of a Merkle tree defined by
   * `root`, according to `proof` and `proofFlags` as described in {processMultiProof}.
   *
   * _Available since v4.7._
   */
  function multiProofVerify(
    bytes32[] memory proof,
    bool[] memory proofFlags,
    bytes32 root,
    bytes32[] memory leaves
  ) internal pure returns (bool) {
    return processMultiProof(proof, proofFlags, leaves) == root;
  }

  /**
   * @dev Calldata version of {multiProofVerify}
   *
   * _Available since v4.7._
   */
  function multiProofVerifyCalldata(
    bytes32[] calldata proof,
    bool[] calldata proofFlags,
    bytes32 root,
    bytes32[] memory leaves
  ) internal pure returns (bool) {
    return processMultiProofCalldata(proof, proofFlags, leaves) == root;
  }

  /**
   * @dev Returns the root of a tree reconstructed from `leaves` and the sibling nodes in `proof`,
   * consuming from one or the other at each step according to the instructions given by
   * `proofFlags`.
   *
   * _Available since v4.7._
   */
  function processMultiProof(
    bytes32[] memory proof,
    bool[] memory proofFlags,
    bytes32[] memory leaves
  ) internal pure returns (bytes32 merkleRoot) {
    // This function rebuild the root hash by traversing the tree up from the leaves. The root is rebuilt by
    // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
    // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
    // the merkle tree.
    uint256 leavesLen = leaves.length;
    uint256 totalHashes = proofFlags.length;

    // Check proof validity.
    require(leavesLen + proof.length - 1 == totalHashes, "MerkleProof: invalid multiproof");

    // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
    // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
    bytes32[] memory hashes = new bytes32[](totalHashes);
    uint256 leafPos = 0;
    uint256 hashPos = 0;
    uint256 proofPos = 0;
    // At each step, we compute the next hash using two values:
    // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
    //   get the next hash.
    // - depending on the flag, either another value for the "main queue" (merging branches) or an element from the
    //   `proof` array.
    for (uint256 i = 0; i < totalHashes; i++) {
      bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
      bytes32 b = proofFlags[i] ? leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++] : proof[proofPos++];
      hashes[i] = _hashPair(a, b);
    }

    if (totalHashes > 0) {
      return hashes[totalHashes - 1];
    } else if (leavesLen > 0) {
      return leaves[0];
    } else {
      return proof[0];
    }
  }

  /**
   * @dev Calldata version of {processMultiProof}
   *
   * _Available since v4.7._
   */
  function processMultiProofCalldata(
    bytes32[] calldata proof,
    bool[] calldata proofFlags,
    bytes32[] memory leaves
  ) internal pure returns (bytes32 merkleRoot) {
    // This function rebuild the root hash by traversing the tree up from the leaves. The root is rebuilt by
    // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
    // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
    // the merkle tree.
    uint256 leavesLen = leaves.length;
    uint256 totalHashes = proofFlags.length;

    // Check proof validity.
    require(leavesLen + proof.length - 1 == totalHashes, "MerkleProof: invalid multiproof");

    // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
    // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
    bytes32[] memory hashes = new bytes32[](totalHashes);
    uint256 leafPos = 0;
    uint256 hashPos = 0;
    uint256 proofPos = 0;
    // At each step, we compute the next hash using two values:
    // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
    //   get the next hash.
    // - depending on the flag, either another value for the "main queue" (merging branches) or an element from the
    //   `proof` array.
    for (uint256 i = 0; i < totalHashes; i++) {
      bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
      bytes32 b = proofFlags[i] ? leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++] : proof[proofPos++];
      hashes[i] = _hashPair(a, b);
    }

    if (totalHashes > 0) {
      return hashes[totalHashes - 1];
    } else if (leavesLen > 0) {
      return leaves[0];
    } else {
      return proof[0];
    }
  }

  function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
    return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
  }

  function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
    /// @solidity memory-safe-assembly
    assembly {
      mstore(0x00, a)
      mstore(0x20, b)
      value := keccak256(0x00, 0x40)
    }
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "./MerkleProof.sol";
import "../../_external/Ownable.sol";
import "../../_external/IERC20.sol";

contract MerkleRedeem is Ownable {
  IERC20 public token;

  event Claimed(address _claimant, uint256 _balance);

  // Recorded weeks
  mapping(uint256 => bytes32) public weekMerkleRoots;
  mapping(uint256 => mapping(address => bool)) public claimed;

  constructor(address _token) {
    token = IERC20(_token);
  }

  function disburse(address _liquidityProvider, uint256 _balance) private {
    if (_balance > 0) {
      emit Claimed(_liquidityProvider, _balance);
      require(token.transfer(_liquidityProvider, _balance), "ERR_TRANSFER_FAILED");
    }
  }

  function claimWeek(
    address _liquidityProvider,
    uint256 _week,
    uint256 _claimedBalance,
    bytes32[] memory _merkleProof
  ) public {
    require(!claimed[_week][_liquidityProvider]);
    require(verifyClaim(_liquidityProvider, _week, _claimedBalance, _merkleProof), "Incorrect merkle proof");

    claimed[_week][_liquidityProvider] = true;
    disburse(_liquidityProvider, _claimedBalance);
  }

  struct Claim {
    uint256 week;
    uint256 balance;
    bytes32[] merkleProof;
  }

  function claimWeeks(address _liquidityProvider, Claim[] memory claims) public {
    uint256 totalBalance = 0;
    Claim memory claim;
    for (uint256 i = 0; i < claims.length; i++) {
      claim = claims[i];

      require(!claimed[claim.week][_liquidityProvider]);
      require(verifyClaim(_liquidityProvider, claim.week, claim.balance, claim.merkleProof), "Incorrect merkle proof");

      totalBalance += claim.balance;
      claimed[claim.week][_liquidityProvider] = true;
    }
    disburse(_liquidityProvider, totalBalance);
  }

  function claimStatus(address _liquidityProvider, uint256 _begin, uint256 _end) external view returns (bool[] memory) {
    uint256 size = 1 + _end - _begin;
    bool[] memory arr = new bool[](size);
    for (uint256 i = 0; i < size; i++) {
      arr[i] = claimed[_begin + i][_liquidityProvider];
    }
    return arr;
  }

  function merkleRoots(uint256 _begin, uint256 _end) external view returns (bytes32[] memory) {
    uint256 size = 1 + _end - _begin;
    bytes32[] memory arr = new bytes32[](size);
    for (uint256 i = 0; i < size; i++) {
      arr[i] = weekMerkleRoots[_begin + i];
    }
    return arr;
  }

  function verifyClaim(
    address _liquidityProvider,
    uint256 _week,
    uint256 _claimedBalance,
    bytes32[] memory _merkleProof
  ) public view returns (bool valid) {
    bytes32 leaf = keccak256(abi.encodePacked(_liquidityProvider, _claimedBalance));
    return MerkleProof.verify(_merkleProof, weekMerkleRoots[_week], leaf);
  }

  function seedAllocations(uint256 _week, bytes32 _merkleRoot, uint256 _totalAllocation) external onlyOwner {
    require(weekMerkleRoots[_week] == bytes32(0), "cannot rewrite merkle root");
    weekMerkleRoots[_week] = _merkleRoot;

    require(token.transferFrom(msg.sender, address(this), _totalAllocation), "ERR_TRANSFER_FAILED");
  }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/// @title interfact to interact with ERC20 tokens
/// @author elee

interface IERC20 {
  function mint(address account, uint256 amount) external;

  function totalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

  function allowance(address owner, address spender) external view returns (uint256);

  function approve(address spender, uint256 amount) external returns (bool);

  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

/// @title slowroll is the third gen wave contract
// solhint-disable comprehensive-interface
contract SlowRoll {
  /// user defined variables
  uint256 public _maxQuantity; // max quantity available in wave
  uint64 public _startPrice; // start price
  uint64 public _maxPrice; // max price
  uint64 public _waveDuration; // duration, in seconds, of the next wave
  /// end user defined variables

  /// contract controlled values
  uint64 public _endTime; // start time of the wave + waveDuration
  uint256 public _soldQuantity; // amount currently sold in wave
  /// end contract controlled values

  // the token used to claim points, USDC
  IERC20 public _pointsToken = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // usdc
  // the token to be rewarded, IPT
  IERC20 public immutable _rewardToken = IERC20(0xd909C5862Cdb164aDB949D92622082f0092eFC3d); // IPT
  // light ownership
  address public _owner;

  modifier onlyOwner() {
    require(msg.sender == _owner);
    _;
  }

  constructor() {
    _owner = msg.sender; // creator of contract
    _maxQuantity = 1_000_000 * 1e18; // 1_00_000 IPT, in wei - max IPT sold per day
    _startPrice = 250_000; // 25 cents
    _maxPrice = 500_000; // 50 cents
    _waveDuration = 60 * 60 * 22; // 22 hours in seconds
  }

  function setMaxQuantity(uint256 maxQuantity_) external onlyOwner {
    _maxQuantity = maxQuantity_;
  }

  function setStartPrice(uint64 startPrice_) external onlyOwner {
    _startPrice = startPrice_;
    require(_startPrice < _maxPrice, "start not < max");
  }

  function setMaxPrice(uint64 maxPrice_) external onlyOwner {
    _maxPrice = maxPrice_;
    require(_startPrice < _maxPrice, "start not < max");
  }

  function setWaveDuration(uint64 waveDuration_) external onlyOwner {
    _waveDuration = waveDuration_;
  }

  function forceNewDay() external onlyOwner {
    new_day();
  }

  ///@notice sends reward tokens to the receiver
  function withdraw(uint256 amount) external onlyOwner {
    giveTo(_owner, amount);
  }

  ///@notice a view only convenience getter
  function getCurrentPrice() external view returns (uint256) {
    return current_price();
  }

  /// @notice submit usdc to be converted
  /// @param amount amount of usdc
  function getPoints(uint256 amount) public {
    try_new_day();
    uint256 currentPrice = current_price();
    uint256 rewardAmount = reward_amount(amount, currentPrice);
    _soldQuantity = _soldQuantity + rewardAmount;
    require(canClaim(), "Cap reached");
    takeFrom(msg.sender, amount);
    giveTo(msg.sender, rewardAmount);
  }

  /// ALL FUNCTIONS BELOW SHOULD BE INTERNAL

  function canClaim() internal view returns (bool) {
    return _maxQuantity >= _soldQuantity;
  }

  function try_new_day() internal {
    if (uint64(block.timestamp) > _endTime) {
      new_day();
    }
  }

  function new_day() internal {
    _soldQuantity = 0;
    _endTime = uint64(_waveDuration + block.timestamp);
  }

  // get the current price
  function current_price() internal view returns (uint256) {
    // this is sold %, in 1e18 terms, multiplied by the difference between the start and max current_price
    // this will give us the amount to increase the price, in 1e18 terms
    uint256 scalar = ((_soldQuantity * 1e18) / _maxQuantity) * (_maxPrice - _startPrice);
    // the price therefore is that number / 1e18 + the start price
    return (scalar / 1e18) + _startPrice;
  }

  /// @notice note that usdc being 1e6 decimals is hard coded here, since our price is in 6 decimals as well.
  /// @param amount the amount of USDC
  /// @param price is the amount of USDC, in usdc base units, to buy 1e18 of IPT
  /// @return the amount of IPT that the usdc amount entitles to.
  function reward_amount(uint256 amount, uint256 price) internal pure returns (uint256) {
    return (1e18 * amount) / price;
  }

  /// @notice function which transfer the point token
  function takeFrom(address target, uint256 amount) internal {
    bool check = _pointsToken.transferFrom(target, _owner, amount);
    require(check, "erc20 transfer failed");
  }

  /// @notice function which sends the reward token
  function giveTo(address target, uint256 amount) internal {
    if (_rewardToken.balanceOf(address(this)) < amount) {
      amount = _rewardToken.balanceOf(address(this));
    }
    require(amount > 0, "cant redeem zero");
    bool check = _rewardToken.transfer(target, amount);
    require(check, "erc20 transfer failed");
  }
}
// solhint-enable comprehensive-interface

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./_external/IERC20Metadata.sol";

/// @title USDI Events
/// @notice interface which contains any events which the USDI contract emits
interface USDIEvents {
  event Deposit(address indexed _from, uint256 _value);
  event Withdraw(address indexed _from, uint256 _value);
  event Mint(address to, uint256 _value);
  event Burn(address from, uint256 _value);
  event Donation(address indexed _from, uint256 _value, uint256 _totalSupply);
}

/// @title USDI Interface
/// @notice extends USDIEvents and IERC20Metadata
interface IUSDI is IERC20Metadata, USDIEvents {
  /// @notice initializer specifies the reserveAddress
  function initialize(address reserveAddress) external;

  // getters
  function reserveRatio() external view returns (uint192);

  function reserveAddress() external view returns (address);

  // owner
  function owner() external view returns (address);

  // business
  function deposit(uint256 usdc_amount) external;

  function depositTo(uint256 usdc_amount, address target) external;

  function withdraw(uint256 usdc_amount) external;

  function withdrawTo(uint256 usdc_amount, address target) external;

  function withdrawAll() external;

  function withdrawAllTo(address target) external;

  function donate(uint256 usdc_amount) external;

  function donateReserve() external;

  // admin functions

  function setPauser(address pauser_) external;

  function pauser() external view returns (address);

  function pause() external;

  function unpause() external;

  function mint(uint256 usdc_amount) external;

  function burn(uint256 usdc_amount) external;

  function setVaultController(address vault_master_address) external;

  function getVaultController() external view returns (address);

  // functions for the vault controller to call
  function vaultControllerBurn(address target, uint256 amount) external;

  function vaultControllerMint(address target, uint256 amount) external;

  function vaultControllerTransfer(address target, uint256 usdc_amount) external;

  function vaultControllerDonate(uint256 amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
import {IERC20} from "./_external/IERC20.sol";

interface IWUSDI is IERC20 {
  /** view functions */
  function underlying() external view returns (address);

  function totalUnderlying() external view returns (uint256);

  function balanceOfUnderlying(address owner) external view returns (uint256);

  function underlyingToWrapper(uint256 usdi_amount) external view returns (uint256);

  function wrapperToUnderlying(uint256 wUSDI_amount) external view returns (uint256);

  /** write functions */
  function mint(uint256 wUSDI_amount) external returns (uint256);

  function mintFor(address to, uint256 wUSDI_amount) external returns (uint256);

  function burn(uint256 wUSDI_amount) external returns (uint256);

  function burnTo(address to, uint256 wUSDI_amount) external returns (uint256);

  function burnAll() external returns (uint256);

  function burnAllTo(address to) external returns (uint256);

  function deposit(uint256 usdi_amount) external returns (uint256);

  function depositFor(address to, uint256 usdi_amount) external returns (uint256);

  function withdraw(uint256 usdi_amount) external returns (uint256);

  function withdrawTo(address to, uint256 usdi_amount) external returns (uint256);

  function withdrawAll() external returns (uint256);

  function withdrawAllTo(address to) external returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IVaultController.sol";

import "../vault/VaultNft.sol";
//import "../vault/VaultBPT.sol";

import "../../_external/IERC20Metadata.sol";
import "../../_external/openzeppelin/ERC20Upgradeable.sol";
import "../../_external/openzeppelin/OwnableUpgradeable.sol";
import "../../_external/openzeppelin/Initializable.sol";

/// @title CappedGovToken
/// @notice handles all minting/burning of underlying
/// @dev extends ierc20 upgradable
contract NftVaultController is Initializable, OwnableUpgradeable {
  //this is unused but needs to stay or the storage will be off by 8 bits for future upgrades
  uint8 private _underlying_decimals;
  IVaultController public _vaultController;

  mapping(address => uint96) public _vaultAddress_vaultId; //standard vault addr
  mapping(uint96 => address) public _vaultId_nftVaultAddress;
  mapping(address => uint96) public _nftVaultAddress_vaultId;

  mapping(address => address) public _underlying_CollateralToken;
  mapping(address => address) public _CollateralToken_underlying;

  event NewNftVault(address nft_vault_address, uint256 vaultId);

  /// @notice initializer for contract
  /// @param vaultController_ the address of the vault controller
  function initialize(address vaultController_) public initializer {
    __Ownable_init();
    _vaultController = IVaultController(vaultController_);
  }
  /// @notice register an underlying nft token pair
  /// note that registring a token as a nft token allows it to transfer the balance of the corresponding token at will
  /// @param underlying_address address of underlying
  /// @param capped_token address of nft wrapper token
  function registerUnderlying(address underlying_address, address capped_token) external onlyOwner {
    _underlying_CollateralToken[underlying_address] = capped_token;
    _CollateralToken_underlying[capped_token] = underlying_address;
  }

  /// @notice retrieve underlying asset for the cap token
  /// @param tokenId of underlying asset to retrieve
  /// @param nft_vault holding the underlying
  /// @param target to receive the underlying
  function retrieveUnderlying(uint256 tokenId, address nft_vault, address target) public {
    require(nft_vault != address(0x0), "invalid vault");
    address underlying_address = _CollateralToken_underlying[_msgSender()];
    require(underlying_address != address(0x0), "only capped token");
    VaultNft nftVault = VaultNft(nft_vault);
    nftVault.nftVaultControllerTransfer(underlying_address, target, tokenId);
  }

  /// @notice create a new vault
  /// @param id of an existing vault
  /// @return address of the new vault
  function mintVault(uint96 id) public returns (address) {
    if (_vaultId_nftVaultAddress[id] == address(0)) {
      address vault_address = _vaultController.vaultAddress(id);
      if (vault_address != address(0)) {
        // mint the vault itself, deploying the contract
        address nft_vault_address = address(
          new VaultNft(id, vault_address, address(_vaultController), address(this))
        );
        // add the vault to our system
        _vaultId_nftVaultAddress[id] = nft_vault_address;
        _vaultAddress_vaultId[vault_address] = id;
        _nftVaultAddress_vaultId[nft_vault_address] = id;
        // emit the event
        emit NewNftVault(nft_vault_address, id);
      }
    }
    return _vaultId_nftVaultAddress[id];
  }

  function NftVaultId(address nft_vault_address) public view returns (uint96) {
    return _nftVaultAddress_vaultId[nft_vault_address];
  }

  function vaultId(address vault_address) public view returns (uint96) {
    return _vaultAddress_vaultId[vault_address];
  }

  function NftVaultAddress(uint96 vault_id) public view returns (address) {
    return _vaultId_nftVaultAddress[vault_id];
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "../../IUSDI.sol";
import "../IVault.sol";
import "../IVaultController.sol";

import "../vault/Vault.sol";

import "../../oracle/OracleMaster.sol";
import "../../curve/CurveMaster.sol";

import "../../_external/IERC20.sol";
import "../../_external/compound/ExponentialNoError.sol";
import "../../_external/openzeppelin/OwnableUpgradeable.sol";
import "../../_external/openzeppelin/Initializable.sol";
import "../../_external/openzeppelin/PausableUpgradeable.sol";

/// @title Controller of all vaults in the USDi borrow/lend system
/// @notice VaultController contains all business logic for borrowing and lending through the protocol.
/// It is also in charge of accruing interest.
contract VaultController is
  Initializable,
  PausableUpgradeable,
  IVaultController,
  ExponentialNoError,
  OwnableUpgradeable
{
  // mapping of vault id to vault address
  mapping(uint96 => address) public _vaultId_vaultAddress;

  //mapping of wallet address to vault IDs []
  mapping(address => uint96[]) public _wallet_vaultIDs;

  // mapping of token address to token id
  mapping(address => uint256) public _tokenAddress_tokenId;

  //mapping of tokenId to the LTV*1
  mapping(uint256 => uint256) public _tokenId_tokenLTV;

  //mapping of tokenId to its corresponding oracleAddress (which are addresses)
  mapping(uint256 => address) public _tokenId_oracleAddress;

  //mapping of token address to its corresponding liquidation incentive
  mapping(address => uint256) public _tokenAddress_liquidationIncentive;
  address[] public _enabledTokens;

  OracleMaster public _oracleMaster;
  CurveMaster public _curveMaster;

  IUSDI public _usdi;
  uint96 public _vaultsMinted;

  uint256 private _tokensRegistered;
  uint192 private _totalBaseLiability;
  uint192 private _protocolFee;

  struct Interest {
    uint64 lastTime;
    uint192 factor;
  }
  Interest public _interest;

  /// @notice any function with this modifier will call the pay_interest() function before
  modifier paysInterest() {
    pay_interest();
    _;
  }

  ///@notice any function with this modifier can be paused or unpaused by USDI._pauser() in the case of an emergency
  modifier onlyPauser() {
    require(_msgSender() == _usdi.pauser(), "only pauser");
    _;
  }

  /// @notice no initialization arguments.
  function initialize() external override initializer {
    __Ownable_init();
    __Pausable_init();
    _interest = Interest(uint64(block.timestamp), 1e18);
    _protocolFee = 1e14;

    _vaultsMinted = 0;
    _tokensRegistered = 0;
    _totalBaseLiability = 0;
  }

  /// @notice get current interest factor
  /// @return interest factor
  function interestFactor() external view override returns (uint192) {
    return _interest.factor;
  }

  /// @notice get last interest time
  /// @return interest time
  function lastInterestTime() external view override returns (uint64) {
    return _interest.lastTime;
  }

  /// @notice get current protocol fee
  /// @return protocol fee
  function protocolFee() external view override returns (uint192) {
    return _protocolFee;
  }

  /// @notice get vault address of id
  /// @return the address of vault
  function vaultAddress(uint96 id) external view override returns (address) {
    return _vaultId_vaultAddress[id];
  }

  ///@notice get vaultIDs of a particular wallet
  ///@return array of vault IDs owned by the wallet, from 0 to many
  function vaultIDs(address wallet) external view override returns (uint96[] memory) {
    return _wallet_vaultIDs[wallet];
  }

  /// @notice get total base liability of all vaults
  /// @return total base liability
  function totalBaseLiability() external view override returns (uint192) {
    return _totalBaseLiability;
  }

  /// @notice get the amount of vaults in the system
  /// @return the amount of vaults in the system
  function vaultsMinted() external view override returns (uint96) {
    return _vaultsMinted;
  }

  /// @notice get the amount of tokens regsitered in the system
  /// @return the amount of tokens registered in the system
  function tokensRegistered() external view override returns (uint256) {
    return _tokensRegistered;
  }

  /// @notice create a new vault
  /// @return address of the new vault
  function mintVault() public override whenNotPaused returns (address) {
    // increment  minted vaults
    _vaultsMinted = _vaultsMinted + 1;
    // mint the vault itself, deploying the contract
    address vault_address = address(new Vault(_vaultsMinted, _msgSender(), address(this)));
    // add the vault to our system
    _vaultId_vaultAddress[_vaultsMinted] = vault_address;

    //push new vault ID onto mapping
    _wallet_vaultIDs[_msgSender()].push(_vaultsMinted);

    // emit the event
    emit NewVault(vault_address, _vaultsMinted, _msgSender());
    // return the vault address, allowing the caller to automatically find their vault
    return vault_address;
  }

  /// @notice pause the contract
  function pause() external override onlyPauser {
    _pause();
  }

  /// @notice unpause the contract
  function unpause() external override onlyPauser {
    _unpause();
  }

  /// @notice register the USDi contract
  /// @param usdi_address address to register as USDi
  function registerUSDi(address usdi_address) external override onlyOwner {
    _usdi = IUSDI(usdi_address);
  }

  ///  @notice get oraclemaster address
  /// @return the address
  function getOracleMaster() external view override returns (address) {
    return address(_oracleMaster);
  }

  /// @notice register the OracleMaster contract
  /// @param master_oracle_address address to register as OracleMaster
  function registerOracleMaster(address master_oracle_address) external override onlyOwner {
    _oracleMaster = OracleMaster(master_oracle_address);
    emit RegisterOracleMaster(master_oracle_address);
  }

  ///  @notice get curvemaster address
  /// @return the address
  function getCurveMaster() external view override returns (address) {
    return address(_curveMaster);
  }

  /// @notice register the CurveMaster address
  /// @param master_curve_address address to register as CurveMaster
  function registerCurveMaster(address master_curve_address) external override onlyOwner {
    _curveMaster = CurveMaster(master_curve_address);
    emit RegisterCurveMaster(master_curve_address);
  }

  /// @notice update the protocol fee
  /// @param new_protocol_fee protocol fee in terms of 1e18=100%
  function changeProtocolFee(uint192 new_protocol_fee) external override onlyOwner {
    require(new_protocol_fee < 1e18, "fee is too large");
    _protocolFee = new_protocol_fee;
    emit NewProtocolFee(new_protocol_fee);
  }

  /// @notice register a new token to be used as collateral
  /// @param token_address token to register
  /// @param LTV LTV of the token, 1e18=100%
  /// @param oracle_address address of the token which should be used when querying oracles
  /// @param liquidationIncentive liquidation penalty for the token, 1e18=100%
  function registerErc20(
    address token_address,
    uint256 LTV,
    address oracle_address,
    uint256 liquidationIncentive
  ) external override onlyOwner {
    // the oracle must be registered & the token must be unregistered
    require(_oracleMaster._relays(oracle_address) != address(0x0), "oracle does not exist");
    require(_tokenAddress_tokenId[token_address] == 0, "token already registered");
    //LTV must be compatible with liquidation incentive
    require(LTV < (expScale - liquidationIncentive), "incompatible LTV");
    // increment the amount of registered token
    _tokensRegistered = _tokensRegistered + 1;
    // set & give the token an id
    _tokenAddress_tokenId[token_address] = _tokensRegistered;
    // set the token's oracle
    _tokenId_oracleAddress[_tokensRegistered] = oracle_address;
    // set the token's ltv
    _tokenId_tokenLTV[_tokensRegistered] = LTV;
    // set the token's liquidation incentive
    _tokenAddress_liquidationIncentive[token_address] = liquidationIncentive;
    // finally, add the token to the array of enabled tokens
    _enabledTokens.push(token_address);
    emit RegisteredErc20(token_address, LTV, oracle_address, liquidationIncentive);
  }

  /// @notice update an existing collateral with new collateral parameters
  /// @param token_address the token to modify
  /// @param LTV new loan-to-value of the token, 1e18=100%
  /// @param oracle_address new oracle to attach to the token
  /// @param liquidationIncentive new liquidation penalty for the token, 1e18=100%
  function updateRegisteredErc20(
    address token_address,
    uint256 LTV,
    address oracle_address,
    uint256 liquidationIncentive
  ) external override onlyOwner {
    // the oracle and token must both exist and be registerd
    require(_oracleMaster._relays(oracle_address) != address(0x0), "oracle does not exist");
    require(_tokenAddress_tokenId[token_address] != 0, "token is not registered");
    // we know the token has been registered, get the Id
    uint256 tokenId = _tokenAddress_tokenId[token_address];
    //LTV must be compatible with liquidation incentive
    require(LTV < (expScale - liquidationIncentive), "incompatible LTV");
    // set the oracle of the token
    _tokenId_oracleAddress[tokenId] = oracle_address;
    // set the ltv of the token
    _tokenId_tokenLTV[tokenId] = LTV;
    // set the liquidation incentive of the token
    _tokenAddress_liquidationIncentive[token_address] = liquidationIncentive;

    emit UpdateRegisteredErc20(token_address, LTV, oracle_address, liquidationIncentive);
  }

  /// @notice check an vault for over-collateralization. returns false if amount borrowed is greater than borrowing power.
  /// @param id the vault to check
  /// @return true = vault over-collateralized; false = vault under-collaterlized
  function checkVault(uint96 id) public view override returns (bool) {
    // grab the vault by id if part of our system. revert if not
    IVault vault = getVault(id);
    // calculate the total value of the vault's liquidity
    uint256 total_liquidity_value = get_vault_borrowing_power(vault);
    // calculate the total liability of the vault
    uint256 usdi_liability = truncate((vault.baseLiability() * _interest.factor));
    // if the LTV >= liability, the vault is solvent
    return (total_liquidity_value >= usdi_liability);
  }

  /// @notice borrow USDi from a vault. only vault minter may borrow from their vault
  /// @param id vault to borrow against
  /// @param amount amount of USDi to borrow
  function borrowUsdi(uint96 id, uint192 amount) external override {
    _borrowUSDi(id, amount, _msgSender());
  }

  /// @notice borrow USDi from a vault and send the USDi to a specific address
  /// @notice Only vault minter may borrow from their vault
  /// @param id vault to borrow against
  /// @param amount amount of USDi to borrow
  /// @param target address to receive borrowed USDi
  function borrowUSDIto(uint96 id, uint192 amount, address target) external override {
    _borrowUSDi(id, amount, target);
  }

  /// @notice business logic to perform the USDi loan
  /// @param id vault to borrow against
  /// @param amount amount of USDi to borrow
  /// @param target address to receive borrowed USDi
  /// @dev pays interest
  function _borrowUSDi(uint96 id, uint192 amount, address target) internal paysInterest whenNotPaused {
    // grab the vault by id if part of our system. revert if not
    IVault vault = getVault(id);
    // only the minter of the vault may borrow from their vault
    require(_msgSender() == vault.minter(), "sender not minter");
    // the base amount is the amount of USDi they wish to borrow divided by the interest factor
    uint192 base_amount = safeu192(uint256(amount * expScale) / uint256(_interest.factor));
    // base_liability should contain the vault's new liability, in terms of base units
    // true indicates that we are adding to the liability
    uint256 base_liability = vault.modifyLiability(true, base_amount);
    // increase the total base liability by the base_amount
    // the same amount we added to the vault's liability
    _totalBaseLiability = _totalBaseLiability + safeu192(base_amount);
    // now take the vault's total base liability and multiply it by the interest factor
    uint256 usdi_liability = truncate(uint256(_interest.factor) * base_liability);
    // now get the LTV of the vault, aka their borrowing power, in usdi
    uint256 total_liquidity_value = get_vault_borrowing_power(vault);
    // the LTV must be above the newly calculated usdi_liability, else revert
    require(total_liquidity_value >= usdi_liability, "vault insolvent");
    // now send usdi to the target, equal to the amount they are owed
    _usdi.vaultControllerMint(target, amount);
    // emit the event
    emit BorrowUSDi(id, address(vault), amount);
  }

  /// @notice borrow USDC directly from reserve
  /// @notice liability is still in USDi, and USDi must be repaid
  /// @param id vault to borrow against
  /// @param usdc_amount amount of USDC to borrow
  /// @param target address to receive borrowed USDC
  function borrowUSDCto(uint96 id, uint192 usdc_amount, address target) external override paysInterest whenNotPaused {
    uint256 amount = usdc_amount * 1e12;

    // grab the vault by id if part of our system. revert if not
    IVault vault = getVault(id);
    // only the minter of the vault may borrow from their vault
    require(_msgSender() == vault.minter(), "sender not minter");
    // the base amount is the amount of USDi they wish to borrow divided by the interest factor
    uint192 base_amount = safeu192(uint256(amount * expScale) / uint256(_interest.factor));
    // base_liability should contain the vault's new liability, in terms of base units
    // true indicates that we are adding to the liability
    uint256 base_liability = vault.modifyLiability(true, base_amount);
    // increase the total base liability by the base_amount
    // the same amount we added to the vault's liability
    _totalBaseLiability = _totalBaseLiability + safeu192(base_amount);
    // now take the vault's total base liability and multiply it by the interest factor
    uint256 usdi_liability = truncate(uint256(_interest.factor) * base_liability);
    // now get the LTV of the vault, aka their borrowing power, in usdi
    uint256 total_liquidity_value = get_vault_borrowing_power(vault);
    // the LTV must be above the newly calculated usdi_liability, else revert
    require(total_liquidity_value >= usdi_liability, "vault insolvent");
    // emit the event
    emit BorrowUSDi(id, address(vault), amount);
    //send USDC to the target from reserve instead of mint
    _usdi.vaultControllerTransfer(target, usdc_amount);
  }

  /// @notice repay a vault's USDi loan. anyone may repay
  /// @param id vault to repay
  /// @param amount amount of USDi to repay
  /// @dev pays interest
  function repayUSDi(uint96 id, uint192 amount) external override paysInterest whenNotPaused {
    // grab the vault by id if part of our system. revert if not
    IVault vault = getVault(id);
    // the base amount is the amount of USDi entered divided by the interest factor
    uint192 base_amount = safeu192((amount * expScale) / _interest.factor);
    // decrease the total base liability by the calculated base amount
    _totalBaseLiability = _totalBaseLiability - base_amount;
    // ensure that base_amount is lower than the vault's base liability.
    // this may not be needed, since modifyLiability *should* revert if is not true
    require(base_amount <= vault.baseLiability(), "repay > borrow amount"); //repay all here if true?
    // decrease the vault's liability by the calculated base amount
    vault.modifyLiability(false, base_amount);
    // burn the amount of USDi submitted from the sender
    _usdi.vaultControllerBurn(_msgSender(), amount);
    // emit the event
    emit RepayUSDi(id, address(vault), amount);
  }

  /// @notice repay all of a vault's USDi. anyone may repay a vault's liabilities
  /// @param id the vault to repay
  /// @dev pays interest
  function repayAllUSDi(uint96 id) external override paysInterest whenNotPaused {
    // grab the vault by id if part of our system. revert if not
    IVault vault = getVault(id);
    //store the vault baseLiability in memory
    uint256 baseLiability = vault.baseLiability();
    // get the total USDi liability, equal to the interest factor * vault's base liabilty
    //uint256 usdi_liability = truncate(safeu192(_interest.factor * vault.baseLiability()));
    uint256 usdi_liability = uint256(safeu192(truncate(_interest.factor * baseLiability)));
    // decrease the total base liability by the vault's base liability
    _totalBaseLiability = _totalBaseLiability - safeu192(baseLiability);
    // decrease the vault's liability by the vault's base liability
    vault.modifyLiability(false, baseLiability);
    // burn the amount of USDi paid back from the vault
    _usdi.vaultControllerBurn(_msgSender(), usdi_liability);

    emit RepayUSDi(id, address(vault), usdi_liability);
  }

  /// @notice liquidate an underwater vault
  /// @notice vaults may be liquidated up to the point where they are exactly solvent
  /// @param id the vault to liquidate
  /// @param asset_address the token the liquidator wishes to liquidate
  /// @param tokens_to_liquidate  number of tokens to liquidate
  /// @dev pays interest before liquidation
  function liquidateVault(
    uint96 id,
    address asset_address,
    uint256 tokens_to_liquidate
  ) external override paysInterest whenNotPaused returns (uint256) {
    //cannot liquidate 0
    require(tokens_to_liquidate > 0, "must liquidate>0");
    //check for registered asset - audit L3
    require(_tokenAddress_tokenId[asset_address] != 0, "Token not registered");

    // calculate the amount to liquidate and the 'bad fill price' using liquidationMath
    // see _liquidationMath for more detailed explaination of the math
    (uint256 tokenAmount, uint256 badFillPrice) = _liquidationMath(id, asset_address, tokens_to_liquidate);
    // set tokens_to_liquidate to this calculated amount if the function does not fail
    if (tokenAmount != 0) {
      tokens_to_liquidate = tokenAmount;
    }
    // the USDi to repurchase is equal to the bad fill price multiplied by the amount of tokens to liquidate
    uint256 usdi_to_repurchase = truncate(badFillPrice * tokens_to_liquidate);
    // get the vault that the liquidator wishes to liquidate
    IVault vault = getVault(id);

    //decrease the vault's liability
    vault.modifyLiability(false, (usdi_to_repurchase * 1e18) / _interest.factor);

    // decrease the total base liability
    _totalBaseLiability = _totalBaseLiability - safeu192((usdi_to_repurchase * 1e18) / _interest.factor);

    //decrease liquidator's USDi balance
    _usdi.vaultControllerBurn(_msgSender(), usdi_to_repurchase);

    // finally, deliver tokens to liquidator
    vault.controllerTransfer(asset_address, _msgSender(), tokens_to_liquidate);

    // this mainly prevents reentrancy
    require(get_vault_borrowing_power(vault) <= _vaultLiability(id), "overliquidation");

    // emit the event
    emit Liquidate(id, asset_address, usdi_to_repurchase, tokens_to_liquidate);
    // return the amount of tokens liquidated
    return tokens_to_liquidate;
  }

  /// @notice calculate amount of tokens to liquidate for a vault
  /// @param id the vault to get info for
  /// @param asset_address the token to calculate how many tokens to liquidate
  /// @return - amount of tokens liquidatable
  /// @notice the amount of tokens owed is a moving target and changes with each block as pay_interest is called
  /// @notice this function can serve to give an indication of how many tokens can be liquidated
  /// @dev all this function does is call _liquidationMath with 2**256-1 as the amount
  function tokensToLiquidate(uint96 id, address asset_address) external view override returns (uint256) {
    (
      uint256 tokenAmount, // bad fill price

    ) = _liquidationMath(id, asset_address, 2 ** 256 - 1);
    return tokenAmount;
  }

  /// @notice internal function with business logic for liquidation math
  /// @param id the vault to get info for
  /// @param asset_address the token to calculate how many tokens to liquidate
  /// @param tokens_to_liquidate the max amount of tokens one wishes to liquidate
  /// @return the amount of tokens underwater this vault is
  /// @return the bad fill price for the token
  function _liquidationMath(
    uint96 id,
    address asset_address,
    uint256 tokens_to_liquidate
  ) internal view returns (uint256, uint256) {
    //require that the vault is not solvent
    require(!checkVault(id), "Vault is solvent");

    IVault vault = getVault(id);

    //get price of asset scaled to decimal 18
    uint256 price = _oracleMaster.getLivePrice(asset_address);

    // get price discounted by liquidation penalty
    // price * (100% - liquidationIncentive)
    uint256 badFillPrice = truncate(price * (1e18 - _tokenAddress_liquidationIncentive[asset_address]));

    // the ltv discount is the amount of collateral value that one token provides
    uint256 ltvDiscount = truncate(price * _tokenId_tokenLTV[_tokenAddress_tokenId[asset_address]]);
    // this number is the denominator when calculating the max_tokens_to_liquidate
    // it is simply the badFillPrice - ltvDiscount
    uint256 denominator = badFillPrice - ltvDiscount;

    // the maximum amount of tokens to liquidate is the amount that will bring the vault to solvency
    // divided by the denominator
    uint256 max_tokens_to_liquidate = (_amountToSolvency(id) * 1e18) / denominator;

    //Cannot liquidate more than is necessary to make vault over-collateralized
    if (tokens_to_liquidate > max_tokens_to_liquidate) {
      tokens_to_liquidate = max_tokens_to_liquidate;
    }

    //Cannot liquidate more collateral than there is in the vault
    if (tokens_to_liquidate > vault.tokenBalance(asset_address)) {
      tokens_to_liquidate = vault.tokenBalance(asset_address);
    }

    return (tokens_to_liquidate, badFillPrice);
  }

  /// @notice internal helper function to wrap getting of vaults
  /// @notice it will revert if the vault does not exist
  /// @param id id of vault
  /// @return vault IVault contract of
  function getVault(uint96 id) internal view returns (IVault vault) {
    address vault_address = _vaultId_vaultAddress[id];
    require(vault_address != address(0x0), "vault does not exist");
    vault = IVault(vault_address);
  }

  ///@notice amount of USDi needed to reach even solvency
  ///@notice this amount is a moving target and changes with each block as pay_interest is called
  /// @param id id of vault
  function amountToSolvency(uint96 id) public view override returns (uint256) {
    require(!checkVault(id), "Vault is solvent");
    return _amountToSolvency(id);
  }

  ///@notice bussiness logic for amountToSolvency
  function _amountToSolvency(uint96 id) internal view returns (uint256) {
    return _vaultLiability(id) - get_vault_borrowing_power(getVault(id));
  }

  /// @notice get vault liability of vault
  /// @param id id of vault
  /// @return amount of USDi the vault owes
  /// @dev implementation _vaultLiability
  function vaultLiability(uint96 id) external view override returns (uint192) {
    return _vaultLiability(id);
  }

  ///@notice bussiness logic for vaultLiability
  function _vaultLiability(uint96 id) internal view returns (uint192) {
    address vault_address = _vaultId_vaultAddress[id];
    require(vault_address != address(0x0), "vault does not exist");
    IVault vault = IVault(vault_address);
    return safeu192(truncate(vault.baseLiability() * _interest.factor));
  }

  /// @notice get vault borrowing power for vault
  /// @param id id of vault
  /// @return amount of USDi the vault can borrow
  /// @dev implementation in get_vault_borrowing_power
  function vaultBorrowingPower(uint96 id) external view override returns (uint192) {
    return get_vault_borrowing_power(getVault(id));
  }

  /// @notice the actual implementation of get_vaultA_borrowing_power
  //solhint-disable-next-line code-complexity
  function get_vault_borrowing_power(IVault vault) private view returns (uint192) {
    uint192 total_liquidity_value = 0;
    // loop over each registed token, adding the indivuduals LTV to the total LTV of the vault
    for (uint192 i = 1; i <= _tokensRegistered; ++i) {
      // if the ltv is 0, continue
      if (_tokenId_tokenLTV[i] == 0) {
        continue;
      }
      // get the address of the token through the array of enabled tokens
      // note that index 0 of _enabledTokens corresponds to a vaultId of 1, so we must subtract 1 from i to get the correct index
      address token_address = _enabledTokens[i - 1];
      // the balance is the vault's token balance of the current collateral token in the loop
      uint256 balance = vault.tokenBalance(token_address);
      if (balance == 0) {
        continue;
      }
      // the raw price is simply the oraclemaster price of the token
      uint192 raw_price = safeu192(_oracleMaster.getLivePrice(token_address));
      if (raw_price == 0) {
        continue;
      }
      // the token value is equal to the price * balance * tokenLTV
      uint192 token_value = safeu192(truncate(truncate(raw_price * balance * _tokenId_tokenLTV[i])));
      // increase the LTV of the vault by the token value
      total_liquidity_value = total_liquidity_value + token_value;
    }
    return total_liquidity_value;
  }

  /// @notice calls the pay interest function
  /// @dev implementation in pay_interest
  function calculateInterest() external override returns (uint256) {
    return pay_interest();
  }

  /// @notice accrue interest to borrowers and distribute it to USDi holders.
  /// this function is called before any function that changes the reserve ratio
  function pay_interest() private returns (uint256) {
    // calculate the time difference between the current block and the last time the block was called
    uint64 timeDifference = uint64(block.timestamp) - _interest.lastTime;
    // if the time difference is 0, there is no interest. this saves gas in the case that
    // if multiple users call interest paying functions in the same block
    if (timeDifference == 0) {
      return 0;
    }
    // the current reserve ratio, cast to a uint256
    uint256 ui18 = uint256(_usdi.reserveRatio());
    // cast the reserve ratio now to an int in order to get a curve value
    int256 reserve_ratio = int256(ui18);

    // calculate the value at the curve. this vault controller is a USDi vault and will reference
    // the vault at address 0
    int256 int_curve_val = _curveMaster.getValueAt(address(0x00), reserve_ratio);

    // cast the integer curve value to a u192
    uint192 curve_val = safeu192(uint256(int_curve_val));
    // calculate the amount of total outstanding loans before and after this interest accrual

    // first calculate how much the interest factor should increase by
    // this is equal to (timedifference * (curve value) / (seconds in a year)) * (interest factor)
    uint192 e18_factor_increase = safeu192(
      truncate(
        truncate((uint256(timeDifference) * uint256(1e18) * uint256(curve_val)) / (365 days + 6 hours)) *
          uint256(_interest.factor)
      )
    );
    // get the total outstanding value before we increase the interest factor
    uint192 valueBefore = safeu192(truncate(uint256(_totalBaseLiability) * uint256(_interest.factor)));
    // _interest is a struct which contains the last timestamp and the current interest factor
    // set the value of this struct to a struct containing {(current block timestamp), (interest factor + increase)}
    // this should save ~5000 gas/call
    _interest = Interest(uint64(block.timestamp), _interest.factor + e18_factor_increase);
    // using that new value, calculate the new total outstanding value
    uint192 valueAfter = safeu192(truncate(uint256(_totalBaseLiability) * uint256(_interest.factor)));

    // valueAfter - valueBefore is now equal to the true amount of interest accured
    // this mitigates rounding errors
    // the protocol's fee amount is equal to this value multiplied by the protocol fee percentage, 1e18=100%
    uint192 protocolAmount = safeu192(truncate(uint256(valueAfter - valueBefore) * uint256(_protocolFee)));
    // donate the true amount of interest less the amount which the protocol is taking for itself
    // this donation is what pays out interest to USDi holders
    _usdi.vaultControllerDonate(valueAfter - valueBefore - protocolAmount);
    // send the protocol's fee to the owner of this contract.
    _usdi.vaultControllerMint(owner(), protocolAmount);
    // emit the event
    emit InterestEvent(uint64(block.timestamp), e18_factor_increase, curve_val);
    // return the interest factor increase
    return e18_factor_increase;
  }

  /// special view only function to help liquidators

  /// @notice helper function to view the status of a range of vaults
  /// @param start the vault to start looping
  /// @param stop the vault to stop looping
  /// @return VaultSummary[] a collection of vault information
  function vaultSummaries(uint96 start, uint96 stop) public view override returns (VaultSummary[] memory) {
    VaultSummary[] memory summaries = new VaultSummary[](stop - start + 1);
    for (uint96 i = start; i <= stop; i++) {
      IVault vault = getVault(i);
      uint256[] memory tokenBalances = new uint256[](_enabledTokens.length);

      for (uint256 j = 0; j < _enabledTokens.length; j++) {
        tokenBalances[j] = vault.tokenBalance(_enabledTokens[j]);
      }
      summaries[i - start] = VaultSummary(
        i,
        this.vaultBorrowingPower(i),
        this.vaultLiability(i),
        _enabledTokens,
        tokenBalances
      );
    }
    return summaries;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IVaultController.sol";

import "../vault/VotingVault.sol";
import "../vault/VaultBPT.sol";

import "../../_external/IERC20Metadata.sol";
import "../../_external/openzeppelin/ERC20Upgradeable.sol";
import "../../_external/openzeppelin/OwnableUpgradeable.sol";
import "../../_external/openzeppelin/Initializable.sol";

/// @title CappedGovToken
/// @notice handles all minting/burning of underlying
/// @dev extends ierc20 upgradable
contract VotingVaultController is Initializable, OwnableUpgradeable {
  //this is unused but needs to stay or the storage will be off by 8 bits for future upgrades
  uint8 private _underlying_decimals;
  IVaultController public _vaultController;

  mapping(address => uint96) public _vaultAddress_vaultId; //standard vault addr
  mapping(uint96 => address) public _vaultId_votingVaultAddress;
  mapping(address => uint96) public _votingVaultAddress_vaultId;

  mapping(address => address) public _underlying_CappedToken;
  mapping(address => address) public _CappedToken_underlying;

  mapping(uint96 => address) public _vaultId_vaultBPTaddress;
  mapping(address => uint96) public _vaultBPTaddress_vaultId;

  mapping(address => auraLpData) public _auraLpData;

  address public _auraBooster;
  address public _auraBal;

  event NewVotingVault(address voting_vault_address, uint256 vaultId);
  event NewVaultBPT(address vault_bpt_address, uint256 vaultId);

  struct auraLpData {
    address rewardToken;
    uint96 pid;
  }

  /// @notice initializer for contract
  /// @param vaultController_ the address of the vault controller
  function initialize(address vaultController_) public initializer {
    __Ownable_init();
    _vaultController = IVaultController(vaultController_);
  }

  function registerAuraLpData(address auraLP, address rewardToken, uint256 pid) external onlyOwner {
    _auraLpData[auraLP] = auraLpData({rewardToken: rewardToken, pid: uint96(pid)});
  }

  function registerAuraBooster(address newBooster) external onlyOwner {
    _auraBooster = newBooster;
  }

  /// @notice auraBal staking is handled slightly differently
  function registerAuraBal(address auraBal) external onlyOwner {
    _auraBal = auraBal;
  }

  /// @notice register an underlying capped token pair
  /// note that registring a token as a capepd token allows it to transfer the balance of the corresponding token at will
  /// @param underlying_address address of underlying
  /// @param capped_token address of capped token
  function registerUnderlying(address underlying_address, address capped_token) external onlyOwner {
    _underlying_CappedToken[underlying_address] = capped_token;
    _CappedToken_underlying[capped_token] = underlying_address;
  }

  /// @notice retrieve underlying asset for the cap token
  /// @param amount of underlying asset to retrieve by burning cap tokens
  /// @param voting_vault holding the underlying
  /// @param target to receive the underlying
  function retrieveUnderlying(uint256 amount, address voting_vault, address target) public {
    require(voting_vault != address(0x0), "invalid vault");

    address underlying_address = _CappedToken_underlying[_msgSender()];

    require(underlying_address != address(0x0), "only capped token");
    VotingVault votingVault = VotingVault(voting_vault);
    votingVault.votingVaultControllerTransfer(underlying_address, target, amount);
  }

  function retrieveUnderlyingBPT(uint256 amount, address vaultBPT, address target) public {
    require(vaultBPT != address(0x0), "invalid vault");

    //get BPT addr
    address underlying_address = _CappedToken_underlying[_msgSender()];
    require(underlying_address != address(0x0), "only capped token");

    VaultBPT bptVault = VaultBPT(vaultBPT);

    bptVault.votingVaultControllerTransfer(underlying_address, target, amount);
  }

  /// @notice create a new vault
  /// @param id of an existing vault
  /// @return address of the new vault
  function mintVault(uint96 id) public returns (address) {
    if (_vaultId_votingVaultAddress[id] == address(0)) {
      address vault_address = _vaultController.vaultAddress(id);
      if (vault_address != address(0)) {
        // mint the vault itself, deploying the contract
        address voting_vault_address = address(
          new VotingVault(id, vault_address, address(_vaultController), address(this))
        );
        // add the vault to our system
        _vaultId_votingVaultAddress[id] = voting_vault_address;
        _vaultAddress_vaultId[vault_address] = id;
        _votingVaultAddress_vaultId[voting_vault_address] = id;
        // emit the event
        emit NewVotingVault(voting_vault_address, id);
      }
    }
    return _vaultId_votingVaultAddress[id];
  }

  function mintBptVault(uint96 id) public returns (address) {
    if (_vaultId_vaultBPTaddress[id] == address(0)) {
      //standard vault address
      address vault_address = _vaultController.vaultAddress(id);

      //if a standard vault exists already
      if (vault_address != address(0)) {
        // mint the vault itself, deploying the contract
        address bpt_vault_address = address(new VaultBPT(id, vault_address, address(_vaultController), address(this)));
        // add the vault to our system
        _vaultId_vaultBPTaddress[id] = bpt_vault_address;
        _vaultAddress_vaultId[vault_address] = id;
        _vaultBPTaddress_vaultId[bpt_vault_address] = id;
        // emit the event
        emit NewVaultBPT(bpt_vault_address, id);
      }
    }
    return _vaultId_vaultBPTaddress[id];
  }

  function getAuraLpData(address lp) external view returns (address rewardToken, uint256 pid) {
    auraLpData memory data = _auraLpData[lp];
    rewardToken = data.rewardToken;
    pid = uint256(data.pid);
  }

  function votingVaultId(address voting_vault_address) public view returns (uint96) {
    return _votingVaultAddress_vaultId[voting_vault_address];
  }

  function vaultId(address vault_address) public view returns (uint96) {
    return _vaultAddress_vaultId[vault_address];
  }

  function votingVaultAddress(uint96 vault_id) public view returns (address) {
    return _vaultId_votingVaultAddress[vault_id];
  }

  function BPTvaultId(address vault_bpt_address) public view returns (uint96) {
    return _vaultBPTaddress_vaultId[vault_bpt_address];
  }

  function BPTvaultAddress(uint96 vault_id) public view returns (address) {
    return _vaultId_vaultBPTaddress[vault_id];
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// @title Vault Events
/// @notice interface which contains any events which the Vault contract emits
interface VaultEvents {
  event Deposit(address token_address, uint256 amount);
  event Withdraw(address token_address, uint256 amount);
}

/// @title Vault Interface
/// @notice extends VaultEvents
interface IVault is VaultEvents {
  /// @notice value of _baseLiability
  function baseLiability() external view returns (uint256);

  /// @notice value of _vaultInfo.minter
  function minter() external view returns (address);

  /// @notice value of _vaultInfo.id
  function id() external view returns (uint96);

  /// @notice value of _tokenBalance
  function tokenBalance(address) external view returns (uint256);

  // business logic

  function withdrawErc20(address token_address, uint256 amount) external;

  function delegateCompLikeTo(address compLikeDelegatee, address compLikeToken) external;

  // administrative functions
  function controllerTransfer(address _token, address _to, uint256 _amount) external;

  function modifyLiability(bool increase, uint256 base_amount) external returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// @title VaultController Events
/// @notice interface which contains any events which the VaultController contract emits
interface VaultControllerEvents {
  event InterestEvent(uint64 epoch, uint192 amount, uint256 curve_val);
  event NewProtocolFee(uint256 protocol_fee);
  event RegisteredErc20(address token_address, uint256 LTVe4, address oracle_address, uint256 liquidationIncentivee4);
  event UpdateRegisteredErc20(
    address token_address,
    uint256 LTVe4,
    address oracle_address,
    uint256 liquidationIncentivee4
  );
  event NewVault(address vault_address, uint256 vaultId, address vaultOwner);
  event RegisterOracleMaster(address oracleMasterAddress);
  event RegisterCurveMaster(address curveMasterAddress);
  event BorrowUSDi(uint256 vaultId, address vaultAddress, uint256 borrowAmount);
  event RepayUSDi(uint256 vaultId, address vaultAddress, uint256 repayAmount);
  event Liquidate(uint256 vaultId, address asset_address, uint256 usdi_to_repurchase, uint256 tokens_to_liquidate);
}

/// @title VaultController Interface
/// @notice extends VaultControllerEvents
interface IVaultController is VaultControllerEvents {
  // initializer
  function initialize() external;

  // view functions

  function tokensRegistered() external view returns (uint256);

  function vaultsMinted() external view returns (uint96);

  function lastInterestTime() external view returns (uint64);

  function totalBaseLiability() external view returns (uint192);

  function interestFactor() external view returns (uint192);

  function protocolFee() external view returns (uint192);

  function vaultAddress(uint96 id) external view returns (address);

  function vaultIDs(address wallet) external view returns (uint96[] memory);

  function amountToSolvency(uint96 id) external view returns (uint256);

  function vaultLiability(uint96 id) external view returns (uint192);

  function vaultBorrowingPower(uint96 id) external view returns (uint192);

  function tokensToLiquidate(uint96 id, address token) external view returns (uint256);

  function checkVault(uint96 id) external view returns (bool);

  struct VaultSummary {
    uint96 id;
    uint192 borrowingPower;
    uint192 vaultLiability;
    address[] tokenAddresses;
    uint256[] tokenBalances;
  }

  function vaultSummaries(uint96 start, uint96 stop) external view returns (VaultSummary[] memory);

  // interest calculations
  function calculateInterest() external returns (uint256);

  // vault management business
  function mintVault() external returns (address);

  function liquidateVault(uint96 id, address asset_address, uint256 tokenAmount) external returns (uint256);

  function borrowUsdi(uint96 id, uint192 amount) external;

  function borrowUSDIto(uint96 id, uint192 amount, address target) external;

  function borrowUSDCto(uint96 id, uint192 usdc_amount, address target) external;

  function repayUSDi(uint96 id, uint192 amount) external;

  function repayAllUSDi(uint96 id) external;

  // admin
  function pause() external;

  function unpause() external;

  function getOracleMaster() external view returns (address);

  function registerOracleMaster(address master_oracle_address) external;

  function getCurveMaster() external view returns (address);

  function registerCurveMaster(address master_curve_address) external;

  function changeProtocolFee(uint192 new_protocol_fee) external;

  function registerErc20(
    address token_address,
    uint256 LTV,
    address oracle_address,
    uint256 liquidationIncentive
  ) external;

  function registerUSDi(address usdi_address) external;

  function updateRegisteredErc20(
    address token_address,
    uint256 LTV,
    address oracle_address,
    uint256 liquidationIncentive
  ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../IUSDI.sol";
import "../IVault.sol";
import "../IVaultController.sol";

import "../../_external/CompLike.sol";
import "../../_external/IERC20.sol";
import "../../_external/Context.sol";
import "../../_external/openzeppelin/SafeERC20Upgradeable.sol";

/// @title Vault
/// @notice our implentation of maker-vault like vault
/// major differences:
/// 1. multi-collateral
/// 2. generate interest in USDi
/// 3. can delegate voting power of contained tokens
contract Vault is IVault, Context {
  using SafeERC20Upgradeable for IERC20;

  /// @title VaultInfo struct
  /// @notice this struct is used to store the vault metadata
  /// this should reduce the cost of minting by ~15,000
  /// by limiting us to max 2**96-1 vaults
  struct VaultInfo {
    uint96 id;
    address minter;
  }
  /// @notice Metadata of vault, aka the id & the minter's address
  VaultInfo public _vaultInfo;
  IVaultController public immutable _controller;

  /// @notice this is the unscaled liability of the vault.
  /// the number is meaningless on its own, and must be combined with the factor taken from
  /// the vaultController in order to find the true liabilitiy
  uint256 public _baseLiability;

  /// @notice checks if _msgSender is the controller of the vault
  modifier onlyVaultController() {
    require(_msgSender() == address(_controller), "sender not VaultController");
    _;
  }

  /// @notice checks if _msgSender is the minter of the vault
  modifier onlyMinter() {
    require(_msgSender() == _vaultInfo.minter, "sender not minter");
    _;
  }

  /// @notice must be called by VaultController, else it will not be registered as a vault in system
  /// @param id_ unique id of the vault, ever increasing and tracked by VaultController
  /// @param minter_ address of the person who created this vault
  /// @param controller_address address of the VaultController
  constructor(uint96 id_, address minter_, address controller_address) {
    _vaultInfo = VaultInfo(id_, minter_);
    _controller = IVaultController(controller_address);
  }

  /// @notice minter of the vault
  /// @return address of minter
  function minter() external view override returns (address) {
    return _vaultInfo.minter;
  }

  /// @notice id of the vault
  /// @return address of minter
  function id() external view override returns (uint96) {
    return _vaultInfo.id;
  }

  /// @notice current vault base liability
  /// @return base liability of vault
  function baseLiability() external view override returns (uint256) {
    return _baseLiability;
  }

  /// @notice get vaults balance of an erc20 token
  /// @param addr address of the erc20 token
  /// @dev scales wBTC up to normal erc20 size
  function tokenBalance(address addr) external view override returns (uint256) {
    return IERC20(addr).balanceOf(address(this));
  }

  /// @notice withdraw an erc20 token from the vault
  /// this can only be called by the minter
  /// the withdraw will be denied if ones vault would become insolvent
  /// @param token_address address of erc20 token
  /// @param amount amount of erc20 token to withdraw
  function withdrawErc20(address token_address, uint256 amount) external override onlyMinter {
    // transfer the token to the owner
    SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(token_address), _msgSender(), amount);
    //  check if the account is solvent
    require(_controller.checkVault(_vaultInfo.id), "over-withdrawal");
    emit Withdraw(token_address, amount);
  }

  /// @notice delegate the voting power of a comp-like erc20 token to another address
  /// @param delegatee address that will receive the votes
  /// @param token_address address of comp-like erc20 token
  function delegateCompLikeTo(address delegatee, address token_address) external override onlyMinter {
    CompLike(token_address).delegate(delegatee);
  }

  /// @notice function used by the VaultController to transfer tokens
  /// callable by the VaultController only
  /// @param _token token to transfer
  /// @param _to person to send the coins to
  /// @param _amount amount of coins to move
  function controllerTransfer(address _token, address _to, uint256 _amount) external override onlyVaultController {
    SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_token), _to, _amount);
  }

  /// @notice function used by the VaultController to reduce a vault's liability
  /// callable by the VaultController only
  /// @param increase true to increase, false to decrease
  /// @param base_amount change in base liability
  function modifyLiability(bool increase, uint256 base_amount) external override onlyVaultController returns (uint256) {
    if (increase) {
      _baseLiability = _baseLiability + base_amount;
    } else {
      // require statement only valid for repayment
      require(_baseLiability >= base_amount, "repay too much");
      _baseLiability = _baseLiability - base_amount;
    }
    return _baseLiability;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../controller/VotingVaultController.sol";

import "../../IUSDI.sol";
import "../IVault.sol";
import "../IVaultController.sol";

import "../../_external/CompLike.sol";
import "../../_external/IERC20.sol";
import "../../_external/Context.sol";
import "../../_external/openzeppelin/SafeERC20Upgradeable.sol";

import "../../_external/balancer/IGauge.sol";

//testing
import "hardhat/console.sol";

interface IRewardsPool {
  function stakeAll() external returns (bool);

  function getReward() external returns (bool);

  function earned(address account) external view returns (uint256);

  function rewards(address account) external view returns (uint256);

  function getReward(address _account, bool _claimExtras) external returns (bool);

  function withdrawAll(bool claim) external;

  function withdrawAllAndUnwrap(bool claim) external;

  function balanceOf(address target) external view returns (uint256);

  function pid() external view returns (uint256);

  function extraRewardsLength() external view returns (uint256);

  function extraRewards(uint256 idx) external view returns (address);

  function rewardToken() external view returns (address);
}

interface IVirtualRewardPool {
  function getReward() external;

  function earned(address account) external view returns (uint256);

  function balanceOf(address target) external view returns (uint256);

  function rewardToken() external view returns (address);
}

interface IBooster {
  function depositAll(uint256 _pid, bool _stake) external returns (bool);

  function poolInfo(
    uint256 pid
  )
    external
    view
    returns (address lptoken, address token, address gauge, address crvRewards, address stash, bool shutdown);
}

contract VaultBPT is Context {
  using SafeERC20Upgradeable for IERC20;

  /// @title VaultInfo struct
  /// @notice This vault holds the underlying token
  /// @notice The Capped token is held by the parent vault
  /// @notice Withdrawls must be initiated by the withdrawErc20() function on the parent vault

  /// @notice this struct is used to store the vault metadata
  /// this should reduce the cost of minting by ~15,000
  /// by limiting us to max 2**96-1 vaults
  struct VaultInfo {
    uint96 id;
    address vault_address;
  }
  /// @notice Metadata of vault, aka the id & the minter's address
  VaultInfo public _vaultInfo;

  VotingVaultController public _votingController;
  IVaultController public _controller;

  /// @notice if staked, then underlying is not in the vault so we need to unstake
  /// all assets stake all or nothing
  mapping(address => bool) public isStaked;

  //mapping(address => stakeType) public typeOfStake;

  //mapping(address => address) public lp_rewardtoken;

/**
  enum stakeType {
    AURABAL,
    AURA_LP,
    BAL_LP
  }
 */

  /// @notice checks if _msgSender is the controller of the voting vault
  modifier onlyVotingVaultController() {
    require(_msgSender() == address(_votingController), "sender not VotingVaultController");
    _;
  }
  /// @notice checks if _msgSender is the controller of the vault
  modifier onlyVaultController() {
    require(_msgSender() == address(_controller), "sender not VaultController");
    _;
  }
  /// @notice checks if _msgSender is the minter of the vault
  modifier onlyMinter() {
    require(_msgSender() == IVault(_vaultInfo.vault_address).minter(), "sender not minter");
    _;
  }

  /// @notice must be called by VotingVaultController, else it will not be registered as a vault in system
  /// @param id_ is the shared ID of both the voting vault and the standard vault
  /// @param vault_address address of the vault this is attached to
  /// @param controller_address address of the vault controller
  /// @param voting_controller_address address of the voting vault controller
  constructor(
    uint96 id_,
    address vault_address,
    address controller_address,
    address voting_controller_address //address _auraBal
  ) {
    _vaultInfo = VaultInfo(id_, vault_address);
    _controller = IVaultController(controller_address);
    _votingController = VotingVaultController(voting_controller_address);
  }

  function parentVault() external view returns (address) {
    return address(_vaultInfo.vault_address);
  }

  /// @notice id of the vault
  /// @return address of minter
  function id() external view returns (uint96) {
    return _vaultInfo.id;
  }

  /** auraBal && aura LP token staking */
  ///@param lp underlying lp
  ///@param lp is NOT the gauge token, but the actual LP
  ///@notice unfortunately, there is no simple way to stake directly from the gauge token to the Aura rewards token
  function stakeAuraLP(IERC20 lp) external returns (bool) {
    require(isStaked[address(lp)] == false, "already staked");
    isStaked[address(lp)] = true;
    (address rewardsToken, uint256 pid) = _votingController.getAuraLpData(address(lp));

    //stake auraBal directly on rewards pool
    if (address(lp) == _votingController._auraBal()) {
      IRewardsPool rp = IRewardsPool(rewardsToken);
      lp.approve(rewardsToken, lp.balanceOf(address(this)));

      require(rp.stakeAll(), "auraBal staking failed");
      return true;
    }

    //else we stake other LPs via booster contract
    IBooster booster = IBooster(_votingController._auraBooster());

    //approve booster
    lp.approve(address(booster), lp.balanceOf(address(this)));

    //deposit via booster
    require(booster.depositAll(pid, true), "Deposit failed");
    return true;
  }

  /// @param lp - the aura LP token address, or auraBal address
  /// @param claimExtra - claim extra token rewards, uses more gas
  function claimAuraLpRewards(IERC20 lp, bool claimExtra) external {
    bool solvencyCheckNeeded = false;

    //get rewards pool
    (address rewardsToken, uint256 PID) = _votingController.getAuraLpData(address(lp));
    IRewardsPool rp = IRewardsPool(rewardsToken);

    //claim rewards
    rp.getReward(address(this), claimExtra);

    //get minter
    address minter = IVault(_vaultInfo.vault_address).minter();

    //send rewards to minter
    IERC20 rewardToken = IERC20(rp.rewardToken());

    //check if rewardToken is registered as a collateral, if not, the _rewardToken should be 0x0
    (address _rewardToken, ) = _votingController.getAuraLpData(address(rewardToken));
    if (_rewardToken != address(0x0)) {
      solvencyCheckNeeded = true;
    }

    rewardToken.transfer(minter, rewardToken.balanceOf(address(this)));

    //repeat for claimExtra
    if (claimExtra) {
      for (uint256 i = 0; i < rp.extraRewardsLength(); i++) {
        IVirtualRewardPool extraRewardPool = IVirtualRewardPool(rp.extraRewards(i));

        IERC20 extraRewardToken = IERC20(extraRewardPool.rewardToken());

        //check if extraRewardToken is registered as a collateral, if not, the _rewardToken should be 0x0
        (address _rewardToken, ) = _votingController.getAuraLpData(address(extraRewardToken));
        if (_rewardToken != address(0x0)) {
          solvencyCheckNeeded = true;
        }
        extraRewardPool.getReward();

        extraRewardToken.transfer(minter, extraRewardToken.balanceOf(address(this)));
      }
    }
    
    // if an underlying reward or extra reward token is used as collateral,
    // claiming rewards will empty the vault of this token, this check prevents this
    // if it is the case that the underlying reward token is registered collateral held by this vault
    // the liability will need to be repaid sufficiently in order to claim rewards
    if (solvencyCheckNeeded) {
      require(_controller.checkVault(_vaultInfo.id), "Claim causes insolvency");
    }
  }

  /// @notice manual unstake
  /// todo needed?
  function unstakeAuraLP(address lp) external onlyMinter {
    _unstakeAuraLP(lp, (lp == _votingController._auraBal()));
  }

  function _unstakeAuraLP(address lp, bool auraBal) internal {
    isStaked[lp] = false;
    (address rewardsToken, ) = _votingController.getAuraLpData(lp);
    IRewardsPool rp = IRewardsPool(rewardsToken);

    if (auraBal) {
      rp.withdrawAll(false);
    } else {
      rp.withdrawAllAndUnwrap(false);
    }
  }

  /// @notice function used by the VaultController to transfer tokens
  /// callable by the VaultController only
  /// not currently in use, available for future upgrades
  /// @param _token token to transfer
  /// @param _to person to send the coins to
  /// @param _amount amount of coins to move
  function controllerTransfer(address _token, address _to, uint256 _amount) external onlyVaultController {
    if (isStaked[_token] == true) {
      _unstakeAuraLP(_token, (_token == _votingController._auraBal()));
    }

    SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_token), _to, _amount);
  }

  /// @notice function used by the VotingVaultController to transfer tokens
  /// callable by the VotingVaultController only
  /// @param _token token to transfer
  /// @param _to person to send the coins to
  /// @param _amount amount of coins to move
  function votingVaultControllerTransfer(
    address _token,
    address _to,
    uint256 _amount
  ) external onlyVotingVaultController {
    if (isStaked[_token] == true) {
      _unstakeAuraLP(_token, (_token == _votingController._auraBal()));
    }

    SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_token), _to, _amount);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../controller/NftVaultController.sol";

import "../../IUSDI.sol";
import "../IVault.sol";
import "../IVaultController.sol";

import "../../_external/CompLike.sol";
import "../../_external/IERC721.sol";
import "../../_external/Context.sol";

//not sure this is a thing
//import "../../_external/openzeppelin/SafeERC721Upgradeable.sol";

import "../../_external/balancer/IGauge.sol";

//testing
import "hardhat/console.sol";

contract VaultNft is Context {
  //using SafeERC721Upgradeable for IERC721;

  /// @title VaultInfo struct
  /// @notice This vault holds the underlying token
  /// @notice The Capped token is held by the parent vault
  /// @notice Withdrawls must be initiated by the withdrawErc20() function on the parent vault

  /// @notice this struct is used to store the vault metadata
  /// this should reduce the cost of minting by ~15,000
  /// by limiting us to max 2**96-1 vaults
  struct VaultInfo {
    uint96 id;
    address vault_address;
  }
  /// @notice Metadata of vault, aka the id & the minter's address
  VaultInfo public _vaultInfo;

  NftVaultController public _nftController;
  IVaultController public _controller;

  /// @notice checks if _msgSender is the controller of the nft vault
  modifier onlyNftVaultController() {
    require(_msgSender() == address(_nftController), "sender not NftVaultController");
    _;
  }
  /// @notice checks if _msgSender is the controller of the vault
  modifier onlyVaultController() {
    require(_msgSender() == address(_controller), "sender not VaultController");
    _;
  }
  /// @notice checks if _msgSender is the minter of the vault
  modifier onlyMinter() {
    require(_msgSender() == IVault(_vaultInfo.vault_address).minter(), "sender not minter");
    _;
  }

  /// @notice must be called by NftVaultController, else it will not be registered as a vault in system
  /// @param id_ is the shared ID of both the nft vault and the standard vault
  /// @param vault_address address of the vault this is attached to
  /// @param controller_address address of the vault controller
  /// @param nft_controller_address address of the nft vault controller
  constructor(
    uint96 id_,
    address vault_address,
    address controller_address,
    address nft_controller_address //address _auraBal
  ) {
    _vaultInfo = VaultInfo(id_, vault_address);
    _controller = IVaultController(controller_address);
    _nftController = NftVaultController(nft_controller_address);
  }

  function parentVault() external view returns (address) {
    return address(_vaultInfo.vault_address);
  }

  /// @notice id of the vault
  /// @return address of minter
  function id() external view returns (uint96) {
    return _vaultInfo.id;
  }

  /// callable by the VaultController only
  /// not currently in use, available for future upgrades
  /// @param _token token to transfer
  /// @param _to person to send the nft to
  /// @param _tokenId tokenId of nft to move
  function controllerTransfer(
    address _token,
    address _to,
    uint256 _tokenId
  ) external onlyVaultController {
    //todo
    //SafeERC721Upgradeable.safeTransfer(IERC721Upgradeable(_token, _to, _tokenId);
  }

  /// @notice function used by the NftVaultController to transfer tokens
  /// callable by the NftVaultController only
  /// @param _token token to transfer
  /// @param _to person to send the nft to
  /// @param _tokenId tokenId of nft to move
  function nftVaultControllerTransfer(
    address _token,
    address _to,
    uint256 _tokenId
  ) external onlyNftVaultController {
    //todo
    //SafeERC721Upgradeable.safeTransfer(IERC721Upgradeable(_token, _to, _tokenId);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../_external/IERC20Metadata.sol";
import "../../_external/openzeppelin/ERC20Upgradeable.sol";
import "../../_external/openzeppelin/OwnableUpgradeable.sol";
import "../../_external/openzeppelin/Initializable.sol";

import "../IVaultController.sol";
import "../vault/VotingVault.sol";

/// @title CappedGovToken
/// @notice handles all minting/burning of underlying
/// @dev extends ierc20 upgradable
contract testUpgrade is Initializable, OwnableUpgradeable {
  IVaultController public _vaultController;

  mapping(address => uint96) public _vaultAddress_vaultId;
  mapping(uint96 => address) public _vaultId_votingVaultAddress;
  mapping(address => uint96) public _votingVaultAddress_vaultId;

  mapping(address => address) public _underlying_CappedToken;
  mapping(address => address) public _CappedToken_underlying;

  event NewVotingVault(address voting_vault_address, uint256 vaultId);

  /// @notice initializer for contract
  /// @param vaultController_ the address of the vault controller
  function initialize(address vaultController_) public initializer {
    __Ownable_init();
    _vaultController = IVaultController(vaultController_);
  }

  /// @notice register an underlying capped token pair
  /// note that registring a token as a capepd token allows it to transfer the balance of the corresponding token at will
  /// @param underlying_address address of underlying
  /// @param capped_token address of capped token
  function registerUnderlying(address underlying_address, address capped_token) external onlyOwner {
    _underlying_CappedToken[underlying_address] = capped_token;
    _CappedToken_underlying[capped_token] = underlying_address;
  }

  /// @notice retrieve underlying asset for the cap token
  /// @param amount of underlying asset to retrieve by burning cap tokens
  /// @param voting_vault holding the underlying
  /// @param target to receive the underlying
  function retrieveUnderlying(uint256 amount, address voting_vault, address target) public {
    require(voting_vault != address(0x0), "invalid vault");

    address underlying_address = _CappedToken_underlying[_msgSender()];

    require(underlying_address != address(0x0), "only capped token");
    VotingVault votingVault = VotingVault(voting_vault);
    votingVault.votingVaultControllerTransfer(underlying_address, target, amount);
  }

  /// @notice create a new vault
  /// @param id of an existing vault
  /// @return address of the new vault
  function mintVault(uint96 id) public returns (address) {
    if (_vaultId_votingVaultAddress[id] == address(0)) {
      address vault_address = _vaultController.vaultAddress(id);
      if (vault_address != address(0)) {
        // mint the vault itself, deploying the contract
        address voting_vault_address = address(
          new VotingVault(id, vault_address, address(_vaultController), address(this))
        );
        // add the vault to our system
        _vaultId_votingVaultAddress[id] = voting_vault_address;
        _vaultAddress_vaultId[vault_address] = id;
        _votingVaultAddress_vaultId[voting_vault_address] = id;
        // emit the event
        emit NewVotingVault(voting_vault_address, id);
      }
    }
    return _vaultId_votingVaultAddress[id];
  }

  function votingVaultId(address voting_vault_address) public view returns (uint96) {
    return _votingVaultAddress_vaultId[voting_vault_address];
  }

  function vaultId(address vault_address) public view returns (uint96) {
    return _vaultAddress_vaultId[vault_address];
  }

  function votingVaultAddress(uint96 vault_id) public view returns (address) {
    return _vaultId_votingVaultAddress[vault_id];
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../controller/VotingVaultController.sol";

import "../../IUSDI.sol";
import "../IVault.sol";
import "../IVaultController.sol";

import "../../_external/CompLike.sol";
import "../../_external/IERC20.sol";
import "../../_external/Context.sol";
import "../../_external/openzeppelin/SafeERC20Upgradeable.sol";

contract VotingVault is Context {
  using SafeERC20Upgradeable for IERC20;

  /// @title VaultInfo struct
  /// @notice This vault holds the underlying token
  /// @notice The Capped token is held by the parent vault
  /// @notice Withdrawls must be initiated by the withdrawErc20() function on the parent vault

  /// @notice this struct is used to store the vault metadata
  /// this should reduce the cost of minting by ~15,000
  /// by limiting us to max 2**96-1 vaults
  struct VaultInfo {
    uint96 id;
    address vault_address;
  }
  /// @notice Metadata of vault, aka the id & the minter's address
  VaultInfo public _vaultInfo;

  VotingVaultController public _votingController;
  IVaultController public _controller;

  /// @notice checks if _msgSender is the controller of the voting vault
  modifier onlyVotingVaultController() {
    require(_msgSender() == address(_votingController), "sender not VotingVaultController");
    _;
  }
  /// @notice checks if _msgSender is the controller of the vault
  modifier onlyVaultController() {
    require(_msgSender() == address(_controller), "sender not VaultController");
    _;
  }
  /// @notice checks if _msgSender is the minter of the vault
  modifier onlyMinter() {
    require(_msgSender() == IVault(_vaultInfo.vault_address).minter(), "sender not minter");
    _;
  }

  /// @notice must be called by VotingVaultController, else it will not be registered as a vault in system
  /// @param id_ is the shared ID of both the voting vault and the standard vault
  /// @param vault_address address of the vault this is attached to
  /// @param controller_address address of the vault controller
  /// @param voting_controller_address address of the voting vault controller
  constructor(uint96 id_, address vault_address, address controller_address, address voting_controller_address) {
    _vaultInfo = VaultInfo(id_, vault_address);
    _controller = IVaultController(controller_address);
    _votingController = VotingVaultController(voting_controller_address);
  }

  function parentVault() external view returns (address) {
    return address(_vaultInfo.vault_address);
  }

  /// @notice id of the vault
  /// @return address of minter
  function id() external view returns (uint96) {
    return _vaultInfo.id;
  }

  /// @notice delegate the voting power of a comp-like erc20 token to another address
  /// @param delegatee address that will receive the votes
  /// @param token_address address of comp-like erc20 token
  function delegateCompLikeTo(address delegatee, address token_address) external onlyMinter {
    CompLike(token_address).delegate(delegatee);
  }

  /// @notice function used by the VaultController to transfer tokens
  /// callable by the VaultController only
  /// not currently in use, available for future upgrades
  /// @param _token token to transfer
  /// @param _to person to send the coins to
  /// @param _amount amount of coins to move
  function controllerTransfer(address _token, address _to, uint256 _amount) external onlyVaultController {
    SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_token), _to, _amount);
  }

  /// @notice function used by the VotingVaultController to transfer tokens
  /// callable by the VotingVaultController only
  /// @param _token token to transfer
  /// @param _to person to send the coins to
  /// @param _amount amount of coins to move
  function votingVaultControllerTransfer(
    address _token,
    address _to,
    uint256 _amount
  ) external onlyVotingVaultController {
    SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_token), _to, _amount);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../vault/VaultBPT.sol";
import "../controller/VotingVaultController.sol";

import "../IVaultController.sol";
import "../IVault.sol";

import "../../_external/IERC20Metadata.sol";
import "../../_external/openzeppelin/ERC20Upgradeable.sol";
import "../../_external/openzeppelin/OwnableUpgradeable.sol";
import "../../_external/openzeppelin/Initializable.sol";
import "../../_external/openzeppelin/SafeERC20Upgradeable.sol";

/// @title CappedGovToken
/// @notice handles all minting/burning of underlying
/// @dev extends ierc20 upgradable
contract CappedBptToken is Initializable, OwnableUpgradeable, ERC20Upgradeable {
  using SafeERC20Upgradeable for ERC20Upgradeable;

  ERC20Upgradeable public _underlying;
  IVaultController public _vaultController;
  VotingVaultController public _votingVaultController;

  // in actual units
  uint256 public _cap;

  bool private locked;
  modifier nonReentrant() {
    locked = true;
    _;
    locked = false;
  }

  event cappedBPTtransfer(uint96 vaultId, address recipient, uint256 amount);

  /// @notice initializer for contract
  /// @param name_ name of capped token
  /// @param symbol_ symbol of capped token
  /// @param underlying_ the address of underlying
  /// @param vaultController_ the address of vault controller
  /// @param votingVaultController_ the address of voting vault controller
  function initialize(
    string memory name_,
    string memory symbol_,
    address underlying_,
    address vaultController_,
    address votingVaultController_
  ) public initializer {
    __Ownable_init();
    __ERC20_init(name_, symbol_);
    _underlying = ERC20Upgradeable(underlying_);

    _vaultController = IVaultController(vaultController_);
    _votingVaultController = VotingVaultController(votingVaultController_);

    locked = false;
  }

  /// @notice 18 decimal erc20 spec should have been written into the fucking standard
  function decimals() public pure override returns (uint8) {
    return 18;
  }

  /// @notice get the Cap
  /// @return cap uint256
  function getCap() public view returns (uint256) {
    return _cap;
  }

  /// @notice set the Cap
  function setCap(uint256 cap_) external onlyOwner {
    _cap = cap_;
  }

  function checkCap(uint256 amount_) internal view {
    require(ERC20Upgradeable.totalSupply() + amount_ <= _cap, "cap reached");
  }

  /// @notice deposit _underlying to mint CappedToken
  /// @notice gaugeToken is fungible 1:1 with underlying BPT
  /// @param amount of underlying to deposit
  /// @param vaultId recipient vault of tokens
  /// @param stake deposit + stake in 1 TX, for auraBal or aura LPs
  function deposit(uint256 amount, uint96 vaultId, bool stake) public nonReentrant {
    require(amount > 0, "Cannot deposit 0");
    VaultBPT bptVault = VaultBPT(_votingVaultController.BPTvaultAddress(vaultId));
    require(address(bptVault) != address(0x0), "invalid voting vault");
    IVault vault = IVault(_vaultController.vaultAddress(vaultId));
    require(address(vault) != address(0x0), "invalid vault");

    // check cap
    checkCap(amount);

    // mint this token, the collateral token, to the vault
    ERC20Upgradeable._mint(address(vault), amount);

    // take underlying and sent to BPT vault
    _underlying.safeTransferFrom(_msgSender(), address(bptVault), amount);

    if (stake) {
      bptVault.stakeAuraLP(IERC20(address(_underlying)));
    }
  }

  function transfer(address recipient, uint256 amount) public override returns (bool) {
    uint96 vault_id = _votingVaultController.vaultId(_msgSender());
    // only vaults will ever send this. only vaults will ever hold this token.
    require(vault_id > 0, "only vaults");
    // get the corresponding voting vault
    address BPT_vault_address = _votingVaultController.BPTvaultAddress(vault_id);
    require(BPT_vault_address != address(0x0), "no voting vault");
    // burn the collateral tokens from the sender, which is the vault that holds the collateral tokens
    ERC20Upgradeable._burn(_msgSender(), amount);
    // move the underlying tokens from voting vault to the target
    _votingVaultController.retrieveUnderlyingBPT(amount, BPT_vault_address, recipient);
    // emit event for clarity
    emit cappedBPTtransfer(vault_id, recipient, amount);
    return true;
  }

  function transferFrom(
    address /*sender*/,
    address /*recipient*/,
    uint256 /*amount*/
  ) public pure override returns (bool) {
    // allowances are never granted, as the VotingVault does not grant allowances.
    // this function is therefore always uncallable and so we will just return false
    return false;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../vault/VotingVault.sol";
import "../controller/VotingVaultController.sol";
import "../IVaultController.sol";
import "../IVault.sol";

import "../../_external/IERC20Metadata.sol";
import "../../_external/openzeppelin/ERC20Upgradeable.sol";
import "../../_external/openzeppelin/OwnableUpgradeable.sol";
import "../../_external/openzeppelin/Initializable.sol";
import "../../_external/openzeppelin/SafeERC20Upgradeable.sol";

/// @title CappedFeeOnTransferToken
/// @notice handles all minting/burning of underlying
/// @dev extends ierc20 upgradable
contract CappedFeeOnTransferToken is Initializable, OwnableUpgradeable, ERC20Upgradeable {
  using SafeERC20Upgradeable for ERC20Upgradeable;

  ERC20Upgradeable public _underlying;
  IVaultController public _vaultController;
  VotingVaultController public _votingVaultController;

  /// @notice CAP is in units of the CAP token,so 18 decimals.
  ///         not the underlying!!!!!!!!!
  uint256 public _cap;

  /// @notice need to prevent reentrancy on deposit as calcs are done after transfer
  bool internal locked;
  modifier nonReentrant() {
    require(!locked, "locked");
    locked = true;
    _;
    locked = false;
  }

  /// @notice initializer for contract
  /// @param name_ name of capped token
  /// @param symbol_ symbol of capped token
  /// @param underlying_ the address of underlying
  function initialize(
    string memory name_,
    string memory symbol_,
    address underlying_,
    address vaultController_,
    address votingVaultController_
  ) public initializer {
    __Ownable_init();
    __ERC20_init(name_, symbol_);
    _underlying = ERC20Upgradeable(underlying_);

    _vaultController = IVaultController(vaultController_);
    _votingVaultController = VotingVaultController(votingVaultController_);

    locked = false;
  }

  /// @notice 18 decimal erc20 spec should have been written into the fucking standard
  function decimals() public pure override returns (uint8) {
    return 18;
  }

  /// @notice get the Cap
  /// @return cap uint256
  function getCap() public view returns (uint256) {
    return _cap;
  }

  /// @notice set the Cap
  function setCap(uint256 cap_) external onlyOwner {
    _cap = cap_;
  }

  function checkCap() internal view {
    require(ERC20Upgradeable.totalSupply() <= _cap, "cap reached");
  }

  /// @notice deposit _underlying to mint CappedToken
  /// @notice nonReentrant modifier needed as calculations are done after transfer
  /// @param amount of underlying to deposit
  /// @param vaultId recipient vault of tokens
  function deposit(uint256 amount, uint96 vaultId) public nonReentrant {
    require(amount > 0, "Cannot deposit 0");

    //gather vault information
    VotingVault votingVault = VotingVault(_votingVaultController.votingVaultAddress(vaultId));
    require(address(votingVault) != address(0x0), "invalid voting vault");
    IVault vault = IVault(_vaultController.vaultAddress(vaultId));
    require(address(vault) != address(0x0), "invalid vault");

    // check allowance and ensure transfer success
    uint256 allowance = _underlying.allowance(_msgSender(), address(this));
    require(allowance >= amount, "Insufficient Allowance");

    uint256 startingUnderlying = _underlying.balanceOf(address(votingVault));

    // send the actual underlying from the caller to the voting vault for the vault
    _underlying.safeTransferFrom(_msgSender(), address(votingVault), amount);

    //verify the actual amount received
    uint256 amountReceived = _underlying.balanceOf(address(votingVault)) - startingUnderlying;

    //mint amountReceived new capTokens to the vault
    ERC20Upgradeable._mint(address(vault), amountReceived);

    // check cap to make sure we didn't exceed it
    checkCap();
  }

  function transfer(address recipient, uint256 amount) public override returns (bool) {
    uint96 vault_id = _votingVaultController.vaultId(_msgSender());

    // only vaults should call this. only vaults will ever hold this token.
    require(vault_id > 0, "only vaults");

    // get the corresponding voting vault
    address voting_vault_address = _votingVaultController.votingVaultAddress(vault_id);

    require(voting_vault_address != address(0x0), "no voting vault");

    // burn the collateral tokens from the sender, which is the vault that holds the collateral tokens
    ERC20Upgradeable._burn(_msgSender(), amount);

    // move the underlying tokens from voting vault to the target
    _votingVaultController.retrieveUnderlying(amount, voting_vault_address, recipient);

    return true;
  }

  function transferFrom(
    address /*sender*/,
    address /*recipient*/,
    uint256 /*amount*/
  ) public pure override returns (bool) {
    // allowances are never granted, as the VotingVault does not grant allowances.
    // this function is therefore always uncallable and so we will just return false
    return false;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../vault/VotingVault.sol";
import "../controller/VotingVaultController.sol";

import "../IVaultController.sol";
import "../IVault.sol";

import "../../_external/IERC20Metadata.sol";
import "../../_external/openzeppelin/ERC20Upgradeable.sol";
import "../../_external/openzeppelin/OwnableUpgradeable.sol";
import "../../_external/openzeppelin/Initializable.sol";
import "../../_external/openzeppelin/SafeERC20Upgradeable.sol";

/// @title CappedGovToken
/// @notice handles all minting/burning of underlying
/// @dev extends ierc20 upgradable
contract CappedGovToken is Initializable, OwnableUpgradeable, ERC20Upgradeable {
  using SafeERC20Upgradeable for ERC20Upgradeable;

  ERC20Upgradeable public _underlying;
  IVaultController public _vaultController;
  VotingVaultController public _votingVaultController;

  // in actual units
  uint256 public _cap;

  /// @notice initializer for contract
  /// @param name_ name of capped token
  /// @param symbol_ symbol of capped token
  /// @param underlying_ the address of underlying
  /// @param vaultController_ the address of vault controller
  /// @param votingVaultController_ the address of voting vault controller
  function initialize(
    string memory name_,
    string memory symbol_,
    address underlying_,
    address vaultController_,
    address votingVaultController_
  ) public initializer {
    __Ownable_init();
    __ERC20_init(name_, symbol_);
    _underlying = ERC20Upgradeable(underlying_);

    _vaultController = IVaultController(vaultController_);
    _votingVaultController = VotingVaultController(votingVaultController_);
  }

  /// @notice 18 decimal erc20 spec should have been written into the fucking standard
  function decimals() public pure override returns (uint8) {
    return 18;
  }

  /// @notice get the Cap
  /// @return cap uint256
  function getCap() public view returns (uint256) {
    return _cap;
  }

  /// @notice set the Cap
  function setCap(uint256 cap_) external onlyOwner {
    _cap = cap_;
  }

  function checkCap(uint256 amount_) internal view {
    require(ERC20Upgradeable.totalSupply() + amount_ <= _cap, "cap reached");
  }

  /// @notice deposit _underlying to mint CappedToken
  /// @param amount of underlying to deposit
  /// @param vaultId recipient vault of tokens
  function deposit(uint256 amount, uint96 vaultId) public {
    require(amount > 0, "Cannot deposit 0");
    VotingVault votingVault = VotingVault(_votingVaultController.votingVaultAddress(vaultId));
    require(address(votingVault) != address(0x0), "invalid voting vault");
    IVault vault = IVault(_vaultController.vaultAddress(vaultId));
    require(address(vault) != address(0x0), "invalid vault");
    // check cap
    checkCap(amount);
    // check allowance and ensure transfer success
    uint256 allowance = _underlying.allowance(_msgSender(), address(this));
    require(allowance >= amount, "Insufficient Allowance");
    // mint this token, the collateral token, to the vault
    ERC20Upgradeable._mint(address(vault), amount);
    // send the actual underlying to the voting vault for the vault
    _underlying.safeTransferFrom(_msgSender(), address(votingVault), amount);
  }

  function transfer(address recipient, uint256 amount) public override returns (bool) {
    uint96 vault_id = _votingVaultController.vaultId(_msgSender());
    // only vaults will ever send this. only vaults will ever hold this token.
    require(vault_id > 0, "only vaults");
    // get the corresponding voting vault
    address voting_vault_address = _votingVaultController.votingVaultAddress(vault_id);
    require(voting_vault_address != address(0x0), "no voting vault");
    // burn the collateral tokens from the sender, which is the vault that holds the collateral tokens
    ERC20Upgradeable._burn(_msgSender(), amount);
    // move the underlying tokens from voting vault to the target
    _votingVaultController.retrieveUnderlying(amount, voting_vault_address, recipient);
    return true;
  }

  function transferFrom(
    address /*sender*/,
    address /*recipient*/,
    uint256 /*amount*/
  ) public pure override returns (bool) {
    // allowances are never granted, as the VotingVault does not grant allowances.
    // this function is therefore always uncallable and so we will just return false
    return false;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../vault/VaultBPT.sol";
import "../controller/VotingVaultController.sol";
import "../controller/NftVaultController.sol";

import "../IVaultController.sol";
import "../IVault.sol";

//import "../../_external/IERC721Metadata.sol";
import "../../_external/uniswap/INonfungiblePositionManager.sol";
import "../../_external/openzeppelin/ERC721Upgradeable.sol";
import "../../_external/openzeppelin/OwnableUpgradeable.sol";
import "../../_external/openzeppelin/Initializable.sol";

//not sure this is a thing
//import "../../_external/openzeppelin/SafeERC721Upgradeable.sol";

/// @title Univ3CollateralToken
/// @notice creates a token worth 1e18 with 18 visible decimals for vaults to consume
/// @dev extends ierc20 upgradable
contract Univ3CollateralToken is Initializable, OwnableUpgradeable, ERC721Upgradeable {
  //using SafeERC721Upgradeable for ERC721Upgradeable;

  ERC721Upgradeable public _underlying;
  IVaultController public _vaultController;
  NftVaultController public _nftVaultController;

  INonfungiblePositionManager public _univ3NftPositions;

  mapping(address => uint256[]) public _underlyingOwners;

  bool private locked;

  modifier nonReentrant() {
    locked = true;
    _;
    locked = false;
  }

  /// @notice initializer for contract
  /// @param name_ name of capped token
  /// @param symbol_ symbol of capped token
  /// @param underlying_ the address of underlying
  /// @param vaultController_ the address of vault controller
  /// @param nftVaultController_ the address of voting vault controller
  function initialize(
    string memory name_,
    string memory symbol_,
    address underlying_,
    address vaultController_,
    address nftVaultController_,
    address univ3NftPositions_
  ) public initializer {
    __Ownable_init();
    __ERC721_init(name_, symbol_);
    _underlying = ERC721Upgradeable(underlying_);

    _vaultController = IVaultController(vaultController_);
    _nftVaultController = NftVaultController(nftVaultController_);
    _univ3NftPositions = INonfungiblePositionManager(univ3NftPositions_);

    locked = false;
  }

  /// @notice 18 decimal erc20 spec should have been written into the fucking standard
  function decimals() public pure /**override */ returns (uint8) {
    return 18;
  }

  /// @notice deposit _underlying to mint CappedToken
  /// @notice gaugeToken is fungible 1:1 with underlying BPT
  /// @param tokenId //amount of underlying to deposit
  /// @param vaultId recipient vault of tokens
  /// @param stake deposit + stake in 1 TX, for auraBal or aura LPs
  function deposit(uint256 tokenId, uint96 vaultId, bool stake) public nonReentrant {
    address univ3_vault_address = _nftVaultController.NftVaultAddress(vaultId);
    require(address(univ3_vault_address) != address(0x0), "invalid voting vault");

    // transfer position
    // todo
    //_underlying.safeTransferFrom(_msgSender(), address(univ3_vault_address), amount);
  }

  // transfer withdraws every single NFT from the vault.
  // TODO: thie means no partial liquidations/withdraws. We could possibly support partial withdraws -
  // but it would mean changing our liquidation logic even more. Let's think about this.
  // basically we can code the token id into the amount, but we would need to make sure that
  // liquidations always move an amount that is not a tokenId to ensure no exploit is possible.
  function transfer(address recipient, uint256 amount) public /**override */ returns (bool) {
    uint96 vault_id = _nftVaultController.vaultId(_msgSender());
    // only vaults will ever send this. only vaults will ever need to call this function
    require(vault_id > 0, "only vaults");
    // get the corresponding voting vault
    address univ3_vault_address = _nftVaultController.NftVaultAddress(vault_id);
    require(univ3_vault_address != address(0x0), "no univ3 vault");

    // move every nft from the nft vault to the target
    for (uint256 i; i < _underlyingOwners[recipient].length; i++) {
      uint256 tokenId = _underlyingOwners[recipient][i];
      // no need to do the check here when removing from list
      remove_from_list(univ3_vault_address, tokenId);
      _nftVaultController.retrieveUnderlying(tokenId, univ3_vault_address, recipient);
    }
    return true;
  }

  function transferFrom(
    address /*sender*/,
    address /*recipient*/,
    uint256 /*amount*/
  ) public pure override /**no bool return for erc721 returns (bool) */ {
    // allowances are never granted, as the VotingVault does not grant allowances.
    // this function is therefore always uncallable and so we will just return false
    //return false; //no return for 721
  }

  // TODO: will solidity be smart enough to gas optimize for us here? if not, we need to make sure this function is as cheap as we can get it
  function balanceOf(address account) public view override returns (uint256) {
    // iterate across each user balance
    uint256 totalValue = 0;
    for (uint256 i; i < _underlyingOwners[account].length; i++) {
      //TODO: investigate possible gas improvement through passing multiple tokenids  instead of doing them one by one
      // this would allow us to cache values from historical calculations, but im not sure if that would even save anything
      totalValue = totalValue + get_token_value(_underlyingOwners[account][i]);
    }
    return totalValue;
  }

  function get_token_value(uint256 tokenid) internal view returns (uint256) {
    try _univ3NftPositions.positions(tokenid) returns (
      uint96 nonce,
      address operator,
      address token0,
      address token1,
      uint24 fee,
      int24 tickLower,
      int24 tickUpper,
      uint128 liquidity,
      uint256 feeGrowthInside0LastX128,
      uint256 feeGrowthInside1LastX128,
      uint128 tokensOwed0,
      uint128 tokensOwed1
    ) {
      // TODO: use token0 and token1 with the oraclemaster, along with their tokensOwed to calculate their collateral value
    } catch (bytes memory /*lowLevelData*/) {
      // return 0 if the position has somehow become invalid
      return 0;
    }
  }

  // Utility functions for mutating the address tokenid list
  function add_to_list(address recipient, uint256 tokenid) internal {
    for (uint256 i; i < _underlyingOwners[recipient].length; i++) {
      // replace 0 first
      if (_underlyingOwners[recipient][i] == 0) {
        _underlyingOwners[recipient][i] = tokenid;
        return;
      }
      _underlyingOwners[recipient][i] = (tokenid);
    }
  }

  function remove_from_list(address recipient, uint256 tokenid) internal returns (bool) {
    for (uint256 i; i < _underlyingOwners[recipient].length; i++) {
      if (_underlyingOwners[recipient][i] == tokenid) {
        _underlyingOwners[recipient][i] = 0;
        return true;
      }
    }
    return false;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";

interface IBalancerFeed {
  enum Variable {
    PAIR_PRICE,
    BPT_PRICE,
    INVARIANT
  }

  struct OracleAverageQuery {
    Variable variable;
    uint256 secs;
    uint256 ago;
  }

  //this returns the deviation from the true peg
  function getTimeWeightedAverage(OracleAverageQuery[] memory queries) external view returns (uint256[] memory);
}

interface IRateProvider {
  //this returns the true peg
  function getRate() external view returns (uint256);
}

/*****************************************
 *
 * This relay gets a USD TWAP for a wrapped asset from a balancer MetaStablePool
 *
 */

contract BalancerPeggedAssetRelay is IOracleRelay {
  uint256 public immutable _multiply;
  uint256 public immutable _divide;
  uint256 public immutable _secs;

  IBalancerFeed private immutable _priceFeed;
  IRateProvider private immutable _rateProvider;
  IOracleRelay public constant ethOracle = IOracleRelay(0x22B01826063564CBe01Ef47B96d623b739F82Bf2);

  /**
   * @param lookback - How many seconds to look back when generating TWAP
   * @param pool_address - Balancer MetaStablePool address
   * @param rateProvider - Provides the rate for the peg, typically can be found at @param pool_address.getRateProviders()
   */
  constructor(uint32 lookback, address pool_address, address rateProvider, uint256 mul, uint256 div) {
    _priceFeed = IBalancerFeed(pool_address);
    _rateProvider = IRateProvider(rateProvider);
    _multiply = mul;
    _divide = div;
    _secs = lookback;
  }

  function currentValue() external view override returns (uint256) {
    uint256 peg = _rateProvider.getRate();
    uint256 deviation = getDeviation();

    uint256 priceInEth = (deviation * peg) / 1e18;
    uint256 ethPrice = ethOracle.currentValue();

    ///@notice switch to this to invert the price if needed, such that
    // ethPrice == assets per 1 eth
    // return divide(ethPrice, priceInEth, 18);

    ///ethPrice == eth per 1 asset
    return (ethPrice * priceInEth) / 1e18;
  }

  function getDeviation() private view returns (uint256) {
    IBalancerFeed.OracleAverageQuery[] memory inputs = new IBalancerFeed.OracleAverageQuery[](1);

    inputs[0] = IBalancerFeed.OracleAverageQuery({
      variable: IBalancerFeed.Variable.PAIR_PRICE,
      secs: _secs,
      ago: _secs
    });

    uint256 result = _priceFeed.getTimeWeightedAverage(inputs)[0];
    return result;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";
import "../../_external/PRBMath/PRBMathSD59x18.sol";

/*****************************************
 *
 * This relay gets a USD price for a Balancer BPT LP token from a weighted pool
 *
 */

interface IBalancerPool {
  function totalSupply() external view returns (uint256);

  function getLastInvariant() external view returns (uint256);

  function getNormalizedWeights() external view returns (uint256[] memory);
}

contract BPT_WEIGHTED_ORACLE is IOracleRelay {
  using PRBMathSD59x18 for *;

  IBalancerPool public immutable _priceFeed;
  mapping(address => IOracleRelay) public _assetOracles;
  address[] public _tokens;

  /**
   * @param priceFeed - Balancer weighted pool address
   * @param tokens order must match the corrisponding weights of getNormalizedWeights()
   * @param oracles must be in the same order as @param tokens
   */
  constructor(IBalancerPool priceFeed, address[] memory tokens, address[] memory oracles) {
    _priceFeed = priceFeed;
    _tokens = tokens;

    //register oracles
    for (uint256 i = 0; i < _tokens.length; i++) {
      _assetOracles[tokens[i]] = IOracleRelay(oracles[i]);
    }
  }

  function currentValue() external view override returns (uint256) {
    uint256[] memory weights = _priceFeed.getNormalizedWeights();

    int256 totalPi = PRBMathSD59x18.fromInt(1e18);

    uint256[] memory prices = new uint256[](_tokens.length);

    for (uint256 i = 0; i < _tokens.length; i++) {
      prices[i] = _assetOracles[_tokens[i]].currentValue();

      int256 val = int256(prices[i]).div(int256(weights[i]));

      int256 indivPi = val.pow(int256(weights[i]));

      totalPi = totalPi.mul(indivPi);
    }

    int256 invariant = int256(_priceFeed.getLastInvariant());
    int256 numerator = totalPi.mul(invariant);
    return uint256((numerator.toInt().div(int256(_priceFeed.totalSupply()))));
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";
import "../../_external/IERC20.sol";
import "../../_external/balancer/IBalancerVault.sol";

interface IBalancerPool {
  function getPoolId() external view returns (bytes32);

  function totalSupply() external view returns (uint256);

  function getLastInvariant() external view returns (uint256, uint256);

  function getRate() external view returns (uint256);
}

/*****************************************
 *
 * This relay gets a USD price for BPT LP token from a balancer MetaStablePool or StablePool
 * Utilizing the minSafePrice method, this logic should slightly undervalue the BPT
 * This method should be used as a secondary oracle in a multiple oracle system
 */

contract BPTminSafePriceRelay is IOracleRelay {
  IBalancerPool public immutable _priceFeed;
  address public immutable tokenA;
  address public immutable tokenB;

  mapping(address => IOracleRelay) public assetOracles;

  /**
   * @param pool_address - Balancer StablePool or MetaStablePool address
   * @param _tokens should be length 2 and contain both underlying assets for the pool
   * @param _oracles shoulb be length 2 and contain a safe external on-chain oracle for each @param _tokens in the same order
   * @notice the quotient of @param widthNumerator and @param widthDenominator should be the percent difference the exchange rate
   * is able to diverge from the expected exchange rate derived from just the external oracles
   */
  constructor(
    address pool_address,
    address[] memory _tokens,
    address[] memory _oracles
  ) {
    _priceFeed = IBalancerPool(pool_address);

    tokenA = _tokens[0];
    tokenB = _tokens[1];

    //register oracles
    for (uint256 i = 0; i < _tokens.length; i++) {
      assetOracles[_tokens[i]] = IOracleRelay(_oracles[i]);
    }
  }

  function currentValue() external view override returns (uint256 minSafePrice) {
    //get pMin
    uint256 p0 = assetOracles[tokenA].currentValue();
    uint256 p1 = assetOracles[tokenB].currentValue();

    uint256 max = p0 > p1 ? p0 : p1;
    uint256 min = p1 != max ? p1 : p0;

    uint256 rate = _priceFeed.getRate();

    minSafePrice = (rate * min) / 1e18;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";
import "../../_external/IERC20.sol";
import "../../_external/balancer/IBalancerVault.sol";

interface IBalancerPool {
  function getPoolId() external view returns (bytes32);

  function totalSupply() external view returns (uint256);

  function getLastInvariant() external view returns (uint256, uint256);
}

/*****************************************
 *
 * This relay gets a USD price for BPT LP token from a balancer MetaStablePool or StablePool
 * Comparing the results of outGivenIn to known safe oracles for the underlying assets,
 * we can safely determine if manipulation has transpired.
 * After confirming that the naive price is safe, we return the naive price.
 */

contract BPTstablePoolOracle is IOracleRelay {
  bytes32 public immutable _poolId;

  uint256 public immutable _widthNumerator;
  uint256 public immutable _widthDenominator;

  IBalancerPool public immutable _priceFeed;

  mapping(address => IOracleRelay) public assetOracles;

  //Balancer Vault
  IBalancerVault public immutable VAULT;

  /**
   * @param pool_address - Balancer StablePool or MetaStablePool address
   * @param balancerVault is the address for the Balancer Vault contract
   * @param _tokens should be length 2 and contain both underlying assets for the pool
   * @param _oracles shoulb be length 2 and contain a safe external on-chain oracle for each @param _tokens in the same order
   * @notice the quotient of @param widthNumerator and @param widthDenominator should be the percent difference the exchange rate
   * is able to diverge from the expected exchange rate derived from just the external oracles
   */
  constructor(
    address pool_address,
    IBalancerVault balancerVault,
    address[] memory _tokens,
    address[] memory _oracles,
    uint256 widthNumerator,
    uint256 widthDenominator
  ) {
    _priceFeed = IBalancerPool(pool_address);

    _poolId = _priceFeed.getPoolId();

    VAULT = balancerVault;

    //register oracles
    for (uint256 i = 0; i < _tokens.length; i++) {
      assetOracles[_tokens[i]] = IOracleRelay(_oracles[i]);
    }

    _widthNumerator = widthNumerator;
    _widthDenominator = widthDenominator;
  }

  function currentValue() external view override returns (uint256) {
    //check for reentrancy, further protects against manipulation
    ensureNotInVaultContext();

    (IERC20[] memory tokens, uint256[] memory balances /**uint256 lastChangeBlock */, ) = VAULT.getPoolTokens(_poolId);

    uint256 tokenAmountIn = 1000e18;

    uint256 outGivenIn = getOutGivenIn(balances, tokenAmountIn);

    (uint256 calcedRate, uint256 expectedRate) = getExchangeRates(
      outGivenIn,
      tokenAmountIn,
      assetOracles[address(tokens[0])].currentValue(),
      assetOracles[address(tokens[1])].currentValue()
    );

    verifyExchangeRate(expectedRate, calcedRate);

    uint256 naivePrice = getNaivePrice(tokens, balances);

    return naivePrice;
  }

  /*******************************GET & CHECK NAIVE PRICE********************************/
  ///@notice get the naive price by dividing the TVL/total BPT supply
  function getNaivePrice(IERC20[] memory tokens, uint256[] memory balances) internal view returns (uint256 naivePrice) {
    uint256 naiveTVL = 0;
    for (uint256 i = 0; i < tokens.length; i++) {
      naiveTVL += ((assetOracles[address(tokens[i])].currentValue() * balances[i]));
    }
    naivePrice = naiveTVL / _priceFeed.totalSupply();
    require(naivePrice > 0, "invalid naive price");
  }

  ///@notice ensure the exchange rate is within the expected range
  ///@notice ensuring the price is in bounds prevents price manipulation
  function verifyExchangeRate(uint256 expectedRate, uint256 outGivenInRate) internal view {
    uint256 delta = percentChange(expectedRate, outGivenInRate);
    uint256 buffer = divide(_widthNumerator, _widthDenominator, 18);

    require(delta < buffer, "Price out of bounds");
  }

  /*******************************OUT GIVEN IN********************************/
  function getOutGivenIn(uint256[] memory balances, uint256 tokenAmountIn) internal view returns (uint256 outGivenIn) {
    (uint256 v, uint256 amp) = _priceFeed.getLastInvariant();
    uint256 idxIn = 0;
    uint256 idxOut = 1;

    //first calculate the balances, math doesn't work with reported balances on their own
    uint256[] memory calcedBalances = new uint256[](2);
    calcedBalances[0] = _getTokenBalanceGivenInvariantAndAllOtherBalances(amp, balances, v, 0);
    calcedBalances[1] = _getTokenBalanceGivenInvariantAndAllOtherBalances(amp, balances, v, 1);

    //get the ending balance for output token (always index 1)
    uint256 finalBalanceOut = _calcOutGivenIn(amp, calcedBalances, idxIn, idxOut, tokenAmountIn, v);

    //outGivenIn is a function of the actual starting balance, not the calculated balance
    outGivenIn = ((balances[idxOut] - finalBalanceOut) - 1);
  }

  // Computes how many tokens can be taken out of a pool if `tokenAmountIn` are sent, given the current balances.
  // The amplification parameter equals: A n^(n-1)
  // The invariant should be rounded up.
  function _calcOutGivenIn(
    uint256 amplificationParameter,
    uint256[] memory balances,
    uint256 tokenIndexIn,
    uint256 tokenIndexOut,
    uint256 tokenAmountIn,
    uint256 invariant
  ) internal pure returns (uint256) {
    /**************************************************************************************************************
    // outGivenIn token x for y - polynomial equation to solve                                                   //
    // ay = amount out to calculate                                                                              //
    // by = balance token out                                                                                    //
    // y = by - ay (finalBalanceOut)                                                                             //
    // D = invariant                                               D                     D^(n+1)                 //
    // A = amplification coefficient               y^2 + ( S - ----------  - D) * y -  ------------- = 0         //
    // n = number of tokens                                    (A * n^n)               A * n^2n * P              //
    // S = sum of final balances but y                                                                           //
    // P = product of final balances but y                                                                       //
    **************************************************************************************************************/

    balances[tokenIndexIn] = balances[tokenIndexIn] + (tokenAmountIn);

    uint256 finalBalanceOut = _getTokenBalanceGivenInvariantAndAllOtherBalances(
      amplificationParameter,
      balances,
      invariant,
      tokenIndexOut
    );
    balances[tokenIndexIn] = balances[tokenIndexIn] - tokenAmountIn;

    //we simply return finalBalanceOut here, and get outGivenIn elsewhere
    return finalBalanceOut;
    /**
    if (balances[tokenIndexOut] > finalBalanceOut) {
      return sub(sub(balances[tokenIndexOut], finalBalanceOut), 1);
    } else {
      return 0;
    }
     */
  }

  // This function calculates the balance of a given token (tokenIndex)
  // given all the other balances and the invariant
  function _getTokenBalanceGivenInvariantAndAllOtherBalances(
    uint256 amplificationParameter,
    uint256[] memory balances,
    uint256 invariant,
    uint256 tokenIndex
  ) internal pure returns (uint256) {
    // Rounds result up overall
    uint256 _AMP_PRECISION = 1e3;

    uint256 ampTimesTotal = amplificationParameter * balances.length;
    uint256 sum = balances[0];
    uint256 P_D = balances[0] * balances.length;
    for (uint256 j = 1; j < balances.length; j++) {
      P_D = (((P_D * balances[j]) * balances.length) / invariant);
      sum = sum + balances[j];
    }
    // No need to use safe math, based on the loop above `sum` is greater than or equal to `balances[tokenIndex]`
    sum = sum - balances[tokenIndex];

    uint256 inv2 = (invariant * invariant);
    // We remove the balance from c by multiplying it
    uint256 c = ((divUp(inv2, (ampTimesTotal * P_D)) * _AMP_PRECISION) * balances[tokenIndex]);
    uint256 b = sum + ((invariant / ampTimesTotal) * _AMP_PRECISION);

    // We iterate to find the balance
    uint256 prevTokenBalance = 0;
    // We multiply the first iteration outside the loop with the invariant to set the value of the
    // initial approximation.
    uint256 tokenBalance = divUp((inv2 + c), (invariant + b));

    for (uint256 i = 0; i < 255; i++) {
      prevTokenBalance = tokenBalance;

      uint256 numerator = (tokenBalance * tokenBalance) + c;
      uint256 denominator = ((tokenBalance * 2) + b) - invariant;

      tokenBalance = divUp(numerator, denominator);
      if (tokenBalance > prevTokenBalance) {
        if (tokenBalance - prevTokenBalance <= 1) {
          return tokenBalance;
        }
      } else if (prevTokenBalance - tokenBalance <= 1) {
        return tokenBalance;
      }
    }
    revert("STABLE_GET_BALANCE_DIDNT_CONVERGE");
  }

  //https://github.com/balancer/balancer-v2-monorepo/pull/2418/files#diff-36f155e03e561d19a594fba949eb1929677863e769bd08861397f4c7396b0c71R37
  function ensureNotInVaultContext() internal view {
        // Perform the following operation to trigger the Vault's reentrancy guard:
        //
        // IVault.UserBalanceOp[] memory noop = new IVault.UserBalanceOp[](0);
        // _vault.manageUserBalance(noop);
        //
        // However, use a static call so that it can be a view function (even though the function is non-view).
        // This allows the library to be used more widely, as some functions that need to be protected might be
        // view.
        //
        // This staticcall always reverts, but we need to make sure it doesn't fail due to a re-entrancy attack.
        // Staticcalls consume all gas forwarded to them on a revert. By default, almost the entire available gas
        // is forwarded to the staticcall, causing the entire call to revert with an 'out of gas' error.
        //
        // We set the gas limit to 100k, but the exact number doesn't matter because view calls are free, and non-view
        // calls won't waste the entire gas limit on a revert. `manageUserBalance` is a non-reentrant function in the
        // Vault, so calling it invokes `_enterNonReentrant` in the `ReentrancyGuard` contract, reproduced here:
        //
        //    function _enterNonReentrant() private {
        //        // If the Vault is actually being reentered, it will revert in the first line, at the `_require` that
        //        // checks the reentrancy flag, with "BAL#400" (corresponding to Errors.REENTRANCY) in the revertData.
        //        // The full revertData will be: `abi.encodeWithSignature("Error(string)", "BAL#400")`.
        //        _require(_status != _ENTERED, Errors.REENTRANCY);
        //
        //        // If the Vault is not being reentered, the check above will pass: but it will *still* revert,
        //        // because the next line attempts to modify storage during a staticcall. However, this type of
        //        // failure results in empty revertData.
        //        _status = _ENTERED;
        //    }
        //
        // So based on this analysis, there are only two possible revertData values: empty, or abi.encoded BAL#400.
        //
        // It is of course much more bytecode and gas efficient to check for zero-length revertData than to compare it
        // to the encoded REENTRANCY revertData.
        //
        // While it should be impossible for the call to fail in any other way (especially since it reverts before
        // `manageUserBalance` even gets called), any other error would generate non-zero revertData, so checking for
        // empty data guards against this case too.

        (, bytes memory revertData) = address(VAULT).staticcall{ gas: 100_000 }(
            abi.encodeWithSelector(VAULT.manageUserBalance.selector, 0)
        );

        require(revertData.length == 0, "Errors.REENTRANCY");
    }

  /*******************************PURE MATH FUNCTIONS********************************/
  ///@notice get exchange rates
  function getExchangeRates(
    uint256 outGivenIn,
    uint256 tokenAmountIn,
    uint256 price0,
    uint256 price1
  ) internal pure returns (uint256 calcedRate, uint256 expectedRate) {
    expectedRate = divide(price1, price0, 18);

    uint256 numerator = divide(outGivenIn * price1, 1e18, 18);

    uint256 denominator = divide((tokenAmountIn * price0), 1e18, 18);

    calcedRate = divide(numerator, denominator, 18);
  }

  ///@notice get the percent deviation from a => b as a decimal e18
  function percentChange(uint256 a, uint256 b) internal pure returns (uint256 delta) {
    uint256 max = a > b ? a : b;
    uint256 min = b != max ? b : a;
    delta = divide((max - min), min, 18);
  }

  ///@notice floating point division at @param factor scale
  function divide(uint256 numerator, uint256 denominator, uint256 factor) internal pure returns (uint256 result) {
    uint256 q = (numerator / denominator) * 10 ** factor;
    uint256 r = ((numerator * 10 ** factor) / denominator) % 10 ** factor;

    return q + r;
  }

  function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 product = a * b;
    require(a == 0 || product / a == b, "overflow");

    return product / 1e18;
  }

  function divUp(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0, "divUp: Zero division");

    if (a == 0) {
      return 0;
    } else {
      return 1 + (a - 1) / b;
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";
import "../../_external/chainlink/IAggregator.sol";

/// @title Oracle that wraps a chainlink oracle
/// @notice The oracle returns (chainlinkPrice) * mul / div
contract ChainlinkOracleRelay is IOracleRelay {
  IAggregator private immutable _aggregator;

  uint256 public immutable _multiply;
  uint256 public immutable _divide;

  /// @notice all values set at construction time
  /// @param  feed_address address of chainlink feed
  /// @param mul numerator of scalar
  /// @param div denominator of scalar
  constructor(address feed_address, uint256 mul, uint256 div) {
    _aggregator = IAggregator(feed_address);
    _multiply = mul;
    _divide = div;
  }

  /// @notice the current reported value of the oracle
  /// @return the current value
  /// @dev implementation in getLastSecond
  function currentValue() external view override returns (uint256) {
    return getLastSecond();
  }

  function getLastSecond() private view returns (uint256) {
    int256 latest = _aggregator.latestAnswer();
    require(latest > 0, "chainlink: px < 0");
    uint256 scaled = (uint256(latest) * _multiply) / _divide;
    return scaled;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";

interface IPot {
  function chi() external view returns (uint256);

  function rho() external view returns (uint256);

  function dsr() external view returns (uint256);
}

contract CHI_Oracle is IOracleRelay {
  IPot public immutable pot;
  uint256 private constant ONE = 10 ** 27;

  constructor(IPot _pot) {
    pot = _pot;
  }

  function currentValue() external view override returns (uint256 wad) {
    wad = readDrip() / 1e9;
  }

  /// @notice logic and math pulled directly from the pot contract
  /// https://github.com/makerdao/dss/commit/17187f7d47be2f4c71d218785e1155474bbafe8a
  /// https://etherscan.io/address/0x197e90f9fad81970ba7976f33cbd77088e5d7cf7#code
  function readDrip() internal view returns (uint256 tmp) {
    tmp = rmul(rpow(pot.dsr(), (block.timestamp - pot.rho()), ONE), pot.chi());
  }

  function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = mul(x, y) / ONE;
  }

  function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require(y == 0 || (z = x * y) / y == x);
  }

  function rpow(uint256 x, uint256 n, uint256 base) internal pure returns (uint256 z) {
    assembly {
      switch x
      case 0 {
        switch n
        case 0 {
          z := base
        }
        default {
          z := 0
        }
      }
      default {
        switch mod(n, 2)
        case 0 {
          z := base
        }
        default {
          z := x
        }
        let half := div(base, 2) // for rounding.
        for {
          n := div(n, 2)
        } n {
          n := div(n, 2)
        } {
          let xx := mul(x, x)
          if iszero(eq(div(xx, x), x)) {
            revert(0, 0)
          }
          let xxRound := add(xx, half)
          if lt(xxRound, xx) {
            revert(0, 0)
          }
          x := div(xxRound, base)
          if mod(n, 2) {
            let zx := mul(z, x)
            if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) {
              revert(0, 0)
            }
            let zxRound := add(zx, half)
            if lt(zxRound, zx) {
              revert(0, 0)
            }
            z := div(zxRound, base)
          }
        }
      }
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";

interface IrEethOracleFeed {
  function getEthValue(uint256 _rethAmount) external view returns (uint256);
}

contract OracleRETH is IOracleRelay {
  IrEethOracleFeed public constant _priceFeed = IrEethOracleFeed(0xae78736Cd615f374D3085123A210448E74Fc6393);
  IOracleRelay public constant ethOracle = IOracleRelay(0x22B01826063564CBe01Ef47B96d623b739F82Bf2);

  function currentValue() external view override returns (uint256) {
    uint256 priceInEth = getLastSecond();
    uint256 ethPrice = ethOracle.currentValue();

    return (ethPrice * priceInEth) / 1e18;
  }

  function getLastSecond() private view returns (uint256) {
    return _priceFeed.getEthValue(1e18);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";

/*****************************************
 * This gets USD price on Optimism based on the exchange rate
 * found on the RocketOvmPriceOracle @ 0x1a8F81c256aee9C640e14bB0453ce247ea0DFE6F
 * This is a price ported from mainnet and should not be used as a primary oracle on Optimism
 */
interface IRocketOvmPriceOracle {
  function rate() external view returns (uint256);
}

contract rEthOracleOP is IOracleRelay {
  IRocketOvmPriceOracle public immutable _priceFeed;
  IOracleRelay public immutable _ethOracle;

  constructor(IRocketOvmPriceOracle priceFeed, IOracleRelay ethOracle) {
    _priceFeed = priceFeed;
    _ethOracle = ethOracle;
  }

  function currentValue() external view override returns (uint256) {
    uint256 priceInEth = _priceFeed.rate();
    uint256 ethPrice = _ethOracle.currentValue();

    return (ethPrice * priceInEth) / 1e18;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";
import "../../lending/IVaultController.sol";
import "../IOracleMaster.sol";

import "../../thirdparty/curve/ICurvePoolFeed.sol";

/// @title Oracle that wraps a chainlink oracle
/// @notice The oracle returns (chainlinkPrice) * mul / div
contract StEthOracleRelay is IOracleRelay {
  ICurvePoolFeed private immutable _priceFeed;
  IVaultController public constant VC = IVaultController(0x4aaE9823Fb4C70490F1d802fC697F3ffF8D5CbE3);

  IOracleMaster public _oracle;

  uint256 public immutable _multiply;
  uint256 public immutable _divide;

  /// @notice all values set at construction time
  /// @param  feed_address address of curve feed
  /// @param mul numerator of scalar
  /// @param div denominator of scalar
  constructor(address feed_address, uint256 mul, uint256 div) {
    _priceFeed = ICurvePoolFeed(feed_address);
    _multiply = mul;
    _divide = div;
    _oracle = IOracleMaster(VC.getOracleMaster());
  }

  /// @notice the current reported value of the oracle
  /// @return the current value
  /// @dev implementation in getLastSecond
  function currentValue() external view override returns (uint256) {
    return getLastSecond();
  }

  ///@notice get the price in USD terms, after having converted from ETH terms
  function getLastSecond() private view returns (uint256) {
    (uint256 currentPrice, bool isSafe) = _priceFeed.current_price();
    require(isSafe, "Curve Oracle: Not Safe");

    uint256 ethPrice = _oracle.getLivePrice(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    currentPrice = (currentPrice * ethPrice) / 1e18;

    require(currentPrice > 0, "Curve: px < 0");
    uint256 scaled = (uint256(currentPrice) * _multiply) / _divide;
    return scaled;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";

import "../../_external/uniswap/IUniswapV2Pair.sol";
import "../../_external/uniswap/UniswapV2OracleLibrary.sol";

/// @title Oracle that wraps a univ3 pool
/// @notice The oracle returns (univ3) * mul / div
contract UniswapV2OracleRelay is IOracleRelay {
  uint256 public immutable _mul;
  uint256 public immutable _div;
  uint256 public constant PERIOD = 10;

  IUniswapV2Pair public immutable _pair;
  address public immutable _token0;
  address public immutable _token1;
  address public immutable _targetToken;

  uint256 public price0CumulativeLast;
  uint256 public price1CumulativeLast;
  uint32 public blockTimestampLast;

  // NOTE: binary fixed point numbers
  // range: [0, 2**112 - 1]
  // resolution: 1 / 2**112
  uint224 public price0Average;
  uint224 public price1Average;

  /// @notice all values set at construction time

  ///@param targetToken is the token we want the price of, in terms of the other token
  constructor(IUniswapV2Pair pair, address targetToken, uint256 mul, uint256 div) {
    _mul = mul;
    _div = div;

    _targetToken = targetToken;

    _pair = pair;
    _token0 = _pair.token0();
    _token1 = _pair.token1();
    price0CumulativeLast = _pair.price0CumulativeLast();
    price1CumulativeLast = _pair.price1CumulativeLast();
    (, , blockTimestampLast) = _pair.getReserves();
  }

  function update() external {
    (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = UniswapV2OracleLibrary
      .currentCumulativePrices(address(_pair));
    uint32 timeElapsed = blockTimestamp - blockTimestampLast;

    require(timeElapsed >= PERIOD, "time elapsed < min period");

    // NOTE: overflow is desired
    /*
        |----b-------------------------a---------|
        0                                     2**256 - 1
        b - a is preserved even if b overflows
        */
    // NOTE: uint -> uint224 cuts off the bits above uint224
    // max uint
    // 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    // max uint244
    // 0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    price0Average = uint224((price0Cumulative - price0CumulativeLast) / timeElapsed);
    price1Average = uint224((price1Cumulative - price1CumulativeLast) / timeElapsed);

    price0CumulativeLast = price0Cumulative;
    price1CumulativeLast = price1Cumulative;
    blockTimestampLast = blockTimestamp;
  }

  /// @notice the current reported value of the oracle
  /// @return the current value
  /// @dev implementation in getLastSecond
  function currentValue() external view override returns (uint256) {
    return getLastSeconds();
  }

  function getLastSeconds() private view returns (uint256 price) {
    require(_targetToken == _token0 || _targetToken == _token1, "invalid token");
    if (_targetToken == _token0) {
      price = (price0Average * 1e18) >> 112;
    } else {
      price = (price1Average * 1e18) >> 112;
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";
import "../../_external/uniswap/IUniswapV3PoolDerivedState.sol";
import "../../_external/uniswap/TickMath.sol";

/// @title Oracle that wraps a univ3 pool
/// @notice This oracle is for tokens that do not have a stable Uniswap V3 pair against USDC
/// if quote_token_is_token0 == true, then the reciprocal is returned
/// quote_token refers to the token we are comparing to, so for an Aave price in ETH, Aave is the target and Eth is the quote
contract UniswapV3OPTokenOracleRelay is IOracleRelay {
  bool public immutable _quoteTokenIsToken0;
  IUniswapV3PoolDerivedState public immutable _pool;
  uint32 public immutable _lookback;

  uint256 public immutable _mul;
  uint256 public immutable _div;

  IOracleRelay public immutable _ethOracle;

  /// @notice all values set at construction time
  /// @param lookback how many seconds to twap for
  /// @param  pool_address address of chainlink feed
  /// @param quote_token_is_token0 true if eth is token 0, or false if eth is token 1
  /// @param mul numerator of scalar
  /// @param div denominator of scalar
  constructor(uint32 lookback, IOracleRelay ethOracle, address pool_address, bool quote_token_is_token0, uint256 mul, uint256 div) {
    _lookback = lookback;
    _ethOracle = ethOracle;
    _mul = mul;
    _div = div;
    _quoteTokenIsToken0 = quote_token_is_token0;
    _pool = IUniswapV3PoolDerivedState(pool_address);
  }

  /// @notice the current reported value of the oracle
  /// @return usdPrice - the price in USD terms
  /// @dev implementation in getLastSeconds
  function currentValue() external view override returns (uint256) {
    uint256 priceInEth = getLastSeconds(_lookback);

    //get price of eth to convert priceInEth to USD terms
    uint256 ethPrice = _ethOracle.currentValue();

    return (ethPrice * priceInEth) / 1e18;
  }

  function getLastSeconds(uint32 tickTimeDifference) private view returns (uint256 price) {
    int56[] memory tickCumulatives;
    uint32[] memory input = new uint32[](2);
    input[0] = tickTimeDifference;
    input[1] = 0;

    (tickCumulatives, ) = _pool.observe(input);

    int56 tickCumulativeDifference = tickCumulatives[0] - tickCumulatives[1];
    bool tickNegative = tickCumulativeDifference < 0;

    uint56 tickAbs;

    if (tickNegative) {
      tickAbs = uint56(-tickCumulativeDifference);
    } else {
      tickAbs = uint56(tickCumulativeDifference);
    }

    uint56 bigTick = tickAbs / tickTimeDifference;
    require(bigTick < 887272, "Tick time diff fail");
    int24 tick;
    if (tickNegative) {
      tick = -int24(int56(bigTick));
    } else {
      tick = int24(int56(bigTick));
    }

    // we use 1e18 bc this is what we're going to use in exp
    // basically, you need the "price" amount of the quote in order to buy 1 base
    // or, 1 base is worth this much quote;

    price = (1e9 * ((uint256(TickMath.getSqrtRatioAtTick(tick))))) / (2 ** (2 * 48));

    price = price * price;

    if (!_quoteTokenIsToken0) {
      price = (1e18 * 1e18) / price;
    }

    price = (price * _mul) / _div;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";
import "../../_external/uniswap/IUniswapV3PoolDerivedState.sol";
import "../../_external/uniswap/TickMath.sol";

/// @title Oracle that wraps a univ3 pool
/// @notice The oracle returns (univ3) * mul / div
/// if quote_token_is_token0 == true, then the reciprocal is returned
contract UniswapV3OracleRelay is IOracleRelay {
  bool public immutable _quoteTokenIsToken0;
  IUniswapV3PoolDerivedState public immutable _pool;
  uint32 public immutable _lookback;

  uint256 public immutable _mul;
  uint256 public immutable _div;

  /// @notice all values set at construction time
  /// @param lookback how many seconds to twap for
  /// @param  pool_address address of chainlink feed
  /// @param quote_token_is_token0 marker for which token to use as quote/base in calculation
  /// @param mul numerator of scalar
  /// @param div denominator of scalar
  constructor(uint32 lookback, address pool_address, bool quote_token_is_token0, uint256 mul, uint256 div) {
    _lookback = lookback;
    _mul = mul;
    _div = div;
    _quoteTokenIsToken0 = quote_token_is_token0;
    _pool = IUniswapV3PoolDerivedState(pool_address);
  }

  /// @notice the current reported value of the oracle
  /// @return the current value
  /// @dev implementation in getLastSecond
  function currentValue() external view override returns (uint256) {
    return getLastSeconds(_lookback);
  }

  function getLastSeconds(uint32 seconds_) private view returns (uint256 price) {
    int56[] memory tickCumulatives;
    uint32[] memory input = new uint32[](2);
    input[0] = seconds_;
    input[1] = 0;

    (tickCumulatives, ) = _pool.observe(input);

    uint32 tickTimeDifference = seconds_;
    int56 tickCumulativeDifference = tickCumulatives[0] - tickCumulatives[1];
    bool tickNegative = tickCumulativeDifference < 0;
    uint56 tickAbs;
    if (tickNegative) {
      tickAbs = uint56(-tickCumulativeDifference);
    } else {
      tickAbs = uint56(tickCumulativeDifference);
    }

    uint56 bigTick = tickAbs / tickTimeDifference;
    require(bigTick < 887272, "Tick time diff fail");
    int24 tick;
    if (tickNegative) {
      tick = -int24(int56(bigTick));
    } else {
      tick = int24(int56(bigTick));
    }

    // we use 1e18 bc this is what we're going to use in exp
    // basically, you need the "price" amount of the quote in order to buy 1 base
    // or, 1 base is worth this much quote;

    price = (1e9 * ((uint256(TickMath.getSqrtRatioAtTick(tick))))) / (2 ** (2 * 48));

    price = price * price;

    if (!_quoteTokenIsToken0) {
      price = (1e18 * 1e18) / price;
    }

    price = (price * _mul) / _div;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";
import "../../_external/uniswap/IUniswapV3PoolDerivedState.sol";
import "../../_external/uniswap/TickMath.sol";

/// @title Oracle that wraps a univ3 pool
/// @notice This oracle is for tokens that do not have a stable Uniswap V3 pair against USDC
/// if quote_token_is_token0 == true, then the reciprocal is returned
/// quote_token refers to the token we are comparing to, so for an Aave price in ETH, Aave is the target and Eth is the quote
contract UniswapV3TokenOracleRelay is IOracleRelay {
  bool public immutable _quoteTokenIsToken0;
  IUniswapV3PoolDerivedState public immutable _pool;
  uint32 public immutable _lookback;

  uint256 public immutable _mul;
  uint256 public immutable _div;

  IOracleRelay public constant ethOracle = IOracleRelay(0x22B01826063564CBe01Ef47B96d623b739F82Bf2);

  /// @notice all values set at construction time
  /// @param lookback how many seconds to twap for
  /// @param  pool_address address of chainlink feed
  /// @param quote_token_is_token0 true if eth is token 0, or false if eth is token 1
  /// @param mul numerator of scalar
  /// @param div denominator of scalar
  constructor(uint32 lookback, address pool_address, bool quote_token_is_token0, uint256 mul, uint256 div) {
    _lookback = lookback;
    _mul = mul;
    _div = div;
    _quoteTokenIsToken0 = quote_token_is_token0;
    _pool = IUniswapV3PoolDerivedState(pool_address);
  }

  /// @notice the current reported value of the oracle
  /// @return usdPrice - the price in USD terms
  /// @dev implementation in getLastSeconds
  function currentValue() external view override returns (uint256) {
    uint256 priceInEth = getLastSeconds(_lookback);

    //get price of eth to convert priceInEth to USD terms
    uint256 ethPrice = ethOracle.currentValue();

    return (ethPrice * priceInEth) / 1e18;
  }

  function getLastSeconds(uint32 tickTimeDifference) private view returns (uint256 price) {
    int56[] memory tickCumulatives;
    uint32[] memory input = new uint32[](2);
    input[0] = tickTimeDifference;
    input[1] = 0;

    (tickCumulatives, ) = _pool.observe(input);

    int56 tickCumulativeDifference = tickCumulatives[0] - tickCumulatives[1];
    bool tickNegative = tickCumulativeDifference < 0;

    uint56 tickAbs;

    if (tickNegative) {
      tickAbs = uint56(-tickCumulativeDifference);
    } else {
      tickAbs = uint56(tickCumulativeDifference);
    }

    uint56 bigTick = tickAbs / tickTimeDifference;
    require(bigTick < 887272, "Tick time diff fail");
    int24 tick;
    if (tickNegative) {
      tick = -int24(int56(bigTick));
    } else {
      tick = int24(int56(bigTick));
    }

    // we use 1e18 bc this is what we're going to use in exp
    // basically, you need the "price" amount of the quote in order to buy 1 base
    // or, 1 base is worth this much quote;

    price = (1e9 * ((uint256(TickMath.getSqrtRatioAtTick(tick))))) / (2 ** (2 * 48));

    price = price * price;

    if (!_quoteTokenIsToken0) {
      price = (1e18 * 1e18) / price;
    }

    price = (price * _mul) / _div;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";

interface IwstETH {
  function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);

  function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);
}

/*****************************************
 *
 * This relay gets a USD price for wstETH using the direct conversion from the wstETH contract
 * and comparing to a known safe price for stETH
 */

contract wstETHRelay is IOracleRelay {
  IOracleRelay public constant stETH_Oracle = IOracleRelay(0x73052741d8bE063b086c4B7eFe084B0CEE50677A);

  IwstETH public wstETH = IwstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

  function currentValue() external view override returns (uint256) {
    uint256 conversionRate = wstETH.getStETHByWstETH(1e18);

    uint256 stETH_Price = stETH_Oracle.currentValue();

    return (stETH_Price * conversionRate) / 1e18;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/// @title OracleMaster Interface
/// @notice Interface for interacting with OracleMaster
interface IOracleMaster {
  // calling function
  function getLivePrice(address token_address) external view returns (uint256);

  // admin functions
  function setRelay(address token_address, address relay_address) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/// @title OracleRelay Interface
/// @notice Interface for interacting with OracleRelay
interface IOracleRelay {
  // returns  price with 18 decimals
  function currentValue() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";

/// @title implementation of compounds' AnchoredView
/// @notice using a main relay and an anchor relay, the AnchoredView
/// ensures that the main relay's price is within some amount of the anchor relay price
/// if not, the call reverts, effectively disabling the oracle & any actions which require it
contract AnchoredViewRelay is IOracleRelay {
  address public _anchorAddress;
  IOracleRelay public _anchorRelay;

  address public _mainAddress;
  IOracleRelay public _mainRelay;

  uint256 public _widthNumerator;
  uint256 public _widthDenominator;

  /// @notice all values set at construction time
  /// @param anchor_address address of OracleRelay to use as anchor
  /// @param main_address address of OracleRelay to use as main
  /// @param widthNumerator numerator of the allowable deviation width
  /// @param widthDenominator denominator of the allowable deviation width
  constructor(address anchor_address, address main_address, uint256 widthNumerator, uint256 widthDenominator) {
    _anchorAddress = anchor_address;
    _anchorRelay = IOracleRelay(anchor_address);

    _mainAddress = main_address;
    _mainRelay = IOracleRelay(main_address);

    _widthNumerator = widthNumerator;
    _widthDenominator = widthDenominator;
  }

  /// @notice returns current value of oracle
  /// @return current value of oracle
  /// @dev implementation in getLastSecond
  function currentValue() external view override returns (uint256) {
    return getLastSecond();
  }

  /// @notice compares the main value (chainlink) to the anchor value (uniswap v3)
  /// @notice the two prices must closely match +-buffer, or it will revert
  function getLastSecond() private view returns (uint256) {
    // get the main price
    uint256 mainValue = _mainRelay.currentValue();
    require(mainValue > 0, "invalid oracle value");

    // get anchor price
    uint256 anchorPrice = _anchorRelay.currentValue();
    require(anchorPrice > 0, "invalid anchor value");

    // calculate buffer
    uint256 buffer = (_widthNumerator * anchorPrice) / _widthDenominator;

    // create upper and lower bounds
    uint256 upperBounds = anchorPrice + buffer;
    uint256 lowerBounds = anchorPrice - buffer;

    // ensure the anchor price is within bounds
    require(mainValue < upperBounds, "anchor too low");
    require(mainValue > lowerBounds, "anchor too high");

    // return mainValue
    return mainValue;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./IOracleMaster.sol";
import "./IOracleRelay.sol";

import "../_external/Ownable.sol";

/// @title An addressbook for oracle relays
/// @notice the oraclemaster is simply an addressbook of address->relay
/// this is so that contracts may use the OracleMaster to call any registered relays.
contract OracleMaster is IOracleMaster, Ownable {
  // mapping of token to address
  mapping(address => address) public _relays;

  /// @notice empty constructor
  constructor() Ownable() {}

  /// @notice gets the current price of the oracle registered for a token
  /// @param token_address address of the token to get value for
  /// @return the value of the token
  function getLivePrice(address token_address) external view override returns (uint256) {
    require(_relays[token_address] != address(0x0), "token not enabled");
    IOracleRelay relay = IOracleRelay(_relays[token_address]);
    uint256 value = relay.currentValue();
    return value;
  }

  /// @notice admin only, sets relay for a token address to the relay addres
  /// @param token_address address of the token
  /// @param relay_address address of the relay
  function setRelay(address token_address, address relay_address) public override onlyOwner {
    _relays[token_address] = relay_address;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

library EthAddressLib {
  /**
   * @dev returns the address used within the protocol to identify ETH
   * @return the address assigned to ETH
   */
  function ethAddress() internal pure returns (address) {
    return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

//import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../_external/IERC20.sol";
//import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IFlashLoanReceiver.sol";
import "./ILendingPoolAddressProvider.sol";
import "./ILendingPool.sol";

abstract contract FlashLoanReceiverBase is IFlashLoanReceiver {
  //using SafeERC20 for IERC20;
  //using SafeMath for uint;

  ILendingPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
  ILendingPool public immutable LENDING_POOL;

  constructor(ILendingPoolAddressesProvider provider) {
    ADDRESSES_PROVIDER = provider;
    LENDING_POOL = ILendingPool(provider.getLendingPool());
  }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title IFlashLoanReceiver interface
 * @notice Interface for the Aave fee IFlashLoanReceiver.
 * @author Aave
 * @dev implement this interface to develop a flashloan-compatible flashLoanReceiver contract
 **/
interface IFlashLoanReceiver {
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ILendingPool {
  function flashLoan(
    address receiverAddress,
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata modes,
    address onBehalfOf,
    bytes calldata params,
    uint16 referralCode
  ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

interface ILendingPoolAddressesProvider {
  function getLendingPool() external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.9;

/**
 * @dev This is an empty interface used to represent either ERC20-conforming token contracts or ETH (using the zero
 * address sentinel value). We're just relying on the fact that `interface` can be used to declare new address-like
 * types.
 *
 * This concept is unrelated to a Pool's Asset Managers.
 */
interface IAsset {
  // solhint-disable-previous-line no-empty-blocks
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.9;

interface IAuthorizer {
  /**
   * @dev Returns true if `account` can perform the action described by `actionId` in the contract `where`.
   */
  function canPerform(bytes32 actionId, address account, address where) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IBaseOracle {
  /// @dev Return the value of the given input as ETH per unit, multiplied by 2**112.
  /// @param token The ERC-20 token to check the value.
  function getETHPx(address token) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.9;

// Inspired by Aave Protocol's IFlashLoanReceiver.

import "../../_external/IERC20.sol";

interface IFlashLoanRecipient {
  /**
   * @dev When `flashLoan` is called on the Vault, it invokes the `receiveFlashLoan` hook on the recipient.
   *
   * At the time of the call, the Vault will have transferred `amounts` for `tokens` to the recipient. Before this
   * call returns, the recipient must have transferred `amounts` plus `feeAmounts` for each token back to the
   * Vault, or else the entire flash loan will revert.
   *
   * `userData` is the same value passed in the `IVault.flashLoan` call.
   */
  function receiveFlashLoan(
    IERC20[] memory tokens,
    uint256[] memory amounts,
    uint256[] memory feeAmounts,
    bytes memory userData
  ) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import "../../_external/IERC20.sol";

import "./IVault.sol";
import "./IAuthorizer.sol";

interface IProtocolFeesCollector {
  event SwapFeePercentageChanged(uint256 newSwapFeePercentage);
  event FlashLoanFeePercentageChanged(uint256 newFlashLoanFeePercentage);

  function withdrawCollectedFees(IERC20[] calldata tokens, uint256[] calldata amounts, address recipient) external;

  function setSwapFeePercentage(uint256 newSwapFeePercentage) external;

  function setFlashLoanFeePercentage(uint256 newFlashLoanFeePercentage) external;

  function getSwapFeePercentage() external view returns (uint256);

  function getFlashLoanFeePercentage() external view returns (uint256);

  function getCollectedFeeAmounts(IERC20[] memory tokens) external view returns (uint256[] memory feeAmounts);

  function getAuthorizer() external view returns (IAuthorizer);

  function vault() external view returns (IBalancerVault);
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.9;

/**
 * @dev Interface for the SignatureValidator helper, used to support meta-transactions.
 */
interface ISignaturesValidator {
  /**
   * @dev Returns the EIP712 domain separator.
   */
  function getDomainSeparator() external view returns (bytes32);

  /**
   * @dev Returns the next nonce used by an address to sign messages.
   */
  function getNextNonce(address user) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.9;

/**
 * @dev Interface for the TemporarilyPausable helper.
 */
interface ITemporarilyPausable {
  /**
   * @dev Emitted every time the pause state changes by `_setPaused`.
   */
  event PausedStateChanged(bool paused);

  /**
   * @dev Returns the current paused state.
   */
  function getPausedState()
    external
    view
    returns (bool paused, uint256 pauseWindowEndTime, uint256 bufferPeriodEndTime);
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma experimental ABIEncoderV2;

import "../../_external/IERC20.sol";
import "./IWETH.sol";
import "./ISignaturesValidator.sol";
import "./ITemporarilyPausable.sol";

import "./IAsset.sol";
import "./IAuthorizer.sol";
//import "./IFlashLoanRecipient.sol";
import "./IProtocolFeesCollector.sol";

pragma solidity ^0.8.9;

/**
 * @dev Full external interface for the Vault core contract - no external or public methods exist in the contract that
 * don't override one of these declarations.
 */
interface IBalancerVault is ISignaturesValidator, ITemporarilyPausable {
  // Generalities about the Vault:
  //
  // - Whenever documentation refers to 'tokens', it strictly refers to ERC20-compliant token contracts. Tokens are
  // transferred out of the Vault by calling the `IERC20.transfer` function, and transferred in by calling
  // `IERC20.transferFrom`. In these cases, the sender must have previously allowed the Vault to use their tokens by
  // calling `IERC20.approve`. The only deviation from the ERC20 standard that is supported ifs functions not returning
  // a boolean value: in these scenarios, a non-reverting call is assumed to be successful.
  //
  // - All non-view functions in the Vault are non-reentrant: calling them while another one is mid-execution (e.g.
  // while execution control is transferred to a token contract during a swap) will result in a revert. View
  // functions can be called in a re-reentrant way, but doing so might cause them to return inconsistent results.
  // Contracts calling view functions in the Vault must make sure the Vault has not already been entered.
  //
  // - View functions revert if referring to either unregistered Pools, or unregistered tokens for registered Pools.

  // Authorizer
  //
  // Some system actions are permissioned, like setting and collecting protocol fees. This permissioning system exists
  // outside of the Vault in the Authorizer contract: the Vault simply calls the Authorizer to check if the caller
  // can perform a given action.

  /**
   * @dev Returns the Vault's Authorizer.
   */
  function getAuthorizer() external view returns (IAuthorizer);

  /**
   * @dev Sets a new Authorizer for the Vault. The caller must be allowed by the current Authorizer to do this.
   *
   * Emits an `AuthorizerChanged` event.
   */
  function setAuthorizer(IAuthorizer newAuthorizer) external;

  /**
   * @dev Emitted when a new authorizer is set by `setAuthorizer`.
   */
  event AuthorizerChanged(IAuthorizer indexed newAuthorizer);

  // Relayers
  //
  // Additionally, it is possible for an account to perform certain actions on behalf of another one, using their
  // Vault ERC20 allowance and Internal Balance. These accounts are said to be 'relayers' for these Vault functions,
  // and are expected to be smart contracts with sound authentication mechanisms. For an account to be able to wield
  // this power, two things must occur:
  //  - The Authorizer must grant the account the permission to be a relayer for the relevant Vault function. This
  //    means that Balancer governance must approve each individual contract to act as a relayer for the intended
  //    functions.
  //  - Each user must approve the relayer to act on their behalf.
  // This double protection means users cannot be tricked into approving malicious relayers (because they will not
  // have been allowed by the Authorizer via governance), nor can malicious relayers approved by a compromised
  // Authorizer or governance drain user funds, since they would also need to be approved by each individual user.

  /**
   * @dev Returns true if `user` has approved `relayer` to act as a relayer for them.
   */
  function hasApprovedRelayer(address user, address relayer) external view returns (bool);

  /**
   * @dev Allows `relayer` to act as a relayer for `sender` if `approved` is true, and disallows it otherwise.
   *
   * Emits a `RelayerApprovalChanged` event.
   */
  function setRelayerApproval(address sender, address relayer, bool approved) external;

  /**
   * @dev Emitted every time a relayer is approved or disapproved by `setRelayerApproval`.
   */
  event RelayerApprovalChanged(address indexed relayer, address indexed sender, bool approved);

  // Internal Balance
  //
  // Users can deposit tokens into the Vault, where they are allocated to their Internal Balance, and later
  // transferred or withdrawn. It can also be used as a source of tokens when joining Pools, as a destination
  // when exiting them, and as either when performing swaps. This usage of Internal Balance results in greatly reduced
  // gas costs when compared to relying on plain ERC20 transfers, leading to large savings for frequent users.
  //
  // Internal Balance management features batching, which means a single contract call can be used to perform multiple
  // operations of different kinds, with different senders and recipients, at once.

  /**
   * @dev Returns `user`'s Internal Balance for a set of tokens.
   */
  function getInternalBalance(address user, IERC20[] memory tokens) external view returns (uint256[] memory);

  /**
   * @dev Performs a set of user balance operations, which involve Internal Balance (deposit, withdraw or transfer)
   * and plain ERC20 transfers using the Vault's allowance. This last feature is particularly useful for relayers, as
   * it lets integrators reuse a user's Vault allowance.
   *
   * For each operation, if the caller is not `sender`, it must be an authorized relayer for them.
   */
  function manageUserBalance(UserBalanceOp[] memory ops) external payable;

  /**
     * @dev Data for `manageUserBalance` operations, which include the possibility for ETH to be sent and received
     without manual WETH wrapping or unwrapping.
     */
  struct UserBalanceOp {
    UserBalanceOpKind kind;
    IAsset asset;
    uint256 amount;
    address sender;
    address payable recipient;
  }

  // There are four possible operations in `manageUserBalance`:
  //
  // - DEPOSIT_INTERNAL
  // Increases the Internal Balance of the `recipient` account by transferring tokens from the corresponding
  // `sender`. The sender must have allowed the Vault to use their tokens via `IERC20.approve()`.
  //
  // ETH can be used by passing the ETH sentinel value as the asset and forwarding ETH in the call: it will be wrapped
  // and deposited as WETH. Any ETH amount remaining will be sent back to the caller (not the sender, which is
  // relevant for relayers).
  //
  // Emits an `InternalBalanceChanged` event.
  //
  //
  // - WITHDRAW_INTERNAL
  // Decreases the Internal Balance of the `sender` account by transferring tokens to the `recipient`.
  //
  // ETH can be used by passing the ETH sentinel value as the asset. This will deduct WETH instead, unwrap it and send
  // it to the recipient as ETH.
  //
  // Emits an `InternalBalanceChanged` event.
  //
  //
  // - TRANSFER_INTERNAL
  // Transfers tokens from the Internal Balance of the `sender` account to the Internal Balance of `recipient`.
  //
  // Reverts if the ETH sentinel value is passed.
  //
  // Emits an `InternalBalanceChanged` event.
  //
  //
  // - TRANSFER_EXTERNAL
  // Transfers tokens from `sender` to `recipient`, using the Vault's ERC20 allowance. This is typically used by
  // relayers, as it lets them reuse a user's Vault allowance.
  //
  // Reverts if the ETH sentinel value is passed.
  //
  // Emits an `ExternalBalanceTransfer` event.

  enum UserBalanceOpKind {
    DEPOSIT_INTERNAL,
    WITHDRAW_INTERNAL,
    TRANSFER_INTERNAL,
    TRANSFER_EXTERNAL
  }

  /**
   * @dev Emitted when a user's Internal Balance changes, either from calls to `manageUserBalance`, or through
   * interacting with Pools using Internal Balance.
   *
   * Because Internal Balance works exclusively with ERC20 tokens, ETH deposits and withdrawals will use the WETH
   * address.
   */
  event InternalBalanceChanged(address indexed user, IERC20 indexed token, int256 delta);

  /**
   * @dev Emitted when a user's Vault ERC20 allowance is used by the Vault to transfer tokens to an external account.
   */
  event ExternalBalanceTransfer(IERC20 indexed token, address indexed sender, address recipient, uint256 amount);

  // Pools
  //
  // There are three specialization settings for Pools, which allow for cheaper swaps at the cost of reduced
  // functionality:
  //
  //  - General: no specialization, suited for all Pools. IGeneralPool is used for swap request callbacks, passing the
  // balance of all tokens in the Pool. These Pools have the largest swap costs (because of the extra storage reads),
  // which increase with the number of registered tokens.
  //
  //  - Minimal Swap Info: IMinimalSwapInfoPool is used instead of IGeneralPool, which saves gas by only passing the
  // balance of the two tokens involved in the swap. This is suitable for some pricing algorithms, like the weighted
  // constant product one popularized by Balancer V1. Swap costs are smaller compared to general Pools, and are
  // independent of the number of registered tokens.
  //
  //  - Two Token: only allows two tokens to be registered. This achieves the lowest possible swap gas cost. Like
  // minimal swap info Pools, these are called via IMinimalSwapInfoPool.

  enum PoolSpecialization {
    GENERAL,
    MINIMAL_SWAP_INFO,
    TWO_TOKEN
  }

  /**
   * @dev Registers the caller account as a Pool with a given specialization setting. Returns the Pool's ID, which
   * is used in all Pool-related functions. Pools cannot be deregistered, nor can the Pool's specialization be
   * changed.
   *
   * The caller is expected to be a smart contract that implements either `IGeneralPool` or `IMinimalSwapInfoPool`,
   * depending on the chosen specialization setting. This contract is known as the Pool's contract.
   *
   * Note that the same contract may register itself as multiple Pools with unique Pool IDs, or in other words,
   * multiple Pools may share the same contract.
   *
   * Emits a `PoolRegistered` event.
   */
  function registerPool(PoolSpecialization specialization) external returns (bytes32);

  /**
   * @dev Emitted when a Pool is registered by calling `registerPool`.
   */
  event PoolRegistered(bytes32 indexed poolId, address indexed poolAddress, PoolSpecialization specialization);

  /**
   * @dev Returns a Pool's contract address and specialization setting.
   */
  function getPool(bytes32 poolId) external view returns (address, PoolSpecialization);

  /**
   * @dev Registers `tokens` for the `poolId` Pool. Must be called by the Pool's contract.
   *
   * Pools can only interact with tokens they have registered. Users join a Pool by transferring registered tokens,
   * exit by receiving registered tokens, and can only swap registered tokens.
   *
   * Each token can only be registered once. For Pools with the Two Token specialization, `tokens` must have a length
   * of two, that is, both tokens must be registered in the same `registerTokens` call, and they must be sorted in
   * ascending order.
   *
   * The `tokens` and `assetManagers` arrays must have the same length, and each entry in these indicates the Asset
   * Manager for the corresponding token. Asset Managers can manage a Pool's tokens via `managePoolBalance`,
   * depositing and withdrawing them directly, and can even set their balance to arbitrary amounts. They are therefore
   * expected to be highly secured smart contracts with sound design principles, and the decision to register an
   * Asset Manager should not be made lightly.
   *
   * Pools can choose not to assign an Asset Manager to a given token by passing in the zero address. Once an Asset
   * Manager is set, it cannot be changed except by deregistering the associated token and registering again with a
   * different Asset Manager.
   *
   * Emits a `TokensRegistered` event.
   */
  function registerTokens(bytes32 poolId, IERC20[] memory tokens, address[] memory assetManagers) external;

  /**
   * @dev Emitted when a Pool registers tokens by calling `registerTokens`.
   */
  event TokensRegistered(bytes32 indexed poolId, IERC20[] tokens, address[] assetManagers);

  /**
   * @dev Deregisters `tokens` for the `poolId` Pool. Must be called by the Pool's contract.
   *
   * Only registered tokens (via `registerTokens`) can be deregistered. Additionally, they must have zero total
   * balance. For Pools with the Two Token specialization, `tokens` must have a length of two, that is, both tokens
   * must be deregistered in the same `deregisterTokens` call.
   *
   * A deregistered token can be re-registered later on, possibly with a different Asset Manager.
   *
   * Emits a `TokensDeregistered` event.
   */
  function deregisterTokens(bytes32 poolId, IERC20[] memory tokens) external;

  /**
   * @dev Emitted when a Pool deregisters tokens by calling `deregisterTokens`.
   */
  event TokensDeregistered(bytes32 indexed poolId, IERC20[] tokens);

  /**
   * @dev Returns detailed information for a Pool's registered token.
   *
   * `cash` is the number of tokens the Vault currently holds for the Pool. `managed` is the number of tokens
   * withdrawn and held outside the Vault by the Pool's token Asset Manager. The Pool's total balance for `token`
   * equals the sum of `cash` and `managed`.
   *
   * Internally, `cash` and `managed` are stored using 112 bits. No action can ever cause a Pool's token `cash`,
   * `managed` or `total` balance to be greater than 2^112 - 1.
   *
   * `lastChangeBlock` is the number of the block in which `token`'s total balance was last modified (via either a
   * join, exit, swap, or Asset Manager update). This value is useful to avoid so-called 'sandwich attacks', for
   * example when developing price oracles. A change of zero (e.g. caused by a swap with amount zero) is considered a
   * change for this purpose, and will update `lastChangeBlock`.
   *
   * `assetManager` is the Pool's token Asset Manager.
   */
  function getPoolTokenInfo(
    bytes32 poolId,
    IERC20 token
  ) external view returns (uint256 cash, uint256 managed, uint256 lastChangeBlock, address assetManager);

  /**
   * @dev Returns a Pool's registered tokens, the total balance for each, and the latest block when *any* of
   * the tokens' `balances` changed.
   *
   * The order of the `tokens` array is the same order that will be used in `joinPool`, `exitPool`, as well as in all
   * Pool hooks (where applicable). Calls to `registerTokens` and `deregisterTokens` may change this order.
   *
   * If a Pool only registers tokens once, and these are sorted in ascending order, they will be stored in the same
   * order as passed to `registerTokens`.
   *
   * Total balances include both tokens held by the Vault and those withdrawn by the Pool's Asset Managers. These are
   * the amounts used by joins, exits and swaps. For a detailed breakdown of token balances, use `getPoolTokenInfo`
   * instead.
   */
  function getPoolTokens(
    bytes32 poolId
  ) external view returns (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock);

  /**
   * @dev Called by users to join a Pool, which transfers tokens from `sender` into the Pool's balance. This will
   * trigger custom Pool behavior, which will typically grant something in return to `recipient` - often tokenized
   * Pool shares.
   *
   * If the caller is not `sender`, it must be an authorized relayer for them.
   *
   * The `assets` and `maxAmountsIn` arrays must have the same length, and each entry indicates the maximum amount
   * to send for each asset. The amounts to send are decided by the Pool and not the Vault: it just enforces
   * these maximums.
   *
   * If joining a Pool that holds WETH, it is possible to send ETH directly: the Vault will do the wrapping. To enable
   * this mechanism, the IAsset sentinel value (the zero address) must be passed in the `assets` array instead of the
   * WETH address. Note that it is not possible to combine ETH and WETH in the same join. Any excess ETH will be sent
   * back to the caller (not the sender, which is important for relayers).
   *
   * `assets` must have the same length and order as the array returned by `getPoolTokens`. This prevents issues when
   * interacting with Pools that register and deregister tokens frequently. If sending ETH however, the array must be
   * sorted *before* replacing the WETH address with the ETH sentinel value (the zero address), which means the final
   * `assets` array might not be sorted. Pools with no registered tokens cannot be joined.
   *
   * If `fromInternalBalance` is true, the caller's Internal Balance will be preferred: ERC20 transfers will only
   * be made for the difference between the requested amount and Internal Balance (if any). Note that ETH cannot be
   * withdrawn from Internal Balance: attempting to do so will trigger a revert.
   *
   * This causes the Vault to call the `IBasePool.onJoinPool` hook on the Pool's contract, where Pools implement
   * their own custom logic. This typically requires additional information from the user (such as the expected number
   * of Pool shares). This can be encoded in the `userData` argument, which is ignored by the Vault and passed
   * directly to the Pool's contract, as is `recipient`.
   *
   * Emits a `PoolBalanceChanged` event.
   */
  function joinPool(bytes32 poolId, address sender, address recipient, JoinPoolRequest memory request) external payable;

  struct JoinPoolRequest {
    IAsset[] assets;
    uint256[] maxAmountsIn;
    bytes userData;
    bool fromInternalBalance;
  }

  /**
   * @dev Called by users to exit a Pool, which transfers tokens from the Pool's balance to `recipient`. This will
   * trigger custom Pool behavior, which will typically ask for something in return from `sender` - often tokenized
   * Pool shares. The amount of tokens that can be withdrawn is limited by the Pool's `cash` balance (see
   * `getPoolTokenInfo`).
   *
   * If the caller is not `sender`, it must be an authorized relayer for them.
   *
   * The `tokens` and `minAmountsOut` arrays must have the same length, and each entry in these indicates the minimum
   * token amount to receive for each token contract. The amounts to send are decided by the Pool and not the Vault:
   * it just enforces these minimums.
   *
   * If exiting a Pool that holds WETH, it is possible to receive ETH directly: the Vault will do the unwrapping. To
   * enable this mechanism, the IAsset sentinel value (the zero address) must be passed in the `assets` array instead
   * of the WETH address. Note that it is not possible to combine ETH and WETH in the same exit.
   *
   * `assets` must have the same length and order as the array returned by `getPoolTokens`. This prevents issues when
   * interacting with Pools that register and deregister tokens frequently. If receiving ETH however, the array must
   * be sorted *before* replacing the WETH address with the ETH sentinel value (the zero address), which means the
   * final `assets` array might not be sorted. Pools with no registered tokens cannot be exited.
   *
   * If `toInternalBalance` is true, the tokens will be deposited to `recipient`'s Internal Balance. Otherwise,
   * an ERC20 transfer will be performed. Note that ETH cannot be deposited to Internal Balance: attempting to
   * do so will trigger a revert.
   *
   * `minAmountsOut` is the minimum amount of tokens the user expects to get out of the Pool, for each token in the
   * `tokens` array. This array must match the Pool's registered tokens.
   *
   * This causes the Vault to call the `IBasePool.onExitPool` hook on the Pool's contract, where Pools implement
   * their own custom logic. This typically requires additional information from the user (such as the expected number
   * of Pool shares to return). This can be encoded in the `userData` argument, which is ignored by the Vault and
   * passed directly to the Pool's contract.
   *
   * Emits a `PoolBalanceChanged` event.
   */
  function exitPool(bytes32 poolId, address sender, address payable recipient, ExitPoolRequest memory request) external;

  struct ExitPoolRequest {
    IAsset[] assets;
    uint256[] minAmountsOut;
    bytes userData;
    bool toInternalBalance;
  }

  /**
   * @dev Emitted when a user joins or exits a Pool by calling `joinPool` or `exitPool`, respectively.
   */
  event PoolBalanceChanged(
    bytes32 indexed poolId,
    address indexed liquidityProvider,
    IERC20[] tokens,
    int256[] deltas,
    uint256[] protocolFeeAmounts
  );

  enum PoolBalanceChangeKind {
    JOIN,
    EXIT
  }

  // Swaps
  //
  // Users can swap tokens with Pools by calling the `swap` and `batchSwap` functions. To do this,
  // they need not trust Pool contracts in any way: all security checks are made by the Vault. They must however be
  // aware of the Pools' pricing algorithms in order to estimate the prices Pools will quote.
  //
  // The `swap` function executes a single swap, while `batchSwap` can perform multiple swaps in sequence.
  // In each individual swap, tokens of one kind are sent from the sender to the Pool (this is the 'token in'),
  // and tokens of another kind are sent from the Pool to the recipient in exchange (this is the 'token out').
  // More complex swaps, such as one token in to multiple tokens out can be achieved by batching together
  // individual swaps.
  //
  // There are two swap kinds:
  //  - 'given in' swaps, where the amount of tokens in (sent to the Pool) is known, and the Pool determines (via the
  // `onSwap` hook) the amount of tokens out (to send to the recipient).
  //  - 'given out' swaps, where the amount of tokens out (received from the Pool) is known, and the Pool determines
  // (via the `onSwap` hook) the amount of tokens in (to receive from the sender).
  //
  // Additionally, it is possible to chain swaps using a placeholder input amount, which the Vault replaces with
  // the calculated output of the previous swap. If the previous swap was 'given in', this will be the calculated
  // tokenOut amount. If the previous swap was 'given out', it will use the calculated tokenIn amount. These extended
  // swaps are known as 'multihop' swaps, since they 'hop' through a number of intermediate tokens before arriving at
  // the final intended token.
  //
  // In all cases, tokens are only transferred in and out of the Vault (or withdrawn from and deposited into Internal
  // Balance) after all individual swaps have been completed, and the net token balance change computed. This makes
  // certain swap patterns, such as multihops, or swaps that interact with the same token pair in multiple Pools, cost
  // much less gas than they would otherwise.
  //
  // It also means that under certain conditions it is possible to perform arbitrage by swapping with multiple
  // Pools in a way that results in net token movement out of the Vault (profit), with no tokens being sent in (only
  // updating the Pool's internal accounting).
  //
  // To protect users from front-running or the market changing rapidly, they supply a list of 'limits' for each token
  // involved in the swap, where either the maximum number of tokens to send (by passing a positive value) or the
  // minimum amount of tokens to receive (by passing a negative value) is specified.
  //
  // Additionally, a 'deadline' timestamp can also be provided, forcing the swap to fail if it occurs after
  // this point in time (e.g. if the transaction failed to be included in a block promptly).
  //
  // If interacting with Pools that hold WETH, it is possible to both send and receive ETH directly: the Vault will do
  // the wrapping and unwrapping. To enable this mechanism, the IAsset sentinel value (the zero address) must be
  // passed in the `assets` array instead of the WETH address. Note that it is possible to combine ETH and WETH in the
  // same swap. Any excess ETH will be sent back to the caller (not the sender, which is relevant for relayers).
  //
  // Finally, Internal Balance can be used when either sending or receiving tokens.

  enum SwapKind {
    GIVEN_IN,
    GIVEN_OUT
  }

  /**
   * @dev Performs a swap with a single Pool.
   *
   * If the swap is 'given in' (the number of tokens to send to the Pool is known), it returns the amount of tokens
   * taken from the Pool, which must be greater than or equal to `limit`.
   *
   * If the swap is 'given out' (the number of tokens to take from the Pool is known), it returns the amount of tokens
   * sent to the Pool, which must be less than or equal to `limit`.
   *
   * Internal Balance usage and the recipient are determined by the `funds` struct.
   *
   * Emits a `Swap` event.
   */
  function swap(
    SingleSwap memory singleSwap,
    FundManagement memory funds,
    uint256 limit,
    uint256 deadline
  ) external payable returns (uint256);

  /**
   * @dev Data for a single swap executed by `swap`. `amount` is either `amountIn` or `amountOut` depending on
   * the `kind` value.
   *
   * `assetIn` and `assetOut` are either token addresses, or the IAsset sentinel value for ETH (the zero address).
   * Note that Pools never interact with ETH directly: it will be wrapped to or unwrapped from WETH by the Vault.
   *
   * The `userData` field is ignored by the Vault, but forwarded to the Pool in the `onSwap` hook, and may be
   * used to extend swap behavior.
   */
  struct SingleSwap {
    bytes32 poolId;
    SwapKind kind;
    IAsset assetIn;
    IAsset assetOut;
    uint256 amount;
    bytes userData;
  }

  /**
   * @dev Performs a series of swaps with one or multiple Pools. In each individual swap, the caller determines either
   * the amount of tokens sent to or received from the Pool, depending on the `kind` value.
   *
   * Returns an array with the net Vault asset balance deltas. Positive amounts represent tokens (or ETH) sent to the
   * Vault, and negative amounts represent tokens (or ETH) sent by the Vault. Each delta corresponds to the asset at
   * the same index in the `assets` array.
   *
   * Swaps are executed sequentially, in the order specified by the `swaps` array. Each array element describes a
   * Pool, the token to be sent to this Pool, the token to receive from it, and an amount that is either `amountIn` or
   * `amountOut` depending on the swap kind.
   *
   * Multihop swaps can be executed by passing an `amount` value of zero for a swap. This will cause the amount in/out
   * of the previous swap to be used as the amount in for the current one. In a 'given in' swap, 'tokenIn' must equal
   * the previous swap's `tokenOut`. For a 'given out' swap, `tokenOut` must equal the previous swap's `tokenIn`.
   *
   * The `assets` array contains the addresses of all assets involved in the swaps. These are either token addresses,
   * or the IAsset sentinel value for ETH (the zero address). Each entry in the `swaps` array specifies tokens in and
   * out by referencing an index in `assets`. Note that Pools never interact with ETH directly: it will be wrapped to
   * or unwrapped from WETH by the Vault.
   *
   * Internal Balance usage, sender, and recipient are determined by the `funds` struct. The `limits` array specifies
   * the minimum or maximum amount of each token the vault is allowed to transfer.
   *
   * `batchSwap` can be used to make a single swap, like `swap` does, but doing so requires more gas than the
   * equivalent `swap` call.
   *
   * Emits `Swap` events.
   */
  function batchSwap(
    SwapKind kind,
    BatchSwapStep[] memory swaps,
    IAsset[] memory assets,
    FundManagement memory funds,
    int256[] memory limits,
    uint256 deadline
  ) external payable returns (int256[] memory);

  /**
   * @dev Data for each individual swap executed by `batchSwap`. The asset in and out fields are indexes into the
   * `assets` array passed to that function, and ETH assets are converted to WETH.
   *
   * If `amount` is zero, the multihop mechanism is used to determine the actual amount based on the amount in/out
   * from the previous swap, depending on the swap kind.
   *
   * The `userData` field is ignored by the Vault, but forwarded to the Pool in the `onSwap` hook, and may be
   * used to extend swap behavior.
   */
  struct BatchSwapStep {
    bytes32 poolId;
    uint256 assetInIndex;
    uint256 assetOutIndex;
    uint256 amount;
    bytes userData;
  }

  /**
   * @dev Emitted for each individual swap performed by `swap` or `batchSwap`.
   */
  event Swap(
    bytes32 indexed poolId,
    IERC20 indexed tokenIn,
    IERC20 indexed tokenOut,
    uint256 amountIn,
    uint256 amountOut
  );

  /**
   * @dev All tokens in a swap are either sent from the `sender` account to the Vault, or from the Vault to the
   * `recipient` account.
   *
   * If the caller is not `sender`, it must be an authorized relayer for them.
   *
   * If `fromInternalBalance` is true, the `sender`'s Internal Balance will be preferred, performing an ERC20
   * transfer for the difference between the requested amount and the User's Internal Balance (if any). The `sender`
   * must have allowed the Vault to use their tokens via `IERC20.approve()`. This matches the behavior of
   * `joinPool`.
   *
   * If `toInternalBalance` is true, tokens will be deposited to `recipient`'s internal balance instead of
   * transferred. This matches the behavior of `exitPool`.
   *
   * Note that ETH cannot be deposited to or withdrawn from Internal Balance: attempting to do so will trigger a
   * revert.
   */
  struct FundManagement {
    address sender;
    bool fromInternalBalance;
    address payable recipient;
    bool toInternalBalance;
  }

  /**
   * @dev Simulates a call to `batchSwap`, returning an array of Vault asset deltas. Calls to `swap` cannot be
   * simulated directly, but an equivalent `batchSwap` call can and will yield the exact same result.
   *
   * Each element in the array corresponds to the asset at the same index, and indicates the number of tokens (or ETH)
   * the Vault would take from the sender (if positive) or send to the recipient (if negative). The arguments it
   * receives are the same that an equivalent `batchSwap` call would receive.
   *
   * Unlike `batchSwap`, this function performs no checks on the sender or recipient field in the `funds` struct.
   * This makes it suitable to be called by off-chain applications via eth_call without needing to hold tokens,
   * approve them for the Vault, or even know a user's address.
   *
   * Note that this function is not 'view' (due to implementation details): the client code must explicitly execute
   * eth_call instead of eth_sendTransaction.
   */
  function queryBatchSwap(
    SwapKind kind,
    BatchSwapStep[] memory swaps,
    IAsset[] memory assets,
    FundManagement memory funds
  ) external returns (int256[] memory assetDeltas);

  /**
   * @dev Performs a 'flash loan', sending tokens to `recipient`, executing the `receiveFlashLoan` hook on it,
   * and then reverting unless the tokens plus a proportional protocol fee have been returned.
   *
   * The `tokens` and `amounts` arrays must have the same length, and each entry in these indicates the loan amount
   * for each token contract. `tokens` must be sorted in ascending order.
   *
   * The 'userData' field is ignored by the Vault, and forwarded as-is to `recipient` as part of the
   * `receiveFlashLoan` call.
   *
   * Emits `FlashLoan` events.
   */
  /**
     function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
     */

  /**
   * @dev Emitted for each individual flash loan performed by `flashLoan`.
   */
  //event FlashLoan(IFlashLoanRecipient indexed recipient, IERC20 indexed token, uint256 amount, uint256 feeAmount);

  // Asset Management
  //
  // Each token registered for a Pool can be assigned an Asset Manager, which is able to freely withdraw the Pool's
  // tokens from the Vault, deposit them, or assign arbitrary values to its `managed` balance (see
  // `getPoolTokenInfo`). This makes them extremely powerful and dangerous. Even if an Asset Manager only directly
  // controls one of the tokens in a Pool, a malicious manager could set that token's balance to manipulate the
  // prices of the other tokens, and then drain the Pool with swaps. The risk of using Asset Managers is therefore
  // not constrained to the tokens they are managing, but extends to the entire Pool's holdings.
  //
  // However, a properly designed Asset Manager smart contract can be safely used for the Pool's benefit,
  // for example by lending unused tokens out for interest, or using them to participate in voting protocols.
  //
  // This concept is unrelated to the IAsset interface.

  /**
   * @dev Performs a set of Pool balance operations, which may be either withdrawals, deposits or updates.
   *
   * Pool Balance management features batching, which means a single contract call can be used to perform multiple
   * operations of different kinds, with different Pools and tokens, at once.
   *
   * For each operation, the caller must be registered as the Asset Manager for `token` in `poolId`.
   */
  function managePoolBalance(PoolBalanceOp[] memory ops) external;

  struct PoolBalanceOp {
    PoolBalanceOpKind kind;
    bytes32 poolId;
    IERC20 token;
    uint256 amount;
  }

  /**
   * Withdrawals decrease the Pool's cash, but increase its managed balance, leaving the total balance unchanged.
   *
   * Deposits increase the Pool's cash, but decrease its managed balance, leaving the total balance unchanged.
   *
   * Updates don't affect the Pool's cash balance, but because the managed balance changes, it does alter the total.
   * The external amount can be either increased or decreased by this call (i.e., reporting a gain or a loss).
   */
  enum PoolBalanceOpKind {
    WITHDRAW,
    DEPOSIT,
    UPDATE
  }

  /**
   * @dev Emitted when a Pool's token Asset Manager alters its balance via `managePoolBalance`.
   */
  event PoolBalanceManaged(
    bytes32 indexed poolId,
    address indexed assetManager,
    IERC20 indexed token,
    int256 cashDelta,
    int256 managedDelta
  );

  // Protocol Fees
  //
  // Some operations cause the Vault to collect tokens in the form of protocol fees, which can then be withdrawn by
  // permissioned accounts.
  //
  // There are two kinds of protocol fees:
  //
  //  - flash loan fees: charged on all flash loans, as a percentage of the amounts lent.
  //
  //  - swap fees: a percentage of the fees charged by Pools when performing swaps. For a number of reasons, including
  // swap gas costs and interface simplicity, protocol swap fees are not charged on each individual swap. Rather,
  // Pools are expected to keep track of how much they have charged in swap fees, and pay any outstanding debts to the
  // Vault when they are joined or exited. This prevents users from joining a Pool with unpaid debt, as well as
  // exiting a Pool in debt without first paying their share.

  /**
   * @dev Returns the current protocol fee module.
   */
  function getProtocolFeesCollector() external view returns (IProtocolFeesCollector);

  /**
   * @dev Safety mechanism to pause most Vault operations in the event of an emergency - typically detection of an
   * error in some part of the system.
   *
   * The Vault can only be paused during an initial time period, after which pausing is forever disabled.
   *
   * While the contract is paused, the following features are disabled:
   * - depositing and transferring internal balance
   * - transferring external balance (using the Vault's allowance)
   * - swaps
   * - joining Pools
   * - Asset Manager interactions
   *
   * Internal Balance can still be withdrawn, and Pools exited.
   */
  function setPaused(bool paused) external;

  /**
   * @dev Returns the Vault's WETH instance.
   */
  function WETH() external view returns (IWETH);
  // solhint-disable-previous-line func-name-mixedcase
}

// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;

interface IWETH {
  function deposit() external payable;

  function transfer(address to, uint256 value) external returns (bool);

  function withdraw(uint256) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../oracle/IOracleRelay.sol";
import "../../_external/IERC20.sol";
import "../../_external/balancer/IBalancerVault.sol";
import "../../_external/balancer/IAsset.sol";

import "../../_external/balancer/LogExpMath.sol";

import "./IBaseOracle.sol";
import "./UsingBaseOracle.sol";
import "../../_external/HomoraMath.sol";

import "../../_external/IWETH.sol";

//test wit Aave flash loan
import "../aaveFlashLoan/FlashLoanReceiverBase.sol";

import "hardhat/console.sol";

interface IBalancerPool {
  function getPoolId() external view returns (bytes32);

  function totalSupply() external view returns (uint256);

  function getLastInvariant() external view returns (uint256, uint256);

  function getRate() external view returns (uint256);

  //metaStablePool only
  function getOracleMiscData()
    external
    view
    returns (
      int256 logInvariant,
      int256 logTotalSupply,
      uint256 oracleSampleCreationTimestamp,
      uint256 oracleIndex,
      bool oracleEnabled
    );
}

/*****************************************
 *
 * This relay gets a USD price for BPT LP token from a balancer MetaStablePool
 * This can be used as a stand alone oracle as the price is checked 2 separate ways
 *
 */

contract RateProofOfConcept is UsingBaseOracle, IBaseOracle, IOracleRelay {
  using HomoraMath for uint;
  bytes32 public immutable _poolId;

  uint256 public immutable _widthNumerator;
  uint256 public immutable _widthDenominator;

  IBalancerPool public immutable _priceFeed;

  mapping(address => IOracleRelay) public assetOracles;

  //Balancer Vault
  IBalancerVault public immutable VAULT; // = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

  /**
   * @param pool_address - Balancer StablePool or MetaStablePool address
   */
  constructor(
    address pool_address,
    IBalancerVault balancerVault,
    address[] memory _tokens,
    address[] memory _oracles,
    uint256 widthNumerator,
    uint256 widthDenominator
  ) UsingBaseOracle(IBaseOracle(pool_address)) {
    _priceFeed = IBalancerPool(pool_address);

    _poolId = _priceFeed.getPoolId();

    VAULT = balancerVault;

    registerOracles(_tokens, _oracles);

    _widthNumerator = widthNumerator;
    _widthDenominator = widthDenominator;
  }

  function currentValue() external view override returns (uint256) {
    (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = VAULT.getPoolTokens(_poolId);
    console.log("POOL ADDR: ", address(_priceFeed));
    console.log("Token 0: ", address(tokens[0]));
    console.log("Token 1: ", address(tokens[1]));
    console.log("Token0 price : ", assetOracles[address(tokens[0])].currentValue());
    console.log("Token1 price : ", assetOracles[address(tokens[1])].currentValue());

    console.log("Rate: ", _priceFeed.getRate());

    /**************Check Robust Price Solutions**************/
    checkLastChangedBlock(lastChangeBlock);
    //compareRates();
    //compareOutGivenIn(tokens, balances);
    //compareTokenBalances(tokens, balances);
    /**
    uint256 expectedOGI = divide(
      assetOracles[address(tokens[0])].currentValue(),
      assetOracles[address(tokens[1])].currentValue(),
      18
    );
    console.log("Expected Out giveni: ", expectedOGI);
     */
    //uint256 spotRobustPrice = getBPTprice(tokens, balances);
    //getOracleData();
    //uint256 pxPrice = getETHPx(address(_priceFeed));
    //simpleCalc();
    //getMinSafePrice(tokens);
    calcBptOut(tokens, balances);
    /********************************************************/

    uint256 naivePrice = getNaivePrice(tokens, balances);
    //console.log("RBST  price: ", spotRobustPrice);
    console.log("NAIVE PRICE: ", naivePrice);

    //verifyNaivePrice(naivePrice, naivePrice);

    // return checked price
    return naivePrice;
  }

  /*******************************GET & CHECK NAIVE PRICE********************************/
  function getNaivePrice(IERC20[] memory tokens, uint256[] memory balances) internal view returns (uint256 naivePrice) {
    uint256 naiveValue = sumBalances(tokens, balances);
    naivePrice = naiveValue / _priceFeed.totalSupply();
    require(naivePrice > 0, "invalid naive price");
  }

  function verifyNaivePrice(uint256 naivePrice, uint256 robustPrice) internal view {
    require(robustPrice > 0, "invalid robust price"); //todo move this to the used robust price

    // calculate buffer
    uint256 buffer = (_widthNumerator * naivePrice) / _widthDenominator;

    // create upper and lower bounds
    uint256 upperBounds = naivePrice + buffer;
    uint256 lowerBounds = naivePrice - buffer;

    ////console.log("naive Price: ", naivePrice, naivePrice / 1e18);
    ////console.log("Robust Price: ", robustPrice, robustPrice / 1e18);

    // ensure the robust price is within bounds
    require(robustPrice < upperBounds, "robustPrice too low");
    require(robustPrice > lowerBounds, "robustPrice too high");
  }

  /*******************************CHECK FOR LAST CHANGE BLOCK********************************/
  function checkLastChangedBlock(uint256 lastChangeBlock) internal view {
    require(lastChangeBlock < block.number, "Revert for manipulation resistance");
  }

  /*******************************CALCULATE BPT OUT********************************/

  function calcBptOutWithFairBalances(
    uint256[] memory _balances,
    uint256 v,
    uint256 amp
  ) internal view returns (uint256 result) {
    //calculate 'fair' balances

    console.log("True 0: ", _balances[0]);
    console.log("True 1: ", _balances[1]);

    uint256 fair0 = _getTokenBalanceGivenInvariantAndAllOtherBalances(amp, _balances, v, 1);
    uint256 fair1 = _getTokenBalanceGivenInvariantAndAllOtherBalances(amp, _balances, v, 0);
    console.log("Fair 0: ", fair0);
    console.log("Fair 1: ", fair1);
    //calculate V from fair balances? or use lastInvariant

    /**
    uint256[] memory fairBalances = new uint256[](2);

    fairBalances[0] = fair0;
    fairBalances[1] = fair1;

    fair0 = fair0 + 10 ** factor;
    fair1 = fair1 + 10 ** factor;

    uint256[] memory newBalances = new uint256[](2);

    newBalances[0] = fair0;
    newBalances[1] = fair1;

    uint256 currentInvariant = _calculateInvariant(amp, fairBalances);
    uint256 newInvariant = _calculateInvariant(amp, newBalances);
    uint256 invariantRatio = divide(newInvariant, currentInvariant, 18);

    result = mulDown(_priceFeed.totalSupply(), (invariantRatio - 1e18));
     */

    result = 1;
  }

  function calcBptOut(IERC20[] memory tokens, uint256[] memory _balances) internal view {
    (uint256 v, uint256 amp) = _priceFeed.getLastInvariant();

    uint256 currentV = _calculateInvariant(amp, _balances);
    uint256 factor = 20;

    uint256 vResult = calcBptOutWithFairBalances(_balances, v, amp);

    //console.log("Bal0: ", _balances[0]);
    //console.log("Bal1: ", _balances[1]);

    _balances[0] = _balances[0] + 10 ** factor;
    _balances[1] = _balances[1] + 10 ** factor;

    //console.log("Amt0: ", _balances[0]);
    //console.log("Amt1: ", _balances[1]);

    uint256 newInvariant = _calculateInvariant(amp, _balances);

    uint256 invariantRatio = divide(newInvariant, currentV, 18);

    uint256 result = mulDown(_priceFeed.totalSupply(), (invariantRatio - 1e18));

    //price0 + price1
    uint256 numerator = assetOracles[address(tokens[0])].currentValue() +
      assetOracles[address(tokens[1])].currentValue();

    uint256 output = divide(numerator, result, factor);
    uint256 vOutput = divide(numerator, vResult, factor);

    console.log("BPT T PRICE: ", output);
    console.log("BPT V PRICE: ", vOutput);
  }

  function _calculateInvariant(
    uint256 amplificationParameter,
    uint256[] memory balances
  ) internal pure returns (uint256) {
    uint256 _AMP_PRECISION = 1e3;
    /**********************************************************************************************
        // invariant                                                                                 //
        // D = invariant                                                  D^(n+1)                    //
        // A = amplification coefficient      A  n^n S + D = A D n^n + -----------                   //
        // S = sum of balances                                             n^n P                     //
        // P = product of balances                                                                   //
        // n = number of tokens                                                                      //
        **********************************************************************************************/

    // Always round down, to match Vyper's arithmetic (which always truncates).

    uint256 sum = 0; // S in the Curve version
    uint256 numTokens = balances.length;
    for (uint256 i = 0; i < numTokens; i++) {
      sum = sum + (balances[i]);
    }
    if (sum == 0) {
      return 0;
    }

    uint256 prevInvariant; // Dprev in the Curve version
    uint256 invariant = sum; // D in the Curve version
    uint256 ampTimesTotal = amplificationParameter * numTokens; // Ann in the Curve version

    for (uint256 i = 0; i < 255; i++) {
      uint256 D_P = invariant;

      for (uint256 j = 0; j < numTokens; j++) {
        // (D_P * invariant) / (balances[j] * numTokens)
        D_P = divDown(mul(D_P, invariant), mul(balances[j], numTokens));
      }

      prevInvariant = invariant;

      invariant = divDown(
        mul(
          // (ampTimesTotal * sum) / AMP_PRECISION + D_P * numTokens
          (divDown(mul(ampTimesTotal, sum), _AMP_PRECISION) + (mul(D_P, numTokens))),
          invariant
        ),
        // ((ampTimesTotal - _AMP_PRECISION) * invariant) / _AMP_PRECISION + (numTokens + 1) * D_P
        (divDown(mul((ampTimesTotal - _AMP_PRECISION), invariant), _AMP_PRECISION) + (mul((numTokens + 1), D_P)))
      );

      if (invariant > prevInvariant) {
        if (invariant - prevInvariant <= 1) {
          return invariant;
        }
      } else if (prevInvariant - invariant <= 1) {
        return invariant;
      }
    }

    revert("STABLE_INVARIANT_DIDNT_CONVERGE");
  }

  /*******************************USE MIN SAFE PRICE********************************/
  ///@notice this returns a price that is typically slightly less than the naive price
  /// it should be safe to use this price, though it will be slightly less than the true naive price,
  /// so borrowing power will be slightly less than expected
  function getMinSafePrice(IERC20[] memory tokens) internal view returns (uint256 minSafePrice) {
    //uint256 rate = _priceFeed.getRate();

    (uint256 v /**uint256 amp */, ) = _priceFeed.getLastInvariant();

    uint256 calculatedRate = (v * 1e18) / _priceFeed.totalSupply();

    //get min price
    uint256 p0 = assetOracles[address(tokens[0])].currentValue();
    uint256 p1 = assetOracles[address(tokens[1])].currentValue();

    uint256 pm = p0 < p1 ? p0 : p1;

    minSafePrice = (pm * calculatedRate) / 1e18;
    console.log("Min safe price: ", minSafePrice);
  }

  /*******************************BASE ORACLE ALPHA METHOD********************************/

  function getETHPx(address /**priceFeed */) public view override returns (uint) {
    (IERC20[] memory tokens, uint256[] memory balances /**uint256 lastChangeBlock */, ) = VAULT.getPoolTokens(_poolId);
    //address token0 = address(tokens[0]);
    //address token1 = address(tokens[1]);
    uint totalSupply = _priceFeed.totalSupply();
    uint r0 = balances[0];
    uint r1 = balances[1];

    console.log("Actual0: ", balances[0]);
    console.log("Actual1: ", balances[1]);

    uint sqrtK = HomoraMath.sqrt(r0 * r1).fdiv(totalSupply);

    uint px0 = assetOracles[address(tokens[0])].currentValue() * 2 ** 112;
    uint px1 = assetOracles[address(tokens[1])].currentValue() * 2 ** 112;
    // fair token0 amt: sqrtK * sqrt(px1/px0)
    // fair token1 amt: sqrtK * sqrt(px0/px1)
    // fair lp price = 2 * sqrt(px0 * px1)
    // split into 2 sqrts multiplication to prevent uint overflow (note the 2**112)

    uint result = sqrtK.mul(2).mul(HomoraMath.sqrt(px0)).div(2 ** 56).mul(HomoraMath.sqrt(px1)).div(2 ** 56);
    //console.log("SqrtReserve: ", result / 2 ** 112);
    return result;
  }

  function simpleCalc() public view {
    //trying hard numbers
    /**
  //this works according to   //https://cmichel.io/pricing-lp-tokens/
    uint r0 = 10000e18;
    uint r1 = 200e18;

    uint p0 = 650e18;
    uint p1 = 22000e18;

    uint K = r0 * r1;
    uint P = divide(p0, p1, 18);

    uint reserve0 = HomoraMath.sqrt(divide(K, P, 18));
    console.log(reserve0);

    uint reserve1 = HomoraMath.sqrt(K * P) / 1e9;
    console.log(reserve1);

    //safe price would be ((reserve0 * p0) + (reserve1 * p1)) / totalSupply
   */

    (IERC20[] memory tokens, uint256[] memory balances /**uint256 lastChangeBlock */, ) = VAULT.getPoolTokens(_poolId);
    //(uint256 invariant, uint256 amp) = _priceFeed.getLastInvariant();

    uint px0 = assetOracles[address(tokens[0])].currentValue();
    uint px1 = assetOracles[address(tokens[1])].currentValue();

    uint K = balances[0] * balances[1];
    uint P = divide(px0, px1, 18);
    uint fairReserve0 = HomoraMath.sqrt(divide(K, P, 18));
    uint fairReserve1 = HomoraMath.sqrt(K * P) / 1e9;

    uint fairValue0 = (fairReserve0 * px0) / 1e18;
    uint fairValue1 = (fairReserve1 * px1) / 1e18;

    console.log("Comput0: ", fairValue0);
    console.log("Comput1: ", fairValue1);
    uint result = divide((fairValue0 + fairValue1), _priceFeed.totalSupply(), 18);
    console.log("FairReserve: ", result);
  }

  /*******************************UTILIZE METASTABLEPOOL LOG ORACLE********************************/
  /**
  function getOracleData() internal view {
    if (address(_priceFeed) != 0x3dd0843A028C86e0b760b1A76929d1C5Ef93a2dd) {
      (
        int256 logInvariant,
        int256 logTotalSupply,
        uint256 oracleSampleCreationTimestamp,
        uint256 oracleIndex,
        bool oracleEnabled
      ) = _priceFeed.getOracleMiscData();

      uint256 v = fromLowResLog(logInvariant);
      uint256 ts = fromLowResLog(logTotalSupply);

      uint256 oracleRate = (v * 1e18) / ts;
      console.log("Oracle rate  : ", oracleRate);
    }
  }
   */

  /**
   * @dev Restores `value` from logarithmic space. `value` is expected to be the result of a call to `toLowResLog`,
   * any other function that returns 4 decimals fixed point logarithms, or the sum of such values.
   */
  function fromLowResLog(int256 value) internal pure returns (uint256) {
    int256 _LOG_COMPRESSION_FACTOR = 1e14;
    return uint256(LogExpMath.exp(value * _LOG_COMPRESSION_FACTOR));
  }

  /*******************************CALCULATE SPOT PRICE********************************/
  function getBPTprice(IERC20[] memory tokens, uint256[] memory balances) internal view returns (uint256 price) {
    uint256 pyx = getSpotPrice(balances);
    uint256[] memory reverse = new uint256[](2);
    reverse[0] = balances[1];
    reverse[1] = balances[0];

    uint256 pxy = getSpotPrice(reverse);

    //console.log("token 0 => 1 : ", pyx);
    //console.log("token 1 => 0 : ", pxy);

    //uint256 valueX = ((balances[0] * assetOracles[address(tokens[0])].currentValue()));
    uint256 valueX = (((pxy * balances[0]) * assetOracles[address(tokens[0])].currentValue()) / 1e18);

    uint256 valueY = (((pyx * balances[1]) * assetOracles[address(tokens[1])].currentValue()) / 1e18);

    uint256 totalValue = valueX + valueY;

    price = (totalValue / _priceFeed.totalSupply());
  }

  /**
   * @dev Calculates the spot price of token Y in terms of token X.
   */
  function getSpotPrice(uint256[] memory balances) internal view returns (uint256 pyx) {
    (uint256 invariant, uint256 amp) = _priceFeed.getLastInvariant();

    uint256 a = amp * 2;
    uint256 b = (invariant * a) - invariant;

    uint256 axy2 = mulDown(((a * 2) * balances[0]), balances[1]);

    // dx = a.x.y.2 + a.y^2 - b.y
    uint256 derivativeX = mulDown(axy2 + (a * balances[0]), balances[1]) - (mulDown(b, balances[1]));

    // dy = a.x.y.2 + a.x^2 - b.x
    uint256 derivativeY = mulDown(axy2 + (a * balances[0]), balances[1]) - (mulDown(b, balances[0]));

    pyx = divUpSpot(derivativeX, derivativeY);
  }

  function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 product = a * b;
    require(a == 0 || product / a == b, "overflow");

    return product / 1e18;
  }

  function divUpSpot(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0, "Zero Division");

    if (a == 0) {
      return 0;
    } else {
      uint256 aInflated = a * 1e18;
      require(aInflated / a == 1e18, "divUp error - mull overflow"); // mul overflow

      // The traditional divUp formula is:
      // divUp(x, y) := (x + y - 1) / y
      // To avoid intermediate overflow in the addition, we distribute the division and get:
      // divUp(x, y) := (x - 1) / y + 1
      // Note that this requires x != 0, which we already tested for.

      return ((aInflated - 1) / b) + 1;
    }
  }

  /*******************************COMPARE RATES********************************/
  function compareRates() internal view {
    (uint256 v /**uint256 amp */, ) = _priceFeed.getLastInvariant();

    uint256 calculatedRate = (v * 1e18) / _priceFeed.totalSupply();

    uint256 reportedRate = _priceFeed.getRate();
    console.log("Invariant: ", v);

    console.log("computed rate: ", calculatedRate);
    console.log("Reported Rate: ", reportedRate);
    console.log("Inverted rate: ", divide(1e18, reportedRate, 18));

    ///@notice theoreticly if the rates diverge, then the price may have been manipulated
    /// todo test this theory
    uint256 buffer = 1e14; //0.0001 => 0.001%

    // create upper and lower bounds
    uint256 upperBounds = calculatedRate + buffer;
    uint256 lowerBounds = calculatedRate - buffer;

    require(reportedRate < upperBounds, "reportedRate too low");
    require(reportedRate > lowerBounds, "reportedRate too high");
  }

  /*******************************COMPARE CALCULATED TOKEN BALANCES********************************/
  /**
  We can compare the results of _getTokenBalanceGivenInvariantAndAllOtherBalances in a similar way to calcOutGivenIn

  we need to know if its a metaStablePool or a regular stable pool


  For StablePools, we can compare _getTokenBalanceGivenInvariantAndAllOtherBalances => final balance out to actual balance 1 by:
  actual balance 1 - final balance out == out given in

  If this holds true, than the naive price should be manipulation resistant


  For MetaStablePools

  */
  function compareTokenBalances(IERC20[] memory /**tokens */, uint256[] memory _balances) internal view {
    (uint256 v, uint256 amp) = _priceFeed.getLastInvariant();

    uint256[] memory balances = _balances;

    uint256[] memory startingBalances = balances;

    uint256 tokenAmountIn = 1e18;
    uint256 tokenIndexIn = 0;
    uint256 tokenIndexOut = 1;

    balances[tokenIndexIn] = balances[tokenIndexIn] + (tokenAmountIn);

    uint256 finalBalanceOut = _getTokenBalanceGivenInvariantAndAllOtherBalances(amp, balances, v, tokenIndexOut);
    balances[tokenIndexIn] = balances[tokenIndexIn] - tokenAmountIn;

    //for MetaStablePools use calced balances for both
    uint256 result;
    if (startingBalances[1] < finalBalanceOut) {
      console.log("MetaStablePool");

      balances = startingBalances;
      balances[0] = _getTokenBalanceGivenInvariantAndAllOtherBalances(amp, balances, v, tokenIndexIn);
      balances[1] = _getTokenBalanceGivenInvariantAndAllOtherBalances(amp, balances, v, tokenIndexOut);

      balances[tokenIndexIn] = balances[tokenIndexIn] + (tokenAmountIn);

      finalBalanceOut = _getTokenBalanceGivenInvariantAndAllOtherBalances(amp, balances, v, tokenIndexOut);
      balances[tokenIndexIn] = balances[tokenIndexIn] - tokenAmountIn;

      result = startingBalances[1] - finalBalanceOut;
      console.log("Result: ", result);
      console.log("Compar: ", 1e18);
    } else {
      result = _getTokenBalanceGivenInvariantAndAllOtherBalances(amp, balances, v, tokenIndexOut) - finalBalanceOut;
      console.log("Result: ", result);
      console.log("Compar: ", 1e18);
    }

    //console.log("Final balance out: ", finalBalanceOut);
    //console.log("Actual1 minus final: ", startingBalances[1] - finalBalanceOut);
    //console.log("Compare to 1e18::::: ", 1e18);
    //console.log("Result: ", (startingBalances[1] - finalBalanceOut) - 1);
    //console.log(sub(sub(balances[tokenIndexOut], finalBalanceOut), 1));
    /**
    if (balances[tokenIndexOut] > finalBalanceOut) {
      return sub(sub(balances[tokenIndexOut], finalBalanceOut), 1);
    } else {
      return 0;
    }s
     */
  }

  /*******************************GET VIRTUAL PRICE USING outGivenIn********************************/
  //idea https://github.com/balancer/balancer-v2-monorepo/blob/d2794ef7d8f6d321cde36b7c536e8d51971688bd/pkg/vault/contracts/balances/TwoTokenPoolsBalance.sol#L334
  //decode cash vs managed to see if maybe the input balances are wrong somehow
  function compareOutGivenIn(IERC20[] memory /**tokens */, uint256[] memory balances) internal view {
    (uint256 v, uint256 amp) = _priceFeed.getLastInvariant();
    uint256 idxIn = 0;
    uint256 idxOut = 1;
    uint256 tokenAmountIn = 1e18;

    // console.log("Compare OUT GIVEN IN");
    //console.log("Token in : ", address(tokens[idxIn]));
    //console.log("Token out: ", address(tokens[idxOut]));

    console.log("Actual balance 0: ", balances[0]);
    console.log("Actual balance 1: ", balances[1]);

    console.log("Calced balance 0: ", _getTokenBalanceGivenInvariantAndAllOtherBalances(amp, balances, v, 0));
    console.log("Calced balance 1: ", _getTokenBalanceGivenInvariantAndAllOtherBalances(amp, balances, v, 1));
    uint256 outGivenIn = _calcOutGivenIn(amp, balances, idxIn, idxOut, tokenAmountIn, v);

    bool requireCalcedBalances = false;
    if (outGivenIn == 0) {
      console.log("OGI == 0, MetaStablePool");
      requireCalcedBalances = true;

      uint256[] memory calcedBalances = new uint256[](2);
      calcedBalances[0] = _getTokenBalanceGivenInvariantAndAllOtherBalances(amp, balances, v, 0);

      calcedBalances[1] = _getTokenBalanceGivenInvariantAndAllOtherBalances(amp, balances, v, 1);
      outGivenIn = _calcOutGivenIn(amp, calcedBalances, idxIn, idxOut, tokenAmountIn, v);
    }

    /**
    (uint256 calcedRate, uint256 expectedRate) = getOutGivenInRate(
      outGivenIn,
      assetOracles[address(tokens[0])].currentValue(),
      assetOracles[address(tokens[1])].currentValue()
    );
     */
    //simple out given in should be price 0 * expectedRate
    //uint256 expectedOutput = assetOracles[address(tokens[0])].currentValue() * expectedRate;
    //console.log("Expected Rate: ", expectedRate);
    //console.log("Out given in : ", outGivenIn);

    //console.log("Expected OGI : ", divide(expectedOutput, 1e36, 18));

    //console.log("Computed Rate: ", calcedRate);

    // console.log("Required calced balances?: ", requireCalcedBalances);
    console.log("OUT GIVEN IN RESULT: ", outGivenIn);
    //expected out given in should be price0 / price1

    //console.log("OUT GIVEN IN RESULT: ", outGivenIn); //102.386021679385123944
  }

  function getSimpleRate(uint256 price0, uint256 price1) internal pure returns (uint256 expectedRate) {
    //rate  p1 / p0
    expectedRate = divide(price1, price0, 18);
  }

  function getOutGivenInRate(
    uint256 ogi,
    uint256 price0,
    uint256 price1
  ) internal pure returns (uint256 calcedRate, uint256 expectedRate) {
    expectedRate = getSimpleRate(price0, price1);

    uint256 numerator = divide(ogi * price1, 1e18, 18);

    uint256 denominator = divide((1e18 * price0), 1e18, 18);

    calcedRate = divide(numerator, denominator, 18);
  }

  // Computes how many tokens can be taken out of a pool if `tokenAmountIn` are sent, given the current balances.
  // The amplification parameter equals: A n^(n-1)
  // The invariant should be rounded up.
  function _calcOutGivenIn(
    uint256 amplificationParameter,
    uint256[] memory balances,
    uint256 tokenIndexIn,
    uint256 tokenIndexOut,
    uint256 tokenAmountIn,
    uint256 invariant
  ) internal view returns (uint256) {
    /**************************************************************************************************************
        // outGivenIn token x for y - polynomial equation to solve                                                   //
        // ay = amount out to calculate                                                                              //
        // by = balance token out                                                                                    //
        // y = by - ay (finalBalanceOut)                                                                             //
        // D = invariant                                               D                     D^(n+1)                 //
        // A = amplification coefficient               y^2 + ( S - ----------  - D) * y -  ------------- = 0         //
        // n = number of tokens                                    (A * n^n)               A * n^2n * P              //
        // S = sum of final balances but y                                                                           //
        // P = product of final balances but y                                                                       //
        **************************************************************************************************************/

    balances[tokenIndexIn] = balances[tokenIndexIn] + (tokenAmountIn);

    uint256 finalBalanceOut = _getTokenBalanceGivenInvariantAndAllOtherBalances(
      amplificationParameter,
      balances,
      invariant,
      tokenIndexOut
    );
    balances[tokenIndexIn] = balances[tokenIndexIn] - tokenAmountIn;

    console.log("Final balance out: ", finalBalanceOut);

    if (balances[tokenIndexOut] > finalBalanceOut) {
      return sub(sub(balances[tokenIndexOut], finalBalanceOut), 1);
    } else {
      return 0;
    }
  }

  // This function calculates the balance of a given token (tokenIndex)
  // given all the other balances and the invariant
  function _getTokenBalanceGivenInvariantAndAllOtherBalances(
    uint256 amplificationParameter,
    uint256[] memory balances,
    uint256 invariant,
    uint256 tokenIndex
  ) internal pure returns (uint256) {
    // Rounds result up overall
    uint256 _AMP_PRECISION = 1e3;

    uint256 ampTimesTotal = amplificationParameter * balances.length;
    uint256 sum = balances[0];
    uint256 P_D = balances[0] * balances.length;
    for (uint256 j = 1; j < balances.length; j++) {
      P_D = divDown(mul(mul(P_D, balances[j]), balances.length), invariant);
      sum = add(sum, balances[j]);
    }
    // No need to use safe math, based on the loop above `sum` is greater than or equal to `balances[tokenIndex]`
    sum = sum - balances[tokenIndex];

    uint256 inv2 = mul(invariant, invariant);
    // We remove the balance from c by multiplying it
    uint256 c = mul(mul(divUp(inv2, mul(ampTimesTotal, P_D)), _AMP_PRECISION), balances[tokenIndex]);
    uint256 b = sum + mul(divDown(invariant, ampTimesTotal), _AMP_PRECISION);

    // We iterate to find the balance
    uint256 prevTokenBalance = 0;
    // We multiply the first iteration outside the loop with the invariant to set the value of the
    // initial approximation.
    uint256 tokenBalance = divUp(add(inv2, c), add(invariant, b));

    for (uint256 i = 0; i < 255; i++) {
      prevTokenBalance = tokenBalance;

      //tokenBalance = divUp(add(mul(tokenBalance, tokenBalance), c), sub(add(mul(tokenBalance, 2), b), invariant));

      uint256 numerator = (tokenBalance * tokenBalance) + c;
      uint256 denominator = ((tokenBalance * 2) + b) - invariant;

      tokenBalance = divUp(numerator, denominator);
      if (tokenBalance > prevTokenBalance) {
        if (tokenBalance - prevTokenBalance <= 1) {
          return tokenBalance;
        }
      } else if (prevTokenBalance - tokenBalance <= 1) {
        return tokenBalance;
      }
    }
    revert("STABLE_GET_BALANCE_DIDNT_CONVERGE");
  }

  function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0, "divDown: Zero division");
    return a / b;
  }

  function divUp(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0, "divUp: Zero division");

    if (a == 0) {
      return 0;
    } else {
      return 1 + (a - 1) / b;
    }
  }

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    require(a == 0 || c / a == b, "mul: overflow");
    return c;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, "ADD_OVERFLOW");
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a, "SUB_OVERFLOW");
    uint256 c = a - b;
    return c;
  }

  function divide(uint256 numerator, uint256 denominator, uint256 factor) internal pure returns (uint256 result) {
    uint256 q = (numerator / denominator) * 10 ** factor;
    uint256 r = ((numerator * 10 ** factor) / denominator) % 10 ** factor;

    return q + r;
  }

  /*******************************REQUIRED SETUP FUNCTIONS********************************/
  function sumBalances(IERC20[] memory tokens, uint256[] memory balances) internal view returns (uint256 total) {
    total = 0;
    for (uint256 i = 0; i < tokens.length; i++) {
      total += ((assetOracles[address(tokens[i])].currentValue() * balances[i]));
    }
  }

  function registerOracles(address[] memory _tokens, address[] memory _oracles) internal {
    for (uint256 i = 0; i < _tokens.length; i++) {
      assetOracles[_tokens[i]] = IOracleRelay(_oracles[i]);
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../oracle/IOracleRelay.sol";
import "../../_external/IERC20.sol";
import "../../_external/balancer/IBalancerVault.sol";

interface IBalancerPool {
  function getPoolId() external view returns (bytes32);

  function totalSupply() external view returns (uint256);

  function getLastInvariant() external view returns (uint256, uint256);
}

/*****************************************
 *
 * This relay gets a USD price for BPT LP token from a balancer MetaStablePool or StablePool
 * Comparing the results of outGivenIn to known safe oracles for the underlying assets,
 * we can safely determine if manipulation has transpired.
 * After confirming that the naive price is safe, we return the naive price.
 */

contract StablecoinTestOracle is IOracleRelay {
  

  function currentValue() external view override returns (uint256) {
    return 1e18;
  }


}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../oracle/IOracleRelay.sol";
import "../../_external/IERC20.sol";
import "../../_external/balancer/IBalancerVault.sol";

import "hardhat/console.sol";

interface IBalancerPool {
  function getPoolId() external view returns (bytes32);

  function totalSupply() external view returns (uint256);

  function getLastInvariant() external view returns (uint256, uint256);
}

/*****************************************
 *
 * This relay gets a USD price for BPT LP token from a balancer MetaStablePool or StablePool
 * Comparing the results of outGivenIn to known safe oracles for the underlying assets,
 * we can safely determine if manipulation has transpired.
 * After confirming that the naive price is safe, we return the naive price.
 */

contract StablePoolShowcase {
  bytes32 public immutable _poolId;

  uint256 public immutable _widthNumerator;
  uint256 public immutable _widthDenominator;

  IBalancerPool public immutable _priceFeed;

  mapping(address => IOracleRelay) public assetOracles;

  //Balancer Vault
  IBalancerVault public immutable VAULT;

  /**
   * @param pool_address - Balancer StablePool or MetaStablePool address
   * @param balancerVault is the address for the Balancer Vault contract
   * @param _tokens should be length 2 and contain both underlying assets for the pool
   * @param _oracles shoulb be length 2 and contain a safe external on-chain oracle for each @param _tokens in the same order
   * @notice the quotient of @param widthNumerator and @param widthDenominator should be the percent difference the exchange rate
   * is able to diverge from the expected exchange rate derived from just the external oracles
   */
  constructor(
    address pool_address,
    IBalancerVault balancerVault,
    address[] memory _tokens,
    address[] memory _oracles,
    uint256 widthNumerator,
    uint256 widthDenominator
  ) {
    _priceFeed = IBalancerPool(pool_address);

    _poolId = _priceFeed.getPoolId();

    VAULT = balancerVault;

    //register oracles
    for (uint256 i = 0; i < _tokens.length; i++) {
      assetOracles[_tokens[i]] = IOracleRelay(_oracles[i]);
    }

    _widthNumerator = widthNumerator;
    _widthDenominator = widthDenominator;
  }

  function currentValue() external view returns (uint256, uint256, uint256) {
    //check for reentrancy, further protects against manipulation
    ensureNotInVaultContext();

    (IERC20[] memory tokens, uint256[] memory balances /**uint256 lastChangeBlock */, ) = VAULT.getPoolTokens(_poolId);

    uint256 tokenAmountIn = 10e18;

    uint256 outGivenIn = getOutGivenIn(balances, tokenAmountIn);
    console.log("Out given in: ", outGivenIn);

    (uint256 calcedRate, uint256 expectedRate) = getExchangeRates(
      outGivenIn,
      tokenAmountIn,
      assetOracles[address(tokens[0])].currentValue(),
      assetOracles[address(tokens[1])].currentValue()
    );

    verifyExchangeRate(expectedRate, calcedRate);

    uint256 naivePrice = getNaivePrice(tokens, balances);

    return (naivePrice, expectedRate, calcedRate);
  }

  /*******************************GET & CHECK NAIVE PRICE********************************/
  ///@notice get the naive price by dividing the TVL/total BPT supply
  function getNaivePrice(IERC20[] memory tokens, uint256[] memory balances) internal view returns (uint256 naivePrice) {
    uint256 naiveTVL = 0;
    for (uint256 i = 0; i < tokens.length; i++) {
      naiveTVL += ((assetOracles[address(tokens[i])].currentValue() * balances[i]));
    }
    naivePrice = naiveTVL / _priceFeed.totalSupply();
    require(naivePrice > 0, "invalid naive price");
  }

  ///@notice ensure the exchange rate is within the expected range
  ///@notice ensuring the price is in bounds prevents price manipulation
  function verifyExchangeRate(uint256 expectedRate, uint256 outGivenInRate) internal view {
    uint256 delta = percentChange(expectedRate, outGivenInRate);
    uint256 buffer = divide(_widthNumerator, _widthDenominator, 18);

    console.log("ExpectedRate: ", expectedRate);
    console.log("CalculatRate: ", outGivenInRate);

    require(delta < buffer, "Price out of bounds");
  }

  /*******************************OUT GIVEN IN********************************/
  function getOutGivenIn(uint256[] memory balances, uint256 tokenAmountIn) internal view returns (uint256 outGivenIn) {
    (uint256 v, uint256 amp) = _priceFeed.getLastInvariant();
    uint256 idxIn = 0;
    uint256 idxOut = 1;

    //first calculate the balances, math doesn't work with reported balances on their own
    uint256[] memory calcedBalances = new uint256[](2);
    calcedBalances[0] = _getTokenBalanceGivenInvariantAndAllOtherBalances(amp, balances, v, 0);
    calcedBalances[1] = _getTokenBalanceGivenInvariantAndAllOtherBalances(amp, balances, v, 1);

    //get the ending balance for output token (always index 1)
    uint256 finalBalanceOut = _calcOutGivenIn(amp, calcedBalances, idxIn, idxOut, tokenAmountIn, v);

    //outGivenIn is a function of the actual starting balance, not the calculated balance
    outGivenIn = ((balances[idxOut] - finalBalanceOut) - 1);
  }

  // Computes how many tokens can be taken out of a pool if `tokenAmountIn` are sent, given the current balances.
  // The amplification parameter equals: A n^(n-1)
  // The invariant should be rounded up.
  function _calcOutGivenIn(
    uint256 amplificationParameter,
    uint256[] memory balances,
    uint256 tokenIndexIn,
    uint256 tokenIndexOut,
    uint256 tokenAmountIn,
    uint256 invariant
  ) internal pure returns (uint256) {
    /**************************************************************************************************************
    // outGivenIn token x for y - polynomial equation to solve                                                   //
    // ay = amount out to calculate                                                                              //
    // by = balance token out                                                                                    //
    // y = by - ay (finalBalanceOut)                                                                             //
    // D = invariant                                               D                     D^(n+1)                 //
    // A = amplification coefficient               y^2 + ( S - ----------  - D) * y -  ------------- = 0         //
    // n = number of tokens                                    (A * n^n)               A * n^2n * P              //
    // S = sum of final balances but y                                                                           //
    // P = product of final balances but y                                                                       //
    **************************************************************************************************************/

    balances[tokenIndexIn] = balances[tokenIndexIn] + (tokenAmountIn);

    uint256 finalBalanceOut = _getTokenBalanceGivenInvariantAndAllOtherBalances(
      amplificationParameter,
      balances,
      invariant,
      tokenIndexOut
    );
    balances[tokenIndexIn] = balances[tokenIndexIn] - tokenAmountIn;

    //we simply return finalBalanceOut here, and get outGivenIn elsewhere
    return finalBalanceOut;
    /**
    if (balances[tokenIndexOut] > finalBalanceOut) {
      return sub(sub(balances[tokenIndexOut], finalBalanceOut), 1);
    } else {
      return 0;
    }
     */
  }

  // This function calculates the balance of a given token (tokenIndex)
  // given all the other balances and the invariant
  function _getTokenBalanceGivenInvariantAndAllOtherBalances(
    uint256 amplificationParameter,
    uint256[] memory balances,
    uint256 invariant,
    uint256 tokenIndex
  ) internal pure returns (uint256) {
    // Rounds result up overall
    uint256 _AMP_PRECISION = 1e3;

    uint256 ampTimesTotal = amplificationParameter * balances.length;
    uint256 sum = balances[0];
    uint256 P_D = balances[0] * balances.length;
    for (uint256 j = 1; j < balances.length; j++) {
      P_D = (((P_D * balances[j]) * balances.length) / invariant);
      sum = sum + balances[j];
    }
    // No need to use safe math, based on the loop above `sum` is greater than or equal to `balances[tokenIndex]`
    sum = sum - balances[tokenIndex];

    uint256 inv2 = (invariant * invariant);
    // We remove the balance from c by multiplying it
    uint256 c = ((divUp(inv2, (ampTimesTotal * P_D)) * _AMP_PRECISION) * balances[tokenIndex]);
    uint256 b = sum + ((invariant / ampTimesTotal) * _AMP_PRECISION);

    // We iterate to find the balance
    uint256 prevTokenBalance = 0;
    // We multiply the first iteration outside the loop with the invariant to set the value of the
    // initial approximation.
    uint256 tokenBalance = divUp((inv2 + c), (invariant + b));

    for (uint256 i = 0; i < 255; i++) {
      prevTokenBalance = tokenBalance;

      uint256 numerator = (tokenBalance * tokenBalance) + c;
      uint256 denominator = ((tokenBalance * 2) + b) - invariant;

      tokenBalance = divUp(numerator, denominator);
      if (tokenBalance > prevTokenBalance) {
        if (tokenBalance - prevTokenBalance <= 1) {
          return tokenBalance;
        }
      } else if (prevTokenBalance - tokenBalance <= 1) {
        return tokenBalance;
      }
    }
    revert("STABLE_GET_BALANCE_DIDNT_CONVERGE");
  }

  //https://github.com/balancer/balancer-v2-monorepo/pull/2418/files#diff-36f155e03e561d19a594fba949eb1929677863e769bd08861397f4c7396b0c71R37
  function ensureNotInVaultContext() internal view {
    // Perform the following operation to trigger the Vault's reentrancy guard:
    //
    // IVault.UserBalanceOp[] memory noop = new IVault.UserBalanceOp[](0);
    // _vault.manageUserBalance(noop);
    //
    // However, use a static call so that it can be a view function (even though the function is non-view).
    // This allows the library to be used more widely, as some functions that need to be protected might be
    // view.
    //
    // This staticcall always reverts, but we need to make sure it doesn't fail due to a re-entrancy attack.
    // Staticcalls consume all gas forwarded to them on a revert. By default, almost the entire available gas
    // is forwarded to the staticcall, causing the entire call to revert with an 'out of gas' error.
    //
    // We set the gas limit to 100k, but the exact number doesn't matter because view calls are free, and non-view
    // calls won't waste the entire gas limit on a revert. `manageUserBalance` is a non-reentrant function in the
    // Vault, so calling it invokes `_enterNonReentrant` in the `ReentrancyGuard` contract, reproduced here:
    //
    //    function _enterNonReentrant() private {
    //        // If the Vault is actually being reentered, it will revert in the first line, at the `_require` that
    //        // checks the reentrancy flag, with "BAL#400" (corresponding to Errors.REENTRANCY) in the revertData.
    //        // The full revertData will be: `abi.encodeWithSignature("Error(string)", "BAL#400")`.
    //        _require(_status != _ENTERED, Errors.REENTRANCY);
    //
    //        // If the Vault is not being reentered, the check above will pass: but it will *still* revert,
    //        // because the next line attempts to modify storage during a staticcall. However, this type of
    //        // failure results in empty revertData.
    //        _status = _ENTERED;
    //    }
    //
    // So based on this analysis, there are only two possible revertData values: empty, or abi.encoded BAL#400.
    //
    // It is of course much more bytecode and gas efficient to check for zero-length revertData than to compare it
    // to the encoded REENTRANCY revertData.
    //
    // While it should be impossible for the call to fail in any other way (especially since it reverts before
    // `manageUserBalance` even gets called), any other error would generate non-zero revertData, so checking for
    // empty data guards against this case too.

    (, bytes memory revertData) = address(VAULT).staticcall{gas: 100_000}(
      abi.encodeWithSelector(VAULT.manageUserBalance.selector, 0)
    );

    require(revertData.length == 0, "Errors.REENTRANCY");
  }

  /*******************************PURE MATH FUNCTIONS********************************/
  ///@notice get exchange rates
  function getExchangeRates(
    uint256 outGivenIn,
    uint256 tokenAmountIn,
    uint256 price0,
    uint256 price1
  ) internal pure returns (uint256 calcedRate, uint256 expectedRate) {
    expectedRate = divide(price1, price0, 18);

    uint256 numerator = divide(outGivenIn * price1, 1e18, 18);

    uint256 denominator = divide((tokenAmountIn * price0), 1e18, 18);

    calcedRate = divide(numerator, denominator, 18);
  }

  ///@notice get the percent deviation from a => b as a decimal e18
  function percentChange(uint256 a, uint256 b) public pure returns (uint256 delta) {
    uint256 max = a > b ? a : b;
    uint256 min = b != max ? b : a;
    delta = divide((max - min), min, 18);
  }

  ///@notice floating point division at @param factor scale
  function divide(uint256 numerator, uint256 denominator, uint256 factor) internal pure returns (uint256 result) {
    uint256 q = (numerator / denominator) * 10 ** factor;
    uint256 r = ((numerator * 10 ** factor) / denominator) % 10 ** factor;

    return q + r;
  }

  function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 product = a * b;
    require(a == 0 || product / a == b, "overflow");

    return product / 1e18;
  }

  function divUp(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0, "divUp: Zero division");

    if (a == 0) {
      return 0;
    } else {
      return 1 + (a - 1) / b;
    }
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./IBaseOracle.sol";

contract UsingBaseOracle {
  IBaseOracle public immutable base; // Base oracle source

  constructor(IBaseOracle _base) {
    base = _base;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../oracle/IOracleRelay.sol";

contract BogusOracle is IOracleRelay {
  function currentValue() external pure override returns (uint256) {
    return 5e17;
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.9;

interface IGovernancePowerDelegationToken {
  enum DelegationType {
    VOTING_POWER,
    PROPOSITION_POWER
  }

  /**
   * @dev emitted when a user delegates to another
   * @param delegator the delegator
   * @param delegatee the delegatee
   * @param delegationType the type of delegation (VOTING_POWER, PROPOSITION_POWER)
   **/
  event DelegateChanged(address indexed delegator, address indexed delegatee, DelegationType delegationType);

  /**
   * @dev emitted when an action changes the delegated power of a user
   * @param user the user which delegated power has changed
   * @param amount the amount of delegated power for the user
   * @param delegationType the type of delegation (VOTING_POWER, PROPOSITION_POWER)
   **/
  event DelegatedPowerChanged(address indexed user, uint256 amount, DelegationType delegationType);

  /**
   * @dev delegates the specific power to a delegatee
   * @param delegatee the user which delegated power has changed
   * @param delegationType the type of delegation (VOTING_POWER, PROPOSITION_POWER)
   **/
  function delegateByType(address delegatee, DelegationType delegationType) external;

  /**
   * @dev delegates all the powers to a specific user
   * @param delegatee the user to which the power will be delegated
   **/
  function delegate(address delegatee) external;

  /**
   * @dev returns the delegatee of an user
   * @param delegator the address of the delegator
   **/
  function getDelegateeByType(address delegator, DelegationType delegationType) external view returns (address);

  /**
   * @dev returns the current delegated power of a user. The current power is the
   * power delegated at the time of the last snapshot
   * @param user the user
   **/
  function getPowerCurrent(address user, DelegationType delegationType) external view returns (uint256);

  /**
   * @dev returns the delegated power of a user at a certain block
   * @param user the user
   **/
  function getPowerAtBlock(
    address user,
    uint256 blockNumber,
    DelegationType delegationType
  ) external view returns (uint256);

  /**
   * @dev returns the total supply at a certain block number
   **/
  function totalSupplyAt(uint256 blockNumber) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../_external/IERC20Metadata.sol";

interface ILido is IERC20Metadata {
  function depositBufferedEther() external;

  function submit(address _referral) external payable returns (uint256);

  function getOracle() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../_external/IERC20Metadata.sol";

interface ILidoOracle is IERC20Metadata {
  function reportBeacon(uint256 _epochId, uint64 _beaconBalance, uint32 _beaconValidators) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ITestOracle {
  // The three values that can be queried:
  //
  // - PAIR_PRICE: the price of the tokens in the Pool, expressed as the price of the second token in units of the
  //   first token. For example, if token A is worth $2, and token B is worth $4, the pair price will be 2.0.
  //   Note that the price is computed *including* the tokens decimals. This means that the pair price of a Pool with
  //   DAI and USDC will be close to 1.0, despite DAI having 18 decimals and USDC 6.
  //
  // - BPT_PRICE: the price of the Pool share token (BPT), in units of the first token.
  //   Note that the price is computed *including* the tokens decimals. This means that the BPT price of a Pool with
  //   USDC in which BPT is worth $5 will be 5.0, despite the BPT having 18 decimals and USDC 6.
  //
  // - INVARIANT: the value of the Pool's invariant, which serves as a measure of its liquidity.
  enum Variable {
    PAIR_PRICE,
    BPT_PRICE,
    INVARIANT
  }

  struct OracleAverageQuery {
    Variable variable;
    uint256 secs;
    uint256 ago;
  }

  function getTimeWeightedAverage(OracleAverageQuery[] memory queries) external view returns (uint256[] memory);

  function getAuthorizer() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable comprehensive-interface
contract TESTERC20 {
  mapping(address => uint256) private _balances;

  mapping(address => mapping(address => uint256)) private _allowances;

  uint256 private _totalSupply;

  string private _name;
  string private _symbol;
  uint8 private _decimals;
  uint64 private _givemul;

  mapping(address => address) public _delegations;

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);

  constructor(string memory name_, string memory symbol_, uint8 decimals_, uint64 givemul_) {
    _name = name_;
    _symbol = symbol_;
    _decimals = decimals_;
    _givemul = givemul_;
  }

  /**
   * @dev Returns the name of the token.
   */
  function name() public view returns (string memory) {
    return _name;
  }

  function symbol() public view returns (string memory) {
    return _symbol;
  }

  function decimals() public view returns (uint8) {
    return _decimals;
  }

  function publicMint() external {
    _mint(msg.sender, (10 ** _decimals) * _givemul);
  }

  function delegate(address a) public {
    _delegations[msg.sender] = a;
  }

  /**
   * @dev See {IERC20-totalSupply}.
   */
  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  /**
   * @dev See {IERC20-balanceOf}.
   */
  function balanceOf(address account) public view returns (uint256) {
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
  function transfer(address to, uint256 amount) public returns (bool) {
    address owner = msg.sender;
    _transfer(owner, to, amount);
    return true;
  }

  /**
   * @dev See {IERC20-allowance}.
   */
  function allowance(address owner, address spender) public view returns (uint256) {
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
  function approve(address spender, uint256 amount) public returns (bool) {
    address owner = msg.sender;
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
  function transferFrom(address from, address to, uint256 amount) public returns (bool) {
    address spender = msg.sender;
    _spendAllowance(from, spender, amount);
    _transfer(from, to, amount);
    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
    address owner = msg.sender;
    _approve(owner, spender, allowance(owner, spender) + addedValue);
    return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
    address owner = msg.sender;
    uint256 currentAllowance = allowance(owner, spender);
    require(currentAllowance >= subtractedValue, "decreased allowance below zero");
    unchecked {
      _approve(owner, spender, currentAllowance - subtractedValue);
    }

    return true;
  }

  function _transfer(address from, address to, uint256 amount) internal {
    require(from != address(0), "transfer from the zero address");
    require(to != address(0), "transfer to the zero address");

    _beforeTokenTransfer(from, to, amount);

    uint256 fromBalance = _balances[from];
    require(fromBalance >= amount, "transfer amount exceeds balance");
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
  function _mint(address account, uint256 amount) internal {
    require(account != address(0), "mint to the zero address");

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
  function _burn(address account, uint256 amount) internal {
    require(account != address(0), "burn from the zero address");

    _beforeTokenTransfer(account, address(0), amount);

    uint256 accountBalance = _balances[account];
    require(accountBalance >= amount, "burn amount exceeds balance");
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
  function _approve(address owner, address spender, uint256 amount) internal {
    require(owner != address(0), "approve from the zero address");
    require(spender != address(0), "approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  /**
   * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
   *
   * Does not update the allowance amount in case of infinite allowance.
   * Revert if not enough allowance is available.
   *
   * Might emit an {Approval} event.
   */
  function _spendAllowance(address owner, address spender, uint256 amount) internal {
    uint256 currentAllowance = allowance(owner, spender);
    if (currentAllowance != type(uint256).max) {
      require(currentAllowance >= amount, "insufficient allowance");
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
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal {}

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
  function _afterTokenTransfer(address from, address to, uint256 amount) internal {}
}

// solhint-enable comprehensive-interface

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../_external/IERC20Metadata.sol";
import "../../_external/openzeppelin/ERC20Upgradeable.sol";
import "../../_external/openzeppelin/OwnableUpgradeable.sol";
import "../../_external/openzeppelin/Initializable.sol";

import {SafeERC20} from "../../_external/extensions/SafeERC20.sol";

import "hardhat/console.sol";

/// @title CappedRebaseToken - uses logic from Wrapped USDI which uses logic from WAMPL
/// @notice handles all minting/burning of underlying
/// @dev extends ierc20 upgradable
contract CappedRebaseToken is Initializable, OwnableUpgradeable, ERC20Upgradeable {
  using SafeERC20 for IERC20;

  IERC20Metadata public _underlying;
  uint8 private _underlying_decimals;

  ///@notice this cap is represented in underlying amount, not the wrapped version issued by this contract
  uint256 public _cap;

  /// @notice This must remain constant for conversions to work, the cap is separate
  uint256 public constant MAX_SUPPLY = 10000000 * (10 ** 18); // 10 M

  /// @notice initializer for contract
  /// @param name_ name of capped token
  /// @param symbol_ symbol of capped token
  /// @param underlying_ the address of underlying
  function initialize(string memory name_, string memory symbol_, address underlying_) public initializer {
    __Ownable_init();
    __ERC20_init(name_, symbol_);
    _underlying = IERC20Metadata(underlying_);
    _underlying_decimals = _underlying.decimals();
  }

  /// @notice getter for address of the underlying currency, or underlying
  /// @return decimals for of underlying currency
  function underlyingAddress() public view returns (address) {
    return address(_underlying);
  }

  ///////////////////////// CAP FUNCTIONS /////////////////////////
  /// @notice get the Cap
  /// @return cap
  function getCap() public view returns (uint256) {
    return _cap;
  }

  /// @notice set the Cap
  function setCap(uint256 cap_) external onlyOwner {
    _cap = cap_;
  }

  /// @notice check the incoming supply of underlying against the cap, which is also expressed in underlying units
  function checkCap(uint256 wrappedAmount) internal view {
    uint256 incomingUnderlyingAmount = _capped_to_underlying(wrappedAmount, _underlying.totalSupply());

    uint256 currentUnderlyingSupply = _capped_to_underlying(ERC20Upgradeable.totalSupply(), _underlying.totalSupply());

    require(currentUnderlyingSupply + incomingUnderlyingAmount <= _cap, "cap reached");
  }

  function decimals() public pure override returns (uint8) {
    return 18;
  }

  function underlyingScalar() public view returns (uint256) {
    return (10 ** (18 - _underlying_decimals));
  }

  /// @notice get underlying ratio
  /// @return e18_underlying_ratio underlying ratio of coins
  function underlyingRatio() public view returns (uint256 e18_underlying_ratio) {
    e18_underlying_ratio = (((_underlying.balanceOf(address(this)) * underlyingScalar()) * 1e18) /
      _underlying.totalSupply());
  }

  ///////////////////////// WRAP AND UNWRAP /////////////////////////

  //cappedTokenUnits

  /// @notice Transfers underlyingAmount from {msg.sender} and mints cappedTokenAmount.
  ///
  /// @param cappedTokenAmount The amount of cappedTokens to mint.
  /// @return The amount of underlyingAmount deposited.
  function mint(uint256 cappedTokenAmount) external returns (uint256) {
    checkCap(cappedTokenAmount);
    uint256 underlyingAmount = _capped_to_underlying(cappedTokenAmount, _query_Underlying_Supply());
    _deposit(_msgSender(), _msgSender(), underlyingAmount, cappedTokenAmount);
    return underlyingAmount;
  }

  /// @notice Transfers underlyingAmount from {msg.sender} and mints cappedTokenAmount,
  ///         to the specified beneficiary.
  ///
  /// @param to The beneficiary wallet.
  /// @param cappedTokenAmount The amount of cappedTokenAmount to mint.
  /// @return The amount of underlyingAmount deposited.
  function mintFor(address to, uint256 cappedTokenAmount) external returns (uint256) {
    checkCap(cappedTokenAmount);
    uint256 underlyingAmount = _capped_to_underlying(cappedTokenAmount, _query_Underlying_Supply());
    _deposit(_msgSender(), to, underlyingAmount, cappedTokenAmount);
    return underlyingAmount;
  }

  /// @notice Burns cappedTokenAmount from {msg.sender} and transfers underlyingAmount back.
  ///
  /// @param cappedTokenAmount The amount of cappedTokenAmount to burn.
  /// @return The amount of usdi withdrawn.
  function burn(uint256 cappedTokenAmount) external returns (uint256) {
    uint256 underlyingAmount = _capped_to_underlying(cappedTokenAmount, _query_Underlying_Supply());
    _withdraw(_msgSender(), _msgSender(), underlyingAmount, cappedTokenAmount);
    return underlyingAmount;
  }

  /// @notice Burns cappedTokenAmount from {msg.sender} and transfers underlyingAmount back,
  ///         to the specified beneficiary.
  ///
  /// @param to The beneficiary wallet.
  /// @param cappedTokenAmount The amount of cappedTokenAmount to burn.
  /// @return The amount of underlyingAmount withdrawn.
  function burnTo(address to, uint256 cappedTokenAmount) external returns (uint256) {
    uint256 underlyingAmount = _capped_to_underlying(cappedTokenAmount, _query_Underlying_Supply());
    _withdraw(_msgSender(), to, underlyingAmount, cappedTokenAmount);
    return underlyingAmount;
  }

  /// @notice Burns all cappedTokenAmount from {msg.sender} and transfers underlyingAmount back.
  ///
  /// @return The amount of underlyingAmount withdrawn.
  function burnAll() external returns (uint256) {
    uint256 cappedTokenAmount = balanceOf(_msgSender());
    uint256 underlyingAmount = _capped_to_underlying(cappedTokenAmount, _query_Underlying_Supply());
    _withdraw(_msgSender(), _msgSender(), underlyingAmount, cappedTokenAmount);
    return underlyingAmount;
  }

  /// @notice Burns all cappedTokenAmount from {msg.sender} and transfers underlyingAmount back,
  ///         to the specified beneficiary.
  ///
  /// @param to The beneficiary wallet.
  /// @return The amount of underlyingAmount withdrawn.
  function burnAllTo(address to) external returns (uint256) {
    uint256 cappedTokenAmount = balanceOf(_msgSender());
    uint256 underlyingAmount = _capped_to_underlying(cappedTokenAmount, _query_Underlying_Supply());
    _withdraw(_msgSender(), to, underlyingAmount, cappedTokenAmount);
    return underlyingAmount;
  }

  //underlying units

  /// @notice Transfers underlyingAmount from {msg.sender} and mints cappedTokenAmount.
  ///
  /// @param underlyingAmount The amount of underlyingAmount to deposit.
  /// @return The amount of cappedTokenAmount minted.
  function deposit(uint256 underlyingAmount) external returns (uint256) {
    checkCap(underlyingAmount);
    uint256 cappedTokenAmount = _underlying_to_capped(underlyingAmount, _query_Underlying_Supply());
    _deposit(_msgSender(), _msgSender(), underlyingAmount, cappedTokenAmount);
    return cappedTokenAmount;
  }

  /// @notice Transfers underlyingAmount from {msg.sender} and mints cappedTokenAmount,
  ///         to the specified beneficiary.
  ///
  /// @param to The beneficiary wallet.
  /// @param underlyingAmount The amount of underlyingAmount to deposit.
  /// @return The amount of cappedTokenAmount minted.
  function depositFor(address to, uint256 underlyingAmount) external returns (uint256) {
    checkCap(underlyingAmount);
    uint256 cappedTokenAmount = _underlying_to_capped(underlyingAmount, _query_Underlying_Supply());
    _deposit(_msgSender(), to, underlyingAmount, cappedTokenAmount);
    return cappedTokenAmount;
  }

  /// @notice Burns cappedTokenAmount from {msg.sender} and transfers underlyingAmount back.
  ///
  /// @param underlyingAmount The amount of underlyingAmount to withdraw.
  /// @return The amount of burnt cappedTokenAmount.
  function withdraw(uint256 underlyingAmount) external returns (uint256) {
    uint256 cappedTokenAmount = _underlying_to_capped(underlyingAmount, _query_Underlying_Supply());
    _withdraw(_msgSender(), _msgSender(), underlyingAmount, cappedTokenAmount);
    return cappedTokenAmount;
  }

  /// @notice Burns cappedTokenAmount from {msg.sender} and transfers underlyingAmount back,
  ///         to the specified beneficiary.
  ///
  /// @param to The beneficiary wallet.
  /// @param underlyingAmount The amount of underlyingAmount to withdraw.
  /// @return The amount of burnt cappedTokenAmount.
  function withdrawTo(address to, uint256 underlyingAmount) external returns (uint256) {
    uint256 cappedTokenAmount = _underlying_to_capped(underlyingAmount, _query_Underlying_Supply());
    _withdraw(_msgSender(), to, underlyingAmount, cappedTokenAmount);
    return cappedTokenAmount;
  }

  /// @notice Burns all cappedTokenAmount from {msg.sender} and transfers underlyingAmount back.
  ///
  /// @return The amount of burnt cappedTokenAmount.
  function withdrawAll() external returns (uint256) {
    uint256 cappedTokenAmount = balanceOf(_msgSender());
    uint256 underlyingAmount = _capped_to_underlying(cappedTokenAmount, _query_Underlying_Supply());

    require(underlyingAmount <= _underlying.balanceOf(address(this)), "Insufficient funds in bank");

    _withdraw(_msgSender(), _msgSender(), underlyingAmount, cappedTokenAmount);
    return cappedTokenAmount;
  }

  /// @notice Burns all cappedTokenAmount from {msg.sender} and transfers underlyingAmount back,
  ///         to the specified beneficiary.
  ///
  /// @param to The beneficiary wallet.
  /// @return The amount of burnt cappedTokenAmount.
  function withdrawAllTo(address to) external returns (uint256) {
    uint256 cappedTokenAmount = balanceOf(_msgSender());
    uint256 underlyingAmount = _capped_to_underlying(cappedTokenAmount, _query_Underlying_Supply());
    _withdraw(_msgSender(), to, underlyingAmount, cappedTokenAmount);
    return cappedTokenAmount;
  }

  ///////////////////////// VIEW FUNCTIONS /////////////////////////

  /// @return The address of the underlying "wrapped" token ie) usdi.
  function underlying() external view returns (address) {
    return address(_underlying);
  }

  /// @return The total underlyingAmount held by this contract.
  function totalUnderlying() external view returns (uint256) {
    return _underlying_to_capped(totalSupply(), _query_Underlying_Supply());
  }

  /// @param owner The account address.
  /// @return The usdi balance redeemable by the owner.
  function balanceOfUnderlying(address owner) external view returns (uint256) {
    return _capped_to_underlying(balanceOf(owner), _query_Underlying_Supply());
  }

  /// @param underlyingAmount The amount of usdi tokens.
  /// @return The amount of wUSDI tokens exchangeable.
  function underlyingToWrapper(uint256 underlyingAmount) external view returns (uint256) {
    return _underlying_to_capped(underlyingAmount, _query_Underlying_Supply());
  }

  /// @param cappedAmount The amount of wUSDI tokens.
  /// @return The amount of usdi tokens exchangeable.
  function wrapperToUnderlying(uint256 cappedAmount) external view returns (uint256) {
    return _capped_to_underlying(cappedAmount, _query_Underlying_Supply());
  }

  ///////////////////////// CONVERSION MATH /////////////////////////

  /// @dev Queries the current total supply of underlying rebase token.
  function _query_Underlying_Supply() private view returns (uint256) {
    return _underlying.totalSupply();
  }

  /// @notice assumes underlying is decimal 18
  function _underlying_to_capped(
    uint256 underlyingAmount,
    uint256 underlyingTotalSupply
  ) private pure returns (uint256) {
    return (underlyingAmount * MAX_SUPPLY) / underlyingTotalSupply;
  }

  function _capped_to_underlying(uint256 cappedAmount, uint256 underlyingTotalSupply) private pure returns (uint256) {
    return (cappedAmount * underlyingTotalSupply) / MAX_SUPPLY;
  }

  /// @dev Internal helper function to handle deposit state change.
  /// @param from The initiator wallet.
  /// @param to The beneficiary wallet.
  /// @param underlyingAmount The amount of underlyingAmount to deposit.
  /// @param cappedTokenAmount The amount of cappedTokenAmount to mint.
  function _deposit(address from, address to, uint256 underlyingAmount, uint256 cappedTokenAmount) private {
    IERC20(address(_underlying)).safeTransferFrom(from, address(this), underlyingAmount);

    _mint(to, cappedTokenAmount);
  }

  /// @dev Internal helper function to handle withdraw state change.
  /// @param from The initiator wallet.
  /// @param to The beneficiary wallet.
  /// @param underlyingAmount The amount of underlyingAmount to withdraw.
  /// @param cappedTokenAmount The amount of cappedTokenAmount to burn.
  function _withdraw(address from, address to, uint256 underlyingAmount, uint256 cappedTokenAmount) private {
    _burn(from, cappedTokenAmount);

    IERC20(address(_underlying)).safeTransfer(to, underlyingAmount);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../_external/IERC20Metadata.sol";
import "../../_external/openzeppelin/ERC20Upgradeable.sol";
import "../../_external/openzeppelin/OwnableUpgradeable.sol";
import "../../_external/openzeppelin/Initializable.sol";
import "../../_external/IERC20Metadata.sol";

import {SafeERC20} from "../../_external/extensions/SafeERC20.sol";

interface IStETH is IERC20 {
  function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);

  function getSharesByPooledEth(uint256 _pooledEthAmount) external view returns (uint256);

  function submit(address _referral) external payable returns (uint256);
}

/**
 * @title StETH token wrapper with static balances.
 * @dev It's an ERC20 token that represents the account's share of the total
 * supply of stETH tokens. WstETH token's balance only changes on transfers,
 * unlike StETH that is also changed when oracles report staking rewards and
 * penalties. It's a "power user" token for DeFi protocols which don't
 * support rebasable tokens.
 *
 * The contract is also a trustless wrapper that accepts stETH tokens and mints
 * wstETH in return. Then the user unwraps, the contract burns user's wstETH
 * and sends user locked stETH in return.
 *
 * The contract provides the staking shortcut: user can send ETH with regular
 * transfer and get wstETH in return. The contract will send ETH to Lido submit
 * method, staking it and wrapping the received stETH.
 *
 */
contract CappedSTETH is Initializable, OwnableUpgradeable, ERC20Upgradeable {
  using SafeERC20 for IERC20;

  IStETH public stETH;

  IERC20Metadata public _underlying;
  uint8 private _underlying_decimals;

  uint256 public _cap;

  /// @notice initializer for contract
  /// @param name_ name of capped token
  /// @param symbol_ symbol of capped token
  /// @param underlying_ the address of underlying
  function initialize(string memory name_, string memory symbol_, address underlying_) public initializer {
    __Ownable_init();
    __ERC20_init(name_, symbol_);
    _underlying = IERC20Metadata(underlying_);
    _underlying_decimals = _underlying.decimals();

    stETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
  }

  /// @notice getter for address of the underlying currency, or underlying
  /// @return decimals for of underlying currency
  function underlyingAddress() public view returns (address) {
    return address(_underlying);
  }

  ///////////////////////// CAP FUNCTIONS /////////////////////////

  /// @notice get the Cap
  /// @return cap
  function getCap() public view returns (uint256) {
    return _cap;
  }

  /// @notice set the Cap
  function setCap(uint256 cap_) external onlyOwner {
    _cap = cap_;
  }

  function checkCap(uint256 amount_) internal view {
    require(ERC20Upgradeable.totalSupply() + amount_ <= _cap, "cap reached");
  }

  function decimals() public pure override returns (uint8) {
    return 18;
  }

  ///////////////////////// WSTETH FUNCTIONS /////////////////////////

  /**
   * @notice Exchanges stETH to wstETH
   * @param _stETHAmount amount of stETH to wrap in exchange for wstETH
   * @dev Requirements:
   *  - `_stETHAmount` must be non-zero
   *  - msg.sender must approve at least `_stETHAmount` stETH to this
   *    contract.
   *  - msg.sender must have at least `_stETHAmount` of stETH.
   * User should first approve _stETHAmount to the WstETH contract
   * @return Amount of wstETH user receives after wrap
   */
  function wrap(uint256 _stETHAmount) external returns (uint256) {
    checkCap(_stETHAmount);
    require(_stETHAmount > 0, "wstETH: can't wrap zero stETH");
    uint256 wstETHAmount = stETH.getSharesByPooledEth(_stETHAmount);
    _mint(msg.sender, wstETHAmount);
    stETH.transferFrom(msg.sender, address(this), _stETHAmount);
    return wstETHAmount;
  }

  /**
   * @notice Exchanges wstETH to stETH
   * @param _wstETHAmount amount of wstETH to uwrap in exchange for stETH
   * @dev Requirements:
   *  - `_wstETHAmount` must be non-zero
   *  - msg.sender must have at least `_wstETHAmount` wstETH.
   * @return Amount of stETH user receives after unwrap
   */
  function unwrap(uint256 _wstETHAmount) external returns (uint256) {
    require(_wstETHAmount > 0, "wstETH: zero amount unwrap not allowed");
    uint256 stETHAmount = stETH.getPooledEthByShares(_wstETHAmount);
    _burn(msg.sender, _wstETHAmount);
    stETH.transfer(msg.sender, stETHAmount);
    return stETHAmount;
  }

  /**
   * @notice Shortcut to stake ETH and auto-wrap returned stETH
   receive() external payable {
    uint256 shares = stETH.submit{value: msg.value}(address(0));
    _mint(msg.sender, shares);
  }
   */

  /**
   * @notice Get amount of wstETH for a given amount of stETH
   * @param _stETHAmount amount of stETH
   * @return Amount of wstETH for a given stETH amount
   */
  function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256) {
    return stETH.getSharesByPooledEth(_stETHAmount);
  }

  /**
   * @notice Get amount of stETH for a given amount of wstETH
   * @param _wstETHAmount amount of wstETH
   * @return Amount of stETH for a given wstETH amount
   */
  function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256) {
    return stETH.getPooledEthByShares(_wstETHAmount);
  }

  /**
   * @notice Get amount of stETH for a one wstETH
   * @return Amount of stETH for 1 wstETH
   */
  function stEthPerToken() external view returns (uint256) {
    return stETH.getPooledEthByShares(1 ether);
  }

  /**
   * @notice Get amount of wstETH for a one stETH
   * @return Amount of wstETH for a 1 stETH
   */
  function tokensPerStEth() external view returns (uint256) {
    return stETH.getSharesByPooledEth(1 ether);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../_external/IERC20Metadata.sol";
import "../../_external/openzeppelin/ERC20Upgradeable.sol";
import "../../_external/openzeppelin/OwnableUpgradeable.sol";
import "../../_external/openzeppelin/Initializable.sol";

/// @title CappedToken
/// @notice handles all minting/burning of underlying
/// @dev extends ierc20 upgradable
contract CappedToken is Initializable, OwnableUpgradeable, ERC20Upgradeable {
  IERC20Metadata public _underlying;
  uint8 private _underlying_decimals;

  /// @notice CAP is in units of the CAP token,so 18 decimals.
  ///         not the underlying!!!!!!!!!
  uint256 public _cap;

  /// @notice initializer for contract
  /// @param name_ name of capped token
  /// @param symbol_ symbol of capped token
  /// @param underlying_ the address of underlying
  function initialize(string memory name_, string memory symbol_, address underlying_) public initializer {
    __Ownable_init();
    __ERC20_init(name_, symbol_);
    _underlying = IERC20Metadata(underlying_);
    _underlying_decimals = _underlying.decimals();
  }

  /// @notice 18 decimal erc20 spec should have been written into the fucking standard
  function decimals() public pure override returns (uint8) {
    return 18;
  }

  /// @notice get the Cap
  /// @return cap uint256
  function getCap() public view returns (uint256) {
    return _cap;
  }

  /// @notice set the Cap
  function setCap(uint256 cap_) external onlyOwner {
    _cap = cap_;
  }

  function checkCap(uint256 amount_) internal view {
    require(ERC20Upgradeable.totalSupply() + amount_ <= _cap, "cap reached");
  }

  function underlyingScalar() public view returns (uint256) {
    return (10 ** (18 - _underlying_decimals));
  }

  /// @notice get underlying ratio
  /// @return amount amount of this CappedToken
  function underlyingToCappedAmount(uint256 underlying_amount) internal view returns (uint256 amount) {
    amount = underlying_amount * underlyingScalar();
  }

  function cappedAmountToUnderlying(uint256 underlying_amount) internal view returns (uint256 amount) {
    amount = underlying_amount / underlyingScalar();
  }

  /// @notice deposit _underlying to mint CappedToken
  /// @param underlying_amount amount of underlying to deposit
  /// @param target recipient of tokens
  function deposit(uint256 underlying_amount, address target) public {
    // scale the decimals to THIS token decimals, or 1e18. see underlyingToCappedAmount
    uint256 amount = underlyingToCappedAmount(underlying_amount);
    require(amount > 0, "Cannot deposit 0");
    // check cap
    checkCap(amount);
    // check allowance and ensure transfer success
    uint256 allowance = _underlying.allowance(_msgSender(), address(this));
    require(allowance >= underlying_amount, "Insufficient Allowance");
    // mint the scaled amount of tokens to the TARGET
    ERC20Upgradeable._mint(target, amount);
    // transfer underlying from SENDER to THIS
    require(_underlying.transferFrom(_msgSender(), address(this), underlying_amount), "transfer failed");
  }

  /// @notice withdraw underlying by burning THIS token
  /// caller should obtain 1 underlying for every underlyingScalar() THIS token
  /// @param underlying_amount amount of underlying to withdraw
  function withdraw(uint256 underlying_amount, address target) public {
    // scale the underlying_amount to the THIS token decimal amount, aka 1e18
    uint256 amount = underlyingToCappedAmount(underlying_amount);
    // check balances all around
    require(amount <= this.balanceOf(_msgSender()), "insufficient funds");
    require(amount > 0, "Cannot withdraw 0");
    uint256 balance = _underlying.balanceOf(address(this));
    require(balance >= underlying_amount, "Insufficient underlying in Bank");
    // burn the scaled amount of tokens from the SENDER
    ERC20Upgradeable._burn(_msgSender(), amount);
    // transfer underlying to the TARGET
    require(_underlying.transfer(target, underlying_amount), "transfer failed");
  }

  // EIP-4626 compliance, sorry it's not the most gas efficient.

  function underlyingAddress() external view returns (address) {
    return address(_underlying);
  }

  function totalUnderlying() public view returns (uint256) {
    return _underlying.balanceOf(address(this));
  }

  function convertToShares(uint256 assets) external view returns (uint256) {
    return underlyingToCappedAmount(assets);
  }

  function convertToAssets(uint256 shares) external view returns (uint256) {
    return cappedAmountToUnderlying(shares);
  }

  function maxDeposit(address receiver) public view returns (uint256) {
    uint256 remaining = (_cap - (totalUnderlying() * underlyingScalar())) / underlyingScalar();
    if (remaining < _underlying.balanceOf(receiver)) {
      return _underlying.balanceOf(receiver);
    }
    return remaining;
  }

  function previewDeposit(uint256 assets) public view returns (uint256) {
    return underlyingToCappedAmount(assets);
  }

  //function deposit - already implemented

  function maxMint(address receiver) external view returns (uint256) {
    return cappedAmountToUnderlying(maxDeposit(receiver));
  }

  function previewMint(uint256 shares) external view returns (uint256) {
    return cappedAmountToUnderlying(previewDeposit(shares));
  }

  function mint(uint256 shares, address receiver) external {
    return deposit(cappedAmountToUnderlying(shares), receiver);
  }

  function maxWithdraw(address receiver) public view returns (uint256) {
    uint256 receiver_can = (ERC20Upgradeable.balanceOf(receiver) / underlyingScalar());
    if (receiver_can > _underlying.balanceOf(address(this))) {
      return _underlying.balanceOf(address(this));
    }
    return receiver_can;
  }

  function previewWithdraw(uint256 assets) public view returns (uint256) {
    return underlyingToCappedAmount(assets);
  }

  //function withdraw - already implemented

  function maxRedeem(address receiver) external view returns (uint256) {
    return cappedAmountToUnderlying(maxWithdraw(receiver));
  }

  function previewRedeem(uint256 shares) external view returns (uint256) {
    return cappedAmountToUnderlying(previewWithdraw(shares));
  }

  function redeem(uint256 shares, address receiver) external {
    return withdraw(cappedAmountToUnderlying(shares), receiver);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../_external/Ownable.sol";
import "../../curve/ICurveMaster.sol";
import "../../curve/ICurveSlave.sol";
import "../../lending/IVaultController.sol";

/// @title Curve Master
/// @notice Curve master keeps a record of CurveSlave contracts and links it with an address
/// @dev all numbers should be scaled to 1e18. for instance, number 5e17 represents 50%
contract OldCurveMaster is ICurveMaster, Ownable {
  // mapping of token to address
  mapping(address => address) public _curves;
  mapping(address => bool) public _paused;

  address public _vaultControllerAddress;
  IVaultController private _VaultController;

  /// @notice gets the return value of curve labled token_address at x_value
  /// @param token_address the key to lookup the curve with in the mapping
  /// @param x_value the x value to pass to the slave
  /// @return y value of the curve
  function getValueAt(address token_address, int256 x_value) external view override returns (int256) {
    require(_paused[token_address] == false, "curve paused");
    require(_curves[token_address] != address(0x0), "token not enabled");
    ICurveSlave curve = ICurveSlave(_curves[token_address]);
    int256 value = curve.valueAt(x_value);
    require(value != 0, "result must be nonzero");
    return value;
  }

  /// @notice set the VaultController addr in order to pay interest on curve setting
  /// @param vault_master_address address of vault master
  function setVaultController(address vault_master_address) external override onlyOwner {
    _vaultControllerAddress = vault_master_address;
    _VaultController = IVaultController(vault_master_address);
  }

  function vaultControllerAddress() external view override returns (address) {
    return _vaultControllerAddress;
  }

  function setCurve(address token_address, address curve_address) external override onlyOwner {
    if (address(_VaultController) != address(0)) {
      _VaultController.calculateInterest();
    }
    _curves[token_address] = curve_address;
  }

  /// @notice special function that does not calculate interest, used for deployment et al
  function forceSetCurve(address token_address, address curve_address) external override onlyOwner {
    _curves[token_address] = curve_address;
  }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/// @title interfact to interact with ERC20 tokens
/// @author elee

interface IERC20 {
  function mint(address account, uint256 amount) external;

  function totalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

  function allowance(address owner, address spender) external view returns (uint256);

  function approve(address spender, uint256 amount) external returns (bool);

  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

/// @title Wavepool is the second genration wave contract
// solhint-disable comprehensive-interface
contract RollingWave {
  struct RedemptionData {
    uint256 claimed;
    bool redeemed;
  }

  struct WaveMetadata {
    bytes32 merkleRoot;
    uint128 enableTime;
    uint128 round;
  }

  struct RoundMetaData {
    uint256 roundReward;
    uint128 roundClaimed;
    uint128 impliedPrice;
    uint128 roundFloor;
    uint128 redeemTime;
    bool calculated;
    bool saturation;
  }

  // mapping from wave -> wave information
  // wave informoation includes the merkleRoot and enableTime
  mapping(uint256 => WaveMetadata) public _waveMetaData;

  mapping(uint128 => RoundMetaData) public _roundMetaData;

  // mapping from wave -> address -> claim information
  // claim information includes the amount and whether or not it has been redeemed
  mapping(uint256 => mapping(address => RedemptionData)) public _data;

  // time at which people can claim
  uint128 public _startTime;

  //time between waves
  uint128 public _delay;

  //time between rounds
  uint128 public _roundDelay;

  // the address which will receive any possible extra IPT
  address public _receiver;

  // the token used to claim points, USDC
  IERC20 public _pointsToken; // = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // usdc
  // the token to be rewarded, IPT
  IERC20 public _rewardToken;

  // the amount of reward tokens allocated to the contract
  uint256 public _totalReward;

  // this is the minimum amount of 'points' that can be redeemed for one IPT
  uint256 public _floor;
  // this is the maximum amount of points that can be added to the contract
  uint256 public _cap;

  // the amount of points token that have been sent to the contract
  uint256 public _totalClaimed = 0;

  uint256 public impliedPrice;
  bool public saturation;
  bool public calculated;
  bool public withdrawn;

  event Points(address indexed from, uint256 wave, uint256 amount);

  /**
    each round has 2 waves, and a start time
    run time is delay * 2 (maybe plus some amount)
    wave 1 starts as the round does, wave 2 starts after delay

    when a round completes (second wave is done):
    IPT from that round can be claimed, implied price is saved for that round

    after roundDelay: 
    floor is updated to implied price
    next round starts and process repeats

    if cap is reached, that is the final round

    3 rounds total otherwise
  
   */

  constructor(
    address receiver, //Receive proceeds
    uint256 totalReward, //IPT to sell
    address rewardToken, //IPT
    address pointsToken, //USDC
    uint128 startTime, //time sale starts
    uint128 delay, //time between waves
    uint128 roundDelay, //time between rounds
    bytes32 merkle1, //root for odd number waves
    bytes32 merkle2, //root for even number waves
    uint256 startingFloor //starting floor price
  ) {
    _cap = 500_000 * 35_000_000 * 4;
    _floor = startingFloor;
    _startTime = startTime;
    _delay = delay;
    _roundDelay = roundDelay;
    // reward information
    _rewardToken = IERC20(rewardToken);
    _pointsToken = IERC20(pointsToken);
    _totalReward = totalReward;

    //receiver of proceeds
    _receiver = receiver;

    _setUpWaves(merkle1, merkle2);
    _roundMetaData[1].roundReward = totalReward / 3;
    _roundMetaData[2].roundReward = totalReward / 3;
    _roundMetaData[3].roundReward = totalReward / 3;

    _roundMetaData[1].roundFloor = uint128(startingFloor);
    _roundMetaData[2].roundFloor = uint128(startingFloor);
    _roundMetaData[2].roundFloor = uint128(startingFloor);

    calculated = false;
    saturation = false;
    withdrawn = false;
  }

  function _setUpWaves(bytes32 merkle1, bytes32 merkle2) private {
    //round 1
    _waveMetaData[1].merkleRoot = merkle1;
    _waveMetaData[1].enableTime = _startTime;
    _waveMetaData[1].round = 1;

    _waveMetaData[2].merkleRoot = merkle2;
    _waveMetaData[2].enableTime = _startTime + _delay;
    _waveMetaData[2].round = 1;

    //adjust times
    _startTime = _startTime + _delay + _roundDelay;
    _roundMetaData[1].redeemTime = _startTime;

    //round 2
    _waveMetaData[3].merkleRoot = merkle1;
    _waveMetaData[3].enableTime = _startTime + _delay;
    _waveMetaData[3].round = 2;

    _waveMetaData[4].merkleRoot = merkle2;
    _waveMetaData[4].enableTime = _startTime + _delay;
    _waveMetaData[4].round = 2;

    //adjust times
    _startTime = _startTime + _delay + _roundDelay;
    _roundMetaData[2].redeemTime = _startTime;

    //round 3
    _waveMetaData[5].merkleRoot = merkle1;
    _waveMetaData[5].enableTime = _startTime + _delay;
    _waveMetaData[5].round = 3;

    _waveMetaData[6].merkleRoot = merkle2;
    _waveMetaData[6].enableTime = _startTime + _delay;
    _waveMetaData[6].round = 3;

    _roundMetaData[3].redeemTime = _startTime + _delay + _roundDelay;
  }

  /// @notice tells whether the wave is enabled or not
  /// @return boolean true if the wave is enabled
  function isEnabled(uint256 wave) public view returns (bool) {
    return
      block.timestamp > _waveMetaData[wave].enableTime &&
      block.timestamp < _roundMetaData[_waveMetaData[wave].round].redeemTime;
  }

  /// @notice not claimable after USDC cap has been reached ether for total or for individual round
  function canClaim(uint128 round) public view returns (bool) {
    return
      (_totalClaimed <= _cap) && (_roundMetaData[round].roundClaimed <= (_roundMetaData[round].roundReward / 1e12));
  }

  /// @notice whether or not redemption is possible
  function canRedeem(uint128 round) public view returns (bool) {
    return block.timestamp > _roundMetaData[round].redeemTime;
  }

  /// @notice calculate pricing 1 time for each round to save gas
  function calculatePricing(uint128 round) internal {
    require(!_roundMetaData[round].calculated, "Calculated already");
    // implied price is assuming pro rata, how many points you need for one reward
    // for instance, if the totalReward was 1, and _totalClaimed was below 500_000, then the impliedPrice would be below 500_000
    _roundMetaData[round].impliedPrice = uint128(
      _roundMetaData[round].roundClaimed / (_roundMetaData[round].roundReward / 1e18)
    );
    if (_roundMetaData[round].impliedPrice > _roundMetaData[round].roundFloor) {
      _roundMetaData[round].saturation = true;

      _roundMetaData[round + 1].roundFloor = _roundMetaData[round].impliedPrice;
    }
    _roundMetaData[round].calculated = true;
  }

  /// @notice 1 USDC == 1 point - rewards distributed pro rata based on points
  /// @param amount amount of usdc
  /// @param key the total amount the points the user may claim - ammount allocated in whitelist
  /// @param merkleProof a proof proving that the caller may redeem up to `key` points
  function getPoints(uint256 wave, uint256 amount, uint256 key, bytes32[] memory merkleProof) public {
    require(isEnabled(wave) == true, "not enabled");

    uint256 target = _data[wave][msg.sender].claimed + amount;

    require(verifyClaim(wave, msg.sender, key, merkleProof) == true, "invalid proof");

    require(target <= key, "max alloc claimed");

    _data[wave][msg.sender].claimed = target;

    _roundMetaData[_waveMetaData[wave].round].roundClaimed =
      _roundMetaData[_waveMetaData[wave].round].roundClaimed +
      uint128(amount);

    _totalClaimed = _totalClaimed + amount;

    require(canClaim(_waveMetaData[wave].round) == true, "Cap reached");

    takeFrom(msg.sender, amount);
    emit Points(msg.sender, wave, amount);
  }

  /// @notice redeem points for reward token
  /// @param wave if claimed on multiple waves, must redeem for each one separately
  function redeem(uint256 wave) external {
    uint128 round = _waveMetaData[wave].round;
    require(canRedeem(round) == true, "can't redeem yet");
    require(_data[wave][msg.sender].redeemed == false, "already redeem");
    if (!_roundMetaData[round].calculated) {
      calculatePricing(round);
    }
    _data[wave][msg.sender].redeemed = true;
    uint256 rewardAmount;
    RedemptionData memory user = _data[wave][msg.sender];

    if (!_roundMetaData[round].saturation) {
      // if the implied price is smaller than the floor price, that means that
      // not enough points have been claimed to get to the floor price
      // in that case, charge the floor price
      rewardAmount = ((1e18 * user.claimed) / _roundMetaData[round].roundFloor);
    } else {
      // if the implied price is above the floor price, the price is the implied price
      rewardAmount = ((1e18 * user.claimed) / _roundMetaData[round].impliedPrice);
    }
    giveTo(msg.sender, rewardAmount);
  }

  /// @notice function which transfer the point token
  function takeFrom(address target, uint256 amount) internal {
    bool check = _pointsToken.transferFrom(target, _receiver, amount);
    require(check, "erc20 transfer failed");
  }

  /// @notice function which sends the reward token
  function giveTo(address target, uint256 amount) internal {
    if (_rewardToken.balanceOf(address(this)) < amount) {
      amount = _rewardToken.balanceOf(address(this));
    }
    require(amount > 0, "cant redeem zero");
    bool check = _rewardToken.transfer(target, amount);
    require(check, "erc20 transfer failed");
  }

  /// @notice validate the proof of a merkle drop claim
  /// @param wave the wave that they are trying to redeem for
  /// @param claimer the address attempting to claim
  /// @param key the amount of scaled TRIBE allocated the claimer claims that they have credit over
  /// @param merkleProof a proof proving that claimer may redeem up to `key` amount of tribe
  /// @return boolean true if the proof is valid, false if the proof is invalid
  function verifyClaim(
    uint256 wave,
    address claimer,
    uint256 key,
    bytes32[] memory merkleProof
  ) private view returns (bool) {
    bytes32 leaf = keccak256(abi.encodePacked(claimer, key));
    bytes32 merkleRoot = _waveMetaData[wave].merkleRoot;
    return verifyProof(merkleProof, merkleRoot, leaf);
  }

  //solhint-disable-next-line max-line-length
  //merkle logic: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/c9bdb1f0ae168e00a942270f2b85d6a7d3293550/contracts/utils/cryptography/MerkleProof.sol
  //MIT: OpenZeppelin Contracts v4.3.2 (utils/cryptography/MerkleProof.sol)
  function verifyProof(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
    return processProof(proof, leaf) == root;
  }

  function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
    bytes32 computedHash = leaf;
    for (uint256 i = 0; i < proof.length; i++) {
      bytes32 proofElement = proof[i];
      if (computedHash <= proofElement) {
        computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
      } else {
        computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
      }
    }
    return computedHash;
  }
} // solhint-enable comprehensive-interface

//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/// @title interfact to interact with ERC20 tokens
/// @author elee

interface IERC20 {
  function mint(address account, uint256 amount) external;

  function totalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

  function allowance(address owner, address spender) external view returns (uint256);

  function approve(address spender, uint256 amount) external returns (bool);

  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

/// @title Wavepool is the second genration wave contract
// solhint-disable comprehensive-interface
contract WavePool {
  struct RedemptionData {
    uint256 claimed;
    bool redeemed;
  }

  struct WaveMetadata {
    bool enabled;
    bytes32 merkleRoot;
    uint256 enableTime;
  }

  // mapping from wave -> wave information
  // wave informoation includes the merkleRoot and enableTime
  mapping(uint256 => WaveMetadata) public _metadata;
  // mapping from wave -> address -> claim information
  // claim information includes the amount and whether or not it has been redeemed
  mapping(uint256 => mapping(address => RedemptionData)) public _data;

  // time at which people can claim
  uint256 public _claimTime;

  // the address which will receive any possible extra IPT
  address public _receiver;

  // the token used to claim points, USDC
  IERC20 public _pointsToken; // = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // usdc
  // the token to be rewarded, IPT
  IERC20 public _rewardToken;

  // the amount of reward tokens allocated to the contract
  uint256 public _totalReward;

  // this is the minimum amount of 'points' that can be redeemed for one IPT
  uint256 public _floor;
  // this is the maximum amount of points that can be added to the contract
  uint256 public _cap;

  // the amount of points token that have been sent to the contract
  uint256 public _totalClaimed = 0;

  uint256 public impliedPrice;
  bool public saturation;
  bool public calculated;
  bool public withdrawn;

  event Points(address indexed from, uint256 wave, uint256 amount);

  constructor(
    address receiver,
    uint256 totalReward,
    address rewardToken,
    address pointsToken,
    uint256 claimTime,
    bytes32 merkle1,
    uint256 enable1,
    bytes32 merkle2,
    uint256 enable2,
    bytes32 merkle3,
    uint256 enable3
  ) {
    // price information
    _floor = 250_000;
    _cap = 500_000 * 35_000_000 * 4;
    _claimTime = claimTime;
    // reward information
    _rewardToken = IERC20(rewardToken);
    _pointsToken = IERC20(pointsToken);
    _totalReward = totalReward;

    // set receiver of IPT
    _receiver = receiver;

    // wave metadata
    _metadata[1].enabled = true;
    _metadata[1].merkleRoot = merkle1;
    _metadata[1].enableTime = enable1;

    _metadata[2].enabled = true;
    _metadata[2].merkleRoot = merkle2;
    _metadata[2].enableTime = enable2;

    _metadata[3].enabled = true;
    _metadata[3].merkleRoot = merkle3;
    _metadata[3].enableTime = enable3;

    calculated = false;
    saturation = false;
    withdrawn = false;
  }

  /// @notice tells whether the wave is enabled or not
  /// @return boolean true if the wave is enabled
  function isEnabled(uint256 wave) public view returns (bool) {
    if (_metadata[wave].enabled != true) {
      return false;
    }
    return block.timestamp > _metadata[wave].enableTime && block.timestamp < _claimTime;
  }

  /// @notice not claimable after USDC cap has been reached
  function canClaim() public view returns (bool) {
    return _totalClaimed <= _cap;
  }

  /// @notice whether or not redemption is possible
  function canRedeem() public view returns (bool) {
    return block.timestamp > _claimTime;
  }

  /// @notice calculate pricing 1 time to save gas
  function calculatePricing() internal {
    require(!calculated, "Calculated already");
    // implied price is assuming pro rata, how many points you need for one reward
    // for instance, if the totalReward was 1, and _totalClaimed was below 500_000, then the impliedPrice would be below 500_000
    impliedPrice = _totalClaimed / (_totalReward / 1e18);
    if (!(impliedPrice < _floor)) {
      saturation = true;
    }
    calculated = true;
  }

  /// @notice redeem points for reward token
  /// @param wave if claimed on multiple waves, must redeem for each one separately
  function redeem(uint256 wave) external {
    require(canRedeem() == true, "can't redeem yet");
    require(_data[wave][msg.sender].redeemed == false, "already redeem");
    if (!calculated) {
      calculatePricing();
    }

    _data[wave][msg.sender].redeemed = true;
    uint256 rewardAmount;
    RedemptionData memory user = _data[wave][msg.sender];

    if (!saturation) {
      // if the implied price is smaller than the floor price, that means that
      // not enough points have been claimed to get to the floor price
      // in that case, charge the floor price
      rewardAmount = ((1e18 * user.claimed) / _floor);
    } else {
      // if the implied price is above the floor price, the price is the implied price
      rewardAmount = ((1e18 * user.claimed) / impliedPrice);
    }
    giveTo(msg.sender, rewardAmount);
  }

  /// @notice 1 USDC == 1 point - rewards distributed pro rata based on points
  /// @param amount amount of usdc
  /// @param key the total amount the points the user may claim - ammount allocated in whitelist
  /// @param merkleProof a proof proving that the caller may redeem up to `key` points
  function getPoints(uint256 wave, uint256 amount, uint256 key, bytes32[] memory merkleProof) public {
    require(isEnabled(wave) == true, "not enabled");
    uint256 target = _data[wave][msg.sender].claimed + amount;

    if (_metadata[wave].merkleRoot != 0x00) {
      require(verifyClaim(wave, msg.sender, key, merkleProof) == true, "invalid proof");
      require(target <= key, "max alloc claimed");
    }

    _data[wave][msg.sender].claimed = target;
    _totalClaimed = _totalClaimed + amount;

    require(canClaim() == true, "Cap reached");

    takeFrom(msg.sender, amount);
    emit Points(msg.sender, wave, amount);
  }

  /// @notice validate the proof of a merkle drop claim
  /// @param wave the wave that they are trying to redeem for
  /// @param claimer the address attempting to claim
  /// @param key the amount of scaled TRIBE allocated the claimer claims that they have credit over
  /// @param merkleProof a proof proving that claimer may redeem up to `key` amount of tribe
  /// @return boolean true if the proof is valid, false if the proof is invalid
  function verifyClaim(
    uint256 wave,
    address claimer,
    uint256 key,
    bytes32[] memory merkleProof
  ) private view returns (bool) {
    bytes32 leaf = keccak256(abi.encodePacked(claimer, key));
    bytes32 merkleRoot = _metadata[wave].merkleRoot;
    return verifyProof(merkleProof, merkleRoot, leaf);
  }

  //solhint-disable-next-line max-line-length
  //merkle logic: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/c9bdb1f0ae168e00a942270f2b85d6a7d3293550/contracts/utils/cryptography/MerkleProof.sol
  //MIT: OpenZeppelin Contracts v4.3.2 (utils/cryptography/MerkleProof.sol)
  function verifyProof(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
    return processProof(proof, leaf) == root;
  }

  function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
    bytes32 computedHash = leaf;
    for (uint256 i = 0; i < proof.length; i++) {
      bytes32 proofElement = proof[i];
      if (computedHash <= proofElement) {
        computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
      } else {
        computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
      }
    }
    return computedHash;
  }

  /// @notice function which transfer the point token
  function takeFrom(address target, uint256 amount) internal {
    bool check = _pointsToken.transferFrom(target, _receiver, amount);
    require(check, "erc20 transfer failed");
  }

  /// @notice function which sends the reward token
  function giveTo(address target, uint256 amount) internal {
    if (_rewardToken.balanceOf(address(this)) < amount) {
      amount = _rewardToken.balanceOf(address(this));
    }
    require(amount > 0, "cant redeem zero");
    bool check = _rewardToken.transfer(target, amount);
    require(check, "erc20 transfer failed");
  }

  ///@notice sends all unclaimed reward tokens to the receiver
  function withdraw() external {
    require(msg.sender == _receiver, "Only Receiver");
    require(calculated, "calculatePricing() first");
    require(!withdrawn, "Already withdrawn");

    uint256 rewardAmount;
    if (!saturation) {
      rewardAmount = ((1e18 * _totalClaimed) / _floor);
    } else {
      revert("Saturation reached");
    }
    rewardAmount = _totalReward - rewardAmount;

    giveTo(_receiver, rewardAmount);
  }
}
// solhint-enable comprehensive-interface

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ICurvePoolFeed {
  function initialize(
    uint256 max_safe_price_difference,
    address stable_swap_oracle_address,
    address curve_pool_address,
    address admin
  ) external;

  function safe_price() external view returns (uint256, uint256);

  function current_price() external view returns (uint256, bool);

  function update_safe_price() external returns (uint256);

  function fetch_safe_price(uint256 max_age) external returns (uint256, uint256);

  function set_admin(address admin) external;

  function set_max_safe_price_difference(uint256 max_safe_price_difference) external;

  function admin() external view returns (address);

  function max_safe_price_difference() external view returns (uint256);

  function safe_price_value() external view returns (uint256);

  function safe_price_timestamp() external view returns (uint256);

  function curve_pool_address() external view returns (address);

  function stable_swap_oracle_address() external view returns (address);
}

// SPDX-License-Identifier: MIT
/* solhint-disable */
pragma solidity 0.8.9;

import "../_external/ERC20Detailed.sol";

import "../_external/openzeppelin/OwnableUpgradeable.sol";
import "../_external/openzeppelin/Initializable.sol";

/**
 * @title uFragments ERC20 token
 * @dev USDI uses the uFragments concept from the Ideal Money project to play interest
 *      Implementation is shamelessly borrowed from Ampleforth project
 *      uFragments is a normal ERC20 token, but its supply can be adjusted by splitting and
 *      combining tokens proportionally across all wallets.
 *
 *
 *      uFragment balances are internally represented with a hidden denomination, 'gons'.
 *      We support splitting the currency in expansion and combining the currency on contraction by
 *      changing the exchange rate between the hidden 'gons' and the public 'fragments'.
 */
contract UFragments is Initializable, OwnableUpgradeable, ERC20Detailed {
  // PLEASE READ BEFORE CHANGING ANY ACCOUNTING OR MATH
  // Anytime there is division, there is a risk of numerical instability from rounding errors. In
  // order to minimize this risk, we adhere to the following guidelines:
  // 1) The conversion rate adopted is the number of gons that equals 1 fragment.
  //    The inverse rate must not be used--_totalGons is always the numerator and _totalSupply is
  //    always the denominator. (i.e. If you want to convert gons to fragments instead of
  //    multiplying by the inverse rate, you should divide by the normal rate)
  // 2) Gon balances converted into Fragments are always rounded down (truncated).
  //
  // We make the following guarantees:
  // - If address 'A' transfers x Fragments to address 'B'. A's resulting external balance will
  //   be decreased by precisely x Fragments, and B's external balance will be precisely
  //   increased by x Fragments.
  //
  // We do not guarantee that the sum of all balances equals the result of calling totalSupply().
  // This is because, for any conversion function 'f()' that has non-zero rounding error,
  // f(x0) + f(x1) + ... + f(xn) is not always equal to f(x0 + x1 + ... xn).

  event LogRebase(uint256 indexed epoch, uint256 totalSupply);
  event LogMonetaryPolicyUpdated(address monetaryPolicy);

  // Used for authentication
  address public monetaryPolicy;

  modifier onlyMonetaryPolicy() {
    require(msg.sender == monetaryPolicy);
    _;
  }

  modifier validRecipient(address to) {
    require(to != address(0x0));
    require(to != address(this));
    _;
  }

  uint256 private constant DECIMALS = 18;
  uint256 private constant MAX_UINT256 = 2 ** 256 - 1;
  uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 1 * 10 ** DECIMALS;

  // _totalGons is a multiple of INITIAL_FRAGMENTS_SUPPLY so that _gonsPerFragment is an integer.
  // Use the highest value that fits in a uint256 for max granularity.
  uint256 public _totalGons; // = INITIAL_FRAGMENTS_SUPPLY * 10**48;

  // MAX_SUPPLY = maximum integer < (sqrt(4*_totalGons + 1) - 1) / 2
  uint256 public MAX_SUPPLY; // = type(uint128).max; // (2^128) - 1

  uint256 public _totalSupply;
  uint256 public _gonsPerFragment;
  mapping(address => uint256) public _gonBalances;

  // This is denominated in Fragments, because the gons-fragments conversion might change before
  // it's fully paid.
  mapping(address => mapping(address => uint256)) private _allowedFragments;

  // EIP-2612: permit – 712-signed approvals
  // https://eips.ethereum.org/EIPS/eip-2612
  string public constant EIP712_REVISION = "1";
  bytes32 public constant EIP712_DOMAIN =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
  bytes32 public constant PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

  // EIP-2612: keeps track of number of permits per address
  mapping(address => uint256) private _nonces;

  function __UFragments_init(string memory name, string memory symbol) public initializer {
    __Ownable_init();
    __ERC20Detailed_init(name, symbol, uint8(DECIMALS));

    //set og initial values
    _totalGons = INITIAL_FRAGMENTS_SUPPLY * 10 ** 48;
    MAX_SUPPLY = 2 ** 128 - 1;

    _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
    _gonBalances[address(0x0)] = _totalGons; //send starting supply to a burner address so _totalSupply is never 0
    _gonsPerFragment = _totalGons / _totalSupply;

    emit Transfer(address(this), address(0x0), _totalSupply);
  }

  /**
   * @param monetaryPolicy_ The address of the monetary policy contract to use for authentication.
   */
  function setMonetaryPolicy(address monetaryPolicy_) external onlyOwner {
    monetaryPolicy = monetaryPolicy_;
    emit LogMonetaryPolicyUpdated(monetaryPolicy_);
  }

  /**
   * @return The total number of fragments.
   */
  function totalSupply() external view override returns (uint256) {
    return _totalSupply;
  }

  /**
   * @param who The address to query.
   * @return The balance of the specified address.
   */
  function balanceOf(address who) external view override returns (uint256) {
    return _gonBalances[who] / _gonsPerFragment;
  }

  /**
   * @param who The address to query.
   * @return The gon balance of the specified address.
   */
  function scaledBalanceOf(address who) external view returns (uint256) {
    return _gonBalances[who];
  }

  /**
   * @return the total number of gons.
   */
  function scaledTotalSupply() external view returns (uint256) {
    return _totalGons;
  }

  /**
   * @return The number of successful permits by the specified address.
   */
  function nonces(address who) public view returns (uint256) {
    return _nonces[who];
  }

  /**
   * @return The computed DOMAIN_SEPARATOR to be used off-chain services
   *         which implement EIP-712.
   *         https://eips.ethereum.org/EIPS/eip-2612
   */
  function DOMAIN_SEPARATOR() public view returns (bytes32) {
    uint256 chainId;
    assembly {
      chainId := chainid()
    }
    return
      keccak256(
        abi.encode(EIP712_DOMAIN, keccak256(bytes(name())), keccak256(bytes(EIP712_REVISION)), chainId, address(this))
      );
  }

  /**
   * @dev Transfer tokens to a specified address.
   * @param to The address to transfer to.
   * @param value The amount to be transferred.
   * @return True on success, false otherwise.
   */
  function transfer(address to, uint256 value) external override validRecipient(to) returns (bool) {
    uint256 gonValue = value * _gonsPerFragment;

    _gonBalances[msg.sender] = _gonBalances[msg.sender] - gonValue;
    _gonBalances[to] = _gonBalances[to] + gonValue;

    emit Transfer(msg.sender, to, value);
    return true;
  }

  /**
   * @dev Transfer all of the sender's wallet balance to a specified address.
   * @param to The address to transfer to.
   * @return True on success, false otherwise.
   */
  function transferAll(address to) external validRecipient(to) returns (bool) {
    uint256 gonValue = _gonBalances[msg.sender];
    uint256 value = gonValue / _gonsPerFragment;

    delete _gonBalances[msg.sender];
    _gonBalances[to] = _gonBalances[to] + gonValue;

    emit Transfer(msg.sender, to, value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner has allowed to a spender.
   * @param owner_ The address which owns the funds.
   * @param spender The address which will spend the funds.
   * @return The number of tokens still available for the spender.
   */
  function allowance(address owner_, address spender) external view override returns (uint256) {
    return _allowedFragments[owner_][spender];
  }

  /**
   * @dev Transfer tokens from one address to another.
   * @param from The address you want to send tokens from.
   * @param to The address you want to transfer to.
   * @param value The amount of tokens to be transferred.
   */
  function transferFrom(address from, address to, uint256 value) external override validRecipient(to) returns (bool) {
    _allowedFragments[from][msg.sender] = _allowedFragments[from][msg.sender] - value;

    uint256 gonValue = value * _gonsPerFragment;
    _gonBalances[from] = _gonBalances[from] - gonValue;
    _gonBalances[to] = _gonBalances[to] + gonValue;

    emit Transfer(from, to, value);
    return true;
  }

  /**
   * @dev Transfer all balance tokens from one address to another.
   * @param from The address you want to send tokens from.
   * @param to The address you want to transfer to.
   */
  function transferAllFrom(address from, address to) external validRecipient(to) returns (bool) {
    uint256 gonValue = _gonBalances[from];
    uint256 value = gonValue / _gonsPerFragment;

    _allowedFragments[from][msg.sender] = _allowedFragments[from][msg.sender] - value;

    delete _gonBalances[from];
    _gonBalances[to] = _gonBalances[to] + gonValue;

    emit Transfer(from, to, value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of
   * msg.sender. This method is included for ERC20 compatibility.
   * increaseAllowance and decreaseAllowance should be used instead.
   * Changing an allowance with this method brings the risk that someone may transfer both
   * the old and the new allowance - if they are both greater than zero - if a transfer
   * transaction is mined before the later approve() call is mined.
   *
   * @param spender The address which will spend the funds.
   * @param value The amount of tokens to be spent.
   */
  function approve(address spender, uint256 value) external override returns (bool) {
    _allowedFragments[msg.sender][spender] = value;

    emit Approval(msg.sender, spender, value);
    return true;
  }

  /**
   * @dev Increase the amount of tokens that an owner has allowed to a spender.
   * This method should be used instead of approve() to avoid the double approval vulnerability
   * described above.
   * @param spender The address which will spend the funds.
   * @param addedValue The amount of tokens to increase the allowance by.
   */
  function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
    _allowedFragments[msg.sender][spender] = _allowedFragments[msg.sender][spender] + addedValue;

    emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
    return true;
  }

  /**
   * @dev Decrease the amount of tokens that an owner has allowed to a spender.
   *
   * @param spender The address which will spend the funds.
   * @param subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
    uint256 oldValue = _allowedFragments[msg.sender][spender];
    _allowedFragments[msg.sender][spender] = (subtractedValue >= oldValue) ? 0 : oldValue - subtractedValue;

    emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
    return true;
  }

  /**
   * @dev Allows for approvals to be made via secp256k1 signatures.
   * @param owner The owner of the funds
   * @param spender The spender
   * @param value The amount
   * @param deadline The deadline timestamp, type(uint256).max for max deadline
   * @param v Signature param
   * @param s Signature param
   * @param r Signature param
   */
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public {
    require(block.timestamp <= deadline);

    uint256 ownerNonce = _nonces[owner];
    bytes32 permitDataDigest = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, ownerNonce, deadline));
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), permitDataDigest));

    require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "Invalid signature");
    require(owner == ecrecover(digest, v, r, s));
    require(owner != address(0x0), "Invalid signature");

    _nonces[owner] = ownerNonce + 1;

    _allowedFragments[owner][spender] = value;
    emit Approval(owner, spender, value);
  }
}
/* solhint-enable */

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../lending/IVaultController.sol";

interface IVaultController2 is IVaultController {
  function newThing() external view returns (uint256);

  function changeTheThing(uint256 _newThing) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "../lending/controller/VaultController.sol";
import "./IVaultController2.sol";

contract VaultController2 is VaultController, IVaultController2 {
  //CHANGED extend storage
  uint256 public newThing;

  //CHANGED new event
  event ThingChanged(uint256 newThing);

  //CHANGED new function
  function changeTheThing(uint256 _newThing) public override {
    newThing = _newThing;
    emit ThingChanged(_newThing);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./IUSDI.sol";

import "./token/UFragments.sol";
import "./lending/IVaultController.sol";

import "./_external/IERC20.sol";
import "./_external/compound/ExponentialNoError.sol";
import "./_external/openzeppelin/PausableUpgradeable.sol";

/// @title USDI token contract
/// @notice handles all minting/burning of usdi
/// @dev extends UFragments
contract USDI is Initializable, PausableUpgradeable, UFragments, IUSDI, ExponentialNoError {
  IERC20 public _reserve;
  IVaultController public _VaultController;

  address public _pauser;

  /// @notice checks if _msgSender() is VaultController
  modifier onlyVaultController() {
    require(_msgSender() == address(_VaultController), "only VaultController");
    _;
  }

  /// @notice checks if _msgSender() is pauser
  modifier onlyPauser() {
    require(_msgSender() == address(_pauser), "only pauser");
    _;
  }

  /// @notice any function with this modifier will call the pay_interest() function before any function logic is called
  modifier paysInterest() {
    _VaultController.calculateInterest();
    _;
  }

  /// @notice initializer for contract
  /// @param reserveAddr the address of USDC
  /// @dev consider adding decimals?
  function initialize(address reserveAddr) public override initializer {
    __UFragments_init("opUSDI Token", "opUSDI");
    __Pausable_init();
    _reserve = IERC20(reserveAddr);
  }

  ///@notice sets the pauser for both USDI and VaultController
  ///@notice the pauser is a separate role from the owner
  function setPauser(address pauser_) external override onlyOwner {
    _pauser = pauser_;
  }

  /// @notice pause contract, pauser only
  function pause() external override onlyPauser {
    _pause();
  }

  /// @notice unpause contract, pauser only
  function unpause() external override onlyPauser {
    _unpause();
  }

  ///@notice gets the pauser for both USDI and VaultController
  function pauser() public view returns (address) {
    return _pauser;
  }

  ///@notice gets the owner of the USDI contract
  function owner() public view override(IUSDI, OwnableUpgradeable) returns (address) {
    return super.owner();
  }

  /// @notice getter for name
  /// @return name of token
  function name() public view override(IERC20Metadata, ERC20Detailed) returns (string memory) {
    return super.name();
  }

  /// @notice getter for symbol
  /// @return symbol for token
  function symbol() public view override(IERC20Metadata, ERC20Detailed) returns (string memory) {
    return super.symbol();
  }

  /// @notice getter for decimals
  /// @return decimals for token
  function decimals() public view override(IERC20Metadata, ERC20Detailed) returns (uint8) {
    return super.decimals();
  }

  /// @notice getter for address of the reserve currency, or usdc
  /// @return decimals for of reserve currency
  function reserveAddress() public view override returns (address) {
    return address(_reserve);
  }

  /// @notice get the VaultController addr
  /// @return vaultcontroller addr
  function getVaultController() public view override returns (address) {
    return address(_VaultController);
  }

  /// @notice set the VaultController addr so that vault_master may mint/burn USDi without restriction
  /// @param vault_master_address address of vault master
  function setVaultController(address vault_master_address) external override onlyOwner {
    _VaultController = IVaultController(vault_master_address);
  }

  /// @notice deposit USDC to mint USDi
  /// @dev caller should obtain 1e12 USDi for each USDC
  /// the calculations for deposit mimic the calculations done by mint in the ampleforth contract, simply with the usdc transfer
  /// "fragments" are the units that we see, so 1000 fragments == 1000 USDi
  /// "gons" are the internal accounting unit, used to keep scale.
  /// we use the variable _gonsPerFragment in order to convert between the two
  /// try dimensional analysis when doing the math in order to verify units are correct
  /// @param usdc_amount amount of USDC to deposit
  function deposit(uint256 usdc_amount) external override {
    _deposit(usdc_amount, _msgSender());
  }

  function depositTo(uint256 usdc_amount, address target) external override {
    _deposit(usdc_amount, target);
  }

  function _deposit(uint256 usdc_amount, address target) internal paysInterest whenNotPaused {
    // scale the usdc_amount to the usdi decimal amount, aka 1e18. since usdc is 6 decimals, we multiply by 1e12
    uint256 amount = usdc_amount * 1e12;
    require(amount > 0, "Cannot deposit 0");
    // check allowance and ensure transfer success
    uint256 allowance = _reserve.allowance(_msgSender(), address(this));
    require(allowance >= usdc_amount, "Insufficient Allowance");
    require(_reserve.transferFrom(_msgSender(), address(this), usdc_amount), "transfer failed");
    // the gonbalances of the sender is in gons, therefore we must multiply the deposit amount, which is in fragments, by gonsperfragment
    _gonBalances[target] = _gonBalances[target] + amount * _gonsPerFragment;
    // total supply is in fragments, and so we add amount
    _totalSupply = _totalSupply + amount;
    // and totalgons of course is in gons, and so we multiply amount by gonsperfragment to get the amount of gons we must add to totalGons
    _totalGons = _totalGons + amount * _gonsPerFragment;

    emit Transfer(address(0), target, amount);
    emit Deposit(target, amount);
  }

  /// @notice withdraw USDC by burning USDi
  /// caller should obtain 1 USDC for every 1e12 USDi
  /// @param usdc_amount amount of USDC to withdraw
  function withdraw(uint256 usdc_amount) external override {
    _withdraw(usdc_amount, _msgSender());
  }

  ///@notice withdraw USDC to a specific address by burning USDi from the caller
  /// target should obtain 1 USDC for every 1e12 USDi burned from the caller
  /// @param usdc_amount amount of USDC to withdraw
  /// @param target address to receive the USDC
  function withdrawTo(uint256 usdc_amount, address target) external override {
    _withdraw(usdc_amount, target);
  }

  ///@notice business logic to withdraw USDC and burn USDi from the caller
  function _withdraw(uint256 usdc_amount, address target) internal paysInterest whenNotPaused {
    // scale the usdc_amount to the USDi decimal amount, aka 1e18
    uint256 amount = usdc_amount * 1e12;
    // check balances all around
    require(amount <= this.balanceOf(_msgSender()), "insufficient funds");
    require(amount > 0, "Cannot withdraw 0");
    uint256 balance = _reserve.balanceOf(address(this));
    require(balance >= usdc_amount, "Insufficient Reserve in Bank");
    // ensure transfer success
    require(_reserve.transfer(target, usdc_amount), "transfer failed");
    // modify the gonbalances of the sender, subtracting the amount of gons, therefore amount*gonsperfragment
    _gonBalances[_msgSender()] = _gonBalances[_msgSender()] - amount * _gonsPerFragment;
    // modify totalSupply and totalGons
    _totalSupply = _totalSupply - amount;
    _totalGons = _totalGons - amount * _gonsPerFragment;
    // emit both a Withdraw and transfer event
    emit Transfer(_msgSender(), address(0), amount);
    emit Withdraw(target, amount);
  }

  /// @notice withdraw USDC by burning USDi
  /// caller should obtain 1 USDC for every 1e12 USDi
  /// this function is effectively just withdraw, but we calculate the amount for the sender
  function withdrawAll() external override {
    _withdrawAll(_msgSender());
  }

  /// @notice withdraw USDC by burning USDi
  /// @param target should obtain 1 USDC for every 1e12 USDi burned from caller
  /// this function is effectively just withdraw, but we calculate the amount for the target
  function withdrawAllTo(address target) external override {
    _withdrawAll(target);
  }

  /// @notice business logic for withdrawAll
  /// @param target should obtain 1 USDC for every 1e12 USDi burned from caller
  /// this function is effectively just withdraw, but we calculate the amount for the target
  function _withdrawAll(address target) internal paysInterest whenNotPaused {
    uint256 reserve = _reserve.balanceOf(address(this));
    require(reserve != 0, "Reserve is empty");
    uint256 usdc_amount = (this.balanceOf(_msgSender())) / 1e12;
    //user's USDI value is more than reserve
    if (usdc_amount > reserve) {
      usdc_amount = reserve;
    }
    uint256 amount = usdc_amount * 1e12;
    require(_reserve.transfer(target, usdc_amount), "transfer failed");
    // see comments in the withdraw function for an explaination of this math
    _gonBalances[_msgSender()] = _gonBalances[_msgSender()] - (amount * _gonsPerFragment);
    _totalSupply = _totalSupply - amount;
    _totalGons = _totalGons - (amount * _gonsPerFragment);
    // emit both a Withdraw and transfer event
    emit Transfer(_msgSender(), address(0), amount);
    emit Withdraw(target, amount);
  }

  /// @notice admin function to mint USDi
  /// @param usdc_amount the amount of USDi to mint, denominated in USDC
  function mint(uint256 usdc_amount) external override paysInterest onlyOwner {
    require(usdc_amount != 0, "Cannot mint 0");
    uint256 amount = usdc_amount * 1e12;
    // see comments in the deposit function for an explaination of this math
    _gonBalances[_msgSender()] = _gonBalances[_msgSender()] + amount * _gonsPerFragment;
    _totalSupply = _totalSupply + amount;
    _totalGons = _totalGons + amount * _gonsPerFragment;
    // emit both a mint and transfer event
    emit Transfer(address(0), _msgSender(), amount);
    emit Mint(_msgSender(), amount);
  }

  /// @notice admin function to burn USDi
  /// @param usdc_amount the amount of USDi to burn, denominated in USDC
  function burn(uint256 usdc_amount) external override paysInterest onlyOwner {
    require(usdc_amount != 0, "Cannot burn 0");
    uint256 amount = usdc_amount * 1e12;
    // see comments in the deposit function for an explaination of this math
    _gonBalances[_msgSender()] = _gonBalances[_msgSender()] - amount * _gonsPerFragment;
    _totalSupply = _totalSupply - amount;
    _totalGons = _totalGons - amount * _gonsPerFragment;
    // emit both a mint and transfer event
    emit Transfer(_msgSender(), address(0), amount);
    emit Burn(_msgSender(), amount);
  }

  /// @notice donates usdc to the protocol reserve
  /// @param usdc_amount the amount of USDC to donate
  function donate(uint256 usdc_amount) external override paysInterest whenNotPaused {
    uint256 amount = usdc_amount * 1e12;
    require(amount > 0, "Cannot deposit 0");
    uint256 allowance = _reserve.allowance(_msgSender(), address(this));
    require(allowance >= usdc_amount, "Insufficient Allowance");
    require(_reserve.transferFrom(_msgSender(), address(this), usdc_amount), "transfer failed");
    _donation(amount);
  }

  /// @notice donates any USDC held by this contract to the USDi holders
  /// @notice accounts for any USDC that may have been sent here accidently
  /// @notice without this, any USDC sent to the contract could mess up the reserve ratio
  function donateReserve() external override onlyOwner whenNotPaused {
    uint256 totalUSDC = (_reserve.balanceOf(address(this))) * 1e12;
    uint256 totalLiability = truncate(_VaultController.totalBaseLiability() * _VaultController.interestFactor());
    require((totalUSDC + totalLiability) > _totalSupply, "No extra reserve");

    _donation((totalUSDC + totalLiability) - _totalSupply);
  }

  /// @notice function for the vaultController to mint
  /// @param target whom to mint the USDi to
  /// @param amount the amount of USDi to mint
  function vaultControllerMint(address target, uint256 amount) external override onlyVaultController {
    // see comments in the deposit function for an explaination of this math
    _gonBalances[target] = _gonBalances[target] + amount * _gonsPerFragment;
    _totalSupply = _totalSupply + amount;
    _totalGons = _totalGons + amount * _gonsPerFragment;
    emit Transfer(address(0), target, amount);
    emit Mint(target, amount);
  }

  /// @notice function for the vaultController to burn
  /// @param target whom to burn the USDi from
  /// @param amount the amount of USDi to burn
  function vaultControllerBurn(address target, uint256 amount) external override onlyVaultController {
    require(_gonBalances[target] > (amount * _gonsPerFragment), "USDI: not enough balance");
    // see comments in the withdraw function for an explaination of this math
    _gonBalances[target] = _gonBalances[target] - amount * _gonsPerFragment;
    _totalSupply = _totalSupply - amount;
    _totalGons = _totalGons - amount * _gonsPerFragment;
    emit Transfer(target, address(0), amount);
    emit Burn(target, amount);
  }

  /// @notice Allows VaultController to send USDC from the reserve
  /// @param target whom to receive the USDC from reserve
  /// @param usdc_amount the amount of USDC to send
  function vaultControllerTransfer(address target, uint256 usdc_amount) external override onlyVaultController {
    // ensure transfer success
    require(_reserve.transfer(target, usdc_amount), "transfer failed");
  }

  /// @notice function for the vaultController to scale all USDi balances
  /// @param amount amount of USDi (e18) to donate
  function vaultControllerDonate(uint256 amount) external override onlyVaultController {
    _donation(amount);
  }

  /// @notice function for distributing the donation to all USDi holders
  /// @param amount amount of USDi to donate
  function _donation(uint256 amount) internal {
    _totalSupply = _totalSupply + amount;
    if (_totalSupply > MAX_SUPPLY) {
      _totalSupply = MAX_SUPPLY;
    }
    _gonsPerFragment = _totalGons / _totalSupply;
    emit Donation(_msgSender(), amount, _totalSupply);
  }

  /// @notice get reserve ratio
  /// @return e18_reserve_ratio USDi reserve ratio
  function reserveRatio() external view override returns (uint192 e18_reserve_ratio) {
    e18_reserve_ratio = safeu192(((_reserve.balanceOf(address(this)) * expScale) / _totalSupply) * 1e12);
  }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.9;

import {IWUSDI} from "./IWUSDI.sol";

import {IERC20} from "./_external/IERC20.sol";

import {SafeERC20} from "./_external/extensions/SafeERC20.sol";
import {ERC20} from "./_external/extensions/ERC20.sol";
// solhint-disable-next-line max-line-length
import {ERC20Permit} from "./_external/extensions/ERC20Permit.sol";

//import "hardhat/console.sol";

/**
 * @title wUSDI (Wrapped usdi).
 *
 * @dev A fixed-balance ERC-20 wrapper for the usdi rebasing token.
 *
 *      Users deposit usdi into this contract and are minted wUSDI.
 *
 *      Each account's wUSDI balance represents the fixed percentage ownership
 *      of usdi's market cap.
 *
 *      For exusdie: 100K wUSDI => 1% of the usdi market cap
 *        when the usdi supply is 100M, 100K wUSDI will be redeemable for 1M usdi
 *        when the usdi supply is 500M, 100K wUSDI will be redeemable for 5M usdi
 *        and so on.
 *
 *      We call wUSDI the "wrapper" token and usdi the "underlying" or "wrapped" token.
 */
contract WUSDI is IWUSDI, ERC20, ERC20Permit {
  using SafeERC20 for IERC20;

  //--------------------------------------------------------------------------
  // Constants

  /// @dev The maximum wUSDI supply.
  uint256 public constant MAX_wUSDI_SUPPLY = 10000000 * (10 ** 18); // 10 M

  //--------------------------------------------------------------------------
  // Attributes

  /// @dev The reference to the usdi token.
  address private immutable _usdi;

  //--------------------------------------------------------------------------

  /// @param usdi The usdi ERC20 token address.
  /// @param name_ The wUSDI ERC20 name.
  /// @param symbol_ The wUSDI ERC20 symbol.
  constructor(address usdi, string memory name_, string memory symbol_) ERC20(name_, symbol_) ERC20Permit(name_) {
    _usdi = usdi;
  }

  //--------------------------------------------------------------------------
  // wUSDI write methods

  /// @notice Transfers usdi_amount from {msg.sender} and mints wUSDI_amount.
  ///
  /// @param wUSDI_amount The amount of wUSDI_amount to mint.
  /// @return The amount of usdi_amount deposited.
  function mint(uint256 wUSDI_amount) external override returns (uint256) {
    uint256 usdi_amount = _wUSDI_to_USDI(wUSDI_amount, _query_USDi_Supply());
    _deposit(_msgSender(), _msgSender(), usdi_amount, wUSDI_amount);
    return usdi_amount;
  }

  /// @notice Transfers usdi_amount from {msg.sender} and mints wUSDI_amount,
  ///         to the specified beneficiary.
  ///
  /// @param to The beneficiary wallet.
  /// @param wUSDI_amount The amount of wUSDI_amount to mint.
  /// @return The amount of usdi_amount deposited.
  function mintFor(address to, uint256 wUSDI_amount) external override returns (uint256) {
    uint256 usdi_amount = _wUSDI_to_USDI(wUSDI_amount, _query_USDi_Supply());
    _deposit(_msgSender(), to, usdi_amount, wUSDI_amount);
    return usdi_amount;
  }

  /// @notice Burns wUSDI_amount from {msg.sender} and transfers usdi_amount back.
  ///
  /// @param wUSDI_amount The amount of wUSDI_amount to burn.
  /// @return The amount of usdi withdrawn.
  function burn(uint256 wUSDI_amount) external override returns (uint256) {
    uint256 usdi_amount = _wUSDI_to_USDI(wUSDI_amount, _query_USDi_Supply());
    _withdraw(_msgSender(), _msgSender(), usdi_amount, wUSDI_amount);
    return usdi_amount;
  }

  /// @notice Burns wUSDI_amount from {msg.sender} and transfers usdi_amount back,
  ///         to the specified beneficiary.
  ///
  /// @param to The beneficiary wallet.
  /// @param wUSDI_amount The amount of wUSDI_amount to burn.
  /// @return The amount of usdi_amount withdrawn.
  function burnTo(address to, uint256 wUSDI_amount) external override returns (uint256) {
    uint256 usdi_amount = _wUSDI_to_USDI(wUSDI_amount, _query_USDi_Supply());
    _withdraw(_msgSender(), to, usdi_amount, wUSDI_amount);
    return usdi_amount;
  }

  /// @notice Burns all wUSDI_amount from {msg.sender} and transfers usdi_amount back.
  ///
  /// @return The amount of usdi_amount withdrawn.
  function burnAll() external override returns (uint256) {
    uint256 wUSDI_amount = balanceOf(_msgSender());
    uint256 usdi_amount = _wUSDI_to_USDI(wUSDI_amount, _query_USDi_Supply());
    _withdraw(_msgSender(), _msgSender(), usdi_amount, wUSDI_amount);
    return usdi_amount;
  }

  /// @notice Burns all wUSDI_amount from {msg.sender} and transfers usdi_amount back,
  ///         to the specified beneficiary.
  ///
  /// @param to The beneficiary wallet.
  /// @return The amount of usdi_amount withdrawn.
  function burnAllTo(address to) external override returns (uint256) {
    uint256 wUSDI_amount = balanceOf(_msgSender());
    uint256 usdi_amount = _wUSDI_to_USDI(wUSDI_amount, _query_USDi_Supply());
    _withdraw(_msgSender(), to, usdi_amount, wUSDI_amount);
    return usdi_amount;
  }

  /// @notice Transfers usdi_amount from {msg.sender} and mints wUSDI_amount.
  ///
  /// @param usdi_amount The amount of usdi_amount to deposit.
  /// @return The amount of wUSDI_amount minted.
  function deposit(uint256 usdi_amount) external override returns (uint256) {
    uint256 wUSDI_amount = _usdi_to_wUSDI(usdi_amount, _query_USDi_Supply());
    _deposit(_msgSender(), _msgSender(), usdi_amount, wUSDI_amount);
    return wUSDI_amount;
  }

  /// @notice Transfers usdi_amount from {msg.sender} and mints wUSDI_amount,
  ///         to the specified beneficiary.
  ///
  /// @param to The beneficiary wallet.
  /// @param usdi_amount The amount of usdi_amount to deposit.
  /// @return The amount of wUSDI_amount minted.
  function depositFor(address to, uint256 usdi_amount) external override returns (uint256) {
    uint256 wUSDI_amount = _usdi_to_wUSDI(usdi_amount, _query_USDi_Supply());
    _deposit(_msgSender(), to, usdi_amount, wUSDI_amount);
    return wUSDI_amount;
  }

  /// @notice Burns wUSDI_amount from {msg.sender} and transfers usdi_amount back.
  ///
  /// @param usdi_amount The amount of usdi_amount to withdraw.
  /// @return The amount of burnt wUSDI_amount.
  function withdraw(uint256 usdi_amount) external override returns (uint256) {
    uint256 wUSDI_amount = _usdi_to_wUSDI(usdi_amount, _query_USDi_Supply());
    _withdraw(_msgSender(), _msgSender(), usdi_amount, wUSDI_amount);
    return wUSDI_amount;
  }

  /// @notice Burns wUSDI_amount from {msg.sender} and transfers usdi_amount back,
  ///         to the specified beneficiary.
  ///
  /// @param to The beneficiary wallet.
  /// @param usdi_amount The amount of usdi_amount to withdraw.
  /// @return The amount of burnt wUSDI_amount.
  function withdrawTo(address to, uint256 usdi_amount) external override returns (uint256) {
    uint256 wUSDI_amount = _usdi_to_wUSDI(usdi_amount, _query_USDi_Supply());
    _withdraw(_msgSender(), to, usdi_amount, wUSDI_amount);
    return wUSDI_amount;
  }

  /// @notice Burns all wUSDI_amount from {msg.sender} and transfers usdi_amount back.
  ///
  /// @return The amount of burnt wUSDI_amount.
  function withdrawAll() external override returns (uint256) {
    uint256 wUSDI_amount = balanceOf(_msgSender());
    uint256 usdi_amount = _wUSDI_to_USDI(wUSDI_amount, _query_USDi_Supply());

    _withdraw(_msgSender(), _msgSender(), usdi_amount, wUSDI_amount);
    return wUSDI_amount;
  }

  /// @notice Burns all wUSDI_amount from {msg.sender} and transfers usdi_amount back,
  ///         to the specified beneficiary.
  ///
  /// @param to The beneficiary wallet.
  /// @return The amount of burnt wUSDI_amount.
  function withdrawAllTo(address to) external override returns (uint256) {
    uint256 wUSDI_amount = balanceOf(_msgSender());
    uint256 usdi_amount = _wUSDI_to_USDI(wUSDI_amount, _query_USDi_Supply());
    _withdraw(_msgSender(), to, usdi_amount, wUSDI_amount);
    return wUSDI_amount;
  }

  //--------------------------------------------------------------------------
  // wUSDI view methods

  /// @return The address of the underlying "wrapped" token ie) usdi.
  function underlying() external view override returns (address) {
    return _usdi;
  }

  /// @return The total usdi_amount held by this contract.
  function totalUnderlying() external view override returns (uint256) {
    return _wUSDI_to_USDI(totalSupply(), _query_USDi_Supply());
  }

  /// @param owner The account address.
  /// @return The usdi balance redeemable by the owner.
  function balanceOfUnderlying(address owner) external view override returns (uint256) {
    return _wUSDI_to_USDI(balanceOf(owner), _query_USDi_Supply());
  }

  /// @param usdi_amount The amount of usdi tokens.
  /// @return The amount of wUSDI tokens exchangeable.
  function underlyingToWrapper(uint256 usdi_amount) external view override returns (uint256) {
    return _usdi_to_wUSDI(usdi_amount, _query_USDi_Supply());
  }

  /// @param wUSDI_amount The amount of wUSDI tokens.
  /// @return The amount of usdi tokens exchangeable.
  function wrapperToUnderlying(uint256 wUSDI_amount) external view override returns (uint256) {
    return _wUSDI_to_USDI(wUSDI_amount, _query_USDi_Supply());
  }

  //--------------------------------------------------------------------------
  // Private methods

  /// @dev Internal helper function to handle deposit state change.
  /// @param from The initiator wallet.
  /// @param to The beneficiary wallet.
  /// @param usdi_amount The amount of usdi_amount to deposit.
  /// @param wUSDI_amount The amount of wUSDI_amount to mint.
  function _deposit(address from, address to, uint256 usdi_amount, uint256 wUSDI_amount) private {
    IERC20(_usdi).safeTransferFrom(from, address(this), usdi_amount);

    _mint(to, wUSDI_amount);
  }

  /// @dev Internal helper function to handle withdraw state change.
  /// @param from The initiator wallet.
  /// @param to The beneficiary wallet.
  /// @param usdi_amount The amount of usdi_amount to withdraw.
  /// @param wUSDI_amount The amount of wUSDI_amount to burn.
  function _withdraw(address from, address to, uint256 usdi_amount, uint256 wUSDI_amount) private {
    _burn(from, wUSDI_amount);

    IERC20(_usdi).safeTransfer(to, usdi_amount);
  }

  /// @dev Queries the current total supply of usdi.
  /// @return The current usdi supply.
  function _query_USDi_Supply() private view returns (uint256) {
    return IERC20(_usdi).totalSupply();
  }

  //--------------------------------------------------------------------------
  // Pure methods

  /// @dev Converts usdi_amount to wUSDI amount.
  function _usdi_to_wUSDI(uint256 usdi_amount, uint256 total_usdi_supply) private pure returns (uint256) {
    return (usdi_amount * MAX_wUSDI_SUPPLY) / total_usdi_supply;
  }

  /// @dev Converts wUSDI_amount amount to usdi_amount.
  function _wUSDI_to_USDI(uint256 wUSDI_amount, uint256 total_usdi_supply) private pure returns (uint256) {
    return (wUSDI_amount * total_usdi_supply) / MAX_wUSDI_SUPPLY;
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

	function logInt(int256 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(int256)", p0));
	}

	function logUint(uint256 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256)", p0));
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

	function log(uint256 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256)", p0));
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

	function log(uint256 p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256)", p0, p1));
	}

	function log(uint256 p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string)", p0, p1));
	}

	function log(uint256 p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool)", p0, p1));
	}

	function log(uint256 p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address)", p0, p1));
	}

	function log(string memory p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256)", p0, p1));
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

	function log(bool p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256)", p0, p1));
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

	function log(address p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256)", p0, p1));
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

	function log(uint256 p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256)", p0, p1, p2));
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

	function log(string memory p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256)", p0, p1, p2));
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

	function log(string memory p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256)", p0, p1, p2));
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

	function log(bool p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256)", p0, p1, p2));
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

	function log(bool p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256)", p0, p1, p2));
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

	function log(bool p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256)", p0, p1, p2));
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

	function log(address p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address)", p0, p1, p2));
	}

	function log(address p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256)", p0, p1, p2));
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

	function log(address p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256)", p0, p1, p2));
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

	function log(address p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256)", p0, p1, p2));
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

	function log(uint256 p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,uint256)", p0, p1, p2, p3));
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

	function log(string memory p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,uint256)", p0, p1, p2, p3));
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

	function log(string memory p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,uint256)", p0, p1, p2, p3));
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

	function log(string memory p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,uint256)", p0, p1, p2, p3));
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

	function log(string memory p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,uint256)", p0, p1, p2, p3));
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

	function log(string memory p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,uint256)", p0, p1, p2, p3));
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

	function log(string memory p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,uint256)", p0, p1, p2, p3));
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

	function log(string memory p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,uint256)", p0, p1, p2, p3));
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

	function log(string memory p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,uint256)", p0, p1, p2, p3));
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

	function log(bool p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,uint256)", p0, p1, p2, p3));
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

	function log(bool p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,uint256)", p0, p1, p2, p3));
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

	function log(bool p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,uint256)", p0, p1, p2, p3));
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

	function log(bool p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,uint256)", p0, p1, p2, p3));
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

	function log(bool p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,uint256)", p0, p1, p2, p3));
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

	function log(bool p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,uint256)", p0, p1, p2, p3));
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

	function log(bool p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,uint256)", p0, p1, p2, p3));
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

	function log(bool p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,uint256)", p0, p1, p2, p3));
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

	function log(bool p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,uint256)", p0, p1, p2, p3));
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

	function log(address p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,uint256)", p0, p1, p2, p3));
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

	function log(address p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,uint256)", p0, p1, p2, p3));
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

	function log(address p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,uint256)", p0, p1, p2, p3));
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

	function log(address p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,uint256)", p0, p1, p2, p3));
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

	function log(address p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,uint256)", p0, p1, p2, p3));
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

	function log(address p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,uint256)", p0, p1, p2, p3));
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

	function log(address p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,uint256)", p0, p1, p2, p3));
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

	function log(address p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,uint256)", p0, p1, p2, p3));
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

	function log(address p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,uint256)", p0, p1, p2, p3));
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