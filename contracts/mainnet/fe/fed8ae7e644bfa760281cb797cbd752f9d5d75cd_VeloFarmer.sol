/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-11
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

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

interface IRouter {

    struct route {
        address from;
        address to;
        bool stable;
    }
    
    function pairFor(address tokenA, address tokenB, bool stable) external view returns (address pair);

    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external view returns (uint amount, bool stable);

    function getAmountsOut(uint amountIn, route[] memory routes) external view returns (uint[] memory amounts);

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired
    ) external view returns (uint amountA, uint amountB, uint liquidity);

    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity
    ) external view returns (uint amountA, uint amountB);

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
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
        bool stable,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

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

interface IGauge {
    function deposit(uint amount, uint tokenId) external;
    function getReward(address account, address[] memory tokens) external;
    function withdraw(uint shares) external;
    function balanceOf(address account) external returns (uint);
}

/**
 * @title IL2ERC20Bridge
 */
interface IL2ERC20Bridge {
    /**********
     * Events *
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
     * Public Functions *
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
     * param _l1Gas Unused, but included for potential forward compatibility considerations.
     * @param _data Optional data to forward to L1. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
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
     * param _l1Gas Unused, but included for potential forward compatibility considerations.
     * @param _data Optional data to forward to L1. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function withdrawTo(
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _l1Gas,
        bytes calldata _data
    ) external;

    /*************************
     * Cross-chain Functions *
     *************************/

    /**
     * @dev Complete a deposit from L1 to L2, and credits funds to the recipient's balance of this
     * L2 token. This call will fail if it did not originate from a corresponding deposit in
     * L1StandardTokenBridge.
     * @param _l1Token Address for the l1 token this is called with
     * @param _l2Token Address for the l2 token this is called with
     * @param _from Account to pull the deposit from on L2.
     * @param _to Address to receive the withdrawal at
     * @param _amount Amount of the token to withdraw
     * @param _data Data provider by the sender on L1. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
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
     * Events *
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
     * Variables *
     *************/

    function xDomainMessageSender() external view returns (address);

    /********************
     * Public Functions *
     ********************/

    /**
     * Sends a cross domain message to the target messenger.
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

contract VeloFarmer {
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

    IGauge public constant dolaGauge = IGauge(0xAFD2c84b9d1cd50E7E18a55e419749A6c9055E1F);
    IERC20 public constant LP_TOKEN = IERC20(0x6C5019D345Ec05004A7E7B0623A91a0D9B8D590d);
    address public constant veloTokenAddr = 0x3c8B650257cFb5f272f799F5e2b4e65093a11a05;
    ICrossDomainMessenger public constant ovmL2CrossDomainMessenger = ICrossDomainMessenger(0x4200000000000000000000000000000000000007);
    IRouter public constant router = IRouter(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);
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
            address treasury_,
            address guardian_,
            address bridge_,
            address optiFed_,
            uint maxSlippageBpsDolaToUsdc_,
            uint maxSlippageBpsUsdcToDola_,
            uint maxSlippageBpsLiquidity_
        )
    {
        chair = chair_;
        gov = gov_;
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
    @notice Claims all VELO token rewards accrued by this contract & transfer all VELO owned by this contract to `treasury`
    */
    function claimVeloRewards() external {
        address[] memory addr = new address[](1);
        addr[0] = veloTokenAddr;
        dolaGauge.getReward(address(this), addr);

        IERC20(addr[0]).transfer(treasury, IERC20(addr[0]).balanceOf(address(this)));
    }

    /**
    @notice Attempts to claim token rewards & transfer all reward tokens owned by this contract to `treasury`
    @param addrs Array of token addresses to claim rewards of.
    */
    function claimRewards(address[] calldata addrs) external onlyChair {
        dolaGauge.getReward(address(this), addrs);

        for (uint i = 0; i < addrs.length; i++) {
            IERC20(addrs[i]).transfer(treasury, IERC20(addrs[i]).balanceOf(address(this)));
        }
    }

    /**
    @notice Attempts to deposit `dolaAmount` of DOLA & `usdcAmount` of USDC into Velodrome DOLA/USDC stable pool. Then, deposits LP tokens into gauge.
    @param dolaAmount Amount of DOLA to be added as liquidity in Velodrome DOLA/USDC pool
    @param usdcAmount Amount of USDC to be added as liquidity in Velodrome DOLA/USDC pool
    */
    function deposit(uint dolaAmount, uint usdcAmount) public onlyChair {
        uint lpTokenPrice = getLpTokenPrice(false);

        DOLA.approve(address(router), dolaAmount);
        USDC.approve(address(router), usdcAmount);
        (uint dolaSpent, uint usdcSpent, uint lpTokensReceived) = router.addLiquidity(address(DOLA), address(USDC), true, dolaAmount, usdcAmount, 0, 0, address(this), block.timestamp);

        (uint usdcDolaValue,) = router.getAmountOut(usdcSpent, address(USDC), address(DOLA));
        uint totalDolaValue = dolaSpent + usdcDolaValue;

        uint expectedLpTokens = totalDolaValue * 1e18 / lpTokenPrice * (PRECISION - maxSlippageBpsLiquidity) / PRECISION;
        if (lpTokensReceived < expectedLpTokens) revert LiquiditySlippageTooHigh();
        
        LP_TOKEN.approve(address(dolaGauge), LP_TOKEN.balanceOf(address(this)));
        dolaGauge.deposit(LP_TOKEN.balanceOf(address(this)), 0);
    }

    /**
    @notice Calls `deposit()` with entire DOLA & USDC token balance of this contract.
    */
    function depositAll() external {
        deposit(DOLA.balanceOf(address(this)), USDC.balanceOf(address(this)));
    }

    /**
    @notice Withdraws `dolaAmount` worth of LP tokens from gauge. Then, redeems LP tokens for DOLA/USDC.
    @dev If attempting to remove more DOLA than total LP tokens are worth, will remove all LP tokens.
    @param dolaAmount Desired dola value to remove from DOLA/USDC pool. Will attempt to remove 50/50 while allowing for `maxSlippageBpsLiquidity` bps of variance.
    @return Amount of USDC received from liquidity removal. Used by withdrawLiquidityAndSwap wrapper.
    */
    function withdrawLiquidity(uint dolaAmount) public onlyChair returns (uint) {
        uint lpTokenPrice = getLpTokenPrice(true);
        uint liquidityToWithdraw = dolaAmount * 1e18 / lpTokenPrice;
        uint ownedLiquidity = dolaGauge.balanceOf(address(this));

        if (liquidityToWithdraw > ownedLiquidity) liquidityToWithdraw = ownedLiquidity;

        dolaGauge.withdraw(liquidityToWithdraw);

        LP_TOKEN.approve(address(router), liquidityToWithdraw);
        (uint amountDola, uint amountUSDC) = router.removeLiquidity(address(DOLA), address(USDC), true, liquidityToWithdraw, 0, 0, address(this), block.timestamp);

        (uint dolaReceivedAsUsdc,) = router.getAmountOut(amountUSDC, address(USDC), address(DOLA));
        uint totalDolaReceived = amountDola + dolaReceivedAsUsdc;

        if ((dolaAmount * (PRECISION - maxSlippageBpsLiquidity) / PRECISION) > totalDolaReceived) {
            revert LiquiditySlippageTooHigh();
        }

        return amountUSDC;
    }

    /**
    @notice Withdraws `dolaAmount` worth of LP tokens from gauge. Then, redeems LP tokens for DOLA/USDC and swaps redeemed USDC to DOLA.
    @param dolaAmount Desired dola value to remove from DOLA/USDC pool. Will attempt to remove 50/50 while allowing for `maxSlippageBpsLiquidity` bps of variance.
    */
    function withdrawLiquidityAndSwapToDOLA(uint dolaAmount) external {
        uint usdcAmount = withdrawLiquidity(dolaAmount);

        swapUSDCtoDOLA(usdcAmount);
    }

    /**
    @notice Withdraws `dolaAmount` of DOLA to optiFed on L1. Will take 7 days before withdraw is claimable on L1.
    @param dolaAmount Amount of DOLA to withdraw and send to L1 OptiFed
    */
    function withdrawToL1OptiFed(uint dolaAmount) external onlyChair {
        if (dolaAmount > DOLA.balanceOf(address(this))) revert NotEnoughTokens();

        bridge.withdrawTo(address(DOLA), optiFed, dolaAmount, 0, "");
    }

    /**
    @notice Withdraws `dolaAmount` of DOLA & `usdcAmount` of USDC to optiFed on L1. Will take 7 days before withdraw is claimable on L1.
    @param dolaAmount Amount of DOLA to withdraw and send to L1 OptiFed
    @param usdcAmount Amount of USDC to withdraw and send to L1 OptiFed
    */
    function withdrawToL1OptiFed(uint dolaAmount, uint usdcAmount) external onlyChair {
        if (dolaAmount > DOLA.balanceOf(address(this))) revert NotEnoughTokens();
        if (usdcAmount > USDC.balanceOf(address(this))) revert NotEnoughTokens();

        bridge.withdrawTo(address(DOLA), optiFed, dolaAmount, 0, "");
        bridge.withdrawTo(address(USDC), optiFed, usdcAmount, 0, "");
    }

    /**
    @notice Withdraws `amount` of `l2Token` to address `to` on L1. Will take 7 days before withdraw is claimable.
    @param l2Token Address of the L2 token to be withdrawn
    @param to L1 Address that tokens will be sent to
    @param amount Amount of the L2 token to be withdrawn
    */
    function withdrawTokensToL1(address l2Token, address to, uint amount) external onlyChair {
        if (amount > IERC20(l2Token).balanceOf(address(this))) revert NotEnoughTokens();

        IERC20(l2Token).approve(address(bridge), amount);
        bridge.withdrawTo(address(l2Token), to, amount, 0, "");
    }

    /**
    @notice Swap `usdcAmount` of USDC to DOLA through velodrome.
    @param usdcAmount Amount of USDC to swap to DOLA
    */
    function swapUSDCtoDOLA(uint usdcAmount) public onlyChair {
        uint minOut = usdcAmount * (PRECISION - maxSlippageBpsUsdcToDola) / PRECISION * DOLA_USDC_CONVERSION_MULTI;

        USDC.approve(address(router), usdcAmount);
        router.swapExactTokensForTokensSimple(usdcAmount, minOut, address(USDC), address(DOLA), true, address(this), block.timestamp);
    }

    /**
    @notice Swap `dolaAmount` of DOLA to USDC through velodrome.
    @param dolaAmount Amount of DOLA to swap to USDC
    */
    function swapDOLAtoUSDC(uint dolaAmount) public onlyChair { 
        uint minOut = dolaAmount * (PRECISION - maxSlippageBpsDolaToUsdc) / PRECISION / DOLA_USDC_CONVERSION_MULTI;
        
        DOLA.approve(address(router), dolaAmount);
        router.swapExactTokensForTokensSimple(dolaAmount, minOut, address(DOLA), address(USDC), true, address(this), block.timestamp);
    }

    /**
    @notice Calculates approximate price of 1 Velodrome DOLA/USDC stable pool LP token
    */
    function getLpTokenPrice(bool withdraw_) internal view returns (uint) {
        (uint dolaAmountOneLP, uint usdcAmountOneLP) = router.quoteRemoveLiquidity(address(DOLA), address(USDC), true, 0.001 ether);
        (uint dolaForRemovedUsdc,) = router.getAmountOut(usdcAmountOneLP, address(USDC), address(DOLA));
        (uint usdcForRemovedDola,) = router.getAmountOut(dolaAmountOneLP, address(DOLA), address(USDC));
        usdcForRemovedDola *= DOLA_USDC_CONVERSION_MULTI;
        usdcAmountOneLP *= DOLA_USDC_CONVERSION_MULTI;

        if (dolaAmountOneLP + dolaForRemovedUsdc > usdcAmountOneLP + usdcForRemovedDola && withdraw_) {
            return (dolaAmountOneLP + dolaForRemovedUsdc) * 1000;
        } else {
            return (usdcAmountOneLP + usdcForRemovedDola) * 1000;
        }
    }

    /**
    @notice Method for current chair of the fed to resign
    */
    function resign() external onlyChair {
        if (msg.sender == l2chair) {
            l2chair = address(0);
        } else {
            chair = address(0);
        }
    }

    /**
    @notice Governance only function for setting acceptable slippage when swapping DOLA -> USDC
    @param newMaxSlippageBps The new maximum allowed loss for DOLA -> USDC swaps. 1 = 0.01%
    */
    function setMaxSlippageDolaToUsdc(uint newMaxSlippageBps) onlyGovOrGuardian external {
        if (newMaxSlippageBps > 10000) revert MaxSlippageTooHigh();
        maxSlippageBpsDolaToUsdc = newMaxSlippageBps;
    }

    /**
    @notice Governance only function for setting acceptable slippage when swapping USDC -> DOLA
    @param newMaxSlippageBps The new maximum allowed loss for USDC -> DOLA swaps. 1 = 0.01%
    */
    function setMaxSlippageUsdcToDola(uint newMaxSlippageBps) onlyGovOrGuardian external {
        if (newMaxSlippageBps > 10000) revert MaxSlippageTooHigh();
        maxSlippageBpsUsdcToDola = newMaxSlippageBps;
    }

    /**
    @notice Governance only function for setting acceptable slippage when adding or removing liquidty from DOLA/USDC pool
    @param newMaxSlippageBps The new maximum allowed loss for adding/removing liquidity from DOLA/USDC pool. 1 = 0.01%
    */
    function setMaxSlippageLiquidity(uint newMaxSlippageBps) onlyGovOrGuardian external {
        if (newMaxSlippageBps > 10000) revert MaxSlippageTooHigh();
        maxSlippageBpsLiquidity = newMaxSlippageBps;
    }

    /**
    @notice Method for `gov` to change `pendingGov` address
    @dev `pendingGov` will have to call `claimGov` to complete `gov` transfer
    @dev `pendingGov` should be an L1 address
    @param newPendingGov_ L1 address to be set as `pendingGov`
    */
    function setPendingGov(address newPendingGov_) onlyGov external {
        pendingGov = newPendingGov_;
    }

    /**
    @notice Method for `pendingGov` to claim `gov` role.
    */
    function claimGov() external onlyPendingGov {
        gov = pendingGov;
        pendingGov = address(0);
    }

    /**
    @notice Method for gov to change treasury address, the address that receives all rewards
    @param newTreasury_ L2 address to be set as treasury
    */
    function changeTreasury(address newTreasury_) external onlyGov {
        treasury = newTreasury_;
    }

    /**
    @notice Method for gov to change the chair
    @dev chair address should be set to the address of L1 VeloFarmerMessenger if it is being used
    @param newChair_ L1 address to be set as chair
    */
    function changeChair(address newChair_) external onlyGov {
        chair = newChair_;
    }

    /**
    @notice Method for gov to change the L2 chair
    @param newL2Chair_ L2 address to be set as l2chair
    */
    function changeL2Chair(address newL2Chair_) external onlyGov {
        l2chair = newL2Chair_;
    }

    /**
    @notice Method for gov to change the guardian
    @param guardian_ L1 address to be set as guardian
    */
    function changeGuardian(address guardian_) external onlyGov {
        guardian = guardian_;
    }

    /**
    @notice Method for gov to change the L1 optiFed address
    @dev optiFed is the L1 address that receives all bridged DOLA/USDC from both withdrawToL1OptiFed functions
    @param newOptiFed_ L1 address to be set as optiFed
    */
    function changeOptiFed(address newOptiFed_) external onlyGov {
        optiFed = newOptiFed_;
    }
}