// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/extensions/IERC20Metadata.sol";

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
pragma solidity ^0.8.19;

import {IExchangeAdapter} from "./../../interfaces/IExchangeAdapter.sol";
import {IBeefyVaultV6} from "./IBeefyVault.sol";
import "./../../interfaces/IVelodromePool.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "./../../interfaces/IWrappedEther.sol";
import "./../../interfaces/IPriceRouterV2.sol";

interface IBeefyZap {
    function beefIn(
        address beefyVault,
        uint256 tokenAmountOutMin,
        address tokenIn,
        uint256 tokenInAmount
    ) external;

    function beefOutAndSwap(
        address beefyVault,
        uint256 withdrawAmount,
        address desiredToken,
        uint256 desiredTokenOutMin
    ) external;
}

contract BeefyUniversalAdapter is IExchangeAdapter {
    IWrappedEther public constant WETH =
        IWrappedEther(0x4200000000000000000000000000000000000006);
    IPriceFeedRouterV2 public constant PRICE_ROUTER =
        IPriceFeedRouterV2(0x7E6FD319A856A210b9957Cd6490306995830aD25);
    uint256 public constant MINIMUM_BEEF_IN = 1000;

    event NeedPriceFeed(address indexed token);

    // Needs extra approval of the opposite token in Velodrome pool
    // 0x6012856e  =>  executeSwap(address,address,address,uint256)
    function executeSwap(
        address pool,
        address fromToken,
        address toToken,
        uint256 amount
    ) external payable returns (uint256) {
        if (isBeefyVault(toToken)) {
            address oppositeToken = getOppositeToken(toToken, fromToken);

            (uint256 originBalance, uint256 oppositeBalance) = beefInAndWrap(
                pool,
                toToken,
                fromToken,
                oppositeToken,
                amount
            );

            loop(
                pool,
                fromToken,
                oppositeToken,
                originBalance,
                oppositeBalance,
                toToken
            );

            originBalance = IERC20(fromToken).balanceOf(address(this));
            oppositeBalance = IERC20(oppositeToken).balanceOf(address(this));

            if (originBalance > 0) {
                IERC20(fromToken).transfer(msg.sender, originBalance);
            }

            if (oppositeBalance > 0) {
                IERC20(oppositeToken).transfer(msg.sender, oppositeBalance);
            }

            return IERC20(toToken).balanceOf(address(this));
        } else if (isBeefyVault(fromToken)) {
            address oppositeToken = getOppositeToken(fromToken, toToken);

            uint256 result = beefOutAndWrap(pool, fromToken, toToken, amount);

            uint256 originBalance = IERC20(fromToken).balanceOf(address(this));
            uint256 oppositeBalance = IERC20(oppositeToken).balanceOf(
                address(this)
            );

            if (originBalance > 0) {
                IERC20(fromToken).transfer(msg.sender, originBalance);
            }

            if (oppositeBalance > 0) {
                IERC20(oppositeToken).transfer(msg.sender, oppositeBalance);
            }

            return result;
        } else {
            revert("BeefyUniversalAdapter: cant swap");
        }
    }

    function loop(
        address pool,
        address originToken,
        address oppositeToken,
        uint256 originBalance,
        uint256 oppositeBalance,
        address beefyToken
    ) private {
        if (originBalance == 0 && oppositeBalance == 0) {
            return;
        }

        (uint256 priceOrigin, uint8 priceDecimalsOrigin) = tryGetTokenPrice(
            originToken,
            originBalance
        );
        (uint256 priceOpposite, uint8 priceDecimalsOpposite) = tryGetTokenPrice(
            oppositeToken,
            oppositeBalance
        );

        uint256 priceOriginGoal = 10 ** (priceDecimalsOrigin - 1);
        uint256 priceOppositeGoal = 10 ** (priceDecimalsOpposite - 1);

        for (uint256 i = 0; i < 7; i++) {
            if (
                (priceOrigin < priceOriginGoal && priceDecimalsOrigin != 1) &&
                (priceOpposite < priceOppositeGoal &&
                    priceDecimalsOpposite != 1)
            ) {
                return;
            }
            bool investOpposite;
            if (
                priceDecimalsOrigin > priceDecimalsOpposite &&
                priceOrigin != 0 &&
                priceOpposite != 0
            ) {
                uint256 priceOppositeSameDecimals = priceOpposite *
                    (10 ** (priceDecimalsOrigin - priceDecimalsOpposite));

                investOpposite = priceOppositeSameDecimals > priceOrigin;
            } else if (
                priceDecimalsOrigin < priceDecimalsOpposite &&
                priceOrigin != 0 &&
                priceOpposite != 0
            ) {
                uint256 priceOriginSameDecimals = priceOrigin *
                    (10 ** (priceDecimalsOpposite - priceDecimalsOrigin));

                investOpposite = priceOpposite > priceOriginSameDecimals;
            } else {
                // Normally this case should not happen.
                // This protects from 0 value beefIn
                investOpposite = oppositeBalance > originBalance;
            }

            uint256 depositAmount = investOpposite
                ? oppositeBalance
                : originBalance;

            if (depositAmount < MINIMUM_BEEF_IN) {
                return;
            }

            (
                uint256 investedAmount,
                uint256 oppositeInvestedAmount
            ) = beefInAndWrap(
                    pool,
                    beefyToken,
                    investOpposite ? oppositeToken : originToken,
                    investOpposite ? originToken : oppositeToken,
                    depositAmount
                );

            oppositeBalance = investOpposite
                ? investedAmount
                : oppositeInvestedAmount;
            originBalance = investOpposite
                ? oppositeInvestedAmount
                : investedAmount;

            (priceOrigin, priceDecimalsOrigin) = tryGetTokenPrice(
                originToken,
                originBalance
            );
            (priceOpposite, priceDecimalsOpposite) = tryGetTokenPrice(
                oppositeToken,
                oppositeBalance
            );
        }
    }

    function tryGetTokenPrice(
        address token,
        uint256 amount
    ) private returns (uint256, uint8) {
        try PRICE_ROUTER.getPriceOfAmount(token, amount, 0) returns (
            uint256 value,
            uint8 decimals
        ) {
            return (value, decimals);
        } catch {
            emit NeedPriceFeed(token);
            return (0, 1);
        }
    }

    function getOppositeToken(
        address beefyVault,
        address originToken
    ) private view returns (address) {
        IVelodromePool veloPool = IVelodromePool(
            IBeefyVaultV6(beefyVault).want()
        );
        address token0 = veloPool.token0();
        address token1 = veloPool.token1();

        return (token0 == originToken) ? token1 : token0;
    }

    function beefInAndWrap(
        address pool,
        address beefyToken,
        address from,
        address oppositeFrom,
        uint256 amount
    ) private returns (uint256 fromAmount, uint256 oppositeFromAmount) {
        IBeefyZap(pool).beefIn(beefyToken, 0, from, amount);
        wrap(from, oppositeFrom);

        fromAmount = IERC20(from).balanceOf(address(this));
        oppositeFromAmount = IERC20(oppositeFrom).balanceOf(address(this));
    }

    function beefOutAndWrap(
        address pool,
        address beefyToken,
        address to,
        uint256 amount
    ) private returns (uint256) {
        IBeefyZap(pool).beefOutAndSwap(beefyToken, amount, to, 0);
        wrap(to, address(0));

        return IERC20(to).balanceOf(address(this));
    }

    function wrap(address tokenA, address tokenB) private {
        uint256 balance = address(this).balance;
        if (
            (tokenA == address(WETH) || tokenB == address(WETH)) && balance > 0
        ) {
            WETH.deposit{value: balance}();
        }
    }

    function isBeefyVault(address vaultAddress) public view returns (bool) {
        bytes memory symbol = bytes(IERC20Metadata(vaultAddress).symbol());

        if (
            symbol[0] == bytes1("m") &&
            symbol[1] == bytes1("o") &&
            symbol[2] == bytes1("o")
        ) {
            try IBeefyVaultV6(vaultAddress).getPricePerFullShare() returns (
                uint256
            ) {
                return true;
            } catch {
                return false;
            }
        } else {
            return false;
        }
    }

    // 0x73ec962e  =>  enterPool(address,address,uint256)
    function enterPool(
        address,
        address,
        uint256
    ) external payable returns (uint256) {
        revert("BeefyUniversalAdapter: !enter");
    }

    // 0x660cb8d4  =>  exitPool(address,address,uint256)
    function exitPool(
        address,
        address,
        uint256
    ) external payable returns (uint256) {
        revert("BeefyUniversalAdapter: !enter");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IBeefyVaultV6 {
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approvalDelay() external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function available() external view returns (uint256);

    function balance() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external returns (bool);

    function deposit(uint256 _amount) external;

    function depositAll() external;

    function earn() external;

    function getPricePerFullShare() external view returns (uint256);

    function inCaseTokensGetStuck(address _token) external;

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external returns (bool);

    function name() external view returns (string memory);

    function owner() external view returns (address);

    function proposeStrat(address _implementation) external;

    function renounceOwnership() external;

    function stratCandidate()
        external
        view
        returns (address implementation, uint256 proposedTime);

    function strategy() external view returns (address);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferOwnership(address newOwner) external;

    function upgradeStrat() external;

    function want() external view returns (address);

    function withdraw(uint256 _shares) external;

    function withdrawAll() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IExchangeAdapter {
    // 0x6012856e  =>  executeSwap(address,address,address,uint256)
    function executeSwap(
        address pool,
        address fromToken,
        address toToken,
        uint256 amount
    ) external payable returns (uint256);

    // 0x73ec962e  =>  enterPool(address,address,uint256)
    function enterPool(
        address pool,
        address fromToken,
        uint256 amount
    ) external payable returns (uint256);

    // 0x660cb8d4  =>  exitPool(address,address,uint256)
    function exitPool(
        address pool,
        address toToken,
        uint256 amount
    ) external payable returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED
// !! THIS FILE WAS AUTOGENERATED BY abi-to-sol v0.6.6. SEE SOURCE BELOW. !!
pragma solidity ^0.8.11;

interface IPriceFeedRouterV2 {
    event AdminChanged(address previousAdmin, address newAdmin);
    event BeaconUpgraded(address indexed beacon);
    event Initialized(uint8 version);
    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );
    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event Upgraded(address indexed implementation);

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function UPGRADER_ROLE() external view returns (bytes32);

    function changeUpgradeStatus(bool _status) external;

    function cryptoToUsdStrategies(address) external view returns (address);

    function decimalsConverter(
        uint256 _amount,
        uint8 _decimalsIn,
        uint8 _decimalsOut
    ) external pure returns (uint256);

    function fiatIdToUsdStrategies(uint256) external view returns (address);

    function fiatNameToFiatId(string memory) external view returns (uint256);

    function getPrice(
        address token,
        uint256 fiatId
    ) external view returns (uint256 value, uint8 decimals);

    function getPrice(
        address token,
        string memory fiatName
    ) external view returns (uint256 value, uint8 decimals);

    function getPriceOfAmount(
        address token,
        uint256 amount,
        string memory fiatName
    ) external view returns (uint256 value, uint8 decimals);

    function getPriceOfAmount(
        address token,
        uint256 amount,
        uint256 fiatId
    ) external view returns (uint256 value, uint8 decimals);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);

    function initialize(address _multiSigWallet) external;

    function proxiableUUID() external view returns (bytes32);

    function renounceRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function setCryptoStrategy(address strategy, address coin) external;

    function setFiatStrategy(
        string memory fiatSymbol,
        uint256 fiatId,
        address fiatFeed
    ) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function upgradeStatus() external view returns (bool);

    function upgradeTo(address newImplementation) external;

    function upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) external payable;
}

// THIS FILE WAS AUTOGENERATED FROM THE FOLLOWING ABI JSON:
/*
[{"inputs":[],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"previousAdmin","type":"address"},{"indexed":false,"internalType":"address","name":"newAdmin","type":"address"}],"name":"AdminChanged","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"beacon","type":"address"}],"name":"BeaconUpgraded","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint8","name":"version","type":"uint8"}],"name":"Initialized","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"bytes32","name":"previousAdminRole","type":"bytes32"},{"indexed":true,"internalType":"bytes32","name":"newAdminRole","type":"bytes32"}],"name":"RoleAdminChanged","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"RoleGranted","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"role","type":"bytes32"},{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":true,"internalType":"address","name":"sender","type":"address"}],"name":"RoleRevoked","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"implementation","type":"address"}],"name":"Upgraded","type":"event"},{"inputs":[],"name":"DEFAULT_ADMIN_ROLE","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"UPGRADER_ROLE","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bool","name":"_status","type":"bool"}],"name":"changeUpgradeStatus","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"cryptoToUsdStrategies","outputs":[{"internalType":"contract IFeedStrategy","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"_amount","type":"uint256"},{"internalType":"uint8","name":"_decimalsIn","type":"uint8"},{"internalType":"uint8","name":"_decimalsOut","type":"uint8"}],"name":"decimalsConverter","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"pure","type":"function"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"fiatIdToUsdStrategies","outputs":[{"internalType":"contract IFeedStrategy","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"string","name":"","type":"string"}],"name":"fiatNameToFiatId","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"token","type":"address"},{"internalType":"uint256","name":"fiatId","type":"uint256"}],"name":"getPrice","outputs":[{"internalType":"uint256","name":"value","type":"uint256"},{"internalType":"uint8","name":"decimals","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"token","type":"address"},{"internalType":"string","name":"fiatName","type":"string"}],"name":"getPrice","outputs":[{"internalType":"uint256","name":"value","type":"uint256"},{"internalType":"uint8","name":"decimals","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"token","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"string","name":"fiatName","type":"string"}],"name":"getPriceOfAmount","outputs":[{"internalType":"uint256","name":"value","type":"uint256"},{"internalType":"uint8","name":"decimals","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"token","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"uint256","name":"fiatId","type":"uint256"}],"name":"getPriceOfAmount","outputs":[{"internalType":"uint256","name":"value","type":"uint256"},{"internalType":"uint8","name":"decimals","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"}],"name":"getRoleAdmin","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"grantRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"hasRole","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_multiSigWallet","type":"address"}],"name":"initialize","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"proxiableUUID","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"renounceRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"revokeRole","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"strategy","type":"address"},{"internalType":"address","name":"coin","type":"address"}],"name":"setCryptoStrategy","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"string","name":"fiatSymbol","type":"string"},{"internalType":"uint256","name":"fiatId","type":"uint256"},{"internalType":"address","name":"fiatFeed","type":"address"}],"name":"setFiatStrategy","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes4","name":"interfaceId","type":"bytes4"}],"name":"supportsInterface","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"upgradeStatus","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"newImplementation","type":"address"}],"name":"upgradeTo","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"newImplementation","type":"address"},{"internalType":"bytes","name":"data","type":"bytes"}],"name":"upgradeToAndCall","outputs":[],"stateMutability":"payable","type":"function"}]
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IVelodromePool {
    struct Observation {
        uint timestamp;
        uint reserve0Cumulative;
        uint reserve1Cumulative;
    }

    function allowance(address, address) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    function blockTimestampLast() external view returns (uint256);

    function burn(
        address to
    ) external returns (uint256 amount0, uint256 amount1);

    function claimFees() external returns (uint256 claimed0, uint256 claimed1);

    function claimable0(address) external view returns (uint256);

    function claimable1(address) external view returns (uint256);

    function current(
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    function currentCumulativePrices()
        external
        view
        returns (
            uint256 reserve0Cumulative,
            uint256 reserve1Cumulative,
            uint256 blockTimestamp
        );

    function decimals() external view returns (uint8);

    function fees() external view returns (address);

    function getAmountOut(
        uint256 amountIn,
        address tokenIn
    ) external view returns (uint256);

    function getReserves()
        external
        view
        returns (
            uint256 _reserve0,
            uint256 _reserve1,
            uint256 _blockTimestampLast
        );

    function index0() external view returns (uint256);

    function index1() external view returns (uint256);

    function lastObservation() external view returns (Observation memory);

    function metadata()
        external
        view
        returns (
            uint256 dec0,
            uint256 dec1,
            uint256 r0,
            uint256 r1,
            bool st,
            address t0,
            address t1
        );

    function mint(address to) external returns (uint256 liquidity);

    function name() external view returns (string memory);

    function nonces(address) external view returns (uint256);

    function observationLength() external view returns (uint256);

    function observations(
        uint256
    )
        external
        view
        returns (
            uint256 timestamp,
            uint256 reserve0Cumulative,
            uint256 reserve1Cumulative
        );

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function prices(
        address tokenIn,
        uint256 amountIn,
        uint256 points
    ) external view returns (uint256[] memory);

    function quote(
        address tokenIn,
        uint256 amountIn,
        uint256 granularity
    ) external view returns (uint256 amountOut);

    function reserve0() external view returns (uint256);

    function reserve0CumulativeLast() external view returns (uint256);

    function reserve1() external view returns (uint256);

    function reserve1CumulativeLast() external view returns (uint256);

    function sample(
        address tokenIn,
        uint256 amountIn,
        uint256 points,
        uint256 window
    ) external view returns (uint256[] memory);

    function skim(address to) external;

    function stable() external view returns (bool);

    function supplyIndex0(address) external view returns (uint256);

    function supplyIndex1(address) external view returns (uint256);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes memory data
    ) external;

    function symbol() external view returns (string memory);

    function sync() external;

    function token0() external view returns (address);

    function token1() external view returns (address);

    function tokens() external view returns (address, address);

    function totalSupply() external view returns (uint256);

    function transfer(address dst, uint256 amount) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IWrappedEther {
    function name() external view returns (string memory);

    function approve(address guy, uint256 wad) external returns (bool);

    function totalSupply() external view returns (uint256);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);

    function withdraw(uint256 wad) external;

    function decimals() external view returns (uint8);

    function balanceOf(address) external view returns (uint256);

    function symbol() external view returns (string memory);

    function transfer(address dst, uint256 wad) external returns (bool);

    function deposit() external payable;

    function allowance(address, address) external view returns (uint256);
}