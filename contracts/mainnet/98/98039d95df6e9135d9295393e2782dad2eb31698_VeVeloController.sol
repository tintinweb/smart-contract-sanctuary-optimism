pragma solidity 0.8.15;

interface IRewardsDistributor {
  function claim_many(uint[] memory _tokenIds) external returns (bool);
}

pragma solidity 0.8.15;

interface IVoter {
  function _ve() external view returns (address);

  function governor() external view returns (address);

  function emergencyCouncil() external view returns (address);

  function attachTokenToGauge(uint _tokenId, address account) external;

  function detachTokenFromGauge(uint _tokenId, address account) external;

  function emitDeposit(uint _tokenId, address account, uint amount) external;

  function emitWithdraw(uint _tokenId, address account, uint amount) external;

  function isWhitelisted(address token) external view returns (bool);

  function notifyRewardAmount(uint amount) external;

  function distribute(address _gauge) external;

  function vote(
    uint tokenId,
    address[] calldata _poolVote,
    uint256[] calldata _weights
  ) external;

  function claimBribes(
    address[] memory _bribes,
    address[][] memory _tokens,
    uint _tokenId
  ) external;

  function claimFees(
    address[] memory _fees,
    address[][] memory _tokens,
    uint _tokenId
  ) external;

  function reset(uint256 _tokenId) external;

  function gauges(address pool) external view returns (address);
}

pragma solidity 0.8.15;

interface IVotingEscrow {
  struct Point {
    int128 bias;
    int128 slope; // # -dweight / dt
    uint256 ts;
    uint256 blk; // block
  }

  function token() external view returns (address);

  function team() external returns (address);

  function epoch() external view returns (uint);

  function point_history(uint loc) external view returns (Point memory);

  function user_point_history(
    uint tokenId,
    uint loc
  ) external view returns (Point memory);

  function user_point_epoch(uint tokenId) external view returns (uint);

  function ownerOf(uint) external view returns (address);

  function isApprovedOrOwner(address, uint) external view returns (bool);

  function transferFrom(address, address, uint) external;

  function voting(uint tokenId) external;

  function abstain(uint tokenId) external;

  function attach(uint tokenId) external;

  function detach(uint tokenId) external;

  function checkpoint() external;

  function deposit_for(uint tokenId, uint value) external;

  function create_lock_for(uint, uint, address) external returns (uint);

  function create_lock(
    uint _value,
    uint _lock_duration
  ) external returns (uint);

  function increase_unlock_time(uint tokenId, uint lock_duration) external;

  function balanceOfNFT(uint) external view returns (uint);

  function totalSupply() external view returns (uint);

  function withdraw(uint _tokenId) external;

  function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
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

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
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

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
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

    function transferFrom(address from, address to, uint256 id) public virtual {
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

    function safeTransferFrom(address from, address to, uint256 id) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(address from, address to, uint256 id, bytes calldata data) public virtual {
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

    function _safeMint(address to, uint256 id, bytes memory data) internal virtual {
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
    function onERC721Received(address, address, uint256, bytes calldata) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "../tokens/ERC20.sol";

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
/// @dev Note that none of the functions in this library check that a token has code at all! That responsibility is delegated to the caller.
library SafeTransferLib {
    /*//////////////////////////////////////////////////////////////
                             ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferFrom(ERC20 token, address from, address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), from) // Append the "from" argument.
            mstore(add(freeMemoryPointer, 36), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
            )
        }

        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(ERC20 token, address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "TRANSFER_FAILED");
    }

    function safeApprove(ERC20 token, address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "APPROVE_FAILED");
    }
}

pragma solidity ^0.8.15;

import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {Owned} from "../lib/solmate/src/auth/Owned.sol";

contract VeVelo is ERC20, Owned {
  constructor(
    address _owner,
    string memory _name,
    string memory _symbol,
    uint8 _decimals
  ) ERC20(_name, _symbol, _decimals) Owned(_owner) {}

  function mint(address to, uint256 value) public virtual onlyOwner {
    _mint(to, value);
  }

  function burn(address from, uint256 value) public virtual onlyOwner {
    _burn(from, value);
  }
}

pragma solidity ^0.8.15;

import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {ERC721TokenReceiver} from "../lib/solmate/src/tokens/ERC721.sol";
import {Owned} from "../lib/solmate/src/auth/Owned.sol";
import {SafeTransferLib} from "../lib/solmate/src//utils/SafeTransferLib.sol";

import "../interfaces/IVoter.sol";
import "../interfaces/IVotingEscrow.sol";
import "../interfaces/IRewardsDistributor.sol";

import {VeVelo} from "./VeVelo.sol";

contract VeVeloController is ERC721TokenReceiver, Owned {
  using SafeTransferLib for ERC20;

  VeVelo public immutable veVeloToken;
  ERC20 public immutable velo;

  IVoter public immutable voter;
  IVotingEscrow public immutable votingEscrow;
  IRewardsDistributor public immutable rewardsDistributor;

  uint256[] public veNFTIds;

  event RemoveExcessTokens(address token, address to, uint256 amount);
  event GenerateVeNFT(uint256 id, uint256 lockedAmount, uint256 lockDuration);
  event RelockVeNFT(uint256 id, uint256 lockDuration);
  event NFTVoted(uint256 id, uint256 timestamp);
  event WithdrawVeNFT(uint256 id, uint256 timestamp);
  event ClaimedBribes(uint256 id, uint256 timestamp);
  event ClaimedFees(uint256 id, uint256 timestamp);
  event ClaimedRebases(uint256[] id, uint256 timestamp);

  constructor(
    address _owner,
    address _VeVeloAddress,
    address _VeloAddress,
    address _VoterAddress,
    address _VotingEscrowAddress,
    address _RewardsDistributorAddress
  ) Owned(_owner) {
    veVeloToken = VeVelo(_VeVeloAddress);
    velo = ERC20(_VeloAddress);
    voter = IVoter(_VoterAddress);
    votingEscrow = IVotingEscrow(_VotingEscrowAddress);
    rewardsDistributor = IRewardsDistributor(_RewardsDistributorAddress);
  }

  function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
    return
      interfaceId == type(ERC20).interfaceId ||
      interfaceId == type(ERC721TokenReceiver).interfaceId ||
      interfaceId == 0x01ffc9a7;
  }

  function lockVELO(uint256 _tokenAmount) external {
    uint256 _lockDuration = 365 days * 4;

    SafeTransferLib.safeTransferFrom(
      velo,
      msg.sender,
      address(this),
      _tokenAmount
    );
    veVeloToken.mint(msg.sender, _tokenAmount);
    uint256 NFTId = votingEscrow.create_lock(_tokenAmount, _lockDuration);
    veNFTIds.push(NFTId);
    uint256 weeksLocked = (_lockDuration / 1 weeks) * 1 weeks;

    emit GenerateVeNFT(NFTId, _tokenAmount, weeksLocked);
  }

  function relockVELO(uint256 _NFTId, uint256 _lockDuration)
    external
    onlyOwner
  {
    votingEscrow.increase_unlock_time(_NFTId, _lockDuration);
    uint256 weeksLocked = (_lockDuration / 1 weeks) * 1 weeks;
    emit RelockVeNFT(_NFTId, weeksLocked);
  }

  function vote(
    uint256[] calldata _NFTIds,
    address[] calldata _poolVote,
    uint256[] calldata _weights
  ) external onlyOwner {
    uint256 length = _NFTIds.length;
    for (uint256 i = 0; i < length; ++i) {
      voter.vote(_NFTIds[i], _poolVote, _weights);
      emit NFTVoted(_NFTIds[i], block.timestamp);
    }
  }

  function withdrawNFT(uint256 _tokenId, uint256 _index) external onlyOwner {
    //ensure we are deleting the right veNFTId slot
    require(veNFTIds[_index] == _tokenId, "Wrong index slot");
    //abstain from current epoch vote to reset voted to false, allowing withdrawal
    voter.reset(_tokenId);
    //request withdrawal
    votingEscrow.withdraw(_tokenId);
    //delete stale veNFTId as veNFT is now burned.
    delete veNFTIds[_index];
    emit WithdrawVeNFT(_tokenId, block.timestamp);
  }

  function removeERC20Tokens(
    address[] calldata _tokens,
    uint256[] calldata _amounts
  ) external onlyOwner {
    uint256 length = _tokens.length;
    require(length == _amounts.length, "Mismatched arrays");

    for (uint256 i = 0; i < length; ++i) {
      ERC20(_tokens[i]).safeTransfer(msg.sender, _amounts[i]);
      emit RemoveExcessTokens(_tokens[i], msg.sender, _amounts[i]);
    }
  }

  function transferNFTs(
    uint256[] calldata _tokenIds,
    uint256[] calldata _indexes
  ) external onlyOwner {
    uint256 length = _tokenIds.length;
    require(length == _indexes.length, "Mismatched arrays");

    for (uint256 i = 0; i < length; ++i) {
      require(veNFTIds[_indexes[i]] == _tokenIds[i], "Wrong index slot");
      delete veNFTIds[_indexes[i]];
      //abstain from current epoch vote to reset voted to false, allowing transfer
      voter.reset(_tokenIds[i]);
      //here msg.sender is always owner.
      votingEscrow.safeTransferFrom(address(this), msg.sender, _tokenIds[i]);
      //no event needed as votingEscrow emits one on transfer anyway
    }
  }

  function claimBribesMultiNFTs(
    address[] calldata _bribes,
    address[][] calldata _tokens,
    uint256[] calldata _tokenIds
  ) external {
    uint256 length = _tokenIds.length;
    for (uint256 i = 0; i < length; ++i) {
      voter.claimBribes(_bribes, _tokens, _tokenIds[i]);
      emit ClaimedBribes(_tokenIds[i], block.timestamp);
    }
  }

  function claimFeesMultiNFTs(
    address[] calldata _fees,
    address[][] calldata _tokens,
    uint256[] calldata _tokenIds
  ) external {
    uint256 length = _tokenIds.length;
    for (uint256 i = 0; i < length; ++i) {
      voter.claimFees(_fees, _tokens, _tokenIds[i]);
      emit ClaimedFees(_tokenIds[i], block.timestamp);
    }
  }

  function claimRebaseMultiNFTs(uint256[] calldata _tokenIds) external {
    //claim_many always returns true unless a tokenId = 0 so return bool is not needed
    //slither-disable-next-line unused-return
    rewardsDistributor.claim_many(_tokenIds);
    emit ClaimedRebases(_tokenIds, block.timestamp);
  }

  function onERC721Received(
    address _operator,
    address _from,
    uint256 _id,
    bytes calldata _data
  ) public virtual override returns (bytes4) {
    return ERC721TokenReceiver.onERC721Received.selector;
  }
}