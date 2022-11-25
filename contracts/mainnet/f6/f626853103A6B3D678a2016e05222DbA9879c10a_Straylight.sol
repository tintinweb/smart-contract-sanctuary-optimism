//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./metadata.sol";
import "./EnumerableMate.sol";

//                           STRAYLIGHT PROTOCOL v.01
//
//                                .         .
//                                  ., ... .,
//                                  \%%&%%&./
//                         ,,.      /@&&%&&&\     ,,
//                            *,   (##%&&%##)  .*.
//                              (,  (#%%%%.)   %,
//                               ,% (#(##(%.(/
//                                 %((#%%%##*
//                 ..**,*/***///*,..,#%%%%*..,*\\\***\*,**..
//                                   /%#%%
//                              /###(/%&%/(##%(,
//                           ,/    (%###%%&%,   **
//                         .#.    *@&%###%%&)     \\
//                        /       *&&%###%&@#       *.
//                      ,*         (%#%###%#?)       .*.
//                                 ./%%###%%#,
//                                  .,(((##,.
//
//

/// @title Straylight
/// @notice The main point of interaction for Straylight - relies on Gamboard, Metadata, Turmitesv4 and EnumerableMate
/// @author @brachlandberlin / plsdlr.net
/// @dev facilitates minting, moving of individual turmites, reprogramming and even external logic of turmites and overwrites tokenUri()

contract Straylight is EnumerableMate, Metadata {
    event TurmiteReprogramm(uint256 indexed tokenId, bytes12 indexed newrule);
    event TurmiteMint(uint256 indexed tokenId, bytes12 indexed rule, uint256 boardId);

    uint256 public boardcounter = 0;
    uint256 private turmitecounter = 0;
    uint256 public maxnumbturmites;
    uint256[4] startx = [36, 72, 72, 108];
    uint256[4] starty = [72, 36, 108, 72];
    address minterContract;
    address haecceityContract;
    address admin;
    mapping(uint256 => bool) public haecceity;

    constructor(
        address _minterContract,
        uint256 maxAmount,
        string memory network
    ) Metadata(network) EnumerableMate("Straylight", "STR") {
        minterContract = _minterContract;
        maxnumbturmites = maxAmount;
        admin = msg.sender;
    }

    /// @dev public Mint function should only be called from external Minter Contract
    /// @param mintTo the address the token should be minted to
    /// @param rule the inital rule the turmite is minted with
    /// @param moves the inital number of rules the turmite is minted with
    function publicmint(
        address mintTo,
        bytes12 rule,
        uint256 moves
    ) external {
        require(turmitecounter < maxnumbturmites, "MINT_OVER");
        require(validateNewRule(rule) == true, "INVALID_RULE");
        require(msg.sender == minterContract, "ONLY_MINTABLE_FROM_MINT_CONTRACT");

        boardcounter = (turmitecounter / 4) + 1;
        uint256 startposx = startx[turmitecounter % 4];
        uint256 startposy = starty[turmitecounter % 4];
        _addTokenToOwnerEnumeration(mintTo, turmitecounter);
        _addTokenToAllTokensEnumeration(turmitecounter);
        _mint(mintTo, turmitecounter);
        createTurmite(turmitecounter, uint8(startposx), uint8(startposy), 1, uint8(boardcounter), rule);
        emit TurmiteMint(turmitecounter, rule, boardcounter);
        if (moves > 0) {
            calculateTurmiteMove(turmitecounter, moves);
        }
        haecceity[turmitecounter] = false;
        turmitecounter = turmitecounter + 1;
    }

    /// @dev overwrites the tokenURI function from ERC721 Solmate
    /// @param id the id of the NFT
    function tokenURI(uint256 id) public view override returns (string memory) {
        return
            fullMetadata(
                id,
                turmites[id].boardnumber,
                turmites[id].rule,
                turmites[id].state,
                turmites[id].turposx,
                turmites[id].turposy,
                turmites[id].orientation
            );
    }

    /// @dev helper Function to render board without turmites
    /// @param number Board number
    function renderBoard(uint8 number) public view returns (string memory) {
        return getSvg(number, 0, 0, false);
    }

    function moveTurmite(uint256[2] calldata idmoves) external {
        require(msg.sender == ownerOf(idmoves[0]), "NOT_AUTHORIZED");
        if (idmoves[1] > 0) {
            calculateTurmiteMove(idmoves[0], idmoves[1]);
        }
    }

    /// @dev function to validate that an new input from user is in the "gramma" of the rules
    /// @param rule a bytes12 rule - to understand the specific gramma of rules take a look at turmitev4 contract
    function validateNewRule(bytes12 rule) public pure returns (bool allowed) {
        //Normal Format Example: 0xff0801ff0201ff0000000001
        //we dont test against direction bc direction never writes
        //bool firstbit = (rule[0] == 0xFF || rule[0] == 0x00);
        //bool secondbit = (rule[3] == 0xFF || rule[3] == 0x00);
        bool colorfieldbit = ((rule[0] == 0xFF || rule[0] == 0x00) &&
            (rule[3] == 0xFF || rule[3] == 0x00) &&
            (rule[6] == 0xFF || rule[6] == 0x00) &&
            (rule[9] == 0xFF || rule[9] == 0x00));
        bool statebit = ((rule[2] == 0x01 || rule[2] == 0x00) &&
            (rule[5] == 0x01 || rule[5] == 0x00) &&
            (rule[8] == 0x01 || rule[8] == 0x00) &&
            (rule[11] == 0x01 || rule[11] == 0x00));
        return bool(statebit && colorfieldbit);
    }

    /// @notice WE EXPECT THAT YOU KNOW WHAT YOU ARE DOING BEFORE CALLING THIS FUNCTION MANUALY
    /// @notice PLEASE CONSULT THE DOCUMENTATION
    /// @dev function to reprogramm your turmite | DANGERZONE | if you don't use the interface consult the documentation before wasting gas
    /// @param id ID of the turmite
    /// @param rule a bytes12 rule - to understand the specific gramma of rules take a look at turmitev4 contract
    function reprogrammTurmite(uint256 id, bytes12 rule) external {
        require(msg.sender == ownerOf(id), "NOT_AUTHORIZED");
        require(validateNewRule(rule) == true, "INVALID_RULE");
        turmites[id].rule = rule;
        emit TurmiteReprogramm(id, rule);
    }

    /// @dev function for the admin to set external HA Contract
    /// @param _haecceityContract address of contract
    function setHaecceityContract(address _haecceityContract) external {
        require(msg.sender == admin, "NOT_AUTHORIZED");
        haecceityContract = _haecceityContract;
    }

    /// @dev get the position(x and y values) and the state of the current field for a turmite (all handy encoded)
    /// @param id the id of the token / turmite
    function getPosField(uint256 id) public view returns (bytes memory encodedData) {
        bytes32 sour;
        uint8 _x;
        uint8 _y;
        bytes memory data = new bytes(32);
        turmite storage dataTurmite = turmites[id];
        assembly {
            sour := sload(dataTurmite.slot)
            _x := and(sour, 0xFF)
            _y := and(shr(8, sour), 0xFF)
        }
        bytes1 stateOfField = getByte(_x, _y, (id / 4) + 1);
        assembly {
            mstore8(add(data, 32), _x)
            mstore8(add(data, 33), _y)
            mstore(add(data, 34), stateOfField)
        }
        return (data);
    }

    //  _   _   _____          _   _  _____ ______ _____   __________  _   _ ______   _   _
    // | | | | |  __ \   /\   | \ | |/ ____|  ____|  __ \ |___  / __ \| \ | |  ____| | | | |
    // | | | | | |  | | /  \  |  \| | |  __| |__  | |__) |   / / |  | |  \| | |__    | | | |
    // | | | | | |  | |/ /\ \ | . ` | | |_ |  __| |  _  /   / /| |  | | . ` |  __|   | | | |
    // |_| |_| | |__| / ____ \| |\  | |__| | |____| | \ \  / /_| |__| | |\  | |____  |_| |_|
    // (_) (_) |_____/_/    \_\_| \_|\_____|______|_|  \_\/_____\____/|_| \_|______| (_) (_)

    /// @notice WE EXPECT THAT YOU KNOW WHAT YOU ARE DOING BEFORE CALLING THIS FUNCTION
    /// @notice PLEASE CONSULT THE DOCUMENTATION
    /// @dev should be called by user to unlock external control
    /// @param id the id of the token / turmite the user what to hand logic control over to external smart contract
    function setHaecceityMode(uint256 id) external {
        require(haecceityContract != address(0), "CONTRACT_IS_ZEROADDRESS");
        require(msg.sender == ownerOf(id), "NOT_AUTHORIZED");
        haecceity[id] = true;
    }

    /// @dev internal deocde function
    ///  @param data data to decode
    function decode(bytes memory data)
        internal
        pure
        returns (
            uint8 x,
            uint8 y,
            bytes1 field
        )
    {
        assembly {
            x := mload(add(data, 1))
            y := mload(add(data, 2))
            field := mload(add(data, 34))
        }
    }

    /// @notice WE EXPECT THAT YOU KNOW WHAT YOU ARE DOING BEFORE CALLING THIS FUNCTION
    /// @notice PLEASE CONSULT THE DOCUMENTATION
    /// @dev function should be called by external haecceity Contract which allows external control of turmites by user deployed smart contracts
    /// @dev this function sets the field
    /// @param id the id of the turmite
    /// @param data the encoded data of the next step
    function setByteHaMode(uint256 id, bytes calldata data) external {
        require(haecceityContract != address(0), "CONTRACT_IS_ZEROADDRESS");
        require(haecceity[id] == true, "CONTRACT_NOT_INITALIZED_BY_NFT_OWNER");
        require(msg.sender == haecceityContract, "CALL_ONLY_FROM_HACONTRACT");
        (uint8 x, uint8 y, bytes1 stateOfField) = decode(data);
        setByte(x, y, stateOfField, turmites[id].boardnumber);
    }

    /// @notice WE EXPECT THAT YOU KNOW WHAT YOU ARE DOING BEFORE CALLING THIS FUNCTION
    /// @notice PLEASE CONSULT THE DOCUMENTATION
    /// @dev function should be called by external haecceity Contract which allows external control of turmites by user deployed smart contracts
    /// @dev this function sets the end position after moving
    /// @param id the id of the turmite
    /// @param data the encoded data of the position
    function setPositionHaMode(uint256 id, bytes calldata data) external {
        require(haecceityContract != address(0), "CONTRACT_IS_ZEROADDRESS");
        require(haecceity[id] == true, "CONTRACT_NOT_INITALIZED_BY_NFT_OWNER");
        require(msg.sender == haecceityContract, "CALL_ONLY_FROM_HACONTRACT");
        (uint8 x, uint8 y, ) = decode(data);
        turmites[id].turposx = x;
        turmites[id].turposy = y;
    }

    /// @dev overwriting transfer functions to add extension from here

    /// @notice after every transfer we reset the permission for external control
    /// @dev resets permission after every transfer
    function _transferResetHAMode(uint256 tokenId) internal {
        if (haecceity[tokenId] == true) {
            haecceity[tokenId] = false;
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        _transferResetHAMode(tokenId);
        _removeTokenFromOwnerEnumeration(from, tokenId);
        _addTokenToOwnerEnumeration(to, tokenId);
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        _transferResetHAMode(tokenId);
        _removeTokenFromOwnerEnumeration(from, tokenId);
        _addTokenToOwnerEnumeration(to, tokenId);
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) public virtual override {
        _transferResetHAMode(tokenId);
        _removeTokenFromOwnerEnumeration(from, tokenId);
        _addTokenToOwnerEnumeration(to, tokenId);
        super.safeTransferFrom(from, to, tokenId, data);
    }
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./turmitev4.sol";
import "solady/src/utils/LibString.sol";

/// @title Metadata
/// @notice Renders the dynamic metadata of every NFT via the Turmite v4.
/// @author @brachlandberlin / plsdlr.net
/// @dev Generates the metadata as JSON String and encodes it with base64 and data:application/json;base64,

contract Metadata is Turmite {
    string private network;

    constructor(string memory _network) {
        network = _network;
    }

    /// @dev generates the dynamic metadata
    /// @param tokenId the tokenId of the Turmite
    /// @param boardNumber the Board Number
    /// @param rule the rule of the turmite
    /// @param state current state
    /// @param turposx x position of the turmite
    /// @param turposy y position of the turmite
    /// @param orientation orientation of the turmite
    function fullMetadata(
        uint256 tokenId,
        uint8 boardNumber,
        bytes12 rule,
        bytes1 state,
        uint8 turposx,
        uint8 turposy,
        uint8 orientation
    ) internal view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            '{"name":"',
                            generateName(tokenId, boardNumber),
                            '", "description":"',
                            "Onchain Mutiplayer Art",
                            '", "image": "',
                            getSvg(boardNumber, turposx, turposy, true),
                            '",',
                            '"attributes": ',
                            generateAttributes(boardNumber, rule, state, turposx, turposy, orientation),
                            "}"
                        )
                    )
                )
            );
    }

    /// @dev generates the Name of the turmite as a string
    /// @param tokenId the tokenId of the Turmite
    /// @param boardNumber the Board Number
    function generateName(uint256 tokenId, uint8 boardNumber) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked("Turmite ", LibString.toString(tokenId), " World ", LibString.toString(boardNumber))
            );
    }

    /// @dev generates the dynamic attributes as JSON String, for param see fullMetadata()
    function generateAttributes(
        uint8 boardNumber,
        bytes12 rule,
        bytes1 state,
        uint8 turposx,
        uint8 turposy,
        uint8 orientation
    ) internal view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '[{"trait_type":"World","value":"',
                    LibString.toString(boardNumber),
                    '"},',
                    '{"trait_type":"Rule",',
                    '"value":"',
                    bytes12ToString(rule),
                    '"},',
                    '{"trait_type":"State",',
                    '"value":"',
                    LibString.toString(uint8(state)),
                    '"},',
                    '{"trait_type":"POS X",',
                    '"value":"',
                    LibString.toString(turposx),
                    '"},',
                    '{"trait_type":"POS Y",',
                    '"value":"',
                    LibString.toString(turposy),
                    '"},',
                    '{"trait_type":"Direction",',
                    '"value":"',
                    LibString.toString(orientation),
                    '"},{"trait_type":"Network","value":"',
                    network,
                    '"}]'
                )
            );
    }

    /// @dev helper function to create a String from a byte12
    /// @param _bytes12 the input value
    function bytes12ToString(bytes12 _bytes12) internal pure returns (string memory) {
        uint8 i = 0;
        bytes memory bytesArray = new bytes(24);
        for (i = 0; i < bytesArray.length; i++) {
            uint8 _f = uint8(_bytes12[i / 2] & 0x0f);
            uint8 _l = uint8(_bytes12[i / 2] >> 4);

            bytesArray[i] = toByte(_l);
            i = i + 1;
            bytesArray[i] = toByte(_f);
        }
        return string(bytesArray);
    }

    /// @dev helper function to convert from uint8 to byte1
    /// @param _uint8 the input value
    function toByte(uint8 _uint8) internal pure returns (bytes1) {
        if (_uint8 < 10) {
            return bytes1(_uint8 + 48);
        } else {
            return bytes1(_uint8 + 87);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@rari-capital/solmate/src/tokens/ERC721.sol";

/// @title EnumerableMate
/// @notice slightly reduced version of ERC721Enumerable.sol - mainly optimizing the transfer function
/// @author @brachlandberlin / plsdlr.net
/// @author OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/extensions/IERC721Enumerable.sol)
/// @dev Comments are mostly taken over from OpenZeppelin

abstract contract EnumerableMate is ERC721 {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    constructor(string memory name, string memory s) ERC721(name, s) {}

    /// getter
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual returns (uint256) {
        require(index < EnumerableMate.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) internal {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    function _addTokenToAllTokensEnumeration(uint256 tokenId) internal {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) internal {
        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) internal {
        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];
        uint256 lastTokenId = _allTokens[lastTokenIndex];
        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./gameboard.sol";

/// @title Turmite v4
/// @notice Implementation of Turmite logic for Straylight Protocoll.
/// @author @brachlandberlin / plsdlr.net
/// @dev Every Turmite rule is for simplicity represented as 12 Bytes. For easy acess by render functions all individual turmite data is safed in an struct.

contract Turmite is Gameboard {
    // using Base64 for string;    //note what is this used for?

    mapping(uint256 => turmite) public turmites;

    event TurmiteMove(uint256 indexed tokenId, uint8 indexed boardnumber, uint256 indexed moves);

    /// @dev individual slot for every turmite
    // Layout from Example:
    // _____________________________________________________________________________________________________
    // Empty Space :)                   Rule                     State  Boardnumber  Orientation   Y     X
    // _____________________________________________________________________________________________________
    // 0x000000000000000000000000000000 ff0801ff0201ff0000000001 01     01           01            32    3a
    // _____________________________________________________________________________________________________
    //
    struct turmite {
        uint8 turposx;
        uint8 turposy;
        uint8 orientation;
        uint8 boardnumber;
        bytes1 state;
        bytes12 rule;
    }

    /// @dev grammar for the rules
    // Layout from example rule
    // Rule:
    // _________________________________________________
    // ff0801ff0201ff0000000001                            2 states / 4 rulessegments
    // _________________________________________________
    // | ff0801 | ff0201 | ff0000 | 000001 |               4 * 3 Bytes
    // _________________________________________________
    // | c d s  |  c d s |  ...                            c = color, d = direction, s = state
    // _________________________________________________
    // | c = ff  ,  d = 08  ,  s = 01 | ...
    // _________________________________________________
    //
    // written as context-sensitive grammar, with start symbol S:
    //
    //     S    	→       a  a  a
    //     a        →       c  d  s
    //     c        →       ff | 00
    //     d        →       02 | 08 | 04
    //     s        →       01 | 00

    /// @dev creates an Turmite Struct and mapping to id, every turmite gets initalized with state 0
    /// @param posx the x position of the turmite on the board
    /// @param posy the y position on the turmite on the board
    /// @param startdirection the startdirection of the turmite
    /// @param boardNumber the boardNumber number
    /// @param rule 12 Byte rule which defines behavior of the turmite
    function createTurmite(
        uint256 id,
        uint8 posx,
        uint8 posy,
        uint8 startdirection,
        uint8 boardNumber,
        bytes12 rule
    ) internal {
        bytes1 state = hex"00";
        turmites[id] = turmite(posx, posy, startdirection, boardNumber, state, rule);
    }

    /// @dev main computational logic of turmite
    /// @dev this function is internal because there should be a check to validate ownership of the turmite
    /// @param id the id of the turmite to move
    /// @param moves the number of moves
    function calculateTurmiteMove(uint256 id, uint256 moves) internal {
        bytes1 colorField;
        uint8 _x;
        uint8 _y;
        uint8 _boardNumber;
        bytes32 sour;

        turmite storage data = turmites[id];
        assembly {
            sour := sload(data.slot)
        }
        for (uint256 z = 0; z < moves; ) {
            assembly {
                _x := and(sour, 0xFF)
                _y := and(shr(8, sour), 0xFF)
                _boardNumber := shr(24, sour)
            }
            bytes1 stateOfField = getByte(_x, _y, _boardNumber);
            assembly {
                let maskedRule := and(sour, 0x000000000000000000000000000000ffffffffffffffffffffffff0000000000)

                let _orientation := and(
                    shr(16, sour),
                    0x00000000000000000000000000000000000000000000000000000000000000ff
                )

                let newState
                let newDirection

                if and(
                    eq(shr(248, stateOfField), 0x00),
                    eq(shr(32, and(sour, 0x000000000000000000000000000000000000000000000000000000ff00000000)), 0x00)
                ) {
                    colorField := shl(120, maskedRule)
                    newDirection := and(shr(120, maskedRule), 0xFF)
                    newState := and(shr(112, maskedRule), 0xFF)
                }
                if and(
                    eq(shr(248, stateOfField), 0xff),
                    eq(shr(32, and(sour, 0x000000000000000000000000000000000000000000000000000000ff00000000)), 0x00)
                ) {
                    colorField := shl(144, maskedRule)
                    newDirection := and(shr(96, maskedRule), 0xFF)
                    newState := and(shr(88, maskedRule), 0xFF)
                }
                if and(
                    eq(shr(248, stateOfField), 0x00),
                    eq(shr(32, and(sour, 0x000000000000000000000000000000000000000000000000000000ff00000000)), 0x01)
                ) {
                    colorField := shl(168, maskedRule)
                    newDirection := and(shr(72, maskedRule), 0xFF)
                    newState := and(shr(64, maskedRule), 0xFF)
                }
                if and(
                    eq(shr(248, stateOfField), 0xff),
                    eq(shr(32, and(sour, 0x000000000000000000000000000000000000000000000000000000ff00000000)), 0x01)
                ) {
                    colorField := shl(192, maskedRule)
                    newDirection := and(shr(48, maskedRule), 0xFF)
                    newState := and(shr(40, maskedRule), 0xFF)
                }

                let newOrientation
                switch newDirection
                case 0x02 {
                    newOrientation := addmod(_orientation, 1, 4)
                }
                case 0x08 {
                    switch _orientation
                    case 0 {
                        newOrientation := 3
                    }
                    default {
                        newOrientation := mod(sub(_orientation, 1), 4)
                    }
                }
                case 0x04 {
                    newOrientation := mod(add(_orientation, 2), 4)
                }
                default {
                    newOrientation := _orientation
                }

                let buffer := mload(0x40)

                switch newOrientation
                case 0x00 {
                    mstore8(add(buffer, 31), addmod(_x, 1, 144))
                    mstore8(add(buffer, 30), _y)
                }
                case 0x02 {
                    switch _x
                    case 0 {
                        mstore8(add(buffer, 31), 143)
                        mstore8(add(buffer, 30), _y)
                    }
                    default {
                        mstore8(add(buffer, 31), sub(_x, 1))
                        mstore8(add(buffer, 30), _y)
                    }
                }
                case 0x03 {
                    mstore8(add(buffer, 31), _x)
                    mstore8(add(buffer, 30), addmod(_y, 1, 144))
                }
                case 0x01 {
                    switch _y
                    case 0 {
                        mstore8(add(buffer, 31), _x)
                        mstore8(add(buffer, 30), 143)
                    }
                    default {
                        mstore8(add(buffer, 31), _x)
                        mstore8(add(buffer, 30), sub(_y, 1))
                    }
                }

                //  128   120  112  104   96   88   80   72   64   56   48  40
                // 0xff    08   01   ff   02   01   ff   00   00   00   44  21

                mstore8(add(buffer, 29), newOrientation)
                mstore8(add(buffer, 28), _boardNumber)
                mstore8(add(buffer, 27), newState)
                sour := or(mload(buffer), maskedRule)
            }

            // note that we pass here the "old" x & y
            setByte(_x, _y, colorField, _boardNumber);
            unchecked {
                z += 1;
            }
        }
        assembly {
            sstore(data.slot, sour)
        }
        emit TurmiteMove(id, _boardNumber, moves);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for converting numbers into strings and other string operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibString.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/LibString.sol)
library LibString {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The `length` of the output is too small to contain all the hex digits.
    error HexLengthInsufficient();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The constant returned when the `search` is not found in the string.
    uint256 internal constant NOT_FOUND = type(uint256).max;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     DECIMAL OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the base 10 decimal representation of `value`.
    function toString(uint256 value) internal pure returns (string memory str) {
        /// @solidity memory-safe-assembly
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
            // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 word for the trailing zeros padding, 1 word for the length,
            // and 3 words for a maximum of 78 digits. Total: 5 * 0x20 = 0xa0.
            let m := add(mload(0x40), 0xa0)
            // Update the free memory pointer to allocate.
            mstore(0x40, m)
            // Assign the `str` to the end.
            str := sub(m, 0x20)
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end of the memory to calculate the length later.
            let end := str

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 1)
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                // prettier-ignore
                if iszero(temp) { break }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   HEXADECIMAL OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the hexadecimal representation of `value`,
    /// left-padded to an input length of `length` bytes.
    /// The output is prefixed with "0x" encoded using 2 hexadecimal digits per byte,
    /// giving a total length of `length * 2 + 2` bytes.
    /// Reverts if `length` is too small for the output to contain all the digits.
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(value, length);
        /// @solidity memory-safe-assembly
        assembly {
            let strLength := add(mload(str), 2) // Compute the length.
            mstore(str, 0x3078) // Write the "0x" prefix.
            str := sub(str, 2) // Move the pointer.
            mstore(str, strLength) // Write the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`,
    /// left-padded to an input length of `length` bytes.
    /// The output is prefixed with "0x" encoded using 2 hexadecimal digits per byte,
    /// giving a total length of `length * 2` bytes.
    /// Reverts if `length` is too small for the output to contain all the digits.
    function toHexStringNoPrefix(uint256 value, uint256 length) internal pure returns (string memory str) {
        /// @solidity memory-safe-assembly
        assembly {
            let start := mload(0x40)
            // We need 0x20 bytes for the trailing zeros padding, `length * 2` bytes
            // for the digits, 0x02 bytes for the prefix, and 0x20 bytes for the length.
            // We add 0x20 to the total and round down to a multiple of 0x20.
            // (0x20 + 0x20 + 0x02 + 0x20) = 0x62.
            let m := add(start, and(add(shl(1, length), 0x62), not(0x1f)))
            // Allocate the memory.
            mstore(0x40, m)
            // Assign the `str` to the end.
            str := sub(m, 0x20)
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end to calculate the length later.
            let end := str
            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            let temp := value
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for {} 1 {} {
                str := sub(str, 2)
                mstore8(add(str, 1), mload(and(temp, 15)))
                mstore8(str, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                length := sub(length, 1)
                // prettier-ignore
                if iszero(length) { break }
            }

            if temp {
                // Store the function selector of `HexLengthInsufficient()`.
                mstore(0x00, 0x2194895a)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Compute the string's length.
            let strLength := sub(end, str)
            // Move the pointer and write the length.
            str := sub(str, 0x20)
            mstore(str, strLength)
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x" and encoded using 2 hexadecimal digits per byte.
    /// As address are 20 bytes long, the output will left-padded to have
    /// a length of `20 * 2 + 2` bytes.
    function toHexString(uint256 value) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(value);
        /// @solidity memory-safe-assembly
        assembly {
            let strLength := add(mload(str), 2) // Compute the length.
            mstore(str, 0x3078) // Write the "0x" prefix.
            str := sub(str, 2) // Move the pointer.
            mstore(str, strLength) // Write the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is encoded using 2 hexadecimal digits per byte.
    /// As address are 20 bytes long, the output will left-padded to have
    /// a length of `20 * 2` bytes.
    function toHexStringNoPrefix(uint256 value) internal pure returns (string memory str) {
        /// @solidity memory-safe-assembly
        assembly {
            let start := mload(0x40)
            // We need 0x20 bytes for the trailing zeros padding, 0x20 bytes for the length,
            // 0x02 bytes for the prefix, and 0x40 bytes for the digits.
            // The next multiple of 0x20 above (0x20 + 0x20 + 0x02 + 0x40) is 0xa0.
            let m := add(start, 0xa0)
            // Allocate the memory.
            mstore(0x40, m)
            // Assign the `str` to the end.
            str := sub(m, 0x20)
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end to calculate the length later.
            let end := str
            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 2)
                mstore8(add(str, 1), mload(and(temp, 15)))
                mstore8(str, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                // prettier-ignore
                if iszero(temp) { break }
            }

            // Compute the string's length.
            let strLength := sub(end, str)
            // Move the pointer and write the length.
            str := sub(str, 0x20)
            mstore(str, strLength)
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x", encoded using 2 hexadecimal digits per byte,
    /// and the alphabets are capitalized conditionally according to
    /// https://eips.ethereum.org/EIPS/eip-55
    function toHexStringChecksumed(address value) internal pure returns (string memory str) {
        str = toHexString(value);
        /// @solidity memory-safe-assembly
        assembly {
            let mask := shl(6, div(not(0), 255)) // `0b010000000100000000 ...`
            let o := add(str, 0x22)
            let hashed := and(keccak256(o, 40), mul(34, mask)) // `0b10001000 ... `
            let t := shl(240, 136) // `0b10001000 << 240`
            // prettier-ignore
            for { let i := 0 } 1 {} {
                mstore(add(i, i), mul(t, byte(i, hashed)))
                i := add(i, 1)
                // prettier-ignore
                if eq(i, 20) { break }
            }
            mstore(o, xor(mload(o), shr(1, and(mload(0x00), and(mload(o), mask)))))
            o := add(o, 0x20)
            mstore(o, xor(mload(o), shr(1, and(mload(0x20), and(mload(o), mask)))))
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x" and encoded using 2 hexadecimal digits per byte.
    function toHexString(address value) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(value);
        /// @solidity memory-safe-assembly
        assembly {
            let strLength := add(mload(str), 2) // Compute the length.
            mstore(str, 0x3078) // Write the "0x" prefix.
            str := sub(str, 2) // Move the pointer.
            mstore(str, strLength) // Write the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is encoded using 2 hexadecimal digits per byte.
    function toHexStringNoPrefix(address value) internal pure returns (string memory str) {
        /// @solidity memory-safe-assembly
        assembly {
            str := mload(0x40)

            // Allocate the memory.
            // We need 0x20 bytes for the trailing zeros padding, 0x20 bytes for the length,
            // 0x02 bytes for the prefix, and 0x28 bytes for the digits.
            // The next multiple of 0x20 above (0x20 + 0x20 + 0x02 + 0x28) is 0x80.
            mstore(0x40, add(str, 0x80))

            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            str := add(str, 2)
            mstore(str, 40)

            let o := add(str, 0x20)
            mstore(add(o, 40), 0)

            value := shl(96, value)

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let i := 0 } 1 {} {
                let p := add(o, add(i, i))
                let temp := byte(i, value)
                mstore8(add(p, 1), mload(and(temp, 15)))
                mstore8(p, mload(shr(4, temp)))
                i := add(i, 1)
                // prettier-ignore
                if eq(i, 20) { break }
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   RUNE STRING OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the number of UTF characters in the string.
    function runeCount(string memory s) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            if mload(s) {
                mstore(0x00, div(not(0), 255))
                mstore(0x20, 0x0202020202020202020202020202020202020202020202020303030304040506)
                let o := add(s, 0x20)
                let end := add(o, mload(s))
                // prettier-ignore
                for { result := 1 } 1 { result := add(result, 1) } {
                    o := add(o, byte(0, mload(shr(250, mload(o)))))
                    // prettier-ignore
                    if iszero(lt(o, end)) { break }
                }
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   BYTE STRING OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // For performance and bytecode compactness, all indices of the following operations
    // are byte (ASCII) offsets, not UTF character offsets.

    /// @dev Returns `subject` all occurrences of `search` replaced with `replacement`.
    function replace(
        string memory subject,
        string memory search,
        string memory replacement
    ) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            let subjectLength := mload(subject)
            let searchLength := mload(search)
            let replacementLength := mload(replacement)

            subject := add(subject, 0x20)
            search := add(search, 0x20)
            replacement := add(replacement, 0x20)
            result := add(mload(0x40), 0x20)

            let subjectEnd := add(subject, subjectLength)
            if iszero(gt(searchLength, subjectLength)) {
                let subjectSearchEnd := add(sub(subjectEnd, searchLength), 1)
                let h := 0
                if iszero(lt(searchLength, 32)) {
                    h := keccak256(search, searchLength)
                }
                let m := shl(3, sub(32, and(searchLength, 31)))
                let s := mload(search)
                // prettier-ignore
                for {} 1 {} {
                    let t := mload(subject)
                    // Whether the first `searchLength % 32` bytes of 
                    // `subject` and `search` matches.
                    if iszero(shr(m, xor(t, s))) {
                        if h {
                            if iszero(eq(keccak256(subject, searchLength), h)) {
                                mstore(result, t)
                                result := add(result, 1)
                                subject := add(subject, 1)
                                // prettier-ignore
                                if iszero(lt(subject, subjectSearchEnd)) { break }
                                continue
                            }
                        }
                        // Copy the `replacement` one word at a time.
                        // prettier-ignore
                        for { let o := 0 } 1 {} {
                            mstore(add(result, o), mload(add(replacement, o)))
                            o := add(o, 0x20)
                            // prettier-ignore
                            if iszero(lt(o, replacementLength)) { break }
                        }
                        result := add(result, replacementLength)
                        subject := add(subject, searchLength)
                        if searchLength {
                            // prettier-ignore
                            if iszero(lt(subject, subjectSearchEnd)) { break }
                            continue
                        }
                    }
                    mstore(result, t)
                    result := add(result, 1)
                    subject := add(subject, 1)
                    // prettier-ignore
                    if iszero(lt(subject, subjectSearchEnd)) { break }
                }
            }

            let resultRemainder := result
            result := add(mload(0x40), 0x20)
            let k := add(sub(resultRemainder, result), sub(subjectEnd, subject))
            // Copy the rest of the string one word at a time.
            // prettier-ignore
            for {} lt(subject, subjectEnd) {} {
                mstore(resultRemainder, mload(subject))
                resultRemainder := add(resultRemainder, 0x20)
                subject := add(subject, 0x20)
            }
            result := sub(result, 0x20)
            // Zeroize the slot after the string.
            let last := add(add(result, 0x20), k)
            mstore(last, 0)
            // Allocate memory for the length and the bytes,
            // rounded up to a multiple of 32.
            mstore(0x40, and(add(last, 31), not(31)))
            // Store the length of the result.
            mstore(result, k)
        }
    }

    /// @dev Returns the byte index of the first location of `search` in `subject`,
    /// searching from left to right, starting from `from`.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `search` is not found.
    function indexOf(
        string memory subject,
        string memory search,
        uint256 from
    ) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // prettier-ignore
            for { let subjectLength := mload(subject) } 1 {} {
                if iszero(mload(search)) {
                    // `result = min(from, subjectLength)`.
                    result := xor(from, mul(xor(from, subjectLength), lt(subjectLength, from)))
                    break
                }
                let searchLength := mload(search)
                let subjectStart := add(subject, 0x20)    
                
                result := not(0) // Initialize to `NOT_FOUND`.

                subject := add(subjectStart, from)
                let subjectSearchEnd := add(sub(add(subjectStart, subjectLength), searchLength), 1)

                let m := shl(3, sub(32, and(searchLength, 31)))
                let s := mload(add(search, 0x20))

                // prettier-ignore
                if iszero(lt(subject, subjectSearchEnd)) { break }

                if iszero(lt(searchLength, 32)) {
                    // prettier-ignore
                    for { let h := keccak256(add(search, 0x20), searchLength) } 1 {} {
                        if iszero(shr(m, xor(mload(subject), s))) {
                            if eq(keccak256(subject, searchLength), h) {
                                result := sub(subject, subjectStart)
                                break
                            }
                        }
                        subject := add(subject, 1)
                        // prettier-ignore
                        if iszero(lt(subject, subjectSearchEnd)) { break }
                    }
                    break
                }
                // prettier-ignore
                for {} 1 {} {
                    if iszero(shr(m, xor(mload(subject), s))) {
                        result := sub(subject, subjectStart)
                        break
                    }
                    subject := add(subject, 1)
                    // prettier-ignore
                    if iszero(lt(subject, subjectSearchEnd)) { break }
                }
                break
            }
        }
    }

    /// @dev Returns the byte index of the first location of `search` in `subject`,
    /// searching from left to right.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `search` is not found.
    function indexOf(string memory subject, string memory search) internal pure returns (uint256 result) {
        result = indexOf(subject, search, 0);
    }

    /// @dev Returns the byte index of the first location of `search` in `subject`,
    /// searching from right to left, starting from `from`.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `search` is not found.
    function lastIndexOf(
        string memory subject,
        string memory search,
        uint256 from
    ) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // prettier-ignore
            for {} 1 {} {
                let searchLength := mload(search)
                let fromMax := sub(mload(subject), searchLength)
                if iszero(gt(fromMax, from)) {
                    from := fromMax
                }
                if iszero(mload(search)) {
                    result := from
                    break
                }
                result := not(0) // Initialize to `NOT_FOUND`.

                let subjectSearchEnd := sub(add(subject, 0x20), 1)

                subject := add(add(subject, 0x20), from)
                // prettier-ignore
                if iszero(gt(subject, subjectSearchEnd)) { break }
                // As this function is not too often used,
                // we shall simply use keccak256 for smaller bytecode size.
                // prettier-ignore
                for { let h := keccak256(add(search, 0x20), searchLength) } 1 {} {
                    if eq(keccak256(subject, searchLength), h) {
                        result := sub(subject, add(subjectSearchEnd, 1))
                        break
                    }
                    subject := sub(subject, 1)
                    // prettier-ignore
                    if iszero(gt(subject, subjectSearchEnd)) { break }
                }
                break
            }
        }
    }

    /// @dev Returns the byte index of the first location of `search` in `subject`,
    /// searching from right to left.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `search` is not found.
    function lastIndexOf(string memory subject, string memory search) internal pure returns (uint256 result) {
        result = lastIndexOf(subject, search, uint256(int256(-1)));
    }

    /// @dev Returns whether `subject` starts with `search`.
    function startsWith(string memory subject, string memory search) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            let searchLength := mload(search)
            // Just using keccak256 directly is actually cheaper.
            result := and(
                iszero(gt(searchLength, mload(subject))),
                eq(keccak256(add(subject, 0x20), searchLength), keccak256(add(search, 0x20), searchLength))
            )
        }
    }

    /// @dev Returns whether `subject` ends with `search`.
    function endsWith(string memory subject, string memory search) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            let searchLength := mload(search)
            let subjectLength := mload(subject)
            // Whether `search` is not longer than `subject`.
            let withinRange := iszero(gt(searchLength, subjectLength))
            // Just using keccak256 directly is actually cheaper.
            result := and(
                withinRange,
                eq(
                    keccak256(
                        // `subject + 0x20 + max(subjectLength - searchLength, 0)`.
                        add(add(subject, 0x20), mul(withinRange, sub(subjectLength, searchLength))),
                        searchLength
                    ),
                    keccak256(add(search, 0x20), searchLength)
                )
            )
        }
    }

    /// @dev Returns `subject` repeated `times`.
    function repeat(string memory subject, uint256 times) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            let subjectLength := mload(subject)
            if iszero(or(iszero(times), iszero(subjectLength))) {
                subject := add(subject, 0x20)
                result := mload(0x40)
                let output := add(result, 0x20)
                // prettier-ignore
                for {} 1 {} {
                    // Copy the `subject` one word at a time.
                    // prettier-ignore
                    for { let o := 0 } 1 {} {
                        mstore(add(output, o), mload(add(subject, o)))
                        o := add(o, 0x20)
                        // prettier-ignore
                        if iszero(lt(o, subjectLength)) { break }
                    }
                    output := add(output, subjectLength)
                    times := sub(times, 1)
                    // prettier-ignore
                    if iszero(times) { break }
                }
                // Zeroize the slot after the string.
                mstore(output, 0)
                // Store the length.
                let resultLength := sub(output, add(result, 0x20))
                mstore(result, resultLength)
                // Allocate memory for the length and the bytes,
                // rounded up to a multiple of 32.
                mstore(0x40, add(result, and(add(resultLength, 63), not(31))))
            }
        }
    }

    /// @dev Returns a copy of `subject` sliced from `start` to `end` (exclusive).
    /// `start` and `end` are byte offsets.
    function slice(
        string memory subject,
        uint256 start,
        uint256 end
    ) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            let subjectLength := mload(subject)
            if iszero(gt(subjectLength, end)) {
                end := subjectLength
            }
            if iszero(gt(subjectLength, start)) {
                start := subjectLength
            }
            if lt(start, end) {
                result := mload(0x40)
                let resultLength := sub(end, start)
                mstore(result, resultLength)
                subject := add(subject, start)
                let w := not(31)
                // Copy the `subject` one word at a time, backwards.
                // prettier-ignore
                for { let o := and(add(resultLength, 31), w) } 1 {} {
                    mstore(add(result, o), mload(add(subject, o)))
                    o := add(o, w) // `sub(o, 0x20)`.
                    // prettier-ignore
                    if iszero(o) { break }
                }
                // Zeroize the slot after the string.
                mstore(add(add(result, 0x20), resultLength), 0)
                // Allocate memory for the length and the bytes,
                // rounded up to a multiple of 32.
                mstore(0x40, add(result, and(add(resultLength, 63), w)))
            }
        }
    }

    /// @dev Returns a copy of `subject` sliced from `start` to the end of the string.
    /// `start` is a byte offset.
    function slice(string memory subject, uint256 start) internal pure returns (string memory result) {
        result = slice(subject, start, uint256(int256(-1)));
    }

    /// @dev Returns all the indices of `search` in `subject`.
    /// The indices are byte offsets.
    function indicesOf(string memory subject, string memory search) internal pure returns (uint256[] memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            let subjectLength := mload(subject)
            let searchLength := mload(search)

            if iszero(gt(searchLength, subjectLength)) {
                subject := add(subject, 0x20)
                search := add(search, 0x20)
                result := add(mload(0x40), 0x20)

                let subjectStart := subject
                let subjectSearchEnd := add(sub(add(subject, subjectLength), searchLength), 1)
                let h := 0
                if iszero(lt(searchLength, 32)) {
                    h := keccak256(search, searchLength)
                }
                let m := shl(3, sub(32, and(searchLength, 31)))
                let s := mload(search)
                // prettier-ignore
                for {} 1 {} {
                    let t := mload(subject)
                    // Whether the first `searchLength % 32` bytes of 
                    // `subject` and `search` matches.
                    if iszero(shr(m, xor(t, s))) {
                        if h {
                            if iszero(eq(keccak256(subject, searchLength), h)) {
                                subject := add(subject, 1)
                                // prettier-ignore
                                if iszero(lt(subject, subjectSearchEnd)) { break }
                                continue
                            }
                        }
                        // Append to `result`.
                        mstore(result, sub(subject, subjectStart))
                        result := add(result, 0x20)
                        // Advance `subject` by `searchLength`.
                        subject := add(subject, searchLength)
                        if searchLength {
                            // prettier-ignore
                            if iszero(lt(subject, subjectSearchEnd)) { break }
                            continue
                        }
                    }
                    subject := add(subject, 1)
                    // prettier-ignore
                    if iszero(lt(subject, subjectSearchEnd)) { break }
                }
                let resultEnd := result
                // Assign `result` to the free memory pointer.
                result := mload(0x40)
                // Store the length of `result`.
                mstore(result, shr(5, sub(resultEnd, add(result, 0x20))))
                // Allocate memory for result.
                // We allocate one more word, so this array can be recycled for {split}.
                mstore(0x40, add(resultEnd, 0x20))
            }
        }
    }

    /// @dev Returns a arrays of strings based on the `delimiter` inside of the `subject` string.
    function split(string memory subject, string memory delimiter) internal pure returns (string[] memory result) {
        uint256[] memory indices = indicesOf(subject, delimiter);
        /// @solidity memory-safe-assembly
        assembly {
            let w := not(31)
            let indexPtr := add(indices, 0x20)
            let indicesEnd := add(indexPtr, shl(5, add(mload(indices), 1)))
            mstore(add(indicesEnd, w), mload(subject))
            mstore(indices, add(mload(indices), 1))
            let prevIndex := 0
            // prettier-ignore
            for {} 1 {} {
                let index := mload(indexPtr)
                mstore(indexPtr, 0x60)                        
                if iszero(eq(index, prevIndex)) {
                    let element := mload(0x40)
                    let elementLength := sub(index, prevIndex)
                    mstore(element, elementLength)
                    // Copy the `subject` one word at a time, backwards.
                    // prettier-ignore
                    for { let o := and(add(elementLength, 31), w) } 1 {} {
                        mstore(add(element, o), mload(add(add(subject, prevIndex), o)))
                        o := add(o, w) // `sub(o, 0x20)`.
                        // prettier-ignore
                        if iszero(o) { break }
                    }
                    // Zeroize the slot after the string.
                    mstore(add(add(element, 0x20), elementLength), 0)
                    // Allocate memory for the length and the bytes,
                    // rounded up to a multiple of 32.
                    mstore(0x40, add(element, and(add(elementLength, 63), w)))
                    // Store the `element` into the array.
                    mstore(indexPtr, element)                        
                }
                prevIndex := add(index, mload(delimiter))
                indexPtr := add(indexPtr, 0x20)
                // prettier-ignore
                if iszero(lt(indexPtr, indicesEnd)) { break }
            }
            result := indices
            if iszero(mload(delimiter)) {
                result := add(indices, 0x20)
                mstore(result, sub(mload(indices), 2))
            }
        }
    }

    /// @dev Returns a concatenated string of `a` and `b`.
    /// Cheaper than `string.concat()` and does not de-align the free memory pointer.
    function concat(string memory a, string memory b) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            let w := not(31)
            result := mload(0x40)
            let aLength := mload(a)
            // Copy `a` one word at a time, backwards.
            // prettier-ignore
            for { let o := and(add(mload(a), 32), w) } 1 {} {
                mstore(add(result, o), mload(add(a, o)))
                o := add(o, w) // `sub(o, 0x20)`.
                // prettier-ignore
                if iszero(o) { break }
            }
            let bLength := mload(b)
            let output := add(result, mload(a))
            // Copy `b` one word at a time, backwards.
            // prettier-ignore
            for { let o := and(add(bLength, 32), w) } 1 {} {
                mstore(add(output, o), mload(add(b, o)))
                o := add(o, w) // `sub(o, 0x20)`.
                // prettier-ignore
                if iszero(o) { break }
            }
            let totalLength := add(aLength, bLength)
            let last := add(add(result, 0x20), totalLength)
            // Zeroize the slot after the string.
            mstore(last, 0)
            // Stores the length.
            mstore(result, totalLength)
            // Allocate memory for the length and the bytes,
            // rounded up to a multiple of 32.
            mstore(0x40, and(add(last, 31), w))
        }
    }

    /// @dev Returns a copy of the string in either lowercase or UPPERCASE.
    function toCase(string memory subject, bool toUpper) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            let length := mload(subject)
            if length {
                result := add(mload(0x40), 0x20)
                subject := add(subject, 1)
                let flags := shl(add(70, shl(5, toUpper)), 67108863)
                let w := not(0)
                // prettier-ignore
                for { let o := length } 1 {} {
                    o := add(o, w)
                    let b := and(0xff, mload(add(subject, o)))
                    mstore8(add(result, o), xor(b, and(shr(b, flags), 0x20)))
                    // prettier-ignore
                    if iszero(o) { break }
                }
                // Restore the result.
                result := mload(0x40)
                // Stores the string length.
                mstore(result, length)
                // Zeroize the slot after the string.
                let last := add(add(result, 0x20), length)
                mstore(last, 0)
                // Allocate memory for the length and the bytes,
                // rounded up to a multiple of 32.
                mstore(0x40, and(add(last, 31), not(31)))
            }
        }
    }

    /// @dev Returns a lowercased copy of the string.
    function lower(string memory subject) internal pure returns (string memory result) {
        result = toCase(subject, false);
    }

    /// @dev Returns an UPPERCASED copy of the string.
    function upper(string memory subject) internal pure returns (string memory result) {
        result = toCase(subject, true);
    }

    /// @dev Escapes the string to be used within HTML tags.
    function escapeHTML(string memory s) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            // prettier-ignore
            for {
                let end := add(s, mload(s))
                result := add(mload(0x40), 0x20)
                // Store the bytes of the packed offsets and strides into the scratch space.
                // `packed = (stride << 5) | offset`. Max offset is 20. Max stride is 6.
                mstore(0x1f, 0x900094)
                mstore(0x08, 0xc0000000a6ab)
                // Store "&quot;&amp;&#39;&lt;&gt;" into the scratch space.
                mstore(0x00, shl(64, 0x2671756f743b26616d703b262333393b266c743b2667743b))
            } iszero(eq(s, end)) {} {
                s := add(s, 1)
                let c := and(mload(s), 0xff)
                // Not in `["\"","'","&","<",">"]`.
                if iszero(and(shl(c, 1), 0x500000c400000000)) { 
                    mstore8(result, c)
                    result := add(result, 1)
                    continue    
                }
                let t := shr(248, mload(c))
                mstore(result, mload(and(t, 31)))
                result := add(result, shr(5, t))
            }
            let last := result
            // Zeroize the slot after the string.
            mstore(last, 0)
            // Restore the result to the start of the free memory.
            result := mload(0x40)
            // Store the length of the result.
            mstore(result, sub(last, add(result, 0x20)))
            // Allocate memory for the length and the bytes,
            // rounded up to a multiple of 32.
            mstore(0x40, and(add(last, 31), not(31)))
        }
    }

    /// @dev Escapes the string to be used within double-quotes in a JSON.
    function escapeJSON(string memory s) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            // prettier-ignore
            for {
                let end := add(s, mload(s))
                result := add(mload(0x40), 0x20)
                // Store "\\u0000" in scratch space.
                // Store "0123456789abcdef" in scratch space.
                // Also, store `{0x08:"b", 0x09:"t", 0x0a:"n", 0x0c:"f", 0x0d:"r"}`.
                // into the scratch space.
                mstore(0x15, 0x5c75303030303031323334353637383961626364656662746e006672)
                // Bitmask for detecting `["\"","\\"]`.
                let e := or(shl(0x22, 1), shl(0x5c, 1))
            } iszero(eq(s, end)) {} {
                s := add(s, 1)
                let c := and(mload(s), 0xff)
                if iszero(lt(c, 0x20)) {
                    if iszero(and(shl(c, 1), e)) { // Not in `["\"","\\"]`.
                        mstore8(result, c)
                        result := add(result, 1)
                        continue    
                    }
                    mstore8(result, 0x5c) // "\\".
                    mstore8(add(result, 1), c) 
                    result := add(result, 2)
                    continue
                }
                if iszero(and(shl(c, 1), 0x3700)) { // Not in `["\b","\t","\n","\f","\d"]`.
                    mstore8(0x1d, mload(shr(4, c))) // Hex value.
                    mstore8(0x1e, mload(and(c, 15))) // Hex value.
                    mstore(result, mload(0x19)) // "\\u00XX".
                    result := add(result, 6)    
                    continue
                }
                mstore8(result, 0x5c) // "\\".
                mstore8(add(result, 1), mload(add(c, 8)))
                result := add(result, 2)
            }
            let last := result
            // Zeroize the slot after the string.
            mstore(last, 0)
            // Restore the result to the start of the free memory.
            result := mload(0x40)
            // Store the length of the result.
            mstore(result, sub(last, add(result, 0x20)))
            // Allocate memory for the length and the bytes,
            // rounded up to a multiple of 32.
            mstore(0x40, and(add(last, 31), not(31)))
        }
    }

    /// @dev Returns whether `a` equals `b`.
    function eq(string memory a, string memory b) internal pure returns (bool result) {
        assembly {
            result := eq(keccak256(add(a, 0x20), mload(a)), keccak256(add(b, 0x20), mload(b)))
        }
    }

    /// @dev Packs a single string with its length into a single word.
    /// Returns `bytes32(0)` if the length is zero or greater than 31.
    function packOne(string memory a) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // We don't need to zero right pad the string,
            // since this is our own custom non-standard packing scheme.
            result := mul(
                // Load the length and the bytes.
                mload(add(a, 0x1f)),
                // `length != 0 && length < 32`. Abuses underflow.
                // Assumes that the length is valid and within the block gas limit.
                lt(sub(mload(a), 1), 0x1f)
            )
        }
    }

    /// @dev Unpacks a string packed using {packOne}.
    /// Returns the empty string if `packed` is `bytes32(0)`.
    /// If `packed` is not an output of {packOne}, the output behaviour is undefined.
    function unpackOne(bytes32 packed) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            // Grab the free memory pointer.
            result := mload(0x40)
            // Allocate 2 words (1 for the length, 1 for the bytes).
            mstore(0x40, add(result, 0x40))
            // Zeroize the length slot.
            mstore(result, 0)
            // Store the length and bytes.
            mstore(add(result, 0x1f), packed)
            // Right pad with zeroes.
            mstore(add(add(result, 0x20), mload(result)), 0)
        }
    }

    /// @dev Packs two strings with their lengths into a single word.
    /// Returns `bytes32(0)` if combined length is zero or greater than 30.
    function packTwo(string memory a, string memory b) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let aLength := mload(a)
            // We don't need to zero right pad the strings,
            // since this is our own custom non-standard packing scheme.
            result := mul(
                // Load the length and the bytes of `a` and `b`.
                or(shl(shl(3, sub(0x1f, aLength)), mload(add(a, aLength))), mload(sub(add(b, 0x1e), aLength))),
                // `totalLength != 0 && totalLength < 31`. Abuses underflow.
                // Assumes that the lengths are valid and within the block gas limit.
                lt(sub(add(aLength, mload(b)), 1), 0x1e)
            )
        }
    }

    /// @dev Unpacks strings packed using {packTwo}.
    /// Returns the empty strings if `packed` is `bytes32(0)`.
    /// If `packed` is not an output of {packTwo}, the output behaviour is undefined.
    function unpackTwo(bytes32 packed) internal pure returns (string memory resultA, string memory resultB) {
        /// @solidity memory-safe-assembly
        assembly {
            // Grab the free memory pointer.
            resultA := mload(0x40)
            resultB := add(resultA, 0x40)
            // Allocate 2 words for each string (1 for the length, 1 for the byte). Total 4 words.
            mstore(0x40, add(resultB, 0x40))
            // Zeroize the length slots.
            mstore(resultA, 0)
            mstore(resultB, 0)
            // Store the lengths and bytes.
            mstore(add(resultA, 0x1f), packed)
            mstore(add(resultB, 0x1f), mload(add(add(resultA, 0x20), mload(resultA))))
            // Right pad with zeroes.
            mstore(add(add(resultA, 0x20), mload(resultA)), 0)
            mstore(add(add(resultB, 0x20), mload(resultB)), 0)
        }
    }

    /// @dev Directly returns `a` without copying.
    function directReturn(string memory a) internal pure {
        assembly {
            // Assumes that the string does not start from the scratch space.
            let retStart := sub(a, 0x20)
            let retSize := add(mload(a), 0x40)
            // Right pad with zeroes. Just in case the string is produced
            // by a method that doesn't zero right pad.
            mstore(add(retStart, retSize), 0)
            // Store the return offset.
            mstore(retStart, 0x20)
            // End the transaction, returning the string.
            return(retStart, retSize)
        }
    }
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "solidity-bytes-utils/contracts/BytesLib.sol";
import "base64-sol/base64.sol";

/// @title Gameboard for inchain turmites
/// @notice Implementation of an Gameboard for Straylight Protocoll.
/// @notice we are all standing on the shoulders of giants - this board is inspired by how CryptoGhost is drawing boards
/// @author @brachlandberlin / plsdlr.net
/// @dev bytesLib & base64 are required for formating

contract Gameboard {
    using BytesLib for bytes;
    mapping(uint256 => gameboard) gameboards;

    struct gameboard {
        bytes1[144][144] board;
    }

    /// @dev an explicit function to get a byte with x,y,board
    /// @param x the x position on the board
    /// @param y the y position on the board
    /// @param boardNumber the boardNumber number
    function getByte(
        uint256 x,
        uint256 y,
        uint256 boardNumber
    ) public view returns (bytes1) {
        return gameboards[boardNumber].board[x][y];
    }

    /// @dev an explicit function to set a byte with x,y,value,board
    /// @param x the x position on the board
    /// @param y the y position on the board
    /// @param value the byte1 value to set
    /// @param boardNumber the board number
    function setByte(
        uint256 x,
        uint256 y,
        bytes1 value,
        uint256 boardNumber
    ) internal {
        gameboards[boardNumber].board[x][y] = value;
    }

    /// @dev function to generate the Bitmap Base64 encoded with boardNumber, position x, position y and boolean if turmite should be rendered
    /// @param boardNumber the board number
    /// @param posx the x position of the turmite on the board
    /// @param posy the y position on the turmite on the board
    /// @param renderTurmite boolean to render turmite
    function getBitmapBase64(
        uint8 boardNumber,
        uint8 posx,
        uint8 posy,
        bool renderTurmite
    ) public view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:image/bmp;base64,",
                    Base64.encode(getBitmap(boardNumber, posx, posy, renderTurmite))
                )
            );
    }

    /// @dev function to generate a SVG String with boardNumber, position x, position y and boolean if turmite should be rendered
    /// @dev same parameters as getBitmapBase64
    function getSvg(
        uint8 boardNumber,
        uint8 posx,
        uint8 posy,
        bool renderTurmite
    ) public view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            '<svg class="svgBGG" xmlns="http://www.w3.org/2000/svg" version="1.1" width="500" height="500"><defs id="someDefs"><style id="style1999"> .svgBGG { width: 500px;height: 500px;background-image: url(',
                            getBitmapBase64(boardNumber, posx, posy, renderTurmite),
                            "); background-repeat: no-repeat; background-size: 100%; image-rendering: -webkit-optimize-contrast; -ms-interpolation-mode: nearest-neighbor; image-rendering: -moz-crisp-edges; image-rendering: pixelated;}</style></defs></svg>"
                        )
                    )
                )
            );
    }

    /// @dev function to generate byte representation of the Board, position x, position y and boolean if turmite should be rendered
    /// @dev BMP Header is generated externaly
    /// @dev same parameters as getBitmapBase64
    function getBitmap(
        uint8 boardNumber,
        uint8 posx,
        uint8 posy,
        bool renderTurmite
    ) public view returns (bytes memory) {
        bytes
            memory headers = hex"424D385500000000000036040000280000009000000090000000010008000000000002510000120B0000120B00000000000000000000000000000101010002020200030303000404040005050500060606000707070008080800090909000A0A0A000B0B0B000C0C0C000D0D0D000E0E0E000F0F0F00101010001111110012121200131313001414140015151500161616001717170018181800191919001A1A1A001B1B1B001C1C1C001D1D1D001E1E1E001F1F1F00202020002121210022222200232323002424240025252500262626002727270028282800292929002A2A2A002B2B2B002C2C2C002D2D2D002E2E2E002F2F2F00303030003131310032323200333333003434340035353500363636003737370038383800393939003A3A3A003B3B3B003C3C3C003D3D3D003E3E3E003F3F3F00404040004141410042424200434343004444440045454500464646004747470048484800494949004A4A4A004B4B4B004C4C4C004D4D4D004E4E4E004F4F4F00505050005151510052525200535353005454540055555500565656005757570058585800595959005A5A5A005B5B5B005C5C5C005D5D5D005E5E5E005F5F5F00606060006161610062626200636363006464640065656500666666006767670068686800696969006A6A6A006B6B6B006C6C6C006D6D6D006E6E6E006F6F6F00707070007171710072727200737373007474740075757500767676007777770078787800797979007A7A7A007B7B7B007C7C7C007D7D7D007E7E7E007F7F7F00808080008181810082828200838383008484840085858500868686008787870088888800898989008A8A8A008B8B8B008C8C8C008D8D8D008E8E8E008F8F8F00909090009191910092929200939393009494940095959500969696009797970098989800999999009A9A9A009B9B9B009C9C9C009D9D9D009E9E9E009F9F9F00A0A0A000A1A1A100A2A2A200A3A3A300A4A4A400A5A5A500A6A6A600A7A7A700A8A8A800A9A9A900AAAAAA00ABABAB00ACACAC00ADADAD00AEAEAE00AFAFAF00B0B0B000B1B1B100B2B2B200B3B3B300B4B4B400B5B5B500B6B6B600B7B7B700B8B8B800B9B9B900BABABA00BBBBBB00BCBCBC00BDBDBD00BEBEBE00BFBFBF00C0C0C000C1C1C100C2C2C200C3C3C300C4C4C400C5C5C500C6C6C600C7C7C700C8C8C800C9C9C900CACACA00CBCBCB00CCCCCC00CDCDCD00CECECE00CFCFCF00D0D0D000D1D1D100D2D2D200D3D3D300D4D4D400D5D5D500D6D6D600D7D7D700D8D8D800D9D9D900DADADA00DBDBDB00DCDCDC00DDDDDD00DEDEDE00DFDFDF00E0E0E000E1E1E100E2E2E200E3E3E300E4E4E400E5E5E500E6E6E600E7E7E700E8E8E800E9E9E900EAEAEA00EBEBEB00ECECEC00EDEDED00EEEEEE00EFEFEF00F0F0F000F1F1F100F2F2F200F3F3F300F4F4F400F5F5F500F6F6F600F7F7F700F8F8F800F9F9F900FAFAFA00FBFBFB00FCFCFC00FDFDFD00FEFEFE00FFFFFF00";
        bytes memory returngameboard = new bytes(20736);
        for (uint256 xFill = 0; xFill < 144; ++xFill) {
            for (uint256 yFill = 0; yFill < 144; ++yFill) {
                uint256 index = xFill + 144 * yFill;
                returngameboard[index] = gameboards[boardNumber].board[xFill][yFill];
            }
        }
        if (renderTurmite == true) {
            uint256 index2 = uint256(posx) + 144 * uint256(posy);
            returngameboard[index2] = bytes1(uint8(165));
        }
        return headers.concat(returngameboard);
    }
}

// SPDX-License-Identifier: Unlicense
/*
 * @title Solidity Bytes Arrays Utils
 * @author Gonçalo Sá <[email protected]>
 *
 * @dev Bytes tightly packed arrays utility library for ethereum contracts written in Solidity.
 *      The library lets you concatenate, slice and type cast bytes arrays both in memory and storage.
 */
pragma solidity >=0.8.0 <0.9.0;


library BytesLib {
    function concat(
        bytes memory _preBytes,
        bytes memory _postBytes
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory tempBytes;

        assembly {
            // Get a location of some free memory and store it in tempBytes as
            // Solidity does for memory variables.
            tempBytes := mload(0x40)

            // Store the length of the first bytes array at the beginning of
            // the memory for tempBytes.
            let length := mload(_preBytes)
            mstore(tempBytes, length)

            // Maintain a memory counter for the current write location in the
            // temp bytes array by adding the 32 bytes for the array length to
            // the starting location.
            let mc := add(tempBytes, 0x20)
            // Stop copying when the memory counter reaches the length of the
            // first bytes array.
            let end := add(mc, length)

            for {
                // Initialize a copy counter to the start of the _preBytes data,
                // 32 bytes into its memory.
                let cc := add(_preBytes, 0x20)
            } lt(mc, end) {
                // Increase both counters by 32 bytes each iteration.
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                // Write the _preBytes data into the tempBytes memory 32 bytes
                // at a time.
                mstore(mc, mload(cc))
            }

            // Add the length of _postBytes to the current length of tempBytes
            // and store it as the new length in the first 32 bytes of the
            // tempBytes memory.
            length := mload(_postBytes)
            mstore(tempBytes, add(length, mload(tempBytes)))

            // Move the memory counter back from a multiple of 0x20 to the
            // actual end of the _preBytes data.
            mc := end
            // Stop copying when the memory counter reaches the new combined
            // length of the arrays.
            end := add(mc, length)

            for {
                let cc := add(_postBytes, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

            // Update the free-memory pointer by padding our last write location
            // to 32 bytes: add 31 bytes to the end of tempBytes to move to the
            // next 32 byte block, then round down to the nearest multiple of
            // 32. If the sum of the length of the two arrays is zero then add
            // one before rounding down to leave a blank 32 bytes (the length block with 0).
            mstore(0x40, and(
              add(add(end, iszero(add(length, mload(_preBytes)))), 31),
              not(31) // Round down to the nearest 32 bytes.
            ))
        }

        return tempBytes;
    }

    function concatStorage(bytes storage _preBytes, bytes memory _postBytes) internal {
        assembly {
            // Read the first 32 bytes of _preBytes storage, which is the length
            // of the array. (We don't need to use the offset into the slot
            // because arrays use the entire slot.)
            let fslot := sload(_preBytes.slot)
            // Arrays of 31 bytes or less have an even value in their slot,
            // while longer arrays have an odd value. The actual length is
            // the slot divided by two for odd values, and the lowest order
            // byte divided by two for even values.
            // If the slot is even, bitwise and the slot with 255 and divide by
            // two to get the length. If the slot is odd, bitwise and the slot
            // with -1 and divide by two.
            let slength := div(and(fslot, sub(mul(0x100, iszero(and(fslot, 1))), 1)), 2)
            let mlength := mload(_postBytes)
            let newlength := add(slength, mlength)
            // slength can contain both the length and contents of the array
            // if length < 32 bytes so let's prepare for that
            // v. http://solidity.readthedocs.io/en/latest/miscellaneous.html#layout-of-state-variables-in-storage
            switch add(lt(slength, 32), lt(newlength, 32))
            case 2 {
                // Since the new array still fits in the slot, we just need to
                // update the contents of the slot.
                // uint256(bytes_storage) = uint256(bytes_storage) + uint256(bytes_memory) + new_length
                sstore(
                    _preBytes.slot,
                    // all the modifications to the slot are inside this
                    // next block
                    add(
                        // we can just add to the slot contents because the
                        // bytes we want to change are the LSBs
                        fslot,
                        add(
                            mul(
                                div(
                                    // load the bytes from memory
                                    mload(add(_postBytes, 0x20)),
                                    // zero all bytes to the right
                                    exp(0x100, sub(32, mlength))
                                ),
                                // and now shift left the number of bytes to
                                // leave space for the length in the slot
                                exp(0x100, sub(32, newlength))
                            ),
                            // increase length by the double of the memory
                            // bytes length
                            mul(mlength, 2)
                        )
                    )
                )
            }
            case 1 {
                // The stored value fits in the slot, but the combined value
                // will exceed it.
                // get the keccak hash to get the contents of the array
                mstore(0x0, _preBytes.slot)
                let sc := add(keccak256(0x0, 0x20), div(slength, 32))

                // save new length
                sstore(_preBytes.slot, add(mul(newlength, 2), 1))

                // The contents of the _postBytes array start 32 bytes into
                // the structure. Our first read should obtain the `submod`
                // bytes that can fit into the unused space in the last word
                // of the stored array. To get this, we read 32 bytes starting
                // from `submod`, so the data we read overlaps with the array
                // contents by `submod` bytes. Masking the lowest-order
                // `submod` bytes allows us to add that value directly to the
                // stored value.

                let submod := sub(32, slength)
                let mc := add(_postBytes, submod)
                let end := add(_postBytes, mlength)
                let mask := sub(exp(0x100, submod), 1)

                sstore(
                    sc,
                    add(
                        and(
                            fslot,
                            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00
                        ),
                        and(mload(mc), mask)
                    )
                )

                for {
                    mc := add(mc, 0x20)
                    sc := add(sc, 1)
                } lt(mc, end) {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } {
                    sstore(sc, mload(mc))
                }

                mask := exp(0x100, sub(mc, end))

                sstore(sc, mul(div(mload(mc), mask), mask))
            }
            default {
                // get the keccak hash to get the contents of the array
                mstore(0x0, _preBytes.slot)
                // Start copying to the last used word of the stored array.
                let sc := add(keccak256(0x0, 0x20), div(slength, 32))

                // save new length
                sstore(_preBytes.slot, add(mul(newlength, 2), 1))

                // Copy over the first `submod` bytes of the new data as in
                // case 1 above.
                let slengthmod := mod(slength, 32)
                let mlengthmod := mod(mlength, 32)
                let submod := sub(32, slengthmod)
                let mc := add(_postBytes, submod)
                let end := add(_postBytes, mlength)
                let mask := sub(exp(0x100, submod), 1)

                sstore(sc, add(sload(sc), and(mload(mc), mask)))

                for {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } lt(mc, end) {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } {
                    sstore(sc, mload(mc))
                }

                mask := exp(0x100, sub(mc, end))

                sstore(sc, mul(div(mload(mc), mask), mask))
            }
        }
    }

    function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    )
        internal
        pure
        returns (bytes memory)
    {
        require(_length + 31 >= _length, "slice_overflow");
        require(_bytes.length >= _start + _length, "slice_outOfBounds");

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // The first word of the slice result is potentially a partial
                // word read from the original array. To read it, we calculate
                // the length of that partial word and start copying that many
                // bytes into the array. The first word we copy will start with
                // data we don't care about, but the last `lengthmod` bytes will
                // land at the beginning of the contents of the new array. When
                // we're done copying, we overwrite the full first word with
                // the actual length of the slice.
                let lengthmod := and(_length, 31)

                // The multiplication in the next line is necessary
                // because when slicing multiples of 32 bytes (lengthmod == 0)
                // the following copy loop was copying the origin's length
                // and then ending prematurely not copying everything it should.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // The multiplication in the next line has the same exact purpose
                    // as the one above.
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(tempBytes, _length)

                //update free-memory pointer
                //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)
                //zero out the 32 bytes slice we are about to return
                //we need to do it because Solidity does not garbage collect
                mstore(tempBytes, 0)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }

    function toAddress(bytes memory _bytes, uint256 _start) internal pure returns (address) {
        require(_bytes.length >= _start + 20, "toAddress_outOfBounds");
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }

    function toUint8(bytes memory _bytes, uint256 _start) internal pure returns (uint8) {
        require(_bytes.length >= _start + 1 , "toUint8_outOfBounds");
        uint8 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x1), _start))
        }

        return tempUint;
    }

    function toUint16(bytes memory _bytes, uint256 _start) internal pure returns (uint16) {
        require(_bytes.length >= _start + 2, "toUint16_outOfBounds");
        uint16 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x2), _start))
        }

        return tempUint;
    }

    function toUint32(bytes memory _bytes, uint256 _start) internal pure returns (uint32) {
        require(_bytes.length >= _start + 4, "toUint32_outOfBounds");
        uint32 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x4), _start))
        }

        return tempUint;
    }

    function toUint64(bytes memory _bytes, uint256 _start) internal pure returns (uint64) {
        require(_bytes.length >= _start + 8, "toUint64_outOfBounds");
        uint64 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x8), _start))
        }

        return tempUint;
    }

    function toUint96(bytes memory _bytes, uint256 _start) internal pure returns (uint96) {
        require(_bytes.length >= _start + 12, "toUint96_outOfBounds");
        uint96 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0xc), _start))
        }

        return tempUint;
    }

    function toUint128(bytes memory _bytes, uint256 _start) internal pure returns (uint128) {
        require(_bytes.length >= _start + 16, "toUint128_outOfBounds");
        uint128 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x10), _start))
        }

        return tempUint;
    }

    function toUint256(bytes memory _bytes, uint256 _start) internal pure returns (uint256) {
        require(_bytes.length >= _start + 32, "toUint256_outOfBounds");
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }

    function toBytes32(bytes memory _bytes, uint256 _start) internal pure returns (bytes32) {
        require(_bytes.length >= _start + 32, "toBytes32_outOfBounds");
        bytes32 tempBytes32;

        assembly {
            tempBytes32 := mload(add(add(_bytes, 0x20), _start))
        }

        return tempBytes32;
    }

    function equal(bytes memory _preBytes, bytes memory _postBytes) internal pure returns (bool) {
        bool success = true;

        assembly {
            let length := mload(_preBytes)

            // if lengths don't match the arrays are not equal
            switch eq(length, mload(_postBytes))
            case 1 {
                // cb is a circuit breaker in the for loop since there's
                //  no said feature for inline assembly loops
                // cb = 1 - don't breaker
                // cb = 0 - break
                let cb := 1

                let mc := add(_preBytes, 0x20)
                let end := add(mc, length)

                for {
                    let cc := add(_postBytes, 0x20)
                // the next line is the loop condition:
                // while(uint256(mc < end) + cb == 2)
                } eq(add(lt(mc, end), cb), 2) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    // if any of these checks fails then arrays are not equal
                    if iszero(eq(mload(mc), mload(cc))) {
                        // unsuccess:
                        success := 0
                        cb := 0
                    }
                }
            }
            default {
                // unsuccess:
                success := 0
            }
        }

        return success;
    }

    function equalStorage(
        bytes storage _preBytes,
        bytes memory _postBytes
    )
        internal
        view
        returns (bool)
    {
        bool success = true;

        assembly {
            // we know _preBytes_offset is 0
            let fslot := sload(_preBytes.slot)
            // Decode the length of the stored array like in concatStorage().
            let slength := div(and(fslot, sub(mul(0x100, iszero(and(fslot, 1))), 1)), 2)
            let mlength := mload(_postBytes)

            // if lengths don't match the arrays are not equal
            switch eq(slength, mlength)
            case 1 {
                // slength can contain both the length and contents of the array
                // if length < 32 bytes so let's prepare for that
                // v. http://solidity.readthedocs.io/en/latest/miscellaneous.html#layout-of-state-variables-in-storage
                if iszero(iszero(slength)) {
                    switch lt(slength, 32)
                    case 1 {
                        // blank the last byte which is the length
                        fslot := mul(div(fslot, 0x100), 0x100)

                        if iszero(eq(fslot, mload(add(_postBytes, 0x20)))) {
                            // unsuccess:
                            success := 0
                        }
                    }
                    default {
                        // cb is a circuit breaker in the for loop since there's
                        //  no said feature for inline assembly loops
                        // cb = 1 - don't breaker
                        // cb = 0 - break
                        let cb := 1

                        // get the keccak hash to get the contents of the array
                        mstore(0x0, _preBytes.slot)
                        let sc := keccak256(0x0, 0x20)

                        let mc := add(_postBytes, 0x20)
                        let end := add(mc, mlength)

                        // the next line is the loop condition:
                        // while(uint256(mc < end) + cb == 2)
                        for {} eq(add(lt(mc, end), cb), 2) {
                            sc := add(sc, 1)
                            mc := add(mc, 0x20)
                        } {
                            if iszero(eq(sload(sc), mload(mc))) {
                                // unsuccess:
                                success := 0
                                cb := 0
                            }
                        }
                    }
                }
            }
            default {
                // unsuccess:
                success := 0
            }
        }

        return success;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

/// @title Base64
/// @author Brecht Devos - <[email protected]>
/// @notice Provides functions for encoding/decoding base64
library Base64 {
    string internal constant TABLE_ENCODE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    bytes  internal constant TABLE_DECODE = hex"0000000000000000000000000000000000000000000000000000000000000000"
                                            hex"00000000000000000000003e0000003f3435363738393a3b3c3d000000000000"
                                            hex"00000102030405060708090a0b0c0d0e0f101112131415161718190000000000"
                                            hex"001a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132330000000000";

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';

        // load the table into memory
        string memory table = TABLE_ENCODE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 3 bytes at a time
            for {} lt(dataPtr, endPtr) {}
            {
                // read 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // write 4 characters
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr( 6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(        input,  0x3F))))
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }

        return result;
    }

    function decode(string memory _data) internal pure returns (bytes memory) {
        bytes memory data = bytes(_data);

        if (data.length == 0) return new bytes(0);
        require(data.length % 4 == 0, "invalid base64 decoder input");

        // load the table into memory
        bytes memory table = TABLE_DECODE;

        // every 4 characters represent 3 bytes
        uint256 decodedLen = (data.length / 4) * 3;

        // add some extra buffer at the end required for the writing
        bytes memory result = new bytes(decodedLen + 32);

        assembly {
            // padding with '='
            let lastBytes := mload(add(data, mload(data)))
            if eq(and(lastBytes, 0xFF), 0x3d) {
                decodedLen := sub(decodedLen, 1)
                if eq(and(lastBytes, 0xFFFF), 0x3d3d) {
                    decodedLen := sub(decodedLen, 1)
                }
            }

            // set the actual output length
            mstore(result, decodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 4 characters at a time
            for {} lt(dataPtr, endPtr) {}
            {
               // read 4 characters
               dataPtr := add(dataPtr, 4)
               let input := mload(dataPtr)

               // write 3 bytes
               let output := add(
                   add(
                       shl(18, and(mload(add(tablePtr, and(shr(24, input), 0xFF))), 0xFF)),
                       shl(12, and(mload(add(tablePtr, and(shr(16, input), 0xFF))), 0xFF))),
                   add(
                       shl( 6, and(mload(add(tablePtr, and(shr( 8, input), 0xFF))), 0xFF)),
                               and(mload(add(tablePtr, and(        input , 0xFF))), 0xFF)
                    )
                )
                mstore(resultPtr, shl(232, output))
                resultPtr := add(resultPtr, 3)
            }
        }

        return result;
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                         METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    function tokenURI(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) internal _ownerOf;

    mapping(address => uint256) internal _balanceOf;

    function ownerOf(uint256 id) public view virtual returns (address owner) {
        require((owner = _ownerOf[id]) != address(0), "NOT_MINTED");
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");

        return _balanceOf[owner];
    }

    /*//////////////////////////////////////////////////////////////
                         ERC721 APPROVAL STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 id) public virtual {
        address owner = _ownerOf[id];

        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        require(from == _ownerOf[id], "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        require(
            msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id],
            "NOT_AUTHORIZED"
        );

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            _balanceOf[from]--;

            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id) internal virtual {
        require(to != address(0), "INVALID_RECIPIENT");

        require(_ownerOf[id] == address(0), "ALREADY_MINTED");

        // Counter overflow is incredibly unrealistic.
        unchecked {
            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    function _burn(uint256 id) internal virtual {
        address owner = _ownerOf[id];

        require(owner != address(0), "NOT_MINTED");

        // Ownership check above ensures no underflow.
        unchecked {
            _balanceOf[owner]--;
        }

        delete _ownerOf[id];

        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _safeMint(
        address to,
        uint256 id,
        bytes memory data
    ) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}