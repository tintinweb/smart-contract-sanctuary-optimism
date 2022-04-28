//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOptiPunks {
    function balanceOf(address owner) external view returns (uint256 balance);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);
}

contract TopOptiPunk {
    IOptiPunks public immutable optipunk;

    constructor (IOptiPunks _optipunk) {
        optipunk = _optipunk;
    }

    function getTopOne(address _user)
        public
        view
        returns (uint256 _tokenId, uint256 _class, bool _found)
    {
        uint256 balance = optipunk.balanceOf(_user);
        if (balance == 0) {
            return (0, 0, false);
        } else {
            _tokenId = optipunk.tokenOfOwnerByIndex(_user, 0);
            return (_tokenId, _class, true);
        }
    }
}