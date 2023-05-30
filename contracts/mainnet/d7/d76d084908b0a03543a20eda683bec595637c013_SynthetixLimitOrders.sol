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
pragma solidity ^0.8.9;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Initializable} from "../proxy/utils/Initializable.sol";
import {AuthUpgradable, Authority} from "../libraries/AuthUpgradable.sol";
import {ReentrancyGuardUpgradable} from "../libraries/ReentracyUpgradable.sol";

import {IPyth} from "../interfaces/IPyth.sol";

interface IList {
    function accountID(address) external view returns (uint64);
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

    function assetPrice() external view returns (uint256 price, bool invalid);
}

interface IAccount {
    function cast(string[] calldata _targetNames, bytes[] calldata _datas, address _origin) external;
}

contract SynthetixLimitOrders is Initializable, AuthUpgradable, ReentrancyGuardUpgradable {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------
    using FixedPointMathLib for uint256;

    /// -----------------------------------------------------------------------
    /// Data Types
    /// -----------------------------------------------------------------------

    struct FullOrderRequest {
        int256 sizeDelta;
        uint256 priceImpactDelta;
        uint256 expiry;
        uint256 priceA;
        uint256 priceB;
        uint256 firstPairA;
        uint256 firstPairB;
        uint256 secondPairA;
        uint256 secondPairB;
    }

    struct PairOrderRequest {
        int256 sizeDelta;
        uint256 priceImpactDelta;
        uint256 expiry;
        uint256 firstPairA;
        uint256 firstPairB;
        uint256 secondPairA;
        uint256 secondPairB;
    }

    struct FullOrder {
        bool isStarted;
        bool isCompleted;
        bool isCancelled;
        address user;
        address market;
        int256 sizeDelta;
        uint256 priceImpactDelta;
        uint256 expiry;
        uint256 requestPrice;
        uint256 priceA;
        uint256 priceB;
        uint256 firstPairA;
        uint256 firstPairB;
        uint256 secondPairA;
        uint256 secondPairB;
    }

    /// -----------------------------------------------------------------------
    /// State Variables
    /// -----------------------------------------------------------------------

    /// @notice Pyth Oracle
    IPyth public pyth;

    /// @notice Address of the fee receipient
    address public feeReceipient;

    /// @notice Flat fee charged per each order, taken from margin upon execution
    uint256 public flatFee;

    /// @notice Percentage fee charged per each order (or dollar value)
    uint256 public percentageFee;

    /// @notice Next full order id
    uint256 public nextFullOrderId;

    /// @notice Time Cutoff for Pyth Price
    uint256 public pythPriceTimeCutoff;

    /// @notice Price Delta Cutoff for Pyth Price
    uint256 public pythPriceDeltaCutoff;

    /// @notice Storage gap
    uint256[50] private _gap;

    /// @notice Order id to order info mapping
    mapping(uint256 => FullOrder) private fullOrders;

    /// @notice Pyth Oracle IDs to read for each market
    mapping(address => bytes32) public pythIds;

    function initialize(IPyth _pyth, address _owner, address _feeReceipient, uint256 _flatFee, uint256 _percentageFee)
        public
        initializer
    {
        _auth_init(_owner, Authority(address(0x0)));
        _reentrancy_init();

        emit UpdateFeeReceipient(feeReceipient, _feeReceipient);
        emit UpdateFees(flatFee, _flatFee, percentageFee, _percentageFee);

        pyth = _pyth;

        feeReceipient = _feeReceipient;

        flatFee = _flatFee;
        percentageFee = _percentageFee;

        nextFullOrderId = 1;
    }

    /// -----------------------------------------------------------------------
    /// User Actions
    /// -----------------------------------------------------------------------

    function submitFullOrder(address market, FullOrderRequest memory request) external nonReentrant {
        require(isAllowed());
        require(request.expiry > block.timestamp, "invalid-expiry");

        (uint256 requestPrice, bool invalid) = IPerpMarket(market).assetPrice();
        require(!invalid && requestPrice != 0, "invalid-current-price");

        require(request.priceA != 0 && request.priceB != 0, "range-is-zero");
        require(request.priceB > request.priceA, "invalid-range");
        require(request.priceA > requestPrice || request.priceB < requestPrice, "invalid-range-for-current-price");

        FullOrder storage order = fullOrders[nextFullOrderId++];

        order.user = msg.sender;
        order.market = market;
        order.expiry = request.expiry;
        order.requestPrice = requestPrice;
        order.sizeDelta = request.sizeDelta;
        order.priceImpactDelta = request.priceImpactDelta;
        order.priceA = request.priceA;
        order.priceB = request.priceB;
        order.firstPairA = request.firstPairA;
        order.firstPairB = request.firstPairB;
        order.secondPairA = request.secondPairA;
        order.secondPairB = request.secondPairB;

        emit SubmitFullOrder(market, msg.sender, nextFullOrderId - 1, requestPrice, request);
    }

    function submitPairOrder(address market, PairOrderRequest memory request) external nonReentrant {
        require(isAllowed());
        require(request.expiry > block.timestamp, "invalid-expiry");

        (uint256 requestPrice, bool invalid) = IPerpMarket(market).assetPrice();
        require(!invalid && requestPrice != 0, "invalid-current-price");

        require(request.firstPairA != 0 && request.firstPairA != 0, "range-is-zero");
        require(request.firstPairB > request.firstPairA, "invalid-range");
        require(
            request.firstPairA > requestPrice || request.firstPairB < requestPrice, "invalid-range-for-current-price"
        );

        FullOrder storage order = fullOrders[nextFullOrderId++];

        order.user = msg.sender;
        order.market = market;
        order.expiry = request.expiry;
        order.requestPrice = requestPrice;
        order.isStarted = true;
        order.sizeDelta = -request.sizeDelta;
        order.priceImpactDelta = request.priceImpactDelta;
        order.firstPairA = request.firstPairA;
        order.firstPairB = request.firstPairB;
        order.secondPairA = request.secondPairA;
        order.secondPairB = request.secondPairB;

        emit SubmitPairOrder(market, msg.sender, nextFullOrderId - 1, requestPrice, request);
    }

    function addPairOrder(uint256 id, PairOrderRequest memory request) external nonReentrant {
        FullOrder storage order = fullOrders[id];
        require(msg.sender == order.user);
        require(!order.isCancelled, "order-already-cancelled");
        require(!order.isCompleted, "order-already-completed");
        require(request.expiry > block.timestamp, "invalid-expiry");

        (uint256 requestPrice, bool invalid) = IPerpMarket(order.market).assetPrice();
        require(!invalid && requestPrice != 0, "invalid-current-price");

        require(request.firstPairA != 0 && request.firstPairA != 0, "range-is-zero");
        require(request.firstPairB > request.firstPairA, "invalid-range");
        require(
            request.firstPairA > requestPrice || request.firstPairB < requestPrice, "invalid-range-for-current-price"
        );

        order.firstPairA = request.firstPairA;
        order.firstPairB = request.firstPairB;
        order.secondPairA = request.secondPairA;
        order.secondPairB = request.secondPairB;
        order.expiry = request.expiry;

        emit AddPairOrder(order.market, msg.sender, id, requestPrice, request);
    }

    function cancelFullOrder(uint256 orderId) external nonReentrant {
        FullOrder storage order = fullOrders[orderId];
        require(msg.sender == order.user, "unauthorized");

        order.isCancelled = true;

        emit CancelFullOrder(order.market, order.user, orderId);
    }

    function cancelPairOrder(uint256 orderId) external nonReentrant {
        FullOrder storage order = fullOrders[orderId];
        require(msg.sender == order.user, "unauthorized");

        order.isStarted = true;

        order.firstPairA = 0;
        order.firstPairB = 0;
        order.secondPairA = 0;
        order.secondPairB = 0;

        emit CancelPairOrder(order.market, order.user, orderId);
    }

    function cancelIndividualOrder(uint256 orderId, bool isFirst) external nonReentrant {
        FullOrder storage order = fullOrders[orderId];
        require(msg.sender == order.user, "unauthorized");

        if (isFirst) {
            order.firstPairA = 0;
            order.firstPairB = 0;
        } else {
            order.secondPairA = 0;
            order.secondPairB = 0;
        }

        emit CancelIndividualOrder(order.market, order.user, orderId, isFirst);
    }

    /// -----------------------------------------------------------------------
    /// Views
    /// -----------------------------------------------------------------------

    function getFullOrder(uint256 id) external view returns (FullOrder memory order) {
        order = fullOrders[id];
    }

    /// -----------------------------------------------------------------------
    /// Keeper Actions
    /// -----------------------------------------------------------------------

    function updateAndExecuteLimitOrder(bytes[] calldata updateData, uint256 orderId) external payable requiresAuth {
        pyth.updatePriceFeeds{value: msg.value}(updateData);
        executeLimitOrder(orderId);
    }

    function updateAndExecutePairOrder(bytes[] calldata updateData, uint256 orderId) external payable requiresAuth {
        pyth.updatePriceFeeds{value: msg.value}(updateData);
        executePairOrder(orderId);
    }

    function executeMultiple(uint256[] memory limitOrders, uint256[] memory pairOrders) external requiresAuth {
        for (uint256 i = 0; i < limitOrders.length; i++) {
            executeLimitOrder(limitOrders[i]);
        }

        for (uint256 i = 0; i < pairOrders.length; i++) {
            executePairOrder(pairOrders[i]);
        }
    }

    function executeLimitOrder(uint256 orderId) public nonReentrant requiresAuth {
        FullOrder storage order = fullOrders[orderId];
        require(block.timestamp <= order.expiry, "order-expired");
        require(!order.isStarted, "order-executed");
        require(!order.isCancelled, "order-cancelled");

        (bool isInRange, uint256 currentPrice,) = isInPriceRange(order, true);
        require(isInRange, "price-not-in-range");

        uint256 dollarValue = _abs(order.sizeDelta).mulWadDown(currentPrice);
        uint256 totalFees = flatFee + dollarValue.mulWadDown(percentageFee);

        string[] memory targets = new string[](3);
        bytes[] memory datas = new bytes[](3);

        targets[0] = "Synthetix-Perp-v1.3";
        datas[0] =
            abi.encodeWithSignature("removeMargin(address,uint256,uint256,uint256)", order.market, totalFees, 0, 0);

        targets[1] = "Synthetix-Perp-v1.3";
        datas[1] = abi.encodeWithSignature(
            "trade(address,int256,uint256)", order.market, order.sizeDelta, order.priceImpactDelta
        );

        targets[2] = "Basic-v1";
        datas[2] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,uint256,uint256)",
            0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9,
            totalFees,
            feeReceipient,
            0,
            0
        );

        IAccount(order.user).cast(targets, datas, address(0x0));

        order.isStarted = true;

        emit ExecuteLimitOrder(order.market, order.user, orderId, currentPrice, totalFees);
    }

    function executePairOrder(uint256 orderId) public nonReentrant requiresAuth {
        FullOrder storage order = fullOrders[orderId];
        require(block.timestamp <= order.expiry, "order-expired");
        require(order.isStarted, "limit-order-not-executed-yet");
        require(!order.isCompleted, "pair-order-already-executed");
        require(!order.isCancelled, "order-cancelled");

        (bool isInRange, uint256 currentPrice, bool isInFirstRange) = isInPriceRange(order, false);
        require(isInRange, "price-not-in-range");

        IPerpMarket.Position memory position = IPerpMarket(order.market).positions(order.user);

        if (_abs(order.sizeDelta) > _abs(position.size)) {
            order.sizeDelta = position.size;
        }

        if (order.firstPairA > 0 && order.firstPairB > 0 && isInFirstRange) {
            _executePairOrder(order, orderId, currentPrice);

            return;
        }

        if (order.secondPairA > 0 && order.secondPairB > 0 && !isInFirstRange) {
            _executePairOrder(order, orderId, currentPrice);

            return;
        }
    }

    function _executePairOrder(FullOrder memory order, uint256 orderId, uint256 currentPrice) internal {
        uint256 dollarValue = _abs(order.sizeDelta).mulWadDown(currentPrice);
        uint256 totalFees = flatFee + dollarValue.mulWadDown(percentageFee);

        string[] memory targets = new string[](3);
        bytes[] memory datas = new bytes[](3);

        targets[0] = "Synthetix-Perp-v1.3";
        datas[0] =
            abi.encodeWithSignature("removeMargin(address,uint256,uint256,uint256)", order.market, totalFees, 0, 0);

        targets[1] = "Synthetix-Perp-v1.3";
        datas[1] = abi.encodeWithSignature(
            "trade(address,int256,uint256)", order.market, -order.sizeDelta, order.priceImpactDelta
        );

        targets[2] = "Basic-v1";
        datas[2] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,uint256,uint256)",
            0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9,
            totalFees,
            feeReceipient,
            0,
            0
        );

        IAccount(order.user).cast(targets, datas, address(0x0));

        order.isCompleted = true;

        emit ExecutePairOrder(order.market, order.user, orderId, currentPrice, totalFees);
    }

    receive() external payable {
        (bool success,) = feeReceipient.call{value: msg.value}("");
        require(success);

        emit ReceiveEther(msg.sender, msg.value);
    }

    /// -----------------------------------------------------------------------
    /// Internals
    /// -----------------------------------------------------------------------

    /// @notice Returns whether an order can be executed or not based on current price
    /// @param order Order struct
    /// @param isFirst Whether the request is for the first order or pair order
    function isInPriceRange(FullOrder memory order, bool isFirst) internal view returns (bool, uint256, bool) {
        (uint256 currentPrice, bool invalid) = IPerpMarket(order.market).assetPrice();
        if (currentPrice == 0 || invalid) return (false, currentPrice, false);

        bytes32 pythId = pythIds[order.market];
        IPyth.Price memory pythPrice = pyth.getPriceUnsafe(pythId);
        uint256 actualPythPrice = _getWadPrice(pythPrice.price, pythPrice.expo);
        uint256 priceDelta = actualPythPrice > currentPrice
            ? (actualPythPrice - currentPrice).divWadDown(currentPrice)
            : (currentPrice - actualPythPrice).divWadDown(actualPythPrice);

        bool isPythPriceStale = pythPrice.price <= 0 || block.timestamp - pythPrice.publishTime > pythPriceTimeCutoff
            || priceDelta > pythPriceDeltaCutoff;

        if (isFirst) {
            if (order.priceA >= currentPrice && order.priceB <= currentPrice) {
                return (true, currentPrice, false);
            }

            if (!isPythPriceStale && order.priceA >= actualPythPrice && order.priceB <= actualPythPrice) {
                return (true, actualPythPrice, false);
            }
        } else {
            bool isInFirstRange = currentPrice >= order.firstPairA && currentPrice <= order.firstPairB;
            bool isInSecondRange = currentPrice >= order.secondPairA && currentPrice <= order.secondPairB;

            if (isInFirstRange || isInSecondRange) {
                return (true, currentPrice, isInFirstRange);
            }

            isInFirstRange = actualPythPrice >= order.firstPairA && actualPythPrice <= order.firstPairB;
            isInSecondRange = actualPythPrice >= order.secondPairA && actualPythPrice <= order.secondPairB;

            if (!isPythPriceStale && (isInFirstRange || isInSecondRange)) {
                return (true, actualPythPrice, isInFirstRange);
            }
        }

        return (false, currentPrice, false);
    }

    /// @notice Returns whether an address is a SCW or not
    function isAllowed() internal view returns (bool) {
        return IList(0xd567E18FDF8aFa58953DD8B0c1b6C97adF67566B).accountID(msg.sender) != 0;
    }

    function _signedAbs(int256 x) internal pure returns (int256) {
        return x < 0 ? -x : x;
    }

    function _abs(int256 x) internal pure returns (uint256) {
        return uint256(_signedAbs(x));
    }

    function _getWadPrice(int64 price, int32 expo) internal pure returns (uint256 wadPrice) {
        uint256 exponent = _abs(expo);
        uint256 lastPrice = _abs(price);

        if (exponent >= 18) {
            uint256 denom = 10 ** (exponent - 18);
            wadPrice = lastPrice / denom;
        } else {
            uint256 multiplier = 10 ** (18 - exponent);
            wadPrice = lastPrice * multiplier;
        }
    }

    /// -----------------------------------------------------------------------
    /// Admin Actions
    /// -----------------------------------------------------------------------

    function updateFeeReceipient(address _feeReceipient) external requiresAuth {
        emit UpdateFeeReceipient(feeReceipient, _feeReceipient);

        feeReceipient = _feeReceipient;
    }

    /// @notice Update fee
    /// @param _flatFee New flat fee rate
    /// @param _percentageFee New percentage fee rate
    function updateFees(uint256 _flatFee, uint256 _percentageFee) external requiresAuth {
        emit UpdateFees(flatFee, _flatFee, percentageFee, _percentageFee);

        flatFee = _flatFee;
        percentageFee = _percentageFee;
    }

    /// @notice Update Pyth Oracle ID
    /// @param market Address of the market
    /// @param id New Pyth Oracle ID
    function updatePythOracleId(address market, bytes32 id) external requiresAuth {
        emit UpdatePythId(market, pythIds[market], id);

        pythIds[market] = id;
    }

    /// @notice Update Pyth Oracle IDs
    /// @param markets Market addresses
    /// @param ids Pyth Oracle IDs
    function updatePythOracleIds(address[] memory markets, bytes32[] memory ids) external requiresAuth {
        require(markets.length == ids.length);
        for (uint256 i = 0; i < markets.length; i++) {
            emit UpdatePythId(markets[i], pythIds[markets[i]], ids[i]);

            pythIds[markets[i]] = ids[i];
        }
    }

    /// @notice Update Pyth Time Cutoff
    /// @param newCutoff New cutoff
    function updatePythTimeCutoff(uint256 newCutoff) external requiresAuth {
        emit UpdatePythTimeCutoff(pythPriceTimeCutoff, newCutoff);

        pythPriceTimeCutoff = newCutoff;
    }

    function updatePythDeltaCutoff(uint256 newCutoff) external requiresAuth {
        emit UpdatePythDeltaCutoff(pythPriceDeltaCutoff, newCutoff);

        pythPriceDeltaCutoff = newCutoff;
    }

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @notice Emitted when fee receipient is updated
    /// @param oldReceipient Old Fee Receipient
    /// @param newReceipient New Fee Receipient
    event UpdateFeeReceipient(address oldReceipient, address newReceipient);

    /// @notice Emitted when fees are updated
    /// @param oldFlat Old flat fee rate
    /// @param newFlat New flat fee rate
    /// @param oldPercentage Old percentage fee rate
    /// @param newPercentage New percentage fee rate
    event UpdateFees(uint256 oldFlat, uint256 newFlat, uint256 oldPercentage, uint256 newPercentage);

    /// @notice Emitted when Pyth oracle IDs are updated
    /// @param market Address of the market
    /// @param oldId Old Pyth Oracle ID
    /// @param newId New Pyth Oracle ID
    event UpdatePythId(address indexed market, bytes32 oldId, bytes32 newId);

    /// @notice Emitted when Pyth price time cutoff is updated
    /// @param oldCutoff Old cutoff
    /// @param newCutoff New cutoff
    event UpdatePythTimeCutoff(uint256 oldCutoff, uint256 newCutoff);

    /// @notice Emitted when Pyth price delta cutoff is updated
    /// @param oldCutoff Old Cutoff
    /// @param newCutoff New Cutoff
    event UpdatePythDeltaCutoff(uint256 oldCutoff, uint256 newCutoff);

    /// @notice Emitted when an order is submitted
    /// @param market Address of the perp market
    /// @param user Address of the user
    /// @param orderId Order ID
    /// @param requestPrice Price of the asset at the time of request
    /// @param request Request Params
    event SubmitFullOrder(
        address indexed market, address indexed user, uint256 orderId, uint256 requestPrice, FullOrderRequest request
    );

    /// @notice Emitted when an order is submitted
    /// @param market Address of the perp market
    /// @param user Address of the user
    /// @param orderId Order ID
    /// @param requestPrice Price of the asset at the time of request
    /// @param request Request Params
    event SubmitPairOrder(
        address indexed market, address indexed user, uint256 orderId, uint256 requestPrice, PairOrderRequest request
    );

    /// @notice Emitted when an pair order is added to an existing full order
    /// @param market Address of the perp market
    /// @param user Address of the user
    /// @param orderId Order ID
    /// @param requestPrice Price of the asset at the time of request
    /// @param request Request Params
    event AddPairOrder(
        address indexed market, address indexed user, uint256 orderId, uint256 requestPrice, PairOrderRequest request
    );

    /// @notice Emitted when an order request is cancelled
    /// @param market Address of the perp v2 market
    /// @param user Address of the user
    /// @param orderId Order ID
    event CancelFullOrder(address indexed market, address indexed user, uint256 orderId);

    /// @notice Emitted when a pair order request is cancelled
    /// @param market Address of the perp v2 market
    /// @param user Address of the user
    /// @param orderId Order ID
    event CancelPairOrder(address indexed market, address indexed user, uint256 orderId);

    /// @notice Emitted when an individual order from paid order request is cancelled
    /// @param market Address of the perp v2 market
    /// @param user Address of the user
    /// @param orderId Order ID
    /// @param isFirst Whether the individual order is the first one or second
    event CancelIndividualOrder(address indexed market, address indexed user, uint256 orderId, bool isFirst);

    /// @notice Emitted when a limit order is executed
    /// @param market Address of the perp v2 market
    /// @param user Address of the user
    /// @param orderId Order id
    /// @param executionPrice Price at the time of execution
    /// @param totalFee Total fee deducted from margin
    event ExecuteLimitOrder(
        address indexed market, address indexed user, uint256 orderId, uint256 executionPrice, uint256 totalFee
    );

    /// @notice Emitted when the pair order is executed
    /// @param market Address of the perp v2 market
    /// @param user Address of the user
    /// @param orderId Order id
    /// @param executionPrice Price at the time of execution
    /// @param totalFee Total fee deducted from margin
    event ExecutePairOrder(
        address indexed market, address indexed user, uint256 orderId, uint256 executionPrice, uint256 totalFee
    );

    /// @notice Emitted when ether is received
    event ReceiveEther(address indexed from, uint256 amt);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IPyth {
    struct Price {
        // Price
        int64 price;
        // Confidence interval around the price
        uint64 conf;
        // Price exponent
        int32 expo;
        // Unix timestamp describing when the price was published
        uint256 publishTime;
    }

    function getPriceUnsafe(bytes32 id) external view returns (Price memory price);

    function updatePriceFeeds(bytes[] calldata updateData) external payable;
}

// SPDX-License-Identifier: AGPL-3.0-only
// Source - https://github.com/transmissions11/solmate/blob/main/src/auth/Auth.sol

pragma solidity >=0.8.0;

import {Initializable} from "../proxy/utils/Initializable.sol";

/// @notice Provides a flexible and updatable auth pattern which is completely separate from application logic.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
abstract contract AuthUpgradable is Initializable {
    event OwnershipTransferred(address indexed user, address indexed newOwner);

    event AuthorityUpdated(address indexed user, Authority indexed newAuthority);

    address public owner;

    Authority public authority;

    function _auth_init(address _owner, Authority _authority) internal onlyInitializing {
        owner = _owner;
        authority = _authority;

        emit OwnershipTransferred(msg.sender, _owner);
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

    function transferOwnership(address newOwner) public virtual requiresAuth {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}

/// @notice A generic interface for a contract which provides authorization data to an Auth instance.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
interface Authority {
    function canCall(address user, address target, bytes4 functionSig) external view returns (bool);
}

// SPDX-License-Identifier: AGPL-3.0-only
// Source - https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol

pragma solidity >=0.8.0;

import {Initializable} from "../proxy/utils/Initializable.sol";

/// @notice Gas optimized reentrancy protection for smart contracts.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol)
abstract contract ReentrancyGuardUpgradable is Initializable {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private locked;

    function _reentrancy_init() internal onlyInitializing {
        locked = _NOT_ENTERED;
    }

    modifier nonReentrant() virtual {
        require(locked == _NOT_ENTERED, "REENTRANCY");

        locked = 2;

        _;

        locked = 1;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
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
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success,) = recipient.call{value: amount}("");
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage)
        internal
        returns (bytes memory)
    {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage)
        internal
        returns (bytes memory)
    {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage)
        internal
        view
        returns (bytes memory)
    {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage)
        internal
        returns (bytes memory)
    {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(bool success, bytes memory returndata, string memory errorMessage)
        internal
        pure
        returns (bytes memory)
    {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.9;

import "./Address.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!Address.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized != type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}