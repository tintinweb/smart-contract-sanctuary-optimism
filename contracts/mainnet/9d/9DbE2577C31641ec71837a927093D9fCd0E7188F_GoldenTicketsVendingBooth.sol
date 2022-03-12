// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;
/* solhint-disable not-rely-on-time, reason-string, var-name-mixedcase */

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { CircusAccessControlled, ICircusAuthority } from "../../libraries/access/CircusAccessControlled.sol";
import { IGoldenTickets } from "../../interfaces/IGoldenTickets.sol";
import { IGoldenTicketsVendingBooth } from "../../interfaces/IGoldenTicketsVendingBooth.sol";
import { IGovernableTreasury } from "../../interfaces/IGovernableTreasury.sol";
import { IMainShow } from "../../interfaces/IMainShow.sol";
import { IWETH9 } from "../../interfaces/externals/IWETH9.sol";

/**
 * @author BarnabyBob
 * @title GoldenTicketsVendingBooth
 * @notice Get those tickets while you are early, price goes up!
 * @dev Fair crowdsale-like contract used to bootstrap Barnab...CircusDAO treasury
 */
contract GoldenTicketsVendingBooth is CircusAccessControlled, ReentrancyGuard, IGoldenTicketsVendingBooth {
	/* ========== DEPENDENCIES ========== */

	using SafeERC20 for IGoldenTickets;
	using SafeERC20 for IWETH9;

	/* ========== STATE VARIABLES ========== */

	// The 🎟️ being sold
	IGoldenTickets public immutable TICKETS;

	// The token used to purchase with
	IWETH9 public immutable WETH;

	// The treasury contract where funds are deposited and 🎟️ minted
	IGovernableTreasury public immutable TREASURY;

	// Whether the purchased 🎟️ should be made available immediately to beneficiaries
	bool public immutable CLAIMABLE;

	bytes32 public immutable AIRDROP_MERKLE_ROOT;
	uint256 public immutable AIRDROP_ETHER_THRESHOLD = 1221 ether;
	uint256 public immutable AIRDROP_EXCESS_RESERVES_THRESHOLD = 244.2 ether;

	// The 🎪 contract
	IMainShow public mainShow;

	uint256 public etherRaised;

	uint256 public ticketsSold;
	uint256 public ticketsClaimed;
	uint256 public ticketsAirdropped;

	uint256 public openingTime;
	uint256 public closingTime;

	mapping(address => uint256) public contributions;
	uint256 public maxContributionCap;

	uint256 public initialRate;
	uint256 public finalRate;

	mapping(address => uint256) public claims;
	mapping(address => bool) public airdropClaims;

	/* ========== MODIFIERS ========== */

	/**
	 * @dev Reverts when not in crowdsale opening hours
	 */
	modifier onlyWhileOpen() {
		require(isOpen(), "GoldenTicketsVendingBooth::onlyWhileOpen: crowdsale is closed");
		_;
	}

	/* ========== CONSTRUCTOR ========== */

	/**
	 * @dev The rate is the conversion between WETH and the smallest and indivisible token unit.
	 * So, if you are using a rate of 1 with a token w/ 3 decimals called TOK, 1 WETH will give you 1 unit, or 0.001 TOK
	 * @param treasury Address where collected funds will be deposited
	 * @param tickets Address of the token being sold
	 * @param _openingTime Crowdsale opening time (in seconds)
	 * @param _closingTime Crowdsale closing time (in seconds)
	 * @param _contributionCap Crowdsale contribution cap (in wei)
	 * @param _initialRate Number of 🎟️ a buyer gets per wei at the start of the crowdsale (in decimals)
	 * @param _finalRate Number of 🎟️ a buyer gets per wei at the end of the crowdsale (in decimals)
	 * @param _claimable Whether the 🎟️ purchased will need to be claimed
	 */
	constructor(
		IGoldenTickets tickets,
		IWETH9 weth,
		IGovernableTreasury treasury,
		IMainShow _mainShow,
		uint256 _openingTime,
		uint256 _closingTime,
		uint256 _contributionCap,
		uint256 _initialRate,
		uint256 _finalRate,
		bool _claimable,
		bytes32 _airdropMerkleRoot,
		ICircusAuthority _authority
	) CircusAccessControlled(_authority) {
		require(
			address(tickets) != address(0),
			unicode"GoldenTicketsVendingBooth::constructor: 🎟️ cannot be the zero address"
		);
		require(
			address(weth) != address(0),
			unicode"GoldenTicketsVendingBooth::constructor: wrapped ether cannot be the zero address"
		);
		require(
			address(treasury) != address(0),
			"GoldenTicketsVendingBooth::constructor: treasury cannot be the zero address"
		);

		require(
			_openingTime >= block.timestamp,
			"GoldenTicketsVendingBooth::constructor: opening time is before current time"
		);
		require(
			_closingTime > _openingTime,
			"GoldenTicketsVendingBooth::constructor: opening time is not before closing time"
		);

		require(_finalRate > 0, "GoldenTicketsVendingBooth::constructor: final rate is 0");
		require(
			_initialRate < _finalRate,
			"GoldenTicketsVendingBooth::constructor: final rate is not greater than initial rate"
		);

		TICKETS = tickets;
		WETH = weth;
		TREASURY = treasury;
		mainShow = _mainShow;

		openingTime = _openingTime;
		closingTime = _closingTime;
		maxContributionCap = _contributionCap;
		initialRate = _initialRate;
		finalRate = _finalRate;

		CLAIMABLE = _claimable;
		AIRDROP_MERKLE_ROOT = _airdropMerkleRoot;
	}

	/* ========== VIEW FUNCTIONS ========== */

	/**
	 * @return true if the crowdsale is open, false otherwise.
	 */
	function isOpen() public view returns (bool) {
		return block.timestamp >= openingTime && block.timestamp <= closingTime;
	}

	/**
	 * @dev Checks whether the period in which the crowdsale is open has already elapsed.
	 * @return Whether crowdsale period has elapsed
	 */
	function hasClosed() public view returns (bool) {
		return block.timestamp > closingTime;
	}

	/**
	 * @dev Returns the rate of wei per 🎟️ unit at the present block time.
	 * Note that:
	 * - returns 0 if crowdsale is not open yet
	 * - increases over time
	 * - has thousands precision
	 * @return The number of 🎟️ units a buyer gets per wei at a given time
	 */
	function getCurrentRate() public view returns (uint256) {
		if (!isOpen()) {
			return 0;
		}

		uint256 elapsedTime = block.timestamp - openingTime;
		uint256 timeRange = closingTime - openingTime;
		uint256 rateRange = (finalRate - initialRate) * 1000;
		return ((elapsedTime * rateRange) / timeRange) + (initialRate * 1000);
	}

	/**
	 * @return The minimum contribution cap
	 */
	function minContributionCap() public view returns (uint256) {
		return (getCurrentRate() * 0.01 ether) / 1000;
	}

	/**
	 * @return true if the crowdsale is open, false otherwise.
	 */
	function isAirdropOpen() public view returns (bool) {
		return hasClosed() && (block.timestamp <= closingTime + ((closingTime - openingTime) * 12));
	}

	/* ========== MUTATIVE FUNCTIONS ========== */

	/**
	 * @dev This function has a non-reentrancy guard, so it shouldn't be called by another `nonReentrant` function
	 * @param beneficiary recipient of the tickets
	 * @param wethAmount purchase amount in wei
	 * @param stake whether the purchased 🎟️ should be staked on behalf of the beneficiary
	 */
	function buyTickets(
		address beneficiary,
		uint256 wethAmount,
		bool stake
	) external payable nonReentrant {
		uint256 ethAmount = wethAmount;
		bool native = msg.value > 0;
		if (native) {
			ethAmount = msg.value;
		}

		_preValidatePurchase(beneficiary, ethAmount);

		(uint256 tickets, uint256 reserves) = _getTokenAmounts(ethAmount);

		_processPurchase(beneficiary, ethAmount, tickets, reserves, stake, native);
		emit TicketsPurchased(msg.sender, beneficiary, ethAmount, tickets, stake);

		_updatePurchasingState(beneficiary, ethAmount, tickets);
	}

	/**
	 * @notice Transfers all 🎟️ owed to either the caller or the 🎪, but only after the crowdsale is over
	 * @param stake whether the claimed 🎟️ should be staked on behalf of the beneficiary
	 */
	function claimTickets(bool stake) external nonReentrant {
		require(hasClosed(), "GoldenTicketsVendingBooth::claimTickets: crowdsale is not over");

		uint256 claimableTickets = claims[msg.sender];
		require(claimableTickets > 0, unicode"GoldenTicketsVendingBooth::claimTickets: caller has no claimable 🎟️");
		require(
			TICKETS.balanceOf(address(this)) >= claimableTickets,
			unicode"GoldenTicketsVendingBooth::claimTickets: booth doesn't have enough 🎟️"
		);

		claims[msg.sender] = 0;

		if (stake && address(mainShow) != address(0)) {
			TICKETS.safeIncreaseAllowance(address(mainShow), claimableTickets);
			mainShow.watch(msg.sender, claimableTickets, true, false);
		} else {
			TICKETS.safeTransfer(msg.sender, claimableTickets);
		}

		ticketsClaimed += claimableTickets;
		emit TicketsClaimed(msg.sender, claimableTickets, stake);
	}

	/**
	 * @dev This function has a non-reentrancy guard, so it shouldn't be called by another `nonReentrant` function
	 * @param beneficiary recipient of the airdrop
	 * @param amount gOHM balance at snapshot (randomly determines the amount of 🎟️ received)
	 * @param merkleProof Proof of inclusion in the tree, constructed off-chain
	 * @param stake whether the claimed 🎟️ should be staked on behalf of the beneficiary or transferred to the beneficiary
	 */
	function claimAirdrop(
		address beneficiary,
		uint256 amount,
		bytes32[] calldata merkleProof,
		bool stake
	) external nonReentrant {
		require(isAirdropOpen(), "GoldenTicketsVendingBooth::claimAirdrop: airdrop is closed");
		require(!airdropClaims[beneficiary], "GoldenTicketsVendingBooth::claimAirdrop: airdrop already claimed");
		require(
			etherRaised >= AIRDROP_ETHER_THRESHOLD,
			"GoldenTicketsVendingBooth::claimAirdrop: crowdsale did not raise enough funds"
		);
		require(
			TREASURY.excessReserves() > TREASURY.tokenValue(address(WETH), AIRDROP_EXCESS_RESERVES_THRESHOLD),
			"GoldenTicketsVendingBooth::claimAirdrop: treasury doesn't hold enough excess reserves"
		);

		bytes32 node = keccak256(abi.encodePacked(beneficiary, amount));
		require(
			MerkleProof.verify(merkleProof, AIRDROP_MERKLE_ROOT, node),
			"GoldenTicketsVendingBooth::claimAirdrop: invalid merkle proof"
		);

		airdropClaims[beneficiary] = true;

		uint256 tickets = ((amount % 3) + 1) * 1e7;
		if (stake && address(mainShow) != address(0)) {
			TREASURY.mint(address(this), tickets);
			TICKETS.safeIncreaseAllowance(address(mainShow), tickets);
			mainShow.watch(beneficiary, tickets, true, false);
		} else {
			TREASURY.mint(beneficiary, tickets);
		}

		ticketsAirdropped += tickets;
		emit TicketsAirdrop(msg.sender, beneficiary, tickets, stake);
	}

	/**
	 * @dev Sets the new 🎪 contract
	 * @param newMainShow New 🎪 contract
	 */
	function updateMainShow(IMainShow newMainShow) external onlyGovernor {
		require(
			address(mainShow) == address(0),
			unicode"GoldenTicketsVendingBooth::updateMainShow: 🎪 can only be set once"
		);
		emit MainShowUpdated(address(mainShow), address(newMainShow));
		mainShow = newMainShow;
	}

	/**
	 * @dev Allows to rescue any WETH dust and deposit it into the treasury as excess reserve
	 */
	function depositDust() external onlyGovernor {
		require(hasClosed(), "GoldenTicketsVendingBooth::cleanDust: crowdsale is not over");

		uint256 wethBalance = WETH.balanceOf(address(this));
		if (wethBalance > 0.001 ether) {
			TREASURY.deposit(wethBalance, address(WETH), TREASURY.tokenValue(address(WETH), wethBalance));
		}
	}

	/* ========== INTERNAL FUNCTIONS ========== */

	/**
	 * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met
	 * @param beneficiary Address receiving the 🎟️
	 * @param ethAmount Value in wei involved in the purchase
	 */
	function _preValidatePurchase(address beneficiary, uint256 ethAmount) internal view onlyWhileOpen {
		require(
			beneficiary != address(0),
			"GoldenTicketsVendingBooth::_preValidatePurchase: beneficiary cannot be the zero address"
		);
		require(
			ethAmount >= minContributionCap(),
			"GoldenTicketsVendingBooth::_preValidatePurchase: min contribution cap unmet"
		);
		require(
			contributions[beneficiary] + ethAmount <= maxContributionCap,
			"GoldenTicketsVendingBooth::_preValidatePurchase: max contribution cap exceeded"
		);
	}

	/**
	 * @dev Executed after a purchase has been validated and is ready to be fulfilled
	 * @param beneficiary Address receiving the 🎟️
	 * @param ethAmount Amount of wei spent
	 * @param ticketsAmount Amount of 🎟️ purchased
	 * @param reservesAmount Amount of excess 🎟️ reserves
	 * @param stakeTickets Whether purchased 🎟️ should be staked
	 * @param withNativeCurrency Whether native ether or wrapped either was used to purchase
	 */
	function _processPurchase(
		address beneficiary,
		uint256 ethAmount,
		uint256 ticketsAmount,
		uint256 reservesAmount,
		bool stakeTickets,
		bool withNativeCurrency
	) internal {
		if (withNativeCurrency) {
			WETH.deposit{ value: ethAmount }();
		} else {
			WETH.safeTransferFrom(msg.sender, address(this), ethAmount);
		}
		require(
			WETH.balanceOf(address(this)) >= ethAmount,
			"GoldenTicketsVendingBooth::_processPurchase: wrapped ether doesn't add up"
		);

		WETH.safeIncreaseAllowance(address(TREASURY), ethAmount);
		uint256 ticketsMinted = TREASURY.deposit(ethAmount, address(WETH), reservesAmount);
		require(
			ticketsMinted == ticketsAmount,
			unicode"GoldenTicketsVendingBooth::_processPurchase: minted 🎟️ don't add up"
		);

		if (CLAIMABLE) {
			claims[beneficiary] += ticketsMinted;
		} else {
			if (stakeTickets && address(mainShow) != address(0)) {
				TICKETS.safeIncreaseAllowance(address(mainShow), ticketsMinted);
				mainShow.watch(beneficiary, ticketsMinted, true, false);
			} else {
				TICKETS.safeTransfer(beneficiary, ticketsMinted);
			}
		}
	}

	/**
	 * @dev Override for extensions that require an internal state to check for validity (current user contributions,
	 * etc.)
	 * @param beneficiary Address receiving the 🎟️
	 * @param ethAmount Value in wei involved in the purchase
	 * @param ticketsAmount Amount of 🎟️ purchased
	 */
	function _updatePurchasingState(
		address beneficiary,
		uint256 ethAmount,
		uint256 ticketsAmount
	) internal {
		contributions[beneficiary] += ethAmount;
		ticketsSold += ticketsAmount;
		etherRaised += ethAmount;
	}

	/**
	 * @dev Override to extend the way in which ether is converted to 🎟️
	 * @param ethAmount Value in wei to be converted into 🎟️
	 * @return tickets Number of 🎟️ that can be purchased with the specified WETH amount
	 * @return reserves Number of additional WETH reserves in the treasury after the sale
	 */
	function _getTokenAmounts(uint256 ethAmount) internal view returns (uint256 tickets, uint256 reserves) {
		uint256 fairTicketsValue = TREASURY.tokenValue(address(WETH), ethAmount);
		tickets = (fairTicketsValue * 1000) / getCurrentRate();
		require(tickets > 0, unicode"GoldenTicketsVendingBooth::_getTokenAmounts: 🎟️ cannot be 0");
		reserves = fairTicketsValue - tickets;
	}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Trees proofs.
 *
 * The proofs can be generated using the JavaScript library
 * https://github.com/miguelmota/merkletreejs[merkletreejs].
 * Note: the hashing algorithm should be keccak256 and pair sorting should be enabled.
 *
 * See `test/utils/cryptography/MerkleProof.test.js` for some examples.
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merklee tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. When processing the proof, the pairs
     * of leafs & pre-images are assumed to be sorted.
     *
     * _Available since v4.4._
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        return computedHash;
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;
/* solhint-disable reason-string */

import { ICircusAuthority } from "../../interfaces/ICircusAuthority.sol";

abstract contract CircusAccessControlled {
	/* ========== EVENTS ========== */

	event AuthorityUpdated(ICircusAuthority indexed authority);

	/* ========== STATE VARIABLES ========== */

	ICircusAuthority public authority;

	/* ========== CONSTRUCTOR ========== */

	constructor(ICircusAuthority _authority) {
		authority = _authority;
		emit AuthorityUpdated(_authority);
	}

	/* ========== MODIFIERS ========== */

	modifier onlyGovernor() {
		require(msg.sender == authority.governor(), "CircusAccessControlled::onlyGovernor: caller is not the governor");
		_;
	}

	modifier onlyGuardian() {
		require(msg.sender == authority.guardian(), "CircusAccessControlled::onlyGuardian: caller is not the guardian");
		_;
	}

	modifier onlyGovernorOrGuardian() {
		require(
			msg.sender == authority.governor() || msg.sender == authority.guardian(),
			"CircusAccessControlled::onlyGovernorOrGuardian: caller is neither governor nor guardian"
		);
		_;
	}

	modifier onlyPolicy() {
		require(msg.sender == authority.policy(), "CircusAccessControlled::onlyPolicy: caller is not the governance");
		_;
	}

	modifier onlyVault() {
		require(msg.sender == authority.vault(), "CircusAccessControlled::onlyVault: caller is not the vault");
		_;
	}

	/* ========== MUTATIVE FUNCTIONS ========== */

	function setAuthority(ICircusAuthority _newAuthority) external onlyGovernor {
		authority = _newAuthority;
		emit AuthorityUpdated(_newAuthority);
	}
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IGoldenTicketsLiquefier } from "./IGoldenTicketsLiquefier.sol";

interface IGoldenTickets is IERC20Metadata {
	/* ========== VIEW FUNCTIONS ========== */

	function ticketsBurnt() external view returns (uint256);

	/* ========== MUTATIVE FUNCTIONS ========== */

	function mint(address account, uint256 amount) external;

	function burn(uint256 amount) external;

	function burnFrom(address account, uint256 amount) external;

	function changeMetadata(string memory name, string memory symbol) external;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

interface IGoldenTicketsVendingBooth {
	/* ========== EVENTS ========== */

	/**
	 * Event for 🎟️ purchase logging
	 * @param purchaser who paid for the 🎟️
	 * @param beneficiary who got the 🎟️
	 * @param value amount of tokens used for purchasing
	 * @param amount amount of 🎟️ purchased
	 * @param staked whether the purchaser chose to stake the 🎟️
	 */
	event TicketsPurchased(
		address indexed purchaser,
		address indexed beneficiary,
		uint256 value,
		uint256 amount,
		bool staked
	);

	/**
	 * Event for 🎟️ claim logging
	 * @param claimant who claimed the 🎟️
	 * @param amount amount of 🎟️ claimed
	 * @param staked whether the claimant chose to stake the 🎟️
	 */
	event TicketsClaimed(address indexed claimant, uint256 amount, bool staked);

	/**
	 * Event for 🎟️ airdrop claim logging
	 * @param claimant who claimed the 🎟️
	 * @param beneficiary who got the 🎟️
	 * @param amount amount of 🎟️ airdropped
	 * @param staked whether the claimant chose to stake the 🎟️
	 */
	event TicketsAirdrop(address indexed claimant, address indexed beneficiary, uint256 amount, bool staked);

	event MainShowUpdated(address prevMainShow, address newMainShow);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

interface IGovernableTreasury {
	/* ========== EVENTS ========== */

	event Deposit(address indexed token, uint256 amount, uint256 value);
	event Withdrawal(address indexed token, uint256 amount, uint256 value);
	event CreateDebt(address indexed debtor, address indexed token, uint256 amount, uint256 value);
	event RepayDebt(address indexed debtor, address indexed token, uint256 amount, uint256 value);
	event ReservesManaged(address indexed token, uint256 amount);
	event ReservesAudited(uint256 indexed totalReserves);
	event Minted(address indexed caller, address indexed recipient, uint256 amount);
	event PermissionQueued(PolicyAction indexed status, address queued);
	event Permissioned(address addr, PolicyAction indexed status, bool result);

	/* ========== DATA STRUCTURES ========== */

	enum PolicyAction {
		RESERVE_DEPOSITOR,
		RESERVE_SPENDER,
		RESERVE_TOKEN,
		RESERVE_MANAGER,
		LIQUIDITY_DEPOSITOR,
		LIQUIDITY_TOKEN,
		LIQUIDITY_MANAGER,
		RESERVE_DEBTOR,
		REWARD_MANAGER,
		BALLOONS,
		TICKETS_DEBTOR
	}

	struct Policy {
		PolicyAction managing;
		address toPermit;
		address calculator;
		uint256 timelockEnd;
		bool canceled;
		bool executed;
	}

	/* ========== VIEW FUNCTIONS ========== */

	function excessReserves() external view returns (uint256);

	function baseSupply() external view returns (uint256);

	function tokenValue(address token, uint256 amount) external view returns (uint256 value);

	function indexInRegistry(address target, PolicyAction action) external view returns (bool, uint256);

	/* ========== MUTATIVE FUNCTIONS ========== */

	function deposit(
		uint256 amount,
		address token,
		uint256 excessReservesAmount
	) external returns (uint256);

	function withdraw(uint256 amount, address token) external;

	function mint(address recipient, uint256 amount) external;

	function manage(address token, uint256 amount) external;

	function incurDebt(uint256 amount, address token) external;

	function repayDebtWithReserve(uint256 amount, address token) external;

	function repayDebtWithTickets(uint256 amount) external;

	function auditReserves() external;

	function enable(
		PolicyAction action,
		address target,
		address extra
	) external;

	function revoke(PolicyAction action, address target) external;

	function queuePolicyAction(
		PolicyAction action,
		address target,
		address extra
	) external;

	function execute(uint256 index) external;

	function cancel(uint256 index) external;

	function disableTimelock() external;

	function setDebtLimit(address target, uint256 limit) external;

	function setPolicyTimelock(uint256 timelock) external;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

interface IMainShow {
	/* ========== EVENTS ========== */

	event DistributorSet(address distributor);
	event QueueSet(uint256 queue);

	/* ========== DATA STRUCTURES ========== */

	struct MainShow {
		uint256 duration;
		uint256 number;
		uint256 endsAt;
		uint256 distribute;
	}

	struct TicketsClaim {
		uint256 deposit;
		uint256 gons;
		uint256 expiry;
		bool lock; // prevents malicious delays
	}

	/* ========== VIEW FUNCTIONS ========== */

	function index() external view returns (uint256);

	function queuedSupply() external view returns (uint256);

	function secondsToNextEpoch() external view returns (uint256);

	/* ========== MUTATIVE FUNCTIONS ========== */

	function watch(
		address attendee,
		uint256 amount,
		bool rebasing,
		bool claim
	) external returns (uint256);

	function clap(address attendee, bool rebasing) external returns (uint256);

	function forfeit() external returns (uint256);

	function toggleLock() external;

	function leave(
		address attendee,
		uint256 amount,
		bool trigger,
		bool rebasing
	) external returns (uint256);

	function wrap(address to, uint256 amount) external returns (uint256 candyBalance);

	function unwrap(address to, uint256 amount) external returns (uint256 balloonBalance);

	function rebase() external returns (uint256 bounty);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IWETH9 is IERC20Metadata {
	/* ========== MUTATIVE FUNCTIONS ========== */

	receive() external payable;

	function deposit() external payable;

	function withdraw(uint256 wad) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

interface ICircusAuthority {
	/* ========== EVENTS ========== */

	event GovernorPushed(address indexed from, address indexed to, bool immediately);
	event GuardianPushed(address indexed from, address indexed to, bool immediately);
	event PolicyPushed(address indexed from, address indexed to, bool immediately);
	event VaultPushed(address indexed from, address indexed to, bool immediately);

	event GovernorPulled(address indexed from, address indexed to);
	event GuardianPulled(address indexed from, address indexed to);
	event PolicyPulled(address indexed from, address indexed to);
	event VaultPulled(address indexed from, address indexed to);

	/* ========== VIEW FUNCTIONS ========== */

	function governor() external view returns (address);

	function guardian() external view returns (address);

	function policy() external view returns (address);

	function vault() external view returns (address);

	/* ========== MUTATIVE FUNCTIONS ========== */

	function pushGovernor(address newGovernor, bool effectiveImmediately) external;

	function pushGuardian(address newGuardian, bool effectiveImmediately) external;

	function pushPolicy(address newPolicy, bool effectiveImmediately) external;

	function pushVault(address newVault, bool effectiveImmediately) external;

	function pullGovernor() external;

	function pullGuardian() external;

	function pullPolicy() external;

	function pullVault() external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

interface IGoldenTicketsLiquefier {
	/* ========== EVENTS ========== */

	event TicketsLiquefied(uint256 _wei, uint256 tickets);

	/* ========== VIEW FUNCTIONS ========== */

	function router() external view returns (address);

	function pair() external view returns (address);

	/* ========== MUTATIVE FUNCTIONS ========== */

	function liquefy(uint256) external;
}