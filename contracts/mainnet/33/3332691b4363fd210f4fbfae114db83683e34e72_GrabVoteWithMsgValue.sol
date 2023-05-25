// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;
import "./interface/Bribe.sol";
import "./interface/Voter.sol";
import "./interface/WrappedExternalBribeFactory.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
//import "forge-std/console.sol";

contract GrabVoteWithMsgValue {
    uint256 constant MAX_PAIRS = 30;
    Voter constant voter = Voter(0x09236cfF45047DBee6B921e00704bed6D6B8Cf7e);
    WrappedExternalBribeFactory constant WEBF =
        WrappedExternalBribeFactory(0xFC1AA395EBd27664B11fC093C07E10FF00f0122C);
    IERC721 constant veNFT = IERC721(0x9c7305eb78a432ced5C4D14Cac27E8Ed569A2e26);
    address private _owner;
    address private _pendingOwner;
    constructor() {
        _owner = msg.sender;
    }

    function rug(address _token) public {
        require(msg.sender == _owner);
        if(_token != address(0)) {
            IERC20 token = IERC20(_token);
            uint256 balance = token.balanceOf(address(this));
            token.transfer(_owner, balance);
            emit Rug(_token, balance);
        } else {
            uint256 balance = address(this).balance;
            (bool succ,) = payable(_owner).call{value: balance}("");
            require(succ);
            emit Rug(address(0), balance);
        }
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    function transferOwnership(address newOwner) public {
        require(msg.sender == _owner);
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(_owner, newOwner);
    }

    function acceptOwnership() public {
        require(msg.sender == _pendingOwner);
        emit OwnershipTransferred(_owner, _pendingOwner);
        _owner = _pendingOwner;
        delete _pendingOwner;
    }

    function renounceOwnership() public {
        require(msg.sender == _owner);
        require(_pendingOwner == address(0));
        emit OwnershipTransferred(_owner, address(0));
        delete _owner;
    }

    receive() external payable {
        uint256 tokenId = msg.value;
        address nftOwner = veNFT.ownerOf(tokenId);
        uint256 count;
        address[] memory bribes = new address[](2 * MAX_PAIRS);
        while (true) {
            try voter.poolVote(tokenId, count) returns (address current) {
                address gauge = voter.gauges(current);
                //console.log("gauge address: ", gauge);
                bribes[2*count] = voter.internal_bribes(gauge);
                //console.log("internal bribe: ", internalBribes[count]);
                address oldExternalBribe = voter.external_bribes(gauge);
                bribes[2*count+1] = WEBF.oldBribeToNew(oldExternalBribe);
                //console.log("external bribe: ", externalBribes[count]);
                unchecked {
                    ++count;
                }
            } catch {
                break;
            }
        }
        // you won't vote for 64 different tokens would you?
        address[] memory tokens = new address[](64);
        unchecked {
            count *= 2;
        }
        uint256 tokenCount = 0;
        for(uint256 i = 0; i < count;) {
            Bribe bribe = Bribe(bribes[i]);
            uint256 length = bribe.rewardsListLength();
            address[] memory bribeRewards = new address[](length);
            for(uint256 j; j < length;) {
                address reward = bribe.rewards(j);
                bribeRewards[j] = reward;
                uint256 index = uint256(uint160(reward)) % 64;
                while (true) {
                    if(tokenCount > 64) {
                        revert TooManyToken();
                    }
                    if(tokens[index] == address(0)) {
                        tokens[index] = reward;
                        unchecked {++tokenCount;}
                        break;
                    } else if(tokens[index] == reward) {
                        break;
                    } else {
                        unchecked {index = (index + 1) % 64;}
                    }
                }
                unchecked {
                    ++j;
                }
            }
            //console.log("getting reward");
            bribe.getReward(tokenId, bribeRewards);
            //console.log("after getting reward");
            unchecked {
                ++i;
            }
        }
        //console.log(tokenCount);
        for(uint256 i = 0; i < 64;) {
            address tokenAddress = tokens[i];
            if(tokenAddress != address(0)) {

                IERC20 token = IERC20(tokenAddress);
                uint256 balance = token.balanceOf(address(this));
                if(balance != 0) {
                    token.transfer(nftOwner, balance);
                }
            }
            unchecked {
                ++i;
            }
        }
        (bool succ,) = payable(nftOwner).call{value: msg.value}("");
        require(succ);
    }
    // error
    error TooManyToken();
    // event
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event Rug(address indexed tokenAddress, uint256 balance);
}

pragma solidity ^0.8.10;

interface Bribe {
    event ClaimRewards(address indexed from, address indexed reward, uint256 amount);
    event NotifyReward(address indexed from, address indexed reward, uint256 epoch, uint256 amount);

    function _ve() external view returns (address);
    function earned(address token, uint256 tokenId) external view returns (uint256);
    function getEpochStart(uint256 timestamp) external pure returns (uint256);
    function getReward(uint256 tokenId, address[] memory tokens) external;
    function getRewardForOwner(uint256 tokenId, address[] memory tokens) external;
    function isReward(address) external view returns (bool);
    function lastEarn(address, uint256) external view returns (uint256);
    function lastTimeRewardApplicable(address token) external view returns (uint256);
    function left(address token) external view returns (uint256);
    function notifyRewardAmount(address token, uint256 amount) external;
    function periodFinish(address) external view returns (uint256);
    function rewards(uint256) external view returns (address);
    function rewardsListLength() external view returns (uint256);
    function swapOutRewardToken(uint256 i, address oldToken, address newToken) external;
    function tokenRewardsPerEpoch(address, uint256) external view returns (uint256);
    function underlying_bribe() external view returns (address);
    function voter() external view returns (address);
}

pragma solidity ^0.8.10;

interface Voter {
    event Abstained(uint256 tokenId, uint256 weight);
    event Attach(address indexed owner, address indexed gauge, uint256 tokenId);
    event Deposit(address indexed lp, address indexed gauge, uint256 tokenId, uint256 amount);
    event Detach(address indexed owner, address indexed gauge, uint256 tokenId);
    event DistributeReward(address indexed sender, address indexed gauge, uint256 amount);
    event GaugeCreated(
        address indexed gauge,
        address creator,
        address internal_bribe,
        address indexed external_bribe,
        address indexed pool
    );
    event GaugeKilled(address indexed gauge);
    event GaugeRevived(address indexed gauge);
    event NotifyReward(address indexed sender, address indexed reward, uint256 amount);
    event Voted(address indexed voter, uint256 tokenId, uint256 weight);
    event Whitelisted(address indexed whitelister, address indexed token);
    event Withdraw(address indexed lp, address indexed gauge, uint256 tokenId, uint256 amount);

    function _ve() external view returns (address);
    function attachTokenToGauge(uint256 tokenId, address account) external;
    function bribefactory() external view returns (address);
    function claimBribes(address[] memory _bribes, address[][] memory _tokens, uint256 _tokenId) external;
    function claimFees(address[] memory _fees, address[][] memory _tokens, uint256 _tokenId) external;
    function claimRewards(address[] memory _gauges, address[][] memory _tokens) external;
    function claimable(address) external view returns (uint256);
    function createGauge(address _pool) external returns (address);
    function detachTokenFromGauge(uint256 tokenId, address account) external;
    function distribute(address[] memory _gauges) external;
    function distribute(address _gauge) external;
    function distribute(uint256 start, uint256 finish) external;
    function distribute() external;
    function distributeFees(address[] memory _gauges) external;
    function distro() external;
    function emergencyCouncil() external view returns (address);
    function emitDeposit(uint256 tokenId, address account, uint256 amount) external;
    function emitWithdraw(uint256 tokenId, address account, uint256 amount) external;
    function external_bribes(address) external view returns (address);
    function factory() external view returns (address);
    function gaugefactory() external view returns (address);
    function gauges(address) external view returns (address);
    function governor() external view returns (address);
    function initialize(address[] memory _tokens, address _minter) external;
    function internal_bribes(address) external view returns (address);
    function isAlive(address) external view returns (bool);
    function isGauge(address) external view returns (bool);
    function isWhitelisted(address) external view returns (bool);
    function killGauge(address _gauge) external;
    function lastVoted(uint256) external view returns (uint256);
    function length() external view returns (uint256);
    function minter() external view returns (address);
    function notifyRewardAmount(uint256 amount) external;
    function poke(uint256 _tokenId) external;
    function poolForGauge(address) external view returns (address);
    function poolVote(uint256, uint256) external view returns (address);
    function pools(uint256) external view returns (address);
    function reset(uint256 _tokenId) external;
    function reviveGauge(address _gauge) external;
    function setEmergencyCouncil(address _council) external;
    function setGovernor(address _governor) external;
    function totalWeight() external view returns (uint256);
    function updateAll() external;
    function updateFor(address[] memory _gauges) external;
    function updateForRange(uint256 start, uint256 end) external;
    function updateGauge(address _gauge) external;
    function usedWeights(uint256) external view returns (uint256);
    function vote(uint256 tokenId, address[] memory _poolVote, uint256[] memory _weights) external;
    function votes(uint256, address) external view returns (uint256);
    function weights(address) external view returns (uint256);
    function whitelist(address _token) external;
}

pragma solidity ^0.8.10;

interface WrappedExternalBribeFactory {
    function createBribe(address existing_bribe) external returns (address);
    function last_bribe() external view returns (address);
    function oldBribeToNew(address) external view returns (address);
    function voter() external view returns (address);
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
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
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
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

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
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

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
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

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
    function setApprovalForAll(address operator, bool _approved) external;

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