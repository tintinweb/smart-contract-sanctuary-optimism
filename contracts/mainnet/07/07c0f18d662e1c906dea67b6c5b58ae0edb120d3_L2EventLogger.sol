// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./interface/IL2EventLogger.sol";
import "./interface/IL2EventLoggerEvents.sol";
import "../shared/EventLogger.sol";

contract L2EventLogger is EventLogger, IL2EventLogger, IL2EventLoggerEvents {
    function emitCanonicalNftOwnerProceedsClaimable(
        address canonicalNftAddress_,
        uint256 tokenId_,
        uint256 amount_
    ) external override {
        emit CanonicalNftOwnerProceedsClaimable(
            msg.sender,
            canonicalNftAddress_,
            tokenId_,
            amount_
        );
    }

    function emitRemintProceedsClaimed(address beneficiary_, uint256 amount_)
        external
        override
    {
        emit RemintProceedsClaimed(msg.sender, beneficiary_, amount_);
    }

    function emitRemintCostReclaimed(
        address beneficiary_,
        uint256 amount_,
        address replicaNft_,
        uint256 replicaTokenId_
    ) external override {
        emit RemintCostReclaimed(
            msg.sender,
            beneficiary_,
            amount_,
            replicaNft_,
            replicaTokenId_
        );
    }

    function emitProtocolFeeReceived(
        address canonicalNft_,
        uint256 canonicalTokenId_,
        uint256 amount_
    ) external override {
        emit ProtocolFeeReceived(
            msg.sender,
            canonicalNft_,
            canonicalTokenId_,
            amount_
        );
    }

    function emitReplicaMinted(
        address to_,
        address canonicalNft_,
        uint256 canonicalTokenId_,
        uint256 replicaTokenId_,
        uint256 remintPrice_
    ) external override {
        emit ReplicaMinted(
            to_,
            canonicalNft_,
            msg.sender,
            canonicalTokenId_,
            replicaTokenId_,
            remintPrice_
        );
    }

    function emitMarkReplicasAsAuthentic(
        address canonicalNft_,
        uint256 tokenId_
    ) external override {
        emit MarkReplicasAsAuthentic(msg.sender, canonicalNft_, tokenId_);
    }

    function emitReplicasBurned(address canonicalNft_, uint256 tokenId_)
        external
        override
    {
        emit ReplicasBurned(msg.sender, canonicalNft_, tokenId_);
    }

    function emitRemintingDisabled(address canonicalNft_, uint256 tokenId_)
        external
        override
    {
        emit RemintingDisabled(msg.sender, canonicalNft_, tokenId_);
    }

    function emitRemintingEnabled(address canonicalNft_, uint256 tokenId_)
        external
        override
    {
        emit RemintingEnabled(msg.sender, canonicalNft_, tokenId_);
    }

    function emitClaimEtherForMultipleNftsMessageFinalized(
        bytes32 canonicalNftsHash_,
        bytes32 tokenIdsHash_,
        address beneficiary_,
        uint256 etherAmount_
    ) external override {
        emit ClaimEtherForMultipleNftsMessageFinalized(
            msg.sender,
            canonicalNftsHash_,
            tokenIdsHash_,
            beneficiary_,
            etherAmount_
        );
    }

    function emitClaimEtherMessageFinalized(
        address canonicalNft_,
        uint256 tokenId_,
        address beneficiary_,
        uint256 etherAmount_
    ) external override {
        emit ClaimEtherMessageFinalized(
            msg.sender,
            canonicalNft_,
            tokenId_,
            beneficiary_,
            etherAmount_
        );
    }

    function emitMarkReplicasAsAuthenticMessageFinalized(
        address canonicalNft_,
        uint256 tokenId_
    ) external override {
        emit MarkReplicasAsAuthenticMessageFinalized(
            msg.sender,
            canonicalNft_,
            tokenId_
        );
    }

    function emitMarkReplicasAsAuthenticMultipleMessageFinalized(
        bytes32 canonicalNftsHash_,
        bytes32 tokenIdsHash_
    ) external override {
        emit MarkReplicasAsAuthenticMultipleMessageFinalized(
            msg.sender,
            canonicalNftsHash_,
            tokenIdsHash_
        );
    }

    function emitBurnReplicasAndDisableRemintsMessageFinalized(
        address canonicalNft_,
        uint256 tokenId_
    ) external override {
        emit BurnReplicasAndDisableRemintsMessageFinalized(
            msg.sender,
            canonicalNft_,
            tokenId_
        );
    }

    function emitBurnReplicasAndDisableRemintsMultipleMessageFinalized(
        bytes32 canonicalNftsHash_,
        bytes32 tokenIdsHash_
    ) external override {
        emit BurnReplicasAndDisableRemintsMultipleMessageFinalized(
            msg.sender,
            canonicalNftsHash_,
            tokenIdsHash_
        );
    }

    function emitEnableRemintsMessageFinalized(
        address canonicalNft_,
        uint256 tokenId_
    ) external override {
        emit EnableRemintsMessageFinalized(msg.sender, canonicalNft_, tokenId_);
    }

    function emitEnableRemintsMultipleMessageFinalized(
        bytes32 canonicalNftsHash_,
        bytes32 tokenIdsHash_
    ) external override {
        emit EnableRemintsMultipleMessageFinalized(
            msg.sender,
            canonicalNftsHash_,
            tokenIdsHash_
        );
    }

    function emitDisableRemintsMessageFinalized(
        address canonicalNft_,
        uint256 tokenId_
    ) external override {
        emit DisableRemintsMessageFinalized(
            msg.sender,
            canonicalNft_,
            tokenId_
        );
    }

    function emitDisableRemintsMultipleMessageFinalized(
        bytes32 canonicalNftsHash_,
        bytes32 tokenIdsHash_
    ) external override {
        emit DisableRemintsMultipleMessageFinalized(
            msg.sender,
            canonicalNftsHash_,
            tokenIdsHash_
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../../shared/interface/IEventLogger.sol";

interface IL2EventLogger is IEventLogger {
    function emitCanonicalNftOwnerProceedsClaimable(
        address canonicalNftAddress_,
        uint256 tokenId_,
        uint256 amount_
    ) external;

    function emitRemintProceedsClaimed(address beneficiary_, uint256 amount_)
        external;

    function emitRemintCostReclaimed(
        address beneficiary_,
        uint256 amount_,
        address replicaNft_,
        uint256 replicaTokenId_
    ) external;

    function emitReplicaMinted(
        address to_,
        address canonicalNft_,
        uint256 canonicalTokenId_,
        uint256 replicaTokenId_,
        uint256 remintPrice_
    ) external;

    function emitProtocolFeeReceived(
        address canonicalNft_,
        uint256 canonicalTokenId_,
        uint256 amount_
    ) external;

    function emitRemintingDisabled(address canonicalNft_, uint256 tokenId_)
        external;

    function emitRemintingEnabled(address canonicalNft_, uint256 tokenId_)
        external;

    function emitMarkReplicasAsAuthentic(
        address canonicalNft_,
        uint256 tokenId_
    ) external;

    function emitReplicasBurned(address canonicalNft_, uint256 tokenId_)
        external;

    function emitClaimEtherForMultipleNftsMessageFinalized(
        bytes32 canonicalNftsHash_,
        bytes32 tokenIdsHash_,
        address beneficiary_,
        uint256 etherAmount_
    ) external;

    function emitClaimEtherMessageFinalized(
        address canonicalNft_,
        uint256 tokenId_,
        address beneficiary_,
        uint256 etherAmount_
    ) external;

    function emitMarkReplicasAsAuthenticMessageFinalized(
        address canonicalNft_,
        uint256 tokenId_
    ) external;

    function emitMarkReplicasAsAuthenticMultipleMessageFinalized(
        bytes32 canonicalNftsHash_,
        bytes32 tokenIdsHash_
    ) external;

    function emitBurnReplicasAndDisableRemintsMessageFinalized(
        address canonicalNft_,
        uint256 tokenId_
    ) external;

    function emitBurnReplicasAndDisableRemintsMultipleMessageFinalized(
        bytes32 canonicalNftsHash_,
        bytes32 tokenIdsHash_
    ) external;

    function emitEnableRemintsMessageFinalized(
        address canonicalNft_,
        uint256 tokenId_
    ) external;

    function emitEnableRemintsMultipleMessageFinalized(
        bytes32 canonicalNftsHash_,
        bytes32 tokenIdsHash_
    ) external;

    function emitDisableRemintsMessageFinalized(
        address canonicalNft_,
        uint256 tokenId_
    ) external;

    function emitDisableRemintsMultipleMessageFinalized(
        bytes32 canonicalNftsHash_,
        bytes32 tokenIdsHash_
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../../shared/interface/IEventLoggerEvents.sol";

interface IL2EventLoggerEvents is IEventLoggerEvents {
    event CanonicalNftOwnerProceedsClaimable(
        address indexed remintProceedsTreasury,
        address indexed canonicalNftAddress,
        uint256 indexed tokenId,
        uint256 amount
    );

    event RemintProceedsClaimed(
        address remintProceedsTreasury,
        address beneficiary,
        uint256 amount
    );

    event RemintCostReclaimed(
        address indexed remintProceedsTreasury,
        address indexed beneficiary,
        uint256 amount,
        address indexed replicaNft,
        uint256 replicaTokenId
    );

    event ProtocolFeeReceived(
        address indexed homageProtocolTreasury,
        address indexed canonicalNft,
        uint256 indexed canonicalTokenId,
        uint256 amount
    );

    event ReplicaMinted(
        address indexed to,
        address indexed canonicalNft,
        address indexed replicaNft,
        uint256 canonicalTokenId,
        uint256 replicaTokenId,
        uint256 remintPrice
    );

    event MarkReplicasAsAuthentic(
        address indexed l2Replica,
        address indexed canonicalNft,
        uint256 indexed tokenId
    );

    event ReplicasBurned(
        address indexed l2Replica,
        address indexed canonicalNft,
        uint256 indexed tokenId
    );

    event RemintingDisabled(
        address indexed l2Replica,
        address indexed canonicalNft,
        uint256 indexed tokenId
    );

    event RemintingEnabled(
        address indexed l2Replica,
        address indexed canonicalNft,
        uint256 indexed tokenId
    );

    event ClaimEtherForMultipleNftsMessageFinalized(
        address indexed l2TokenClaimBridge,
        bytes32 canonicalNftsHash,
        bytes32 tokenIdsHash,
        address indexed beneficiary,
        uint256 etherAmount
    );

    event ClaimEtherMessageFinalized(
        address indexed l2TokenClaimBridge,
        address indexed canonicalNft,
        uint256 tokenId,
        address indexed beneficiary,
        uint256 etherAmount
    );

    event MarkReplicasAsAuthenticMessageFinalized(
        address indexed l2TokenClaimBridge,
        address indexed canonicalNft,
        uint256 indexed tokenId
    );

    event MarkReplicasAsAuthenticMultipleMessageFinalized(
        address indexed l2TokenClaimBridge,
        bytes32 canonicalNftsHash,
        bytes32 tokenIdsHash
    );

    event BurnReplicasAndDisableRemintsMultipleMessageFinalized(
        address indexed l2TokenClaimBridge,
        bytes32 canonicalNftsHash,
        bytes32 tokenIdsHash
    );

    event BurnReplicasAndDisableRemintsMessageFinalized(
        address indexed l2TokenClaimBridge,
        address indexed canonicalNft,
        uint256 indexed tokenId
    );

    event EnableRemintsMultipleMessageFinalized(
        address indexed l2TokenClaimBridge,
        bytes32 canonicalNftsHash,
        bytes32 tokenIdsHash
    );

    event EnableRemintsMessageFinalized(
        address indexed l2TokenClaimBridge,
        address indexed canonicalNft,
        uint256 indexed tokenId
    );

    event DisableRemintsMultipleMessageFinalized(
        address indexed l2TokenClaimBridge,
        bytes32 canonicalNftsHash,
        bytes32 tokenIdsHash
    );

    event DisableRemintsMessageFinalized(
        address indexed l2TokenClaimBridge,
        address indexed canonicalNft,
        uint256 indexed tokenId
    );
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./interface/IEventLogger.sol";
import "./interface/IEventLoggerEvents.sol";

abstract contract EventLogger is IEventLogger, IEventLoggerEvents {
    function emitReplicaDeployed(address replica_) external {
        emit ReplicaDeployed(msg.sender, replica_);
    }

    function emitReplicaRegistered(
        address canonicalNftContract_,
        uint256 canonicalTokenId_,
        address replica_
    ) external {
        emit ReplicaRegistered(
            msg.sender,
            canonicalNftContract_,
            canonicalTokenId_,
            replica_
        );
    }

    function emitReplicaUnregistered(address replica_) external {
        emit ReplicaUnregistered(msg.sender, replica_);
    }

    function emitReplicaTransferred(
        uint256 canonicalTokenId_,
        uint256 replicaTokenId_
    ) external {
        emit ReplicaTransferred(msg.sender, canonicalTokenId_, replicaTokenId_);
    }

    function emitReplicaBridgingInitiated(
        address canonicalNftContract_,
        uint256 replicaTokenId_,
        address sourceOwnerAddress_,
        address destinationOwnerAddress_
    ) external {
        emit ReplicaBridgingInitiated(
            msg.sender,
            canonicalNftContract_,
            replicaTokenId_,
            sourceOwnerAddress_,
            destinationOwnerAddress_
        );
    }

    function emitReplicaBridgingFinalized(
        address canonicalNftContract_,
        uint256 replicaTokenId_,
        address sourceOwnerAddress_,
        address destinationOwnerAddress_
    ) external {
        emit ReplicaBridgingFinalized(
            msg.sender,
            canonicalNftContract_,
            replicaTokenId_,
            sourceOwnerAddress_,
            destinationOwnerAddress_
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IEventLogger {
    function emitReplicaDeployed(address replica_) external;

    function emitReplicaTransferred(
        uint256 canonicalTokenId_,
        uint256 replicaTokenId_
    ) external;

    function emitReplicaRegistered(
        address canonicalNftContract_,
        uint256 canonicalTokenId_,
        address replica_
    ) external;

    function emitReplicaUnregistered(address replica_) external;

    function emitReplicaBridgingInitiated(
        address canonicalNftContract_,
        uint256 replicaTokenId_,
        address sourceOwnerAddress_,
        address destinationOwnerAddress_
    ) external;

    function emitReplicaBridgingFinalized(
        address canonicalNftContract_,
        uint256 replicaTokenId_,
        address sourceOwnerAddress_,
        address destinationOwnerAddress_
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

//**
//* As convention, we put the indexed address of the caller as the first parameter of each event.
//* This is so that we can verify that the (indirect) emitter of the event is a verified part
//* of the protocol.
//**
interface IEventLoggerEvents {
    event ReplicaDeployed(
        address indexed replicaFactory,
        address indexed replica
    );

    event ReplicaRegistered(
        address indexed replicaRegistry,
        address indexed canonicalNftContract,
        uint256 canonicalTokenId,
        address indexed replica
    );

    event ReplicaUnregistered(
        address indexed replicaRegistry,
        address indexed replica
    );

    event ReplicaTransferred(
        address indexed replica,
        uint256 canonicalTokenId,
        uint256 replicaTokenId
    );

    event ReplicaBridgingInitiated(
        address indexed bridge,
        address indexed canonicalNftContract,
        uint256 replicaTokenId,
        address indexed sourceOwnerAddress,
        address destinationOwnerAddress
    );

    event ReplicaBridgingFinalized(
        address indexed bridge,
        address indexed canonicalNftContract,
        uint256 replicaTokenId,
        address sourceOwnerAddress,
        address indexed destinationOwnerAddress
    );
}