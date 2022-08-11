// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./Identity.sol";

/// @title identity factory
/// @author Sudham Jayanthi
/// @notice factory contract to deploy new identities
contract IdentityFactory {

    /// @notice Emits when a new identity is created
    event NewIdentity(address indexed identity, address[] owners);

    /// @notice creates new identity
    /// @param _owners list of owners of the identity
    /// @param _equities list of owners of the equities corresponding to the identities
    function createIdentity(
        address[] memory _owners,
        uint256[] memory _equities
    ) public {
        Identity identity = new Identity(_owners, _equities);
        emit NewIdentity(address(identity), _owners);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IERC20 {
    function transfer(address _to, uint256 _value) external;

    function balanceOf(address _owner) external view returns (uint256 balance);
}

interface IERC721 {
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external;
}

interface IERC721Receiver {
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external returns (bytes4);
}

/// @title smart identity
/// @author Sudham Jayanthi
/// @notice A POC to form decentralised entities
contract Identity is IERC721Receiver {
    /// @notice stores the list of owners
    address[] public owners;

    /// @notice stores the equity %s of the owners, as integers (1-100)
    /// @dev the equity at any index is of the owner at the same index
    mapping(address => uint256) public equities;

    /// @notice stores the list of accepted tokens
    /// @dev only accepted tokens are cashed out in withdraw()
    address[] public acceptedTokens;

    /// @notice custom structure to track the nfts sent to the identity
    /// @param sentBy address of the owner which sent the token
    /// @param collection collection address
    /// @param tokenId token id
    /// @param sentAt block number at which nft is sent
    struct NFT {
        address sentBy;
        address collection;
        uint256 tokenId;
        uint256 sentAt;
    }

    /// @notice stores the list of nfts sent to the identity
    NFT[] public nfts;

    /// @dev a mapping to implement the onlyOwner modifier easily
    mapping(address => bool) public isOwner;

    /// @notice a modifier to gate access to certain functions
    modifier onlyOwners() {
        require(isOwner[msg.sender], "not a owner");
        _;
    }

    /// @notice constructs the identity with given owners and equities
    /// @param _owners list of owners of the identity
    /// @param _equities list of equities corresponding to the owners
    /// @dev the equity at any index is of the owner at the same index
    constructor(address[] memory _owners, uint256[] memory _equities) {
        owners = _owners;

        for (uint256 i = 0; i < _owners.length; ) {
            isOwner[_owners[i]] = true;
            equities[_owners[i]] = _equities[i];

            unchecked {
                ++i;
            }
        }
    }

    /// @notice returns a list of the all owners of the identity
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    /// @notice returns a list of all the nfts sent to the identity
    function getNfts() external view returns (NFT[] memory) {
        return nfts;
    }

    /// @notice returns a list of all tokens accepted by the owners of identity
    function getAcceptedTokens() external view returns (address[] memory) {
        return acceptedTokens;
    }

    /// @notice transfers a nft to the identity
    /// @param nftCollection address of the nft collection
    /// @param tokenId token id of the nft
    /// @dev nft needs to be approved to the identity before calling this function
    function transferNFT(address nftCollection, uint256 tokenId) public {
        // transfer nft
        IERC721(nftCollection).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );

        // store it in the contract
        NFT memory nft = NFT(msg.sender, nftCollection, tokenId, block.number);
        nfts.push(nft);
    }

    /// @notice checks if a certain nft is owned by the identity
    /// @param nftCollection address of the nft collection
    /// @param tokenId token id of the nft
    /// @dev returns (true, number of blocks since the nft is transferred to identity) if the nft is owned by the identity
    /// @dev returns (false, 0) otherwise
    function hasNft(address nftCollection, uint256 tokenId)
        external
        view
        returns (bool, uint256)
    {
        bool doIHave;
        uint256 since;

        uint256 _nftsLength = nfts.length;

        for (uint256 i = 0; i < _nftsLength; ) {
            if (
                nfts[i].collection == nftCollection &&
                nfts[i].tokenId == tokenId
            ) {
                doIHave = true;
                since = block.number - nfts[i].sentAt;
            }

            unchecked {
                ++i;
            }
        }

        return (doIHave, since);
    }

    /// @notice accepts a erc20 token
    /// @param token address of the erc20 token to be accepted
    function acceptErc20(address token) public onlyOwners {
        acceptedTokens.push(token);
    }

    /// @notice withdraws native & erc20 tokens according to the equities of owners
    /// @dev only the erc20 tokens accepted by owners using acceptErc20() are withdrawn
    function withdraw() public onlyOwners {
        uint256 _etherBal = address(this).balance;

        uint256 _ownersLength = owners.length;

        // returns ether according to the equities of owners
        for (uint256 i = 0; i < _ownersLength; ) {
            payable(owners[i]).transfer(
                (_etherBal * equities[owners[i]]) / 100
            );

            unchecked {
                ++i;
            }
        }

        uint256 _tokensLength = acceptedTokens.length;

        // returns erc20s according to the equities of owners
        for (uint256 j = 0; j < _tokensLength; j++) {
            uint256 erc20Bal = IERC20(acceptedTokens[j]).balanceOf(
                address(this)
            );

            for (uint256 i = 0; i < _ownersLength; i++) {
                IERC20(acceptedTokens[j]).transfer(
                    owners[i],
                    (erc20Bal * equities[owners[i]]) / 100
                );
            }
        }
    }

    /// @notice disintegrates the identity - returns ether & erc20 tokens back to the owners according to their equitites and nfts to back to their original owners
    /// @dev only the erc20 tokens accepted by owners using acceptErc20() are withdrawn
    function disintegrate() public onlyOwners {
        // withdraws ether & erc20 tokens
        withdraw();

        uint256 _nftsLength = nfts.length;

        // returns nfts to their original owners
        for (uint256 i = 0; i < _nftsLength; ) {
            IERC721(nfts[i].collection).safeTransferFrom(
                address(this),
                nfts[i].sentBy,
                nfts[i].tokenId
            );

            unchecked {
                ++i;
            }
        }

        // destructs the contract forever
        selfdestruct(payable(msg.sender));
    }

    /// @dev this allows other contracts to send ether to the identity
    receive() external payable {}

    /// @dev this allows the identity to recieve erc721 tokens
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}