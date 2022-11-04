// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface ISVGModule {
  function decode(bytes memory input) external view returns (string memory);

  function getEncoding() external view returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/utils/Strings.sol";

contract SVGColor {
  using Strings for uint256;
  using Strings for uint8;

  mapping(string => bytes) public colors;

  constructor() {
    colors["Black"] = hex"000000";
    colors["White"] = hex"FFFFFF";
    colors["Dark1"] = hex"232323";
    colors["Dark2"] = hex"464646";
  }

  function getColor(string memory _colorName) public view returns (bytes memory) {
    require(colors[_colorName].length == 3, "Unknown color");
    return abi.encodePacked(colors[_colorName], hex"64");
  }

  function getColor(string memory _colorName, uint8 _alpha) public view returns (bytes memory) {
    require(colors[_colorName].length == 3, "Unknown color");
    return abi.encodePacked(colors[_colorName], _alpha);
  }

  function getRgba(string memory _colorName) public view returns (string memory) {
    return string(toRgba(getColor(_colorName), 0));
  }

  // Input: array of colors (without alpha)
  // Ouputs a linearGradient
  function autoLinearGradient(
    bytes memory _colors,
    bytes memory _id,
    bytes memory _customAttributes
  ) public view returns (bytes memory) {
    return this.autoLinearGradient("", _colors, _id, _customAttributes);
  }

  function autoLinearGradient(
    bytes memory _coordinates,
    bytes memory _colors,
    bytes memory _id,
    bytes memory _customAttributes
  ) external view returns (bytes memory) {
    bytes memory _b;
    if (_coordinates.length > 3) {
      _b = abi.encodePacked(uint8(128), _coordinates);
    } else {
      _b = hex"00";
    }
    // Count the number of colors passed, each on 4 byte
    uint256 colorCount = _colors.length / 4;
    uint8 i = 0;
    while (i < colorCount) {
      _b = abi.encodePacked(
        _b,
        uint8(i * (100 / (colorCount - 1))), // grad. stop %
        uint8(_colors[i * 4]),
        uint8(_colors[i * 4 + 1]),
        uint8(_colors[i * 4 + 2]),
        uint8(_colors[i * 4 + 3])
      );
      i++;
    }
    return linearGradient(_b, _id, _customAttributes);
  }

  function linearGradient(
    bytes memory _lg,
    bytes memory _id,
    bytes memory _customAttributes
  ) public pure returns (bytes memory) {
    bytes memory grdata;
    uint8 offset = 1;

    if (uint8(_lg[0]) & 128 == 128) {
      grdata = abi.encodePacked(
        'x1="',
        byte2uint8(_lg, 1).toString(),
        '%" x2="',
        byte2uint8(_lg, 2).toString(),
        '%" y1="',
        byte2uint8(_lg, 3).toString(),
        '%" y2="',
        byte2uint8(_lg, 4).toString(),
        '%"'
      );
      offset = 5;
    }
    grdata = abi.encodePacked('<linearGradient id="', _id, '" ', _customAttributes, grdata, ">");
    for (uint256 i = offset; i < _lg.length; i += 5) {
      grdata = abi.encodePacked(
        grdata,
        '<stop offset="',
        byte2uint8(_lg, i).toString(),
        '%" stop-color="',
        toRgba(_lg, i + 1),
        '" id="',
        _id,
        byte2uint8(_lg, i).toString(),
        '"/>'
      );
    }
    return abi.encodePacked(grdata, "</linearGradient>");
  }

  function toRgba(bytes memory _rgba, uint256 offset) public pure returns (bytes memory) {
    return
      abi.encodePacked(
        "rgba(",
        byte2uint8(_rgba, offset).toString(),
        ",",
        byte2uint8(_rgba, offset + 1).toString(),
        ",",
        byte2uint8(_rgba, offset + 2).toString(),
        ",",
        byte2uint8(_rgba, offset + 3).toString(),
        "%)"
      );
  }

  function byte2uint8(bytes memory _data, uint256 _offset) public pure returns (uint8) {
    require(_data.length > _offset, "Out of range");
    return uint8(_data[_offset]);
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
    string memory formattedA = _a < 100 ? string.concat("0.", uint2str(_a)) : "1";
    return
      string.concat(
        "rgba(",
        uint2str(_r),
        ",",
        uint2str(_g),
        ",",
        uint2str(_b),
        ",",
        formattedA,
        ")"
      );
  }

  function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
    if (_i == 0) {
      return "0";
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
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { svg } from "./svg.sol";
import { svgUtils } from "./svgUtils.sol";
import { SVGColor } from "./SVGColor.sol";

contract SVGLibrary {
  address private _colors;

  bytes32 private immutable BUILD = keccak256("BUILD");
  bytes32 private immutable COLOR = keccak256("COLOR");
  bytes32 private immutable UTILS = keccak256("UTILS");

  mapping(bytes32 => address) _modules;

  constructor(address _colors_) {
    _colors = _colors_;
  }

  function execute(bytes32 package, bytes calldata input)
    external
    view
    returns (string memory data)
  {
    if (_modules[package] != 0x0000000000000000000000000000000000000000) {
      (bool success, bytes memory data) = address(_modules[package]).staticcall(input);
      return string(data);
    } else if (package == BUILD) {
      (bool success, bytes memory data) = address(svg).staticcall(input);
      return string(data);
    } else if (package == COLOR) {
      (bool success, bytes memory data) = _colors.staticcall(input);
      return string(data);
    } else if (package == UTILS) {
      (bool success, bytes memory data) = address(svgUtils).staticcall(input);
      return string(data);
    } else {
      return string(data);
      revert("SVGLibrary:invalid-operation");
    }
  }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./svgUtils.sol";

/**
 * @title svg
 * @author Kames Geraghty
 * @notice SVG construction library using web-like API.
 * @dev Original code from w1nt3r-eth/hot-chain-svg (https://github.com/w1nt3r-eth/hot-chain-svg)
 */
library svg {
  using Strings for uint256;
  using Strings for uint8;

  function g(string memory _props, string memory _children) internal pure returns (string memory) {
    return el("g", _props, _children);
  }

  function path(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el("path", _props, _children);
  }

  function text(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el("text", _props, _children);
  }

  function line(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el("line", _props, _children);
  }

  function circle(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el("circle", _props, _children);
  }

  function circle(string memory _props) internal pure returns (string memory) {
    return el("circle", _props);
  }

  function rect(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el("rect", _props, _children);
  }

  function rect(string memory _props) internal pure returns (string memory) {
    return el("rect", _props);
  }

  function stop(string memory _props) internal pure returns (string memory) {
    return el("stop", _props);
  }

  function filter(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el("filter", _props, _children);
  }

  function defs(string memory _children) internal pure returns (string memory) {
    return el("defs", "", _children);
  }

  function cdata(string memory _content) internal pure returns (string memory) {
    return string.concat("<![CDATA[", _content, "]]>");
  }

  /* GRADIENTS */
  function radialGradient(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el("radialGradient", _props, _children);
  }

  function linearGradient(string memory _props, string memory _children)
    internal
    pure
    returns (string memory)
  {
    return el("linearGradient", _props, _children);
  }

  function gradientStop(
    uint256 offset,
    string memory stopColor,
    string memory _props
  ) internal pure returns (string memory) {
    return
      el(
        "stop",
        string.concat(
          prop("stop-color", stopColor),
          " ",
          prop("offset", string.concat(svgUtils.uint2str(offset), "%")),
          " ",
          _props
        )
      );
  }

  function animateTransform(string memory _props) internal pure returns (string memory) {
    return el("animateTransform", _props);
  }

  function image(string memory _href, string memory _props) internal pure returns (string memory) {
    return el("image", string.concat(prop("href", _href), " ", _props));
  }

  function start() internal pure returns (string memory) {
    return
      string.concat(
        '<svg width="320" height="320" style="background:#FFF" ',
        'viewBox="0 0 320 320" ',
        'xmlns="http://www.w3.org/2000/svg" ',
        ">"
      );
  }

  function end() internal pure returns (bytes memory) {
    return ("</svg>");
  }

  /* COMMON */
  // A generic element, can be used to construct any SVG (or HTML) element
  function el(
    string memory _tag,
    string memory _props,
    string memory _children
  ) internal pure returns (string memory) {
    return string.concat("<", _tag, " ", _props, ">", _children, "</", _tag, ">");
  }

  // A generic element, can be used to construct any SVG (or HTML) element without children
  function el(string memory _tag, string memory _props) internal pure returns (string memory) {
    return string.concat("<", _tag, " ", _props, "/>");
  }

  // an SVG attribute
  function prop(string memory _key, string memory _val) internal pure returns (string memory) {
    return string.concat(_key, "=", '"', _val, '" ');
  }

  function stringifyIntSet(
    bytes memory _data,
    uint256 _offset,
    uint256 _len
  ) public pure returns (bytes memory) {
    bytes memory res;
    require(_data.length >= _offset + _len, "Out of range");
    for (uint256 i = _offset; i < _offset + _len; i++) {
      res = abi.encodePacked(res, byte2uint8(_data, i).toString(), " ");
    }
    return res;
  }

  function byte2uint8(bytes memory _data, uint256 _offset) public pure returns (uint8) {
    require(_data.length > _offset, "Out of range");
    return uint8(_data[_offset]);
  }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/utils/Strings.sol";
/**
  * @title  SVG Utilities
  * @author Kames Geraghty
  * @notice The SVG Utilities Library provides functions for constructing SVG; format CSS and numbers.
  * @dev Original code from w1nt3r-eth/hot-chain-svg (https://github.com/w1nt3r-eth/hot-chain-svg)
*/
library svgUtils {
    using Strings for uint256;
    using Strings for uint8;
    
    /// @notice Empty SVG element
    string internal constant NULL = "";

    /**
     * @notice Formats a CSS variable line. Includes a semicolon for formatting.
     * @param _key User for which to calculate prize amount.
     * @param _val User for which to calculate prize amount.
     * @return string Generated CSS variable.
    */
    function setCssVar(string memory _key, string memory _val)
        internal
        pure
        returns (string memory)
    {
        return string.concat("--", _key, ":", _val, ";");
    }

    /**
     * @notice Formats getting a css variable
     * @param _key User for which to calculate prize amount.
     * @return string Generated CSS variable.
    */
    function getCssVar(string memory _key)
        internal
        pure
        returns (string memory)
    {
        return string.concat("var(--", _key, ")");
    }

    // formats getting a def URL
    function getDefURL(string memory _id)
        internal
        pure
        returns (string memory)
    {
        return string.concat("url(#", _id, ")");
    }

    // checks if two strings are equal
    function stringsEqual(string memory _a, string memory _b)
        internal
        pure
        returns (bool)
    {
        return
            keccak256(abi.encodePacked(_a)) == keccak256(abi.encodePacked(_b));
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

    function round2Txt(
        uint256 _value,
        uint8 _decimals,
        uint8 _prec
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            (_value / 10 ** _decimals).toString(), 
            ".",
            ( _value / 10 ** (_decimals - _prec) -
                _value / 10 ** (_decimals ) * 10 ** _prec
            ).toString()
        );
    }

     // converts an unsigned integer to a string
     function uint2str(uint256 _i)
     internal
     pure
     returns (string memory _uintAsString)
 {
     if (_i == 0) {
         return "0";
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

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

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Three-step single owner authorization mixin.
/// @author SolBase (https://github.com/Sol-DAO/solbase/blob/main/src/auth/OwnedThreeStep.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract OwnedThreeStep {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event OwnerUpdateInitiated(address indexed user, address indexed ownerCandidate);

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error Unauthorized();

    /// -----------------------------------------------------------------------
    /// Ownership Storage
    /// -----------------------------------------------------------------------

    address public owner;

    address internal _ownerCandidate;

    bool internal _ownerCandidateConfirmed;

    modifier onlyOwner() virtual {
        if (msg.sender != owner) revert Unauthorized();

        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    /// @notice Create contract and set `owner`.
    /// @param _owner The `owner` of contract.
    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /// -----------------------------------------------------------------------
    /// Ownership Logic
    /// -----------------------------------------------------------------------

    /// @notice Initiate ownership transfer.
    /// @param newOwner The `_ownerCandidate` that will `confirmOwner()`.
    function transferOwnership(address newOwner) public payable virtual onlyOwner {
        _ownerCandidate = newOwner;

        emit OwnerUpdateInitiated(msg.sender, newOwner);
    }

    /// @notice Confirm ownership between `owner` and `_ownerCandidate`.
    function confirmOwner() public payable virtual {
        if (_ownerCandidateConfirmed) {
            if (msg.sender != owner) revert Unauthorized();

            delete _ownerCandidateConfirmed;

            address newOwner = _ownerCandidate;

            owner = newOwner;

            emit OwnershipTransferred(msg.sender, newOwner);
        } else {
            if (msg.sender != _ownerCandidate) revert Unauthorized();

            _ownerCandidateConfirmed = true;
        }
    }

    /// @notice Terminate ownership by `owner`.
    function renounceOwner() public payable virtual onlyOwner {
        delete owner;

        emit OwnershipTransferred(msg.sender, address(0));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { svg } from "@erc721k/periphery-sol/contracts/svg/svg.sol";
import { OwnedThreeStep } from "@turbo-eth/solbase-sol/src/auth/OwnedThreeStep.sol";
import { svgUtils } from "@erc721k/periphery-sol/contracts/svg/svgUtils.sol";
import { SVGLibrary } from "@erc721k/periphery-sol/contracts/svg/SVGLibrary.sol";
import { ISVGModule } from "@erc721k/periphery-sol/contracts/interfaces/ISVGModule.sol";

contract Web3Assets is OwnedThreeStep {
  string private encoding = "(uint8, uint8)";
  mapping(bytes32 => string) private assets;

  /* ===================================================================================== */
  /* Constructor & Modifiers                                                               */
  /* ===================================================================================== */

  constructor(address _owner) OwnedThreeStep(_owner) {}

  /* ===================================================================================== */
  /* External Functions                                                                    */
  /* ===================================================================================== */

  function getEncoding() external view returns (string memory) {
    return encoding;
  }

  function get(bytes32 position) external view returns (string memory) {
    return assets[position];
  }

  function decode(bytes memory input) external view returns (string memory) {
    bytes32 position = abi.decode(input, (bytes32));
    return assets[position];
  }

  function set(bytes32 position, string memory svg) external onlyOwner {
    assets[position] = svg;
  }
}