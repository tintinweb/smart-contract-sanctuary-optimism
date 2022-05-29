// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*///////////////////////////////////////////////////////////////
                             METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*///////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*///////////////////////////////////////////////////////////////
                             EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*///////////////////////////////////////////////////////////////
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

    /*///////////////////////////////////////////////////////////////
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

    /*///////////////////////////////////////////////////////////////
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
            bytes32 digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
                )
            );

            address recoveredAddress = ecrecover(digest, v, r, s);

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

    /*///////////////////////////////////////////////////////////////
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

// SPDX-License-Identifier: GPL-2.0

pragma solidity ^0.8.10;

import "@rari-capital/solmate/src/tokens/ERC20.sol";


contract CreditPool {

  /////////////////////////////////////////////////////////////////////////////////
  //                             CONTRACT VARIABLES                              //
  /////////////////////////////////////////////////////////////////////////////////


  // internal credits for each member in the game
  mapping(address => uint256) public memberCredits;

  // total internal credits outstanding (across all members). Note: this can be less than the total reserve in the contract.
  uint256 public totalCredits;

  // ERC20 token contract for the $CHIP tokens used in the game
  ERC20 public immutable reserveToken;

  // mapping of addresses that can change internal credits
  mapping(address => bool) public isHost;

  // error for when the internal credits don't match the contract's $CHIP balance
  error NotEnoughCredits();

  // event for tracking member credit balances
  event CreditsUpdated(address indexed member, uint256 amount, bool isAdded);

  // event for tracking hosts
  event HostUpdated(address indexed host, address indexed caller, bool isAdded);

  // modifier to control access of protected functions
  modifier onlyHost() {
    require(isHost[msg.sender], "UNAUTHORIZED");
    _;
  }

  constructor(ERC20 reserveToken_) {
    // set the ERC20 token contract
    reserveToken = reserveToken_;

    // add the host as an Host
    isHost[msg.sender] = true;
  }


  /////////////////////////////////////////////////////////////////////////////////
  //                                USER INTERFACE                               //
  /////////////////////////////////////////////////////////////////////////////////


  // member buys credits
  function buyCredit(uint256 purchaseAmt_) external {

    // increase the member credit by the posted amount
    memberCredits[msg.sender] += purchaseAmt_;

    // increase the total game credits in the game by the amount the member buys in for
    totalCredits += purchaseAmt_;

    // transfer the reserveToken token from the user's wallet to the pool contract for the purchaed amount
    reserveToken.transferFrom(msg.sender, address(this), purchaseAmt_);

    // credits have been added to member
    emit CreditsUpdated(msg.sender, purchaseAmt_, true);
  }


  // member withdraws credits
  function withdrawCredit(uint256 withdrawAmt_) external {

    // ensure the amount of chips returning to the member does not exceed their internal credit balance
    if ( withdrawAmt_ > memberCredits[msg.sender] )  { revert NotEnoughCredits(); }
    
    // decrease the amount of internal credits of the member
    memberCredits[msg.sender] -= withdrawAmt_;

    // reduce the total outstanding credits in the pool
    totalCredits -= withdrawAmt_;

    // transfer reserveTokens to the member 
    reserveToken.transfer(msg.sender, withdrawAmt_);

    // credits have been deducted from member
    emit CreditsUpdated(msg.sender, withdrawAmt_, false);
  }


   // member tipping credits to the pool host
  function tip(uint256 tipAmt_) external {

    // if the amount of chips returned to the member exceeds their internal credit balance, throw an error
    if ( tipAmt_ > memberCredits[msg.sender] )  { revert NotEnoughCredits(); }
    
    // decrease the amount of internal credits of the member
    memberCredits[msg.sender] -= tipAmt_;

    // reduce the total outstanding credits in the pool
    totalCredits -= tipAmt_;

    // credits have been deducted from member
    emit CreditsUpdated(msg.sender, tipAmt_, false);
  }


  // HOST ONLY: add credits to a member's balance
  function addCredits(address member_, uint256 amount_) external onlyHost {

    // ensure the total pool credits does not exceed the number of reserve tokens in the contract
    if ( totalCredits + amount_ > reserveToken.balanceOf(address(this)) )  { revert NotEnoughCredits(); }

    // increase the internal credits for a member in the pool by the amount
    memberCredits[member_] += amount_;

    // increase the total outstanding credits in the pool
    totalCredits += amount_;

    // credits have been added to member
    emit CreditsUpdated(member_, amount_, true);
  }


  // HOST ONLY: deduct internal credits from a member.
  function deductCredits(address member_, uint256 amount_) external onlyHost {

    // reduce the member's credit
    memberCredits[member_] -= amount_;

    // reduce the total outstanding credits in the pool
    totalCredits -= amount_;

    // credits have been deducted from member
    emit CreditsUpdated(member_, amount_, false);
  }


  // called by an Host to add another Host
  function addHost(address newHost_) external onlyHost {

    // add address to whitelist
    isHost[newHost_] = true;

    // Host has been added
    emit HostUpdated(newHost_, msg.sender, true);
  }


  // called by an Host to remove another Host
  function removeHost(address oldHost_) external onlyHost {

    // remove address from Host whitelist
    isHost[oldHost_] = false;

    // Host has been removed
    emit HostUpdated(oldHost_, msg.sender, false);
  }
}