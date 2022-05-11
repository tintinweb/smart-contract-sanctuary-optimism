/**
 *Submitted for verification at optimistic.etherscan.io on 2022-05-10
*/

// File @openzeppelin/contracts/utils/introspection/[email protected]

// SPDX-License-Identifier: MIT
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

// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

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


// File @openzeppelin/contracts/token/ERC721/[email protected]

// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}


// File @openzeppelin/contracts/token/ERC721/extensions/[email protected]

// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}


// File @openzeppelin/contracts/utils/[email protected]

// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

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


// File @openzeppelin/contracts/utils/[email protected]

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


// File @openzeppelin/contracts/utils/[email protected]

// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

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


// File @openzeppelin/contracts/utils/introspection/[email protected]

// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}


// File @openzeppelin/contracts/token/ERC721/[email protected]

// OpenZeppelin Contracts v4.4.1 (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;







/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}


// File @openzeppelin/contracts/token/ERC721/extensions/[email protected]

// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}


// File @openzeppelin/contracts/token/ERC721/extensions/[email protected]

// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/ERC721Enumerable.sol)

pragma solidity ^0.8.0;


/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}


// File @openzeppelin/contracts/utils/[email protected]

// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}


// File base64-sol/[email protected]

pragma solidity >=0.6.0;

/// @title Base64
/// @author Brecht Devos - <[email protected]>
/// @notice Provides functions for encoding/decoding base64
library Base64 {
    string internal constant TABLE_ENCODE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    bytes  internal constant TABLE_DECODE = hex"0000000000000000000000000000000000000000000000000000000000000000"
                                            hex"00000000000000000000003e0000003f3435363738393a3b3c3d000000000000"
                                            hex"00000102030405060708090a0b0c0d0e0f101112131415161718190000000000"
                                            hex"001a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132330000000000";

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';

        // load the table into memory
        string memory table = TABLE_ENCODE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 3 bytes at a time
            for {} lt(dataPtr, endPtr) {}
            {
                // read 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // write 4 characters
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr( 6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(        input,  0x3F))))
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }

        return result;
    }

    function decode(string memory _data) internal pure returns (bytes memory) {
        bytes memory data = bytes(_data);

        if (data.length == 0) return new bytes(0);
        require(data.length % 4 == 0, "invalid base64 decoder input");

        // load the table into memory
        bytes memory table = TABLE_DECODE;

        // every 4 characters represent 3 bytes
        uint256 decodedLen = (data.length / 4) * 3;

        // add some extra buffer at the end required for the writing
        bytes memory result = new bytes(decodedLen + 32);

        assembly {
            // padding with '='
            let lastBytes := mload(add(data, mload(data)))
            if eq(and(lastBytes, 0xFF), 0x3d) {
                decodedLen := sub(decodedLen, 1)
                if eq(and(lastBytes, 0xFFFF), 0x3d3d) {
                    decodedLen := sub(decodedLen, 1)
                }
            }

            // set the actual output length
            mstore(result, decodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 4 characters at a time
            for {} lt(dataPtr, endPtr) {}
            {
               // read 4 characters
               dataPtr := add(dataPtr, 4)
               let input := mload(dataPtr)

               // write 3 bytes
               let output := add(
                   add(
                       shl(18, and(mload(add(tablePtr, and(shr(24, input), 0xFF))), 0xFF)),
                       shl(12, and(mload(add(tablePtr, and(shr(16, input), 0xFF))), 0xFF))),
                   add(
                       shl( 6, and(mload(add(tablePtr, and(shr( 8, input), 0xFF))), 0xFF)),
                               and(mload(add(tablePtr, and(        input , 0xFF))), 0xFF)
                    )
                )
                mstore(resultPtr, shl(232, output))
                resultPtr := add(resultPtr, 3)
            }
        }

        return result;
    }
}


// File contracts/ToColor.sol

pragma solidity >=0.8.0 <0.9.0;

library ToColor {
    bytes16 internal constant ALPHABET = '0123456789abcdef';

    function toColor(bytes3 value) internal pure returns (string memory) {
      bytes memory buffer = new bytes(6);
      for (uint256 i = 0; i < 3; i++) {
          buffer[i*2+1] = ALPHABET[uint8(value[i]) & 0xf];
          buffer[i*2] = ALPHABET[uint8(value[i]>>4) & 0xf];
      }
      return string(buffer);
    }
}


// File contracts/HexStrings.sol

pragma solidity ^0.8.0;

library HexStrings {
    bytes16 internal constant ALPHABET = '0123456789abcdef';

    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = '0';
        buffer[1] = 'x';
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = ALPHABET[value & 0xf];
            value >>= 4;
        }
        return string(buffer);
    }
}


// File contracts/LoogieShipMetadata.sol

pragma solidity >=0.8.0 <0.9.0;




library LoogieShipMetadata {

  using Strings for uint256;
  using ToColor for bytes3;
  using HexStrings for uint160;

  function tokenURI(uint id, bytes3 wheelColor, bytes3 mastheadColor, bytes3 flagColor, bytes3 flagAlternativeColor, bool loogieMasthead, bool loogieFlag, string memory svg) public pure returns (string memory) {
    return
      string(
          abi.encodePacked(
            'data:application/json;base64,',
            Base64.encode(
                bytes(
                      abi.encodePacked(
                          '{"name":"Loogie Ship #',id.toString(),
                          '", "description":"Loogie Ship #',id.toString(),
                          '", "external_url":"https://sailor.fancyloogies.com/ship/',
                          id.toString(),
                          '", "attributes": [{"trait_type": "Flag Color", "value": "#',
                          flagColor.toColor(),
                          '"},{"trait_type": "Flag Secondary Color", "value": "#',
                          flagAlternativeColor.toColor(),
                          '"},{"trait_type": "Wheel Color", "value": "#',
                          wheelColor.toColor(),
                          '"},{"trait_type": "Masthead Color", "value": "#',
                          mastheadColor.toColor(),
                          '"},{"trait_type": "Loogie Masthead", "value": ',
                          loogieMasthead ? 'true' : 'false',
                          '},{"trait_type": "Loogie Flag", "value": ',
                          loogieFlag ? 'true' : 'false',
                          '}], "image": "',
                          'data:image/svg+xml;base64,',
                          Base64.encode(bytes(svg)),
                          '"}'
                      )
                    )
                )
          )
      );
  }
}


// File contracts/LoogieShipRender.sol

pragma solidity >=0.8.0 <0.9.0;

library LoogieShipRender {

  using ToColor for bytes3;

  function renderDefs(bytes3 wheelColor, bytes3 mastheadColor, bytes3 flagColor, bytes3 flagAlternativeColor, bool loogieMasthead, bool loogieFlag) public pure returns (string memory) {
    string memory render = string(abi.encodePacked(
      '<defs>',
        '<style>',
          '.cls-1,.cls-12,.cls-17,.cls-18,.cls-22,.cls-4,.cls-26{fill:none;}',
          '.cls-2{isolation:isolate;}',
          '.cls-10,.cls-11,.cls-3,.cls-4,.cls-5,.cls-7,.cls-8,.cls-9{stroke:#42210b;}',
          '.cls-10,.cls-11,.cls-12,.cls-17,.cls-18,.cls-20,.cls-21,.cls-3,.cls-4,.cls-5,.cls-7,.cls-8,.cls-9,.cls-24,.cls-25,.cls-26{stroke-miterlimit:10;}',
          '.cls-3{fill:url(#linear-gradient);}',
          '.cls-4,.cls-24{stroke-linecap:round;}',
          '.cls-18,.cls-4{stroke-width:2px;}',
          '.cls-5,.cls-9{fill:#',flagColor.toColor(),';}',
          '.cls-19,.cls-6{fill:#cbcbcb;}',
          '.cls-14,.cls-6{mix-blend-mode:multiply;}',
          '.cls-7{fill:url(#linear-gradient-2);}',
          '.cls-8{fill:url(#linear-gradient-3);}',
          '.cls-9{stroke-width:1.09px;}',
          '.cls-10{fill:url(#linear-gradient-4);}',
          '.cls-11{fill:url(#linear-gradient-5);}',
          '.cls-12{stroke:#',wheelColor.toColor(),';stroke-width:3.81px;}',
          '.cls-13{clip-path:url(#clip-path);}',
          '.cls-15{fill:url(#linear-gradient-6);}',
          '.cls-16{fill:#754c24;}',
          '.cls-17,.cls-18{stroke:#754c24;}',
          '.cls-17{stroke-width:2.13px;}',
          '.cls-20,.cls-24,.cls-25{fill:#',mastheadColor.toColor(),';}',
          '.cls-20,.cls-21,.cls-22,.cls-24,.cls-25,.cls-26{stroke:#000;}',
          '.cls-21{fill:#fff;}',
          '.cls-22{stroke-width:1.11px;}',
          '.cls-23{fill:#',flagAlternativeColor.toColor(),';}',
        '</style>',
        '<linearGradient id="linear-gradient" x1="225.7" y1="217.21" x2="231.4" y2="217.21" gradientUnits="userSpaceOnUse">',
          '<stop offset="0" stop-color="#a57c52"/>',
          '<stop offset="1" stop-color="#603813"/>',
        '</linearGradient>',
        '<linearGradient id="linear-gradient-2" x1="132.43" y1="152" x2="145.69" y2="152" xlink:href="#linear-gradient"/>',
        '<linearGradient id="linear-gradient-3" x1="115.36" y1="81.99" x2="162.22" y2="81.99" gradientUnits="userSpaceOnUse">',
          '<stop offset="0" stop-color="#c59b6d"/>',
          '<stop offset="1" stop-color="#603813"/>',
        '</linearGradient>',
        '<linearGradient id="linear-gradient-4" x1="333.74" y1="147.55" x2="345.01" y2="147.55" xlink:href="#linear-gradient"/>',
        '<linearGradient id="linear-gradient-5" x1="116.69" y1="135.07" x2="309.22" y2="265.47" xlink:href="#linear-gradient-3"/>',
        '<clipPath id="clip-path">',
          '<path class="cls-1" d="M326.13,245.17c1.23,0,2.45.05,3.66.13,2.29-16.67,3-16.92,3-16.92H232.33l-4.18,16h-53.4c0,50.86,11.44,71.92,99.53,71.37a54.36,54.36,0,0,1,51.85-70.56Z"/>',
        '</clipPath>',
        '<linearGradient id="linear-gradient-6" x1="174.75" y1="263.16" x2="333.86" y2="263.16" gradientUnits="userSpaceOnUse">',
          '<stop offset="0" stop-color="#8b6239"/>',
          '<stop offset="1" stop-color="#603813"/>',
        '</linearGradient>',
      '</defs>'
      ));

      return render;
  }

  function renderShip(bytes3 wheelColor, bytes3 mastheadColor, bytes3 flagColor, bytes3 flagAlternativeColor, bool loogieMasthead, bool loogieFlag) public pure returns (string memory) {

    string memory masthead;
    string memory flag;

    if (loogieMasthead) {
      masthead = string(abi.encodePacked(
        '<path class="cls-20" d="M48.49,183.39s-1.76,5.12.91,6.59,6.54-1.15,10.31,1.09.44,12.21,15,18.11c18,7.32,21.13,7.87,25,10.58s1.61,6.46,4.32,13.7c6.69-3.1,4.35-13.77,4.35-13.77s8,4.39,13.74,1.46c-1.57-6.24-16.85-9.59-16.85-9.59s-6.88-2.17-11.14-7.21-9.29-10.43-15.72-14.13-12.21-5.09-12.94-9.3-3.89-8.48-7.63-7.83-9.24-3.21-9.24-3.21l-3.33,3s4.39,3.08,4.33,5.5A17.63,17.63,0,0,1,48.49,183.39Z"/>',
        '<path class="cls-20" d="M56.7,173.21s13.07-1.79,20,3.33,7.48,9.45,9.61,10.2c.69.24,3.86-.08,5.92,1.32s3.11,2.83,1.1,4.43-6-1-6-1a5,5,0,0,1,.17,2.68c-.39,1-1.89.16-2.72-1.19s-4.74-7.93-8.34-10.95-15.48-2.71-15.48-2.71"/>',
        '<circle class="cls-20" cx="43.68" cy="171.22" r="8.5"/>',
        '<circle class="cls-21" cx="36.52" cy="166.34" r="3.89"/>',
        '<circle class="cls-21" cx="40.6" cy="163.75" r="3.89"/>',
        '<circle cx="40.6" cy="163.75" r="1"/>',
        '<circle cx="35.08" cy="166.99" r="1"/>',
        '<path class="cls-22" d="M38,177.34a7.2,7.2,0,0,0,9.26-4.09"/>'
      ));
    } else {
      masthead = string(abi.encodePacked(
        '<circle class="cls-21" cx="47.27" cy="161.33" r="5.83"/>',
        '<circle cx="45.29" cy="159.92" r="1.5"/>',
        '<path class="cls-24" d="M73.1,166.34c8.26-1.44,28-9.26,25.8,3.39,7.49-2.18,10,7.26,5.13,8.47,5.3,1.51,6.62,13.59-3.8,10.45"/>',
        '<path class="cls-25" d="M35.77,168.34s11,25.07,29.63,34.48,24.54.43,36.38,9.09c7.61,5.56,9,11.22,6.56,17.3-3.63,8.9-2.72,14.17-2.72,14.17s12.08-2.22,15.07-11.26a32.67,32.67,0,0,0,16.16,9.08,23.66,23.66,0,0,0-7.26-18.53c-4.14-4.14-7.09-4.81-9.26-10.53S109.55,184.8,88,172.44C60,156.4,35.77,168.34,35.77,168.34Z"/>',
        '<circle class="cls-21" cx="56.11" cy="166.37" r="5.83"/>',
        '<circle cx="54.71" cy="165.52" r="1.5"/>',
        '<path class="cls-25" d="M44.81,170.55c1.82-13.75-26-12.9-5.4-1.55-4.31-2.37-13.71-2.27-8.06,3.21C35.14,176,44.23,175,44.81,170.55Z"/>',
        '<path class="cls-26" d="M68,189.46s5.87,12.69,24.5,9.77C94,186.2,79,178.38,79,178.38"/>',
        '<path class="cls-20" d="M41.5,167.19s-2.72.72-3.54,4.45"/>'
      ));
    }

    if (loogieFlag) {
      flag = string(abi.encodePacked(
        '<path class="cls-23" d="M105.35,131.91c3.06-1.37,6.46-2.54,9.76-1l1.73-6.14c-2.65-1.5-4.23-4.22-5.18-7-1.42-3.55-8.29,0-5.57,4.31,1,3.32-5.46,2.81-4,7.09C102.22,129.39,103.41,132.51,105.35,131.91Z"/>',
        '<path class="cls-23" d="M114.42,157.18c1.08-3.18,2.54-6.46,5.94-7.8L117,143.93c-2.9.92-6,.22-8.67-1-3.57-1.37-5.62,6.09-.64,7,3.12,1.43-1.61,6,2.51,7.72C110.44,157.75,113.54,159,114.42,157.18Z"/>',
        '<path class="cls-23" d="M171.46,131.91c-3.07-1.37-6.47-2.54-9.76-1L160,124.81c2.65-1.5,4.23-4.22,5.18-7,1.43-3.55,8.29,0,5.57,4.31-1,3.32,5.46,2.81,3.95,7.09C174.58,129.39,173.4,132.51,171.46,131.91Z"/>',
        '<path class="cls-23" d="M162.38,157.18c-1.07-3.18-2.53-6.46-5.93-7.8.15,0,3.24-5.82,3.5-5.4,4.59,2.39,9.37-4.4,12,1.14,1.75,4.87-4.12,3.17-4,7.5C170.11,155.91,165.65,160.24,162.38,157.18Z"/>',
        '<path class="cls-23" d="M155.86,121.83A11.16,11.16,0,1,0,138.2,108.7,11.16,11.16,0,1,0,121,122.27a21.27,21.27,0,1,0,34.84-.44Zm-7.72-17a8.9,8.9,0,1,1-8.9,8.9A8.89,8.89,0,0,1,148.14,104.87Zm-19.88,0a8.9,8.9,0,1,1-8.91,8.9A8.9,8.9,0,0,1,128.26,104.87Zm24.61,32.42H123.81v-2h29.06Z"/>'
      ));
    } else {
      flag = string(abi.encodePacked(
        '<polygon class="cls-23" points="187.25 123.39 181.98 104.15 138.63 123.3 100.18 103.16 94.85 122.63 137.9 145.18 187.25 123.39"/>',
        '<polygon class="cls-23" points="173.77 91.71 108.8 91.71 137.81 106.91 173.77 91.71"/>',
        '<polygon class="cls-23" points="192.26 141.67 138.78 164.16 90.57 138.27 85.22 157.79 106.41 169.17 177.76 169.17 197.52 160.86 192.26 141.67"/>'
      ));
    }

    string memory render = string(abi.encodePacked(
      '<g id="ship" class="cls-2">',
        '<g id="Layer_1" data-name="Layer 1">',
          '<polygon class="cls-3" points="231.4 235.82 225.7 235.82 226.56 198.59 230.54 198.59 231.4 235.82"/>',
          '<circle class="cls-4" cx="230.7" cy="185.42" r="12.87"/>',
          '<line class="cls-4" x1="225.45" y1="169.28" x2="235.95" y2="201.55"/>',
          '<line class="cls-4" x1="246.84" y1="180.17" x2="214.56" y2="190.67"/>',
          '<line class="cls-4" x1="238.4" y1="170.29" x2="223" y2="200.54"/>',
          '<line class="cls-4" x1="245.82" y1="193.11" x2="215.58" y2="177.72"/>',
          '<path class="cls-5" d="M394.77,120.67c-13.62-3.82-15.26-3.82-9.81-21.25S340.28,88,340.28,88l.55,28.34s24.52-4.91,20.7,11.44c-2,8.41,10.54,13.44,26.16,8.17,10.32-3.48,24-4.9,31.06,5.45C423.11,124.48,408.39,124.48,394.77,120.67Z"/>',
          '<path class="cls-6" d="M340.28,88l.55,28.34a28.26,28.26,0,0,1,10.1-.54c-.46-9.52.38-19,.24-28.63C344.9,87.42,340.28,88,340.28,88Z"/>',
          '<polygon class="cls-7" points="145.69 223.66 132.43 223.66 134.43 80.35 143.69 80.35 145.69 223.66"/>',
          '<path class="cls-6" d="M143.69,80.35h-9.26l-1.36,97.74,12,2.67Z"/>',
          '<polygon class="cls-8" points="152.22 93.97 125.36 93.97 115.36 70 162.22 70 152.22 93.97"/>',
          '<polygon class="cls-9" points="179.12 90.71 103.37 90.71 81.58 170.26 200.91 170.26 179.12 90.71"/>',
          '<polygon class="cls-10" points="345.01 208.39 333.74 208.39 335.44 86.7 343.31 86.7 345.01 208.39"/>',
          '<path class="cls-11" d="M326.13,255.76a43.13,43.13,0,0,1,13.94,2.31c1.75-11.37,3.5-22.15,3.5-22.15,1.47-10.36,9.47-18.14,19.36-20.85a1.72,1.72,0,0,0,1.08-1.22l9-39.78c-1.18.41-65.9,11.43-66.51,13.4-4.49,13-13.62,26.51-29,25.92H224.72a1.69,1.69,0,0,0-1.61,1.16l-4.93,16.75a1.69,1.69,0,0,1-1.61,1.16H157a12.35,12.35,0,0,1-11.75-8.53c-2-7.67-6.65-14.57-13.9-18.09L42.53,161l-3.09,8.72s74.83,43.68,75.92,58.94c8.74,101.78,153.1,95.18,170.55,94.91,1.51,0,3-.1,4.42-.21a43.27,43.27,0,0,1,35.8-67.59Z"/>',
          '<g class="wheel">',
            '<circle class="cls-12" cx="326.36" cy="299.54" r="30.05"/>',
            '<line class="cls-12" x1="326.36" y1="259.91" x2="326.36" y2="339.17"/>',
            '<line class="cls-12" x1="365.99" y1="299.54" x2="286.73" y2="299.54"/>',
            '<line class="cls-12" x1="354.39" y1="271.51" x2="298.34" y2="327.56"/>',
            '<line class="cls-12" x1="354.39" y1="327.56" x2="298.34" y2="271.51"/>',
            '<animateTransform attributeName="transform" attributeType="XML" type="rotate" from="0 326.36 299.54" to="360 326.36 299.54" begin="0s" dur="4s" repeatCount="indefinite" additive="sum" />',
          '</g>',
          '<g class="cls-13">',
            '<g class="cls-14">',
              '<path class="cls-15" d="M326.13,245.17c1.23,0,2.45.05,3.66.13,2.29-16.67,4.07-34.72,4.07-34.72H229.24l-8.17,33.78H174.75c0,50.86,11.44,71.92,99.53,71.37a54.36,54.36,0,0,1,51.85-70.56Z"/>',
            '</g>',
            '<circle class="cls-16" cx="271.29" cy="247.93" r="2.9"/>',
            '<circle class="cls-16" cx="281.37" cy="241.09" r="2.9"/>',
            '<circle class="cls-16" cx="259.51" cy="253.66" r="2.72"/>',
            '<line class="cls-17" x1="257.57" y1="253.12" x2="289.45" y2="262.25"/>',
            '<line class="cls-18" x1="271.47" y1="248.18" x2="282.23" y2="271.33"/>',
            '<line class="cls-18" x1="281.28" y1="241.36" x2="284.41" y2="267.52"/>',
          '</g>',
          masthead,
          flag,
        '</g>',
      '</g>'
      ));

    return render;
  }
}


// File contracts/LoogieShip.sol

pragma solidity ^0.8.0;




//learn more: https://docs.openzeppelin.com/contracts/3.x/erc721

// GET LISTED ON OPENSEA: https://testnets.opensea.io/get-listed/step-two

abstract contract FancyLoogiesContract {
  function renderTokenById(uint256 id) external virtual view returns (string memory);
  function hasNft(address nft, uint256 id) external virtual view returns (bool);
  function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external virtual;
}

abstract contract LoogieCoinContract {
  function mint(address to, uint256 amount) virtual public;
}

contract LoogieShip is ERC721Enumerable, IERC721Receiver {

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  FancyLoogiesContract fancyLoogies;
  LoogieCoinContract loogieCoin;

  address bow;
  address mustache;
  address contactLenses;
  address eyelashes;

  address payable public constant recipient =
    payable(0x51f63a79D75206Fc3e1f29Caa58eb9B732F06f52);

  uint256 public constant limit = 1000;
  uint256 public price = 0.02 ether;

  mapping (uint256 => bytes3) public wheelColor;
  mapping (uint256 => bytes3) public mastheadColor;
  mapping (uint256 => bytes3) public flagColor;
  mapping (uint256 => bytes3) public flagAlternativeColor;
  mapping (uint256 => bool) public loogieMasthead;
  mapping (uint256 => bool) public loogieFlag;

  mapping(uint8 => mapping(uint256 => uint256)) public crewById;

  constructor(address _fancyLoogies, address _bow, address _mustache, address _contactLenses, address _eyelashes, address _loogieCoin) ERC721("LoogieShips", "LOOGIESHIP") {
    // RELEASE THE LOOGIE SHIPS!
    fancyLoogies = FancyLoogiesContract(_fancyLoogies);
    bow = _bow;
    mustache = _mustache;
    contactLenses = _contactLenses;
    eyelashes = _eyelashes;
    loogieCoin = LoogieCoinContract(_loogieCoin);
  }

  function mintItem()
      public
      payable
      returns (uint256)
  {
      require(_tokenIds.current() < limit, "DONE MINTING");
      require(msg.value >= price, "NOT ENOUGH");

      _tokenIds.increment();

      uint256 id = _tokenIds.current();
      _mint(msg.sender, id);

      loogieCoin.mint(msg.sender, 20000);

      bytes32 predictableRandom = keccak256(abi.encodePacked( id, blockhash(block.number-1), msg.sender, address(this) ));
      wheelColor[id] = bytes2(predictableRandom[3]) | ( bytes2(predictableRandom[4]) >> 8 ) | ( bytes3(predictableRandom[5]) >> 16 );
      mastheadColor[id] = bytes2(predictableRandom[6]) | ( bytes2(predictableRandom[7]) >> 8 ) | ( bytes3(predictableRandom[8]) >> 16 );
      flagColor[id] = bytes2(predictableRandom[9]) | ( bytes2(predictableRandom[10]) >> 8 ) | ( bytes3(predictableRandom[11]) >> 16 );
      flagAlternativeColor[id] = bytes2(predictableRandom[12]) | ( bytes2(predictableRandom[13]) >> 8 ) | ( bytes3(predictableRandom[14]) >> 16 );

      loogieMasthead[id] = uint8(predictableRandom[15]) > 200;
      loogieFlag[id] = uint8(predictableRandom[16]) > 200;

      (bool success, ) = recipient.call{value: msg.value}("");
      require(success, "could not send");

      return id;
  }

  function tokenURI(uint256 id) public view override returns (string memory) {
      require(_exists(id), "not exist");
      return LoogieShipMetadata.tokenURI(id, wheelColor[id], mastheadColor[id], flagColor[id], flagAlternativeColor[id], loogieMasthead[id], loogieFlag[id], generateSVGofTokenById(id));
  }

  function generateSVGofTokenById(uint256 id) internal view returns (string memory) {

    string memory svg = string(abi.encodePacked(
      '<svg width="450" height="350" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
        renderTokenById(id),
      '</svg>'
    ));

    return svg;
  }

  // Visibility is `public` to enable it being called by other contracts for composition.
  function renderTokenById(uint256 id) public view returns (string memory) {
    require(_exists(id), "not exist");

    string memory render;

    render = string(abi.encodePacked(render, LoogieShipRender.renderDefs(wheelColor[id], mastheadColor[id], flagColor[id], flagAlternativeColor[id], loogieMasthead[id], loogieFlag[id])));

    render = string(abi.encodePacked(render, '<g id="loogie-ship">'));

    if (crewById[0][id] != 0) {
      render = string(abi.encodePacked(render, '<g id="captain" class="captain" transform="scale(0.3 0.3) translate(710 420)">', fancyLoogies.renderTokenById(crewById[0][id]), '</g>'));
    }

    if (crewById[2][id] != 0) {
      render = string(abi.encodePacked(render, '<g id="officer" class="officer" transform="scale(0.3 0.3) translate(405 520)">', fancyLoogies.renderTokenById(crewById[2][id]), '</g>'));
    }

    if (crewById[3][id] != 0) {
      render = string(abi.encodePacked(render, '<g id="seaman" class="seaman" transform="scale(0.3 0.3) translate(260 -20)">', fancyLoogies.renderTokenById(crewById[3][id]), '</g>'));
    }

    render = string(abi.encodePacked(render, LoogieShipRender.renderShip(wheelColor[id], mastheadColor[id], flagColor[id], flagAlternativeColor[id], loogieMasthead[id], loogieFlag[id])));

    if (crewById[1][id] != 0) {
      render = string(abi.encodePacked(render, '<g id="engineer" class="engineer" transform="scale(-0.3 0.3) translate(-990 770)">', fancyLoogies.renderTokenById(crewById[1][id]), '</g>'));
    }

    render = string(abi.encodePacked(render, '</g>'));

    return render;
  }

  function removeCrew(uint8 crew, uint256 id) external {
    require(msg.sender == ownerOf(id), "only the owner can remove a crew member!");

    require(crewById[crew][id] != 0, "the ship doesn't have this crew member!");
    fancyLoogies.transferFrom(address(this), ownerOf(id), crewById[crew][id]);
    crewById[crew][id] = 0;
  }

  // to receive ERC721 tokens
  function onERC721Received(
      address operator,
      address from,
      uint256 tokenId,
      bytes calldata data) external override returns (bytes4) {

      (uint256 shipId, uint8 crew) = abi.decode(data, (uint256,uint8));

      require(ownerOf(shipId) == from, "you can only add crew to a LoogieShip you own!");
      require(msg.sender == address(fancyLoogies), "only FancyLoogies can be part of the crew!");
      require(crew < 4, "only 4 crew members per ship!");
      require(crewById[crew][shipId] == 0, "the ship already have this crew member!");

      //Captain
      if (crew == 0) {
        require(fancyLoogies.hasNft(bow, tokenId), "the Captain must wear a Bow!");
      }

      //Engineer
      if (crew == 1) {
        require(fancyLoogies.hasNft(mustache, tokenId), "the Chief Engineer must wear a Mustache!");
      }

      //Officer
      if (crew == 2) {
        require(fancyLoogies.hasNft(contactLenses, tokenId), "the Deck Officer must wear a pair of Contact Lenses");
      }

      //Seaman
      if (crew == 3) {
        require(fancyLoogies.hasNft(eyelashes, tokenId), "the Seaman must wear Eyelashes");
      }

      crewById[crew][shipId] = tokenId;

      return this.onERC721Received.selector;
    }
}