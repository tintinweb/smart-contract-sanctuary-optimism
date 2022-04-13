// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Base64.sol)

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

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IFont {
    function name() external view returns (string memory);

    function format() external view returns (string memory);

    function font() external view returns (string memory);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IFont} from "../fonts/interface/IFont.sol";

import {Base64} from "openzeppelin-contracts/contracts/utils/Base64.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

interface IWritingEditions {
    function owner() external view returns (address);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function ownerOf(uint256 tokenId) external view returns (address);

    function description() external view returns (string memory);

    function limit() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function price() external view returns (uint256);

    function contentURI() external view returns (string memory);

    function imageURI() external view returns (string memory);
}

/**
 * @title Test Renderer
 * Generate an SVG by reading the description, name, and symbol of the caller.
 * This contract assumes the caller implements the ERC721 interface and a
 * `description`, `limit`, `totalSupply` and `price` fields.
 * @author MirrorXYZ
 */
contract MirrorRenderer {
    IFont internal font;

    constructor(address fontAddress) {
        font = IFont(fontAddress);
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        IWritingEditions edition = IWritingEditions(msg.sender);

        try edition.ownerOf(tokenId) returns (address owner) {
            if (owner == address(0)) {
                revert("cannot render");
            }
        } catch {
            revert("cannot render");
        }

        return _constructSVG(tokenId, edition);
    }

    function _constructSVG(uint256 tokenId, IWritingEditions edition)
        internal
        view
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            string(
                                abi.encodePacked(
                                    '{"name": "',
                                    edition.name(),
                                    '", "description": "',
                                    edition.description(),
                                    '", "media": { "text": "ar://',
                                    edition.contentURI(),
                                    '", "image": "ipfs://',
                                    edition.imageURI(),
                                    '"}, "image": "data:image/svg+xml;base64,',
                                    Base64.encode(
                                        bytes(_getImageData(tokenId, edition))
                                    ),
                                    '", "attributes":[{ "trait_type": "Serial", "value": ',
                                    Strings.toString(tokenId),
                                    "}] }"
                                )
                            )
                        )
                    )
                )
            );
    }

    function _getImageData(uint256 tokenId, IWritingEditions edition)
        internal
        view
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350',
                    _getStyle(),
                    '<foreignObject x="0" y="0" width="100%" height="100%"><div class="body" xmlns="http://www.w3.org/1999/xhtml">',
                    _getBody(tokenId, edition),
                    "</foreignObject></svg>"
                )
            );
    }

    function _getBody(uint256 tokenId, IWritingEditions edition)
        internal
        view
        returns (string memory body)
    {
        body = string(
            abi.encodePacked(
                '<div class="footer">Author: ',
                _addressToString(edition.owner()),
                '</div><div class="footer">Name: ',
                edition.name(),
                '</div><div class="footer">Symbol: $',
                edition.symbol(),
                '</div><div class="footer">Token: ',
                edition.limit() > 0
                    ? string(
                        abi.encodePacked(
                            Strings.toString(tokenId),
                            "/",
                            Strings.toString(edition.limit())
                        )
                    )
                    : Strings.toString(tokenId),
                '</div><div class="footer">Price: ',
                string(
                    abi.encodePacked(_formatPrice(edition.price(), 18), " ETH")
                ),
                '</div><div class="footer">Sold: ',
                Strings.toString(edition.totalSupply()),
                "</div></div>"
            )
        );
    }

    function _formatPrice(uint256 price, uint256 exponent)
        internal
        view
        returns (string memory)
    {
        require(exponent > 0, "invalid exponent");

        uint256 remainder = price % (10**exponent);
        uint256 quotient = price / (10**exponent);
        if (remainder != 0) {
            return
                string(
                    abi.encodePacked(
                        Strings.toString(quotient),
                        exponent == 18 ? "." : "",
                        _formatPrice(remainder, exponent - 1)
                    )
                );
        }
        return Strings.toString(quotient);
    }

    function _getStyle() internal view returns (string memory style) {
        style = string(
            abi.encodePacked(
                '"><style>@font-face { font-family: ',
                font.name(),
                '; src: url("',
                font.font(),
                '") format("',
                font.format(),
                '"); } .body { text-align: center; padding: 10px 20px; fill: #0E0E0E',
                abi.encodePacked(
                    "; font-family: ",
                    font.name(),
                    "; font-size: 24px; } .footer { text-align: left; border-style: dotted; border-width: 1px; margin-top: 5px; padding: 5px 10px; fill: #0E0E0E",
                    "; font-family: ",
                    font.name(),
                    '; font-size: 10px} </style><rect width="100%" height="100%" fill="#ffffff',
                    '"/>'
                )
            )
        );
    }

    // https://ethereum.stackexchange.com/questions/8346/convert-address-to-string/8447#8447
    function _addressToString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = _char(hi);
            s[2 * i + 1] = _char(lo);
        }
        return string(abi.encodePacked("0x", s));
    }

    function _char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}