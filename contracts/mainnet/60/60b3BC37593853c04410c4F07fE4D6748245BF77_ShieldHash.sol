/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-20
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
contract ShieldHash {
    struct data {
        string hashinfo;
        address user;
        uint timestamp;
    }

    mapping(address => data[]) sOwner;

    // Send a hashinfo ( Four-Tier Encrypted Data ) to a owner box 
    // _hashinfo:: Encrypted Data ( Long length data ) 
    // ( Before transaction, Estimated gas fee will be approved by user )
    function setHashinfo(string memory _hashinfo) external {
        
        require(bytes(_hashinfo).length >= 10, "data length is too small.");
       
        data memory message = data(_hashinfo, msg.sender, block.timestamp);
        sOwner[msg.sender].push(message);
    }

    // Currently, there is no support for returning nested lists, so the length
    // of hashinfo needs to be fetched and then retrieved by index. This is not
    // fast but it is the most gas efficient method for storing and
    // fetching data. Ideally this only needs to be done once per owner box load
    function getHashinfoCountForOwner(address _sOwner) external view returns (uint) {
        return sOwner[_sOwner].length;
    }

    // There is no support for returning a struct to web3, so this needs to be
    // returned as multiple items. This will throw an error if the index from 
    // owner box is invalid
    function getHashinfoByIndexForOwner(address _sOwner, uint _index) external view returns (string memory, address, uint) {
        data memory message = sOwner[_sOwner][_index];
        return (message.hashinfo, message.user, message.timestamp);
    }

}