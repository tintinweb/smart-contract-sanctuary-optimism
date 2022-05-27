// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/// > [[[[[[[[[[[ Imports ]]]]]]]]]]]

import "./interface/IWritingEditions.sol";
import "./interface/IWritingEditionsFactory.sol";
import "../observability/interface/IObservability.sol";
import "../fee-configuration/interface/IFeeConfiguration.sol";
import "../renderer/interface/IRenderer.sol";
import "../treasury/interface/ITreasuryConfiguration.sol";
import "../treasury/interface/ITreasury.sol";
import "../treasury/interface/ITributaryRegistry.sol";
import "../lib/Ownable.sol";
import "../lib/ERC721/ERC721.sol";
import "../lib/ERC165/ERC165.sol";
import "../lib/ERC721/interface/IERC721.sol";
import "../lib/ERC2981/interface/IERC2981.sol";
import "../lib/transaction-reentrancy-guard/TransactionReentrancyGuard.sol";

/// > [[[[[[[[[[[ External Library Imports ]]]]]]]]]]]

import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/utils/Base64.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

/**
 * @title WritingEditions
 * @author MirrorXYZ
 * @custom:security-contact [email protected]
 */
contract WritingEditions is
    Ownable,
    TransactionReentrancyGuard,
    ReentrancyGuard,
    ERC721,
    IERC721Metadata,
    IERC2981,
    IWritingEditions,
    IWritingEditionEvents,
    IObservabilityEvents
{
    /// > [[[[[[[[[[[ Version ]]]]]]]]]]]

    /// @notice Version.
    uint8 public immutable override VERSION = 101;

    /// > [[[[[[[[[[[ Authorization ]]]]]]]]]]]

    /// @notice Address that deploys and initializes clones.
    address public immutable override factory;

    /// > [[[[[[[[[[[ Configuration ]]]]]]]]]]]

    /// @notice Address for Mirror treasury configuration.
    address public immutable override treasuryConfiguration;

    /// @notice Address for Mirror's observability contract.
    address public immutable override o11y;

    /// > [[[[[[[[[[[ ERC721 Metadata ]]]]]]]]]]]

    /// @notice Token name.
    string public override name;

    /// @notice Token symbol.
    string public override symbol;

    /// @notice Base URI for description.
    string internal _baseDescriptionURI;

    /// > [[[[[[[[[[[ Token Data ]]]]]]]]]]]

    /// @notice Total supply of editions. Used to calculate next tokenId.
    uint256 public override totalSupply;

    /// @notice Token text content, stored in Arweave.
    string public override contentURI;

    /// @notice Token image content, stored in IPFS.
    string public override imageURI;

    /// @notice Token price, set by the owner.
    uint256 public override price;

    /// @notice Token limit, set by the owner.
    uint256 public override limit;

    /// @notice Account that will receive funds from sales.
    address public override fundingRecipient;

    /// > [[[[[[[[[[[ Fees ]]]]]]]]]]]

    /// @notice Fee basis points paid if fees are on.
    uint16 public override fee;

    /// > [[[[[[[[[[[ Royalty Info (ERC2981) ]]]]]]]]]]]

    /// @notice Account that will receive royalties.
    address public override royaltyRecipient;

    /// @notice Royalty basis points.
    uint256 public override royaltyBPS;

    /// > [[[[[[[[[[[ Rendering ]]]]]]]]]]]

    /// @notice Address for a rendering contract, if set, calls to
    /// `tokenURI(uint256)` are forwarded to this address.
    address public override renderer;

    /// > [[[[[[[[[[[ Constructor ]]]]]]]]]]]

    /// @notice Implementation logic for clones.
    /// @param _factory the factory contract deploying clones with this implementation.
    /// @param _treasuryConfiguration Mirror treasury configuration.
    /// @param _o11y contract for observability.
    constructor(
        address _factory,
        address _treasuryConfiguration,
        address _o11y
    ) Ownable(address(0)) TransactionReentrancyGuard(true) {
        // Assert not the zero-address.
        require(_factory != address(0), "must set factory");

        // Store factory.
        factory = _factory;

        // Assert not the zero-address.
        require(
            _treasuryConfiguration != address(0),
            "must set treasury configuration"
        );

        // Store treasury configuration.
        treasuryConfiguration = _treasuryConfiguration;

        // Assert not the zero-address.
        require(_o11y != address(0), "must set observability");

        // Store observability.
        o11y = _o11y;
    }

    /// > [[[[[[[[[[[ Initializing ]]]]]]]]]]]

    /// @notice Initialize a clone by storing edition parameters. Called only
    /// by the factory. Mints the first edition to `tokenRecipient`.
    /// @param _owner owner of the clone.
    /// @param edition edition parameters used to deploy the clone.
    /// @param tokenRecipient account that will receive the first minted token.
    /// @param message message sent with the token purchase, not stored.
    function initialize(
        address _owner,
        WritingEdition memory edition,
        address tokenRecipient,
        string memory message,
        bool _guardOn
    ) external payable override nonReentrant {
        // Only factory can call this function.
        require(msg.sender == factory, "unauthorized caller");

        // Store ERC721 metadata.
        name = edition.name;
        symbol = edition.symbol;

        // Store edition data.
        imageURI = edition.imageURI;
        contentURI = edition.contentURI;
        price = edition.price;
        limit = edition.limit;
        fundingRecipient = edition.fundingRecipient;
        renderer = edition.renderer;

        // Store fee.
        _setFee(edition.fee);

        // Store owner.
        _setInitialOwner(_owner);

        // Store guard status.
        _setGuard(_guardOn);

        // Mint initial token to recipient, assuming
        // the correct value was sent through the factory
        if (tokenRecipient != address(0)) {
            _purchase(tokenRecipient, message);
        }
    }

    /// @notice Base description URI.
    function baseDescriptionURI()
        external
        view
        override
        returns (string memory)
    {
        return _getBaseDescriptionURI();
    }

    /// @notice Token description.
    function description() public view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    _getBaseDescriptionURI(),
                    Strings.toString(block.chainid),
                    "/",
                    _addressToString(address(this))
                )
            );
    }

    /// > [[[[[[[[[[[ View Functions ]]]]]]]]]]]

    /// @notice Helper function to get owners for a list of tokenIds.
    /// @dev Could revert if `tokenIds` is too long.
    /// @param tokenIds a list of token-ids to check ownership of.
    /// @return owners a list of token-id owners, address(0) if token is not minted
    function ownerOf(uint256[] memory tokenIds)
        external
        view
        override
        returns (address[] memory owners)
    {
        owners = new address[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            owners[i] = _owners[tokenIds[i]];
        }
    }

    /// > [[[[[[[[[[[ Funding Recipient ]]]]]]]]]]]

    /// @notice Set a new funding recipient.
    /// @param _fundingRecipient new funding recipient.
    function setFundingRecipient(address _fundingRecipient)
        external
        override
        onlyOwner
    {
        // slither-disable-next-line reentrancy-no-eth
        IObservability(o11y).emitFundingRecipientSet(
            // oldFundingRecipient
            fundingRecipient,
            // newFundingRecipient
            _fundingRecipient
        );

        fundingRecipient = _fundingRecipient;
    }

    /// > [[[[[[[[[[[ Price ]]]]]]]]]]]

    /// @notice Set a new price.
    /// @param _price new price.
    function setPrice(uint256 _price) external override onlyOwner {
        // slither-disable-next-line reentrancy-no-eth
        IObservability(o11y).emitPriceSet(
            // oldPrice
            price,
            // newPrice
            _price
        );

        price = _price;
    }

    /// @notice Set a new base description URI.
    /// @param newBaseDescriptionURI new base description URI
    function setBaseDescriptionURI(string memory newBaseDescriptionURI)
        external
        override
        onlyOwner
    {
        // slither-disable-next-line reentrancy-no-eth
        IObservability(o11y).emitBaseDescriptionURISet(
            // oldDescriptionURI
            _getBaseDescriptionURI(),
            // oldDescriptionURI
            newBaseDescriptionURI
        );

        _baseDescriptionURI = newBaseDescriptionURI;
    }

    /// @notice Turn Transaction Level Reentrancy Guard on/off.
    function toggleGuard() external override onlyOwner {
        _toggleGuard();
    }

    /// > [[[[[[[[[[[ Purchase ]]]]]]]]]]]

    /// @notice Purchase a token.
    /// @param tokenRecipient the account to receive the token.
    /// @param message an optional message during purchase, not stored.
    /// @return tokenId the id of the minted token.
    function purchase(address tokenRecipient, string memory message)
        external
        payable
        override
        guard
        nonReentrant
        returns (uint256 tokenId)
    {
        // Ensure enough value is sent.
        require(msg.value == price, "incorrect value");

        return _purchase(tokenRecipient, message);
    }

    /// @notice Purchase a token through the factory. Assumes balance checks
    /// were made in the factory.
    /// @param tokenRecipient the account to receive the token.
    /// @param message an optional message during purchase, not stored.
    /// @return tokenId the id of the minted token.
    function purchaseThroughFactory(
        address tokenRecipient,
        string memory message
    ) external payable override nonReentrant returns (uint256 tokenId) {
        // Ensure only factory calls.
        require(msg.sender == factory, "unauthorized");

        tokenId = _purchase(tokenRecipient, message);
    }

    /// > [[[[[[[[[[[ Mint ]]]]]]]]]]]

    /// @notice Mint an edition
    /// @dev throws if called by a non-owner
    /// @param tokenRecipient the account to receive the edition
    function mint(address tokenRecipient)
        external
        override
        onlyOwner
        returns (uint256 tokenId)
    {
        tokenId = _getTokenIdAndMint(tokenRecipient);
    }

    /// > [[[[[[[[[[[ Limit ]]]]]]]]]]]

    /// @notice Allows the owner to set a global limit on the total supply
    /// @dev throws if attempting to increase the limit
    /// @param newLimit new mint limit.
    function setLimit(uint256 newLimit) external override onlyOwner {
        // Enforce that the limit should only ever decrease once set.
        require(
            newLimit >= totalSupply && (limit == 0 || newLimit < limit),
            "limit must be < than current limit"
        );

        // Announce the change in limit.
        // slither-disable-next-line reentrancy-no-eth
        IObservability(o11y).emitWritingEditionLimitSet(
            // oldLimit
            limit,
            // newLimit
            newLimit
        );

        // Update the limit.
        limit = newLimit;
    }

    /// @notice Set the limit to the last minted tokenId.
    function setMaxLimit() external override onlyOwner {
        // Announce the change in limit.
        // slither-disable-next-line reentrancy-no-eth
        IObservability(o11y).emitWritingEditionLimitSet(
            // oldLimit
            limit,
            // newLimit
            totalSupply
        );

        // Update the limit.
        limit = totalSupply;
    }

    /// > [[[[[[[[[[[ ERC2981 Methods ]]]]]]]]]]]

    /// @notice Called with the sale price to determine how much royalty
    //  is owed and to whom
    /// @param _tokenId - the NFT asset queried for royalty information
    /// @param _salePrice - the sale price of the NFT asset specified by _tokenId
    /// @return receiver - address of who should be sent the royalty payment
    /// @return royaltyAmount - the royalty payment amount for _salePrice
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = _royaltyRecipient();

        royaltyAmount = (_salePrice * _royaltyBPS()) / 10_000;
    }

    /// @notice Get royalties information.
    /// @param royaltyRecipient_ the address that will receive royalties
    /// @param royaltyBPS_ the royalty amount in basis points (bps)
    function setRoyaltyInfo(
        address payable royaltyRecipient_,
        uint256 royaltyBPS_
    ) external override onlyOwner {
        require(
            royaltyBPS_ <= 10_000,
            "bps must be less than or equal to 10,000"
        );

        // slither-disable-next-line reentrancy-no-eth
        IObservability(o11y).emitRoyaltyChange(
            // oldRoyaltyRecipient
            _royaltyRecipient(),
            // oldRoyaltyBPS
            _royaltyBPS(),
            // newRoyaltyRecipient
            royaltyRecipient_,
            // newRoyaltyBPS
            royaltyBPS_
        );

        royaltyRecipient = royaltyRecipient_;
        royaltyBPS = royaltyBPS_;
    }

    /// > [[[[[[[[[[[ Rendering Methods ]]]]]]]]]]]

    /// @notice Set the renderer address
    /// @dev Throws if renderer is not the zero address
    /// @param _renderer contract responsible for rendering tokens.
    function setRenderer(address _renderer) external override onlyOwner {
        require(renderer == address(0), "renderer already set");

        renderer = _renderer;

        IObservability(o11y).emitRendererSet(
            // renderer
            _renderer
        );
    }

    /// @notice Get contract metadata
    /// @dev If a renderer is set, attempt return the renderer's metadata.
    function contractURI() external view override returns (string memory) {
        if (renderer != address(0)) {
            // slither-disable-next-line unused-return
            try IRenderer(renderer).contractURI() returns (
                // slither-disable-next-line uninitialized-local
                string memory result
            ) {
                return result;
            } catch {
                // Fallback if the renderer does not implement contractURI
                return _generateContractURI();
            }
        }

        return _generateContractURI();
    }

    /// @notice Get `tokenId` URI or data
    /// @dev If a renderer is set, call renderer's tokenURI
    /// @param tokenId The tokenId used to request data
    function tokenURI(uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "ERC721: query for nonexistent token");

        if (renderer != address(0)) {
            return IRenderer(renderer).tokenURI(tokenId);
        }

        // slither-disable-next-line uninitialized-local
        bytes memory editionNumber;
        if (limit != 0) {
            editionNumber = abi.encodePacked("/", Strings.toString(limit));
        }

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        _escapeQuotes(name),
                        " ",
                        Strings.toString(tokenId),
                        editionNumber,
                        '", "description": "',
                        _escapeQuotes(description()),
                        '", "content": "ar://',
                        contentURI,
                        '", "image": "ipfs://',
                        imageURI,
                        '", "attributes":[{ "trait_type": "Serial", "value": ',
                        Strings.toString(tokenId),
                        "}] }"
                    )
                )
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    /// > [[[[[[[[[[[ IERC165 Method ]]]]]]]]]]]

    /// @param interfaceId The interface identifier, as specified in ERC-165
    function supportsInterface(bytes4 interfaceId)
        public
        pure
        override
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC2981).interfaceId;
    }

    /// > [[[[[[[[[[[ Internal Functions ]]]]]]]]]]]

    function _generateContractURI() internal view returns (string memory) {
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        _escapeQuotes(name),
                        '", "description": "',
                        _escapeQuotes(description()),
                        '", "content": "ar://',
                        contentURI,
                        '", "image": "ipfs://',
                        imageURI,
                        '", "seller_fee_basis_points": ',
                        Strings.toString(_royaltyBPS()),
                        ', "fee_recipient": "',
                        _addressToString(_royaltyRecipient()),
                        '", "external_link": "',
                        _getBaseDescriptionURI(),
                        '"}'
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    /// @dev Emit a transfer event from observability contract.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        IObservability(o11y).emitTransferEvent(from, to, tokenId);
    }

    function _royaltyRecipient() internal view returns (address) {
        return
            royaltyRecipient == address(0)
                ? fundingRecipient
                : royaltyRecipient;
    }

    /// @dev The ternary expression below prevents from returning 0 as the
    /// royalty amount. To turn off royalties, we make the assumption that
    /// if the royaltyRecipient is set to address(0), the marketplace code
    /// will ignore the royalty amount.
    function _royaltyBPS() internal view returns (uint256) {
        return royaltyBPS == 0 ? 1000 : royaltyBPS;
    }

    function _purchase(address tokenRecipient, string memory message)
        internal
        returns (uint256 tokenId)
    {
        // Mint token, and get a tokenId.
        tokenId = _getTokenIdAndMint(tokenRecipient);

        // Emit event through observability contract.
        IObservability(o11y).emitWritingEditionPurchased(
            // tokenId
            tokenId,
            // recipient
            tokenRecipient,
            // price
            price,
            // message
            message
        );

        _withdraw(fundingRecipient, msg.value);
    }

    function _getFeeConfiguration() internal returns (address) {
        return ITreasuryConfiguration(treasuryConfiguration).feeConfiguration();
    }

    function _getTributaryRegistry() internal returns (address) {
        return
            ITreasuryConfiguration(treasuryConfiguration).tributaryRegistry();
    }

    /// @dev Withdraws `amount` to `fundsRecipient`. Sends fee to treasury
    // if fees are on.
    function _withdraw(address fundsRecipient, uint256 amount) internal {
        address feeConfiguration = _getFeeConfiguration();
        if (
            feeConfiguration != address(0) &&
            IFeeConfiguration(feeConfiguration).on()
        ) {
            // Calculate the fee on the current balance, using the fee percentage.
            uint256 feeAmount = _feeAmount(amount, fee);

            // If the fee is not zero, attempt to send it to the treasury.
            // If the treasury is not set, do not pay the fee.
            address treasury = ITreasuryConfiguration(treasuryConfiguration)
                .treasury();
            if (feeAmount != 0 && treasury != address(0)) {
                _sendEther(payable(treasury), feeAmount);

                // Transfer the remaining amount to the recipient.
                _sendEther(payable(fundsRecipient), amount - feeAmount);
            } else {
                _sendEther(payable(fundsRecipient), amount);
            }
        } else {
            _sendEther(payable(fundsRecipient), amount);
        }
    }

    function _sendEther(address payable recipient, uint256 amount) internal {
        // Ensure sufficient balance.
        require(address(this).balance >= amount, "insufficient balance");

        // Send the value.
        // slither-disable-next-line low-level-calls
        (bool success, ) = recipient.call{value: amount, gas: gasleft()}("");

        require(success, "recipient reverted");
    }

    function _feeAmount(uint256 amount, uint16 fee_)
        internal
        pure
        returns (uint256)
    {
        if (amount >= 10_000) {
            // Ignore warning since we check amount >= divisor
            // Hence no loss of precision.
            // slither-disable-next-line divide-before-multiply
            return (amount / 10_000) * fee_;
        }

        return 0;
    }

    /// @dev If fee is invalid, default to minimum fee.
    function _setFee(uint16 newFee) internal {
        address feeConfiguration = _getFeeConfiguration();

        fee = IFeeConfiguration(feeConfiguration).valid(newFee)
            ? newFee
            : IFeeConfiguration(feeConfiguration).minimumFee();
    }

    /// @dev Mints and returns tokenId
    function _getTokenIdAndMint(address tokenRecipient)
        internal
        returns (uint256 tokenId)
    {
        // Increment totalSupply to get next id and store tokenId.
        tokenId = ++totalSupply;

        // check that there are still tokens available to purchase
        // zero and max uint256 represent infinite minting
        require(
            limit == 0 || limit == type(uint256).max || tokenId < limit + 1,
            "sold out"
        );

        // mint a new token for the tokenRecipient, using the `tokenId`.
        _mint(tokenRecipient, tokenId);
    }

    function _getBaseDescriptionURI() internal view returns (string memory) {
        return
            bytes(_baseDescriptionURI).length == 0
                ? IWritingEditionsFactory(factory).baseDescriptionURI()
                : _baseDescriptionURI;
    }

    // https://ethereum.stackexchange.com/questions/8346/convert-address-to-string/8447#8447
    function _addressToString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = _char(hi);
            s[2 * i + 1] = _char(lo);
        }
        return string(abi.encodePacked("0x", s));
    }

    function _char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function _escapeQuotes(string memory str)
        internal
        pure
        returns (string memory)
    {
        bytes memory strBytes = bytes(str);
        uint8 quotesCount = 0;
        for (uint8 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] == '"') {
                quotesCount++;
            }
        }
        if (quotesCount > 0) {
            bytes memory escapedBytes = new bytes(
                strBytes.length + (quotesCount)
            );
            uint256 index;
            for (uint8 i = 0; i < strBytes.length; i++) {
                if (strBytes[i] == '"') {
                    escapedBytes[index++] = "\\";
                }
                escapedBytes[index++] = strBytes[i];
            }
            return string(escapedBytes);
        }
        return str;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IWritingEditionEvents {
    event RoyaltyChange(
        address indexed oldRoyaltyRecipient,
        uint256 oldRoyaltyBPS,
        address indexed newRoyaltyRecipient,
        uint256 newRoyaltyBPS
    );

    event RendererSet(address indexed renderer);

    event WritingEditionLimitSet(uint256 oldLimit, uint256 newLimit);

    event PriceSet(uint256 price);
}

interface IWritingEditions {
    struct WritingEdition {
        string name;
        string symbol;
        string description;
        string imageURI;
        string contentURI;
        uint256 price;
        uint256 limit;
        address fundingRecipient;
        address renderer;
        uint256 nonce;
        uint16 fee;
    }

    function VERSION() external view returns (uint8);

    function factory() external returns (address);

    function treasuryConfiguration() external returns (address);

    function o11y() external returns (address);

    function baseDescriptionURI() external view returns (string memory);

    function description() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function price() external view returns (uint256);

    function limit() external view returns (uint256);

    function contentURI() external view returns (string memory);

    function imageURI() external view returns (string memory);

    function fundingRecipient() external returns (address);

    function fee() external returns (uint16);

    function royaltyRecipient() external returns (address);

    function royaltyBPS() external returns (uint256);

    function renderer() external view returns (address);

    function ownerOf(uint256[] memory tokenIds)
        external
        view
        returns (address[] memory owners);

    function initialize(
        address owner_,
        WritingEdition memory edition,
        address recipient,
        string memory message,
        bool _guard
    ) external payable;

    function setFundingRecipient(address fundingRecipient_) external;

    function setPrice(uint256 price_) external;

    function setBaseDescriptionURI(string memory _baseDescriptionURI) external;

    function setLimit(uint256 limit_) external;

    function setMaxLimit() external;

    function setRoyaltyInfo(
        address payable royaltyRecipient_,
        uint256 royaltyPercentage_
    ) external;

    function toggleGuard() external;

    function purchase(address tokenRecipient, string memory message)
        external
        payable
        returns (uint256 tokenId);

    function purchaseThroughFactory(
        address tokenRecipient,
        string memory message
    ) external payable returns (uint256 tokenId);

    function mint(address tokenRecipient) external returns (uint256 tokenId);

    function setRenderer(address renderer_) external;

    function contractURI() external view returns (string memory);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/// > [[[[[[[[[[[ Imports ]]]]]]]]]]]

import "./IWritingEditions.sol";

interface IWritingEditionsFactoryEvents {
    event NewImplementation(
        address indexed oldImplementation,
        address indexed newImplementation
    );

    event EditionsDeployed(
        address indexed owner,
        address indexed clone,
        address indexed implementation
    );
}

interface IWritingEditionsFactory {
    function VERSION() external view returns (uint8);

    function implementation() external view returns (address);

    function o11y() external view returns (address);

    function treasuryConfiguration() external view returns (address);

    function guardOn() external view returns (bool);

    function salts(bytes32 salt) external view returns (bool);

    function maxLimit() external view returns (uint256);

    function DOMAIN_SEPARATOR() external returns (bytes32);

    function CREATE_TYPEHASH() external returns (bytes32);

    function baseDescriptionURI() external view returns (string memory);

    function predictDeterministicAddress(address implementation_, bytes32 salt)
        external
        view
        returns (address);

    function getSalt(
        address owner_,
        IWritingEditions.WritingEdition memory edition_
    ) external view returns (bytes32);

    function isValid(
        address owner_,
        bytes32 salt,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (bool);

    function setLimit(uint256 _maxLimit) external;

    function setGuard(bool _guardOn) external;

    function setImplementation(address _implementation) external;

    function create(IWritingEditions.WritingEdition memory edition_)
        external
        returns (address clone);

    function createWithSignature(
        address owner_,
        IWritingEditions.WritingEdition memory edition_,
        uint8 v,
        bytes32 r,
        bytes32 s,
        address recipient,
        string memory message
    ) external payable returns (address clone);

    function setTributary(address clone, address _tributary) external;

    function purchaseThroughFactory(
        address clone,
        address tokenRecipient,
        string memory message
    ) external payable returns (uint256 tokenId);
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

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IFeeConfigurationEvents {
    event FeeSwitch(bool on);

    event MinimumFee(uint16 fee);

    event MaximumFee(uint16 fee);
}

interface IFeeConfiguration {
    function on() external returns (bool);

    function maximumFee() external returns (uint16);

    function minimumFee() external returns (uint16);

    function switchFee() external;

    function updateMinimumFee(uint16 newFee) external;

    function updateMaximumFee(uint16 newFe) external;

    function valid(uint16) external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IRenderer {
    function tokenURI(uint256 tokenId) external view returns (string calldata);

    function contractURI() external view returns (string calldata);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ITreasuryConfigurationEvents {
    event TreasurySet(address indexed treasury, address indexed newTreasury);

    event TributaryRegistrySet(
        address indexed tributaryRegistry,
        address indexed newTributaryRegistry
    );

    event DistributionSet(
        address indexed distribution,
        address indexed newDistribution
    );

    event FeeConfigurationSet(
        address indexed feeConfiguration,
        address indexed newFeeConfiguration
    );
}

interface ITreasuryConfiguration {
    function treasury() external returns (address payable);

    function tributaryRegistry() external returns (address);

    function distribution() external returns (address);

    function feeConfiguration() external returns (address);

    function setTreasury(address payable newTreasury) external;

    function setTributaryRegistry(address newTributaryRegistry) external;

    function setDistribution(address newDistribution) external;

    function setFeeConfiguration(address newFeeConfiguration) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ITreasuryEvents {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event ERC20Transfer(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount
    );

    event ERC721Transfer(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 tokenId
    );
}

interface ITreasury {
    struct Call {
        // The target of the transaction.
        address target;
        // The value passed into the transaction.
        uint96 value;
        // Any data passed with the call.
        bytes data;
    }

    function treasuryConfiguration() external view returns (address);

    function transferFunds(address payable to, uint256 value) external;

    function transferERC20(
        address token,
        address to,
        uint256 value
    ) external;

    function transferERC721(
        address token,
        address from,
        address to,
        uint256 tokenId
    ) external;

    function contributeWithTributary(address tributary) external payable;

    function contribute(uint256 amount) external payable;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ITributaryRegistry {
    function allowedRegistrar(address account) external view returns (bool);

    function producerToTributary(address producer)
        external
        view
        returns (address tributary);

    function singletonProducer(address producer) external view returns (bool);

    function addRegistrar(address registrar) external;

    function removeRegistrar(address registrar) external;

    function addSingletonProducer(address producer) external;

    function removeSingletonProducer(address producer) external;

    function setTributary(address producer, address newTributary) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IOwnableEvents {
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
}

interface IOwnable {
    function transferOwnership(address nextOwner_) external;

    function cancelOwnershipTransfer() external;

    function acceptOwnership() external;

    function renounceOwnership() external;

    function isOwner() external view returns (bool);

    function isNextOwner() external view returns (bool);
}

contract Ownable is IOwnable, IOwnableEvents {
    address public owner;
    address private nextOwner;

    /// > [[[[[[[[[[[ Modifiers ]]]]]]]]]]]

    modifier onlyOwner() {
        require(isOwner(), "caller is not the owner.");
        _;
    }

    modifier onlyNextOwner() {
        require(isNextOwner(), "current owner must set caller as next owner.");
        _;
    }

    /// @notice Initialize contract by setting the initial owner.
    constructor(address owner_) {
        _setInitialOwner(owner_);
    }

    /// @notice Initiate ownership transfer by setting nextOwner.
    function transferOwnership(address nextOwner_) external override onlyOwner {
        require(nextOwner_ != address(0), "Next owner is the zero address.");

        nextOwner = nextOwner_;
    }

    /// @notice Cancel ownership transfer by deleting nextOwner.
    function cancelOwnershipTransfer() external override onlyOwner {
        delete nextOwner;
    }

    /// @notice Accepts ownership transfer by setting owner.
    function acceptOwnership() external override onlyNextOwner {
        delete nextOwner;

        owner = msg.sender;

        emit OwnershipTransferred(owner, msg.sender);
    }

    /// @notice Renounce ownership by setting owner to zero address.
    function renounceOwnership() external override onlyOwner {
        _renounceOwnership();
    }

    /// @notice Returns true if the caller is the current owner.
    function isOwner() public view override returns (bool) {
        return msg.sender == owner;
    }

    /// @notice Returns true if the caller is the next owner.
    function isNextOwner() public view override returns (bool) {
        return msg.sender == nextOwner;
    }

    /// > [[[[[[[[[[[ Internal Functions ]]]]]]]]]]]

    function _setOwner(address previousOwner, address newOwner) internal {
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, owner);
    }

    function _setInitialOwner(address newOwner) internal {
        owner = newOwner;
        emit OwnershipTransferred(address(0), newOwner);
    }

    function _renounceOwnership() internal {
        emit OwnershipTransferred(owner, address(0));

        owner = address(0);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./interface/IERC721.sol";
import "../ERC165/ERC165.sol";

/**
 * Based on: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol
 */
contract ERC721 is ERC165, IERC721, IERC721Events {
    mapping(uint256 => address) internal _owners;
    mapping(address => uint256) internal _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function balanceOf(address owner)
        external
        view
        virtual
        override
        returns (uint256)
    {
        require(
            owner != address(0),
            "ERC721: balance query for the zero address"
        );
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) external view virtual returns (address) {
        return _ownerOf(tokenId);
    }

    function _ownerOf(uint256 tokenId) internal view returns (address) {
        address owner = _owners[tokenId];
        require(
            owner != address(0),
            "ERC721: owner query for nonexistent token"
        );
        return owner;
    }

    function approve(address to, uint256 tokenId) external virtual override {
        address owner = _ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        require(
            _exists(tokenId),
            "ERC721: approved query for nonexistent token"
        );

        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved)
        external
        virtual
        override
    {
        require(operator != msg.sender, "ERC721: approve to caller");

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external virtual override {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external virtual override {
        _safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) external virtual override {
        _safeTransferFrom(from, to, tokenId, _data);
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        _safeTransfer(from, to, tokenId, _data);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        virtual
        returns (bool)
    {
        require(
            _exists(tokenId),
            "ERC721: operator query for nonexistent token"
        );
        address owner = _ownerOf(tokenId);
        return (spender == owner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owner, spender));
    }

    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual {
        address owner = _ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(
            _ownerOf(tokenId) == from,
            "ERC721: transfer of token that is not own"
        );
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(_ownerOf(tokenId), to, tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.code.length > 0) {
            // slither-disable-next-line unused-return
            try
                IERC721Receiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    _data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    // solhint-disable-next-line no-inline-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

abstract contract ERC165 is IERC165 {
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

interface IERC721Events {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );
}

interface IERC721Metadata {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function tokenURI(uint256 tokenId) external view returns (string memory);
}

interface IERC721Burnable is IERC721 {
    function burn(uint256 tokenId) external;
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

interface IERC721Royalties {
    function getFeeRecipients(uint256 id)
        external
        view
        returns (address payable[] memory);

    function getFeeBps(uint256 id) external view returns (uint256[] memory);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title IERC2981
 * @notice Interface for the NFT Royalty Standard
 */
interface IERC2981 {
    // / bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a

    /**
     * @notice Called with the sale price to determine how much royalty
     *         is owed and to whom.
     * @param _tokenId - the NFT asset queried for royalty information
     * @param _salePrice - the sale price of the NFT asset specified by _tokenId
     * @return receiver - address of who should be sent the royalty payment
     * @return royaltyAmount - the royalty payment amount for _salePrice
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title TransactionReentrancyGuard
 * @notice Transaction level reentrancy guard, used to prevent calling a
 * function multiple times in the same transaction, e.g. minting a token
 * using a multicall contract. The guard accesses a storage variable twice
 * and compares the gas used, taking advantage of EIP-2929 cold/warm storage
 * read costs.
 *
 * From EIP-2929: Gas cost increases for state access opcodes:
 *     "For SLOAD, if the (address, storage_key) pair (where address
 *     is the address of the contract whose storage is being read) is not yet
 *     in accessed_storage_keys, charge COLD_SLOAD_COST gas and add the pair
 *     to accessed_storage_keys. If the pair is already in accessed_storage_keys,
 *     charge WARM_STORAGE_READ_COST gas."
 *
 * Implementation was forked from bertani.eth, after a thread involving these
 * anon solidity giga-brains: [at]rage_pit, [at]transmissions11, 0age.eth.
 */
contract TransactionReentrancyGuard {
    bool public guardOn;

    uint256 internal GUARD = 1;

    /// > [[[[[[[[[[[ Modifiers ]]]]]]]]]]]
    modifier guard() {
        // If guard is on, run guard.
        if (guardOn) {
            _guard();
        }
        _;
    }

    constructor(bool _guardOn) {
        _setGuard(_guardOn);
    }

    function _guard() internal view {
        // Store current gas left.
        uint256 t0 = gasleft();

        // Load GUARD from storage.
        uint256 g = GUARD;

        // Store current gas left.
        uint256 t1 = gasleft();

        // Load GUARD from storage.
        uint256 m = GUARD;

        // Assert the cost of acessing `g` is greater than the
        // cost of accessing `m`, which implies the first SLOAD
        // was charged COLD_SLOAD_COST and the second SLOAD was
        // charged WARM_STORAGE_READ_COST. Hence this is the first
        // time the function has been called.
        require(t1 - gasleft() < t0 - t1);
    }

    function _toggleGuard() internal {
        _setGuard(!guardOn);
    }

    function _setGuard(bool _guardOn) internal {
        guardOn = _guardOn;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Base64.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides a set of functions to operate with Base64 strings.
 *
 * _Available since v4.5._
 */
library Base64 {
    /**
     * @dev Base64 Encoding/Decoding Table
     */
    string internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /**
     * @dev Converts a `bytes` to its Bytes64 `string` representation.
     */
    function encode(bytes memory data) internal pure returns (string memory) {
        /**
         * Inspired by Brecht Devos (Brechtpd) implementation - MIT licence
         * https://github.com/Brechtpd/base64/blob/e78d9fd951e7b0977ddca77d92dc85183770daf4/base64.sol
         */
        if (data.length == 0) return "";

        // Loads the table into memory
        string memory table = _TABLE;

        // Encoding takes 3 bytes chunks of binary data from `bytes` data parameter
        // and split into 4 numbers of 6 bits.
        // The final Base64 length should be `bytes` data length multiplied by 4/3 rounded up
        // - `data.length + 2`  -> Round up
        // - `/ 3`              -> Number of 3-bytes chunks
        // - `4 *`              -> 4 characters for each chunk
        string memory result = new string(4 * ((data.length + 2) / 3));

        assembly {
            // Prepare the lookup table (skip the first "length" byte)
            let tablePtr := add(table, 1)

            // Prepare result pointer, jump over length
            let resultPtr := add(result, 32)

            // Run over the input, 3 bytes at a time
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {

            } {
                // Advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // To write each character, shift the 3 bytes (18 bits) chunk
                // 4 times in blocks of 6 bits for each character (18, 12, 6, 0)
                // and apply logical AND with 0x3F which is the number of
                // the previous character in the ASCII table prior to the Base64 Table
                // The result is then added to the table to get the character to write,
                // and finally write it in the result pointer but with a left shift
                // of 256 (1 byte) - 8 (1 ASCII char) = 248 bits

                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }

            // When data `bytes` is not exactly 3 bytes long
            // it is padded with `=` characters at the end
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}