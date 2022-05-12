// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import './TicketTypeSpecificSVGHelper.sol';

contract BorrowTicketSVGHelper is TicketTypeSpecificSVGHelper {
    /**
     * @dev Returns SVG styles where the primary background color is derived
     * from the collateral asset address and the secondary background color 
     * is derived from the loan asset address
     */
    function backgroundColorsStyles(
        string memory collateralAsset,
        string memory loanAsset
    ) 
        external 
        pure
        override 
        returns (string memory)
    {
        return colorStyles(collateralAsset, loanAsset);
    }

    /// See {ITicketTypeSpecificSVGHelper}
    function ticketIdXCoordinate() external pure override returns (string memory) {
        return '134';
    }
    
    /// See {ITicketTypeSpecificSVGHelper}
    function backgroundTitleRectsXTranslate() external pure override returns (string memory) {
        return '31';
    }

    /// See {ITicketTypeSpecificSVGHelper}
    function titlesPositionClass() external pure override returns (string memory) {
        return 'right';
    }

    /// See {ITicketTypeSpecificSVGHelper}
    function titlesXTranslate() external pure override returns (string memory) {
        return '121';
    }

    /// See {ITicketTypeSpecificSVGHelper}
    function backgroundValueRectsXTranslate() external pure override returns (string memory) {
        return '129';
    }

    /// See {ITicketTypeSpecificSVGHelper}
    function alignmentClass() external pure override returns (string memory) {
        return 'left';
    }

    /// See {ITicketTypeSpecificSVGHelper}
    function valuesXTranslate() external pure override returns (string memory) {
        return '136';
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import '../interfaces/ITicketTypeSpecificSVGHelper.sol';
import "@openzeppelin/contracts/utils/Strings.sol";

contract TicketTypeSpecificSVGHelper is ITicketTypeSpecificSVGHelper {
    /// See {ITicketTypeSpecificSVGHelper-backgroundColorsStyles}
    function backgroundColorsStyles(
        string memory collateralAsset,
        string memory loanAsset
    ) 
        external 
        pure 
        override 
        virtual 
        returns (string memory) 
    {}

    /// See {ITicketTypeSpecificSVGHelper}
    function ticketIdXCoordinate() external pure virtual override returns (string memory) {}

    /// See {ITicketTypeSpecificSVGHelper}
    function backgroundTitleRectsXTranslate() external pure virtual override returns (string memory) {}

    /// See {ITicketTypeSpecificSVGHelper}
    function titlesPositionClass() external pure virtual override returns (string memory) {}
    
    /// See {ITicketTypeSpecificSVGHelper}
    function titlesXTranslate() external pure virtual override returns (string memory) {}

    /// See {ITicketTypeSpecificSVGHelper}
    function backgroundValueRectsXTranslate() external pure virtual override returns (string memory) {}

    /// See {ITicketTypeSpecificSVGHelper}
    function alignmentClass() external pure virtual override returns (string memory) {}

    /// See {ITicketTypeSpecificSVGHelper}
    function valuesXTranslate() external pure virtual override returns (string memory) {}

    /// @dev used by backgroundColorsStyles, returns SVG style classes    
    function colorStyles(string memory primary, string memory secondary) internal pure returns (string memory) {
        return string.concat(
            '.highlight-hue{stop-color:',
            addressStringToHSL(primary),
            '}',
            '.highlight-offset{stop-color:',
            addressStringToHSL(secondary),
            '}'
        );
    }

    /**
     * @dev returns a string, an HSL color specification that can be used in SVG styles. 
     * where H, S, and L, are derived from `account`
     */
    function addressStringToHSL(string memory account) private pure returns (string memory) {
        bytes32 hs = keccak256(abi.encodePacked(account));
        uint256 h = (uint256(uint8(hs[0])) + uint8(hs[1])) % 360;
        uint256 s = 80 + (uint8(hs[2]) % 20);
        uint256 l = 80 + (uint8(hs[3]) % 10);
        return string.concat(
            'hsl(',
            Strings.toString(h),
            ',',
            Strings.toString(s),
            '%,',
            Strings.toString(l),
            '%)'
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface ITicketTypeSpecificSVGHelper {
    /**
     * @notice returns a string of styles for use within an SVG
     * @param collateralAsset A string of the collateral asset address
     * @param loanAsset A string of the loan asset address
     */
    function backgroundColorsStyles(
        string memory collateralAsset,
        string memory loanAsset
        ) 
        external pure 
        returns (string memory);

    /**
     * @dev All the below methods return ticket-type-specific values
     * used in building the ticket svg image. See NFTLoanTicketSVG for usage.
     */

    function ticketIdXCoordinate() external pure returns (string memory);

    function backgroundTitleRectsXTranslate() external pure returns (string memory);

    function titlesPositionClass() external pure returns (string memory);

    function titlesXTranslate() external pure returns (string memory);

    function backgroundValueRectsXTranslate() external pure returns (string memory);

    function alignmentClass() external pure returns (string memory);

    function valuesXTranslate() external pure returns (string memory);
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