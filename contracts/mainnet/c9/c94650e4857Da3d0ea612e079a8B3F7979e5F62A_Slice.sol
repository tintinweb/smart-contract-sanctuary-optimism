// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Slice {
    mapping(address => address) eoaToSafe;

    event SafeSet(address safe, address signer);

    function setSafe(address safe, address signer) public {
        eoaToSafe[signer] = safe;
        emit SafeSet(safe, signer);
    }

    function getSafe(address signer) public view returns (address) {
        return eoaToSafe[signer];
    }
}