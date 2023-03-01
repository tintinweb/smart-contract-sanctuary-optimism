// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./interface/IL2EventLogger.sol";
import "./interface/IL2EventLoggerEvents.sol";
import "../shared/EventLogger.sol";

contract L2EventLogger is EventLogger, IL2EventLogger, IL2EventLoggerEvents {
    function emitCanonicalNftCreatorProceedsClaimable(
        address canonicalNftAddress_,
        uint256 tokenId_,
        uint256 amount_
    ) external override {
        emit CanonicalNftCreatorProceedsClaimable(
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
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../../shared/interface/IEventLogger.sol";

interface IL2EventLogger is IEventLogger {
    function emitCanonicalNftCreatorProceedsClaimable(
        address canonicalNftAddress_,
        uint256 tokenId_,
        uint256 amount_
    ) external;

    function emitRemintProceedsClaimed(address beneficiary_, uint256 amount_)
        external;

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

    function emitMarkReplicasAsAuthentic(
        address canonicalNft_,
        uint256 tokenId_
    ) external;

    function emitClaimEtherForMultipleNftsMessageFinalized(
        bytes32 canonicalNftsHash_,
        bytes32 tokenIdsHash_,
        address beneficiary_,
        uint256 etherAmount_
    ) external;

    function emitMarkReplicasAsAuthenticMessageFinalized(
        address canonicalNft_,
        uint256 tokenId_
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../../shared/interface/IEventLoggerEvents.sol";

interface IL2EventLoggerEvents is IEventLoggerEvents {
    event CanonicalNftCreatorProceedsClaimable(
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

    event ClaimEtherForMultipleNftsMessageFinalized(
        address indexed l2TokenClaimBridge,
        bytes32 canonicalNftsHash,
        bytes32 tokenIdsHash,
        address indexed beneficiary,
        uint256 etherAmount
    );

    event MarkReplicasAsAuthenticMessageFinalized(
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

    function emitReplicaTransferred(
        uint256 canonicalTokenId_,
        uint256 replicaTokenId_
    ) external {
        emit ReplicaTransferred(msg.sender, canonicalTokenId_, replicaTokenId_);
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

    event ReplicaTransferred(
        address indexed replica,
        uint256 canonicalTokenId,
        uint256 replicaTokenId
    );
}