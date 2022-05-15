/**
 *Submitted for verification at optimistic.etherscan.io on 2022-05-14
*/

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract Sonotoki {
    struct Proof {
        address owner;
        uint blockNumber;
    }

    //mapping of the SHA-3 hash of the file to a proof struct
    mapping (bytes32 => Proof) public proofs;

    event StoreProof(address indexed _owner, bytes32 indexed _proofHash);
    event DeleteProof(address indexed _owner, bytes32 indexed _proofHash);

    constructor() {
    }

    function storeProof(bytes32 _proofHash) public {
        require(proofs[_proofHash].blockNumber == 0, "Can't overwrite an existing proof");
        Proof memory proof = Proof(msg.sender, block.number);
        proofs[_proofHash] = proof;
        emit StoreProof(msg.sender, _proofHash);
    }

    function deleteProof(bytes32 _proofHash) public {
        require(proofs[_proofHash].owner == msg.sender, "Only the owner can delete a proof");
        delete proofs[_proofHash];
        emit DeleteProof(msg.sender, _proofHash);
    }
}