/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-26
*/

// My First Smart Contract 
pragma solidity >=0.5.0 <0.7.0;
contract HelloWorld {
    function get()public pure returns (string memory){
        return 'Hello Contracts';
    }
}