// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
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
        return a + b;
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
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
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
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
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
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';

import './interfaces/ISonne.sol';
import './interfaces/IClaimable.sol';
import './interfaces/IVester.sol';

contract Vester is IVester, IClaimable {
    using SafeMath for uint256;

    uint256 public constant override segments = 100;

    address public immutable sonne;
    address public recipient;

    uint256 public immutable override vestingAmount;
    uint256 public immutable override vestingBegin;
    uint256 public immutable override vestingEnd;

    uint256 public previousPoint;
    uint256 public immutable finalPoint;

    constructor(
        address sonne_,
        address recipient_,
        uint256 vestingAmount_,
        uint256 vestingBegin_,
        uint256 vestingEnd_
    ) {
        require(vestingEnd_ > vestingBegin_, 'Vester: END_TOO_EARLY');

        sonne = sonne_;
        recipient = recipient_;

        vestingAmount = vestingAmount_;
        vestingBegin = vestingBegin_;
        vestingEnd = vestingEnd_;

        finalPoint = vestingCurve(1e18);
    }

    function vestingCurve(uint256 x) public pure virtual returns (uint256 y) {
        uint256 speed = 1e18;
        for (uint256 i = 0; i < 100e16; i += 1e16) {
            if (x < i + 1e16) return y + (speed * (x - i)) / 1e16;
            y += speed;
            speed = (speed * 976) / 1000;
        }
    }

    function getUnlockedAmount() internal virtual returns (uint256 amount) {
        uint256 blockTimestamp = getBlockTimestamp();
        uint256 currentPoint = vestingCurve((blockTimestamp - vestingBegin).mul(1e18).div(vestingEnd - vestingBegin));
        amount = vestingAmount.mul(currentPoint.sub(previousPoint)).div(finalPoint);
        previousPoint = currentPoint;
    }

    function claim() public virtual override returns (uint256 amount) {
        require(msg.sender == recipient, 'Vester: UNAUTHORIZED');
        uint256 blockTimestamp = getBlockTimestamp();
        if (blockTimestamp < vestingBegin) return 0;
        if (blockTimestamp > vestingEnd) {
            amount = ISonne(sonne).balanceOf(address(this));
        } else {
            amount = getUnlockedAmount();
        }
        if (amount > 0) ISonne(sonne).transfer(recipient, amount);
    }

    function setRecipient(address recipient_) public virtual {
        require(msg.sender == recipient, 'Vester: UNAUTHORIZED');
        recipient = recipient_;
    }

    function getBlockTimestamp() public view virtual returns (uint256) {
        return block.timestamp;
    }
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';

import './Vester.sol';

contract VesterSale is Vester {
    using SafeMath for uint256;

    constructor(
        address sonne_,
        address recipient_,
        uint256 vestingAmount_,
        uint256 vestingBegin_,
        uint256 vestingEnd_
    ) Vester(sonne_, recipient_, vestingAmount_, vestingBegin_, vestingEnd_) {}

    function getUnlockedAmount()
        internal
        virtual
        override
        returns (uint256 amount)
    {
        uint256 blockTimestamp = getBlockTimestamp();
        uint256 currentPoint = vestingCurve(
            (blockTimestamp - vestingBegin).mul(1e18).div(
                vestingEnd - vestingBegin
            )
        );
        amount = vestingAmount
            .mul(currentPoint.sub(previousPoint))
            .div(finalPoint)
            .mul(5)
            .div(10);
        if (previousPoint == 0 && currentPoint > 0) {
            // distribute 50% on TGE
            amount = amount.add(vestingAmount.div(2));
        }
        previousPoint = currentPoint;
    }
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IClaimable {
    function claim() external returns (uint256 amount);

    event Claim(address indexed account, uint256 amount);
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

//IERC20
interface ISonne {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address dst, uint256 rawAmount) external returns (bool);
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IVester {
    function segments() external view returns (uint256);

    function vestingAmount() external view returns (uint256);

    function vestingBegin() external view returns (uint256);

    function vestingEnd() external view returns (uint256);
}