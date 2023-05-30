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
import {wadMul, wadDiv} from "solmate/utils/SignedWadMath.sol";

interface IPerpMarket {
    struct Position {
        uint64 id;
        uint64 lastFundingIndex;
        uint128 margin;
        uint128 lastPrice;
        int128 size;
    }

    function marketKey() external view returns (bytes32 key);

    function assetPrice() external view returns (uint256 price, bool invalid);

    function fillPrice(int256 sizeDelta) external view returns (uint256 price, bool invalid);

    function positions(address account) external view returns (Position memory);

    function canLiquidate(address account) external view returns (bool);

    function accruedFunding(address account) external view returns (int256 funding, bool invalid);

    function profitLoss(address account) external view returns (int256 pnl, bool invalid);

    function orderFee(int256 sizeDelta, uint8 orderType) external view returns (uint256 fee, bool invalid);

    function marketSize() external view returns (uint128 size);

    function marketSkew() external view returns (int128 skew);

    function fundingSequenceLength() external view returns (uint256 length);

    function unrecordedFunding() external view returns (int256 funding, bool invalid);

    function fundingSequence(uint256 index) external view returns (int128 netFunding);
}

interface IPerpMarketSettings {
    function takerFeeOffchainDelayedOrder(bytes32 _marketKey) external view returns (uint256);

    function makerFeeOffchainDelayedOrder(bytes32 _marketKey) external view returns (uint256);

    function minKeeperFee() external view returns (uint256);

    function maxKeeperFee() external view returns (uint256);

    function liquidationFeeRatio() external view returns (uint256);
}

interface IFlexibleStorage {
    function getUIntValue(bytes32 contractName, bytes32 record) external view returns (uint256);
}

interface IAddressResolver {
    function getAddress(bytes32 name) external view returns (address);
}

contract Boomerang {
    using FixedPointMathLib for uint256;

    struct TradeParams {
        int256 marginDelta;
        int256 sizeDelta;
        uint256 oraclePrice;
        uint256 fillPrice;
        uint256 desiredFillPrice;
    }

    struct DataHolder {
        uint256 fee;
        uint256 keeperFee;
        int256 slot0;
        int256 slot1;
        int256 slot2;
        uint256 lMargin;
        uint256 maxMarketValue;
        uint256 latestFundingIndex;
    }

    struct PostTradeInput {
        IPerpMarket market;
        bytes32 marketKey;
    }

    enum Status {
        Ok,
        InvalidPrice,
        InvalidOrderType,
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
        PriceImpactToleranceExceeded,
        PositionFlagged,
        PositionNotFlagged
    }

    IAddressResolver private constant addressResolver = IAddressResolver(0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C);

    IPerpMarketSettings settings;

    constructor(address settings_) {
        settings = IPerpMarketSettings(settings_);
    }

    function calculate(address market_, int256 sizeDelta, int256 marginDelta, address sender)
        external
        view
        returns (uint256 margin, int256 size, uint256 price, uint256 liqPrice, uint256 fee, Status status)
    {
        PostTradeInput memory postTradeInput;
        postTradeInput.market = IPerpMarket(market_);
        postTradeInput.marketKey = postTradeInput.market.marketKey();
        TradeParams memory params;

        params.marginDelta = marginDelta;
        params.sizeDelta = sizeDelta;

        (params.oraclePrice,) = postTradeInput.market.assetPrice();
        (params.fillPrice,) = postTradeInput.market.fillPrice(sizeDelta);

        params.desiredFillPrice = params.oraclePrice;

        (IPerpMarket.Position memory newPosition, uint256 fee_, Status status_) =
            _postTradeDetails(postTradeInput.marketKey, params, postTradeInput.market, sender);

        liqPrice = _approxLiquidationPrice(newPosition, postTradeInput.market, newPosition.lastPrice);

        return (newPosition.margin, newPosition.size, newPosition.lastPrice, liqPrice, fee_, status_);
    }

    function _postTradeDetails(bytes32 marketKey, TradeParams memory params, IPerpMarket market, address sender)
        internal
        view
        returns (IPerpMarket.Position memory newPosition, uint256 fee, Status tradeStatus)
    {
        IPerpMarket.Position memory oldPos = market.positions(sender);
        DataHolder memory data;

        if (params.sizeDelta == 0) {
            return (oldPos, 0, Status.NilOrder);
        }

        if (market.canLiquidate(sender)) {
            return (oldPos, 0, Status.CanLiquidate);
        }

        (data.fee,) = market.orderFee(params.sizeDelta, 2);
        data.keeperFee = settings.minKeeperFee();

        (data.slot0,) = market.accruedFunding(sender);
        (data.slot1,) = market.profitLoss(sender);

        uint256 uMargin = uint256(oldPos.margin);

        // newMargin
        data.slot2 = int256(uMargin) + data.slot0 + data.slot1 - int256(data.fee + data.keeperFee);

        uMargin = uint256(data.slot2);

        if (data.slot2 < 0) {
            return (oldPos, 0, Status.InsufficientMargin);
        }

        data.slot0 = int256(oldPos.size);

        data.lMargin = _liquidationMargin(marketKey, data.slot0, params.oraclePrice);

        if (data.slot0 != 0 && uMargin <= data.lMargin) {
            return (oldPos, uMargin, Status.CanLiquidate);
        }

        data.slot1 = oldPos.size + params.sizeDelta;

        data.latestFundingIndex = market.fundingSequenceLength() - 1;

        IPerpMarket.Position memory newPos = IPerpMarket.Position({
            id: oldPos.id,
            lastFundingIndex: uint64(data.latestFundingIndex),
            margin: uint128(uMargin),
            lastPrice: uint128(params.fillPrice),
            size: int128(data.slot1)
        });

        bool positionDecreasing = _sameSide(oldPos.size, newPos.size) && _abs(newPos.size) < _abs(oldPos.size);

        if (!positionDecreasing) {
            // minMargin + fee <= margin is equivalent to minMargin <= margin - fee
            // except that we get a nicer error message if fee > margin, rather than arithmetic overflow.
            if (uint256(newPos.margin) + data.fee < _minInitialMargin()) {
                return (oldPos, 0, Status.InsufficientMargin);
            }
        }

        uint256 liqPremium = _liquidationPremium(marketKey, newPos.size, params.oraclePrice);
        data.lMargin = _liquidationMargin(marketKey, newPos.size, params.oraclePrice) + liqPremium;
        if (uMargin <= data.lMargin) {
            return (newPos, 0, Status.CanLiquidate);
        }

        uint256 leverage = _abs(newPos.size).mulDivDown(params.fillPrice, uMargin + data.fee + data.keeperFee);
        uint256 maxLeverage = _getParam(marketKey, "maxLeverage");

        if (maxLeverage + 1e16 < leverage) {
            return (oldPos, 0, Status.MaxLeverageExceeded);
        }

        data.maxMarketValue = _getParam(marketKey, "maxMarketValue");

        if (_orderSizeTooLarge(market, data.maxMarketValue, oldPos.size, newPos.size)) {
            return (oldPos, 0, Status.MaxMarketSizeExceeded);
        }

        return (newPos, data.fee, Status.Ok);
    }

    function _liquidationFee(int256 positionSize, uint256 price) internal view returns (uint256 lFee) {
        // uint proportionalFee = _abs(positionSize).multiplyDecimal(price).multiplyDecimal(_liquidationFeeRatio());

        uint256 liqFeeRatio = settings.liquidationFeeRatio();
        uint256 proportionalFee = _abs(positionSize).mulWadDown(price).mulWadDown(liqFeeRatio);
        uint256 maxFee = settings.maxKeeperFee();
        uint256 cappedProportionalFee = proportionalFee > maxFee ? maxFee : proportionalFee;
        uint256 minFee = settings.minKeeperFee();

        return cappedProportionalFee > minFee ? cappedProportionalFee : minFee;
    }

    function _keeperLiquidationFee() internal view returns (uint256) {
        IFlexibleStorage flexibleStorage = IFlexibleStorage(addressResolver.getAddress("FlexibleStorage"));

        return flexibleStorage.getUIntValue("PerpsV2MarketSettings", "keeperLiquidationFee");
    }

    function _liquidationMargin(bytes32 marketKey, int256 positionSize, uint256 price)
        internal
        view
        returns (uint256 lMargin)
    {
        // uint liquidationBuffer =
        //     _abs(positionSize).multiplyDecimal(price).multiplyDecimal(_liquidationBufferRatio(_marketKey()));

        uint256 liquidationBufferRatio = _getParam(marketKey, "liquidationBufferRatio");
        uint256 liquidationBuffer = _abs(positionSize).mulWadDown(price).mulWadDown(liquidationBufferRatio);

        return liquidationBuffer + _liquidationFee(positionSize, price) + _keeperLiquidationFee();
    }

    function _getParam(bytes32 marketKey, bytes32 value) internal view returns (uint256) {
        IFlexibleStorage flexibleStorage = IFlexibleStorage(addressResolver.getAddress("FlexibleStorage"));

        return flexibleStorage.getUIntValue("PerpsV2MarketSettings", keccak256(abi.encodePacked(marketKey, value)));
    }

    function _minInitialMargin() internal view returns (uint256) {
        IFlexibleStorage flexibleStorage = IFlexibleStorage(addressResolver.getAddress("FlexibleStorage"));

        return flexibleStorage.getUIntValue("PerpsV2MarketSettings", "perpsV2MinInitialMargin");
    }

    function _notionalValue(int256 positionSize, uint256 price) internal pure returns (int256 value) {
        return wadMul(positionSize, int256(price));
    }

    function _liquidationPremium(bytes32 marketKey, int256 positionSize, uint256 currentPrice)
        internal
        view
        returns (uint256)
    {
        if (positionSize == 0) {
            return 0;
        }

        uint256 notional = _abs(_notionalValue(positionSize, currentPrice));
        uint256 skewScale = _getParam(marketKey, "skewScale");
        uint256 liquidationPremiumMultiplier = _getParam(marketKey, "liquidationPremiumMultiplier");

        return _abs(positionSize).mulWadDown(notional).mulDivDown(liquidationPremiumMultiplier, skewScale);
    }

    function _orderSizeTooLarge(IPerpMarket market, uint256 maxSize, int256 oldSize, int256 newSize)
        internal
        view
        returns (bool)
    {
        // Allow users to reduce an order no matter the market conditions.
        if (_sameSide(oldSize, newSize) && _abs(newSize) <= _abs(oldSize)) {
            return false;
        }

        int256 marketSkew = market.marketSkew();
        uint256 marketSize = market.marketSize();

        int256 newSkew = marketSkew - oldSize + newSize;
        int256 newMarketSize = int256(marketSize) - (_signedAbs(oldSize)) + (_signedAbs(newSize));

        int256 newSideSize;
        if (0 < newSize) {
            // long case: marketSize + skew
            //            = (|longSize| + |shortSize|) + (longSize + shortSize)
            //            = 2 * longSize
            newSideSize = newMarketSize + (newSkew);
        } else {
            // short case: marketSize - skew
            //            = (|longSize| + |shortSize|) - (longSize + shortSize)
            //            = 2 * -shortSize
            newSideSize = newMarketSize - (newSkew);
        }

        // newSideSize still includes an extra factor of 2 here, so we will divide by 2 in the actual condition
        if (maxSize < _abs(newSideSize / 2)) {
            return true;
        }

        return false;
    }

    function _approxLiquidationPrice(IPerpMarket.Position memory position, IPerpMarket market, uint256 currentPrice)
        internal
        view
        returns (uint256)
    {
        if (position.size == 0) {
            return 0;
        }

        uint256 liqMargin = _liquidationMargin(market.marketKey(), position.size, currentPrice);
        uint256 liqPremium = _liquidationPremium(market.marketKey(), position.size, currentPrice);

        int256 midValue = int256(liqMargin) - int128(position.margin) - int256(liqPremium);
        midValue = wadDiv(midValue, position.size);

        int256 netFundingPerUnit = _netFundingPerUnit(market, position.lastFundingIndex);

        int256 result = int256(uint256(position.lastPrice)) + midValue - netFundingPerUnit;

        return uint256(_max(0, result));
    }

    function _nextFundingEntry(IPerpMarket market) internal view returns (int256) {
        (int256 unrecordedFunding,) = market.unrecordedFunding();
        uint256 latestFundingIndex = market.fundingSequenceLength() - 1;
        return market.fundingSequence(latestFundingIndex) + unrecordedFunding;
    }

    function _netFundingPerUnit(IPerpMarket market, uint256 startIndex) internal view returns (int256) {
        // Compute the net difference between start and end indices.
        return _nextFundingEntry(market) - market.fundingSequence(startIndex);
    }

    /*
     * Absolute value of the input, returned as a signed number.
     */
    function _signedAbs(int256 x) internal pure returns (int256) {
        return x < 0 ? -x : x;
    }

    /*
     * Absolute value of the input, returned as an unsigned number.
     */
    function _abs(int256 x) internal pure returns (uint256) {
        return uint256(_signedAbs(x));
    }

    function _max(int256 x, int256 y) internal pure returns (int256) {
        return x < y ? y : x;
    }

    function _min(int256 x, int256 y) internal pure returns (int256) {
        return x < y ? x : y;
    }

    /*
     * True if and only if two positions a and b are on the same side of the market; that is, if they have the same
     * sign, or either of them is zero.
     */
    function _sameSide(int256 a, int256 b) internal pure returns (bool) {
        return (a == 0) || (b == 0) || (a > 0) == (b > 0);
    }
}