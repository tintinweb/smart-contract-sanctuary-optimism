/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-13
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

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

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom( address sender, address recipient,uint256 amount ) external returns (bool);
}

interface CTokenInterface {

    function getCash() external view returns (uint256);
    function decimals() external view returns (uint8);
    function underlying() external view returns (address);

}

interface StakingRewardsInterface {

    function paused() external view returns (bool);

}




interface StakingRewardsHelperInterface {

    struct UserStaked {
        address stakingTokenAddress;
        uint256 balance;
    }
    function getUserStaked(address account) external view returns (UserStaked[] memory);

}




interface IVaultInterface {
     function execute(address, bytes memory)
        external
        payable
        returns (bytes memory);
}


interface  IrBankOracleInterface {
    function getUnderlyingPrice(address cToken) external  view returns (uint256);  
}


interface IStdReference {
    /// A structure returned whenever someone requests for standard reference data.
    struct ReferenceData {
        uint256 rate; // base/quote exchange rate, multiplied by 1e18.
        uint256 lastUpdatedBase; // UNIX epoch of the last time when base price gets updated.
        uint256 lastUpdatedQuote; // UNIX epoch of the last time when quote price gets updated.
    }

    /// Returns the price data for the given base/quote pair. Revert if not available.
    function getReferenceData(string memory _base, string memory _quote)
        external
        view
        returns (ReferenceData memory);

    /// Similar to getReferenceData, but with multiple base/quote pairs at once.
    function getReferenceDataBulk(string[] memory _bases, string[] memory _quotes)
        external
        view
        returns (ReferenceData[] memory);
}




contract IrBankMonitor  {

    using SafeMath for uint256;
    address public irBankStrategy;
    address public stakeRewardsHelper;
    address public irbankOracle;
    address public bandOracle;
    address public owner;
    bool public stop;

    struct TokenConfig {
        address pToken;
        address underlying;
        string underlyingSymbol; //example: DAI
        uint256 baseUnit; //example: 1e18
        uint256 cashThreshold;
        uint256 ratio; //
    }
    mapping (address => TokenConfig) public tokenConfigs;
    mapping(address => bool) public whitelisted;

    event SetPTokens(address pToken, string  symbol);

    constructor (address _owner, address _irbankStrategy, address _stakeRewardsHelper, address _irbankOracle, address _bandOracle)  {
        owner = _owner;
        irBankStrategy = _irbankStrategy;
        stakeRewardsHelper =_stakeRewardsHelper;
        irbankOracle = _irbankOracle;
        bandOracle = _bandOracle;

    }

    modifier onlyWhitelisted() {
        require(
            whitelisted[msg.sender] || msg.sender == owner,
            "exit all: Not whitelisted"
        );
        _;
    }



    function getIrBankUnderlyingPrice(address  pToken) internal  view returns (uint256) {
        uint256 price;
        price = IrBankOracleInterface(irbankOracle).getUnderlyingPrice(pToken);
        return price;
    }


    function getIrBankUnderlyingPrice2(address  pToken) external  view returns (uint256) {
        uint256 price;
        price = IrBankOracleInterface(irbankOracle).getUnderlyingPrice(pToken);
        return price;
    }


    function getBandPrice(string memory _base, string memory _quote, address pToken) internal view returns (uint256) {
        uint256 price;
        IStdReference.ReferenceData memory data = IStdReference(bandOracle).getReferenceData(_base,_quote);
        price = data.rate.mul(1e18).div(tokenConfigs[pToken].baseUnit);
        return price;
    }

    function getBandPriceCall(string memory _base, string memory _quote, address pToken) public view returns (uint256) {
        uint256 price;
        IStdReference.ReferenceData memory data = IStdReference(bandOracle).getReferenceData(_base,_quote);
        price = data.rate.mul(1e18).div(tokenConfigs[pToken].baseUnit);
        return price;
    }



    function _notSupportSymbolInternal(string memory symbol, address  pToken) internal view returns (bool) {

        try this.getBandPriceCall(symbol, 'USD', pToken) {

            return false;

        } catch {

            return true;

        }


    }

    function _notSupportSymbolInternal2(string memory symbol, address  pToken) external view returns (bool) {

        try this.getBandPriceCall(symbol, 'USD', pToken) {

            return false;

        } catch {

            return true;

        }


    }

    function notSupportSymbol(address [] memory pTokens) internal view returns (bool) {

        bool notSupport;
        for(uint256 i=0; i<pTokens.length; i++){

            notSupport = _notSupportSymbolInternal(tokenConfigs[pTokens[i]].underlyingSymbol, pTokens[i]);
            if(notSupport) {

                return true;
                
            }

        }
        return false;


    }


    function notSupportSymbol2(address [] memory pTokens) external view returns (bool) {

        bool notSupport;
        for(uint256 i=0; i<pTokens.length; i++){

            notSupport = _notSupportSymbolInternal(tokenConfigs[pTokens[i]].underlyingSymbol, pTokens[i]);
            if(notSupport) {

                return true;
                
            }

        }
        return false;


    }




    function isCompareOracleDeviate(address [] memory pTokens) internal  view returns (bool) {

        uint256 irbankPrice;
        uint256 bandPrice;
        uint256 priceGap;
        uint256 ratio;

        for(uint256 i=0; i<pTokens.length; i++) {
            irbankPrice = getIrBankUnderlyingPrice(pTokens[i]);
            bandPrice = getBandPrice(tokenConfigs[pTokens[i]].underlyingSymbol, 'USD', pTokens[i]);
            if ( !(bandPrice > 0) ) {
                return  true;
            }
            ratio = tokenConfigs[pTokens[i]].ratio;

            if (irbankPrice >= bandPrice) {

                priceGap = irbankPrice - bandPrice;
                if (bandPrice.mul(ratio).div(100) < priceGap){
                    return true;
                } 

            } else {
                priceGap =bandPrice - irbankPrice ;
                if (bandPrice.mul(ratio).div(100) < priceGap){
                    return true;
                }  
            }

        }
        return false;
    }


    function isCompareOracleDeviate2(address [] memory pTokens) external  view returns (bool) {

        uint256 irbankPrice;
        uint256 bandPrice;
        uint256 priceGap;
        uint256 ratio;

        for(uint256 i=0; i<pTokens.length; i++) {
            irbankPrice = getIrBankUnderlyingPrice(pTokens[i]);
            bandPrice = getBandPrice(tokenConfigs[pTokens[i]].underlyingSymbol, 'USD', pTokens[i]);
            if ( !(bandPrice > 0) ) {
                return  true;
            }
            ratio = tokenConfigs[pTokens[i]].ratio;

            if (irbankPrice >= bandPrice) {

                priceGap = irbankPrice - bandPrice;
                if (bandPrice.mul(ratio).div(100) < priceGap){
                    return true;
                } 

            } else {
                priceGap =bandPrice - irbankPrice ;
                if (bandPrice.mul(ratio).div(100) < priceGap){
                    return true;
                }  
            }

        }
        return false;
    }


    function _getCashInternal(address pToken) internal view returns (uint256) {
        uint256 cash;
        cash = CTokenInterface(pToken).getCash();
        return cash;
    }

    function isLiquidityInsufficient(address [] memory pTokens) internal view returns (bool) {

        bool cashThresholdStatus;
        for(uint256 i=0; i<pTokens.length; i++) {
            cashThresholdStatus = _getCashInternal(pTokens[i]) <= tokenConfigs[pTokens[i]].cashThreshold;
            if (cashThresholdStatus){
                return true;
            }
        }
        return false;

    }


    function isLiquidityInsufficient2(address [] memory pTokens) external view returns (bool) {

        bool cashThresholdStatus;
        for(uint256 i=0; i<pTokens.length; i++) {
            cashThresholdStatus = _getCashInternal(pTokens[i]) <= tokenConfigs[pTokens[i]].cashThreshold;
            if (cashThresholdStatus){
                return true;
            }
        }
        return false;

    }




    function isPoolPaused(address [] memory stakerRewards) internal view returns (bool) {
        bool pause;
        for(uint256 i=0; i<stakerRewards.length; i++ ){      
            pause = StakingRewardsInterface(stakerRewards[i]).paused();
            if (pause == true) {
                return true;
            }
        }
        return false;
    }


    function isPoolPaused2(address [] memory stakerRewards) external view returns (bool) {
        bool pause;
        for(uint256 i=0; i<stakerRewards.length; i++ ){      
            pause = StakingRewardsInterface(stakerRewards[i]).paused();
            if (pause == true) {
                return true;
            }
        }
        return false;
    }



    function getUserStakedAmount(address account) external view returns (StakingRewardsHelperInterface.UserStaked [] memory) {
        StakingRewardsHelperInterface.UserStaked [] memory userStakes = StakingRewardsHelperInterface(stakeRewardsHelper).getUserStaked(account);
        return userStakes;
    }





    function encodeExitAllInputs() internal  pure returns (bytes memory encodedInput) {
        return abi.encodeWithSignature("exitAll()");
    }



    function setTfokenConfigs(address pToken, address underlying, string memory underlyingSymbol,  uint256 baseUnit, uint256 cashCap, uint256 priceRatio)
        external
    {
        require(msg.sender == owner, "only owner set cashCap");
        TokenConfig storage tokenConfig = tokenConfigs[pToken];
        tokenConfig.pToken = pToken;
        tokenConfig.underlying = underlying;
        tokenConfig.underlyingSymbol = underlyingSymbol;
        tokenConfig.baseUnit = baseUnit;
        tokenConfig.cashThreshold = cashCap;
        tokenConfig.ratio = priceRatio;
    }


    function setStop (bool _stop) external {
        require(msg.sender == owner," only owner set flag");
        stop = _stop;

    }


    function setWhitelist(address _account, bool _whitelist)
        external
    {
        require(msg.sender == owner," only owner set whiteliste");
        whitelisted[_account] = _whitelist;
    }



    function exitAll(address _vault) external onlyWhitelisted {
        bytes memory data;
        data = encodeExitAllInputs();   
        IVaultInterface(_vault).execute(irBankStrategy, data);
        stop = true;
    }


    function checker(address _vault,address [] memory pTokens, address [] memory stakeRewards)
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {   if (stop == true) {
            canExec = false;
            } else  {
                
                if (isLiquidityInsufficient(pTokens)) {
                    canExec = true;
                    execPayload = abi.encodeCall(this.exitAll, (_vault));
                    return (canExec, execPayload);
                }
                if (isPoolPaused(stakeRewards)) {
                    canExec = true;
                    return (canExec, execPayload);
                }
                if (notSupportSymbol(pTokens)) {
                    canExec = true;
                    return (canExec, execPayload);
                }
                if (isCompareOracleDeviate(pTokens)) {
                    canExec = true;
                    return (canExec, execPayload);

                } else {
                    canExec = false;
                    return (canExec, bytes("all key points is ok"));
                }
        }
    }
}