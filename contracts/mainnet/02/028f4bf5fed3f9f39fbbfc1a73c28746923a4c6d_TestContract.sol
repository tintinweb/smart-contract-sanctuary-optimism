/**
 *Submitted for verification at optimistic.etherscan.io on 2022-07-12
*/

pragma solidity >=0.7.0 <0.9.0;

// imagine something terrible happens if you don't flip the switch in time

contract TestContract {
    address public owner;
    bool public arbitrary_killswitch;

    constructor() {
        owner = msg.sender;
        arbitrary_killswitch = false;
    }

    modifier onlyOwner {
      require(msg.sender == owner);
      _;
   }
    
    function set(bool _s) public onlyOwner {
        arbitrary_killswitch = _s;
    }
}