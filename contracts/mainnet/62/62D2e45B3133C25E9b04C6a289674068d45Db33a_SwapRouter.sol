// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../tokens/interfaces/IWETH.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/Address.sol";
import "../libraries/utils/ReentrancyGuard.sol";

import "./interfaces/IRouter.sol";
import "./interfaces/IVault.sol";
import "./interfaces/ISwapRouter.sol";

import "../access/Governable.sol";
import "../peripherals/interfaces/ITimelock.sol";
import "./BaseRequestRouter.sol";

contract SwapRouter is ISwapRouter, BaseRequestRouter {

    struct SwapRequest {
        address account;
        address[] path;
        uint256 amountIn;
        uint256 minOut;
        address receiver;
        uint256 acceptableRatio;
        uint256 executionFee;
        uint256 blockNumber;
        uint256 blockTime;
        bool isETHIn;
        bool isETHOut;
    }

    bytes32[] public swapRequestKeys;

    uint256 public override swapRequestKeysStart;

    mapping (address => uint256) public swapsIndex;
    mapping (bytes32 => SwapRequest) public swapRequests;

    event CreateSwap(
        address indexed account,
        address[] path,
        uint256 amountIn,
        uint256 minOut,
        address receiver,
        uint256 acceptableRatio,
        uint256 executionFee,
        uint256 index,
        uint256 blockNumber,
        uint256 blockTime
    );

    event ExecuteSwap(
        address indexed account,
        address[] path,
        uint256 amountIn,
        uint256 amountOut,
        uint256 minOut,
        address receiver,
        uint256 acceptableRatio,
        uint256 executionFee,
        uint256 blockGap,
        uint256 timeGap
    );

    event CancelSwap(
        address indexed account,
        address[] path,
        uint256 amountIn,
        uint256 minOut,
        address receiver,
        uint256 acceptableRatio,
        uint256 executionFee,
        uint256 blockGap,
        uint256 timeGap
    );

    event SetRequestKeysStartValue(uint256 swapRequestKeysStart);

    constructor(
        address _vault,
        address _router,
        address _weth,
        uint256 _minExecutionFee
    ) public BaseRequestRouter(_vault, _router, _weth, _minExecutionFee) {}

    function setRequestKeysStartValue(uint256 _swapRequestKeysStart) external onlyAdmin {
        swapRequestKeysStart = _swapRequestKeysStart;

        emit SetRequestKeysStartValue(_swapRequestKeysStart);
    }

    function executeSwaps(uint256 _endIndex, address payable _executionFeeReceiver) external override onlyRequestKeeper {
        uint256 index = swapRequestKeysStart;
        uint256 length = swapRequestKeys.length;

        if (index >= length) { return; }

        if (_endIndex > length) {
            _endIndex = length;
        }

        while (index < _endIndex) {
            bytes32 key = swapRequestKeys[index];

            // if the request was executed then delete the key from the array
            // if the request was not executed then break from the loop, this can happen if the
            // minimum number of blocks has not yet passed
            // an error could be thrown if the request is too old or if the slippage is
            // higher than what the user specified, or if there is insufficient liquidity for the swap
            // in case an error was thrown, cancel the request
            try this.executeSwap(key, _executionFeeReceiver) returns (bool _wasExecuted) {
                if (!_wasExecuted) { break; }
            } catch {
                // wrap this call in a try catch to prevent invalid cancels from blocking the loop
                try this.cancelSwap(key, _executionFeeReceiver) returns (bool _wasCancelled) {
                    if (!_wasCancelled) { break; }
                } catch {}
            }

            delete swapRequestKeys[index];
            index++;
        }

        swapRequestKeysStart = index;
    }

    function createSwap(
        address[] memory _path,
        uint256 _amountIn,
        uint256 _minOut,
        address _receiver,
        uint256 _acceptableRatio,
        uint256 _executionFee,
        bool _isETHOut
    ) public payable {
        require(_executionFee >= minExecutionFee, "SwapRouter: invalid executionFee");
        require(msg.value == _executionFee, "SwapRouter: invalid msg.value");
        require(_path.length == 2, "SwapRouter: invalid _path length");
        require(_amountIn > 0, "SwapRouter: invalid amountIn");

        if (_isETHOut) {
            require(_path[_path.length - 1] == weth, "SwapRouter: invalid _path");
        }

        _transferInETH();

        IRouter(router).pluginTransfer(_path[0], msg.sender, address(this), _amountIn);

        _createSwap(
            msg.sender,
            _path,
            _amountIn,
            _minOut,
            _receiver,
            _acceptableRatio,
            _executionFee,
            false,
            _isETHOut
        );
    }

    function createSwapETHToTokens(
        address[] memory _path,
        uint256 _minOut,
        address _receiver,
        uint256 _acceptableRatio,
        uint256 _executionFee
    ) external payable {
        require(_executionFee >= minExecutionFee, "SwapRouter: invalid executionFee");
        require(msg.value >= _executionFee, "SwapRouter: invalid msg.value");
        require(_path.length == 2, "SwapRouter: invalid _path length");
        require(_path[0] == weth, "SwapRouter: invalid _path");

        _transferInETH();

        uint256 amountIn = msg.value.sub(_executionFee);

        require(amountIn > 0, "SwapRouter: invalid amountIn");

        _createSwap(
            msg.sender,
            _path,
            amountIn,
            _minOut,
            _receiver,
            _acceptableRatio,
            _executionFee,
            true,
            false
        );
    }

    function getRequestQueueLengths() external view returns (uint256, uint256) {
        return (
            swapRequestKeysStart,
            swapRequestKeys.length
        );
    }

    function getSwapRequestPath(bytes32 _key) public view returns (address[] memory) {
        SwapRequest memory request = swapRequests[_key];
        return request.path;
    }

    function executeSwap(bytes32 _key, address payable _executionFeeReceiver) public nonReentrant returns (bool) {
        SwapRequest memory request = swapRequests[_key];
        // if the request was already executed or cancelled, return true so that the executeSwaps loop will continue executing the next request
        if (request.account == address(0)) { return true; }

        bool shouldExecute = _validateExecution(request.blockNumber, request.blockTime, request.account);
        if (!shouldExecute) { return false; }

        uint256 ratio = IVault(vault).getMinPrice(request.path[0]).mul(PRICE_PRECISION).div(IVault(vault).getMaxPrice(request.path[1]));

        require(ratio >= request.acceptableRatio, "SwapRouter: price ratio lower than limit");

        delete swapRequests[_key];

        IERC20(request.path[0]).safeTransfer(vault, request.amountIn);
        uint256 amountOut = _swap(request.path, request.minOut, address(this));

        if (request.isETHOut) {
           _transferOutETHWithGasLimit(amountOut, payable(request.receiver));
        } else {
           IERC20(request.path[request.path.length - 1]).safeTransfer(request.receiver, amountOut);
        }

       _transferOutETH(request.executionFee, _executionFeeReceiver);

        emit ExecuteSwap(
            request.account,
            request.path,
            request.amountIn,
            amountOut,
            request.minOut,
            request.receiver,
            request.acceptableRatio,
            request.executionFee,
            block.number.sub(request.blockNumber),
            block.timestamp.sub(request.blockTime)
        );

        return true;
    }

    function cancelSwap(bytes32 _key, address payable _executionFeeReceiver) public nonReentrant returns (bool) {
        SwapRequest memory request = swapRequests[_key];
        // if the request was already executed or cancelled, return true so that the executeSwaps loop will continue executing the next request
        if (request.account == address(0)) { return true; }

        bool shouldCancel = _validateCancellation(request.blockNumber, request.blockTime, request.account);
        if (!shouldCancel) { return false; }

        delete swapRequests[_key];

        if (request.isETHIn) {
            _transferOutETHWithGasLimit(request.amountIn, payable(request.account));
        } else {
            IERC20(request.path[0]).safeTransfer(request.account, request.amountIn);
        }

       _transferOutETH(request.executionFee, _executionFeeReceiver);

        emit CancelSwap(
            request.account,
            request.path,
            request.amountIn,
            request.minOut,
            request.receiver,
            request.acceptableRatio,
            request.executionFee,
            block.number.sub(request.blockNumber),
            block.timestamp.sub(request.blockTime)
        );

        return true;
    }

    function _createSwap(
        address _account,
        address[] memory _path,
        uint256 _amountIn,
        uint256 _minOut,
        address _receiver,
        uint256 _acceptableRatio,
        uint256 _executionFee,
        bool _isETHIn,
        bool _isETHOut
    ) internal {
        uint256 index = swapsIndex[_account].add(1);
        swapsIndex[_account] = index;

        SwapRequest memory request = SwapRequest(
            _account,
            _path,
            _amountIn,
            _minOut,
            _receiver,
            _acceptableRatio,
            _executionFee,
            block.number,
            block.timestamp,
            _isETHIn,
            _isETHOut
        );

        bytes32 key = getRequestKey(_account, index);
        swapRequests[key] = request;

        swapRequestKeys.push(key);

        emit CreateSwap(
            _account,
            _path,
            _amountIn,
            _minOut,
            _receiver,
            _acceptableRatio,
            _executionFee,
            index,
            block.number,
            block.timestamp
        );
    }

    function _swap(address[] memory _path, uint256 _minOut, address _receiver) internal returns (uint256) {
        if (_path.length == 2) {
            return _vaultSwap(_path[0], _path[1], _minOut, _receiver);
        }
        revert("SwapRouter: invalid _path.length");
    }

    function _vaultSwap(address _tokenIn, address _tokenOut, uint256 _minOut, address _receiver) internal returns (uint256) {
        address timelock = IVault(vault).gov();
        ITimelock(timelock).activateFeeUtils(vault);
        uint256 amountOut = IVault(vault).swap(_tokenIn, _tokenOut, _receiver);
        ITimelock(timelock).deactivateFeeUtils(vault);

        require(amountOut >= _minOut, "SwapRouter: insufficient amountOut");
        return amountOut;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

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

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

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

//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./IERC20.sol";
import "../math/SafeMath.sol";
import "../utils/Address.sol";

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

pragma solidity ^0.6.2;

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
     * _Available since v3.3._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.3._
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

pragma solidity 0.6.12;

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
contract ReentrancyGuard {
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

pragma solidity 0.6.12;

interface IRouter {
    function addPlugin(address _plugin) external;
    function pluginTransfer(address _token, address _account, address _receiver, uint256 _amount) external;
    function pluginIncreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external;
    function pluginDecreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external returns (uint256);
    function swap(address[] memory _path, uint256 _amountIn, uint256 _minOut, address _receiver) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./IVaultUtils.sol";
import "./IFeeUtils.sol";

interface IVault {
    function isInitialized() external view returns (bool);
    function isSwapEnabled() external view returns (bool);
    function isLeverageEnabled() external view returns (bool);

    function setVaultUtils(IVaultUtils _vaultUtils) external;
    function setFeeUtils(IFeeUtils _feeUtils) external;
    function setError(uint256 _errorCode, string calldata _error) external;

    function router() external view returns (address);
    function usdf() external view returns (address);
    function gov() external view returns (address);

    function getVaultUtils() external view returns (address);
    function getFeeUtils() external view returns (address);

    function whitelistedTokenCount() external view returns (uint256);
    function maxLeverage() external view returns (uint256);

    function minProfitTime() external view returns (uint256);
    function totalTokenWeights() external view returns (uint256);
    function getTargetUsdfAmount(address _token) external view returns (uint256);

    function inManagerMode() external view returns (bool);
    function inPrivateLiquidationMode() external view returns (bool);

    function maxGasPrice() external view returns (uint256);

    function approvedRouters(address _account, address _router) external view returns (bool);
    function isLiquidator(address _account) external view returns (bool);
    function isManager(address _account) external view returns (bool);

    function minProfitBasisPoints(address _token) external view returns (uint256);
    function tokenBalances(address _token) external view returns (uint256);

    function setMaxLeverage(uint256 _maxLeverage) external;
    function setInManagerMode(bool _inManagerMode) external;
    function setManager(address _manager, bool _isManager) external;
    function setIsSwapEnabled(bool _isSwapEnabled) external;
    function setIsLeverageEnabled(bool _isLeverageEnabled) external;
    function setMaxGasPrice(uint256 _maxGasPrice) external;
    function setUsdfAmount(address _token, uint256 _amount) external;
    function setBufferAmount(address _token, uint256 _amount) external;
    function setMaxGlobalShortSize(address _token, uint256 _amount) external;
    function setInPrivateLiquidationMode(bool _inPrivateLiquidationMode) external;
    function setLiquidator(address _liquidator, bool _isActive) external;

    function setMinProfitTime(uint256 _minProfitTime) external;

    function setTokenConfig(
        address _token,
        uint256 _tokenDecimals,
        uint256 _redemptionBps,
        uint256 _minProfitBps,
        uint256 _maxUsdfAmount,
        bool _isStable,
        bool _isShortable
    ) external;

    function clearTokenConfig(address _token) external;

    function setPriceFeed(address _priceFeed) external;
    function withdrawFees(address _token, address _receiver) external returns (uint256);

    function directPoolDeposit(address _token) external;
    function buyUSDF(address _token, address _receiver) external returns (uint256);
    function sellUSDF(address _token, address _receiver) external returns (uint256);
    function swap(address _tokenIn, address _tokenOut, address _receiver) external returns (uint256);
    function increasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external;
    function decreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external returns (uint256);
    function liquidatePosition(address _account, address _collateralToken, address _indexToken, bool _isLong, address _feeReceiver) external;
    function tokenToUsdMin(address _token, uint256 _tokenAmount) external view returns (uint256);

    function priceFeed() external view returns (address);

    function allWhitelistedTokensLength() external view returns (uint256);
    function allWhitelistedTokens(uint256) external view returns (address);
    function whitelistedTokens(address _token) external view returns (bool);
    function stableTokens(address _token) external view returns (bool);
    function shortableTokens(address _token) external view returns (bool);
    function feeReserves(address _token) external view returns (uint256);
    function globalShortSizes(address _token) external view returns (uint256);
    function globalShortAveragePrices(address _token) external view returns (uint256);
    function maxGlobalShortSizes(address _token) external view returns (uint256);
    function tokenDecimals(address _token) external view returns (uint256);
    function tokenWeights(address _token) external view returns (uint256);
    function guaranteedUsd(address _token) external view returns (uint256);
    function poolAmounts(address _token) external view returns (uint256);
    function bufferAmounts(address _token) external view returns (uint256);
    function reservedAmounts(address _token) external view returns (uint256);
    function usdfAmounts(address _token) external view returns (uint256);
    function maxUsdfAmounts(address _token) external view returns (uint256);
    function getRedemptionAmount(address _token, uint256 _usdfAmount) external view returns (uint256);
    function getMaxPrice(address _token) external view returns (uint256);
    function getMinPrice(address _token) external view returns (uint256);

    function getDelta(address _indexToken, uint256 _size, uint256 _averagePrice, bool _isLong, uint256 _lastIncreasedTime) external view returns (bool, uint256);
    function getPositionDelta(address _account, address _collateralToken, address _indexToken, bool _isLong) external view returns (bool, uint256);
    function getPosition(address _account, address _collateralToken, address _indexToken, bool _isLong) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, bool, uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ISwapRouter {
    function swapRequestKeysStart() external returns (uint256);

    function executeSwaps(uint256 _count, address payable _executionFeeReceiver) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

contract Governable {
    address public gov;

    constructor() public {
        gov = msg.sender;
    }

    modifier onlyGov() {
        require(msg.sender == gov, "Governable: forbidden");
        _;
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ITimelock {
    function setAdmin(address _admin) external;
    function enableLeverage(address _vault) external;
    function disableLeverage(address _vault) external;
    function activateFeeUtils(address _vault) external;
    function deactivateFeeUtils(address _vault) external;
    function setIsLeverageEnabled(address _vault, bool _isLeverageEnabled) external;
    function signalSetGov(address _target, address _gov) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../tokens/interfaces/IWETH.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/Address.sol";
import "../libraries/utils/ReentrancyGuard.sol";

import "./interfaces/IRouter.sol";
import "./interfaces/IVault.sol";

import "../access/Governable.sol";

contract BaseRequestRouter is ReentrancyGuard, Governable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    uint256 public constant PRICE_PRECISION = 10 ** 30;

    address public admin;

    address public vault;
    address public router;
    address public weth;

    uint256 public minExecutionFee;

    uint256 public minBlockDelayKeeper;
    uint256 public minTimeDelayPublic;
    uint256 public maxTimeDelay;

    mapping (address => bool) public isRequestKeeper;

    event SetRequestKeeper(address indexed account, bool isActive);
    event SetMinExecutionFee(uint256 minExecutionFee);
    event SetDelayValues(uint256 minBlockDelayKeeper, uint256 minTimeDelayPublic, uint256 maxTimeDelay);
    event SetAdmin(address admin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "BaseRequestRouter: forbidden");
        _;
    }

    modifier onlyRequestKeeper() {
        require(isRequestKeeper[msg.sender], "BaseRequestRouter: forbidden");
        _;
    }

    constructor(
        address _vault,
        address _router,
        address _weth,
        uint256 _minExecutionFee
    ) public {
        vault = _vault;
        router = _router;
        weth = _weth;
        minExecutionFee = _minExecutionFee;

        admin = msg.sender;
    }

    receive() external payable {
        require(msg.sender == weth, "BaseRequestRouter: invalid sender");
    }

    function approve(address _token, address _spender, uint256 _amount) external onlyGov {
        IERC20(_token).approve(_spender, _amount);
    }

    function sendValue(address payable _receiver, uint256 _amount) external onlyGov {
        _receiver.sendValue(_amount);
    }

    function setAdmin(address _admin) external onlyGov {
        admin = _admin;
        emit SetAdmin(_admin);
    }

    function setRequestKeeper(address _account, bool _isActive) external onlyAdmin {
        isRequestKeeper[_account] = _isActive;
        emit SetRequestKeeper(_account, _isActive);
    }

    function setMinExecutionFee(uint256 _minExecutionFee) external onlyAdmin {
        minExecutionFee = _minExecutionFee;
        emit SetMinExecutionFee(_minExecutionFee);
    }

    function setDelayValues(uint256 _minBlockDelayKeeper, uint256 _minTimeDelayPublic, uint256 _maxTimeDelay) external onlyAdmin {
        minBlockDelayKeeper = _minBlockDelayKeeper;
        minTimeDelayPublic = _minTimeDelayPublic;
        maxTimeDelay = _maxTimeDelay;
        emit SetDelayValues(_minBlockDelayKeeper, _minTimeDelayPublic, _maxTimeDelay);
    }

    function getRequestKey(address _account, uint256 _index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _index));
    }

    function _validateExecution(uint256 _positionBlockNumber, uint256 _positionBlockTime, address _account) internal view returns (bool) {
        if (_positionBlockTime.add(maxTimeDelay) <= block.timestamp) {
            revert("BaseRequestRouter: request has expired");
        }

        bool isKeeperCall = msg.sender == address(this) || isRequestKeeper[msg.sender];

        if (isKeeperCall) {
            return _positionBlockNumber.add(minBlockDelayKeeper) <= block.number;
        }

        require(msg.sender == _account, "BaseRequestRouter: forbidden");

        require(_positionBlockTime.add(minTimeDelayPublic) <= block.timestamp, "BaseRequestRouter: min delay not yet passed");

        return true;
    }

    function _validateCancellation(uint256 _positionBlockNumber, uint256 _positionBlockTime, address _account) internal view returns (bool) {
        bool isKeeperCall = msg.sender == address(this) || isRequestKeeper[msg.sender];

        if (isKeeperCall) {
            return _positionBlockNumber.add(minBlockDelayKeeper) <= block.number;
        }

        require(msg.sender == _account, "BaseRequestRouter: forbidden");

        require(_positionBlockTime.add(minTimeDelayPublic) <= block.timestamp, "BaseRequestRouter: min delay not yet passed");

        return true;
    }

    function _transferInETH() internal {
        if (msg.value != 0) {
            IWETH(weth).deposit{value: msg.value}();
        }
    }

    function _transferOutETH(uint256 _amountOut, address payable _receiver) internal {
        IWETH(weth).withdraw(_amountOut);
        _receiver.sendValue(_amountOut);
    }

    function _transferOutETHWithGasLimit(uint256 _amountOut, address payable _receiver) internal {
        IWETH(weth).withdraw(_amountOut);
        _receiver.transfer(_amountOut);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./IFeeUtils.sol";

interface IVaultUtils {
    function getFeeUtils() external view returns (address);

    function setFeeUtils(IFeeUtils _feeUtils) external;
    function validateIncreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external view;
    function validateDecreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external view;
    function validateLiquidation(address _account, address _collateralToken, address _indexToken, bool _isLong, bool _raise) external view returns (uint256, uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IFeeUtils {
    function gov() external view returns (address);

    function feeMultiplierIfInactive() external view returns (uint256);
    function isActive() external view returns (bool);

    function setFeeMultiplierIfInactive(uint256 _feeMultiplierIfInactive) external;
    function setIsActive(bool _isActive) external;

    function getLiquidationFeeUsd() external view returns (uint256);
    function getBaseIncreasePositionFeeBps(address _indexToken) external view returns (uint256);
    function getBaseDecreasePositionFeeBps(address _indexToken) external view returns (uint256);

    function getEntryRolloverRate(address _collateralToken) external view returns (uint256);
    function getNextRolloverRate(address _token) external view returns (uint256);
    function getRolloverRates(address _weth, address[] memory _tokens) external view returns (uint256[] memory);
    function updateCumulativeRolloverRate(address _collateralToken) external;

    function getIncreasePositionFee(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _sizeDelta) external view returns (uint256);
    function getDecreasePositionFee(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _sizeDelta) external view returns (uint256);
    function getRolloverFee(address _collateralToken, uint256 _size, uint256 _entryFundingRate) external view returns (uint256);

    function getBuyUsdfFeeBasisPoints(address _token, uint256 _usdfAmount) external view returns (uint256);
    function getSellUsdfFeeBasisPoints(address _token, uint256 _usdfAmount) external view returns (uint256);
    function getSwapFeeBasisPoints(address _tokenIn, address _tokenOut, uint256 _usdfAmount) external view returns (uint256);
    function getFeeBasisPoints(address _token, uint256 _usdfDelta, uint256 _feeBasisPoints, uint256 _taxBasisPoints, bool _increment) external view returns (uint256);
}