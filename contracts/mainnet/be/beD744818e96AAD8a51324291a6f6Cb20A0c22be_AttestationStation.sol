// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title Semver
 * @notice Semver is a simple contract for managing contract versions.
 */
contract Semver {
    /**
     * @notice Contract version number (major).
     */
    uint256 private immutable MAJOR_VERSION;

    /**
     * @notice Contract version number (minor).
     */
    uint256 private immutable MINOR_VERSION;

    /**
     * @notice Contract version number (patch).
     */
    uint256 private immutable PATCH_VERSION;

    /**
     * @param _major Version number (major).
     * @param _minor Version number (minor).
     * @param _patch Version number (patch).
     */
    constructor(
        uint256 _major,
        uint256 _minor,
        uint256 _patch
    ) {
        MAJOR_VERSION = _major;
        MINOR_VERSION = _minor;
        PATCH_VERSION = _patch;
    }

    /**
     * @notice Returns the full semver contract version.
     *
     * @return Semver contract version as a string.
     */
    function version() public view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    Strings.toString(MAJOR_VERSION),
                    ".",
                    Strings.toString(MINOR_VERSION),
                    ".",
                    Strings.toString(PATCH_VERSION)
                )
            );
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
pragma solidity 0.8.15;

import { Semver } from "@eth-optimism/contracts-bedrock/contracts/universal/Semver.sol";

/**
 * @title AttestationStation
 * @author Optimism Collective
 * @author Gitcoin
 * @notice Where attestations live.
 */
contract AttestationStation is Semver {
    /**
     * @notice Struct representing data that is being attested.
     *
     * @custom:field about Address for which the attestation is about.
     * @custom:field key   A bytes32 key for the attestation.
     * @custom:field val   The attestation as arbitrary bytes.
     */
    struct AttestationData {
        address about;
        bytes32 key;
        bytes val;
    }

    /**
     * @notice Maps addresses to attestations. Creator => About => Key => Value.
     */
    mapping(address => mapping(address => mapping(bytes32 => bytes))) public attestations;

    /**
     * @notice Emitted when Attestation is created.
     *
     * @param creator Address that made the attestation.
     * @param about   Address attestation is about.
     * @param key     Key of the attestation.
     * @param val     Value of the attestation.
     */
    event AttestationCreated(
        address indexed creator,
        address indexed about,
        bytes32 indexed key,
        bytes val
    );

    /**
     * @custom:semver 1.1.0
     */
    constructor() Semver(1, 1, 0) {}

    /**
     * @notice Allows anyone to create an attestation.
     *
     * @param _about Address that the attestation is about.
     * @param _key   A key used to namespace the attestation.
     * @param _val   An arbitrary value stored as part of the attestation.
     */
    function attest(
        address _about,
        bytes32 _key,
        bytes memory _val
    ) public {
        attestations[msg.sender][_about][_key] = _val;

        emit AttestationCreated(msg.sender, _about, _key, _val);
    }

    /**
     * @notice Allows anyone to create attestations.
     *
     * @param _attestations An array of attestation data.
     */
    function attest(AttestationData[] calldata _attestations) external {
        uint256 length = _attestations.length;
        for (uint256 i = 0; i < length; ) {
            AttestationData memory attestation = _attestations[i];

            attest(attestation.about, attestation.key, attestation.val);

            unchecked {
                ++i;
            }
        }
    }
}