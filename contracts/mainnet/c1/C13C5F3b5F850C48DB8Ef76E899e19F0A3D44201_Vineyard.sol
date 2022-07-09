// SPDX-License-Identifier: Viral Public License
/**
.___     .___ .______  ._______ ____   ____.______  .______  .______  
|   |___ : __|:      \ : .____/ \   \_/   /:      \ : __   \ :_ _   \ 
|   |   || : ||       || : _/\   \___ ___/ |   .   ||  \____||   |   |
|   :   ||   ||   |   ||   /  \    |   |   |   :   ||   :  \ | . |   |
 \      ||   ||___|   ||_.: __/    |___|   |___|   ||   |___\|. ____/ 
  \____/ |___|    |___|   :/                   |___||___|     :/      
                                                              :       
                                                                      
 */
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "./interfaces/IWineBottle.sol";
import "./interfaces/IRoyaltyManager.sol";
import "./interfaces/IVotableUri.sol";
import "./interfaces/IAddressStorage.sol";
import "./libraries/UriUtils.sol";

interface IGiveawayToken {
    function burnOne() external;
}

interface IMerkleDiscount {
    function claim(
        uint256 index,
        address account,
        bytes32[] calldata merkleProof
    ) external returns (bool);
}

contract Vineyard is ERC721, ERC2981 {
    IAddressStorage private addressStorage;
    address public deployer;
    uint256 public totalSupply;
    uint256 public immutable firstSeasonLength = 3 weeks;
    uint256 public immutable seasonLength = 12 weeks;
    uint256 public immutable maxVineyards = 5500;
    uint256 public gameStart;

    /// @dev attributes are
    /// location, elevation, isNegative, soil
    mapping(uint256 => uint16[]) private tokenAttributes;
    mapping(uint256 => uint256) public planted;
    mapping(uint256 => uint256) public watered;
    mapping(uint256 => uint256) public xp;
    mapping(uint256 => uint16) public streak;
    mapping(uint256 => uint256) public lastHarvested;
    mapping(uint256 => uint256) public sprinkler;

    string public baseUri;
    uint16 public immutable sellerFee = 750;

    uint16[3][15] private mintReqs;
    uint8[15] public climates;

    // EVENTS
    event VineyardMinted(
        uint256 tokenId,
        uint256 location,
        uint256 elevation,
        uint256 elevationNegative,
        uint256 soilType
    );
    event SprinklerPurchased(uint256 tokenId);
    event Start(uint48 timestamp);
    event Planted(uint256 tokenId, uint256 season);
    event Harvested(uint256 tokenId, uint256 season, uint256 bottleId);

    // CONSTRUCTOR
    constructor(
        string memory _baseUri,
        address _addressStorage,
        uint16[3][15] memory _mintReqs,
        uint8[15] memory _climates
    ) ERC721("Hash Valley Vineyard", "VNYD") {
        deployer = _msgSender();
        setBaseURI(_baseUri);
        addressStorage = IAddressStorage(_addressStorage);
        _setDefaultRoyalty(_msgSender(), 750);

        for (uint8 i = 0; i < _mintReqs.length; ++i) {
            mintReqs[i] = _mintReqs[i];
        }

        climates = _climates;
    }

    // called once to init royalties
    bool private inited;

    function initR() external {
        require(!inited, "!init");
        IRoyaltyManager(addressStorage.royaltyManager()).updateRoyalties(
            _msgSender()
        );
        inited = true;
    }

    function owner() public view returns (address) {
        return addressStorage.royaltyManager();
    }

    /// @notice validates minting attributes
    function validateAttributes(uint16[] calldata _tokenAttributes)
        public
        view
        returns (bool)
    {
        require(_tokenAttributes.length == 4, "wrong #params");
        require(_tokenAttributes[0] <= 14, "inv 1st param");
        uint256 lower = mintReqs[_tokenAttributes[0]][0];
        uint256 upper = mintReqs[_tokenAttributes[0]][1];
        require(
            _tokenAttributes[1] >= lower && _tokenAttributes[1] <= upper,
            "inv 2nd param"
        );
        require(
            _tokenAttributes[2] == 0 || _tokenAttributes[2] == 1,
            "inv 3rd param"
        );
        if (_tokenAttributes[2] == 1)
            require(mintReqs[_tokenAttributes[0]][2] == 1, "3rd cant be 1");
        require(_tokenAttributes[3] <= 5, "inv 4th param");
        return true;
    }

    // SALE
    /// @notice mints a new vineyard
    /// @param _tokenAttributes array of attribute ints [location, elevation, elevationIsNegative (0 or 1), soilType]
    function newVineyards(uint16[] calldata _tokenAttributes) public payable {
        // first 100 free
        if (totalSupply >= 100) {
            require(msg.value >= 0.07 ether, "Value below price");
        }

        _mintVineyard(_tokenAttributes, false);
    }

    /// @notice mints a new vineyard with discount
    /// @param _tokenAttributes array of attribute ints [location, elevation, elevationIsNegative (0 or 1), soilType]
    function newVineyardsDiscount(
        uint16[] calldata _tokenAttributes,
        uint256 index,
        bytes32[] calldata merkleProof
    ) public payable {
        require(totalSupply >= 100, "not yet");
        require(msg.value >= 0.04 ether, "Value below price");
        require(
            IMerkleDiscount(addressStorage.merkle()).claim(
                index,
                _msgSender(),
                merkleProof
            ),
            "invalid claim"
        );
        _mintVineyard(_tokenAttributes, false);
    }

    /// @notice mints a new vineyard for free by burning a giveaway token
    function newVineyardGiveaway(uint16[] calldata _tokenAttributes) public {
        IGiveawayToken(addressStorage.giveawayToken()).burnOne();
        _mintVineyard(_tokenAttributes, true);
    }

    /// @notice private vineyard minting function
    function _mintVineyard(uint16[] calldata _tokenAttributes, bool giveaway)
        private
    {
        uint256 tokenId = totalSupply;
        if (!giveaway) {
            require(tokenId < maxVineyards, "Max vineyards minted");
        }

        validateAttributes(_tokenAttributes);

        _safeMint(_msgSender(), tokenId);
        tokenAttributes[tokenId] = _tokenAttributes;
        totalSupply += 1;

        emit VineyardMinted(
            tokenId,
            _tokenAttributes[0],
            _tokenAttributes[1],
            _tokenAttributes[2],
            _tokenAttributes[3]
        );
    }

    /// @notice buys a sprinkler (lasts 3 years)
    function buySprinkler(uint256 _tokenId) public payable {
        require(
            sprinkler[_tokenId] + 156 weeks < block.timestamp,
            "already sprinkled"
        );
        require(msg.value >= 0.01 ether, "Value below price");
        sprinkler[_tokenId] = block.timestamp;

        emit SprinklerPurchased(_tokenId);
    }

    /// @notice returns token attributes array
    function getTokenAttributes(uint256 _tokenId)
        public
        view
        returns (uint16[] memory attributes)
    {
        attributes = tokenAttributes[_tokenId];
    }

    /// @notice returns token climate
    function getClimate(uint256 _tokenId) public view returns (uint8) {
        return climates[tokenAttributes[_tokenId][0]];
    }

    // LOGISTICS
    /// @notice marks game as started triggering the first planting season to begin
    function start() public {
        require(_msgSender() == deployer, "!deployer");
        require(gameStart == 0, "Game already started");
        gameStart = block.timestamp;
        emit Start(uint48(block.timestamp));
    }

    /// @notice withdraws sale proceeds
    function withdrawAll() public payable {
        require(_msgSender() == deployer, "!deployer");
        require(payable(_msgSender()).send(address(this).balance));
    }

    // GAME
    /// @notice returns current season number
    function currSeason() public view returns (uint256) {
        if (gameStart == 0) return 0;
        uint256 gameTime = block.timestamp - gameStart;
        if (gameTime <= firstSeasonLength) return 1;
        return (gameTime - firstSeasonLength) / seasonLength + 2;
    }

    /// @notice plants the selected vineyard
    function plant(uint256 _tokenId) public {
        require(plantingTime(), "Not planting time");
        uint256 season = currSeason();
        require(planted[_tokenId] != season, "Vineyard already planted");
        planted[_tokenId] = season;
        watered[_tokenId] = block.timestamp;
        emit Planted(_tokenId, planted[_tokenId]);
    }

    /// @notice plant multiple vineyards in one tx
    function plantMultiple(uint256[] calldata _tokenIds) public {
        for (uint8 i = 0; i < _tokenIds.length; i++) {
            plant(_tokenIds[i]);
        }
    }

    /// @notice harvests the selected vineyard
    function harvest(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == _msgSender(), "Not owner");
        require(harvestTime(), "Not harvest time");
        uint256 season = currSeason();
        require(planted[_tokenId] == season, "Vineyard already harvested");
        require(vineyardAlive(_tokenId), "Vineyard not alive");
        planted[_tokenId] = 0;

        if (lastHarvested[_tokenId] == season - 1) {
            streak[_tokenId] += 1;
        } else {
            streak[_tokenId] = 1;
        }
        lastHarvested[_tokenId] = season;
        xp[_tokenId] += 100 * streak[_tokenId];

        address wineBottle = addressStorage.bottle();
        uint256 bottleId = IWineBottle(wineBottle).newBottle(
            _tokenId,
            ownerOf(_tokenId)
        );
        emit Harvested(_tokenId, season, bottleId);
    }

    /// @notice harvest multiple vineyards in one tx
    function harvestMultiple(uint256[] calldata _tokenIds) public {
        for (uint8 i = 0; i < _tokenIds.length; i++) {
            harvest(_tokenIds[i]);
        }
    }

    /// @notice waters the selected vineyard
    function water(uint256 _tokenId) public {
        require(canWater(_tokenId), "Vineyard can't be watered");
        watered[_tokenId] = block.timestamp;
    }

    /// @notice water multiple vineyards in one tx
    function waterMultiple(uint256[] calldata _tokenIds) public {
        for (uint8 i = 0; i < _tokenIds.length; i++) {
            water(_tokenIds[i]);
        }
    }

    /// @notice min time before watering window opens
    function minWaterTime(uint256 _tokenId) public view returns (uint256) {
        uint256 sprinklerBreaks = sprinkler[_tokenId] + 156 weeks;
        if (sprinklerBreaks > block.timestamp) {
            return sprinklerBreaks - block.timestamp;
        }
        return 24 hours;
    }

    /// @notice window of time to water in
    function waterWindow(uint256 _tokenId) public pure returns (uint256) {
        if (_tokenId == 4 || _tokenId == 9 || _tokenId == 11) return 48 hours;
        return 24 hours;
    }

    /// @notice checks if vineyard is alive (planted and watered)
    function vineyardAlive(uint256 _tokenId) public view returns (bool) {
        if (planted[_tokenId] == currSeason()) {
            if (
                block.timestamp <=
                watered[_tokenId] +
                    minWaterTime(_tokenId) +
                    waterWindow(_tokenId)
            ) {
                return true;
            }
            return false;
        }
        return false;
    }

    // VIEWS
    /// @notice current harvest streak for vineyard
    function currentStreak(uint256 _tokenId) public view returns (uint16) {
        uint256 season = currSeason();
        if (season == 0) return 0;
        if (lastHarvested[_tokenId] >= currSeason() - 1) {
            return streak[_tokenId];
        }
        return 0;
    }

    /// @notice checks if vineyard can be watered
    function canWater(uint256 _tokenId) public view returns (bool) {
        uint256 _canWater = watered[_tokenId] + minWaterTime(_tokenId);
        return
            _canWater <= block.timestamp &&
            _canWater + waterWindow(_tokenId) >= block.timestamp;
    }

    /// @notice checks if its planting season
    function plantingTime() public view returns (bool) {
        if (gameStart == 0) return false;
        uint256 season = currSeason();
        uint256 plantingBegins;
        if (season == 1) plantingBegins = gameStart;
        else
            plantingBegins =
                gameStart +
                firstSeasonLength +
                (currSeason() - 2) *
                seasonLength;
        uint256 plantingEnds = plantingBegins + 1 weeks;
        return
            plantingEnds >= block.timestamp &&
            block.timestamp >= plantingBegins;
    }

    /// @notice checks if vineyard can be planted
    function canPlant(uint256 _tokenId) public view returns (bool) {
        return plantingTime() && planted[_tokenId] != currSeason();
    }

    /// @notice checks if it is harvesting season
    function harvestTime() public view returns (bool) {
        if (gameStart == 0) return false;
        uint256 season = currSeason();
        uint256 harvestEnds;
        if (season == 1) harvestEnds = gameStart + firstSeasonLength;
        else
            harvestEnds =
                gameStart +
                firstSeasonLength +
                (currSeason() - 1) *
                seasonLength;
        uint256 harvestBegins = harvestEnds - 1 weeks;
        return
            harvestEnds >= block.timestamp && block.timestamp >= harvestBegins;
    }

    /// @notice checks if vineyard can be harvested
    function canHarvest(uint256 _tokenId) public view returns (bool) {
        return
            harvestTime() &&
            planted[_tokenId] == currSeason() &&
            vineyardAlive(_tokenId);
    }

    // URI
    function setBaseURI(string memory _baseUri) public {
        require(_msgSender() == deployer, "!deployer");
        baseUri = _baseUri;
    }

    /// @notice returns metadata string for latest uri, royalty recipient settings
    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        uint16[] memory attr = tokenAttributes[_tokenId];

        string memory json = string.concat(
            string.concat(
                '{"name": "Hash Valley Winery Vineyard ',
                UriUtils.uint2str(_tokenId),
                '", "external_url": "',
                baseUri,
                "/vineyard/",
                UriUtils.uint2str(_tokenId),
                '", "image": "',
                IVotableUri(addressStorage.vineUri()).image(),
                "/",
                UriUtils.uint2str(attr[0]),
                '.png", "description": "Plant, tend and harvest this vineyard to grow your wine collection.", "animation_url": "'
            ),
            string.concat(
                IVotableUri(addressStorage.vineUri()).uri(),
                "?seed=",
                UriUtils.uint2str(attr[0]),
                "-",
                UriUtils.uint2str(attr[1]),
                "-",
                UriUtils.uint2str(attr[2]),
                "-",
                UriUtils.uint2str(attr[3]),
                "-",
                UriUtils.uint2str(xp[_tokenId]),
                '", ',
                '"seller_fee_basis_points": ',
                UriUtils.uint2str(sellerFee),
                ', "fee_recipient": "0x',
                UriUtils.toAsciiString(
                    IVotableUri(addressStorage.vineUri()).artist()
                )
            ),
            string.concat(
                '", "attributes": [',
                string.concat(
                    '{"trait_type": "Location", "value": "',
                    locationNames[attr[0]],
                    '"},'
                ),
                string.concat(
                    '{"trait_type": "Elevation", "value": "',
                    UriUtils.uint2str(attr[1]),
                    '"},'
                ),
                string.concat(
                    '{"trait_type": "Soil Type", "value": "',
                    soilNames[attr[3]],
                    '"},'
                ),
                string.concat(
                    '{"trait_type": "Xp", "value": "',
                    UriUtils.uint2str(xp[_tokenId]),
                    '"},'
                ),
                string.concat(
                    '{"trait_type": "Streak", "value": "',
                    UriUtils.uint2str(streak[_tokenId]),
                    '"},'
                ),
                string.concat(
                    '{"trait_type": "Sprinkler", "value": "',
                    sprinkler[_tokenId] + 156 weeks > block.timestamp
                        ? "true"
                        : "false",
                    '"}'
                ),
                "]"
            ),
            "}"
        );

        string memory output = string.concat(
            "data:application/json;base64,",
            UriUtils.encodeBase64((bytes(json)))
        );

        return output;
    }

    string[15] locationNames = [
        "Amsterdam",
        "Tokyo",
        "Napa Valley",
        "Denali",
        "Madeira",
        "Kashmere",
        "Outback",
        "Siberia",
        "Mt. Everest",
        "Amazon Basin",
        "Ohio",
        "Borneo",
        "Fujian Province",
        "Long Island",
        "Champagne"
    ];

    string[6] soilNames = ["Rocky", "Sandy", "Clay", "Boggy", "Peaty", "Mulch"];

    //ERC2981 stuff
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) public {
        require(
            _msgSender() == addressStorage.royaltyManager(),
            "!RoyaltyManager"
        );
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC2981, ERC721)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
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

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/common/ERC2981.sol)

pragma solidity ^0.8.0;

import "../../interfaces/IERC2981.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of the NFT Royalty Standard, a standardized way to retrieve royalty payment information.
 *
 * Royalty information can be specified globally for all token ids via {_setDefaultRoyalty}, and/or individually for
 * specific token ids via {_setTokenRoyalty}. The latter takes precedence over the first.
 *
 * Royalty is specified as a fraction of sale price. {_feeDenominator} is overridable but defaults to 10000, meaning the
 * fee is specified in basis points by default.
 *
 * IMPORTANT: ERC-2981 only specifies a way to signal royalty information and does not enforce its payment. See
 * https://eips.ethereum.org/EIPS/eip-2981#optional-royalty-payments[Rationale] in the EIP. Marketplaces are expected to
 * voluntarily pay royalties together with sales, but note that this standard is not yet widely supported.
 *
 * _Available since v4.5._
 */
abstract contract ERC2981 is IERC2981, ERC165 {
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    RoyaltyInfo private _defaultRoyaltyInfo;
    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @inheritdoc IERC2981
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) public view virtual override returns (address, uint256) {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[_tokenId];

        if (royalty.receiver == address(0)) {
            royalty = _defaultRoyaltyInfo;
        }

        uint256 royaltyAmount = (_salePrice * royalty.royaltyFraction) / _feeDenominator();

        return (royalty.receiver, royaltyAmount);
    }

    /**
     * @dev The denominator with which to interpret the fee set in {_setTokenRoyalty} and {_setDefaultRoyalty} as a
     * fraction of the sale price. Defaults to 10000 so fees are expressed in basis points, but may be customized by an
     * override.
     */
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    /**
     * @dev Sets the royalty information that all ids in this contract will default to.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: invalid receiver");

        _defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Removes default royalty information.
     */
    function _deleteDefaultRoyalty() internal virtual {
        delete _defaultRoyaltyInfo;
    }

    /**
     * @dev Sets the royalty information for a specific token id, overriding the global default.
     *
     * Requirements:
     *
     * - `tokenId` must be already minted.
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: Invalid parameters");

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Resets royalty information for the token id back to the global default.
     */
    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
    }
}

// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IWineBottle {
    function newBottle(uint256 _vineyard, address _owner)
        external
        returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function bottleAge(uint256 _tokenID) external view returns (uint256);
}

// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IRoyaltyManager {
    function updateRoyalties(address recipient) external;
}

// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IVotableUri {
    function artist() external view returns (address);

    function uri() external view returns (string memory);

    function image() external view returns (string memory);
}

// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IAddressStorage {
    function cellar() external view returns (address);

    function vinegar() external view returns (address);

    function vineyard() external view returns (address);

    function bottle() external view returns (address);

    function giveawayToken() external view returns (address);

    function royaltyManager() external view returns (address);

    function merkle() external view returns (address);

    function wineUri() external view returns (address);

    function vineUri() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title UriUtils
/// @author encodeBase64: Brecht Devos <[email protected]>
///         uint2str: Oraclize
///         toAsciiString: stackoverflow user tkeber
library UriUtils {
    /// @notice Converts a uint into a string
    function uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    bytes internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Provides a function for encoding some bytes in base64
    function encodeBase64(bytes memory data)
        internal
        pure
        returns (string memory)
    {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(input, 0x3F))), 0xFF)
                )
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }

    /// @notice converts address to string
    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (interfaces/IERC2981.sol)

pragma solidity ^0.8.0;

import "../utils/introspection/IERC165.sol";

/**
 * @dev Interface for the NFT Royalty Standard.
 *
 * A standardized way to retrieve royalty payment information for non-fungible tokens (NFTs) to enable universal
 * support for royalty payments across all NFT marketplaces and ecosystem participants.
 *
 * _Available since v4.5._
 */
interface IERC2981 is IERC165 {
    /**
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be paid in that same unit of exchange.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}