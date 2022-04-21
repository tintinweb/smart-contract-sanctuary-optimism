/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-21
*/

//define which compiler to use
pragma solidity ^0.8.13;

//contract name is MyFirstContract
contract MyDBContract {

//create two variables.  A sting and an integer

    string private name;
    uint private age;

    mapping(address => string) public names;

//set
    function setName(string memory newName) public {
        name = newName;
        names[msg.sender] = newName;
    }

//get
    function getName () public view returns (string memory) {
        return name;
    }
    
//set
    function setAge(uint newAge) public {
        age = newAge;
        
    }

//get
    function getAge () public view returns (uint) {
        return age;
    }
    
}