/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-01-12
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// This file is MIT Licensed.
//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() pure internal returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() pure internal returns (G2Point memory) {
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
    }
    /// @return the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) pure internal returns (G1Point memory) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
    }


    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success);
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length);
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[1];
            input[i * 6 + 3] = p2[i].X[0];
            input[i * 6 + 4] = p2[i].Y[1];
            input[i * 6 + 5] = p2[i].Y[0];
        }
        uint[1] memory out;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}

// Groth16 Proof struct
struct Proof {
        Pairing.G1Point a;
        Pairing.G2Point b;
        Pairing.G1Point c;
}

// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

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


// OpenZeppelin Contracts (last updated v4.7.3) (utils/cryptography/ECDSA.sol)


/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}


// This file is MIT Licensed.
//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

contract OnAddLeaf {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alpha;
        Pairing.G2Point beta;
        Pairing.G2Point gamma;
        Pairing.G2Point delta;
        Pairing.G1Point[] gamma_abc;
    }
    function verifyingKey() pure internal returns (VerifyingKey memory vk) {
        vk.alpha = Pairing.G1Point(uint256(0x193e22c4311c3609eb91e7138ac6d29b9dd8bd2f074f6be04fa42c02ca036053), uint256(0x295745b73ac6fc210aa6bc3e0b8d789b6404a259dff1ac60c722848920e5f87f));
        vk.beta = Pairing.G2Point([uint256(0x213d8635a997818eb1c13707bb04ccd95e69ff60c6b9ccaea869cdc71890b6c1), uint256(0x2719f14a0ab6d68f531559d2cd432b2e901c00ff3840764e1c552c773189677b)], [uint256(0x0e14bc64efd9ded08e799a666e1745df6aec82d0761b22777772eb94eb221c9f), uint256(0x03d175bb6309fca6d740df37d61d959922ebdba6877ee305522e81b6d7ae332c)]);
        vk.gamma = Pairing.G2Point([uint256(0x1a06e23ec4935b54c0597f3b467b0a6387a7c3b0601b6e7371438af61f7bc265), uint256(0x1fe80dada06db006ba66ef4db82d3ee74832414d3b53f4626a06f7f8750c15c4)], [uint256(0x08dcab2e5abd9809c60e25037c3b916fe834388bcd5c78e3709e6aeb2e3cc57e), uint256(0x03e1fc33cdcf73fc1d82e36fae31748c781fa4226b30e7601a2bda0e8a56b12a)]);
        vk.delta = Pairing.G2Point([uint256(0x1772a892dc0d131f5d709f8060c57da955692ff581ab41a36a3c0d0daf207a48), uint256(0x16c6fcd0a249a5dab4911e6d2d3f5c95f4a36245a6117120f631ae029c39aeb9)], [uint256(0x0087271d18ff6303d104536f890649b4b420d49c747e192d780c66cd2c964b29), uint256(0x00a890a9980461c6da9125d63bc6b3c996bb6985432fb38dabb7d3ddca844be9)]);
        vk.gamma_abc = new Pairing.G1Point[](4);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x0c985a310d66b2f4f974c21d8e4d2be8df76394ba894c8307c6f01ec5d9f8734), uint256(0x193c8d425f2fb2e4b227368edadb05f282ae2750c60e1a056dc7fdb028088b4f));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x1197eca1c597fd28d76a01664204e6144a92366a06e5642721af18e24ad08e1e), uint256(0x23cc59ae89cb3c9cb359d3e7610912167dd54eba8db12de9161e1198ca298842));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x13cdef780266d604b254108f00b50c19e0293103d68fe04dd5e76e593f1d19bf), uint256(0x0f0089538a39d0f144f4c8ca57c0cc3f63a4174f6f9d17d5b0ee563cf8708e33));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x20b55fc8eb393034d47a78c00f394cf68769592e0b1343d92e5d0c64b9629902), uint256(0x22665571d9d730edcf00aff2ef5e39d90f67497b149e6817dc5e62f23ecd6306));
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.gamma_abc.length);
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field);
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.gamma_abc[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.gamma_abc[0]);
        if(!Pairing.pairingProd4(
             proof.a, proof.b,
             Pairing.negate(vk_x), vk.gamma,
             Pairing.negate(proof.c), vk.delta,
             Pairing.negate(vk.alpha), vk.beta)) return 1;
        return 0;
    }
    function verifyTx(
            Proof memory proof, uint[3] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](3);
        
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

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


interface IVerifier {
   function verifyEncoded(Proof calldata proof, uint[] calldata input_) external view returns (bool);
}

// Adds a verified crendential to the user
contract ProofRouter is Ownable{    
    mapping (string => address) public routes;

    constructor(address admin){
        _transferOwnership(admin);
    }

    function addRoute(string memory name, address destination) public onlyOwner {
        // Check that it is uninitialized (for security so centralized owner cannot overwrite old routes, only add new ones)
        require(routes[name] == address(0x0), "cannot override existing route");
        routes[name] = destination;
    }

    // How to get input struct to encodedInput: abi.encode. Verifier contract can decode it using abi.decode https://medium.com/coinmonks/abi-encode-and-decode-using-solidity-2d372a03e110
    function verifyProof(string calldata name, Proof calldata proof, uint[] calldata input) public view returns (bool) {
        require(routes[name] != address(0x0));
        IVerifier v = IVerifier(routes[name]);
        return v.verifyEncoded(proof, input);
    }    
}

// import "hardhat/console.sol";

library PoseidonT3 {
    function poseidon(uint256[2] memory) public pure returns (uint256) {}
}

library PoseidonT6 {
    function poseidon(uint256[5] memory) public pure returns (uint256) {}
}


// Each incremental tree has certain properties and data that will
// be used to add new leaves.
struct IncrementalTreeData {
    uint256 depth; // Depth of the tree (levels - 1).
    uint256 root; // Root hash of the tree.
    uint256 numberOfLeaves; // Number of leaves of the tree.
    mapping(uint256 => uint256) zeroes; // Zero hashes used for empty nodes (level -> zero hash).
    // The nodes of the subtrees used in the last addition of a leaf (level -> [nodes]).
    mapping(uint256 => uint256[5]) lastSubtrees; // Caching these values is essential to efficient appends.
}

/// @title Incremental quin Merkle tree.
/// @dev The incremental tree allows to calculate the root hash each time a leaf is added, ensuring
/// the integrity of the tree.
library IncrementalQuinTree {
    uint8 internal constant MAX_DEPTH = 32;
    uint256 internal constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    /// @dev Initializes a tree.
    /// @param self: Tree data.
    /// @param depth: Depth of the tree.
    /// @param zero: Zero value to be used.
    function init(
        IncrementalTreeData storage self,
        uint256 depth,
        uint256 zero
    ) public {
        require(zero < SNARK_SCALAR_FIELD, "IncrementalBinaryTree: leaf must be < SNARK_SCALAR_FIELD");
        require(depth > 0 && depth <= MAX_DEPTH, "IncrementalQuinTree: tree depth must be between 1 and 32");

        self.depth = depth;

        for (uint8 i = 0; i < depth; ) {
            self.zeroes[i] = zero;
            uint256[5] memory zeroChildren;

            for (uint8 j = 0; j < 5; ) {
                zeroChildren[j] = zero;
                unchecked {
                    ++j;
                }
            }

            zero = PoseidonT6.poseidon(zeroChildren);

            unchecked {
                ++i;
            }
        }

        self.root = zero;
    }

    /// @dev Inserts a leaf in the tree.
    /// @param self: Tree data.
    /// @param leaf: Leaf to be inserted.
    function insert(IncrementalTreeData storage self, uint256 leaf) public {
        uint256 depth = self.depth;

        require(leaf < SNARK_SCALAR_FIELD, "IncrementalQuinTree: leaf must be < SNARK_SCALAR_FIELD");
        require(self.numberOfLeaves < 5**depth, "IncrementalQuinTree: tree is full");

        uint256 index = self.numberOfLeaves;
        uint256 hash = leaf;

        for (uint8 i = 0; i < depth; ) {
            uint8 position = uint8(index % 5);

            self.lastSubtrees[i][position] = hash;

            if (position == 0) {
                for (uint8 j = 1; j < 5; ) {
                    self.lastSubtrees[i][j] = self.zeroes[i];
                    unchecked {
                        ++j;
                    }
                }
            }

            hash = PoseidonT6.poseidon(self.lastSubtrees[i]);
            index /= 5;

            unchecked {
                ++i;
            }
        }

        self.root = hash;
        self.numberOfLeaves += 1;
    }

    /// @dev Updates a leaf in the tree.
    /// @param self: Tree data.
    /// @param leaf: Leaf to be updated.
    /// @param newLeaf: New leaf.
    /// @param proofSiblings: Array of the sibling nodes of the proof of membership.
    /// @param proofPathIndices: Path of the proof of membership.
    function update(
        IncrementalTreeData storage self,
        uint256 leaf,
        uint256 newLeaf,
        uint256[4][] calldata proofSiblings,
        uint8[] calldata proofPathIndices
    ) public {
        require(
            verify(self, leaf, proofSiblings, proofPathIndices),
            "IncrementalQuinTree: leaf is not part of the tree"
        );

        uint256 depth = self.depth;
        uint256 hash = newLeaf;

        for (uint8 i = 0; i < depth; ) {
            uint256[5] memory nodes;

            for (uint8 j = 0; j < 5; ) {
                if (j < proofPathIndices[i]) {
                    nodes[j] = proofSiblings[i][j];
                } else if (j == proofPathIndices[i]) {
                    nodes[j] = hash;
                } else {
                    nodes[j] = proofSiblings[i][j - 1];
                }
                unchecked {
                    ++j;
                }
            }

            if (nodes[0] == self.lastSubtrees[i][0] || nodes[4] == self.lastSubtrees[i][4]) {
                self.lastSubtrees[i][proofPathIndices[i]] = hash;
            }

            hash = PoseidonT6.poseidon(nodes);

            unchecked {
                ++i;
            }
        }

        self.root = hash;
    }

    /// @dev Removes a leaf from the tree.
    /// @param self: Tree data.
    /// @param leaf: Leaf to be removed.
    /// @param proofSiblings: Array of the sibling nodes of the proof of membership.
    /// @param proofPathIndices: Path of the proof of membership.
    function remove(
        IncrementalTreeData storage self,
        uint256 leaf,
        uint256[4][] calldata proofSiblings,
        uint8[] calldata proofPathIndices
    ) public {
        require(
            verify(self, leaf, proofSiblings, proofPathIndices),
            "IncrementalQuinTree: leaf is not part of the tree"
        );

        uint256 depth = self.depth;
        uint256 hash = self.zeroes[0];

        for (uint8 i = 0; i < depth; ) {
            uint256[5] memory nodes;

            for (uint8 j = 0; j < 5; ) {
                if (j < proofPathIndices[i]) {
                    nodes[j] = proofSiblings[i][j];
                } else if (j == proofPathIndices[i]) {
                    nodes[j] = hash;
                } else {
                    nodes[j] = proofSiblings[i][j - 1];
                }
                unchecked {
                    ++j;
                }
            }

            if (nodes[0] == self.lastSubtrees[i][0] || nodes[4] == self.lastSubtrees[i][4]) {
                self.lastSubtrees[i][proofPathIndices[i]] = hash;
            }

            hash = PoseidonT6.poseidon(nodes);

            unchecked {
                ++i;
            }
        }

        self.root = hash;
    }

    /// @dev Verify if the path is correct and the leaf is part of the tree.
    /// @param self: Tree data.
    /// @param leaf: Leaf to be removed.
    /// @param proofSiblings: Array of the sibling nodes of the proof of membership.
    /// @param proofPathIndices: Path of the proof of membership.
    /// @return True or false.
    function verify(
        IncrementalTreeData storage self,
        uint256 leaf,
        uint256[4][] calldata proofSiblings,
        uint8[] calldata proofPathIndices
    ) private view returns (bool) {
        require(leaf < SNARK_SCALAR_FIELD, "IncrementalQuinTree: leaf must be < SNARK_SCALAR_FIELD");
        uint256 depth = self.depth;
        require(
            proofPathIndices.length == depth && proofSiblings.length == depth,
            "IncrementalQuinTree: length of path is not correct"
        );

        uint256 hash = leaf;

        for (uint8 i = 0; i < depth; ) {
            uint256[5] memory nodes;

            for (uint8 j = 0; j < 5; ) {
                if (j < proofPathIndices[i]) {
                    require(
                        proofSiblings[i][j] < SNARK_SCALAR_FIELD,
                        "IncrementalQuinTree: sibling node must be < SNARK_SCALAR_FIELD"
                    );

                    nodes[j] = proofSiblings[i][j];
                } else if (j == proofPathIndices[i]) {
                    nodes[j] = hash;
                } else {
                    require(
                        proofSiblings[i][j - 1] < SNARK_SCALAR_FIELD,
                        "IncrementalQuinTree: sibling node must be < SNARK_SCALAR_FIELD"
                    );

                    nodes[j] = proofSiblings[i][j - 1];
                }

                unchecked {
                    ++j;
                }
            }

            hash = PoseidonT6.poseidon(nodes);

            unchecked {
                ++i;
            }
        }

        return hash == self.root;
    }
}


contract MerkleTree is Ownable {
    using IncrementalQuinTree for IncrementalTreeData;
    uint8 public constant DEPTH = 14;
    uint8 public constant ROOT_HISTORY_SIZE = 10;
    uint256[ROOT_HISTORY_SIZE] public recentRootsList;
    mapping(uint256 => bool) public recentRootsMap;

    event LeafInserted(uint256 leaf, uint256 root);


    IncrementalTreeData public tree;

    uint256 public root;
    uint256[] public leaves;
    mapping (uint256 => bool) public leafExists;
    
    address public hubAddress;

    uint256[] internal emptyArray;

    /// @param _hubAddress Address of the Hub contract
    constructor(address _hubAddress) {
        // console.log("WARNING: INCRASE ROOT_HISTORY_SIZE TO AT LEAST 30 BEFORE PRODUCTION, AND REMOVE HARDHAT/CONSOLE.SOL");

        // Create tree with depth DEPTH and use 0 as the value for null leaves
        tree.init(DEPTH, 0);
        
        hubAddress = _hubAddress;
    }

    modifier onlyHub() {
        require(msg.sender == hubAddress, "Only the Hub contract can call this function.");
        _;
    }

    function setHubAddress(address newHubAddress) public onlyOwner {
        hubAddress = newHubAddress;
    }

    /// @dev Only the Hub contract should be able to call this function because
    ///      the leaf should be validated before being inserted.
    function insertLeaf(uint256 _leaf) public onlyHub {
        // Insert the leaf
        tree.insert(_leaf);
        leaves.push(_leaf);
        leafExists[_leaf] = true;
        // Replace an element of recentRootsList to make room for new root:
        uint256 insertAt = (tree.numberOfLeaves-1) % ROOT_HISTORY_SIZE; //number of leaves is a the same as number of roots ever made
        recentRootsMap[recentRootsList[insertAt]] = false;
        recentRootsMap[tree.root] = true;
        recentRootsList[insertAt] = tree.root;

        emit LeafInserted(_leaf, tree.root);
    }

    function mostRecentRoot() public view returns (uint256) {
        return tree.root;
    }
    function rootIsRecent(uint256 r) public view returns (bool) {
        return recentRootsMap[r];
    }
    function getLeaves() public view returns(uint256[] memory) {
        return leaves;
    }
    // Returns all new leaves, starting at idx (this is called off-chain to update a local state cache with new leaves)
    function getLeavesFrom(uint idx) public view returns(uint256[] memory) {
        if(leaves.length <= idx) { return emptyArray; }
        uint256[] memory leavesFrom = new uint256[](leaves.length - idx);
        uint256 j = 0;
        for(uint i=idx; i<leaves.length; i++) {
            leavesFrom[j] = leaves[i];
            j++;
        }
        return leavesFrom;
    }
}


// Adds a verified crendential to the user
contract Hub {    
    using ECDSA for bytes32;
    mapping (uint256 => bool) public oldLeafUsed;
    OnAddLeaf oal;

    ProofRouter public router;
    MerkleTree public mt;

    constructor(address routerAdmin_){
        router = new ProofRouter(routerAdmin_);
        oal = new OnAddLeaf(); 
        mt = new MerkleTree(address(this));
    }

    // Copied and slightly modified from from https://blog.ricmoo.com/verifying-messages-in-solidity-50a94f82b2ca
    function isFromIssuer(bytes memory message, uint8 v, bytes32 r, bytes32 s, address issuer) public pure returns (bool fromIssuer) {
        // The message header; we will fill in the length next
        bytes memory header = bytes("\x19Ethereum Signed Message:\n000000");
        uint256 lengthOffset;
        uint256 length;
        assembly {
        // The first word of a string is its length
        length := mload(message)
        // The beginning of the base-10 message length in the prefix
        lengthOffset := add(header, 57)
        }
        // Maximum length we support
        require(length <= 999999);
        // The length of the message's length in base-10
        uint256 lengthLength = 0;
        // The divisor to get the next left-most message length digit
        uint256 divisor = 100000;
        // Move one digit of the message length to the right at a time
        while (divisor != 0) {
        // The place value at the divisor
        uint256 digit = length / divisor;
        if (digit == 0) {
            // Skip leading zeros
            if (lengthLength == 0) {
            divisor /= 10;
            continue;
            }
        }
        // Found a non-zero digit or non-leading zero digit
        lengthLength++;
        // Remove this digit from the message length's current value
        length -= digit * divisor;
        // Shift our base-10 divisor over
        divisor /= 10;
        
        // Convert the digit to its ASCII representation (man ascii)
        digit += 0x30;
        // Move to the next character and write the digit
        lengthOffset++;
        assembly {
            mstore8(lengthOffset, digit)
        }
        }
        // The null string requires exactly 1 zero (unskip 1 leading 0)
        if (lengthLength == 0) {
        lengthLength = 1 + 0x19 + 1;
        } else {
        lengthLength += 1 + 0x19;
        }
        // Truncate the tailing zeros from the header
        assembly {
        mstore(header, lengthLength)
        }
        // Perform the elliptic curve recover operation
        bytes32 check = keccak256(bytes.concat(header, message));
        return ecrecover(check, v, r, s) == issuer;

    }

    function uncheckedUIntToAddress(uint256 u_) private pure returns (address addr) {
        assembly {
            addr := u_
        } 
    }

    // Blindly adds a leaf (should be private)
    function _addLeaf(uint256 leaf) private {
        mt.insertLeaf(leaf);
    }
    
    
    function addLeaf(address issuer, uint8 v, bytes32 r, bytes32 s, Proof memory proof, uint[3] memory input) public {
        address addr = uncheckedUIntToAddress(input[2]);
        uint256 newLeaf = input[1];
        uint256 oldLeaf = input[0];
        require(addr == issuer, "credentials must be proven to start with the issuer's address");
        require(isFromIssuer(abi.encodePacked(oldLeaf), v,r,s, issuer), "leaf must be signed by the issuer"); 
        require(oal.verifyTx(proof, input), "zkSNARK failed");

        require(!oldLeafUsed[oldLeaf], "cannot create more than one new leaf from a signed leaf");
        oldLeafUsed[oldLeaf] = true;   

        _addLeaf(newLeaf);        
    }

    // Encode input using abi.encode to convert fixed-length uint[n] array to bytes
    function verifyProof(string calldata proofType, Proof calldata proof, uint[] calldata input) public view returns (bool) {
        require(mt.rootIsRecent(input[0]), "First public argument of proof must be a recent Merkle Root");
        return router.verifyProof(proofType, proof, input);
    }

    function mostRecentRoot() public view returns (uint256) {
        return mt.mostRecentRoot();
    }

    function getLeaves() public view returns (uint256[] memory) {
        return mt.getLeaves();
    }

    function getLeavesFrom(uint idx) public view returns(uint256[] memory) {
        return mt.getLeavesFrom(idx);
    }
}



contract IsUSResident {
    
    mapping(address => bool) public usResidency; // e.g., 0x123... => true
    mapping(uint256 => bool) public masalaWasUsed;

    Hub hub;
    uint authorityAddress; // Stored as uint instead of address for easy comparison to proof input uints
    event USResidency(address userAddr, bool usResidency);

    constructor(address hub_, address authorityAddress_) {
        hub = Hub(hub_);
        authorityAddress = uint256(uint160(authorityAddress_));
    }


    // It is useful to separate this from the prove() function which is changes state, so that somebody can call this off-chain as a view function.
    // Then, they can maintain their own off-chain list of footprints and verified address 
    function proofIsValid(Proof calldata proof, uint[] calldata input) public view returns (bool isValid) {
        // Checking msg.sender no longer seems very necessary and prevents signature-free interactions. Without it, relayers can submit cross-chain transactions without the user signature. Thus, we are deprecating this check:
        // require(uint256(uint160(msg.sender)) == input[1], "Second public argument of proof must be your address");

        require(input[2] == authorityAddress, "Proof must come from authority address"); // This is integer representation of the address 0xc88... 
        require(input[3] == 18450029681611047275023442534946896643130395402313725026917000686233641593164, "Footprint is made from the wrong salt"); //poseidon("IsFromUS")
        require(!masalaWasUsed[input[4]], "One person can only verify once");
        require(input[5] == 2, "Credentials do not have US as country code"); // 2 is prime that represents USA because USA is #2
        require(hub.verifyProof("USResident", proof, input), "Failed to verify proof");
        return true;
    }

    /// @param proof PairingAndProof.sol Proof struct
    /// @param input The public inputs to the proof, in ZoKrates' format
    function prove(Proof calldata proof, uint[] calldata input) public {
        require(proofIsValid(proof, input));
        masalaWasUsed[input[4]] = true;
        usResidency[address(uint160(input[1]))] = true; //
        emit USResidency(msg.sender, true);
    }

}