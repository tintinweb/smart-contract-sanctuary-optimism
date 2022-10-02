// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.3;

import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import { SafeCastUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IPerpetualMixDEXWrapper } from "../interfaces/IPerpetualMixDEXWrapper.sol";
import { SafeMathExt } from "../libraries/SafeMathExt.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "../interfaces/IERC20Decimals.sol";
import "../interfaces/IUSDLemma.sol";
import "../interfaces/Perpetual/IClearingHouse.sol";
import "../interfaces/Perpetual/IClearingHouseConfig.sol";
import "../interfaces/Perpetual/IIndexPrice.sol";
import "../interfaces/Perpetual/IAccountBalance.sol";
import "../interfaces/Perpetual/IMarketRegistry.sol";
import "../interfaces/Perpetual/IPerpVault.sol";
import "../interfaces/Perpetual/IBaseToken.sol";
import "../interfaces/Perpetual/IExchange.sol";

/// @author Lemma Finance
/// @notice PerpLemmaCommon contract will use to open short and long position with no-leverage on perpetual protocol (v2)
/// USDLemma and LemmaSynth will consume the methods to open short or long on derivative dex
/// Every collateral has different PerpLemma deployed, and after deployment it will be added in USDLemma contract and corresponding LemmaSynth's perpetualDEXWrappers mapping
contract PerpLemmaCommon is ERC2771ContextUpgradeable, IPerpetualMixDEXWrapper, AccessControlUpgradeable {
    using SafeCastUpgradeable for uint256;
    using SafeCastUpgradeable for int256;
    using SafeMathExt for int256;

    // Different Roles to perform restricted tx
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant USDC_TREASURY = keccak256("USDC_TREASURY");
    bytes32 public constant PERPLEMMA_ROLE = keccak256("PERPLEMMA_ROLE");
    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER_ROLE");

    /// USDLemma contract address
    address public usdLemma;
    /// LemmaSynth contract address
    address public lemmaSynth;
    /// Rebalancer Address to rebalance position between short or long
    address public reBalancer;
    /// BaseToken address from perpV2
    address public usdlBaseTokenAddress;
    /// Settlement token manager contract address
    address public settlementTokenManager;
    /// Referrer Code use while openPosition
    bytes32 public referrerCode;

    address public xUsdl;
    address public xSynth;

    /// PerpV2 contract addresses
    IClearingHouse public clearingHouse;
    IClearingHouseConfig public clearingHouseConfig;
    IPerpVault public perpVault;
    IAccountBalance public accountBalance;
    IMarketRegistry public marketRegistry;

    /// Is USDL collateral is tail then it will not deposit into perpV2, It will stay in PerpLemma BalanceSheet
    bool public isUsdlCollateralTailAsset;
    /// USDL collateral address which is use to mint usdl
    IERC20Decimals public usdlCollateral;
    /// USDC ERC20 contract
    IERC20Decimals public override usdc;
    uint256 public usdcDecimals;

    /// MAX Uint256
    uint256 public constant MAX_UINT256 = type(uint256).max;
    /// MaxPosition till perpLemma can openPosition
    uint256 public maxPosition;
    /// USDL's collateral decimal (for e.g. if  eth then 18 decimals)
    uint256 public usdlCollateralDecimals;

    int256 public amountBase;
    int256 public amountQuote;
    /// Amount of usdl's collateral that is deposited in perpLemma and then deposited into perpV2
    uint256 public amountUsdlCollateralDeposited;

    // NOTE: Below this free collateral amount, recapitalization in USDC is needed to push back the margin in a safe zone
    uint256 public minFreeCollateral;

    // NOTE: This is the min margin for safety
    uint256 public minMarginSafeThreshold;

    // NOTE: This is very important to define the margin we want to keep when minting
    uint24 public collateralRatio;

    // Gets set only when Settlement has already happened
    // NOTE: This should be equal to the amount of USDL minted depositing on that dexIndex
    /// Amount of USDL minted through this perpLemma, it is tracking because usdl can be mint by multiple perpLemma
    uint256 public mintedPositionUsdlForThisWrapper;
    /// Amount of LemmaSynth minted
    uint256 public mintedPositionSynthForThisWrapper;
    /// Settlement time price
    uint256 public closedPrice;

    // Has the Market Settled, If settled we can't mint new USDL or Synth
    bool public override hasSettled;

    //for accounting of funding payment distribution
    int256 public fundingPaymentsToDistribute;
    uint256 public percFundingPaymentsToUSDLHolders;

    uint256 public accruedFPLossesFromXUSDLInUSDC;
    uint256 public accruedFPLossesFromXSynthInUSDC;

    // Events
    event USDLemmaUpdated(address indexed usdlAddress);
    event SetLemmaSynth(address indexed lemmaSynthAddress);
    event ReferrerUpdated(bytes32 indexed referrerCode);
    event RebalancerUpdated(address indexed rebalancerAddress);
    event MaxPositionUpdated(uint256 indexed maxPos);
    event SetSettlementTokenManager(address indexed _settlementTokenManager);
    event SetMinFreeCollateral(uint256 indexed _minFreeCollateral);
    event SetCollateralRatio(uint256 indexed _collateralRatio);
    event SetMinMarginSafeThreshold(uint256 indexed _minMarginSafeThreshold);

    //////////////////////////////////
    /// Initialize External METHOD ///
    //////////////////////////////////

    /// @notice Intialize method only called once while deploying contract
    /// It will setup different roles and give role access to specific addreeses
    /// Also set up the perpV2 contract instances and give allownace task
    function initialize(
        address _trustedForwarder,
        address _usdlCollateral,
        address _usdlBaseToken,
        address _clearingHouse,
        address _marketRegistry,
        address _usdLemma,
        address _lemmaSynth,
        uint256 _maxPosition
    ) external initializer {
        __ERC2771Context_init(_trustedForwarder);

        __AccessControl_init();
        _setRoleAdmin(PERPLEMMA_ROLE, ADMIN_ROLE);
        _setRoleAdmin(OWNER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(USDC_TREASURY, ADMIN_ROLE);
        _setRoleAdmin(REBALANCER_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
        grantRole(OWNER_ROLE, msg.sender);

        require(_usdlBaseToken != address(0), "UsdlBaseToken should not ZERO address");
        require(_clearingHouse != address(0), "ClearingHouse should not ZERO address");
        require(_marketRegistry != address(0), "MarketRegistry should not ZERO address");

        // NOTE: Even though it is not necessary, it is for clarity
        hasSettled = false;
        usdLemma = _usdLemma;
        lemmaSynth = _lemmaSynth;
        usdlBaseTokenAddress = _usdlBaseToken;
        maxPosition = _maxPosition;

        clearingHouse = IClearingHouse(_clearingHouse);
        clearingHouseConfig = IClearingHouseConfig(clearingHouse.getClearingHouseConfig());
        perpVault = IPerpVault(clearingHouse.getVault());
        accountBalance = IAccountBalance(clearingHouse.getAccountBalance());
        marketRegistry = IMarketRegistry(_marketRegistry);
        usdc = IERC20Decimals(perpVault.getSettlementToken());
        usdcDecimals = usdc.decimals();

        collateralRatio = clearingHouseConfig.getImRatio();

        usdlCollateral = IERC20Decimals(_usdlCollateral);
        usdlCollateralDecimals = usdlCollateral.decimals(); // need to verify
        SafeERC20Upgradeable.safeApprove(usdlCollateral, _clearingHouse, MAX_UINT256);

        SafeERC20Upgradeable.safeApprove(usdlCollateral, address(perpVault), 0);
        SafeERC20Upgradeable.safeApprove(usdlCollateral, address(perpVault), MAX_UINT256);
        SafeERC20Upgradeable.safeApprove(usdc, address(perpVault), 0);
        SafeERC20Upgradeable.safeApprove(usdc, address(perpVault), MAX_UINT256);

        if (usdLemma != address(0)) {
            grantRole(PERPLEMMA_ROLE, _usdLemma);
            SafeERC20Upgradeable.safeApprove(usdc, usdLemma, 0);
            SafeERC20Upgradeable.safeApprove(usdc, usdLemma, MAX_UINT256);
            SafeERC20Upgradeable.safeApprove(usdlCollateral, usdLemma, 0);
            SafeERC20Upgradeable.safeApprove(usdlCollateral, usdLemma, MAX_UINT256);
        }

        if (lemmaSynth != address(0)) {
            grantRole(PERPLEMMA_ROLE, _lemmaSynth);
            SafeERC20Upgradeable.safeApprove(usdc, lemmaSynth, 0);
            SafeERC20Upgradeable.safeApprove(usdc, lemmaSynth, MAX_UINT256);
            SafeERC20Upgradeable.safeApprove(usdlCollateral, lemmaSynth, 0);
            SafeERC20Upgradeable.safeApprove(usdlCollateral, lemmaSynth, MAX_UINT256);
        }
    }

    /////////////////////////////
    /// EXTERNAL VIEW METHODS ///
    /////////////////////////////

    /// @dev a helper method to get usdlCollateralDecimlas
    function getUsdlCollateralDecimals() external view override returns (uint256) {
        return usdlCollateralDecimals;
    }

    /// @notice getSettlementToken will return USDC contract address
    function getSettlementToken() external view override returns (address) {
        return perpVault.getSettlementToken();
    }

    /// @notice getMinFreeCollateral will return minFreeCollateral set by owner
    function getMinFreeCollateral() external view override returns (uint256) {
        return minFreeCollateral;
    }

    /// @notice getMinMarginSafeThreshold will return minMarginSafeThreshold set by owner
    function getMinMarginSafeThreshold() external view override returns (uint256) {
        return minMarginSafeThreshold;
    }

    /// @notice getFees fees charge by perpV2 protocol for each trade
    function getFees() external view override returns (uint256) {
        IMarketRegistry.MarketInfo memory marketInfo = marketRegistry.getMarketInfo(usdlBaseTokenAddress);
        return marketInfo.exchangeFeeRatio;
    }

    /// @notice It returns the collateral accepted in the Perp Protocol to back positions
    /// @dev By default, the first element is the settlement token
    function getCollateralTokens() external view override returns (address[] memory res) {
        res = new address[](1);
        res[0] = perpVault.getSettlementToken();
    }

    /// @notice It returns the amount of USDC that are possibly needed to properly collateralize the new position on Perp
    /// @dev When the position is reduced in absolute terms, then there is no need for additional collateral while when it increases in absolute terms then we need to add more
    /// @param amount The amount of the new position
    /// @param isShort If we are minting USDL or a Synth by changing our Position on Perp
    function getRequiredUSDCToBackMinting(uint256 amount, bool isShort)
        external
        view
        override
        returns (bool isAcceptable, uint256 extraUSDC)
    {
        // NOTE: According to Perp, this is defined as accountValue = totalCollateralValue + totalUnrealizedPnl, in 18 decimals
        int256 currentAccountValue = getAccountValue();
        uint256 currentPrice = getIndexPrice();

        // NOTE: Computing the absolute delta in terms of quote token for the new position
        // NOTE: Need an amount in 1e18 to be compared with account value which I think is in 1e18
        int256 deltaPosition = int256((currentPrice * amount) / (10**(usdlCollateral.decimals())));

        // NOTE: Computing the next position
        int256 futureTotalPositionValue = currentAccountValue + ((isShort) ? int256(-1) : int256(1)) * deltaPosition;
        // int256 futureTotalPositionValue = currentTotalPositionValue + ((isShort) ? int256(-1) : int256(1)) * deltaPosition;
        // int256 futureAccountValue = futureTotalPositionValue + currentAccountValue;

        uint256 extraUSDC_1e18 = (futureTotalPositionValue >= 0) ? 0 : uint256(-futureTotalPositionValue);
        // uint256 extraUSDC_1e18 = (futureAccountValue >= 0) ? 0 : uint256(-futureAccountValue);
        extraUSDC = getAmountInCollateralDecimalsForPerp(extraUSDC_1e18, address(usdc), false);

        uint256 maxSettlementTokenAcceptableFromPerpVault = getMaxSettlementTokenAcceptableByVault();

        if (extraUSDC > maxSettlementTokenAcceptableFromPerpVault) {
            isAcceptable = false;
        } else {
            isAcceptable = true;
        }
    }

    // Returns the margin
    // NOTE: Returns totalCollateralValue + unrealizedPnL
    /// Functions
    /// clearingHouse.getAccountValue()
    /// https://github.com/perpetual-protocol/perp-curie-contract/blob/main/contracts/ClearingHouse.sol#L684
    /// https://github.com/perpetual-protocol/perp-curie-contract/blob/main/contracts/ClearingHouse.sol#L684
    /// https://github.com/yashnaman/perp-lushan/blob/main/contracts/interface/IClearingHouse.sol#L254
    function getSettlementTokenAmountInVault() external view override returns (int256) {
        return perpVault.getBalance(address(this));
    }

    /// @notice Returns the relative margin in 1e18 format
    function getRelativeMargin() external view override returns (uint256) {
        // NOTE: Returns totalCollateralValue + unrealizedPnL
        // https://github.com/yashnaman/perp-lushan/blob/main/contracts/interface/IClearingHouse.sol#L254
        int256 _accountValue_1e18 = clearingHouse.getAccountValue(address(this));
        uint256 _accountValue = getAmountInCollateralDecimalsForPerp(
            _accountValue_1e18.abs().toUint256(),
            address(usdlCollateral),
            false
        );

        // NOTE: Returns the margin requirement taking into account the position PnL
        // NOTE: This is what can be compared with the Account Value according to Perp Doc
        // https://github.com/yashnaman/perp-lushan/blob/main/contracts/interface/IAccountBalance.sol#L158
        int256 _margin = accountBalance.getMarginRequirementForLiquidation(address(this));
        return (
            (_accountValue_1e18 <= int256(0) || (_margin < 0))
                ? MAX_UINT256 // No Collateral Deposited --> Max Leverage Possible
                : (_margin.abs().toUint256() * 1e18) / _accountValue
        );
    }

    /// @notice Computes the delta exposure
    /// @dev It does not take into account if the deposited collateral gets silently converted in USDC so that we lose positive delta exposure
    function getDeltaExposure() external view override returns (int256) {
        (
            uint256 _usdlCollateralAmount,
            uint256 _usdlCollateralDepositedAmount,
            int256 _longOrShort,
            ,

        ) = getExposureDetails();
        uint256 _longOnly = (_usdlCollateralAmount + _usdlCollateralDepositedAmount) *
            10**(18 - usdlCollateralDecimals); // Both usdlCollateralDecimals format

        int256 _deltaLongShort = int256(_longOnly) + _longOrShort;
        uint256 _absTot = _longOnly + _longOrShort.abs().toUint256();
        int256 _delta = (_absTot == 0) ? int256(0) : (_deltaLongShort * 1e6) / int256(_absTot);
        return _delta;
    }

    /// @notice Returns the margin
    function getMargin() external view override returns (int256) {
        int256 _margin = accountBalance.getMarginRequirementForLiquidation(address(this));
        return _margin;
    }

    /// @notice isAdditionalUSDCAcceptable methods to that perpVault is ready to accept more USDC
    /// perpVault has global cap to deposit, if it exceeds it will not accept new USDC as collateral
    function isAdditionalUSDCAcceptable(uint256 amount) external view override returns (bool) {
        uint256 vaultSettlementTokenBalance = usdc.balanceOf(address(perpVault));
        uint256 vaultSettlementTokenBalanceCap = clearingHouseConfig.getSettlementTokenBalanceCap();
        require(
            vaultSettlementTokenBalanceCap >= vaultSettlementTokenBalance,
            "isAdditionalUSDCAcceptable Cap needs to be >= Current"
        );
        uint256 maxAcceptableToken = uint256(
            int256(vaultSettlementTokenBalanceCap) - int256(vaultSettlementTokenBalance)
        );
        return amount <= maxAcceptableToken;
    }

    /// @notice computeRequiredUSDCForTrade methods
    /// it will calculate the amount usdc require to deposit to recap the leverage at 1x.
    /// It will call by usdLemma contract only.
    function computeRequiredUSDCForTrade(uint256 amount, bool isShort)
        external
        view
        override
        returns (uint256 requiredUSDC)
    {
        // NOTE: Estimating USDC needed
        uint256 freeCollateralBefore = getFreeCollateral();
        uint256 indexPrice = getIndexPrice();
        uint256 deltaAmount = amount;

        if (
            ((isShort) && (amountBase > 0)) || ((!isShort) && (amountBase < 0)) // NOTE Decrease Long // NOTE Decrease Short
        ) {
            // NOTE: amountBase is in vToken amount so 1e18
            uint256 amountBaseInCollateralDecimals = (_abs(amountBase) * 10**(usdlCollateral.decimals())) / 1e18;

            if (amount <= amountBaseInCollateralDecimals) {
                return 0;
            }

            if (amount <= 2 * amountBaseInCollateralDecimals) {
                return 0;
            }
            deltaAmount = amount - 2 * amountBaseInCollateralDecimals;
        }

        uint256 expectedDeltaQuote = (deltaAmount * indexPrice) / 10**(18 + 18 - usdcDecimals);

        uint256 expectedUSDCDeductedFromFreeCollateral = (expectedDeltaQuote * uint256(collateralRatio)) / 1e6;

        if (expectedUSDCDeductedFromFreeCollateral > freeCollateralBefore) {
            requiredUSDC = expectedUSDCDeductedFromFreeCollateral - freeCollateralBefore;
        }
    }

    ////////////////////////
    /// EXTERNAL METHODS ///
    ////////////////////////

    /// @notice changeAdmin is to change address of admin role
    /// Only current admin can change admin and after new admin current admin address will be no more admin
    /// @param newAdmin new admin address
    function changeAdmin(address newAdmin) external onlyRole(ADMIN_ROLE) {
        require(newAdmin != address(0), "NewAdmin should not ZERO address");
        require(newAdmin != msg.sender, "Admin Addresses should not be same");
        _setupRole(ADMIN_ROLE, newAdmin);
        renounceRole(ADMIN_ROLE, msg.sender);
    }

    /// @notice setPercFundingPaymentsToUSDLHolders will set _percFundingPaymentsToUSDLHolder
    function setPercFundingPaymentsToUSDLHolders(uint256 _percFundingPaymentsToUSDLHolder)
        external
        override
        onlyRole(OWNER_ROLE)
    {
        percFundingPaymentsToUSDLHolders = _percFundingPaymentsToUSDLHolder;
    }

    /// @notice setXUsdl will set xusdl contract address by owner role address
    /// @param _xUsdl contract address
    function setXUsdl(address _xUsdl) external override onlyRole(OWNER_ROLE) {
        require(_xUsdl != address(0), "Address can't be zero");
        xUsdl = _xUsdl;
    }

    /// @notice setXSynth will set xLemmSynth contract address by owner role address
    /// for e.g. if LemmaSynthWETH => XLemmaSynthWETH, LemmaSynthWBTC => XLemmaSynthWBTC
    /// @param _xSynth contract address
    function setXSynth(address _xSynth) external override onlyRole(OWNER_ROLE) {
        require(_xSynth != address(0), "Address can't be zero");
        xSynth = _xSynth;
    }

    /// @notice setMinFreeCollateral will set _minFreeCollateral by owner role address
    /// @param _minFreeCollateral contract address
    function setMinFreeCollateral(uint256 _minFreeCollateral) external override onlyRole(OWNER_ROLE) {
        minFreeCollateral = _minFreeCollateral;
        emit SetMinFreeCollateral(minFreeCollateral);
    }

    /// @notice setMinMarginSafeThreshold will set _margin by owner role address
    /// @param _margin contract address
    function setMinMarginSafeThreshold(uint256 _margin) external override onlyRole(OWNER_ROLE) {
        require(_margin > minFreeCollateral, "Needs to be > minFreeCollateral");
        minMarginSafeThreshold = _margin;
        emit SetMinMarginSafeThreshold(minMarginSafeThreshold);
    }

    /// @notice setCollateralRatio will set _collateralRatio by owner role address
    /// @param _collateralRatio contract address
    function setCollateralRatio(uint24 _collateralRatio) external override onlyRole(OWNER_ROLE) {
        // NOTE: This one should always be >= imRatio or >= mmRatio but not sure if a require is needed
        collateralRatio = _collateralRatio;
        emit SetCollateralRatio(collateralRatio);
    }

    /// @notice Defines the USDL Collateral as a tail asset by only owner role
    function setIsUsdlCollateralTailAsset(bool _x) external onlyRole(OWNER_ROLE) {
        isUsdlCollateralTailAsset = _x;
    }

    /// @notice sets USDLemma address - only owner can set
    /// @param _usdLemma USDLemma address to set
    function setUSDLemma(address _usdLemma) external onlyRole(ADMIN_ROLE) {
        require(_usdLemma != address(0), "UsdLemma should not ZERO address");
        usdLemma = _usdLemma;
        grantRole(PERPLEMMA_ROLE, usdLemma);
        SafeERC20Upgradeable.safeApprove(usdc, usdLemma, 0);
        SafeERC20Upgradeable.safeApprove(usdc, usdLemma, MAX_UINT256);
        SafeERC20Upgradeable.safeApprove(usdlCollateral, usdLemma, 0);
        SafeERC20Upgradeable.safeApprove(usdlCollateral, usdLemma, MAX_UINT256);
        emit USDLemmaUpdated(usdLemma);
    }

    /// @notice sets LemmaSynth address - only owner can set
    /// @param _lemmaSynth LemmaSynth address to set
    function setLemmaSynth(address _lemmaSynth) external onlyRole(ADMIN_ROLE) {
        require(_lemmaSynth != address(0), "LemmaSynth should not ZERO address");
        lemmaSynth = _lemmaSynth;
        grantRole(PERPLEMMA_ROLE, lemmaSynth);
        SafeERC20Upgradeable.safeApprove(usdc, lemmaSynth, 0);
        SafeERC20Upgradeable.safeApprove(usdc, lemmaSynth, MAX_UINT256);
        SafeERC20Upgradeable.safeApprove(usdlCollateral, lemmaSynth, 0);
        SafeERC20Upgradeable.safeApprove(usdlCollateral, lemmaSynth, MAX_UINT256);
        emit SetLemmaSynth(lemmaSynth);
    }

    /// @notice sets refferer code - only owner can set
    /// @param _referrerCode referrerCode of address to set
    function setReferrerCode(bytes32 _referrerCode) external onlyRole(OWNER_ROLE) {
        referrerCode = _referrerCode;
        emit ReferrerUpdated(referrerCode);
    }

    /// @notice sets maximum position the wrapper can take (in terms of base) - only owner can set
    /// @param _maxPosition reBalancer address to set
    function setMaxPosition(uint256 _maxPosition) external onlyRole(OWNER_ROLE) {
        maxPosition = _maxPosition;
        emit MaxPositionUpdated(maxPosition);
    }

    /// @notice setSettlementTokenManager is to set the address of settlementTokenManager by admin role only
    /// @param _settlementTokenManager address
    function setSettlementTokenManager(address _settlementTokenManager) external onlyRole(ADMIN_ROLE) {
        revokeRole(USDC_TREASURY, settlementTokenManager);
        settlementTokenManager = _settlementTokenManager;
        grantRole(USDC_TREASURY, settlementTokenManager);
        emit SetSettlementTokenManager(settlementTokenManager);
    }

    ///@notice sets reBalncer address - only owner can set
    ///@param _reBalancer reBalancer address to set
    function setReBalancer(address _reBalancer) external onlyRole(ADMIN_ROLE) {
        require(_reBalancer != address(0), "ReBalancer should not ZERO address");
        grantRole(REBALANCER_ROLE, _reBalancer);
        reBalancer = _reBalancer;
        emit RebalancerUpdated(_reBalancer);
    }

    /// @notice reset approvals
    function resetApprovals() external {
        SafeERC20Upgradeable.safeApprove(usdlCollateral, address(perpVault), 0);
        SafeERC20Upgradeable.safeApprove(usdlCollateral, address(perpVault), MAX_UINT256);
        SafeERC20Upgradeable.safeApprove(usdc, address(perpVault), 0);
        SafeERC20Upgradeable.safeApprove(usdc, address(perpVault), MAX_UINT256);
    }

    /// @notice depositSettlementToken is used to deposit settlement token USDC into perp vault - only owner can deposit
    /// @param _amount USDC amount need to deposit into perp vault
    function depositSettlementToken(uint256 _amount) external override onlyRole(USDC_TREASURY) {
        require(_amount > 0, "Amount should greater than zero");
        SafeERC20Upgradeable.safeTransferFrom(usdc, msg.sender, address(this), _amount);
        perpVault.deposit(address(usdc), _amount);
    }

    /// @notice withdrawSettlementToken is used to withdraw settlement token USDC from perp vault - only owner can withdraw
    /// @param _amount USDC amount need to withdraw from perp vault
    function withdrawSettlementToken(uint256 _amount) external override onlyRole(USDC_TREASURY) {
        require(_amount > 0, "Amount should greater than zero");
        perpVault.withdraw(address(usdc), _amount);
        SafeERC20Upgradeable.safeTransfer(usdc, msg.sender, _amount);
    }

    /// @notice withdrawSettlementTokenTo is used to withdraw settlement token USDC from perp vault - only owner can withdraw
    /// @param _amount USDC amount need to withdraw from perp vault
    /// @param _to address where to transfer fund
    function withdrawSettlementTokenTo(uint256 _amount, address _to) external onlyRole(OWNER_ROLE) {
        require(_amount > 0, "Amount should greater than zero");
        require(hasSettled, "Perpetual is not settled yet");
        SafeERC20Upgradeable.safeTransfer(usdc, _to, _amount);
    }

    /// @notice deposit method is to call from USDLemma or LemmaSynth while mint USDL or Synth
    /// @param amount of assets to deposit
    /// @param collateral needs to deposit
    function deposit(uint256 amount, address collateral) external override onlyRole(PERPLEMMA_ROLE) {
        _deposit(amount, collateral);
    }

    /// @notice withdraw method is to call from USDLemma or LemmaSynth while redeem USDL or Synth
    /// @param amount of assets to withdraw
    /// @param collateral needs to withdraw
    function withdraw(uint256 amount, address collateral) external override onlyRole(PERPLEMMA_ROLE) {
        _withdraw(amount, collateral);
    }

    /// @notice when perpetual is in CLEARED state, withdraw the collateral
    /// @dev Anybody can call it so that it happens as quickly as possible
    function settle() external override {
        clearingHouse.quitMarket(address(this), usdlBaseTokenAddress);
        closedPrice = IBaseToken(usdlBaseTokenAddress).getClosedPrice();

        // NOTE: Settle pending funding rates
        clearingHouse.settleAllFunding(address(this));

        uint256 freeUSDCCollateral = perpVault.getFreeCollateral(address(this));
        _withdraw(freeUSDCCollateral, address(usdc));

        if (!isUsdlCollateralTailAsset) {
            // NOTE: This amount of free collateral is the one internally used to check for the V_NEFC error, so this is the max withdrawable
            uint256 freeCollateralUSDL = perpVault.getFreeCollateralByToken(address(this), address(usdlCollateral));
            _withdraw(freeCollateralUSDL, address(usdlCollateral));
        }

        // All the collateral is now back
        hasSettled = true;
    }

    /// @notice getCollateralBackAfterSettlement is called when market is settled so USDL and Synth withdraw method call this method instead close position
    function getCollateralBackAfterSettlement(
        uint256 amount,
        address to,
        bool isUsdl
    ) external override onlyRole(PERPLEMMA_ROLE) {
        return settleCollateral(amount, to, isUsdl);
    }

    /// @custom:deprecated not being used currently, there will be an update soon
    /// @notice Rebalances USDL or Synth emission swapping by Perp backed to Token backed
    /// @dev USDL can be backed by both: 1) Floating Collateral + Perp Short of the same Floating Collateral or 2) USDC
    /// @dev LemmaX (where X can be ETH, ...) can be backed by both: 1) USDC collateralized Perp Long or 2) X token itself
    /// @dev The idea is to use this mechanism for this purposes like Arbing between Mark and Spot Price or adjusting our tokens in our balance sheet for LemmaSwap supply
    /// @dev Details at https://www.notion.so/lemmafinance/Rebalance-Details-f72ad11a5d8248c195762a6ac6ce037e
    ///
    /// @param router The Router to execute the swap on
    /// @param routerType The Router Type: 0 --> UniV3, ...
    /// @param amountBaseToRebalance The Amount of Base Token to buy or sell on Perp and consequently the amount of corresponding colletarl to sell or buy on Spot
    /// @param isCheckProfit Check the profit to possibly revert the TX in case
    /// @return Amount of USDC resulting from the operation. It can also be negative as we can use this mechanism for purposes other than Arb See https://www.notion.so/lemmafinance/Rebalance-Details-f72ad11a5d8248c195762a6ac6ce037e#ffad7b09a81a4b049348e3cd38e57466 here
    function rebalance(
        address router,
        uint256 routerType,
        int256 amountBaseToRebalance,
        bool isCheckProfit
    ) external override onlyRole(REBALANCER_ROLE) returns (uint256, uint256) {
        // uint256 usdlCollateralAmountPerp;
        // uint256 usdlCollateralAmountDex;
        uint256 amountUSDCPlus;
        uint256 amountUSDCMinus;

        require(amountBaseToRebalance != 0, "! No Rebalance with Zero Amount");

        bool isIncreaseBase = amountBaseToRebalance > 0;
        uint256 _amountBaseToRebalance = (isIncreaseBase)
            ? uint256(amountBaseToRebalance)
            : uint256(-amountBaseToRebalance);

        if (isIncreaseBase) {
            if (amountBase < 0) {
                (, uint256 amountUSDCMinus_1e18) = closeShortWithExactBase(_amountBaseToRebalance);
                amountUSDCMinus = (amountUSDCMinus_1e18 * (10**usdcDecimals)) / 1e18;
                _withdraw(_amountBaseToRebalance, address(usdlCollateral));
                require(usdlCollateral.balanceOf(address(this)) > _amountBaseToRebalance, "T1");
                amountUSDCPlus = _CollateralToUSDC(router, routerType, true, _amountBaseToRebalance);
            } else {
                amountUSDCPlus = _CollateralToUSDC(router, routerType, true, _amountBaseToRebalance);
                _deposit(amountUSDCPlus, address(usdc));
                (, uint256 amountUSDCMinus_1e18) = openLongWithExactBase(_amountBaseToRebalance);
                amountUSDCMinus = (amountUSDCMinus_1e18 * (10**usdcDecimals)) / 1e18;
            }
        } else {
            if (amountBase <= 0) {
                amountUSDCMinus = _USDCToCollateral(router, routerType, false, _amountBaseToRebalance);
                _deposit(_amountBaseToRebalance, address(usdlCollateral));
                (, uint256 amountUSDCPlus_1e18) = openShortWithExactBase(_amountBaseToRebalance);
                amountUSDCPlus = (amountUSDCPlus_1e18 * (10**usdcDecimals)) / 1e18;
            } else {
                (, uint256 amountUSDCPlus_1e18) = closeLongWithExactBase(_amountBaseToRebalance);
                amountUSDCPlus = (amountUSDCPlus_1e18 * (10**usdcDecimals)) / 1e18;
                _withdraw(amountUSDCPlus, address(usdc));
                amountUSDCMinus = _USDCToCollateral(router, routerType, false, _amountBaseToRebalance);
            }
        }
        if (isCheckProfit) require(amountUSDCPlus >= amountUSDCMinus, "Unprofitable");
        return (amountUSDCPlus, amountUSDCMinus);
    }

    /// @notice calculateMintingAsset is method to track the minted usdl and synth by this perpLemma
    /// @param amount needs to add or sub
    /// @param isOpenShort that position is short or long
    /// @param basis is enum that defines the calculateMintingAsset call from Usdl or lemmaSynth contract
    function calculateMintingAsset(
        uint256 amount,
        Basis basis,
        bool isOpenShort
    ) external override onlyRole(PERPLEMMA_ROLE) {
        _calculateMintingAsset(amount, basis, isOpenShort);
    }

    /// @notice distributes funding payments to xUSDL and xLemmaSynth holders
    function distributeFundingPayments()
        external
        override
        returns (
            bool isProfit,
            uint256 amountUSDCToXUSDL,
            uint256 amountUSDCToXSynth
        )
    {
        settlePendingFundingPayments();
        if (fundingPaymentsToDistribute != 0) {
            isProfit = fundingPaymentsToDistribute < 0;
            if (isProfit) {
                // NOTE: Distribute profit
                uint256 amount = _convDecimals(uint256(-fundingPaymentsToDistribute), 18, usdcDecimals);
                amountUSDCToXUSDL = (amount * percFundingPaymentsToUSDLHolders) / 1e6;
                amountUSDCToXSynth = amount - amountUSDCToXUSDL;
                // NOTE: They both require an amount in USDC Decimals
                IUSDLemma(usdLemma).mintToStackingContract(_convDecimals(amountUSDCToXUSDL, usdcDecimals, 18));
                IUSDLemma(lemmaSynth).mintToStackingContract(_convUSDCToSynthAtIndexPrice(amountUSDCToXSynth));
            } else {
                amountUSDCToXUSDL = (uint256(fundingPaymentsToDistribute) * percFundingPaymentsToUSDLHolders) / 1e6;
                amountUSDCToXSynth = uint256(fundingPaymentsToDistribute) - amountUSDCToXUSDL;

                amountUSDCToXUSDL = _convDecimals(amountUSDCToXUSDL, 18, usdcDecimals);
                amountUSDCToXSynth = _convDecimals(amountUSDCToXSynth, 18, usdcDecimals);
                uint256 amountUSDLInUSDC = _convDecimals(
                    IUSDLemma(usdLemma).balanceOf(address(xUsdl)),
                    18,
                    usdcDecimals
                );
                uint256 amountSynthInUSDC = _convSynthToUSDCAtIndexPrice(
                    IUSDLemma(lemmaSynth).balanceOf(address(xSynth))
                );
                //we consider the past payment that was not paid as well
                uint256 USDCToPayFromXUSDL = accruedFPLossesFromXUSDLInUSDC + amountUSDCToXUSDL;
                uint256 USDLToBurn = USDCToPayFromXUSDL;
                if (USDCToPayFromXUSDL > amountUSDLInUSDC) {
                    USDLToBurn = amountUSDLInUSDC;
                    //the rest we try to take from the settlmentTokenManager
                    uint256 settlmentTokenManagerBalance = usdc.balanceOf(settlementTokenManager);
                    uint256 amountFromSettlmentTokenManager = USDCToPayFromXUSDL - amountUSDLInUSDC;
                    if (amountFromSettlmentTokenManager > settlmentTokenManagerBalance) {
                        amountFromSettlmentTokenManager = settlmentTokenManagerBalance;
                        //this is the amount that couldn't be paid from neither xUSDL nor settlmentTokenManager
                        accruedFPLossesFromXUSDLInUSDC = amountFromSettlmentTokenManager - settlmentTokenManagerBalance;
                    }
                    IUSDLemma(usdLemma).requestLossesRecap(amountFromSettlmentTokenManager);
                }
                IUSDLemma(usdLemma).burnToStackingContract(_convDecimals(USDLToBurn, usdcDecimals, 18));

                uint256 USDCToPayFromXLemmaSynth = accruedFPLossesFromXSynthInUSDC + amountUSDCToXSynth;
                uint256 lemmaSynthToBurn = USDCToPayFromXLemmaSynth;
                if (USDCToPayFromXLemmaSynth > amountSynthInUSDC) {
                    lemmaSynthToBurn = amountSynthInUSDC;
                    //the rest we try to take from the settlmentTokenManager
                    uint256 settlmentTokenManagerBalance = usdc.balanceOf(settlementTokenManager);
                    uint256 amountFromSettlmentTokenManager = USDCToPayFromXLemmaSynth - amountSynthInUSDC;
                    if (amountFromSettlmentTokenManager > settlmentTokenManagerBalance) {
                        amountFromSettlmentTokenManager = settlmentTokenManagerBalance;
                        //this is the amount that couldn't be paid from neither xLemmaSynth nor settlmentTokenManager
                        accruedFPLossesFromXSynthInUSDC =
                            amountFromSettlmentTokenManager -
                            settlmentTokenManagerBalance;
                    }
                    IUSDLemma(usdLemma).requestLossesRecap(amountFromSettlmentTokenManager);
                }
                IUSDLemma(lemmaSynth).burnToStackingContract(_convUSDCToSynthAtIndexPrice(lemmaSynthToBurn));
            }
        }
        // NOTE: Reset the funding payment to distribute
        fundingPaymentsToDistribute = 0;
    }

    //////////////////////
    /// PUBLIC METHODS ///
    //////////////////////

    /**@notice settle the funding payments to make sure funding payments gets ditributed correctly
                it should be called be called before any interaction that happen on perpetual protocol.
    */
    function settlePendingFundingPayments() public override {
        fundingPaymentsToDistribute += getPendingFundingPayment();
        clearingHouse.settleAllFunding(address(this));
    }

    /// @notice trade method is to open short or long position
    /// if isShorting true then base -> quote otherwise quote -> base
    /// if isShorting == true then input will be base
    /// if isShorting == false then input will be quote
    /// @param amount of position short/long, amount is base or quote and input or notInput is decide by below params
    /// @param isShorting is short or long
    /// @param isExactInput is ExactInput or not
    function trade(
        uint256 amount,
        bool isShorting,
        bool isExactInput
    ) public override onlyRole(PERPLEMMA_ROLE) returns (uint256, uint256) {
        bool _isBaseToQuote = isShorting;
        bool _isExactInput = isExactInput;

        // NOTE: Funding Payments get settled anyway when the trade is executed, so we need to account them before settling them ourselves
        settlePendingFundingPayments();

        IClearingHouse.OpenPositionParams memory params = IClearingHouse.OpenPositionParams({
            baseToken: usdlBaseTokenAddress,
            isBaseToQuote: _isBaseToQuote,
            isExactInput: _isExactInput,
            amount: amount,
            oppositeAmountBound: 0,
            deadline: MAX_UINT256,
            sqrtPriceLimitX96: 0,
            referralCode: referrerCode
        });

        // NOTE: It returns the base and quote of the last trade only
        (uint256 _amountBase, uint256 _amountQuote) = clearingHouse.openPosition(params);
        amountBase += (_isBaseToQuote) ? -1 * int256(_amountBase) : int256(_amountBase);
        amountQuote += (_isBaseToQuote) ? int256(_amountQuote) : -1 * int256(_amountQuote);
        int256 positionSize = accountBalance.getTotalPositionSize(address(this), usdlBaseTokenAddress);
        require(positionSize.abs().toUint256() <= maxPosition, "max position reached");
        return (_amountBase, _amountQuote);
    }

    ////////////// TRADING - CONVENIENCE FUNCTIONS //////////////
    // openLongWithExactBase & closeShortWithExactBase: Quote --> Base, ExactInput: False
    // openLongWithExactQuote & closeShortWithExactQuote: Quote --> Base, ExactInput: True
    // closeLongWithExactBase & openShortWithExactBase: Base --> Quote, ExactInput: True
    // closeLongWithExactQuote & openShortWithExactQuote: Base --> Quote, ExactInput: False

    /// LemmaSynth will use below four methods
    /// 1). openLongWithExactBase => depositTo
    /// 2). openLongWithExactQuote => depositToWExactCollateral
    /// 3). closeLongWithExactBase => withdrawTo
    /// 4). closeLongWithExactQuote => withdrawToWExactCollateral
    function openLongWithExactBase(uint256 amount) public override onlyRole(PERPLEMMA_ROLE) returns (uint256, uint256) {
        (uint256 base, uint256 quote) = trade(amount, false, false);
        return (base, quote);
    }

    function openLongWithExactQuote(uint256 amount)
        public
        override
        onlyRole(PERPLEMMA_ROLE)
        returns (uint256, uint256)
    {
        (uint256 base, uint256 quote) = trade(amount, false, true);
        return (base, quote);
    }

    function closeLongWithExactBase(uint256 amount)
        public
        override
        onlyRole(PERPLEMMA_ROLE)
        returns (uint256, uint256)
    {
        (uint256 base, uint256 quote) = trade(amount, true, true);
        return (base, quote);
    }

    function closeLongWithExactQuote(uint256 amount)
        public
        override
        onlyRole(PERPLEMMA_ROLE)
        returns (uint256, uint256)
    {
        (uint256 base, uint256 quote) = trade(amount, true, false);
        base = getRoudDown(base, address(usdlCollateral)); // RoundDown
        return (base, quote);
    }

    /// USDLemma will use below four methods
    /// 1). openShortWithExactBase => depositToWExactCollateral
    /// 2). openShortWithExactQuote => depositTo
    /// 3). closeShortWithExactBase => withdrawToWExactCollateral
    /// 4). closeShortWithExactQuote => withdrawTo
    function openShortWithExactBase(uint256 amount)
        public
        override
        onlyRole(PERPLEMMA_ROLE)
        returns (uint256, uint256)
    {
        (uint256 base, uint256 quote) = trade(amount, true, true);
        return (base, quote);
    }

    function openShortWithExactQuote(uint256 amount)
        public
        override
        onlyRole(PERPLEMMA_ROLE)
        returns (uint256, uint256)
    {
        (uint256 base, uint256 quote) = trade(amount, true, false);
        return (base, quote);
    }

    function closeShortWithExactBase(uint256 amount)
        public
        override
        onlyRole(PERPLEMMA_ROLE)
        returns (uint256, uint256)
    {
        (uint256 base, uint256 quote) = trade(amount, false, false);
        return (base, quote);
    }

    function closeShortWithExactQuote(uint256 amount)
        public
        override
        onlyRole(PERPLEMMA_ROLE)
        returns (uint256, uint256)
    {
        (uint256 base, uint256 quote) = trade(amount, false, true);
        return (base, quote);
    }

    ///////////////////////////
    /// PUBLIC VIEW METHODS ///
    ///////////////////////////

    /// @notice Get the free collateral value denominated in the settlement token of the specified trader
    /// @return freeCollateral the value (in settlement token's decimals) of free collateral available
    ///         for withdraw or opening new positions or orders)
    function getFreeCollateral() public view override returns (uint256) {
        return perpVault.getFreeCollateral(address(this));
    }

    /// @notice getCollateralRatios will get,
    /// @return imRatio Initial margin ratio
    /// @return mmRatio Maintenance margin requirement ratio
    function getCollateralRatios() public view override returns (uint24 imRatio, uint24 mmRatio) {
        imRatio = clearingHouseConfig.getImRatio();
        mmRatio = clearingHouseConfig.getMmRatio();
    }

    /// @notice Get account value of the specified trader
    /// @return value_1e18 account value (in settlement token's decimals)
    function getAccountValue() public view override returns (int256 value_1e18) {
        value_1e18 = clearingHouse.getAccountValue(address(this));
    }

    /// @notice Returns the index price of the token.
    /// interval The interval represents twap interval.
    /// @return indexPrice Twap price with interval
    function getIndexPrice() public view override returns (uint256 indexPrice) {
        uint256 _twapInterval = IClearingHouseConfig(clearingHouseConfig).getTwapInterval();
        indexPrice = IIndexPrice(usdlBaseTokenAddress).getIndexPrice(_twapInterval);
    }

    /// @notice Returns the price of th UniV3Pool.
    function getMarkPrice() public view override returns (uint256 token0Price) {
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(marketRegistry.getPool(usdlBaseTokenAddress)).slot0();
        token0Price = ((uint256(sqrtPriceX96)**2) / (2**192)) * 1e18;
    }

    /// @notice Get the pending funding payment for a trader in a given market
    /// @return pendingFundingPayments The pending funding payment of a trader in one market,
    /// including liquidity & balance coefficients. Positive value means the trader pays funding,
    /// negative value means the trader receives funding.
    function getPendingFundingPayment() public view override returns (int256 pendingFundingPayments) {
        // See
        // Interface
        // https://github.com/perpetual-protocol/perp-curie-contract/blob/main/contracts/interface/IExchange.sol#L101
        // Implementation
        // https://github.com/perpetual-protocol/perp-curie-contract/blob/main/contracts/Exchange.sol#L361
        //
        // Notation
        // Earning or Paying Funding
        // - If you see a positive payment, this means you paid this amount of funding.
        // - If you see a negative payment, this means you earned this amount of funding.
        // Source
        // https://support.perp.com/hc/en-us/articles/5257580412569-Funding-Payments
        pendingFundingPayments = IExchange(clearingHouse.getExchange()).getPendingFundingPayment(
            address(this),
            usdlBaseTokenAddress
        );
    }

    /// @notice getAmountInCollateralDecimalsForPerp is use to convert amount in collateral decimals
    function getAmountInCollateralDecimalsForPerp(
        uint256 amount,
        address collateral,
        bool roundUp
    ) public view override returns (uint256) {
        uint256 collateralDecimals = IERC20Decimals(collateral).decimals();
        if (roundUp && (amount % (uint256(10**(18 - collateralDecimals))) != 0)) {
            return amount / uint256(10**(18 - collateralDecimals)) + 1; // need to verify
        }
        return amount / uint256(10**(18 - collateralDecimals));
    }

    /// @notice Returning the max amount of USDC Tokens that is possible to put in Vault to collateralize positions
    /// @dev The underlying Perp Protocol (so far we only have PerpV2) can have a limit on the total amount of Settlement Token the Vault can accept
    function getMaxSettlementTokenAcceptableByVault() public view override returns (uint256) {
        uint256 perpVaultSettlementTokenBalanceBefore = usdc.balanceOf(address(perpVault));
        uint256 settlementTokenBalanceCap = IClearingHouseConfig(clearingHouse.getClearingHouseConfig())
            .getSettlementTokenBalanceCap();
        require(
            settlementTokenBalanceCap >= perpVaultSettlementTokenBalanceBefore,
            "[getVaultSettlementTokenLimit] Unexpected"
        );
        return uint256(int256(settlementTokenBalanceCap) - int256(perpVaultSettlementTokenBalanceBefore));
    }

    /// @notice getTotalPosition in terms of quoteToken(in our case vUSD)
    /// @notice Get total position value of trader's baseToken market
    /// @return Total position value of trader's baseToken market
    function getTotalPosition() public view override returns (int256) {
        return accountBalance.getTotalPositionValue(address(this), usdlBaseTokenAddress);
    }

    /// @notice Returns all the exposure related details
    function getExposureDetails()
        public
        view
        override
        returns (
            uint256,
            uint256,
            int256,
            int256,
            uint256
        )
    {
        return (
            usdlCollateral.balanceOf(address(this)),
            amountUsdlCollateralDeposited,
            amountBase, // All the other terms are in 1e6
            perpVault.getBalance(address(this)), // This number could change when PnL gets realized so it is better to read it from the Vault directly
            usdc.balanceOf(address(this))
        );
    }

    ////////////////////////
    /// INTERNAL METHODS ///
    ////////////////////////

    /// @notice to deposit collateral in vault for short or open position
    /// @dev If collateral is tail asset no need to deposit it in Perp, it has to stay in this contract balance sheet
    function _deposit(uint256 collateralAmount, address collateral) internal {
        if (collateral == address(usdc)) {
            perpVault.deposit(address(usdc), collateralAmount);
        } else if ((collateral == address(usdlCollateral)) && (!isUsdlCollateralTailAsset)) {
            perpVault.deposit(collateral, collateralAmount);
            amountUsdlCollateralDeposited += collateralAmount;
        }
    }

    /// @notice to withdraw collateral from vault after long or close position
    /// @dev If collateral is tail asset no need to withdraw it from Perp, it is already in this contract balance sheet
    function _withdraw(uint256 amountToWithdraw, address collateral) internal {
        // NOTE: Funding Payments are settled anyway when withdraw happens so we need to account them before executing
        settlePendingFundingPayments();
        if (collateral == address(usdc)) {
            perpVault.withdraw(address(usdc), amountToWithdraw);
        } else if ((collateral == address(usdlCollateral)) && (!isUsdlCollateralTailAsset)) {
            // NOTE: This is problematic with ETH
            perpVault.withdraw(collateral, amountToWithdraw);
            amountUsdlCollateralDeposited -= amountToWithdraw;
        }
    }

    /// @notice calculateMintingAsset is method to track the minted usdl and synth by this perpLemma
    /// @param amount needs to add or sub
    /// @param isOpenShort that position is short or long
    /// @param basis is enum that defines the calculateMintingAsset call from Usdl or lemmaSynth contract
    function _calculateMintingAsset(
        uint256 amount,
        Basis basis,
        bool isOpenShort
    ) internal {
        if (isOpenShort) {
            // if openShort or closeLong
            if (Basis.IsUsdl == basis) {
                mintedPositionUsdlForThisWrapper += amount; // quote
            } else if (Basis.IsSynth == basis) {
                mintedPositionSynthForThisWrapper -= amount; // base
            }
        } else {
            // if openLong or closeShort
            if (Basis.IsUsdl == basis) {
                mintedPositionUsdlForThisWrapper -= amount; // quote
            } else if (Basis.IsSynth == basis) {
                mintedPositionSynthForThisWrapper += amount; // base
            }
        }
    }

    /// @notice settleCollateral is called when market is settled and it will pro-rata distribute the funds
    /// Before market settled, rebalance function called and collateral is not same in perpLemma when it is deposited
    /// So we will use ClosePerpMarket price and current balances of usdl and synth to distribute the pro-rata base collateral
    function settleCollateral(
        uint256 usdlOrSynthAmount,
        address to,
        bool isUsdl
    ) internal {
        // NOTE: Funding Payments are settled anyway when settlement happens so we need to account them before executing
        settlePendingFundingPayments();
        uint256 tailCollateralBal = (usdlCollateral.balanceOf(address(this)) * 1e18) / (10**usdlCollateral.decimals());
        uint256 synthCollateralBal = (usdc.balanceOf(address(this)) * 1e18) / (10**usdcDecimals);
        require(tailCollateralBal > 0 || synthCollateralBal > 0, "Not Enough collateral for settle");

        if (isUsdl) {
            uint256 tailCollateralTransfer = (usdlOrSynthAmount * 1e18) / closedPrice;
            if (tailCollateralTransfer <= tailCollateralBal) {
                SafeERC20Upgradeable.safeTransfer(
                    usdlCollateral,
                    to,
                    getAmountInCollateralDecimalsForPerp(tailCollateralTransfer, address(usdlCollateral), false)
                );
            } else {
                if (tailCollateralBal > 0) {
                    SafeERC20Upgradeable.safeTransfer(
                        usdlCollateral,
                        to,
                        getAmountInCollateralDecimalsForPerp(tailCollateralBal, address(usdlCollateral), false)
                    );
                }
                if (synthCollateralBal > getSynthInDollar()) {
                    // do we have extra synth for usdlUser
                    uint256 checkDiffInDollar = ((tailCollateralTransfer - tailCollateralBal) * closedPrice) / 1e18; // calculate the needed extra synth to transfer
                    uint256 checkUSDCForUSdl = synthCollateralBal - getSynthInDollar(); // check how much extra synth we have for usdlUser
                    if (checkUSDCForUSdl > checkDiffInDollar) {
                        SafeERC20Upgradeable.safeTransfer(
                            usdc,
                            to,
                            getAmountInCollateralDecimalsForPerp(checkDiffInDollar, address(usdc), false)
                        );
                    } else {
                        SafeERC20Upgradeable.safeTransfer(
                            usdc,
                            to,
                            getAmountInCollateralDecimalsForPerp(checkUSDCForUSdl, address(usdc), false)
                        );
                    }
                }
            }
            /// ERROR MESSAGE: => NEUM: Not enough USDL minted by this PerpLemmaContract
            require(mintedPositionUsdlForThisWrapper >= usdlOrSynthAmount, "NEUM");
            mintedPositionUsdlForThisWrapper -= usdlOrSynthAmount;
        } else {
            uint256 usdcCollateralTransfer = (usdlOrSynthAmount * closedPrice) / 1e18;
            if (usdcCollateralTransfer <= synthCollateralBal) {
                SafeERC20Upgradeable.safeTransfer(
                    usdc,
                    to,
                    getAmountInCollateralDecimalsForPerp(usdcCollateralTransfer, address(usdc), false)
                );
            } else {
                if (synthCollateralBal > 0) {
                    SafeERC20Upgradeable.safeTransfer(
                        usdc,
                        to,
                        getAmountInCollateralDecimalsForPerp(synthCollateralBal, address(usdc), false)
                    );
                }
                if (tailCollateralBal > getUSDLInTail()) {
                    // do we have extra tail for synthUser
                    uint256 checkDiffInTail = ((usdcCollateralTransfer - synthCollateralBal) * 1e18) / closedPrice; // calculate the needed extra tail to transfer
                    uint256 checkTailForSynth = tailCollateralBal - getUSDLInTail(); // check how much extra tail we have for synthUser
                    if (checkTailForSynth > checkDiffInTail) {
                        SafeERC20Upgradeable.safeTransfer(
                            usdlCollateral,
                            to,
                            getAmountInCollateralDecimalsForPerp(checkDiffInTail, address(usdlCollateral), false)
                        );
                    } else {
                        SafeERC20Upgradeable.safeTransfer(
                            usdlCollateral,
                            to,
                            getAmountInCollateralDecimalsForPerp(checkTailForSynth, address(usdlCollateral), false)
                        );
                    }
                }
            }
            /// ERROR MESSAGE: => NEUM: Not enough USDL minted by this PerpLemmaContract
            require(mintedPositionSynthForThisWrapper >= usdlOrSynthAmount, "NEUM");
            mintedPositionSynthForThisWrapper -= usdlOrSynthAmount;
        }
    }

    /// @custom:deprecated not being used currently, there will be an update soon
    /// @notice swap USDC -> USDLCollateral
    function _USDCToCollateral(
        address router,
        uint256 routerType,
        bool isExactInput,
        uint256 amountUSDC
    ) internal returns (uint256) {
        return _swapOnDEXSpot(router, routerType, false, isExactInput, amountUSDC);
    }

    /// @custom:deprecated not being used currently, there will be an update soon
    /// @notice swap USDLCollateral -> USDC
    function _CollateralToUSDC(
        address router,
        uint256 routerType,
        bool isExactInput,
        uint256 amountCollateral
    ) internal returns (uint256) {
        return _swapOnDEXSpot(router, routerType, true, isExactInput, amountCollateral);
    }

    /// @notice will route the tx to specific exchange router
    function _swapOnDEXSpot(
        address router,
        uint256 routerType,
        bool isBuyUSDLCollateral,
        bool isExactInput,
        uint256 amountIn
    ) internal returns (uint256) {
        if (routerType == 0) {
            // NOTE: UniV3
            return _swapOnUniV3(router, isBuyUSDLCollateral, isExactInput, amountIn);
        }
        // NOTE: Unsupported Router --> Using UniV3 as default
        return _swapOnUniV3(router, isBuyUSDLCollateral, isExactInput, amountIn);
    }

    /// @custom:deprecated not being used currently, there will be an update soon
    /// @dev Helper function to swap on UniV3
    function _swapOnUniV3(
        address router,
        bool isUSDLCollateralToUSDC,
        bool isExactInput,
        uint256 amount
    ) internal returns (uint256) {
        uint256 res;
        address tokenIn = (isUSDLCollateralToUSDC) ? address(usdlCollateral) : address(usdc);
        address tokenOut = (isUSDLCollateralToUSDC) ? address(usdc) : address(usdlCollateral);

        SafeERC20Upgradeable.safeApprove(IERC20Upgradeable(tokenIn), router, MAX_UINT256);
        if (isExactInput) {
            ISwapRouter.ExactInputSingleParams memory temp = ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: 3000,
                recipient: address(this),
                deadline: MAX_UINT256,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
            uint256 balanceBefore = IERC20Decimals(tokenOut).balanceOf(address(this));
            res = ISwapRouter(router).exactInputSingle(temp);
            uint256 balanceAfter = IERC20Decimals(tokenOut).balanceOf(address(this));
            res = uint256(int256(balanceAfter) - int256(balanceBefore));
        } else {
            ISwapRouter.ExactOutputSingleParams memory temp = ISwapRouter.ExactOutputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: 3000,
                recipient: address(this),
                deadline: MAX_UINT256,
                amountOut: amount,
                amountInMaximum: MAX_UINT256,
                sqrtPriceLimitX96: 0
            });
            res = ISwapRouter(router).exactOutputSingle(temp);
        }
        SafeERC20Upgradeable.safeApprove(IERC20Upgradeable(tokenIn), router, 0);
        return res;
    }

    /// @notice getSynthInDollar will give lemmaSynth in dollar price, for e.g 1 LemmaSynthETH => 1000 USDC
    function getSynthInDollar() internal view returns (uint256) {
        return (mintedPositionSynthForThisWrapper * closedPrice) / 1e18;
    }

    /// @notice getUSDLInTail will give USDL in eth/tail collateral price, for e.g 1000 USDL => 1 ETH
    function getUSDLInTail() internal view returns (uint256) {
        return (mintedPositionUsdlForThisWrapper * 1e18) / closedPrice;
    }

    /// @notice getRoudDown is use to roundDown by amount = amount-1
    /// because perpV2 gives 1 wei increase in vaule for base and quote so we have to roundDown that 1 wei
    /// Otherwise it can give arithmetic error in calculateMintingAsset() function
    /// if the amount is less than collateral decimals value(like 1e18, 1e6) then it will compulsary roundDown 1 wei
    /// closeShortWithExactQuote, closeLongWithExactQuote are using getRoudDown method
    /// @param amount needs to roundDown
    /// @param collateral address, if the amount is base then it will be usdlCollateral otherwise synthCollateral
    function getRoudDown(uint256 amount, address collateral) internal view returns (uint256 roundDownAmount) {
        uint256 collateralDecimals = IERC20Decimals(collateral).decimals();
        roundDownAmount = (amount % (uint256(10**(collateralDecimals))) != 0) ? amount - 1 : amount;
    }

    /// @notice will convert amount to source to dest decimals
    function _convDecimals(
        uint256 amount,
        uint256 srcDecimals,
        uint256 dstDecimals
    ) internal pure returns (uint256 res) {
        res = (amount * 10**(dstDecimals)) / 10**(srcDecimals);
    }

    /// @notice _convUSDCToSynthAtIndexPrice will convert amount from USDC to Synth token at index price
    function _convUSDCToSynthAtIndexPrice(uint256 amountUSDC) internal view returns (uint256) {
        return _convDecimals(amountUSDC, usdcDecimals, 18 + IUSDLemma(lemmaSynth).decimals()) / getIndexPrice();
    }

    /// @notice _convSynthToUSDCAtIndexPrice will convert amount from Synth to USDC token at index price
    function _convSynthToUSDCAtIndexPrice(uint256 amountSynth) internal view returns (uint256) {
        return _convDecimals(amountSynth * getIndexPrice(), IUSDLemma(lemmaSynth).decimals() + 18, usdcDecimals);
    }

    /// @notice _convUSDCToUSDLIndexPrice will convert amount from USDC to USDL token.
    function _convUSDCToUSDLIndexPrice(uint256 amountUSDC) internal view returns (uint256) {
        return _convDecimals(amountUSDC, usdcDecimals, 18);
    }

    /// @notice _convUSDLToUSDCAtIndexPrice will convert amount from USDL to USDC token.
    function _convUSDLToUSDCAtIndexPrice(uint256 amountUSDL) internal view returns (uint256) {
        return _convDecimals(amountUSDL, 18, usdcDecimals);
    }

    /// @notice get min amount among a and b
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a <= b) ? a : b;
    }

    /// @notice get max amount among a and b (for int256)
    function _max(int256 a, int256 b) internal pure returns (int256) {
        return (a >= b) ? a : b;
    }

    /// @notice get max amount among a and b (for uint256)
    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a >= b) ? a : b;
    }

    /// @notice get _abs will convert negative amount to positive
    function _abs(int256 a) internal pure returns (uint256) {
        return (a >= 0) ? uint256(a) : uint256(-1 * a);
    }

    /// @notice Below we are not taking advantage of ERC2771ContextUpgradeable even though we should be able to
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return msg.sender;
    }

    /// @notice Below we are not taking advantage of ERC2771ContextUpgradeable even though we should be able to
    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return msg.data;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.3;

import "../interfaces/IERC20Decimals.sol";

interface IPerpetualMixDEXWrapper {
    enum Basis {
        IsUsdl,
        IsSynth,
        IsRebalance,
        IsSettle
    }

    function getSettlementToken() external view returns (address);

    function getMinFreeCollateral() external view returns (uint256);

    function getMinMarginSafeThreshold() external view returns (uint256);

    function getCollateralRatios() external view returns (uint24 imRatio, uint24 mmRatio);

    function getFreeCollateral() external view returns (uint256);

    function computeRequiredUSDCForTrade(uint256 amount, bool isShort) external view returns (uint256);

    function isAdditionalUSDCAcceptable(uint256 amount) external view returns (bool);

    function setMinFreeCollateral(uint256 _margin) external;

    function setMinMarginSafeThreshold(uint256 _margin) external;

    function setCollateralRatio(uint24 _ratio) external;

    function setPercFundingPaymentsToUSDLHolders(uint256) external;

    function setXUsdl(address _xUsdl) external;

    function setXSynth(address _xSynth) external;

    function hasSettled() external view returns (bool);

    function getMarkPrice() external view returns(uint256);

    function getPendingFundingPayment() external view returns(int256);

    function settlePendingFundingPayments() external;

    function distributeFundingPayments() external returns(bool, uint256, uint256);

    function getCollateralBackAfterSettlement(
        uint256 amount,
        address to,
        bool isUsdl
    ) external;

    function trade(
        uint256 amount,
        bool isShorting,
        bool isExactInput
    ) external returns (uint256 base, uint256 quote);

    function getAccountValue() external view returns (int256);

    function getRelativeMargin() external view returns (uint256);

    function getMargin() external view returns (int256);

    function getDeltaExposure() external view returns (int256);

    function getExposureDetails()
        external
        view
        returns (
            uint256,
            uint256,
            int256,
            int256,
            uint256
        );

    function getCollateralTokens() external view returns (address[] memory res);

    function getRequiredUSDCToBackMinting(uint256 amount, bool isShort) external view returns (bool, uint256);

    function getUsdlCollateralDecimals() external view returns (uint256);

    function getIndexPrice() external view returns (uint256);

    // Convenience trading functions
    function openLongWithExactBase(uint256 amount) external returns (uint256, uint256);

    function openLongWithExactQuote(uint256 amount) external returns (uint256, uint256);

    function closeLongWithExactBase(uint256 amount) external returns (uint256, uint256);

    function closeLongWithExactQuote(uint256 amount) external returns (uint256, uint256);

    function openShortWithExactBase(uint256 amount) external returns (uint256, uint256);

    function openShortWithExactQuote(uint256 amount) external returns (uint256, uint256);

    function closeShortWithExactBase(uint256 amount) external returns (uint256, uint256);

    function closeShortWithExactQuote(uint256 amount) external returns (uint256, uint256);

    /////////

    function calculateMintingAsset(
        uint256 amount,
        Basis basis,
        bool isOpenShort
    ) external;

    function getMaxSettlementTokenAcceptableByVault() external view returns (uint256);

    function getSettlementTokenAmountInVault() external view returns (int256);

    function depositSettlementToken(uint256 _amount) external;

    function withdrawSettlementToken(uint256 _amount) external;

    function deposit(uint256 amount, address collateral) external;

    function withdraw(uint256 amount, address collateral) external;

    function rebalance(
        address router,
        uint256 routerType,
        int256 amountBase,
        bool isCheckProfit
    ) external returns (uint256, uint256);

    // function reBalance(
    //     address _reBalancer,
    //     int256 amount,
    //     bytes calldata data
    // ) external returns (bool);

    function getTotalPosition() external view returns (int256);

    function getAmountInCollateralDecimalsForPerp(
        uint256 amount,
        address collateral,
        bool roundUp
    ) external view returns (uint256);

    function getFees() external view returns (uint256);

    function usdc() external view returns (IERC20Decimals);

    function settle() external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.3;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SignedSafeMathUpgradeable.sol";
import "./Constant.sol";
import "./Utils.sol";

enum Round {
    CEIL,
    FLOOR
}

library SafeMathExt {
    using SafeMathUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;

    /*
     * @dev Always half up for uint256
     */
    function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(y).add(Constant.UNSIGNED_ONE / 2) / Constant.UNSIGNED_ONE;
    }

    /*
     * @dev Always half up for uint256
     */
    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(Constant.UNSIGNED_ONE).add(y / 2).div(y);
    }

    /*
     * @dev Always half up for uint256
     */
    function wfrac(
        uint256 x,
        uint256 y,
        uint256 z
    ) internal pure returns (uint256 r) {
        r = x.mul(y).add(z / 2).div(z);
    }

    /*
     * @dev Always half up if no rounding parameter
     */
    function wmul(int256 x, int256 y) internal pure returns (int256 z) {
        z = roundHalfUp(x.mul(y), Constant.SIGNED_ONE) / Constant.SIGNED_ONE;
    }

    /*
     * @dev Always half up if no rounding parameter
     */
    function wdiv(int256 x, int256 y) internal pure returns (int256 z) {
        if (y < 0) {
            y = neg(y);
            x = neg(x);
        }
        z = roundHalfUp(x.mul(Constant.SIGNED_ONE), y).div(y);
    }

    /*
     * @dev Always half up if no rounding parameter
     */
    function wfrac(
        int256 x,
        int256 y,
        int256 z
    ) internal pure returns (int256 r) {
        int256 t = x.mul(y);
        if (z < 0) {
            z = neg(z);
            t = neg(t);
        }
        r = roundHalfUp(t, z).div(z);
    }

    function wmul(
        int256 x,
        int256 y,
        Round round
    ) internal pure returns (int256 z) {
        z = div(x.mul(y), Constant.SIGNED_ONE, round);
    }

    function wdiv(
        int256 x,
        int256 y,
        Round round
    ) internal pure returns (int256 z) {
        z = div(x.mul(Constant.SIGNED_ONE), y, round);
    }

    function wfrac(
        int256 x,
        int256 y,
        int256 z,
        Round round
    ) internal pure returns (int256 r) {
        int256 t = x.mul(y);
        r = div(t, z, round);
    }

    function abs(int256 x) internal pure returns (int256) {
        return x >= 0 ? x : neg(x);
    }

    function neg(int256 a) internal pure returns (int256) {
        return SignedSafeMathUpgradeable.sub(int256(0), a);
    }

    /*
     * @dev ROUND_HALF_UP rule helper.
     *      You have to call roundHalfUp(x, y) / y to finish the rounding operation.
     *      0.5 ≈ 1, 0.4 ≈ 0, -0.5 ≈ -1, -0.4 ≈ 0
     */
    function roundHalfUp(int256 x, int256 y) internal pure returns (int256) {
        require(y > 0, "roundHalfUp only supports y > 0");
        if (x >= 0) {
            return x.add(y / 2);
        }
        return x.sub(y / 2);
    }

    /*
     * @dev Division, rounding ceil or rounding floor
     */
    function div(
        int256 x,
        int256 y,
        Round round
    ) internal pure returns (int256 divResult) {
        require(y != 0, "division by zero");
        divResult = x.div(y);
        if (x % y == 0) {
            return divResult;
        }
        bool isSameSign = Utils.hasTheSameSign(x, y);
        if (round == Round.CEIL && isSameSign) {
            divResult = divResult.add(1);
        }
        if (round == Round.FLOOR && !isSameSign) {
            divResult = divResult.sub(1);
        }
    }

    function max(int256 a, int256 b) internal pure returns (int256) {
        return a >= b ? a : b;
    }

    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.3;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IERC20Decimals is IERC20Upgradeable {
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.3;

import {IERC20Upgradeable} from "../interfaces/IERC20Decimals.sol";

interface IUSDLemma is IERC20Upgradeable {
    function depositTo(
        address to,
        uint256 amount,
        uint256 perpetualDEXIndex,
        uint256 maxCollateralRequired,
        IERC20Upgradeable collateral
    ) external;

    function withdrawTo(
        address to,
        uint256 amount,
        uint256 perpetualDEXIndex,
        uint256 minCollateralToGetBack,
        IERC20Upgradeable collateral
    ) external;

    function depositToWExactCollateral(
        address to,
        uint256 collateralAmount,
        uint256 perpetualDEXIndex,
        uint256 minUSDLToMint,
        IERC20Upgradeable collateral
    ) external;

    function withdrawToWExactCollateral(
        address to,
        uint256 collateralAmount,
        uint256 perpetualDEXIndex,
        uint256 maxUSDLToBurn,
        IERC20Upgradeable collateral
    ) external;

    function mintToStackingContract(uint256 amount) external;
    function burnToStackingContract(uint256 amount) external;
    function requestLossesRecap(uint256 usdcAmount) external;

    function perpetualDEXWrappers(uint256 perpetualDEXIndex, address collateral)
        external
        view
        returns (address);

    function addPerpetualDEXWrapper(
        uint256 perpetualDEXIndex,
        address collateralAddress,
        address perpetualDEXWrapperAddress
    ) external;

    function setWhiteListAddress(address _account, bool _isWhiteList) external;

    function decimals() external view returns (uint256);

    function nonces(address owner) external view returns (uint256);

    function name() external view returns (string memory);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function closePosition(
        uint256 collateralAmount,
        uint256 perpetualDEXIndex,
        IERC20Upgradeable collateral
    ) external returns (uint256, uint256);

    function burnAndTransfer(
        uint256 USDLToBurn,
        uint256 collateralAmountToGetBack,
        address to,
        IERC20Upgradeable collateral
    ) external;

    function grantRole(bytes32 role, address account) external;

    event PerpetualDexWrapperAdded(
        uint256 indexed dexIndex,
        address indexed collateral,
        address dexWrapper
    );
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.3;

interface IClearingHouseConfig {
    /// @return maxMarketsPerAccount Max value of total markets per account
    function getMaxMarketsPerAccount() external view returns (uint8 maxMarketsPerAccount);

    /// @return imRatio Initial margin ratio
    function getImRatio() external view returns (uint24 imRatio);

    /// @return mmRatio Maintenance margin requirement ratio
    function getMmRatio() external view returns (uint24 mmRatio);

    /// @return liquidationPenaltyRatio Liquidation penalty ratio
    function getLiquidationPenaltyRatio() external view returns (uint24 liquidationPenaltyRatio);

    /// @return partialCloseRatio Partial close ratio
    function getPartialCloseRatio() external view returns (uint24 partialCloseRatio);

    /// @return twapInterval TwapInterval for funding and prices (mark & index) calculations
    function getTwapInterval() external view returns (uint32 twapInterval);

    /// @return settlementTokenBalanceCap Max value of settlement token balance
    function getSettlementTokenBalanceCap() external view returns (uint256 settlementTokenBalanceCap);

    /// @return maxFundingRate Max value of funding rate
    function getMaxFundingRate() external view returns (uint24 maxFundingRate);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.3;

// pragma abicoder v2;

interface IClearingHouse {
    event ReferredPositionChanged(bytes32 indexed referralCode);

    event PositionLiquidated(
        address indexed trader,
        address indexed baseToken,
        uint256 positionNotional,
        uint256 positionSize,
        uint256 liquidationFee,
        address liquidator
    );

    event FundingUpdated(address indexed baseToken, uint256 markTwap, uint256 indexTwap);

    //
    // STRUCT
    //

    struct AddLiquidityParams {
        address baseToken;
        uint256 base;
        uint256 quote;
        int24 lowerTick;
        int24 upperTick;
        uint256 minBase;
        uint256 minQuote;
        uint256 deadline;
    }

    /// @param liquidity collect fee when 0
    struct RemoveLiquidityParams {
        address baseToken;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint256 minBase;
        uint256 minQuote;
        uint256 deadline;
    }

    struct AddLiquidityResponse {
        uint256 base;
        uint256 quote;
        uint256 fee;
        uint256 liquidity;
    }

    struct RemoveLiquidityResponse {
        uint256 base;
        uint256 quote;
        uint256 fee;
    }

    struct OpenPositionParams {
        address baseToken;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        // B2Q + exact input, want more output quote as possible, so we set a lower bound of output quote
        // B2Q + exact output, want less input base as possible, so we set a upper bound of input base
        // Q2B + exact input, want more output base as possible, so we set a lower bound of output base
        // Q2B + exact output, want less input quote as possible, so we set a upper bound of input quote
        // when it's set to 0, it will disable slippage protection entirely regardless of exact input or output
        // when it's over or under the bound, it will be reverted
        uint256 oppositeAmountBound;
        uint256 deadline;
        // B2Q: the price cannot be less than this value after the swap
        // Q2B: The price cannot be greater than this value after the swap
        // it will fill the trade until it reach the price limit instead of reverted
        // when it's set to 0, it will disable price limit entirely regardless of B2Q or Q2B
        uint160 sqrtPriceLimitX96;
        bytes32 referralCode;
    }

    struct ClosePositionParams {
        address baseToken;
        uint160 sqrtPriceLimitX96;
        uint256 oppositeAmountBound;
        uint256 deadline;
        bytes32 referralCode;
    }

    function addLiquidity(AddLiquidityParams calldata params) external returns (AddLiquidityResponse memory);

    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        returns (RemoveLiquidityResponse memory response);

    function openPosition(OpenPositionParams memory params) external returns (uint256 deltaBase, uint256 deltaQuote);

    function closePosition(ClosePositionParams calldata params)
        external
        returns (uint256 deltaBase, uint256 deltaQuote);

    /// @notice Close all positions of a trader in the closed market
    /// @param trader The address of trader
    /// @param baseToken The address of baseToken
    /// @return base The amount of base token that is closed
    /// @return quote The amount of quote token that is closed
    function quitMarket(address trader, address baseToken) external returns (uint256 base, uint256 quote);

    function liquidate(address trader, address baseToken) external;

    function cancelExcessOrders(
        address maker,
        address baseToken,
        bytes32[] calldata orderIds
    ) external;

    function cancelAllExcessOrders(address maker, address baseToken) external;

    /// @dev accountValue = totalCollateralValue + totalUnrealizedPnl, in settlement token's decimals
    function getAccountValue(address trader) external view returns (int256);

    function getQuoteToken() external view returns (address);

    function getUniswapV3Factory() external view returns (address);

    function getClearingHouseConfig() external view returns (address);

    function getVault() external view returns (address);

    function getExchange() external view returns (address);

    function getOrderBook() external view returns (address);

    function getAccountBalance() external view returns (address);

    function settleAllFunding(address trader) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.3;

interface IMarketRegistry {
    struct MarketInfo {
        address pool;
        uint24 exchangeFeeRatio;
        uint24 uniswapFeeRatio;
        uint24 insuranceFundFeeRatio;
    }

    /// @notice Emitted when a new market is created.
    /// @param baseToken The address of the base token
    /// @param feeRatio Fee ratio of the market
    /// @param pool The address of the pool
    event PoolAdded(address indexed baseToken, uint24 indexed feeRatio, address indexed pool);

    /// @notice Emitted when the fee ratio of a market is updated.
    /// @param baseToken The address of the base token
    /// @param feeRatio Fee ratio of the market
    event FeeRatioChanged(address baseToken, uint24 feeRatio);

    /// @notice Emitted when the insurance fund fee ratio is updated.
    /// @param feeRatio Insurance fund fee ratio
    event InsuranceFundFeeRatioChanged(uint24 feeRatio);

    /// @notice Emitted when the max orders per market is updated.
    /// @param maxOrdersPerMarket Max orders per market
    event MaxOrdersPerMarketChanged(uint8 maxOrdersPerMarket);

    /// @dev Add a new pool to the registry.
    /// @param baseToken The token that the pool is for.
    /// @param feeRatio The fee ratio for the pool.
    /// @return pool The address of the pool.
    function addPool(address baseToken, uint24 feeRatio) external returns (address pool);

    /// @dev Set the fee ratio for a pool
    /// @param baseToken The token address of the pool.
    /// @param feeRatio The fee ratio for the pool.
    function setFeeRatio(address baseToken, uint24 feeRatio) external;

    /// @dev Set insurance fund fee ratio for a pool
    /// @param baseToken The token address of the pool.
    /// @param insuranceFundFeeRatioArg The fee ratio for the pool.
    function setInsuranceFundFeeRatio(address baseToken, uint24 insuranceFundFeeRatioArg) external;

    /// @dev Set max allowed orders per market
    /// @param maxOrdersPerMarketArg The max allowed orders per market
    function setMaxOrdersPerMarket(uint8 maxOrdersPerMarketArg) external;

    /// @notice Get the pool address (UNIv3 pool) by given base token address
    /// @param baseToken The address of the base token
    /// @return pool The address of the pool
    function getPool(address baseToken) external view returns (address pool);

    /// @notice Get the fee ratio of a given market
    /// @dev The ratio is in `1e6` format, that means `1% = 1e4`
    /// @param baseToken The address of the base token
    /// @return feeRatio The fee ratio of the market, it is a decimal in `1e6`
    function getFeeRatio(address baseToken) external view returns (uint24 feeRatio);

    /// @notice Get the insurance fund fee ratio of a given market
    /// @dev The ratio is in `1e6` format, that means `1% = 1e4`
    /// @param baseToken The address of the base token
    /// @return feeRatio The fee ratio of the market, it is a decimal in `1e6`
    function getInsuranceFundFeeRatio(address baseToken) external view returns (uint24 feeRatio);

    /// @notice Get the market info by given base token address
    /// @param baseToken The address of the base token
    /// @return info The market info encoded as `MarketInfo`
    function getMarketInfo(address baseToken) external view returns (MarketInfo memory info);

    /// @notice Get the quote token address
    /// @return quoteToken The address of the quote token
    function getQuoteToken() external view returns (address quoteToken);

    /// @notice Get Uniswap factory address
    /// @return factory The address of the Uniswap factory
    function getUniswapV3Factory() external view returns (address factory);

    /// @notice Get max allowed orders per market
    /// @return maxOrdersPerMarket The max allowed orders per market
    function getMaxOrdersPerMarket() external view returns (uint8 maxOrdersPerMarket);

    /// @notice Check if a pool exist by given base token address
    /// @return hasPool True if the pool exist, false otherwise
    function hasPool(address baseToken) external view returns (bool);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.3;

interface IBaseToken {
    // Do NOT change the order of enum values because it will break backwards compatibility
    enum Status {
        Open,
        Paused,
        Closed
    }

    event PriceFeedChanged(address indexed priceFeed);
    event StatusUpdated(Status indexed status);

    function setPriceFeed(address) external;

    function pause() external;

    function close() external;

    function close(uint256 closedPrice) external;

    /// @notice Get the price feed address
    /// @return priceFeed the current price feed
    function getPriceFeed() external view returns (address priceFeed);

    function getIndexPrice(uint256) external view returns (uint256);

    function getPausedTimestamp() external view returns (uint256);

    function getPausedIndexPrice() external view returns (uint256);

    function getClosedPrice() external view returns (uint256);

    function isOpen() external view returns (bool);

    function isPaused() external view returns (bool);

    function isClosed() external view returns (bool);

    function owner() external view returns (address);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.3;

interface IPerpVault {
    function deposit(address token, uint256 amount) external;

    function withdraw(address token, uint256 amountX10_D) external;

    function getBalance(address trader) external view returns (int256);

    function decimals() external view returns (uint8);

    function getSettlementToken() external view returns (address settlementToken);

    function getFreeCollateral(address trader) external view returns (uint256);

    function getFreeCollateralByRatio(address trader, uint24 ratio)
        external
        view
        returns (int256 freeCollateralByRatio);

    function getFreeCollateralByToken(address trader, address token) external view returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.3;

interface IIndexPrice {
    /// @dev Returns the index price of the token.
    /// @param interval The interval represents twap interval.
    /// @return indexPrice Twap price with interval
    function getIndexPrice(uint256 interval) external view returns (uint256 indexPrice);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.3;

interface IAccountBalance {
    function getTotalPositionSize(address trader, address baseToken) external view returns (int256);

    function getPositionSize(address trader, address baseToken) external view returns (int256);

    function getTotalPositionValue(address trader, address baseToken) external view returns (int256);

    function getPnlAndPendingFee(address trader)
        external
        view
        returns (
            int256 owedRealizedPnl,
            int256 unrealizedPnl,
            uint256 pendingFee
        );

    function getMarginRequirementForLiquidation(address trader)
        external
        view
        returns (int256 marginRequirementForLiquidation);

    function getBase(address trader, address baseToken) external view returns (int256 baseAmount);

    function getQuote(address trader, address baseToken) external view returns (int256);

    function settleOwedRealizedPnl(address trader) external returns (int256);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.3;

interface IExchange {
    /// @notice Get all the pending funding payment for a trader
    /// @return pendingFundingPayment The pending funding payment of the trader.
    /// Positive value means the trader pays funding, negative value means the trader receives funding.
    function getAllPendingFundingPayment(address trader) external view returns (int256 pendingFundingPayment);

    /// @notice Get the pending funding payment for a trader in a given market
    /// @dev this is the view version of _updateFundingGrowth()
    /// @return pendingFundingPayment The pending funding payment of a trader in one market,
    /// including liquidity & balance coefficients. Positive value means the trader pays funding,
    /// negative value means the trader receives funding.
    function getPendingFundingPayment(address trader, address baseToken)
        external
        view
        returns (int256 pendingFundingPayment);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/*
 * @dev Context variant with ERC2771 support.
 */
abstract contract ERC2771ContextUpgradeable is Initializable, ContextUpgradeable {
    address _trustedForwarder;

    function __ERC2771Context_init(address trustedForwarder) internal initializer {
        __Context_init_unchained();
        __ERC2771Context_init_unchained(trustedForwarder);
    }

    function __ERC2771Context_init_unchained(address trustedForwarder) internal initializer {
        _trustedForwarder = trustedForwarder;
    }

    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == _trustedForwarder;
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

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
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        _setOwner(_msgSender());
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
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    function hasRole(bytes32 role, address account) external view returns (bool);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role, address account) external;
}

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
    }

    function __AccessControl_init_unchained() internal initializer {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{20}) is missing role (0x[0-9a-f]{32})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{20}) is missing role (0x[0-9a-f]{32})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(uint160(account), 20),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        emit RoleAdminChanged(role, getRoleAdmin(role), adminRole);
        _roles[role].adminRole = adminRole;
    }

    function _grantRole(bytes32 role, address account) private {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import './pool/IUniswapV3PoolImmutables.sol';
import './pool/IUniswapV3PoolState.sol';
import './pool/IUniswapV3PoolDerivedState.sol';
import './pool/IUniswapV3PoolActions.sol';
import './pool/IUniswapV3PoolOwnerActions.sol';
import './pool/IUniswapV3PoolEvents.sol';

/// @title The interface for a Uniswap V3 Pool
/// @notice A Uniswap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IUniswapV3Pool is
    IUniswapV3PoolImmutables,
    IUniswapV3PoolState,
    IUniswapV3PoolDerivedState,
    IUniswapV3PoolActions,
    IUniswapV3PoolOwnerActions,
    IUniswapV3PoolEvents
{

}

// SPDX-License-Identifier: MIT

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

pragma solidity ^0.8.0;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCastUpgradeable {
    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128) {
        require(value >= type(int128).min && value <= type(int128).max, "SafeCast: value doesn't fit in 128 bits");
        return int128(value);
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64) {
        require(value >= type(int64).min && value <= type(int64).max, "SafeCast: value doesn't fit in 64 bits");
        return int64(value);
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32) {
        require(value >= type(int32).min && value <= type(int32).max, "SafeCast: value doesn't fit in 32 bits");
        return int32(value);
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16) {
        require(value >= type(int16).min && value <= type(int16).max, "SafeCast: value doesn't fit in 16 bits");
        return int16(value);
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= type(int8).min && value <= type(int8).max, "SafeCast: value doesn't fit in 8 bits");
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol';

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface ISwapRouter is IUniswapV3SwapCallback {
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

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}

// SPDX-License-Identifier: MIT

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

// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.3;

library Constant {
    address internal constant INVALID_ADDRESS = address(0);

    int256 internal constant SIGNED_ONE = 10**18;
    uint256 internal constant UNSIGNED_ONE = 10**18;

    uint256 internal constant PRIVILEGE_DEPOSIT = 0x1;
    uint256 internal constant PRIVILEGE_WITHDRAW = 0x2;
    uint256 internal constant PRIVILEGE_TRADE = 0x4;
    uint256 internal constant PRIVILEGE_LIQUIDATE = 0x8;
    uint256 internal constant PRIVILEGE_GUARD =
        PRIVILEGE_DEPOSIT | PRIVILEGE_WITHDRAW | PRIVILEGE_TRADE | PRIVILEGE_LIQUIDATE;
    // max number of uint256
    uint256 internal constant SET_ALL_PERPETUALS_TO_EMERGENCY_STATE =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.3;

import "./SafeMathExt.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SignedSafeMathUpgradeable.sol";

//recreating https://github.com/mcdexio/mai-protocol-v3/blob/master/contracts/libraries/Utils.sol
library Utils {
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;

    /*
     * @dev Check if two numbers have the same sign. Zero has the same sign with any number
     */
    function hasTheSameSign(int256 x, int256 y) internal pure returns (bool) {
        if (x == 0 || y == 0) {
            return true;
        }
        return (x ^ y) >> 255 == 0;
    }

    /*
     * @dev Split the delta to two numbers.
     *      Use for splitting the trading amount to the amount to close position and the amount to open position.
     *      Examples: 2, 1 => 0, 1; 2, -1 => -1, 0; 2, -3 => -2, -1
     */
    function splitAmount(int256 amount, int256 delta) internal pure returns (int256, int256) {
        if (Utils.hasTheSameSign(amount, delta)) {
            return (0, delta);
        } else if (amount.abs() >= delta.abs()) {
            return (delta, 0);
        } else {
            return (amount.neg(), amount.add(delta));
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is no longer needed starting with Solidity 0.8. The compiler
 * now has built in overflow checking.
 */
library SafeMathUpgradeable {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
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
        return a + b;
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
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
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
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
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
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SignedSafeMath` is no longer needed starting with Solidity 0.8. The compiler
 * now has built in overflow checking.
 */
library SignedSafeMathUpgradeable {
    /**
     * @dev Returns the multiplication of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two signed integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(int256 a, int256 b) internal pure returns (int256) {
        return a / b;
    }

    /**
     * @dev Returns the subtraction of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        return a - b;
    }

    /**
     * @dev Returns the addition of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(int256 a, int256 b) internal pure returns (int256) {
        return a + b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/*
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
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
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

pragma solidity ^0.8.0;

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
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

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
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

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
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal initializer {
        __ERC165_init_unchained();
    }

    function __ERC165_init_unchained() internal initializer {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Pool state that never changes
/// @notice These parameters are fixed for a pool forever, i.e., the methods will always return the same values
interface IUniswapV3PoolImmutables {
    /// @notice The contract that deployed the pool, which must adhere to the IUniswapV3Factory interface
    /// @return The contract address
    function factory() external view returns (address);

    /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (address);

    /// @notice The pool's fee in hundredths of a bip, i.e. 1e-6
    /// @return The fee
    function fee() external view returns (uint24);

    /// @notice The pool tick spacing
    /// @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
    /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
    /// This value is an int24 to avoid casting even though it is always positive.
    /// @return The tick spacing
    function tickSpacing() external view returns (int24);

    /// @notice The maximum amount of position liquidity that can use any tick in the range
    /// @dev This parameter is enforced per tick to prevent liquidity from overflowing a uint128 at any point, and
    /// also prevents out-of-range liquidity from being used to prevent adding in-range liquidity to a pool
    /// @return The max amount of liquidity per tick
    function maxLiquidityPerTick() external view returns (uint128);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Pool state that can change
/// @notice These methods compose the pool's state, and can change with any frequency including multiple times
/// per transaction
interface IUniswapV3PoolState {
    /// @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
    /// when accessed externally.
    /// @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
    /// tick The current tick of the pool, i.e. according to the last tick transition that was run.
    /// This value may not always be equal to SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96) if the price is on a tick
    /// boundary.
    /// observationIndex The index of the last oracle observation that was written,
    /// observationCardinality The current maximum number of observations stored in the pool,
    /// observationCardinalityNext The next maximum number of observations, to be updated when the observation.
    /// feeProtocol The protocol fee for both tokens of the pool.
    /// Encoded as two 4 bit values, where the protocol fee of token1 is shifted 4 bits and the protocol fee of token0
    /// is the lower 4 bits. Used as the denominator of a fraction of the swap fee, e.g. 4 means 1/4th of the swap fee.
    /// unlocked Whether the pool is currently locked to reentrancy
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    /// @notice The fee growth as a Q128.128 fees of token0 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal0X128() external view returns (uint256);

    /// @notice The fee growth as a Q128.128 fees of token1 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal1X128() external view returns (uint256);

    /// @notice The amounts of token0 and token1 that are owed to the protocol
    /// @dev Protocol fees will never exceed uint128 max in either token
    function protocolFees() external view returns (uint128 token0, uint128 token1);

    /// @notice The currently in range liquidity available to the pool
    /// @dev This value has no relationship to the total liquidity across all ticks
    function liquidity() external view returns (uint128);

    /// @notice Look up information about a specific tick in the pool
    /// @param tick The tick to look up
    /// @return liquidityGross the total amount of position liquidity that uses the pool either as tick lower or
    /// tick upper,
    /// liquidityNet how much liquidity changes when the pool price crosses the tick,
    /// feeGrowthOutside0X128 the fee growth on the other side of the tick from the current tick in token0,
    /// feeGrowthOutside1X128 the fee growth on the other side of the tick from the current tick in token1,
    /// tickCumulativeOutside the cumulative tick value on the other side of the tick from the current tick
    /// secondsPerLiquidityOutsideX128 the seconds spent per liquidity on the other side of the tick from the current tick,
    /// secondsOutside the seconds spent on the other side of the tick from the current tick,
    /// initialized Set to true if the tick is initialized, i.e. liquidityGross is greater than 0, otherwise equal to false.
    /// Outside values can only be used if the tick is initialized, i.e. if liquidityGross is greater than 0.
    /// In addition, these values are only relative and must be used only in comparison to previous snapshots for
    /// a specific position.
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    /// @notice Returns 256 packed tick initialized boolean values. See TickBitmap for more information
    function tickBitmap(int16 wordPosition) external view returns (uint256);

    /// @notice Returns the information about a position by the position's key
    /// @param key The position's key is a hash of a preimage composed by the owner, tickLower and tickUpper
    /// @return _liquidity The amount of liquidity in the position,
    /// Returns feeGrowthInside0LastX128 fee growth of token0 inside the tick range as of the last mint/burn/poke,
    /// Returns feeGrowthInside1LastX128 fee growth of token1 inside the tick range as of the last mint/burn/poke,
    /// Returns tokensOwed0 the computed amount of token0 owed to the position as of the last mint/burn/poke,
    /// Returns tokensOwed1 the computed amount of token1 owed to the position as of the last mint/burn/poke
    function positions(bytes32 key)
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    /// @notice Returns data about a specific observation index
    /// @param index The element of the observations array to fetch
    /// @dev You most likely want to use #observe() instead of this method to get an observation as of some amount of time
    /// ago, rather than at a specific index in the array.
    /// @return blockTimestamp The timestamp of the observation,
    /// Returns tickCumulative the tick multiplied by seconds elapsed for the life of the pool as of the observation timestamp,
    /// Returns secondsPerLiquidityCumulativeX128 the seconds per in range liquidity for the life of the pool as of the observation timestamp,
    /// Returns initialized whether the observation has been initialized and the values are safe to use
    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Pool state that is not stored
/// @notice Contains view functions to provide information about the pool that is computed rather than stored on the
/// blockchain. The functions here may have variable gas costs.
interface IUniswapV3PoolDerivedState {
    /// @notice Returns the cumulative tick and liquidity as of each timestamp `secondsAgo` from the current block timestamp
    /// @dev To get a time weighted average tick or liquidity-in-range, you must call this with two values, one representing
    /// the beginning of the period and another for the end of the period. E.g., to get the last hour time-weighted average tick,
    /// you must call it with secondsAgos = [3600, 0].
    /// @dev The time weighted average tick represents the geometric time weighted average price of the pool, in
    /// log base sqrt(1.0001) of token1 / token0. The TickMath library can be used to go from a tick value to a ratio.
    /// @param secondsAgos From how long ago each cumulative tick and liquidity value should be returned
    /// @return tickCumulatives Cumulative tick values as of each `secondsAgos` from the current block timestamp
    /// @return secondsPerLiquidityCumulativeX128s Cumulative seconds per liquidity-in-range value as of each `secondsAgos` from the current block
    /// timestamp
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);

    /// @notice Returns a snapshot of the tick cumulative, seconds per liquidity and seconds inside a tick range
    /// @dev Snapshots must only be compared to other snapshots, taken over a period for which a position existed.
    /// I.e., snapshots cannot be compared if a position is not held for the entire period between when the first
    /// snapshot is taken and the second snapshot is taken.
    /// @param tickLower The lower tick of the range
    /// @param tickUpper The upper tick of the range
    /// @return tickCumulativeInside The snapshot of the tick accumulator for the range
    /// @return secondsPerLiquidityInsideX128 The snapshot of seconds per liquidity for the range
    /// @return secondsInside The snapshot of seconds per liquidity for the range
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
        external
        view
        returns (
            int56 tickCumulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        );
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Permissionless pool actions
/// @notice Contains pool methods that can be called by anyone
interface IUniswapV3PoolActions {
    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
    function initialize(uint160 sqrtPriceX96) external;

    /// @notice Adds liquidity for the given recipient/tickLower/tickUpper position
    /// @dev The caller of this method receives a callback in the form of IUniswapV3MintCallback#uniswapV3MintCallback
    /// in which they must pay any token0 or token1 owed for the liquidity. The amount of token0/token1 due depends
    /// on tickLower, tickUpper, the amount of liquidity, and the current price.
    /// @param recipient The address for which the liquidity will be created
    /// @param tickLower The lower tick of the position in which to add liquidity
    /// @param tickUpper The upper tick of the position in which to add liquidity
    /// @param amount The amount of liquidity to mint
    /// @param data Any data that should be passed through to the callback
    /// @return amount0 The amount of token0 that was paid to mint the given amount of liquidity. Matches the value in the callback
    /// @return amount1 The amount of token1 that was paid to mint the given amount of liquidity. Matches the value in the callback
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Collects tokens owed to a position
    /// @dev Does not recompute fees earned, which must be done either via mint or burn of any amount of liquidity.
    /// Collect must be called by the position owner. To withdraw only token0 or only token1, amount0Requested or
    /// amount1Requested may be set to zero. To withdraw all tokens owed, caller may pass any value greater than the
    /// actual tokens owed, e.g. type(uint128).max. Tokens owed may be from accumulated swap fees or burned liquidity.
    /// @param recipient The address which should receive the fees collected
    /// @param tickLower The lower tick of the position for which to collect fees
    /// @param tickUpper The upper tick of the position for which to collect fees
    /// @param amount0Requested How much token0 should be withdrawn from the fees owed
    /// @param amount1Requested How much token1 should be withdrawn from the fees owed
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    /// @notice Burn liquidity from the sender and account tokens owed for the liquidity to the position
    /// @dev Can be used to trigger a recalculation of fees owed to a position by calling with an amount of 0
    /// @dev Fees must be collected separately via a call to #collect
    /// @param tickLower The lower tick of the position for which to burn liquidity
    /// @param tickUpper The upper tick of the position for which to burn liquidity
    /// @param amount How much liquidity to burn
    /// @return amount0 The amount of token0 sent to the recipient
    /// @return amount1 The amount of token1 sent to the recipient
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Swap token0 for token1, or token1 for token0
    /// @dev The caller of this method receives a callback in the form of IUniswapV3SwapCallback#uniswapV3SwapCallback
    /// @param recipient The address to receive the output of the swap
    /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
    /// @param amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
    /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
    /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
    /// @param data Any data to be passed through to the callback
    /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
    /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    /// @notice Receive token0 and/or token1 and pay it back, plus a fee, in the callback
    /// @dev The caller of this method receives a callback in the form of IUniswapV3FlashCallback#uniswapV3FlashCallback
    /// @dev Can be used to donate underlying tokens pro-rata to currently in-range liquidity providers by calling
    /// with 0 amount{0,1} and sending the donation amount(s) from the callback
    /// @param recipient The address which will receive the token0 and token1 amounts
    /// @param amount0 The amount of token0 to send
    /// @param amount1 The amount of token1 to send
    /// @param data Any data to be passed through to the callback
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    /// @notice Increase the maximum number of price and liquidity observations that this pool will store
    /// @dev This method is no-op if the pool already has an observationCardinalityNext greater than or equal to
    /// the input observationCardinalityNext.
    /// @param observationCardinalityNext The desired minimum number of observations for the pool to store
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Permissioned pool actions
/// @notice Contains pool methods that may only be called by the factory owner
interface IUniswapV3PoolOwnerActions {
    /// @notice Set the denominator of the protocol's % share of the fees
    /// @param feeProtocol0 new protocol fee for token0 of the pool
    /// @param feeProtocol1 new protocol fee for token1 of the pool
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external;

    /// @notice Collect the protocol fee accrued to the pool
    /// @param recipient The address to which collected protocol fees should be sent
    /// @param amount0Requested The maximum amount of token0 to send, can be 0 to collect fees in only token1
    /// @param amount1Requested The maximum amount of token1 to send, can be 0 to collect fees in only token0
    /// @return amount0 The protocol fee collected in token0
    /// @return amount1 The protocol fee collected in token1
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Events emitted by a pool
/// @notice Contains all events emitted by the pool
interface IUniswapV3PoolEvents {
    /// @notice Emitted exactly once by a pool when #initialize is first called on the pool
    /// @dev Mint/Burn/Swap cannot be emitted by the pool before Initialize
    /// @param sqrtPriceX96 The initial sqrt price of the pool, as a Q64.96
    /// @param tick The initial tick of the pool, i.e. log base 1.0001 of the starting price of the pool
    event Initialize(uint160 sqrtPriceX96, int24 tick);

    /// @notice Emitted when liquidity is minted for a given position
    /// @param sender The address that minted the liquidity
    /// @param owner The owner of the position and recipient of any minted liquidity
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount The amount of liquidity minted to the position range
    /// @param amount0 How much token0 was required for the minted liquidity
    /// @param amount1 How much token1 was required for the minted liquidity
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted when fees are collected by the owner of a position
    /// @dev Collect events may be emitted with zero amount0 and amount1 when the caller chooses not to collect fees
    /// @param owner The owner of the position for which fees are collected
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount0 The amount of token0 fees collected
    /// @param amount1 The amount of token1 fees collected
    event Collect(
        address indexed owner,
        address recipient,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount0,
        uint128 amount1
    );

    /// @notice Emitted when a position's liquidity is removed
    /// @dev Does not withdraw any fees earned by the liquidity position, which must be withdrawn via #collect
    /// @param owner The owner of the position for which liquidity is removed
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount The amount of liquidity to remove
    /// @param amount0 The amount of token0 withdrawn
    /// @param amount1 The amount of token1 withdrawn
    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted by the pool for any swaps between token0 and token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the output of the swap
    /// @param amount0 The delta of the token0 balance of the pool
    /// @param amount1 The delta of the token1 balance of the pool
    /// @param sqrtPriceX96 The sqrt(price) of the pool after the swap, as a Q64.96
    /// @param liquidity The liquidity of the pool after the swap
    /// @param tick The log base 1.0001 of price of the pool after the swap
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    /// @notice Emitted by the pool for any flashes of token0/token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the tokens from flash
    /// @param amount0 The amount of token0 that was flashed
    /// @param amount1 The amount of token1 that was flashed
    /// @param paid0 The amount of token0 paid for the flash, which can exceed the amount0 plus the fee
    /// @param paid1 The amount of token1 paid for the flash, which can exceed the amount1 plus the fee
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );

    /// @notice Emitted by the pool for increases to the number of observations that can be stored
    /// @dev observationCardinalityNext is not the observation cardinality until an observation is written at the index
    /// just before a mint/swap/burn.
    /// @param observationCardinalityNextOld The previous value of the next observation cardinality
    /// @param observationCardinalityNextNew The updated value of the next observation cardinality
    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld,
        uint16 observationCardinalityNextNew
    );

    /// @notice Emitted when the protocol fee is changed by the pool
    /// @param feeProtocol0Old The previous value of the token0 protocol fee
    /// @param feeProtocol1Old The previous value of the token1 protocol fee
    /// @param feeProtocol0New The updated value of the token0 protocol fee
    /// @param feeProtocol1New The updated value of the token1 protocol fee
    event SetFeeProtocol(uint8 feeProtocol0Old, uint8 feeProtocol1Old, uint8 feeProtocol0New, uint8 feeProtocol1New);

    /// @notice Emitted when the collected protocol fees are withdrawn by the factory owner
    /// @param sender The address that collects the protocol fees
    /// @param recipient The address that receives the collected protocol fees
    /// @param amount0 The amount of token0 protocol fees that is withdrawn
    /// @param amount0 The amount of token1 protocol fees that is withdrawn
    event CollectProtocol(address indexed sender, address indexed recipient, uint128 amount0, uint128 amount1);
}

// SPDX-License-Identifier: MIT

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
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
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

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Callback for IUniswapV3PoolActions#swap
/// @notice Any contract that calls IUniswapV3PoolActions#swap must implement this interface
interface IUniswapV3SwapCallback {
    /// @notice Called to `msg.sender` after executing a swap via IUniswapV3Pool#swap.
    /// @dev In the implementation you must pay the pool tokens owed for the swap.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// amount0Delta and amount1Delta can both be 0 if no tokens were swapped.
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token0 to the pool.
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token1 to the pool.
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}