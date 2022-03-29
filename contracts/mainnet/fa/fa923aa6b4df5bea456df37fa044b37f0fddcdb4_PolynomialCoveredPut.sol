/**
 *Submitted for verification at optimistic.etherscan.io on 2022-03-29
*/

// Sources flattened with hardhat v2.8.3 https://hardhat.org

// File @rari-capital/solmate/src/auth/[email protected]


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

    modifier requiresAuth() {
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


pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*///////////////////////////////////////////////////////////////
                             METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*///////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*///////////////////////////////////////////////////////////////
                             EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*///////////////////////////////////////////////////////////////
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

    /*///////////////////////////////////////////////////////////////
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

    /*///////////////////////////////////////////////////////////////
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
            bytes32 digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
                )
            );

            address recoveredAddress = ecrecover(digest, v, r, s);

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

    /*///////////////////////////////////////////////////////////////
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


pragma solidity >=0.8.0;

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/FixedPointMathLib.sol)
library FixedPointMathLib {
    /*///////////////////////////////////////////////////////////////
                            COMMON BASE UNITS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant YAD = 1e8;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant RAY = 1e27;
    uint256 internal constant RAD = 1e45;

    /*///////////////////////////////////////////////////////////////
                         FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function fmul(
        uint256 x,
        uint256 y,
        uint256 baseUnit
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(x == 0 || (x * y) / x == y)
            if iszero(or(iszero(x), eq(div(z, x), y))) {
                revert(0, 0)
            }

            // If baseUnit is zero this will return zero instead of reverting.
            z := div(z, baseUnit)
        }
    }

    function fdiv(
        uint256 x,
        uint256 y,
        uint256 baseUnit
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * baseUnit in z for now.
            z := mul(x, baseUnit)

            // Equivalent to require(y != 0 && (x == 0 || (x * baseUnit) / x == baseUnit))
            if iszero(and(iszero(iszero(y)), or(iszero(x), eq(div(z, x), baseUnit)))) {
                revert(0, 0)
            }

            // We ensure y is not zero above, so there is never division by zero here.
            z := div(z, y)
        }
    }

    function fpow(
        uint256 x,
        uint256 n,
        uint256 baseUnit
    ) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := baseUnit
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store baseUnit in z for now.
                    z := baseUnit
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, baseUnit)

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
                    x := div(xxRound, baseUnit)

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
                        z := div(zxRound, baseUnit)
                    }
                }
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
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
                z := shl(64, z)
            }
            if iszero(lt(y, 0x10000000000000000)) {
                y := shr(64, y) // Like dividing by 2 ** 64.
                z := shl(32, z)
            }
            if iszero(lt(y, 0x100000000)) {
                y := shr(32, y) // Like dividing by 2 ** 32.
                z := shl(16, z)
            }
            if iszero(lt(y, 0x10000)) {
                y := shr(16, y) // Like dividing by 2 ** 16.
                z := shl(8, z)
            }
            if iszero(lt(y, 0x100)) {
                y := shr(8, y) // Like dividing by 2 ** 8.
                z := shl(4, z)
            }
            if iszero(lt(y, 0x10)) {
                y := shr(4, y) // Like dividing by 2 ** 4.
                z := shl(2, z)
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


pragma solidity >=0.8.0;

/// @notice Gas optimized reentrancy protection for smart contracts.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/ReentrancyGuard.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol)
abstract contract ReentrancyGuard {
    uint256 private reentrancyStatus = 1;

    modifier nonReentrant() {
        require(reentrancyStatus == 1, "REENTRANCY");

        reentrancyStatus = 2;

        _;

        reentrancyStatus = 1;
    }
}


// File @rari-capital/solmate/src/utils/[email protected]


pragma solidity >=0.8.0;

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @author Modified from Gnosis (https://github.com/gnosis/gp-v2-contracts/blob/main/src/contracts/libraries/GPv2SafeERC20.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
library SafeTransferLib {
    /*///////////////////////////////////////////////////////////////
                            ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferETH(address to, uint256 amount) internal {
        bool callStatus;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            callStatus := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(callStatus, "ETH_TRANSFER_FAILED");
    }

    /*///////////////////////////////////////////////////////////////
                           ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool callStatus;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata to memory piece by piece:
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000) // Begin with the function selector.
            mstore(add(freeMemoryPointer, 4), and(from, 0xffffffffffffffffffffffffffffffffffffffff)) // Mask and append the "from" argument.
            mstore(add(freeMemoryPointer, 36), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Mask and append the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Finally append the "amount" argument. No mask as it's a full 32 byte value.

            // Call the token and store if it succeeded or not.
            // We use 100 because the calldata length is 4 + 32 * 3.
            callStatus := call(gas(), token, 0, freeMemoryPointer, 100, 0, 0)
        }

        require(didLastOptionalReturnCallSucceed(callStatus), "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool callStatus;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata to memory piece by piece:
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000) // Begin with the function selector.
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Mask and append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Finally append the "amount" argument. No mask as it's a full 32 byte value.

            // Call the token and store if it succeeded or not.
            // We use 68 because the calldata length is 4 + 32 * 2.
            callStatus := call(gas(), token, 0, freeMemoryPointer, 68, 0, 0)
        }

        require(didLastOptionalReturnCallSucceed(callStatus), "TRANSFER_FAILED");
    }

    function safeApprove(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool callStatus;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata to memory piece by piece:
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000) // Begin with the function selector.
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Mask and append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Finally append the "amount" argument. No mask as it's a full 32 byte value.

            // Call the token and store if it succeeded or not.
            // We use 68 because the calldata length is 4 + 32 * 2.
            callStatus := call(gas(), token, 0, freeMemoryPointer, 68, 0, 0)
        }

        require(didLastOptionalReturnCallSucceed(callStatus), "APPROVE_FAILED");
    }

    /*///////////////////////////////////////////////////////////////
                         INTERNAL HELPER LOGIC
    //////////////////////////////////////////////////////////////*/

    function didLastOptionalReturnCallSucceed(bool callStatus) private pure returns (bool success) {
        assembly {
            // Get how many bytes the call returned.
            let returnDataSize := returndatasize()

            // If the call reverted:
            if iszero(callStatus) {
                // Copy the revert message into memory.
                returndatacopy(0, 0, returnDataSize)

                // Revert with the same message.
                revert(0, returnDataSize)
            }

            switch returnDataSize
            case 32 {
                // Copy the return data into memory.
                returndatacopy(0, 0, returnDataSize)

                // Set success to whether it returned true.
                success := iszero(iszero(mload(0)))
            }
            case 0 {
                // There was no return data.
                success := 1
            }
            default {
                // It returned some malformed input.
                success := 0
            }
        }
    }
}


// File contracts/interfaces/IPolynomialCoveredPut.sol

pragma solidity 0.8.9;

interface IPolynomialCoveredPut {

    struct UserInfo {
        uint256 depositRound;
        uint256 pendingDeposit;
        uint256 withdrawRound;
        uint256 withdrawnShares;
        uint256 totalShares;
    }

    function deposit(uint256 _amt) external;

    function deposit(address _user, uint256 _amt) external;

    function requestWithdraw(uint256 _shares) external;

    function completeWithdraw() external;

    function cancelWithdraw(uint256 _shares) external;
}


// File contracts/interfaces/lyra/ILyraDistributor.sol

pragma solidity 0.8.9;

interface ILyraDistributor {
    function claim() external;
}


// File contracts/interfaces/lyra/ICollateralShort.sol


pragma solidity 0.8.9;

interface ICollateralShort {
    struct Loan {
        // ID for the loan
        uint id;
        //  Account that created the loan
        address account;
        //  Amount of collateral deposited
        uint collateral;
        // The synth that was borrowed
        bytes32 currency;
        //  Amount of synths borrowed
        uint amount;
        // Indicates if the position was short sold
        bool short;
        // interest amounts accrued
        uint accruedInterest;
        // last interest index
        uint interestIndex;
        // time of last interaction.
        uint lastInteraction;
    }
  
    function loans(uint id) external returns (
        uint,
        address,
        uint,
        bytes32,
        uint,
        bool,
        uint,
        uint,
        uint
    );
  
    function minCratio() external returns (uint);
  
    function minCollateral() external returns (uint);
  
    function issueFeeRate() external returns (uint);
  
    function open(
        uint collateral,
        uint amount,
        bytes32 currency
    ) external returns (uint id);
  
    function repay(
        address borrower,
        uint id,
        uint amount
    ) external returns (uint short, uint collateral);
  
    function repayWithCollateral(uint id, uint repayAmount) external returns (uint short, uint collateral);
  
    function draw(uint id, uint amount) external returns (uint short, uint collateral);
  
    // Same as before
    function deposit(
        address borrower,
        uint id,
        uint amount
    ) external returns (uint short, uint collateral);
  
    // Same as before
    function withdraw(uint id, uint amount) external returns (uint short, uint collateral);
  
    // function to return the loan details in one call, without needing to know about the collateralstate
    function getShortAndCollateral(address account, uint id) external view returns (uint short, uint collateral);
}


// File contracts/interfaces/lyra/IExchangeRates.sol

pragma solidity 0.8.9;

// https://docs.synthetix.io/contracts/source/interfaces/iexchangerates
interface IExchangeRates {
    function rateAndInvalid(bytes32 currencyKey) external view returns (uint rate, bool isInvalid);
}


// File contracts/interfaces/lyra/IExchanger.sol

pragma solidity 0.8.9;

// https://docs.synthetix.io/contracts/source/interfaces/iexchanger
interface IExchanger {
    function feeRateForExchange(
        bytes32 sourceCurrencyKey,
        bytes32 destinationCurrencyKey
    ) external view returns (uint exchangeFeeRate);
}


// File contracts/interfaces/lyra/ISynthetix.sol


pragma solidity 0.8.9;

interface ISynthetix {
    function exchange(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    ) external returns (uint amountReceived);
  
    function exchangeOnBehalf(
        address exchangeForAddress,
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    ) external returns (uint amountReceived);
}


// File contracts/interfaces/lyra/ILyraGlobals.sol


pragma solidity 0.8.9;




interface ILyraGlobals {
    enum ExchangeType {BASE_QUOTE, QUOTE_BASE, ALL}

    /**
    * @dev Structs to help reduce the number of calls between other contracts and this one
    * Grouped in usage for a particular contract/use case
    */
    struct ExchangeGlobals {
        uint spotPrice;
        bytes32 quoteKey;
        bytes32 baseKey;
        ISynthetix synthetix;
        ICollateralShort short;
        uint quoteBaseFeeRate;
        uint baseQuoteFeeRate;
    }

    struct GreekCacheGlobals {
        int rateAndCarry;
        uint spotPrice;
    }

    struct PricingGlobals {
        uint optionPriceFeeCoefficient;
        uint spotPriceFeeCoefficient;
        uint vegaFeeCoefficient;
        uint vegaNormFactor;
        uint standardSize;
        uint skewAdjustmentFactor;
        int rateAndCarry;
        int minDelta;
        uint volatilityCutoff;
        uint spotPrice;
    }

    function synthetix() external view returns (ISynthetix);

    function exchanger() external view returns (IExchanger);

    function exchangeRates() external view returns (IExchangeRates);

    function collateralShort() external view returns (ICollateralShort);

    function isPaused() external view returns (bool);

    function tradingCutoff(address) external view returns (uint);

    function optionPriceFeeCoefficient(address) external view returns (uint);

    function spotPriceFeeCoefficient(address) external view returns (uint);

    function vegaFeeCoefficient(address) external view returns (uint);

    function vegaNormFactor(address) external view returns (uint);

    function standardSize(address) external view returns (uint);

    function skewAdjustmentFactor(address) external view returns (uint);

    function rateAndCarry(address) external view returns (int);

    function minDelta(address) external view returns (int);

    function volatilityCutoff(address) external view returns (uint);

    function quoteKey(address) external view returns (bytes32);

    function baseKey(address) external view returns (bytes32);

    function setGlobals(
        ISynthetix _synthetix,
        IExchanger _exchanger,
        IExchangeRates _exchangeRates,
        ICollateralShort _collateralShort
    ) external;

    function setGlobalsForContract(
        address _contractAddress,
        uint _tradingCutoff,
        PricingGlobals memory pricingGlobals,
        bytes32 _quoteKey,
        bytes32 _baseKey
    ) external;

    function setPaused(bool _isPaused) external;

    function setTradingCutoff(address _contractAddress, uint _tradingCutoff) external;

    function setOptionPriceFeeCoefficient(address _contractAddress, uint _optionPriceFeeCoefficient) external;

    function setSpotPriceFeeCoefficient(address _contractAddress, uint _spotPriceFeeCoefficient) external;

    function setVegaFeeCoefficient(address _contractAddress, uint _vegaFeeCoefficient) external;

    function setVegaNormFactor(address _contractAddress, uint _vegaNormFactor) external;

    function setStandardSize(address _contractAddress, uint _standardSize) external;

    function setSkewAdjustmentFactor(address _contractAddress, uint _skewAdjustmentFactor) external;

    function setRateAndCarry(address _contractAddress, int _rateAndCarry) external;

    function setMinDelta(address _contractAddress, int _minDelta) external;

    function setVolatilityCutoff(address _contractAddress, uint _volatilityCutoff) external;

    function setQuoteKey(address _contractAddress, bytes32 _quoteKey) external;

    function setBaseKey(address _contractAddress, bytes32 _baseKey) external;

    function getSpotPriceForMarket(address _contractAddress) external view returns (uint);

    function getSpotPrice(bytes32 to) external view returns (uint);

    function getPricingGlobals(address _contractAddress) external view returns (PricingGlobals memory);

    function getGreekCacheGlobals(address _contractAddress) external view returns (GreekCacheGlobals memory);

    function getExchangeGlobals(address _contractAddress, ExchangeType exchangeType)
        external
        view
        returns (ExchangeGlobals memory exchangeGlobals);

    function getGlobalsForOptionTrade(address _contractAddress, bool isBuy)
        external
        view
        returns (
            PricingGlobals memory pricingGlobals,
            ExchangeGlobals memory exchangeGlobals,
            uint tradeCutoff
        );
}


// File contracts/interfaces/lyra/ILiquidityPool.sol


pragma solidity 0.8.9;

interface ILiquidityPool {
    struct Collateral {
        uint quote;
        uint base;
    }

    /// @dev These are all in quoteAsset amounts.
    struct Liquidity {
        uint freeCollatLiquidity;
        uint usedCollatLiquidity;
        uint freeDeltaLiquidity;
        uint usedDeltaLiquidity;
    }

    enum Error {
        QuoteTransferFailed,
        AlreadySignalledWithdrawal,
        SignallingBetweenRounds,
        UnSignalMustSignalFirst,
        UnSignalAlreadyBurnable,
        WithdrawNotBurnable,
        EndRoundWithLiveBoards,
        EndRoundAlreadyEnded,
        EndRoundMustExchangeBase,
        EndRoundMustHedgeDelta,
        StartRoundMustEndRound,
        ReceivedZeroFromBaseQuoteExchange,
        ReceivedZeroFromQuoteBaseExchange,
        LockingMoreQuoteThanIsFree,
        LockingMoreBaseThanCanBeExchanged,
        FreeingMoreBaseThanLocked,
        SendPremiumNotEnoughCollateral,
        OnlyPoolHedger,
        OnlyOptionMarket,
        OnlyShortCollateral,
        ReentrancyDetected,
        Last
    }

    function lockedCollateral() external view returns (uint, uint);

    function queuedQuoteFunds() external view returns (uint);

    function expiryToTokenValue(uint) external view returns (uint);

    function deposit(address beneficiary, uint amount) external returns (uint);

    function signalWithdrawal(uint certificateId) external;

    function unSignalWithdrawal(uint certificateId) external;

    function withdraw(address beneficiary, uint certificateId) external returns (uint value);

    function tokenPriceQuote() external view returns (uint);

    function endRound() external;

    function startRound(uint lastMaxExpiryTimestamp, uint newMaxExpiryTimestamp) external;

    function exchangeBase() external;

    function lockQuote(uint amount, uint freeCollatLiq) external;

    function lockBase(
        uint amount,
        ILyraGlobals.ExchangeGlobals memory exchangeGlobals,
        Liquidity memory liquidity
    ) external;

    function freeQuoteCollateral(uint amount) external;

    function freeBase(uint amountBase) external;

    function sendPremium(
        address recipient,
        uint amount,
        uint freeCollatLiq
    ) external;

    function boardLiquidation(
        uint amountQuoteFreed,
        uint amountQuoteReserved,
        uint amountBaseFreed
    ) external;

    function sendReservedQuote(address user, uint amount) external;

    function getTotalPoolValueQuote(uint basePrice, uint usedDeltaLiquidity) external view returns (uint);

    function getLiquidity(uint basePrice, ICollateralShort short) external view returns (Liquidity memory);

    function transferQuoteToHedge(ILyraGlobals.ExchangeGlobals memory exchangeGlobals, uint amount)
        external
        returns (uint);
}


// File contracts/interfaces/lyra/IOptionMarket.sol


pragma solidity 0.8.9;


interface IOptionMarket {
    struct OptionListing {
        uint id;
        uint strike;
        uint skew;
        uint longCall;
        uint shortCall;
        uint longPut;
        uint shortPut;
        uint boardId;
    }

    struct OptionBoard {
        uint id;
        uint expiry;
        uint iv;
        bool frozen;
        uint[] listingIds;
    }

    struct Trade {
        bool isBuy;
        uint amount;
        uint vol;
        uint expiry;
        ILiquidityPool.Liquidity liquidity;
    }

    enum TradeType {LONG_CALL, SHORT_CALL, LONG_PUT, SHORT_PUT}

    enum Error {
        TransferOwnerToZero,
        InvalidBoardId,
        InvalidBoardIdOrNotFrozen,
        InvalidListingIdOrNotFrozen,
        StrikeSkewLengthMismatch,
        BoardMaxExpiryReached,
        CannotStartNewRoundWhenBoardsExist,
        ZeroAmountOrInvalidTradeType,
        BoardFrozenOrTradingCutoffReached,
        QuoteTransferFailed,
        BaseTransferFailed,
        BoardNotExpired,
        BoardAlreadyLiquidated,
        OnlyOwner,
        Last
    }

    function maxExpiryTimestamp() external view returns (uint);

    function optionBoards(uint)
        external
        view
        returns (
        uint id,
        uint expiry,
        uint iv,
        bool frozen
        );

    function optionListings(uint)
        external
        view
        returns (
        uint id,
        uint strike,
        uint skew,
        uint longCall,
        uint shortCall,
        uint longPut,
        uint shortPut,
        uint boardId
        );

    function boardToPriceAtExpiry(uint) external view returns (uint);

    function listingToBaseReturnedRatio(uint) external view returns (uint);

    function transferOwnership(address newOwner) external;

    function setBoardFrozen(uint boardId, bool frozen) external;

    function setBoardBaseIv(uint boardId, uint baseIv) external;

    function setListingSkew(uint listingId, uint skew) external;

    function createOptionBoard(
        uint expiry,
        uint baseIV,
        uint[] memory strikes,
        uint[] memory skews
    ) external returns (uint);

    function addListingToBoard(
        uint boardId,
        uint strike,
        uint skew
    ) external;

    function getLiveBoards() external view returns (uint[] memory _liveBoards);

    function getBoardListings(uint boardId) external view returns (uint[] memory);

    function openPosition(
        uint _listingId,
        TradeType tradeType,
        uint amount
    ) external returns (uint totalCost);

    function closePosition(
        uint _listingId,
        TradeType tradeType,
        uint amount
    ) external returns (uint totalCost);

    function liquidateExpiredBoard(uint boardId) external;

    function settleOptions(uint listingId, TradeType tradeType) external;
}


// File contracts/interfaces/lyra/IOptionMarketPricer.sol


pragma solidity 0.8.9;


interface IOptionMarketPricer {
    struct Pricing {
        uint optionPrice;
        int preTradeAmmNetStdVega;
        int postTradeAmmNetStdVega;
        int callDelta;
    }

    function ivImpactForTrade(
        IOptionMarket.OptionListing memory listing,
        IOptionMarket.Trade memory trade,
        ILyraGlobals.PricingGlobals memory pricingGlobals,
        uint boardBaseIv
    ) external pure returns (uint, uint);

    function updateCacheAndGetTotalCost(
        IOptionMarket.OptionListing memory listing,
        IOptionMarket.Trade memory trade,
        ILyraGlobals.PricingGlobals memory pricingGlobals,
        uint boardBaseIv
    )
        external
        returns (
        uint totalCost,
        uint newBaseIv,
        uint newSkew
        );

    function getPremium(
        IOptionMarket.Trade memory trade,
        Pricing memory pricing,
        ILyraGlobals.PricingGlobals memory pricingGlobals
    ) external pure returns (uint premium);

    function getVegaUtil(
        IOptionMarket.Trade memory trade,
        Pricing memory pricing,
        ILyraGlobals.PricingGlobals memory pricingGlobals
    ) external pure returns (uint vegaUtil);

    function getFee(
        ILyraGlobals.PricingGlobals memory pricingGlobals,
        uint amount,
        uint optionPrice,
        uint vegaUtil
    ) external pure returns (uint fee);
}


// File contracts/interfaces/lyra/IOptionMarketViewer.sol


pragma solidity 0.8.9;

interface IOptionMarketViewer {
    struct TradePremiumView {
        uint listingId;
        uint premium;
        uint basePrice;
        uint vegaUtilFee;
        uint optionPriceFee;
        uint spotPriceFee;
        uint newIv;
    }

    function getPremiumForOpen(
        uint _listingId,
        IOptionMarket.TradeType tradeType,
        uint amount
    ) external view returns (TradePremiumView memory);
}


// File contracts/utils/Pausable.sol

pragma solidity 0.8.9;

abstract contract Pausable {
    event Paused(address account);

    event Unpaused(address account);

    bool private _paused;

    constructor() {
        _paused = false;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!paused(), "PAUSED");
        _;
    }

    modifier whenPaused() {
        require(paused(), "NOT_PAUSED");
        _;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}


// File contracts/PolynomialCoveredPut.sol

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;








contract PolynomialCoveredPut is IPolynomialCoveredPut, ReentrancyGuard, Auth, Pausable {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    /// -----------------------------------------------------------------------
    /// Constants
    /// -----------------------------------------------------------------------

    /// @notice Number of weeks in a year (in 8 decimals)
    uint256 private constant WEEKS_PER_YEAR = 52142857143;

    /// @notice An instance of LYRA token
    ERC20 public constant LYRA_TOKEN = ERC20(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb);

    /// @notice An instance of LYRA distributor
    ILyraDistributor public constant LYRA_CLAIMER = ILyraDistributor(0x0BFb21f64E414Ff616aC54853e52679EEDB22Dd2);

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    /// @notice Collateral Asset
    ERC20 public immutable COLLATERAL;

    /// @notice Lyra Option Market
    IOptionMarket public immutable LYRA_MARKET;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /// @notice Human Readable Name of the Vault
    string public name;

    /// @notice Address of the keeper
    address public keeper;

    /// @notice Fee Reciepient
    address public feeReciepient;

    /// @notice Current round
    uint256 public currentRound;

    /// @notice Current Listing ID
    uint256 public currentListingId;

    /// @notice Current Listing ID's Expiry
    uint256 public currentExpiry;

    /// @notice Current Listing Strike Price
    uint256 public currentStrike;

    /// @notice Total premium collected in the round
    uint256 public premiumCollected;

    /// @notice Total amount of collateral for the current round
    uint256 public totalFunds;

    /// @notice Funds used so far in the current round
    uint256 public usedFunds;

    /// @notice Total shares issued so far
    uint256 public totalShares;

    /// @notice Vault capacity
    uint256 public vaultCapacity;

    /// @notice User deposit limit
    uint256 public userDepositLimit;

    /// @notice Total pending deposit amounts (in COLLATERAL)
    uint256 public pendingDeposits;

    /// @notice Pending withdraws (in SHARES)
    uint256 public pendingWithdraws;

    /// @notice IV Slippage limit per trade
    uint256 public ivLimit;

    /// @notice Performance Fee
    uint256 public performanceFee;

    /// @notice Management Fee
    uint256 public managementFee;

    /// @notice Mapping of User Info
    mapping (address => UserInfo) public userInfos;

    /// @notice Mapping of round versus perfomance index
    mapping (uint256 => uint256) public performanceIndices;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event StartNewRound(
        uint256 indexed round,
        uint256 indexed listingId,
        uint256 newIndex,
        uint256 expiry,
        uint256 strikePrice,
        uint256 lostColl,
        uint256 qty
    );

    event SellOptions(
        uint256 indexed round,
        uint256 optionsSold,
        uint256 totalCost,
        uint256 expiry,
        uint256 strikePrice
    );

    event CompleteWithdraw(
        address indexed user,
        uint256 indexed withdrawnRound,
        uint256 shares,
        uint256 funds
    );

    event Deposit(
        address indexed user,
        uint256 indexed depositRound,
        uint256 amt
    );

    event CancelDeposit(
        address indexed user,
        uint256 indexed depositRound,
        uint256 amt
    );

    event RequestWithdraw(
        address indexed user,
        uint256 indexed withdrawnRound,
        uint256 shares
    );

    event CancelWithdraw(
        address indexed user,
        uint256 indexed withdrawnRound,
        uint256 shares
    );

    event SetCap(
        address indexed auth,
        uint256 oldCap,
        uint256 newCap
    );

    event SetUserDepositLimit(
        address indexed auth,
        uint256 oldDepositLimit,
        uint256 newDepositLimit
    );

    event SetIvLimit(
        address indexed auth,
        uint256 oldLimit,
        uint256 newLimit
    );

    event SetFees(
        address indexed auth,
        uint256 oldManageFee,
        uint256 oldPerfFee,
        uint256 newManageFee,
        uint256 newPerfFee
    );

    event SetFeeReciepient(
        address indexed auth,
        address oldReceipient,
        address newReceipient
    );

    event SetKeeper(
        address indexed auth,
        address oldKeeper,
        address newKeeper
    );

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    modifier onlyKeeper {
        require(msg.sender == keeper, "NOT_KEEPER");
        _;
    }

    constructor(
        string memory _name,
        ERC20 _collateral,
        IOptionMarket _lyraMarket
    ) Auth(msg.sender, Authority(address(0x0))) {
        name = _name;
        COLLATERAL = _collateral;
        LYRA_MARKET = _lyraMarket;

        performanceIndices[0] = 1e18;
    }

    /// -----------------------------------------------------------------------
    /// User actions
    /// -----------------------------------------------------------------------

    /// @notice Deposits COLLATERAL tokens to the vault
    /// Shares assigned at the end of the current round (unless the round is 0)
    /// @param _amt Amount of COLLATERAL tokens to deposit
    function deposit(uint256 _amt) external override nonReentrant whenNotPaused {
        require(_amt > 0, "AMT_CANNOT_BE_ZERO");

        if (currentRound == 0) {
            _depositForRoundZero(msg.sender, _amt);
        } else {
            _deposit(msg.sender, _amt);
        }

        emit Deposit(msg.sender, currentRound, _amt);
    }

    /// @notice Deposits COLLATERAL tokens to the vault for another address
    /// Used in periphery contracts to swap and deposit
    /// @param _amt Amount of COLLATERAL tokens to deposit
    function deposit(address _user, uint256 _amt) external override nonReentrant whenNotPaused {
        require(_amt > 0, "AMT_CANNOT_BE_ZERO");

        if (currentRound == 0) {
            _depositForRoundZero(_user, _amt);
        } else {
            _deposit(_user, _amt);
        }

        emit Deposit(_user, currentRound, _amt);
    }

    /// @notice Cancel a pending deposit
    /// @param _amt Amount of tokens to cancel from deposit
    function cancelDeposit(uint256 _amt) external nonReentrant whenNotPaused {
        UserInfo storage userInfo = userInfos[msg.sender];

        require(
            userInfo.pendingDeposit >= _amt &&
            userInfo.depositRound == currentRound,
            "NO_PENDING_DEPOSIT"
        );

        userInfo.pendingDeposit -= _amt;
        pendingDeposits -= _amt;

        emit CancelDeposit(msg.sender, currentRound, _amt);
    }

    /// @notice Request withdraw from the vault
    /// Unless cancelled, withdraw request can be completed at the end of the round
    /// @param _shares Amount of shares to withdraw
    function requestWithdraw(uint256 _shares) external override nonReentrant {
        UserInfo storage userInfo = userInfos[msg.sender];

        if (userInfo.depositRound < currentRound && userInfo.pendingDeposit > 0) {
            /// Convert any pending deposit to shares
            userInfo.totalShares += userInfo.pendingDeposit.fdiv(
                performanceIndices[userInfo.depositRound],
                1e18
            );
            userInfo.pendingDeposit = 0;
        }

        require(userInfo.totalShares >= _shares, "INSUFFICIENT_SHARES");

        if (currentRound == 0) {
            COLLATERAL.safeTransfer(msg.sender, _shares);
            totalShares -= _shares;
        } else {
            if (userInfo.withdrawRound < currentRound) {
                require(userInfo.withdrawnShares == 0, "INCOMPLETE_PENDING_WITHDRAW");
            }
            userInfo.withdrawRound = currentRound;
            userInfo.withdrawnShares += _shares;
            pendingWithdraws += _shares;
        }
        userInfo.totalShares -= _shares;

        emit RequestWithdraw(msg.sender, currentRound, _shares);
    }

    /// @notice Cancel a withdraw request
    /// Cannot cancel a withdraw request if a round has already passed
    /// @param _shares Amount of shares to cancel
    function cancelWithdraw(uint256 _shares) external override nonReentrant whenNotPaused {
        UserInfo storage userInfo = userInfos[msg.sender];

        require(userInfo.withdrawnShares >= _shares, "NO_WITHDRAW_REQUESTS");
        require(userInfo.withdrawRound == currentRound, "CANNOT_CANCEL_AFTER_ROUND");

        userInfo.withdrawnShares -= _shares;
        pendingWithdraws -= _shares;
        userInfo.totalShares += _shares;

        emit CancelWithdraw(msg.sender, currentRound, _shares);
    }

    /// @notice Complete withdraw request and claim UNDERLYING tokens from the vault
    function completeWithdraw() external override nonReentrant {
        UserInfo storage userInfo = userInfos[msg.sender];

        require(currentRound > userInfo.withdrawRound, "ROUND_NOT_OVER");

        /// Calculate amount to withdraw from withdrawn round's performance index
        uint256 pendingWithdrawAmount = userInfo.withdrawnShares.fmul(
            performanceIndices[userInfo.withdrawRound],
            1e18
        );
        COLLATERAL.safeTransfer(msg.sender, pendingWithdrawAmount);

        emit CompleteWithdraw(
            msg.sender,
            userInfo.withdrawRound,
            userInfo.withdrawnShares,
            pendingWithdrawAmount
        );

        userInfo.withdrawnShares = 0;
        userInfo.withdrawRound = 0;
    }

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    /// @notice Set vault capacity
    /// @param _newCap Vault capacity amount in UNDERLYING
    function setCap(uint256 _newCap) external requiresAuth {
        require(_newCap > 0, "CAP_CANNOT_BE_ZERO");
        emit SetCap(msg.sender, vaultCapacity, _newCap);
        vaultCapacity = _newCap;
    }

    /// @notice Set user deposit limit
    /// @param _depositLimit Max deposit amount per each deposit, in UNDERLYING
    function setUserDepositLimit(uint256 _depositLimit) external requiresAuth {
        require(_depositLimit > 0, "LIMIT_CANNOT_BE_ZERO");
        emit SetUserDepositLimit(msg.sender, userDepositLimit, _depositLimit);
        userDepositLimit = _depositLimit;
    }

    /// @notice Set IV Limit
    /// @param _ivLimit IV Limit. 1e16 == 1%
    function setIvLimit(uint256 _ivLimit) external requiresAuth {
        require(_ivLimit > 0, "SLIPPAGE_CANNOT_BE_ZERO");
        emit SetIvLimit(msg.sender, ivLimit, _ivLimit);
        ivLimit = _ivLimit;
    }

    /// @notice Set vault fees
    /// Fees use 8 decimals. 1% == 1e6, 10% == 1e7 & 100% == 1e8
    /// @param _perfomanceFee Performance fee
    /// @param _managementFee Management Fee
    function setFees(uint256 _perfomanceFee, uint256 _managementFee) external requiresAuth {
        require(_perfomanceFee <= 1e7, "PERF_FEE_TOO_HIGH");
        require(_managementFee <= 5e6, "MANAGE_FEE_TOO_HIGH");

        emit SetFees(msg.sender, managementFee, performanceFee, _managementFee, _perfomanceFee);

        performanceFee = _perfomanceFee;
        managementFee = _managementFee;
    }

    /// @notice Set fee reciepient address
    /// @param _feeReciepient Fee reciepient address
    function setFeeReciepient(address _feeReciepient) external requiresAuth {
        require(_feeReciepient != address(0x0), "CANNOT_BE_VOID");
        emit SetFeeReciepient(msg.sender, feeReciepient, _feeReciepient);
        feeReciepient = _feeReciepient;
    }

    /// @notice Set Keeper address
    /// Keeper bot sells options from the vault once a round is started
    /// @param _keeper Address of the keeper
    function setKeeper(address _keeper) external requiresAuth {
        require(_keeper != address(0x0), "CANNOT_BE_VOID");
        emit SetKeeper(msg.sender, keeper, _keeper);
        keeper = _keeper;
    }

    /// @notice Pause contract
    /// Once paused, deposits and selling options are closed
    function pause() external requiresAuth {
        _pause();
    }

    /// @notice Unpause contract
    function unpause() external requiresAuth {
        _unpause();
    }

    /// @notice Claim LYRA from Lyra Distributor
    /// @param _receiver Target Address to receive the claimed tokens
    function claimLyra(address _receiver) external requiresAuth {
        LYRA_CLAIMER.claim();
        uint256 received = LYRA_TOKEN.balanceOf(address(this));
        LYRA_TOKEN.transfer(_receiver, received);
    }

    /// @notice Start a new round by providing listing ID for an upcoming option
    /// @param _listingId Unique listing ID from Lyra Option Market
    function startNewRound(uint256 _listingId) external requiresAuth nonReentrant {
        /// Check if listing ID is valid & last round's expiry is over
        (,uint256 strikePrice,,,,,, uint256 boardId) = LYRA_MARKET.optionListings(_listingId);
        (, uint256 expiry,,) = LYRA_MARKET.optionBoards(boardId);
        require(expiry >= block.timestamp, "INVALID_LISTING_ID");
        require(block.timestamp > currentExpiry, "ROUND_NOT_OVER");
        /// Close position if round != 0 & Calculate funds & new index value
        if (currentRound > 0) {
            uint256 newIndex = performanceIndices[currentRound - 1];
            uint256 collateralWithdrawn = usedFunds;
            uint256 collectedFunds = totalFunds;
            uint256 totalFees;

            if (usedFunds > 0) {
                uint256 preSettleBal = COLLATERAL.balanceOf(address(this));
                /// Settle all the options sold from last round
                LYRA_MARKET.settleOptions(currentListingId, IOptionMarket.TradeType.SHORT_PUT);
                uint256 postSettleBal = COLLATERAL.balanceOf(address(this));
                collateralWithdrawn = postSettleBal - preSettleBal;

                /// Calculate and collect fees, if the option expired OTM
                if (collateralWithdrawn == usedFunds) {
                    uint256 currentRoundManagementFees = collateralWithdrawn.fmul(managementFee, WEEKS_PER_YEAR);
                    uint256 currentRoundPerfomanceFee = premiumCollected.fmul(performanceFee, WEEKS_PER_YEAR);
                    totalFees = currentRoundManagementFees + currentRoundPerfomanceFee;
                    COLLATERAL.safeTransfer(feeReciepient, totalFees);
                }
                /// Calculate last round's performance index
                uint256 unusedFunds = totalFunds - usedFunds;
                collectedFunds = collateralWithdrawn + premiumCollected + unusedFunds - totalFees;
                newIndex = collectedFunds.fdiv(totalShares, 1e18);
            }

            performanceIndices[currentRound] = newIndex;

            /// Process pending deposits and withdrawals
            totalShares += pendingDeposits.fdiv(newIndex, 1e18);
            totalShares -= pendingWithdraws;

            /// Calculate available funds for the round that's starting
            uint256 fundsPendingWithdraws = pendingWithdraws.fmul(newIndex, 1e18);
            totalFunds = collectedFunds + pendingDeposits - fundsPendingWithdraws;

            emit StartNewRound(
                currentRound + 1,
                _listingId,
                newIndex,
                expiry,
                strikePrice,
                usedFunds - collateralWithdrawn,
                usedFunds
            );

            pendingDeposits = 0;
            pendingWithdraws = 0;
            usedFunds = 0;
            premiumCollected = 0;
        } else {
            totalFunds = COLLATERAL.balanceOf(address(this));

            emit StartNewRound(1, _listingId, 1e18, expiry, strikePrice, 0, 0);
        }
        /// Set listing ID and start round
        currentRound++;
        currentListingId = _listingId;
        currentExpiry = expiry;
        currentStrike = strikePrice;
    }

    /// @notice Sell options to Lyra AMM
    /// Called via Keeper bot
    /// @param _amt Amount of sUSD to lock as collateral for selling options
    function sellOptions(uint256 _amt) external onlyKeeper nonReentrant whenNotPaused {
        uint256 maxAmt = (totalFunds - usedFunds).fdiv(currentStrike, 1e18);
        _amt = _amt > maxAmt ? maxAmt : _amt;
        require(_amt > 0, "NO_FUNDS_REMAINING");

        uint256 collateralAmt = _amt.fmul(currentStrike, 1e18);

        IOptionMarket.TradeType tradeType = IOptionMarket.TradeType.SHORT_PUT;

        /// Get initial board IV, and listing skew to calculate initial IV
        (,, uint256 initSkew,,,,, uint256 boardId) = LYRA_MARKET.optionListings(currentListingId);
        (,, uint256 initBaseIv,) = LYRA_MARKET.optionBoards(boardId);

        /// Sell options to Lyra AMM
        COLLATERAL.safeApprove(address(LYRA_MARKET), collateralAmt);
        uint256 totalCost = LYRA_MARKET.openPosition(currentListingId, tradeType, _amt);

        /// Get final board IV, and listing skew to calculate final IV
        (,, uint256 finalSkew,,,,,) = LYRA_MARKET.optionListings(currentListingId);
        (,, uint256 finalBaseIv,) = LYRA_MARKET.optionBoards(boardId);

        /// Calculate IVs and revert if IV impact is high
        uint256 initIv = initBaseIv.fmul(initSkew, 1e18);
        uint256 finalIv = finalBaseIv.fmul(finalSkew, 1e18);
        require(initIv - finalIv < ivLimit, "IV_LIMIT_HIT");

        premiumCollected += totalCost;
        usedFunds += collateralAmt;

        emit SellOptions(currentRound, _amt, totalCost, currentExpiry, currentStrike);
    }

    /// -----------------------------------------------------------------------
    /// Internal Methods
    /// -----------------------------------------------------------------------

    /// @notice Deposit for round zero
    /// Shares are issued during the round itself
    function _depositForRoundZero(address _user, uint256 _amt) internal {
        COLLATERAL.safeTransferFrom(msg.sender, address(this), _amt);
        require(COLLATERAL.balanceOf(address(this)) <= vaultCapacity, "CAPACITY_EXCEEDED");

        UserInfo storage userInfo = userInfos[_user];
        userInfo.totalShares += _amt;
        require(userInfo.totalShares <= userDepositLimit, "USER_DEPOSIT_LIMIT_EXCEEDED");
        totalShares += _amt;
    }

    /// @notice Internal deposit function
    /// Shares issued after the current round is over
    function _deposit(address _user, uint256 _amt) internal {
        COLLATERAL.safeTransferFrom(msg.sender, address(this), _amt);

        pendingDeposits += _amt;
        require(totalFunds + pendingDeposits < vaultCapacity, "CAPACITY_EXCEEDED");

        UserInfo storage userInfo = userInfos[_user];
        if (userInfo.depositRound > 0 && userInfo.depositRound < currentRound) {
            userInfo.totalShares += userInfo.pendingDeposit.fdiv(performanceIndices[userInfo.depositRound], 1e18);
            userInfo.pendingDeposit = _amt;
        } else {
            userInfo.pendingDeposit += _amt;
        }
        userInfo.depositRound = currentRound;

        uint256 totalBalance = userInfo.pendingDeposit + userInfo.totalShares.fmul(performanceIndices[currentRound - 1], 1e18);
        require(totalBalance <= userDepositLimit, "USER_DEPOSIT_LIMIT_EXCEEDED");
    }
}