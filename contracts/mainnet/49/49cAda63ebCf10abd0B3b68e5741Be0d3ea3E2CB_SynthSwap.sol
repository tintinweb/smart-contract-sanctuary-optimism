// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ISynthSwap.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ISynthetix.sol";
import "./interfaces/IAddressResolver.sol";
import "./interfaces/IAggregationRouterV4.sol";
import "./interfaces/IAggregationExecutor.sol";
import "./utils/SafeERC20.sol";
import "./utils/Owned.sol";
import "./utils/ReentrancyGuard.sol";
import "./libraries/RevertReasonParser.sol";

/// @title system to swap synths to/from many erc20 tokens
/// @dev IAggregationRouterV4 relies on calldata generated off-chain
contract SynthSwap is ISynthSwap, Owned, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 immutable sUSD;
    IAggregationRouterV4 immutable router;
    IAddressResolver immutable addressResolver;
    address immutable volumeRewards;
    address immutable treasury;

    address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    bytes32 private constant CONTRACT_SYNTHETIX = "Synthetix";
    bytes32 private constant sUSD_CURRENCY_KEY = "sUSD";
    bytes32 private constant TRACKING_CODE = "KWENTA";

    event SwapInto(address indexed from, uint amountReceived);
    event SwapOutOf(address indexed from, uint amountReceived);
    event Received(address from, uint amountReceived);
    
    constructor (
        address _sUSD,
        address _aggregationRouterV4,
        address _addressResolver,
        address _volumeRewards,
        address _treasury
    ) Owned(msg.sender) {
        sUSD = IERC20(_sUSD);
        router = IAggregationRouterV4(_aggregationRouterV4);
        addressResolver = IAddressResolver(_addressResolver);
        volumeRewards = _volumeRewards;
        treasury = _treasury;
    }

    //////////////////////////////////////
    ///////// EXTERNAL FUNCTIONS /////////
    //////////////////////////////////////

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /// @inheritdoc ISynthSwap
    function swapInto(
        bytes32 _destSynthCurrencyKey,
        bytes calldata _data
    ) external payable override returns (uint) {
        (uint amountOut,) = swapOn1inch(_data, false);

        // if destination synth is NOT sUSD, swap on Synthetix is necessary 
        if (_destSynthCurrencyKey != sUSD_CURRENCY_KEY) {
            amountOut = swapOnSynthetix(
                amountOut,
                sUSD_CURRENCY_KEY,
                _destSynthCurrencyKey
            );
        }

        address destSynthAddress = proxyForSynth(addressResolver.getSynth(_destSynthCurrencyKey));
        IERC20(destSynthAddress).safeTransfer(msg.sender, amountOut);
  
        emit SwapInto(msg.sender, amountOut);
        return amountOut;
    }

    /// @inheritdoc ISynthSwap
    function swapOutOf(
        bytes32 _sourceSynthCurrencyKey,
        uint _sourceAmount,
        bytes calldata _data
    ) external override nonReentrant returns (uint) {
        // transfer synth to this contract
        address sourceSynthAddress = proxyForSynth(addressResolver.getSynth(_sourceSynthCurrencyKey));
        IERC20(sourceSynthAddress).safeTransferFrom(msg.sender, address(this), _sourceAmount);

        // if source synth is NOT sUSD, swap on Synthetix is necessary 
        if (_sourceSynthCurrencyKey != sUSD_CURRENCY_KEY) {
            swapOnSynthetix(
                _sourceAmount, 
                _sourceSynthCurrencyKey, 
                sUSD_CURRENCY_KEY
            );
        }

        (uint amountOut, address dstToken) = swapOn1inch(_data, true);
        
        if (dstToken == ETH_ADDRESS) {
            (bool success, bytes memory result) = msg.sender.call{value: amountOut}("");
            if (!success) {
                revert(RevertReasonParser.parse(result, "callBytes failed: "));
            }
        } else {
            IERC20(dstToken).safeTransfer(msg.sender, amountOut);
        }
  
        emit SwapOutOf(msg.sender, amountOut);

        // any remaining sUSD in contract should be transferred to treasury
        uint remainingBalanceSUSD = sUSD.balanceOf(address(this));
        if (remainingBalanceSUSD > 0) {
            sUSD.safeTransfer(treasury, remainingBalanceSUSD);
        }

        return amountOut;
    }

    /// @inheritdoc ISynthSwap
    function uniswapSwapInto(
        bytes32 _destSynthCurrencyKey,
        address _sourceTokenAddress,
        uint _amount,
        bytes calldata _data
    ) external payable override returns (uint) {
        // if not swapping from ETH, transfer source token to contract and approve spending
        if (_sourceTokenAddress != ETH_ADDRESS) {
            IERC20(_sourceTokenAddress).safeTransferFrom(msg.sender, address(this), _amount);
            IERC20(_sourceTokenAddress).approve(address(router), _amount);
        }

        // swap ETH or source token for sUSD
        (bool success, bytes memory result) = address(router).call{value: msg.value}(_data);
        if (!success) {
            revert(RevertReasonParser.parse(result, "callBytes failed: "));
        }

         // record amount of sUSD received from swap
        (uint amountOut) = abi.decode(result, (uint));

        // if destination synth is NOT sUSD, swap on Synthetix is necessary 
        if (_destSynthCurrencyKey != sUSD_CURRENCY_KEY) {
            amountOut = swapOnSynthetix(
                amountOut, 
                sUSD_CURRENCY_KEY, 
                _destSynthCurrencyKey
            );
        }

        // send amount of destination synth to msg.sender
        address destSynthAddress = proxyForSynth(addressResolver.getSynth(_destSynthCurrencyKey));
        IERC20(destSynthAddress).safeTransfer(msg.sender, amountOut);
  
        emit SwapInto(msg.sender, amountOut);
        return amountOut;
    }

    /// @inheritdoc ISynthSwap
    function uniswapSwapOutOf(
        bytes32 _sourceSynthCurrencyKey,
        address _destTokenAddress,
        uint _amountOfSynth,
        uint _expectedAmountOfSUSDFromSwap,
        bytes calldata _data
    ) external override nonReentrant returns (uint) {
        // transfer synth to this contract
        address sourceSynthAddress = proxyForSynth(addressResolver.getSynth(_sourceSynthCurrencyKey));
        IERC20(sourceSynthAddress).transferFrom(msg.sender, address(this), _amountOfSynth);

        // if source synth is NOT sUSD, swap on Synthetix is necessary 
        if (_sourceSynthCurrencyKey != sUSD_CURRENCY_KEY) {
            swapOnSynthetix(
                _amountOfSynth, 
                _sourceSynthCurrencyKey, 
                sUSD_CURRENCY_KEY
            );
        }

        // approve AggregationRouterV4 to spend sUSD
        sUSD.approve(address(router), _expectedAmountOfSUSDFromSwap);

        // swap sUSD for ETH or destination token
        (bool success, bytes memory result) = address(router).call(_data);
        if (!success) {
            revert(RevertReasonParser.parse(result, "SynthSwap: callBytes failed: "));
        }

        // record amount of ETH or destination token received from swap
        (uint amountOut) = abi.decode(result, (uint));
        
        // send amount of ETH or destination token to msg.sender
        if (_destTokenAddress == ETH_ADDRESS) {
            (success, result) = msg.sender.call{value: amountOut}("");
            if (!success) {
            revert(RevertReasonParser.parse(result, "SynthSwap: callBytes failed: "));
        }
        } else {
            IERC20(_destTokenAddress).safeTransfer(msg.sender, amountOut);
        }

        emit SwapOutOf(msg.sender, amountOut);

        // any remaining sUSD in contract should be transferred to treasury
        uint remainingBalanceSUSD = sUSD.balanceOf(address(this));
        if (remainingBalanceSUSD > 0) {
            sUSD.safeTransfer(treasury, remainingBalanceSUSD);
        }

        return amountOut;
    }

    /// @notice owner possesses ability to rescue tokens locked within contract 
    function rescueFunds(IERC20 token, uint256 amount) external onlyOwner {
        token.safeTransfer(msg.sender, amount);
    }

    //////////////////////////////////////
    ///////// INTERNAL FUNCTIONS /////////
    //////////////////////////////////////

    /// @notice addressResolver fetches ISynthetix address 
    function synthetix() internal view returns (ISynthetix) {
        return ISynthetix(addressResolver.requireAndGetAddress(
            CONTRACT_SYNTHETIX, 
            "Could not get Synthetix"
        ));
    }

    /// @notice execute swap on 1inch
    /// @dev token approval needed when source is not ETH
    /// @dev either source or destination token will ALWAYS be sUSD
    /// @param _data specifying swap data
    /// @param _areTokensInContract TODO
    /// @return amount received from 1inch swap
    function swapOn1inch(
        bytes calldata _data, 
        bool _areTokensInContract
    ) internal returns (uint, address) {
        // decode _data for 1inch swap
        (
            IAggregationExecutor executor,
            IAggregationRouterV4.SwapDescription memory desc,
            bytes memory routeData
        ) = abi.decode(
            _data,
            (
                IAggregationExecutor,
                IAggregationRouterV4.SwapDescription,
                bytes
            )
        );

        // set swap description destination address to this contract
        desc.dstReceiver = payable(address(this));

        if (desc.srcToken != ETH_ADDRESS) {
            // if being called from swapInto, tokens have not been transfered to this contract
            if (!_areTokensInContract) {
                IERC20(desc.srcToken).safeTransferFrom(msg.sender, address(this), desc.amount);
            }
            // approve AggregationRouterV4 to spend srcToken
            IERC20(desc.srcToken).approve(address(router), desc.amount);
        }

        // execute 1inch swap
        (uint amountOut,) = router.swap{value: msg.value}(executor, desc, routeData);

        require(amountOut > 0, "SynthSwap: swapOn1inch failed");
        return (amountOut, desc.dstToken);
    }

    /// @notice execute swap on Synthetix
    /// @dev token approval is always required
    /// @param _amount of source synth to swap
    /// @param _sourceSynthCurrencyKey source synth key needed for exchange
    /// @param _destSynthCurrencyKey destination synth key needed for exchange
    /// @return amountOut: received from Synthetix swap
    function swapOnSynthetix(
        uint _amount,
        bytes32 _sourceSynthCurrencyKey,
        bytes32 _destSynthCurrencyKey
    ) internal returns (uint) {
        // execute Synthetix swap
        uint amountOut = synthetix().exchangeWithTracking(
            _sourceSynthCurrencyKey,
            _amount,
            _destSynthCurrencyKey,
            volumeRewards,
            TRACKING_CODE
        );

        require(amountOut > 0, "SynthSwap: swapOnSynthetix failed");
        return amountOut;
    }

    /// @notice get the proxy address from the synth implementation contract
    /// @dev only possible because Synthetix synths inherit Proxyable which track proxy()
    /// @param synthImplementation synth implementation address
    /// @return synthProxy proxy address
    function proxyForSynth(address synthImplementation) internal returns (address synthProxy) {
        (bool success, bytes memory retVal) = synthImplementation.call(abi.encodeWithSignature("proxy()"));
        require(success, "get Proxy address failed");
        (synthProxy) = abi.decode(retVal, (address));
    }

}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/iaddressresolver
interface IAddressResolver {
    function getAddress(bytes32 name) external view returns (address);
    function getSynth(bytes32 key) external view returns (address);
    function requireAndGetAddress(bytes32 name, string calldata reason) external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAggregationExecutor {
    /// @notice Make calls on `msgSender` with specified data
    function callBytes(address msgSender, bytes calldata data) external payable; // 0x2636f7f8
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IAggregationExecutor.sol";

interface IAggregationRouterV4 {
    struct SwapDescription {
        address srcToken;
        address dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
        bytes permit;
    }

    function swap(
        IAggregationExecutor caller,
        SwapDescription calldata desc,
        bytes calldata data
    ) external payable returns (uint256 returnAmount, uint256 gasLeft);
}

// SPDX-License-Identifier: MIT

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
    function transferFrom(
        address sender,
        address recipient,
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title SynthSwap
/// @notice 1Inch + Synthetix utlity contract for going into a Synth and out of a Synth
interface ISynthSwap {
    /// @notice swap into a specified synth
    /// @dev supports ETH -> Synth conversions
    /// @param _destSynthCurrencyKey is the bytes32 representation of a Synthetix currency key
    /// @param _data is the transaction data returned by the 1inch API 
    /// @return amount of destination synth received from swap
    function swapInto(
        bytes32 _destSynthCurrencyKey,
        bytes calldata _data
    ) external payable returns (uint);

    /// @notice swap out of a specified synth
    /// @dev make sure synthetix is approved to spend sourceAmount
    /// @dev supports Synth -> ETH conversions
    /// @param _sourceSynthCurrencyKey is the bytes32 representation of a Synthetix currency key
    /// @param _sourceAmount is the amount of sourceSynth to swap out of
    /// @param _data is the transaction data returned by the 1inch API
    /// @return amount of destination asset received from swap
    function swapOutOf(
        bytes32 _sourceSynthCurrencyKey,
        uint _sourceAmount,
        bytes calldata _data
    ) external returns (uint);

    /// @notice swap into a specified synth
    /// @dev supports ETH -> Synth conversions
    /// @param _destSynthCurrencyKey is the bytes32 representation of a Synthetix currency key
    /// @param _sourceTokenAddress is the address of the source token
    /// @param _amount is the amout of source token to be swapped
    /// @param _data is the transaction data returned by the 1inch API 
    /// @return amount of destination synth received from swap
    function uniswapSwapInto(
        bytes32 _destSynthCurrencyKey,
        address _sourceTokenAddress,
        uint _amount,
        bytes calldata _data
    ) external payable returns (uint);

    /// @notice swap out of a specified synth
    /// @dev make sure synthetix is approved to spend sourceAmount
    /// @dev supports Synth -> ETH conversions
    /// @param _sourceSynthCurrencyKey is the bytes32 representation of a Synthetix currency key
    /// @param _amountOfSynth is the amount of sourceSynth to swap out of
    /// @param _expectedAmountOfSUSDFromSwap is expected amount of sUSD to be returned from Synthetix portion of swap
    /// @param _data is the transaction data returned by the 1inch API
    /// @return amount of destination asset received from swap
    function uniswapSwapOutOf(
        bytes32 _sourceSynthCurrencyKey,
        address _destTokenAddress,
        uint _amountOfSynth,
        uint _expectedAmountOfSUSDFromSwap,
        bytes calldata _data
    ) external returns (uint);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISynthetix {
    function exchangeWithTracking(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint amountReceived);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Library that allows to parse unsuccessful arbitrary calls revert reasons.
/// See https://solidity.readthedocs.io/en/latest/control-structures.html#revert for details.
/// Note that we assume revert reason being abi-encoded as Error(string) so it may fail to parse reason
/// if structured reverts appear in the future.
///
/// All unsuccessful parsings get encoded as Unknown(data) string
library RevertReasonParser {
    bytes4 constant private _PANIC_SELECTOR = bytes4(keccak256("Panic(uint256)"));
    bytes4 constant private _ERROR_SELECTOR = bytes4(keccak256("Error(string)"));

    function parse(bytes memory data, string memory prefix) internal pure returns (string memory) {
        if (data.length >= 4) {
            bytes4 selector;
            assembly {  // solhint-disable-line no-inline-assembly
                selector := mload(add(data, 0x20))
            }

            // 68 = 4-byte selector + 32 bytes offset + 32 bytes length
            if (selector == _ERROR_SELECTOR && data.length >= 68) {
                uint256 offset;
                bytes memory reason;
                // solhint-disable no-inline-assembly
                assembly {
                    // 36 = 32 bytes data length + 4-byte selector
                    offset := mload(add(data, 36))
                    reason := add(data, add(36, offset))
                }
                /*
                    revert reason is padded up to 32 bytes with ABI encoder: Error(string)
                    also sometimes there is extra 32 bytes of zeros padded in the end:
                    https://github.com/ethereum/solidity/issues/10170
                    because of that we can't check for equality and instead check
                    that offset + string length + extra 36 bytes is less than overall data length
                */
                require(data.length >= 36 + offset + reason.length, "Invalid revert reason");
                return string(abi.encodePacked(prefix, "Error(", reason, ")"));
            }
            // 36 = 4-byte selector + 32 bytes integer
            else if (selector == _PANIC_SELECTOR && data.length == 36) {
                uint256 code;
                // solhint-disable no-inline-assembly
                assembly {
                    // 36 = 32 bytes data length + 4-byte selector
                    code := mload(add(data, 36))
                }
                return string(abi.encodePacked(prefix, "Panic(", _toHex(code), ")"));
            }
        }

        return string(abi.encodePacked(prefix, "Unknown(", _toHex(data), ")"));
    }

    function _toHex(uint256 value) private pure returns(string memory) {
        return _toHex(abi.encodePacked(value));
    }

    function _toHex(bytes memory data) private pure returns(string memory) {
        bytes16 alphabet = 0x30313233343536373839616263646566;
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 * i + 2] = alphabet[uint8(data[i] >> 4)];
            str[2 * i + 3] = alphabet[uint8(data[i] & 0x0f)];
        }
        return string(str);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

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
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
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
        return functionCall(target, data, "Address: low-level call failed");
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
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
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

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
pragma solidity ^0.8.0;

// https://docs.synthetix.io/contracts/source/contracts/owned
contract Owned {
    address public owner;
    address public nominatedOwner;

    constructor(address _owner) {
        require(_owner != address(0), "Owner address cannot be 0");
        owner = _owner;
        emit OwnerChanged(address(0), _owner);
    }

    function nominateNewOwner(address _owner) external onlyOwner {
        nominatedOwner = _owner;
        emit OwnerNominated(_owner);
    }

    function acceptOwnership() external {
        require(msg.sender == nominatedOwner, "You must be nominated before you can accept ownership");
        emit OwnerChanged(owner, nominatedOwner);
        owner = nominatedOwner;
        nominatedOwner = address(0);
    }

    modifier onlyOwner {
        _onlyOwner();
        _;
    }

    function _onlyOwner() private view {
        require(msg.sender == owner, "Only the contract owner may perform this action");
    }

    event OwnerNominated(address newOwner);
    event OwnerChanged(address oldOwner, address newOwner);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "./Address.sol";

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
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
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
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}