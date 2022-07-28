/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-07-28
*/

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.10;

/**
 * @dev Contains the enum used to define valid Cozy states.
 * @dev All states except TRIGGERED are valid for sets, and all states except PAUSED are valid for markets/triggers.
 */
interface ICState {
  // The set of all Cozy states.
  enum CState {
    ACTIVE,
    FROZEN,
    PAUSED,
    TRIGGERED
  }
}

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
    }

    /*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

            // Divide z by the denominator.
            z := div(z, denominator)
        }
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

            // First, divide z - 1 by the denominator and add 1.
            // We allow z - 1 to underflow if z is 0, because we multiply the
            // end result by 0 if z is zero, ensuring we return 0 if z is zero.
            z := mul(iszero(iszero(z)), add(div(sub(z, 1), denominator), 1))
        }
    }

    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := scalar
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store scalar in z for now.
                    z := scalar
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, scalar)

                for {
                    // Shift n right by 1 before looping to halve it.
                    n := shr(1, n)
                } n {
                    // Shift n right by 1 each iteration to halve it.
                    n := shr(1, n)
                } {
                    // Revert immediately if x ** 2 would overflow.
                    // Equivalent to iszero(eq(div(xx, x), x)) here.
                    if shr(128, x) {
                        revert(0, 0)
                    }

                    // Store x squared.
                    let xx := mul(x, x)

                    // Round to the nearest number.
                    let xxRound := add(xx, half)

                    // Revert if xx + half overflowed.
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }

                    // Set x to scaled xxRound.
                    x := div(xxRound, scalar)

                    // If n is even:
                    if mod(n, 2) {
                        // Compute z * x.
                        let zx := mul(z, x)

                        // If z * x overflowed:
                        if iszero(eq(div(zx, x), z)) {
                            // Revert if x is non-zero.
                            if iszero(iszero(x)) {
                                revert(0, 0)
                            }
                        }

                        // Round to the nearest number.
                        let zxRound := add(zx, half)

                        // Revert if zx + half overflowed.
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }

                        // Return properly scaled zxRound.
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            // Start off with z at 1.
            z := 1

            // Used below to help find a nearby power of 2.
            let y := x

            // Find the lowest power of 2 that is at least sqrt(x).
            if iszero(lt(y, 0x100000000000000000000000000000000)) {
                y := shr(128, y) // Like dividing by 2 ** 128.
                z := shl(64, z) // Like multiplying by 2 ** 64.
            }
            if iszero(lt(y, 0x10000000000000000)) {
                y := shr(64, y) // Like dividing by 2 ** 64.
                z := shl(32, z) // Like multiplying by 2 ** 32.
            }
            if iszero(lt(y, 0x100000000)) {
                y := shr(32, y) // Like dividing by 2 ** 32.
                z := shl(16, z) // Like multiplying by 2 ** 16.
            }
            if iszero(lt(y, 0x10000)) {
                y := shr(16, y) // Like dividing by 2 ** 16.
                z := shl(8, z) // Like multiplying by 2 ** 8.
            }
            if iszero(lt(y, 0x100)) {
                y := shr(8, y) // Like dividing by 2 ** 8.
                z := shl(4, z) // Like multiplying by 2 ** 4.
            }
            if iszero(lt(y, 0x10)) {
                y := shr(4, y) // Like dividing by 2 ** 4.
                z := shl(2, z) // Like multiplying by 2 ** 2.
            }
            if iszero(lt(y, 0x8)) {
                // Equivalent to 2 ** z.
                z := shl(1, z)
            }

            // Shifting right by 1 is like dividing by 2.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // Compute a rounded down version of z.
            let zRoundDown := div(x, z)

            // If zRoundDown is smaller, use it.
            if lt(zRoundDown, z) {
                z := zRoundDown
            }
        }
    }
}

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
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

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
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

/**
 * @dev Interface that all cost models must conform to.
 */
interface ICostModel {
  /// @notice Returns the cost of purchasing protection as a percentage of the amount being purchased, as a wad.
  /// For example, if you are purchasing $200 of protection and this method returns 1e17, then the cost of
  /// the purchase is 200 * 1e17 / 1e18 = $20.
  /// @param utilization Current utilization of the market.
  /// @param newUtilization Utilization ratio of the market after purchasing protection.
  function costFactor(uint256 utilization, uint256 newUtilization) external view returns (uint256);

  /// @notice Gives the return value in assets of returning protection, as a percentage of
  /// the supplier fee pool, as a wad. For example, if the supplier fee pool currently has $100
  /// and this method returns 1e17, then you will get $100 * 1e17 / 1e18 = $10 in assets back.
  /// @param utilization Current utilization of the market.
  /// @param newUtilization Utilization ratio of the market after cancelling protection.
  function refundFactor(uint256 utilization, uint256 newUtilization) external view returns (uint256);
}

/**
 * @dev Interface that all decay models must conform to.
 */
interface IDecayModel {
  /// @notice Returns current decay rate of PToken value, as percent per second, where the percent is a wad.
  /// @param utilization Current utilization of the market.
  function decayRate(uint256 utilization) external view returns (uint256);
}

/**
 * @dev Interface that all drip models must conform to.
 */
interface IDripModel {
  /// @notice Returns the percentage of the fee pool that should be dripped to suppliers, per second, as a wad.
  /// @dev The returned value is not equivalent to the annual yield earned by suppliers. Annual yield can be
  /// computed as supplierFeePool * dripRate * secondsPerYear / totalAssets.
  /// @param utilization Current utilization of the set.
  function dripRate(uint256 utilization) external view returns (uint256);
}

/**
 * @dev Structs used to define parameters in sets and markets.
 * @dev A "zoc" is a unit with 4 decimal places. All numbers in these config structs are in zocs, i.e. a
 * value of 900 translates to 900/10,000 = 0.09, or 9%.
 */
interface IConfig {
  // Set-level configuration.
  struct SetConfig {
    uint256 leverageFactor; // The set's leverage factor.
    uint256 depositFee; // Fee applied on each deposit and mint.
    IDecayModel decayModel; // Contract defining the decay rate for PTokens in this set.
    IDripModel dripModel; // Contract defining the rate at which funds are dripped to suppliers for their yield.
  }

  // Market-level configuration.
  struct MarketInfo {
    address trigger; // Address of the trigger contract for this market.
    address costModel; // Contract defining the cost model for this market.
    uint16 weight; // Weight of this market. Sum of weights across all markets must sum to 100% (1e4, 1 zoc).
    uint16 purchaseFee; // Fee applied on each purchase.
  }

  // PTokens and are not eligible to claim protection until maturity. It takes `purchaseDelay` seconds for a PToken
  // to mature, but time during an InactivePeriod is not counted towards maturity. Similarly, there is a delay
  // between requesting a withdrawal and completing that withdrawal, and inactive periods do not count towards that
  // withdrawal delay.
  struct InactivePeriod {
    uint64 startTime; // Timestamp that this inactive period began.
    uint64 cumulativeDuration; // Cumulative inactive duration of all prior inactive periods and this inactive period at the point when this inactive period ended.
  }
}

/**
 * @notice Events for the Set.
 */
interface ISet is ICState {
  /// @dev Emitted when a user cancels protection. This is a market-level event.
  event Cancellation(address caller, address indexed receiver, address indexed owner, uint256 protection, uint256 ptokens, address indexed trigger, uint256 refund);

  /// @dev Emitted when a user claims their protection payout when a market is triggered. This is a market-level event.
  event Claim(address caller, address indexed receiver, address indexed owner, uint256 protection, uint256 ptokens, address indexed trigger);

  /// @dev Emitted when a user deposits assets or mints shares. This is a set-level event.
  event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

  /// @dev Emitted when a user purchases protection from a market. This is a market-level event.
  event Purchase(address indexed caller, address indexed owner, uint256 protection, uint256 ptokens, address indexed trigger, uint256 cost);

  /// @dev Emitted when a user withdraws assets or redeems shares. This is a set-level event.
  event Withdraw(address caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares, uint256 indexed withdrawalId);

  /// @dev Emitted when a user queues a withdrawal or redeem to be completed later. This is a set-level event.
  event WithdrawalPending(address caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares, uint256 indexed withdrawalId);
}

/**
 * @dev Helper methods for common math operations.
 */
library CozyMath {
  /// @dev Performs `x * y` without overflow checks.
  /// Only use this when you are sure `x * y` will not overflow.
  function unsafemul(uint256 x, uint256 y) internal pure returns (uint256 z) {
    assembly { z := mul(x, y) }
  }

  /// @dev Unchecked increment of the provided value.
  /// Realistically it's impossible to overflow a uint256 so this is always safe.
  function uncheckedIncrement(uint256 i) internal pure returns (uint256) {
    unchecked { return i + 1; }
  }

  /// @dev Performs `x / y` without divide by zero checks.
  /// Only use this when you are sure `y` is not zero.
  function unsafediv(uint256 x, uint256 y) internal pure returns (uint256 z) {
    // Only use this when you are sure y is not zero.
    assembly { z := div(x, y) }
  }

  /// @dev Returns `x - y` if the result is positive, or zero if `x - y` would overflow and result in a negative value.
  /// @dev Named doz as shorthand for difference or zero, see https://en.wikipedia.org/wiki/Monus#Natural_numbers.
  function doz(uint256 x, uint256 y) internal pure returns (uint256 z) {
    unchecked { z = x >=y ? x - y : 0; }
  }
}

/**
 * @dev Provides an `initializer` modifier for contracts that cannot use a constructor and need to ensure a method
 * is only called once. This is required for upgradeability patterns that use an implementation contract behind a proxy.
 * See the OpenZeppelin documentation for more information: https://docs.openzeppelin.com/contracts/4.x/api/proxy#Initializable
 */
abstract contract Initializable {
  /// @dev The number of times the contract has been initialized. This starts at zero, and is incremented with each
  // upgrade's new initializer method.
  uint256 public initializeCount;

  /// @dev Thrown when the initializer was already called.
  error CannotInitialize();

  /// @dev Only use this modifier on the most-derived contract. For contracts meant to be inherited from, make
  /// the initializers internal and call them in the most-derived contract's initializer. Because the internal
  /// initializers do not have a modifier, either manually ensure they cannot get called again, or add a check
  /// to enforce this (e.g. revert if address is not the zero address).
  modifier initializer(uint256 _expectedCount) {
    if (initializeCount != _expectedCount) revert CannotInitialize();
    initializeCount++;
    _;
  }
}

/**
 * @dev Facilitates packing and unpacking multiple values into a single 32 byte word.
 * @dev To reduce bytecode size and gas usage, no intermediate variables are used. This makes the methods hard
 * to read, so an annotated verbose version is provided in the comments of each method.
 */
library SlotEncoder {
  /// @dev For the given 32 byte `word`, insert a `value` given the `size` and `offset` of that value.
  /// @dev WARNING: No safety checks are implementing to ensure the `value` fits in the `size`. It is up to the
  /// caller to validate that.
  function write(bytes32 word, uint256 size, uint256 offset, uint256 value) internal pure returns (bytes32) {
    // First we generate a mask based on the size of the value. This mask is equal to 2 ** bits - 1.
    //   uint256 mask = (1 << size) - 1;
    //
    // Next we clean the relevant portion of the word. This ensures all bits used for the provided value,
    // size, and offset are set to zero.
    //   uint256 cleanedWord = uint256(word) & ~(mask << offset);
    //
    // We take the provided value and shift it by the specified offset so the bits are in the correct position.
    // That value is then bitwise-or'd with the cleaned word, which places the value in the correct position.
    //   return bytes32(cleanedWord | value << offset);
    return bytes32((uint256(word) & ~(((1 << size) - 1) << offset)) | value << offset);
  }

  /// @dev For the given 32 byte `word`, extract a value given its `size` and `offset`. The value is always returned
  /// as a uint256 and can be can be casted to other types as needed.
  function read(bytes32 word, uint256 size, uint256 offset) internal pure returns (uint256) {
    // First we generate a mask based on the size of the value. This mask is equal to 2 ** bits - 1.
    //   uint256 mask = (1 << size) - 1;
    //
    // We now shift the word by the provided offset, which places the bits in the correct position, and
    // use the mask to zero out the remaining bits.
    //   return uint256(word >> offset) & mask;
    return uint256(word >> offset) & ((1 << size) - 1);
  }
}

/**
 * @dev Defines the sizes and offsets for variables that are packed into a single slot.
 */
contract SlotEncodings {
  // -------- Market data --------
  uint256 internal constant ACTIVE_PROTECTION_SIZE = 112;
  uint256 internal constant ACTIVE_PROTECTION_OFFSET = 0;

  uint256 internal constant DECAY_RATE_SIZE = 112;
  uint256 internal constant DECAY_RATE_OFFSET = ACTIVE_PROTECTION_OFFSET + ACTIVE_PROTECTION_SIZE;

  uint256 internal constant LAST_DECAY_TIME_SIZE = 32;
  uint256 internal constant LAST_DECAY_TIME_OFFSET = DECAY_RATE_OFFSET + DECAY_RATE_SIZE;

  // -------- Market config --------
  // The three market configuration parameters are packed into a single word. The three parameters
  // take up 192 bits, leaving the upper 64 bits unused. The weight and purchase fee are zocs, and
  // therefore the have a max value of 10,000. While this means they can be represented by only 14
  // 14 bits, we use 16 bits because other fee values are not manually packed into a word and
  // Solidity does not offer a uint14 type. The sum of all weights in a market must sum to 10,000,
  // which is 100%.
  uint256 internal constant MC_COST_MODEL_SIZE = 160;
  uint256 internal constant MC_WEIGHT_SIZE = 16;
  uint256 internal constant MC_PURCHASE_FEE_SIZE = 16;

  uint256 internal constant MC_COST_MODEL_OFFSET = 0;
  uint256 internal constant MC_WEIGHT_OFFSET = MC_COST_MODEL_SIZE + MC_COST_MODEL_OFFSET;
  uint256 internal constant MC_PURCHASE_FEE_OFFSET = MC_WEIGHT_OFFSET + MC_WEIGHT_SIZE;

  // -------- Set inactive periods --------
  // The start time is the timestamp that this inactive period began, and the cumulative duration is the inactive
  // duration of all prior inactive periods and this inactive period at the point when this inactive period ended.
  uint256 internal constant IP_START_TIME_SIZE = 64;
  uint256 internal constant IP_CUMULATIVE_DURATION_SIZE = 64;

  uint256 internal constant IP_START_TIME_OFFSET = 0;
  uint256 internal constant IP_CUMULATIVE_DURATION_OFFSET = IP_START_TIME_OFFSET + IP_START_TIME_SIZE;
}

/**
 * @notice Modern and gas efficient ERC-20 + ERC-2612 implementation.
 * @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
 * @dev Modified from Solmate to reduce bytecode size and match the style of the rest of the codebase.
 * Original Solmate implementation: https://github.com/Rari-Capital/solmate/blob/eaaccf88ac5290299884437e1aee098a96583d54/src/tokens/ERC20.sol
 */
abstract contract SmallERC20 {
  // ------------------------
  // -------- Events --------
  // ------------------------

  /// @dev Emitted when `amount` tokens are moved from `from` to `to`.
  event Transfer(address indexed from, address indexed to, uint256 amount);

  /// @dev Emitted when the allowance of a `spender` for an `owner` is updated, where `amount` is the new allowance.
  event Approval(address indexed owner, address indexed spender, uint256 amount);

  // ------------------------
  // -------- Errors --------
  // ------------------------

  /// @dev Thrown when a permit is invalid. This can occur if the permit deadline has passed, or if provided
  /// signature did not recover to the expected address.
  error InvalidPermit();

  // ----------------------------------
  // -------- Metadata Storage --------
  // ----------------------------------

  /// @notice Returns the name of the token.
  string public name;

  /// @notice Returns the symbol of the token.
  string public symbol;

  /// @notice Returns the decimal places of the token.
  uint8 public decimals;

  // --------------------------------
  // -------- ERC-20 Storage --------
  // --------------------------------

  /// @notice Returns the amount of tokens in existence.
  uint256 public totalSupply;

  /// @notice Returns the amount of tokens owned by `account`.
  mapping(address => uint256) public balanceOf;

  /// @notice Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `holder`.
  /// @dev Mapping is from `holder` to `spender` to remaining allowance.
  mapping(address => mapping(address => uint256)) public allowance;

  // ----------------------------------
  // -------- ERC-2612 Storage --------
  // ----------------------------------

  /// @dev Chain ID at the time of deployment. This may change if a fork occurs.
  uint256 internal INITIAL_CHAIN_ID;

  /// @dev Domain separator at the time of deployment. This may change if a fork occurs.
  bytes32 internal INITIAL_DOMAIN_SEPARATOR;

  /// @notice Returns the `nonce` for the given `account`. The nonce is updated on each `permit`.
  mapping(address => uint256) public nonces;

  // -----------------------------
  // -------- Initializer --------
  // -----------------------------

  /// @dev Initializer which replaces the constructor since Cozy ERC20's are upgradeable.
  function __initSmallERC20(string memory _name, string memory _symbol, uint8 _decimals) internal {
    name = _name;
    symbol = _symbol;
    decimals = _decimals;

    INITIAL_CHAIN_ID = block.chainid;
    INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
  }

  // ------------------------------
  // -------- ERC-20 Logic --------
  // ------------------------------

  /// @notice Sets `_amount` as the allowance of `_spender` over the caller's tokens.
  function approve(address _spender, uint256 _amount) public virtual returns (bool) {
    return _approve(msg.sender, _spender, _amount);
  }

  /// @dev Implements the logic to set `_amount` as the allowance of `_spender` over the `_holder`s tokens.
  function _approve(address _holder, address _spender, uint256 _amount) internal returns (bool) {
    allowance[_holder][_spender] = _amount;
    emit Approval(_holder, _spender, _amount);
    return true;
  }

  /// @notice Moves `_amount` tokens from the caller's account to `_to`.
  function transfer(address _to, uint256 _amount) public virtual returns (bool) {
    return _transfer(msg.sender, _to, _amount);
  }

  /// @notice Moves `_amount` tokens from `_from` to `_to` using the allowance mechanism. `_amount` is then deducted
  /// from the caller's allowance.
  function transferFrom(address _from, address _to, uint256 _amount) public virtual returns (bool) {
    uint256 _allowed = allowance[_from][msg.sender]; // Saves gas for limited approvals.
    if (_allowed != type(uint256).max) allowance[_from][msg.sender] = _allowed - _amount;
    return _transfer(_from, _to, _amount);
  }

  /// @dev Implements the logic for transferring `_amount` tokens from `_from` to `_to`.
  function _transfer(address _from, address _to, uint256 _amount) internal returns (bool) {
    balanceOf[_from] -= _amount;
    // Cannot overflow because the sum of all user balances can't realistically exceed the max uint256 value.
    unchecked { balanceOf[_to] += _amount; }
    _emitTransfer(_from, _to, _amount);
    return true;
  }

  /// @dev Emits the transfer event, used to reduce bytecode size.
  function _emitTransfer(address _from, address _to, uint256 _amount) internal {
    emit Transfer(_from, _to, _amount);
  }

  // --------------------------------
  // -------- ERC-2612 Logic --------
  // --------------------------------

  /// @notice Sets `_value` as the allowance of `_spender` over `_owner`s tokens, given a signed approval from the
  /// owner.
  function permit(address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) public virtual {
    if (_deadline < block.timestamp) revert InvalidPermit();

    // Unchecked because the only math done is incrementing the owner's nonce which cannot realistically overflow.
    unchecked {
      address _recoveredAddress = ecrecover(
        keccak256(
          abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR(),
            keccak256(
              abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                _owner,
                _spender,
                _value,
                nonces[_owner]++,
                _deadline
              )
            )
          )
        ),
        _v,
        _r,
        _s
      );

      if (_recoveredAddress == address(0) || _recoveredAddress != _owner) revert InvalidPermit();
      _approve(_recoveredAddress, _spender, _value);
    }
  }

  /// @notice Returns the domain separator.
  function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
    return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
  }

  /// @dev Computes the current domain separator based on the chain's chain ID.
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

  // ------------------------------------------
  // -------- Internal Mint/Burn Logic --------
  // ------------------------------------------

  /// @dev Mints `_amount` tokens to `_to`.
  function _mint(address _to, uint256 _amount) internal virtual {
    totalSupply += _amount;
    // Cannot overflow because the sum of all user balances can't realistically exceed the max uint256 value.
    unchecked { balanceOf[_to] += _amount; }
    _emitTransfer(address(0), _to, _amount);
  }

  /// @dev Burns `_amount` tokens from `_from`.
  function _burn(address _from, uint256 _amount) internal virtual {
    balanceOf[_from] -= _amount;
    // Cannot underflow because a user's balance will never be larger than the total supply.
    unchecked { totalSupply -= _amount; }
    _emitTransfer(_from, address(0), _amount);
  }
}

/**
 * @notice Latently-fungible token (LFT) implementation. An LFT is a token that is initially non-transferrable
 * and non-fungible, but becomes transferrable and fungible at some time. The `balanceOf` method behaves the same
 * as an ERC-20 and returns the full balance. However, not all of those tokens are necessarily fungible and spendable.
 * A `balanceOfMatured` method is added which returns the amount of tokens that are fungible and can be spent. The
 * logic for determining matured balance can vary and must be implemented.
 */
abstract contract LFT is SmallERC20 {
  // Data saved off on each mint.
  struct MintMetadata {
    uint128 amount; // Amount of tokens minted.
    uint64 time; // Timestamp of the mint.
    uint64 delay; // Delay until these tokens mature and become fungible.
  }

  /// @notice Mapping from user address to all of their mints.
  mapping(address => MintMetadata[]) public mints;

  /// @dev Thrown when an operation cannot be performed because the user does not have a sufficient matured balance.
  error InsufficientBalance();

  /// @notice Returns the quantity of matured tokens held by the given `_user`.
  /// @dev A user's `balanceOfMatured` is computed by starting with `balanceOf[_user]` then subtracting the sum of
  /// all `amounts` from the  user's `mints` array that are not yet matured. How to determine when a given mint
  /// is matured is left to the implementer. It can be simple such as maturing when `block.timestamp >= time + delay`,
  /// or something more complex.
  function balanceOfMatured(address _user) public view virtual returns (uint256);

  /// @notice Moves `_amount` tokens from the caller's account to `_to`. Tokens must be matured to transfer them.
  function transfer(address _to, uint256 _amount) public override returns (bool) {
    if (balanceOfMatured(msg.sender) < _amount) revert InsufficientBalance();
    return super.transfer(_to, _amount);
  }

  /// @notice Moves `_amount` tokens from `_from` to `_to`. Tokens must be matured to transfer them.
  function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
    if (balanceOfMatured(_from) < _amount) revert InsufficientBalance();
    return super.transferFrom(_from, _to, _amount);
  }

  /// @notice Destroys `_amount` tokens from `_from`. Tokens must be matured to burn them.
  function _burn(address _from, uint256 _amount) internal override {
    if (balanceOfMatured(_from) < _amount) revert InsufficientBalance();
    super._burn(_from, _amount);
  }

  /// @notice Returns the array of metadata for all tokens minted to `_user`.
  function getMints(address _user) external view returns (MintMetadata[] memory) {
    return mints[_user];
  }
}

// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/UUPSUpgradeable.sol)

// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
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

// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

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

// OpenZeppelin Contracts v4.4.1 (utils/StorageSlot.sol)

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
library StorageSlot {
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

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967Upgrade {
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
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
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
            Address.functionDelegateCall(newImplementation, data);
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
        if (StorageSlot.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
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
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
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
        return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(Address.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            Address.isContract(IBeacon(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlot.getAddressSlot(_BEACON_SLOT).value = newBeacon;
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
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        }
    }
}

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
abstract contract UUPSUpgradeable is IERC1822Proxiable, ERC1967Upgrade {
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
}

/**
 * @dev Data types and events for the Manager.
 */
interface IManager is ICState, IConfig {
  // All fees that can be set by the Cozy admin.
  struct Fees {
    uint256 depositFeeReserves;  // Fee charged on deposit and min, allocated to the protocol reserves, denoted in zoc.
    uint256 depositFeeBackstop; // Fee charged on deposit and min, allocated to the protocol backstop, denoted in zoc.
    uint256 purchaseFeeReserves; // Fee charged on purchase, allocated to the protocol reserves, denoted in zoc.
    uint256 purchaseFeeBackstop; // Fee charged on purchase, allocated to the protocol backstop, denoted in zoc.
    uint256 cancellationFeeReserves; // Fee charged on cancellation, allocated to the protocol reserves, denoted in zoc.
    uint256 cancellationFeeBackstop; // Fee charged on cancellation, allocated to the protocol backstop, denoted in zoc.
  }

  // All delays that can be set by the Cozy admin.
  struct Delays {
    uint256 configUpdateDelay; // Duration between when a set/market configuration updates are queued and when they can be executed.
    uint256 configUpdateGracePeriod; // Defines how long the admin has to execute a configuration change, once it can be executed.
    uint256 minDepositDuration; // The minimum duration before a withdrawal can be initiated after a deposit.
    uint256 withdrawDelay; // If not paused, suppliers must queue a withdrawal and wait this long before completing the withdrawal.
    uint256 purchaseDelay; // Protection does not mature (i.e. it cannot claim funds from a trigger) until this delay elapses after purchase.
  }

  // A market or set is considered inactive when it's FROZEN or PAUSED.
  struct InactivityData {
    uint64 inactiveTransitionTime; // The timestamp the set/market transitioned from active to inactive, if currently inactive. 0 otherwise.
    InactivePeriod[] periods; // Array of all inactive periods for a set or market.
  }

  /// @dev Emitted when a new set is given permission to pull funds from the backstop if it has a shortfall after a trigger.
  event BackstopApprovalStatusUpdated(address indexed set, bool status);

  /// @dev Emitted when the Cozy configuration delays are updated, and when a set is created.
  event ConfigParamsUpdated(uint256 configUpdateDelay, uint256 configUpdateGracePeriod);

  /// @dev Emitted when a Set admin's queued set and market configuration updates are applied, and when a set is created.
  event ConfigUpdatesFinalized(address indexed set, SetConfig setConfig, MarketInfo[] marketInfos);

  /// @dev Emitted when a Set admin queues new set and/or market configurations.
  event ConfigUpdatesQueued(address indexed set, SetConfig setConfig, MarketInfo[] marketInfos, uint256 updateTime, uint256 updateDeadline);

  /// @dev Emitted when accrued Cozy reserve fees and backstop fees are swept from a Set to the Cozy admin (for reserves) and backstop.
  event CozyFeesClaimed(address indexed set);

  /// @dev Emitted when the delays affecting user actions are initialized or updated by the Cozy admin.
  event DelaysUpdated(uint256 minDepositDuration, uint256 withdrawDelay, uint256 purchaseDelay);

  /// @dev Emitted when the deposit cap for an asset is updated by the Cozy admin.
  event DepositCapUpdated(ERC20 indexed asset, uint256 depositCap);

  /// @dev Emitted when the Cozy protocol fees are updated by the Cozy admin.
  /// Changes to fees for the Set admin are emitted in ConfigUpdatesQueued and ConfigUpdatesFinalized.
  event FeesUpdated(Fees fees);

  /// @dev Emitted when a market, defined by it's trigger address, changes state.
  event MarketStateUpdated(address indexed set, address indexed trigger, CState indexed state);

  /// @dev Emitted when the admin of a set is updated.
  event SetAdminUpdated(address indexed set, address indexed admin);

  /// @dev Emitted when the Set admin claims their portion of fees.
  event SetFeesClaimed(address indexed set, address _receiver);

  /// @dev Emitted when the Set's pauser is updated.
  event SetPauserUpdated(address indexed set, address indexed pauser);

  /// @dev Emitted when the Set's state is updated.
  event SetStateUpdated(address indexed set, CState indexed state);
}

/**
 * @dev Contract module providing admin functionality, intended to be used through inheritance.
 * @dev No modifiers are provided to reduce bloat from unused code (even though this should be removed by the
 * compiler), as the child contract may have more complex authentication requirements than just a modifier from
 * this contract.
 */
abstract contract Administrable {
  /// @notice Contract administrator.
  address public admin;

  /// @dev Reserve slots in this contract's storage layout to be used in future upgrades.
  uint256[50] private __gap;

  /// @dev Emitted when the admin address is updated.
  event AdminUpdated(address indexed newAdmin);

  /// @dev Thrown when the caller is not authorized to perform the action.
  error Unauthorized();

  /// @dev Intended to be called only one time in the most-derived contract's initializer or constructor.
  /// @dev This internal method has no guard: we trust the contract inheriting from this to only allow this
  /// method to be called once.
  function __initAdministrable(address _admin) internal {
    admin = _admin;
    emit AdminUpdated(_admin);
  }

  /// @notice Update admin of the contract to `_newAdmin`.
  /// @param _newAdmin The new admin of the contract.
  function updateAdmin(address _newAdmin) external {
    if (msg.sender != admin) revert Unauthorized();
    emit AdminUpdated(_newAdmin);
    admin = _newAdmin;
  }
}

/**
 * @dev Contract module providing admin and pauser functionality, intended to be used through inheritance.
 * @dev No modifiers are provided to avoid the chance of dead code, as the child contract may
 * have more complex authentication requirements than just a modifier from this contract.
 */
abstract contract Governable is Administrable {
  /// @notice Contract pauser.
  address public pauser;

  /// @dev Reserve slots in this contract's storage layout to be used in future upgrades.
  uint256[50] private __gap;

  /// @dev Emitted when the pauser address is updated.
  event PauserUpdated(address indexed newPauser);

  /// @dev Intended to be called only one time in the most-derived contract's initializer.
  /// @dev This internal method has no guard: we trust the contract inheriting from this to only allow this
  /// method to be called once.
  function __initGovernable(address _admin, address _pauser) internal {
    __initAdministrable(_admin);
    pauser = _pauser;
    emit PauserUpdated(_pauser);
  }

  /// @notice Update pauser to `_newPauser`.
  /// @param _newPauser The new pauser.
  function updatePauser(address _newPauser) external {
    if (msg.sender != admin && msg.sender != pauser) revert Unauthorized();
    emit PauserUpdated(_newPauser);
    pauser = _newPauser;
  }
}

/**
 * @dev Interface for WETH9.
 */
interface IWeth {
  /// @notice Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `holder`.
  function allowance(address holder, address spender) view external returns (uint256 remainingAllowance);

  /// @notice Sets `amount` as the allowance of `spender` over the caller's tokens.
  function approve(address spender, uint256 amount) external returns (bool success);

  /// @notice Returns the amount of tokens owned by `account`.
  function balanceOf(address account) view external returns (uint256 balance);

  /// @notice Returns the decimal places of the token.
  function decimals() view external returns (uint8);

  /// @notice Deposit ETH and receive WETH.
  function deposit() payable external;

  /// @notice Returns the name of the token.
  function name() view external returns (string memory);

  /// @notice Returns the symbol of the token.
  function symbol() view external returns (string memory);

  /// @notice Returns the amount of tokens in existence.
  function totalSupply() view external returns (uint256 supply);

  /// @notice Moves `amount` tokens from the caller's account to `to`.
  function transfer(address to, uint256 amount) external returns (bool success);

  /// @notice Moves `amount` tokens from `from` to `to` using the allowance mechanism. `amount` is then deducted
  /// from the caller's allowance.
  function transferFrom(address from, address to, uint256 amount) external returns (bool success);

  /// @notice Burn WETH to withdraw ETH.
  function withdraw(uint256 amount) external;
}

/**
 * @notice Stores the values for protocol-level immutables. Proxy contracts cannot have conventional immutables since
 * the logic contract is separate from the storage contract. By storing all immutables in this contract, we can have
 * the logic contracts read and save the values during construction.
 */
contract ImmutablesBeacon {
  /// @notice Cozy protocol Backstop.
  address public immutable backstop;

  /// @notice Cozy protocol Manager.
  address public immutable manager;

  /// @notice Cozy protocol PTokenBeacon.
  address public immutable ptokenBeacon;

  /// @notice Cozy protocol PTokenFactory.
  address public immutable ptokenFactory;

  /// @notice Cozy protocol SetBeacon.
  address public immutable setBeacon;

  /// @notice Cozy protocol SetFactory.
  address public immutable setFactory;

  /// @notice WETH address
  address public immutable weth;

  constructor(
    address _backstop,
    address _manager,
    address _ptokenBeacon,
    address _ptokenFactory,
    address _setBeacon,
    address _setFactory,
    address _weth
  ) {
    backstop = _backstop;
    manager = _manager;
    ptokenBeacon = _ptokenBeacon;
    ptokenFactory = _ptokenFactory;
    setBeacon = _setBeacon;
    setFactory = _setFactory;
    weth = _weth;
  }
}

/**
 * @notice There is a single Backstop instance in the Cozy protocol. Its purpose is to serve as a backup source
 * of funds to payout PToken holders after a trigger if the Set does not have enough funds. In a set with one market
 * this will never be the case. But sets with multiple markets are leveraged and sell more protection than there are
 * available funds. Therefore if two or more markets trigger, the funds held by that set would normally be insufficient
 * to payout all PToken holders.
 *
 * The Backstop serves to reduce the risk of PToken holders not getting paid out in such cases. The Cozy protocol may
 * charge fees on deposits/mints, purchases, and cancellations which fund the backstop. Additionally, anyone can
 * provide funds to the backstop by sending ETH or tokens to it. The Cozy admin can approve a set to pull from the
 * backstop. If a set is approved, and it has insufficient funds to payout PToken holders after a trigger, the set
 * will pull from the backstop to cover the deficit.
 */
contract Backstop is UUPSUpgradeable, Initializable {
  using SafeTransferLib for ERC20;

  /// @notice Version number of this implementation contract.
  uint256 public constant VERSION = 0;

  /// @notice WETH9 address.
  IWeth public immutable weth;

  /// @notice Address of the Cozy protocol manager.
  Manager public immutable manager;

  /// @dev Thrown when the caller is not authorized to perform the action.
  error Unauthorized();

  /// @dev Address of the Cozy protocol ImmutablesBeacon contract.
  constructor(ImmutablesBeacon _immutablesBeacon) {
    weth = IWeth(_immutablesBeacon.weth());
    manager = Manager(_immutablesBeacon.manager());
  }

  /// @dev This function should revert when `msg.sender` is not authorized to upgrade the contract.
  /// It's called by `upgradeTo` `upgradeToAndCall`.
  function _authorizeUpgrade(address /* _newImplementation */) internal view override {
    if (msg.sender != manager.admin()) revert Unauthorized();
  }

  /// @dev This contract should never hold ETH. Any ETH received is wrapped to WETH.
  receive() external payable {
    deposit();
  }

  /// @notice If someone forces ETH to this contract outside of transfers, e.g. with `selfdestruct`, call this method
  /// to deposit that ETH.
  function deposit() public {
    weth.deposit{value: address(this).balance}();
  }

  /// @notice Provide `_set` with `_amount` of tokens, where `_amount` is a quantity of that set's underlying `asset`.
  function claim(Set _set, uint256 _amount) external {
    // State changes for all sets are initiated in the manager, which also stores the backstop authorization
    // statuses. Therefore, if the call came from the manager we can trust that the claim is valid.
    if (msg.sender != address(manager)) revert Unauthorized();
    ERC20 _asset = _set.asset();
    uint256 _balance = _asset.balanceOf(address(this));
    _asset.safeTransfer(address(_set), _balance < _amount ? _balance : _amount);
  }
}

/**
 * @dev Wrappers over Solidity's casting operators that revert if the input overflows the new type when downcasted.
 */
library SafeCastLib {
  /// @dev Thrown when a downcast fails.
  error SafeCastFailed();

  /// @dev Downcast `x` to a `uint128`, reverting if `x > type(uint128).max`.
  function safeCastTo128(uint256 x) internal pure returns (uint128 y) {
    if (x >= 1 << 128) revert SafeCastFailed();
    y = uint128(x);
  }

  function safeCastTo64(uint256 x) internal pure returns (uint64 y) {
    if (x >= 1 << 64) revert SafeCastFailed();
    y = uint64(x);
  }
}

/// @notice Users receive protection tokens when purchasing protection. Each protection token
/// contract is associated with a single market, and protection tokens are minted to a user
/// proportional to the amount of protection they purchase. When a market triggers, protection
/// tokens can be redeemed to claim assets.
contract PToken is LFT, Initializable {
  using SafeCastLib for uint256;

  /// @notice Version number of this implementation contract.
  uint256 public constant VERSION = 0;

  /// @notice Address of the Cozy protocol manager.
  Manager public immutable manager;

  /// @notice The set this token is for. Markets in a set are uniquely identified by their trigger.
  address public set;

  /// @notice The trigger this token is for. Markets in a set are uniquely identified by their trigger.
  address public trigger;

  /// @dev Thrown when the caller is not authorized to perform the action.
  error Unauthorized();

  /// @dev Address of the Cozy protocol ImmutablesBeacon contract.
  constructor(ImmutablesBeacon _immutablesBeacon) {
    manager = Manager(_immutablesBeacon.manager());
  }

  /// @dev WARNING: DO NOT change this function signature or input to the `initializer` modifier. This method is
  /// called by the `PTokenFactory` which requires this exact signature.
  function initialize(
    uint8 _decimals,
    address _set,
    address _trigger
  ) external initializer(0) {
    __initSmallERC20("Cozy PToken", "CPT", _decimals);
    set = _set;
    trigger = _trigger;
  }

  function mint(address _to, uint256 _amount) external {
    if (msg.sender != set) revert Unauthorized();
    mints[_to].push(MintMetadata(_amount.safeCastTo128(), block.timestamp.safeCastTo64(), manager.purchaseDelay().safeCastTo64()));
    _mint(_to, _amount);
  }

  function burn(address _from, uint256 _amount) external {
    if (msg.sender != set) revert Unauthorized();
    _burn(_from, _amount);
  }

  function setAllowance(address _owner, address _spender, uint256 _amount) external {
    if (msg.sender != set) revert Unauthorized();
    allowance[_owner][_spender] = _amount;
  }

  function balanceOfMatured(address _user) public view override returns (uint256) {
    // We read the number of total tokens they have, and subtract any un-matured protection. This is required
    // to ensure that tokens transferred to the user are counted, as they would not be in the protections array.
    uint256 _balance = balanceOf[_user];
    MintMetadata[] memory _mints = mints[_user];

    IManager.InactivityData memory _inactivityData = manager.getMarketInactivityData(set, trigger);

    for (uint256 i = 0; i < _mints.length; i++) {
      uint256 _activeTimeElapsed = manager.getDelayTimeAccrued(
        _mints[i].time,
        // If _inactiveTransitionTime > 0, the market is in an inactive state, and so we calculate the current
        // inactive period duration.
        _inactivityData.inactiveTransitionTime > 0 ? block.timestamp - _inactivityData.inactiveTransitionTime : 0,
        _inactivityData.periods
      );
      if (_activeTimeElapsed < _mints[i].delay) {
        _balance -= _mints[i].amount;
      }
    }
    return _balance;
  }
}

// OpenZeppelin Contracts v4.4.1 (proxy/beacon/BeaconProxy.sol)

// OpenZeppelin Contracts (last updated v4.6.0) (proxy/Proxy.sol)

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _beforeFallback();
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _fallback();
    }

    /**
     * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
     * call, or as part of the Solidity `fallback` or `receive` functions.
     *
     * If overridden should call `super._beforeFallback()`.
     */
    function _beforeFallback() internal virtual {}
}

/**
 * @dev This contract implements a proxy that gets the implementation address for each call from a {UpgradeableBeacon}.
 *
 * The beacon address is stored in storage slot `uint256(keccak256('eip1967.proxy.beacon')) - 1`, so that it doesn't
 * conflict with the storage layout of the implementation behind the proxy.
 *
 * _Available since v3.4._
 */
contract BeaconProxy is Proxy, ERC1967Upgrade {
    /**
     * @dev Initializes the proxy with `beacon`.
     *
     * If `data` is nonempty, it's used as data in a delegate call to the implementation returned by the beacon. This
     * will typically be an encoded function call, and allows initializating the storage of the proxy like a Solidity
     * constructor.
     *
     * Requirements:
     *
     * - `beacon` must be a contract with the interface {IBeacon}.
     */
    constructor(address beacon, bytes memory data) payable {
        assert(_BEACON_SLOT == bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1));
        _upgradeBeaconToAndCall(beacon, data, false);
    }

    /**
     * @dev Returns the current beacon address.
     */
    function _beacon() internal view virtual returns (address) {
        return _getBeacon();
    }

    /**
     * @dev Returns the current implementation address of the associated beacon.
     */
    function _implementation() internal view virtual override returns (address) {
        return IBeacon(_getBeacon()).implementation();
    }

    /**
     * @dev Changes the proxy to use a new beacon. Deprecated: see {_upgradeBeaconToAndCall}.
     *
     * If `data` is nonempty, it's used as data in a delegate call to the implementation returned by the beacon.
     *
     * Requirements:
     *
     * - `beacon` must be a contract.
     * - The implementation returned by `beacon` must be a contract.
     */
    function _setBeacon(address beacon, bytes memory data) internal virtual {
        _upgradeBeaconToAndCall(beacon, data, false);
    }
}

/**
 * @dev This contract is a proxy that gets the PToken's implementation address for each call from the PTokenBeacon
 *
 * The beacon address is stored in storage slot `uint256(keccak256('eip1967.proxy.beacon')) - 1`, so that it doesn't
 * conflict with the storage layout of the implementation behind the proxy.
 */
contract PTokenBeaconProxy is BeaconProxy {
  constructor(address _ptokenBeacon, bytes memory _data) BeaconProxy(_ptokenBeacon, _data) payable {}
}

contract PTokenFactory {
  address public immutable ptokenBeacon;

  event PTokenDeployed(PToken ptoken, uint8 decimals, address indexed set, address indexed trigger);

  constructor(address _ptokenBeacon) {
    ptokenBeacon = _ptokenBeacon;
  }

  function deployPToken(uint8 _decimals, address _set, address _trigger) external returns (PToken _ptoken) {
    // We generate the salt from the set-trigger pairing, which must be unique, and concatenate it with the chain ID
    // to prevent the same PToken address existing on multiple chains for different sets or triggers.
    bytes32 _salt = keccak256(abi.encode(_set, _trigger, block.chainid));

    // Deploy and initialize the PToken.
    bytes memory _data = abi.encodeCall(PToken.initialize, (_decimals, _set, _trigger));
    _ptoken = PToken(address(new PTokenBeaconProxy{salt: _salt}(ptokenBeacon, _data)));
    emit PTokenDeployed(_ptoken, _decimals, _set, _trigger);
  }
}

/**
 * @dev This contract is a proxy that gets the Set's implementation address for each call from the SetBeacon
 *
 * The beacon address is stored in storage slot `uint256(keccak256('eip1967.proxy.beacon')) - 1`, so that it doesn't
 * conflict with the storage layout of the implementation behind the proxy.
 */
contract SetBeaconProxy is BeaconProxy {
  constructor(address _setBeacon, bytes memory _data) BeaconProxy(_setBeacon, _data) payable {}
}

contract SetFactory is IConfig {
  address public immutable setBeacon;

  event SetDeployed(Set set, ERC20 indexed asset);

  constructor(address _setBeacon) {
    setBeacon = _setBeacon;
  }

  function deploySet(
    ERC20 _asset,
    uint256 _leverageFactor,
    uint256 _depositFee,
    IDecayModel _decayModel,
    IDripModel _dripModel,
    MarketInfo[] memory _marketInfos,
    bytes32 _salt
  ) public returns (Set _set) {
    // We take the user-provided salt and concatenate it with the chain ID before hashing. This is required because
    // CREATE2 with a user provided salt or CREATE both make it easy for an attacker to create a malicious Set
    // on one chain and pass it off as a reputable Set from another chain since the two have the same address.
    _salt = keccak256(abi.encode(_salt, block.chainid));

    // Deploy and initialize the new Set.
    bytes memory _data = abi.encodeCall(Set.initialize, (_asset, _leverageFactor, _depositFee, _decayModel, _dripModel, _marketInfos));
    _set = Set(address(new SetBeaconProxy{salt: _salt}(setBeacon, _data)));
    emit SetDeployed(_set, _asset);
  }
}

contract Manager is UUPSUpgradeable, Governable, IManager, SlotEncodings, Initializable {
  using SlotEncoder for bytes32;
  using SafeCastLib for uint256;

  uint256 internal constant WAD = 1e18;
  uint256 internal constant ZOC = 1e4;

  /// @notice Max fee for deposit and purchase.
  /// - Protocol deposit fee for reserves + protocol deposit fee for backstop <= MAX_FEE.
  /// - Protocol purchase fee for reserves + protocol purchase fee for backstop <= MAX_FEE.
  //  - Protocol cancellation fee for reserves + protocol cancellation fee for backstop <= MAX_FEE.
  /// - Set deposit fee <= MAX_FEE.
  /// - Market purchase fee <= MAX_FEE.
  uint256 public constant MAX_FEE = ZOC / 2;

  /// @notice Version number of this implementation contract.
  uint256 public constant VERSION = 0;

  /// @notice Cozy protocol Backstop.
  Backstop public immutable backstop;

  /// @notice Cozy protocol PTokenFactory.
  PTokenFactory public immutable ptokenFactory;

  /// @notice Cozy protocol SetFactory.
  SetFactory public immutable setFactory;

  /// @notice Protocol fees that can be applied on deposit/mint, purchase, and cancellation.
  Fees public fees;

  // Protocol delays and durations, in seconds.
  uint256 public withdrawDelay;
  uint256 public purchaseDelay;
  uint256 public configUpdateDelay;
  uint256 public minDepositDuration;
  // Period after configUpdateDelay, after signalling for a config update, that a config update can be executed.
  uint256 public configUpdateGracePeriod;

  mapping(Set => address) public setAdmin; // Maps from set address to its admin address.
  mapping(Set => address) public setPauser; // Maps from set address to its pauser address.

  // Maps from set address to a hash representing queued SetConfig and MarketInfo[] updates. This hash is used to prove that the
  // SetConfig and MarketInfo[] params used when applying config updates are identical to the queued updates. This strategy is used
  // instead of storing non-hashed SetConfig and MarketInfo[] for gas optimization and to avoid dynamic array manipulation.
  mapping(Set => bytes32) public queuedConfigUpdateHash;
  // Maps from set address to the earliest timestamp at which finalizeUpdateConfigs can be called to apply config updates queued by updateConfigs.
  mapping(Set => uint256) public configUpdateTime;
  // Maps from set address to the latest timestamp after configUpdateTime at which finalizeUpdateConfigs can be called to apply config updates
  // queued by updateConfigs. After this timestamp, the queued config updates expire and can no longer be applied.
  mapping(Set => uint256) public configUpdateDeadline;

  // Maps from set address to metadata about previous inactive periods for sets.
  mapping(Set => InactivityData) public setInactivityData;
  // Maps from set address to trigger address to metadata about previous inactive periods for markets.
  mapping(Set => mapping(address => InactivityData)) public marketInactivityData;

  // Maximum amount of assets that can be deposited into the set. Zero is used to mean "no cap".
  mapping(ERC20 => uint256) private depositCap;

  // Information on a given set.
  struct SetData {
    bool exists; // When a set is created, this is updated to true.
    bool approved; // If true, this set can use funds from the backstop.
  }
  mapping(Set => SetData) public sets;

  // Used to update backstop approvals.
  struct BackstopApproval {
    Set set;
    bool status;
  }

  // Errors
  error InvalidConfiguration();
  error InvalidSet();
  error InvalidState();
  error InvalidStateTransition();

  /// @param _immutablesBeacon Address of the Cozy protocol ImmutablesBeacon contract.
  constructor(ImmutablesBeacon _immutablesBeacon) {
    backstop = Backstop(payable(_immutablesBeacon.backstop()));
    ptokenFactory = PTokenFactory(_immutablesBeacon.ptokenFactory());
    setFactory = SetFactory(_immutablesBeacon.setFactory());
  }

  // -------------------------------
  // -------- Proxy Methods --------
  // -------------------------------

  function initializeV0(
    address _admin,
    address _pauser,
    Delays memory _delays,
    Fees memory _fees
  ) external initializer(0) {
    __initGovernable(_admin, _pauser);
    if (_delays.configUpdateDelay <= _delays.minDepositDuration + _delays.withdrawDelay || _delays.configUpdateDelay <= _delays.purchaseDelay) revert InvalidConfiguration();

    configUpdateDelay = _delays.configUpdateDelay;
    configUpdateGracePeriod = _delays.configUpdateGracePeriod;

    _updateFees(_fees);
    _updateUserDelays(_delays.minDepositDuration, _delays.withdrawDelay, _delays.purchaseDelay);
  }

  /// @dev This function should revert when `msg.sender` is not authorized to upgrade the contract.
  /// It's called by `upgradeTo` `upgradeToAndCall`.
  function _authorizeUpgrade(address /* _newImplementation */) internal view override {
    _assertCallerIsAdmin();
  }

  // ------------------------------------
  // -------- Cozy Admin Actions --------
  // ------------------------------------

  /// @notice Update the protocol fees.
  /// @param _fees The new protocol fees.
  function updateFees(Fees memory _fees) external {
    _assertCallerIsAdmin();
    _updateFees(_fees);
  }

  /// @notice Update user-related protocol delays.
  /// @param _minDepositDuration The new minimum deposit duration, in seconds.
  /// @param _withdrawDelay The new withdraw delay, in seconds.
  /// @param _purchaseDelay The new purchase delay, in seconds.
  function updateUserDelays(uint256 _minDepositDuration, uint256 _withdrawDelay, uint256 _purchaseDelay) external {
    _assertCallerIsAdmin();
    _updateUserDelays(_minDepositDuration, _withdrawDelay, _purchaseDelay);
  }

  /// @notice Update params related to config updates.
  /// @param _configUpdateDelay The new config update delay, in seconds.
  /// @param _configUpdateGracePeriod The new config update grace period, in seconds.
  function updateConfigParams(uint256 _configUpdateDelay, uint256 _configUpdateGracePeriod) external {
    _assertCallerIsAdmin();
    if (_configUpdateDelay <= minDepositDuration + withdrawDelay || _configUpdateDelay <= purchaseDelay) revert InvalidConfiguration();
    emit ConfigParamsUpdated(_configUpdateDelay, _configUpdateGracePeriod);
    configUpdateDelay = _configUpdateDelay;
    configUpdateGracePeriod = _configUpdateGracePeriod;
  }

  function updateDepositCap(ERC20 _asset, uint256 _newDepositCap) external {
    _assertCallerIsAdmin();
    depositCap[_asset] = _newDepositCap;
    emit DepositCapUpdated(_asset, _newDepositCap);
  }

  // Pass in an array of sets and change all of their approval statuses.
  function updateBackstopApprovals(BackstopApproval[] calldata _approvals) external {
    _assertCallerIsAdmin();
    for (uint256 i = 0; i < _approvals.length; i++) {
      SetData storage _set = sets[_approvals[i].set];
      if (!_set.exists) revert InvalidSet();
      _set.approved = _approvals[i].status;
      emit BackstopApprovalStatusUpdated(address(_approvals[i].set), _approvals[i].status);
    }
  }

  // -----------------------------------
  // -------- Set Admin Actions --------
  // -----------------------------------

  function pause(Set _set) external {
    CState _currentSetState = _getSetState(_set);
    if (!isValidSetStateTransition(_set, msg.sender, _currentSetState, CState.PAUSED)) revert InvalidStateTransition();
    _updateSetInactivePeriods(_set, _currentSetState, CState.PAUSED);
    _set.pause();
    emit SetStateUpdated(address(_set), CState.PAUSED);
  }

  function unpause(Set _set) external {
    CState _currentSetState = _getSetState(_set);
    if (!isAdmin(_set, msg.sender) || _currentSetState != CState.PAUSED) revert InvalidStateTransition();
    CState _newSetState = isAnyMarketFrozen(_set) ? CState.FROZEN : CState.ACTIVE;
    _updateSetInactivePeriods(_set, _currentSetState, _newSetState);
    _set.unpause(_newSetState);
    emit SetStateUpdated(address(_set), _newSetState);
  }

  function updateSetAdmin(Set _set, address _admin) external {
    _assertCallerIsLocalAdmin(_set);
    setAdmin[_set] = _admin;
    emit SetAdminUpdated(address(_set), _admin);
  }

  function updateSetPauser(Set _set, address _pauser) external {
    if (msg.sender != setPauser[_set] && !isLocalSetAdmin(_set, msg.sender)) revert Unauthorized();
    setPauser[_set] = _pauser;
    emit SetPauserUpdated(address(_set), _pauser);
  }

  function claimSetFees(Set _set, address _receiver) external {
    _assertCallerIsLocalAdmin(_set);
    emit SetFeesClaimed(address(_set), _receiver);
    _set.claimSetFees(_receiver);
  }

  /// @notice Signal an update to the set config and market configs. Existing queued updates are overwritten.
  /// @param _set The set to be updated.
  /// @param _setConfig The new set config.
  /// @param _marketInfos The array of new market configs, sorted by trigger address. Updating triggered markets is
  /// disallowed, so this array should not contain triggered markets. The array may also include config for new markets.
  function updateConfigs(Set _set, SetConfig memory _setConfig, MarketInfo[] memory _marketInfos) external {
    if (!isAdmin(_set, msg.sender)) revert Unauthorized();
    if (!isValidUpdate(_set, _setConfig, _marketInfos)) revert InvalidConfiguration();

    // Hash stored to ensure only queued updates can be applied.
    queuedConfigUpdateHash[_set] = keccak256(abi.encode(_setConfig, _marketInfos));

    uint256 _configUpdateTime = block.timestamp + configUpdateDelay;
    uint256 _configUpdateDeadline = _configUpdateTime + configUpdateGracePeriod;
    emit ConfigUpdatesQueued(address(_set), _setConfig, _marketInfos, _configUpdateTime, _configUpdateDeadline);
    configUpdateTime[_set] = _configUpdateTime;
    configUpdateDeadline[_set] = _configUpdateDeadline;
  }

  /// @notice Execute queued updates to set config and market configs.
  /// @param _set The set to be updated.
  /// @param _setConfig The new set config. Must be identical to the queued set config updates.
  /// @param _marketInfos The array of new market configs. Must be identical to the queued market config updates.
  function finalizeUpdateConfigs(Set _set, SetConfig memory _setConfig, MarketInfo[] memory _marketInfos) external {
    if (_getSetState(_set) != CState.ACTIVE) revert InvalidState();
    if (block.timestamp < configUpdateTime[_set]) revert InvalidStateTransition();
    if (block.timestamp > configUpdateDeadline[_set]) revert InvalidStateTransition();
    if (keccak256(abi.encode(_setConfig, _marketInfos)) != queuedConfigUpdateHash[_set]) revert InvalidConfiguration();

    // Before we execute the config update, verify that any new markets use a trigger that is ACTIVE. We use
    // the same for loop to add the set to the trigger's set list.
    for (uint256 i = 0; i < _marketInfos.length; i = _uncheckedIncrement(i)) {
      address _trigger = _marketInfos[i].trigger;
      if (isMarket(_set, _trigger)) continue;
      if (_getTriggerState(_trigger) != CState.ACTIVE) revert InvalidConfiguration(); // Only active markets can be initialized.
      ITrigger(_trigger).addSet(_set); // Add the set to the trigger's array.
    }

    // Execute the config update.
    _set.updateConfigs(
      _setConfig.leverageFactor,
      _setConfig.depositFee,
      _setConfig.decayModel,
      _setConfig.dripModel,
      _marketInfos
    );

    // Ensure no existing market's utilization becomes >= 100% with the new leverage factor and weights.
    // This would be cheaper to check in the Set itself, but we do it here (1) to reduce the Set bytecode
    // size, and (2) it's logically cleaner to have all config update validation in this contract, instead
    // of split between the two.
    // We don't use a strict greater than here (i.e. we don't allow 100% utilization after this rebalance) because
    // due to precision loss you can end up with utilization over 100% that gets floored down to 100%. In those
    // cases, the configuration update would be allowed even though it's insolvent.
    for (uint256 i = 0; i < _marketInfos.length; i = _uncheckedIncrement(i)) {
      if (_set.utilization(_marketInfos[i].trigger) >= WAD) revert InvalidConfiguration();
    }

    emit ConfigUpdatesFinalized(address(_set), _setConfig, _marketInfos);
  }

  // --------------------------------
  // -------- Market Actions --------
  // --------------------------------

  function updateMarketState(Set _set, CState _newMarketState) external {
    // -------- Market --------

    address _trigger = msg.sender;
    CState _currentMarketState = _getMarketState(_set, _trigger);

    // If the from and to states are the same, we return early. In this case, `isValidMarketStateTransition` would
    // return false and this call would revert. However, we prefer silently returning to maximize the set of triggers
    // that Cozy can support. For example, a trigger may store an array of sets and trigger each of those sets when
    // the trigger toggles. If a trigger is in that array twice, reverting here would prevent updating state for all
    // triggers in the array, whereas this allows duplicates to be handled. This can of course be handled by using
    // try/catch in the trigger, but we aim to support as many triggers as possible while minimizing the burden for
    // trigger creators.
    if (_currentMarketState == _newMarketState) return;

    if (!isValidMarketStateTransition(_set, _trigger, _currentMarketState, _newMarketState)) revert InvalidStateTransition();

    CState _currentSetState = _getSetState(_set);
    if (_currentSetState != CState.PAUSED) {
      if (_newMarketState == CState.ACTIVE) {
        // If the current set state is not paused and the market is transitioning to active, the market's inactive
        // periods array should be updated, and the market's inactive transition time should be reset.
        _updateMarketInactivePeriods(_set, _trigger);
      } else if (_currentMarketState == CState.ACTIVE) {
          // If set is not paused and the market is now transitioning from active to frozen or triggered, the market's
          // inactive transition time should be updated to the current timestamp. In the case that the set is paused, the
          // market's inactive transition time should have already been updated when the set transitioned to paused. It
          // should also be reset when the set transitions out of paused if the market is active.
          marketInactivityData[_set][_trigger].inactiveTransitionTime = block.timestamp.safeCastTo64();
      }

      if (_newMarketState == CState.TRIGGERED) {
        // Decay/fees do not accrue while the set is paused or the market is triggered, so we update the market now.
        _set.accrueDecay(_trigger);
      }
    }

    if (_newMarketState == CState.TRIGGERED) {
      // If there is a shortfall, have the backstop send the excess funds to the set.
      uint256 _shortfall = _set.shortfall(_trigger);
      if (_shortfall > 0 && isApprovedForBackstop(_set)) {
        backstop.claim(_set, _shortfall);
        _set.sync();
      }
    }

    _set.updateMarketState(_trigger, _newMarketState);
    emit MarketStateUpdated(address(_set), _trigger, _newMarketState);

    // -------- Set --------

    // If the set is not PAUSED, its state gets updated.
    if (_currentSetState != CState.PAUSED) {
      CState _newSetState = _newMarketState == CState.FROZEN || isAnyMarketFrozen(_set) ? CState.FROZEN : CState.ACTIVE;
      if (_currentSetState == _newSetState) return;
      if (!isValidSetStateTransition(_set, _trigger, _currentSetState, _newSetState)) revert InvalidStateTransition();

      _updateSetInactivePeriods(_set, _currentSetState, _newSetState);
      _set.updateSetState(_newSetState);
      emit SetStateUpdated(address(_set), _newSetState);
    }
  }

  // ----------------------------------------
  // -------- Permissionless Actions --------
  // ----------------------------------------

  function claimCozyFees(address[] calldata _sets) external {
    for (uint256 i = 0; i < _sets.length; i++) {
      Set(_sets[i]).claimCozyFees(admin, address(backstop));
      emit CozyFeesClaimed(_sets[i]);
    }
  }

  function createSet(
    address _admin,
    address _pauser,
    ERC20 _asset,
    SetConfig memory _setConfig,
    MarketInfo[] memory _marketInfos,
    bytes32 _salt
  ) external returns (Set _set) {
    if (!isValidConfiguration(_setConfig, _marketInfos)) revert InvalidConfiguration();

    _set = setFactory.deploySet(
      _asset,
      _setConfig.leverageFactor,
      _setConfig.depositFee,
      _setConfig.decayModel,
      _setConfig.dripModel,
      _marketInfos,
      _salt
    );
    sets[_set].exists = true;

    // Ensure the trigger is ACTIVE, and if a set address is not yet assigned in the trigger contract, do so here.
    for (uint256 i = 0; i < _marketInfos.length; i++) {
      address _trigger = _marketInfos[i].trigger;

      if (_getTriggerState(_trigger) != CState.ACTIVE) revert InvalidConfiguration(); // Only active markets can be initialized.

      ITrigger(_trigger).addSet(_set);
    }

    emit ConfigUpdatesFinalized(address(_set), _setConfig, _marketInfos);

    // Assign the users authorized to modify that set.
    _addAuth(_set, _admin, _pauser);
  }

  // ----------------------------
  // -------- Validation --------
  // ----------------------------

  function validateFees(Fees memory _fees) public pure returns (bool) {
    return (
      _fees.depositFeeReserves + _fees.depositFeeBackstop <= MAX_FEE &&
      _fees.purchaseFeeReserves + _fees.purchaseFeeBackstop <= MAX_FEE &&
      _fees.cancellationFeeReserves + _fees.cancellationFeeBackstop <= MAX_FEE
    );
  }

  function isValidUpdate(Set _set, SetConfig memory _setConfig, MarketInfo[] memory _marketInfos) public view returns (bool) {
    // Validate the configuration parameters.
    if (!isValidConfiguration(_setConfig, _marketInfos)) return false;

    uint256 _numUntriggeredMarkets = 0;
    for (uint256 i = 0; i < _marketInfos.length; i++) {
      address _trigger = _marketInfos[i].trigger;
      // Updating triggered markets is not allowed. During the initializer, the `Set._initializeMarket` method enforces
      // that the specified set is active, therefore we don't need to worry about checking the state in that case.
      if (_getMarketState(_set, _trigger) == CState.TRIGGERED) return false;

      // Used to check if the number of MarketInfos is >= to the number of untriggered markets.
      if (isMarket(_set, _trigger)) _numUntriggeredMarkets++;
    }

    // Confirm _marketInfos includes MarketInfo for all existing untriggered markets.
    if (_numUntriggeredMarkets != _getNumMarkets(_set) - _set.numTriggeredMarkets()) return false;

    return true;
  }

  /// @notice Validate set config and market configs.
  /// @param _setConfig The set config.
  /// @param _marketInfos The array of new market configs, sorted by trigger address. Updating triggered markets is
  /// disallowed, so this array should not contain triggered markets. The array may also include config for new markets.
  function isValidConfiguration(SetConfig memory _setConfig, MarketInfo[] memory _marketInfos) public pure returns (bool) {
    // Validate set configuration.
    if (_setConfig.leverageFactor < ZOC) return false;
    if (_setConfig.depositFee > MAX_FEE) return false;
    if (_setConfig.leverageFactor > ZOC * _marketInfos.length) return false;

    // Validate market configurations.
    uint256 _weightSum = 0;
    uint256 _maxWeight = 0;
    for (uint256 i = 0; i < _marketInfos.length; i++) {
      address _trigger = _marketInfos[i].trigger;
      if (i > 0 && _trigger <= _marketInfos[i - 1].trigger) return false; // Array not sorted or includes duplicates.
      if (_marketInfos[i].purchaseFee > MAX_FEE) return false; // Purchase fee too high.

      uint256 _weight = _marketInfos[i].weight;
      _weightSum += _weight;
      if (_weight > _maxWeight) _maxWeight = _weight;
    }

    // The sum of weights in a set must equal 100%.
    if (_weightSum != ZOC) return false;

    // Validate a market cannot have more protection available than amount supplied to the set (ignoring triggers).
    // In other words, the maximum leverage factor for a set is 1 / max(marketWeights). This means we need
    // `leverageFactor / zoc > zoc / max(marketWeights)`, which we rearrange below to avoid precision loss.
    if (_setConfig.leverageFactor > ZOC * ZOC / _maxWeight) return false;

    return true;
  }

  /// @notice Check if a state transition is valid for a set.
  /// @param _set Address of the set to check if the state transition is valid for.
  /// @param _who The address that would use the Set contract to update the set state.
  /// @param _from The initial state of the set.
  /// @param _to The new state of the set.
  function isValidSetStateTransition(Set _set, address _who, CState _from, CState _to) public view returns (bool) {
    // STATE TRANSITION RULES FOR SETS.
    // Sets cannot be in the TRIGGERED state, but all other states are valid. To read the below table:
    //   - Rows headers are the "from" state,
    //   - Column headers are the "to" state.
    //   - Cells describe whether that transition is allowed.
    //   - Numbers in parentheses indicate conditional transitions with details described in footnotes.
    //   - Letters in parentheses indicate who can perform the transition with details described in footnotes.
    //
    // | From / To | ACTIVE      | FROZEN      | PAUSED   | TRIGGERED |
    // | --------- | ----------- | ----------- | -------- | --------- |
    // | ACTIVE    | -           | true (1, T) | true (P) | false     |
    // | FROZEN    | true (0, T) | -           | true (P) | false     |
    // | PAUSED    | true (0, A) | true (1, A) | -        | false     |
    // | TRIGGERED | -           | -           | -        | -         |
    //
    // (0) Only allowed if number of frozen markets == 0.
    // (1) Only allowed if number of frozen markets >= 1.
    // (A) Only allowed if msg.sender is any admin (both Cozy-level and set-level allowed).
    // (P) Only allowed if msg.sender is any admin or any pauser (both Cozy-level and set-level allowed).
    // (T) Only allowed if msg.sender == trigger.

    // First we check disallowed transitions. We cannot transition into TRIGGERED.
    if (_to == CState.TRIGGERED ) return false;

    // Now verify the transition is allowed.
    return
      // The PAUSED column.
      (_to == CState.PAUSED && isAdminOrPauser(_set, _who))
      // The ACTIVE-FROZEN cell.
      || (_from == CState.ACTIVE && _to == CState.FROZEN && isAnyMarketFrozen(_set) && isMarket(_set, _who))
      // The FROZEN-ACTIVE cell.
      || (_from == CState.FROZEN && _to == CState.ACTIVE && !isAnyMarketFrozen(_set) && isMarket(_set, _who))
      // The PAUSED-ACTIVE cell.
      || (_from == CState.PAUSED && _to == CState.ACTIVE && !isAnyMarketFrozen(_set) && isAdmin(_set, _who))
      // The PAUSED-FROZEN cell.
      || (_from == CState.PAUSED && _to == CState.FROZEN && isAnyMarketFrozen(_set) && isAdmin(_set, _who));
  }

  /// @notice Check if a state transition is valid for a market in a set.
  /// @param _set Address of the set to check if the state transition is valid for.
  /// @param _who The address that would use the Set contract to update the market state.
  /// @param _from The initial state of the market.
  /// @param _to The new state of the market.
  function isValidMarketStateTransition(Set _set, address _who, CState _from, CState _to) public view returns (bool) {
    // STATE TRANSITION RULES FOR MARKETS.
    // Markets cannot be in the PAUSED state, but all other states are valid. To read the below table:
    //   - Rows headers are the "from" state.
    //   - Column headers are the "to" state.
    //   - Cells describe whether that transition is allowed.
    //   - Letters in parentheses indicate who can perform the transition with details described in footnotes.
    //
    // | From / To | ACTIVE   | FROZEN   | PAUSED | TRIGGERED |
    // | --------- | -------- | -------- | ------ | --------- |
    // | ACTIVE    | -        | true (T) | false  | true (T)  |
    // | FROZEN    | true (T) | -        | false  | true (T)  |
    // | PAUSED    | -        | -        | -      | -         |
    // | TRIGGERED | false    | false    | false  | -         |
    //
    // (T) Only allowed if msg.sender == trigger.

    // First we check disallowed transitions. We cannot transfer out of TRIGGERED or into PAUSED.
    if (_from == CState.TRIGGERED || _to == CState.PAUSED) return false;

    // Now we verify authentication: Only the trigger may transition a market's state.
    if (!isMarket(_set, _who)) return false;

    // Now verify the transition is allowed.
    return
      // We allow the same from and to states, since it becomes a no-op.
      (_from == _to)
      // The ACTIVE-FROZEN cell.
      || (_from == CState.ACTIVE && _to == CState.FROZEN)
      // The ACTIVE-TRIGGERED cell.
      || (_from == CState.ACTIVE && _to == CState.TRIGGERED)
      // The FROZEN-ACTIVE cell.
      || (_from == CState.FROZEN && _to == CState.ACTIVE)
      // The FROZEN-TRIGGERED cell.
      || (_from == CState.FROZEN && _to == CState.TRIGGERED);
  }

  // -------------------------------
  // -------- Authorization --------
  // -------------------------------

  function isAdmin(Set _set, address _who) public view returns (bool) {
    return isLocalSetAdmin(_set, _who) || _who == admin;
  }

  function isLocalSetAdmin(Set _set, address _who) public view returns (bool) {
    return _who == setAdmin[_set];
  }

  function isPauser(Set _set, address _who) public view returns (bool) {
    return _who == setPauser[_set] || _who == pauser;
  }

  function isAdminOrPauser(Set _set, address _who) public view returns (bool) {
    return isAdmin(_set, _who) || isPauser(_set, _who);
  }

  // -------------------------------
  // -------- State Getters --------
  // -------------------------------

  function isMarket(Set _set, address _who) public view returns (bool) {
    return _set.dataApd(_who).read(LAST_DECAY_TIME_SIZE, LAST_DECAY_TIME_OFFSET) > 0;
  }

  function isAnyMarketFrozen(Set _set) public view returns (bool) {
    address[] memory _triggers = _allTriggers(_set);
    for (uint i = 0; i < _triggers.length; i++) {
      if (_getMarketState(_set, _triggers[i]) == CState.FROZEN) return true;
    }
    return false;
  }

  /// @notice Checks if the specified set is approved for the backstop.
  /// @param _set The set to check.
  function isApprovedForBackstop(Set _set) public view returns (bool) {
    return sets[_set].approved;
  }

  /// @notice Returns the maximum amount of assets that can be deposited into a set that uses `_asset`.
  function getDepositCap(ERC20 _asset) external view returns (uint256) {
    uint256 _depositCap = depositCap[_asset];
    // Treat uninitialized deposit caps as no caps. Until a cap is added, there is no limit on deposits for the asset.
    return _depositCap == 0 ? type(uint256).max : _depositCap;
  }

  function depositFees() external view returns (uint256 _reserveFee, uint256 _backstopFee) {
    _reserveFee = fees.depositFeeReserves;
    _backstopFee = fees.depositFeeBackstop;
  }

  function purchaseFees() external view returns (uint256 _reserveFee, uint256 _backstopFee) {
    _reserveFee = fees.purchaseFeeReserves;
    _backstopFee = fees.purchaseFeeBackstop;
  }

  function cancellationFees() external view returns (uint256 _reserveFee, uint256 _backstopFee) {
    _reserveFee = fees.cancellationFeeReserves;
    _backstopFee = fees.cancellationFeeBackstop;
  }

  function getMarketInactivityData(address _set, address _trigger) external view returns (InactivityData memory) {
    return marketInactivityData[Set(_set)][_trigger];
  }

  /// @notice Get the amount of delay time that has accrued since a timestamp.
  /// @param _startTime Timestamp to check how much delay has accrued since.
  /// @param _currentInactiveDuration The amount of time that has elapsed in the current inactive period, if currently
  /// in an inactive state.
  /// @param _inactivePeriods Array of InactivePeriods.
  function getDelayTimeAccrued(
    uint256 _startTime,
    uint256 _currentInactiveDuration,
    InactivePeriod[] memory _inactivePeriods
  ) public view returns (uint256) {
    uint256 _inactiveDurationAfterStartTime = _currentInactiveDuration;

    if (_inactivePeriods.length > 0) {
      _inactiveDurationAfterStartTime += (_inactivePeriods[_inactivePeriods.length - 1].cumulativeDuration - inactiveDurationBeforeTimestampLookup(_startTime, _inactivePeriods));
    }
    return block.timestamp - _startTime - _inactiveDurationAfterStartTime;
  }

  function getWithdrawDelayTimeAccrued(
    Set _set,
    uint256 _startTime,
    CState _setState
  ) external view returns (uint256 _activeTimeElapsed) {
    InactivityData memory _inactivityData = setInactivityData[_set];

    _activeTimeElapsed = getDelayTimeAccrued(
      _startTime,
      _setState == CState.ACTIVE ? 0 : _elapsedTime(_inactivityData.inactiveTransitionTime),
      _inactivityData.periods
    );
  }

  // Perform a binary search to lookup the cumulative inactive duration before a timestamp.
  function inactiveDurationBeforeTimestampLookup(
    uint256 _timestamp,
    InactivePeriod[] memory _inactivePeriods
  ) public pure returns (uint256) {
    uint256 _high = _inactivePeriods.length;
    uint256 _low = 0;
    while (_low < _high) {
      uint256 _mid = (_low + _high) / 2;
      if (_inactivePeriods[_mid].startTime >= _timestamp) {
        _high = _mid;
      } else {
        _low = _mid + 1;
      }
    }
    // If _high == 0, there are no inactive periods before _timestamp.
    return _high == 0 ? 0 : _inactivePeriods[_high - 1].cumulativeDuration;
  }

  // ----------------------------------
  // -------- Internal Helpers --------
  // ----------------------------------

  function _updateFees(Fees memory _fees) internal {
    if (!validateFees(_fees)) revert InvalidConfiguration();
    emit FeesUpdated(_fees);
    fees = _fees;
  }

  function _updateUserDelays(uint256 _minDepositDuration, uint256 _withdrawDelay, uint256 _purchaseDelay) internal {
    uint256 _configUpdateDelay = configUpdateDelay; // Saves an extra SLOAD.
    if (_configUpdateDelay <= _minDepositDuration + _withdrawDelay || _configUpdateDelay <= _purchaseDelay) revert InvalidConfiguration();
    emit DelaysUpdated(_minDepositDuration, _withdrawDelay, _purchaseDelay);
    minDepositDuration = _minDepositDuration;
    withdrawDelay = _withdrawDelay;
    purchaseDelay = _purchaseDelay;
  }

  function _addAuth(Set _set, address _admin, address _pauser) internal {
    setAdmin[_set] = _admin;
    setPauser[_set] = _pauser;
    emit SetAdminUpdated(address(_set), _admin);
    emit SetPauserUpdated(address(_set), _pauser);
  }

  // Update a market's inactive periods array with a new entry for the current inactive period and
  // reset its inactive transition time.
  function _updateMarketInactivePeriods(Set _set, address _trigger) internal {
    InactivityData storage _inactivityData = marketInactivityData[_set][_trigger];
    uint64 _inactiveTransitionTime = _inactivityData.inactiveTransitionTime; // Saves an extra SLOAD.

    _inactivityData.periods.push(InactivePeriod(_inactiveTransitionTime, _getNewCumulativePreviousInactiveDuration(
      _inactiveTransitionTime,
      _inactivityData.periods
    )));

    _inactivityData.inactiveTransitionTime = 0; // Reset inactiveTransitionTime for the market.
  }

  function _updateSetInactivePeriods(Set _set, CState _oldSetState, CState _newSetState) internal {
    InactivityData storage _setInactivityData = setInactivityData[_set];

    if (_oldSetState == CState.ACTIVE) {
      // When transitioning the set state from active to an inactive state, we update the inactiveTransitionTime.
      _setInactivityData.inactiveTransitionTime = block.timestamp.safeCastTo64();
    } else if (_oldSetState == CState.PAUSED) {
      // When transitioning the set state from paused to another state, we need to update each active market's
      // inactivePeriods array and reset their inactiveTransitionTime, since markets rely on set state to determine
      // if they're paused.
      address[] memory _triggers = _allTriggers(_set);
      for (uint256 i = 0; i < _triggers.length; i = _uncheckedIncrement(i)) {
        if (_getMarketState(_set, _triggers[i]) == CState.ACTIVE) {
          _updateMarketInactivePeriods(_set, _triggers[i]);
        }
      }
    }

    if (_newSetState == CState.ACTIVE) {
      // If transitioning set state from inactive to active, we need to update the set's inactivePeriods array and
      // reset the inactiveTransitionTime.
      _setInactivityData.periods.push(InactivePeriod(
          _setInactivityData.inactiveTransitionTime,
          _getNewCumulativePreviousInactiveDuration(_setInactivityData.inactiveTransitionTime, _setInactivityData.periods)
        )
      );
      _setInactivityData.inactiveTransitionTime = 0;
    } else if (_newSetState == CState.PAUSED) {
      // If transitioning set state to paused, we need to update inactiveTransition time for any active markets,
      // since markets rely on set level state to determine if they're paused.
      address[] memory _triggers = _allTriggers(_set);
      for (uint256 i = 0; i < _triggers.length; i = _uncheckedIncrement(i)) {
        if (_getMarketState(_set, _triggers[i]) == CState.ACTIVE) {
          marketInactivityData[_set][_triggers[i]].inactiveTransitionTime = block.timestamp.safeCastTo64();
        }
      }
    }
  }

  /// @dev Get the new cumulative previous inactive duration by adding the current inactive period's duration to the
  // most recently computed cumulative inactive duration value.
  function _getNewCumulativePreviousInactiveDuration(
    uint64 _inactiveTransitionTime,
    InactivePeriod[] memory _inactivePeriods
  ) internal view returns (uint64) {
    uint256 _numInactivePeriods = _inactivePeriods.length;
    uint256 _priorCumulativeDuration = _numInactivePeriods > 0 ? _inactivePeriods[_numInactivePeriods - 1].cumulativeDuration : 0;
    return (_priorCumulativeDuration + (block.timestamp - _inactiveTransitionTime)).safeCastTo64();
  }

  function _allTriggers(Set _set) internal view returns (address[] memory _triggers) {
    uint256 _numMarkets = _getNumMarkets(_set);
    _triggers = new address[](_numMarkets);

    for (uint256 i = 0; i < _numMarkets; i = _uncheckedIncrement(i)) {
      _triggers[i] = _set.triggers(i);
    }
  }

  function _uncheckedIncrement(uint i) internal pure returns (uint256) {
    unchecked { return i + 1; }
  }

  function _elapsedTime(uint256 _time) internal view returns (uint256) {
    unchecked {
      // All time values passed to this function are only set using block.timestamp, which of course
      // monotonically increases, therefore this subtraction cannot overflow.
      return block.timestamp - _time;
    }
  }

  function _getSetState(Set _set) internal view returns (CState) {
    return _getMarketState(_set, address(_set));
  }

  function _getMarketState(Set _set, address _trigger) internal view returns (CState) {
    return _set.state(_trigger);
  }

  function _getTriggerState(address _trigger) internal returns (CState) {
    return ITrigger(_trigger).state();
  }

  function _getNumMarkets(Set _set) internal view returns (uint256) {
    return _set.numMarkets();
  }

  function _assertCallerIsAdmin() internal view {
    if (msg.sender != admin) revert Unauthorized();
  }

  function _assertCallerIsLocalAdmin(Set _set) internal view {
    if (!isLocalSetAdmin(_set, msg.sender)) revert Unauthorized();
  }
}

/**
 * @notice All protection markets live within a set.
 *
 * @dev A set's architecture is as follows:
 *   - The set itself is an ERC-20 token and conforms to the ERC-4626 standard. This means that
 *     when depositing funds (supplying protection), the address of the receipt token received
 *     is the address of this contract.
 *   - The set's initializer deploys n ERC-20 PTokens, where n is length of the MarketInfo[]
 *     array provided during initialization. Each PToken is a protection market, where the PToken
 *     represents the user's claim on protection (i.e. a claim on funds supplied to the set),
 *     which is redeemable for the underlying asset if the state of the associated trigger is
 *     in the TRIGGERED state.
 *
 * @dev Notes on rounding conventions that shares and PTokens must follow are below, taken  from
 * the EIP-4626 spec: https://eips.ethereum.org/EIPS/eip-4626#security-considerations
 *   Finally, ERC-4626 Vault implementers should be aware of the need for specific, opposing rounding
 *   directions across the different mutable and view methods, as it is considered most secure to
 *   favor the Vault itself during calculations over its users:
 *
 *   If (1) it’s calculating how many shares to issue to a user for a certain amount of the underlying
 *   tokens they provide or (2) it’s determining the amount of the underlying tokens to transfer to
 *   them for returning a certain amount of shares, it should round down.
 *
 *   If (1) it’s calculating the amount of shares a user has to supply to receive a given amount of
 *   the underlying tokens or (2) it’s calculating the amount of underlying tokens a user has to
 *   provide to receive a certain amount of shares, it should round up.
 *
 * @dev There are no reentrancy checks. Using this with malicious tokens as the `asset` can lead to vulnerabilities.
 */
contract Set is LFT, ICState, ISet, SlotEncodings, Initializable {
  using FixedPointMathLib for uint256;
  using CozyMath for uint256;
  using SafeCastLib for uint256;
  using SafeTransferLib for ERC20;
  using SlotEncoder for bytes32;

  uint256 internal constant ZOC = 1e4;
  uint256 internal constant ZOC2 = 1e8;
  uint256 internal constant WAD = 1e18;
  uint256 internal constant WAD_ZOC2 = 1e26;

  /// @notice Version number of this implementation contract.
  uint256 public constant VERSION = 0;

  /// @notice Address of the Cozy protocol Manager.
  Manager public immutable manager;

  /// @notice Address of the Cozy protocol PTokenFactory.
  PTokenFactory public immutable ptokenFactory;

  // -------- State --------

  /// @notice Stores the current state for a market, or for the set itself.
  mapping(address => CState) public state;

  // -------- Market data --------

  /// @notice Stores the active protection, decay rate, and last decay time.
  /// @dev The values are packed into a single word to reduce bytecode size and gas usage compared to structs.
  mapping(address => bytes32) public dataApd; // Data for active protection and decay.

  /// @notice Stores a market's current decayAccumulator, which is how much PToken values have decayed by.
  /// @dev Starts at 1 wad and decreases when decay accumulates.
  mapping(address => uint256) public decayAccumulator;

  /// @notice Stores the PToken address for a market.
  mapping(address => PToken) public ptoken;

  /// @notice Stores the encoded market configuration, i.e. it's cost model, weight, and purchase fee for a market.
  /// @dev The values are packed into a single word to reduce bytecode size and gas usage compared to structs.
  mapping(address => bytes32) public marketConfig;

  // -------- Set config --------

  // Leverage factor and deposit fee can be smaller, but the packing adds gas costs and bytecode size
  // since the two are not used together.
  uint256 public leverageFactor;
  uint256 public depositFee;
  IDecayModel public decayModel;
  IDripModel public dripModel;

  // -------- Set data --------

  /// @notice Underlying asset used by this set.
  ERC20 public asset;

  address[] public triggers; // Array of trigger addresses
  uint256 public numTriggeredMarkets;

  /// @notice The pending withdrawal count when the most recently triggered market became triggered, or 0 if none.
  /// Any pending withdrawals with IDs less than this need to have their amount of assets updated to reflect the exchange
  /// rate at the time when the most recently triggered market became triggered
  uint128 public lastTriggeredPendingWithdrawalCount;
  /// @notice The exchange rate of shares:assets when the most recent trigger occurred, or 0 if no market is triggered.
  /// This exchange rate is used for any pending withdrawals that were queued before the trigger occured to calculate
  /// the new amount of assets to be received when the withdrawal is completed.
  uint128 public lastTriggeredExchangeRate;

  /// @notice The total number of withdrawals that have been queued, including pending withdrawals that have been completed.
  uint256 public pendingWithdrawalCount;
  /// @notice The amount of assets pending withdrawal. These assets are unavailable for new protection purchases but
  /// are available to payout protection in the event of a market becoming triggered.
  uint256 public assetsPendingWithdrawal;

  // This is total amount of fees available to drip to suppliers. When protection is purchased, this gets
  // incremented by the protection cost (after fees). It gets decremented when fees are dripped to suppliers.
  uint256 public supplierFeePool;
  uint256 public lastDripRate;
  uint256 public lastDripTime;

  // Accrued asset balances.
  uint256 public assetBalance; // Equivalent to asset.balanceOf(address(this)) if no one transfers tokens directly to the contract.
  uint256 public accruedCozyReserveFees; // Amount of assets for generic cozy reserves.
  uint256 public accruedCozyBackstopFees; // Amount of assets for the cozy backstop.
  uint256 public accruedSetAdminFees; // Amount of assets for the set admin.

  struct PendingWithdrawal {
    address owner;
    address receiver;
    uint256 shares;
    uint256 assets;
    uint256 queueTime;
    uint256 delay;
  }
  mapping(uint256 => PendingWithdrawal) public pendingWithdrawals;

  error DelayNotElapsed();
  error InvalidPurchase();
  error InvalidDeposit();
  error InvalidState();
  error RoundsToZero();
  error WithdrawalNotFound();
  error WithdrawalRequestExceedsMax(uint256);
  error ZeroAssets();
  error Unauthorized();

  /// @dev Address of the Cozy protocol ImmutablesBeacon contract.
  constructor(ImmutablesBeacon _immutablesBeacon) {
    manager = Manager(_immutablesBeacon.manager());
    ptokenFactory = PTokenFactory(_immutablesBeacon.ptokenFactory());
  }

  /// @dev WARNING: DO NOT change this function signature or input to the `initializer` modifier. This method is
  /// called by the `SetFactory` which requires this exact signature.
  function initialize(
    ERC20 _asset,
    uint256 _leverageFactor,
    uint256 _depositFee,
    IDecayModel _decayModel,
    IDripModel _dripModel,
    IConfig.MarketInfo[] memory _marketInfos
  ) external initializer(0) {
    __initSmallERC20("Cozy Set", "CSET", _asset.decimals());
    // ACTIVE is the first state in the enum, therefore we don't need to explicitly initialize the set state.
    asset = _asset;

    leverageFactor = _leverageFactor;
    depositFee = _depositFee;
    decayModel = _decayModel;
    dripModel = _dripModel;

    uint256 _decayRateZeroUtilization = _decayRate(0);
    for (uint256 i = 0; i < _marketInfos.length; i = CozyMath.uncheckedIncrement(i)) {
      _initializeMarket(_marketInfos[i], _decayRateZeroUtilization);
    }
  }

  function _assertNotPaused() internal view {
    if (state[address(this)] == CState.PAUSED) revert InvalidState();
  }

  // -------------------------------------
  // ------- ERC-4626 Methods  -----------
  // -------------------------------------

  function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
    uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
    return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
  }

  function previewRedeem(uint256 shares) public view virtual returns (uint256) {
    return convertToAssets(shares);
  }

  function convertToAssets(uint256 shares) public view virtual returns (uint256) {
    uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
    return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
  }

  function convertToShares(uint256 assets) public view virtual returns (uint256) {
    uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
    return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
  }

  function maxDeposit(address) external view virtual returns (uint256) {
    uint256 _depositCap = manager.getDepositCap(asset);
    return _depositCap == type(uint256).max ? type(uint256).max : _depositCap.doz(assetBalance);
  }

  function maxMint(address) external view virtual returns (uint256) {
    uint256 _depositCap = manager.getDepositCap(asset);
    return _depositCap == type(uint256).max ? type(uint256).max : convertToShares(_depositCap.doz(assetBalance));
  }

  // Returns amount of assets that _owner can request for withdrawal.
  function maxWithdrawalRequest(address _owner) public view returns (uint256) {
    uint256 _maxAssetsRequired = 0;
    address _trigger;
    uint256 _assetsRequiredToBackMarket;
    uint256 _weight;

    for (uint256 i = 0; i < triggers.length; i++) {
      _trigger = triggers[i];

      // If a market is not triggered, we compute the amount of assets needed to back it so those funds are not withdrawn
      // (since users have a potential claim on those assets). If a market is triggered, the funds needed for it have
      // already been accounted for so we don't want to include them here, hence the if check.
      if (state[_trigger] != CState.TRIGGERED) {
        _weight = marketConfig[_trigger].read(MC_WEIGHT_SIZE, MC_WEIGHT_OFFSET);
        // Leverage factor times weight cannot realistically overflow a uint256.
        _assetsRequiredToBackMarket = ZOC2.mulDivDown(activeProtection(_trigger), leverageFactor.unsafemul(_weight));
        if (_maxAssetsRequired < _assetsRequiredToBackMarket) _maxAssetsRequired = _assetsRequiredToBackMarket;
      }
    }
    uint256 _ownerAssets = convertToAssets(balanceOfMatured(_owner));
    uint256 _withdrawableAssets = totalAssets() - _maxAssetsRequired;
    return _min(_withdrawableAssets, _ownerAssets);
  }

  function maxRedemptionRequest(address _owner) public view returns(uint256) {
    return convertToShares(maxWithdrawalRequest(_owner));
  }

  // ----------------------------------------
  // -------- State Getters: Markets --------
  // ----------------------------------------

  function weightedTotalAssetsScaled(address _trigger) internal view returns (uint256) {
    // Return value is a factor of ZOC2 larger than the true value, done to avoid precision loss when this
    // expression is used elsewhere. Leverage factor times weight cannot realistically overflow a uint256.
    return totalAssets() * leverageFactor.unsafemul(marketConfig[_trigger].read(MC_WEIGHT_SIZE, MC_WEIGHT_OFFSET));
  }

  // Returns the maximum amount of protection that can be sold for the specified market.
  function maxProtection(address _trigger) public view returns (uint256) {
    // This is safe because ZOC2 is a constant so we'll never divide by zero.
    return weightedTotalAssetsScaled(_trigger).unsafediv(ZOC2);
  }

  // Returns the amount of protection currently available to purchase for the specified market.
  function remainingProtection(address _trigger) external view returns (uint256) {
    return maxProtection(_trigger) - activeProtection(_trigger);
  }

  // Returns the amount of outstanding protection that is currently active.
  function activeProtection(address _trigger) public view returns (uint256) {
    return dataApd[_trigger].read(ACTIVE_PROTECTION_SIZE, ACTIVE_PROTECTION_OFFSET).mulWadDown(1e18 - nextDecayAmount(_trigger));
  }

  // Returns the current utilization ratio of the set, as a wad.
  function utilization() public view returns (uint256) {
    // Total active protection across all markets.
    uint256 _totalActiveProtection;
    for (uint256 i = 0; i < triggers.length; i = CozyMath.uncheckedIncrement(i)) {
      address _trigger = triggers[i];
      if (state[_trigger] != CState.TRIGGERED) _totalActiveProtection += activeProtection(_trigger);
    }

    // Utilization is activeProtection/totalAssets.
    uint256 _scaledTotalAssets = totalAssets() * leverageFactor; // Scaled up by a zoc.
    return _scaledTotalAssets == 0 ? 0 : (_totalActiveProtection * ZOC).divWadDown(_scaledTotalAssets);
  }

  // Returns the current utilization ratio of the specified market, as a wad. Defined as `activeProtection / maxProtection`.
  function utilization(address _trigger) public view returns (uint256) {
    return _previewUtilization(_trigger, 0, true); // True/false doesn't matter here since _assets is 0.
  }

  // Returns the utilization ratio of the specified market after purchasing `_assets` of protection.
  function previewPurchaseUtilization(address _trigger, uint256 _assets) public view returns (uint256) {
    return _previewUtilization(_trigger, _assets, true);
  }

  // Returns the utilization ratio of the specified market after canceling `_assets` of protection.
  function previewCancellationUtilization(address _trigger, uint256 _assets) public view returns (uint256) {
    return _previewUtilization(_trigger, _assets, false);
  }

  function _previewUtilization(address _trigger, uint256 _assets, bool _isPurchase) internal view returns (uint256) {
    // Compute the resulting amount of active protection after the purchase/cancellation.
    uint256 _newActiveProtection = _isPurchase ? activeProtection(_trigger) + _assets : activeProtection(_trigger) - _assets;

    // We explicitly do not use the maxProtection method here so we can do division last to avoid precision loss.
    uint256 _denominator = weightedTotalAssetsScaled(_trigger);
    return _denominator == 0 ? 0 : (WAD_ZOC2).mulDivDown(_newActiveProtection, _denominator);
  }

  // --------------------------------------------
  // -------- Purchase/Cancel Protection --------
  // --------------------------------------------

  // -------- Purchase/Cancel Logic --------

  // Purchase `_protection` amount of protection for the specified market, and send the PTokens to `_receiver`.
  function purchase(address _trigger, uint256 _protection, address _receiver) external returns (uint256 _totalCost, uint256 _ptokens) {
    // Purchases are only allowed when the set is not PAUSED and the market is ACTIVE.
    if (state[address(this)] == CState.PAUSED || state[_trigger] != CState.ACTIVE) revert InvalidState();
    accrueDecay(_trigger);

    // Validate purchase. Checks for rounding error since convertToPTokens rounds down.
    uint256 _cost; uint256 _reserveFeeAssets;  uint256 _backstopFeeAssets; uint256 _setAdminFeeAssets;
    ( _totalCost, _ptokens, _cost, _reserveFeeAssets, _backstopFeeAssets, _setAdminFeeAssets) = previewPurchaseData(_trigger, _protection);
    if (_totalCost == 0 || _ptokens == 0) revert InvalidPurchase();

    // Ensure we cannot buy more protection than what's available.
    uint256 _activeProtection = dataApd[_trigger].read(ACTIVE_PROTECTION_SIZE, ACTIVE_PROTECTION_OFFSET);
    if (_activeProtection + _protection > maxProtection(_trigger)) revert InvalidPurchase();
    dataApd[_trigger] = dataApd[_trigger].write(ACTIVE_PROTECTION_SIZE, ACTIVE_PROTECTION_OFFSET, _activeProtection + _protection);

    unchecked {
      // In theory this can overflow if the drip rate is very small or zero so this strictly increases. In practice
      // suppliers are unlikely to use a market with very little interest, and accruing `type(uint112).max` tokens
      // in fees is unrealistically high for normal tokens.
      supplierFeePool += _cost;
    }

    // Check surplus to transfer minimum required assets. This must be computed before incrementing assetBalance below.
    (uint256 _assetAmtNeeded, uint256 _initAssetBalanceOfSelf) = _assetsNeeded(_totalCost);

    // Update internal accounting.
    unchecked {
      // The added amounts are a fraction of the total cost, so assetBalance would overflow before these do.
      // In theory this can overflow first admins never claim fees and this surpasses `assetBalance`. In practice
      // if there are a lot of fees to claim, the admin is incentivized to claim them, and accruing
      // `type(uint112).max` tokens in fees is unrealistically high for normal tokens.
      accruedCozyReserveFees += _reserveFeeAssets;
      accruedCozyBackstopFees += _backstopFeeAssets;
      accruedSetAdminFees += _setAdminFeeAssets;
    }

    // As a safety check, we keep this math checked as overflow protection.
    assetBalance += _totalCost;

    // Pull in payment and mint PTokens. After the transfer we ensure we no longer need any assets. This check is
    // required to support fee on transfer tokens, in particular to support the case where USDT enables a fee.
    if (_assetAmtNeeded > 0) _assetSafeTransferFrom(msg.sender, address(this), _assetAmtNeeded); // Transfer before minting or ERC777s could reenter.
    if (_assetBalanceOfSelf() - _initAssetBalanceOfSelf < _assetAmtNeeded) revert InvalidPurchase();
    ptoken[_trigger].mint(_receiver, _ptokens);
    emit Purchase(msg.sender, _receiver, _protection, _ptokens, _trigger, _totalCost);
  }

  // Cancel `_protection` amount of protection for the specified market, and send the refund amount to `_receiver`.
  function cancel(address _trigger, uint256 _protection, address _receiver, address _owner) external returns (uint256 _refund, uint256 _ptokens) {
    // No need to check for rounding error, previewCancellation rounds up.
    accrueDecay(_trigger);
    uint256 _reserveFeeAssets; uint256 _backstopFeeAssets;
    (_refund, _ptokens, _reserveFeeAssets, _backstopFeeAssets) = previewCancellation(_trigger, _protection);

    // Finalize cancellation.
    _cancel(_trigger, _protection, _ptokens, _refund, _receiver, _owner, _reserveFeeAssets, _backstopFeeAssets);
  }

  // Sell `_ptokens` amount of ptokens for the specified market, and send the refund amount to `_receiver`.
  function sell(address _trigger, uint256 _ptokens, address _receiver, address _owner) external returns (uint256 _refund, uint256 _protection) {
    accrueDecay(_trigger);
    uint256 _reserveFeeAssets; uint256 _backstopFeeAssets;
    (_refund, _protection, _reserveFeeAssets, _backstopFeeAssets) = previewSale(_trigger, _ptokens);

    // Finalize sale.
    _cancel(_trigger, _protection, _ptokens, _refund, _receiver, _owner, _reserveFeeAssets, _backstopFeeAssets);
  }

  function claim(address _trigger, uint256 _protection, address _receiver, address _owner) external returns (uint256 _ptokens) {
    _ptokens = previewClaim(_trigger, _protection); // Rounds up, so no need to check for zero tokens.
    _claim(_trigger, _protection, _ptokens, _receiver, _owner);
  }

  function payout(address _trigger, uint256 _ptokens, address _receiver, address _owner) external returns (uint256 _protection) {
    _protection = previewPayout(_trigger, _ptokens);
    if (_protection == 0) revert RoundsToZero();
    _claim(_trigger, _protection, _ptokens, _receiver, _owner);
  }

  function _cancel(address _trigger, uint256 _protection, uint256 _ptokens, uint256 _refund, address _receiver, address _owner, uint256 _reserveFeeAssets, uint256 _backstopFeeAssets) internal {
    // Cancellations are only allowed when the market is ACTIVE and the set is ACTIVE or PAUSED.
    if (!(state[_trigger] == CState.ACTIVE && (state[address(this)] == CState.ACTIVE || state[address(this)] == CState.PAUSED))) revert InvalidState();

    _removeProtection(_trigger, _owner, _receiver, _ptokens, _protection, _refund, _reserveFeeAssets, _backstopFeeAssets);
    emit Cancellation(msg.sender, _receiver, _owner, _protection, _ptokens, _trigger, _refund);
  }

  function _claim(address _trigger, uint256 _protection, uint256 _ptokens, address _receiver, address _owner) internal {
    if (state[_trigger] != CState.TRIGGERED) revert InvalidState();

    _removeProtection(_trigger, _owner, _receiver, _ptokens, _protection, _protection, 0, 0);
    emit Claim(msg.sender, _receiver, _owner, _protection, _ptokens, _trigger);
  }

  function _removeProtection(address _trigger, address _owner, address _receiver, uint256 _ptokens, uint256 _protection, uint256 _assets, uint256 _reserveFeeAssets, uint256 _backstopFeeAssets) internal {
    PToken _ptoken = ptoken[_trigger];
    if (msg.sender != _owner) {
      uint256 _allowed = _ptoken.allowance(_owner, msg.sender); // Saves gas for limited approvals.
      if (_allowed != type(uint256).max) _ptoken.setAllowance(_owner, msg.sender, _allowed - _ptokens);
    }

    // Decrementing `activeProtection` by `_protection` is required for accurate calculation of totalAssets.
    // This means if you want to know what the `activeProtection` was at the time of trigger you'll need to
    // look it up using an archive node, since that state won't be saved in the contract.
    _ptoken.burn(_owner, _ptokens);
    assetBalance -= _assets;

    // Update internal accounting.
    unchecked {
      // The added amounts are a fraction of the total refund, so assetBalance would overflow before these do.
      // In theory this can overflow first if admins never claim fees and this surpasses `assetBalance`. In practice
      // if there are a lot of fees to claim, the admin is incentivized to claim them, and accruing
      // `type(uint112).max` tokens in fees is unrealistically high for normal tokens.
      accruedCozyReserveFees += _reserveFeeAssets;
      accruedCozyBackstopFees += _backstopFeeAssets;
    }

    uint256 _activeProtection = dataApd[_trigger].read(ACTIVE_PROTECTION_SIZE, ACTIVE_PROTECTION_OFFSET);
    dataApd[_trigger] = dataApd[_trigger].write(ACTIVE_PROTECTION_SIZE, ACTIVE_PROTECTION_OFFSET, _activeProtection - _protection);

    _assetSafeTransfer(_receiver, _assets);
  }

  // -------- Accounting Logic --------

  function costFactor(address _trigger, uint256 _protection) public view returns (uint256 _costFactor) {
    _costFactor = _getCostModel(_trigger).costFactor(utilization(_trigger), previewPurchaseUtilization(_trigger, _protection));
  }

  function refundFactor(address _trigger, uint256 _protection) public view returns (uint256 _refundFactor) {
    _refundFactor = _getCostModel(_trigger).refundFactor(utilization(_trigger), previewCancellationUtilization(_trigger, _protection));
  }

  function purchaseFees(address _trigger) public view returns (uint256 _reserveFee, uint256 _backstopFee, uint256 _setAdminFee) {
    (_reserveFee, _backstopFee) = manager.purchaseFees();
    _setAdminFee = marketConfig[_trigger].read(MC_PURCHASE_FEE_SIZE, MC_PURCHASE_FEE_OFFSET);
  }

  // Get the cost and quantity of PTokens received to purchase the specified amount of protection.
  function previewPurchase(address _trigger, uint256 _protection) external view returns (uint256 _totalCost, uint256 _ptokens) {
    (_totalCost, _ptokens,,,,) = previewPurchaseData(_trigger, _protection);
  }

  function previewPurchaseData(address _trigger, uint256 _protection) public view returns (
    uint256 _totalCost,
    uint256 _ptokens,
    uint256 _cost,
    uint256 _reserveFeeAssets,
    uint256 _backstopFeeAssets,
    uint256 _setAdminFeeAssets
  ) {
    _cost = _protection.mulWadDown(costFactor(_trigger, _protection));
    (uint256 _reserveFee, uint256 _backstopFee, uint256 _setAdminFee) = purchaseFees(_trigger);

    _reserveFeeAssets = _cost.mulDivDown(_reserveFee, ZOC);
    _backstopFeeAssets = _cost.mulDivDown(_backstopFee, ZOC);
    _setAdminFeeAssets = _cost.mulDivDown(_setAdminFee, ZOC);
    _totalCost = _cost + _reserveFeeAssets + _backstopFeeAssets + _setAdminFeeAssets;

    _ptokens = convertToPTokens(_trigger, _protection);
  }

  // Get the refund amount and quantity of PTokens received to cancel the specified amount of protection.
  function previewCancellation(address _trigger, uint256 _protection) public view returns (
    uint256 _refund,
    uint256 _ptokens,
    uint256 _reserveFeeAssets,
    uint256 _backstopFeeAssets
  ) {
    _ptokens = previewClaim(_trigger, _protection);
    (_refund, _reserveFeeAssets, _backstopFeeAssets) = _previewCancellation(_trigger, _protection);
  }

  function _previewCancellation(address _trigger, uint256 _protection) internal view returns (
    uint256 _refund,
    uint256 _reserveFeeAssets,
    uint256 _backstopFeeAssets
  ) {
    // The refund factor defines the refund amount as a percentage of the supplier fee pool. Refunds are only
    // allowed to come from this pool, and should never deduct from supplier earnings.
    (uint256 _reserveFee, uint256 _backstopFee) = manager.cancellationFees();
    uint256 _rawRefund = supplierFeePool.mulWadDown(refundFactor(_trigger, _protection));
    uint256 _totalFee = _reserveFee + _backstopFee;
    uint256 _totalFeeAssets = _rawRefund.mulDivDown(_totalFee, ZOC);
    _reserveFeeAssets = _totalFee == 0 ? 0 : _totalFeeAssets.mulDivDown(_reserveFee, _totalFee);

    unchecked {
      // The reserve fee is a portion of the total fees, therefore this cannot underflow.
      _backstopFeeAssets = _totalFeeAssets - _reserveFeeAssets;
    }
    _refund = _rawRefund - _totalFeeAssets;
  }

  function previewClaim(address _trigger, uint256 _protection) public view returns (uint256 _ptokens) {
    uint256 _supply = _ptokenTotalSupply(_trigger); // Saves an extra SLOAD if totalSupply is non-zero.
    _ptokens = _supply == 0 ? _protection : _protection.mulDivUp(_supply, activeProtection(_trigger));
  }

  function previewPayout(address _trigger, uint256 _ptokens) public view returns (uint256 _protection) {
    _protection = convertToProtection(_trigger, _ptokens);
  }

  function previewSale(address _trigger, uint256 _ptokens) public view returns (
    uint256 _refund,
    uint256 _protection,
    uint256 _reserveFeeAssets,
    uint256 _backstopFeeAssets
  ) {
    _protection = previewPayout(_trigger, _ptokens);
    (_refund, _reserveFeeAssets, _backstopFeeAssets) = _previewCancellation(_trigger, _protection);
  }

  // Convert an amount of protection into an amount of PTokens.
  function convertToPTokens(address _trigger, uint256 _protection) public view virtual returns (uint256) {
    uint256 _supply = _ptokenTotalSupply(_trigger); // Saves an extra SLOAD if totalSupply is non-zero.
    return _supply == 0 ? _protection : _protection.mulDivDown(_supply, activeProtection(_trigger));
  }

  // Convert an amount of PTokens into an amount of protection.
  function convertToProtection(address _trigger, uint256 _ptokens) public view virtual returns (uint256) {
    uint256 _supply = _ptokenTotalSupply(_trigger); // Saves an extra SLOAD if totalSupply is non-zero.
    return _supply == 0 ? _ptokens : _ptokens.mulDivDown(activeProtection(_trigger), _supply);
  }

  function accrueDecay(address _trigger) public {
    if (state[_trigger] == CState.TRIGGERED) revert InvalidState();

    uint256 _accruedDecay = nextDecayAmount(_trigger);

    decayAccumulator[_trigger] = decayAccumulator[_trigger].mulWadDown(1e18 - _accruedDecay);

    uint256 _activeProtection = dataApd[_trigger].read(ACTIVE_PROTECTION_SIZE, ACTIVE_PROTECTION_OFFSET);
    dataApd[_trigger] = bytes32(0)
      .write(ACTIVE_PROTECTION_SIZE, ACTIVE_PROTECTION_OFFSET, _activeProtection.mulWadDown(1e18 - _accruedDecay))
      .write(DECAY_RATE_SIZE, DECAY_RATE_OFFSET, _decayRate(utilization(_trigger)))
      .write(LAST_DECAY_TIME_SIZE, LAST_DECAY_TIME_OFFSET, block.timestamp);
  }

  function nextDecayAmount(address _trigger) public view returns (uint256 _accruedDecay) {
    // Whenever Set.accrueDecay is executed to accrue decay, we also update lastDecayTime. When the set transitions
    // out of the paused state, decay is not accrued but lastDecayTime is updated. Therefore, calculating the
    // elapsed time since lastDecayTime is safe and accurate w.r.t. calculating the next decay amount.
    uint256 _deltaT = _elapsedTime(dataApd[_trigger].read(LAST_DECAY_TIME_SIZE, LAST_DECAY_TIME_OFFSET));
    if (_deltaT == 0 || state[address(this)] == CState.PAUSED) return 0;

    uint256 _lastDecayRate = dataApd[_trigger].read(DECAY_RATE_SIZE, DECAY_RATE_OFFSET);

    // A sane decay rate cannot overflow a uint256 when multiplied by a realistic deltaT.
    _accruedDecay = _lastDecayRate.unsafemul(_deltaT);
  }

  function balanceOfMatured(address _user) public view override returns (uint256 _balance) {
    _balance = balanceOf[_user];
    MintMetadata[] memory _mints = mints[_user];

    for (uint256 i = 0; i < _mints.length; i = CozyMath.uncheckedIncrement(i)) {
      if (_elapsedTime(_mints[i].time) < _mints[i].delay) {
        _balance -= _mints[i].amount;
      }
    }
  }

  // ---------------------------------------
  // -------- External Call Helpers --------
  // ---------------------------------------

  // Used to reduce bytecode size for external calls used multiple times in this contract.

  function _ptokenTotalSupply(address _trigger) internal view returns (uint256) {
    return ptoken[_trigger].totalSupply();
  }

  function _assetBalanceOfSelf() internal view returns (uint256) {
    return asset.balanceOf(address(this));
  }

  function _assetSafeTransfer(address _to, uint256 _amount) internal {
    asset.safeTransfer(_to, _amount);
  }

  function _assetSafeTransferFrom(address _from, address _to, uint256 _amount) internal {
    asset.safeTransferFrom(_from, _to, _amount);
  }

  function _decayRate(uint256 _utilization) internal view returns (uint256) {
    return decayModel.decayRate(_utilization);
  }

  // ----------------------------------------
  // -------- State Transition Logic --------
  // ----------------------------------------

  // NOTE: State transitions that are blocked due to unauthorized callers revert with InvalidStateTransition instead
  // of Unauthorized. This is partly because it keeps the logic cleaner, and partly because InvalidStateTransition
  // is an accurate description: the state transition is invalid because the caller is not authorized.

  // -------- Authorization Helpers --------

  function isMarket(address _who) public view returns (bool) {
    return dataApd[_who].read(LAST_DECAY_TIME_SIZE, LAST_DECAY_TIME_OFFSET) > 0;
  }

  function _assertCallerIsManager() internal view {
    if (msg.sender != address(manager)) revert Unauthorized();
  }

  // -------- Set State Transitions --------

  function updateSetState(CState _state) external {
    _assertCallerIsManager();
    _updateSetState(_state);
  }

  function pause() external {
    _assertCallerIsManager();
    // Decay/fees do not accrue while paused, so for untriggered markets we update them now.
    drip();
    for (uint i = 0; i < triggers.length; i = CozyMath.uncheckedIncrement(i)) {
      address _trigger = triggers[i];
      // Decay should be accrued before the set's state is updated to the paused state, since Set.nextDecayAmount
      // returns 0 if the set is paused.
      if (state[_trigger] != CState.TRIGGERED) accrueDecay(_trigger);
    }
    _updateSetState(CState.PAUSED);
  }

  function unpause(CState _state) external {
    _assertCallerIsManager();
    _updateSetState(_state);

    // Decay/fees do not accrue while paused, so for untriggered markets we update the last accrual times to the current time.
    for (uint i = 0; i < triggers.length; i = CozyMath.uncheckedIncrement(i)) {
      address _trigger = triggers[i];
      if (state[_trigger] != CState.TRIGGERED) {
        dataApd[_trigger] = dataApd[_trigger].write(LAST_DECAY_TIME_SIZE, LAST_DECAY_TIME_OFFSET, block.timestamp);
      }
    }

    lastDripTime = block.timestamp;
    lastDripRate = currentDripRate(); // New drip rate based on the current utilization.
  }

  function _updateSetState(CState _newState) internal {
    state[address(this)] = _newState;
  }

  // -------- Market State Transitions --------

  function shortfall(address _trigger) external view returns (uint256) {
    return activeProtection(_trigger).doz(maxProtection(_trigger));
  }

  // Update the state of the a market in the set. The caller must be the trigger contract for the market.
  function updateMarketState(address _trigger, CState _newState) external {
    _assertCallerIsManager();

    if (_newState != CState.TRIGGERED) {
      // For every state except triggered, all we need to do is change the state.
      state[_trigger] = _newState;
      return;
    }

    // When a market becomes triggered, we determine the new amount of assets pending withdrawal by determining the
    // amount of active protection in the triggered market that pending withdrawals are liable for paying out claims.
    uint256 _totalAssets = totalAssets() + assetsPendingWithdrawal;
    // Assets pending withdrawal that should be set aside for the triggered market = active protection in the triggered market * ratio of pending withdrawal assets:total assets.
    uint256 _assetsPendingWithdrawalForTriggeredMarket = _totalAssets == 0
      ? 0
      : activeProtection(_trigger).mulDivDown(assetsPendingWithdrawal,  _totalAssets);
    assetsPendingWithdrawal = assetsPendingWithdrawal.doz(_assetsPendingWithdrawalForTriggeredMarket);

    // Any pending withdrawals with an ID less than the current pending withdrawal count need to have their
    // amount of assets updated during withdraw completion to reflect the exchange rate at the most recent trigger,
    // since their assets are used to help pay protection claims. The exchange rate is calculated after the state
    // of the market is updated above, so totalAssets() returns the new amount of available assets.
    state[_trigger] = _newState;
    lastTriggeredExchangeRate = totalSupply == 0 ? 0 : totalAssets().mulDivDown(WAD, totalSupply).safeCastTo128();
    lastTriggeredPendingWithdrawalCount = pendingWithdrawalCount.safeCastTo128();

    numTriggeredMarkets++;
  }

  function isAnyMarketFrozen() external view returns (bool) {
    for (uint i = 0; i < triggers.length; i = CozyMath.uncheckedIncrement(i)) {
      if (state[triggers[i]] == CState.FROZEN) return true;
    }
    return false;
  }

  // ---------------------------------
  // -------- Admin Functions --------
  // ---------------------------------

  /// @notice Execute queued updates to setConfig and marketConfig. This should only be called by the Manager.
  function updateConfigs(
    uint256 _leverageFactor,
    uint256 _depositFee,
    IDecayModel _decayModel,
    IDripModel _dripModel,
    IConfig.MarketInfo[] calldata _marketInfos
  ) external {
    _assertCallerIsManager();

    // Update set config.
    leverageFactor = _leverageFactor;
    depositFee = _depositFee;
    decayModel = _decayModel;
    dripModel = _dripModel;

    uint256 _decayRateZeroUtilization = _decayRate(0);
    for (uint256 i = 0; i < _marketInfos.length; i = CozyMath.uncheckedIncrement(i)) {
      address _trigger = _marketInfos[i].trigger;
      if (!isMarket(_trigger)) {
        // If the MarketInfo is not for an existing market, a new one is added.
        _initializeMarket(_marketInfos[i], _decayRateZeroUtilization);
      } else {
        // Update existing market config.
        marketConfig[_trigger] = _encodeMarketInfo(_marketInfos[i]);
      }
    }
  }

  function _initializeMarket(IConfig.MarketInfo memory _marketInfo, uint256 _decayRateZeroUtilization) internal {
    address _trigger = _marketInfo.trigger;

    marketConfig[_trigger] = _encodeMarketInfo(_marketInfo);
    state[_trigger] = CState.ACTIVE;
    ptoken[_trigger] = ptokenFactory.deployPToken(decimals, address(this), _trigger);
    decayAccumulator[_trigger] = FixedPointMathLib.WAD;
    dataApd[_trigger] = bytes32(0)
      .write(DECAY_RATE_SIZE, DECAY_RATE_OFFSET, _decayRateZeroUtilization)
      .write(LAST_DECAY_TIME_SIZE, LAST_DECAY_TIME_OFFSET, block.timestamp);
    triggers.push(_trigger);
  }

  function claimSetFees(address _receiver) external {
    _assertCallerIsManager();
    uint256 _setAdminFees = accruedSetAdminFees;
    assetBalance -= _setAdminFees;
    accruedSetAdminFees = 0;
    _assetSafeTransfer(_receiver, _setAdminFees);

  }

  function claimCozyFees(address _admin, address _backstop) external {
    // Cozy fee claims will often be batched, so we require it to be initiated from the manager to save gas by
    // removing calls and SLOADs to check the admin and backstop addresses each time.
    _assertCallerIsManager();
    uint256 _reserveAmount = accruedCozyReserveFees;
    uint256 _backstopAmount = accruedCozyBackstopFees;
    assetBalance -= (_reserveAmount + _backstopAmount);
    accruedCozyReserveFees = 0;
    accruedCozyBackstopFees = 0;
    _assetSafeTransfer(_admin, _reserveAmount);
    _assetSafeTransfer(_backstop, _backstopAmount);
  }

  // ---------------------------
  // -------- ERC-4626  --------
  // ---------------------------

  // -------- ERC-4626 Deposit/Withdrawal Logic --------

  function depositFees() public view returns (uint256 _reserveFee, uint256 _backstopFee, uint256 _setAdminFee) {
    (_reserveFee, _backstopFee) = manager.depositFees();
    _setAdminFee = depositFee;
  }

  function previewDeposit(uint256 _assets) external view returns (uint256 _shares) {
    (_shares,,,) = previewDepositData(_assets);
  }

  function previewDepositData(uint256 _assets) public view returns (
    uint256 _userShares,
    uint256 _reserveFeeAssets,
    uint256 _backstopFeeAssets,
    uint256 _setAdminFeeAssets
  ) {
    (uint256 _reserveFee, uint256 _backstopFee, uint256 _setAdminFee) = depositFees();

    _reserveFeeAssets = _assets.mulDivDown(_reserveFee, ZOC);
    _backstopFeeAssets = _assets.mulDivDown(_backstopFee, ZOC);
    _setAdminFeeAssets = _assets.mulDivDown(_setAdminFee, ZOC);
    unchecked {
      // Total fees cannot exceed 100%, therefore subtracting total fees from assets cannot overflow.
      _userShares = convertToShares(_assets - _reserveFeeAssets - _backstopFeeAssets - _setAdminFeeAssets);
    }
  }

  function previewMint(uint256 _shares) external view returns (uint256 _assets) {
    (_assets,,,) = previewMintData(_shares);
  }

  function previewMintData(uint256 _shares) public view returns (
    uint256 _assets,
    uint256 _reserveFeeAssets,
    uint256 _backstopFeeAssets,
    uint256 _setAdminFeeAssets
  ) {
    (uint256 _reserveFee, uint256 _backstopFee, uint256 _setAdminFee) = depositFees();
    uint256 _supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
    _assets = _supply == 0 ? _shares : _shares.mulDivUp(totalAssets(), _supply);

    uint256 _totalFee = _reserveFee + _backstopFee + _setAdminFee;
    uint256 _totalFeeAssets = _assets.mulDivDown(_totalFee, ZOC);
    _reserveFeeAssets = _totalFeeAssets.unsafemul(_reserveFee).unsafediv(_totalFee);
    _backstopFeeAssets = _totalFeeAssets.unsafemul(_backstopFee).unsafediv(_totalFee);
    unchecked {
      // The reserve and backstop fees are a portion of the total fees, therefore this cannot overflow.
      _setAdminFeeAssets = _totalFeeAssets - _reserveFeeAssets - _backstopFeeAssets;
    }
  }

  // Mints shares Vault shares to receiver by depositing exactly amount of underlying tokens.
  // MUST emit the Deposit event.
  // MUST support ERC-20 approve / transferFrom on asset as a deposit flow. MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the deposit execution, and are accounted for during deposit.
  // MUST revert if all of assets cannot be deposited (due to deposit limit being reached, slippage, the user not approving enough underlying tokens to the Vault contract, etc).
  // Note that most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
  function deposit(uint256 _assets, address _receiver) external returns (uint256 _shares) {
    _assertNotPaused();
    drip();

    uint256 _reserveFeeAssets; uint256 _backstopFeeAssets; uint256 _setAdminFeeAssets;
    (_shares, _reserveFeeAssets, _backstopFeeAssets, _setAdminFeeAssets) = previewDepositData(_assets);
    if (_shares == 0) revert RoundsToZero();
    _executeDeposit(_assets, _shares, _receiver, _reserveFeeAssets, _backstopFeeAssets, _setAdminFeeAssets);
  }

  // Mints exactly shares Vault shares to receiver by depositing amount of underlying tokens.
  // MUST emit the Deposit event.
  // MUST support ERC-20 approve / transferFrom on asset as a mint flow. MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the mint execution, and are accounted for during mint.
  // MUST revert if all of shares cannot be minted (due to deposit limit being reached, slippage, the user not approving enough underlying tokens to the Vault contract, etc).
  // Note that most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
  function mint(uint256 _shares, address _receiver) external returns (uint256 _assets) {
    _assertNotPaused();
    drip();

    // No need to check for rounding error, previewMint rounds up.
    uint256 _reserveFeeAssets; uint256 _backstopFeeAssets; uint256 _setAdminFeeAssets;
    (_assets, _reserveFeeAssets, _backstopFeeAssets, _setAdminFeeAssets) = previewMintData(_shares);
    _executeDeposit(_assets, _shares, _receiver, _reserveFeeAssets, _backstopFeeAssets, _setAdminFeeAssets);
  }

  function _executeDeposit(
    uint256 _assets,
    uint256 _shares,
    address _receiver,
    uint256 _reserveFeeAssets,
    uint256 _backstopFeeAssets,
    uint256 _setAdminFeeAssets
  ) internal {
    // Use any surplus of assets to minimize the transfer amount.
    (uint256 _assetAmtNeeded, uint256 _initAssetBalanceOfSelf) = _assetsNeeded(_assets);

    assetBalance += _assets;
    accruedCozyReserveFees += _reserveFeeAssets;
    accruedCozyBackstopFees += _backstopFeeAssets;
    accruedSetAdminFees += _setAdminFeeAssets;

    // Check this *after* we have added _assets to assetBalance, since we're doing our own internal asset accounting.
    if (totalAssets() > manager.getDepositCap(asset)) revert InvalidDeposit();

    // Pull in payment and complete deposit. After the transfer we ensure we no longer need any assets. This check is
    // required to support fee on transfer tokens, in particular to support the case where USDT enables a fee.
    if (_assetAmtNeeded > 0) _assetSafeTransferFrom(msg.sender, address(this), _assetAmtNeeded); // Need to transfer before minting or ERC777s could reenter.
    if (_assetBalanceOfSelf() - _initAssetBalanceOfSelf < _assetAmtNeeded) revert InvalidDeposit();

    mints[_receiver].push(
      MintMetadata(
        _shares.safeCastTo128(),
        block.timestamp.safeCastTo64(),
        manager.minDepositDuration().safeCastTo64()
      )
    );
    _mint(_receiver, _shares);
    emit Deposit(msg.sender, _receiver, _assets, _shares);
  }

  function withdraw(uint256 _assets, address _receiver, address _owner) external returns (uint256 _shares) {
    // Burns shares from owner and queues an exact amount (_assets) of underlying tokens to be sent
    // after the manager.withdrawDelay has elapsed. This function will NOT transfer the assets, nor emit a Withdraw
    // event, that is done in completeWithdraw(), which also specifies where the assets are sent.
    // Assets queued for withdrawal can still be used for protection payouts while the
    // withdrawal is pending, but they cannot be used to sell new protection.
    drip();

    uint256 _maxWithdrawableAssets = maxWithdrawalRequest(_owner);
    if (_assets > _maxWithdrawableAssets) revert WithdrawalRequestExceedsMax(_maxWithdrawableAssets);

    _shares = previewWithdraw(_assets); // No need to check for rounding error, previewWithdraw rounds up.
    _updateShareAllowance(_owner, _shares);
    _queueWithdrawal(_owner, _receiver, _shares, _assets);
  }

  function redeem(uint256 _shares, address _receiver, address _owner) external returns (uint256 _assets) {
    // Burns _shares from _owner and queues the corresponding amount of _assets to be sent
    // after the manager.withdrawDelay has elapsed. This function will NOT transfer the assets, nor emit a
    // Withdraw event, that is done in completeRedeem(), which also specifies where the
    // assets are sent. Assets queued for redemption can still be used for protection payouts while
    // the redemption is pending, but they cannot be used to sell new protection.
    drip();

    uint256 _maxRedeemableShares = maxRedemptionRequest(_owner);
    if (_shares > _maxRedeemableShares) revert WithdrawalRequestExceedsMax(_maxRedeemableShares);

    _updateShareAllowance(_owner, _shares);
    _assets = previewRedeem(_shares);
    if (_assets == 0) revert RoundsToZero(); // Check for rounding error since we round down in previewRedeem.
    _queueWithdrawal(_owner, _receiver, _shares, _assets);
  }

  function _updateShareAllowance(address _owner, uint256 _shares) internal {
    if (msg.sender != _owner) {
      uint256 _allowed = allowance[_owner][msg.sender]; // Saves gas for limited approvals.
      if (_allowed != type(uint256).max) allowance[_owner][msg.sender] = _allowed - _shares;
    }
  }

  function _queueWithdrawal(
    address _owner,
    address _receiver,
    uint256 _shares,
    uint256 _assets
  ) internal returns (uint256 _withdrawalId) {
    if (state[address(this)] == CState.FROZEN) revert InvalidState();
    _burn(_owner, _shares);

    _withdrawalId = pendingWithdrawalCount;
    unchecked {
      // Increments can never realistically overflow.
      pendingWithdrawalCount += 1;

      // The maximum amount of assets that can be withdrawn is bounded by assetBalance, which will overflow if
      // the contract has too many assets. We can never have more assetsPendingWithdrawal than current assetBalance,
      // therefore this cannot overflow.
      assetsPendingWithdrawal += _assets;
    }

    uint256 _withdrawDelay = state[address(this)] == CState.PAUSED ? 0 : manager.withdrawDelay();

    pendingWithdrawals[_withdrawalId] = PendingWithdrawal(_owner, _receiver, _shares, _assets, block.timestamp, _withdrawDelay);
    emit WithdrawalPending(msg.sender, _receiver, _owner, _assets, _shares, _withdrawalId);

    if (_withdrawDelay == 0) completeWithdraw(_withdrawalId, _receiver);
  }

  function pendingWithdrawalData(uint256 _withdrawalId) public view returns(
    uint256 _remainingWithdrawalDelay,
    PendingWithdrawal memory _pendingWithdrawal
  ) {
    _pendingWithdrawal = pendingWithdrawals[_withdrawalId];
    if (_pendingWithdrawal.owner == address(0)) revert WithdrawalNotFound();

    // If the set is paused, withdrawals can occur instantly.
    _remainingWithdrawalDelay = state[address(this)] == CState.PAUSED
      ? 0
      : _pendingWithdrawal.delay.doz(
        manager.getWithdrawDelayTimeAccrued(
          this,
          _pendingWithdrawal.queueTime,
          state[address(this)]
        )
    );

    // If the pending withdrawal was queued before the most recent trigger occurred, re-calculate the amount of assets
    // to withdraw using the exchange rate when the most recent trigger occurred.
    if (_withdrawalId < lastTriggeredPendingWithdrawalCount) {
      _pendingWithdrawal.assets = _pendingWithdrawal.shares.mulWadDown(lastTriggeredExchangeRate);
    }
  }

  function completeRedeem(uint256 _redemptionId) external {
    completeWithdraw(_redemptionId, pendingWithdrawals[_redemptionId].receiver);
  }

  function completeRedeem(uint256 _redemptionId, address _receiver) external {
    completeWithdraw(_redemptionId, _receiver);
  }

  function completeWithdraw(uint256 _withdrawalId) external {
    completeWithdraw(_withdrawalId, pendingWithdrawals[_withdrawalId].receiver);
  }

  function completeWithdraw(uint256 _withdrawalId, address _receiver) public {
    (uint256 _remainingWithdrawalDelay, PendingWithdrawal memory _pendingWithdrawal) = pendingWithdrawalData(_withdrawalId);
    if (_remainingWithdrawalDelay > 0) revert DelayNotElapsed();
    _updateShareAllowance(_pendingWithdrawal.owner, _pendingWithdrawal.shares);

    unchecked {
      // We increment assetsPendingWithdrawal by assets when queued, and now subtract from it. Those are the
      // only ways it can be modified, therefore this can never overflow.
      assetsPendingWithdrawal -= _pendingWithdrawal.assets;
    }
    emit Withdraw(msg.sender, _receiver, _pendingWithdrawal.owner, _pendingWithdrawal.assets, _pendingWithdrawal.shares, _withdrawalId);
    delete pendingWithdrawals[_withdrawalId];

    assetBalance -= _pendingWithdrawal.assets;
    _assetSafeTransfer(_receiver, _pendingWithdrawal.assets);
  }

  // -------- ERC-4626 Accounting Logic --------

  // `totalAssets` is an ERC4626 function that represents the total amount of assets
  // managed by the vault. In this context, however, it represents the total sum of assets
  // that is available to back protection.
  //
  // SHOULD include any compounding that occurs from yield.
  // MUST be inclusive of any fees that are charged against assets in the Vault.
  // MUST NOT revert.
  function totalAssets() public view returns (uint256 _protectableAssets) {
    // This should return "total assets available for suppliers". This is defined as total assets held by this
    // contract, minus unrealized assets that have not dripped to suppliers, minus assets that have an active
    // claim on them for triggered markets.
    _protectableAssets = assetBalance - assetsPendingWithdrawal - (supplierFeePool - nextDripAmount()) - (accruedCozyReserveFees + accruedCozyBackstopFees + accruedSetAdminFees);

    for (uint256 i = 0; i < triggers.length; i = CozyMath.uncheckedIncrement(i)) {
      if (state[triggers[i]] == CState.TRIGGERED) {
        _protectableAssets = _protectableAssets.doz(dataApd[triggers[i]].read(ACTIVE_PROTECTION_SIZE, ACTIVE_PROTECTION_OFFSET));
      }
    }
  }

  function sync() external {
    assetBalance += (_assetBalanceOfSelf() - assetBalance);
  }

  // -----------------------------------------
  // -------- Supplier Interest Logic --------
  // -----------------------------------------

  function currentDripRate() public view returns (uint256) {
    // Drip rate is bounded by decay rate to ensure user's can always cancel their protection.
    uint256 _utilization = utilization();
    return _min(dripModel.dripRate(_utilization), _decayRate(_utilization));
  }

  // Drips accrued fees to suppliers
  function drip() public {
    supplierFeePool -= nextDripAmount(); // Reducing supplierFeePool increases value returned by totalAssets().
    lastDripTime = block.timestamp;
    lastDripRate = currentDripRate(); // New drip rate based on the current utilization.
  }

  function nextDripAmount() public view returns (uint256) {
    // Apply the pending drip
    uint256 _deltaT = _elapsedTime(lastDripTime);
    if (_deltaT == 0 || state[address(this)] == CState.PAUSED) return 0;

    // A sane drip rate cannot overflow a uint256 when multiplied by a realistic deltaT.
    return supplierFeePool.mulWadDown(lastDripRate.unsafemul(_deltaT));
  }

  // -------------------------------
  // -------- State Getters --------
  // -------------------------------

  function numMarkets() external view returns (uint256) {
    return triggers.length;
  }

  function _getCostModel(address _trigger) internal view returns (ICostModel) {
    return ICostModel(address(uint160(marketConfig[_trigger].read(MC_COST_MODEL_SIZE, MC_COST_MODEL_OFFSET))));
  }

  // --------------------------
  // -------- Encoders --------
  // --------------------------
  function _encodeMarketInfo(IConfig.MarketInfo memory _marketInfo) internal pure returns (bytes32) {
    return bytes32(0)
        .write(MC_COST_MODEL_SIZE, MC_COST_MODEL_OFFSET, uint256(uint160(_marketInfo.costModel)))
        .write(MC_WEIGHT_SIZE, MC_WEIGHT_OFFSET, _marketInfo.weight)
        .write(MC_PURCHASE_FEE_SIZE, MC_PURCHASE_FEE_OFFSET, _marketInfo.purchaseFee);
  }

  // ----------------------
  // -------- Math --------
  // ----------------------

  function _min(uint256 x, uint256 y) internal pure returns (uint256) {
    return x < y ? x : y;
  }

  function _assetsNeeded(uint256 _assets) internal view returns (uint256 _assetAmtNeeded, uint256 _assetBalOfSelf) {
    _assetBalOfSelf = _assetBalanceOfSelf();
    uint256 _surplus = _assetBalOfSelf - assetBalance;
    _assetAmtNeeded = _assets.doz(_surplus);
  }

  function _elapsedTime(uint256 _time) internal view returns (uint256) {
    unchecked {
      // All time values passed to this function are only set using block.timestamp, which of course
      // monotonically increases, therefore this subtraction cannot overflow.
      return block.timestamp - _time;
    }
  }
}

/**
 * @dev Events that may be emitted by a trigger. Only `TriggerStateUpdated` is required.
 */
interface ITriggerEvents is ICState {
  /// @dev Emitted when a trigger's state is updated.
  event TriggerStateUpdated(CState indexed state);
}

/**
 * @dev The minimal functions a trigger must implement to work with the Cozy protocol.
 */
interface ITrigger is ITriggerEvents {
  /// @dev Emitted when a new set is added to the trigger's list of sets.
  event SetAdded(Set set);

  /// @notice The current trigger state. This should never return PAUSED.
  function state() external returns(CState);

  /// @notice Called by the Manager to add a newly created set to the trigger's list of sets.
  function addSet(Set set) external;
}

/**
 * @dev Additional functions that are recommended to have in a trigger, but are not required.
 */
interface IBaseTrigger is ITrigger {
  /// @notice Returns the set address at the specified index in the trigger's list of sets.
  function sets(uint256 index) external returns(Set set);

  /// @notice Returns all sets in the trigger's list of sets.
  function getSets() external returns(Set[] memory);

  /// @notice Returns the number of Sets that use this trigger in a market.
  function getSetsLength() external returns(uint256 setsLength);

  /// @notice Returns the address of the trigger's manager.
  function manager() external returns(Manager managerAddress);

  /// @notice The maximum amount of sets that can be added to this trigger.
  function MAX_SET_LENGTH() external returns(uint256 maxSetLength);
}

/**
 * @dev Core trigger interface and implementation. All triggers should inherit from this to ensure they conform
 * to the required trigger interface.
 */
abstract contract BaseTrigger is ICState, IBaseTrigger {
  /// @notice Current trigger state.
  CState public state;

  /// @notice The Sets that use this trigger in a market.
  /// @dev Use this function to retrieve a specific Set.
  Set[] public sets;

  /// @notice Prevent DOS attacks by limiting the number of sets.
  uint256 public constant MAX_SET_LENGTH = 25;

  /// @notice The manager of the Cozy protocol.
  Manager immutable public manager;

  error InvalidStateTransition();
  error Unauthorized();
  error SetLimitReached();

  constructor(Manager _manager) { manager = _manager; }

  /// @notice The Sets that use this trigger in a market.
  /// @dev Use this function to retrieve all Sets.
  function getSets() public view returns(Set[] memory) {
    return sets;
  }

  /// @notice The number of Sets that use this trigger in a market.
  function getSetsLength() public view returns(uint256) {
    return sets.length;
  }

  /// @dev Call this method to update Set addresses after deploy.
  function addSet(Set _set) external {
    (bool _setDataExists,) = manager.sets(_set);
    if (msg.sender != address(manager) || !_setDataExists) revert Unauthorized();
    uint256 setLength = sets.length;
    if (setLength >= MAX_SET_LENGTH) revert SetLimitReached();
    for (uint256 i = 0; i < setLength; i = CozyMath.uncheckedIncrement(i)) {
      if (sets[i] == _set) return;
    }
    sets.push(_set);
    emit SetAdded(_set);
  }

  /// @dev Child contracts should use this function to handle Trigger state transitions.
  function _updateTriggerState(CState _newState) internal {
    if (!_isValidTriggerStateTransition(state, _newState)) revert InvalidStateTransition();
    state = _newState;
    uint256 setLength = sets.length;
    for (uint256 i = 0; i < setLength; i = CozyMath.uncheckedIncrement(i)) {
      manager.updateMarketState(sets[i], _newState);
    }
    emit TriggerStateUpdated(_newState);
  }

  /// @dev Reimplement this function if different state transitions are needed.
  function _isValidTriggerStateTransition(CState _oldState, CState _newState) internal virtual returns(bool) {
    // | From / To | ACTIVE      | FROZEN      | PAUSED   | TRIGGERED |
    // | --------- | ----------- | ----------- | -------- | --------- |
    // | ACTIVE    | -           | true        | false    | true      |
    // | FROZEN    | true        | -           | false    | true      |
    // | PAUSED    | false       | false       | -        | false     | <-- PAUSED is a set-level state, triggers cannot be paused
    // | TRIGGERED | false       | false       | false    | -         | <-- TRIGGERED is a terminal state

    if (_oldState == CState.TRIGGERED) return false;
    if (_oldState == _newState) return true; // If oldState == newState, return true since the Manager will convert that into a no-op.
    if (_oldState == CState.ACTIVE && _newState == CState.FROZEN) return true;
    if (_oldState == CState.FROZEN && _newState == CState.ACTIVE) return true;
    if (_oldState == CState.ACTIVE && _newState == CState.TRIGGERED) return true;
    if (_oldState == CState.FROZEN && _newState == CState.TRIGGERED) return true;
    return false;
  }
}

// MECHANICS
// The Trigger and Manager know about each other. Whenever the trigger's state changes, it calls
// Manager.updateMarketState(_state) so the Market is immediately aware of the state update.
//
// DESIGN SPACE
// This trigger is a recommended contract template, but there is no way to enforce that all triggers
// confirm to this spec. The only true requirement of the trigger is that any state change calls
// Manager.updateMarketState(_state) to update the Market of the new trigger state, with _state being
// an enum of { ACTIVE, FROZEN, TRIGGERED }
//
// This template provides four parameters that trigger developers can use to customize the behavior
// of the trigger. These parameters are:
//
//   freezers:          A list of addresses that are allowed to change state from ACTIVE to FROZEN
//   boss:              A single address that is allowed to change state from ACTIVE to FROZEN, and
//                      also has permission to unfreeze the trigger, i.e. transition from FROZEN to
//                      ACTIVE or TRIGGERED
//   programmaticCheck: A method that implements atomic, on-chain logic to determine if a trigger
//                      condition has occurred
//   isAutoTrigger:     If true, and if a programmaticCheck is present, the trigger will transition
//                      to TRIGGERED when the programmaticCheck's condition was met. If false, the
//                      trigger will transition to FROZEN when the programmaticCheck condition is met
//
// This results in 16 possible trigger configurations. Some of these configurations are invalid, and
// some are effectively identical to one another. The table below documents these configurations.
// Because the core protocol has no way of enforcing that triggers are legitimate, we do not
// attempt to detect invalid configurations in the constructor, since not all invalid
// configurations are even detectable on-chain.
//
// Another property of this template is that the freezers and boss roles are immutable, i.e. they
// cannot be changed after deployment. This is recommended because these roles, especially the
// boss, have a lot of power, and having to monitor the trigger contract for address changes (e.g.
// from a multisig or DAO to an EOA) adds overhead and risk for protection seekers. However, this
// immutability is not enforced by the core protocol, so it is ultimately up to the trigger
// developer to decide whether roles should be immuable or not.
//
// CONFIGURATIONS
// +-------------------------------------------------+------------------------------------------------------------------------------+
// | freezers  boss    programmaticCheck  autoToggle | result                                                                       |
// +-------------------------------------------------+------------------------------------------------------------------------------+
// | none      False   no-op              False      | invalid: never toggles                                                       |
// | none      False   no-op              True       | invalid: never toggles                                                       |
// | none      False   has logic          False      | invalid: stuck after transition to frozen                                    |
// | none      False   has logic          True       | valid:   pure programmatic trigger                                           |
// +-------------------------------------------------+------------------------------------------------------------------------------+
// | none      True    no-op              False      | valid:   boss can freeze, boss can unfreeze                                  |
// | none      True    no-op              True       | valid:   boss can freeze, boss can unfreeze                                  |
// | none      True    has logic          False      | valid:   boss can freeze, boss can unfreeze, programmatic can freeze         |
// | none      True    has logic          True       | valid:   boss can freeze, boss can unfreeze, programmatic can trigger        |
// +-------------------------------------------------+------------------------------------------------------------------------------+
// | 1+        False   no-op              False      | invalid: never toggles                                                       |
// | 1+        False   no-op              True       | invalid: never toggles                                                       |
// | 1+        False   has logic          False      | invalid: stuck after transition to frozen                                    |
// | 1+        False   has logic          True       | valid:   pure programmatic trigger                                           |
// +-------------------------------------------------+------------------------------------------------------------------------------+
// | 1+        True    no-op              False      | valid:   boss can freeze, boss/freezer can unfreeze                          |
// | 1+        True    no-op              True       | valid:   boss can freeze, boss/freezer can unfreeze                          |
// | 1+        True    has logic          False      | valid:   boss/programmatic can freeze, boss/freezer can unfreeze             |
// | 1+        True    has logic          True       | valid:   boss can freeze, boss/freezer can unfreeze, programmatic can toggle |
// +-------------------------------------------------+------------------------------------------------------------------------------+

contract FlexibleTrigger is BaseTrigger {

  /// @notice Addresses with permission to transition the trigger state from ACTIVE to FROZEN.
  mapping(address => bool) public freezers;

  /// @notice Maximum amount of time that the trigger state can be FROZEN, in seconds. If the trigger state is
  /// FROZEN for a duration that exceeds maxFreezeDuration, the trigger state transitions to TRIGGERED.
  uint256 public immutable maxFreezeDuration;

  /// @notice Timestamp that the trigger entered the FROZEN state, if FROZEN. 0 if not FROZEN.
  uint256 public freezeTime;

  /// @notice Address with permission to (1) transition the trigger state from ACTIVE to FROZEN,
  /// and (2) unfreeze the trigger, i.e. transition from FROZEN to ACTIVE or TRIGGERED.
  address public immutable boss;

  /// @notice If true, a programmatic check automatically flips state from ACTIVE to TRIGGERED.
  /// If false, a programmatic check automatically flips state from ACTIVE to FROZEN.
  bool public isAutoTrigger;

  /// @dev Emitted when a new freezer is added to the trigger's list of allowed freezers.
  event FreezerAdded(address freezer);

  constructor(
    Manager _manager,
    address _boss,
    address[] memory _freezers,
    bool _isAutoTrigger,
    uint256 _maxFreezeDuration
  ) BaseTrigger(_manager) {
    boss = _boss;
    maxFreezeDuration = _maxFreezeDuration;
    isAutoTrigger = _isAutoTrigger;
    state = CState.ACTIVE;

    uint256 _lenFreezers = _freezers.length; // Cache to avoid MLOAD on each loop iteration.
    for (uint256 i = 0; i < _lenFreezers;) {
      freezers[_freezers[i]] = true;
      emit FreezerAdded(_freezers[i]);
      unchecked { i++; }
    }
  }

  /// @notice Transitions the trigger state from ACTIVE to FROZEN.
  function freeze() external {
    if (!freezers[msg.sender] && msg.sender != boss) revert Unauthorized();
    if (state != CState.ACTIVE) revert InvalidStateTransition();
    _updateTriggerState(CState.FROZEN);
    freezeTime = block.timestamp;
  }

  /// @notice Transitions the trigger state from FROZEN to ACTIVE.
  /// @dev We use a special method, instead of taking a `newState` input, to minimize the chance of
  /// the caller passing in the wrong `CState` value.
  function resume() external {
    if (msg.sender != boss) revert Unauthorized();
    if (state != CState.FROZEN) revert InvalidStateTransition();
    _updateTriggerState(CState.ACTIVE);
    freezeTime = 0;
  }

  /// @notice Transitions the trigger state from FROZEN to TRIGGERED
  /// @dev We use a special method, instead of taking a `newState` input, to minimize the chance of
  /// the caller passing in the wrong `CState` value.
  function trigger() external {
    if (msg.sender != boss) revert Unauthorized();
    _trigger();
  }

  function _trigger() internal {
    if (state != CState.FROZEN) revert InvalidStateTransition();
    _updateTriggerState(CState.TRIGGERED);
    freezeTime = 0;
  }

  /// @notice Callable by anyone, used to transition the trigger state from FROZEN to TRIGGERED
  /// if the trigger is currently FROZEN and has been FROZEN for longer than maxFreezeDuration.
  function publicTrigger() external {
    if (freezeTime + maxFreezeDuration >= block.timestamp) revert InvalidStateTransition();
    _trigger();
  }

  /// @notice If `programmaticCheck()` is defined, this method executes the check and makes the
  /// required state changes both in the trigger and the sets. This method will automatically
  /// transition the trigger state to TRIGGERED when `isAutoTrigger` is true, and transition it to
  /// FROZEN when `isAutoTrigger` is false.
  function runProgrammaticCheck() external returns (CState) {
    // Rather than revert if not active, we simply return the state and exit. Both behaviors are
    // acceptable, but returning is friendlier to the caller as they don't need to handle a revert
    // and can simply parse the transaction's logs to know if the call resulted in a state change.
    if (state != CState.ACTIVE) return state;

    bool _wasConditionMet = programmaticCheck();

    // If programmatic condition was not met, state does not change and we return current state.
    if (!_wasConditionMet) return state;

    // Otherwise, we toggle state accordingly.
    CState _newState = isAutoTrigger ? CState.TRIGGERED : CState.FROZEN;
    if (_newState == CState.FROZEN) freezeTime = block.timestamp;
    _updateTriggerState(_newState);

    return state;
  }

  /// @notice Executes logic to programmatically determine if the trigger should be toggled.
  /// @dev If a programmatic check is desired, override this function.
  function programmaticCheck() internal virtual returns (bool) {
    return false;
  }
}

// A mock trigger that allows anyone to change what the programmaticCheck returns. See FlexibleTrigger for more details.
contract MockTrigger is FlexibleTrigger {
  bool internal _programmaticCheckResponse;
  constructor(
    Manager _manager,
    address _boss,
    address[] memory _freezers,
    bool _autoTrigger,
    uint256 _maxFreezeDuration
  ) FlexibleTrigger(_manager, _boss, _freezers, _autoTrigger, _maxFreezeDuration) {}

  function programmaticCheck() internal override view returns (bool) {
    return _programmaticCheckResponse;
  }

  // Anyone can call this method to update the return value of programmaticCheck.
  function updateProgrammaticCheckResponse(bool _response) public {
    _programmaticCheckResponse = _response;
  }
}