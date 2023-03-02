// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

import "./interfaces/IAddressStorage.sol";
import "./interfaces/ISpellParams.sol";

interface ISeasons {
    function startOfSeason() external view returns (uint256, uint256);
}

contract SpellParams is ISpellParams {
    IAddressStorage public addressStorage;

    constructor(address _addressStorage) {
        addressStorage = IAddressStorage(_addressStorage);
    }

    /// @notice gets cheaper deeper into the season
    function witherCost(uint256 target) public view override returns (uint256) {
        (uint256 seasonStart, uint256 season) = ISeasons(
            addressStorage.vineyard()
        ).startOfSeason();

        uint256 timePassed = block.timestamp - seasonStart;
        uint256 seasonLength = season == 1 ? 3 weeks : 12 weeks;
        return
            ((15_000e18 * (seasonLength - timePassed)) / seasonLength) +
            5_000e18;
    }

    function defendCost(uint256 target) public pure override returns (uint256) {
        return 2_000e18;
    }

    function vitalityCost(uint256 target)
        public
        pure
        override
        returns (uint256)
    {
        return 1_660e18;
    }

    function rejuveCost(uint256 ageInVinegar)
        public
        pure
        override
        returns (uint256)
    {
        return 3 * ageInVinegar;
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