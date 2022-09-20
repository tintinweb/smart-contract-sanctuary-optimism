/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-09-20
*/

pragma solidity ^0.8.17;

/// [MIT License]
/// @title Base64
/// @notice Provides a function for encoding some bytes in base64
/// @author Brecht Devos <[email protected]>
library Base64 {
    bytes internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
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
}

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
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
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
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

/// @notice Gas optimized reentrancy protection for smart contracts.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol)
abstract contract ReentrancyGuard {
    uint256 private locked = 1;

    modifier nonReentrant() virtual {
        require(locked == 1, "REENTRANCY");

        locked = 2;

        _;

        locked = 1;
    }
}

/// @title Whitenoise Challenge NFT
/// @author clabby <https://github.com/clabby>
/// @author asnared <https://github.com/abigger87>
/// ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
/// ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠈⠻⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
/// ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⢷⣤⡀⠀⠉⠛⠿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
/// ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣇⡀⠀⠉⠁⠀⠀⠀⠀⠈⠙⠻⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⠋⠁⣸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
/// ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡛⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⣿⣿⠟⠛⠋⠉⠉⠁⠀⢀⣠⣴⠾⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
/// ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⡶⠖⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠁⠀⠀⠀⠀⠀⠀⠀⠀⠠⣤⣤⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
/// ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⠀⠀⠀⠀⠀⠀⠀⠠⣀⠀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
/// ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⣠⠀⠀⠀⠀⠀⠀⠀⠀⠻⠀⠀⠀⠀⠀⠀⠀⠀⢈⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
/// ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣶⠶⠂⠀⠀⠀⠀⢀⡄⠀⠀⠀⡀⠀⣱⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
/// ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠛⠋⠉⠁⠀⠀⠀⠀⠀⠀⠀⠙⢿⣷⣶⣶⣾⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
/// ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠶⠒⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
/// ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣴⠂⠀⠠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠈⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
/// ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⣀⣴⠇⠀⢠⡇⠀⠀⣶⠀⠀⢧⡀⢈⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
/// ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣤⣿⡇⠀⢰⣿⣇⣀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
/// ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
contract WhitenoiseNFT is ERC721, ReentrancyGuard {
    ////////////////////////////////////////////////////////////////
    //                         VARIABLES                          //
    ////////////////////////////////////////////////////////////////

    uint256 public immutable END_TIME;

    /// @notice The owner of the NFT contract (Should be the challenge contract!)
    address public owner;

    /// @notice The total supply of the NFT
    uint256 public currentId;

    /// @notice The number of chads who have solved the challenge.
    uint256 public numChads;

    /// @notice Stores all solutions.
    ///         The last Chad submitted the most optimized solver.
    ///         The first Chad is the initial exploiter.
    mapping(uint256 => Chad) public leaderboard;

    ////////////////////////////////////////////////////////////////
    //                          STRUCTS                           //
    ////////////////////////////////////////////////////////////////

    /// @notice Represents a Chad who solved the challenge.
    struct Chad {
        address solver;
        uint128 score;
        uint64 gasUsed;
        uint64 codeSize;
    }

    ////////////////////////////////////////////////////////////////
    //                           ERRORS                           //
    ////////////////////////////////////////////////////////////////

    /// @notice Error thrown when a function protected by the `onlyOwner`
    ///         modifier is called by an address that is not the owner.
    error OnlyOwner();

    /// @notice Error thrown when a function that can only be executed
    ///         during the challenge is executed afterwards.
    error OnlyDuringChallenge();

    /// @notice Error thrown when a function that can only be executed
    ///         after the challenge has completed is executed beforehand.
    error OnlyAfterChallenge();

    /// @notice Error thrown when an EOA who is not the current Chad attempts
    ///         to claim the Optimizer NFT after the Challenge has concluded.
    error NotTheChad();

    /// @notice Error thrown when the max NFT supply has been reached.
    error MaxSupply();

    /// @notice Error thrown if transfer function is called.
    error Soulbound();

    ////////////////////////////////////////////////////////////////
    //                           EVENTS                           //
    ////////////////////////////////////////////////////////////////

    /// @notice Event emitted when the first solve occurs.
    event FirstSolve(address indexed solver);

    /// @notice Event emitted when a new optimal solution has been submitted.
    event NewLeader(address indexed solver, uint256 gasUsed, uint256 codeSize);

    ////////////////////////////////////////////////////////////////
    //                         MODIFIERS                          //
    ////////////////////////////////////////////////////////////////

    /// @notice Asserts that msg.sender is the owner.
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert OnlyOwner();
        }
        _;
    }

    ////////////////////////////////////////////////////////////////
    //                        CONSTRUCTOR                         //
    ////////////////////////////////////////////////////////////////

    constructor() ERC721("Doves in the Wind", "DOVE") {
        END_TIME = block.timestamp + 21 days;

        bool creatorIsEOA;
        assembly {
            creatorIsEOA := iszero(extcodesize(caller()))
        }

        // If the creator is an EOA, mint the creator edition (id = 0) and deploy as normal.
        // else, revert.
        if (creatorIsEOA) {
            _mintyFresh(msg.sender, 0);
            assembly {
                sstore(owner.slot, caller())
            }
        } else {
            assembly {
                revert(0x00, 0x00)
            }
        }
    }

    ////////////////////////////////////////////////////////////////
    //                          EXTERNAL                          //
    ////////////////////////////////////////////////////////////////

    /// @notice Get the token URI of a token ID
    function tokenURI(uint256 id) public pure override returns (string memory) {
        string memory name = "Optimizer";
        string memory description = "A Soulbound token demonstrating a mastery in optimization and evm wizardry. This address submitted the most optimized solution to the first Whitenoise challenge.";
        string memory img_url = "ipfs://QmT5v6ioQMUHgsYXTXL8oAaVAitxqK6NE7Q5bacUzTVgbA";

        // Check for creator special edition
        if (id == 0) {
            name = "Deployer";
            description = "Special Edition Soulbound Token for the Deployer of the first Whitenoise challenge.";
            img_url = "ipfs://QmR82jC87jEtgJFxhbUBThJCcavDCwut21VD3TvHSXsp43";
        }

        // Check for first solver special edition
        if (id == 1) {
            name = "Chad";
            description = "Special Edition Soulbound Token for the first solver of the first Whitenoise challenge.";
            img_url = "ipfs://QmT2vXZ52LTFfXPn6YAffHsWik5bYRFrp744rqbCaKy18i";
        }

        // Base64 Encode our JSON Metadata
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        name,
                        '", "description": "',
                        description,
                        '", "image": "',
                        img_url,
                        '", "external_url": "https://ctf.whitenoise.rs"}'
                    )
                )
            )
        );

        // Prepend data:application/json;base64 to define the base64 encoded data
        return string(
            abi.encodePacked("data:application/json;base64,", json)
        );
    }

    /// @notice Returns the current Chad.
    function theChad() public view returns (Chad memory chad) {
        uint256 _numChads = numChads;
        if (_numChads == 0) {
            return Chad({
                solver: address(0),
                score: type(uint128).max,
                gasUsed: type(uint64).max,
                codeSize: type(uint64).max
            });
        } else {
            return leaderboard[_numChads - 1];
        }
    }

    /// @notice Claim Optimizer NFT after the game has concluded.
    function claim() external {
        // Assert that the challenge has concluded.
        if (block.timestamp < END_TIME) {
            revert OnlyAfterChallenge();
        }

        Chad memory chad = theChad();
        if (chad.solver == msg.sender) {
            _mintyFresh(msg.sender, currentId);
        } else {
            revert NotTheChad();
        }
    }

    ////////////////////////////////////////////////////////////////
    //                           ADMIN                            //
    ////////////////////////////////////////////////////////////////

    /// @notice Submit a new solution.
    /// @dev Only callable by the owner of this contract (DovesInTheWind.huff)
    function submit(address _solver, uint256 gasUsed, uint256 codeSize)
        external
        onlyOwner
        nonReentrant
    {
        // Assert that the the challenge is not over
        if (block.timestamp >= END_TIME) {
            revert OnlyDuringChallenge();
        }

        uint256 _currentId = currentId;

        // If this is the first solve, emit a `FirstSolve` event with their address
        // and mint their NFT.
        if (_currentId == 1) {
            _mintyFresh(_solver, _currentId);
            emit FirstSolve(_solver);
        }

        // Copy `numChads` to the stack
        uint256 _numChads = numChads;

        // Add the new leader to the leaderboard.
        leaderboard[_numChads] = Chad({
            solver: _solver,
            score: uint128(gasUsed + codeSize),
            gasUsed: uint64(gasUsed),
            codeSize: uint64(codeSize)
        });

        // Increase number of Chads.
        // SAFETY: It is unrealistic that this will ever overflow.
        assembly {
            sstore(numChads.slot, add(_numChads, 0x01))
        }

        // Emit a `NewLeader` event.
        emit NewLeader(_solver, gasUsed, codeSize);
    }

    /// @notice Administrative function to transfer the ownership of the contract
    ///         over to the Challenge contract.
    function transferOwnership(address _newOwner) external onlyOwner {
        assembly {
            // Don't allow ownership transfer to a non-contract.
            if iszero(extcodesize(_newOwner)) { revert(0x00, 0x00) }

            // Once the owner is set to a contract, it can no longer be changed.
            if iszero(iszero(extcodesize(sload(owner.slot)))) { revert(0x00, 0x00) }
        }

        // Update the owner to a contract.
        owner = _newOwner;
    }

    ////////////////////////////////////////////////////////////////
    //                          INTERNAL                          //
    ////////////////////////////////////////////////////////////////

    // Make the NFT Soulbound by overriding transfer functionality
    function transferFrom(address, address, uint256) public override {
        revert Soulbound();
    }

    function _mintyFresh(address _to, uint256 _currentId) internal {
        if (currentId > 2) {
            revert MaxSupply();
        }

        // Safe Mint NFT with current ID
        _safeMint(_to, _currentId);

        // Update the currentId.
        // SAFETY: It is unrealistic that this will ever overflow.
        assembly {
            sstore(currentId.slot, add(_currentId, 0x01))
        }
    }
}