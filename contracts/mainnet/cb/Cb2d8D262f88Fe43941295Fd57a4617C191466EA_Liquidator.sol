// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../access/Governable.sol";
import "./IPikaPerp.sol";
import './IFundingManager.sol';
import './FundingManager.sol';
import "../oracle/IOracle.sol";
import '../lib/PerpLib.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// In PikaPerpV3 contract, the liquidatePosition function has an issue where the open interest can be decreased even if the position is not liquidatable.
// This contract is created to avoid that issue. The liquidateWithPrices and liquidatePosition functions in this contract are the only functions used for liquidation.
// The canLiquidate function has the same validation logic as those in PikaPerpV3, to make sure the position is truly liquidatble if the validation passes,
// so that the open interest in PikaPerpV3 can only be decreased if the position is truly liquidated. This contract is set as the only liquidator address for PikaPerpV3.
contract Liquidator is Governable {

    address public owner;
    address public pikaPerp;
    address public rewardToken;
    address public priceFeed;
    address public fundingManager;
    // a forever locked timelock account that was used one time to open positions to correct the totalOpenInterest in PikaPerpV3 and this account should never be liquidated
    address public immutable lockedAccount;
    bool public allowPublicLiquidator;
    uint256[] positionIds;
    mapping (address => bool) public isKeeper;
    mapping (address => bool) public isLiquidator;
    uint256 private constant BASE = 10**8;
    uint256 private constant FUNDING_BASE = 10**12;

    event NotLiquidate(uint256 positionId);
    event RewardWithdraw(address indexed receiver, uint256 rewardAmount);
    event PikaPerpSet(address pikaPerp);
    event RewardTokenSet(address rewardToken);
    event PriceFeedSet(address priceFeed);
    event FundingManagerSet(address fundingManager);
    event AllowPublicLiquidatorSet(bool allowPublicLiquidator);
    event UpdateKeeper(address keeper, bool isAlive);
    event UpdateLiquidator(address liquidator, bool isAlive);
    event UpdateOwner(address owner);

    constructor(address _pikaPerp, address _rewardToken, address _priceFeed, address _fundingManager, address _lockedAccount) public {
        owner = msg.sender;
        pikaPerp = _pikaPerp;
        rewardToken = _rewardToken;
        priceFeed = _priceFeed;
        fundingManager = _fundingManager;
        lockedAccount = _lockedAccount;
    }

    function liquidateWithPrices(
        address[] memory tokens,
        uint256[] memory prices,
        address[] calldata accounts,
        uint256[] calldata productIds,
        bool[] calldata isLongs)
    external onlyKeeper {
        IOracle(priceFeed).setPrices(tokens, prices);
        liquidatePositions(accounts, productIds, isLongs);
    }

    function liquidatePositions(address[] calldata accounts, uint256[] calldata productIds, bool[] calldata isLongs) public {
        require(isLiquidator[msg.sender] || allowPublicLiquidator, "!liquidator");
        for (uint256 i = 0; i < accounts.length; i++) {
            if (canLiquidate(accounts[i], productIds[i], isLongs[i])) {
                positionIds.push(getPositionId(accounts[i], productIds[i], isLongs[i]));
            } else {
                emit NotLiquidate(getPositionId(accounts[i], productIds[i], isLongs[i]));
            }
        }
        IPikaPerp(pikaPerp).liquidatePositions(positionIds);
        delete positionIds;
    }

    function liquidatePosition(address account, uint256 productId, bool isLong) external {
        require(isLiquidator[msg.sender] || allowPublicLiquidator, "!liquidator");
        require(canLiquidate(account, productId, isLong), "!liquidate");
        positionIds.push(getPositionId(account, productId, isLong));
        IPikaPerp(pikaPerp).liquidatePositions(positionIds);
        delete positionIds;
    }

    function canLiquidate(address account, uint256 productId, bool isLong) public returns(bool) {
        if (account == lockedAccount) {
            return false;
        }
        (uint256 _productId,uint256 leverage,uint256 positionPrice,,uint256 margin,,,,int256 funding) = IPikaPerp(pikaPerp).getPosition(account, productId, isLong);
        if (_productId == 0) {
            return false;
        }
        (address productToken,,,,,,,,) = IPikaPerp(pikaPerp).getProduct(productId);
        int256 fundingRate = IFundingManager(fundingManager).getFundingRate(productId);
        int256 fundingChange = fundingRate * int256(block.timestamp - FundingManager(fundingManager).lastUpdateTimes(productId)) / int256(365 days);
        int256 prevCumFunding = FundingManager(fundingManager).cumulativeFundings(productId);
        int256 cumulativeFunding = FundingManager(fundingManager).cumulativeFundings(productId) + fundingChange;
        int256 fundingPayment = _getFundingPayment(isLong, productId, leverage, margin, funding, cumulativeFunding);
        int256 pnl = PerpLib._getPnl(isLong, positionPrice, leverage, margin, IOracle(priceFeed).getPrice(productToken)) - fundingPayment;
        if (pnl >= 0 || uint256(-1 * pnl) < uint256(margin) * IPikaPerp(pikaPerp).liquidationThreshold() / (10**4)) {
            return false;
        }
        return true;
    }

    function _getFundingPayment(
        bool isLong,
        uint256 productId,
        uint256 positionLeverage,
        uint256 margin,
        int256 funding,
        int256 cumulativeFunding
    ) internal view returns(int256) {
        return isLong ? int256(margin * positionLeverage) * (cumulativeFunding - funding) / int256(BASE * FUNDING_BASE) :
        int256(margin * positionLeverage) * (funding - cumulativeFunding) / int256(BASE * FUNDING_BASE);
    }

    function getPositionId(
        address account,
        uint256 productId,
        bool isLong
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(account, productId, isLong)));
    }

    function withdrawReward(address receiver) external onlyOwner {
        uint256 rewardAmount = IERC20(rewardToken).balanceOf(address(this));
        IERC20(rewardToken).transfer(receiver, rewardAmount);
        emit RewardWithdraw(receiver, rewardAmount);
    }

    function setPikaPerp(address _pikaPerp) external onlyOwner {
        pikaPerp = _pikaPerp;
        emit PikaPerpSet(_pikaPerp);
    }

    function setRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = _rewardToken;
        emit RewardTokenSet(_rewardToken);
    }

    function setPriceFeed(address _priceFeed) external onlyOwner {
        priceFeed = _priceFeed;
        emit PriceFeedSet(_priceFeed);
    }

    function setFundingManager(address _fundingManager) external onlyOwner {
        fundingManager = _fundingManager;
        emit FundingManagerSet(_fundingManager);
    }

    function setAllowPublicLiquidator(bool _allowPublicLiquidator) external onlyOwner {
        allowPublicLiquidator = _allowPublicLiquidator;
        emit AllowPublicLiquidatorSet(_allowPublicLiquidator);
    }

    function setOwner(address _owner) external onlyGov {
        owner = _owner;
        emit UpdateOwner(_owner);
    }

    function setKeeper(address _account, bool _isActive) external onlyOwner {
        isKeeper[_account] = _isActive;
        emit UpdateKeeper(_account, _isActive);
    }

    function setLiquidator(address _account, bool _isActive) external onlyOwner {
        isLiquidator[_account] = _isActive;
        emit UpdateLiquidator(_account, _isActive);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Liquidator: !owner");
        _;
    }

    modifier onlyKeeper() {
        require(isKeeper[msg.sender], "Liquidator: !keeper");
        _;
    }

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Governable {
    address public gov;

    constructor() public {
        gov = msg.sender;
    }

    modifier onlyGov() {
        require(msg.sender == gov, "Governable: forbidden");
        _;
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }
}

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPikaPerp {
    function getTotalShare() external view returns(uint256);
    function getShare(address stakeOwner) external view returns(uint256);
    function distributeProtocolReward() external returns(uint256);
    function distributePikaReward() external returns(uint256);
    function distributeVaultReward() external returns(uint256);
    function getPendingPikaReward() external view returns(uint256);
    function getPendingProtocolReward() external view returns(uint256);
    function getPendingVaultReward() external view returns(uint256);
    function stake(uint256 amount, address user) external payable;
    function redeem(uint256 shares) external;
    function openPosition(
        address user,
        uint256 productId,
        uint256 margin,
        bool isLong,
        uint256 leverage
    ) external payable;
    function closePositionWithId(
        uint256 positionId,
        uint256 margin
    ) external;
    function closePosition(
        address user,
        uint256 productId,
        uint256 margin,
        bool isLong
    ) external;
    function liquidatePositions(uint256[] calldata positionIds) external;
    function getProduct(uint256 productId) external view returns (
        address,uint256,uint256,bool,uint256,uint256,uint256,uint256,uint256);
    function getPosition(
        address account,
        uint256 productId,
        bool isLong
    ) external view returns (uint256,uint256,uint256,uint256,uint256,address,uint256,bool,int256);
    function getMaxExposure(uint256 productWeight) external view returns(uint256);
    function getCumulativeFunding(uint256 _productId) external view returns(uint256);
    function liquidationThreshold() external view returns(uint256);
}

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IFundingManager {
    function updateFunding(uint256) external;
    function getFunding(uint256) external view returns(int256);
    function getFundingRate(uint256) external view returns(int256);
}

pragma solidity ^0.8.0;

import "./IPikaPerp.sol";
import "../access/Governable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";

contract FundingManager is Governable {

    address public pikaPerp;
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    event UpdateOwner(address owner);

    uint256 constant public FUNDING_BASE = 10**12;
    uint256 public maxFundingRate = 10 * FUNDING_BASE;
    uint256 public minFundingMultiplier = 2 * FUNDING_BASE;
    mapping(uint256 => uint256) public fundingMultipliers;
    mapping(uint256 => int256) public cumulativeFundings;
    mapping(uint256 => uint256) public lastUpdateTimes;

    event FundingUpdated(uint256 productId, int256 fundingRate, int256 fundingChange, int256 cumulativeFunding);
    event PikaPerpSet(address pikaPerp);
    event MinFundingMultiplierSet(uint256 minFundingMultiplier);
    event FundingMultiplierSet(uint256 productId, uint256 fundingMultiplier);
    event MaxFundingRateSet(uint256 maxFundingRate);

    function updateFunding(uint256 _productId) external {
        require(msg.sender == pikaPerp, "FundingManager: !pikaPerp");
        if (lastUpdateTimes[_productId] == 0) {
            lastUpdateTimes[_productId] = block.timestamp;
            return;
        }
        int256 fundingRate = getFundingRate(_productId);
        int256 fundingChange = fundingRate * int256(block.timestamp - lastUpdateTimes[_productId]) / int256(365 days);
        cumulativeFundings[_productId] = cumulativeFundings[_productId] + fundingChange;
        lastUpdateTimes[_productId] = block.timestamp;
        emit FundingUpdated(_productId, fundingRate, fundingChange, cumulativeFundings[_productId]);
    }

    function getFundingRate(uint256 _productId) public view returns(int256) {
        (,,,,uint256 openInterestLong, uint256 openInterestShort,,uint256 productWeight,) = IPikaPerp(pikaPerp).getProduct(_productId);
        uint256 maxExposure = IPikaPerp(pikaPerp).getMaxExposure(productWeight);
        uint256 fundingMultiplier = Math.max(fundingMultipliers[_productId], minFundingMultiplier);
        if (openInterestLong > openInterestShort) {
            return int256(Math.min((openInterestLong - openInterestShort) * fundingMultiplier / maxExposure, maxFundingRate));
        } else {
            return -1 * int256(Math.min((openInterestShort - openInterestLong) * fundingMultiplier / maxExposure, maxFundingRate));
        }
    }

    function getFunding(uint256 _productId) external view returns(int256) {
        return cumulativeFundings[_productId];
    }

    function setPikaPerp(address _pikaPerp) external onlyOwner {
        pikaPerp = _pikaPerp;
        emit PikaPerpSet(_pikaPerp);
    }

    function setMinFundingMultiplier(uint256 _minFundingMultiplier) external onlyOwner {
        minFundingMultiplier = _minFundingMultiplier;
        emit MinFundingMultiplierSet(_minFundingMultiplier);
    }

    function setFundingMultiplier(uint256 _productId, uint256 _fundingMultiplier) external onlyOwner {
        fundingMultipliers[_productId] = _fundingMultiplier;
        emit FundingMultiplierSet(_productId, _fundingMultiplier);
    }

    function setMaxFundingRate(uint256 _maxFundingRate) external onlyOwner {
        maxFundingRate = _maxFundingRate;
        emit MaxFundingRateSet(_maxFundingRate);
    }

    function setOwner(address _owner) external onlyGov {
        owner = _owner;
        emit UpdateOwner(_owner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "FundingManager: !owner");
        _;
    }

}

pragma solidity ^0.8.0;

interface IOracle {
    function getPrice(address feed) external view returns (uint256);
    function getPrice(address token, bool isMax) external view returns (uint256);
    function getLastNPrices(address token, uint256 n) external view returns(uint256[] memory);
    function setPrices(address[] memory tokens, uint256[] memory prices) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../oracle/IOracle.sol";
import '../perp/IFeeCalculator.sol';
import '../perp/IFundingManager.sol';

library PerpLib {
    uint256 private constant BASE = 10**8;
    uint256 private constant FUNDING_BASE = 10**12;

    function _canTakeProfit(
        bool isLong,
        uint256 positionTimestamp,
        uint256 positionOraclePrice,
        uint256 oraclePrice,
        uint256 minPriceChange,
        uint256 minProfitTime
    ) internal view returns(bool) {
        if (block.timestamp > positionTimestamp + minProfitTime) {
            return true;
        } else if (isLong && oraclePrice > positionOraclePrice * (10**4 + minPriceChange) / (10**4)) {
            return true;
        } else if (!isLong && oraclePrice < positionOraclePrice * (10**4 - minPriceChange) / (10**4)) {
            return true;
        }
        return false;
    }

    function _getPnl(
        bool isLong,
        uint256 positionPrice,
        uint256 positionLeverage,
        uint256 margin,
        uint256 price
    ) internal view returns(int256 _pnl) {
        bool pnlIsNegative;
        uint256 pnl;
        if (isLong) {
            if (price >= positionPrice) {
                pnl = margin * positionLeverage * (price - positionPrice) / positionPrice / BASE;
            } else {
                pnl = margin * positionLeverage * (positionPrice - price) / positionPrice / BASE;
                pnlIsNegative = true;
            }
        } else {
            if (price > positionPrice) {
                pnl = margin * positionLeverage * (price - positionPrice) / positionPrice / BASE;
                pnlIsNegative = true;
            } else {
                pnl = margin * positionLeverage * (positionPrice - price) / positionPrice / BASE;
            }
        }

        if (pnlIsNegative) {
            _pnl = -1 * int256(pnl);
        } else {
            _pnl = int256(pnl);
        }

        return _pnl;
    }

    function _getFundingPayment(
        address fundingManager,
        bool isLong,
        uint256 productId,
        uint256 positionLeverage,
        uint256 margin,
        int256 funding
    ) internal view returns(int256) {
        return isLong ? int256(margin * positionLeverage) * (IFundingManager(fundingManager).getFunding(productId) - funding) / int256(BASE * FUNDING_BASE) :
            int256(margin * positionLeverage) * (funding - IFundingManager(fundingManager).getFunding(productId)) / int256(BASE * FUNDING_BASE);
    }

    function _getTradeFee(
        uint256 margin,
        uint256 leverage,
        uint256 productFee,
        address productToken,
        address user,
        address sender,
        address feeCalculator
    ) internal view returns(uint256) {
        uint256 fee = IFeeCalculator(feeCalculator).getFee(productToken, productFee, user, sender);
        return margin * leverage / BASE * fee / 10**4;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

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
// OpenZeppelin Contracts (last updated v4.5.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a / b + (a % b == 0 ? 0 : 1);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/SignedSafeMath.sol)

pragma solidity ^0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SignedSafeMath` is no longer needed starting with Solidity 0.8. The compiler
 * now has built in overflow checking.
 */
library SignedSafeMath {
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
        return a * b;
    }

    /**
     * @dev Returns the integer division of two signed integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(int256 a, int256 b) internal pure returns (int256) {
        return a / b;
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
        return a - b;
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
        return a + b;
    }
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeeCalculator {
    function getFee(address token, uint256 productFee, address user, address sender) external view returns (uint256);
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