/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-23
*/

pragma solidity ^0.4.26;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, reverts on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b);

    return c;
  }

  /**
  * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  /**
  * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    uint256 c = a - b;

    return c;
  }

  /**
  * @dev Adds two numbers, reverts on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);

    return c;
  }

  /**
  * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
  * reverts when dividing by zero.
  */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}

// IoT base
contract billing {
    
    using SafeMath for uint256;
    
    address public buyer;              // buyer address
    address public seller;             // seller address


    struct Item {
        string name;                    // item name
        uint cost;                      // item cost
        address paidBy;                 // address buyer
    }
    
    mapping (address => Item) items;
    
    modifier onlySeller(){
        require (msg.sender == seller);
        _;
    }
    
    // add Item to billing contract
    function addItem(address itemControllerAddress, string itemName, uint itemCost) public  onlySeller {
        items[itemControllerAddress].name = itemName;
        items[itemControllerAddress].cost = itemCost;
    }

    // purchase
    function purchase(address itemControllerAddress) public  payable {
        require (items[itemControllerAddress].cost == msg.value );
        items[itemControllerAddress].paidBy = msg.sender;
        seller.transfer(msg.value);
    }
    
    // purchase check
    function checkPurchase(address itemControllerAddress ) public  onlySeller returns (bool) {
        if (items[itemControllerAddress].paidBy!=0) return true; else return false;
    }
    
}