// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract Corgi {
    // keccak256(encodePacked(creator, key)) => sha256(entityJson)
    mapping(bytes32 => bytes32) public entities;

    event EntityCreated(address creator, string key, bytes32 lookupHash, bytes32 jsonHash);

    function getLookupHash(
        address creator, string calldata key
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    creator,
                    key
                )
            );
    }

    function lookupJsonHash(
        address creator, string calldata key
    ) public view returns (bytes32) {
        return entities[getLookupHash(creator, key)];
    }

    function createEntity(string calldata key, bytes32 jsonHash) public returns (bytes32) {
        bytes32 lookupHash = getLookupHash(msg.sender, key);
        if (entities[lookupHash] == 0) {
            entities[lookupHash] = jsonHash;
            emit EntityCreated(msg.sender, key, lookupHash, jsonHash);
        }

        return lookupHash;
    }
}