/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-05-24
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

struct Vault {
    uint256 id;
    uint256 collateral;
    uint256 debt;
    uint256 collateralRatio;
    bool isLiquidatable;
}

interface IVault {
    function _minimumCollateralPercentage() external view returns (uint256);

    function checkCollateralPercentage(uint256) external view returns (uint256);

    function checkLiquidation(uint256) external view returns (bool);

    function ethPriceSource() external view returns (address);

    function exists(uint256) external view returns (bool);

    function getEthPriceSource() external view returns (uint256);

    function vaultCollateral(uint256) external view returns (uint256);

    function vaultDebt(uint256) external view returns (uint256);

    function vaultCount() external view returns (uint256);
}

contract Fetcher {
    function getInfo(address vaultAddress)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 vaultCount = IVault(vaultAddress).vaultCount();
        uint256 minimumCollateralRatio = IVault(vaultAddress)
            ._minimumCollateralPercentage();
        uint256 price = IVault(vaultAddress).getEthPriceSource();

        return (vaultCount, minimumCollateralRatio, price);
    }

    function getVault(address vaultAddress, uint256 vaultId)
        public
        view
        returns (Vault memory)
    {
        bool exists = IVault(vaultAddress).exists(vaultId);
        if (!exists) return Vault(0, 0, 0, 0, false);

        uint256 collateral = IVault(vaultAddress).vaultCollateral(vaultId);
        uint256 debt = IVault(vaultAddress).vaultDebt(vaultId);
        uint256 collateralRatio = IVault(vaultAddress)
            .checkCollateralPercentage(vaultId);
        bool isLiquidatable = IVault(vaultAddress).checkLiquidation(vaultId);

        return
            Vault(vaultId, collateral, debt, collateralRatio, isLiquidatable);
    }

    function getVaults(
        address vaultAddress,
        uint256 start,
        uint256 end
    ) external view returns (Vault[] memory) {
        require(end > start);
        Vault[] memory vaults = new Vault[](end - start);

        for (uint256 i = start; i < end; i++) {
            vaults[i - start] = getVault(vaultAddress, i);
        }
        return vaults;
    }
}