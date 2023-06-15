// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

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
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBribe {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function getReward(address account) external;
    function notifyRewardAmount(address token, uint amount) external;
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    function _deposit(uint amount, address account) external;
    function _withdraw(uint amount, address account) external;
    function addReward(address rewardToken) external;
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function rewardPerToken(address reward) external view returns (uint);
    function earned(address account, address reward) external view returns (uint);
    function getRewardTokens() external view returns (address[] memory);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IGauge {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function getReward(address account) external;
    function notifyRewardAmount(address token, uint amount) external;
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    function _deposit(address account, uint256 amount) external;
    function _withdraw(address account, uint256 amount) external;
    function addReward(address rewardToken) external;
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function rewardPerToken(address reward) external view returns (uint);
    function earned(address account, address reward) external view returns (uint);
    function left(address token) external view returns (uint);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IPlugin {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function claimAndDistribute() external;
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    function setGauge(address gauge) external;
    function setBribe(address bribe) external;
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function getUnderlyingName() external view returns (string memory);
    function getUnderlyingSymbol() external view returns (string memory);
    function getUnderlyingAddress() external view returns (address);
    function getProtocol() external view returns (string memory);
    function getTokensInUnderlying() external view returns (address[] memory);
    function getBribeTokens() external view returns (address[] memory);
    function getPrice() external view returns (uint256);
    function getUnderlyingDecimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ITOKEN {
    /*----------  FUNCTIONS  --------------------------------------------*/
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function totalSupply() external view returns (uint256);
    function frBASE() external view returns (uint256);
    function mrvBASE() external view returns (uint256);
    function mrrBASE() external view returns (uint256);
    function mrrTOKEN() external view returns (uint256);
    function getFloorPrice() external view returns (uint256);
    function getMaxSell() external view returns (uint256);
    function getMarketPrice() external view returns (uint256);
    function getOTokenPrice() external view returns (uint256);
    function getTotalValueLocked() external view returns (uint256);
    function getAccountCredit(address account) external view returns (uint256) ;
    function debts(address account) external view returns (uint256);
    function treasury() external view returns (address);
    function FEES() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IVoter {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function distribute(address _gauge) external;
    function emitDeposit(address account, uint amount) external;
    function emitWithdraw(address account, uint amount) external;
    function notifyRewardAmount(uint amount) external;
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function plugins(uint256 index) external view returns (address);
    function getPlugins() external view returns (address[] memory);
    function gauges(address pool) external view returns (address);
    function bribes(address pool) external view returns (address);
    function isAlive(address gauge) external view returns (bool);
    function usedWeights(address account) external view returns (uint256);
    function weights(address pool) external view returns (uint256);
    function totalWeight() external view returns (uint256);
    function votes(address account, address pool) external view returns (uint256);
    function treasury() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IVTOKEN {
    /*----------  FUNCTIONS  --------------------------------------------*/
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function balanceOf(address account) external view returns (uint256);
    function balanceOfTOKEN(address account) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IVTOKENRewarder {
    /*----------  FUNCTIONS  --------------------------------------------*/
    function notifyRewardAmount(address token, uint amount) external;
    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/
    function _deposit(uint amount, address account) external;
    function _withdraw(uint amount, address account) external;
    function addReward(address rewardToken) external;
    /*----------  VIEW FUNCTIONS  ---------------------------------------*/
    function rewardPerToken(address _rewardsToken) external view returns (uint256);
    function earned(address account, address _rewardsToken) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "contracts/interfaces/ITOKEN.sol";
import "contracts/interfaces/IVTOKEN.sol";
import "contracts/interfaces/IVTOKENRewarder.sol";
import "contracts/interfaces/IGauge.sol";
import "contracts/interfaces/IBribe.sol";
import "contracts/interfaces/IVoter.sol";
import "contracts/interfaces/IPlugin.sol";

contract Multicall {

    /*----------  CONSTANTS  --------------------------------------------*/

    uint256 public constant FEE = 30;
    uint256 public constant DIVISOR = 10000;
    uint256 public constant PRECISION = 1e18;

    /*----------  STATE VARIABLES  --------------------------------------*/

    address public immutable voter;
    address public immutable BASE;
    address public immutable TOKEN;
    address public immutable OTOKEN;
    address public immutable VTOKEN;
    address public immutable rewarder;

    uint256 public priceBASE;

    struct SwapCard {
        uint256 frBASE;
        uint256 mrvBASE;
        uint256 mrrBASE;
        uint256 mrrTOKEN;
        uint256 marketMaxTOKEN;
    }

    struct BondingCurve {
        uint256 priceBASE;              // C1
        uint256 priceTOKEN;             // C2
        uint256 priceOTOKEN;            // C3
        uint256 maxMarketSell;          // C4

        uint256 tvl;                    // C5
        uint256 supplyTOKEN;            // C6
        uint256 supplyVTOKEN;           // C7
        uint256 apr;                    // C8
        uint256 ltv;                    // C9
        uint256 ratio;                  // C10

        uint256 accountNATIVE;          // C11
        uint256 accountBASE;            // C12
        uint256 accountTOKEN;           // C13
        uint256 accountOTOKEN;          // C14

        uint256 accountEarnedBASE;      // C15
        uint256 accountEarnedTOKEN;     // C16    
        uint256 accountEarnedOTOKEN;    // C17 

        uint256 accountVTOKEN;          // C18
        uint256 accountVotingPower;     // C19
        uint256 accountUsedWeights;     // C20

        uint256 accountBorrowCredit;    // C21
        uint256 accountBorrowDebt;      // C22
        uint256 accountMaxWithdraw;     // C23         
    }

    struct GaugeCard {
        address plugin;                     // G1
        address underlying;                 // G2
        uint8 underlyingDecimals;           // G3

        address gauge;                      // G4
        bool isAlive;                       // G5

        string protocol;                    // G6
        string symbol;                      // G7
        address[] tokensInUnderlying;       // G8

        uint256 priceUnderlying;            // G9
        uint256 priceOTOKEN;                // G10

        uint256 apr;                        // G11
        uint256 tvl;                        // G12
        uint256 votingWeight;               // G13
        uint256 totalSupply;                // G14

        uint256 accountUnderlyingBalance;   // G15
        uint256 accountStakedBalance;       // G16
        uint256 accountEarnedOTOKEN;        // G17
    }

    struct BribeCard {
        address plugin;                 // B1
        address bribe;                  // B2
        bool isAlive;                   // B3

        string protocol;                // B4
        string symbol;                  // B5

        address[] rewardTokens;         // B6
        uint8[] rewardTokenDecimals;    // B7
        uint256[] rewardsPerToken;      // B8
        uint256[] accountRewardsEarned; // B9

        uint256 voteWeight;             // B10
        uint256 votePercent;            // B11

        uint256 accountVotePercent;     // B12
    }

    /*----------  FUNCTIONS  --------------------------------------------*/

    constructor(
        address _voter,
        address _BASE,
        address _TOKEN,
        address _OTOKEN,
        address _VTOKEN,
        address _rewarder
    ) {
        voter = _voter;
        BASE = _BASE;
        TOKEN = _TOKEN;
        OTOKEN = _OTOKEN;
        VTOKEN = _VTOKEN;
        rewarder = _rewarder;
    }

    function setPriceBase(uint256 _priceBASE) external {
        priceBASE = _priceBASE;
    }

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/

    function swapCardData() external view returns (SwapCard memory swapCard) {
        swapCard.frBASE = ITOKEN(TOKEN).frBASE();
        swapCard.mrvBASE = ITOKEN(TOKEN).mrvBASE();
        swapCard.mrrBASE = ITOKEN(TOKEN).mrrBASE();
        swapCard.mrrTOKEN = ITOKEN(TOKEN).mrrTOKEN();
        swapCard.marketMaxTOKEN = ITOKEN(TOKEN).mrvBASE();

        return swapCard;
    }

    function bondingCurveData(address account) external view returns (BondingCurve memory bondingCurve) {
        bondingCurve.priceBASE = priceBASE;
        bondingCurve.priceTOKEN = ITOKEN(TOKEN).getMarketPrice() * bondingCurve.priceBASE / 1e18;
        bondingCurve.priceOTOKEN = ITOKEN(TOKEN).getOTokenPrice() * bondingCurve.priceBASE / 1e18;
        bondingCurve.maxMarketSell = ITOKEN(TOKEN).getMaxSell();

        bondingCurve.tvl = ITOKEN(TOKEN).getTotalValueLocked() * bondingCurve.priceBASE / 1e18;
        bondingCurve.supplyTOKEN = IERC20(TOKEN).totalSupply();
        bondingCurve.supplyVTOKEN = IERC20(VTOKEN).totalSupply();
        bondingCurve.apr = ((IVTOKENRewarder(rewarder).rewardPerToken(BASE) * bondingCurve.priceBASE / 1e18) +  (IVTOKENRewarder(rewarder).rewardPerToken(TOKEN) * bondingCurve.priceTOKEN / 1e18) + 
                           (IVTOKENRewarder(rewarder).rewardPerToken(OTOKEN) * bondingCurve.priceOTOKEN / 1e18)) * 365 * 100 * 1e18 / (7 * bondingCurve.priceTOKEN);
        bondingCurve.ltv = 100 * ITOKEN(TOKEN).getFloorPrice() * 1e18 / ITOKEN(TOKEN).getMarketPrice();
        bondingCurve.ratio = ITOKEN(TOKEN).getMarketPrice() * 1e18 / ITOKEN(TOKEN).getFloorPrice();

        bondingCurve.accountNATIVE = (account == address(0) ? 0 : account.balance);
        bondingCurve.accountBASE = (account == address(0) ? 0 : IERC20(BASE).balanceOf(account));
        bondingCurve.accountTOKEN = (account == address(0) ? 0 : IERC20(TOKEN).balanceOf(account));
        bondingCurve.accountOTOKEN = (account == address(0) ? 0 : IERC20(OTOKEN).balanceOf(account));

        bondingCurve.accountEarnedBASE = (account == address(0) ? 0 : IVTOKENRewarder(rewarder).earned(account, BASE));
        bondingCurve.accountEarnedTOKEN = (account == address(0) ? 0 : IVTOKENRewarder(rewarder).earned(account, TOKEN));
        bondingCurve.accountEarnedOTOKEN = (account == address(0) ? 0 : IVTOKENRewarder(rewarder).earned(account, OTOKEN));

        bondingCurve.accountVTOKEN = (account == address(0) ? 0 : IVTOKEN(VTOKEN).balanceOfTOKEN(account));
        bondingCurve.accountVotingPower = (account == address(0) ? 0 : IERC20(VTOKEN).balanceOf(account));
        bondingCurve.accountUsedWeights = (account == address(0) ? 0 : IVoter(voter).usedWeights(account));

        bondingCurve.accountBorrowCredit = (account == address(0) ? 0 : ITOKEN(TOKEN).getAccountCredit(account));
        bondingCurve.accountBorrowDebt = (account == address(0) ? 0 : ITOKEN(TOKEN).debts(account));
        bondingCurve.accountMaxWithdraw = (account == address(0) ? 0 : (IVoter(voter).usedWeights(account) > 0 ? 0 : bondingCurve.accountVTOKEN - bondingCurve.accountBorrowDebt));

        return bondingCurve;
    }

    function gaugeCardData(address plugin, address account) public view returns (GaugeCard memory gaugeCard) {
        gaugeCard.plugin = plugin;
        gaugeCard.underlying = IPlugin(plugin).getUnderlyingAddress();
        gaugeCard.underlyingDecimals = IPlugin(plugin).getUnderlyingDecimals();

        gaugeCard.gauge = IVoter(voter).gauges(plugin);
        gaugeCard.isAlive = IVoter(voter).isAlive(gaugeCard.gauge);
        
        gaugeCard.protocol = IPlugin(plugin).getProtocol();
        gaugeCard.symbol = IPlugin(plugin).getUnderlyingSymbol();
        gaugeCard.tokensInUnderlying = IPlugin(plugin).getTokensInUnderlying();

        gaugeCard.priceUnderlying = IPlugin(plugin).getPrice();
        gaugeCard.priceOTOKEN = ITOKEN(TOKEN).getOTokenPrice() * (priceBASE) / 1e18;
        
        gaugeCard.apr = IGauge(IVoter(voter).gauges(plugin)).rewardPerToken(OTOKEN) * gaugeCard.priceOTOKEN * 365 * 100 / 7 / gaugeCard.priceUnderlying;
        gaugeCard.tvl = IGauge(IVoter(voter).gauges(plugin)).totalSupply() * gaugeCard.priceUnderlying / 1e18;
        gaugeCard.votingWeight = (IVoter(voter).totalWeight() == 0 ? 0 : 100 * IVoter(voter).weights(plugin) * 1e18 / IVoter(voter).totalWeight());
        gaugeCard.totalSupply = IGauge(gaugeCard.gauge).totalSupply();

        gaugeCard.accountUnderlyingBalance = (account == address(0) ? 0 : IERC20(gaugeCard.underlying).balanceOf(account));
        gaugeCard.accountStakedBalance = (account == address(0) ? 0 : IPlugin(plugin).balanceOf(account));
        gaugeCard.accountEarnedOTOKEN = (account == address(0) ? 0 : IGauge(IVoter(voter).gauges(plugin)).earned(account, OTOKEN));

        return gaugeCard;
    }

    function bribeCardData(address plugin, address account) public view returns (BribeCard memory bribeCard) {
        bribeCard.plugin = plugin;
        bribeCard.bribe = IVoter(voter).bribes(plugin);
        bribeCard.isAlive = IVoter(voter).isAlive(IVoter(voter).gauges(plugin));

        bribeCard.protocol = IPlugin(plugin).getProtocol();
        bribeCard.symbol = IPlugin(plugin).getUnderlyingSymbol();
        bribeCard.rewardTokens = IBribe(IVoter(voter).bribes(plugin)).getRewardTokens();

        uint8[] memory _rewardTokenDecimals = new uint8[](bribeCard.rewardTokens.length);
        for (uint i = 0; i < bribeCard.rewardTokens.length; i++) {
            _rewardTokenDecimals[i] = IERC20Metadata(bribeCard.rewardTokens[i]).decimals();
        }
        bribeCard.rewardTokenDecimals = _rewardTokenDecimals;

        uint[] memory _rewardsPerToken = new uint[](bribeCard.rewardTokens.length);
        for (uint i = 0; i < bribeCard.rewardTokens.length; i++) {
            _rewardsPerToken[i] = IBribe(IVoter(voter).bribes(plugin)).rewardPerToken(bribeCard.rewardTokens[i]);
        }
        bribeCard.rewardsPerToken = _rewardsPerToken;

        uint[] memory _accountRewardsEarned = new uint[](bribeCard.rewardTokens.length);
        for (uint i = 0; i < bribeCard.rewardTokens.length; i++) {
            _accountRewardsEarned[i] = (account == address(0) ? 0 : IBribe(IVoter(voter).bribes(plugin)).earned(account, bribeCard.rewardTokens[i]));
        }
        bribeCard.accountRewardsEarned = _accountRewardsEarned;

        bribeCard.voteWeight = IVoter(voter).weights(plugin);
        bribeCard.votePercent = (IVoter(voter).totalWeight() == 0 ? 0 : 100 * IVoter(voter).weights(plugin) * 1e18 / IVoter(voter).totalWeight());

        bribeCard.accountVotePercent = (account == address(0) ? 0 : (IVoter(voter).usedWeights(account) == 0 ? 0 : 100 * IVoter(voter).votes(account, plugin) * 1e18 / IVoter(voter).usedWeights(account)));

        return bribeCard;
    }

    function getGaugeCards(uint256 start, uint256 stop, address account) external view returns (GaugeCard[] memory) {
        GaugeCard[] memory gaugeCards = new GaugeCard[](stop - start);
        for (uint i = start; i < stop; i++) {
            gaugeCards[i] = gaugeCardData(getPlugin(i), account);
        }
        return gaugeCards;
    }

    function getBribeCards(uint256 start, uint256 stop, address account) external view returns (BribeCard[] memory) {
        BribeCard[] memory bribeCards = new BribeCard[](stop - start);
        for (uint i = start; i < stop; i++) {
            bribeCards[i] = bribeCardData(getPlugin(i), account);
        }
        return bribeCards;
    }

    function getPlugins() external view returns (address[] memory) {
        return IVoter(voter).getPlugins();
    }

    function getPlugin(uint256 index) public view returns (address) {
        return IVoter(voter).plugins(index);
    }

    function quoteBuyIn(uint256 input, uint256 slippageTolerance) external view returns (uint256 output, uint256 slippage, uint256 minOutput) {
        uint256 feeBASE = input * FEE / DIVISOR;
        uint256 oldMrBASE = ITOKEN(TOKEN).mrvBASE() + ITOKEN(TOKEN).mrrBASE();
        uint256 newMrBASE = oldMrBASE + input - feeBASE;
        uint256 oldMrTOKEN = ITOKEN(TOKEN).mrrTOKEN();
        output = oldMrTOKEN - (oldMrBASE * oldMrTOKEN / newMrBASE);


        return (
            output, 
            100 * (1e18 - (output * 1e18 / ((input - feeBASE) * 1e18 / ITOKEN(TOKEN).getMarketPrice()))), 
            ((input - feeBASE) * 1e18 / ITOKEN(TOKEN).getMarketPrice()) * slippageTolerance / DIVISOR
        );
    }

    function quoteBuyOut(uint256 input, uint256 slippageTolerance) external view returns (uint256 output, uint256 slippage, uint256 minOutput) {
        uint256 oldMrBASE = ITOKEN(TOKEN).mrvBASE() + ITOKEN(TOKEN).mrrBASE();
        output = DIVISOR * ((oldMrBASE * ITOKEN(TOKEN).mrrTOKEN() / (ITOKEN(TOKEN).mrrTOKEN() - input)) - oldMrBASE) / (DIVISOR - FEE);

        return (
            output, 
            100 * (1e18 - (input * 1e18 / ((output - (output * FEE / DIVISOR)) * 1e18 / ITOKEN(TOKEN).getMarketPrice()))), 
            ((output - (output * FEE / DIVISOR)) * 1e18 / ITOKEN(TOKEN).getMarketPrice()) * slippageTolerance / DIVISOR
        );
    }

    function quoteSellIn(uint256 input, uint256 slippageTolerance) external view returns (uint256 output, uint256 slippage, uint256 minOutput) {
        uint256 feeTOKEN = input * FEE / DIVISOR;
        uint256 oldMrTOKEN = ITOKEN(TOKEN).mrrTOKEN();
        uint256 newMrTOKEN = oldMrTOKEN + input - feeTOKEN;
        if (newMrTOKEN > ITOKEN(TOKEN).mrvBASE()) {
            return (0, 0, 0);
        }

        uint256 oldMrBASE = ITOKEN(TOKEN).mrvBASE() + ITOKEN(TOKEN).mrrBASE();
        output = oldMrBASE - (oldMrBASE * oldMrTOKEN / newMrTOKEN);

        return (
            output, 
            100 * (1e18 - (output * 1e18 / ((input - feeTOKEN) * ITOKEN(TOKEN).getMarketPrice() / 1e18))), 
            ((input - feeTOKEN) * ITOKEN(TOKEN).getMarketPrice() / 1e18) * slippageTolerance / DIVISOR
        );
    }

    function quoteSellOut(uint256 input, uint256 slippageTolerance) external view returns (uint256 output, uint256 slippage, uint256 minOutput) {
        uint256 oldMrBASE = ITOKEN(TOKEN).mrvBASE() + ITOKEN(TOKEN).mrrBASE();
        output = DIVISOR * ((oldMrBASE * ITOKEN(TOKEN).mrrTOKEN() / (oldMrBASE - input)) - ITOKEN(TOKEN).mrrTOKEN()) / (DIVISOR - FEE);
        if (output + ITOKEN(TOKEN).mrrTOKEN() > ITOKEN(TOKEN).mrvBASE()) {
            return (0, 0, 0);
        }

        return (
            output, 
            100 * (1e18 - (input * 1e18 / ((output - (output * FEE / DIVISOR)) * ITOKEN(TOKEN).getMarketPrice() / 1e18))), 
            ((output - (output * FEE / DIVISOR)) * ITOKEN(TOKEN).getMarketPrice() / 1e18) * slippageTolerance / DIVISOR
        );
    }

}