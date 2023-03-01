// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface ISwap {
    // pool data view functions
    function getA() external view returns (uint256);

    function getAPrecise() external view returns (uint256);

    function getToken(uint8 index) external view returns (IERC20);

    function getTokenIndex(address tokenAddress) external view returns (uint8);

    function getTokenBalance(uint8 index) external view returns (uint256);

    function getVirtualPrice() external view returns (uint256);

    function swapStorage()
        external
        view
        returns (
            uint256 initialA,
            uint256 futureA,
            uint256 initialATime,
            uint256 futureATime,
            uint256 swapFee,
            uint256 adminFee,
            address lpToken
        );

    // min return calculation functions
    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256);

    function calculateTokenAmount(uint256[] calldata amounts, bool deposit) external view returns (uint256);

    function calculateRemoveLiquidity(uint256 amount) external view returns (uint256[] memory);

    function calculateRemoveLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex)
        external
        view
        returns (uint256 availableTokenAmount);

    // state modifying functions
    function initialize(
        IERC20[] memory pooledTokens,
        uint8[] memory decimals,
        string memory lpTokenName,
        string memory lpTokenSymbol,
        uint256 a,
        uint256 fee,
        uint256 adminFee,
        address lpTokenTargetAddress
    ) external;

    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256);

    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minToMint,
        uint256 deadline
    ) external returns (uint256);

    function removeLiquidity(
        uint256 amount,
        uint256[] calldata minAmounts,
        uint256 deadline
    ) external returns (uint256[] memory);

    function removeLiquidityOneToken(
        uint256 tokenAmount,
        uint8 tokenIndex,
        uint256 minAmount,
        uint256 deadline
    ) external returns (uint256);

    function removeLiquidityImbalance(
        uint256[] calldata amounts,
        uint256 maxBurnAmount,
        uint256 deadline
    ) external returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../libraries/BridgeStructs.sol";

interface ISwapAdapter {
    /**
     * @notice Performs a tokenIn -> tokenOut swap, according to the provided params.
     * If tokenIn is ETH_ADDRESS, this method should be invoked with `msg.value = amountIn`.
     * If tokenIn is ERC20, the tokens should be already transferred to this contract (using `msg.value = 0`).
     * If tokenOut is ETH_ADDRESS, native ETH will be sent to the recipient (be aware of potential reentrancy).
     * If tokenOut is ERC20, the tokens will be transferred to the recipient.
     * @dev Contracts implementing {ISwapAdapter} interface are required to enforce the above restrictions.
     * On top of that, they must ensure that exactly `amountOut` worth of `tokenOut` is transferred to the recipient.
     * Swap deadline and slippage is checked outside of this contract.
     * @param to            Address to receive the swapped token
     * @param tokenIn       Token to sell (use ETH_ADDRESS to start from native ETH)
     * @param amountIn      Amount of tokens to sell
     * @param tokenOut      Token to buy (use ETH_ADDRESS to end with native ETH)
     * @param rawParams     Additional swap parameters
     * @return amountOut    Amount of bought tokens
     */
    function adapterSwap(
        address to,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        bytes calldata rawParams
    ) external payable returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../libraries/BridgeStructs.sol";

interface ISwapQuoter {
    function findConnectedTokens(LimitedToken[] memory tokensIn, address tokenOut)
        external
        view
        returns (uint256 amountFound, bool[] memory isConnected);

    function getAmountOut(
        LimitedToken memory tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (SwapQuery memory query);

    function allPools() external view returns (Pool[] memory pools);

    function poolsAmount() external view returns (uint256 tokens);

    function poolInfo(address pool) external view returns (uint256 tokens, address lpToken);

    function poolTokens(address pool) external view returns (PoolToken[] memory tokens);

    function calculateAddLiquidity(address pool, uint256[] memory amounts) external view returns (uint256 amountOut);

    function calculateSwap(
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256 amountOut);

    function calculateRemoveLiquidity(address pool, uint256 amount) external view returns (uint256[] memory amountsOut);

    function calculateWithdrawOneToken(
        address pool,
        uint256 tokenAmount,
        uint8 tokenIndex
    ) external view returns (uint256 amountOut);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

interface ISynapseBridge {
    using SafeERC20 for IERC20;

    function deposit(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external;

    function depositAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    ) external;

    function redeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external;

    function redeemv2(
        bytes32 to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external;

    function redeemAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    ) external;

    function redeemAndRemove(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 liqTokenIndex,
        uint256 liqMinAmount,
        uint256 liqDeadline
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.4.0;

interface IWETH9 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function balanceOf(address) external view returns (uint256);

    function allowance(address, address) external view returns (uint256);

    receive() external payable;

    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function totalSupply() external view returns (uint256);

    function approve(address guy, uint256 wad) external returns (bool);

    function transfer(address dst, uint256 wad) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/// @notice Struct representing a request for SynapseRouter.
/// @dev tokenIn is supplied separately.
/// @param swapAdapter      Adapter address that will perform the swap. Address(0) specifies a "no swap" query.
/// @param tokenOut         Token address to swap to.
/// @param minAmountOut     Minimum amount of tokens to receive after the swap, or tx will be reverted.
/// @param deadline         Latest timestamp for when the transaction needs to be executed, or tx will be reverted.
/// @param rawParams        ABI-encoded params for the swap that will be passed to `swapAdapter`.
///                         Should be SynapseParams for swaps via SynapseAdapter.
struct SwapQuery {
    address swapAdapter;
    address tokenOut;
    uint256 minAmountOut;
    uint256 deadline;
    bytes rawParams;
}

/// @notice Struct representing parameters for swapping via SynapseAdapter.
/// @param action           Action that SynapseAdapter needs to perform.
/// @param pool             Liquidity pool that will be used for Swap/AddLiquidity/RemoveLiquidity actions.
/// @param tokenIndexFrom   Token index to swap from. Used for swap/addLiquidity actions.
/// @param tokenIndexTo     Token index to swap to. Used for swap/removeLiquidity actions.
struct SynapseParams {
    Action action;
    address pool;
    uint8 tokenIndexFrom;
    uint8 tokenIndexTo;
}

/// @notice All possible actions that SynapseAdapter could perform.
enum Action {
    Swap, // swap between two pools tokens
    AddLiquidity, // add liquidity in a form of a single pool token
    RemoveLiquidity, // remove liquidity in a form of a single pool token
    HandleEth // ETH <> WETH interaction
}

/// @notice Struct representing a token, and the available Actions for performing a swap.
/// @param actionMask   Bitmask representing what actions (see ActionLib) are available for swapping a token
/// @param token        Token address
struct LimitedToken {
    uint256 actionMask;
    address token;
}

/// @notice Struct representing a bridge token. Used as the return value in view functions.
/// @param symbol   Bridge token symbol: unique token ID consistent among all chains
/// @param token    Bridge token address
struct BridgeToken {
    string symbol;
    address token;
}

/// @notice Struct representing how pool tokens are stored by `SwapQuoter`.
/// @param isWeth   Whether the token represents Wrapped ETH.
/// @param token    Token address.
struct PoolToken {
    bool isWeth;
    address token;
}

/// @notice Struct representing a request for a swap quote from a bridge token.
/// @dev tokenOut is passed externally
/// @param symbol   Bridge token symbol: unique token ID consistent among all chains
/// @param amountIn Amount of bridge token to start with, before the bridge fee is applied
struct DestRequest {
    string symbol;
    uint256 amountIn;
}

/// @notice Struct representing a liquidity pool. Used as the return value in view functions.
/// @param pool         Pool address.
/// @param lpToken      Address of pool's LP token.
/// @param tokens       List of pool's tokens.
struct Pool {
    address pool;
    address lpToken;
    PoolToken[] tokens;
}

/// @notice Library for dealing with bit masks, describing what Actions are available.
library ActionLib {
    /// @notice Returns a bitmask with all possible actions set to True.
    function allActions() internal pure returns (uint256 actionMask) {
        actionMask = type(uint256).max;
    }

    /// @notice Returns whether the given action is set to True in the bitmask.
    function includes(uint256 actionMask, Action action) internal pure returns (bool) {
        return actionMask & mask(action) != 0;
    }

    /// @notice Returns a bitmask with only the given action set to True.
    function mask(Action action) internal pure returns (uint256) {
        return 1 << uint256(action);
    }

    /// @notice Returns a bitmask with only two given actions set to True.
    function mask(Action a, Action b) internal pure returns (uint256) {
        return mask(a) | mask(b);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./BridgeStructs.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

/**
 * Library to unify handling of ETH/WETH and ERC20 tokens.
 */
library UniversalToken {
    using SafeERC20 for IERC20;

    address internal constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 private constant MAX_UINT = type(uint256).max;

    /// @notice Returns token balance for the given account.
    function universalBalanceOf(address token, address account) internal view returns (uint256) {
        if (token == ETH_ADDRESS) {
            return account.balance;
        } else {
            return IERC20(token).balanceOf(account);
        }
    }

    /// @notice Compares two tokens. ETH_ADDRESS and WETH are deemed equal.
    function universalEquals(address token, PoolToken memory poolToken) internal pure returns (bool) {
        if (token == ETH_ADDRESS) {
            return poolToken.isWeth;
        } else {
            return token == poolToken.token;
        }
    }

    function universalApproveInfinity(address token, address spender) internal {
        // ETH Chad doesn't require your approval
        if (token == ETH_ADDRESS) return;
        // No need to approve own tokens
        if (spender == address(this)) return;
        uint256 allowance = IERC20(token).allowance(address(this), spender);
        // Set allowance to MAX_UINT if needed
        if (allowance != MAX_UINT) {
            // if allowance is neither zero nor infinity, reset if first
            if (allowance != 0) {
                IERC20(token).safeApprove(spender, 0);
            }
            IERC20(token).safeApprove(spender, MAX_UINT);
        }
    }

    /// @notice Transfers tokens to the given account. Reverts if transfer is not successful.
    /// @dev This might trigger fallback, if ETH is transferred to the contract.
    /// Make sure this can not lead to reentrancy attacks.
    function universalTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // Don't do anything, if need to send tokens to this address
        if (to == address(this)) return;
        if (token == ETH_ADDRESS) {
            /// @dev Note: this can potentially lead to executing code in `to`.
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = to.call{value: value}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(token).safeTransfer(to, value);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

abstract contract LocalBridgeConfig is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;

    /**
     * @notice Indicates the type of the supported bridge token on the local chain.
     * - TokenType.Redeem: token is burnt in order to initiate a bridge tx (bridge.redeem)
     * - TokenType.Deposit: token is locked in order to initiate a bridge tx (bridge.deposit)
     */
    enum TokenType {
        Redeem,
        Deposit
    }

    /**
     * @notice Config for a supported bridge token.
     * @dev Some of the tokens require a wrapper token to make them conform SynapseERC20 interface.
     * In these cases, `bridgeToken` will feature a different address.
     * Otherwise, the token address is saved.
     * @param tokenType     Method of bridging for the token: Redeem or Deposit
     * @param bridgeToken   Bridge token address
     */
    struct TokenConfig {
        TokenType tokenType;
        address bridgeToken;
    }

    /**
     * @notice Fee structure for a supported bridge token, optimized to fit in a single storage word.
     * @param bridgeFee     Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
     * @param minFee        Minimum fee for bridging a token to this chain, in token decimals
     * @param maxFee        Maximum fee for bridging a token to this chain, in token decimals
     */
    struct FeeStructure {
        uint40 bridgeFee;
        uint104 minFee;
        uint112 maxFee;
    }

    /**
     * @notice Struct defining a supported bridge token. This is not supposed to be stored on-chain,
     * so this is not optimized in terms of storage words.
     * @param id            ID for token used in BridgeConfigV3
     * @param token         "End" token, supported by SynapseBridge. This is the token user is receiving/sending.
     * @param decimals      Amount ot decimals used for `token`
     * @param tokenType     Method of bridging used for the token: Redeem or Deposit.
     * @param bridgeToken   Actual token used for bridging `token`. This is the token bridge is burning/locking.
     *                      Might differ from `token`, if `token` does not conform to bridge-supported interface.
     * @param bridgeFee     Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
     * @param minFee        Minimum fee for bridging a token to this chain, in token decimals
     * @param maxFee        Maximum fee for bridging a token to this chain, in token decimals
     */
    struct BridgeTokenConfig {
        string id;
        address token;
        uint256 decimals;
        LocalBridgeConfig.TokenType tokenType;
        address bridgeToken;
        uint256 bridgeFee;
        uint256 minFee;
        uint256 maxFee;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              CONSTANTS                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Denominator used to calculate the bridge fee: amount.mul(bridgeFee).div(FEE_DENOMINATOR)
    uint256 private constant FEE_DENOMINATOR = 10**10;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STORAGE                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Config for each supported token.
    /// @dev If wrapper token is required for bridging, its address is stored in `.bridgeToken`
    /// i.e. for GMX: config[GMX].bridgeToken = GMXWrapper
    mapping(address => TokenConfig) public config;
    /// @notice Fee structure for each supported token.
    /// @dev If wrapper token is required for bridging, its underlying is used as key here
    mapping(address => FeeStructure) public fee;
    /// @notice Maps bridge token address into bridge token symbol
    mapping(address => string) public tokenToSymbol;
    /// @notice Maps bridge token symbol into bridge token address
    mapping(string => address) public symbolToToken;
    /// @dev A list of all supported bridge tokens
    EnumerableSet.AddressSet internal _bridgeTokens;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              ONLY OWNER                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Adds a bridge token and its fee structure to the local config, if it was not added before.
     * @param token         "End" token, supported by SynapseBridge. This is the token user is receiving/sending.
     * @param tokenType     Method of bridging used for the token: Redeem or Deposit.
     * @param bridgeToken   Actual token used for bridging `token`. This is the token bridge is burning/locking.
     *                      Might differ from `token`, if `token` does not conform to bridge-supported interface.
     * @param bridgeFee     Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
     * @param minFee        Minimum fee for bridging a token to this chain, in token decimals
     * @param maxFee        Maximum fee for bridging a token to this chain, in token decimals
     * @return wasAdded     True, if token was added to the config
     */
    function addToken(
        string memory symbol,
        address token,
        TokenType tokenType,
        address bridgeToken,
        uint256 bridgeFee,
        uint256 minFee,
        uint256 maxFee
    ) external onlyOwner returns (bool wasAdded) {
        wasAdded = _addToken(symbol, token, tokenType, bridgeToken, bridgeFee, minFee, maxFee);
    }

    /// @notice Adds a bunch of bridge tokens and their fee structure to the local config, if it was not added before.
    function addTokens(BridgeTokenConfig[] memory tokens) external onlyOwner {
        uint256 amount = tokens.length;
        for (uint256 i = 0; i < amount; ++i) {
            BridgeTokenConfig memory token = tokens[i];
            _addToken(
                token.id,
                token.token,
                token.tokenType,
                token.bridgeToken,
                token.bridgeFee,
                token.minFee,
                token.maxFee
            );
        }
    }

    /**
     * @notice Updates the bridge config for an already added bridge token.
     * @dev Will revert if token was not added before.
     * @param token         "End" token, supported by SynapseBridge. This is the token user is receiving/sending.
     * @param tokenType     Method of bridging used for the token: Redeem or Deposit.
     * @param bridgeToken   Actual token used for bridging `token`. This is the token bridge is burning/locking.
     *                      Might differ from `token`, if `token` does not conform to bridge-supported interface.
     */
    function setTokenConfig(
        address token,
        TokenType tokenType,
        address bridgeToken
    ) external onlyOwner {
        require(config[token].bridgeToken != address(0), "Unknown token");
        _setTokenConfig(token, tokenType, bridgeToken);
    }

    /**
     * @notice Updates the fee structure for an already added bridge token.
     * @dev Will revert if token was not added before.
     * @param token         "End" token, supported by SynapseBridge. This is the token user is receiving/sending.
     * @param bridgeFee     Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
     * @param minFee        Minimum fee for bridging a token to this chain, in token decimals
     * @param maxFee        Maximum fee for bridging a token to this chain, in token decimals
     */
    function setTokenFee(
        address token,
        uint256 bridgeFee,
        uint256 minFee,
        uint256 maxFee
    ) external onlyOwner {
        require(config[token].bridgeToken != address(0), "Unknown token");
        _setTokenFee(token, bridgeFee, minFee, maxFee);
    }

    /**
     * @notice Removes tokens from the local config, and deletes the associated bridge fee structure.
     * @dev If a token requires a bridge wrapper token, use the underlying token address for removing.
     * @param token         "End" token, supported by SynapseBridge. This is the token user is receiving/sending.
     * @return wasRemoved   True, if token was removed from the config
     */
    function removeToken(address token) external onlyOwner returns (bool wasRemoved) {
        wasRemoved = _removeToken(token);
    }

    /**
     * @notice Removes a list of tokens from the local config, and deletes their associated bridge fee structure.
     * @dev If a token requires a bridge wrapper token, use the underlying token address for removing.
     * @param tokens    List of "end" tokens, supported by SynapseBridge. These are the tokens user is receiving/sending.
     */
    function removeTokens(address[] calldata tokens) external onlyOwner {
        uint256 amount = tokens.length;
        for (uint256 i = 0; i < amount; ++i) {
            _removeToken(tokens[i]);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                VIEWS                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Returns a list of all supported bridge tokens.
    function bridgeTokens() external view returns (address[] memory tokens) {
        uint256 amount = bridgeTokensAmount();
        tokens = new address[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            tokens[i] = _bridgeTokens.at(i);
        }
    }

    /// @notice Returns the amount of the supported bridge tokens.
    function bridgeTokensAmount() public view returns (uint256 amount) {
        amount = _bridgeTokens.length();
    }

    /**
     * @notice Calculates a fee for bridging a token to this chain.
     * @dev If a token requires a bridge wrapper token, use the underlying token address for getting a fee quote.
     * @param token     "End" token, supported by SynapseBridge. This is the token user is receiving/sending.
     * @param amount    Amount of tokens to bridge to this chain.
     */
    function calculateBridgeFee(address token, uint256 amount) external view returns (uint256 feeAmount) {
        feeAmount = _calculateBridgeFee(token, amount);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                 INTERNAL: ADD & REMOVE BRIDGE TOKENS                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Adds a bridge token config, if it's not present and updates its fee structure.
    /// Child contract could implement additional logic upon adding a token.
    function _addToken(
        string memory _symbol,
        address token,
        TokenType tokenType,
        address bridgeToken,
        uint256 bridgeFee,
        uint256 minFee,
        uint256 maxFee
    ) internal virtual returns (bool wasAdded) {
        wasAdded = _bridgeTokens.add(token);
        if (wasAdded) {
            // Need to save config only once. Need to use "end user" address for symbol mappings.
            _setTokenSymbol(_symbol, token);
            _setTokenConfig(token, tokenType, bridgeToken);
            _setTokenFee(token, bridgeFee, minFee, maxFee);
        }
    }

    /// @dev Sets the symbol for the bridge token
    function _setTokenSymbol(string memory symbol, address token) internal {
        // tokenToSymbol[token] is guaranteed to be empty, as token was just added
        require(bytes(symbol).length != 0, "Empty symbol");
        require(symbolToToken[symbol] == address(0), "Symbol already in use");
        symbolToToken[symbol] = token;
        tokenToSymbol[token] = symbol;
    }

    /// @dev Updates the token config for an already known bridge token.
    function _setTokenConfig(
        address token,
        TokenType tokenType,
        address bridgeToken
    ) internal {
        // Sanity checks for the provided token values
        require(token != address(0) && bridgeToken != address(0), "Token can't be zero address");
        config[token] = TokenConfig(tokenType, bridgeToken);
    }

    /// @dev Updates the fee structure for an already known bridge token.
    function _setTokenFee(
        address token,
        uint256 bridgeFee,
        uint256 minFee,
        uint256 maxFee
    ) internal {
        // Sanity checks for the provided fee values
        require(bridgeFee < FEE_DENOMINATOR, "bridgeFee >= 100%");
        require(minFee <= maxFee, "minFee > maxFee");
        fee[token] = FeeStructure(uint40(bridgeFee), uint104(minFee), uint112(maxFee));
    }

    /// @dev Removes a bridge token config along with its fee structure.
    /// Child contract could implement additional logic upon removing a token.
    function _removeToken(address token) internal virtual returns (bool wasRemoved) {
        wasRemoved = _bridgeTokens.remove(token);
        if (wasRemoved) {
            string memory symbol = tokenToSymbol[token];
            delete tokenToSymbol[token];
            delete symbolToToken[symbol];
            delete config[token];
            delete fee[token];
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL: VIEWS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Returns the amount of tokens received after applying the bridge fee.
    /// Will return 0, if bridged amount is lower than a minimum bridge fee.
    function _calculateBridgeAmountOut(address token, uint256 amount) internal view returns (uint256 amountOut) {
        uint256 feeAmount = _calculateBridgeFee(token, amount);
        if (feeAmount < amount) {
            // No need for SafeMath here
            amountOut = amount - feeAmount;
        }
        // Return 0, if fee amount >= amount
    }

    /// @dev Returns the fee for bridging a given token to this chain.
    function _calculateBridgeFee(address token, uint256 amount) internal view returns (uint256 feeAmount) {
        require(config[token].bridgeToken != address(0), "Token not supported");
        FeeStructure memory tokenFee = fee[token];
        feeAmount = amount.mul(tokenFee.bridgeFee).div(FEE_DENOMINATOR);
        if (feeAmount < tokenFee.minFee) {
            feeAmount = tokenFee.minFee;
        } else if (feeAmount > tokenFee.maxFee) {
            feeAmount = tokenFee.maxFee;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/ISwap.sol";
import "../interfaces/ISwapAdapter.sol";
import "../interfaces/ISwapQuoter.sol";
import "../interfaces/IWETH9.sol";
import "../libraries/UniversalToken.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract SynapseAdapter is Ownable, ISwapAdapter {
    using SafeERC20 for IERC20;
    using UniversalToken for address;

    uint256 internal constant MAX_UINT = type(uint256).max;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STORAGE                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Address of the local SwapQuoter contract
    ISwapQuoter public swapQuoter;

    /// @notice Receive function to enable unwrapping ETH into this contract
    receive() external payable {} // solhint-disable-line no-empty-blocks

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              OWNER ONLY                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Sets the Swap Quoter address to get the swap quotes from.
    function setSwapQuoter(ISwapQuoter _swapQuoter) external onlyOwner {
        swapQuoter = _swapQuoter;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          EXTERNAL FUNCTIONS                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Performs a tokenIn -> tokenOut swap, according to the provided params.
     * If tokenIn is ETH_ADDRESS, this method should be invoked with `msg.value = amountIn`.
     * If tokenIn is ERC20, the tokens should be already transferred to this contract (using `msg.value = 0`).
     * If tokenOut is ETH_ADDRESS, native ETH will be sent to the recipient (be aware of potential reentrancy).
     * If tokenOut is ERC20, the tokens will be transferred to the recipient.
     * @dev Contracts implementing {ISwapAdapter} interface are required to enforce the above restrictions.
     * On top of that, they must ensure that exactly `amountOut` worth of `tokenOut` is transferred to the recipient.
     * Swap deadline and slippage is checked outside of this contract.
     * @dev Applied to SynapseAdapter only:
     * Use `params.pool = address(this)` for ETH handling without swaps:
     * 1. For wrapping ETH: tokenIn = ETH_ADDRESS, tokenOut = WETH, params.pool = address(this)
     * 2. For unwrapping WETH: tokenIn = WETH, tokenOut = ETH_ADDRESS, params.pool = address(this)
     * If `params.pool != address(this)`, and ETH_ADDRESS was supplied as tokenIn or tokenOut,
     * a corresponding pool token will be treated as WETH.
     * @param to            Address to receive the swapped token
     * @param tokenIn       Token to sell (use ETH_ADDRESS to start from native ETH)
     * @param amountIn      Amount of tokens to sell
     * @param tokenOut      Token to buy (use ETH_ADDRESS to end with native ETH)
     * @param rawParams     Additional swap parameters
     * @return amountOut    Amount of bought tokens
     */
    function adapterSwap(
        address to,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        bytes calldata rawParams
    ) external payable override returns (uint256 amountOut) {
        // We define a few phases for the whole swap process.
        // (?) means the phase is optional.
        // (!) means the phase is mandatory.

        // ============================== PHASE 0(!): CHECK ALL THE PARAMS =========================
        require(tokenIn != tokenOut, "Swap tokens should differ");
        // Decode params for swapping via a Synapse pool
        SynapseParams memory params = abi.decode(rawParams, (SynapseParams));
        // Swap pool should exist, if action other than HandleEth was requested
        require(params.pool != address(0) || params.action == Action.HandleEth, "!pool");

        // ============================== PHASE 1(?): WRAP RECEIVED ETH ============================
        // tokenIn was already transferred to this contract, check if we start from native ETH
        if (tokenIn == UniversalToken.ETH_ADDRESS) {
            // Determine WETH address: this is either tokenOut (if no swap is needed),
            // or a pool token with index `tokenIndexFrom` (if swap is needed).
            tokenIn = _deriveWethAddress({token: tokenOut, params: params, isWethIn: true});
            // Wrap ETH into WETH and leave it in this contract
            _wrapETH(tokenIn, amountIn);
        } else {
            // For ERC20 tokens msg.value should be zero
            require(msg.value == 0, "Incorrect tokenIn for ETH swap");
        }
        // Either way, this contract has `amountIn` worth of `tokenIn`; tokenIn != ETH_ADDRESS

        // ============================== PHASE 2(?): PREPARE TO UNWRAP SWAPPED WETH ===============
        address tokenSwapTo = tokenOut;
        // Check if swap to native ETH was requested
        if (tokenOut == UniversalToken.ETH_ADDRESS) {
            // Determine WETH address: this is either tokenIn (if no swap is needed),
            // or a pool token with index `tokenIndexTo` (if swap is needed).
            tokenSwapTo = _deriveWethAddress({token: tokenIn, params: params, isWethIn: false});
        }
        // Either way, we need to perform tokenIn -> tokenSwapTo swap.
        // Then we need to send tokenOut to the recipient.
        // The last step includes WETH unwrapping, if tokenOut is ETH_ADDRESS

        // ============================== PHASE 3(?): PERFORM A REQUESTED SWAP =====================
        // Determine if we need to perform a swap
        if (params.action == Action.HandleEth) {
            // If no swap is required, amountOut doesn't change
            amountOut = amountIn;
        } else {
            // Approve token for spending if needed
            tokenIn.universalApproveInfinity(params.pool);
            if (params.action == Action.Swap) {
                // Perform a swap through the pool
                amountOut = _swap(ISwap(params.pool), params, amountIn, tokenSwapTo);
            } else if (params.action == Action.AddLiquidity) {
                // Add liquidity to the pool
                amountOut = _addLiquidity(ISwap(params.pool), params, amountIn, tokenSwapTo);
            } else {
                // Remove liquidity to the pool
                amountOut = _removeLiquidity(ISwap(params.pool), params, amountIn, tokenSwapTo);
            }
        }
        // Either way, this contract has `amountOut` worth of `tokenSwapTo`

        // ============================== PHASE 4(?): UNWRAP SWAPPED WETH ==========================
        // Check if swap to native ETH was requested
        if (tokenOut == UniversalToken.ETH_ADDRESS) {
            // We stored WETH address in `tokenSwapTo` previously, let's unwrap it
            _unwrapETH(tokenSwapTo, amountOut);
        }
        // Either way, we need to transfer `amountOut` worth of `tokenOut`

        // ============================== PHASE 5(!): TRANSFER SWAPPED TOKENS ======================
        tokenOut.universalTransfer(to, amountOut);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            VIEWS: QUOTES                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Finds the best pool for tokenIn -> tokenOut swap from the list of supported pools.
     * Returns the `SwapQuery` struct, that can be used on SynapseRouter.
     * minAmountOut and deadline fields will need to be adjusted based on the swap settings.
     */
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (SwapQuery memory) {
        // All actions are allowed by default
        LimitedToken memory _tokenIn = LimitedToken(ActionLib.allActions(), tokenIn);
        return swapQuoter.getAmountOut(_tokenIn, tokenOut, amountIn);
    }

    /**
     * @notice Returns the exact quote for adding liquidity to a given pool
     * in a form of a single token.
     * @param pool      The pool to add tokens to
     * @param amounts   An array of token amounts to deposit.
     *                  The amount should be in each pooled token's native precision.
     *                  If a token charges a fee on transfers, use the amount that gets transferred after the fee.
     * @return LP token amount the user will receive
     */
    function calculateAddLiquidity(address pool, uint256[] memory amounts) external view returns (uint256) {
        return swapQuoter.calculateAddLiquidity(pool, amounts);
    }

    /**
     * @notice Returns the exact quote for swapping between two given tokens.
     * @param pool              The pool to use for the swap
     * @param tokenIndexFrom    The token the user wants to sell
     * @param tokenIndexTo      The token the user wants to buy
     * @param dx                The amount of tokens the user wants to sell. If the token charges a fee on transfers,
     *                          use the amount that gets transferred after the fee.
     * @return amountOut        amount of tokens the user will receive
     */
    function calculateSwap(
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256 amountOut) {
        amountOut = swapQuoter.calculateSwap(pool, tokenIndexFrom, tokenIndexTo, dx);
    }

    /**
     * @notice Returns the exact quote for withdrawing pools tokens in a balanced way.
     * @param pool          The pool to withdraw tokens from
     * @param amount        The amount of LP tokens that would be burned on withdrawal
     * @return amountsOut   Array of token balances that the user will receive
     */
    function calculateRemoveLiquidity(address pool, uint256 amount)
        external
        view
        returns (uint256[] memory amountsOut)
    {
        amountsOut = swapQuoter.calculateRemoveLiquidity(pool, amount);
    }

    /**
     * @notice Returns the exact quote for withdrawing a single pool token.
     * @param pool          The pool to withdraw a token from
     * @param tokenAmount   The amount of LP token to burn
     * @param tokenIndex    Index of which token will be withdrawn
     * @return amountOut    Calculated amount of underlying token available to withdraw
     */
    function calculateWithdrawOneToken(
        address pool,
        uint256 tokenAmount,
        uint8 tokenIndex
    ) external view returns (uint256 amountOut) {
        amountOut = swapQuoter.calculateWithdrawOneToken(pool, tokenAmount, tokenIndex);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             VIEWS: POOLS                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Returns a list of all supported pools.
     */
    function allPools() public view returns (Pool[] memory pools) {
        pools = swapQuoter.allPools();
    }

    /**
     * @notice Returns the amount of tokens the given pool supports and the pool's LP token.
     */
    function poolInfo(address pool) public view returns (uint256, address) {
        return swapQuoter.poolInfo(pool);
    }

    /**
     * @notice Returns a list of pool tokens for the given pool.
     */
    function poolTokens(address pool) public view returns (PoolToken[] memory tokens) {
        tokens = swapQuoter.poolTokens(pool);
    }

    /**
     * @notice Returns the amount of supported pools.
     */
    function poolsAmount() public view returns (uint256 amount) {
        amount = swapQuoter.poolsAmount();
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Performs a swap through the given pool.
     * The pool token is already approved for spending.
     */
    function _swap(
        ISwap pool,
        SynapseParams memory params,
        uint256 amountIn,
        address tokenOut
    ) internal returns (uint256 amountOut) {
        // tokenOut should match the "swap to" token
        require(pool.getToken(params.tokenIndexTo) == IERC20(tokenOut), "!tokenOut");
        // amountOut and deadline are not checked in SwapAdapter
        amountOut = pool.swap({
            tokenIndexFrom: params.tokenIndexFrom,
            tokenIndexTo: params.tokenIndexTo,
            dx: amountIn,
            minDy: 0,
            deadline: MAX_UINT
        });
    }

    /**
     * @notice Adds liquidity in a form of a single token to the given pool.
     * The pool token is already approved for spending.
     */
    function _addLiquidity(
        ISwap pool,
        SynapseParams memory params,
        uint256 amountIn,
        address tokenOut
    ) internal returns (uint256 amountOut) {
        (uint256 tokens, address lpToken) = swapQuoter.poolInfo(address(pool));
        // tokenOut should match the LP token
        require(tokenOut == lpToken, "!tokenOut");
        uint256[] memory amounts = new uint256[](tokens);
        amounts[params.tokenIndexFrom] = amountIn;
        // amountOut and deadline are not checked in SwapAdapter
        amountOut = pool.addLiquidity({amounts: amounts, minToMint: 0, deadline: MAX_UINT});
    }

    /**
     * @notice Removes liquidity in a form of a single token from the given pool.
     * The pool LP token is already approved for spending.
     */
    function _removeLiquidity(
        ISwap pool,
        SynapseParams memory params,
        uint256 amountIn,
        address tokenOut
    ) internal returns (uint256 amountOut) {
        // tokenOut should match the "swap to" token
        require(pool.getToken(params.tokenIndexTo) == IERC20(tokenOut), "!tokenOut");
        // amountOut and deadline are not checked in SwapAdapter
        amountOut = pool.removeLiquidityOneToken({
            tokenAmount: amountIn,
            tokenIndex: params.tokenIndexTo,
            minAmount: 0,
            deadline: MAX_UINT
        });
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         INTERNAL: WETH LOGIC                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Derives WETH address from swap parameters.
    function _deriveWethAddress(
        address token,
        SynapseParams memory params,
        bool isWethIn
    ) internal view returns (address weth) {
        if (params.action == Action.HandleEth) {
            // If we only need to wrap/unwrap ETH, WETH address should be specified as the other token
            weth = token;
        } else {
            // Otherwise, we need to get WETH address from the liquidity pool
            weth = address(ISwap(params.pool).getToken(isWethIn ? params.tokenIndexFrom : params.tokenIndexTo));
        }
    }

    /// @dev Wraps ETH into WETH.
    function _wrapETH(address weth, uint256 amount) internal {
        require(msg.value == amount, "!msg.value");
        // Deposit in order to have WETH in this contract
        IWETH9(payable(weth)).deposit{value: amount}();
    }

    /// @dev Unwraps WETH into ETH.
    function _unwrapETH(address weth, uint256 amount) internal {
        // Withdraw ETH to this contract
        IWETH9(payable(weth)).withdraw(amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/ISynapseBridge.sol";
import "./LocalBridgeConfig.sol";
import "./SynapseAdapter.sol";
import "../utils/MulticallView.sol";

/**
 * @notice SynapseRouter contract that can be used together with SynapseBridge on any chain.
 * On every supported chain:
 * - SynapseRouter and SwapQuoter contracts need to be deployed.
 * - Chain pools that are present in the global BridgeConfig should be added to SwapQuoter.
 * - All supported bridge tokens should be added to SynapseRouter contract.
 * - router.setSwapQuoter(swapQuoter) should be executed to link these contracts.
 *
 * @dev Bridging workflow with SynapseRouter contract.
 * Initial assumptions:
 * - `routerOrigin` and `routerDest` are SynapseRouter deployments on origin and destination chain respectively.
 * - User wants to send `tokenIn` on origin chain, and receive `tokenOut` on destination chain.
 * - The amount of `tokenIn` tokens user wishes to send is `amountIn`.
 * - User wants to receives tokens to `userDest` address on destination chain.
 * - User has no idea what bridge tokens are supported on origin and destination chains.
 *
 * Under the hood, the cross-chain swap from `tokenIn` to `tokenOut` is:
 * 1. [*] `tokenIn` gets swapped to `bridgeToken` on origin chain. `bridgeToken` is a token supported by Synapse:Bridge.
 * 2. `bridgeToken` gets bridged from origin to destination chain
 * 3. [**] `bridgeToken` gets swapped to `tokenOut` on destination chain.
 * 4. `tokenOut` is transferred to the user on destination chain.
 * [*] : "origin swap" is skipped, if `tokenIn == bridgeToken` on origin chain.
 * [**]: "destination swap" is skipped, if `tokenOut == bridgeToken` on destination chain.
 *
 * Following set of actions is required (be aware, provided code is a pseudo code):
 * 1. Determine the set of bridge tokens that could fulfill "receive tokenOut on destination chain":
 *      // This will return a list of (string symbol, address token) tuples.
 *      bridgeTokens = routerDest.getConnectedBridgeTokens(tokenOut);
 * 2. Get the list of symbols for these tokens
 *      symbols = bridgeTokens.map(token => token.symbol);
 * 3. Get the list of structs with instructions for possible "origin swap":
 *      // This will return queries for all possible (tokenIn -> symbols[i]) swaps
 *      originQueries = routerOrigin.getOriginAmountOut(tokenIn, symbols, amountIn);
 * 4. Form the list of requests for the "destination swap" quotes:
 *      // Use symbols[i] and originQueries[i].minAmountOut to form a "request":
 *      requests = zipWith(symbols, originQueries, (symbol, query) => { return [symbol, query.minAmountOut] });
 * 5. Get the list of structs with instructions for possible "destination swap":
 *      // This will return quotes for all (symbols[i] => tokenOut) swaps
 *      // This will also take into account the bridge fee for getting a token to destination chain
 *      destQueries = routerDest.getDestinationAmountOut(requests, tokenOut);
 * 6. Pick any pair of (originQuery, destQuery):
 *      // For instance pick the one with the best destQuery.minAmountOut
 *      maxIndex = destQueries.indexOf(destQueries.maxBy, (query) => { return query.minAmountOut });
 *      originQuery = originQueries[maxIndex];
 *      // destQuery.minAmountOut is the full quote for tokenIn => tokenOut cross-chain swap
 *      destQuery = destQueries[maxIndex];
 * 7. Apply slippage, and set deadlines as per user settings:
 *      originQuery = applyUserSettings(originQuery);
 *      destQuery = applyUserSettings(destQuery);
 * 8. Call SynapseRouter using the obtained structs:
 *      // Check if user wants to send native ETH
 *      amountETH = (tokenIn == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) ? amountIn : 0;
 *      routerOrigin.bridge{value: amountETH}(userDest, chainIdDest, tokenIn, amountIn, originQuery, destQuery);
 */
contract SynapseRouter is LocalBridgeConfig, SynapseAdapter, MulticallView {
    // SynapseRouter is also the Adapter for the Synapse pools (this reduces the amount of token transfers).
    // SynapseRouter address will be used as swapAdapter in SwapQueries returned by a local SwapQuoter.

    using SafeERC20 for IERC20;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        CONSTANTS & IMMUTABLES                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Synapse:Bridge address
    ISynapseBridge public immutable synapseBridge;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      CONSTRUCTOR & INITIALIZER                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Deploys a Synapse Router implementation, saves local Synapse:Bridge address and transfers ownership.
     */
    constructor(address _synapseBridge, address owner_) public {
        synapseBridge = ISynapseBridge(_synapseBridge);
        transferOwnership(owner_);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              OWNER ONLY                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Sets a custom allowance for the given token.
     * @dev To be used for the wrapper token setups.
     */
    function setAllowance(
        IERC20 token,
        address spender,
        uint256 amount
    ) external onlyOwner {
        token.safeApprove(spender, amount);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            BRIDGE & SWAP                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Initiate a bridge transaction with an optional swap on both origin and destination chains.
     * @dev Note that method is payable.
     * If token is ETH_ADDRESS, this method should be invoked with `msg.value = amountIn`.
     * If token is ERC20, the tokens will be pulled from msg.sender (use `msg.value = 0`).
     * Make sure to approve this contract for spending `token` beforehand.
     * originQuery.tokenOut should never be ETH_ADDRESS, bridge only works with ERC20 tokens.
     *
     * `token` is always a token user is sending. In case token requires a wrapper token to be bridge,
     * use underlying address for `token` instead of the wrapper one.
     *
     * `originQuery` contains instructions for the swap on origin chain. As above, originQuery.tokenOut
     * should always use the underlying address. In other words, the concept of wrapper token is fully
     * abstracted away from the end user.
     *
     * `originQuery` is supposed to be fetched using SynapseRouter.getOriginAmountOut().
     * Alternatively one could use an external adapter for more complex swaps on the origin chain.
     *
     * `destQuery` is supposed to be fetched using SynapseRouter.getDestinationAmountOut().
     * Complex swaps on destination chain are not supported for the time being.
     * Check contract description above for more details.
     *
     * @param to            Address to receive tokens on destination chain
     * @param chainId       Destination chain id
     * @param token         Initial token for the bridge transaction to be pulled from the user
     * @param amount        Amount of the initial tokens for the bridge transaction
     * @param originQuery   Origin swap query. Empty struct indicates no swap is required
     * @param destQuery     Destination swap query. Empty struct indicates no swap is required
     */
    function bridge(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) external payable {
        if (_hasAdapter(originQuery)) {
            // Perform a swap using the swap adapter, transfer the swapped tokens to this contract
            (token, amount) = _adapterSwap(address(this), token, amount, originQuery);
        } else {
            // Pull initial token from the user to this contract
            _pullToken(address(this), token, amount);
        }
        // Either way, this contract has `amount` worth of `token`
        TokenConfig memory _config = config[token];
        require(_config.bridgeToken != address(0), "Token not supported");
        token = _config.bridgeToken;
        // Decode params for swapping via a Synapse pool on the destination chain, if they were requested.
        SynapseParams memory destParams;
        if (_hasAdapter(destQuery)) destParams = abi.decode(destQuery.rawParams, (SynapseParams));
        // Check if Swap/RemoveLiquidity Action on destination chain is required.
        // Swap adapter needs to be specified.
        // HandleETH action is done automatically by SynapseBridge.
        if (_hasAdapter(destQuery) && destParams.action != Action.HandleEth) {
            if (_config.tokenType == TokenType.Deposit) {
                require(destParams.action == Action.Swap, "Unsupported dest action");
                // Case 1: token needs to be deposited on origin chain.
                // We need to perform AndSwap() on destination chain.
                synapseBridge.depositAndSwap({
                    to: to,
                    chainId: chainId,
                    token: IERC20(token),
                    amount: amount,
                    tokenIndexFrom: destParams.tokenIndexFrom,
                    tokenIndexTo: destParams.tokenIndexTo,
                    minDy: destQuery.minAmountOut,
                    deadline: destQuery.deadline
                });
            } else if (destParams.action == Action.Swap) {
                // Case 2: token needs to be redeemed on origin chain.
                // We need to perform AndSwap() on destination chain.
                synapseBridge.redeemAndSwap({
                    to: to,
                    chainId: chainId,
                    token: IERC20(token),
                    amount: amount,
                    tokenIndexFrom: destParams.tokenIndexFrom,
                    tokenIndexTo: destParams.tokenIndexTo,
                    minDy: destQuery.minAmountOut,
                    deadline: destQuery.deadline
                });
            } else {
                require(destParams.action == Action.RemoveLiquidity, "Unsupported dest action");
                // Case 3: token needs to be redeemed on origin chain.
                // We need to perform AndRemove() on destination chain.
                synapseBridge.redeemAndRemove({
                    to: to,
                    chainId: chainId,
                    token: IERC20(token),
                    amount: amount,
                    liqTokenIndex: destParams.tokenIndexTo,
                    liqMinAmount: destQuery.minAmountOut,
                    liqDeadline: destQuery.deadline
                });
            }
        } else {
            if (_config.tokenType == TokenType.Deposit) {
                // Case 1 (Deposit): token needs to be deposited on origin chain
                synapseBridge.deposit(to, chainId, IERC20(token), amount);
            } else {
                // Case 2 (Redeem): token needs to be redeemed on origin chain
                synapseBridge.redeem(to, chainId, IERC20(token), amount);
            }
        }
    }

    /**
     * @notice Perform a swap using the supplied parameters.
     * @dev Note that method is payable.
     * If token is ETH_ADDRESS, this method should be invoked with `msg.value = amountIn`.
     * If token is ERC20, the tokens will be pulled from msg.sender (use `msg.value = 0`).
     * Make sure to approve this contract for spending `token` beforehand.
     * If query.tokenOut is ETH_ADDRESS, native ETH will be sent to the recipient (be aware of potential reentrancy).
     * If query.tokenOut is ERC20, the tokens will be transferred to the recipient.
     * @param to            Address to receive swapped tokens
     * @param token         Token to swap
     * @param amount        Amount of tokens to swap
     * @param query         Query with the swap parameters (see BridgeStructs.sol)
     * @return amountOut    Amount of swapped tokens received by the user
     */
    function swap(
        address to,
        address token,
        uint256 amount,
        SwapQuery memory query
    ) external payable returns (uint256 amountOut) {
        require(to != address(0), "!recipient: zero address");
        require(to != address(this), "!recipient: router address");
        require(_hasAdapter(query), "!swapAdapter");
        // Perform a swap through the Adapter. Adapter will be the one handling ETH/WETH interactions.
        (, amountOut) = _adapterSwap(to, token, amount, query);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         VIEWS: BRIDGE QUOTES                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Finds the best path between `tokenIn` and every supported bridge token from the given list,
     * treating the swap as "origin swap", without putting any restrictions on the swap.
     * @dev Will NOT revert if any of the tokens are not supported, instead will return an empty query for that symbol.
     * Check (query.minAmountOut != 0): this is true only if the swap is possible and bridge token is supported.
     * The returned queries with minAmountOut != 0 could be used as `originQuery` with SynapseRouter.
     * Note: it is possible to form a SwapQuery off-chain using alternative SwapAdapter for the origin swap.
     * @param tokenIn       Initial token that user wants to bridge/swap
     * @param tokenSymbols  List of symbols representing bridge tokens
     * @param amountIn      Amount of tokens user wants to bridge/swap
     * @return originQueries    List of structs that could be used as `originQuery` in SynapseRouter.
     *                          minAmountOut and deadline fields will need to be adjusted based on the user settings.
     */
    function getOriginAmountOut(
        address tokenIn,
        string[] memory tokenSymbols,
        uint256 amountIn
    ) external view returns (SwapQuery[] memory originQueries) {
        uint256 length = tokenSymbols.length;
        originQueries = new SwapQuery[](length);
        for (uint256 i = 0; i < length; ++i) {
            // Check if token with given symbol is supported on this chain
            address bridgeToken = symbolToToken[tokenSymbols[i]];
            // Skip not supported tokens
            if (bridgeToken == address(0)) continue;
            // Every possible action is supported for origin swap
            LimitedToken memory _tokenIn = LimitedToken(ActionLib.allActions(), tokenIn);
            originQueries[i] = swapQuoter.getAmountOut(_tokenIn, bridgeToken, amountIn);
        }
    }

    /**
     * @notice Finds the best path between every supported bridge token from the given list and `tokenOut`,
     * treating the swap as "destination swap", limiting possible actions to those available for every bridge token.
     * @dev Will NOT revert if any of the tokens are not supported, instead will return an empty query for that symbol.
     * Note: it is NOT possible to form a SwapQuery off-chain using alternative SwapAdapter for the destination swap.
     * For the time being, only swaps through the Synapse-supported pools are available on destination chain.
     * @param requests  List of structs with following information:
     *                  - symbol: unique token ID consistent among all chains
     *                  - amountIn: amount of bridge token to start with, before the bridge fee is applied
     * @param tokenOut  Token user wants to receive on destination chain
     * @return destQueries  List of structs that could be used as `destQuery` in SynapseRouter.
     *                      minAmountOut and deadline fields will need to be adjusted based on the user settings.
     */
    function getDestinationAmountOut(DestRequest[] memory requests, address tokenOut)
        external
        view
        returns (SwapQuery[] memory destQueries)
    {
        uint256 length = requests.length;
        destQueries = new SwapQuery[](length);
        for (uint256 i = 0; i < length; ++i) {
            address token = symbolToToken[requests[i].symbol];
            // Skip if token is not supported
            if (token == address(0)) continue;
            // token is confirmed to be a supported bridge token at this point
            uint256 amountIn = _calculateBridgeAmountOut(token, requests[i].amountIn);
            // Skip if fee is greater than amountIn
            if (amountIn == 0) continue;
            TokenType bridgeTokenType = config[token].tokenType;
            // See what kind of "Actions" are available for the given bridge token:
            LimitedToken memory tokenIn = LimitedToken(_bridgeTokenActions(bridgeTokenType), token);
            destQueries[i] = swapQuoter.getAmountOut(tokenIn, tokenOut, amountIn);
        }
    }

    /**
     * @notice Gets the list of all bridge tokens (and their symbols), such that destination swap
     * from a bridge token to `tokenOut` is possible.
     * @param tokenOut  Token address to swap to on destination chain
     * @return tokens   List of structs with following information:
     *                  - symbol: unique token ID consistent among all chains
     *                  - token: bridge token address
     */
    function getConnectedBridgeTokens(address tokenOut) external view returns (BridgeToken[] memory tokens) {
        uint256 amount = bridgeTokensAmount();
        // Try connecting every supported bridge token to tokenOut
        LimitedToken[] memory allTokens = new LimitedToken[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            address token = _bridgeTokens.at(i);
            // Make sure only "supported actions" for destination swap are included
            allTokens[i].actionMask = _bridgeTokenActions(config[token].tokenType);
            allTokens[i].token = token;
        }
        (uint256 amountFound, bool[] memory isConnected) = swapQuoter.findConnectedTokens(allTokens, tokenOut);
        tokens = new BridgeToken[](amountFound);
        // This will now track amount of found connected tokens so far during the next for loop
        amountFound = 0;
        for (uint256 i = 0; i < amount; ++i) {
            if (isConnected[i]) {
                // Record the connected token
                address token = allTokens[i].token;
                tokens[amountFound].symbol = tokenToSymbol[token];
                tokens[amountFound].token = token;
                // Increase the counter
                ++amountFound;
            }
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            INTERNAL: SWAP                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Performs a swap from `token` using the provided query,
     * which includes the swap adapter, tokenOut and the swap execution parameters.
     * Swapped token is transferred to the specified recipient.
     */
    function _adapterSwap(
        address recipient,
        address token,
        uint256 amount,
        SwapQuery memory query
    ) internal returns (address tokenOut, uint256 amountOut) {
        // First, check the deadline for the swap
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= query.deadline, "Deadline not met");
        // Pull initial token from the user to specified swap adapter
        _pullToken(query.swapAdapter, token, amount);
        tokenOut = query.tokenOut;
        // If swapAdapter is this contract (which is the case for the supported Synapse pools),
        // this will be an external call to address(this), which we are fine with.
        // The external call is used because additional Adapters will be established in the future.
        // We are forwarding `msg.value` and are expecting the Adapter to handle ETH/WETH interactions.
        amountOut = ISwapAdapter(query.swapAdapter).adapterSwap{value: msg.value}({
            to: recipient,
            tokenIn: token,
            amountIn: amount,
            tokenOut: tokenOut,
            rawParams: query.rawParams
        });
        // We can trust the supported adapters to return the exact swapped amount
        // Finally, check that the recipient received at least as much as they wanted
        require(amountOut >= query.minAmountOut, "Swap didn't result in min tokens");
    }

    /**
     * Pulls a requested token from the user to the requested recipient.
     * Or, if msg.value was provided, check that ETH_ADDRESS was used and msg.value is correct.
     */
    function _pullToken(
        address recipient,
        address token,
        uint256 amount
    ) internal {
        if (msg.value == 0) {
            // Token needs to be pulled only if msg.value is zero
            // This way user can specify WETH as the origin asset
            IERC20(token).safeTransferFrom(msg.sender, recipient, amount);
        } else {
            // Otherwise, we need to check that ETH was specified
            require(token == UniversalToken.ETH_ADDRESS, "!eth");
            // And that amount matches msg.value
            require(msg.value == amount, "!msg.value");
            // We will forward msg.value in the external call to the recipient
        }
    }

    /**
     * @notice Checks whether the swap adapter was specified in the query.
     * Query without a swap adapter specifies that no action needs to be taken.
     */
    function _hasAdapter(SwapQuery memory query) internal pure returns (bool) {
        return query.swapAdapter != address(0);
    }

    function _bridgeTokenActions(TokenType tokenType) internal pure returns (uint256 actionMask) {
        if (tokenType == TokenType.Redeem) {
            // For tokens that are minted on destination chain
            // possible bridge functions are mint() and mintAndSwap(). Thus:
            // Swap: available via mintAndSwap()
            // (Add/Remove)Liquidity is unavailable
            // HandleETH is unavailable, as WETH could only be withdrawn by SynapseBridge
            actionMask = ActionLib.mask(Action.Swap);
        } else {
            // For tokens that are withdrawn on destination chain
            // possible bridge functions are withdraw() and withdrawAndRemove().
            // Swap/AddLiquidity: not available
            // RemoveLiquidity: available via withdrawAndRemove()
            // HandleETH: available via withdraw(). SwapQuoter will check if the bridge token is WETH or not.
            actionMask = ActionLib.mask(Action.RemoveLiquidity, Action.HandleEth);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                 INTERNAL: ADD & REMOVE BRIDGE TOKENS                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Adds a bridge token config and its fee structure, if it's not present.
    /// If a token was added, approves it for spending by SynapseBridge.
    function _addToken(
        string memory symbol,
        address token,
        TokenType tokenType,
        address bridgeToken,
        uint256 bridgeFee,
        uint256 minFee,
        uint256 maxFee
    ) internal override returns (bool wasAdded) {
        // Add token and its fee structure
        wasAdded = LocalBridgeConfig._addToken(symbol, token, tokenType, bridgeToken, bridgeFee, minFee, maxFee);
        if (wasAdded) {
            // Approve token only if it wasn't previously added
            // Underlying token should always implement allowance(), approve()
            if (token == bridgeToken) token.universalApproveInfinity(address(synapseBridge));
            // Use {setAllowance} for custom wrapper token setups
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/// @notice Multicall utility for view/pure functions. Inspired by Multicall3:
/// https://github.com/mds1/multicall/blob/master/src/Multicall3.sol
abstract contract MulticallView {
    struct Result {
        bool success;
        bytes returnData;
    }

    /// @notice Aggregates a few static calls to this contract into one multicall.
    /// Any of the calls could revert without having impact on other calls. That includes the scenario,
    /// where a data for state modifying call was supplied, which would lead to one of the calls being reverted.
    function multicallView(bytes[] memory data) external view returns (Result[] memory callResults) {
        uint256 amount = data.length;
        callResults = new Result[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            // We perform a static call to ourselves here. This will record `success` as false,
            // should the static call be reverted. The other calls will still be performed regardless.
            // Note: `success` will be set to false, if data for state modifying call was supplied.
            // No data will be modified, as this is a view function.
            (callResults[i].success, callResults[i].returnData) = address(this).staticcall(data[i]);
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
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
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
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
        require(b > 0, "SafeMath: modulo by zero");
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/Context.sol";
import "./IERC20.sol";
import "../../math/SafeMath.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/Context.sol";
import "./ERC20.sol";

/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract ERC20Burnable is Context, ERC20 {
    using SafeMath for uint256;

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(amount, "ERC20: burn amount exceeds allowance");

        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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

pragma solidity >=0.6.0 <0.8.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

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
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
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
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

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
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;

        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) { // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            bytes32 lastvalue = set._values[lastIndex];

            // Move the last value to the index where the value to delete is
            set._values[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            set._indexes[lastvalue] = toDeleteIndex + 1; // All indexes are 1-based

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }


    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}