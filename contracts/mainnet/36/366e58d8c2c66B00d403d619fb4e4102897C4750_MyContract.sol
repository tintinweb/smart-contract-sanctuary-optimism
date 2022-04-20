/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-20
*/

contract MyContract {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function setOwner(address newOwner) public {
        require(msg.sender == owner);
        owner = newOwner;
    }
}