// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {Owned} from "./Owned.sol";
import {Blocklist} from "./Blocklist.sol";
import {Forwarder} from "./Forwarder.sol";
import {ContractMetadata} from "./ContractMetadata.sol";

/*
 /$$$$$$$                                  /$$     /$$                    
| $$__  $$                                | $$    |__/                    
| $$  \ $$  /$$$$$$  /$$   /$$ /$$$$$$$  /$$$$$$   /$$  /$$$$$$   /$$$$$$$
| $$$$$$$  /$$__  $$| $$  | $$| $$__  $$|_  $$_/  | $$ /$$__  $$ /$$_____/
| $$__  $$| $$  \ $$| $$  | $$| $$  \ $$  | $$    | $$| $$$$$$$$|  $$$$$$ 
| $$  \ $$| $$  | $$| $$  | $$| $$  | $$  | $$ /$$| $$| $$_____/ \____  $$
| $$$$$$$/|  $$$$$$/|  $$$$$$/| $$  | $$  |  $$$$/| $$|  $$$$$$$ /$$$$$$$/
|_______/  \______/  \______/ |__/  |__/   \___/  |__/ \_______/|_______/ 
*/

/// @custom:security-contact [email protected]
contract Bounties is ERC721, Owned, Blocklist, Forwarder, ContractMetadata {
  event URI(string value, uint256 id);
  event ChangedVisibility(uint256 id, Visibility v);
  event AirlockAdded(uint256 id, address indexed airlock);

  enum Visibility {
    Loud,
    Quiet
  }

  // tokens
  uint256 private counter;
  uint256 private totalCounter;
  mapping(uint256 => string) public tokenURIs;
  mapping(uint256 => Visibility) public visibility;
  mapping(uint256 => bool) public isToken;

  mapping(uint256 => address[]) public airlocks;

  // modifiers
  modifier canAlter(uint256 tokenId) {
    require(
      _msgSender() == owner || _msgSender() == ownerOf(tokenId),
      "unauthorized"
    );
    _;
  }

  // lets set this up
  constructor()
    ERC721("Bounties", "BNTS")
    Owned(msg.sender)
    ContractMetadata("ipfs://")
  {}

  // create, edit and remove a bounty
  function create(string memory uri) external whenNotPaused returns (uint256) {
    uint256 tokenId = counter;

    unchecked {
      counter += 1;
      totalCounter += 1;
    }

    _safeMint(_msgSender(), tokenId);
    _setTokenURI(tokenId, uri);
    isToken[tokenId] = true;
    return tokenId;
  }

  function edit(uint256 tokenId, string memory uri)
    external
    whenNotPaused
    canAlter(tokenId)
  {
    _setTokenURI(tokenId, uri);
    emit URI(uri, tokenId);
  }

  function remove(uint256 tokenId) external whenNotPaused canAlter(tokenId) {
    super._burn(tokenId);
    isToken[tokenId] = false;
    unchecked {
      totalCounter -= 1;
    }
  }

  function totalSupply() external view returns (uint256) {
    return totalCounter;
  }

  function changeVisibility(uint256 tokenId, Visibility v)
    external
    whenNotPaused
    canAlter(tokenId)
  {
    visibility[tokenId] = v;
    emit ChangedVisibility(tokenId, v);
  }

  function addAirlock(uint256 tokenId, address airlock)
    public
    whenNotPaused
    canAlter(tokenId)
  {
    airlocks[tokenId].push(airlock);
    emit AirlockAdded(tokenId, airlock);
  }

  function getAirlock(uint256 tokenId, uint256 index)
    public
    view
    returns (address)
  {
    if (index < airlocks[tokenId].length) {
      return airlocks[tokenId][index];
    } else {
      return address(0);
    }
  }

  // for holding the URIs
  function _setTokenURI(uint256 tokenId, string memory uri) internal {
    tokenURIs[tokenId] = uri;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(isToken[tokenId], "does not exist");
    return tokenURIs[tokenId];
  }

  // overrides for ERC721
  // taken from Solmate with tweaks
  function approve(address spender, uint256 id)
    public
    virtual
    override(ERC721)
    whenNotPaused
  {
    address o = _ownerOf[id];

    require(
      _msgSender() == o ||
        _msgSender() == owner ||
        isApprovedForAll[o][_msgSender()],
      "unauthorized"
    );

    getApproved[id] = spender;

    emit Approval(o, spender, id);
  }

  function transferFrom(
    address from,
    address to,
    uint256 id
  ) public virtual override(ERC721) whenNotPaused {
    require(from == _ownerOf[id], "invalid");
    require(to != address(0), "invalid");

    require(
      _msgSender() == from ||
        isApprovedForAll[from][_msgSender()] ||
        _msgSender() == owner ||
        _msgSender() == getApproved[id],
      "unauthorized"
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
  ) public virtual override(ERC721) whenNotPaused {
    super.safeTransferFrom(from, to, id);
  }

  function safeTransferFrom(
    address from,
    address to,
    uint256 id,
    bytes calldata data
  ) public virtual override(ERC721) whenNotPaused {
    super.safeTransferFrom(from, to, id, data);
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BaseRelayRecipient} from "@opengsn/contracts/BaseRelayRecipient.sol";

/*
  /$$$$$$                                          /$$
 /$$__  $$                                        | $$
| $$  \ $$ /$$  /$$  /$$ /$$$$$$$   /$$$$$$   /$$$$$$$
| $$  | $$| $$ | $$ | $$| $$__  $$ /$$__  $$ /$$__  $$
| $$  | $$| $$ | $$ | $$| $$  \ $$| $$$$$$$$| $$  | $$
| $$  | $$| $$ | $$ | $$| $$  | $$| $$_____/| $$  | $$
|  $$$$$$/|  $$$$$/$$$$/| $$  | $$|  $$$$$$$|  $$$$$$$
 \______/  \_____/\___/ |__/  |__/ \_______/ \_______/
*/

abstract contract Owned is BaseRelayRecipient {
    event OwnerUpdated(address from, address to);

    // administration if ever needed
    bool public isPaused = false;
    address public owner;

    modifier onlyOwner() {
        require(_msgSender() == owner, "unauthorized");
        _;
    }

    modifier whenNotPaused() {
        require(!isPaused, "is paused");
        _;
    }

    constructor(address incomingOwner) {
        require(incomingOwner != address(0), "must be non-zero address");
        owner = incomingOwner;
    }

    // admin func
    // for emergencies
    function pause() external onlyOwner {
        isPaused = true;
    }

    function unpause() external onlyOwner {
        isPaused = false;
    }

    // move to elsewhere
    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "must be non-zero address");
        address p = owner;
        owner = newOwner;
        emit OwnerUpdated(p, owner);
    }

    function renounceOwnership() external onlyOwner {
        address p = owner;
        owner = address(0);
        emit OwnerUpdated(p, owner);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Owned.sol";

/* 
 /$$$$$$$  /$$                     /$$       /$$ /$$             /$$    
| $$__  $$| $$                    | $$      | $$|__/            | $$    
| $$  \ $$| $$  /$$$$$$   /$$$$$$$| $$   /$$| $$ /$$  /$$$$$$$ /$$$$$$  
| $$$$$$$ | $$ /$$__  $$ /$$_____/| $$  /$$/| $$| $$ /$$_____/|_  $$_/  
| $$__  $$| $$| $$  \ $$| $$      | $$$$$$/ | $$| $$|  $$$$$$   | $$    
| $$  \ $$| $$| $$  | $$| $$      | $$_  $$ | $$| $$ \____  $$  | $$ /$$
| $$$$$$$/| $$|  $$$$$$/|  $$$$$$$| $$ \  $$| $$| $$ /$$$$$$$/  |  $$$$/
|_______/ |__/ \______/  \_______/|__/  \__/|__/|__/|_______/    \___/  
*/

abstract contract Blocklist is Owned {
    mapping(address => bool) internal blocked;

    modifier checkBlock() {
        // TOO BUSY MMMMBLOCKING OUT THE HATERS
        // https://www.youtube.com/watch?v=MtA5Xze0C4g
        require(!blocked[_msgSender()], "blocked address");
        _;
    }

    function amIBlocked() external view returns (bool) {
        return blocked[_msgSender()];
    }

    function addBlocked(address[] memory addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != owner, "cannot be owner");
            blocked[addresses[i]] = true;
        }
    }

    function removeBlocked(address[] memory addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            blocked[addresses[i]] = false;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BaseRelayRecipient} from "@opengsn/contracts/BaseRelayRecipient.sol";

abstract contract Forwarder is BaseRelayRecipient {
  address public admin;

  modifier onlyAdmin() {
    require(msg.sender == admin, "only admin");
    _;
  }

  function updateAdmin(address _admin) external onlyAdmin {
    admin = _admin;
  }

  function setForwarder(address forwarder) external onlyAdmin {
    _setTrustedForwarder(forwarder);
  }

  function versionRecipient() external pure override returns (string memory) {
    return "2.2.5";
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Owned.sol";

/*
$$\      $$\            $$\                     $$\            $$\               
$$$\    $$$ |           $$ |                    $$ |           $$ |              
$$$$\  $$$$ | $$$$$$\ $$$$$$\    $$$$$$\   $$$$$$$ | $$$$$$\ $$$$$$\    $$$$$$\  
$$\$$\$$ $$ |$$  __$$\\_$$  _|   \____$$\ $$  __$$ | \____$$\\_$$  _|   \____$$\ 
$$ \$$$  $$ |$$$$$$$$ | $$ |     $$$$$$$ |$$ /  $$ | $$$$$$$ | $$ |     $$$$$$$ |
$$ |\$  /$$ |$$   ____| $$ |$$\ $$  __$$ |$$ |  $$ |$$  __$$ | $$ |$$\ $$  __$$ |
$$ | \_/ $$ |\$$$$$$$\  \$$$$  |\$$$$$$$ |\$$$$$$$ |\$$$$$$$ | \$$$$  |\$$$$$$$ |
\__|     \__| \_______|  \____/  \_______| \_______| \_______|  \____/  \_______|
*/

abstract contract ContractMetadata is Owned {
    // contract metadata
    string public contractMetadata;

    constructor(string memory uri) {
        updateContractURI(uri);
    }

    function contractURI() external view returns (string memory) {
        return contractMetadata;
    }

    function updateContractURI(string memory uri) public onlyOwner {
        contractMetadata = uri;
    }
}

// SPDX-License-Identifier: MIT
// solhint-disable no-inline-assembly
pragma solidity >=0.6.9;

import "./interfaces/IRelayRecipient.sol";

/**
 * A base contract to be inherited by any contract that want to receive relayed transactions
 * A subclass must use "_msgSender()" instead of "msg.sender"
 */
abstract contract BaseRelayRecipient is IRelayRecipient {

    /*
     * Forwarder singleton we accept calls from
     */
    address private _trustedForwarder;

    function trustedForwarder() public virtual view returns (address){
        return _trustedForwarder;
    }

    function _setTrustedForwarder(address _forwarder) internal {
        _trustedForwarder = _forwarder;
    }

    function isTrustedForwarder(address forwarder) public virtual override view returns(bool) {
        return forwarder == _trustedForwarder;
    }

    /**
     * return the sender of this call.
     * if the call came through our trusted forwarder, return the original sender.
     * otherwise, return `msg.sender`.
     * should be used in the contract anywhere instead of msg.sender
     */
    function _msgSender() internal override virtual view returns (address ret) {
        if (msg.data.length >= 20 && isTrustedForwarder(msg.sender)) {
            // At this point we know that the sender is a trusted forwarder,
            // so we trust that the last bytes of msg.data are the verified sender address.
            // extract sender address from the end of msg.data
            assembly {
                ret := shr(96,calldataload(sub(calldatasize(),20)))
            }
        } else {
            ret = msg.sender;
        }
    }

    /**
     * return the msg.data of this call.
     * if the call came through our trusted forwarder, then the real sender was appended as the last 20 bytes
     * of the msg.data - so this method will strip those 20 bytes off.
     * otherwise (if the call was made directly and not through the forwarder), return `msg.data`
     * should be used in the contract instead of msg.data, where this difference matters.
     */
    function _msgData() internal override virtual view returns (bytes calldata ret) {
        if (msg.data.length >= 20 && isTrustedForwarder(msg.sender)) {
            return msg.data[0:msg.data.length-20];
        } else {
            return msg.data;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

/**
 * a contract must implement this interface in order to support relayed transaction.
 * It is better to inherit the BaseRelayRecipient as its implementation.
 */
abstract contract IRelayRecipient {

    /**
     * return if the forwarder is trusted to forward relayed transactions to us.
     * the forwarder is required to verify the sender's signature, and verify
     * the call is not a replay.
     */
    function isTrustedForwarder(address forwarder) public virtual view returns(bool);

    /**
     * return the sender of this call.
     * if the call came through our trusted forwarder, then the real sender is appended as the last 20 bytes
     * of the msg.data.
     * otherwise, return `msg.sender`
     * should be used in the contract anywhere instead of msg.sender
     */
    function _msgSender() internal virtual view returns (address);

    /**
     * return the msg.data of this call.
     * if the call came through our trusted forwarder, then the real sender was appended as the last 20 bytes
     * of the msg.data - so this method will strip those 20 bytes off.
     * otherwise (if the call was made directly and not through the forwarder), return `msg.data`
     * should be used in the contract instead of msg.data, where this difference matters.
     */
    function _msgData() internal virtual view returns (bytes calldata);

    function versionRecipient() external virtual view returns (string memory);
}