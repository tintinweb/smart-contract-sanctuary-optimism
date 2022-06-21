/**
 *Submitted for verification at optimistic.etherscan.io on 2022-06-21
*/

// SPDX-License-Identifier: MIT
// author: yoyoismee.eth -- it's opensource but also feel free to send me coffee/beer.
//  ╔═╗┌─┐┌─┐┌─┐┌┬┐┌┐ ┌─┐┌─┐┌┬┐┌─┐┌┬┐┬ ┬┌┬┐┬┌─┐
//  ╚═╗├─┘├┤ ├┤  ││├┴┐│ │├─┤ │ └─┐ │ │ │ ││││ │
//  ╚═╝┴  └─┘└─┘─┴┘└─┘└─┘┴ ┴ ┴o└─┘ ┴ └─┘─┴┘┴└─┘
// check out speedboat - https://speedboat.studio/
// or docs http://docs.speedboat.studio/

// oops lotto! to collab with oops lotto. feel free to use this contract to draw winner. 

// to collab with us https://forms.gle/oPtDVEjF5ucS2Y1S6
// check out http://oopslotto.xyz/

// File: @openzeppelin/contracts/utils/introspection/IERC165.sol


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

// File: @openzeppelin/contracts/token/ERC721/IERC721.sol


// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721.sol)

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

// File: extralotto.sol


// author: yoyoismee.eth -- it's opensource but also feel free to send me coffee/beer.
//  ╔═╗┌─┐┌─┐┌─┐┌┬┐┌┐ ┌─┐┌─┐┌┬┐┌─┐┌┬┐┬ ┬┌┬┐┬┌─┐
//  ╚═╗├─┘├┤ ├┤  ││├┴┐│ │├─┤ │ └─┐ │ │ │ ││││ │
//  ╚═╝┴  └─┘└─┘─┴┘└─┘└─┘┴ ┴ ┴o└─┘ ┴ └─┘─┴┘┴└─┘
// check out speedboat - https://speedboat.studio/
// or docs http://docs.speedboat.studio/

// oops lotto! to collab with oops lotto. feel free to use this contract to draw winner. 

// to collab with us https://forms.gle/oPtDVEjF5ucS2Y1S6
// check out http://oopslotto.xyz/




pragma solidity 0.8.14;


contract extraLotto {
    /// @notice life too short for chainlink VRF 
    /// this lotto is semi-permissionless. anyone can put prize here but there's no garantee that the prize will be pay out
    /// but I'll try my best to only PR the one that sound legit enough.
    /// ps. chainlinkTeam - feel free to spon this. I'll write a new one if ya give me some grants lol :P

    event newPrize(string name, uint amount, uint drawTime);
    event winner(string prize, uint ticketNo,address winner);

    // go go secondary sell at https://quixotic.io/collection/0xD182adC29d09FcF823C9FE8ED678ee96e09BE7a9
    address constant public oopsLotto = 0xD182adC29d09FcF823C9FE8ED678ee96e09BE7a9;
    uint constant public lottoNo = 10_000;

    struct Prize{
        uint64 amount;
        uint64 drawTime;
        bool exist;
    }

    string[] public prizeList;
    mapping(string => address[]) public winners;
    mapping(string => Prize) public prize;



    /// @notice call this function then add to this https://forms.gle/oPtDVEjF5ucS2Y1S6
    /// Feel free to test on prod here add prize, draw, etc. 
    /// but if you fill the form and not pay out I'll list you in a not pay out section on http://oopslotto.xyz/
    function addPrize(string calldata _name, uint64 _amount, uint64 _drawTime) public{
        require(!prize[_name].exist, "prize already exist");
        prize[_name] = Prize({amount:_amount,
                              drawTime:_drawTime,
                              exist:true});
        prizeList.push(_name);

        emit newPrize(_name,_amount,_drawTime);
    }

    /// @dev anyone can draw! 
    function draw(string calldata _prize, uint _amount) public {
        require(prize[_prize].exist, "prize not exist");
        require(winners[_prize].length + _amount <= prize[_prize].amount, "too much");
        require(block.timestamp >= prize[_prize].drawTime, "not yet");
        uint luckyNo;
        address lottoOwner;
        for (uint i =0 ; i < _amount;i++){
            luckyNo = uint256(keccak256(abi.encodePacked(_prize,block.timestamp,blockhash(block.number -1), winners[_prize].length))) % lottoNo + 1; // 1-10000;
            lottoOwner = IERC721(oopsLotto).ownerOf(luckyNo);
            winners[_prize].push(lottoOwner);
            emit winner(_prize, luckyNo,lottoOwner);
        }
    }

    function listWinner(string calldata _prize) public view returns(address[] memory){
        return winners[_prize];
    }

    function timeNow() public view returns(uint){
        return block.timestamp;
    }

    function timeInXHrs(uint hrs) public view returns(uint){
        uint x = 1 hours;
        return block.timestamp + hrs * x; /// WTF solidity 0.8.14 who the fuck change this?!?
    }
}