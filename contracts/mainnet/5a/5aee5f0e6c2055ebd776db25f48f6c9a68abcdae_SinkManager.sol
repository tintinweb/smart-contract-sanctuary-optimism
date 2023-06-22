// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {SinkManagerFacilitator} from "./SinkManagerFacilitator.sol";
import {ISinkManager} from "../../interfaces/ISinkManager.sol";
import {IMinter} from "../../interfaces/IMinter.sol";
import {IVotingEscrow} from "../../interfaces/IVotingEscrow.sol";
import {IVelo} from "../../interfaces/IVelo.sol";
import {IGaugeV1} from "../../interfaces/v1/IGaugeV1.sol";
import {IVoterV1} from "../../interfaces/v1/IVoterV1.sol";
import {IVotingEscrowV1} from "../../interfaces/v1/IVotingEscrowV1.sol";
import {IRewardsDistributorV1} from "../../interfaces/v1/IRewardsDistributorV1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {VelodromeTimeLibrary} from "../../libraries/VelodromeTimeLibrary.sol";

/// @title Velodrome Sink Manager
/// @notice Absorb v1 Velo and converting v1 veNFTs and VELO into v2
/// @author velodrome.finance, @pegahcarter
contract SinkManager is ISinkManager, ERC2771Context, Ownable, ERC721Holder, ReentrancyGuard {
    uint256 internal constant MAXTIME = 4 * 365 days;
    uint256 internal constant WEEK = 1 weeks;
    // @dev Additional salt for contract creation
    uint256 private counter;

    /// @dev tokenId => tokenIdV2
    mapping(uint256 => uint256) public conversions;
    /// @dev tokenId => facilitator address
    mapping(uint256 => address) public facilitators;

    /// @dev token id of veNFT owned by this contract to capture v1 VELO emissions
    uint256 public ownedTokenId;

    /// @dev Address of fake pool used to capture emissions
    address private sinkDrain;

    // @dev Address of deployed facilitator contract to clone
    address public facilitatorImplementation;

    /// @dev V1 Voting contract
    IVoterV1 public immutable voter;
    /// @dev V1 Velo contract
    IVelo public immutable velo;
    /// @dev V2 Velo contract
    IVelo public immutable veloV2;
    /// @dev V2 Minter contract
    IMinter public immutable minterV2;
    /// @dev V1 Voting Escrow contract
    IVotingEscrowV1 public immutable ve;
    /// @dev V2 Voting Escrow contract
    IVotingEscrow public immutable veV2;
    /// @dev V1 Rewards Distributor contract
    IRewardsDistributorV1 public immutable rewardsDistributor;
    /// @dev V1 sinkDrain gauge
    IGaugeV1 public gauge;
    /// @dev epoch start => velo captured
    mapping(uint256 => uint256) internal _captured;

    constructor(
        address _forwarder,
        address _sinkDrain,
        address _facilitatorImplementation,
        address _voter,
        address _velo,
        address _veloV2,
        address _ve,
        address _veV2,
        address _rewardsDistributor
    ) ERC2771Context(_forwarder) {
        sinkDrain = _sinkDrain;
        facilitatorImplementation = _facilitatorImplementation;
        voter = IVoterV1(_voter);
        velo = IVelo(_velo);
        veloV2 = IVelo(_veloV2);
        minterV2 = IMinter(IVelo(_veloV2).minter());
        ve = IVotingEscrowV1(_ve);
        veV2 = IVotingEscrow(_veV2);
        rewardsDistributor = IRewardsDistributorV1(_rewardsDistributor);

        velo.approve(_ve, type(uint256).max);
        veloV2.approve(_veV2, type(uint256).max);
    }

    // --------------------------------------------------------------------
    // Conversion methods
    // --------------------------------------------------------------------

    /// @inheritdoc ISinkManager
    function convertVELO(uint256 amount) external {
        uint256 _ownedTokenId = ownedTokenId;
        if (_ownedTokenId == 0) revert TokenIdNotSet();
        address sender = _msgSender();

        // Mint emissions prior to conversion
        minterV2.updatePeriod();

        // Deposit old VELO
        velo.transferFrom(sender, address(this), amount);

        // Add VELO to owned escrow
        ve.increase_amount(_ownedTokenId, amount);

        // return new VELO
        veloV2.mint(sender, amount);
        _captured[VelodromeTimeLibrary.epochStart(block.timestamp)] += amount;

        emit ConvertVELO(sender, amount, block.timestamp);
    }

    /// @inheritdoc ISinkManager
    function convertVe(uint256 tokenId) external nonReentrant returns (uint256 tokenIdV2) {
        uint256 _ownedTokenId = ownedTokenId;
        if (_ownedTokenId == 0) revert TokenIdNotSet();

        // Ensure the veNFT was not converted
        if (conversions[tokenId] != 0) revert NFTAlreadyConverted();

        // Ensure this contract has been approved to transfer the veNFT
        if (!ve.isApprovedOrOwner(address(this), tokenId)) revert NFTNotApproved();

        // Ensure the veNFT has not expired
        if (ve.locked__end(tokenId) <= block.timestamp) revert NFTExpired();

        address sender = _msgSender();

        // Mint emissions prior to conversion
        minterV2.updatePeriod();

        // Create contract to facilitate the merge
        SinkManagerFacilitator facilitator = SinkManagerFacilitator(
            Clones.cloneDeterministic(
                facilitatorImplementation,
                keccak256(abi.encodePacked(++counter, blockhash(block.number - 1)))
            )
        );

        // Transfer the veNFT to the facilitator
        ve.safeTransferFrom(sender, address(facilitator), tokenId);

        /* Create new veNFT with same lock parameters */

        // Fetch lock information of v1 veNFT
        (int128 _lockAmount, uint256 lockEnd) = ve.locked(tokenId); // amount of v1 VELO locked, unlock timestamp
        uint256 lockAmount = uint256(int256(_lockAmount));
        // determine lockDuration based on current epoch start - see unlockTime in ve._createLock()
        uint256 lockDuration = lockEnd - (block.timestamp / WEEK) * WEEK;

        // mint v2 VELO to deposit into lock
        veloV2.mint(address(this), lockAmount);

        // Create v2 veNFT
        tokenIdV2 = veV2.createLockFor(lockAmount, lockDuration, sender);

        // Merge into the sinkManager veNFT
        ve.approve(address(facilitator), ownedTokenId);
        facilitator.merge(ve, tokenId, ownedTokenId);
        ve.approve(address(0), ownedTokenId);

        // poke vote to update voting balance to gauge
        voter.poke(_ownedTokenId);

        // event emission and storage of conversion
        conversions[tokenId] = tokenIdV2;
        facilitators[tokenId] = address(facilitator);
        _captured[VelodromeTimeLibrary.epochStart(block.timestamp)] += lockAmount;
        emit ConvertVe(sender, tokenId, tokenIdV2, lockAmount, lockEnd, block.timestamp);
    }

    // --------------------------------------------------------------------
    // Maintenance
    // --------------------------------------------------------------------
    /// @inheritdoc ISinkManager
    function claimRebaseAndGaugeRewards() external {
        if (address(gauge) == address(0)) revert GaugeNotSet();
        uint256 _ownedTokenId = ownedTokenId;

        // Claim gauge rewards and deposit into owned veNFT
        uint256 amountResidual = velo.balanceOf(address(this));
        address[] memory rewards = new address[](1);
        rewards[0] = address(velo);
        gauge.getReward(address(this), rewards);
        uint256 amountAfterReward = velo.balanceOf(address(this));
        uint256 amountRewarded = amountAfterReward - amountResidual;
        if (amountAfterReward > 0) {
            ve.increase_amount(_ownedTokenId, amountAfterReward);
        }

        // Claim rebases
        uint256 amountRebased = rewardsDistributor.claimable(_ownedTokenId);
        if (amountRebased > 0) {
            rewardsDistributor.claim(_ownedTokenId);
        }

        // increase locktime to max if possible
        uint256 unlockTime = ((block.timestamp + MAXTIME) / WEEK) * WEEK;
        (, uint256 end) = ve.locked(_ownedTokenId);
        if (unlockTime > end) {
            ve.increase_unlock_time(_ownedTokenId, MAXTIME);
        }

        // poke vote to update voting balance to gauge
        voter.poke(_ownedTokenId);

        emit ClaimRebaseAndGaugeRewards(_msgSender(), amountResidual, amountRewarded, amountRebased, block.timestamp);
    }

    // --------------------------------------------------------------------
    // Admin
    // --------------------------------------------------------------------
    /// @notice Initial setup of the ownedTokenId, the v1 veNFT which votes for the SinkDrain
    function setOwnedTokenId(uint256 tokenId) external onlyOwner {
        if (ownedTokenId != 0) revert TokenIdAlreadySet();
        if (ve.ownerOf(tokenId) != address(this)) revert ContractNotOwnerOfToken();
        ownedTokenId = tokenId;
    }

    /// @notice Deposit all of SinkDrain token to gauge to earn 100% of rewards
    /// And vote for the gauge to allocate rewards
    function setupSinkDrain(address _gauge) external onlyOwner {
        uint256 _ownedTokenId = ownedTokenId;
        if (_ownedTokenId == 0) revert TokenIdNotSet();
        if (address(gauge) != address(0)) revert GaugeAlreadySet();

        // Set gauge for future claims
        gauge = IGaugeV1(_gauge);

        // Approve gauge to transfer token
        IERC20 token = IERC20(gauge.stake());
        uint256 balance = token.balanceOf(address(this));
        token.approve(_gauge, balance);

        // Deposit SinkDrain to gauge
        gauge.deposit(balance, 0);

        // Initial vote
        address[] memory poolVote = new address[](1);
        uint256[] memory weights = new uint256[](1);
        poolVote[0] = gauge.stake();
        weights[0] = 1;
        voter.vote(_ownedTokenId, poolVote, weights);
    }

    /// @inheritdoc ISinkManager
    function captured(uint256 _timestamp) external view returns (uint256 _amount) {
        _amount = _captured[VelodromeTimeLibrary.epochStart(_timestamp)];
    }

    function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    function _msgSender() internal view override(ERC2771Context, Context) returns (address) {
        return ERC2771Context._msgSender();
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IVotingEscrowV1} from "../../interfaces/v1/IVotingEscrowV1.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/// @notice This contract is used to support merging into the Velodrome SinkManager
contract SinkManagerFacilitator is ERC721Holder {
    constructor() {}

    function merge(IVotingEscrowV1 _ve, uint256 _from, uint256 _to) external {
        _ve.merge(_from, _to);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVelo} from "./IVelo.sol";

interface ISinkManager {
    event ConvertVELO(address indexed who, uint256 amount, uint256 timestamp);
    event ConvertVe(
        address indexed who,
        uint256 indexed tokenId,
        uint256 indexed tokenIdV2,
        uint256 amount,
        uint256 lockEnd,
        uint256 timestamp
    );
    event ClaimRebaseAndGaugeRewards(
        address indexed who,
        uint256 amountResidual,
        uint256 amountRewarded,
        uint256 amountRebased,
        uint256 timestamp
    );

    error ContractNotOwnerOfToken();
    error GaugeAlreadySet();
    error GaugeNotSet();
    error GaugeNotSinkDrain();
    error NFTAlreadyConverted();
    error NFTNotApproved();
    error NFTExpired();
    error TokenIdNotSet();
    error TokenIdAlreadySet();

    function ownedTokenId() external view returns (uint256);

    function velo() external view returns (IVelo);

    function veloV2() external view returns (IVelo);

    /// @notice Helper utility that returns amount of token captured by epoch
    function captured(uint256 timestamp) external view returns (uint256 amount);

    /// @notice User converts their v1 VELO into v2 VELO
    /// @param amount Amount of VELO to convert
    function convertVELO(uint256 amount) external;

    /// @notice User converts their v1 ve into v2 ve
    /// @param tokenId      Token ID of v1 ve
    /// @return tokenIdV2   Token ID of v2 ve
    function convertVe(uint256 tokenId) external returns (uint256 tokenIdV2);

    /// @notice Claim SinkManager-eligible rebase and gauge rewards to lock into the SinkManager-owned tokenId
    /// @dev Callable by anyone
    function claimRebaseAndGaugeRewards() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMinter {
    error AlreadyNudged();
    error NotEpochGovernor();
    error TailEmissionsInactive();

    event Mint(address indexed _sender, uint256 _weekly, uint256 _circulating_supply, bool indexed _tail);
    event Nudge(uint256 indexed _period, uint256 _oldRate, uint256 _newRate);

    /// @notice Timestamp of start of epoch that updatePeriod was last called in
    function activePeriod() external returns (uint256);

    /// @notice Allows epoch governor to modify the tail emission rate by at most 1 basis point
    ///         per epoch to a maximum of 100 basis points or to a minimum of 1 basis point.
    ///         Note: the very first nudge proposal must take place the week prior
    ///         to the tail emission schedule starting.
    /// @dev Throws if not epoch governor.
    ///      Throws if not currently in tail emission schedule.
    ///      Throws if already nudged this epoch.
    ///      Throws if nudging above maximum rate.
    ///      Throws if nudging below minimum rate.
    ///      This contract is coupled to EpochGovernor as it requires three option simple majority voting.
    function nudge() external;

    /// @notice Calculates rebases according to the formula
    ///         weekly * (ve.totalSupply / velo.totalSupply) ^ 3 / 2
    ///         Note that ve.totalSupply is the locked ve supply
    ///         velo.totalSupply is the total ve supply minted
    /// @param _minted Amount of VELO minted this epoch
    /// @return _growth Rebases
    function calculateGrowth(uint256 _minted) external view returns (uint256 _growth);

    /// @notice Processes emissions and rebases. Callable once per epoch (1 week).
    /// @return _period Start of current epoch.
    function updatePeriod() external returns (uint256 _period);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721, IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import {IVotes} from "../governance/IVotes.sol";

interface IVotingEscrow is IVotes, IERC4906, IERC721Metadata {
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
    function factoryRegistry() external view returns (address);

    function token() external view returns (address);

    function distributor() external view returns (address);

    function voter() external view returns (address);

    function team() external view returns (address);

    function artProxy() external view returns (address);

    function allowedManager() external view returns (address);

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

    function supportsInterface(bytes4 _interfaceID) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                             ESCROW STORAGE
    //////////////////////////////////////////////////////////////*/

    function epoch() external view returns (uint256);

    function supply() external view returns (uint256);

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

    /// @notice Toggle split for a specific veNFT.
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
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVelo is IERC20 {
    error NotMinter();
    error NotOwner();
    error NotMinterOrSinkManager();
    error SinkManagerAlreadySet();

    function mint(address, uint256) external returns (bool);

    function minter() external returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGaugeV1 {
    function balanceOf(address _account) external returns (uint256 _balance);

    function stake() external returns (address _stake);

    function totalSupply() external returns (uint256 _totalSupply);

    function getReward(address _account, address[] memory _tokens) external;

    function deposit(uint256 _amount, uint256 _tokenId) external;

    function notifyRewardAmount(address _token, uint256 _amount) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVoterV1 {
    function governor() external returns (address _governor);

    function totalWeight() external returns (uint256 _totalWeight);

    function usedWeights(uint256 _tokenId) external returns (uint256 _weight);

    function votes(uint256 _tokenId, address _pool) external returns (uint256 _votes);

    function createGauge(address _pool) external returns (address _gauge);

    function gauges(address pool) external view returns (address);

    function distribute(address _gauge) external;

    function poke(uint256 _tokenId) external;

    function vote(uint256 _tokenId, address[] memory _pools, uint256[] memory _weights) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVotingEscrowV1 {
    struct Point {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    function getApproved(uint256 _tokenId) external view returns (address);

    function isApprovedOrOwner(address _spender, uint256 _tokenId) external returns (bool);

    function locked__end(uint256 _tokenId) external view returns (uint256 _locked);

    function locked(uint256 _tokenId) external view returns (int128 _amount, uint256 _end);

    function ownerOf(uint256 _tokenId) external view returns (address _owner);

    function increase_amount(uint256 _tokenId, uint256 _amount) external;

    function increase_unlock_time(uint256 _tokenId, uint256 _duration) external;

    function create_lock(uint256 _amount, uint256 _end) external returns (uint256 tokenId);

    function create_lock_for(uint256 _amount, uint256 _end, address _to) external returns (uint256 tokenId);

    function approve(address who, uint256 tokenId) external;

    function balanceOfNFT(uint256) external view returns (uint256 amount);

    function user_point_epoch(uint256) external view returns (uint256);

    function user_point_history(uint256, uint256) external view returns (Point memory);

    function merge(uint256 _from, uint256 _to) external;

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRewardsDistributorV1 {
    function claimable(uint256 _tokenId) external view returns (uint256 _claimable);

    function claim(uint256 _tokenId) external returns (uint256 _amount);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
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
// OpenZeppelin Contracts v4.4.1 (token/ERC721/utils/ERC721Holder.sol)

pragma solidity ^0.8.0;

import "../IERC721Receiver.sol";

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

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
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/Clones.sol)

pragma solidity ^0.8.0;

/**
 * @dev https://eips.ethereum.org/EIPS/eip-1167[EIP 1167] is a standard for
 * deploying minimal proxy contracts, also known as "clones".
 *
 * > To simply and cheaply clone contract functionality in an immutable way, this standard specifies
 * > a minimal bytecode implementation that delegates all calls to a known, fixed address.
 *
 * The library includes functions to deploy a proxy using either `create` (traditional deployment) or `create2`
 * (salted deterministic deployment). It also includes functions to predict the addresses of clones deployed using the
 * deterministic method.
 *
 * _Available since v3.4._
 */
library Clones {
    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone(address implementation) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create(0, 0x09, 0x37)
        }
        require(instance != address(0), "ERC1167: create failed");
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create2(0, 0x09, 0x37, salt)
        }
        require(instance != address(0), "ERC1167: create2 failed");
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x38), deployer)
            mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
            mstore(add(ptr, 0x14), implementation)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(ptr, 0x58), salt)
            mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
            predicted := keccak256(add(ptr, 0x43), 0x55)
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt
    ) internal view returns (address predicted) {
        return predictDeterministicAddress(implementation, salt, address(this));
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

library VelodromeTimeLibrary {
    uint256 internal constant WEEK = 7 days;

    /// @dev Returns start of epoch based on current timestamp
    function epochStart(uint256 timestamp) internal pure returns (uint256) {
        unchecked {
            return timestamp - (timestamp % WEEK);
        }
    }

    /// @dev Returns start of next epoch / end of current epoch
    function epochNext(uint256 timestamp) internal pure returns (uint256) {
        unchecked {
            return timestamp - (timestamp % WEEK) + WEEK;
        }
    }

    /// @dev Returns start of voting window
    function epochVoteStart(uint256 timestamp) internal pure returns (uint256) {
        unchecked {
            return timestamp - (timestamp % WEEK) + 1 hours;
        }
    }

    /// @dev Returns end of voting window / beginning of unrestricted voting window
    function epochVoteEnd(uint256 timestamp) internal pure returns (uint256) {
        unchecked {
            return timestamp - (timestamp % WEEK) + WEEK - 1 hours;
        }
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