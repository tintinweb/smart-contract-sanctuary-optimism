/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-08-25
*/

// Sources flattened with hardhat v2.9.6 https://hardhat.org

// File @rari-capital/solmate/src/auth/[email protected]

// -License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Provides a flexible and updatable auth pattern which is completely separate from application logic.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
abstract contract Auth {
    event OwnerUpdated(address indexed user, address indexed newOwner);

    event AuthorityUpdated(address indexed user, Authority indexed newAuthority);

    address public owner;

    Authority public authority;

    constructor(address _owner, Authority _authority) {
        owner = _owner;
        authority = _authority;

        emit OwnerUpdated(msg.sender, _owner);
        emit AuthorityUpdated(msg.sender, _authority);
    }

    modifier requiresAuth() virtual {
        require(isAuthorized(msg.sender, msg.sig), "UNAUTHORIZED");

        _;
    }

    function isAuthorized(address user, bytes4 functionSig) internal view virtual returns (bool) {
        Authority auth = authority; // Memoizing authority saves us a warm SLOAD, around 100 gas.

        // Checking if the caller is the owner only after calling the authority saves gas in most cases, but be
        // aware that this makes protected functions uncallable even to the owner if the authority is out of order.
        return (address(auth) != address(0) && auth.canCall(user, address(this), functionSig)) || user == owner;
    }

    function setAuthority(Authority newAuthority) public virtual {
        // We check if the caller is the owner first because we want to ensure they can
        // always swap out the authority even if it's reverting or using up a lot of gas.
        require(msg.sender == owner || authority.canCall(msg.sender, address(this), msg.sig));

        authority = newAuthority;

        emit AuthorityUpdated(msg.sender, newAuthority);
    }

    function setOwner(address newOwner) public virtual requiresAuth {
        owner = newOwner;

        emit OwnerUpdated(msg.sender, newOwner);
    }
}

/// @notice A generic interface for a contract which provides authorization data to an Auth instance.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
interface Authority {
    function canCall(
        address user,
        address target,
        bytes4 functionSig
    ) external view returns (bool);
}


// File @rari-capital/solmate/src/tokens/[email protected]

// -License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

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


// File @rari-capital/solmate/src/utils/[email protected]

// -License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

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


// File @rari-capital/solmate/src/utils/[email protected]

// -License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Gas optimized reentrancy protection for smart contracts.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/ReentrancyGuard.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol)
abstract contract ReentrancyGuard {
    uint256 private locked = 1;

    modifier nonReentrant() virtual {
        require(locked == 1, "REENTRANCY");

        locked = 2;

        _;

        locked = 1;
    }
}


// File @rari-capital/solmate/src/utils/[email protected]

// -License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

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


// File contracts/utils/Pausable.sol

// -License-Identifier: MIT
pragma solidity 0.8.9;

abstract contract Pausable {

    bool private _paused;
    bool private _depositsPaused;

    constructor() {
        _paused = false;
        _depositsPaused = false;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function depositsPaused() public view virtual returns (bool) {
        return _depositsPaused;
    }

    modifier whenNotPaused() {
        if (paused()) {
            revert Paused();
        }
        _;
    }

    modifier whenPaused() {
        if (!paused()) {
            revert NotPaused();
        }
        _;
    }

    modifier whenDepositsNotPaused() {
        if(depositsPaused()) {
            revert DepositsPaused();
        }
        _;
    }

    modifier whenDepositsPaused() {
        if (!depositsPaused()) {
            revert DepositsNotPaused();
        }
        _;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        _depositsPaused = true;
        emit SetPaused(msg.sender);
    }

    function _pauseDeposits() internal virtual whenDepositsNotPaused {
        _depositsPaused = true;
        emit SetDepositsPaused(msg.sender);
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        _depositsPaused = false;
        emit SetUnpaused(msg.sender);
    }

    function _unpauseDeposits() internal virtual whenDepositsPaused {
        _depositsPaused = false;
        emit SetDepositsUnpaused(msg.sender);
    }

    error Paused();
    error DepositsPaused();
    error NotPaused();
    error DepositsNotPaused();

    event SetPaused(address account);
    event SetDepositsPaused(address account);
    event SetUnpaused(address account);
    event SetDepositsUnpaused(address account);
}


// File contracts/interfaces/IAllowList.sol

// -License-Identifier: MIT
pragma solidity 0.8.9;

interface IAllowList {
    function isAllowed(address) external view returns (bool);
}


// File contracts/interfaces/IPolynomialVaultToken.sol

// -License-Identifier: MIT
pragma solidity 0.8.9;

interface IPolynomialVaultToken {
    function mint(address _user, uint256 _amt) external;
    function burn(address _user, uint256 _amt) external;

    function totalSupply() external view returns (uint256 totalSupply);
    function balanceOf(address user) external view returns (uint256 balance);
}


// File contracts/interfaces/IPolynomialVault.sol

// -License-Identifier: MIT
pragma solidity 0.8.9;

interface IPolynomialVault {}


// File contracts/interfaces/synthetix/IExchangeRates.sol

// -License-Identifier: MIT
pragma solidity 0.8.9;

interface IExchangeRates {
    function rateAndInvalid(
        bytes32 currencyKey
    ) external view returns (uint rate, bool isInvalid);
}


// File contracts/interfaces/synthetix/IFuturesMarket.sol

// -License-Identifier: MIT
pragma solidity 0.8.9;

interface IFuturesMarket {
    function assetPrice() external view returns (uint256 price, bool invalid);

    function baseAsset() external view returns (bytes32 key);

    function remainingMargin(address account) external view returns (uint256 marginRemaining, bool invalid);

    function transferMargin(int256 marginDelta) external;

    function withdrawAllMargin() external;

    function modifyPositionWithTracking(int256 sizeDelta, bytes32 trackingCode) external;
}


// File contracts/interfaces/lyra/IOptionMarket.sol

// -License-Identifier: MIT
pragma solidity 0.8.9;

interface IOptionMarket {
    enum OptionType {
        LONG_CALL,
        LONG_PUT,
        SHORT_CALL_BASE,
        SHORT_CALL_QUOTE,
        SHORT_PUT_QUOTE
    }

    struct Strike {
        // strike listing identifier
        uint id;
        // strike price
        uint strikePrice;
        // volatility component specific to the strike listing (boardIv * skew = vol of strike)
        uint skew;
        // total user long call exposure
        uint longCall;
        // total user short call (base collateral) exposure
        uint shortCallBase;
        // total user short call (quote collateral) exposure
        uint shortCallQuote;
        // total user long put exposure
        uint longPut;
        // total user short put (quote collateral) exposure
        uint shortPut;
        // id of board to which strike belongs
        uint boardId;
    }
    
    struct OptionBoard {
        // board identifier
        uint id;
        // expiry of all strikes belonging to board
        uint expiry;
        // volatility component specific to board (boardIv * skew = vol of strike)
        uint iv;
        // admin settable flag blocking all trading on this board
        bool frozen;
        // list of all strikes belonging to this board
        uint[] strikeIds;
    }

    function getStrikeAndBoard(uint strikeId) external view returns (Strike memory, OptionBoard memory);

    function getStrikeAndExpiry(uint strikeId) external view returns (uint strikePrice, uint expiry);

    function getSettlementParameters(uint strikeId) external view returns (
        uint strikePrice,
        uint priceAtExpiry,
        uint strikeToBaseReturned
    );

    function addCollateral(uint positionId, uint amountCollateral) external;
}


// File contracts/interfaces/lyra/IOptionMarketWrapperWithSwaps.sol

// -License-Identifier: MIT
pragma solidity 0.8.9;

interface IOptionMarketWrapperWithSwaps {
    struct ReturnDetails {
        address market;
        uint positionId;
        address owner;
        uint amount;
        uint totalCost;
        uint totalFee;
        int swapFee;
        address token;
    }

    struct OptionPositionParams {
        IOptionMarket optionMarket;
        uint strikeId; // The id of the relevant OptionListing
        uint positionId;
        uint iterations;
        uint setCollateralTo;
        uint currentCollateral;
        IOptionMarket.OptionType optionType; // Is the trade a long/short & call/put?
        uint amount; // The amount the user has requested to close
        uint minCost; // Min amount for the cost of the trade
        uint maxCost; // Max amount for the cost of the trade
        uint inputAmount; // Amount of stable coins the user can use
        ERC20 inputAsset; // Address of coin user wants to open with
    }

    function openPosition(OptionPositionParams memory params) external returns (ReturnDetails memory returnDetails);

    function closePosition(OptionPositionParams memory params) external returns (ReturnDetails memory returnDetails);
}


// File contracts/interfaces/lyra/IOptionToken.sol

// -License-Identifier: MIT
pragma solidity 0.8.9;

interface IOptionToken {
    enum PositionState {
        EMPTY,
        ACTIVE,
        CLOSED,
        LIQUIDATED,
        SETTLED,
        MERGED
    }

    function getPositionState(uint positionId) external view returns (PositionState);

    function getApproved(uint256 tokenId) external view returns (address operator);

    function approve(address to, uint256 tokenId) external;
}


// File contracts/interfaces/lyra/IOptionGreekCache.sol

// -License-Identifier: MIT
pragma solidity 0.8.9;

interface IOptionGreekCache {
    struct GreekCacheParameters {
        // Cap the number of strikes per board to avoid hitting gasLimit constraints
        uint maxStrikesPerBoard;
        // How much spot price can move since last update before deposits/withdrawals are blocked
        uint acceptableSpotPricePercentMove;
        // How much time has passed since last update before deposits/withdrawals are blocked
        uint staleUpdateDuration;
        // Length of the GWAV for the baseline volatility used to fire the vol circuit breaker
        uint varianceIvGWAVPeriod;
        // Length of the GWAV for the skew ratios used to fire the vol circuit breaker
        uint varianceSkewGWAVPeriod;
        // Length of the GWAV for the baseline used to determine the NAV of the pool
        uint optionValueIvGWAVPeriod;
        // Length of the GWAV for the skews used to determine the NAV of the pool
        uint optionValueSkewGWAVPeriod;
        // Minimum skew that will be fed into the GWAV calculation
        // Prevents near 0 values being used to heavily manipulate the GWAV
        uint gwavSkewFloor;
        // Maximum skew that will be fed into the GWAV calculation
        uint gwavSkewCap;
        // Interest/risk free rate
        int rateAndCarry;
    }

    function getGreekCacheParams() external view returns (GreekCacheParameters memory);

    function getIvGWAV(uint boardId, uint secondsAgo) external view returns (uint ivGWAV);

    function getSkewGWAV(uint strikeId, uint secondsAgo) external view returns (uint skewGWAV);
}


// File contracts/libraries/DecimalMath.sol

//-License-Identifier: MIT
//
//Copyright (c) 2019 Synthetix
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

pragma solidity ^0.8.9;

/**
 * @title DecimalMath
 * @author Lyra
 * @dev Modified synthetix SafeDecimalMath to include internal arithmetic underflow/overflow.
 * @dev https://docs.synthetix.io/contracts/source/libraries/SafeDecimalMath/
 */

library DecimalMath {
  /* Number of decimal places in the representations. */
  uint8 public constant decimals = 18;
  uint8 public constant highPrecisionDecimals = 27;

  /* The number representing 1.0. */
  uint public constant UNIT = 10**uint(decimals);

  /* The number representing 1.0 for higher fidelity numbers. */
  uint public constant PRECISE_UNIT = 10**uint(highPrecisionDecimals);
  uint private constant UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR = 10**uint(highPrecisionDecimals - decimals);

  /**
   * @return Provides an interface to UNIT.
   */
  function unit() external pure returns (uint) {
    return UNIT;
  }

  /**
   * @return Provides an interface to PRECISE_UNIT.
   */
  function preciseUnit() external pure returns (uint) {
    return PRECISE_UNIT;
  }

  /**
   * @return The result of multiplying x and y, interpreting the operands as fixed-point
   * decimals.
   *
   * @dev A unit factor is divided out after the product of x and y is evaluated,
   * so that product must be less than 2**256. As this is an integer division,
   * the internal division always rounds down. This helps save on gas. Rounding
   * is more expensive on gas.
   */
  function multiplyDecimal(uint x, uint y) internal pure returns (uint) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    return (x * y) / UNIT;
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of the specified precision unit.
   *
   * @dev The operands should be in the form of a the specified unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function _multiplyDecimalRound(
    uint x,
    uint y,
    uint precisionUnit
  ) private pure returns (uint) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    uint quotientTimesTen = (x * y) / (precisionUnit / 10);

    if (quotientTimesTen % 10 >= 5) {
      quotientTimesTen += 10;
    }

    return quotientTimesTen / 10;
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a precise unit.
   *
   * @dev The operands should be in the precise unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRoundPrecise(uint x, uint y) internal pure returns (uint) {
    return _multiplyDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a standard unit.
   *
   * @dev The operands should be in the standard unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRound(uint x, uint y) internal pure returns (uint) {
    return _multiplyDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is a high
   * precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and UNIT must be less than 2**256. As
   * this is an integer division, the result is always rounded down.
   * This helps save on gas. Rounding is more expensive on gas.
   */
  function divideDecimal(uint x, uint y) internal pure returns (uint) {
    /* Reintroduce the UNIT factor that will be divided out by y. */
    return (x * UNIT) / y;
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * decimal in the precision unit specified in the parameter.
   *
   * @dev y is divided after the product of x and the specified precision unit
   * is evaluated, so the product of x and the specified precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function _divideDecimalRound(
    uint x,
    uint y,
    uint precisionUnit
  ) private pure returns (uint) {
    uint resultTimesTen = (x * (precisionUnit * 10)) / y;

    if (resultTimesTen % 10 >= 5) {
      resultTimesTen += 10;
    }

    return resultTimesTen / 10;
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * standard precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and the standard precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRound(uint x, uint y) internal pure returns (uint) {
    return _divideDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * high precision decimal.
   *
   * @dev y is divided after the product of x and the high precision unit
   * is evaluated, so the product of x and the high precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRoundPrecise(uint x, uint y) internal pure returns (uint) {
    return _divideDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @dev Convert a standard decimal representation to a high precision one.
   */
  function decimalToPreciseDecimal(uint i) internal pure returns (uint) {
    return i * UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR;
  }

  /**
   * @dev Convert a high precision decimal to a standard decimal representation.
   */
  function preciseDecimalToDecimal(uint i) internal pure returns (uint) {
    uint quotientTimesTen = i / (UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR / 10);

    if (quotientTimesTen % 10 >= 5) {
      quotientTimesTen += 10;
    }

    return quotientTimesTen / 10;
  }
}


// File contracts/libraries/SignedDecimalMath.sol

//-License-Identifier: MIT
//
//Copyright (c) 2019 Synthetix
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

pragma solidity ^0.8.9;

/**
 * @title SignedDecimalMath
 * @author Lyra
 * @dev Modified synthetix SafeSignedDecimalMath to include internal arithmetic underflow/overflow.
 * @dev https://docs.synthetix.io/contracts/source/libraries/safedecimalmath
 */
library SignedDecimalMath {
  /* Number of decimal places in the representations. */
  uint8 public constant decimals = 18;
  uint8 public constant highPrecisionDecimals = 27;

  /* The number representing 1.0. */
  int public constant UNIT = int(10**uint(decimals));

  /* The number representing 1.0 for higher fidelity numbers. */
  int public constant PRECISE_UNIT = int(10**uint(highPrecisionDecimals));
  int private constant UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR = int(10**uint(highPrecisionDecimals - decimals));

  /**
   * @return Provides an interface to UNIT.
   */
  function unit() external pure returns (int) {
    return UNIT;
  }

  /**
   * @return Provides an interface to PRECISE_UNIT.
   */
  function preciseUnit() external pure returns (int) {
    return PRECISE_UNIT;
  }

  /**
   * @dev Rounds an input with an extra zero of precision, returning the result without the extra zero.
   * Half increments round away from zero; positive numbers at a half increment are rounded up,
   * while negative such numbers are rounded down. This behaviour is designed to be consistent with the
   * unsigned version of this library (SafeDecimalMath).
   */
  function _roundDividingByTen(int valueTimesTen) private pure returns (int) {
    int increment;
    if (valueTimesTen % 10 >= 5) {
      increment = 10;
    } else if (valueTimesTen % 10 <= -5) {
      increment = -10;
    }
    return (valueTimesTen + increment) / 10;
  }

  /**
   * @return The result of multiplying x and y, interpreting the operands as fixed-point
   * decimals.
   *
   * @dev A unit factor is divided out after the product of x and y is evaluated,
   * so that product must be less than 2**256. As this is an integer division,
   * the internal division always rounds down. This helps save on gas. Rounding
   * is more expensive on gas.
   */
  function multiplyDecimal(int x, int y) internal pure returns (int) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    return (x * y) / UNIT;
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of the specified precision unit.
   *
   * @dev The operands should be in the form of a the specified unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function _multiplyDecimalRound(
    int x,
    int y,
    int precisionUnit
  ) private pure returns (int) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    int quotientTimesTen = (x * y) / (precisionUnit / 10);
    return _roundDividingByTen(quotientTimesTen);
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a precise unit.
   *
   * @dev The operands should be in the precise unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRoundPrecise(int x, int y) internal pure returns (int) {
    return _multiplyDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a standard unit.
   *
   * @dev The operands should be in the standard unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRound(int x, int y) internal pure returns (int) {
    return _multiplyDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is a high
   * precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and UNIT must be less than 2**256. As
   * this is an integer division, the result is always rounded down.
   * This helps save on gas. Rounding is more expensive on gas.
   */
  function divideDecimal(int x, int y) internal pure returns (int) {
    /* Reintroduce the UNIT factor that will be divided out by y. */
    return (x * UNIT) / y;
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * decimal in the precision unit specified in the parameter.
   *
   * @dev y is divided after the product of x and the specified precision unit
   * is evaluated, so the product of x and the specified precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function _divideDecimalRound(
    int x,
    int y,
    int precisionUnit
  ) private pure returns (int) {
    int resultTimesTen = (x * (precisionUnit * 10)) / y;
    return _roundDividingByTen(resultTimesTen);
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * standard precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and the standard precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRound(int x, int y) internal pure returns (int) {
    return _divideDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * high precision decimal.
   *
   * @dev y is divided after the product of x and the high precision unit
   * is evaluated, so the product of x and the high precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRoundPrecise(int x, int y) internal pure returns (int) {
    return _divideDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @dev Convert a standard decimal representation to a high precision one.
   */
  function decimalToPreciseDecimal(int i) internal pure returns (int) {
    return i * UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR;
  }

  /**
   * @dev Convert a high precision decimal to a standard decimal representation.
   */
  function preciseDecimalToDecimal(int i) internal pure returns (int) {
    int quotientTimesTen = i / (UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR / 10);
    return _roundDividingByTen(quotientTimesTen);
  }
}


// File contracts/libraries/HigherMath.sol

// -License-Identifier: UNLICENSED
pragma solidity 0.8.9;

// Slightly modified version of:
// - https://github.com/recmo/experiment-solexp/blob/605738f3ed72d6c67a414e992be58262fbc9bb80/src/FixedPointMathLib.sol
library HigherMath {
  /// @dev Computes ln(x) for a 1e27 fixed point. Loses 9 last significant digits of precision.
  function lnPrecise(int x) internal pure returns (int r) {
    return ln(x / 1e9) * 1e9;
  }

  /// @dev Computes e ^ x for a 1e27 fixed point. Loses 9 last significant digits of precision.
  function expPrecise(int x) internal pure returns (uint r) {
    return exp(x / 1e9) * 1e9;
  }

  // Computes ln(x) in 1e18 fixed point.
  // Reverts if x is negative or zero.
  // Consumes 670 gas.
  function ln(int x) internal pure returns (int r) {
    unchecked {
      if (x < 1) {
        if (x < 0) revert LnNegativeUndefined();
        revert Overflow();
      }

      // We want to convert x from 10**18 fixed point to 2**96 fixed point.
      // We do this by multiplying by 2**96 / 10**18.
      // But since ln(x * C) = ln(x) + ln(C), we can simply do nothing here
      // and add ln(2**96 / 10**18) at the end.

      // Reduce range of x to (1, 2) * 2**96
      // ln(2^k * x) = k * ln(2) + ln(x)
      // Note: inlining ilog2 saves 8 gas.
      int k = int(ilog2(uint(x))) - 96;
      x <<= uint(159 - k);
      x = int(uint(x) >> 159);

      // Evaluate using a (8, 8)-term rational approximation
      // p is made monic, we will multiply by a scale factor later
      int p = x + 3273285459638523848632254066296;
      p = ((p * x) >> 96) + 24828157081833163892658089445524;
      p = ((p * x) >> 96) + 43456485725739037958740375743393;
      p = ((p * x) >> 96) - 11111509109440967052023855526967;
      p = ((p * x) >> 96) - 45023709667254063763336534515857;
      p = ((p * x) >> 96) - 14706773417378608786704636184526;
      p = p * x - (795164235651350426258249787498 << 96);
      //emit log_named_int("p", p);
      // We leave p in 2**192 basis so we don't need to scale it back up for the division.
      // q is monic by convention
      int q = x + 5573035233440673466300451813936;
      q = ((q * x) >> 96) + 71694874799317883764090561454958;
      q = ((q * x) >> 96) + 283447036172924575727196451306956;
      q = ((q * x) >> 96) + 401686690394027663651624208769553;
      q = ((q * x) >> 96) + 204048457590392012362485061816622;
      q = ((q * x) >> 96) + 31853899698501571402653359427138;
      q = ((q * x) >> 96) + 909429971244387300277376558375;
      assembly {
        // Div in assembly because solidity adds a zero check despite the `unchecked`.
        // The q polynomial is known not to have zeros in the domain. (All roots are complex)
        // No scaling required because p is already 2**96 too large.
        r := sdiv(p, q)
      }
      // r is in the range (0, 0.125) * 2**96

      // Finalization, we need to
      // * multiply by the scale factor s = 5.549…
      // * add ln(2**96 / 10**18)
      // * add k * ln(2)
      // * multiply by 10**18 / 2**96 = 5**18 >> 78
      // mul s * 5e18 * 2**96, base is now 5**18 * 2**192
      r *= 1677202110996718588342820967067443963516166;
      // add ln(2) * k * 5e18 * 2**192
      r += 16597577552685614221487285958193947469193820559219878177908093499208371 * k;
      // add ln(2**96 / 10**18) * 5e18 * 2**192
      r += 600920179829731861736702779321621459595472258049074101567377883020018308;
      // base conversion: mul 2**18 / 2**192
      r >>= 174;
    }
  }

  // Integer log2
  // @returns floor(log2(x)) if x is nonzero, otherwise 0. This is the same
  //          as the location of the highest set bit.
  // Consumes 232 gas. This could have been an 3 gas EVM opcode though.
  function ilog2(uint x) internal pure returns (uint r) {
    assembly {
      r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
      r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
      r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
      r := or(r, shl(4, lt(0xffff, shr(r, x))))
      r := or(r, shl(3, lt(0xff, shr(r, x))))
      r := or(r, shl(2, lt(0xf, shr(r, x))))
      r := or(r, shl(1, lt(0x3, shr(r, x))))
      r := or(r, lt(0x1, shr(r, x)))
    }
  }

  // Computes e^x in 1e18 fixed point.
  function exp(int x) internal pure returns (uint r) {
    unchecked {
      // Input x is in fixed point format, with scale factor 1/1e18.

      // When the result is < 0.5 we return zero. This happens when
      // x <= floor(log(0.5e18) * 1e18) ~ -42e18
      if (x <= -42139678854452767551) {
        return 0;
      }

      // When the result is > (2**255 - 1) / 1e18 we can not represent it
      // as an int256. This happens when x >= floor(log((2**255 -1) / 1e18) * 1e18) ~ 135.
      if (x >= 135305999368893231589) revert ExpOverflow();

      // x is now in the range (-42, 136) * 1e18. Convert to (-42, 136) * 2**96
      // for more intermediate precision and a binary basis. This base conversion
      // is a multiplication by 1e18 / 2**96 = 5**18 / 2**78.
      x = (x << 78) / 5**18;

      // Reduce range of x to (-½ ln 2, ½ ln 2) * 2**96 by factoring out powers of two
      // such that exp(x) = exp(x') * 2**k, where k is an integer.
      // Solving this gives k = round(x / log(2)) and x' = x - k * log(2).
      int k = ((x << 96) / 54916777467707473351141471128 + 2**95) >> 96;
      x = x - k * 54916777467707473351141471128;
      // k is in the range [-61, 195].

      // Evaluate using a (6, 7)-term rational approximation
      // p is made monic, we will multiply by a scale factor later
      int p = x + 2772001395605857295435445496992;
      p = ((p * x) >> 96) + 44335888930127919016834873520032;
      p = ((p * x) >> 96) + 398888492587501845352592340339721;
      p = ((p * x) >> 96) + 1993839819670624470859228494792842;
      p = p * x + (4385272521454847904632057985693276 << 96);
      // We leave p in 2**192 basis so we don't need to scale it back up for the division.
      // Evaluate using using Knuth's scheme from p. 491.
      int z = x + 750530180792738023273180420736;
      z = ((z * x) >> 96) + 32788456221302202726307501949080;
      int w = x - 2218138959503481824038194425854;
      w = ((w * z) >> 96) + 892943633302991980437332862907700;
      int q = z + w - 78174809823045304726920794422040;
      q = ((q * w) >> 96) + 4203224763890128580604056984195872;
      assembly {
        // Div in assembly because solidity adds a zero check despite the `unchecked`.
        // The q polynomial is known not to have zeros in the domain. (All roots are complex)
        // No scaling required because p is already 2**96 too large.
        r := sdiv(p, q)
      }
      // r should be in the range (0.09, 0.25) * 2**96.

      // We now need to multiply r by
      //  * the scale factor s = ~6.031367120...,
      //  * the 2**k factor from the range reduction, and
      //  * the 1e18 / 2**96 factor for base converison.
      // We do all of this at once, with an intermediate result in 2**213 basis
      // so the final right shift is always by a positive amount.
      r = (uint(r) * 3822833074963236453042738258902158003155416615667) >> uint(195 - k);
    }
  }

  error Overflow();
  error ExpOverflow();
  error LnNegativeUndefined();
}


// File contracts/libraries/BlackScholes.sol

// -License-Identifier: ISC

//ISC License
//
//Copyright (c) 2021 Lyra Finance
//
//Permission to use, copy, modify, and/or distribute this software for any
//purpose with or without fee is hereby granted, provided that the above
//copyright notice and this permission notice appear in all copies.
//
//THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
//REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
//AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
//INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
//LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
//OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
//PERFORMANCE OF THIS SOFTWARE.

pragma solidity 0.8.9;



/**
* @title BlackScholes
* @author Lyra
* @dev Contract to compute the black scholes price of options. Where the unit is unspecified, it should be treated as a
* PRECISE_DECIMAL, which has 1e27 units of precision. The default decimal matches the ethereum standard of 1e18 units
* of precision.
*/
library BlackScholesLib {
    using DecimalMath for uint;
    using SignedDecimalMath for int;
    
    struct PricesDeltaStdVega {
        uint callPrice;
        uint putPrice;
        int callDelta;
        int putDelta;
        uint vega;
        uint stdVega;
    }
    
    /**
    * @param timeToExpirySec Number of seconds to the expiry of the option
    * @param volatilityDecimal Implied volatility over the period til expiry as a percentage
    * @param spotDecimal The current price of the base asset
    * @param strikePriceDecimal The strikePrice price of the option
    * @param rateDecimal The percentage risk free rate + carry cost
    */
    struct BlackScholesInputs {
        uint timeToExpirySec;
        uint volatilityDecimal;
        uint spotDecimal;
        uint strikePriceDecimal;
        int rateDecimal;
    }
    
    uint private constant SECONDS_PER_YEAR = 31536000;
    /// @dev Internally this library uses 27 decimals of precision
    uint private constant PRECISE_UNIT = 1e27;
    uint private constant SQRT_TWOPI = 2506628274631000502415765285;
    /// @dev Below this value, return 0
    int private constant MIN_CDF_STD_DIST_INPUT = (int(PRECISE_UNIT) * -45) / 10; // -4.5
    /// @dev Above this value, return 1
    int private constant MAX_CDF_STD_DIST_INPUT = int(PRECISE_UNIT) * 10;
    /// @dev Value to use to avoid any division by 0 or values near 0
    uint private constant MIN_T_ANNUALISED = PRECISE_UNIT / SECONDS_PER_YEAR; // 1 second
    uint private constant MIN_VOLATILITY = PRECISE_UNIT / 10000; // 0.001%
    uint private constant VEGA_STANDARDISATION_MIN_DAYS = 7 days;
    /// @dev Magic numbers for normal CDF
    uint private constant SPLIT = 7071067811865470000000000000;
    uint private constant N0 = 220206867912376000000000000000;
    uint private constant N1 = 221213596169931000000000000000;
    uint private constant N2 = 112079291497871000000000000000;
    uint private constant N3 = 33912866078383000000000000000;
    uint private constant N4 = 6373962203531650000000000000;
    uint private constant N5 = 700383064443688000000000000;
    uint private constant N6 = 35262496599891100000000000;
    uint private constant M0 = 440413735824752000000000000000;
    uint private constant M1 = 793826512519948000000000000000;
    uint private constant M2 = 637333633378831000000000000000;
    uint private constant M3 = 296564248779674000000000000000;
    uint private constant M4 = 86780732202946100000000000000;
    uint private constant M5 = 16064177579207000000000000000;
    uint private constant M6 = 1755667163182640000000000000;
    uint private constant M7 = 88388347648318400000000000;
    
    /////////////////////////////////////
    // Option Pricing public functions //
    /////////////////////////////////////
    
    /**
    * @dev Returns call and put prices for options with given parameters.
    */
    function optionPrices(BlackScholesInputs memory bsInput) public pure returns (uint call, uint put) {
        uint tAnnualised = _annualise(bsInput.timeToExpirySec);
        uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();
        uint strikePricePrecise = bsInput.strikePriceDecimal.decimalToPreciseDecimal();
        int ratePrecise = bsInput.rateDecimal.decimalToPreciseDecimal();
        (int d1, int d2) = _d1d2(
            tAnnualised,
            bsInput.volatilityDecimal.decimalToPreciseDecimal(),
            spotPrecise,
            strikePricePrecise,
            ratePrecise
        );
        (call, put) = _optionPrices(tAnnualised, spotPrecise, strikePricePrecise, ratePrecise, d1, d2);
        return (call.preciseDecimalToDecimal(), put.preciseDecimalToDecimal());
    }
    
    /**
    * @dev Returns call/put prices and delta/stdVega for options with given parameters.
    */
    function pricesDeltaStdVega(BlackScholesInputs memory bsInput) public pure returns (PricesDeltaStdVega memory) {
        uint tAnnualised = _annualise(bsInput.timeToExpirySec);
        uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();
        
        (int d1, int d2) = _d1d2(
            tAnnualised,
            bsInput.volatilityDecimal.decimalToPreciseDecimal(),
            spotPrecise,
            bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
            bsInput.rateDecimal.decimalToPreciseDecimal()
        );
        (uint callPrice, uint putPrice) = _optionPrices(
            tAnnualised,
            spotPrecise,
            bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
            bsInput.rateDecimal.decimalToPreciseDecimal(),
            d1,
            d2
        );
        (uint vegaPrecise, uint stdVegaPrecise) = _standardVega(d1, spotPrecise, bsInput.timeToExpirySec);
        (int callDelta, int putDelta) = _delta(d1);
        
        return
        PricesDeltaStdVega(
            callPrice.preciseDecimalToDecimal(),
            putPrice.preciseDecimalToDecimal(),
            callDelta.preciseDecimalToDecimal(),
            putDelta.preciseDecimalToDecimal(),
            vegaPrecise.preciseDecimalToDecimal(),
            stdVegaPrecise.preciseDecimalToDecimal()
        );
    }
    
    /**
    * @dev Returns call delta given parameters.
    */
    
    function delta(BlackScholesInputs memory bsInput) public pure returns (int callDeltaDecimal, int putDeltaDecimal) {
        uint tAnnualised = _annualise(bsInput.timeToExpirySec);
        uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();
        
        (int d1, ) = _d1d2(
            tAnnualised,
            bsInput.volatilityDecimal.decimalToPreciseDecimal(),
            spotPrecise,
            bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
            bsInput.rateDecimal.decimalToPreciseDecimal()
        );
        
        (int callDelta, int putDelta) = _delta(d1);
        return (callDelta.preciseDecimalToDecimal(), putDelta.preciseDecimalToDecimal());
    }
    
    /**
    * @dev Returns non-normalized vega given parameters. Quoted in cents.
    */
    function vega(BlackScholesInputs memory bsInput) public pure returns (uint vegaDecimal) {
        uint tAnnualised = _annualise(bsInput.timeToExpirySec);
        uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();
        
        (int d1, ) = _d1d2(
            tAnnualised,
            bsInput.volatilityDecimal.decimalToPreciseDecimal(),
            spotPrecise,
            bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
            bsInput.rateDecimal.decimalToPreciseDecimal()
        );
        return _vega(tAnnualised, spotPrecise, d1).preciseDecimalToDecimal();
    }
    
    //////////////////////
    // Computing Greeks //
    //////////////////////
    
    /**
    * @dev Returns internal coefficients of the Black-Scholes call price formula, d1 and d2.
    * @param tAnnualised Number of years to expiry
    * @param volatility Implied volatility over the period til expiry as a percentage
    * @param spot The current price of the base asset
    * @param strikePrice The strikePrice price of the option
    * @param rate The percentage risk free rate + carry cost
    */
    function _d1d2(
        uint tAnnualised,
        uint volatility,
        uint spot,
        uint strikePrice,
        int rate
    ) internal pure returns (int d1, int d2) {
        // Set minimum values for tAnnualised and volatility to not break computation in extreme scenarios
        // These values will result in option prices reflecting only the difference in stock/strikePrice, which is expected.
        // This should be caught before calling this function, however the function shouldn't break if the values are 0.
        tAnnualised = tAnnualised < MIN_T_ANNUALISED ? MIN_T_ANNUALISED : tAnnualised;
        volatility = volatility < MIN_VOLATILITY ? MIN_VOLATILITY : volatility;
        
        int vtSqrt = int(volatility.multiplyDecimalRoundPrecise(_sqrtPrecise(tAnnualised)));
        int log = HigherMath.lnPrecise(int(spot.divideDecimalRoundPrecise(strikePrice)));
        int v2t = (int(volatility.multiplyDecimalRoundPrecise(volatility) / 2) + rate).multiplyDecimalRoundPrecise(
            int(tAnnualised)
        );
        d1 = (log + v2t).divideDecimalRoundPrecise(vtSqrt);
        d2 = d1 - vtSqrt;
    }
    
    /**
    * @dev Internal coefficients of the Black-Scholes call price formula.
    * @param tAnnualised Number of years to expiry
    * @param spot The current price of the base asset
    * @param strikePrice The strikePrice price of the option
    * @param rate The percentage risk free rate + carry cost
    * @param d1 Internal coefficient of Black-Scholes
    * @param d2 Internal coefficient of Black-Scholes
    */
    function _optionPrices(
        uint tAnnualised,
        uint spot,
        uint strikePrice,
        int rate,
        int d1,
        int d2
    ) internal pure returns (uint call, uint put) {
        uint strikePricePV = strikePrice.multiplyDecimalRoundPrecise(
            HigherMath.expPrecise(int(-rate.multiplyDecimalRoundPrecise(int(tAnnualised))))
        );
        uint spotNd1 = spot.multiplyDecimalRoundPrecise(_stdNormalCDF(d1));
        uint strikePriceNd2 = strikePricePV.multiplyDecimalRoundPrecise(_stdNormalCDF(d2));
        
        // We clamp to zero if the minuend is less than the subtrahend
        // In some scenarios it may be better to compute put price instead and derive call from it depending on which way
        // around is more precise.
        call = strikePriceNd2 <= spotNd1 ? spotNd1 - strikePriceNd2 : 0;
        put = call + strikePricePV;
        put = spot <= put ? put - spot : 0;
    }
    
    /*
    * Greeks
    */
    
    /**
    * @dev Returns the option's delta value
    * @param d1 Internal coefficient of Black-Scholes
    */
    function _delta(int d1) internal pure returns (int callDelta, int putDelta) {
        callDelta = int(_stdNormalCDF(d1));
        putDelta = callDelta - int(PRECISE_UNIT);
    }
    
    /**
    * @dev Returns the option's vega value based on d1. Quoted in cents.
    *
    * @param d1 Internal coefficient of Black-Scholes
    * @param tAnnualised Number of years to expiry
    * @param spot The current price of the base asset
    */
    function _vega(
        uint tAnnualised,
        uint spot,
        int d1
    ) internal pure returns (uint) {
        return _sqrtPrecise(tAnnualised).multiplyDecimalRoundPrecise(_stdNormal(d1).multiplyDecimalRoundPrecise(spot));
    }
    
    /**
    * @dev Returns the option's vega value with expiry modified to be at least VEGA_STANDARDISATION_MIN_DAYS
    * @param d1 Internal coefficient of Black-Scholes
    * @param spot The current price of the base asset
    * @param timeToExpirySec Number of seconds to expiry
    */
    function _standardVega(
        int d1,
        uint spot,
        uint timeToExpirySec
    ) internal pure returns (uint, uint) {
        uint tAnnualised = _annualise(timeToExpirySec);
        uint normalisationFactor = _getVegaNormalisationFactorPrecise(timeToExpirySec);
        uint vegaPrecise = _vega(tAnnualised, spot, d1);
        return (vegaPrecise, vegaPrecise.multiplyDecimalRoundPrecise(normalisationFactor));
    }
    
    function _getVegaNormalisationFactorPrecise(uint timeToExpirySec) internal pure returns (uint) {
        timeToExpirySec = timeToExpirySec < VEGA_STANDARDISATION_MIN_DAYS ? VEGA_STANDARDISATION_MIN_DAYS : timeToExpirySec;
        uint daysToExpiry = timeToExpirySec / 1 days;
        uint thirty = 30 * PRECISE_UNIT;
        return _sqrtPrecise(thirty / daysToExpiry) / 100;
    }
    
    /////////////////////
    // Math Operations //
    /////////////////////
    
    /**
    * @dev Compute the absolute value of `val`.
    *
    * @param val The number to absolute value.
    */
    function _abs(int val) internal pure returns (uint) {
        return uint(val < 0 ? -val : val);
    }
    
    /// @notice Calculates the square root of x, rounding down (borrowed from https://github.com/paulrberg/prb-math)
    /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
    /// @param x The uint256 number for which to calculate the square root.
    /// @return result The result as an uint256.
    function _sqrt(uint x) internal pure returns (uint result) {
        if (x == 0) {
            return 0;
        }
        
        // Calculate the square root of the perfect square of a power of two that is the closest to x.
        uint xAux = uint(x);
        result = 1;
        if (xAux >= 0x100000000000000000000000000000000) {
            xAux >>= 128;
            result <<= 64;
        }
        if (xAux >= 0x10000000000000000) {
            xAux >>= 64;
            result <<= 32;
        }
        if (xAux >= 0x100000000) {
            xAux >>= 32;
            result <<= 16;
        }
        if (xAux >= 0x10000) {
            xAux >>= 16;
            result <<= 8;
        }
        if (xAux >= 0x100) {
            xAux >>= 8;
            result <<= 4;
        }
        if (xAux >= 0x10) {
            xAux >>= 4;
            result <<= 2;
        }
        if (xAux >= 0x8) {
            result <<= 1;
        }
        
        // The operations can never overflow because the result is max 2^127 when it enters this block.
        unchecked {
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1; // Seven iterations should be enough
            uint roundedDownResult = x / result;
            return result >= roundedDownResult ? roundedDownResult : result;
        }
    }
    
    /**
    * @dev Returns the square root of the value using Newton's method.
    */
    function _sqrtPrecise(uint x) internal pure returns (uint) {
        // Add in an extra unit factor for the square root to gobble;
        // otherwise, sqrt(x * UNIT) = sqrt(x) * sqrt(UNIT)
        return _sqrt(x * PRECISE_UNIT);
    }
    
    /**
    * @dev The standard normal distribution of the value.
    */
    function _stdNormal(int x) internal pure returns (uint) {
        return
        HigherMath.expPrecise(int(-x.multiplyDecimalRoundPrecise(x / 2))).divideDecimalRoundPrecise(SQRT_TWOPI);
    }
    
    /**
    * @dev The standard normal cumulative distribution of the value.
    * borrowed from a C++ implementation https://stackoverflow.com/a/23119456
    */
    function _stdNormalCDF(int x) public pure returns (uint) {
        uint z = _abs(x);
        int c;
        
        if (z <= 37 * PRECISE_UNIT) {
            uint e = HigherMath.expPrecise(-int(z.multiplyDecimalRoundPrecise(z / 2)));
            if (z < SPLIT) {
                c = int(
                    (_stdNormalCDFNumerator(z).divideDecimalRoundPrecise(_stdNormalCDFDenom(z)).multiplyDecimalRoundPrecise(e))
                );
            } else {
                uint f = (z +
                    PRECISE_UNIT.divideDecimalRoundPrecise(
                        z +
                        (2 * PRECISE_UNIT).divideDecimalRoundPrecise(
                            z +
                            (3 * PRECISE_UNIT).divideDecimalRoundPrecise(
                                z + (4 * PRECISE_UNIT).divideDecimalRoundPrecise(z + ((PRECISE_UNIT * 13) / 20))
                            )
                        )
                    ));
                    c = int(e.divideDecimalRoundPrecise(f.multiplyDecimalRoundPrecise(SQRT_TWOPI)));
                }
            }
        return uint((x <= 0 ? c : (int(PRECISE_UNIT) - c)));
    }
        
    /**
    * @dev Helper for _stdNormalCDF
    */
    function _stdNormalCDFNumerator(uint z) internal pure returns (uint) {
        uint numeratorInner = ((((((N6 * z) / PRECISE_UNIT + N5) * z) / PRECISE_UNIT + N4) * z) / PRECISE_UNIT + N3);
        return (((((numeratorInner * z) / PRECISE_UNIT + N2) * z) / PRECISE_UNIT + N1) * z) / PRECISE_UNIT + N0;
    }
    
    /**
    * @dev Helper for _stdNormalCDF
    */
    function _stdNormalCDFDenom(uint z) internal pure returns (uint) {
        uint denominatorInner = ((((((M7 * z) / PRECISE_UNIT + M6) * z) / PRECISE_UNIT + M5) * z) / PRECISE_UNIT + M4);
        return
        (((((((denominatorInner * z) / PRECISE_UNIT + M3) * z) / PRECISE_UNIT + M2) * z) / PRECISE_UNIT + M1) * z) /
        PRECISE_UNIT +
        M0;
    }
    
    /**
    * @dev Converts an integer number of seconds to a fractional number of years.
    */
    function _annualise(uint secs) internal pure returns (uint yearFraction) {
        return secs.divideDecimalRoundPrecise(SECONDS_PER_YEAR);
    }
}


// File contracts/core/GammaVault.sol

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;













contract GammaVault is IPolynomialVault, Auth, ReentrancyGuard, Pausable {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    /// -----------------------------------------------------------------------
    /// Data Structures
    /// -----------------------------------------------------------------------

    struct PositionData {
        uint256 strikeId;
        uint256 positionId;
        uint256 optionAmount;
        uint256 premiumPaid;
        uint256 shortAmount;
        uint256 totalMargin;
    }

    struct QueuedDeposit {
        uint256 id;
        address user;
        uint256 depositedAmount;
        uint256 mintedTokens;
        uint256 requestedTime;
    }

    struct QueuedWithdraw {
        uint256 id;
        address user;
        uint256 withdrawnTokens;
        uint256 returnedAmount;
        uint256 requestedTime;
    }

    /// -----------------------------------------------------------------------
    /// Constants
    /// -----------------------------------------------------------------------

    IOptionMarket.OptionType private constant OPTION_TYPE = IOptionMarket.OptionType.LONG_CALL;

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    /// @notice Human Readable Name of the Vault
    bytes32 public immutable name;

    /// @notice Synthetix Synth key of the underlying token
    bytes32 public immutable UNDERLYING_SYNTH_KEY;

    /// @notice sUSD
    ERC20 public immutable SUSD;

    /// @notice Corresponding vault token
    IPolynomialVaultToken public immutable VAULT_TOKEN;

    /// @notice Lyra Option Market
    IOptionMarket public immutable OPTION_MARKET;

    /// @notice Synthetix Futures Market
    IFuturesMarket public immutable FUTURES_MARKET;

    /// @notice Lyra Option Market Wrapper
    IOptionMarketWrapperWithSwaps public immutable OPTION_MARKET_WRAPPER;

    /// @notice Lyra Option Token
    IOptionToken public immutable OPTION_TOKEN;

    /// @notice Lyra Options Greek Cache
    IOptionGreekCache public immutable GREEKS;

    /// @notice Synthetix Exchange Rates
    IExchangeRates public immutable RATES;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /// @notice Minimum deposit amount
    uint256 public minDepositAmount;

    /// @notice Maximum deposit amount
    uint256 public maxDepositAmount;

    /// @notice Minimum deposit delay
    uint256 public minDepositDelay;

    /// @notice Minimum withdrawal delay
    uint256 public minWithdrawDelay;

    /// @notice GWAV Length
    uint256 public gwavLength;

    /// @notice Leverage used for Futures positions
    uint256 public leverage;

    /// @notice Fee Receipient
    address public feeReceipient;

    /// @notice Performance Fee 
    uint256 public performanceFee;

    /// @notice Withdrawal Fee
    uint256 public withdrawalFee;

    /// @notice Synthetix Tracking Code
    bytes32 public synthetixTrackingCode;

    /// @notice Total queued deposits
    uint256 public totalQueuedDeposits;

    /// @notice Total queued withdrawals
    uint256 public totalQueuedWithdrawals;

    /// @notice Next deposit queue item that needs to be processed
    uint256 public queuedDepositHead = 1;

    /// @notice Next deposit queue ID that needs to be processed
    uint256 public nextQueuedDepositId = 1;

    /// @notice Next withdrawal queue item that needs to be processed
    uint256 public queuedWithdrawalHead = 1;

    /// @notice Next withdrawal queue ID that needs to be processed
    uint256 public nextQueuedWithdrawalId = 1;

    /// @notice Total funds
    uint256 public totalFunds;

    /// @notice Used funds
    uint256 public usedFunds;

    /// @notice Boolean flag to stop from opening new position if closing has started
    bool public hasClosingStarted;

    /// @notice Position Data
    PositionData public positionData;

    /// @notice Allow List
    IAllowList public allowList;

    /// @notice Deposit Queue
    mapping (uint256 => QueuedDeposit) public depositQueue;

    /// @notice Withdrawal Queue
    mapping (uint256 => QueuedWithdraw) public withdrawalQueue;

    constructor(
        ERC20 _susd,
        IPolynomialVaultToken _vaultToken,
        IOptionMarket _optionMarket,
        IFuturesMarket _futuresMarket,
        IOptionMarketWrapperWithSwaps _optionMarketWrapper,
        IOptionToken _optionToken,
        IOptionGreekCache _greeks,
        IExchangeRates _rates,
        bytes32 _underlyingKey,
        bytes32 _name
    ) Auth(msg.sender, Authority(address(0x0))) {
        VAULT_TOKEN = _vaultToken;
        OPTION_MARKET = _optionMarket;
        FUTURES_MARKET = _futuresMarket;
        OPTION_MARKET_WRAPPER = _optionMarketWrapper;
        OPTION_TOKEN = _optionToken;
        RATES = _rates;
        GREEKS = _greeks;
        UNDERLYING_SYNTH_KEY = _underlyingKey;
        name = _name;
        SUSD = _susd;
    }

    /// -----------------------------------------------------------------------
    /// User actions
    /// -----------------------------------------------------------------------

    /// @notice Initiate deposit to the vault
    /// @notice If there are no active positions, deposits are processed immediately
    /// @notice Otherwise it is added to the deposit queue
    /// @param user Address of the user to receive the VAULT_TOKENs upon processing
    /// @param amount Amount of sUSD being depositted
    function initiateDeposit(address user, uint256 amount) external nonReentrant whenDepositsNotPaused {
        if (user == address(0x0)) {
            revert ExpectedNonZero();
        }

        if (amount < minDepositAmount) {
            revert MinimumDepositRequired(minDepositAmount, amount);
        }

        // Instant processing
        if (positionData.optionAmount == 0) {
            uint256 tokenPrice = getTokenPrice();
            uint256 tokensToMint = amount.divWadDown(tokenPrice);
            VAULT_TOKEN.mint(user, tokensToMint);
            totalFunds += amount;
            emit ProcessDeposit(0, user, amount, tokensToMint, block.timestamp);
        } else {
            // Queueing the deposit request 
            QueuedDeposit storage newDeposit = depositQueue[nextQueuedDepositId];

            newDeposit.id = nextQueuedDepositId++;
            newDeposit.user = user;
            newDeposit.depositedAmount = amount;
            newDeposit.requestedTime = block.timestamp;

            totalQueuedDeposits += amount;
            emit InitiateDeposit(newDeposit.id, msg.sender, user, amount);
        }

        SUSD.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Initiate withdrawal from the vault
    /// @notice If there are no active positions, withdrawals are processed instantly
    /// @notice Otherwise the request is added to the withdrawal queue
    /// @param user Address of the user to receive the sUSD upon processing
    /// @param tokens Amounts of VAULT_TOKENs being requested to burn / withdraw
    function initiateWithdrawal(address user, uint256 tokens) external nonReentrant {
        if (user == address(0x0)) {
            revert ExpectedNonZero();
        }

        // Instant processing
        if (positionData.optionAmount == 0) {
            uint256 tokenPrice = getTokenPrice();
            uint256 susdToReturn = tokens.mulWadDown(tokenPrice);
            SUSD.safeTransfer(user, susdToReturn);
            totalFunds -= susdToReturn;
            emit ProcessWithdrawal(0, user, tokens, susdToReturn, block.timestamp);
        } else {
            // Queueing the withdrawal request
            QueuedWithdraw storage newWithdraw = withdrawalQueue[nextQueuedWithdrawalId];

            newWithdraw.id = nextQueuedWithdrawalId++;
            newWithdraw.user = user;
            newWithdraw.withdrawnTokens = tokens;
            newWithdraw.requestedTime = block.timestamp;

            totalQueuedWithdrawals += tokens;
            emit InitiateWithdrawal(newWithdraw.id, msg.sender, user, tokens);
        }

        VAULT_TOKEN.burn(msg.sender, tokens);
    }

    /// @notice Process queued deposit requests
    /// @param idCount Number of deposit queue items to process
    function processDepositQueue(uint256 idCount) external nonReentrant {
        uint256 tokenPrice = getTokenPrice();

        for (uint256 i = 0; i < idCount; i++) {
            QueuedDeposit storage current = depositQueue[queuedDepositHead];

            if (current.requestedTime == 0 || block.timestamp < current.requestedTime + minDepositDelay) {
                return;
            }

            uint256 tokensToMint = current.depositedAmount.divWadDown(tokenPrice);

            current.mintedTokens = tokensToMint;
            totalQueuedDeposits -= current.depositedAmount;
            totalFunds += current.depositedAmount;
            VAULT_TOKEN.mint(current.user, tokensToMint);

            emit ProcessDeposit(current.id, current.user, current.depositedAmount, tokensToMint, current.requestedTime);

            current.depositedAmount = 0;
            queuedDepositHead++;
        }
    }

    /// @notice Process queued withdrawal requests
    /// @param idCount Number of withdrawal queue items to process
    function processWithdrawalQueue(uint256 idCount) external nonReentrant {
        for (uint256 i = 0; i < idCount; i++) {
            uint256 tokenPrice = getTokenPrice();

            QueuedWithdraw storage current = withdrawalQueue[queuedWithdrawalHead];

            if (current.requestedTime == 0 || block.timestamp < current.requestedTime + minWithdrawDelay) {
                return;
            }

            uint256 availableFunds = totalFunds - usedFunds;

            if (availableFunds == 0) {
                return;
            }

            uint256 susdToReturn = current.withdrawnTokens.mulWadDown(tokenPrice);

            // Partial withdrawals if not enough available funds in the vault
            // Queue head is not increased
            if (susdToReturn > availableFunds) {
                current.returnedAmount = availableFunds;
                uint256 tokensBurned = availableFunds.divWadUp(tokenPrice);

                totalQueuedWithdrawals -= tokensBurned;
                current.withdrawnTokens -= tokensBurned;

                totalFunds -= availableFunds;

                if (withdrawalFee > 0) {
                    uint256 withdrawFees = availableFunds.mulWadDown(withdrawalFee);
                    SUSD.safeTransfer(feeReceipient, withdrawFees);
                    availableFunds -= withdrawFees;
                }

                SUSD.safeTransfer(current.user, availableFunds);

                emit ProcessWithdrawalPartially(
                    current.id, current.user, tokensBurned, availableFunds, current.requestedTime
                );
                return;
            } else {
                current.returnedAmount = susdToReturn;
                totalQueuedWithdrawals -= current.withdrawnTokens;
                current.withdrawnTokens = 0;

                totalFunds -= susdToReturn;

                if (withdrawalFee > 0) {
                    uint256 withdrawFees = susdToReturn.mulWadDown(withdrawalFee);
                    SUSD.safeTransfer(feeReceipient, withdrawFees);
                    susdToReturn -= withdrawFees;
                }

                SUSD.safeTransfer(current.user, susdToReturn);

                emit ProcessWithdrawal(
                    current.id, current.user, current.withdrawnTokens, susdToReturn, current.requestedTime
                );
            }

            queuedWithdrawalHead++;
        }
    }

    /// -----------------------------------------------------------------------    
    /// View methods
    /// -----------------------------------------------------------------------

    /// @notice Get VAULT_TOKEN price
    /// @notice Calculated using the Black-Scholes and margin value of the positions
    function getTokenPrice() public view returns (uint256) {
        if (totalFunds == 0) {
            return 1e18;
        }

        uint256 totalSupply = getTotalSupply();
        if (positionData.optionAmount == 0) {
            return totalFunds.divWadDown(totalSupply);
        }

        (uint256 callPremium, ) = getPremiumForStrike(positionData.strikeId);
        (uint256 totalMargin, ) = FUTURES_MARKET.remainingMargin(address(this));
        uint256 usedValue = callPremium.mulWadDown(positionData.optionAmount) + totalMargin;

        return (totalFunds + usedValue - usedFunds).divWadDown(totalSupply);
    }

    /// @notice Returns the total supply of the VAULT_TOKEN
    function getTotalSupply() public view returns (uint256) {
        return VAULT_TOKEN.totalSupply() + totalQueuedWithdrawals;
    }

    /// -----------------------------------------------------------------------    
    /// Internal View methods
    /// -----------------------------------------------------------------------

    /// @notice Returns the Black-Scholes premium of call and put options
    /// @param _strikeId Lyra Strike ID
    function getPremiumForStrike(uint256 _strikeId) internal view returns (uint256 callPremium, uint256 putPremium) {
        (
            IOptionMarket.Strike memory strike,
            IOptionMarket.OptionBoard memory board
        ) = OPTION_MARKET.getStrikeAndBoard(_strikeId);
        
        (uint256 spotPrice, bool isInvalid) = RATES.rateAndInvalid(UNDERLYING_SYNTH_KEY);

        if (spotPrice == 0 || isInvalid) {
            revert();
        }

        if (block.timestamp > board.expiry) {
            (
                uint256 strikePrice,
                uint256 priceAtExpiry,
            ) = OPTION_MARKET.getSettlementParameters(_strikeId);

            if (priceAtExpiry == 0) {
                revert ExpectedNonZero();
            }

            callPremium = priceAtExpiry > strikePrice ? priceAtExpiry - strikePrice : 0;
        } else {
            uint256 boardIv = GREEKS.getIvGWAV(board.id, gwavLength);
            uint256 strikeSkew = GREEKS.getSkewGWAV(_strikeId, gwavLength);
            BlackScholesLib.BlackScholesInputs memory bsInput = BlackScholesLib.BlackScholesInputs({
                timeToExpirySec: board.expiry - block.timestamp,
                volatilityDecimal: boardIv.mulWadDown(strikeSkew),
                spotDecimal: spotPrice,
                strikePriceDecimal: strike.strikePrice,
                rateDecimal: GREEKS.getGreekCacheParams().rateAndCarry
            });
    
            (callPremium, putPremium) = BlackScholesLib.optionPrices(bsInput);
        }
    }

    /// @notice Returns the delta of the call option given its strike ID
    /// @param _strikeId Lyra Strike ID
    function getCallDelta(uint256 _strikeId) internal view returns (int256 callDelta) {
        (
            IOptionMarket.Strike memory strike,
            IOptionMarket.OptionBoard memory board
        ) = OPTION_MARKET.getStrikeAndBoard(_strikeId);

        (uint256 spotPrice, bool isInvalid) = RATES.rateAndInvalid(UNDERLYING_SYNTH_KEY);

        if (spotPrice == 0 || isInvalid) {
            revert InvalidPrice(spotPrice, isInvalid);
        }

        BlackScholesLib.BlackScholesInputs memory bsInput = BlackScholesLib.BlackScholesInputs({
            timeToExpirySec: board.expiry - block.timestamp,
            volatilityDecimal: board.iv.mulWadDown(strike.skew),
            spotDecimal: spotPrice,
            strikePriceDecimal: strike.strikePrice,
            rateDecimal: GREEKS.getGreekCacheParams().rateAndCarry
        });

        (callDelta, ) = BlackScholesLib.delta(bsInput);
    }

    /// -----------------------------------------------------------------------
    /// Keeper actions
    /// -----------------------------------------------------------------------

    /// @notice Open a delta neutral position of a call option (of delta 0.4-0.6) and short futures
    /// @param strikeId Lyra strike ID of the call option
    /// @param amount Amount of options to buy
    /// @param maxPremiumAmount Maximum amount paid for purchasing the options
    function openPosition(uint256 strikeId, uint256 amount, uint256 maxPremiumAmount) external requiresAuth nonReentrant whenNotPaused {
        _openPosition(strikeId, amount, maxPremiumAmount);
    }

    /// @notice Close position (futures positions are closed propotional to total options size)
    /// @param amount Amount of options to close
    /// @param minPremium Minimum premium amount collected from each option closed
    function closePosition(uint256 amount, uint256 minPremium) external requiresAuth nonReentrant whenNotPaused {
        _closePosition(amount, minPremium);
    }

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    /// @notice Pause contracts
    function pause() external requiresAuth {
        _pause();
    }

    /// @notice Pause deposits
    function pauseDeposits() external requiresAuth {
        _pauseDeposits();
    }

    /// @notice Unpause contracts
    function unpause() external requiresAuth {
        _unpause();
    }

    /// @notice Unpause deposits
    function unpauseDeposits() external requiresAuth {
        _unpauseDeposits();
    }

    /// @notice Set fee receipient address
    /// @param _feeReceipient Address of the new fee receipient
    function setFeeReceipient(address _feeReceipient) external requiresAuth {
        if (_feeReceipient == address(0x0)) {
            revert ExpectedNonZero();
        }

        emit UpdateFeeReceipient(feeReceipient, _feeReceipient);

        feeReceipient = _feeReceipient;
    }

    /// @notice Set Fees
    /// @param _performanceFee New Performance Fee
    /// @param _withdrawalFee New Withdrawal Fee
    function setFees(uint256 _performanceFee, uint256 _withdrawalFee) external requiresAuth {
        if (_performanceFee > 1e17 || _withdrawalFee > 1e16) {
            revert FeesTooHigh(performanceFee, withdrawalFee, _performanceFee, _withdrawalFee);
        }

        emit UpdateFees(
            performanceFee, withdrawalFee, _performanceFee, _withdrawalFee
        );

        performanceFee = _performanceFee;
        withdrawalFee = _withdrawalFee;
    }

    /// @notice Set Synthetix Volume Program Tracking Code
    /// @param _code New tracking code
    function setSynthetixTracking(bytes32 _code) external requiresAuth {
        emit UpdateSynthetixTrackingCode(synthetixTrackingCode, _code);
        synthetixTrackingCode = _code;
    }

    /// @notice Set Minimum deposit amount
    /// @param _minAmt Minimum deposit amount
    function setMinDepositAmount(uint256 _minAmt) external requiresAuth {
        emit UpdateMinDeposit(minDepositAmount, _minAmt);
        minDepositAmount = _minAmt;
    }

    /// @notice Set Maximum deposit amount
    /// @param _maxAmt Maximum deposit amount
    function setMaxDepositAmount(uint256 _maxAmt) external requiresAuth {
        emit UpdateMaxDeposit(maxDepositAmount, _maxAmt);
        maxDepositAmount = _maxAmt;
    }

    /// @notice Set Deposit and Withdrawal delays
    /// @param _depositDelay New Deposit Delay
    /// @param _withdrawDelay New Withdrawal Delay
    function setDelays(uint256 _depositDelay, uint256 _withdrawDelay) external requiresAuth {
        emit UpdateDelays(minDepositDelay, _depositDelay, minWithdrawDelay, _withdrawDelay);
        minDepositDelay = _depositDelay;
        minWithdrawDelay = _withdrawDelay;
    }

    /// @notice Set GWAV Length
    /// @param length Length in seconds
    function setGWAVLength(uint256 length) external requiresAuth {
        emit UpdateGWAVLength(gwavLength, length);
        gwavLength = length;
    }

    /// @notice Set leverage used for futures positions
    /// @param _lev Leverage in 18 decimals
    function setLeverage(uint256 _lev) external requiresAuth {
        if (_lev > 5e18 || _lev < 1e18) {
            revert InvalidLeverage(leverage, _lev);
        }
        emit UpdateLeverage(leverage, _lev);
        leverage = _lev;
    }

    function setAllowList(IAllowList _list) external requiresAuth {
        emit UpdateAllowList(address(allowList), address(_list));
        allowList = _list;
    }

    /// @notice Save ERC20 token from the vault (not SUSD or UNDERLYING)
    /// @param token Address of the token
    /// @param receiver Address of the receiver
    /// @param amt Amount to save
    function saveToken(address token, address receiver, uint256 amt) external requiresAuth {
        require(token != address(SUSD));
        ERC20(token).transfer(receiver, amt);
    }

    /// -----------------------------------------------------------------------
    /// Internal Methods
    /// -----------------------------------------------------------------------

    function _openPosition(uint256 _strikeId, uint256 _amt, uint256 _maxPremium) internal {
        if ((positionData.positionId != 0 && positionData.strikeId != _strikeId) || hasClosingStarted) {
            revert InvalidRequest();
        }

        int256 callDelta = getCallDelta(_strikeId);

        if (callDelta < 4e17 || callDelta > 6e17) {
            revert InvalidOption(_strikeId, uint256(callDelta));
        }

        (uint256 spotPrice, bool isInvalid) = FUTURES_MARKET.assetPrice();

        if (spotPrice == 0 || isInvalid) {
            revert InvalidPrice(spotPrice, isInvalid);
        }

        uint256 _shortPosition = _amt.mulWadDown(uint256(callDelta));
        uint256 marginRequired = _shortPosition.mulDivDown(spotPrice, leverage);
        int256 shortPosition = -int256(_shortPosition);

        if (usedFunds + _maxPremium + marginRequired > totalFunds) {
            revert InsufficientFunds(totalFunds, usedFunds, _maxPremium + marginRequired);
        }

        ERC20(SUSD).safeApprove(address(OPTION_MARKET_WRAPPER), _maxPremium);

        IOptionMarketWrapperWithSwaps.OptionPositionParams memory params;

        params.optionMarket = OPTION_MARKET;
        params.strikeId = _strikeId;
        params.positionId = positionData.positionId;
        params.iterations = 4;
        // params.setCollateralTo = 0;
        // params.currentCollateral = 0;
        params.optionType = OPTION_TYPE;
        params.amount = _amt;
        // params.minCost = 0;
        params.maxCost = _maxPremium;
        params.inputAmount = _maxPremium;
        params.inputAsset = SUSD;

        IOptionMarketWrapperWithSwaps.ReturnDetails memory returnDetails = OPTION_MARKET_WRAPPER.openPosition(params);

        FUTURES_MARKET.transferMargin(int256(marginRequired));
        FUTURES_MARKET.modifyPositionWithTracking(shortPosition, synthetixTrackingCode);

        if (positionData.positionId == 0) {
            positionData.positionId = returnDetails.positionId;
            positionData.strikeId = _strikeId;
        }

        positionData.optionAmount += _amt;
        positionData.premiumPaid += returnDetails.totalCost;
        positionData.shortAmount += _shortPosition;
        positionData.totalMargin += marginRequired;

        usedFunds += marginRequired + returnDetails.totalCost;

        emit OpenPosition(
            _strikeId,
            positionData.positionId,
            _amt,
            returnDetails.totalCost,
            uint256(callDelta),
            _shortPosition,
            marginRequired
        );
    }

    function _closePosition(uint256 _amt, uint256 _minPremium) internal {
        if (positionData.positionId == 0) {
            revert ExpectedNonZero();
        }

        (uint256 spotPrice, bool isInvalid) = FUTURES_MARKET.assetPrice();

        if (spotPrice == 0 || isInvalid) {
            revert InvalidPrice(spotPrice, isInvalid);
        }

        if (!hasClosingStarted) {
            hasClosingStarted = true;
        }

        if (OPTION_TOKEN.getApproved(positionData.positionId) != address(OPTION_MARKET_WRAPPER)) {
            OPTION_TOKEN.approve(address(OPTION_MARKET_WRAPPER), positionData.positionId);
        }

        if (_amt >= positionData.optionAmount) {
            hasClosingStarted = false;

            IOptionMarketWrapperWithSwaps.OptionPositionParams memory params;

            params.optionMarket = OPTION_MARKET;
            params.strikeId = positionData.strikeId;
            params.positionId = positionData.positionId;
            params.iterations = 4;
            // params.setCollateralTo = 0;
            // params.currentCollateral = 0;
            params.optionType = OPTION_TYPE;
            params.amount = positionData.optionAmount;
            params.minCost = _minPremium.mulWadDown(params.amount);
            params.maxCost = type(uint256).max;
            // params.inputAmount = 0;
            params.inputAsset = SUSD;

            IOptionMarketWrapperWithSwaps.ReturnDetails memory returnDetails = OPTION_MARKET_WRAPPER.closePosition(params);

            FUTURES_MARKET.modifyPositionWithTracking(int256(positionData.shortAmount), synthetixTrackingCode);

            // No need to check for invalid since already done above
            (uint256 finalMargin, ) = FUTURES_MARKET.remainingMargin(address(this));

            FUTURES_MARKET.withdrawAllMargin();

            uint256 totalReceived = finalMargin + returnDetails.totalCost;

            if (totalReceived > usedFunds) {
                uint256 profit = totalReceived - usedFunds;
                uint256 perfFees = profit.mulWadDown(performanceFee);
                ERC20(SUSD).safeTransfer(feeReceipient, perfFees);
                totalFunds += (profit - perfFees);
            } else {
                totalFunds -= (usedFunds - totalReceived);
            }

            emit ClosePosition(
                positionData.strikeId,
                positionData.positionId,
                positionData.optionAmount,
                returnDetails.totalCost,
                positionData.shortAmount,
                finalMargin
            );

            usedFunds = 0;
            positionData.optionAmount = 0;
            positionData.positionId = 0;
            positionData.strikeId = 0;
            positionData.premiumPaid = 0;
            positionData.shortAmount = 0;
            positionData.totalMargin = 0;
        } else {
            IOptionMarketWrapperWithSwaps.OptionPositionParams memory params;

            params.optionMarket = OPTION_MARKET;
            params.strikeId = positionData.strikeId;
            params.positionId = positionData.positionId;
            params.iterations = 4;
            // params.setCollateralTo = 0;
            // params.currentCollateral = 0;
            params.optionType = OPTION_TYPE;
            params.amount = _amt;
            params.minCost = _minPremium.mulWadDown(_amt);
            params.maxCost = type(uint256).max;
            // params.inputAmount = 0;
            params.inputAsset = SUSD;

            IOptionMarketWrapperWithSwaps.ReturnDetails memory returnDetails = OPTION_MARKET_WRAPPER.closePosition(params);

            uint256 shortPositionToClose = _amt.mulDivDown(positionData.shortAmount, positionData.optionAmount);

            FUTURES_MARKET.modifyPositionWithTracking(int256(shortPositionToClose), synthetixTrackingCode);

            emit ClosePosition(
                positionData.strikeId,
                positionData.positionId,
                _amt,
                returnDetails.totalCost,
                shortPositionToClose,
                0
            );

            usedFunds -= returnDetails.totalCost;

            positionData.optionAmount -= _amt;
            positionData.shortAmount -= shortPositionToClose;
        }
    }

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    /// General
    error InsufficientFunds(uint256 totalFunds, uint256 usedFunds, uint256 requiredFunds);
    error ExpectedNonZero();

    /// Trading errors
    error InvalidPrice(uint256 spotPrice, bool isInvalid);
    error InvalidOption(uint256 strikeId, uint256 callDelta);
    error InvalidRequest();

    /// Deposit and Withdrawals
    error MinimumDepositRequired(uint256 minDeposit, uint256 requestedAmount);

    /// Owner actions
    error InvalidLeverage(uint256 currentLeverage, uint256 requestedLeverage);
    error FeesTooHigh(uint256 currentPerf, uint256 currentWithdraw, uint256 newPerf, uint256 newWithdraw);

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @notice Initiate Deposit Event
    /// @param depositId Deposit ID
    /// @param depositor Address of the fund depositor (msg.sender)
    /// @param user Address of the user who'll be getting the VAULT_TOKENs
    /// @param amount Amount depositted (in UNDERLYING)
    event InitiateDeposit(
        uint256 depositId,
        address depositor,
        address user,
        uint256 amount
    );

    /// @notice Process Deposit Event
    /// @param depositId Deposit ID
    /// @param user Address of the user who'll be getting the VAULT_TOKENs
    /// @param amount Amount depositted (in UNDERLYING)
    /// @param tokens Amount of VAULT_TOKENs minted
    /// @param requestedTime Timestamp of the initiateDeposit call
    event ProcessDeposit(
        uint256 depositId,
        address user,
        uint256 amount,
        uint256 tokens,
        uint256 requestedTime
    );

    /// @notice Initiate Withdrawal Event
    /// @param withdrawalId Withdrawal ID
    /// @param withdrawer Address of the user who requested withdraw (msg.sender)
    /// @param user Address of the user who'll be getting UNDERLYING tokens upon processing
    /// @param tokens Amount of VAULT_TOKENs to burn / withdraw
    event InitiateWithdrawal(
        uint256 withdrawalId,
        address withdrawer,
        address user,
        uint256 tokens
    );

    /// @notice Process Withdrawal Event
    /// @param withdrawalId Withdrawal ID
    /// @param user Address of the user who's getting the funds
    /// @param tokens Amount of VAULT_TOKENs burned
    /// @param amount Amount of UNDERLYING returned
    /// @param requestedTime Timestamp of the initiateWithdraw call
    event ProcessWithdrawal(
        uint256 withdrawalId,
        address user,
        uint256 tokens,
        uint256 amount,
        uint256 requestedTime
    );

    /// @notice Process Withdrawal Partially Event
    /// @param withdrawalId Withdrawal ID
    /// @param user Address of the user who's getting the funds
    /// @param tokens Amount of VAULT_TOKENs burned
    /// @param amount Amount of UNDERLYING returned
    /// @param requestedTime Timestamp of the initiateWithdraw call
    event ProcessWithdrawalPartially(
        uint256 withdrawalId,
        address user,
        uint256 tokens,
        uint256 amount,
        uint256 requestedTime
    );

    /// @notice Update Fee Receipient Event
    /// @param oldFeeReceipient Address of the old fee receipient
    /// @param newFeeReceipient Address of the new fee receipient
    event UpdateFeeReceipient(address oldFeeReceipient, address newFeeReceipient);

    /// @notice Update Fees Event
    /// @param oldPerf Old Perfomance Fee
    /// @param oldWithdraw Old Withdrawal Fee
    /// @param newPerf New Performance Fee
    /// @param newWithdraw New Withdrawal Fee
    event UpdateFees(uint256 oldPerf, uint256 oldWithdraw, uint256 newPerf, uint256 newWithdraw);

    /// @notice Update Synthetix Tracking Code Event
    /// @param oldCode Existing code
    /// @param newCode New code
    event UpdateSynthetixTrackingCode(bytes32 oldCode, bytes32 newCode);

    /// @notice Update Minimum Deposit Amount Event
    /// @param oldMinimum Previous minimum deposit amount
    /// @param newMinimum New minimum deposit amount
    event UpdateMinDeposit(uint256 oldMinimum, uint256 newMinimum);

    /// @notice Update Maximum Deposit Amount Event
    /// @param oldMax Previous maximum deposit amount
    /// @param newMax New maximum deposit amount
    event UpdateMaxDeposit(uint256 oldMax, uint256 newMax);

    /// @notice Update Deposit and Withdraw delays Event
    /// @param oldDepositDelay Old Deposit Delay
    /// @param newDepositDelay New Deposit Delay
    /// @param oldWithdrawDelay Old Withdraw Delay
    /// @param newWithdrawDelay New Withdraw Delay
    event UpdateDelays(
        uint256 oldDepositDelay,
        uint256 newDepositDelay,
        uint256 oldWithdrawDelay,
        uint256 newWithdrawDelay
    );

    /// @notice Update GWAV Length
    /// @param oldLength Old Length
    /// @param newLength New Length
    event UpdateGWAVLength(
        uint256 oldLength,
        uint256 newLength
    );

    /// @notice Update Leverage Event
    /// @param oldLeverage Old leverage
    /// @param newLeverage New leverage
    event UpdateLeverage(
        uint256 oldLeverage,
        uint256 newLeverage
    );

    /// @notice Update AllowList Event
    /// @param oldList Old AllowList
    /// @param newList New AllowList
    event UpdateAllowList(
        address oldList,
        address newList
    );

    /// @notice Open Position Event
    /// @param strikeId Lyra Option Strike ID
    /// @param positionId Corresponding Position ID
    /// @param amount Amount of options purchased
    /// @param premiumPaid Total premium paid
    /// @param callDelta Delta of the option
    /// @param shortPosition Amount of UNDERLYING shorted
    /// @param marginUsed Margin used for opening the short position
    event OpenPosition(
        uint256 strikeId,
        uint256 positionId,
        uint256 amount,
        uint256 premiumPaid,
        uint256 callDelta,
        uint256 shortPosition,
        uint256 marginUsed
    );

    /// @notice Close Position Event
    /// @param strikeId Lyra Option Strike ID
    /// @param positionId Corresponding Position ID
    /// @param amount Amount of options closed
    /// @param premiumCollected Total premium collected
    /// @param shortPosition Amount of futures position closed
    /// @param marginWithdrawn Margin withdrawn
    event ClosePosition(
        uint256 strikeId,
        uint256 positionId,
        uint256 amount,
        uint256 premiumCollected,
        uint256 shortPosition,
        uint256 marginWithdrawn
    );
}