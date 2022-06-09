// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StrategyStorage.sol";
import "../interfaces/IStrategy.sol";

contract DeltaNeutralPerp is StrategyStorage, IStrategy {

    int256 private _depositsSinceLastCharge; // todo del
    int256 private _withdrawalsSinceLastCharge; //  todo del
    int256 private _lastTotal; //  todo del

    uint32 internal _performanceFee; // fee charged every day by trigger server; 1e6
    uint32 internal _subscriptionFee; // fee charged once on deposit; 1e6

    uint32 internal constant _DAILY_SECONDS = 60 * 60 * 24; //  todo del
    uint32 internal constant _W_TOKEN_VALUE = 45; // current wToken value
    uint32 internal constant _SHORT_VALUE = 45; // current Short position in Perpetual.finance
    uint32 internal constant _RESERVE_VALUE = 10; // current reserve

    uint256 private _lastPfChargeTime; //  todo del
    uint256 private _depositLimit; //  todo del

    IClearingHouse internal _perp;
    IVault internal _perpVault;

    mapping(address => bool) private _allowList; //  todo del
    mapping(address => uint256) private _depositAmount; //  todo del

    // __gap is reserved storage
    uint256[50] private __gap;

    uint256 public maxPoolSizeLimit; //  todo del

    uint256 private maxUsersPoolSizeLimit;
    uint256 public maxDaoListPoolSizeLimit; //  todo del
    uint256 public currentDaoDeposits; //  todo del
    uint256 private currentCasualDeposits;

    mapping(address => bool) private _daoMembersList; //  todo del

    bytes32 public perpReferralCode;

    /**
    * @dev Sets the addresses for USDC stableCoin, triggerServer, deCommas Pool Token,
    * UniswapRouter, Perpetual ClearingHouse, Perpetual Vault(AccountBalance contract), Perpetual vToken for Strategy,
    * initialize to base shares for position
    */
    function initialize(address _usdc,
        address router_,
        address wToken_,
        address vToken_,
        IClearingHouse perp_,
        IVault perpVault_,
        address _triggerServer,
        uint32 performanceFee_,
        uint32 subscriptionFee_) public {
        __Ownable_init();
        _usdToken = _usdc;
        _router = router_;
        // UniSwap Router
        _wToken = wToken_;
        // wToken implementation for chain
        _vToken = vToken_;
        // perpBaseToken
        _perp = perp_;
        // Perpetual Clearing House
        _perpVault = perpVault_;
        triggerServer = _triggerServer;
        _performanceFee = performanceFee_;
        _subscriptionFee = subscriptionFee_;

        _lastPfChargeTime = 0;
        _lastTotal = 0;
        _depositsSinceLastCharge = 0;
        _withdrawalsSinceLastCharge = 0;

        _deadlineTime = 300;
        _feeToPair = 500;
        _sqrtPriceLimitX96toUni = 0;

        IERC20(_usdToken).approve(address(_router), type(uint256).max);
        IERC20(_usdToken).approve(address(_perpVault), type(uint256).max);
        IERC20(_wToken).approve(address(_router), type(uint256).max);
    }


    /**
    * @dev User can to deposit her USDC for strategy
    * @param amount USDC token amount
    * @notice deposit USDC to the strategy. User will receive LP tokens proportionally to the pool share
    */
    function depositUSDC(uint256 amount) public override {
        require(amount != 0, "DNP: zero amount");

        require(currentCasualDeposits + amount <= maxUsersPoolSizeLimit, "DNP: Exceeding poolLimit");
        currentCasualDeposits += amount;

        uint256 tvl = getTotalUSDCValue();
        uint256 mintingAmount = amount * 1e12;
        // user get token amount equal to USDC amount
        if (tvl > 100000) {
            uint256 share = Math.mulDiv(amount, 1e18, tvl);
            mintingAmount = Math.mulDiv(share, IdcToken(_dcToken).totalSupply(), 1e18);
        }

        require(IERC20(_usdToken).transferFrom(_msgSender(), address(this), amount), "DNP: usdc transfer failed");

        IdcToken(_dcToken).mint(_msgSender(), mintingAmount);
        emit USDCDeposited(_msgSender(), amount, mintingAmount);
    }


    /**
    * @dev User can to withdraw her USDC from strategy
    * @param amount dCommas Pool Token user's amount
    * @notice withdraw USDC from the strategy. `Amount` of LP tokens will be burned.
    */
    function withdrawUSDC(uint256 amount) public override {
        require(amount != 0, "DNP: zero amount");
        require(amount <= IdcToken(_dcToken).balanceOf(_msgSender()), "DNP: insufficient tokens");
        uint256 poolShare = Math.mulDiv(amount, 1e18, IdcToken(_dcToken).totalSupply());
        uint256 result = Math.mulDiv(getTotalUSDCValue(), poolShare, 1e18);
        require(result <= getTotalUSDCValue(), "DNP: trying to withdraw more than pool contains");

        if (getReserve() < result) {
            _closePositionsForWithdrawal(getReserve(), result);
        }
        if (result >= currentCasualDeposits) {
            currentCasualDeposits = 0;
        } else {
            currentCasualDeposits -= result;
        }
        require(IdcToken(_dcToken).transferFrom(_msgSender(), address(this), amount), "DNP: dcToken transfer failed");
        IdcToken(_dcToken).burn(amount);

        require(IERC20(_usdToken).transfer(_msgSender(), result), "DNP: usdc transfer failed");
        emit USDCWithdrawn(_msgSender(), result);
    }

    function setDcToken(address dcToken_) public onlyOwner {
        _dcToken = dcToken_;
        // dCommas Pool Token
    }

    function setPoolLimit(uint256 _newLimit) public onlyOwner {
        require(_newLimit != 0, "DNP: zero amount");
        maxUsersPoolSizeLimit = _newLimit;
    }

    function approveUSDC() external onlyTrigger {
        IERC20(_usdToken).approve(address(_router), type(uint256).max);
        IERC20(_usdToken).approve(address(_perpVault), type(uint256).max);
    }

    /**
    * @dev TriggerServer manipulate to position in Perpetual.ClearingHouse
    * @param operationType true for openPosition / false for closePosition
    * @param positionType true for shorting the base token asset, false for longing the base token asset
    * @param amount how USDC need for position
    * Can only be called by the current TriggerServer
    */
    function adjustPosition(bool operationType, bool positionType, uint256 amount) public override onlyTrigger() {
        require(amount != 0, "DNP: zero amount");
        //        uint256 wTokenToReserveProportion = Math.mulDiv(_RESERVE_VALUE, 100, _W_TOKEN_VALUE);
        //        uint256 wTokenAmountUSDC = Math.mulDiv(IERC20(_wToken).balanceOf(address(this)),
        //                                                    _nativeStrategyTokenPrice(0), 1e30);
        // Shows how much USDC should be on reserve to maintain proportion
        //        uint256 strategyReserve = Math.mulDiv(wTokenAmountUSDC, wTokenToReserveProportion, 100);

        //        if (wTokenAmountUSDC > 0 && operationType && positionType) {
        //            require(getReserve() - amount <= strategyReserve, "DNP: Proportion break");
        //        }

        if (operationType) {// openPosition
            uint256 usdcAmount = _calculateAmountToPosition(amount, _SHORT_VALUE);
            /// short/buy wToken
            if (positionType) {
                require(getReserve() >= amount, "DNP: Insufficient reserve");
                _buyTokensToUniswap(_usdToken, _wToken, usdcAmount);
                _depositToVault(usdcAmount);
                _openPosition(usdcAmount * 1e12, positionType);
                emit PositionAdjusted(operationType,
                    positionType,
                    usdcAmount,
                    usdcAmount);
            } else {
                /// long/sell wToken
                if (Math.mulDiv(IERC20(_wToken).balanceOf(address(this)),
                    _nativeStrategyTokenPrice(0), 1e18) < usdcAmount) {
                    _fullClose();
                } else {
                    _sellTokensToUniswap(_wToken, _usdToken, usdcAmount,
                        IERC20(_wToken).balanceOf(address(this)));
                    _openPosition(usdcAmount, positionType);
                    _withdrawFromPerp(usdcAmount);
                    emit PositionAdjusted(operationType,
                        positionType,
                        usdcAmount,
                        usdcAmount);
                }
            }
        } else {
            _fullClose();
        }
    }


    function directClosePosition(uint256 amount) public onlyTrigger() {
        _closePosition(amount);
    }


    function directBuyTokensToUniswap(address tokenA, address tokenB, uint256 amount) public onlyTrigger() {
        _buyTokensToUniswap(tokenA, tokenB, amount);
    }


    function directWithdrawUSDCtoPerpVault(uint256 amount) public onlyTrigger() {
        _withdrawFromPerp(amount);
    }


    function directDepositToVault(uint256 amount) public onlyTrigger() {
        _depositToVault(amount);
    }


    function directOpenPosition(uint256 amount, bool position) public onlyTrigger() {
        _openPosition(amount, position);
    }


    // Migrate Contract funds to new address
    function migrate(address newContract) public onlyTrigger {
        //forbid to enter this pool
        maxUsersPoolSizeLimit = 0;
        _fullClose();
        require(IERC20(_usdToken).transfer(newContract, IERC20(_usdToken).balanceOf(address(this))),
            "DNP: usdc transfer failed");
    }

    function setPerpRefCode(uint256 code) public onlyTrigger {
        perpReferralCode = bytes32(code);

        emit PerpReferralCodeChanged(perpReferralCode);
    }

    /**
    * @notice Strategy worth nominated in the USDC
    */
    function getTotalUSDCValue() public view override returns (uint256) {
        return _abs(_perp.getAccountValue(address(this))) / 1e12 +
        getReserve() +
        Math.mulDiv(IERC20(_wToken).balanceOf(address(this)),
            _nativeStrategyTokenPrice(0), 1e18);
    }


    /**
    * @dev returns linked token current price
    * @return price in USDC (1e6)
    * @notice LP token price.
     */
    function getDCTokenPrice() public view override returns (uint256) {
        if (IdcToken(_dcToken).totalSupply() == 0) {
            return 0;
        }
        return Math.mulDiv(getTotalUSDCValue(), 1e18, IdcToken(_dcToken).totalSupply());
    }


    /**
    * @notice USDC on the strategy balance
    */
    function getReserve() public view override returns (uint256) {
        return (IERC20(_usdToken).balanceOf(address(this)));
    }


    /**
    * @dev if funding rate is more than 1 => long positions pays to short
    * vise versa otherwise
    * @return fundingRate_10_6
    * @notice Current funding rate for the perpV2
     */
    function getCurrentFundingRate() public view override returns (uint256) {
        uint256 dailyMarketTwap = getDailyMarketTwap() / 1e12;
        uint256 dailyIndexTwap = _nativeStrategyTokenPrice(60 * 60);
        // 1 hour

        return Math.mulDiv(dailyMarketTwap, 1e6, dailyIndexTwap);
    }

    /**
    * @notice Total pool limit for all users
     */
    function poolLimit() public view override returns (uint256) {
        return maxUsersPoolSizeLimit;
    }

    /**
    * @notice Total deposit amount
     */
    function currentDeposits() public view override returns (uint256) {
        return currentCasualDeposits;
    }

    /// DEBUG
    function getDailyMarketTwap() public view returns (uint256) {
        uint160 dailyMarketTwap160X96 = IExchange(_perp.getExchange()).getSqrtMarkTwapX96(_vToken, 60 * 60 * 1);
        uint256 dailyMarketTwapX96 = Math.formatSqrtPriceX96ToPriceX96(dailyMarketTwap160X96);
        return Math.formatX96ToX10_18(dailyMarketTwapX96);
    }

    function _fullClose() private {
        _closePosition(0);
        _withdrawFromPerp(_perpVault.getFreeCollateral(address(this)));
        if (IERC20(_wToken).balanceOf(address(this)) > 0) {
            _buyTokensToUniswap(_wToken, _usdToken, IERC20(_wToken).balanceOf(address(this)));
        }
        emit PositionAdjusted(false, false, IERC20(_usdToken).balanceOf(address(this)), 0);
    }


    function _depositToVault(uint256 amount) private {
        require(amount != 0, "DNP: zero amount");
        //deposit to AccountBalance
        _perpVault.deposit(_usdToken, amount);
    }


    function _closePositionsForWithdrawal(uint256 reserve, uint256 toWithdraw) private {
        uint256 toClose = toWithdraw - reserve;
        // add 10% and take a half to close both positions
        toClose = (toClose + toClose / 10) / 2;
        uint256 wTokenAmount = Math.mulDiv(toClose, 1e18, _nativeStrategyTokenPrice(0));

        if (toClose > getTotalUSDCValue() / 2 ||
            wTokenAmount > IERC20(_wToken).balanceOf(address(this))) {
            _fullClose();
        } else {
            _sellTokensToUniswap(_wToken, _usdToken, toClose, IERC20(_wToken).balanceOf(address(this)));
            _openPosition(wTokenAmount, false);
            _withdrawFromPerp(toClose);
        }
    }


    function _withdrawFromPerp(uint256 amount) private {
        _perpVault.withdraw(_usdToken, amount);
    }


    /**
       * @dev amount should be in 1e18
    */
    function _openPosition(uint256 amount, bool positionType) private returns (bool) {
        // use positionType for isBaseToQuote(true = short, false = long), isExactInput (),  amount ()
        // Open Perp position
        _perp.openPosition(
            IClearingHouse.OpenPositionParams({
        baseToken : _vToken,
        isBaseToQuote : positionType, //true for shorting the baseTokenAsset, false for long the baseTokenAsset
        isExactInput : false, // for specifying exactInput or exactOutput ; similar to UniSwap V2's specs
        amount : amount, // Depending on the isExactInput param, this can be either the input or output
        oppositeAmountBound : 0,
        deadline : block.timestamp + _deadlineTime,
        sqrtPriceLimitX96 : _sqrtPriceLimitX96toUni,
        referralCode : perpReferralCode
        })
        );
        return true;
    }


    /**
    * @dev Close full position in Perpetual
  */
    function _closePosition(uint256 _amount) private returns (bool) {
        _perp.closePosition(
            IClearingHouse.ClosePositionParams({
        baseToken : _vToken,
        sqrtPriceLimitX96 : _sqrtPriceLimitX96toUni,
        oppositeAmountBound : _amount,
        deadline : block.timestamp + _deadlineTime,
        referralCode : perpReferralCode
        })
        );
        return true;
    }


    function _nativeStrategyTokenPrice(uint256 interval) private view returns (uint256) {// wBTC, wETH or other
        return IIndexPrice(_vToken).getIndexPrice(interval) / 1e12;
    }


    function _abs(int256 value) private pure returns (uint256) {
        return value >= 0 ? uint256(value) : uint256(- value);
    }


    function _calculateAmountToPosition(uint256 amount, uint256 share) private pure returns (uint256) {
        return (amount * share) / 100;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Math.sol";

import "../interfaces/IdcToken.sol";
import "../integrations/perpetual/IVault.sol";
import "../integrations/perpetual/IExchange.sol";
import "../integrations/uniswap/IV3SwapRouter.sol";
import "../integrations/perpetual/IIndexPrice.sol";
import "../integrations/perpetual/IClearingHouse.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract StrategyStorage is OwnableUpgradeable {

    uint24 internal _feeToPair;
    uint160 internal _deadlineTime;
    uint160 internal _sqrtPriceLimitX96toUni;

    address internal _router;
    address internal _dcToken;
    address internal _usdToken; // baseToken - usdc
    address internal _wToken; // wrapped Native Token
    address internal _vToken; /// Native Strategy Perp Token

    address public escrowServer;
    address public triggerServer;

    modifier onlyTrigger() {
        require(triggerServer == _msgSender(), "StrategyStorage: caller is not trigger");
        _;
    }


    function setTriggerServer(address _newTriggerServer) public onlyOwner {
        require(_newTriggerServer != (address(0x0)), "StrategyStorage: zero address");
        triggerServer = _newTriggerServer;
    }


    function setEscrow(address _newEscrow) public onlyOwner {
        require(_newEscrow != address(0x0), "StrategyStorage: zero address");
        escrowServer = _newEscrow;
    }


    function setVToken(address newVToken) public onlyOwner {
        _vToken = newVToken;
    }


    function emergencyWithdraw(IERC20 _token) public onlyOwner {
        require(escrowServer != address(0x0), "StrategyStorage: zero address");
        require(_token.transfer(escrowServer, _token.balanceOf(address(this))), "DNP: ERC20 transfer failed");
    }


    function approveTokenForUni(IERC20 token, uint256 amount) public onlyOwner {
        token.approve(_router, amount);
    }


    function _buyTokensToUniswap(address _tokenA, address _tokenB, uint256 amount) internal {
        IV3SwapRouter(_router).exactInputSingle(IV3SwapRouter.ExactInputSingleParams({
            tokenIn: _tokenA,
            tokenOut: _tokenB,
            fee: _feeToPair,
            recipient: address(this),
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: _sqrtPriceLimitX96toUni
        }));
    }


    // We want to sell `tokenA` for `tokenB` and receive `amount` of `tokenB`
    // We want to spend no more than `amountInMaximum` of tokenA
    function _sellTokensToUniswap(address _tokenA, address _tokenB, uint256 amount, uint256 amountInMaximum) internal {
        IV3SwapRouter(_router).exactOutputSingle(IV3SwapRouter.ExactOutputSingleParams({
        tokenIn: _tokenA,
        tokenOut: _tokenB,
        fee: _feeToPair,
        recipient: address(this),
        amountOut: amount,
        amountInMaximum: amountInMaximum,
        sqrtPriceLimitX96: _sqrtPriceLimitX96toUni
        }));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStrategy {

    /**
    * Events
    */

    event USDCDeposited(address indexed user,
        uint256 usdcAmount,
        uint256 indexed dcMintingAmount);

    event USDCWithdrawn(address indexed user, uint256 usdcAmount);

    event PositionAdjusted(bool indexed operationType, bool indexed positionType, uint256 usdcValue, uint256 wValue);

    event PFCharged(address indexed triger, uint256 pfAmount);

    event DepositAllowed(address indexed user);

    event PerpReferralCodeChanged(bytes32 newCode);

    /**
    * Methods
    */

    function depositUSDC(uint256 amount) external;

    function withdrawUSDC(uint256 amount) external;

    function adjustPosition(bool operationType, bool positionType, uint256 amount) external;

    /**
    * View
    */

    function getCurrentFundingRate() external view returns (uint256);

    function getTotalUSDCValue() external view returns (uint256);

    function getDCTokenPrice() external view returns (uint256);

    function getReserve() external view returns (uint256);

    function poolLimit() external view returns (uint256);

    function currentDeposits() external view returns (uint256);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import { FixedPoint96 } from "../integrations/lib/FixedPoint96.sol";

library Math {

    function fullMul(uint256 x, uint256 y) internal pure returns (uint256 l, uint256 h) {
    unchecked{
        uint256 mm = mulmod(x, y, type(uint256).max);
        l = x * y;
        h = mm - l;
        if (mm < l) h -= 1;
    }
    }

    function fullDiv(
        uint256 l,
        uint256 h,
        uint256 d
    ) private pure returns (uint256) {
    unchecked {
        uint256 pow2 = d & (~d + 1);
        d /= pow2;
        l /= pow2;
        l += h * ((~pow2 + 1) / pow2 + 1);
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
    }

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256) {
        (uint256 l, uint256 h) = fullMul(x, y);

    unchecked {
        uint256 mm = mulmod(x, y, d);
        if (mm > l) h -= 1;
        l -= mm;

        if (h == 0) return l / d;

        require(h < d, "FullMath: FULLDIV_OVERFLOW");
        return fullDiv(l, h, d);
    }
    }

    function formatSqrtPriceX96ToPriceX96(uint160 sqrtPriceX96) internal pure returns (uint256) {
        return Math.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
    }

    /*
    function formatX10_18ToX96(uint256 valueX10_18) internal pure returns (uint256) {
        return Math.mulDiv(valueX10_18, FixedPoint96.Q96, 1 ether);
    } */

    function formatX96ToX10_18(uint256 valueX96) internal pure returns (uint256) {
        return Math.mulDiv(valueX96, 1 ether, FixedPoint96.Q96);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IdcToken {

    function mint(address _to, uint256 _amount) external returns(bool);

    function burn(uint256 _amount) external returns(bool);

    function addGovernance(address _member) external;

    function removeGovernance(address _member) external;

    function isGovernance(address governance_) external;

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function pause() external;

    function unpause() external;

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IVault {
    event Deposited(address indexed collateralToken, address indexed trader, uint256 amount);

    event Withdrawn(address indexed collateralToken, address indexed trader, uint256 amount);

    /// @param token the address of the token to deposit;
    ///        once multi-collateral is implemented, the token is not limited to settlementToken
    /// @param amountX10_D the amount of the token to deposit in decimals D (D = _decimals)
    function deposit(address token, uint256 amountX10_D) external;

    /// @param token the address of the token sender is going to withdraw
    ///        once multi-collateral is implemented, the token is not limited to settlementToken
    /// @param amountX10_D the amount of the token to withdraw in decimals D (D = _decimals)
    function withdraw(address token, uint256 amountX10_D) external;

    function getBalance(address account) external view returns (int256);

    /// @param trader The address of the trader to query
    /// @return freeCollateral Max(0, amount of collateral available for withdraw or opening new positions or orders)
    function getFreeCollateral(address trader) external view returns (uint256);

    /// @dev there are three configurations for different insolvency risk tolerances: conservative, moderate, aggressive
    ///      we will start with the conservative one and gradually move to aggressive to increase capital efficiency
    /// @param trader the address of the trader
    /// @param ratio the margin requirement ratio, imRatio or mmRatio
    /// @return freeCollateralByRatio freeCollateral, by using the input margin requirement ratio; can be negative
    function getFreeCollateralByRatio(address trader, uint24 ratio) external view returns (int256);

    function getSettlementToken() external view returns (address);

    /// @dev cached the settlement token's decimal for gas optimization
    function decimals() external view returns (uint8);

    function getTotalDebt() external view returns (uint256);

    function getClearingHouseConfig() external view returns (address);

    function getAccountBalance() external view returns (address);

    function getInsuranceFund() external view returns (address);

    function getExchange() external view returns (address);

    function getClearingHouse() external view returns (address);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// Unneeded dependency, only for seetleFunding, which we don't use internally.
// import { Funding } from "../lib/Funding.sol";

interface IExchange {
    /// @param amount when closing position, amount(uint256) == takerPositionSize(int256),
    ///        as amount is assigned as takerPositionSize in ClearingHouse.closePosition()
    struct SwapParams {
        address trader;
        address baseToken;
        bool isBaseToQuote;
        bool isExactInput;
        bool isClose;
        uint256 amount;
        uint160 sqrtPriceLimitX96;
    }

    struct SwapResponse {
        uint256 base;
        uint256 quote;
        int256 exchangedPositionSize;
        int256 exchangedPositionNotional;
        uint256 fee;
        uint256 insuranceFundFee;
        int256 pnlToBeRealized;
        uint256 sqrtPriceAfterX96;
        int24 tick;
        bool isPartialClose;
    }

    struct SwapCallbackData {
        address trader;
        address baseToken;
        address pool;
        uint24 uniswapFeeRatio;
        uint256 fee;
    }

    struct RealizePnlParams {
        address trader;
        address baseToken;
        int256 base;
        int256 quote;
    }

    event FundingUpdated(address indexed baseToken, uint256 markTwap, uint256 indexTwap);

    event MaxTickCrossedWithinBlockChanged(address indexed baseToken, uint24 maxTickCrossedWithinBlock);

    /// @param accountBalance The address of accountBalance contract
    event AccountBalanceChanged(address accountBalance);

    function swap(SwapParams memory params) external returns (SwapResponse memory);

    function getMaxTickCrossedWithinBlock(address baseToken) external view returns (uint24);

    function getAllPendingFundingPayment(address trader) external view returns (int256);

    /// @dev this is the view version of _updateFundingGrowth()
    /// @return the pending funding payment of a trader in one market, including liquidity & balance coefficients
    function getPendingFundingPayment(address trader, address baseToken) external view returns (int256);

    function getSqrtMarkTwapX96(address baseToken, uint32 twapInterval) external view returns (uint160);

    function getPnlToBeRealized(RealizePnlParams memory params) external view returns (int256);

    function getOrderBook() external view returns (address);

    function getAccountBalance() external view returns (address);

    function getClearingHouseConfig() external view returns (address);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import './IUniswapV3SwapCallback.sol';

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface IV3SwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @dev Setting `amountIn` to 0 will cause the contract to look up its own balance,
    /// and swap the entire amount, enabling contracts to send tokens before calling this function.
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @dev Setting `amountIn` to 0 will cause the contract to look up its own balance,
    /// and swap the entire amount, enabling contracts to send tokens before calling this function.
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// that may remain in the router after the swap.
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// that may remain in the router after the swap.
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IIndexPrice {
    /// @dev Returns the index price of the token.
    /// @param interval The interval represents twap interval.
    function getIndexPrice(uint256 interval) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

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

    event ReferredPositionChanged(bytes32 indexed referralCode);

    event PositionLiquidated(
        address indexed trader,
        address indexed baseToken,
        uint256 positionNotional,
        uint256 positionSize,
        uint256 liquidationFee,
        address liquidator
    );

    /// @param base the amount of base token added (> 0) / removed (< 0) as liquidity; fees not included
    /// @param quote the amount of quote token added ... (same as the above)
    /// @param liquidity the amount of liquidity unit added (> 0) / removed (< 0)
    /// @param quoteFee the amount of quote token the maker received as fees
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

    /// @param fundingPayment > 0: payment, < 0 : receipt
    event FundingPaymentSettled(address indexed trader, address indexed baseToken, int256 fundingPayment);

    event TrustedForwarderChanged(address indexed forwarder);

    /// @dev tx will fail if adding base == 0 && quote == 0 / liquidity == 0
    function addLiquidity(AddLiquidityParams calldata params) external returns (AddLiquidityResponse memory);

    function removeLiquidity(RemoveLiquidityParams calldata params) external returns
                                                            (RemoveLiquidityResponse memory response);

    function settleAllFunding(address trader) external;

    function openPosition(OpenPositionParams memory params) external returns (uint256 base, uint256 quote);

    function closePosition(ClosePositionParams calldata params) external returns (uint256 base, uint256 quote);

    function liquidate(address trader, address baseToken) external;

    function cancelExcessOrders(
        address maker,
        address baseToken,
        bytes32[] calldata orderIds
    ) external;

    function cancelAllExcessOrders(address maker, address baseToken) external;

    /// @dev accountValue = totalCollateralValue + totalUnrealizedPnl, in 18 decimals
    function getAccountValue(address trader) external view returns (int256);

    function getQuoteToken() external view returns (address);

    function getUniswapV3Factory() external view returns (address);

    function getClearingHouseConfig() external view returns (address);

    function getVault() external view returns (address);

    function getExchange() external view returns (address);

    function getOrderBook() external view returns (address);

    function getAccountBalance() external view returns (address);

    function getInsuranceFund() external view returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
// OpenZeppelin Contracts v4.4.0 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title Callback for IUniswapV3PoolActions#swap
/// @notice Any contract that calls IUniswapV3PoolActions#swap must implement this interface
interface IUniswapV3SwapCallback {
    /// @notice Called to `msg.sender` after executing a swap via IUniswapV3Pool#swap.
    /// @dev In the implementation you must pay the pool tokens owed for the swap.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// amount0Delta and amount1Delta can both be 0 if no tokens were swapped.
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token0 to the pool.
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token1 to the pool.
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
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
}