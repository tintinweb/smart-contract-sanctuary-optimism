// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseVault.sol";

import "../interfaces/IThalesAMM.sol";
import "../interfaces/IPositionalMarket.sol";

contract Vault is BaseVault {
    /* ========== CONSTANTS ========== */
    uint private constant HUNDRED = 1e20;

    enum Asset {
        ETH,
        BTC,
        Other
    }

    /* ========== STATE VARIABLES ========== */

    mapping(Asset => uint) public allocationLimits;
    mapping(uint => mapping(Asset => uint)) public allocationSpentPerRound;

    uint public priceLowerLimit;
    uint public priceUpperLimit;
    uint public skewImpactLimit;

    /* ========== CONSTRUCTOR ========== */

    function initialize(
        address _owner,
        IThalesAMM _thalesAmm,
        IERC20Upgradeable _sUSD,
        uint _roundLength,
        uint _priceLowerLimit,
        uint _priceUpperLimit,
        uint _skewImpactLimit,
        uint _allocationLimitBTC,
        uint _allocationLimitETH,
        uint _allocationLimitOtherAssets
    ) external initializer {
        __BaseVault_init(_owner, _thalesAmm, _sUSD, _roundLength);
        priceLowerLimit = _priceLowerLimit;
        priceUpperLimit = _priceUpperLimit;
        skewImpactLimit = _skewImpactLimit;
        allocationLimits[Asset.ETH] = _allocationLimitETH;
        allocationLimits[Asset.BTC] = _allocationLimitBTC;
        allocationLimits[Asset.Other] = _allocationLimitOtherAssets;
    }

    /// @notice Buy market options from Thales AMM
    /// @param market address of a market
    /// @param amount number of options to be bought
    function trade(address market, uint amount) external nonReentrant whenNotPaused {
        require(vaultStarted, "Vault has not started");

        IPositionalMarket marketContract = IPositionalMarket(market);
        (bytes32 key, , ) = marketContract.getOracleDetails();
        (uint maturity, ) = marketContract.times();
        require(maturity < roundEndTime[round], "Market not valid");

        uint priceUp = thalesAMM.price(address(market), IThalesAMM.Position.Up);
        uint priceDown = thalesAMM.price(address(market), IThalesAMM.Position.Down);
        uint priceUpImpact = thalesAMM.buyPriceImpact(address(market), IThalesAMM.Position.Up, amount);
        uint priceDownImpact = thalesAMM.buyPriceImpact(address(market), IThalesAMM.Position.Down, amount);

        if (priceUp >= priceLowerLimit && priceUp <= priceUpperLimit && priceUpImpact < skewImpactLimit) {
            _buyFromAmm(market, _getAsset(key), IThalesAMM.Position.Up, amount);
        } else if (priceDown >= priceLowerLimit && priceDown <= priceUpperLimit && priceDownImpact < skewImpactLimit) {
            _buyFromAmm(market, _getAsset(key), IThalesAMM.Position.Down, amount);
        } else {
            revert("Market not valid");
        }

        if (!isTradingMarketInARound[round][market]) {
            tradingMarketsPerRound[round].push(market);
            isTradingMarketInARound[round][market] = true;
        }
    }

    /// @notice Set allocation limits for assets to be spent in one round
    /// @param _allocationETH allocation for ETH in percent
    /// @param _allocationBTC allocation for BTC in percent
    /// @param _allocationOtherAssets allocation for other assets in percent
    function setAllocationLimits(
        uint _allocationETH,
        uint _allocationBTC,
        uint _allocationOtherAssets
    ) external onlyOwner {
        require(_allocationBTC + _allocationETH + _allocationOtherAssets == HUNDRED, "Invalid allocation limit values");
        allocationLimits[Asset.ETH] = _allocationETH;
        allocationLimits[Asset.BTC] = _allocationBTC;
        allocationLimits[Asset.Other] = _allocationOtherAssets;
        emit SetAllocationLimits(_allocationETH, _allocationBTC, _allocationOtherAssets);
    }

    /// @notice Set price limit for options to be bought from AMM
    /// @param _priceLowerLimit lower limit
    /// @param _priceUpperLimit upper limit
    function setPriceLimits(uint _priceLowerLimit, uint _priceUpperLimit) external onlyOwner {
        require(_priceLowerLimit < _priceUpperLimit, "Invalid price limit values");
        priceLowerLimit = _priceLowerLimit;
        priceUpperLimit = _priceUpperLimit;
        emit SetPriceLimits(_priceLowerLimit, _priceUpperLimit);
    }

    /// @notice Set skew impact limit for AMM
    /// @param _skewImpactLimit limit in percents
    function setSkewImpactLimit(uint _skewImpactLimit) external onlyOwner {
        skewImpactLimit = _skewImpactLimit;
        emit SetSkewImpactLimit(_skewImpactLimit);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /// @notice Buy options from AMM
    /// @param market address of a market
    /// @param asset market asset
    /// @param position position to be bought
    /// @param amount amount of positions to be bought
    function _buyFromAmm(
        address market,
        Asset asset,
        IThalesAMM.Position position,
        uint amount
    ) internal {
        uint quote = thalesAMM.buyFromAmmQuote(market, position, amount);
        uint allocationAsset = (allocationPerRound[round] * allocationLimits[asset]) / HUNDRED;
        require(
            (quote + allocationSpentPerRound[round][asset]) < allocationAsset,
            "Amount exceeds available allocation for asset"
        );

        uint balanceBeforeTrade = sUSD.balanceOf(address(this));

        thalesAMM.buyFromAMM(market, position, amount, quote, 500000000000000000);

        uint balanceAfterTrade = sUSD.balanceOf(address(this));

        uint totalAmountSpent = balanceBeforeTrade - balanceAfterTrade;

        allocationSpentPerRound[round][asset] += totalAmountSpent;

        emit TradeExecuted(market, position, asset, amount, totalAmountSpent);
    }

    /// @notice Get asset number based on asset key
    /// @param key asset key
    /// @return asset
    function _getAsset(bytes32 key) public pure returns (Asset asset) {
        if (key == "ETH") {
            asset = Asset.ETH;
        } else if (key == "BTC") {
            asset = Asset.BTC;
        } else {
            asset = Asset.Other;
        }
    }

    /* ========== VIEWS ========== */

    /// @notice Get amount spent on given asset in a round
    /// @param _round number of round
    /// @param asset asset to fetch spent allocation for
    /// @return uint
    function getAllocationSpentPerRound(uint _round, Asset asset) external view returns (uint) {
        return allocationSpentPerRound[_round][asset];
    }

    /* ========== EVENTS ========== */

    event SetAllocationLimits(uint allocationETH, uint allocationBTC, uint allocationOtherAssets);
    event SetPriceLimits(uint priceLowerLimit, uint priceUpperLimit);
    event SetSkewImpactLimit(uint skewImpact);
    event TradeExecuted(address market, IThalesAMM.Position position, Asset asset, uint amount, uint quote);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../utils/proxy/solidity-0.8.0/ProxyReentrancyGuard.sol";
import "../utils/proxy/solidity-0.8.0/ProxyOwned.sol";

import "../interfaces/IThalesAMM.sol";
import "../interfaces/IPositionalMarket.sol";

contract BaseVault is Initializable, ProxyOwned, PausableUpgradeable, ProxyReentrancyGuard {
    /* ========== LIBRARIES ========== */
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct WithdrawalRequest {
        uint round;
        uint amount;
        bool requested;
    }

    struct DepositReceipt {
        uint round;
        uint amount;
    }

    /* ========== CONSTANTS ========== */
    uint private constant HUNDRED = 1e20;

    /* ========== STATE VARIABLES ========== */

    IThalesAMM public thalesAMM;
    IERC20Upgradeable public sUSD;

    bool public vaultStarted;

    uint public round;
    uint public roundLength;
    mapping(uint => uint) public roundStartTime;
    mapping(uint => uint) public roundEndTime;

    mapping(uint => address[]) public usersPerRound;
    mapping(uint => mapping(address => uint)) public balancesPerRound;
    mapping(uint => mapping(address => bool)) public claimedPerRound;
    mapping(address => WithdrawalRequest) public withdrawalQueue;
    mapping(address => DepositReceipt) public depositReceipts;
    mapping(uint => uint) public withdrawalQueueAmount;

    mapping(uint => uint) public allocationPerRound;

    mapping(uint => address[]) public tradingMarketsPerRound;
    mapping(uint => mapping(address => bool)) public isTradingMarketInARound;

    mapping(uint => uint) public profitAndLossPerRound;
    mapping(uint => uint) public cumulativeProfitAndLoss;

    /* ========== CONSTRUCTOR ========== */

    function __BaseVault_init(
        address _owner,
        IThalesAMM _thalesAmm,
        IERC20Upgradeable _sUSD,
        uint _roundLength
    ) internal onlyInitializing {
        setOwner(_owner);
        initNonReentrant();
        thalesAMM = IThalesAMM(_thalesAmm);
        sUSD = _sUSD;
        roundLength = _roundLength;
        sUSD.approve(address(thalesAMM), type(uint256).max);
    }

    /// @notice Start vault and begin round #1
    function startVault() external onlyOwner {
        require(!vaultStarted, "Vault has already started");
        round = 1;

        roundStartTime[round] = block.timestamp;
        roundEndTime[round] = roundStartTime[round] + roundLength;

        allocationPerRound[round] = sUSD.balanceOf(address(this));

        vaultStarted = true;

        emit VaultStarted();
    }

    /// @notice Close current round and begin next round,
    /// excercise options of trading markets and calculate profit and loss
    function closeRound() external nonReentrant whenNotPaused canCloseRound {
        // excercise market options
        for (uint i = 0; i < tradingMarketsPerRound[round].length; i++) {
            IPositionalMarket(tradingMarketsPerRound[round][i]).exerciseOptions();
        }

        // TODO: exclude sUSD that was sent directly to contract
        // balance in next round does not affect PnL in a current round
        uint currentVaultBalance = sUSD.balanceOf(address(this)) - allocationPerRound[round + 1];
        // calculate PnL

        // if no allocation for current round
        if (allocationPerRound[round] == 0) {
            profitAndLossPerRound[round] = 1;
        } else {
            profitAndLossPerRound[round] = (currentVaultBalance * 1e18) / allocationPerRound[round];
        }

        if (round == 1) {
            cumulativeProfitAndLoss[round] = profitAndLossPerRound[round];
        } else {
            cumulativeProfitAndLoss[round] = (cumulativeProfitAndLoss[round - 1] * profitAndLossPerRound[round]) / 1e18;
        }

        // calculate withdrawal amount share
        withdrawalQueueAmount[round] = (withdrawalQueueAmount[round] * profitAndLossPerRound[round]) / 1e18;

        // start next round
        round += 1;

        roundStartTime[round] = block.timestamp;
        roundEndTime[round] = roundStartTime[round] + roundLength;

        // allocation for next round doesn't include withdrawal queue share from previous round
        allocationPerRound[round] = sUSD.balanceOf(address(this)) - withdrawalQueueAmount[round - 1];

        emit RoundClosed(round - 1);
    }

    /// @notice Deposit funds from user into vault for the next round
    /// @param amount Value to be deposited
    function deposit(uint amount) external canDeposit(amount) {
        sUSD.safeTransferFrom(msg.sender, address(this), amount);

        // calculate previous shares
        if (vaultStarted) {
            _calculateBalanceInARound(msg.sender, round);
        }

        uint nextRound = round + 1;

        if (balancesPerRound[nextRound][msg.sender] == 0) {
            usersPerRound[nextRound].push(msg.sender);
        }

        balancesPerRound[nextRound][msg.sender] += amount;

        // update deposit state of a user
        depositReceipts[msg.sender] = DepositReceipt(nextRound, balancesPerRound[nextRound][msg.sender]);

        allocationPerRound[nextRound] += amount;

        emit Deposited(msg.sender, amount);
    }

    function withdrawalRequest() external {
        require(vaultStarted, "Vault has not started");
        require(!withdrawalQueue[msg.sender].requested, "Withdrawal already requested");

        _calculateBalanceInARound(msg.sender, round);

        withdrawalQueue[msg.sender] = WithdrawalRequest(round, balancesPerRound[round][msg.sender], true);

        withdrawalQueueAmount[round] += balancesPerRound[round][msg.sender];

        emit WithdrawalRequested(msg.sender);
    }

    /// @notice Transfer sUSD to user based on vault success and user deposits
    /// @dev During a round, user can claim amount only from previous rounds if withdrawal request is sent
    function claim() external nonReentrant whenNotPaused {
        WithdrawalRequest memory withdrawalRequest = withdrawalQueue[msg.sender];
        require(withdrawalRequest.requested, "Withdrawal request has not been sent");

        uint amount = (withdrawalRequest.amount * profitAndLossPerRound[withdrawalRequest.round]) / 1e18;
        require(amount > 0, "Nothing to claim");

        sUSD.safeTransfer(msg.sender, amount);
        claimedPerRound[withdrawalRequest.round][msg.sender] = true;
        withdrawalQueueAmount[withdrawalRequest.round] -= amount;

        // reset withdrawal request;
        withdrawalQueue[msg.sender].requested = false;
        withdrawalQueue[msg.sender].amount = 0;
        withdrawalQueue[msg.sender].round = 0;

        // reset deposit receipt;
        depositReceipts[msg.sender].round = 0;
        depositReceipts[msg.sender].amount = 0;

        emit Claimed(msg.sender, amount);
    }

    /// @notice Set length of rounds
    /// @param _roundLength Length of a round in miliseconds
    function setRoundLength(uint _roundLength) external onlyOwner {
        roundLength = _roundLength;
        emit RoundLengthChanged(_roundLength);
    }

    /// @notice Set ThalesAMM contract
    /// @param _thalesAMM ThalesAMM address
    function setThalesAMM(IThalesAMM _thalesAMM) external onlyOwner {
        thalesAMM = _thalesAMM;
        emit ThalesAMMChanged(address(_thalesAMM));
    }

    /// @notice Set sUSD token contract
    /// @param _sUSD sUSD token address
    function setSUSD(IERC20Upgradeable _sUSD) external onlyOwner {
        sUSD = _sUSD;
        emit SetSUSD(address(sUSD));
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /// @notice Calculate user balance in a round based on vaults' PnL
    /// @param user Address of the user
    /// @param _round Round number
    function _calculateBalanceInARound(address user, uint _round) internal {
        for (uint i = 1; i < _round; i++) {
            if (claimedPerRound[i][user]) continue;

            balancesPerRound[i][user] = (balancesPerRound[i][user] * profitAndLossPerRound[i]) / 1e18;
            balancesPerRound[i + 1][user] += balancesPerRound[i][user];
            claimedPerRound[i][user] = true;
        }
    }

    /// @notice Return multiplied PnLs between rounds
    /// @param roundA Round number from
    /// @param roundB Round number to
    /// @return uint
    function _cumulativePnLBetweenRounds(uint roundA, uint roundB) internal view returns (uint) {
        return (cumulativeProfitAndLoss[roundB] * profitAndLossPerRound[roundA]) / cumulativeProfitAndLoss[roundA];
    }

    /* ========== VIEWS ========== */

    /// @notice Return user balance in a round
    /// @param _round Round number
    /// @param user Address of the user
    /// @return uint
    function getBalancesPerRound(uint _round, address user) external view returns (uint) {
        return balancesPerRound[_round][user];
    }

    /// @notice Return if user has claimed in a round
    /// @param _round Round number
    /// @param user Address of the user
    /// @return bool
    function getClaimedPerRound(uint _round, address user) external view returns (bool) {
        return claimedPerRound[_round][user];
    }

    /// @notice Return user's available amount to claim
    /// @param user Address of the user
    /// @return amount Amount to be claimed
    function getAvailableToClaim(address user) external view returns (uint) {
        WithdrawalRequest memory withdrawalRequest = withdrawalQueue[user];
        DepositReceipt memory depositReceipt = depositReceipts[user];

        // if no round has been finished or user already claimed (no withdrawal request and no deposit)
        if (!vaultStarted || round == 1 || (!withdrawalRequest.requested && depositReceipt.round == 0)) {
            return 0;
        }

        //if user requested withrawal, share in previous rounds is already calculated
        if (withdrawalRequest.requested) {
            return
                withdrawalRequest.round == round
                    ? withdrawalRequest.amount
                    : (withdrawalRequest.amount * profitAndLossPerRound[withdrawalRequest.round]) / 1e18;
        }

        if (depositReceipt.round >= round) {
            // if user claimed and deposited in the same round
            if (claimedPerRound[round][user] == true) return 0;
            return balancesPerRound[round - 1][user];
        } else {
            uint initialBalance =
                (balancesPerRound[depositReceipt.round - 1][user] * profitAndLossPerRound[depositReceipt.round - 1]) /
                    1e18 +
                    balancesPerRound[depositReceipt.round][user];

            return (initialBalance * _cumulativePnLBetweenRounds(depositReceipt.round, round - 1)) / 1e18;
        }
    }

    /* ========== MODIFIERS ========== */

    modifier canDeposit(uint amount) {
        require(!withdrawalQueue[msg.sender].requested, "Withdrawal is requested, cannot deposit");
        require(amount > 0, "Invalid amount");
        require(sUSD.balanceOf(msg.sender) >= amount, "No enough sUSD");
        require(sUSD.allowance(msg.sender, address(this)) >= amount, "No allowance");
        _;
    }

    modifier canCloseRound() {
        require(vaultStarted, "Vault has not started");
        require(block.timestamp > (roundStartTime[round] + roundLength), "Can't close round yet");
        _;
    }

    /* ========== EVENTS ========== */

    event VaultStarted();
    event RoundClosed(uint round);
    event RoundLengthChanged(uint roundLength);
    event ThalesAMMChanged(address thalesAmm);
    event SetSUSD(address sUSD);
    event Deposited(address user, uint amount);
    event Claimed(address user, uint amount);
    event WithdrawalRequested(address user);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16;

interface IThalesAMM {
    enum Position {Up, Down}

    function manager() external view returns (address);

    function availableToBuyFromAMM(address market, Position position) external view returns (uint);

    function impliedVolatilityPerAsset(bytes32 oracleKey) external view returns(uint);

    function buyFromAmmQuote(
        address market,
        Position position,
        uint amount
    ) external view returns (uint);

    function buyFromAMM(
        address market,
        Position position,
        uint amount,
        uint expectedPayout,
        uint additionalSlippage
    ) external;

    function availableToSellToAMM(address market, Position position) external view returns (uint);

    function sellToAmmQuote(
        address market,
        Position position,
        uint amount
    ) external view returns (uint);

    function sellToAMM(
        address market,
        Position position,
        uint amount,
        uint expectedPayout,
        uint additionalSlippage
    ) external;

    function isMarketInAMMTrading(address market) external view returns (bool);
    function price(address market, Position position) external view returns (uint);
    function buyPriceImpact(
        address market,
        Position position,
        uint amount
    ) external view returns (uint);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

import "../interfaces/IPositionalMarketManager.sol";
import "../interfaces/IPosition.sol";
import "../interfaces/IPriceFeed.sol";

interface IPositionalMarket {
    /* ========== TYPES ========== */

    enum Phase {Trading, Maturity, Expiry}
    enum Side {Up, Down}

    /* ========== VIEWS / VARIABLES ========== */

    function getOptions() external view returns (IPosition up, IPosition down);

    function times() external view returns (uint maturity, uint destructino);

    function getOracleDetails()
        external
        view
        returns (
            bytes32 key,
            uint strikePrice,
            uint finalPrice
        );

    function fees() external view returns (uint poolFee, uint creatorFee);

    function deposited() external view returns (uint);

    function creator() external view returns (address);

    function resolved() external view returns (bool);

    function phase() external view returns (Phase);

    function oraclePrice() external view returns (uint);

    function oraclePriceAndTimestamp() external view returns (uint price, uint updatedAt);

    function canResolve() external view returns (bool);

    function result() external view returns (Side);

    function balancesOf(address account) external view returns (uint up, uint down);

    function totalSupplies() external view returns (uint up, uint down);

    function getMaximumBurnable(address account) external view returns (uint amount);

    /* ========== MUTATIVE FUNCTIONS ========== */

    function mint(uint value) external;

    function exerciseOptions() external returns (uint);

    function burnOptions(uint amount) external;

    function burnOptionsMaximum() external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
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
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
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
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To initialize the implementation contract, you can either invoke the
 * initializer manually, or you can include a constructor to automatically mark it as initialized when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() initializer {}
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(_initializing ? _isConstructor() : !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Context_init_unchained();
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the `nonReentrant` modifier
 * available, which can be aplied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 */
contract ProxyReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;
    bool private _initialized;

    function initNonReentrant() public {
        require(!_initialized, "Already initialized");
        _initialized = true;
        _guardCounter = 1;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter, "ReentrancyGuard: reentrant call");
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Clone of syntetix contract without constructor
contract ProxyOwned {
    address public owner;
    address public nominatedOwner;
    bool private _initialized;
    bool private _transferredAtInit;

    function setOwner(address _owner) public {
        require(_owner != address(0), "Owner address cannot be 0");
        require(!_initialized, "Already initialized, use nominateNewOwner");
        _initialized = true;
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

    function transferOwnershipAtInit(address proxyAddress) external onlyOwner {
        require(proxyAddress != address(0), "Invalid address");
        require(!_transferredAtInit, "Already transferred");
        owner = proxyAddress;
        _transferredAtInit = true;
        emit OwnerChanged(owner, proxyAddress);
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
        assembly {
            size := extcodesize(account)
        }
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
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

import "../interfaces/IPositionalMarket.sol";

interface IPositionalMarketManager {
    /* ========== VIEWS / VARIABLES ========== */

    function durations() external view returns (uint expiryDuration, uint maxTimeToMaturity);

    function capitalRequirement() external view returns (uint);

    function marketCreationEnabled() external view returns (bool);

    function transformCollateral(uint value) external view returns (uint);

    function reverseTransformCollateral(uint value) external view returns (uint);

    function totalDeposited() external view returns (uint);

    function numActiveMarkets() external view returns (uint);

    function activeMarkets(uint index, uint pageSize) external view returns (address[] memory);

    function numMaturedMarkets() external view returns (uint);

    function maturedMarkets(uint index, uint pageSize) external view returns (address[] memory);

    function isActiveMarket(address candidate) external view returns (bool);

    function isKnownMarket(address candidate) external view returns (bool);

    /* ========== MUTATIVE FUNCTIONS ========== */

    function createMarket(
        bytes32 oracleKey,
        uint strikePrice,
        uint maturity,
        uint initialMint // initial sUSD to mint options for,
    ) external returns (IPositionalMarket);

    function resolveMarket(address market) external;

    function expireMarkets(address[] calldata market) external;

    function transferSusdTo(
        address sender,
        address receiver,
        uint amount
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

import "./IPositionalMarket.sol";

interface IPosition {
    /* ========== VIEWS / VARIABLES ========== */

    function getBalanceOf(address account) external view returns (uint);

    function getTotalSupply() external view returns (uint);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

interface IPriceFeed {
    // Structs
    struct RateAndUpdatedTime {
        uint216 rate;
        uint40 time;
    }

    // Mutative functions
    function addAggregator(bytes32 currencyKey, address aggregatorAddress) external;

    function removeAggregator(bytes32 currencyKey) external;

    // Views

    function rateForCurrency(bytes32 currencyKey) external view returns (uint);

    function rateAndUpdatedTime(bytes32 currencyKey) external view returns (uint rate, uint time);

    function getRates() external view returns (uint[] memory);

    function getCurrencies() external view returns (bytes32[] memory);
}