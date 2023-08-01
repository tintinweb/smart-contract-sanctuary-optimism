// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import {Auth} from "src/utils/Auth.sol";
import {BytesLib} from "src/utils/uniswap/BytesLib.sol";
import {
    IAccount, IPerpsV2MarketConsolidated
} from "src/interfaces/IAccount.sol";
import {IFactory} from "src/interfaces/IFactory.sol";
import {IFuturesMarketManager} from
    "src/interfaces/synthetix/IFuturesMarketManager.sol";
import {IPermit2} from "src/interfaces/uniswap/IPermit2.sol";
import {ISettings} from "src/interfaces/ISettings.sol";
import {ISystemStatus} from "src/interfaces/synthetix/ISystemStatus.sol";
import {IOps} from "src/interfaces/gelato/IOps.sol";
import {IUniversalRouter} from "src/interfaces/uniswap/IUniversalRouter.sol";
import {IEvents} from "src/interfaces/IEvents.sol";
import {IPerpsV2ExchangeRate} from
    "src/interfaces/synthetix/IPerpsV2ExchangeRate.sol";
import {OpsReady} from "src/utils/gelato/OpsReady.sol";
import {SafeCast160} from "src/utils/uniswap/SafeCast160.sol";
import {IERC20} from "src/interfaces/token/IERC20.sol";
import {V3Path} from "src/utils/uniswap/V3Path.sol";

/// @title Kwenta Smart Margin Account Implementation
/// @author JaredBorders ([email protected]), JChiaramonte7 ([email protected])
/// @notice flexible smart margin account enabling users to trade on-chain derivatives
contract Account is IAccount, Auth, OpsReady {
    using V3Path for bytes;
    using BytesLib for bytes;
    using SafeCast160 for uint256;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAccount
    bytes32 public constant VERSION = "2.1.0";

    /// @notice tracking code used when modifying positions
    bytes32 internal constant TRACKING_CODE = "KWENTA";

    /// @notice used to ensure the pyth provided price is sufficiently recent
    /// @dev price cannot be older than MAX_PRICE_LATENCY seconds
    uint256 internal constant MAX_PRICE_LATENCY = 120;

    /// @notice Uniswap's Universal Router command for swapping tokens
    /// @dev specifically for swapping exact tokens in for a non-exact amount of tokens out
    uint256 internal constant V3_SWAP_EXACT_IN = 0x00;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice address of the Smart Margin Account Factory
    IFactory internal immutable FACTORY;

    /// @notice address of the contract used by all accounts for emitting events
    /// @dev can be immutable due to the fact the events contract is
    /// upgraded alongside the account implementation
    IEvents internal immutable EVENTS;

    /// @notice address of the Synthetix ProxyERC20sUSD contract used as the margin asset
    /// @dev can be immutable due to the fact the sUSD contract is a proxy address
    IERC20 internal immutable MARGIN_ASSET;

    /// @notice address of the Synthetix PerpsV2ExchangeRate
    /// @dev used internally by Synthetix Perps V2 contracts to retrieve asset exchange rates
    IPerpsV2ExchangeRate internal immutable PERPS_V2_EXCHANGE_RATE;

    /// @notice address of the Synthetix FuturesMarketManager
    /// @dev the manager keeps track of which markets exist, and is the main window between
    /// perpsV2 markets and the rest of the synthetix system. It accumulates the total debt
    /// over all markets, and issues and burns sUSD on each market's behalf
    IFuturesMarketManager internal immutable FUTURES_MARKET_MANAGER;

    /// @notice address of the Synthetix SystemStatus
    /// @dev the system status contract is used to check if the system is operational
    ISystemStatus internal immutable SYSTEM_STATUS;

    /// @notice address of contract used to store global settings
    ISettings internal immutable SETTINGS;

    /// @notice address of Uniswap's Universal Router
    IUniversalRouter internal immutable UNISWAP_UNIVERSAL_ROUTER;

    /// @notice address of Uniswap's Permit2
    IPermit2 public immutable PERMIT2;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAccount
    uint256 public committedMargin;

    /// @inheritdoc IAccount
    uint256 public conditionalOrderId;

    /// @notice track conditional orders by id
    mapping(uint256 id => ConditionalOrder order) internal conditionalOrders;

    /// @notice value used for reentrancy protection
    /// @dev nonReentrant checks that locked is NOT EQUAL to 2
    uint256 internal locked;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier isAccountExecutionEnabled() {
        if (!SETTINGS.accountExecutionEnabled()) {
            revert AccountExecutionDisabled();
        }

        _;
    }

    modifier nonReentrant() {
        /// @dev locked is intially set to 0 due to the proxy nature of SM accounts
        /// however after the inital call to nonReentrant(), locked will be set to 1
        if (locked == 2) revert Reentrancy();
        locked = 2;

        _;

        locked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @dev set owner of implementation to zero address
    /// @param _params: constructor parameters (see IAccount.sol)
    constructor(AccountConstructorParams memory _params)
        Auth(address(0))
        OpsReady(_params.gelato, _params.ops)
    {
        FACTORY = IFactory(_params.factory);
        EVENTS = IEvents(_params.events);
        MARGIN_ASSET = IERC20(_params.marginAsset);
        PERPS_V2_EXCHANGE_RATE =
            IPerpsV2ExchangeRate(_params.perpsV2ExchangeRate);
        FUTURES_MARKET_MANAGER =
            IFuturesMarketManager(_params.futuresMarketManager);
        SYSTEM_STATUS = ISystemStatus(_params.systemStatus);
        SETTINGS = ISettings(_params.settings);
        UNISWAP_UNIVERSAL_ROUTER = IUniversalRouter(_params.universalRouter);
        PERMIT2 = IPermit2(_params.permit2);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAccount
    function getDelayedOrder(bytes32 _marketKey)
        external
        view
        override
        returns (IPerpsV2MarketConsolidated.DelayedOrder memory order)
    {
        // fetch delayed order data from Synthetix
        order = _getPerpsV2Market(_marketKey).delayedOrders(address(this));
    }

    /// @inheritdoc IAccount
    function checker(uint256 _conditionalOrderId)
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        canExec = _validConditionalOrder(_conditionalOrderId);

        // calldata for execute func
        execPayload =
            abi.encodeCall(this.executeConditionalOrder, _conditionalOrderId);
    }

    /// @inheritdoc IAccount
    function freeMargin() public view override returns (uint256) {
        return MARGIN_ASSET.balanceOf(address(this)) - committedMargin;
    }

    /// @inheritdoc IAccount
    function getPosition(bytes32 _marketKey)
        public
        view
        override
        returns (IPerpsV2MarketConsolidated.Position memory position)
    {
        // fetch position data from Synthetix
        position = _getPerpsV2Market(_marketKey).positions(address(this));
    }

    /// @inheritdoc IAccount
    function getConditionalOrder(uint256 _conditionalOrderId)
        public
        view
        override
        returns (ConditionalOrder memory)
    {
        return conditionalOrders[_conditionalOrderId];
    }

    /*//////////////////////////////////////////////////////////////
                               OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAccount
    function setInitialOwnership(address _owner) external override {
        if (msg.sender != address(FACTORY)) revert Unauthorized();
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    /// @notice transfer ownership of account to new address
    /// @dev update factory's record of account ownership
    /// @param _newOwner: new account owner
    function transferOwnership(address _newOwner) public override {
        // will revert if msg.sender is *NOT* owner
        super.transferOwnership(_newOwner);

        // update the factory's record of owners and account addresses
        FACTORY.updateAccountOwnership({
            _newOwner: _newOwner,
            _oldOwner: msg.sender // verified to be old owner
        });
    }

    /*//////////////////////////////////////////////////////////////
                               EXECUTION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAccount
    function execute(Command[] calldata _commands, bytes[] calldata _inputs)
        external
        payable
        override
        nonReentrant
        isAccountExecutionEnabled
    {
        uint256 numCommands = _commands.length;
        if (_inputs.length != numCommands) {
            revert LengthMismatch();
        }

        // loop through all given commands and execute them
        for (uint256 commandIndex = 0; commandIndex < numCommands;) {
            _dispatch(_commands[commandIndex], _inputs[commandIndex]);
            unchecked {
                ++commandIndex;
            }
        }
    }

    /// @notice Decodes and executes the given command with the given inputs
    /// @param _command: The command type to execute
    /// @param _inputs: The inputs to execute the command with
    function _dispatch(Command _command, bytes calldata _inputs) internal {
        uint256 commandIndex = uint256(_command);

        if (commandIndex < 2 || commandIndex == 14 || commandIndex == 15) {
            /// @dev only owner can execute the following commands
            if (!isOwner()) revert Unauthorized();

            if (_command == Command.ACCOUNT_MODIFY_MARGIN) {
                // Command.ACCOUNT_MODIFY_MARGIN
                int256 amount;
                assembly {
                    amount := calldataload(_inputs.offset)
                }
                _modifyAccountMargin({_amount: amount});
            } else if (_command == Command.ACCOUNT_WITHDRAW_ETH) {
                uint256 amount;
                assembly {
                    amount := calldataload(_inputs.offset)
                }
                _withdrawEth({_amount: amount});
            } else if (_command == Command.UNISWAP_V3_SWAP) {
                // Command.UNISWAP_V3_SWAP
                uint256 amountIn;
                uint256 amountOutMin;
                bytes calldata path = _inputs.toBytes(2);
                assembly {
                    amountIn := calldataload(_inputs.offset)
                    amountOutMin := calldataload(add(_inputs.offset, 0x20))
                    // 0x40 offset is the path; decoded above
                }
                _uniswapV3Swap({
                    _amountIn: amountIn,
                    _amountOutMin: amountOutMin,
                    _path: path
                });
            } else {
                // Command.PERMIT2_PERMIT
                IPermit2.PermitSingle calldata permitSingle;
                assembly {
                    permitSingle := _inputs.offset
                }
                bytes calldata data = _inputs.toBytes(6); // PermitSingle takes first 6 slots (0..5)
                PERMIT2.permit(msg.sender, permitSingle, data);
            }
        } else {
            /// @dev only owner and delegate(s) can execute the following commands
            if (!isAuth()) revert Unauthorized();

            if (commandIndex < 4) {
                if (_command == Command.PERPS_V2_MODIFY_MARGIN) {
                    // Command.PERPS_V2_MODIFY_MARGIN
                    address market;
                    int256 amount;
                    assembly {
                        market := calldataload(_inputs.offset)
                        amount := calldataload(add(_inputs.offset, 0x20))
                    }
                    _perpsV2ModifyMargin({_market: market, _amount: amount});
                } else {
                    // Command.PERPS_V2_WITHDRAW_ALL_MARGIN
                    address market;
                    assembly {
                        market := calldataload(_inputs.offset)
                    }
                    _perpsV2WithdrawAllMargin({_market: market});
                }
            } else if (commandIndex < 6) {
                if (_command == Command.PERPS_V2_SUBMIT_ATOMIC_ORDER) {
                    // Command.PERPS_V2_SUBMIT_ATOMIC_ORDER
                    address market;
                    int256 sizeDelta;
                    uint256 desiredFillPrice;
                    assembly {
                        market := calldataload(_inputs.offset)
                        sizeDelta := calldataload(add(_inputs.offset, 0x20))
                        desiredFillPrice :=
                            calldataload(add(_inputs.offset, 0x40))
                    }
                    _perpsV2SubmitAtomicOrder({
                        _market: market,
                        _sizeDelta: sizeDelta,
                        _desiredFillPrice: desiredFillPrice
                    });
                } else {
                    // Command.PERPS_V2_SUBMIT_DELAYED_ORDER
                    address market;
                    int256 sizeDelta;
                    uint256 desiredTimeDelta;
                    uint256 desiredFillPrice;
                    assembly {
                        market := calldataload(_inputs.offset)
                        sizeDelta := calldataload(add(_inputs.offset, 0x20))
                        desiredTimeDelta :=
                            calldataload(add(_inputs.offset, 0x40))
                        desiredFillPrice :=
                            calldataload(add(_inputs.offset, 0x60))
                    }
                    _perpsV2SubmitDelayedOrder({
                        _market: market,
                        _sizeDelta: sizeDelta,
                        _desiredTimeDelta: desiredTimeDelta,
                        _desiredFillPrice: desiredFillPrice
                    });
                }
            } else if (commandIndex < 8) {
                if (_command == Command.PERPS_V2_SUBMIT_OFFCHAIN_DELAYED_ORDER)
                {
                    // Command.PERPS_V2_SUBMIT_OFFCHAIN_DELAYED_ORDER
                    address market;
                    int256 sizeDelta;
                    uint256 desiredFillPrice;
                    assembly {
                        market := calldataload(_inputs.offset)
                        sizeDelta := calldataload(add(_inputs.offset, 0x20))
                        desiredFillPrice :=
                            calldataload(add(_inputs.offset, 0x40))
                    }
                    _perpsV2SubmitOffchainDelayedOrder({
                        _market: market,
                        _sizeDelta: sizeDelta,
                        _desiredFillPrice: desiredFillPrice
                    });
                } else {
                    // Command.PERPS_V2_CLOSE_POSITION
                    address market;
                    uint256 desiredFillPrice;
                    assembly {
                        market := calldataload(_inputs.offset)
                        desiredFillPrice :=
                            calldataload(add(_inputs.offset, 0x20))
                    }
                    _perpsV2ClosePosition({
                        _market: market,
                        _desiredFillPrice: desiredFillPrice
                    });
                }
            } else if (commandIndex < 10) {
                if (_command == Command.PERPS_V2_SUBMIT_CLOSE_DELAYED_ORDER) {
                    // Command.PERPS_V2_SUBMIT_CLOSE_DELAYED_ORDER
                    address market;
                    uint256 desiredTimeDelta;
                    uint256 desiredFillPrice;
                    assembly {
                        market := calldataload(_inputs.offset)
                        desiredTimeDelta :=
                            calldataload(add(_inputs.offset, 0x20))
                        desiredFillPrice :=
                            calldataload(add(_inputs.offset, 0x40))
                    }
                    _perpsV2SubmitCloseDelayedOrder({
                        _market: market,
                        _desiredTimeDelta: desiredTimeDelta,
                        _desiredFillPrice: desiredFillPrice
                    });
                } else {
                    // Command.PERPS_V2_SUBMIT_CLOSE_OFFCHAIN_DELAYED_ORDER
                    address market;
                    uint256 desiredFillPrice;
                    assembly {
                        market := calldataload(_inputs.offset)
                        desiredFillPrice :=
                            calldataload(add(_inputs.offset, 0x20))
                    }
                    _perpsV2SubmitCloseOffchainDelayedOrder({
                        _market: market,
                        _desiredFillPrice: desiredFillPrice
                    });
                }
            } else if (commandIndex < 12) {
                if (_command == Command.PERPS_V2_CANCEL_DELAYED_ORDER) {
                    // Command.PERPS_V2_CANCEL_DELAYED_ORDER
                    address market;
                    assembly {
                        market := calldataload(_inputs.offset)
                    }
                    _perpsV2CancelDelayedOrder({_market: market});
                } else {
                    // Command.PERPS_V2_CANCEL_OFFCHAIN_DELAYED_ORDER
                    address market;
                    assembly {
                        market := calldataload(_inputs.offset)
                    }
                    _perpsV2CancelOffchainDelayedOrder({_market: market});
                }
            } else if (commandIndex < 14) {
                if (_command == Command.GELATO_PLACE_CONDITIONAL_ORDER) {
                    // Command.GELATO_PLACE_CONDITIONAL_ORDER
                    bytes32 marketKey;
                    int256 marginDelta;
                    int256 sizeDelta;
                    uint256 targetPrice;
                    ConditionalOrderTypes conditionalOrderType;
                    uint256 desiredFillPrice;
                    bool reduceOnly;
                    assembly {
                        marketKey := calldataload(_inputs.offset)
                        marginDelta := calldataload(add(_inputs.offset, 0x20))
                        sizeDelta := calldataload(add(_inputs.offset, 0x40))
                        targetPrice := calldataload(add(_inputs.offset, 0x60))
                        conditionalOrderType :=
                            calldataload(add(_inputs.offset, 0x80))
                        desiredFillPrice :=
                            calldataload(add(_inputs.offset, 0xa0))
                        reduceOnly := calldataload(add(_inputs.offset, 0xc0))
                    }
                    _placeConditionalOrder({
                        _marketKey: marketKey,
                        _marginDelta: marginDelta,
                        _sizeDelta: sizeDelta,
                        _targetPrice: targetPrice,
                        _conditionalOrderType: conditionalOrderType,
                        _desiredFillPrice: desiredFillPrice,
                        _reduceOnly: reduceOnly
                    });
                } else {
                    // Command.GELATO_CANCEL_CONDITIONAL_ORDER
                    uint256 orderId;
                    assembly {
                        orderId := calldataload(_inputs.offset)
                    }
                    _cancelConditionalOrder({_conditionalOrderId: orderId});
                }
            } else if (commandIndex > 15) {
                // commandIndex 14 & 15 valid and already checked
                revert InvalidCommandType(commandIndex);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        ACCOUNT DEPOSIT/WITHDRAW
    //////////////////////////////////////////////////////////////*/

    /// @notice allows ETH to be deposited directly into a margin account
    /// @notice ETH can be withdrawn
    receive() external payable {}

    /// @notice allow users to withdraw ETH deposited for keeper fees
    /// @param _amount: amount to withdraw
    function _withdrawEth(uint256 _amount) internal {
        if (_amount > 0) {
            (bool success,) = payable(msg.sender).call{value: _amount}("");
            if (!success) revert EthWithdrawalFailed();

            EVENTS.emitEthWithdraw({user: msg.sender, amount: _amount});
        }
    }

    /// @notice deposit/withdraw margin to/from this smart margin account
    /// @param _amount: amount of margin to deposit/withdraw
    function _modifyAccountMargin(int256 _amount) internal {
        // if amount is positive, deposit
        if (_amount > 0) {
            /// @dev failed Synthetix asset transfer will revert and not return false if unsuccessful
            MARGIN_ASSET.transferFrom(msg.sender, address(this), _abs(_amount));

            EVENTS.emitDeposit({user: msg.sender, amount: _abs(_amount)});
        } else if (_amount < 0) {
            // if amount is negative, withdraw
            _sufficientMargin(_amount);

            /// @dev failed Synthetix asset transfer will revert and not return false if unsuccessful
            MARGIN_ASSET.transfer(msg.sender, _abs(_amount));

            EVENTS.emitWithdraw({user: msg.sender, amount: _abs(_amount)});
        }
    }

    /*//////////////////////////////////////////////////////////////
                          MODIFY MARKET MARGIN
    //////////////////////////////////////////////////////////////*/

    /// @notice deposit/withdraw margin to/from a Synthetix PerpsV2 Market
    /// @param _market: address of market
    /// @param _amount: amount of margin to deposit/withdraw
    function _perpsV2ModifyMargin(address _market, int256 _amount) internal {
        if (_amount > 0) {
            _sufficientMargin(_amount);
        }
        IPerpsV2MarketConsolidated(_market).transferMargin(_amount);
    }

    /// @notice withdraw margin from market back to this account
    /// @dev this will *not* fail if market has zero margin
    function _perpsV2WithdrawAllMargin(address _market) internal {
        IPerpsV2MarketConsolidated(_market).withdrawAllMargin();
    }

    /*//////////////////////////////////////////////////////////////
                             ATOMIC ORDERS
    //////////////////////////////////////////////////////////////*/

    /// @notice submit an atomic order to a Synthetix PerpsV2 Market
    /// @dev atomic orders are executed immediately and incur a *significant* fee
    /// @param _market: address of market
    /// @param _sizeDelta: size delta of order
    /// @param _desiredFillPrice: desired fill price of order
    function _perpsV2SubmitAtomicOrder(
        address _market,
        int256 _sizeDelta,
        uint256 _desiredFillPrice
    ) internal {
        IPerpsV2MarketConsolidated(_market).modifyPositionWithTracking({
            sizeDelta: _sizeDelta,
            desiredFillPrice: _desiredFillPrice,
            trackingCode: TRACKING_CODE
        });
    }

    /// @notice close Synthetix PerpsV2 Market position via an atomic order
    /// @param _market: address of market
    /// @param _desiredFillPrice: desired fill price of order
    function _perpsV2ClosePosition(address _market, uint256 _desiredFillPrice)
        internal
    {
        // close position (i.e. reduce size to zero)
        /// @dev this does not remove margin from market
        IPerpsV2MarketConsolidated(_market).closePositionWithTracking({
            desiredFillPrice: _desiredFillPrice,
            trackingCode: TRACKING_CODE
        });
    }

    /*//////////////////////////////////////////////////////////////
                             DELAYED ORDERS
    //////////////////////////////////////////////////////////////*/

    /// @notice submit a delayed order to a Synthetix PerpsV2 Market
    /// @param _market: address of market
    /// @param _sizeDelta: size delta of order
    /// @param _desiredTimeDelta: desired time delta of order
    /// @param _desiredFillPrice: desired fill price of order
    function _perpsV2SubmitDelayedOrder(
        address _market,
        int256 _sizeDelta,
        uint256 _desiredTimeDelta,
        uint256 _desiredFillPrice
    ) internal {
        IPerpsV2MarketConsolidated(_market).submitDelayedOrderWithTracking({
            sizeDelta: _sizeDelta,
            desiredTimeDelta: _desiredTimeDelta,
            desiredFillPrice: _desiredFillPrice,
            trackingCode: TRACKING_CODE
        });
    }

    /// @notice cancel a *pending* delayed order from a Synthetix PerpsV2 Market
    /// @dev will revert if no previous delayed order
    function _perpsV2CancelDelayedOrder(address _market) internal {
        IPerpsV2MarketConsolidated(_market).cancelDelayedOrder(address(this));
    }

    /// @notice close Synthetix PerpsV2 Market position via a delayed order
    /// @param _market: address of market
    /// @param _desiredTimeDelta: desired time delta of order
    /// @param _desiredFillPrice: desired fill price of order
    function _perpsV2SubmitCloseDelayedOrder(
        address _market,
        uint256 _desiredTimeDelta,
        uint256 _desiredFillPrice
    ) internal {
        // close position (i.e. reduce size to zero)
        /// @dev this does not remove margin from market
        IPerpsV2MarketConsolidated(_market).submitCloseDelayedOrderWithTracking({
            desiredTimeDelta: _desiredTimeDelta,
            desiredFillPrice: _desiredFillPrice,
            trackingCode: TRACKING_CODE
        });
    }

    /*//////////////////////////////////////////////////////////////
                        DELAYED OFF-CHAIN ORDERS
    //////////////////////////////////////////////////////////////*/

    /// @notice submit an off-chain delayed order to a Synthetix PerpsV2 Market
    /// @param _market: address of market
    /// @param _sizeDelta: size delta of order
    /// @param _desiredFillPrice: desired fill price of order
    function _perpsV2SubmitOffchainDelayedOrder(
        address _market,
        int256 _sizeDelta,
        uint256 _desiredFillPrice
    ) internal {
        IPerpsV2MarketConsolidated(_market)
            .submitOffchainDelayedOrderWithTracking({
            sizeDelta: _sizeDelta,
            desiredFillPrice: _desiredFillPrice,
            trackingCode: TRACKING_CODE
        });
    }

    /// @notice cancel a *pending* off-chain delayed order from a Synthetix PerpsV2 Market
    /// @dev will revert if no previous offchain delayed order
    function _perpsV2CancelOffchainDelayedOrder(address _market) internal {
        IPerpsV2MarketConsolidated(_market).cancelOffchainDelayedOrder(
            address(this)
        );
    }

    /// @notice close Synthetix PerpsV2 Market position via an offchain delayed order
    /// @param _market: address of market
    /// @param _desiredFillPrice: desired fill price of order
    function _perpsV2SubmitCloseOffchainDelayedOrder(
        address _market,
        uint256 _desiredFillPrice
    ) internal {
        // close position (i.e. reduce size to zero)
        /// @dev this does not remove margin from market
        IPerpsV2MarketConsolidated(_market)
            .submitCloseOffchainDelayedOrderWithTracking({
            desiredFillPrice: _desiredFillPrice,
            trackingCode: TRACKING_CODE
        });
    }

    /*//////////////////////////////////////////////////////////////
                        CREATE CONDITIONAL ORDER
    //////////////////////////////////////////////////////////////*/

    /// @notice register a conditional order internally and with gelato
    /// @dev restricts _sizeDelta to be non-zero otherwise no need for conditional order
    /// @param _marketKey: Synthetix futures market id/key
    /// @param _marginDelta: amount of margin (in sUSD) to deposit or withdraw
    /// @param _sizeDelta: denominated in market currency (i.e. ETH, BTC, etc), size of position
    /// @param _targetPrice: expected conditional order price
    /// @param _conditionalOrderType: expected conditional order type enum where 0 = LIMIT, 1 = STOP, etc..
    /// @param _desiredFillPrice: desired price to fill Synthetix PerpsV2 order at execution time
    /// @param _reduceOnly: if true, only allows position's absolute size to decrease
    function _placeConditionalOrder(
        bytes32 _marketKey,
        int256 _marginDelta,
        int256 _sizeDelta,
        uint256 _targetPrice,
        ConditionalOrderTypes _conditionalOrderType,
        uint256 _desiredFillPrice,
        bool _reduceOnly
    ) internal {
        if (_sizeDelta == 0) revert ZeroSizeDelta();

        // if more margin is desired on the position we must commit the margin
        if (_marginDelta > 0) {
            _sufficientMargin(_marginDelta);
            committedMargin += _abs(_marginDelta);
        }

        // create and submit Gelato task for this conditional order
        bytes32 taskId = _createGelatoTask();

        // internally store the conditional order
        conditionalOrders[conditionalOrderId] = ConditionalOrder({
            marketKey: _marketKey,
            marginDelta: _marginDelta,
            sizeDelta: _sizeDelta,
            targetPrice: _targetPrice,
            gelatoTaskId: taskId,
            conditionalOrderType: _conditionalOrderType,
            desiredFillPrice: _desiredFillPrice,
            reduceOnly: _reduceOnly
        });

        EVENTS.emitConditionalOrderPlaced({
            conditionalOrderId: conditionalOrderId,
            gelatoTaskId: taskId,
            marketKey: _marketKey,
            marginDelta: _marginDelta,
            sizeDelta: _sizeDelta,
            targetPrice: _targetPrice,
            conditionalOrderType: _conditionalOrderType,
            desiredFillPrice: _desiredFillPrice,
            reduceOnly: _reduceOnly
        });

        ++conditionalOrderId;
    }

    /// @notice create a new Gelato task for a conditional order
    /// @return taskId of the new Gelato task
    function _createGelatoTask() internal returns (bytes32 taskId) {
        IOps.ModuleData memory moduleData = _createGelatoModuleData();

        taskId = IOps(OPS).createTask({
            execAddress: address(this),
            execData: abi.encodeCall(
                this.executeConditionalOrder, conditionalOrderId
                ),
            moduleData: moduleData,
            feeToken: ETH
        });
    }

    /// @notice create the Gelato ModuleData for a conditional order
    /// @dev see IOps for details on the task creation and the ModuleData struct
    function _createGelatoModuleData()
        internal
        view
        returns (IOps.ModuleData memory moduleData)
    {
        moduleData = IOps.ModuleData({
            modules: new IOps.Module[](1),
            args: new bytes[](1)
        });

        moduleData.modules[0] = IOps.Module.RESOLVER;
        moduleData.args[0] = abi.encode(
            address(this), abi.encodeCall(this.checker, conditionalOrderId)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        CANCEL CONDITIONAL ORDER
    //////////////////////////////////////////////////////////////*/

    /// @notice cancel a gelato queued conditional order
    /// @param _conditionalOrderId: key for an active conditional order
    function _cancelConditionalOrder(uint256 _conditionalOrderId) internal {
        ConditionalOrder memory conditionalOrder =
            getConditionalOrder(_conditionalOrderId);

        // if margin was committed, free it
        if (conditionalOrder.marginDelta > 0) {
            committedMargin -= _abs(conditionalOrder.marginDelta);
        }

        // cancel gelato task
        /// @dev will revert if task id does not exist {Automate.cancelTask: Task not found}
        IOps(OPS).cancelTask({taskId: conditionalOrder.gelatoTaskId});

        // delete order from conditional orders
        delete conditionalOrders[_conditionalOrderId];

        EVENTS.emitConditionalOrderCancelled({
            conditionalOrderId: _conditionalOrderId,
            gelatoTaskId: conditionalOrder.gelatoTaskId,
            reason: ConditionalOrderCancelledReason
                .CONDITIONAL_ORDER_CANCELLED_BY_USER
        });
    }

    /*//////////////////////////////////////////////////////////////
                       EXECUTE CONDITIONAL ORDER
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAccount
    function executeConditionalOrder(uint256 _conditionalOrderId)
        external
        override
        nonReentrant
        isAccountExecutionEnabled
    {
        // verify conditional order is ready for execution
        /// @dev it is understood this is a duplicate check if the executor is Gelato
        if (!_validConditionalOrder(_conditionalOrderId)) {
            revert CannotExecuteConditionalOrder({
                conditionalOrderId: _conditionalOrderId,
                executor: msg.sender
            });
        }

        // store conditional order object in memory
        ConditionalOrder memory conditionalOrder =
            getConditionalOrder(_conditionalOrderId);

        // remove conditional order from internal accounting
        delete conditionalOrders[_conditionalOrderId];

        // remove gelato task from their accounting
        /// @dev will revert if task id does not exist {Automate.cancelTask: Task not found}
        /// @dev if executor is not Gelato, the task will still be cancelled
        IOps(OPS).cancelTask({taskId: conditionalOrder.gelatoTaskId});

        // impose and record fee paid to executor
        uint256 fee = _payExecutorFee();

        // define Synthetix PerpsV2 market
        IPerpsV2MarketConsolidated market =
            _getPerpsV2Market(conditionalOrder.marketKey);

        /// @dev conditional order is valid given checker() returns true; define fill price
        (uint256 fillPrice, PriceOracleUsed priceOracle) = _sUSDRate(market);

        // if conditional order is reduce only, ensure position size is only reduced
        if (conditionalOrder.reduceOnly) {
            int256 currentSize = market.positions({account: address(this)}).size;

            // ensure position exists and incoming size delta is NOT the same sign
            /// @dev if incoming size delta is the same sign, then the conditional order is not reduce only
            if (
                currentSize == 0
                    || _isSameSign(currentSize, conditionalOrder.sizeDelta)
            ) {
                EVENTS.emitConditionalOrderCancelled({
                    conditionalOrderId: _conditionalOrderId,
                    gelatoTaskId: conditionalOrder.gelatoTaskId,
                    reason: ConditionalOrderCancelledReason
                        .CONDITIONAL_ORDER_CANCELLED_NOT_REDUCE_ONLY
                });

                return;
            }

            // ensure incoming size delta is not larger than current position size
            /// @dev reduce only conditional orders can only reduce position size (i.e. approach size of zero) and
            /// cannot cross that boundary (i.e. short -> long or long -> short)
            if (_abs(conditionalOrder.sizeDelta) > _abs(currentSize)) {
                // bound conditional order size delta to current position size
                conditionalOrder.sizeDelta = -currentSize;
            }
        }

        // if margin was committed, free it
        if (conditionalOrder.marginDelta > 0) {
            committedMargin -= _abs(conditionalOrder.marginDelta);
        }

        // execute trade
        _perpsV2ModifyMargin({
            _market: address(market),
            _amount: conditionalOrder.marginDelta
        });

        _perpsV2SubmitOffchainDelayedOrder({
            _market: address(market),
            _sizeDelta: conditionalOrder.sizeDelta,
            _desiredFillPrice: conditionalOrder.desiredFillPrice
        });

        EVENTS.emitConditionalOrderFilled({
            conditionalOrderId: _conditionalOrderId,
            gelatoTaskId: conditionalOrder.gelatoTaskId,
            fillPrice: fillPrice,
            keeperFee: fee,
            priceOracle: priceOracle
        });
    }

    /// @notice pay fee for conditional order execution
    /// @dev fee will be different depending on executor
    /// @return fee amount paid
    function _payExecutorFee() internal returns (uint256 fee) {
        if (msg.sender == OPS) {
            (fee,) = IOps(OPS).getFeeDetails();
            _transfer({_amount: fee});
        } else {
            fee = SETTINGS.executorFee();
            (bool success,) = msg.sender.call{value: fee}("");
            if (!success) revert CannotPayExecutorFee(fee, msg.sender);
        }
    }

    /// @notice order logic condition checker
    /// @dev this is where order type logic checks are handled
    /// @param _conditionalOrderId: key for an active order
    /// @return true if conditional order is valid by execution rules
    function _validConditionalOrder(uint256 _conditionalOrderId)
        internal
        view
        returns (bool)
    {
        ConditionalOrder memory conditionalOrder =
            getConditionalOrder(_conditionalOrderId);

        /// @dev return false early if market key is the default value (i.e. "")
        if (conditionalOrder.marketKey == bytes32(0)) {
            return false;
        }

        // return false if market is paused
        try SYSTEM_STATUS.requireFuturesMarketActive(conditionalOrder.marketKey)
        {} catch {
            return false;
        }

        /// @dev if marketKey is invalid, this will revert
        (uint256 price,) =
            _sUSDRate(_getPerpsV2Market(conditionalOrder.marketKey));

        // check if markets satisfy specific order type
        if (
            conditionalOrder.conditionalOrderType == ConditionalOrderTypes.LIMIT
        ) {
            return _validLimitOrder(conditionalOrder, price);
        } else if (
            conditionalOrder.conditionalOrderType == ConditionalOrderTypes.STOP
        ) {
            return _validStopOrder(conditionalOrder, price);
        }

        // unknown order type
        return false;
    }

    /// @notice limit order logic condition checker
    /// @dev sizeDelta will never be zero due to check when submitting conditional order
    /// @param _conditionalOrder: struct for an active conditional order
    /// @param _price: current price of market asset
    /// @return true if conditional order is valid by execution rules
    function _validLimitOrder(
        ConditionalOrder memory _conditionalOrder,
        uint256 _price
    ) internal pure returns (bool) {
        if (_conditionalOrder.sizeDelta > 0) {
            // Long: increase position size (buy) once *below* target price
            // ex: open long position once price is below target
            return _price <= _conditionalOrder.targetPrice;
        } else {
            // Short: decrease position size (sell) once *above* target price
            // ex: open short position once price is above target
            return _price >= _conditionalOrder.targetPrice;
        }
    }

    /// @notice stop order logic condition checker
    /// @dev sizeDelta will never be zero due to check when submitting order
    /// @param _conditionalOrder: struct for an active conditional order
    /// @param _price: current price of market asset
    /// @return true if conditional order is valid by execution rules
    function _validStopOrder(
        ConditionalOrder memory _conditionalOrder,
        uint256 _price
    ) internal pure returns (bool) {
        if (_conditionalOrder.sizeDelta > 0) {
            // Long: increase position size (buy) once *above* target price
            // ex: unwind short position once price is above target (prevent further loss)
            return _price >= _conditionalOrder.targetPrice;
        } else {
            // Short: decrease position size (sell) once *below* target price
            // ex: unwind long position once price is below target (prevent further loss)
            return _price <= _conditionalOrder.targetPrice;
        }
    }

    /*//////////////////////////////////////////////////////////////
                                UNISWAP
    //////////////////////////////////////////////////////////////*/

    /// @notice swap tokens via Uniswap V3 (sUSD <-> whitelisted token)
    /// @dev assumes sufficient token allowances (i.e. Permit2 and this contract)
    /// @dev non-whitelisted connector tokens will NOT cause a revert
    /// (i.e. sUSD -> non-whitelisted token -> whitelisted token)
    /// @param _amountIn: amount of token to swap
    /// @param _amountOutMin: minimum amount of token to receive
    /// @param _path: path of tokens to swap (token0 - fee - token1)
    function _uniswapV3Swap(
        uint256 _amountIn,
        uint256 _amountOutMin,
        bytes calldata _path
    ) internal {
        // decode tokens to swap
        (address tokenIn, address tokenOut) = _getTokenInTokenOut(_path);

        // define recipient of swap; set later once direction is established
        address recipient;

        /// @dev verify direction and validity of swap (i.e. sUSD <-> whitelisted token)
        if (
            tokenIn == address(MARGIN_ASSET)
                && SETTINGS.isTokenWhitelisted(tokenOut)
        ) {
            // if swapping sUSD for another token, ensure sufficient margin
            /// @dev margin is being transferred out of this contract
            _sufficientMargin(int256(_amountIn));

            recipient = msg.sender;

            // transfer sUSD to the UniversalRouter for the swap
            /// @dev not using SafeERC20 because sUSD is a trusted token
            IERC20(tokenIn).transfer(
                address(UNISWAP_UNIVERSAL_ROUTER), _amountIn
            );
        } else if (
            tokenOut == address(MARGIN_ASSET)
                && SETTINGS.isTokenWhitelisted(tokenIn)
        ) {
            // if swapping another token for sUSD, incoming token must be transferred to the UniversalRouter
            /// @dev msg.sender must have approved Permit2 to spend at least the amountIn
            PERMIT2.transferFrom({
                from: msg.sender,
                to: address(UNISWAP_UNIVERSAL_ROUTER),
                amount: _amountIn.toUint160(),
                token: tokenIn
            });

            recipient = address(this);
        } else {
            // only allow sUSD <-> whitelisted token swaps
            revert TokenSwapNotAllowed(tokenIn, tokenOut);
        }

        _universalRouterExecute(recipient, _amountIn, _amountOutMin, _path);

        EVENTS.emitUniswapV3Swap({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            recipient: recipient,
            amountIn: _amountIn,
            amountOutMinimum: _amountOutMin
        });
    }

    /// @notice decode and return tokens encoded in the provided path
    /// @param _path: path of tokens to swap (token0 - fee - token1)
    /// @return tokenIn token swapped into the respective pool
    /// @return tokenOut token swapped out of the respective pool
    function _getTokenInTokenOut(bytes calldata _path)
        internal
        pure
        returns (address tokenIn, address tokenOut)
    {
        tokenIn = _path.decodeFirstToken();
        while (true) {
            bool hasMultiplePools = _path.hasMultiplePools();

            // decide whether to continue or terminate
            if (hasMultiplePools) {
                _path = _path.skipToken();
            } else {
                (,, tokenOut) = _path.toPool();
                break;
            }
        }
    }

    /// @notice call Uniswap's Universal Router to execute a swap
    /// @param _recipient: address to receive swapped tokens
    /// @param _amountIn: amount of token to swap
    /// @param _amountOutMin: minimum amount of token to receive
    /// @param _path: path of tokens to swap (token0 - fee - token1)
    function _universalRouterExecute(
        address _recipient,
        uint256 _amountIn,
        uint256 _amountOutMin,
        bytes calldata _path
    ) internal {
        /// @dev payerIsUser (i.e. 5th argument encoded) will always be false because
        /// tokens are transferred to the UniversalRouter before executing the swap
        bytes[] memory inputs = new bytes[](1);
        inputs[0] =
            abi.encode(_recipient, _amountIn, _amountOutMin, _path, false);

        UNISWAP_UNIVERSAL_ROUTER.execute({
            commands: abi.encodePacked(bytes1(uint8(V3_SWAP_EXACT_IN))),
            inputs: inputs
        });
    }

    /*//////////////////////////////////////////////////////////////
                            MARGIN UTILITIES
    //////////////////////////////////////////////////////////////*/

    /// @notice check that margin attempted to be moved/locked is within free margin bounds
    /// @param _marginOut: amount of margin to be moved/locked
    function _sufficientMargin(int256 _marginOut) internal view {
        if (_abs(_marginOut) > freeMargin()) {
            revert InsufficientFreeMargin(freeMargin(), _abs(_marginOut));
        }
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER UTILITIES
    //////////////////////////////////////////////////////////////*/

    /// @notice fetch PerpsV2Market market defined by market key
    /// @param _marketKey: key for Synthetix PerpsV2 market
    /// @return IPerpsV2MarketConsolidated contract interface
    function _getPerpsV2Market(bytes32 _marketKey)
        internal
        view
        returns (IPerpsV2MarketConsolidated)
    {
        return IPerpsV2MarketConsolidated(
            FUTURES_MARKET_MANAGER.marketForKey(_marketKey)
        );
    }

    /// @notice get exchange rate of underlying market asset in terms of sUSD
    /// @param _market: Synthetix PerpsV2 Market
    /// @return price in sUSD
    function _sUSDRate(IPerpsV2MarketConsolidated _market)
        internal
        view
        returns (uint256, PriceOracleUsed)
    {
        /// @dev will revert if market is invalid
        bytes32 assetId = _market.baseAsset();

        /// @dev can revert if assetId is invalid OR there's no price for the given asset
        (uint256 price, uint256 publishTime) =
            PERPS_V2_EXCHANGE_RATE.resolveAndGetLatestPrice(assetId);

        // resolveAndGetLatestPrice is provide by pyth
        PriceOracleUsed priceOracle = PriceOracleUsed.PYTH;

        // if the price is stale, get the latest price from the market
        // (i.e. Chainlink provided price)
        if (publishTime < block.timestamp - MAX_PRICE_LATENCY) {
            // set price oracle used to Chainlink
            priceOracle = PriceOracleUsed.CHAINLINK;

            // fetch asset price and ensure it is valid
            bool invalid;
            (price, invalid) = _market.assetPrice();
            if (invalid) revert InvalidPrice();
        }

        /// @dev see IPerpsV2ExchangeRates to understand risks associated with this price
        return (price, priceOracle);
    }

    /*//////////////////////////////////////////////////////////////
                             MATH UTILITIES
    //////////////////////////////////////////////////////////////*/

    /// @notice get absolute value of the input, returned as an unsigned number.
    /// @param x: signed number
    /// @return z uint256 absolute value of x
    function _abs(int256 x) internal pure returns (uint256 z) {
        assembly {
            let mask := sub(0, shr(255, x))
            z := xor(mask, add(mask, x))
        }
    }

    /// @notice determines if input numbers have the same sign
    /// @dev asserts that both numbers are not zero
    /// @param x: signed number
    /// @param y: signed number
    /// @return true if same sign, false otherwise
    function _isSameSign(int256 x, int256 y) internal pure returns (bool) {
        assert(x != 0 && y != 0);
        return (x ^ y) >= 0;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

/// @notice Authorization mixin for Smart Margin Accounts
/// @author JaredBorders ([email protected])
/// @dev This contract is intended to be inherited by the Account contract
abstract contract Auth {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice owner of the account
    address public owner;

    /// @notice mapping of delegate address
    mapping(address delegate => bool) public delegates;

    /// @dev reserved storage space for future contract upgrades
    /// @custom:caution reduce storage size when adding new storage variables
    uint256[19] private __gap;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice thrown when an unauthorized caller attempts
    /// to access a caller restricted function
    error Unauthorized();

    /// @notice thrown when the delegate address is invalid
    /// @param delegateAddress: address of the delegate attempting to be added
    error InvalidDelegateAddress(address delegateAddress);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted after ownership transfer
    /// @param caller: previous owner
    /// @param newOwner: new owner
    event OwnershipTransferred(
        address indexed caller, address indexed newOwner
    );

    /// @notice emitted after a delegate is added
    /// @param caller: owner of the account
    /// @param delegate: address of the delegate being added
    event DelegatedAccountAdded(
        address indexed caller, address indexed delegate
    );

    /// @notice emitted after a delegate is removed
    /// @param caller: owner of the account
    /// @param delegate: address of the delegate being removed
    event DelegatedAccountRemoved(
        address indexed caller, address indexed delegate
    );

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @dev sets owner to _owner and not msg.sender
    /// @param _owner The address of the owner
    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @return true if the caller is the owner
    function isOwner() public view virtual returns (bool) {
        return (msg.sender == owner);
    }

    /// @return true if the caller is the owner or a delegate
    function isAuth() public view virtual returns (bool) {
        return (msg.sender == owner || delegates[msg.sender]);
    }

    /*//////////////////////////////////////////////////////////////
                                SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer ownership of the account
    /// @dev only owner can transfer ownership (not delegates)
    /// @param _newOwner The address of the new owner
    function transferOwnership(address _newOwner) public virtual {
        if (!isOwner()) revert Unauthorized();

        owner = _newOwner;

        emit OwnershipTransferred(msg.sender, _newOwner);
    }

    /// @notice Add a delegate to the account
    /// @dev only owner can add a delegate (not delegates)
    /// @param _delegate The address of the delegate
    function addDelegate(address _delegate) public virtual {
        if (!isOwner()) revert Unauthorized();

        if (_delegate == address(0) || delegates[_delegate]) {
            revert InvalidDelegateAddress(_delegate);
        }

        delegates[_delegate] = true;

        emit DelegatedAccountAdded({caller: msg.sender, delegate: _delegate});
    }

    /// @notice Remove a delegate from the account
    /// @dev only owner can remove a delegate (not delegates)
    /// @param _delegate The address of the delegate
    function removeDelegate(address _delegate) public virtual {
        if (!isOwner()) revert Unauthorized();

        if (_delegate == address(0) || !delegates[_delegate]) {
            revert InvalidDelegateAddress(_delegate);
        }

        delete delegates[_delegate];

        emit DelegatedAccountRemoved({caller: msg.sender, delegate: _delegate});
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import {Constants} from "src/utils/uniswap/Constants.sol";

library BytesLib {
    error SliceOutOfBounds();

    /// @notice Returns the address starting at byte 0
    /// @dev length and overflow checks must be carried out before calling
    /// @param _bytes The input bytes string to slice
    /// @return _address The address starting at byte 0
    function toAddress(bytes calldata _bytes)
        internal
        pure
        returns (address _address)
    {
        if (_bytes.length < Constants.ADDR_SIZE) revert SliceOutOfBounds();
        assembly {
            _address := shr(96, calldataload(_bytes.offset))
        }
    }

    /// @notice Returns the pool details starting at byte 0
    /// @dev length and overflow checks must be carried out before calling
    /// @param _bytes The input bytes string to slice
    /// @return token0 The address at byte 0
    /// @return fee The uint24 starting at byte 20
    /// @return token1 The address at byte 23
    function toPool(bytes calldata _bytes)
        internal
        pure
        returns (address token0, uint24 fee, address token1)
    {
        if (_bytes.length < Constants.V3_POP_OFFSET) revert SliceOutOfBounds();
        assembly {
            let firstWord := calldataload(_bytes.offset)
            token0 := shr(96, firstWord)
            fee := and(shr(72, firstWord), 0xffffff)
            token1 := shr(96, calldataload(add(_bytes.offset, 23)))
        }
    }

    /// @notice Decode the `_arg`-th element in `_bytes` as a dynamic array
    /// @dev The decoding of `length` and `offset` is universal,
    /// whereas the type declaration of `res` instructs the compiler how to read it.
    /// @param _bytes The input bytes string to slice
    /// @param _arg The index of the argument to extract
    /// @return length Length of the array
    /// @return offset Pointer to the data part of the array
    function toLengthOffset(bytes calldata _bytes, uint256 _arg)
        internal
        pure
        returns (uint256 length, uint256 offset)
    {
        uint256 relativeOffset;
        assembly {
            // The offset of the `_arg`-th element is `32 * arg`, which stores the offset of the length pointer.
            // shl(5, x) is equivalent to mul(32, x)
            let lengthPtr :=
                add(_bytes.offset, calldataload(add(_bytes.offset, shl(5, _arg))))
            length := calldataload(lengthPtr)
            offset := add(lengthPtr, 0x20)
            relativeOffset := sub(offset, _bytes.offset)
        }
        if (_bytes.length < length + relativeOffset) revert SliceOutOfBounds();
    }

    /// @notice Decode the `_arg`-th element in `_bytes` as `bytes`
    /// @param _bytes The input bytes string to extract a bytes string from
    /// @param _arg The index of the argument to extract
    function toBytes(bytes calldata _bytes, uint256 _arg)
        internal
        pure
        returns (bytes calldata res)
    {
        (uint256 length, uint256 offset) = toLengthOffset(_bytes, _arg);
        assembly {
            res.length := length
            res.offset := offset
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import {IPerpsV2MarketConsolidated} from
    "src/interfaces/synthetix/IPerpsV2MarketConsolidated.sol";

/// @title Kwenta Smart Margin Account v2.1.0 Implementation Interface
/// @author JaredBorders ([email protected]), JChiaramonte7 ([email protected])
interface IAccount {
    /*///////////////////////////////////////////////////////////////
                                Types
    ///////////////////////////////////////////////////////////////*/

    /// @notice Command Flags used to decode commands to execute
    /// @dev under the hood ACCOUNT_MODIFY_MARGIN = 0, ACCOUNT_WITHDRAW_ETH = 1
    enum Command {
        ACCOUNT_MODIFY_MARGIN, // 0
        ACCOUNT_WITHDRAW_ETH,
        PERPS_V2_MODIFY_MARGIN,
        PERPS_V2_WITHDRAW_ALL_MARGIN,
        PERPS_V2_SUBMIT_ATOMIC_ORDER,
        PERPS_V2_SUBMIT_DELAYED_ORDER, // 5
        PERPS_V2_SUBMIT_OFFCHAIN_DELAYED_ORDER,
        PERPS_V2_CLOSE_POSITION,
        PERPS_V2_SUBMIT_CLOSE_DELAYED_ORDER,
        PERPS_V2_SUBMIT_CLOSE_OFFCHAIN_DELAYED_ORDER,
        PERPS_V2_CANCEL_DELAYED_ORDER, // 10
        PERPS_V2_CANCEL_OFFCHAIN_DELAYED_ORDER,
        GELATO_PLACE_CONDITIONAL_ORDER,
        GELATO_CANCEL_CONDITIONAL_ORDER,
        UNISWAP_V3_SWAP,
        PERMIT2_PERMIT // 15
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

    /// @notice denotes what oracle is used for price when executing conditional orders
    /// @dev under the hood PYTH = 0, CHAINLINK = 1
    enum PriceOracleUsed {
        PYTH,
        CHAINLINK
    }

    /// @param factory: address of the Smart Margin Account Factory
    /// @param events: address of the contract used by all accounts for emitting events
    /// @param marginAsset: address of the Synthetix ProxyERC20sUSD contract used as the margin asset
    /// @param perpsV2ExchangeRate: address of the Synthetix PerpsV2ExchangeRate
    /// @param futuresMarketManager: address of the Synthetix FuturesMarketManager
    /// @param systemStatus: address of the Synthetix SystemStatus
    /// @param gelato: address of Gelato
    /// @param ops: address of Ops
    /// @param settings: address of contract used to store global settings
    /// @param universalRouter: address of Uniswap's Universal Router
    /// @param permit2: address of Uniswap's Permit2
    struct AccountConstructorParams {
        address factory;
        address events;
        address marginAsset;
        address perpsV2ExchangeRate;
        address futuresMarketManager;
        address systemStatus;
        address gelato;
        address ops;
        address settings;
        address universalRouter;
        address permit2;
    }

    /// marketKey: Synthetix PerpsV2 Market id/key
    /// marginDelta: amount of margin to deposit or withdraw; positive indicates deposit, negative withdraw
    /// sizeDelta: denoted in market currency (i.e. ETH, BTC, etc), size of Synthetix PerpsV2 position
    /// targetPrice: limit or stop price target needing to be met to submit Synthetix PerpsV2 order
    /// gelatoTaskId: unqiue taskId from gelato necessary for cancelling conditional orders
    /// conditionalOrderType: conditional order type to determine conditional order fill logic
    /// desiredFillPrice: desired price to fill Synthetix PerpsV2 order at execution time
    /// reduceOnly: if true, only allows position's absolute size to decrease
    struct ConditionalOrder {
        bytes32 marketKey;
        int256 marginDelta;
        int256 sizeDelta;
        uint256 targetPrice;
        bytes32 gelatoTaskId;
        ConditionalOrderTypes conditionalOrderType;
        uint256 desiredFillPrice;
        bool reduceOnly;
    }
    /// @dev see example below elucidating targtPrice vs desiredFillPrice:
    /// 1. targetPrice met (ex: targetPrice = X)
    /// 2. account submits delayed order to Synthetix PerpsV2 with desiredFillPrice = Y
    /// 3. keeper executes Synthetix PerpsV2 order after delay period
    /// 4. if current market price defined by Synthetix PerpsV2
    ///    after delay period satisfies desiredFillPrice order is filled

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice thrown when commands length does not equal inputs length
    error LengthMismatch();

    /// @notice thrown when Command given is not valid
    error InvalidCommandType(uint256 commandType);

    /// @notice thrown when conditional order type given is not valid due to zero sizeDelta
    error ZeroSizeDelta();

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

    /// @notice thrown when account execution has been disabled in the settings contract
    error AccountExecutionDisabled();

    /// @notice thrown when a call attempts to reenter the protected function
    error Reentrancy();

    /// @notice thrown when token swap attempted with invalid token (i.e. token that is not whitelisted)
    /// @param tokenIn: token attempting to swap from
    /// @param tokenOut: token attempting to swap to
    error TokenSwapNotAllowed(address tokenIn, address tokenOut);

    /// @notice thrown when a conditional order is attempted to be executed during invalid market conditions
    /// @param conditionalOrderId: conditional order id
    /// @param executor: address of executor
    error CannotExecuteConditionalOrder(
        uint256 conditionalOrderId, address executor
    );

    /// @notice thrown when a conditional order is attempted to be executed but SM account cannot pay fee
    /// @param executorFee: fee required to execute conditional order
    error CannotPayExecutorFee(uint256 executorFee, address executor);

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice returns the version of the Account
    function VERSION() external view returns (bytes32);

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

    /// @notice sets the initial owner of the account
    /// @dev only called once by the factory on account creation
    /// @param _owner: address of the owner
    function setInitialOwnership(address _owner) external;

    /// @notice executes commands along with provided inputs
    /// @param _commands: array of commands, each represented as an enum
    /// @param _inputs: array of byte strings containing abi encoded inputs for each command
    function execute(Command[] calldata _commands, bytes[] calldata _inputs)
        external
        payable;

    /// @notice execute queued conditional order
    /// @dev currently only supports conditional order submission via PERPS_V2_SUBMIT_OFFCHAIN_DELAYED_ORDER COMMAND
    /// @param _conditionalOrderId: key for an active conditional order
    function executeConditionalOrder(uint256 _conditionalOrderId) external;
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
    /// @param version: version of account created
    event NewAccount(
        address indexed creator, address indexed account, bytes32 version
    );

    /// @notice emitted when implementation is upgraded
    /// @param implementation: address of new implementation
    event AccountImplementationUpgraded(address implementation);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice thrown when factory cannot set account owner to the msg.sender
    /// @param data: data returned from failed low-level call
    error FailedToSetAcountOwner(bytes data);

    /// @notice thrown when Account creation fails due to no version being set
    /// @param data: data returned from failed low-level call
    error AccountFailedToFetchVersion(bytes data);

    /// @notice thrown when factory is not upgradable
    error CannotUpgrade();

    /// @notice thrown when account is unrecognized by factory
    error AccountDoesNotExist();

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @return canUpgrade: bool to determine if system can be upgraded
    function canUpgrade() external view returns (bool);

    /// @return logic: account logic address
    function implementation() external view returns (address);

    /// @param _account: address of account
    /// @return whether or not account exists
    function accounts(address _account) external view returns (bool);

    /// @param _account: address of account
    /// @return owner of account
    function getAccountOwner(address _account)
        external
        view
        returns (address);

    /// @param _owner: address of owner
    /// @return array of accounts owned by _owner
    function getAccountsOwnedBy(address _owner)
        external
        view
        returns (address[] memory);

    /*//////////////////////////////////////////////////////////////
                               OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    /// @notice update owner to account(s) mapping
    /// @dev does *NOT* check new owner != old owner
    /// @param _newOwner: new owner of account
    /// @param _oldOwner: old owner of account
    function updateAccountOwnership(address _newOwner, address _oldOwner)
        external;

    /*//////////////////////////////////////////////////////////////
                           ACCOUNT DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice create unique account proxy for function caller
    /// @return accountAddress address of account created
    function newAccount() external returns (address payable accountAddress);

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

    /// @notice remove upgradability from factory
    /// @dev cannot be undone
    function removeUpgradability() external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

interface IFuturesMarketManager {
    function marketForKey(bytes32 marketKey) external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

interface IPermit2 {
    /// @notice The permit data for a token
    struct PermitDetails {
        // ERC20 token address
        address token;
        // the maximum amount allowed to spend
        uint160 amount;
        // timestamp at which a spender's token allowances become invalid
        uint48 expiration;
        // an incrementing value indexed per owner,token,and spender for each signature
        uint48 nonce;
    }

    /// @notice The permit message signed for a single token allownce
    struct PermitSingle {
        // the permit data for a single token alownce
        PermitDetails details;
        // address permissioned on the allowed tokens
        address spender;
        // deadline on the permit signature
        uint256 sigDeadline;
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @dev Should return whether the signature provided is valid for the provided data
    /// @param hash      Hash of the data to be signed
    /// @param signature Signature byte array associated with _data
    /// @return magicValue The bytes4 magic value 0x1626ba7e
    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        returns (bytes4 magicValue);

    /// @notice A mapping from owner address to token address to spender address to PackedAllowance struct, which contains details and conditions of the approval.
    /// @notice The mapping is indexed in the above order see: allowance[ownerAddress][tokenAddress][spenderAddress]
    /// @dev The packed slot holds the allowed amount, expiration at which the allowed amount is no longer valid, and current nonce thats updated on any signature based approvals.
    function allowance(address user, address token, address spender)
        external
        view
        returns (uint160 amount, uint48 expiration, uint48 nonce);

    /// @notice Approves the spender to use up to amount of the specified token up until the expiration
    /// @param token The token to approve
    /// @param spender The spender address to approve
    /// @param amount The approved amount of the token
    /// @param expiration The timestamp at which the approval is no longer valid
    /// @dev The packed allowance also holds a nonce, which will stay unchanged in approve
    /// @dev Setting amount to type(uint160).max sets an unlimited approval
    function approve(
        address token,
        address spender,
        uint160 amount,
        uint48 expiration
    ) external;

    /// @notice Permit a spender to a given amount of the owners token via the owner's EIP-712 signature
    /// @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce
    /// @param owner The owner of the tokens being approved
    /// @param permitSingle Data signed over by the owner specifying the terms of approval
    /// @param signature The owner's signature over the permit data
    function permit(
        address owner,
        PermitSingle memory permitSingle,
        bytes calldata signature
    ) external;

    /// @notice Transfer approved tokens from one address to another
    /// @param from The address to transfer from
    /// @param to The address of the recipient
    /// @param amount The amount of the token to transfer
    /// @param token The token address to transfer
    /// @dev Requires the from address to have approved at least the desired amount
    /// of tokens to msg.sender.
    function transferFrom(
        address from,
        address to,
        uint160 amount,
        address token
    ) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

/// @title Kwenta Smart Margin Account Settings Interface
/// @author JaredBorders ([email protected])
interface ISettings {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted when account execution is enabled or disabled
    /// @param enabled: true if account execution is enabled, false if disabled
    event AccountExecutionEnabledSet(bool enabled);

    /// @notice emitted when the executor fee is updated
    /// @param executorFee: the executor fee
    event ExecutorFeeSet(uint256 executorFee);

    /// @notice emitted when a token is added to or removed from the whitelist
    /// @param token: address of the token
    /// @param isWhitelisted: true if token is whitelisted, false if not
    event TokenWhitelistStatusUpdated(address token, bool isWhitelisted);

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice checks if account execution is enabled or disabled
    /// @return enabled: true if account execution is enabled, false if disabled
    function accountExecutionEnabled() external view returns (bool);

    /// @notice gets the conditional order executor fee
    /// @return executorFee: the executor fee
    function executorFee() external view returns (uint256);

    /// @notice checks if token is whitelisted
    /// @param _token: address of the token to check
    /// @return true if token is whitelisted, false if not
    function isTokenWhitelisted(address _token) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                                SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice enables or disables account execution
    /// @param _enabled: true if account execution is enabled, false if disabled
    function setAccountExecutionEnabled(bool _enabled) external;

    /// @notice sets the conditional order executor fee
    /// @param _executorFee: the executor fee
    function setExecutorFee(uint256 _executorFee) external;

    /// @notice adds/removes token to/from whitelist
    /// @dev does not check if token was previously whitelisted
    /// @param _token: address of the token to add
    /// @param _isWhitelisted: true if token is to be whitelisted, false if not
    function setTokenWhitelistStatus(address _token, bool _isWhitelisted)
        external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

interface ISystemStatus {
    function requireFuturesMarketActive(bytes32 marketKey) external view;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

interface IOps {
    /**
     * @notice Whitelisted modules that are available for users to customise conditions and specifications of their tasks.
     *
     * @param RESOLVER Use dynamic condition & input data for execution. {See ResolverModule.sol}
     * @param TIME Repeated execution of task at a specified timing and interval. {See TimeModule.sol}
     * @param PROXY Creates a dedicated caller (msg.sender) to be used when executing the task. {See ProxyModule.sol}
     * @param SINGLE_EXEC Task is cancelled after one execution. {See SingleExecModule.sol}
     */
    enum Module {
        RESOLVER,
        TIME,
        PROXY,
        SINGLE_EXEC
    }

    /**
     * @notice Struct to contain modules and their relative arguments that are used for task creation.
     *
     * @param modules List of selected modules.
     * @param args Arguments of modules if any. Pass "0x" for modules which does not require args {See encodeModuleArg}
     */
    struct ModuleData {
        Module[] modules;
        bytes[] args;
    }

    /**
     * @notice Struct for time module.
     *
     * @param nextExec Time when the next execution should occur.
     * @param interval Time interval between each execution.
     */
    struct Time {
        uint128 nextExec;
        uint128 interval;
    }

    /**
     * @notice Initiates a task with conditions which Gelato will monitor and execute when conditions are met.
     *
     * @param execAddress Address of contract that should be called by Gelato.
     * @param execData Execution data to be called with / function selector if execution data is yet to be determined.
     * @param moduleData Conditional modules that will be used.
     * @param feeToken Address of token to be used as payment. Use address(0) if TaskTreasury is being used, 0xeeeeee... for ETH or native tokens.
     *
     * @return taskId Unique hash of the task created.
     */
    function createTask(
        address execAddress,
        bytes calldata execData,
        ModuleData calldata moduleData,
        address feeToken
    ) external returns (bytes32 taskId);

    /**
     * @notice Terminates a task that was created and Gelato can no longer execute it.
     *
     * @param taskId Unique hash of the task that is being cancelled. {See LibTaskId-getTaskId}
     */
    function cancelTask(bytes32 taskId) external;

    /**
     * @notice Execution API called by Gelato.
     *
     * @param taskCreator The address which created the task.
     * @param execAddress Address of contract that should be called by Gelato.
     * @param execData Execution data to be called with / function selector if execution data is yet to be determined.
     * @param moduleData Conditional modules that will be used.
     * @param txFee Fee paid to Gelato for execution, deducted on the TaskTreasury or transfered to Gelato.
     * @param feeToken Token used to pay for the execution. ETH = 0xeeeeee...
     * @param useTaskTreasuryFunds If taskCreator's balance on TaskTreasury should pay for the tx.
     * @param revertOnFailure To revert or not if call to execAddress fails. (Used for off-chain simulations)
     */
    function exec(
        address taskCreator,
        address execAddress,
        bytes memory execData,
        ModuleData calldata moduleData,
        uint256 txFee,
        address feeToken,
        bool useTaskTreasuryFunds,
        bool revertOnFailure
    ) external;

    /**
     * @notice Sets the address of task modules. Only callable by proxy admin.
     *
     * @param modules List of modules to be set
     * @param moduleAddresses List of addresses for respective modules.
     */
    function setModule(
        Module[] calldata modules,
        address[] calldata moduleAddresses
    ) external;

    /**
     * @notice Helper function to query fee and feeToken to be used for payment. (For executions which pays itself)
     *
     * @return uint256 Fee amount to be paid.
     * @return address Token to be paid. (Determined and passed by taskCreator during createTask)
     */
    function getFeeDetails() external view returns (uint256, address);

    /**
     * @notice Helper func to query all open tasks by a task creator.
     *
     * @param taskCreator Address of task creator to query.
     *
     * @return bytes32[] List of taskIds created.
     */
    function getTaskIdsByUser(address taskCreator)
        external
        view
        returns (bytes32[] memory);

    /**
     * @notice Helper function to compute task id with module arguments
     *
     * @param taskCreator The address which created the task.
     * @param execAddress Address of contract that will be called by Gelato.
     * @param execSelector Signature of the function which will be called by Gelato.
     * @param moduleData  Conditional modules that will be used. {See LibDataTypes-ModuleData}
     * @param feeToken Address of token to be used as payment. Use address(0) if TaskTreasury is being used, 0xeeeeee... for ETH or native tokens.
     */
    function getTaskId(
        address taskCreator,
        address execAddress,
        bytes4 execSelector,
        ModuleData memory moduleData,
        address feeToken
    ) external pure returns (bytes32 taskId);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

interface IUniversalRouter {
    /// @notice Executes encoded commands along with provided inputs. Reverts if deadline has expired.
    /// @param commands A set of concatenated commands, each 1 byte in length
    /// @param inputs An array of byte strings containing abi encoded inputs for each command
    /// @param deadline The deadline by which the transaction must be executed
    function execute(
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 deadline
    ) external payable;

    /// @notice Executes encoded commands along with provided inputs
    /// @param commands A set of concatenated commands, each 1 byte in length
    /// @param inputs An array of byte strings containing abi encoded inputs for each command
    function execute(bytes calldata commands, bytes[] calldata inputs)
        external
        payable;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import {IAccount} from "./IAccount.sol";

/// @title Interface for contract that emits all events emitted by the Smart Margin Accounts
/// @author JaredBorders ([email protected])
interface IEvents {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted when a non-account contract attempts to call a restricted function
    error OnlyAccounts();

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice returns the address of the factory contract
    function factory() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted after a successful withdrawal
    /// @param user: the address that withdrew from account
    /// @param amount: amount of marginAsset to withdraw from account
    function emitDeposit(address user, uint256 amount) external;

    event Deposit(
        address indexed user, address indexed account, uint256 amount
    );

    /// @notice emitted after a successful withdrawal
    /// @param user: the address that withdrew from account
    /// @param amount: amount of marginAsset to withdraw from account
    function emitWithdraw(address user, uint256 amount) external;

    event Withdraw(
        address indexed user, address indexed account, uint256 amount
    );

    /// @notice emitted after a successful ETH withdrawal
    /// @param user: the address that withdrew from account
    /// @param amount: amount of ETH to withdraw from account
    function emitEthWithdraw(address user, uint256 amount) external;

    event EthWithdraw(
        address indexed user, address indexed account, uint256 amount
    );

    /// @notice emitted after a successful token swap
    /// @param tokenIn: contract address of the inbound token
    /// @param tokenOut: contract address of the outbound token
    /// @param recipient: address to receive the outbound token
    /// @param amountIn: amount of inbound token to swap
    /// @param amountOutMinimum: minimum amount of outbound token to receive
    function emitUniswapV3Swap(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external;

    event UniswapV3Swap(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum
    );

    /// @notice emitted when a conditional order is placed
    /// @param conditionalOrderId: id of conditional order
    /// @param gelatoTaskId: id of gelato task
    /// @param marketKey: Synthetix PerpsV2 market key
    /// @param marginDelta: margin change
    /// @param sizeDelta: size change
    /// @param targetPrice: targeted fill price
    /// @param conditionalOrderType: expected conditional order type enum where 0 = LIMIT, 1 = STOP, etc..
    /// @param desiredFillPrice: desired price to fill Synthetix PerpsV2 order at execution time
    /// @param reduceOnly: if true, only allows position's absolute size to decrease
    function emitConditionalOrderPlaced(
        uint256 conditionalOrderId,
        bytes32 gelatoTaskId,
        bytes32 marketKey,
        int256 marginDelta,
        int256 sizeDelta,
        uint256 targetPrice,
        IAccount.ConditionalOrderTypes conditionalOrderType,
        uint256 desiredFillPrice,
        bool reduceOnly
    ) external;

    event ConditionalOrderPlaced(
        address indexed account,
        uint256 indexed conditionalOrderId,
        bytes32 indexed gelatoTaskId,
        bytes32 marketKey,
        int256 marginDelta,
        int256 sizeDelta,
        uint256 targetPrice,
        IAccount.ConditionalOrderTypes conditionalOrderType,
        uint256 desiredFillPrice,
        bool reduceOnly
    );

    /// @notice emitted when a conditional order is cancelled
    /// @param conditionalOrderId: id of conditional order
    /// @param gelatoTaskId: id of gelato task
    /// @param reason: reason for cancellation
    function emitConditionalOrderCancelled(
        uint256 conditionalOrderId,
        bytes32 gelatoTaskId,
        IAccount.ConditionalOrderCancelledReason reason
    ) external;

    event ConditionalOrderCancelled(
        address indexed account,
        uint256 indexed conditionalOrderId,
        bytes32 indexed gelatoTaskId,
        IAccount.ConditionalOrderCancelledReason reason
    );

    /// @notice emitted when a conditional order is filled
    /// @param conditionalOrderId: id of conditional order
    /// @param gelatoTaskId: id of gelato task
    /// @param fillPrice: price the conditional order was executed at
    /// @param keeperFee: fees paid to the executor
    /// @param priceOracle: price oracle used to execute conditional order
    function emitConditionalOrderFilled(
        uint256 conditionalOrderId,
        bytes32 gelatoTaskId,
        uint256 fillPrice,
        uint256 keeperFee,
        IAccount.PriceOracleUsed priceOracle
    ) external;

    event ConditionalOrderFilled(
        address indexed account,
        uint256 indexed conditionalOrderId,
        bytes32 indexed gelatoTaskId,
        uint256 fillPrice,
        uint256 keeperFee,
        IAccount.PriceOracleUsed priceOracle
    );
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

/// Used to fetch a price with a degree of uncertainty, represented as a price +- a confidence interval.
///
/// The confidence interval roughly corresponds to the standard error of a normal distribution.
/// Both the price and confidence are stored in a fixed-point numeric representation,
/// `x * (10^expo)`, where `expo` is the exponent.
///
/// Please refer to the documentation at https://docs.pyth.network/consumers/best-practices for how
/// to how this price safely.
interface IPerpsV2ExchangeRate {
    /// @notice Returns the price of a price feed without any sanity checks.
    /// @dev This function returns the most recent price update in this contract without any recency checks.
    /// This function is unsafe as the returned price update may be arbitrarily far in the past.
    ///
    /// Users of this function should check the `publishTime` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getPrice` or `getPriceNoOlderThan`.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    /// @return publishTime - unix timestamp describing when the price was published.
    function resolveAndGetLatestPrice(bytes32 assetId)
        external
        view
        returns (uint256 price, uint256 publishTime);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

/// @dev Inherit this contract to allow your smart
/// contract to make synchronous fee payments and have
/// call restrictions for functions to be automated.
abstract contract OpsReady {
    /// @notice address of Gelato Network contract
    address public immutable GELATO;

    /// @notice address of Gelato `Automate` contract
    address public immutable OPS;

    /// @notice internal address representation of ETH (used by Gelato)
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice sets the addresses of the Gelato Network contracts
    /// @param _gelato: address of the Gelato Network contract
    /// @param _ops: address of the Gelato `Automate` contract
    constructor(address _gelato, address _ops) {
        GELATO = _gelato;
        OPS = _ops;
    }

    /// @notice transfers fee (in ETH) to gelato for synchronous fee payments
    /// @dev happens at task execution time
    /// @param _amount: amount of asset to transfer
    function _transfer(uint256 _amount) internal {
        (bool success,) = GELATO.call{value: _amount}("");
        require(success, "OpsReady: ETH transfer failed");
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

library SafeCast160 {
    /// @notice Thrown when a valude greater than type(uint160).max is cast to uint160
    error UnsafeCast();

    /// @notice Safely casts uint256 to uint160
    /// @param value The uint256 to be cast
    function toUint160(uint256 value) internal pure returns (uint160) {
        if (value > type(uint160).max) revert UnsafeCast();
        return uint160(value);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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
    event Approval(
        address indexed owner, address indexed spender, uint256 value
    );

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
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

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
    function transferFrom(address from, address to, uint256 amount)
        external
        returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import {BytesLib} from "src/utils/uniswap/BytesLib.sol";
import {Constants} from "src/utils/uniswap/Constants.sol";

/// @title Functions for manipulating path data for multihop swaps
library V3Path {
    using BytesLib for bytes;

    /// @notice Returns true iff the path contains two or more pools
    /// @param path The encoded swap path
    /// @return True if path contains two or more pools, otherwise false
    function hasMultiplePools(bytes calldata path)
        internal
        pure
        returns (bool)
    {
        return path.length >= Constants.MULTIPLE_V3_POOLS_MIN_LENGTH;
    }

    function decodeFirstToken(bytes calldata path)
        internal
        pure
        returns (address tokenA)
    {
        tokenA = path.toAddress();
    }

    /// @notice Skips a token + fee element
    /// @param path The swap path
    function skipToken(bytes calldata path)
        internal
        pure
        returns (bytes calldata)
    {
        return path[Constants.NEXT_V3_POOL_OFFSET:];
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

/// @title Constant state
/// @notice Constant state used by the Universal Router
library Constants {
    /// @dev The length of the bytes encoded address
    uint256 internal constant ADDR_SIZE = 20;

    /// @dev The length of the bytes encoded fee
    uint256 internal constant V3_FEE_SIZE = 3;

    /// @dev The offset of a single token address (20) and pool fee (3)
    uint256 internal constant NEXT_V3_POOL_OFFSET = ADDR_SIZE + V3_FEE_SIZE;

    /// @dev The offset of an encoded pool key
    /// Token (20) + Fee (3) + Token (20) = 43
    uint256 internal constant V3_POP_OFFSET = NEXT_V3_POOL_OFFSET + ADDR_SIZE;

    /// @dev The minimum length of an encoding that contains 2 or more pools
    uint256 internal constant MULTIPLE_V3_POOLS_MIN_LENGTH =
        V3_POP_OFFSET + NEXT_V3_POOL_OFFSET;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

interface IPerpsV2MarketConsolidated {
    struct Position {
        uint64 id;
        uint64 lastFundingIndex;
        uint128 margin;
        uint128 lastPrice;
        int128 size;
    }

    struct DelayedOrder {
        bool isOffchain;
        int128 sizeDelta;
        uint128 desiredFillPrice;
        uint128 targetRoundId;
        uint128 commitDeposit;
        uint128 keeperDeposit;
        uint256 executableAtTime;
        uint256 intentionTime;
        bytes32 trackingCode;
    }

    function marketKey() external view returns (bytes32 key);

    function positions(address account)
        external
        view
        returns (Position memory);

    function delayedOrders(address account)
        external
        view
        returns (DelayedOrder memory);

    function baseAsset() external view returns (bytes32 key);

    function assetPrice() external view returns (uint256 price, bool invalid);

    function transferMargin(int256 marginDelta) external;

    function withdrawAllMargin() external;

    function modifyPositionWithTracking(
        int256 sizeDelta,
        uint256 desiredFillPrice,
        bytes32 trackingCode
    ) external;

    function closePositionWithTracking(
        uint256 desiredFillPrice,
        bytes32 trackingCode
    ) external;

    function submitCloseOffchainDelayedOrderWithTracking(
        uint256 desiredFillPrice,
        bytes32 trackingCode
    ) external;

    function submitCloseDelayedOrderWithTracking(
        uint256 desiredTimeDelta,
        uint256 desiredFillPrice,
        bytes32 trackingCode
    ) external;

    function submitDelayedOrderWithTracking(
        int256 sizeDelta,
        uint256 desiredTimeDelta,
        uint256 desiredFillPrice,
        bytes32 trackingCode
    ) external;

    function submitOffchainDelayedOrderWithTracking(
        int256 sizeDelta,
        uint256 desiredFillPrice,
        bytes32 trackingCode
    ) external;

    function cancelDelayedOrder(address account) external;

    function cancelOffchainDelayedOrder(address account) external;
}