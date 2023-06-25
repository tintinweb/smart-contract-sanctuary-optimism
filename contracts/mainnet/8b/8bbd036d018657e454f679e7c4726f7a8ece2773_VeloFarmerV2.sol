// SPDX-License-Identifier: MIT
import "src/velo-fed/IRouter.sol";

pragma solidity ^0.8.13;

// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */

interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     *another (`to`).
     *
     *Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     *a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the decimal points used by the token.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     *Returns a boolean value indicating whether the operation succeeded.
     *
     *Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     *allowed to spend on behalf of `owner` through {transferFrom}. This is
     *zero by default.
     *
     *This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     *Returns a boolean value indicating whether the operation succeeded.
     *
     *IMPORTANT: Beware that changing an allowance with this method brings the risk
     *that someone may use both the old and the new allowance by unfortunate
     *transaction ordering. One possible solution to mitigate this race
     *condition is to first reduce the spender's allowance to 0 and set the
     *desired value afterwards:
     *https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     *Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     *allowance mechanism. `amount` is then deducted from the caller's
     *allowance.
     *
     *Returns a boolean value indicating whether the operation succeeded.
     *
     *Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    
    /**
     * @dev Burns `amount` of token, shringking total supply
     */
    function burn(uint amount) external;

    /**
     * @dev Mints `amount` of token to address `to` increasing total supply
     */
    function mint(address to, uint amount) external;

    //For testing
    function addMinter(address minter_) external;
}

interface IGauge {
    function deposit(uint amount) external;
    function getReward(address account) external;
    function notifyRewardAmount(uint amount) external;
    function withdraw(uint shares) external;
    function balanceOf(address account) external returns (uint);
    function voter() external view returns(address);
}

/**
 * @title IL2ERC20Bridge
 */
interface IL2ERC20Bridge {
    /**********
     *Events *
     **********/

    event WithdrawalInitiated(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );

    event DepositFinalized(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );

    event DepositFailed(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );

    /********************
     *Public Functions *
     ********************/

    /**
     * @dev get the address of the corresponding L1 bridge contract.
     * @return Address of the corresponding L1 bridge contract.
      */
    function l1TokenBridge() external returns (address);

    /**
     * @dev initiate a withdraw of some tokens to the caller's account on L1
     * @param _l2Token Address of L2 token where withdrawal was initiated.
     * @param _amount Amount of the token to withdraw.
     *param _l1Gas Unused, but included for potential forward compatibility considerations.
     * @param _data Optional data to forward to L1. This data is provided
     *solely as a convenience for external contracts. Aside from enforcing a maximum
     *length, these contracts provide no guarantees about its content.
      */
    function withdraw(
        address _l2Token,
        uint256 _amount,
        uint32 _l1Gas,
        bytes calldata _data
    ) external;

    /**
     * @dev initiate a withdraw of some token to a recipient's account on L1.
     * @param _l2Token Address of L2 token where withdrawal is initiated.
     * @param _to L1 adress to credit the withdrawal to.
     * @param _amount Amount of the token to withdraw.
     *param _l1Gas Unused, but included for potential forward compatibility considerations.
     * @param _data Optional data to forward to L1. This data is provided
     *solely as a convenience for external contracts. Aside from enforcing a maximum
     *length, these contracts provide no guarantees about its content.
      */
    function withdrawTo(
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _l1Gas,
        bytes calldata _data
    ) external;

    /*************************
     *Cross-chain Functions *
     *************************/

    /**
     * @dev Complete a deposit from L1 to L2, and credits funds to the recipient's balance of this
     *L2 token. This call will fail if it did not originate from a corresponding deposit in
     *L1StandardTokenBridge.
     * @param _l1Token Address for the l1 token this is called with
     * @param _l2Token Address for the l2 token this is called with
     * @param _from Account to pull the deposit from on L2.
     * @param _to Address to receive the withdrawal at
     * @param _amount Amount of the token to withdraw
     * @param _data Data provider by the sender on L1. This data is provided
     *solely as a convenience for external contracts. Aside from enforcing a maximum
     *length, these contracts provide no guarantees about its content.
      */
    function finalizeDeposit(
        address _l1Token,
        address _l2Token,
        address _from,
        address _to,
        uint256 _amount,
        bytes calldata _data
    ) external;
}

/**
 * @title ICrossDomainMessenger
 */
interface ICrossDomainMessenger {
    /**********
     *Events *
     **********/

    event SentMessage(
        address indexed target,
        address sender,
        bytes message,
        uint256 messageNonce,
        uint256 gasLimit
    );
    event RelayedMessage(bytes32 indexed msgHash);
    event FailedRelayedMessage(bytes32 indexed msgHash);

    /*************
     *Variables *
     *************/

    function xDomainMessageSender() external view returns (address);

    /********************
     *Public Functions *
     ********************/

    /**
      *Sends a cross domain message to the target messenger.
      * @param _target Target contract address.
      * @param _message Message to send to the target.
      * @param _gasLimit Gas limit for the provided message.
      */
    function sendMessage(
        address _target,
        bytes calldata _message,
        uint32 _gasLimit
    ) external;
}

contract VeloFarmerV2 {
    address public chair;
    address public l2chair;
    address public pendingGov;
    address public gov;
    address public treasury;
    address public guardian;
    uint public maxSlippageBpsDolaToUsdc;
    uint public maxSlippageBpsUsdcToDola;
    uint public maxSlippageBpsLiquidity;

    uint public constant DOLA_USDC_CONVERSION_MULTI= 1e12;
    uint public constant PRECISION = 10_000;

    IGauge public constant dolaGauge = IGauge(0xa1034Ed2C9eb616d6F7f318614316e64682e7923);
    IERC20 public constant LP_TOKEN = IERC20(0xB720FBC32d60BB6dcc955Be86b98D8fD3c4bA645);
    address public constant veloTokenAddr = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;
    address public constant factory = 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;
    ICrossDomainMessenger public constant ovmL2CrossDomainMessenger = ICrossDomainMessenger(0x4200000000000000000000000000000000000007);
    IRouter public constant router = IRouter(0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858);
    IERC20 public constant DOLA = IERC20(0x8aE125E8653821E851F12A49F7765db9a9ce7384);
    IERC20 public constant USDC = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IL2ERC20Bridge public bridge;
    address public optiFed;

    error OnlyChair();
    error OnlyGov();
    error OnlyPendingGov();
    error OnlyGovOrGuardian();
    error MaxSlippageTooHigh();
    error NotEnoughTokens();
    error LiquiditySlippageTooHigh();
    
    constructor(
        address gov_,
        address chair_,
        address l2chair_,
        address treasury_,
        address guardian_,
        address bridge_,
        address optiFed_,
        uint maxSlippageBpsDolaToUsdc_,
        uint maxSlippageBpsUsdcToDola_,
        uint maxSlippageBpsLiquidity_
        )
    {
        gov = gov_;
        chair = chair_;
        l2chair = l2chair_;
        treasury = treasury_;
        guardian = guardian_;
        bridge = IL2ERC20Bridge(bridge_);
        optiFed = optiFed_;
        maxSlippageBpsDolaToUsdc = maxSlippageBpsDolaToUsdc_;
        maxSlippageBpsUsdcToDola = maxSlippageBpsUsdcToDola_;
        maxSlippageBpsLiquidity = maxSlippageBpsLiquidity_;
    }

    modifier onlyGov() {
        if (msg.sender != address(ovmL2CrossDomainMessenger) ||
            ovmL2CrossDomainMessenger.xDomainMessageSender() != gov
        ) revert OnlyGov();
        _;
    }

    modifier onlyPendingGov() {
        if (msg.sender != address(ovmL2CrossDomainMessenger) ||
            ovmL2CrossDomainMessenger.xDomainMessageSender() != pendingGov
        ) revert OnlyPendingGov();
        _;
    }

    modifier onlyChair() {
        if ((msg.sender != address(ovmL2CrossDomainMessenger) ||
            ovmL2CrossDomainMessenger.xDomainMessageSender() != chair) &&
            msg.sender != l2chair
        ) revert OnlyChair();
        _;
    }

    modifier onlyGovOrGuardian() {
        if ((msg.sender != address(ovmL2CrossDomainMessenger) ||
            (ovmL2CrossDomainMessenger.xDomainMessageSender() != gov) &&
             ovmL2CrossDomainMessenger.xDomainMessageSender() != guardian)
        ) revert OnlyGovOrGuardian();
        _;
    }

    /**
     * @notice Claims all VELO token rewards accrued by this contract & transfer all VELO owned by this contract to `treasury`
     */
    function claimVeloRewards() external {
        dolaGauge.getReward(address(this));

        IERC20(veloTokenAddr).transfer(treasury, IERC20(veloTokenAddr).balanceOf(address(this)));
    }

    /**
     * @notice Attempts to deposit `dolaAmount` of DOLA & `usdcAmount` of USDC into Velodrome DOLA/USDC stable pool. Then, deposits LP tokens into gauge.
     * @param dolaAmount Amount of DOLA to be added as liquidity in Velodrome DOLA/USDC pool
     * @param usdcAmount Amount of USDC to be added as liquidity in Velodrome DOLA/USDC pool
     */
    function deposit(uint dolaAmount, uint usdcAmount) public onlyChair {
        uint lpTokenPrice = getLpTokenPrice();

        DOLA.approve(address(router), dolaAmount);
        USDC.approve(address(router), usdcAmount);
        (uint dolaSpent, uint usdcSpent, uint lpTokensReceived) = router.addLiquidity(address(DOLA), address(USDC), true, dolaAmount, usdcAmount, 0, 0, address(this), block.timestamp);
        require(lpTokensReceived > 0, "No LP tokens received");

        uint totalDolaValue = dolaSpent + (usdcSpent *DOLA_USDC_CONVERSION_MULTI);

        uint expectedLpTokens = totalDolaValue *1e18 / lpTokenPrice *(PRECISION - maxSlippageBpsLiquidity) / PRECISION;
        if (lpTokensReceived < expectedLpTokens) revert LiquiditySlippageTooHigh();
        
        LP_TOKEN.approve(address(dolaGauge), LP_TOKEN.balanceOf(address(this)));
        dolaGauge.deposit(LP_TOKEN.balanceOf(address(this)));
    }

    /**
     * @notice Calls `deposit()` with entire DOLA & USDC token balance of this contract.
     */
    function depositAll() external {
        deposit(DOLA.balanceOf(address(this)), USDC.balanceOf(address(this)));
    }

    /**
     * @notice Withdraws `dolaAmount` worth of LP tokens from gauge. Then, redeems LP tokens for DOLA/USDC.
     * @dev If attempting to remove more DOLA than total LP tokens are worth, will remove all LP tokens.
     * @param dolaAmount Desired dola value to remove from DOLA/USDC pool. Will attempt to remove 50/50 while allowing for `maxSlippageBpsLiquidity` bps of variance.
     * @return Amount of USDC received from liquidity removal. Used by withdrawLiquidityAndSwap wrapper.
     */
    function withdrawLiquidity(uint dolaAmount) public onlyChair returns (uint) {
        uint lpTokenPrice = getLpTokenPrice();
        uint liquidityToWithdraw = dolaAmount *1e18 / lpTokenPrice;
        uint ownedLiquidity = dolaGauge.balanceOf(address(this));

        if (liquidityToWithdraw > ownedLiquidity) liquidityToWithdraw = ownedLiquidity;
        dolaGauge.withdraw(liquidityToWithdraw);

        LP_TOKEN.approve(address(router), liquidityToWithdraw);
        (uint amountUSDC, uint amountDola) = router.removeLiquidity(address(USDC), address(DOLA), true, liquidityToWithdraw, 0, 0, address(this), block.timestamp);

        uint totalDolaReceived = amountDola + (amountUSDC *DOLA_USDC_CONVERSION_MULTI);

        if ((dolaAmount *(PRECISION - maxSlippageBpsLiquidity) / PRECISION) > totalDolaReceived) {
            revert LiquiditySlippageTooHigh();
        }

        return amountUSDC;
    }

    /**
     * @notice Withdraws `dolaAmount` worth of LP tokens from gauge. Then, redeems LP tokens for DOLA/USDC and swaps redeemed USDC to DOLA.
     * @param dolaAmount Desired dola value to remove from DOLA/USDC pool. Will attempt to remove 50/50 while allowing for `maxSlippageBpsLiquidity` bps of variance.
     */
    function withdrawLiquidityAndSwapToDOLA(uint dolaAmount) external {
        uint usdcAmount = withdrawLiquidity(dolaAmount);

        swapUSDCtoDOLA(usdcAmount);
    }

    /**
     * @notice Withdraws `dolaAmount` of DOLA to optiFed on L1. Will take 7 days before withdraw is claimable on L1.
     * @param dolaAmount Amount of DOLA to withdraw and send to L1 OptiFed
     */
    function withdrawToL1OptiFed(uint dolaAmount) external onlyChair {
        if (dolaAmount > DOLA.balanceOf(address(this))) revert NotEnoughTokens();

        bridge.withdrawTo(address(DOLA), optiFed, dolaAmount, 0, "");
    }

    /**
     * @notice Withdraws `dolaAmount` of DOLA & `usdcAmount` of USDC to optiFed on L1. Will take 7 days before withdraw is claimable on L1.
     * @param dolaAmount Amount of DOLA to withdraw and send to L1 OptiFed
     * @param usdcAmount Amount of USDC to withdraw and send to L1 OptiFed
     */
    function withdrawToL1OptiFed(uint dolaAmount, uint usdcAmount) external onlyChair {
        if (dolaAmount > DOLA.balanceOf(address(this))) revert NotEnoughTokens();
        if (usdcAmount > USDC.balanceOf(address(this))) revert NotEnoughTokens();

        bridge.withdrawTo(address(DOLA), optiFed, dolaAmount, 0, "");
        bridge.withdrawTo(address(USDC), optiFed, usdcAmount, 0, "");
    }

    /**
     * @notice Withdraws `amount` of `l2Token` to address `to` on L1. Will take 7 days before withdraw is claimable.
     * @param l2Token Address of the L2 token to be withdrawn
     * @param to L1 Address that tokens will be sent to
     * @param amount Amount of the L2 token to be withdrawn
     */
    function withdrawTokensToL1(address l2Token, address to, uint amount) external onlyChair {
        if (amount > IERC20(l2Token).balanceOf(address(this))) revert NotEnoughTokens();

        IERC20(l2Token).approve(address(bridge), amount);
        bridge.withdrawTo(address(l2Token), to, amount, 0, "");
    }

    /**
     * @notice Swap `usdcAmount` of USDC to DOLA through velodrome.
     * @param usdcAmount Amount of USDC to swap to DOLA
     */
    function swapUSDCtoDOLA(uint usdcAmount) public onlyChair {
        uint minOut = usdcAmount *(PRECISION - maxSlippageBpsUsdcToDola) / PRECISION *DOLA_USDC_CONVERSION_MULTI;

        USDC.approve(address(router), usdcAmount);
        router.swapExactTokensForTokens(usdcAmount, minOut, getRoute(address(USDC), address(DOLA)), address(this), block.timestamp);
    }

    /**
     * @notice Swap `dolaAmount` of DOLA to USDC through velodrome.
     * @param dolaAmount Amount of DOLA to swap to USDC
     */
    function swapDOLAtoUSDC(uint dolaAmount) public onlyChair { 
        uint minOut = dolaAmount *(PRECISION - maxSlippageBpsDolaToUsdc) / PRECISION / DOLA_USDC_CONVERSION_MULTI;
        
        DOLA.approve(address(router), dolaAmount);
        router.swapExactTokensForTokens(dolaAmount, minOut, getRoute(address(DOLA), address(USDC)), address(this), block.timestamp);
    }

    /**
     * @notice Calculates approximate price of 1 Velodrome DOLA/USDC stable pool LP token
     */
    function getLpTokenPrice() internal view returns (uint) {
        (uint dolaAmountOneLP, uint usdcAmountOneLP) = router.quoteRemoveLiquidity(address(DOLA), address(USDC), true, factory, 0.001 ether);
        usdcAmountOneLP *= DOLA_USDC_CONVERSION_MULTI;
        return (dolaAmountOneLP + usdcAmountOneLP)*1000;
    }

    /**
     * @notice Generate route array for swap between two stablecoins
     * @param from Token to go from
     * @param to Token to go to
     * @return Returns a Route[] with a single element, representing the route
     */
    function getRoute(address from, address to) internal pure returns(IRouter.Route[] memory){
        IRouter.Route memory route = IRouter.Route(from, to, true, factory);
        IRouter.Route[] memory routeArray = new IRouter.Route[](1);
        routeArray[0] = route;
        return routeArray;
    }

    /**
     * @notice Method for current chair of the fed to resign
     */
    function resign() external onlyChair {
        if (msg.sender == l2chair) {
            l2chair = address(0);
        } else {
            chair = address(0);
        }
    }

    /**
     * @notice Governance only function for setting acceptable slippage when swapping DOLA -> USDC
     * @param newMaxSlippageBps The new maximum allowed loss for DOLA -> USDC swaps. 1 = 0.01%
     */
    function setMaxSlippageDolaToUsdc(uint newMaxSlippageBps) onlyGovOrGuardian external {
        if (newMaxSlippageBps > 10000) revert MaxSlippageTooHigh();
        maxSlippageBpsDolaToUsdc = newMaxSlippageBps;
    }

    /**
     * @notice Governance only function for setting acceptable slippage when swapping USDC -> DOLA
     * @param newMaxSlippageBps The new maximum allowed loss for USDC -> DOLA swaps. 1 = 0.01%
     */
    function setMaxSlippageUsdcToDola(uint newMaxSlippageBps) onlyGovOrGuardian external {
        if (newMaxSlippageBps > 10000) revert MaxSlippageTooHigh();
        maxSlippageBpsUsdcToDola = newMaxSlippageBps;
    }

    /**
     * @notice Governance only function for setting acceptable slippage when adding or removing liquidty from DOLA/USDC pool
     * @param newMaxSlippageBps The new maximum allowed loss for adding/removing liquidity from DOLA/USDC pool. 1 = 0.01%
     */
    function setMaxSlippageLiquidity(uint newMaxSlippageBps) onlyGovOrGuardian external {
        if (newMaxSlippageBps > 10000) revert MaxSlippageTooHigh();
        maxSlippageBpsLiquidity = newMaxSlippageBps;
    }

    /**
     * @notice Method for `gov` to change `pendingGov` address
     * @dev `pendingGov` will have to call `claimGov` to complete `gov` transfer
     * @dev `pendingGov` should be an L1 address
     * @param newPendingGov_ L1 address to be set as `pendingGov`
     */
    function setPendingGov(address newPendingGov_) onlyGov external {
        pendingGov = newPendingGov_;
    }

    /**
     * @notice Method for `pendingGov` to claim `gov` role.
     */
    function claimGov() external onlyPendingGov {
        gov = pendingGov;
        pendingGov = address(0);
    }

    /**
     * @notice Method for gov to change treasury address, the address that receives all rewards
     * @param newTreasury_ L2 address to be set as treasury
     */
    function changeTreasury(address newTreasury_) external onlyGov {
        treasury = newTreasury_;
    }

    /**
     * @notice Method for gov to change the chair
     * @dev chair address should be set to the address of L1 VeloFarmerMessenger if it is being used
     * @param newChair_ L1 address to be set as chair
     */
    function changeChair(address newChair_) external onlyGov {
        chair = newChair_;
    }

    /**
     * @notice Method for gov to change the L2 chair
     * @param newL2Chair_ L2 address to be set as l2chair
     */
    function changeL2Chair(address newL2Chair_) external onlyGov {
        l2chair = newL2Chair_;
    }

    /**
     * @notice Method for gov to change the guardian
     * @param guardian_ L1 address to be set as guardian
     */
    function changeGuardian(address guardian_) external onlyGov {
        guardian = guardian_;
    }

    /**
     * @notice Method for gov to change the L1 optiFed address
     * @dev optiFed is the L1 address that receives all bridged DOLA/USDC from both withdrawToL1OptiFed functions
     * @param newOptiFed_ L1 address to be set as optiFed
     */
    function changeOptiFed(address newOptiFed_) external onlyGov {
        optiFed = newOptiFed_;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    error ETHTransferFailed();
    error Expired();
    error InsufficientAmount();
    error InsufficientAmountA();
    error InsufficientAmountB();
    error InsufficientAmountADesired();
    error InsufficientAmountBDesired();
    error InsufficientAmountAOptimal();
    error InsufficientLiquidity();
    error InsufficientOutputAmount();
    error InvalidAmountInForETHDeposit();
    error InvalidTokenInForETHDeposit();
    error InvalidPath();
    error InvalidRouteA();
    error InvalidRouteB();
    error OnlyWETH();
    error PoolDoesNotExist();

    /// @dev Struct containing information necessary to zap in and out of pools
    /// @param tokenA .
    /// @param tokenB .
    /// @param stable  Stable or volatile pool
    /// @param factory factory of pool
    /// @param amountOutMinA Minimum amount expected from swap leg of zap via routesA
    /// @param amountOutMinB Minimum amount expected from swap leg of zap via routesB
    /// @param amountAMin Minimum amount of tokenA expected from liquidity leg of zap
    /// @param amountBMin Minimum amount of tokenB expected from liquidity leg of zap
    struct Zap {
        address tokenA;
        address tokenB;
        bool stable;
        address factory;
        uint256 amountOutMinA;
        uint256 amountOutMinB;
        uint256 amountAMin;
        uint256 amountBMin;
    }

    /// @notice Calculate the address of a pool
    /// @dev Returns a randomly generated address for a nonexistent pool
    /// @param tokenA Address of token to query
    /// @param tokenB Address of token to query
    /// @param stable Boolean to indicate if the pool is stable or volatile
    /// @param factory Address of factory which created the pool
    function poolFor(address tokenA, address tokenB, bool stable, address factory) external view returns (address pool);

    /// @notice Wraps around poolFor(tokenA,tokenB,stable,factory) for backwards compatibility to Velodrome v1
    function pairFor(address tokenA, address tokenB, bool stable, address factory) external view returns (address pool);

    function getReserves(
        address tokenA,
        address tokenB,
        bool stable,
        address factory
    ) external view returns (uint256 reserveA, uint256 reserveB);

    function getAmountsOut(uint256 amountIn, Route[] memory routes) external view returns (uint256[] memory amounts);

    // **** ADD LIQUIDITY ****

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 amountADesired,
        uint256 amountBDesired
    ) external view returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 liquidity
    ) external view returns (uint256 amountA, uint256 amountB);

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
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function addLiquidityETH(
        address token,
        bool stable,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    // **** REMOVE LIQUIDITY ****

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        bool stable,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        bool stable,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    // **** SWAP ****

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function UNSAFE_swapExactTokensForTokens(
        uint256[] memory amounts,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);

    // **** SWAP (supporting fee-on-transfer tokens) ****
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external;

    /// @notice Zap a token A into a pool (B, C). (A can be equal to B or C).
    ///         Supports standard ERC20 tokens only (i.e. not fee-on-transfer tokens etc).
    ///         Slippage is required for the initial swap.
    ///         Additional slippage may be required when adding liquidity as the
    ///         price of the token may have changed.
    /// @param tokenIn Token you are zapping in from (i.e. input token).
    /// @param amountInA Amount of input token you wish to send down routesA
    /// @param amountInB Amount of input token you wish to send down routesB
    /// @param zapInPool Contains zap struct information. See Zap struct.
    /// @param routesA Route used to convert input token to tokenA
    /// @param routesB Route used to convert input token to tokenB
    /// @param to Address you wish to mint liquidity to.
    /// @param stake Auto-stake liquidity in corresponding gauge.
    /// @return liquidity Amount of LP tokens created from zapping in.
    function zapIn(
        address tokenIn,
        uint256 amountInA,
        uint256 amountInB,
        Zap calldata zapInPool,
        Route[] calldata routesA,
        Route[] calldata routesB,
        address to,
        bool stake
    ) external payable returns (uint256 liquidity);

    /// @notice Zap out a pool (B, C) into A.
    ///         Supports standard ERC20 tokens only (i.e. not fee-on-transfer tokens etc).
    ///         Slippage is required for the removal of liquidity.
    ///         Additional slippage may be required on the swap as the
    ///         price of the token may have changed.
    /// @param tokenOut Token you are zapping out to (i.e. output token).
    /// @param liquidity Amount of liquidity you wish to remove.
    /// @param zapOutPool Contains zap struct information. See Zap struct.
    /// @param routesA Route used to convert tokenA into output token.
    /// @param routesB Route used to convert tokenB into output token.
    function zapOut(
        address tokenOut,
        uint256 liquidity,
        Zap calldata zapOutPool,
        Route[] calldata routesA,
        Route[] calldata routesB
    ) external;

    /// @notice Used to generate params required for zapping in.
    ///         Zap in => remove liquidity then swap.
    ///         Apply slippage to expected swap values to account for changes in reserves in between.
    /// @dev Output token refers to the token you want to zap in from.
    /// @param tokenA .
    /// @param tokenB .
    /// @param stable .
    /// @param _factory .
    /// @param amountInA Amount of input token you wish to send down routesA
    /// @param amountInB Amount of input token you wish to send down routesB
    /// @param routesA Route used to convert input token to tokenA
    /// @param routesB Route used to convert input token to tokenB
    /// @return amountOutMinA Minimum output expected from swapping input token to tokenA.
    /// @return amountOutMinB Minimum output expected from swapping input token to tokenB.
    /// @return amountAMin Minimum amount of tokenA expected from depositing liquidity.
    /// @return amountBMin Minimum amount of tokenB expected from depositing liquidity.
    function generateZapInParams(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 amountInA,
        uint256 amountInB,
        Route[] calldata routesA,
        Route[] calldata routesB
    ) external view returns (uint256 amountOutMinA, uint256 amountOutMinB, uint256 amountAMin, uint256 amountBMin);

    /// @notice Used to generate params required for zapping out.
    ///         Zap out => swap then add liquidity.
    ///         Apply slippage to expected liquidity values to account for changes in reserves in between.
    /// @dev Output token refers to the token you want to zap out of.
    /// @param tokenA .
    /// @param tokenB .
    /// @param stable .
    /// @param _factory .
    /// @param liquidity Amount of liquidity being zapped out of into a given output token.
    /// @param routesA Route used to convert tokenA into output token.
    /// @param routesB Route used to convert tokenB into output token.
    /// @return amountOutMinA Minimum output expected from swapping tokenA into output token.
    /// @return amountOutMinB Minimum output expected from swapping tokenB into output token.
    /// @return amountAMin Minimum amount of tokenA expected from withdrawing liquidity.
    /// @return amountBMin Minimum amount of tokenB expected from withdrawing liquidity.
    function generateZapOutParams(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 liquidity,
        Route[] calldata routesA,
        Route[] calldata routesB
    ) external view returns (uint256 amountOutMinA, uint256 amountOutMinB, uint256 amountAMin, uint256 amountBMin);

    /// @notice Used by zapper to determine appropriate ratio of A to B to deposit liquidity. Assumes stable pool.
    /// @dev Returns stable liquidity ratio of B to (A + B).
    ///      E.g. if ratio is 0.4, it means there is more of A than there is of B.
    ///      Therefore you should deposit more of token A than B.
    /// @param tokenA tokenA of stable pool you are zapping into.
    /// @param tokenB tokenB of stable pool you are zapping into.
    /// @param factory Factory that created stable pool.
    /// @return ratio Ratio of token0 to token1 required to deposit into zap.
    function quoteStableLiquidityRatio(
        address tokenA,
        address tokenB,
        address factory
    ) external view returns (uint256 ratio);
}