// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";

import "./interfaces/IVault.sol";
import "./interfaces/IFeeUtils.sol";
import "./interfaces/IFeeUtilsV2.sol";

contract FeeUtilsV2 is IFeeUtils, IFeeUtilsV2 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Position {
        uint256 size;
        uint256 collateral;
        uint256 averagePrice;
        uint256 entryRolloverRate;
        uint256 reserveAmount;
        int256 realisedPnl;
        uint256 lastIncreasedTime;
    }

    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant ROLLOVER_RATE_PRECISION = 1000000;
    uint256 public constant PRICE_PRECISION = 10 ** 30;
    uint256 public constant MAX_FEE_BASIS_POINTS = 500; // 5%
    uint256 public constant MAX_PROFIT_FEE_BASIS_POINTS = 5000; // 50%
    uint256 public constant MAX_LIQUIDATION_FEE_USD = 100 * PRICE_PRECISION; // 100 USD
    uint256 public constant MIN_ROLLOVER_RATE_INTERVAL = 1 hours;
    uint256 public constant MAX_ROLLOVER_RATE_FACTOR = 10000; // 1%

    bool public override isInitialized;

    IVault public vault;
    address public override gov;

    uint256 public override feeMultiplierIfInactive = 10; // 10x
    bool public override isActive = false;

    uint256 public override liquidationFeeUsd;
    mapping (address => uint256) public override taxBasisPoints;
    mapping (address => uint256) public override mintBurnFeeBasisPoints;
    mapping (address => uint256) public override swapFeeBasisPoints;

    mapping (address => uint256[]) public override relativePnlLists;
    mapping (address => uint256[]) public override positionFeeBasisPointsLists;
    mapping (address => uint256[]) public override profitFeeBasisPointsLists;

    bool public override hasDynamicFees = false;

    uint256 public override rolloverInterval = 8 hours;
    mapping (address => uint256) public override rolloverRateFactors;

    // cumulativeRolloverRates tracks the rollover rates based on utilization
    mapping(address => uint256) public override cumulativeRolloverRates;
    // lastRolloverTimes tracks the last time rollover was updated for a token
    mapping(address => uint256) public override lastRolloverTimes;

    event UpdateRolloverRate(address token, uint256 rolloverRate);

    // once the parameters are verified to be working correctly,
    // gov should be set to a timelock contract or a governance contract
    constructor(IVault _vault) public {
        gov = msg.sender;
        vault = _vault;
    }

    modifier afterInitialized() {
        require(isInitialized, "FeeUtilsV2: not initialized yet");
        _;
    }

    function initialize(
        uint256 _liquidationFeeUsd,
        bool _hasDynamicFees
    ) external {
        _onlyGov();
        require(!isInitialized, "FeeUtilsV2: already initialized");

        isInitialized = true;

        liquidationFeeUsd = _liquidationFeeUsd;
        hasDynamicFees = _hasDynamicFees;
    }

    function setGov(address _gov) external {
        _onlyGov();
        gov = _gov;
    }

    function setFeeMultiplierIfInactive(uint256 _feeMultiplierIfInactive) external override {
        _onlyGov();
        require(_feeMultiplierIfInactive >= 1, "FeeUtilsV2: invalid _feeMultiplierIfInactive");
        feeMultiplierIfInactive = _feeMultiplierIfInactive;
    }

    function setIsActive(bool _isActive) external override afterInitialized {
        _onlyGov();
        isActive = _isActive;
    }

    function setLiquidationFeeUsd(uint256 _liquidationFeeUsd) external override {
        _onlyGov();
        require(
            _liquidationFeeUsd <= MAX_LIQUIDATION_FEE_USD,
            "FeeUtilsV2: invalid _liquidationFeeUsd"
        );

        liquidationFeeUsd = _liquidationFeeUsd;
    }

    function setHasDynamicFees(bool _hasDynamicFees) external override {
        _onlyGov();

        hasDynamicFees = _hasDynamicFees;
    }

    function setTokenFeeFactors(
        address _token,
        uint256 _taxBasisPoints,
        uint256 _mintBurnFeeBasisPoints,
        uint256 _swapFeeBasisPoints,
        uint256 _rolloverRateFactor,
        uint256[] memory _relativePnlList,
        uint256[] memory _positionFeeBpsList,
        uint256[] memory _profitFeeBpsList
    ) external override {
        _onlyGov();

        require(
            _taxBasisPoints <= MAX_FEE_BASIS_POINTS,
            "FeeUtilsV2: invalid _taxBasisPoints"
        );
        require(
            _mintBurnFeeBasisPoints <= MAX_FEE_BASIS_POINTS,
            "FeeUtilsV2: invalid _mintBurnFeeBasisPoints"
        );
        require(
            _swapFeeBasisPoints <= MAX_FEE_BASIS_POINTS,
            "FeeUtilsV2: invalid _swapFeeBasisPoints"
        );
        require(
            _rolloverRateFactor <= MAX_ROLLOVER_RATE_FACTOR,
            "FeeUtilsV2: invalid _rolloverRateFactor"
        );

        require(
            _relativePnlList.length == _positionFeeBpsList.length && _relativePnlList.length == _profitFeeBpsList.length,
            "FeeUtilsV2: invalid _relativePnlList, _positionFeeBpsList, _profitFeeBpsList"
        );

        for (uint256 i = 0; i < _relativePnlList.length; i ++) {
            require(i == 0 || _relativePnlList[i - 1] <= _relativePnlList[i], "FeeUtilsV2: invalid _relativePnlList");
            require(_positionFeeBpsList[i] <= MAX_FEE_BASIS_POINTS, "FeeUtilsV2: invalid _positionFeeBpsList");
            require(_profitFeeBpsList[i] <= MAX_PROFIT_FEE_BASIS_POINTS, "FeeUtilsV2: invalid _profitFeeBpsList");
        }

        taxBasisPoints[_token] = _taxBasisPoints;
        mintBurnFeeBasisPoints[_token] = _mintBurnFeeBasisPoints;
        swapFeeBasisPoints[_token] = _swapFeeBasisPoints;
        rolloverRateFactors[_token] = _rolloverRateFactor;
        relativePnlLists[_token] = _relativePnlList;
        positionFeeBasisPointsLists[_token] = _positionFeeBpsList;
        profitFeeBasisPointsLists[_token] = _profitFeeBpsList;
    }

    function getLiquidationFeeUsd() external override view afterInitialized returns (uint256) {
        return liquidationFeeUsd;
    }

    function getBaseIncreasePositionFeeBps(address /* _indexToken */) external override view afterInitialized returns(uint256) {
        return 0;
    }

    function getBaseDecreasePositionFeeBps(address _indexToken) external override view afterInitialized returns(uint256) {
        if (positionFeeBasisPointsLists[_indexToken].length > 0) {
            return positionFeeBasisPointsLists[_indexToken][0];
        }
        return 0;
    }

    function setRolloverInterval(uint256 _rolloverInterval) external override {
        _onlyGov();
        require(
            _rolloverInterval >= MIN_ROLLOVER_RATE_INTERVAL,
            "FeeUtilsV2: invalid _rolloverInterval"
        );
        rolloverInterval = _rolloverInterval;
    }

    function updateCumulativeRolloverRate(address _collateralToken) external override afterInitialized {
        if (lastRolloverTimes[_collateralToken] == 0) {
            lastRolloverTimes[_collateralToken] = block
                .timestamp
                .div(rolloverInterval)
                .mul(rolloverInterval);
            return;
        }

        if (lastRolloverTimes[_collateralToken].add(rolloverInterval) > block.timestamp) {
            return;
        }

        uint256 rolloverRate = getNextRolloverRate(_collateralToken);
        cumulativeRolloverRates[_collateralToken] = cumulativeRolloverRates[_collateralToken].add(rolloverRate);
        lastRolloverTimes[_collateralToken] = block
            .timestamp
            .div(rolloverInterval)
            .mul(rolloverInterval);

        emit UpdateRolloverRate(
            _collateralToken,
            cumulativeRolloverRates[_collateralToken]
        );
    }

    function getNextRolloverRate(address _token) public view override afterInitialized returns (uint256) {
        if (lastRolloverTimes[_token].add(rolloverInterval) > block.timestamp) {
            return 0;
        }

        uint256 intervals = block.timestamp.sub(lastRolloverTimes[_token]).div(rolloverInterval);
        uint256 poolAmount = vault.poolAmounts(_token);
        if (poolAmount == 0) {
            return 0;
        }

        uint256 _rolloverRateFactor = rolloverRateFactors[_token];

        return _rolloverRateFactor
            .mul(vault.reservedAmounts(_token))
            .mul(intervals)
            .div(poolAmount);
    }

    function getEntryRolloverRate( address _collateralToken ) public override view afterInitialized returns (uint256) {
        return cumulativeRolloverRates[_collateralToken];
    }

    function getRolloverRates(address _weth, address[] memory _tokens) external override view afterInitialized returns (uint256[] memory) {
        uint256 propsLength = 2;
        uint256[] memory rolloverRates = new uint256[](_tokens.length * propsLength);

        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            if (token == address(0)) {
                token = _weth;
            }

            uint256 rolloverRate = rolloverRateFactors[token];
            uint256 reservedAmount = vault.reservedAmounts(token);
            uint256 poolAmount = vault.poolAmounts(token);

            if (poolAmount > 0) {
                rolloverRates[i * propsLength] = rolloverRate.mul(reservedAmount).div(poolAmount);
            }

            if (cumulativeRolloverRates[token] > 0) {
                uint256 nextRate = getNextRolloverRate(token);
                uint256 baseRate = cumulativeRolloverRates[token];
                rolloverRates[i * propsLength + 1] = baseRate.add(nextRate);
            }
        }

        return rolloverRates;
    }

    function getRolloverFee(
        address _collateralToken,
        uint256 _size,
        uint256 _entryRolloverRate
    ) external view override afterInitialized returns (uint256) {
        if (_size == 0) {
            return 0;
        }

        uint256 rolloverRate = cumulativeRolloverRates[_collateralToken] < _entryRolloverRate
            ? 0
            : cumulativeRolloverRates[_collateralToken].sub(_entryRolloverRate);

        if (rolloverRate == 0) {
            return 0;
        }

        uint256 multiplier = isActive ? 1 : feeMultiplierIfInactive;

        return _size.mul(rolloverRate).mul(multiplier).div(ROLLOVER_RATE_PRECISION);
    }

    function getIncreasePositionFee(
        address /* _account */,
        address /* _collateralToken */,
        address _indexToken,
        bool /* _isLong */,
        uint256 _sizeDelta
    ) external view override afterInitialized returns (uint256) {
        require(isInitialized, "FeeUtilsV2: not initialized yet");

        if (_sizeDelta == 0 || isActive || positionFeeBasisPointsLists[_indexToken].length == 0) {
            return 0;
        }

        uint256 len = positionFeeBasisPointsLists[_indexToken].length;

        uint256 positionFeeBps = positionFeeBasisPointsLists[_indexToken][len - 1];

        uint256 afterFeeUsd = _sizeDelta
            .mul(BASIS_POINTS_DIVISOR.sub(positionFeeBps))
            .div(BASIS_POINTS_DIVISOR);

        return _sizeDelta.sub(afterFeeUsd).mul(feeMultiplierIfInactive);
    }

    function getDecreasePositionFee(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        uint256 _sizeDelta
    ) external view override afterInitialized returns (uint256) {
        require(isInitialized, "FeeUtilsV2: not initialized yet");

        if (_sizeDelta == 0) {
            return 0;
        }

        bool hasProfit;
        uint256 pnl;

        // scope variables to avoid stack too deep errors
        {
            Position memory position = getPosition(_account, _collateralToken, _indexToken, _isLong);
            (bool _hasProfit, uint256 delta) = vault.getPositionDelta(_account, _collateralToken, _indexToken, _isLong);
            hasProfit = _hasProfit;
            // get the proportional change in pnl
            pnl = _sizeDelta.mul(delta).div(position.size);
        }

        uint256 positionFeeBps;
        uint256 profitFeeBps;

        uint256[] memory relativePnlList = relativePnlLists[_indexToken];
        uint256[] memory positionFeeBpsList = positionFeeBasisPointsLists[_indexToken];
        uint256[] memory profitFeeBpsList = profitFeeBasisPointsLists[_indexToken];

        if (!hasProfit || pnl == 0) {
            positionFeeBps = positionFeeBpsList[0];
            profitFeeBps = 0;
        } else {
            uint256 relativePnl = pnl.mul(BASIS_POINTS_DIVISOR).div(_sizeDelta);

            uint256 len = relativePnlList.length;
            if (relativePnl >= relativePnlList[len - 1]) {
                positionFeeBps = positionFeeBpsList[len - 1];
                profitFeeBps = profitFeeBpsList[len - 1];
            } else {
                for (uint256 i = 1; i < len; i++) {
                    if (relativePnl < relativePnlList[i]) {
                        uint256 minRelativePnl = relativePnlList[i - 1];
                        uint256 maxRelativePnl = relativePnlList[i];
                        uint256 minPositionFeeBps = positionFeeBpsList[i - 1];
                        uint256 maxPositionFeeBps = positionFeeBpsList[i];
                        uint256 minProfitFeeBps = profitFeeBpsList[i - 1];
                        uint256 maxProfitFeeBps = profitFeeBpsList[i];

                        positionFeeBps = minPositionFeeBps.add(
                            (maxPositionFeeBps - minPositionFeeBps).mul(relativePnl - minRelativePnl).div(maxRelativePnl - minRelativePnl)
                        );

                        profitFeeBps = minProfitFeeBps.add(
                            (maxProfitFeeBps - minProfitFeeBps).mul(relativePnl - minRelativePnl).div(maxRelativePnl - minRelativePnl)
                        );

                        break;
                    }
                }
            }
        }

        uint256 fees = (_sizeDelta.mul(positionFeeBps).add(pnl.mul(profitFeeBps))).div(BASIS_POINTS_DIVISOR);

        uint256 multiplier = isActive ? 1 : feeMultiplierIfInactive;

        return fees.mul(multiplier);
    }

    function getBuyUsdfFeeBasisPoints(
        address _token,
        uint256 _usdfAmount
    ) public view override afterInitialized returns (uint256) {
        return getFeeBasisPoints(
            _token,
            _usdfAmount,
            mintBurnFeeBasisPoints[_token],
            taxBasisPoints[_token],
            true
        );
    }

    function getSellUsdfFeeBasisPoints(
        address _token,
        uint256 _usdfAmount
    ) public view override afterInitialized returns (uint256) {
        return getFeeBasisPoints(
            _token,
            _usdfAmount,
            mintBurnFeeBasisPoints[_token],
            taxBasisPoints[_token],
            false
        );
    }

    function getSwapFeeBasisPoints(
        address _tokenIn,
        address _tokenOut,
        uint256 _usdfAmount
    ) public view override afterInitialized returns (uint256) {
        uint256 feesBasisPoints0 = getFeeBasisPoints(
            _tokenIn,
            _usdfAmount,
            swapFeeBasisPoints[_tokenIn],
            taxBasisPoints[_tokenIn],
            true
        );
        uint256 feesBasisPoints1 = getFeeBasisPoints(
            _tokenOut,
            _usdfAmount,
            swapFeeBasisPoints[_tokenOut],
            taxBasisPoints[_tokenOut],
            false
        );
        // use the higher of the two fee basis points
        return feesBasisPoints0 > feesBasisPoints1
            ? feesBasisPoints0
            : feesBasisPoints1;
    }

    // cases to consider
    // 1. initialAmount is far from targetAmount, action increases balance slightly => high rebate
    // 2. initialAmount is far from targetAmount, action increases balance largely => high rebate
    // 3. initialAmount is close to targetAmount, action increases balance slightly => low rebate
    // 4. initialAmount is far from targetAmount, action reduces balance slightly => high tax
    // 5. initialAmount is far from targetAmount, action reduces balance largely => high tax
    // 6. initialAmount is close to targetAmount, action reduces balance largely => low tax
    // 7. initialAmount is above targetAmount, nextAmount is below targetAmount and vice versa
    // 8. a large swap should have similar fees as the same trade split into multiple smaller swaps
    function getFeeBasisPoints(
        address _token,
        uint256 _usdfDelta,
        uint256 _feeBasisPoints,
        uint256 _taxBasisPoints,
        bool _increment
    ) public view override afterInitialized returns (uint256) {
        uint256 feeBps = _feeBasisPoints.mul(isActive ? 1 : feeMultiplierIfInactive);

        if (!hasDynamicFees) {
            return feeBps;
        }

        uint256 initialAmount = vault.usdfAmounts(_token);
        uint256 nextAmount = initialAmount.add(_usdfDelta);
        if (!_increment) {
            nextAmount = _usdfDelta > initialAmount
                ? 0
                : initialAmount.sub(_usdfDelta);
        }

        uint256 targetAmount = vault.getTargetUsdfAmount(_token);
        if (targetAmount == 0) {
            return feeBps;
        }

        uint256 initialDiff = initialAmount > targetAmount
            ? initialAmount.sub(targetAmount)
            : targetAmount.sub(initialAmount);
        uint256 nextDiff = nextAmount > targetAmount
            ? nextAmount.sub(targetAmount)
            : targetAmount.sub(nextAmount);

        // action improves relative asset balance
        if (nextDiff < initialDiff) {
            uint256 rebateBps = _taxBasisPoints.mul(initialDiff).div(targetAmount);
            return rebateBps > feeBps ? 0 : feeBps.sub(rebateBps);
        }

        uint256 averageDiff = initialDiff.add(nextDiff).div(2);
        if (averageDiff > targetAmount) {
            averageDiff = targetAmount;
        }
        uint256 taxBps = _taxBasisPoints.mul(averageDiff).div(targetAmount);
        return feeBps.add(taxBps);
    }

    // we have this validation as a function instead of a modifier to reduce contract size
    function _onlyGov() private view {
        require(msg.sender == gov, "FeeUtilsV2: forbidden");
    }

    function getStates(address[] memory _tokens) external view returns (
        address[] memory,
        uint256[] memory,
        bool[] memory
    ) {
        uint256 totalLength = 0;
        for (uint256 i = 0; i < _tokens.length; i++) {
            totalLength += 5 + 3 * relativePnlLists[_tokens[i]].length;
        }

        address[] memory addressValues = new address[](2);
        uint256[] memory intValues = new uint256[](3 + totalLength);
        bool[] memory boolValues = new bool[](2);

        addressValues[0] = gov;
        addressValues[1] = address(vault);

        intValues[0] = liquidationFeeUsd;
        intValues[1] = rolloverInterval;
        intValues[2] = feeMultiplierIfInactive;

        boolValues[0] = hasDynamicFees;
        boolValues[1] = isActive;

        uint256 index = 3;
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];

            intValues[index] = taxBasisPoints[token];
            intValues[index + 1] = mintBurnFeeBasisPoints[token];
            intValues[index + 2] = swapFeeBasisPoints[token];
            intValues[index + 3] = rolloverRateFactors[token];
            intValues[index + 4] = relativePnlLists[token].length;
            index += 5;
            for (uint256 j = 0; j < relativePnlLists[token].length; j++) {
                intValues[index] = relativePnlLists[token][j];
                intValues[index + 1] = positionFeeBasisPointsLists[token][j];
                intValues[index + 2] = profitFeeBasisPointsLists[token][j];
                index += 3;
            }
        }

        return (
            addressValues,
            intValues,
            boolValues
        );
    }

    function getPosition(address _account, address _collateralToken, address _indexToken, bool _isLong) internal view returns (Position memory) {
        IVault _vault = vault;
        Position memory position;
        {
            (uint256 size, uint256 collateral, uint256 averagePrice, uint256 entryRolloverRate, /* reserveAmount */, /* realisedPnl */, /* hasProfit */, uint256 lastIncreasedTime) = _vault.getPosition(_account, _collateralToken, _indexToken, _isLong);
            position.size = size;
            position.collateral = collateral;
            position.averagePrice = averagePrice;
            position.entryRolloverRate = entryRolloverRate;
            position.lastIncreasedTime = lastIncreasedTime;
        }
        return position;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
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
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
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
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
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
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
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
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
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
        require(b != 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

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

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./IERC20.sol";
import "../math/SafeMath.sol";
import "../utils/Address.sol";

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
    using SafeMath for uint256;
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
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
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
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./IVaultUtils.sol";
import "./IFeeUtils.sol";

interface IVault {
    function isInitialized() external view returns (bool);
    function isSwapEnabled() external view returns (bool);
    function isLeverageEnabled() external view returns (bool);

    function setVaultUtils(IVaultUtils _vaultUtils) external;
    function setFeeUtils(IFeeUtils _feeUtils) external;
    function setError(uint256 _errorCode, string calldata _error) external;

    function router() external view returns (address);
    function usdf() external view returns (address);
    function gov() external view returns (address);

    function getVaultUtils() external view returns (address);
    function getFeeUtils() external view returns (address);

    function whitelistedTokenCount() external view returns (uint256);
    function maxLeverage() external view returns (uint256);

    function minProfitTime() external view returns (uint256);
    function totalTokenWeights() external view returns (uint256);
    function getTargetUsdfAmount(address _token) external view returns (uint256);

    function inManagerMode() external view returns (bool);
    function inPrivateLiquidationMode() external view returns (bool);

    function maxGasPrice() external view returns (uint256);

    function approvedRouters(address _account, address _router) external view returns (bool);
    function isLiquidator(address _account) external view returns (bool);
    function isManager(address _account) external view returns (bool);

    function minProfitBasisPoints(address _token) external view returns (uint256);
    function tokenBalances(address _token) external view returns (uint256);

    function setMaxLeverage(uint256 _maxLeverage) external;
    function setInManagerMode(bool _inManagerMode) external;
    function setManager(address _manager, bool _isManager) external;
    function setIsSwapEnabled(bool _isSwapEnabled) external;
    function setIsLeverageEnabled(bool _isLeverageEnabled) external;
    function setMaxGasPrice(uint256 _maxGasPrice) external;
    function setUsdfAmount(address _token, uint256 _amount) external;
    function setBufferAmount(address _token, uint256 _amount) external;
    function setMaxGlobalShortSize(address _token, uint256 _amount) external;
    function setInPrivateLiquidationMode(bool _inPrivateLiquidationMode) external;
    function setLiquidator(address _liquidator, bool _isActive) external;

    function setMinProfitTime(uint256 _minProfitTime) external;

    function setTokenConfig(
        address _token,
        uint256 _tokenDecimals,
        uint256 _redemptionBps,
        uint256 _minProfitBps,
        uint256 _maxUsdfAmount,
        bool _isStable,
        bool _isShortable
    ) external;

    function clearTokenConfig(address _token) external;

    function setPriceFeed(address _priceFeed) external;
    function withdrawFees(address _token, address _receiver) external returns (uint256);

    function directPoolDeposit(address _token) external;
    function buyUSDF(address _token, address _receiver) external returns (uint256);
    function sellUSDF(address _token, address _receiver) external returns (uint256);
    function swap(address _tokenIn, address _tokenOut, address _receiver) external returns (uint256);
    function increasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external;
    function decreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external returns (uint256);
    function liquidatePosition(address _account, address _collateralToken, address _indexToken, bool _isLong, address _feeReceiver) external;
    function tokenToUsdMin(address _token, uint256 _tokenAmount) external view returns (uint256);

    function priceFeed() external view returns (address);

    function allWhitelistedTokensLength() external view returns (uint256);
    function allWhitelistedTokens(uint256) external view returns (address);
    function whitelistedTokens(address _token) external view returns (bool);
    function stableTokens(address _token) external view returns (bool);
    function shortableTokens(address _token) external view returns (bool);
    function feeReserves(address _token) external view returns (uint256);
    function globalShortSizes(address _token) external view returns (uint256);
    function globalShortAveragePrices(address _token) external view returns (uint256);
    function maxGlobalShortSizes(address _token) external view returns (uint256);
    function tokenDecimals(address _token) external view returns (uint256);
    function tokenWeights(address _token) external view returns (uint256);
    function guaranteedUsd(address _token) external view returns (uint256);
    function poolAmounts(address _token) external view returns (uint256);
    function bufferAmounts(address _token) external view returns (uint256);
    function reservedAmounts(address _token) external view returns (uint256);
    function usdfAmounts(address _token) external view returns (uint256);
    function maxUsdfAmounts(address _token) external view returns (uint256);
    function getRedemptionAmount(address _token, uint256 _usdfAmount) external view returns (uint256);
    function getMaxPrice(address _token) external view returns (uint256);
    function getMinPrice(address _token) external view returns (uint256);

    function getDelta(address _indexToken, uint256 _size, uint256 _averagePrice, bool _isLong, uint256 _lastIncreasedTime) external view returns (bool, uint256);
    function getPositionDelta(address _account, address _collateralToken, address _indexToken, bool _isLong) external view returns (bool, uint256);
    function getPosition(address _account, address _collateralToken, address _indexToken, bool _isLong) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, bool, uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IFeeUtils {
    function gov() external view returns (address);

    function feeMultiplierIfInactive() external view returns (uint256);
    function isActive() external view returns (bool);

    function setFeeMultiplierIfInactive(uint256 _feeMultiplierIfInactive) external;
    function setIsActive(bool _isActive) external;

    function getLiquidationFeeUsd() external view returns (uint256);
    function getBaseIncreasePositionFeeBps(address _indexToken) external view returns (uint256);
    function getBaseDecreasePositionFeeBps(address _indexToken) external view returns (uint256);

    function getEntryRolloverRate(address _collateralToken) external view returns (uint256);
    function getNextRolloverRate(address _token) external view returns (uint256);
    function getRolloverRates(address _weth, address[] memory _tokens) external view returns (uint256[] memory);
    function updateCumulativeRolloverRate(address _collateralToken) external;

    function getIncreasePositionFee(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _sizeDelta) external view returns (uint256);
    function getDecreasePositionFee(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _sizeDelta) external view returns (uint256);
    function getRolloverFee(address _collateralToken, uint256 _size, uint256 _entryFundingRate) external view returns (uint256);

    function getBuyUsdfFeeBasisPoints(address _token, uint256 _usdfAmount) external view returns (uint256);
    function getSellUsdfFeeBasisPoints(address _token, uint256 _usdfAmount) external view returns (uint256);
    function getSwapFeeBasisPoints(address _tokenIn, address _tokenOut, uint256 _usdfAmount) external view returns (uint256);
    function getFeeBasisPoints(address _token, uint256 _usdfDelta, uint256 _feeBasisPoints, uint256 _taxBasisPoints, bool _increment) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IFeeUtilsV2 {
    function isInitialized() external view returns (bool);

    function hasDynamicFees() external view returns (bool);
    function rolloverInterval() external view returns (uint256);
    function rolloverRateFactors(address _token) external view returns (uint256);
    function cumulativeRolloverRates(address _token) external view returns (uint256);
    function lastRolloverTimes(address _token) external view returns (uint256);

    function liquidationFeeUsd() external view returns (uint256);

    function taxBasisPoints(address _token) external view returns (uint256);
    function mintBurnFeeBasisPoints(address _token) external view returns (uint256);
    function swapFeeBasisPoints(address _token) external view returns (uint256);

    function relativePnlLists(address _token, uint256 index) external view returns (uint256);
    function positionFeeBasisPointsLists(address _token, uint256 index) external view returns (uint256);
    function profitFeeBasisPointsLists(address _token, uint256 index) external view returns (uint256);

    function setRolloverInterval(uint256 _rolloverInterval) external;
    function setLiquidationFeeUsd(uint256 _liquidationFeeUsd) external;
    function setHasDynamicFees(bool _hasDynamicFees) external;

    function setTokenFeeFactors(
        address _token,
        uint256 _taxBasisPoints,
        uint256 _mintBurnFeeBasisPoints,
        uint256 _swapFeeBasisPoints,
        uint256 _rolloverRateFactor,
        uint256[] memory _relativePnlList,
        uint256[] memory _positionFeeBpsList,
        uint256[] memory _profitFeeBpsList
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.3._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.3._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

pragma solidity 0.6.12;

import "./IFeeUtils.sol";

interface IVaultUtils {
    function getFeeUtils() external view returns (address);

    function setFeeUtils(IFeeUtils _feeUtils) external;
    function validateIncreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external view;
    function validateDecreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external view;
    function validateLiquidation(address _account, address _collateralToken, address _indexToken, bool _isLong, bool _raise) external view returns (uint256, uint256);
}