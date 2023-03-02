// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

import "./interfaces/IAddressStorage.sol";
import "./interfaces/IGrape.sol";
import "./interfaces/IVinegar.sol";
import "./interfaces/IAlchemy.sol";
import "./interfaces/ISpellParams.sol";

interface IVine {
    function currSeason() external view returns (uint256);

    function plantingTime() external view returns (bool);
}

contract Alchemy is IAlchemy {
    IAddressStorage public addressStorage;

    mapping(uint256 => Withering) public withered;
    mapping(uint256 => uint256) public vitalized;

    event Wither(uint256 target, uint256 deadline, uint256 cost);
    event Defend(uint256 target, uint256 cost);
    event Vitality(uint256 target, uint256 cost);

    constructor(address _addressStorage) {
        addressStorage = IAddressStorage(_addressStorage);
    }

    /// @notice disable vineyard for season
    function wither(uint256 target) public {
        require(withered[target].deadline == 0, "already withering");
        uint256 deadline = block.timestamp + 16 hours; // TODO numbers
        uint256 cost = ISpellParams(addressStorage.spellParams()).witherCost(
            target
        );
        withered[target] = Withering(
            deadline,
            IVine(addressStorage.vineyard()).currSeason()
        );
        IVinegar(addressStorage.vinegar()).witherCost(msg.sender, cost);
        emit Wither(target, deadline, cost);
    }

    /// @notice blocks a wither
    function defend(uint256 target) public {
        require(
            withered[target].deadline >= block.timestamp &&
                withered[target].deadline != 0,
            "!withering"
        );
        uint256 cost = ISpellParams(addressStorage.spellParams()).defendCost(
            target
        );
        delete withered[target];
        IGrape(addressStorage.grape()).burn(msg.sender, cost);
        emit Defend(target, cost);
    }

    /// @notice burns grapes to boost xp gain on vineyard
    function vitality(uint256 target) public {
        uint256 currSeason = IVine(addressStorage.vineyard()).currSeason();
        require(vitalized[target] != currSeason, "already vitalized");
        require(
            IVine(addressStorage.vineyard()).plantingTime(),
            "!plantingTime"
        );
        vitalized[target] = currSeason;
        uint256 cost = ISpellParams(addressStorage.spellParams()).vitalityCost(
            target
        );
        IGrape(addressStorage.grape()).burn(msg.sender, cost);
        emit Vitality(target, cost);
    }

    function batchSpell(uint256[] calldata targets, uint8 spell) public {
        for (uint8 i = 0; i < targets.length; i++) {
            if (spell == 0) wither(targets[i]);
            if (spell == 1) defend(targets[i]);
            if (spell == 2) vitality(targets[i]);
        }
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

    function alchemy() external view returns (address);

    function grape() external view returns (address);

    function spellParams() external view returns (address);

    function wineUri() external view returns (address);

    function vineUri() external view returns (address);
}

// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface ISpellParams {
    function witherCost(uint256 target) external view returns (uint256);

    function defendCost(uint256 target) external view returns (uint256);

    function vitalityCost(uint256 target) external view returns (uint256);

    function rejuveCost(uint target) external view returns (uint256);
}

// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IGrape {
    function burn(address caller, uint256 amount) external;

    function mint(address caller, uint256 amount) external;
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

    function witherCost(address caller, uint256 amount) external;

    function mintReward(address caller) external;
}

// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IAlchemy {
    enum Spell {
        WITHER,
        DEFEND,
        VITALITY
    }
    struct Withering {
        uint256 deadline;
        uint256 season;
    }

    function withered(uint256 target)
        external
        view
        returns (uint256 deadline, uint256 season);

    function vitalized(uint256 target) external view returns (uint256);
}