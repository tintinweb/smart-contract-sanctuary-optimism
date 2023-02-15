/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-15
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

interface MinimalSafe {
    function getOwners() external view returns (address[] memory);
    function masterCopy() external view returns (address);
    function getThreshold() external view returns (uint);
}


contract SafeChecker {
    address public constant SAFE_IMPL = 0xfb1bffC9d739B8D520DaF37dF666da4C687191EA; // https://github.com/safe-global/safe-deployments/blob/main/src/assets/v1.3.0/gnosis_safe_l2.json
    
    address public constant SAFE_PROXY_KNOWN_ADDR = 0xf9D445a46D65427550174ec2A49FceFA3dae7f8D; // https://optimistic.etherscan.io/address/0xf9d445a46d65427550174ec2a49fcefa3dae7f8d#code
    bytes32 public SAFE_PROXY_HASH;

    constructor() {
        SAFE_PROXY_HASH = SAFE_PROXY_KNOWN_ADDR.codehash;
    }

    function validateSafes(
        MinimalSafe[] memory _safeAddresses,
        address[] memory _intendedSigners,
        uint _intendedThreshold
    ) public view returns(bool) {
        for (uint i = 0; i < _safeAddresses.length; i++) {
            _validateSafe(
                _safeAddresses[i],
                _intendedSigners,
                _intendedThreshold
            );
        }
        return true;
    }

    function _validateSafe(
        MinimalSafe _safeAddress,
        address[] memory _intendedSigners,
        uint _intendedThreshold
    ) internal view {
        require(address(_safeAddress).codehash == SAFE_PROXY_HASH, "wrong proxy code");
        require(_safeAddress.masterCopy() == SAFE_IMPL, "wrong implementation");
        require(_safeAddress.getThreshold() == _intendedThreshold, "wrong threshold");
        address[] memory actualSigners = _safeAddress.getOwners();
        require(actualSigners.length == _intendedSigners.length, "length mismatch");
        for (uint i = 0; i < _intendedSigners.length; i++) {
            address intendedSigner = _intendedSigners[i];
            address actualSigner = actualSigners[i];
            require(intendedSigner == actualSigner, "signer mismatch");
        }
    }
}