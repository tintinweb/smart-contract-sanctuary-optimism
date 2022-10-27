// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {Owned} from "./Owned.sol";
import {Forwarder} from "./Forwarder.sol";

struct Milestone {
  address by;
  string description;
  uint256 clientAgreed;
  uint256 workerAgreed;
  uint256 transferredAt;
}

struct Claim {
  uint256 milestoneId;
  address from;
  ClaimType contractType;
  address contractAddress;
  uint256 tokenId;
  uint256 value;
  string description;
  string uri;
}

enum FlowDirection {
  TowardsClient,
  TowardsWorker
}

enum ClaimType {
  ERC20,
  ERC721,
  ERC1155,
  OnChain,
  OffChain
}

enum ClaimVerification {
  NotVerified,
  PartVerified,
  ExactVerified,
  OverVerified
}

contract Airlock is Forwarder {
  event MilestoneAdded(uint256 id);
  event FlowAdded(address indexed flow);
  event WorkerChanged(address indexed worker);
  event ContractAgreed(uint256 timestamp);
  event MilestoneAgreed(uint256 id, address indexed by, uint256 timestamp);
  event MilestoneClaimsTransferred(uint256 id, uint256 timestamp);

  Milestone[] public milestones;

  AirlockFlow[] public flows;

  uint256 public milestonesCounter;
  uint256 public flowsCounter;

  address public client;
  AirlockFlow public clientFlow;

  address public worker;
  uint256 public workerAgreedAt;
  AirlockFlow public workerFlow;

  address public artibator;

  modifier onlyParty() {
    require(
      (_msgSender() == client || _msgSender() == worker) &&
        _msgSender() != address(0),
      "only one of the client or worker"
    );
    _;
  }

  modifier onlyClient() {
    require(_msgSender() == client, "only client");
    _;
  }

  modifier onlyWorker() {
    require(_msgSender() == worker, "only worker");
    _;
  }

  modifier notLocked() {
    require(workerAgreedAt == 0, "contract has been agreed to");
    _;
  }

  modifier onlyLocked() {
    require(workerAgreedAt > 0, "contract has to be agreed to");
    _;
  }

  constructor() {
    client = _msgSender();
  }

  function setWorker(address _worker) external onlyClient {
    require(worker == address(0), "worker has already been set");
    require(_worker != address(0), "worker can't be zero address");
    require(_worker != client, "worker can't be the same as the client");

    worker = _worker;

    emit WorkerChanged(worker);
  }

  function unsetWorker() external onlyWorker notLocked {
    worker = address(0);
    emit WorkerChanged(address(0));
  }

  function agreeToContract() external onlyWorker notLocked {
    workerAgreedAt = block.timestamp;
    emit ContractAgreed(block.timestamp);
  }

  function createMilestone(string memory description)
    external
    onlyParty
    notLocked
  {
    Milestone memory m = Milestone(_msgSender(), description, 0, 0, 0);
    milestones.push(m);

    emit MilestoneAdded(milestonesCounter);

    unchecked {
      milestonesCounter += 1;
    }
  }

  function createMilestones(string[] memory _descriptions)
    external
    onlyParty
    notLocked
  {
    require(_descriptions.length > 0);

    for (uint256 i = 0; i < _descriptions.length; i++) {
      Milestone memory m = Milestone(_msgSender(), _descriptions[i], 0, 0, 0);
      milestones.push(m);

      emit MilestoneAdded(milestonesCounter);

      unchecked {
        milestonesCounter += 1;
      }
    }
  }

  function createClaim(
    uint256 _milestoneId,
    ClaimType _contractType,
    address _contractAddress,
    uint256 _tokenId,
    uint256 _value,
    string calldata _description,
    string calldata _uri
  ) external onlyParty notLocked {
    AirlockFlow flow = createFlow();

    flow.createClaim(
      _milestoneId,
      _msgSender(),
      _contractType,
      _contractAddress,
      _tokenId,
      _value,
      _description,
      _uri
    );
  }

  function createFlow() private onlyParty returns (AirlockFlow) {
    if (_msgSender() == client) {
      return createClientFlow();
    } else {
      return createWorkerFlow();
    }
  }

  function createClientFlow() private onlyParty returns (AirlockFlow) {
    if (address(clientFlow) == address(0)) {
      clientFlow = new AirlockFlow(this, FlowDirection.TowardsWorker);
      emit FlowAdded(address(clientFlow));
    }

    return clientFlow;
  }

  function createWorkerFlow() private onlyParty returns (AirlockFlow) {
    if (address(workerFlow) == address(0)) {
      workerFlow = new AirlockFlow(this, FlowDirection.TowardsClient);
      emit FlowAdded(address(workerFlow));
    }

    return workerFlow;
  }

  function getFlow() public view onlyParty returns (AirlockFlow) {
    if (_msgSender() == client) {
      return clientFlow;
    } else {
      return workerFlow;
    }
  }

  function signOffMilestone(uint256 _milestoneId)
    external
    onlyParty
    onlyLocked
  {
    Milestone storage m = milestones[_milestoneId];

    if (_msgSender() == client) {
      if (m.clientAgreed <= 0) {
        m.clientAgreed = block.timestamp;
        emit MilestoneAgreed(_milestoneId, _msgSender(), block.timestamp);
      }
    } else {
      if (m.workerAgreed <= 0) {
        m.workerAgreed = block.timestamp;
        emit MilestoneAgreed(_milestoneId, _msgSender(), block.timestamp);
      }
    }

    if (m.workerAgreed > 0 && m.clientAgreed > 0 && m.transferredAt <= 0) {
      transferClaims(_milestoneId);
      m.transferredAt = block.timestamp;
      emit MilestoneClaimsTransferred(_milestoneId, block.timestamp);
    }
  }

  function transferClaims(uint256 _milestoneId) internal {
    if (address(clientFlow) != address(0)) {
      clientFlow.transferClaims(_milestoneId);
    }

    if (address(workerFlow) != address(0)) {
      workerFlow.transferClaims(_milestoneId);
    }
  }
}

// this will be the address to send money to
// e.g. "from" will be shown the contract address
contract AirlockFlow is ERC721TokenReceiver, ERC1155TokenReceiver, Forwarder {
  event MilestoneAgreed(uint256 milestoneId, address by);
  event ClaimAdded(uint256 claimId);
  event ClaimTransferred(uint256 claimId);

  Airlock public airlock;
  FlowDirection public direction;
  Claim[] public claims;

  uint256 public claimsCounter;

  constructor(Airlock _airlock, FlowDirection _direction) payable {
    airlock = _airlock;
    direction = _direction;
  }

  modifier onlyFrom() {
    require(_msgSender() == getFrom(), "must be the from address");
    _;
  }

  modifier onlyTo() {
    require(_msgSender() == getFrom(), "must be the to address");
    _;
  }

  modifier onlyAirlock() {
    require(_msgSender() == address(airlock), "must be from the airlock");
    _;
  }

  function getFrom() public view returns (address) {
    if (direction == FlowDirection.TowardsWorker) {
      return airlock.client();
    } else {
      return airlock.worker();
    }
  }

  function getTo() public view returns (address) {
    if (direction == FlowDirection.TowardsWorker) {
      return airlock.worker();
    } else {
      return airlock.client();
    }
  }

  // receive eth
  receive() external payable {}

  fallback() external payable {}

  function getBalance() public view returns (uint256) {
    return address(this).balance;
  }

  function createClaim(
    uint256 _milestoneId,
    address _sender,
    ClaimType _contractType,
    address _contractAddress,
    uint256 _tokenId,
    uint256 _value,
    string calldata _description,
    string calldata _uri
  ) public onlyAirlock {
    Claim memory c = Claim(
      _milestoneId,
      _sender,
      _contractType,
      _contractAddress,
      _tokenId,
      _value,
      _description,
      _uri
    );
    claims.push(c);

    emit ClaimAdded(claimsCounter);

    unchecked {
      claimsCounter += 1;
    }
  }

  function transferClaims(uint256 _milestoneId) public {
    for (uint256 i = 0; i < claimsCounter; i++) {
      Claim memory c = claims[i];
      if (c.milestoneId == _milestoneId) {
        transferClaimTo(i);
      }
    }
  }

  function totalClaimsBalance(
    ClaimType _ct,
    address _ca,
    uint256 _tokenId
  ) public view returns (uint256) {
    uint256 balance = 0;

    for (uint256 i = 0; i < claims.length; i++) {
      Claim memory c = claims[i];

      if (
        c.contractType == _ct &&
        c.contractAddress == _ca &&
        c.tokenId == _tokenId
      ) {
        if (
          c.contractType == ClaimType.ERC20 ||
          c.contractType == ClaimType.ERC1155
        ) {
          balance += c.value;
        } else if (c.contractType == ClaimType.ERC721) {
          balance += 1;
        }
      }
    }

    return balance;
  }

  function totalUnclaimedBalance(
    ClaimType _ct,
    address _ca,
    uint256 _tokenId
  ) public view returns (uint256) {
    uint256 balance = 0;

    for (uint256 i = 0; i < claims.length; i++) {
      Claim memory c = claims[i];
      (, , , , uint256 transferredAt) = airlock.milestones(c.milestoneId);

      if (
        c.contractType == _ct &&
        c.contractAddress == _ca &&
        c.tokenId == _tokenId &&
        transferredAt == 0 &&
        airlock.workerAgreedAt() > 0
      ) {
        if (
          c.contractType == ClaimType.ERC20 ||
          c.contractType == ClaimType.ERC1155
        ) {
          balance += c.value;
        } else if (c.contractType == ClaimType.ERC721) {
          balance += 1;
        }
      }
    }

    return balance;
  }

  function verifyClaim(uint256 _claimId)
    external
    view
    returns (ClaimVerification)
  {
    Claim memory c = claims[_claimId];

    ClaimType ct = c.contractType;
    address ca = c.contractAddress;
    uint256 tokenId = c.tokenId;
    uint256 value = c.value;

    if (ct == ClaimType.ERC20) {
      // get balance
      uint256 balance = 0;
      if (ca == address(0)) {
        balance = getBalance();
      } else {
        try ERC20(ca).balanceOf(address(this)) returns (uint256 _b) {
          balance = _b;
        } catch {
          balance = 0;
        }
      }

      if (balance <= 0) {
        return ClaimVerification.NotVerified;
      } else if (balance < value) {
        return ClaimVerification.PartVerified;
      } else if (balance == value) {
        return ClaimVerification.ExactVerified;
      } else {
        return ClaimVerification.OverVerified;
      }
    } else if (ct == ClaimType.ERC721) {
      // get owner
      try ERC721(ca).ownerOf(tokenId) returns (address tokenOwner) {
        if (tokenOwner == address(this)) {
          return ClaimVerification.ExactVerified;
        } else {
          return ClaimVerification.NotVerified;
        }
      } catch {
        return ClaimVerification.NotVerified;
      }
    } else if (ct == ClaimType.ERC1155) {
      try ERC1155(ca).balanceOf(address(this), tokenId) returns (
        uint256 balance
      ) {
        if (balance <= 0) {
          return ClaimVerification.NotVerified;
        } else if (balance < value) {
          return ClaimVerification.PartVerified;
        } else if (balance == value) {
          return ClaimVerification.ExactVerified;
        } else {
          return ClaimVerification.OverVerified;
        }
      } catch {
        return ClaimVerification.NotVerified;
      }
    } else {
      return ClaimVerification.NotVerified;
    }
  }

  function transferClaimTo(uint256 _claimId) public onlyAirlock {
    Claim memory c = claims[_claimId];

    ClaimType ct = c.contractType;
    address ca = c.contractAddress;
    uint256 tokenId = c.tokenId;
    uint256 value = c.value;

    if (ct == ClaimType.ERC20) {
      if (ca == address(0)) {
        (bool sent, ) = getTo().call{value: value}("");
        // require(sent, "Failed to send Ether");
      } else {
        try ERC20(ca).transfer(getTo(), value) {} catch {}
      }
    } else if (ct == ClaimType.ERC721) {
      try
        ERC721(ca).safeTransferFrom(address(this), getTo(), tokenId)
      {} catch {}
    } else if (ct == ClaimType.ERC1155) {
      try
        ERC1155(ca).safeTransferFrom(address(this), getTo(), tokenId, value, "")
      {} catch {}
    }

    emit ClaimTransferred(_claimId);
  }

  function recover(
    ClaimType ct,
    address ca,
    uint256 tokenId
  ) public onlyFrom {
    if (ct == ClaimType.ERC20) {
      recoverERC20(ca);
    } else if (ct == ClaimType.ERC721) {
      recoverERC721(ca, tokenId);
    } else {
      recoverERC1155(ca, tokenId);
    }
  }

  function recoverERC20(address ca) public onlyFrom {
    uint256 balance = 0;
    if (ca == address(0)) {
      balance = getBalance();
    } else {
      try ERC20(ca).balanceOf(address(this)) returns (uint256 _b) {
        balance = _b;
      } catch {
        balance = 0;
      }
    }

    balance -= totalUnclaimedBalance(ClaimType.ERC20, ca, 0);

    if (ca == address(0)) {
      (bool sent, ) = getFrom().call{value: balance}("");
      require(sent, "Failed to send Ether");
    } else {
      try ERC20(ca).transfer(getFrom(), balance) {} catch {}
    }
  }

  function recoverERC721(address ca, uint256 tokenId) public onlyFrom {
    uint256 balance = totalUnclaimedBalance(ClaimType.ERC721, ca, tokenId);

    if (balance == 0) {
      try
        ERC721(ca).safeTransferFrom(address(this), getFrom(), tokenId)
      {} catch {}
    }
  }

  function recoverERC1155(address ca, uint256 tokenId) public onlyFrom {
    uint256 balance = ERC1155(ca).balanceOf(address(this), tokenId);

    balance -= totalUnclaimedBalance(ClaimType.ERC1155, ca, tokenId);

    if (balance > 0) {
      try
        ERC1155(ca).safeTransferFrom(
          address(this),
          getFrom(),
          tokenId,
          balance,
          ""
        )
      {} catch {}
    }
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

/// @notice Minimalist and gas efficient standard ERC1155 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    event URI(string value, uint256 indexed id);

    /*//////////////////////////////////////////////////////////////
                             ERC1155 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                             METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                              ERC1155 LOGIC
    //////////////////////////////////////////////////////////////*/

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual {
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual {
        require(ids.length == amounts.length, "LENGTH_MISMATCH");

        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            amount = amounts[i];

            balanceOf[from][id] -= amount;
            balanceOf[to][id] += amount;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        require(owners.length == ids.length, "LENGTH_MISMATCH");

        balances = new uint256[](owners.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i = 0; i < owners.length; ++i) {
                balances[i] = balanceOf[owners[i]][ids[i]];
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
            interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[to][ids[i]] += amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, address(0), ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[from][ids[i]] -= amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        balanceOf[from][id] -= amount;

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }
}

/// @notice A generic interface for a contract which properly accepts ERC1155 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
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