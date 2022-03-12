/**
 *Submitted for verification at optimistic.etherscan.io on 2022-01-24
*/

// Sources flattened with hardhat v2.7.1 https://hardhat.org

// File @openzeppelin/contracts/utils/[email protected]

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Context.sol)

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

// OpenZeppelin Contracts v4.4.0 (access/Ownable.sol)

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


// File @openzeppelin/contracts/utils/introspection/[email protected]

// OpenZeppelin Contracts v4.4.0 (utils/introspection/IERC165.sol)

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
interface IERC165 {
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


// File @openzeppelin/contracts/token/ERC721/[email protected]

// OpenZeppelin Contracts v4.4.0 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}


// File @openzeppelin/contracts/interfaces/[email protected]

// OpenZeppelin Contracts v4.4.0 (interfaces/IERC721.sol)

pragma solidity ^0.8.0;


// File @openzeppelin/contracts/token/ERC20/[email protected]

// OpenZeppelin Contracts v4.4.0 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
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


// File @openzeppelin/contracts/interfaces/[email protected]

// OpenZeppelin Contracts v4.4.0 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;


// File @openzeppelin/contracts/utils/introspection/[email protected]

// OpenZeppelin Contracts v4.4.0 (utils/introspection/ERC165Checker.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library used to query support of an interface declared via {IERC165}.
 *
 * Note that these functions return the actual result of the query: they do not
 * `revert` if an interface is not supported. It is up to the caller to decide
 * what to do in these cases.
 */
library ERC165Checker {
    // As per the EIP-165 spec, no interface should ever match 0xffffffff
    bytes4 private constant _INTERFACE_ID_INVALID = 0xffffffff;

    /**
     * @dev Returns true if `account` supports the {IERC165} interface,
     */
    function supportsERC165(address account) internal view returns (bool) {
        // Any contract that implements ERC165 must explicitly indicate support of
        // InterfaceId_ERC165 and explicitly indicate non-support of InterfaceId_Invalid
        return
            _supportsERC165Interface(account, type(IERC165).interfaceId) &&
            !_supportsERC165Interface(account, _INTERFACE_ID_INVALID);
    }

    /**
     * @dev Returns true if `account` supports the interface defined by
     * `interfaceId`. Support for {IERC165} itself is queried automatically.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsInterface(address account, bytes4 interfaceId) internal view returns (bool) {
        // query support of both ERC165 as per the spec and support of _interfaceId
        return supportsERC165(account) && _supportsERC165Interface(account, interfaceId);
    }

    /**
     * @dev Returns a boolean array where each value corresponds to the
     * interfaces passed in and whether they're supported or not. This allows
     * you to batch check interfaces for a contract where your expectation
     * is that some interfaces may not be supported.
     *
     * See {IERC165-supportsInterface}.
     *
     * _Available since v3.4._
     */
    function getSupportedInterfaces(address account, bytes4[] memory interfaceIds)
        internal
        view
        returns (bool[] memory)
    {
        // an array of booleans corresponding to interfaceIds and whether they're supported or not
        bool[] memory interfaceIdsSupported = new bool[](interfaceIds.length);

        // query support of ERC165 itself
        if (supportsERC165(account)) {
            // query support of each interface in interfaceIds
            for (uint256 i = 0; i < interfaceIds.length; i++) {
                interfaceIdsSupported[i] = _supportsERC165Interface(account, interfaceIds[i]);
            }
        }

        return interfaceIdsSupported;
    }

    /**
     * @dev Returns true if `account` supports all the interfaces defined in
     * `interfaceIds`. Support for {IERC165} itself is queried automatically.
     *
     * Batch-querying can lead to gas savings by skipping repeated checks for
     * {IERC165} support.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsAllInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool) {
        // query support of ERC165 itself
        if (!supportsERC165(account)) {
            return false;
        }

        // query support of each interface in _interfaceIds
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            if (!_supportsERC165Interface(account, interfaceIds[i])) {
                return false;
            }
        }

        // all interfaces supported
        return true;
    }

    /**
     * @notice Query if a contract implements an interface, does not check ERC165 support
     * @param account The address of the contract to query for support of an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return true if the contract at account indicates support of the interface with
     * identifier interfaceId, false otherwise
     * @dev Assumes that account contains a contract that supports ERC165, otherwise
     * the behavior of this method is undefined. This precondition can be checked
     * with {supportsERC165}.
     * Interface identification is specified in ERC-165.
     */
    function _supportsERC165Interface(address account, bytes4 interfaceId) private view returns (bool) {
        bytes memory encodedParams = abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId);
        (bool success, bytes memory result) = account.staticcall{gas: 30000}(encodedParams);
        if (result.length < 32) return false;
        return success && abi.decode(result, (bool));
    }
}


// File @openzeppelin/contracts/utils/[email protected]

// OpenZeppelin Contracts v4.4.0 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
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


// File @openzeppelin/contracts/utils/cryptography/[email protected]

// OpenZeppelin Contracts v4.4.0 (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        // Check the signature length
        // - case 65: r,s,v signature (standard)
        // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098) _Available since v4.1._
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            return tryRecover(hash, r, vs);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s;
        uint8 v;
        assembly {
            s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            v := add(shr(255, vs), 27)
        }
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}


// File @openzeppelin/contracts/utils/[email protected]

// OpenZeppelin Contracts v4.4.0 (utils/Address.sol)

pragma solidity ^0.8.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
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


// File @openzeppelin/contracts/security/[email protected]

// OpenZeppelin Contracts v4.4.0 (security/Pausable.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}


// File @openzeppelin/contracts/security/[email protected]

// OpenZeppelin Contracts v4.4.0 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}


// File Contracts/Exchange.sol

pragma solidity ^0.8.0;







interface IExchangeRegistry {
    function addRegistrant(address registrant) external;

    function removeRegistrant(address registrant) external;

    function cancelOrder(bytes memory signature) external;

    function isOrderCancelled(bytes memory signature) external view returns (bool);

    function setRoyalty(address _erc721address, address payable _payoutAddress, uint256 _payoutPerMille) external;

    function getRoyaltyPayoutAddress(address _erc721address) external view returns (address payable);

    function getRoyaltyPayoutRate(address _erc721address) external view returns (uint256);
}

contract ExchangeV2 is Ownable, Pausable, ReentrancyGuard {
    using ERC165Checker for address;

    bytes4 private InterfaceId_ERC721 = 0x80ac58cd; // Magic number that detects 721s

    address payable _makerWallet;
    uint256 private _makerFeePerMille = 25;
    uint256 private _maxRoyaltyPerMille = 150;

    IExchangeRegistry registry;

    IERC20 wethContract;

    event SellOrderFilled(address indexed seller, address payable buyer, address indexed erc721address, uint256 indexed tokenId, uint256 price);
    event BuyOrderFilled(address indexed seller, address payable buyer, address indexed erc721address, uint256 indexed tokenId, uint256 price);
    event DutchAuctionFilled(address indexed seller, address payable buyer, address indexed erc721address, uint256 indexed tokenId, uint256 price);


    /* This contains all data of the SellOrder */
    struct ERC721SellOrder {

        /* This is version 2 */
        uint256 exchangeVersion;

        /* Seller of the NFT */
        address payable seller;

        /* Contract address of NFT */
        address erc721address;

        /* Token id of NFT to sell */
        uint256 tokenId;

        /* Expiration in unix timestamp */
        uint256 expiration;

        /* Price in wei */
        uint256 price;

    }

    /* This contains all data of the BuyOrder */
    struct ERC721BuyOrder {

        /* This should be 2 */
        uint256 exchangeVersion;

        /* Seller of the NFT */
        address payable buyer;

        /* Contract address of NFT */
        address erc721address;

        /* Token id of NFT to sell */
        uint256 tokenId;

        /* Expiration in unix timestamp */
        uint256 expiration;

        /* Price in wei */
        uint256 price;

    }

    struct ERC721DutchAuctionOrder {

        /* This should be 2 */
        uint256 exchangeVersion;

        /* Should always be "DutchAuction" */
        string action;

        /* Seller of the NFT */
        address payable seller;

        /* Contract address of NFT */
        address erc721address;

        /* Token id of NFT to sell */
        uint256 tokenId;

        /* Start time in unix timestamp */
        uint256 startTime;

        /* End time in unix timestamp */
        uint256 endTime;

        /* Price in wei */
        uint256 startPrice;

        /* Price in wei */
        uint256 endPrice;
    }

    function setRegistryContract(address registryAddress) external onlyOwner {
        registry = IExchangeRegistry(registryAddress);
    }

    function setWethContract(address wethAddress) external onlyOwner {
        wethContract = IERC20(wethAddress);
    }

    /*
    * @dev External trade function. This accepts the details of the sell order and signed sell
    * order (the signature) as a meta-transaction.
    *
    * Emits a {SellOrderFilled} event via `_fillSellOrder`.
    */
    function fillSellOrder(
        uint256 exchangeVersion,
        address payable seller,
        address erc721address,
        uint256 tokenId,
        uint256 expiration,
        uint256 price,
        bytes memory signature,
        address payable buyer
    ) external payable whenNotPaused nonReentrant {

        require(msg.value >= price, "You're transaction doesn't have the required payment");

        ERC721SellOrder memory sellOrder = ERC721SellOrder(
            exchangeVersion,
            seller,
            erc721address,
            tokenId,
            expiration,
            price
        );

        _fillSellOrder(sellOrder, signature, buyer);
    }

    /*
    * @dev Executes a trade given a sell order.
    *
    * Emits a {SellOrderFilled} event.
    */
    function _fillSellOrder(ERC721SellOrder memory sellOrder, bytes memory signature, address payable buyer) internal {

        /* Make sure the order is not cancelled */
        require(!isOrderCancelled(signature), "This order has been cancelled.");

        /* First check signature */
        require(_validateSellerSignature(sellOrder, signature), "Signature is not valid for SellOrder.");

        /* Check that address is actually ERC721 */
        require(sellOrder.erc721address.supportsInterface(InterfaceId_ERC721), "IS_NOT_721_TOKEN");


        // Check not expired
        require((block.timestamp < sellOrder.expiration), "This sell order has expired.");

        IERC721 erc721 = IERC721(sellOrder.erc721address);

        /* require seller owns it */
        require((erc721.ownerOf(sellOrder.tokenId) == sellOrder.seller), "The seller does not own this NFT");
        // Might be unnecessary

        /* require is approved for all */
        require(erc721.isApprovedForAll(sellOrder.seller, address(this)), "The Trading contract is not approved to operate this NFT");

        /* Do the trade */

        // Step 1: Send the ETH
        uint256 royaltyPayout = (registry.getRoyaltyPayoutRate(sellOrder.erc721address) * msg.value) / 1000;
        uint256 makerPayout = (_makerFeePerMille * msg.value) / 1000;
        uint256 remainingPayout = msg.value - royaltyPayout - makerPayout;


        if (royaltyPayout > 0) {
            Address.sendValue(registry.getRoyaltyPayoutAddress(sellOrder.erc721address), royaltyPayout);
        }

        Address.sendValue(_makerWallet, makerPayout);
        Address.sendValue(sellOrder.seller, remainingPayout);

        // Step 2: Transfer the NFT
        erc721.safeTransferFrom(sellOrder.seller, buyer, sellOrder.tokenId);

        registry.cancelOrder(signature);
        emit SellOrderFilled(sellOrder.seller, buyer, sellOrder.erc721address, sellOrder.tokenId, sellOrder.price);
    }

    /*
    * @dev Sets the royalty as a int out of 1000 that the creator should receive and the address to pay.
    */
    function setRoyalty(address _erc721address, address payable _payoutAddress, uint256 _payoutPerMille) external {
        require(_payoutPerMille <= _maxRoyaltyPerMille, "Royalty must be between 0 and 15%");
        require(_erc721address.supportsInterface(InterfaceId_ERC721), "IS_NOT_721_TOKEN");

        Ownable ownableNFTContract = Ownable(_erc721address);
        require(_msgSender() == ownableNFTContract.owner());

        registry.setRoyalty(_erc721address, _payoutAddress, _payoutPerMille);
    }

    /*
    * @dev Gets the royalty payout address.
    */
    function getRoyaltyPayoutAddress(address _erc721address) public view returns (address) {
        return registry.getRoyaltyPayoutAddress(_erc721address);
    }

    /*
    * @dev Gets the royalty as a int out of 1000 that the creator should receive.
    */
    function getRoyaltyPayoutRate(address _erc721address) public view returns (uint256) {
        return registry.getRoyaltyPayoutRate(_erc721address);
    }


    /*
    * @dev Sets the wallet for the exchange.
    */
    function setMakerWallet(address payable _newMakerWallet) external onlyOwner {
        _makerWallet = _newMakerWallet;
    }

    /*
    * @dev Pauses trading on the exchange. To be used for emergencies.
    */
    function pause() external onlyOwner {
        _pause();
    }

    /*
    * @dev Resumes trading on the exchange. To be used for emergencies.
    */
    function unpause() external onlyOwner {
        _unpause();
    }

    /*
    * @dev Cancels a buy order.
    */
    function cancelBuyOrder(
        uint256 exchangeVersion,
        address payable buyer,
        address erc721address,
        uint256 tokenId,
        uint256 expiration,
        uint256 price,
        bytes memory signature
    ) external {
        require((buyer == _msgSender() || owner() == _msgSender()), "Caller must be Exchange Owner or Order Signer");

        ERC721BuyOrder memory buyOrder = ERC721BuyOrder(
            exchangeVersion,
            buyer,
            erc721address,
            tokenId,
            expiration,
            price
        );

        require(_validateBuyerSignature(buyOrder, signature), "Signature is not valid for BuyOrder.");

        registry.cancelOrder(signature);
    }

    /*
    * @dev Cancels an order.
    */
    function cancelSellOrder(
        uint256 exchangeVersion,
        address payable seller,
        address erc721address,
        uint256 tokenId,
        uint256 expiration,
        uint256 price,
        bytes memory signature
    ) external {
        require((seller == _msgSender() || owner() == _msgSender()), "Caller must be Exchange Owner or Order Signer");

        ERC721SellOrder memory sellOrder = ERC721SellOrder(
            exchangeVersion,
            seller,
            erc721address,
            tokenId,
            expiration,
            price
        );

        require(_validateSellerSignature(sellOrder, signature), "Signature is not valid for BuyOrder.");

        registry.cancelOrder(signature);
    }

    /*
    * @dev Check if an order has been cancelled.
    */
    function isOrderCancelled(bytes memory signature) public view returns (bool) {
        return registry.isOrderCancelled(signature);
    }

    /*
    * @dev Validate the sell order against the signature of the meta-transaction.
    */
    function _validateSellerSignature(ERC721SellOrder memory sellOrder, bytes memory signature) internal pure returns (bool) {

        bytes32 message = ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(
                sellOrder.exchangeVersion,
                sellOrder.seller,
                sellOrder.erc721address,
                sellOrder.tokenId,
                sellOrder.expiration,
                sellOrder.price
            )));

        address recoveredSeller = ECDSA.recover(message, signature);

        return recoveredSeller == sellOrder.seller;
    }

    /*
    * @dev Validate the sell order against the signature of the meta-transaction.
    */
    function _validateBuyerSignature(ERC721BuyOrder memory buyOrder, bytes memory signature) internal pure returns (bool) {

        bytes32 message = ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(
                buyOrder.exchangeVersion,
                buyOrder.buyer,
                buyOrder.erc721address,
                buyOrder.tokenId,
                buyOrder.expiration,
                buyOrder.price
            )));

        address recoveredBuyer = ECDSA.recover(message, signature);

        return recoveredBuyer == buyOrder.buyer;
    }

    /*
    * Withdraw just in case Ether is accidentally sent to this contract.
    */
    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    /*
    * @dev For testing purposes. Shows what hashed message should be signed to create a sell order meta-transaction.
    */
    function checkPreMessage(address seller,
        address erc721address,
        uint256 tokenId,
        uint256 expiration,
        uint256 price
    ) public pure returns (bytes32) {
        // this recreates the message that was signed on the client
        bytes32 premessage = keccak256(abi.encodePacked(
                seller,
                erc721address,
                tokenId,
                expiration,
                price
            ));
        return premessage;
    }

    function checkSigningMessage(address seller,
        address erc721address,
        uint256 tokenId,
        uint256 expiration,
        uint256 price
    ) public pure returns (bytes32) {
        // this recreates the message that was signed on the client
        bytes32 signingMsg = ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(
                seller,
                erc721address,
                tokenId,
                expiration,
                price
            )));
        return signingMsg;
    }

    function recover(bytes32 message, bytes memory signature) public pure returns (address) {
        return ECDSA.recover(message, signature);
    }

    function fillBuyOrder(
        uint256 exchangeVersion,
        address payable buyer,
        address erc721address,
        uint256 tokenId,
        uint256 expiration,
        uint256 price,
        bytes memory signature,
        address payable seller
    ) external payable whenNotPaused nonReentrant {
        ERC721BuyOrder memory buyOrder = ERC721BuyOrder(
            exchangeVersion,
            buyer,
            erc721address,
            tokenId,
            expiration,
            price
        );

        _fillBuyOrder(buyOrder, signature, seller);
    }

    function _fillBuyOrder(ERC721BuyOrder memory buyOrder, bytes memory signature, address payable seller) internal {

        /* Make sure the order is not cancelled */
        require(!isOrderCancelled(signature), "This order has been cancelled.");

        /* First check signature */
        require(_validateBuyerSignature(buyOrder, signature), "Signature is not valid for BuyOrder.");

        /* Check that address is actually ERC721 */
        require(buyOrder.erc721address.supportsInterface(InterfaceId_ERC721), "IS_NOT_721_TOKEN");

        // Check not expired
        require((block.timestamp < buyOrder.expiration), "This buy order has expired.");

        IERC721 erc721 = IERC721(buyOrder.erc721address);

        /* require seller owns it */
        require((erc721.ownerOf(buyOrder.tokenId) == seller), "The seller does not own this NFT");
        // Might be unnecessary

        /* require is approved for all */
        require(erc721.isApprovedForAll(seller, address(this)), "The Trading contract is not approved to operate this NFT");

        /* require buyer has enough money */
        require(wethContract.balanceOf(buyOrder.buyer) > buyOrder.price, "The buyer does not have enough WETH");

        /* require that we have enough allowance */
        require(wethContract.allowance(buyOrder.buyer, address(this)) > buyOrder.price, "The buyer must allow us to withdraw their WETH");

        /* Do the trade */

        // Step 1: Send the WETH
        uint256 royaltyPayout = (registry.getRoyaltyPayoutRate(buyOrder.erc721address) * buyOrder.price) / 1000;
        uint256 makerPayout = (_makerFeePerMille * buyOrder.price) / 1000;
        uint256 remainingPayout = buyOrder.price - royaltyPayout - makerPayout;

        if (royaltyPayout > 0) {
            wethContract.transferFrom(buyOrder.buyer, registry.getRoyaltyPayoutAddress(buyOrder.erc721address), royaltyPayout);
        }

        wethContract.transferFrom(buyOrder.buyer, _makerWallet, makerPayout);
        // Pay marketplace
        wethContract.transferFrom(buyOrder.buyer, seller, remainingPayout);

        // Step 2: Transfer the NFT
        erc721.safeTransferFrom(seller, buyOrder.buyer, buyOrder.tokenId);

        registry.cancelOrder(signature);
        emit BuyOrderFilled(seller, buyOrder.buyer, buyOrder.erc721address, buyOrder.tokenId, buyOrder.price);
    }

    /*
    * @dev External trade function. This accepts the details of the dutch auction order and signed dutch auction
    * order (the signature) as a meta-transaction.
    *
    * Emits a {DutchAuctionOrderFilled} event via `_fillDutchAuctionOrder`.
    */
    function fillDutchAuction(
        uint256 exchangeVersion,
        address payable seller,
        address erc721address,
        uint256 tokenId,
        uint256 startTime,
        uint256 endTime,
        uint256 startPrice,
        uint256 endPrice,
        bytes memory signature,
        address payable buyer
    ) external payable whenNotPaused nonReentrant {

        uint256 currentPrice = _calculateCurrentPrice(startTime, endTime, startPrice, endPrice);
        require(msg.value >= currentPrice, "The current price is higher than the payment submitted.");

        ERC721DutchAuctionOrder memory dutchAuctionOrder = ERC721DutchAuctionOrder(
            exchangeVersion,
            "DutchAuction",
            seller,
            erc721address,
            tokenId,
            startTime,
            endTime,
            startPrice,
            endPrice
        );

        _fillDutchAuction(dutchAuctionOrder, signature, buyer);
    }

    function currentPriceOfDutchAuction(
        address payable seller,
        address erc721address,
        uint256 tokenId,
        uint256 startTime,
        uint256 endTime,
        uint256 startPrice,
        uint256 endPrice,
        bytes memory signature,
        address payable buyer
    ) public view returns (uint256) {
        return _calculateCurrentPrice(startTime, endTime, startPrice, endPrice);
    }

    function _fillDutchAuction(
        ERC721DutchAuctionOrder memory dutchAuctionOrder,
        bytes memory signature,
        address payable buyer
    ) internal {
        /* Make sure the order is not cancelled */
        require(!isOrderCancelled(signature), "This order has been cancelled.");

        /* First check signature */
        require(_validateDutchAuctionSignature(dutchAuctionOrder, signature), "Signature is not valid for DutchAuctionOrder.");

        /* Check that address is actually ERC721 */
        require(dutchAuctionOrder.erc721address.supportsInterface(InterfaceId_ERC721), "IS_NOT_721_TOKEN");

        // Check not expired
        require((block.timestamp < dutchAuctionOrder.endTime), "This sell order has expired.");

        IERC721 erc721 = IERC721(dutchAuctionOrder.erc721address);

        /* require seller owns it */
        require((erc721.ownerOf(dutchAuctionOrder.tokenId) == dutchAuctionOrder.seller), "The seller does not own this NFT");
        // Might be unnecessary

        /* require is approved for all */
        require(erc721.isApprovedForAll(dutchAuctionOrder.seller, address(this)), "The Trading contract is not approved to operate this NFT");

        /* Do the trade */

        // Step 1: Send the ETH
        uint256 royaltyPayout = (registry.getRoyaltyPayoutRate(dutchAuctionOrder.erc721address) * msg.value) / 1000;
        uint256 makerPayout = (_makerFeePerMille * msg.value) / 1000;
        uint256 remainingPayout = msg.value - royaltyPayout - makerPayout;

        if (royaltyPayout > 0) {
            Address.sendValue(registry.getRoyaltyPayoutAddress(dutchAuctionOrder.erc721address), royaltyPayout);
        }

        Address.sendValue(_makerWallet, makerPayout);
        Address.sendValue(dutchAuctionOrder.seller, remainingPayout);

        // Step 2: Transfer the NFT
        erc721.safeTransferFrom(dutchAuctionOrder.seller, buyer, dutchAuctionOrder.tokenId);

        registry.cancelOrder(signature);
        emit DutchAuctionFilled(dutchAuctionOrder.seller, buyer, dutchAuctionOrder.erc721address, dutchAuctionOrder.tokenId, msg.value);
    }

    function _calculateCurrentPrice(uint256 startTime, uint256 endTime, uint256 startPrice, uint256 endPrice) internal view returns (uint256) {
        uint256 auctionDuration = (endTime - startTime);
        uint256 timeRemaining = (endTime - block.timestamp);

        uint256 perMilleRemaining = (1000000000000000 / auctionDuration) / (1000000000000 / timeRemaining);

        uint256 variableAmount = startPrice - endPrice;
        uint256 variableAmountRemaining = (perMilleRemaining * variableAmount) / 1000;
        return endPrice + variableAmountRemaining;
    }

    function _validateDutchAuctionSignature(
        ERC721DutchAuctionOrder memory dutchAuctionOrder,
        bytes memory signature
    ) internal pure returns (bool) {

        bytes32 message = ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(
                dutchAuctionOrder.exchangeVersion,
                dutchAuctionOrder.action,
                dutchAuctionOrder.seller,
                dutchAuctionOrder.erc721address,
                dutchAuctionOrder.tokenId,
                dutchAuctionOrder.startTime,
                dutchAuctionOrder.endTime,
                dutchAuctionOrder.startPrice,
                dutchAuctionOrder.endPrice
            )));

        address recoveredSeller = ECDSA.recover(message, signature);

        return recoveredSeller == dutchAuctionOrder.seller;
    }

}