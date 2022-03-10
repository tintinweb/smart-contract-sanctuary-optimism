/**
 *Submitted for verification at optimistic.etherscan.io on 2022-02-10
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;



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
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

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
    function transferFrom(address from, address to, uint256 tokenId) external;

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
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}



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
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}



/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant alphabet = "0123456789abcdef";

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
            buffer[i] = alphabet[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
	
    /**
	 * @dev Replaces the given key with the given value in the given string
	 */
	function replace(string memory str, string memory key, string memory value) internal pure returns(string memory) {
		bytes memory bStr = bytes(str);
		bytes memory bKey = bytes(key);
		bytes memory bValue = bytes(value);

		uint index = indexOf(bStr, bKey);
		if (index < bStr.length) {
			bytes memory rStr = new bytes((bStr.length + bValue.length) - bKey.length);

			uint i;
			for (i = 0; i < index; i++) rStr[i] = bStr[i];
			for (i = 0; i < bValue.length; i++) rStr[index + i] = bValue[i];
			for (i = 0; i < bStr.length - (index + bKey.length); i++) rStr[index + bValue.length + i] = bStr[index + bKey.length + i];

			return string(rStr);
		}
		return string(bStr);
	}

	/**
	 * @dev Gets the index of the key string in the given string
	 */
	function indexOf(bytes memory str, bytes memory key) internal pure returns(uint256) {
		for (uint i = 0; i < str.length - (key.length - 1); i++) {
			bool matchFound = true;
			for (uint j = 0; j < key.length; j++) {
				if (str[i + j] != key[j]) {
					matchFound = false;
					break;
				}
			}
			if (matchFound) {
				return i;
			}
		}
		return str.length;
	}
}



/*
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
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
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
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        require(owner() == _msgSender(), "Caller is not the owner");
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}



/**
 * @title ICrossDomainMessenger
 */
interface ICrossDomainMessenger {
    /**********
     * Events *
     **********/

    event SentMessage(
        address indexed target,
        address sender,
        bytes message,
        uint256 messageNonce,
        uint256 gasLimit
    );
    event RelayedMessage(bytes32 indexed msgHash);
    event FailedRelayedMessage(bytes32 indexed msgHash);

    /*************
     * Variables *
     *************/

    function xDomainMessageSender() external view returns (address);

    /********************
     * Public Functions *
     ********************/

    /**
     * Sends a cross domain message to the target messenger.
     * @param _target Target contract address.
     * @param _message Message to send to the target.
     * @param _gasLimit Gas limit for the provided message.
     */
    function sendMessage(
        address _target,
        bytes calldata _message,
        uint32 _gasLimit
    ) external;
}



/**
 * @title CrossDomainEnabled
 * @dev Helper contract for contracts performing cross-domain communications
 *
 * Compiler used: defined by inheriting contract
 */
contract CrossDomainEnabled {
    /*************
     * Variables *
     *************/

    // Messenger contract used to send and recieve messages from the other domain.
    address public messenger;

    /***************
     * Constructor *
     ***************/

    /**
     * @param _messenger Address of the CrossDomainMessenger on the current layer.
     */
    constructor(address _messenger) {
        messenger = _messenger;
    }

    /**********************
     * Function Modifiers *
     **********************/

    /**
     * Enforces that the modified function is only callable by a specific cross-domain account.
     * @param _sourceDomainAccount The only account on the originating domain which is
     *  authenticated to call this function.
     */
    modifier onlyFromCrossDomainAccount(address _sourceDomainAccount) {
        require(
            msg.sender == address(getCrossDomainMessenger()),
            "OVM_XCHAIN: messenger contract unauthenticated"
        );

        require(
            getCrossDomainMessenger().xDomainMessageSender() == _sourceDomainAccount,
            "OVM_XCHAIN: wrong sender of cross-domain message"
        );

        _;
    }

    /**********************
     * Internal Functions *
     **********************/

    /**
     * Gets the messenger, usually from storage. This function is exposed in case a child contract
     * needs to override.
     * @return The address of the cross-domain messenger contract which should be used.
     */
    function getCrossDomainMessenger() internal virtual returns (ICrossDomainMessenger) {
        return ICrossDomainMessenger(messenger);
    }

    /**q
     * Sends a message to an account on another domain
     * @param _crossDomainTarget The intended recipient on the destination domain
     * @param _message The data to send to the target (usually calldata to a function with
     *  `onlyFromCrossDomainAccount()`)
     * @param _gasLimit The gasLimit for the receipt of the message on the target domain.
     */
    function sendCrossDomainMessage(
        address _crossDomainTarget,
        uint32 _gasLimit,
        bytes memory _message
    ) internal {
        // slither-disable-next-line reentrancy-events, reentrancy-benign
        getCrossDomainMessenger().sendMessage(_crossDomainTarget, _message, _gasLimit);
    }
}



/**
 * @title PixelConInvaders Core
 * @notice The purpose of this contract is to manage Invader PixelCons. All users are treated equally with the exception 
 * of an admin user who only controls the ERC721 metadata function which points to the app website. No fees are required to 
 * interact with this contract beyond base gas fees. For more information about PixelConInvaders, please visit (https://invaders.pixelcons.io)
 * @dev This contract follows the ERC721 token standard with additional functions for minting
 * See (https://github.com/OpenZeppelin/openzeppelin-solidity)
 * @author PixelCons
 */
contract PixelConInvaders is Ownable, CrossDomainEnabled, IERC165, IERC721, IERC721Enumerable, IERC721Metadata {

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////// Structs/Constants /////////////////////////////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	// Data storage structures
	struct TokenData {
		address owner;
		uint32 ownerIndex;
		uint32 index;
	}
	
	
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////// Storage ///////////////////////////////////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// Mapping from token ID to owner
	mapping(uint256 => TokenData) internal _tokenData;
	
	// Mapping from token index to token ID
	mapping(uint256 => uint256) internal _tokenIds;

	// Mapping from owner address to balance
	mapping(address => uint256) internal _ownerBalance;
	
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownerTokens;

	// Mapping from token ID to approved address
	mapping(uint256 => address) internal _tokenApprovals;

	// Mapping from owner to operator approvals
	mapping(address => mapping(address => bool)) internal _operatorApprovals;
	
	// Array of all invader IDs
	uint256[] internal _tokens;

	// The URI template for retrieving token metadata
	string internal _tokenURITemplate;

	// The address of the PixelCon Invaders bridge contract (L1)
	address internal _pixelconInvadersBridgeContract;


	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////// Events ////////////////////////////////////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// Invader token events
	event Mint(uint256 indexed invaderId, uint32 indexed invaderIndex, address to);
	event Bridge(uint256 indexed invaderId, address to);
	event Unbridge(uint256 indexed invaderId, address to);


	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////////////////////////////// PixelConInvaders Core ///////////////////////////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/**
	 * @dev Contract constructor
	 */
	constructor(address l2CrossDomainMessenger) CrossDomainEnabled(l2CrossDomainMessenger) Ownable() {
		//require(l2CrossDomainMessenger != address(0), "Invalid address"); //unlikely
		_pixelconInvadersBridgeContract = address(0);
	}

	/**
     * @dev Sets the Invader bridge contract address on L1
	 * @param pixelconInvadersBridgeContract -Invader bridge contract address
	 */
	function linkBridgeContract(address pixelconInvadersBridgeContract) public onlyOwner {
		//require(pixelconInvadersBridgeContract != address(0), "Invalid address"); //unlikely
		require(_pixelconInvadersBridgeContract == address(0), "Already set");
		_pixelconInvadersBridgeContract = pixelconInvadersBridgeContract;
	}

	/**
	 * @dev Change the token URI template
	 * @param newTokenURITemplate -New token URI template
	 */
	function setTokenURITemplate(string memory newTokenURITemplate) public onlyOwner {
		_tokenURITemplate = newTokenURITemplate;
	}
	
	////////////////// PixelCon Invader Tokens //////////////////
	
    /**
     * @dev Bridge the Invader PixelCon from L1 (callable only by the L2 messenger)
	 * @param tokenId -ID of token
	 * @param to -New owner address
	 */
	function bridgeFromL1(uint256 tokenId, address to) external onlyFromCrossDomainAccount(_pixelconInvadersBridgeContract) {
		require(tokenId != uint256(0), "Invalid ID");
		require(to != address(0), "Invalid address");
		
		TokenData storage tokenData = _tokenData[tokenId];
		address from = tokenData.owner;
		require(from == address(0) || from == address(this), "Invalid state");
		
		//new invader
		if(from == address(0)) {
			tokenData.index = uint32(_tokens.length);
			tokenData.owner = to;
			_tokens.push(tokenId);
			
			//update enumeration
			_addTokenToOwnerEnumeration(to, tokenId);
			
			//update user balance
			_ownerBalance[to] += 1;
			
			emit Mint(tokenId, tokenData.index, to);
			
		//existing invader
		} else {
			tokenData.owner = to;
		
			//update enumeration
			_removeTokenFromOwnerEnumeration(from, tokenId);
			_addTokenToOwnerEnumeration(to, tokenId);
			
			//update user balances
			_ownerBalance[from] -= 1;
			_ownerBalance[to] += 1;
		}
		
        emit Transfer(from, to, tokenId);
		emit Bridge(tokenId, to);
	}
	
	/**
	 * @dev Unbridge an Invader PixelCon to L1
	 * @param tokenId -ID of the Invader to unbridge
	 * @param to -Address of desired Invader pixelcon owner
	 * @param gasLimit -Amount of gas for messenger
	 */
	function unbridgeToL1(uint256 tokenId, address to, uint32 gasLimit) public {
		require(tokenId != uint256(0), "Invalid ID");
		require(to != address(0), "Invalid address");
		
		//check valid invader
		TokenData storage tokenData = _tokenData[tokenId];
		address from = tokenData.owner;
		require(from != address(0), "Does not exist");
		
		//check that caller owns the invader
		require(from == _msgSender(), "Not owner");
		
		//transfer invader to this contract
		_transfer(from, address(this), tokenId);
	
		//unbridge invader from the bridge contract on L1
		_unbridgeToL1(tokenId, to, gasLimit);
	}
	
    /**
     * @dev Returns linked PixelconInvadersBridge contract
	 * @return PixelconInvadersBridge contract
     */
    function getPixelconInvadersBridgeContract() public view returns (address) {
        return _pixelconInvadersBridgeContract;
    }
	
	////////////////// Web3 Only //////////////////

	/**
	 * @dev Gets all token data (web3 only)
	 * @return All token data
	 */
	function getAllTokenData() external view returns (uint256[] memory, address[] memory) {
		uint256[] memory tokenIds = new uint256[](_tokens.length);
		address[] memory owners = new address[](_tokens.length);

		for (uint i = 0; i < _tokens.length; i++) {
			uint256 tokenId = _tokens[i];
			TokenData storage tokenData = _tokenData[tokenId];

			tokenIds[i] = tokenId;
			owners[i] = tokenData.owner;
		}
		return (tokenIds, owners);
	}
	
	/**
	 * @dev Gets the token data in the given range (web3 only)
	 * @param startIndex -Start index
	 * @param endIndex -End index
	 * @return All token data
	 */
	function getTokenData(uint256 startIndex, uint256 endIndex) external view returns (uint256[] memory, address[] memory) {
		require(startIndex <= totalSupply(), "Start index is out of bounds");
		require(endIndex <= totalSupply(), "End index is out of bounds");
		require(startIndex <= endIndex, "End index is less than the start index");

		uint256 dataLength = endIndex - startIndex;
		uint256[] memory tokenIds = new uint256[](dataLength);
		address[] memory owners = new address[](dataLength);
		for (uint i = 0; i < dataLength; i++)	{
			uint256 tokenId = _tokens[i];
			TokenData storage tokenData = _tokenData[tokenId];

			tokenIds[i] = tokenId;
			owners[i] = tokenData.owner;
		}
		return (tokenIds, owners);
	}
	
	
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////// ERC-721 Implementation ///////////////////////////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId
			|| interfaceId == type(IERC721).interfaceId
            || interfaceId == type(IERC721Metadata).interfaceId
            || interfaceId == type(IERC721Enumerable).interfaceId;
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view override returns (uint256) {
		require(owner != address(0), "Invalid address");
		return _ownerBalance[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
		address owner = _tokenData[tokenId].owner;
        require(owner != address(0), "Does not exist");
        return owner;
    }
	
    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public override {
		require(tokenId != uint256(0), "Invalid ID");
		address owner = _tokenData[tokenId].owner;
        require(to != owner, "Cannot approve self");
        require(_msgSender() == owner || _operatorApprovals[owner][_msgSender()], "Not owner nor approved for all");
		_approve(owner, to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view override returns (address) {
		address owner = _tokenData[tokenId].owner;
        require(owner != address(0), "Does not exist");
        return _tokenApprovals[tokenId];
    }

    /**
     * @dev Calldata optimized version of setApprovalForAll. See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll_opt(uint256 operator_approved) public {
		address operator = address(uint160(operator_approved & 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff));
		bool approved = ((operator_approved & 0xffffffffffffffffffffffff0000000000000000000000000000000000000000) > 0x00);
		return setApprovalForAll(operator, approved);
	}

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public override {
		require(operator != address(0), "Invalid address");
        require(operator != _msgSender(), "Cannot approve self");
        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
		require(owner != address(0) && operator != address(0), "Invalid address");
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev Calldata optimized version of transferFrom. See {IERC721-transferFrom}.
     */
    function transferFrom_opt(uint256 addressTo_tokenIndex) public {
		address from = address(0x0000000000000000000000000000000000000000);
		address to = address(uint160((addressTo_tokenIndex & 0xffffffffffffffffffffffffffffffffffffffff000000000000000000000000) >> (8*12)));
		uint256 tokenId = tokenByIndex(uint32(addressTo_tokenIndex & 0x00000000000000000000000000000000000000000000000000000000ffffffff));
		return transferFrom(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public override {
		require(to != address(0), "Invalid address");
		require(tokenId != uint256(0), "Invalid ID");
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Not owner nor approved for all");
        _transfer(from, to, tokenId);
    }

    /**
     * @dev Calldata optimized version of safeTransferFrom. See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom_opt(uint256 addressTo_tokenIndex, bytes memory data_p) public {
		address from = address(0x0000000000000000000000000000000000000000);
		address to = address(uint160((addressTo_tokenIndex & 0xffffffffffffffffffffffffffffffffffffffff000000000000000000000000) >> (8*12)));
		uint256 tokenId = tokenByIndex(uint32(addressTo_tokenIndex & 0x00000000000000000000000000000000000000000000000000000000ffffffff));
		return safeTransferFrom(from, to, tokenId, data_p);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data_p) public override {
		//requirements are checked in 'transferFrom' function
		transferFrom(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data_p), "Transfer to non ERC721Receiver implementer");
    }
	

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////// ERC-721 Metadata Implementation //////////////////////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public pure override returns (string memory) {
        return "PixelConInvaders";
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public pure override returns (string memory) {
        return "PCINVDR";
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
		TokenData storage tokenData = _tokenData[tokenId];
		require(tokenData.owner != address(0), "Does not exist");		

		//Available values: <tokenId>, <tokenIndex>, <owner>

		//start with the token URI template and replace in the appropriate values
		string memory finalTokenURI = _tokenURITemplate;
		finalTokenURI = Strings.replace(finalTokenURI, "<tokenId>", Strings.toHexString(tokenId, 32));
		finalTokenURI = Strings.replace(finalTokenURI, "<tokenIndex>", Strings.toHexString(uint256(tokenData.index), 8));
		finalTokenURI = Strings.replace(finalTokenURI, "<owner>", Strings.toHexString(uint256(uint160(tokenData.owner)), 20));
		return finalTokenURI;
    }
	

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////////////////////// ERC-721 Enumerable Implementation //////////////////////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _tokens.length;
    }
	
    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
	function tokenByIndex(uint256 tokenIndex) public view override returns (uint256) {
		require(tokenIndex < _tokens.length, "Does not exist");
		return _tokens[tokenIndex];
	}
	
    /**
     * @dev Returns the token index from the given ID
	 * @param tokenId -The token ID
	 * @return Token index
     */
	function indexByToken(uint256 tokenId) public view returns (uint256) {
		TokenData storage tokenData = _tokenData[tokenId];
		require(tokenData.owner != address(0), "Does not exist");
		return uint256(tokenData.index);
	}
	
    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view override returns (uint256) {
        require(owner != address(0), "Invalid address");
        require(index < _ownerBalance[owner], "Invalid index");
        return _ownerTokens[owner][index];
    }
	
	
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////// Utils ////////////////////////////////////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
    /**
     * @dev Checks if an address is allowed to manage a token
	 * @param spender -Address to check
	 * @param tokenId -ID of token to check
     * @return True if the address is allowed to manage the token
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) private view returns (bool) {
		address owner = _tokenData[tokenId].owner;
        return (spender == owner || _tokenApprovals[tokenId] == spender || _operatorApprovals[owner][spender]);
    }
	
    /**
     * @dev Approves an address to operate on a token
	 * @param owner -Current token owner
	 * @param to -Address to approve
	 * @param tokenId -ID of token
     */
    function _approve(address owner, address to, uint256 tokenId) private {
		_tokenApprovals[tokenId] = to;
		emit Approval(owner, to, tokenId);
    }
	
    /**
     * @dev Transfers a token form one address to another
	 * @param from -Current token owner
	 * @param to -Address to transfer ownership to
	 * @param tokenId -ID of token
     */
    function _transfer(address from, address to, uint256 tokenId) private {
		TokenData storage tokenData = _tokenData[tokenId];
		require(from == address(0) || from == tokenData.owner, "Invalid from address");
		from = tokenData.owner;
		
        //clear approvals
		if(_tokenApprovals[tokenId] != address(0)) {
			_approve(tokenData.owner, address(0), tokenId);
		}
		
		//update enumeration
        _removeTokenFromOwnerEnumeration(from, tokenId);
        _addTokenToOwnerEnumeration(to, tokenId);
		
		//update user balances
		_ownerBalance[from] -= 1;
		_ownerBalance[to] += 1;
		
		//change token owner
		tokenData.owner = to;
		
        emit Transfer(from, to, tokenId);
    }
	
    /**
     * @dev Returns true if account is a contract
     * @param account -Account address
     * @return True if account is a contract
     */
    function _isContract(address account) private view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
	
    /**
     * @dev Function to invoke {IERC721Receiver-onERC721Received} on a target address
     * @param from -Address representing the previous owner of the given token ID
     * @param to -Target address that will receive the tokens
     * @param tokenId -ID of the token to be transferred
     * @param _data -Optional data to send along with the call
     * @return True if the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) private returns (bool) {
        if (_isContract(to)) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
					revert("Cannot transfer to non ERC721Receiver implementer");
                } else {
                    // solhint-disable-next-line no-inline-assembly
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
     * @dev Unbridges the Invader from L1
	 * @param tokenId -ID of the Invader
	 * @param to -The address to receive the Invader PixelCon
	 * @param gasLimit -Amount of gas for messenger
	 */
	function _unbridgeToL1(uint256 tokenId, address to, uint32 gasLimit) private {
		//construct calldata for L1 unbridge function
		bytes memory message = abi.encodeWithSignature("unbridgeFromL2(uint256,address)", tokenId, to);

		//send message to L2
		sendCrossDomainMessage(_pixelconInvadersBridgeContract, gasLimit, message);
		emit Unbridge(tokenId, to);
	}
	
    /**
     * @dev Private function to add a token to the ownership tracking data structures
     * @param to -Address representing the new owner of the given Invader ID
     * @param tokenId -ID of the Invader to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 newIndex = _ownerBalance[to];
        _ownerTokens[to][newIndex] = tokenId;
		_tokenData[tokenId].ownerIndex = uint32(newIndex);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures
     * @param from -Address representing the previous owner of the given Invader ID
     * @param tokenId -ID of the Invader to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop)
        uint256 lastTokenIndex = _ownerBalance[from] - 1;
        uint256 tokenIndex = uint256(_tokenData[tokenId].ownerIndex);

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownerTokens[from][lastTokenIndex];

            _ownerTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _tokenData[lastTokenId].ownerIndex = uint32(tokenIndex); // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
		//_tokenData[tokenId].ownerIndex = uint32(0); //set in subsequent _addTokenToOwnerEnumeration
        delete _ownerTokens[from][lastTokenIndex];
    }
}