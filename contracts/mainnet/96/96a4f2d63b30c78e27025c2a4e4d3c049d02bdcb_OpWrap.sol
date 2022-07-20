/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-07-20
*/

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

/// @title ERC165 Interface
/// @author Modified from openzeppelin-contracts <
/// @notice Interface of the ERC165 standard.
/// @notice https://eips.ethereum.org/EIPS/eip-165[EIP].
interface IERC165 {
    /// @notice Returns true if this contract implements the interface defined by `interfaceId`
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/// @title ERC721 Interface
/// @author Modified from openzeppelin-contracts <https://github.com/OpenZeppelin/openzeppelin-contracts>
interface IERC721 is IERC165 {
    // Events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /// @notice Returns the number of tokens in ``owner``'s account.
    function balanceOf(address owner) external view returns (uint256 balance);

    /// @notice Returns the owner of the `tokenId` token.
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /// @notice Safely transfers `tokenId` token from `from` to `to`.
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /// @notice Safely transfers `tokenId` token from `from` to `to`.
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /// @notice Transfers `tokenId` token from `from` to `to`.
    function transferFrom(address from, address to, uint256 tokenId) external;

    /// @notice Gives permission to `to` to transfer `tokenId` token to another account.
    function approve(address to, uint256 tokenId) external;

    /// @notice Approve or remove `operator` as an operator for the caller.
    function setApprovalForAll(address operator, bool _approved) external;

    /// @notice Returns the account approved for `tokenId` token.
    function getApproved(uint256 tokenId) external view returns (address operator);

    /// @notice Returns if the `operator` is allowed to manage all of the assets of `owner`.
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

/// @title OpWrap
/// @author asnared <https://github.com/abigger87>
/// @notice Batches Calls to an ERC721 Contract
contract OpWrap {

  /// @notice The Optimism Token
  IERC721 public token;

  /// @notice The Owner
  address public owner;

  /// @notice Thrown when an unauthorized caller makes a call to this contract
  error Unauthorized();

  /// @notice Instantiate the Batcher
  constructor(IERC721 _token, address _owner) {
    token = _token;
    owner = _owner;
  }

  /// @notice Returns if one of the given addresses is a token owner.
  function areOwners(address[] memory potentialOwners) public view returns (bool) {
    uint256 length = potentialOwners.length;
    uint256 i;
    for (i = 0; i < length;) {
      if (token.balanceOf(potentialOwners[i]) > 0) return true;
      unchecked { ++i; }
    }
    return false;
  }

  /// @notice Allows the owner to set the token.
  function setToken(IERC721 newToken) external {
    if (msg.sender != owner) revert Unauthorized();
    token = newToken;
  }

  /// @notice Allows the owner to set a new owner.
  function setOwner(address newOwner) external {
    if (msg.sender != owner) revert Unauthorized();
    owner = newOwner;
  }
}