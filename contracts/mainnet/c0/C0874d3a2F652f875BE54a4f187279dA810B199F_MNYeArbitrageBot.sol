// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/ISetToken.sol";
import "./interfaces/IExchangeIssuancePerp.sol";
import "./interfaces/uniswap/IUniV3SwapRouter.sol";
import "./interfaces/uniswap/IUniV3Quoter.sol";
import "./interfaces/aave/IAaveV3Pool.sol";

contract MNYeArbitrageBot is Ownable {
    // Uniswap V3 constants
    IUniV3SwapRouter private constant uniV3SwapRouter = IUniV3SwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniV3Quoter private constant uniV3Quoter = IUniV3Quoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    uint24 private constant fee = 500;

    // Aave v3 constants
    IAaveV3Pool private constant aaveV3Pool = IAaveV3Pool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    // MNYe constants
    IExchangeIssuancePerp private constant exchangeIssuancePerp =
        IExchangeIssuancePerp(0x2b44C227d95B8FDa1c8750986d3aDfF0E67627F7);
    IERC20 private constant usdc = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20 private constant mnye = IERC20(0x0Be27c140f9Bdad3474bEaFf0A413EC7e19e9B93);

    constructor() Ownable() {
        usdc.approve(address(uniV3SwapRouter), type(uint256).max);
        mnye.approve(address(uniV3SwapRouter), type(uint256).max);
        usdc.approve(address(exchangeIssuancePerp), type(uint256).max);
        mnye.approve(address(exchangeIssuancePerp), type(uint256).max);
    }

    /**
     * @dev Prepare USDC from Aave flashloan, Buy MNYe from UniswapV3, Redeem MNYe as USDC, take profit
     * @param mnyeAmount The USDC amount to prepare from Aave flashloan
     */
    function buyMNYeAndRedeem(uint256 mnyeAmount) external returns (uint256 profit) {
        // track USDC balance for profit calculation
        uint256 balanceBefore = usdc.balanceOf(address(this));

        uint256 usdcAmount = uniV3Quoter.quoteExactOutputSingle(address(usdc), address(mnye), fee, mnyeAmount, 0) +
            1000000; // plus 1 USDC
        bytes memory flashloanParams = abi.encode(mnyeAmount, true); // false
        aaveV3Pool.flashLoanSimple(address(this), address(usdc), usdcAmount, flashloanParams, 0);

        profit = usdc.balanceOf(address(this)) - balanceBefore;
    }

    /**
     * @dev Prepare USDC from Aave flashloan, Issue MNYe using USDC, Sell MNYe from UniswapV3, take profit
     * @param mnyeAmount The MNYe amount units
     */
    function issueMNYeAndSell(uint256 mnyeAmount) external returns (uint256 profit) {
        // track USDC balance for profit calculation
        uint256 balanceBefore = usdc.balanceOf(address(this));

        uint256 usdcAmount = exchangeIssuancePerp.getUsdcAmountInForFixedSetOffChain(address(mnye), mnyeAmount) +
            1000000; // plus 1 USDC
        bytes memory flashloanParams = abi.encode(mnyeAmount, false); // false
        aaveV3Pool.flashLoanSimple(address(this), address(usdc), usdcAmount, flashloanParams, 0);

        profit = usdc.balanceOf(address(this)) - balanceBefore;
    }

    function withdrawProfit() external onlyOwner {
        usdc.transfer(msg.sender, usdc.balanceOf(address(this)));
    }

    /**
     * @notice Executes an operation after receiving the flash-borrowed asset
     * @dev Ensure that the contract can return the debt + premium, e.g., has
     *      enough funds to repay and has approved the Pool to pull the total amount
     * @param asset The address of the flash-borrowed asset
     * @param amount The amount of the flash-borrowed asset
     * @param premium The fee of the flash-borrowed asset
     * @param initiator The address of the flashloan initiator
     * @param params The byte-encoded params passed when initiating the flashloan
     * @return True if the execution of the operation succeeds, false otherwise
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        require(msg.sender == address(aaveV3Pool) && initiator == address(this), "invalid flashloan from");
        require(asset == address(usdc), "invalid asset flashloan");

        (uint256 mnyeAmount, bool isBuyMNYeAndRedeem) = abi.decode(params, (uint256, bool));

        if (isBuyMNYeAndRedeem) {
            // Buy MNYe from UniswapV3
            uniV3SwapRouter.exactOutputSingle(
                IUniV3SwapRouter.ExactOutputSingleParams({
                    tokenIn: address(usdc),
                    tokenOut: address(mnye),
                    fee: fee,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountOut: mnyeAmount,
                    amountInMaximum: amount,
                    sqrtPriceLimitX96: 0
                })
            );

            // Redeem MNYe as USDC
            exchangeIssuancePerp.redeemFixedSetForUsdc(address(mnye), mnye.balanceOf(address(this)), 1);
        } else {
            // Issue MNYe using USDC
            exchangeIssuancePerp.issueFixedSetFromUsdc(address(mnye), mnyeAmount, amount);

            // Sell MNYe from UniswapV3
            uniV3SwapRouter.exactInputSingle(
                IUniV3SwapRouter.ExactInputSingleParams({
                    tokenIn: address(mnye),
                    tokenOut: address(usdc),
                    fee: fee,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: mnye.balanceOf(address(this)),
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );
        }

        // payback amounts + premiums
        usdc.approve(address(aaveV3Pool), amount + premium);

        return true;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ISetToken {
    function getComponents() external view returns (address[] memory);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IExchangeIssuancePerp {
    function getUsdcAmountInForFixedSetOffChain(address _setToken, uint256 _amountOut)
        external
        returns (uint256 totalUsdcAmountIn);

    function getUsdcAmountOutForFixedSetOffChain(address _setToken, uint256 _amountIn)
        external
        returns (uint256 totalUsdcAmountOut);

    function issueFixedSetFromUsdc(
        address _setToken,
        uint256 _amount,
        uint256 _maxUsdcAmountIn
    ) external;

    function redeemFixedSetForUsdc(
        address _setToken,
        uint256 _amount,
        uint256 _minUsdcAmountOut
    ) external;
}

// SPDX-License-Identifer: UNLICENSED
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

interface IUniV3SwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}

// SPDX-License-Identifer: UNLICENSED
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

interface IUniV3Quoter {
    function quoteExactInput(bytes memory path, uint256 amountIn) external returns (uint256 amountOut);

    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);

    function quoteExactOutput(bytes memory path, uint256 amountOut) external returns (uint256 amountIn);

    function quoteExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountIn);
}

// SPDX-License-Identifer: UNLICENSED
pragma solidity ^0.8.9;

interface IAaveV3Pool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
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