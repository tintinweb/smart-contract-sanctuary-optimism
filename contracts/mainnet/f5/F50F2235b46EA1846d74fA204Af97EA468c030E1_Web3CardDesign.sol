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
pragma solidity ^0.8.4;

/// @notice Three-step single owner authorization mixin.
/// @author SolBase (https://github.com/Sol-DAO/solbase/blob/main/src/auth/OwnedThreeStep.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract OwnedThreeStep {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event OwnerUpdateInitiated(address indexed user, address indexed ownerCandidate);

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error Unauthorized();

    /// -----------------------------------------------------------------------
    /// Ownership Storage
    /// -----------------------------------------------------------------------

    address public owner;

    address internal _ownerCandidate;

    bool internal _ownerCandidateConfirmed;

    modifier onlyOwner() virtual {
        if (msg.sender != owner) revert Unauthorized();

        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    /// @notice Create contract and set `owner`.
    /// @param _owner The `owner` of contract.
    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /// -----------------------------------------------------------------------
    /// Ownership Logic
    /// -----------------------------------------------------------------------

    /// @notice Initiate ownership transfer.
    /// @param newOwner The `_ownerCandidate` that will `confirmOwner()`.
    function transferOwnership(address newOwner) public payable virtual onlyOwner {
        _ownerCandidate = newOwner;

        emit OwnerUpdateInitiated(msg.sender, newOwner);
    }

    /// @notice Confirm ownership between `owner` and `_ownerCandidate`.
    function confirmOwner() public payable virtual {
        if (_ownerCandidateConfirmed) {
            if (msg.sender != owner) revert Unauthorized();

            delete _ownerCandidateConfirmed;

            address newOwner = _ownerCandidate;

            owner = newOwner;

            emit OwnershipTransferred(msg.sender, newOwner);
        } else {
            if (msg.sender != _ownerCandidate) revert Unauthorized();

            _ownerCandidateConfirmed = true;
        }
    }

    /// @notice Terminate ownership by `owner`.
    function renounceOwner() public payable virtual onlyOwner {
        delete owner;

        emit OwnershipTransferred(msg.sender, address(0));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { OwnedThreeStep } from "@turbo-eth/solbase-sol/src/auth/OwnedThreeStep.sol";

contract Web3CardDesign is OwnedThreeStep {
  address public erc721KActivatorInstance;

  uint256 private STYLE_UPGRADE_VALUE = 0.01 ether;

  mapping(uint256 => uint8) private _color;
  mapping(uint256 => uint8) private _emoji;

  mapping(uint8 => bytes) private _colorMap;
  mapping(uint8 => string) private _emojiMap;

  mapping(address => bool) private _supporter;

  /* ===================================================================================== */
  /* Constructor & Modifiers                                                               */
  /* ===================================================================================== */

  constructor(address _owner) OwnedThreeStep(_owner) {
    _colorMap[0] = hex"6236C5"; // Purple
    _colorMap[1] = hex"224396"; // Blue
    _colorMap[2] = hex"922B2B"; // Red
    _colorMap[3] = hex"498933"; // Green
    _colorMap[4] = hex"313131"; // Black

    _emojiMap[0] = unicode"🏦";
    _emojiMap[1] = unicode"🦜";
    _emojiMap[2] = unicode"🦊";
    _emojiMap[3] = unicode"🦄";
    _emojiMap[4] = unicode"🐙";
    _emojiMap[5] = unicode"🐵";
    _emojiMap[6] = unicode"🐳";
    _emojiMap[7] = unicode"🐝";
    _emojiMap[8] = unicode"🐺";
    _emojiMap[9] = unicode"👑";
    _emojiMap[10] = unicode"🚀";
    _emojiMap[11] = unicode"🌈";
    _emojiMap[12] = unicode"🪶";
    _emojiMap[13] = unicode"🧸";
    _emojiMap[14] = unicode"🎁";
    _emojiMap[15] = unicode"💌";
    _emojiMap[16] = unicode"🎀";
    _emojiMap[17] = unicode"🔮";
    _emojiMap[18] = unicode"💎";
    _emojiMap[19] = unicode"🪅";
    _emojiMap[20] = unicode"🏗";
    _emojiMap[21] = unicode"🧰";
    _emojiMap[22] = unicode"🧲";
    _emojiMap[23] = unicode"🧪";
    _emojiMap[24] = unicode"🛡️";
    _emojiMap[25] = unicode"🧬";
    _emojiMap[26] = unicode"🧭";
    _emojiMap[27] = unicode"🧮";
    _emojiMap[28] = unicode"⚔️";
    _emojiMap[29] = unicode"🧰";
    _emojiMap[30] = unicode"🧱";
    _emojiMap[31] = unicode"⛓️";
    _emojiMap[32] = unicode"🏈";
    _emojiMap[33] = unicode"🏀";
    _emojiMap[34] = unicode"⚽️";
    _emojiMap[35] = unicode"🏐";
    _emojiMap[36] = unicode"🏓";
    _emojiMap[37] = unicode"🎾";
    _emojiMap[38] = unicode"🎲";
    _emojiMap[39] = unicode"🏉";
    _emojiMap[40] = unicode"🎽";
    _emojiMap[41] = unicode"🏆";
    _emojiMap[42] = unicode"🎯";
  }

  /* ===================================================================================== */
  /* External Functions                                                                    */
  /* ===================================================================================== */

  function getEmoji(uint256 tokenId) external view returns (string memory) {
    return _emojiMap[_emoji[tokenId]];
  }

  function getColor(uint256 tokenId) external view returns (bytes memory) {
    return _colorMap[_color[tokenId]];
  }

  function getEmojiFromMap(uint8 emojiId) external view returns (string memory) {
    return _emojiMap[emojiId];
  }

  function getColorFromMap(uint8 colorId) external view returns (bytes memory) {
    return _colorMap[colorId];
  }

  function setDuringMint(
    uint256 tokenId,
    uint8 color,
    uint8 emoji
  ) external {
    require(msg.sender == erc721KActivatorInstance, "Web3CardDesign:not-authorized");
    _color[tokenId] = color;
    _emoji[tokenId] = emoji;
  }

  function setEmoji(uint256 tokenId, uint8 emoji) external payable {
    require(msg.value >= STYLE_UPGRADE_VALUE, "Web3CardDesign:insufficient-eth");
    require(
      msg.sender == IERC721(erc721KActivatorInstance).ownerOf(tokenId),
      "Web3CardDesign:not-owner"
    );
    _emoji[tokenId] = emoji;
    _call(msg.value);
  }

  function setColor(uint256 tokenId, uint8 color) external payable {
    require(msg.value >= STYLE_UPGRADE_VALUE, "Web3CardDesign:insufficient-eth");
    require(
      msg.sender == IERC721(erc721KActivatorInstance).ownerOf(tokenId),
      "Web3CardDesign:not-owner"
    );
    _color[tokenId] = color;
    _call(msg.value);
  }

  function setERC721KActivatorInstance(address _erc721KActivatorInstance) external onlyOwner {
    erc721KActivatorInstance = _erc721KActivatorInstance;
  }

  function setStyleUpgradeCost(uint256 _styleUpgradeCost) external onlyOwner {
    STYLE_UPGRADE_VALUE = _styleUpgradeCost;
  }

  function _call(uint256 value) internal {
    (bool _success, ) = erc721KActivatorInstance.call{ value: value }("");
    require(_success, "Web3CardDesign:call-failed");
  }
}