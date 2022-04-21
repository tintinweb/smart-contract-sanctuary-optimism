/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-21
*/

//define which compiler to use
pragma solidity ^0.8.13;

//contract name is MyFirstContract
contract BetWinner {

//create two variables.  A sting and an integer

    uint private maxBet;

    mapping(uint => address) public bettors;

//set
    function bet(uint betSize) public {
        if ( betSize >= maxBet ) {
            maxBet = betSize;
            bettors[betSize] = msg.sender;
        }
    }

//get
    function getMaxBet () public view returns (uint ) {
        return maxBet;
    }
    
    function getMaxBettor () public view returns (address ) {
        return bettors[maxBet];
    }
     
}