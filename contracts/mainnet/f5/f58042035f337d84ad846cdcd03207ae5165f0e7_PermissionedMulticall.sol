/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-21
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PermissionedMulticall {
    address public owner;
    address public nominatedOwner;

    constructor() {
        owner = msg.sender;
        nominatedOwner = address(0);
    }

    function batchCall(address[] memory targets, bytes[] memory data) external onlyOwner returns (bytes[] memory results) {
        results = new bytes[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, bytes memory result) = targets[i].call(data[i]);
            if (!success) {
                results[i] = abi.encodePacked("Call failed: ", string(result));
            } else {
                results[i] = result;
            }
        }
    }

    function nominateNewOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        nominatedOwner = newOwner;
        emit OwnerNominated(newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == nominatedOwner, "You are not nominated");
        owner = nominatedOwner;
        nominatedOwner = address(0);
        emit OwnerChanged(owner);
    }

    event OwnerNominated(address newOwner);
    event OwnerChanged(address newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
}