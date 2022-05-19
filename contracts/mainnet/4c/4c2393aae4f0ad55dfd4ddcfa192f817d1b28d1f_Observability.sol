// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./interface/IObservability.sol";

/**
 * @title Observability
 * @author MirrorXYZ
 */
contract Observability is IObservability, IObservabilityEvents {
    /// > [[[[[[[[[[[ Factory functions ]]]]]]]]]]]

    function emitDeploymentEvent(address owner, address clone)
        external
        override
    {
        emit CloneDeployed(msg.sender, owner, clone);
    }

    function emitTributarySet(
        address clone,
        address oldTributary,
        address newTributary
    ) external override {
        emit TributarySet(msg.sender, clone, oldTributary, newTributary);
    }

    function emitFactoryLimitSet(uint256 oldLimit, uint256 newLimit)
        external
        override
    {
        emit FactoryLimitSet(msg.sender, oldLimit, newLimit);
    }

    function emitFactoryGuardSet(bool guard) external override {
        emit FactoryGuardSet(guard);
    }

    function emitFactoryImplementationSet(
        address oldImplementation,
        address newImplementation
    ) external override {
        emit FactoryImplementationSet(
            msg.sender,
            oldImplementation,
            newImplementation
        );
    }

    /// > [[[[[[[[[[[ Clone functions ]]]]]]]]]]]

    function emitWritingEditionPurchased(
        uint256 tokenId,
        address recipient,
        uint256 price,
        string memory message
    ) external override {
        emit WritingEditionPurchased(
            msg.sender,
            tokenId,
            recipient,
            price,
            message
        );
    }

    function emitTransferEvent(
        address from,
        address to,
        uint256 tokenId
    ) external override {
        emit Transfer(msg.sender, from, to, tokenId);
    }

    function emitRoyaltyChange(
        address oldRoyaltyRecipient,
        uint256 oldRoyaltyBPS,
        address newRoyaltyRecipient,
        uint256 newRoyaltyBPS
    ) external override {
        emit RoyaltyChange(
            msg.sender,
            oldRoyaltyRecipient,
            oldRoyaltyBPS,
            newRoyaltyRecipient,
            newRoyaltyBPS
        );
    }

    function emitRendererSet(address renderer) external override {
        emit RendererSet(msg.sender, renderer);
    }

    function emitWritingEditionLimitSet(uint256 oldLimit, uint256 newLimit)
        external
        override
    {
        emit WritingEditionLimitSet(msg.sender, oldLimit, newLimit);
    }

    function emitPriceSet(uint256 oldPrice, uint256 newPrice)
        external
        override
    {
        emit PriceSet(msg.sender, oldPrice, newPrice);
    }

    function emitFundingRecipientSet(
        address oldFundingRecipient,
        address newFundingRecipient
    ) external override {
        emit FundingRecipientSet(
            msg.sender,
            oldFundingRecipient,
            newFundingRecipient
        );
    }

    function emitBaseDescriptionURISet(
        string memory oldBaseDescriptionURI,
        string memory newBaseDescriptionURI
    ) external override {
        emit BaseDescriptionURISet(
            msg.sender,
            oldBaseDescriptionURI,
            newBaseDescriptionURI
        );
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IObservabilityEvents {
    /// > [[[[[[[[[[[ Factory events ]]]]]]]]]]]

    event CloneDeployed(
        address indexed factory,
        address indexed owner,
        address indexed clone
    );

    event TributarySet(
        address indexed factory,
        address indexed clone,
        address oldTributary,
        address indexed newTributary
    );

    event FactoryLimitSet(
        address indexed factory,
        uint256 oldLimit,
        uint256 newLimit
    );

    event FactoryGuardSet(bool guard);

    event FactoryImplementationSet(
        address indexed factory,
        address indexed oldImplementation,
        address indexed newImplementation
    );

    /// > [[[[[[[[[[[ Clone events ]]]]]]]]]]]

    event WritingEditionPurchased(
        address indexed clone,
        uint256 tokenId,
        address indexed recipient,
        uint256 price,
        string message
    );

    event Transfer(
        address indexed clone,
        address indexed from,
        address indexed to,
        uint256 tokenId
    );

    event RoyaltyChange(
        address indexed clone,
        address indexed oldRoyaltyRecipient,
        uint256 oldRoyaltyBPS,
        address indexed newRoyaltyRecipient,
        uint256 newRoyaltyBPS
    );

    event RendererSet(address indexed clone, address indexed renderer);

    event WritingEditionLimitSet(
        address indexed clone,
        uint256 oldLimit,
        uint256 newLimit
    );

    event PriceSet(address indexed clone, uint256 oldLimit, uint256 newLimit);

    event FundingRecipientSet(
        address indexed clone,
        address indexed oldFundingRecipient,
        address indexed newFundingRecipient
    );

    event BaseDescriptionURISet(
        address indexed clone,
        string oldBaseDescriptionURI,
        string newBaseDescriptionURI
    );
}

interface IObservability {
    function emitDeploymentEvent(address owner, address clone) external;

    function emitTributarySet(
        address clone,
        address oldTributary,
        address newTributary
    ) external;

    function emitFactoryGuardSet(bool guard) external;

    function emitFactoryImplementationSet(
        address oldImplementation,
        address newImplementation
    ) external;

    function emitFactoryLimitSet(uint256 oldLimit, uint256 newLimit) external;

    function emitTransferEvent(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function emitWritingEditionPurchased(
        uint256 tokenId,
        address recipient,
        uint256 price,
        string memory message
    ) external;

    function emitRoyaltyChange(
        address oldRoyaltyRecipient,
        uint256 oldRoyaltyBPS,
        address newRoyaltyRecipient,
        uint256 newRoyaltyBPS
    ) external;

    function emitRendererSet(address renderer) external;

    function emitWritingEditionLimitSet(uint256 oldLimit, uint256 newLimit)
        external;

    function emitFundingRecipientSet(
        address oldFundingRecipient,
        address newFundingRecipient
    ) external;

    function emitPriceSet(uint256 oldPrice, uint256 newPrice) external;

    function emitBaseDescriptionURISet(
        string memory oldBaseDescriptionURI,
        string memory newBaseDescriptionURI
    ) external;
}