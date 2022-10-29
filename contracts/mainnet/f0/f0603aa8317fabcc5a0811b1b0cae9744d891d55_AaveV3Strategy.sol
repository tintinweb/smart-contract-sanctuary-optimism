// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {BaseStrategy} from "../BaseStrategy.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {IL2Pool} from "../interfaces/aaveV3/IL2Pool.sol";
import {IAaveIncentivesController} from "../interfaces/aaveV3/IAaveIncentiveController.sol";

/// @title AaveV3 Strategy
/// @dev Lend token on AaveV3
contract AaveV3Strategy is BaseStrategy {
    using SafeTransferLib for ERC20;

    /*//////////////////////////////////////////////////////////////
                                ADDRESSES
    //////////////////////////////////////////////////////////////*/

    IL2Pool public immutable aaveV3Pool;
    IAaveIncentivesController public immutable incentiveController;
    ERC20 public immutable aToken;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice sets the strategy configurations
    /// @param _bentoBox address of the bentobox
    /// @param _strategyToken address of the token in strategy
    /// @param _strategyExecutor address of the executor
    /// @param _feeTo address of the fee recipient
    /// @param _owner address of the owner of the strategy
    /// @param _fee fee of the strategy
    /// @param _aaveV3Pool address of aave pool
    /// @param _incentiveController address of incentive / reward controller
    constructor(
        address _bentoBox,
        address _strategyToken,
        address _strategyExecutor,
        address _feeTo,
        address _owner,
        uint256 _fee,
        address _aaveV3Pool,
        address _incentiveController
    )
        BaseStrategy(
            _bentoBox,
            _strategyToken,
            _strategyExecutor,
            _feeTo,
            _owner,
            _fee
        )
    {
        aaveV3Pool = IL2Pool(_aaveV3Pool);
        aToken = ERC20(
            IL2Pool(_aaveV3Pool).getReserveData(_strategyToken).aTokenAddress
        );
        incentiveController = IAaveIncentivesController(_incentiveController);
    }

    function _skim(uint256 amount) internal override {
        strategyToken.safeApprove(address(aaveV3Pool), amount);
        aaveV3Pool.supply(address(strategyToken), amount, address(this), 0);
    }

    function _harvest(uint256 balance)
        internal
        override
        returns (int256 amountAdded)
    {
        uint256 currentBalance = aToken.balanceOf(address(this));
        amountAdded = int256(currentBalance) - int256(balance); // Reasonably assume the values won't overflow.
        if (amountAdded > 0)
            aaveV3Pool.withdraw(
                address(strategyToken),
                uint256(amountAdded),
                address(this)
            );
    }

    function _withdraw(uint256 amount) internal override {
        aaveV3Pool.withdraw(address(strategyToken), amount, address(this));
    }

    function _exit() internal override {
        uint256 tokenBalance = aToken.balanceOf(address(this));
        uint256 available = strategyToken.balanceOf(address(aToken));
        if (tokenBalance <= available) {
            // If there are more tokens available than our full position, take all based on aToken balance (continue if unsuccessful).
            try
                aaveV3Pool.withdraw(
                    address(strategyToken),
                    tokenBalance,
                    address(this)
                )
            {} catch {}
        } else {
            // Otherwise redeem all available and take a loss on the missing amount (continue if unsuccessful).
            try
                aaveV3Pool.withdraw(
                    address(strategyToken),
                    available,
                    address(this)
                )
            {} catch {}
        }
    }

    function _harvestRewards() internal virtual override {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(aToken);
        incentiveController.claimAllRewards(rewardTokens, feeTo);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.10;

import "./interfaces/IStrategy.sol";
import "./interfaces/IBentoBoxMinimal.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/// @title Base contract for BentoBox Strategies
/// @dev Extend the contract and implement _skim, _harvest, _withdraw, _exit and _harvestRewards methods.
abstract contract BaseStrategy is IStrategy, Owned {
    using SafeTransferLib for ERC20;

    /*//////////////////////////////////////////////////////////////
                                ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /// @notice address of the token in strategy
    ERC20 public immutable strategyToken;

    /// @notice address of bentobox
    IBentoBoxMinimal private immutable bentoBox;

    /// @notice address of the performance fee receiver
    address public feeTo;

    /*//////////////////////////////////////////////////////////////
                            STRATEGY STATES
    //////////////////////////////////////////////////////////////*/

    /// @notice status of the exit strategy
    /// @dev After bentobox 'exits' the strategy harvest and withdraw functions can no longer be called.
    bool private _exited;

    /// @notice slippage protection during harvest
    uint256 private _maxBentoBoxBalance;

    /// @notice performance fee
    uint256 public fee;

    /// @notice performance fee precision
    uint256 public FEE_PRECISION = 1e18;

    /// @notice executors address status
    mapping(address => bool) public strategyExecutors;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LogSetStrategyExecutor(address indexed executor, bool allowed);
    event LogSetSwapPath(address indexed input, address indexed output);
    event LogFeeUpdated(uint256 fee);
    event LogFeeToUpdated(address newFeeTo);
    event LogPerformanceFee(ERC20 indexed token, uint256 indexed amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error StrategyExited();
    error StrategyNotExited();
    error OnlyBentoBox();
    error OnlyExecutor();
    error InvalidFee();

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice sets the strategy configurations
    /// @param _bentoBox address of the bentobox
    /// @param _strategyToken address of the token in strategy
    /// @param _strategyExecutor address of the executor
    /// @param _feeTo address of the fee recipient
    /// @param _owner address of the owner of the strategy
    /// @param _fee fee for the strategy
    constructor(
        address _bentoBox,
        address _strategyToken,
        address _strategyExecutor,
        address _feeTo,
        address _owner,
        uint256 _fee
    ) Owned(_owner) {
        strategyToken = ERC20(_strategyToken);
        bentoBox = IBentoBoxMinimal(_bentoBox);
        strategyExecutors[_strategyExecutor] = true;
        feeTo = _feeTo;
        if (_fee >= 1e18) revert InvalidFee();
        fee = _fee;
        emit LogFeeUpdated(_fee);
        emit LogSetStrategyExecutor(_strategyExecutor, true);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS 
    //////////////////////////////////////////////////////////////*/

    modifier isActive() {
        if (_exited) {
            revert StrategyExited();
        }
        _;
    }

    modifier onlyBentoBox() {
        if (msg.sender != address(bentoBox)) {
            revert OnlyBentoBox();
        }
        _;
    }

    modifier onlyExecutor() {
        if (!strategyExecutors[msg.sender]) {
            revert OnlyExecutor();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        STRATEGY CONFIG FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the status of the executors
    /// @param executor address of the executor to be updated
    /// @param status status of the exectuor to be updated
    function setStrategyExecutor(address executor, bool status)
        external
        onlyOwner
    {
        strategyExecutors[executor] = status;
        emit LogSetStrategyExecutor(executor, status);
    }

    /// @notice Sets the performance fee
    /// @param newFee new fee
    /// @dev should be less than 1e18 (cannot set it to 100%)
    function setFee(uint256 newFee) external onlyOwner {
        if (newFee >= 1e18) revert InvalidFee();
        fee = newFee;
        emit LogFeeUpdated(newFee);
    }

    /// @notice Sets the fee receiver
    /// @param newFeeTo address of the new fee receiver
    function setFeeTo(address newFeeTo) external onlyOwner {
        feeTo = newFeeTo;
        emit LogFeeToUpdated(newFeeTo);
    }

    /*//////////////////////////////////////////////////////////////
                        OVERRIDE FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    /// @notice Invests the underlying asset.
    /// @param amount The amount of tokens to invest.
    /// @dev Assume the contract's balance is greater than the amount.
    function _skim(uint256 amount) internal virtual;

    /// @notice Harvest any profits made and transfer them to address(this) or report a loss.
    /// @param balance The amount of tokens that have been invested.
    /// @return amountAdded The delta (+profit or -loss) that occured in contrast to `balance`.
    /// @dev amountAdded can be left at 0 when reporting profits (gas savings).
    /// amountAdded should not reflect any rewards or tokens the strategy received.
    /// Calculate the amount added based on what the current deposit is worth.
    /// (The Base Strategy harvest function accounts for rewards).
    function _harvest(uint256 balance)
        internal
        virtual
        returns (int256 amountAdded);

    /// @dev Withdraw the requested amount of the underlying tokens to address(this).
    /// @param amount The requested amount we want to withdraw.
    function _withdraw(uint256 amount) internal virtual;

    /// @notice Withdraw the maximum available amount of the invested assets to address(this).
    /// @dev This shouldn't revert (use try catch).
    function _exit() internal virtual;

    /// @notice Claim any reward tokens and optionally sell them for the underlying token.
    /// @dev Doesn't need to be implemented if we don't expect any rewards.
    function _harvestRewards() internal virtual {}

    /// @inheritdoc IStrategy
    function skim(uint256 amount) external override {
        _skim(amount);
    }

    /// @notice Harvest profits while preventing a sandwich attack exploit.
    /// @param maxBalanceInBentoBox The maximum balance of the underlying token that is allowed to be in BentoBox.
    /// @param rebalance Whether BentoBox should rebalance the strategy assets to acheive it's target allocation.
    /// @param maxChangeAmount When rebalancing - the maximum amount that will be deposited to or withdrawn from a strategy to BentoBox.
    /// @param harvestRewards If we want to claim any accrued reward tokens
    /// @dev maxBalance can be set to 0 to keep the previous value.
    /// @dev maxChangeAmount can be set to 0 to allow for full rebalancing.
    function safeHarvest(
        uint256 maxBalanceInBentoBox,
        bool rebalance,
        uint256 maxChangeAmount,
        bool harvestRewards
    ) external onlyExecutor {
        if (harvestRewards) {
            _harvestRewards();
        }

        if (maxBalanceInBentoBox > 0) {
            _maxBentoBoxBalance = maxBalanceInBentoBox;
        }

        bentoBox.harvest(address(strategyToken), rebalance, maxChangeAmount);
    }

    /** @inheritdoc IStrategy
    @dev Only BentoBox can call harvest on this strategy.
    @dev Ensures that (1) the caller was this contract (called through the safeHarvest function)
        and (2) that we are not being frontrun by a large BentoBox deposit when harvesting profits. */
    function harvest(uint256 balance, address sender)
        external
        override
        isActive
        onlyBentoBox
        returns (int256)
    {
        /** @dev Don't revert if conditions aren't met in order to allow
            BentoBox to continue execution as it might need to do a rebalance. */
        if (
            sender != address(this) ||
            bentoBox.totals(address(strategyToken)).elastic >
            _maxBentoBoxBalance ||
            balance == 0
        ) return int256(0);

        int256 amount = _harvest(balance);

        /** @dev We might have some underlying tokens in the contract that the _harvest call doesn't report. 
        E.g. reward tokens that have been sold into the underlying tokens which are now sitting in the contract.
        Meaning the amount returned by the internal _harvest function isn't necessary the final profit/loss amount */

        uint256 contractBalance = strategyToken.balanceOf(address(this)); // Reasonably assume this is less than type(int256).max

        if (amount > 0) {
            // _harvest reported a profit

            uint256 totalFee = (contractBalance * fee) / FEE_PRECISION;
            uint256 deltaProfit = contractBalance - totalFee;

            strategyToken.safeTransfer(feeTo, totalFee);

            emit LogPerformanceFee(strategyToken, totalFee);

            strategyToken.safeTransfer(address(bentoBox), deltaProfit);

            return int256(deltaProfit);
        } else if (contractBalance > 0) {
            // _harvest reported a loss but we have some tokens sitting in the contract

            int256 diff = amount + int256(contractBalance);

            if (diff > 0) {
                // We still made some profit.
                uint256 totalFee = (uint256(diff) * fee) / FEE_PRECISION;
                diff = diff - int256(totalFee);

                strategyToken.safeTransfer(feeTo, totalFee);
                emit LogPerformanceFee(strategyToken, totalFee);

                // Send the profit to BentoBox and reinvest the rest.
                strategyToken.safeTransfer(address(bentoBox), uint256(diff));
                _skim(contractBalance - uint256(diff) - totalFee);
            } else {
                // We made a loss but we have some tokens we can reinvest.

                _skim(contractBalance);
            }

            return diff;
        } else {
            // We made a loss.

            return amount;
        }
    }

    /// @inheritdoc IStrategy
    function withdraw(uint256 amount)
        external
        override
        isActive
        onlyBentoBox
        returns (uint256 actualAmount)
    {
        _withdraw(amount);
        // Make sure we send and report the exact same amount of tokens by using balanceOf.
        actualAmount = strategyToken.balanceOf(address(this));
        strategyToken.safeTransfer(address(bentoBox), actualAmount);
    }

    /// @inheritdoc IStrategy
    /// @dev Do not use isActive modifier here. Allow bentobox to call strategy.exit() multiple times
    /// This is to ensure that the strategy isn't locked if its (accidentally) set twice in a row as a token's strategy in bentobox.
    function exit(uint256 balance)
        external
        override
        onlyBentoBox
        returns (int256 amountAdded)
    {
        _exit();
        // Flag as exited, allowing the owner to manually deal with any amounts available later.
        _exited = true;
        // Check balance of token on the contract.
        uint256 actualBalance = strategyToken.balanceOf(address(this));
        // Calculate tokens added (or lost).
        // We reasonably assume actualBalance and balance are less than type(int256).max
        amountAdded = int256(actualBalance) - int256(balance);
        // Transfer all tokens to bentoBox.
        strategyToken.safeTransfer(address(bentoBox), actualBalance);
    }

    /** @dev After exited, the owner can perform ANY call. This is to rescue any funds that didn't
        get released during exit or got earned afterwards due to vesting or airdrops, etc. */
    function afterExit(
        address to,
        uint256 value,
        bytes memory data
    ) external onlyOwner returns (bool success) {
        if (!_exited) {
            revert StrategyNotExited();
        }
        (success, ) = to.call{value: value}(data);
        require(success);
    }

    function exited() public view returns (bool) {
        return _exited;
    }

    function maxBentoBoxBalance() public view returns (uint256) {
        return _maxBentoBoxBalance;
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

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

/**
 * @title IL2Pool
 * @author Aave
 * @notice Defines the basic extension interface for an L2 Aave Pool.
 **/
interface IL2Pool {
    struct ReserveConfigurationMap {
        //bit 0-15: LTV
        //bit 16-31: Liq. threshold
        //bit 32-47: Liq. bonus
        //bit 48-55: Decimals
        //bit 56: reserve is active
        //bit 57: reserve is frozen
        //bit 58: borrowing is enabled
        //bit 59: stable rate borrowing enabled
        //bit 60: asset is paused
        //bit 61: borrowing in isolation mode is enabled
        //bit 62-63: reserved
        //bit 64-79: reserve factor
        //bit 80-115 borrow cap in whole tokens, borrowCap == 0 => no cap
        //bit 116-151 supply cap in whole tokens, supplyCap == 0 => no cap
        //bit 152-167 liquidation protocol fee
        //bit 168-175 eMode category
        //bit 176-211 unbacked mint cap in whole tokens, unbackedMintCap == 0 => minting disabled
        //bit 212-251 debt ceiling for isolation mode with (ReserveConfiguration::DEBT_CEILING_DECIMALS) decimals
        //bit 252-255 unused

        uint256 data;
    }
    struct ReserveData {
        //stores the reserve configuration
        ReserveConfigurationMap configuration;
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex;
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        //variable borrow index. Expressed in ray
        uint128 variableBorrowIndex;
        //the current variable borrow rate. Expressed in ray
        uint128 currentVariableBorrowRate;
        //the current stable borrow rate. Expressed in ray
        uint128 currentStableBorrowRate;
        //timestamp of last update
        uint40 lastUpdateTimestamp;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint16 id;
        //aToken address
        address aTokenAddress;
        //stableDebtToken address
        address stableDebtTokenAddress;
        //variableDebtToken address
        address variableDebtTokenAddress;
        //address of the interest rate strategy
        address interestRateStrategyAddress;
        //the current treasury balance, scaled
        uint128 accruedToTreasury;
        //the outstanding unbacked aTokens minted through the bridging feature
        uint128 unbacked;
        //the outstanding debt borrowed against this asset in isolation mode
        uint128 isolationModeTotalDebt;
    }

    /**
     * @notice Returns the state and configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The state and configuration data of the reserve
     **/
    function getReserveData(address asset)
        external
        view
        returns (ReserveData memory);

    /**
     * @notice Supplies an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
     * - E.g. User supplies 100 USDC and gets in return 100 aUSDC
     * @param asset The address of the underlying asset to supply
     * @param amount The amount to be supplied
     * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
     *   is a different wallet
     * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     **/
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    /**
     * @notice Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
     * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
     * @param asset The address of the underlying asset to withdraw
     * @param amount The underlying amount to be withdrawn
     *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
     * @param to The address that will receive the underlying, same as msg.sender if the user
     *   wants to receive it on his own wallet, or a different address if the beneficiary is a
     *   different wallet
     * @return The final amount withdrawn
     **/
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    /**
     * @notice Calldata efficient wrapper of the supply function on behalf of the caller
     * @param args Arguments for the supply function packed in one bytes32
     *    96 bits       16 bits         128 bits      16 bits
     * | 0-padding | referralCode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     */
    function supply(bytes32 args) external;

    /**
     * @notice Calldata efficient wrapper of the supplyWithPermit function on behalf of the caller
     * @param args Arguments for the supply function packed in one bytes32
     *    56 bits    8 bits         32 bits           16 bits         128 bits      16 bits
     * | 0-padding | permitV | shortenedDeadline | referralCode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     * @param r The R parameter of ERC712 permit sig
     * @param s The S parameter of ERC712 permit sig
     */
    function supplyWithPermit(
        bytes32 args,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @notice Calldata efficient wrapper of the withdraw function, withdrawing to the caller
     * @param args Arguments for the withdraw function packed in one bytes32
     *    112 bits       128 bits      16 bits
     * | 0-padding | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     */
    function withdraw(bytes32 args) external;

    /**
     * @notice Calldata efficient wrapper of the borrow function, borrowing on behalf of the caller
     * @param args Arguments for the borrow function packed in one bytes32
     *    88 bits       16 bits             8 bits                 128 bits       16 bits
     * | 0-padding | referralCode | shortenedInterestRateMode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     */
    function borrow(bytes32 args) external;

    /**
     * @notice Calldata efficient wrapper of the repay function, repaying on behalf of the caller
     * @param args Arguments for the repay function packed in one bytes32
     *    104 bits             8 bits               128 bits       16 bits
     * | 0-padding | shortenedInterestRateMode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     * @return The final amount repaid
     */
    function repay(bytes32 args) external returns (uint256);

    /**
     * @notice Calldata efficient wrapper of the repayWithPermit function, repaying on behalf of the caller
     * @param args Arguments for the repayWithPermit function packed in one bytes32
     *    64 bits    8 bits        32 bits                   8 bits               128 bits       16 bits
     * | 0-padding | permitV | shortenedDeadline | shortenedInterestRateMode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     * @param r The R parameter of ERC712 permit sig
     * @param s The S parameter of ERC712 permit sig
     * @return The final amount repaid
     */
    function repayWithPermit(
        bytes32 args,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /**
     * @notice Calldata efficient wrapper of the repayWithATokens function
     * @param args Arguments for the repayWithATokens function packed in one bytes32
     *    104 bits             8 bits               128 bits       16 bits
     * | 0-padding | shortenedInterestRateMode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     * @return The final amount repaid
     */
    function repayWithATokens(bytes32 args) external returns (uint256);

    /**
     * @notice Calldata efficient wrapper of the swapBorrowRateMode function
     * @param args Arguments for the swapBorrowRateMode function packed in one bytes32
     *    232 bits            8 bits             16 bits
     * | 0-padding | shortenedInterestRateMode | assetId |
     * @dev assetId is the index of the asset in the reservesList.
     */
    function swapBorrowRateMode(bytes32 args) external;

    /**
     * @notice Calldata efficient wrapper of the rebalanceStableBorrowRate function
     * @param args Arguments for the rebalanceStableBorrowRate function packed in one bytes32
     *    80 bits      160 bits     16 bits
     * | 0-padding | user address | assetId |
     * @dev assetId is the index of the asset in the reservesList.
     */
    function rebalanceStableBorrowRate(bytes32 args) external;

    /**
     * @notice Calldata efficient wrapper of the setUserUseReserveAsCollateral function
     * @param args Arguments for the setUserUseReserveAsCollateral function packed in one bytes32
     *    239 bits         1 bit       16 bits
     * | 0-padding | useAsCollateral | assetId |
     * @dev assetId is the index of the asset in the reservesList.
     */
    function setUserUseReserveAsCollateral(bytes32 args) external;

    /**
     * @notice Calldata efficient wrapper of the liquidationCall function
     * @param args1 part of the arguments for the liquidationCall function packed in one bytes32
     *    64 bits      160 bits       16 bits         16 bits
     * | 0-padding | user address | debtAssetId | collateralAssetId |
     * @param args2 part of the arguments for the liquidationCall function packed in one bytes32
     *    127 bits       1 bit             128 bits
     * | 0-padding | receiveAToken | shortenedDebtToCover |
     * @dev the shortenedDebtToCover is cast to 256 bits at decode time,
     * if type(uint128).max the value will be expanded to type(uint256).max
     */
    function liquidationCall(bytes32 args1, bytes32 args2) external;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

/**
 * @title IAaveIncentivesController
 * @author Aave
 * @notice Defines the basic interface for an Aave Incentives Controller.
 **/
interface IAaveIncentivesController {
    function claimAllRewards(address[] calldata assets, address to)
        external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts);

    function getUserRewards(
        address[] calldata assets,
        address user,
        address reward
    ) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.10;

interface IStrategy {
    /// @notice Send the assets to the Strategy and call skim to invest them.
    /// @param amount The amount of tokens to invest.
    function skim(uint256 amount) external;

    /// @notice Harvest any profits made converted to the asset and pass them to the caller.
    /// @param balance The amount of tokens the caller thinks it has invested.
    /// @param sender The address of the initiator of this transaction. Can be used for reimbursements, etc.
    /// @return amountAdded The delta (+profit or -loss) that occured in contrast to `balance`.
    function harvest(uint256 balance, address sender)
        external
        returns (int256 amountAdded);

    /// @notice Withdraw assets. The returned amount can differ from the requested amount due to rounding.
    /// @dev The `actualAmount` should be very close to the amount.
    /// The difference should NOT be used to report a loss. That's what harvest is for.
    /// @param amount The requested amount the caller wants to withdraw.
    /// @return actualAmount The real amount that is withdrawn.
    function withdraw(uint256 amount) external returns (uint256 actualAmount);

    /// @notice Withdraw all assets in the safest way possible. This shouldn't fail.
    /// @param balance The amount of tokens the caller thinks it has invested.
    /// @return amountAdded The delta (+profit or -loss) that occured in contrast to `balance`.
    function exit(uint256 balance) external returns (int256 amountAdded);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IStrategy.sol";

interface IBentoBoxMinimal {
    struct Rebase {
        uint128 elastic;
        uint128 base;
    }

    struct StrategyData {
        uint64 strategyStartDate;
        uint64 targetPercentage;
        uint128 balance; // the balance of the strategy that BentoBox thinks is in there
    }

    function balanceOf(address, address) external view returns (uint256);

    function batch(bytes[] calldata calls, bool revertOnFail)
        external
        payable
        returns (bool[] memory successes, bytes[] memory results);

    function claimOwnership() external;

    function deploy(
        address masterContract,
        bytes calldata data,
        bool useCreate2
    ) external payable;

    function deposit(
        address token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external payable returns (uint256 amountOut, uint256 shareOut);

    function harvest(
        address token,
        bool balance,
        uint256 maxChangeAmount
    ) external;

    function masterContractApproved(address, address)
        external
        view
        returns (bool);

    function masterContractOf(address) external view returns (address);

    function nonces(address) external view returns (uint256);

    function owner() external view returns (address);

    function pendingOwner() external view returns (address);

    function pendingStrategy(address) external view returns (IStrategy);

    function registerProtocol() external;

    function setMasterContractApproval(
        address user,
        address masterContract,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function setStrategy(address token, address newStrategy) external;

    function setStrategyTargetPercentage(
        address token,
        uint64 targetPercentage_
    ) external;

    function strategy(address) external view returns (IStrategy);

    function strategyData(address)
        external
        view
        returns (
            uint64 strategyStartDate,
            uint64 targetPercentage,
            uint128 balance
        );

    function toAmount(
        address token,
        uint256 share,
        bool roundUp
    ) external view returns (uint256 amount);

    function toShare(
        address token,
        uint256 amount,
        bool roundUp
    ) external view returns (uint256 share);

    function totals(address) external view returns (Rebase memory totals_);

    function transfer(
        address token,
        address from,
        address to,
        uint256 share
    ) external;

    function transferMultiple(
        address token,
        address from,
        address[] calldata tos,
        uint256[] calldata shares
    ) external;

    function transferOwnership(
        address newOwner,
        bool direct,
        bool renounce
    ) external;

    function whitelistMasterContract(address masterContract, bool approved)
        external;

    function whitelistedMasterContracts(address) external view returns (bool);

    function withdraw(
        address token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256 amountOut, uint256 shareOut);
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}