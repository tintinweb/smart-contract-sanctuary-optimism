/*
    Copyright 2021 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;
pragma experimental "ABIEncoderV2";

import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import { PerpV2 } from "../integration/lib/PerpV2.sol";
import { UniswapV3Math } from "../integration/lib/UniswapV3Math.sol";
import { IAccountBalance } from "../../interfaces/external/perp-v2/IAccountBalance.sol";
import { IClearingHouse } from "../../interfaces/external/perp-v2/IClearingHouse.sol";
import { IClearingHouseConfig } from "../../interfaces/external/perp-v2/IClearingHouseConfig.sol";
import { IExchange } from "../../interfaces/external/perp-v2/IExchange.sol";
import { IIndexPrice } from "../../interfaces/external/perp-v2/IIndexPrice.sol";
import { IVault } from "../../interfaces/external/perp-v2/IVault.sol";
import { IQuoter } from "../../interfaces/external/perp-v2/IQuoter.sol";
import { IMarketRegistry } from "../../interfaces/external/perp-v2/IMarketRegistry.sol";
import { IController } from "../../interfaces/IController.sol";
import { IDebtIssuanceModule } from "../../interfaces/IDebtIssuanceModule.sol";
import { IModuleIssuanceHookV2 } from "../../interfaces/IModuleIssuanceHookV2.sol";
import { ISetToken } from "../../interfaces/ISetToken.sol";
import { ModuleBase } from "../lib/ModuleBase.sol";
import { SetTokenAccessible } from "../lib/SetTokenAccessible.sol";
import { PreciseUnitMath } from "../../lib/PreciseUnitMath.sol";
import { AddressArrayUtils } from "../../lib/AddressArrayUtils.sol";
import { UnitConversionUtils } from "../../lib/UnitConversionUtils.sol";

/**
 * @title PerpV2LeverageModule
 * @author Set Protocol
 * @notice Smart contract that enables leveraged trading using the PerpV2 protocol. Each SetToken can only manage a single Perp account
 * represented as a positive equity external position whose value is the net Perp account value denominated in the collateral token
 * deposited into the Perp Protocol. This module only allows Perp positions to be collateralized by one asset, USDC, set on deployment of
 * this contract (see collateralToken) however it can take positions simultaneously in multiple base assets.
 *
 * Upon issuance and redemption positions are not EXACTLY replicated like for other position types since a trade is necessary to enter/exit
 * the position on behalf of the issuer/redeemer. Any cost of entering/exiting the position (slippage) is carried by the issuer/redeemer.
 * Any pending funding costs or PnL is carried by the current token holders. To be used safely this module MUST issue using the
 * SlippageIssuanceModule or else issue and redeem transaction could be sandwich attacked.
 *
 * NOTE: The external position unit is only updated on an as-needed basis during issuance/redemption. It does not reflect the current
 * value of the Set's perpetual position. The current value can be calculated from getPositionNotionalInfo.
 */
contract PerpV2LeverageModule is ModuleBase, ReentrancyGuard, Ownable, SetTokenAccessible, IModuleIssuanceHookV2 {
    using PerpV2 for ISetToken;
    using PreciseUnitMath for int256;
    using SignedSafeMath for int256;
    using UnitConversionUtils for int256;
    using UniswapV3Math for uint160;
    using UniswapV3Math for uint256;
    using UnitConversionUtils for uint256;
    using AddressArrayUtils for address[];

    /* ============ Structs ============ */

    struct ActionInfo {
        ISetToken setToken;
        address baseToken;              // Virtual token minted by the Perp protocol
        bool isBuy;                     // When true, `baseToken` is being bought, when false, sold
        uint256 baseTokenAmount;        // Base token quantity in 10**18 decimals
        uint256 oppositeAmountBound;    // vUSDC pay or receive quantity bound (see `_createActionInfoNotional` for details)
    }

    struct PositionNotionalInfo {
        address baseToken;              // Virtual token minted by the Perp protocol
        int256 baseBalance;             // Base position notional quantity in 10**18 decimals. When negative, position is short
        int256 quoteBalance;            // vUSDC "debt" notional quantity minted to open position. When positive, position is short
    }

    struct PositionUnitInfo {
        address baseToken;              // Virtual token minted by the Perp protocol
        int256 baseUnit;                // Base position unit. When negative, position is short
        int256 quoteUnit;               // vUSDC "debt" position unit. When positive, position is short
    }

    // Note: when `pendingFundingPayments` is positive it will be credited to account on settlement,
    // when negative it's a debt owed that will be repaid on settlement. (PerpProtocol.Exchange returns the value
    // with the opposite meaning, e.g positively signed payments are owed by account to system).
    struct AccountInfo {
        int256 collateralBalance;       // Quantity of collateral deposited in Perp vault in 10**18 decimals
        int256 owedRealizedPnl;         // USDC quantity of profit and loss in 10**18 decimals not yet settled to vault
        int256 pendingFundingPayments;  // USDC quantity of pending funding payments in 10**18 decimals
        int256 netQuoteBalance;         // USDC quantity of net quote balance for all open positions in Perp account
    }

    /* ============ Events ============ */

    /**
     * @dev Emitted on trade
     * @param _setToken         Instance of SetToken
     * @param _baseToken        Virtual token minted by the Perp protocol
     * @param _deltaBase        Change in baseToken position size resulting from trade
     * @param _deltaQuote       Change in vUSDC position size resulting from trade
     * @param _protocolFee      Quantity in collateral decimals sent to fee recipient during lever trade
     * @param _isBuy            True when baseToken is being bought, false when being sold
     */
    event PerpTraded(
        ISetToken indexed _setToken,
        address indexed _baseToken,
        uint256 indexed _deltaBase,
        uint256 _deltaQuote,
        uint256 _protocolFee,
        bool _isBuy
    );

    /**
     * @dev Emitted on deposit (not issue or redeem)
     * @param _setToken             Instance of SetToken
     * @param _collateralToken      Token being deposited as collateral (USDC)
     * @param _amountDeposited      Amount of collateral being deposited into Perp
     */
    event CollateralDeposited(
        ISetToken indexed _setToken,
        IERC20 indexed _collateralToken,
        uint256 indexed _amountDeposited
    );

    /**
     * @dev Emitted on withdraw (not issue or redeem)
     * @param _setToken             Instance of SetToken
     * @param _collateralToken      Token being withdrawn as collateral (USDC)
     * @param _amountWithdrawn      Amount of collateral being withdrawn from Perp
     */
    event CollateralWithdrawn(
        ISetToken indexed _setToken,
        IERC20 indexed _collateralToken,
        uint256 indexed _amountWithdrawn
    );

    /* ============ Constants ============ */

    // String identifying the DebtIssuanceModule in the IntegrationRegistry. Note: Governance must add DefaultIssuanceModule as
    // the string as the integration name
    string constant internal DEFAULT_ISSUANCE_MODULE_NAME = "DefaultIssuanceModule";

    // 0 index stores protocol fee % on the controller, charged in the _executeTrade function
    uint256 constant internal PROTOCOL_TRADE_FEE_INDEX = 0;

    /* ============ State Variables ============ */

    // Token (USDC) used as a vault deposit, Perp currently only supports USDC as it's settlement and collateral token
    IERC20 public immutable collateralToken;

    // Decimals of collateral token. We set this in the constructor for later reading
    uint8 internal immutable collateralDecimals;

    // PerpV2 contract which provides getters for base, quote, and owedRealizedPnl balances
    IAccountBalance public immutable perpAccountBalance;

    // PerpV2 contract which provides a trading API
    IClearingHouse public immutable perpClearingHouse;

    // PerpV2 contract which manages trading logic. Provides getters for UniswapV3 pools and pending funding balances
    IExchange public immutable perpExchange;

    // PerpV2 contract which handles deposits and withdrawals. Provides getter for collateral balances
    IVault public immutable perpVault;

    // PerpV2 contract which makes it possible to simulate a trade before it occurs
    IQuoter public immutable perpQuoter;

    // PerpV2 contract which provides a getter for baseToken UniswapV3 pools
    IMarketRegistry public immutable perpMarketRegistry;

    // PerpV2 operations are very gas intensive and there is a limit on the number of positions that can be opened in a single transaction
    // during issuance/redemption. `maxPerpPositionsPerSet` is a safe limit set by governance taking Optimism's block gas limit into account.
    uint256 public maxPerpPositionsPerSet;

    // Mapping of SetTokens to an array of virtual token addresses the Set has open positions for.
    // Array is updated when new positions are opened or old positions are zeroed out.
    mapping(ISetToken => address[]) internal positions;

    /* ============ Constructor ============ */

    /**
     * @dev Sets external PerpV2 Protocol contract addresses. Sets `collateralToken` and `collateralDecimals`
     * to the Perp vault's settlement token (USDC) and its decimals, respectively.
     *
     * @param _controller               Address of controller contract
     * @param _perpVault                Address of Perp Vault contract
     * @param _perpQuoter               Address of Perp Quoter contract
     * @param _perpMarketRegistry       Address of Perp MarketRegistry contract
     */
    constructor(
        IController _controller,
        IVault _perpVault,
        IQuoter _perpQuoter,
        IMarketRegistry _perpMarketRegistry,
        uint256 _maxPerpPositionsPerSet
    )
        public
        ModuleBase(_controller)
        SetTokenAccessible(_controller)
    {
        // Use temp variables to initialize immutables
        address tempCollateralToken = _perpVault.getSettlementToken();
        collateralToken = IERC20(tempCollateralToken);
        collateralDecimals = ERC20(tempCollateralToken).decimals();

        perpAccountBalance = IAccountBalance(_perpVault.getAccountBalance());
        perpClearingHouse = IClearingHouse(_perpVault.getClearingHouse());
        perpExchange = IExchange(_perpVault.getExchange());
        perpVault = _perpVault;
        perpQuoter = _perpQuoter;
        perpMarketRegistry = _perpMarketRegistry;
        maxPerpPositionsPerSet = _maxPerpPositionsPerSet;
    }

    /* ============ External Functions ============ */

    /**
     * @dev MANAGER ONLY: Initializes this module to the SetToken. Either the SetToken needs to be on the
     * allowed list or anySetAllowed needs to be true.
     *
     * @param _setToken             Instance of the SetToken to initialize
     */
    function initialize(
        ISetToken _setToken
    )
        external
        onlySetManager(_setToken, msg.sender)
        onlyValidAndPendingSet(_setToken)
        onlyAllowedSet(_setToken)
    {
        // Initialize module before trying register
        _setToken.initializeModule();

        // Get debt issuance module registered to this module and require that it is initialized
        require(_setToken.isInitializedModule(
            getAndValidateAdapter(DEFAULT_ISSUANCE_MODULE_NAME)),
            "Issuance not initialized"
        );

        // Try if register exists on any of the modules including the debt issuance module
        address[] memory modules = _setToken.getModules();
        for(uint256 i = 0; i < modules.length; i++) {
            try IDebtIssuanceModule(modules[i]).registerToIssuanceModule(_setToken) {
                // This module registered itself on `modules[i]` issuance module.
            } catch {
                // Try will fail if `modules[i]` is not an instance of IDebtIssuanceModule and does not
                // implement the `registerToIssuanceModule` function, or if the `registerToIssuanceModule`
                // function call reverted. Irrespective of the reason for failure, continue to the next module.
            }
        }
    }

    /**
     * @dev MANAGER ONLY: Allows manager to buy or sell perps to change exposure to the underlying baseToken.
     * Providing a positive value for `_baseQuantityUnits` buys vToken on UniswapV3 via Perp's ClearingHouse,
     * Providing a negative value sells the token. `_quoteBoundQuantityUnits` defines a min-receive-like slippage
     * bound for the amount of vUSDC quote asset the trade will either pay or receive as a result of the action.
     *
     * NOTE: This method doesn't update the externalPositionUnit because it is a function of UniswapV3 virtual
     * token market prices and needs to be generated on the fly to be meaningful.
     *
     * In the tables below, basePositionUnit = baseTokenBalance / setTotalSupply.
     * 
     * As a user when levering, e.g increasing the magnitude of your position, you'd trade as below
     * | ----------------------------------------------------------------------------------------------- |
     * | Type  |  Action | Goal                      | `quoteBoundQuantity`        | `baseQuantityUnits` |
     * | ----- |-------- | ------------------------- | --------------------------- | ------------------- |
     * | Long  | Buy     | pay least amt. of vQuote  | upper bound of input quote  | positive            |
     * | Short | Sell    | get most amt. of vQuote   | lower bound of output quote | negative            |
     * | ----------------------------------------------------------------------------------------------- |
     *
     * As a user when delevering by partially closing your position, you'd trade as below
     * -----------------------------------------------------------------------------------------------------------------------------------
     * | Type  |  Action | Goal                      | `quoteBoundQuantity`        | `baseQuantityUnits`                                 |
     * | ----- |-------- | ------------------------- | --------------------------- | ----------------------------------------------------|
     * | Long  | Sell    | get most amt. of vQuote   | upper bound of input quote  | negative, |baseQuantityUnits| < |basePositionUnit|  |
     * | Short | Buy     | pay least amt. of vQuote  | lower bound of output quote | positive, |baseQuantityUnits| < |basePositionUnit|  |
     * -----------------------------------------------------------------------------------------------------------------------------------
     *
     * As a user when completely closing a position, you'd trade as below
     * -------------------------------------------------------------------------------------------------------------------------------------------
     * | Type  |  Action         | Goal                      | `quoteBoundQuantity`        | `baseQuantityUnits`                                 |
     * | ----- |-----------------| ------------------------- | --------------------------- | ----------------------------------------------------|
     * | Long  | Sell to close   | get most amt. of vQuote   | upper bound of input quote  | negative, baseQuantityUnits = -1 * basePositionUnit |
     * | Short | Buy to close    | pay least amt. of vQuote  | lower bound of output quote | positive, baseQuantityUnits = -1 * basePositionUnit |
     * -------------------------------------------------------------------------------------------------------------------------------------------
     *
     * As a user when reversing a position, e.g going from a long position to a short position in a single trade, you'd trade as below
     * -------------------------------------------------------------------------------------------------------------------------------------------
     * | Type  |  Action         | Goal                      | `quoteBoundQuantity`        | `baseQuantityUnits`                                 |
     * | ----- |-----------------|---------------------------| --------------------------- | ----------------------------------------------------|
     * | Long  | Sell to reverse | get most amt. of vQuote   | upper bound of input quote  | negative, |baseQuantityUnits| > |basePositionUnit|  |
     * | Short | Buy to reverse  | pay least amt. of vQuote  | lower bound of output quote | positive, |baseQuantityUnits| > |basePositionUnit|  |
     * -------------------------------------------------------------------------------------------------------------------------------------------
     *
     * @param _setToken                     Instance of the SetToken
     * @param _baseToken                    Address virtual token being traded
     * @param _baseQuantityUnits            Quantity of virtual token to trade in position units
     * @param _quoteBoundQuantityUnits      Max/min of vQuote asset to pay/receive when buying or selling
     */
    function trade(
        ISetToken _setToken,
        address _baseToken,
        int256 _baseQuantityUnits,
        uint256 _quoteBoundQuantityUnits
    )
        external
        nonReentrant
        onlyManagerAndValidSet(_setToken)
    {
        ActionInfo memory actionInfo = _createAndValidateActionInfo(
            _setToken,
            _baseToken,
            _baseQuantityUnits,
            _quoteBoundQuantityUnits
        );

        (uint256 deltaBase, uint256 deltaQuote) = _executeTrade(actionInfo);

        uint256 protocolFee = _accrueProtocolFee(_setToken, deltaQuote);

        _updatePositionList(_setToken, _baseToken);

        emit PerpTraded(
            _setToken,
            _baseToken,
            deltaBase,
            deltaQuote,
            protocolFee,
            actionInfo.isBuy
        );
    }

    /**
     * @dev MANAGER ONLY: Deposits default position collateral token into the PerpV2 Vault, increasing
     * the size of the Perp account external position. This method is useful for establishing initial
     * collateralization ratios, e.g the flow when setting up a 2X external position would be to deposit
     * 100 units of USDC and execute a lever trade for ~200 vUSDC worth of vToken with the difference
     * between these made up as automatically "issued" margin debt in the PerpV2 system.
     *
     * @param  _setToken                    Instance of the SetToken
     * @param  _collateralQuantityUnits     Quantity of collateral to deposit in position units
     */
    function deposit(
      ISetToken _setToken,
      uint256 _collateralQuantityUnits
    )
      public
      nonReentrant
      onlyManagerAndValidSet(_setToken)
    {
        require(_collateralQuantityUnits > 0, "Deposit amount is 0");

        uint256 notionalDepositedQuantity = _depositAndUpdatePositions(_setToken, _collateralQuantityUnits);

        emit CollateralDeposited(_setToken, collateralToken, notionalDepositedQuantity);
    }

    /**
     * @dev MANAGER ONLY: Withdraws collateral token from the PerpV2 Vault to a default position on
     * the SetToken. This method is useful when adjusting the overall composition of a Set which has
     * a Perp account external position as one of several components.
     *
     * NOTE: Within PerpV2, `withdraw` settles `owedRealizedPnl` and any pending funding payments
     * to the Perp vault prior to transfer.
     *
     * @param  _setToken                    Instance of the SetToken
     * @param  _collateralQuantityUnits     Quantity of collateral to withdraw in position units
     */
    function withdraw(
      ISetToken _setToken,
      uint256 _collateralQuantityUnits
    )
      public
      nonReentrant
      onlyManagerAndValidSet(_setToken)
    {
        require(_collateralQuantityUnits > 0, "Withdraw amount is 0");

        uint256 notionalWithdrawnQuantity = _withdrawAndUpdatePositions(_setToken, _collateralQuantityUnits);

        emit CollateralWithdrawn(_setToken, collateralToken, notionalWithdrawnQuantity);
    }

    /**
     * @dev MANAGER ONLY: Removes this module from the SetToken, via call by the SetToken. Deletes
     * position mappings associated with SetToken.
     *
     * NOTE: Function will revert if there is greater than a position unit amount of USDC of account value.
     */
    function removeModule() external override onlyValidAndInitializedSet(ISetToken(msg.sender)) {
        ISetToken setToken = ISetToken(msg.sender);

        // Check that there is less than 1 position unit of USDC of account value (to tolerate PRECISE_UNIT math rounding errors).
        // Account value is checked here because liquidation may result in a positive vault balance while net value is below zero.
        int256 accountValueUnit = perpClearingHouse.getAccountValue(address(setToken)).preciseDiv(setToken.totalSupply().toInt256());
        require(
            accountValueUnit.fromPreciseUnitToDecimals(collateralDecimals) <= 1,
            "Account balance exists"
        );

        // `positions[setToken]` mapping stores an array of addresses. The base token addresses are removed from the array when the
        // corresponding base token positions are zeroed out. Since no positions exist when removing the module, the stored array should
        // already be empty, and the mapping can be deleted directly.
        delete positions[setToken]; 

        // Try if unregister exists on any of the modules
        address[] memory modules = setToken.getModules();
        for(uint256 i = 0; i < modules.length; i++) {
            try IDebtIssuanceModule(modules[i]).unregisterFromIssuanceModule(setToken) {} catch {}
        }
    }

    /**
     * @dev MANAGER ONLY: Add registration of this module on the debt issuance module for the SetToken.
     *
     * Note: if the debt issuance module is not added to SetToken before this module is initialized, then
     * this function needs to be called if the debt issuance module is later added and initialized to prevent state
     * inconsistencies
     *
     * @param _setToken             Instance of the SetToken
     * @param _debtIssuanceModule   Debt issuance module address to register
     */
    function registerToModule(ISetToken _setToken, IDebtIssuanceModule _debtIssuanceModule) external onlyManagerAndValidSet(_setToken) {
        require(_setToken.isInitializedModule(address(_debtIssuanceModule)), "Issuance not initialized");

        _debtIssuanceModule.registerToIssuanceModule(_setToken);
    }

    /**
     * @dev MODULE ONLY: Hook called prior to issuance. Only callable by valid module. Should only be called ONCE
     * during issue. Trades into current positions and sets the collateralToken's externalPositionUnit so that
     * issuance module can transfer in the right amount of collateral accounting for accrued fees/pnl and slippage
     * incurred during issuance. Any pending funding payments and accrued owedRealizedPnl are attributed to current
     * Set holders.
     *
     * @param _setToken             Instance of the SetToken
     * @param _setTokenQuantity     Quantity of Set to issue
     */
    function moduleIssueHook(
        ISetToken _setToken,
        uint256 _setTokenQuantity
    )
        external
        override
        onlyModule(_setToken)
    {
        if (_setToken.totalSupply() == 0) return;
        if (!_setToken.hasExternalPosition(address(collateralToken))) return;

        int256 newExternalPositionUnit = _executePositionTrades(_setToken, _setTokenQuantity, true, false);

        // Set collateralToken externalPositionUnit such that DIM can use it for transfer calculation
        _setToken.editExternalPositionUnit(
            address(collateralToken),
            address(this),
            newExternalPositionUnit
        );
    }

    /**
     * @dev MODULE ONLY: Hook called prior to redemption in the issuance module. Trades out of existing
     * positions to make redemption capital withdrawable from PerpV2 vault. Sets the `externalPositionUnit`
     * equal to the realizable value of account in position units (as measured by the trade outcomes for
     * this redemption). Any `owedRealizedPnl` and pending funding payments are socialized in this step so
     * that redeemer pays/receives their share of them. Should only be called ONCE during redeem.
     *
     * @param _setToken             Instance of the SetToken
     * @param _setTokenQuantity     Quantity of SetToken to redeem
     */
    function moduleRedeemHook(
        ISetToken _setToken,
        uint256 _setTokenQuantity
    )
        external
        override
        onlyModule(_setToken)
    {
        if (_setToken.totalSupply() == 0) return;
        if (!_setToken.hasExternalPosition(address(collateralToken))) return;

        int256 newExternalPositionUnit = _executePositionTrades(_setToken, _setTokenQuantity, false, false);

        // Set USDC externalPositionUnit such that DIM can use it for transfer calculation
        _setToken.editExternalPositionUnit(
            address(collateralToken),
            address(this),
            newExternalPositionUnit
        );
    }

    /**
     * @dev MODULE ONLY: Hook called prior to looping through each component on issuance. Deposits
     * collateral into Perp protocol from SetToken default position.
     * @param _setToken             Instance of the SetToken
     * @param _setTokenQuantity     Quantity of SetToken to issue
     * @param _component            Address of deposit collateral component
     * @param _isEquity             True if componentHook called from issuance module for equity flow, false otherwise
     */
    function componentIssueHook(
        ISetToken _setToken,
        uint256 _setTokenQuantity,
        IERC20 _component,
        bool _isEquity
    )
        external
        override
        onlyModule(_setToken)
    {
        if (_isEquity) {
            int256 externalPositionUnit = _setToken.getExternalPositionRealUnit(address(_component), address(this));

            // Use preciseMulCeil here to ensure correct collateralization if there are rounding errors.
            uint256 usdcTransferInNotionalQuantity = _setTokenQuantity.preciseMulCeil(externalPositionUnit.toUint256());

            _deposit(_setToken, usdcTransferInNotionalQuantity);
        }
    }

    /**
     * @dev MODULE ONLY: Hook called prior to looping through each component on redemption. Withdraws
     * collateral from Perp protocol to SetToken default position *without* updating the default position unit.
     * Called by issuance module's `resolveEquityPositions` method which immediately transfers the collateral
     * component from SetToken to redeemer after this hook executes.
     *
     * @param _setToken             Instance of the SetToken
     * @param _setTokenQuantity     Quantity of SetToken to redeem
     * @param _component            Address of deposit collateral component
     * @param _isEquity             True if componentHook called from issuance module for equity flow, false otherwise
     */
    function componentRedeemHook(
        ISetToken _setToken,
        uint256 _setTokenQuantity,
        IERC20 _component,
        bool _isEquity
    )
        external
        override
        onlyModule(_setToken)
    {
        if (_isEquity) {
            int256 externalPositionUnit = _setToken.getExternalPositionRealUnit(address(_component), address(this));
            uint256 usdcTransferOutNotionalQuantity = _setTokenQuantity.preciseMul(externalPositionUnit.toUint256());

            _withdraw(_setToken, usdcTransferOutNotionalQuantity);
        }
    }

    /* ============ External Setter Functions ============ */

    /**
     * @dev GOVERNANCE ONLY: Update max perpetual positions per SetToken. Only callable by governance.
     * 
     * @param _maxPerpPositionsPerSet       New max perpetual positons per set
     */
    function updateMaxPerpPositionsPerSet(uint256 _maxPerpPositionsPerSet) external onlyOwner {
        maxPerpPositionsPerSet = _maxPerpPositionsPerSet;
    }

    /* ============ External Getter Functions ============ */

    /**
     * @dev Gets the positive equity collateral externalPositionUnit that would be calculated for
     * issuing a quantity of SetToken, representing the amount of collateral that would need to
     * be transferred in per SetToken. Values in the returned arrays map to the same index in the
     * SetToken's components array
     *
     * @param _setToken             Instance of SetToken
     * @param _setTokenQuantity     Number of sets to issue
     *
     * @return equityAdjustments array containing a single element and an empty debtAdjustments array
     */
    function getIssuanceAdjustments(
        ISetToken _setToken,
        uint256 _setTokenQuantity
    )
        external
        override
        returns (int256[] memory, int256[] memory)
    {
        address[] memory components = _setToken.getComponents();

        if (positions[_setToken].length > 0) {
            int256 newExternalPositionUnit = _executePositionTrades(_setToken, _setTokenQuantity, true, true);
            return _formatAdjustments(_setToken, components, newExternalPositionUnit);
        } else {
            return _formatAdjustments(_setToken, components, 0);
        }
    }

    /**
     * @dev Gets the positive equity collateral externalPositionUnit that would be calculated for
     * redeeming a quantity of SetToken representing the amount of collateral returned per SetToken.
     * Values in the returned arrays map to the same index in the SetToken's components array.
     *
     * @param _setToken             Instance of SetToken
     * @param _setTokenQuantity     Number of sets to issue
     *
     * @return equityAdjustments array containing a single element and an empty debtAdjustments array
     */
    function getRedemptionAdjustments(
        ISetToken _setToken,
        uint256 _setTokenQuantity
    )
        external
        override
        returns (int256[] memory, int256[] memory _)
    {
        address[] memory components = _setToken.getComponents();

        if (positions[_setToken].length > 0) {
            int256 newExternalPositionUnit = _executePositionTrades(_setToken, _setTokenQuantity, false, true);
            return _formatAdjustments(_setToken, components, newExternalPositionUnit);
        } else {
            return _formatAdjustments(_setToken, components, 0);
        }
    }

    /**
     * @dev Returns a PositionUnitNotionalInfo array representing all positions open for the SetToken.
     *
     * @param _setToken         Instance of SetToken
     *
     * @return PositionUnitInfo array, in which each element has properties:
     *
     *         + baseToken: address,
     *         + baseBalance:  baseToken balance as notional quantity (10**18)
     *         + quoteBalance: USDC quote asset balance as notional quantity (10**18)
     */
    function getPositionNotionalInfo(ISetToken _setToken) public view returns (PositionNotionalInfo[] memory) {
        address[] memory positionList = positions[_setToken];
        uint256 positionLength = positionList.length;
        PositionNotionalInfo[] memory positionInfo = new PositionNotionalInfo[](positionLength);

        for(uint i = 0; i < positionLength; i++){
            address baseToken = positionList[i];
            positionInfo[i] = PositionNotionalInfo({
                baseToken: baseToken,
                baseBalance: perpAccountBalance.getBase(
                    address(_setToken),
                    baseToken
                ),
                quoteBalance: perpAccountBalance.getQuote(
                    address(_setToken),
                    baseToken
                )
            });
        }

        return positionInfo;
    }

    /**
     * @dev Returns a PositionUnitInfo array representing all positions open for the SetToken.
     *
     * @param _setToken         Instance of SetToken
     *
     * @return PositionUnitInfo array, in which each element has properties:
     *
     *         + baseToken: address,
     *         + baseUnit:  baseToken balance as position unit (10**18)
     *         + quoteUnit: USDC quote asset balance as position unit (10**18)
     */
    function getPositionUnitInfo(ISetToken _setToken) external view returns (PositionUnitInfo[] memory) {
        int256 totalSupply = _setToken.totalSupply().toInt256();
        PositionNotionalInfo[] memory positionNotionalInfo = getPositionNotionalInfo(_setToken);
        uint256 positionLength = positionNotionalInfo.length;
        PositionUnitInfo[] memory positionUnitInfo = new PositionUnitInfo[](positionLength);

        for(uint i = 0; i < positionLength; i++){
            PositionNotionalInfo memory currentPosition = positionNotionalInfo[i];
            positionUnitInfo[i] = PositionUnitInfo({
                baseToken: currentPosition.baseToken,
                baseUnit: currentPosition.baseBalance.preciseDiv(totalSupply),
                quoteUnit: currentPosition.quoteBalance.preciseDiv(totalSupply)
            });
        }

        return positionUnitInfo;
    }


    /**
     * @dev Gets Perp account info for SetToken. Returns an AccountInfo struct containing account wide
     * (rather than position specific) balance info
     *
     * @param  _setToken            Instance of the SetToken
     *
     * @return accountInfo          struct with properties for:
     *
     *         + collateral balance (10**18, regardless of underlying collateral decimals)
     *         + owed realized Pnl` (10**18)
     *         + pending funding payments (10**18)
     *         + net quote balance (10**18)
     */
    function getAccountInfo(ISetToken _setToken) public view returns (AccountInfo memory accountInfo) {
        (int256 owedRealizedPnl,, ) =  perpAccountBalance.getPnlAndPendingFee(address(_setToken));

        // NOTE: pendingFundingPayments are represented as in the Perp system as "funding owed"
        // e.g a positive number is a debt which gets subtracted from owedRealizedPnl on settlement.
        // We are flipping its sign here to reflect its settlement value.
        accountInfo = AccountInfo({
            collateralBalance: _getCollateralBalance(_setToken),
            owedRealizedPnl: owedRealizedPnl,
            pendingFundingPayments: perpExchange.getAllPendingFundingPayment(address(_setToken)).neg(),
            netQuoteBalance: _getNetQuoteBalance(_setToken)
        });
    }

    /* ============ Internal Functions ============ */

    /**
     * @dev MODULE ONLY: Hook called prior to issuance or redemption. Only callable by valid module.
     * This method implements the core logic to replicate positions during issuance and redemption. Syncs
     * the `positions` list before starting (because positions may have liquidated). Cycles through
     * each position, trading `basePositionUnit * issueOrRedeemQuantity` and calculates the amount of
     * USDC to transfer in/out for exchange, ensuring that issuer/redeemer pays slippage and that any
     * pending payments like funding or owedRealizedPnl are socialized among existing Set holders
     * appropriately. The hook which invokes this method sets the SetToken's externalPositionUnit using
     * the positionUnit value returned here. Subsequent transfers in/out are managed by the issuance module
     * which reads this value.
     *
     * The general formula for determining `accountValue` per Set is:
     *
     * `accountValue = collateral                                <---
     *               + owedRealizedPnl                               }   totalCollateralValue
     *               + pendingFundingPayment                     <---
     *               + netQuoteBalance                           neg. when long, pos. when short
     *               +/- sum( |deltaQuoteResultingFromTrade| )   add when long, subtract when short
     *
     * (See docs for `_calculatePartialAccountValuePositionUnit` below for more detail about the
     * account value components).
     *
     * NOTE: On issuance, this hook is run *BEFORE* USDC is transferred in and deposited to the Perp
     * vault to pay for the issuer's Sets. This trading temporarily spikes the Perp account's
     * margin ratio (capped at ~9X) and limits the amount of Set that can issued at once to
     * a multiple of the current Perp account value (will vary depending on Set's leverage ratio).
     *
     * @param _setToken             Instance of the SetToken
     * @param _setTokenQuantity     Quantity of Set to issue
     * @param _isIssue              If true, invocation is for issuance, redemption otherwise
     * @param _isSimulation         If true, trading is only simulated (to return issuance adjustments)
     * @return int256               Amount of collateral to transfer in/out in position units
     */
    function _executePositionTrades(
        ISetToken _setToken,
        uint256 _setTokenQuantity,
        bool _isIssue,
        bool _isSimulation
    )
        internal
        returns (int256)
    {
        _syncPositionList(_setToken);
        int256 setTokenQuantityInt = _setTokenQuantity.toInt256();

        // Note: `issued` naming convention used here for brevity. This logic is also run on redemption
        // and variable may refer to the value which will be redeemed.
        int256 accountValueIssued = _calculatePartialAccountValuePositionUnit(_setToken).preciseMul(setTokenQuantityInt);

        PositionNotionalInfo[] memory positionInfo = getPositionNotionalInfo(_setToken);
        uint256 positionLength = positionInfo.length;
        int256 totalSupply = _setToken.totalSupply().toInt256();

        for(uint i = 0; i < positionLength; i++) {
            int256 baseTradeNotionalQuantity = positionInfo[i].baseBalance.preciseDiv(totalSupply).preciseMul(setTokenQuantityInt);

            // When redeeming, we flip the sign of baseTradeNotionalQuantity because we are reducing the size of the position,
            // e.g selling base when long, buying base when short
            ActionInfo memory actionInfo = _createActionInfoNotional(
                _setToken,
                positionInfo[i].baseToken,
                _isIssue ? baseTradeNotionalQuantity : baseTradeNotionalQuantity.neg(),
                0
            );

            // Execute or simulate trade.
            // `deltaQuote` is always a positive number
            (, uint256 deltaQuote) = _isSimulation ? _simulateTrade(actionInfo) : _executeTrade(actionInfo);

            // slippage is borne by the issuer
            accountValueIssued = baseTradeNotionalQuantity >= 0 ? accountValueIssued.add(deltaQuote.toInt256()) :
                accountValueIssued.sub(deltaQuote.toInt256());
        }

        // After trading, verify that accountValueIssued is not negative. In some post-liquidation states the
        // account could be bankrupt and we represent that as zero.
        if (accountValueIssued <= 0) {
            return 0;
        }

        // Return value in collateral decimals (e.g USDC = 6)
        // Use preciseDivCeil when issuing to ensure we don't under-collateralize due to rounding error
        return (_isIssue)
            ? accountValueIssued.preciseDivCeil(setTokenQuantityInt).fromPreciseUnitToDecimals(collateralDecimals)
            : accountValueIssued.preciseDiv(setTokenQuantityInt).fromPreciseUnitToDecimals(collateralDecimals);
    }

    /**
     * Calculates the "partial account value" position unit. This is the sum of the vault collateral balance,
     * the net quote balance for all positions, and any pending funding or owed realized Pnl balances,
     * as a position unit. It forms the base to which traded position values are added during issuance or redemption,
     * and to which existing position values are added when calculating the externalPositionUnit.
     *
     * @param _setToken             Instance of the SetToken
     * @return accountValue         Partial account value in position units
     */
    function _calculatePartialAccountValuePositionUnit(ISetToken _setToken) internal view returns (int256 accountValue) {
        AccountInfo memory accountInfo = getAccountInfo(_setToken);

        accountValue = accountInfo.collateralBalance
            .add(accountInfo.owedRealizedPnl)
            .add(accountInfo.pendingFundingPayments)
            .add(accountInfo.netQuoteBalance)
            .preciseDiv(_setToken.totalSupply().toInt256());
    }

    /**
     * @dev Invoke deposit from SetToken using PerpV2 library. Creates a collateral deposit in Perp vault
     * Updates the collateral token default position unit. This function is called directly by
     * the componentIssue hook, skipping external position unit setting because that method is assumed
     * to be the end of a call sequence (e.g manager will not need to read the updated value)
     *
     * @param _setToken                     Instance of SetToken
     * @param _collateralNotionalQuantity   Notional collateral quantity to deposit
     */
    function _deposit(ISetToken _setToken, uint256 _collateralNotionalQuantity) internal {
        _setToken.invokeApprove(
            address(collateralToken),
            address(perpVault),
            _collateralNotionalQuantity
        );

        _setToken.invokeDeposit(perpVault, collateralToken, _collateralNotionalQuantity);
    }

    /**
     * Approves and deposits collateral units into Perp vault and additionally sets collateral token externalPositionUnit
     * so Manager contracts have a value they can base calculations for further trading on within the same transaction.
     *
     * NOTE: This flow is only used when invoking the external `deposit` function - it converts collateral
     * quantity units into a notional quantity.
     *
     * @param _setToken                     Instance of SetToken
     * @param _collateralQuantityUnits      Collateral quantity in position units to deposit
     * @return uint256                      Notional quantity deposited
     */
    function _depositAndUpdatePositions(
        ISetToken _setToken,
        uint256 _collateralQuantityUnits
    )
        internal
        returns (uint256)
    {
        uint256 initialCollateralPositionBalance = collateralToken.balanceOf(address(_setToken));
        uint256 collateralNotionalQuantity = _collateralQuantityUnits.preciseMul(_setToken.totalSupply());

        _deposit(_setToken, collateralNotionalQuantity);

        _setToken.calculateAndEditDefaultPosition(
            address(collateralToken),
            _setToken.totalSupply(),
            initialCollateralPositionBalance
        );

        _setToken.editExternalPosition(
            address(collateralToken),
            address(this),
            _calculateExternalPositionUnit(_setToken),
            ""
        );

        return collateralNotionalQuantity;
    }

    /**
     * @dev Invoke withdraw from SetToken using PerpV2 library. Withdraws collateral token from Perp vault
     * into a default position. This function is called directly by _accrueFee and _moduleRedeemHook,
     * skipping position unit state updates because the funds withdrawn to SetToken are immediately
     * forwarded to `feeRecipient` and SetToken owner respectively.
     *
     * @param _setToken                     Instance of SetToken
     * @param _collateralNotionalQuantity   Notional collateral quantity to withdraw
     */
    function _withdraw(ISetToken _setToken, uint256 _collateralNotionalQuantity) internal {
        if (_collateralNotionalQuantity == 0) return;

        _setToken.invokeWithdraw(perpVault, collateralToken, _collateralNotionalQuantity);
    }

    /**
     * Withdraws collateral units from Perp vault to SetToken and additionally sets both the collateralToken
     * externalPositionUnit (so Manager contracts have a value they can base calculations for further
     * trading on within the same transaction), and the collateral token default position unit.
     *
     * NOTE: This flow is only used when invoking the external `withdraw` function - it converts
     * a collateral units quantity into a notional quantity before invoking withdraw.
     *
     * @param _setToken                     Instance of SetToken
     * @param _collateralQuantityUnits      Collateral quantity in position units to withdraw
     * @return uint256                      Notional quantity withdrawn
     */
    function _withdrawAndUpdatePositions(
        ISetToken _setToken,
        uint256 _collateralQuantityUnits

    )
        internal
        returns (uint256)
    {
        uint256 initialCollateralPositionBalance = collateralToken.balanceOf(address(_setToken));
        uint256 collateralNotionalQuantity = _collateralQuantityUnits.preciseMul(_setToken.totalSupply());

        _withdraw(_setToken, collateralNotionalQuantity);

        _setToken.calculateAndEditDefaultPosition(
            address(collateralToken),
            _setToken.totalSupply(),
            initialCollateralPositionBalance
        );

        _setToken.editExternalPosition(
            address(collateralToken),
            address(this),
            _calculateExternalPositionUnit(_setToken),
            ""
        );

        return collateralNotionalQuantity;
    }

    /**
     * @dev Formats Perp Protocol openPosition call and executes via SetToken (and PerpV2 lib)
     *
     * `isBaseToQuote`, `isExactInput` and `oppositeAmountBound` are configured as below:
     * | ---------------------------------------------------|---------------------------- |
     * | Action  | isBuy   | isB2Q  | Exact In / Out        | Opposite Bound Description  |
     * | ------- |-------- |--------|-----------------------|---------------------------- |
     * | Buy     |  true   | false  | exact output (false)  | Max quote to pay            |
     * | Sell    |  false  | true   | exact input (true)    | Min quote to receive        |
     * |----------------------------------------------------|---------------------------- |
     *
     * @param _actionInfo  ActionInfo object
     * @return uint256     The base position delta resulting from the trade
     * @return uint256     The quote asset position delta resulting from the trade
     */
    function _executeTrade(ActionInfo memory _actionInfo) internal returns (uint256, uint256) {

        // When isBaseToQuote is true, `baseToken` is being sold, when false, bought
        // When isExactInput is true, `amount` is the swap input, when false, the swap output
        IClearingHouse.OpenPositionParams memory params = IClearingHouse.OpenPositionParams({
            baseToken: _actionInfo.baseToken,
            isBaseToQuote: !_actionInfo.isBuy,
            isExactInput: !_actionInfo.isBuy,
            amount: _actionInfo.baseTokenAmount,
            oppositeAmountBound: _actionInfo.oppositeAmountBound,
            deadline: PreciseUnitMath.maxUint256(),
            sqrtPriceLimitX96: 0,
            referralCode: bytes32(0)
        });

        return _actionInfo.setToken.invokeOpenPosition(perpClearingHouse, params);
    }


    /**
     * @dev Formats Perp Periphery Quoter.swap call and executes via SetToken (and PerpV2 lib)
     *
     * See _executeTrade method comments for details about `isBaseToQuote` and `isExactInput` configuration.
     *
     * @param _actionInfo   ActionInfo object
     * @return uint256      The base position delta resulting from the trade
     * @return uint256      The quote asset position delta resulting from the trade
     */
    function _simulateTrade(ActionInfo memory _actionInfo) internal returns (uint256, uint256) {
        IQuoter.SwapParams memory params = IQuoter.SwapParams({
            baseToken: _actionInfo.baseToken,
            isBaseToQuote: !_actionInfo.isBuy,
            isExactInput: !_actionInfo.isBuy,
            amount: _actionInfo.baseTokenAmount,
            sqrtPriceLimitX96: 0
        });

        IQuoter.SwapResponse memory swapResponse = _actionInfo.setToken.invokeSwap(perpQuoter, params);
        return (swapResponse.deltaAvailableBase, swapResponse.deltaAvailableQuote);
    }

    /**
     * @dev Calculates protocol fee on module and pays protocol fee from SetToken
     *
     * @param  _setToken            Instance of SetToken
     * @param  _exchangedQuantity   Notional quantity of USDC exchanged in trade (e.g deltaQuote)
     * @return uint256              Total protocol fee paid in underlying collateral decimals e.g (USDC = 6)
     */
    function _accrueProtocolFee(
        ISetToken _setToken,
        uint256 _exchangedQuantity
    )
        internal
        returns(uint256)
    {
        uint256 protocolFee = getModuleFee(PROTOCOL_TRADE_FEE_INDEX, _exchangedQuantity);
        uint256 protocolFeeInPreciseUnits = protocolFee.fromPreciseUnitToDecimals(collateralDecimals);

        _withdraw(_setToken, protocolFeeInPreciseUnits);

        payProtocolFeeFromSetToken(_setToken, address(collateralToken), protocolFeeInPreciseUnits);

        return protocolFeeInPreciseUnits;
    }

    /**
     * @dev Construct the ActionInfo struct for trading. This method takes POSITION UNIT amounts and passes to
     *  _createActionInfoNotional to create the struct. If the _baseTokenQuantity is zero then revert. If
     * the _baseTokenQuantity = -(baseBalance/setSupply) then close the position entirely. This method is
     * only called from `trade` - the issue/redeem flow uses createActionInfoNotional directly.
     *
     * @param _setToken             Instance of the SetToken
     * @param _baseToken            Address of base token being traded into/out of
     * @param _baseQuantityUnits    Quantity of baseToken to trade in PositionUnits
     * @param _quoteReceiveUnits    Quantity of quote to receive if selling base and pay if buying, in PositionUnits
     *
     * @return ActionInfo           Instance of constructed ActionInfo struct
     */
    function _createAndValidateActionInfo(
        ISetToken _setToken,
        address _baseToken,
        int256 _baseQuantityUnits,
        uint256 _quoteReceiveUnits
    )
        internal
        view
        returns(ActionInfo memory)
    {
        require(_baseQuantityUnits != 0, "Amount is 0");
        require(perpMarketRegistry.hasPool(_baseToken), "Base token does not exist");

        uint256 totalSupply = _setToken.totalSupply();

        int256 baseBalance = perpAccountBalance.getBase(address(_setToken), _baseToken);
        int256 basePositionUnit = baseBalance.preciseDiv(totalSupply.toInt256());
        
        int256 baseNotional = _baseQuantityUnits == basePositionUnit.neg() 
            ? baseBalance.neg()         // To close position completely
            : _baseQuantityUnits.preciseMul(totalSupply.toInt256());

        return _createActionInfoNotional(
            _setToken,
            _baseToken,
            baseNotional,
            _quoteReceiveUnits.preciseMul(totalSupply)
        );
    }

    /**
     * @dev Construct the ActionInfo struct for trading. This method takes NOTIONAL token amounts and creates
     * the struct. If the _baseTokenQuantity is greater than zero then we are buying the baseToken. This method
     * is called during issue and redeem via `_executePositionTrades` and during trade via `_createAndValidateActionInfo`.
     *
     * (See _executeTrade method comments for details about `oppositeAmountBound` configuration)
     *
     * @param _setToken                 Instance of the SetToken
     * @param _baseToken                Address of base token being traded into/out of
     * @param _baseTokenQuantity        Notional quantity of baseToken to trade
     * @param _quoteReceiveQuantity     Notional quantity of quote to receive if selling base and pay if buying
     *
     * @return ActionInfo               Instance of constructed ActionInfo struct
     */
    function _createActionInfoNotional(
        ISetToken _setToken,
        address _baseToken,
        int256 _baseTokenQuantity,
        uint256 _quoteReceiveQuantity
    )
        internal
        pure
        returns(ActionInfo memory)
    {
        // NOT checking that _baseTokenQuantity != 0 here because for places this is directly called
        // (issue/redeem hooks) we know the position cannot be 0. We check in _createAndValidateActionInfo
        // that quantity is 0 for inputs to trade.
        bool isBuy = _baseTokenQuantity > 0;

        return ActionInfo({
            setToken: _setToken,
            baseToken: _baseToken,
            isBuy: isBuy,
            baseTokenAmount: _baseTokenQuantity.abs(),
            oppositeAmountBound: _quoteReceiveQuantity
        });
    }

    /**
     * @dev Update position address array if a token has been newly added or completely sold off
     * during lever/delever
     *
     * @param _setToken     Instance of SetToken
     * @param _baseToken    Address of virtual base token
     */
    function _updatePositionList(ISetToken _setToken, address _baseToken) internal {
        address[] memory positionList = positions[_setToken];
        bool hasBaseToken = positionList.contains(_baseToken);

        if (hasBaseToken) {
            if(!_hasBaseBalance(_setToken, _baseToken)) {
                positions[_setToken].removeStorage(_baseToken);
            }
        } else {
            require(positions[_setToken].length < maxPerpPositionsPerSet, "Exceeds max perpetual positions per set");
            positions[_setToken].push(_baseToken);
        }
    }

    /**
     * @dev Removes any zero balance positions from the positions array. This
     * sync is done before issuance and redemption to account for positions that may have
     * been liquidated.
     *
     * @param _setToken         Instance of the SetToken
     */
    function _syncPositionList(ISetToken _setToken) internal {
        address[] memory positionList = positions[_setToken];
        uint256 positionLength = positionList.length;
        
        for (uint256 i = 0; i < positionLength; i++) {
            address currPosition = positionList[i];
            if (!_hasBaseBalance(_setToken, currPosition)) {
                positions[_setToken].removeStorage(currPosition);
            }
        }
    }

    /**
     * @dev Checks to see if we can make 1 positionUnit worth of a baseToken position, if not we consider the Set to have
     * no balance and return false
     *
     * @param _setToken     Instance of SetToken
     * @param _baseToken    Address of virtual base token
     * @return bool         True if a non-dust base token balance exists, false otherwise
     */
    function _hasBaseBalance(ISetToken _setToken, address _baseToken) internal view returns(bool) {
        int256 baseBalanceUnit = perpAccountBalance
            .getBase(address(_setToken), _baseToken)
            .preciseDiv(_setToken.totalSupply().toInt256());

        return (baseBalanceUnit > 1) || (baseBalanceUnit < -1);
    }

    /**
     * @dev Gets the mid-point price of a virtual asset from UniswapV3 markets maintained by Perp Protocol
     *
     * @param  _baseToken           Address of virtual token to price
     * @return price                Mid-point price of virtual token in UniswapV3 AMM market
     */
    function _calculateAMMSpotPrice(address _baseToken) internal view returns (uint256 price) {
        address pool = perpMarketRegistry.getPool(_baseToken);
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
        uint256 priceX96 = sqrtPriceX96.formatSqrtPriceX96ToPriceX96();
        return priceX96.formatX96ToX10_18();
    }

    /**
     * @dev Calculates the sum of collateralToken denominated market-prices of assets and debt for the Perp account per
     * SetToken
     *
     * @param _setToken     Instance of SetToken
     * @return int256       External position unit
     */
    function _calculateExternalPositionUnit(ISetToken _setToken) internal view returns (int256) {
        PositionNotionalInfo[] memory positionInfo = getPositionNotionalInfo(_setToken);
        uint256 positionLength = positionInfo.length;
        int256 totalPositionValue = 0;

        for (uint i = 0; i < positionLength; i++ ) {
            int256 spotPrice = _calculateAMMSpotPrice(positionInfo[i].baseToken).toInt256();
            totalPositionValue = totalPositionValue.add(
                positionInfo[i].baseBalance.preciseMul(spotPrice)
            );
        }

        int256 externalPositionUnitInPreciseUnits = _calculatePartialAccountValuePositionUnit(_setToken)
            .add(totalPositionValue.preciseDiv(_setToken.totalSupply().toInt256()));

        return externalPositionUnitInPreciseUnits.fromPreciseUnitToDecimals(collateralDecimals);
    }

    /**
     * @dev Retrieves collateral balance as an 18 decimal vUSDC quote value
     *
     * @param _setToken     Instance of SetToken
     * @return int256       Collateral balance as an 18 decimal vUSDC quote value
     */
    function _getCollateralBalance(ISetToken _setToken) internal view returns (int256) {
        return perpVault.getBalance(address(_setToken)).toPreciseUnitsFromDecimals(collateralDecimals);
    }

    /**
     * @dev Retrieves net quote balance of all open positions
     *
     * @param _setToken             Instance of SetToken
     * @return netQuoteBalance      Net quote balance of all open positions
     */
    function _getNetQuoteBalance(ISetToken _setToken) internal view returns (int256 netQuoteBalance) {
        address[] memory positionList = positions[_setToken];
        uint256 positionLength = positionList.length;

        for (uint256 i = 0; i < positionLength; i++) {
            netQuoteBalance = netQuoteBalance.add(
                perpAccountBalance.getQuote(address(_setToken), positionList[i])
            );
        }
    }

    /**
     * @dev Returns issuance or redemption adjustments in the format expected by `SlippageIssuanceModule`.
     * The last recorded externalPositionUnit (current) is subtracted from a dynamically generated
     * externalPositionUnit (new) and set in an `equityAdjustments` array which is the same length as
     * the SetToken's components array, at the same index the collateral token occupies in the components
     * array. All other values are left unset (0). An empty-value components length debtAdjustments
     * array is also returned.
     *
     * @param _setToken                         Instance of the SetToken
     * @param _components                       Array of components held by the SetToken
     * @param _newExternalPositionUnit          Dynamically calculated externalPositionUnit
     * @return int256[]                         Components-length array with equity adjustment value at appropriate index
     * @return int256[]                         Components-length array of zeroes (debt adjustements)
     */
    function _formatAdjustments(
        ISetToken _setToken,
        address[] memory _components,
        int256 _newExternalPositionUnit
    )
        internal
        view
        returns (int256[] memory, int256[] memory)
    {
        int256[] memory equityAdjustments = new int256[](_components.length);
        int256[] memory debtAdjustments = new int256[](_components.length);

        (uint256 index, bool isIn) = _components.indexOf(address(collateralToken));

        if (isIn) {
            int256 currentExternalPositionUnit = _setToken.getExternalPositionRealUnit(
                address(collateralToken),
                address(this)
            );

            equityAdjustments[index] = _newExternalPositionUnit.sub(currentExternalPositionUnit);
        }

        return (equityAdjustments, debtAdjustments);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @title SignedSafeMath
 * @dev Signed math operations with safety checks that revert on error.
 */
library SignedSafeMath {
    int256 constant private _INT256_MIN = -2**255;

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
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == _INT256_MIN), "SignedSafeMath: multiplication overflow");

        int256 c = a * b;
        require(c / a == b, "SignedSafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two signed integers. Reverts on
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
    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != 0, "SignedSafeMath: division by zero");
        require(!(b == -1 && a == _INT256_MIN), "SignedSafeMath: division overflow");

        int256 c = a / b;

        return c;
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
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), "SignedSafeMath: subtraction overflow");

        return c;
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
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), "SignedSafeMath: addition overflow");

        return c;
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

import "../../GSN/Context.sol";
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
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
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
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
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
    function _setupDecimals(uint8 decimals_) internal {
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

import "../GSN/Context.sol";
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
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
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

/*
    Copyright 2021 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IClearingHouse } from "../../../interfaces/external/perp-v2/IClearingHouse.sol";
import { IVault } from "../../../interfaces/external/perp-v2/IVault.sol";
import { IQuoter } from "../../../interfaces/external/perp-v2/IQuoter.sol";
import { ISetToken } from "../../../interfaces/ISetToken.sol";

/**
 * @title PerpV2
 * @author Set Protocol
 *
 * Collection of helper functions for interacting with PerpV2 integrations.
 */
library PerpV2 {

    /* ============ External ============ */

    /**
     * Gets Perp vault `deposit` calldata
     *
     * When invoked, calldata deposits an `_amountNotional` of collateral asset into the Perp Protocol vault
     *
     * @param  _vault               Perp protocol vault
     * @param  _asset               Collateral asset to deposit
     * @param  _amountNotional      Notional amount in collateral decimals to deposit
     *
     * @return address              Vault address
     * @return uint256              Call value
     * @return calldata             Deposit calldata
     */
    function getDepositCalldata(
        IVault _vault,
        IERC20 _asset,
        uint256 _amountNotional
    )
        public
        pure
        returns (address, uint256, bytes memory)
    {
        bytes memory callData = abi.encodeWithSignature(
            "deposit(address,uint256)",
            _asset,
            _amountNotional
        );

        return (address(_vault), 0, callData);
    }

    /**
     * Invoke `deposit` on Vault from SetToken
     *
     * Deposits an `_amountNotional` of collateral asset into the Perp Protocol vault
     *
     * @param _setToken             Address of the SetToken
     * @param _vault                Address of Perp Protocol vault contract
     * @param _asset                The address of the collateral asset to deposit
     * @param _amountNotional       Notional amount in collateral decimals to deposit
     */
    function invokeDeposit(
        ISetToken _setToken,
        IVault _vault,
        IERC20 _asset,
        uint256 _amountNotional
    )
        external
    {
        ( , , bytes memory depositCalldata) = getDepositCalldata(
            _vault,
            _asset,
            _amountNotional
        );

        _setToken.invoke(address(_vault), 0, depositCalldata);
    }

    /**
     * Get Perp Vault `withdraw` method calldata
     *
     * When invoked, calldata withdraws an `_amountNotional` of collateral asset from the Perp protocol vault
     *
     * @param _vault                Address of the Perp Protocol vault contract
     * @param _asset                The address of the collateral asset to withdraw
     * @param _amountNotional       The notional amount in collateral decimals to be withdrawn
     *
     * @return address              Vault contract address
     * @return uint256              Call value
     * @return bytes                Withdraw calldata
     */
    function getWithdrawCalldata(
        IVault _vault,
        IERC20 _asset,
        uint256 _amountNotional
    )
        public
        pure
        returns (address, uint256, bytes memory)
    {
        bytes memory callData = abi.encodeWithSignature(
            "withdraw(address,uint256)",
            _asset,
            _amountNotional
        );

        return (address(_vault), 0, callData);
    }

    /**
     * Invoke `withdraw` on Vault from SetToken
     *
     * Withdraws an `_amountNotional` of collateral asset from the Perp protocol vault
     *
     * @param _setToken         Address of the SetToken
     * @param _vault            Address of the Perp Protocol vault contract
     * @param _asset            The address of the collateral asset to withdraw
     * @param _amountNotional   The notional amount in collateral decimals to be withdrawn     *
     */
    function invokeWithdraw(
        ISetToken _setToken,
        IVault _vault,
        IERC20 _asset,
        uint256 _amountNotional
    )
        external
    {
        ( , , bytes memory withdrawCalldata) = getWithdrawCalldata(
            _vault,
            _asset,
            _amountNotional
        );

        _setToken.invoke(address(_vault), 0, withdrawCalldata);
    }

    /**
     * Get Perp ClearingHouse `openPosition` method calldata
     *
     * When invoked, calldata executes a trade via the Perp protocol ClearingHouse contract
     *
     * @param _clearingHouse        Address of the Clearinghouse contract
     * @param _params               OpenPositionParams struct. For details see definition
     *                              in contracts/interfaces/external/perp-v2/IClearingHouse.sol
     *
     * @return address              ClearingHouse contract address
     * @return uint256              Call value
     * @return bytes                `openPosition` calldata
     */
    function getOpenPositionCalldata(
        IClearingHouse _clearingHouse,
        IClearingHouse.OpenPositionParams memory _params
    )
        public
        pure
        returns (address, uint256, bytes memory)
    {
        bytes memory callData = abi.encodeWithSignature(
            "openPosition((address,bool,bool,uint256,uint256,uint256,uint160,bytes32))",
            _params
        );

        return (address(_clearingHouse), 0, callData);
    }

    /**
     * Invoke `openPosition` on ClearingHouse from SetToken
     *
     * Executes a trade via the Perp protocol ClearingHouse contract
     *
     * @param _setToken             Address of the SetToken
     * @param _clearingHouse        Address of the Clearinghouse contract
     * @param _params               OpenPositionParams struct. For details see definition
     *                              in contracts/interfaces/external/perp-v2/IClearingHouse.sol
     *
     * @return deltaBase            Positive or negative change in base token balance resulting from trade
     * @return deltaQuote           Positive or negative change in quote token balance resulting from trade
     */
    function invokeOpenPosition(
        ISetToken _setToken,
        IClearingHouse _clearingHouse,
        IClearingHouse.OpenPositionParams memory _params
    )
        external
        returns (uint256 deltaBase, uint256 deltaQuote)
    {
        ( , , bytes memory openPositionCalldata) = getOpenPositionCalldata(
            _clearingHouse,
            _params
        );

        bytes memory returnValue = _setToken.invoke(address(_clearingHouse), 0, openPositionCalldata);
        return abi.decode(returnValue, (uint256,uint256));
    }

    /**
     * Get Perp Quoter `swap` method calldata
     *
     * When invoked, calldata simulates a trade on the Perp exchange via the Perp periphery contract Quoter
     *
     * @param _quoter               Address of the Quoter contract
     * @param _params               SwapParams struct. For details see definition
     *                              in contracts/interfaces/external/perp-v2/IQuoter.sol
     *
     * @return address              ClearingHouse contract address
     * @return uint256              Call value
     * @return bytes                `swap` calldata
     */
    function getSwapCalldata(
        IQuoter _quoter,
        IQuoter.SwapParams memory _params
    )
        public
        pure
        returns (address, uint256, bytes memory)
    {
        bytes memory callData = abi.encodeWithSignature(
            "swap((address,bool,bool,uint256,uint160))",
            _params
        );

        return (address(_quoter), 0, callData);
    }

    /**
     * Invoke `swap` method on Perp Quoter contract
     *
     * Simulates a trade on the Perp exchange via the Perp periphery contract Quoter
     *
     * @param _setToken             Address of the SetToken
     * @param _quoter               Address of the Quoter contract
     * @param _params               SwapParams struct. For details see definition
     *                              in contracts/interfaces/external/perp-v2/IQuoter.sol
     *
     * @return swapResponse         Struct which includes deltaAvailableBase and deltaAvailableQuote
     *                              properties (equiv. to deltaQuote, deltaBase) returned from `openPostion`
     */
    function invokeSwap(
        ISetToken _setToken,
        IQuoter _quoter,
        IQuoter.SwapParams memory _params
    )
        external
        returns (IQuoter.SwapResponse memory)
    {
        ( , , bytes memory swapCalldata) = getSwapCalldata(
            _quoter,
            _params
        );

        bytes memory returnValue = _setToken.invoke(address(_quoter), 0, swapCalldata);
        return abi.decode(returnValue, (IQuoter.SwapResponse));
    }
}

/*
    Copyright 2021 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";

import { PreciseUnitMath } from "../../../lib/PreciseUnitMath.sol";

/**
 * @title UniswapV3Math
 * @author Set Protocol
 *
 * Helper functions for managing UniswapV3 math.
 */
library UniswapV3Math {

    /**
     * @dev Converts a UniswapV3 sqrtPriceX96 value to a priceX96 value. This method is borrowed from
     * PerpProtocol's `lushan` repo, in lib/PerpMath.
     *
     * For more info about the sqrtPriceX96 format see:
     * https://docs.uniswap.org/sdk/guides/fetching-prices#understanding-sqrtprice
     *
     * @param _sqrtPriceX96     Square root of a UniswapV3 encoded fixed-point pool price.
     * @return                  _sqrtPriceX96 converted to a priceX96 value
     */
    function formatSqrtPriceX96ToPriceX96(uint160 _sqrtPriceX96) internal pure returns (uint256) {
        return FullMath.mulDiv(_sqrtPriceX96, _sqrtPriceX96, FixedPoint96.Q96);
    }

    /**
     * @dev Converts a UniswapV3 X96 format price into a PRECISE_UNIT price. This method is borrowed from
     * PerpProtocol's `lushan` repo, in lib/PerpMath
     *
     * For more info about the priceX96 format see:
     * https://docs.uniswap.org/sdk/guides/fetching-prices#understanding-sqrtprice
     *
     * @param _valueX96         UniswapV3 encoded fixed-point pool price
     * @return                  _priceX96 as a PRECISE_UNIT value
     */
    function formatX96ToX10_18(uint256 _valueX96) internal pure returns (uint256) {
        return FullMath.mulDiv(_valueX96, PreciseUnitMath.preciseUnit(), FixedPoint96.Q96);
    }
}

/*
  Copyright 2021 Set Labs Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

interface IAccountBalance {
    function getBaseTokens(address trader) external view returns (address[] memory);
    function hasOrder(address trader) external view returns (bool);
    function getMarginRequirementForLiquidation(address trader) external view returns (int256);
    function getTotalDebtValue(address trader) external view returns (uint256);
    function getPnlAndPendingFee(address trader) external view returns (int256,int256,uint256);
    function getBase(address trader, address baseToken) external view returns (int256);
    function getQuote(address trader, address baseToken) external view returns (int256);
    function getNetQuoteBalanceAndPendingFee(address trader) external view returns (int256, uint256);
    function getPositionSize(address trader, address baseToken) external view returns (int256);
    function getPositionValue(address trader, address baseToken) external view returns (int256);
    function getTotalAbsPositionValue(address trader) external view returns (uint256);
    function getClearingHouseConfig() external view returns (address);
    function getExchange() external view returns (address);
    function getOrderBook() external view returns (address);
    function getVault() external view returns (address);
}

/*
  Copyright 2021 Set Labs Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

interface IClearingHouse {
    struct OpenPositionParams {
        address baseToken;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        // B2Q + exact input, want more output quote as possible, so we set a lower bound of output quote
        // B2Q + exact output, want less input base as possible, so we set a upper bound of input base
        // Q2B + exact input, want more output base as possible, so we set a lower bound of output base
        // Q2B + exact output, want less input quote as possible, so we set a upper bound of input quote
        // when it's 0 in exactInput, means ignore slippage protection
        // when it's maxUint in exactOutput = ignore
        // when it's over or under the bound, it will be reverted
        uint256 oppositeAmountBound;
        uint256 deadline;
        // B2Q: the price cannot be less than this value after the swap
        // Q2B: The price cannot be greater than this value after the swap
        // it will fill the trade until it reach the price limit instead of reverted
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

    function openPosition(OpenPositionParams memory params)
        external
        returns (uint256 deltaBase, uint256 deltaQuote);

    function closePosition(ClosePositionParams calldata params)
        external
        returns (uint256 deltaBase, uint256 deltaQuote);

    function getAccountValue(address trader) external view returns (int256);
    function getPositionSize(address trader, address baseToken) external view returns (int256);
    function getPositionValue(address trader, address baseToken) external view returns (int256);
    function getOpenNotional(address trader, address baseToken) external view returns (int256);
    function getOwedRealizedPnl(address trader) external view returns (int256);
    function getTotalInitialMarginRequirement(address trader) external view returns (uint256);
    function getNetQuoteBalance(address trader) external view returns (int256);
    function getTotalUnrealizedPnl(address trader) external view returns (int256);
}

/*
  Copyright 2022 Set Labs Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

interface IClearingHouseConfig {
    function getImRatio() external view returns (uint24 imRatio);
}

/*
  Copyright 2021 Set Labs Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

interface IExchange {
    struct FundingGrowth {
        int256 twPremiumX96;
        int256 twPremiumDivBySqrtPriceX96;
    }

    struct SwapParams {
        address trader;
        address baseToken;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint160 sqrtPriceLimitX96;
        FundingGrowth fundingGrowthGlobal;
    }

    struct SwapResponse {
        uint256 deltaAvailableBase;
        uint256 deltaAvailableQuote;
        int256 exchangedPositionSize;
        int256 exchangedPositionNotional;
        uint256 fee;
        uint256 insuranceFundFee;
        int24 tick;
        int256 realizedPnl;
        int256 openNotional;
    }

    // Note: Do *NOT* add `getFundingGrowthGlobalAndTwaps` to this interface. It may work with the
    // custom bytecode we generated to expose the method in our TS tests but it's no longer part of the
    // public interface of the deployed PerpV2 system contracts. (Removed in v0.15.0).

    function getPool(address baseToken) external view returns (address);
    function getTick(address baseToken) external view returns (int24);
    function getSqrtMarkTwapX96(address baseToken, uint32 twapInterval) external view returns (uint160);
    function getMaxTickCrossedWithinBlock(address baseToken) external view returns (uint24);
    function getAllPendingFundingPayment(address trader) external view returns (int256);
    function getPendingFundingPayment(address trader, address baseToken) external view returns (int256);
}

/*
  Copyright 2022 Set Labs Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;

interface IIndexPrice {
    function getIndexPrice(uint256 interval) external view returns (uint256 indexPrice);
}

/*
  Copyright 2021 Set Labs Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;

interface IVault {
    function getBalance(address account) external view returns (int256);
    function decimals() external view returns (uint8);
    function getFreeCollateral(address trader) external view returns (uint256);
    function getFreeCollateralByRatio(address trader, uint24 ratio) external view returns (int256);
    function getLiquidateMarginRequirement(address trader) external view returns (int256);
    function getSettlementToken() external view returns (address);
    function getAccountBalance() external view returns (address);
    function getClearingHouse() external view returns (address);
    function getExchange() external view returns (address);
}

/*
  Copyright 2021 Set Labs Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

interface IQuoter {
    struct SwapParams {
        address baseToken;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint160 sqrtPriceLimitX96; // price slippage protection
    }

    struct SwapResponse {
        uint256 deltaAvailableBase;
        uint256 deltaAvailableQuote;
        int256 exchangedPositionSize;
        int256 exchangedPositionNotional;
        uint160 sqrtPriceX96;
    }

    function swap(SwapParams memory params) external returns (SwapResponse memory response);
}

/*
  Copyright 2021 Set Labs Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

interface IMarketRegistry {
    //
    // STRUCT
    //
    struct MarketInfo {
        address pool;
        uint24 exchangeFeeRatio;
        uint24 uniswapFeeRatio;
        uint24 insuranceFundFeeRatio;
    }

    //
    // EVENT
    //
    event PoolAdded(address indexed baseToken, uint24 indexed feeRatio, address indexed pool);
    event FeeRatioChanged(address baseToken, uint24 feeRatio);
    event InsuranceFundFeeRatioChanged(uint24 feeRatio);
    event MaxOrdersPerMarketChanged(uint8 maxOrdersPerMarket);

    //
    // FUNCTION
    //

    function addPool(address baseToken, uint24 feeRatio) external returns (address);

    function setFeeRatio(address baseToken, uint24 feeRatio) external;

    function setInsuranceFundFeeRatio(address baseToken, uint24 insuranceFundFeeRatioArg) external;

    function setMaxOrdersPerMarket(uint8 maxOrdersPerMarketArg) external;

    //
    // EXTERNAL VIEW
    //

    function getPool(address baseToken) external view returns (address);

    function getFeeRatio(address baseToken) external view returns (uint24);

    function getInsuranceFundFeeRatio(address baseToken) external view returns (uint24);

    function getMarketInfo(address baseToken) external view returns (MarketInfo memory);

    function getQuoteToken() external view returns (address);

    function getUniswapV3Factory() external view returns (address);

    function getMaxOrdersPerMarket() external view returns (uint8);

    function hasPool(address baseToken) external view returns (bool);
}

/*
    Copyright 2020 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/
pragma solidity 0.6.10;

interface IController {
    function addSet(address _setToken) external;
    function feeRecipient() external view returns(address);
    function getModuleFee(address _module, uint256 _feeType) external view returns(uint256);
    function isModule(address _module) external view returns(bool);
    function isSet(address _setToken) external view returns(bool);
    function isSystemContract(address _contractAddress) external view returns (bool);
    function resourceId(uint256 _id) external view returns(address);
}

/*
    Copyright 2021 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/
pragma solidity 0.6.10;

import { ISetToken } from "./ISetToken.sol";

/**
 * @title IDebtIssuanceModule
 * @author Set Protocol
 *
 * Interface for interacting with Debt Issuance module interface.
 */
interface IDebtIssuanceModule {

    /**
     * Called by another module to register itself on debt issuance module. Any logic can be included
     * in case checks need to be made or state needs to be updated.
     */
    function registerToIssuanceModule(ISetToken _setToken) external;

    /**
     * Called by another module to unregister itself on debt issuance module. Any logic can be included
     * in case checks need to be made or state needs to be cleared.
     */
    function unregisterFromIssuanceModule(ISetToken _setToken) external;
}

/*
    Copyright 2021 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/
pragma solidity 0.6.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISetToken } from "./ISetToken.sol";


/**
 * CHANGELOG:
 *      - Added a module level issue hook that can be used to set state ahead of component level
 *        issue hooks
 *      - Added non-view getter that returns expected positional adjustments during issue/redeem to
 *        the issuance module in order to give more accurate token flow information
 */
interface IModuleIssuanceHookV2 {

    function moduleIssueHook(ISetToken _setToken, uint256 _setTokenQuantity) external;
    function moduleRedeemHook(ISetToken _setToken, uint256 _setTokenQuantity) external;

    function componentIssueHook(
        ISetToken _setToken,
        uint256 _setTokenQuantity,
        IERC20 _component,
        bool _isEquity
    ) external;

    function componentRedeemHook(
        ISetToken _setToken,
        uint256 _setTokenQuantity,
        IERC20 _component,
        bool _isEquity
    ) external;

    /**
     * Adjustments should return the NET CHANGE in POSITION UNITS for each component in the SetToken's
     * components array (i.e. if debt is greater than current debt position unit return negative number).
     * Each entry in the returned arrays should index to the same component in the SetToken's components
     * array (called using getComponents()).
     *
     * NOTE: This getter is non-view to allow module hooks to determine units by simulating state changes in
     * an external protocol and reverting. It should only be called by off-chain methods via static call.
     */
    function getIssuanceAdjustments(
        ISetToken _setToken,
        uint256 _setTokenQuantity
    )
        external
        returns (int256[] memory, int256[] memory);

    /**
     * Adjustments should return the NET CHANGE in POSITION UNITS for each component in the SetToken's
     * components array (i.e. if debt is greater than current debt position unit return negative number).
     * Each entry in the returned arrays should index to the same component in the SetToken's components
     * array (called using getComponents()).
     *
     * NOTE: This getter is non-view to allow module hooks to determine units by simulating state changes in
     * an external protocol and reverting. It should only be called by off-chain methods via static call.
     */
    function getRedemptionAdjustments(
        ISetToken _setToken,
        uint256 _setTokenQuantity
    )
        external
        returns (int256[] memory, int256[] memory);
}

/*
    Copyright 2020 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/
pragma solidity 0.6.10;
pragma experimental "ABIEncoderV2";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ISetToken
 * @author Set Protocol
 *
 * Interface for operating with SetTokens.
 */
interface ISetToken is IERC20 {

    /* ============ Enums ============ */

    enum ModuleState {
        NONE,
        PENDING,
        INITIALIZED
    }

    /* ============ Structs ============ */
    /**
     * The base definition of a SetToken Position
     *
     * @param component           Address of token in the Position
     * @param module              If not in default state, the address of associated module
     * @param unit                Each unit is the # of components per 10^18 of a SetToken
     * @param positionState       Position ENUM. Default is 0; External is 1
     * @param data                Arbitrary data
     */
    struct Position {
        address component;
        address module;
        int256 unit;
        uint8 positionState;
        bytes data;
    }

    /**
     * A struct that stores a component's cash position details and external positions
     * This data structure allows O(1) access to a component's cash position units and 
     * virtual units.
     *
     * @param virtualUnit               Virtual value of a component's DEFAULT position. Stored as virtual for efficiency
     *                                  updating all units at once via the position multiplier. Virtual units are achieved
     *                                  by dividing a "real" value by the "positionMultiplier"
     * @param componentIndex            
     * @param externalPositionModules   List of external modules attached to each external position. Each module
     *                                  maps to an external position
     * @param externalPositions         Mapping of module => ExternalPosition struct for a given component
     */
    struct ComponentPosition {
      int256 virtualUnit;
      address[] externalPositionModules;
      mapping(address => ExternalPosition) externalPositions;
    }

    /**
     * A struct that stores a component's external position details including virtual unit and any
     * auxiliary data.
     *
     * @param virtualUnit       Virtual value of a component's EXTERNAL position.
     * @param data              Arbitrary data
     */
    struct ExternalPosition {
      int256 virtualUnit;
      bytes data;
    }


    /* ============ Functions ============ */
    
    function addComponent(address _component) external;
    function removeComponent(address _component) external;
    function editDefaultPositionUnit(address _component, int256 _realUnit) external;
    function addExternalPositionModule(address _component, address _positionModule) external;
    function removeExternalPositionModule(address _component, address _positionModule) external;
    function editExternalPositionUnit(address _component, address _positionModule, int256 _realUnit) external;
    function editExternalPositionData(address _component, address _positionModule, bytes calldata _data) external;

    function invoke(address _target, uint256 _value, bytes calldata _data) external returns(bytes memory);

    function editPositionMultiplier(int256 _newMultiplier) external;

    function mint(address _account, uint256 _quantity) external;
    function burn(address _account, uint256 _quantity) external;

    function lock() external;
    function unlock() external;

    function addModule(address _module) external;
    function removeModule(address _module) external;
    function initializeModule() external;

    function setManager(address _manager) external;

    function manager() external view returns (address);
    function moduleStates(address _module) external view returns (ModuleState);
    function getModules() external view returns (address[] memory);
    
    function getDefaultPositionRealUnit(address _component) external view returns(int256);
    function getExternalPositionRealUnit(address _component, address _positionModule) external view returns(int256);
    function getComponents() external view returns(address[] memory);
    function getExternalPositionModules(address _component) external view returns(address[] memory);
    function getExternalPositionData(address _component, address _positionModule) external view returns(bytes memory);
    function isExternalPositionModule(address _component, address _module) external view returns(bool);
    function isComponent(address _component) external view returns(bool);
    
    function positionMultiplier() external view returns (int256);
    function getPositions() external view returns (Position[] memory);
    function getTotalComponentRealUnits(address _component) external view returns(int256);

    function isInitializedModule(address _module) external view returns(bool);
    function isPendingModule(address _module) external view returns(bool);
    function isLocked() external view returns (bool);
}

/*
    Copyright 2020 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AddressArrayUtils } from "../../lib/AddressArrayUtils.sol";
import { ExplicitERC20 } from "../../lib/ExplicitERC20.sol";
import { IController } from "../../interfaces/IController.sol";
import { IModule } from "../../interfaces/IModule.sol";
import { ISetToken } from "../../interfaces/ISetToken.sol";
import { Invoke } from "./Invoke.sol";
import { Position } from "./Position.sol";
import { PreciseUnitMath } from "../../lib/PreciseUnitMath.sol";
import { ResourceIdentifier } from "./ResourceIdentifier.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";

/**
 * @title ModuleBase
 * @author Set Protocol
 *
 * Abstract class that houses common Module-related state and functions.
 *
 * CHANGELOG:
 * - 4/21/21: Delegated modifier logic to internal helpers to reduce contract size
 *
 */
abstract contract ModuleBase is IModule {
    using AddressArrayUtils for address[];
    using Invoke for ISetToken;
    using Position for ISetToken;
    using PreciseUnitMath for uint256;
    using ResourceIdentifier for IController;
    using SafeCast for int256;
    using SafeCast for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    /* ============ State Variables ============ */

    // Address of the controller
    IController public controller;

    /* ============ Modifiers ============ */

    modifier onlyManagerAndValidSet(ISetToken _setToken) {
        _validateOnlyManagerAndValidSet(_setToken);
        _;
    }

    modifier onlySetManager(ISetToken _setToken, address _caller) {
        _validateOnlySetManager(_setToken, _caller);
        _;
    }

    modifier onlyValidAndInitializedSet(ISetToken _setToken) {
        _validateOnlyValidAndInitializedSet(_setToken);
        _;
    }

    /**
     * Throws if the sender is not a SetToken's module or module not enabled
     */
    modifier onlyModule(ISetToken _setToken) {
        _validateOnlyModule(_setToken);
        _;
    }

    /**
     * Utilized during module initializations to check that the module is in pending state
     * and that the SetToken is valid
     */
    modifier onlyValidAndPendingSet(ISetToken _setToken) {
        _validateOnlyValidAndPendingSet(_setToken);
        _;
    }

    /* ============ Constructor ============ */

    /**
     * Set state variables and map asset pairs to their oracles
     *
     * @param _controller             Address of controller contract
     */
    constructor(IController _controller) public {
        controller = _controller;
    }

    /* ============ Internal Functions ============ */

    /**
     * Transfers tokens from an address (that has set allowance on the module).
     *
     * @param  _token          The address of the ERC20 token
     * @param  _from           The address to transfer from
     * @param  _to             The address to transfer to
     * @param  _quantity       The number of tokens to transfer
     */
    function transferFrom(IERC20 _token, address _from, address _to, uint256 _quantity) internal {
        ExplicitERC20.transferFrom(_token, _from, _to, _quantity);
    }

    /**
     * Gets the integration for the module with the passed in name. Validates that the address is not empty
     */
    function getAndValidateAdapter(string memory _integrationName) internal view returns(address) { 
        bytes32 integrationHash = getNameHash(_integrationName);
        return getAndValidateAdapterWithHash(integrationHash);
    }

    /**
     * Gets the integration for the module with the passed in hash. Validates that the address is not empty
     */
    function getAndValidateAdapterWithHash(bytes32 _integrationHash) internal view returns(address) { 
        address adapter = controller.getIntegrationRegistry().getIntegrationAdapterWithHash(
            address(this),
            _integrationHash
        );

        require(adapter != address(0), "Must be valid adapter"); 
        return adapter;
    }

    /**
     * Gets the total fee for this module of the passed in index (fee % * quantity)
     */
    function getModuleFee(uint256 _feeIndex, uint256 _quantity) internal view returns(uint256) {
        uint256 feePercentage = controller.getModuleFee(address(this), _feeIndex);
        return _quantity.preciseMul(feePercentage);
    }

    /**
     * Pays the _feeQuantity from the _setToken denominated in _token to the protocol fee recipient
     */
    function payProtocolFeeFromSetToken(ISetToken _setToken, address _token, uint256 _feeQuantity) internal {
        if (_feeQuantity > 0) {
            _setToken.strictInvokeTransfer(_token, controller.feeRecipient(), _feeQuantity); 
        }
    }

    /**
     * Returns true if the module is in process of initialization on the SetToken
     */
    function isSetPendingInitialization(ISetToken _setToken) internal view returns(bool) {
        return _setToken.isPendingModule(address(this));
    }

    /**
     * Returns true if the address is the SetToken's manager
     */
    function isSetManager(ISetToken _setToken, address _toCheck) internal view returns(bool) {
        return _setToken.manager() == _toCheck;
    }

    /**
     * Returns true if SetToken must be enabled on the controller 
     * and module is registered on the SetToken
     */
    function isSetValidAndInitialized(ISetToken _setToken) internal view returns(bool) {
        return controller.isSet(address(_setToken)) &&
            _setToken.isInitializedModule(address(this));
    }

    /**
     * Hashes the string and returns a bytes32 value
     */
    function getNameHash(string memory _name) internal pure returns(bytes32) {
        return keccak256(bytes(_name));
    }

    /* ============== Modifier Helpers ===============
     * Internal functions used to reduce bytecode size
     */

    /**
     * Caller must SetToken manager and SetToken must be valid and initialized
     */
    function _validateOnlyManagerAndValidSet(ISetToken _setToken) internal view {
       require(isSetManager(_setToken, msg.sender), "Must be the SetToken manager");
       require(isSetValidAndInitialized(_setToken), "Must be a valid and initialized SetToken");
    }

    /**
     * Caller must SetToken manager
     */
    function _validateOnlySetManager(ISetToken _setToken, address _caller) internal view {
        require(isSetManager(_setToken, _caller), "Must be the SetToken manager");
    }

    /**
     * SetToken must be valid and initialized
     */
    function _validateOnlyValidAndInitializedSet(ISetToken _setToken) internal view {
        require(isSetValidAndInitialized(_setToken), "Must be a valid and initialized SetToken");
    }

    /**
     * Caller must be initialized module and module must be enabled on the controller
     */
    function _validateOnlyModule(ISetToken _setToken) internal view {
        require(
            _setToken.moduleStates(msg.sender) == ISetToken.ModuleState.INITIALIZED,
            "Only the module can call"
        );

        require(
            controller.isModule(msg.sender),
            "Module must be enabled on controller"
        );
    }

    /**
     * SetToken must be in a pending state and module must be in pending state
     */
    function _validateOnlyValidAndPendingSet(ISetToken _setToken) internal view {
        require(controller.isSet(address(_setToken)), "Must be controller-enabled SetToken");
        require(isSetPendingInitialization(_setToken), "Must be pending initialization");
    }
}

/*
    Copyright 2021 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IController } from "../../interfaces/IController.sol";
import { ISetToken } from "../../interfaces/ISetToken.sol";

/**
 * @title  SetTokenAccessible
 * @author Set Protocol
 *
 * Abstract class that houses permissioning of module for SetTokens.
 */
abstract contract SetTokenAccessible is Ownable {

    /* ============ Events ============ */

    /**
     * @dev Emitted on updateAllowedSetToken()
     * @param _setToken SetToken being whose allowance to initialize this module is being updated
     * @param _added    true if added false if removed
     */
    event SetTokenStatusUpdated(
        ISetToken indexed _setToken,
        bool indexed _added
    );

    /**
     * @dev Emitted on updateAnySetAllowed()
     * @param _anySetAllowed    true if any set is allowed to initialize this module, false otherwise
     */
    event AnySetAllowedUpdated(
        bool indexed _anySetAllowed
    );

    /* ============ Modifiers ============ */

    // @dev If anySetAllowed is true or _setToken is registered in allowedSetTokens, modifier succeeds.
    // Reverts otherwise.
    modifier onlyAllowedSet(ISetToken _setToken) {
        if (!anySetAllowed) {
            require(allowedSetTokens[_setToken], "Not allowed SetToken");
        }
        _;
    }

    /* ============ State Variables ============ */

    // Address of the controller
    IController private controller;

    // Mapping of SetToken to boolean indicating if SetToken is on allow list. Updateable by governance
    mapping(ISetToken => bool) public allowedSetTokens;

    // Boolean that returns if any SetToken can initialize this module. If false, then subject to allow list.
    // Updateable by governance.
    bool public anySetAllowed;


    /* ============ Constructor ============ */

    /**
     * Set controller state variable
     *
     * @param _controller             Address of controller contract
     */
    constructor(IController _controller) public {
        controller = _controller;
    }

    /* ============ External Functions ============ */

    /**
     * @dev GOVERNANCE ONLY: Enable/disable ability of a SetToken to initialize this module.
     *
     * @param _setToken             Instance of the SetToken
     * @param _status               Bool indicating if _setToken is allowed to initialize this module
     */
    function updateAllowedSetToken(ISetToken _setToken, bool _status) public onlyOwner {
        require(controller.isSet(address(_setToken)) || allowedSetTokens[_setToken], "Invalid SetToken");
        allowedSetTokens[_setToken] = _status;
        emit SetTokenStatusUpdated(_setToken, _status);
    }

    /**
     * @dev GOVERNANCE ONLY: Toggle whether ANY SetToken is allowed to initialize this module.
     *
     * @param _anySetAllowed             Bool indicating if ANY SetToken is allowed to initialize this module
     */
    function updateAnySetAllowed(bool _anySetAllowed) public onlyOwner {
        anySetAllowed = _anySetAllowed;
        emit AnySetAllowedUpdated(_anySetAllowed);
    }
}

/*
    Copyright 2020 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";


/**
 * @title PreciseUnitMath
 * @author Set Protocol
 *
 * Arithmetic for fixed-point numbers with 18 decimals of precision. Some functions taken from
 * dYdX's BaseMath library.
 *
 * CHANGELOG:
 * - 9/21/20: Added safePower function
 * - 4/21/21: Added approximatelyEquals function
 * - 12/13/21: Added preciseDivCeil (int overloads) function
 * - 12/13/21: Added abs function
 */
library PreciseUnitMath {
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using SafeCast for int256;

    // The number One in precise units.
    uint256 constant internal PRECISE_UNIT = 10 ** 18;
    int256 constant internal PRECISE_UNIT_INT = 10 ** 18;

    // Max unsigned integer value
    uint256 constant internal MAX_UINT_256 = type(uint256).max;
    // Max and min signed integer value
    int256 constant internal MAX_INT_256 = type(int256).max;
    int256 constant internal MIN_INT_256 = type(int256).min;

    /**
     * @dev Getter function since constants can't be read directly from libraries.
     */
    function preciseUnit() internal pure returns (uint256) {
        return PRECISE_UNIT;
    }

    /**
     * @dev Getter function since constants can't be read directly from libraries.
     */
    function preciseUnitInt() internal pure returns (int256) {
        return PRECISE_UNIT_INT;
    }

    /**
     * @dev Getter function since constants can't be read directly from libraries.
     */
    function maxUint256() internal pure returns (uint256) {
        return MAX_UINT_256;
    }

    /**
     * @dev Getter function since constants can't be read directly from libraries.
     */
    function maxInt256() internal pure returns (int256) {
        return MAX_INT_256;
    }

    /**
     * @dev Getter function since constants can't be read directly from libraries.
     */
    function minInt256() internal pure returns (int256) {
        return MIN_INT_256;
    }

    /**
     * @dev Multiplies value a by value b (result is rounded down). It's assumed that the value b is the significand
     * of a number with 18 decimals precision.
     */
    function preciseMul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a.mul(b).div(PRECISE_UNIT);
    }

    /**
     * @dev Multiplies value a by value b (result is rounded towards zero). It's assumed that the value b is the
     * significand of a number with 18 decimals precision.
     */
    function preciseMul(int256 a, int256 b) internal pure returns (int256) {
        return a.mul(b).div(PRECISE_UNIT_INT);
    }

    /**
     * @dev Multiplies value a by value b (result is rounded up). It's assumed that the value b is the significand
     * of a number with 18 decimals precision.
     */
    function preciseMulCeil(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 || b == 0) {
            return 0;
        }
        return a.mul(b).sub(1).div(PRECISE_UNIT).add(1);
    }

    /**
     * @dev Divides value a by value b (result is rounded down).
     */
    function preciseDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return a.mul(PRECISE_UNIT).div(b);
    }


    /**
     * @dev Divides value a by value b (result is rounded towards 0).
     */
    function preciseDiv(int256 a, int256 b) internal pure returns (int256) {
        return a.mul(PRECISE_UNIT_INT).div(b);
    }

    /**
     * @dev Divides value a by value b (result is rounded up or away from 0).
     */
    function preciseDivCeil(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "Cant divide by 0");

        return a > 0 ? a.mul(PRECISE_UNIT).sub(1).div(b).add(1) : 0;
    }

    /**
     * @dev Divides value a by value b (result is rounded up or away from 0). When `a` is 0, 0 is
     * returned. When `b` is 0, method reverts with divide-by-zero error.
     */
    function preciseDivCeil(int256 a, int256 b) internal pure returns (int256) {
        require(b != 0, "Cant divide by 0");
        
        a = a.mul(PRECISE_UNIT_INT);
        int256 c = a.div(b);

        if (a % b != 0) {
            // a ^ b == 0 case is covered by the previous if statement, hence it won't resolve to --c
            (a ^ b > 0) ? ++c : --c;
        }

        return c;
    }

    /**
     * @dev Divides value a by value b (result is rounded down - positive numbers toward 0 and negative away from 0).
     */
    function divDown(int256 a, int256 b) internal pure returns (int256) {
        require(b != 0, "Cant divide by 0");
        require(a != MIN_INT_256 || b != -1, "Invalid input");

        int256 result = a.div(b);
        if (a ^ b < 0 && a % b != 0) {
            result -= 1;
        }

        return result;
    }

    /**
     * @dev Multiplies value a by value b where rounding is towards the lesser number.
     * (positive values are rounded towards zero and negative values are rounded away from 0).
     */
    function conservativePreciseMul(int256 a, int256 b) internal pure returns (int256) {
        return divDown(a.mul(b), PRECISE_UNIT_INT);
    }

    /**
     * @dev Divides value a by value b where rounding is towards the lesser number.
     * (positive values are rounded towards zero and negative values are rounded away from 0).
     */
    function conservativePreciseDiv(int256 a, int256 b) internal pure returns (int256) {
        return divDown(a.mul(PRECISE_UNIT_INT), b);
    }

    /**
    * @dev Performs the power on a specified value, reverts on overflow.
    */
    function safePower(
        uint256 a,
        uint256 pow
    )
        internal
        pure
        returns (uint256)
    {
        require(a > 0, "Value must be positive");

        uint256 result = 1;
        for (uint256 i = 0; i < pow; i++){
            uint256 previousResult = result;

            // Using safemath multiplication prevents overflows
            result = previousResult.mul(a);
        }

        return result;
    }

    /**
     * @dev Returns true if a =~ b within range, false otherwise.
     */
    function approximatelyEquals(uint256 a, uint256 b, uint256 range) internal pure returns (bool) {
        return a <= b.add(range) && a >= b.sub(range);
    }

    /**
     * Returns the absolute value of int256 `a` as a uint256
     */
    function abs(int256 a) internal pure returns (uint) {
        return a >= 0 ? a.toUint256() : a.mul(-1).toUint256();
    }

    /**
     * Returns the negation of a
     */
    function neg(int256 a) internal pure returns (int256) {
        require(a > MIN_INT_256, "Inversion overflow");
        return -a;
    }
}

/*
    Copyright 2020 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;

/**
 * @title AddressArrayUtils
 * @author Set Protocol
 *
 * Utility functions to handle Address Arrays
 *
 * CHANGELOG:
 * - 4/21/21: Added validatePairsWithArray methods
 */
library AddressArrayUtils {

    /**
     * Finds the index of the first occurrence of the given element.
     * @param A The input array to search
     * @param a The value to find
     * @return Returns (index and isIn) for the first occurrence starting from index 0
     */
    function indexOf(address[] memory A, address a) internal pure returns (uint256, bool) {
        uint256 length = A.length;
        for (uint256 i = 0; i < length; i++) {
            if (A[i] == a) {
                return (i, true);
            }
        }
        return (uint256(-1), false);
    }

    /**
    * Returns true if the value is present in the list. Uses indexOf internally.
    * @param A The input array to search
    * @param a The value to find
    * @return Returns isIn for the first occurrence starting from index 0
    */
    function contains(address[] memory A, address a) internal pure returns (bool) {
        (, bool isIn) = indexOf(A, a);
        return isIn;
    }

    /**
    * Returns true if there are 2 elements that are the same in an array
    * @param A The input array to search
    * @return Returns boolean for the first occurrence of a duplicate
    */
    function hasDuplicate(address[] memory A) internal pure returns(bool) {
        require(A.length > 0, "A is empty");

        for (uint256 i = 0; i < A.length - 1; i++) {
            address current = A[i];
            for (uint256 j = i + 1; j < A.length; j++) {
                if (current == A[j]) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * @param A The input array to search
     * @param a The address to remove
     * @return Returns the array with the object removed.
     */
    function remove(address[] memory A, address a)
        internal
        pure
        returns (address[] memory)
    {
        (uint256 index, bool isIn) = indexOf(A, a);
        if (!isIn) {
            revert("Address not in array.");
        } else {
            (address[] memory _A,) = pop(A, index);
            return _A;
        }
    }

    /**
     * @param A The input array to search
     * @param a The address to remove
     */
    function removeStorage(address[] storage A, address a)
        internal
    {
        (uint256 index, bool isIn) = indexOf(A, a);
        if (!isIn) {
            revert("Address not in array.");
        } else {
            uint256 lastIndex = A.length - 1; // If the array would be empty, the previous line would throw, so no underflow here
            if (index != lastIndex) { A[index] = A[lastIndex]; }
            A.pop();
        }
    }

    /**
    * Removes specified index from array
    * @param A The input array to search
    * @param index The index to remove
    * @return Returns the new array and the removed entry
    */
    function pop(address[] memory A, uint256 index)
        internal
        pure
        returns (address[] memory, address)
    {
        uint256 length = A.length;
        require(index < A.length, "Index must be < A length");
        address[] memory newAddresses = new address[](length - 1);
        for (uint256 i = 0; i < index; i++) {
            newAddresses[i] = A[i];
        }
        for (uint256 j = index + 1; j < length; j++) {
            newAddresses[j - 1] = A[j];
        }
        return (newAddresses, A[index]);
    }

    /**
     * Returns the combination of the two arrays
     * @param A The first array
     * @param B The second array
     * @return Returns A extended by B
     */
    function extend(address[] memory A, address[] memory B) internal pure returns (address[] memory) {
        uint256 aLength = A.length;
        uint256 bLength = B.length;
        address[] memory newAddresses = new address[](aLength + bLength);
        for (uint256 i = 0; i < aLength; i++) {
            newAddresses[i] = A[i];
        }
        for (uint256 j = 0; j < bLength; j++) {
            newAddresses[aLength + j] = B[j];
        }
        return newAddresses;
    }

    /**
     * Validate that address and uint array lengths match. Validate address array is not empty
     * and contains no duplicate elements.
     *
     * @param A         Array of addresses
     * @param B         Array of uint
     */
    function validatePairsWithArray(address[] memory A, uint[] memory B) internal pure {
        require(A.length == B.length, "Array length mismatch");
        _validateLengthAndUniqueness(A);
    }

    /**
     * Validate that address and bool array lengths match. Validate address array is not empty
     * and contains no duplicate elements.
     *
     * @param A         Array of addresses
     * @param B         Array of bool
     */
    function validatePairsWithArray(address[] memory A, bool[] memory B) internal pure {
        require(A.length == B.length, "Array length mismatch");
        _validateLengthAndUniqueness(A);
    }

    /**
     * Validate that address and string array lengths match. Validate address array is not empty
     * and contains no duplicate elements.
     *
     * @param A         Array of addresses
     * @param B         Array of strings
     */
    function validatePairsWithArray(address[] memory A, string[] memory B) internal pure {
        require(A.length == B.length, "Array length mismatch");
        _validateLengthAndUniqueness(A);
    }

    /**
     * Validate that address array lengths match, and calling address array are not empty
     * and contain no duplicate elements.
     *
     * @param A         Array of addresses
     * @param B         Array of addresses
     */
    function validatePairsWithArray(address[] memory A, address[] memory B) internal pure {
        require(A.length == B.length, "Array length mismatch");
        _validateLengthAndUniqueness(A);
    }

    /**
     * Validate that address and bytes array lengths match. Validate address array is not empty
     * and contains no duplicate elements.
     *
     * @param A         Array of addresses
     * @param B         Array of bytes
     */
    function validatePairsWithArray(address[] memory A, bytes[] memory B) internal pure {
        require(A.length == B.length, "Array length mismatch");
        _validateLengthAndUniqueness(A);
    }

    /**
     * Validate address array is not empty and contains no duplicate elements.
     *
     * @param A          Array of addresses
     */
    function _validateLengthAndUniqueness(address[] memory A) internal pure {
        require(A.length > 0, "Array length must be > 0");
        require(!hasDuplicate(A), "Cannot duplicate addresses");
    }
}

/*
    Copyright 2021 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";

/**
 * @title UnitConversionUtils
 * @author Set Protocol
 *
 * Utility functions to convert PRECISE_UNIT values to and from other decimal units
 */
library UnitConversionUtils {
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    /**
     * @dev Converts a uint256 PRECISE_UNIT quote quantity into an alternative decimal format.
     *
     * This method is borrowed from PerpProtocol's `lushan` repo in lib/SettlementTokenMath
     *
     * @param _amount       PRECISE_UNIT amount to convert from
     * @param _decimals     Decimal precision format to convert to
     * @return              Input converted to alternative decimal precision format
     */
    function fromPreciseUnitToDecimals(uint256 _amount, uint8 _decimals) internal pure returns (uint256) {
        return _amount.div(10**(18 - uint(_decimals)));
    }

    /**
     * @dev Converts an int256 PRECISE_UNIT quote quantity into an alternative decimal format.
     *
     * This method is borrowed from PerpProtocol's `lushan` repo in lib/SettlementTokenMath
     *
     * @param _amount       PRECISE_UNIT amount to convert from
     * @param _decimals     Decimal precision format to convert to
     * @return              Input converted to alternative decimal precision format
     */
    function fromPreciseUnitToDecimals(int256 _amount, uint8 _decimals) internal pure returns (int256) {
        return _amount.div(int256(10**(18 - uint(_decimals))));
    }

    /**
     * @dev Converts an arbitrarily decimalized quantity into a PRECISE_UNIT quantity.
     *
     * @param _amount       Non-PRECISE_UNIT amount to convert
     * @param _decimals     Decimal precision of amount being converted to PRECISE_UNIT
     * @return              Input converted to PRECISE_UNIT decimal format
     */
    function toPreciseUnitsFromDecimals(int256 _amount, uint8 _decimals) internal pure returns (int256) {
        return _amount.mul(int256(10**(18 - (uint(_decimals)))));
    }
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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
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
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
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
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
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
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
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
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
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
        require(b != 0, errorMessage);
        return a % b;
    }
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

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.4.0;

/// @title FixedPoint96
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)
/// @dev Used in SqrtPriceMath.sol
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.0;

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 512-bit multiply [prod1 prod0] = a * b
        // Compute the product mod 2**256 and mod 2**256 - 1
        // then use the Chinese Remainder Theorem to reconstruct
        // the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2**256 + prod0
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // Handle non-overflow cases, 256 by 256 division
        if (prod1 == 0) {
            require(denominator > 0);
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        // Make sure the result is less than 2**256.
        // Also prevents denominator == 0
        require(denominator > prod1);

        ///////////////////////////////////////////////
        // 512 by 256 division.
        ///////////////////////////////////////////////

        // Make division exact by subtracting the remainder from [prod1 prod0]
        // Compute remainder using mulmod
        uint256 remainder;
        assembly {
            remainder := mulmod(a, b, denominator)
        }
        // Subtract 256 bit number from 512 bit number
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        // Factor powers of two out of denominator
        // Compute largest power of two divisor of denominator.
        // Always >= 1.
        uint256 twos = -denominator & denominator;
        // Divide denominator by power of two
        assembly {
            denominator := div(denominator, twos)
        }

        // Divide [prod1 prod0] by the factors of two
        assembly {
            prod0 := div(prod0, twos)
        }
        // Shift in bits from prod1 into prod0. For this we need
        // to flip `twos` such that it is 2**256 / twos.
        // If twos is zero, then it becomes one
        assembly {
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        // Invert denominator mod 2**256
        // Now that denominator is an odd number, it has an inverse
        // modulo 2**256 such that denominator * inv = 1 mod 2**256.
        // Compute the inverse by starting with a seed that is correct
        // correct for four bits. That is, denominator * inv = 1 mod 2**4
        uint256 inv = (3 * denominator) ^ 2;
        // Now use Newton-Raphson iteration to improve the precision.
        // Thanks to Hensel's lifting lemma, this also works in modular
        // arithmetic, doubling the correct bits in each step.
        inv *= 2 - denominator * inv; // inverse mod 2**8
        inv *= 2 - denominator * inv; // inverse mod 2**16
        inv *= 2 - denominator * inv; // inverse mod 2**32
        inv *= 2 - denominator * inv; // inverse mod 2**64
        inv *= 2 - denominator * inv; // inverse mod 2**128
        inv *= 2 - denominator * inv; // inverse mod 2**256

        // Because the division is now exact we can divide by multiplying
        // with the modular inverse of denominator. This will give us the
        // correct result modulo 2**256. Since the precoditions guarantee
        // that the outcome is less than 2**256, this is the final result.
        // We don't need to compute the high bits of the result and prod1
        // is no longer required.
        result = prod0 * inv;
        return result;
    }

    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;


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
library SafeCast {

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
        require(value < 2**128, "SafeCast: value doesn\'t fit in 128 bits");
        return uint128(value);
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
        require(value < 2**64, "SafeCast: value doesn\'t fit in 64 bits");
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
        require(value < 2**32, "SafeCast: value doesn\'t fit in 32 bits");
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
        require(value < 2**16, "SafeCast: value doesn\'t fit in 16 bits");
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
        require(value < 2**8, "SafeCast: value doesn\'t fit in 8 bits");
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
        require(value >= -2**127 && value < 2**127, "SafeCast: value doesn\'t fit in 128 bits");
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
        require(value >= -2**63 && value < 2**63, "SafeCast: value doesn\'t fit in 64 bits");
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
        require(value >= -2**31 && value < 2**31, "SafeCast: value doesn\'t fit in 32 bits");
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
        require(value >= -2**15 && value < 2**15, "SafeCast: value doesn\'t fit in 16 bits");
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
        require(value >= -2**7 && value < 2**7, "SafeCast: value doesn\'t fit in 8 bits");
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
        require(value < 2**255, "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

/*
    Copyright 2020 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @title ExplicitERC20
 * @author Set Protocol
 *
 * Utility functions for ERC20 transfers that require the explicit amount to be transferred.
 */
library ExplicitERC20 {
    using SafeMath for uint256;

    /**
     * When given allowance, transfers a token from the "_from" to the "_to" of quantity "_quantity".
     * Ensures that the recipient has received the correct quantity (ie no fees taken on transfer)
     *
     * @param _token           ERC20 token to approve
     * @param _from            The account to transfer tokens from
     * @param _to              The account to transfer tokens to
     * @param _quantity        The quantity to transfer
     */
    function transferFrom(
        IERC20 _token,
        address _from,
        address _to,
        uint256 _quantity
    )
        internal
    {
        // Call specified ERC20 contract to transfer tokens (via proxy).
        if (_quantity > 0) {
            uint256 existingBalance = _token.balanceOf(_to);

            SafeERC20.safeTransferFrom(
                _token,
                _from,
                _to,
                _quantity
            );

            uint256 newBalance = _token.balanceOf(_to);

            // Verify transfer quantity is reflected in balance
            require(
                newBalance == existingBalance.add(_quantity),
                "Invalid post transfer balance"
            );
        }
    }
}

/*
    Copyright 2020 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/
pragma solidity 0.6.10;


/**
 * @title IModule
 * @author Set Protocol
 *
 * Interface for interacting with Modules.
 */
interface IModule {
    /**
     * Called by a SetToken to notify that this module was removed from the Set token. Any logic can be included
     * in case checks need to be made or state needs to be cleared.
     */
    function removeModule() external;
}

/*
    Copyright 2020 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { ISetToken } from "../../interfaces/ISetToken.sol";


/**
 * @title Invoke
 * @author Set Protocol
 *
 * A collection of common utility functions for interacting with the SetToken's invoke function
 */
library Invoke {
    using SafeMath for uint256;

    /* ============ Internal ============ */

    /**
     * Instructs the SetToken to set approvals of the ERC20 token to a spender.
     *
     * @param _setToken        SetToken instance to invoke
     * @param _token           ERC20 token to approve
     * @param _spender         The account allowed to spend the SetToken's balance
     * @param _quantity        The quantity of allowance to allow
     */
    function invokeApprove(
        ISetToken _setToken,
        address _token,
        address _spender,
        uint256 _quantity
    )
        internal
    {
        bytes memory callData = abi.encodeWithSignature("approve(address,uint256)", _spender, _quantity);
        _setToken.invoke(_token, 0, callData);
    }

    /**
     * Instructs the SetToken to transfer the ERC20 token to a recipient.
     *
     * @param _setToken        SetToken instance to invoke
     * @param _token           ERC20 token to transfer
     * @param _to              The recipient account
     * @param _quantity        The quantity to transfer
     */
    function invokeTransfer(
        ISetToken _setToken,
        address _token,
        address _to,
        uint256 _quantity
    )
        internal
    {
        if (_quantity > 0) {
            bytes memory callData = abi.encodeWithSignature("transfer(address,uint256)", _to, _quantity);
            _setToken.invoke(_token, 0, callData);
        }
    }

    /**
     * Instructs the SetToken to transfer the ERC20 token to a recipient.
     * The new SetToken balance must equal the existing balance less the quantity transferred
     *
     * @param _setToken        SetToken instance to invoke
     * @param _token           ERC20 token to transfer
     * @param _to              The recipient account
     * @param _quantity        The quantity to transfer
     */
    function strictInvokeTransfer(
        ISetToken _setToken,
        address _token,
        address _to,
        uint256 _quantity
    )
        internal
    {
        if (_quantity > 0) {
            // Retrieve current balance of token for the SetToken
            uint256 existingBalance = IERC20(_token).balanceOf(address(_setToken));

            Invoke.invokeTransfer(_setToken, _token, _to, _quantity);

            // Get new balance of transferred token for SetToken
            uint256 newBalance = IERC20(_token).balanceOf(address(_setToken));

            // Verify only the transfer quantity is subtracted
            require(
                newBalance == existingBalance.sub(_quantity),
                "Invalid post transfer balance"
            );
        }
    }

    /**
     * Instructs the SetToken to unwrap the passed quantity of WETH
     *
     * @param _setToken        SetToken instance to invoke
     * @param _weth            WETH address
     * @param _quantity        The quantity to unwrap
     */
    function invokeUnwrapWETH(ISetToken _setToken, address _weth, uint256 _quantity) internal {
        bytes memory callData = abi.encodeWithSignature("withdraw(uint256)", _quantity);
        _setToken.invoke(_weth, 0, callData);
    }

    /**
     * Instructs the SetToken to wrap the passed quantity of ETH
     *
     * @param _setToken        SetToken instance to invoke
     * @param _weth            WETH address
     * @param _quantity        The quantity to unwrap
     */
    function invokeWrapWETH(ISetToken _setToken, address _weth, uint256 _quantity) internal {
        bytes memory callData = abi.encodeWithSignature("deposit()");
        _setToken.invoke(_weth, _quantity, callData);
    }
}

/*
    Copyright 2020 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;
pragma experimental "ABIEncoderV2";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";

import { ISetToken } from "../../interfaces/ISetToken.sol";
import { PreciseUnitMath } from "../../lib/PreciseUnitMath.sol";


/**
 * @title Position
 * @author Set Protocol
 *
 * Collection of helper functions for handling and updating SetToken Positions
 *
 * CHANGELOG:
 *  - Updated editExternalPosition to work when no external position is associated with module
 */
library Position {
    using SafeCast for uint256;
    using SafeMath for uint256;
    using SafeCast for int256;
    using SignedSafeMath for int256;
    using PreciseUnitMath for uint256;

    /* ============ Helper ============ */

    /**
     * Returns whether the SetToken has a default position for a given component (if the real unit is > 0)
     */
    function hasDefaultPosition(ISetToken _setToken, address _component) internal view returns(bool) {
        return _setToken.getDefaultPositionRealUnit(_component) > 0;
    }

    /**
     * Returns whether the SetToken has an external position for a given component (if # of position modules is > 0)
     */
    function hasExternalPosition(ISetToken _setToken, address _component) internal view returns(bool) {
        return _setToken.getExternalPositionModules(_component).length > 0;
    }
    
    /**
     * Returns whether the SetToken component default position real unit is greater than or equal to units passed in.
     */
    function hasSufficientDefaultUnits(ISetToken _setToken, address _component, uint256 _unit) internal view returns(bool) {
        return _setToken.getDefaultPositionRealUnit(_component) >= _unit.toInt256();
    }

    /**
     * Returns whether the SetToken component external position is greater than or equal to the real units passed in.
     */
    function hasSufficientExternalUnits(
        ISetToken _setToken,
        address _component,
        address _positionModule,
        uint256 _unit
    )
        internal
        view
        returns(bool)
    {
       return _setToken.getExternalPositionRealUnit(_component, _positionModule) >= _unit.toInt256();    
    }

    /**
     * If the position does not exist, create a new Position and add to the SetToken. If it already exists,
     * then set the position units. If the new units is 0, remove the position. Handles adding/removing of 
     * components where needed (in light of potential external positions).
     *
     * @param _setToken           Address of SetToken being modified
     * @param _component          Address of the component
     * @param _newUnit            Quantity of Position units - must be >= 0
     */
    function editDefaultPosition(ISetToken _setToken, address _component, uint256 _newUnit) internal {
        bool isPositionFound = hasDefaultPosition(_setToken, _component);
        if (!isPositionFound && _newUnit > 0) {
            // If there is no Default Position and no External Modules, then component does not exist
            if (!hasExternalPosition(_setToken, _component)) {
                _setToken.addComponent(_component);
            }
        } else if (isPositionFound && _newUnit == 0) {
            // If there is a Default Position and no external positions, remove the component
            if (!hasExternalPosition(_setToken, _component)) {
                _setToken.removeComponent(_component);
            }
        }

        _setToken.editDefaultPositionUnit(_component, _newUnit.toInt256());
    }

    /**
     * Update an external position and remove and external positions or components if necessary. The logic flows as follows:
     * 1) If component is not already added then add component and external position. 
     * 2) If component is added but no existing external position using the passed module exists then add the external position.
     * 3) If the existing position is being added to then just update the unit and data
     * 4) If the position is being closed and no other external positions or default positions are associated with the component
     *    then untrack the component and remove external position.
     * 5) If the position is being closed and other existing positions still exist for the component then just remove the
     *    external position.
     *
     * @param _setToken         SetToken being updated
     * @param _component        Component position being updated
     * @param _module           Module external position is associated with
     * @param _newUnit          Position units of new external position
     * @param _data             Arbitrary data associated with the position
     */
    function editExternalPosition(
        ISetToken _setToken,
        address _component,
        address _module,
        int256 _newUnit,
        bytes memory _data
    )
        internal
    {
        if (_newUnit != 0) {
            if (!_setToken.isComponent(_component)) {
                _setToken.addComponent(_component);
                _setToken.addExternalPositionModule(_component, _module);
            } else if (!_setToken.isExternalPositionModule(_component, _module)) {
                _setToken.addExternalPositionModule(_component, _module);
            }
            _setToken.editExternalPositionUnit(_component, _module, _newUnit);
            _setToken.editExternalPositionData(_component, _module, _data);
        } else {
            require(_data.length == 0, "Passed data must be null");
            // If no default or external position remaining then remove component from components array
            if (_setToken.getExternalPositionRealUnit(_component, _module) != 0) {
                address[] memory positionModules = _setToken.getExternalPositionModules(_component);
                if (_setToken.getDefaultPositionRealUnit(_component) == 0 && positionModules.length == 1) {
                    require(positionModules[0] == _module, "External positions must be 0 to remove component");
                    _setToken.removeComponent(_component);
                }
                _setToken.removeExternalPositionModule(_component, _module);
            }
        }
    }

    /**
     * Get total notional amount of Default position
     *
     * @param _setTokenSupply     Supply of SetToken in precise units (10^18)
     * @param _positionUnit       Quantity of Position units
     *
     * @return                    Total notional amount of units
     */
    function getDefaultTotalNotional(uint256 _setTokenSupply, uint256 _positionUnit) internal pure returns (uint256) {
        return _setTokenSupply.preciseMul(_positionUnit);
    }

    /**
     * Get position unit from total notional amount
     *
     * @param _setTokenSupply     Supply of SetToken in precise units (10^18)
     * @param _totalNotional      Total notional amount of component prior to
     * @return                    Default position unit
     */
    function getDefaultPositionUnit(uint256 _setTokenSupply, uint256 _totalNotional) internal pure returns (uint256) {
        return _totalNotional.preciseDiv(_setTokenSupply);
    }

    /**
     * Get the total tracked balance - total supply * position unit
     *
     * @param _setToken           Address of the SetToken
     * @param _component          Address of the component
     * @return                    Notional tracked balance
     */
    function getDefaultTrackedBalance(ISetToken _setToken, address _component) internal view returns(uint256) {
        int256 positionUnit = _setToken.getDefaultPositionRealUnit(_component); 
        return _setToken.totalSupply().preciseMul(positionUnit.toUint256());
    }

    /**
     * Calculates the new default position unit and performs the edit with the new unit
     *
     * @param _setToken                 Address of the SetToken
     * @param _component                Address of the component
     * @param _setTotalSupply           Current SetToken supply
     * @param _componentPreviousBalance Pre-action component balance
     * @return                          Current component balance
     * @return                          Previous position unit
     * @return                          New position unit
     */
    function calculateAndEditDefaultPosition(
        ISetToken _setToken,
        address _component,
        uint256 _setTotalSupply,
        uint256 _componentPreviousBalance
    )
        internal
        returns(uint256, uint256, uint256)
    {
        uint256 currentBalance = IERC20(_component).balanceOf(address(_setToken));
        uint256 positionUnit = _setToken.getDefaultPositionRealUnit(_component).toUint256();

        uint256 newTokenUnit;
        if (currentBalance > 0) {
            newTokenUnit = calculateDefaultEditPositionUnit(
                _setTotalSupply,
                _componentPreviousBalance,
                currentBalance,
                positionUnit
            );
        } else {
            newTokenUnit = 0;
        }

        editDefaultPosition(_setToken, _component, newTokenUnit);

        return (currentBalance, positionUnit, newTokenUnit);
    }

    /**
     * Calculate the new position unit given total notional values pre and post executing an action that changes SetToken state
     * The intention is to make updates to the units without accidentally picking up airdropped assets as well.
     *
     * @param _setTokenSupply     Supply of SetToken in precise units (10^18)
     * @param _preTotalNotional   Total notional amount of component prior to executing action
     * @param _postTotalNotional  Total notional amount of component after the executing action
     * @param _prePositionUnit    Position unit of SetToken prior to executing action
     * @return                    New position unit
     */
    function calculateDefaultEditPositionUnit(
        uint256 _setTokenSupply,
        uint256 _preTotalNotional,
        uint256 _postTotalNotional,
        uint256 _prePositionUnit
    )
        internal
        pure
        returns (uint256)
    {
        // If pre action total notional amount is greater then subtract post action total notional and calculate new position units
        uint256 airdroppedAmount = _preTotalNotional.sub(_prePositionUnit.preciseMul(_setTokenSupply));
        return _postTotalNotional.sub(airdroppedAmount).preciseDiv(_setTokenSupply);
    }
}

/*
    Copyright 2020 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;

import { IController } from "../../interfaces/IController.sol";
import { IIntegrationRegistry } from "../../interfaces/IIntegrationRegistry.sol";
import { IPriceOracle } from "../../interfaces/IPriceOracle.sol";
import { ISetValuer } from "../../interfaces/ISetValuer.sol";

/**
 * @title ResourceIdentifier
 * @author Set Protocol
 *
 * A collection of utility functions to fetch information related to Resource contracts in the system
 */
library ResourceIdentifier {

    // IntegrationRegistry will always be resource ID 0 in the system
    uint256 constant internal INTEGRATION_REGISTRY_RESOURCE_ID = 0;
    // PriceOracle will always be resource ID 1 in the system
    uint256 constant internal PRICE_ORACLE_RESOURCE_ID = 1;
    // SetValuer resource will always be resource ID 2 in the system
    uint256 constant internal SET_VALUER_RESOURCE_ID = 2;

    /* ============ Internal ============ */

    /**
     * Gets the instance of integration registry stored on Controller. Note: IntegrationRegistry is stored as index 0 on
     * the Controller
     */
    function getIntegrationRegistry(IController _controller) internal view returns (IIntegrationRegistry) {
        return IIntegrationRegistry(_controller.resourceId(INTEGRATION_REGISTRY_RESOURCE_ID));
    }

    /**
     * Gets instance of price oracle on Controller. Note: PriceOracle is stored as index 1 on the Controller
     */
    function getPriceOracle(IController _controller) internal view returns (IPriceOracle) {
        return IPriceOracle(_controller.resourceId(PRICE_ORACLE_RESOURCE_ID));
    }

    /**
     * Gets the instance of Set valuer on Controller. Note: SetValuer is stored as index 2 on the Controller
     */
    function getSetValuer(IController _controller) internal view returns (ISetValuer) {
        return ISetValuer(_controller.resourceId(SET_VALUER_RESOURCE_ID));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

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
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
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
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
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

/*
    Copyright 2020 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/
pragma solidity 0.6.10;

interface IIntegrationRegistry {
    function addIntegration(address _module, string memory _id, address _wrapper) external;
    function getIntegrationAdapter(address _module, string memory _id) external view returns(address);
    function getIntegrationAdapterWithHash(address _module, bytes32 _id) external view returns(address);
    function isValidIntegration(address _module, string memory _id) external view returns(bool);
}

/*
    Copyright 2020 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/
pragma solidity 0.6.10;

/**
 * @title IPriceOracle
 * @author Set Protocol
 *
 * Interface for interacting with PriceOracle
 */
interface IPriceOracle {

    /* ============ Functions ============ */

    function getPrice(address _assetOne, address _assetTwo) external view returns (uint256);
    function masterQuoteAsset() external view returns (address);
}

/*
    Copyright 2020 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/
pragma solidity 0.6.10;

import { ISetToken } from "../interfaces/ISetToken.sol";

interface ISetValuer {
    function calculateSetTokenValuation(ISetToken _setToken, address _quoteAsset) external view returns (uint256);
}