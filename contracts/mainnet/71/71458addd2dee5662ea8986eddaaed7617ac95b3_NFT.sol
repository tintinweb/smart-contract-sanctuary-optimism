// SPDX-License-Identifier: MIT
// Create by 0xChrisx

pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./ERC721A.sol";
import "./MerkleProof.sol";
import "./ERC721AQueryable.sol";

contract NFT is Ownable, ERC721A, ERC721AQueryable, ReentrancyGuard {

    event Received(address, uint);

    uint256 public mintPhase ;

    uint256 public mintPrice = 0.0149 ether;

    uint256 public collectionSize_ = 222 ;
    uint256 public maxWlRound =  212 ;

    uint256 public maxPerWhitelist = 3 ;
    uint256 public maxPerPublic = 5 ;

    bytes32 public WLroot ;

    string private baseURI ;

    struct AddressDetail {
        uint256 WLBalance ;
        uint256 PBBalance ;
    }

    mapping(address => AddressDetail) public _addressDetail ;

    constructor() ERC721A("BlueBox Assassin", "BBA") {
    }


    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

//------------------ BaseURI 
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI (string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

//--------------------- END BaseURI
//--------------------- Set & Change anythings

    function setMintPrice (uint256 newPrice) public onlyOwner {
        mintPrice = newPrice ;
    }
    
    function setCollectionSize (uint256 newCollectionSize) public onlyOwner {
        collectionSize_ = newCollectionSize ;
    }

    function setMaxWlRound (uint256 newMaxWlRound) public onlyOwner {
        maxWlRound = newMaxWlRound ;
    }

    function setMaxPerPublic (uint256 newMaxPerPublic) public onlyOwner {
        maxPerPublic = newMaxPerPublic ;
    }

    function setMaxPerWhitelist (uint256 newMaxPerWhitelist ) public onlyOwner {
        maxPerWhitelist = newMaxPerWhitelist;
    }

    function setWLRoot (bytes32 newWLRoot) public onlyOwner {
        WLroot = newWLRoot ;
    }

    function setPhase (uint256 newPhase) public onlyOwner {
        mintPhase = newPhase ;
    }

//--------------------- END Set & Change anythings
//--------------------------------------- Mint
//-------------------- DevMint
    function mintDev(address _to ,uint256 _mintAmount) external onlyOwner {

        require(totalSupply() + _mintAmount <= collectionSize_ , "You can't mint more than collection size");

        _safeMint( _to,_mintAmount);
    }
//-------------------- END DevMint
//-------------------- WhitelistMint
    function mintWhiteList(uint256 _mintAmount , bytes32[] memory _Proof) external payable {
        
        require(mintPhase == 1, "Whitelist round hasn't open yet");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(_Proof, WLroot, leaf),
            "You're not whitelist."
        );

        require(totalSupply() + _mintAmount <= maxWlRound , "Purchase would exceed max tokens");
        require(_addressDetail[msg.sender].WLBalance + _mintAmount <= maxPerWhitelist, "Reached max per address for whitelist, Please try lower.");
        require(mintPrice * _mintAmount <= msg.value, "Ether value sent is not correct");

        _safeMint(msg.sender, _mintAmount);
        _addressDetail[msg.sender].WLBalance += _mintAmount ;

    }

//-------------------- END WhitelistMint
//-------------------- PublicMint
    function mintPublic(uint256 _mintAmount) external payable callerIsUser {

        require(mintPhase == 5, "public sale hasn't begun yet");
        require(totalSupply() + _mintAmount <= collectionSize_  , "reached max supply"); // must less than collction size
        require(_addressDetail[msg.sender].PBBalance + _mintAmount <= maxPerPublic, "Reached max per public round, Please try lower."); // check max mint PerAddress ?
        require(msg.value >= mintPrice * _mintAmount, "ETH amount is not sufficient");

        _safeMint(msg.sender, _mintAmount);
        _addressDetail[msg.sender].PBBalance += _mintAmount ;
    }

    function numberMinted(address owner) public view returns (uint256) { // check number Minted of that address จำนวนที่มิ้นไปแล้ว ใน address นั้น
        return _numberMinted(owner);
    }
//-------------------- END PublicMint
//--------------------------------------------- END Mint
//------------------------- Withdraw Money

        address private wallet1 = 0x009ED1DFB92a970eC3476b4Ca887011EDf1BCF4F;

    function withdrawMoney() external payable nonReentrant { 

        uint256 _paytoW1 = address(this).balance ;
    
        require(address(this).balance > 0, "No ETH left");

        require(payable(wallet1).send(_paytoW1));

    }

//------------------------- END Withdraw Money

//-------------------- START Fallback Receive Ether Function
    receive() external payable {
            emit Received(msg.sender, msg.value);
    }
//-------------------- END Fallback Receive Ether Function
}