// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

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
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
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
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
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
            "ERC721: approve caller is not token owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);

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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

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
        bytes memory data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
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
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
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
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
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
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
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

        _afterTokenTransfer(address(0), to, tokenId);
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

        _afterTokenTransfer(owner, address(0), tokenId);
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
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
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
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
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

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

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

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
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
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

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
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/ERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "./IERC721Enumerable.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

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
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Base64.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides a set of functions to operate with Base64 strings.
 *
 * _Available since v4.5._
 */
library Base64 {
    /**
     * @dev Base64 Encoding/Decoding Table
     */
    string internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /**
     * @dev Converts a `bytes` to its Bytes64 `string` representation.
     */
    function encode(bytes memory data) internal pure returns (string memory) {
        /**
         * Inspired by Brecht Devos (Brechtpd) implementation - MIT licence
         * https://github.com/Brechtpd/base64/blob/e78d9fd951e7b0977ddca77d92dc85183770daf4/base64.sol
         */
        if (data.length == 0) return "";

        // Loads the table into memory
        string memory table = _TABLE;

        // Encoding takes 3 bytes chunks of binary data from `bytes` data parameter
        // and split into 4 numbers of 6 bits.
        // The final Base64 length should be `bytes` data length multiplied by 4/3 rounded up
        // - `data.length + 2`  -> Round up
        // - `/ 3`              -> Number of 3-bytes chunks
        // - `4 *`              -> 4 characters for each chunk
        string memory result = new string(4 * ((data.length + 2) / 3));

        /// @solidity memory-safe-assembly
        assembly {
            // Prepare the lookup table (skip the first "length" byte)
            let tablePtr := add(table, 1)

            // Prepare result pointer, jump over length
            let resultPtr := add(result, 32)

            // Run over the input, 3 bytes at a time
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {

            } {
                // Advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // To write each character, shift the 3 bytes (18 bits) chunk
                // 4 times in blocks of 6 bits for each character (18, 12, 6, 0)
                // and apply logical AND with 0x3F which is the number of
                // the previous character in the ASCII table prior to the Base64 Table
                // The result is then added to the table to get the character to write,
                // and finally write it in the result pointer but with a left shift
                // of 256 (1 byte) - 8 (1 ASCII char) = 248 bits

                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }

            // When data `bytes` is not exactly 3 bytes long
            // it is padded with `=` characters at the end
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }

        return result;
    }
}

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

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

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/math/Math.sol)

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
        return a >= b ? a : b;
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
     * @dev Returns the square root of a number. It the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`.
        // We also know that `k`, the position of the most significant bit, is such that `msb(a) = 2**k`.
        // This gives `2**k < a <= 2**(k+1)` → `2**(k/2) <= sqrt(a) < 2 ** (k/2+1)`.
        // Using an algorithm similar to the msb conmputation, we are able to compute `result = 2**(k/2)` which is a
        // good first aproximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1;
        uint256 x = a;
        if (x >> 128 > 0) {
            x >>= 128;
            result <<= 64;
        }
        if (x >> 64 > 0) {
            x >>= 64;
            result <<= 32;
        }
        if (x >> 32 > 0) {
            x >>= 32;
            result <<= 16;
        }
        if (x >> 16 > 0) {
            x >>= 16;
            result <<= 8;
        }
        if (x >> 8 > 0) {
            x >>= 8;
            result <<= 4;
        }
        if (x >> 4 > 0) {
            x >>= 4;
            result <<= 2;
        }
        if (x >> 2 > 0) {
            result <<= 1;
        }

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
        uint256 result = sqrt(a);
        if (rounding == Rounding.Up && result * result < a) {
            result += 1;
        }
        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/structs/EnumerableSet.sol)

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
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSet {
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
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
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

        /// @solidity memory-safe-assembly
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

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface ISolarPunk {
    /*/////////////////////////////////////////////////////////////
                                EVENTS
    /////////////////////////////////////////////////////////////*/
    event RequestCreated(
        address indexed owner,
        uint256 blockNumber,
        uint256 amount
    );

    event AssetAdded(uint256 index, address shapeAddr);

    event RequestPostponed(address indexed owner, uint256 newBlockNumber);

    event RequestFulfilled(address indexed owner, uint256 tokenId);

    /*/////////////////////////////////////////////////////////////
                                ERRORS
    /////////////////////////////////////////////////////////////*/
    error OutOfBlockRange(uint256 blockNumber);
    error ValueBelowExpected(uint256 value);
    error NoAvailableItems();
    error RequestListTooLong();
    error NoRequestToFulfill();
    error InexistantIndex(uint256 index);
    error InexistantAsset(uint256 index);
    error AssetsNumberLimitReached();

    /*/////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    function requestMint(uint256 blockNumber, uint256 amount) external payable;

    function fulfillRequest(bool onlyOwnerRequest) external;

    function mintPendingItems() external;

    function addAsset(address assetAddr) external;

    /*/////////////////////////////////////////////////////////////
                                GETTERS
    /////////////////////////////////////////////////////////////*/

    function cost() external view returns (uint256);

    function requestList()
        external
        view
        returns (address[] memory addresses, uint256[] memory blocksNumber);

    function pendingMints(address account)
        external
        view
        returns (uint256[] memory);

    function numberOfShapes() external view returns (uint256);

    function availableItems() external view returns (uint256);

    function remainningItemOfShape(uint256 index)
        external
        view
        returns (uint256);

    function totalRemainingItems() external view returns (uint256 totalItem);

    function contractURI() external pure returns (string memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ERC721Enumerable, ERC721} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import {SolarPunkService} from "src/metadata/SolarPunkService.sol";
import {SwapAndPop} from "src/structs/SwapAndPop.sol";
import {ISolarPunk} from "src/ISolarPunk.sol";

/**
 * @title ERC721 collection with on-chain metadata
 */
contract SolarPunk is ERC721Enumerable, Ownable, ISolarPunk {
    using Address for address payable;
    using EnumerableSet for EnumerableSet.UintSet;
    using SwapAndPop for SwapAndPop.Reserve;

    /// @return cost for requesting a mint
    uint256 public immutable cost;

    /// @dev count items committed in requests
    uint128 private _availableItems;

    /// @dev counter for creating unique request for the same block number and owner
    uint128 private _lastRequestId;

    /// @dev counter for indexing shape contracts addresses
    uint256 private _lastShapeId;

    /// @dev track shape contracts addresses
    mapping(uint256 => address) private _shapesAddr;

    /// @dev track remainning itemID for a specific shape
    mapping(uint256 => SwapAndPop.Reserve) private _reserveOf;

    /// @dev track tokenID to mint for users
    mapping(address => uint256[]) private _itemsToMint;

    /// @dev list of mint request
    EnumerableSet.UintSet private _requestList;

    /// @dev list of shape contracts addresses index with remainning item inside
    EnumerableSet.UintSet private _activeShapeList;

    /// @param owner address of owner of the contract
    constructor(address owner) ERC721("SolarPunk", "SPK") {
        if (msg.sender != owner) transferOwnership(owner);
        cost = 0.001 ether;
    }

    /*/////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @notice Allow users to request one or several assets, users
     * must determine a block number in the future in which the
     * blockchash will be used to randomly choose assets to mint.
     *
     * @param blockNumber future block number committed (RANGE=[block.number+1:block.number + 72000))
     * @param amount number of asset to request
     * */
    function requestMint(uint256 blockNumber, uint256 amount) external payable {
        // check inputs
        if (blockNumber <= block.number || blockNumber > block.number + 36000)
            revert OutOfBlockRange(blockNumber);
        if (msg.value < cost * amount) revert ValueBelowExpected(msg.value);
        if (_requestList.length() + amount > 100) revert RequestListTooLong();
        if (_availableItems < amount) revert NoAvailableItems();

        // decrement available items
        unchecked {
            _availableItems -= uint128(amount);
        }

        // store requests
        for (uint256 i; i < amount; ) {
            unchecked {
                ++_lastRequestId;
                ++i;
            }
            uint256 request = createRequest(
                msg.sender,
                _lastRequestId,
                blockNumber
            );
            _requestList.add(request);
        }

        emit RequestCreated(msg.sender, blockNumber, amount);

        // give change
        payable(msg.sender).sendValue(msg.value - cost * amount);
    }

    /**
     * @notice Allow users to fulfill requests, any users could
     * fulfill requests. If the request is owned by the user the
     * item is minted. The request can be erroned, in this case
     * the request is postponed.
     *
     * TODO reward fulfilling of others AND give choice to fulfill
     * only owned request
     * */
    function fulfillRequest(bool onlyOwnerRequest) external {
        uint256 length = _requestList.length();
        if (length == 0) revert NoRequestToFulfill();

        _fulfillRequests(length, onlyOwnerRequest);
    }

    /**
     * @notice Allow users to mint item in their pending
     * list. This latter is filled when an user fulfill request
     * of others.
     * */
    function mintPendingItems() external {
        uint256[] memory pendingItem = _itemsToMint[msg.sender];
        for (uint256 i; i < pendingItem.length; ) {
            _mint(msg.sender, pendingItem[i]);
            unchecked {
                ++i;
            }
        }
        delete _itemsToMint[msg.sender];
    }

    /**
     * @notice Allow owner to add a new `assets` contract, which
     * should be a new design.
     *
     * TODO maybe the contract impl should be checked AND the maximal
     * amount of `assets` must be caped to 22.
     * */
    function addAsset(address assetAddr) external onlyOwner {
        if (_lastShapeId == 22) revert AssetsNumberLimitReached();
        unchecked {
            ++_lastShapeId;
        }
        uint256 index = _lastShapeId;
        _activeShapeList.add(index);

        _shapesAddr[index] = assetAddr;
        _reserveOf[index].stock = 84;
        _availableItems += 84;
        emit AssetAdded(index, assetAddr);
    }

    /**
     * @notice Allow only-owner to with the contract balance.
     */
    function withdraw() external onlyOwner {
        payable(msg.sender).sendValue(address(this).balance);
    }

    /*/////////////////////////////////////////////////////////////
                                GETTERS
    /////////////////////////////////////////////////////////////*/

    /// @return addresses list of request owner
    /// @return blocksNumber list of block number
    function requestList()
        external
        view
        returns (address[] memory addresses, uint256[] memory blocksNumber)
    {
        uint256 length = _requestList.length();
        addresses = new address[](length);
        blocksNumber = new uint256[](length);

        for (uint256 i; i < length; ) {
            uint256 request = _requestList.at(i);
            addresses[i] = address(uint160(request >> 96));
            blocksNumber[i] = uint64(request);
            unchecked {
                ++i;
            }
        }
    }

    /// @return list of pending mints of an user (`uint256[] memory`)
    function pendingMints(address account)
        external
        view
        returns (uint256[] memory)
    {
        return _itemsToMint[account];
    }

    /// @return number of shapes released
    function numberOfShapes() external view returns (uint256) {
        return _lastShapeId;
    }

    /// @return number of items available to request (`uint256`)
    function availableItems() external view returns (uint256) {
        return _availableItems;
    }

    /// @return remaining item for a specific shape (`uint256`)
    function remainningItemOfShape(uint256 index)
        external
        view
        returns (uint256)
    {
        if (_shapesAddr[index] == address(0)) revert InexistantIndex(index);
        return _reserveOf[index].stock;
    }

    /// @return totalItem total remaining item among all assets (`uint256`)
    function totalRemainingItems() external view returns (uint256 totalItem) {
        for (uint256 i; i < _activeShapeList.length(); ) {
            totalItem += _reserveOf[_activeShapeList.at(i)].stock;
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice This function return the NFT metadata as base64 encoded string
     *
     * @dev When the function is called the base64 encoded string is created
     * with information encoded in the tokenID. The result should be cached
     * to avoid long rendering.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        uint256 index = uint8(tokenId >> 248);
        address shapeAddr = _shapesAddr[index];
        if (shapeAddr == address(0)) revert InexistantAsset(index);

        return SolarPunkService.renderMetadata(tokenId, shapeAddr);
    }

    function contractURI() external pure returns (string memory) {
        return SolarPunkService.renderLogo();
    }

    /*/////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @dev First select a shape where to draw an item, then draw it
     * from the Reserve. And finally encode NFT informations
     * into the tokenID
     *
     * @return unique encoded tokenID
     */
    function _drawAndTransform(uint256 randNum) internal returns (uint256) {
        uint256 index = _activeShapeList.at(
            randNum % _activeShapeList.length()
        );
        uint256 itemId = _reserveOf[index].draw(randNum);
        if (_reserveOf[index].stock == 0) _activeShapeList.remove(index);

        return SolarPunkService.transformItemId(index, itemId);
    }

    /**
     * @dev Fulfill the request if the blockNumber is in the
     * range `[(block.number - 256):block.number)`.
     * A fulfilled request is either minted if the request owner
     * is the `sender`, or `drawed` and stored in the request owner's
     * pending mint list.
     *
     * If a requets is erroned (more than 256 block passed), the request is postponed.
     * As {EnumarableSet} use the swap and pop method the postponed request
     * replace the erroned one. Thus the loop just need to increase index
     */
    function _fulfillRequests(uint256 length, bool onlyOwnerRequest) internal {
        uint256 lastBlockhash = block.number - 256;
        uint256 lastRandomNumber = 1;

        for (uint256 i; i < length; ) {
            uint256 request = _requestList.at(i);
            uint256 blockNumber = uint64(request);
            address requestOwner = address(uint160(request >> 96));

            unchecked {
                ++i;
            }

            if (onlyOwnerRequest && requestOwner != msg.sender) continue;
            if (blockNumber >= block.number) continue;

            if (blockNumber < lastBlockhash) {
                // postpone the request
                uint256 postponedRequest = createRequest(
                    requestOwner,
                    ++_lastRequestId,
                    block.number + 3000
                );
                _requestList.add(postponedRequest);
                emit RequestPostponed(requestOwner, block.number + 3000);
            } else {
                unchecked {
                    lastRandomNumber =
                        lastRandomNumber +
                        uint256(blockhash(blockNumber));
                    --length;
                    --i;
                }
                uint256 tokenId = _drawAndTransform(lastRandomNumber);
                if (requestOwner == msg.sender) {
                    // mint directly the item
                    _mint(msg.sender, tokenId);
                } else {
                    // add item to the minting list
                    _itemsToMint[requestOwner].push(tokenId);
                }
                emit RequestFulfilled(requestOwner, tokenId);
            }
            _requestList.remove(request);
        }
    }

    /**
     * @dev workaround to pack request information into an `uint256`
     *
     * @param owner address of the request owner
     * @param lastRequestId request counter
     * @param blockNumber future block
     *
     * @return request as packed `uint256`
     */
    function createRequest(
        address owner,
        uint256 lastRequestId,
        uint256 blockNumber
    ) internal pure returns (uint256) {
        return
            uint256(
                bytes32(
                    abi.encodePacked(
                        uint160(owner),
                        uint32(lastRequestId),
                        uint64(blockNumber)
                    )
                )
            );
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/utils/Base64.sol";

/**
 * @title Simple metadata properties for on-chain NFT
 * @dev Do not include `attributes`
 */

library MetadataProperties {
    // UTILS
    string internal constant HEADER = "data:application/json;base64,";
    string internal constant OPEN_JSON = "{";
    string internal constant NEXT_ATTRIBUTE = '",';
    string internal constant CLOSE_JSON = '"}';

    // PROPERTIES
    string internal constant PRE_NAME = '"name":"';
    string internal constant PRE_DESCRIPTION = '"description":"';
    string internal constant PRE_IMAGE = '"image":"';
    string internal constant PRE_EXTERNAL_URL = '"external_url":"';
    string internal constant PRE_BACKGROUND_COLOR = '"background_color":"';

    // IMAGE UTILS
    string internal constant SVG_HEADER = "data:image/svg+xml;base64,";
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/utils/Base64.sol";

/// @title Constants properties of SolarPunks
library SolarPunkProperties {
    // ASSETS PROPERTIES
    string internal constant NAME_PRIMER = "Solar Punk";
    string internal constant DESCRIPTION_PRIMER =
        "This NFT belongs to the Solar Punk collection. Solar Punks promotes an optimist vision of the future, they don't warn of futures dangers but propose solutions to avoid that the dystopias come true. Solar Punks holds 22 principles that defines they're vision and mission.  \\n";
    string internal constant DESCRIPTION_UNI =
        "Unis are the most common edition this collection, but this not mean they are worthless.";
    string internal constant DESCRIPTION_GRADIENT =
        "Gradients are less common in this collection. They shine as the mission of SolarPunks.";
    string internal constant DESCRIPTION_DARK =
        "Darks are rare in this collection, the living proofs of existence of Lunar Punks, even if missions of Solar Punks are obstructed, they continue to act discretely.";
    string internal constant DESCRIPTION_ELEVATED =
        "This is one of the two Elevated Solar Punks holding this principle, their charisma radiates everywhere and inspires people by their actions.";
    string internal constant DESCRIPTION_PHANTOM =
        "Each principle is held by a Phamtom, this one always acting in the shadows to serve the light.";

    // COLLECTIONS PROPERTIES
    string internal constant CONTRACT_NAME = "Solar Punk Collection";
    string internal constant CONTRACT_DESCRIPTION =
        "Discover the Solar Punk collection!  \\nA collection of 1848 unique asset living on Optimism ethereum layer 2, this collection promotes an optimist vision as Solar Punks do.  \\nThe collection consists of 22 shapes x 84 assets including 5 different rarities, each assets are distributed randomly. NFTs metadata consist of SVG on-chain, encoded into the `tokenID` and rendered with the `tokenURI` function. The contract is verified on explorers and IPFS, so you can mint your asset wherever you want.";
    string internal constant CONTRACT_IMAGE = "";
    string internal constant EXTERNAL_URL =
        "https://github.com/RaphaelHardFork/solar-punk";
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {MetadataEncoder} from "src/utils/MetadataEncoder.sol";
import {SolarPunkProperties} from "src/metadata/SolarPunkProperties.sol";
import {SolarPunkSVGProperties} from "src/vectors/SolarPunkSVG.sol";
import {IShape} from "src/vectors/shapes/IShape.sol";

/// @title SolarPunkService
/// @notice Library to construct SolarPunks on-chain SVG image and metadata
library SolarPunkService {
    using MetadataEncoder for string;

    struct Gradient {
        uint24 colorA;
        uint24 colorB;
    }

    struct Image {
        bool animated;
        uint24 shapeColor;
        Gradient background;
        Gradient layer;
    }

    struct TokenID {
        uint8 shapeId;
        uint8 tokenId;
        uint8 numberOfCopies;
        Image image;
    }

    function renderLogo() internal pure returns (string memory) {
        return
            MetadataEncoder.encodeMetadata(
                SolarPunkProperties.CONTRACT_NAME,
                SolarPunkProperties.CONTRACT_DESCRIPTION,
                createLogo(),
                SolarPunkProperties.EXTERNAL_URL
            );
    }

    function renderMetadata(uint256 tokenId, address shapeAddr)
        internal
        view
        returns (string memory)
    {
        TokenID memory data = decodeTokenId(tokenId);
        (string memory rarity, string memory rarityDescrition) = rarityDetails(
            data.numberOfCopies
        );

        // render name & description
        string memory name = string.concat(
            SolarPunkProperties.NAME_PRIMER,
            " ",
            IShape(shapeAddr).name(),
            " ",
            rarity
        );

        string memory description = string.concat(
            SolarPunkProperties.DESCRIPTION_PRIMER,
            rarityDescrition,
            "  \\n",
            IShape(shapeAddr).description()
        );

        return
            MetadataEncoder.encodeMetadata(
                name,
                description,
                createImage(
                    data,
                    IShape(shapeAddr).path(data.image.shapeColor)
                ),
                SolarPunkProperties.EXTERNAL_URL
            );
    }

    /**
     * @dev Using multiple `append` instead of one big
     * `string.concat` to avoid the `Stack too deep` error
     */
    function createImage(TokenID memory data, string memory path)
        internal
        pure
        returns (string memory svgCode)
    {
        svgCode = svgCode.append(SolarPunkSVGProperties.HEADER);
        svgCode = svgCode.append(SolarPunkSVGProperties.BACKGROUND);
        svgCode = svgCode.append(
            data.image.animated
                ? SolarPunkSVGProperties.LAYER_ANIMATED
                : SolarPunkSVGProperties.LAYER_STATIC
        );
        svgCode = svgCode.append(path);
        svgCode = svgCode.append(
            SolarPunkSVGProperties.text(data.tokenId, data.numberOfCopies)
        );
        svgCode = svgCode.append(SolarPunkSVGProperties.defs(true));
        svgCode = svgCode.append(
            SolarPunkSVGProperties.linearGradient(
                true,
                data.image.background.colorA,
                data.image.background.colorB
            )
        );

        if (data.numberOfCopies < 51) {
            svgCode = svgCode.append(
                SolarPunkSVGProperties.linearGradient(
                    false,
                    data.image.layer.colorA,
                    data.image.layer.colorB
                )
            );
        }
        svgCode = svgCode.append(SolarPunkSVGProperties.defs(false));
        svgCode = svgCode.append(SolarPunkSVGProperties.FOOTER);
    }

    function createLogo() internal pure returns (string memory svgCode) {
        svgCode = svgCode.append(SolarPunkSVGProperties.HEADER);
        svgCode = svgCode.append(SolarPunkSVGProperties.BACKGROUND);
        svgCode = svgCode.append(SolarPunkSVGProperties.LAYER_ANIMATED);
        svgCode = svgCode.append(SolarPunkSVGProperties.CONTRACT_LOGO);
        svgCode = svgCode.append(SolarPunkSVGProperties.defs(true));
        svgCode = svgCode.append(
            SolarPunkSVGProperties.linearGradient(true, 0x12ae56, 0xee9944)
        );
        svgCode = svgCode.append(
            SolarPunkSVGProperties.linearGradient(false, 0xaa3377, 0x2244cc)
        );
        svgCode = svgCode.append(SolarPunkSVGProperties.defs(false));
        svgCode = svgCode.append(SolarPunkSVGProperties.FOOTER);
    }

    function transformItemId(uint256 principe, uint256 itemId)
        internal
        pure
        returns (uint256)
    {
        TokenID memory data;
        data.shapeId = uint8(principe);

        // Rarity
        if (itemId < 51) {
            // uni
            data.tokenId = uint8(itemId + 1);
            data.numberOfCopies = 51;
            data.image.background.colorA = 0xB1D39C;
            data.image.background.colorB = 0xB1D39C;
        } else if (itemId >= 51 && itemId < 77) {
            // gradient
            itemId = itemId % 51;
            data.tokenId = uint8(itemId + 1);
            data.numberOfCopies = 26;
            data.image.background.colorA = 0xffffff;
            data.image.background.colorB = 0xC85426;
            data.image.layer.colorA = 0x87E990;
            data.image.layer.colorB = 0x63B3E9;
        } else if (itemId >= 77 && itemId < 81) {
            // dark
            itemId = (itemId % 51) % 26;
            data.tokenId = uint8(itemId + 1);
            data.numberOfCopies = 4;
            data.image.background.colorA = 0x108EA6;
            data.image.background.colorB = 0x000000;
            data.image.layer.colorA = 0x612463;
            data.image.layer.colorB = 0x202283;
            data.image.shapeColor = 0xffffff;
        } else if (itemId == 81 || itemId == 82) {
            // elevated
            data.tokenId = itemId == 81 ? 1 : 2;
            data.numberOfCopies = 2;
            data.image.animated = true;
            data.image.background.colorA = 0xDBA533;
            data.image.background.colorB = 0xBB2730;
            data.image.layer.colorA = 0x33CEDB;
            data.image.layer.colorB = 0x5BB252;
        } else {
            // phantom
            data.tokenId = 1;
            data.numberOfCopies = 1;
            data.image.animated = true;
            data.image.background.colorA = 0x5E2463;
            data.image.background.colorB = 0x000000;
            data.image.layer.colorA = 0xFFF4CC;
            data.image.layer.colorB = 0xffffff;
            data.image.shapeColor = 0xffffff;
        }

        return
            uint256(
                bytes32(
                    abi.encodePacked(
                        data.shapeId,
                        data.tokenId,
                        data.numberOfCopies,
                        data.image.animated,
                        data.image.shapeColor,
                        data.image.background.colorA,
                        data.image.background.colorB,
                        data.image.layer.colorA,
                        data.image.layer.colorB
                    )
                )
            );
    }

    function decodeTokenId(uint256 tokenId)
        internal
        pure
        returns (TokenID memory data)
    {
        data.shapeId = uint8(tokenId >> 248);
        data.tokenId = uint8(tokenId >> 240);
        data.numberOfCopies = uint8(tokenId >> 232);
        data.image.animated = uint8(tokenId >> 224) == 0 ? false : true;
        data.image.shapeColor = uint24(tokenId >> 200);
        data.image.background.colorA = uint24(tokenId >> 176);
        data.image.background.colorB = uint24(tokenId >> 152);
        data.image.layer.colorA = uint24(tokenId >> 128);
        data.image.layer.colorB = uint24(tokenId >> 104);
    }

    function rarityDetails(uint256 numberOfCopies)
        internal
        pure
        returns (string memory, string memory)
    {
        if (numberOfCopies == 51)
            return ("Uni", SolarPunkProperties.DESCRIPTION_UNI);
        if (numberOfCopies == 26)
            return ("Gradient", SolarPunkProperties.DESCRIPTION_GRADIENT);
        if (numberOfCopies == 4)
            return ("Dark", SolarPunkProperties.DESCRIPTION_DARK);
        if (numberOfCopies == 2)
            return ("Elevated", SolarPunkProperties.DESCRIPTION_ELEVATED);
        return ("Phantom", SolarPunkProperties.DESCRIPTION_PHANTOM);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/**
 * @notice Allow to use a mapping into an enumerable array of
 * `uint256` used to draw (randomly) items.
 *
 * Declare a set state variables
 * SwapAndPop.Reserve private reserve;
 *
 * Then use box.draw(randNum)
 *
 * @dev WARNING the librairy is permissive, a set of item can
 * overrided by replacing the stock amount
 */
library SwapAndPop {
    error Empty();

    struct Reserve {
        uint256 stock;
        mapping(uint256 => uint256) itemsId;
    }

    /**
     * @notice Use this function to remove one item from
     * the mapping
     *
     * @param reserve Reserve struct stated in your contract
     * @param randNum random number moduled by number of items
     */
    function draw(Reserve storage reserve, uint256 randNum)
        internal
        returns (uint256 itemId)
    {
        // check if items remainning
        uint256 itemsAmount = reserve.stock;
        if (itemsAmount == 0) revert Empty();

        // choose among available index
        uint256 index = randNum % itemsAmount;

        // assign item ID
        itemId = reserve.itemsId[index];
        if (itemId == 0) itemId = index;

        // read last item ID
        uint256 lastItem = reserve.itemsId[itemsAmount - 1];

        // assign last item ID
        if (lastItem == 0) lastItem = itemsAmount - 1;
        reserve.itemsId[index] = lastItem;

        // pop from the list
        delete reserve.itemsId[itemsAmount - 1];
        --reserve.stock;
    }
}

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/**
 * @title HexadecimalColor
 * @notice Library used to convert an `uint24` to his
 * hexadecimal string representation starting with `#`
 * */
library HexadecimalColor {
    bytes16 private constant _HEX_SYMBOLS = "0123456789ABCDEF";

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toColor(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "#000000";
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
    function toHexString(uint256 value, uint256 length)
        internal
        pure
        returns (string memory)
    {
        bytes memory buffer = new bytes(2 * length + 1);
        buffer[0] = "#";
        for (uint256 i = 2 * length; i > 0; ) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
            unchecked {
                --i;
            }
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Base64} from "openzeppelin-contracts/contracts/utils/Base64.sol";
import {MetadataProperties} from "src/metadata/MetadataProperties.sol";

/// @title Librairy used to write and encode on-chain metadata
library MetadataEncoder {
    using MetadataEncoder for string;

    function encodeMetadata(
        string memory name,
        string memory description,
        string memory image,
        string memory externalUrl
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    MetadataProperties.HEADER,
                    Base64.encode(
                        _jsonFile(
                            name,
                            description,
                            encodeSVG(image),
                            externalUrl
                        )
                    )
                )
            );
    }

    function _jsonFile(
        string memory name,
        string memory description,
        string memory image,
        string memory externalUrl
    ) internal pure returns (bytes memory) {
        string memory jsonString;
        jsonString = jsonString.append(MetadataProperties.OPEN_JSON);
        jsonString = jsonString.append(MetadataProperties.PRE_NAME);
        jsonString = jsonString.append(name);
        jsonString = jsonString.append(MetadataProperties.NEXT_ATTRIBUTE);
        jsonString = jsonString.append(MetadataProperties.PRE_DESCRIPTION);
        jsonString = jsonString.append(description);
        jsonString = jsonString.append(MetadataProperties.NEXT_ATTRIBUTE);
        jsonString = jsonString.append(MetadataProperties.PRE_IMAGE);
        jsonString = jsonString.append(image);
        jsonString = jsonString.append(MetadataProperties.NEXT_ATTRIBUTE);
        jsonString = jsonString.append(MetadataProperties.PRE_EXTERNAL_URL);
        jsonString = jsonString.append(externalUrl);
        jsonString = jsonString.append(MetadataProperties.CLOSE_JSON);
        return abi.encodePacked(jsonString);
    }

    function encodeSVG(string memory svgCode)
        internal
        pure
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    MetadataProperties.SVG_HEADER,
                    Base64.encode(bytes(svgCode))
                )
            );
    }

    function append(string memory baseString, string memory element)
        internal
        pure
        returns (string memory)
    {
        return string.concat(baseString, element);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/utils/Strings.sol";

import "src/utils/HexadecimalColor.sol";

/**
 * @title Used to construct SolarPunk frame, it could evolve
 * to a more generic librairy to construct SVGs.
 * */
library SolarPunkSVGProperties {
    using Strings for uint8;
    using HexadecimalColor for uint24;

    // constant svg elements
    string internal constant HEADER =
        '<svg xmlns="http://www.w3.org/2000/svg" style="fill-rule:evenodd;" viewBox="0 0 1000 1000">';

    string internal constant BACKGROUND =
        '<path d="M0 0h1000v1000H0z" style="fill:url(#a)"/>';

    string internal constant LAYER_STATIC =
        '<path d="M0 0h1000v1000H0z" style="fill:url(#b);fill-opacity:.75"/>';

    string internal constant CONTRACT_LOGO =
        '<text x="251px" y="809px" style="font-family:&quot;Poiret One&quot;;font-size:819px;">?</text>';

    string internal constant LAYER_ANIMATED =
        '<path d="M0 0h1000v1000H0z" style="fill:url(#b);fill-opacity:0"><animate attributeName="fill-opacity" values="0; 1; 0" dur="20s" repeatCount="indefinite"/></path>';

    string internal constant FOOTER = "</svg>";

    function defs(bool opening) internal pure returns (string memory) {
        return opening ? "<defs>" : "</defs>";
    }

    // elements with parameters
    function text(uint8 tokenId, uint8 rarityAmount)
        internal
        pure
        returns (string memory)
    {
        string memory color = rarityAmount == 4 || rarityAmount == 1
            ? ";fill:#FFF"
            : "";
        return
            string.concat(
                '<text text-anchor="middle" x="50%" y="946" style="font-family:&quot;Poiret One&quot;',
                color,
                ';font-size:34px">',
                tokenId.toString(),
                "/",
                rarityAmount.toString(),
                "</text>"
            );
    }

    function linearGradient(
        bool isBackground,
        uint24 color1,
        uint24 color2
    ) internal pure returns (string memory) {
        return
            string.concat(
                // first part
                "<linearGradient id=",
                isBackground ? '"a"' : '"b"',
                ' x1="0" x2="1" y1="0" y2="0" gradientUnits="userSpaceOnUse" gradientTransform="matrix',
                isBackground
                    ? "(-1000,-1000,1000,-1000,1000,1000)"
                    : "(-1000,1000,-1000,-1000,1000,0)",
                '">',
                // second part
                '<stop offset="0" style="stop-color:',
                color1.toColor(),
                ';"/>',
                '<stop offset="1" style="stop-color:',
                color2.toColor(),
                ';"/>',
                "</linearGradient>"
            );
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IShape {
    function name() external view returns (string memory);

    function description() external view returns (string memory);

    function path(string memory color) external view returns (string memory);

    function path(uint24 color) external view returns (string memory);
}