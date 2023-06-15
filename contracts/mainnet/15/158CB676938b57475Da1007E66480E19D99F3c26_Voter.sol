// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

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
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

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
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBribe {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function getReward(address account) external;
    function notifyRewardAmount(address token, uint amount) external;
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    function _deposit(uint amount, address account) external;
    function _withdraw(uint amount, address account) external;
    function addReward(address rewardToken) external;
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function rewardPerToken(address reward) external view returns (uint);
    function earned(address account, address reward) external view returns (uint);
    function getRewardTokens() external view returns (address[] memory);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBribeFactory {
    /*----------  FUNCTIONS  --------------------------------------------*/
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    function createBribe(address voter) external returns (address);
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IGauge {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function getReward(address account) external;
    function notifyRewardAmount(address token, uint amount) external;
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    function _deposit(address account, uint256 amount) external;
    function _withdraw(address account, uint256 amount) external;
    function addReward(address rewardToken) external;
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function rewardPerToken(address reward) external view returns (uint);
    function earned(address account, address reward) external view returns (uint);
    function left(address token) external view returns (uint);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IGaugeFactory {
    /*----------  FUNCTIONS  --------------------------------------------*/
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    function createGauge(address voter, address token) external returns (address);
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IMinter {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function update_period() external returns (uint256);
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IPlugin {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function claimAndDistribute() external;
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    function setGauge(address gauge) external;
    function setBribe(address bribe) external;
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function getUnderlyingName() external view returns (string memory);
    function getUnderlyingSymbol() external view returns (string memory);
    function getUnderlyingAddress() external view returns (address);
    function getProtocol() external view returns (string memory);
    function getTokensInUnderlying() external view returns (address[] memory);
    function getBribeTokens() external view returns (address[] memory);
    function getPrice() external view returns (uint256);
    function getUnderlyingDecimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IVTOKEN {
    /*----------  FUNCTIONS  --------------------------------------------*/
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function balanceOf(address account) external view returns (uint256);
    function balanceOfTOKEN(address account) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/interfaces/IVTOKEN.sol";
import "contracts/interfaces/IPlugin.sol";
import "contracts/interfaces/IGauge.sol";
import "contracts/interfaces/IBribe.sol";
import "contracts/interfaces/IMinter.sol";
import "contracts/interfaces/IGaugeFactory.sol";
import "contracts/interfaces/IBribeFactory.sol";

/**
 * @title Voter
 * @author heesho
 * 
 * Voter contract is used to vote on plugins. It is also used to create gauges for plugins and distribute rewards to gauges.
 * 
 */
contract Voter is ReentrancyGuard, Ownable {

    /*----------  CONSTANTS  --------------------------------------------*/

    uint internal constant DURATION = 7 days; // duration of each voting epoch

    /*----------  STATE VARIABLES  --------------------------------------*/

    address public immutable VTOKEN;        // the voting token that governs these contracts
    address internal immutable OTOKEN;      // the token that is distributed to gauges for rewards
    address public immutable gaugefactory;  // the gauge factory that creates gauges  
    address public immutable bribefactory;  // the bribe factory that creates bribes
    address public minter;                  // the minter that mints OTOKENs to Voter contract for distribution
    address public treasury;                // the treasury that receives a portion of voting rewards from plugin revenue
    address public team;                    // the team that can step in to remove/add gauges in case of emergency. Can also add bribe rewards.


    uint public totalWeight;                                        // total voting weight
    address[] public plugins;                                       // all plugins viable for incentives
    mapping(address => address) public gauges;                      // plugin => gauge
    mapping(address => address) public pluginForGauge;              // gauge => plugin
    mapping(address => address) public bribes;                      // plugin => bribe
    mapping(address => uint256) public weights;                     // plugin => weight
    mapping(address => mapping(address => uint256)) public votes;   // account => plugin => votes
    mapping(address => address[]) public pluginVote;                // account => plugins
    mapping(address => uint) public usedWeights;                    // account => total voting weight of user
    mapping(address => uint) public lastVoted;                      // account => timestamp of last vote, to ensure one vote per epoch
    mapping(address => bool) public isGauge;                        // gauge => true if is gauge
    mapping(address => bool) public isAlive;                        // gauge => true if is alive

    uint internal index;                            // index of current voting epoch
    mapping(address => uint) internal supplyIndex;  // plugin => index of supply at last reward distribution
    mapping(address => uint) public claimable;      // plugin => claimable rewards

    /*----------  ERRORS ------------------------------------------------*/

    error Voter__AlreadyVotedThisEpoch();
    error Voter__NotAuthorizedGovernance();
    error Voter__PluginLengthNotEqualToWeightLength();
    error Voter__NotAuthorizedMinter();
    error Voter__InvalidZeroAddress();
    error Voter__NotMinter();
    error Voter__GaugeExists();
    error Voter__GaugeIsDead();
    error Voter__GaugeIsAlive();
    error Voter__NotGauge();

    /*----------  EVENTS ------------------------------------------------*/

    event Voter__GaugeCreated(address creator, address indexed plugin, address indexed gauge,  address bribe);
    event Voter__GaugeKilled(address indexed gauge);
    event Voter__GaugeRevived(address indexed gauge);
    event Voter__Voted(address indexed voter, uint256 weight);
    event Voter__Abstained(address account, uint256 weight);
    event Voter__Deposit(address indexed plugin, address indexed gauge, address account, uint amount);
    event Voter__Withdraw(address indexed plugin, address indexed gauge, address account, uint amount);
    event Voter__NotifyReward(address indexed sender, address indexed reward, uint amount);
    event Voter__DistributeReward(address indexed sender, address indexed gauge, uint amount);
    event Voter__BribeRewardAdded(address indexed bribe, address indexed reward);
    event Voter__TreasurySet(address indexed account);
    event Voter__TeamSet(address indexed account);

    /*----------  MODIFIERS  --------------------------------------------*/

    modifier onlyNewEpoch(address account) {
        if ((block.timestamp / DURATION) * DURATION < lastVoted[account]) revert Voter__AlreadyVotedThisEpoch();
        _;
    }

    modifier onlyGov {
        if (msg.sender != owner() && msg.sender != team) revert Voter__NotAuthorizedGovernance();
        _;
    }

    modifier nonZeroAddress(address _account) {
        if (_account == address(0)) revert Voter__InvalidZeroAddress();
        _;
    }

    /*----------  FUNCTIONS  --------------------------------------------*/

    /**
     * @notice construct a voter contract 
     * @param _VTOKEN VTOKEN address which is used to get voting power
     * @param _OTOKEN OTOKEN address which is distributed to gauges for rewards
     * @param _gaugefactory GaugeFactory address which is used to create gauges
     * @param _bribefactory BribeFactory address which is used to create bribes
     */
    constructor(address _VTOKEN, address _OTOKEN, address _gaugefactory, address _bribefactory) {
        VTOKEN = _VTOKEN;
        OTOKEN = _OTOKEN;
        gaugefactory = _gaugefactory;
        bribefactory = _bribefactory;
        minter = msg.sender;
        treasury = msg.sender;
        team = msg.sender;
    }

    /**
     * @notice Resets msg.sender's votes to zero on all plugins. Can only be called once per epoch.
     *         This is necessary for the user to withdraw staked VTOKENs by setting users voting weight to 0.
     */
    function reset() 
        external 
        onlyNewEpoch(msg.sender) 
    {
        address account = msg.sender;
        lastVoted[account] = block.timestamp;
        _reset(account);
    }

    /**
     * @notice Allocates voting power for msg.sender to input plugins based on input weights. Will update bribe balances
     *         to track voting rewards. Makes users voting weight nonzero. Can only be called once per epoch. 
     * @param _plugins list of plugins to vote on
     * @param _weights list of weights corresponding to plugins
     */
    function vote(address[] calldata _plugins, uint256[] calldata _weights) 
        external 
        onlyNewEpoch(msg.sender) 
    {
        if (_plugins.length != _weights.length) revert Voter__PluginLengthNotEqualToWeightLength();
        lastVoted[msg.sender] = block.timestamp;
        _vote(msg.sender, _plugins, _weights);
    }

    /**
     * @notice Claims rewards for msg.sender from list of gauges.
     * @param _gauges list of gauges to claim rewards from
     */
    function claimRewards(address[] memory _gauges) external {
        for (uint i = 0; i < _gauges.length; i++) {
            IGauge(_gauges[i]).getReward(msg.sender);
        }
    }

    /**
     * @notice Claims rewards for msg.sender from list of bribes.
     * @param _bribes list of bribes to claim rewards from
     */
    function claimBribes(address[] memory _bribes) external {
        for (uint i = 0; i < _bribes.length; i++) {
            IBribe(_bribes[i]).getReward(msg.sender);
        }
    }

    /**
     * @notice Claims voting rewards for each plugin and distributes it to corresponding bribe contracts
     * @param _plugins list of plugins to claim rewards and distribute from
     */
    function distributeToBribes(address[] memory _plugins) external {
        for (uint i = 0; i < _plugins.length; i++) {
            IPlugin(_plugins[i]).claimAndDistribute();
        }
    }

    /**
     * @notice Distributes OTOKEN to _gauge, notifies gauge contract to start distributing OTOKEN to plugin depositors.
     * @param _gauge gauge to distribute OTOKEN to
     */
    function distribute(address _gauge) public nonReentrant {
        IMinter(minter).update_period();
        _updateFor(_gauge); // should set claimable to 0 if killed
        uint _claimable = claimable[_gauge];
        if (_claimable > IGauge(_gauge).left(OTOKEN) && _claimable / DURATION > 0) {
            claimable[_gauge] = 0;
            IGauge(_gauge).notifyRewardAmount(OTOKEN, _claimable);
            emit Voter__DistributeReward(msg.sender, _gauge, _claimable);
        }
    }

    /**
     * @notice Distributes OTOKEN to gauges from start to finish
     * @param start starting index of gauges to distribute to
     * @param finish ending index of gauges to distribute to
     */
    function distribute(uint start, uint finish) public {
        for (uint x = start; x < finish; x++) {
            distribute(gauges[plugins[x]]);
        }
    }

    /**
     * @notice Distributes OTOKEN to all gauges
     */
    function distro() external {
        distribute(0, plugins.length);
    }

    /**
     * @notice For the minter to notify the voter contract of the amount of OTOKEN to distribute
     * @param amount amount of OTOKEN to distribute
     */
    function notifyRewardAmount(uint amount) external {
        _safeTransferFrom(OTOKEN, msg.sender, address(this), amount); // transfer the distro in
        uint256 _ratio = amount * 1e18 / totalWeight; // 1e18 adjustment is removed during claim
        if (_ratio > 0) {
            index += _ratio;
        }
        emit Voter__NotifyReward(msg.sender, OTOKEN, amount);
    }

    function updateFor(address[] memory _gauges) external {
        for (uint i = 0; i < _gauges.length; i++) {
            _updateFor(_gauges[i]);
        }
    }

    function updateForRange(uint start, uint end) public {
        for (uint i = start; i < end; i++) {
            _updateFor(gauges[plugins[i]]);
        }
    }

    function updateAll() external {
        updateForRange(0, plugins.length);
    }

    function updateGauge(address _gauge) external {
        _updateFor(_gauge);
    }

    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/

    function initialize(address _minter) 
        external 
    {
        if (msg.sender != minter) revert Voter__NotMinter();
        minter = _minter;
    }

    function addPlugin(address _plugin) 
        external 
        onlyGov 
        returns (address) 
    {
        if (gauges[_plugin] != address(0)) revert Voter__GaugeExists();

        address _gauge = IGaugeFactory(gaugefactory).createGauge(address(this), _plugin);
        IGauge(_gauge).addReward(OTOKEN);
        IPlugin(_plugin).setGauge(_gauge);
        IERC20(OTOKEN).approve(_gauge, type(uint).max);

        address _bribe = IBribeFactory(bribefactory).createBribe(address(this));
        address[] memory _bribeTokens = IPlugin(_plugin).getBribeTokens();
        for (uint256 i = 0; i < _bribeTokens.length; i++) {
            IBribe(_bribe).addReward(_bribeTokens[i]);
        }
        IPlugin(_plugin).setBribe(_bribe);

        gauges[_plugin] = _gauge;
        bribes[_plugin] = _bribe;
        pluginForGauge[_gauge] = _plugin;
        isGauge[_gauge] = true;
        isAlive[_gauge] = true;
        _updateFor(_gauge);
        plugins.push(_plugin);
        emit Voter__GaugeCreated(msg.sender, _plugin, _gauge, _bribe); 
        return _gauge;
    }

    function killGauge(address _gauge) 
        external 
        onlyGov 
    {
        if (!isAlive[_gauge]) revert Voter__GaugeIsDead();
        isAlive[_gauge] = false;
        claimable[_gauge] = 0;
        emit Voter__GaugeKilled(_gauge);
    }

    function reviveGauge(address _gauge) 
        external 
        onlyGov 
    {
        if (isAlive[_gauge]) revert Voter__GaugeIsAlive();
        isAlive[_gauge] = true;
        emit Voter__GaugeRevived(_gauge);
    }

    function setTreasury(address _treasury) 
        external 
        onlyOwner 
        nonZeroAddress(_treasury)
    {
        treasury = _treasury;
        emit Voter__TreasurySet(_treasury);
    }

    function setTeam(address _team) 
        external 
        onlyOwner 
        nonZeroAddress(_team)
    {
        team = _team;
        emit Voter__TeamSet(_team);
    }

    function addBribeReward(address _bribe, address _rewardToken) 
        external 
        onlyGov 
        nonZeroAddress(_rewardToken)
    {
        IBribe(_bribe).addReward(_rewardToken);
        emit Voter__BribeRewardAdded(_bribe, _rewardToken);
    }

    function emitDeposit(address account, uint amount) 
        external 
    {
        if (!isGauge[msg.sender]) revert Voter__NotGauge();
        if (!isAlive[msg.sender]) revert Voter__GaugeIsDead();
        emit Voter__Deposit(pluginForGauge[msg.sender], msg.sender, account, amount);
    }

    function emitWithdraw(address account, uint amount) external {
        if (!isGauge[msg.sender]) revert Voter__NotGauge();
        emit Voter__Withdraw(pluginForGauge[msg.sender], msg.sender, account, amount);
    }

    function _reset(address account) internal {
        address[] storage _pluginVote = pluginVote[account];
        uint _pluginVoteCnt = _pluginVote.length;
        uint256 _totalWeight = 0;

        for (uint i = 0; i < _pluginVoteCnt; i ++) {
            address _plugin = _pluginVote[i];
            uint256 _votes = votes[account][_plugin];

            if (_votes > 0) {
                _updateFor(gauges[_plugin]);
                weights[_plugin] -= _votes;
                votes[account][_plugin] -= _votes;
                IBribe(bribes[_plugin])._withdraw(IBribe(bribes[_plugin]).balanceOf(account), account);
                _totalWeight += _votes;
                emit Voter__Abstained(account, _votes);
            }
        }
        totalWeight -= uint256(_totalWeight);
        usedWeights[account] = 0;
        delete pluginVote[account];
    }

    function _vote(address account, address[] memory _pluginVote, uint256[] memory _weights) internal {
        _reset(account);
        uint _pluginCnt = _pluginVote.length;
        uint256 _weight = IVTOKEN(VTOKEN).balanceOf(account);
        uint256 _totalVoteWeight = 0;
        uint256 _totalWeight = 0;
        uint256 _usedWeight = 0;

        for (uint i = 0; i < _pluginCnt; i++) {
            address _plugin = _pluginVote[i];
            address _gauge = gauges[_plugin];
            if (isGauge[_gauge] && isAlive[_gauge]) { 
                _totalVoteWeight += _weights[i];
            }
        }

        for (uint i = 0; i < _pluginCnt; i++) {
            address _plugin = _pluginVote[i];
            address _gauge = gauges[_plugin];

            if (isGauge[_gauge] && isAlive[_gauge]) { 
                uint256 _pluginWeight = _weights[i] * _weight / _totalVoteWeight;
                require(votes[account][_plugin] == 0);
                require(_pluginWeight != 0);
                _updateFor(_gauge);

                pluginVote[account].push(_plugin);

                weights[_plugin] += _pluginWeight;
                votes[account][_plugin] += _pluginWeight;
                IBribe(bribes[_plugin])._deposit(uint256(_pluginWeight), account); 
                _usedWeight += _pluginWeight;
                _totalWeight += _pluginWeight;
                emit Voter__Voted(account, _pluginWeight);
            }
        }

        totalWeight += uint256(_totalWeight);
        usedWeights[account] = uint256(_usedWeight);
    }

    function _updateFor(address _gauge) internal {
        address _plugin = pluginForGauge[_gauge];
        uint256 _supplied = weights[_plugin];
        if (_supplied > 0) {
            uint _supplyIndex = supplyIndex[_gauge];
            uint _index = index; // get global index0 for accumulated distro
            supplyIndex[_gauge] = _index; // update _gauge current position to global position
            uint _delta = _index - _supplyIndex; // see if there is any difference that need to be accrued
            if (_delta > 0) {
                uint _share = uint(_supplied) * _delta / 1e18; // add accrued difference for each supplied token
                if (isAlive[_gauge]) {
                    claimable[_gauge] += _share;
                }
            }
        } else {
            supplyIndex[_gauge] = index; // new users are set to the default global state
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/

    function getPlugins() external view returns (address[] memory) {
        return plugins;
    }

    function length() external view returns (uint) {
        return plugins.length;
    }

}