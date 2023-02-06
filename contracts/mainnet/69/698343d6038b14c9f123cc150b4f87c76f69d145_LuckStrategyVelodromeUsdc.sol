/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-05
*/

// File: @openzeppelin-4/contracts/utils/Context.sol

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
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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
        require(newOwner != address(0), "Ownable: new owner is the zero address");
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


/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-07-23
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IStrategy {
    //deposits all funds into the farm
    function deposit() external;

    //vault only - withdraws funds from the strategy
    function withdraw(uint256 _amount) external;

    //claims rewards, charges fees, and re-deposits; returns caller fee amount.
    function harvest() external returns (uint256);

    //returns the balance of all tokens managed by the strategy
    function balanceOf() external view returns (uint256);

    //pauses deposits, resets allowances, and withdraws all funds from farm
    function panic() external;
}


// File contracts/interfaces/IVault.sol



pragma solidity ^0.8.0;

interface IVault {
    function token() external view returns (address);
    function getPricePerFullShare() external view returns (uint256);
}


// File @openzeppelin/contracts-upgradeable/access/[email protected]


// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}


// File @openzeppelin/contracts-upgradeable/access/[email protected]


// OpenZeppelin Contracts v4.4.1 (access/IAccessControlEnumerable.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControlEnumerable declared to support ERC165 detection.
 */
interface IAccessControlEnumerableUpgradeable is IAccessControlUpgradeable {
    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}


// File @openzeppelin/contracts-upgradeable/utils/[email protected]


// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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

// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}


// File @openzeppelin/contracts-upgradeable/utils/introspection/[email protected]


// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}



pragma solidity ^0.8.0;




// File @openzeppelin/contracts-upgradeable/utils/structs/[email protected]


// OpenZeppelin Contracts v4.4.1 (utils/structs/EnumerableSet.sol)

pragma solidity ^0.8.0;

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
        mapping(bytes32 => uint256) _indexes;
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

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

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
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
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

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
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

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
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

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}



// File contracts/abstract/ReaperBaseStrategyv3.sol



pragma solidity ^0.8.0;
abstract contract ReaperBaseStrategyv3 is IStrategy, Ownable
{
    uint256 public constant PERCENT_DIVISOR = 10_000;
    uint256 public constant ONE_YEAR = 365 days;
    uint256 public constant UPGRADE_TIMELOCK = 48 hours; // minimum 48 hours for RF

    struct Harvest {
        uint256 timestamp;
        uint256 vaultSharePrice;
    }

    Harvest[] public harvestLog;
    uint256 public harvestLogCadence;
    uint256 public lastHarvestTimestamp;

    uint256 public upgradeProposalTime;

    /**
     * @dev Reaper contracts:
     * {treasury} - Address of the Reaper treasury
     * {vault} - Address of the vault that controls the strategy's funds.
     * {strategist} - Address where strategist fee is remitted to.
     */
    address public treasury;
    address public vault;
    address public strategist;

    /**
     * Fee related constants:
     * {MAX_FEE} - Maximum fee allowed by the strategy. Hard-capped at 10%.
     * {STRATEGIST_MAX_FEE} - Maximum strategist fee allowed by the strategy (as % of treasury fee).
     *                        Hard-capped at 50%
     * {MAX_SECURITY_FEE} - Maximum security fee charged on withdrawal to prevent
     *                      flash deposit/harvest attacks.
     */
    uint256 public constant MAX_FEE = 1000;
    uint256 public constant STRATEGIST_MAX_FEE = 5000;
    uint256 public constant MAX_SECURITY_FEE = 10;

    /**
     * @dev Distribution of fees earned, expressed as % of the profit from each harvest.
     * {totalFee} - divided by 10,000 to determine the % fee. Set to 4.5% by default and
     * lowered as necessary to provide users with the most competitive APY.
     *
     * {callFee} - Percent of the totalFee reserved for the harvester (1000 = 10% of total fee: 0.45% by default)
     * {treasuryFee} - Percent of the totalFee taken by maintainers of the software (9000 = 90% of total fee: 4.05% by default)
     * {strategistFee} - Percent of the treasuryFee taken by strategist (2500 = 25% of treasury fee: 1.0125% by default)
     *
     * {securityFee} - Fee taxed when a user withdraws funds. Taken to prevent flash deposit/harvest attacks.
     * These funds are redistributed to stakers in the pool.
     */
    uint256 public totalFee;
    uint256 public callFee;
    uint256 public treasuryFee;
    uint256 public strategistFee;
    uint256 public securityFee;

    /**
     * {TotalFeeUpdated} Event that is fired each time the total fee is updated.
     * {FeesUpdated} Event that is fired each time callFee+treasuryFee+strategistFee are updated.
     * {StratHarvest} Event that is fired each time the strategy gets harvested.
     * {StrategistUpdated} Event that is fired each time the strategist address is updated.
     */
    event TotalFeeUpdated(uint256 newFee);
    event FeesUpdated(uint256 newCallFee, uint256 newTreasuryFee, uint256 newStrategistFee);
    event StratHarvest(address indexed harvester);
    event StrategistUpdated(address newStrategist);

    function __ReaperBaseStrategy_init(
        address _vault,
        address _treasury,
        address _strategist
    ) internal {
        harvestLogCadence = 1 minutes;
        totalFee = 25;
        callFee = 0;
        treasuryFee = 10000;
        strategistFee = 2500;
        securityFee = 0;

        vault = _vault;
        treasury = _treasury;
        strategist = _strategist;
        
        clearUpgradeCooldown();
        harvestLog.push(Harvest({timestamp: block.timestamp, vaultSharePrice: IVault(_vault).getPricePerFullShare()}));
    }

    /**
     * @dev Function that puts the funds to work.
     *      It gets called whenever someone deposits in the strategy's vault contract.
     *      Deposits go through only when the strategy is not paused.
     */
    function deposit() public override {
        _deposit();
    }

    /**
     * @dev Withdraws funds and sends them back to the vault. Can only
     *      be called by the vault. _amount must be valid and security fee
     *      is deducted up-front.
     */
    function withdraw(uint256 _amount) external override {
        require(msg.sender == vault);
        require(_amount != 0);
        require(_amount <= balanceOf());

        uint256 withdrawFee = (_amount * securityFee) / PERCENT_DIVISOR;
        _amount -= withdrawFee;

        _withdraw(_amount);
    }

    /**
     * @dev harvest() function that takes care of logging. Subcontracts should
     *      override _harvestCore() and implement their specific logic in it.
     */
    function harvest() external override returns (uint256 callerFee) {
        callerFee = _harvestCore();

        if (block.timestamp >= harvestLog[harvestLog.length - 1].timestamp + harvestLogCadence) {
            harvestLog.push(
                Harvest({timestamp: block.timestamp, vaultSharePrice: IVault(vault).getPricePerFullShare()})
            );
        }

        lastHarvestTimestamp = block.timestamp;
        emit StratHarvest(msg.sender);
    }

    function harvestLogLength() external view returns (uint256) {
        return harvestLog.length;
    }

    /**
     * @dev Traverses the harvest log backwards _n items,
     *      and returns the average APR calculated across all the included
     *      log entries. APR is multiplied by PERCENT_DIVISOR to retain precision.
     */
    function averageAPRAcrossLastNHarvests(int256 _n) external view returns (int256) {
        require(harvestLog.length >= 2);

        int256 runningAPRSum;
        int256 numLogsProcessed;

        for (uint256 i = harvestLog.length - 1; i > 0 && numLogsProcessed < _n; i--) {
            runningAPRSum += calculateAPRUsingLogs(i - 1, i);
            numLogsProcessed++;
        }

        return runningAPRSum / numLogsProcessed;
    }

    /**
     * @dev Strategists and roles with higher privilege can edit the log cadence.
     */
    function updateHarvestLogCadence(uint256 _newCadenceInSeconds) external onlyOwner {
        harvestLogCadence = _newCadenceInSeconds;
    }

    /**
     * @dev Function to calculate the total {want} held by the strat.
     *      It takes into account both the funds in hand, plus the funds in external contracts.
     */
    function balanceOf() public view virtual override returns (uint256);

    /**
     * @dev Pauses deposits. Withdraws all funds leaving rewards behind.
     *      Guardian and roles with higher privilege can panic.
     */
    function panic() external override onlyOwner {
        _reclaimWant();
    }


    /**
     * @dev updates the total fee, capped at 5%; only DEFAULT_ADMIN_ROLE.
     */
    function updateTotalFee(uint256 _totalFee) external onlyOwner {
        require(_totalFee <= MAX_FEE);
        totalFee = _totalFee;
        emit TotalFeeUpdated(totalFee);
    }

    /**
     * @dev updates the call fee, treasury fee, and strategist fee
     *      call Fee + treasury Fee must add up to PERCENT_DIVISOR
     *
     *      strategist fee is expressed as % of the treasury fee and
     *      must be no more than STRATEGIST_MAX_FEE
     *
     *      only DEFAULT_ADMIN_ROLE.
     */
    function updateFees(
        uint256 _callFee,
        uint256 _treasuryFee,
        uint256 _strategistFee
    ) external onlyOwner returns (bool) {
        require(_callFee + _treasuryFee == PERCENT_DIVISOR);
        require(_strategistFee <= STRATEGIST_MAX_FEE);

        callFee = _callFee;
        treasuryFee = _treasuryFee;
        strategistFee = _strategistFee;
        emit FeesUpdated(callFee, treasuryFee, strategistFee);
        return true;
    }

    function updateSecurityFee(uint256 _securityFee) external onlyOwner {
        require(_securityFee <= MAX_SECURITY_FEE);
        securityFee = _securityFee;
    }

    /**
     * @dev only DEFAULT_ADMIN_ROLE can update treasury address.
     */
    function updateTreasury(address newTreasury) external onlyOwner returns (bool) {
        treasury = newTreasury;
        return true;
    }

    /**
     * @dev Updates the current strategist. Only DEFAULT_ADMIN_ROLE may do this.
     */
    function updateStrategist(address _newStrategist) external onlyOwner {
        require(_newStrategist != address(0));
        strategist = _newStrategist;
        emit StrategistUpdated(_newStrategist);
    }

    /**
     * @dev Project an APR using the vault share price change between harvests at the provided indices.
     */
    function calculateAPRUsingLogs(uint256 _startIndex, uint256 _endIndex) public view returns (int256) {
        Harvest storage start = harvestLog[_startIndex];
        Harvest storage end = harvestLog[_endIndex];
        bool increasing = true;
        if (end.vaultSharePrice < start.vaultSharePrice) {
            increasing = false;
        }

        uint256 unsignedSharePriceChange;
        if (increasing) {
            unsignedSharePriceChange = end.vaultSharePrice - start.vaultSharePrice;
        } else {
            unsignedSharePriceChange = start.vaultSharePrice - end.vaultSharePrice;
        }

        uint256 unsignedPercentageChange = (unsignedSharePriceChange * 1e18) / start.vaultSharePrice;
        uint256 timeDifference = end.timestamp - start.timestamp;

        uint256 yearlyUnsignedPercentageChange = (unsignedPercentageChange * ONE_YEAR) / timeDifference;
        yearlyUnsignedPercentageChange /= 1e14; // restore basis points precision

        if (increasing) {
            return int256(yearlyUnsignedPercentageChange);
        }

        return -int256(yearlyUnsignedPercentageChange);
    }

    /**
     * @dev This function must be called prior to upgrading the implementation.
     *      It's required to wait UPGRADE_TIMELOCK seconds before executing the upgrade.
     *      Strategists and roles with higher privilege can initiate this cooldown.
     */
    function initiateUpgradeCooldown() external onlyOwner {
        upgradeProposalTime = block.timestamp;
    }

    /**
     * @dev This function is called:
     *      - in initialize()
     *      - as part of a successful upgrade
     *      - manually to clear the upgrade cooldown.
     * Guardian and roles with higher privilege can clear this cooldown.
     */
    function clearUpgradeCooldown() public onlyOwner {
        upgradeProposalTime = block.timestamp + (ONE_YEAR * 100);
    }

    /**
     * @dev subclasses should add their custom deposit logic in this function.
     */
    function _deposit() internal virtual;

    /**
     * @dev subclasses should add their custom withdraw logic in this function.
     *      Note that security fee has already been deducted, so it shouldn't be deducted
     *      again within this function.
     */
    function _withdraw(uint256 _amount) internal virtual;

    /**
     * @dev subclasses should add their custom harvesting logic in this function
     *      including charging any fees. The amount of fee that is remitted to the
     *      caller must be returned.
     */
    function _harvestCore() internal virtual returns (uint256);

    /**
     * @dev subclasses should add their custom logic to withdraw the principal from
     *      any external contracts in this function. Note that we don't care about rewards,
     *      we just want to reclaim our principal as much as possible, and as quickly as possible.
     *      So keep this function lean. Principal should be left in the strategy and not sent to
     *      the vault.
     */
    function _reclaimWant() internal virtual;
}


// File contracts/interfaces/IVeloRouter.sol


pragma solidity ^0.8.0;



// interface IERC20 {
//     function totalSupply() external view returns (uint256);
//     function transfer(address recipient, uint amount) external returns (bool);
//     function decimals() external view returns (uint8);
//     function symbol() external view returns (string memory);
//     function balanceOf(address) external view returns (uint);
//     function transferFrom(address sender, address recipient, uint amount) external returns (bool);
//     function allowance(address owner, address spender) external view returns (uint);
//     function approve(address spender, uint value) external returns (bool);

//     event Transfer(address indexed from, address indexed to, uint value);
//     event Approval(address indexed owner, address indexed spender, uint value);
// }

// interface IPair {
//     function metadata() external view returns (uint dec0, uint dec1, uint r0, uint r1, bool st, address t0, address t1);
//     function claimFees() external returns (uint, uint);
//     function tokens() external returns (address, address);
//     function transferFrom(address src, address dst, uint amount) external returns (bool);
//     function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
//     function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
//     function burn(address to) external returns (uint amount0, uint amount1);
//     function mint(address to) external returns (uint liquidity);
//     function getReserves() external view returns (uint _reserve0, uint _reserve1, uint _blockTimestampLast);
//     function getAmountOut(uint, address) external view returns (uint);
// }

// interface IPairFactory {
//     function allPairsLength() external view returns (uint);
//     function isPair(address pair) external view returns (bool);
//     function pairCodeHash() external pure returns (bytes32);
//     function getPair(address tokenA, address token, bool stable) external view returns (address);
//     function createPair(address tokenA, address tokenB, bool stable) external returns (address pair);
// }

interface IRouter {
    function pairFor(address tokenA, address tokenB, bool stable) external view returns (address pair);
}

interface IWETH {
    function deposit() external payable returns (uint);
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external returns (uint);
}

interface IVeloRouter is IRouter {
     struct route {
        address from;
        address to;
        bool stable;
    }

    function factory() external view returns (address);

    function weth() external view returns (IWETH);

    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);

    function pairFor(address tokenA, address tokenB, bool stable) external view returns (address pair);

    function getReserves(address tokenA, address tokenB, bool stable) external view returns (uint reserveA, uint reserveB);

    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external view returns (uint amount, bool stable);

    function getAmountsOut(uint amountIn, route[] memory routes) external view returns (uint[] memory amounts);

    function isPair(address pair) external view returns (bool);

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired
    ) external view returns (uint amountA, uint amountB, uint liquidity);

    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity
    ) external view returns (uint amountA, uint amountB);

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        bool stable,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETH(
        address token,
        bool stable,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHWithPermit(
        address token,
        bool stable,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);

    function swapExactTokensForTokensSimple(
        uint amountIn,
        uint amountOutMin,
        address tokenFrom,
        address tokenTo,
        bool stable,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        route[] calldata routes,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(uint amountOutMin, route[] calldata routes, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, route[] calldata routes, address to, uint deadline)
    external
    returns (uint[] memory amounts);

    function UNSAFE_swapExactTokensForTokens(
        uint[] memory amounts,
        route[] calldata routes,
        address to,
        uint deadline
    ) external returns (uint[] memory);
}


// File contracts/interfaces/IVeloPair.sol


pragma solidity ^0.8.0;

interface IVeloPair {
    function claimFees() external returns (uint256 claimed0, uint256 claimed1);

    function claimable0(address) external view returns (uint256);

    function claimable1(address) external view returns (uint256);

    function stable() external view returns (bool);

    function tokens() external view returns (address, address);
}


// File contracts/interfaces/IVeloGauge.sol



pragma solidity ^0.8.0;

// interface IVotingEscrow {

//     struct Point {
//         int128 bias;
//         int128 slope; // # -dweight / dt
//         uint256 ts;
//         uint256 blk; // block
//     }

//     function token() external view returns (address);
//     function team() external returns (address);
//     function epoch() external view returns (uint);
//     function point_history(uint loc) external view returns (Point memory);
//     function user_point_history(uint tokenId, uint loc) external view returns (Point memory);
//     function user_point_epoch(uint tokenId) external view returns (uint);

//     function ownerOf(uint) external view returns (address);
//     function isApprovedOrOwner(address, uint) external view returns (bool);
//     function transferFrom(address, address, uint) external;

//     function voting(uint tokenId) external;
//     function abstain(uint tokenId) external;
//     function attach(uint tokenId) external;
//     function detach(uint tokenId) external;

//     function checkpoint() external;
//     function deposit_for(uint tokenId, uint value) external;
//     function create_lock_for(uint, uint, address) external returns (uint);

//     function balanceOfNFT(uint) external view returns (uint);
//     function totalSupply() external view returns (uint);
// }

// interface IVoter {
//     function _ve() external view returns (address);
//     function governor() external view returns (address);
//     function emergencyCouncil() external view returns (address);
//     function attachTokenToGauge(uint _tokenId, address account) external;
//     function detachTokenFromGauge(uint _tokenId, address account) external;
//     function emitDeposit(uint _tokenId, address account, uint amount) external;
//     function emitWithdraw(uint _tokenId, address account, uint amount) external;
//     function isWhitelisted(address token) external view returns (bool);
//     function notifyRewardAmount(uint amount) external;
//     function distribute(address _gauge) external;
// }

// interface IPair {
//     function metadata() external view returns (uint dec0, uint dec1, uint r0, uint r1, bool st, address t0, address t1);
//     function claimFees() external returns (uint, uint);
//     function tokens() external returns (address, address);
//     function transferFrom(address src, address dst, uint amount) external returns (bool);
//     function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
//     function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
//     function burn(address to) external returns (uint amount0, uint amount1);
//     function mint(address to) external returns (uint liquidity);
//     function getReserves() external view returns (uint _reserve0, uint _reserve1, uint _blockTimestampLast);
//     function getAmountOut(uint, address) external view returns (uint);
// }

interface IGauge {
    function notifyRewardAmount(address token, uint amount) external;
    function getReward(address account, address[] memory tokens) external;
    function claimFees() external returns (uint claimed0, uint claimed1);
    function left(address token) external view returns (uint);
    function isForPair() external view returns (bool);
}
// interface IERC20 {
//     function totalSupply() external view returns (uint256);
//     function transfer(address recipient, uint amount) external returns (bool);
//     function decimals() external view returns (uint8);
//     function symbol() external view returns (string memory);
//     function balanceOf(address) external view returns (uint);
//     function transferFrom(address sender, address recipient, uint amount) external returns (bool);
//     function allowance(address owner, address spender) external view returns (uint);
//     function approve(address spender, uint value) external returns (bool);

//     event Transfer(address indexed from, address indexed to, uint value);
//     event Approval(address indexed owner, address indexed spender, uint value);
// }

// interface IBribe {
//     function _deposit(uint amount, uint tokenId) external;
//     function _withdraw(uint amount, uint tokenId) external;
//     function getRewardForOwner(uint tokenId, address[] memory tokens) external;
//     function notifyRewardAmount(address token, uint amount) external;
//     function left(address token) external view returns (uint);
// }

// Gauges are used to incentivize pools, they emit reward tokens over 7 days for staked LP tokens
interface IVeloGauge is IGauge{

    /// STATE VARIABLES ///

    // the LP token that needs to be staked for rewards
    function stake() external view returns (address);
    // the ve token used for gauges
    function _ve() external view returns (address);
    function internal_bribe() external view returns (address);
    function external_bribe() external view returns (address);
    function voter() external view returns (address);
    function derivedSupply() external view returns (uint256);
    function derivedBalances(address) external view returns (uint256);
    function isForPair() external view returns (bool);
    // default snx staking contract implementation
    function rewardRate(address) external view returns (uint256);
    function periodFinish(address) external view returns (uint256);
    function lastUpdateTime(address) external view returns (uint256);
    function rewardPerTokenStored(address) external view returns (uint256);
    function lastEarn(address, address) external view returns (uint256);
    function userRewardPerTokenStored(address, address) external view returns (uint256);
    function tokenIds(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function rewards(uint256) external view returns (address);
    function isReward(address) external view returns (bool);
    /// @notice A checkpoint for marking balance
    struct Checkpoint {
        uint256 timestamp;
        uint256 balanceOf;
    }
    /// @notice A checkpoint for marking reward rate
    struct RewardPerTokenCheckpoint {
        uint256 timestamp;
        uint256 rewardPerToken;
    }
    /// @notice A checkpoint for marking supply
    struct SupplyCheckpoint {
        uint256 timestamp;
        uint256 supply;
    }
    function checkpoints(address, uint256) external view returns (Checkpoint memory);
    function numCheckpoints(address) external view returns (uint256);
    function supplyCheckpoints(uint256) external view returns (SupplyCheckpoint memory);
    function supplyNumCheckpoints() external view returns (uint256);
    function rewardPerTokenCheckpoints(address, uint256) external view returns (RewardPerTokenCheckpoint memory);
    function rewardPerTokenNumCheckpoints(address) external view returns (uint256);
    function fees0() external view returns (uint256);
    function fees1() external view returns (uint256);

    /// FUNCTIONS ///
    function claimFees() external returns (uint256 claimed0, uint256 claimed1);
    /**
    * @notice Determine the prior balance for an account as of a block number
    * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
    * @param account The address of the account to check
    * @param timestamp The timestamp to get the balance at
    * @return The balance the account had as of the given block
    */
    function getPriorBalanceIndex(address account, uint256 timestamp) external view returns (uint256);
    function getPriorSupplyIndex(uint256 timestamp) external view returns (uint256);
    function getPriorRewardPerToken(address token, uint256 timestamp) external view returns (uint256, uint256);
    function rewardsListLength() external view returns (uint256);
    // returns the last time the reward was modified or periodFinish if the reward has ended
    function lastTimeRewardApplicable(address token) external view returns (uint256);
    function getReward(address account, address[] memory tokens) external;
    function rewardPerToken(address token) external view returns (uint256);
    function derivedBalance(address account) external view returns (uint256);
    function batchRewardPerToken(address token, uint256 maxRuns) external;
    /// @dev Update stored rewardPerToken values without the last one snapshot
    ///      If the contract will get "out of gas" error on users actions this will be helpful
    function batchUpdateRewardPerToken(address token, uint256 maxRuns) external;
    // earned is an estimation, it won't be exact till the supply > rewardPerToken calculations have run
    function earned(address token, address account) external view returns (uint256);
    function depositAll(uint256 tokenId) external;
    function deposit(uint256 amount, uint256 tokenId) external;
    function withdrawAll() external;
    function withdraw(uint256 amount) external;
    function withdrawToken(uint256 amount, uint256 tokenId) external;
    function left(address token) external view returns (uint256);
    function notifyRewardAmount(address token, uint256 amount) external;
    function swapOutRewardToken(uint256 i, address oldToken, address newToken) external;
}


// File @openzeppelin/contracts-upgradeable/token/ERC20/[email protected]


// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;


/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}



pragma solidity ^0.8.0;
/// @dev Deposit and stake want in Velodrome Gauges. Harvests VELO rewards and compounds.
///     Designed for USDC-X pairs
contract LuckStrategyVelodromeUsdc is ReaperBaseStrategyv3 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// 3rd-party contract addresses
    address public constant VELODROME_ROUTER = address(0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);

    /// @dev Tokens Used:
    /// {USDC} - Fees are charged in {USDC}
    /// {VELO} - Velodrome's reward
    /// {gauge} - Gauge where {want} is staked.
    /// {want} - Token staked.
    /// {lpToken0} - {want}'s underlying token.
    /// {lpToken1} - {want}'s underlying token.
    address public constant USDC = address(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    address public constant VELO = address(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
    address public gauge;
    address public want;
    address public lpToken0;
    address public lpToken1;

    /// @dev Arrays
    /// {rewards} - Array need to claim rewards
    /// {veloToUsdcPath} - Path from velo to usdc
    address[] public rewards;
    address[] public veloToUsdcPath;

    /// @dev Initializes the strategy. Sets parameters and saves routes.
    /// @notice see documentation for each variable above its respective declaration.
    constructor(
        address _vault,
        address _treasury,
        address _strategist,
        address _gauge
    ) public {
        __ReaperBaseStrategy_init(_vault, _treasury, _strategist);
        gauge = _gauge;
        want = IVeloGauge(gauge).stake();
        (lpToken0, lpToken1) = IVeloPair(want).tokens();

        // VELO, WETH, USDC
        veloToUsdcPath = [VELO, address(0x4200000000000000000000000000000000000006), USDC];
        rewards.push(VELO);
    }

    /// @dev Function that puts the funds to work.
    ///      It gets called whenever someone deposits in the strategy's vault contract.
    function _deposit() internal override onlyOwner {
        uint256 wantBalance = IERC20Upgradeable(want).balanceOf(address(this));
        if (wantBalance != 0) {
            uint256 wantId = IVeloGauge(gauge).tokenIds(want);
            IERC20Upgradeable(want).safeIncreaseAllowance(gauge, wantBalance);
            IVeloGauge(gauge).deposit(wantBalance, wantId);
        }
    }

    /// @dev Withdraws funds and sends them back to the vault.
    function _withdraw(uint256 _amount) internal override onlyOwner {
        uint256 wantBal = IERC20Upgradeable(want).balanceOf(address(this));
        if (wantBal < _amount) {

            // Calculate how much to cWant this is
            uint256 remaining = _amount - wantBal;
            IVeloGauge(gauge).withdraw(remaining);
        }
        IERC20Upgradeable(want).safeTransfer(vault, _amount);
    }

    /// @dev Core function of the strat, in charge of collecting and re-investing rewards.
    ///      1. Claims {VELO} from the {gauge}.
    ///      2. Claims fees in {USDC} for the harvest caller and treasury.
    ///      3. Swaps the remaining rewards for {want} using {VELODROME_ROUTER}.
    ///      4. Deposits and stakes into {gauge}.
    function _harvestCore() internal override returns (uint256 callerFee) {
        IVeloGauge(gauge).getReward(address(this), rewards);
        // All {VELO} is swapped to {USDC} here
        // Saves a swap because {USDC} is one of {want}'s underlying tokens
        callerFee = _chargeFees();
        _addLiquidity();
        deposit();
    }

    /// @dev Helper function to swap {_from} to {_to} given an {_amount}.
    function _swap(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        if (_from == _to || _amount == 0) {
            return;
        }

        IERC20Upgradeable(_from).safeIncreaseAllowance(VELODROME_ROUTER, _amount);
        IVeloRouter router = IVeloRouter(VELODROME_ROUTER);

        (, bool useStable) = router.getAmountOut(_amount, _from, _to);
        IVeloRouter.route[] memory routes = new IVeloRouter.route[](1);
        routes[0] = IVeloRouter.route({from: _from, to: _to, stable: useStable});
        router.swapExactTokensForTokens(_amount, 0, routes, address(this), block.timestamp);
    }


    /// @dev Core harvest function.
    ///      Charges fees based on the amount of USDC gained from reward
    function _chargeFees() internal returns (uint256 callFeeToUser){
        IERC20Upgradeable usdc = IERC20Upgradeable(USDC);
        for (uint256 i; i < veloToUsdcPath.length - 1; i++) {
            _swap(veloToUsdcPath[i],veloToUsdcPath[i+1],IERC20Upgradeable(veloToUsdcPath[i]).balanceOf(address(this)));
        }
        uint256 usdcFee = (usdc.balanceOf(address(this)) * totalFee) / PERCENT_DIVISOR;

        if (usdcFee != 0) {
            callFeeToUser = (usdcFee * callFee) / PERCENT_DIVISOR;
            uint256 treasuryFeeToVault = (usdcFee * treasuryFee) / PERCENT_DIVISOR;
            uint256 feeToStrategist = (treasuryFeeToVault * strategistFee) / PERCENT_DIVISOR;
            treasuryFeeToVault -= feeToStrategist;

            usdc.safeTransfer(msg.sender, callFeeToUser);
            usdc.safeTransfer(treasury, treasuryFeeToVault);
            usdc.safeTransfer(strategist, feeToStrategist);
        }
    }

    /// @dev Core harvest function.
    ///      Converts half of held {USDC} in {want}
    function _addLiquidity() internal {
        uint256 usdcBal = IERC20Upgradeable(USDC).balanceOf(address(this));
        if (usdcBal == 0) {
            return;
        }

        if (USDC == lpToken0) {
            _swap(USDC, lpToken1, usdcBal / 2);
        } else {
            _swap(USDC, lpToken0, usdcBal / 2);
        }

        uint256 lpToken0Bal = IERC20Upgradeable(lpToken0).balanceOf(address(this));
        uint256 lpToken1Bal = IERC20Upgradeable(lpToken1).balanceOf(address(this));
        IERC20Upgradeable(lpToken0).safeIncreaseAllowance(VELODROME_ROUTER, lpToken0Bal);
        IERC20Upgradeable(lpToken1).safeIncreaseAllowance(VELODROME_ROUTER, lpToken1Bal);
        IVeloRouter(VELODROME_ROUTER).addLiquidity(
            lpToken0,
            lpToken1,
            IVeloPair(want).stable(),
            lpToken0Bal,
            lpToken1Bal,
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    /// @dev Function to calculate the total {want} held by the strat.
    ///      It takes into account both the funds directly held by the contract and those into the {gauge}
    function balanceOf() public view override returns (uint256) {
        return balanceInGauge() + IERC20Upgradeable(want).balanceOf(address(this));
    }

    /// @dev Returns the amount of {want} staked into the {gauge}
    function balanceInGauge() public view returns (uint256) {
        return IVeloGauge(gauge).balanceOf(address(this));
    }


    /// @dev Withdraws all funds leaving rewards behind.
    function _reclaimWant() internal override {
        IVeloGauge(gauge).withdrawAll();
    }

    function setVeloToUsdcPath(address[] memory _path) external onlyOwner {
        require(_path[0] == VELO && _path[_path.length - 1] == USDC, "INVALID INPUT");
        veloToUsdcPath = _path;
    }
}