// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {IVotingEscrow} from "contracts/interfaces/IVotingEscrow.sol";
import {IRestrictedTeam} from "contracts/interfaces/v2/IRestrictedTeam.sol";

/// @title Velodrome RestrictedTeam contract
/// @author velodrome.finance, @pegahcarter, @figs999
/// @notice Team role for VotingEscrow without toggleSplit(), setTeam() abilities.
/// @dev Uses same owner role as FactoryRegistry
contract RestrictedTeam is IRestrictedTeam, ERC2771Context {
    /// @inheritdoc IRestrictedTeam
    IVotingEscrow public immutable escrow;
    /// @inheritdoc IRestrictedTeam
    Ownable public immutable factoryRegistry;

    /// @param _escrow The VotingEscrow contract
    constructor(address _escrow) ERC2771Context(IVotingEscrow(_escrow).forwarder()) {
        escrow = IVotingEscrow(_escrow);
        factoryRegistry = Ownable(escrow.factoryRegistry());
    }

    /// @inheritdoc IRestrictedTeam
    function setArtProxy(address _proxy) external {
        if (_msgSender() != factoryRegistry.owner()) revert NotTeam();
        escrow.setArtProxy(_proxy);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (metatx/ERC2771Context.sol)

pragma solidity ^0.8.9;

import "../utils/Context.sol";

/**
 * @dev Context variant with ERC2771 support.
 */
abstract contract ERC2771Context is Context {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable _trustedForwarder;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder) {
        _trustedForwarder = trustedForwarder;
    }

    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == _trustedForwarder;
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165, IERC721, IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import {IVotes} from "../governance/IVotes.sol";

interface IVotingEscrow is IVotes, IERC4906, IERC6372, IERC721Metadata {
    struct LockedBalance {
        int128 amount;
        uint256 end;
        bool isPermanent;
    }

    struct UserPoint {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
        uint256 permanent;
    }

    struct GlobalPoint {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
        uint256 permanentLockBalance;
    }

    /// @notice A checkpoint for recorded delegated voting weights at a certain timestamp
    struct Checkpoint {
        uint256 fromTimestamp;
        address owner;
        uint256 delegatedBalance;
        uint256 delegatee;
    }

    enum DepositType {
        DEPOSIT_FOR_TYPE,
        CREATE_LOCK_TYPE,
        INCREASE_LOCK_AMOUNT,
        INCREASE_UNLOCK_TIME
    }

    /// @dev Different types of veNFTs:
    /// NORMAL  - typical veNFT
    /// LOCKED  - veNFT which is locked into a MANAGED veNFT
    /// MANAGED - veNFT which can accept the deposit of NORMAL veNFTs
    enum EscrowType {
        NORMAL,
        LOCKED,
        MANAGED
    }

    error AlreadyVoted();
    error AmountTooBig();
    error ERC721ReceiverRejectedTokens();
    error ERC721TransferToNonERC721ReceiverImplementer();
    error InvalidNonce();
    error InvalidSignature();
    error InvalidSignatureS();
    error InvalidManagedNFTId();
    error LockDurationNotInFuture();
    error LockDurationTooLong();
    error LockExpired();
    error LockNotExpired();
    error NoLockFound();
    error NonExistentToken();
    error NotApprovedOrOwner();
    error NotDistributor();
    error NotEmergencyCouncilOrGovernor();
    error NotGovernor();
    error NotGovernorOrManager();
    error NotManagedNFT();
    error NotManagedOrNormalNFT();
    error NotLockedNFT();
    error NotNormalNFT();
    error NotPermanentLock();
    error NotOwner();
    error NotTeam();
    error NotVoter();
    error OwnershipChange();
    error PermanentLock();
    error SameAddress();
    error SameNFT();
    error SameState();
    error SplitNoOwner();
    error SplitNotAllowed();
    error SignatureExpired();
    error TooManyTokenIDs();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroBalance();

    event Deposit(
        address indexed provider,
        uint256 indexed tokenId,
        DepositType indexed depositType,
        uint256 value,
        uint256 locktime,
        uint256 ts
    );
    event Withdraw(address indexed provider, uint256 indexed tokenId, uint256 value, uint256 ts);
    event LockPermanent(address indexed _owner, uint256 indexed _tokenId, uint256 amount, uint256 _ts);
    event UnlockPermanent(address indexed _owner, uint256 indexed _tokenId, uint256 amount, uint256 _ts);
    event Supply(uint256 prevSupply, uint256 supply);
    event Merge(
        address indexed _sender,
        uint256 indexed _from,
        uint256 indexed _to,
        uint256 _amountFrom,
        uint256 _amountTo,
        uint256 _amountFinal,
        uint256 _locktime,
        uint256 _ts
    );
    event Split(
        uint256 indexed _from,
        uint256 indexed _tokenId1,
        uint256 indexed _tokenId2,
        address _sender,
        uint256 _splitAmount1,
        uint256 _splitAmount2,
        uint256 _locktime,
        uint256 _ts
    );
    event CreateManaged(
        address indexed _to,
        uint256 indexed _mTokenId,
        address indexed _from,
        address _lockedManagedReward,
        address _freeManagedReward
    );
    event DepositManaged(
        address indexed _owner,
        uint256 indexed _tokenId,
        uint256 indexed _mTokenId,
        uint256 _weight,
        uint256 _ts
    );
    event WithdrawManaged(
        address indexed _owner,
        uint256 indexed _tokenId,
        uint256 indexed _mTokenId,
        uint256 _weight,
        uint256 _ts
    );
    event SetAllowedManager(address indexed _allowedManager);

    // State variables
    /// @notice Address of Meta-tx Forwarder
    function forwarder() external view returns (address);

    /// @notice Address of FactoryRegistry.sol
    function factoryRegistry() external view returns (address);

    /// @notice Address of token (VELO) used to create a veNFT
    function token() external view returns (address);

    /// @notice Address of RewardsDistributor.sol
    function distributor() external view returns (address);

    /// @notice Address of Voter.sol
    function voter() external view returns (address);

    /// @notice Address of Velodrome Team multisig
    function team() external view returns (address);

    /// @notice Address of art proxy used for on-chain art generation
    function artProxy() external view returns (address);

    /// @dev address which can create managed NFTs
    function allowedManager() external view returns (address);

    /// @dev Current count of token
    function tokenId() external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                            MANAGED NFT STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev Mapping of token id to escrow type
    ///      Takes advantage of the fact default value is EscrowType.NORMAL
    function escrowType(uint256 tokenId) external view returns (EscrowType);

    /// @dev Mapping of token id to managed id
    function idToManaged(uint256 tokenId) external view returns (uint256 managedTokenId);

    /// @dev Mapping of user token id to managed token id to weight of token id
    function weights(uint256 tokenId, uint256 managedTokenId) external view returns (uint256 weight);

    /// @dev Mapping of managed id to deactivated state
    function deactivated(uint256 tokenId) external view returns (bool inactive);

    /// @dev Mapping from managed nft id to locked managed rewards
    ///      `token` denominated rewards (rebases/rewards) stored in locked managed rewards contract
    ///      to prevent co-mingling of assets
    function managedToLocked(uint256 tokenId) external view returns (address);

    /// @dev Mapping from managed nft id to free managed rewards contract
    ///      these rewards can be freely withdrawn by users
    function managedToFree(uint256 tokenId) external view returns (address);

    /*///////////////////////////////////////////////////////////////
                            MANAGED NFT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Create managed NFT (a permanent lock) for use within ecosystem.
    /// @dev Throws if address already owns a managed NFT.
    /// @return _mTokenId managed token id.
    function createManagedLockFor(address _to) external returns (uint256 _mTokenId);

    /// @notice Delegates balance to managed nft
    ///         Note that NFTs deposited into a managed NFT will be re-locked
    ///         to the maximum lock time on withdrawal.
    ///         Permanent locks that are deposited will automatically unlock.
    /// @dev Managed nft will remain max-locked as long as there is at least one
    ///      deposit or withdrawal per week.
    ///      Throws if deposit nft is managed.
    ///      Throws if recipient nft is not managed.
    ///      Throws if deposit nft is already locked.
    ///      Throws if not called by voter.
    /// @param _tokenId tokenId of NFT being deposited
    /// @param _mTokenId tokenId of managed NFT that will receive the deposit
    function depositManaged(uint256 _tokenId, uint256 _mTokenId) external;

    /// @notice Retrieves locked rewards and withdraws balance from managed nft.
    ///         Note that the NFT withdrawn is re-locked to the maximum lock time.
    /// @dev Throws if NFT not locked.
    ///      Throws if not called by voter.
    /// @param _tokenId tokenId of NFT being deposited.
    function withdrawManaged(uint256 _tokenId) external;

    /// @notice Permit one address to call createManagedLockFor() that is not Voter.governor()
    function setAllowedManager(address _allowedManager) external;

    /// @notice Set Managed NFT state. Inactive NFTs cannot be deposited into.
    /// @param _mTokenId managed nft state to set
    /// @param _state true => inactive, false => active
    function setManagedState(uint256 _mTokenId, bool _state) external;

    /*///////////////////////////////////////////////////////////////
                             METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function version() external view returns (string memory);

    function decimals() external view returns (uint8);

    function setTeam(address _team) external;

    function setArtProxy(address _proxy) external;

    /// @inheritdoc IERC721Metadata
    function tokenURI(uint256 tokenId) external view returns (string memory);

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev Mapping from owner address to mapping of index to tokenId
    function ownerToNFTokenIdList(address _owner, uint256 _index) external view returns (uint256 _tokenId);

    /// @inheritdoc IERC721
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /// @inheritdoc IERC721
    function balanceOf(address owner) external view returns (uint256 balance);

    /*//////////////////////////////////////////////////////////////
                         ERC721 APPROVAL STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC721
    function getApproved(uint256 _tokenId) external view returns (address operator);

    /// @inheritdoc IERC721
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /// @notice Check whether spender is owner or an approved user for a given veNFT
    /// @param _spender .
    /// @param _tokenId .
    function isApprovedOrOwner(address _spender, uint256 _tokenId) external returns (bool);

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC721
    function approve(address to, uint256 tokenId) external;

    /// @inheritdoc IERC721
    function setApprovalForAll(address operator, bool approved) external;

    /// @inheritdoc IERC721
    function transferFrom(address from, address to, uint256 tokenId) external;

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 _interfaceID) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                             ESCROW STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Total count of epochs witnessed since contract creation
    function epoch() external view returns (uint256);

    /// @notice Total amount of token() deposited
    function supply() external view returns (uint256);

    /// @notice Aggregate permanent locked balances
    function permanentLockBalance() external view returns (uint256);

    function userPointEpoch(uint256 _tokenId) external view returns (uint256 _epoch);

    /// @notice time -> signed slope change
    function slopeChanges(uint256 _timestamp) external view returns (int128);

    /// @notice account -> can split
    function canSplit(address _account) external view returns (bool);

    /// @notice Global point history at a given index
    function pointHistory(uint256 _loc) external view returns (GlobalPoint memory);

    /// @notice Get the LockedBalance (amount, end) of a _tokenId
    /// @param _tokenId .
    /// @return LockedBalance of _tokenId
    function locked(uint256 _tokenId) external view returns (LockedBalance memory);

    /// @notice User -> UserPoint[userEpoch]
    function userPointHistory(uint256 _tokenId, uint256 _loc) external view returns (UserPoint memory);

    /*//////////////////////////////////////////////////////////////
                              ESCROW LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Record global data to checkpoint
    function checkpoint() external;

    /// @notice Deposit `_value` tokens for `_tokenId` and add to the lock
    /// @dev Anyone (even a smart contract) can deposit for someone else, but
    ///      cannot extend their locktime and deposit for a brand new user
    /// @param _tokenId lock NFT
    /// @param _value Amount to add to user's lock
    function depositFor(uint256 _tokenId, uint256 _value) external;

    /// @notice Deposit `_value` tokens for `msg.sender` and lock for `_lockDuration`
    /// @param _value Amount to deposit
    /// @param _lockDuration Number of seconds to lock tokens for (rounded down to nearest week)
    /// @return TokenId of created veNFT
    function createLock(uint256 _value, uint256 _lockDuration) external returns (uint256);

    /// @notice Deposit `_value` tokens for `_to` and lock for `_lockDuration`
    /// @param _value Amount to deposit
    /// @param _lockDuration Number of seconds to lock tokens for (rounded down to nearest week)
    /// @param _to Address to deposit
    /// @return TokenId of created veNFT
    function createLockFor(uint256 _value, uint256 _lockDuration, address _to) external returns (uint256);

    /// @notice Deposit `_value` additional tokens for `_tokenId` without modifying the unlock time
    /// @param _value Amount of tokens to deposit and add to the lock
    function increaseAmount(uint256 _tokenId, uint256 _value) external;

    /// @notice Extend the unlock time for `_tokenId`
    ///         Cannot extend lock time of permanent locks
    /// @param _lockDuration New number of seconds until tokens unlock
    function increaseUnlockTime(uint256 _tokenId, uint256 _lockDuration) external;

    /// @notice Withdraw all tokens for `_tokenId`
    /// @dev Only possible if the lock is both expired and not permanent
    ///      This will burn the veNFT. Any rebases or rewards that are unclaimed
    ///      will no longer be claimable. Claim all rebases and rewards prior to calling this.
    function withdraw(uint256 _tokenId) external;

    /// @notice Merges `_from` into `_to`.
    /// @dev Cannot merge `_from` locks that are permanent or have already voted this epoch.
    ///      Cannot merge `_to` locks that have already expired.
    ///      This will burn the veNFT. Any rebases or rewards that are unclaimed
    ///      will no longer be claimable. Claim all rebases and rewards prior to calling this.
    /// @param _from VeNFT to merge from.
    /// @param _to VeNFT to merge into.
    function merge(uint256 _from, uint256 _to) external;

    /// @notice Splits veNFT into two new veNFTS - one with oldLocked.amount - `_amount`, and the second with `_amount`
    /// @dev    This burns the tokenId of the target veNFT
    ///         Callable by approved or owner
    ///         If this is called by approved, approved will not have permissions to manipulate the newly created veNFTs
    ///         Returns the two new split veNFTs to owner
    ///         If `from` is permanent, will automatically dedelegate.
    ///         This will burn the veNFT. Any rebases or rewards that are unclaimed
    ///         will no longer be claimable. Claim all rebases and rewards prior to calling this.
    /// @param _from VeNFT to split.
    /// @param _amount Amount to split from veNFT.
    /// @return _tokenId1 Return tokenId of veNFT with oldLocked.amount - `_amount`.
    /// @return _tokenId2 Return tokenId of veNFT with `_amount`.
    function split(uint256 _from, uint256 _amount) external returns (uint256 _tokenId1, uint256 _tokenId2);

    /// @notice Toggle split for a specific address.
    /// @dev Toggle split for address(0) to enable or disable for all.
    /// @param _account Address to toggle split permissions
    /// @param _bool True to allow, false to disallow
    function toggleSplit(address _account, bool _bool) external;

    /// @notice Permanently lock a veNFT. Voting power will be equal to
    ///         `LockedBalance.amount` with no decay. Required to delegate.
    /// @dev Only callable by unlocked normal veNFTs.
    /// @param _tokenId tokenId to lock.
    function lockPermanent(uint256 _tokenId) external;

    /// @notice Unlock a permanently locked veNFT. Voting power will decay.
    ///         Will automatically dedelegate if delegated.
    /// @dev Only callable by permanently locked veNFTs.
    ///      Cannot unlock if already voted this epoch.
    /// @param _tokenId tokenId to unlock.
    function unlockPermanent(uint256 _tokenId) external;

    /*///////////////////////////////////////////////////////////////
                           GAUGE VOTING STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the voting power for _tokenId at the current timestamp
    /// @dev Returns 0 if called in the same block as a transfer.
    /// @param _tokenId .
    /// @return Voting power
    function balanceOfNFT(uint256 _tokenId) external view returns (uint256);

    /// @notice Get the voting power for _tokenId at a given timestamp
    /// @param _tokenId .
    /// @param _t Timestamp to query voting power
    /// @return Voting power
    function balanceOfNFTAt(uint256 _tokenId, uint256 _t) external view returns (uint256);

    /// @notice Calculate total voting power at current timestamp
    /// @return Total voting power at current timestamp
    function totalSupply() external view returns (uint256);

    /// @notice Calculate total voting power at a given timestamp
    /// @param _t Timestamp to query total voting power
    /// @return Total voting power at given timestamp
    function totalSupplyAt(uint256 _t) external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                            GAUGE VOTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice See if a queried _tokenId has actively voted
    /// @param _tokenId .
    /// @return True if voted, else false
    function voted(uint256 _tokenId) external view returns (bool);

    /// @notice Set the global state voter and distributor
    /// @dev This is only called once, at setup
    function setVoterAndDistributor(address _voter, address _distributor) external;

    /// @notice Set `voted` for _tokenId to true or false
    /// @dev Only callable by voter
    /// @param _tokenId .
    /// @param _voted .
    function voting(uint256 _tokenId, bool _voted) external;

    /*///////////////////////////////////////////////////////////////
                            DAO VOTING STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The number of checkpoints for each tokenId
    function numCheckpoints(uint256 tokenId) external view returns (uint48);

    /// @notice A record of states for signing / validating signatures
    function nonces(address account) external view returns (uint256);

    /// @inheritdoc IVotes
    function delegates(uint256 delegator) external view returns (uint256);

    /// @notice A record of delegated token checkpoints for each account, by index
    /// @param tokenId .
    /// @param index .
    /// @return Checkpoint
    function checkpoints(uint256 tokenId, uint48 index) external view returns (Checkpoint memory);

    /// @inheritdoc IVotes
    function getPastVotes(address account, uint256 tokenId, uint256 timestamp) external view returns (uint256);

    /// @inheritdoc IVotes
    function getPastTotalSupply(uint256 timestamp) external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                             DAO VOTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVotes
    function delegate(uint256 delegator, uint256 delegatee) external;

    /// @inheritdoc IVotes
    function delegateBySig(
        uint256 delegator,
        uint256 delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /*//////////////////////////////////////////////////////////////
                              ERC6372 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC6372
    function clock() external view returns (uint48);

    /// @inheritdoc IERC6372
    function CLOCK_MODE() external view returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVotingEscrow} from "../IVotingEscrow.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IRestrictedTeam {
    error NotTeam();

    /// @notice Address of the VotingEscrow contract.
    function escrow() external view returns (IVotingEscrow);

    /// @notice Address of the factory registry contract.
    function factoryRegistry() external view returns (Ownable);

    /// @notice Set art proxy address
    /// @dev Only callable by factory registry owner
    function setArtProxy(address _proxy) external;
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
// OpenZeppelin Contracts (interfaces/IERC6372.sol)

pragma solidity ^0.8.0;

interface IERC6372 {
    /**
     * @dev Clock used for flagging checkpoints. Can be overridden to implement timestamp based checkpoints (and voting).
     */
    function clock() external view returns (uint48);

    /**
     * @dev Description of the clock
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() external view returns (string memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC165.sol";
import "./IERC721.sol";

/// @title EIP-721 Metadata Update Extension
interface IERC4906 is IERC165, IERC721 {
    /// @dev This event emits when the metadata of a token is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFT.
    event MetadataUpdate(uint256 _tokenId);

    /// @dev This event emits when the metadata of a range of tokens is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFTs.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// Modified IVotes interface for tokenId based voting
interface IVotes {
    /**
     * @dev Emitted when an account changes their delegate.
     */
    event DelegateChanged(address indexed delegator, uint256 indexed fromDelegate, uint256 indexed toDelegate);

    /**
     * @dev Emitted when a token transfer or delegate change results in changes to a delegate's number of votes.
     */
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    /**
     * @dev Returns the amount of votes that `tokenId` had at a specific moment in the past.
     *      If the account passed in is not the owner, returns 0.
     */
    function getPastVotes(address account, uint256 tokenId, uint256 timepoint) external view returns (uint256);

    /**
     * @dev Returns the total supply of votes available at a specific moment in the past. If the `clock()` is
     * configured to use block numbers, this will return the value the end of the corresponding block.
     *
     * NOTE: This value is the sum of all available votes, which is not necessarily the sum of all delegated votes.
     * Votes that have not been delegated are still part of total supply, even though they would not participate in a
     * vote.
     */
    function getPastTotalSupply(uint256 timepoint) external view returns (uint256);

    /**
     * @dev Returns the delegate that `tokenId` has chosen. Can never be equal to the delegator's `tokenId`.
     *      Returns 0 if not delegated.
     */
    function delegates(uint256 tokenId) external view returns (uint256);

    /**
     * @dev Delegates votes from the sender to `delegatee`.
     */
    function delegate(uint256 delegator, uint256 delegatee) external;

    /**
     * @dev Delegates votes from `delegator` to `delegatee`. Signer must own `delegator`.
     */
    function delegateBySig(
        uint256 delegator,
        uint256 delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

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
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
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
    function transferFrom(address from, address to, uint256 tokenId) external;

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
    function setApprovalForAll(address operator, bool approved) external;

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
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC165.sol)

pragma solidity ^0.8.0;

import "../utils/introspection/IERC165.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC721.sol)

pragma solidity ^0.8.0;

import "../token/ERC721/IERC721.sol";

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