// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IGrant } from './IGrant.sol';

contract LaunchGrant is IGrant {
    uint256 internal immutable startOffsetInSeconds;

    constructor(uint256 _startOffsetInSeconds) {
        if (block.timestamp < _startOffsetInSeconds) revert InvalidConfiguration();

        startOffsetInSeconds = _startOffsetInSeconds;
    }

    function getCurrentId() external view override returns (uint256) {
        return (block.timestamp - startOffsetInSeconds) / 7 days;
    }

    function getAmount(uint256 grantId) external pure override returns (uint256) {
        if (grantId == 12) return 1  * 10**18;
        if (grantId == 13) return 25 * 10**18;
        if (grantId == 14) return 15 * 10**18;
        if (grantId == 15) return 5  * 10**18;
        if (grantId == 16) return 2  * 10**18;
        return 0;
    }

    function checkValidity(uint256 grantId) external view override{
        if (this.getCurrentId() != grantId) revert InvalidGrant();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IGrant {
    /// @notice Error in case the grant is invalid.
    error InvalidGrant();

    /// @notice Error in case the grant configuration is invalid.
    error InvalidConfiguration();

    /// @notice Returns the current grant id.
    function getCurrentId() external view returns (uint256);

    /// @notice Returns the amount of tokens for a grant.
    /// @notice This may contain more complicated logic and is therefore not just a member variable.
    /// @param grantId The grant id to get the amount for.
    function getAmount(uint256 grantId) external view returns (uint256);

    /// @notice Checks whether a grant is valid.
    /// @param grantId The grant id to check.
    function checkValidity(uint256 grantId) external view;
}