// SPDX-License-Identifier: Unlicense
/**
._______ ._______.___    .___    .______  .______  
:_.  ___\: .____/|   |   |   |   :      \ : __   \ 
|  : |/\ | : _/\ |   |   |   |   |   .   ||  \____|
|    /  \|   /  \|   |/\ |   |/\ |   :   ||   :  \ 
|. _____/|_.: __/|   /  \|   /  \|___|   ||   |___\
 :/         :/   |______/|______/    |___||___|    
 :   
                                               
 */
pragma solidity ^0.8.0;

import "./interfaces/IAddressStorage.sol";
import "./interfaces/IVinegar.sol";

interface IERC721 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function burn(uint256 tokenId) external;
}

interface IWineBottle {
    function cellarAged(uint256 cellarTime) external view returns (uint256);
}

contract Cellar {
    IAddressStorage public addressStorage;

    mapping(uint256 => uint256) public staked;
    mapping(uint256 => uint256) public withdrawn;
    mapping(uint256 => address) public owner;

    //EVENTS
    event Staked(uint256 tokenId);
    event Withdrawn(uint256 tokenId, uint256 cellarTime);
    event Spoiled(uint256 tokenId);

    // CONSTRUCTOR
    constructor(address _addressStorage) {
        addressStorage = IAddressStorage(_addressStorage);
    }

    // FUNCTIONS
    /// @notice returns time spent in cellar
    function cellarTime(uint256 _tokenID) public view returns (uint256) {
        if (withdrawn[_tokenID] == 0 && staked[_tokenID] != 0) {
            // currently in cellar
            return 0;
        }
        return withdrawn[_tokenID] - staked[_tokenID];
    }

    /// @notice stakes bottle in contract
    function stake(uint256 _tokenID) public {
        require(staked[_tokenID] == 0, "Id already staked");
        address wineBottle = addressStorage.bottle();
        staked[_tokenID] = block.timestamp;
        owner[_tokenID] = msg.sender;
        IERC721(wineBottle).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenID
        );
        emit Staked(_tokenID);
    }

    /// @notice calculates chance that bottle spoils
    function spoilChance(uint256 stakedDays)
        public
        pure
        returns (uint256 chance)
    {
        if (stakedDays < 360) {
            chance = 100 * (5 + ((365 - stakedDays) / 38)**2);
        } else {
            chance = 500;
        }
    }

    /// @notice unstakes bottle from contract
    function withdraw(uint256 _tokenID) public {
        require(staked[_tokenID] != 0, "Id not staked");
        require(owner[_tokenID] == msg.sender, "Id not owned");

        address wineBottle = addressStorage.bottle();
        withdrawn[_tokenID] = block.timestamp;

        // probability of spoiling
        uint256 rand = random(
            string(abi.encodePacked(block.timestamp, _tokenID))
        ) % 10000; // TODO: better rand num?
        uint256 stakedDays = (withdrawn[_tokenID] - staked[_tokenID]) /
            (1 days);

        if (rand < spoilChance(stakedDays)) {
            IERC721(wineBottle).safeTransferFrom(
                address(this),
                msg.sender,
                _tokenID
            );
            emit Withdrawn(_tokenID, withdrawn[_tokenID] - staked[_tokenID]);
        } else {
            IVinegar(addressStorage.vinegar()).spoilReward(
                msg.sender,
                IWineBottle(addressStorage.bottle()).cellarAged(
                    cellarTime(_tokenID)
                )
            );
            IERC721(wineBottle).burn(_tokenID);
            emit Spoiled(_tokenID);
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }
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