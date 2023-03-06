// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import {IEvents, IAccount} from "./interfaces/IEvents.sol";

/// @title Consolidates all events emitted by the Smart Margin Accounts
/// @author JaredBorders ([email protected])
contract Events is IEvents {
    /// @inheritdoc IEvents
    function emitDeposit(address user, address account, uint256 amount) external override {
        emit Deposit({user: user, account: account, amount: amount});
    }

    /// @inheritdoc IEvents
    function emitWithdraw(address user, address account, uint256 amount) external override {
        emit Withdraw({user: user, account: account, amount: amount});
    }

    /// @inheritdoc IEvents
    function emitEthWithdraw(address user, address account, uint256 amount) external override {
        emit EthWithdraw({user: user, account: account, amount: amount});
    }

    /// @inheritdoc IEvents
    function emitConditionalOrderPlaced(
        address account,
        uint256 conditionalOrderId,
        bytes32 marketKey,
        int256 marginDelta,
        int256 sizeDelta,
        uint256 targetPrice,
        IAccount.ConditionalOrderTypes conditionalOrderType,
        uint128 priceImpactDelta,
        bool reduceOnly
    ) external override {
        emit ConditionalOrderPlaced({
            account: account,
            conditionalOrderId: conditionalOrderId,
            marketKey: marketKey,
            marginDelta: marginDelta,
            sizeDelta: sizeDelta,
            targetPrice: targetPrice,
            conditionalOrderType: conditionalOrderType,
            priceImpactDelta: priceImpactDelta,
            reduceOnly: reduceOnly
        });
    }

    /// @inheritdoc IEvents
    function emitConditionalOrderCancelled(
        address account,
        uint256 conditionalOrderId,
        IAccount.ConditionalOrderCancelledReason reason
    ) external override {
        emit ConditionalOrderCancelled({
            account: account,
            conditionalOrderId: conditionalOrderId,
            reason: reason
        });
    }

    /// @inheritdoc IEvents
    function emitConditionalOrderFilled(
        address account,
        uint256 conditionalOrderId,
        uint256 fillPrice,
        uint256 keeperFee
    ) external override {
        emit ConditionalOrderFilled({
            account: account,
            conditionalOrderId: conditionalOrderId,
            fillPrice: fillPrice,
            keeperFee: keeperFee
        });
    }

    /// @inheritdoc IEvents
    function emitFeeImposed(address account, uint256 amount) external override {
        emit FeeImposed({account: account, amount: amount});
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import {IAddressResolver} from "@synthetix/IAddressResolver.sol";
import {IEvents} from "./IEvents.sol";
import {IExchanger} from "@synthetix/IExchanger.sol";
import {IFactory} from "./IFactory.sol";
import {IFuturesMarketManager} from "@synthetix/IFuturesMarketManager.sol";
import {IPerpsV2MarketConsolidated} from "@synthetix/IPerpsV2MarketConsolidated.sol";
import {ISettings} from "./ISettings.sol";

/// @title Kwenta Smart Margin Account Implementation Interface
/// @author JaredBorders ([email protected]), JChiaramonte7 ([email protected])
interface IAccount {
    /*///////////////////////////////////////////////////////////////
                                Types
    ///////////////////////////////////////////////////////////////*/

    /// @notice Command Flags used to decode commands to execute
    /// @dev under the hood PERPS_V2_MODIFY_MARGIN = 0, PERPS_V2_WITHDRAW_ALL_MARGIN = 1
    enum Command {
        ACCOUNT_MODIFY_MARGIN,
        ACCOUNT_WITHDRAW_ETH,
        PERPS_V2_MODIFY_MARGIN,
        PERPS_V2_WITHDRAW_ALL_MARGIN,
        PERPS_V2_SUBMIT_ATOMIC_ORDER,
        PERPS_V2_SUBMIT_DELAYED_ORDER,
        PERPS_V2_SUBMIT_OFFCHAIN_DELAYED_ORDER,
        PERPS_V2_CANCEL_DELAYED_ORDER,
        PERPS_V2_CANCEL_OFFCHAIN_DELAYED_ORDER,
        PERPS_V2_CLOSE_POSITION,
        GELATO_PLACE_CONDITIONAL_ORDER,
        GELATO_CANCEL_CONDITIONAL_ORDER
    }

    /// @notice denotes conditional order types for code clarity
    /// @dev under the hood LIMIT = 0, STOP = 1
    enum ConditionalOrderTypes {
        LIMIT,
        STOP
    }

    /// @notice denotes conditional order cancelled reasons for code clarity
    /// @dev under the hood CONDITIONAL_ORDER_CANCELLED_BY_USER = 0, CONDITIONAL_ORDER_CANCELLED_NOT_REDUCE_ONLY = 1
    enum ConditionalOrderCancelledReason {
        CONDITIONAL_ORDER_CANCELLED_BY_USER,
        CONDITIONAL_ORDER_CANCELLED_NOT_REDUCE_ONLY
    }

    /// marketKey: Synthetix PerpsV2 Market id/key
    /// marginDelta: amount of margin to deposit or withdraw; positive indicates deposit, negative withdraw
    /// sizeDelta: denoted in market currency (i.e. ETH, BTC, etc), size of Synthetix PerpsV2 position
    /// targetPrice: limit or stop price to fill at
    /// gelatoTaskId: unqiue taskId from gelato necessary for cancelling conditional orders
    /// conditionalOrderType: conditional order type to determine conditional order fill logic
    /// priceImpactDelta: price impact tolerance as a percentage used on fillPrice at execution
    /// reduceOnly: if true, only allows position's absolute size to decrease
    struct ConditionalOrder {
        bytes32 marketKey;
        int256 marginDelta;
        int256 sizeDelta;
        uint256 targetPrice;
        bytes32 gelatoTaskId;
        ConditionalOrderTypes conditionalOrderType;
        uint128 priceImpactDelta;
        bool reduceOnly;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice thrown when commands length does not equal inputs length
    error LengthMismatch();

    /// @notice thrown when Command given is not valid
    error InvalidCommandType(uint256 commandType);

    /// @notice thrown when margin asset transfer fails
    error FailedMarginTransfer();

    /// @notice given value cannot be zero
    /// @param valueName: name of the variable that cannot be zero
    error ValueCannotBeZero(bytes32 valueName);

    /// @notice exceeds useable margin
    /// @param available: amount of useable margin asset
    /// @param required: amount of margin asset required
    error InsufficientFreeMargin(uint256 available, uint256 required);

    /// @notice call to transfer ETH on withdrawal fails
    error EthWithdrawalFailed();

    /// @notice base price from the oracle was invalid
    /// @dev Rate can be invalid either due to:
    ///     1. Returned as invalid from ExchangeRates - due to being stale or flagged by oracle
    ///     2. Out of deviation bounds w.r.t. to previously stored rate
    ///     3. if there is no valid stored rate, w.r.t. to previous 3 oracle rates
    ///     4. Price is zero
    error InvalidPrice();

    /// @notice Insufficient margin to pay fee
    error CannotPayFee();

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice returns the version of the Account
    function VERSION() external view returns (bytes32);

    /// @return returns the address of the factory
    function factory() external view returns (IFactory);

    /// @return returns the address of the futures market manager
    function futuresMarketManager() external view returns (IFuturesMarketManager);

    /// @return returns the address of the native settings for account
    function settings() external view returns (ISettings);

    /// @return returns the address of events contract for accounts
    function events() external view returns (IEvents);

    /// @return returns the amount of margin locked for future events (i.e. conditional orders)
    function committedMargin() external view returns (uint256);

    /// @return returns current conditional order id
    function conditionalOrderId() external view returns (uint256);

    /// @notice get delayed order data from Synthetix PerpsV2
    /// @dev call reverts if _marketKey is invalid
    /// @param _marketKey: key for Synthetix PerpsV2 Market
    /// @return delayed order struct defining delayed order (will return empty struct if no delayed order exists)
    function getDelayedOrder(bytes32 _marketKey)
        external
        returns (IPerpsV2MarketConsolidated.DelayedOrder memory);

    /// @notice checker() is the Resolver for Gelato
    /// (see https://docs.gelato.network/developer-services/automate/guides/custom-logic-triggers/smart-contract-resolvers)
    /// @notice signal to a keeper that a conditional order is valid/invalid for execution
    /// @dev call reverts if conditional order Id does not map to a valid conditional order;
    /// ConditionalOrder.marketKey would be invalid
    /// @param _conditionalOrderId: key for an active conditional order
    /// @return canExec boolean that signals to keeper a conditional order can be executed by Gelato
    /// @return execPayload calldata for executing a conditional order
    function checker(uint256 _conditionalOrderId)
        external
        view
        returns (bool canExec, bytes memory execPayload);

    /// @notice the current withdrawable or usable balance
    /// @return free margin amount
    function freeMargin() external view returns (uint256);

    /// @notice get up-to-date position data from Synthetix PerpsV2
    /// @param _marketKey: key for Synthetix PerpsV2 Market
    /// @return position struct defining current position
    function getPosition(bytes32 _marketKey)
        external
        returns (IPerpsV2MarketConsolidated.Position memory);

    /// @notice conditional order id mapped to conditional order
    /// @param _conditionalOrderId: id of conditional order
    /// @return conditional order
    function getConditionalOrder(uint256 _conditionalOrderId)
        external
        view
        returns (ConditionalOrder memory);

    /*//////////////////////////////////////////////////////////////
                                MUTATIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice executes commands along with provided inputs
    /// @param _commands: array of commands, each represented as an enum
    /// @param _inputs: array of byte strings containing abi encoded inputs for each command
    function execute(Command[] calldata _commands, bytes[] calldata _inputs) external payable;

    /// @notice execute a gelato queued conditional order
    /// @notice only keepers can trigger this function
    /// @dev currently only supports conditional order submission via PERPS_V2_SUBMIT_OFFCHAIN_DELAYED_ORDER COMMAND
    /// @param _conditionalOrderId: key for an active conditional order
    function executeConditionalOrder(uint256 _conditionalOrderId) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import {IAccount} from "./IAccount.sol";

/// @title Interface for contract that emits all events emitted by the Smart Margin Accounts
/// @author JaredBorders ([email protected])
interface IEvents {
    /// @notice emitted after a successful withdrawal
    /// @param user: the address that withdrew from account
    /// @param account: the account that was withdrawn from
    /// @param amount: amount of marginAsset to withdraw from account
    function emitDeposit(address user, address account, uint256 amount) external;

    // @inheritdoc IAccount
    event Deposit(address indexed user, address indexed account, uint256 amount);

    /// @notice emitted after a successful withdrawal
    /// @param user: the address that withdrew from account
    /// @param account: the account that was withdrawn from
    /// @param amount: amount of marginAsset to withdraw from account
    function emitWithdraw(address user, address account, uint256 amount) external;

    // @inheritdoc IAccount
    event Withdraw(address indexed user, address indexed account, uint256 amount);

    /// @notice emitted after a successful ETH withdrawal
    /// @param user: the address that withdrew from account
    /// @param amount: the account that was withdrawn from
    /// @param amount: amount of ETH to withdraw from account
    function emitEthWithdraw(address user, address account, uint256 amount) external;

    // @inheritdoc IAccount
    event EthWithdraw(address indexed user, address indexed account, uint256 amount);

    /// @notice emitted when a conditional order is placed
    /// @param account: account placing the conditional order
    /// @param conditionalOrderId: id of conditional order
    /// @param marketKey: Synthetix PerpsV2 market key
    /// @param marginDelta: margin change
    /// @param sizeDelta: size change
    /// @param targetPrice: targeted fill price
    /// @param conditionalOrderType: expected conditional order type enum where 0 = LIMIT, 1 = STOP, etc..
    /// @param priceImpactDelta: price impact tolerance as a percentage
    /// @param reduceOnly: if true, only allows position's absolute size to decrease
    function emitConditionalOrderPlaced(
        address account,
        uint256 conditionalOrderId,
        bytes32 marketKey,
        int256 marginDelta,
        int256 sizeDelta,
        uint256 targetPrice,
        IAccount.ConditionalOrderTypes conditionalOrderType,
        uint128 priceImpactDelta,
        bool reduceOnly
    ) external;

    // @inheritdoc IAccount
    event ConditionalOrderPlaced(
        address indexed account,
        uint256 conditionalOrderId,
        bytes32 marketKey,
        int256 marginDelta,
        int256 sizeDelta,
        uint256 targetPrice,
        IAccount.ConditionalOrderTypes conditionalOrderType,
        uint128 priceImpactDelta,
        bool reduceOnly
    );

    /// @notice emitted when a conditional order is cancelled
    /// @param account: account cancelling the conditional order
    /// @param conditionalOrderId: id of conditional order
    /// @param reason: reason for cancellation
    function emitConditionalOrderCancelled(
        address account,
        uint256 conditionalOrderId,
        IAccount.ConditionalOrderCancelledReason reason
    ) external;

    // @inheritdoc IAccount
    event ConditionalOrderCancelled(
        address indexed account,
        uint256 conditionalOrderId,
        IAccount.ConditionalOrderCancelledReason reason
    );

    /// @notice emitted when a conditional order is filled
    /// @param account: account that placed the conditional order
    /// @param conditionalOrderId: id of conditional order
    /// @param fillPrice: price the conditional order was executed at
    /// @param keeperFee: fees paid to the executor
    function emitConditionalOrderFilled(
        address account,
        uint256 conditionalOrderId,
        uint256 fillPrice,
        uint256 keeperFee
    ) external;

    // @inheritdoc IAccount
    event ConditionalOrderFilled(
        address indexed account, uint256 conditionalOrderId, uint256 fillPrice, uint256 keeperFee
    );

    /// @notice emitted after a fee has been transferred to Treasury
    /// @param account: the address of the account the fee was imposed on
    /// @param amount: fee amount sent to Treasury
    function emitFeeImposed(address account, uint256 amount) external;

    // @inheritdoc IAccount
    event FeeImposed(address indexed account, uint256 amount);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

/// @title Kwenta Factory Interface
/// @author JaredBorders ([email protected])
interface IFactory {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted when new account is created
    /// @param creator: account creator (address that called newAccount())
    /// @param account: address of account that was created (will be address of proxy)
    event NewAccount(address indexed creator, address indexed account, bytes32 version);

    /// @notice emitted when implementation is upgraded
    /// @param implementation: address of new implementation
    event AccountImplementationUpgraded(address implementation);

    /// @notice emitted when settings contract is upgraded
    /// @param settings: address of new settings contract
    event SettingsUpgraded(address settings);

    /// @notice emitted when events contract is upgraded
    /// @param events: address of new events contract
    event EventsUpgraded(address events);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice thrown when newAccount() is called
    /// by an address which has already made an account
    /// @param account: address of account previously created
    error OnlyOneAccountPerAddress(address account);

    /// @notice thrown when Account creation fails at initialization step
    /// @param data: data returned from failed low-level call
    error AccountFailedToInitialize(bytes data);

    /// @notice thrown when Account creation fails due to no version being set
    /// @param data: data returned from failed low-level call
    error AccountFailedToFetchVersion(bytes data);

    /// @notice thrown when factory is not upgradable
    error CannotUpgrade();

    /// @notice thrown account owner is unrecognized via ownerToAccount mapping
    error AccountDoesNotExist();

    /// @notice thrown when caller is not an account
    error CallerMustBeAccount();

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @return canUpgrade: bool to determine if factory can be upgraded
    function canUpgrade() external view returns (bool);

    /// @return logic: account logic address
    function implementation() external view returns (address);

    /// @return settings: address of settings contract for accounts
    function settings() external view returns (address);

    /// @return events: address of events contract for accounts
    function events() external view returns (address);

    /// @return address of account owned by _owner
    /// @param _owner: owner of account
    function ownerToAccount(address _owner) external view returns (address);

    /*//////////////////////////////////////////////////////////////
                                MUTATIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice create unique account proxy for function caller
    /// @return accountAddress address of account created
    function newAccount() external returns (address payable accountAddress);

    /// @notice update account owner
    /// @param _oldOwner: old owner of account
    /// @param _newOwner: new owner of account
    function updateAccountOwner(address _oldOwner, address _newOwner) external;

    /*//////////////////////////////////////////////////////////////
                             UPGRADABILITY
    //////////////////////////////////////////////////////////////*/

    /// @notice upgrade implementation of account which all account proxies currently point to
    /// @dev this *will* impact all existing accounts
    /// @dev future accounts will also point to this new implementation (until
    /// upgradeAccountImplementation() is called again with a newer implementation)
    /// @dev *DANGER* this function does not check the new implementation for validity,
    /// thus, a bad upgrade could result in severe consequences.
    /// @param _implementation: address of new implementation
    function upgradeAccountImplementation(address _implementation) external;

    /// @dev upgrade settings contract for all future accounts; existing accounts will not be affected
    /// and will point to settings address they were initially deployed with
    /// @param _settings: address of new settings contract
    function upgradeSettings(address _settings) external;

    /// @dev upgrade events contract for all future accounts; existing accounts will not be affected
    /// and will point to events address they were initially deployed with
    /// @param _events: address of new events contract
    function upgradeEvents(address _events) external;

    /// @notice remove upgradability from factory
    /// @dev cannot be undone
    function removeUpgradability() external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

/// @title Kwenta Settings Interface
/// @author JaredBorders ([email protected])
/// @dev all fees are denoted in Basis points (BPS)
interface ISettings {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted after changing treasury address
    /// @param treasury: new treasury address
    event TreasuryAddressChanged(address treasury);

    /// @notice emitted after a successful trade fee change
    /// @param fee: fee denoted in BPS
    event TradeFeeChanged(uint256 fee);

    /// @notice emitted after a successful limit order fee change
    /// @param fee: fee denoted in BPS
    event LimitOrderFeeChanged(uint256 fee);

    /// @notice emitted after a successful stop loss fee change
    /// @param fee: fee denoted in BPS
    event StopOrderFeeChanged(uint256 fee);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice zero address cannot be used
    error ZeroAddress();

    /// @notice new treasury address cannot be the same as the old treasury address
    error DuplicateAddress();

    /// @notice invalid fee (fee > MAX_BPS)
    /// @param fee: fee denoted in BPS
    error InvalidFee(uint256 fee);

    /// @notice new fee cannot be the same as the old fee
    error DuplicateFee();

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @return max BPS; used for decimals calculations
    // solhint-disable-next-line func-name-mixedcase
    function MAX_BPS() external view returns (uint256);

    // @return Kwenta's Treasury Address
    function treasury() external view returns (address);

    /// @return fee imposed on all trades
    function tradeFee() external view returns (uint256);

    /// @return fee imposed on limit orders
    function limitOrderFee() external view returns (uint256);

    /// @return fee imposed on stop losses
    function stopOrderFee() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                                MUTATIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice set new treasury address
    /// @param _treasury: new treasury address
    function setTreasury(address _treasury) external;

    /// @notice set new trade fee
    /// @param _fee: fee imposed on all trades
    function setTradeFee(uint256 _fee) external;

    /// @notice set new limit order fee
    /// @param _fee: fee imposed on limit orders
    function setLimitOrderFee(uint256 _fee) external;

    /// @notice set new stop loss fee
    /// @param _fee: fee imposed on stop losses
    function setStopOrderFee(uint256 _fee) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

// https://docs.synthetix.io/contracts/source/interfaces/iaddressresolver
interface IAddressResolver {
    function getAddress(bytes32 name) external view returns (address);

    function getSynth(bytes32 key) external view returns (address);

    function requireAndGetAddress(bytes32 name, string calldata reason)
        external
        view
        returns (address);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

pragma experimental ABIEncoderV2;

import "./IVirtualSynth.sol";

// https://docs.synthetix.io/contracts/source/interfaces/iexchanger
interface IExchanger {
    struct ExchangeEntrySettlement {
        bytes32 src;
        uint256 amount;
        bytes32 dest;
        uint256 reclaim;
        uint256 rebate;
        uint256 srcRoundIdAtPeriodEnd;
        uint256 destRoundIdAtPeriodEnd;
        uint256 timestamp;
    }

    struct ExchangeEntry {
        uint256 sourceRate;
        uint256 destinationRate;
        uint256 destinationAmount;
        uint256 exchangeFeeRate;
        uint256 exchangeDynamicFeeRate;
        uint256 roundIdForSrc;
        uint256 roundIdForDest;
        uint256 sourceAmountAfterSettlement;
    }

    // Views
    function calculateAmountAfterSettlement(
        address from,
        bytes32 currencyKey,
        uint256 amount,
        uint256 refunded
    ) external view returns (uint256 amountAfterSettlement);

    function isSynthRateInvalid(bytes32 currencyKey) external view returns (bool);

    function maxSecsLeftInWaitingPeriod(address account, bytes32 currencyKey)
        external
        view
        returns (uint256);

    function settlementOwing(address account, bytes32 currencyKey)
        external
        view
        returns (uint256 reclaimAmount, uint256 rebateAmount, uint256 numEntries);

    function hasWaitingPeriodOrSettlementOwing(address account, bytes32 currencyKey)
        external
        view
        returns (bool);

    function feeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey)
        external
        view
        returns (uint256);

    function dynamicFeeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey)
        external
        view
        returns (uint256 feeRate, bool tooVolatile);

    function getAmountsForExchange(
        uint256 sourceAmount,
        bytes32 sourceCurrencyKey,
        bytes32 destinationCurrencyKey
    ) external view returns (uint256 amountReceived, uint256 fee, uint256 exchangeFeeRate);

    function priceDeviationThresholdFactor() external view returns (uint256);

    function waitingPeriodSecs() external view returns (uint256);

    function lastExchangeRate(bytes32 currencyKey) external view returns (uint256);

    // Mutative functions
    function exchange(
        address exchangeForAddress,
        address from,
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey,
        address destinationAddress,
        bool virtualSynth,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint256 amountReceived, IVirtualSynth vSynth);

    function exchangeAtomically(
        address from,
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey,
        address destinationAddress,
        bytes32 trackingCode,
        uint256 minAmount
    ) external returns (uint256 amountReceived);

    function settle(address from, bytes32 currencyKey)
        external
        returns (uint256 reclaimed, uint256 refunded, uint256 numEntries);
}

// Used to have strongly-typed access to internal mutative functions in Synthetix
interface ISynthetixInternal {
    function emitExchangeTracking(
        bytes32 trackingCode,
        bytes32 toCurrencyKey,
        uint256 toAmount,
        uint256 fee
    ) external;

    function emitSynthExchange(
        address account,
        bytes32 fromCurrencyKey,
        uint256 fromAmount,
        bytes32 toCurrencyKey,
        uint256 toAmount,
        address toAddress
    ) external;

    function emitAtomicSynthExchange(
        address account,
        bytes32 fromCurrencyKey,
        uint256 fromAmount,
        bytes32 toCurrencyKey,
        uint256 toAmount,
        address toAddress
    ) external;

    function emitExchangeReclaim(address account, bytes32 currencyKey, uint256 amount) external;

    function emitExchangeRebate(address account, bytes32 currencyKey, uint256 amount) external;
}

interface IExchangerInternalDebtCache {
    function updateCachedSynthDebtsWithRates(
        bytes32[] calldata currencyKeys,
        uint256[] calldata currencyRates
    ) external;

    function updateCachedSynthDebts(bytes32[] calldata currencyKeys) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

interface IFuturesMarketManager {
    function markets(uint256 index, uint256 pageSize) external view returns (address[] memory);

    function markets(uint256 index, uint256 pageSize, bool proxiedMarkets)
        external
        view
        returns (address[] memory);

    function numMarkets() external view returns (uint256);

    function numMarkets(bool proxiedMarkets) external view returns (uint256);

    function allMarkets() external view returns (address[] memory);

    function allMarkets(bool proxiedMarkets) external view returns (address[] memory);

    function marketForKey(bytes32 marketKey) external view returns (address);

    function marketsForKeys(bytes32[] calldata marketKeys)
        external
        view
        returns (address[] memory);

    function totalDebt() external view returns (uint256 debt, bool isInvalid);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

interface IPerpsV2MarketBaseTypes {
    /* ========== TYPES ========== */

    enum OrderType {
        Atomic,
        Delayed,
        Offchain
    }

    enum Status {
        Ok,
        InvalidPrice,
        InvalidOrderType,
        PriceOutOfBounds,
        CanLiquidate,
        CannotLiquidate,
        MaxMarketSizeExceeded,
        MaxLeverageExceeded,
        InsufficientMargin,
        NotPermitted,
        NilOrder,
        NoPositionOpen,
        PriceTooVolatile,
        PriceImpactToleranceExceeded
    }

    // If margin/size are positive, the position is long; if negative then it is short.
    struct Position {
        uint64 id;
        uint64 lastFundingIndex;
        uint128 margin;
        uint128 lastPrice;
        int128 size;
    }

    // Delayed order storage
    struct DelayedOrder {
        bool isOffchain; // flag indicating the delayed order is offchain
        int128 sizeDelta; // difference in position to pass to modifyPosition
        uint128 priceImpactDelta; // price impact tolerance as a percentage used on fillPrice at execution
        uint128 targetRoundId; // price oracle roundId using which price this order needs to executed
        uint128 commitDeposit; // the commitDeposit paid upon submitting that needs to be refunded if order succeeds
        uint128 keeperDeposit; // the keeperDeposit paid upon submitting that needs to be paid / refunded on tx confirmation
        uint256 executableAtTime; // The timestamp at which this order is executable at
        uint256 intentionTime; // The block timestamp of submission
        bytes32 trackingCode; // tracking code to emit on execution for volume source fee sharing
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import "./IPerpsV2MarketBaseTypes.sol";

pragma experimental ABIEncoderV2;

// Helper Interface, only used in tests and to provide a consolidated interface to PerpsV2 users/integrators

interface IPerpsV2MarketConsolidated {
    /* ========== TYPES ========== */
    enum OrderType {
        Atomic,
        Delayed,
        Offchain
    }

    enum Status {
        Ok,
        InvalidPrice,
        InvalidOrderPrice,
        PriceOutOfBounds,
        CanLiquidate,
        CannotLiquidate,
        MaxMarketSizeExceeded,
        MaxLeverageExceeded,
        InsufficientMargin,
        NotPermitted,
        NilOrder,
        NoPositionOpen,
        PriceTooVolatile,
        PriceImpactToleranceExceeded
    }

    // If margin/size are positive, the position is long; if negative then it is short.
    struct Position {
        uint64 id;
        uint64 lastFundingIndex;
        uint128 margin;
        uint128 lastPrice;
        int128 size;
    }

    // Delayed order storage
    struct DelayedOrder {
        bool isOffchain; // flag indicating the delayed order is offchain
        int128 sizeDelta; // difference in position to pass to modifyPosition
        uint128 priceImpactDelta; // price impact tolerance as a percentage used on fillPrice at execution
        uint128 targetRoundId; // price oracle roundId using which price this order needs to executed
        uint128 commitDeposit; // the commitDeposit paid upon submitting that needs to be refunded if order succeeds
        uint128 keeperDeposit; // the keeperDeposit paid upon submitting that needs to be paid / refunded on tx confirmation
        uint256 executableAtTime; // The timestamp at which this order is executable at
        uint256 intentionTime; // The block timestamp of submission
        bytes32 trackingCode; // tracking code to emit on execution for volume source fee sharing
    }

    /* ========== Views ========== */
    /* ---------- Market Details ---------- */

    function marketKey() external view returns (bytes32 key);

    function baseAsset() external view returns (bytes32 key);

    function marketSize() external view returns (uint128 size);

    function marketSkew() external view returns (int128 skew);

    function fundingLastRecomputed() external view returns (uint32 timestamp);

    function fundingSequence(uint256 index) external view returns (int128 netFunding);

    function positions(address account) external view returns (Position memory);

    function delayedOrders(address account) external view returns (DelayedOrder memory);

    function assetPrice() external view returns (uint256 price, bool invalid);

    function marketSizes() external view returns (uint256 long, uint256 short);

    function marketDebt() external view returns (uint256 debt, bool isInvalid);

    function currentFundingRate() external view returns (int256 fundingRate);

    function currentFundingVelocity() external view returns (int256 fundingVelocity);

    function unrecordedFunding() external view returns (int256 funding, bool invalid);

    function fundingSequenceLength() external view returns (uint256 length);

    /* ---------- Position Details ---------- */

    function notionalValue(address account) external view returns (int256 value, bool invalid);

    function profitLoss(address account) external view returns (int256 pnl, bool invalid);

    function accruedFunding(address account) external view returns (int256 funding, bool invalid);

    function remainingMargin(address account)
        external
        view
        returns (uint256 marginRemaining, bool invalid);

    function accessibleMargin(address account)
        external
        view
        returns (uint256 marginAccessible, bool invalid);

    function liquidationPrice(address account)
        external
        view
        returns (uint256 price, bool invalid);

    function liquidationFee(address account) external view returns (uint256);

    function canLiquidate(address account) external view returns (bool);

    function orderFee(int256 sizeDelta, IPerpsV2MarketBaseTypes.OrderType orderType)
        external
        view
        returns (uint256 fee, bool invalid);

    function postTradeDetails(
        int256 sizeDelta,
        uint256 tradePrice,
        IPerpsV2MarketBaseTypes.OrderType orderType,
        address sender
    )
        external
        view
        returns (
            uint256 margin,
            int256 size,
            uint256 price,
            uint256 liqPrice,
            uint256 fee,
            Status status
        );

    /* ========== Market ========== */
    function recomputeFunding() external returns (uint256 lastIndex);

    function transferMargin(int256 marginDelta) external;

    function withdrawAllMargin() external;

    function modifyPosition(int256 sizeDelta, uint256 priceImpactDelta) external;

    function modifyPositionWithTracking(
        int256 sizeDelta,
        uint256 priceImpactDelta,
        bytes32 trackingCode
    ) external;

    function closePosition(uint256 priceImpactDelta) external;

    function closePositionWithTracking(uint256 priceImpactDelta, bytes32 trackingCode) external;

    function liquidatePosition(address account) external;

    /* ========== DelayedOrder ========== */
    function submitDelayedOrder(
        int256 sizeDelta,
        uint256 priceImpactDelta,
        uint256 desiredTimeDelta
    ) external;

    function submitDelayedOrderWithTracking(
        int256 sizeDelta,
        uint256 priceImpactDelta,
        uint256 desiredTimeDelta,
        bytes32 trackingCode
    ) external;

    function cancelDelayedOrder(address account) external;

    function executeDelayedOrder(address account) external;

    /* ========== OffchainDelayedOrder ========== */
    function submitOffchainDelayedOrder(int256 sizeDelta, uint256 priceImpactDelta) external;

    function submitOffchainDelayedOrderWithTracking(
        int256 sizeDelta,
        uint256 priceImpactDelta,
        bytes32 trackingCode
    ) external;

    function cancelOffchainDelayedOrder(address account) external;

    function executeOffchainDelayedOrder(address account, bytes[] calldata priceUpdateData)
        external
        payable;

    /* ========== Events ========== */

    event PositionModified(
        uint256 indexed id,
        address indexed account,
        uint256 margin,
        int256 size,
        int256 tradeSize,
        uint256 lastPrice,
        uint256 fundingIndex,
        uint256 fee
    );

    event MarginTransferred(address indexed account, int256 marginDelta);

    event PositionLiquidated(
        uint256 id, address account, address liquidator, int256 size, uint256 price, uint256 fee
    );

    event FundingRecomputed(int256 funding, int256 fundingRate, uint256 index, uint256 timestamp);

    event PerpsTracking(
        bytes32 indexed trackingCode,
        bytes32 baseAsset,
        bytes32 marketKey,
        int256 sizeDelta,
        uint256 fee
    );

    event DelayedOrderRemoved(
        address indexed account,
        bool isOffchain,
        uint256 currentRoundId,
        int256 sizeDelta,
        uint256 targetRoundId,
        uint256 commitDeposit,
        uint256 keeperDeposit,
        bytes32 trackingCode
    );

    event DelayedOrderSubmitted(
        address indexed account,
        bool isOffchain,
        int256 sizeDelta,
        uint256 targetRoundId,
        uint256 intentionTime,
        uint256 executableAtTime,
        uint256 commitDeposit,
        uint256 keeperDeposit,
        bytes32 trackingCode
    );
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

// https://docs.synthetix.io/contracts/source/interfaces/isynth
interface ISynth {
    // Views
    function currencyKey() external view returns (bytes32);

    function transferableSynths(address account) external view returns (uint256);

    // Mutative functions
    function transferAndSettle(address to, uint256 value) external returns (bool);

    function transferFromAndSettle(address from, address to, uint256 value)
        external
        returns (bool);

    // Restricted: used internally to Synthetix
    function burn(address account, uint256 amount) external;

    function issue(address account, uint256 amount) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import "./ISynth.sol";

interface IVirtualSynth {
    // Views
    function balanceOfUnderlying(address account) external view returns (uint256);

    function rate() external view returns (uint256);

    function readyToSettle() external view returns (bool);

    function secsLeftInWaitingPeriod() external view returns (uint256);

    function settled() external view returns (bool);

    function synth() external view returns (ISynth);

    // Mutative functions
    function settle(address account) external;
}