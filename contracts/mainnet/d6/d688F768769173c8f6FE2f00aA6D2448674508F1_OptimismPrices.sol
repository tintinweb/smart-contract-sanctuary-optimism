pragma solidity ^0.8.13;
pragma abicoder v2;

import "IVeloPair.sol";
import "IERC20Decimals.sol";
import "Sqrt.sol";
import "Address.sol";

contract OptimismPrices {
    using Sqrt for uint256;

    address public immutable factory;
    bytes32 public immutable initcodeHash;
    uint8 maxHop = 10;

    constructor(address _factory, bytes32 _initcodeHash) {
        factory = _factory;
        initcodeHash = _initcodeHash;
    }

    struct BalanceInfo {
        uint256 bal0;
        uint256 bal1;
        bool isStable;
    }

    struct Path {
        uint8 to_i;
        uint256 rate;
    }

    struct ReturnVal {
        bool mod;
        bool isStable;
        uint256 bal0;
        uint256 bal1;
    }

    struct Arrays {
        uint256[] rates;
        Path[] paths;
        int[] decimals;
        uint8[] visited;
    }

    struct IterVars {
        uint256 cur_rate;
        uint256 rate;
        uint8 from_i;
        uint8 to_i;
        bool seen;
    }

    function _get_bal(IERC20 from, IERC20 to, uint256 in_bal0) internal view returns (ReturnVal memory out) {
        (uint256 b0, uint256 b1) = _getBalances(from, to, false);
        (uint256 b2, uint256 b3) = _getBalances(from, to, true);
        if (b0 > in_bal0 || b2 > in_bal0) {
            out.mod = true;
            if (b0 > b2) {(out.bal0, out.bal1, out.isStable) = (b0,b1,false);}
            else {(out.bal0, out.bal1, out.isStable) = (b2,b3,true);}         
        }
    }

    function getManyRatesWithConnectors(uint8 src_len, IERC20[] memory connectors) external view returns (uint256[] memory rates) {
        uint8 j_max = min(maxHop, uint8(connectors.length - src_len ));
        Arrays memory arr;
        arr.rates = new uint256[]( src_len );
        arr.paths = new Path[]( (connectors.length - src_len ));
        arr.decimals = new int[](connectors.length);

        // Caching decimals of all connector tokens
        {
            for (uint8 i = 0; i < connectors.length; i++){
                arr.decimals[i] = int(uint(connectors[i].decimals()));
            }
        }
         
        // Iterating through srcTokens
        for (uint8 src = 0; src < src_len; src++){
            IterVars memory vars;
            vars.cur_rate = 1;
            vars.from_i = src;
            arr.visited = new uint8[](connectors.length - src_len);
            // Counting hops
            for (uint8 j = 0; j < j_max; j++){
                BalanceInfo memory balInfo = BalanceInfo(0, 0, false);
                vars.to_i = 0;
                // Going through all connectors
                for (uint8 i = src_len; i < connectors.length; i++) {
                    // Check if the current connector has been used to prevent cycles
                    vars.seen = false;
                    {
                        for (uint8 c = 0; c < j; c++){
                            if (arr.visited[c] == i){vars.seen = true; break;}
                        }
                    }
                    if (vars.seen) {continue;}
                    ReturnVal memory out =  _get_bal(connectors[vars.from_i], connectors[i], balInfo.bal0);
                    if (out.mod){
                        balInfo.isStable = out.isStable;
                        balInfo.bal0 = out.bal0;
                        balInfo.bal1 = out.bal1;
                        vars.to_i = i;
                    }
                }

                if (vars.to_i == 0){
                    arr.rates[src] = 0;
                    break;
                }

                if (balInfo.isStable) {vars.rate = _stableRate(connectors[vars.from_i], connectors[vars.to_i], arr.decimals[vars.from_i] - arr.decimals[vars.to_i]);}
                else                  {vars.rate = _volatileRate(balInfo.bal0, balInfo.bal1, arr.decimals[vars.from_i] - arr.decimals[vars.to_i]);} 
               
                vars.cur_rate *= vars.rate;
                if (j > 0){vars.cur_rate /= 1e18;}

                // If from_i points to a connector, cache swap rate for connectors[from_i] : connectors[to_i]
                if (vars.from_i >= src_len){ arr.paths[vars.from_i - src_len] = Path(vars.to_i, vars.rate);}
                // If from_i points to a srcToken, check if to_i is a connector which has already been expanded.
                // If so, directly follow the cached path to dstToken to get the final rate.
                else {
                    if (arr.paths[vars.to_i - src_len].rate > 0){
                        while (true){
                            vars.cur_rate = vars.cur_rate * arr.paths[vars.to_i - src_len].rate / 1e18;
                            vars.to_i = arr.paths[vars.to_i - src_len].to_i;
                            if (vars.to_i == connectors.length - 1) {arr.rates[src] = vars.cur_rate; break;}
                        }
                    }
                }
                arr.visited[j] = vars.to_i;

                // Next token is dstToken, stop
                if (vars.to_i == connectors.length - 1) {arr.rates[src] = vars.cur_rate; break;}
                vars.from_i = vars.to_i;

            }
        }
        return arr.rates;
    }

    // getting prices, while passing in connectors as an array
    // Assuming srcToken is the first entry of connectors, dstToken is the last entry of connectors
    function getRateWithConnectors(IERC20[] memory connectors) external view returns (uint256 rate) {
        uint256 cur_rate = 1;
        uint8 from_i = 0;
        IERC20 dstToken = connectors[connectors.length - 1];

        // Caching decimals of all connector tokens
        int[] memory decimals = new int[](connectors.length);
        for (uint8 i = 0; i < connectors.length; i++){
            decimals[i] = int(uint(connectors[i].decimals()));
        }

        // Store visited connector indices
        uint8[] memory visited = new uint8[](connectors.length);
        uint8 j_max = min(maxHop, uint8(connectors.length));

        for (uint8 j = 0; j < j_max; j++){
            BalanceInfo memory balInfo;
            IERC20 from = connectors[from_i];
            uint8 to_i = 0;
            // Going through all connectors except for srcToken
            for (uint8 i = 1; i < connectors.length; i++) {
                // Check if the current connector has been used to prevent cycles
                bool seen = false;
                for (uint8 c = 0; c < j; c++){
                    if (visited[c] == i){seen = true; break;}
                }
                if (seen) {continue;}
                IERC20 to = connectors[i];
                (uint256 b0, uint256 b1) = _getBalances(from, to, false);
                (uint256 b2, uint256 b3) = _getBalances(from, to, true);

                if (b0 > balInfo.bal0 || b2 > balInfo.bal0) {
                    uint256 bal0; uint256 bal1; bool isStable;
                    if (b0 > b2) {(bal0, bal1, isStable) = (b0,b1,false);}
                    else {(bal0, bal1, isStable) = (b2,b3,true);}
                    balInfo.isStable = isStable;
                    balInfo.bal0 = bal0;
                    balInfo.bal1 = bal1;
                    to_i = i;
                }
            }

            if (to_i == 0){
                return 0;
            }
            if (balInfo.isStable) {rate = _stableRate(from, connectors[to_i], decimals[from_i] - decimals[to_i]);}
            else                  {rate = _volatileRate(balInfo.bal0, balInfo.bal1, decimals[from_i] - decimals[to_i]);} 

            visited[j] = to_i;
            from_i = to_i;
            cur_rate *= rate;
            if (j > 0){cur_rate /= 1e18;}
            if (connectors[to_i] == dstToken) {return cur_rate;}
        }                                                            
        return 0;
    }


    function _volatileRate(uint256 b0, uint256 b1, int dec_diff) internal pure returns (uint256 rate){
        // b0 has less 0s
        if (dec_diff < 0){
            rate = (1e18 * b1) / (b0 * 10**(uint(-dec_diff)));
        }
        // b0 has more 0s
        else{
            rate = (1e18 * 10**(uint(dec_diff)) * b1) / b0;
        }
    }

    function _stableRate(IERC20 t0, IERC20 t1, int dec_diff) internal view returns (uint256 rate){
        uint256 t0_dec = t0.decimals();
        address currentPair = _orderedPairFor(t0, t1, true);
        // newOut in t1
        uint256 newOut = IVeloPair(currentPair).getAmountOut((10**t0_dec), address(t0));

        // t0 has less 0s
        if (dec_diff < 0){
            rate = (1e18 * newOut) / (10**t0_dec * 10**(uint(-dec_diff)));
        }
        // t0 has more 0s
        else{
            rate = (1e18 * (newOut * 10**(uint(dec_diff)))) / (10**t0_dec);
        }
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function _pairFor(IERC20 tokenA, IERC20 tokenB, bool stable) private view returns (address pair) {
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
                hex"ff",
                factory,
                keccak256(abi.encodePacked(tokenA, tokenB, stable)),
                initcodeHash
            )))));
    }

    // returns the reserves of a pool if it exists, preserving the order of srcToken and dstToken
    function _getBalances(IERC20 srcToken, IERC20 dstToken, bool stable) internal view returns (uint256 srcBalance, uint256 dstBalance) {
        (IERC20 token0, IERC20 token1) = srcToken < dstToken ? (srcToken, dstToken) : (dstToken, srcToken);
        address pairAddress = _pairFor(token0, token1, stable);

        // if the pair doesn't exist, return 0
        if(!Address.isContract(pairAddress)) {
            srcBalance = 0;
            dstBalance = 0;
        }
        else {
            (uint256 reserve0, uint256 reserve1,) = IVeloPair(pairAddress).getReserves();
            (srcBalance, dstBalance) = srcToken == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
        }
    }

    // fetch pair from tokens using correct order
    function _orderedPairFor(IERC20 tokenA, IERC20 tokenB, bool stable) internal view returns (address pairAddress) {
        (IERC20 token0, IERC20 token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pairAddress = _pairFor(token0, token1, stable);
    }

    function min(uint8 a, uint8 b) internal pure returns (uint8) {
        return a < b ? a : b;
    }
}

pragma solidity ^0.8.13;

interface IVeloPair {
    function metadata() external view returns (uint dec0, uint dec1, uint r0, uint r1, bool st, address t0, address t1);
    function claimFees() external returns (uint, uint);
    function tokens() external returns (address, address);
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function burn(address to) external returns (uint amount0, uint amount1);
    function mint(address to) external returns (uint liquidity);
    function getReserves() external view returns (uint _reserve0, uint _reserve1, uint _blockTimestampLast);
    function getAmountOut(uint, address) external view returns (uint);
}

pragma solidity ^0.8.13;

interface IERC20 {
    function decimals() external view returns (uint8);
}

pragma solidity ^0.8.13;
pragma abicoder v1;

library Sqrt {
    function sqrt(uint y) internal pure returns (uint z) {
        unchecked {
            if (y > 3) {
                z = y;
                uint x = y / 2 + 1;
                while (x < z) {
                    z = x;
                    x = (y / x + x) / 2;
                }
            } else if (y != 0) {
                z = 1;
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}