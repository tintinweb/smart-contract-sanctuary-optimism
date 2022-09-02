/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-09-02
*/

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

contract MistenPresale {
    mapping(address => bool) public whitelistedAddress;
    mapping(address => uint256) public amountSent;

    uint constant PRESALE_MAX_AMOUNT = 60 ether;
    uint constant WL_MAX_AMOUNT = 0.5 ether;
    uint constant FCFS_MAX_AMOUNT = 0.3 ether;
    uint public presaleAmountCollected = 0;

    bool public isFCFSActivated = false;

    address public owner;
   
    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Restricted to Owner");
        _;
    }

    function setWhitelist(address[] memory _adr) external onlyOwner {
        for (uint i = 0; i < _adr.length; i++) {
            whitelistedAddress[_adr[i]] = true;
        }
    }

    function activateFCFS() external onlyOwner {
        isFCFSActivated = true;
    }

    function participateInPresale() public payable {
        require(presaleAmountCollected + msg.value <= PRESALE_MAX_AMOUNT, "Presale cap reached");
        if (!isFCFSActivated) {
            require(whitelistedAddress[msg.sender], "Sender is not whitelisted");
            require(amountSent[msg.sender] + msg.value <= WL_MAX_AMOUNT, "WL max amount reached");
        } else {
            require(amountSent[msg.sender] + msg.value <= FCFS_MAX_AMOUNT, "FCFS max amount reached");
        }
        amountSent[msg.sender] += msg.value;
        presaleAmountCollected += msg.value;
    }

    function withdraw() public onlyOwner{
        payable(owner).transfer(address(this).balance);
    }
}