/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-06-09
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

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
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
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

// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

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

struct Randomness
{
    bytes32 randomBytes;
    uint commitmentDeadline;
    uint revealDeadline;
    bool rewardIsClaimed;
    uint stakeAmount;
    address creator;
}

contract RandomnessCeremony {
    using Counters for Counters.Counter;
    enum CommitmentState {NotCommitted, Committed, Revealed, Slashed}

    function sendETH(address payable _to, uint amount) internal {
        (bool sent, bytes memory data) = _to.call{value: amount}("");
        data;
        require(sent, "Failed to send Ether");
    }

    struct Commitment
    {
        address committer;
        CommitmentState state;
    }

    Counters.Counter public randomnessIds;
    mapping(uint randomnessId => Randomness) public randomness;
    mapping(uint randomnessId => mapping(bytes32 hashedValue => Commitment commitment)) public commitments;

    constructor() {
    }

    // Public Functions

    function commit(address committer, uint randomnessId, bytes32 hashedValue) public payable {
        require(msg.value == randomness[randomnessId].stakeAmount, "Invalid stake amount");
        require(block.timestamp <= randomness[randomnessId].commitmentDeadline, "Can't commit at this moment.");
        commitments[randomnessId][hashedValue] = Commitment(committer, CommitmentState.Committed);
    }

    function reveal(uint randomnessId, bytes32 hashedValue, bytes32 secretValue) public {
        require(block.timestamp > randomness[randomnessId].commitmentDeadline &&
            block.timestamp <= randomness[randomnessId].revealDeadline, "Can't reveal at this moment.");
        require(commitments[randomnessId][hashedValue].state == CommitmentState.Committed, "Hash is not commited");
        require(hashedValue == keccak256(abi.encodePacked(secretValue)), "Invalid secret value");

        commitments[randomnessId][hashedValue].state = CommitmentState.Revealed;

        randomness[randomnessId].randomBytes = randomness[randomnessId].randomBytes ^ secretValue;

        sendETH(
            payable(commitments[randomnessId][hashedValue].committer),
            randomness[randomnessId].stakeAmount
        );
    }

    function getRandomness(uint randomnessId) public view returns(bytes32) {
        require(block.timestamp > randomness[randomnessId].revealDeadline,
            "Randomness not ready yet.");
        return randomness[randomnessId].randomBytes;
    }

    function generateRandomness(uint commitmentDeadline, uint revealDeadline, uint stakeAmount) public returns(uint){
        uint randomnessId = randomnessIds.current();
        randomness[randomnessId] = Randomness(
            bytes32(0),
            commitmentDeadline,
            revealDeadline,
            false,
            stakeAmount,
            msg.sender
        );
        randomnessIds.increment();
        return randomnessId;
    }

    function claimSlashedETH(uint randomnessId, bytes32 hashedValue) public {
        require(randomness[randomnessId].creator == msg.sender, "Only creator can claim slashed");
        require(block.timestamp > randomness[randomnessId].revealDeadline, "Slashing period has not happened yet");
        require(commitments[randomnessId][hashedValue].state == CommitmentState.Committed, "This commitment was not slashed");
        commitments[randomnessId][hashedValue].state = CommitmentState.Slashed;
        sendETH(
            payable(msg.sender),
            randomness[randomnessId].stakeAmount
        );
    }
}

contract LottoAndNFTCeremony is Ownable {

    using Counters for Counters.Counter;
    RandomnessCeremony public randomnessCeremony;

    function sendETH(address payable _to, uint amount) internal {
        (bool sent, bytes memory data) = _to.call{value: amount}("");
        data;
        require(sent, "Failed to send Ether");
    }

    struct Ceremony {
        uint randomnessCeremonyId;
        bool isNFTClaimed;
        bool isETHClaimed;
        bool isNFTCreatorETHClaimed;
        bool isProtocolETHClaimed;
        uint ticketCount;
        uint ticketPrice;
        uint stakeAmount;
        uint nftID;
        address nftContractAddress;
        address nftCreatorAddress;
        address protocolAddress;
        Percentages percentages;
    }

    struct Percentages {
        uint lottoETHPercentage;
        uint nftCreatorETHPercentage;
        uint protocolETHPercentage;
    }

    Counters.Counter public ceremonyCount;
    mapping(uint ceremonyId => Ceremony) public ceremonies;
    mapping(uint ceremonyId => mapping(uint ticketId => address ticketOwner)) public tickets;

    constructor(address randomnessCeremonyAddress) {
        randomnessCeremony = RandomnessCeremony(payable(randomnessCeremonyAddress));
    }

    // Public functions

    function createCeremony(
        uint commitmentDeadline,
        uint revealDeadline,
        uint ticketPrice,
        uint stakeAmount,
        uint nftID,
        address nftContractAddress,
        address nftCreatorAddress,
        address protocolAddress,
        uint nftCreatorETHPercentage,
        uint protocolETHPercentage) public {
        uint randomnessCeremonyId = randomnessCeremony.generateRandomness(
            commitmentDeadline,
            revealDeadline,
            stakeAmount);
        IERC721(nftContractAddress).transferFrom(msg.sender, address(this), nftID);
        uint lottoETHPercentage = 10000 - nftCreatorETHPercentage - protocolETHPercentage;
        ceremonies[ceremonyCount.current()] = Ceremony(
            randomnessCeremonyId,
            false,
            false,
            false,
            false,
            0,
            ticketPrice,
            stakeAmount,
            nftID,
            nftContractAddress,
            nftCreatorAddress,
            protocolAddress,
            Percentages(
                lottoETHPercentage,
                nftCreatorETHPercentage,
                protocolETHPercentage
                )
            );
        ceremonyCount.increment();
    }

    function commit(address commiter, uint ceremonyId, bytes32 hashedValue) public payable {
        Ceremony memory ceremony = ceremonies[ceremonyId];
        require(msg.value == ceremony.ticketPrice + ceremony.stakeAmount);
        randomnessCeremony.commit{value: ceremony.stakeAmount}(commiter, ceremony.randomnessCeremonyId, hashedValue);
        tickets[ceremonyId][ceremony.ticketCount] = commiter;
        ceremonies[ceremonyId].ticketCount += 1;
    }

    function reveal(uint ceremonyId, bytes32 hashedValue, bytes32 secretValue) public /** TODO Reentrancy */ {
        randomnessCeremony.reveal(ceremonies[ceremonyId].randomnessCeremonyId, hashedValue, secretValue);
    }

    function claimETH(uint ceremonyId) public {
        Ceremony memory ceremony = ceremonies[ceremonyId];
        require(!ceremony.isETHClaimed, "Already claimed");
        ceremony.isETHClaimed = true;
        address winner = getWinner(ceremonyId, WinnerType.ETHWinner);
        uint lottoETHPercentage = ceremony.percentages.lottoETHPercentage;
        sendETH(
            payable(winner),
            (ceremony.ticketPrice * ceremony.ticketCount) * lottoETHPercentage / 10000
        );
    }

    function claimNFTCreatorETH(uint ceremonyId) public {
        Ceremony memory ceremony = ceremonies[ceremonyId];
        require(!ceremony.isNFTCreatorETHClaimed, "Already claimed");
        ceremony.isNFTCreatorETHClaimed = true;
        address nftCreatorAddress = ceremony.nftCreatorAddress;
        uint nftCreatorETHPercentage = ceremony.percentages.nftCreatorETHPercentage;
        sendETH(
            payable(nftCreatorAddress),
            (ceremony.ticketPrice * ceremony.ticketCount) * nftCreatorETHPercentage / 10000
        );
    }

    function claimProtocolETH(uint ceremonyId) public {
        Ceremony memory ceremony = ceremonies[ceremonyId];
        require(!ceremony.isProtocolETHClaimed, "Already claimed");
        ceremony.isProtocolETHClaimed = true;
        address protocolAddress = ceremony.protocolAddress;
        uint protocolETHPercentage = ceremony.percentages.protocolETHPercentage;
        sendETH(
            payable(protocolAddress),
            (ceremony.ticketPrice * ceremony.ticketCount) * protocolETHPercentage / 10000
        );
    }

    function claimNFT(uint ceremonyId) public {
        Ceremony memory ceremony = ceremonies[ceremonyId];
        require(!ceremony.isNFTClaimed, "Already claimed");
        ceremony.isNFTClaimed = true;
        address winner = getWinner(ceremonyId, WinnerType.NFTWinner);
        IERC721(ceremony.nftContractAddress).transferFrom(address(this), winner, ceremony.nftID);
    }

    // Creator functions

    function claimSlashedETH(uint randomnessCeremonyId, bytes32 hashedValue) public /** Slashed eth nao wat */  {
        randomnessCeremony.claimSlashedETH(randomnessCeremonyId, hashedValue);
    }

    // View functions
    enum WinnerType
    {
        ETHWinner,
        NFTWinner,
        BeerRoundLooser
    }

    function getWinner(uint ceremonyId, WinnerType winnerType) public view returns(address) {
        uint randomness = uint(getRandomness(ceremonyId));
        uint winnerRandomness = uint(keccak256(abi.encode(randomness, winnerType)));
        uint randomTicket = winnerRandomness % ceremonies[ceremonyId].ticketCount;
        return tickets[ceremonyId][randomTicket];
    }

    function getRandomness(uint ceremonyId) public view returns(uint) {
        return uint(randomnessCeremony.getRandomness(ceremonyId));
    }
}