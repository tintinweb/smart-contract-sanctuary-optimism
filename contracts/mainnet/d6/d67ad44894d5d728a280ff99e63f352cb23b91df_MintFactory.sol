/**
 *Submitted for verification at optimistic.etherscan.io on 2022-06-07
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INFTTest{
    
   function totalSupply () external view returns(uint256);
   
  function mintToken( uint256 num) external;
 
function safeTransferFrom(address from, address to,uint256 tokenId) external;
}

contract NFTMint {

    constructor(address _erc721, address  _owner,uint256 id)  {
 //  uint256 id1 = INFTTest(_erc721).totalSupply()+1;

INFTTest(_erc721).mintToken(1);
   
        INFTTest(_erc721).safeTransferFrom(address(this), _owner, id);
          
        selfdestruct(payable(_owner));
    }
}

contract MintFactory{
    address public owner;

    constructor(){
        //owner = msg.sender;
    }

 
    function deploy(address _erc721, uint _count,uint256 id) public {
        owner = msg.sender;
        for(uint i; i < _count; i++){
            new NFTMint(_erc721, owner,i+id);
        }
    }
}