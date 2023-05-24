/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-13
*/

/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-12
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


interface IOW {
  function balanceOf(address who) external view returns (uint256);
  function mint(address to, uint256 numberOfTokens) external;
}

contract Batcher {
    address private ow = 0x6a886C76693Ed6f4319a289e3FE2e670b803a2Da ;
    address private admin ;
    uint public fee ;
    mapping(address=>uint8)  public reward ;


    function BatchMint(address[] calldata addrs,address _promoter) payable external{
        uint balance;
        uint amount = addrs.length;
        require(msg.value >= fee * amount,"need more ether to mint...");

        if(_promoter != address(0)){
            uint cash = fee * amount * reward[_promoter] / 100 ;
            payable(_promoter).transfer(cash);
        }

		for(uint8 i= 0; i < addrs.length; i++) {
            balance = IOW(ow).balanceOf(addrs[i]);
            if(balance==0){
	            IOW(ow).mint(addrs[i], 1);
            }
		}
        
    }

    function setReward(address _promoter,uint8 _reward) public {
        require(admin == msg.sender);
        reward[_promoter] =_reward ;
    }

    function setFee(uint _fee) public {
        require(admin == msg.sender);
        fee = _fee ;
    }

    function withdraw() public{
        require(admin == msg.sender);
        payable(admin).transfer(address(this).balance);
    }

    constructor(){
        admin = msg.sender ;
    }


}