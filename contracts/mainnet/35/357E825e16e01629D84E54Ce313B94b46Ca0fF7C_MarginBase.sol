// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "./interfaces/IAddressResolver.sol";
import "./interfaces/IFuturesMarket.sol";
import "./interfaces/IFuturesMarketManager.sol";
import "./interfaces/IMarginBaseTypes.sol";
import "./interfaces/IMarginBase.sol";
import "./interfaces/IExchanger.sol";
import "./utils/OpsReady.sol";
import "./utils/MinimalProxyable.sol";
import "./MarginBaseSettings.sol";

/// @title Kwenta MarginBase Account
/// @author JaredBorders ([email protected]), JChiaramonte7 ([email protected])
/// @notice Flexible, minimalist, and gas-optimized cross-margin enabled account
/// for managing perpetual futures positions
contract MarginBase is MinimalProxyable, IMarginBase, OpsReady {
    using BitMaps for BitMaps.BitMap;

    /*///////////////////////////////////////////////////////////////
                                Constants
    ///////////////////////////////////////////////////////////////*/

    /// @notice tracking code used when modifying positions
    bytes32 private constant TRACKING_CODE = "KWENTA";

    /// @notice name for futures market manager, needed for fetching market key
    bytes32 private constant FUTURES_MANAGER = "FuturesMarketManager";

    /// @notice max BPS
    uint256 private constant MAX_BPS = 10000;

    /// @notice constant for sUSD currency key
    bytes32 private constant SUSD = "sUSD";

    /*///////////////////////////////////////////////////////////////
                                State
    ///////////////////////////////////////////////////////////////*/

    // @notice synthetix address resolver
    IAddressResolver private addressResolver;

    /// @notice synthetix futures market manager
    IFuturesMarketManager private futuresManager;

    /// @notice settings for MarginBase account
    MarginBaseSettings public marginBaseSettings;

    /// @notice token contract used for account margin
    IERC20 public marginAsset;

    /// @notice margin locked for future events (ie. limit orders)
    uint256 public committedMargin;

    /// @notice active markets bitmap
    BitMaps.BitMap private markets;

    /// @notice market keys that the account has active positions in
    bytes32[] public activeMarketKeys;

    /// @notice active market keys mapped to index in activeMarketKeys
    mapping(bytes32 => uint256) public marketKeyIndex;

    /// @notice limit orders
    mapping(uint256 => Order) public orders;

    /// @notice sequentially id orders
    uint256 public orderId;

    /*///////////////////////////////////////////////////////////////
                                Events
    ///////////////////////////////////////////////////////////////*/

    /// @notice emitted after a successful deposit
    /// @param user: the address that deposited into account
    /// @param amount: amount of marginAsset to deposit into marginBase account
    event Deposit(address indexed user, uint256 amount);

    /// @notice emitted after a successful withdrawal
    /// @param user: the address that withdrew from account
    /// @param amount: amount of marginAsset to withdraw from marginBase account
    event Withdraw(address indexed user, uint256 amount);

    /// @notice emitted when an advanced order is placed
    /// @param account: account placing the order
    /// @param orderId: id of order
    /// @param marketKey: futures market key
    /// @param marginDelta: margin change
    /// @param sizeDelta: size change
    /// @param targetPrice: targeted fill price
    event OrderPlaced(
        address indexed account,
        uint256 orderId,
        bytes32 marketKey,
        int256 marginDelta,
        int256 sizeDelta,
        uint256 targetPrice,
        OrderTypes orderType
    );

    /// @notice emitted when an advanced order is cancelled
    event OrderCancelled(address indexed account, uint256 orderId);

    /// @notice emitted when an advanced order is filled
    /// @param fillPrice: price the order was executed at
    /// @param keeperFee: fees paid to the executor
    event OrderFilled(
        address indexed account,
        uint256 orderId,
        uint256 fillPrice,
        uint256 keeperFee
    );

    /// @notice emitted after a fee has been transferred to Treasury
    /// @param account: the address of the account the fee was imposed on
    /// @param amount: fee amount sent to Treasury
    event FeeImposed(address indexed account, uint256 amount);

    /*///////////////////////////////////////////////////////////////
                                Modifiers
    ///////////////////////////////////////////////////////////////*/

    /// @notice helpful modifier to check non-zero values
    /// @param value: value to check if zero
    modifier notZero(uint256 value, bytes32 valueName) {
        /// @notice value cannot be zero
        if (value == 0) {
            revert ValueCannotBeZero(valueName);
        }
        _;
    }

    /*///////////////////////////////////////////////////////////////
                                Errors
    ///////////////////////////////////////////////////////////////*/

    /// @notice given value cannot be zero
    /// @param valueName: name of the variable that cannot be zero
    error ValueCannotBeZero(bytes32 valueName);

    /// @notice limit size of new position specs passed into distribute margin
    /// @param numberOfNewPositions: number of new position specs
    error MaxNewPositionsExceeded(uint256 numberOfNewPositions);

    /// @notice exceeds useable margin
    /// @param available: amount of useable margin asset
    /// @param required: amount of margin asset required
    error InsufficientFreeMargin(uint256 available, uint256 required);

    /// @notice cannot execute invalid order
    error OrderInvalid();

    /// @notice call to transfer ETH on withdrawal fails
    error EthWithdrawalFailed();

    /// @notice base price from the oracle was invalid
    /// @dev Rate can be invalid either due to:
    ///      1. Returned as invalid from ExchangeRates - due to being stale or flagged by oracle
    ///      2. Out of deviation bounds w.r.t. to previously stored rate
    ///      3. if there is no valid stored rate, w.r.t. to previous 3 oracle rates
    ///      4. Price is zero
    error InvalidPrice();

    /// @notice cannot rescue underlying margin asset token
    error CannotRescueMarginAsset();

    /// @notice Insufficient margin to pay fee
    error CannotPayFee();

    /// @notice Must have a minimum eth balance before placing an order
    /// @param balance: current ETH balance
    /// @param minimum: min required ETH balance
    error InsufficientEthBalance(uint256 balance, uint256 minimum);

    /*///////////////////////////////////////////////////////////////
                        Constructor & Initializer
    ///////////////////////////////////////////////////////////////*/

    /// @notice constructor never used except for first CREATE
    // solhint-disable-next-line
    constructor() MinimalProxyable() {}

    /// @notice allows ETH to be deposited directly into a margin account
    /// @notice ETH can be withdrawn
    receive() external payable onlyOwner {}

    /// @notice initialize contract (only once) and transfer ownership to caller
    /// @dev ensure resolver and sUSD addresses are set to their proxies and not implementations
    /// @param _marginAsset: token contract address used for account margin
    /// @param _addressResolver: contract address for synthetix address resolver
    /// @param _marginBaseSettings: contract address for MarginBase account settings
    /// @param _ops: gelato ops address
    function initialize(
        address _marginAsset,
        address _addressResolver,
        address _marginBaseSettings,
        address payable _ops
    ) external initOnce {
        marginAsset = IERC20(_marginAsset);
        addressResolver = IAddressResolver(_addressResolver);
        futuresManager = IFuturesMarketManager(
            addressResolver.requireAndGetAddress(
                FUTURES_MANAGER,
                "MarginBase: Could not get Futures Market Manager"
            )
        );

        /// @dev MarginBaseSettings must exist prior to MarginBase account creation
        marginBaseSettings = MarginBaseSettings(_marginBaseSettings);

        /// @dev the Ownable constructor is never called when we create minimal proxies
        _transferOwnership(msg.sender);

        ops = _ops;
    }

    /*///////////////////////////////////////////////////////////////
                                Views
    ///////////////////////////////////////////////////////////////*/

    /// @notice get number of internal market positions account has
    /// @return number of positions which are internally accounted for
    function getNumberOfInternalPositions() external view returns (uint256) {
        return activeMarketKeys.length;
    }

    /// @notice the current withdrawable or usable balance
    function freeMargin() public view returns (uint256) {
        return marginAsset.balanceOf(address(this)) - committedMargin;
    }

    /// @notice get up-to-date position data from Synthetix
    /// @param _marketKey: key for synthetix futures market
    function getPosition(bytes32 _marketKey)
        public
        view
        returns (
            uint64 id,
            uint64 fundingIndex,
            uint128 margin,
            uint128 lastPrice,
            int128 size
        )
    {
        // fetch position data from Synthetix
        (id, fundingIndex, margin, lastPrice, size) = futuresMarket(_marketKey)
            .positions(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                        Account Deposit & Withdraw
    ///////////////////////////////////////////////////////////////*/

    /// @param _amount: amount of marginAsset to deposit into marginBase account
    function deposit(uint256 _amount) public onlyOwner {
        _deposit(_amount);
    }

    /// @dev see deposit() NatSpec
    function _deposit(uint256 _amount) internal notZero(_amount, "_amount") {
        // transfer in margin asset from user
        // (will revert if user does not have amount specified)
        require(
            marginAsset.transferFrom(owner(), address(this), _amount),
            "MarginBase: deposit failed"
        );

        emit Deposit(msg.sender, _amount);
    }

    /// @param _amount: amount of marginAsset to withdraw from marginBase account
    function withdraw(uint256 _amount)
        external
        notZero(_amount, "_amount")
        onlyOwner
    {
        // make sure committed margin isn't withdrawn
        if (_amount > freeMargin()) {
            revert InsufficientFreeMargin(freeMargin(), _amount);
        }

        // transfer out margin asset to user
        // (will revert if account does not have amount specified)
        require(
            marginAsset.transfer(owner(), _amount),
            "MarginBase: withdraw failed"
        );

        emit Withdraw(msg.sender, _amount);
    }

    /// @notice allow users to withdraw ETH deposited for keeper fees
    /// @param _amount: amount to withdraw
    function withdrawEth(uint256 _amount) external onlyOwner {
        // solhint-disable-next-line
        (bool success, ) = payable(owner()).call{value: _amount}("");
        if (!success) {
            revert EthWithdrawalFailed();
        }
    }

    /*///////////////////////////////////////////////////////////////
                            Margin Distribution
    ///////////////////////////////////////////////////////////////*/

    /// @notice accept a deposit amount and open new
    /// futures market position(s) all in a single tx
    /// @param _amount: amount of marginAsset to deposit into marginBase account
    /// @param _newPositions: an array of NewPosition's used to modify active market positions
    function depositAndDistribute(
        uint256 _amount,
        NewPosition[] memory _newPositions
    ) external onlyOwner {
        _deposit(_amount);
        _distributeMargin(_newPositions, 0);
    }

    /// @notice distribute margin across all/some positions specified via _newPositions
    /// @dev _newPositions may contain any number of new or existing positions
    /// @dev close and withdraw all margin from position if resulting position size is zero post trade
    /// @param _newPositions: an array of NewPosition's used to modify active market positions
    function distributeMargin(NewPosition[] memory _newPositions)
        external
        onlyOwner
    {
        _distributeMargin(_newPositions, 0);
    }

    // @dev see distributeMargin() NatSpec
    function _distributeMargin(
        NewPosition[] memory _newPositions,
        uint256 _advancedOrderFee
    ) internal {
        /// @notice limit size of new position specs passed into distribute margin
        uint256 newPositionsLength = _newPositions.length;
        if (newPositionsLength > type(uint8).max) {
            revert MaxNewPositionsExceeded(newPositionsLength);
        }

        /// @notice tracking variable for calculating fee(s)
        uint256 tradingFee = 0;

        // for each new position in _newPositions, distribute margin accordingly
        for (uint8 i = 0; i < newPositionsLength; i++) {
            // define market params to be used to create or modify a position
            bytes32 marketKey = _newPositions[i].marketKey;
            int256 sizeDelta = _newPositions[i].sizeDelta;
            int256 marginDelta = _newPositions[i].marginDelta;

            // define market
            IFuturesMarket market = futuresMarket(marketKey);

            // fetch position size from Synthetix
            (, , , , int128 size) = getPosition(marketKey);

            /// @dev check if position exists internally
            if (markets.get(uint256(marketKey))) {
                // check if position was liquidated
                if (size == 0) {
                    removeMarketKey(marketKey);

                    // this position no longer exists internally
                    // thus, treat as new position
                    if (sizeDelta == 0) {
                        // position does not exist internally thus, sizeDelta must be non-zero
                        revert ValueCannotBeZero("sizeDelta");
                    }
                }
                // check if position will be closed by newPosition's sizeDelta
                else if (size + sizeDelta == 0) {
                    removeMarketKey(marketKey);

                    // close position and withdraw margin
                    market.closePositionWithTracking(TRACKING_CODE);
                    market.withdrawAllMargin();

                    // determine trade fee based on size delta
                    tradingFee += calculateTradeFee(
                        sizeDelta,
                        market,
                        _advancedOrderFee
                    );

                    // continue to next newPosition
                    continue;
                }
            }
            /// @dev position does not exist internally thus sizeDelta must be non-zero
            else if (sizeDelta == 0) {
                revert ValueCannotBeZero("sizeDelta");
            }

            /// @notice execute trade
            /// @dev following trades will not result in position being closed
            /// @dev following trades may either modify or create a position
            if (marginDelta < 0) {
                // remove margin from market and potentially adjust position size
                tradingFee += modifyPositionForMarketAndWithdraw(
                    marginDelta,
                    sizeDelta,
                    market,
                    _advancedOrderFee
                );

                // update internal accounting
                addMarketKey(marketKey);
            } else if (marginDelta > 0) {
                // deposit margin into market and potentially adjust position size
                tradingFee += depositAndModifyPositionForMarket(
                    marginDelta,
                    sizeDelta,
                    market,
                    _advancedOrderFee
                );

                // update internal accounting
                addMarketKey(marketKey);
            } else if (sizeDelta != 0) {
                /// @notice adjust position size
                /// @notice no margin deposited nor withdrawn from market
                tradingFee += modifyPositionForMarket(
                    sizeDelta,
                    market,
                    _advancedOrderFee
                );

                // update internal accounting
                addMarketKey(marketKey);
            }
        }

        /// @notice impose fee
        /// @dev send fee to Kwenta's treasury
        if (tradingFee > 0) {
            // fee canot be greater than available margin
            if (tradingFee > freeMargin()) {
                revert CannotPayFee();
            }
            bool successfulTransfer = marginAsset.transfer(
                marginBaseSettings.treasury(),
                tradingFee
            );
            if (!successfulTransfer) {
                revert CannotPayFee();
            } else {
                emit FeeImposed(address(this), tradingFee);
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                        Execute Trades
    ///////////////////////////////////////////////////////////////*/

    /// @notice modify market position's size
    /// @dev _sizeDelta will always be non-zero
    /// @param _sizeDelta: size and position type (long/short) denominated in market synth
    /// @param _market: synthetix futures market
    /// @param _advancedOrderFee: if additional fee charged for advanced orders
    /// @return fee *in sUSD*
    function modifyPositionForMarket(
        int256 _sizeDelta,
        IFuturesMarket _market,
        uint256 _advancedOrderFee
    ) internal returns (uint256 fee) {
        // modify position in specific market with KWENTA tracking code
        _market.modifyPositionWithTracking(_sizeDelta, TRACKING_CODE);

        // determine trade fee based on size delta
        fee = calculateTradeFee(_sizeDelta, _market, _advancedOrderFee);

        /// @notice alter the amount of margin in specific market position
        /// @dev positive input triggers a deposit; a negative one, a withdrawal
        _market.transferMargin(int256(fee) * -1);
    }

    /// @notice deposit margin into specific market and potentially modify position size
    /// @dev _depositSize will always be greater than zero
    /// @dev _sizeDelta may be zero (i.e. market position goes unchanged)
    /// @param _depositSize: size of deposit in sUSD
    /// @param _sizeDelta: size and position type (long/short) denominated in market synth
    /// @param _market: synthetix futures market
    /// @param _advancedOrderFee: if additional fee charged for advanced orders
    /// @return fee *in sUSD*
    function depositAndModifyPositionForMarket(
        int256 _depositSize,
        int256 _sizeDelta,
        IFuturesMarket _market,
        uint256 _advancedOrderFee
    ) internal returns (uint256 fee) {
        /// @dev ensure trade doesn't spend margin which is not available
        uint256 absDepositSize = _abs(_depositSize);
        if (absDepositSize > freeMargin()) {
            revert InsufficientFreeMargin(freeMargin(), absDepositSize);
        }

        /// @dev if _sizeDelta is 0, then we do not want to modify position size, only margin
        if (_sizeDelta != 0) {
            // determine trade fee based on size delta
            fee = calculateTradeFee(_sizeDelta, _market, _advancedOrderFee);

            /// @notice alter the amount of margin in specific market position
            /// @dev positive input triggers a deposit; a negative one, a withdrawal
            /// @dev subtracting fee ensures margin account has enough margin to pay
            /// the fee (i.e. effectively fee comes from position)
            _market.transferMargin(_depositSize - int256(fee));

            // modify position in specific market with KWENTA tracking code
            _market.modifyPositionWithTracking(_sizeDelta, TRACKING_CODE);
        } else {
            /// @notice alter the amount of margin in specific market position
            /// @dev positive input triggers a deposit; a negative one, a withdrawal
            _market.transferMargin(_depositSize);
        }
    }

    /// @notice potentially modify position size and withdraw margin from market
    /// @dev _withdrawalSize will always be less than zero
    /// @dev _sizeDelta may be zero (i.e. market position goes unchanged)
    /// @param _withdrawalSize: size of sUSD to withdraw from market into account
    /// @param _sizeDelta: size and position type (long//short) denominated in market synth
    /// @param _market: synthetix futures market
    /// @param _advancedOrderFee: if additional fee charged for advanced orders
    /// @return fee *in sUSD*
    function modifyPositionForMarketAndWithdraw(
        int256 _withdrawalSize,
        int256 _sizeDelta,
        IFuturesMarket _market,
        uint256 _advancedOrderFee
    ) internal returns (uint256 fee) {
        /// @dev if _sizeDelta is 0, then we do not want to modify position size, only margin
        if (_sizeDelta != 0) {
            // modify position in specific market with KWENTA tracking code
            _market.modifyPositionWithTracking(_sizeDelta, TRACKING_CODE);

            // determine trade fee based on size delta
            fee = calculateTradeFee(_sizeDelta, _market, _advancedOrderFee);

            /// @notice alter the amount of margin in specific market position
            /// @dev positive input triggers a deposit; a negative one, a withdrawal
            /// @dev subtracting fee ensures margin account has enough margin to pay
            /// the fee (i.e. effectively fee comes from position)
            _market.transferMargin(_withdrawalSize - int256(fee));
        } else {
            /// @notice alter the amount of margin in specific market position
            /// @dev positive input triggers a deposit; a negative one, a withdrawal
            _market.transferMargin(_withdrawalSize);
        }
    }

    /*///////////////////////////////////////////////////////////////
                        Internal Accounting
    ///////////////////////////////////////////////////////////////*/

    /// @notice calculate fee based on both size and given market
    /// @param _sizeDelta: size delta of given trade
    /// @param _market: synthetix futures market
    /// @param _advancedOrderFee: if additional fee charged for advanced orders
    /// @return fee to be imposed based on size delta
    function calculateTradeFee(
        int256 _sizeDelta,
        IFuturesMarket _market,
        uint256 _advancedOrderFee
    ) internal view returns (uint256 fee) {
        fee =
            (_abs(_sizeDelta) *
                (marginBaseSettings.tradeFee() + _advancedOrderFee)) /
            MAX_BPS;
        /// @notice fee is currently measured in the underlying base asset of the market
        /// @dev fee will be measured in sUSD, thus exchange rate is needed
        fee = (sUSDRate(_market) * fee) / 1e18;
    }

    /// @notice add marketKey to activeMarketKeys
    /// @param _marketKey to add
    function addMarketKey(bytes32 _marketKey) internal {
        if (!markets.get(uint256(_marketKey))) {
            // add to mapping
            marketKeyIndex[_marketKey] = activeMarketKeys.length;

            // add to end of array
            activeMarketKeys.push(_marketKey);

            // add to bitmap
            markets.setTo(uint256(_marketKey), true);
        }
    }

    /// @notice remove index from activeMarketKeys
    /// @param _marketKey to add
    function removeMarketKey(bytes32 _marketKey) internal {
        uint256 index = marketKeyIndex[_marketKey];
        assert(index < activeMarketKeys.length);

        // remove from mapping
        delete marketKeyIndex[_marketKey];

        // remove from array
        for (; index < activeMarketKeys.length - 1; ) {
            unchecked {
                // shift element in array to the left
                activeMarketKeys[index] = activeMarketKeys[index + 1];
                // update index for given market key
                marketKeyIndex[activeMarketKeys[index]] = index;
                index++;
            }
        }
        activeMarketKeys.pop();

        // remove from bitmap
        markets.setTo(uint256(_marketKey), false);
    }

    /*///////////////////////////////////////////////////////////////
                            Limit Orders
    ///////////////////////////////////////////////////////////////*/

    /// @notice order logic condition checker
    /// @dev this is where order type logic checks are handled
    /// @param _orderId: key for an active order
    /// @return true if order is valid by execution rules
    /// @return price that the order will be filled at (only valid if prev is true)
    function validOrder(uint256 _orderId) public view returns (bool, uint256) {
        Order memory order = orders[_orderId];

        if (order.maxDynamicFee != 0) {
            (uint256 dynamicFee, bool tooVolatile) = exchanger()
                .dynamicFeeRateForExchange(
                    SUSD,
                    futuresMarket(order.marketKey).baseAsset()
                );
            if (tooVolatile || dynamicFee > order.maxDynamicFee) {
                return (false, 0);
            }
        }

        if (order.orderType == OrderTypes.LIMIT) {
            return validLimitOrder(order);
        } else if (order.orderType == OrderTypes.STOP) {
            return validStopOrder(order);
        }

        // unknown order type
        // @notice execution should never reach here
        // @dev needed to satisfy types
        return (false, 0);
    }

    /// @notice limit order logic condition checker
    /// @param order: struct for an active order
    /// @return true if order is valid by execution rules
    /// @return price that the order will be filled at (only valid if prev is true)
    function validLimitOrder(Order memory order)
        internal
        view
        returns (bool, uint256)
    {
        uint256 price = sUSDRate(futuresMarket(order.marketKey));

        /// @notice intent is targetPrice or better despite direction
        if (order.sizeDelta > 0) {
            // Long
            return (price <= order.targetPrice, price);
        } else if (order.sizeDelta < 0) {
            // Short
            return (price >= order.targetPrice, price);
        }

        // sizeDelta == 0
        // @notice execution should never reach here
        // @dev needed to satisfy types
        return (false, price);
    }

    /// @notice stop order logic condition checker
    /// @param order: struct for an active order
    /// @return true if order is valid by execution rules
    /// @return price that the order will be filled at (only valid if prev is true)
    function validStopOrder(Order memory order)
        internal
        view
        returns (bool, uint256)
    {
        uint256 price = sUSDRate(futuresMarket(order.marketKey));

        /// @notice intent is targetPrice or worse despite direction
        if (order.sizeDelta > 0) {
            // Long
            return (price >= order.targetPrice, price);
        } else if (order.sizeDelta < 0) {
            // Short
            return (price <= order.targetPrice, price);
        }

        // sizeDelta == 0
        // @notice execution should never reach here
        // @dev needed to satisfy types
        return (false, price);
    }

    /// @notice register a limit order internally and with gelato
    /// @param _marketKey: synthetix futures market id/key
    /// @param _marginDelta: amount of margin (in sUSD) to deposit or withdraw
    /// @param _sizeDelta: denominated in market currency (i.e. ETH, BTC, etc), size of futures position
    /// @param _targetPrice: expected limit order price
    /// @param _orderType: expected order type enum where 0 = LIMIT, 1 = STOP, etc..
    /// @return orderId contract interface
    function placeOrder(
        bytes32 _marketKey,
        int256 _marginDelta,
        int256 _sizeDelta,
        uint256 _targetPrice,
        OrderTypes _orderType
    ) external payable returns (uint256) {
        return
            _placeOrder(
                _marketKey,
                _marginDelta,
                _sizeDelta,
                _targetPrice,
                _orderType,
                0
            );
    }

    /// @notice register a limit order internally and with gelato
    /// @param _marketKey: synthetix futures market id/key
    /// @param _marginDelta: amount of margin (in sUSD) to deposit or withdraw
    /// @param _sizeDelta: denominated in market currency (i.e. ETH, BTC, etc), size of futures position
    /// @param _targetPrice: expected limit order price
    /// @param _orderType: expected order type enum where 0 = LIMIT, 1 = STOP, etc..
    /// @param _maxDynamicFee: dynamic fee cap in 18 decimal form; 0 for no cap
    /// @return orderId contract interface
    function placeOrderWithFeeCap(
        bytes32 _marketKey,
        int256 _marginDelta,
        int256 _sizeDelta,
        uint256 _targetPrice,
        OrderTypes _orderType,
        uint256 _maxDynamicFee
    ) external payable returns (uint256) {
        return
            _placeOrder(
                _marketKey,
                _marginDelta,
                _sizeDelta,
                _targetPrice,
                _orderType,
                _maxDynamicFee
            );
    }

    function _placeOrder(
        bytes32 _marketKey,
        int256 _marginDelta,
        int256 _sizeDelta,
        uint256 _targetPrice,
        OrderTypes _orderType,
        uint256 _maxDynamicFee
    )
        internal
        notZero(_abs(_sizeDelta), "_sizeDelta")
        onlyOwner
        returns (uint256)
    {
        if (address(this).balance < 1 ether / 100) {
            revert InsufficientEthBalance(address(this).balance, 1 ether / 100);
        }
        // if more margin is desired on the position we must commit the margin
        if (_marginDelta > 0) {
            // ensure margin doesn't exceed max
            if (_abs(_marginDelta) > freeMargin()) {
                revert InsufficientFreeMargin(freeMargin(), _abs(_marginDelta));
            }
            committedMargin += _abs(_marginDelta);
        }

        bytes32 taskId = IOps(ops).createTaskNoPrepayment(
            address(this), // execution function address
            this.executeOrder.selector, // execution function selector
            address(this), // checker (resolver) address
            abi.encodeWithSelector(this.checker.selector, orderId), // checker (resolver) calldata
            ETH // payment token
        );

        orders[orderId] = Order({
            marketKey: _marketKey,
            marginDelta: _marginDelta,
            sizeDelta: _sizeDelta,
            targetPrice: _targetPrice,
            gelatoTaskId: taskId,
            orderType: _orderType,
            maxDynamicFee: _maxDynamicFee
        });

        emit OrderPlaced(
            address(this),
            orderId,
            _marketKey,
            _marginDelta,
            _sizeDelta,
            _targetPrice,
            _orderType
        );

        return orderId++;
    }

    /// @notice cancel a gelato queued order
    /// @param _orderId: key for an active order
    function cancelOrder(uint256 _orderId) external onlyOwner {
        Order memory order = orders[_orderId];

        // if margin was committed, free it
        if (order.marginDelta > 0) {
            committedMargin -= _abs(order.marginDelta);
        }
        IOps(ops).cancelTask(order.gelatoTaskId);

        // delete order from orders
        delete orders[_orderId];

        emit OrderCancelled(address(this), _orderId);
    }

    /// @notice execute a gelato queued order
    /// @notice only keepers can trigger this function
    /// @param _orderId: key for an active order
    function executeOrder(uint256 _orderId) external onlyOps {
        (bool isValidOrder, uint256 fillPrice) = validOrder(_orderId);
        if (!isValidOrder) {
            revert OrderInvalid();
        }
        Order memory order = orders[_orderId];

        // if margin was committed, free it
        if (order.marginDelta > 0) {
            committedMargin -= _abs(order.marginDelta);
        }

        // prep new position
        MarginBase.NewPosition[]
            memory newPositions = new MarginBase.NewPosition[](1);
        newPositions[0] = NewPosition({
            marketKey: order.marketKey,
            marginDelta: order.marginDelta,
            sizeDelta: order.sizeDelta
        });

        // remove task from gelato's side
        /// @dev optimization done for gelato
        IOps(ops).cancelTask(order.gelatoTaskId);

        // delete order from orders
        delete orders[_orderId];

        uint256 advancedOrderFee = order.orderType == OrderTypes.LIMIT
            ? marginBaseSettings.limitOrderFee()
            : marginBaseSettings.stopOrderFee();

        // execute trade
        _distributeMargin(newPositions, advancedOrderFee);

        // pay fee
        (uint256 fee, address feeToken) = IOps(ops).getFeeDetails();
        _transfer(fee, feeToken);

        emit OrderFilled(address(this), _orderId, fillPrice, fee);
    }

    /// @notice signal to a keeper that an order is valid/invalid for execution
    /// @param _orderId: key for an active order
    /// @return canExec boolean that signals to keeper an order can be executed
    /// @return execPayload calldata for executing an order
    function checker(uint256 _orderId)
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        (canExec, ) = validOrder(_orderId);
        // calldata for execute func
        execPayload = abi.encodeWithSelector(
            this.executeOrder.selector,
            _orderId
        );
    }

    /*///////////////////////////////////////////////////////////////
                        Internal Getter Utilities
    ///////////////////////////////////////////////////////////////*/

    /// @notice addressResolver fetches IFuturesMarket address for specific market
    /// @param _marketKey: key for synthetix futures market
    /// @return IFuturesMarket contract interface
    function futuresMarket(bytes32 _marketKey)
        internal
        view
        returns (IFuturesMarket)
    {
        return IFuturesMarket(futuresManager.marketForKey(_marketKey));
    }

    /// @notice get exchange rate of underlying market asset in terms of sUSD
    /// @param market: synthetix futures market
    /// @return price in sUSD
    function sUSDRate(IFuturesMarket market) internal view returns (uint256) {
        (uint256 price, bool invalid) = market.assetPrice();
        if (invalid) {
            revert InvalidPrice();
        }
        return price;
    }

    /// @notice exchangeRates() fetches current ExchangeRates contract
    function exchanger() internal view returns (IExchanger) {
        return
            IExchanger(
                addressResolver.requireAndGetAddress(
                    "Exchanger",
                    "MarginBase: Could not get Exchanger"
                )
            );
    }

    /*///////////////////////////////////////////////////////////////
                            Utility Functions
    ///////////////////////////////////////////////////////////////*/

    /// @notice Absolute value of the input, returned as an unsigned number.
    /// @param x: signed number
    function _abs(int256 x) internal pure returns (uint256) {
        return uint256(x < 0 ? -x : x);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

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
    event Approval(address indexed owner, address indexed spender, uint256 value);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/structs/BitMaps.sol)
pragma solidity ^0.8.0;

/**
 * @dev Library for managing uint256 to bool mapping in a compact and efficient way, providing the keys are sequential.
 * Largelly inspired by Uniswap's https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol[merkle-distributor].
 */
library BitMaps {
    struct BitMap {
        mapping(uint256 => uint256) _data;
    }

    /**
     * @dev Returns whether the bit at `index` is set.
     */
    function get(BitMap storage bitmap, uint256 index) internal view returns (bool) {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        return bitmap._data[bucket] & mask != 0;
    }

    /**
     * @dev Sets the bit at `index` to the boolean `value`.
     */
    function setTo(
        BitMap storage bitmap,
        uint256 index,
        bool value
    ) internal {
        if (value) {
            set(bitmap, index);
        } else {
            unset(bitmap, index);
        }
    }

    /**
     * @dev Sets the bit at `index`.
     */
    function set(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] |= mask;
    }

    /**
     * @dev Unsets the bit at `index`.
     */
    function unset(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] &= ~mask;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

// https://docs.synthetix.io/contracts/source/interfaces/iaddressresolver
interface IAddressResolver {
    function getAddress(bytes32 name) external view returns (address);

    function getSynth(bytes32 key) external view returns (address);

    function requireAndGetAddress(bytes32 name, string calldata reason) external view returns (address);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./IFuturesMarketBaseTypes.sol";

interface IFuturesMarket {
    /* ========== FUNCTION INTERFACE ========== */

    /* ---------- Market Details ---------- */

    function marketKey() external view returns (bytes32 key);

    function baseAsset() external view returns (bytes32 key);

    function marketSize() external view returns (uint128 size);

    function marketSkew() external view returns (int128 skew);

    function fundingLastRecomputed() external view returns (uint32 timestamp);

    function fundingSequence(uint index) external view returns (int128 netFunding);

    function positions(address account)
        external
        view
        returns (
            uint64 id,
            uint64 fundingIndex,
            uint128 margin,
            uint128 lastPrice,
            int128 size
        );

    function assetPrice() external view returns (uint price, bool invalid);

    function marketSizes() external view returns (uint long, uint short);

    function marketDebt() external view returns (uint debt, bool isInvalid);

    function currentFundingRate() external view returns (int fundingRate);

    function unrecordedFunding() external view returns (int funding, bool invalid);

    function fundingSequenceLength() external view returns (uint length);

    /* ---------- Position Details ---------- */

    function notionalValue(address account) external view returns (int value, bool invalid);

    function profitLoss(address account) external view returns (int pnl, bool invalid);

    function accruedFunding(address account) external view returns (int funding, bool invalid);

    function remainingMargin(address account) external view returns (uint marginRemaining, bool invalid);

    function accessibleMargin(address account) external view returns (uint marginAccessible, bool invalid);

    function liquidationPrice(address account) external view returns (uint price, bool invalid);

    function liquidationFee(address account) external view returns (uint);

    function canLiquidate(address account) external view returns (bool);

    function orderFee(int sizeDelta) external view returns (uint fee, bool invalid);

    function postTradeDetails(int sizeDelta, address sender)
        external
        view
        returns (
            uint margin,
            int size,
            uint price,
            uint liqPrice,
            uint fee,
            IFuturesMarketBaseTypes.Status status
        );

    /* ---------- Market Operations ---------- */

    function recomputeFunding() external returns (uint lastIndex);

    function transferMargin(int marginDelta) external;

    function withdrawAllMargin() external;

    function modifyPosition(int sizeDelta) external;

    function modifyPositionWithTracking(int sizeDelta, bytes32 trackingCode) external;

    function submitNextPriceOrder(int sizeDelta) external;

    function submitNextPriceOrderWithTracking(int sizeDelta, bytes32 trackingCode) external;

    function cancelNextPriceOrder(address account) external;

    function executeNextPriceOrder(address account) external;

    function closePosition() external;

    function closePositionWithTracking(bytes32 trackingCode) external;

    function liquidatePosition(address account) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

interface IFuturesMarketManager {
    function markets(uint index, uint pageSize) external view returns (address[] memory);

    function numMarkets() external view returns (uint);

    function allMarkets() external view returns (address[] memory);

    function marketForKey(bytes32 marketKey) external view returns (address);

    function marketsForKeys(bytes32[] calldata marketKeys) external view returns (address[] memory);

    function totalDebt() external view returns (uint debt, bool isInvalid);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

/// @title Kwenta MarginBase Types
/// @author JaredBorders ([email protected]), JChiaramonte7 ([email protected])
/// @notice Types used in Margin Base Accounts
interface IMarginBaseTypes {
    /*///////////////////////////////////////////////////////////////
                                Types
    ///////////////////////////////////////////////////////////////*/

    // denotes order types for code clarity
    /// @dev under the hood LIMIT = 0, STOP = 1
    enum OrderTypes {
        LIMIT,
        STOP
    }

    // marketKey: synthetix futures market id/key
    // marginDelta: amount of margin (in sUSD) to deposit or withdraw
    // sizeDelta: denoted in market currency (i.e. ETH, BTC, etc), size of futures position
    struct NewPosition {
        bytes32 marketKey;
        int256 marginDelta; // positive indicates deposit, negative withdraw
        int256 sizeDelta;
    }

    // marketKey: synthetix futures market id/key
    // marginDelta: amount of margin (in sUSD) to deposit or withdraw
    // sizeDelta: denoted in market currency (i.e. ETH, BTC, etc), size of futures position
    // targetPrice: limit or stop price to fill at
    // gelatoTaskId: unqiue taskId from gelato necessary for cancelling orders
    // orderType: order type to determine order fill logic
    // maxDynamicFee: dynamic fee cap in 18 decimal form; 0 for no cap
    struct Order {
        bytes32 marketKey;
        int256 marginDelta; // positive indicates deposit, negative withdraw
        int256 sizeDelta;
        uint256 targetPrice;
        bytes32 gelatoTaskId;
        OrderTypes orderType;
        uint256 maxDynamicFee;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "./IMarginBaseTypes.sol";

/// @title Kwenta MarginBase Interface
/// @author JaredBorders ([email protected]roton.me), JChiaramonte7 ([email protected])
interface IMarginBase is IMarginBaseTypes {
    /*///////////////////////////////////////////////////////////////
                                Views
    ///////////////////////////////////////////////////////////////*/

    function getNumberOfInternalPositions() external view returns (uint256);

    function freeMargin() external view returns (uint256);

    function getPosition(bytes32 _marketKey)
        external
        returns (
            uint64 id,
            uint64 fundingIndex,
            uint128 margin,
            uint128 lastPrice,
            int128 size
        );

    /*///////////////////////////////////////////////////////////////
                                Mutative
    ///////////////////////////////////////////////////////////////*/

    // Account Deposit & Withdraw
    function deposit(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function withdrawEth(uint256 _amount) external;

    // Margin Distribution
    function distributeMargin(NewPosition[] memory _newPositions) external;

    function depositAndDistribute(
        uint256 _amount,
        NewPosition[] memory _newPositions
    ) external;

    // Limit Orders
    function validOrder(uint256 _orderId) external view returns (bool, uint256);

    function placeOrder(
        bytes32 _marketKey,
        int256 _marginDelta,
        int256 _sizeDelta,
        uint256 _targetPrice,
        OrderTypes _orderType
    ) external payable returns (uint256);

    function placeOrderWithFeeCap(
        bytes32 _marketKey,
        int256 _marginDelta,
        int256 _sizeDelta,
        uint256 _targetPrice,
        OrderTypes _orderType,
        uint256 _maxDynamicFee
    ) external payable returns (uint256);

    function cancelOrder(uint256 _orderId) external;

    function checker(uint256 _orderId)
        external
        view
        returns (bool canExec, bytes memory execPayload);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./IVirtualSynth.sol";

// https://docs.synthetix.io/contracts/source/interfaces/iexchanger
interface IExchanger {
    struct ExchangeEntrySettlement {
        bytes32 src;
        uint amount;
        bytes32 dest;
        uint reclaim;
        uint rebate;
        uint srcRoundIdAtPeriodEnd;
        uint destRoundIdAtPeriodEnd;
        uint timestamp;
    }

    struct ExchangeEntry {
        uint sourceRate;
        uint destinationRate;
        uint destinationAmount;
        uint exchangeFeeRate;
        uint exchangeDynamicFeeRate;
        uint roundIdForSrc;
        uint roundIdForDest;
    }

    // Views
    function calculateAmountAfterSettlement(
        address from,
        bytes32 currencyKey,
        uint amount,
        uint refunded
    ) external view returns (uint amountAfterSettlement);

    function isSynthRateInvalid(bytes32 currencyKey) external view returns (bool);

    function maxSecsLeftInWaitingPeriod(address account, bytes32 currencyKey) external view returns (uint);

    function settlementOwing(address account, bytes32 currencyKey)
        external
        view
        returns (
            uint reclaimAmount,
            uint rebateAmount,
            uint numEntries
        );

    function hasWaitingPeriodOrSettlementOwing(address account, bytes32 currencyKey) external view returns (bool);

    function feeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey) external view returns (uint);

    function dynamicFeeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey)
        external
        view
        returns (uint feeRate, bool tooVolatile);

    function getAmountsForExchange(
        uint sourceAmount,
        bytes32 sourceCurrencyKey,
        bytes32 destinationCurrencyKey
    )
        external
        view
        returns (
            uint amountReceived,
            uint fee,
            uint exchangeFeeRate
        );

    function priceDeviationThresholdFactor() external view returns (uint);

    function waitingPeriodSecs() external view returns (uint);

    function lastExchangeRate(bytes32 currencyKey) external view returns (uint);

    // Mutative functions
    function exchange(
        address exchangeForAddress,
        address from,
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address destinationAddress,
        bool virtualSynth,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint amountReceived, IVirtualSynth vSynth);

    function exchangeAtomically(
        address from,
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address destinationAddress,
        bytes32 trackingCode,
        uint minAmount
    ) external returns (uint amountReceived);

    function settle(address from, bytes32 currencyKey)
        external
        returns (
            uint reclaimed,
            uint refunded,
            uint numEntries
        );

    function suspendSynthWithInvalidRate(bytes32 currencyKey) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    SafeERC20,
    IERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IOps.sol";

abstract contract OpsReady {
    address public ops;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    modifier onlyOps() {
        require(msg.sender == ops, "OpsReady: onlyOps");
        _;
    }

    function gelato() public view returns (address payable) {
        return IOps(ops).gelato();
    }

    function _transfer(uint256 _amount, address _paymentToken) internal {
        if (_paymentToken == ETH) {
            (bool success, ) = gelato().call{value: _amount}("");
            require(success, "_transfer: ETH transfer failed");
        } else {
            SafeERC20.safeTransfer(IERC20(_paymentToken), gelato(), _amount);
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MinimalProxyable is Ownable {

    bool masterCopy;
    bool initialized;

    constructor() {
        masterCopy = true;
    }

    function initialize() public initOnce {}

    modifier initOnce {
        require(!masterCopy, "Cannot initialize implementation");
        require(!initialized, "Already initialized");
        initialized = true;
        _;
    }

}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Kwenta Settings for MarginBase Accounts
/// @author JaredBorders ([email protected]), JChiaramonte7 ([email protected])
/// @notice Contract (owned by the deployer) for controlling the settings of MarginBase account(s)
/// @dev This contract will require deployment prior to MarginBase account creation
contract MarginBaseSettings is Ownable {
    /*///////////////////////////////////////////////////////////////
                                Constants
    ///////////////////////////////////////////////////////////////*/

    /// @notice max BPS; used for decimals calculations
    uint256 private constant MAX_BPS = 10000;

    /*///////////////////////////////////////////////////////////////
                        Settings
    ///////////////////////////////////////////////////////////////*/

    // @notice Kwenta's Treasury Address
    address public treasury;

    /// @notice denoted in Basis points (BPS) (One basis point is equal to 1/100th of 1%)
    /// @dev fee imposed on all trades
    /// @dev trades: defined as changes made to IMarginBaseTypes.ActiveMarketPosition.size
    uint256 public tradeFee;

    /// @notice denoted in Basis points (BPS) (One basis point is equal to 1/100th of 1%)
    /// @dev fee imposed on limit orders
    uint256 public limitOrderFee;

    /// @notice denoted in Basis points (BPS) (One basis point is equal to 1/100th of 1%)
    /// @dev fee imposed on stop losses
    uint256 public stopOrderFee;

    /*///////////////////////////////////////////////////////////////
                                Events
    ///////////////////////////////////////////////////////////////*/

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

    /*///////////////////////////////////////////////////////////////
                                Errors
    ///////////////////////////////////////////////////////////////*/

    /// @notice zero address cannot be used
    error ZeroAddress();

    /// @notice invalid fee (fee > MAX_BPS)
    /// @param fee: fee denoted in BPS
    error InvalidFee(uint256 fee);

    /// @notice new fee cannot be the same as the old fee
    error DuplicateFee();

    /// @notice new address cannot be the same as the old address
    error DuplicateAddress();

    /*///////////////////////////////////////////////////////////////
                            Constructor
    ///////////////////////////////////////////////////////////////*/

    /// @notice set initial margin base account fees
    /// @param _treasury: Kwenta's Treasury Address
    /// @param _tradeFee: fee denoted in BPS
    /// @param _limitOrderFee: fee denoted in BPS
    /// @param _stopOrderFee: fee denoted in BPS
    constructor(
        address _treasury,
        uint256 _tradeFee,
        uint256 _limitOrderFee,
        uint256 _stopOrderFee
    ) {
        /// @notice ensure valid address for Kwenta Treasury
        if (_treasury == address(0)) revert ZeroAddress();

        /// @notice set Kwenta Treasury address
        treasury = _treasury;

        /// @notice ensure valid fees
        if (_tradeFee > MAX_BPS) revert InvalidFee(_tradeFee);
        if (_limitOrderFee > MAX_BPS) revert InvalidFee(_limitOrderFee);
        if (_stopOrderFee > MAX_BPS) revert InvalidFee(_stopOrderFee);

        /// @notice set initial fees
        tradeFee = _tradeFee;
        limitOrderFee = _limitOrderFee;
        stopOrderFee = _stopOrderFee;
    }

    /*///////////////////////////////////////////////////////////////
                                Setters
    ///////////////////////////////////////////////////////////////*/

    /// @notice set new treasury address
    /// @param _treasury: new treasury address
    function setTreasury(address _treasury) external onlyOwner {
        /// @notice ensure valid address for Kwenta Treasury
        if (_treasury == address(0)) revert ZeroAddress();

        // @notice ensure address will change
        if (_treasury == treasury) revert DuplicateAddress();

        /// @notice set Kwenta Treasury address
        treasury = _treasury;

        emit TreasuryAddressChanged(_treasury);
    }

    /// @notice set new trade fee
    /// @param _fee: fee denoted in BPS
    function setTradeFee(uint256 _fee) external onlyOwner {
        /// @notice ensure valid fee
        if (_fee > MAX_BPS) revert InvalidFee(_fee);

        // @notice ensure fee will change
        if (_fee == tradeFee) revert DuplicateFee();

        /// @notice set fee
        tradeFee = _fee;

        emit TradeFeeChanged(_fee);
    }

    /// @notice set new limit order fee
    /// @param _fee: fee denoted in BPS
    function setLimitOrderFee(uint256 _fee) external onlyOwner {
        /// @notice ensure valid fee
        if (_fee > MAX_BPS) revert InvalidFee(_fee);

        // @notice ensure fee will change
        if (_fee == limitOrderFee) revert DuplicateFee();

        /// @notice set fee
        limitOrderFee = _fee;

        emit LimitOrderFeeChanged(_fee);
    }

    /// @notice set new stop loss fee
    /// @param _fee: fee denoted in BPS
    function setStopOrderFee(uint256 _fee) external onlyOwner {
        /// @notice ensure valid fee
        if (_fee > MAX_BPS) revert InvalidFee(_fee);

        // @notice ensure fee will change
        if (_fee == stopOrderFee) revert DuplicateFee();

        /// @notice set fee
        stopOrderFee = _fee;

        emit StopOrderFeeChanged(_fee);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

interface IFuturesMarketBaseTypes {
    /* ========== TYPES ========== */

    enum Status {
        Ok,
        InvalidPrice,
        PriceOutOfBounds,
        CanLiquidate,
        CannotLiquidate,
        MaxMarketSizeExceeded,
        MaxLeverageExceeded,
        InsufficientMargin,
        NotPermitted,
        NilOrder,
        NoPositionOpen,
        PriceTooVolatile
    }

    // If margin/size are positive, the position is long; if negative then it is short.
    struct Position {
        uint64 id;
        uint64 lastFundingIndex;
        uint128 margin;
        uint128 lastPrice;
        int128 size;
    }

    // next-price order storage
    struct NextPriceOrder {
        int128 sizeDelta; // difference in position to pass to modifyPosition
        uint128 targetRoundId; // price oracle roundId using which price this order needs to exucted
        uint128 commitDeposit; // the commitDeposit paid upon submitting that needs to be refunded if order succeeds
        uint128 keeperDeposit; // the keeperDeposit paid upon submitting that needs to be paid / refunded on tx confirmation
        bytes32 trackingCode; // tracking code to emit on execution for volume source fee sharing
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./ISynth.sol";

interface IVirtualSynth {
    // Views
    function balanceOfUnderlying(address account) external view returns (uint);

    function rate() external view returns (uint);

    function readyToSettle() external view returns (bool);

    function secsLeftInWaitingPeriod() external view returns (uint);

    function settled() external view returns (bool);

    function synth() external view returns (ISynth);

    // Mutative functions
    function settle(address account) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

// https://docs.synthetix.io/contracts/source/interfaces/isynth
interface ISynth {
    // Views
    function currencyKey() external view returns (bytes32);

    function transferableSynths(address account) external view returns (uint);

    // Mutative functions
    function transferAndSettle(address to, uint value) external returns (bool);

    function transferFromAndSettle(
        address from,
        address to,
        uint value
    ) external returns (bool);

    // Restricted: used internally to Synthetix
    function burn(address account, uint amount) external;

    function issue(address account, uint amount) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

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

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IOps {
    event TaskCreated(
        address taskCreator,
        address execAddress,
        bytes4 selector,
        address resolverAddress,
        bytes32 taskId,
        bytes resolverData,
        bool useTaskTreasuryFunds,
        address feeToken,
        bytes32 resolverHash
    );

    event TaskCancelled(bytes32 taskId, address taskCreator);

    event ExecSuccess(
        uint256 indexed txFee,
        address indexed feeToken,
        address indexed execAddress,
        bytes execData,
        bytes32 taskId,
        bool callSuccess
    );

    function exec(
        uint256 _txFee,
        address _feeToken,
        address _taskCreator,
        bool _useTaskTreasuryFunds,
        bool _revertOnFailure,
        bytes32 _resolverHash,
        address _execAddress,
        bytes calldata _execData
    ) external;

    function gelato() external view returns (address payable);

    function createTaskNoPrepayment(
        address _execAddress,
        bytes4 _execSelector,
        address _resolverAddress,
        bytes calldata _resolverData,
        address _feeToken
    ) external returns (bytes32 task);

    function cancelTask(bytes32 _taskId) external;

    function getFeeDetails() external view returns (uint256, address);

    function getResolverHash(
        address _resolverAddress,
        bytes memory _resolverData
    ) external pure returns (bytes32);

    function taskCreator(bytes32 _taskId) external view returns (address);
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
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
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
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

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
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

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