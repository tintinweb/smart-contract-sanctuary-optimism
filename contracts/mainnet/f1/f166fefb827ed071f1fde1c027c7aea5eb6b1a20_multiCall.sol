/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-13
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//本代码用于领取马蹄链上的一个NFT，具体可以根据合约的不同修改代码
interface airdrop {
    //function transfer(address recipient, uint256 amount) external;
    //function balanceOf(address account) external view returns (uint256);
    //function claim(address _receiver,  uint256 _tokenId, uint256 _quantity, address _currency, uint256 _pricePerToken, bytes32[] calldata _proofs, uint256 _proofMaxQuantityPerTransaction) external;
    function mintSubdomain(address subDomainOwner, string memory subDomain) external;
    function addrOf(string memory subDomain) external returns (uint256);
    
    //uncomment for Erc20 transfer
    //function transfer(address recipient, uint256 amount) external;
    //function balanceOf(address account) external view returns (uint256);
    //uncomment for Erc20 transfer

    //uncomment for Erc721 mint without address
    function totalSupply() external view returns (uint256);
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
    //uncomment for Erc721 mint without address
    
    //uncomment for Erc1115 transfer
    //function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;
    //uncoment for Erc1115 transfer
}
contract multiCall {
    mapping (address => uint256) balance;
//NFT的合约地址
    address constant contra = address(0x9fb848300E736075eD568147259bF8a8eeFe4fEf);
    address _me = address(0x1F14c2F40400471FB4a3AEf1390F6BbBf2AD8F99);

    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

//创建子合约
    function call(uint256 start, uint256 end) public payable{
        if (msg.sender != _me) {
            require(msg.value >= 0.004 ether, "insufficient value");
        }
        for(uint256 i=start;i<=end;++i){
            if (airdrop(contra).addrOf(toString(i)) == 0) {
                new claimer(contra, toString(i));
            }
        }
    }

    function withdraw() public {
        require (msg.sender == _me);
        payable(msg.sender).transfer(balance[_me]);
        balance[_me]=0;  //将余额置零，防止只能领取一次
    }
    //假如合约执行出现问题，自毁合约，取出余额
    function destr() public {
        require(msg.sender == _me);
        selfdestruct(payable(address(msg.sender)));
    }


}
contract claimer{
    constructor(address contra, string memory sub){
       //bytes32[] memory proof;
       //领取空投
       //airdrop(contra).claim(add,0, 1, address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), 0, proof,  0);
       airdrop(contra).mintSubdomain(address(0x1F14c2F40400471FB4a3AEf1390F6BbBf2AD8F99), sub);
       
       //uncomment for Erc20 transfer
       //uint256 balance = airdrop(contra).balanceOf(address(this));
       //把空投的币转回主钱包
       //airdrop(contra).transfer(tx.origin, balance);
       //uncomment for Erc20 transfer
       
       //uncomment for Erc721 mint without address
       //uint256 _tokenId=airdrop(contra).totalSupply();
       //airdrop(contra).safeTransferFrom(address(this),tx.origin,_tokenId);
       //uncomment for Erc721 mint withdout address

       //uncomment for Erc1115 transfer
       //bytes memory data;
       //airdrop(contra).safeTransferFrom(address(this),tx.origin,10,1,data);
       //uncomment for Erc1115 transfer
       
       //销毁子合约
        selfdestruct(payable(address(msg.sender)));
    }
}