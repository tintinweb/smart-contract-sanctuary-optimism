// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ZeroDekompressorLib } from "./lib/ZeroDekompressorLib.sol";

/// @title CallKompressor
/// @author clabby <https://github.com/clabby>
contract CallKompressor {
    /// @dev When the `CallKompressor` receives a payload, it first decompresses it using
    /// `ZeroDekompressorLib.dekompressCalldata()`. Once the payload is decompressed, the
    /// `to` address as well as the payload are extracted in order to forward the call.
    ///
    /// The decompressed payload is expected to be in the following format:
    /// ╔═════════╤═══════════════════╗
    /// ║ Bytes   │ [0, 20)   [20, n) ║
    /// ╟─────────┼───────────────────╢
    /// ║ Element │ to        payload ║
    /// ╚═════════╧═══════════════════╝
    fallback() external payable {
        // Decompress the payload
        bytes memory decompressed = ZeroDekompressorLib.dekompressCalldata();

        // Extract the `to` address as well as the payload to forward
        assembly ("memory-safe") {
            // Forward the call
            let success :=
                call(
                    gas(), // Forward all gas
                    shr(0x60, mload(add(decompressed, 0x20))), // Extract the address (first 20 bytes)
                    callvalue(), // Forward the call value
                    add(decompressed, 0x34), // Extract the payload (skip the first 20 bytes)
                    sub(mload(decompressed), 0x14), // Extract the payload length (skip the first 20 bytes)
                    0x00, // Don't copy returndata
                    0x00 // Don't copy returndata
                )

            // Copy returndata to memory. It's okay that we clobber the free memory pointer here - it will
            // never be used again in this call context.
            returndatacopy(0x00, 0x00, returndatasize())

            // Bubble up the returndata
            switch success
            case true { return(0x00, returndatasize()) }
            case false { revert(0x00, returndatasize()) }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title ZerkDekompressorLib
/// @author clabby <https://github.com/clabby>
library ZeroDekompressorLib {
    /// @notice Decodes ZeroKompressed calldata into memory.
    /// @return _out The uncompressed calldata in memory.
    function dekompressCalldata() internal pure returns (bytes memory _out) {
        assembly ("memory-safe") {
            // If the input is empty, return an empty output.
            // By default, `_out` is set to the zero offset (0x60), so we only branch once rather than creating a
            // switch statement.
            if calldatasize() {
                // Grab some free memory for the output
                _out := mload(0x40)

                // Store the total length of the output on the stack and increment as we loop through the calldata
                let outLength := 0x00

                // Loop through the calldata
                for {
                    let cdOffset := 0x00
                    let memOffset := add(_out, 0x20)
                } lt(cdOffset, calldatasize()) { } {
                    // Load the current chunk
                    let chunk := calldataload(cdOffset)
                    // Load the first byte of the current chunk
                    let b1 := byte(0x00, chunk)
                    // Load the second byte of the current chunk
                    let b2 := byte(0x01, chunk)

                    // If the second byte is 0x00, we expect it to be RLE encoded. Skip over memory by `b1` bytes.
                    // Otherwise, copy the byte as normal.
                    switch and(iszero(b2), lt(add(cdOffset, 0x01), calldatasize()))
                    case true {
                        // Increment the calldata offset by 2 bytes to account for the RLE prefix and the zero byte.
                        cdOffset := add(cdOffset, 0x02)
                        // Increment the memory offset by `b1` bytes to retain `b1` zero bytes starting at `memOffset`.
                        memOffset := add(memOffset, b1)
                        // Increment the output length by `b1` bytes.
                        outLength := add(outLength, b1)
                    }
                    case false {
                        // Store the non-zero byte in memory at the current `memOffset`
                        mstore8(memOffset, b1)

                        // Increment the calldata offset by 1 byte to account for the non-zero byte.
                        cdOffset := add(cdOffset, 0x01)
                        // Increment the memory offset by 1 byte to account for the non-zero byte we just wrote.
                        memOffset := add(memOffset, 0x01)
                        // Increment the output length by 1 byte.
                        outLength := add(outLength, 0x01)
                    }
                }

                // Set the length of the output to the calculated length
                mstore(_out, outLength)

                // Update the free memory pointer
                mstore(0x40, add(_out, and(add(outLength, 0x3F), not(0x1F))))
            }
        }
    }
}