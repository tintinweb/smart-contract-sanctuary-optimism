// SPDX-License-Identifier: MIT
// Create by 0xChrisx

pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./ERC721A.sol";
import "./Strings.sol";
import "./MerkleProof.sol";
import "./DefaultOperatorFilterer.sol";

contract NFT is Ownable, ERC721A, DefaultOperatorFilterer, ReentrancyGuard {

    event Received(address, uint);

    uint256 public mintPhase ;

    uint256 public mintPrice = 0 ether;

    uint256 public collectionSize_ = 5555 ;
    uint256 public maxWlRound =  5555 ;

    uint256 public maxPerPublic = 5;
    uint256 public maxPerWhitelist = 5;

    uint256 pbseed ;

    bytes32 public WLroot ;

    string private baseURI ;

    constructor() ERC721A("FrenchFries", "FFF", maxPerPublic , collectionSize_ ) {
        
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

    function setMaxPerAddress (uint256 newMaxPerAddress) public onlyOwner {
        maxPerPublic = newMaxPerAddress ;
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

    function setPbseed (uint256 newpbseed) public onlyOwner {
        pbseed = newpbseed ;
    }

//--------------------- END Set & Change anythings
//--------------------------------------- Mint
//-------------------- PublicMint
    function publicMint(uint256 _mintAmount ,uint256 getpbseed) external payable callerIsUser {

        require(mintPhase == 5, "public sale hasn't begun yet");
        require(pbseed == getpbseed, "public sale hasn't begun yet (wrong seed).");
        require(totalSupply() + _mintAmount <= collectionSize_  , "reached max supply"); // must less than collction size
        require(numberMinted(msg.sender) + _mintAmount <= maxPerPublic, "can not mint this many"); // check max mint PerAddress ?
        require(msg.value >= mintPrice * _mintAmount, "ETH amount is not sufficient");

        _safeMint(msg.sender, _mintAmount);
    }

    function numberMinted(address owner) public view returns (uint256) { // check number Minted of that address จำนวนที่มิ้นไปแล้ว ใน address นั้น
        return _numberMinted(owner);
    }
//-------------------- END PublicMint
//-------------------- DevMint
    function devMint(address _to ,uint256 _mintAmount) external onlyOwner {

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
        
        require(numberMinted(msg.sender) + _mintAmount <= maxPerWhitelist, "Max per address for whitelist. Please try lower.");

        require(mintPrice * _mintAmount <= msg.value, "Ether value sent is not correct");

        _safeMint(msg.sender, _mintAmount);

    }

    function isValidWL(bytes32[] memory proof, bytes32 leaf) public view returns (bool) {
        
        return MerkleProof.verify(proof, WLroot, leaf);

    }

//-------------------- END WhitelistMint
//--------------------------------------------- END Mint
//------------------------- Withdraw Money

        address private wallet1 = 0x7884A13d537D281568Ad7e9b9821b745eB8f1EDa; // K.Bass
        address private wallet2 = 0x4B0A54D5529D34352048022a6e67BB6a26d91A7A; // K.Kayy
        address private wallet3 = 0x00778e7EBE6Ca9D082335Fc027d1A4aB3233036c; // K.Chris
        address private wallet4 = 0xc724C3cB9770eCfBb1Dd09751b15842043bc15a5; // K.Yok
        address private wallet5 = 0x5350303b367FeA34bFb85Fd0da683eA9D8Ebd550; // VAULT

    function withdrawMoney() external payable nonReentrant { 

        uint256 _paytoW1 = address(this).balance*20/100 ; // K.Bass
        uint256 _paytoW2 = address(this).balance*20/100 ; // K.Kayy
        uint256 _paytoW3 = address(this).balance*20/100 ; // K.Chris
        uint256 _paytoW4 = address(this).balance*20/100 ; // K.Yok
        uint256 _paytoW5 = address(this).balance*20/100 ; // VAULT

        require(address(this).balance > 0, "No ETH left");

        require(payable(wallet1).send(_paytoW1));
        require(payable(wallet2).send(_paytoW2));
        require(payable(wallet3).send(_paytoW3));
        require(payable(wallet4).send(_paytoW4));
        require(payable(wallet5).send(_paytoW5));

    }
//------------------------- END Withdraw Money

//-------------------- START Fallback Receive Ether Function
    receive() external payable {
            emit Received(msg.sender, msg.value);
    }
//-------------------- END Fallback Receive Ether Function

//-------------------- START DefaultOperaterFilterer
    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId) public override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }
//--------------------- END DefaultOperaterFilterer
}