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

abstract contract Distributor is IClaimable {
    using SafeMath for uint256;

    address public immutable sonne;
    address public immutable claimable;

    struct Recipient {
        uint256 shares;
        uint256 lastShareIndex;
        uint256 credit;
    }
    mapping(address => Recipient) public recipients;

    uint256 public totalShares;
    uint256 public shareIndex;

    event UpdateShareIndex(uint256 shareIndex);
    event UpdateCredit(address indexed account, uint256 lastShareIndex, uint256 credit);
    event EditRecipient(address indexed account, uint256 shares, uint256 totalShares);

    constructor(address sonne_, address claimable_) {
        sonne = sonne_;
        claimable = claimable_;
    }

    function updateShareIndex() public virtual nonReentrant returns (uint256 _shareIndex) {
        if (totalShares == 0) return shareIndex;
        uint256 amount = IClaimable(claimable).claim();
        if (amount == 0) return shareIndex;
        _shareIndex = amount.mul(2**160).div(totalShares).add(shareIndex);
        shareIndex = _shareIndex;
        emit UpdateShareIndex(_shareIndex);
    }

    function updateCredit(address account) public returns (uint256 credit) {
        uint256 _shareIndex = updateShareIndex();
        if (_shareIndex == 0) return 0;
        Recipient storage recipient = recipients[account];
        credit = recipient.credit + _shareIndex.sub(recipient.lastShareIndex).mul(recipient.shares) / 2**160;
        recipient.lastShareIndex = _shareIndex;
        recipient.credit = credit;
        emit UpdateCredit(account, _shareIndex, credit);
    }

    function claimInternal(address account) internal virtual returns (uint256 amount) {
        amount = updateCredit(account);
        if (amount > 0) {
            recipients[account].credit = 0;
            ISonne(sonne).transfer(account, amount);
            emit Claim(account, amount);
        }
    }

    function claim() external virtual override returns (uint256 amount) {
        return claimInternal(msg.sender);
    }

    function editRecipientInternal(address account, uint256 shares) internal {
        updateCredit(account);
        Recipient storage recipient = recipients[account];
        uint256 prevShares = recipient.shares;
        uint256 _totalShares = shares > prevShares
            ? totalShares.add(shares - prevShares)
            : totalShares.sub(prevShares - shares);
        totalShares = _totalShares;
        recipient.shares = shares;
        emit EditRecipient(account, shares, _totalShares);
    }

    // Prevents a contract from calling itself, directly or indirectly.
    bool internal _notEntered = true;
    modifier nonReentrant() {
        require(_notEntered, 'Distributor: REENTERED');
        _notEntered = false;
        _;
        _notEntered = true;
    }
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./Distributor.sol";

contract OwnedDistributor is Distributor {
    address public admin;

    event SetAdmin(address newAdmin);

    constructor(
        address sonne_,
        address claimable_,
        address admin_
    ) Distributor(sonne_, claimable_) {
        admin = admin_;
    }

    function editRecipient(address account, uint256 shares) public virtual {
        require(msg.sender == admin, "OwnedDistributor: UNAUTHORIZED");
        editRecipientInternal(account, shares);
    }

    function setAdmin(address admin_) public virtual {
        require(msg.sender == admin, "OwnedDistributor: UNAUTHORIZED");
        admin = admin_;
        emit SetAdmin(admin_);
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