// SPDX-License-Identifier: BUSL-1.1
// Refer to https://docs.pegasusfinance.xyz/protocol-overview/protocol-mechanism/code-use-notes
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "../interface/ILiquidityPoolGetter.sol";

contract SymbolService is Initializable, OwnableUpgradeable {
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    struct PerpetualUID {
        address liquidityPool;
        uint256 perpetualIndex;
    }

    mapping(uint256 => PerpetualUID) internal _perpetualUIDs;
    mapping(bytes32 => EnumerableSetUpgradeable.UintSet) internal _perpetualSymbols;
    uint256 internal _nextSymbol;
    uint256 internal _reservedSymbolCount;
    EnumerableSetUpgradeable.AddressSet internal _whitelistedFactories;

    event AllocateSymbol(address liquidityPool, uint256 perpetualIndex, uint256 symbol);
    event AddWhitelistedFactory(address factory);
    event RemoveWhitelistedFactory(address factory);

    function initialize(uint256 reservedSymbolCount) external virtual initializer {
        __Ownable_init();
        _nextSymbol = reservedSymbolCount;
        _reservedSymbolCount = reservedSymbolCount;
    }

    /**
     * @notice Check if the factory is whitelisted
     * @param factory The address of the factory
     * @return bool True if the factory is whitelisted
     */
    function isWhitelistedFactory(address factory) public view returns (bool) {
        return _whitelistedFactories.contains(factory);
    }

    /**
     * @notice Add the factory to the whitelist. Can only called by owner
     * @param factory The address of the factory
     */
    function addWhitelistedFactory(address factory) public onlyOwner {
        require(factory.isContract(), "factory must be a contract");
        require(!isWhitelistedFactory(factory), "factory already exists");
        _whitelistedFactories.add(factory);
        emit AddWhitelistedFactory(factory);
    }

    /**
     * @notice Remove the factory from the whitelist. Can only called by owner
     * @param factory The address of the factory
     */
    function removeWhitelistedFactory(address factory) public onlyOwner {
        require(isWhitelistedFactory(factory), "factory not found");
        _whitelistedFactories.remove(factory);
        emit RemoveWhitelistedFactory(factory);
    }

    modifier onlyWhitelisted(address liquidityPool) {
        require(AddressUpgradeable.isContract(liquidityPool), "must called by contract");
        (, , address[7] memory addresses, , ) = ILiquidityPoolGetter(liquidityPool)
            .getLiquidityPoolInfo();
        require(_whitelistedFactories.contains(addresses[0]), "wrong factory");
        _;
    }

    /**
     * @notice Get the unique id(liquidity pool + perpetual index) of the perpetual by the symbol
     * @param symbol The symbol
     * @return liquidityPool The address of the liquidity pool
     * @return perpetualIndex The index of the perpetual in the liquidity pool
     */
    function getPerpetualUID(uint256 symbol)
        public
        view
        returns (address liquidityPool, uint256 perpetualIndex)
    {
        PerpetualUID storage perpetualUID = _perpetualUIDs[symbol];
        require(perpetualUID.liquidityPool != address(0), "symbol not found");
        liquidityPool = perpetualUID.liquidityPool;
        perpetualIndex = perpetualUID.perpetualIndex;
    }

    /**
     * @notice Get the symbols of the perpetual by the unique id(liquidity pool + perpetual index)
     * @param liquidityPool The address of the liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return symbols The symbols of the perpetual
     */
    function getSymbols(address liquidityPool, uint256 perpetualIndex)
        public
        view
        returns (uint256[] memory symbols)
    {
        bytes32 key = _getPerpetualKey(liquidityPool, perpetualIndex);
        uint256 length = _perpetualSymbols[key].length();
        if (length == 0) {
            return symbols;
        }
        symbols = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            symbols[i] = _perpetualSymbols[key].at(i);
        }
    }

    /**
     * @notice Allocate the perpetual an unreserved symbol The perpetual must have no symbol before.
     *         Can only called by whitelisted factory
     * @param liquidityPool The address of the liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return symbol The symbol allocated
     */
    function allocateSymbol(address liquidityPool, uint256 perpetualIndex)
        public
        onlyWhitelisted(msg.sender)
        returns (uint256 symbol)
    {
        bytes32 key = _getPerpetualKey(liquidityPool, perpetualIndex);
        require(_perpetualSymbols[key].length() == 0, "perpetual already exists");

        symbol = _nextSymbol;
        require(symbol < type(uint256).max, "not enough symbol");
        _perpetualUIDs[symbol] = PerpetualUID({
            liquidityPool: liquidityPool,
            perpetualIndex: perpetualIndex
        });
        _perpetualSymbols[key].add(symbol);
        _nextSymbol = _nextSymbol.add(1);
        emit AllocateSymbol(liquidityPool, perpetualIndex, symbol);
    }

    /**
     * @notice Assign perpetual a reserved symbol. The perpetual must have unreserved symbol
     *         and not have reserved symbol before. Can only called by owner
     * @param liquidityPool The address of the liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param symbol The symbol assigned
     */
    function assignReservedSymbol(
        address liquidityPool,
        uint256 perpetualIndex,
        uint256 symbol
    ) public onlyOwner onlyWhitelisted(liquidityPool) {
        require(symbol < _reservedSymbolCount, "symbol exceeds reserved symbol count");
        require(_perpetualUIDs[symbol].liquidityPool == address(0), "symbol already exists");

        bytes32 key = _getPerpetualKey(liquidityPool, perpetualIndex);
        require(
            _perpetualSymbols[key].length() == 1 &&
                _perpetualSymbols[key].at(0) >= _reservedSymbolCount,
            "perpetual must have normal symbol and mustn't have reversed symbol"
        );
        _perpetualUIDs[symbol] = PerpetualUID({
            liquidityPool: liquidityPool,
            perpetualIndex: perpetualIndex
        });
        _perpetualSymbols[key].add(symbol);
        emit AllocateSymbol(liquidityPool, perpetualIndex, symbol);
    }

    /**
     * @dev Get the key of the perpetual
     * @param liquidityPool The address of the liquidity pool which the perpetual belongs to
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return bytes32 The key of the perpetual
     */
    function _getPerpetualKey(address liquidityPool, uint256 perpetualIndex)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(liquidityPool, perpetualIndex));
    }
}

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity >=0.4.24 <0.8.0;

import "../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || _isConstructor() || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/Initializable.sol";
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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMathUpgradeable {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSetUpgradeable {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;

        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) { // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            bytes32 lastvalue = set._values[lastIndex];

            // Move the last value to the index where the value to delete is
            set._values[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            set._indexes[lastvalue] = toDeleteIndex + 1; // All indexes are 1-based

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }


    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Type.sol";

interface ILiquidityPoolGetter {
    /**
     * @notice Get the info of the liquidity pool
     * @return isRunning True if the liquidity pool is running
     * @return isFastCreationEnabled True if the operator of the liquidity pool is allowed to create new perpetual
     *                               when the liquidity pool is running
     * @return addresses The related addresses of the liquidity pool
     * @return intNums Int type properties, see below for details.
     * @return uintNums Uint type properties, see below for details.
     */
    function getLiquidityPoolInfo()
        external
        view
        returns (
            bool isRunning,
            bool isFastCreationEnabled,
            // [0] creator,
            // [1] operator,
            // [2] transferringOperator,
            // [3] governor,
            // [4] shareToken,
            // [5] collateralToken,
            // [6] vault,
            address[7] memory addresses,
            // [0] vaultFeeRate,
            // [1] poolCash,
            // [2] insuranceFundCap,
            // [3] insuranceFund,
            // [4] donatedInsuranceFund,
            int256[5] memory intNums,
            // [0] collateralDecimals,
            // [1] perpetualCount,
            // [2] fundingTime,
            // [3] operatorExpiration,
            // [4] liquidityCap,
            // [5] shareTransferDelay,
            uint256[6] memory uintNums
        );

    /**
     * @notice Get the info of the perpetual. Need to update the funding state and the oracle price
     *         of each perpetual before and update the funding rate of each perpetual after
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return state The state of the perpetual
     * @return oracle The oracle's address of the perpetual
     * @return nums The related numbers of the perpetual
     */
    function getPerpetualInfo(uint256 perpetualIndex)
        external
        view
        returns (
            PerpetualState state,
            address oracle,
            // [0] totalCollateral
            // [1] markPrice, (return settlementPrice if it is in EMERGENCY state)
            // [2] indexPrice,
            // [3] fundingRate,
            // [4] unitAccumulativeFunding,
            // [5] initialMarginRate,
            // [6] maintenanceMarginRate,
            // [7] operatorFeeRate,
            // [8] lpFeeRate,
            // [9] referralRebateRate,
            // [10] liquidationPenaltyRate,
            // [11] keeperGasReward,
            // [12] insuranceFundRate,
            // [13-15] halfSpread value, min, max,
            // [16-18] openSlippageFactor value, min, max,
            // [19-21] closeSlippageFactor value, min, max,
            // [22-24] fundingRateLimit value, min, max,
            // [25-27] ammMaxLeverage value, min, max,
            // [28-30] maxClosePriceDiscount value, min, max,
            // [31] openInterest,
            // [32] maxOpenInterestRate,
            // [33-35] fundingRateFactor value, min, max,
            // [36-38] defaultTargetLeverage value, min, max,
            // [39-41] baseFundingRate value, min, max,
            int256[50] memory nums
        );

    /**
     * @notice Get the account info of the trader. Need to update the funding state and the oracle price
     *         of each perpetual before and update the funding rate of each perpetual after
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param trader The address of the trader
     * @return cash The cash(collateral) of the account
     * @return position The position of the account
     * @return availableMargin The available margin of the account
     * @return margin The margin of the account
     * @return settleableMargin The settleable margin of the account
     * @return isInitialMarginSafe True if the account is initial margin safe
     * @return isMaintenanceMarginSafe True if the account is maintenance margin safe
     * @return isMarginSafe True if the total value of margin account is beyond 0
     * @return targetLeverage   The target leverage for openning position.
     */
    function getMarginAccount(uint256 perpetualIndex, address trader)
        external
        view
        returns (
            int256 cash,
            int256 position,
            int256 availableMargin,
            int256 margin,
            int256 settleableMargin,
            bool isInitialMarginSafe,
            bool isMaintenanceMarginSafe,
            bool isMarginSafe, // bankrupt
            int256 targetLeverage,
            int256 entryValue
        );

    /**
     * @notice Get the number of active accounts in the perpetual.
     *         Active means the trader's account is not empty in the perpetual.
     *         Empty means cash and position are zero
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return activeAccountCount The number of active accounts in the perpetual
     */
    function getActiveAccountCount(uint256 perpetualIndex) external view returns (uint256);

    /**
     * @notice Get the active accounts in the perpetual whose index between begin and end.
     *         Active means the trader's account is not empty in the perpetual.
     *         Empty means cash and position are zero
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param begin The begin index
     * @param end The end index
     * @return result The active accounts in the perpetual whose index between begin and end
     */
    function listActiveAccounts(
        uint256 perpetualIndex,
        uint256 begin,
        uint256 end
    ) external view returns (address[] memory result);

    /**
     * @notice Get the progress of clearing active accounts.
     *         Return the number of total active accounts and the number of active accounts not cleared
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return left The left active accounts
     * @return total The total active accounts
     */
    function getClearProgress(uint256 perpetualIndex)
        external
        view
        returns (uint256 left, uint256 total);

    /**
     * @notice Get the pool margin of the liquidity pool.
     *         Pool margin is how much collateral of the pool considering the AMM's positions of perpetuals
     * @return poolMargin The pool margin of the liquidity pool
     */
    function getPoolMargin() external view returns (int256 poolMargin, bool isSafe);

    /**
     * @notice  Query the price, fees and cost when trade agaist amm.
     *          The trading price is determined by the AMM based on the index price of the perpetual.
     *          This method should returns the same result as a 'read-only' trade.
     *          WARN: the result of this function is base on current storage of liquidityPool, not the latest.
     *          To get the latest status, call `syncState` first.
     *
     *          Flags is a 32 bit uint value which indicates: (from highest bit)
     *            - close only      only close position during trading;
     *            - market order    do not check limit price during trading;
     *            - stop loss       only available in brokerTrade mode;
     *            - take profit     only available in brokerTrade mode;
     *          For stop loss and take profit, see `validateTriggerPrice` in OrderModule.sol for details.
     *
     * @param   perpetualIndex  The index of the perpetual in liquidity pool.
     * @param   trader          The address of trader.
     * @param   amount          The amount of position to trader, positive for buying and negative for selling. The amount always use decimals 18.
     * @param   referrer        The address of referrer who will get rebate from the deal.
     * @param   flags           The flags of the trade.
     * @return  tradePrice      The average fill price.
     * @return  totalFee        The total fee collected from the trader after the trade.
     * @return  cost            Deposit or withdraw to let effective leverage == targetLeverage if flags contain USE_TARGET_LEVERAGE. > 0 if deposit, < 0 if withdraw.
     */
    function queryTrade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        address referrer,
        uint32 flags
    )
        external
        returns (
            int256 tradePrice,
            int256 totalFee,
            int256 cost
        );

    /**
     * @notice  Query cash to add / share to mint when adding liquidity to the liquidity pool.
     *          Only one of cashToAdd or shareToMint may be non-zero.
     *
     * @param   cashToAdd         The amount of cash to add, always use decimals 18.
     * @param   shareToMint       The amount of share token to mint, always use decimals 18.
     * @return  cashToAddResult   The amount of cash to add, always use decimals 18. Equal to cashToAdd if cashToAdd is non-zero.
     * @return  shareToMintResult The amount of cash to add, always use decimals 18. Equal to shareToMint if shareToMint is non-zero.
     */
    function queryAddLiquidity(int256 cashToAdd, int256 shareToMint)
        external
        view
        returns (int256 cashToAddResult, int256 shareToMintResult);

    /**
     * @notice  Query cash to return / share to redeem when removing liquidity from the liquidity pool.
     *          Only one of shareToRemove or cashToReturn may be non-zero.
     *          Can only called when the pool is running.
     *
     * @param   shareToRemove       The amount of share token to redeem, always use decimals 18.
     * @param   cashToReturn        The amount of cash to return, always use decimals 18.
     * @return  shareToRemoveResult The amount of share token to redeem, always use decimals 18. Equal to shareToRemove if shareToRemove is non-zero.
     * @return  cashToReturnResult  The amount of cash to return, always use decimals 18. Equal to cashToReturn if cashToReturn is non-zero.
     */
    function queryRemoveLiquidity(int256 shareToRemove, int256 cashToReturn)
        external
        view
        returns (int256 shareToRemoveResult, int256 cashToReturnResult);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: BUSL-1.1
// Refer to https://docs.pegasusfinance.xyz/protocol-overview/protocol-mechanism/code-use-notes
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

/**
 * @notice  Perpetual state:
 *          - INVALID:      Uninitialized or not non-existent perpetual;
 *          - INITIALIZING: Only when LiquidityPoolStorage.isRunning == false. Traders cannot perform operations;
 *          - NORMAL:       Full functional state. Traders is able to perform all operations;
 *          - EMERGENCY:    Perpetual is unsafe and only clear is available;
 *          - CLEARED:      All margin account is cleared. Trade could withdraw remaining margin balance.
 */
enum PerpetualState {
    INVALID,
    INITIALIZING,
    NORMAL,
    EMERGENCY,
    CLEARED
}
enum OrderType {
    LIMIT,
    MARKET,
    STOP
}

/**
 * @notice  Data structure to store risk parameter value.
 */
struct Option {
    int256 value;
    int256 minValue;
    int256 maxValue;
}

/**
 * @notice  Data structure to store oracle price data.
 */
struct OraclePriceData {
    int256 price;
    uint256 time;
}

/**
 * @notice  Data structure to store user margin information. See MarginAccountModule.sol for details.
 */
struct MarginAccount {
    int256 cash;
    int256 position;
    int256 targetLeverage;
    int256 entryValue;
}

/**
 * @notice  Data structure of an order object.
 */
struct Order {
    address trader;
    address broker;
    address relayer;
    address referrer;
    address liquidityPool;
    int256 minTradeAmount;
    int256 amount;
    int256 limitPrice;
    int256 triggerPrice;
    uint256 chainID;
    uint64 expiredAt;
    uint32 perpetualIndex;
    uint32 brokerFeeLimit;
    uint32 flags;
    uint32 salt;
}

/**
 * @notice  Core data structure, a core .
 */
struct LiquidityPoolStorage {
    bool isRunning;
    bool isFastCreationEnabled;
    // addresses
    address creator;
    address operator;
    address transferringOperator;
    address governor;
    address shareToken;
    address accessController;
    bool reserved3; // isWrapped
    uint256 scaler;
    uint256 collateralDecimals;
    address collateralToken;
    // pool attributes
    int256 poolCash;
    uint256 fundingTime;
    uint256 reserved5;
    uint256 operatorExpiration;
    mapping(address => int256) reserved1;
    bytes32[] reserved2;
    // perpetuals
    uint256 perpetualCount;
    mapping(uint256 => PerpetualStorage) perpetuals;
    // insurance fund
    int256 insuranceFundCap;
    int256 insuranceFund;
    int256 donatedInsuranceFund;
    address reserved4;
    uint256 liquidityCap;
    uint256 shareTransferDelay;
    address lpAuth;
    // reserved slot for future upgrade
    bytes32[13] reserved;
}

/**
 * @notice  Core data structure, storing perpetual information.
 */
struct PerpetualStorage {
    uint256 id;
    PerpetualState state;
    address oracle;
    int256 totalCollateral;
    int256 openInterest;
    // prices
    OraclePriceData indexPriceData;
    OraclePriceData markPriceData;
    OraclePriceData settlementPriceData;
    // funding state
    int256 fundingRate;
    int256 unitAccumulativeFunding;
    int256 unitAccumulativeShortFunding;
    int256 unitAccumulativeLongFunding;
    // base parameters
    int256 initialMarginRate;
    int256 maintenanceMarginRate;
    int256 operatorFeeRate;
    int256 lpFeeRate;
    int256 referralRebateRate;
    int256 liquidationPenaltyRate;
    int256 keeperGasReward;
    int256 insuranceFundRate;
    int256 reserved1;
    int256 maxOpenInterestRate;
    // risk parameters
    Option halfSpread;
    Option openSlippageFactor;
    Option closeSlippageFactor;
    Option fundingRateLimit;
    Option fundingRateFactor;
    Option ammMaxLeverage;
    Option maxClosePriceDiscount;
    Option openSlippageLongPenaltyFactor;
    Option openSlippageShortPenaltyFactor;
    Option meanRate;
    Option maxRate;
    Option longMeanRevertFactor;
    Option shortMeanRevertFactor;
    // users
    uint256 totalAccount;
    int256 totalMarginWithoutPosition;
    int256 totalMarginWithPosition;
    int256 redemptionRateWithoutPosition;
    int256 redemptionRateWithPosition;
    EnumerableSetUpgradeable.AddressSet activeAccounts;
    // insurance fund
    int256 reserved2;
    int256 reserved3;
    // accounts
    mapping(address => MarginAccount) marginAccounts;
    Option defaultTargetLeverage;
    // keeper
    address reserved4;
    EnumerableSetUpgradeable.AddressSet ammKeepers;
    EnumerableSetUpgradeable.AddressSet reserved5;
    Option baseFundingRate;
    // reserved slot for future upgrade
    bytes32[9] reserved;
}