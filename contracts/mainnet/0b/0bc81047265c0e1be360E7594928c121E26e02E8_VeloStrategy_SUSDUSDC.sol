// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;
import {BasicStrategy} from "../BasicStrategy.sol";
import "../../interfaces/Velodrome.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Minion} from "../../Minion.sol";
// import "hardhat/console.sol"; // TODO: Remove before deploy

/**
 * @title VeloStrategy_SUSDUSDC
 * @dev Defined strategy(I.e curve 3pool) that inherits structure and functionality from BasicStrategy
 */
contract VeloStrategy_SUSDUSDC is BasicStrategy {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address private _veloGaugeDeposit =
        address(0xb03f52D2DB3e758DD49982Defd6AeEFEa9454e80);

    address private _veloLpToken =
        address(0xd16232ad60188B68076a235c65d692090caba155);

    address private _veloRouter =
        address(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);

    address private _veloToken =
        address(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);

    address private _susdToken =
        address(0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9);

    address private _usdcToken =
        address(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);

    address[] public activeRewardsTokens = [_veloToken];

    int128 private _tokenIndex = 0;
    uint256 private _slippageAllowed = 10000000; // 10000000 = 1%

    constructor(
        address _vault,
        address _wantToken,
        address _poolInvestToken
    ) BasicStrategy(_vault, _wantToken, _poolInvestToken) {}

    /// @return name of the strategy
    function getName() external pure override returns (string memory) {
        return "VeloStrategy_SUSDUSDC";
    }

    /// @dev pre approves max
    function doApprovals() public {
        IERC20(want()).safeApprove(_veloGaugeDeposit, type(uint256).max);
        IERC20(_veloToken).safeApprove(_veloRouter, type(uint256).max);
        IERC20(_susdToken).safeApprove(_veloRouter, type(uint256).max);
        IERC20(_usdcToken).safeApprove(_veloRouter, type(uint256).max);
    }

    /// @notice gives an estimate of tokens invested
    function balanceOfPool() public view override returns (uint256) {
        return ISolidlyGauge(_veloGaugeDeposit).balanceOf(address(this));
    }

    function depositFromVault() public onlyVault {
        _deposit();
    }

    /// @notice invests available funds
    function deposit() public override onlyMinion {
        _deposit();
    }

    /// @notice invests available funds
    function _deposit() internal {

        uint256 availableFundsToDeposit = getAvailableFunds();

        require(availableFundsToDeposit > 0, "No funds available");

        ISolidlyGauge(_veloGaugeDeposit).deposit(availableFundsToDeposit, 0);
    }

    /// @notice withdraws all from pool to strategy where the funds can safetly be withdrawn by it's owners
    /// @dev this is only to be allowed by governance and should only be used in the event of a strategy or pool not functioning correctly/getting discontinued etc
    function withdrawAll() public override onlyGovernance {

        uint256 balanceOfGaugeToken = IERC20(_veloGaugeDeposit).balanceOf(
            address(this)
        ); // get shares

        ISolidlyGauge(_veloGaugeDeposit).withdraw(balanceOfGaugeToken);
    }

    /// @notice withdraws a certain amount from the pool
    /// @dev can only be called from inside the contract through the withdraw function which is protected by only vault modifier
    function _withdrawAmount(uint256 _amount)
        internal
        override
        onlyVault
        returns (uint256)
    {
        uint256 beforeWithdraw = getAvailableFunds();

        uint256 balanceOfPoolAmount = balanceOfPool();

        if (_amount > balanceOfPoolAmount) {
            _amount = balanceOfPoolAmount;
        }

        ISolidlyGauge(_veloGaugeDeposit).withdraw(_amount);

        uint256 afterWithdraw = getAvailableFunds();

        return afterWithdraw.sub(beforeWithdraw);
    }

    /// @notice call to withdraw funds to vault
    function withdraw(uint256 _amount)
        external
        override
        onlyVault
        returns (uint256)
    {
        uint256 availableFunds = getAvailableFunds();

        if (availableFunds >= _amount) {
            IERC20(wantToken).safeTransfer(__vault, _amount);
            return _amount;
        }

        uint256 amountToWithdrawFromGauge = _amount.sub(availableFunds);

        uint256 amountThatWasWithdrawn = _withdrawAmount(amountToWithdrawFromGauge);

        availableFunds = getAvailableFunds();

        if(availableFunds < _amount){
            _amount = availableFunds;
        }

        IERC20(wantToken).safeTransfer(__vault, _amount);

        return _amount;
    }

    function _swapSolidlyWithRoute(RouteParams memory routes, uint256 _amount) internal {
        ISolidlyRouter(_veloRouter).swapExactTokensForTokens(_amount, 0, routes, address(this), block.timestamp.add(60));
    }

    function harvest() public onlyMinion {
        ISolidlyGauge(_veloGaugeDeposit).getReward(address(this), activeRewardsTokens);
    }

    /// @notice harvests rewards, sells them for want and reinvests them
    function harvestAndReinvest() public override onlyMinion {
        ISolidlyGauge(_veloGaugeDeposit).getReward(address(this), activeRewardsTokens);

        uint256 rewardAmount = IERC20(_veloToken).balanceOf(
            address(this)
        );

        require(rewardAmount > 0, "No Rewards");


        if (performanceFee > 0) {
            uint256 _fee = calculateFee(rewardAmount, performanceFee);
            IERC20(_veloToken).safeTransfer(feeAddress, _fee);
        }

        rewardAmount = IERC20(_veloToken).balanceOf(
            address(this)
        );

        // Swap Velo to token0/token1
        uint256 _toToken0 = rewardAmount.div(2);
        uint256 _toToken1 = rewardAmount.sub(_toToken0);

        RouteParams[] memory _veloRoute = new RouteParams[](2);
        _veloRoute[0] = RouteParams(_veloToken, _usdcToken, true);
        _veloRoute[1] = RouteParams(_veloToken, _susdToken, true);

//        _swapSolidlyWithRoute(_veloRoute[0], _toToken0);
//        _swapSolidlyWithRoute(_veloRoute[1], _toToken1);

        ISolidlyRouter(_veloRouter).swapExactTokensForTokensSimple(_toToken0, 0, _veloToken, _usdcToken, false,  address(this), block.timestamp.add(60));
        ISolidlyRouter(_veloRouter).swapExactTokensForTokensSimple(_toToken1, 0, _veloToken, _susdToken, false,  address(this), block.timestamp.add(60));

        // Adds in liquidity
        uint256 _token0Amount = IERC20(_usdcToken).balanceOf(address(this));
        uint256 _token1Amount = IERC20(_susdToken).balanceOf(address(this));
        if (_token0Amount > 0 && _token1Amount > 0) {
            ISolidlyRouter(_veloRouter).addLiquidity(
                _usdcToken,
                _susdToken,
                true,
                _token0Amount,
                _token1Amount,
                0,
                0,
                address(this),
                block.timestamp + 60
            );
        }

        _deposit();
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Minion} from "../Minion.sol";
import {VaultConnected} from "../VaultConnected.sol";
import {ISwapRouter03, IV3SwapRouter} from "../interfaces/Uniswap.sol";

/**
 * @title BasicStrategy
 * @dev Defines structure and basic functionality of strategies
 */
contract BasicStrategy is VaultConnected, Minion {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public immutable wantToken;
    address public immutable poolInvestToken;

    address[] public rewards;

    uint24 internal _poolFee = 3000;
    uint256 public performanceFee = 0;
    address public feeAddress = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant MAX_FLOAT_FEE = 10000000000; // 100%, 1e10 precision.
    uint256 public lifetimeEarned = 0;

    address payable public univ3Router2 =
        payable(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    mapping(address => bool) private approvedTokens;

    // not sure we need indexed
    event HarvestAndReinvest(
        uint256 indexed amountTraded,
        uint256 indexed amountReceived
    );

    event Harvest(uint256 wantEarned, uint256 lifetimeEarned);

    constructor(address _vault, address _wantToken, address _poolInvestToken) VaultConnected(_vault) {
        wantToken = _wantToken;
        poolInvestToken = _poolInvestToken;
    }

    /// @return name of the strategy
    function getName() external pure virtual returns (string memory) {
        return "BasicStrategy";
    }

    /// @notice invests available funds
    function deposit() public virtual onlyMinion {
    }

    /// @notice withdraws all from pool to strategy where the funds can safetly be withdrawn by it's owners
    /// @dev this is only to be allowed by governance and should only be used in the event of a strategy or pool not functioning correctly/getting discontinued etc
    function withdrawAll() public virtual onlyGovernance {
    }

    /// @notice withdraws a certain amount from the pool
    /// @dev can only be called from inside the contract through the withdraw function which is protected by only vault modifier
    function _withdrawAmount(uint256 _amount)
        internal
        virtual
        onlyVault
        returns (uint256)
    {
    }

    /// @dev returns nr of curve tokens that are not yet gauged
    function getAvailableFunds() public view returns (uint256) {
        return IERC20(wantToken).balanceOf(address(this));
    }

    /// @dev returns nr of funds that are not yet invested
    function getAvailablePoolInvestTokens() public view returns (uint256) {
        return IERC20(poolInvestToken).balanceOf(address(this));
    }

    /// @notice gives an estimate of tokens invested
    /// @dev returns an estimate of tokens invested
    function balanceOfPool() public view virtual returns (uint256) {
        return 0;
    }

    /// @notice gets the total amount of funds held by this strategy
    /// @dev returns total amount of available and invested funds
    function getTotalBalance() public view returns (uint256) { // TODO: Maybe add the susd/poolInvestToken somehow as well...not sure
        uint256 investedFunds = balanceOfPool();
        uint256 availableFunds = getAvailableFunds();

        return investedFunds.add(availableFunds);
    }

    /// @notice sells rewards for want and reinvests them
    function harvestAndReinvest() public virtual onlyMinion {
        for (uint256 i = 0; i < rewards.length; i++) {
            if (rewards[i] == address(0)) {
                continue;
            }

            uint256 balanceOfCurrentReward = IERC20(rewards[i]).balanceOf(
                address(this)
            );

            if (balanceOfCurrentReward < 1) {
                continue;
            }

            if (approvedTokens[rewards[i]] == false) {
                IERC20(rewards[i]).safeApprove(univ3Router2, type(uint256).max);
                approvedTokens[rewards[i]] = true;
            }

            uint256 amountOut = ISwapRouter03(univ3Router2).exactInput(
                IV3SwapRouter.ExactInputParams({
                    path: abi.encodePacked(
                        rewards[i],
                        _poolFee,
                        ISwapRouter03(univ3Router2).WETH9(),
                        _poolFee,
                        poolInvestToken
                    ),
                    recipient: address(this),
                    amountIn: balanceOfCurrentReward,
                    amountOutMinimum: 0
                })
            );

            /// @notice Keep this in so you get paid!
            if (performanceFee > 0 && amountOut > 0) {
                uint256 _fee = calculateFee(amountOut, performanceFee);
                IERC20(poolInvestToken).safeTransfer(feeAddress, _fee);
            }

            lifetimeEarned = lifetimeEarned.add(amountOut);
            emit Harvest(amountOut, lifetimeEarned);
            emit HarvestAndReinvest(balanceOfCurrentReward, amountOut);
        }
    }

    /// @notice call to withdraw funds to vault
    function withdraw(uint256 _amount)
        external
        virtual
        onlyVault
        returns (uint256)
    {
        uint256 availableFunds = getAvailableFunds();

        if (availableFunds >= _amount) {
            IERC20(wantToken).safeTransfer(__vault, _amount);
            return _amount;
        }

        uint256 amountThatWasWithdrawn = _withdrawAmount(_amount);

        IERC20(wantToken).safeTransfer(__vault, amountThatWasWithdrawn);
        return amountThatWasWithdrawn;
    }

    /// @notice returns address of want token(I.e token that this strategy aims to accumulate)
    function want() public view returns (address) {
        return wantToken;
    }

    /// @dev calculates acceptable difference, used when setting an acceptable min of return
    /// @param _amount amount to calculate percentage of
    /// @param _differenceRate percentage rate to use
    function calculateAcceptableDifference(
        uint256 _amount,
        uint256 _differenceRate
    ) internal pure returns (uint256 _fee) {
        return _amount.sub((_amount * _differenceRate) / 10000); // 100%
    }

    /// @dev adds address of an expected reward to be yielded from the strategy, looks for a empty slot in the array before creating extra space in array in order to save gas
    /// @param _reward address of reward token
    function addReward(address _reward) public onlyGovernance {

        for (uint256 i = 0; i < rewards.length; i++) {
            if (rewards[i] == _reward) {
                // address already exists, return
                return;
            }
        }

        for (uint256 i = 0; i < rewards.length; i++) {
            if (rewards[i] == address(0)) {
                rewards[i] = _reward;
                return;
            }
        }
        rewards.push(_reward);
    }

    /// @dev looks for an address of a token in the rewards array and resets it to zero instead of popping it, this in order to save gas
    function removeReward(address _reward) public onlyGovernance {
        for (uint256 i = 0; i < rewards.length; i++) {
            if (rewards[i] == _reward) {
                rewards[i] = address(0);
                return;
            }
        }
    }

    /// @dev resets all addresses of rewards to zero
    function clearRewards() public onlyGovernance {
        for (uint256 i = 0; i < rewards.length; i++) {
            rewards[i] = address(0);
        }
    }

    /// @dev returns rewards that this strategy yields and later converts to want
    function getRewards() public view returns (address[] memory) {
        return rewards;
    }

    /// @dev gets pool fee rate
    function getPoolFee() public view returns (uint24) {
        return _poolFee;
    }

    /// @dev sets pool fee rate
    function setPoolFee(uint24 _feeRate) public onlyGovernance {
        _poolFee = _feeRate;
    }

    /// @notice sets address that fees are paid to
    function setPerformanceFeeAddress(address _feeAddress) public onlyGovernance {
        feeAddress = _feeAddress;
    }

    /// @notice sets performance fee rate
    function setPerformanceFee(uint256 _performanceFee) public onlyGovernance {
        require(_performanceFee < 2000000000, "Max fee reached");
        performanceFee = _performanceFee;
    }

    /// @dev calulcates fee given an amount and a fee rate
    function calculateFee(uint256 _amount, uint256 _feeRate)
        public
        pure
        returns (uint256 _fee)
    {
        return (_amount * _feeRate) / MAX_FLOAT_FEE;
    }
}

// License-Identifier: MIT
pragma solidity ^0.8.0;

    struct RouteParams {
        address from;
        address to;
        bool stable;
    }

interface ISolidlyRouter {

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA,uint256 amountB,uint256 liquidity);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        RouteParams calldata routes,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForTokensSimple(
        uint amountIn,
        uint amountOutMin,
        address tokenFrom,
        address tokenTo,
        bool stable,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface ISolidlyGauge {
    function earned(address token, address account) external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function deposit(uint256 amount, uint256 tokenId) external;

    function withdraw(uint256 amount) external;

    function getReward(address account, address[] memory tokens) external;

    function claimFees() external returns (uint256 claimed0, uint256 claimed1);
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
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

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
        return a + b;
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
        return a - b;
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

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
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
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;
import {Governable} from "./Governable.sol";

/**
* @title Minion
* @dev The Minion contract has an minion address, and provides basic authorization control
* functions, this simplifies the implementation of "user permissions".
*/
abstract contract Minion is Governable {
  address private _minion;
  address private _proposedMinion;

  event MinionTransferred(
    address indexed previousMinion,
    address indexed newMinion
  );

  event NewMinionProposed(
    address indexed previousMinion,
    address indexed newMinion
  );

  /**
  * @dev The Governed constructor sets the original `owner` of the contract to the sender
  * account.
  */
  constructor() {
    _minion = msg.sender;
    _proposedMinion = msg.sender;
    emit MinionTransferred(address(0), _minion);
  }

  /**
  * @return the address of the minion.
  */
  function minion() public view returns(address) {
    return _minion;
  }

  /**
  * @dev Throws if called by any account other than the minion.
  */
  modifier onlyMinion() {
    require(isMinion(), "!Minion");
    _;
  }

  /**
  * @return true if `msg.sender` is the minion of the contract.
  */
  function isMinion() public view returns(bool) {
    return msg.sender == _minion;
  }

  /**
  * @dev Allows the current minion to propose transfer of control of the contract to a new minion.
  * @param newMinion The address to transfer minion to.
  */
  function proposeMinion(address newMinion) public onlyGovernance {
    _proposeMinion(newMinion);
  }

  /**
  * @dev Proposes a new minion.
  * @param newMinion The address to propose minion to.
  */
  function _proposeMinion(address newMinion) internal {
    require(newMinion != address(0), "!address(0)");
    emit NewMinionProposed(_minion, newMinion);
    _proposedMinion = newMinion;
  }

  /**
  * @dev Transfers control of the contract to a new minion if the calling address is the same as the proposed one.
   */
  function acceptMinion() public {
    _acceptMinion();
  }

  /**
  * @dev Transfers control of the contract to a new Minion.
  */
  function _acceptMinion() internal {
    require(msg.sender == _proposedMinion, "!ProposedMinion");
    emit MinionTransferred(_minion, msg.sender);
    _minion = msg.sender;
  }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/**
* @title VaultConnected
* @dev The VaultConnected contract has a vault address, and provides basic authorization control
* functions, this simplifies the implementation of "user permissions".
*/
abstract contract VaultConnected {
  address immutable internal __vault;

  /**
  * @dev called with address to vault to connect to
  */
  constructor(address _vault) {
    __vault = _vault;
  }

  /**
  * @return the address of the vault.
  */
  function connectedVault() public view returns(address) {
    return __vault;
  }

  /**
  * @dev Throws if called by any address other than the vault.
  */
  modifier onlyVault() {
    require(isConnected(), "!isConnected");
    _;
  }

  /**
  * @return true if `msg.sender` is the connected vault.
  */
  function isConnected() public view returns(bool) {
    return msg.sender == __vault;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface ISwapRouter03 {
    function WETH9() external view returns (address);

    function approveMax(address token) external payable;

    function approveMaxMinusOne(address token) external payable;

    function approveZeroThenMax(address token) external payable;

    function approveZeroThenMaxMinusOne(address token) external payable;

    function callPositionManager(bytes memory data)
        external
        payable
        returns (bytes memory result);

    function checkOracleSlippage(
        bytes[] memory paths,
        uint128[] memory amounts,
        uint24 maximumTickDivergence,
        uint32 secondsAgo
    ) external view;

    function checkOracleSlippage(
        bytes memory path,
        uint24 maximumTickDivergence,
        uint32 secondsAgo
    ) external view;

    function exactInput(IV3SwapRouter.ExactInputParams memory params)
        external
        payable
        returns (uint256 amountOut);

    function exactInputSingle(
        IV3SwapRouter.ExactInputSingleParams memory params
    ) external payable returns (uint256 amountOut);

    function exactOutput(IV3SwapRouter.ExactOutputParams memory params)
        external
        payable
        returns (uint256 amountIn);

    function exactOutputSingle(
        IV3SwapRouter.ExactOutputSingleParams memory params
    ) external payable returns (uint256 amountIn);

    function factory() external view returns (address);

    function factoryV2() external view returns (address);

    function getApprovalType(address token, uint256 amount)
        external
        returns (uint8);

    function increaseLiquidity(
        IApproveAndCall.IncreaseLiquidityParams memory params
    ) external payable returns (bytes memory result);

    function mint(IApproveAndCall.MintParams memory params)
        external
        payable
        returns (bytes memory result);

    function multicall(bytes32 previousBlockhash, bytes[] memory data)
        external
        payable
        returns (bytes[] memory);

    function multicall(uint256 deadline, bytes[] memory data)
        external
        payable
        returns (bytes[] memory);

    function multicall(bytes[] memory data)
        external
        payable
        returns (bytes[] memory results);

    function positionManager() external view returns (address);

    function pull(address token, uint256 value) external payable;

    function refundETH() external payable;

    function selfPermit(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    function selfPermitAllowed(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    function selfPermitAllowedIfNecessary(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    function selfPermitIfNecessary(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to
    ) external payable returns (uint256 amountOut);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to
    ) external payable returns (uint256 amountIn);

    function sweepToken(
        address token,
        uint256 amountMinimum,
        address recipient
    ) external payable;

    function sweepToken(address token, uint256 amountMinimum) external payable;

    function sweepTokenWithFee(
        address token,
        uint256 amountMinimum,
        uint256 feeBips,
        address feeRecipient
    ) external payable;

    function sweepTokenWithFee(
        address token,
        uint256 amountMinimum,
        address recipient,
        uint256 feeBips,
        address feeRecipient
    ) external payable;

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory _data
    ) external;

    function unwrapWETH9(uint256 amountMinimum, address recipient)
        external
        payable;

    function unwrapWETH9(uint256 amountMinimum) external payable;

    function unwrapWETH9WithFee(
        uint256 amountMinimum,
        address recipient,
        uint256 feeBips,
        address feeRecipient
    ) external payable;

    function unwrapWETH9WithFee(
        uint256 amountMinimum,
        uint256 feeBips,
        address feeRecipient
    ) external payable;

    function wrapETH(uint256 value) external payable;

    receive() external payable;
}

interface IV3SwapRouter {
    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
}

interface IApproveAndCall {
    struct IncreaseLiquidityParams {
        address token0;
        address token1;
        uint256 tokenId;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
    }
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

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/**
* @title Governable
* @dev The Governable contract has an governance address, and provides basic authorization control
* functions, this simplifies the implementation of "user permissions".
*/
abstract contract Governable {
  address private _governance;
  address private _proposedGovernance;

  event GovernanceTransferred(
    address indexed previousGovernance,
    address indexed newGovernance
  );

  event NewGovernanceProposed(
    address indexed previousGovernance,
    address indexed newGovernance
  );

  /**
  * @dev The Governed constructor sets the original `owner` of the contract to the sender
  * account.
  */
  constructor() {
    _governance = msg.sender;
    _proposedGovernance = msg.sender;
    emit GovernanceTransferred(address(0), _governance);
  }

  /**
  * @return the address of the governance.
  */
  function governance() public view returns(address) {
    return _governance;
  }

  /**
  * @dev Throws if called by any account other than the governance.
  */
  modifier onlyGovernance() {
    require(isGovernance(), "!Governance");
    _;
  }

  /**
  * @return true if `msg.sender` is the governance of the contract.
  */
  function isGovernance() public view returns(bool) {
    return msg.sender == _governance;
  }

  /**
  * @dev Allows the current governance to propose transfer of control of the contract to a new governance.
  * @param newGovernance The address to transfer governance to.
  */
  function proposeGovernance(address newGovernance) public onlyGovernance {
    _proposeGovernance(newGovernance);
  }

  /**
  * @dev Proposes a new governance.
  * @param newGovernance The address to propose governance to.
  */
  function _proposeGovernance(address newGovernance) internal {
    require(newGovernance != address(0), "!address(0)");
    emit NewGovernanceProposed(_governance, newGovernance);
    _proposedGovernance = newGovernance;
  }

  /**
  * @dev Transfers control of the contract to a new governance if the calling address is the same as the proposed one.
   */
  function acceptGovernance() public {
    _acceptGovernance();
  }

  /**
  * @dev Transfers control of the contract to a new governance.
  */
  function _acceptGovernance() internal {
    require(msg.sender == _proposedGovernance, "!ProposedGovernance");
    emit GovernanceTransferred(_governance, msg.sender);
    _governance = msg.sender;
  }
}