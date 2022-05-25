// SPDX-License-Identifier: BUSL-1.1

/// @title  The administrator contract of Rubicon Pools
/// @author Rubicon DeFi Inc. - bghughes.eth
/// @notice The BathHouse initializes proxy-wrapped bathTokens, manages approved strategists, and sets system variables

pragma solidity =0.7.6;

import "./BathToken.sol";
import "../interfaces/IBathPair.sol";
import "../interfaces/IBathToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract BathHouse {
    /// *** Storage Variables ***

    /// @notice Rubicon Bath House
    string public name;

    /// @notice The administrator of the Bath House contract
    address public admin;

    /// @notice The proxy administrator of Bath Tokens
    address public proxyManager;

    /// @notice The core Rubicon Market of the Pools system
    address public RubiconMarketAddress;

    /// @notice A mapping of approved strategists to access Pools liquidity
    mapping(address => bool) public approvedStrategists;

    /// @notice The initialization status of BathHouse
    bool public initialized;

    /// @notice If true, strategists are permissioned and must be approved by admin
    bool public permissionedStrategists;

    /// @notice Key, system-wide risk parameter for all liquity Pools
    /// @notice This represents the proportion of a pool's underlying assets that must remain in the pool
    /// @dev This protects a run on the bank scenario and ensures users can withdraw while allowing funds to be utilized for yield in the market
    uint256 public reserveRatio;

    /// @notice A variable time delay after which a strategist must return funds to the Bath Token
    uint256 public timeDelay;

    /// @notice The lone Bath Pair contract of the system which acts as the strategist entry point and logic contract
    address public approvedPairContract;

    /// @notice The basis point fee that is paid to strategists from LPs on capital that is successfully rebalanced to a Bath Token
    uint8 public bpsToStrategists;

    /// @notice Key mapping for determining the address of a Bath Token based on its underlying asset
    /// @dev Source of truth mapping that logs all ERC20 Liquidity pools underlying asset => bathToken Address
    mapping(address => address) public tokenToBathToken;

    /// @notice The BathToken.sol implementation that any new bathTokens inherit
    /// @dev The implementation of any ~newly spawned~ proxy-wrapped Bath Tokens via _createBathToken
    address public newBathTokenImplementation;

    /// *** Events ***

    /// @notice An event that signals the creation of a new Bath Token
    event LogNewBathToken(
        address underlyingToken,
        address bathTokenAddress,
        address bathTokenFeeAdmin,
        uint256 timestamp,
        address bathTokenCreator
    );

    /// @notice An event that signals the permissionless spawning of a new Bath Token
    event LogOpenCreationSignal(
        ERC20 newERC20Underlying,
        address spawnedBathToken,
        uint256 initialNewBathTokenDeposit,
        ERC20 pairedExistingAsset,
        address pairedExistingBathToken,
        uint256 pairedBathTokenDeposit,
        address signaler
    );

    /// *** Modifiers ***

    /// @notice This modifier enforces that only the admin can call these functions
    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    /// *** External Functions ***

    /// @notice The constructor-like initialization function
    /// @dev Proxy-safe initialization of storage that sets key storage variables
    /// @dev Admin is set to msg.sender
    function initialize(
        address market,
        uint256 _reserveRatio,
        uint256 _timeDelay,
        address _newBathTokenImplementation,
        address _proxyAdmin
    ) external {
        require(!initialized);
        name = "Rubicon Bath House";
        admin = msg.sender;
        timeDelay = _timeDelay;

        // Set Bath Token reserve ratio globally
        require(_reserveRatio <= 100);
        require(_reserveRatio > 0);
        reserveRatio = _reserveRatio;

        // Set BPS reward fee for successful strategist market-making
        /// @notice [(10000 - {bpsToStrategists}) / 10000] BPS of MM-ing activity is passed to users
        bpsToStrategists = 20;

        // Set key storage variables
        RubiconMarketAddress = market;
        permissionedStrategists = true;
        newBathTokenImplementation = _newBathTokenImplementation;
        proxyManager = _proxyAdmin;

        // Automatically approve admin as an approved strategist
        approveStrategist(admin);

        // Complete contract instantiation
        initialized = true;
    }

    /// @notice Permissionless entry point to spawn a Bath Token while posting liquidity to a ~pair of Bath Tokens~
    /// @notice Please note, creating a Bath Token in this fashion ~does not~ gaurentee markets will be made for the new pair. This function signals the desire to have a new pair supported on Rubicon for strategists to consider market-making for
    /// @notice The best desiredPairedAsset to select is a popular quote currency. Many traditional systems quote in USD while the ETH quote is superior - the choice is yours sweet msg.sender
    /// @dev The user must approve the bathHouse to spend their ERC20s
    /// @dev The user can only spawn a Bath Token for an ERC20 that is not yet in the Pools system and they must post liquidity on the other side of the pair for an ~extant Bath Token~
    function openBathTokenSpawnAndSignal(
        ERC20 newBathTokenUnderlying,
        uint256 initialLiquidityNew, // Must approve this contract to spend
        ERC20 desiredPairedAsset, // Must be paired with an existing quote for v1
        uint256 initialLiquidityExistingBathToken
    ) external returns (address newBathToken) {
        // Check that it doesn't already exist
        require(
            getBathTokenfromAsset(newBathTokenUnderlying) == address(0),
            "bathToken already exists for that ERC20"
        );
        require(
            getBathTokenfromAsset(desiredPairedAsset) != address(0),
            "bathToken does not exist for that desiredPairedAsset"
        );

        // Spawn a bathToken for the new asset
        address newOne = _createBathToken(newBathTokenUnderlying, address(0)); // NOTE: address(0) as feeAdmin means fee is paid to pool holders

        // Deposit initial liquidity posted of newBathTokenUnderlying
        require(
            newBathTokenUnderlying.transferFrom(
                msg.sender,
                address(this),
                initialLiquidityNew
            ),
            "Couldn't transferFrom your initial liquidity - make sure to approve BathHouse.sol"
        );

        newBathTokenUnderlying.approve(newOne, initialLiquidityNew);

        // Deposit assets and send Bath Token shares to msg.sender
        IBathToken(newOne).deposit(initialLiquidityNew, msg.sender);

        // desiredPairedAsset must be pulled and deposited into bathToken
        require(
            desiredPairedAsset.transferFrom(
                msg.sender,
                address(this),
                initialLiquidityExistingBathToken
            ),
            "Couldn't transferFrom your initial liquidity - make sure to approve BathHouse.sol"
        );
        address pairedPool = getBathTokenfromAsset((desiredPairedAsset));
        desiredPairedAsset.approve(
            pairedPool,
            initialLiquidityExistingBathToken
        );

        // Deposit assets and send Bath Token shares to msg.sender
        IBathToken(pairedPool).deposit(
            initialLiquidityExistingBathToken,
            msg.sender
        );

        // emit an event describing the new pair, underlyings and bathTokens
        emit LogOpenCreationSignal(
            newBathTokenUnderlying,
            newOne,
            initialLiquidityNew,
            desiredPairedAsset,
            pairedPool,
            initialLiquidityExistingBathToken,
            msg.sender
        );

        newBathToken = newOne;
    }

    /// ** Admin-Only Functions **

    /// @notice An admin-only function to create a new Bath Token for any ERC20
    function createBathToken(ERC20 underlyingERC20, address _feeAdmin)
        external
        onlyAdmin
        returns (address newBathTokenAddress)
    {
        newBathTokenAddress = _createBathToken(underlyingERC20, _feeAdmin);
    }

    /// @notice A migration function that allows the admin to write arbitrarily to tokenToBathToken
    function adminWriteBathToken(ERC20 overwriteERC20, address newBathToken)
        external
        onlyAdmin
    {
        tokenToBathToken[address(overwriteERC20)] = newBathToken;
        emit LogNewBathToken(
            address(overwriteERC20),
            newBathToken,
            address(0),
            block.timestamp,
            msg.sender
        );
    }

    /// @notice Function to initialize and store the address of the ~lone~ bathPair contract for the Rubicon protocol
    function initBathPair(
        address _bathPairAddress,
        uint256 _maxOrderSizeBPS,
        int128 _shapeCoefNum
    ) external onlyAdmin returns (address newPair) {
        require(
            approvedPairContract == address(0),
            "BathPair already approved"
        );
        require(
            IBathPair(_bathPairAddress).initialized() != true,
            "BathPair already initialized"
        );
        newPair = _bathPairAddress;

        IBathPair(newPair).initialize(_maxOrderSizeBPS, _shapeCoefNum);

        approvedPairContract = newPair;
    }

    /// @notice Admin-only function to set a new Admin
    function setBathHouseAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }

    /// @notice Admin-only function to set a new Bath Token implementation
    /// @dev Please note that all bathTokens created will use this abi
    function setNewBathTokenImplementation(address newImplementation)
        external
        onlyAdmin
    {
        newBathTokenImplementation = newImplementation;
    }

    /// @notice Admin-only function to approve a new permissioned strategist
    function approveStrategist(address strategist) public onlyAdmin {
        approvedStrategists[strategist] = true;
    }

    /// @notice Admin-only function to set whether or not strategists are permissioned
    function setPermissionedStrategists(bool _new) external onlyAdmin {
        permissionedStrategists = _new;
    }

    /// @notice Admin-only function to set timeDelay
    function setCancelTimeDelay(uint256 value) external onlyAdmin {
        timeDelay = value;
    }

    /// @notice Admin-only function to set reserveRatio
    function setReserveRatio(uint256 rr) external onlyAdmin {
        require(rr <= 100);
        require(rr > 0);
        reserveRatio = rr;
    }

    /// @notice Admin-only function to set a Bath Token's timeDelay
    function setBathTokenMarket(address bathToken, address newMarket)
        external
        onlyAdmin
    {
        IBathToken(bathToken).setMarket(newMarket);
    }

    /// @notice Admin-only function to add a bonus token to a Bath Token's reward schema
    function setBonusToken(address bathToken, address newBonusToken)
        external
        onlyAdmin
    {
        IBathToken(bathToken).setBonusToken(newBonusToken);
    }

    /// @notice Admin-only function to set a Bath Token's Bath House admin
    function setBathTokenBathHouse(address bathToken, address newAdmin)
        external
        onlyAdmin
    {
        IBathToken(bathToken).setBathHouse(newAdmin);
    }

    /// @notice Admin-only function to set a Bath Token's feeBPS
    function setBathTokenFeeBPS(address bathToken, uint256 newBPS)
        external
        onlyAdmin
    {
        IBathToken(bathToken).setFeeBPS(newBPS);
    }

    /// @notice Admin-only function to approve the Bath Token's underlying token on the assigned market
    /// @dev required in case the market address ever changes.. #battleScars
    function bathTokenApproveSetMarket(address targetBathToken)
        external
        onlyAdmin
    {
        IBathToken(targetBathToken).approveMarket();
    }

    /// @notice Admin-only function to set a Bath Token's fee recipient (typically the Bath Token itself)
    function setBathTokenFeeTo(address bathToken, address feeTo)
        external
        onlyAdmin
    {
        IBathToken(bathToken).setFeeTo(feeTo);
    }

    /// @notice Admin-only function to set a Bath Token's target Rubicon Market
    function setMarket(address newMarket) external onlyAdmin {
        RubiconMarketAddress = newMarket;
    }

    /// @notice funtion to set bpsToStrategists
    function setBPSToStrategists(uint8 newBPS) external onlyAdmin {
        bpsToStrategists = newBPS;
    }

    /// *** View Functions ***

    // Getter Functions for parameters
    function getMarket() external view returns (address) {
        return RubiconMarketAddress;
    }

    function getReserveRatio() external view returns (uint256) {
        return reserveRatio;
    }

    function getCancelTimeDelay() external view returns (uint256) {
        return timeDelay;
    }

    /// @notice Returns the address of any bathToken in the system based on its corresponding underlying asset
    function getBathTokenfromAsset(ERC20 asset) public view returns (address) {
        return tokenToBathToken[address(asset)];
    }

    function getBPSToStrats() public view returns (uint8) {
        return bpsToStrategists;
    }

    /// *** System Security Checks ***

    /// @notice A function to check whether or not an address is an approved strategist
    function isApprovedStrategist(address wouldBeStrategist)
        external
        view
        returns (bool)
    {
        if (
            approvedStrategists[wouldBeStrategist] == true ||
            !permissionedStrategists
        ) {
            return true;
        } else {
            return false;
        }
    }

    /// @notice A function to check whether or not an address is the approved system instance of BathPair.sol
    function isApprovedPair(address pair) public view returns (bool outcome) {
        pair == approvedPairContract ? outcome = true : outcome = false;
    }

    /// *** Internal Functions ***

    /// @dev Low-level functionality to spawn a Bath Token using the OZ Transparent Upgradeable Proxy standard
    /// @param underlyingERC20 The underlying ERC-20 asset that underlies the newBathTokenAddress
    /// @param _feeAdmin Recipient of pool withdrawal fees, typically the pool itself
    function _createBathToken(ERC20 underlyingERC20, address _feeAdmin)
        internal
        returns (address newBathTokenAddress)
    {
        require(initialized, "BathHouse not initialized");
        address _underlyingERC20 = address(underlyingERC20);
        require(
            _underlyingERC20 != address(0),
            "Cant create bathToken for zero address"
        );

        // Check that it isn't already logged in the registry
        require(
            tokenToBathToken[_underlyingERC20] == address(0),
            "bathToken already exists"
        );

        // Creates a new bathToken that is upgradeable by the proxyManager
        require(
            newBathTokenImplementation != address(0),
            "no implementation set for bathTokens"
        );

        // Note, the option of a fee recipient for pool withdrawls exists. For all pools this is set to the pool itself in production and is visible via ~feeTo~ on any respective contract
        // Note, fee admin presently ignored in the Bath Token initialization() call via defaulting to itself; though, this is still upgradeable by the Bath House admin via
        bytes memory _initData = abi.encodeWithSignature(
            "initialize(address,address,address)",
            _underlyingERC20,
            (RubiconMarketAddress),
            (_feeAdmin)
        );

        TransparentUpgradeableProxy newBathToken = new TransparentUpgradeableProxy(
                newBathTokenImplementation,
                proxyManager,
                _initData
            );

        // New Bath Token Address
        newBathTokenAddress = address(newBathToken);

        // Write to source-of-truth router mapping for this ERC-20 => Bath Token
        tokenToBathToken[_underlyingERC20] = newBathTokenAddress;

        // Log Data
        emit LogNewBathToken(
            _underlyingERC20,
            newBathTokenAddress,
            _feeAdmin,
            block.timestamp,
            msg.sender
        );
    }
}

// SPDX-License-Identifier: BUSL-1.1

/// @author Rubicon DeFi Inc. - bghughes.eth
/// @notice This contract represents a single-asset liquidity pool for Rubicon Pools
/// @notice Any user can deposit assets into this pool and earn yield from successful strategist market making with their liquidity
/// @notice This contract looks to both BathPairs and the BathHouse as its admin

pragma solidity =0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IBathHouse.sol";
import "../interfaces/IRubiconMarket.sol";
import "../interfaces/IVestingWallet.sol";

contract BathToken {
    using SafeMath for uint256;

    /// *** Storage Variables ***

    /// @notice The initialization status of the Bath Token
    bool public initialized;

    /// @notice  ** ERC-20 **
    string public symbol;
    string public name;
    uint8 public decimals;

    /// @notice The RubiconMarket.sol instance that all pool liquidity is intially directed to as market-making offers
    address public RubiconMarketAddress;

    /// @notice The Bath House admin of the Bath Token
    address public bathHouse;

    /// @notice The withdrawal fee recipient, typically the Bath Token itself
    address public feeTo;

    /// @notice The underlying ERC-20 token which is the core asset of the Bath Token vault
    IERC20 public underlyingToken;

    /// @notice The basis point fee rate that is paid on withdrawing the underlyingToken and bonusTokens
    uint256 public feeBPS;

    /// @notice ** ERC-20 **
    uint256 public totalSupply;

    /// @notice The amount of underlying deposits that are outstanding attempting market-making on the order book for yield
    /// @dev quantity of underlyingToken that is in the orderbook that the pool still has a claim on
    /// @dev The underlyingToken is effectively mark-to-marketed when it enters the book and it could be returned at a loss due to poor strategist performance
    /// @dev outstandingAmount is NOT inclusive of any non-underlyingToken assets sitting on the Bath Tokens that have filled to here and are awaiting rebalancing to the underlyingToken by strategists
    uint256 public outstandingAmount;

    /// @dev Intentionally unused DEPRECATED STORAGE VARIABLE to maintain contiguous state on proxy-wrapped contracts. Consider it a beautiful scar of incremental progress 📈
    /// @dev Keeping deprecated variables maintains consistent network-agnostic contract abis when moving to new chains and versions
    uint256[] deprecatedStorageArray; // Kept in to avoid storage collision bathTokens that are proxy upgraded

    /// @dev Intentionally unused DEPRECATED STORAGE VARIABLE to maintain contiguous state on proxy-wrapped contracts. Consider it a beautiful scar of incremental progress 📈
    mapping(uint256 => uint256) deprecatedMapping; // Kept in to avoid storage collision on bathTokens that are upgraded
    // *******************************************

    /// @notice  ** ERC-20 **
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /// @notice EIP-2612
    bytes32 public DOMAIN_SEPARATOR;

    /// @notice EIP-2612
    /// @dev keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /// @notice EIP-2612
    mapping(address => uint256) public nonces;

    /// @notice Array of Bonus ERC-20 tokens that are given as liquidity incentives to pool withdrawers
    address[] public bonusTokens;

    /// @notice Address of the OZ Vesting Wallet which acts as means to vest bonusToken incentives to pool HODLers
    IVestingWallet public rewardsVestingWallet;

    /// *** Events ***

    /// @notice ** ERC-20 **
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /// @notice ** ERC-20 **
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Time of Bath Token instantiation
    event LogInit(uint256 timeOfInit);

    /// @notice Log details about a pool deposit
    event LogDeposit(
        uint256 depositedAmt,
        IERC20 asset,
        uint256 sharesReceived,
        address depositor,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice Log details about a pool withdraw
    event LogWithdraw(
        uint256 amountWithdrawn,
        IERC20 asset,
        uint256 sharesWithdrawn,
        address withdrawer,
        uint256 fee,
        address feeTo,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice Log details about a pool rebalance
    event LogRebalance(
        IERC20 pool_asset,
        address destination,
        IERC20 transferAsset,
        uint256 rebalAmt,
        uint256 stratReward,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice Log details about a pool order canceled in the Rubicon Market book
    event LogPoolCancel(
        uint256 orderId,
        IERC20 pool_asset,
        uint256 outstandingAmountToCancel,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice Log details about a pool order placed in the Rubicon Market book
    event LogPoolOffer(
        uint256 id,
        IERC20 pool_asset,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice Log the credit to outstanding amount for funds that have been filled market-making
    event LogRemoveFilledTradeAmount(
        IERC20 pool_asset,
        uint256 fillAmount,
        uint256 underlyingBalance,
        uint256 outstandingAmount,
        uint256 totalSupply
    );

    /// @notice * EIP 4626 *
    event Deposit(
        address indexed caller,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /// @notice * EIP 4626 *
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /// @notice Log bonus token reward event
    event LogClaimBonusTokn(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares,
        IERC20 bonusToken
    );

    /// *** Constructor ***

    /// @notice Proxy-safe initialization of storage; the constructor
    function initialize(
        ERC20 token,
        address market,
        address _feeTo
    ) external {
        require(!initialized);
        string memory _symbol = string(
            abi.encodePacked(("bath"), token.symbol())
        );
        symbol = _symbol;
        underlyingToken = token;
        RubiconMarketAddress = market;
        bathHouse = msg.sender; //NOTE: assumed admin is creator on BathHouse

        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
        name = string(abi.encodePacked(_symbol, (" v1")));
        decimals = token.decimals(); // v1 Change - 4626 Adherence

        // Add infinite approval of Rubicon Market for this asset
        IERC20(address(token)).approve(RubiconMarketAddress, 2**256 - 1);
        emit LogInit(block.timestamp);

        feeTo = address(this); //This contract is the fee recipient, rewarding HODLers
        feeBPS = 3; //Fee set to 3 BPS initially

        // Complete constract instantiation
        initialized = true;
    }

    /// *** Modifiers ***

    modifier onlyPair() {
        require(
            IBathHouse(bathHouse).isApprovedPair(msg.sender) == true,
            "not an approved pair - bathToken"
        );
        _;
    }

    modifier onlyBathHouse() {
        require(
            msg.sender == bathHouse,
            "caller is not bathHouse - BathToken.sol"
        );
        _;
    }

    /// *** External Functions - Only Bath House / Admin ***

    /// @notice Admin-only function to set a Bath Token's market address
    function setMarket(address newRubiconMarket) external onlyBathHouse {
        RubiconMarketAddress = newRubiconMarket;
    }

    /// @notice Admin-only function to set a Bath Token's Bath House admin
    function setBathHouse(address newBathHouse) external onlyBathHouse {
        bathHouse = newBathHouse;
    }

    /// @notice Admin-only function to approve Bath Token's RubiconMarketAddress with the maximum integer value (infinite approval)
    function approveMarket() external onlyBathHouse {
        underlyingToken.approve(RubiconMarketAddress, 2**256 - 1);
    }

    /// @notice Admin-only function to set a Bath Token's feeBPS
    function setFeeBPS(uint256 _feeBPS) external onlyBathHouse {
        feeBPS = _feeBPS;
    }

    /// @notice Admin-only function to set a Bath Token's fee recipient, typically the pool itself
    function setFeeTo(address _feeTo) external onlyBathHouse {
        feeTo = _feeTo;
    }

    /// @notice Admin-only function to add a bonus token to bonusTokens for pool incentives
    function setBonusToken(address newBonusERC20) external onlyBathHouse {
        bonusTokens.push(newBonusERC20);
    }

    /// *** External Functions - Only Approved Bath Pair / Strategist Contract ***

    /// ** Rubicon Market Functions **

    /// @notice The function for a strategist to cancel an outstanding Market Offer
    function cancel(uint256 id, uint256 amt) external onlyPair {
        outstandingAmount = outstandingAmount.sub(amt);
        IRubiconMarket(RubiconMarketAddress).cancel(id);

        emit LogPoolCancel(
            id,
            IERC20(underlyingToken),
            amt,
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
    }

    /// @notice A function called by BathPair to maintain proper accounting of outstandingAmount
    function removeFilledTradeAmount(uint256 amt) external onlyPair {
        outstandingAmount = outstandingAmount.sub(amt);
        emit LogRemoveFilledTradeAmount(
            IERC20(underlyingToken),
            amt,
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
    }

    /// @notice The function that places a bid and/or ask in the orderbook for a given pair from this pool
    function placeOffer(
        uint256 pay_amt,
        ERC20 pay_gem,
        uint256 buy_amt,
        ERC20 buy_gem
    ) external onlyPair returns (uint256) {
        // Place an offer in RubiconMarket
        // If incomplete offer return 0
        if (
            pay_amt == 0 ||
            pay_gem == ERC20(0) ||
            buy_amt == 0 ||
            buy_gem == ERC20(0)
        ) {
            return 0;
        }

        uint256 id = IRubiconMarket(RubiconMarketAddress).offer(
            pay_amt,
            pay_gem,
            buy_amt,
            buy_gem,
            0,
            false
        );
        outstandingAmount = outstandingAmount.add(pay_amt);

        emit LogPoolOffer(
            id,
            IERC20(underlyingToken),
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
        return (id);
    }

    /// @notice This function returns filled orders to the correct liquidity pool and sends strategist rewards to the Bath Pair
    /// @dev Sends non-underlyingToken fill elsewhere in the Pools system, typically it's sister asset within a trading pair (e.g. ETH-USDC)
    /// @dev Strategists presently accrue rewards in the filled asset not underlyingToken
    function rebalance(
        address destination,
        address filledAssetToRebalance, /* sister or fill asset */
        uint256 stratProportion,
        uint256 rebalAmt
    ) external onlyPair {
        uint256 stratReward = (stratProportion.mul(rebalAmt)).div(10000);
        IERC20(filledAssetToRebalance).transfer(
            destination,
            rebalAmt.sub(stratReward)
        );
        IERC20(filledAssetToRebalance).transfer(msg.sender, stratReward);

        emit LogRebalance(
            IERC20(underlyingToken),
            destination,
            IERC20(filledAssetToRebalance),
            rebalAmt,
            stratReward,
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
    }

    /// *** EIP 4626 Implementation ***
    // https://eips.ethereum.org/EIPS/eip-4626#specification

    /// @notice Withdraw your bathTokens for the underlyingToken
    function withdraw(uint256 _shares)
        external
        returns (uint256 amountWithdrawn)
    {
        return _withdraw(_shares, msg.sender);
    }

    /// @notice * EIP 4626 *
    function asset() public view returns (address assetTokenAddress) {
        assetTokenAddress = address(underlyingToken);
    }

    /// @notice * EIP 4626 *
    function totalAssets() public view returns (uint256 totalManagedAssets) {
        return underlyingBalance();
    }

    /// @notice * EIP 4626 *
    function convertToShares(uint256 assets)
        public
        view
        returns (uint256 shares)
    {
        // Note: Inflationary tokens may affect this logic
        (totalSupply == 0) ? shares = assets : shares = (
            assets.mul(totalSupply)
        )
        .div(totalAssets());
    }

    // Note: MUST NOT be inclusive of any fees that are charged against assets in the Vault.
    /// @notice * EIP 4626 *
    function convertToAssets(uint256 shares)
        public
        view
        returns (uint256 assets)
    {
        assets = (totalAssets().mul(shares)).div(totalSupply);
    }

    // Note: Unused function param to adhere to standard
    /// @notice * EIP 4626 *
    function maxDeposit(address receiver)
        public
        pure
        returns (uint256 maxAssets)
    {
        maxAssets = 2**256 - 1; // No limit on deposits in current implementation  = Max UINT
    }

    /// @notice * EIP 4626 *
    function previewDeposit(uint256 assets)
        public
        view
        returns (uint256 shares)
    {
        // The exact same logic is used, no deposit fee - only difference is deflationary token check (rare condition and probably redundant)
        shares = convertToShares(assets);
    }

    // Single asset override to reflect old functionality
    function deposit(uint256 assets) public returns (uint256 shares) {
        // Note: msg.sender is the same throughout the same contract context
        return _deposit(assets, msg.sender);
    }

    /// @notice * EIP 4626 *
    function deposit(uint256 assets, address receiver)
        public
        returns (uint256 shares)
    {
        return _deposit(assets, receiver);
    }

    // Note: Unused function param to adhere to standard
    /// @notice * EIP 4626 *
    function maxMint(address receiver) public pure returns (uint256 maxShares) {
        maxShares = 2**256 - 1; // No limit on shares that could be created via deposit in current implementation - Max UINT
    }

    // Given I want these shares, how much do I have to deposit
    /// @notice * EIP 4626 *
    function previewMint(uint256 shares) public view returns (uint256 assets) {
        (totalSupply == 0) ? assets = shares : assets = (
            shares.mul(totalAssets())
        )
        .div(totalSupply);
    }

    // Mints exactly shares Vault shares to receiver by depositing amount of underlying tokens.
    /// @notice * EIP 4626 *
    function mint(uint256 shares, address receiver)
        public
        returns (uint256 assets)
    {
        assets = previewMint(shares);
        uint256 _shares = _deposit(assets, receiver);
        require(_shares == shares, "did not mint expected share count");
    }

    // A user can withdraw whatever they hold
    /// @notice * EIP 4626 *
    function maxWithdraw(address owner)
        public
        view
        returns (uint256 maxAssets)
    {
        if (totalSupply == 0) {
            maxAssets = 0;
        } else {
            uint256 ownerShares = balanceOf[owner];
            maxAssets = convertToAssets(ownerShares);
        }
    }

    /// @notice * EIP 4626 *
    function previewWithdraw(uint256 assets)
        public
        view
        returns (uint256 shares)
    {
        if (totalSupply == 0) {
            shares = 0;
        } else {
            uint256 amountWithdrawn;
            uint256 _fee = assets.mul(feeBPS).div(10000);
            amountWithdrawn = assets.sub(_fee);
            shares = convertToShares(amountWithdrawn);
        }
    }

    /// @notice * EIP 4626 *
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public returns (uint256 shares) {
        require(
            owner == msg.sender,
            "This implementation does not support non-sender owners from withdrawing user shares"
        );
        uint256 expectedShares = previewWithdraw(assets);
        uint256 assetsReceived = _withdraw(expectedShares, receiver);
        require(
            assetsReceived >= assets,
            "You cannot withdraw the amount of assets you expected"
        );
        shares = expectedShares;
    }

    // Constraint: msg.sender is owner of shares when withdrawing
    /// @notice * EIP 4626 *
    function maxRedeem(address owner) public view returns (uint256 maxShares) {
        return balanceOf[owner];
    }

    // Constraint: msg.sender is owner of shares when withdrawing
    /// @notice * EIP 4626 *
    function previewRedeem(uint256 shares)
        public
        view
        returns (uint256 assets)
    {
        uint256 r = (underlyingBalance().mul(shares)).div(totalSupply);
        uint256 _fee = r.mul(feeBPS).div(10000);
        assets = r.sub(_fee);
    }

    /// @notice * EIP 4626 *
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public returns (uint256 assets) {
        require(
            owner == msg.sender,
            "This implementation does not support non-sender owners from withdrawing user shares"
        );
        assets = _withdraw(shares, receiver);
    }

    /// *** Internal Functions ***

    /// @notice Deposit assets for the user and mint Bath Token shares to receiver
    function _deposit(uint256 assets, address receiver)
        internal
        returns (uint256 shares)
    {
        uint256 _pool = underlyingBalance();
        uint256 _before = underlyingToken.balanceOf(address(this));

        // **Assume caller is depositor**
        underlyingToken.transferFrom(msg.sender, address(this), assets);
        uint256 _after = underlyingToken.balanceOf(address(this));
        assets = _after.sub(_before); // Additional check for deflationary tokens

        (totalSupply == 0) ? shares = assets : shares = (
            assets.mul(totalSupply)
        )
        .div(_pool);


        // Send shares to designated target
        _mint(receiver, shares);
        emit LogDeposit(
            assets,
            underlyingToken,
            shares,
            msg.sender,
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
        emit Deposit(msg.sender, msg.sender, assets, shares);
    }

    /// @notice Withdraw share for the user and send underlyingToken to receiver with any accrued yield and incentive tokens
    function _withdraw(uint256 _shares, address receiver)
        internal
        returns (uint256 amountWithdrawn)
    {
        uint256 _initialTotalSupply = totalSupply;

        // Distribute network rewards first in order to handle bonus token == underlying token case; it only releases vested tokens in this call
        distributeBonusTokenRewards(receiver, _shares, _initialTotalSupply);

        uint256 r = (underlyingBalance().mul(_shares)).div(_initialTotalSupply);
        _burn(msg.sender, _shares);
        uint256 _fee = r.mul(feeBPS).div(10000);
        // If FeeTo == address(0) then the fee is effectively accrued by the pool
        if (feeTo != address(0)) {
            underlyingToken.transfer(feeTo, _fee);
        }
        amountWithdrawn = r.sub(_fee);
        underlyingToken.transfer(receiver, amountWithdrawn);

        emit LogWithdraw(
            amountWithdrawn,
            underlyingToken,
            _shares,
            msg.sender,
            _fee,
            feeTo,
            underlyingBalance(),
            outstandingAmount,
            totalSupply
        );
        emit Withdraw(
            msg.sender,
            receiver,
            msg.sender,
            amountWithdrawn,
            _shares
        );
    }

    /// @notice Function to distibute non-underlyingToken Bath Token incentives to pool withdrawers
    /// @dev Note that bonusTokens adhere to the same feeTo and feeBPS pattern
    /// @dev Note the edge case in which the bonus token is the underlyingToken, here we simply release() to the pool and skip
    function distributeBonusTokenRewards(
        address receiver,
        uint256 sharesWithdrawn,
        uint256 initialTotalSupply
    ) internal {
        // Verbose check:
        // require(initialTotalSupply == sharesWithdrawn + totalSupply);
        if (bonusTokens.length > 0) {
            for (uint256 index = 0; index < bonusTokens.length; index++) {
                IERC20 token = IERC20(bonusTokens[index]);

                // Pair each bonus token with an OZ Vesting wallet. Each time a user withdraws, they can release() the
                //  vested amount to this pool. Note, this pool must be the beneficiary of the VestingWallet.
                if (rewardsVestingWallet != IVestingWallet(0)) {
                    rewardsVestingWallet.release(address(token));
                }

                // avoid underlyingToken == token double spend
                if (address(token) == address(underlyingToken)) {
                    continue; // Skip because logic below fails on underlying token and release() already called so bonus tokens are already accrued and withdrawn
                }

                uint256 bonusTokenBalance = token.balanceOf(address(this));
                if (bonusTokenBalance > 0) {
                    uint256 amount = bonusTokenBalance.mul(sharesWithdrawn).div(
                        initialTotalSupply
                    );
                    // Note: Shares already burned in _withdraw

                    uint256 _fee = amount.mul(feeBPS).div(10000);
                    // If FeeTo == address(0) then the fee is effectively accrued by the pool
                    if (feeTo != address(0)) {
                        token.transfer(feeTo, _fee);
                    }
                    uint256 amountWithdrawn = amount.sub(_fee);
                    token.transfer(receiver, amountWithdrawn);

                    emit LogClaimBonusTokn(
                        msg.sender,
                        receiver,
                        msg.sender,
                        amountWithdrawn,
                        sharesWithdrawn,
                        token
                    );
                }
            }
        }
    }

    /// *** ERC - 20 Standard ***

    function _mint(address to, uint256 value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        if (allowance[from][msg.sender] != uint256(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(
                value
            );
        }
        _transfer(from, to, value);
        return true;
    }

    /// @notice EIP 2612
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp, "bathToken: EXPIRED");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        nonces[owner]++,
                        deadline
                    )
                )
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(
            recoveredAddress != address(0) && recoveredAddress == owner,
            "bathToken: INVALID_SIGNATURE"
        );
        _approve(owner, spender, value);
    }

    /// *** View Functions ***

    /// @notice The underlying ERC-20 that this bathToken handles
    function underlyingERC20() external view returns (address) {
        return address(underlyingToken);
    }

    /// @notice The best-guess total claim on assets the Bath Token has
    /// @dev returns the amount of underlying ERC20 tokens in this pool in addition to any tokens that are outstanding in the Rubicon order book seeking market-making yield (outstandingAmount)
    function underlyingBalance() public view returns (uint256) {
        uint256 _pool = IERC20(underlyingToken).balanceOf(address(this));
        return _pool.add(outstandingAmount);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.7.6;

interface IBathPair {
    function initialized() external returns (bool);

    function initialize(uint256 _maxOrderSizeBPS, int128 _shapeCoefNum)
        external;

    function setMaxOrderSizeBPS(uint16 val) external;

    function setShapeCoefNum(int128 val) external;
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBathToken is IERC20 {
    function removeFilledTradeAmount(uint256 amt) external;

    function cancel(uint256 id, uint256 amt) external;

    function placeOffer(
        uint256 pay_amt,
        IERC20 pay_gem,
        uint256 buy_amt,
        IERC20 buy_gem
    ) external returns (uint256);

    function rebalance(
        address destination,
        address filledAssetToRebalance,
        uint256 stratTakeProportion,
        uint256 rebalAmt
    ) external;

    // Note: commenting out assuming that delegatecalls to the target will suffice, maybe needed for v0 migration ease of upgradeability... trying it out
    // function initialize(
    //     IERC20 token,
    //     address market,
    //     address _bathHouse,
    //     address _feeTo
    // ) external;

    function approveMarket() external;

    function underlyingToken() external returns (IERC20 erc20);

    function bathHouse() external returns (address admin);

    function setBathHouse(address newBathHouse) external;

    function setMarket(address newRubiconMarket) external;

    function setBonusToken(address newBonusToken) external;

    function setFeeBPS(uint256 _feeBPS) external;

    function setFeeTo(address _feeTo) external;

    function RubiconMarketAddress() external returns (address market);

    function outstandingAmount() external returns (uint256 amount);

    function underlyingBalance() external view returns (uint256);

    function deposit(uint256 amount) external returns (uint256 shares);

    function deposit(uint256 assets, address receiver)
        external
        returns (uint256 shares);

    function withdraw(uint256 shares) external returns (uint256 amount);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/Context.sol";
import "./IERC20.sol";
import "../../math/SafeMath.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./UpgradeableProxy.sol";

/**
 * @dev This contract implements a proxy that is upgradeable by an admin.
 *
 * To avoid https://medium.com/nomic-labs-blog/malicious-backdoors-in-ethereum-proxies-62629adf3357[proxy selector
 * clashing], which can potentially be used in an attack, this contract uses the
 * https://blog.openzeppelin.com/the-transparent-proxy-pattern/[transparent proxy pattern]. This pattern implies two
 * things that go hand in hand:
 *
 * 1. If any account other than the admin calls the proxy, the call will be forwarded to the implementation, even if
 * that call matches one of the admin functions exposed by the proxy itself.
 * 2. If the admin calls the proxy, it can access the admin functions, but its calls will never be forwarded to the
 * implementation. If the admin tries to call a function on the implementation it will fail with an error that says
 * "admin cannot fallback to proxy target".
 *
 * These properties mean that the admin account can only be used for admin actions like upgrading the proxy or changing
 * the admin, so it's best if it's a dedicated account that is not used for anything else. This will avoid headaches due
 * to sudden errors when trying to call a function from the proxy implementation.
 *
 * Our recommendation is for the dedicated account to be an instance of the {ProxyAdmin} contract. If set up this way,
 * you should think of the `ProxyAdmin` instance as the real administrative interface of your proxy.
 */
contract TransparentUpgradeableProxy is UpgradeableProxy {
    /**
     * @dev Initializes an upgradeable proxy managed by `_admin`, backed by the implementation at `_logic`, and
     * optionally initialized with `_data` as explained in {UpgradeableProxy-constructor}.
     */
    constructor(address _logic, address admin_, bytes memory _data) public payable UpgradeableProxy(_logic, _data) {
        assert(_ADMIN_SLOT == bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1));
        _setAdmin(admin_);
    }

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 private constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Modifier used internally that will delegate the call to the implementation unless the sender is the admin.
     */
    modifier ifAdmin() {
        if (msg.sender == _admin()) {
            _;
        } else {
            _fallback();
        }
    }

    /**
     * @dev Returns the current admin.
     *
     * NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyAdmin}.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function admin() external ifAdmin returns (address admin_) {
        admin_ = _admin();
    }

    /**
     * @dev Returns the current implementation.
     *
     * NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyImplementation}.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`
     */
    function implementation() external ifAdmin returns (address implementation_) {
        implementation_ = _implementation();
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     *
     * NOTE: Only the admin can call this function. See {ProxyAdmin-changeProxyAdmin}.
     */
    function changeAdmin(address newAdmin) external virtual ifAdmin {
        require(newAdmin != address(0), "TransparentUpgradeableProxy: new admin is the zero address");
        emit AdminChanged(_admin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev Upgrade the implementation of the proxy.
     *
     * NOTE: Only the admin can call this function. See {ProxyAdmin-upgrade}.
     */
    function upgradeTo(address newImplementation) external virtual ifAdmin {
        _upgradeTo(newImplementation);
    }

    /**
     * @dev Upgrade the implementation of the proxy, and then call a function from the new implementation as specified
     * by `data`, which should be an encoded function call. This is useful to initialize new storage variables in the
     * proxied contract.
     *
     * NOTE: Only the admin can call this function. See {ProxyAdmin-upgradeAndCall}.
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable virtual ifAdmin {
        _upgradeTo(newImplementation);
        Address.functionDelegateCall(newImplementation, data);
    }

    /**
     * @dev Returns the current admin.
     */
    function _admin() internal view virtual returns (address adm) {
        bytes32 slot = _ADMIN_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            adm := sload(slot)
        }
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        bytes32 slot = _ADMIN_SLOT;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, newAdmin)
        }
    }

    /**
     * @dev Makes sure the admin cannot access the fallback function. See {Proxy-_beforeFallback}.
     */
    function _beforeFallback() internal virtual override {
        require(msg.sender != _admin(), "TransparentUpgradeableProxy: admin cannot fallback to proxy target");
        super._beforeFallback();
    }
}

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

// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.7.6;

interface IBathHouse {
    function getMarket() external view returns (address);

    function initialized() external returns (bool);

    function reserveRatio() external view returns (uint256);

    function tokenToBathToken(address erc20Address)
        external
        view
        returns (address bathTokenAddress);

    function isApprovedStrategist(address wouldBeStrategist)
        external
        view
        returns (bool);

    function getBPSToStrats() external view returns (uint8);

    function isApprovedPair(address pair) external view returns (bool);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRubiconMarket {
    function cancel(uint256 id) external;

    function offer(
        uint256 pay_amt, //maker (ask) sell how much
        IERC20 pay_gem, //maker (ask) sell which token
        uint256 buy_amt, //maker (ask) buy how much
        IERC20 buy_gem, //maker (ask) buy which token
        uint256 pos, //position to insert offer, 0 should be used if unknown
        bool matching //match "close enough" orders?
    ) external returns (uint256);

    // Get best offer
    function getBestOffer(IERC20 sell_gem, IERC20 buy_gem)
        external
        view
        returns (uint256);

    // get offer
    function getOffer(uint256 id)
        external
        view
        returns (
            uint256,
            IERC20,
            uint256,
            IERC20
        );
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6;

interface IVestingWallet {
    function beneficiary() external view returns (address);

    function release(address token) external;

    function vestedAmount(address token, uint64 timestamp)
        external
        view
        returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./Proxy.sol";
import "../utils/Address.sol";

/**
 * @dev This contract implements an upgradeable proxy. It is upgradeable because calls are delegated to an
 * implementation address that can be changed. This address is stored in storage in the location specified by
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967], so that it doesn't conflict with the storage layout of the
 * implementation behind the proxy.
 *
 * Upgradeability is only provided internally through {_upgradeTo}. For an externally upgradeable proxy see
 * {TransparentUpgradeableProxy}.
 */
contract UpgradeableProxy is Proxy {
    /**
     * @dev Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
     *
     * If `_data` is nonempty, it's used as data in a delegate call to `_logic`. This will typically be an encoded
     * function call, and allows initializating the storage of the proxy like a Solidity constructor.
     */
    constructor(address _logic, bytes memory _data) public payable {
        assert(_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));
        _setImplementation(_logic);
        if(_data.length > 0) {
            Address.functionDelegateCall(_logic, _data);
        }
    }

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Returns the current implementation address.
     */
    function _implementation() internal view virtual override returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            impl := sload(slot)
        }
    }

    /**
     * @dev Upgrades the proxy to a new implementation.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal virtual {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "UpgradeableProxy: new implementation is not a contract");

        bytes32 slot = _IMPLEMENTATION_SLOT;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, newImplementation)
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internall call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /**
     * @dev This is a virtual function that should be overriden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internall call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _beforeFallback();
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback () external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive () external payable virtual {
        _fallback();
    }

    /**
     * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
     * call, or as part of the Solidity `fallback` or `receive` functions.
     *
     * If overriden should call `super._beforeFallback()`.
     */
    function _beforeFallback() internal virtual {
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

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