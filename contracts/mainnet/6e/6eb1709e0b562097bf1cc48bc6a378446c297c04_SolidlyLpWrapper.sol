// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "tokens/ERC20Vault.sol";
import "interfaces/ISolidlyPair.sol";
import "interfaces/ISolidlyRouter.sol";
import "interfaces/ISolidlyLpWrapper.sol";
import "interfaces/IVelodromePairFactory.sol";
import "libraries/SolidlyOneSidedVolatile.sol";
import "interfaces/IVaultHarvester.sol";
import "libraries/SafeTransferLib.sol";

contract SolidlyLpWrapper is ISolidlyLpWrapper, ERC20Vault {
    using SafeTransferLib for IERC20;

    error NotHarvester();
    error NotStrategyExecutor();
    error InsufficientAmountOut();
    error InvalidFeePercent();

    event RewardHarvested(uint256 total, uint256 vaultAmount, uint256 feeAmount);
    event HarvesterChanged(IVaultHarvester indexed oldHarvester, IVaultHarvester indexed newHarvester);
    event FeeParametersChanged(address indexed feeCollector, uint256 feeAmount);
    event StrategyExecutorChanged(address indexed executor, bool allowed);

    ISolidlyPair public immutable pair;
    address public immutable token0;
    address public immutable token1;

    address public feeCollector;
    uint8 public feePercent;
    IVaultHarvester public harvester;

    mapping(address => bool) public strategyExecutors;

    modifier onlyExecutor() {
        if (!strategyExecutors[msg.sender]) {
            revert NotStrategyExecutor();
        }
        _;
    }

    constructor(
        ISolidlyPair _pair,
        string memory _name,
        string memory _symbol,
        uint8 decimals
    ) ERC20Vault(IERC20(address(_pair)), _name, _symbol, decimals) {
        pair = _pair;
        (token0, token1) = _pair.tokens();
    }

    function harvest(uint256 minAmountOut) external onlyExecutor returns (uint256 amountOut) {
        ISolidlyPair(address(underlying)).claimFees();
        IERC20(token0).safeTransfer(address(harvester), IERC20(token0).balanceOf(address(this)));
        IERC20(token1).safeTransfer(address(harvester), IERC20(token1).balanceOf(address(this)));

        uint256 amountBefore = underlying.balanceOf(address(this));

        IVaultHarvester(harvester).harvest(address(this));

        uint256 total = underlying.balanceOf(address(this)) - amountBefore;
        if (total < minAmountOut) {
            revert InsufficientAmountOut();
        }

        uint256 feeAmount = (total * feePercent) / 100;

        if (feeAmount > 0) {
            amountOut = total - feeAmount;
            underlying.safeTransfer(feeCollector, feeAmount);
        }

        emit RewardHarvested(total, amountOut, feeAmount);
    }

    function setStrategyExecutor(address executor, bool value) external onlyOwner {
        strategyExecutors[executor] = value;
        emit StrategyExecutorChanged(executor, value);
    }

    function setHarvester(IVaultHarvester _harvester) external onlyOwner {
        IVaultHarvester previousHarvester = harvester;
        harvester = _harvester;
        emit HarvesterChanged(previousHarvester, _harvester);
    }

    function setFeeParameters(address _feeCollector, uint8 _feePercent) external onlyOwner {
        if (feePercent > 100) {
            revert InvalidFeePercent();
        }

        feeCollector = _feeCollector;
        feePercent = _feePercent;

        emit FeeParametersChanged(_feeCollector, _feePercent);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20WithSupply} from "BoringSolidity/ERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "libraries/SafeTransferLib.sol";
import "interfaces/IERC20Vault.sol";

/// @notice A token that behaves like SushiBar where the contract underlying token balance
/// influences the share value.
contract ERC20Vault is IERC20Vault, ERC20WithSupply, BoringOwnable {
    using SafeTransferLib for IERC20;

    IERC20 public immutable underlying;
    uint8 public immutable decimals;

    string public name;
    string public symbol;

    constructor(
        IERC20 _underlying,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        underlying = _underlying;
    }

    function _enter(uint256 amount, address recipient) internal returns (uint256 shares) {
        shares = toShares(amount);
        _mint(recipient, shares);
        underlying.safeTransferFrom(msg.sender, address(this), amount);
    }

    function _leave(uint256 shares, address recipient) internal returns (uint256 amount) {
        amount = toAmount(shares);
        _burn(msg.sender, shares);
        underlying.safeTransfer(recipient, amount);
    }

    function enter(uint256 amount) external returns (uint256 shares) {
        return _enter(amount, msg.sender);
    }

    function enterFor(uint256 amount, address recipient) external returns (uint256 shares) {
        return _enter(amount, recipient);
    }

    function leave(uint256 shares) external returns (uint256 amount) {
        return _leave(shares, msg.sender);
    }

    function leaveTo(uint256 shares, address recipient) external returns (uint256 amount) {
        return _leave(shares, recipient);
    }

    function leaveAll() external returns (uint256 amount) {
        return _leave(balanceOf[msg.sender], msg.sender);
    }

    function leaveAllTo(address recipient) external returns (uint256 amount) {
        return _leave(balanceOf[msg.sender], recipient);
    }

    function toAmount(uint256 shares) public view returns (uint256) {
        uint256 totalUnderlying = underlying.balanceOf(address(this));
        return (totalSupply == 0 || totalUnderlying == 0) ? shares : (shares * totalUnderlying) / totalSupply;
    }

    function toShares(uint256 amount) public view returns (uint256) {
        uint256 totalUnderlying = underlying.balanceOf(address(this));
        return (totalSupply == 0 || totalUnderlying == 0) ? amount : (amount * totalSupply) / totalUnderlying;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ISolidlyPair {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function token0() external pure returns (address);

    function token1() external pure returns (address);

    function tokens() external view returns (address, address);

    function reserve0() external pure returns (uint256);

    function reserve1() external pure returns (uint256);

    function claimFees() external returns (uint256 claimed0, uint256 claimed1);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function burn(address to) external returns (uint256 amount0, uint256 amount1);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ISolidlyRouter {
    // solhint-disable-next-line contract-name-camelcase
    struct route {
        address from;
        address to;
        bool stable;
    }

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

    function getAmountsOut(uint256 amountIn, route[] memory routes) external view returns (uint256[] memory amounts);

    function pairFor(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (address pair);

    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 amount, bool stable);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IERC20Vault.sol";
import "interfaces/IVaultHarvester.sol";

interface ISolidlyLpWrapper is IERC20Vault {
    function harvest(uint256 minAmountOut) external returns (uint256 amountOut);

    function setStrategyExecutor(address executor, bool value) external;

    function setHarvester(IVaultHarvester _harvester) external;

    function setFeeParameters(address _feeCollector, uint8 _feePercent) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IVelodromePairFactory {
    function volatileFee() external view returns (uint256);
    function stableFee() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "libraries/SafeTransferLib.sol";
import "interfaces/ISolidlyRouter.sol";
import "interfaces/ISolidlyPair.sol";
import "./Babylonian.sol";

library SolidlyOneSidedVolatile {
    using SafeTransferLib for IERC20;
    
    struct AddLiquidityAndOneSideRemainingParams {
        ISolidlyRouter router;
        ISolidlyPair pair;
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 token0Amount;
        uint256 token1Amount;
        uint256 minOneSideableAmount0;
        uint256 minOneSideableAmount1;
        address recipient;
        uint256 fee;
    }

    struct AddLiquidityFromSingleTokenParams {
        ISolidlyRouter router;
        ISolidlyPair pair;
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        address tokenIn;
        uint256 tokenInAmount;
        address recipient;
        uint256 fee;
    }

    /// @dev adapted from https://blog.alphaventuredao.io/onesideduniswap/
    /// turn off fees since they are not automatically added to the pair when swapping
    /// but moved out of the pool
    function _calculateSwapInAmount(
        uint256 reserveIn,
        uint256 amountIn,
        uint256 fee
    ) internal pure returns (uint256) {
        /// @dev rought estimation to account for the fact that fees don't stay inside the pool.
        amountIn += ((amountIn * fee) / 10000) / 2;

        return (Babylonian.sqrt(4000000 * (reserveIn * reserveIn) + (4000000 * amountIn * reserveIn)) - 2000 * reserveIn) / 2000;
    }

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function addLiquidityAndOneSideRemaining(AddLiquidityAndOneSideRemainingParams memory params)
        internal
        returns (
            uint256 idealAmount0,
            uint256 idealAmount1,
            uint256 liquidity
        )
    {
        (idealAmount0, idealAmount1, liquidity) = params.router.addLiquidity(
            params.token0,
            params.token1,
            false,
            params.token0Amount,
            params.token1Amount,
            0,
            0,
            params.recipient,
            type(uint256).max
        );

        params.token0Amount -= idealAmount0;
        params.token1Amount -= idealAmount1;

        address oneSideTokenIn;
        uint256 oneSideTokenAmount;

        if (params.token0Amount >= params.minOneSideableAmount0) {
            oneSideTokenIn = params.token0;
            oneSideTokenAmount = params.token0Amount;
        } else if (params.token1Amount > params.minOneSideableAmount1) {
            oneSideTokenIn = params.token1;
            oneSideTokenAmount = params.token1Amount;
        }

        if (oneSideTokenAmount > 0) {
            AddLiquidityFromSingleTokenParams memory _addLiquidityFromSingleTokenParams = AddLiquidityFromSingleTokenParams(
                params.router,
                params.pair,
                params.token0,
                params.token1,
                params.reserve0,
                params.reserve1,
                oneSideTokenIn,
                oneSideTokenAmount,
                params.recipient,
                params.fee
            );

            (uint256 _idealAmount0, uint256 _idealAmount1, uint256 _liquidity) = addLiquidityFromSingleToken(
                _addLiquidityFromSingleTokenParams
            );

            idealAmount0 += _idealAmount0;
            idealAmount1 += _idealAmount1;
            liquidity += _liquidity;
        }
    }

    function addLiquidityFromSingleToken(AddLiquidityFromSingleTokenParams memory params)
        internal
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        if (params.tokenIn == params.token0) {
            uint256 tokenInSwapAmount = _calculateSwapInAmount(params.reserve0, params.tokenInAmount, params.fee);
            params.tokenInAmount -= tokenInSwapAmount;
            uint256 sideTokenAmount = params.pair.getAmountOut(tokenInSwapAmount, params.token0);
            IERC20(params.tokenIn).safeTransfer(address(params.pair), tokenInSwapAmount);
            params.pair.swap(0, sideTokenAmount, address(this), "");
            return
                params.router.addLiquidity(
                    params.token0,
                    params.token1,
                    false,
                    params.tokenInAmount,
                    sideTokenAmount,
                    0,
                    0,
                    params.recipient,
                    type(uint256).max
                );
        } else {
            uint256 tokenInSwapAmount = _calculateSwapInAmount(params.reserve1, params.tokenInAmount, params.fee);
            params.tokenInAmount -= tokenInSwapAmount;
            uint256 sideTokenAmount = params.pair.getAmountOut(tokenInSwapAmount, params.token1);
            IERC20(params.tokenIn).safeTransfer(address(params.pair), tokenInSwapAmount);
            params.pair.swap(sideTokenAmount, 0, address(this), "");

            return
                params.router.addLiquidity(
                    params.token0,
                    params.token1,
                    false,
                    sideTokenAmount,
                    params.tokenInAmount,
                    0,
                    0,
                    params.recipient,
                    type(uint256).max
                );
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

interface IVaultHarvester {
    function harvest(address recipient) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";

/// @notice Safe ETH and IERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @author BoringSolidity (https://github.com/boringcrypto/BoringSolidity/blob/master/contracts/libraries/BoringERC20.sol)
/// @dev Caution! This library won't check that a token has code, responsibility is delegated to the caller.
library SafeTransferLib {
    bytes4 private constant SIG_SYMBOL = 0x95d89b41; // symbol()
    bytes4 private constant SIG_NAME = 0x06fdde03; // name()
    bytes4 private constant SIG_DECIMALS = 0x313ce567; // decimals()
    bytes4 private constant SIG_BALANCE_OF = 0x70a08231; // balanceOf(address)
    bytes4 private constant SIG_TOTALSUPPLY = 0x18160ddd; // balanceOf(address)

    function returnDataToString(bytes memory data) internal pure returns (string memory) {
        if (data.length >= 64) {
            return abi.decode(data, (string));
        } else if (data.length == 32) {
            uint8 i = 0;
            while (i < 32 && data[i] != 0) {
                i++;
            }
            bytes memory bytesArray = new bytes(i);
            for (i = 0; i < 32 && data[i] != 0; i++) {
                bytesArray[i] = data[i];
            }
            return string(bytesArray);
        } else {
            return "???";
        }
    }

    /// @notice Provides a safe ERC20.symbol version which returns '???' as fallback string.
    /// @param token The address of the ERC-20 token contract.
    /// @return (string) Token symbol.
    function safeSymbol(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_SYMBOL));
        return success ? returnDataToString(data) : "???";
    }

    /// @notice Provides a safe ERC20.name version which returns '???' as fallback string.
    /// @param token The address of the ERC-20 token contract.
    /// @return (string) Token name.
    function safeName(IERC20 token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_NAME));
        return success ? returnDataToString(data) : "???";
    }

    /// @notice Provides a safe ERC20.decimals version which returns '18' as fallback value.
    /// @param token The address of the ERC-20 token contract.
    /// @return (uint8) Token decimals.
    function safeDecimals(IERC20 token) internal view returns (uint8) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_DECIMALS));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    /// @notice Provides a gas-optimized balance check to avoid a redundant extcodesize check in addition to the returndatasize check.
    /// @param token The address of the ERC-20 token.
    /// @param to The address of the user to check.
    /// @return amount The token amount.
    function safeBalanceOf(IERC20 token, address to) internal view returns (uint256 amount) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_BALANCE_OF, to));
        require(success && data.length >= 32, "BoringERC20: BalanceOf failed");
        amount = abi.decode(data, (uint256));
    }

    /// @notice Provides a gas-optimized totalSupply to avoid a redundant extcodesize check in addition to the returndatasize check.
    /// @param token The address of the ERC-20 token.
    /// @return totalSupply The token totalSupply.
    function safeTotalSupply(IERC20 token) internal view returns (uint256 totalSupply) {
        (bool success, bytes memory data) = address(token).staticcall(abi.encodeWithSelector(SIG_TOTALSUPPLY));
        require(success && data.length >= 32, "BoringERC20: totalSupply failed");
        totalSupply = abi.decode(data, (uint256));
    }

    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // We'll write our calldata to this slot below, but restore it later.
            let memPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(0, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(4, from) // Append the "from" argument.
            mstore(36, to) // Append the "to" argument.
            mstore(68, amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 100 because that's the total length of our calldata (4 + 32 * 3)
                // Counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left.
                call(gas(), token, 0, 0, 100, 0, 32)
            )

            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, memPointer) // Restore the memPointer.
        }

        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // We'll write our calldata to this slot below, but restore it later.
            let memPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(0, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(4, to) // Append the "to" argument.
            mstore(36, amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because that's the total length of our calldata (4 + 32 * 2)
                // Counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left.
                call(gas(), token, 0, 0, 68, 0, 32)
            )

            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, memPointer) // Restore the memPointer.
        }

        require(success, "TRANSFER_FAILED");
    }

    function safeApprove(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // We'll write our calldata to this slot below, but restore it later.
            let memPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(0, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(4, to) // Append the "to" argument.
            mstore(36, amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because that's the total length of our calldata (4 + 32 * 2)
                // Counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left.
                call(gas(), token, 0, 0, 68, 0, 32)
            )

            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, memPointer) // Restore the memPointer.
        }

        require(success, "APPROVE_FAILED");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/IERC20.sol";
import "./Domain.sol";

// solhint-disable no-inline-assembly
// solhint-disable not-rely-on-time

// Data part taken out for building of contracts that receive delegate calls
contract ERC20Data {
    /// @notice owner > balance mapping.
    mapping(address => uint256) public balanceOf;
    /// @notice owner > spender > allowance mapping.
    mapping(address => mapping(address => uint256)) public allowance;
    /// @notice owner > nonce mapping. Used in `permit`.
    mapping(address => uint256) public nonces;
}

abstract contract ERC20 is IERC20, Domain {
    /// @notice owner > balance mapping.
    mapping(address => uint256) public override balanceOf;
    /// @notice owner > spender > allowance mapping.
    mapping(address => mapping(address => uint256)) public override allowance;
    /// @notice owner > nonce mapping. Used in `permit`.
    mapping(address => uint256) public nonces;

    /// @notice Transfers `amount` tokens from `msg.sender` to `to`.
    /// @param to The address to move the tokens.
    /// @param amount of the tokens to move.
    /// @return (bool) Returns True if succeeded.
    function transfer(address to, uint256 amount) public returns (bool) {
        // If `amount` is 0, or `msg.sender` is `to` nothing happens
        if (amount != 0 || msg.sender == to) {
            uint256 srcBalance = balanceOf[msg.sender];
            require(srcBalance >= amount, "ERC20: balance too low");
            if (msg.sender != to) {
                require(to != address(0), "ERC20: no zero address"); // Moved down so low balance calls safe some gas

                balanceOf[msg.sender] = srcBalance - amount; // Underflow is checked
                balanceOf[to] += amount;
            }
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Transfers `amount` tokens from `from` to `to`. Caller needs approval for `from`.
    /// @param from Address to draw tokens from.
    /// @param to The address to move the tokens.
    /// @param amount The token amount to move.
    /// @return (bool) Returns True if succeeded.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        // If `amount` is 0, or `from` is `to` nothing happens
        if (amount != 0) {
            uint256 srcBalance = balanceOf[from];
            require(srcBalance >= amount, "ERC20: balance too low");

            if (from != to) {
                uint256 spenderAllowance = allowance[from][msg.sender];
                // If allowance is infinite, don't decrease it to save on gas (breaks with EIP-20).
                if (spenderAllowance != type(uint256).max) {
                    require(spenderAllowance >= amount, "ERC20: allowance too low");
                    allowance[from][msg.sender] = spenderAllowance - amount; // Underflow is checked
                }
                require(to != address(0), "ERC20: no zero address"); // Moved down so other failed calls safe some gas

                balanceOf[from] = srcBalance - amount; // Underflow is checked
                balanceOf[to] += amount;
            }
        }
        emit Transfer(from, to, amount);
        return true;
    }

    /// @notice Approves `amount` from sender to be spend by `spender`.
    /// @param spender Address of the party that can draw from msg.sender's account.
    /// @param amount The maximum collective amount that `spender` can draw.
    /// @return (bool) Returns True if approved.
    function approve(address spender, uint256 amount) public override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparator();
    }

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 private constant PERMIT_SIGNATURE_HASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /// @notice Approves `value` from `owner_` to be spend by `spender`.
    /// @param owner_ Address of the owner.
    /// @param spender The address of the spender that gets approved to draw from `owner_`.
    /// @param value The maximum collective amount that `spender` can draw.
    /// @param deadline This permit must be redeemed before this deadline (UTC timestamp in seconds).
    function permit(
        address owner_,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(owner_ != address(0), "ERC20: Owner cannot be 0");
        require(block.timestamp < deadline, "ERC20: Expired");
        require(
            ecrecover(_getDigest(keccak256(abi.encode(PERMIT_SIGNATURE_HASH, owner_, spender, value, nonces[owner_]++, deadline))), v, r, s) ==
                owner_,
            "ERC20: Invalid Signature"
        );
        allowance[owner_][spender] = value;
        emit Approval(owner_, spender, value);
    }
}

contract ERC20WithSupply is IERC20, ERC20 {
    uint256 public override totalSupply;

    function _mint(address user, uint256 amount) internal {
        uint256 newTotalSupply = totalSupply + amount;
        require(newTotalSupply >= totalSupply, "Mint overflow");
        totalSupply = newTotalSupply;
        balanceOf[user] += amount;
        emit Transfer(address(0), user, amount);
    }

    function _burn(address user, uint256 amount) internal {
        require(balanceOf[user] >= amount, "Burn too much");
        totalSupply -= amount;
        balanceOf[user] -= amount;
        emit Transfer(user, address(0), amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Source: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol + Claimable.sol
// Simplified by BoringCrypto

contract BoringOwnableData {
    address public owner;
    address public pendingOwner;
}

contract BoringOwnable is BoringOwnableData {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice `owner` defaults to msg.sender on construction.
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /// @notice Transfers ownership to `newOwner`. Either directly or claimable by the new pending owner.
    /// Can only be invoked by the current `owner`.
    /// @param newOwner Address of the new owner.
    /// @param direct True if `newOwner` should be set immediately. False if `newOwner` needs to use `claimOwnership`.
    /// @param renounce Allows the `newOwner` to be `address(0)` if `direct` and `renounce` is True. Has no effect otherwise.
    function transferOwnership(
        address newOwner,
        bool direct,
        bool renounce
    ) public onlyOwner {
        if (direct) {
            // Checks
            require(newOwner != address(0) || renounce, "Ownable: zero address");

            // Effects
            emit OwnershipTransferred(owner, newOwner);
            owner = newOwner;
            pendingOwner = address(0);
        } else {
            // Effects
            pendingOwner = newOwner;
        }
    }

    /// @notice Needs to be called by `pendingOwner` to claim ownership.
    function claimOwnership() public {
        address _pendingOwner = pendingOwner;

        // Checks
        require(msg.sender == _pendingOwner, "Ownable: caller != pending owner");

        // Effects
        emit OwnershipTransferred(owner, _pendingOwner);
        owner = _pendingOwner;
        pendingOwner = address(0);
    }

    /// @notice Only allows the `owner` to execute the function.
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";

interface IERC20Vault is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function toAmount(uint256 shares) external view returns (uint256);

    function toShares(uint256 amount) external view returns (uint256);

    function underlying() external view returns (IERC20);

    function enter(uint256 amount) external returns (uint256 shares);

    function enterFor(uint256 amount, address recipient) external returns (uint256 shares);

    function leave(uint256 shares) external returns (uint256 amount);

    function leaveTo(uint256 shares, address receipient) external returns (uint256 amount);

    function leaveAll() external returns (uint256 amount);

    function leaveAllTo(address receipient) external returns (uint256 amount);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    // transfer and tranferFrom have been removed, because they don't work on all tokens (some aren't ERC20 complaint).
    // By removing them you can't accidentally use them.
    // name, symbol and decimals have been removed, because they are optional and sometimes wrongly implemented (MKR).
    // Use BoringERC20 with `using BoringERC20 for IERC20` and call `safeTransfer`, `safeTransferFrom`, etc instead.
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice EIP 2612
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

interface IStrictERC20 {
    // This is the strict ERC20 interface. Don't use this, certainly not if you don't control the ERC20 token you're calling.
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address _owner) external view returns (uint256 balance);
    function transfer(address _to, uint256 _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice EIP 2612
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

/// @notice Babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method).
library Babylonian {
    // computes square roots using the babylonian method
    // credit for this implementation goes to
    // https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.sol#L687
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        // this block is equivalent to r = uint256(1) << (BitMath.mostSignificantBit(x) / 2);
        // however that code costs significantly more gas
        uint256 xx = x;
        uint256 r = 1;
        if (xx >= 0x100000000000000000000000000000000) {
            xx >>= 128;
            r <<= 64;
        }
        if (xx >= 0x10000000000000000) {
            xx >>= 64;
            r <<= 32;
        }
        if (xx >= 0x100000000) {
            xx >>= 32;
            r <<= 16;
        }
        if (xx >= 0x10000) {
            xx >>= 16;
            r <<= 8;
        }
        if (xx >= 0x100) {
            xx >>= 8;
            r <<= 4;
        }
        if (xx >= 0x10) {
            xx >>= 4;
            r <<= 2;
        }
        if (xx >= 0x8) {
            r <<= 1;
        }
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1; // Seven iterations should be enough
        uint256 r1 = x / r;
        return (r < r1 ? r : r1);
    }
}

// SPDX-License-Identifier: MIT
// Based on code and smartness by Ross Campbell and Keno
// Uses immutable to store the domain separator to reduce gas usage
// If the chain id changes due to a fork, the forked chain will calculate on the fly.
pragma solidity ^0.8.0;

// solhint-disable no-inline-assembly

contract Domain {
    bytes32 private constant DOMAIN_SEPARATOR_SIGNATURE_HASH = keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
    // See https://eips.ethereum.org/EIPS/eip-191
    string private constant EIP191_PREFIX_FOR_EIP712_STRUCTURED_DATA = "\x19\x01";

    // solhint-disable var-name-mixedcase
    bytes32 private immutable _DOMAIN_SEPARATOR;
    uint256 private immutable DOMAIN_SEPARATOR_CHAIN_ID;

    /// @dev Calculate the DOMAIN_SEPARATOR
    function _calculateDomainSeparator(uint256 chainId) private view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_SEPARATOR_SIGNATURE_HASH, chainId, address(this)));
    }

    constructor() {
        _DOMAIN_SEPARATOR = _calculateDomainSeparator(DOMAIN_SEPARATOR_CHAIN_ID = block.chainid);
    }

    /// @dev Return the DOMAIN_SEPARATOR
    // It's named internal to allow making it public from the contract that uses it by creating a simple view function
    // with the desired public name, such as DOMAIN_SEPARATOR or domainSeparator.
    // solhint-disable-next-line func-name-mixedcase
    function _domainSeparator() internal view returns (bytes32) {
        return block.chainid == DOMAIN_SEPARATOR_CHAIN_ID ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(block.chainid);
    }

    function _getDigest(bytes32 dataHash) internal view returns (bytes32 digest) {
        digest = keccak256(abi.encodePacked(EIP191_PREFIX_FOR_EIP712_STRUCTURED_DATA, _domainSeparator(), dataHash));
    }
}