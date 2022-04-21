/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-21
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

//import "hardhat/console.sol";

/**
 * @title Owner
 * @dev Set & change owner
 */
contract OptimismAddChecker {

    address private owner;

    mapping(address => bool) public listAddress;

    modifier isOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function setAddress() public {
        listAddress[msg.sender] = true;
    }

    function checkAddress() public view returns (bool) {
        return listAddress[msg.sender];
    }

}