// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;
import {BasicStrategy} from "../BasicStrategy.sol";
import {CurveFactoryDeposit, CurveGauge, SUSDPoolContract, CRVTokenContract} from "../../interfaces/OptimismCurve.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title CurveSusdStrategy
 * @dev Defined strategy(I.e susd curve pool) that inherits structure and functionality from BasicStrategy
 */
contract CurveSusdStrategy is BasicStrategy {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address private _curveFactoryDepositAddress =
        address(0x167e42a1C7ab4Be03764A2222aAC57F5f6754411);
    address private _sUSDCurve3PoolToken =
        address(0x061b87122Ed14b9526A813209C8a59a633257bAb);
    address private _sUSDCurve3GaugeDeposit =
        address(0xc5aE4B5F86332e70f3205a8151Ee9eD9F71e0797);
    address private _sUSDPoolContractAddress =
        address(0x061b87122Ed14b9526A813209C8a59a633257bAb); // todo: same as _sUSDCurve3PoolToken... refactor
    address private _sUSDPoolCRVTokenContractAddress =
        address(0xabC000d88f23Bb45525E447528DBF656A9D55bf5);
    int128 private _tokenIndex = 0;

    constructor(address _vault, address _wantToken)
        BasicStrategy(_vault, _wantToken)
    {}

    /// @return name of the strategy
    function getName() external pure override returns (string memory) {
        return "CurveSUSDStrategy";
    }

    /// @dev pre approves max
    function doApprovals() public {
        IERC20(want()).safeApprove(
            _curveFactoryDepositAddress,
            type(uint256).max
        );
        IERC20(_sUSDCurve3PoolToken).safeApprove(
            _sUSDCurve3GaugeDeposit,
            type(uint256).max
        );
        IERC20(_sUSDCurve3PoolToken).safeApprove(
            _curveFactoryDepositAddress,
            type(uint256).max
        );
    }

    /// @notice gives an estimate of tokens invested
    function balanceOfPool() public view override returns (uint256) {
        uint256 balanceOfGaugeToken = IERC20(_sUSDCurve3GaugeDeposit).balanceOf(
            address(this)
        ); // get shares

        if (balanceOfGaugeToken == 0) {
            return 0;
        }

        uint256 amountInSUSD = CurveFactoryDeposit(_curveFactoryDepositAddress)
            .calc_withdraw_one_coin(
                _sUSDCurve3PoolToken,
                balanceOfGaugeToken,
                _tokenIndex
            );
        return amountInSUSD;
    }

    /// @notice invests available funds
    function deposit() public override onlyGovernance {
        uint256 availableFundsToDeposit = getAvailableFunds();

        require(availableFundsToDeposit > 0, "No funds available");

        uint256[4] memory fundsToDeposit;
        fundsToDeposit = [uint256(availableFundsToDeposit), 0, 0, 0];
        uint256 accapetableReturnAmount = calculateAcceptableDifference(
            availableFundsToDeposit,
            100
        ); // 100 = 1%

        CurveFactoryDeposit(_curveFactoryDepositAddress).add_liquidity(
            _sUSDCurve3PoolToken,
            fundsToDeposit,
            accapetableReturnAmount
        );

        uint256 balanceCurveToken = IERC20(_sUSDCurve3PoolToken).balanceOf(
            address(this)
        );

        require(balanceCurveToken > 0, "!balanceCurveToken");

        CurveGauge(_sUSDCurve3GaugeDeposit).deposit(balanceCurveToken);
    }

    function getCurveFee() public view returns (uint256) {
        uint256 curveFeee = SUSDPoolContract(_sUSDPoolContractAddress).fee();
        return curveFeee;
    }

    function getAdminFee() public view returns (uint256) {
        uint256 adminFee = SUSDPoolContract(_sUSDPoolContractAddress)
            .admin_fee();
        return adminFee;
    }

    /// @notice withdraws all from pool to strategy where the funds can safetly be withdrawn by it's owners
    /// @dev this is only to be allowed by governance and should only be used in the event of a strategy or pool not functioning correctly/getting discontinued etc
    function withdrawAll() public override onlyGovernance {
        uint256 balanceOfGaugeToken = IERC20(_sUSDCurve3GaugeDeposit).balanceOf(
            address(this)
        ); // get shares

        if (balanceOfGaugeToken > 0) {
            // doing this instead of require since there is a risk of funds getting locked in otherwise
            CurveGauge(_sUSDCurve3GaugeDeposit).withdraw(balanceOfGaugeToken);
        }

        uint256 balanceOfCurveToken = IERC20(_sUSDCurve3PoolToken).balanceOf(
            address(this)
        );

        require(balanceOfCurveToken > 0, "Nothing to withdraw");

        CurveFactoryDeposit(_curveFactoryDepositAddress)
            .remove_liquidity_one_coin(
                _sUSDCurve3PoolToken,
                balanceOfCurveToken,
                0,
                balanceOfCurveToken // TODO: what is min we accept back?
            );
    }

    /// @notice withdraws a certain amount from the pool
    /// @dev can only be called from inside the contract through the withdraw function which is protected by only vault modifier
    function _withdrawAmount(uint256 _amount)
        internal
        override
        onlyVault
        returns (uint256)
    {
        // TODO: we need to think about what min return we should expect and how to deal with that if it's not enough
        uint256 beforeWithdraw = getAvailableFunds();

        uint256 balanceOfPoolAmount = balanceOfPool();

        if (_amount > balanceOfPoolAmount) {
            _amount = balanceOfPoolAmount;
        }

        uint256[4] memory fundsToWithdraw = [uint256(_amount), 0, 0, 0];

        uint256 neededCRVTokens = CurveFactoryDeposit(
            _curveFactoryDepositAddress
        ).calc_token_amount(_sUSDCurve3PoolToken, fundsToWithdraw, false);

        uint256 balanceOfGaugeToken = IERC20(_sUSDCurve3GaugeDeposit).balanceOf(
            address(this)
        ); // get shares

        require(balanceOfGaugeToken >= neededCRVTokens, "not enough funds");

        CurveGauge(_sUSDCurve3GaugeDeposit).withdraw(neededCRVTokens);

        CurveFactoryDeposit(_curveFactoryDepositAddress)
            .remove_liquidity_one_coin(
                _sUSDCurve3PoolToken,
                neededCRVTokens,
                _tokenIndex,
                neededCRVTokens
            );

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

        uint256 amountThatWasWithdrawn = _withdrawAmount(_amount);

        IERC20(wantToken).safeTransfer(__vault, amountThatWasWithdrawn);
        return amountThatWasWithdrawn;
    }

    /// @notice harvests rewards, sells them for want and reinvests them
    function harvestAndReinvest() public override onlyGovernance {
        // CurveGauge(_sUSDCurve3GaugeDeposit).claim_rewards(); // TODO: is this really needed?
        CRVTokenContract(_sUSDPoolCRVTokenContractAddress).mint(_sUSDCurve3GaugeDeposit);
        super.harvestAndReinvest();
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Governable} from "../Governable.sol";
import {VaultConnected} from "../VaultConnected.sol";
import {ISwapRouter03, IV3SwapRouter} from "../interfaces/Uniswap.sol";
// import "hardhat/console.sol"; // TODO: Remove before deploy

/**
 * @title BasicStrategy
 * @dev Defines structure and basic functionality of strategies
 */
contract BasicStrategy is VaultConnected, Governable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public immutable wantToken;

    address[] public rewards;

    uint256 private _depositFee;
    uint256 private _withdrawFee;
    uint24 private _poolFee = 3000;
    uint256 public performanceFee = 0;
    address public feeAddress = 0x000000000000000000000000000000000000dEaD; // address to pay fees to TODO: Remove burn
    uint256 public constant MAX_FLOAT_FEE = 10000000000; // 100%, 1e10 precision.
    uint256 public lifetimeEarned = 0;

    address payable public univ3Router2 =
        payable(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    address public test = 0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53;
    mapping(address => bool) private approvedTokens;

    // not sure we need indexed
    event HarvestAndReinvest(
        uint256 indexed amountTraded,
        uint256 indexed amountReceived
    );

    event Harvest(uint256 wantEarned, uint256 lifetimeEarned);

    constructor(address _vault, address _wantToken) VaultConnected(_vault) {
        wantToken = _wantToken;
    }

    /// @return name of the strategy
    function getName() external pure virtual returns (string memory) {
        return "BasicStrategy";
    }

    /// @notice invests available funds
    function deposit() public virtual onlyGovernance {
        // should invest all available tokens, TODO: should mock a curve pool...
    }

    /// @notice withdraws all from pool to strategy where the funds can safetly be withdrawn by it's owners
    /// @dev this is only to be allowed by governance and should only be used in the event of a strategy or pool not functioning correctly/getting discontinued etc
    function withdrawAll() public virtual onlyGovernance {
        // should withdraw all tokens, TODO: should mock a curve pool...
    }

    /// @notice withdraws a certain amount from the pool
    /// @dev can only be called from inside the contract through the withdraw function which is protected by only vault modifier (TODO: need to measure gas cost of having a extra modifier on this, might be overkill)
    function _withdrawAmount(uint256 _amount)
        internal
        virtual
        onlyVault
        returns (uint256)
    {
        // should withdraw amount of tokens, TODO: should mock a curve pool...
    }

    /// @dev returns nr of funds that are not yet invested
    function getAvailableFunds() public view returns (uint256) {
        return IERC20(wantToken).balanceOf(address(this));
    }

    /// @notice gives an estimate of tokens invested
    /// @dev returns an estimate of tokens invested
    function balanceOfPool() public view virtual returns (uint256) {
        return 0;
    }

    /// @notice gets the total amount of funds held by this strategy
    /// @dev returns total amount of available and invested funds
    function getTotalBalance() public view returns (uint256) {
        uint256 investedFunds = balanceOfPool();
        uint256 availableFunds = getAvailableFunds();

        return investedFunds.add(availableFunds);
    }

    /// @notice sells rewards for want and reinvests them
    function harvestAndReinvest() public virtual onlyGovernance {
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
                        wantToken
                    ),
                    recipient: address(this),
                    amountIn: balanceOfCurrentReward,
                    amountOutMinimum: 0
                })
            );

            /// @notice Keep this in so you get paid!
            if (performanceFee > 0 && amountOut > 0) {
                uint256 _fee = _calculateFee(amountOut, performanceFee);
                IERC20(wantToken).safeTransfer(feeAddress, _fee);
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
        // TODO: test thorougly, how much gas do we actually save by using existing empty space?

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

    /// @dev returns deposit fee rate
    function getDepositFee() public view returns (uint256) {
        return _depositFee;
    }

    /// @dev sets deposit fee rate
    function setDepositFee(uint256 _feeRate) public onlyGovernance {
        require(_feeRate < 300000000, "Max fee reached");
        _depositFee = _feeRate;
    }

    /// @dev gets withdraw fee rate
    function getWithdrawFee() public view returns (uint256) {
        return _withdrawFee;
    }

    /// @dev sets withdraw fee rate
    function setWithdrawFee(uint256 _feeRate) public onlyGovernance {
        require(_feeRate < 300000000, "Max fee reached");
        _withdrawFee = _feeRate;
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
        require(_depositFee < 300000000, "Max fee reached");
        performanceFee = _performanceFee;
    }

    /// @dev calulcates fee given an amount and a fee rate
    function _calculateFee(uint256 _amount, uint256 _feeRate)
        internal
        pure
        returns (uint256 _fee)
    {
        return (_amount * _feeRate) / MAX_FLOAT_FEE;
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