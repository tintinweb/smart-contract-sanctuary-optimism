//SPDX-License-Identifier: None
pragma solidity =0.7.6;
pragma abicoder v2;

import "./router/SwapRouter.sol";
import "./router/libs/IERC20.sol";

interface UniswapV3Pool {
    function token0() external returns (address);
    function token1() external returns (address);
    function fee() external returns (uint24);
}

contract LlamaZip is SwapRouter {
    address internal immutable owner; // Set to internal to avoid collisions
    uint internal constant MAX_BPS = 10000;

    constructor(address _factory, address _WETH9, address _owner) SwapRouter(_factory, _WETH9) {
        owner = _owner;
    }

    struct Pool {
        address token0;
        address token1;
        uint24 fee;
    }

    mapping(uint => Pool) internal pools;

    function setPool(uint id, address pool) internal {
        require(pools[id].token0 == address(0) && pools[id].token1 == address(0), "already set");

        pools[id] = Pool({
            fee: UniswapV3Pool(pool).fee(),
            token0: UniswapV3Pool(pool).token0(),
            token1: UniswapV3Pool(pool).token1()
        });
    }

    function getPool(uint poolId) view internal returns (Pool memory pool){
        if(poolId == 0){
            return Pool(0x4200000000000000000000000000000000000006, 0x7F5c764cBc14f9669B88837ca1490cCa17c31607, 500); // WETH / USDC 0.05%
        } else if(poolId == (1 << 252)){
            return Pool(0x4200000000000000000000000000000000000006, 0x4200000000000000000000000000000000000042, 3000); // WETH / OP 0.3%
        } else if(poolId == (2 << 252)){
            return Pool(0x4200000000000000000000000000000000000042, 0x7F5c764cBc14f9669B88837ca1490cCa17c31607, 3000); // OP / USDC 0.3%
        } else if(poolId == (3 << 252)){
            return Pool(0x4200000000000000000000000000000000000006, 0x4200000000000000000000000000000000000042, 500); // WETH / OP 0.05%
        } else if(poolId == (4 << 252)){
            return Pool(0x7F5c764cBc14f9669B88837ca1490cCa17c31607, 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1, 100); // USDC / DAI 0.01%
        } else if(poolId == (5 << 252)){
            return Pool(0x4200000000000000000000000000000000000006, 0x8700dAec35aF8Ff88c16BdF0418774CB3D7599B4, 3000); // WETH / SNX 0.3%
        } else if(poolId == (6 << 252)){
            return Pool(0x4200000000000000000000000000000000000006, 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1, 3000); // WETH / DAI 0.3%
        }

        return pools[poolId];
    }

    // Because of function uniswapV3SwapCallback() 2.3e-8% of calls will fail because they'll hit that selector
    fallback() external payable {
        if(msg.sender == owner){
            (uint method) = abi.decode(msg.data, (uint));
            if(method == 0){
                // Sweep tokens or ETH that got stuck here
                (,address token, uint amount, address receiver) = abi.decode(msg.data, (uint, address, uint, address));
                if(token == address(0)){
                    payable(receiver).transfer(address(this).balance);
                } else {
                    IERC20(token).transfer(receiver, amount); // We don't care if it fails
                }
            } else{
                (,uint poolId, address poolAddress) = abi.decode(msg.data, (uint, uint, address));
                setPool(poolId, poolAddress);
            }
            return;
        }

        uint data;
        assembly {
            data := calldataload(0)
        }
        uint pair = data & (0xf << (256-4));
        uint token0IsTokenIn = data & (0x1 << (256-4-1));
        Pool memory pool = getPool(pair);
        address tokenIn = token0IsTokenIn == 0?pool.token1:pool.token0;

        uint expectedSignificantBits = (data & (0x1ffff << (256-5-17))) >> (256-5-17);
        uint outZeros = (data & (0xff << (256-5-17-8))) >> (256-5-17-8);
        uint expectedTotalOut = expectedSignificantBits << outZeros;

        uint totalIn;
        if(tokenIn == WETH9 && msg.value > 0){
            totalIn = msg.value;
        } else {
            uint inputDataExists = data & (type(uint256).max >> 5+17+8+2);
            if(inputDataExists == 0){
                totalIn = IERC20(tokenIn).balanceOf(msg.sender);
                expectedTotalOut = (expectedTotalOut*totalIn)/1e18; // use it as a rate instead
            } else {
                uint inZeros = (data & (0x1f << (256-5-17-8-2-5))) >> (256-5-17-8-2-5);
                uint calldataLength;
                assembly {
                    calldataLength := calldatasize()
                }
                // (type(uint256).max >> 5+17+8+2+5) = 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffff, this is done to get around stack too deep
                uint significantInputBits = (data & 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffff) >> (256-(calldataLength*8));
                totalIn = significantInputBits * (10**inZeros);
            }
        }

        uint slippageBps;
        {
            uint slippageId = data & (0x3 << (256-5-17-8-2));
            if(slippageId == 0){
                slippageBps = MAX_BPS - 50; //0.5
            } else if(slippageId == (0x1 << (256-5-17-8-2))){
                slippageBps = MAX_BPS - 10; //0.1
            }  else if(slippageId == (0x2 << (256-5-17-8-2))){
                slippageBps = MAX_BPS - 100; //1
            }  else if(slippageId == (0x3 << (256-5-17-8-2))){
                slippageBps = MAX_BPS - 500; //5
            }
        }

        uint minTotalOut = (expectedTotalOut * slippageBps)/MAX_BPS;

        address tokenOut = token0IsTokenIn == 0?pool.token0:pool.token1;
        swap(tokenIn, tokenOut, pool.fee, totalIn, expectedTotalOut, minTotalOut);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "./libs/CallbackValidation.sol";
import "./libs/PeripheryPayments.sol";
import "./libs/PeripheryImmutableState.sol";
import "./libs/SafeCast.sol";

interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

contract SwapRouter is PeripheryImmutableState, PeripheryPayments {
    using SafeCast for uint256;

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    constructor(address _factory, address _WETH9) PeripheryImmutableState(_factory, _WETH9) {}

    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) private view returns (IUniswapV3Pool) {
        return IUniswapV3Pool(PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(tokenA, tokenB, fee)));
    }

    struct SwapCallbackData {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address payer;
    }

    function swap(address tokenIn, address tokenOut, uint24 fee, uint amountIn, uint expectedAmountOut, uint minAmountOut) internal {
        bool zeroForOne = tokenIn < tokenOut;

        bytes memory data = abi.encode(SwapCallbackData({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            payer: msg.sender
        }));

        (int256 amount0, int256 amount1) =
            getPool(tokenIn, tokenOut, fee).swap(
                address(this),
                zeroForOne,
                amountIn.toInt256(),
                (zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1),
                data
            );

        uint amountOut = uint256(-(zeroForOne ? amount1 : amount0));
        if(amountOut > expectedAmountOut){
            amountOut = expectedAmountOut;
        }

        require(amountOut >= minAmountOut, 'Too little received');

        if(tokenOut == WETH9){
            // Doesn't support WETH output since we can't differentiate
            IWETH9(WETH9).withdraw(amountOut);
            TransferHelper.safeTransferETH(msg.sender, amountOut);
        } else {
            TransferHelper.safeTransfer(tokenOut, msg.sender, amountOut);
        }
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external {
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        CallbackValidation.verifyCallback(factory, data.tokenIn, data.tokenOut, data.fee);

        pay(data.tokenIn, data.payer, msg.sender, amount0Delta > 0? uint256(amount0Delta) : uint256(amount1Delta));
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import './PoolAddress.sol';

/// @notice Provides validation for callbacks from Uniswap V3 Pools
library CallbackValidation {
    /// @notice Returns the address of a valid Uniswap V3 Pool
    /// @param factory The contract address of the Uniswap V3 factory
    /// @param tokenA The contract address of either token0 or token1
    /// @param tokenB The contract address of the other token
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @return pool The V3 pool contract address
    function verifyCallback(
        address factory,
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal view returns (address pool) {
        return verifyCallback(factory, PoolAddress.getPoolKey(tokenA, tokenB, fee));
    }

    /// @notice Returns the address of a valid Uniswap V3 Pool
    /// @param factory The contract address of the Uniswap V3 factory
    /// @param poolKey The identifying key of the V3 pool
    /// @return pool The V3 pool contract address
    function verifyCallback(address factory, PoolAddress.PoolKey memory poolKey)
        internal
        view
        returns (address pool)
    {
        pool = PoolAddress.computeAddress(factory, poolKey);
        require(msg.sender == address(pool));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface IERC20{
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

/// @title Immutable state
/// @notice Immutable state used by periphery contracts
abstract contract PeripheryImmutableState {
    address internal immutable factory;
    address internal immutable WETH9;

    constructor(address _factory, address _WETH9) {
        factory = _factory;
        WETH9 = _WETH9;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

import './IERC20.sol';

import './TransferHelper.sol';

import './PeripheryImmutableState.sol';

interface IWETH9 is IERC20 {
    /// @notice Deposit ether to get wrapped ether
    function deposit() external payable;

    /// @notice Withdraw wrapped ether to get ether
    function withdraw(uint256) external;
}

abstract contract PeripheryPayments is PeripheryImmutableState {
    receive() external payable {
        require(msg.sender == WETH9, 'Not WETH9');
    }

/*
Removed external functions to avoid collisions

    /// @inheritdoc IPeripheryPayments
    function unwrapWETH9(uint256 amountMinimum, address recipient) public payable override {
        uint256 balanceWETH9 = IWETH9(WETH9).balanceOf(address(this));
        require(balanceWETH9 >= amountMinimum, 'Insufficient WETH9');

        if (balanceWETH9 > 0) {
            IWETH9(WETH9).withdraw(balanceWETH9);
            TransferHelper.safeTransferETH(recipient, balanceWETH9);
        }
    }

    /// @inheritdoc IPeripheryPayments
    function sweepToken(
        address token,
        uint256 amountMinimum,
        address recipient
    ) public payable override {
        uint256 balanceToken = IERC20(token).balanceOf(address(this));
        require(balanceToken >= amountMinimum, 'Insufficient token');

        if (balanceToken > 0) {
            TransferHelper.safeTransfer(token, recipient, balanceToken);
        }
    }

    /// @inheritdoc IPeripheryPayments
    function refundETH() external payable override {
        if (address(this).balance > 0) TransferHelper.safeTransferETH(msg.sender, address(this).balance);
    }
*/

    /// @param token The token to pay
    /// @param payer The entity that must pay
    /// @param recipient The entity that will receive payment
    /// @param value The amount to pay
    function pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        if (token == WETH9 && address(this).balance >= value) {
            // pay with WETH9
            IWETH9(WETH9).deposit{value: value}(); // wrap only what is needed to pay
            IWETH9(WETH9).transfer(recipient, value);
        } else if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            TransferHelper.safeTransfer(token, recipient, value);
        } else {
            // pull payment
            TransferHelper.safeTransferFrom(token, payer, recipient, value);
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Provides functions for deriving a pool address from the factory, tokens, and the fee
library PoolAddress {
    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    /// @notice The identifying key of the pool
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @notice Returns PoolKey: the ordered tokens with the matched fee levels
    /// @param tokenA The first token of a pool, unsorted
    /// @param tokenB The second token of a pool, unsorted
    /// @param fee The fee level of the pool
    /// @return Poolkey The pool details with ordered token0 and token1 assignments
    function getPoolKey(
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal pure returns (PoolKey memory) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolKey({token0: tokenA, token1: tokenB, fee: fee});
    }

    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param factory The Uniswap V3 factory contract address
    /// @param key The PoolKey
    /// @return pool The contract address of the V3 pool
    function computeAddress(address factory, PoolKey memory key) internal pure returns (address pool) {
        require(key.token0 < key.token1);
        pool = address(
            uint256(
                keccak256(
                    abi.encodePacked(
                        hex'ff',
                        factory,
                        keccak256(abi.encode(key.token0, key.token1, key.fee)),
                        POOL_INIT_CODE_HASH
                    )
                )
            )
        );
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Safe casting methods
/// @notice Contains methods for safely casting between types
library SafeCast {
    /// @notice Cast a uint256 to a uint160, revert on overflow
    /// @param y The uint256 to be downcasted
    /// @return z The downcasted integer, now type uint160
    function toUint160(uint256 y) internal pure returns (uint160 z) {
        require((z = uint160(y)) == y);
    }

    /// @notice Cast a int256 to a int128, revert on overflow or underflow
    /// @param y The int256 to be downcasted
    /// @return z The downcasted integer, now type int128
    function toInt128(int256 y) internal pure returns (int128 z) {
        require((z = int128(y)) == y);
    }

    /// @notice Cast a uint256 to a int256, revert on overflow
    /// @param y The uint256 to be casted
    /// @return z The casted integer, now type int256
    function toInt256(uint256 y) internal pure returns (int256 z) {
        require(y < 2**255);
        z = int256(y);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.0;

import './IERC20.sol';

library TransferHelper {
    /// @notice Transfers tokens from the targeted address to the given destination
    /// @notice Errors with 'STF' if transfer fails
    /// @param token The contract address of the token to be transferred
    /// @param from The originating address from which the tokens will be transferred
    /// @param to The destination address of the transfer
    /// @param value The amount to be transferred
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF');
    }

    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Errors with ST if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'ST');
    }

    /// @notice Approves the stipulated contract to spend the given allowance in the given token
    /// @dev Errors with 'SA' if transfer fails
    /// @param token The contract address of the token to be approved
    /// @param to The target of the approval
    /// @param value The amount of the given token the target will be allowed to spend
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'SA');
    }

    /// @notice Transfers ETH to the recipient address
    /// @dev Fails with `STE`
    /// @param to The destination of the transfer
    /// @param value The value to be transferred
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'STE');
    }
}