// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BytesTransformer } from "./BytesTransformer.sol";
import { SwapHelper, AllSwapsInfo, SwapType, SwapLocation } from "../Types/SwapTypes.sol";

import { MethodInfo, CallInfo, TYPES } from "./directory.sol";

/** @title A router for interacting with lending protocols
 *  @author Thomas - Nicolas
 *  @notice This contract is used for creating calldata to interact with lending protocols.
 *      The backend will generate callInfo parameters.
 *  @dev We don't use the directory structure in this contract to simplify tests and integration
 */
contract Router is SwapHelper {

    constructor(address _owner) SwapHelper(_owner) {}

    /* 
        EXTERNAL FUNCTIONS - WRITE
    */

    /// @notice Facilitates entry/exit in a liquidity pool for a user.
    /// 
    /// @dev This function needs only 2 input parameters in the directory case
    /// The method parameter could be queried from additional pool + method arguments, that could be stored in callInfo
    /// @param _callInfo The parameters that will be serialized alongside the called method. 
    ///    This parameter will change everytime a user wants to do an action and should stay as an parameter
    /// @param method Describes the method that will be called by the contract. This parameter could be saved on-chain
    /// @param swaps Describes which swaps the user wants to do before/after executing the main action

    /// @custom:execution-schema
    /// 1. We swap the tokens or transfer them to the contract if no swap is needed
    /// 2. We generate and call the action
    /// 3. We swap the token to the desired out token (if any) and transfer the result to the action recipient

    function route(
        CallInfo memory              _callInfo,
        MethodInfo calldata          method,
        AllSwapsInfo calldata        swaps
    ) public payable {
        bool success;


        address tokenInMainOperation = method.inTokens[0];
        address tokenOutMainOperation = method.outTokens[0];

        // 1.
        _transferToContract(
            swaps.swapLocation, 
            swaps.swaps[0],
            tokenInMainOperation, 
            _callInfo.intArguments[method.amountPositions[0]]
        );
        _callInfo.intArguments[method.amountPositions[0]] = _swapAndApprove(
            swaps.swapLocation, 
            swaps.swaps[0], 
            tokenInMainOperation, 
            _callInfo.intArguments[method.amountPositions[0]], 
            method.interactionAddress
        );
        //

        //2. 
        bytes memory callData = _generateCalldata(
            _callInfo,
            method
        );

        if(tokenInMainOperation == nativeToken){
            (success, ) = address(method.interactionAddress).call{value: msg.value}(callData);
        }else{
            (success, ) = address(method.interactionAddress).call(callData);
        }

        // 3.
        _transferOrSwapAfter(swaps.swapLocation,swaps.swaps[0], tokenOutMainOperation, msg.sender);
        require(success,  "Routing error occured");
    }

    /* 
        INTERNAL FUNCTIONS
    */

    /// @notice Generates the calldata needed to complete a call
    ///     This function generates the calldata for a contract interaction using : 
    ///         1. Method specific information (methodName, argument types, argument order)
    ///         2. Data sent by the user to fill the method arguments
    /// @dev This was developped following the ABI specifications
    ///     https://docs.soliditylang.org/en/v0.8.18/abi-spec.html#abi
    /// @param _callInfo The parameters that will be serialized alongside the called method. 
    ///    This parameter will change everytime a user wants to do an action and should stay as an parameter
    /// @param method Describes the method that will be called by the contract. This parameter could be saved on-chain
    function _generateCalldata(
        CallInfo memory    _callInfo,
        MethodInfo calldata     method
    ) private pure returns (bytes memory) {

        uint256 stringOffset = method.argv.length * 32;
        uint256 offset = 36;
        uint256 bSize = 4 + stringOffset + method.argcArray * 64;
        bytes memory result = new bytes(bSize);
        bytes4 selector = BytesTransformer.fnSelector(method.methodName);
        assembly {
            mstore(add(result, 32), selector)
        }
        for (uint256 i = 0; i < method.argv.length; i++) {
            uint256 position = method.argv[i].argv;
            TYPES argType = method.argv[i].argType;
            // We serialize the arg
            bytes32 elem;
            if(argType == TYPES.ADDRESS){
                elem = BytesTransformer.addressToBytes32(_callInfo.addressArguments[position]);
            }else if(argType == TYPES.UINT256){
                elem = BytesTransformer.uintToBytes32(_callInfo.intArguments[position]);
            }else if(argType == TYPES.STRING){
                elem = BytesTransformer.stringToBytes32(_callInfo.stringArguments[position]);
            }else if(argType == TYPES.BYTES32){
                elem = _callInfo.bytes32Arguments[position];
            }else if(argType == TYPES.BOOL){
                elem = BytesTransformer.boolToBytes32(_callInfo.boolArguments[position]);
            }

            assembly {
                mstore(add(result, offset), elem)
            }
            offset += 32;
        }
        return result;
    }

    /// @dev Callback for receiving Ether when the calldata is empty
    receive() external payable {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

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
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

library BytesTransformer {
    function fnSelector(string memory _method) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(_method)));
    }

    function addressToBytes32(address addr) internal pure returns (bytes32) { 
        bytes memory tmp = new bytes(32);
        bytes32 result;
        assembly {
            mstore(add(tmp, 32), addr)
            result := mload(add(tmp, 32))
        }
        return result;
    }
    
    function uintToBytes32(uint256 _num) internal pure returns (bytes32) {
        return bytes32(_num);
    }

    function boolToBytes32(bool _b) internal pure returns (bytes32) {
        uint256 number = _b ? uint(1) : uint(0);
        return bytes32(number);
    }
    
    function strlenBytes32(string memory _str) internal pure returns (bytes32) {
        uint256 len = bytes(_str).length; 
        return bytes32(len);
    }

    function stringToBytes32(string memory _src) internal pure returns (bytes32 res) {
        if (bytes(_src).length == 0) {
            return 0x0;
        }
        assembly {
            res := mload(add(_src, 32))
        }
    }

    function bytesToUint256(bytes memory _bs) internal pure returns (uint256 value) {
        require(_bs.length == 32, "bytes length is not 32.");
        assembly {
            // load 32 bytes from memory starting from position _bs + 32
            value := mload(add(_bs, 0x20))
        }
        require(value <= 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, "Value exceeds the range");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Router, ExactInputSingleParams, ExactInputParams} from "../Interfaces/external/IUniswapRouter.sol";
import {WithOwner} from "./WithOwner.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

enum SwapLocation {
    NONE,
    BEFORE_ACTION,
    AFTER_ACTION
}

enum SwapType {
    None,           //0
    UniswapV3,      //1
    OneInch,        //2
    ZeroX           //3
}

struct AllSwapsInfo{
    uint256         swapInAmount; // This is redundant, but helps us for the multiple swap case.
    address         tokenToTransfer;
    SwapLocation    swapLocation;
    SwapInfo[]      swaps;
}

struct SwapInfo {
    SwapType                swapType;
    address                 swapToken; // The token you want to swap (for in case of a BEFORE swap, or to in case of an after swap)
    uint256                 inAmount; // The amount of tokens you want to swap
    uint256                 minOutAmount;
    uint256                 value;
    // For OneInch and ZeroX, we get the callData and contractAddress to execute the swap
    bytes                   args;
    // For Uniswapv3, this variable gives the fee that must be paid (usually 3000 = 0.3% or 1000 = 0.1%)
    uint24                  feeTier;
}

abstract contract SwapHelper is WithOwner{
    address constant nativeToken = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    // Mapping of router type to router address
    mapping(SwapType => address) swapRouters;

    mapping(address => mapping(address => bool)) public tokensApproved;

    constructor(address _owner) WithOwner(_owner){}

    /// Owner functions
    function registerSwaps(SwapType[] calldata _swapTypes, address[] calldata _routers) public onlyOwner{
        for(uint256 i=0;i<_swapTypes.length;i++){
            swapRouters[_swapTypes[i]] = _routers[i];
        }
    }

    /// Logic

    function _balanceOf(address _contract, address _user) internal view returns (uint256 balance){
        if(_contract == nativeToken){
            balance = _user.balance;
        }else{
            balance = IERC20(_contract).balanceOf(_user);
        }
    }


    // tokenInMainOperation is the token that will go into the main function
    /// 1.a We transfer a token to the contract in any case (the swap token or the token to provide to the main operation)
    /// 1.b We execute the swap if necessary and get the total amount of tokens available for the main operation in any case
    /// 1.c If the in token for the main operation is not a native token, we need to approve it for the next operation

    function _transferToContract(SwapLocation swapLocation, SwapInfo calldata _swapInfo, address tokenInMainOperation, uint256 inAmountMainOperation) internal {
        // 1.a 
        if(swapLocation == SwapLocation.BEFORE_ACTION && _swapInfo.swapType != SwapType.None){
            if(_swapInfo.swapToken != nativeToken){
                IERC20(_swapInfo.swapToken).transferFrom(msg.sender, address(this), _swapInfo.inAmount);
            }
        }else{
            if(tokenInMainOperation != nativeToken){
                IERC20(tokenInMainOperation).transferFrom(msg.sender, address(this),  inAmountMainOperation);
            }
        }
    }


    function  _swapAndApprove(SwapLocation swapLocation, SwapInfo calldata _swapInfo, address tokenInMainOperation, uint256 inAmountMainOperation, address interactionAddress) internal returns (uint256 amount){
        // 1.b
        if(swapLocation == SwapLocation.BEFORE_ACTION && _swapInfo.swapType != SwapType.None){
            // 1.b.i - We swap if necessary
            amount = _swap(_swapInfo, address(this), _swapInfo.swapToken, tokenInMainOperation, SwapLocation.BEFORE_ACTION);
            // When providing swapInfo.args, you have to make sure that the destination asset is equal to tokenInMainOperation
        }else {
            // 1.b.ii - Or we simply register the inAmount that we want to transfer
            amount = inAmountMainOperation;
        }

        // 1.c
        if (tokenInMainOperation != nativeToken) {
            approveIfNecessary(interactionAddress, tokenInMainOperation);
        }
    }


    function _transferOrSwapAfter(SwapLocation swapLocation, SwapInfo memory _swapInfo, address tokenOutMainOperation, address recipient) internal{
        if(swapLocation == SwapLocation.AFTER_ACTION && _swapInfo.swapType != SwapType.None){
            // 3.a
            _swapInfo.inAmount = _balanceOf(tokenOutMainOperation,address(this));
            _swap(_swapInfo, recipient, tokenOutMainOperation, _swapInfo.swapToken, SwapLocation.AFTER_ACTION);
        }else{
            uint256 amountToSweep = _balanceOf(tokenOutMainOperation, address(this));
            if(amountToSweep != 0){
                IERC20(tokenOutMainOperation).transfer(recipient, amountToSweep);
            }
        }
    }

    function _swapUniswapV3(SwapInfo memory _swapInfo, address inToken, address outToken, address _recipient) internal returns(bool success, uint256 swapAmount) {
        
        ExactInputSingleParams memory params = ExactInputSingleParams({
            tokenIn: inToken,
            tokenOut: outToken,
            fee: _swapInfo.feeTier,
            recipient: _recipient,
            deadline: block.timestamp,
            amountIn: _swapInfo.inAmount,
            amountOutMinimum: _swapInfo.minOutAmount,
            sqrtPriceLimitX96: 0
        });
        if(inToken == nativeToken){
            swapAmount = IUniswapV3Router(swapRouters[SwapType.UniswapV3]).exactInputSingle{value: _swapInfo.inAmount}(
                params 
            );
        }else{
            swapAmount = IUniswapV3Router(swapRouters[SwapType.UniswapV3]).exactInputSingle(
                params
            );
        }
        success = true;
    }

    function _swap(SwapInfo memory _swapInfo, address _recipient, address inToken, address outToken, SwapLocation _swapLocation) internal returns(uint256 amount) {
        bool success = true;


        if(_swapInfo.swapType == SwapType.None){
            revert("Inaccessible error");
        }
        address routerAddress = swapRouters[_swapInfo.swapType];
        // If we have an ERC20 Token, we need to approve the contract that will execute the swap
        if(inToken!= nativeToken){
            // We approve for the max amount once 
            // This is similar to :
            // (https://github.com/AngleProtocol/angle-core/blob/53c9d93eb1adf4fda4be8bd5b2ea09f237a6b408/contracts/router/AngleRouter.sol#L1364)
            approveIfNecessary(routerAddress, inToken);
        }

        // OneInch and ZeroX swaps works in the same way
        if(_swapInfo.swapType == SwapType.OneInch || _swapInfo.swapType == SwapType.ZeroX){
            if(_swapLocation == SwapLocation.BEFORE_ACTION){
                // All swaps are possible before the operation because the API is accessible simply
                bytes memory returnBytes;
                (success, returnBytes) = swapRouters[_swapInfo.swapType].call{value: _swapInfo.value}(_swapInfo.args);
                amount = abi.decode(returnBytes, (uint256));
            } else if(_swapLocation == SwapLocation.AFTER_ACTION){
                revert("Invalid SwapType");
            }
        }else if (_swapInfo.swapType == SwapType.UniswapV3){
            // UniswapV3 swap can be done at any time
            (success, amount) = _swapUniswapV3(_swapInfo, inToken, outToken, _recipient);
        }

        require(success, "Error when swapping tokens");
    }

    function approveTokenForContract(address contractAddress, address token) public {
        IERC20(token).approve(contractAddress, type(uint256).max);
        tokensApproved[contractAddress][token] = true;
    }

    function approveIfNecessary(address contractAddress, address token) internal {
        if(!tokensApproved[contractAddress][token]){
            approveTokenForContract(contractAddress, token);
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;


///Methods
enum TYPES {
    ADDRESS,                // 0
    UINT256,                // 1
    STRING,                 // 2
    BYTES32,                // 3
    BOOL,                   // 4
    ARRAYAddress,           // 5
    ARRAYUint               // 6
}

enum ACTION {
    DEPOSIT,                // 0
    REDEEM,                 // 1
    STAKE,                  // 2
    UNSTAKE,                // 3
    BOOST,                  // 4
    UNBOOST,                // 5
    CLAIM_REWARDS,          // 6
    CLAIM_INTERESTS         // 7
}

///Protocol Information
struct ProtocolInfo {
    bool                                                    locked;
    bool                                                    proxy;
    address                                                 customAddress;
    address                                                 idGetter;
    string                                                  idFuncName;
    PoolInfo[]                                              pools;
}

///Pool Information
struct PoolInfo {
    bool                                                    locked;
    address                                                 investingAddress;
    address                                                 stakingAddress;
    address                                                 boostingAddress;
    address                                                 distributorAddress;
    address[5]                                              underlyingTokens;
    address[5]                                              rewardsTokens;
}


struct MethodInfo {
    address                                                 interactionAddress;   
    uint256                                                 argcArray;
    InputArguments[]                                        argv;
    uint256[]                                               amountPositions;  
    address[]                                               inTokens;
    address[]                                               outTokens; 
    string                                                  methodName;             
}
struct InputArguments {
    TYPES argType;                 // type array to consider (ex 0 == addressArguments)
    uint256 argv;                  // Position in type array
}

struct CallInfo {
    address[]                           addressArguments;
    uint256[]                           intArguments;
    string[]                            stringArguments;
    bool[]                              boolArguments;
    bytes32[]                           bytes32Arguments;
    address[][]                         addressArrayArguments;
    uint256[][]                         intArrayArguments;
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

struct ExactInputParams {
    bytes path;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
}

struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface IUniswapV3Router {
    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

/// @title Router for price estimation functionality
/// @notice Functions for getting the price of one token with respect to another using Uniswap V2
/// @dev This interface is only used for non critical elements of the protocol
interface IUniswapV2Router {
    /// @notice Given an input asset amount, returns the maximum output amount of the
    /// other asset (accounting for fees) given reserves.
    /// @param path Addresses of the pools used to get prices
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);

    function swapExactTokensForTokens(
        uint256 swapAmount,
        uint256 minExpected,
        address[] calldata path,
        address receiver,
        uint256 swapDeadline
    ) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;


contract WithOwner{

	address owner;

	constructor(address  _owner){
		owner = _owner;
	}

    /* 
        MODIFIERS
    */

    modifier onlyOwner() {
        require(msg.sender == owner, "Sender not owner");
        _;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}