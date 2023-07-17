// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
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

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract acxToken is ERC20, Ownable{
    constructor(string memory symbol, string memory name) public ERC20(symbol, name) { }

    function mint(address _to, uint256 _amount) public onlyOwner{
    	_mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public{
        if(msg.sender != owner()){
            require(msg.sender == _from, "No");
        }
    	_burn(_from, _amount);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IACX{
	function burn(address _to, uint256 _amount) external;
	function mint(address _to, uint256 _amount) external;
	function totalSupply() external returns(uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IGauge{
	function getReward(address account) external;
	function deposit(uint amount) external;
	function withdraw(uint amount) external;
	function balanceOf(address) external view returns (uint);
    function earned(address account) external view returns (uint);
    function rewardToken() external view returns (address);

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IVelodromePair {
  function allowance(address owner, address spender)external view returns(uint256);
  function approve(address spender, uint256 amount)external returns(bool);
  function balanceOf(address account)external view returns(uint256);
  function burn(address to)external returns(uint256 amount0, uint256 amount1);
  function getAmountOut(uint256 amountIn, address tokenIn)external view returns(uint256);
  function getReserves() external view returns(uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast);
  function mint(address to)external returns(uint256 liquidity);
  function name() external view returns(string memory);
  function quote(address tokenIn, uint256 amountIn, uint256 granularity)external view returns(uint256 amountOut);
  function reserve0() external view returns(uint256);
  function reserve1() external view returns(uint256);


  function stable() external view returns(bool);
  function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data)external;
  function symbol() external view returns(string memory);
  function token0() external view returns(address);
  function token1() external view returns(address);


}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IWETH {
	function deposit() external payable;
    function withdraw(uint256 value) external;
}

// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Interfaces/IVelodromePair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.6.12;

library Babylonian {
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // else z = 0
    }
}



contract lpHelper {
    using SafeMath for uint256;
    
    function calculateSwapInAmount(uint256 reserveIn, uint256 reserveOut, uint256 userIn, bool stable,uint256 amountOut)
    public
    pure
    returns (uint256)
    {
    		if(stable){
				uint ratio = amountOut * 1e18 / (userIn) * reserveIn / reserveOut;
        		return userIn * 1e18 / (ratio + 1e18);    			
    		}
			return
	        Babylonian
	        .sqrt(
	            reserveIn.mul(userIn.mul(3988000) + reserveIn.mul(3988009))
	        )
	        .sub(reserveIn.mul(1997)) / 1994;
    }


    function _addLiquidity(address _token, address _pair, uint256 _amount) internal returns (uint256 liquidity) {
    	address token0 = IVelodromePair(_pair).token0();
    	address token1 = IVelodromePair(_pair).token1();
    	if(token0 != _token){
    		(uint256 amountIn,uint256 amountOut) = _swapTokenForLiq(_pair, token1, _amount);
    		IERC20(token1).transfer(address(_pair), amountIn);
            IERC20(token0).transfer(address(_pair), amountOut);
            liquidity = IVelodromePair(_pair).mint(address(this));
    	}else{
    		(uint256 amountIn,uint256 amountOut) = _swapTokenForLiq(_pair, token0, _amount);
			IERC20(token0).transfer(address(_pair), amountIn);
            IERC20(token1).transfer(address(_pair), amountOut);
            liquidity = IVelodromePair(_pair).mint(address(this));
    	}
    }


    function _swapTokenForLiq(address _pair, address fromToken, uint256 amountIn) internal returns (uint256 inputAmount, uint256 amountOut) {
        IVelodromePair pair = IVelodromePair(_pair);
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        bool stable = IVelodromePair(_pair).stable();
        uint256 out = IVelodromePair(_pair).getAmountOut(amountIn, fromToken);
        if (fromToken == pair.token0()) {
        	inputAmount = calculateSwapInAmount(reserve0, reserve1 , amountIn, stable, out);
            IERC20(fromToken).transfer(address(pair), inputAmount);

            amountOut = pair.getAmountOut(inputAmount, fromToken); 
            pair.swap(0, amountOut, address(this), new bytes(0));
            inputAmount = amountIn.sub(inputAmount);
        } else {
        	inputAmount = calculateSwapInAmount(reserve1, reserve0 ,amountIn, stable, out);

            IERC20(fromToken).transfer(address(pair), inputAmount);

            amountOut = pair.getAmountOut(inputAmount, fromToken);
            pair.swap(amountOut, 0, address(this), new bytes(0));
            inputAmount = amountIn.sub(inputAmount);
        }
    }

    function _swapToken(address _pair, address fromToken, uint256 amountIn) internal returns(uint256 amountOut, address outToken){
    	IVelodromePair pair = IVelodromePair(_pair);
        if (fromToken == pair.token0()) {
        	outToken = pair.token1();
            IERC20(fromToken).transfer(address(pair), amountIn);
            amountOut = pair.getAmountOut(amountIn, fromToken);
            pair.swap(0, amountOut, address(this), new bytes(0));
        } else {
        	outToken = pair.token0();
            IERC20(fromToken).transfer(address(pair), amountIn);
            amountOut = pair.getAmountOut(amountIn, fromToken);
            pair.swap(amountOut, 0, address(this), new bytes(0));
        }
    }



}

// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.6.12;
/*                                 /$$    /$$                 /$$  /$$            
                                  | $$   | $$                | $$ | $$            
  /$$$$$$  /$$$$$$$/$$   /$$      | $$   | $$/$$$$$$ /$$   /$| $$/$$$$$$  /$$$$$$$
 |____  $$/$$_____|  $$ /$$/      |  $$ / $$|____  $| $$  | $| $|_  $$_/ /$$_____/
  /$$$$$$| $$      \  $$$$/        \  $$ $$/ /$$$$$$| $$  | $| $$ | $$  |  $$$$$$ 
 /$$__  $| $$       >$$  $$         \  $$$/ /$$__  $| $$  | $| $$ | $$ /$\____  $$
|  $$$$$$|  $$$$$$$/$$/\  $$         \  $/ |  $$$$$$|  $$$$$$| $$ |  $$$$/$$$$$$$/
 \_______/\_______|__/  \__/          \_/   \_______/\______/|__/  \___/|_______/ */
                                                                                  
// An Open X Project                                                                                  

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Interfaces/IVelodromePair.sol";

import './Interfaces/IGauge.sol';
import "./Interfaces/IACX.sol";
import "./Interfaces/IWETH.sol";
import "./acxToken.sol";
import "./lpHelper.sol";

contract vaultFactory is Ownable, lpHelper{
    using SafeMath for uint256;

	// The struct for the pool information.
	struct PoolInfo {
		address rewardToken;
		address underlyingLp;
		address acxToken;
		address gauge;
		uint256 totalStaked;
		address[] path;
		uint256 lastCollectionTimestamp;
	}

	// Array of pools and mapping to check if pair already exists.
	PoolInfo[] public Pools;
	mapping(address => bool) public pairExists;

	// Variables for fees.
	uint256 public bountyfeePer10K = 100;
	uint256 public performanceFeePer10K = 600;
	uint256 public zapFeePer10K = 10;
	uint256 public perfPool = 0;


	address public weth = 0x4200000000000000000000000000000000000006;
	

	uint private unlocked = 1;
    //reentrancy guard
    modifier lock() {
        require(unlocked == 1, 'OpenX LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // Method to get the length of pools.
	function poolsLength() public view returns (uint256){
		return Pools.length;
	}

	// Method to add a new vault.
	function addVault(address _underlyingLp, address _gauge, address[] memory path) public onlyOwner{
		require(pairExists[_underlyingLp] == false, "Pool Already Exists.");
		pairExists[_underlyingLp] = true;
		PoolInfo memory newPool;
		acxToken acx = new acxToken(string(abi.encodePacked('acx-', IVelodromePair(_underlyingLp).symbol())) , string(abi.encodePacked('Auto Compounding X ', IVelodromePair(_underlyingLp).symbol())));
		newPool.acxToken = address(acx);
		newPool.gauge = _gauge;
		newPool.underlyingLp = _underlyingLp;
		newPool.rewardToken = IGauge(_gauge).rewardToken();
		newPool.path = path;
		Pools.push(newPool);
	}

	// Method to update the path for token swaps.
	function updatePath(uint256 _pid, address[] memory _path) public onlyOwner {
		Pools[_pid].path = _path;
	}

	// Method to update the performance pool.
	function updatePerfPool(uint256 _pid) public onlyOwner{
		perfPool = _pid;
	}

	// Method to update the fees.
	function updateFees(uint256 _bountyfeePer10K, uint256 _performanceFeePer10K, uint256 _zapFeePer10K) public onlyOwner {
		require(_bountyfeePer10K.add(_performanceFeePer10K).add(_zapFeePer10K) <= 1000, "Max 10%");
		bountyfeePer10K = _bountyfeePer10K;
		performanceFeePer10K = _performanceFeePer10K;
		zapFeePer10K = _zapFeePer10K;
	}


	// Method to deposit into a pool.
	function deposit(uint256 _pid, uint256 _amount, address _to) public lock{
		IERC20 lpToken = IERC20(Pools[_pid].underlyingLp);
		safeTransferFrom(address(lpToken), msg.sender, address(this), _amount);
		_deposit(_pid, _amount, _to);
	}

	// Internal method to handle the deposit logic.
	function _deposit(uint256 _pid, uint256 _amount, address _to) internal {
		IACX acxToken = IACX(Pools[_pid].acxToken);
		IERC20 lpToken = IERC20(Pools[_pid].underlyingLp);
		IGauge gauge = IGauge(Pools[_pid].gauge);
		uint256 totalSupply = acxToken.totalSupply();

		if(totalSupply == 0){
			acxToken.mint(_to, _amount);
		}else{
			if(Pools[_pid].lastCollectionTimestamp != block.timestamp){
				Pools[_pid].lastCollectionTimestamp = block.timestamp;
				claimBounty(_pid,_to);
			}
			uint256 lpBal = gauge.balanceOf(address(this));
			
            uint256 _mintAmount = _amount.mul(totalSupply).div(lpBal);
            acxToken.mint(_to, _mintAmount);
		}


		lpToken.approve(address(gauge), _amount);
		gauge.deposit(_amount);
		Pools[_pid].totalStaked += _amount;
	}

	// Method to withdraw from a pool.
	function withdraw(uint256 _pid, uint256 _amount, address _to) public lock{
		_withdraw(_pid, _amount, msg.sender, _to);
	}

	// Internal method to handle the withdrawal logic.
	function _withdraw(uint256 _pid, uint256 _amount,address _from, address _to) internal returns(uint256) {
		IACX acxToken = IACX(Pools[_pid].acxToken);
		IERC20 lpToken = IERC20(Pools[_pid].underlyingLp);
		IGauge gauge = IGauge(Pools[_pid].gauge);
		uint256 totalSupply = acxToken.totalSupply();
		uint256 lpBal = gauge.balanceOf(address(this));
		uint256 withdrawAmount = _amount.mul(lpBal).div(totalSupply);
		
		acxToken.burn(_from, _amount);
		gauge.withdraw(withdrawAmount);
		safeTransfer(address(lpToken), _to, withdrawAmount);

		Pools[_pid].totalStaked -= withdrawAmount;
		return withdrawAmount;
	}

    // Method to claim the bounty.
    function claimBounty(uint256 _pid, address _to) public {
    	address rewardToken = Pools[_pid].rewardToken;
    	IGauge gauge = IGauge(Pools[_pid].gauge);
    	uint256 earned = gauge.earned(address(this));
    	if(earned < 1*10**17){
    		return;
    	}
    	uint256 bounty = earned.mul(bountyfeePer10K).div(10000);
    	uint256 performance = earned.mul(bountyfeePer10K).div(10000);
    	gauge.getReward(address(this));

    	safeTransfer(rewardToken, _to, bounty);

    	earned = earned.sub(performance).sub(bounty);
    	uint256 amount = _compound(_pid, earned);

    	uint256 amountPerf = _compound(perfPool, performance);
    	_deposit(perfPool, amountPerf, owner());

    	Pools[_pid].totalStaked += amount;

    	IERC20(Pools[_pid].underlyingLp).approve(address(gauge), amount);
		gauge.deposit(amount);

    }

    // Method to handle the compounding.
    function _compound(uint256 _pid, uint256 _amount) internal returns(uint256){
    	uint256 len = Pools[_pid].path.length;
    	address outToken = Pools[_pid].rewardToken;
    	for(uint i; i < len; i++){

    		(_amount, outToken) = _swapToken(Pools[_pid].path[i], outToken, _amount);
    	}
    	if(len > 0){
    		return _addLiquidity(outToken, Pools[_pid].underlyingLp,  _amount);
    	}else{
    		return _addLiquidity(Pools[_pid].rewardToken, Pools[_pid].underlyingLp,  _amount);
    	}
    }

    // Method to zap.
    function zap(uint256 _pid,address _inToken, uint256 _amount, address[] memory _path, address _to) public payable lock {
    	uint256 len = _path.length;

    	if(_inToken == weth){
    		IWETH(weth).deposit{value: msg.value}();
    	}else{
			safeTransferFrom(_inToken, msg.sender, address(this), _amount);
    	}

    	for(uint i; i < len; i++){
    		(_amount, _inToken) = _swapToken(_path[i], _inToken, _amount);
    	}

    	_amount = _addLiquidity(_inToken, Pools[_pid].underlyingLp, _amount);
    	
    	uint256 feeAmount = _amount.mul(zapFeePer10K).div(10000);
    	_deposit(_pid, feeAmount, owner());
    	_deposit(_pid, _amount.sub(feeAmount), _to);
    }

    // Method to unzap.
    function unzap(uint256 _pid,address _outToken, uint256 _amount, address[] memory _path, address _to) public lock {
    	uint256 len = _path.length;
    	address outToken = _outToken;
    	address token0 = IVelodromePair(Pools[_pid].underlyingLp).token0();
    	address token1 = IVelodromePair(Pools[_pid].underlyingLp).token1();

    	if(_outToken == address(0)){
    		_amount = _withdraw(_pid, _amount, msg.sender, address(this));
    		uint256 feeAmount = _amount.mul(zapFeePer10K).div(10000);

    		_deposit(_pid, feeAmount, owner());
    		safeTransfer(Pools[_pid].underlyingLp, Pools[_pid].underlyingLp, _amount.sub(feeAmount));
	    	(uint256 amount0, uint256 amount1) = IVelodromePair(Pools[_pid].underlyingLp).burn(address(this)); 
	    	if (token0 == weth) {
	    		IWETH(weth).withdraw(amount0);
	    		safeTransferETH(_to, amount0);
	    	}else{
				safeTransfer(token0, _to, amount0);
	    	}
	    	if (token1 == weth) {
	    		IWETH(weth).withdraw(amount1);
	    		safeTransferETH(_to, amount1);
	    	}else{
	    		safeTransfer(token1, _to, amount1);
	    	}
    	}else{
	    	_withdraw(_pid, _amount, msg.sender, Pools[_pid].underlyingLp);
	    	(uint256 amount0, uint256 amount1) = IVelodromePair(Pools[_pid].underlyingLp).burn(address(this)); 
	    	if(token0 == outToken){
	    		(_amount, outToken) = _swapToken(Pools[_pid].underlyingLp, token1, amount1);
	    		_amount += amount0;
	    	}else{
	    	    (_amount, outToken) = _swapToken(Pools[_pid].underlyingLp, token0, amount0);
	    	   	_amount += amount1;
			}

	    	for(uint i; i < len; i++){
	    		(_amount, outToken) = _swapToken(_path[i], outToken, _amount);
	    	}

	    	uint256 feeAmount = _amount.mul(zapFeePer10K).div(10000);

	    	if(_outToken == weth){
	    		IWETH(weth).withdraw(_amount);
	    		safeTransferETH(owner(), feeAmount);
	    		safeTransferETH(_to, _amount.sub(feeAmount));
	    	}else{
				safeTransfer(_outToken, owner(), feeAmount);
				safeTransfer(_outToken, _to, _amount.sub(feeAmount));
	    	}
    	}
    }

    //Receive Eth
    receive() external payable{}


    function safeTransferETH(address to, uint _value) internal {
        (bool success,) = to.call{value:_value}(new bytes(0));
        require(success, 'ETH_TRANSFER_FAILED');
    }

   	function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FROM_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FAILED');
    }

}