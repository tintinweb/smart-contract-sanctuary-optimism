/**
 *Submitted for verification at optimistic.etherscan.io on 2022-06-05
*/

//SPDX-License-Identifier: MIT

// File: @openzeppelin/contracts/utils/Base64.sol


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

// File: @openzeppelin/contracts/utils/Strings.sol


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

// File: Utils.sol

pragma solidity ^0.8.12;

// Core utils used extensively to format CSS and numbers.
library utils {
  // used to simulate empty strings
  string internal constant NULL = '';

  // formats a CSS variable line. includes a semicolon for formatting.
  function setCssVar(string memory _key, string memory _val)
    internal
    pure
    returns (string memory)
  {
    return string.concat('--', _key, ':', _val, ';');
  }

  // formats getting a css variable
  function getCssVar(string memory _key) internal pure returns (string memory) {
    return string.concat('var(--', _key, ')');
  }

  // formats getting a def URL
  function getDefURL(string memory _id) internal pure returns (string memory) {
    return string.concat('url(#', _id, ')');
  }

  // formats rgba white with a specified opacity / alpha
  function white_a(uint256 _a) internal pure returns (string memory) {
    return rgba(255, 255, 255, _a);
  }

  // formats rgba black with a specified opacity / alpha
  function black_a(uint256 _a) internal pure returns (string memory) {
    return rgba(0, 0, 0, _a);
  }

  // formats generic rgba color in css
  function rgba(
    uint256 _r,
    uint256 _g,
    uint256 _b,
    uint256 _a
  ) internal pure returns (string memory) {
    string memory formattedA = _a < 100
      ? string.concat('0.', utils.uint2str(_a))
      : '1';
    return
      string.concat(
        'rgba(',
        utils.uint2str(_r),
        ',',
        utils.uint2str(_g),
        ',',
        utils.uint2str(_b),
        ',',
        formattedA,
        ')'
      );
  }

  // checks if two strings are equal
  function stringsEqual(string memory _a, string memory _b)
    internal
    pure
    returns (bool)
  {
    return keccak256(abi.encodePacked(_a)) == keccak256(abi.encodePacked(_b));
  }

  // returns the length of a string in characters
  function utfStringLength(string memory _str)
    internal
    pure
    returns (uint256 length)
  {
    uint256 i = 0;
    bytes memory string_rep = bytes(_str);

    while (i < string_rep.length) {
      if (string_rep[i] >> 7 == 0) i += 1;
      else if (string_rep[i] >> 5 == bytes1(uint8(0x6))) i += 2;
      else if (string_rep[i] >> 4 == bytes1(uint8(0xE))) i += 3;
      else if (string_rep[i] >> 3 == bytes1(uint8(0x1E)))
        i += 4;
        //For safety
      else i += 1;

      length++;
    }
  }

  // converts an unsigned integer to a string
  function uint2str(uint256 _i)
    internal
    pure
    returns (string memory _uintAsString)
  {
    if (_i == 0) {
      return '0';
    }
    uint256 j = _i;
    uint256 len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint256 k = len;
    while (_i != 0) {
      k = k - 1;
      uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
      bytes1 b1 = bytes1(temp);
      bstr[k] = b1;
      _i /= 10;
    }
    return string(bstr);
  }

  function getSlice(
    uint256 begin,
    uint256 end,
    string memory text
  ) internal pure returns (string memory) {
    bytes memory a = new bytes(end - begin + 1);
    for (uint256 i = 0; i <= end - begin; i++) {
      a[i] = bytes(text)[i + begin - 1];
    }
    return string(a);
  }
}

// File: SVG.sol

pragma solidity ^0.8.12;


// Core SVG utilitiy library which helps us construct
// onchain SVG's with a simple, web-like API.
library svg {
  /* MAIN ELEMENTS */
  function g(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el('g', _props, _children);
  }

  function path(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el('path', _props, _children);
  }

  function text(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el('text', _props, _children);
  }

  function line(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el('line', _props, _children);
  }

  function circle(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el('circle', _props, _children);
  }

  function circle(string memory _props) internal pure returns (string memory) {
    return el('circle', _props);
  }

  function rect(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el('rect', _props, _children);
  }

  function rect(string memory _props) internal pure returns (string memory) {
    return el('rect', _props);
  }

  function filter(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el('filter', _props, _children);
  }

  function cdata(string memory _content) internal pure returns (string memory) {
    return string.concat('<![CDATA[', _content, ']]>');
  }

  /* GRADIENTS */
  function radialGradient(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el('radialGradient', _props, _children);
  }

  function linearGradient(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el('linearGradient', _props, _children);
  }

  function gradientStop(
    uint256 offset,
    string memory stopColor,
    string memory _props
  ) internal pure returns (string memory) {
    return
      el(
        'stop',
        string.concat(
          prop('stop-color', stopColor),
          ' ',
          prop('offset', string.concat(utils.uint2str(offset), '%')),
          ' ',
          _props
        )
      );
  }

  function animateTransform(string memory _props)
    internal
    pure
    returns (string memory)
  {
    return el('animateTransform', _props);
  }

  function image(string memory _href, string memory _props)
    internal
    pure
    returns (string memory)
  {
    return el('image', string.concat(prop('href', _href), ' ', _props));
  }

  /* COMMON */
  // A generic element, can be used to construct any SVG (or HTML) element
  function el(
    string memory _tag,
    string memory _props,
    string memory _children
  ) internal pure returns (string memory) {
    return
      string.concat('<', _tag, ' ', _props, '>', _children, '</', _tag, '>');
  }

  // A generic element, can be used to construct any SVG (or HTML) element without children
  function el(string memory _tag, string memory _props)
    internal
    pure
    returns (string memory)
  {
    return string.concat('<', _tag, ' ', _props, '/>');
  }

  // an SVG attribute
  function prop(string memory _key, string memory _val)
    internal
    pure
    returns (string memory)
  {
    return string.concat(_key, '=', '"', _val, '" ');
  }
}

// File: Renderer.sol

pragma solidity ^0.8.11;





contract Renderer {
    function render(uint256 _tokenId, string memory _a)
        public
        pure
        returns (string memory)
    {
        string[7] memory colors = [
            string.concat('#ff', utils.getSlice(3, 6, _a)),
            string.concat('#', utils.getSlice(7, 12, _a)),
            string.concat('#', utils.getSlice(13, 18, _a)),
            string.concat('#', utils.getSlice(19, 24, _a)),
            string.concat('#', utils.getSlice(25, 30, _a)),
            string.concat('#', utils.getSlice(31, 36, _a)),
            string.concat('#', utils.getSlice(37, 42, _a))
        ];

        string memory image = _renderSVG(colors);

        return _renderMetaData(_tokenId, image);
    }

    // Convenience functions for formatting all the metadata related to a particular NFT

    function _renderMetaData(uint256 _tokenId, string memory image)
        internal
        pure
        returns (string memory)
    {
        return
            string.concat(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                        getEeethersJSON(
                            name(_tokenId),
                            // image data
                            Base64.encode(bytes(image))
                        )
                    )
                )
            );
    }

    function name(uint256 _tokenId) internal pure returns (string memory) {
        return string.concat('Guest #', utils.uint2str(_tokenId + 1));
    }

    function getEeethersJSON(string memory _name, string memory _imageData)
        internal
        pure
        returns (string memory)
    {
        return
            string.concat(
                '{"name": "',
                _name,
                '", "image": "data:image/svg+xml;base64,',
                _imageData,
                '","decription": "gm.\\n\\nThis NFT commemorates signing a web3 guestbook."',
                '}'
            );
    }

    function _renderGradientCircle(string[7] memory colors)
        internal
        pure
        returns (string memory)
    {
        return
            svg.el(
                'defs',
                utils.NULL,
                svg.el(
                    'linearGradient',
                    string.concat(
                        svg.prop('id', 'ethGradient'),
                        svg.prop('gradientTransform', 'rotate(90)')
                    ),
                    string.concat(_renderGradient(colors))
                )
            );
    }

    function _renderGradient(string[7] memory colors)
        internal
        pure
        returns (string memory)
    {
        return
            string.concat(
                svg.el(
                    'stop',
                    string.concat(
                        svg.prop('offset', '0%'),
                        svg.prop('stop-color', colors[0])
                    )
                ),
                svg.el(
                    'stop',
                    string.concat(
                        svg.prop('offset', '16.6%'),
                        svg.prop('stop-color', colors[1])
                    )
                ),
                svg.el(
                    'stop',
                    string.concat(
                        svg.prop('offset', '33.2%'),
                        svg.prop('stop-color', colors[2])
                    )
                ),
                svg.el(
                    'stop',
                    string.concat(
                        svg.prop('offset', '49.8%'),
                        svg.prop('stop-color', colors[3])
                    )
                ),
                svg.el(
                    'stop',
                    string.concat(
                        svg.prop('offset', '66.4%'),
                        svg.prop('stop-color', colors[4])
                    )
                ),
                svg.el(
                    'stop',
                    string.concat(
                        svg.prop('offset', '83%'),
                        svg.prop('stop-color', colors[5])
                    )
                ),
                svg.el(
                    'stop',
                    string.concat(
                        svg.prop('offset', '100%'),
                        svg.prop('stop-color', colors[6])
                    )
                )
            );
    }

    function _renderSVG(string[7] memory colors)
        internal
        pure
        returns (string memory)
    {
        return
            string.concat(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400" style="background:#fff; font-family: monospace;">',
                svg.rect(
                    string.concat(
                        svg.prop('fill', '#fff'),
                        svg.prop('stroke-width', '2'),
                        svg.prop('stroke', 'black'),
                        svg.prop('width', '398'),
                        svg.prop('height', '398'),
                        svg.prop('x', '1'),
                        svg.prop('y', '1')
                    )
                ),
                _renderGradientCircle(colors),
                svg.el(
                    'circle',
                    string.concat(
                        svg.prop('cx', '200'),
                        svg.prop('cy', '200'),
                        svg.prop('r', '100'),
                        svg.prop('fill', 'url(#ethGradient)')
                    )
                ),
                svg.text(
                    string.concat(svg.prop('x', '142'), svg.prop('y', '24')),
                    string.concat(
                        svg.el(
                            'tspan',
                            svg.prop('fill', colors[0]),
                            string.concat(colors[0], ' ')
                        ),
                        svg.el(
                            'tspan',
                            svg.prop('fill', colors[1]),
                            string.concat(colors[1], ' ')
                        ),
                        svg.el(
                            'tspan',
                            svg.prop('fill', colors[2]),
                            string.concat(colors[2], ' ')
                        ),
                        svg.el(
                            'tspan',
                            svg.prop('fill', colors[3]),
                            string.concat(colors[3], ' ')
                        )
                    )
                ),
                svg.text(
                    string.concat(svg.prop('x', '205'), svg.prop('y', '40')),
                    string.concat(
                        svg.el(
                            'tspan',
                            svg.prop('fill', colors[4]),
                            string.concat(colors[4], ' ')
                        ),
                        svg.el(
                            'tspan',
                            svg.prop('fill', colors[5]),
                            string.concat(colors[5], ' ')
                        ),
                        svg.el(
                            'tspan',
                            svg.prop('fill', colors[6]),
                            string.concat(colors[6], ' ')
                        )
                    )
                ),
                // div with svg logo
                svg.path(
                    string.concat(
                        svg.prop('transform', 'translate(16, 350)'),
                        svg.prop('fill-rule', 'evenodd'),
                        svg.prop('clip-rule', 'evenodd'),
                        svg.prop(
                            'd',
                            'M0 0v4.408h3.761v10.704h3.763l.01-10.704h3.75V0H0Zm17.556 0v15.112h3.763v-4.408h3.76v4.408h3.762V0H25.08v6.297h-3.761V0h-3.763ZM35.11 0v15.126l11.286-.014v-4.408h-3.764V6.297h-3.758V4.408h7.522V0H35.11ZM0 18.888V34h11.285v-8.815H7.524l-.002 4.408h-3.76v-6.297h7.523v-4.408H0Zm17.556 0V34h11.285V18.888h-3.763v10.705h-3.76V18.888h-3.762Zm17.554 0V34h11.286v-4.407h-3.764l.003-4.408h-3.76v-1.889h7.521v-4.408H35.11Zm17.556 0v8.815h3.763l-.002 1.89h-3.761V34h7.524v-8.815h-3.761v-1.889h3.76v-4.408h-7.523Zm13.795 0v4.408h3.763V34h3.761V23.296l3.761.003v-4.411H66.461Zm27.589 0V34h11.284V23.296h-7.522v-4.408h-3.763Zm3.76 8.815.002 1.89h3.759l.002-1.89H97.81Zm13.793-8.815V34h11.286V18.888h-11.286Zm3.764 4.408v6.297h3.758l.003-6.297h-3.761Zm13.792-4.408V34h11.287V18.888h-11.287Zm3.764 4.408v6.297h3.758l.003-6.297h-3.761Zm13.792-4.408V34h3.763v-6.297h3.759V34H158v-8.815h-3.763v-1.889h-3.759v-4.408h-3.763Zm7.524 0-.002 4.408H158v-4.408h-3.761Z'
                        ),
                        svg.prop('fill', '#000')
                    ),
                    utils.NULL
                ),
                '</svg>'
            );
    }
}