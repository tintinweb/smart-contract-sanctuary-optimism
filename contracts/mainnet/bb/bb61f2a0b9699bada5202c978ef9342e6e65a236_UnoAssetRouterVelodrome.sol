// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import './interfaces/IUnoAssetRouterVelodrome.sol'; 
import '../../interfaces/IUnoFarm.sol';
import "../../interfaces/IAggregationRouterV5.sol";
import "../../interfaces/IRouter.sol";
import "../../interfaces/IPool.sol";
import "../../interfaces/IGauge.sol"; 
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract UnoAssetRouterVelodrome is Initializable, PausableUpgradeable, UUPSUpgradeable, IUnoAssetRouterVelodrome {
	using SafeERC20 for IERC20;

	/**
	 * @dev Contract Variables:
	 * farmFactory - The contract that deploys new Farms and links them to {gauge}s.
	 * accessManager - Role manager contract.
	 */
	IUnoFarmFactory public farmFactory;
	IUnoAccessManager public accessManager;

	bytes32 private constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
	bytes32 private constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
	bytes32 private ADMIN_ROLE;

	uint256 public fee;

	address public constant WETH = 0x4200000000000000000000000000000000000006;
	IRouter private constant VelodromeRouter = IRouter(0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858);
    address private constant OneInchRouter = 0x1111111254EEB25477B68fb85Ed929f73A960582;

	modifier onlyRole(bytes32 role) {
		if(!accessManager.hasRole(role, msg.sender)) revert CALLER_NOT_AUTHORIZED();
		_;
	}

	// ============ Methods ============

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	function initialize(address _accessManager, address _farmFactory) external initializer {
        if(_accessManager == address(0)) revert INVALID_ACCESS_MANAGER();
        if(_farmFactory == address(0)) revert INVALID_FARM_FACTORY();

		__Pausable_init();

		accessManager = IUnoAccessManager(_accessManager);
		ADMIN_ROLE = accessManager.ADMIN_ROLE();
		farmFactory = IUnoFarmFactory(_farmFactory);
	}

	receive() external payable {
		//Reject deposits from EOA
        if (msg.sender == tx.origin) revert ETH_DEPOSIT_REJECTED();
	}

    /**
     * @dev Deposits tokens in the given pool. Creates new Farm contract if there isn't one deployed for the {gauge} and deposits tokens in it. Emits a {Deposit} event.
     * @param gauge - Address of the gauge to deposit tokens in.
     * @param amountA  - Token A amount to deposit.
     * @param amountB -  Token B amount to deposit.
     * @param amountAMin - Bounds the extent to which the B/A price can go up before the transaction reverts.
     * @param amountBMin - Bounds the extent to which the A/B price can go up before the transaction reverts.
     * @param recipient - Address which will receive the deposit.
     
     * @return sentA - Token A amount sent to the farm.
     * @return sentB - Token B amount sent to the farm.
     * @return liquidity - Total liquidity sent to the farm (in lpTokens).
     */
    function deposit(address gauge, uint256 amountA, uint256 amountB, uint256 amountAMin, uint256 amountBMin, address recipient) external whenNotPaused returns(uint256 sentA, uint256 sentB, uint256 liquidity){
        if(amountA == 0 || amountB == 0) revert NO_TOKENS_SENT();
        Farm farm = Farm(farmFactory.Farms(gauge));
        if(farm == Farm(address(0))){
            farm = Farm(farmFactory.createFarm(gauge));
        }

        address tokenA = farm.tokenA();
        address tokenB = farm.tokenB();
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);

        (sentA, sentB, liquidity) = _addLiquidity(tokenA, tokenB, farm.isStable(), amountA, amountB, amountAMin, amountBMin, address(farm));
        farm.deposit(liquidity, recipient);

        emit Deposit(gauge, msg.sender, recipient, liquidity); 
    }

    /**
     * @dev Autoconverts MATIC into WAVAX and deposits tokens in the given pool. Creates new Farm contract if there isn't one deployed for the {lpStakingPool} and deposits tokens in it. Emits a {Deposit} event.
     * @param gauge - Address of the gauge to deposit tokens in.
     * @param amountToken  - Token amount to deposit.
     * @param amountTokenMin - Bounds the extent to which the TOKEN/WAVAX price can go up before the transaction reverts.
     * @param amountETHMin - Bounds the extent to which the WAVAX/TOKEN price can go up before the transaction reverts.
     * @param recipient - Address which will receive the deposit.
     
     * @return sentToken - Token amount sent to the farm.
     * @return sentETH - WAVAX amount sent to the farm.
     * @return liquidity - Total liquidity sent to the farm (in lpTokens).
     */
    function depositETH(address gauge, uint256 amountToken, uint256 amountTokenMin, uint256 amountETHMin, address recipient) external payable whenNotPaused returns(uint256 sentToken, uint256 sentETH, uint256 liquidity){
        if(msg.value == 0 || amountToken == 0) revert NO_TOKENS_SENT();
        Farm farm = Farm(farmFactory.Farms(gauge));
        if(farm == Farm(address(0))){
            farm = Farm(farmFactory.createFarm(gauge));
        }

        address tokenA = farm.tokenA();
        address tokenB = farm.tokenB();
        if (tokenA == WETH) {
            IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountToken);
            (sentToken, sentETH, liquidity) = _addLiquidityETH(tokenB, farm.isStable(), amountToken, amountTokenMin, amountETHMin, address(farm));
        } else if (tokenB == WETH) {
            IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountToken);
            (sentToken, sentETH, liquidity) = _addLiquidityETH(tokenA, farm.isStable(), amountToken, amountTokenMin, amountETHMin, address(farm));
        } else revert NOT_ETH_FARM();

        farm.deposit(liquidity, recipient);

        emit Deposit(gauge, msg.sender, recipient, liquidity);
    }

    /**
     * @dev Deposits any tokens in the given pool by swapping them using 1inch. Creates new Farm contract if there isn't one deployed for the {gauge}, swaps {token} for pool tokens and deposits them. Emits a {Deposit} event.
     * @param gauge - Address of the gauge to deposit tokens in.
     * @param swapData - Parameters with which 1inch router is being called with.
     * @param recipient - Address which will receive the deposit.
     
     * @return sent0 - Tokens sent to the farm from the {swapData[0]}.
     * @return sent1 - Tokens sent to the farm from the {swapData[1]}.
     * @return dustA - TokenA dust sent to the {msg.sender}.
     * @return dustB - TokenB dust sent to the {msg.sender}.
     * @return liquidity - Total liquidity sent to the farm (in lpTokens).
     */
    function depositWithSwap(address gauge, bytes[2] calldata swapData, address recipient) external payable whenNotPaused returns(uint256 sent0, uint256 sent1, uint256 dustA, uint256 dustB, uint256 liquidity){
        Farm farm = Farm(farmFactory.Farms(gauge));
        if(farm == Farm(address(0))){
            farm = Farm(farmFactory.createFarm(gauge));
        }

        _checkMsgValue(swapData);
        
        {
        address tokenA = farm.tokenA();
        address tokenB = farm.tokenB();

        uint256 amountA; uint256 amountAMin;
        uint256 amountB; uint256 amountBMin;
        (amountA, sent0, amountAMin) = _swapDeposit(swapData[0], IERC20(tokenA));
        (amountB, sent1, amountBMin) = _swapDeposit(swapData[1], IERC20(tokenB));

        // Variable naming is not correct, however I have to do it this way to avoid Stack too deep error.
        (amountAMin, amountBMin, liquidity) = _addLiquidity(tokenA, tokenB, farm.isStable(), amountA, amountB, amountAMin, amountBMin, address(farm));
        farm.deposit(liquidity, recipient);
        
        if(amountA > amountAMin){
            dustA = amountA - amountAMin;
        }
        if(amountB > amountBMin){
            dustB = amountB - amountBMin;
        }
        }

        emit Deposit(gauge, msg.sender, recipient, liquidity);
    }

    /**
     * @dev Deposits tokens in the given pool. Creates new Farm contract if there isn't one deployed for the {gauge} and deposits tokens in it. Emits a {Deposit} event.
     * @param gauge - Address of the gauge to deposit tokens in.
     * @param amount - LP Token amount to deposit.
     * @param recipient - Address which will receive the deposit.
     */
    function depositLP(address gauge, uint256 amount, address recipient) external whenNotPaused{
        if(amount == 0) revert NO_TOKENS_SENT();
        Farm farm = Farm(farmFactory.Farms(gauge));
        if(farm == Farm(address(0))){
            farm = Farm(farmFactory.createFarm(gauge));
        }

        IERC20(farm.lpPool()).safeTransferFrom(msg.sender, address(farm), amount);
        farm.deposit(amount, recipient);

        emit Deposit(gauge, msg.sender, recipient, amount); 
    }

    /** 
     * @dev Withdraws a pair of tokens from the given pool. Emits a {Withdraw} event.
     * @param gauge - Gauge to withdraw from.
     * @param amount - LP amount to withdraw. 
     * @param amountAMin - The minimum amount of tokenA that must be received for the transaction not to revert.
     * @param amountBMin - The minimum amount of tokenB that must be received for the transaction not to revert.
     * @param recipient - The address which will receive tokens.

     * @return amountA - Token A amount sent to the {recipient}
     * @return amountB - Token B amount sent to the {recipient}
     */ 
    function withdraw(address gauge, uint256 amount, uint256 amountAMin, uint256 amountBMin, address recipient) external returns(uint256 amountA, uint256 amountB){
        Farm farm = Farm(farmFactory.Farms(gauge));
        if(farm == Farm(address(0))) revert FARM_NOT_EXISTS();

        farm.withdraw(amount, msg.sender, address(this));
        (amountA, amountB) = _removeLiquidity(farm.lpPool(), farm.tokenA(), farm.tokenB(), amount, amountAMin, amountBMin, recipient);
        
        emit Withdraw(gauge, msg.sender, recipient, amount);  
    }

    /** 
     * @dev Autoconverts WAVAX into MATIC and withdraws tokens from the pool. Emits a {Withdraw} event.
     * @param gauge - Gauge to withdraw from.
     * @param amount - LP amount to withdraw. 
     * @param amountTokenMin - The minimum amount of token that must be received for the transaction not to revert.
     * @param amountETHMin - The minimum amount of MATIC that must be received for the transaction not to revert.
     * @param recipient - The address which will receive tokens.

     * @return amountToken - Token amount sent to the {recipient}.
     * @return amountETH - MATIC amount sent to the {recipient}.
     */ 
    function withdrawETH(address gauge, uint256 amount, uint256 amountTokenMin, uint256 amountETHMin, address recipient) external returns(uint256 amountToken, uint256 amountETH){
        Farm farm = Farm(farmFactory.Farms(gauge));
        if(farm == Farm(address(0))) revert FARM_NOT_EXISTS();

        address tokenA = farm.tokenA();
        address tokenB = farm.tokenB();

        farm.withdraw(amount, msg.sender, address(this));
        if (tokenA == WETH) {
            (amountToken, amountETH) = _removeLiquidityETH(farm.lpPool(), tokenB, amount, amountTokenMin, amountETHMin, recipient);
        } else if (tokenB == WETH) {
            (amountToken, amountETH) = _removeLiquidityETH(farm.lpPool(), tokenA, amount, amountTokenMin, amountETHMin, recipient);
        } else revert NOT_ETH_FARM();

        emit Withdraw(gauge, msg.sender, recipient, amount);
    }

    /**
     * @dev Withdraws tokens from the given pool and swap them using 1inch. Emits a {Withdraw} event. Note: If there are any tokens left to be withdrawn after swaps they will be sent to the {{recipient}} in a respective token.
     * @param gauge - Gauge to withdraw from.
     * @param amount - LP amount to withdraw. 
     * @param swapData - Parameters with which 1inch router is being called with.
     * @param recipient - The address which will receive tokens.
     
     * @return amount0 - Tokens sent to the {recipient} from the {swapData[0]}.
     * @return amount1 - Tokens sent to the {recipient} from the {swapData[1]}.
     * @return amountA - TokenA dust sent to the {recipient}.
     * @return amountB - TokenB dust to the {recipient}.
     */
    function withdrawWithSwap(address gauge, uint256 amount, bytes[2] calldata swapData, address recipient) external returns(uint256 amount0, uint256 amount1, uint256 amountA, uint256 amountB){
        Farm farm = Farm(farmFactory.Farms(gauge));
        if(farm == Farm(address(0))) revert FARM_NOT_EXISTS();

        farm.withdraw(amount, msg.sender, address(this));

        address tokenA = farm.tokenA();
        address tokenB = farm.tokenB();
        (uint256 _amountA, uint256 _amountB) = _removeLiquidity(farm.lpPool(), tokenA, tokenB, amount, 0, 0, address(this));
        
        (amount0, amountA) = _swapWithdraw(swapData[0], IERC20(tokenA), _amountA, recipient);
        (amount1, amountB) = _swapWithdraw(swapData[1], IERC20(tokenB), _amountB, recipient);

        emit Withdraw(gauge, msg.sender, recipient, amount);
    }

    /** 
     * @dev Withdraws LP tokens from the given pool. Emits a {Withdraw} event.
     * @param gauge - Gauge to withdraw from.
     * @param amount - LP amount to withdraw. 
     * @param recipient - The address which will receive tokens.
     */ 
    function withdrawLP(address gauge, uint256 amount, address recipient) external {
        Farm farm = Farm(farmFactory.Farms(gauge));
        if(farm == Farm(address(0))) revert FARM_NOT_EXISTS();
        
        farm.withdraw(amount, msg.sender, recipient);
        emit Withdraw(gauge, msg.sender, recipient, amount);  
    }

    /**
     * @dev Distributes tokens between users.
     * @param gauge - Gauge to distribute tokens in.
     * @param swapInfos - Arrays of structs with token arrays describing swap routes (rewardTokenToTokenA, rewardTokenToTokenB, rewarderTokenToTokenA, rewarderTokenToTokenB) and minimum amounts of output tokens that must be received for the transaction not to revert.
     * @param feeTo - Address to collect fees to.
     *
     * Note: This function can only be called by the distributor.
     */ 
    function distribute(
        address gauge,
        Farm.SwapInfo[2] calldata swapInfos,
        address feeTo
    ) external whenNotPaused onlyRole(DISTRIBUTOR_ROLE) returns(uint256 reward){
        Farm farm = Farm(farmFactory.Farms(gauge));
        if(farm == Farm(address(0))) revert FARM_NOT_EXISTS();

        //I don't understand why the definition for FeeInfo can not be imported from Farm
        reward = farm.distribute(swapInfos, IUnoFarm.FeeInfo(feeTo, fee));
        emit Distribute(gauge, reward);
    }

    /**
     * @dev Returns tokens staked by the {_address} for the given {gauge}.
     * @param _address - The address to check stakes for.
     * @param gauge - Gauge to check stakes in.

     * @return stakeLP - Total user stake(in LP tokens).
     * @return stakeA - Token A stake.
     * @return stakeB - Token B stake.
     */
    function userStake(address _address, address gauge) external view returns (uint256 stakeLP, uint256 stakeA, uint256 stakeB) {
        Farm farm = Farm(farmFactory.Farms(gauge));
        if (farm != Farm(address(0))) {
            stakeLP = farm.userBalance(_address);
            (stakeA, stakeB) = _getTokenStake(gauge, stakeLP);
        }
    }

    /**
     * @dev Returns total amount locked in the pool. Doesn't take pending rewards into account.
     * @param gauge - Gauge to check total deposits in.

     * @return totalDepositsLP - Total deposits (in LP tokens).
     * @return totalDepositsA - Token A deposits.
     * @return totalDepositsB - Token B deposits.
     */  
    function totalDeposits(address gauge) external view returns (uint256 totalDepositsLP, uint256 totalDepositsA, uint256 totalDepositsB) {
        Farm farm = Farm(farmFactory.Farms(gauge));
        if (farm != Farm(address(0))) {
            totalDepositsLP = farm.getTotalDeposits();
            (totalDepositsA, totalDepositsB) = _getTokenStake(gauge, totalDepositsLP);
        }
    }

    /**
     * @dev Returns addresses of tokens in {gauge}.
     * @param gauge - gauge to check tokens in.

     * @return tokens - Tokens addresses.
     */  
    function getTokens(address gauge) external view returns(IERC20[] memory tokens){
        IPool lpPair = IPool(IGauge(gauge).stakingToken());
        tokens = new IERC20[](2);
        tokens[0] = IERC20(lpPair.token0());
        tokens[1] = IERC20(lpPair.token1());
    }

    /**
     * @dev Deposits assets to router & refunds dust.
     */ 
    function _addLiquidity(
        address tokenA,
        address tokenB, 
        bool isStable,
        uint256 amountA, 
        uint256 amountB, 
        uint256 amountAMin, 
        uint256 amountBMin, 
        address farm
    ) internal returns(uint256 sentA, uint256 sentB, uint256 liquidity){
        IERC20(tokenA).approve(address(VelodromeRouter), amountA);
        IERC20(tokenB).approve(address(VelodromeRouter), amountB);

        (sentA, sentB, liquidity) = VelodromeRouter.addLiquidity(tokenA, tokenB, isStable, amountA, amountB, amountAMin, amountBMin, farm, block.timestamp);
        // Refund dust
        if(amountA > sentA){
            IERC20(tokenA).safeTransfer(msg.sender, amountA - sentA);
        }
        if(amountB > sentB){
		    IERC20(tokenB).safeTransfer(msg.sender, amountB - sentB);
        }
    }

    /**
     * @dev Deposits assets to router & refunds dust.
     */ 
    function _addLiquidityETH(
        address token,
        bool isStable,
        uint256 amount, 
        uint256 amountTokenMin, 
        uint256 amountETHMin, 
        address farm
    ) internal returns(uint256 sentToken, uint256 sentETH, uint256 liquidity){
        IERC20(token).approve(address(VelodromeRouter), amount);

        (sentToken, sentETH, liquidity) = VelodromeRouter.addLiquidityETH{value: msg.value}(token, isStable, amount, amountTokenMin, amountETHMin, farm, block.timestamp);
        // Refund dust
        if(amount > sentToken){
            IERC20(token).safeTransfer(msg.sender, amount - sentToken);
        }
        if(msg.value > sentETH){
            payable(msg.sender).transfer(msg.value - sentETH);
        }
    }

    /**
     * @dev Withdraws assets from router.
     */ 
    function _removeLiquidity(
        address lpPair,
        address tokenA,
        address tokenB, 
        uint256 amount, 
        uint256 amountAMin, 
        uint256 amountBMin, 
        address recipient
    ) internal returns(uint256 amountA, uint256 amountB){
        IERC20(lpPair).approve(address(VelodromeRouter), amount);
        (amountA, amountB) = VelodromeRouter.removeLiquidity(tokenA, tokenB, IPool(lpPair).stable(), amount, amountAMin, amountBMin, recipient, block.timestamp);
    }

    /**
     * @dev Withdraws assets from router.
     */ 
    function _removeLiquidityETH(
        address lpPair,
        address token,
        uint256 amount, 
        uint256 amountTokenMin, 
        uint256 amountETHMin, 
        address recipient
    ) internal returns(uint256 amountToken, uint256 amountETH){
        IERC20(lpPair).approve(address(VelodromeRouter), amount);
        (amountToken, amountETH) = VelodromeRouter.removeLiquidityETH(token, IPool(lpPair).stable(), amount, amountTokenMin, amountETHMin, recipient, block.timestamp);
    }

    function _swapDeposit(bytes calldata swapData, IERC20 toToken) internal returns(uint256 returnAmount, uint256 spentAmount, uint256 amountMin){
        (,IAggregationRouterV5.SwapDescription memory desc,) = abi.decode(swapData[4:], (address, IAggregationRouterV5.SwapDescription, bytes));
        
        amountMin = desc.minReturnAmount;
        if(desc.srcToken == toToken){
            if(desc.amount == 0) revert INVALID_SWAP_DESCRIPTION();
            desc.srcToken.safeTransferFrom(msg.sender, address(this), desc.amount);
            return (desc.amount, desc.amount, amountMin);
        }
        
        if(
            bytes4(swapData[:4]) != IAggregationRouterV5.swap.selector || 
            desc.dstToken != toToken || 
            desc.amount == 0 ||
            desc.dstReceiver != address(this)
        ) revert INVALID_SWAP_DESCRIPTION();

        bool isETH = (address(desc.srcToken) == address(0) || address(desc.srcToken) == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE));
        if(!isETH){
            desc.srcToken.safeTransferFrom(msg.sender, address(this), desc.amount);
            desc.srcToken.approve(OneInchRouter, desc.amount);
        }

        {
        uint256 value = isETH ? desc.amount : 0;
        (bool success, bytes memory data) = OneInchRouter.call{value: value}(swapData);
        if(!success) revert SWAP_NOT_SUCCESSFUL();
        (returnAmount, spentAmount) = abi.decode(data, (uint256, uint256));
        }

        if(desc.amount > spentAmount){
            if(isETH){
                (bool success, ) = msg.sender.call{value: desc.amount - spentAmount}("");
                if(!success) revert TRANSFER_NOT_SUCCESSFUL();
            }else{
                desc.srcToken.safeTransfer(address(msg.sender), desc.amount - spentAmount);
            }
        }
    }
 
    function _swapWithdraw(bytes calldata swapData, IERC20 fromToken, uint256 maxAmount, address recipient) internal returns(uint256 returnAmount, uint256 dust){
        (,IAggregationRouterV5.SwapDescription memory desc,) = abi.decode(swapData[4:], (address, IAggregationRouterV5.SwapDescription, bytes));
        
        if(desc.dstToken == fromToken){
            fromToken.safeTransfer(recipient, maxAmount);
            return (maxAmount, 0);
        }
        
        if(
            bytes4(swapData[:4]) != IAggregationRouterV5.swap.selector || 
            desc.srcToken != fromToken ||
            desc.amount == 0 ||
            desc.dstReceiver != recipient
        ) revert INVALID_SWAP_DESCRIPTION();

        desc.srcToken.approve(OneInchRouter, desc.amount);
        (bool success, bytes memory data) = OneInchRouter.call(swapData);
        if(!success) revert SWAP_NOT_SUCCESSFUL();
        uint256 spentAmount;
        (returnAmount, spentAmount) = abi.decode(data, (uint256, uint256));

        if(maxAmount > spentAmount){
            dust = maxAmount - spentAmount;
            desc.srcToken.safeTransfer(recipient, dust);
        } else if(maxAmount != spentAmount) revert INSUFFICIENT_AMOUNT();
    }

    function _checkMsgValue(bytes[2] calldata swapData) internal view {
        uint256 value;

        (,IAggregationRouterV5.SwapDescription memory desc0,) = abi.decode(swapData[0][4:], (address, IAggregationRouterV5.SwapDescription, bytes));
        if(address(desc0.srcToken) == address(0) || address(desc0.srcToken) == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)){
            value = desc0.amount;
        }

        (,IAggregationRouterV5.SwapDescription memory desc1,) = abi.decode(swapData[1][4:], (address, IAggregationRouterV5.SwapDescription, bytes));
        if(address(desc1.srcToken) == address(0) || address(desc1.srcToken) == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)){
            value += desc1.amount;
        }

        if(msg.value != value) revert INVALID_MSG_VALUE();
    }

    /**
     * @dev Converts LP tokens to normal tokens, value(amountA) == value(amountB) == 0.5*amountLP
     * @param gauge - Gauge for conversion.
     * @param amountLP - Amount of LP tokens to convert.

     * @return amountA - Token A amount.
     * @return amountB - Token B amount.
     */ 
    function _getTokenStake(address gauge, uint256 amountLP) internal view returns (uint256 amountA, uint256 amountB) {
        address lpPair = IGauge(gauge).stakingToken();
        uint256 totalSupply = IERC20(lpPair).totalSupply();
        amountA = amountLP * IERC20(IPool(lpPair).token0()).balanceOf(lpPair) / totalSupply;
        amountB = amountLP * IERC20(IPool(lpPair).token1()).balanceOf(lpPair) / totalSupply;
    }

    /**
     * @dev Change fee amount.
     * @param _fee -New fee to collect from farms. [10^18 == 100%]
     *
     * Note: This function can only be called by ADMIN_ROLE.
     */ 
    function setFee(uint256 _fee) external onlyRole(ADMIN_ROLE){
        if(_fee > 1 ether) revert MAX_FEE_EXCEEDED(1 ether);
        if(fee != _fee){
            emit FeeChanged(fee, _fee); 
            fee = _fee;
        }
    }
 
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address) internal override onlyRole(ADMIN_ROLE) {

    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
pragma experimental ABIEncoderV2;
import "./IUnoAccessManager.sol";

interface IUnoFarmFactory {
	event FarmDeployed(address indexed farmAddress);

	function accessManager() external view returns (IUnoAccessManager);

	function assetRouter() external view returns (address);

	function farmBeacon() external view returns (address);

	function pools(uint256) external view returns (address);

	function Farms(address) external view returns (address);

	function createFarm(address pool) external returns (address);

	function poolLength() external view returns (uint256);

	function upgradeFarms(address newImplementation) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IUnoFarm {
    /**
     * @dev DistributionInfo:
     * {block} - Distribution block number.
     * {rewardPerDepositAge} - Distribution reward divided by {totalDepositAge}. 
     * {cumulativeRewardAgePerDepositAge} - Sum of {rewardPerDepositAge}s multiplied by distribution interval.
     */
    struct DistributionInfo {
        uint256 block;
        uint256 rewardPerDepositAge;
        uint256 cumulativeRewardAgePerDepositAge;
    }
    /**
     * @dev UserInfo:
     * {stake} - Amount of LP tokens deposited by the user.
     * {depositAge} - User deposits multiplied by blocks the deposit has been in. 
     * {reward} - Amount of LP tokens entitled to the user.
     * {lastDistribution} - Distribution ID before the last user deposit.
     * {lastUpdate} - Deposit update block.
     */
    struct UserInfo {
        uint256 stake;
        uint256 depositAge;
        uint256 reward;
        uint32 lastDistribution;
        uint256 lastUpdate;
    }
    /**
     * @dev FeeInfo:
     * {feeCollector} - Contract to transfer fees to.
     * {fee} - Fee percentage to collect (10^18 == 100%). 
     */
    struct FeeInfo {
        address feeTo;
        uint256 fee;
    }

    error CALLER_NOT_ASSET_ROUTER();
    error INVALID_LP_POOL();
    error INVALID_ASSET_ROUTER();
    error NO_LIQUIDITY_PROVIDED();
    error INSUFFICIENT_AMOUNT();
    error INSUFFICIENT_BALANCE();
    error NO_LIQUIDITY();
    error CALL_ON_THE_SAME_BLOCK();
    error INVALID_ROUTE(address fromToken, address toToken);

	function rewardToken() external view returns (address);
	function tokenA() external view returns (address);
	function tokenB() external view returns (address);
    
    function lpPool() external view returns (address);
    function assetRouter() external view returns (address);

    function initialize(address _gauge, address _assetRouter) external;

    function deposit(uint256 amountLP, address recipient) external;
    function withdraw(uint256 amount, address origin, address recipient) external;

    function userBalance(address _address) external view returns (uint256);
    function getTotalDeposits() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
pragma experimental ABIEncoderV2;

import './IUnoFarmFactory.sol';
import './IUnoAccessManager.sol'; 
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IUnoAssetRouter {
    event Deposit(address indexed lpPool, address indexed sender, address indexed recipient, uint256 amount);
    event Withdraw(address indexed lpPool, address indexed sender, address indexed recipient, uint256 amount);
    event Distribute(address indexed lpPool, uint256 reward);

    event FeeChanged(uint256 previousFee, uint256 newFee);

    error ETH_DEPOSIT_REJECTED();
    error CALLER_NOT_AUTHORIZED();
    error FARM_NOT_EXISTS();
    error NOT_ETH_FARM();
    error INVALID_MSG_VALUE();
    error INVALID_SWAP_DESCRIPTION();
    error INVALID_ACCESS_MANAGER();
    error INVALID_FARM_FACTORY();
    error SWAP_NOT_SUCCESSFUL();
    error TRANSFER_NOT_SUCCESSFUL();
    error INSUFFICIENT_AMOUNT();
    error NO_TOKENS_SENT();
    error MAX_FEE_EXCEEDED(uint256 maxFee);

    function farmFactory() external view returns(IUnoFarmFactory);
    function accessManager() external view returns(IUnoAccessManager);
    function fee() external view returns(uint256);
    function WETH() external view returns(address);

    function deposit(address lpPair, uint256 amountA, uint256 amountB, uint256 amountAMin, uint256 amountBMin, address recipient) external returns(uint256 sentA, uint256 sentB, uint256 liquidity);
    function depositETH(address lpPair, uint256 amountToken, uint256 amountTokenMin, uint256 amountETHMin, address recipient) external payable returns(uint256 sentToken, uint256 sentETH, uint256 liquidity);
    function depositWithSwap(address lpPair, bytes[2] calldata swapData, address recipient) external payable returns(uint256 sent0, uint256 sent1, uint256 dustA, uint256 dustB, uint256 liquidity);
    function depositLP(address lpPair, uint256 amount, address recipient) external;

    function withdraw(address lpPair, uint256 amount, uint256 amountAMin, uint256 amountBMin, address recipient) external returns(uint256 amountA, uint256 amountB);
    function withdrawETH(address lpPair, uint256 amount, uint256 amountTokenMin, uint256 amountETHMin, address recipient) external returns(uint256 amountToken, uint256 amountETH);
    function withdrawWithSwap(address lpPair, uint256 amount, bytes[2] calldata swapData, address recipient) external returns(uint256 amount0, uint256 amount1, uint256 amountA, uint256 amountB);
    function withdrawLP(address lpPair, uint256 amount, address recipient) external;

    function initialize(address _accessManager, address _farmFactory) external;

    function userStake(address _address, address lpPair) external view returns (uint256 stakeLP, uint256 stakeA, uint256 stakeB);
    function totalDeposits(address lpPair) external view returns (uint256 totalDepositsLP, uint256 totalDepositsA, uint256 totalDepositsB);
    function getTokens(address lpPair) external view returns(IERC20[] memory tokens);

    function setFee(uint256 _fee) external;

    function pause() external;
    function unpause() external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
pragma experimental ABIEncoderV2;

interface IUnoAccessManager {
	event RoleGranted(bytes32 indexed role, address indexed account);
	event RoleRevoked(bytes32 indexed role, address indexed account);

	function hasRole(bytes32 role, address account)
		external
		view
		returns (bool);

	function ADMIN_ROLE() external view returns (bytes32);

	function grantRole(bytes32 role, address account) external;

	function revokeRole(bytes32 role, address account) external;
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

    error ConversionFromV2ToV1VeloProhibited();
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
    error PoolFactoryDoesNotExist();
    error SameAddresses();
    error ZeroAddress();

    /// @dev Struct containing information necessary to zap in and out of pools
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           Stable or volatile pool
    /// @param factory          factory of pool
    /// @param amountOutMinA    Minimum amount expected from swap leg of zap via routesA
    /// @param amountOutMinB    Minimum amount expected from swap leg of zap via routesB
    /// @param amountAMin       Minimum amount of tokenA expected from liquidity leg of zap
    /// @param amountBMin       Minimum amount of tokenB expected from liquidity leg of zap
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

    /// @notice Sort two tokens by which address value is less than the other
    /// @param tokenA   Address of token to sort
    /// @param tokenB   Address of token to sort
    /// @return token0  Lower address value between tokenA and tokenB
    /// @return token1  Higher address value between tokenA and tokenB
    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);

    /// @notice Calculate the address of a pool by its' factory.
    ///         Used by all Router functions containing a `Route[]` or `_factory` argument.
    ///         Reverts if _factory is not approved by the FactoryRegistry
    /// @dev Returns a randomly generated address for a nonexistent pool
    /// @param tokenA   Address of token to query
    /// @param tokenB   Address of token to query
    /// @param stable   True if pool is stable, false if volatile
    /// @param _factory Address of factory which created the pool
    function poolFor(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory
    ) external view returns (address pool);

    /// @notice Wraps around poolFor(tokenA,tokenB,stable,_factory) for backwards compatibility to Velodrome v1
    function pairFor(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory
    ) external view returns (address pool);

    /// @notice Fetch and sort the reserves for a pool
    /// @param tokenA       .
    /// @param tokenB       .
    /// @param stable       True if pool is stable, false if volatile
    /// @param _factory     Address of PoolFactory for tokenA and tokenB
    /// @return reserveA    Amount of reserves of the sorted token A
    /// @return reserveB    Amount of reserves of the sorted token B
    function getReserves(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory
    ) external view returns (uint256 reserveA, uint256 reserveB);

    /// @notice Perform chained getAmountOut calculations on any number of pools
    function getAmountsOut(uint256 amountIn, Route[] memory routes) external view returns (uint256[] memory amounts);

    // **** ADD LIQUIDITY ****

    /// @notice Quote the amount deposited into a Pool
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           True if pool is stable, false if volatile
    /// @param _factory         Address of PoolFactory for tokenA and tokenB
    /// @param amountADesired   Amount of tokenA desired to deposit
    /// @param amountBDesired   Amount of tokenB desired to deposit
    /// @return amountA         Amount of tokenA to actually deposit
    /// @return amountB         Amount of tokenB to actually deposit
    /// @return liquidity       Amount of liquidity token returned from deposit
    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 amountADesired,
        uint256 amountBDesired
    ) external view returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /// @notice Quote the amount of liquidity removed from a Pool
    /// @param tokenA       .
    /// @param tokenB       .
    /// @param stable       True if pool is stable, false if volatile
    /// @param _factory     Address of PoolFactory for tokenA and tokenB
    /// @param liquidity    Amount of liquidity to remove
    /// @return amountA     Amount of tokenA received
    /// @return amountB     Amount of tokenB received
    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 liquidity
    ) external view returns (uint256 amountA, uint256 amountB);

    /// @notice Add liquidity of two tokens to a Pool
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           True if pool is stable, false if volatile
    /// @param amountADesired   Amount of tokenA desired to deposit
    /// @param amountBDesired   Amount of tokenB desired to deposit
    /// @param amountAMin       Minimum amount of tokenA to deposit
    /// @param amountBMin       Minimum amount of tokenB to deposit
    /// @param to               Recipient of liquidity token
    /// @param deadline         Deadline to receive liquidity
    /// @return amountA         Amount of tokenA to actually deposit
    /// @return amountB         Amount of tokenB to actually deposit
    /// @return liquidity       Amount of liquidity token returned from deposit
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

    /// @notice Add liquidity of a token and WETH (transferred as ETH) to a Pool
    /// @param token                .
    /// @param stable               True if pool is stable, false if volatile
    /// @param amountTokenDesired   Amount of token desired to deposit
    /// @param amountTokenMin       Minimum amount of token to deposit
    /// @param amountETHMin         Minimum amount of ETH to deposit
    /// @param to                   Recipient of liquidity token
    /// @param deadline             Deadline to add liquidity
    /// @return amountToken         Amount of token to actually deposit
    /// @return amountETH           Amount of tokenETH to actually deposit
    /// @return liquidity           Amount of liquidity token returned from deposit
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

    /// @notice Remove liquidity of two tokens from a Pool
    /// @param tokenA       .
    /// @param tokenB       .
    /// @param stable       True if pool is stable, false if volatile
    /// @param liquidity    Amount of liquidity to remove
    /// @param amountAMin   Minimum amount of tokenA to receive
    /// @param amountBMin   Minimum amount of tokenB to receive
    /// @param to           Recipient of tokens received
    /// @param deadline     Deadline to remove liquidity
    /// @return amountA     Amount of tokenA received
    /// @return amountB     Amount of tokenB received
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

    /// @notice Remove liquidity of a token and WETH (returned as ETH) from a Pool
    /// @param token            .
    /// @param stable           True if pool is stable, false if volatile
    /// @param liquidity        Amount of liquidity to remove
    /// @param amountTokenMin   Minimum amount of token to receive
    /// @param amountETHMin     Minimum amount of ETH to receive
    /// @param to               Recipient of liquidity token
    /// @param deadline         Deadline to receive liquidity
    /// @return amountToken     Amount of token received
    /// @return amountETH       Amount of ETH received
    function removeLiquidityETH(
        address token,
        bool stable,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    /// @notice Remove liquidity of a fee-on-transfer token and WETH (returned as ETH) from a Pool
    /// @param token            .
    /// @param stable           True if pool is stable, false if volatile
    /// @param liquidity        Amount of liquidity to remove
    /// @param amountTokenMin   Minimum amount of token to receive
    /// @param amountETHMin     Minimum amount of ETH to receive
    /// @param to               Recipient of liquidity token
    /// @param deadline         Deadline to receive liquidity
    /// @return amountETH       Amount of ETH received
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

    /// @notice Swap one token for another
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    /// @return amounts     Array of amounts returned per route
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swap ETH for a token
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    /// @return amounts     Array of amounts returned per route
    function swapExactETHForTokens(
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    /// @notice Swap a token for WETH (returned as ETH)
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired ETH
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    /// @return amounts     Array of amounts returned per route
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swap one token for another without slippage protection
    /// @return amounts     Array of amounts to swap  per route
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    function UNSAFE_swapExactTokensForTokens(
        uint256[] memory amounts,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);

    // **** SWAP (supporting fee-on-transfer tokens) ****

    /// @notice Swap one token for another supporting fee-on-transfer tokens
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external;

    /// @notice Swap ETH for a token supporting fee-on-transfer tokens
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable;

    /// @notice Swap a token for WETH (returned as ETH) supporting fee-on-transfer tokens
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired ETH
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
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
    /// @param tokenIn      Token you are zapping in from (i.e. input token).
    /// @param amountInA    Amount of input token you wish to send down routesA
    /// @param amountInB    Amount of input token you wish to send down routesB
    /// @param zapInPool    Contains zap struct information. See Zap struct.
    /// @param routesA      Route used to convert input token to tokenA
    /// @param routesB      Route used to convert input token to tokenB
    /// @param to           Address you wish to mint liquidity to.
    /// @param stake        Auto-stake liquidity in corresponding gauge.
    /// @return liquidity   Amount of LP tokens created from zapping in.
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
    /// @param tokenOut     Token you are zapping out to (i.e. output token).
    /// @param liquidity    Amount of liquidity you wish to remove.
    /// @param zapOutPool   Contains zap struct information. See Zap struct.
    /// @param routesA      Route used to convert tokenA into output token.
    /// @param routesB      Route used to convert tokenB into output token.
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
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           .
    /// @param _factory         .
    /// @param amountInA        Amount of input token you wish to send down routesA
    /// @param amountInB        Amount of input token you wish to send down routesB
    /// @param routesA          Route used to convert input token to tokenA
    /// @param routesB          Route used to convert input token to tokenB
    /// @return amountOutMinA   Minimum output expected from swapping input token to tokenA.
    /// @return amountOutMinB   Minimum output expected from swapping input token to tokenB.
    /// @return amountAMin      Minimum amount of tokenA expected from depositing liquidity.
    /// @return amountBMin      Minimum amount of tokenB expected from depositing liquidity.
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
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           .
    /// @param _factory         .
    /// @param liquidity        Amount of liquidity being zapped out of into a given output token.
    /// @param routesA          Route used to convert tokenA into output token.
    /// @param routesB          Route used to convert tokenB into output token.
    /// @return amountOutMinA   Minimum output expected from swapping tokenA into output token.
    /// @return amountOutMinB   Minimum output expected from swapping tokenB into output token.
    /// @return amountAMin      Minimum amount of tokenA expected from withdrawing liquidity.
    /// @return amountBMin      Minimum amount of tokenB expected from withdrawing liquidity.
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
    /// @param tokenA   tokenA of stable pool you are zapping into.
    /// @param tokenB   tokenB of stable pool you are zapping into.
    /// @param factory  Factory that created stable pool.
    /// @return ratio   Ratio of token0 to token1 required to deposit into zap.
    function quoteStableLiquidityRatio(
        address tokenA,
        address tokenB,
        address factory
    ) external view returns (uint256 ratio);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPool {
    error DepositsNotEqual();
    error BelowMinimumK();
    error FactoryAlreadySet();
    error InsufficientLiquidity();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error InsufficientOutputAmount();
    error InsufficientInputAmount();
    error IsPaused();
    error InvalidTo();
    error K();
    error NotEmergencyCouncil();

    event Fees(address indexed sender, uint256 amount0, uint256 amount1);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, address indexed to, uint256 amount0, uint256 amount1);
    event Swap(
        address indexed sender,
        address indexed to,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out
    );
    event Sync(uint256 reserve0, uint256 reserve1);
    event Claim(address indexed sender, address indexed recipient, uint256 amount0, uint256 amount1);

    function metadata()
        external
        view
        returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1);

    function claimFees() external returns (uint256, uint256);

    function tokens() external view returns (address, address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function stable() external view returns (bool);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    function mint(address to) external returns (uint256 liquidity);

    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast);

    function getAmountOut(uint256, address) external view returns (uint256);

    function skim(address to) external;

    function initialize(address _token0, address _token1, bool _stable) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
interface IGauge is IERC20 {
    error NotAlive();
    error NotAuthorized();
    error NotVoter();
    error RewardRateTooHigh();
    error ZeroAmount();
    error ZeroRewardRate();

    event Deposit(address indexed from, address indexed to, uint256 amount);
    event Withdraw(address indexed from, uint256 amount);
    event NotifyReward(address indexed from, uint256 amount);
    event ClaimFees(address indexed from, uint256 claimed0, uint256 claimed1);
    event ClaimRewards(address indexed from, uint256 amount);

    function rewardToken() external view returns (address);

    function rewardPerToken() external view returns (uint256 _rewardPerToken);

    /// @notice Returns the last time the reward was modified or periodFinish if the reward has ended
    function lastTimeRewardApplicable() external view returns (uint256 _time);

    /// @notice Returns accrued balance to date from last claim / first deposit.
    function earned(address _account) external view returns (uint256 _earned);

    function left() external view returns (uint256 _left);

    /// @notice Returns if gauge is linked to a legitimate Velodrome pool
    function isPool() external view returns (bool _isPool);

    function stakingToken() external view returns (address _pool);

    /// @notice Retrieve rewards for an address.
    /// @dev Throws if not called by same address or voter.
    /// @param _account .
    function getReward(address _account) external;

    /// @notice Deposit LP tokens into gauge for msg.sender
    /// @param _amount .
    function deposit(uint256 _amount) external;

    /// @notice Deposit LP tokens into gauge for any user
    /// @param _amount .
    /// @param _recipient Recipient to give balance to
    function deposit(uint256 _amount, address _recipient) external;

    /// @notice Withdraw LP tokens for user
    /// @param _amount .
    function withdraw(uint256 _amount) external;

    /// @dev Notifies gauge of gauge rewards. Assumes gauge reward tokens is 18 decimals.
    ///      If not 18 decimals, rewardRate may have rounding issues.
    function notifyRewardAmount(uint256 amount) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IAggregationRouterV5 {
    struct SwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    function swap(
        address executor,
        SwapDescription calldata desc,
        bytes calldata permit,
        bytes calldata data
    ) external payable returns (uint256 returnAmount, uint256 spentAmount);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '../../../interfaces/IUnoFarm.sol';
import "../../../interfaces/IGauge.sol"; 
import "../../../interfaces/IRouter.sol";

interface IUnoFarmVelodrome is IUnoFarm { 
	/**
     * @dev SwapInfo:
     * {route} - Array of token addresses describing swap routes.
     * {amountOutMin} - The minimum amount of output token that must be received for the transaction not to revert.
     */
    struct SwapInfo{
        IRouter.Route[] route;
        uint256 amountOutMin;
    }

    error INVALID_GAUGE();

    function isStable() external view returns (bool);
    function gauge() external view returns (IGauge);
    
    function distribute(
        SwapInfo[2] calldata swapInfos,
        FeeInfo calldata feeInfo
    ) external returns(uint256 reward);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IUnoFarmVelodrome as Farm} from './IUnoFarmVelodrome.sol'; 
import '../../../interfaces/IUnoAssetRouter.sol';

interface IUnoAssetRouterVelodrome is IUnoAssetRouter {
	function distribute(
		address lpPair,
		Farm.SwapInfo[2] calldata swapInfos,
		address feeTo
	) external returns(uint256 reward);
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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/StorageSlot.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlotUpgradeable {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly {
            r.slot := slot
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

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
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
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
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../ERC1967/ERC1967UpgradeUpgradeable.sol";
import "./Initializable.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822ProxiableUpgradeable, ERC1967UpgradeUpgradeable {
    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }

    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate that the this implementation remains valid after an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
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
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
     */
    modifier initializer() {
        bool isTopLevelCall = _setInitializedVersion(1);
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     */
    modifier reinitializer(uint8 version) {
        bool isTopLevelCall = _setInitializedVersion(version);
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(version);
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     */
    function _disableInitializers() internal virtual {
        _setInitializedVersion(type(uint8).max);
    }

    function _setInitializedVersion(uint8 version) private returns (bool) {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, and for the lowest level
        // of initializers, because in other contexts the contract may have been reentered.
        if (_initializing) {
            require(
                version == 1 && !AddressUpgradeable.isContract(address(this)),
                "Initializable: contract is already initialized"
            );
            return false;
        } else {
            require(_initialized < version, "Initializable: contract is already initialized");
            _initialized = version;
            return true;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeaconUpgradeable {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeaconUpgradeable.sol";
import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/StorageSlotUpgradeable.sol";
import "../utils/Initializable.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967UpgradeUpgradeable is Initializable {
    function __ERC1967Upgrade_init() internal onlyInitializing {
    }

    function __ERC1967Upgrade_init_unchained() internal onlyInitializing {
    }
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(AddressUpgradeable.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822ProxiableUpgradeable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(AddressUpgradeable.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            AddressUpgradeable.isContract(IBeaconUpgradeable(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(IBeaconUpgradeable(newBeacon).implementation(), data);
        }
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822ProxiableUpgradeable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}