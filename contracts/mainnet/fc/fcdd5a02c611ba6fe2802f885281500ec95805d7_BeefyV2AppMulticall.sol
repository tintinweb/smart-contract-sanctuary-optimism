/**
 *Submitted for verification at optimistic.etherscan.io on 2022-06-27
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IBeefyVault {
    function balance() external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
    function strategy() external view returns (address);
}

interface IBeefyBoost {
    function totalSupply() external view returns (uint256);
    function periodFinish() external view returns (uint256);
    function rewardRate() external view returns (uint256);
}

struct BoostInfo {
    uint256 totalSupply;
    uint256 rewardRate;
    uint256 periodFinish;
}

struct VaultInfo {
    uint256 balance;
    uint256 pricePerFullShare;
    address strategy;
}

struct GovVaultInfo {
    uint256 totalSupply;
}

contract BeefyV2AppMulticall {

    function getVaultInfo(address[] calldata vaults) external view returns (VaultInfo[] memory) {
        VaultInfo[] memory results = new VaultInfo[](vaults.length);

        for (uint i = 0; i < vaults.length; i++) {
            IBeefyVault vault = IBeefyVault(vaults[i]);
            results[i] = VaultInfo(
                vault.balance(),
                vault.getPricePerFullShare(),
                vault.strategy()
            );
        }

        return results;
    }

    function getBoostInfo(address[] calldata boosts) external view returns (BoostInfo[] memory) {
        BoostInfo[] memory results = new BoostInfo[](boosts.length);

        for (uint i = 0; i < boosts.length; i++) {
            IBeefyBoost boost = IBeefyBoost(boosts[i]);
            results[i] = BoostInfo(
                boost.totalSupply(),
                boost.rewardRate(),
                boost.periodFinish()
            );
        }

        return results;
    }

    function getGovVaultInfo(address[] calldata govVaults) external view returns (GovVaultInfo[] memory) {
        GovVaultInfo[] memory results = new GovVaultInfo[](govVaults.length);

        for (uint i = 0; i < govVaults.length; i++) {
            IBeefyBoost govVault = IBeefyBoost(govVaults[i]);
            results[i] = GovVaultInfo(
                govVault.totalSupply()
            );
        }

        return results;
    }
}