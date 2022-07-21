/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-07-20
*/

// Sources flattened with hardhat v2.7.0 https://hardhat.org

// File @openzeppelin/contracts/math/[email protected]

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


// File contracts/optimism/common/math.sol

pragma solidity ^0.7.0;

contract DSMath {
  uint constant WAD = 10 ** 18;
  uint constant RAY = 10 ** 27;

  function add(uint x, uint y) internal pure returns (uint z) {
    z = SafeMath.add(x, y);
  }

  function sub(uint x, uint y) internal virtual pure returns (uint z) {
    z = SafeMath.sub(x, y);
  }

  function mul(uint x, uint y) internal pure returns (uint z) {
    z = SafeMath.mul(x, y);
  }

  function div(uint x, uint y) internal pure returns (uint z) {
    z = SafeMath.div(x, y);
  }

  function wmul(uint x, uint y) internal pure returns (uint z) {
    z = SafeMath.add(SafeMath.mul(x, y), WAD / 2) / WAD;
  }

  function wdiv(uint x, uint y) internal pure returns (uint z) {
    z = SafeMath.add(SafeMath.mul(x, WAD), y / 2) / y;
  }

  function rdiv(uint x, uint y) internal pure returns (uint z) {
    z = SafeMath.add(SafeMath.mul(x, RAY), y / 2) / y;
  }

  function rmul(uint x, uint y) internal pure returns (uint z) {
    z = SafeMath.add(SafeMath.mul(x, y), RAY / 2) / RAY;
  }

  function toInt(uint x) internal pure returns (int y) {
    y = int(x);
    require(y >= 0, "int-overflow");
  }

  function toRad(uint wad) internal pure returns (uint rad) {
    rad = mul(wad, 10 ** 27);
  }
}


// File contracts/optimism/common/interfaces.sol


pragma solidity ^0.7.0;
pragma abicoder v2;

interface TokenInterface {
    function approve(address, uint256) external;
    function transfer(address, uint) external;
    function transferFrom(address, address, uint) external;
    function deposit() external payable;
    function withdraw(uint) external;
    function balanceOf(address) external view returns (uint);
    function decimals() external view returns (uint);
    function totalSupply() external view returns (uint);
}

interface MemoryInterface {
    function getUint(uint id) external returns (uint num);
    function setUint(uint id, uint val) external;
}


interface AccountInterface {
    function enable(address) external;
    function disable(address) external;
    function isAuth(address) external view returns (bool);
    function cast(
        string[] calldata _targetNames,
        bytes[] calldata _datas,
        address _origin
    ) external payable returns (bytes32[] memory responses);
}

interface ListInterface {
    function accountID(address) external returns (uint64);
}

interface InstaConnectors {
    function isConnectors(string[] calldata) external returns (bool, address[] memory);
}


// File contracts/optimism/common/stores.sol


pragma solidity ^0.7.0;

abstract contract Stores {

  /**
   * @dev Return ethereum address
   */
  address constant internal ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /**
   * @dev Return Wrapped ETH address
   */
  address constant internal wethAddr = 0x4200000000000000000000000000000000000006;

  /**
   * @dev Return memory variable address
   */
  MemoryInterface constant internal instaMemory = MemoryInterface(0x3254Ce8f5b1c82431B8f21Df01918342215825C2);

  /**
   * @dev Return InstaList address
   */
  ListInterface internal constant instaList = ListInterface(0x9926955e0Dd681Dc303370C52f4Ad0a4dd061687);

  /**
	 * @dev Returns connectors registry address
	 */
	InstaConnectors internal constant instaConnectors = InstaConnectors(0x127d8cD0E2b2E0366D522DeA53A787bfE9002C14);

  /**
   * @dev Get Uint value from InstaMemory Contract.
   */
  function getUint(uint getId, uint val) internal returns (uint returnVal) {
    returnVal = getId == 0 ? val : instaMemory.getUint(getId);
  }

  /**
  * @dev Set Uint value in InstaMemory Contract.
  */
  function setUint(uint setId, uint val) virtual internal {
    if (setId != 0) instaMemory.setUint(setId, val);
  }
}


// File contracts/optimism/common/basic.sol


pragma solidity ^0.7.0;



abstract contract Basic is DSMath, Stores {

    function convert18ToDec(uint _dec, uint256 _amt) internal pure returns (uint256 amt) {
        amt = (_amt / 10 ** (18 - _dec));
    }

    function convertTo18(uint _dec, uint256 _amt) internal pure returns (uint256 amt) {
        amt = mul(_amt, 10 ** (18 - _dec));
    }

    function getTokenBal(TokenInterface token) internal view returns(uint _amt) {
        _amt = address(token) == ethAddr ? address(this).balance : token.balanceOf(address(this));
    }

    function getTokensDec(TokenInterface buyAddr, TokenInterface sellAddr) internal view returns(uint buyDec, uint sellDec) {
        buyDec = address(buyAddr) == ethAddr ?  18 : buyAddr.decimals();
        sellDec = address(sellAddr) == ethAddr ?  18 : sellAddr.decimals();
    }

    function encodeEvent(string memory eventName, bytes memory eventParam) internal pure returns (bytes memory) {
        return abi.encode(eventName, eventParam);
    }

    function approve(TokenInterface token, address spender, uint256 amount) internal {
        try token.approve(spender, amount) {

        } catch {
            token.approve(spender, 0);
            token.approve(spender, amount);
        }
    }

    function changeEthAddress(address buy, address sell) internal pure returns(TokenInterface _buy, TokenInterface _sell){
        _buy = buy == ethAddr ? TokenInterface(wethAddr) : TokenInterface(buy);
        _sell = sell == ethAddr ? TokenInterface(wethAddr) : TokenInterface(sell);
    }

    function changeEthAddrToWethAddr(address token) internal pure returns(address tokenAddr){
        tokenAddr = token == ethAddr ? wethAddr : token;
    }

    function convertEthToWeth(bool isEth, TokenInterface token, uint amount) internal {
        if(isEth) token.deposit{value: amount}();
    }

    function convertWethToEth(bool isEth, TokenInterface token, uint amount) internal {
       if(isEth) {
            approve(token, address(token), amount);
            token.withdraw(amount);
        }
    }
}


// File contracts/optimism/connectors/synthetix-Future/interface.sol

interface IFuturesMarket {
    function assetPrice() external view returns (uint256 price, bool invalid);

    function baseAsset() external view returns (bytes32 key);

    function remainingMargin(address account) external view returns (uint256 marginRemaining, bool invalid);

    function transferMargin(int256 marginDelta) external;

    function withdrawAllMargin() external;

    function modifyPositionWithTracking(int256 sizeDelta, bytes32 trackingCode) external;
    
    struct TradeParams {
        int sizeDelta;
        uint price;
        uint takerFee;
        uint makerFee;
        bytes32 trackingCode; // optional tracking code for volume source fee sharing
    }
}
interface IExchangeRates {
    function rateAndInvalid(
        bytes32 currencyKey
    ) external view returns (uint rate, bool isInvalid);
}
interface ISynthetix {

    function exchange(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    ) external returns (uint amountReceived);
  
    function exchangeOnBehalf(
        address exchangeForAddress,
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    ) external returns (uint amountReceived);

    function exchangeWithTracking(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint256 amountReceived);

}


// File contracts/optimism/connectors/synthetix-Future/helpers.sol


pragma solidity ^0.7.0;



abstract contract Helpers is DSMath, Basic {
    /**
	 * @dev future market 
	 */
    IFuturesMarket internal constant futureMarket = 
    // TODO: need to find the address and pass here 
        IFuturesMarket(0x834Ef6c82D431Ac9A7A6B66325F185b2430780D7);


    IExchangeRates internal constant exchangeRates = 
     // TODO: need to find the address and pass here 
        IExchangeRates(0xb4dc5ced63C2918c89E491D19BF1C0e92845de7C);


    ISynthetix internal constant synthetix = 
     // TODO: need to find the address and pass here 
        ISynthetix(0x08F30Ecf2C15A783083ab9D5b9211c22388d0564);

    function getSpotPrice(bytes32 currencyKey) 
        internal 
        view 
        returns (uint rate) {
            (uint spotprice,) = exchangeRates.rateAndInvalid(currencyKey);
            return spotprice; 
    }   
    
    function totalMargin(address user)
        internal
        view 
        returns (uint256 marginRemaining) {

        (uint marginRemaining,) = futureMarket.remainingMargin(msg.sender);
        return marginRemaining;
    }

    function underlyingReceivedForOpen(uint amount, bytes32 currencyKey)
        internal
        returns(uint256) 
    {
        uint256 underlyingReceived = synthetix.exchangeWithTracking("sUSD", amount, currencyKey, address(this), "TRACKING_CODE"); 
        return underlyingReceived;
    }
    function underlyingReceivedForClose(uint amount, bytes32 currencyKey)
        internal
        returns(uint256) 
    {
        uint256 underlyingReceived = synthetix.exchangeWithTracking(currencyKey, amount,"sUSD",  address(this), "TRACKING_CODE"); 
        return underlyingReceived;
    }
}


// File contracts/optimism/connectors/synthetix-Future/events.sol

pragma solidity ^0.7.0;

contract Events {
    event MarginTransferred(address indexed account, int marginDelta);

    event PositionModified(
        uint indexed id,
        address indexed account,
        uint margin,
        int size,
        int tradeSize,
        uint lastPrice,
        uint fundingIndex,
        uint fee
    );

    event PositionLiquidated(
        uint indexed id,
        address indexed account,
        address indexed liquidator,
        int size,
        uint price,
        uint fee
    );

    event FundingRecomputed(int funding, uint index, uint timestamp);

    event FuturesTracking(bytes32 indexed trackingCode, bytes32 baseAsset, bytes32 marketKey, int sizeDelta, uint fee);

    event MarketAdded(address market, bytes32 indexed asset, bytes32 indexed marketKey);

    event MarketRemoved(address market, bytes32 indexed asset, bytes32 indexed marketKey);

    
}


// File contracts/optimism/connectors/synthetix-Future/main.sol


pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

/**
 * @title synthetix-future
 * @dev future market
 */

abstract contract SynthetixFutureResolver is DSMath,Events, Helpers {
    function openPosition(
        uint amount, 
        bytes32 currencyKey, 
        uint leverage,
        bool positiontype  // true for long/open and false for short/close
    ) 
    external
    payable

    {
        uint256 spotPrice = getSpotPrice(currencyKey);
        uint256 totalPosition = mul(spotPrice,amount);
        uint256 futuresCost = div(totalPosition,leverage);
        uint256 underlyingReceived = underlyingReceivedForOpen(totalPosition, currencyKey);
        futureMarket.transferMargin(int256(futuresCost));
        if(positiontype == true)
            futureMarket.modifyPositionWithTracking(int(underlyingReceived), bytes32(0));
        else {
            futureMarket.modifyPositionWithTracking(-int(underlyingReceived), bytes32(0));
        }
        
    }


    function closePosition(
        uint amount,
        bytes32 currencyKey,
        bool positiontype // true/open for long and false for short/close
    )
    external
    payable
    {
        uint256 spotPrice = getSpotPrice(currencyKey);
        uint256 sUSDReceived = underlyingReceivedForClose(amount, currencyKey);
        uint256 totalMargin = totalMargin(msg.sender);
        uint256 marginToWithdraw = mul(amount,totalMargin);
        if(positiontype == true)
            futureMarket.modifyPositionWithTracking(-int256(amount), bytes32(0));
        else
            futureMarket.modifyPositionWithTracking(-int256(amount), bytes32(0));
        futureMarket.transferMargin(int256(marginToWithdraw));
    }

    function openBasisTrading(
        uint amount,
        bytes32 currencyKey
    )
    external
    payable 
    {
        uint256 spotPrice = getSpotPrice(currencyKey);
        uint256 basisOpenAmount = div(amount, 2);
        uint256 totalPosition = mul(spotPrice,basisOpenAmount);
        uint256 futuresCost = div(totalPosition,1); //with 1x leverage
        uint256 underlyingReceived = underlyingReceivedForOpen(totalPosition, currencyKey);
        futureMarket.transferMargin(int256(futuresCost));
        futureMarket.modifyPositionWithTracking(-int(underlyingReceived), bytes32(0));
    }
    function closeBasisTrading(
        uint amount, 
        bytes32 currencyKey

    )
    external
    payable
    {
        uint256 spotPrice = getSpotPrice(currencyKey);
        uint256 basisCloseAmount = div(amount,2);
        uint256 sUSDReceived = underlyingReceivedForClose(basisCloseAmount, currencyKey);
        uint256 totalMargin = totalMargin(msg.sender);
        uint256 marginToWithdraw = mul(basisCloseAmount,totalMargin);
        futureMarket.modifyPositionWithTracking(int256(amount), bytes32(0));
    }

}

contract synthetixFuture is SynthetixFutureResolver {
	string public constant name = "SynthetixFuture";
}