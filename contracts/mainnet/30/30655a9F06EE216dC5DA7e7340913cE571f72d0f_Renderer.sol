/**
 *Submitted for verification at optimistic.etherscan.io on 2022-05-06
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
  function render(uint256 _tokenId, string memory _a) public pure returns (string memory) {

    string[7] memory colors = [
      string.concat('ff', utils.getSlice(3, 6, _a)),
      utils.getSlice(7, 12, _a),
      utils.getSlice(13, 18, _a),
      utils.getSlice(19, 24, _a),
      utils.getSlice(25, 30, _a),
      utils.getSlice(31, 36, _a),
      utils.getSlice(37, 42, _a)
    ];

    string memory image = _render(_tokenId, colors);

    return
      string.concat(
        'data:application/json;base64,',
        Base64.encode(
          bytes(
            getEeethersJSON(
              name(_tokenId),
              // image data
              Base64.encode(bytes(image)),
              attributes(colors, _tokenId)
            )
          )
        )
      );
  }

  function _render(uint256 _tokenId, string[7] memory colors)
    internal
    pure
    returns (string memory)
  {
    return
      string.concat(
        '<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%" viewBox="0 0 1000 1000" style="background: #F2F3F5;">',
        svg.el(
          'filter',
          string.concat(svg.prop('id', 'filter')),
          string.concat(
            svg.el(
              'feTurbulence',
              string.concat(
                svg.prop('type', 'fractalNoise'),
                svg.prop('baseFrequency', '0.01'),
                svg.prop('numOctaves', '3'),
                svg.prop('seed', utils.uint2str(_tokenId))
              )
            ),
            svg.el(
              'feDisplacementMap',
              string.concat(
                svg.prop('in', 'SourceGraphic'),
                svg.prop('yChannelSelector', 'R'),
                svg.prop('scale', '99')
              )
            )
          )
        ),
        svg.g(
          string.concat(
            svg.prop('filter', 'url(#filter)'),
            svg.prop('fill', 'none'),
            svg.prop('stroke', string.concat('#ff', colors[0])),
            svg.prop('stroke-width', '140%'),
            svg.prop('stroke-dasharray', '99')
          ),
          dashArray(colors)
        ),
        '</svg>'
      );
  }

  function dashArray(string[7] memory colors)
    internal
    pure
    returns (string memory)
  {
    return
      string.concat(
        svg.circle(
          string.concat(
            svg.prop('id', 'c'),
            svg.prop('cx', '50%'),
            svg.prop('cy', '50%'),
            svg.prop('r', '70%'),
            svg.prop('style', 'transform-origin: center')
          ),
          svg.animateTransform(
            string.concat(
              svg.prop('attributeName', 'transform'),
              svg.prop('attributeType', 'XML'),
              svg.prop('type', 'rotate'),
              svg.prop('from', '0 0 0'),
              svg.prop('to', '360 0 0'),
              svg.prop('dur', '120s'),
              svg.prop('repeatCount', 'indefinite')
            )
          )
        ),
        string.concat(
          svg.el(
            'use',
            string.concat(
              svg.prop('href', '#c'),
              svg.prop('stroke', string.concat('#', colors[1])),
              svg.prop('stroke-dasharray', '99 60')
            )
          ),
          svg.el(
            'use',
            string.concat(
              svg.prop('href', '#c'),
              svg.prop('stroke', string.concat('#', colors[2])),
              svg.prop('stroke-dasharray', '99 120')
            )
          ),
          svg.el(
            'use',
            string.concat(
              svg.prop('href', '#c'),
              svg.prop('stroke', string.concat('#', colors[3])),
              svg.prop('stroke-dasharray', '99 180')
            )
          ),
          svg.el(
            'use',
            string.concat(
              svg.prop('href', '#c'),
              svg.prop('stroke', string.concat('#', colors[4])),
              svg.prop('stroke-dasharray', '99 240')
            )
          ),
          svg.el(
            'use',
            string.concat(
              svg.prop('href', '#c'),
              svg.prop('stroke', string.concat('#', colors[5])),
              svg.prop('stroke-dasharray', '99 300')
            )
          ),
          svg.el(
            'use',
            string.concat(
              svg.prop('href', '#c'),
              svg.prop('stroke', string.concat('#', colors[6])),
              svg.prop('stroke-dasharray', '99 360')
            )
          )
        )
      );
  }

  function attributes(string[7] memory colors, uint256 _tokenId)
    internal
    pure
    returns (string memory)
  {
    return
      string.concat(
        attributeString('Base Color', '#F2F3F5'),
        ',',
        attributeString('Color 1', string.concat('#ff', colors[0])),
        ',',
        attributeString('Color 2', string.concat('#', colors[1])),
        ',',
        attributeString('Color 3', string.concat('#', colors[2])),
        ',',
        attributeString('Color 4', string.concat('#', colors[3])),
        ',',
        attributeString('Color 5', string.concat('#', colors[4])),
        ',',
        attributeString('Color 6', string.concat('#', colors[5])),
        ',',
        attributeString('Color 7', string.concat('#', colors[6])),
        ',',
        attributeString('Seed', utils.uint2str(_tokenId))
      );
  }

  function name(uint256 _tokenId) internal pure returns (string memory) {
    return string.concat('Eeethers #', utils.uint2str(_tokenId + 1));
  }

  // Convenience functions for formatting all the metadata related to a particular NFT

  function getEeethersJSON(
    string memory _name,
    string memory _imageData,
    string memory _attributes
  ) internal pure returns (string memory) {
    return
      string.concat(
        '{"name": "',
        _name,
        '", "image": "data:image/svg+xml;base64,',
        _imageData,
        '","decription": "Exploring Ethereums endless spectrum of colors."',
        ',"attributes":[',
        _attributes,
        ']}'
      );
  }

  function attributeString(string memory _name, string memory _value)
    internal
    pure
    returns (string memory)
  {
    return
      string.concat(
        '{',
        kv('trait_type', string.concat('"', _name, '"')),
        ',',
        kv('value', string.concat('"', _value, '"')),
        '}'
      );
  }

  function kv(string memory _key, string memory _value)
    internal
    pure
    returns (string memory)
  {
    return string.concat('"', _key, '"', ':', _value);
  }
}