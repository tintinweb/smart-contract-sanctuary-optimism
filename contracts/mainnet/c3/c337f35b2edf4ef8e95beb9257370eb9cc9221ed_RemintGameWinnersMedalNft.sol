//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "openzeppelin-contracts/lib/forge-std/src/interfaces/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/contracts/utils/Base64.sol";
import "./NftSvg.sol";

contract RemintGameWinnersMedalNft is IERC721, IERC721Metadata, NftSvg {
    address private _owner = 0xD0f7fBf89106aB6Eda8b3CbcA65C085fcCb87209;

    constructor() {
        emit Transfer(address(0), _owner, 1);
    }

    modifier onlyNftOwner() {
        require(msg.sender == _owner, "Caller is not owner");
        _;
    }

    function name() external pure returns (string memory) {
        return "Homage Remint Game Winner's Medal";
    }

    function symbol() external pure returns (string memory) {
        return "MEDAL";
    }

    function tokenURI(uint256) external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                "Homage Remint Game Winner's Medal",
                                '", "description":"',
                                "The Homage Remint Game Winner's Medal",
                                '", "image": "',
                                "data:image/svg+xml;base64,",
                                render(),
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    function balanceOf(address owner_) external view returns (uint256) {
        if (owner_ == _owner) {
            return 1;
        } else {
            return 0;
        }
    }

    function ownerOf(uint256 tokenId_) external view returns (address) {
        if (tokenId_ != 1) {
            revert("Token with token ID does not exist");
        }

        return _owner;
    }

    function safeTransferFrom(
        address from_,
        address to_,
        uint256 tokenId_,
        bytes memory data_
    ) external payable onlyNftOwner {
        _safeTransfer(from_, to_, tokenId_, data_);
    }

    function safeTransferFrom(
        address from_,
        address to_,
        uint256 tokenId_
    ) external payable onlyNftOwner {
        _safeTransfer(from_, to_, tokenId_, "");
    }

    function transferFrom(
        address from_,
        address to_,
        uint256 tokenId_
    ) external payable onlyNftOwner {
        _transfer(from_, to_, tokenId_);
    }

    function approve(address, uint256) external payable {
        revert("Unsupported function");
    }

    function setApprovalForAll(address, bool) external pure {
        revert("Unsupported function");
    }

    function getApproved(uint256) external pure returns (address) {
        revert("Unsupported function");
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        revert("Unsupported function");
    }

    function supportsInterface(bytes4 interfaceId_) public pure returns (bool) {
        return
            interfaceId_ == type(IERC721).interfaceId ||
            interfaceId_ == type(IERC721Metadata).interfaceId;
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(_owner == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _owner = to;

        emit Transfer(from, to, tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.code.length > 0) {
            try
                IERC721Receiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    _data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
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
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;

import "./IERC165.sol";

/// @title ERC-721 Non-Fungible Token Standard
/// @dev See https://eips.ethereum.org/EIPS/eip-721
/// Note: the ERC-165 identifier for this interface is 0x80ac58cd.
interface IERC721 is IERC165 {
    /// @dev This emits when ownership of any NFT changes by any mechanism.
    /// This event emits when NFTs are created (`from` == 0) and destroyed
    /// (`to` == 0). Exception: during contract creation, any number of NFTs
    /// may be created and assigned without emitting Transfer. At the time of
    /// any transfer, the approved address for that NFT (if any) is reset to none.
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    /// @dev This emits when the approved address for an NFT is changed or
    /// reaffirmed. The zero address indicates there is no approved address.
    /// When a Transfer event emits, this also indicates that the approved
    /// address for that NFT (if any) is reset to none.
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    /// @dev This emits when an operator is enabled or disabled for an owner.
    /// The operator can manage all NFTs of the owner.
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    /// @notice Count all NFTs assigned to an owner
    /// @dev NFTs assigned to the zero address are considered invalid, and this
    /// function throws for queries about the zero address.
    /// @param _owner An address for whom to query the balance
    /// @return The number of NFTs owned by `_owner`, possibly zero
    function balanceOf(address _owner) external view returns (uint256);

    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    /// about them do throw.
    /// @param _tokenId The identifier for an NFT
    /// @return The address of the owner of the NFT
    function ownerOf(uint256 _tokenId) external view returns (address);

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    /// operator, or the approved address for this NFT. Throws if `_from` is
    /// not the current owner. Throws if `_to` is the zero address. Throws if
    /// `_tokenId` is not a valid NFT. When transfer is complete, this function
    /// checks if `_to` is a smart contract (code size > 0). If so, it calls
    /// `onERC721Received` on `_to` and throws if the return value is not
    /// `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    /// @param data Additional data with no specified format, sent in call to `_to`
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata data) external payable;

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    /// except this function just sets data to "".
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;

    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    /// TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    /// THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    /// operator, or the approved address for this NFT. Throws if `_from` is
    /// not the current owner. Throws if `_to` is the zero address. Throws if
    /// `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;

    /// @notice Change or reaffirm the approved address for an NFT
    /// @dev The zero address indicates there is no approved address.
    /// Throws unless `msg.sender` is the current NFT owner, or an authorized
    /// operator of the current owner.
    /// @param _approved The new approved NFT controller
    /// @param _tokenId The NFT to approve
    function approve(address _approved, uint256 _tokenId) external payable;

    /// @notice Enable or disable approval for a third party ("operator") to manage
    /// all of `msg.sender`'s assets
    /// @dev Emits the ApprovalForAll event. The contract MUST allow
    /// multiple operators per owner.
    /// @param _operator Address to add to the set of authorized operators
    /// @param _approved True if the operator is approved, false to revoke approval
    function setApprovalForAll(address _operator, bool _approved) external;

    /// @notice Get the approved address for a single NFT
    /// @dev Throws if `_tokenId` is not a valid NFT.
    /// @param _tokenId The NFT to find the approved address for
    /// @return The approved address for this NFT, or the zero address if there is none
    function getApproved(uint256 _tokenId) external view returns (address);

    /// @notice Query if an address is an authorized operator for another address
    /// @param _owner The address that owns the NFTs
    /// @param _operator The address that acts on behalf of the owner
    /// @return True if `_operator` is an approved operator for `_owner`, false otherwise
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

/// @dev Note: the ERC-165 identifier for this interface is 0x150b7a02.
interface IERC721TokenReceiver {
    /// @notice Handle the receipt of an NFT
    /// @dev The ERC721 smart contract calls this function on the recipient
    /// after a `transfer`. This function MAY throw to revert and reject the
    /// transfer. Return of other than the magic value MUST result in the
    /// transaction being reverted.
    /// Note: the contract address is always the message sender.
    /// @param _operator The address which called `safeTransferFrom` function
    /// @param _from The address which previously owned the token
    /// @param _tokenId The NFT identifier which is being transferred
    /// @param _data Additional data with no specified format
    /// @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    ///  unless throwing
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data)
        external
        returns (bytes4);
}

/// @title ERC-721 Non-Fungible Token Standard, optional metadata extension
/// @dev See https://eips.ethereum.org/EIPS/eip-721
/// Note: the ERC-165 identifier for this interface is 0x5b5e139f.
interface IERC721Metadata is IERC721 {
    /// @notice A descriptive name for a collection of NFTs in this contract
    function name() external view returns (string memory _name);

    /// @notice An abbreviated name for NFTs in this contract
    function symbol() external view returns (string memory _symbol);

    /// @notice A distinct Uniform Resource Identifier (URI) for a given asset.
    /// @dev Throws if `_tokenId` is not a valid NFT. URIs are defined in RFC
    /// 3986. The URI may point to a JSON file that conforms to the "ERC721
    /// Metadata JSON Schema".
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

/// @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
/// @dev See https://eips.ethereum.org/EIPS/eip-721
/// Note: the ERC-165 identifier for this interface is 0x780e9d63.
interface IERC721Enumerable is IERC721 {
    /// @notice Count NFTs tracked by this contract
    /// @return A count of valid NFTs tracked by this contract, where each one of
    /// them has an assigned and queryable owner not equal to the zero address
    function totalSupply() external view returns (uint256);

    /// @notice Enumerate valid NFTs
    /// @dev Throws if `_index` >= `totalSupply()`.
    /// @param _index A counter less than `totalSupply()`
    /// @return The token identifier for the `_index`th NFT,
    /// (sort order not specified)
    function tokenByIndex(uint256 _index) external view returns (uint256);

    /// @notice Enumerate NFTs assigned to an owner
    /// @dev Throws if `_index` >= `balanceOf(_owner)` or if
    /// `_owner` is the zero address, representing invalid NFTs.
    /// @param _owner An address where we are interested in NFTs owned by them
    /// @param _index A counter less than `balanceOf(_owner)`
    /// @return The token identifier for the `_index`th NFT assigned to `_owner`,
    /// (sort order not specified)
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256);
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

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "openzeppelin-contracts/contracts/utils/Strings.sol";

abstract contract NftSvg {
    function render() public pure returns (string memory) {
        // The colors are determined by the winning NFT
        string[4] memory colors = _generateHslColorPalette(
            keccak256(
                abi.encodePacked(
                    0x3B3ee1931Dc30C1957379FAc9aba94D1C48a5405,
                    uint256(35855)
                )
            )
        );

        return
        string.concat(
            '<svg width="1000" height="1000" viewBox="0 0 1000 1000" fill="none" xmlns="http://www.w3.org/2000/svg">',
            '<rect x="0.5" y="0.5" width="999" height="999" fill="',
            colors[0],
            '" />',
            _flakes(colors[1]),
            _base(colors[0]),
            _majorPlate(
                'reminter',
                keccak256(abi.encodePacked('reminter', 'medha.eth')),
                colors[1]
            ),
            _majorPlate(
                'creator',
                keccak256(
                    abi.encodePacked(
                        'creator',
                        0x0624D062Ae9dD596de0384D37522cDe46cD500d6
                    )
                ),
                colors[2]
            ),
            _majorPlate(
                'collector',
                keccak256(abi.encodePacked('collector', 'pleasrdao.eth')),
                colors[3]
            ),
            '</svg>'
        );
    }

    function _flakes(string memory color_) internal pure returns (string memory) {
        return
        string.concat(
            _minorFlake(
                'flake1',
                keccak256(
                    abi.encodePacked(
                        'remint2',
                        0xcfa9A8B82b1010BA1A69fa1FAc4CB1573261AEe1
                    )
                ),
                color_
            ),
            _minorFlake(
                'flake2',
                keccak256(abi.encodePacked('remint3', '11b.eth')),
                color_
            ),
            _minorFlake(
                'flake3',
                keccak256(abi.encodePacked('remint4', '11b.eth')),
                color_
            ),
            _minorFlake(
                'flake4',
                keccak256(
                    abi.encodePacked(
                        'remint5',
                        0xC4EaC2351631FdB9C107563D6d425Fdf5ddCb66F
                    )
                ),
                color_
            ),
            _minorFlake(
                'flake5',
                keccak256(abi.encodePacked('remint6', 'shough.eth')),
                color_
            )
        );
    }

    function _generateHslColorPalette(
        bytes32 entropy_
    ) public pure returns (string[4] memory) {
        uint256 entropyUint256 = uint256(entropy_);
        uint256 hue = uint256(entropyUint256 >> 1) % 361;
        uint256 saturation = uint256(entropyUint256 >> 2) % 101;
        uint256 lightness = uint256(entropyUint256 >> 3) % 101;

        uint256 h1 = (hue + 90) % 360;
        uint256 h2 = (hue + 180) % 360;
        uint256 h3 = (hue + 270) % 360;
        string[4] memory colors;
        colors[0] = string(
            abi.encodePacked(
                'hsla(',
                Strings.toString(h1),
                ',',
                Strings.toString(saturation),
                '%,',
                Strings.toString(lightness),
                '%, 0.4)'
            )
        );
        colors[1] = string(
            abi.encodePacked(
                'hsla(',
                Strings.toString(h2),
                ',',
                Strings.toString(saturation),
                '%,',
                Strings.toString(lightness),
                '%, 0.5)'
            )
        );
        colors[2] = string(
            abi.encodePacked(
                'hsla(',
                Strings.toString(h3),
                ',',
                Strings.toString(saturation),
                '%,',
                Strings.toString(lightness),
                '%, 0.5)'
            )
        );
        colors[3] = string(
            abi.encodePacked(
                'hsla(',
                Strings.toString(hue),
                ',',
                Strings.toString(saturation),
                '%,',
                Strings.toString(lightness),
                '%, 0.5)'
            )
        );

        return colors;
    }

    function _base(string memory color_) internal pure returns (string memory) {
        return
        string.concat(
            '<style>#shape1{fill:',
            color_,
            ';}</style>',
            '<defs>',
            '<mask id="medal-mask">',
            '<path d="M500.5 167L168 366.5L234.5 699L500.5 832L766.5 699L833 366.5L500.5 167Z" fill="white" />',
            '<path d="M500.5 404L405 461.3L424.1 556.8L500.5 595L576.9 556.8L596 461.3L500.5 404Z" fill="black"/>',
            '</clipPath>',
            '</defs>',
            '<path id="shape1" mask="url(#medal-mask)" d="M500.5 167L168 366.5L234.5 699L500.5 832L766.5 699L833 366.5L500.5 167Z" />'
        );
    }

    function _majorPlate(
        string memory id_,
        bytes32 entropy_,
        string memory color_
    ) internal pure returns (string memory) {
        return
        string.concat(
            '<style>',
            _fill(id_, color_),
            _animateMovement(id_, entropy_),
            '</style>',
            _polygon(id_, entropy_)
        );
    }

    function _fill(
        string memory id_,
        string memory color_
    ) internal pure returns (string memory) {
        return string.concat('#', id_, '{fill:', color_, ';}');
    }

    function _animateMovement(
        string memory id_,
        bytes32 entropy_
    ) internal pure returns (string memory) {
        return
        string.concat(
            _animateTranslate(id_, entropy_),
            _animateRotate(id_, entropy_)
        );
    }

    function _animateTranslate(
        string memory id_,
        bytes32 entropy_
    ) internal pure returns (string memory) {
        string memory translationName = string.concat(id_, '-translate');

        uint256 entropyUint256 = uint256(entropy_);
        uint16 maxTranslate = 50;

        uint8 duration = (uint8(entropyUint256) % 10) + 1;

        return
        string.concat(
            '@keyframes ',
            translationName,
            ' {',
            ' 0% {transform: translate(0px,0px);}',
            ' 25% {transform: translate(',
            Strings.toString(uint16(entropyUint256 << 2) % maxTranslate),
            'px,',
            Strings.toString(uint16(entropyUint256 << 3) % maxTranslate),
            'px);}',
            ' 50% {transform: translate(',
            Strings.toString(uint16(entropyUint256 << 4) % maxTranslate),
            'px,',
            Strings.toString(uint16(entropyUint256 << 5) % maxTranslate),
            'px);}',
            ' 50% {transform: translate(',
            Strings.toString(uint16(entropyUint256 << 4) % maxTranslate),
            'px,',
            Strings.toString(uint16(entropyUint256 << 5) % maxTranslate),
            'px);}',
            ' 100% {transform: translate(0px,0px);}',
            ' }',
            ' #',
            id_,
            ' {animation:',
            translationName,
            ' ',
            Strings.toString(duration),
            's ease-in-out infinite;}'
        );
    }

    function _animateRotate(
        string memory id_,
        bytes32 entropy_
    ) internal pure returns (string memory) {
        string memory translationName = string.concat(id_, '-rotate');

        uint256 entropyUint256 = uint256(entropy_);
        uint16 maxRotate = 10;

        uint8 duration = (uint8(entropyUint256 << 1) % 5) + 3;

        return
        string.concat(
            '@keyframes ',
            translationName,
            ' {',
            ' 25% {transform: rotate(',
            Strings.toString(uint16(entropyUint256 << 2) % maxRotate),
            'deg); transform-origin: center center;}',
            ' 50% {transform: rotate(',
            Strings.toString(uint16(entropyUint256 << 3) % maxRotate),
            'deg); transform-origin: center center;}',
            ' 75% {transform: rotate(',
            Strings.toString(uint16(entropyUint256 << 4) % maxRotate),
            'deg); transform-origin: center center;}',
            ' }',
            ' #',
            id_,
            ' {animation:',
            translationName,
            ' ',
            Strings.toString(duration),
            's ease-in-out infinite;}'
        );
    }

    function _polygon(
        string memory id_,
        bytes32 entropy_
    ) internal pure returns (string memory) {
        uint16 POLYGON_POINT_MIN_DISTANCE_FROM_EDGE = 30;
        uint16 POLYGON_POINT_RANGE = 940;
        // 1000 - 2 * POLYGON_POINT_MIN_DISTANCE_FROM_EDGE

        string memory points = '';
        uint256 randomNumber = uint256(entropy_);
        // Between 3 and 4 sides
        uint8 numSides = uint8((randomNumber % 2) + 3);

        for (uint8 i = 0; i < numSides; i++) {
            // x and y coordinates can be between 150 to 850
            uint256 x = uint256(
                (randomNumber << (i + 1)) % POLYGON_POINT_RANGE
            ) + POLYGON_POINT_MIN_DISTANCE_FROM_EDGE;
            uint256 y = uint256(
                (randomNumber << (i + 2)) % POLYGON_POINT_RANGE
            ) + POLYGON_POINT_MIN_DISTANCE_FROM_EDGE;

            points = string.concat(
                points,
                ' ',
                Strings.toString(x),
                ',',
                Strings.toString(y)
            );
        }

        return
        string.concat(
            '<polygon id="',
            id_,
            '" points="',
            points,
            '">',
            '</polygon>'
        );
    }

    function _minorFlake(
        string memory id_,
        bytes32 entropy_,
        string memory color_
    ) internal pure returns (string memory) {
        return
        string.concat(
            '<style>',
            _fill(id_, color_),
            _animateMovement(id_, entropy_),
            '</style>',
            _minorPolygon(id_, entropy_)
        );
    }

    function _minorPolygon(
        string memory id_,
        bytes32 entropy_
    ) internal pure returns (string memory) {
        string memory points = '';
        uint256 randomNumber = uint256(entropy_);
        // Between 3 and 4 sides
        uint8 numSides = uint8((randomNumber % 2) + 3);

        uint16 xStart = uint16(randomNumber >> 10) % 10;
        uint16 yStart = uint16(randomNumber >> 23) % 10;

        // located between 20 - 200 and 800 - 980
        uint16 x = 0;
        uint16 y = 0;

        if (xStart < 5) {
            x = 20 + xStart * 36;
        } else {
            x = 980 - xStart * 36;
        }

        if (yStart < 5) {
            y = 20 + yStart * 36;
        } else {
            y = 980 - yStart * 36;
        }

        for (uint8 i = 0; i < numSides; i++) {
            points = string.concat(
                points,
                ' ',
                Strings.toString(x),
                ',',
                Strings.toString(y)
            );

            // x and y coordinates can change by up to MINI_POLYGON_MAX_POINT_DELTA
            if (i == 2 && x > 48) {
                x -= uint16(30 + ((randomNumber << (i + 1)) % 10) * 2);
            } else {
                x += uint16(30 + ((randomNumber << (i + 1)) % 10) * 2);
            }

            if (i != 0 && y > 48) {
                y -= uint16(30 + ((randomNumber << (i + 2)) % 10) * 2);
            } else {
                y += uint16(30 + ((randomNumber << (i + 2)) % 10) * 2);
            }
        }

        return
        string.concat(
            '<polygon id="',
            id_,
            '" points="',
            points,
            '">',
            '</polygon>'
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;

interface IERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceID The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    /// uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    /// `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
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
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

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
        return a > b ? a : b;
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
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

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
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}