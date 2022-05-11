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


// File @openzeppelin/contracts/access/[email protected]

// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
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


// File @openzeppelin/contracts/access/[email protected]

// OpenZeppelin Contracts v4.4.1 (access/AccessControl.sol)

pragma solidity ^0.8.0;




/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return _roles[role].adminRole;
    }

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
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
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


// File contracts/SailorLoogiesGameAward1Render.sol

pragma solidity >=0.8.0 <0.9.0;

library SailorLoogiesGameAward1Render {

  function renderAward(string memory color, string memory secondaryColor, string memory week, string memory reward) public pure returns (string memory) {

    string memory render = string(abi.encodePacked(
      '<defs>',
        '<style>',
          '.cls-1{fill:#331708;}.cls-2{stroke:#4c250f;stroke-width:22px;fill:url(#linear-gradient);}.cls-2,.cls-3{stroke-linejoin:round;}.cls-10,.cls-3{fill:none;}.cls-3{stroke:#774335;stroke-linecap:round;stroke-width:20px;}.cls-4{fill:#4c250f;}.cls-5{fill:url(#linear-gradient-2);}.cls-6{opacity:0.35;}.cls-7{fill:#fff;}.cls-10,.cls-7,.cls-8,.cls-9{stroke:#000;stroke-miterlimit:10;}.cls-7,.cls-8,.cls-9{stroke-width:6.73px;}.cls-8{fill:#',color,';}.cls-11,.cls-9{fill:#',secondaryColor,';}.cls-10{stroke-width:6.83px;}.cls-12{font-size:36px;font-family:Bicyclette-Bold, Bicyclette;font-weight:700;}.cls-13{font-size:24px}',
        '</style>',
        '<linearGradient id="linear-gradient" x1="580.06" y1="132.51" x2="363.38" y2="519.29" gradientUnits="userSpaceOnUse">',
          '<stop offset="0" stop-color="#c59b6d"/>',
          '<stop offset="1" stop-color="#603813"/>',
        '</linearGradient>',
        '<linearGradient id="linear-gradient-2" x1="310.38" y1="508" x2="591.87" y2="508" gradientUnits="userSpaceOnUse">',
          '<stop offset="0" stop-color="#ffa13b"/>',
          '<stop offset="1" stop-color="#ffc73b"/>',
        '</linearGradient>',
      '</defs>',
      '<g class="sailor-loogies-game-award award1">',
        '<path class="cls-1" d="M787.6,353.35c-.68-29.51-2.86-57.15-6.31-79.94-3.84-25.29-8.69-41.61-14.85-49.9a17.33,17.33,0,0,0-6.6-5.34c-2.09-1-4.79-1.93-8.19-3.15-19.57-7-60.29-21.54-79-68.57a17.3,17.3,0,0,0-16.13-11H242.38a17.3,17.3,0,0,0-16.13,11c-18.76,47-59.47,61.58-79,68.57-3.41,1.22-6.1,2.18-8.19,3.15a17.29,17.29,0,0,0-6.61,5.34c-13.82,18.61-20,79.27-21.16,129.84-2.24,97.74,12,148.9,18.16,166.36a17.38,17.38,0,0,0,13.07,11.19c45.93,8.8,73.44,30.56,81.74,64.7h0a17.27,17.27,0,0,0,16.84,13.21H657.79a17.28,17.28,0,0,0,16.85-13.21c8.3-34.14,35.8-55.9,81.74-64.7a17.39,17.39,0,0,0,13.07-11.2C775.65,502.25,789.85,451.09,787.6,353.35Z"/>',
        '<path class="cls-2" d="M239.21,575.24c-11.52-47.33-53.62-65.26-89.58-72.15a7.31,7.31,0,0,1-5.53-4.72c-28.27-79.5-19.15-259,1.61-286.88a7.14,7.14,0,0,1,2.78-2.24c12.2-5.65,68.63-17.68,92.32-77.08a7.37,7.37,0,0,1,6.84-4.68H661.74a7.38,7.38,0,0,1,6.85,4.68c23.69,59.4,80.12,71.43,92.31,77.08a7.25,7.25,0,0,1,2.79,2.24c20.75,27.93,29.87,207.38,1.6,286.88a7.31,7.31,0,0,1-5.52,4.72c-36,6.89-78.07,24.82-89.58,72.15a7.33,7.33,0,0,1-7.13,5.58H246.33A7.32,7.32,0,0,1,239.21,575.24Z"/>',
        '<path class="cls-3" d="M250.75,122.89H665.22a7.38,7.38,0,0,1,6.84,4.68C695.75,187,752.19,198.38,764.38,204"/>',
        '<path class="cls-3" d="M658.68,578H250.11a7,7,0,0,1-6.84-4.68c-20-65.51-81.86-67.85-94.05-73.5"/>',
        '<path class="cls-4" d="M571.79,550.67H323.67A16.68,16.68,0,0,0,307,534V492.87a16.68,16.68,0,0,0,16.69-16.68H571.79a16.68,16.68,0,0,0,16.69,16.68V534A16.68,16.68,0,0,0,571.79,550.67Z"/>',
        '<path class="cls-5" d="M575.19,545.24H327.06a16.68,16.68,0,0,0-16.68-16.68V487.44a16.68,16.68,0,0,0,16.68-16.68H575.19a16.68,16.68,0,0,0,16.68,16.68v41.12A16.68,16.68,0,0,0,575.19,545.24Z"/>',
        '<g class="cls-6">',
          '<path d="M112.09,324a18.42,18.42,0,0,0,1,4.26c.09-2.88.2-5.79.32-8.71A13.72,13.72,0,0,0,112.09,324Z"/>',
          '<path d="M793.61,335.34c-.69-30.15-3.18-63.89-8-90.25-22.69,6.92-52.41,27.8-81.23,50.2-21.53,6.54-45.75.62-83.49-14.39,9-4,19.56-10.39,24.2-19.27,14.5-72.38-125.81-96.74-169.93-83.41-31.46,6.14-59.86,23.95-71.72,32.17-34.8-2.52-82.38,6.3-119.44,15.55-4.92-31-48.25-42.67-68.19-19-12.66-13.45-35.07-15.93-50.39-5.38-16.42,10.25-22.51,33.55-13.68,50.35-9.07-.71-22.39,2.44-33.15,7.75-1.53,10.89-2.74,22.57-3.65,34.43,6.17,2.31,14.83,4.11,26.91,5-12.78,4.86-24.51,12.27-28.42,20.44-.12,2.92-.23,5.83-.32,8.71C119.49,346,152.44,346,168.52,339c36.37,39.69,87.79,94.4,144.9,112.89,62.85,26.69,141.09,25.39,205.44,8.05,60.18,74.83,147.85-3,83.41-37.06,89.63-64.43,118.65,16.53,184.45,32C791.25,427.21,794.83,388,793.61,335.34Z"/>',
        '</g>',
        '<circle class="cls-7" cx="169.3" cy="192.67" r="39.24"/>',
        '<circle cx="152.99" cy="191.21" r="10.08"/>',
        '<path class="cls-8" d="M130.39,249.1C127,276.22,243.79,472.91,468.54,442.82,627.92,421.48,605.84,361,707.4,367.59c41.38,12.22,87.46,69.59,114.73,61.12s11.28-75.23,15-105.32,32.92-98.74-4.7-116.61-73.35,44.2-107.2,54.54-72.41-6.58-150.46-40.43S427.55,154.12,314.7,177.63,133.21,226.53,130.39,249.1Z"/>',
        '<path class="cls-8" d="M519.32,425s51.73,54.54,78.06,42.32,41.37-28.21,38.55-46.08S614.3,407.08,609.6,393"/>',
        '<path class="cls-8" d="M397.07,173.87s38.56-30.1,81.82-38.56C508.48,129.52,628.41,124,658.5,204c10.59,28.12-41.38,41.38-41.38,41.38"/>',
        '<circle class="cls-7" cx="231.24" cy="191.75" r="39.24"/>',
        '<circle cx="220.16" cy="191.58" r="10.08"/>',
        '<path class="cls-8" d="M185.53,249.82c-36.33-86-195,13.86-36.62,9.45-33.14.92-87.34,33.59-35.83,46.1C148,314.41,197.29,277.64,185.53,249.82Z"/>',
        '<path class="cls-9" d="M154.84,241.6s-13.34,13.51-5.38,37.91"/>',
        '<path class="cls-10" d="M548.9,417.07S560.34,439,587,451.4"/>',
        '<path class="cls-10" d="M576.55,412.3s3.82,17.16,28.61,26.7"/>',
        '<path class="cls-10" d="M597.53,405.62s1.91,12.4,19.07,21"/>',
        '<path class="cls-10" d="M746,307.4s45.52-2.35,74.4-15.71"/>',
        '<path class="cls-10" d="M732.85,286.48s60.07-4.26,88.28-24.17"/>',
        '<path class="cls-10" d="M747.84,266s41.84-6.17,70.87-36.56"/>',
        '<path class="cls-10" d="M743.14,325.27s45.25,1,74,14.6"/>',
        '<path class="cls-10" d="M729.58,344.21s60,4.86,88,25.05"/>',
        '<path class="cls-10" d="M745,365.71s41.12,5.68,69.85,36.36"/>',
        '<path class="cls-11" d="M446.29,224.79c-5.66-14.59-16.27-24.18-34.54-13.49-30.94,22.47,14.19,86.65-9.17,121.12-10.25,15.14-5.3,48.5,9.51,32.34C434.56,340.23,455.85,249.48,446.29,224.79Z"/>',
        '<path class="cls-11" d="M505.85,245.82c-4.24-13.07-13.08-22-29.62-13.52-28.23,18.19,8.21,76.67-14,105.75-9.73,12.76-7,42.26,6.75,28.81C489.93,346.45,513,267.93,505.85,245.82Z"/>',
        '<path class="cls-11" d="M555.8,258.63c-3.74-10.36-11-17.28-24.07-10.06-22.13,15.29,8.55,61.17-8.44,85-7.46,10.48-4.53,34,6.15,22.9C545.65,339.61,562.11,276.14,555.8,258.63Z"/>',
        '<path class="cls-11" d="M602.1,272c-3.12-8.65-9.22-14.42-20.09-8.4-18.47,12.77,7.14,51.07-7,71-6.22,8.74-3.78,28.4,5.14,19.11C593.63,339.6,607.37,286.62,602.1,272Z"/>',
        '<path class="cls-11" d="M642.71,277c-2.87-7.57-8.31-12.56-17.79-7.1-16.06,11.5,7,44.82-5.17,62.54-5.35,7.78-2.91,25,4.79,16.74C636.24,336.62,647.57,289.82,642.71,277Z"/>',
        '<path class="cls-11" d="M678.22,281c-2.43-5.65-6.74-9.26-13.77-4.8-11.83,9.28,6.84,33.85-1.85,47.73-3.81,6.1-1.38,19.14,4.21,12.57C675.29,326.55,682.34,290.58,678.22,281Z"/>',
        '<path class="cls-11" d="M709.07,285.93c-1.93-4.47-5.33-7.33-10.89-3.8-9.37,7.34,5.4,26.78-1.46,37.76-3,4.83-1.1,15.14,3.32,9.95C706.75,322,712.33,293.49,709.07,285.93Z"/>',
        '<circle class="cls-11" cx="394.57" cy="397.37" r="13.48"/>',
        '<circle class="cls-11" cx="449.94" cy="398.2" r="11.17"/>',
        '<circle class="cls-11" cx="510.51" cy="389.8" r="10.3"/>',
        '<circle class="cls-11" cx="562.13" cy="379.99" r="9.27"/>',
        '<circle class="cls-11" cx="611.9" cy="369.57" r="7.49"/>',
        '<circle class="cls-11" cx="656.67" cy="354.09" r="5.97"/>',
        '<circle class="cls-11" cx="691.42" cy="346.9" r="5.08"/>',
        '<path class="cls-10" d="M236.27,346.27s28.84,18.81,60.18,8.78,84-77.74,62.7-110.34S299,218.38,299,218.38"/>',
        '<path class="cls-8" d="M301.57,319.47s32.3,75.37,64.72,57,59.08-41,32.43-59-49.79-6.07-69.52-16.58"/>',
        '<path class="cls-10" d="M355.42,320.71s17.9,10.07,34.36,14"/>',
        '<path class="cls-10" d="M331.72,322.79s20.51,19.39,42.94,26.68"/>',
        '<path class="cls-10" d="M323.39,333.37S333,354,352.44,361.57"/>',
        '<path class="cls-10" d="M446,174.81s29.16-21.63,58.31-26.33"/>',
        '<path class="cls-10" d="M482.65,179.51s29.15-21.63,58.3-26.33"/>',
        '<path class="cls-10" d="M517.44,186.09s29.16-21.63,58.31-26.33"/>',
        '<path class="cls-10" d="M548.48,197.38s29.15-21.63,58.3-26.33"/>',
        '<path class="cls-10" d="M579.51,207.72s15-14.1,44.2-18.81"/>',
        '<path class="cls-10" d="M602.08,220.89s4.7-9.41,33.85-14.11"/>',
        '<text class="cls-12" transform="translate(327.98 505.59)"><tspan x="35">WEEK ',week,'</tspan><tspan class="cls-13" x="35" y="29">REWARD ',reward,'</tspan></text>',
      '</g>'
      ));

    return render;
  }
}


// File contracts/SailorLoogiesGameAward2Render.sol

pragma solidity >=0.8.0 <0.9.0;

library SailorLoogiesGameAward2Render {

  function renderAward(string memory color, string memory secondaryColor, string memory week, string memory reward) public pure returns (string memory) {

    string memory render = string(abi.encodePacked(
      '<defs>',
        '<style>',
          '.cls-1{fill:#331708;}.cls-2{stroke:#4c250f;stroke-width:22px;fill:url(#linear-gradient);}.cls-2,.cls-3{stroke-linejoin:round;}.cls-11,.cls-3{fill:none;}.cls-3{stroke:#774335;stroke-linecap:round;stroke-width:20px;}.cls-4{fill:#4c250f;}.cls-5{fill:url(#linear-gradient-2);}.cls-6{font-size:36px;font-family:Bicyclette-Bold, Bicyclette;font-weight:700;}.cls-7{opacity:0.35;}.cls-8{fill:#fff;}.cls-11,.cls-8,.cls-9{stroke:#000;stroke-miterlimit:10;stroke-width:6px;}.cls-9{fill:#',color,';}.cls-10{fill:#',secondaryColor,';}.cls-12{font-size:24px}',
        '</style>',
        '<linearGradient id="linear-gradient" x1="739.17" y1="132.51" x2="522.48" y2="519.29" gradientUnits="userSpaceOnUse">',
          '<stop offset="0" stop-color="#c59b6d"/>',
          '<stop offset="1" stop-color="#603813"/>',
        '</linearGradient>',
        '<linearGradient id="linear-gradient-2" x1="469.48" y1="508" x2="750.98" y2="508" gradientUnits="userSpaceOnUse">',
          '<stop offset="0" stop-color="#ffa13b"/>',
          '<stop offset="1" stop-color="#ffc73b"/>',
        '</linearGradient>',
      '</defs>',
      '<g class="sailor-loogies-game-award award2">',
        '<path class="cls-1" d="M946.7,353.35c-.67-29.51-2.86-57.15-6.31-79.94-3.83-25.29-8.69-41.61-14.84-49.9a17.36,17.36,0,0,0-6.61-5.34c-2.09-1-4.78-1.93-8.19-3.15-19.57-7-60.29-21.54-79-68.57a17.3,17.3,0,0,0-16.13-11H401.49a17.29,17.29,0,0,0-16.13,11c-18.76,47-59.48,61.58-79.05,68.57-3.4,1.22-6.1,2.18-8.19,3.15a17.26,17.26,0,0,0-6.6,5.34c-13.83,18.61-20,79.27-21.16,129.84-2.25,97.74,11.94,148.9,18.15,166.36a17.4,17.4,0,0,0,13.07,11.19c45.94,8.8,73.44,30.56,81.74,64.7h0a17.28,17.28,0,0,0,16.84,13.21H816.9a17.27,17.27,0,0,0,16.84-13.21c8.3-34.14,35.8-55.9,81.74-64.7a17.39,17.39,0,0,0,13.07-11.2C934.76,502.25,949,451.09,946.7,353.35Z"/>',
        '<path class="cls-2" d="M398.31,575.24c-11.52-47.33-53.62-65.26-89.58-72.15a7.33,7.33,0,0,1-5.53-4.72c-28.26-79.5-19.14-259,1.61-286.88a7.25,7.25,0,0,1,2.79-2.24c12.19-5.65,68.62-17.68,92.31-77.08a7.37,7.37,0,0,1,6.85-4.68H820.84a7.37,7.37,0,0,1,6.85,4.68c23.69,59.4,80.12,71.43,92.31,77.08a7.17,7.17,0,0,1,2.79,2.24c20.76,27.93,29.87,207.38,1.61,286.88a7.33,7.33,0,0,1-5.53,4.72c-36,6.89-78.06,24.82-89.58,72.15a7.32,7.32,0,0,1-7.12,5.58H405.43A7.33,7.33,0,0,1,398.31,575.24Z"/>',
        '<path class="cls-3" d="M409.86,122.89H824.32a7.4,7.4,0,0,1,6.85,4.68C854.86,187,911.3,198.38,923.49,204"/>',
        '<path class="cls-3" d="M817.79,578H409.21a7,7,0,0,1-6.84-4.68c-19.95-65.51-81.86-67.85-94.05-73.5"/>',
        '<path class="cls-4" d="M730.9,550.67H482.77A16.68,16.68,0,0,0,466.09,534V492.87a16.68,16.68,0,0,0,16.68-16.68H730.9a16.68,16.68,0,0,0,16.68,16.68V534A16.68,16.68,0,0,0,730.9,550.67Z"/>',
        '<path class="cls-5" d="M734.29,545.24H486.17a16.68,16.68,0,0,0-16.69-16.68V487.44a16.68,16.68,0,0,0,16.69-16.68H734.29A16.68,16.68,0,0,0,751,487.44v41.12A16.68,16.68,0,0,0,734.29,545.24Z"/>',
        '<text class="cls-6" transform="translate(487.08 505.59)"><tspan x="35">WEEK ',week,'</tspan><tspan class="cls-12" x="35" y="29">REWARD ',reward,'</tspan></text>',
        '<g class="cls-7">',
          '<path d="M373.15,144.28l-1,.41c-4.4,2-8.14,6.08-11.21,12.29A105,105,0,0,0,373.15,144.28Z"/>',
          '<path d="M900.77,352c-28.29-17.49-60.63-37.48-90.06-52.67-.88-9.92-4.9-16.91-64.92-50.36-44.11-24.58-141.92-29-220.51-32.46-38.16-1.71-71.12-3.18-88.53-6.72-27.21-5.53-33.89-27-39.27-44.24-3.15-10.11-5.87-18.85-12.43-21.82-3.35-1.52-7.26-1.33-11.9.53A105,105,0,0,1,360.93,157c-6.34,12.82-9.82,34.63-10.39,65.23-.47,24.83,1.15,49,2,59.61-16.13,9.73-23.1,21.6-29,33.4A41.71,41.71,0,0,0,274,312.68c-.9.59-1.76,1.23-2.6,1.89-.51,9.05-.86,18.07-1.07,26.79a745.21,745.21,0,0,0,2.54,85.06c5.68-.06,10.66.06,14.78.4-4.27,2.87-8.94,6.28-13.72,10,1.31,11.71,2.84,22,4.45,30.86a122.93,122.93,0,0,1,32.71-5.55c34.09-1.37,103-16.28,169.66-30.7,55.12-11.93,107.18-23.19,134.75-25.75,8.86-.82,20.08-2.12,33.07-3.63l5.45-.63c5.25,6.37,13.32,15.69,23.1,25.38,23.68,23.47,45.6,37.87,65.14,42.82l4.1,1-.38-4.22c-.71-7.76-6.17-15.71-12-24.12-7.06-10.28-14.36-20.9-11.45-29.85,2.57-7.93,8.36-14.49,13.71-19.18,24.08-1.76,49.17-2.88,73.26-2.57,67.09.89,111.89,12.71,133.17,35.13,1.6,1.69,3.14,3.45,4.62,5.26,1.87-13.76,3.45-29.87,4.4-48.5C937.77,374.89,920,363.92,900.77,352Z"/>',
        '</g>',
        '<circle class="cls-8" cx="235.93" cy="312.97" r="38.77"/>',
        '<path class="cls-9" d="M47.48,414.43s210.84-34.11,248.66-24.81c-22.32,13-60.77,47.13-62,61.4S249,426.21,311,423.73,554.35,373,615.51,367.3c67-6.2,271.61-40.31,329.9,21.08S977.66,589.92,1047.73,624c-34.73-155.65-44-198.44-35.35-223.86s152.55-89.92,172.4-88.06c-70.7-21.7-178,55.81-209,49S817.66,258.16,755,244.52s-285.25-53.33-395,1.24c-38.45,19.22-31,49.61-57.68,69.45S47.48,414.43,47.48,414.43Z"/>',
        '<path class="cls-9" d="M356.09,251.75S343.69,125.25,373.45,112s9.92,54.57,62.84,65.32,243.09,2.48,308.41,38.86,62.84,40.51,63.66,51.26"/>',
        '<path class="cls-9" d="M650.16,355.94s47.32,63.77,93.2,75.37c-1.49-16.47-29.12-37.2-23.28-55.17s26.42-29,26.42-29"/>',
        '<path class="cls-9" d="M351.54,294.33S397,296,400.32,335.67,392.88,382.8,383,386.11"/>',
        '<path class="cls-9" d="M343.27,317.48s39.69,28.12,24,52.92-26.46,18.19-26.46,18.19"/>',
        '<circle cx="219.81" cy="311.54" r="9.96"/>',
        '<circle class="cls-8" cx="297.12" cy="312.07" r="38.77"/>',
        '<circle cx="286.18" cy="311.9" r="9.96"/>',
        '<path class="cls-10" d="M398.69,259.16l9-2.8,23.5,68.28q-2.62,1.22-5.25,2.39Z"/>',
        '<polygon class="cls-10" points="415.82 254.15 431.83 250.35 450.46 317.27 437.43 322.1 415.82 254.15"/>',
        '<polygon class="cls-10" points="439.78 248.68 455.67 245.72 470.64 310.73 457.12 315 439.78 248.68"/>',
        '<polygon class="cls-10" points="463.61 244.42 479.48 242.15 491.3 305.01 477.48 308.74 463.61 244.42"/>',
        '<polygon class="cls-10" points="487.42 241.18 503.29 239.54 512.29 300.09 498.26 303.29 487.42 241.18"/>',
        '<polygon class="cls-10" points="511.23 238.88 527.09 237.84 533.54 295.95 519.35 298.63 511.23 238.88"/>',
        '<polygon class="cls-10" points="535.02 237.47 550.87 237.03 554.99 292.59 540.67 294.75 535.02 237.47"/>',
        '<polygon class="cls-10" points="558.79 236.95 574.61 237.07 576.61 290 562.18 291.64 558.79 236.95"/>',
        '<polygon class="cls-10" points="582.5 237.28 598.27 237.98 598.37 288.19 583.85 289.31 582.5 237.28"/>',
        '<polygon class="cls-10" points="606.14 238.47 621.84 239.73 620.23 287.16 605.64 287.76 606.14 238.47"/>',
        '<polygon class="cls-10" points="629.66 240.5 645.27 242.32 642.16 286.93 627.53 287 629.66 240.5"/>',
        '<polygon class="cls-10" points="653.05 243.37 668.56 245.75 664.13 287.48 649.48 287.02 653.05 243.37"/>',
        '<polygon class="cls-10" points="676.28 247.08 691.65 250.01 686.11 288.83 671.46 287.84 676.28 247.08"/>',
        '<polygon class="cls-10" points="699.3 251.61 714.53 255.09 708.08 290.97 693.44 289.45 699.3 251.61"/>',
        '<polygon class="cls-10" points="722.1 256.96 737.16 260.98 730.01 293.92 715.4 291.87 722.1 256.96"/>',
        '<polygon class="cls-10" points="744.65 263.12 759.52 267.66 751.88 297.66 737.31 295.08 744.65 263.12"/>',
        '<polygon class="cls-10" points="766.91 270.07 781.58 275.13 773.64 302.2 759.14 299.09 766.91 270.07"/>',
        '<polygon class="cls-10" points="788.85 277.79 803.3 283.36 795.27 307.52 780.86 303.89 788.85 277.79"/>',
        '<polygon class="cls-10" points="810.46 286.28 824.67 292.34 816.75 313.63 802.45 309.47 810.46 286.28"/>',
        '<polygon class="cls-10" points="831.71 295.5 845.66 302.05 838.06 320.5 823.88 315.83 831.71 295.5"/>',
        '<polygon class="cls-10" points="852.58 305.44 866.26 312.45 859.17 328.13 845.12 322.96 852.58 305.44"/>',
        '<polygon class="cls-10" points="873.04 316.07 886.45 323.53 880.04 336.49 866.15 330.83 873.04 316.07"/>',
        '<polygon class="cls-10" points="893.16 327.4 899.76 331.32 893.91 342.51 887.02 339.47 893.16 327.4"/>',
        '<path class="cls-9" d="M421,343.12c2.48-.83,162.89-77.73,220.77-57.06-5,9.93-39.69,7.45-72.76,21.5s-92.61,39.69-96.74,60.36"/>',
        '<path class="cls-11" d="M399.24,232.1s174.91-47.4,382.5,26.16"/>',
      '</g>'
      ));

    return render;
  }
}


// File contracts/SailorLoogiesGameAward3Render.sol

pragma solidity >=0.8.0 <0.9.0;

library SailorLoogiesGameAward3Render {

  function renderAward(string memory color, string memory secondaryColor, string memory week, string memory reward) public pure returns (string memory) {

    string memory render = string(abi.encodePacked(
      '<defs>',
        '<style>',
          '.cls-1{fill:#331708;}.cls-2{stroke:#4c250f;stroke-width:22px;fill:url(#linear-gradient);}.cls-2,.cls-3{stroke-linejoin:round;}.cls-3{fill:none;stroke:#774335;stroke-linecap:round;stroke-width:20px;}.cls-4{opacity:0.35;}.cls-5{fill:#fff;}.cls-5,.cls-6{stroke:#000;stroke-miterlimit:10;stroke-width:6.08px;}.cls-6{fill:#',color,';}.cls-7{fill:#',secondaryColor,';}.cls-8{fill:#4c250f;}.cls-9{fill:url(#linear-gradient-2);}.cls-10{font-size:36px;font-family:Bicyclette-Bold, Bicyclette;font-weight:700;}.cls-11{font-size:24px}',
        '</style>',
        '<linearGradient id="linear-gradient" x1="595.32" y1="132.51" x2="378.64" y2="519.29" gradientUnits="userSpaceOnUse">',
          '<stop offset="0" stop-color="#c59b6d"/>',
          '<stop offset="1" stop-color="#603813"/>',
        '</linearGradient>',
        '<linearGradient id="linear-gradient-2" x1="193.23" y1="438.09" x2="474.72" y2="438.09" gradientUnits="userSpaceOnUse">',
          '<stop offset="0" stop-color="#ffa13b"/>',
          '<stop offset="1" stop-color="#ffc73b"/>',
        '</linearGradient>',
      '</defs>',
      '<g class="sailor-loogies-game-award award3">',
        '<path class="cls-1" d="M802.86,353.35c-.68-29.51-2.86-57.15-6.32-79.94-3.83-25.29-8.68-41.61-14.84-49.9a17.29,17.29,0,0,0-6.61-5.34c-2.09-1-4.78-1.93-8.19-3.15-19.57-7-60.28-21.54-79-68.57a17.3,17.3,0,0,0-16.13-11H257.64a17.3,17.3,0,0,0-16.13,11c-18.76,47-59.48,61.58-79,68.57-3.41,1.22-6.1,2.18-8.2,3.15a17.33,17.33,0,0,0-6.6,5.34c-13.83,18.61-20,79.27-21.16,129.84-2.25,97.74,12,148.9,18.16,166.36a17.37,17.37,0,0,0,13.06,11.19c45.94,8.8,73.44,30.56,81.75,64.7h0a17.27,17.27,0,0,0,16.84,13.21H673.05a17.27,17.27,0,0,0,16.84-13.21c8.31-34.14,35.81-55.9,81.74-64.7a17.36,17.36,0,0,0,13.07-11.2C790.91,502.25,805.11,451.09,802.86,353.35Z"/>',
        '<path class="cls-2" d="M254.46,575.24C243,527.91,200.84,510,164.88,503.09a7.31,7.31,0,0,1-5.52-4.72c-28.27-79.5-19.15-259,1.61-286.88a7.14,7.14,0,0,1,2.78-2.24c12.19-5.65,68.62-17.68,92.32-77.08a7.36,7.36,0,0,1,6.84-4.68H677a7.36,7.36,0,0,1,6.84,4.68c23.69,59.4,80.12,71.43,92.32,77.08a7.14,7.14,0,0,1,2.78,2.24c20.76,27.93,29.88,207.38,1.61,286.88a7.31,7.31,0,0,1-5.53,4.72c-36,6.89-78.06,24.82-89.57,72.15a7.34,7.34,0,0,1-7.13,5.58H261.59A7.33,7.33,0,0,1,254.46,575.24Z"/>',
        '<path class="cls-3" d="M266,122.89H680.47a7.39,7.39,0,0,1,6.85,4.68C711,187,767.45,198.38,779.64,204"/>',
        '<path class="cls-3" d="M673.94,578H265.37a7,7,0,0,1-6.85-4.68c-19.94-65.51-81.85-67.85-94-73.5"/>',
        '<g class="cls-4">',
          '<path d="M738.13,427.65h1.18c22,0,39.37-1.33,51.87-4l.18,0,15.41-5.27q.63-7.07,1.13-14.75c-25.28,3.43-55.09,7-66.18,6.51-5.26-.23-16.19-2.42-29.56-5.56,28.32-.36,50-5.08,64.84-14.15,16.64-10.21,26.63-20.27,32.35-29.69q.07-12.14-.22-25.38c-.22-9.53-.62-19.42-1.22-29.33-5.42-11.4-23.76-23.93-26-25.45l-10.65-7.14,6.3,11.16c6.18,10.94,20.33,42.37,11.76,56.32C779,357.6,726,373.39,696.23,368.6c-6-1-17.63-4.73-32-9.69,47.2-28.08,59.36-58.52,62.09-67.88,2.38-8.18.28-22.81-8.34-34.95-5.89-8.3-17-18.41-36.61-19.45-37.51-2-91.29,66-93.56,68.89L573.57,323.7l18.49-13.87c18.15-13.62,68.84-48.82,85.28-48.09,5,.22,8.1,1.64,9.59,4.35,2.73,5,.23,15.37-6.53,27.13-6.88,12-55.9,30.9-86.52,41.44-26.69-8.55-52-15.27-68-15.27h-3.16c.6-.86,1.19-1.75,1.73-2.68a42.35,42.35,0,1,0-73-43c-.63,1.07-1.2,2.15-1.72,3.25a345,345,0,0,0-44.44-16.33c-37.21-11-96.63-22-169.57-13-2.34-30.11-14.29-51.13-36.48-64.2-.46-.27-.91-.53-1.37-.78-11.7,6.71-22.78,10.67-30.52,13.44-3.43,1.23-6.14,2.19-8.28,3.18a18.3,18.3,0,0,0-7,5.66c-5.4,7.26-9.65,20.83-12.89,37.66-8,27.12-11.85,71.92-12.74,110.76-.38,16.57-.29,31.79.16,45.74C162,382.37,181.06,364.29,187,358c6.13,5,24.36,18.53,56.12,32,65,27.63,134.62,32.83,181.71,32.3.82.07,1.65.1,2.49.1a46.61,46.61,0,0,0,16-3.3,106.2,106.2,0,0,0,9.82,4.34c29.71,11.57,62,30.24,68.46,105.63,3.46,40.25-10.89,59.27-23.54,68.13-11.79,8.26-23.69,8.82-26.23,7.65-1.72-.8-5.21-6.14-8.29-10.85-8.82-13.49-22.14-33.87-41-29-25,6.47-37.08,23.64-37.58,24.37l-8.25,12,12.35-7.65c8-4.94,30.84-15.86,40.6-7.15,3,2.66,5.36,7.83,7.88,13.31,1.32,2.87,2.73,5.91,4.34,8.93h90.89c11.69-12,20.14-28.85,24.9-50a195.17,195.17,0,0,0,4.42-39.14c6.34,2.67,12.46,6.38,15.32,11.34,6.77,11.71,49.25,66.4,84.23,77.77h11.36a17.27,17.27,0,0,0,16.84-13.21,83,83,0,0,1,2.67-8.74c-4.68.48-9,.76-12.58.76l-1.48,0c-21-.49-41.24-31.08-42.39-35.71-.54-3.46-13.42-29.15-27-50.18,19.66,14.1,39,25.92,52.17,29,23.24,5.47,47.82,11,69.24,14a132.22,132.22,0,0,1,29.19-11.13c-16.11-4.66-32.55-8.75-47.54-12.48-27.65-6.88-53.77-13.37-60.18-19.63-3.46-3.39-8.48-8.59-14.3-14.63-3.63-3.76-7.49-7.77-11.39-11.76,35.6,9.09,96.73,25,143.76,38.78a52.75,52.75,0,0,1,14.42,6.34c.06-.17.13-.33.19-.5,1.19-3.32,2.66-7.87,4.25-13.73a18.45,18.45,0,0,0,2-3.92c.58-1.65,1.24-3.6,2-5.87-4.87-3-10.25-6.05-16-9.13l1.36-2.16c-12.53-8.18-27.26-14.45-42.57-19.49,21.22,3,42.94,5.36,63.51,6.31,1.65-7.9,3.3-17.15,4.77-27.81C789.15,441.74,763.44,435,738.13,427.65Z"/>',
        '</g>',
        '<circle class="cls-5" cx="487.99" cy="223.29" r="39.31"/>',
        '<circle cx="494.7" cy="208.32" r="10.1"/>',
        '<path class="cls-6" d="M664.52,336.37s120.33,39.12,147,39.36c25.29.22,110.54-2.36,99.66-61.9s-37.43-72.67-33.73-97.56,73,81.8,55.77,111.3-22.28,69.07-112.76,69.63-217.14-33.76-217.14-33.76l.16-47.82Z"/>',
        '<path class="cls-6" d="M536.75,367S625.46,447.23,662,455.84,753.33,477,776.57,470c-52.12-17.1-114.82-26.71-126.67-38.29s-42.12-44.65-55.36-54.35-69.91-56.29-69.91-56.29Z"/>',
        '<path class="cls-6" d="M848.7,328.89s-86,13.28-107.12,12.35-129.06-32.06-129.06-32.06L546.66,290l37.14,50.45S732.9,361,790.55,348.77Z"/>',
        '<path class="cls-6" d="M56.65,199.66c-6.53,16,17.66,27.46,20.95,48.76S60,351.76,112.06,330.31s74.7-48.44,74.7-48.44S260.9,349.25,425,347.38c27.22,2.5,77.6-40.5,73.56-66.71s-29.78-62.49-29.78-62.49S376,160.39,232.94,179.13c-1.78-33.27-14.9-53-35.2-65s-24.92-5.36-61.85,37.51C100.34,192.91,67.6,172.81,56.65,199.66Z"/>',
        '<path class="cls-6" d="M207.21,177.24s3.51-42.47-21.94-33.51,5.06,32.76-12.82,69.07S110,242.58,100.28,277.62"/>',
        '<path class="cls-6" d="M579.73,270.64S672.46,241.22,683,222.82c7.71-13.43,15.54-35.11-5.57-36s-87.24,48.7-87.24,48.7,54.65-69.67,91-67.73,46,37.33,42.18,50.5S703,265,646.91,293,579.73,270.64,579.73,270.64Z"/>',
        '<path class="cls-6" d="M597.76,392.81S699.79,418.14,771,439s-21.63,93-41.28,102c-15.84,7.21-102.62,36-136.08,31.09s-119.22-.87-110.58,6.18,58.74,22,99,16.57,159.14-32.53,189-57.71c23.29-19.64,80.86-62.81,34.84-100.14S605.49,350.52,578.19,331.26,521.85,314,521.85,314l4.56,40.38Z"/>',
        '<path class="cls-6" d="M542.85,439s29.24,4.71,37.25,18.56S637,532.67,671,535.8s29.86-2.1,48.19-8.29c13.17-4.44,38.68-21.07,38.68-21.07S702,519.27,678.43,518.72s-44.69-34.19-45.33-38.29-30.6-62.36-46.67-74.13S536.75,367,536.75,367Z"/>',
        '<path class="cls-6" d="M456.53,249.42c-19.48,18.67-9,34.09-16.6,55.4s-19.58,30.7,14.33,43.91,64,34.55,70.39,108.21-45.95,82.57-54.08,78.79-23-45.92-47.22-39.66-35.84,23.14-35.84,23.14,30.61-19,44.23-6.83,11.69,59.41,72.3,39.15,56.77-110.24,53.6-130.72S538,320.7,538,320.7s74,66.55,119.07,70.5,108.39,17.64,119.49,24.31c-45.7-29.84-124.41-34.45-141.3-46.1s-65.63-61.14-65.63-61.14,149.11,42.37,205.8,7.62,33.35-66.37,30.76-77.71-26-27-26-27,23.09,40.88,11.7,59.41-66.9,33.82-96.14,29.11c-24.29-3.91-130.08-49.51-170.29-49.17s-46.19-11.31-46.19-11.31S463.83,242.42,456.53,249.42Z"/>',
        '<circle class="cls-5" cx="442.22" cy="285.2" r="39.31"/>',
        '<circle cx="446" cy="274.77" r="10.1"/>',
        '<circle class="cls-7" cx="362.05" cy="304.98" r="19.64"/>',
        '<circle class="cls-7" cx="307.97" cy="297.49" r="17.88"/>',
        '<circle class="cls-7" cx="261.34" cy="286.09" r="15.38"/>',
        '<circle class="cls-7" cx="220.57" cy="270.52" r="12.31"/>',
        '<circle class="cls-7" cx="188.32" cy="254.66" r="10.35"/>',
        '<path class="cls-8" d="M454.64,480.77H206.52a16.68,16.68,0,0,0-16.68-16.69V423a16.68,16.68,0,0,0,16.68-16.68H454.64A16.68,16.68,0,0,0,471.33,423v41.11A16.69,16.69,0,0,0,454.64,480.77Z"/>',
        '<path class="cls-9" d="M458,475.34H209.91a16.68,16.68,0,0,0-16.68-16.69V417.54a16.68,16.68,0,0,0,16.68-16.69H458a16.68,16.68,0,0,0,16.68,16.69v41.11A16.68,16.68,0,0,0,458,475.34Z"/>',
        '<text class="cls-10" transform="translate(210.83 435.69)"><tspan x="35">WEEK ',week,'</tspan><tspan class="cls-11" x="35" y="29">REWARD ',reward,'</tspan></text>',
      '</g>'
      ));

    return render;
  }
}


// File contracts/SailorLoogiesGameAward.sol

pragma solidity >=0.8.0 <0.9.0;







contract SailorLoogiesGameAward is ERC721Enumerable, AccessControl {

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  using Strings for uint256;
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  mapping (uint256 => uint8) public color;
  mapping (uint256 => uint8) public secondaryColor;
  mapping (uint256 => uint8) public rewardType;
  mapping (uint256 => uint256) public week;
  mapping (uint256 => uint256) public reward;

  string[8] colors = ["9d005d", "dd0aac", "39b54a", "059ca0", "f27e8b", "ffb93b", "ff4803", "c8a5db"];

  constructor() ERC721("SailorLoogiesGameAward", "SLG-AWARD") {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, AccessControl) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function mintItem(address owner, uint256 weekAward, uint256 rewardAward) public onlyRole(MINTER_ROLE) returns (uint256)
  {
      _tokenIds.increment();

      uint256 id = _tokenIds.current();
      _mint(owner, id);

      bytes32 predictableRandom = keccak256(abi.encodePacked( id, blockhash(block.number-1), msg.sender, address(this) ));
      color[id] = uint8(predictableRandom[0]) & uint8(7);
      secondaryColor[id] = uint8(predictableRandom[1]) & uint8(7);
      rewardType[id] = uint8(predictableRandom[2]);
      week[id] = weekAward;
      reward[id] = rewardAward;

      return id;
  }

  function tokenURI(uint id) public view override returns (string memory) {
    require(_exists(id), "not exist");

    return
      string(
          abi.encodePacked(
            'data:application/json;base64,',
            Base64.encode(
                bytes(
                      abi.encodePacked(
                          '{"name":"SailorLoogies Game Award #',id.toString(),
                          '", "description":"SailorLoogies Game Award - Week #',week[id].toString(),
                          '", "external_url":"https://sailor.fancyloogies.com/award/',
                          id.toString(),
                          '", "attributes": [{"trait_type": "Color", "value": "#',
                          colors[color[id]],
                          '"},{"trait_type": "Secondary Color", "value": "#',
                          colors[secondaryColor[id]],
                          '"},{"trait_type": "Reward Type", "value": "',
                          rewardTypeName(id),
                          '"},{"trait_type": "Week", "value": ',
                          week[id].toString(),
                          '},{"trait_type": "Reward", "value": ',
                          reward[id].toString(),
                          '}], "image": "',
                          'data:image/svg+xml;base64,',
                          Base64.encode(bytes(generateSVGofTokenById(id))),
                          '"}'
                      )
                    )
                )
          )
      );
  }

  function rewardTypeName(uint256 id) public view returns (string memory) {
    if (rewardType[id] < 128) {
      return 'Fish';
    }

    if (rewardType[id] > 224) {
      return 'Lobster';
    }

    return 'Swordfish';
  }

  function width(uint256 id) public view returns (string memory) {
    if (rewardType[id] < 128) {
      return '937';
    }

    if (rewardType[id] > 224) {
      return '983';
    }

    return '1245';
  }

  function generateSVGofTokenById(uint256 id) internal view returns (string memory) {

    string memory svg = string(abi.encodePacked(
      '<svg width="',width(id),'" height="715" xmlns="http://www.w3.org/2000/svg">',
        renderTokenById(id),
      '</svg>'
    ));

    return svg;
  }

  // Visibility is `public` to enable it being called by other contracts for composition.
  function renderTokenById(uint256 id) public view returns (string memory) {
    require(_exists(id), "not exist");

    if (rewardType[id] < 128) {
      return SailorLoogiesGameAward1Render.renderAward(colors[color[id]], colors[secondaryColor[id]], week[id].toString(), reward[id].toString());
    }

    if (rewardType[id] > 224) {
      return SailorLoogiesGameAward3Render.renderAward(colors[color[id]], colors[secondaryColor[id]], week[id].toString(), reward[id].toString());
    }

    return SailorLoogiesGameAward2Render.renderAward(colors[color[id]], colors[secondaryColor[id]], week[id].toString(), reward[id].toString());
  }
}