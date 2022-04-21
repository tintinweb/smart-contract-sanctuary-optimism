/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-21
*/

contract CounterContract {
    address public owner;
    mapping(address => uint256) private _balances;
    uint256 private _totalSupply;

    constructor() {
        owner = msg.sender;
    }

    function setOwner(address newOwner) public {
        require(msg.sender == owner);
        owner = newOwner;
    }

    function addBalance() public {
        _totalSupply += 1;
        _balances[msg.sender] += 1;
    }

    function getBalance() public view returns (uint256) {
        return _balances[msg.sender];
    }
}