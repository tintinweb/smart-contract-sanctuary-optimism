/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-06-20
*/

/**
    Lets Go Brandon! V4 - $FJB
    
    Total Supply: 40,000,000,000 (40 Billion)

    Lets Go Brandon! V4 - $FJB is a fork contract for the token Lets Go Brandon! - $FJB.
    This fork was needed to fix liquidity pool issues, airdrop conversion issues from V3,
    amount of supply in circulation, better contract management for the project and token,
    and an issue in the code that created gas fees to continuously grow.

    R3JhbnQgaXMgYSBseWluZyBkb3VjaGViYWcu
*/

// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.9;

interface IERC20 {
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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
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
     * @dev Returns the integer division of two unsigned integers. Reverts on
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
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
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
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}


abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

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
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
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
        return _functionCallWithValue(target, data, 0, errorMessage);
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
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
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
contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
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

    function getLockedTime() public view returns (uint256) {
        return _lockTime;
    }

    /**
     * @dev Lock the contract for owner for the amounts of time provided.
     *
     * @param duration: amounts of time to lock.
     *
     * For example: if you want to set this value to 1 day,
     * please enter `86400` (60 x 60 x 24 = 86400s)
     */
    function lockToken(uint256 duration) public virtual onlyOwner {
        require(duration <= 86400, "Lock time should be maximum 1 day.");
        _previousOwner = _owner;
        _owner = address(0);
        _lockTime = block.timestamp + duration;
        emit OwnershipTransferred(_owner, address(0));
    }
    
    // Unlock the contract for owner when _lockTime is exceeds
    function unlockToken() public virtual {
        require(_previousOwner == msg.sender, "You don't have permission to unlock");
        require(block.timestamp > _lockTime , "Contract is locked until 1 day");
        emit OwnershipTransferred(_owner, _previousOwner);
        _owner = _previousOwner;
    }
}

interface IV3SwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint amount0Desired;
        uint amount1Desired;
        uint amount0Min;
        uint amount1Min;
        address recipient;
        uint deadline;
    }

    function mint(
        MintParams calldata params
    )
        external
        payable
        returns (uint tokenId, uint128 liquidity, uint amount0, uint amount1);

    struct IncreaseLiquidityParams {
        uint tokenId;
        uint amount0Desired;
        uint amount1Desired;
        uint amount0Min;
        uint amount1Min;
        uint deadline;
    }

    function increaseLiquidity(
        IncreaseLiquidityParams calldata params
    ) external payable returns (uint128 liquidity, uint amount0, uint amount1);

    struct DecreaseLiquidityParams {
        uint tokenId;
        uint128 liquidity;
        uint amount0Min;
        uint amount1Min;
        uint deadline;
    }

    function decreaseLiquidity(
        DecreaseLiquidityParams calldata params
    ) external payable returns (uint amount0, uint amount1);

    struct CollectParams {
        uint tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(
        CollectParams calldata params
    ) external payable returns (uint amount0, uint amount1);
}

contract FJBV4 is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _automatedMarketMakerPairs;
    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isVIPWallet;
    mapping (address => bool) private _blacklist;

    uint256 private _totalSupply = 40000000000 * 10**9;

    string private _name = "Lets Go Brandon!";
    string private _symbol = "$FJB-test";
    uint8 private _decimals = 9;
    
    uint256 public buyCharityFee = 1;
    uint256 public buyMarketingFee = 5;
    uint256 public buyLPFee = 2;
    uint256 public buyTeamFees;

    uint256 public sellCharityFee = 1;
    uint256 public sellMarketingFee = 5;
    uint256 public sellLPFee = 2;
    uint256 public sellTeamFees;

    uint256 public transferCharityFee = 1;
    uint256 public transferMarketingFee = 5;
    uint256 public transferLPFee = 2;
    uint256 public transferTeamFees;

    // Fee for VIP
    uint256 public transferCharityFeeForVIP = 1;
    uint256 public transferMarketingFeeForVIP = 5;
    uint256 public transferLPFeeForVIP = 2;
    uint256 public transferTeamFeesForVIP;

    uint256 private _tokensForCharity;
    uint256 private _tokensForMarketing;
    uint256 private _tokensForLP;

    IV3SwapRouter public immutable uniswapV3Router02;
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    address private constant SWAP_ROUTER_02 = address(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    address private constant NONFUNGIBLE_POSITION_MANAGER = address(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    address private constant WETH = address(0x4200000000000000000000000000000000000006);
    int24 private constant MIN_TICK = -887272;
    int24 private constant MAX_TICK = -MIN_TICK;
    int24 private constant TICK_SPACING = 60;

    address public stableTokenAddress;  // The address of the stable token

    address payable public charityAddress = payable(0x8249929D38FFa0259Fb96868e88fB9A21695E9d3);
    address payable public marketingAddress = payable(0xbc36FACe2075ae2b0f299C38Da0523067e4AAA56);
    
    uint256 public maxTxAmount = 100000000 * 10**9;
    uint256 public mixAmountToSwap = 1000000;

    bool private _isSwapping = false;
    bool public isSwapEnabled = false;
    bool public isSwapEnabledForStableToken = false;

    event SwapFor(address fromToken, address toToken, uint256 amountIn);
    event SetAutomatedMarketMakerPair(address pairAddress, bool value);
    event SetSwapStatus(bool status);
    event SetStatusToConvertStableToken(bool status);
    event AddLiquidity(uint256 contractTokens, uint256 tokensSwapped);

    modifier lockSwap {
        _isSwapping = true;
        _;
        _isSwapping = false;
    }
    
    constructor () {
        _balances[_msgSender()] = _totalSupply;

        uniswapV3Router02 = IV3SwapRouter(SWAP_ROUTER_02);
        nonfungiblePositionManager = INonfungiblePositionManager(NONFUNGIBLE_POSITION_MANAGER);

        stableTokenAddress = address(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58); // USDT address as default

        buyTeamFees = buyCharityFee + buyMarketingFee + buyLPFee;
        sellTeamFees = sellCharityFee + sellMarketingFee + sellLPFee;
        transferTeamFees = transferCharityFee + transferMarketingFee + transferLPFee;
        transferTeamFeesForVIP = transferCharityFeeForVIP + transferMarketingFeeForVIP + transferLPFeeForVIP;

        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

     //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}
    
    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function isAutomatedMarketMakerPair(address pairAddress) external view onlyOwner returns (bool) {
        return _automatedMarketMakerPairs[pairAddress];
    }

    function setAutomatedMarketMakerPair(address pairAddress, bool value) external onlyOwner {
        _automatedMarketMakerPairs[pairAddress] = value;

        emit SetAutomatedMarketMakerPair(pairAddress, value);
    }

    function isExcludedFromFee(address account) external view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }
    
    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function isVIPWallet(address account) external view returns(bool) {
        return _isVIPWallet[account];
    }

    function excludeFromVIP(address account) external onlyOwner {
        _isVIPWallet[account] = false;
    }
    
    function includeInVIP(address account) external onlyOwner {
        _isVIPWallet[account] = true;
    }

    function checkBlacklist(address account) external view returns (bool) {
        return _blacklist[account];
    }

    function addToBlacklist(address account) external onlyOwner() {
        _blacklist[account] = true;
    }
    
    function removeFromBlacklist(address account) external onlyOwner() {
        _blacklist[account] = false;
    }
    
    /** 
    * @dev Set fees of Charity, Marketing, LP when buying
    *
    * @param charityFee: Charity fee. ex: `1`. 
    * @param marketingFee: Marketing fee. ex: `5`.
    * @param lpFee: Liquidity Pool fee. ex: `2`.
    */
    function setBuyFeesPercent(uint256 charityFee, uint256 marketingFee, uint256 lpFee) external onlyOwner {
        buyCharityFee = charityFee;
        buyMarketingFee = marketingFee;
        buyLPFee = lpFee;
        buyTeamFees = buyCharityFee + buyMarketingFee + buyLPFee;
    }

    /** 
    * @dev Set fees of Charity, Marketing, LP when selling
    *
    * @param charityFee: Charity fee. ex: `1`. 
    * @param marketingFee: Marketing fee. ex: `5`.
    * @param lpFee: Liquidity Pool fee. ex: `2`.
    */
    function setSellFeesPercent(uint256 charityFee, uint256 marketingFee, uint256 lpFee) external onlyOwner {
        sellCharityFee = charityFee;
        sellMarketingFee = marketingFee;
        sellLPFee = lpFee;
        sellTeamFees = sellCharityFee + sellMarketingFee + sellLPFee;
    }

    /** 
    * @dev Set fees of Charity, Marketing, LP when transfering
    *
    * @param charityFee: Charity fee. ex: `1`. 
    * @param marketingFee: Marketing fee. ex: `5`.
    * @param lpFee: Liquidity Pool fee. ex: `2`.
    */
    function setTransferFeesPercent(uint256 charityFee, uint256 marketingFee, uint256 lpFee) external onlyOwner {
        transferCharityFee = charityFee;
        transferMarketingFee = marketingFee;
        transferLPFee = lpFee;
        transferTeamFees = transferCharityFee + transferMarketingFee + transferLPFee;
    }

    /** 
    * @dev Set fees of Charity, Marketing, LP for VIP when transfering
    *
    * @param charityFee: Charity fee. ex: `1`. 
    * @param marketingFee: Marketing fee. ex: `5`.
    * @param lpFee: Liquidity Pool fee. ex: `2`.
    */
    function setTransferFeesPercentForVIP(uint256 charityFee, uint256 marketingFee, uint256 lpFee) external onlyOwner {
        transferCharityFeeForVIP = charityFee;
        transferMarketingFeeForVIP = marketingFee;
        transferLPFeeForVIP = lpFee;
        transferTeamFeesForVIP = transferCharityFeeForVIP + transferMarketingFeeForVIP + transferLPFeeForVIP;
    }

    /**
    * @param maxTxPercent: Max transaction percentage. ex: `2`.
    */
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        maxTxAmount = _totalSupply.mul(maxTxPercent).div(100);
    }
    
    /**
    * @param maxTxExact: Max transaction amounts. ex: `100000000`.
    */
    function setMaxTxExact(uint256 maxTxExact) external onlyOwner() {
        maxTxAmount = maxTxExact;
    }

    /**
    * @param minAmountToSwapExact: Min amounts to swap. ex: `100000000`.
    */
    function setMinAmountToSwap(uint256 minAmountToSwapExact) external onlyOwner() {
        mixAmountToSwap = minAmountToSwapExact;
    }
    
    function setCharityAddress(address account) external onlyOwner() {
        require(charityAddress != account, "ERROR: Can not set to same address.");
        charityAddress = payable(account);
    }
    
    function setMarketingAddress(address account) external onlyOwner() {
        require(marketingAddress != account, "ERROR: Can not set to same address.");
        marketingAddress = payable(account);
    }
    
    function setSwapStatus(bool status) external onlyOwner() {
        isSwapEnabled = status;

        emit SetSwapStatus(status);
    }
    
    function setSwapStatusForStableToken(bool status) external onlyOwner() {
        isSwapEnabledForStableToken = status;

        emit SetStatusToConvertStableToken(status);
    }
    
    function setStableTokenAddress(address account) external onlyOwner() {
        require(stableTokenAddress != account, "ERROR: Can not set to same address.");
        stableTokenAddress = account;
    }
    
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(!_blacklist[from] && !_blacklist[to], "Your account is blacklisted.");

        if (from != owner() && to != owner()) {
            require(amount <= maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= mixAmountToSwap;

        if (canSwap && isSwapEnabled && !_isSwapping && !_automatedMarketMakerPairs[from]) {
            _swapAndSend(contractTokenBalance);
        }

        bool takeFee = true;
        
        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        uint256 tokensForTeam = 0;
        if (takeFee) {
            // on buy
            if (_automatedMarketMakerPairs[from] && to != address(uniswapV3Router02)) {
                tokensForTeam = amount.mul(buyTeamFees).div(100);
                _tokensForCharity += tokensForTeam.mul(buyCharityFee).div(buyTeamFees);
                _tokensForMarketing += tokensForTeam.mul(buyMarketingFee).div(buyTeamFees);
                _tokensForLP += tokensForTeam.mul(buyLPFee).div(buyTeamFees);
            }
            // on sell
            else if (_automatedMarketMakerPairs[to] && from != address(uniswapV3Router02)) {
                tokensForTeam = amount.mul(sellTeamFees).div(100);
                _tokensForCharity += tokensForTeam.mul(sellCharityFee).div(sellTeamFees);
                _tokensForMarketing += tokensForTeam.mul(sellMarketingFee).div(sellTeamFees);
                _tokensForLP += tokensForTeam.mul(sellLPFee).div(sellTeamFees);
            }
            // on transfer
            else if (!_automatedMarketMakerPairs[from] && !_automatedMarketMakerPairs[to]) {
                if (_isVIPWallet[to]) {
                    tokensForTeam = amount.mul(transferTeamFeesForVIP).div(100);
                    _tokensForCharity += tokensForTeam.mul(transferCharityFeeForVIP).div(transferTeamFeesForVIP);
                    _tokensForMarketing += tokensForTeam.mul(transferMarketingFeeForVIP).div(transferTeamFeesForVIP);
                    _tokensForLP += tokensForTeam.mul(transferLPFeeForVIP).div(transferTeamFeesForVIP);
                } else {
                    tokensForTeam = amount.mul(transferTeamFees).div(100);
                    _tokensForCharity += tokensForTeam.mul(transferCharityFee).div(transferTeamFees);
                    _tokensForMarketing += tokensForTeam.mul(transferMarketingFee).div(transferTeamFees);
                    _tokensForLP += tokensForTeam.mul(transferLPFee).div(transferTeamFees);
                }
            }

            if (tokensForTeam > 0) {
                _takeTeam(from, tokensForTeam);
            }

        	amount -= tokensForTeam;
        }

        _tokenTransfer(from, to, amount);
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount) private {
        _balances[sender] = _balances[sender].sub(amount);

        if (_isVIPWallet[recipient] && isSwapEnabledForStableToken) {
            uint256 stableToken = _swapTokensFor(amount, stableTokenAddress);
            _transferStableTokensToWallets(payable(recipient), stableToken);
        } else {
            _balances[recipient] = _balances[recipient].add(amount);
        }

        emit Transfer(sender, recipient, amount);
    }

    function _takeTeam(address sender, uint256 tokensForTeam) private {
        _balances[sender] = _balances[sender].sub(tokensForTeam);
        _balances[address(this)] = _balances[address(this)].add(tokensForTeam);
    }
    
    /** 
    * @dev Swap for WETH.
    *
    * @param tokenAmount: Token amounts to be swapped.
    */
    function _swapTokensForWETH(uint256 tokenAmount) private {
        // Approve the Uniswap V3 router to spend the token
        _approve(address(this), address(uniswapV3Router02), tokenAmount);

        // Specify the token swap details
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: address(this),
                tokenOut: WETH,
                fee: 3000,
                recipient: address(this),
                amountIn: tokenAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // Execute the token swap
        uniswapV3Router02.exactInputSingle(params);

        emit SwapFor(address(this), WETH, tokenAmount);
    }

    /** 
    * @dev Swap for stable token.
    *
    * @param tokenAmount: Token amounts to be swapped.
    */
    function _swapTokensForStableToken(uint256 tokenAmount) private {
        // Approve the Uniswap V3 router to spend the token
        _approve(address(this), address(uniswapV3Router02), tokenAmount);

        // Specify the token swap details
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: address(this),
                tokenOut: stableTokenAddress,
                fee: 3000,
                recipient: address(this),
                amountIn: tokenAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // Execute the token swap
        uniswapV3Router02.exactInputSingle(params);

        emit SwapFor(address(this), stableTokenAddress, tokenAmount);
    }

    function _swapTokensFor(uint256 amounts, address tokenDesiredToSwap ) private returns (uint256) {
        IERC20 stableToken = IERC20(stableTokenAddress);
        uint256 tokensSwapped = 0;

        if (tokenDesiredToSwap == stableTokenAddress) {
            uint256 initialStableTokenBalance = stableToken.balanceOf(address(this));
            _swapTokensForStableToken(amounts);
            tokensSwapped = stableToken.balanceOf(address(this)).sub(initialStableTokenBalance);
        } else {
            uint256 initialETHBalance = address(this).balance;
            _swapTokensForWETH(amounts);
            tokensSwapped = address(this).balance.sub(initialETHBalance);
        }

        return tokensSwapped;
    }

    function addLiquidity(uint256 contractTokenAmount, uint256 wethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV3Router02), contractTokenAmount);

        // add the liquidity
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: address(this),
                token1: WETH,
                fee: 3000,
                tickLower: (MIN_TICK / TICK_SPACING) * TICK_SPACING,
                tickUpper: (MAX_TICK / TICK_SPACING) * TICK_SPACING,
                amount0Desired: contractTokenAmount,
                amount1Desired: wethAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        nonfungiblePositionManager.mint(params);
    }

    function _swapAndSend(uint256 contractTokenBalance) private lockSwap {
        uint256 totalTokens = _tokensForCharity.add(_tokensForMarketing).add(_tokensForLP);

        uint256 tokenBalanceForLP = contractTokenBalance.mul(_tokensForLP).div(totalTokens);
        uint256 tokenBalanceForTeam = contractTokenBalance.sub(tokenBalanceForLP);

        uint256 halfTokensForLP = tokenBalanceForLP.div(2);
        uint256 otherHalfTokensForLP = tokenBalanceForLP.sub(halfTokensForLP);

        if (isSwapEnabledForStableToken) {
            // swap tokensForTeam for stable token
            uint256 stableTokens = _swapTokensFor(tokenBalanceForTeam, stableTokenAddress);

            uint256 tokensForCharity = stableTokens.mul(_tokensForCharity).div(totalTokens);
            uint256 tokensForMarketing = stableTokens.mul(_tokensForMarketing).div(totalTokens);

            _transferStableTokensToWallets(charityAddress, tokensForCharity);
            _transferStableTokensToWallets(marketingAddress, tokensForMarketing);
        } else {
            // swap tokensForTeam for eth
            uint256 ethForTeam = _swapTokensFor(tokenBalanceForTeam, WETH);

            uint256 ethForCharity = ethForTeam.mul(_tokensForCharity).div(totalTokens);
            uint256 ethForMarketing = ethForTeam.mul(_tokensForMarketing).div(totalTokens);

            charityAddress.transfer(ethForCharity);
            marketingAddress.transfer(ethForMarketing);
        }

        // swap tokensForLP for eth
        uint256 ethForLP = _swapTokensFor(otherHalfTokensForLP, WETH);

        // add liquidity to uniswap
        if (halfTokensForLP > 0 && ethForLP > 0) {
            addLiquidity(halfTokensForLP, ethForLP);

            emit AddLiquidity(halfTokensForLP, ethForLP);
        }

        _tokensForCharity = 0;
        _tokensForMarketing = 0;
        _tokensForLP = 0;
    }

    /** 
    * @dev Send to recipient the converted stable token.
    *
    * @param recipient: Address to receive.
    * @param amount: Token amounts to transfer.
    */
    function _transferStableTokensToWallets(address payable recipient, uint256 amount) private {
        IERC20 stableToken = IERC20(stableTokenAddress);
        stableToken.transfer(recipient, amount);

        emit Transfer(address(this), recipient, amount);
    }
}