/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-01-03
*/

// SPDX-License-Identifier: MIT

//
//  8888888888P                                          .d8888b.                888 d8b                  
//        d88P                                          d88P  Y88b               888 Y8P                  
//       d88P                                           888    888               888                      
//      d88P    .d88b.  88888b.   .d88b.  .d8888b       888         .d88b.   .d88888 888  .d8888b .d88b.  
//     d88P    d8P  Y8b 888 "88b d88""88b 88K           888        d88""88b d88" 888 888 d88P"   d8P  Y8b 
//    d88P     88888888 888  888 888  888 "Y8888b.      888    888 888  888 888  888 888 888     88888888 
//   d88P      Y8b.     888  888 Y88..88P      X88      Y88b  d88P Y88..88P Y88b 888 888 Y88b.   Y8b.     
//  d8888888888 "Y8888  888  888  "Y88P"   88888P'       "Y8888P"   "Y88P"   "Y88888 888  "Y8888P "Y8888  
//
// * a dAgora contract by Zeno of Citium 
// * https://decentragora.xyz


// * Forked from Cookbook.dev — based on a contract by BraverElliot.eth *
// * Find the base of this contract on Cookbook: https://www.cookbook.dev/contracts/Information-Storage?utm=code *


pragma solidity ^0.8.7;

contract zenoCodices{

    address public owner;
    uint256 private counter;

    constructor()   {
        counter = 0;
        owner = msg.sender;
    }
    struct papyrus    {
        address scribe;
        uint256 id;
        string Fielda;
        string Fieldb;
        string Fieldc;
    }

    event papyrusCreated   (
        address scribe,
        uint256 id,
        string Fielda,
        string Fieldb,
        string Fieldc
    );

    mapping(uint256 => papyrus) Scribes;  


    function addScribe(

        string memory Fielda,
        string memory Fieldb,
        string memory Fieldc
    ) public payable {
        require(msg.value ==  10000000000 wei, "Please submit 0.00000001 Eth"); // submit 0.00000001 to keep the codice alive
        papyrus storage newPapyrus = Scribes[counter];
        newPapyrus.Fielda = Fielda;
        newPapyrus.Fieldb = Fieldb;
        newPapyrus.scribe = msg.sender;
        newPapyrus.id = counter;


        emit papyrusCreated(
                msg.sender,
                counter,
                Fielda,
                Fieldb,
                Fieldc
            );

        counter++;

        payable(owner).transfer(msg.value);


    }

    function getInfo(uint256 id) public view returns(
            string memory,
            string memory,
            string memory,
            address
        ){
            require(id<counter, "No such Post");
            papyrus storage t = Scribes[id];
            return(t.Fielda,t.Fieldb,t.Fieldc,t.scribe);
        }


}