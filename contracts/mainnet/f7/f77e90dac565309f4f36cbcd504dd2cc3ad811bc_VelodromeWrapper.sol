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
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

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
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
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

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IVeloPair.sol";
import "./interfaces/IVeloSugar.sol";
import "./interfaces/IVeloRouter.sol";
import "./interfaces/IWETH.sol";

// import "forge-std/console2.sol";

contract VelodromeWrapper {
    // Use SafeMath library for safe arithmetic operations
    using SafeMath for uint256;

    address public immutable admin;
    uint256 public fee;
    address constant routerAddress = 0x9c12939390052919aF3155f41Bf4160Fd3666A6f;
    address constant wethAddress = 0x4200000000000000000000000000000000000006;
    address constant sugarAddress = 0x75c31cC1a815802336aa3bd3F7cACA896Afc7630;

    uint256 constant minBalanceRequired = 0.003 ether;

    IVeloRouter internal immutable router;
    IVeloSugar internal immutable sugar;
    IWETH public immutable weth = IWETH(wethAddress);

    event FeeUpdated(uint256 value);

    modifier onlyOwner() {
        require(msg.sender == admin, "Only admin can update fee");
        _;
    }

    constructor(address _admin, uint256 _fee) {
        require(_admin != address(0), "Admin address cannot be 0");
        admin = _admin;
        fee = _fee;
        router = IVeloRouter(routerAddress);
        sugar = IVeloSugar(sugarAddress);
    }

    // address user, address token,
    function swapAndDeposit(
        address pairAddress,
        IVeloRouter.route[] calldata routes0,
        IVeloRouter.route[] calldata routes1
    ) public payable returns (uint256) {
        // console2.log("start:swapAndDeposit", pairAddress);
        uint256 etherAmount = msg.value;
        uint256 maxAmount = 2**256 - 1;

        // Check if there is enough ETH to cover the gas fees
        if (msg.sender.balance < (minBalanceRequired)) {
            // If there is not enough ETH, deduct the gas fees from the value
            etherAmount = etherAmount.sub(minBalanceRequired);
            require(
                etherAmount > 0,
                "There are not enough tokens for gas fees, please try to send with a higher amount again"
            );
        }

        // Get the pair details
        IVeloSugar.Pair memory pair = sugar.byAddress(pairAddress, msg.sender);

        // swap 50% ETH to token0
        uint256[] memory swap0;
        // if token0 is WETH, then no need to swap
        if (pair.token0 != wethAddress) {
            uint256[] memory expectedOutput0 = router.getAmountsOut(
                etherAmount.div(2),
                routes0
            );
            // console2.log("swapExactETHForTokens0", etherAmount.div(2), expectedOutput0[expectedOutput0.length - 1]);
            swap0 = router.swapExactETHForTokens{value: etherAmount.div(2)}(
                expectedOutput0[expectedOutput0.length - 1],
                routes0,
                address(this),
                block.timestamp
            );
        } else {
            // console2.log("transferFrom0", msg.sender, address(this), etherAmount.div(2));
            weth.deposit{value: etherAmount.div(2)}();
            require(
                weth.transfer(address(this), etherAmount.div(2)),
                "WETH transfer failed"
            );
            swap0 = new uint256[](1);
            swap0[0] = etherAmount.div(2);
        }

        // swap 50% ETH to token1
        uint256[] memory swap1;
        // if token1 is WETH, then no need to swap
        if (pair.token1 != wethAddress) {
            uint256[] memory expectedOutput1 = router.getAmountsOut(
                etherAmount.div(2),
                routes1
            );
            // console2.log("swapExactETHForTokens1", etherAmount.div(2), expectedOutput1[expectedOutput1.length - 1]);
            swap1 = router.swapExactETHForTokens{value: etherAmount.div(2)}(
                expectedOutput1[expectedOutput1.length - 1],
                routes1,
                address(this),
                block.timestamp
            );
        } else {
            // console2.log("transferFrom1", msg.sender, address(this), etherAmount.div(2));
            weth.deposit{value: etherAmount.div(2)}();
            require(
                weth.transfer(address(this), etherAmount.div(2)),
                "WETH transfer failed"
            );
            swap1 = new uint256[](1);
            swap1[0] = etherAmount.div(2);
        }

        // get the token amounts
        uint256 token0Amount = swap0[swap0.length - 1];
        uint256 token1Amount = swap1[swap1.length - 1];
        require(
            IERC20(pair.token0).balanceOf(address(this)) >= token0Amount,
            "sender has not enough token0 balance"
        );
        require(
            IERC20(pair.token1).balanceOf(address(this)) >= token1Amount,
            "sender has not enough token1 balance"
        );

        // 1. Allow the router to spend the pairs
        // Check if user has enough allowance for the needed tokens
        // if (IERC20(pair.token0).allowance(address(this), routerAddress) < token0Amount) {
        // console2.log("approve0", pair.token0, routerAddress, maxAmount);
        require(
            IERC20(pair.token0).approve(routerAddress, maxAmount),
            "Token0 approval failed"
        );
        // }
        // if (IERC20(pair.token1).allowance(address(this), routerAddress) < token1Amount) {
        // console2.log("approve1", pair.token1, routerAddress, maxAmount);
        require(
            IERC20(pair.token1).approve(routerAddress, maxAmount),
            "Token1 approval failed"
        );
        // }

        // 2. add to liquidity the pairs using the router
        // console2.log("quoteAddLiquidity", token0Amount, token1Amount);
        (uint256 estimateAmount0, uint256 estimateAmount1, ) = router
            .quoteAddLiquidity(
                pair.token0,
                pair.token1,
                pair.stable,
                token0Amount,
                token1Amount
            );
        // console2.log("addLiquidity", estimateAmount0, estimateAmount1);
        (, , uint256 liquidity) = router.addLiquidity(
            pair.token0,
            pair.token1,
            pair.stable,
            estimateAmount0,
            estimateAmount1,
            estimateAmount0.mul(98).div(100),
            estimateAmount1.mul(98).div(100),
            // msg.sender,
            address(this),
            block.timestamp
        );
        require(liquidity > 0, "Liquidity addition failed");

        // 3. move the LP tokens to the user
        uint256 LpBalance = IERC20(pair.pair_address).balanceOf(address(this));
        // console2.log("transferFrom", address(this), msg.sender, LpBalance);
        bool success = IVeloPair(pair.pair_address).transferFrom(
            address(this),
            msg.sender,
            LpBalance
        );
        require(success, "LP transfer failed");
        // console2.log("end:swapAndDeposit", LpBalance);
        return LpBalance;
    }

    function withdrawAndSwap(
        address pairAddress,
        uint256 rewards,
        IVeloRouter.route[] calldata routes0,
        IVeloRouter.route[] calldata routes1
    ) public payable {
        // console2.log("start:withdrawAndSwap");
        uint256 amount = msg.value;
        uint256 maxAmount = 2**256 - 1;
        address veloAddress = 0x3c8B650257cFb5f272f799F5e2b4e65093a11a05;

        // Get the pair details
        IVeloSugar.Pair memory pair = sugar.byAddress(pairAddress, msg.sender);

        // Check if the velodrome wrapper contract has allownce to spend LP tokens
        // require(IERC20(pair.pair_address).allowance(msg.sender, address(this)) == maxAmount, "LP allownce is required");
        // Check if the velodrome wrapper contract has allownce to spend VELO tokens
        // require(IERC20(veloAddress).allowance(msg.sender, address(this)) == maxAmount, "VELO allowance is required");
        // require(IVeloPair(pair.pair_address).balanceOf(msg.sender) > 100, "No LP found");

        // 1. transfer outlet fee if rewards are greater than 0
        if (rewards > 0) {
            // console2.log("rewards");
            bool success = IERC20(veloAddress).transferFrom(
                msg.sender,
                0x793A36E1fE945123ae676Bbb42F6C4f31288a4e6,
                rewards.mul(fee).div(100)
            );
            require(success, "VELO transfer failed");
        }

        // 2.transfer the LP tokens to the contract
        // console2.log("ransfer the LP tokens to the contract", msg.sender, address(this), amount);
        bool soccess2 = IVeloPair(pair.pair_address).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(soccess2, "LP transfer failed");

        // 3. Allow the router to spend the LP tokens
        // if (IERC20(pair.pair_address).allowance(address(this), routerAddress) < maxAmount) {
        require(
            IERC20(pair.pair_address).approve(routerAddress, maxAmount),
            "routerAddress approval failed"
        );
        // }

        // 4. remove liquidity from the pairs using the router
        // console2.log("quoteRemoveLiquidity", amount);
        (uint256 estimateAmount0, uint256 estimateAmount1) = router
            .quoteRemoveLiquidity(
                pair.token0,
                pair.token1,
                pair.stable,
                amount
            );
        // console2.log("removeLiquidity", estimateAmount0, estimateAmount1);
        (uint256 amount0, uint256 amount1) = router.removeLiquidity(
            pair.token0,
            pair.token1,
            pair.stable,
            amount,
            estimateAmount0.mul(98).div(100),
            estimateAmount1.mul(98).div(100),
            address(this),
            block.timestamp
        );

        // 5. Allow the router to spend the pairs
        // if (IERC20(pair.token0).allowance(address(this), routerAddress) < maxAmount) {
        require(
            IERC20(pair.token0).approve(routerAddress, maxAmount),
            "Token0 approval failed"
        );
        // }
        // if (IERC20(pair.token1).allowance(address(this), routerAddress) < maxAmount) {
        require(
            IERC20(pair.token1).approve(routerAddress, maxAmount),
            "Token1 approval failed"
        );
        // }

        // 6. swap the tokens for ETH and send it to the user
        // if token0 is WETH, then no need to swap
        if (pair.token0 != wethAddress) {
            uint256[] memory expectedOutput0 = router.getAmountsOut(
                amount0,
                routes0
            );
            // console2.log("swapExactTokensForETH0", amount0, expectedOutput0[expectedOutput0.length - 1]);
            router.swapExactTokensForETH(
                amount0,
                expectedOutput0[expectedOutput0.length - 1],
                routes0,
                msg.sender,
                block.timestamp
            );
        } else {
            // if token0 is WETH, then send it to the user
            // console2.log("withdraw0", amount0);
            bool success = IERC20(wethAddress).transfer(msg.sender, amount0);
            require(success, "WETH transfer failed");
        }

        // if token1 is WETH, then no need to swap
        if (pair.token1 != wethAddress) {
            uint256[] memory expectedOutput1 = router.getAmountsOut(
                amount1,
                routes1
            );
            // console2.log("swapExactTokensForETH1", amount1, expectedOutput1[expectedOutput1.length - 1]);
            router.swapExactTokensForETH(
                amount1,
                expectedOutput1[expectedOutput1.length - 1],
                routes1,
                msg.sender,
                block.timestamp
            );
        } else {
            // if token1 is WETH, then send it to the user
            // console2.log("withdraw1", amount1);
            bool success = IERC20(wethAddress).transfer(msg.sender, amount1);
            require(success, "WETH transfer failed");
        }
        // console2.log("end:withdrawAndSwap");
    }

    function updateFee(uint256 newFee) public onlyOwner {
        fee = newFee;
        emit FeeUpdated(newFee);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IVeloPair {
    // event Approval(address indexed owner, address indexed spender, uint256 amount);
    // event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    // event Claim(address indexed sender, address indexed recipient, uint256 amount0, uint256 amount1);
    // event Fees(address indexed sender, uint256 amount0, uint256 amount1);
    // event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    // event Swap(
    //     address indexed sender,
    //     uint256 amount0In,
    //     uint256 amount1In,
    //     uint256 amount0Out,
    //     uint256 amount1Out,
    //     address indexed to
    // );
    // event Sync(uint256 reserve0, uint256 reserve1);
    // event Transfer(address indexed from, address indexed to, uint256 amount);
    // struct Observation {
    //     uint256 timestamp;
    //     uint256 reserve0Cumulative;
    //     uint256 reserve1Cumulative;
    // }
    // function allowance(address, address) external view returns (uint256);
    // function approve(address spender, uint256 amount) external returns (bool);
    // function balanceOf(address) external view returns (uint256);
    // function blockTimestampLast() external view returns (uint256);
    // function burn(address to) external returns (uint256 amount0, uint256 amount1);
    // function claimFees() external returns (uint256 claimed0, uint256 claimed1);
    // function claimable0(address) external view returns (uint256);
    // function claimable1(address) external view returns (uint256);
    // function current(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut);
    // function currentCumulativePrices()
    //     external
    //     view
    //     returns (
    //         uint256 reserve0Cumulative,
    //         uint256 reserve1Cumulative,
    //         uint256 blockTimestamp
    //     );
    // function decimals() external view returns (uint8);
    // function fees() external view returns (address);
    // function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
    // function getReserves()
    //     external
    //     view
    //     returns (
    //         uint256 _reserve0,
    //         uint256 _reserve1,
    //         uint256 _blockTimestampLast
    //     );
    // function index0() external view returns (uint256);
    // function index1() external view returns (uint256);
    // function lastObservation() external view returns (Observation memory);
    // function metadata()
    //     external
    //     view
    //     returns (
    //         uint256 dec0,
    //         uint256 dec1,
    //         uint256 r0,
    //         uint256 r1,
    //         bool st,
    //         address t0,
    //         address t1
    //     );
    // function mint(address to) external returns (uint256 liquidity);
    // function name() external view returns (string memory);
    // function nonces(address) external view returns (uint256);
    // function observationLength() external view returns (uint256);
    // function observations(uint256)
    //     external
    //     view
    //     returns (
    //         uint256 timestamp,
    //         uint256 reserve0Cumulative,
    //         uint256 reserve1Cumulative
    //     );
    // function permit(
    //     address owner,
    //     address spender,
    //     uint256 value,
    //     uint256 deadline,
    //     uint8 v,
    //     bytes32 r,
    //     bytes32 s
    // ) external;
    // function prices(
    //     address tokenIn,
    //     uint256 amountIn,
    //     uint256 points
    // ) external view returns (uint256[] memory);
    // function quote(
    //     address tokenIn,
    //     uint256 amountIn,
    //     uint256 granularity
    // ) external view returns (uint256 amountOut);
    // function reserve0() external view returns (uint256);
    // function reserve0CumulativeLast() external view returns (uint256);
    // function reserve1() external view returns (uint256);
    // function reserve1CumulativeLast() external view returns (uint256);
    // function sample(
    //     address tokenIn,
    //     uint256 amountIn,
    //     uint256 points,
    //     uint256 window
    // ) external view returns (uint256[] memory);
    // function skim(address to) external;
    // function stable() external view returns (bool);
    // function supplyIndex0(address) external view returns (uint256);
    // function supplyIndex1(address) external view returns (uint256);
    // function swap(
    //     uint256 amount0Out,
    //     uint256 amount1Out,
    //     address to,
    //     bytes memory data
    // ) external;
    // function symbol() external view returns (string memory);
    // function sync() external;
    // function token0() external view returns (address);
    // function token1() external view returns (address);
    // function tokens() external view returns (address, address);
    // function totalSupply() external view returns (uint256);
    // function transfer(address dst, uint256 amount) external returns (bool);
    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IVeloRouter {
    struct route {
        address from;
        address to;
        bool stable;
    }

    // function UNSAFE_swapExactTokensForTokens(
    //     uint256[] memory amounts,
    //     route[] memory routes,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256[] memory);
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
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    // function addLiquidityETH(
    //     address token,
    //     bool stable,
    //     uint256 amountTokenDesired,
    //     uint256 amountTokenMin,
    //     uint256 amountETHMin,
    //     address to,
    //     uint256 deadline
    // )
    //     external
    //     payable
    //     returns (
    //         uint256 amountToken,
    //         uint256 amountETH,
    //         uint256 liquidity
    //     );
    // function factory() external view returns (address);
    // function getAmountOut(
    //     uint256 amountIn,
    //     address tokenIn,
    //     address tokenOut
    // ) external view returns (uint256 amount, bool stable);
    function getAmountsOut(uint256 amountIn, route[] memory routes)
        external
        view
        returns (uint256[] memory amounts);

    // function getReserves(
    //     address tokenA,
    //     address tokenB,
    //     bool stable
    // ) external view returns (uint256 reserveA, uint256 reserveB);
    // function isPair(address pair) external view returns (bool);
    // function pairFor(
    //     address tokenA,
    //     address tokenB,
    //     bool stable
    // ) external view returns (address pair);
    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired
    )
        external
        view
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity
    ) external view returns (uint256 amountA, uint256 amountB);

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

    // function removeLiquidityETH(
    //     address token,
    //     bool stable,
    //     uint256 liquidity,
    //     uint256 amountTokenMin,
    //     uint256 amountETHMin,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256 amountToken, uint256 amountETH);
    // function removeLiquidityETHWithPermit(
    //     address token,
    //     bool stable,
    //     uint256 liquidity,
    //     uint256 amountTokenMin,
    //     uint256 amountETHMin,
    //     address to,
    //     uint256 deadline,
    //     bool approveMax,
    //     uint8 v,
    //     bytes32 r,
    //     bytes32 s
    // ) external returns (uint256 amountToken, uint256 amountETH);
    // function removeLiquidityWithPermit(
    //     address tokenA,
    //     address tokenB,
    //     bool stable,
    //     uint256 liquidity,
    //     uint256 amountAMin,
    //     uint256 amountBMin,
    //     address to,
    //     uint256 deadline,
    //     bool approveMax,
    //     uint8 v,
    //     bytes32 r,
    //     bytes32 s
    // ) external returns (uint256 amountA, uint256 amountB);
    // function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);
    function swapExactETHForTokens(
        uint256 amountOutMin,
        route[] memory routes,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        route[] memory routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    // function swapExactTokensForTokens(
    //     uint256 amountIn,
    //     uint256 amountOutMin,
    //     route[] memory routes,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256[] memory amounts);
    // function swapExactTokensForTokensSimple(
    //     uint256 amountIn,
    //     uint256 amountOutMin,
    //     address tokenFrom,
    //     address tokenTo,
    //     bool stable,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256[] memory amounts);
    // function weth() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IVeloSugar {
    struct Pair {
        address pair_address;
        string symbol;
        uint8 decimals;
        bool stable;
        uint256 total_supply;
        address token0;
        string token0_symbol;
        uint8 token0_decimals;
        uint256 reserve0;
        uint256 claimable0;
        address token1;
        string token1_symbol;
        uint8 token1_decimals;
        uint256 reserve1;
        uint256 claimable1;
        address gauge;
        uint256 gauge_total_supply;
        address fee;
        address bribe;
        address wrapped_bribe;
        uint256 emissions;
        address emissions_token;
        uint8 emissions_token_decimals;
        uint256 account_balance;
        uint256 account_earned;
        uint256 account_staked;
        uint256 account_token0_balance;
        uint256 account_token1_balance;
    }

    // function all(
    //     uint256 _limit,
    //     uint256 _offset,
    //     address _account
    // ) external view returns (Pair memory);
    function byAddress(address _address, address _account)
        external
        view
        returns (Pair memory);
    // function byIndex(uint256 _index, address _account) external view returns (Pair memory);
    // function owner() external view returns (address);
    // function pair_factory() external view returns (address);
    // function setup(address _voter, address _wrapped_bribe_factory) external;
    // function token() external view returns (address);
    // function voter() external view returns (address);
    // function wrapped_bribe_factory() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);
}