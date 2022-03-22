// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

interface IWritingEditions {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function ownerOf(uint256 tokenId) external view returns (address);

    function description() external view returns (string memory);
}

/**
 * @title Test Renderer
 * Generate an SVG by reading the description, name, and symbol of the caller.
 * This contract assumes the caller implements the ERC721 interface and a
 * `description` field.
 * @author MirrorXYZ
 */
contract MirrorRenderer {
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        try IWritingEditions(msg.sender).ownerOf(tokenId) returns (
            address owner
        ) {
            if (owner == address(0)) {
                revert("cannot render");
            }
        } catch {
            revert("cannot render");
        }

        (
            uint256 minX,
            uint256 minY,
            uint256 width,
            uint256 height,
            string memory fill,
            string memory fill1
        ) = _getSettings(msg.sender, tokenId);

        // TODO: we might need to add a constaint in the word character count
        // unless we do dymaic sizing.

        // Note: We callback here to maintain the `tokenURI(uint256 tokenId)` interface.
        // The `tokenId` value is not necessary since all tokens will have the same value

        string memory settings = string(
            abi.encodePacked(
                toString(minX),
                " ",
                toString(minY),
                " ",
                toString(width),
                " ",
                toString(height)
            )
        );

        string memory style = string(
            abi.encodePacked(
                '"><style>.body { fill: ',
                fill,
                "; font-family: Arial; font-size: 24px; } .footer { fill: ",
                fill,
                '; font-family: Arial; font-size: 10px} </style><rect width="100%" height="100%" fill="',
                fill1,
                '"/>'
            )
        );

        string memory body = string(
            abi.encodePacked(
                '<text x="10" y="30" class="body">',
                IWritingEditions(msg.sender).description(),
                "</text>",
                '<text x="10" y="340" class="footer">',
                IWritingEditions(msg.sender).name(),
                ": $",
                IWritingEditions(msg.sender).symbol(),
                "</text></svg>"
            )
        );

        string memory output = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="',
                settings,
                style,
                body
            )
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "TokenId #',
                        toString(tokenId),
                        '", "description": "',
                        IWritingEditions(msg.sender).description(),
                        '", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(output)),
                        '"}'
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    // TODO: use the contract address and tokenId to figure out settings.
    // Potentially call a "settings" contract.
    function _getSettings(address contractAddress, uint256 tokenId)
        internal
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            string memory,
            string memory
        )
    {
        return (0, 0, 350, 350, "#0E0E0E", "#ffffff");
    }

    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT license
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
}

/// [MIT License]
/// @title Base64
/// @notice Provides a function for encoding some bytes in base64
/// @author Brecht Devos <[email protected]>
library Base64 {
    bytes internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(input, 0x3F))), 0xFF)
                )
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}