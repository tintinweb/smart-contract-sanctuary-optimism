// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableAdmins {
    address[] private _admins;

    event AdminAdded(address indexed newAdmin);
    event AdminRemoved(address indexed oldAdmin);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _addAdmin(msg.sender);
    }

    modifier onlyAdmins() {
        require(isAdmin(address(msg.sender)), "Caller is not Admin");
        _;
    }

    function isAdmin(address _Admin) public view virtual returns (bool) {
        uint8 totalAdmins = uint8(_admins.length);

        for (uint8 i = 0; i < totalAdmins; ) {
            if (_admins[i] == _Admin) return true;

            unchecked {
                i++;
            }
        }

        return false;
    }

    function removeAdmin(address oldAdmin) public virtual onlyAdmins {
        uint8 totalAdmins = uint8(_admins.length);

        for (uint8 i = 0; i < totalAdmins; ) {
            if (_admins[i] == oldAdmin) {
                _admins[i] = _admins[totalAdmins - 1];
                _admins.pop();

                break;
            }

            unchecked {
                i++;
            }
        }

        emit AdminRemoved(oldAdmin);
    }

    function addAdmin(address newAdmin) public virtual onlyAdmins {
        uint8 totalAdmins = uint8(_admins.length);

        for (uint8 i = 0; i < totalAdmins; i++) {
            if (_admins[i] == newAdmin) return;

            unchecked {
                i++;
            }
        }

        _addAdmin(newAdmin);
    }

    function _addAdmin(address newAdmin) internal virtual {
        _admins.push(newAdmin);
        emit AdminAdded(newAdmin);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./OwnableAdmin.sol";
import "solmate/src/tokens/ERC20.sol";
import "solmate/src/tokens/ERC721.sol";

error NotWhitelisted(address minter);
error CallerHasMinted(address minter);
error CallerIsNotAdmin(address caller);
error MintLimitReached(uint256 mintLimit);
error NotOnWhitelist(address addressToRemove);
error WhitelistLimitReached(uint256 whitelistLimit);
error AlreadyWhitelisted(address whitelistedAddress);

contract StrandsFirst100 is ERC721, OwnableAdmins {
    string public baseURI;
    uint256 public feeAmount = 10;
    uint256 private mintCounter;
    uint256 private whitelistCounter;
    // USDC, Ethereum mainnet address
    address public feeToken = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address public feeRecipient = 0x3960b0Eac90Aae9FeE27D0AeDBb81d951B72862A;

    mapping(address => bool) whitelist;
    mapping(address => bool) hasMinted;

    constructor(string memory _baseURI) ERC721("Strands First 100", "F100") {
        baseURI = _baseURI;
        _addAdmin(msg.sender);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return baseURI;
    }

    function setTokenURI(string memory _newBaseURI) external {
        if (isAdmin(msg.sender) == false) revert CallerIsNotAdmin(msg.sender);
        baseURI = _newBaseURI;
    }

    function isWhitelisted(address _a) public view virtual returns (bool) {
        bool isWhitelisted_ = whitelist[_a];

        if (isWhitelisted_) {
            return isWhitelisted_;
        } else {
            return false;
        }
    }

    function addToWhitelist(address[] memory _toWhitelist)
        external
        returns (bool)
    {
        if (isAdmin(msg.sender) == false) revert CallerIsNotAdmin(msg.sender);
        if (whitelistCounter > 99)
            revert WhitelistLimitReached(whitelistCounter);

        uint256 addresses = _toWhitelist.length;

        for (uint256 i = 0; i < addresses; i++) {
            address a_ = _toWhitelist[i]; // Get address to whitelist

            // Revert if the address has been whitelisted
            if (isWhitelisted(a_)) revert AlreadyWhitelisted(a_);

            whitelistCounter += 1; // Increment counter for whitelist
            whitelist[a_] = true; // Add to whitelist
        }

        return true; // Confirmation that function added addresses to whitelist
    }

    function removeFromWhitelist(address[] memory _toWhitelist)
        external
        returns (bool)
    {
        if (isAdmin(msg.sender) == false) revert CallerIsNotAdmin(msg.sender);
        if (whitelistCounter > 99)
            revert WhitelistLimitReached(whitelistCounter);

        uint256 addresses = _toWhitelist.length;

        for (uint256 i = 0; i < addresses; i++) {
            // Get address to remove from whitelist
            address a_ = _toWhitelist[i];

            if (whitelist[a_] == false) revert NotOnWhitelist(a_);

            whitelistCounter -= 1; // Decrement counter for whitelist
            whitelist[a_] = false;
        }

        return true;
    }

    function mint() external {
        address _to = msg.sender;

        if (!isWhitelisted(_to)) revert NotWhitelisted(_to);
        if (hasMinted[_to]) revert CallerHasMinted(_to);
        if (mintCounter > 99) revert MintLimitReached(mintCounter);

        mintCounter += 1;
        hasMinted[_to] = true;

        _safeMint(_to, mintCounter);
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }

    function _burn(uint256 id) internal virtual override {
        address owner = _ownerOf[id];

        require(owner != address(0) || isAdmin(msg.sender), "NOT_MINTED");

        // Ownership check above ensures no underflow.
        unchecked {
            _balanceOf[owner]--;
        }

        mintCounter -= 1;

        delete hasMinted[owner];
        delete _ownerOf[id];
        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual override {
        require(from == _ownerOf[id], "WRONG_FROM");
        require(to != address(0), "INVALID_RECIPIENT");
        require(
            msg.sender == from ||
                isApprovedForAll[from][msg.sender] ||
                msg.sender == getApproved[id],
            "NOT_AUTHORIZED"
        );

        ERC20(feeToken).transferFrom(from, feeRecipient, feeAmount);

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

    function setFeeRecipient(address _newRecipient) public {
        if (isAdmin(msg.sender) == false) revert CallerIsNotAdmin(msg.sender);
        feeRecipient = _newRecipient;
    }

    function setFeeAmount(uint256 _newAmount) public {
        if (isAdmin(msg.sender) == false) revert CallerIsNotAdmin(msg.sender);
        feeAmount = _newAmount;
    }

    function setFeeToken(address _newToken) public {
        if (isAdmin(msg.sender) == false) revert CallerIsNotAdmin(msg.sender);
        feeToken = _newToken;
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

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