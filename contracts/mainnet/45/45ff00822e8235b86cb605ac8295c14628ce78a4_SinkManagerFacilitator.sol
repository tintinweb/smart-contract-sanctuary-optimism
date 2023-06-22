// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IVotingEscrowV1} from "../../interfaces/v1/IVotingEscrowV1.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/// @notice This contract is used to support merging into the Velodrome SinkManager
contract SinkManagerFacilitator is ERC721Holder {
    constructor() {}

    function merge(IVotingEscrowV1 _ve, uint256 _from, uint256 _to) external {
        _ve.merge(_from, _to);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVotingEscrowV1 {
    struct Point {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    function getApproved(uint256 _tokenId) external view returns (address);

    function isApprovedOrOwner(address _spender, uint256 _tokenId) external returns (bool);

    function locked__end(uint256 _tokenId) external view returns (uint256 _locked);

    function locked(uint256 _tokenId) external view returns (int128 _amount, uint256 _end);

    function ownerOf(uint256 _tokenId) external view returns (address _owner);

    function increase_amount(uint256 _tokenId, uint256 _amount) external;

    function increase_unlock_time(uint256 _tokenId, uint256 _duration) external;

    function create_lock(uint256 _amount, uint256 _end) external returns (uint256 tokenId);

    function create_lock_for(uint256 _amount, uint256 _end, address _to) external returns (uint256 tokenId);

    function approve(address who, uint256 tokenId) external;

    function balanceOfNFT(uint256) external view returns (uint256 amount);

    function user_point_epoch(uint256) external view returns (uint256);

    function user_point_history(uint256, uint256) external view returns (Point memory);

    function merge(uint256 _from, uint256 _to) external;

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/utils/ERC721Holder.sol)

pragma solidity ^0.8.0;

import "../IERC721Receiver.sol";

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
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