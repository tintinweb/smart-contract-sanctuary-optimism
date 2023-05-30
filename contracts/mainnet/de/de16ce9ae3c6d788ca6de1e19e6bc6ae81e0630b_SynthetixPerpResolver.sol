// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MAX_UINT256 = 2**256 - 1;

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
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
                revert(0, 0)
            }

            // Divide x * y by the denominator.
            z := div(mul(x, y), denominator)
        }
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
                revert(0, 0)
            }

            // If x * y modulo the denominator is strictly greater than 0,
            // 1 is added to round up the division of x * y by the denominator.
            z := add(gt(mod(mul(x, y), denominator), 0), div(mul(x, y), denominator))
        }
    }

    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
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
        /// @solidity memory-safe-assembly
        assembly {
            let y := x // We start y at x, which will help us make our initial estimate.

            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // We check y >= 2^(k + 8) but shift right by k bits
            // each branch to ensure that if x >= 256, then y >= 256.
            if iszero(lt(y, 0x10000000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x1000000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x10000000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x1000000)) {
                y := shr(16, y)
                z := shl(8, z)
            }

            // Goal was to get z*z*y within a small factor of x. More iterations could
            // get y in a tighter range. Currently, we will have y in [256, 256*2^16).
            // We ensured y >= 256 so that the relative difference between y and y+1 is small.
            // That's not possible if x < 256 but we can just verify those cases exhaustively.

            // Now, z*z*y <= x < z*z*(y+1), and y <= 2^(16+8), and either y >= 256, or x < 256.
            // Correctness can be checked exhaustively for x < 256, so we assume y >= 256.
            // Then z*sqrt(y) is within sqrt(257)/sqrt(256) of sqrt(x), or about 20bps.

            // For s in the range [1/256, 256], the estimate f(s) = (181/1024) * (s+1) is in the range
            // (1/2.84 * sqrt(s), 2.84 * sqrt(s)), with largest error when s = 1 and when s = 256 or 1/256.

            // Since y is in [256, 256*2^16), let a = y/65536, so that a is in [1/256, 256). Then we can estimate
            // sqrt(y) using sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2^18.

            // There is no overflow risk here since y < 2^136 after the first branch above.
            z := shr(18, mul(z, add(y, 65536))) // A mul() is saved from starting z at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If x+1 is a perfect square, the Babylonian method cycles between
            // floor(sqrt(x)) and ceil(sqrt(x)). This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            // Since the ceil is rare, we save gas on the assignment and repeat division in the rare case.
            // If you don't care whether the floor or ceil square root is returned, you can remove this statement.
            z := sub(z, lt(div(x, z), z))
        }
    }

    function unsafeMod(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Mod x by y. Note this will return
            // 0 instead of reverting if y is zero.
            z := mod(x, y)
        }
    }

    function unsafeDiv(uint256 x, uint256 y) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // Divide x by y. Note this will return
            // 0 instead of reverting if y is zero.
            r := div(x, y)
        }
    }

    function unsafeDivUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Add 1 to x * y if x % y > 0. Note this will
            // return 0 instead of reverting if y is zero.
            z := add(gt(mod(x, y), 0), div(x, y))
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @notice Signed 18 decimal fixed point (wad) arithmetic library.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SignedWadMath.sol)
/// @author Modified from Remco Bloemen (https://xn--2-umb.com/22/exp-ln/index.html)

/// @dev Will not revert on overflow, only use where overflow is not possible.
function toWadUnsafe(uint256 x) pure returns (int256 r) {
    /// @solidity memory-safe-assembly
    assembly {
        // Multiply x by 1e18.
        r := mul(x, 1000000000000000000)
    }
}

/// @dev Takes an integer amount of seconds and converts it to a wad amount of days.
/// @dev Will not revert on overflow, only use where overflow is not possible.
/// @dev Not meant for negative second amounts, it assumes x is positive.
function toDaysWadUnsafe(uint256 x) pure returns (int256 r) {
    /// @solidity memory-safe-assembly
    assembly {
        // Multiply x by 1e18 and then divide it by 86400.
        r := div(mul(x, 1000000000000000000), 86400)
    }
}

/// @dev Takes a wad amount of days and converts it to an integer amount of seconds.
/// @dev Will not revert on overflow, only use where overflow is not possible.
/// @dev Not meant for negative day amounts, it assumes x is positive.
function fromDaysWadUnsafe(int256 x) pure returns (uint256 r) {
    /// @solidity memory-safe-assembly
    assembly {
        // Multiply x by 86400 and then divide it by 1e18.
        r := div(mul(x, 86400), 1000000000000000000)
    }
}

/// @dev Will not revert on overflow, only use where overflow is not possible.
function unsafeWadMul(int256 x, int256 y) pure returns (int256 r) {
    /// @solidity memory-safe-assembly
    assembly {
        // Multiply x by y and divide by 1e18.
        r := sdiv(mul(x, y), 1000000000000000000)
    }
}

/// @dev Will return 0 instead of reverting if y is zero and will
/// not revert on overflow, only use where overflow is not possible.
function unsafeWadDiv(int256 x, int256 y) pure returns (int256 r) {
    /// @solidity memory-safe-assembly
    assembly {
        // Multiply x by 1e18 and divide it by y.
        r := sdiv(mul(x, 1000000000000000000), y)
    }
}

function wadMul(int256 x, int256 y) pure returns (int256 r) {
    /// @solidity memory-safe-assembly
    assembly {
        // Store x * y in r for now.
        r := mul(x, y)

        // Equivalent to require(x == 0 || (x * y) / x == y)
        if iszero(or(iszero(x), eq(sdiv(r, x), y))) {
            revert(0, 0)
        }

        // Scale the result down by 1e18.
        r := sdiv(r, 1000000000000000000)
    }
}

function wadDiv(int256 x, int256 y) pure returns (int256 r) {
    /// @solidity memory-safe-assembly
    assembly {
        // Store x * 1e18 in r for now.
        r := mul(x, 1000000000000000000)

        // Equivalent to require(y != 0 && ((x * 1e18) / 1e18 == x))
        if iszero(and(iszero(iszero(y)), eq(sdiv(r, 1000000000000000000), x))) {
            revert(0, 0)
        }

        // Divide r by y.
        r := sdiv(r, y)
    }
}

/// @dev Will not work with negative bases, only use when x is positive.
function wadPow(int256 x, int256 y) pure returns (int256) {
    // Equivalent to x to the power of y because x ** y = (e ** ln(x)) ** y = e ** (ln(x) * y)
    return wadExp((wadLn(x) * y) / 1e18); // Using ln(x) means x must be greater than 0.
}

function wadExp(int256 x) pure returns (int256 r) {
    unchecked {
        // When the result is < 0.5 we return zero. This happens when
        // x <= floor(log(0.5e18) * 1e18) ~ -42e18
        if (x <= -42139678854452767551) return 0;

        // When the result is > (2**255 - 1) / 1e18 we can not represent it as an
        // int. This happens when x >= floor(log((2**255 - 1) / 1e18) * 1e18) ~ 135.
        if (x >= 135305999368893231589) revert("EXP_OVERFLOW");

        // x is now in the range (-42, 136) * 1e18. Convert to (-42, 136) * 2**96
        // for more intermediate precision and a binary basis. This base conversion
        // is a multiplication by 1e18 / 2**96 = 5**18 / 2**78.
        x = (x << 78) / 5**18;

        // Reduce range of x to (-½ ln 2, ½ ln 2) * 2**96 by factoring out powers
        // of two such that exp(x) = exp(x') * 2**k, where k is an integer.
        // Solving this gives k = round(x / log(2)) and x' = x - k * log(2).
        int256 k = ((x << 96) / 54916777467707473351141471128 + 2**95) >> 96;
        x = x - k * 54916777467707473351141471128;

        // k is in the range [-61, 195].

        // Evaluate using a (6, 7)-term rational approximation.
        // p is made monic, we'll multiply by a scale factor later.
        int256 y = x + 1346386616545796478920950773328;
        y = ((y * x) >> 96) + 57155421227552351082224309758442;
        int256 p = y + x - 94201549194550492254356042504812;
        p = ((p * y) >> 96) + 28719021644029726153956944680412240;
        p = p * x + (4385272521454847904659076985693276 << 96);

        // We leave p in 2**192 basis so we don't need to scale it back up for the division.
        int256 q = x - 2855989394907223263936484059900;
        q = ((q * x) >> 96) + 50020603652535783019961831881945;
        q = ((q * x) >> 96) - 533845033583426703283633433725380;
        q = ((q * x) >> 96) + 3604857256930695427073651918091429;
        q = ((q * x) >> 96) - 14423608567350463180887372962807573;
        q = ((q * x) >> 96) + 26449188498355588339934803723976023;

        /// @solidity memory-safe-assembly
        assembly {
            // Div in assembly because solidity adds a zero check despite the unchecked.
            // The q polynomial won't have zeros in the domain as all its roots are complex.
            // No scaling is necessary because p is already 2**96 too large.
            r := sdiv(p, q)
        }

        // r should be in the range (0.09, 0.25) * 2**96.

        // We now need to multiply r by:
        // * the scale factor s = ~6.031367120.
        // * the 2**k factor from the range reduction.
        // * the 1e18 / 2**96 factor for base conversion.
        // We do this all at once, with an intermediate result in 2**213
        // basis, so the final right shift is always by a positive amount.
        r = int256((uint256(r) * 3822833074963236453042738258902158003155416615667) >> uint256(195 - k));
    }
}

function wadLn(int256 x) pure returns (int256 r) {
    unchecked {
        require(x > 0, "UNDEFINED");

        // We want to convert x from 10**18 fixed point to 2**96 fixed point.
        // We do this by multiplying by 2**96 / 10**18. But since
        // ln(x * C) = ln(x) + ln(C), we can simply do nothing here
        // and add ln(2**96 / 10**18) at the end.

        /// @solidity memory-safe-assembly
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

        // Reduce range of x to (1, 2) * 2**96
        // ln(2^k * x) = k * ln(2) + ln(x)
        int256 k = r - 96;
        x <<= uint256(159 - k);
        x = int256(uint256(x) >> 159);

        // Evaluate using a (8, 8)-term rational approximation.
        // p is made monic, we will multiply by a scale factor later.
        int256 p = x + 3273285459638523848632254066296;
        p = ((p * x) >> 96) + 24828157081833163892658089445524;
        p = ((p * x) >> 96) + 43456485725739037958740375743393;
        p = ((p * x) >> 96) - 11111509109440967052023855526967;
        p = ((p * x) >> 96) - 45023709667254063763336534515857;
        p = ((p * x) >> 96) - 14706773417378608786704636184526;
        p = p * x - (795164235651350426258249787498 << 96);

        // We leave p in 2**192 basis so we don't need to scale it back up for the division.
        // q is monic by convention.
        int256 q = x + 5573035233440673466300451813936;
        q = ((q * x) >> 96) + 71694874799317883764090561454958;
        q = ((q * x) >> 96) + 283447036172924575727196451306956;
        q = ((q * x) >> 96) + 401686690394027663651624208769553;
        q = ((q * x) >> 96) + 204048457590392012362485061816622;
        q = ((q * x) >> 96) + 31853899698501571402653359427138;
        q = ((q * x) >> 96) + 909429971244387300277376558375;
        /// @solidity memory-safe-assembly
        assembly {
            // Div in assembly because solidity adds a zero check despite the unchecked.
            // The q polynomial is known not to have zeros in the domain.
            // No scaling required because p is already 2**96 too large.
            r := sdiv(p, q)
        }

        // r is in the range (0, 0.125) * 2**96

        // Finalization, we need to:
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

/// @dev Will return 0 instead of reverting if y is zero.
function unsafeDiv(int256 x, int256 y) pure returns (int256 r) {
    /// @solidity memory-safe-assembly
    assembly {
        // Divide x by y.
        r := sdiv(x, y)
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {wadDiv} from "solmate/utils/SignedWadMath.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface IAddressResolver {
    function getAddress(bytes32 name) external view returns (address);
}

interface IExchanger {
    function dynamicFeeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey)
        external
        view
        returns (uint256 feeRate, bool tooVolatile);
}

interface IFlexibleStorage {
    function getUIntValue(bytes32 contractName, bytes32 record) external view returns (uint256);
}

interface IFuturesMarketManager {
    function marketForKey(bytes32 marketKey) external view returns (address);
}

interface IDynamicKeeperFeeModule {
    function getMinKeeperFee() external view returns (uint256);
}

interface IPerpMarket {
    struct Position {
        uint64 id;
        uint64 lastFundingIndex;
        uint128 margin;
        uint128 lastPrice;
        int128 size;
    }

    function positions(address account) external view returns (Position memory);
    function baseAsset() external view returns (bytes32 key);
    function assetPrice() external view returns (uint256 price, bool invalid);
    function marketSkew() external view returns (int256 skew);
    function marketSize() external view returns (uint256 size);
    function marketKey() external view returns (bytes32 key);
    function remainingMargin(address account) external view returns (uint256 marginRemaining, bool invalid);
    function orderFee(int256 sizeDelta, uint8 orderType) external view returns (uint256 fee, bool invalid);
    function fundingLastRecomputed() external view returns (uint32 timestamp);
    function fundingSequence(uint256 index) external view returns (int128 netFunding);
    function currentFundingRate() external view returns (int256 fundingRate);
    function currentFundingVelocity() external view returns (int256 fundingVelocity);
    function unrecordedFunding() external view returns (int256 funding, bool invalid);
    function fundingSequenceLength() external view returns (uint256 length);
}

contract SynthetixPerpResolver {
    using FixedPointMathLib for uint256;

    struct Data {
        bool isMaxMarket;
        bool tooVolatile;
        bytes32 marketKey;
        uint256 currentPrice;
        uint256 margin;
        uint256 minMargin;
    }

    enum Status {
        Ok,
        InvalidPrice,
        InvalidOrderPrice,
        PriceOutOfBounds,
        CanLiquidate,
        CannotLiquidate,
        MaxMarketSizeExceeded,
        MaxLeverageExceeded,
        InsufficientMargin,
        NotPermitted,
        NilOrder,
        NoPositionOpen,
        PriceTooVolatile,
        PriceImpactToleranceExceeded
    }

    IAddressResolver private constant addressResolver = IAddressResolver(0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C);

    IFuturesMarketManager private constant marketManager =
        IFuturesMarketManager(0xdb89f3fc45A707Dd49781495f77f8ae69bF5cA6e);

    IDynamicKeeperFeeModule private constant dynamicKeeperFee =
        IDynamicKeeperFeeModule(0xF4bc5588aAB8CBB412baDd3674094ECF808286f6);

    // function balances(address user, address[] memory token, address[] memory market)
    //     external
    //     view
    //     returns (uint256[] memory tokens, uint256[] memory markets)
    // {
    //     if (token.length > 0) {
    //         tokens = new uint256[](token.length);
    //     }

    //     if (market.length > 0) {
    //         markets = new uint256[](market.length);
    //     }

    //     for (uint256 i = 0; i < token.length; i++) {
    //         tokens[i] = IERC20(token[i]).balanceOf(user);
    //     }

    //     for (uint256 i = 0; i < market.length; i++) {
    //         IPerpMarket.Position memory position = IPerpMarket(market[i]).positions(user);

    //         if (position.size == 0) {
    //             markets[i] = position.margin;
    //         }
    //     }
    // }

    function calculate(address market, int256 marginDelta, int256 sizeDelta, address account)
        external
        view
        returns (
            uint256 minKeeperFee,
            uint256 fee,
            uint256 liquidationPrice,
            uint256 totalMargin,
            uint256 accessibleMargin,
            uint256 assetPrice,
            Status status
        )
    {
        minKeeperFee = dynamicKeeperFee.getMinKeeperFee();
        IPerpMarket perpMarket = IPerpMarket(market);
        IPerpMarket.Position memory position = perpMarket.positions(account);
        Data memory data;

        data.marketKey = perpMarket.marketKey();

        (data.currentPrice,) = perpMarket.assetPrice();

        (fee,) = perpMarket.orderFee(sizeDelta, 2);

        (data.margin,) = perpMarket.remainingMargin(account);

        if (data.margin == 0 && marginDelta <= 0) {
            return (minKeeperFee, 0, 0, 0, 0, data.currentPrice, Status.InsufficientMargin);
        }

        if (marginDelta > 0) {
            data.margin += _abs(marginDelta);
        } else {
            uint256 absMargin = _abs(marginDelta);
            if (absMargin > data.margin) {
                return (minKeeperFee, 0, 0, 0, 0, data.currentPrice, Status.InsufficientMargin);
            }
            data.margin -= _abs(marginDelta);
        }

        data.margin -= fee + 2e18;

        data.minMargin = _getParam(data.marketKey, "perpsV2MinInitialMargin");

        if (data.margin < data.minMargin) {
            return (minKeeperFee, 0, 0, 0, 0, data.currentPrice, Status.InsufficientMargin);
        }

        int256 oldSize = position.size;

        position.size += int128(sizeDelta);

        data.isMaxMarket = _isMaxMarket(perpMarket, oldSize, position.size);

        if (data.isMaxMarket) {
            status = Status.MaxMarketSizeExceeded;
        }

        int256 liquidationMargin = int256(_liquidationMargin(data.marketKey, position.size, data.currentPrice));

        if (_abs(liquidationMargin) >= data.margin) {
            status = Status.CanLiquidate;
        }

        int256 liquidationPremium = int256(_liquidationPremium(data.marketKey, position.size, data.currentPrice));
        int256 liqPrice = position.size == 0
            ? int256(0)
            : (
                int256(data.currentPrice)
                    + wadDiv(liquidationMargin - int256(data.margin) - liquidationPremium, position.size)
            );
        liquidationPrice = uint256(_max(0, liqPrice));

        uint256 leverage = data.margin == 0 ? 0 : _abs(int256(position.size)).mulDivDown(data.currentPrice, data.margin);
        uint256 maxLeverage = _getParam(data.marketKey, "maxLeverage") + 1e16;

        if (leverage > maxLeverage) {
            status = Status.MaxLeverageExceeded;
        }

        totalMargin = data.margin;

        uint256 inaccessible = _inaccessibleMargin(data.marketKey, position.size, data.currentPrice, data.minMargin);
        if (inaccessible < totalMargin) {
            accessibleMargin = totalMargin - inaccessible;
        }
        assetPrice = data.currentPrice;
    }

    function _liquidationMargin(bytes32 marketKey, int256 size, uint256 price) internal view returns (uint256) {
        uint256 liquidationBufferParam = _getParam(marketKey, "perpsV2LiquidationBufferRatio");
        uint256 liquidationBuffer = _abs(size).mulWadDown(price).mulWadDown(liquidationBufferParam);
        uint256 liquidationFeeRatio = _getParam(marketKey, "perpsV2LiquidationFeeRatio");
        uint256 proportionalFee = _abs(size).mulWadDown(price).mulWadDown(liquidationFeeRatio);
        uint256 maxKeeperFee = _getParam(marketKey, "perpsV2MaxKeeperFee");
        uint256 cappedProportionalFee = proportionalFee > maxKeeperFee ? maxKeeperFee : proportionalFee;
        uint256 minKeeperFee = _getParam(marketKey, "perpsV2MinKeeperFee");
        uint256 liquidationFee = cappedProportionalFee > minKeeperFee ? cappedProportionalFee : minKeeperFee;

        return liquidationBuffer + liquidationFee;
    }

    function _liquidationPremium(bytes32 marketKey, int256 size, uint256 price) internal view returns (uint256) {
        if (size == 0) {
            return 0;
        }
        uint256 notionalSize = _abs(size).mulWadDown(price);
        uint256 skewScale = _getParam(marketKey, "skewScale");
        uint256 liquidationPremiumMultiplier = _getParam(marketKey, "liquidationPremiumMultiplier");
        return _abs(size).mulWadDown(notionalSize).mulDivDown(liquidationPremiumMultiplier, skewScale);
    }

    function _isMaxMarket(IPerpMarket perpMarket, int256 oldSize, int256 newSize) internal view returns (bool) {
        if (_sameSide(oldSize, newSize) && _abs(newSize) <= _abs(oldSize)) {
            return false;
        }
        bytes32 marketKey = perpMarket.marketKey();
        uint256 maxMarketSize = _getParam(marketKey, "maxMarketValue");
        int256 skew = perpMarket.marketSkew() - oldSize + newSize;
        int256 marketSize = int256(perpMarket.marketSize()) - int256(_abs(oldSize)) + int256(_abs(newSize));
        int256 sideSize;

        if (newSize > 0) {
            sideSize = marketSize + skew;
        } else {
            sideSize = marketSize - skew;
        }

        if (maxMarketSize < _abs(sideSize / 2)) {
            return true;
        }

        return false;
    }

    function _inaccessibleMargin(bytes32 marketKey, int256 size, uint256 price, uint256 minMargin)
        internal
        view
        returns (uint256)
    {
        uint256 maxLeverage = _getParam(marketKey, "maxLeverage") - 1e15;
        uint256 notionalSize = _abs(size).mulWadDown(price);
        uint256 inaccessible = notionalSize.divWadDown(maxLeverage);

        if (inaccessible > 0) {
            if (minMargin > inaccessible) {
                inaccessible = minMargin;
            }
            inaccessible += 1e15;
        }

        return inaccessible;
    }

    function _getParam(bytes32 marketKey, bytes32 value) internal view returns (uint256) {
        IFlexibleStorage flexibleStorage = IFlexibleStorage(addressResolver.getAddress("FlexibleStorage"));

        return flexibleStorage.getUIntValue("PerpsV2MarketSettings", keccak256(abi.encodePacked(marketKey, value)));
    }

    function _signedAbs(int256 x) internal pure returns (int256) {
        return x < 0 ? -x : x;
    }

    function _abs(int256 x) internal pure returns (uint256) {
        return uint256(_signedAbs(x));
    }

    function _max(int256 x, int256 y) internal pure returns (int256) {
        return x < y ? y : x;
    }

    function _sameSide(int256 a, int256 b) internal pure returns (bool) {
        return (a == 0) || (b == 0) || (a > 0) == (b > 0);
    }
}