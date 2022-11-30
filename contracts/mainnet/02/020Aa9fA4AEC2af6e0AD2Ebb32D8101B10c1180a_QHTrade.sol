// SPDX-License-Identifier: ISC

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./../utils/Math.sol";
import "../interfaces/ITrade.sol";

contract QHTrade is ITrade {

    event SwapSuccess(address tokenA, address tokenB, uint256 amountIn, uint256 amountOut);
    event TriggerChanged(address sender, address newTrigger);

    mapping(address => bool) managers;

    address public trigger;
    address public usdt;

    constructor(address _trigger, address _usdt, address _manager) {
        trigger = _trigger;
        usdt = _usdt;

        managers[msg.sender] = true;
        managers[_manager] = true;


    }

    function tvl() public view returns(uint256){
//        return IERC20(_usdt).balanceOf(address(this)) + Math.mulDiv(address(this).balance, etherPrice, 1e18);
//        return Math.mulDiv(ethBalance, etherPrice, 1e18) + usdtBalance;
        return IERC20(usdt).balanceOf(address(this));
    }

    function usdtAmount() public view returns(uint256) {
        return IERC20(usdt).balanceOf(address(this));
    }

    //FIXME Auth
    function transferToFeeder(uint256 amount, address feeder) external {
        IERC20(usdt).transfer(feeder, amount);
    }

    // Deposit native token to this contract
    function deposit() public payable {}

    function withdraw() public {
        require(msg.sender == trigger, "Only trigger server can withdraw native");
        uint amount = address(this).balance;
        (bool success, ) = trigger.call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return 'Transaction reverted silently';

        assembly {
        // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    function ecrecovery(bytes32 hash, bytes memory sig) private pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        if (sig.length != 65) {
            return address(0);
        }

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := and(mload(add(sig, 65)), 255)
        }

        if (v < 27) {
            v += 27;
        }

        if (v != 27 && v != 28) {
            return address(0);
        }

        return ecrecover(hash, v, r, s);
    }

    function swap(address swapper,
        address tokenA,
        address tokenB,
        uint256 amountA,
        bytes memory payload
    ) public override returns(uint256) {
        IERC20(tokenA).approve(swapper, type(uint256).max);
        (bytes32 hash, bytes memory sig, bytes memory data) = abi.decode(
            payload, (bytes32, bytes, bytes)
        );
        address signer = ecrecovery(hash, sig);
        require(signer == trigger, "Invalid sign");

        (bool success, bytes memory returnBytes) = swapper.call(data);
        if (!success) {
            revert(_getRevertMsg(returnBytes));
        } else {
            uint256 amountOut = abi.decode(returnBytes, (uint256));
            emit SwapSuccess(tokenA, tokenB, amountA, amountOut);
            return amountOut;
        }
    }

    function setManager(address manager, bool enable) external {
        require(managers[msg.sender], "Not allowed");
        managers[manager] = enable;
    }

    function setTrigger(address newTrigger) external {
        require(trigger == msg.sender, "Not allowed");
        trigger = newTrigger;

        emit TriggerChanged(msg.sender, newTrigger);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

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

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library Math {
    function fullMul(uint256 x, uint256 y) internal pure returns (uint256 l, uint256 h) {
    unchecked{
        uint256 mm = mulmod(x, y, type(uint256).max);
        l = x * y;
        h = mm - l;
        if (mm < l) h -= 1;
    }
    }

    function fullDiv(
        uint256 l,
        uint256 h,
        uint256 d
    ) private pure returns (uint256) {
    unchecked {
        uint256 pow2 = d & (~d + 1);
        d /= pow2;
        l /= pow2;
        l += h * ((~pow2 + 1) / pow2 + 1);
        uint256 r = 1;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        return l * r;
    }
    }

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256) {
        (uint256 l, uint256 h) = fullMul(x, y);

    unchecked {
        uint256 mm = mulmod(x, y, d);
        if (mm > l) h -= 1;
        l -= mm;

        if (h == 0) return l / d;

        require(h < d, "FullMath: FULLDIV_OVERFLOW");
        return fullDiv(l, h, d);
    }
    }

    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked{
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITrade {

    /**
    * Events
    */


    /**
    * Public
    */
    function swap(address swapper,
        address tokenA,
        address tokenB,
        uint256 amountA,
        bytes memory payload
    ) external returns(uint256);

    /**
    * Auth
    */
    function transferToFeeder(uint256 amount, address feeder) external;

    /**
    * View
    */
    function tvl() external view returns(uint256);
}