// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ControllerStratAbs.sol";
import "../interfaces/ICurve.sol";

interface IUniswapV3 {
  struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

contract ControllerMetaCurveStrat is ControllerStratAbs {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;

    IERC20Metadata public immutable crvToken;
    address public immutable metaPool;
    address public immutable pool;
    ICurveGauge public immutable gauge;
    ICurveGaugeFactory public immutable gaugeFactory;

    int128 private immutable poolSize;
    int128 private immutable tokenIndex; // want token index on the pool

    uint8 private immutable gaugeType;
    uint8 private constant GAUGE_TYPE_STAKING = 0;
    uint8 private constant GAUGE_TYPE_CHILD_STAKING = 1;

    // UniswapV3 has different fees between each pool (Commonly is 0.3% but can be 0.1% or 1%
    mapping(address => mapping(address => uint24)) public tokenToTokenSwapFee;

    error PoolSizeZero();
    error InvalidIndex();

    constructor(
        IERC20Metadata _want,
        address _controller,
        address _exchange,
        address _treasury,
        IERC20Metadata _crvToken,
        address _pool,
        address _metaPool,
        ICurveGauge _gauge,
        ICurveGaugeFactory _gaugeFactory,
        uint8 _gaugeType,
        int128 _poolSize,
        int128 _tokenIndex
    ) ControllerStratAbs(_want, _controller, _exchange, _treasury) {
        require(_pool != address(0), "pool !ZeroAddress");
        require(_metaPool != address(0), "metaPool !ZeroAddress");
        require(address(_gauge) != address(0), "gauge !ZeroAddress");
        require(address(_gaugeFactory) != address(0), "gaugeFactory !ZeroAddress");
        require(_gaugeType < 2, "gaugeType unknown");

        _checkIERC20(_crvToken, "Invalid crvToken");
        // Check gauge _behaves_ as a gauge
        _gauge.claimable_tokens(address(this));
        // Check gauge factory _behaves_ as a gauge factory
        _gaugeFactory.minted(address(this), address(this));

        // poolSize = ICurvePool(_pool).N_ALL_COINS();
        if (_poolSize <= 0) { revert PoolSizeZero(); }

        poolSize     = _poolSize;
        crvToken     = _crvToken;
        pool         = _pool;
        metaPool     = _metaPool;
        gauge        = _gauge;
        gaugeFactory = _gaugeFactory;
        gaugeType    = _gaugeType;
        tokenIndex   = _tokenIndex;
    }

    function identifier() external view returns (string memory) {
        return string(abi.encodePacked(want.symbol(), "@Curve#1.0.0"));
    }

    function wantCRVBalance() public view returns (uint) {
        return crvToken.balanceOf(address(this));
    }

    function balanceOfPool() public view override returns (uint) {
        return gauge.balanceOf(address(this));
    }

    function balanceOfPoolInWant() public view override returns (uint) {
        return _calcWithdrawOneCoin(balanceOfPool());
    }

    function setTokenToTokenSwapFee(address _tokenA, address _tokenB, uint24 _fee) external onlyAdmin {
        require(_tokenA != address(0), "!ZeroAddress tokenA");
        require(_tokenB != address(0), "!ZeroAddress tokenB");
        require(_fee >= 0, "Fee can't be negative");

        tokenToTokenSwapFee[_tokenA][_tokenB] = _fee;
    }

    function _deposit() internal override {
        uint _wantBal = wantBalance();

        if (_wantBal > 0) { _addLiquidity(_wantBal); }

        uint _wantCRVBalance = wantCRVBalance();

        if (_wantCRVBalance > 0) {
            crvToken.safeApprove(address(gauge), _wantCRVBalance);
            gauge.deposit(_wantCRVBalance);
        }
    }

    function _addLiquidity(uint _wantBal) internal {
        uint _expected = _wantToWantCrvDoubleCheck(_wantBal, true);

        if (poolSize == 2) {
            uint[2] memory _amounts;

            _amounts[uint(uint128(tokenIndex))] = _wantBal;

            want.safeApprove(pool, _wantBal);
            ICurvePool(pool).add_liquidity(metaPool, _amounts, _expected, true);
        } else if (poolSize == 4) {
            uint[4] memory _amounts;

            _amounts[uint(uint128(tokenIndex))] = _wantBal;

            want.safeApprove(pool, _wantBal);
            ICurvePool(pool).add_liquidity(metaPool, _amounts, _expected);
        }
    }

    function _withdraw(uint _amount) internal override returns (uint) {
        uint _balance = wantBalance();

        _withdrawFromPool(
            _wantToWantCrvDoubleCheck(_amount - _balance, false)
        );

        uint _withdrawn = wantBalance() - _balance;

        return (_withdrawn > _amount) ? _amount : _withdrawn;
    }

    function _withdrawAll() internal override returns (uint) {
        uint _balance = wantBalance();

        _withdrawFromPool(balanceOfPool());

        return wantBalance() - _balance;
    }

    function _withdrawFromPool(uint _wantCrvAmount) internal {
        // Remove staked from gauge
        gauge.withdraw(_wantCrvAmount);

        // remove_liquidity
        uint _balance = wantCRVBalance();
        uint _expected = _wantCrvToWantDoubleCheck(_balance);

        require(_expected > 0, "remove_liquidity expected = 0");

        crvToken.safeApprove(pool, _balance);
        ICurvePool(pool).remove_liquidity_one_coin(metaPool, _balance, tokenIndex, _expected);
    }

    function _claimRewards() internal override {
        // CRV rewards
        if (gauge.claimable_tokens(address(this)) > 0) {
            gaugeFactory.mint(address(gauge));
        }

        // no-CRV rewards
        bool _claim = false;

        if (gaugeType == GAUGE_TYPE_STAKING) {
            if (gauge.claimable_reward(address(this)) > 0) {
                _claim = true;
            }
        } else if (gaugeType == GAUGE_TYPE_CHILD_STAKING) {
            for (uint i = 0; i < gauge.reward_count(); i++) {
                address _reward = gauge.reward_tokens(i);

                if (gauge.claimable_reward(address(this), _reward) > 0) {
                    _claim = true;
                    break;
                }
            }
        }

        if (_claim) { gauge.claim_rewards(); }
    }

    function _minWantToWantCrv(uint _amount) internal view returns (uint) {
        // Based on virtual_price (poolMinVirtualPrice) and poolSlippageRatio
        // the expected amount is represented with 18 decimals as crvWant token
        // so we have to add 12 decimals (on USDC and USDT for example) to the want balance.
        // E.g. 1e6 (1WANT) * 1e12 * 99.4 / 100.0 => 0.994e18 crvToken tokens
        return _amount * WANT_MISSING_PRECISION * (RATIO_PRECISION - poolSlippageRatio - poolMinVirtualPrice) / RATIO_PRECISION;
    }

    function _wantToWantCrvDoubleCheck(uint _amount, bool _isDeposit) internal view returns (uint _wantCrvAmount) {
        if (poolSize == 2) {
            uint[2] memory _amounts;

            _amounts[uint(uint128(tokenIndex))] = _amount;
            // calc_token_amount doesn't consider fee
            _wantCrvAmount = ICurvePool(pool).calc_token_amount(metaPool, _amounts, _isDeposit);
        } else if (poolSize == 4) {
            uint[4] memory _amounts;

            _amounts[uint(uint128(tokenIndex))] = _amount;
            // calc_token_amount doesn't consider fee
            _wantCrvAmount = ICurvePool(pool).calc_token_amount(metaPool, _amounts, _isDeposit);
        }

        // Remove max fee
        _wantCrvAmount = _wantCrvAmount * (RATIO_PRECISION - poolSlippageRatio) / RATIO_PRECISION;

        // In case the pool is unbalanced (attack), make a double check for
        // the expected amount with minExpected set ratios.
        uint _wantToWantCrv = _minWantToWantCrv(_amount);

        if (_wantToWantCrv > _wantCrvAmount) { _wantCrvAmount = _wantToWantCrv; }
    }

    // Calculate at least xx% of the expected. The function doesn't
    // consider the fee.
    function _wantCrvToWantDoubleCheck(uint _balance) internal view returns (uint _expected) {
        _expected = (
            _calcWithdrawOneCoin(_balance) * (RATIO_PRECISION - poolSlippageRatio)
        ) / RATIO_PRECISION;

        // Double check for expected value
        // In this case we sum the poolMinVirtualPrice and divide by
        // (for example) 1e12 because we want to swap crvToken => WANT
        uint _minExpected = _balance *
            (RATIO_PRECISION + poolMinVirtualPrice - poolSlippageRatio) /
            RATIO_PRECISION /
            WANT_MISSING_PRECISION;

        if (_minExpected > _expected) { _expected = _minExpected; }
    }

    function _calcWithdrawOneCoin(uint _amount) internal view returns (uint) {
        if (_amount > 0) {
            return ICurvePool(pool).calc_withdraw_one_coin(metaPool, _amount, tokenIndex);
        } else {
            return 0;
        }
    }

    // UniswapV3
    function _swapRewards() internal override {
        for (uint i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            uint _balance = IERC20Metadata(rewardToken).balanceOf(address(this));

            if (_balance > 0) {
                uint expected = _expectedForSwap(_balance, rewardToken, address(want));

                // Want price sometimes is too high so it requires a lot of rewards to swap
                if (expected > 1) {
                    IERC20Metadata(rewardToken).safeApprove(exchange, _balance);

                    bytes memory _path = abi.encodePacked(rewardToken);

                    for (uint j = 1; j < rewardToWantRoute[rewardToken].length; j++) {
                        uint24 _fee = tokenToTokenSwapFee[rewardToWantRoute[rewardToken][j - 1]][rewardToWantRoute[rewardToken][j]];

                        _path = abi.encodePacked(
                            _path,
                            _fee,
                            rewardToWantRoute[rewardToken][j]
                        );
                    }

                    IUniswapV3(exchange).exactInput(IUniswapV3.ExactInputParams({
                        path: _path,
                        recipient: address(this),
                        deadline: block.timestamp + 60,
                        amountIn: _balance,
                        amountOutMinimum: expected
                    }));
                }
            }
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Swappable.sol";

abstract contract ControllerStratAbs is Swappable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;

    bytes32 public constant BOOSTER_ROLE = keccak256("BOOSTER_ROLE");

    // Want
    IERC20Metadata immutable public want;
    // want "missing" decimals precision
    uint internal immutable WANT_MISSING_PRECISION;

    // Pool settings
    uint public ratioForFullWithdraw = 9000; // 90% [Min % to full withdraw
    uint public poolSlippageRatio = 20; // 0.2% [Slippage % to add/remove liquidity to/from the pool]
    // Min % to add/remove to an amount to conver BTC<=>BTCCRV
    // The virtualPrice will ALWAYS be greater than 1.0 (otherwise we're loosing BTC
    // so we only consider the decimal part)
    uint public poolMinVirtualPrice = 30; // 0.3%
    // Pool reward[s] route for Swap
    mapping(address => address[]) public rewardToWantRoute;
    // PoolRewards
    address[] public rewardTokens;

    // Fees
    uint constant public MAX_PERFORMANCE_FEE = 5000; // 50% max
    uint public performanceFee = 500; // 5.0%
    uint internal lastBalance;

    address public treasury;
    address public exchange;
    address public immutable controller; // immutable to prevent anyone to change it and withdraw

    // Deposit compensation
    address public equalizer;
    uint public offsetRatio = 0; // 0.00%

    // manual boosts
    uint public lastExternalBoost;

    // Migrate to a library or something
    function _checkIERC20(IERC20Metadata token, string memory errorMsg) internal view {
        require(address(token) != address(0), errorMsg);
        token.symbol(); // Check that want is at least an ERC20
        require(token.balanceOf(address(this)) == 0, "Invalid ERC20"); // Check that want is at least an ERC20
        require(token.allowance(msg.sender, address(this)) == 0, "Invalid ERC20"); // Check that want is at least an ERC20
    }

    constructor(IERC20Metadata _want, address _controller, address _exchange, address _treasury) {
        _checkIERC20(_want, "Want !ZeroAddress");
        require(_controller != address(0), "Controller !ZeroAddress");
        require(_exchange != address(0), "Exchange !ZeroAddress");
        require(_treasury != address(0), "Treasury !ZeroAddress");

        want = _want;
        controller = _controller;
        exchange = _exchange;
        treasury = _treasury;

        WANT_MISSING_PRECISION = (10 ** (18 - _want.decimals()));

        equalizer = msg.sender;
    }

    event NewTreasury(address oldTreasury, address newTreasury);
    event NewExchange(address oldExchange, address newExchange);
    event NewPerformanceFee(uint oldFee, uint newFee);
    event Harvested(address _want, uint _amount);
    event PerformanceFee(uint _amount);
    event Boosted(address indexed booster, uint amount);
    event Compensated(address indexed equalizer, uint amount);

    modifier onlyController() {
        require(msg.sender == controller, "Not from controller");
        _;
    }

    function setTreasury(address _treasury) external onlyAdmin nonReentrant {
        require(_treasury != treasury, "Same address");
        require(_treasury != address(0), "!ZeroAddress");
        emit NewTreasury(treasury, _treasury);

        treasury = _treasury;
    }

    function setExchange(address _exchange) external onlyAdmin nonReentrant {
        require(_exchange != exchange, "Same address");
        require(_exchange != address(0), "!ZeroAddress");
        emit NewExchange(exchange, _exchange);

        exchange = _exchange;
    }

    function setPerformanceFee(uint _fee) external onlyAdmin nonReentrant {
        require(_fee != performanceFee, "Same fee");
        require(_fee <= MAX_PERFORMANCE_FEE, "Can't be greater than max");
        emit NewPerformanceFee(performanceFee, _fee);

        performanceFee = _fee;
    }

    function setPoolMinVirtualPrice(uint _ratio) public onlyAdmin {
        require(_ratio != poolMinVirtualPrice, "Same ratio");
        require(_ratio <= RATIO_PRECISION, "Can't be more than 100%");

        poolMinVirtualPrice = _ratio;
    }

    function setPoolSlippageRatio(uint _ratio) public onlyAdmin {
        require(_ratio != poolSlippageRatio, "Same ratio");
        require(_ratio <= RATIO_PRECISION, "Can't be more than 100%");

        poolSlippageRatio = _ratio;
    }
    function setRatioForFullWithdraw(uint _ratio) public onlyAdmin {
        require(_ratio != ratioForFullWithdraw, "Same ratio");
        require(_ratio <= RATIO_PRECISION, "Can't be more than 100%");

        ratioForFullWithdraw = _ratio;
    }

    function setRewardToWantRoute(address _reward, address[] calldata _route) external onlyAdmin {
        require(_reward != address(0), "!ZeroAddress");
        require(_route[0] == _reward, "First route isn't reward");
        require(_route[_route.length - 1] == address(want), "Last route isn't want token");

        bool newReward = true;
        for (uint i = 0; i < rewardTokens.length; i++) {
            if (rewardTokens[i] == _reward) {
                newReward = false;
                break;
            }
        }

        if (newReward) { rewardTokens.push(_reward); }
        rewardToWantRoute[_reward] = _route;
    }

    // Compensation
    function setOffsetRatio(uint newRatio) external onlyAdmin {
        require(newRatio != offsetRatio, "same ratio");
        require(newRatio <= RATIO_PRECISION, "greater than 100%");
        require(newRatio >= 0, "less than 0%?");

        offsetRatio = newRatio;
    }

    function setEqualizer(address _equalizer) external onlyAdmin {
        require(_equalizer != address(0), "!ZeroAddress");
        require(_equalizer != equalizer, "same address");

        equalizer = _equalizer;
    }

    function beforeMovement() external onlyController nonReentrant {
        _beforeMovement();
    }

    // Update new `lastBalance` for the next charge
    function _afterMovement() internal virtual {
        lastBalance = balance();
    }

    function deposit() external whenNotPaused onlyController nonReentrant {
        _deposit();
        _afterMovement();
    }

    function withdraw(uint _amount) external onlyController nonReentrant returns (uint) {
        uint _balance = wantBalance();

        if (_balance < _amount) {
            uint poolBalance = balanceOfPoolInWant();

            // If the requested amount is greater than xx% of the founds just withdraw everything
            if (_amount > (poolBalance * ratioForFullWithdraw / RATIO_PRECISION)) {
                _withdrawAll();
            } else {
                _withdraw(_amount);
            }

            _balance = wantBalance();

            if (_balance < _amount) { _amount = _balance; } // solhint-disable-unreachable-code
        }

        want.safeTransfer(controller, _amount);

        // Redeposit
        if (!paused()) { _deposit(); }

        _afterMovement();

        return _amount;
    }

    function harvest() public nonReentrant virtual {
        uint _before = wantBalance();

        _claimRewards();
        _swapRewards();

        uint harvested = wantBalance() - _before;

        // Charge performance fee for earned want + rewards
        _beforeMovement();

        // re-deposit
        if (!paused()) { _deposit(); }

        // Update lastBalance for the next movement
        _afterMovement();

        emit Harvested(address(want), harvested);
    }

    // This function is called to "boost" the strategy.
    function boost(uint _amount) external {
        require(hasRole(BOOSTER_ROLE, msg.sender), "Not a booster");

        // Charge performance fee for earned want
        _beforeMovement();

        // transfer reward from caller
        if (_amount > 0) { want.safeTransferFrom(msg.sender, address(this), _amount); }

        // Keep track of how much is added to calc boost APY
        lastExternalBoost = _amount;

        // Deposit transfered amount
        _deposit();

        // update last_balance to exclude the manual reward from perfFee
        _afterMovement();

        emit Boosted(msg.sender, _amount);
    }

    function _beforeMovement() internal virtual{
        uint currentBalance = balance();

        if (currentBalance > lastBalance) {
            uint perfFee = ((currentBalance - lastBalance) * performanceFee) / RATIO_PRECISION;

            if (perfFee > 0) {
                uint _balance = wantBalance();

                if (_balance < perfFee) {
                    uint _diff = perfFee - _balance;

                    _withdraw(_diff);
                }

                // Just in case
                _balance = wantBalance();
                if (_balance < perfFee) { perfFee = _balance; }

                if (perfFee > 0) {
                    want.safeTransfer(treasury, perfFee);
                    emit PerformanceFee(perfFee);
                }
            }
        }
    }

    function _deposit() internal virtual {
        // should be implemented
    }

    function _withdraw(uint) internal virtual returns (uint) {
        // should be implemented
    }

    function _withdrawAll() internal virtual returns (uint) {
        // should be implemented
    }

    function _claimRewards() internal virtual {
        // should be implemented
    }

    function _swapRewards() internal virtual {
        // should be implemented
        for (uint i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            uint _balance = IERC20Metadata(rewardToken).balanceOf(address(this));

            if (_balance > 0) {
                uint expected = _expectedForSwap(_balance, rewardToken, address(want));
                // Want price sometimes is too high so it requires a lot of rewards to swap
                if (expected > 1) {
                    IERC20Metadata(rewardToken).safeApprove(exchange, _balance);

                    IUniswapRouter(exchange).swapExactTokensForTokens(
                        _balance, expected, rewardToWantRoute[rewardToken], address(this), block.timestamp + 60
                    );
                }
            }
        }
    }

    /**
     * @dev Takes out performance fee.
     */
    function _chargeFees(uint _harvested) internal {
        uint fee = (_harvested * performanceFee) / RATIO_PRECISION;

        // Pay to treasury a percentage of the total reward claimed
        if (fee > 0) {
            want.safeTransfer(treasury, fee);
            emit PerformanceFee(fee);
        }
    }

    function _compensateDeposit(uint _amount) internal returns (uint) {
        if (offsetRatio <= 0) { return _amount; }

        uint _comp = _amount * offsetRatio / RATIO_PRECISION;

        // Compensate only if we can...
        if (
            want.allowance(equalizer, address(this)) >= _comp &&
            want.balanceOf(equalizer) >= _comp
        ) {
            want.safeTransferFrom(equalizer, address(this), _comp);
            _amount += _comp;

            emit Compensated(equalizer, _comp);
        }

        return _amount;
    }

    function wantBalance() public view returns (uint) {
        return want.balanceOf(address(this));
    }

    function balance() public view returns (uint) {
        return wantBalance() + balanceOfPoolInWant();
    }

    function balanceOfPool() public view virtual returns (uint) {
        // should be implemented
    }

    function balanceOfPoolInWant() public view virtual returns (uint) {
        // should be implemented
    }

    // called as part of strat migration. Sends all the available funds back to the vault.
    function retireStrat() external onlyController {
        if (!paused()) { _pause(); }

        // max withdraw can fail if not staked (in case of panic)
        if (balanceOfPool() > 0) { _withdrawAll(); }

        // Can be called without rewards
        harvest();

        require(balanceOfPool() <= 0, "Strategy still has deposits");
        want.safeTransfer(controller, wantBalance());
    }

    // pauses deposits and withdraws all funds from third party systems.
    function panic() external onlyAdmin nonReentrant {
        _withdrawAll(); // max withdraw
        pause();
    }

    function pause() public onlyAdmin {
        _pause();
    }

    function unpause() external onlyAdmin nonReentrant {
        _unpause();

        _deposit();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

interface ICurvePool {
    // _use_underlying If True, withdraw underlying assets instead of aTokens
    function add_liquidity(uint[2] calldata amounts, uint min_mint_amount, bool _use_underlying) external;
    function add_liquidity(uint[2] calldata amounts, uint min_mint_amount) external;
    function add_liquidity(address _pool, uint[2] calldata amounts, uint min_mint_amount, bool _use_underlying) external;
    function add_liquidity(address _pool, uint[2] calldata amounts, uint min_mint_amount) external;
    function add_liquidity(uint[4] calldata amounts, uint min_mint_amount, bool _use_underlying) external;
    function add_liquidity(uint[4] calldata amounts, uint min_mint_amount) external;
    function add_liquidity(address _pool, uint[4] calldata amounts, uint min_mint_amount, bool _use_underlying) external;
    function add_liquidity(address _pool, uint[4] calldata amounts, uint min_mint_amount) external;
    function remove_liquidity_one_coin(uint _token_amount, int128 i, uint _min_amount) external returns (uint);
    function remove_liquidity_one_coin(uint _token_amount, int128 i, uint _min_amount, bool _use_underlying) external;
    function remove_liquidity_one_coin(address _pool, uint _token_amount, int128 i, uint _min_amount) external returns (uint);
    function remove_liquidity_one_coin(address _pool, uint _token_amount, int128 i, uint _min_amount, bool _use_underlying) external;
    function calc_withdraw_one_coin(uint _token_amount, int128 i) external view returns (uint);
    function calc_withdraw_one_coin(address _pool, uint _token_amount, int128 i) external view returns (uint);
    function calc_token_amount(uint[2] calldata _amounts, bool is_deposit) external view returns (uint);
    function calc_token_amount(uint[4] calldata _amounts, bool is_deposit) external view returns (uint);
    function calc_token_amount(address _pool, uint[2] calldata _amounts, bool is_deposit) external view returns (uint);
    function calc_token_amount(address _pool, uint[4] calldata _amounts, bool is_deposit) external view returns (uint);
    function underlying_coins(int128 i) external view returns (address);
    function underlying_coins(uint256 i) external view returns (address);
}

interface ICurveGauge {
    // This function should be view but it's not defined as view...
    function claimable_tokens(address) external returns (uint);
    function claimable_reward(address _user) external view returns (uint);
    function claimable_reward(address _user, address _reward) external view returns (uint);
    function reward_count() external view returns (uint);
    function reward_tokens(uint) external view returns (address);
    function balanceOf(address account) external view returns (uint);

    function claim_rewards() external;
    function deposit(uint _value) external;
    function withdraw(uint _value) external;
}

interface ICurveGaugeFactory {
    function mint(address _gauge) external;
    function minted(address _arg0, address _arg1) external returns (uint256);
}

// SPDX-License-Identifier: MIT

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

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// import "hardhat/console.sol";

import "./PiAdmin.sol";
import "../interfaces/IChainLink.sol";
import "../interfaces/IUniswapRouter.sol";

abstract contract Swappable is PiAdmin {
    uint constant public SWAP_PRECISION = 1e18;
    uint constant public RATIO_PRECISION = 10000; // 100%
    uint public swapSlippageRatio = 100; // 1%

    mapping(address => IChainLink) public oracles;

    uint public maxPriceOffset = 600; // 10 minutes

    function setSwapSlippageRatio(uint _ratio) external onlyAdmin {
        require(_ratio != swapSlippageRatio, "Same ratio");
        require(_ratio <= RATIO_PRECISION, "Can't be more than 100%");
        swapSlippageRatio = _ratio;
    }

    function setMaxPriceOffset(uint _offset) external onlyAdmin {
        require(_offset != maxPriceOffset, "Same offset");
        require(_offset <= 86400, "Can't be more than 1 day");
        maxPriceOffset = _offset;
    }

    function setPriceFeed(address _token, IChainLink _feed) external onlyAdmin {
        require(_token != address(0), "!ZeroAddress");
        (uint80 round, int price,,,) = _feed.latestRoundData();
        require(round > 0 && price > 0, "Invalid feed");

        oracles[_token] = _feed;
    }

    function _expectedForSwap(uint _amount, address _fromToken, address _toToken) internal view returns (uint) {
        // ratio is a 18 decimals ratio number calculated to get the minimum
        // amount of want-tokens. So the balance is multiplied by the ratio
        // and then divided by 9 decimals to get the same "precision".
        // Then the result should be divided for the decimal diff between tokens.
        // Oracle Price Feed has always 8 decimals.
        // E.g want is USDT with only 6 decimals:
        // tokenDiffPrecision = 1e21 ((1e18 MATIC decimals / 1e6 USDT decimals) * 1e9 ratio precision)
        // ratio = 1_507_423_500 ((152265000 * 1e9) / 100000000) * 99 / 100 [with 1.52 USDT/MATIC]
        // _balance = 1e18 (1.0 MATIC)
        // expected = 1507423 (1e18 * 1_507_423_500 / 1e21) [1.507 in USDT decimals]
        // we should keep in mind the order of the token decimals

        uint ratio = (
            (_getPriceFor(_fromToken) * SWAP_PRECISION) / _getPriceFor(_toToken)
        ) * (RATIO_PRECISION - swapSlippageRatio) / RATIO_PRECISION;

        if (IERC20Metadata(_fromToken).decimals() >= IERC20Metadata(_toToken).decimals()) {
            uint tokenDiffPrecision = (10 ** IERC20Metadata(_fromToken).decimals()) / (10 ** IERC20Metadata(_toToken).decimals());

            tokenDiffPrecision *= SWAP_PRECISION;

            return (_amount * ratio / tokenDiffPrecision);
        } else {
            uint tokenDiffPrecision = (10 ** IERC20Metadata(_toToken).decimals()) / (10 ** IERC20Metadata(_fromToken).decimals());

            return (_amount * ratio * tokenDiffPrecision / SWAP_PRECISION);
        }
    }

    function _getPriceFor(address _token) internal view returns (uint) {
        // This could be implemented with FeedRegistry but it's not available in polygon
        (, int price,,uint timestamp,) = oracles[_token].latestRoundData();

        require(timestamp >= (block.timestamp - maxPriceOffset), "Old price");

        return uint(price);
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
        assembly {
            size := extcodesize(account)
        }
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

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/AccessControl.sol";
// import "hardhat/console.sol";

abstract contract PiAdmin is AccessControl {
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not an admin");
        _;
    }

    // @dev Used to break loops if gasleft is less than 20k
    function _outOfGasForLoop() internal view returns (bool) {
        return gasleft() <= 20_000;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

interface IChainLink {
  function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
  function decimals() external view returns (uint8);
  function aggregator() external view returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

interface IUniswapRouter {
  function swapExactTokensForTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
  ) external returns (uint[] memory amounts);

  function addLiquidity(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
  ) external returns (uint amountA, uint amountB, uint liquidity);
  function removeLiquidity(
    address tokenA,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
  ) external returns (uint amountA, uint amountB);
  function removeLiquidityETH(
      address token,
      uint liquidity,
      uint amountTokenMin,
      uint amountETHMin,
      address to,
      uint deadline
  ) external returns (uint amountToken, uint amountETH);

  function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    function _grantRole(bytes32 role, address account) private {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}