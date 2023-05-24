/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-12
*/

// Sources flattened with hardhat v2.14.0 https://hardhat.org

// File @openzeppelin/contracts/utils/[email protected]

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
  function _msgSender() internal view virtual returns (address) {
    return msg.sender;
  }

  function _msgData() internal view virtual returns (bytes calldata) {
    return msg.data;
  }
}

// File @openzeppelin/contracts/access/[email protected]

// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev Initializes the contract setting the deployer as the initial owner.
   */
  constructor() {
    _transferOwnership(_msgSender());
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    _checkOwner();
    _;
  }

  /**
   * @dev Returns the address of the current owner.
   */
  function owner() public view virtual returns (address) {
    return _owner;
  }

  /**
   * @dev Throws if the sender is not the owner.
   */
  function _checkOwner() internal view virtual {
    require(owner() == _msgSender(), 'Ownable: caller is not the owner');
  }

  /**
   * @dev Leaves the contract without owner. It will not be possible to call
   * `onlyOwner` functions anymore. Can only be called by the current owner.
   *
   * NOTE: Renouncing ownership will leave the contract without an owner,
   * thereby removing any functionality that is only available to the owner.
   */
  function renounceOwnership() public virtual onlyOwner {
    _transferOwnership(address(0));
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   * Can only be called by the current owner.
   */
  function transferOwnership(address newOwner) public virtual onlyOwner {
    require(newOwner != address(0), 'Ownable: new owner is the zero address');
    _transferOwnership(newOwner);
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   * Internal function without access restriction.
   */
  function _transferOwnership(address newOwner) internal virtual {
    address oldOwner = _owner;
    _owner = newOwner;
    emit OwnershipTransferred(oldOwner, newOwner);
  }
}

// File contracts/interfaces/Enum.sol

pragma solidity ^0.8.17;

/// @title Enum - Collection of enums
/// @author Richard Meissner - <[email protected]sis.pm>
interface Enum {
  enum Operation {
    Call,
    DelegateCall
  }
}

// File contracts/interfaces/GnosisSafe.sol

pragma solidity ^0.8.17;

interface GnosisSafe {
  /// @dev Allows a Module to execute a Safe transaction without any further confirmations.
  /// @param to Destination address of module transaction.
  /// @param value Ether value of module transaction.
  /// @param data Data payload of module transaction.
  /// @param operation Operation type of module transaction.
  function execTransactionFromModule(
    address to,
    uint256 value,
    bytes calldata data,
    Enum.Operation operation
  ) external returns (bool success);
}

// File @openzeppelin/contracts/utils/math/[email protected]

// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
  enum Rounding {
    Down, // Toward negative infinity
    Up, // Toward infinity
    Zero // Toward zero
  }

  /**
   * @dev Returns the largest of two numbers.
   */
  function max(uint256 a, uint256 b) internal pure returns (uint256) {
    return a > b ? a : b;
  }

  /**
   * @dev Returns the smallest of two numbers.
   */
  function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }

  /**
   * @dev Returns the average of two numbers. The result is rounded towards
   * zero.
   */
  function average(uint256 a, uint256 b) internal pure returns (uint256) {
    // (a + b) / 2 can overflow.
    return (a & b) + (a ^ b) / 2;
  }

  /**
   * @dev Returns the ceiling of the division of two numbers.
   *
   * This differs from standard division with `/` in that it rounds up instead
   * of rounding down.
   */
  function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    // (a + b - 1) / b can overflow on addition, so we distribute.
    return a == 0 ? 0 : (a - 1) / b + 1;
  }

  /**
   * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
   * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
   * with further edits by Uniswap Labs also under MIT license.
   */
  function mulDiv(
    uint256 x,
    uint256 y,
    uint256 denominator
  ) internal pure returns (uint256 result) {
    unchecked {
      // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
      // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
      // variables such that product = prod1 * 2^256 + prod0.
      uint256 prod0; // Least significant 256 bits of the product
      uint256 prod1; // Most significant 256 bits of the product
      assembly {
        let mm := mulmod(x, y, not(0))
        prod0 := mul(x, y)
        prod1 := sub(sub(mm, prod0), lt(mm, prod0))
      }

      // Handle non-overflow cases, 256 by 256 division.
      if (prod1 == 0) {
        return prod0 / denominator;
      }

      // Make sure the result is less than 2^256. Also prevents denominator == 0.
      require(denominator > prod1);

      ///////////////////////////////////////////////
      // 512 by 256 division.
      ///////////////////////////////////////////////

      // Make division exact by subtracting the remainder from [prod1 prod0].
      uint256 remainder;
      assembly {
        // Compute remainder using mulmod.
        remainder := mulmod(x, y, denominator)

        // Subtract 256 bit number from 512 bit number.
        prod1 := sub(prod1, gt(remainder, prod0))
        prod0 := sub(prod0, remainder)
      }

      // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
      // See https://cs.stackexchange.com/q/138556/92363.

      // Does not overflow because the denominator cannot be zero at this stage in the function.
      uint256 twos = denominator & (~denominator + 1);
      assembly {
        // Divide denominator by twos.
        denominator := div(denominator, twos)

        // Divide [prod1 prod0] by twos.
        prod0 := div(prod0, twos)

        // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
        twos := add(div(sub(0, twos), twos), 1)
      }

      // Shift in bits from prod1 into prod0.
      prod0 |= prod1 * twos;

      // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
      // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
      // four bits. That is, denominator * inv = 1 mod 2^4.
      uint256 inverse = (3 * denominator) ^ 2;

      // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
      // in modular arithmetic, doubling the correct bits in each step.
      inverse *= 2 - denominator * inverse; // inverse mod 2^8
      inverse *= 2 - denominator * inverse; // inverse mod 2^16
      inverse *= 2 - denominator * inverse; // inverse mod 2^32
      inverse *= 2 - denominator * inverse; // inverse mod 2^64
      inverse *= 2 - denominator * inverse; // inverse mod 2^128
      inverse *= 2 - denominator * inverse; // inverse mod 2^256

      // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
      // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
      // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
      // is no longer required.
      result = prod0 * inverse;
      return result;
    }
  }

  /**
   * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
   */
  function mulDiv(
    uint256 x,
    uint256 y,
    uint256 denominator,
    Rounding rounding
  ) internal pure returns (uint256) {
    uint256 result = mulDiv(x, y, denominator);
    if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
      result += 1;
    }
    return result;
  }

  /**
   * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
   *
   * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
   */
  function sqrt(uint256 a) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }

    // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
    //
    // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
    // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
    //
    // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
    // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
    // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
    //
    // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
    uint256 result = 1 << (log2(a) >> 1);

    // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
    // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
    // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
    // into the expected uint128 result.
    unchecked {
      result = (result + a / result) >> 1;
      result = (result + a / result) >> 1;
      result = (result + a / result) >> 1;
      result = (result + a / result) >> 1;
      result = (result + a / result) >> 1;
      result = (result + a / result) >> 1;
      result = (result + a / result) >> 1;
      return min(result, a / result);
    }
  }

  /**
   * @notice Calculates sqrt(a), following the selected rounding direction.
   */
  function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
    unchecked {
      uint256 result = sqrt(a);
      return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
    }
  }

  /**
   * @dev Return the log in base 2, rounded down, of a positive value.
   * Returns 0 if given 0.
   */
  function log2(uint256 value) internal pure returns (uint256) {
    uint256 result = 0;
    unchecked {
      if (value >> 128 > 0) {
        value >>= 128;
        result += 128;
      }
      if (value >> 64 > 0) {
        value >>= 64;
        result += 64;
      }
      if (value >> 32 > 0) {
        value >>= 32;
        result += 32;
      }
      if (value >> 16 > 0) {
        value >>= 16;
        result += 16;
      }
      if (value >> 8 > 0) {
        value >>= 8;
        result += 8;
      }
      if (value >> 4 > 0) {
        value >>= 4;
        result += 4;
      }
      if (value >> 2 > 0) {
        value >>= 2;
        result += 2;
      }
      if (value >> 1 > 0) {
        result += 1;
      }
    }
    return result;
  }

  /**
   * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
   * Returns 0 if given 0.
   */
  function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
    unchecked {
      uint256 result = log2(value);
      return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
    }
  }

  /**
   * @dev Return the log in base 10, rounded down, of a positive value.
   * Returns 0 if given 0.
   */
  function log10(uint256 value) internal pure returns (uint256) {
    uint256 result = 0;
    unchecked {
      if (value >= 10 ** 64) {
        value /= 10 ** 64;
        result += 64;
      }
      if (value >= 10 ** 32) {
        value /= 10 ** 32;
        result += 32;
      }
      if (value >= 10 ** 16) {
        value /= 10 ** 16;
        result += 16;
      }
      if (value >= 10 ** 8) {
        value /= 10 ** 8;
        result += 8;
      }
      if (value >= 10 ** 4) {
        value /= 10 ** 4;
        result += 4;
      }
      if (value >= 10 ** 2) {
        value /= 10 ** 2;
        result += 2;
      }
      if (value >= 10 ** 1) {
        result += 1;
      }
    }
    return result;
  }

  /**
   * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
   * Returns 0 if given 0.
   */
  function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
    unchecked {
      uint256 result = log10(value);
      return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
    }
  }

  /**
   * @dev Return the log in base 256, rounded down, of a positive value.
   * Returns 0 if given 0.
   *
   * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
   */
  function log256(uint256 value) internal pure returns (uint256) {
    uint256 result = 0;
    unchecked {
      if (value >> 128 > 0) {
        value >>= 128;
        result += 16;
      }
      if (value >> 64 > 0) {
        value >>= 64;
        result += 8;
      }
      if (value >> 32 > 0) {
        value >>= 32;
        result += 4;
      }
      if (value >> 16 > 0) {
        value >>= 16;
        result += 2;
      }
      if (value >> 8 > 0) {
        result += 1;
      }
    }
    return result;
  }

  /**
   * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
   * Returns 0 if given 0.
   */
  function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
    unchecked {
      uint256 result = log256(value);
      return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
    }
  }
}

// File contracts/interfaces/AddressResolver.sol

pragma solidity ^0.8.17;

interface AddressResolver {
  function requireAndGetAddress(
    bytes32 name,
    string calldata reason
  ) external view returns (address);
}

// File contracts/interfaces/ExchangeRates.sol

pragma solidity ^0.8.17;

interface ExchangeRates {
  function rateAndInvalid(bytes32 currencyKey) external view returns (uint rate, bool isInvalid);
}

// File contracts/interfaces/GasPriceOracle.sol

pragma solidity ^0.8.17;

interface GasPriceOracle {
  function gasPrice() external view returns (uint256);

  function l1BaseFee() external view returns (uint256);

  function overhead() external view returns (uint256);

  function scalar() external view returns (uint256);

  function decimals() external view returns (uint256);

  function getL1Fee(bytes memory _data) external view returns (uint256);

  function getL1GasUsed(bytes memory _data) external view returns (uint256);
}

// File contracts/PerpsV2DynamicFeesModule.sol

pragma solidity ^0.8.17;

// PerpsV2DynamicFeesModule is a dynamic gas fee module, which is able to adjust the
// minKeeperFee, within bounds set by governance.
//
// @see: https://sips.synthetix.io/sips/sip-2013/
contract PerpsV2DynamicFeesModule is Ownable {
  using Math for uint256;

  address public constant GAS_PRICE_ORACLE_ADDRESS = 0x420000000000000000000000000000000000000F;
  address public constant SNX_PDAO_MULTISIG_ADDRESS = 0x6cd3f878852769e04A723A5f66CA7DD4d9E38A6C;
  address public constant SNX_ADDRESS_RESOLVER = 0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C;

  GasPriceOracle private _gasPriceOracle;
  GnosisSafe private _pDAOSafe;
  AddressResolver private _addressResolver;

  uint256 private constant UNIT = 10 ** uint(18);

  uint256 private _profitMarginUSD;
  uint256 private _profitMarginPercent;
  uint256 private _minKeeperFeeUpperBound;
  uint256 private _minKeeperFeeLowerBound;
  uint256 private _gasUnitsL1;
  uint256 private _gasUnitsL2;
  uint256 private _lastUpdatedAtTime;

  bool public isPaused;

  constructor(
    address _owner,
    uint256 profitMarginUSD,
    uint256 profitMarginPercent,
    uint256 minKeeperFeeUpperBound,
    uint256 minKeeperFeeLowerBound,
    uint256 gasUnitsL1,
    uint256 gasUnitsL2
  ) {
    // Do not call Ownable constructor which sets the owner to the msg.sender and set it to _owner.
    _transferOwnership(_owner);

    // contracts
    _addressResolver = AddressResolver(SNX_ADDRESS_RESOLVER);
    _pDAOSafe = GnosisSafe(SNX_PDAO_MULTISIG_ADDRESS);
    _gasPriceOracle = GasPriceOracle(GAS_PRICE_ORACLE_ADDRESS);

    // params
    _profitMarginUSD = profitMarginUSD;
    _profitMarginPercent = profitMarginPercent;
    _minKeeperFeeUpperBound = minKeeperFeeUpperBound;
    _minKeeperFeeLowerBound = minKeeperFeeLowerBound;
    _gasUnitsL1 = gasUnitsL1;
    _gasUnitsL2 = gasUnitsL2;

    // start as not paused
    isPaused = false;
  }

  // --- External/Public --- //

  // @dev Returns computed gas price given on-chain variables.
  function getMinKeeperFee() public view returns (uint256) {
    ExchangeRates exchangeRates = ExchangeRates(
      _addressResolver.requireAndGetAddress('ExchangeRates', 'Missing ExchangeRates address')
    );

    (uint256 price, bool invalid) = exchangeRates.rateAndInvalid('ETH');
    require(!invalid, 'Invalid price');

    uint256 gasPriceL2 = _gasPriceOracle.gasPrice();
    uint256 overhead = _gasPriceOracle.overhead();
    uint256 l1BaseFee = _gasPriceOracle.l1BaseFee();
    uint256 decimals = _gasPriceOracle.decimals();
    uint256 scalar = _gasPriceOracle.scalar();

    uint256 costOfExecutionGross = ((((_gasUnitsL1 + overhead) * l1BaseFee * scalar) /
      10 ** decimals) + (_gasUnitsL2 * gasPriceL2)) * price;

    uint256 maxProfitMargin = _profitMarginUSD.max(
      costOfExecutionGross.mulDiv(_profitMarginPercent, UNIT)
    );
    uint256 costOfExecutionNet = costOfExecutionGross + maxProfitMargin;

    return _minKeeperFeeUpperBound.min(costOfExecutionNet.max(_minKeeperFeeLowerBound));
  }

  // @dev Updates the minKeeperFee in PerpsV2MarketSettings.
  function setMinKeeperFee() external returns (bool success) {
    require(!isPaused, 'Module paused');

    success = _executeSafeTransaction(getMinKeeperFee());
  }

  // @dev Returns the current configurations.
  function getParameters()
    external
    view
    returns (
      uint256 profitMarginUSD,
      uint256 profitMarginPercent,
      uint256 minKeeperFeeUpperBound,
      uint256 minKeeperFeeLowerBound,
      uint256 gasUnitsL1,
      uint256 gasUnitsL2,
      uint256 lastUpdatedAtTime
    )
  {
    profitMarginUSD = _profitMarginUSD;
    profitMarginPercent = _profitMarginPercent;
    minKeeperFeeUpperBound = _minKeeperFeeUpperBound;
    minKeeperFeeLowerBound = _minKeeperFeeLowerBound;
    gasUnitsL1 = _gasUnitsL1;
    gasUnitsL2 = _gasUnitsL2;
    lastUpdatedAtTime = _lastUpdatedAtTime;
  }

  // @dev Sets params used for gas price computation.
  function setParameters(
    uint256 profitMarginUSD,
    uint256 profitMarginPercent,
    uint256 minKeeperFeeUpperBound,
    uint256 minKeeperFeeLowerBound,
    uint256 gasUnitsL1,
    uint256 gasUnitsL2
  ) external onlyOwner {
    _profitMarginUSD = profitMarginUSD;
    _profitMarginPercent = profitMarginPercent;
    _minKeeperFeeUpperBound = minKeeperFeeUpperBound;
    _minKeeperFeeLowerBound = minKeeperFeeLowerBound;
    _gasUnitsL1 = gasUnitsL1;
    _gasUnitsL2 = gasUnitsL2;
  }

  // @dev sets the paused state
  function setPaused(bool _isPaused) external onlyOwner {
    isPaused = _isPaused;
  }

  // --- Internal --- //

  function _executeSafeTransaction(uint256 minKeeperFee) internal returns (bool success) {
    bytes memory payload = abi.encodeWithSignature('setMinKeeperFee(uint256)', minKeeperFee);
    address marketSettingsAddress = _addressResolver.requireAndGetAddress(
      'PerpsV2MarketSettings',
      'Missing Perpsv2MarketSettings address'
    );

    success = _pDAOSafe.execTransactionFromModule(
      marketSettingsAddress,
      0,
      payload,
      Enum.Operation.Call
    );
    _lastUpdatedAtTime = block.timestamp;

    if (success) {
      emit KeeperFeeUpdated(minKeeperFee, _lastUpdatedAtTime);
    } else {
      emit KeeperFeeUpdateFailed(minKeeperFee, _lastUpdatedAtTime);
    }
  }

  // --- Events --- //

  event KeeperFeeUpdated(uint256 minKeeperFee, uint256 lastUpdatedAtTime);
  event KeeperFeeUpdateFailed(uint256 minKeeperFee, uint256 lastUpdatedAtTime);
}