// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MethodInfo, PoolActionInfo, TYPES } from "./directory.sol";
import { BytesTransformer } from "./BytesTransformer.sol";
import { SwapHelper, AllSwapsInfo, SwapType, SwapLocation } from "../Types/SwapTypes.sol";

struct LendingInfo {
    string                  action;
    address                 pool;
    address                 src; 
    address                 dst;
    address                 referral;
    address                 addressId;
    uint256                 id;
    uint256                 deadline;
    uint256                 amount;
}

contract Router is SwapHelper {

    constructor(address _owner) SwapHelper(_owner) {
        
    }

    /* 
        EXTERNAL FUNCTIONS
    */

    /// READ

    function getActionData(
        LendingInfo calldata        _info,
        MethodInfo   calldata       method
    ) external pure returns(bytes memory data) {
        data = _generateCalldata(
            _info,
            _info.amount,
            method
        );
        return data;
    }

    /// WRITE

    /// Schema : 
    /// 1. We swap the tokens or transfer them to the contract if no swap is needed

    /// 2. We generate and call the action

    /// 3. We swap the token to the desired out token (if any) and transfer the result to the action recipient

    function route(
        LendingInfo calldata         _info,
        PoolActionInfo calldata      poolActionInfo,
        MethodInfo calldata          method,
        AllSwapsInfo calldata        swaps
    ) public payable {
        bool success;


        address tokenInMainOperation = poolActionInfo.inTokens[0];
        address tokenOutMainOperation = poolActionInfo.outTokens[0];

        // 1.
        _transferToContract(swaps.swapLocation, swaps.swaps[0], tokenInMainOperation, _info.amount);
        uint256 amount = _swapAndApprove(swaps.swapLocation, swaps.swaps[0], tokenInMainOperation, _info.amount, poolActionInfo.interactionAddress);
        //

        //2. 
        bytes memory callData = _generateCalldata(
            _info,
            amount,
            method
        );

        if(tokenInMainOperation == nativeToken){
            (success, ) = address(poolActionInfo.interactionAddress).call{value: msg.value}(callData);
        }else{
            (success, ) = address(poolActionInfo.interactionAddress).call(callData);
        }

        // 3.
        _transferOrSwapAfter(swaps.swapLocation,swaps.swaps[0], tokenOutMainOperation, _info.dst);
        require(success,  "Routing error occured");
    }

    function sweep(address _token, address _dst) external onlyOwner {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_dst, amount);
    }

    /// @dev Callback for receiving Ether when the calldata is empty
    receive() external payable {}


    /* 
        INTERNAL FUNCTIONS
    */

    function _generateCalldata(
        LendingInfo calldata    _info,
        uint256                 _amount,
        MethodInfo calldata     method

    ) private pure returns (bytes memory) {
        /// prepare the args in bytes32 to adapt to varying args of external methods
        bytes32[7] memory args = [
            BytesTransformer.uintToBytes32(_amount),
            BytesTransformer.uintToBytes32(_info.deadline),
            BytesTransformer.uintToBytes32(_info.id),
            BytesTransformer.addressToBytes32(_info.addressId),
            BytesTransformer.addressToBytes32(_info.src),
            BytesTransformer.addressToBytes32(_info.dst),
            BytesTransformer.addressToBytes32(_info.referral)
        ];
        /// calculate the position where dynamic elements start in the bytes array
        uint256 stringOffset = method.argc * 32;
        /// calculate the position where static elements start in the bytes array, 32 + 4 as the function selector is bytes4
        uint256 offset = 36;
        /// calculate the size of the bytes array and allocate the bytes array -- 2
        uint256 bSize = 4 + stringOffset + method.argcArray * 64;
        bytes memory result = new bytes(bSize);
        /// concat the function selector of the method at the first position of the bytes array -- 3
        bytes4 selector = BytesTransformer.fnSelector(method.methodName);
        assembly {
            mstore(add(result, 32), selector)
        }
        /// loop through all the arguments of the method to add them to the calldata
        for (uint256 i = 0; i < method.argc; i++) {
            /// get the position of the arg in the method and the input arg in bytes32
            uint256 position = method.argv[i];
            /// check if the arg is a string as it is dynamic data
            /// In that case we need to indicate 3 arguments
            /// 1. At the normal location of the argument, we need to specify where the array is stored
            /// 2. The array storage space starts with the array length (here it's always 32 bits)
            /// 3. The array storage
            if (method.argvType[i] == TYPES.ARRAY) {
                /// if arg string/array get the value that must be put on the bytes array at the right position 
                bytes32 len = BytesTransformer.uintToBytes32(1);
                bytes32 elem = args[position];
                bytes32 stringStartPos = BytesTransformer.uintToBytes32(stringOffset);
                assembly {
                    /// write the bytes32 value of the position as the call argument
                    mstore(add(result, offset), stringStartPos)
                    /// write 32 (the string / array length is 32 bytes max) at the (offset position) for the len of the string
                    mstore(add(result, stringOffset), len)
                    /// write the contenf of the array at the (offset position + 32)
                    mstore(add(result, add(stringOffset, 32)), elem)
                }
                /// stringoffset to write the next 2 bytes32 at the right position if there is another string arg  
                stringOffset += 64;
            } else {
                /// if arg not a string, concat the element to offset position of the bytes array
                bytes32 elem = args[position];
                assembly {
                    mstore(add(result, offset), elem)
                }
            }
            /// offset to write the next bytes32 arg during the next loop
            offset += 32;
        }
        return result;
    }

    /// OTHERS

    function _internalSweep(address _token, address _dst) internal {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        if (amount > 0) {
            IERC20(_token).transfer(_dst, amount);
        }
    }

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


uint256 constant ammArgLength = 12;


enum TYPES {
    ADDRESS,                // 0
    UINT256,                // 1
    STRING,                 // 2
    BYTES32,                // 3
    BOOL,                   // 4
    ARRAY                   // 5
}

//      Lending Order
//     _uintToBytes32(_amount),               // 0
//     _uintToBytes32(_deadline),             // 1
//     _uintToBytes32(_id),                   // 2
//     _addressToBytes32(_addressId),         // 3  
//     _addressToBytes32(_src),               // 4      
//     _addressToBytes32(_dst),               // 5
//     _addressToBytes32(_referral)           // 6

//      AMM Order
// BytesTransformer.addressToBytes32(_info.tokens[0]),                  // 0
// BytesTransformer.addressToBytes32(_info.tokens[1]),                  // 1
// BytesTransformer.uintToBytes32(_info.amountsDesired[0]),             // 2 
// BytesTransformer.uintToBytes32(_info.amountsDesired[1]),             // 3
// BytesTransformer.uintToBytes32(_info.amountsMinimum[0]),             // 4 
// BytesTransformer.uintToBytes32(_info.amountsMinimum[1]),             // 5
// BytesTransformer.uintToBytes32(_info.minAmountOut),                  // 6
// BytesTransformer.addressToBytes32(_info.src),                        // 7
// BytesTransformer.addressToBytes32(_info.dst),                        // 8
// BytesTransformer.addressToBytes32(_info.referral),                   // 9
// BytesTransformer.uintToBytes32(_info.deadline)                       // 10
// _info.rawBytes                                                       // 11

// tokens[i] = BytesTransformer.addressToBytes32(_info.tokens[i]);
// desired[i] = BytesTransformer.uintToBytes32(_info.amountsDesired[i]);
// minimum[i] = BytesTransformer.uintToBytes32(_info.amountsMinimum[i]);

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
    string                                                  name;
    string                                                  protocol;
}

///Methods
struct MethodInfo {
    address                                                 interactionAddress;
    bool                                                    locked;
    bool                                                    custodian;   
    uint256                                                 argc;
    uint256                                                 argcArray;
    uint256                                                 inNum;
    uint256                                                 outNum;   
    uint256[ammArgLength]                                   argv;  
    TYPES[ammArgLength]                                     argvType;
    address[5]                                              inTokens;
    address[5]                                              outTokens; 
    string                                                  methodName;             
}

struct PoolActionInfo {
    bool                    custodian;
    address                 customAddress;
    address                 interactionAddress;
    address[5]              inTokens;
    address[5]              outTokens;
}

struct ConnectorCalldata {
    string                  action;
    address                 pool;
    address                 src;
    address                 dst;
    address                 referral;
    address                 addressId;
    uint256                 id;
    uint256                 deadline;
    uint256                 amount;
    address                 interactionAddress;
    address[5]              inTokens;
    address[5]              outTokens;
}


// ideas

// interface IArgs {
//         address         user, 0 
//         address         receiver, 1
//         address         referral, 2
//         uint256         amount, 3
// }

// keep several mapping or one mapping string => argsStruct?
// struct ProtocolStruct {
//     bool                                                proxy;
//     bool                                                custom;
//     // string                                              functionName; // no need if we develop a specific connector
//     address                                             customAddress;
//     mapping(string => string)                           methodNames;   
//     mapping(string => uint256)                          methodArgsNumbers;
//     mapping(string => uint256)                          methodNumStringArgs;
//     // mapping(string => mapping(uint256 => uint256))      methodArgs;
//     mapping(string => uint256[])                        methodArgs; //-- array to avoid recoming
//     // mapping(string => mapping(uint256 => string))       methodArgsTypes; 
//     mapping(string => string[])                         methodArgsTypes; //-- array to avoid recoming
//     // mapping(uint256 => uint256)     functionArgs;  // to delete?            
// }
// mapping(string  => ProtocolStruct) private                  data;

// struct ProtocolStruct {
//     bool                                                proxy;
//     bool                                                custom;
//     // string                                           functionName; // no need if we develop a specific connector
//     address                                             customAddress;
//     string[10][10]                                      methodNames;   
//     uint256[10][10]                                     methodArgsNumbers;
//     uint256[10][10]                                     methodNumStringArgs;
//     // mapping(string => mapping(uint256 => uint256))      methodArgs;
//     uint256[10][10]                                     methodArgs; //-- array to avoid recoming
//     // mapping(string => mapping(uint256 => string))       methodArgsTypes; 
//     uint256[10][10]                                     methodArgsTypes; //-- array to avoid recoming
//     // mapping(uint256 => uint256)     functionArgs;  // to delete?            
// // }
//
// enum TYPES {
//     ADDRESS,                // 0
//     UINT256,                // 1
//     STRING,                 // 2
//     BYTES32,                // 3
//     BOOL,                   // 4
//     ARRAY                   // 5
//     ADDRESS_ARRAY,          // 5
//     UINT256_ARRAY,          // 6
//     STRING_ARRAY,           // 7
//     BYTES32_ARRAY,          // 8
//     BOOL_ARRAY,             // 9
// }

/// show that 14 is working
// pragma solidity ^0.8.7;

// struct MethodInfo {
//     uint256[14]                                          argv;  
//     uint256[14]                                          argvType;            
// }


// contract Hello {
//     mapping(string  => MethodInfo) private                                info;

//     function addInfo(
//         string calldata             _protocol,
//         uint256[14] calldata        _argv,
//         uint256[14] calldata        _argvType
//     ) external {
//         info[_protocol].argv = _argv;
//         info[_protocol].argvType = _argvType;
//     }
// }
//
// enum TOKEN_TYPE {
//     ERC20
// }
//// struct PoolMethodInfo {
//     bool                                                locked;
//     ACTION[8]                                           actions;
//     uint256[8]                                          inNum;
//     uint256[8]                                          outNum; 
//     address[8][10]                                      inTokens;
//     address[8][10]                                      outTokens;
// }

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
    SwapLocation swapLocation;
    uint256     swapInAmount; // This is redundant, but helps us for the multiple swap case.
    address     tokenToTransfer;
    SwapInfo[] swaps;
}

struct SwapInfo {
    SwapType                swapType;
    address                 inToken; // The token you want to swap
    address                 outToken;
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

    constructor(address _owner) WithOwner(_owner){
    }

    /// Owner functions
    function registerSwaps(SwapType[] calldata _swapTypes, address[] calldata _routers) public onlyOwner{
        for(uint256 i=0;i<_swapTypes.length;i++){
            swapRouters[_swapTypes[i]] = _routers[i];
        }
    }


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
            if(_swapInfo.inToken != nativeToken){
                IERC20(_swapInfo.inToken).transferFrom(msg.sender, address(this), _swapInfo.inAmount);
            }
        }else{
            if(tokenInMainOperation != nativeToken){
                IERC20(tokenInMainOperation).transferFrom(msg.sender, address(this),  inAmountMainOperation);
            }
        }
    }


    function    _swapAndApprove(SwapLocation swapLocation, SwapInfo calldata _swapInfo, address tokenInMainOperation, uint256 inAmountMainOperation, address interactionAddress) internal returns (uint256 amount){
        // 1.b
        if(swapLocation == SwapLocation.BEFORE_ACTION && _swapInfo.swapType != SwapType.None){
            // 1.b.i - We swap if necessary
            amount = _swap(_swapInfo, address(this), SwapLocation.BEFORE_ACTION);
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
            _swapInfo.inAmount = _balanceOf(_swapInfo.inToken,address(this));
            _swap(_swapInfo, recipient, SwapLocation.AFTER_ACTION);
        }else{
            uint256 amountToSweep = _balanceOf(tokenOutMainOperation, address(this));
            if(amountToSweep != 0){
                IERC20(tokenOutMainOperation).transfer(recipient, amountToSweep);
            }
        }
    }


    // OLD
    function _OLDswapUniswapV3(SwapInfo memory _swapInfo, address _recipient) internal returns(bool success, uint256 swapAmount) {
        if(_swapInfo.inToken == nativeToken){
            swapAmount = IUniswapV3Router(swapRouters[SwapType.UniswapV3]).exactInput{value: _swapInfo.inAmount}(
                ExactInputParams(_swapInfo.args, _recipient, block.timestamp, _swapInfo.inAmount, _swapInfo.minOutAmount)
            );
        }else{
            swapAmount = IUniswapV3Router(swapRouters[SwapType.UniswapV3]).exactInput(
                ExactInputParams(_swapInfo.args, _recipient, block.timestamp, _swapInfo.inAmount, _swapInfo.minOutAmount)
            );
        }
        success = true;
    }

    function _swapUniswapV3(SwapInfo memory _swapInfo, address _recipient) internal returns(bool success, uint256 swapAmount) {
        
        ExactInputSingleParams memory params = ExactInputSingleParams({
            tokenIn: _swapInfo.inToken,
            tokenOut: _swapInfo.outToken,
            fee: _swapInfo.feeTier,
            recipient: _recipient,
            deadline: block.timestamp,
            amountIn: _swapInfo.inAmount,
            amountOutMinimum: _swapInfo.minOutAmount,
            sqrtPriceLimitX96: 0
        });
        if(_swapInfo.inToken == nativeToken){
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

    function _swap(SwapInfo memory _swapInfo, address _recipient, SwapLocation _swapLocation) internal returns(uint256 amount) {
        bool success = true;


        if(_swapInfo.swapType == SwapType.None){
            revert("Inaccessible error");
        }
        address routerAddress = swapRouters[_swapInfo.swapType];
        // If we have an ERC20 Token, we need to approve the contract that will execute the swap
        if(_swapInfo.inToken != nativeToken){

            // We approve for the max amount once 
            // This is similar to :
            // (https://github.com/AngleProtocol/angle-core/blob/53c9d93eb1adf4fda4be8bd5b2ea09f237a6b408/contracts/router/AngleRouter.sol#L1364)
            approveIfNecessary(routerAddress,_swapInfo.inToken);
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
            (success, amount) = _swapUniswapV3(_swapInfo, _recipient);
        }
        require(success, "Error when swapping tokens");
    }

    function approveIfNecessary(address contractAddress, address token) internal {
        if(!tokensApproved[contractAddress][token]){
            IERC20(token).approve(contractAddress, type(uint256).max);
            tokensApproved[contractAddress][token] = true;
        }
    }
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