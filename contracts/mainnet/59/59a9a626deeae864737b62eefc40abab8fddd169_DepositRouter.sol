// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {IVault} from "src/interface/IVault.sol";

/// @notice A router for depositing funds into the Perpetual vault. It supports a single ERC20 token
/// and Ether.
contract DepositRouter {
  /// @notice The token that is being deposited into the router.
  address public immutable TOKEN;

  /// @notice The contract for the Perpetual vault where the deposits are sent.
  IVault public immutable PERPETUAL_VAULT;

  /// @param token Address of the token that is being deposited into the router.
  /// @param vault Address of the Perpetual vault where the deposits are sent.
  constructor(address token, IVault vault) {
    TOKEN = token;
    PERPETUAL_VAULT = vault;
  }

  /// @notice Deposits the router's token into the Perpetual vault.
  fallback() external payable {
    uint256 amount = uint256(uint96(bytes12(msg.data[0:12])));
    SafeTransferLib.safeTransferFrom(ERC20(TOKEN), msg.sender, address(this), amount);
    ERC20(TOKEN).approve(address(PERPETUAL_VAULT), amount);
    PERPETUAL_VAULT.depositFor(msg.sender, TOKEN, amount);
  }

  /// @notice Deposits Ether into the Perpetual vault.
  receive() external payable {
    PERPETUAL_VAULT.depositEtherFor{value: msg.value}(msg.sender);
  }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "../tokens/ERC20.sol";

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
/// @dev Note that none of the functions in this library check that a token has code at all! That responsibility is delegated to the caller.
library SafeTransferLib {
    /*//////////////////////////////////////////////////////////////
                             ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), from) // Append the "from" argument.
            mstore(add(freeMemoryPointer, 36), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
            )
        }

        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "TRANSFER_FAILED");
    }

    function safeApprove(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "APPROVE_FAILED");
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// permalink: https://optimistic.etherscan.io/address/0x12c884f45062b58e1592d1438542731829790a25#code#F38#L1
pragma solidity 0.8.16;
pragma abicoder v2;

interface IVault {
    /// @notice Emitted when trader deposit collateral into vault
    /// @param collateralToken The address of token deposited
    /// @param trader The address of trader
    /// @param amount The amount of token deposited
    event Deposited(
        address indexed collateralToken,
        address indexed trader,
        uint256 amount
    );

    /// @notice Emitted when trader withdraw collateral from vault
    /// @param collateralToken The address of token withdrawn
    /// @param trader The address of trader
    /// @param amount The amount of token withdrawn
    event Withdrawn(
        address indexed collateralToken,
        address indexed trader,
        uint256 amount
    );

    /// @notice Emitted when a trader's collateral is liquidated
    /// @param trader The address of trader
    /// @param collateralToken The address of the token that is liquidated
    /// @param liquidator The address of liquidator
    /// @param collateral The amount of collateral token liquidated
    /// @param repaidSettlementWithoutInsuranceFundFeeX10_S The amount of settlement token repaid
    ///        for trader (in settlement token's decimals)
    /// @param insuranceFundFeeX10_S The amount of insurance fund fee paid(in settlement token's
    /// decimals)
    /// @param discountRatio The discount ratio of liquidation price
    event CollateralLiquidated(
        address indexed trader,
        address indexed collateralToken,
        address indexed liquidator,
        uint256 collateral,
        uint256 repaidSettlementWithoutInsuranceFundFeeX10_S,
        uint256 insuranceFundFeeX10_S,
        uint24 discountRatio
    );

    /// @notice Emitted when trustedForwarder is changed
    /// @dev trustedForwarder is only used for metaTx
    /// @param trustedForwarder The address of trustedForwarder
    event TrustedForwarderChanged(address indexed trustedForwarder);

    /// @notice Emitted when clearingHouse is changed
    /// @param clearingHouse The address of clearingHouse
    event ClearingHouseChanged(address indexed clearingHouse);

    /// @notice Emitted when collateralManager is changed
    /// @param collateralManager The address of collateralManager
    event CollateralManagerChanged(address indexed collateralManager);

    /// @notice Emitted when WETH9 is changed
    /// @param WETH9 The address of WETH9
    event WETH9Changed(address indexed WETH9);

    /// @notice Emitted when bad debt realized and settled
    /// @param trader Address of the trader
    /// @param amount Absolute amount of bad debt
    event BadDebtSettled(address indexed trader, uint256 amount);

    /// @notice Deposit collateral into vault
    /// @param token The address of the token to deposit
    /// @param amount The amount of the token to deposit
    function deposit(address token, uint256 amount) external;

    /// @notice Deposit the collateral token for other account
    /// @param to The address of the account to deposit to
    /// @param token The address of collateral token
    /// @param amount The amount of the token to deposit
    function depositFor(
        address to,
        address token,
        uint256 amount
    ) external;

    /// @notice Deposit ETH as collateral into vault
    function depositEther() external payable;

    /// @notice Deposit ETH as collateral for specified account
    /// @param to The address of the account to deposit to
    function depositEtherFor(address to) external payable;

    /// @notice Withdraw collateral from vault
    /// @param token The address of the token to withdraw
    /// @param amount The amount of the token to withdraw
    function withdraw(address token, uint256 amount) external;

    /// @notice Withdraw ETH from vault
    /// @param amount The amount of the ETH to withdraw
    function withdrawEther(uint256 amount) external;

    /// @notice Withdraw all free collateral from vault
    /// @param token The address of the token to withdraw
    /// @return amount The amount of the token withdrawn
    function withdrawAll(address token) external returns (uint256 amount);

    /// @notice Withdraw all free collateral of ETH from vault
    /// @return amount The amount of ETH withdrawn
    function withdrawAllEther() external returns (uint256 amount);

    /// @notice Liquidate trader's collateral by given settlement token amount or non settlement token
    /// amount
    /// @param trader The address of trader that will be liquidated
    /// @param token The address of non settlement collateral token that the trader will be liquidated
    /// @param amount The amount of settlement token that the liquidator will repay for trader or
    ///               the amount of non-settlement collateral token that the liquidator will charge
    /// from trader
    /// @param isDenominatedInSettlementToken Whether the amount is denominated in settlement token or
    /// not
    /// @return returnAmount The amount of a non-settlement token (in its native decimals) that is
    /// liquidated
    ///         when `isDenominatedInSettlementToken` is true or the amount of settlement token that
    /// is repaid
    ///         when `isDenominatedInSettlementToken` is false
    function liquidateCollateral(
        address trader,
        address token,
        uint256 amount,
        bool isDenominatedInSettlementToken
    ) external returns (uint256 returnAmount);

    /// @notice Settle trader's bad debt
    /// @param trader The address of trader that will be settled
    function settleBadDebt(address trader) external;

    /// @notice Get the specified trader's settlement token balance, without pending fee, funding
    /// payment
    ///         and owed realized PnL
    /// @dev The function is equivalent to `getBalanceByToken(trader, settlementToken)`
    ///      We keep this function solely for backward-compatibility with the older single-collateral
    /// system.
    ///      In practical applications, the developer might want to use `getSettlementTokenValue()`
    /// instead
    ///      because the latter includes pending fee, funding payment etc.
    ///      and therefore more accurately reflects a trader's settlement (ex. USDC) balance
    /// @return balance The balance amount (in settlement token's decimals)
    function getBalance(address trader) external view returns (int256 balance);

    /// @notice Get the balance of Vault of the specified collateral token and trader
    /// @param trader The address of the trader
    /// @param token The address of the collateral token
    /// @return balance The balance amount (in its native decimals)
    function getBalanceByToken(address trader, address token)
        external
        view
        returns (int256 balance);

    /// @notice Get they array of collateral token addresses that a trader has
    /// @return collateralTokens array of collateral token addresses
    function getCollateralTokens(address trader)
        external
        view
        returns (address[] memory collateralTokens);

    /// @notice Get account value of the specified trader
    /// @param trader The address of the trader
    /// @return accountValueX10_S account value (in settlement token's decimals)
    function getAccountValue(address trader)
        external
        view
        returns (int256 accountValueX10_S);

    /// @notice Get the free collateral value denominated in the settlement token of the specified
    /// trader
    /// @param trader The address of the trader
    /// @return freeCollateral the value (in settlement token's decimals) of free collateral available
    ///         for withdraw or opening new positions or orders)
    function getFreeCollateral(address trader)
        external
        view
        returns (uint256 freeCollateral);

    /// @notice Get the free collateral amount of the specified trader and collateral ratio
    /// @dev There are three configurations for different insolvency risk tolerances:
    ///      **conservative, moderate &aggressive**. We will start with the **conservative** one
    ///      and gradually move to **aggressive** to increase capital efficiency
    /// @param trader The address of the trader
    /// @param ratio The margin requirement ratio, imRatio or mmRatio
    /// @return freeCollateralByRatio freeCollateral (in settlement token's decimals), by using the
    ///         input margin requirement ratio; can be negative
    function getFreeCollateralByRatio(address trader, uint24 ratio)
        external
        view
        returns (int256 freeCollateralByRatio);

    /// @notice Get the free collateral amount of the specified collateral token of specified trader
    /// @param trader The address of the trader
    /// @param token The address of the collateral token
    /// @return freeCollateral amount of that token (in the token's native decimals)
    function getFreeCollateralByToken(address trader, address token)
        external
        view
        returns (uint256 freeCollateral);

    /// @notice Get the specified trader's settlement value, including pending fee, funding payment,
    ///         owed realized PnL and unrealized PnL
    /// @dev Note the difference between `settlementTokenBalanceX10_S`, `getSettlementTokenValue()`
    /// and `getBalance()`:
    ///      They are all settlement token balances but with or without
    ///      pending fee, funding payment, owed realized PnL, unrealized PnL, respectively
    ///      In practical applications, we use `getSettlementTokenValue()` to get the trader's debt
    /// (if < 0)
    /// @param trader The address of the trader
    /// @return balance The balance amount (in settlement token's decimals)
    function getSettlementTokenValue(address trader)
        external
        view
        returns (int256 balance);

    /// @notice Get the settlement token address
    /// @dev We assume the settlement token should match the denominator of the price oracle.
    ///      i.e. if the settlement token is USDC, then the oracle should be priced in USD
    /// @return settlementToken The address of the settlement token
    function getSettlementToken()
        external
        view
        returns (address settlementToken);

    /// @notice Check if a given trader's collateral token can be liquidated; liquidation criteria:
    ///         1. margin ratio falls below maintenance threshold + 20bps (mmRatioBuffer)
    ///         2. USDC debt > nonSettlementTokenValue * debtNonSettlementTokenValueRatio (ex: 75%)
    ///         3. USDC debt > debtThreshold (ex: $10000)
    //          USDC debt = USDC balance + Total Unrealized PnL
    /// @param trader The address of the trader
    /// @return isLiquidatable If the trader can be liquidated
    function isLiquidatable(address trader)
        external
        view
        returns (bool isLiquidatable);

    /// @notice get the margin requirement for collateral liquidation of a trader
    /// @dev this value is compared with `ClearingHouse.getAccountValue()` (int)
    /// @param trader The address of the trader
    /// @return marginRequirement margin requirement (in 18 decimals)
    function getMarginRequirementForCollateralLiquidation(address trader)
        external
        view
        returns (int256 marginRequirement);

    /// @notice Get the maintenance margin ratio for collateral liquidation
    /// @return collateralMmRatio The maintenance margin ratio for collateral liquidation
    function getCollateralMmRatio()
        external
        view
        returns (uint24 collateralMmRatio);

    /// @notice Get a trader's liquidatable collateral amount by a given settlement amount
    /// @param token The address of the token of the trader's collateral
    /// @param settlementX10_S The amount of settlement token the liquidator wants to pay
    /// @return collateral The collateral amount(in its native decimals) the liquidator can get
    function getLiquidatableCollateralBySettlement(
        address token,
        uint256 settlementX10_S
    ) external view returns (uint256 collateral);

    /// @notice Get a trader's repaid settlement amount by a given collateral amount
    /// @param token The address of the token of the trader's collateral
    /// @param collateral The amount of collateral token the liquidator wants to get
    /// @return settlementX10_S The settlement amount(in settlement token's decimals) the liquidator
    /// needs to pay
    function getRepaidSettlementByCollateral(address token, uint256 collateral)
        external
        view
        returns (uint256 settlementX10_S);

    /// @notice Get a trader's max repaid settlement & max liquidatable collateral by a given
    /// collateral token
    /// @param trader The address of the trader
    /// @param token The address of the token of the trader's collateral
    /// @return maxRepaidSettlementX10_S The maximum settlement amount(in settlement token's decimals)
    ///         the liquidator needs to pay to liquidate a trader's collateral token
    /// @return maxLiquidatableCollateral The maximum liquidatable collateral amount
    ///         (in the collateral token's native decimals) of a trader
    function getMaxRepaidSettlementAndLiquidatableCollateral(
        address trader,
        address token
    )
        external
        view
        returns (
            uint256 maxRepaidSettlementX10_S,
            uint256 maxLiquidatableCollateral
        );

    /// @notice Get settlement token decimals
    /// @dev cached the settlement token's decimal for gas optimization
    /// @return decimals The decimals of settlement token
    function decimals() external view returns (uint8 decimals);

    /// @notice (Deprecated) Get the borrowed settlement token amount from insurance fund
    /// @return debtAmount The debt amount (in settlement token's decimals)
    function getTotalDebt() external view returns (uint256 debtAmount);

    /// @notice Get `ClearingHouseConfig` contract address
    /// @return clearingHouseConfig The address of `ClearingHouseConfig` contract
    function getClearingHouseConfig()
        external
        view
        returns (address clearingHouseConfig);

    /// @notice Get `AccountBalance` contract address
    /// @return accountBalance The address of `AccountBalance` contract
    function getAccountBalance() external view returns (address accountBalance);

    /// @notice Get `InsuranceFund` contract address
    /// @return insuranceFund The address of `InsuranceFund` contract
    function getInsuranceFund() external view returns (address insuranceFund);

    /// @notice Get `Exchange` contract address
    /// @return exchange The address of `Exchange` contract
    function getExchange() external view returns (address exchange);

    /// @notice Get `ClearingHouse` contract address
    /// @return clearingHouse The address of `ClearingHouse` contract
    function getClearingHouse() external view returns (address clearingHouse);

    /// @notice Get `CollateralManager` contract address
    /// @return clearingHouse The address of `CollateralManager` contract
    function getCollateralManager()
        external
        view
        returns (address clearingHouse);

    /// @notice Get `WETH9` contract address
    /// @return clearingHouse The address of `WETH9` contract
    function getWETH9() external view returns (address clearingHouse);
}