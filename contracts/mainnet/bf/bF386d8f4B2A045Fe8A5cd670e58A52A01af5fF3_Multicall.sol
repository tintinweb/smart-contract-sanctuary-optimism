// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.12;

interface IVineyard {
    function canPlant(uint256 _tokenId) external view returns (bool);

    function canHarvest(uint256 _tokenId) external view returns (bool);

    function canWater(uint256 _tokenId) external view returns (bool);

    function planted(uint256 _tokenId) external view returns (uint256);
}

contract Multicall {
    // get farm status of list of tokens in one rpc call
    enum FarmStatus {
        NONE,
        PLANT,
        WATER,
        HARVEST,
        WATER_OR_HARVEST
    }

    function getFarmingStats(uint256[] calldata _tokenIds, address vineyard)
        public
        view
        returns (FarmStatus[] memory)
    {
        IVineyard Vineyard = IVineyard(vineyard);
        FarmStatus[] memory vals = new FarmStatus[](_tokenIds.length);
        for (uint256 i; i < _tokenIds.length; ++i) {
            FarmStatus farmStatus = FarmStatus.NONE;
            if (Vineyard.canPlant(_tokenIds[i])) {
                farmStatus = FarmStatus.PLANT;
            } else if (Vineyard.canHarvest(_tokenIds[i])) {
                if (
                    Vineyard.canWater(_tokenIds[i]) &&
                    Vineyard.planted(_tokenIds[i]) > 0
                ) {
                    farmStatus = FarmStatus.WATER_OR_HARVEST;
                } else {
                    farmStatus = FarmStatus.HARVEST;
                }
            } else if (
                Vineyard.canWater(_tokenIds[i]) &&
                Vineyard.planted(_tokenIds[i]) > 0
            ) {
                farmStatus = FarmStatus.WATER;
            }
            vals[i] = farmStatus;
        }
        return vals;
    }
}