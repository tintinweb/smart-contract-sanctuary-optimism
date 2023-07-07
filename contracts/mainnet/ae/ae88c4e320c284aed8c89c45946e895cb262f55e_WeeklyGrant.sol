// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IGrant } from './IGrant.sol';

contract WeeklyGrant is IGrant {
    uint256 internal immutable offset;
    uint256 internal immutable amount;

    constructor(uint256 _offset, uint256 _amount) {
        offset = _offset;
        amount = _amount;
    }

    function getCurrentId() external view override returns (uint256) {
        return (block.timestamp - offset) / (7*24*3600);
    }

    function getAmount(uint256) external view override returns (uint256) {
        return amount;
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