/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-28
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


// File contracts/libraries/FullMath.sol

// -License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @notice Source - https://github.com/sushiswap/StakingContract/blob/master/src/libraries/FullMath.sol
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
/// @dev Adapted to pragma solidity 0.8 from https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/FullMath.sol
library FullMath {
    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = a * b
            // Compute the product mod 2**256 and mod 2**256 - 1
            // then use the Chinese Remainder Theorem to reconstruct
            // the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2**256 + prod0
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(a, b, not(0))
                prod0 := mul(a, b)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division
            if (prod1 == 0) {
                require(denominator > 0);
                assembly {
                    result := div(prod0, denominator)
                }
                return result;
            }

            // Make sure the result is less than 2**256.
            // Also prevents denominator == 0
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0]
            // Compute remainder using mulmod
            uint256 remainder;
            assembly {
                remainder := mulmod(a, b, denominator)
            }
            // Subtract 256 bit number from 512 bit number
            assembly {
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator
            // Compute largest power of two divisor of denominator.
            // Always >= 1.
            uint256 twos = (0 - denominator) & denominator;
            // Divide denominator by power of two
            assembly {
                denominator := div(denominator, twos)
            }

            // Divide [prod1 prod0] by the factors of two
            assembly {
                prod0 := div(prod0, twos)
            }
            // Shift in bits from prod1 into prod0. For this we need
            // to flip `twos` such that it is 2**256 / twos.
            // If twos is zero, then it becomes one
            assembly {
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;

            // Invert denominator mod 2**256
            // Now that denominator is an odd number, it has an inverse
            // modulo 2**256 such that denominator * inv = 1 mod 2**256.
            // Compute the inverse by starting with a seed that is correct
            // correct for four bits. That is, denominator * inv = 1 mod 2**4
            uint256 inv = (3 * denominator) ^ 2;
            // Now use Newton-Raphson iteration to improve the precision.
            // Thanks to Hensel's lifting lemma, this also works in modular
            // arithmetic, doubling the correct bits in each step.
            inv *= 2 - denominator * inv; // inverse mod 2**8
            inv *= 2 - denominator * inv; // inverse mod 2**16
            inv *= 2 - denominator * inv; // inverse mod 2**32
            inv *= 2 - denominator * inv; // inverse mod 2**64
            inv *= 2 - denominator * inv; // inverse mod 2**128
            inv *= 2 - denominator * inv; // inverse mod 2**256

            // Because the division is now exact we can divide by multiplying
            // with the modular inverse of denominator. This will give us the
            // correct result modulo 2**256. Since the precoditions guarantee
            // that the outcome is less than 2**256, this is the final result.
            // We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inv;
            return result;
        }
    }

    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }
}


// File contracts/Resolver.sol

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;



interface IPolynomialVaultToken {
    function balanceOf(address user) external view returns (uint256);
}

interface IPolynomialVault {
    function VAULT_TOKEN() external view returns (IPolynomialVaultToken);

    function getTokenPrice() external view returns (uint256);
}

interface IPolynomialCallSelling {
    struct PositionData {
        uint256 positionId;
        uint256 amount;
        uint256 collateral;
        int256 premiumCollected;
    }

    function getLiveStrikes() external view returns (uint256[] memory strikes);

    function positionDatas(uint256 strikeId)
        external
        view
        returns (PositionData memory data);
}

interface IPolynomialPutSelling is IPolynomialCallSelling {}

interface IBasisTrading {
    function positionSize() external view returns (uint256);
}

interface IGamma {
    struct PositionData {
        uint256 strikeId;
        uint256 positionId;
        uint256 optionAmount;
        uint256 premiumPaid;
        uint256 shortAmount;
        uint256 totalMargin;
    }

    function positionData() external view returns (PositionData memory);
}

interface IOptionMarket {
    struct Strike {
        // strike listing identifier
        uint256 id;
        // strike price
        uint256 strikePrice;
        // volatility component specific to the strike listing (boardIv * skew = vol of strike)
        uint256 skew;
        // total user long call exposure
        uint256 longCall;
        // total user short call (base collateral) exposure
        uint256 shortCallBase;
        // total user short call (quote collateral) exposure
        uint256 shortCallQuote;
        // total user long put exposure
        uint256 longPut;
        // total user short put (quote collateral) exposure
        uint256 shortPut;
        // id of board to which strike belongs
        uint256 boardId;
    }

    struct OptionBoard {
        // board identifier
        uint256 id;
        // expiry of all strikes belonging to board
        uint256 expiry;
        // volatility component specific to board (boardIv * skew = vol of strike)
        uint256 iv;
        // admin settable flag blocking all trading on this board
        bool frozen;
        // list of all strikes belonging to this board
        uint256[] strikeIds;
    }

    function getStrikeAndBoard(uint256 strikeId)
        external
        view
        returns (Strike memory, OptionBoard memory);
}

interface IExchangeRates {
    function rateAndInvalid(bytes32 currencyKey)
        external
        view
        returns (uint256 rate, bool isInvalid);
}

interface IOptionGreeksCache {
    struct GreekCacheParameters {
        // Cap the number of strikes per board to avoid hitting gasLimit constraints
        uint256 maxStrikesPerBoard;
        // How much spot price can move since last update before deposits/withdrawals are blocked
        uint256 acceptableSpotPricePercentMove;
        // How much time has passed since last update before deposits/withdrawals are blocked
        uint256 staleUpdateDuration;
        // Length of the GWAV for the baseline volatility used to fire the vol circuit breaker
        uint256 varianceIvGWAVPeriod;
        // Length of the GWAV for the skew ratios used to fire the vol circuit breaker
        uint256 varianceSkewGWAVPeriod;
        // Length of the GWAV for the baseline used to determine the NAV of the pool
        uint256 optionValueIvGWAVPeriod;
        // Length of the GWAV for the skews used to determine the NAV of the pool
        uint256 optionValueSkewGWAVPeriod;
        // Minimum skew that will be fed into the GWAV calculation
        // Prevents near 0 values being used to heavily manipulate the GWAV
        uint256 gwavSkewFloor;
        // Maximum skew that will be fed into the GWAV calculation
        uint256 gwavSkewCap;
        // Interest/risk free rate
        int256 rateAndCarry;
    }

    function getGreekCacheParams()
        external
        view
        returns (GreekCacheParameters memory);
}

interface IFuturesMarket {
    function remainingMargin(address user)
        external
        view
        returns (uint256 margin, bool invalid);
}

interface IIncentiveDistributor {
    struct Incentive {
        address creator; // 1st slot
        address token; // 2nd slot
        address rewardToken; // 3rd slot
        uint32 endTime; // 3rd slot
        uint256 rewardPerLiquidity; // 4th slot
        uint32 lastRewardTime; // 5th slot
        uint112 rewardRemaining; // 5th slot
        uint112 liquidityStaked; // 5th slot
    }

    struct UserStake {
        uint112 liquidity;
        uint144 subscribedIncentiveIds; // Six packed uint24 values.
    }

    function incentives(uint256 id) external view returns (Incentive memory);

    function rewardPerLiquidityLast(address user, uint256 id)
        external
        view
        returns (uint256);

    function userStakes(address user, address vaultToken)
        external
        view
        returns (uint112 liquidity, uint144 subscribedIncentiveIds);
}

contract PolynomialEarnResolver is Auth {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------
    using FixedPointMathLib for uint256;

    /// -----------------------------------------------------------------------
    /// Data Structures
    /// -----------------------------------------------------------------------
    struct FuturesData {
        uint256 spotPrice;
        uint256 shortPosition;
        uint256 margin;
        uint256 leverage;
    }

    struct OptionData {
        uint256 strikeId;
        uint256 strikePrice;
        uint256 expiry;
        uint256 positionId;
        uint256 optionAmount;
        uint256 premiumPaid;
        int256 premiumCollected;
        uint256 collateral;
        int256 currentOptionDelta;
        uint256 currentOptionPrice;
    }

    struct MinimalStrike {
        uint256 strikeId;
        uint256 expiry;
        uint256 strikePrice;
    }

    enum VaultType {
        NONE,
        CALL_SELLING,
        PUT_SELLING,
        GAMMA,
        BASIS_TRADING
    }

    mapping(address => VaultType) public isVault;

    IOptionMarket public immutable MARKET;
    IExchangeRates public immutable RATES;
    IOptionGreeksCache public immutable GREEKS;
    IFuturesMarket public immutable FUTURES_MARKET;
    IIncentiveDistributor public immutable INCENTIVES;

    constructor(
        IOptionMarket market,
        IExchangeRates rates,
        IOptionGreeksCache greeks,
        IFuturesMarket futuresMarket,
        IIncentiveDistributor incentives
    ) Auth(msg.sender, Authority(address(0x0))) {
        MARKET = market;
        RATES = rates;
        GREEKS = greeks;
        FUTURES_MARKET = futuresMarket;
        INCENTIVES = incentives;
    }

    function getVaultPositions(address vault)
        public
        view
        returns (
            FuturesData memory futurePosition,
            OptionData[] memory optionData
        )
    {
        if (isVault[vault] == VaultType.NONE) {
            return (futurePosition, optionData);
        } else if (isVault[vault] == VaultType.CALL_SELLING) {
            IPolynomialCallSelling polyVault = IPolynomialCallSelling(vault);

            uint256[] memory strikes = polyVault.getLiveStrikes();
            if (strikes.length > 0) {
                optionData = new OptionData[](strikes.length);
            }

            for (uint256 i = 0; i < strikes.length; i++) {
                IPolynomialCallSelling.PositionData memory data = polyVault
                    .positionDatas(strikes[i]);

                optionData[i].strikeId = strikes[i];
                optionData[i].positionId = data.positionId;
                optionData[i].optionAmount = data.amount;
                optionData[i].premiumCollected = data.premiumCollected;
                optionData[i].collateral = data.collateral;
                (
                    optionData[i].currentOptionDelta,
                    ,
                    optionData[i].strikePrice,
                    optionData[i].expiry
                ) = getDelta(strikes[i]);
                (optionData[i].currentOptionPrice, , ) = getPremium(strikes[i]);
            }
            return (futurePosition, optionData);
        } else if (isVault[vault] == VaultType.PUT_SELLING) {
            IPolynomialPutSelling polyVault = IPolynomialPutSelling(vault);

            uint256[] memory strikes = polyVault.getLiveStrikes();
            if (strikes.length > 0) {
                optionData = new OptionData[](strikes.length);
            }

            for (uint256 i = 0; i < strikes.length; i++) {
                IPolynomialCallSelling.PositionData memory data = polyVault
                    .positionDatas(strikes[i]);

                optionData[i].strikeId = strikes[i];
                optionData[i].positionId = data.positionId;
                optionData[i].optionAmount = data.amount;
                optionData[i].premiumCollected = data.premiumCollected;
                optionData[i].collateral = data.collateral;
                (
                    ,
                    optionData[i].currentOptionDelta,
                    optionData[i].strikePrice,
                    optionData[i].expiry
                ) = getDelta(strikes[i]);
                (, optionData[i].currentOptionPrice, ) = getPremium(strikes[i]);
            }
            return (futurePosition, optionData);
        } else if (isVault[vault] == VaultType.BASIS_TRADING) {
            IBasisTrading polyVault = IBasisTrading(vault);

            (futurePosition.spotPrice, ) = RATES.rateAndInvalid("sETH");
            futurePosition.shortPosition = polyVault.positionSize();
            (futurePosition.margin, ) = FUTURES_MARKET.remainingMargin(vault);
            futurePosition.leverage = futurePosition.shortPosition.mulDivDown(
                futurePosition.spotPrice,
                futurePosition.margin
            );
            return (futurePosition, optionData);
        } else if (isVault[vault] == VaultType.GAMMA) {
            IGamma polyVault = IGamma(vault);

            IGamma.PositionData memory positionData = polyVault.positionData();

            (futurePosition.spotPrice, ) = RATES.rateAndInvalid("sETH");
            futurePosition.shortPosition = positionData.shortAmount;
            (futurePosition.margin, ) = FUTURES_MARKET.remainingMargin(vault);
            futurePosition.leverage = futurePosition.shortPosition.mulDivDown(
                futurePosition.spotPrice,
                futurePosition.margin
            );

            optionData = new OptionData[](1);

            optionData[0].strikeId = positionData.strikeId;
            optionData[0].positionId = positionData.positionId;
            optionData[0].optionAmount = positionData.optionAmount;
            optionData[0].premiumPaid = positionData.premiumPaid;
            (
                optionData[0].currentOptionDelta,
                ,
                optionData[0].strikePrice,
                optionData[0].expiry
            ) = getDelta(positionData.strikeId);
            (optionData[0].currentOptionPrice, , ) = getPremium(
                positionData.strikeId
            );
            return (futurePosition, optionData);
        }
    }

    function getUserPositions(address user, address[] memory vaults)
        public
        view
        returns (
            uint256[] memory balances,
            uint256[] memory underlyings,
            uint256[] memory stakedBalances,
            uint256[] memory stakedUnderlyings
        )
    {
        balances = new uint256[](vaults.length);
        underlyings = new uint256[](vaults.length);
        stakedBalances = new uint256[](vaults.length);
        stakedUnderlyings = new uint256[](vaults.length);

        for (uint256 i = 0; i < vaults.length; i++) {
            IPolynomialVault vault = IPolynomialVault(vaults[i]);
            IPolynomialVaultToken vaultToken = vault.VAULT_TOKEN();
            balances[i] = vaultToken.balanceOf(user);

            (uint112 stakedBalance, ) = INCENTIVES.userStakes(
                user,
                address(vaultToken)
            );
            stakedBalances[i] = stakedBalance;

            uint256 tokenPrice = vault.getTokenPrice();
            underlyings[i] = balances[i].mulWadDown(tokenPrice);
            stakedUnderlyings[i] = stakedBalances[i].mulWadDown(tokenPrice);
        }
    }

    function addVault(address vault, VaultType vaultType) public requiresAuth {
        isVault[vault] = vaultType;
    }

    function getDelta(uint256 strikeId)
        internal
        view
        returns (
            int256 callDelta,
            int256 putDelta,
            uint256 strikePrice,
            uint256 expiry
        )
    {
        if (strikeId == 0) {
            return (0, 0, 0, 0);
        }
        (
            IOptionMarket.Strike memory strike,
            IOptionMarket.OptionBoard memory board
        ) = MARKET.getStrikeAndBoard(strikeId);

        (uint256 spotPrice, bool isInvalid) = RATES.rateAndInvalid("sETH");

        if (spotPrice == 0 || isInvalid) {
            revert();
        }

        if (block.timestamp > board.expiry) {
            callDelta = 0;
            putDelta = 0;
        } else {
            BlackScholesLib.BlackScholesInputs memory bsInput = BlackScholesLib
                .BlackScholesInputs({
                    timeToExpirySec: board.expiry - block.timestamp,
                    volatilityDecimal: board.iv.mulWadDown(strike.skew),
                    spotDecimal: spotPrice,
                    strikePriceDecimal: strike.strikePrice,
                    rateDecimal: GREEKS.getGreekCacheParams().rateAndCarry
                });

            (callDelta, putDelta) = BlackScholesLib.delta(bsInput);
        }

        strikePrice = strike.strikePrice;
        expiry = board.expiry;
    }

    function getDeltaWithSpotPrice(uint256 spotPrice, uint256 strikeId)
        public
        view
        returns (int256 callDelta, int256 putDelta)
    {
        (
            IOptionMarket.Strike memory strike,
            IOptionMarket.OptionBoard memory board
        ) = MARKET.getStrikeAndBoard(strikeId);

        if (block.timestamp > board.expiry) {
            callDelta = 0;
            putDelta = 0;
        } else {
            BlackScholesLib.BlackScholesInputs memory bsInput = BlackScholesLib
                .BlackScholesInputs({
                    timeToExpirySec: board.expiry - block.timestamp,
                    volatilityDecimal: board.iv.mulWadDown(strike.skew),
                    spotDecimal: spotPrice,
                    strikePriceDecimal: strike.strikePrice,
                    rateDecimal: GREEKS.getGreekCacheParams().rateAndCarry
                });

            (callDelta, putDelta) = BlackScholesLib.delta(bsInput);
        }
    }

    function getDeltas(uint256[] memory strikeIds)
        public
        view
        returns (int256[] memory callDeltas, int256[] memory putDeltas)
    {
        callDeltas = new int256[](strikeIds.length);
        putDeltas = new int256[](strikeIds.length);

        (uint256 spotPrice, bool isInvalid) = RATES.rateAndInvalid("sETH");

        if (spotPrice == 0 || isInvalid) {
            revert();
        }

        for (uint256 i = 0; i < strikeIds.length; i++) {
            (callDeltas[i], putDeltas[i]) = getDeltaWithSpotPrice(
                spotPrice,
                strikeIds[i]
            );
        }
    }

    function getStrikeDetails(uint256[] memory strikeIds)
        public
        view
        returns (MinimalStrike[] memory strikes)
    {
        strikes = new MinimalStrike[](strikeIds.length);

        for (uint256 i = 0; i < strikeIds.length; i++) {
            (
                IOptionMarket.Strike memory strike,
                IOptionMarket.OptionBoard memory board
            ) = MARKET.getStrikeAndBoard(strikeIds[i]);
            strikes[i] = MinimalStrike({
                strikeId: strikeIds[i],
                expiry: board.expiry,
                strikePrice: strike.strikePrice
            });
        }
    }

    function getPremium(uint256 strikeId)
        public
        view
        returns (
            uint256 callPremium,
            uint256 putPremium,
            uint256 underlyingPrice
        )
    {
        if (strikeId == 0) {
            return (0, 0, 0);
        }
        (
            IOptionMarket.Strike memory strike,
            IOptionMarket.OptionBoard memory board
        ) = MARKET.getStrikeAndBoard(strikeId);

        (uint256 spotPrice, bool isInvalid) = RATES.rateAndInvalid("sETH");

        if (spotPrice == 0 || isInvalid) {
            revert();
        }

        BlackScholesLib.BlackScholesInputs memory bsInput = BlackScholesLib
            .BlackScholesInputs({
                timeToExpirySec: board.expiry - block.timestamp,
                volatilityDecimal: board.iv.mulWadDown(strike.skew),
                spotDecimal: spotPrice,
                strikePriceDecimal: strike.strikePrice,
                rateDecimal: GREEKS.getGreekCacheParams().rateAndCarry
            });

        (callPremium, putPremium) = BlackScholesLib.optionPrices(bsInput);
        underlyingPrice = spotPrice;
    }

    function getIncentiveApy(
        uint256[] memory ids,
        address[] memory vaults,
        bytes32[] memory currencies
    )
        external
        view
        returns (uint256[] memory rates, uint256[] memory timeUnits)
    {
        assert(ids.length == vaults.length);
        assert(ids.length == currencies.length);

        rates = new uint256[](ids.length);
        timeUnits = new uint256[](ids.length);

        uint256 timeNow = block.timestamp;
        uint256 oneYear = 31556952;

        (uint256 opPrice, ) = RATES.rateAndInvalid("OP");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];

            IIncentiveDistributor.Incentive memory incentive = accrueIncentive(
                id
            );

            (uint256 depositTokenPrice, ) = RATES.rateAndInvalid(currencies[i]);

            uint256 tokenPrice = IPolynomialVault(vaults[i]).getTokenPrice();

            uint256 totalPendingOpInUsd = opPrice.mulWadDown(
                incentive.rewardRemaining
            );
            uint256 totalUsdStaked = depositTokenPrice.mulWadDown(tokenPrice);
            totalUsdStaked = totalUsdStaked.mulWadDown(
                incentive.liquidityStaked
            );

            if (totalUsdStaked == 0 || totalPendingOpInUsd == 0) {
                rates[i] = 0;
                timeUnits[i] = 0;

                continue;
            }

            uint256 rate = totalPendingOpInUsd.divWadDown(totalUsdStaked);
            uint256 units = oneYear.divWadDown(
                (uint256(incentive.endTime) - timeNow)
            );

            rates[i] = rate;
            timeUnits[i] = units;
        }
    }

    function pendingRewards(address user, uint256[] memory ids)
        external
        view
        returns (uint256[] memory rewards)
    {
        rewards = new uint256[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];

            IIncentiveDistributor.Incentive memory incentive = accrueIncentive(
                id
            );

            (uint112 liquidity, ) = INCENTIVES.userStakes(
                user,
                incentive.token
            );

            if (liquidity == 0) {
                rewards[i] = 0;
                continue;
            }

            uint256 userRewardPerLiquidtyLast = INCENTIVES
                .rewardPerLiquidityLast(user, id);

            if (userRewardPerLiquidtyLast == 0) {
                rewards[i] = 0;
                continue;
            }

            uint256 rewardPerLiquidityDelta;

            unchecked {
                rewardPerLiquidityDelta =
                    incentive.rewardPerLiquidity -
                    userRewardPerLiquidtyLast;
            }
            rewards[i] = FullMath.mulDiv(
                rewardPerLiquidityDelta,
                liquidity,
                type(uint112).max
            );
        }
    }

    function accrueIncentive(uint256 id)
        internal
        view
        returns (IIncentiveDistributor.Incentive memory incentive)
    {
        incentive = INCENTIVES.incentives(id);

        uint256 lastRewardTime = incentive.lastRewardTime;

        uint256 endTime = incentive.endTime;

        unchecked {
            uint256 maxTime = block.timestamp < endTime
                ? block.timestamp
                : endTime;

            if (incentive.liquidityStaked > 0 && lastRewardTime < maxTime) {
                uint256 totalTime = endTime - lastRewardTime;
                uint256 passedTime = maxTime - lastRewardTime;
                uint256 reward = (uint256(incentive.rewardRemaining) *
                    passedTime) / totalTime;

                // Increments of less than type(uint224).max - overflow is unrealistic.
                incentive.rewardPerLiquidity +=
                    (reward * type(uint112).max) /
                    incentive.liquidityStaked;
                incentive.rewardRemaining -= uint112(reward);
                incentive.lastRewardTime = uint32(maxTime);
            } else if (
                incentive.liquidityStaked == 0 &&
                lastRewardTime < block.timestamp
            ) {
                incentive.lastRewardTime = uint32(maxTime);
            }
        }
    }
}