// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

import "./interfaces/IWineBottle.sol";
import "./interfaces/IAddressStorage.sol";
import "./interfaces/IVinegar.sol";
import "./interfaces/IRoyaltyManager.sol";

contract VotableUri {
    uint256 public startTimestamp;
    mapping(uint256 => uint256) public voted;
    uint256 public forVotes;
    uint256 public againstVotes;
    string public newUri;
    address public newArtist;
    bool public settled = true;
    IAddressStorage addressStorage;

    string public uri; // animation_uri in metadata
    address public artist; // secondary market royalties recipient

    string public image; // image_uri in metadata (marketplace thumbs)

    // EVENTS
    event Suggest(
        uint256 startTimestamp,
        string newUri,
        address newArtist,
        uint256 bottle,
        uint256 forVotes
    );
    event Support(uint256 startTimestamp, uint256 bottle, uint256 forVotes);
    event Retort(uint256 startTimestamp, uint256 bottle, uint256 againstVotes);
    event Complete(uint256 startTimestamp, string newUri, address newArtist);
    event Setup(string newUri, address newArtist);

    // CONSTRUCTOR
    constructor(address _addressStorage, string memory _animUri, string memory _imguri) {
        addressStorage = IAddressStorage(_addressStorage);
        uri = _animUri;
        artist = msg.sender;

        image = _imguri;
        
        emit Setup(uri, artist);
    }

    // PUBLIC FUNCTIONS
    /// @notice suggest a new uri and royalties recipient
    /// @param _tokenId bottle token id to vote with
    /// @param _newUri new uri, preferably ipfs/arweave
    /// @param _artist secondary market royalties recipient
    function suggest(
        uint256 _tokenId,
        string calldata _newUri,
        address _artist
    ) public {
        require(
            (forVotes == 0 && againstVotes == 0) ||
                (forVotes > againstVotes &&
                    startTimestamp + 9 days < block.timestamp) ||
                (forVotes > againstVotes &&
                    startTimestamp + 48 hours < block.timestamp &&
                    !settled) ||
                (againstVotes > forVotes &&
                    startTimestamp + 36 hours < block.timestamp),
            "Too soon"
        );
        IWineBottle bottle = IWineBottle(addressStorage.bottle());
        require(bottle.ownerOf(_tokenId) == msg.sender, "Bottle not owned");

        startTimestamp = block.timestamp;
        voted[_tokenId] = block.timestamp;
        forVotes = bottle.bottleAge(_tokenId);
        againstVotes = 0;
        newUri = _newUri;
        newArtist = _artist;
        settled = false;
        emit Suggest(startTimestamp, _newUri, _artist, _tokenId, forVotes);
    }

    /// @notice vote for the current suggestion
    /// @param _tokenId bottle to vote with
    function support(uint256 _tokenId) public {
        IWineBottle bottle = IWineBottle(addressStorage.bottle());
        require(bottle.ownerOf(_tokenId) == msg.sender, "Bottle not owned");
        require(voted[_tokenId] + 36 hours < block.timestamp, "Double vote");
        require(startTimestamp + 36 hours > block.timestamp, "No queue");

        voted[_tokenId] = block.timestamp;
        forVotes += bottle.bottleAge(_tokenId);
        emit Support(startTimestamp, _tokenId, forVotes);
    }

    /// @notice vote against current suggestion
    /// @param _tokenId bottle to vote with
    function retort(uint256 _tokenId) public {
        IWineBottle bottle = IWineBottle(addressStorage.bottle());
        require(bottle.ownerOf(_tokenId) == msg.sender, "Bottle not owned");
        require(voted[_tokenId] + 36 hours < block.timestamp, "Double vote");
        require(startTimestamp + 36 hours > block.timestamp, "No queue");

        voted[_tokenId] = block.timestamp;
        againstVotes += bottle.bottleAge(_tokenId);
        emit Retort(startTimestamp, _tokenId, againstVotes);
    }

    /// @notice writes suggested address and uri to contract mapping
    function complete() public {
        require(forVotes > againstVotes, "Blocked");
        require(startTimestamp + 36 hours < block.timestamp, "Too soon");
        require(startTimestamp + 48 hours > block.timestamp, "Too late");

        artist = newArtist;
        uri = newUri;
        settled = true;
        IVinegar(addressStorage.vinegar()).voteReward(newArtist);

        IRoyaltyManager(addressStorage.royaltyManager()).updateRoyalties(
            newArtist
        );
        emit Complete(startTimestamp, newUri, newArtist);
    }
}

// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IWineBottle {
    function newBottle(uint256 _vineyard, address _owner)
        external
        returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function bottleAge(uint256 _tokenID) external view returns (uint256);
}

// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IAddressStorage {
    function cellar() external view returns (address);

    function vinegar() external view returns (address);

    function vineyard() external view returns (address);

    function bottle() external view returns (address);

    function giveawayToken() external view returns (address);

    function royaltyManager() external view returns (address);

    function merkle() external view returns (address);

    function wineUri() external view returns (address);

    function vineUri() external view returns (address);
}

// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IVinegar {
    function voteReward(address recipient) external;

    function spoilReward(address recipient, uint256 cellarAge) external;

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function rejuvenationCost(address account, uint256 cellarAge) external;
}

// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IRoyaltyManager {
    function updateRoyalties(address recipient) external;
}