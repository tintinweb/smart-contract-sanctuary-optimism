// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Base64} from "lib/base64/base64.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "contracts/interfaces/IReliquary.sol";

contract NFTDescriptor {
    using Strings for uint;

    address public immutable reliquary;

    string internal constant IMAGE_HOST = "https://digit-public-assets.s3.ap-southeast-2.amazonaws.com/";

    constructor(address _reliquary) {
        reliquary = _reliquary;
    }

    struct LocalVariables_constructTokenURI {
        PositionInfo position;
        PoolInfo pool;
        LevelInfo levelInfo;
        string levelString;
        address underlying;
        string underlyingSymbol;
        string amount;
        string pendingReward;
        uint maturity;
        uint maturityDays;
        string maturityString;
        string rewardSymbol;
        string currentMultiplier;
        string image;
    }

    /// @notice Generate tokenURI as a base64 encoding from live on-chain values.
    function constructTokenURI(uint relicId) external view returns (string memory uri) {
        IReliquary _reliquary = IReliquary(reliquary);
        LocalVariables_constructTokenURI memory vars;
        vars.position = _reliquary.getPositionForId(relicId);
        vars.levelString = (vars.position.level + 1).toString();
        vars.pool = _reliquary.getPoolInfo(vars.position.poolId);
        vars.underlying = address(_reliquary.poolToken(vars.position.poolId));
        vars.pendingReward = generateDecimalString(_reliquary.pendingReward(relicId), 18);
        vars.maturity = block.timestamp - vars.position.entry;
        vars.maturityDays = vars.maturity / 1 days;
        vars.maturityString = vars.maturityDays == 1 ? "1 day" : string.concat(vars.maturityDays.toString(), " days");
        vars.rewardSymbol = IERC20Metadata(address(_reliquary.rewardToken())).symbol();
        vars.levelInfo = _reliquary.getLevelInfo(vars.position.poolId);

        // sets vars.amount and vars.underlyingSymbol used in generateSVGImage
        string memory tokenText = generateTextFromToken(vars);
        // sets vars.currentMultiplier used in generateSVGImage
        string memory multiplierBox = generateRewardMultipliers(vars);

        vars.image = Base64.encode(
            abi.encodePacked(
                generateSVGImage(vars),
                generateImageText(vars, relicId),
                multiplierBox,
                generateBars(vars),
                tokenText,
                "</svg>"
            )
        );

        uri = string.concat(
            "data:application/json;base64,",
            Base64.encode(
                abi.encodePacked(
                    '{"name":"',
                    "Digit ID #",
                    relicId.toString(),
                    ": ",
                    vars.pool.name,
                    '", "description":"',
                    generateDescription(vars.pool.name),
                    '", "attributes": [',
                    generateAttributes(vars),
                    '], "image": "',
                    "data:image/svg+xml;base64,",
                    vars.image,
                    '"}'
                )
            )
        );
    }

    /// @notice Generate description of the liquidity position for NFT metadata.
    /// @param poolName Name of pool as provided by operator.
    function generateDescription(string memory poolName) internal pure returns (string memory description) {
        description = string.concat(
            "This NFT represents a position in a Digit ",
            poolName,
            " pool. ",
            "The owner of this NFT can modify or redeem the position."
        );
    }

    /// @notice Generate attributes for NFT metadata.
    function generateAttributes(LocalVariables_constructTokenURI memory vars)
        internal
        pure
        returns (string memory attributes)
    {
        attributes = string.concat(
            '{"trait_type": "Pool ID", "value": ',
            vars.position.poolId.toString(),
            '}, {"trait_type": "Amount Deposited", "value": "',
            vars.amount,
            '"}, {"trait_type": "Pending ',
            vars.rewardSymbol,
            '", "value": "',
            vars.pendingReward,
            '"}, {"trait_type": "Maturity", "value": "',
            vars.maturityString,
            '"}, {"trait_type": "Level", "value": ',
            vars.levelString,
            "}"
        );
    }

    /**
     * @notice Generate the first part of the SVG for this NFT.
     */
    function generateSVGImage(LocalVariables_constructTokenURI memory vars) internal pure returns (string memory svg) {
        svg = string.concat(
            '<svg class="container" width="300" height="450" viewBox="0 0 600 900" fill="none" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">'
            "<style>" ".text {" 'font-family: "Public Sans", sans-serif;' "font-style: normal;" "}" ".backTextLarge {"
            "fill: #53455B;" "font-weight: 800;" "font-size: 32px;" "text-anchor: end;" "}" ".backTextMedium {"
            "fill: #53455B;" "font-weight: 800;" "font-size: 24px;" "text-anchor: end;" "}" ".backTextSmall {"
            "fill: #908A98;" "font-weight: 700;" "font-size: 16px;" "}" ".backTextOverBar {" "fill: #FFFFFF;"
            "font-weight: 600;" "font-size: 16px;" "text-anchor: middle" "}" ".textShadow {"
            "filter: drop-shadow(0 0 2px rgba(0, 0, 0, 0.7))" "}" ".container {" "background-color: transparent;"
            "perspective: 1000px;" "}" ".flipper {" "position: relative;" "transform-origin: 50% 50%;"
            "transform-style: preserve-3d;" "transition: transform 0.5s;" "}" ".container:hover .flipper {"
            "transform: rotateY(180deg);" "}" ".frontFace, .backFace {" "backface-visibility: hidden;"
            "position: absolute;" "transition: opacity 0.5s;" "width: 100%;" "height: 100%;" "}"
            ".container:hover .frontFace {" "opacity: 0;" "}" ".backFace {" "opacity: 0;" "transform-origin: 50% 50%;"
            "transform: rotateY(180deg);" "}" ".container:hover .backFace {" "opacity: 1;" "}" ".level {"
            "font-weight: 800;" "font-size: 14px;" "fill: #FFFFFF;" "}" ".level:hover {" "fill: #ABC123;" "}" ".label {"
            "font-weight: 400;" "font-size: 9px;" "fill: #FFFFFF;" "}" ".label.back {" "fill: #888292;" "}"
            ".headlineValue {" "font-weight: 800;" "font-size: 18px;" "fill: #FFFFFF;" "text-anchor: end;" "}"
            ".white {" "fill: #FFFFFF;" "}" "</style>" "<defs>" "<style>"
            '@import url("https://fonts.googleapis.com/css2?family=Public+Sans:[email protected];500;600;700;800&amp;display=swap");'
            "</style>"
            '<linearGradient id="paint0_linear_302_24893" x1="99" y1="158" x2="453" y2="766" gradientUnits="userSpaceOnUse">'
            '<stop stop-color="#FFE49F"/>' '<stop offset="1" stop-color="#BC8856"/>' "</linearGradient>"
            '<linearGradient id="paint0_linear_308_24240" x1="73" y1="272.462" x2="418" y2="272.462" gradientUnits="userSpaceOnUse">'
            '<stop stop-color="#735086"/>' '<stop offset="1" stop-color="#8C59A8"/>' "</linearGradient>"
            '<linearGradient id="paint1_linear_308_24240" x1="74" y1="280.615" x2="448" y2="280.615" gradientUnits="userSpaceOnUse">'
            '<stop stop-color="#735086"/>' '<stop offset="1" stop-color="#8C59A8"/>' "</linearGradient>"
            '<linearGradient id="paint2_linear_308_24240" x1="154.37" y1="347.686" x2="236.895" y2="347.686" gradientUnits="userSpaceOnUse">'
            '<stop stop-color="#735086"/>' '<stop offset="1" stop-color="#AD7CEC"/>' "</linearGradient>"
            '<linearGradient id="paint3_linear_308_24240" x1="171.498" y1="596.445" x2="171.498" y2="609.761" gradientUnits="userSpaceOnUse">'
            '<stop stop-color="#AD7CEC"/>' '<stop offset="1" stop-color="#735086"/>' "</linearGradient>" "</defs>"
            '<g class="flipper">' '<g class="frontFace">'
            '<rect width="600" height="900" rx="40" fill="url(#paint0_linear_302_24893)"/>'
            '<image width="600" height="900" href="',
            IMAGE_HOST,
            "lvl",
            vars.levelString,
            '.png"/>' '<image x="443" y="36" width="120" height="120" href="',
            IMAGE_HOST,
            vars.pool.name
        );
        svg = string.concat(
            svg,
            '.svg"/>' '<rect class="levelBox" x="36" y="36" width="134" height="30" rx="15" fill="#3F3644"/>'
            '<text x="53" y="56" textLength="100" class="text level">LEVEL ',
            vars.levelString,
            "</text>" '<rect x="36" y="167" width="367" height="45" rx="10" fill="#3F3644"/>'
            '<text x="392" y="202" class="text headlineValue">',
            vars.currentMultiplier,
            "</text>" '<text x="46" y="187" class="text label">Reward</text>'
            '<text x="46" y="198" class="text label">Multiplier</text>'
            '<rect x="36" y="242" width="367" height="45" rx="10" fill="#3F3644"/>'
            '<text x="392" y="277" class="text headlineValue">',
            vars.amount,
            " ",
            vars.underlyingSymbol,
            "</text>" '<text x="46" y="263" class="text label">Your</text>'
            '<text x="46" y="273" class="text label">Investment</text>' "</g>"
        );
    }

    struct ProgressInfo {
        uint progress;
        string label;
        string fill;
    }

    /// @notice Generate the first part of text labels for this NFT image.
    function generateImageText(LocalVariables_constructTokenURI memory vars, uint relicId)
        internal
        pure
        returns (string memory text)
    {
        ProgressInfo memory progressInfo;
        if (vars.position.level != vars.levelInfo.requiredMaturities.length - 1) {
            progressInfo.progress = 100 * (vars.maturity - vars.levelInfo.requiredMaturities[vars.position.level])
                / (
                    vars.levelInfo.requiredMaturities[vars.position.level + 1]
                        - vars.levelInfo.requiredMaturities[vars.position.level]
                );

            if (progressInfo.progress > 100) progressInfo.progress = 100;

            progressInfo.label = string.concat(progressInfo.progress.toString(), "%");
            progressInfo.fill = "url(#paint1_linear_308_24240)";
        } else {
            progressInfo.progress = 100;
            progressInfo.label = "MAX LEVEL REACHED";
            progressInfo.fill = "url(#paint0_linear_302_24893)";
        }

        text = string.concat(
            '<g class="backFace">' '<rect width="600" height="900" rx="40" fill="url(#paint0_linear_302_24893)"/>'
            '<rect x="25" y="25" width="550" height="850" rx="20" fill="white"/>'
            '<rect x="65" y="68" width="470" height="54" rx="10" fill="#DEDCE0"/>'
            '<text x="75" y="85" class="text label back">POSITION STRATEGY</text>'
            '<text x="525" y="109" class="text backTextLarge">',
            vars.pool.name,
            "</text>" '<rect x="398" y="130" width="137" height="45" rx="10" fill="#735086"/>'
            '<text x="466.5" y="161" class="text backTextMedium white" style="text-anchor: middle">LEVEL ',
            vars.levelString,
            "</text>" '<rect x="65" y="233" width="470" height="65" rx="10" fill="#DEDCE0"/>'
            '<text x="75" y="248" class="text label back">PROGRESS TO NEXT LEVEL</text>' '<rect x="75" y="256" width="',
            (progressInfo.progress * 450 / 100).toString(),
            '" height="32" rx="5" fill="',
            progressInfo.fill,
            '"/>' '<text x="300" y="277" class="text textShadow backTextOverBar">',
            progressInfo.label,
            "</text>"
        );
        text = string.concat(
            text,
            '<rect x="65" y="729" width="470" height="45" rx="10" fill="#DEDCE0"/>'
            '<text x="75" y="746" class="text label back">PENDING ',
            vars.rewardSymbol,
            "</text>" '<text x="525" y="761" class="text backTextMedium">',
            vars.pendingReward,
            "</text>" '<rect x="307" y="787" width="228" height="45" rx="10" fill="#DEDCE0"/>'
            '<text x="317" y="804" class="text label back">MATURITY</text>'
            '<text x="525" y="819" class="text backTextMedium">',
            vars.maturityString,
            "</text>" '<text x="65" y="829" class="text backTextSmall">ID: ',
            relicId.toString(),
            "</text>"
        );
    }

    /// @notice Generate Reward APY box
    function generateRewardMultipliers(LocalVariables_constructTokenURI memory vars)
        internal
        pure
        returns (string memory text)
    {
        require(vars.levelInfo.multipliers.length <= 12);

        text = '<rect x="65" y="306" width="470" height="96" rx="10" fill="#DEDCE0"/>'
            '<text x="75" y="323" class="text label back">REWARD APY</text>';

        uint widthDivisor = vars.levelInfo.multipliers.length;
        if (widthDivisor > 6) {
            widthDivisor = 6;
        }
        uint barWidth = 45800 / widthDivisor - 800;

        for (uint i = 0; i < vars.levelInfo.multipliers.length; ++i) {
            uint multiplier = 100 * vars.levelInfo.multipliers[i] / vars.levelInfo.multipliers[0];
            string memory multiplierString = string.concat(generateDecimalString(multiplier, 2), "x");

            string memory fill;
            if (vars.position.level == i) {
                fill = "#AD7CEC";
                vars.currentMultiplier = multiplierString;
            } else if (i < vars.position.level) {
                fill = "#735086";
            } else {
                fill = "#C0B9C9";
            }

            bool isSecondRow = i > 5;
            uint barX = 7500 + (isSecondRow ? i - 6 : i) * (barWidth + 800);
            uint labelX = barX + barWidth / 2;
            text = string.concat(
                text,
                '<rect x="',
                generateDecimalString(barX, 2),
                '" y="',
                isSecondRow ? "365" : "337",
                '" width="',
                generateDecimalString(barWidth, 2)
            );
            text = string.concat(
                text,
                '" height="22" rx="5" fill="',
                fill,
                '"/>' '<text x="',
                generateDecimalString(labelX, 2),
                '" y="',
                isSecondRow ? "381" : "353",
                '" class="text backTextOverBar">',
                multiplierString,
                "</text>"
            );
        }
    }

    /// @notice Generate further text labels specific to the underlying token.
    function generateTextFromToken(LocalVariables_constructTokenURI memory vars)
        internal
        view
        virtual
        returns (string memory text)
    {
        vars.underlyingSymbol = IERC20Metadata(vars.underlying).symbol();
        vars.amount = generateDecimalString(vars.position.amount, IERC20Metadata(vars.underlying).decimals());

        text = string.concat(
            '<image x="65" y="130" widht="45" height="45" href="',
            IMAGE_HOST,
            vars.underlyingSymbol,
            '.svg"/>' '<text x="65" y="199" class="text backTextSmall">',
            vars.underlyingSymbol,
            ": ",
            vars.amount,
            "</text>" '<rect x="65" y="657" width="470" height="59" rx="10" fill="#DEDCE0"/>'
            '<text x="75" y="674" class="text label back">AMOUNT</text>'
            '<text x="525" y="699" class="text backTextLarge">',
            vars.amount,
            "</text></g></g>"
        );
    }

    /// @notice Generate bar graph of this pool's bonding curve and indicator of the position's placement.
    function generateBars(LocalVariables_constructTokenURI memory vars) internal pure returns (string memory bars) {
        uint highestMultiplier = vars.levelInfo.multipliers[0];
        for (uint i = 1; i < vars.levelInfo.multipliers.length; i++) {
            if (vars.levelInfo.multipliers[i] > highestMultiplier) {
                highestMultiplier = vars.levelInfo.multipliers[i];
            }
        }

        bars = '<rect x="65" y="410" width="470" height="234" rx="10" fill="#DEDCE0"/>'
            '<text x="75" y="427" class="text label back">OVERVIEW</text>';
        for (uint i; i < vars.levelInfo.multipliers.length; i++) {
            string memory fill;
            if (i <= vars.position.level) {
                fill = "#735086";
            } else {
                fill = "#C0B9C9";
            }
            uint barsInColumn = vars.levelInfo.multipliers[i] * 12 / highestMultiplier;
            if (barsInColumn == 0) {
                barsInColumn = 1;
            }
            uint barWidth = 45300 / vars.levelInfo.multipliers.length - 300;
            uint barX = 7500 + i * (barWidth + 300);
            for (uint j; j < barsInColumn; ++j) {
                if (i == vars.position.level && j == barsInColumn - 1) {
                    fill = "#AD7CEC";
                }
                bars = string.concat(
                    bars,
                    '<rect x="',
                    generateDecimalString(barX, 2),
                    '" y="',
                    (616 - j * 16).toString(),
                    '" width="',
                    generateDecimalString(barWidth, 2),
                    '" height="13" rx="3" fill="',
                    fill,
                    '"/>'
                );
            }
        }
    }

    /**
     * @notice Generate human-readable string from a number with given decimal places.
     * Does not work for amounts with more than 18 digits before decimal point.
     * @param num A number.
     * @param decimals Number of decimal places.
     */
    function generateDecimalString(uint num, uint decimals) internal pure returns (string memory decString) {
        if (num == 0) {
            return "0";
        }

        uint numLength;
        uint temp = num;
        uint trailingZeros;
        bool hitNonzero;
        do {
            ++numLength;
            if (!hitNonzero && numLength < decimals && temp % 10 == 0) {
                ++trailingZeros;
            } else {
                hitNonzero = true;
            }
            temp /= 10;
        } while (temp != 0);

        num /= 10 ** trailingZeros;
        bool lessThanOne = numLength <= decimals;
        uint bufferLength;
        if (lessThanOne) {
            bufferLength = decimals + 2 - trailingZeros;
        } else {
            numLength -= trailingZeros;
            decimals -= trailingZeros;
            if (numLength > 19) {
                uint difference = numLength - 19;
                decimals -= difference > decimals ? decimals : difference;
                num /= 10 ** difference;
                bufferLength = 20;
            } else {
                bufferLength = numLength + 1;
            }
        }
        bytes memory buffer = new bytes(bufferLength);

        if (lessThanOne) {
            buffer[0] = "0";
            buffer[1] = ".";
            for (uint i = 0; i < decimals - numLength; i++) {
                buffer[i + 2] = "0";
            }
        }
        uint index = bufferLength - 1;
        while (num != 0) {
            if (!lessThanOne && index == bufferLength - decimals - 1) {
                buffer[index--] = ".";
            }
            buffer[index] = bytes1(uint8(48 + num % 10));
            num /= 10;
            unchecked {
                index--;
            }
        }

        decString = string(buffer);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

/// @title Base64
/// @author Brecht Devos - <[email protected]>
/// @notice Provides functions for encoding/decoding base64
library Base64 {
    string internal constant TABLE_ENCODE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    bytes  internal constant TABLE_DECODE = hex"0000000000000000000000000000000000000000000000000000000000000000"
                                            hex"00000000000000000000003e0000003f3435363738393a3b3c3d000000000000"
                                            hex"00000102030405060708090a0b0c0d0e0f101112131415161718190000000000"
                                            hex"001a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132330000000000";

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';

        // load the table into memory
        string memory table = TABLE_ENCODE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 3 bytes at a time
            for {} lt(dataPtr, endPtr) {}
            {
                // read 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // write 4 characters
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr( 6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(        input,  0x3F))))
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }

        return result;
    }

    function decode(string memory _data) internal pure returns (bytes memory) {
        bytes memory data = bytes(_data);

        if (data.length == 0) return new bytes(0);
        require(data.length % 4 == 0, "invalid base64 decoder input");

        // load the table into memory
        bytes memory table = TABLE_DECODE;

        // every 4 characters represent 3 bytes
        uint256 decodedLen = (data.length / 4) * 3;

        // add some extra buffer at the end required for the writing
        bytes memory result = new bytes(decodedLen + 32);

        assembly {
            // padding with '='
            let lastBytes := mload(add(data, mload(data)))
            if eq(and(lastBytes, 0xFF), 0x3d) {
                decodedLen := sub(decodedLen, 1)
                if eq(and(lastBytes, 0xFFFF), 0x3d3d) {
                    decodedLen := sub(decodedLen, 1)
                }
            }

            // set the actual output length
            mstore(result, decodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 4 characters at a time
            for {} lt(dataPtr, endPtr) {}
            {
               // read 4 characters
               dataPtr := add(dataPtr, 4)
               let input := mload(dataPtr)

               // write 3 bytes
               let output := add(
                   add(
                       shl(18, and(mload(add(tablePtr, and(shr(24, input), 0xFF))), 0xFF)),
                       shl(12, and(mload(add(tablePtr, and(shr(16, input), 0xFF))), 0xFF))),
                   add(
                       shl( 6, and(mload(add(tablePtr, and(shr( 8, input), 0xFF))), 0xFF)),
                               and(mload(add(tablePtr, and(        input , 0xFF))), 0xFF)
                    )
                )
                mstore(resultPtr, shl(232, output))
                resultPtr := add(resultPtr, 3)
            }
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
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
pragma solidity ^0.8.15;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/**
 * @notice Info for each Reliquary position.
 * `amount` LP token amount the position owner has provided.
 * `rewardDebt` Amount of reward token accumalated before the position's entry or last harvest.
 * `rewardCredit` Amount of reward token owed to the user on next harvest.
 * `entry` Used to determine the maturity of the position.
 * `poolId` ID of the pool to which this position belongs.
 * `level` Index of this position's level within the pool's array of levels.
 */
struct PositionInfo {
    uint amount;
    uint rewardDebt;
    uint rewardCredit;
    uint entry; // position owner's relative entry into the pool.
    uint poolId; // ensures that a single Relic is only used for one pool.
    uint level;
}

/**
 * @notice Info of each Reliquary pool.
 * `accRewardPerShare` Accumulated reward tokens per share of pool (1 / 1e12).
 * `lastRewardTime` Last timestamp the accumulated reward was updated.
 * `allocPoint` Pool's individual allocation - ratio of the total allocation.
 * `name` Name of pool to be displayed in NFT image.
 * `allowPartialWithdrawals` Whether users can withdraw less than their entire position.
 *     A value of false will also disable shift and split functionality.
 */
struct PoolInfo {
    uint accRewardPerShare;
    uint lastRewardTime;
    uint allocPoint;
    string name;
    bool allowPartialWithdrawals;
}

/**
 * @notice Info for each level in a pool that determines how maturity is rewarded.
 * `requiredMaturities` The minimum maturity (in seconds) required to reach each Level.
 * `multipliers` Multiplier for each level applied to amount of incentivized token when calculating rewards in the pool.
 *     This is applied to both the numerator and denominator in the calculation such that the size of a user's position
 *     is effectively considered to be the actual number of tokens times the multiplier for their level.
 *     Also note that these multipliers do not affect the overall emission rate.
 * `balance` Total (actual) number of tokens deposited in positions at each level.
 */
struct LevelInfo {
    uint[] requiredMaturities;
    uint[] multipliers;
    uint[] balance;
}

/**
 * @notice Object representing pending rewards and related data for a position.
 * `relicId` The NFT ID of the given position.
 * `poolId` ID of the pool to which this position belongs.
 * `pendingReward` pending reward amount for a given position.
 */
struct PendingReward {
    uint relicId;
    uint poolId;
    uint pendingReward;
}

interface IReliquary is IERC721Enumerable {
    function setEmissionCurve(address _emissionCurve) external;
    function addPool(
        uint allocPoint,
        address _poolToken,
        address _rewarder,
        uint[] calldata requiredMaturity,
        uint[] calldata allocPoints,
        string memory name,
        address _nftDescriptor,
        bool allowPartialWithdrawals
    ) external;
    function modifyPool(
        uint pid,
        uint allocPoint,
        address _rewarder,
        string calldata name,
        address _nftDescriptor,
        bool overwriteRewarder
    ) external;
    function massUpdatePools(uint[] calldata pids) external;
    function updatePool(uint pid) external;
    function deposit(uint amount, uint relicId) external;
    function withdraw(uint amount, uint relicId) external;
    function harvest(uint relicId, address harvestTo) external;
    function withdrawAndHarvest(uint amount, uint relicId, address harvestTo) external;
    function emergencyWithdraw(uint relicId) external;
    function updatePosition(uint relicId) external;
    function getPositionForId(uint) external view returns (PositionInfo memory);
    function getPoolInfo(uint) external view returns (PoolInfo memory);
    function getLevelInfo(uint) external view returns (LevelInfo memory);
    function pendingRewardsOfOwner(address owner) external view returns (PendingReward[] memory pendingRewards);
    function relicPositionsOfOwner(address owner)
        external
        view
        returns (uint[] memory relicIds, PositionInfo[] memory positionInfos);
    function isApprovedOrOwner(address, uint) external view returns (bool);
    function createRelicAndDeposit(address to, uint pid, uint amount) external returns (uint id);
    function split(uint relicId, uint amount, address to) external returns (uint newId);
    function shift(uint fromId, uint toId, uint amount) external;
    function merge(uint fromId, uint toId) external;
    function burn(uint tokenId) external;
    function pendingReward(uint relicId) external view returns (uint pending);
    function levelOnUpdate(uint relicId) external view returns (uint level);
    function poolLength() external view returns (uint);

    function rewardToken() external view returns (address);
    function nftDescriptor(uint) external view returns (address);
    function emissionCurve() external view returns (address);
    function poolToken(uint) external view returns (address);
    function rewarder(uint) external view returns (address);
    function totalAllocPoint() external view returns (uint);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

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
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
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