// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ZapperBase} from "../../ZapperBase.sol";
import {CurveFactoryDeposit} from "../../interfaces/OptimismCurve.sol";
import {OptimismWETH} from "../../interfaces/OptimismWeth.sol";
import {ISwapRouter03, IV3SwapRouter} from "../../interfaces/Uniswap.sol";
import {IStargateRouterMaster} from "../../interfaces/Stargate.sol";

// import "hardhat/console.sol"; // TODO: Remove before deploy

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StargateZapper is ZapperBase {
    using SafeERC20 for ERC20;
    using SafeERC20 for IERC20;

    address payable public constant UNISWAPROUTER_V3_ADDRESS =
        payable(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    address public constant WETH_ADDRESS =
        0x4200000000000000000000000000000000000006;
    address public constant SUSD_ADDRESS =
        0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9;
    address public constant DAI_ADDRESS =
        0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address public constant USDC_ADDRESS =
        0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address public constant USDT_ADDRESS =
        0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;
    address public constant STARGATE_ROUTER_ADDRESS =
        address(0xB0D502E938ed5f4df2E681fE6E419ff29631d62b);

    constructor(address _vaultWant, address _vaultAddress)
        ZapperBase(_vaultWant, _vaultAddress)
    {}

    function doApprovals() public override onlyGovernance {
        IERC20(USDC_ADDRESS).safeApprove(STARGATE_ROUTER_ADDRESS, type(uint256).max);

        IERC20(SUSD_ADDRESS).safeApprove(
            UNISWAPROUTER_V3_ADDRESS,
            type(uint256).max
        );
        IERC20(DAI_ADDRESS).safeApprove(
            UNISWAPROUTER_V3_ADDRESS,
            type(uint256).max
        );
        IERC20(USDC_ADDRESS).safeApprove(
            UNISWAPROUTER_V3_ADDRESS,
            type(uint256).max
        );
        IERC20(USDT_ADDRESS).safeApprove(
            UNISWAPROUTER_V3_ADDRESS,
            type(uint256).max
        );
        IERC20(WETH_ADDRESS).safeApprove(
            UNISWAPROUTER_V3_ADDRESS,
            type(uint256).max
        );
        super.doApprovals();
    }

    function zap(address _token, uint256 _amount)
        public
        payable
        override
        returns (uint256 shares)
    {

        if (msg.value > 0) {
            OptimismWETH(WETH_ADDRESS).deposit{value: msg.value}();
        }

        if (_token != address(0) && _amount > 0) {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

            if (_token != USDC_ADDRESS) {
                ISwapRouter03(UNISWAPROUTER_V3_ADDRESS).exactInputSingle(
                    IV3SwapRouter.ExactInputSingleParams(
                        _token,
                        WETH_ADDRESS,
                        3000,
                        address(this),
                        _amount,
                        0,
                        0
                    )
                );
            }
        }

        uint256 balanceOfWeth = OptimismWETH(WETH_ADDRESS).balanceOf(
            address(this)
        );

        if (balanceOfWeth > 0) {
            ISwapRouter03(UNISWAPROUTER_V3_ADDRESS).exactInputSingle(
                IV3SwapRouter.ExactInputSingleParams(
                    WETH_ADDRESS,
                    USDC_ADDRESS,
                    3000,
                    address(this),
                    balanceOfWeth,
                    0,
                    0
                )
            );
        }

        uint256 balanceOfUSDC = OptimismWETH(USDC_ADDRESS).balanceOf(
            address(this)
        );

        // uint256 accapetableReturnAmount = calculateAcceptableReturnAmount( // TODO: not sure we need it?
        //     _amount,
        //     acceptableAddLiqReturnAmount
        // );

        IStargateRouterMaster(STARGATE_ROUTER_ADDRESS).addLiquidity(
            1,
            balanceOfUSDC,
            address(this)
        );

        shares = super.zap();
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IERC4626} from "./interfaces/EIP4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Governable} from "./Governable.sol";

abstract contract ZapperBase is Governable {
    using SafeERC20 for ERC20;

    address public immutable vaultWant;
    address public immutable vaultAddress;
    ERC20 private immutable vaultWantToken;

    uint256 public constant MAX_FLOAT_FEE = 10000000000; // 100%, 1e10 precision.
    uint256 internal acceptableAddLiqReturnAmount = 9000000000; // 1000000000 = 10%

    constructor(address _vaultWant, address _vaultAddress) {
        vaultWant = _vaultWant;
        vaultAddress = _vaultAddress;
        vaultWantToken = ERC20(_vaultWant);
    }

    function doApprovals() public virtual onlyGovernance {
        vaultWantToken.safeApprove(vaultAddress, type(uint256).max);
    }

    function zap(address _token, uint256 _amount)
        public
        payable
        virtual
        returns (uint256 shares);

    function zap() public virtual returns (uint256 shares) {
        uint256 balanceVaultWant = IERC4626(vaultWant).balanceOf(address(this));

        require(balanceVaultWant > 0, "!balanceVaultWant");

        shares = IERC4626(vaultAddress).deposit(balanceVaultWant, msg.sender);
    }

    /// @dev calculates acceptable difference, used when setting an acceptable min of return
    /// @param _amount amount to calculate percentage of
    /// @param _differenceRate percentage rate to use
    function calculateAcceptableReturnAmount(
        uint256 _amount,
        uint256 _differenceRate
    ) public pure returns (uint256 _acceptableReturn) {
        return (_amount * _differenceRate) / MAX_FLOAT_FEE;
    }

    /// @notice sets acceptable add_liquidity return amount percentage
    function setAcceptableAddLiqReturnAmount(
        uint256 _acceptableAddLiqReturnAmount
    ) public onlyGovernance {
        acceptableAddLiqReturnAmount = _acceptableAddLiqReturnAmount;
    }

    /// @dev gets acceptable add_liquidity return amount percentage
    function getAcceptableAddLiqReturnAmount() public view returns (uint256) {
        return acceptableAddLiqReturnAmount;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* solhint-disable func-name-mixedcase, var-name-mixedcase */


interface SUSDPoolContract {
  function initialize ( string memory _name, string memory _symbol, address _coin, uint256 _rate_multiplier, uint256 _A, uint256 _fee ) external;
  function decimals (  ) external view returns ( uint256 );
  function transfer ( address _to, uint256 _value ) external returns ( bool );
  function transferFrom ( address _from, address _to, uint256 _value ) external returns ( bool );
  function approve ( address _spender, uint256 _value ) external returns ( bool );
  function permit ( address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s ) external returns ( bool );
  function admin_fee (  ) external view returns ( uint256 );
  function A (  ) external view returns ( uint256 );
  function A_precise (  ) external view returns ( uint256 );
  function get_virtual_price (  ) external view returns ( uint256 );
  function calc_token_amount ( uint256[2] memory _amounts, bool _is_deposit ) external view returns ( uint256 );
  function add_liquidity ( uint256[2] memory _amounts, uint256 _min_mint_amount ) external returns ( uint256 );
  function add_liquidity ( uint256[2] memory _amounts, uint256 _min_mint_amount, address _receiver ) external returns ( uint256 );
  function get_dy ( int128 i, int128 j, uint256 dx ) external view returns ( uint256 );
  function get_dy_underlying ( int128 i, int128 j, uint256 dx ) external view returns ( uint256 );
  function exchange ( int128 i, int128 j, uint256 _dx, uint256 _min_dy ) external returns ( uint256 );
  function exchange ( int128 i, int128 j, uint256 _dx, uint256 _min_dy, address _receiver ) external returns ( uint256 );
  function exchange_underlying ( int128 i, int128 j, uint256 _dx, uint256 _min_dy ) external returns ( uint256 );
  function exchange_underlying ( int128 i, int128 j, uint256 _dx, uint256 _min_dy, address _receiver ) external returns ( uint256 );
  function remove_liquidity ( uint256 _burn_amount, uint256[2] memory _min_amounts ) external returns ( uint256[2] memory );
  function remove_liquidity ( uint256 _burn_amount, uint256[2] memory _min_amounts, address _receiver ) external returns ( uint256[2] memory );
  function remove_liquidity_imbalance ( uint256[2] memory _amounts, uint256 _max_burn_amount ) external returns ( uint256 );
  function remove_liquidity_imbalance ( uint256[2] memory _amounts, uint256 _max_burn_amount, address _receiver ) external returns ( uint256 );
  function calc_withdraw_one_coin ( uint256 _burn_amount, int128 i ) external view returns ( uint256 );
  function remove_liquidity_one_coin ( uint256 _burn_amount, int128 i, uint256 _min_received ) external returns ( uint256 );
  function remove_liquidity_one_coin ( uint256 _burn_amount, int128 i, uint256 _min_received, address _receiver ) external returns ( uint256 );
  function ramp_A ( uint256 _future_A, uint256 _future_time ) external;
  function stop_ramp_A (  ) external;
  function admin_balances ( uint256 i ) external view returns ( uint256 );
  function withdraw_admin_fees (  ) external;
  function version (  ) external view returns ( string memory);
  function coins ( uint256 arg0 ) external view returns ( address );
  function balances ( uint256 arg0 ) external view returns ( uint256 );
  function fee (  ) external view returns ( uint256 );
  function initial_A (  ) external view returns ( uint256 );
  function future_A (  ) external view returns ( uint256 );
  function initial_A_time (  ) external view returns ( uint256 );
  function future_A_time (  ) external view returns ( uint256 );
  function name (  ) external view returns ( string memory );
  function symbol (  ) external view returns ( string memory);
  function balanceOf ( address arg0 ) external view returns ( uint256 );
  function allowance ( address arg0, address arg1 ) external view returns ( uint256 );
  function totalSupply (  ) external view returns ( uint256 );
  function DOMAIN_SEPARATOR (  ) external view returns ( bytes32 );
  function nonces ( address arg0 ) external view returns ( uint256 );
}


interface CurveFactoryDeposit {
    function add_liquidity(
        address _pool,
        uint256[4] memory _deposit_amounts,
        uint256 _min_mint_amount
    ) external returns (uint256);

    function add_liquidity(
        address _pool,
        uint256[4] memory _deposit_amounts,
        uint256 _min_mint_amount,
        address _receiver
    ) external returns (uint256);

    function add_liquidity(
        uint256[3] memory _amounts,
        uint256 _min_mint_amount
    ) external returns (uint256);

    function remove_liquidity(
        address _pool,
        uint256 _burn_amount,
        uint256[4] memory _min_amounts
    ) external returns (uint256[4] memory);

    function remove_liquidity(
        address _pool,
        uint256 _burn_amount,
        uint256[4] memory _min_amounts,
        address _receiver
    ) external returns (uint256[4] memory);

    function remove_liquidity_one_coin(
        address _pool,
        uint256 _burn_amount,
        int128 i,
        uint256 _min_amount
    ) external returns (uint256);

    function remove_liquidity_one_coin(
        address _pool,
        uint256 _burn_amount,
        int128 i,
        uint256 _min_amount,
        address _receiver
    ) external returns (uint256);

    function remove_liquidity_imbalance(
        address _pool,
        uint256[4] memory _amounts,
        uint256 _max_burn_amount
    ) external returns (uint256);

    function remove_liquidity_imbalance(
        address _pool,
        uint256[4] memory _amounts,
        uint256 _max_burn_amount,
        address _receiver
    ) external returns (uint256);

    function calc_withdraw_one_coin(
        address _pool,
        uint256 _token_amount,
        int128 i
    ) external view returns (uint256);

    function calc_token_amount(
        address _pool,
        uint256[4] memory _amounts,
        bool _is_deposit
    ) external view returns (uint256);

    function fee() external view returns(uint256);
}

interface CurveGauge {
    function deposit(uint256 _value) external;

    function deposit(uint256 _value, address _user) external;

    function deposit(
        uint256 _value,
        address _user,
        bool _claim_rewards
    ) external;

    function withdraw(uint256 _value) external;

    function withdraw(uint256 _value, address _user) external;

    function withdraw(
        uint256 _value,
        address _user,
        bool _claim_rewards
    ) external;

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool);

    function approve(address _spender, uint256 _value) external returns (bool);

    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (bool);

    function transfer(address _to, uint256 _value) external returns (bool);

    function increaseAllowance(address _spender, uint256 _added_value)
        external
        returns (bool);

    function decreaseAllowance(address _spender, uint256 _subtracted_value)
        external
        returns (bool);

    function user_checkpoint(address addr) external returns (bool);

    function claimable_tokens(address addr) external returns (uint256);

    function claimed_reward(address _addr, address _token)
        external
        view
        returns (uint256);

    function claimable_reward(address _user, address _reward_token)
        external
        view
        returns (uint256);

    function set_rewards_receiver(address _receiver) external;

    function claim_rewards() external;

    function claim_rewards(address _addr) external;

    function claim_rewards(address _addr, address _receiver) external;

    function add_reward(address _reward_token, address _distributor) external;

    function set_reward_distributor(address _reward_token, address _distributor)
        external;

    function deposit_reward_token(address _reward_token, uint256 _amount)
        external;

    function set_manager(address _manager) external;

    function update_voting_escrow() external;

    function set_killed(bool _is_killed) external;

    function decimals() external view returns (uint256);

    function integrate_checkpoint() external view returns (uint256);

    function version() external view returns (string memory);

    function factory() external view returns (address);

    function initialize(address _lp_token, address _manager) external;

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function nonces(address arg0) external view returns (uint256);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function allowance(address arg0, address arg1)
        external
        view
        returns (uint256);

    function balanceOf(address arg0) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function lp_token() external view returns (address);

    function manager() external view returns (address);

    function voting_escrow() external view returns (address);

    function working_balances(address arg0) external view returns (uint256);

    function working_supply() external view returns (uint256);

    function period() external view returns (uint256);

    function period_timestamp(uint256 arg0) external view returns (uint256);

    function integrate_checkpoint_of(address arg0)
        external
        view
        returns (uint256);

    function integrate_fraction(address arg0) external view returns (uint256);

    function integrate_inv_supply(uint256 arg0) external view returns (uint256);

    function integrate_inv_supply_of(address arg0)
        external
        view
        returns (uint256);

    function reward_count() external view returns (uint256);

    function reward_tokens(uint256 arg0) external view returns (address);

    //   function reward_data ( address arg0 ) external view returns ( tuple );
    function rewards_receiver(address arg0) external view returns (address);

    function reward_integral_for(address arg0, address arg1)
        external
        view
        returns (uint256);

    function is_killed() external view returns (bool);

    function inflation_rate(uint256 arg0) external view returns (uint256);
}

interface CRVTokenContract {
  function mint ( address _gauge ) external;
  function mint_many (address[32] memory _gauges ) external;
  function deploy_gauge ( address _lp_token, bytes32 _salt ) external returns ( address );
  function deploy_gauge ( address _lp_token, bytes32 _salt, address _manager ) external returns ( address );
  function set_voting_escrow ( address _voting_escrow ) external;
  function set_implementation ( address _implementation ) external;
  function set_mirrored ( address _gauge, bool _mirrored ) external;
  function set_call_proxy ( address _new_call_proxy ) external;
  function commit_transfer_ownership ( address _future_owner ) external;
  function accept_transfer_ownership (  ) external;
  function is_valid_gauge ( address _gauge ) external view returns ( bool );
  function is_mirrored ( address _gauge ) external view returns ( bool );
  function last_request ( address _gauge ) external view returns ( uint256 );
  function get_implementation (  ) external view returns ( address );
  function voting_escrow (  ) external view returns ( address );
  function owner (  ) external view returns ( address );
  function future_owner (  ) external view returns ( address );
  function call_proxy (  ) external view returns ( address );
  function gauge_data ( address arg0 ) external view returns ( uint256 );
  function minted ( address arg0, address arg1 ) external view returns ( uint256 );
  function get_gauge_from_lp_token ( address arg0 ) external view returns ( address );
  function get_gauge_count (  ) external view returns ( uint256 );
  function get_gauge ( uint256 arg0 ) external view returns ( address );
}

/* solhint-enable func-name-mixedcase, var-name-mixedcase */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface OptimismWETH {
  function allowance ( address, address ) external view returns ( uint256 );
  function approve ( address guy, uint256 wad ) external returns ( bool );
  function balanceOf ( address ) external view returns ( uint256 );
  function decimals (  ) external view returns ( uint8 );
  function deposit (  ) external payable;
  function name (  ) external view returns (string memory);
  function symbol (  ) external view returns (string memory);
  function totalSupply (  ) external view returns ( uint256 );
  function transfer ( address dst, uint256 wad ) external returns ( bool );
  function transferFrom ( address src, address dst, uint256 wad ) external returns ( bool );
  function withdraw ( uint256 wad ) external;
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

// SPDX-License-Identifier: UNLICENSED
// !! THIS FILE WAS AUTOGENERATED BY abi-to-sol v0.6.5. SEE SOURCE BELOW. !!
pragma solidity >=0.7.0 <0.9.0;

interface IStargateFarm {
    event Add(uint256 allocPoint, address indexed lpToken);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event Set(uint256 indexed pid, uint256 allocPoint);
    event TokensPerSec(uint256 eTokenPerSecond);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    function BONUS_MULTIPLIER() external view returns (uint256);

    function add(uint256 _allocPoint, address _lpToken) external;

    function bonusEndTime() external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;

    function eToken() external view returns (address);

    function eTokenPerSecond() external view returns (uint256);

    function emergencyWithdraw(uint256 _pid) external;

    function getMultiplier(uint256 _from, uint256 _to)
    external
    view
    returns (uint256);

    function lpBalances(uint256) external view returns (uint256);

    function massUpdatePools() external;

    function owner() external view returns (address);

    function pendingEmissionToken(uint256 _pid, address _user)
    external
    view
    returns (uint256);

    function poolInfo(uint256)
    external
    view
    returns (
        address lpToken,
        uint256 allocPoint,
        uint256 lastRewardTime,
        uint256 accEmissionPerShare
    );

    function poolLength() external view returns (uint256);

    function renounceOwnership() external;

    function set(uint256 _pid, uint256 _allocPoint) external;

    function setETokenPerSecond(uint256 _eTokenPerSecond) external;

    function startTime() external view returns (uint256);

    function totalAllocPoint() external view returns (uint256);

    function transferOwnership(address newOwner) external;

    function updatePool(uint256 _pid) external;

    function userInfo(uint256, address)
    external
    view
    returns (uint256 amount, uint256 rewardDebt);

    function withdraw(uint256 _pid, uint256 _amount) external;
}

interface IStargateRouterMaster {
    event CachedSwapSaved(
        uint16 chainId,
        bytes srcAddress,
        uint256 nonce,
        address token,
        uint256 amountLD,
        address to,
        bytes payload,
        bytes reason
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event RedeemLocalCallback(
        uint16 srcChainId,
        bytes indexed srcAddress,
        uint256 indexed nonce,
        uint256 srcPoolId,
        uint256 dstPoolId,
        address to,
        uint256 amountSD,
        uint256 mintAmountSD
    );
    event Revert(
        uint8 bridgeFunctionType,
        uint16 chainId,
        bytes srcAddress,
        uint256 nonce
    );
    event RevertRedeemLocal(
        uint16 srcChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        bytes to,
        uint256 redeemAmountSD,
        uint256 mintAmountSD,
        uint256 indexed nonce,
        bytes indexed srcAddress
    );

    function activateChainPath(
        uint256 _poolId,
        uint16 _dstChainId,
        uint256 _dstPoolId
    ) external;

    function addLiquidity(
        uint256 _poolId,
        uint256 _amountLD,
        address _to
    ) external;

    function bridge() external view returns (address);

    function cachedSwapLookup(
        uint16,
        bytes memory,
        uint256
    )
    external
    view
    returns (
        address token,
        uint256 amountLD,
        address to,
        bytes memory payload
    );

    function callDelta(uint256 _poolId, bool _fullMode) external;

    function clearCachedSwap(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint256 _nonce
    ) external;

    function createChainPath(
        uint256 _poolId,
        uint16 _dstChainId,
        uint256 _dstPoolId,
        uint256 _weight
    ) external;

    function createPool(
        uint256 _poolId,
        address _token,
        uint8 _sharedDecimals,
        uint8 _localDecimals,
        string memory _name,
        string memory _symbol
    ) external returns (address);

    function creditChainPath(
        uint16 _dstChainId,
        uint256 _dstPoolId,
        uint256 _srcPoolId,
        Pool.CreditObj memory _c
    ) external;

    function factory() external view returns (address);

    function instantRedeemLocal(
        uint16 _srcPoolId,
        uint256 _amountLP,
        address _to
    ) external returns (uint256 amountSD);

    function mintFeeOwner() external view returns (address);

    function owner() external view returns (address);

    function protocolFeeOwner() external view returns (address);

    function quoteLayerZeroFee(
        uint16 _dstChainId,
        uint8 _functionType,
        bytes memory _toAddress,
        bytes memory _transferAndCallPayload,
        IStargateRouter.lzTxObj memory _lzTxParams
    ) external view returns (uint256, uint256);

    function redeemLocal(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address _refundAddress,
        uint256 _amountLP,
        bytes memory _to,
        IStargateRouter.lzTxObj memory _lzTxParams
    ) external payable;

    function redeemLocalCallback(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint256 _nonce,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address _to,
        uint256 _amountSD,
        uint256 _mintAmountSD
    ) external;

    function redeemLocalCheckOnRemote(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint256 _nonce,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        uint256 _amountSD,
        bytes memory _to
    ) external;

    function redeemRemote(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address _refundAddress,
        uint256 _amountLP,
        uint256 _minAmountLD,
        bytes memory _to,
        IStargateRouter.lzTxObj memory _lzTxParams
    ) external payable;

    function renounceOwnership() external;

    function retryRevert(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint256 _nonce
    ) external payable;

    function revertLookup(
        uint16,
        bytes memory,
        uint256
    ) external view returns (bytes memory);

    function revertRedeemLocal(
        uint16 _dstChainId,
        bytes memory _srcAddress,
        uint256 _nonce,
        address _refundAddress,
        IStargateRouter.lzTxObj memory _lzTxParams
    ) external payable;

    function sendCredits(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address _refundAddress
    ) external payable;

    function setBridgeAndFactory(address _bridge, address _factory) external;

    function setDeltaParam(
        uint256 _poolId,
        bool _batched,
        uint256 _swapDeltaBP,
        uint256 _lpDeltaBP,
        bool _defaultSwapMode,
        bool _defaultLPMode
    ) external;

    function setFeeLibrary(uint256 _poolId, address _feeLibraryAddr) external;

    function setFees(uint256 _poolId, uint256 _mintFeeBP) external;

    function setMintFeeOwner(address _owner) external;

    function setProtocolFeeOwner(address _owner) external;

    function setSwapStop(uint256 _poolId, bool _swapStop) external;

    function setWeightForChainPath(
        uint256 _poolId,
        uint16 _dstChainId,
        uint256 _dstPoolId,
        uint16 _weight
    ) external;

    function swap(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address _refundAddress,
        uint256 _amountLD,
        uint256 _minAmountLD,
        IStargateRouter.lzTxObj memory _lzTxParams,
        bytes memory _to,
        bytes memory _payload
    ) external payable;

    function swapRemote(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint256 _nonce,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        uint256 _dstGasForCall,
        address _to,
        Pool.SwapObj memory _s,
        bytes memory _payload
    ) external;

    function transferOwnership(address newOwner) external;

    function withdrawMintFee(uint256 _poolId, address _to) external;

    function withdrawProtocolFee(uint256 _poolId, address _to) external;
}

interface Pool {
    struct CreditObj {
        uint256 credits;
        uint256 idealBalance;
    }

    struct SwapObj {
        uint256 amount;
        uint256 eqFee;
        uint256 eqReward;
        uint256 lpFee;
        uint256 protocolFee;
        uint256 lkbRemove;
    }
}

interface IStargateRouter {
    struct lzTxObj {
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
        bytes dstNativeAddr;
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
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

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
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
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
        _approve(owner, spender, _allowances[owner][spender] + addedValue);
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
        uint256 currentAllowance = _allowances[owner][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
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
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
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
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Spend `amount` form the allowance of `owner` toward `spender`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
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
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

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
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IERC4626 is IERC20, IERC20Metadata {
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * @dev Returns the address of the underlying token used for the Vault for accounting, depositing, and withdrawing.
     *
     * - MUST be an ERC-20 token contract.
     * - MUST NOT revert.
     */
    function asset() external view returns (address assetTokenAddress);

    /**
     * @dev Returns the total amount of the underlying asset that is “managed” by Vault.
     *
     * - SHOULD include any compounding that occurs from yield.
     * - MUST be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT revert.
     */
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /**
     * @dev Returns the amount of shares that the Vault would exchange for the amount of assets provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
     * from.
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Returns the amount of assets that the Vault would exchange for the amount of shares provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
     * from.
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be deposited into the Vault for the receiver,
     * through a deposit call.
     *
     * - MUST return a limited value if receiver is subject to some deposit limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be deposited.
     * - MUST NOT revert.
     */
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of Vault shares that would be minted in a deposit
     *   call in the same transaction. I.e. deposit should return the same or more shares as previewDeposit if called
     *   in the same transaction.
     * - MUST NOT account for deposit limits like those returned from maxDeposit and should always act as though the
     *   deposit would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewDeposit SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Mints shares Vault shares to receiver by depositing exactly amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   deposit execution, and are accounted for during deposit.
     * - MUST revert if all of assets cannot be deposited (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @dev Returns the maximum amount of the Vault shares that can be minted for the receiver, through a mint call.
     * - MUST return a limited value if receiver is subject to some mint limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of shares that may be minted.
     * - MUST NOT revert.
     */
    function maxMint(address receiver) external view returns (uint256 maxShares);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of assets that would be deposited in a mint call
     *   in the same transaction. I.e. mint should return the same or fewer assets as previewMint if called in the
     *   same transaction.
     * - MUST NOT account for mint limits like those returned from maxMint and should always act as though the mint
     *   would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewMint SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by minting.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Mints exactly shares Vault shares to receiver by depositing amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the mint
     *   execution, and are accounted for during mint.
     * - MUST revert if all of shares cannot be minted (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
     * Vault, through a withdraw call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST NOT revert.
     */
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of Vault shares that would be burned in a withdraw
     *   call in the same transaction. I.e. withdraw should return the same or fewer shares as previewWithdraw if
     *   called
     *   in the same transaction.
     * - MUST NOT account for withdrawal limits like those returned from maxWithdraw and should always act as though
     *   the withdrawal would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewWithdraw SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Burns shares from owner and sends exactly assets of underlying tokens to receiver.
     *
     * - MUST emit the Withdraw event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   withdraw execution, and are accounted for during withdraw.
     * - MUST revert if all of assets cannot be withdrawn (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * Note that some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    /**
     * @dev Returns the maximum amount of Vault shares that can be redeemed from the owner balance in the Vault,
     * through a redeem call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST return balanceOf(owner) if owner is not subject to any withdrawal limit or timelock.
     * - MUST NOT revert.
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their redeemption at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of assets that would be withdrawn in a redeem call
     *   in the same transaction. I.e. redeem should return the same or more assets as previewRedeem if called in the
     *   same transaction.
     * - MUST NOT account for redemption limits like those returned from maxRedeem and should always act as though the
     *   redemption would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewRedeem SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by redeeming.
     */
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Burns exactly shares from owner and sends assets of underlying tokens to receiver.
     *
     * - MUST emit the Withdraw event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   redeem execution, and are accounted for during redeem.
     * - MUST revert if all of shares cannot be redeemed (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * NOTE: some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

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