//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import './interfaces/IERC20.sol';
import './interfaces/IOwnedDistributor.sol';
import './interfaces/IVelodromeGauge.sol';
import './interfaces/IVelodromePairFactory.sol';
import './interfaces/IVelodromeRouter.sol';
import './interfaces/IVelodromeVoter.sol';
import './libraries/SafeMath.sol';
import './libraries/SafeToken.sol';

contract LiquidityGenerator {
    using SafeMath for uint256;
    using SafeToken for address;

    struct ConstuctorParams {
        address admin_;
        address sonne_;
        address usdc_;
        address velo_;
        address router0_;
        address voter_;
        address reservesManager_;
        address distributor_;
        address bonusDistributor_;
        uint256 periodBegin_;
        uint256 periodDuration_;
        uint256 bonusDuration_;
    }

    uint256 public constant lockDuration = 6 * 30 * 24 * 60 * 60; // 6 months

    address public immutable admin;
    address public immutable sonne;
    address public immutable usdc;
    address public immutable velo;
    address public immutable router0;
    address public immutable voter;
    address public immutable distributor;
    address public immutable bonusDistributor;
    uint256 public immutable periodBegin;
    uint256 public immutable periodEnd;
    uint256 public immutable bonusEnd;
    uint256 public unlockTimestamp;
    bool public finalized = false;
    bool public delivered = false;
    address public reservesManager;

    // Generated velodrome addresses
    address public immutable pair0;
    address public immutable gauge;

    event Finalized(uint256 amountSonne, uint256 amountUSDC);
    event Deposit(
        address indexed sender,
        uint256 amount,
        uint256 distributorTotalShares,
        uint256 bonusDistributorTotalShares,
        uint256 newShares,
        uint256 newBonusShares
    );
    event PostponeUnlockTimestamp(
        uint256 prevUnlockTimestamp,
        uint256 unlockTimestamp
    );
    event Delivered(uint256 amountPair0);
    event VeloRewardClaimed(uint256 amountVelo);

    constructor(ConstuctorParams memory params_) {
        require(
            params_.periodDuration_ > 0,
            'LiquidityGenerator: INVALID_PERIOD_DURATION'
        );
        require(
            params_.bonusDuration_ > 0 &&
                params_.bonusDuration_ <= params_.periodDuration_,
            'LiquidityGenerator: INVALID_BONUS_DURATION'
        );
        admin = params_.admin_;
        sonne = params_.sonne_;
        usdc = params_.usdc_;
        velo = params_.velo_;
        router0 = params_.router0_;
        voter = params_.voter_;
        reservesManager = params_.reservesManager_;
        distributor = params_.distributor_;
        bonusDistributor = params_.bonusDistributor_;
        periodBegin = params_.periodBegin_;
        periodEnd = params_.periodBegin_.add(params_.periodDuration_);
        bonusEnd = params_.periodBegin_.add(params_.bonusDuration_);

        address _pair0 = _createPair(
            params_.router0_,
            params_.sonne_,
            params_.usdc_
        );
        address _gauge = _createGauge(params_.voter_, _pair0);

        pair0 = _pair0;
        gauge = _gauge;
    }

    function distributorTotalShares()
        public
        view
        returns (uint256 totalShares)
    {
        return IOwnedDistributor(distributor).totalShares();
    }

    function bonusDistributorTotalShares()
        public
        view
        returns (uint256 totalShares)
    {
        return IOwnedDistributor(bonusDistributor).totalShares();
    }

    function distributorRecipients(address account)
        public
        view
        returns (
            uint256 shares,
            uint256 lastShareIndex,
            uint256 credit
        )
    {
        return IOwnedDistributor(distributor).recipients(account);
    }

    function bonusDistributorRecipients(address account)
        public
        view
        returns (
            uint256 shares,
            uint256 lastShareIndex,
            uint256 credit
        )
    {
        return IOwnedDistributor(bonusDistributor).recipients(account);
    }

    function setReserveManager(address reserveManager_) external {
        require(msg.sender == admin, 'LiquidityGenerator: FORBIDDEN');
        require(
            reserveManager_ != address(0),
            'LiquidityGenerator: INVALID_ADDRESS'
        );
        reservesManager = reserveManager_;
    }

    function postponeUnlockTimestamp(uint256 newUnlockTimestamp) public {
        require(msg.sender == admin, 'LiquidityGenerator: UNAUTHORIZED');
        require(
            newUnlockTimestamp > unlockTimestamp,
            'LiquidityGenerator: INVALID_UNLOCK_TIMESTAMP'
        );
        uint256 prevUnlockTimestamp = unlockTimestamp;
        unlockTimestamp = newUnlockTimestamp;
        emit PostponeUnlockTimestamp(prevUnlockTimestamp, unlockTimestamp);
    }

    function deliverLiquidityToReservesManager() public {
        require(msg.sender == admin, 'LiquidityGenerator: UNAUTHORIZED');
        require(!delivered, 'LiquidityGenerator: ALREADY_DELIVERED');
        require(finalized, 'LiquidityGenerator: NOT_FINALIZED');
        uint256 blockTimestamp = getBlockTimestamp();
        require(
            blockTimestamp >= unlockTimestamp,
            'LiquidityGenerator: STILL_LOCKED'
        );
        IVelodromeGauge(gauge).withdrawAll();
        uint256 _amountPair0 = pair0.myBalance();
        pair0.safeTransfer(reservesManager, _amountPair0);
        delivered = true;
        emit Delivered(_amountPair0);
    }

    function claimVeloRewards() public {
        require(msg.sender == admin, 'LiquidityGenerator: UNAUTHORIZED');
        require(finalized, 'LiquidityGenerator: NOT_FINALIZED');

        address[] memory tokens = new address[](1);
        tokens[0] = velo;
        IVelodromeGauge(gauge).getReward(address(this), tokens);

        uint256 _amountVelo = velo.myBalance();
        velo.safeTransfer(reservesManager, _amountVelo);
        emit VeloRewardClaimed(_amountVelo);
    }

    function finalize() public {
        require(!finalized, 'LiquidityGenerator: FINALIZED');
        uint256 blockTimestamp = getBlockTimestamp();
        require(blockTimestamp >= periodEnd, 'LiquidityGenerator: TOO_SOON');

        uint256 _amountSonne = sonne.myBalance();
        uint256 _amountUSDC = usdc.myBalance();

        sonne.safeApprove(router0, _amountSonne);
        usdc.safeApprove(router0, _amountUSDC);
        IVelodromeRouter(router0).addLiquidity(
            sonne,
            usdc,
            false,
            _amountSonne,
            _amountUSDC,
            _amountSonne,
            _amountUSDC,
            address(this),
            blockTimestamp
        );

        uint256 _amountPair0 = pair0.myBalance();
        pair0.safeApprove(gauge, _amountPair0);
        IVelodromeGauge(gauge).deposit(_amountPair0, 0);

        unlockTimestamp = blockTimestamp.add(lockDuration);
        finalized = true;
        emit Finalized(_amountSonne, _amountUSDC);
    }

    function deposit(uint256 amountUSDC) external payable {
        uint256 blockTimestamp = getBlockTimestamp();
        require(blockTimestamp >= periodBegin, 'LiquidityGenerator: TOO_SOON');
        require(blockTimestamp < periodEnd, 'LiquidityGenerator: TOO_LATE');
        require(amountUSDC >= 1e7, 'LiquidityGenerator: INVALID_VALUE'); // minimum 10 USDC

        // Pull usdc to this contract
        usdc.safeTransferFrom(msg.sender, address(this), amountUSDC);

        (uint256 _prevSharesBonus, , ) = IOwnedDistributor(bonusDistributor)
            .recipients(msg.sender);
        uint256 _newSharesBonus = _prevSharesBonus;
        if (blockTimestamp < bonusEnd) {
            _newSharesBonus = _prevSharesBonus.add(amountUSDC);
            IOwnedDistributor(bonusDistributor).editRecipient(
                msg.sender,
                _newSharesBonus
            );
        }
        (uint256 _prevShares, , ) = IOwnedDistributor(distributor).recipients(
            msg.sender
        );
        uint256 _newShares = _prevShares.add(amountUSDC);
        IOwnedDistributor(distributor).editRecipient(msg.sender, _newShares);
        emit Deposit(
            msg.sender,
            amountUSDC,
            distributorTotalShares(),
            bonusDistributorTotalShares(),
            _newShares,
            _newSharesBonus
        );
    }

    receive() external payable {
        revert('LiquidityGenerator: BAD_CALL');
    }

    function getBlockTimestamp() public view virtual returns (uint256) {
        return block.timestamp;
    }

    function _createPair(
        address router_,
        address sonne_,
        address usdc_
    ) internal returns (address) {
        address _veloPairFactory = IVelodromeRouter(router_).factory();
        address _pair = IVelodromePairFactory(_veloPairFactory).getPair(
            sonne_,
            usdc_,
            false
        );
        if (_pair != address(0)) return _pair;

        _pair = IVelodromePairFactory(_veloPairFactory).createPair(
            sonne,
            usdc,
            false
        );

        return _pair;
    }

    function _createGauge(address voter_, address pair0_)
        internal
        returns (address)
    {
        address _gauge = IVelodromeVoter(voter_).gauges(pair0_);
        if (_gauge != address(0)) return _gauge;

        _gauge = IVelodromeVoter(voter_).createGauge(pair0_);

        return _gauge;
    }
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IERC20 {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IOwnedDistributor {
    function totalShares() external view returns (uint256);

    function recipients(address)
        external
        view
        returns (
            uint256 shares,
            uint256 lastShareIndex,
            uint256 credit
        );

    function editRecipient(address account, uint256 shares) external;
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IVelodromeGauge {
    function deposit(uint256 amount, uint256 tokenId) external;

    function withdrawAll() external;

    function withdraw(uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);

    function getReward(address account, address[] calldata tokens) external;
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IVelodromePairFactory {
    function createPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external returns (address pair);

    function getPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (address pair);
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IVelodromeRouter {
    function factory() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IVelodromeVoter {
    function gauges(address _pool) external view returns (address);

    function claimable(address _gauge) external view returns (uint256);

    function createGauge(address _pool) external returns (address);

    function whitelist(address token) external;

    function distribute(address _gauge) external;

    function vote(
        uint256 tokenId,
        address[] calldata _poolVote,
        uint256[] calldata _weights
    ) external;

    function votes(uint256 _tokenId, address _pool) external view returns (uint256);
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// From https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/Math.sol
// Subject to the MIT license.

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
     * @dev Returns the addition of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting with custom message on overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, errorMessage);

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on underflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot underflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction underflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on underflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot underflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, errorMessage);

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers.
     * Reverts on division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers.
     * Reverts with custom message on division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface ERC20Interface {
    function balanceOf(address user) external view returns (uint256);
}

library SafeToken {
    function myBalance(address token) internal view returns (uint256) {
        return ERC20Interface(token).balanceOf(address(this));
    }

    function balanceOf(address token, address user) internal view returns (uint256) {
        return ERC20Interface(token).balanceOf(user);
    }

    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), '!safeApprove');
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), '!safeTransfer');
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), '!safeTransferFrom');
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, '!safeTransferETH');
    }
}