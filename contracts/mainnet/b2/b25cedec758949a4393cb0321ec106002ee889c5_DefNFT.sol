// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./ERC721A.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./MerkleProof.sol";

contract DefNFT is Ownable, ERC721A, ReentrancyGuard {
    using Strings for uint256;

    string baseURI;
    string public baseExtension = ".json";
    uint256 public whiteListCost = 0; // 0 eth
    uint256 public publicCost = 5000000000000000; // 0.005 eth
    uint256 public maxSupply = 1000; //setter to be change
    uint256 public maxMintAmount = 10; //max mint amount
    bool public paused = true;
    bool public revealed = false;
    string public notRevealedUri;

    mapping(address => bool) public AddressMinted;

    bytes32 public merkleRoot =
        0x37f8aa45011c9bf1f09feb528b9df9c19875df288057d05e476e51406d8b2dac; //will be change as we change whitelist

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        string memory _initNotRevealedUri
    ) ERC721A(_name, _symbol) {
        setBaseURI(_initBaseURI);
        setNotRevealedURI(_initNotRevealedUri);
    }

    // whiteList Mint function
    function whiteListMint(bytes32[] calldata _merkleProof) public payable {
        uint256 supply = totalSupply();
        require(!paused);
        require(supply + 1 <= maxSupply);
        require(msg.value >= whiteListCost);
        require(!AddressMinted[msg.sender], "Already minted Once");

        //verify the provided _merkleProof given to us through the API call on our website
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "Invalid Proof!!"
        );
        _safeMint(msg.sender, 1);
        AddressMinted[msg.sender] = true;
    }

    // Public mint at a price
    function publicMint(uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();
        require(!paused);
        require(_mintAmount > 0, "Quantity cannot be zero");
        require(_mintAmount <= maxMintAmount);
        require(supply + _mintAmount <= maxSupply);
        require(msg.value >= publicCost * _mintAmount);

        _safeMint(msg.sender, _mintAmount);
    }

    // Minting for ownerOnly
    function reserveMint(uint256 _mintAmount) public payable onlyOwner {
        uint256 supply = totalSupply();
        require(_mintAmount > 0);
        require(supply + _mintAmount <= maxSupply);
        _safeMint(msg.sender, _mintAmount);
    }

    // airdropping to array of address
    function sendGifts(address[] memory _wallets) public onlyOwner {
        uint256 supply = totalSupply();
        require(
            supply + _wallets.length <= maxSupply,
            "not enough tokens left"
        );
        for (uint256 i = 0; i < _wallets.length; i++) {
            _safeMint(_wallets[i], 1);
        }
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    //Returns URI of the particular token
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (!revealed) {
            return notRevealedUri;
        }
        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    //only owner
    function reveal(bool _revealed) public onlyOwner {
        revealed = _revealed;
    }

    function setMaxMintAmount(uint256 _maxMintAmount) public onlyOwner {
        maxMintAmount = _maxMintAmount;
    }

    function setWhiteListCost(uint256 _whiteListCost) public onlyOwner {
        whiteListCost = _whiteListCost;
    }

    function setPublicCost(uint256 _publicCost) public onlyOwner {
        publicCost = _publicCost;
    }

    function setMerkleRoot(bytes32 _newMerkleRoot) public onlyOwner {
        merkleRoot = _newMerkleRoot;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}