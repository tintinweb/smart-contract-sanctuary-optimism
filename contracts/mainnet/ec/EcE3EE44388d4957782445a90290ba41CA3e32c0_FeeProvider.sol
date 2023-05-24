// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./dependencies/openzeppelin/proxy/utils/Initializable.sol";
import "./storage/FeeProviderStorage.sol";
import "./lib/WadRayMath.sol";

error SenderIsNotGovernor();
error PoolRegistryIsNull();
error NewValueIsSameAsCurrent();
error FeeIsGreaterThanTheMax();
error TierDiscountTooHigh();
error TiersNotOrderedByMin();

/**
 * @title FeeProvider contract
 */
contract FeeProvider is Initializable, FeeProviderStorageV1 {
    using WadRayMath for uint256;

    string public constant VERSION = "1.2.0";

    uint256 internal constant MAX_FEE_VALUE = 0.25e18; // 25%
    uint256 internal constant MAX_FEE_DISCOUNT = 1e18; // 100%

    /// @notice Emitted when deposit fee is updated
    event DepositFeeUpdated(uint256 oldDepositFee, uint256 newDepositFee);

    /// @notice Emitted when issue fee is updated
    event IssueFeeUpdated(uint256 oldIssueFee, uint256 newIssueFee);

    /// @notice Emitted when liquidator incentive is updated
    event LiquidatorIncentiveUpdated(uint256 oldLiquidatorIncentive, uint256 newLiquidatorIncentive);

    /// @notice Emitted when protocol liquidation fee is updated
    event ProtocolLiquidationFeeUpdated(uint256 oldProtocolLiquidationFee, uint256 newProtocolLiquidationFee);

    /// @notice Emitted when repay fee is updated
    event RepayFeeUpdated(uint256 oldRepayFee, uint256 newRepayFee);

    /// @notice Emitted when swap fee is updated
    event SwapDefaultFeeUpdated(uint256 oldSwapFee, uint256 newSwapFee);

    /// @notice Emitted when tiers are updated
    event TiersUpdated(Tier[] oldTiers, Tier[] newTiers);

    /// @notice Emitted when withdraw fee is updated
    event WithdrawFeeUpdated(uint256 oldWithdrawFee, uint256 newWithdrawFee);

    /**
     * @notice Throws if caller isn't the governor
     */
    modifier onlyGovernor() {
        if (msg.sender != poolRegistry.governor()) revert SenderIsNotGovernor();
        _;
    }

    function initialize(IPoolRegistry poolRegistry_, IESMET esMET_) public initializer {
        if (address(poolRegistry_) == address(0)) revert PoolRegistryIsNull();

        poolRegistry = poolRegistry_;
        esMET = esMET_;

        liquidationFees = LiquidationFees({
            liquidatorIncentive: 1e17, // 10%
            protocolFee: 8e16 // 8%
        });
        defaultSwapFee = 25e14; // 0.25%
    }

    /**
     * @notice Get fee discount tiers
     */
    function getTiers() external view returns (Tier[] memory _tiers) {
        return tiers;
    }

    /**
     * @notice Get the swap fee for a given account
     * Fee discount are applied on top of the default swap fee depending on user's esMET balance
     * @param account_ The account address
     * @return _swapFee The account's swap fee
     */
    function swapFeeFor(address account_) external view override returns (uint256 _swapFee) {
        uint256 _len = tiers.length;

        if (_len == 0) {
            return defaultSwapFee;
        }

        uint256 _balance = esMET.balanceOf(account_);

        if (_balance < tiers[0].min) {
            return defaultSwapFee;
        }

        uint256 i = 1;
        while (i < _len) {
            if (_balance < tiers[i].min) {
                unchecked {
                    // Note: `discount` is always <= `1e18`
                    return defaultSwapFee.wadMul(1e18 - tiers[i - 1].discount);
                }
            }

            unchecked {
                ++i;
            }
        }

        unchecked {
            // Note: `discount` is always <= `1e18`
            return defaultSwapFee.wadMul(1e18 - tiers[_len - 1].discount);
        }
    }

    /**
     * @notice Update deposit fee
     */
    function updateDepositFee(uint256 newDepositFee_) external onlyGovernor {
        if (newDepositFee_ > MAX_FEE_VALUE) revert FeeIsGreaterThanTheMax();
        uint256 _currentDepositFee = depositFee;
        if (newDepositFee_ == _currentDepositFee) revert NewValueIsSameAsCurrent();
        emit DepositFeeUpdated(_currentDepositFee, newDepositFee_);
        depositFee = newDepositFee_;
    }

    /**
     * @notice Update issue fee
     */
    function updateIssueFee(uint256 newIssueFee_) external onlyGovernor {
        if (newIssueFee_ > MAX_FEE_VALUE) revert FeeIsGreaterThanTheMax();
        uint256 _currentIssueFee = issueFee;
        if (newIssueFee_ == _currentIssueFee) revert NewValueIsSameAsCurrent();
        emit IssueFeeUpdated(_currentIssueFee, newIssueFee_);
        issueFee = newIssueFee_;
    }

    /**
     * @notice Update liquidator incentive
     * @dev liquidatorIncentive + protocolFee can't surpass max
     */
    function updateLiquidatorIncentive(uint128 newLiquidatorIncentive_) external onlyGovernor {
        LiquidationFees memory _current = liquidationFees;
        if (newLiquidatorIncentive_ + _current.protocolFee > MAX_FEE_VALUE) revert FeeIsGreaterThanTheMax();
        if (newLiquidatorIncentive_ == _current.liquidatorIncentive) revert NewValueIsSameAsCurrent();
        emit LiquidatorIncentiveUpdated(_current.liquidatorIncentive, newLiquidatorIncentive_);
        liquidationFees.liquidatorIncentive = newLiquidatorIncentive_;
    }

    /**
     * @notice Update protocol liquidation fee
     * @dev liquidatorIncentive + protocolFee can't surpass max
     */
    function updateProtocolLiquidationFee(uint128 newProtocolLiquidationFee_) external onlyGovernor {
        LiquidationFees memory _current = liquidationFees;
        if (newProtocolLiquidationFee_ + _current.liquidatorIncentive > MAX_FEE_VALUE) revert FeeIsGreaterThanTheMax();
        if (newProtocolLiquidationFee_ == _current.protocolFee) revert NewValueIsSameAsCurrent();
        emit ProtocolLiquidationFeeUpdated(_current.protocolFee, newProtocolLiquidationFee_);
        liquidationFees.protocolFee = newProtocolLiquidationFee_;
    }

    /**
     * @notice Update repay fee
     */
    function updateRepayFee(uint256 newRepayFee_) external onlyGovernor {
        if (newRepayFee_ > MAX_FEE_VALUE) revert FeeIsGreaterThanTheMax();
        uint256 _currentRepayFee = repayFee;
        if (newRepayFee_ == _currentRepayFee) revert NewValueIsSameAsCurrent();
        emit RepayFeeUpdated(_currentRepayFee, newRepayFee_);
        repayFee = newRepayFee_;
    }

    /**
     * @notice Update swap fee
     */
    function updateDefaultSwapFee(uint256 newDefaultSwapFee_) external onlyGovernor {
        if (newDefaultSwapFee_ > MAX_FEE_VALUE) revert FeeIsGreaterThanTheMax();
        uint256 _current = defaultSwapFee;
        if (newDefaultSwapFee_ == _current) revert NewValueIsSameAsCurrent();
        emit SwapDefaultFeeUpdated(_current, newDefaultSwapFee_);
        defaultSwapFee = newDefaultSwapFee_;
    }

    /**
     * @notice Update fee discount tiers
     */
    function updateTiers(Tier[] memory tiers_) external onlyGovernor {
        emit TiersUpdated(tiers, tiers_);
        delete tiers;

        uint256 _len = tiers_.length;
        for (uint256 i; i < _len; ++i) {
            Tier memory _tier = tiers_[i];
            if (_tier.discount > MAX_FEE_DISCOUNT) revert TierDiscountTooHigh();
            if (i > 0 && tiers_[i - 1].min > _tier.min) revert TiersNotOrderedByMin();
            tiers.push(_tier);
        }
    }

    /**
     * @notice Update withdraw fee
     */
    function updateWithdrawFee(uint256 newWithdrawFee_) external onlyGovernor {
        if (newWithdrawFee_ > MAX_FEE_VALUE) revert FeeIsGreaterThanTheMax();
        uint256 _currentWithdrawFee = withdrawFee;
        if (newWithdrawFee_ == _currentWithdrawFee) revert NewValueIsSameAsCurrent();
        emit WithdrawFeeUpdated(_currentWithdrawFee, newWithdrawFee_);
        withdrawFee = newWithdrawFee_;
    }
}

// SPDX-License-Identifier: MIT

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

pragma solidity ^0.8.0;

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

pragma solidity 0.8.9;

import "../dependencies/openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "./ISyntheticToken.sol";

interface IDebtToken is IERC20Metadata {
    function lastTimestampAccrued() external view returns (uint256);

    function isActive() external view returns (bool);

    function syntheticToken() external view returns (ISyntheticToken);

    function accrueInterest() external;

    function debtIndex() external returns (uint256 debtIndex_);

    function burn(address from_, uint256 amount_) external;

    function issue(uint256 amount_, address to_) external returns (uint256 _issued, uint256 _fee);

    function flashIssue(address borrower_, uint256 amount_) external returns (uint256 _issued, uint256 _fee);

    function repay(address onBehalfOf_, uint256 amount_) external returns (uint256 _repaid, uint256 _fee);

    function repayAll(address onBehalfOf_) external returns (uint256 _repaid, uint256 _fee);

    function quoteIssueIn(uint256 amountToIssue_) external view returns (uint256 _amount, uint256 _fee);

    function quoteIssueOut(uint256 amount_) external view returns (uint256 _amountToIssue, uint256 _fee);

    function quoteRepayIn(uint256 amountToRepay_) external view returns (uint256 _amount, uint256 _fee);

    function quoteRepayOut(uint256 amount_) external view returns (uint256 _amountToRepay, uint256 _fee);

    function updateMaxTotalSupply(uint256 newMaxTotalSupply_) external;

    function updateInterestRate(uint256 newInterestRate_) external;

    function maxTotalSupply() external view returns (uint256);

    function interestRate() external view returns (uint256);

    function interestRatePerSecond() external view returns (uint256);

    function toggleIsActive() external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

/**
 * @notice FeeProvider interface
 */
interface IFeeProvider {
    struct LiquidationFees {
        uint128 liquidatorIncentive;
        uint128 protocolFee;
    }

    function defaultSwapFee() external view returns (uint256);

    function depositFee() external view returns (uint256);

    function issueFee() external view returns (uint256);

    function liquidationFees() external view returns (uint128 liquidatorIncentive, uint128 protocolFee);

    function repayFee() external view returns (uint256);

    function swapFeeFor(address account_) external view returns (uint256);

    function withdrawFee() external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

/**
 * @notice Governable interface
 */
interface IGovernable {
    function governor() external view returns (address _governor);

    function transferGovernorship(address _proposedGovernor) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IPauseable {
    function paused() external view returns (bool);

    function everythingStopped() external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./external/IMasterOracle.sol";
import "./IPauseable.sol";
import "./IGovernable.sol";
import "./ISyntheticToken.sol";

interface IPoolRegistry is IPauseable, IGovernable {
    function isPoolRegistered(address pool_) external view returns (bool);

    function feeCollector() external view returns (address);

    function nativeTokenGateway() external view returns (address);

    function getPools() external view returns (address[] memory);

    function registerPool(address pool_) external;

    function unregisterPool(address pool_) external;

    function masterOracle() external view returns (IMasterOracle);

    function updateMasterOracle(IMasterOracle newOracle_) external;

    function updateFeeCollector(address newFeeCollector_) external;

    function updateNativeTokenGateway(address newGateway_) external;

    function idOfPool(address pool_) external view returns (uint256);

    function nextPoolId() external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "../dependencies/openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "./IDebtToken.sol";
import "./IPoolRegistry.sol";

interface ISyntheticToken is IERC20Metadata {
    function isActive() external view returns (bool);

    function mint(address to_, uint256 amount_) external;

    function burn(address from_, uint256 amount) external;

    function poolRegistry() external returns (IPoolRegistry);

    function toggleIsActive() external;

    function seize(address from_, address to_, uint256 amount_) external;

    function updateMaxTotalSupply(uint256 newMaxTotalSupply_) external;

    function maxTotalSupply() external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IESMET {
    function balanceOf(address account_) external view returns (uint256);

    function lock(uint256 amount_, uint256 lockPeriod_) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IMasterOracle {
    function quoteTokenToUsd(address _asset, uint256 _amount) external view returns (uint256 _amountInUsd);

    function quoteUsdToToken(address _asset, uint256 _amountInUsd) external view returns (uint256 _amount);

    function quote(address _assetIn, address _assetOut, uint256 _amountIn) external view returns (uint256 _amountOut);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

/**
 * @title Math library
 * @dev Provides mul and div function for wads (decimal numbers with 18 digits precision) and rays (decimals with 27 digits)
 * @dev Based on https://github.com/dapphub/ds-math/blob/master/src/math.sol
 */
library WadRayMath {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant HALF_WAD = WAD / 2;

    uint256 internal constant RAY = 1e27;
    uint256 internal constant HALF_RAY = RAY / 2;

    uint256 internal constant WAD_RAY_RATIO = 1e9;

    /**
     * @dev Multiplies two wad, rounding half up to the nearest wad
     * @param a Wad
     * @param b Wad
     * @return The result of a*b, in wad
     */
    function wadMul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 || b == 0) {
            return 0;
        }

        return (a * b + HALF_WAD) / WAD;
    }

    /**
     * @dev Divides two wad, rounding half up to the nearest wad
     * @param a Wad
     * @param b Wad
     * @return The result of a/b, in wad
     */
    function wadDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * WAD + b / 2) / b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "../interfaces/IFeeProvider.sol";
import "../interfaces/IPoolRegistry.sol";
import "../interfaces/external/IESMET.sol";

abstract contract FeeProviderStorageV1 is IFeeProvider {
    struct Tier {
        uint128 min; // esMET min balance needed to be eligible for `discount`
        uint128 discount; // discount in percentage to apply. Use 18 decimals (e.g. 1e16 = 1%)
    }

    /**
     * @notice The fee discount tiers
     */
    Tier[] public tiers;

    /**
     * @notice The default fee charged when swapping synthetic tokens
     * @dev Use 18 decimals (e.g. 1e16 = 1%)
     */
    uint256 public override defaultSwapFee;

    /**
     * @notice The fee charged when depositing collateral
     * @dev Use 18 decimals (e.g. 1e16 = 1%)
     */
    uint256 public override depositFee;

    /**
     * @notice The fee charged when minting a synthetic token
     * @dev Use 18 decimals (e.g. 1e16 = 1%)
     */
    uint256 public override issueFee;

    /**
     * @notice The fee charged when withdrawing collateral
     * @dev Use 18 decimals (e.g. 1e16 = 1%)
     */
    uint256 public override withdrawFee;

    /**
     * @notice The fee charged when repaying debt
     * @dev Use 18 decimals (e.g. 1e16 = 1%)
     */
    uint256 public override repayFee;

    /**
     * @notice The fees charged when liquidating a position
     * @dev Use 18 decimals (e.g. 1e16 = 1%)
     */
    LiquidationFees public override liquidationFees;

    /**
     * @dev The Pool Registry
     */
    IPoolRegistry public poolRegistry;

    /**
     * @notice The esMET contract
     */
    IESMET public esMET;
}