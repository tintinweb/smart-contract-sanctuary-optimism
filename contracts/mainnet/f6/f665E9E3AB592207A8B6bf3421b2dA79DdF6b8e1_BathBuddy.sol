// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../interfaces/IBathBuddy.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// Inheritance
// import "./interfaces/IStakingRewards.sol";
// import "./RewardsDistributionRecipient.sol";
// import "./Pausable.sol";
import "../rubiconPools/BathToken.sol";

/**
 * @title BathBuddy
 * @dev *** This contract is a modified version of StakingRewards.sol by Synthetix
 * @dev https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol
 *
 * @dev The ~only~ external entrypoint used in the system is the getReward(token) function called by the Bath Token. Extra care should be taken to make sure only the beneficiary can ever access the funds and send them to the withdrawer (and fee to self)
 * @dev This should be permissioned so only legitimate BathToken flows can access it
 * @dev This contract handles the vesting ERC20 tokens for a given Bath Token. Custody of multiple tokens
 * can be given to this contract, which will release the token to the beneficiary following a given vesting schedule depending on what tokens have been notified().
 *
 */

/// @dev NOTE: There is an implicit assumption that having bathToken shares means you are staked. This BathBuddy is paired with a SINGLE bathToken
/// @dev It only accepts calls from that BathToken, specifically when a user wants to claim funds, base function and exit, withdraw() and get all rewards
contract BathBuddy is ReentrancyGuard, IBathBuddy, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    // WILL BE BATH HOUSE IS OWNER
    /// BATH TOKEN ONLY ENTRYPOINTs
    address public owner;
    address public myBathTokenBuddy;
    bool public friendshipStarted;

    /// @dev set to block.timestamp + rewards duration to track an active rewards period after notifyRewardAmount()
    mapping(address => uint256) public periodFinish; // Token specific
    mapping(address => uint256) public rewardRates; // Token specific reward rates
    mapping(address => uint256) public rewardsDuration; // Can be kept global but can also be token specific
    mapping(address => uint256) public lastUpdateTime; //Token specific
    mapping(address => uint256) public rewardsPerTokensStored; // Token specific

    // Token then user always
    mapping(address => mapping(address => uint256))
        public userRewardsPerTokenPaid; // ATTEMPTED TOKEN AGNOSTIC
    mapping(address => mapping(address => uint256)) public tokenRewards; // ATTEMPTED TOKEN AGNOSTIC

    /* ========== CONSTRUCTOR ========== */

    // IDEA: This can be bathBuddy if all rewardsToken logic comes from bath token
    // So long as all share logic is just being read from BathToken correctly, then bathbuddy can still sit on top and dish out ERC20s?
    // Implicitly staked or not depending on your bathToken share balance!?
    // Reliance on bathToken share state when dispensing rewards

    // Proxy-safe constructor
    function spawnBuddy(address _owner, address newBud) external {
        require(!friendshipStarted, "I already have a buddy!");
        owner = _owner;
        myBathTokenBuddy = newBud;

        // Note, rewards duration must be set by admin

        // Constructor pattern
        friendshipStarted = true;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // Enforce only soul-bound Bath Token has calling rights
    modifier onlyBuddy() {
        require(
            msg.sender == myBathTokenBuddy &&
                msg.sender != address(0) &&
                friendshipStarted,
            "You are not my buddy!"
        );
        _;
    }

    /* ========== VIEWS ========== */
    // BATH TOKEN DOES ALL SHARE ACCOUNTING! CAREFUL!

    function lastTimeRewardApplicable(address token)
        public
        view
        returns (uint256)
    {
        return
            block.timestamp < periodFinish[token]
                ? block.timestamp
                : periodFinish[token];
    }

    function rewardPerToken(address token) public view returns (uint256) {
        require(friendshipStarted, "I have not started a bathToken friendship");

        if (IERC20(myBathTokenBuddy).totalSupply() == 0) {
            return rewardsPerTokensStored[token];
        }
        return
            rewardsPerTokensStored[token].add(
                lastTimeRewardApplicable(token)
                    .sub(lastUpdateTime[token])
                    .mul(rewardRates[token])
                    .mul(1e18)
                    .div(IERC20(myBathTokenBuddy).totalSupply())
            );
    }

    // Determines a user rewards
    // Note, uses share logic from bathToken
    function earned(address account, address token)
        public
        view
        override
        returns (uint256)
    {
        require(friendshipStarted, "I have not started a bathToken friendship");

        return
            IERC20(myBathTokenBuddy) // Care with this?
                .balanceOf(account)
                .mul(
                    rewardPerToken(token).sub(
                        userRewardsPerTokenPaid[token][account]
                    )
                )
                .div(1e18)
                .add(tokenRewards[token][account]);
    }

    function getRewardForDuration(address token)
        external
        view
        returns (uint256)
    {
        return rewardRates[token].mul(rewardsDuration[token]);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    // IDEA: add this core logic to bathTokens and extrapolate to potentially multiple bath tokens if possible
    // Msg.sender calls BathToken (becomes holderRecipient here) which calls any time to get all rewards accrued for provided token
    /// @param holderRecipient allows the BathToken to pass through correct reward amounts to callers of the function @ BATH TOKEN LEVEL
    function getReward(IERC20 rewardsToken, address holderRecipient)
        external
        override
        nonReentrant
        whenNotPaused
        updateReward(holderRecipient, address(rewardsToken))
        onlyBuddy
    {
        uint256 reward = tokenRewards[address(rewardsToken)][holderRecipient];
        if (reward > 0) {
            tokenRewards[address(rewardsToken)][holderRecipient] = 0;
            rewardsToken.safeTransfer(holderRecipient, reward);
            emit RewardPaid(holderRecipient, reward);
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // Seems useful to add more reward amounts
    // Can set the new reward amount over the defined rewards Duration
    function notifyRewardAmount(uint256 reward, IERC20 rewardsToken)
        external
        onlyOwner
        updateReward(address(0), address(rewardsToken))
    {
        if (block.timestamp >= periodFinish[address(rewardsToken)]) {
            rewardRates[address(rewardsToken)] = reward.div(
                rewardsDuration[address(rewardsToken)]
            );
        } else {
            uint256 remaining = periodFinish[address(rewardsToken)].sub(
                block.timestamp
            );
            uint256 leftover = remaining.mul(
                rewardRates[address(rewardsToken)]
            );
            rewardRates[address(rewardsToken)] = reward.add(leftover).div(
                rewardsDuration[address(rewardsToken)]
            );
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        // Note********** ERC20s must be here*************
        uint256 balance = rewardsToken.balanceOf(address(this));
        require(
            rewardRates[address(rewardsToken)] <=
                balance.div(rewardsDuration[address(rewardsToken)]),
            "Provided reward too high"
        );

        lastUpdateTime[address(rewardsToken)] = block.timestamp;
        periodFinish[address(rewardsToken)] = block.timestamp.add(
            rewardsDuration[address(rewardsToken)]
        );
        emit RewardAdded(reward);
    }

    // This must be set before notifying a new rewards program for a given token
    // Must be used before? notifyRewardAmount to set the new period
    function setRewardsDuration(uint256 _rewardsDuration, address token)
        external
        onlyOwner
    {
        require(
            block.timestamp > periodFinish[token],
            "Previous rewards period must be complete before changing the duration for the new period"
        );
        rewardsDuration[token] = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration[token]);
    }

    /* ========== MODIFIERS ========== */

    // Rewards set here
    modifier updateReward(address account, address token) {
        rewardsPerTokensStored[token] = rewardPerToken(token);
        lastUpdateTime[token] = lastTimeRewardApplicable(token);
        if (account != address(0)) {
            tokenRewards[token][account] = earned(account, token);
            userRewardsPerTokenPaid[token][account] = rewardsPerTokensStored[
                token
            ];
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBathBuddy {
    /// @notice Releases the withdrawer's relative share of all vested tokens directly to them with their withdrawal
    /// @dev function that only the single, permissioned bathtoken can call that rewards a user their accrued rewards
    ///            for a given token during the current rewards period ongoing on bathBuddy
    function getReward(IERC20 token, address recipient) external;

    // Determines a user rewards
    // Note, uses share logic from bathToken
    function earned(address account, address token)
        external
        view
        returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

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
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
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
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
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

pragma solidity >=0.6.0 <0.8.0;

import "./Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor () internal {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: BUSL-1.1

/// @author Rubicon DeFi Inc. - bghughes.eth
/// @notice This contract represents a single-asset liquidity pool for Rubicon Pools
/// @notice Any user can deposit assets into this pool and earn yield from successful strategist market making with their liquidity
/// @notice This contract looks to both BathPairs and the BathHouse as its admin

pragma solidity =0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
// import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/IBathHouse.sol";
import "../interfaces/IRubiconMarket.sol";
import "../interfaces/IBathBuddy.sol";

contract BathToken {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// *** Storage Variables ***

    /// @notice The initialization status of the Bath Token
    bool public initialized;

    /// @notice  ** ERC-20 **
    string public symbol;
    string public name;
    uint8 public decimals;

    /// @notice The RubiconMarket.sol instance that all pool liquidity is intially directed to as market-making offers
    address public RubiconMarketAddress;

    /// @notice The Bath House admin of the Bath Token
    address public bathHouse;

    /// @notice The withdrawal fee recipient, typically the Bath Token itself
    address public feeTo;

    /// @notice The underlying ERC-20 token which is the core asset of the Bath Token vault
    IERC20 public underlyingToken;

    /// @notice The basis point fee rate that is paid on withdrawing the underlyingToken and bonusTokens
    uint256 public feeBPS;

    /// @notice ** ERC-20 **
    uint256 public totalSupply;

    /// @notice The amount of underlying deposits that are outstanding attempting market-making on the order book for yield
    /// @dev quantity of underlyingToken that is in the orderbook that the pool still has a claim on
    /// @dev The underlyingToken is effectively mark-to-marketed when it enters the book and it could be returned at a loss due to poor strategist performance
    /// @dev outstandingAmount is NOT inclusive of any non-underlyingToken assets sitting on the Bath Tokens that have filled to here and are awaiting rebalancing to the underlyingToken by strategists
    uint256 public outstandingAmount;

    /// @dev Intentionally unused DEPRECATED STORAGE VARIABLE to maintain contiguous state on proxy-wrapped contracts. Consider it a beautiful scar of incremental progress 📈
    /// @dev Keeping deprecated variables maintains consistent network-agnostic contract abis when moving to new chains and versions
    uint256[] deprecatedStorageArray; // Kept in to avoid storage collision bathTokens that are proxy upgraded

    /// @dev Intentionally unused DEPRECATED STORAGE VARIABLE to maintain contiguous state on proxy-wrapped contracts. Consider it a beautiful scar of incremental progress 📈
    mapping(uint256 => uint256) deprecatedMapping; // Kept in to avoid storage collision on bathTokens that are upgraded
    // *******************************************

    /// @notice  ** ERC-20 **
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /// @notice EIP-2612
    bytes32 public DOMAIN_SEPARATOR;

    /// @notice EIP-2612
    /// @dev keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /// @notice EIP-2612
    mapping(address => uint256) public nonces;

    /// @notice Array of Bonus ERC-20 tokens that are given as liquidity incentives to pool withdrawers
    address[] public bonusTokens;

    /// @notice Address of the OZ Vesting Wallet which acts as means to vest bonusToken incentives to pool HODLers
    IBathBuddy public bathBuddy;

    /// @dev Reentrancy protection
    bool locked;

    /// *** Events ***

    /// @notice ** ERC-20 **
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /// @notice ** ERC-20 **
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Time of Bath Token instantiation
    event LogInit(uint256 timeOfInit);

    /// @notice Log details about a pool deposit
    event LogDeposit(
        uint256 depositedAmt,
        IERC20 asset,
        uint256 sharesReceived,
        address depositor,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice Log details about a pool withdraw
    event LogWithdraw(
        uint256 amountWithdrawn,
        IERC20 asset,
        uint256 sharesWithdrawn,
        address withdrawer,
        uint256 fee,
        address feeTo,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice Log details about a pool rebalance
    event LogRebalance(
        IERC20 pool_asset,
        address destination,
        IERC20 transferAsset,
        uint256 rebalAmt,
        uint256 stratReward,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice Log details about a pool order canceled in the Rubicon Market book
    event LogPoolCancel(
        uint256 orderId,
        IERC20 pool_asset,
        uint256 outstandingAmountToCancel,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice Log details about a pool order placed in the Rubicon Market book
    event LogPoolOffer(
        uint256 id,
        IERC20 pool_asset,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice Log the credit to outstanding amount for funds that have been filled market-making
    event LogRemoveFilledTradeAmount(
        IERC20 pool_asset,
        uint256 fillAmount,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice * EIP 4626 *
    event Deposit(
        address indexed caller,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /// @notice * EIP 4626 *
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /// @notice Log bonus token reward event
    event LogClaimBonusTokn(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares,
        IERC20 bonusToken
    );

    /// *** Constructor ***

    /// @notice Proxy-safe initialization of storage; the constructor
    function initialize(
        ERC20 token,
        address market,
        address _feeTo
    ) external nonReentrant {
        require(!initialized);
        string memory _symbol = string(
            abi.encodePacked(("bath"), token.symbol())
        );
        symbol = _symbol;
        underlyingToken = token;
        RubiconMarketAddress = market;
        bathHouse = msg.sender; //NOTE: assumed admin is creator on BathHouse

        name = string(abi.encodePacked(_symbol, (" v1")));
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
        decimals = token.decimals(); // v1 Change - 4626 Adherence

        // Complete constract instantiation via CEI pattern
        initialized = true;

        // Add infinite approval of Rubicon Market for this asset
        IERC20(address(token)).approve(RubiconMarketAddress, 2**256 - 1);
        emit LogInit(block.timestamp);

        feeTo = address(this); //This contract is the fee recipient, rewarding HODLers
        feeBPS = 3; //Fee set to 3 BPS initially
    }

    /// *** Modifiers ***

    modifier onlyPair() {
        require(
            IBathHouse(bathHouse).isApprovedPair(msg.sender) == true,
            "not an approved pair - bathToken"
        );
        _;
    }

    modifier onlyBathHouse() {
        require(
            msg.sender == bathHouse,
            "caller is not bathHouse - BathToken.sol"
        );
        _;
    }

    /// @dev nonReentrant
    modifier nonReentrant() {
        require(!locked);
        locked = true;
        _;
        locked = false;
    }

    /// *** External Functions - Only Bath House / Admin ***

    /// @notice Admin-only function to set a Bath Token's market address
    function setMarket(address newRubiconMarket) external onlyBathHouse {
        RubiconMarketAddress = newRubiconMarket;
    }

    /// @notice Admin-only function to set a Bath Token's Bath House admin
    function setBathHouse(address newBathHouse) external onlyBathHouse {
        bathHouse = newBathHouse;
    }

    /// @notice Admin-only function to approve Bath Token's RubiconMarketAddress with the maximum integer value (infinite approval)
    function approveMarket() external onlyBathHouse {
        underlyingToken.approve(RubiconMarketAddress, 2**256 - 1);
    }

    /// @notice Admin-only function to set a Bath Token's feeBPS
    function setFeeBPS(uint256 _feeBPS) external onlyBathHouse {
        require(_feeBPS <= 300, "Fee can never exceed 300 bps");
        feeBPS = _feeBPS;
    }

    /// @notice Admin-only function to set a Bath Token's fee recipient, typically the pool itself
    function setFeeTo(address _feeTo) external onlyBathHouse {
        feeTo = _feeTo;
    }

    /// @notice Admin-only function to set THE BathBuddy which holds all ERC20 rewards
    function setBathBuddy(address newBuddy) external onlyBathHouse {
        bathBuddy = IBathBuddy(newBuddy);
    }

    /// @notice Admin-only function to add a bonus token to bonusTokens for pool incentives
    function setBonusToken(address newBonusERC20) external onlyBathHouse {
        bonusTokens.push(newBonusERC20);
        require(bonusTokens.length < 5, "too many tokens in this party");
    }

    /// *** External Functions - Only Approved Bath Pair / Strategist Contract ***

    /// ** Rubicon Market Functions **

    /// @notice The function for a strategist to cancel an outstanding Market Offer
    function cancel(uint256 id, uint256 amt) external onlyPair {
        outstandingAmount = outstandingAmount.sub(amt);
        IRubiconMarket(RubiconMarketAddress).cancel(id);

        emit LogPoolCancel(
            id,
            IERC20(underlyingToken),
            amt,
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
    }

    /// @notice A function called by BathPair to maintain proper accounting of outstandingAmount
    function removeFilledTradeAmount(uint256 amt) external onlyPair {
        outstandingAmount = outstandingAmount.sub(amt);
        emit LogRemoveFilledTradeAmount(
            IERC20(underlyingToken),
            amt,
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
    }

    /// @notice The function that places a bid and/or ask in the orderbook for a given pair from this pool
    function placeOffer(
        uint256 pay_amt,
        ERC20 pay_gem,
        uint256 buy_amt,
        ERC20 buy_gem
    ) external onlyPair returns (uint256) {
        // Place an offer in RubiconMarket
        // If incomplete offer return 0
        if (
            pay_amt == 0 ||
            pay_gem == ERC20(0) ||
            buy_amt == 0 ||
            buy_gem == ERC20(0)
        ) {
            return 0;
        }

        uint256 id = IRubiconMarket(RubiconMarketAddress).offer(
            pay_amt,
            pay_gem,
            buy_amt,
            buy_gem,
            0,
            false
        );
        outstandingAmount = outstandingAmount.add(pay_amt);

        emit LogPoolOffer(
            id,
            IERC20(underlyingToken),
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
        return (id);
    }

    /// @notice This function returns filled orders to the correct liquidity pool and sends strategist rewards to the Bath Pair
    /// @dev Sends non-underlyingToken fill elsewhere in the Pools system, typically it's sister asset within a trading pair (e.g. ETH-USDC)
    /// @dev Strategists presently accrue rewards in the filled asset not underlyingToken
    function rebalance(
        address destination,
        address filledAssetToRebalance, /* sister or fill asset */
        uint256 stratProportion,
        uint256 rebalAmt
    ) external onlyPair {
        require(filledAssetToRebalance != asset(), "must not be underlying");
        uint256 stratReward = (stratProportion.mul(rebalAmt)).div(10000);
        IERC20(filledAssetToRebalance).safeTransfer(
            destination,
            rebalAmt.sub(stratReward)
        );
        IERC20(filledAssetToRebalance).safeTransfer(msg.sender, stratReward);

        emit LogRebalance(
            IERC20(underlyingToken),
            destination,
            IERC20(filledAssetToRebalance),
            rebalAmt,
            stratReward,
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
    }

    /// *** EIP 4626 Implementation ***
    // https://eips.ethereum.org/EIPS/eip-4626#specification

    /// @notice Withdraw your bathTokens for the underlyingToken
    function withdraw(uint256 _shares)
        external
        nonReentrant
        returns (uint256 amountWithdrawn)
    {
        return _withdraw(_shares, msg.sender);
    }

    /// @notice * EIP 4626 *
    function asset() public view returns (address assetTokenAddress) {
        assetTokenAddress = address(underlyingToken);
    }

    /// @notice * EIP 4626 *
    function totalAssets() public view returns (uint256 totalManagedAssets) {
        return underlyingBalance();
    }

    /// @notice * EIP 4626 *
    function convertToShares(uint256 assets)
        public
        view
        returns (uint256 shares)
    {
        // Note: Inflationary tokens may affect this logic
        (totalSupply == 0) ? shares = assets : shares = (
            assets.mul(totalSupply)
        ).div(totalAssets());
    }

    // Note: MUST NOT be inclusive of any fees that are charged against assets in the Vault.
    /// @notice * EIP 4626 *
    function convertToAssets(uint256 shares)
        public
        view
        returns (uint256 assets)
    {
        assets = (totalAssets().mul(shares)).div(totalSupply);
    }

    // Note: Unused function param to adhere to standard
    /// @notice * EIP 4626 *
    function maxDeposit(address receiver)
        public
        pure
        returns (uint256 maxAssets)
    {
        maxAssets = 2**256 - 1; // No limit on deposits in current implementation  = Max UINT
    }

    /// @notice * EIP 4626 *
    function previewDeposit(uint256 assets)
        public
        view
        returns (uint256 shares)
    {
        // The exact same logic is used, no deposit fee - only difference is deflationary token check (rare condition and probably redundant)
        shares = convertToShares(assets);
    }

    // Single asset override to reflect old functionality
    function deposit(uint256 assets)
        public
        nonReentrant
        returns (uint256 shares)
    {
        // Note: msg.sender is the same throughout the same contract context
        return _deposit(assets, msg.sender);
    }

    /// @notice * EIP 4626 *
    function deposit(uint256 assets, address receiver)
        public
        nonReentrant
        returns (uint256 shares)
    {
        return _deposit(assets, receiver);
    }

    // Note: Unused function param to adhere to standard
    /// @notice * EIP 4626 *
    function maxMint(address receiver) public pure returns (uint256 maxShares) {
        maxShares = 2**256 - 1; // No limit on shares that could be created via deposit in current implementation - Max UINT
    }

    // Given I want these shares, how much do I have to deposit
    /// @notice * EIP 4626 *
    function previewMint(uint256 shares) public view returns (uint256 assets) {
        (totalSupply == 0) ? assets = shares : assets = (
            shares.mul(totalAssets())
        ).div(totalSupply);
    }

    // Mints exactly shares Vault shares to receiver by depositing amount of underlying tokens.
    /// @notice * EIP 4626 *
    function mint(uint256 shares, address receiver)
        public
        nonReentrant
        returns (uint256 assets)
    {
        assets = previewMint(shares);
        uint256 _shares = _deposit(assets, receiver);
        require(_shares == shares, "did not mint expected share count");
    }

    // A user can withdraw whatever they hold
    /// @notice * EIP 4626 *
    function maxWithdraw(address owner)
        public
        view
        returns (uint256 maxAssets)
    {
        if (totalSupply == 0) {
            maxAssets = 0;
        } else {
            uint256 ownerShares = balanceOf[owner];
            maxAssets = convertToAssets(ownerShares);
        }
    }

    /// @notice * EIP 4626 *
    function previewWithdraw(uint256 assets)
        public
        view
        returns (uint256 shares)
    {
        if (totalSupply == 0) {
            shares = 0;
        } else {
            shares = convertToShares(
                assets.add(assets.mul(feeBPS).div((uint256(10000).sub(feeBPS))))
            );
        }
    }

    /// @notice * EIP 4626 *
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public nonReentrant returns (uint256 shares) {
        require(
            owner == msg.sender,
            "This implementation does not support non-sender owners from withdrawing user shares"
        );
        uint256 expectedShares = previewWithdraw(assets);
        uint256 assetsReceived = _withdraw(expectedShares, receiver);
        require(
            assetsReceived >= assets,
            "You cannot withdraw the amount of assets you expected"
        );
        shares = expectedShares;
    }

    // Constraint: msg.sender is owner of shares when withdrawing
    /// @notice * EIP 4626 *
    function maxRedeem(address owner) public view returns (uint256 maxShares) {
        return balanceOf[owner];
    }

    // Constraint: msg.sender is owner of shares when withdrawing
    /// @notice * EIP 4626 *
    function previewRedeem(uint256 shares)
        public
        view
        returns (uint256 assets)
    {
        uint256 r = (underlyingBalance().mul(shares)).div(totalSupply);
        uint256 _fee = r.mul(feeBPS).div(10000);
        assets = r.sub(_fee);
    }

    /// @notice * EIP 4626 *
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public nonReentrant returns (uint256 assets) {
        require(
            owner == msg.sender,
            "This implementation does not support non-sender owners from withdrawing user shares"
        );
        assets = _withdraw(shares, receiver);
    }

    /// *** Internal Functions ***

    /// @notice Deposit assets for the user and mint Bath Token shares to receiver
    function _deposit(uint256 assets, address receiver)
        internal
        returns (uint256 shares)
    {
        uint256 _pool = underlyingBalance();
        uint256 _before = underlyingToken.balanceOf(address(this));

        // **Assume caller is depositor**
        underlyingToken.safeTransferFrom(msg.sender, address(this), assets);
        uint256 _after = underlyingToken.balanceOf(address(this));
        assets = _after.sub(_before); // Additional check for deflationary tokens

        if (totalSupply == 0) {
            uint256 minLiquidityShare = 10**3;
            shares = assets.sub(minLiquidityShare);
            // Handle protecting from an initial supply spoof attack
            _mint(address(0), (minLiquidityShare));
        } else {
            shares = (assets.mul(totalSupply)).div(_pool);
        }

        // Send shares to designated target
        _mint(receiver, shares);

        require(shares != 0, "No shares minted");
        emit LogDeposit(
            assets,
            underlyingToken,
            shares,
            msg.sender,
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
        emit Deposit(msg.sender, msg.sender, assets, shares);
    }

    /// @dev assumes that msg.sender is the shareholder
    /// @notice Withdraw share for the user and send underlyingToken to receiver with any accrued yield and incentive tokens
    function _withdraw(uint256 _shares, address receiver)
        internal
        returns (uint256 amountWithdrawn)
    {
        uint256 r = (underlyingBalance().mul(_shares)).div(totalSupply);
        _burn(msg.sender, _shares);
        uint256 _fee = r.mul(feeBPS).div(10000);
        // If FeeTo == address(0) then the fee is effectively accrued by the pool
        if (feeTo != address(0)) {
            underlyingToken.safeTransfer(feeTo, _fee);
        }
        amountWithdrawn = r.sub(_fee);
        underlyingToken.safeTransfer(receiver, amountWithdrawn);

        emit LogWithdraw(
            amountWithdrawn,
            underlyingToken,
            _shares,
            msg.sender,
            _fee,
            feeTo,
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
        emit Withdraw(
            msg.sender,
            receiver,
            msg.sender,
            amountWithdrawn,
            _shares
        );
    }

    // // User can recieve the awards they have accrued on BathBuddy
    function getBonusTokenReward(address rewardToken) public {
        IBathBuddy(bathBuddy).getReward(IERC20(rewardToken), msg.sender);
    }

    // // User can recieve the awards they have accrued on BathBuddy
    function getAllBonusTokenReward() public {
        distributeBonusTokenRewards(msg.sender);
    }

    /// Must allow the custom receiver option of the 4626 withdraw call path
    /// @notice Function to distibute non-underlyingToken Bath Token incentives to pool withdrawers
    /// @dev Note that bonusTokens adhere to the same feeTo and feeBPS pattern
    /// @dev Note the edge case in which the bonus token is the underlyingToken, here we simply release() to the pool and skip
    function distributeBonusTokenRewards(address receiver) internal {
        // Note, receiver must be owner <- enforced in the two withdraw entry paths
        // require(msg.sender == receiver, "You cannot claim someone else`s bonus tokens");
        // Verbose check:
        // require(initialTotalSupply == sharesWithdrawn + totalSupply);
        if (bonusTokens.length > 0) {
            for (uint256 index = 0; index < bonusTokens.length; index++) {
                IERC20 token = IERC20(bonusTokens[index]);
                require(address(token) != address(0), "bad bonus token");
                // Hit BathBuddy permissioned, nonReentrant function to handle paying out
                IBathBuddy(bathBuddy).getReward(token, receiver);

                emit LogClaimBonusTokn(
                    msg.sender,
                    receiver,
                    msg.sender,
                    IBathBuddy(bathBuddy).earned(msg.sender, address(token)),
                    balanceOf[msg.sender],
                    token
                );
            }
        }
    }

    /// *** ERC - 20 Standard ***

    function _mint(address to, uint256 value) internal {
        // Used for bonus token accounting
        distributeBonusTokenRewards(to);
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        // Used for bonus token accounting
        distributeBonusTokenRewards(from);
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) private {
        // Bonus tokens
        distributeBonusTokenRewards(from);
        balanceOf[from] = balanceOf[from].sub(value);
        // Bonus tokens
        distributeBonusTokenRewards(to);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        if (allowance[from][msg.sender] != uint256(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(
                value
            );
        }
        _transfer(from, to, value);
        return true;
    }

    /// @notice EIP 2612
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp, "bathToken: EXPIRED");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        nonces[owner]++,
                        deadline
                    )
                )
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(
            recoveredAddress != address(0) && recoveredAddress == owner,
            "bathToken: INVALID_SIGNATURE"
        );
        _approve(owner, spender, value);
    }

    /// *** View Functions ***

    /// @notice The underlying ERC-20 that this bathToken handles
    function underlyingERC20() external view returns (address) {
        return address(underlyingToken);
    }

    /// @notice The best-guess total claim on assets the Bath Token has
    /// @dev returns the amount of underlying ERC20 tokens in this pool in addition to any tokens that are outstanding in the Rubicon order book seeking market-making yield (outstandingAmount)
    function underlyingBalance() public view returns (uint256) {
        uint256 _pool = IERC20(underlyingToken).balanceOf(address(this));
        return _pool.add(outstandingAmount);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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

pragma solidity >=0.6.2 <0.8.0;

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
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/Context.sol";
import "./IERC20.sol";
import "../../math/SafeMath.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.7.6;

interface IBathHouse {
    function getMarket() external view returns (address);

    function initialized() external returns (bool);

    function reserveRatio() external view returns (uint256);

    function tokenToBathToken(address erc20Address)
        external
        view
        returns (address bathTokenAddress);

    function isApprovedStrategist(address wouldBeStrategist)
        external
        view
        returns (bool);

    function getBPSToStrats() external view returns (uint8);

    function isApprovedPair(address pair) external view returns (bool);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRubiconMarket {
    function cancel(uint256 id) external;

    function offer(
        uint256 pay_amt, //maker (ask) sell how much
        IERC20 pay_gem, //maker (ask) sell which token
        uint256 buy_amt, //maker (ask) buy how much
        IERC20 buy_gem, //maker (ask) buy which token
        uint256 pos, //position to insert offer, 0 should be used if unknown
        bool matching //match "close enough" orders?
    ) external returns (uint256);

    // Get best offer
    function getBestOffer(IERC20 sell_gem, IERC20 buy_gem)
        external
        view
        returns (uint256);

    // get offer
    function getOffer(uint256 id)
        external
        view
        returns (
            uint256,
            IERC20,
            uint256,
            IERC20
        );
}