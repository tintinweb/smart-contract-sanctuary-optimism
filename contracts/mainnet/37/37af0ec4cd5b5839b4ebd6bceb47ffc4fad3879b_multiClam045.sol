/**
 *Submitted for verification at optimistic.etherscan.io on 2022-05-29
*/

/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-27
*/

// SPDX-License-Identifier: GPL-3.0



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

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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

// File: contracts/NFTmulMint001.sol


// File: @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol


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

// File: @openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC721/utils/ERC721Holder.sol)

pragma solidity ^0.8.0;


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
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// File: contracts/NftMultMint.sol

/**
 *Submitted for verification at Etherscan.io on 2022-05-25
*/

/**
 *Submitted for verification at Etherscan.io on 2022-05-25
*/

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

// File: @openzeppelin/contracts/utils/introspection/ERC165.sol


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

// File: @openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol


// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;


/**
 * @dev _Available since v3.1._
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @dev Handles the receipt of a single ERC1155 token type. This function is
     * called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * NOTE: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param operator The address which initiated the transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param id The ID of the token being transferred
     * @param value The amount of tokens being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev Handles the receipt of a multiple ERC1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     *
     * NOTE: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param operator The address which initiated the batch transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param ids An array containing ids of each token being transferred (order and length must match values array)
     * @param values An array containing amounts of each token being transferred (order and length must match ids array)
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}

// File: @openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC1155/utils/ERC1155Receiver.sol)

pragma solidity ^0.8.0;



/**
 * @dev _Available since v3.1._
 */
abstract contract ERC1155Receiver is ERC165, IERC1155Receiver {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }
}

// File: @openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol


// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/utils/ERC1155Holder.sol)

pragma solidity ^0.8.0;


/**
 * Simple implementation of `ERC1155Receiver` that will allow a contract to hold ERC1155 tokens.
 *
 * IMPORTANT: When inheriting this contract, you must include a way to use the received tokens, otherwise they will be
 * stuck.
 *
 * @dev _Available since v3.1._
 */
contract ERC1155Holder is ERC1155Receiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}

// File: contracts/aiNFT.sol



pragma solidity ^0.8.0;

pragma experimental ABIEncoderV2;









pragma solidity ^0.8.0;

interface passNFT {
    function purchase(address tokenRecipient, string memory message) external;
}


interface textNFT {
     function mint(string memory text_) external  returns (uint256)  ;
}

interface transTextNFT {
     function safeTransferFrom( address from,
        address to,
        uint256 tokenId) external  ;
}

interface approveNFT{
      function approve(address to, uint256 tokenId) external  ; 
     //  function approve(address to, uint256 tokenId) external;
}

interface approvalForAll{
      function setApprovalForAll(address operator, bool _approved) external;
}


contract TransferContra {
   // address constant contra = address(0xa698713a3bc386970Cdc95A720B5754cC0f96931);
    function transfer( address contra  ,address from , address to,uint256 tokenId) public {
         transTextNFT(contra).safeTransferFrom( 
               from, 
                to ,
              tokenId
        );
    }

     // address  operator =  address(this);
    function getAddress( ) public view returns (address) {
        return address(this);
    }

}


contract ClaimerOne   is   ERC1155Holder   , ERC721Holder{
    constructor( string memory _text,address  contra ,  address  operator,TransferContra  transferContra ){
            approvalForAll(contra).setApprovalForAll(operator,true);
           //  approvalForAll(contra).setApprovalForAll(address(this),true);
            uint256  tokenId =   textNFT(contra).mint(_text ) ;
            uint256  nowId=   tokenId-1;
            approveNFT(contra).approve(address(this),nowId);
              transferContra.transfer(  contra  ,address(this) , address(tx.origin),nowId) ;
            // transTextNFT(contra).safeTransferFrom( 
            //         address(this), 
            //         address(tx.origin) ,
            //     nowId
            // );
        selfdestruct(payable(address(tx.origin))); 
    }
 }




contract Claimer   is   ERC1155Holder   , ERC721Holder{

     constructor( string memory text,address  contra , uint times, address  operator ,TransferContra  transferContra){
        approvalForAll(contra).setApprovalForAll(operator,true);
       //  approvalForAll(contra).setApprovalForAll(address(this),true);
        for(uint i=0;i< times;i++){
            uint256  tokenId =   textNFT(contra).mint(text ) ;
            uint256  nowId=   tokenId-1;
            approveNFT(contra).approve(address(this),nowId);
            transferContra.transfer(  contra  ,address(this) , address(tx.origin),nowId) ;
            // transTextNFT(contra).safeTransferFrom( 
            //     address(this), 
            //     address(tx.origin) ,
            //    nowId
            // );
        }
         selfdestruct(payable(address(tx.origin)));
    }


    //  function doMulMint(address  contra , uint times, address  operator) public  {
    //         approvalForAll(contra).setApprovalForAll(operator,true);
    //     for(uint i=0;i< times;i++){
    //         uint256  tokenId =   textNFT(contra).mint(text ) ;
    //         uint256  nowId=   tokenId-1;
    //            approveNFT(contra).approve(address(this),nowId);
    //         transTextNFT(contra).safeTransferFrom( 
    //             address(this), 
    //             address(tx.origin) ,
    //            nowId
    //         );
    //     }
    //      selfdestruct(payable(address(tx.origin)));
    // }

    // function doOneMint(address  contra ,    address  operator) public  {
    //      approvalForAll(contra).setApprovalForAll(operator,true);
    //     uint256  tokenId =   textNFT(contra).mint(text ) ;
    //      uint256  nowId=   tokenId-1;
    //     approveNFT(contra).approve(address(this),nowId);
    //     transTextNFT(contra).safeTransferFrom( 
    //             address(this), 
    //             address(tx.origin) ,
    //            nowId
    //      );
    //    selfdestruct(payable(address(tx.origin)));      
    // }


}





contract multiClam045 {
    address constant contra = address(0xa698713a3bc386970Cdc95A720B5754cC0f96931);
    function callTime( string memory text , uint times) public {
     TransferContra  transferContra  =new TransferContra();
     
        //address  operator =  address(this);
         address  operator =  transferContra.getAddress( );
        // Claimer claims = 
         new Claimer(text,  contra , times, operator,  transferContra);
    }

    function doOneMint(string memory text  , uint times ) public  {
         TransferContra  transferContra  =new TransferContra();
            address  operator =  transferContra.getAddress( );
         //address  operator =  address(this);
         for(uint i=0;i<times;++i){
         //  ClaimerOne claims = 
            new ClaimerOne(text,  contra ,  operator,transferContra);
        }
    }


}