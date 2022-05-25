/**
 *Submitted for verification at optimistic.etherscan.io on 2022-05-25
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

contract HitAndRun {

    event NewCreature(uint CreatureId, string name, uint dna);

    uint dnaDigits = 16;
    uint dnaModulus = 10 ** dnaDigits;

    struct Creature {
        string name;
        uint dna;
    }

    Creature[] public Creatures;

    mapping (uint => address) public zombieToOwner;
    mapping (address => uint) ownerZombieCount;



    function _generateDna(string memory _str) private view returns (uint) {
        uint rand = uint(keccak256(abi.encodePacked(_str)));
        return rand % dnaModulus;
    }

}