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
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

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
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
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

//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract OppaBearBidAction is Ownable, ReentrancyGuard {
    // Events
    event Bid(
        address bidder,
        uint256 bidAmount,
        uint256 bidderTotal,
        uint256 bucketTotal
    );
    event FinalPriceSet(address setter, uint256 finalPrice);

    // Testing Events
    event RefundProcessed(address indexed bidder, uint256 refundAmount);
    event MintProcessed(address indexed bidder, uint256 mintAmount);

    // Global Variables
    uint256 public finalPrice;

    // Amount Serum
    uint256 public amountSerum;

    // Total Bidder
    address[] public bidder;

    // Bid Winner
    address[] private winner;

    // Total winnder
    uint256 public totalWinner;

    // Structs
    struct BidData {
        address bidder;
        uint232 commitment;
        uint16 totalMinted;
        uint256 totalRefundClaimed;
        bool refundClaimed;
    }

    struct BidWinner {
        address bidder;
        uint256 totalMinted;
    }

    // Mappings
    mapping(address => BidData) public userToBidData;
    mapping(address => uint256) public bidWinner;

    // Bool Triggers
    bool public biddingActive;

    // Administrative Functions
    function setBiddingActive(bool bool_) external onlyOwner {
        biddingActive = bool_;
    }

    function setAmountSerum(uint256 _amount) external onlyOwner {
        amountSerum = _amount;
    }

    receive() external payable {
        bid();
    }

    // Administrative Process of Commits
    function processCommits(address[] memory _bidder) external onlyOwner {
        uint256 _finalPrice = finalPrice;
        require(_finalPrice != 0, "Final Price not set!");
        for (uint256 i; i < _bidder.length; ) {
            _internalProcessCommit(_bidder[i], _finalPrice);
            unchecked {
                ++i;
            }
        }
    }

    // External Function
    function bid() public payable {
        // Require bidding to be active
        require(biddingActive, "Bidding is not active!");
        // Require EOA only
        require(msg.sender == tx.origin, "No Smart Contracts!");

        require(msg.value > 0, "Please bid with msg.value!");

        require(msg.value >= finalPrice, "Please bid more than current price");

        _refeshPrice();

        // Incresment Total bidder
        if (userToBidData[msg.sender].commitment == 0) {
            bidder.push(msg.sender);
        }

        // Load the current commitment value from mapping to memory
        uint256 _currentCommitment = userToBidData[msg.sender].commitment;

        // Calculate thew new commitment based on the bid
        uint256 _newCommitment = _currentCommitment + msg.value;

        // Store the new commitment value
        userToBidData[msg.sender].commitment = uint232(_newCommitment);
        userToBidData[msg.sender].bidder = msg.sender;

        // Emit Event for Data Parsing and Analysis
        emit Bid(msg.sender, msg.value, _newCommitment, address(this).balance);
    }

    // Public View Functions
    function getEligibleMints(address bidder_) public view returns (uint256) {
        require(finalPrice != 0, "Final Price not set!");

        uint256 _eligibleMints = _calMintsFromCommitment(
            userToBidData[bidder_].commitment,
            finalPrice
        );

        return _eligibleMints;
    }

    function getWinnerInformation() external view returns (BidWinner[] memory) {
        require(!biddingActive, "Bidding is active!");
        BidWinner[] memory _bidWinner = new BidWinner[](totalWinner);

        for (uint256 index = 0; index < totalWinner; index++) {
            address winnerAddress = winner[index];
            uint256 amount = bidWinner[winnerAddress];

            _bidWinner[index].bidder = winnerAddress;
            _bidWinner[index].totalMinted = amount;
        }

        return _bidWinner;
    }

    function getRefundAmount(address bidder_) public view returns (uint256) {
        require(finalPrice != 0, "Final Price not set!");

        uint256 _remainder = _calRemainderFromCommitment(
            userToBidData[bidder_].commitment,
            finalPrice
        );

        return !userToBidData[bidder_].refundClaimed ? _remainder : 0;
    }

    function queryCommitments() external view returns (BidData[] memory) {
        uint256 l = bidder.length;

        BidData[] memory _BidDatas = new BidData[](l);
        for (uint256 i; i < l; ) {
            _BidDatas[i] = userToBidData[bidder[i]];
            unchecked {
                ++i;
            }
        }
        return _BidDatas;
    }

    function withdrawEther(address _to) public onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(_to).call{value: balance}("");

        require(success, "failed to withdraw");
    }

    function getAmountBidder() external view returns (uint256) {
        return bidder.length;
    }

    // Internal Function

    function _refeshPrice() internal {
        finalPrice = address(this).balance / amountSerum;
    }

    function _calMintsFromCommitment(uint256 commitment_, uint256 finalPrice_)
        internal
        pure
        returns (uint256)
    {
        return commitment_ / finalPrice_;
    }

    function _calRemainderFromCommitment(
        uint256 commitment_,
        uint256 finalPrice_
    ) internal pure returns (uint256) {
        return commitment_ % finalPrice_;
    }

    function _internalProcessRefund(address bidder_, uint256 refundAmount_)
        internal
    {
        userToBidData[bidder_].refundClaimed = true;
        userToBidData[bidder_].totalRefundClaimed = refundAmount_;
        if (refundAmount_ != 0) {
            (bool success, ) = payable(bidder_).call{value: refundAmount_}("");
            require(success, "failed to refund");
        }
        emit RefundProcessed(bidder_, refundAmount_);
    }

    function _internalProcessMint(address bidder_, uint256 mintAmount_)
        internal
    {
        uint16 _mintAmount = uint16(mintAmount_);
        userToBidData[bidder_].totalMinted += _mintAmount;
        bidWinner[bidder_] = _mintAmount;
        winner.push(bidder_);
        totalWinner += 1;
    }

    function _internalProcessCommit(address bidder_, uint256 finalPrice_)
        internal
    {
        BidData memory _BidData = userToBidData[bidder_];
        uint256 commitment = uint256(_BidData.commitment);
        uint256 eligibleRefunds = _calRemainderFromCommitment(
            commitment,
            finalPrice_
        );

        uint256 _eligibleMints = _calMintsFromCommitment(
            commitment,
            finalPrice_
        );

        if (!_BidData.refundClaimed) {
            _internalProcessRefund(bidder_, eligibleRefunds);
        }

        if (_eligibleMints > _BidData.totalMinted) {
            uint256 _remainingMints = _eligibleMints - _BidData.totalMinted;
            _internalProcessMint(bidder_, _remainingMints);
        }
    }
}