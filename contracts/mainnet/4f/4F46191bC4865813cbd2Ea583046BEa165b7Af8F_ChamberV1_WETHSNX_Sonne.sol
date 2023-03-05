// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AutomationCompatibleInterface {
  /**
   * @notice method that is simulated by the keepers to see if any work actually
   * needs to be performed. This method does does not actually need to be
   * executable, and since it is only ever simulated it can consume lots of gas.
   * @dev To ensure that it is never called, you may want to add the
   * cannotExecute modifier from KeeperBase to your implementation of this
   * method.
   * @param checkData specified in the upkeep registration so it is always the
   * same for a registered upkeep. This can easily be broken down into specific
   * arguments using `abi.decode`, so multiple upkeeps can be registered on the
   * same contract and easily differentiated by the contract.
   * @return upkeepNeeded boolean to indicate whether the keeper should call
   * performUpkeep or not.
   * @return performData bytes that the keeper should call performUpkeep with, if
   * upkeep is needed. If you would like to encode data to decode later, try
   * `abi.encode`.
   */
  function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);

  /**
   * @notice method that is actually executed by the keepers, via the registry.
   * The data returned by the checkUpkeep simulation will be passed into
   * this method to actually be executed.
   * @dev The input to this method should not be trusted, and the caller of the
   * method should not even be restricted to any single registry. Anyone should
   * be able call it, and the input should be validated, there is no guarantee
   * that the data passed in is the performData returned from checkUpkeep. This
   * could happen due to malicious keepers, racing keepers, or simply a state
   * change while the performUpkeep transaction is waiting for confirmation.
   * Always validate the data passed in.
   * @param performData is the data which was passed back from the checkData
   * simulation. If it is encoded, it can easily be decoded into other types by
   * calling `abi.decode`. This data should not be trusted, and should be
   * validated against the contract's current state.
   */
  function performUpkeep(bytes calldata performData) external;
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

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Callback for IUniswapV3PoolActions#swap
/// @notice Any contract that calls IUniswapV3PoolActions#swap must implement this interface
interface IUniswapV3SwapCallback {
    /// @notice Called to `msg.sender` after executing a swap via IUniswapV3Pool#swap.
    /// @dev In the implementation you must pay the pool tokens owed for the swap.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// amount0Delta and amount1Delta can both be 0 if no tokens were swapped.
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token0 to the pool.
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token1 to the pool.
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

import "./Uniswap/utils/LiquidityAmounts.sol";
import "./Uniswap/interfaces/ISwapRouter.sol";
import "./Uniswap/interfaces/IUniswapV3Pool.sol";
import "./Uniswap/interfaces/callback/IUniswapV3MintCallback.sol";

import "./SonneInterfaces/ICErc20.sol";
import "./SonneInterfaces/IComptroller.sol";
import "./SonneInterfaces/CTokenInterfaces.sol";
import "./SonneInterfaces/PriceOracle.sol";

import "./Velodrome/IRouter.sol";

import "./TransferHelper.sol";
import "./MathHelper.sol";

import "./IChamberV1.sol";
import "./swapHelpers/ISwapHelper.sol";

//import "hardhat/console.sol";

/*Errors */
error ChamberV1__ReenterancyGuard();
error ChamberV1__AaveDepositError();
error ChamberV1__UserRepaidMoreToken0ThanOwned();
error ChamberV1__UserRepaidMoreToken1ThanOwned();
error ChamberV1__SwappedUsdcForToken0StillCantRepay();
error ChamberV1__SwappedToken0ForToken1StillCantRepay();
error ChamberV1__CallerIsNotUniPool();
error ChamberV1__sharesWorthMoreThanDep();
error ChamberV1__TicksOut();
error ChamberV1__UpkeepNotNeeded(uint256 _currentLTV, uint256 _totalShares);

// For Wmatic/Weth
contract ChamberV1_WETHSNX_Sonne is
    IChamberV1,
    Ownable,
    IUniswapV3MintCallback,
    AutomationCompatibleInterface
{
    // =================================
    // Storage for users and their deposits
    // =================================

    uint256 private s_totalShares;
    mapping(address => uint256) private s_userShares;

    // =================================
    // Storage for pool
    // =================================

    int24 private s_lowerTick;
    int24 private s_upperTick;
    bool private s_liquidityTokenId;

    // =================================
    // Storage for logic
    // =================================

    bool private unlocked;

    uint256 private s_targetLTV;
    uint256 private s_minLTV;
    uint256 private s_maxLTV;
    uint256 private s_hedgeDev;

    uint256 private s_cetraFeeToken0;
    uint256 private s_cetraFeeToken1;

    int24 private s_ticksRange;

    address private immutable s_swapHelper;

    address private constant i_usdcAddress =
        0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address private constant i_token0Address =
        0x4200000000000000000000000000000000000006;
    address private constant i_token1Address =
        0x8700dAec35aF8Ff88c16BdF0418774CB3D7599B4;

    ICErc20 private constant i_soUSDC =
        ICErc20(0xEC8FEa79026FfEd168cCf5C627c7f486D77b765F);
    ICErc20 private constant i_soToken0 =
        ICErc20(0xf7B5965f5C117Eb1B5450187c9DcFccc3C317e8E);
    ICErc20 private constant i_soToken1 =
        ICErc20(0xD7dAabd899D1fAbbC3A9ac162568939CEc0393Cc);

    PriceOracle private constant i_sonneOracle =
        PriceOracle(0xEFc0495DA3E48c5A55F73706b249FD49d711A502);
    IComptroller private constant i_sonneComptroller =
        IComptroller(0x60CF091cD3f50420d50fD7f707414d0DF4751C58);

    // ISwapRouter private constant i_uniswapSwapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV3Pool private constant i_uniswapPool =
        IUniswapV3Pool(0x0392b358CE4547601BEFa962680BedE836606ae2);

    uint256 private constant USDC_RATE = 1e6;
    uint256 private constant TOKEN0_RATE = 1e18;
    uint256 private constant TOKEN1_RATE = 1e18;

    uint256 private constant PRECISION = 1e18;
    uint256 private constant CETRA_FEE = 5 * 1e16;

    address private constant SONNE_ADDRESS =
        0x1DB2466d9F5e10D7090E7152B68d62703a2245F0;
    IRouter private constant VELO_ROUTER =
        IRouter(0x9c12939390052919aF3155f41Bf4160Fd3666A6f);

    // ================================
    // Modifiers
    // =================================

    modifier lock() {
        if (!unlocked) {
            revert ChamberV1__ReenterancyGuard();
        }
        unlocked = false;
        _;
        unlocked = true;
    }

    // =================================
    // Constructor
    // =================================

    constructor(address _swapHelper, int24 _ticksRange) {
        s_swapHelper = _swapHelper;
        unlocked = true;
        s_ticksRange = _ticksRange;

        address[] memory cTokens = new address[](3);
        cTokens[0] = address(i_soToken0);
        cTokens[1] = address(i_soToken1);
        cTokens[2] = address(i_soUSDC);
        i_sonneComptroller.enterMarkets(cTokens);
    }

    // =================================
    // Main funcitons
    // =================================

    function mint(uint256 usdAmount) external override lock {
        {
            _claimAndIncreaseCollateral();
            uint256 currUsdBalance = currentUSDBalance();
            uint256 sharesToMint = (currUsdBalance > 10)
                ? ((usdAmount * s_totalShares) / (currUsdBalance))
                : usdAmount;
            s_totalShares += sharesToMint;
            s_userShares[msg.sender] += sharesToMint;
            if (sharesWorth(sharesToMint) >= usdAmount) {
                revert ChamberV1__sharesWorthMoreThanDep();
            }
            TransferHelper.safeTransferFrom(
                i_usdcAddress,
                msg.sender,
                address(this),
                usdAmount
            );
        }
        _mint(usdAmount);
    }

    function burn(uint256 _shares) external override lock {
        _claimAndIncreaseCollateral();
        uint256 usdcBalanceBefore = TransferHelper.safeGetBalance(
            i_usdcAddress
        );
        _burn(_shares);

        s_totalShares -= _shares;
        s_userShares[msg.sender] -= _shares;

        TransferHelper.safeTransfer(
            i_usdcAddress,
            msg.sender,
            TransferHelper.safeGetBalance(i_usdcAddress) - usdcBalanceBefore
        );
    }

    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        uint256 _currentLTV = currentLTV();
        (
            uint256 token0Pool,
            uint256 token1Pool
        ) = calculateCurrentPoolReserves();
        uint256 token0Borrowed = getVToken0Balance();
        uint256 token1Borrowed = getVToken1Balance();
        bool tooMuchExposureTakenToken0;
        bool tooMuchExposureTakenToken1;
        if (token1Pool == 0 || token0Pool == 0) {
            tooMuchExposureTakenToken0 = true;
            tooMuchExposureTakenToken1 = true;
        } else {
            tooMuchExposureTakenToken0 = (token0Borrowed > token0Pool)
                ? (((token0Borrowed - token0Pool) * PRECISION) / token0Pool >
                    s_hedgeDev)
                : (
                    (((token0Pool - token0Borrowed) * PRECISION) / token0Pool >
                        s_hedgeDev)
                );
            tooMuchExposureTakenToken1 = (token1Borrowed > token1Pool)
                ? (((token1Borrowed - token1Pool) * PRECISION) / token1Pool >
                    s_hedgeDev)
                : (
                    (((token1Pool - token1Borrowed) * PRECISION) / token1Pool >
                        s_hedgeDev)
                );
        }
        upkeepNeeded =
            (_currentLTV >= s_maxLTV ||
                _currentLTV <= s_minLTV ||
                tooMuchExposureTakenToken0 ||
                tooMuchExposureTakenToken1) &&
            (s_totalShares != 0);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert ChamberV1__UpkeepNotNeeded(currentLTV(), s_totalShares);
        }
        rebalance();
    }

    // =================================
    // Main funcitons helpers
    // =================================

    function _mint(uint256 usdAmount) private {
        uint256 amount0;
        uint256 amount1;
        uint256 usedLTV;

        int24 currentTick = getTick();

        if (!s_liquidityTokenId) {
            s_lowerTick = ((currentTick - s_ticksRange) / 60) * 60;
            s_upperTick = ((currentTick + s_ticksRange) / 60) * 60;
            usedLTV = s_targetLTV;
            s_liquidityTokenId = true;
        } else {
            usedLTV = currentLTV();
        }
        if (usedLTV < (10 * PRECISION) / 100) {
            usedLTV = s_targetLTV;
        }
        (amount0, amount1) = calculatePoolReserves(uint128(1e18));
        //uint256 balance = TransferHelper.safeGetBalance(i_usdcAddress);
        if (i_soUSDC.mint(TransferHelper.safeGetBalance(i_usdcAddress)) != 0) {
            revert();
        }
        //i_soUSDC.redeemUnderlying(balance);

        uint256 usdcOraclePrice = getUsdcOraclePrice();
        uint256 token0OraclePrice = getToken0OraclePrice();
        uint256 token1OraclePrice = getToken1OraclePrice();

        if (amount0 == 0 || amount1 == 0) {
            revert ChamberV1__TicksOut();
        }

        uint256 token0ToBorrow = (usdAmount * usdcOraclePrice * usedLTV) /
            (token0OraclePrice /
                1e12 +
                (token1OraclePrice * amount1) /
                amount0 /
                1e12) /
            PRECISION;

        uint256 token1ToBorrow = (usdAmount * usdcOraclePrice * usedLTV) /
            ((token0OraclePrice * amount0) /
                amount1 /
                1e12 +
                token1OraclePrice /
                1e12) /
            PRECISION;

        if (token0ToBorrow > 0) {
            if (i_soToken0.borrow(token0ToBorrow) != 0) {
                revert();
            }
        }
        if (token1ToBorrow > 0) {
            if (i_soToken1.borrow(token1ToBorrow) != 0) {
                revert();
            }
        }

        {
            uint256 token0Recieved = TransferHelper.safeGetBalance(
                i_token0Address
            ) - s_cetraFeeToken0;
            uint256 token1Recieved = TransferHelper.safeGetBalance(
                i_token1Address
            ) - s_cetraFeeToken1;

            uint128 liquidityMinted = LiquidityAmounts.getLiquidityForAmounts(
                getSqrtRatioX96(),
                MathHelper.getSqrtRatioAtTick(s_lowerTick),
                MathHelper.getSqrtRatioAtTick(s_upperTick),
                token0Recieved,
                token1Recieved
            );

            i_uniswapPool.mint(
                address(this),
                s_lowerTick,
                s_upperTick,
                liquidityMinted,
                ""
            );
        }
    }

    function _burn(uint256 _shares) private {
        (
            uint256 burnToken0,
            uint256 burnToken1,
            uint256 feeToken0,
            uint256 feeToken1
        ) = _withdraw(uint128((getLiquidity() * _shares) / s_totalShares));

        _applyFees(feeToken0, feeToken1);

        uint256 amountToken0 = burnToken0 +
            ((TransferHelper.safeGetBalance(i_token0Address) -
                burnToken0 -
                s_cetraFeeToken0) * _shares) /
            s_totalShares;
        uint256 amountToken1 = burnToken1 +
            ((TransferHelper.safeGetBalance(i_token1Address) -
                burnToken1 -
                s_cetraFeeToken1) * _shares) /
            s_totalShares;

        {
            (
                uint256 token0Remainder,
                uint256 token1Remainder
            ) = _repayAndWithdraw(_shares, amountToken0, amountToken1);
            if (token0Remainder > 0) {
                s_swapHelper.delegatecall(
                    abi.encodeWithSignature(
                        "swapExactAssetToStable(address,uint256)",
                        i_token0Address,
                        token0Remainder
                    )
                );
            }
            if (token1Remainder > 0) {
                s_swapHelper.delegatecall(
                    abi.encodeWithSignature(
                        "swapExactAssetToStable(address,uint256)",
                        i_token1Address,
                        token1Remainder
                    )
                );
            }
        }
    }

    function rebalance() private {
        s_liquidityTokenId = false;
        _burn(s_totalShares);
        _mint(TransferHelper.safeGetBalance(i_usdcAddress));
    }

    // =================================
    // Private funcitons
    // =================================

    function _repayAndWithdraw(
        uint256 _shares,
        uint256 token0OwnedByUser,
        uint256 token1OwnedByUser
    ) private returns (uint256, uint256) {
        uint256 token1Remainder;
        uint256 token0Remainder;

        uint256 token1DebtToCover = (getVToken1Balance() * _shares) /
            s_totalShares;
        uint256 token0DebtToCover = (getVToken0Balance() * _shares) /
            s_totalShares;
        uint256 token1BalanceBefore = TransferHelper.safeGetBalance(
            i_token1Address
        );
        uint256 token0BalanceBefore = TransferHelper.safeGetBalance(
            i_token0Address
        );

        uint256 usdcOraclePrice = getUsdcOraclePrice();
        uint256 _currentLTV = currentLTV();

        uint256 token0Swapped = 0;

        if (token1OwnedByUser < token1DebtToCover) {
            (, bytes memory data) = s_swapHelper.delegatecall(
                abi.encodeWithSignature(
                    "swapAssetToExactAsset(address,address,uint256)",
                    i_token0Address,
                    i_token1Address,
                    token1DebtToCover - token1OwnedByUser
                )
            );
            token0Swapped += abi.decode(data, (uint256));
            if (
                token1OwnedByUser +
                    TransferHelper.safeGetBalance(i_token1Address) -
                    token1BalanceBefore <
                token1DebtToCover
            ) {
                revert ChamberV1__SwappedToken0ForToken1StillCantRepay();
            }
        }

        i_soToken1.repayBorrow(token1DebtToCover);

        i_soUSDC.redeemUnderlying(
            (((((token1DebtToCover * getToken1OraclePrice())) *
                USDC_RATE *
                PRECISION) /
                usdcOraclePrice /
                TOKEN1_RATE) / _currentLTV)
        );

        if (token0OwnedByUser < token0DebtToCover + token0Swapped) {
            s_swapHelper.delegatecall(
                abi.encodeWithSignature(
                    "swapStableToExactAsset(address,uint256)",
                    i_token0Address,
                    token0DebtToCover + token0Swapped - token0OwnedByUser
                )
            );
            if (
                (token0OwnedByUser +
                    TransferHelper.safeGetBalance(i_token0Address)) -
                    token0BalanceBefore <
                token0DebtToCover
            ) {
                revert ChamberV1__SwappedUsdcForToken0StillCantRepay();
            }
        }
        i_soToken0.repayBorrow(token0DebtToCover);
        uint256 usdcToRepay = ((((token0DebtToCover * getToken0OraclePrice())) *
            USDC_RATE *
            PRECISION) /
            usdcOraclePrice /
            TOKEN0_RATE /
            _currentLTV);
        if (
            usdcToRepay >
            (getCompLiquidity() * USDC_RATE) / getUsdcOraclePrice()
        ) {
            i_soUSDC.redeemUnderlying((usdcToRepay * 50) / 100);
            i_soUSDC.redeemUnderlying((usdcToRepay * 499) / 1000);
            // i_soUSDC.redeemUnderlying((usdcToRepay * 8) / 100);
            // i_soUSDC.redeemUnderlying((usdcToRepay * 8) / 100);
        } else {
            i_soUSDC.redeemUnderlying(
                ((((token0DebtToCover * getToken0OraclePrice())) *
                    USDC_RATE *
                    PRECISION) /
                    usdcOraclePrice /
                    TOKEN0_RATE /
                    _currentLTV)
            );
        }

        if (
            TransferHelper.safeGetBalance(i_token0Address) >=
            token0BalanceBefore - token0OwnedByUser
        ) {
            token0Remainder =
                TransferHelper.safeGetBalance(i_token0Address) +
                token0OwnedByUser -
                token0BalanceBefore;
        } else {
            revert ChamberV1__UserRepaidMoreToken0ThanOwned();
        }

        if (
            TransferHelper.safeGetBalance(i_token1Address) >=
            token1BalanceBefore - token1OwnedByUser
        ) {
            token1Remainder =
                TransferHelper.safeGetBalance(i_token1Address) +
                token1OwnedByUser -
                token1BalanceBefore;
        } else {
            revert ChamberV1__UserRepaidMoreToken1ThanOwned();
        }

        return (token0Remainder, token1Remainder);
    }

    function getCompLiquidity() private view returns (uint256) {
        (, uint256 liquidity, ) = i_sonneComptroller.getAccountLiquidity(
            address(this)
        );
        return liquidity;
    }

    // function swapExactAssetToStable(
    //     address assetIn,
    //     uint256 amountIn
    // ) private {
    //     if (assetIn == i_token0Address) {
    //         i_uniswapSwapRouter.exactInput(
    //             ISwapRouter.ExactInputParams({
    //                 path: abi.encodePacked(assetIn, uint24(500), i_usdcAddress),
    //                 recipient: address(this),
    //                 deadline: block.timestamp,
    //                 amountIn: amountIn,
    //                 amountOutMinimum: 0
    //             })
    //         );
    //     } else {
    //         i_uniswapSwapRouter.exactInput(
    //             ISwapRouter.ExactInputParams({
    //                 path: abi.encodePacked(
    //                     assetIn,
    //                     uint24(3000),
    //                     i_token0Address,
    //                     uint24(500),
    //                     i_usdcAddress
    //                 ),
    //                 recipient: address(this),
    //                 deadline: block.timestamp,
    //                 amountIn: amountIn,
    //                 amountOutMinimum: 0
    //             })
    //         );
    //     }
    // }

    // function swapStableToExactAsset(
    //     uint256 amountOut
    // ) private {
    //     i_uniswapSwapRouter.exactOutput(
    //         ISwapRouter.ExactOutputParams({
    //             path: abi.encodePacked(
    //                 i_token0Address,
    //                 uint24(500),
    //                 i_usdcAddress
    //             ),
    //             recipient: address(this),
    //             deadline: block.timestamp,
    //             amountOut: amountOut,
    //             amountInMaximum: 1e50
    //         })
    //     );
    // }

    // function swapAssetToExactAsset(
    //     address assetIn,
    //     address assetOut,
    //     uint256 amountOut
    // ) private returns (uint256) {
    //     uint256 amountIn = i_uniswapSwapRouter.exactOutput(
    //         ISwapRouter.ExactOutputParams({
    //             path: abi.encodePacked(assetOut, uint24(3000), assetIn),
    //             recipient: address(this),
    //             deadline: block.timestamp,
    //             amountOut: amountOut,
    //             amountInMaximum: type(uint256).max
    //         })
    //     );

    //     return (amountIn);
    // }

    function _withdraw(
        uint128 liquidityToBurn
    ) private returns (uint256, uint256, uint256, uint256) {
        uint256 preBalanceToken1 = TransferHelper.safeGetBalance(
            i_token1Address
        );
        uint256 preBalanceToken0 = TransferHelper.safeGetBalance(
            i_token0Address
        );
        (uint256 burnToken0, uint256 burnToken1) = i_uniswapPool.burn(
            s_lowerTick,
            s_upperTick,
            liquidityToBurn
        );
        i_uniswapPool.collect(
            address(this),
            s_lowerTick,
            s_upperTick,
            type(uint128).max,
            type(uint128).max
        );
        uint256 feeToken1 = TransferHelper.safeGetBalance(i_token1Address) -
            preBalanceToken1 -
            burnToken1;
        uint256 feeToken0 = TransferHelper.safeGetBalance(i_token0Address) -
            preBalanceToken0 -
            burnToken0;
        return (burnToken0, burnToken1, feeToken0, feeToken1);
    }

    function _applyFees(uint256 _feeToken0, uint256 _feeToken1) private {
        s_cetraFeeToken0 += (_feeToken0 * CETRA_FEE) / PRECISION;
        s_cetraFeeToken1 += (_feeToken1 * CETRA_FEE) / PRECISION;
    }

    function _claimAndIncreaseCollateral() public {
        i_sonneComptroller.claimComp(address(this));
        if (TransferHelper.safeGetBalance(SONNE_ADDRESS) > 1e18) {
            VELO_ROUTER.swapExactTokensForTokensSimple(
                TransferHelper.safeGetBalance(SONNE_ADDRESS),
                0,
                SONNE_ADDRESS,
                i_usdcAddress,
                false,
                address(this),
                block.timestamp + 60
            );
            assert(
                i_soUSDC.mint(TransferHelper.safeGetBalance(i_usdcAddress)) == 0
            );
        }
    }

    // =================================
    // View funcitons
    // =================================

    function getAdminBalance()
        external
        view
        override
        returns (uint256, uint256)
    {
        return (s_cetraFeeToken0, s_cetraFeeToken1);
    }

    function currentUSDBalance() public view override returns (uint256) {
        (
            uint256 token0PoolBalance,
            uint256 token1PoolBalance
        ) = calculateCurrentPoolReserves();
        (
            uint256 token0FeePending,
            uint256 token1FeePending
        ) = calculateCurrentFees();

        uint256 pureUSDCAmount = getAUSDCTokenBalance() +
            TransferHelper.safeGetBalance(i_usdcAddress);

        uint256 poolTokensValue = ((
            ((((token0PoolBalance +
                token0FeePending +
                TransferHelper.safeGetBalance(i_token0Address) -
                s_cetraFeeToken0) * getToken0OraclePrice()) * USDC_RATE) /
                getUsdcOraclePrice())
        ) /
            TOKEN0_RATE +
            (
                ((((token1PoolBalance +
                    token1FeePending +
                    TransferHelper.safeGetBalance(i_token1Address) -
                    s_cetraFeeToken1) * getToken1OraclePrice()) * USDC_RATE) /
                    getUsdcOraclePrice())
            ) /
            TOKEN1_RATE);
        uint256 debtTokensValue = ((getVToken0Balance() *
            getToken0OraclePrice() *
            USDC_RATE) /
            TOKEN0_RATE /
            getUsdcOraclePrice() +
            (getVToken1Balance() * getToken1OraclePrice() * USDC_RATE) /
            TOKEN1_RATE /
            getUsdcOraclePrice());
        return pureUSDCAmount + poolTokensValue - debtTokensValue;
    }

    function currentLTV() public view override returns (uint256) {
        // return currentETHBorrowed * getToken0OraclePrice() / currentUSDInCollateral/getUsdOraclePrice()
        uint256 liquidity = getCompLiquidity();
        uint256 ltv = (PRECISION * 9) /
            10 -
            (liquidity * PRECISION * PRECISION * 1e6) /
            (TransferHelper.safeGetBalance(address(i_soUSDC)) *
                i_soUSDC.exchangeRateStored() *
                getUsdcOraclePrice());
        return ltv;
    }

    function sharesWorth(uint256 shares) private view returns (uint256) {
        return (currentUSDBalance() * shares) / s_totalShares;
    }

    function getTick() private view returns (int24) {
        (, int24 tick, , , , , ) = i_uniswapPool.slot0();
        return tick;
    }

    function getUsdcOraclePrice() private view returns (uint256) {
        return (
            ((i_sonneOracle.getUnderlyingPrice(i_soUSDC) * USDC_RATE) /
                PRECISION)
        );
    }

    function getToken0OraclePrice() private view returns (uint256) {
        return (
            ((i_sonneOracle.getUnderlyingPrice(i_soToken0) * TOKEN0_RATE) /
                PRECISION)
        );
    }

    function getToken1OraclePrice() private view returns (uint256) {
        return (
            ((i_sonneOracle.getUnderlyingPrice(i_soToken1) * TOKEN1_RATE) /
                PRECISION)
        );
    }

    function _getPositionID() private view returns (bytes32 positionID) {
        return
            keccak256(
                abi.encodePacked(address(this), s_lowerTick, s_upperTick)
            );
    }

    function getSqrtRatioX96() private view returns (uint160) {
        (uint160 sqrtRatioX96, , , , , , ) = i_uniswapPool.slot0();
        return sqrtRatioX96;
    }

    function calculatePoolReserves(
        uint128 liquidity
    ) private view returns (uint256, uint256) {
        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                getSqrtRatioX96(),
                MathHelper.getSqrtRatioAtTick(s_lowerTick),
                MathHelper.getSqrtRatioAtTick(s_upperTick),
                liquidity
            );
        return (amount0, amount1);
    }

    function calculateCurrentPoolReserves()
        public
        view
        override
        returns (uint256, uint256)
    {
        // compute current holdings from liquidity
        (uint256 amount0Current, uint256 amount1Current) = LiquidityAmounts
            .getAmountsForLiquidity(
                getSqrtRatioX96(),
                MathHelper.getSqrtRatioAtTick(s_lowerTick),
                MathHelper.getSqrtRatioAtTick(s_upperTick),
                getLiquidity()
            );

        return (amount0Current, amount1Current);
    }

    function getLiquidity() private view returns (uint128) {
        (uint128 liquidity, , , , ) = i_uniswapPool.positions(_getPositionID());
        return liquidity;
    }

    function calculateCurrentFees()
        private
        view
        returns (uint256 fee0, uint256 fee1)
    {
        int24 tick = getTick();
        (
            uint128 liquidity,
            uint256 feeGrowthInside0Last,
            uint256 feeGrowthInside1Last,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = i_uniswapPool.positions(_getPositionID());
        fee0 =
            _computeFeesEarned(true, feeGrowthInside0Last, tick, liquidity) +
            uint256(tokensOwed0);

        fee1 =
            _computeFeesEarned(false, feeGrowthInside1Last, tick, liquidity) +
            uint256(tokensOwed1);
    }

    function _computeFeesEarned(
        bool isZero,
        uint256 feeGrowthInsideLast,
        int24 tick,
        uint128 liquidity
    ) private view returns (uint256 fee) {
        uint256 feeGrowthOutsideLower;
        uint256 feeGrowthOutsideUpper;
        uint256 feeGrowthGlobal;
        if (isZero) {
            feeGrowthGlobal = i_uniswapPool.feeGrowthGlobal0X128();
            (, , feeGrowthOutsideLower, , , , , ) = i_uniswapPool.ticks(
                s_lowerTick
            );
            (, , feeGrowthOutsideUpper, , , , , ) = i_uniswapPool.ticks(
                s_upperTick
            );
        } else {
            feeGrowthGlobal = i_uniswapPool.feeGrowthGlobal1X128();
            (, , , feeGrowthOutsideLower, , , , ) = i_uniswapPool.ticks(
                s_lowerTick
            );
            (, , , feeGrowthOutsideUpper, , , , ) = i_uniswapPool.ticks(
                s_upperTick
            );
        }

        unchecked {
            // calculate fee growth below
            uint256 feeGrowthBelow;
            if (tick >= s_lowerTick) {
                feeGrowthBelow = feeGrowthOutsideLower;
            } else {
                feeGrowthBelow = feeGrowthGlobal - feeGrowthOutsideLower;
            }

            // calculate fee growth above
            uint256 feeGrowthAbove;
            if (tick < s_upperTick) {
                feeGrowthAbove = feeGrowthOutsideUpper;
            } else {
                feeGrowthAbove = feeGrowthGlobal - feeGrowthOutsideUpper;
            }

            uint256 feeGrowthInside = feeGrowthGlobal -
                feeGrowthBelow -
                feeGrowthAbove;
            fee = FullMath.mulDiv(
                liquidity,
                feeGrowthInside - feeGrowthInsideLast,
                0x100000000000000000000000000000000
            );
        }
    }

    function getAUSDCTokenBalance() private view returns (uint256) {
        return
            (i_soUSDC.balanceOf(address(this)) *
                i_soUSDC.exchangeRateStored()) / PRECISION;
    }

    function getVToken0Balance() private view returns (uint256) {
        return i_soToken0.borrowBalanceStored(address(this));
    }

    function getVToken1Balance() private view returns (uint256) {
        return i_soToken1.borrowBalanceStored(address(this));
    }

    // =================================
    // Getters
    // =================================

    function get_i_aaveVToken0() external pure override returns (address) {
        return address(i_soToken0);
    }

    function get_i_aaveVToken1() external pure override returns (address) {
        return address(i_soToken1);
    }

    function get_i_aaveAUSDCToken() external pure override returns (address) {
        return address(i_soUSDC);
    }

    function get_s_totalShares() external view override returns (uint256) {
        return s_totalShares;
    }

    function get_s_userShares(
        address user
    ) external view override returns (uint256) {
        return s_userShares[user];
    }

    // =================================
    // Callbacks
    // =================================

    /// @notice Uniswap V3 callback fn, called back on pool.mint
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata /*_data*/
    ) external override {
        if (msg.sender != address(i_uniswapPool)) {
            revert ChamberV1__CallerIsNotUniPool();
        }

        if (amount0Owed > 0)
            TransferHelper.safeTransfer(
                i_token0Address,
                msg.sender,
                amount0Owed
            );
        if (amount1Owed > 0)
            TransferHelper.safeTransfer(
                i_token1Address,
                msg.sender,
                amount1Owed
            );
    }

    receive() external payable {}

    // =================================
    // Admin functions
    // =================================

    function _redeemFees() external override onlyOwner {
        TransferHelper.safeTransfer(i_token1Address, owner(), s_cetraFeeToken1);
        TransferHelper.safeTransfer(i_token0Address, owner(), s_cetraFeeToken0);
        s_cetraFeeToken1 = 0;
        s_cetraFeeToken0 = 0;
    }

    function setTicksRange(int24 _ticksRange) external override onlyOwner {
        s_ticksRange = _ticksRange;
    }

    function giveApprove(
        address _token,
        address _to
    ) external override onlyOwner {
        TransferHelper.safeApprove(_token, _to, type(uint256).max);
    }

    function setLTV(
        uint256 _targetLTV,
        uint256 _minLTV,
        uint256 _maxLTV,
        uint256 _hedgeDev
    ) external override onlyOwner {
        s_targetLTV = _targetLTV;
        s_minLTV = _minLTV;
        s_maxLTV = _maxLTV;
        s_hedgeDev = _hedgeDev;
    }
}

// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.0;

interface IChamberV1 {
    function burn(uint256 _shares) external;

    function mint(uint256 usdAmount) external;

    function calculateCurrentPoolReserves()
        external
        view
        returns (uint256, uint256);

    function currentLTV() external view returns (uint256);

    function currentUSDBalance() external returns (uint256);

    function getAdminBalance() external view returns (uint256, uint256);

    function get_i_aaveVToken0() external view returns (address);

    function get_i_aaveVToken1() external view returns (address);

    function get_i_aaveAUSDCToken() external view returns (address);

    function get_s_totalShares() external view returns (uint256);

    function get_s_userShares(address user) external view returns (uint256);

    function _redeemFees() external;

    function setTicksRange(int24 _ticksRange) external;

    function giveApprove(address _token, address _to) external;

    function setLTV(
        uint256 _targetLTV,
        uint256 _minLTV,
        uint256 _maxLTV,
        uint256 _hedgeDev
    ) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

library MathHelper {

    function getSqrtRatioAtTick(
        int24 tick
    ) internal pure returns (uint160 sqrtPriceX96) {
        uint256 absTick = tick < 0
            ? uint256(-int256(tick))
            : uint256(int256(tick));
        require(absTick <= 887272, "T");

        uint256 ratio = absTick & 0x1 != 0
            ? 0xfffcb933bd6fad37aa2d162d1a594001
            : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0)
            ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0)
            ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0)
            ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0)
            ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0)
            ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0)
            ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0)
            ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0)
            ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0)
            ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0)
            ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0)
            ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0)
            ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0)
            ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0)
            ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0)
            ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0)
            ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0)
            ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0)
            ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0)
            ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint256).max / ratio;

        // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
        // we then downcast because we know the result always fits within 160 bits due to our tick input constraint
        // we round up in the division so getTickAtSqrtRatio of the output price is always consistent
        sqrtPriceX96 = uint160(
            (ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1)
        );
    }

}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

abstract contract ComptrollerInterface {
    /// @notice Indicator that this is a Comptroller contract (for inspection)
    bool public constant isComptroller = true;

    /*** Assets You Are In ***/

    function enterMarkets(
        address[] calldata cTokens
    ) external virtual returns (uint[] memory);

    function exitMarket(address cToken) external virtual returns (uint);

    /*** Policy Hooks ***/

    function mintAllowed(
        address cToken,
        address minter,
        uint mintAmount
    ) external virtual returns (uint);

    function mintVerify(
        address cToken,
        address minter,
        uint mintAmount,
        uint mintTokens
    ) external virtual;

    function redeemAllowed(
        address cToken,
        address redeemer,
        uint redeemTokens
    ) external virtual returns (uint);

    function redeemVerify(
        address cToken,
        address redeemer,
        uint redeemAmount,
        uint redeemTokens
    ) external virtual;

    function borrowAllowed(
        address cToken,
        address borrower,
        uint borrowAmount
    ) external virtual returns (uint);

    function borrowVerify(
        address cToken,
        address borrower,
        uint borrowAmount
    ) external virtual;

    function repayBorrowAllowed(
        address cToken,
        address payer,
        address borrower,
        uint repayAmount
    ) external virtual returns (uint);

    function repayBorrowVerify(
        address cToken,
        address payer,
        address borrower,
        uint repayAmount,
        uint borrowerIndex
    ) external virtual;

    function liquidateBorrowAllowed(
        address cTokenBorrowed,
        address cTokenCollateral,
        address liquidator,
        address borrower,
        uint repayAmount
    ) external virtual returns (uint);

    function liquidateBorrowVerify(
        address cTokenBorrowed,
        address cTokenCollateral,
        address liquidator,
        address borrower,
        uint repayAmount,
        uint seizeTokens
    ) external virtual;

    function seizeAllowed(
        address cTokenCollateral,
        address cTokenBorrowed,
        address liquidator,
        address borrower,
        uint seizeTokens
    ) external virtual returns (uint);

    function seizeVerify(
        address cTokenCollateral,
        address cTokenBorrowed,
        address liquidator,
        address borrower,
        uint seizeTokens
    ) external virtual;

    function transferAllowed(
        address cToken,
        address src,
        address dst,
        uint transferTokens
    ) external virtual returns (uint);

    function transferVerify(
        address cToken,
        address src,
        address dst,
        uint transferTokens
    ) external virtual;

    /*** Liquidity/Liquidation Calculations ***/

    function liquidateCalculateSeizeTokens(
        address cTokenBorrowed,
        address cTokenCollateral,
        uint repayAmount
    ) external view virtual returns (uint, uint);
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./ComptrollerInterface.sol";
import "./InterestRateModel.sol";
import "./EIP20NonStandardInterface.sol";
import "./ErrorReporter.sol";

contract CTokenStorage {
    /**
     * @dev Guard variable for re-entrancy checks
     */
    bool internal _notEntered;

    /**
     * @notice EIP-20 token name for this token
     */
    string public name;

    /**
     * @notice EIP-20 token symbol for this token
     */
    string public symbol;

    /**
     * @notice EIP-20 token decimals for this token
     */
    uint8 public decimals;

    // Maximum borrow rate that can ever be applied (.0005% / block)
    uint internal constant borrowRateMaxMantissa = 0.0005e16;

    // Maximum fraction of interest that can be set aside for reserves
    uint internal constant reserveFactorMaxMantissa = 1e18;

    /**
     * @notice Administrator for this contract
     */
    address payable public admin;

    /**
     * @notice Pending administrator for this contract
     */
    address payable public pendingAdmin;

    /**
     * @notice Contract which oversees inter-cToken operations
     */
    ComptrollerInterface public comptroller;

    /**
     * @notice Model which tells what the current interest rate should be
     */
    InterestRateModel public interestRateModel;

    // Initial exchange rate used when minting the first CTokens (used when totalSupply = 0)
    uint internal initialExchangeRateMantissa;

    /**
     * @notice Fraction of interest currently set aside for reserves
     */
    uint public reserveFactorMantissa;

    /**
     * @notice Block number that interest was last accrued at
     */
    uint public accrualBlockNumber;

    /**
     * @notice Accumulator of the total earned interest rate since the opening of the market
     */
    uint public borrowIndex;

    /**
     * @notice Total amount of outstanding borrows of the underlying in this market
     */
    uint public totalBorrows;

    /**
     * @notice Total amount of reserves of the underlying held in this market
     */
    uint public totalReserves;

    /**
     * @notice Total number of tokens in circulation
     */
    uint public totalSupply;

    // Official record of token balances for each account
    mapping(address => uint) internal accountTokens;

    // Approved token transfer amounts on behalf of others
    mapping(address => mapping(address => uint)) internal transferAllowances;

    /**
     * @notice Container for borrow balance information
     * @member principal Total balance (with accrued interest), after applying the most recent balance-changing action
     * @member interestIndex Global borrowIndex as of the most recent balance-changing action
     */
    struct BorrowSnapshot {
        uint principal;
        uint interestIndex;
    }

    // Mapping of account addresses to outstanding borrow balances
    mapping(address => BorrowSnapshot) internal accountBorrows;

    /**
     * @notice Share of seized collateral that is added to reserves
     */
    uint public constant protocolSeizeShareMantissa = 2.8e16; //2.8%
}

abstract contract CTokenInterface is CTokenStorage {
    /**
     * @notice Indicator that this is a CToken contract (for inspection)
     */
    bool public constant isCToken = true;

    /*** Market Events ***/

    /**
     * @notice Event emitted when interest is accrued
     */
    event AccrueInterest(
        uint cashPrior,
        uint interestAccumulated,
        uint borrowIndex,
        uint totalBorrows
    );

    /**
     * @notice Event emitted when tokens are minted
     */
    event Mint(address minter, uint mintAmount, uint mintTokens);

    /**
     * @notice Event emitted when tokens are redeemed
     */
    event Redeem(address redeemer, uint redeemAmount, uint redeemTokens);

    /**
     * @notice Event emitted when underlying is borrowed
     */
    event Borrow(
        address borrower,
        uint borrowAmount,
        uint accountBorrows,
        uint totalBorrows
    );

    /**
     * @notice Event emitted when a borrow is repaid
     */
    event RepayBorrow(
        address payer,
        address borrower,
        uint repayAmount,
        uint accountBorrows,
        uint totalBorrows
    );

    /**
     * @notice Event emitted when a borrow is liquidated
     */
    event LiquidateBorrow(
        address liquidator,
        address borrower,
        uint repayAmount,
        address cTokenCollateral,
        uint seizeTokens
    );

    /*** Admin Events ***/

    /**
     * @notice Event emitted when pendingAdmin is changed
     */
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /**
     * @notice Event emitted when pendingAdmin is accepted, which means admin is updated
     */
    event NewAdmin(address oldAdmin, address newAdmin);

    /**
     * @notice Event emitted when comptroller is changed
     */
    event NewComptroller(
        ComptrollerInterface oldComptroller,
        ComptrollerInterface newComptroller
    );

    /**
     * @notice Event emitted when interestRateModel is changed
     */
    event NewMarketInterestRateModel(
        InterestRateModel oldInterestRateModel,
        InterestRateModel newInterestRateModel
    );

    /**
     * @notice Event emitted when the reserve factor is changed
     */
    event NewReserveFactor(
        uint oldReserveFactorMantissa,
        uint newReserveFactorMantissa
    );

    /**
     * @notice Event emitted when the reserves are added
     */
    event ReservesAdded(
        address benefactor,
        uint addAmount,
        uint newTotalReserves
    );

    /**
     * @notice Event emitted when the reserves are reduced
     */
    event ReservesReduced(
        address admin,
        uint reduceAmount,
        uint newTotalReserves
    );

    /**
     * @notice EIP20 Transfer event
     */
    event Transfer(address indexed from, address indexed to, uint amount);

    /**
     * @notice EIP20 Approval event
     */
    event Approval(address indexed owner, address indexed spender, uint amount);

    /*** User Interface ***/

    function transfer(address dst, uint amount) external virtual returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint amount
    ) external virtual returns (bool);

    function approve(
        address spender,
        uint amount
    ) external virtual returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view virtual returns (uint);

    function balanceOf(address owner) external view virtual returns (uint);

    function balanceOfUnderlying(address owner) external virtual returns (uint);

    function getAccountSnapshot(
        address account
    ) external view virtual returns (uint, uint, uint, uint);

    function borrowRatePerBlock() external view virtual returns (uint);

    function supplyRatePerBlock() external view virtual returns (uint);

    function totalBorrowsCurrent() external virtual returns (uint);

    function borrowBalanceCurrent(
        address account
    ) external virtual returns (uint);

    function borrowBalanceStored(
        address account
    ) external view virtual returns (uint);

    function exchangeRateCurrent() external virtual returns (uint);

    function exchangeRateStored() external view virtual returns (uint);

    function getCash() external view virtual returns (uint);

    function accrueInterest() external virtual returns (uint);

    function seize(
        address liquidator,
        address borrower,
        uint seizeTokens
    ) external virtual returns (uint);

    /*** Admin Functions ***/

    function _setPendingAdmin(
        address payable newPendingAdmin
    ) external virtual returns (uint);

    function _acceptAdmin() external virtual returns (uint);

    function _setComptroller(
        ComptrollerInterface newComptroller
    ) external virtual returns (uint);

    function _setReserveFactor(
        uint newReserveFactorMantissa
    ) external virtual returns (uint);

    function _reduceReserves(uint reduceAmount) external virtual returns (uint);

    function _setInterestRateModel(
        InterestRateModel newInterestRateModel
    ) external virtual returns (uint);
}

contract CErc20Storage {
    /**
     * @notice Underlying asset for this CToken
     */
    address public underlying;
}

abstract contract CErc20Interface is CErc20Storage {
    /*** User Interface ***/

    function mint(uint mintAmount) external virtual returns (uint);

    function redeem(uint redeemTokens) external virtual returns (uint);

    function redeemUnderlying(
        uint redeemAmount
    ) external virtual returns (uint);

    function borrow(uint borrowAmount) external virtual returns (uint);

    function repayBorrow(uint repayAmount) external virtual returns (uint);

    function repayBorrowBehalf(
        address borrower,
        uint repayAmount
    ) external virtual returns (uint);

    function liquidateBorrow(
        address borrower,
        uint repayAmount,
        CTokenInterface cTokenCollateral
    ) external virtual returns (uint);

    function sweepToken(EIP20NonStandardInterface token) external virtual;

    /*** Admin Functions ***/

    function _addReserves(uint addAmount) external virtual returns (uint);
}

contract CDelegationStorage {
    /**
     * @notice Implementation address for this contract
     */
    address public implementation;
}

abstract contract CDelegatorInterface is CDelegationStorage {
    /**
     * @notice Emitted when implementation is changed
     */
    event NewImplementation(
        address oldImplementation,
        address newImplementation
    );

    /**
     * @notice Called by the admin to update the implementation of the delegator
     * @param implementation_ The address of the new implementation for delegation
     * @param allowResign Flag to indicate whether to call _resignImplementation on the old implementation
     * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
     */
    function _setImplementation(
        address implementation_,
        bool allowResign,
        bytes memory becomeImplementationData
    ) external virtual;
}

abstract contract CDelegateInterface is CDelegationStorage {
    /**
     * @notice Called by the delegator on a delegate to initialize it for duty
     * @dev Should revert if any issues arise which make it unfit for delegation
     * @param data The encoded bytes data for any initialization
     */
    function _becomeImplementation(bytes memory data) external virtual;

    /**
     * @notice Called by the delegator on a delegate to forfeit its responsibility
     */
    function _resignImplementation() external virtual;
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

/**
 * @title EIP20NonStandardInterface
 * @dev Version of ERC20 with no return values for `transfer` and `transferFrom`
 *  See https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
 */
interface EIP20NonStandardInterface {
    /**
     * @notice Get the total number of tokens in circulation
     * @return The supply of tokens
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Gets the balance of the specified address
     * @param owner The address from which the balance will be retrieved
     * @return balance The balance
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! `transfer` does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     */
    function transfer(address dst, uint256 amount) external;

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! `transferFrom` does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     */
    function transferFrom(address src, address dst, uint256 amount) external;

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved
     * @return success Whether or not the approval succeeded
     */
    function approve(
        address spender,
        uint256 amount
    ) external returns (bool success);

    /**
     * @notice Get the current allowance from `owner` for `spender`
     * @param owner The address of the account which owns the tokens to be spent
     * @param spender The address of the account which may transfer tokens
     * @return remaining The number of tokens allowed to be spent
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

contract ComptrollerErrorReporter {
    enum Error {
        NO_ERROR,
        UNAUTHORIZED,
        COMPTROLLER_MISMATCH,
        INSUFFICIENT_SHORTFALL,
        INSUFFICIENT_LIQUIDITY,
        INVALID_CLOSE_FACTOR,
        INVALID_COLLATERAL_FACTOR,
        INVALID_LIQUIDATION_INCENTIVE,
        MARKET_NOT_ENTERED, // no longer possible
        MARKET_NOT_LISTED,
        MARKET_ALREADY_LISTED,
        MATH_ERROR,
        NONZERO_BORROW_BALANCE,
        PRICE_ERROR,
        REJECTION,
        SNAPSHOT_ERROR,
        TOO_MANY_ASSETS,
        TOO_MUCH_REPAY
    }

    enum FailureInfo {
        ACCEPT_ADMIN_PENDING_ADMIN_CHECK,
        ACCEPT_PENDING_IMPLEMENTATION_ADDRESS_CHECK,
        EXIT_MARKET_BALANCE_OWED,
        EXIT_MARKET_REJECTION,
        SET_CLOSE_FACTOR_OWNER_CHECK,
        SET_CLOSE_FACTOR_VALIDATION,
        SET_COLLATERAL_FACTOR_OWNER_CHECK,
        SET_COLLATERAL_FACTOR_NO_EXISTS,
        SET_COLLATERAL_FACTOR_VALIDATION,
        SET_COLLATERAL_FACTOR_WITHOUT_PRICE,
        SET_IMPLEMENTATION_OWNER_CHECK,
        SET_LIQUIDATION_INCENTIVE_OWNER_CHECK,
        SET_LIQUIDATION_INCENTIVE_VALIDATION,
        SET_MAX_ASSETS_OWNER_CHECK,
        SET_PENDING_ADMIN_OWNER_CHECK,
        SET_PENDING_IMPLEMENTATION_OWNER_CHECK,
        SET_PRICE_ORACLE_OWNER_CHECK,
        SUPPORT_MARKET_EXISTS,
        SUPPORT_MARKET_OWNER_CHECK,
        SET_PAUSE_GUARDIAN_OWNER_CHECK
    }

    /**
     * @dev `error` corresponds to enum Error; `info` corresponds to enum FailureInfo, and `detail` is an arbitrary
     * contract-specific code that enables us to report opaque error codes from upgradeable contracts.
     **/
    event Failure(uint error, uint info, uint detail);

    /**
     * @dev use this when reporting a known error from the money market or a non-upgradeable collaborator
     */
    function fail(Error err, FailureInfo info) internal returns (uint) {
        emit Failure(uint(err), uint(info), 0);

        return uint(err);
    }

    /**
     * @dev use this when reporting an opaque error from an upgradeable collaborator contract
     */
    function failOpaque(
        Error err,
        FailureInfo info,
        uint opaqueError
    ) internal returns (uint) {
        emit Failure(uint(err), uint(info), opaqueError);

        return uint(err);
    }
}

contract TokenErrorReporter {
    uint public constant NO_ERROR = 0; // support legacy return codes

    error TransferComptrollerRejection(uint256 errorCode);
    error TransferNotAllowed();
    error TransferNotEnough();
    error TransferTooMuch();

    error MintComptrollerRejection(uint256 errorCode);
    error MintFreshnessCheck();

    error RedeemComptrollerRejection(uint256 errorCode);
    error RedeemFreshnessCheck();
    error RedeemTransferOutNotPossible();

    error BorrowComptrollerRejection(uint256 errorCode);
    error BorrowFreshnessCheck();
    error BorrowCashNotAvailable();

    error RepayBorrowComptrollerRejection(uint256 errorCode);
    error RepayBorrowFreshnessCheck();

    error LiquidateComptrollerRejection(uint256 errorCode);
    error LiquidateFreshnessCheck();
    error LiquidateCollateralFreshnessCheck();
    error LiquidateAccrueBorrowInterestFailed(uint256 errorCode);
    error LiquidateAccrueCollateralInterestFailed(uint256 errorCode);
    error LiquidateLiquidatorIsBorrower();
    error LiquidateCloseAmountIsZero();
    error LiquidateCloseAmountIsUintMax();
    error LiquidateRepayBorrowFreshFailed(uint256 errorCode);

    error LiquidateSeizeComptrollerRejection(uint256 errorCode);
    error LiquidateSeizeLiquidatorIsBorrower();

    error AcceptAdminPendingAdminCheck();

    error SetComptrollerOwnerCheck();
    error SetPendingAdminOwnerCheck();

    error SetReserveFactorAdminCheck();
    error SetReserveFactorFreshCheck();
    error SetReserveFactorBoundsCheck();

    error AddReservesFactorFreshCheck(uint256 actualAddAmount);

    error ReduceReservesAdminCheck();
    error ReduceReservesFreshCheck();
    error ReduceReservesCashNotAvailable();
    error ReduceReservesCashValidation();

    error SetInterestRateModelOwnerCheck();
    error SetInterestRateModelFreshCheck();
}

// SPDX-License-Identifier: BSD-3-Clause
abstract contract ICErc20 {
    address public underlying;

    function mint(uint mintAmount) external virtual returns (uint);

    function redeem(uint redeemTokens) external virtual returns (uint);

    function redeemUnderlying(
        uint redeemAmount
    ) external virtual returns (uint);

    function borrow(uint borrowAmount) external virtual returns (uint);

    function repayBorrow(uint repayAmount) external virtual returns (uint);

    function borrowBalanceStored(
        address account
    ) external view virtual returns (uint);

    function borrowBalanceCurrent(
        address account
    ) external virtual returns (uint);

    function exchangeRateStored() external view virtual returns (uint);

    function balanceOf(address owner) external view virtual returns (uint256);
}

// SPDX-License-Identifier: BSD-3-Clause
abstract contract IComptroller {
    function getAccountLiquidity(
        address account
    ) public view virtual returns (uint, uint, uint);

    function enterMarkets(
        address[] memory cTokens
    ) public virtual returns (uint[] memory);

    function claimComp(address holder) public virtual;
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

/**
 * @title Compound's InterestRateModel Interface
 * @author Compound
 */
abstract contract InterestRateModel {
    /// @notice Indicator that this is an InterestRateModel contract (for inspection)
    bool public constant isInterestRateModel = true;

    /**
     * @notice Calculates the current borrow interest rate per block
     * @param cash The total amount of cash the market has
     * @param borrows The total amount of borrows the market has outstanding
     * @param reserves The total amount of reserves the market has
     * @return The borrow rate per block (as a percentage, and scaled by 1e18)
     */
    function getBorrowRate(
        uint cash,
        uint borrows,
        uint reserves
    ) external view virtual returns (uint);

    /**
     * @notice Calculates the current supply interest rate per block
     * @param cash The total amount of cash the market has
     * @param borrows The total amount of borrows the market has outstanding
     * @param reserves The total amount of reserves the market has
     * @param reserveFactorMantissa The current reserve factor the market has
     * @return The supply rate per block (as a percentage, and scaled by 1e18)
     */
    function getSupplyRate(
        uint cash,
        uint borrows,
        uint reserves,
        uint reserveFactorMantissa
    ) external view virtual returns (uint);
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./ICErc20.sol";

abstract contract PriceOracle {
    /// @notice Indicator that this is a PriceOracle contract (for inspection)
    bool public constant isPriceOracle = true;

    /**
     * @notice Get the underlying price of a cToken asset
     * @param cToken The cToken to get the underlying price of
     * @return The underlying asset price mantissa (scaled by 1e18).
     *  Zero means the price is unavailable.
     */
    function getUnderlyingPrice(
        ICErc20 cToken
    ) external view virtual returns (uint);
}

// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.0;

interface ISwapHelper {
    function swapExactAssetToStable(address assetIn, uint256 amountIn) external returns (uint256);
    function swapStableToExactAsset(address assetOut, uint256 amountOut) external returns (uint256);
    function swapAssetToExactAsset(address assetIn, address assetOut, uint256 amountOut) external returns (uint256);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

library TransferHelper {

    error STF();
    error ST();
    error SA();
    error STE();
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
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert STF();
        }
        // require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF');
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
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert ST();
        }
        // require(success && (data.length == 0 || abi.decode(data, (bool))), 'ST');
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
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert SA();
        }
        // require(success && (data.length == 0 || abi.decode(data, (bool))), 'SA');
    }

    /// @notice Transfers ETH to the recipient address
    /// @dev Fails with `STE`
    /// @param to The destination of the transfer
    /// @param value The value to be transferred
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        if (!success) {
            revert STE();
        }
        // require(success, 'STE');
    }

    function safeGetBalance(
        address token
    ) internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Callback for IUniswapV3PoolActions#mint
/// @notice Any contract that calls IUniswapV3PoolActions#mint must implement this interface
interface IUniswapV3MintCallback {
    /// @notice Called to `msg.sender` after minting liquidity to a position from IUniswapV3Pool#mint.
    /// @dev In the implementation you must pay the pool tokens owed for the minted liquidity.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// @param amount0Owed The amount of token0 due to the pool for the minted liquidity
    /// @param amount1Owed The amount of token1 due to the pool for the minted liquidity
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#mint call
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface ISwapRouter is IUniswapV3SwapCallback {
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

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);

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
    function exactInput(
        ExactInputParams calldata params
    ) external payable returns (uint256 amountOut);

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

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingle(
        ExactOutputSingleParams calldata params
    ) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutput(
        ExactOutputParams calldata params
    ) external payable returns (uint256 amountIn);

    function factory() external view returns (address);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import '../pool/IUniswapV3PoolImmutables.sol';
import '../pool/IUniswapV3PoolState.sol';
import '../pool/IUniswapV3PoolDerivedState.sol';
import '../pool/IUniswapV3PoolActions.sol';
import '../pool/IUniswapV3PoolOwnerActions.sol';
import '../pool/IUniswapV3PoolEvents.sol';

/// @title The interface for a Uniswap V3 Pool
/// @notice A Uniswap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IUniswapV3Pool is
    IUniswapV3PoolImmutables,
    IUniswapV3PoolState,
    IUniswapV3PoolDerivedState,
    IUniswapV3PoolActions,
    IUniswapV3PoolOwnerActions,
    IUniswapV3PoolEvents
{

}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.4.0;

/// @title FixedPoint96
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)
/// @dev Used in SqrtPriceMath.sol
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.0;

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 512-bit multiply [prod1 prod0] = a * b
        // Compute the product mod 2**256 and mod 2**256 - 1
        // then use the Chinese Remainder Theorem to reconstruct
        // the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2**256 + prod0
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // Handle non-overflow cases, 256 by 256 division
        if (prod1 == 0) {
            require(denominator > 0);
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        // Make sure the result is less than 2**256.
        // Also prevents denominator == 0
        require(denominator > prod1);

        ///////////////////////////////////////////////
        // 512 by 256 division.
        ///////////////////////////////////////////////

        // Make division exact by subtracting the remainder from [prod1 prod0]
        // Compute remainder using mulmod
        uint256 remainder;
        assembly {
            remainder := mulmod(a, b, denominator)
        }
        // Subtract 256 bit number from 512 bit number
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        // Factor powers of two out of denominator
        // Compute largest power of two divisor of denominator.
        // Always >= 1.
        uint256 twos = denominator & (~denominator + 1);
        // Divide denominator by power of two
        assembly {
            denominator := div(denominator, twos)
        }

        // Divide [prod1 prod0] by the factors of two
        assembly {
            prod0 := div(prod0, twos)
        }
        // Shift in bits from prod1 into prod0. For this we need
        // to flip `twos` such that it is 2**256 / twos.
        // If twos is zero, then it becomes one
        assembly {
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        // Invert denominator mod 2**256
        // Now that denominator is an odd number, it has an inverse
        // modulo 2**256 such that denominator * inv = 1 mod 2**256.
        // Compute the inverse by starting with a seed that is correct
        // correct for four bits. That is, denominator * inv = 1 mod 2**4
        uint256 inv = (3 * denominator) ^ 2;
        // Now use Newton-Raphson iteration to improve the precision.
        // Thanks to Hensel's lifting lemma, this also works in modular
        // arithmetic, doubling the correct bits in each step.
        inv *= 2 - denominator * inv; // inverse mod 2**8
        inv *= 2 - denominator * inv; // inverse mod 2**16
        inv *= 2 - denominator * inv; // inverse mod 2**32
        inv *= 2 - denominator * inv; // inverse mod 2**64
        inv *= 2 - denominator * inv; // inverse mod 2**128
        inv *= 2 - denominator * inv; // inverse mod 2**256

        // Because the division is now exact we can divide by multiplying
        // with the modular inverse of denominator. This will give us the
        // correct result modulo 2**256. Since the precoditions guarantee
        // that the outcome is less than 2**256, this is the final result.
        // We don't need to compute the high bits of the result and prod1
        // is no longer required.
        result = prod0 * inv;
        return result;
    }

    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Permissionless pool actions
/// @notice Contains pool methods that can be called by anyone
interface IUniswapV3PoolActions {
    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
    function initialize(uint160 sqrtPriceX96) external;

    /// @notice Adds liquidity for the given recipient/tickLower/tickUpper position
    /// @dev The caller of this method receives a callback in the form of IUniswapV3MintCallback#uniswapV3MintCallback
    /// in which they must pay any token0 or token1 owed for the liquidity. The amount of token0/token1 due depends
    /// on tickLower, tickUpper, the amount of liquidity, and the current price.
    /// @param recipient The address for which the liquidity will be created
    /// @param tickLower The lower tick of the position in which to add liquidity
    /// @param tickUpper The upper tick of the position in which to add liquidity
    /// @param amount The amount of liquidity to mint
    /// @param data Any data that should be passed through to the callback
    /// @return amount0 The amount of token0 that was paid to mint the given amount of liquidity. Matches the value in the callback
    /// @return amount1 The amount of token1 that was paid to mint the given amount of liquidity. Matches the value in the callback
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Collects tokens owed to a position
    /// @dev Does not recompute fees earned, which must be done either via mint or burn of any amount of liquidity.
    /// Collect must be called by the position owner. To withdraw only token0 or only token1, amount0Requested or
    /// amount1Requested may be set to zero. To withdraw all tokens owed, caller may pass any value greater than the
    /// actual tokens owed, e.g. type(uint128).max. Tokens owed may be from accumulated swap fees or burned liquidity.
    /// @param recipient The address which should receive the fees collected
    /// @param tickLower The lower tick of the position for which to collect fees
    /// @param tickUpper The upper tick of the position for which to collect fees
    /// @param amount0Requested How much token0 should be withdrawn from the fees owed
    /// @param amount1Requested How much token1 should be withdrawn from the fees owed
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    /// @notice Burn liquidity from the sender and account tokens owed for the liquidity to the position
    /// @dev Can be used to trigger a recalculation of fees owed to a position by calling with an amount of 0
    /// @dev Fees must be collected separately via a call to #collect
    /// @param tickLower The lower tick of the position for which to burn liquidity
    /// @param tickUpper The upper tick of the position for which to burn liquidity
    /// @param amount How much liquidity to burn
    /// @return amount0 The amount of token0 sent to the recipient
    /// @return amount1 The amount of token1 sent to the recipient
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Swap token0 for token1, or token1 for token0
    /// @dev The caller of this method receives a callback in the form of IUniswapV3SwapCallback#uniswapV3SwapCallback
    /// @param recipient The address to receive the output of the swap
    /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
    /// @param amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
    /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
    /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
    /// @param data Any data to be passed through to the callback
    /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
    /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    /// @notice Receive token0 and/or token1 and pay it back, plus a fee, in the callback
    /// @dev The caller of this method receives a callback in the form of IUniswapV3FlashCallback#uniswapV3FlashCallback
    /// @dev Can be used to donate underlying tokens pro-rata to currently in-range liquidity providers by calling
    /// with 0 amount{0,1} and sending the donation amount(s) from the callback
    /// @param recipient The address which will receive the token0 and token1 amounts
    /// @param amount0 The amount of token0 to send
    /// @param amount1 The amount of token1 to send
    /// @param data Any data to be passed through to the callback
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    /// @notice Increase the maximum number of price and liquidity observations that this pool will store
    /// @dev This method is no-op if the pool already has an observationCardinalityNext greater than or equal to
    /// the input observationCardinalityNext.
    /// @param observationCardinalityNext The desired minimum number of observations for the pool to store
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Pool state that is not stored
/// @notice Contains view functions to provide information about the pool that is computed rather than stored on the
/// blockchain. The functions here may have variable gas costs.
interface IUniswapV3PoolDerivedState {
    /// @notice Returns the cumulative tick and liquidity as of each timestamp `secondsAgo` from the current block timestamp
    /// @dev To get a time weighted average tick or liquidity-in-range, you must call this with two values, one representing
    /// the beginning of the period and another for the end of the period. E.g., to get the last hour time-weighted average tick,
    /// you must call it with secondsAgos = [3600, 0].
    /// @dev The time weighted average tick represents the geometric time weighted average price of the pool, in
    /// log base sqrt(1.0001) of token1 / token0. The TickMath library can be used to go from a tick value to a ratio.
    /// @param secondsAgos From how long ago each cumulative tick and liquidity value should be returned
    /// @return tickCumulatives Cumulative tick values as of each `secondsAgos` from the current block timestamp
    /// @return secondsPerLiquidityCumulativeX128s Cumulative seconds per liquidity-in-range value as of each `secondsAgos` from the current block
    /// timestamp
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);

    /// @notice Returns a snapshot of the tick cumulative, seconds per liquidity and seconds inside a tick range
    /// @dev Snapshots must only be compared to other snapshots, taken over a period for which a position existed.
    /// I.e., snapshots cannot be compared if a position is not held for the entire period between when the first
    /// snapshot is taken and the second snapshot is taken.
    /// @param tickLower The lower tick of the range
    /// @param tickUpper The upper tick of the range
    /// @return tickCumulativeInside The snapshot of the tick accumulator for the range
    /// @return secondsPerLiquidityInsideX128 The snapshot of seconds per liquidity for the range
    /// @return secondsInside The snapshot of seconds per liquidity for the range
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
        external
        view
        returns (
            int56 tickCumulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        );
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Events emitted by a pool
/// @notice Contains all events emitted by the pool
interface IUniswapV3PoolEvents {
    /// @notice Emitted exactly once by a pool when #initialize is first called on the pool
    /// @dev Mint/Burn/Swap cannot be emitted by the pool before Initialize
    /// @param sqrtPriceX96 The initial sqrt price of the pool, as a Q64.96
    /// @param tick The initial tick of the pool, i.e. log base 1.0001 of the starting price of the pool
    event Initialize(uint160 sqrtPriceX96, int24 tick);

    /// @notice Emitted when liquidity is minted for a given position
    /// @param sender The address that minted the liquidity
    /// @param owner The owner of the position and recipient of any minted liquidity
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount The amount of liquidity minted to the position range
    /// @param amount0 How much token0 was required for the minted liquidity
    /// @param amount1 How much token1 was required for the minted liquidity
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted when fees are collected by the owner of a position
    /// @dev Collect events may be emitted with zero amount0 and amount1 when the caller chooses not to collect fees
    /// @param owner The owner of the position for which fees are collected
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount0 The amount of token0 fees collected
    /// @param amount1 The amount of token1 fees collected
    event Collect(
        address indexed owner,
        address recipient,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount0,
        uint128 amount1
    );

    /// @notice Emitted when a position's liquidity is removed
    /// @dev Does not withdraw any fees earned by the liquidity position, which must be withdrawn via #collect
    /// @param owner The owner of the position for which liquidity is removed
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount The amount of liquidity to remove
    /// @param amount0 The amount of token0 withdrawn
    /// @param amount1 The amount of token1 withdrawn
    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted by the pool for any swaps between token0 and token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the output of the swap
    /// @param amount0 The delta of the token0 balance of the pool
    /// @param amount1 The delta of the token1 balance of the pool
    /// @param sqrtPriceX96 The sqrt(price) of the pool after the swap, as a Q64.96
    /// @param liquidity The liquidity of the pool after the swap
    /// @param tick The log base 1.0001 of price of the pool after the swap
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    /// @notice Emitted by the pool for any flashes of token0/token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the tokens from flash
    /// @param amount0 The amount of token0 that was flashed
    /// @param amount1 The amount of token1 that was flashed
    /// @param paid0 The amount of token0 paid for the flash, which can exceed the amount0 plus the fee
    /// @param paid1 The amount of token1 paid for the flash, which can exceed the amount1 plus the fee
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );

    /// @notice Emitted by the pool for increases to the number of observations that can be stored
    /// @dev observationCardinalityNext is not the observation cardinality until an observation is written at the index
    /// just before a mint/swap/burn.
    /// @param observationCardinalityNextOld The previous value of the next observation cardinality
    /// @param observationCardinalityNextNew The updated value of the next observation cardinality
    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld,
        uint16 observationCardinalityNextNew
    );

    /// @notice Emitted when the protocol fee is changed by the pool
    /// @param feeProtocol0Old The previous value of the token0 protocol fee
    /// @param feeProtocol1Old The previous value of the token1 protocol fee
    /// @param feeProtocol0New The updated value of the token0 protocol fee
    /// @param feeProtocol1New The updated value of the token1 protocol fee
    event SetFeeProtocol(uint8 feeProtocol0Old, uint8 feeProtocol1Old, uint8 feeProtocol0New, uint8 feeProtocol1New);

    /// @notice Emitted when the collected protocol fees are withdrawn by the factory owner
    /// @param sender The address that collects the protocol fees
    /// @param recipient The address that receives the collected protocol fees
    /// @param amount0 The amount of token0 protocol fees that is withdrawn
    /// @param amount0 The amount of token1 protocol fees that is withdrawn
    event CollectProtocol(address indexed sender, address indexed recipient, uint128 amount0, uint128 amount1);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Pool state that never changes
/// @notice These parameters are fixed for a pool forever, i.e., the methods will always return the same values
interface IUniswapV3PoolImmutables {
    /// @notice The contract that deployed the pool, which must adhere to the IUniswapV3Factory interface
    /// @return The contract address
    function factory() external view returns (address);

    /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (address);

    /// @notice The pool's fee in hundredths of a bip, i.e. 1e-6
    /// @return The fee
    function fee() external view returns (uint24);

    /// @notice The pool tick spacing
    /// @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
    /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
    /// This value is an int24 to avoid casting even though it is always positive.
    /// @return The tick spacing
    function tickSpacing() external view returns (int24);

    /// @notice The maximum amount of position liquidity that can use any tick in the range
    /// @dev This parameter is enforced per tick to prevent liquidity from overflowing a uint128 at any point, and
    /// also prevents out-of-range liquidity from being used to prevent adding in-range liquidity to a pool
    /// @return The max amount of liquidity per tick
    function maxLiquidityPerTick() external view returns (uint128);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Permissioned pool actions
/// @notice Contains pool methods that may only be called by the factory owner
interface IUniswapV3PoolOwnerActions {
    /// @notice Set the denominator of the protocol's % share of the fees
    /// @param feeProtocol0 new protocol fee for token0 of the pool
    /// @param feeProtocol1 new protocol fee for token1 of the pool
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external;

    /// @notice Collect the protocol fee accrued to the pool
    /// @param recipient The address to which collected protocol fees should be sent
    /// @param amount0Requested The maximum amount of token0 to send, can be 0 to collect fees in only token1
    /// @param amount1Requested The maximum amount of token1 to send, can be 0 to collect fees in only token0
    /// @return amount0 The protocol fee collected in token0
    /// @return amount1 The protocol fee collected in token1
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Pool state that can change
/// @notice These methods compose the pool's state, and can change with any frequency including multiple times
/// per transaction
interface IUniswapV3PoolState {
    /// @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
    /// when accessed externally.
    /// @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
    /// tick The current tick of the pool, i.e. according to the last tick transition that was run.
    /// This value may not always be equal to SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96) if the price is on a tick
    /// boundary.
    /// observationIndex The index of the last oracle observation that was written,
    /// observationCardinality The current maximum number of observations stored in the pool,
    /// observationCardinalityNext The next maximum number of observations, to be updated when the observation.
    /// feeProtocol The protocol fee for both tokens of the pool.
    /// Encoded as two 4 bit values, where the protocol fee of token1 is shifted 4 bits and the protocol fee of token0
    /// is the lower 4 bits. Used as the denominator of a fraction of the swap fee, e.g. 4 means 1/4th of the swap fee.
    /// unlocked Whether the pool is currently locked to reentrancy
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    /// @notice The fee growth as a Q128.128 fees of token0 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal0X128() external view returns (uint256);

    /// @notice The fee growth as a Q128.128 fees of token1 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal1X128() external view returns (uint256);

    /// @notice The amounts of token0 and token1 that are owed to the protocol
    /// @dev Protocol fees will never exceed uint128 max in either token
    function protocolFees() external view returns (uint128 token0, uint128 token1);

    /// @notice The currently in range liquidity available to the pool
    /// @dev This value has no relationship to the total liquidity across all ticks
    function liquidity() external view returns (uint128);

    /// @notice Look up information about a specific tick in the pool
    /// @param tick The tick to look up
    /// @return liquidityGross the total amount of position liquidity that uses the pool either as tick lower or
    /// tick upper,
    /// liquidityNet how much liquidity changes when the pool price crosses the tick,
    /// feeGrowthOutside0X128 the fee growth on the other side of the tick from the current tick in token0,
    /// feeGrowthOutside1X128 the fee growth on the other side of the tick from the current tick in token1,
    /// tickCumulativeOutside the cumulative tick value on the other side of the tick from the current tick
    /// secondsPerLiquidityOutsideX128 the seconds spent per liquidity on the other side of the tick from the current tick,
    /// secondsOutside the seconds spent on the other side of the tick from the current tick,
    /// initialized Set to true if the tick is initialized, i.e. liquidityGross is greater than 0, otherwise equal to false.
    /// Outside values can only be used if the tick is initialized, i.e. if liquidityGross is greater than 0.
    /// In addition, these values are only relative and must be used only in comparison to previous snapshots for
    /// a specific position.
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    /// @notice Returns 256 packed tick initialized boolean values. See TickBitmap for more information
    function tickBitmap(int16 wordPosition) external view returns (uint256);

    /// @notice Returns the information about a position by the position's key
    /// @param key The position's key is a hash of a preimage composed by the owner, tickLower and tickUpper
    /// @return _liquidity The amount of liquidity in the position,
    /// Returns feeGrowthInside0LastX128 fee growth of token0 inside the tick range as of the last mint/burn/poke,
    /// Returns feeGrowthInside1LastX128 fee growth of token1 inside the tick range as of the last mint/burn/poke,
    /// Returns tokensOwed0 the computed amount of token0 owed to the position as of the last mint/burn/poke,
    /// Returns tokensOwed1 the computed amount of token1 owed to the position as of the last mint/burn/poke
    function positions(bytes32 key)
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    /// @notice Returns data about a specific observation index
    /// @param index The element of the observations array to fetch
    /// @dev You most likely want to use #observe() instead of this method to get an observation as of some amount of time
    /// ago, rather than at a specific index in the array.
    /// @return blockTimestamp The timestamp of the observation,
    /// Returns tickCumulative the tick multiplied by seconds elapsed for the life of the pool as of the observation timestamp,
    /// Returns secondsPerLiquidityCumulativeX128 the seconds per in range liquidity for the life of the pool as of the observation timestamp,
    /// Returns initialized whether the observation has been initialized and the values are safe to use
    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0;

import "../libraries/FullMath.sol";
import "../libraries/FixedPoint96.sol";

/// @title Liquidity amount functions
/// @notice Provides functions for computing liquidity amounts from token amounts and prices
library LiquidityAmounts {
    function toUint128(uint256 x) private pure returns (uint128 y) {
        require((y = uint128(x)) == x);
    }

    /// @notice Computes the amount of liquidity received for a given amount of token0 and price range
    /// @dev Calculates amount0 * (sqrt(upper) * sqrt(lower)) / (sqrt(upper) - sqrt(lower)).
    /// @param sqrtRatioAX96 A sqrt price
    /// @param sqrtRatioBX96 Another sqrt price
    /// @param amount0 The amount0 being sent in
    /// @return liquidity The amount of returned liquidity
    function getLiquidityForAmount0(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96)
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        uint256 intermediate = FullMath.mulDiv(
            sqrtRatioAX96,
            sqrtRatioBX96,
            FixedPoint96.Q96
        );
        return
            toUint128(
                FullMath.mulDiv(
                    amount0,
                    intermediate,
                    sqrtRatioBX96 - sqrtRatioAX96
                )
            );
    }

    /// @notice Computes the amount of liquidity received for a given amount of token1 and price range
    /// @dev Calculates amount1 / (sqrt(upper) - sqrt(lower)).
    /// @param sqrtRatioAX96 A sqrt price
    /// @param sqrtRatioBX96 Another sqrt price
    /// @param amount1 The amount1 being sent in
    /// @return liquidity The amount of returned liquidity
    function getLiquidityForAmount1(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96)
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        return
            toUint128(
                FullMath.mulDiv(
                    amount1,
                    FixedPoint96.Q96,
                    sqrtRatioBX96 - sqrtRatioAX96
                )
            );
    }

    /// @notice Computes the maximum amount of liquidity received for a given amount of token0, token1, the current
    /// pool prices and the prices at the tick boundaries
    function getLiquidityForAmounts(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96)
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96) {
            liquidity = getLiquidityForAmount0(
                sqrtRatioAX96,
                sqrtRatioBX96,
                amount0
            );
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            uint128 liquidity0 = getLiquidityForAmount0(
                sqrtRatioX96,
                sqrtRatioBX96,
                amount0
            );
            uint128 liquidity1 = getLiquidityForAmount1(
                sqrtRatioAX96,
                sqrtRatioX96,
                amount1
            );

            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        } else {
            liquidity = getLiquidityForAmount1(
                sqrtRatioAX96,
                sqrtRatioBX96,
                amount1
            );
        }
    }

    /// @notice Computes the amount of token0 for a given amount of liquidity and a price range
    /// @param sqrtRatioAX96 A sqrt price
    /// @param sqrtRatioBX96 Another sqrt price
    /// @param liquidity The liquidity being valued
    /// @return amount0 The amount0
    function getAmount0ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        if (sqrtRatioAX96 > sqrtRatioBX96)
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return (
            (uint256(liquidity) << FixedPoint96.RESOLUTION) / 1e6 *
            (sqrtRatioBX96 - sqrtRatioAX96) /
            sqrtRatioBX96 / 
            sqrtRatioAX96 * 1e6
        );
    }

    /// @notice Computes the amount of token1 for a given amount of liquidity and a price range
    /// @param sqrtRatioAX96 A sqrt price
    /// @param sqrtRatioBX96 Another sqrt price
    /// @param liquidity The liquidity being valued
    /// @return amount1 The amount1
    function getAmount1ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96)
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return
            FullMath.mulDiv(
                liquidity,
                sqrtRatioBX96 - sqrtRatioAX96,
                FixedPoint96.Q96
            );
    }

    /// @notice Computes the token0 and token1 value for a given amount of liquidity, the current
    /// pool prices and the prices at the tick boundaries
    function getAmountsForLiquidity(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96)
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96) {
            amount0 = getAmount0ForLiquidity(
                sqrtRatioAX96,
                sqrtRatioBX96,
                liquidity
            );
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            amount0 = getAmount0ForLiquidity(
                sqrtRatioX96,
                sqrtRatioBX96,
                liquidity
            );
            amount1 = getAmount1ForLiquidity(
                sqrtRatioAX96,
                sqrtRatioX96,
                liquidity
            );
        } else {
            amount1 = getAmount1ForLiquidity(
                sqrtRatioAX96,
                sqrtRatioBX96,
                liquidity
            );
        }
    }
}

// SPDX-License-Identifier: BSD-3-Clause
abstract contract IRouter {
    function swapExactTokensForTokensSimple(
        uint amountIn,
        uint amountOutMin,
        address tokenFrom,
        address tokenTo,
        bool stable,
        address to,
        uint deadline
    ) external virtual returns (uint[] memory amounts);
}