/**
 *Submitted for verification at optimistic.etherscan.io on 2022-01-27
*/

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
*/
pragma solidity >=0.6.0 <0.8.0;

pragma experimental ABIEncoderV2;


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