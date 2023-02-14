// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../contracts/interfaces/IMultipleMerkleDistributor.sol";

abstract contract $IMultipleMerkleDistributor is IMultipleMerkleDistributor {
    constructor() {}
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../contracts/misc/BatchClaimer.sol";

contract $BatchClaimer is BatchClaimer {
    constructor() {}
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

// Allows anyone to claim a token if they exist in a merkle root.
interface IMultipleMerkleDistributor {
    /// @notice data structure for aggregating multiple claims
    struct Claims {
        uint256 index;
        address account;
        uint256 amount;
        bytes32[] merkleProof;
        uint256 epoch;
    }

    /// @notice event is triggered whenever a call to `claim` succeeds
    event Claimed(
        uint256 index,
        address account,
        uint256 amount,
        uint256 epoch
    );

    /// @notice event is triggered whenever a merkle root is set
    event MerkleRootModified(uint256 epoch);

    /// @return escrow for tokens claimed
    function rewardEscrow() external view returns (address);

    /// @return token to be distributed (KWENTA)
    function token() external view returns (address);

    // @return the merkle root of the merkle tree containing account balances available to claim
    function merkleRoots(uint256) external view returns (bytes32);

    /// @notice determine if indexed claim has been claimed
    /// @param index: used for claim managment
    /// @param epoch: distribution index number
    /// @return true if indexed claim has been claimed
    function isClaimed(uint256 index, uint256 epoch)
        external
        view
        returns (bool);

    /// @notice attempt to claim as `account` and escrow KWENTA for `account`
    /// @param index: used for merkle tree managment and verification
    /// @param account: address used for escrow entry
    /// @param amount: $KWENTA amount to be escrowed
    /// @param merkleProof: off-chain generated proof of merkle tree inclusion
    /// @param epoch: distribution index number
    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof,
        uint256 epoch
    ) external;

    /// @notice function that aggregates multiple claims
    /// @param claims: array of valid claims
    function claimMultiple(Claims[] calldata claims) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/IMultipleMerkleDistributor.sol";

contract BatchClaimer {
    
    function claimMultiple(
        IMultipleMerkleDistributor[] calldata _distributors,
        IMultipleMerkleDistributor.Claims[][] calldata _claims
    ) external {
        require(_distributors.length == _claims.length, "BatchClaimer: invalid input");
        for (uint256 i = 0; i < _distributors.length; i++) {
            _distributors[i].claimMultiple(_claims[i]);
        }
    }
}