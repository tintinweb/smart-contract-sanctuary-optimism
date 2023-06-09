/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-06-09
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

contract BuyMe{
    address  payable contractCreator;
    address public owner;
    uint public contractPrice;


    modifier onlyOwner(){
        require(msg.sender==owner, "not owner");
        _;
    }

    constructor(){
        contractCreator = payable (msg.sender);
        owner = msg.sender;
        contractPrice = 10**10 wei;
    }

    receive()external payable {

        if (msg.value > contractPrice){
           
            address payable _to = payable (owner);
            address _thisContract = address(this);
            _to.transfer(_thisContract.balance);

            owner = msg.sender;

        } else { 

        }
            
    }

    function changePrice (uint _newPrice, uint decimal) public onlyOwner{

        contractPrice = _newPrice * 10**decimal;
    }

    function changeOwner( address _newOwner) public onlyOwner{

        owner = _newOwner;
    }

    function killContract()public onlyOwner{
    
        selfdestruct(contractCreator);
    }

}